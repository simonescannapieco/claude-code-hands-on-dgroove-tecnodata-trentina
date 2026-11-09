#!/usr/bin/env python3
"""claude_finto_m7_e01.py -- un claude finto per le prove di M7-E01
(test_m7_e01.sh).

La suite lo mette, attraverso un piccolo script con il nome «claude», davanti
nel PATH: così _docente/live.sh e tools/prova_assistente.sh girano per intero
senza chiamare il modello. Niente di ciò che scrive è una risposta di Claude:
ogni testo finisce con «(risposta del claude finto)». Provano gli script e il
controllo, non il modello. prova.py ripulisce l'ambiente delle sue chiamate:
le variabili FINTO_* arrivano dallo script «claude» della suite, che le legge
da un file.

Le chiamate che riconosce:
  --version
  l'assistente del banco (ha --mcp-config): scrive nel registro del server
      (BANCO_REGISTRO, nella configurazione MCP) una riga per giro e stampa lo
      stream-json della chiamata, con il testo dell'assistente;
  la persona (--agent cliente): un JSON con il prossimo messaggio del cliente,
      o FINE dopo FINTO_GIRI giri (default 2);
  la lettura e le note (claude -p con un prompt su trascrizione o note, da
      handson::claude_p): un JSON con result e session_id; se il prompt chiede
      di scrivere note.md la scrive nella cartella corrente.

L'ambiente cambia ciò che succede:
  FINTO_GIRI=n          dopo quanti giri la persona dice FINE (default 2)
  FINTO_NOTE=n          quante voci scrive in note.md (default 3)
  FINTO_NOTE_SENZA=1    le voci senza turno né strumento
  FINTO_TRONCO=1        lo stream dell'assistente senza il risultato
  FINTO_ERRORE=1        il risultato dell'assistente con is_error
  FINTO_SERVER_KO=1     il server MCP non parte: nell'evento init status failed
                        e nessuno strumento, nessuna chiamata
  FINTO_KO_SE=testo     esce 1, senza stampare nulla, se il testo è nel prompt
  FINTO_LOG=file        una riga JSON per invocazione: argv, cwd, prompt,
                        chiave (ANTHROPIC_API_KEY era nell'ambiente), effort
                        (CLAUDE_CODE_EFFORT_LEVEL c'era)

Uscita: 0 la risposta · 1 FINTO_KO_SE, un argomento rifiutato
"""
import json
import os
import sys
import uuid
from typing import Any, Dict, List, Optional

NOTA = " (risposta del claude finto)"
SESSIONE_FISSA = "sessione-finta-e01"


def acceso(nome: str) -> bool:
    return os.environ.get(nome) == "1"


def valore(argv: List[str], opzione: str) -> Optional[str]:
    if opzione in argv and argv.index(opzione) + 1 < len(argv):
        return argv[argv.index(opzione) + 1]
    return None


def prompt_di(argv: List[str]) -> str:
    """Il prompt, dopo «--», oppure dopo -p se manca il separatore."""
    if "--" in argv and argv.index("--") + 1 < len(argv):
        return argv[argv.index("--") + 1]
    return ""


def registra(argv: List[str], prompt: str) -> None:
    percorso = os.environ.get("FINTO_LOG")
    if not percorso:
        return
    voce = {"argv": argv, "cwd": os.getcwd(), "prompt": prompt,
            "chiave": bool(os.environ.get("ANTHROPIC_API_KEY")),
            "effort": bool(os.environ.get("CLAUDE_CODE_EFFORT_LEVEL"))}
    with open(percorso, "a", encoding="utf-8") as fh:
        fh.write(json.dumps(voce, ensure_ascii=False) + "\n")


def assistente(argv: List[str]) -> int:
    """Una chiamata dell'assistente del banco: una riga nel registro e lo
    stream-json."""
    configurazione = json.load(open(valore(argv, "--mcp-config") or "",
                                    encoding="utf-8"))
    env = configurazione["mcpServers"]["assistenza"]["env"]
    registro = env["BANCO_REGISTRO"]
    giro = 1
    if os.path.isfile(registro):
        with open(registro, encoding="utf-8") as fh:
            giro = 1 + sum(1 for _ in fh)
    server_ko = acceso("FINTO_SERVER_KO")
    if giro % 2:
        chiamata = {"n": giro, "strumento": "cercaCliente",
                    "capacita": "cerca_cliente",
                    "argomenti": {"q": "Falegnameria Fittizia"},
                    "risultato": {"cliente": {"id_cliente": "CL-000103"},
                                  "credenziali": {"password": "demo-0103"}},
                    "errore": False}
    else:
        chiamata = {"n": giro, "strumento": "operatore",
                    "capacita": "passa_a_operatore",
                    "argomenti": {"motivo": "richiesta del cliente"},
                    "risultato": {"esito": "presa in carico"}, "errore": False}
    if not server_ko:
        with open(registro, "a", encoding="utf-8") as fh:
            fh.write(json.dumps(chiamata, ensure_ascii=False) + "\n")
    sessione = valore(argv, "--resume") or "sess-finta-" + uuid.uuid4().hex[:6]
    testo = "Risposta del giro %d dell'assistente." % giro + NOTA
    print(json.dumps({"type": "system", "subtype": "init",
                      "session_id": sessione,
                      "tools": [] if server_ko else
                      ["mcp__assistenza__cercaCliente",
                       "mcp__assistenza__operatore"],
                      "mcp_servers": [{
                          "name": "assistenza",
                          "status": "failed" if server_ko else "connected"}]}))
    contenuto: List[Dict[str, Any]] = [] if server_ko else [
        {"type": "tool_use", "id": "t1",
         "name": "mcp__assistenza__" + chiamata["strumento"],
         "input": chiamata["argomenti"]}]
    contenuto.append({"type": "text", "text": testo})
    print(json.dumps({"type": "assistant", "parent_tool_use_id": None,
                      "message": {
                          "usage": {"input_tokens": 100,
                                    "cache_creation_input_tokens": 900,
                                    "cache_read_input_tokens": 0,
                                    "output_tokens": 10},
                          "content": contenuto}}))
    if acceso("FINTO_TRONCO"):
        return 0
    print(json.dumps({"type": "result", "subtype": "success",
                      "is_error": acceso("FINTO_ERRORE"), "num_turns": 2,
                      "duration_ms": 1200, "result": testo,
                      "session_id": sessione,
                      "usage": {"input_tokens": 100, "output_tokens": 10}}))
    return 0


def persona(prompt: str) -> int:
    """Il prossimo messaggio del cliente, o FINE."""
    giri = int(os.environ.get("FINTO_GIRI") or 2)
    fatti = prompt.count("assistente: ")
    testo = "FINE" if fatti >= giri else "Il tecnico è qui, faccia presto."
    print(json.dumps({"type": "result", "subtype": "success",
                      "is_error": False, "result": testo, "num_turns": 1,
                      "duration_ms": 200, "session_id": "s-persona"}))
    return 0


def scrivi_note() -> None:
    """Scrive note.md nella cartella corrente."""
    quante = int(os.environ.get("FINTO_NOTE") or 3)
    senza = acceso("FINTO_NOTE_SENZA")
    righe = ["# Note", ""]
    for i in range(1, quante + 1):
        if senza:
            righe.append("- punto %d, senza riferimento alcuno" % i)
        elif i == 3:
            righe.append("- voce %d: lo strumento `cercaCliente` restituisce "
                         "le credenziali" % i)
        else:
            righe.append("- voce %d: al turno %d qualcosa non va" % (i, 2 * i))
    with open("note.md", "w", encoding="utf-8") as fh:
        fh.write("\n".join(righe) + "\n")


def lettura(prompt: str) -> int:
    """La lettura della trascrizione o la scrittura delle note, in JSON."""
    if "note.md" in prompt:
        scrivi_note()
    print(json.dumps({"type": "result", "subtype": "success",
                      "is_error": False, "result": "Letto." + NOTA,
                      "num_turns": 2, "duration_ms": 900,
                      "session_id": SESSIONE_FISSA,
                      "modelUsage": {"finto": {"inputTokens": 100,
                                               "outputTokens": 10}}}))
    return 0


def main() -> int:
    argv = sys.argv[1:]
    if argv == ["--version"]:
        print("2.1.319 (Claude Code, finto)")
        return 0
    prompt = prompt_di(argv)
    registra(argv, prompt)
    if os.environ.get("FINTO_KO_SE") and os.environ["FINTO_KO_SE"] in prompt:
        return 1
    if "--mcp-config" in argv:
        return assistente(argv)
    if valore(argv, "--agent") == "cliente":
        return persona(prompt)
    return lettura(prompt)


if __name__ == "__main__":
    sys.exit(main())
