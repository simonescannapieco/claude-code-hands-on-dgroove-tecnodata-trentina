#!/usr/bin/env python3
"""claude_finto.py -- un claude finto per le prove di tools/prove_skill.sh.

La suite lo copia, con il nome «claude», davanti nel PATH: così lo strumento
gira per intero senza chiamare il modello e senza consumare il piano. Lo stream
che scrive ha la forma di quello di `claude -p --output-format stream-json
--verbose`, ma è inventato: nessuna riga è una risposta di Claude.

Gli argomenti: le opzioni di handson::claude_p e di prove_skill.sh, poi «--» e
il prompt. Un'opzione che non conosce la rifiuta («error: unknown option»,
uscita 1), come uno stream-json senza --verbose. «--version» stampa una
versione finta.

Ogni invocazione aggiunge a FINTO_LOG (obbligatorio, tranne --version) una riga
JSON, scritta in una sola volta: argv, cwd, prompt, chiave (ANTHROPIC_API_KEY
era nell'ambiente?), stdin_nullo (lo STDIN è /dev/null?), le skill che vede in
.claude/skills, se c'è un evals/ dentro una skill, se c'è un *-workspace nella
cartella, se ci sono
.claude/settings.json e .claude/settings.local.json, il branch git, i file di
`git log --all --name-only`; poi, con FINTO_PAUSA, una riga all'inizio e una
alla fine, per misurare quante esecuzioni girano insieme.

Che cosa risponde lo decide il prompt:
  CHIAMA           se in .claude/skills c'è una skill, un tool_use Skill su di
                   lei, e il risultato dice il primo «VERSIONE-…» del suo
                   SKILL.md
  SCRIVI           scrive nuovo.txt nella cartella corrente
  ERRORE-RISULTATO un risultato con is_error, uscita 0
  altrimenti       una risposta senza skill

L'ambiente:
  FINTO_LOG            il registro delle invocazioni
  FINTO_PAUSA          secondi da aspettare prima di rispondere
  FINTO_BREVE_SU       una parola: se è nel prompt, mezzo secondo soltanto
  FINTO_KO_SU          una parola: se è nel prompt esce 1 senza un risultato
  FINTO_CHIAMA_SEMPRE  una skill: un tool_use Skill su di lei, in ogni caso
  FINTO_RIGA_ROTTA     1 = una riga che non è JSON nello stream
  FINTO_NEGA_SKILL     1 = la chiamata Skill di CHIAMA è negata dal permesso:
                       nel tool_use e nei permission_denials, con lo stesso id,
                       e il corpo non arriva (la forma degli stream veri)

Uscita: 0 risposta · 1 FINTO_KO_SU o un argomento rifiutato
"""
import json
import os
import re
import subprocess
import sys
import time

# Le opzioni ammesse e quanti valori prendono.
OPZIONI = {"-p": 0, "--allowedTools": 1, "--model": 1, "--permission-mode": 1,
           "--permission-prompts": 1, "--output-format": 1, "--verbose": 0,
           "--setting-sources": 1, "--effort": 1, "--strict-mcp-config": 0,
           "--no-session-persistence": 0}


def leggi_argomenti(argv):
    """Le opzioni e il prompt; None se un argomento non va."""
    opzioni = {}
    i = 0
    while i < len(argv):
        arg = argv[i]
        if arg == "--":
            return opzioni, argv[i + 1]
        if arg not in OPZIONI:
            print(f"error: unknown option '{arg}'", file=sys.stderr)
            return None
        quanti = OPZIONI[arg]
        opzioni[arg] = argv[i + 1] if quanti else True
        i += 1 + quanti
    print("error: nessun prompt dopo --", file=sys.stderr)
    return None


def skill_viste():
    base = os.path.join(".claude", "skills")
    if not os.path.isdir(base):
        return []
    return sorted(nome for nome in os.listdir(base)
                  if os.path.isdir(os.path.join(base, nome)))


def git(*argomenti):
    fatto = subprocess.run(("git",) + argomenti, stdout=subprocess.PIPE,
                           stderr=subprocess.DEVNULL, check=False,
                           universal_newlines=True)
    return fatto.stdout.strip()


def annota(riga):
    """Una riga del registro, in una sola scrittura: più finti insieme."""
    dati = (json.dumps(riga, ensure_ascii=False) + "\n").encode("utf-8")
    fd = os.open(os.environ["FINTO_LOG"],
                 os.O_WRONLY | os.O_APPEND | os.O_CREAT, 0o600)
    try:
        os.write(fd, dati)
    finally:
        os.close(fd)


def fotografa(prompt):
    skill = skill_viste()
    return {
        "argv": sys.argv[1:],
        "pid": os.getpid(),
        "cwd": os.getcwd(),
        "prompt": prompt,
        "chiave": "ANTHROPIC_API_KEY" in os.environ,
        "stdin_nullo": os.path.samestat(os.fstat(0), os.stat(os.devnull)),
        "skill": skill,
        "evals": any(os.path.isdir(os.path.join(".claude", "skills", s,
                                                "evals")) for s in skill),
        "workspace": any(nome.endswith("-workspace")
                         for nome in os.listdir(".")),
        "settings": os.path.isfile(".claude/settings.json"),
        "settings_local": os.path.isfile(".claude/settings.local.json"),
        "branch": git("rev-parse", "--abbrev-ref", "HEAD"),
        "git_log": git("log", "--all", "--name-only", "--format=").split("\n"),
    }


def versione_di(nome):
    try:
        with open(os.path.join(".claude", "skills", nome, "SKILL.md"),
                  encoding="utf-8") as fh:
            trovata = re.search(r"VERSIONE-\S+", fh.read())
    except OSError:
        return "nessuna"
    return trovata.group(0) if trovata else "nessuna"


def chiamata_skill(nome):
    return {"type": "assistant", "parent_tool_use_id": None, "message": {
        "role": "assistant", "content": [
            {"type": "tool_use", "id": f"toolu_finto_{nome}", "name": "Skill",
             "input": {"skill": nome}}]}}


def stream(prompt):
    """Le righe dello stream finto, in ordine."""
    skill = skill_viste()
    righe = [{"type": "system", "subtype": "init", "cwd": os.getcwd(),
              "session_id": "sessione-finta",
              "skills": skill + ["code-review"]}]
    sempre = os.environ.get("FINTO_CHIAMA_SEMPRE")
    if sempre:
        righe.append(chiamata_skill(sempre))
    testo = "FINTO: risposta senza skill"
    turni = 1
    negati = []
    if "CHIAMA" in prompt and skill:
        righe.append(chiamata_skill(skill[0]))
        if os.environ.get("FINTO_NEGA_SKILL") == "1":
            negati.append({"tool_name": "Skill",
                           "tool_use_id": f"toolu_finto_{skill[0]}",
                           "tool_input": {"skill": skill[0]}})
            testo = "FINTO: non sono riuscito a usare la skill"
        else:
            righe.append({"type": "user", "message": {
                "role": "user", "content": [
                    {"type": "tool_result",
                     "tool_use_id": f"toolu_finto_{skill[0]}",
                     "content": f"Launching skill: {skill[0]}"}]}})
            testo = f"FINTO: risposta con {versione_di(skill[0])}"
            turni = 3
    righe.append({"type": "assistant", "parent_tool_use_id": None, "message": {
        "role": "assistant", "content": [{"type": "text", "text": testo}]}})
    errore = "ERRORE-RISULTATO" in prompt
    righe.append({"type": "result", "subtype": "success", "is_error": errore,
                  "num_turns": turni, "duration_ms": 1000 * turni,
                  "result": testo, "session_id": "sessione-finta",
                  "permission_denials": negati,
                  "usage": {"input_tokens": 10 * turni,
                            "cache_creation_input_tokens": 20,
                            "cache_read_input_tokens": 30,
                            "output_tokens": 40}})
    return righe


def main(argv):
    if argv == ["--version"]:
        print("9.9.9 (Claude Code finto)")
        return 0
    letti = leggi_argomenti(argv)
    if letti is None:
        return 1
    opzioni, prompt = letti
    if opzioni.get("--output-format") != "stream-json" \
            or "--verbose" not in opzioni:
        print("error: serve stream-json con --verbose", file=sys.stderr)
        return 1
    annota(dict(fotografa(prompt), evento="inizio", ora=time.time()))
    pausa = float(os.environ.get("FINTO_PAUSA", "0"))
    breve = os.environ.get("FINTO_BREVE_SU")
    if breve and breve in prompt:
        pausa = 0.5
    if pausa:
        time.sleep(pausa)
    annota({"evento": "fine", "ora": time.time(), "cwd": os.getcwd()})
    parola = os.environ.get("FINTO_KO_SU")
    if parola and parola in prompt:
        print("errore finto: esecuzione fallita", file=sys.stderr)
        return 1
    if "SCRIVI" in prompt:
        with open("nuovo.txt", "w", encoding="utf-8") as fh:
            fh.write("scritto dal claude finto\n")
    if os.environ.get("FINTO_RIGA_ROTTA") == "1":
        print("{questa riga non è JSON")
    for riga in stream(prompt):
        print(json.dumps(riga, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    sys.exit(main(sys.argv[1:]))
