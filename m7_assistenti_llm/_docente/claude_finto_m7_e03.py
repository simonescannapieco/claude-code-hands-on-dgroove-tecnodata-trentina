#!/usr/bin/env python3
"""claude_finto_m7_e03.py -- un claude finto per le prove di M7-E03
(test_m7_e03.sh).

La suite lo mette davanti nel PATH attraverso un wrapper bash, che gli ridà
FINTO_LOG e FINTO_MODI (prova.py ripulisce l'ambiente delle chiamate). Gli
stream sono inventati e dichiarati finti: provano la verifica e gli script, non
il modello.

Tre ruoli, dagli argomenti:
  --agent giudice      il giudice (JSON): voti per criterio in structured_output,
                       2 a tutti, salvo lo scenario SC-20, con C6 a 0 (non
                       superato); FINTO_MODI «giudice»: {"SC-xx": {"C6": 2}} per
                       cambiare i voti di uno scenario, o {"SC-xx": {"C1": null}}
                       per un voto mancante; «giudice_rc1»: true fa uscire 1;
  --mcp-config         l'assistente su un caso (stream-json): due righe nel
                       registro (BANCO_REGISTRO), la risposta finale; FINTO_MODI
                       per esecuzione (la cartella del caso, per esempio
                       «v0/CASO-01») con «rc1», «tronco», «errore», «server_ko»
                       (il server MCP non parte: nell'evento init status failed
                       e nessuno strumento, nessuna riga nel registro);
  altrimenti           la sessione che scrive i casi nuovi (il prompt del
                       README): scrive casi-nuovi/caso-06-… e caso-07-… nella
                       cartella da cui parte e risponde; FINTO_MODI «senza_casi»:
                       true non scrive i file; «caso_rotto»: true scrive un file
                       senza i campi; «sessione_rc1»: true esce 1.

Accetta le opzioni di prova.py e di handson::claude_p; rifiuta un'opzione che
non conosce. --version stampa una versione finta.

FINTO_LOG=file: una riga JSON per invocazione: ruolo, argv, cwd, prompt, chiave
(ANTHROPIC_API_KEY era nell'ambiente), system (il testo di --system-prompt-file),
registro.

Uscita: 0 · 1 un argomento rifiutato, un modo che lo chiede
"""
from __future__ import annotations

import json
import os
import re
import sys
from pathlib import Path
from typing import Any, Dict, List, Tuple

OPZIONI = {"-p": 0, "--allowedTools": 1, "--model": 1, "--permission-mode": 1,
           "--permission-prompts": 1, "--output-format": 1, "--verbose": 0,
           "--setting-sources": 1, "--tools": 1, "--mcp-config": 1,
           "--strict-mcp-config": 0, "--effort": 1,
           "--no-session-persistence": 0, "--system-prompt-file": 1,
           "--agent": 1, "--json-schema": 1}
NOTA = " (risposta del claude finto)"
CRITERI = tuple("C%d" % i for i in range(1, 10))
CASO_06 = {"id": "CASO-06", "titolo": "un caso finto",
           "scenario": "sc-11-router-proprio-password.json",
           "messaggio": "messaggio finto del caso che deve servire.",
           "asserzioni": {"deve_chiamare": ["verifica_identita"]}}
CASO_07 = {"id": "CASO-07", "titolo": "il suo opposto finto",
           "scenario": "sc-11-router-proprio-password.json",
           "messaggio": "messaggio finto del caso che deve rifiutare.",
           "asserzioni": {"non_deve_chiamare": ["registra_accredito"]}}


class Rifiutato(Exception):
    """Argomenti che il finto non accetta."""


def argomenti(argv: List[str]) -> Tuple[Dict[str, str], str]:
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
    return opzioni, argv[i + 1]


def modi() -> Dict[str, Any]:
    percorso = os.environ.get("FINTO_MODI", "")
    if percorso and os.path.isfile(percorso):
        with open(percorso, encoding="utf-8") as fh:
            return json.load(fh)
    return {}


def scrivi_log(ruolo: str, argv: List[str], opzioni: Dict[str, str],
               prompt: str, registro: str) -> None:
    percorso = os.environ.get("FINTO_LOG")
    if not percorso:
        return
    sistema = None
    if "--system-prompt-file" in opzioni:
        sistema = Path(opzioni["--system-prompt-file"]).read_text(
            encoding="utf-8")
    dato = {"ruolo": ruolo, "argv": argv, "cwd": os.getcwd(), "prompt": prompt,
            "chiave": "ANTHROPIC_API_KEY" in os.environ, "system": sistema,
            "registro": registro}
    with open(percorso, "a", encoding="utf-8") as fh:
        fh.write(json.dumps(dato, ensure_ascii=False) + "\n")


def giudice(prompt: str, modo: Dict[str, Any]) -> int:
    """I voti del giudice, in JSON."""
    if modo.get("giudice_rc1"):
        return 1
    trovato = re.search(r'"id":\s*"(SC-\d+)"', prompt)
    scenario = trovato.group(1) if trovato else ""
    punti: Dict[str, Any] = {c: 2 for c in CRITERI}
    if scenario == "SC-20":
        punti["C6"] = 0
    punti.update((modo.get("giudice") or {}).get(scenario, {}))
    print(json.dumps({"type": "result", "subtype": "success",
                      "is_error": False, "result": "fatto" + NOTA,
                      "num_turns": 1, "duration_ms": 20, "session_id": "s-g",
                      "structured_output": {
                          "punteggi": punti,
                          "motivazioni": {"C1": "motivo finto"}}},
                     ensure_ascii=False))
    return 0


def assistente(opzioni: Dict[str, str], modo: Dict[str, Any]) -> int:
    """Un caso: due righe nel registro e lo stream."""
    with open(opzioni["--mcp-config"], encoding="utf-8") as fh:
        env = json.load(fh)["mcpServers"]["assistenza"]["env"]
    registro = Path(env["BANCO_REGISTRO"])
    nome = "%s/%s" % (registro.parent.parent.name, registro.parent.name)
    per_caso = {**modo.get("default", {}), **modo.get(nome, {})}
    if per_caso.get("rc1"):
        return 1
    server_ko = bool(per_caso.get("server_ko"))
    with registro.open("a", encoding="utf-8") as fh:
        for n, (capacita, risultato) in enumerate((
                ("verifica_identita", {"esito": "riconosciuto"}),
                ("cerca_kb", {"risultati": []})), 1):
            if server_ko:
                break
            fh.write(json.dumps({
                "n": n, "strumento": capacita, "capacita": capacita,
                "argomenti": {}, "risultato": risultato, "errore": False},
                ensure_ascii=False) + "\n")
    risposta = "Risposta finta dell'assistente." + NOTA
    righe: List[Dict[str, Any]] = [
        {"type": "system", "subtype": "init", "session_id": "s-a",
         "model": "claude-finto", "claude_code_version": "9.9.9 (finto)",
         "tools": [] if server_ko else ["mcp__assistenza__verifica_identita",
                                        "mcp__assistenza__cerca_kb"],
         "mcp_servers": [{"name": "assistenza",
                          "status": "failed" if server_ko else "connected"}]},
        {"type": "assistant", "parent_tool_use_id": None, "message": {
            "usage": {"input_tokens": 3, "cache_creation_input_tokens": 1500,
                      "cache_read_input_tokens": 0, "output_tokens": 20},
            "content": [{"type": "text", "text": risposta}]}}]
    fine = {"type": "result", "subtype": "success",
            "is_error": bool(per_caso.get("errore")), "num_turns": 3,
            "duration_ms": 2400, "result": risposta, "session_id": "s-a",
            "usage": {"input_tokens": 3, "output_tokens": 20},
            "modelUsage": {"claude-finto": {"inputTokens": 3,
                                            "outputTokens": 20,
                                            "cacheReadInputTokens": 0,
                                            "cacheCreationInputTokens": 1500}}}
    if not per_caso.get("tronco"):
        righe.append(fine)
    for riga in righe:
        print(json.dumps(riga, ensure_ascii=False))
    return 0


def sessione_casi(modo: Dict[str, Any]) -> int:
    """La sessione che scrive i casi nuovi nella cartella corrente."""
    if modo.get("sessione_rc1"):
        return 1
    if not modo.get("senza_casi"):
        cartella = Path("casi-nuovi")
        cartella.mkdir(exist_ok=True)
        primo = {"id": "CASO-06"} if modo.get("caso_rotto") else CASO_06
        (cartella / "caso-06-finto.json").write_text(
            json.dumps(primo, ensure_ascii=False, indent=1) + "\n",
            encoding="utf-8")
        (cartella / "caso-07-finto.json").write_text(
            json.dumps(CASO_07, ensure_ascii=False, indent=1) + "\n",
            encoding="utf-8")
    print(json.dumps({"type": "system", "subtype": "init",
                      "session_id": "s-c"}))
    print(json.dumps({"type": "result", "subtype": "success", "is_error": False,
                      "num_turns": 4, "duration_ms": 8000,
                      "result": "Scritti i due casi." + NOTA,
                      "session_id": "s-c"}, ensure_ascii=False))
    return 0


def main(argv: List[str]) -> int:
    if argv == ["--version"]:
        print("9.9.9 (Claude Code finto)")
        return 0
    try:
        opzioni, prompt = argomenti(argv)
    except Rifiutato as exc:
        print(str(exc), file=sys.stderr)
        return 1
    modo = modi()
    if "--agent" in opzioni:
        ruolo = "giudice"
        registro = ""
    elif "--mcp-config" in opzioni:
        ruolo = "assistente"
        with open(opzioni["--mcp-config"], encoding="utf-8") as fh:
            registro = json.load(fh)["mcpServers"]["assistenza"]["env"][
                "BANCO_REGISTRO"]
    else:
        ruolo = "sessione"
        registro = ""
    scrivi_log(ruolo, argv, opzioni, prompt, registro)
    if ruolo == "giudice":
        return giudice(prompt, modo)
    if ruolo == "assistente":
        return assistente(opzioni, modo)
    return sessione_casi(modo)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
