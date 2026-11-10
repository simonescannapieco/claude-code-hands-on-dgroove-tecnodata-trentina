#!/usr/bin/env python3
"""claude_finto_m8_d04.py -- un claude finto per le prove di M8-D04
(test_m8_d04.sh).

La suite lo lancia con il nome «claude», davanti nel PATH, attraverso un
piccolo involucro che imposta FINTO_MODI, FINTO_LOG e FINTO_TICKET (il
ticket.jsonl dell'elemento, da cui prende le etichette giuste). I JSON che
scrive sono inventati e dichiarati finti («(risposta del claude finto)» nel
campo result). Provano il controllo e gli script, non il modello. Hanno la
forma di quelli di `claude -p --output-format json --json-schema`, con
structured_output.

Le opzioni: quelle di handson::claude_p e dell'elemento (OPZIONI), poi il prompt
dopo «--». Rifiuta («error: …», uscita 1) un'opzione che non conosce, un
--output-format diverso da json, un --json-schema assente o che non è JSON.
--version stampa una versione finta.

Le parole di FINTO_MODI cambiano ciò che succede:
  sbaglia=N             le prime N etichette di questa chiamata sono sbagliate
  sbaglia-modello=M:N   lo stesso, ma solo sul modello M
  senza-strutturato     il JSON senza structured_output
  poche-etichette       structured_output con una etichetta in meno
  errore                il JSON con is_error e subtype error_during_execution
  riga-rotta            una riga che non è JSON
  senza-usage           il JSON senza usage
  usage-testo           un conteggio di usage che non è un numero
  senza-dettaglio       usage senza il dettaglio cache_creation
  costo-diverso         total_cost_usd diverso dal costo dei conteggi
  haiku-caro            Haiku con un output enorme: costa più degli altri
  ko                    esce 1 senza stampare nulla
  ko-modello=M          esce 1 se il modello è M

FINTO_LOG=file: una riga JSON per invocazione: argv, cwd, prompt, chiave
(ANTHROPIC_API_KEY era nell'ambiente), effort (CLAUDE_CODE_EFFORT_LEVEL c'era),
stdin_nullo, sistema (il testo di --system-prompt), schema (il JSON di
--json-schema, dentro una stringa).

Uscita: 0 il JSON · 1 un argomento rifiutato, ko
"""
import json
import os
import stat
import sys
import uuid
from typing import Any, Dict, List, Tuple

OPZIONI = {"-p": 0, "--model": 1, "--permission-mode": 1,
           "--permission-prompts": 1, "--output-format": 1,
           "--setting-sources": 1, "--tools": 1, "--system-prompt": 1,
           "--json-schema": 1, "--effort": 1, "--strict-mcp-config": 0,
           "--no-session-persistence": 0}
NOTA = " (risposta del claude finto)"
NOMI = {"haiku": "claude-haiku-5-5", "sonnet": "claude-sonnet-5-5",
        "opus": "claude-opus-5-5"}
PREZZI = {"haiku": (0.10, 0.50, 0.20, 0.01), "sonnet": (2.0, 10.0, 4.0, 0.10),
          "opus": (4.0, 20.0, 8.0, 0.20)}
MS_API = {"haiku": 800, "sonnet": 1400, "opus": 2100}


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


def scrivi_log(argv: List[str], opzioni: Dict[str, str], prompt: str) -> None:
    """Una riga in FINTO_LOG, se c'è."""
    registro = os.environ.get("FINTO_LOG")
    if not registro:
        return
    dato = {"argv": argv, "cwd": os.getcwd(), "prompt": prompt,
            "chiave": "ANTHROPIC_API_KEY" in os.environ,
            "effort": "CLAUDE_CODE_EFFORT_LEVEL" in os.environ,
            "stdin_nullo": stdin_nullo(),
            "sistema": opzioni.get("--system-prompt"),
            "schema": opzioni.get("--json-schema")}
    with open(registro, "a", encoding="utf-8") as fh:
        fh.write(json.dumps(dato, ensure_ascii=False) + "\n")


def etichette_giuste() -> List[str]:
    """Le etichette giuste, da FINTO_TICKET, nell'ordine dei ticket."""
    with open(os.environ["FINTO_TICKET"], encoding="utf-8") as fh:
        return [json.loads(r)["etichetta"] for r in fh if r.strip()]


def etichette(modello: str) -> List[str]:
    """Le etichette di questa chiamata, con gli errori chiesti dai modi."""
    giuste = etichette_giuste()
    sbagliate = int(valore_modo("sbaglia") or 0)
    bersaglio = valore_modo("sbaglia-modello")
    if bersaglio:
        quale, numero = bersaglio.split(":")
        if quale == modello:
            sbagliate = int(numero)
    giro = {"guasto": "lentezza", "lentezza": "fattura",
            "fattura": "attivazione", "attivazione": "guasto"}
    uscita = [giro[e] if i < sbagliate else e for i, e in enumerate(giuste)]
    return uscita[:-1] if "poche-etichette" in modi() else uscita


def risultato(modello: str) -> Dict[str, Any]:
    """Il JSON finto di una chiamata."""
    prezzi = PREZZI[modello]
    ingresso, scritti, letti = 3, 1800, 0
    uscita = 150 if not ("haiku-caro" in modi() and modello == "haiku") \
        else 400000
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
        uso["output_tokens"] = "molti"
    dato: Dict[str, Any] = {
        "type": "result",
        "subtype": "error_during_execution" if errore else "success",
        "is_error": errore, "num_turns": 2,
        "duration_ms": MS_API[modello] + 100,
        "duration_api_ms": MS_API[modello],
        "result": "Etichette assegnate." + NOTA,
        "session_id": str(uuid.uuid4()),
        "total_cost_usd": costo + 0.5 if "costo-diverso" in modi() else costo,
        "usage": uso,
        "modelUsage": {NOMI["opus" if "altro-modello" in modi()
                            and modello != "opus" else modello]: {
                                       "inputTokens": ingresso,
                                       "outputTokens": uscita,
                                       "cacheReadInputTokens": letti,
                                       "cacheCreationInputTokens": scritti}}}
    if "senza-strutturato" not in modi():
        dato["structured_output"] = {"etichette": etichette(modello)}
    if "senza-usage" in modi():
        del dato["usage"]
    return dato


def main(argv: List[str]) -> int:
    if argv == ["--version"]:
        print("9.9.9 (Claude Code finto)")
        return 0
    try:
        opzioni, prompt = argomenti(argv)
        scrivi_log(argv, opzioni, prompt)
        modello = opzioni.get("--model", "")
        if "ko" in modi() or valore_modo("ko-modello") == modello:
            return 1
        if modello not in NOMI:
            raise Rifiutato("error: modello «%s» sconosciuto" % modello)
        schema = opzioni.get("--json-schema")
        if schema is None:
            raise Rifiutato("error: il finto si aspetta --json-schema")
        json.loads(schema)
        if "riga-rotta" in modi():
            print("{questa riga non è JSON")
            return 0
        print(json.dumps(risultato(modello), ensure_ascii=False))
    except (Rifiutato, ValueError) as exc:
        print(str(exc), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
