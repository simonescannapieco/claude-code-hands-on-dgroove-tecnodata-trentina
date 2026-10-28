#!/usr/bin/env python3
"""verifica.py di M4-E02 «Una funzione nuova, con i test»: i controlli di
verifica.sh.

Legge lo spazio di lavoro con git (il primo commit è il punto di partenza)
e non si fida degli script dello spazio di lavoro: esegue PHPUnit con
tools/php.sh del repository (PN_HANDSON_ROOT), o con PN_PHP_SH.

Decidono l'uscita:
  - almeno un file di test nuovo o cambiato sotto
    progetti/gestionale-php/tests/ (anche già in un commit);
  - la suite intera passa sul codice dello spazio di lavoro, e i test
    nuovi, eseguiti per nome, passano anche loro;
  - i test nuovi falliscono sul codice di partenza: in una copia del
    gestionale al primo commit, con i test nuovi e vendor/, devono cadere,
    perché lì la funzione manca. Il giudice va provato sul codice che non
    ha ciò che il giudice controlla;
  - la garanzia del revisore: un subagent con soli tools Read, Grep, Glob
    non modifica niente. Se la trascrizione del revisore contiene uno
    strumento che modifica, è una segnalazione. Se la sua definizione
    nello spazio di lavoro ha altri strumenti, la garanzia non si applica.
    Se le trascrizioni riconosciute sono meno delle chiamate al revisore,
    «non distinguibile»: una chiamata senza trascrizione non si controlla.
Come dati, mai come uscita: NOTA.md, i commit dopo il punto di partenza, i
file cambiati, le sessioni di Claude Code dello spazio di lavoro e le
chiamate al tool Agent, per tipo di subagent («nessun subagent trovato»
se non ce ne sono).

Le sessioni stanno in ~/.claude/projects/<cartella>/ (PN_CLAUDE_DIR al
posto di ~/.claude per le prove del docente): <sessione>.jsonl, e i
subagent in <sessione>/subagents/agent-<id>.jsonl. La <cartella> è il
percorso dello spazio di lavoro con ogni carattere che non è una lettera o
una cifra cambiato in «-»: la forma dei nomi delle cartelle che Claude
Code 2.1.312 ha creato per gli spazi di lavoro del corso. La verifica
riconosce la trascrizione del revisore da uno di tre segni: accanto alla
trascrizione cerca un agent-<id>.meta.json che porti il valore
«revisore» (un file che la verifica legge se c'è, non uno che la
documentazione di Claude Code promette); il primo messaggio della
trascrizione è il prompt di una chiamata Agent con subagent_type
«revisore»; il risultato di quella chiamata nomina il suo <id>. Una
trascrizione che non si legge ferma la verifica (uscita 2): la garanzia
non si decide su ciò che non si è letto.

Uso:    verifica.py <spazio di lavoro>
Uscita: 0 fatto · 1 non ancora, o il revisore ha modificato · 2 precondizione
        (spazio di lavoro, git, il gestionale, lo strumento per PHP,
        vendor/, PHP che non si avvia, una trascrizione che non si legge)
        o un errore inatteso: mai un «fatto» quando non può decidere
"""
import glob
import io
import json
import os
import re
import shutil
import subprocess
import sys
import tarfile
import tempfile
from typing import Dict, Iterator, List, Optional, Set, Tuple

PROGETTO = "progetti/gestionale-php"
TESTS = PROGETTO + "/tests/"
AGENT = ("Agent", "Task")
MODIFICA = ("Edit", "Write", "NotebookEdit", "MultiEdit")
LETTURA = {"Read", "Grep", "Glob"}
REVISORE = "revisore"
TUTTI = "tutti gli strumenti"
FILE_MOSTRATI = 15


class Precondizione(Exception):
    """Un controllo che non può partire: il messaggio, uscita 2."""


def git(ws: str, *argomenti: str) -> bytes:
    """L'uscita di un comando git nello spazio di lavoro."""
    try:
        fatto = subprocess.run(["git", "-C", ws] + list(argomenti),
                               stdout=subprocess.PIPE,
                               stderr=subprocess.PIPE, check=False)
    except OSError:
        raise Precondizione("manca git")
    if fatto.returncode != 0:
        raise Precondizione("%s non è uno spazio di lavoro preparato "
                            "(git: %s)" % (ws, fatto.stderr.decode(
                                "utf-8", "replace").strip()[:200]))
    return fatto.stdout


def punto_di_partenza(ws: str) -> str:
    """Il primo commit dello spazio di lavoro."""
    if not os.path.isdir(os.path.join(ws, ".git")):
        raise Precondizione("%s non è uno spazio di lavoro preparato "
                            "(manca il repository git)" % ws)
    radici = git(ws, "rev-list", "--max-parents=0", "HEAD").split()
    if len(radici) != 1:
        raise Precondizione("%s non è uno spazio di lavoro preparato "
                            "(atteso un solo primo commit)" % ws)
    return radici[0].decode()


def cambiati(ws: str, base: str) -> List[Tuple[str, str]]:
    """(percorso, «nuovo»|«cambiato»|«cancellato») rispetto al primo commit,
    compresi i file nuovi non ancora aggiunti a git."""
    parti = git(ws, "diff", "--name-status", "--no-renames", "-z",
                base).decode("utf-8", "replace").split("\0")
    nomi = {"A": "nuovo", "D": "cancellato"}
    elenco = [(parti[i + 1], nomi.get(parti[i][:1], "cambiato"))
              for i in range(0, len(parti) - 1, 2) if parti[i]]
    nuovi = git(ws, "ls-files", "--others", "--exclude-standard",
                "-z").decode("utf-8", "replace").split("\0")
    elenco += [(p, "nuovo") for p in nuovi if p]
    return sorted(set(elenco))


def leggi(percorso: str) -> str:
    with open(percorso, encoding="utf-8", errors="replace") as fh:
        return fh.read()


def strumento_php() -> str:
    """tools/php.sh del repository (o PN_PHP_SH), che deve esserci."""
    radice = os.environ.get("PN_HANDSON_ROOT") or os.path.normpath(
        os.path.join(os.path.dirname(os.path.abspath(__file__)),
                     *[os.pardir] * 4))
    php = os.environ.get("PN_PHP_SH") or os.path.join(radice, "tools",
                                                      "php.sh")
    if not (os.path.isfile(php) and os.access(php, os.X_OK)):
        raise Precondizione("manca lo strumento per PHP: %s (tools/php.sh "
                            "del repository)" % php)
    return php


def phpunit(php: str, cartella: str, file: List[str]) -> Tuple[int, str]:
    """PHPUnit nella cartella del progetto, sui file dati o sulla suite;
    uscita e testo. Un'uscita 2 con un messaggio di php.sh è una
    precondizione; un 2 di PHPUnit è un errore nei test."""
    fatto = subprocess.run([php, "phpunit", "--colors=never"] + file,
                           cwd=cartella, stdout=subprocess.PIPE,
                           stderr=subprocess.PIPE, check=False)
    errori = fatto.stderr.decode("utf-8", "replace")
    if fatto.returncode == 2 and "php.sh:" in errori:
        raise Precondizione("PHP non si avvia: %s (PRIMA_DEL_CORSO.md, "
                            "«Docker, oppure PHP e Composer»)"
                            % errori.strip()[:300])
    return fatto.returncode, fatto.stdout.decode("utf-8", "replace") + errori


def ultima(testo: str) -> str:
    """L'ultima riga non vuota di un'uscita di PHPUnit."""
    righe = [r.strip() for r in testo.splitlines() if r.strip()]
    return righe[-1] if righe else "(nessuna uscita)"


def estrai(dati: bytes, destinazione: str) -> None:
    """Estrae l'archivio di git, solo percorsi dentro il gestionale."""
    with tarfile.open(fileobj=io.BytesIO(dati)) as archivio:
        membri = [m for m in archivio.getmembers()
                  if m.name.startswith(PROGETTO + "/") and ".." not in
                  m.name.split("/") and not m.issym() and not m.islnk()]
        archivio.extractall(destinazione, members=membri)


def giudice(ws: str, base: str, test: List[str], php: str) -> Tuple[int, str]:
    """I test nuovi sul codice di partenza: una copia del gestionale al
    primo commit, con i file nuovi o cambiati di tests/ e vendor/."""
    with tempfile.TemporaryDirectory(prefix="verifica-m4-e02.") as tmp:
        dati = subprocess.run(["git", "-C", ws, "archive", "--format=tar",
                               base, PROGETTO], stdout=subprocess.PIPE,
                              stderr=subprocess.DEVNULL, check=False)
        if dati.returncode != 0:
            raise Precondizione("git archive non riesce sul primo commit")
        estrai(dati.stdout, tmp)
        copia = os.path.join(tmp, PROGETTO)
        for rel in test:
            destinazione = os.path.join(tmp, rel)
            os.makedirs(os.path.dirname(destinazione), exist_ok=True)
            shutil.copyfile(os.path.join(ws, rel), destinazione)
        shutil.copytree(os.path.join(ws, PROGETTO, "vendor"),
                        os.path.join(copia, "vendor"), symlinks=True)
        return phpunit(php, copia, eseguibili(test))


def eseguibili(test: List[str]) -> List[str]:
    """I file di test (…Test.php), relativi alla cartella del gestionale."""
    return [t[len(PROGETTO) + 1:] for t in test if t.endswith("Test.php")]


def lavoro(ws: str, base: str, test: List[str], manca: List[str]) -> None:
    """La suite, i test nuovi sul codice nuovo e su quello di partenza."""
    php = strumento_php()
    progetto = os.path.join(ws, PROGETTO)
    if not os.path.isfile(os.path.join(progetto, "vendor", "bin", "phpunit")):
        raise Precondizione(
            "mancano le dipendenze del gestionale (vendor/): dalla radice "
            "dello spazio di lavoro, tools/php.sh composer install -d "
            "progetti/gestionale-php")
    rc, testo = phpunit(php, progetto, [])
    print("\nla suite intera, sul vostro codice: %s\n  | %s"
          % ("passa" if rc == 0 else "non passa (uscita %d)" % rc,
             ultima(testo)))
    if rc != 0:
        manca.append("la suite non passa")
    rc, testo = phpunit(php, progetto, eseguibili(test))
    print("i test nuovi, sul vostro codice: %s\n  | %s"
          % ("passano" if rc == 0 else "non passano (uscita %d)" % rc,
             ultima(testo)))
    if rc != 0:
        manca.append("i test nuovi non passano sul vostro codice")
    rc, testo = giudice(ws, base, test, php)
    if rc != 0:
        print("i test nuovi, sul codice di partenza (una copia al primo "
              "commit): falliscono,\ncome devono: il giudice è valido")
    else:
        print("i test nuovi, sul codice di partenza (una copia al primo "
              "commit): passano\nanche lì, quindi non provano la funzione "
              "nuova")
        manca.append("i test nuovi passano anche sul codice di partenza: "
                     "non provano la funzione nuova")
    print("  | %s" % ultima(testo))


def dati_lavoro(ws: str, base: str, elenco: List[Tuple[str, str]]) -> None:
    """NOTA.md, i commit, i file cambiati: dati."""
    nota = os.path.join(ws, "NOTA.md")
    righe = [r for r in leggi(nota).splitlines() if r.strip()] \
        if os.path.isfile(nota) else []
    print("\n(dato) NOTA.md: %s" % ("c'è, %d righe non vuote" % len(righe)
                                    if righe else "non c'è"))
    commit = git(ws, "rev-list", "--count", "%s..HEAD" % base).decode().strip()
    print("(dato) commit dopo il punto di partenza: %s" % commit)
    print("(dato) file cambiati dal punto di partenza: %d" % len(elenco))
    for percorso, stato in elenco[:FILE_MOSTRATI]:
        print("  %s (%s)" % (percorso, stato))
    if len(elenco) > FILE_MOSTRATI:
        print("  … e altri %d" % (len(elenco) - FILE_MOSTRATI))


def cartella_sessioni(ws: str) -> str:
    """La cartella delle sessioni di Claude Code dello spazio di lavoro."""
    base = os.environ.get("PN_CLAUDE_DIR") or os.path.join(
        os.path.expanduser("~"), ".claude")
    return os.path.join(base, "projects", re.sub(r"[^A-Za-z0-9]", "-", ws))


def righe_json(percorso: str) -> Iterator[dict]:
    """Le righe JSON (oggetti) di una trascrizione; le altre si saltano.
    Una trascrizione che non si apre è una precondizione, mai «nessuno
    strumento»."""
    try:
        fh = open(percorso, encoding="utf-8", errors="replace")
    except OSError as exc:
        raise Precondizione("una trascrizione di Claude Code non si legge: "
                            "%s (%s)" % (percorso, exc.strerror
                                         or type(exc).__name__))
    with fh:
        for riga in fh:
            try:
                oggetto = json.loads(riga)
            except ValueError:
                continue
            if isinstance(oggetto, dict):
                yield oggetto


def blocchi(oggetto: dict, ruolo: str, tipo: str) -> List[dict]:
    """I blocchi di un tipo nel messaggio di una riga del ruolo dato."""
    messaggio = oggetto.get("message")
    if oggetto.get("type") != ruolo or not isinstance(messaggio, dict):
        return []
    contenuto = messaggio.get("content")
    if not isinstance(contenuto, list):
        return []
    return [b for b in contenuto if isinstance(b, dict)
            and b.get("type") == tipo]


def chiamate(sessioni: List[str]) -> Tuple[List[dict], Dict[str, str]]:
    """Le chiamate Agent delle conversazioni principali (id, tipo,
    prompt) e il testo dei loro risultati, per id."""
    trovate = {}  # type: Dict[str, dict]
    risultati = {}  # type: Dict[str, str]
    for percorso in sessioni:
        for oggetto in righe_json(percorso):
            if oggetto.get("isSidechain") is True:
                continue
            for b in blocchi(oggetto, "assistant", "tool_use"):
                if b.get("name") in AGENT and isinstance(b.get("id"), str):
                    ingresso = b.get("input") if isinstance(
                        b.get("input"), dict) else {}
                    trovate[b["id"]] = {
                        "id": b["id"],
                        "tipo": str(ingresso.get("subagent_type")
                                    or "general-purpose"),
                        "prompt": str(ingresso.get("prompt") or "")}
            for b in blocchi(oggetto, "user", "tool_result"):
                risultati[str(b.get("tool_use_id"))] = json.dumps(
                    b.get("content"), ensure_ascii=False)
    return list(trovate.values()), {
        k: v for k, v in risultati.items() if k in trovate}


def valori(oggetto, profondita: int = 3) -> Set[str]:
    """I valori stringa di un JSON, fino a una certa profondità."""
    if isinstance(oggetto, str):
        return {oggetto}
    if profondita == 0:
        return set()
    figli = oggetto.values() if isinstance(oggetto, dict) else (
        oggetto if isinstance(oggetto, list) else [])
    insieme = set()  # type: Set[str]
    for figlio in figli:
        insieme |= valori(figlio, profondita - 1)
    return insieme


def piatto(testo: str) -> str:
    return " ".join(testo.split())


def primo_messaggio(percorso: str) -> str:
    """Il testo del primo messaggio dell'utente in una trascrizione."""
    for oggetto in righe_json(percorso):
        messaggio = oggetto.get("message")
        if oggetto.get("type") != "user" or not isinstance(messaggio, dict):
            continue
        contenuto = messaggio.get("content")
        if isinstance(contenuto, str):
            return piatto(contenuto)
        if isinstance(contenuto, list):
            return piatto(" ".join(str(b.get("text", "")) for b in contenuto
                                   if isinstance(b, dict)))
    return ""


def strumenti_usati(percorso: str) -> List[str]:
    """I nomi degli strumenti chiamati in una trascrizione."""
    return [str(b.get("name")) for oggetto in righe_json(percorso)
            for b in blocchi(oggetto, "assistant", "tool_use")]


def del_revisore(cartella: str, revisioni: List[dict],
                 risultati: Dict[str, str]) -> List[Tuple[str, str]]:
    """(agentId, trascrizione) dei subagent riconosciuti come il revisore."""
    prompt = [piatto(c["prompt"]) for c in revisioni
              if len(piatto(c["prompt"])) >= 20]
    testi = " ".join(risultati.get(c["id"], "") for c in revisioni)
    trovate = []
    for file in sorted(glob.glob(os.path.join(cartella, "*", "subagents",
                                              "agent-*.jsonl"))):
        ident = os.path.basename(file)[len("agent-"):-len(".jsonl")]
        meta = file[:-len(".jsonl")] + ".meta.json"
        try:
            dal_meta = REVISORE in valori(json.loads(leggi(meta)))
        except (OSError, ValueError):
            dal_meta = False
        primo = primo_messaggio(file)
        dal_prompt = any(p == primo or p in primo for p in prompt)
        dal_risultato = bool(re.search(r"(?<![0-9A-Za-z])%s(?![0-9A-Za-z])"
                                       % re.escape(ident), testi))
        if dal_meta or dal_prompt or dal_risultato:
            trovate.append((ident, file))
    return trovate


def strumenti_revisore(ws: str) -> Optional[Set[str]]:
    """Gli strumenti della definizione del revisore nello spazio di
    lavoro; None se la definizione non c'è; {TUTTI} senza «tools»."""
    percorso = os.path.join(ws, ".claude", "agents", "revisore.md")
    if not os.path.isfile(percorso):
        return None
    testa = re.match(r"---\s*\n(.*?)\n---", leggi(percorso), re.S)
    righe = testa.group(1).splitlines() if testa else []
    for i, riga in enumerate(righe):
        if riga.startswith("tools:"):
            valore = riga.split(":", 1)[1].strip()
            if valore:
                return {s.strip() for s in valore.split(",") if s.strip()}
            return {r.split("-", 1)[1].strip() for r in righe[i + 1:]
                    if re.match(r"\s*-\s+", r)}
    return {TUTTI}


def revisore(ws: str, cartella: str, trovate: List[dict],
             risultati: Dict[str, str]) -> Optional[str]:
    """La garanzia del revisore; una segnalazione, o None."""
    revisioni = [c for c in trovate if c["tipo"] == REVISORE]
    if not revisioni:
        print("(dato) il revisore non è stato chiamato in queste sessioni: "
              "nessun esito sulla garanzia")
        return None
    definiti = strumenti_revisore(ws)
    if definiti is None or not definiti <= LETTURA:
        print("la definizione del revisore nello spazio di lavoro ha %s: la "
              "garanzia non si applica" % (", ".join(sorted(definiti))
                                          if definiti else "nessun file"))
        return None
    sue = del_revisore(cartella, revisioni, risultati)
    if not sue:
        print("il revisore è stato chiamato %d volte, ma la sua trascrizione "
              "non si riconosce: nessun esito sulla garanzia"
              % len(revisioni))
        return None
    usati = {ident: [s for s in strumenti_usati(f) if s in MODIFICA]
             for ident, f in sue}
    if any(usati.values()):
        elenco = "; ".join("agent-%s: %s" % (i, ", ".join(s))
                           for i, s in sorted(usati.items()) if s)
        print("il revisore (tools: %s) ha usato strumenti che modificano: %s"
              % (", ".join(sorted(definiti)), elenco))
        return ("il revisore ha usato uno strumento che modifica: una "
                "garanzia di Claude Code che qui non ha tenuto")
    if len(sue) < len(revisioni):
        print("il revisore (tools: %s): %d %s su %d chiamate, nessuno "
              "strumento che modifica: non distinguibile"
              % (", ".join(sorted(definiti)), len(sue),
                 "trascrizione" if len(sue) == 1 else "trascrizioni",
                 len(revisioni)))
        return None
    print("il revisore (tools: %s): %d trascrizioni, nessuno strumento che "
          "modifica: la garanzia vale" % (", ".join(sorted(definiti)),
                                          len(sue)))
    return None


def sessioni(ws: str) -> Optional[str]:
    """Le sessioni e le chiamate Agent come dati; la garanzia del revisore."""
    cartella = cartella_sessioni(ws)
    file = sorted(glob.glob(os.path.join(cartella, "*.jsonl")))
    if not file:
        print("\n(dato) nessuna sessione di Claude Code in %s" % cartella)
        print("(dato) nessun subagent trovato")
        return None
    print("\n(dato) sessioni di Claude Code di questo spazio di lavoro: %d, "
          "in\n       %s" % (len(file), cartella))
    trovate, risultati = chiamate(file)
    if not trovate:
        print("(dato) nessun subagent trovato")
        return None
    tipi = {}  # type: Dict[str, int]
    for c in trovate:
        tipi[c["tipo"]] = tipi.get(c["tipo"], 0) + 1
    print("(dato) chiamate al tool Agent: %d (%s)" % (len(trovate), ", ".join(
        "%s %d" % (t, n) for t, n in sorted(tipi.items()))))
    return revisore(ws, cartella, trovate, risultati)


def main(argv: List[str]) -> int:
    ws = os.path.realpath(argv[1]) if len(argv) > 1 and argv[1] else ""
    if not ws or not os.path.isdir(ws):
        raise Precondizione("spazio di lavoro assente: %s"
                            % (argv[1] if len(argv) > 1 else ""))
    base = punto_di_partenza(ws)
    if not os.path.isdir(os.path.join(ws, PROGETTO)):
        raise Precondizione("manca %s nello spazio di lavoro: preparalo con "
                            "tools/prepara_esercizio.sh M4-E02" % PROGETTO)
    elenco = cambiati(ws, base)
    manca = []  # type: List[str]
    print("Verifica di M4-E02 «Una funzione nuova, con i test»\n")
    test = [p for p, s in elenco if p.startswith(TESTS)
            and s != "cancellato" and os.path.isfile(os.path.join(ws, p))]
    print("test nuovi o cambiati sotto %s: %d" % (TESTS, len(test)))
    for percorso in test:
        print("  %s" % percorso[len(TESTS):])
    if eseguibili(test):
        lavoro(ws, base, test, manca)
    else:
        manca.append("nessun test nuovo o cambiato sotto %s" % TESTS)
    dati_lavoro(ws, base, elenco)
    segnalazione = sessioni(ws)
    if segnalazione:
        manca.append(segnalazione)
    if manca:
        print("\nNon ancora: %s." % "; ".join(manca))
        return 1
    print("\nFatto: la suite passa e i test nuovi falliscono sul codice di "
          "partenza.")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv))
    except Precondizione as exc:
        sys.stderr.write("verifica: %s\n" % exc)
        sys.exit(2)
    except Exception as exc:  # mai un «fatto» né un «non ancora»
        sys.stdout.flush()
        sys.stderr.write("verifica: errore inatteso, la verifica non può "
                         "decidere: %s: %s\n" % (type(exc).__name__, " ".join(
                             str(exc).split())))
        sys.exit(2)
