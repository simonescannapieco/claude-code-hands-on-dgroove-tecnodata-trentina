#!/usr/bin/env python3
"""claude_finto_m8_d03.py -- un claude finto per le prove di M8-D03
(test_m8_d03.sh).

La suite lo lancia con il nome «claude», davanti nel PATH, attraverso un
piccolo involucro che imposta FINTO_MODI, FINTO_LOG e FINTO_CACHE. I JSON che
scrive sono inventati e dichiarati finti: ogni risposta finisce con «(risposta
del claude finto)». Provano il controllo e gli script, non il modello. Hanno la
forma di quelli di `claude -p --output-format json`.

Le opzioni: quelle di handson::claude_p e dell'elemento (OPZIONI), poi il prompt
dopo «--». Rifiuta («error: …», uscita 1) un'opzione che non conosce, un
--output-format diverso da json, un --system-prompt-file che non si legge.
--version stampa una versione finta.

La cache: FINTO_CACHE è un file JSON «modello|impronta del prefisso → quante
volte». La prima volta che un modello vede un prefisso scrive tutto il
prefisso (scritti) e non legge; le volte dopo legge quasi tutto il prefisso e
scrive il resto, come una prima parte comune a più chiamate; con
DISABLE_PROMPT_CACHING=1 tutto in input_tokens e la cache non si tocca.

Le parole di FINTO_MODI cambiano ciò che succede:
  usage=I,C,R,O   forza input, scritti, letti, output di questa chiamata
  senza-dettaglio usage senza il dettaglio cache_creation
  errore          il JSON con is_error e subtype error_during_execution
  riga-rotta      una riga che non è JSON
  senza-usage     il JSON senza usage
  usage-testo     un conteggio di usage che non è un numero
  ko              esce 1 senza stampare nulla
  ko-modello=M    esce 1 se il modello è M

FINTO_LOG=file: una riga JSON per invocazione: argv, cwd, prompt, chiave
(ANTHROPIC_API_KEY era nell'ambiente), effort (CLAUDE_CODE_EFFORT_LEVEL c'era),
spenta (il valore di DISABLE_PROMPT_CACHING, o null), stdin_nullo, sistema (il
testo del file di --system-prompt-file).

Uscita: 0 il JSON · 1 un argomento rifiutato, ko
"""
import hashlib
import json
import os
import stat
import sys
import uuid
from typing import Any, Dict, List, Tuple

OPZIONI = {"-p": 0, "--model": 1, "--permission-mode": 1,
           "--permission-prompts": 1, "--output-format": 1,
           "--setting-sources": 1, "--tools": 1, "--system-prompt-file": 1,
           "--effort": 1, "--strict-mcp-config": 0,
           "--no-session-persistence": 0}
NOTA = " (risposta del claude finto)"
MODELLI = {"haiku": "claude-haiku-5-5", "sonnet": "claude-sonnet-5-5"}
PREZZI = {"haiku": (0.10, 0.50, 0.20, 0.01), "sonnet": (2.0, 10.0, 4.0, 0.10)}
BASE = 90
PARTE_NUOVA = 300
USCITA = 40


class Rifiutato(Exception):
    """Argomenti che il finto non accetta: il messaggio d'errore."""


def modi() -> List[str]:
    """Le parole di FINTO_MODI."""
    return os.environ.get("FINTO_MODI", "").split()


def valore_modo(nome: str) -> str:
    """Il valore di una parola nome=valore di FINTO_MODI, o «»."""
    for parola in modi():
        if parola.startswith(nome + "="):
            return parola.split("=", 1)[1]
    return ""


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
    if opzioni.get("--output-format") != "json":
        raise Rifiutato("error: il finto scrive soltanto json")
    return opzioni, argv[i + 1]


def stdin_nullo() -> bool:
    """Vero se lo STDIN è /dev/null."""
    try:
        dati = os.fstat(0)
        nullo = os.stat(os.devnull)
    except OSError:
        return False
    return stat.S_ISCHR(dati.st_mode) and dati.st_rdev == nullo.st_rdev


def leggi_prefisso(opzioni: Dict[str, str]) -> str:
    """Il testo del file di --system-prompt-file."""
    percorso = opzioni.get("--system-prompt-file")
    if not percorso:
        raise Rifiutato("error: serve --system-prompt-file")
    try:
        with open(percorso, encoding="utf-8") as fh:
            return fh.read()
    except OSError as exc:
        raise Rifiutato("error: %s" % exc) from exc


def scrivi_log(argv: List[str], prompt: str, prefisso: str) -> None:
    """Una riga in FINTO_LOG, se c'è."""
    registro = os.environ.get("FINTO_LOG")
    if not registro:
        return
    dato = {"argv": argv, "cwd": os.getcwd(), "prompt": prompt,
            "chiave": "ANTHROPIC_API_KEY" in os.environ,
            "effort": "CLAUDE_CODE_EFFORT_LEVEL" in os.environ,
            "spenta": os.environ.get("DISABLE_PROMPT_CACHING"),
            "stdin_nullo": stdin_nullo(), "sistema": prefisso}
    with open(registro, "a", encoding="utf-8") as fh:
        fh.write(json.dumps(dato, ensure_ascii=False) + "\n")


def conteggi_cache(modello: str, prefisso: str) -> Tuple[int, int, int]:
    """(input, scritti, letti) per un modello e un prefisso, secondo la cache
    finta, che viene aggiornata."""
    token = BASE + len(prefisso) // 2
    if os.environ.get("DISABLE_PROMPT_CACHING") == "1":
        return token, 0, 0
    percorso = os.environ.get("FINTO_CACHE", "")
    stato: Dict[str, int] = {}
    if percorso and os.path.isfile(percorso):
        with open(percorso, encoding="utf-8") as fh:
            stato = json.load(fh)
    chiave = "%s|%s" % (modello, hashlib.sha1(prefisso.encode()).hexdigest())
    volte = stato.get(chiave, 0)
    stato[chiave] = volte + 1
    if percorso:
        with open(percorso, "w", encoding="utf-8") as fh:
            json.dump(stato, fh)
    if volte == 0:
        return 2, token, 0
    nuova = min(PARTE_NUOVA, token // 3)
    return 2, nuova, token - nuova


def scrivi_risultato(modello: str, ingresso: int, scritti: int, letti: int,
                     uscita: int) -> Dict[str, Any]:
    """Il JSON finto di una chiamata."""
    prezzi = PREZZI[modello]
    costo = (ingresso * prezzi[0] + uscita * prezzi[1] + scritti * prezzi[2]
             + letti * prezzi[3]) / 1e6
    errore = "errore" in modi()
    uso: Dict[str, Any] = {
        "input_tokens": ingresso, "cache_creation_input_tokens": scritti,
        "cache_read_input_tokens": letti, "output_tokens": uscita,
        "cache_creation": {"ephemeral_1h_input_tokens": scritti,
                           "ephemeral_5m_input_tokens": 0}}
    if "senza-dettaglio" in modi():
        del uso["cache_creation"]
    if "usage-testo" in modi():
        uso["cache_read_input_tokens"] = "molti"
    dato: Dict[str, Any] = {
        "type": "result",
        "subtype": "error_during_execution" if errore else "success",
        "is_error": errore, "num_turns": 1, "duration_ms": 1200,
        "duration_api_ms": 1100, "result": "Controlli il cavo." + NOTA,
        "session_id": str(uuid.uuid4()), "total_cost_usd": costo,
        "usage": uso,
        "modelUsage": {MODELLI["haiku" if "altro-modello" in modi()
                               else modello]: {
            "inputTokens": ingresso, "outputTokens": uscita,
            "cacheReadInputTokens": letti,
            "cacheCreationInputTokens": scritti}}}
    if "senza-usage" in modi():
        del dato["usage"]
    return dato


def main(argv: List[str]) -> int:
    if argv == ["--version"]:
        print("9.9.9 (Claude Code finto)")
        return 0
    try:
        opzioni, prompt = argomenti(argv)
        prefisso = leggi_prefisso(opzioni)
        scrivi_log(argv, prompt, prefisso)
        modello = opzioni.get("--model", "")
        if "ko" in modi() or valore_modo("ko-modello") == modello:
            return 1
        if modello not in MODELLI:
            raise Rifiutato("error: modello «%s» sconosciuto" % modello)
        if "riga-rotta" in modi():
            print("{questa riga non è JSON")
            return 0
        forza = valore_modo("usage")
        if forza:
            ingresso, scritti, letti, uscita = (
                int(x) for x in forza.split(","))
        else:
            ingresso, scritti, letti = conteggi_cache(modello, prefisso)
            uscita = USCITA
        print(json.dumps(scrivi_risultato(modello, ingresso, scritti, letti,
                                          uscita), ensure_ascii=False))
    except Rifiutato as exc:
        print(str(exc), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
