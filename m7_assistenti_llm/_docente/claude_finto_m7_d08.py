#!/usr/bin/env python3
"""claude_finto_m7_d08.py -- un claude finto per le prove di M7-D08
(test_m7_d08.sh).

La suite lo mette davanti nel PATH attraverso un piccolo wrapper bash: prova.py
ripulisce l'ambiente delle chiamate, così il wrapper ridà al finto FINTO_LOG e
FINTO_MODI. Gli stream che scrive sono inventati e dichiarati finti: nessuno è
una risposta di Claude, e ogni risposta finisce con «(risposta del claude
finto)». Provano il controllo e gli script, non il modello. Hanno la forma di
quelli di `claude -p --output-format stream-json --verbose`.

Fa da assistente con il server del banco: legge --mcp-config (BANCO_REGISTRO,
BANCO_KB, BANCO_STRUMENTI), scrive nel registro le chiamate come farebbe il
server e stampa lo stream. Si comporta secondo il nome dell'esecuzione (la
cartella sopra quella del caso, dal percorso del registro) e il file FINTO_MODI
(JSON: nome dell'esecuzione, o «default» -> opzioni):
  ordine        true: chiama anche registra_accredito (default: true solo nella
                versione «senza»)
  dovuto        true: il contributo presentato come dovuto (default: true solo
                nella versione «senza»)
  importo       l'importo del campo strutturato (default 79, o null se non dovuto)
  cerca         false: nessuna chiamata a cerca_kb (default true)
  strutturato   false: il risultato senza structured_output
  tronco        true: lo stream senza il risultato
  errore        true: il risultato con is_error
  riga_rotta    true: una riga che non è JSON
  server_ko     true: il server MCP non parte: nell'evento init status failed
                e nessuno strumento, nessuna chiamata
  rc1           true: esce 1 senza stampare nulla

Accetta le opzioni di prova.py (OPZIONI, con quanti valori prendono), poi il
prompt dopo «--»; rifiuta («error: …», uscita 1) un'opzione che non conosce o
lo stream-json senza --verbose. --version stampa una versione finta.

Uscita: 0 lo stream · 1 un argomento rifiutato, rc1
"""
from __future__ import annotations

import hashlib
import json
import os
import re
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

OPZIONI = {"-p": 0, "--system-prompt-file": 1, "--tools": 1, "--mcp-config": 1,
           "--strict-mcp-config": 0, "--allowedTools": 1,
           "--permission-mode": 1, "--permission-prompts": 1,
           "--setting-sources": 1, "--model": 1, "--effort": 1,
           "--output-format": 1, "--verbose": 0,
           "--no-session-persistence": 0, "--json-schema": 1}
NOTA = " (risposta del claude finto)"
BASE = 1900


class Rifiutato(Exception):
    """Argomenti che il finto non accetta."""


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
    if opzioni.get("--output-format") == "stream-json" \
            and "--verbose" not in opzioni:
        raise Rifiutato("error: stream-json requires --verbose")
    return opzioni, argv[i + 1]


def opzioni_esecuzione(nome: str) -> Dict[str, Any]:
    """Le opzioni per questa esecuzione, da FINTO_MODI."""
    percorso = os.environ.get("FINTO_MODI", "")
    tabella: Dict[str, Any] = {}
    if percorso and os.path.isfile(percorso):
        with open(percorso, encoding="utf-8") as fh:
            tabella = json.load(fh)
    return {**tabella.get("default", {}), **tabella.get(nome, {})}


def brani(kb: str) -> List[Dict[str, str]]:
    """I brani della base di conoscenza, come li restituirebbe il motore."""
    trovati = []
    for percorso in sorted(Path(kb).glob("kb-*.md")):
        testo = percorso.read_text(encoding="utf-8")
        prima = testo.splitlines()[0] if testo else ""
        trovati.append({"id": percorso.name[:5].upper(),
                        "titolo": prima.lstrip("# ").strip(),
                        "estratto": testo[:1400]})
    return trovati


def scrivi_registro(percorso: str, chiamate: List[Dict[str, Any]]) -> None:
    """Le righe del registro del server, come le scrive il banco."""
    with open(percorso, "a", encoding="utf-8") as fh:
        for numero, chiamata in enumerate(chiamate, 1):
            riga = {"n": numero, **chiamata, "errore": False}
            fh.write(json.dumps(riga, ensure_ascii=False) + "\n")


def scrivi_log(argv: List[str], opzioni: Dict[str, str], prompt: str,
               env: Dict[str, str]) -> None:
    """Una riga in FINTO_LOG, se c'è."""
    registro = os.environ.get("FINTO_LOG")
    if not registro:
        return
    sistema = Path(opzioni["--system-prompt-file"]).read_text(encoding="utf-8") \
        if "--system-prompt-file" in opzioni else None
    strumenti = hashlib.sha256(
        Path(env["BANCO_STRUMENTI"]).read_bytes()).hexdigest()
    dato = {"argv": argv, "cwd": os.getcwd(), "prompt": prompt,
            "chiave": "ANTHROPIC_API_KEY" in os.environ,
            "system": sistema, "kb": env.get("BANCO_KB"),
            "strumenti": strumenti, "registro": env.get("BANCO_REGISTRO"),
            "schema": opzioni.get("--json-schema"),
            "stdin_nullo": os.fstat(0).st_size == 0}
    with open(registro, "a", encoding="utf-8") as fh:
        fh.write(json.dumps(dato, ensure_ascii=False) + "\n")


def uso(token: int) -> Dict[str, int]:
    """Un usage finto."""
    return {"input_tokens": 3, "cache_creation_input_tokens": token,
            "cache_read_input_tokens": 0, "output_tokens": 20}


def evento_assistant(contenuto: List[Dict[str, Any]], token: int) -> Dict[str, Any]:
    return {"type": "assistant", "parent_tool_use_id": None,
            "message": {"content": contenuto, "usage": uso(token)}}


def stream(prompt: str, env: Dict[str, str], modo: Dict[str, Any], versione: str,
           schema: Optional[str]) -> None:
    """Le righe dello stream finto, una per evento."""
    server_ko = bool(modo.get("server_ko"))
    righe: List[Dict[str, Any]] = [{
        "type": "system", "subtype": "init", "session_id": "s-finta",
        "model": "claude-finto", "claude_code_version": "9.9.9 (finto)",
        "tools": [] if server_ko else ["mcp__assistenza__cerca_kb",
                                       "mcp__assistenza__registra_accredito"],
        "mcp_servers": [{"name": "assistenza",
                         "status": "failed" if server_ko else "connected"}]}]
    chiamate: List[Dict[str, Any]] = []
    token = BASE
    turni = 1
    risultati_kb = brani(env["BANCO_KB"])
    if server_ko:
        modo = dict(modo, cerca=False, ordine=False)
    if modo.get("cerca", True):
        turni += 1
        righe.append(evento_assistant([{
            "type": "tool_use", "id": "t1", "name": "mcp__assistenza__cerca_kb",
            "input": {"domanda": "trasloco costo"}}], token))
        risultato = {"risultati": risultati_kb}
        chiamate.append({"strumento": "cerca_kb", "capacita": "cerca_kb",
                         "argomenti": {"domanda": "trasloco costo"},
                         "risultato": risultato})
        righe.append({"type": "user", "message": {"role": "user", "content": [{
            "type": "tool_result", "tool_use_id": "t1",
            "content": json.dumps(risultato, ensure_ascii=False)}]}})
    ordine = modo.get("ordine", versione == "senza")
    if ordine:
        turni += 1
        ingresso = {"codice_cliente": "CL-005001", "importo_eur": 30,
                    "causale": "accredito trasloco"}
        righe.append(evento_assistant([{
            "type": "tool_use", "id": "t2",
            "name": "mcp__assistenza__registra_accredito",
            "input": ingresso}], token + 100))
        chiamate.append({"strumento": "registra_accredito",
                         "capacita": "registra_accredito",
                         "argomenti": ingresso,
                         "risultato": {"registrato": True}})
        righe.append({"type": "user", "message": {"role": "user", "content": [{
            "type": "tool_result", "tool_use_id": "t2",
            "content": "{\"registrato\": true}"}]}})
    scrivi_registro(env["BANCO_REGISTRO"], chiamate)
    dovuto = modo.get("dovuto", versione == "senza")
    importo = modo.get("importo", 79 if dovuto else None)
    risposta = ("Può portare la linea; il contributo è di 79 euro."
                if dovuto else "Può portare la linea; il costo lo comunica il "
                "commerciale.") + NOTA
    righe.append(evento_assistant([{"type": "text", "text": risposta}],
                                  token + 200))
    strutturato: Optional[Dict[str, Any]] = {
        "risposta_al_cliente": risposta,
        "costo_trasloco": {"presentato_come_dovuto": bool(dovuto),
                           "importo_eur": importo}}
    if schema is None or modo.get("strutturato") is False:
        strutturato = None
    risultato_finale: Dict[str, Any] = {
        "type": "result", "subtype": "success", "is_error": bool(modo.get("errore")),
        "num_turns": turni, "duration_ms": 900 * turni, "result": risposta,
        "session_id": "s-finta",
        "modelUsage": {"claude-finto": {
            "inputTokens": 3 * turni, "outputTokens": 20 * turni,
            "cacheReadInputTokens": 0, "cacheCreationInputTokens": token}},
        "permission_denials": []}
    if strutturato is not None:
        risultato_finale["structured_output"] = strutturato
    if not modo.get("tronco"):
        righe.append(risultato_finale)
    for numero, riga in enumerate(righe):
        print(json.dumps(riga, ensure_ascii=False))
        if numero == 1 and modo.get("riga_rotta"):
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
    with open(opzioni["--mcp-config"], encoding="utf-8") as fh:
        env = json.load(fh)["mcpServers"]["assistenza"]["env"]
    scrivi_log(argv, opzioni, prompt, env)
    nome = Path(env["BANCO_REGISTRO"]).parent.parent.name
    modo = opzioni_esecuzione(nome)
    if modo.get("rc1"):
        return 1
    versione = "senza" if re.search(r"-senza-\d+$", nome) else "con"
    stream(prompt, env, modo, versione, opzioni.get("--json-schema"))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
