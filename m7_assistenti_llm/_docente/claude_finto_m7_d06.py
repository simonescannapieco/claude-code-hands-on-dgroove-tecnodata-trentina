#!/usr/bin/env python3
"""claude_finto_m7_d06.py -- un claude finto per le prove di M7-D06
(test_m7_d06.sh): sta al posto di `claude` davanti nel PATH, così
demo/in_classe.sh e _docente/live.sh girano per intero senza chiamare il
modello e senza consumare il piano. Ciò che scrive è inventato e dichiarato
finto: ogni risposta finisce con «(risposta del claude finto)», e prova gli
script e il controllo, non il modello.

prova.py ripulisce l'ambiente: per questo la suite non lo chiama direttamente,
ma attraverso uno script che fissa FINTO_LOG e FINTO_MODO letti da un file.

Fa quello che il banco chiede: legge la configurazione MCP che prova.py gli
passa, esegue davvero la capacità dello strumento unico con motore.py (la stessa
ricerca del server vero, sui file di BANCO_KB) e scrive la riga del registro;
poi scrive lo stream-json, con l'uscita strutturata quando c'è --json-schema.

La domanda coperta ha una risposta con KB-90; sulla domanda non coperta, con il
permesso nel system prompt risponde che non lo sa, senza il permesso risponde
con una cifra che non è nei brani.

L'ambiente cambia ciò che succede:
  FINTO_LOG=file   una riga JSON per chiamata: argv, cwd, l'API key
                   nell'ambiente o no, il system prompt del file
  FINTO_MODO       ok | rotto (esce 1) | troncato (nessun result) |
                   senza_strutturato (result senza structured_output) |
                   server_ko (il server MCP non parte: nell'evento init status
                   failed e nessuno strumento, nessuna chiamata)

Uscita: 0 lo stream · 1 un argomento rifiutato, il modo rotto
"""
import hashlib
import json
import os
import sys
import uuid
from pathlib import Path
from typing import Any, Dict, List, Tuple

OPZIONI = {"-p": 0, "--system-prompt-file": 1, "--tools": 1, "--mcp-config": 1,
           "--strict-mcp-config": 0, "--allowedTools": 1,
           "--permission-mode": 1, "--permission-prompts": 1,
           "--setting-sources": 1, "--model": 1, "--effort": 1,
           "--output-format": 1, "--verbose": 0,
           "--no-session-persistence": 0, "--json-schema": 1}
NOTA = " (risposta del claude finto)"
PERMESSO = "scrivi al cliente che non lo sai"


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


def registra(argv: List[str], prompt: str, sistema: str) -> None:
    """Una riga in FINTO_LOG, se c'è."""
    registro = os.environ.get("FINTO_LOG")
    if not registro:
        return
    dato = {"argv": argv, "cwd": os.getcwd(), "prompt": prompt,
            "chiave": "ANTHROPIC_API_KEY" in os.environ,
            "effort": "CLAUDE_CODE_EFFORT_LEVEL" in os.environ,
            "sistema": hashlib.sha256(sistema.encode("utf-8")).hexdigest(),
            "permesso": PERMESSO in sistema}
    with open(registro, "a", encoding="utf-8") as fh:
        fh.write(json.dumps(dato, ensure_ascii=False) + "\n")


def esegui_strumento(opzioni: Dict[str, str], prompt: str) -> Tuple[str, Any]:
    """Esegue la capacità dello strumento unico con il motore vero e scrive
    la riga del registro. Returns: (nome dello strumento, risultato)."""
    with open(opzioni["--mcp-config"], encoding="utf-8") as fh:
        server = json.load(fh)["mcpServers"]["assistenza"]
    ambiente = server["env"]
    cartella_server = server["args"][server["args"].index("--directory") + 1]
    sys.path.insert(0, str(Path(cartella_server).parent))
    import motore  # pylint: disable=import-outside-toplevel
    definizioni = motore.carica_strumenti(Path(ambiente["BANCO_STRUMENTI"]))
    definizione = definizioni[0]
    with open(ambiente["BANCO_SCENARIO"], encoding="utf-8") as fh:
        scenario = json.load(fh)
    banco = motore.Banco(scenario, Path(ambiente["BANCO_KB"]))
    argomenti_strumento = {"query": prompt}
    risultato, errore, effettiva = banco.esegui(definizione.capacita,
                                                argomenti_strumento)
    riga = {"n": 1, "strumento": definizione.nome, "capacita": effettiva,
            "argomenti": argomenti_strumento, "risultato": risultato,
            "errore": errore}
    with open(ambiente["BANCO_REGISTRO"], "a", encoding="utf-8") as fh:
        fh.write(json.dumps(riga, ensure_ascii=False) + "\n")
    return definizione.nome, risultato


def uscita_strutturata(prompt: str, sistema: str) -> Dict[str, Any]:
    """La risposta finta, per domanda e per braccio."""
    if "guastato" in prompt:
        return {"coperta": True, "codice_procedura": "KB-90",
                "risposta": "Il nuovo router parte entro 2 giorni lavorativi "
                            "dall'apertura della segnalazione." + NOTA}
    if PERMESSO in sistema:
        return {"coperta": False, "codice_procedura": None,
                "risposta": "Non lo so: le procedure che ho non lo dicono."
                            + NOTA}
    return {"coperta": True, "codice_procedura": "KB-92",
            "risposta": "Paghi 75 euro, addebitati in fattura." + NOTA}


def stream(nome: str, risultato: Any, prompt: str, opzioni: Dict[str, str],
           sistema: str, modo: str) -> None:
    """Lo stream finto, una riga per evento."""
    sessione = str(uuid.uuid4())
    strutturato = uscita_strutturata(prompt, sistema)
    uso = {"input_tokens": 3, "cache_creation_input_tokens": 2000,
           "cache_read_input_tokens": 0, "output_tokens": 40}
    server_ko = modo == "server_ko"
    righe: List[Dict[str, Any]] = [
        {"type": "system", "subtype": "init", "cwd": os.getcwd(),
         "session_id": sessione, "model": "claude-finto",
         "claude_code_version": "9.9.9 (finto)",
         "tools": [] if server_ko else ["mcp__assistenza__" + nome],
         "mcp_servers": [{"name": "assistenza",
                          "status": "failed" if server_ko else "connected"}]}]
    if not server_ko:
        righe += [
            {"type": "assistant", "parent_tool_use_id": None, "message": {
                "id": "msg_1", "usage": uso, "content": [{
                    "type": "tool_use", "id": "toolu_finto_1",
                    "name": "mcp__assistenza__" + nome,
                    "input": {"query": prompt}}]}},
            {"type": "user", "message": {"role": "user", "content": [{
                "type": "tool_result", "tool_use_id": "toolu_finto_1",
                "content": json.dumps(risultato, ensure_ascii=False)}]}}]
    righe.append(
        {"type": "assistant", "parent_tool_use_id": None, "message": {
            "id": "msg_2", "usage": uso, "content": [
                {"type": "text", "text": strutturato["risposta"]}]}})
    finale: Dict[str, Any] = {
        "type": "result", "subtype": "success", "is_error": False,
        "num_turns": 2, "duration_ms": 1500, "session_id": sessione,
        "result": strutturato["risposta"], "usage": uso,
        "modelUsage": {"claude-finto": {
            "inputTokens": 6, "outputTokens": 80,
            "cacheReadInputTokens": 0, "cacheCreationInputTokens": 4000}}}
    if "--json-schema" in opzioni and modo != "senza_strutturato":
        finale["structured_output"] = strutturato
    if modo != "troncato":
        righe.append(finale)
    for riga in righe:
        print(json.dumps(riga, ensure_ascii=False))


def leggi_sistema(opzioni: Dict[str, str]) -> str:
    """Il testo del file del system prompt."""
    with open(opzioni["--system-prompt-file"], encoding="utf-8") as fh:
        return fh.read()


def main(argv: List[str]) -> int:
    if argv == ["--version"]:
        print("9.9.9 (Claude Code finto)")
        return 0
    try:
        opzioni, prompt = argomenti(argv)
    except Rifiutato as exc:
        print(str(exc), file=sys.stderr)
        return 1
    sistema = leggi_sistema(opzioni)
    registra(argv, prompt, sistema)
    modo = os.environ.get("FINTO_MODO", "ok")
    if modo == "rotto":
        print("error: claude finto rotto", file=sys.stderr)
        return 1
    nome, risultato = ("", None) if modo == "server_ko" \
        else esegui_strumento(opzioni, prompt)
    stream(nome, risultato, prompt, opzioni, sistema, modo)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
