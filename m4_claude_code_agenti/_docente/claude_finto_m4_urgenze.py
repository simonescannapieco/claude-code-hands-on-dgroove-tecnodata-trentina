#!/usr/bin/env python3
"""claude_finto_m4_urgenze.py -- un claude finto per le prove di M4-D03,
M4-D05 e M4-D07 (test_m4_d03.sh, test_m4_d05.sh, test_m4_d07.sh).

Le suite lo copiano, con il nome «claude», davanti nel PATH: così i
live.sh e i blocchi dei README girano per intero senza chiamare il modello
e senza consumare il piano. Gli stream sono costruiti qui, inventati e
dichiarati finti: nessuno è una risposta di Claude. Imitano la forma dello
stream-json di claude -p (un evento JSON per riga: l'avvio, i messaggi
dell'assistente con il loro id e il loro usage, i risultati degli
strumenti, per ultima la riga del risultato) e fanno davvero sui file ciò
che lo stream racconta, perché i controlli rieseguono i test, leggono le
copie e le fotografie di git.

Che cosa fa, secondo il prompt:
  «finché i test passano» (M4-D03): legge urgenza.py, esegue i test,
      corregge il confine, li riesegue, risponde. FINTO_GIRO=non_corregge
      non corregge; FINTO_CALO=1 fa scendere l'entrata della richiesta che
      corregge; FINTO_COMPATTA=1 mette prima di quella richiesta un evento
      compact_boundary.
  «Riscrivi la docstring» (M4-D05): riscrive la docstring del modulo e
      prova a chiudere il turno. Se .claude/settings.json della cartella ha
      uno Stop hook lo esegue davvero (bash -c, nella cartella, con
      CLAUDE_PROJECT_DIR) e, finché esce con 2, scrive il messaggio «Stop
      hook feedback» e la notifica, poi reagisce come dice FINTO_STOP:
      corregge (il default: corregge il confine), allenta (cambia il test),
      ostinato (nessuno strumento: otto blocchi di fila, poi chiude), esce
      (chiude dopo il primo blocco: imita una garanzia che non tiene).
      FINTO_HOOK=ignora non esegue gli hook.
  «doctest» (M4-D07, l'esempio): aggiunge alla docstring di
      progetti/urgenze/urgenza.py un esempio con >>>.
  «giorni_di_apertura» (M4-D07, la rinomina): rinomina il parametro.
  -w <nome>: crea .claude/worktrees/<nome> sul ramo worktree-<nome> (git
      worktree add), lo blocca (git worktree lock: così la pulizia di
      live.sh prova anche un worktree bloccato) e lavora lì.
      FINTO_WT=ignora lavora nel checkout
      principale; FINTO_WT_RAMO=<prefisso> usa il ramo <prefisso><nome>;
      FINTO_WT_FUORI=1 modifica, con successo, anche il file del checkout
      principale; FINTO_WT_BLOCCATO=1 ci prova e riceve un errore;
      FINTO_WT_BLOCCATO=negato ci prova, riceve un errore e la chiamata è
      anche nell'elenco permission_denials del risultato;
      FINTO_WT_LOCK=0 non blocca il worktree.
Per tutti: --version; FINTO_ESITO=ko esce 1 senza stampare nulla;
FINTO_TRONCO=1 toglie la riga del risultato; FINTO_LOG riceve una riga
JSON per invocazione: {"argv": [...], "chiave": vero se ANTHROPIC_API_KEY
c'era, "cwd": la cartella da cui è partito}. Per una chiamata -p:
FINTO_PID=<file> vi aggiunge il pid del finto, una riga, e FINTO_DORMI=<s>
lo fa aspettare s secondi prima di rispondere (le prove dell'interruzione).
Un'opzione che non conosce: «error: unknown option», uscita 1; lo
stream-json lo dà soltanto con --verbose, come lo chiedono i live.sh e i
README.
Uscita: 0 risposta · 1 FINTO_ESITO=ko, un argomento rifiutato, un errore
di git o un file che manca
"""
import fcntl
import json
import os
import re
import subprocess
import sys
import time
from typing import Callable, Dict, List, Optional, Tuple

OPZIONI = {"-p": 0, "--print": 0, "--verbose": 0, "--strict-mcp-config": 0,
           "--no-session-persistence": 0, "--model": 1, "--effort": 1,
           "--tools": 1, "--allowedTools": 1, "--output-format": 1,
           "--permission-mode": 1, "--permission-prompts": 1,
           "--setting-sources": 1}
WORKTREE = ("-w", "--worktree")
FORMATI = ("text", "json", "stream-json")
MODELLO = "claude-finto"
VERSIONE = "0.0.0-finto"
SESSIONE = "sessione-finta"
ENTRATA = 17000
CRESCITA = 300
CALO = 500
TETTO = 8
URGENZA = "urgenza.py"
TEST = "test_urgenza.py"
PROGETTO = os.path.join("progetti", "urgenze")
CONFINE = ("giorni_aperta > 7", "giorni_aperta >= 7")
ALLENTA = ("self.assertTrue(urgente(1, 7))", "self.assertFalse(urgente(1, 7))")
ESEMPIO = ('\n"""\n', '\n\n>>> urgente(12, 0)\nTrue\n"""\n')
RINOMINA = ("giorni_aperta", "giorni_di_apertura")
AGGIORNATO = "The file %s has been updated successfully."
BLOCCATO = ("Finto: la modifica di %s è bloccata, il percorso è nel "
            "checkout principale.")
DOCSTRING = re.compile(r'\A"""(.*?)"""', re.S)
NUOVA_DOCSTRING = ('"""Urgenza di una segnalazione di guasto (docstring finta).'
                   '\n\nUrgente da 10 clienti, oppure dopo 7 giorni di '
                   'apertura.\n\n>>> urgente(12, 0)\nTrue\n"""')


class Rifiutato(Exception):
    """Argomenti o condizioni che il finto non accetta: il messaggio."""


def argomenti(argv: List[str]) -> Tuple[Dict[str, str], str, Optional[str]]:
    """(le opzioni con i loro valori, il prompt, il nome di -w o None)."""
    opzioni: Dict[str, str] = {}
    operandi: List[str] = []
    nome: Optional[str] = None
    i = 0
    while i < len(argv):
        parola = argv[i]
        if parola == "--":
            operandi += argv[i + 1:]
            break
        if parola in WORKTREE:
            if i + 1 < len(argv) and not argv[i + 1].startswith("-"):
                nome = argv[i + 1]
                i += 2
                continue
            raise Rifiutato("error: il claude finto vuole un nome per -w")
        if not parola.startswith("-"):
            operandi.append(parola)
            i += 1
            continue
        if parola not in OPZIONI:
            raise Rifiutato("error: unknown option '%s'" % parola)
        valori = OPZIONI[parola]
        if i + valori >= len(argv):
            raise Rifiutato("error: option '%s' argument missing" % parola)
        opzioni[parola] = argv[i + 1] if valori else ""
        i += 1 + valori
    if len(operandi) != 1:
        raise Rifiutato("error: %s" % (
            "too many arguments" if operandi else "missing prompt"))
    formato = opzioni.get("--output-format", "text")
    if formato not in FORMATI:
        raise Rifiutato("error: unknown output format '%s'" % formato)
    if formato != "stream-json":
        raise Rifiutato("error: il claude finto di M4 vuole "
                        "--output-format stream-json")
    if "--verbose" not in opzioni:
        raise Rifiutato("error: --output-format stream-json requires "
                        "--verbose")
    return opzioni, operandi[0], nome


class Flusso:
    """Lo stream finto di una sessione: gli eventi, nell'ordine."""

    def __init__(self, cwd: str, modo: str) -> None:
        self.cwd = cwd
        self.richieste = 0
        self.strumenti = 0
        self.entrata = ENTRATA
        self.dinieghi: List[dict] = []
        self.eventi: List[dict] = [{
            "type": "system", "subtype": "init", "cwd": cwd,
            "session_id": SESSIONE, "model": MODELLO,
            "permissionMode": modo, "claude_code_version": VERSIONE,
            "apiKeySource": "none", "tools": ["Bash", "Edit", "Read"]}]

    def richiesta(self, blocchi: List[dict],
                  entrata: Optional[int] = None) -> None:
        """Una richiesta al modello: un id, un evento per blocco, lo stesso
        usage in ognuno."""
        self.richieste += 1
        if entrata is None:
            entrata = self.entrata + CRESCITA
        self.entrata = entrata
        usage = {"input_tokens": 2, "cache_creation_input_tokens": 100,
                 "cache_read_input_tokens": entrata - 102,
                 "output_tokens": 9}
        ident = "msg_finto_%02d" % self.richieste
        for blocco in blocchi:
            self.eventi.append({
                "type": "assistant", "parent_tool_use_id": None,
                "session_id": SESSIONE,
                "message": {"id": ident, "role": "assistant",
                            "model": MODELLO, "content": [blocco],
                            "usage": dict(usage)}})

    def chiama(self, nome: str, ingresso: dict, esito: str,
               errore: bool = False, testo: str = "",
               entrata: Optional[int] = None) -> str:
        """Una richiesta con una chiamata a uno strumento (e un testo
        prima, se c'è), poi il suo risultato; l'id della chiamata."""
        self.strumenti += 1
        ident = "toolu_finto_%02d" % self.strumenti
        blocchi = [{"type": "text", "text": testo}] if testo else []
        blocchi.append({"type": "tool_use", "id": ident, "name": nome,
                        "input": ingresso})
        self.richiesta(blocchi, entrata)
        risultato = {"type": "tool_result", "tool_use_id": ident,
                     "content": esito}
        if errore:
            risultato["is_error"] = True
        self.eventi.append({"type": "user", "parent_tool_use_id": None,
                            "session_id": SESSIONE,
                            "message": {"role": "user",
                                        "content": [risultato]}})
        return ident

    def testo(self, testo: str) -> None:
        """Una richiesta che risponde soltanto, senza strumenti."""
        self.richiesta([{"type": "text", "text": testo}])

    def blocco_stop(self, comando: str, stderr: str) -> None:
        """Il messaggio sintetico e la notifica di uno Stop hook che
        blocca."""
        self.eventi.append({
            "type": "user", "isSynthetic": True, "parent_tool_use_id": None,
            "session_id": SESSIONE,
            "message": {"role": "user", "content": [{
                "type": "text",
                "text": "Stop hook feedback:\n[%s]: %s" % (comando,
                                                          stderr)}]}})
        self.eventi.append({"type": "system", "subtype": "notification",
                            "key": "stop-hook-error",
                            "text": "Stop hook error occurred",
                            "priority": "immediate",
                            "session_id": SESSIONE})

    def compattazione(self) -> None:
        """L'evento che segna una compattazione."""
        self.eventi.append({"type": "system", "subtype": "compact_boundary",
                            "session_id": SESSIONE})

    def fine(self, testo: str) -> None:
        """La riga del risultato."""
        self.eventi.append({
            "type": "result", "subtype": "success", "is_error": False,
            "result": testo, "num_turns": self.richieste,
            "duration_ms": 1000 * self.richieste, "session_id": SESSIONE,
            "stop_reason": "end_turn", "terminal_reason": "completed",
            "permission_denials": self.dinieghi,
            "usage": {"input_tokens": 2 * self.richieste,
                      "output_tokens": 9 * self.richieste}})


def numerato(percorso: str) -> str:
    """Il contenuto di un file con i numeri di riga, come lo dà Read."""
    with open(percorso, encoding="utf-8") as fh:
        righe = fh.read().splitlines()
    return "\n".join("%d\t%s" % (n, r) for n, r in enumerate(righe, 1))


def modifica(percorso: str, cambia: Callable[[str], str]) -> None:
    """Legge, cambia e riscrive un file sotto un lock esclusivo: due
    sessioni finte sullo stesso file non perdono la modifica dell'altra."""
    with open(percorso, "r+", encoding="utf-8") as fh:
        fcntl.flock(fh, fcntl.LOCK_EX)
        try:
            nuovo = cambia(fh.read())
            fh.seek(0)
            fh.write(nuovo)
            fh.truncate()
        finally:
            fcntl.flock(fh, fcntl.LOCK_UN)


def sostituisci(vecchio: str, nuovo: str,
                tutte: bool = False) -> Callable[[str], str]:
    """La funzione che sostituisce vecchio con nuovo (una volta o tutte);
    Rifiutato se vecchio non c'è."""
    def cambia(testo: str) -> str:
        if vecchio not in testo:
            raise Rifiutato("il testo da sostituire non c'è: %r" % vecchio)
        return testo.replace(vecchio, nuovo, -1 if tutte else 1)
    return cambia


def edit(flusso: Flusso, percorso: str, vecchio: str, nuovo: str,
         tutte: bool = False, testo: str = "") -> None:
    """Un Edit vero sul file e la sua chiamata nello stream."""
    modifica(percorso, sostituisci(vecchio, nuovo, tutte))
    flusso.chiama("Edit", {"file_path": percorso, "old_string": vecchio,
                           "new_string": nuovo, "replace_all": tutte},
                  AGGIORNATO % percorso, testo=testo)


def giro(flusso: Flusso) -> str:
    """M4-D03: test, correzione, test."""
    file_ = os.path.join(flusso.cwd, URGENZA)
    flusso.chiama("Read", {"file_path": file_}, numerato(file_))
    flusso.chiama("Bash", {"command": "python3 -m unittest"},
                  "FAILED (failures=1)", errore=True)
    if os.environ.get("FINTO_GIRO") == "non_corregge":
        flusso.testo("Risposta finta: non correggo niente.")
        return "Risposta finta del claude finto: nessuna correzione."
    entrata = None
    if os.environ.get("FINTO_CALO") == "1":
        if os.environ.get("FINTO_COMPATTA") == "1":
            flusso.compattazione()
        entrata = flusso.entrata - CALO
    modifica(file_, sostituisci(*CONFINE))
    flusso.chiama("Edit", {"file_path": file_, "old_string": CONFINE[0],
                           "new_string": CONFINE[1], "replace_all": False},
                  AGGIORNATO % file_, testo="Testo finto: correggo.",
                  entrata=entrata)
    flusso.chiama("Bash", {"command": "python3 -m unittest"}, "OK")
    flusso.testo("Risposta finta: i test passano.")
    return "Risposta finta del claude finto: i test passano."


def stop_hook(cwd: str) -> List[str]:
    """I comandi degli Stop hook di .claude/settings.json della cartella."""
    try:
        with open(os.path.join(cwd, ".claude", "settings.json"),
                  encoding="utf-8") as fh:
            impostazioni = json.load(fh)
    except (OSError, ValueError):
        return []
    comandi = []
    for voce in impostazioni.get("hooks", {}).get("Stop", []):
        for hook in voce.get("hooks", []):
            if hook.get("type") == "command" and hook.get("command"):
                comandi.append(hook["command"])
    return comandi


def esegui_hook(comandi: List[str], cwd: str) -> Tuple[int, str, str]:
    """Esegue gli Stop hook; (uscita, comando, stderr) del primo che esce
    con 2, oppure (0, "", "")."""
    ambiente = dict(os.environ, CLAUDE_PROJECT_DIR=cwd)
    for comando in comandi:
        fatto = subprocess.run(["bash", "-c", comando], cwd=cwd,
                               env=ambiente, stdout=subprocess.PIPE,
                               stderr=subprocess.PIPE,
                               universal_newlines=True, timeout=120)
        if fatto.returncode == 2:
            return 2, comando, fatto.stderr
    return 0, "", ""


def docstring(flusso: Flusso) -> str:
    """M4-D05: la docstring, poi la fine del turno con gli Stop hook."""
    file_ = os.path.join(flusso.cwd, URGENZA)
    flusso.chiama("Read", {"file_path": file_}, numerato(file_))
    with open(file_, encoding="utf-8") as fh:
        trovata = DOCSTRING.match(fh.read())
    if not trovata:
        raise Rifiutato("urgenza.py senza docstring del modulo")
    edit(flusso, file_, trovata.group(0), NUOVA_DOCSTRING)
    flusso.testo("Risposta finta: ho riscritto la docstring.")
    comandi = [] if os.environ.get("FINTO_HOOK") == "ignora" \
        else stop_hook(flusso.cwd)
    modo = os.environ.get("FINTO_STOP", "corregge")
    di_fila = 0
    while comandi:
        uscita, comando, stderr = esegui_hook(comandi, flusso.cwd)
        if uscita != 2:
            break
        flusso.blocco_stop(comando, stderr)
        if modo == "esce":
            break
        if modo == "ostinato":
            di_fila += 1
            flusso.testo("Risposta finta: ho finito (%d)." % di_fila)
            if di_fila >= TETTO:
                break
            continue
        di_fila = 0
        if modo == "allenta":
            edit(flusso, os.path.join(flusso.cwd, TEST), *ALLENTA)
        else:
            edit(flusso, file_, *CONFINE)
        flusso.testo("Risposta finta: ora il controllo passa.")
    return "Risposta finta del claude finto: la docstring è riscritta."


def principale(cwd: str) -> str:
    """La cima del repository git che contiene cwd."""
    fatto = subprocess.run(["git", "-C", cwd, "rev-parse",
                            "--show-toplevel"], stdout=subprocess.PIPE,
                           stderr=subprocess.PIPE, universal_newlines=True)
    if fatto.returncode != 0:
        raise Rifiutato("-w fuori da un repository git")
    return fatto.stdout.strip()


def worktree(cwd: str, nome: str) -> Tuple[str, str]:
    """Crea il worktree di -w come lo crea Claude Code; (il worktree, il
    checkout principale)."""
    cima = principale(cwd)
    if os.environ.get("FINTO_WT") == "ignora":
        return cwd, cima
    percorso = os.path.join(cima, ".claude", "worktrees", nome)
    ramo = os.environ.get("FINTO_WT_RAMO", "worktree-") + nome
    for comando in (["worktree", "add", "-q", "-b", ramo, percorso, "HEAD"],
                    ["worktree", "lock", "--reason", "sessione finta",
                     percorso]):
        if comando[1] == "lock" and os.environ.get("FINTO_WT_LOCK") == "0":
            continue
        fatto = subprocess.run(["git", "-C", cima] + comando,
                               stdout=subprocess.PIPE,
                               stderr=subprocess.PIPE,
                               universal_newlines=True)
        if fatto.returncode != 0:
            raise Rifiutato("git %s: %s" % (comando[1],
                                            fatto.stderr.strip()))
    return percorso, cima


def parallela(flusso: Flusso, cima: str, rinomina: bool) -> str:
    """M4-D07: l'esempio o la rinomina in progetti/urgenze/urgenza.py
    della cartella della sessione."""
    file_ = os.path.join(flusso.cwd, PROGETTO, URGENZA)
    fuori = os.path.join(cima, PROGETTO, URGENZA)
    vecchio, nuovo = RINOMINA if rinomina else ESEMPIO
    flusso.chiama("Read", {"file_path": file_}, numerato(file_))
    bloccato = os.environ.get("FINTO_WT_BLOCCATO", "")
    if fuori != file_ and bloccato in ("1", "negato"):
        ingresso = {"file_path": fuori, "old_string": vecchio,
                    "new_string": nuovo, "replace_all": rinomina}
        ident = flusso.chiama("Edit", ingresso, BLOCCATO % fuori,
                              errore=True)
        if bloccato == "negato":
            flusso.dinieghi.append({"tool_name": "Edit",
                                    "tool_use_id": ident,
                                    "tool_input": ingresso})
    if fuori != file_ and os.environ.get("FINTO_WT_FUORI") == "1":
        edit(flusso, fuori, vecchio, nuovo, rinomina)
    edit(flusso, file_, vecchio, nuovo, rinomina)
    if rinomina:
        test = os.path.join(flusso.cwd, PROGETTO, TEST)
        flusso.chiama("Read", {"file_path": test}, numerato(test))
    flusso.testo("Risposta finta: fatto.")
    return "Risposta finta del claude finto: fatto."


def registra(argv: List[str]) -> None:
    """Una riga in FINTO_LOG, se c'è."""
    log = os.environ.get("FINTO_LOG")
    if log:
        with open(log, "a", encoding="utf-8") as fh:
            fh.write(json.dumps({
                "argv": argv, "cwd": os.getcwd(),
                "chiave": bool(os.environ.get("ANTHROPIC_API_KEY"))},
                ensure_ascii=False) + "\n")


def sessione(opzioni: Dict[str, str], prompt: str,
             nome: Optional[str]) -> Flusso:
    """La sessione finta che il prompt chiede, nella cartella giusta."""
    cwd, cima = os.getcwd(), ""
    if nome is not None:
        cwd, cima = worktree(cwd, nome)
    elif "progetti/urgenze/" in prompt:
        cima = principale(cwd)
    flusso = Flusso(cwd, opzioni.get("--permission-mode", "default"))
    if "finché i test passano" in prompt:
        testo = giro(flusso)
    elif "Riscrivi la docstring" in prompt:
        testo = docstring(flusso)
    elif "giorni_di_apertura" in prompt:
        testo = parallela(flusso, cima, rinomina=True)
    elif "doctest" in prompt:
        testo = parallela(flusso, cima, rinomina=False)
    else:
        raise Rifiutato("il claude finto non conosce questo prompt")
    flusso.fine(testo)
    return flusso


def attesa() -> None:
    """FINTO_PID e FINTO_DORMI: il pid in un file, poi l'attesa, per le
    prove che interrompono una sessione in corso."""
    file_pid = os.environ.get("FINTO_PID")
    if file_pid:
        with open(file_pid, "a", encoding="utf-8") as fh:
            fh.write("%d\n" % os.getpid())
    secondi = os.environ.get("FINTO_DORMI")
    if secondi:
        time.sleep(float(secondi))


def main(argv: List[str]) -> int:
    registra(argv)
    if argv[:1] == ["--version"]:
        print("0.0.0 (Claude Code, finto)")
        return 0
    try:
        opzioni, prompt, nome = argomenti(argv)
        if os.environ.get("FINTO_ESITO", "ok") != "ok":
            return 1
        attesa()
        flusso = sessione(opzioni, prompt, nome)
    except Rifiutato as exc:
        sys.stderr.write("%s\n" % exc)
        return 1
    eventi = flusso.eventi
    if os.environ.get("FINTO_TRONCO") == "1":
        eventi = eventi[:-1]
    for evento in eventi:
        print(json.dumps(evento, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
