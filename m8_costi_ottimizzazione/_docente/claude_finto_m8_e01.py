#!/usr/bin/env python3
"""claude_finto_m8_e01.py -- un claude finto per le prove di M8-E01 «Quanto
costa una risposta» (test_m8_e01.sh).

La suite lo lancia con il nome «claude», davanti nel PATH, attraverso un
piccolo involucro che imposta FINTO_MODI e FINTO_LOG. Il JSON che scrive è
inventato e dichiarato finto: la risposta finisce con «(risposta del claude
finto)», e --version lo dice. Prova il controllo e gli script, non il modello.
Ha la forma del JSON di `claude -p --output-format json` (Claude Code 2.1.322).

Le opzioni: quelle del passo 2 del README e di handson::claude_p (OPZIONI), il
prompt come argomento oppure dopo «--». Rifiuta («error: …», uscita 1)
un'opzione che non conosce, un --output-format diverso da json, una chiamata
senza prompt o con più di un prompt.

I conteggi (CONTEGGI) sono fissi; il costo si calcola qui con i prezzi di
PREZZI, che non vengono da listino.json: così la suite confronta il ricalcolo
di verifica.py con un calcolo che non è il suo.

Le parole di FINTO_MODI cambiano ciò che succede:
  ko        esce 1 senza stampare nulla
  errore    un JSON con is_error, ed esce 1
  non-json  stampa una riga che non è JSON ed esce 0

FINTO_LOG=file: una riga JSON per invocazione: argv, cwd, prompt, chiave
(ANTHROPIC_API_KEY era nell'ambiente), effort (CLAUDE_CODE_EFFORT_LEVEL c'era),
stdin_nullo.

Uscita: 0 il JSON · 1 un argomento rifiutato, ko, errore
"""
import json
import os
import stat
import sys
import uuid
from typing import Any, Dict, List, Tuple

OPZIONI = {"-p": 0, "--model": 1, "--permission-mode": 1,
           "--permission-prompts": 1, "--output-format": 1,
           "--setting-sources": 1, "--tools": 1, "--effort": 1,
           "--strict-mcp-config": 0, "--no-session-persistence": 0}
NOTA = " (risposta del claude finto)"
CONTEGGI = {"input_tokens": 12, "ephemeral_5m_input_tokens": 400,
            "ephemeral_1h_input_tokens": 3000,
            "cache_read_input_tokens": 9000, "output_tokens": 250}
# I prezzi di Haiku, in dollari per milione di token, scritti qui e non letti
# da listino.json.
PREZZI = {"input_tokens": 0.10, "ephemeral_5m_input_tokens": 0.125,
          "ephemeral_1h_input_tokens": 0.20,
          "cache_read_input_tokens": 0.01, "output_tokens": 0.50}


class Rifiutato(Exception):
    """Argomenti che il finto non accetta: il messaggio d'errore."""


def modi() -> List[str]:
    """Le parole di FINTO_MODI."""
    return os.environ.get("FINTO_MODI", "").split()


def argomenti(argv: List[str]) -> Tuple[Dict[str, str], str]:
    """(le opzioni con i loro valori, il prompt)."""
    opzioni: Dict[str, str] = {}
    prompt: List[str] = []
    i = 0
    while i < len(argv):
        nome = argv[i]
        if nome == "--":
            prompt.extend(argv[i + 1:])
            break
        if nome not in OPZIONI:
            if nome.startswith("-"):
                raise Rifiutato("error: unknown option '%s'" % nome)
            prompt.append(nome)
            i += 1
            continue
        if OPZIONI[nome] and i + 1 >= len(argv):
            raise Rifiutato("error: option '%s' argument missing" % nome)
        opzioni[nome] = argv[i + 1] if OPZIONI[nome] else ""
        i += 1 + OPZIONI[nome]
    if len(prompt) != 1 or not prompt[0]:
        raise Rifiutato("error: serve un prompt, uno solo")
    if opzioni.get("--output-format") != "json":
        raise Rifiutato("error: il finto scrive soltanto json")
    return opzioni, prompt[0]


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
    dato: Dict[str, Any] = {
        "argv": argv, "cwd": os.getcwd(), "prompt": prompt,
        "chiave": "ANTHROPIC_API_KEY" in os.environ,
        "effort": "CLAUDE_CODE_EFFORT_LEVEL" in os.environ,
        "stdin_nullo": stdin_nullo()}
    with open(registro, "a", encoding="utf-8") as fh:
        fh.write(json.dumps(dato, ensure_ascii=False) + "\n")


def risposta(opzioni: Dict[str, str]) -> Dict[str, Any]:
    """Il JSON finto di una chiamata riuscita."""
    c = CONTEGGI
    costo = sum(c[k] * PREZZI[k] for k in c) / 1_000_000
    scrittura = c["ephemeral_5m_input_tokens"] + c["ephemeral_1h_input_tokens"]
    secchi = {"ephemeral_5m_input_tokens": c["ephemeral_5m_input_tokens"],
              "ephemeral_1h_input_tokens": c["ephemeral_1h_input_tokens"]}
    uso = {"input_tokens": c["input_tokens"],
           "cache_creation_input_tokens": scrittura,
           "cache_read_input_tokens": c["cache_read_input_tokens"],
           "output_tokens": c["output_tokens"],
           "output_tokens_details": {"thinking_tokens": 0},
           "server_tool_use": {"web_search_requests": 0,
                               "web_fetch_requests": 0},
           "service_tier": "standard", "cache_creation": dict(secchi),
           "iterations": [{
               "input_tokens": c["input_tokens"],
               "output_tokens": c["output_tokens"],
               "cache_read_input_tokens": c["cache_read_input_tokens"],
               "cache_creation_input_tokens": scrittura,
               "cache_creation": dict(secchi), "type": "message"}]}
    voce = {"inputTokens": c["input_tokens"],
            "outputTokens": c["output_tokens"],
            "cacheReadInputTokens": c["cache_read_input_tokens"],
            "cacheCreationInputTokens": scrittura,
            "cacheCreationEphemeral5mInputTokens":
                c["ephemeral_5m_input_tokens"],
            "cacheCreationEphemeral1hInputTokens":
                c["ephemeral_1h_input_tokens"],
            "costUSD": round(costo, 7), "canonicalModel": "claude-finto",
            "costBasis": "list"}
    errore = "errore" in modi()
    return {"type": "result",
            "subtype": "error_during_execution" if errore else "success",
            "is_error": errore, "duration_ms": 1200, "duration_api_ms": 1000,
            "num_turns": 1, "stop_reason": "end_turn",
            "session_id": str(uuid.uuid4()),
            "total_cost_usd": round(costo, 7), "usage": uso,
            "modelUsage": {"claude-%s-5-5" % opzioni.get("--model", "haiku"):
                           voce},
            "permission_denials": [], "terminal_reason": "completed",
            "result": "Buongiorno, ecco che cosa provare." + NOTA}


def main(argv: List[str]) -> int:
    if argv == ["--version"]:
        print("9.9.9 (Claude Code finto)")
        return 0
    try:
        opzioni, prompt = argomenti(argv)
        scrivi_log(argv, prompt)
    except Rifiutato as exc:
        print(str(exc), file=sys.stderr)
        return 1
    if "ko" in modi():
        return 1
    if "non-json" in modi():
        print("Questa riga non è JSON")
        return 0
    print(json.dumps(risposta(opzioni), ensure_ascii=False))
    return 1 if "errore" in modi() else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
