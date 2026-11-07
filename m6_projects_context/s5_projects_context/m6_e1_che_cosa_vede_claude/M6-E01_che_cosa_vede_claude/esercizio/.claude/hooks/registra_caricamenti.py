#!/usr/bin/env python3
"""registra_caricamenti.py -- l'hook InstructionsLoaded degli elementi del
Modulo 6: per ogni file di istruzioni che Claude Code carica nel contesto, un
CLAUDE.md, un CLAUDE.local.md, un file importato o una regola di
.claude/rules/, aggiunge una riga JSON al registro dello spazio di lavoro.
La documentazione dell'evento: «When a CLAUDE.md or .claude/rules/*.md file is
loaded into context.» (https://code.claude.com/docs/en/hooks).

Si configura nel .claude/settings.json dello spazio di lavoro, con una copia
identica di questo file in .claude/hooks/:

    {"hooks": {"InstructionsLoaded": [{"hooks": [{"type": "command",
      "command": "python3 \\"$CLAUDE_PROJECT_DIR/.claude/hooks/registra_caricamenti.py\\""}]}]}}

Legge da STDIN il JSON dell'evento e aggiunge al registro, in
$CLAUDE_PROJECT_DIR/.claude/caricamenti.jsonl (o nel file di
PN_CARICAMENTI), una riga con i campi dell'evento, con gli stessi nomi:
load_reason, file_path, memory_type, trigger_file_path, parent_file_path,
globs. I percorsi sono relativi alla cartella del progetto; uno sotto la
home diventa «~/…»: così il registro non porta il nome di chi lo ha scritto
e si può mostrare. Una riga sola per evento, scritta in una volta in append.

Uso:    python3 "$CLAUDE_PROJECT_DIR/.claude/hooks/registra_caricamenti.py"
        (così lo lanciano le impostazioni; l'evento su STDIN)
Env:    CLAUDE_PROJECT_DIR  la cartella del progetto, che Claude Code passa
                            agli hook (altrimenti il campo cwd dell'evento)
        PN_CARICAMENTI      un altro registro (le prove)
Uscita: 0 riga scritta · 1 evento che non si legge, di un altro tipo o
        registro che non si scrive · 2 uso sbagliato (un argomento). Claude
        Code ignora l'uscita di questo hook («`InstructionsLoaded` | No | Exit
        code is ignored», https://code.claude.com/docs/en/hooks): un registro
        che manca o è incompleto lo trova il controllo dell'elemento, e lo
        dice.
"""
from __future__ import annotations

import json
import os
import sys
from typing import Optional

CAMPI = ("load_reason", "file_path", "memory_type", "trigger_file_path",
         "parent_file_path", "globs")
PERCORSI = ("file_path", "trigger_file_path", "parent_file_path")
EVENTO = "InstructionsLoaded"


def _dentro(percorso: str, cartella: str) -> Optional[str]:
    """Il percorso relativo, con le barre, se percorso sta in cartella."""
    try:
        if os.path.commonpath([percorso, cartella]) != cartella:
            return None
    except ValueError:
        return None
    relativo = os.path.relpath(percorso, cartella)
    return relativo.replace(os.sep, "/")


def mostra(percorso: object, progetto: str, casa: str) -> object:
    """Un percorso da mostrare: relativo al progetto, «~/…» sotto la home,
    assoluto altrimenti; ciò che non è una stringa resta com'è."""
    if not isinstance(percorso, str) or not percorso:
        return percorso
    vero = os.path.realpath(percorso)
    if progetto:
        relativo = _dentro(vero, os.path.realpath(progetto))
        if relativo is not None:
            return relativo
    if casa:
        relativo = _dentro(vero, os.path.realpath(casa))
        if relativo is not None:
            return "~/" + relativo
    return percorso


def riga(evento: dict, progetto: str, casa: str) -> str:
    """La riga del registro per un evento, senza il fine riga."""
    tenuto = {}
    for campo in CAMPI:
        valore = evento.get(campo)
        if campo in PERCORSI:
            valore = mostra(valore, progetto, casa)
        tenuto[campo] = valore
    return json.dumps(tenuto, ensure_ascii=False, sort_keys=False)


def scrivi(registro: str, testo: str) -> None:
    """Aggiunge una riga al registro con una sola write in append."""
    cartella = os.path.dirname(registro)
    if cartella:
        os.makedirs(cartella, exist_ok=True)
    fd = os.open(registro, os.O_WRONLY | os.O_APPEND | os.O_CREAT, 0o600)
    try:
        os.write(fd, (testo + "\n").encode("utf-8"))
    finally:
        os.close(fd)


def main(argv: list) -> int:
    if len(argv) > 1:
        print("uso: python3 -B -I registra_caricamenti.py "
              "(l'evento su STDIN)", file=sys.stderr)
        return 2
    try:
        evento = json.load(sys.stdin)
    except (ValueError, UnicodeDecodeError) as exc:
        print(f"registra_caricamenti: l'evento non è JSON: {exc}",
              file=sys.stderr)
        return 1
    if not isinstance(evento, dict) \
            or evento.get("hook_event_name") != EVENTO:
        print("registra_caricamenti: non è un evento InstructionsLoaded",
              file=sys.stderr)
        return 1
    progetto = os.environ.get("CLAUDE_PROJECT_DIR") or evento.get("cwd") \
        or ""
    if not isinstance(progetto, str):
        progetto = ""
    registro = os.environ.get("PN_CARICAMENTI") or (
        os.path.join(progetto, ".claude", "caricamenti.jsonl")
        if progetto else "")
    if not registro:
        print("registra_caricamenti: né CLAUDE_PROJECT_DIR né cwd: non so "
              "dove scrivere", file=sys.stderr)
        return 1
    try:
        scrivi(registro, riga(evento, progetto, os.environ.get("HOME", "")))
    except OSError as exc:
        print(f"registra_caricamenti: non riesco a scrivere {registro}: "
              f"{exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
