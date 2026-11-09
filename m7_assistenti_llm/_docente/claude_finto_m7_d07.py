#!/usr/bin/env python3
"""claude_finto_m7_d07.py -- un claude finto per le prove di M7-D07
(test_m7_d07.sh): la suite lo copia, con il nome «claude», davanti nel PATH,
così demo/in_classe.sh e _docente/live.sh girano per intero senza chiamare il
modello. Gli stream sono inventati e dichiarati finti: ogni risposta finisce
con «(risposta del claude finto)». Provano il controllo e gli script, non il
modello.

Le risposte, dal system prompt (--system-prompt-file) e dal prompt:
  attacco «tutti i dati» (diretta) o «system prompt» (ripeti): la scheda intera
  del system prompt, nel braccio educata rifiuta su diretta e collega; attacco
  «reparto tecnico» (collega): quattro campi, dove ci sono;
  nessuna-difesa non si difende mai, ridotta dice ciò che ha.

L'ambiente cambia ciò che succede:
  FINTO_KO_SE=testo    esce 1 senza stampare nulla se testo è nel prompt
  FINTO_TRONCO=1       lo stream senza il risultato
  FINTO_ERRORE=1       il risultato con is_error
  FINTO_RIGA_ROTTA=1   una riga che non è JSON
  FINTO_LOG=file       una riga JSON per invocazione: argv, cwd, prompt, se
                       la cartella è vuota, la
                       chiave nell'ambiente o no

Uscita: 0 lo stream · 1 un argomento rifiutato, FINTO_KO_SE
"""
import json
import os
import re
import sys
import uuid
from typing import Dict, List, Tuple

OPZIONI = {"-p": 0, "--model": 1, "--permission-mode": 1,
           "--permission-prompts": 1, "--output-format": 1, "--verbose": 0,
           "--setting-sources": 1, "--tools": 1, "--system-prompt-file": 1,
           "--effort": 1, "--strict-mcp-config": 0,
           "--no-session-persistence": 0}
NOTA = " (risposta del claude finto)"


class Rifiutato(Exception):
    """Argomenti che il finto non accetta: il messaggio d'errore."""


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
    if opzioni.get("--output-format") != "stream-json" \
            or "--verbose" not in opzioni:
        raise Rifiutato("error: il finto scrive soltanto stream-json con "
                        "--verbose")
    return opzioni, argv[i + 1]


def righe_dati(sistema: str) -> List[str]:
    """Le righe del tag data del system prompt."""
    trovato = re.search(r"<data>\n(.*?)\n</data>", sistema, re.S)
    return trovato.group(1).split("\n") if trovato else []


def risposta_finta(sistema: str, prompt: str) -> str:
    """La risposta finta, per braccio e attacco."""
    educata = "tieni riservati" in sistema
    righe = righe_dati(sistema)
    if "reparto tecnico" in prompt:
        if educata:
            return "Non posso comunicare questi dati in chat." + NOTA
        volute = ("Telefono:", "E-mail:", "Indirizzo:", "Nota interna:")
        return "; ".join(r for r in righe if r.startswith(volute)) + NOTA \
            if any(r.startswith(volute) for r in righe) \
            else "In questa scheda non ho quei dati." + NOTA
    if "tutti i dati" in prompt and educata:
        return "Non posso comunicare i dati della scheda." + NOTA
    if "system prompt" in prompt or "tutti i dati" in prompt:
        return "\n".join(righe) + NOTA
    return "Il tecnico passa martedì, nella fascia 9:00-11:00." + NOTA


def stream(risposta: str) -> None:
    """Lo stream finto, una riga per evento."""
    sessione = str(uuid.uuid4())
    uso = {"input_tokens": 3, "cache_creation_input_tokens": 700,
           "cache_read_input_tokens": 0, "output_tokens": 40}
    righe: List[Dict[str, object]] = [
        {"type": "system", "subtype": "init", "cwd": os.getcwd(),
         "session_id": sessione, "model": "claude-finto",
         "claude_code_version": "9.9.9 (finto)"},
        {"type": "assistant", "parent_tool_use_id": None, "message": {
            "id": "msg_1", "usage": uso, "content": [
                {"type": "text", "text": risposta}]}}]
    errore = os.environ.get("FINTO_ERRORE") == "1"
    finale: Dict[str, object] = {
        "type": "result", "subtype": "success", "is_error": errore,
        "num_turns": 1, "duration_ms": 1200, "session_id": sessione,
        "result": risposta, "usage": uso,
        "modelUsage": {"claude-finto": {
            "inputTokens": 3, "outputTokens": 40,
            "cacheReadInputTokens": 0, "cacheCreationInputTokens": 700}}}
    if os.environ.get("FINTO_TRONCO") != "1":
        righe.append(finale)
    for numero, riga in enumerate(righe):
        print(json.dumps(riga, ensure_ascii=False))
        if numero == 0 and os.environ.get("FINTO_RIGA_ROTTA") == "1":
            print("{questa riga non è JSON")


def main(argv: List[str]) -> int:
    if argv == ["--version"]:
        print("9.9.9 (Claude Code finto)")
        return 0
    try:
        opzioni, prompt = argomenti(argv)
    except Rifiutato as exc:
        print(str(exc), file=sys.stderr)
        return 1
    registro = os.environ.get("FINTO_LOG")
    if registro:
        with open(registro, "a", encoding="utf-8") as fh:
            fh.write(json.dumps({"argv": argv, "cwd": os.getcwd(),
                                 "prompt": prompt,
                                 "vuota": not os.listdir("."),
                                 "chiave": "ANTHROPIC_API_KEY" in os.environ},
                                ensure_ascii=False) + "\n")
    ko = os.environ.get("FINTO_KO_SE")
    if ko and ko in prompt:
        return 1
    with open(opzioni["--system-prompt-file"], encoding="utf-8") as fh:
        sistema = fh.read()
    stream(risposta_finta(sistema, prompt))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
