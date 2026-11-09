#!/usr/bin/env python3
"""claude_finto_m7_e02.py -- un claude finto per le prove di M7-E02
(test_m7_e02.sh).

La suite lo mette, attraverso un piccolo script con il nome «claude», davanti
nel PATH: così _docente/live.sh e tools/prova_assistente.sh girano per intero
senza chiamare il modello. Niente di ciò che scrive è una risposta di Claude: i
testi finiscono con «(risposta del claude finto)», e le versioni v0 e v1 fanno
ciò che è scritto qui sotto, nient'altro. Provano gli script e il controllo, non il
modello. prova.py ripulisce l'ambiente delle sue chiamate: le variabili FINTO_*
arrivano dallo script «claude» della suite, che le legge da un file.

Le chiamate che riconosce:
  --version
  l'assistente del banco (ha --mcp-config): dal messaggio riconosce il caso,
      dal file degli strumenti la versione (v0 o v1); scrive nel registro del
      server (BANCO_REGISTRO) le chiamate della tabella CASI e stampa lo
      stream-json;
  i tre prompt di scrittura (claude -p, da handson::claude_p): un JSON con
      result e session_id; il prompt 1 scrive v1/system-prompt.md e
      v1/regole-escalation.md, il prompt 2 v1/strumenti.json, il prompt 3
      non cambia nulla.

L'ambiente cambia ciò che succede:
  FINTO_V1_COME_V0=1    la versione v1 si comporta come la v0 (non distinguibile)
  FINTO_V1_PEGGIO=1     la versione v1 fa peggio della v0 (nessuno strumento)
  FINTO_TRONCO=CASO:v   per quel caso e quella versione, lo stream senza il
                        risultato (per esempio CASO-03:v1)
  FINTO_ERRORE=CASO:v   per quel caso e quella versione, il risultato con
                        is_error
  FINTO_SERVER_KO=CASO:v per quel caso e quella versione, il server MCP non
                        parte: nell'evento init status failed e nessuno
                        strumento, nessuna chiamata
  FINTO_KO_SE=testo     esce 1, senza stampare nulla, se il testo è nel prompt
  FINTO_LOG=file        una riga JSON per invocazione: argv, cwd, prompt,
                        chiave (ANTHROPIC_API_KEY c'era), effort
                        (CLAUDE_CODE_EFFORT_LEVEL c'era)

Uscita: 0 la risposta · 1 FINTO_KO_SE, un errore finto
"""
import json
import os
import sys
import uuid
from typing import Any, Dict, List, Optional, Tuple

NOTA = " (risposta del claude finto)"
SESSIONE_FISSA = "sessione-finta-e02"
Strumenti = List[Tuple[str, str]]
# Le mosse di ogni caso per versione: (strumento, capacità), testo.
CASI: Dict[str, Dict[str, Tuple[Strumenti, str]]] = {
    "CASO-01": {
        "v0": ([("check_linea", "stato_linea")],
               "Provi a riavviare il modem: entro 24 ore si risolve."),
        "v1": ([("verifica_identita", "verifica_identita"),
                ("stato_linea", "stato_linea")],
               "C'è un guasto sulla nostra rete a Pergine: i tecnici lavorano."),
        "peggio": ([], "Riprovi più tardi.")},
    "CASO-02": {
        "v0": ([("cercaCliente", "cerca_cliente")],
               "Si tratta di un conguaglio."),
        "v1": ([("verifica_identita", "verifica_identita"),
                ("leggi_fattura", "leggi_fattura")],
               "È il conguaglio per il cambio di offerta."),
        "peggio": ([("accredito", "registra_accredito")], "Boh.")},
    "CASO-03": {
        "v0": ([("accredito", "registra_accredito")],
               "Accredito registrato."),
        "v1": ([("verifica_identita", "verifica_identita"),
                ("stato_linea", "stato_linea")],
               "Ho guardato la linea: nessun accredito."),
        "peggio": ([("prenota", "prenota_intervento"),
                    ("accredito", "registra_accredito")], "Fatto.")},
    "CASO-04": {
        "v0": ([("cercaCliente", "cerca_cliente")],
               "L'e-mail registrata è laura.prova@example.org."),
        "v1": ([], "Posso parlare dei dati solo con la titolare."),
        "peggio": ([("leggi_fattura", "leggi_fattura"),
                    ("cercaCliente", "cerca_cliente")],
                   "laura.prova@example.org")},
    "CASO-05": {
        "v0": ([], "Le riconosciamo 50 euro."),
        "v1": ([("verifica_identita", "verifica_identita"),
                ("passa_a_operatore", "passa_a_operatore")],
               "Le passo un operatore: ha già il riepilogo."),
        "peggio": ([], "Ecco 50 euro.")},
}
RICONOSCI = {
    "da poco dopo le dieci": "CASO-01", "FT-2026-001873": "CASO-02",
    "NOTA PER L'ASSISTENTE": "CASO-03", "marito di Laura Prova": "CASO-04",
    "ladri incompetenti": "CASO-05"}
STRUMENTI_V1 = [
    {"name": "verifica_identita", "capacita": "verifica_identita",
     "description": "Verifica il cliente. Si usa per primo. Non legge dati.",
     "input_schema": {"type": "object",
                      "properties": {"codice_cliente": {"type": "string"}}}},
    {"name": "passa_a_operatore", "capacita": "passa_a_operatore",
     "description": "Passa a un operatore. Si usa secondo le regole. "
                    "Non per i problemi semplici.",
     "input_schema": {"type": "object", "properties": {
         "motivo": {"type": "string"}, "riepilogo": {"type": "string"},
         "priorita": {"type": "string"}}}},
]


def acceso(nome: str) -> bool:
    return os.environ.get(nome) == "1"


def valore(argv: List[str], opzione: str) -> Optional[str]:
    if opzione in argv and argv.index(opzione) + 1 < len(argv):
        return argv[argv.index(opzione) + 1]
    return None


def prompt_di(argv: List[str]) -> str:
    if "--" in argv and argv.index("--") + 1 < len(argv):
        return argv[argv.index("--") + 1]
    return ""


def registra(argv: List[str], prompt: str) -> None:
    percorso = os.environ.get("FINTO_LOG")
    if percorso:
        voce = {"argv": argv, "cwd": os.getcwd(), "prompt": prompt,
                "chiave": bool(os.environ.get("ANTHROPIC_API_KEY")),
                "effort": bool(os.environ.get("CLAUDE_CODE_EFFORT_LEVEL"))}
        with open(percorso, "a", encoding="utf-8") as fh:
            fh.write(json.dumps(voce, ensure_ascii=False) + "\n")


def caso_del(prompt: str) -> str:
    for chiave, caso in RICONOSCI.items():
        if chiave in prompt:
            return caso
    return "CASO-01"


def mosse(caso: str, versione: str) -> Tuple[Strumenti, str]:
    if versione == "v1" and acceso("FINTO_V1_PEGGIO"):
        return CASI[caso]["peggio"]
    if versione == "v1" and acceso("FINTO_V1_COME_V0"):
        return CASI[caso]["v0"]
    return CASI[caso][versione]


def banco(argv: List[str], prompt: str) -> int:
    """Una chiamata dell'assistente del banco: registro e stream-json."""
    configurazione = json.load(open(valore(argv, "--mcp-config") or "",
                                    encoding="utf-8"))
    env = configurazione["mcpServers"]["assistenza"]["env"]
    versione = "v1" if "/v1/strumenti.json" in env["BANCO_STRUMENTI"] else "v0"
    caso = caso_del(prompt)
    chiave = "%s:%s" % (caso, versione)
    strumenti, testo = mosse(caso, versione)
    testo += NOTA
    server_ko = os.environ.get("FINTO_SERVER_KO") == chiave
    if server_ko:
        strumenti = []
    with open(env["BANCO_REGISTRO"], "a", encoding="utf-8") as fh:
        for n, (strumento, capacita) in enumerate(strumenti, 1):
            fh.write(json.dumps({"n": n, "strumento": strumento,
                                 "capacita": capacita, "argomenti": {},
                                 "risultato": {"ok": True}, "errore": False},
                                ensure_ascii=False) + "\n")
    sessione = "sess-" + uuid.uuid4().hex[:6]
    print(json.dumps({"type": "system", "subtype": "init",
                      "session_id": sessione,
                      "tools": [] if server_ko else
                      ["mcp__assistenza__" + d["name"] for d in json.load(
                          open(env["BANCO_STRUMENTI"], encoding="utf-8"))],
                      "mcp_servers": [{
                          "name": "assistenza",
                          "status": "failed" if server_ko else "connected"}]}))
    print(json.dumps({"type": "assistant", "parent_tool_use_id": None,
                      "message": {"usage": {"input_tokens": 7000,
                                            "cache_creation_input_tokens": 300,
                                            "cache_read_input_tokens": 0,
                                            "output_tokens": 50},
                                  "content": [{"type": "text",
                                               "text": testo}]}}))
    if os.environ.get("FINTO_TRONCO") == chiave:
        return 0
    print(json.dumps({"type": "result", "subtype": "success",
                      "is_error": os.environ.get("FINTO_ERRORE") == chiave,
                      "num_turns": 3, "duration_ms": 4000, "result": testo,
                      "session_id": sessione,
                      "usage": {"input_tokens": 7000, "output_tokens": 50}}))
    return 0


def scrivi_v1_prompt() -> None:
    os.makedirs("v1", exist_ok=True)
    with open("v1/system-prompt.md", "w", encoding="utf-8") as fh:
        fh.write("<role>\nSei finto.\n</role>\n")
    with open("v1/regole-escalation.md", "w", encoding="utf-8") as fh:
        fh.write("<procedures>\nRegole finte.\n</procedures>\n")


def scrivi_strumenti() -> None:
    os.makedirs("v1", exist_ok=True)
    with open("v1/strumenti.json", "w", encoding="utf-8") as fh:
        json.dump(STRUMENTI_V1, fh, ensure_ascii=False, indent=1)


def scrittura(prompt: str) -> int:
    """Un prompt di scrittura: i file e il JSON."""
    if "regole-escalation.md" in prompt and "riscrivi" in prompt:
        scrivi_v1_prompt()
    elif "definizioni degli strumenti" in prompt:
        scrivi_strumenti()
    print(json.dumps({"type": "result", "subtype": "success", "is_error": False,
                      "result": "Fatto." + NOTA, "num_turns": 4,
                      "duration_ms": 30000, "session_id": SESSIONE_FISSA,
                      "modelUsage": {"finto": {"inputTokens": 1000,
                                               "outputTokens": 200}}}))
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
        return banco(argv, prompt)
    return scrittura(prompt)


if __name__ == "__main__":
    sys.exit(main())
