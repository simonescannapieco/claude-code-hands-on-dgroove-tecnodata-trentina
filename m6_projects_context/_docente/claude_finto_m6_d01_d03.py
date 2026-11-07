#!/usr/bin/env python3
"""claude_finto_m6_d01_d03.py -- un claude finto per le prove di M6-D01 e
M6-D03 (test_m6_d01.sh, test_m6_d03.sh).

Le suite lo copiano, con il nome «claude», davanti nel PATH: così
demo/in_classe.sh e _docente/live.sh girano per intero senza chiamare il
modello e senza consumare il piano. Gli stream che scrive sono inventati e
dichiarati finti: nessuno è una risposta di Claude, e ogni risposta finisce con
«(risposta del claude finto)». Provano i controlli e gli script, non il
modello. Hanno la forma di quelli di `claude -p --output-format stream-json
--verbose`: system/init, assistant, user con i tool_result, result.

Gli argomenti: le opzioni che usano i due elementi (OPZIONI, con quanti valori
prendono), poi il prompt dopo «--». Rifiuta («error: …», uscita 1) un'opzione
che non conosce, un --output-format diverso da stream-json e lo stream-json
senza --verbose. --version stampa una versione finta. Non esegue mai i
comandi che finge: i risultati di Bash sono testi scritti qui.

Le scene, dal prompt e dalla cartella da cui parte:
  la domanda di M6-D01 («Entro quanti giorni …»)
      con un CLAUDE.md che importa @docs/carta-servizi.md, e il file c'è:
      nessuno strumento, la risposta con i giorni lavorativi dell'Art. 4 letti
      dal file e la citazione «Art. 4»;
      altrimenti: Grep e Glob nella cartella, senza la carta, e una risposta
      senza cifre;
  la richiesta di M6-D03 («Esegui la suite di test …»)
      con un CLAUDE.md che nomina tools/php.sh: composer install e phpunit
      con tools/php.sh, il riepilogo «OK (44 tests, 107 assertions)», a
      colori, e la risposta con i numeri;
      altrimenti: ls e which, nessun PHP, e una risposta senza numeri;
  un altro prompt: una risposta qualunque.
I token della prima richiesta: BASE, più i caratteri del CLAUDE.md della
cartella e dei file che importa, per RAPPORTO.

L'ambiente cambia ciò che succede:
  FINTO_CIFRE_SENZA=1   M6-D01 senza la carta: la risposta ha 5 e 9 giorni
  FINTO_SENZA_CIFRE=1   M6-D01 con la carta: la risposta senza cifre
  FINTO_PERDITA=file    M6-D01 senza la carta: Read di quel file, con il suo
                        testo nel tool_result
  FINTO_ARTICOLO=n      M6-D01 con la carta: cita l'Art. n invece del 4
  FINTO_DATA=1          M6-D01 con la carta: la risposta aggiunge una data
  FINTO_SUITE_SEMPRE=1  M6-D03 senza CLAUDE.md: legge il README e fa girare
                        la suite lo stesso
  FINTO_SUITE_MAI=1     M6-D03 con CLAUDE.md: tools/php.sh fallisce, nessun
                        riepilogo
  FINTO_FALLITI=n       M6-D03: il riepilogo con n test falliti
  FINTO_CASA=1          M6-D03: un comando con la home dentro
  FINTO_TRONCO=1        lo stream senza il risultato
  FINTO_ERRORE=1        il risultato con is_error
  FINTO_RIGA_ROTTA=1    una riga che non è JSON
  FINTO_KO_SE=testo     esce 1 senza stampare nulla se testo è nel prompt o
                        nella cartella
  FINTO_LOG=file        una riga JSON per invocazione: argv, cwd, prompt,
                        chiave (ANTHROPIC_API_KEY era nell'ambiente), effort
                        (CLAUDE_CODE_EFFORT_LEVEL c'era), memoria (il valore di
                        CLAUDE_CODE_DISABLE_AUTO_MEMORY), stdin_nullo (lo STDIN
                        è /dev/null), radice (la radice git della cartella),
                        file (i file della radice git, senza .git, ciascuno
                        con il suo sha256), commit (i commit della radice),
                        pulito (git status vuoto)

Uscita: 0 lo stream · 1 un argomento rifiutato, FINTO_KO_SE
"""
import hashlib
import json
import os
import re
import stat
import subprocess
import sys
import uuid
from typing import Dict, List, Optional, Tuple

OPZIONI = {"-p": 0, "--allowedTools": 1, "--model": 1, "--permission-mode": 1,
           "--permission-prompts": 1, "--output-format": 1, "--verbose": 0,
           "--setting-sources": 1, "--tools": 1, "--disallowedTools": 1,
           "--effort": 1, "--strict-mcp-config": 0,
           "--no-session-persistence": 0}
BASE = 5000
RAPPORTO = 0.3
NOTA = " (risposta del claude finto)"
DOMANDA_D01 = "Entro quanti giorni lavorativi"
RICHIESTA_D03 = "Esegui la suite di test"
GIORNI = re.compile(r"(\d+) giorni lavorativi")
SEZIONE = re.compile(r"^## Art\. ([0-9]+) ")
IMPORT = re.compile(r"(?<![`\w])@([\w./-]+)")
COLORE = "\x1b[30;42m"
FINE_COLORE = "\x1b[0m"


class Rifiutato(Exception):
    """Argomenti che il finto non accetta: il messaggio d'errore."""


Blocco = Dict[str, object]
Passo = Tuple[str, Dict[str, object], str, bool]


def acceso(nome: str) -> bool:
    """Vero se la variabile d'ambiente vale 1."""
    return os.environ.get(nome) == "1"


def argomenti(argv: List[str]) -> Tuple[Dict[str, str], str]:
    """(le opzioni con i loro valori, il prompt)."""
    opzioni: Dict[str, str] = {}
    i = 0
    while i < len(argv) and argv[i] != "--":
        nome = argv[i]
        if nome not in OPZIONI:
            raise Rifiutato("error: unknown option '%s'" % nome)
        if OPZIONI[nome] and i + 1 >= len(argv):
            raise Rifiutato("error: option '%s' argument missing" % nome)
        opzioni[nome] = argv[i + 1] if OPZIONI[nome] else ""
        i += 1 + OPZIONI[nome]
    if i >= len(argv) or len(argv) != i + 2:
        raise Rifiutato("error: il prompt va dopo «--»")
    if opzioni.get("--output-format") != "stream-json":
        raise Rifiutato("error: il finto scrive soltanto stream-json")
    if "--verbose" not in opzioni:
        raise Rifiutato("error: stream-json requires --verbose")
    return opzioni, argv[i + 1]


def testo_di(percorso: str) -> str:
    """Il testo di un file, vuoto se non c'è."""
    try:
        with open(percorso, encoding="utf-8") as fh:
            return fh.read()
    except OSError:
        return ""


def importati(claude_md: str) -> List[str]:
    """I file che il CLAUDE.md della cartella importa e che esistono."""
    return [p for p in IMPORT.findall(claude_md) if os.path.isfile(p)]


def prima_richiesta() -> int:
    """I token finti della prima richiesta, dal contesto della cartella."""
    claude_md = testo_di("CLAUDE.md")
    totale = len(claude_md) + sum(len(testo_di(p))
                                  for p in importati(claude_md))
    return BASE + int(totale * RAPPORTO)


def giorni_art4(percorso: str) -> List[str]:
    """I «N giorni lavorativi» dell'Art. 4 del file."""
    dentro, righe = False, []
    for riga in testo_di(percorso).splitlines():
        sezione = SEZIONE.match(riga)
        if riga.startswith("## "):
            dentro = bool(sezione) and sezione.group(1) == "4"
        elif dentro:
            righe.append(riga)
    return GIORNI.findall(" ".join(righe))


def scena_d01(cwd: str) -> Tuple[List[Passo], str]:
    """I passi e la risposta della domanda di M6-D01."""
    claude_md = testo_di("CLAUDE.md")
    carta = [p for p in importati(claude_md) if p.endswith("carta-servizi.md")]
    if carta:
        giorni = giorni_art4(carta[0])
        articolo = os.environ.get("FINTO_ARTICOLO", "4")
        if acceso("FINTO_SENZA_CIFRE"):
            return [], "La carta dei servizi non dà un termine per questo " \
                "intervento." + NOTA
        data = " Siamo al 7 novembre 2026." if acceso("FINTO_DATA") else ""
        return [], ("Secondo l'Art. %s della carta dei servizi, entro %s "
                    "giorni lavorativi da maggio a ottobre ed entro %s giorni "
                    "lavorativi da novembre ad aprile.%s" % (
                        articolo, giorni[0], giorni[-1], data)) + NOTA
    passi: List[Passo] = [
        ("Grep", {"pattern": "ponte radio|in quota", "path": cwd},
         "No matches found", False),
        ("Glob", {"pattern": "**/*", "path": cwd},
         "\n".join(file_di(cwd)) or "No files found", False)]
    perdita = os.environ.get("FINTO_PERDITA")
    if perdita:
        passi.append(("Read", {"file_path": perdita}, testo_di(perdita),
                      False))
    if acceso("FINTO_CIFRE_SENZA"):
        return passi, "Di solito 5 giorni lavorativi d'estate e 9 giorni " \
            "lavorativi d'inverno." + NOTA
    return passi, "Non trovo la carta dei servizi in questa cartella: non " \
        "posso dire il termine." + NOTA


def riepilogo(falliti: int) -> str:
    """L'uscita finta di phpunit, con il riepilogo a colori."""
    testa = "PHPUnit 12.5.38 by Sebastian Bergmann and contributors.\n\n" \
        "Runtime:       PHP 8.3.35\n\n" + "." * 44 + "  44 / 44 (100%)\n\n"
    if falliti:
        return testa + "FAILURES!\nTests: 44, Assertions: 107, Failures: " \
            "%d.\n" % falliti
    return testa + COLORE + "OK (44 tests, 107 assertions)" + FINE_COLORE \
        + "\n"


def scena_d03() -> Tuple[List[Passo], str]:
    """I passi e la risposta della richiesta di M6-D03."""
    falliti = int(os.environ.get("FINTO_FALLITI", "0"))
    con_riga = "tools/php.sh" in testo_di("CLAUDE.md")
    suite = (con_riga and not acceso("FINTO_SUITE_MAI")) \
        or (not con_riga and acceso("FINTO_SUITE_SEMPRE"))
    passi: List[Passo] = []
    if not con_riga:
        comando = "ls; cat composer.json | head -40"
        if acceso("FINTO_CASA"):
            comando += "; ls %s/bin" % os.path.expanduser("~")
        passi.append(("Bash", {"command": comando},
                      "composer.json\nREADME.md\nsrc\ntests", False))
        if not suite:
            passi.append(("Bash", {"command": "which php phpunit composer"},
                          "Exit code 1", True))
            return passi, "Non riesco a eseguire i test: PHP non è " \
                "installato." + NOTA
        passi.append(("Read", {"file_path": os.path.join(os.getcwd(),
                                                         "README.md")},
                      testo_di("README.md")[:400], False))
    if not suite:
        passi.append(("Bash", {"command": "../../tools/php.sh phpunit"},
                      "Exit code 2\nphp.sh: servono PHP >= 8.3 o Docker",
                      True))
        return passi, "I test non sono partiti: tools/php.sh non trova né " \
            "PHP né Docker." + NOTA
    passi.append(("Bash", {"command": "../../tools/php.sh composer install"},
                  "Installing dependencies from lock file\nGenerating "
                  "autoload files", False))
    passi.append(("Bash", {"command": "../../tools/php.sh phpunit"},
                  riepilogo(falliti), falliti > 0))
    return passi, "Ho eseguito la suite: %d passano, %d falliscono." % (
        44 - falliti, falliti) + NOTA


def file_di(radice: str) -> List[str]:
    """I file sotto la cartella, relativi, senza .git."""
    visti = []
    for cartella, sottocartelle, nomi in os.walk(radice):
        sottocartelle[:] = sorted(c for c in sottocartelle if c != ".git")
        for nome in nomi:
            visti.append(os.path.relpath(os.path.join(cartella, nome),
                                         radice))
    return sorted(visti)


def impronte(radice: str) -> Dict[str, str]:
    """Lo sha256 di ogni file sotto la cartella, senza .git."""
    visti = {}
    for relativo in file_di(radice):
        with open(os.path.join(radice, relativo), "rb") as fh:
            visti[relativo] = hashlib.sha256(fh.read()).hexdigest()
    return visti


def git(*argomenti_git: str) -> Optional[str]:
    """L'uscita di un comando git nella cartella corrente, o None."""
    try:
        fatto = subprocess.run(("git",) + argomenti_git, capture_output=True,
                               text=True, check=False)
    except OSError:
        return None
    return fatto.stdout.strip() if fatto.returncode == 0 else None


def stdin_nullo() -> bool:
    """Vero se lo STDIN è /dev/null."""
    try:
        dati = os.fstat(0)
        nullo = os.stat(os.devnull)
    except OSError:
        return False
    return stat.S_ISCHR(dati.st_mode) and dati.st_rdev == nullo.st_rdev


def scrivi_log(argv: List[str], prompt: str) -> None:
    """Una riga in FINTO_LOG, se c'è."""
    registro = os.environ.get("FINTO_LOG")
    if not registro:
        return
    radice = git("rev-parse", "--show-toplevel")
    dato = {"argv": argv, "cwd": os.getcwd(), "prompt": prompt,
            "chiave": "ANTHROPIC_API_KEY" in os.environ,
            "effort": "CLAUDE_CODE_EFFORT_LEVEL" in os.environ,
            "memoria": os.environ.get("CLAUDE_CODE_DISABLE_AUTO_MEMORY"),
            "stdin_nullo": stdin_nullo(), "radice": radice,
            "file": impronte(radice) if radice else {},
            "commit": git("rev-list", "--count", "HEAD"),
            "pulito": git("status", "--porcelain") == ""}
    with open(registro, "a", encoding="utf-8") as fh:
        fh.write(json.dumps(dato, ensure_ascii=False) + "\n")


def uso(token: int) -> Dict[str, int]:
    """Un usage finto, con la prima richiesta nella cache."""
    return {"input_tokens": 3, "cache_creation_input_tokens": token,
            "cache_read_input_tokens": 0, "output_tokens": 20}


def stream(cwd: str, passi: List[Passo], risposta: str, prima: int) -> None:
    """Lo stream finto, una riga per evento."""
    sessione = str(uuid.uuid4())
    righe: List[Blocco] = [{
        "type": "system", "subtype": "init", "cwd": cwd,
        "session_id": sessione, "model": "claude-finto",
        "claude_code_version": "9.9.9 (finto)", "permissionMode": "dontAsk"}]
    for numero, (nome, ingresso, risultato, errore) in enumerate(passi, 1):
        ident = "toolu_finto_%d" % numero
        righe.append({"type": "assistant", "parent_tool_use_id": None,
                      "message": {"id": "msg_%d" % numero, "content": [{
                          "type": "tool_use", "id": ident, "name": nome,
                          "input": ingresso}],
                          "usage": uso(prima + 100 * (numero - 1))}})
        righe.append({"type": "user", "message": {"role": "user", "content": [
            {"type": "tool_result", "tool_use_id": ident,
             "content": risultato, "is_error": errore}]}})
    righe.append({"type": "assistant", "parent_tool_use_id": None,
                  "message": {"id": "msg_fine", "content": [
                      {"type": "text", "text": risposta}],
                      "usage": uso(prima + 100 * len(passi))}})
    errore_finale = acceso("FINTO_ERRORE")
    totale = sum(prima + 100 * i + 23 for i in range(len(passi) + 1))
    risultato_finale = {
        "type": "result", "subtype": "error_during_execution"
        if errore_finale else "success", "is_error": errore_finale,
        "num_turns": len(passi) + 1, "duration_ms": 1200 + 700 * len(passi),
        "result": risposta, "session_id": sessione,
        "usage": {"input_tokens": 3 * (len(passi) + 1),
                  "cache_creation_input_tokens": totale - 23 * (
                      len(passi) + 1),
                  "cache_read_input_tokens": 0,
                  "output_tokens": 20 * (len(passi) + 1)},
        "modelUsage": {"claude-finto": {
            "inputTokens": 3 * (len(passi) + 1), "outputTokens": 20 * (
                len(passi) + 1), "cacheReadInputTokens": 0,
            "cacheCreationInputTokens": totale - 23 * (len(passi) + 1)}},
        "permission_denials": []}
    if not acceso("FINTO_TRONCO"):
        righe.append(risultato_finale)
    for numero, riga in enumerate(righe):
        print(json.dumps(riga, ensure_ascii=False))
        if numero == 1 and acceso("FINTO_RIGA_ROTTA"):
            print("{questa riga non è JSON")


def main(argv: List[str]) -> int:
    if argv == ["--version"]:
        print("9.9.9 (Claude Code finto)")
        return 0
    try:
        _, prompt = argomenti(argv)
    except Rifiutato as exc:
        print(str(exc), file=sys.stderr)
        return 1
    scrivi_log(argv, prompt)
    cwd = os.getcwd()
    ko = os.environ.get("FINTO_KO_SE")
    if ko and (ko in prompt or ko in cwd):
        return 1
    prima = prima_richiesta()
    if prompt.startswith(DOMANDA_D01):
        passi, risposta = scena_d01(cwd)
    elif prompt.startswith(RICHIESTA_D03):
        passi, risposta = scena_d03()
    else:
        passi, risposta = [], "Una risposta qualunque." + NOTA
    stream(cwd, passi, risposta, prima)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
