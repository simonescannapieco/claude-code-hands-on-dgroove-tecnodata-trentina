#!/usr/bin/env python3
"""claude_finto_m5_e02.py -- un claude finto per le prove di M5-E02 e di
lib_lab_m5.sh, per il docente.

La suite lo copia, con il nome «claude», davanti nel PATH: così tools/
prove_skill.sh e _docente/live.sh girano per intero senza chiamare il modello
e senza consumare il piano. Lo stream ha la forma di quello di `claude -p
--output-format stream-json --verbose`, ma è inventato: nessuna riga è una
risposta di Claude, e ogni testo comincia con «FINTO».

Gli argomenti: le opzioni di handson::claude_p e --resume, poi «--» e il
prompt. Un'opzione che non conosce la rifiuta (uscita 1). «--version» stampa
una versione finta. Un --resume con un ID che non ha dato esce 1.

Che cosa fa lo decide il prompt:
  con «<instructions>», la scrittura di una skill. Trova nel prompt il percorso
    .claude/skills/<skill> o bozza/<skill>. Sotto .claude/ rifiuta, come il
    claude vero: un tool_use Write e la sua voce in permission_denials, il file
    non cambia. Altrove aggiunge una riga al SKILL.md, diversa a ogni chiamata.
  altrimenti, una prova, sul branch della cartella corrente. Con una skill in
    .claude/skills/ e una richiesta che non è la near-miss chiama Skill e scrive
    una revisione dalla chiave di FINTO_CHIAVE (le righe del branch); senza
    skill, una revisione generica, senza numeri di regola.

Ogni invocazione aggiunge a FINTO_LOG (obbligatorio, tranne --version) una riga
JSON, in una sola scrittura: argv, cwd, prompt, chiave (ANTHROPIC_API_KEY era
nell'ambiente?), skill (quelle che vede), evals, workspace, bozza (le cartelle
che vede), branch, soggetto (dell'ultimo commit).

L'ambiente:
  FINTO_LOG            il registro delle invocazioni
  FINTO_CHIAVE         _docente/chiave_pr.tsv: le regole di ogni branch
  FINTO_OMETTI         una regola che la revisione non cita
  FINTO_SENZA_RIGA     una regola citata senza il file e la riga
  FINTO_SENZA_ESITO    1 = la revisione non chiude con un esito
  FINTO_SCRIVI         1 = una prova scrive nuovo.txt
  FINTO_NON_CHIAMA     1 = nessuna chiamata Skill, anche con la skill
  FINTO_NEGA_SKILL     1 = la chiamata Skill è negata dal permesso
  FINTO_CHIAMA_SEMPRE  una skill: un tool_use Skill su di lei, in ogni prova
  FINTO_ELENCA         una skill: in system/init anche se non c'è
  FINTO_SENZA_INIT     1 = lo stream non ha system/init
  FINTO_RIGA_ROTTA     1 = una riga che non è JSON nello stream
  FINTO_KO_SU          una parola: se è nel prompt esce 1 senza un risultato
  FINTO_ERRORE_SU      una parola: se è nel prompt, un risultato con is_error
  FINTO_DUE_SEGMENTI   1 = due eventi result
  FINTO_SENZA_SESSIONE 1 = i risultati senza session_id
  FINTO_NON_CAMBIA     1 = la scrittura con --resume non cambia il SKILL.md
  FINTO_TOCCA_EVALS    1 = la scrittura cambia <percorso>/evals/evals.json
  FINTO_NUOVO_FILE     la scrittura crea questo file, relativo al percorso
  FINTO_TOGLIE_FILE    la scrittura cancella questo file, relativo al percorso
  FINTO_TOGLIE_SKILL   1 = la scrittura cancella il SKILL.md

Uscita: 0 risposta · 1 FINTO_KO_SU, un argomento rifiutato o un --resume ignoto
"""
import csv
import json
import os
import re
import subprocess
import sys
import uuid

# Le opzioni ammesse e quanti valori prendono.
OPZIONI = {"-p": 0, "--allowedTools": 1, "--model": 1, "--permission-mode": 1,
           "--permission-prompts": 1, "--output-format": 1, "--verbose": 0,
           "--setting-sources": 1, "--effort": 1, "--strict-mcp-config": 0,
           "--no-session-persistence": 0, "--resume": 1}
RE_PERCORSO = re.compile(r"(\.claude/skills/[a-z0-9-]+|bozza/[a-z0-9-]+)")
NEAR_MISS = "messaggio di commit"
PROGETTO = "progetti/gestionale-php/"


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


def skill_con_file():
    """Le skill che hanno davvero un SKILL.md."""
    return [nome for nome in skill_viste()
            if os.path.isfile(os.path.join(".claude", "skills", nome,
                                           "SKILL.md"))]


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
        "cwd": os.getcwd(),
        "prompt": prompt,
        "chiave": "ANTHROPIC_API_KEY" in os.environ,
        "skill": skill,
        "evals": any(os.path.isdir(os.path.join(".claude", "skills", s,
                                                "evals")) for s in skill),
        "workspace": any(nome.endswith("-workspace")
                         for nome in os.listdir(".")),
        "bozza": os.path.exists("bozza"),
        "branch": git("rev-parse", "--abbrev-ref", "HEAD"),
        "soggetto": git("log", "-1", "--format=%s"),
    }


def risultato(testo, turni, sessione, negati, errore):
    riga = {"type": "result", "subtype": "success", "is_error": errore,
            "num_turns": turni, "duration_ms": 1000 * turni, "result": testo,
            "permission_denials": negati,
            "usage": {"input_tokens": 10 * turni,
                      "cache_creation_input_tokens": 20,
                      "cache_read_input_tokens": 30, "output_tokens": 40}}
    if os.environ.get("FINTO_SENZA_SESSIONE") != "1":
        riga["session_id"] = sessione
    return riga


def assistente(blocco):
    return {"type": "assistant", "parent_tool_use_id": None, "message": {
        "role": "assistant", "content": [blocco]}}


def chiamata_skill(nome):
    return assistente({"type": "tool_use", "id": f"toolu_finto_{nome}",
                       "name": "Skill", "input": {"skill": nome}})


def corpo_della_skill(nome):
    """Il tool_result e il messaggio sintetico, come negli stream veri."""
    return [{"type": "user", "message": {"role": "user", "content": [
        {"type": "tool_result", "tool_use_id": f"toolu_finto_{nome}",
         "content": f"Launching skill: {nome}"}]}},
            {"type": "user", "isSynthetic": True, "message": {
                "role": "user", "content": [
                    {"type": "text",
                     "text": "Base directory for this skill: (finta)"}]}}]


def righe_della_chiave(pr):
    percorso = os.environ.get("FINTO_CHIAVE")
    if not percorso:
        return []
    with open(percorso, encoding="utf-8", newline="") as fh:
        righe = [r for r in fh if r.strip() and not r.startswith("#")]
    return [r for r in csv.DictReader(righe, delimiter="\t")
            if r["pr"] == pr]


def revisione(branch):
    """La revisione finta del branch, dalla chiave: una riga per regola."""
    pr = branch[len("pr-"):] if branch.startswith("pr-") else ""
    tabella = ["FINTO: revisione di prova, non una risposta di Claude.", "",
               "| regola | file | riga | che cosa non va |", "|---|---|---|---|"]
    for riga in righe_della_chiave(pr):
        if riga["regola"] == os.environ.get("FINTO_OMETTI"):
            continue
        posto = f"{PROGETTO}{riga['file']} | {riga['riga']}"
        if riga["file"] == "-" \
                or riga["regola"] == os.environ.get("FINTO_SENZA_RIGA"):
            posto = "- | -"
        tabella.append(f"| {riga['regola']} | {posto} | FINTO |")
    if os.environ.get("FINTO_SENZA_ESITO") != "1":
        tabella += ["", "Esito: da modificare"]
    return "\n".join(tabella)


def stream_prova(prompt, sessione, testo_generico):
    """Le righe dello stream di una prova, in ordine."""
    skill = skill_con_file()
    elencate = skill + ["code-review"]
    if os.environ.get("FINTO_ELENCA"):
        elencate.append(os.environ["FINTO_ELENCA"])
    righe = []
    if os.environ.get("FINTO_SENZA_INIT") != "1":
        righe.append({"type": "system", "subtype": "init", "cwd": os.getcwd(),
                      "session_id": sessione, "skills": elencate})
    sempre = os.environ.get("FINTO_CHIAMA_SEMPRE")
    if sempre:
        righe.append(chiamata_skill(sempre))
    testo = testo_generico
    turni = 2
    negati = []
    naturale = skill and NEAR_MISS not in prompt \
        and os.environ.get("FINTO_NON_CHIAMA") != "1"
    if naturale:
        righe.append(chiamata_skill(skill[0]))
        if os.environ.get("FINTO_NEGA_SKILL") == "1":
            negati.append({"tool_name": "Skill",
                           "tool_use_id": f"toolu_finto_{skill[0]}",
                           "tool_input": {"skill": skill[0]}})
            testo = "FINTO: non sono riuscito a usare la skill"
        else:
            righe += corpo_della_skill(skill[0])
            testo = revisione(git("rev-parse", "--abbrev-ref", "HEAD"))
            turni = 4
    righe.append(assistente({"type": "text", "text": testo}))
    errore = bool(os.environ.get("FINTO_ERRORE_SU")) \
        and os.environ["FINTO_ERRORE_SU"] in prompt
    righe.append(risultato(testo, turni, sessione, negati, errore))
    return righe


def scrivi_nella_bozza(percorso, ripresa):
    """Che cosa fa la scrittura fuori da .claude/: nella cartella del prompt."""
    skill_md = os.path.join(percorso, "SKILL.md")
    if os.environ.get("FINTO_TOGLIE_SKILL") == "1":
        os.remove(skill_md)
        return
    if not (ripresa and os.environ.get("FINTO_NON_CAMBIA") == "1"):
        with open(skill_md, "a", encoding="utf-8") as fh:
            fh.write(f"\nRiga di prova del finto: {uuid.uuid4().hex}\n")
    if os.environ.get("FINTO_TOCCA_EVALS") == "1":
        with open(os.path.join(percorso, "evals", "evals.json"), "w",
                  encoding="utf-8") as fh:
            fh.write("{}\n")
    nuovo = os.environ.get("FINTO_NUOVO_FILE")
    if nuovo:
        pieno = os.path.join(percorso, nuovo)
        os.makedirs(os.path.dirname(pieno), exist_ok=True)
        with open(pieno, "w", encoding="utf-8") as fh:
            fh.write("file di prova del finto\n")
    togli = os.environ.get("FINTO_TOGLIE_FILE")
    if togli and os.path.exists(os.path.join(percorso, togli)):
        os.remove(os.path.join(percorso, togli))


def stream_scrittura(prompt, sessione, ripresa):
    """Le righe dello stream di una scrittura, in ordine."""
    trovato = RE_PERCORSO.search(prompt)
    percorso = trovato.group(1) if trovato else ""
    righe = [{"type": "system", "subtype": "init", "cwd": os.getcwd(),
              "session_id": sessione, "skills": skill_con_file()}]
    uso = assistente({"type": "tool_use", "id": "toolu_finto_write",
                      "name": "Write",
                      "input": {"file_path": f"{percorso}/SKILL.md"}})
    righe.append(uso)
    negati = []
    testo = "FINTO: ho cambiato la skill."
    if not percorso or percorso.startswith(".claude/"):
        negati.append({"tool_name": "Write",
                       "tool_use_id": "toolu_finto_write",
                       "tool_input": {"file_path": f"{percorso}/SKILL.md"}})
        testo = "FINTO: la scrittura sotto .claude/ è negata."
    else:
        scrivi_nella_bozza(percorso, ripresa)
    righe.append(assistente({"type": "text", "text": testo}))
    errore = bool(os.environ.get("FINTO_ERRORE_SU")) \
        and os.environ["FINTO_ERRORE_SU"] in prompt
    if os.environ.get("FINTO_DUE_SEGMENTI") == "1":
        righe.append(risultato(testo, 3, sessione, [], False))
    righe.append(risultato(testo, 5, sessione, negati, errore))
    return righe


def sessione_di(opzioni):
    """L'ID da usare; None se --resume ne nomina uno che non ha dato."""
    registro = os.environ["FINTO_LOG"] + ".sessioni"
    richiesta = opzioni.get("--resume")
    if richiesta is None:
        nuova = f"sessione-finta-{uuid.uuid4().hex}"
        with open(registro, "a", encoding="utf-8") as fh:
            fh.write(nuova + "\n")
        return nuova
    try:
        with open(registro, encoding="utf-8") as fh:
            note = fh.read().split()
    except OSError:
        note = []
    return richiesta if richiesta in note else None


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
    annota(fotografa(prompt))
    sessione = sessione_di(opzioni)
    if sessione is None:
        print("error: No conversation found", file=sys.stderr)
        return 1
    parola = os.environ.get("FINTO_KO_SU")
    if parola and parola in prompt:
        print("errore finto: esecuzione fallita", file=sys.stderr)
        return 1
    if "<instructions>" in prompt:
        righe = stream_scrittura(prompt, sessione, "--resume" in opzioni)
    else:
        if os.environ.get("FINTO_SCRIVI") == "1":
            with open("nuovo.txt", "w", encoding="utf-8") as fh:
                fh.write("scritto dal claude finto\n")
        righe = stream_prova(prompt, sessione,
                             "FINTO: osservazioni generali, senza numeri.")
    if os.environ.get("FINTO_RIGA_ROTTA") == "1":
        print("{questa riga non è JSON")
    for riga in righe:
        print(json.dumps(riga, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    sys.exit(main(sys.argv[1:]))
