"""sessione.py -- una sessione della demo M6-D04 «Una modifica a sessione
avviata, e dopo /compact», in un solo processo di Claude Code.

Prepara una copia nuova di progetto/ in una cartella temporanea (un
repository git con un commit, il registro dell'hook vuoto) con parole in
codice casuali, nate qui; avvia un solo processo

    claude -p --input-format stream-json --output-format stream-json --verbose

e gli manda i messaggi uno alla volta, aspettando il risultato di ognuno: è la
stessa sessione che resta aperta, come in una sessione interattiva. Con
--resume no: ogni chiamata sarebbe un processo nuovo, che rilegge i CLAUDE.md.
I passi, per tipo:
  compact  domanda; CLAUDE.md riscritto da fuori con una parola nuova;
           domanda; /compact; domanda           (nessuno strumento)
  clear    gli stessi, con /clear al posto di /compact
  regola   leggi (src/a.php); /compact; elenca; leggi; elenca   (solo Read)
I testi sono domanda.txt, leggi.txt ed elenca.txt, accanto a questo file.

Mostra il comando prima di avviarlo, e ogni passo con la risposta. Dopo ogni
risultato aspetta che il registro dell'hook InstructionsLoaded resti fermo:
l'hook gira in modo asincrono. Nel deposito lascia:
  <nome>.jsonl              lo stream, riga per riga, come arriva;
  <nome>.caricamenti.jsonl  il registro dell'hook della copia;
  <nome>.sessione.json      il tipo, le parole, gli strumenti e i passi:
                            per ognuno il testo mandato, l'ora d'inizio e di
                            fine e quante righe ha il registro alla fine del
                            passo (così il controllo sa a quale passo
                            appartiene ogni caricamento).
Poi toglie la copia.

Le opzioni sono quelle di handson::claude_p di tools/lib_handson.sh: Sonnet
con effort low, dontAsk, --permission-prompts none, --setting-sources
project,local, nessun server MCP, nessuna sessione salvata; senza
ANTHROPIC_API_KEY e CLAUDE_CODE_EFFORT_LEVEL nell'ambiente di claude, con
CLAUDE_CODE_DISABLE_AUTO_MEMORY=1.

Uso:    python3 sessione.py --tipo compact|clear|regola --nome <nome>
          --progetto <cartella> --copie <cartella> --deposito <cartella>
Env:    PN_SESSIONE_ATTESA  i secondi che un passo può durare (default 300)
        PN_SESSIONE_CALMA   i secondi in cui il registro deve restare fermo
                            dopo un risultato (default 0,5; le prove ne
                            usano meno)
        PN_SESSIONE_PAUSA   i secondi prima della modifica (default 1)
Uscita: 0 la sessione ha dato un risultato a ogni messaggio · 1 claude è
        fallito, ha restituito un errore o non ha risposto in tempo · 2
        precondizione (argomenti, cartelle, testi, git, claude che manca)
"""
from __future__ import annotations

import datetime
import json
import os
import queue
import re
import secrets
import shlex
import shutil
import string
import subprocess
import sys
import tempfile
import threading
import time
from typing import Dict, List, NamedTuple, Optional, Tuple

MODELLO = "sonnet"
REGISTRO = os.path.join(".claude", "caricamenti.jsonl")
CON_SEGNAPOSTO = ("CLAUDE.md", os.path.join(".claude", "rules", "php.md"))
RE_SEGNAPOSTO = re.compile(r"__[A-Z]+__")
TOGLIERE = ("ANTHROPIC_API_KEY", "CLAUDE_CODE_EFFORT_LEVEL")
LARGHEZZA = 76
ATTESA_FINE = 60
CALMA = 0.5
CALMA_MASSIMA = 5.0
PAUSA = 1.0


class Precondizione(Exception):
    """Argomenti, cartelle, testi o git che non vanno: uscita 2."""


class Fallita(Exception):
    """claude è fallito o non ha risposto: uscita 1."""


class Passo(NamedTuple):
    """Un passo della sessione: messaggio, comando o modifica."""
    tipo: str
    testo: str


def ora() -> str:
    return datetime.datetime.now(datetime.timezone.utc).strftime(
        "%Y-%m-%dT%H:%M:%SZ")


def parola(prefisso: str) -> str:
    """Una parola in codice casuale: PREFISSO-XXXXXX."""
    return prefisso + "-" + "".join(secrets.choice(string.ascii_uppercase)
                                    for _ in range(6))


def leggi_testo(percorso: str) -> str:
    try:
        with open(percorso, encoding="utf-8") as fh:
            testo = fh.read().strip()
    except (OSError, UnicodeDecodeError) as exc:
        raise Precondizione("non riesco a leggere %s: %s" % (percorso, exc))
    if not testo:
        raise Precondizione("%s è vuoto" % percorso)
    return testo


def passi_di(tipo: str, qui: str) -> Tuple[List[Passo], str]:
    """I passi del tipo e gli strumenti della sessione."""
    domanda = leggi_testo(os.path.join(qui, "domanda.txt"))
    if tipo in ("compact", "clear"):
        return [Passo("messaggio", domanda), Passo("modifica", "CLAUDE.md"),
                Passo("messaggio", domanda), Passo("comando", "/" + tipo),
                Passo("messaggio", domanda)], ""
    leggi = leggi_testo(os.path.join(qui, "leggi.txt"))
    elenca = leggi_testo(os.path.join(qui, "elenca.txt"))
    return [Passo("messaggio", leggi), Passo("comando", "/compact"),
            Passo("messaggio", elenca), Passo("messaggio", leggi),
            Passo("messaggio", elenca)], "Read"


def parole_di(tipo: str) -> Dict[str, str]:
    if tipo == "regola":
        return {"radice": parola("RADICE"), "regolaphp": parola("REGOLAPHP")}
    return {"radice": parola("PRIMA"), "nuova": parola("DOPO"),
            "regolaphp": parola("REGOLAPHP")}


def sostituisci(percorso: str, vecchio: str, nuovo: str) -> None:
    with open(percorso, encoding="utf-8") as fh:
        testo = fh.read()
    with open(percorso, "w", encoding="utf-8") as fh:
        fh.write(testo.replace(vecchio, nuovo))


def git(copia: str, *argomenti: str) -> None:
    comando = ["git", "-C", copia, "-c", "user.name=Corso Claude Code",
               "-c", "user.email=corso@example.org",
               "-c", "commit.gpgsign=false", "-c", "init.defaultBranch=main"]
    try:
        subprocess.run(comando + list(argomenti), check=True,
                       stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                       stderr=subprocess.PIPE, timeout=60)
    except (OSError, subprocess.SubprocessError) as exc:
        raise Precondizione("git non riesce a fare il repository della "
                            "copia: %s" % exc)


def prepara_copia(progetto: str, copie: str, nome: str,
                  parole: Dict[str, str]) -> str:
    """La copia del progetto con le parole, in git, con il registro vuoto;
    se non riesce, la toglie."""
    copia = tempfile.mkdtemp(prefix=nome + ".", dir=copie)
    try:
        riempi_copia(progetto, copia, nome, parole)
    except Precondizione:
        togli_copia(copia, copie)
        raise
    return copia


def riempi_copia(progetto: str, copia: str, nome: str,
                 parole: Dict[str, str]) -> None:
    try:
        shutil.copytree(progetto, copia, dirs_exist_ok=True)
        sostituisci(os.path.join(copia, "CLAUDE.md"), "__RADICE__",
                    parole["radice"])
        sostituisci(os.path.join(copia, CON_SEGNAPOSTO[1]), "__REGOLAPHP__",
                    parole["regolaphp"])
        for rel in CON_SEGNAPOSTO:
            with open(os.path.join(copia, rel), encoding="utf-8") as fh:
                if RE_SEGNAPOSTO.search(fh.read()):
                    raise Precondizione("un segnaposto senza parola in %s: "
                                        "progetto/ è cambiato?" % rel)
        with open(os.path.join(copia, ".gitignore"), "w",
                  encoding="utf-8") as fh:
            fh.write(REGISTRO.replace(os.sep, "/") + "\n")
    except (OSError, UnicodeDecodeError) as exc:
        raise Precondizione("non riesco a preparare la copia: %s" % exc)
    git(copia, "init", "-q")
    git(copia, "add", "-A")
    git(copia, "commit", "-q", "--no-verify", "-m",
        "Punto di partenza di %s" % nome)
    try:
        open(os.path.join(copia, REGISTRO), "w").close()
    except OSError as exc:
        raise Precondizione("non riesco a creare il registro: %s" % exc)


def comando_di(strumenti: str) -> List[str]:
    argv = ["claude", "-p", "--input-format", "stream-json",
            "--output-format", "stream-json", "--verbose",
            "--model", MODELLO, "--effort", "low",
            "--permission-mode", "dontAsk", "--permission-prompts", "none",
            "--setting-sources", "project,local", "--strict-mcp-config",
            "--no-session-persistence", "--tools", strumenti]
    if strumenti:
        argv += ["--allowedTools", strumenti]
    return argv


def mostra_comando(argv: List[str]) -> str:
    """Il comando incollabile, a capo prima di un'opzione quando la riga
    supererebbe la larghezza dello schermo."""
    righe, riga = [], "  $"
    gruppi: List[str] = []
    for token in argv:
        q = shlex.quote(token)
        if token.startswith("--") and gruppi:
            gruppi.append(q)
        elif gruppi:
            gruppi[-1] += " " + q
        else:
            gruppi.append(q)
    for gruppo in gruppi:
        if len(riga) + len(gruppo) + 1 > LARGHEZZA:
            righe.append(riga + " \\")
            riga = "     "
        riga += " " + gruppo
    righe.append(riga)
    return "\n".join(righe)


def breve(testo: str) -> str:
    testo = " ".join(testo.split())
    return testo[:69] + "…" if len(testo) > 70 else testo


def righe_del_registro(percorso: str) -> int:
    try:
        with open(percorso, encoding="utf-8", errors="replace") as fh:
            return sum(1 for riga in fh if riga.strip())
    except OSError:
        return 0


def secondi_da(nome: str, predefiniti: float) -> float:
    """Una durata da una variabile d'ambiente, da 0 a 10 secondi."""
    valore = os.environ.get(nome, "")
    if not valore:
        return predefiniti
    try:
        secondi = float(valore)
    except ValueError:
        secondi = -1
    if not 0 <= secondi <= 10:
        raise Precondizione("%s vuole i secondi, da 0 a 10, non «%s»"
                            % (nome, valore))
    return secondi


def assesta(percorso: str) -> int:
    """Aspetta che il registro resti fermo per CALMA secondi (al massimo
    CALMA_MASSIMA): l'hook gira in modo asincrono. Returns: le righe."""
    calma = secondi_da("PN_SESSIONE_CALMA", CALMA)
    fine = time.monotonic() + CALMA_MASSIMA
    prima = os.path.getsize(percorso) if os.path.exists(percorso) else -1
    fermo_da = time.monotonic()
    while time.monotonic() < fine:
        time.sleep(0.1)
        adesso = os.path.getsize(percorso) if os.path.exists(percorso) else -1
        if adesso != prima:
            prima, fermo_da = adesso, time.monotonic()
        elif time.monotonic() - fermo_da >= calma:
            break
    return righe_del_registro(percorso)


class Processo:
    """Il processo di claude: STDIN per i messaggi, STDOUT letto da un thread
    in una coda, ogni riga anche nel file dello stream."""

    def __init__(self, argv: List[str], copia: str, stream: str,
                 errori: str) -> None:
        ambiente = {k: v for k, v in os.environ.items() if k not in TOGLIERE}
        ambiente["CLAUDE_CODE_DISABLE_AUTO_MEMORY"] = "1"
        self.uscita = open(stream, "w", encoding="utf-8")
        self.errori = open(errori, "w", encoding="utf-8")
        try:
            self.proc = subprocess.Popen(
                argv, cwd=copia, env=ambiente, stdin=subprocess.PIPE,
                stdout=subprocess.PIPE, stderr=self.errori, text=True,
                encoding="utf-8", errors="replace", bufsize=1)
        except OSError as exc:
            self.uscita.close()
            self.errori.close()
            raise Precondizione("claude non parte: %s" % exc)
        self.coda: "queue.Queue[Optional[str]]" = queue.Queue()
        threading.Thread(target=self._leggi, daemon=True).start()

    def _leggi(self) -> None:
        assert self.proc.stdout is not None
        for riga in self.proc.stdout:
            self.coda.put(riga)
        self.coda.put(None)

    def manda(self, testo: str) -> None:
        messaggio = {"type": "user",
                     "message": {"role": "user", "content": testo}}
        try:
            assert self.proc.stdin is not None
            self.proc.stdin.write(json.dumps(messaggio, ensure_ascii=False)
                                  + "\n")
            self.proc.stdin.flush()
        except (OSError, ValueError) as exc:
            raise Fallita("claude non riceve il messaggio: %s" % exc)

    def risultato(self, attesa: float) -> dict:
        """Le righe fino al prossimo evento result, che restituisce."""
        fine = time.monotonic() + attesa
        while True:
            resta = fine - time.monotonic()
            if resta <= 0:
                raise Fallita("nessun risultato in %d secondi" % attesa)
            try:
                riga = self.coda.get(timeout=resta)
            except queue.Empty:
                raise Fallita("nessun risultato in %d secondi" % attesa)
            if riga is None:
                raise Fallita("claude si è fermato prima del risultato")
            self.uscita.write(riga)
            self.uscita.flush()
            try:
                evento = json.loads(riga)
            except ValueError:
                continue
            if isinstance(evento, dict) and evento.get("type") == "result":
                return evento

    def chiudi(self) -> int:
        """Chiude STDIN, aspetta la fine, scrive le ultime righe."""
        try:
            if self.proc.stdin is not None:
                self.proc.stdin.close()
        except OSError:
            pass
        try:
            uscita = self.proc.wait(timeout=ATTESA_FINE)
        except subprocess.TimeoutExpired:
            self.proc.kill()
            uscita = self.proc.wait()
        while True:
            try:
                riga = self.coda.get(timeout=5)
            except queue.Empty:
                break
            if riga is None:
                break
            self.uscita.write(riga)
        self.uscita.close()
        self.errori.close()
        return uscita


def esegui_passi(proc: Processo, passi: List[Passo], copia: str,
                 parole: Dict[str, str], attesa: float,
                 fatti: List[dict]) -> None:
    """I passi, uno dopo l'altro; i loro dati, per sessione.json, in fatti,
    passo per passo: se uno fallisce, quelli di prima restano."""
    registro = os.path.join(copia, REGISTRO)
    for numero, passo in enumerate(passi, 1):
        inizio = ora()
        if passo.tipo == "modifica":
            time.sleep(secondi_da("PN_SESSIONE_PAUSA", PAUSA))
            sostituisci(os.path.join(copia, "CLAUDE.md"), parole["radice"],
                        parole["nuova"])
            print("  %d. CLAUDE.md riscritto da fuori: la parola ora è %s"
                  % (numero, parole["nuova"]), file=sys.stderr)
            righe = righe_del_registro(registro)
        else:
            print("  %d. → %s" % (numero, breve(passo.testo)),
                  file=sys.stderr)
            proc.manda(passo.testo)
            evento = proc.risultato(attesa)
            testo = evento.get("result") if isinstance(
                evento.get("result"), str) else ""
            turni = evento.get("num_turns")
            print("     ← %s (%s %s)" % (
                breve(testo) or "nessun testo", turni,
                "turno" if turni == 1 else "turni"), file=sys.stderr)
            if evento.get("is_error") or evento.get("subtype", "success") \
                    != "success":
                raise Fallita("claude ha restituito un errore al passo %d"
                              % numero)
            righe = assesta(registro)
        fatti.append({"passo": numero, "tipo": passo.tipo,
                      "testo": passo.testo, "inizio": inizio, "fine": ora(),
                      "caricamenti": righe})


def scrivi_json(percorso: str, dato: dict) -> None:
    with open(percorso, "w", encoding="utf-8") as fh:
        json.dump(dato, fh, ensure_ascii=False, indent=1)
        fh.write("\n")


def togli_copia(copia: str, copie: str) -> None:
    """Toglie la copia: mai un collegamento simbolico, mai fuori da copie."""
    vera = os.path.realpath(copia)
    if os.path.islink(copia) or os.path.dirname(vera) \
            != os.path.realpath(copie):
        return
    shutil.rmtree(vera, ignore_errors=True)


def attesa_di() -> float:
    valore = os.environ.get("PN_SESSIONE_ATTESA", "300")
    try:
        attesa = float(valore)
    except ValueError:
        attesa = 0
    if not 0 < attesa <= 3600:
        raise Precondizione("PN_SESSIONE_ATTESA vuole i secondi, da 1 a "
                            "3600, non «%s»" % valore)
    return attesa


def in_copia(tipo: str, nome: str, copia: str, deposito: str,
             parole: Dict[str, str], passi: List[Passo],
             strumenti: str) -> int:
    """La sessione nella copia: il processo, i passi, i file del deposito."""
    fatti: List[dict] = []
    esito = 0
    argv = comando_di(strumenti)
    print("  # %s" % nome, file=sys.stderr)
    print(mostra_comando(argv) + "\n", file=sys.stderr)
    proc = Processo(argv, copia, os.path.join(deposito, nome + ".jsonl"),
                    os.path.join(deposito, nome + ".stderr.txt"))
    try:
        esegui_passi(proc, passi, copia, parole, attesa_di(), fatti)
    except Fallita as exc:
        print("sessione.py: %s: %s" % (nome, exc), file=sys.stderr)
        esito = 1
    finally:
        uscita = proc.chiudi()
    try:
        shutil.copyfile(os.path.join(copia, REGISTRO),
                        os.path.join(deposito, nome + ".caricamenti.jsonl"))
    except OSError as exc:
        print("sessione.py: %s: il registro dell'hook non si copia: %s"
              % (nome, exc), file=sys.stderr)
        esito = 1
    scrivi_json(os.path.join(deposito, nome + ".sessione.json"),
                {"tipo": tipo, "parole": parole, "strumenti": strumenti,
                 "passi": fatti})
    if uscita != 0 and esito == 0:
        print("sessione.py: %s: claude è uscito con %d" % (nome, uscita),
              file=sys.stderr)
        esito = 1
    return esito


def sessione(tipo: str, nome: str, progetto: str, copie: str,
             deposito: str) -> int:
    qui = os.path.dirname(os.path.abspath(__file__))
    passi, strumenti = passi_di(tipo, qui)
    if shutil.which("claude") is None:
        raise Precondizione("manca claude")
    attesa_di()
    secondi_da("PN_SESSIONE_CALMA", CALMA)
    secondi_da("PN_SESSIONE_PAUSA", PAUSA)
    parole = parole_di(tipo)
    copia = prepara_copia(progetto, copie, nome, parole)
    try:
        return in_copia(tipo, nome, copia, deposito, parole, passi,
                        strumenti)
    finally:
        togli_copia(copia, copie)


def argomenti(argv: List[str]) -> Dict[str, str]:
    nomi = ("--tipo", "--nome", "--progetto", "--copie", "--deposito")
    valori: Dict[str, str] = {}
    i = 0
    while i < len(argv):
        if argv[i] not in nomi or i + 1 >= len(argv) or not argv[i + 1]:
            raise Precondizione("argomento non valido: %s" % argv[i])
        valori[argv[i]] = argv[i + 1]
        i += 2
    mancano = [n for n in nomi if n not in valori]
    if mancano:
        raise Precondizione("manca %s" % mancano[0])
    if valori["--tipo"] not in ("compact", "clear", "regola"):
        raise Precondizione("--tipo vuole compact, clear o regola")
    if not re.match(r"^[a-z]+-[1-9][0-9]*$", valori["--nome"]):
        raise Precondizione("--nome vuole <tipo>-<numero>")
    for nome in ("--progetto", "--copie", "--deposito"):
        if not os.path.isdir(valori[nome]):
            raise Precondizione("%s: non è una cartella: %s"
                                % (nome, valori[nome]))
    return valori


def main(argv: List[str]) -> int:
    for flusso in (sys.stdout, sys.stderr):
        riconfigura = getattr(flusso, "reconfigure", None)
        if riconfigura is not None:
            riconfigura(errors="replace")
    try:
        valori = argomenti(argv)
        return sessione(valori["--tipo"], valori["--nome"],
                        valori["--progetto"], valori["--copie"],
                        valori["--deposito"])
    except Precondizione as exc:
        print("sessione.py: %s" % exc, file=sys.stderr)
        return 2
    except Exception as exc:  # mai un traceback: un errore inatteso esce 2
        print("sessione.py: errore inatteso (%s: %s)"
              % (type(exc).__name__, " ".join(str(exc).split())),
              file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
