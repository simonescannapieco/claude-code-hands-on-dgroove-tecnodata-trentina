#!/usr/bin/env python3
"""claude_finto_m6_e01.py -- un claude finto per le prove di M6-E01
(test_m6_e01.sh).

La suite lo copia, con il nome «claude», davanti nel PATH: così i comandi del
README e _docente/live.sh girano per intero senza chiamare il modello e senza
consumare il piano. Ciò che scrive è inventato e dichiarato finto: nessuna
riga è un'uscita di Claude Code né una risposta di Claude. Ha la forma delle
uscite viste nelle prove del corso con Claude Code 2.1.319: /context all in
-p, un testo in Markdown con il titolo «Context Usage», la tabella delle
categorie e, se nella cartella c'è CLAUDE.md, la riga «Memory files» e la
tabella «Memory Files» con il percorso assoluto del file; la domanda, uno
stream di --output-format stream-json --verbose (system/init, assistant,
result).

Fa ciò che la documentazione dice, perché la verifica lo possa vedere: se
nella cartella c'è CLAUDE.md, lo elenca, e chiama l'hook InstructionsLoaded
di .claude/settings.json con l'evento su STDIN (load_reason session_start) e
CLAUDE_PROJECT_DIR nell'ambiente, come Claude Code. Lo chiama con bash -c, il
comando così com'è nelle impostazioni dello spazio di lavoro di prova.

Gli argomenti: le opzioni di OPZIONI e un prompt, prima o dopo «--».
Rifiuta («error: …», uscita 1) un'opzione che non conosce, due prompt, un
--output-format diverso da text per /context all e da stream-json per la
domanda, lo stream-json senza --verbose, un prompt che non conosce.
«--version» stampa una versione finta.

Ogni invocazione aggiunge a FINTO_LOG, se c'è, una riga JSON: argv, cwd,
prompt, chiave (ANTHROPIC_API_KEY nell'ambiente?), effort_env
(CLAUDE_CODE_EFFORT_LEVEL?), stdin_nullo, claude_md (c'era CLAUDE.md?).

Le variabili per mettere alla prova la verifica (=1 per accendere):
  FINTO_SENZA_MEMORIA   /context non elenca CLAUDE.md anche se c'è
  FINTO_SENZA_TABELLA   la riga «Memory files» c'è, la tabella dei file no
  FINTO_SENZA_HOOK      l'hook non si chiama
  FINTO_NON_NOMINA      la risposta non nomina i comandi di CLAUDE.md
  FINTO_ERRORE          il risultato della domanda è un errore
  FINTO_ESITO_KO_SE=t   esce 1 senza stampare nulla se il prompt contiene t
Uscita: 0 · 1 FINTO_ESITO_KO_SE, un argomento rifiutato, un prompt sconosciuto
"""
import json
import os
import subprocess
import sys
import uuid
from typing import Dict, List, Optional, Tuple

OPZIONI = {"-p": 0, "--print": 0, "--verbose": 0, "--strict-mcp-config": 0,
           "--no-session-persistence": 0, "--model": 1, "--effort": 1,
           "--allowedTools": 1, "--output-format": 1, "--permission-mode": 1,
           "--permission-prompts": 1, "--setting-sources": 1}
CONTESTO = "/context all"
DOMANDA = "Con quale comando si eseguono i test di questo progetto?"
FINTO = "_Uscita finta di claude_finto_m6_e01.py: non è Claude Code._"
USO = {"input_tokens": 3, "cache_creation_input_tokens": 1200,
       "cache_read_input_tokens": 15000, "output_tokens": 40}


class Rifiutato(Exception):
    """Argomenti che il finto non accetta: il messaggio d'errore."""


def acceso(nome: str) -> bool:
    """Vero se la variabile d'ambiente vale 1."""
    return os.environ.get(nome) == "1"


def argomenti(argv: List[str]) -> Tuple[Dict[str, str], str]:
    """(le opzioni con i loro valori, il prompt)."""
    opzioni: Dict[str, str] = {}
    prompt: Optional[str] = None
    i = 0
    while i < len(argv):
        arg = argv[i]
        if arg == "--":
            if len(argv) != i + 2 or prompt is not None:
                raise Rifiutato("error: dopo -- un prompt solo")
            return opzioni, argv[i + 1]
        if arg.startswith("-"):
            if arg not in OPZIONI:
                raise Rifiutato("error: unknown option '%s'" % arg)
            quanti = OPZIONI[arg]
            if quanti and i + 1 >= len(argv):
                raise Rifiutato("error: option '%s' argument missing" % arg)
            opzioni[arg] = argv[i + 1] if quanti else ""
            i += 1 + quanti
            continue
        if prompt is not None:
            raise Rifiutato("error: due prompt")
        prompt = arg
        i += 1
    if prompt is None:
        raise Rifiutato("error: manca il prompt")
    return opzioni, prompt


def registra(argv: List[str], prompt: str) -> None:
    """La riga di FINTO_LOG."""
    percorso = os.environ.get("FINTO_LOG")
    if not percorso:
        return
    riga = {"argv": argv, "cwd": os.getcwd(), "prompt": prompt,
            "chiave": "ANTHROPIC_API_KEY" in os.environ,
            "effort_env": "CLAUDE_CODE_EFFORT_LEVEL" in os.environ,
            "stdin_nullo": os.path.samestat(os.fstat(0),
                                            os.stat(os.devnull)),
            "claude_md": os.path.isfile("CLAUDE.md")}
    with open(percorso, "a", encoding="utf-8") as fh:
        fh.write(json.dumps(riga, ensure_ascii=False) + "\n")


def comandi_hook() -> List[str]:
    """I comandi degli hook InstructionsLoaded di .claude/settings.json."""
    try:
        with open(os.path.join(".claude", "settings.json"),
                  encoding="utf-8") as fh:
            impostazioni = json.load(fh)
    except (OSError, ValueError):
        return []
    gruppi = impostazioni.get("hooks", {}).get("InstructionsLoaded", [])
    return [h["command"] for g in gruppi for h in g.get("hooks", [])
            if h.get("type") == "command" and h.get("command")]


def carica(sid: str) -> Optional[str]:
    """Se c'è CLAUDE.md, l'hook all'avvio; il percorso assoluto del file."""
    if not os.path.isfile("CLAUDE.md"):
        return None
    percorso = os.path.join(os.getcwd(), "CLAUDE.md")
    if acceso("FINTO_SENZA_HOOK"):
        return percorso
    evento = {"session_id": sid, "transcript_path": os.devnull,
              "cwd": os.getcwd(), "hook_event_name": "InstructionsLoaded",
              "file_path": percorso, "memory_type": "Project",
              "load_reason": "session_start"}
    ambiente = dict(os.environ, CLAUDE_PROJECT_DIR=os.getcwd())
    for comando in comandi_hook():
        subprocess.run(["bash", "-c", comando], input=json.dumps(evento),
                       universal_newlines=True, env=ambiente, check=False)
    return percorso


def contesto(percorso: Optional[str]) -> str:
    """L'uscita finta di /context all."""
    elenca = percorso is not None and not acceso("FINTO_SENZA_MEMORIA")
    righe = ["## Context Usage", "", FINTO, "",
             "**Model:** claude-finto  ", "**Tokens:** 1k / 10k (10%)", "",
             "### Estimated usage by category", "",
             "| Category | Tokens | Percentage |",
             "|----------|--------|------------|",
             "| System prompt | 900 | 9.0% |"]
    if elenca or (percorso and acceso("FINTO_SENZA_TABELLA")):
        righe.append("| Memory files | 31 | 0.3% |")
    righe += ["| Messages | 10 | 0.1% |", "| Free space | 9k | 90.6% |", ""]
    if elenca and not acceso("FINTO_SENZA_TABELLA"):
        righe += ["### Memory Files", "", "| Type | Path | Tokens |",
                  "|------|------|--------|",
                  "| Project | %s | 31 |" % percorso, ""]
    righe += ["### Skills", "", "| Skill | Source | Tokens |",
              "|-------|--------|--------|", "| finta | Built-in | ~10 |"]
    return "\n".join(righe) + "\n"


def emetti(evento: dict) -> None:
    print(json.dumps(evento, ensure_ascii=False))


def domanda(sid: str, percorso: Optional[str]) -> None:
    """Lo stream finto della domanda, con una risposta inventata."""
    if acceso("FINTO_NON_NOMINA") or percorso is None:
        testo = "Risposta finta del claude finto: composer test."
    else:
        testo = ("Risposta finta del claude finto: da %s/progetti/"
                 "gestionale-php, `../../tools/php.sh phpunit`, come dice "
                 "CLAUDE.md." % os.getcwd())
    emetti({"type": "system", "subtype": "init", "cwd": os.getcwd(),
            "session_id": sid, "model": "claude-finto",
            "memory_paths": {"auto": "/home/finto/.claude/projects/x/"},
            "tools": ["Read", "Glob", "Grep"]})
    emetti({"type": "assistant", "message": {
        "model": "claude-finto", "id": "msg_" + uuid.uuid4().hex[:12],
        "type": "message", "role": "assistant",
        "content": [{"type": "text", "text": testo}], "usage": USO},
        "parent_tool_use_id": None, "session_id": sid})
    errore = acceso("FINTO_ERRORE")
    emetti({"type": "result", "subtype": "error_during_execution"
            if errore else "success", "is_error": errore, "num_turns": 1,
            "duration_ms": 1000, "result": testo, "session_id": sid,
            "usage": USO, "modelUsage": {"claude-finto": {
                "inputTokens": 3, "outputTokens": 40,
                "cacheReadInputTokens": 15000,
                "cacheCreationInputTokens": 1200}},
            "permission_denials": []})


def esegui(argv: List[str]) -> int:
    if argv == ["--version"]:
        print("0.0.0 (Claude Code finto)")
        return 0
    opzioni, prompt = argomenti(argv)
    if "-p" not in opzioni and "--print" not in opzioni:
        raise Rifiutato("error: il finto conosce solo -p")
    registra(argv, prompt)
    ko = os.environ.get("FINTO_ESITO_KO_SE")
    if ko and ko in prompt:
        return 1
    formato = opzioni.get("--output-format", "text")
    sid = str(uuid.uuid4())
    if prompt == CONTESTO:
        if formato != "text":
            raise Rifiutato("error: il finto stampa /context solo in text")
        sys.stdout.write(contesto(carica(sid)))
        return 0
    if prompt == DOMANDA:
        if formato != "stream-json" or "--verbose" not in opzioni:
            raise Rifiutato("error: la domanda vuole stream-json e --verbose")
        domanda(sid, carica(sid))
        return 0
    raise Rifiutato("error: il finto non conosce il prompt %r" % prompt)


def main() -> int:
    try:
        return esegui(sys.argv[1:])
    except Rifiutato as exc:
        sys.stderr.write("%s\n" % exc)
        return 1


if __name__ == "__main__":
    sys.exit(main())
