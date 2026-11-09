#!/usr/bin/env python3
"""claude_finto_m7_d01_d04.py -- un claude finto per le prove di M7-D01, M7-D03
e M7-D04 (test_m7_d01.sh, test_m7_d03.sh, test_m7_d04.sh).

Le suite lo lanciano con il nome «claude», davanti nel PATH, attraverso un
piccolo involucro che imposta FINTO_MODI e FINTO_LOG: prova.py, il banco di
prova, ripulisce l'ambiente, e l'involucro li rilegge da un file. Gli stream che
scrive sono inventati e dichiarati finti: ogni risposta finisce con «(risposta
del claude finto)». Provano i controlli e gli script, non il modello. Hanno la
forma di quelli di `claude -p --output-format stream-json --verbose`.

Le opzioni: quelle di handson::claude_p e di prova.py (OPZIONI), poi il prompt
dopo «--». Rifiuta («error: …», uscita 1) un'opzione che non conosce, un
--output-format diverso da stream-json e lo stream-json senza --verbose.
--version stampa una versione finta.

Le scene, dal prompt e dalle opzioni:
  una chiamata senza --mcp-config (M7-D01):
      un prompt con una parola in codice (PAROLA-1234, da primo.txt): risponde
      «Ricevuto.», e senza --no-session-persistence salva la parola nella
      sessione (~/.claude/projects/<cartella>/<session_id>.jsonl);
      la domanda «Qual è la parola…»: senza --resume non la sa; con --resume
      la rilegge dalla sessione, che deve esistere;
      altrimenti il messaggio del cliente: con system-ciaspolink.md una risposta
      di due righe, con il system prompt generico una risposta lunga;
  una chiamata con --mcp-config (il banco, M7-D03 e M7-D04): esegue le
      capacità con il motore vero (motore.py del banco, dai percorsi della
      configurazione), scrive il registro come il server e lo stream di ciò
      che il modello ha chiesto.

Le parole di FINTO_MODI cambiano ciò che succede:
  generico-breve    M7-D01: il braccio generico risponde in due righe
  ciaspolink-lungo  M7-D01: il braccio con il ruolo risponde lungo
  dimenticata       M7-D01: con --resume la risposta non ha la parola
  sapeva=PAROLA     M7-D01: senza --resume la risposta contiene quella parola
  muto              M7-D03: nessuna chiamata allo strumento
  log-diverso       M7-D03: il registro ha argomenti diversi dallo stream
  senza-is-error    M7-D03: il tool_result dell'errore senza is_error
  dopo              M7-D03: la risposta prima del tool_result
  pari              M7-D04: la versione vaga fa bene quanto la chiara
  inversa           M7-D04: la versione chiara fa peggio della vaga
  server-ko         il server MCP non parte: nell'evento init status failed e
                    nessuno strumento, nessuna chiamata
  tronco            lo stream senza il risultato
  errore            il risultato con is_error
  riga-rotta        una riga che non è JSON
  ko                esce 1 senza stampare nulla
  ko-se=testo       esce 1 se il testo è nel prompt

FINTO_LOG=file: una riga JSON per invocazione: argv, cwd, prompt, chiave
(ANTHROPIC_API_KEY era nell'ambiente), effort (CLAUDE_CODE_EFFORT_LEVEL c'era),
stdin_nullo, sistema (il testo del file di --system-prompt-file) e, se c'è
--mcp-config, strumenti (il file delle definizioni) e registro (il file del
registro).

Uscita: 0 lo stream · 1 un argomento rifiutato, ko
"""
import json
import os
import re
import stat
import sys
import uuid
from pathlib import Path
from typing import Any, Dict, List, NamedTuple, Optional, Tuple

OPZIONI = {"-p": 0, "--model": 1, "--permission-mode": 1,
           "--permission-prompts": 1, "--output-format": 1, "--verbose": 0,
           "--setting-sources": 1, "--tools": 1, "--system-prompt-file": 1,
           "--effort": 1, "--strict-mcp-config": 0,
           "--no-session-persistence": 0, "--resume": 1, "--mcp-config": 1,
           "--allowedTools": 1, "--json-schema": 1}
NOTA = " (risposta del claude finto)"
PAROLA_IN_CODICE = re.compile(r"\b[A-Z]{3,}-\d{4}\b")
LINEA = re.compile(r"LN-\d{6}")
CODICE = re.compile(r"CL-\d{6}")
EMAIL = re.compile(r"[\w.+-]+@[\w.-]+\.\w+")
BASE = 600
SOGLIA_CHIARA = 150


class Rifiutato(Exception):
    """Argomenti che il finto non accetta: il messaggio d'errore."""


class Mossa(NamedTuple):
    """Uno strumento chiamato: come appare nello stream e nel registro."""
    nome: str
    capacita: str
    argomenti: Dict[str, Any]
    risultato: Dict[str, Any]
    errore: bool


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
    if opzioni.get("--output-format") != "stream-json":
        raise Rifiutato("error: il finto scrive soltanto stream-json")
    if "--verbose" not in opzioni:
        raise Rifiutato("error: stream-json requires --verbose")
    return opzioni, argv[i + 1]


def testo_di(percorso: Optional[str]) -> str:
    """Il testo di un file, vuoto se non c'è."""
    if not percorso:
        return ""
    try:
        with open(percorso, encoding="utf-8") as fh:
            return fh.read()
    except OSError:
        return ""


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
        "sistema": testo_di(opzioni.get("--system-prompt-file"))}
    if "--mcp-config" in opzioni:
        env = config_banco(opzioni["--mcp-config"])["env"]
        dato["strumenti"] = env["BANCO_STRUMENTI"]
        dato["registro"] = env["BANCO_REGISTRO"]
    with open(registro, "a", encoding="utf-8") as fh:
        fh.write(json.dumps(dato, ensure_ascii=False) + "\n")


def config_banco(percorso: str) -> Dict[str, Any]:
    """Il server «assistenza» della configurazione MCP."""
    with open(percorso, encoding="utf-8") as fh:
        return json.load(fh)["mcpServers"]["assistenza"]


# --- M7-D01 --------------------------------------------------------------


def cartella_sessioni() -> Path:
    """La cartella delle sessioni per la cartella corrente, come la usa
    Claude Code."""
    nome = re.sub(r"[^A-Za-z0-9]", "-", os.getcwd())
    return Path.home() / ".claude" / "projects" / nome


def salva_sessione(sessione: str, parola: str) -> None:
    """Salva la parola nella sessione."""
    cartella = cartella_sessioni()
    cartella.mkdir(parents=True, exist_ok=True)
    (cartella / (sessione + ".jsonl")).write_text(
        json.dumps({"parola": parola}) + "\n", encoding="utf-8")


def leggi_sessione(sessione: str) -> Optional[str]:
    """La parola salvata nella sessione, o None se la sessione non c'è."""
    percorso = cartella_sessioni() / (sessione + ".jsonl")
    if not percorso.is_file():
        return None
    return str(json.loads(percorso.read_text(encoding="utf-8"))["parola"])


def risposta_lunga() -> str:
    """La risposta del system prompt generico: molte righe."""
    passi = "\n".join("%d. Controllo finto numero %d." % (i, i)
                      for i in range(1, 11))
    return "Buongiorno, ecco che cosa provare.\n\n" + passi \
        + "\n\nSe non basta, chiami l'assistenza." + NOTA


def risposta_breve() -> str:
    """La risposta con il ruolo: due righe."""
    return "Buongiorno, la luce rossa fissa indica che manca il segnale " \
        "ottico: controlli il cavo in fibra.\nSe non basta, apriamo una " \
        "segnalazione per la sua linea." + NOTA


def scena_d01(opzioni: Dict[str, str], prompt: str,
              sessione: str) -> Tuple[str, int]:
    """La scena senza banco: la risposta e i token della prima richiesta."""
    sistema = testo_di(opzioni.get("--system-prompt-file"))
    con_ruolo = "CiaspoLink" in sistema
    prima = BASE + len(sistema) // 3 + len(prompt) // 3
    parola = PAROLA_IN_CODICE.search(prompt)
    if parola:
        if "--no-session-persistence" not in opzioni:
            salva_sessione(sessione, parola.group(0))
        return "Ricevuto." + NOTA, prima
    if prompt.startswith("Qual è la parola"):
        return risposta_memoria(opzioni, sessione), prima + \
            (40 if "--resume" in opzioni else 0)
    if con_ruolo and "ciaspolink-lungo" not in modi():
        return risposta_breve(), prima
    if not con_ruolo and "generico-breve" in modi():
        return risposta_breve(), prima
    return risposta_lunga(), prima


def risposta_memoria(opzioni: Dict[str, str], sessione: str) -> str:
    """La domanda sulla parola: senza --resume non la sa."""
    if "--resume" not in opzioni:
        saputa = valore_modo("sapeva")
        if saputa:
            return "La parola in codice è %s." % saputa + NOTA
        return "Non ho nessuna parola in codice." + NOTA
    parola = leggi_sessione(opzioni["--resume"])
    if parola is None:
        raise Rifiutato("error: No conversation found with session ID: "
                        + opzioni["--resume"])
    if "dimenticata" in modi():
        return "Non ricordo nessuna parola." + NOTA
    return "La parola in codice di questa prova è %s." % parola + NOTA


# --- Il banco: M7-D03 e M7-D04 ---------------------------------------------


def carica_banco(opzioni: Dict[str, str]) -> Tuple[Any, List[Any], Dict[str, Any], Path]:
    """Il motore, le definizioni, i dati dello scenario e il registro."""
    server = config_banco(opzioni["--mcp-config"])
    cartella = Path(server["args"][server["args"].index("--directory") + 1])
    sys.path.insert(0, str(cartella.parent))
    import motore  # pylint: disable=import-outside-toplevel
    env = server["env"]
    scenario = json.loads(Path(env["BANCO_SCENARIO"]).read_text(
        encoding="utf-8"))
    banco = motore.Banco(scenario, Path(env["BANCO_KB"]))
    definizioni = motore.carica_strumenti(Path(env["BANCO_STRUMENTI"]))
    return banco, definizioni, scenario, Path(env["BANCO_REGISTRO"])


def mossa_di(banco: Any, definizione: Any,
             argomenti_mossa: Dict[str, Any]) -> Mossa:
    """Esegue una capacità con il motore."""
    risultato, errore, capacita = banco.esegui(definizione.capacita,
                                               argomenti_mossa)
    return Mossa(definizione.nome, capacita, argomenti_mossa, risultato,
                 errore)


def piano_d03(banco: Any, definizioni: List[Any], prompt: str) -> List[Mossa]:
    """Lo strumento unico, con il codice di linea del messaggio."""
    if "muto" in modi():
        return []
    linea = LINEA.search(prompt)
    return [mossa_di(banco, definizioni[0],
                     {"id_linea": linea.group(0) if linea else "?"})]


def risposta_d03(prompt: str, mosse: List[Mossa]) -> str:
    """La risposta finta di M7-D03."""
    if not mosse:
        return "Non ho chiesto niente al sistema." + NOTA
    linea = LINEA.search(prompt)
    if mosse[0].errore:
        return "Non trovo la linea %s: può ricontrollare il codice?" \
            % (linea.group(0) if linea else "") + NOTA
    return "La linea %s risulta %s." % (linea.group(0) if linea else "",
                                        mosse[0].risultato.get("stato")) + NOTA


def piano_d04(banco: Any, definizioni: List[Any], prompt: str,
              scenario: Dict[str, Any]) -> List[Mossa]:
    """Le chiamate di M7-D04: chi verifica prima, chi legge la scheda."""
    per_capacita = {d.capacita: d for d in definizioni}
    chiara = len(per_capacita["verifica_identita"].descrizione) \
        > SOGLIA_CHIARA
    codice = CODICE.search(prompt).group(0)  # type: ignore[union-attr]
    email = EMAIL.search(prompt).group(0)  # type: ignore[union-attr]
    linea = scenario["verita_nascosta"]["linee"][0]["id_linea"]
    buona_gioca = (not chiara and ("pari" in modi() or "inversa" in modi())) \
        or (chiara and "inversa" not in modi())
    identita = per_capacita["verifica_identita"]
    scheda = per_capacita["cerca_cliente"]
    stato = per_capacita["stato_linea"]
    arg_linea = {"id_linea": linea} if chiara else {"id": linea}
    if buona_gioca:
        arg_id = {"codice_cliente": codice, "recapito": email} if chiara \
            else {"dati": codice, "recapito": email}
        return [mossa_di(banco, identita, arg_id),
                mossa_di(banco, stato, arg_linea)]
    arg_scheda = {"codice_cliente": codice} if chiara else {"q": codice}
    return [mossa_di(banco, scheda, arg_scheda),
            mossa_di(banco, stato, arg_linea)]


def scena_banco(opzioni: Dict[str, str], prompt: str, sessione: str
                ) -> Tuple[List[Mossa], str, int, List[str]]:
    """La scena con il banco: le mosse, la risposta, i token della prima
    richiesta, i nomi degli strumenti definiti."""
    banco, definizioni, scenario, registro = carica_banco(opzioni)
    sistema = testo_di(opzioni.get("--system-prompt-file"))
    prima = BASE + len(sistema) // 3 + sum(len(d.descrizione) // 4
                                           for d in definizioni)
    if len(definizioni) == 1:
        mosse = piano_d03(banco, definizioni, prompt)
        risposta = risposta_d03(prompt, mosse)
    else:
        mosse = piano_d04(banco, definizioni, prompt, scenario)
        risposta = "Buongiorno, la sua linea risulta in guasto: la " \
            "aggiorniamo appena abbiamo novità." + NOTA
    if "server-ko" in modi():
        mosse = []
    for numero, mossa in enumerate(mosse, 1):
        argomenti_registro = mossa.argomenti
        if "log-diverso" in modi():
            argomenti_registro = {"id_linea": "LN-123456"}
        with registro.open("a", encoding="utf-8") as fh:
            fh.write(json.dumps({"n": numero, "strumento": mossa.nome,
                                 "capacita": mossa.capacita,
                                 "argomenti": argomenti_registro,
                                 "risultato": mossa.risultato,
                                 "errore": mossa.errore},
                                ensure_ascii=False) + "\n")
    return mosse, risposta, prima, [d.nome for d in definizioni]


# --- Lo stream -------------------------------------------------------------


def uso(token: int, uscita: int = 20) -> Dict[str, int]:
    """Un usage finto, con la prima richiesta nella cache."""
    return {"input_tokens": 3, "cache_creation_input_tokens": token,
            "cache_read_input_tokens": 0, "output_tokens": uscita}


def stampa_righe(righe: List[Dict[str, Any]]) -> None:
    """Lo stream, una riga per evento."""
    for numero, riga in enumerate(righe):
        print(json.dumps(riga, ensure_ascii=False))
        if numero == 1 and "riga-rotta" in modi():
            print("{questa riga non è JSON")


def evento_risultato(risposta: str, turni: int, sessione: str,
                     prima: int) -> Dict[str, Any]:
    """L'evento result finto."""
    errore = "errore" in modi()
    return {"type": "result",
            "subtype": "error_during_execution" if errore else "success",
            "is_error": errore, "num_turns": turni,
            "duration_ms": 900 * turni, "result": risposta,
            "session_id": sessione,
            "usage": uso(prima, 30),
            "modelUsage": {"claude-finto": {
                "inputTokens": 3, "outputTokens": 30,
                "cacheReadInputTokens": 0,
                "cacheCreationInputTokens": prima}},
            "permission_denials": []}


def stream_d01(risposta: str, prima: int, sessione: str) -> None:
    """Lo stream finto di una chiamata senza strumenti."""
    righe: List[Dict[str, Any]] = [
        {"type": "system", "subtype": "init", "session_id": sessione,
         "model": "claude-finto", "claude_code_version": "9.9.9 (finto)",
         "permissionMode": "dontAsk"},
        {"type": "assistant", "parent_tool_use_id": None,
         "message": {"id": "msg_1", "content": [{"type": "text",
                                                 "text": risposta}],
                     "usage": uso(prima)}}]
    if "tronco" not in modi():
        righe.append(evento_risultato(risposta, 1, sessione, prima))
    stampa_righe(righe)


def stream_banco(mosse: List[Mossa], risposta: str, prima: int, sessione: str,
                 strumenti: List[str]) -> None:
    """Lo stream finto di una chiamata con il banco."""
    server_ko = "server-ko" in modi()
    righe: List[Dict[str, Any]] = [
        {"type": "system", "subtype": "init", "session_id": sessione,
         "model": "claude-finto", "claude_code_version": "9.9.9 (finto)",
         "tools": [] if server_ko else ["mcp__assistenza__" + n
                                        for n in strumenti],
         "mcp_servers": [{"name": "assistenza",
                          "status": "failed" if server_ko else "connected"}]}]
    finale = {"type": "assistant", "parent_tool_use_id": None,
              "message": {"id": "msg_f", "content": [
                  {"type": "text", "text": risposta}],
                  "usage": uso(prima + 400)}}
    if "dopo" in modi():
        righe.append(finale)
    for numero, mossa in enumerate(mosse, 1):
        ident = "toolu_finto_%d" % numero
        righe.append({"type": "assistant", "parent_tool_use_id": None,
                      "message": {"id": "msg_%d" % numero, "content": [{
                          "type": "tool_use", "id": ident,
                          "name": "mcp__assistenza__" + mossa.nome,
                          "input": mossa.argomenti}],
                          "usage": uso(prima + 100 * (numero - 1))}})
        blocco: Dict[str, Any] = {
            "type": "tool_result", "tool_use_id": ident,
            "content": json.dumps(mossa.risultato, ensure_ascii=False)}
        if mossa.errore and "senza-is-error" not in modi():
            blocco["is_error"] = True
        righe.append({"type": "user", "parent_tool_use_id": None,
                      "message": {"role": "user", "content": [blocco]}})
    if "dopo" not in modi():
        righe.append(finale)
    if "tronco" not in modi():
        righe.append(evento_risultato(risposta, len(mosse) + 1, sessione,
                                      prima))
    stampa_righe(righe)


def main(argv: List[str]) -> int:
    if argv == ["--version"]:
        print("9.9.9 (Claude Code finto)")
        return 0
    try:
        opzioni, prompt = argomenti(argv)
        scrivi_log(argv, opzioni, prompt)
        if "ko" in modi():
            return 1
        ko = valore_modo("ko-se")
        if ko and ko in prompt:
            return 1
        sessione = opzioni.get("--resume") or str(uuid.uuid4())
        if "--mcp-config" in opzioni:
            mosse, risposta, prima, strumenti = scena_banco(opzioni, prompt,
                                                            sessione)
            stream_banco(mosse, risposta, prima, sessione, strumenti)
        else:
            risposta, prima = scena_d01(opzioni, prompt, sessione)
            stream_d01(risposta, prima, sessione)
    except Rifiutato as exc:
        print(str(exc), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
