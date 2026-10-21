#!/usr/bin/env python3
"""claude_finto_m3_demo.py -- un claude finto per le prove di M3-D01 e
M3-D02 (test_m3_d01.sh, test_m3_d02.sh).

Le suite lo copiano, con il nome «claude», davanti nel PATH: così i
live.sh e i blocchi dei README girano per intero senza chiamare il modello
e senza consumare il piano. Le risposte sono scritte qui, inventate e
dichiarate finte: nessuna è una risposta di Claude.

Gli argomenti: le opzioni che usano i due elementi (OPZIONI, con quanti
valori prendono), poi il prompt, dopo «--» oppure come unico argomento che
non comincia con «-». Un'opzione che non conosce la rifiuta («error:
unknown option», uscita 1), come un --output-format che non conosce.

Ogni invocazione aggiunge a FINTO_LOG, se c'è, una riga JSON
{"argv": [...], "chiave": true|false}: gli argomenti, e se
ANTHROPIC_API_KEY era nell'ambiente.
  --version                    una versione finta;
  --output-format json         (M3-D01) un JSON di claude -p: al prompt
                               che nomina allarmi-piccola.png il testo
                               FINTO_PICCOLA (default «non leggibile»), a
                               quello che nomina allarmi.png FINTO_GRANDE
                               (default le due righe giuste della tabella);
  --output-format stream-json  (M3-D02) uno stream finto: una riga JSON
                               per evento, l'ultima il risultato; vuole
                               --verbose. Alla domanda che nomina il
                               changelog un blocco tool_use per ogni nome
                               di FINTO_STRUMENTI_ATTUALE (default
                               «WebSearch»), alla domanda sulla fibra uno
                               per ogni nome di FINTO_STRUMENTI_STABILE
                               (default nessuno); FINTO_TRONCO=1 toglie la
                               riga del risultato.
  FINTO_ESITO=ko               esce 1 senza stampare nulla.
Uscita: 0 risposta · 1 FINTO_ESITO=ko, o un argomento che rifiuta
"""
import json
import os
import sys
from typing import Dict, List, Tuple

OPZIONI = {"-p": 0, "--print": 0, "--verbose": 0, "--strict-mcp-config": 0,
           "--no-session-persistence": 0, "--model": 1, "--effort": 1,
           "--tools": 1, "--allowedTools": 1, "--output-format": 1,
           "--permission-mode": 1, "--permission-prompts": 1,
           "--setting-sources": 1, "--system-prompt": 1}
FORMATI = ("text", "json", "stream-json")
GRANDE = "critici: 3\napparati: olt-pergine-01, ptp-cles-01, sbc-trento-01"
PICCOLA = "non leggibile"
URL_FINTO = "https://changelog.example.org/claude-code"
ATTUALE = ("Risposta finta del claude finto: la versione 9.9.9. "
           "Fonte: %s" % URL_FINTO)
STABILE = ("Risposta finta del claude finto, prima frase. "
           "Seconda frase finta.")


class Rifiutato(Exception):
    """Argomenti che il finto non accetta: il messaggio d'errore."""


def argomenti(argv: List[str]) -> Tuple[Dict[str, str], str]:
    """(le opzioni con i loro valori, il prompt) degli argomenti."""
    opzioni: Dict[str, str] = {}
    operandi: List[str] = []
    i = 0
    while i < len(argv):
        parola = argv[i]
        if parola == "--":
            operandi += argv[i + 1:]
            break
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
    if formato == "stream-json" and "--verbose" not in opzioni:
        raise Rifiutato("error: il claude finto vuole --verbose con "
                        "--output-format stream-json")
    return opzioni, operandi[0]


def risultato(testo: str, turni: int) -> dict:
    """Il messaggio del risultato, come in claude -p."""
    return {"type": "result", "subtype": "success", "is_error": False,
            "result": testo, "num_turns": turni,
            "session_id": "sessione-finta", "permission_denials": [],
            "usage": {"input_tokens": 9, "output_tokens": 5}}


def ingresso(nome: str) -> dict:
    """L'input finto di uno strumento."""
    if nome == "WebSearch":
        return {"query": "ricerca finta del claude finto"}
    if nome == "WebFetch":
        return {"url": URL_FINTO, "prompt": "domanda finta sulla pagina"}
    return {}


def stream(prompt: str) -> List[dict]:
    """Gli eventi dello stream finto di una domanda di M3-D02."""
    if "changelog" in prompt:
        nomi = os.environ.get("FINTO_STRUMENTI_ATTUALE", "WebSearch")
        testo = ATTUALE
    else:
        nomi = os.environ.get("FINTO_STRUMENTI_STABILE", "")
        testo = STABILE
    eventi = [{"type": "system", "subtype": "init",
               "session_id": "sessione-finta", "model": "claude-finto"}]
    for numero, nome in enumerate(n for n in nomi.split(",") if n):
        ident = "toolu_finto_%d" % numero
        eventi.append({"type": "assistant", "message": {
            "role": "assistant", "content": [{
                "type": "tool_use", "id": ident, "name": nome,
                "input": ingresso(nome)}]}})
        eventi.append({"type": "user", "message": {
            "role": "user", "content": [{
                "type": "tool_result", "tool_use_id": ident,
                "content": "risultato finto"}]}})
    eventi.append({"type": "assistant", "message": {
        "role": "assistant", "content": [{"type": "text", "text": testo}]}})
    if os.environ.get("FINTO_TRONCO") != "1":
        eventi.append(risultato(testo, len(eventi)))
    return eventi


def lettura(prompt: str) -> str:
    """La risposta finta di M3-D01, dall'immagine che il prompt nomina."""
    if "allarmi-piccola.png" in prompt:
        return os.environ.get("FINTO_PICCOLA", PICCOLA)
    return os.environ.get("FINTO_GRANDE", GRANDE)


def registra(argv: List[str]) -> None:
    """Una riga in FINTO_LOG, se c'è."""
    log = os.environ.get("FINTO_LOG")
    if log:
        with open(log, "a", encoding="utf-8") as fh:
            fh.write(json.dumps({
                "argv": argv,
                "chiave": bool(os.environ.get("ANTHROPIC_API_KEY"))},
                ensure_ascii=False) + "\n")


def main(argv: List[str]) -> int:
    registra(argv)
    if argv[:1] == ["--version"]:
        print("0.0.0 (Claude Code, finto)")
        return 0
    try:
        opzioni, prompt = argomenti(argv)
    except Rifiutato as exc:
        sys.stderr.write("%s\n" % exc)
        return 1
    if os.environ.get("FINTO_ESITO", "ok") != "ok":
        return 1
    if opzioni.get("--output-format") == "stream-json":
        for evento in stream(prompt):
            print(json.dumps(evento, ensure_ascii=False))
        return 0
    testo = lettura(prompt)
    if opzioni.get("--output-format") == "json":
        print(json.dumps(risultato(testo, 2), ensure_ascii=False))
    else:
        print(testo)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
