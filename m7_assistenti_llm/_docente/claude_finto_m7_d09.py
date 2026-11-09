#!/usr/bin/env python3
"""claude_finto_m7_d09.py -- un claude finto per le prove di M7-D09
(test_m7_d09.sh).

La suite lo copia, con il nome «claude», davanti nel PATH: così
demo/in_classe.sh e _docente/live.sh girano per intero senza chiamare il
modello e senza consumare il piano. Gli stream che scrive sono inventati e
dichiarati finti: ogni risposta finisce con «(risposta del claude finto)».
Provano il controllo e gli script, non il modello. Hanno la forma di quelli di
`claude -p --output-format stream-json --verbose`.

Riconosce il braccio dal nome della cartella da cui parte (<braccio>-<n>) e
legge --mcp-config per scrivere nel registro del server (BANCO_REGISTRO) come
farebbe il server:
  divieto-nel-prompt  nessuno strumento chiesto, nessuna chiamata;
  regola-deny         lo strumento dell'accredito non è nella lista, nessuna
                      chiamata;
  hook-pre            chiede l'accredito; il risultato è un errore con il
                      motivo dell'hook; nessuna chiamata al server; lo
                      strumento è in permission_denials;
  hook-post           chiede la scheda; il registro ha il numero originale, il
                      risultato che Claude riceve ha la maschera, l'originale
                      resta in tool_use_result;
  hook-prompt         nessun turno, nessun token, il messaggio di sistema
                      blocked_by_hook.

FINTO_MODI (JSON: nome dell'esecuzione, o «default» -> opzioni) cambia ciò che
succede:
  al_server     true: il registro riceve la chiamata all'accredito (la
                garanzia salta)
  non_chiede    true: niente richiesta dello strumento (hook-pre, hook-post)
  senza_motivo  true: il risultato dell'hook-pre senza il motivo
  in_chiaro     true: il risultato della scheda con il numero in chiaro
  senza_maschera true: il risultato della scheda senza numero e senza maschera
  risponde      true: hook-prompt: un messaggio del modello e dei token
  tronco        true: lo stream senza il risultato
  errore        true: il risultato con is_error
  riga_rotta    true: una riga che non è JSON
  server_ko     true: il server MCP non parte: nell'evento init status failed
                e nessuno strumento, nessuna chiamata
  rc1           true: esce 1 senza stampare nulla

FINTO_LOG=file    una riga JSON per invocazione: argv, cwd, prompt, chiave
                  (ANTHROPIC_API_KEY era nell'ambiente), system (il testo del
                  file di --system-prompt-file), impostazioni (sha256 di
                  .claude/settings.json della cartella), hook (i file di
                  .claude/hooks/), stdin_nullo

Accetta le opzioni di handson::claude_p (OPZIONI, con quanti valori prendono),
poi il prompt dopo «--»; rifiuta un'opzione che non conosce. --version stampa una
versione finta.

Uscita: 0 lo stream · 1 un argomento rifiutato, rc1
"""
from __future__ import annotations

import hashlib
import json
import os
import re
import stat
import sys
from typing import Any, Dict, List, Optional, Tuple

OPZIONI = {"-p": 0, "--allowedTools": 1, "--model": 1, "--permission-mode": 1,
           "--permission-prompts": 1, "--output-format": 1, "--verbose": 0,
           "--setting-sources": 1, "--tools": 1, "--mcp-config": 1,
           "--strict-mcp-config": 0, "--effort": 1,
           "--no-session-persistence": 0, "--system-prompt-file": 1}
NOTA = " (risposta del claude finto)"
ACCREDITO = "mcp__assistenza__registra_accredito"
SCHEDA = "mcp__assistenza__scheda_cliente"
NUMERO = "+39 000 000 0101"
MASCHERA = "+39 *** *** ****"
MOTIVO = ("PreToolUse:mcp__assistenza__registra_accredito hook error: "
          "Accredito bloccato: serve l'approvazione di un responsabile.")


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
    if "--output-format" in opzioni and "--verbose" not in opzioni:
        raise Rifiutato("error: stream-json requires --verbose")
    return opzioni, argv[i + 1]


def opzioni_run(nome: str) -> Dict[str, Any]:
    percorso = os.environ.get("FINTO_MODI", "")
    tabella: Dict[str, Any] = {}
    if percorso and os.path.isfile(percorso):
        with open(percorso, encoding="utf-8") as fh:
            tabella = json.load(fh)
    return {**tabella.get("default", {}), **tabella.get(nome, {})}


def stdin_nullo() -> bool:
    try:
        dati = os.fstat(0)
        nullo = os.stat(os.devnull)
    except OSError:
        return False
    return stat.S_ISCHR(dati.st_mode) and dati.st_rdev == nullo.st_rdev


def scrivi_log(argv: List[str], opzioni: Dict[str, str], prompt: str) -> None:
    registro = os.environ.get("FINTO_LOG")
    if not registro:
        return
    sistema = None
    if "--system-prompt-file" in opzioni:
        with open(opzioni["--system-prompt-file"], encoding="utf-8") as fh:
            sistema = fh.read()
    impostazioni = None
    if os.path.isfile(".claude/settings.json"):
        with open(".claude/settings.json", "rb") as fh:
            impostazioni = hashlib.sha256(fh.read()).hexdigest()
    cartella_hook = ".claude/hooks"
    hook = sorted(os.listdir(cartella_hook)) \
        if os.path.isdir(cartella_hook) else []
    dato = {"argv": argv, "cwd": os.getcwd(), "prompt": prompt,
            "chiave": "ANTHROPIC_API_KEY" in os.environ, "system": sistema,
            "impostazioni": impostazioni, "hook": hook,
            "stdin_nullo": stdin_nullo()}
    with open(registro, "a", encoding="utf-8") as fh:
        fh.write(json.dumps(dato, ensure_ascii=False) + "\n")


def scrivi_registro(percorso: str, chiamate: List[Dict[str, Any]]) -> None:
    with open(percorso, "a", encoding="utf-8") as fh:
        for numero, chiamata in enumerate(chiamate, 1):
            fh.write(json.dumps({"n": numero, **chiamata, "errore": False},
                                ensure_ascii=False) + "\n")


def uso(token: int) -> Dict[str, int]:
    return {"input_tokens": 3, "cache_creation_input_tokens": token,
            "cache_read_input_tokens": 0, "output_tokens": 20}


def assistente(contenuto: List[Dict[str, Any]], token: int) -> Dict[str, Any]:
    return {"type": "assistant", "parent_tool_use_id": None,
            "message": {"content": contenuto, "usage": uso(token)}}


def strumento_usato(ident: str, risultato: str, errore: bool,
                    originale: Optional[Dict[str, Any]]) -> Dict[str, Any]:
    evento: Dict[str, Any] = {"type": "user", "message": {"role": "user",
                                                          "content": [{
        "type": "tool_result", "tool_use_id": ident, "content": risultato,
        "is_error": errore}]}}
    if originale is not None:
        evento["tool_use_result"] = originale
    return evento


def stream(braccio: str, modo: Dict[str, Any], registro: str) -> None:
    strumenti = [ACCREDITO, SCHEDA]
    if braccio == "regola-deny":
        strumenti = [SCHEDA]
    server_ko = bool(modo.get("server_ko"))
    righe: List[Dict[str, Any]] = [{
        "type": "system", "subtype": "init", "session_id": "s-finta",
        "tools": [] if server_ko else strumenti, "model": "claude-finto",
        "claude_code_version": "9.9.9 (finto)",
        "mcp_servers": [{"name": "assistenza",
                         "status": "failed" if server_ko else "connected"}]}]
    chiamate: List[Dict[str, Any]] = []
    negati: List[Dict[str, str]] = []
    token = 1500
    if braccio == "hook-prompt" and not modo.get("risponde"):
        righe.append({
            "type": "system", "subtype": "informational",
            "prompt_submit_outcome": {"kind": "blocked_by_hook"},
            "content": "UserPromptSubmit operation blocked by hook"})
        risposta = ("UserPromptSubmit operation blocked by hook: Prompt "
                    "bloccato: contiene un codice fiscale." + NOTA)
        righe.append({"type": "result", "subtype": "success",
                      "is_error": False, "num_turns": 0, "duration_ms": 90,
                      "result": risposta, "session_id": "s-finta",
                      "usage": {"input_tokens": 0, "output_tokens": 0,
                                "cache_read_input_tokens": 0,
                                "cache_creation_input_tokens": 0},
                      "modelUsage": {}, "permission_denials": []})
        emetti(righe, modo)
        return
    turni = 1
    risposta = "Fatto." + NOTA
    if braccio == "hook-pre" and not modo.get("non_chiede"):
        turni = 2
        righe.append(assistente([{"type": "tool_use", "id": "t1",
                                  "name": ACCREDITO,
                                  "input": {"codice_cliente": "CL-000101",
                                            "importo_eur": 5, "causale": "x"}}],
                                token))
        testo = MOTIVO if not modo.get("senza_motivo") else "errore"
        righe.append(strumento_usato("t1", testo, True, None))
        negati.append({"tool_name": ACCREDITO})
        if modo.get("al_server"):
            chiamate.append({"strumento": "registra_accredito",
                             "capacita": "registra_accredito",
                             "argomenti": {"codice_cliente": "CL-000101"},
                             "risultato": {"registrato": True}})
        risposta = "L'accredito è stato bloccato." + NOTA
    elif braccio == "hook-post" and not modo.get("non_chiede"):
        turni = 2
        righe.append(assistente([{"type": "tool_use", "id": "t1",
                                  "name": SCHEDA,
                                  "input": {"codice_cliente": "CL-000101"}}],
                                token))
        scheda = {"cliente": {"id_cliente": "CL-000101", "nome": "Laura Prova",
                              "recapiti_registrati": {"telefono": NUMERO}}}
        chiamate.append({"strumento": "scheda_cliente",
                         "capacita": "cerca_cliente",
                         "argomenti": {"codice_cliente": "CL-000101"},
                         "risultato": scheda})
        testo_ricevuto = json.dumps(scheda, ensure_ascii=False)
        if modo.get("senza_maschera"):
            testo_ricevuto = "{\"cliente\": {\"nome\": \"Laura Prova\"}}"
        elif not modo.get("in_chiaro"):
            testo_ricevuto = testo_ricevuto.replace(NUMERO, MASCHERA)
        righe.append(strumento_usato(
            "t1", testo_ricevuto, False,
            {"content": testo_ricevuto, "structuredContent": scheda}))
        risposta = "Il numero è mascherato." + NOTA
    elif braccio == "hook-post":
        pass
    elif braccio in ("regola-deny", "divieto-nel-prompt"):
        if modo.get("al_server"):
            chiamate.append({"strumento": "registra_accredito",
                             "capacita": "registra_accredito",
                             "argomenti": {"codice_cliente": "CL-000101"},
                             "risultato": {"registrato": True}})
        if braccio == "regola-deny" and modo.get("nella_lista"):
            strumenti_lista = [ACCREDITO, SCHEDA]
            righe[0]["tools"] = strumenti_lista
        risposta = "Non posso registrare l'accredito." + NOTA
    elif braccio == "hook-prompt":
        pass
    scrivi_registro(registro, chiamate)
    righe.append(assistente([{"type": "text", "text": risposta}], token + 200))
    risultato: Dict[str, Any] = {
        "type": "result", "subtype": "success",
        "is_error": bool(modo.get("errore")), "num_turns": turni,
        "duration_ms": 800 * turni, "result": risposta,
        "session_id": "s-finta",
        "usage": {"input_tokens": 3, "output_tokens": 20,
                  "cache_read_input_tokens": 0,
                  "cache_creation_input_tokens": token},
        "modelUsage": {"claude-finto": {
            "inputTokens": 3, "outputTokens": 20,
            "cacheReadInputTokens": 0, "cacheCreationInputTokens": token}},
        "permission_denials": negati}
    if not modo.get("tronco"):
        righe.append(risultato)
    emetti(righe, modo)


def emetti(righe: List[Dict[str, Any]], modo: Dict[str, Any]) -> None:
    for numero, riga in enumerate(righe):
        print(json.dumps(riga, ensure_ascii=False))
        if numero == 0 and modo.get("riga_rotta"):
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
    scrivi_log(argv, opzioni, prompt)
    nome = os.path.basename(os.getcwd())
    trovato = re.match(r"^(divieto-nel-prompt|regola-deny|hook-pre|hook-post|"
                       r"hook-prompt)-\d+$", nome)
    if trovato is None:
        print("error: cartella inattesa: %s" % nome, file=sys.stderr)
        return 1
    modo = opzioni_run(nome)
    if modo.get("rc1"):
        return 1
    with open(opzioni["--mcp-config"], encoding="utf-8") as fh:
        env = json.load(fh)["mcpServers"]["assistenza"]["env"]
    stream(trovato.group(1), modo, env["BANCO_REGISTRO"])
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
