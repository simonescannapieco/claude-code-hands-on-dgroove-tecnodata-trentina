#!/usr/bin/env python3
"""claude_finto.py -- un claude finto per le prove del Modulo 2.

Lo copia test_m2_script.sh, con il nome «claude», davanti nel PATH: così i
live.sh e misura.sh girano per intero senza consumare il piano.

Gli argomenti: prima le opzioni che usano gli script del modulo (OPZIONI,
con i loro valori), poi il prompt, dopo «--» oppure come unico argomento
che non comincia con «-». Una parola che comincia con «-», prima di «--»,
e non è un'opzione che conosce la rifiuta («error: unknown option»,
uscita 1): così le prove vedono un prompt che comincia con «-» passato
senza «--» davanti.

Risponde come claude -p --output-format json, con risposte scritte qui,
scelte dal prompt e dalle opzioni:
  --version              una versione finta;
  --agent giudice        un giudizio strutturato: ogni affermazione della
                         rubrica è rispettata se la risposta non contiene il
                         telefono del cliente;
  --json-schema          uno schema non valido (un «type» che JSON Schema
                         non ha) esce 1 con l'errore della CLI su STDERR,
                         come Claude Code all'avvio; altrimenti l'oggetto
                         dello schema di M2-D03 in structured_output, o
                         quello di M2-D04 se lo schema ha «categoria»;
  altrimenti             una risposta che dipende dal prompt (le demo e le
                         esercitazioni del modulo).
I token in entrata sono finti: una base (500 con --system-prompt,
altrimenti 3000) più un quarto dei caratteri del prompt e dei system prompt
passati con --system-prompt e --append-system-prompt.  I token in uscita
sono 50, di cui 0 di ragionamento; per il problema degli sportelli
(M2-D05) il ragionamento dipende da modello ed effort (RAGIONAMENTO, anche
con MAX_THINKING_TOKENS=0, come sui modelli 5.5) e l'uscita è il
ragionamento più 5; con FINTO_THINKING_OLTRE=1 il ragionamento supera
l'uscita di 1.  modelUsage nomina il modello dell'alias di --model.

Ogni chiamata (non --version) aggiunge una riga a FINTO_LOG. Con
FINTO_ESITO=ko esce 1 senza stampare nulla. Con FINTO_RISPOSTA=<testo>
risponde a ogni chiamata con quel testo e senza structured_output: un esito
diverso da quello registrato. Se ANTHROPIC_API_KEY è nel suo ambiente lo
scrive nel registro («CHIAVE»), così le prove vedono se è stata tolta.

Uscita: 0 risposta · 1 FINTO_ESITO=ko, o un argomento che rifiuta
"""
import json
import os
import re
import sys
from typing import Dict, List, Tuple

TEL = "+39 000 000 0103"
MODELLI = {"haiku": "claude-haiku-5-5", "sonnet": "claude-sonnet-5-5",
           "opus": "claude-opus-5-5"}
# I token di ragionamento finti del problema degli sportelli (M2-D05).
RAGIONAMENTO = {("haiku", "low"): 105, ("haiku", "high"): 300,
                ("sonnet", "low"): 0, ("sonnet", "high"): 120,
                ("opus", "low"): 24, ("opus", "high"): 200}
# Le opzioni che il finto conosce, con quanti valori prendono.
OPZIONI = {"-p": 0, "--print": 0, "--strict-mcp-config": 0,
           "--no-session-persistence": 0, "--verbose": 0, "--model": 1,
           "--effort": 1, "--tools": 1, "--allowedTools": 1,
           "--system-prompt": 1, "--append-system-prompt": 1,
           "--json-schema": 1, "--agent": 1, "--output-format": 1,
           "--permission-mode": 1, "--permission-prompts": 1,
           "--setting-sources": 1, "--resume": 1}


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
    return opzioni, operandi[0]


TIPI = {"null", "boolean", "object", "array", "number", "string", "integer"}


def schema_valido(testo: str) -> bool:
    """Uno schema che la CLI accetterebbe, per quanto serve alle prove."""
    try:
        schema = json.loads(testo)
    except ValueError:
        return False
    if not isinstance(schema, dict):
        return False
    tipo = schema.get("type", "object")
    return isinstance(tipo, list) or (isinstance(tipo, str) and tipo in TIPI)


def risposta(prompt: str) -> str:
    """La risposta finta a un prompt delle demo o delle esercitazioni."""
    if "Classificazione:" in prompt and "<examples>" in prompt:
        return "lentezza | media | noc"
    if "Classificazione:" in prompt:
        return "Prestazioni | Media | Rete"
    if "sportelli" in prompt:
        return "Si parte alle 9:00 e l'ultima persona esce alle 9:36."
    if "linee ferme" in prompt:
        return "15:30"
    if "Come ti ho detto ieri" in prompt:
        return "Non ho accesso alla conversazione di ieri: me la incolla?"
    # M2-D06: le cure e gli orrori della galleria, nell'ordine in cui una
    # chiave può stare dentro un'altra (il divieto e la sua cura
    # contengono anche il riepilogo; la cura della stima anche la stima).
    if "con il formato concordato: al massimo tre righe" in prompt:
        return ("Gentile signor Fittizio, la richiameremo la mattina.\n"
                "L'assistenza clienti di CiaspoLink")
    if "tecnico di turno" in prompt:
        return ("Problema: centralino fermo, telefoni «non registrato».\n"
                "Quando: venerdì mattina, dalle 8 alle 10 e mezza.\n"
                "Richieste: indennizzo e linea di riserva.")
    if "prosa scorrevole" in prompt or "Non usare markdown" in prompt:
        return ("Venerdì mattina il centralino del cliente era fermo.\n\n"
                "Chiede un indennizzo e una linea di riserva.")
    if "riepilogo di questo messaggio" in prompt:
        return "## Che cosa è successo\n- Centralino fermo\n- **Ordini persi**"
    if "non indicato nel messaggio" in prompt:
        return "1. Verifica dei log: costo non indicato nel messaggio."
    if "stima dei costi" in prompt:
        return "1. Linea di riserva: 150 €"
    if "Formato:" in prompt and "<messaggio>" in prompt:
        return ("| Problema | Quando |\n|---|---|\n| centralino | venerdì |\n\n"
                "L'assistenza clienti di CiaspoLink")
    if "<messaggio>" in prompt or "<codice>" in prompt or "<log>" in prompt:
        return ("Gentile signor Fittizio, la porta 0/1/3 e le 40 ONT.\n"
                "```php\n$gg_mese = (int) date('t');\n```\n"
                "L'assistenza clienti di CiaspoLink")
    return "Riassunto: Franco Fittizio, telefono %s. [Nome]" % TEL


def giudizio(prompt: str) -> dict:
    """Il giudizio strutturato: rispettato se il telefono non c'è."""
    rubrica = re.search(r"<rubrica>(.*?)</rubrica>", prompt, re.S)
    testo = re.search(r"<risposta>(.*?)</risposta>", prompt, re.S)
    ids = re.findall(r"^- ([a-z][a-z0-9_]*):", rubrica.group(1) if rubrica
                     else "", re.M)
    buona = TEL not in (testo.group(1) if testo else "")
    return {"criteri": [{"id": i, "motivo": "giudizio finto",
                         "rispettato": buona} for i in ids]}


def main(argv: List[str]) -> int:
    if argv[:1] == ["--version"]:
        print("0.0.0 (Claude Code, finto)")
        return 0
    log = os.environ.get("FINTO_LOG")
    if log:
        with open(log, "a", encoding="utf-8") as fh:
            fh.write("chiamata %s\n" % (
                "CHIAVE" if os.environ.get("ANTHROPIC_API_KEY") else "-"))
    try:
        opzioni, prompt = argomenti(argv)
    except Rifiutato as exc:
        sys.stderr.write("%s\n" % exc)
        return 1
    if os.environ.get("FINTO_ESITO", "ok") != "ok":
        return 1
    schema = opzioni.get("--json-schema")
    if schema is not None and not schema_valido(schema):
        sys.stderr.write("Error: --json-schema is not a valid JSON Schema: "
                         "data/type must be equal to one of the allowed "
                         "values\n")
        return 1
    sistema = opzioni.get("--system-prompt")
    caratteri = (len(prompt) + len(sistema or "")
                 + len(opzioni.get("--append-system-prompt", "")))
    thinking, uscita = 0, 50
    if "sportelli" in prompt:
        thinking = RAGIONAMENTO.get((opzioni.get("--model"),
                                     opzioni.get("--effort")), 0)
        uscita = thinking + 5
    if os.environ.get("FINTO_THINKING_OLTRE") == "1":
        thinking = uscita + 1
    doc = {"type": "result", "subtype": "success", "is_error": False,
           "session_id": "sessione-finta",
           "usage": {"input_tokens": 3, "cache_creation_input_tokens":
                     (3000 if sistema is None else 500) + caratteri // 4,
                     "cache_read_input_tokens": 0, "output_tokens": uscita,
                     "output_tokens_details": {"thinking_tokens": thinking}},
           "modelUsage": {MODELLI.get(opzioni.get("--model", ""),
                                      "claude-finto"): {}}}
    fissa = os.environ.get("FINTO_RISPOSTA")
    if fissa:
        doc["result"] = fissa
    elif "--agent" in opzioni:
        doc["structured_output"] = giudizio(prompt)
        doc["result"] = json.dumps(doc["structured_output"])
    elif ("--json-schema" in opzioni
          and '"categoria"' in opzioni["--json-schema"]):
        doc["structured_output"] = {"categoria": "lentezza",
                                    "priorita": "media", "team": "noc"}
        doc["result"] = json.dumps(doc["structured_output"])
    elif "--json-schema" in opzioni:
        doc["structured_output"] = {
            "tipo_cliente": "azienda", "servizio": "centralino",
            "problema": "centralino fermo", "urgenza": "alta",
            "azione_richiesta": "richiamare al " + TEL}
        doc["result"] = json.dumps(doc["structured_output"])
    elif "SOLO un JSON" in prompt:
        doc["result"] = json.dumps({"tipo_cliente": "azienda"})
    else:
        doc["result"] = risposta(prompt)
    print(json.dumps(doc, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
