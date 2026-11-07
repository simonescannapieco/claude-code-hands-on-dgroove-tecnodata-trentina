#!/usr/bin/env python3
"""claude_finto.py -- un claude finto per le prove di tools/prova_contesto.sh.

La suite lo copia, con il nome «claude», davanti nel PATH: lo strumento gira
per intero senza chiamare il modello e senza consumare il piano. Lo stream ha
la forma di quello di `claude -p --output-format stream-json --verbose`, ma è
inventato: nessuna riga è una risposta di Claude.

Gli argomenti: le opzioni di handson::claude_p e di prova_contesto.sh, poi
«--» e il prompt; un'opzione che non conosce la rifiuta (uscita 1).
«--version» stampa una versione finta.

Al posto di Claude Code fa scattare l'hook InstructionsLoaded dello spazio di
lavoro, il vero .claude/hooks/registra_caricamenti.py, con un evento
session_start per ogni CLAUDE.md, CLAUDE.local.md della radice e per ogni
regola di .claude/rules/ senza «paths:».

Ogni invocazione aggiunge a FINTO_LOG una riga JSON: argv, cwd, prompt, la
auto memory spenta o no, i file di istruzioni e gli altri file che vede, i
file del commit di partenza; con FINTO_PAUSA anche una riga all'inizio e una
alla fine, per contare quante esecuzioni girano insieme.

Che cosa risponde lo decide il prompt:
  COMMIT   cambia LEGGIMI.txt e fa un commit «docs: corregge il refuso»
  altrimenti una risposta qualunque
L'ambiente: FINTO_LOG (obbligatorio), FINTO_PAUSA (secondi), FINTO_KO_SU
(una parola: se è nel prompt esce 1 senza un risultato).
Uscita: 0 risposta · 1 FINTO_KO_SU o un argomento rifiutato
"""
import json
import os
import subprocess
import sys
import time

OPZIONI = {"-p": 0, "--allowedTools": 1, "--model": 1, "--permission-mode": 1,
           "--permission-prompts": 1, "--output-format": 1, "--verbose": 0,
           "--setting-sources": 1, "--effort": 1, "--strict-mcp-config": 0,
           "--no-session-persistence": 0, "--tools": 1,
           "--disallowedTools": 1}


def leggi_argomenti(argv):
    opzioni, i = {}, 0
    while i < len(argv):
        a = argv[i]
        if a == "--":
            return opzioni, " ".join(argv[i + 1:])
        if a not in OPZIONI:
            return None, None
        n = OPZIONI[a]
        opzioni[a] = argv[i + 1] if n else True
        i += 1 + n
    return None, None


def scrivi_log(dato):
    with open(os.environ["FINTO_LOG"], "a", encoding="utf-8") as fh:
        fh.write(json.dumps(dato, ensure_ascii=False) + "\n")


def file_qui():
    visti = []
    for radice, cartelle, nomi in os.walk("."):
        cartelle[:] = [c for c in cartelle if c != ".git"]
        for nome in nomi:
            visti.append(os.path.relpath(os.path.join(radice, nome), "."))
    return sorted(visti)


def caricamenti():
    """Fa scattare l'hook vero per ciò che si caricherebbe all'avvio."""
    hook = os.path.join(".claude", "hooks", "registra_caricamenti.py")
    nomi = [n for n in ("CLAUDE.md", "CLAUDE.local.md") if os.path.isfile(n)]
    regole = os.path.join(".claude", "rules")
    if os.path.isdir(regole):
        for nome in sorted(os.listdir(regole)):
            percorso = os.path.join(regole, nome)
            with open(percorso, encoding="utf-8") as fh:
                if "paths:" not in fh.read():
                    nomi.append(percorso)
    for nome in nomi:
        evento = {"hook_event_name": "InstructionsLoaded",
                  "load_reason": "session_start",
                  "file_path": os.path.abspath(nome),
                  "memory_type": "Project", "cwd": os.getcwd()}
        subprocess.run([sys.executable, "-B", "-I", hook],
                       input=json.dumps(evento), text=True, check=True,
                       env={**os.environ, "CLAUDE_PROJECT_DIR": os.getcwd()})
    return sum(os.path.getsize(n) for n in nomi)


def stream(prompt, peso):
    righe = [{"type": "system", "subtype": "init", "model": "finto"},
             {"type": "assistant", "parent_tool_use_id": None,
              "message": {"usage": {"input_tokens": 3,
                                    "cache_creation_input_tokens": 1000 + peso,
                                    "cache_read_input_tokens": 0},
                          "content": [{"type": "text", "text": "fatto"}]}},
             {"type": "result", "subtype": "success", "is_error": False,
              "num_turns": 1, "duration_ms": 10, "result": "finto: fatto",
              "usage": {"input_tokens": 3, "cache_creation_input_tokens": 0,
                        "cache_read_input_tokens": 0, "output_tokens": 1}}]
    for riga in righe:
        print(json.dumps(riga))


def main(argv):
    if argv == ["--version"]:
        print("9.9.9 (finto)")
        return 0
    opzioni, prompt = leggi_argomenti(argv)
    if opzioni is None:
        print("error: unknown option", file=sys.stderr)
        return 1
    pausa = float(os.environ.get("FINTO_PAUSA") or 0)
    if pausa:
        scrivi_log({"evento": "inizio", "t": time.time()})
        time.sleep(pausa)
    partenza = subprocess.run(["git", "show", "--name-only", "--format=",
                               "HEAD"], capture_output=True, text=True)
    scrivi_log({"evento": "chiamata", "argv": argv, "cwd": os.getcwd(),
                "prompt": prompt,
                "memoria_spenta": os.environ.get(
                    "CLAUDE_CODE_DISABLE_AUTO_MEMORY"),
                "file": file_qui(),
                "partenza": partenza.stdout.split()})
    ko = os.environ.get("FINTO_KO_SU")
    if ko and ko in prompt:
        return 1
    peso = caricamenti()
    if "COMMIT" in prompt:
        with open("LEGGIMI.txt", "a", encoding="utf-8") as fh:
            fh.write("corretto\n")
        subprocess.run(["git", "commit", "-qam", "docs: corregge il refuso"],
                       check=True)
    stream(prompt, peso)
    if pausa:
        scrivi_log({"evento": "fine", "t": time.time()})
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
