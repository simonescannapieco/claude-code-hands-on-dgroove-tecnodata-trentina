#!/usr/bin/env python3
"""claude_finto_m6_lab.py -- un claude finto per le prove del laboratorio del
Modulo 6 (M6-E02, M6-E03) e di _docente/lib_lab_m6.sh, per il docente.

La suite lo copia, con il nome «claude», davanti nel PATH: così
tools/prova_contesto.sh e _docente/live.sh girano per intero senza chiamare il
modello e senza consumare il piano. Lo stream ha la forma di quello di
`claude -p --output-format stream-json --verbose`, ma è inventato: nessuna
riga è una risposta di Claude, ogni testo comincia con «FINTO», e i risultati
dei comandi (il riepilogo di PHPUnit, quelli di genera.py) sono scritti qui,
senza eseguire niente.

Gli argomenti: le opzioni di handson::claude_p, di prova_contesto.sh e
--resume, poi «--» e il prompt. Un'opzione che non conosce la rifiuta (uscita
1). «--version» stampa una versione finta. Un --resume con un ID che non ha
dato esce 1.

Che cosa fa lo decidono le opzioni e il prompt:
  con --tools, una prova di prova_contesto.sh: fa scattare l'hook vero dello
    spazio di lavoro per i file che si caricherebbero all'avvio (il CLAUDE.md e
    il CLAUDE.local.md della radice, le regole senza «paths:»), poi risponde
    alla richiesta secondo il progetto della copia e il CLAUDE.md che c'è:
    t1/r1 un comando inventato, con il riepilogo se il CLAUDE.md nomina il
    comando giusto; t2/r2 corregge il refuso e fa un commit, con la forma e la
    riga «Rif:» se il CLAUDE.md le dice; t3/r3 cinque righe;
  «/init», la bozza: scrive CLAUDE.md alla radice;
  con «<role>», il prompt 1: riscrive CLAUDE.md con le righe della v1;
  con «<verification_result>», il seguito: cerca nel prompt bozza/rules/ e
    bozza/settings.json; sotto .claude/ rifiuta, come il claude vero (un
    tool_use Write e la sua voce in permission_denials, il file non cambia);
    in bozza/ scrive la regola con «paths:», aggiunge le regole deny al
    settings.json, l'hook com'era, e una riga al CLAUDE.md.

Ogni invocazione aggiunge a FINTO_LOG (obbligatorio, tranne --version) una riga
JSON, in una sola scrittura: argv, cwd, prompt, chiave (ANTHROPIC_API_KEY era
nell'ambiente?), memoria (CLAUDE_CODE_DISABLE_AUTO_MEMORY), progetto, file
(i file di istruzioni che vede), bozza, appunti e vendor (la cartella o il
file c'è?), refuso (il refuso è nel suo file?).

L'ambiente:
  FINTO_LOG           il registro delle invocazioni
  FINTO_KO_SU         una parola: se è nel prompt esce 1 senza un risultato
  FINTO_ERRORE_SU     una parola: se è nel prompt, un risultato con is_error
  FINTO_CARICA_SEMPRE 1 = l'hook registra un CLAUDE.md anche se non c'è
  FINTO_NON_CARICA    1 = l'hook non scatta mai
  FINTO_SENZA_INIT    1 = /init non scrive CLAUDE.md
  FINTO_NON_CAMBIA    1 = il prompt 1 non cambia il CLAUDE.md
  FINTO_TOGLIE_HOOK   1 = il seguito toglie l'hook da settings.json
  FINTO_SEGUITO_NULLO 1 = il seguito non cambia niente
  FINTO_TOCCA_ANCHE   un file, relativo alla copia: la correzione del
                      refuso lo cambia e lo mette nello stesso commit

Uscita: 0 risposta · 1 FINTO_KO_SU, un argomento rifiutato o un --resume ignoto
"""
import json
import os
import subprocess
import sys
import uuid

OPZIONI = {"-p": 0, "--allowedTools": 1, "--model": 1, "--permission-mode": 1,
           "--permission-prompts": 1, "--output-format": 1, "--verbose": 0,
           "--setting-sources": 1, "--effort": 1, "--strict-mcp-config": 0,
           "--no-session-persistence": 0, "--tools": 1,
           "--disallowedTools": 1, "--resume": 1}
GESTIONALE = "progetti/gestionale-php"
RETE = "progetti/rete"
REFUSI = {
    GESTIONALE: (GESTIONALE + "/bin/fatturazione-mensile.php",
                 "Fatturazione non eseguta", "Fatturazione non eseguita"),
    RETE: (RETE + "/checklist-audit.md", "sono disativati",
           "sono disattivati"),
}
V1 = {
    GESTIONALE: ["# Gestionale (FINTO)", "",
                 "- Test: `cd progetti/gestionale-php && "
                 "../../tools/php.sh phpunit`",
                 "- Commit: `tipo(ambito): descrizione`, poi `Rif: GES-0`."],
    RETE: ["# Rete (FINTO)", "",
           "- A posto: `python3 progetti/rete/genera.py --check` e "
           "`--canone`.",
           "- Commit: `rete(<ambito>): <descrizione>`, poi `Rif: NOC-0`."],
}
REGOLE = {
    GESTIONALE: ("legacy.md", "progetti/gestionale-php/legacy/**",
                 ["Edit(/progetti/gestionale-php/database/dati/**)",
                  "Edit(/progetti/gestionale-php/composer.lock)"]),
    RETE: ("generatore.md", "progetti/rete/generatore/**",
           ["Edit(/progetti/rete/configurazioni/**)",
            "Edit(/progetti/rete/log/**)"]),
}


def leggi_argomenti(argv):
    """Le opzioni e il prompt; None se un argomento non va."""
    opzioni, i = {}, 0
    while i < len(argv):
        arg = argv[i]
        if arg == "--":
            return opzioni, " ".join(argv[i + 1:])
        if arg not in OPZIONI:
            print(f"error: unknown option '{arg}'", file=sys.stderr)
            return None
        quanti = OPZIONI[arg]
        opzioni[arg] = argv[i + 1] if quanti else True
        i += 1 + quanti
    print("error: nessun prompt dopo --", file=sys.stderr)
    return None


def annota(riga):
    """Una riga del registro, in una sola scrittura: più finti insieme."""
    dati = (json.dumps(riga, ensure_ascii=False) + "\n").encode("utf-8")
    fd = os.open(os.environ["FINTO_LOG"],
                 os.O_WRONLY | os.O_APPEND | os.O_CREAT, 0o600)
    try:
        os.write(fd, dati)
    finally:
        os.close(fd)


def progetto():
    for nome in (GESTIONALE, RETE):
        if os.path.isdir(nome):
            return nome
    return None


def testo_di(percorso):
    try:
        with open(percorso, encoding="utf-8") as fh:
            return fh.read()
    except OSError:
        return ""


def scrivi(percorso, testo):
    cartella = os.path.dirname(percorso)
    if cartella:
        os.makedirs(cartella, exist_ok=True)
    with open(percorso, "w", encoding="utf-8") as fh:
        fh.write(testo)


def istruzioni_viste():
    visti = [n for n in ("CLAUDE.md", "CLAUDE.local.md") if os.path.isfile(n)]
    regole = os.path.join(".claude", "rules")
    if os.path.isdir(regole):
        visti += sorted(os.path.join(regole, n) for n in os.listdir(regole))
    return visti


def caricamenti():
    """Fa scattare l'hook vero per ciò che si caricherebbe all'avvio."""
    if os.environ.get("FINTO_NON_CARICA") == "1":
        return
    hook = os.path.join(".claude", "hooks", "registra_caricamenti.py")
    if not os.path.isfile(hook):
        return
    nomi = [n for n in ("CLAUDE.md", "CLAUDE.local.md") if os.path.isfile(n)]
    if os.environ.get("FINTO_CARICA_SEMPRE") == "1" and "CLAUDE.md" not in nomi:
        nomi.append("CLAUDE.md")
    regole = os.path.join(".claude", "rules")
    if os.path.isdir(regole):
        for nome in sorted(os.listdir(regole)):
            if "paths:" not in testo_di(os.path.join(regole, nome)):
                nomi.append(os.path.join(regole, nome))
    for nome in nomi:
        evento = {"hook_event_name": "InstructionsLoaded",
                  "load_reason": "session_start",
                  "file_path": os.path.abspath(nome),
                  "memory_type": "Project", "cwd": os.getcwd()}
        subprocess.run([sys.executable, "-B", "-I", hook],
                       input=json.dumps(evento), universal_newlines=True,
                       check=True,
                       env=dict(os.environ, CLAUDE_PROJECT_DIR=os.getcwd()))


class Stream:
    """Le righe di uno stream inventato, con gli id degli strumenti."""

    def __init__(self, sessione):
        self.sessione = sessione
        self.righe = [{"type": "system", "subtype": "init", "model": "finto",
                       "session_id": sessione}]
        self.negati = []
        self.n = 0

    def _usage(self):
        return {"input_tokens": 3, "cache_creation_input_tokens": 1000,
                "cache_read_input_tokens": 0, "output_tokens": 10}

    def comando(self, comando, uscita, nome="Bash"):
        self.n += 1
        ident = f"toolu_finto_{self.n}"
        self.righe.append({"type": "assistant", "parent_tool_use_id": None,
                           "message": {"usage": self._usage(), "content": [
                               {"type": "tool_use", "id": ident,
                                "name": nome, "input": comando}]}})
        self.righe.append({"type": "user", "message": {"content": [
            {"type": "tool_result", "tool_use_id": ident,
             "content": uscita}]}})
        return ident

    def negato(self, nome, ingresso):
        ident = self.comando(ingresso, "permesso negato", nome)
        self.negati.append({"tool_name": nome, "tool_use_id": ident,
                            "tool_input": ingresso})

    def fine(self, testo, errore=False, token=1013):
        self.righe.append({"type": "assistant", "parent_tool_use_id": None,
                           "message": {"usage": self._usage(), "content": [
                               {"type": "text", "text": testo}]}})
        self.righe.append({
            "type": "result", "subtype": "success", "is_error": errore,
            "num_turns": self.n + 1, "duration_ms": 1000 * (self.n + 1),
            "result": testo, "session_id": self.sessione,
            "permission_denials": self.negati,
            "usage": {"input_tokens": 3, "cache_creation_input_tokens": 0,
                      "cache_read_input_tokens": 0, "output_tokens": 10},
            "modelUsage": {"finto": {"inputTokens": token,
                                     "outputTokens": 0,
                                     "cacheReadInputTokens": 0,
                                     "cacheCreationInputTokens": 0}}})

    def stampa(self):
        for riga in self.righe:
            print(json.dumps(riga, ensure_ascii=False))


def git(*argomenti):
    subprocess.run(("git",) + argomenti, check=True, stdout=subprocess.PIPE,
                   stderr=subprocess.PIPE)


def correggi(stream, nome):
    """Corregge il refuso e fa un commit, con la forma del CLAUDE.md."""
    file, sbagliato, giusto = REFUSI[nome]
    scrivi(file, testo_di(file).replace(sbagliato, giusto, 1))
    stream.comando({"file_path": file, "old_string": sbagliato,
                    "new_string": giusto}, "ok", "Edit")
    file_in_piu = os.environ.get("FINTO_TOCCA_ANCHE")
    aggiunti = [file]
    if file_in_piu:
        scrivi(file_in_piu, testo_di(file_in_piu) + "FINTO\n")
        aggiunti.append(file_in_piu)
    istruzioni = testo_di("CLAUDE.md")
    if "Rif: GES-0" in istruzioni:
        messaggio = "fix(fatturazione): corregge il refuso\n\nRif: GES-0"
    elif "Rif: NOC-0" in istruzioni:
        messaggio = "rete(audit): corregge il refuso di AUD-02\n\nRif: NOC-0"
    else:
        messaggio = "Corregge il refuso"
    git("add", "--", *aggiunti)
    git("commit", "-q", "-m", messaggio)
    stream.comando({"command": f"git commit -m '{messaggio}'"}, "fatto")
    return "FINTO: corretto, e fatto il commit."


def prova(stream, prompt, nome):
    """Una richiesta di prova_contesto.sh: il testo finale."""
    istruzioni = testo_di("CLAUDE.md")
    if "refuso" in prompt:
        return correggi(stream, nome)
    if "Rispondi in cinque righe" in prompt:
        return "FINTO\nuna\ndue\ntre\nquattro"
    if nome == GESTIONALE:
        if "php.sh phpunit" in istruzioni:
            stream.comando({"command": "cd progetti/gestionale-php && "
                                       "../../tools/php.sh phpunit"},
                           "\x1b[30;42mOK (44 tests, 107 assertions)\x1b[0m")
            return "FINTO: 44 passano, 0 falliscono."
        stream.comando({"command": "which php composer"}, "")
        return "FINTO: non trovo come eseguire i test."
    stream.comando({"command": "python3 progetti/rete/genera.py --check"},
                   "genera.py --check: 65 file identici")
    if "--canone" in istruzioni:
        stream.comando({"command": "python3 progetti/rete/genera.py "
                                   "--canone"},
                       "genera.py --canone: 83 file conformi")
        return "FINTO: --check 65 file identici; --canone 83 file conformi."
    return "FINTO: --check dice 65 file identici."


def seguito(stream, prompt, nome):
    """Il prompt 2: la regola, le regole deny e una riga, nella bozza."""
    if ".claude/rules/" in prompt or ".claude/settings.json" in prompt:
        stream.negato("Write", {"file_path": ".claude/rules/x.md"})
        return "FINTO: non ho potuto scrivere in .claude/."
    if os.environ.get("FINTO_SEGUITO_NULLO") == "1":
        return "FINTO: niente da cambiare."
    regola, globo, negate = REGOLE[nome]
    scrivi(os.path.join("bozza", "rules", regola),
           f'---\npaths:\n  - "{globo}"\n---\n\n# FINTO\n\n- Una regola.\n')
    impostazioni = json.loads(testo_di(os.path.join("bozza",
                                                    "settings.json")))
    impostazioni.setdefault("permissions", {}).setdefault("deny", [])
    impostazioni["permissions"]["deny"] += negate
    if os.environ.get("FINTO_TOGLIE_HOOK") == "1":
        impostazioni.pop("hooks", None)
    scrivi(os.path.join("bozza", "settings.json"),
           json.dumps(impostazioni, indent=2) + "\n")
    scrivi("CLAUDE.md", testo_di("CLAUDE.md") + "- Una riga del seguito.\n")
    stream.comando({"file_path": "bozza/rules/" + regola}, "ok", "Write")
    return "FINTO: la regola, le regole deny e una riga."


def scrittura(stream, prompt, nome):
    """/init, il prompt 1 o il seguito: il testo finale."""
    if prompt.strip() == "/init":
        if os.environ.get("FINTO_SENZA_INIT") != "1":
            scrivi("CLAUDE.md", "# Bozza di /init (FINTO)\n\n- Una riga.\n")
        return "FINTO: la bozza."
    if "<verification_result>" in prompt:
        return seguito(stream, prompt, nome)
    if "<role>" in prompt and os.environ.get("FINTO_NON_CAMBIA") != "1":
        scrivi("CLAUDE.md", "\n".join(V1[nome]) + "\n")
    return "FINTO: la prima versione."


def sessione_per(opzioni, registro):
    """L'ID di sessione: uno nuovo, o quello di --resume se l'ha dato."""
    if "--resume" not in opzioni:
        sessione = f"sessione-finta-{uuid.uuid4().hex[:8]}"
        if "--no-session-persistence" not in opzioni:
            with open(registro, "a", encoding="utf-8") as fh:
                fh.write(sessione + "\n")
        return sessione
    note = testo_di(registro).split()
    return opzioni["--resume"] if opzioni["--resume"] in note else None


def main(argv):
    if argv == ["--version"]:
        print("9.9.9 (finto)")
        return 0
    letti = leggi_argomenti(argv)
    if letti is None:
        return 1
    opzioni, prompt = letti
    nome = progetto()
    annota({"argv": argv, "cwd": os.getcwd(), "prompt": prompt,
            "chiave": "ANTHROPIC_API_KEY" in os.environ,
            "memoria": os.environ.get("CLAUDE_CODE_DISABLE_AUTO_MEMORY"),
            "progetto": nome, "file": istruzioni_viste(),
            "bozza": os.path.isdir("bozza"),
            "appunti": os.path.exists("appunti-del-team.md"),
            "vendor": os.path.exists(os.path.join(GESTIONALE, "vendor")),
            "refuso": bool(nome) and REFUSI[nome][1] in testo_di(
                REFUSI[nome][0])})
    sessione = sessione_per(opzioni, os.environ["FINTO_LOG"] + ".sessioni")
    if sessione is None or nome is None:
        print("error: sessione ignota o progetto assente", file=sys.stderr)
        return 1
    ko = os.environ.get("FINTO_KO_SU")
    if ko and ko in prompt:
        return 1
    stream = Stream(sessione)
    if "--tools" in opzioni:
        caricamenti()
        testo = prova(stream, prompt, nome)
    else:
        testo = scrittura(stream, prompt, nome)
    errore = os.environ.get("FINTO_ERRORE_SU")
    stream.fine(testo, errore=bool(errore and errore in prompt))
    stream.stampa()
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
