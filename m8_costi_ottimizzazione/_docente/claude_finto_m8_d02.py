#!/usr/bin/env python3
"""claude_finto_m8_d02.py -- un claude finto per le prove di M8-D02
(test_m8_d02.sh).

La suite lo lancia con il nome «claude», davanti nel PATH, attraverso un piccolo
involucro che imposta FINTO_MODI e FINTO_LOG. Scrive su STDOUT il JSON di
`claude -p --output-format json`: i conteggi sono inventati e la risposta
finisce con «(risposta del claude finto)». Provano il controllo e gli script,
non il modello. --version stampa una versione finta.

Le opzioni: quelle di handson::claude_p e di in_classe.sh (OPZIONI), poi il
prompt dopo «--». Rifiuta («error: …», uscita 1) un'opzione che non conosce e
un --output-format diverso da json.

Le scene, dal prompt: «/context» è la risposta locale, senza modello (zero
turni, zero token, modelUsage vuoto); un prompt che contiene «sei sezioni» è il
braccio lungo (640 token in uscita); gli altri il braccio breve (40). I token in
entrata dipendono dalla lunghezza del prompt e del system prompt; la prima
richiesta scrive in cache a un'ora.

Le parole di FINTO_MODI (uno spazio fra l'una e l'altra) cambiano ciò che
succede:
  pari             il braccio lungo risponde come il breve: uscita e costo uguali
  inversa          il braccio lungo risponde più corto del breve
  costo-diverso    total_cost_usd più alto di 0,000123 del conto giusto
  lettura          la cache si legge invece di scriversi
  cinque-minuti    la scrittura in cache è a cinque minuti
  errore           il risultato ha is_error
  altro-modello    in modelUsage c'è claude-sonnet-5-5
  due-modelli      in modelUsage ci sono due modelli
  modello-vuoto    modelUsage è vuoto
  senza-usage      niente usage
  senza-costo      niente total_cost_usd
  usage-rotto      input_tokens non è un numero
  senza-split      niente usage.cache_creation
  json-rotto       scrive una riga che non è JSON
  contesto-errore  /context con is_error
  contesto-costa   /context con turni e token che non sono zero
  ko               esce 1 senza stampare nulla
  ko-se=testo      esce 1 se il testo è nel prompt

FINTO_LOG=file: una riga JSON per invocazione: argv, cwd, prompt, chiave
(ANTHROPIC_API_KEY era nell'ambiente), effort (CLAUDE_CODE_EFFORT_LEVEL c'era),
stdin_nullo, sistema (il valore di --system-prompt).

Uscita: 0 il JSON · 1 un argomento rifiutato, ko
"""
import json
import os
import stat
import sys
import uuid
from typing import Any, Dict, List, Optional, Tuple

OPZIONI = {"-p": 0, "--model": 1, "--permission-mode": 1,
           "--permission-prompts": 1, "--output-format": 1,
           "--setting-sources": 1, "--tools": 1, "--system-prompt": 1,
           "--effort": 1, "--strict-mcp-config": 0,
           "--no-session-persistence": 0}
NOTA = " (risposta del claude finto)"
# I prezzi di Haiku, in dollari per milione: gli stessi di listino.json.
P_INPUT, P_OUTPUT, P_W5M, P_W1H, P_READ = 0.10, 0.50, 0.125, 0.20, 0.01
TABELLA = ("## Context Usage\n\n**Model:** claude-haiku-5-5  \n"
           "**Tokens:** 28 / 1m (0%)\n\n"
           "| Category | Tokens | Percentage |\n"
           "|----------|--------|------------|\n"
           "| System prompt | 18 | 0.0% |\n"
           "| Messages | 10 | 0.0% |\n")


class Rifiutato(Exception):
    """Argomenti che il finto non accetta: il messaggio d'errore."""


def modi() -> List[str]:
    """Le parole di FINTO_MODI."""
    return os.environ.get("FINTO_MODI", "").split()


def valore_modo(nome: str) -> Optional[str]:
    """Il valore di una parola nome=valore di FINTO_MODI, o None."""
    for parola in modi():
        if parola.startswith(nome + "="):
            return parola.split("=", 1)[1]
    return None


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
    dato: Dict[str, Any] = {
        "argv": argv, "cwd": os.getcwd(), "prompt": prompt,
        "chiave": "ANTHROPIC_API_KEY" in os.environ,
        "effort": "CLAUDE_CODE_EFFORT_LEVEL" in os.environ,
        "stdin_nullo": stdin_nullo(),
        "sistema": opzioni.get("--system-prompt", "")}
    with open(registro, "a", encoding="utf-8") as fh:
        fh.write(json.dumps(dato, ensure_ascii=False) + "\n")


def uso_finto(prompt: str, sistema: str, uscita: int) -> Dict[str, Any]:
    """Un usage inventato, con la prima richiesta scritta in cache."""
    prima = 150 + len(prompt) // 4 + len(sistema) // 4
    if "pari" in modi():  # stessi token in entrata: un costo uguale
        prima = 240
    cc5m, cc1h, letti = 0, prima, 0
    if "lettura" in modi():
        cc1h, letti = 0, prima
    elif "cinque-minuti" in modi():
        cc5m, cc1h = prima, 0
    return {"input_tokens": 3, "cache_creation_input_tokens": cc5m + cc1h,
            "cache_read_input_tokens": letti, "output_tokens": uscita,
            "cache_creation": {"ephemeral_5m_input_tokens": cc5m,
                               "ephemeral_1h_input_tokens": cc1h}}


def costo_finto(uso: Dict[str, Any]) -> float:
    """Il conto giusto dell'usage inventato, ai prezzi di Haiku."""
    dettaglio = uso["cache_creation"]
    return (uso["input_tokens"] * P_INPUT
            + dettaglio["ephemeral_5m_input_tokens"] * P_W5M
            + dettaglio["ephemeral_1h_input_tokens"] * P_W1H
            + uso["cache_read_input_tokens"] * P_READ
            + uso["output_tokens"] * P_OUTPUT) / 1_000_000


def uscita_finta(lungo: bool) -> int:
    """I token in uscita del braccio, secondo i modi."""
    if "pari" in modi():
        return 40
    if "inversa" in modi():
        return 30 if lungo else 40
    return 640 if lungo else 40


def base_risultato(sessione: str) -> Dict[str, Any]:
    """I campi comuni del JSON finto."""
    errore = "errore" in modi()
    return {"type": "result",
            "subtype": "error_during_execution" if errore else "success",
            "is_error": errore, "num_turns": 1, "duration_ms": 1400,
            "duration_api_ms": 1200, "session_id": sessione,
            "permission_denials": [], "stop_reason": "end_turn"}


def risposta_chiamata(opzioni: Dict[str, str], prompt: str,
                      sessione: str) -> Dict[str, Any]:
    """Il JSON di una chiamata al modello finto."""
    lungo = "sei sezioni" in prompt
    uscita = uscita_finta(lungo)
    uso = uso_finto(prompt, opzioni.get("--system-prompt", ""), uscita)
    corpo = base_risultato(sessione)
    testo = "1. Sintomo\n2. Cause\n" * 3 if lungo else "Causa probabile: saturazione."
    corpo["result"] = testo + NOTA
    corpo["usage"] = uso
    corpo["total_cost_usd"] = costo_finto(uso)
    if "costo-diverso" in modi():
        corpo["total_cost_usd"] += 0.000123
    nome = "claude-haiku-5-5"
    if "altro-modello" in modi():
        nome = "claude-sonnet-5-5"
    corpo["modelUsage"] = {nome: {"inputTokens": 3, "outputTokens": uscita,
                                  "costUSD": corpo["total_cost_usd"],
                                  "canonicalModel": nome}}
    if "due-modelli" in modi():
        corpo["modelUsage"]["claude-sonnet-5-5"] = {"inputTokens": 1}
    if "modello-vuoto" in modi():
        corpo["modelUsage"] = {}
    if "senza-usage" in modi():
        del corpo["usage"]
    if "senza-costo" in modi():
        del corpo["total_cost_usd"]
    if "usage-rotto" in modi():
        corpo["usage"]["input_tokens"] = "tre"
    if "senza-split" in modi():
        del corpo["usage"]["cache_creation"]
    return corpo


def risposta_contesto(sessione: str) -> Dict[str, Any]:
    """Il JSON di /context: la tabella, nessuna chiamata al modello."""
    corpo = base_risultato(sessione)
    corpo.update({"num_turns": 0, "duration_ms": 200, "duration_api_ms": 0,
                  "total_cost_usd": 0, "modelUsage": {},
                  "local_command": "context", "result": TABELLA,
                  "usage": {"input_tokens": 0, "output_tokens": 0,
                            "cache_creation_input_tokens": 0,
                            "cache_read_input_tokens": 0,
                            "cache_creation": {
                                "ephemeral_5m_input_tokens": 0,
                                "ephemeral_1h_input_tokens": 0}}})
    if "contesto-errore" in modi():
        corpo["is_error"] = True
        corpo["subtype"] = "error_during_execution"
    if "contesto-costa" in modi():
        corpo.update({"num_turns": 1, "total_cost_usd": 0.0002})
        corpo["usage"]["input_tokens"] = 12
    return corpo


def main(argv: List[str]) -> int:
    if argv == ["--version"]:
        print("9.9.9 (Claude Code finto)")
        return 0
    try:
        opzioni, prompt = argomenti(argv)
    except Rifiutato as exc:
        print(str(exc), file=sys.stderr)
        return 1
    scrivi_log(argv, opzioni, prompt)
    if "ko" in modi():
        return 1
    ko = valore_modo("ko-se")
    if ko and ko in prompt:
        return 1
    if "json-rotto" in modi():
        print("{questa riga non è JSON")
        return 0
    sessione = str(uuid.uuid4())
    if prompt == "/context":
        corpo = risposta_contesto(sessione)
    else:
        corpo = risposta_chiamata(opzioni, prompt, sessione)
    print(json.dumps(corpo, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
