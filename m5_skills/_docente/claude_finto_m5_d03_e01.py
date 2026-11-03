#!/usr/bin/env python3
"""claude_finto_m5_d03_e01.py -- un claude finto per le prove di M5-D03 e
M5-E01 (test_m5_d03.sh, test_m5_e01.sh).

Le suite lo copiano, con il nome «claude», davanti nel PATH: così in_classe.sh,
prova.sh e i live.sh girano per intero senza chiamare il modello e senza
consumare il piano. Gli stream che scrive sono inventati e dichiarati finti:
nessuno è una risposta di Claude. Hanno la forma degli stream di `claude -p
--output-format stream-json --verbose` (l'evento system/init, i messaggi
assistant e user, gli eventi system, il risultato), e provano i controlli, non
il modello.

Legge davvero le skill della cartella in cui gira (.claude/skills/<nome>/
SKILL.md) e fa ciò che la documentazione e le prove del corso dicono: un
!`comando` si esegue prima, e l'output prende il suo posto; un comando che non
è di sola lettura, senza una regola, ferma l'invocazione con zero turni;
allowed-tools vale nel turno che invoca la skill; context: fork non vede la
conversazione. Così una skill scritta male, o un braccio scambiato con l'altro,
si vede nei verdetti.

Gli argomenti: le opzioni di OPZIONI, poi «--» e il prompt. Rifiuta («error:
…», uscita 1) un'opzione che non conosce, un --output-format diverso da
stream-json, lo stream-json senza --verbose, un prompt che non conosce.
«--version» stampa una versione finta; «plugin validate <cartella>» risponde
senza chiamare niente.

Ogni invocazione aggiunge a FINTO_LOG, se c'è, una riga JSON: argv, cwd, prompt,
chiave (ANTHROPIC_API_KEY era nell'ambiente?), effort_env
(CLAUDE_CODE_EFFORT_LEVEL?), stdin_nullo, git (la cartella ha .git?), file (che
cosa c'è nella cartella), e, con FINTO_SPAZIO, risposte (c'era
<spazio>/risposte/?) e prova_stream (c'era <spazio>/prova/stream.jsonl?).
Le sessioni salvate stanno in FINTO_SESSIONI (obbligatoria per riprenderle).

Le scene, dal prompt:
  /nome                 la skill di .claude/skills/nome/; /skill-doctor la
                        tabella, zero turni
  Ricorda: la parola …  ricorda e risponde ok
  Esegui di nuovo …     il messaggio dopo: una chiamata Bash a bash conta.sh
  riassunto-modifiche   la richiesta di M5-E01: scrive la skill con Write, ma
                        non in .claude/ in dontAsk (percorso protetto), poi
                        esegue il controllo se gli strumenti lo consentono
  Che cosa ho cambiato? la domanda naturale di M5-E01: chiama la skill Skill

Le variabili per mettere alla prova i controlli (=1 per accendere):
  FINTO_BANG_NON_SOSTITUISCE  il !`comando` non porta il dato
  FINTO_BANG_STRUMENTO        con !`comando` Claude chiama anche uno strumento
  FINTO_DATO_SENZA_STRUMENTI  senza il ! il codice arriva senza strumenti
  FINTO_FERMO_IGNORATO        il comando non consentito gira lo stesso
  FINTO_ALLOWED_IGNORATO      allowed-tools non vale
  FINTO_GRANT_RESTA           il permesso resta al messaggio dopo
  FINTO_NON_RIPROVA           al messaggio dopo Claude non riprova
  FINTO_NON_ESEGUE            la skill chiede di eseguire e Claude non esegue
  FINTO_FORK_VEDE             il subagent vede la parola
  FINTO_FORK_INLINE           context: fork non apre nessun subagent
  FINTO_INLINE_NON_VEDE       senza fork la parola non torna
  FINTO_ALTRA_SESSIONE        --resume apre un'altra sessione
  FINTO_SKILL_ROTTA           M5-E01: scrive una skill senza description
  FINTO_NON_SCRIVE            M5-E01: la richiesta non scrive la skill
  FINTO_BOZZA_ALTRO           M5-E01: lascia un altro file in bozza/
  FINTO_SENZA_CHIAMATA       M5-E01: risponde senza chiamare la skill
  FINTO_NON_NOMINA            M5-E01: la risposta non nomina il file
  FINTO_CON_STRUMENTI         M5-E01: uno strumento prima della risposta
  FINTO_VALIDATE_KO           plugin validate esce con 1
  FINTO_TRONCO                toglie il risultato finale dallo stream
  FINTO_ERRORE                il risultato finale è un errore
  FINTO_ESITO_KO_SE=t         esce 1 senza stampare nulla se il prompt ha t
Uscita: 0 lo stream · 1 FINTO_ESITO_KO_SE, un argomento rifiutato, un prompt che
        il finto non conosce, una sessione da riprendere che non c'è
"""
import datetime
import fnmatch
import json
import os
import re
import subprocess
import sys
import uuid
from typing import Dict, List, NamedTuple, Optional, Tuple

OPZIONI = {"-p": 0, "--print": 0, "--verbose": 0, "--strict-mcp-config": 0,
           "--no-session-persistence": 0, "--model": 1, "--effort": 1,
           "--allowedTools": 1, "--output-format": 1, "--permission-mode": 1,
           "--permission-prompts": 1, "--setting-sources": 1, "--resume": 1}
SOLA_LETTURA = ("cat ", "git status", "git diff", "git log", "wc ", "ls")
RE_INIEZIONE = re.compile(r"!`([^`]+)`")
RE_COMANDO = re.compile(r"(?<![!`])`([^`]+)`")
RE_PAROLA = re.compile(r"la parola in codice è (\S+?)\.")
RE_BERSAGLIO = re.compile(r"(\S*riassunto-modifiche/SKILL\.md)")
RE_CONTROLLO = re.compile(r"python3 -B -I controlla_skill\.py \S+")
NEGATO = ("Permission to use Bash has been denied because Claude Code is "
          "running in don't ask mode. (finto)")
SKILL_E01 = "riassunto-modifiche"
TESTO_SKILL = """---
name: riassunto-modifiche
description: Riassume le modifiche (skill del finto). Da usare quando si chiede
  che cosa è cambiato.
compatibility: Requires Claude Code and git
---

## Le modifiche

!`git status --short`

!`git diff HEAD`

## Istruzioni

1. Riassumi le modifiche qui sopra.
"""
TESTO_SKILL_ROTTA = """---
name: riassunto-modifiche
---

!`git diff HEAD`
"""
TESTO_DOCTOR = ("skill source context 7d tokens uses last used\n"
                "riassunto-modifiche projectSettings < 20 - 0× never (finto)\n"
                "context = this skill's one-line listing (finto)")
USO = {"input_tokens": 2, "cache_creation_input_tokens": 100,
       "cache_read_input_tokens": 17000, "output_tokens": 10}
USO_ZERO = {"input_tokens": 0, "cache_creation_input_tokens": 0,
            "cache_read_input_tokens": 0, "output_tokens": 0}


class Rifiutato(Exception):
    """Argomenti che il finto non accetta: il messaggio d'errore."""


class Stato(NamedTuple):
    """La chiamata: le opzioni, la sessione, gli strumenti consentiti, i
    dinieghi raccolti."""
    opzioni: Dict[str, str]
    sid: str
    consentiti: List[str]
    negati: List[dict]


def acceso(nome: str) -> bool:
    """Vero se la variabile d'ambiente vale 1."""
    return os.environ.get(nome) == "1"


def argomenti(argv: List[str]) -> Tuple[Dict[str, str], str]:
    """(le opzioni con i loro valori, il prompt)."""
    opzioni: Dict[str, str] = {}
    i = 0
    while i < len(argv):
        arg = argv[i]
        if arg == "--":
            if len(argv) != i + 2:
                raise Rifiutato("error: dopo -- un prompt solo")
            return opzioni, argv[i + 1]
        if arg not in OPZIONI:
            raise Rifiutato("error: unknown option '%s'" % arg)
        quanti = OPZIONI[arg]
        if quanti and i + 1 >= len(argv):
            raise Rifiutato("error: option '%s' argument missing" % arg)
        opzioni[arg] = argv[i + 1] if quanti else ""
        i += 1 + quanti
    raise Rifiutato("error: manca il prompt dopo --")


def registra(argv: List[str], prompt: str) -> None:
    """La riga di FINTO_LOG."""
    percorso = os.environ.get("FINTO_LOG")
    if not percorso:
        return
    spazio = os.environ.get("FINTO_SPAZIO")
    riga = {"argv": argv, "cwd": os.getcwd(), "prompt": prompt,
            "chiave": "ANTHROPIC_API_KEY" in os.environ,
            "effort_env": "CLAUDE_CODE_EFFORT_LEVEL" in os.environ,
            "stdin_nullo": os.path.samestat(os.fstat(0),
                                            os.stat(os.devnull)),
            "git": os.path.isdir(".git"), "file": sorted(os.listdir("."))}
    if spazio:
        riga["risposte"] = os.path.exists(os.path.join(spazio, "risposte"))
        riga["prova_stream"] = os.path.exists(
            os.path.join(spazio, "prova", "stream.jsonl"))
    with open(percorso, "a", encoding="utf-8") as fh:
        fh.write(json.dumps(riga, ensure_ascii=False) + "\n")


def ora() -> str:
    return datetime.datetime.now(datetime.timezone.utc).strftime(
        "%Y-%m-%dT%H:%M:%S.000Z")


def emetti(evento: dict) -> None:
    print(json.dumps(evento, ensure_ascii=False))


def assistente(blocchi: List[dict], stato: Stato) -> None:
    emetti({"type": "assistant", "message": {
        "model": "claude-finto", "id": "msg_" + uuid.uuid4().hex[:12],
        "type": "message", "role": "assistant", "content": blocchi,
        "usage": USO}, "parent_tool_use_id": None, "session_id": stato.sid,
            "uuid": str(uuid.uuid4()), "timestamp": ora()})


def utente(contenuto: object, stato: Stato, **altro: object) -> None:
    evento = {"type": "user", "message": {"role": "user",
                                          "content": contenuto},
              "parent_tool_use_id": None, "session_id": stato.sid,
              "uuid": str(uuid.uuid4()), "timestamp": ora()}
    evento.update(altro)
    emetti(evento)


def risultato(testo: str, turni: int, stato: Stato, locale: bool = False,
              uso: Optional[dict] = None) -> None:
    """L'ultimo evento, salvo FINTO_TRONCO."""
    if acceso("FINTO_TRONCO"):
        return
    uso = USO if uso is None else uso
    evento = {"type": "result", "subtype": "success", "is_error": False,
              "duration_ms": 1000, "duration_api_ms": 900, "num_turns": turni,
              "result": testo, "session_id": stato.sid,
              "permission_denials": stato.negati, "usage": uso,
              "total_cost_usd": 0.01, "result_index": 0,
              "modelUsage": {"claude-finto": {
                  "inputTokens": uso["input_tokens"],
                  "outputTokens": uso["output_tokens"],
                  "cacheReadInputTokens": uso["cache_read_input_tokens"],
                  "cacheCreationInputTokens":
                      uso["cache_creation_input_tokens"]}},
              "uuid": str(uuid.uuid4())}
    if locale:
        evento["local_command"] = True
    if acceso("FINTO_ERRORE"):
        evento.update(is_error=True, subtype="error_during_execution")
    emetti(evento)


def leggi_skill(nome: str) -> Optional[Tuple[Dict[str, str], str]]:
    """(i campi del frontmatter, il corpo) di una skill della cartella."""
    percorso = os.path.join(".claude", "skills", nome, "SKILL.md")
    if not os.path.isfile(percorso):
        return None
    with open(percorso, encoding="utf-8") as fh:
        testo = fh.read()
    _, frontmatter, corpo = testo.split("---\n", 2)
    campi = {}
    for riga in frontmatter.splitlines():
        chiave, _, valore = riga.partition(":")
        campi[chiave.strip()] = valore.strip()
    return campi, corpo


def skill_elencate() -> List[str]:
    """Le skill della cartella, come nell'elenco di system/init."""
    base = os.path.join(".claude", "skills")
    propri = sorted(n for n in os.listdir(base)
                    if os.path.isdir(os.path.join(base, n))) \
        if os.path.isdir(base) else []
    return propri + ["code-review", "verify"]


def concesso(comando: str, regole: List[str]) -> bool:
    """Vero se un comando Bash passa: sola lettura, o una regola che lo copre.
    """
    if comando.startswith(SOLA_LETTURA):
        return True
    return any(fnmatch.fnmatchcase("Bash(%s)" % comando, regola)
               for regola in regole)


def esegui(comando: str) -> str:
    """Esegue davvero un comando della skill, nella cartella."""
    fatto = subprocess.run(comando, shell=True, stdout=subprocess.PIPE,
                           stderr=subprocess.STDOUT, check=False)
    return fatto.stdout.decode("utf-8", "replace").rstrip("\n")


def regole_skill(campi: Dict[str, str]) -> List[str]:
    """Le regole del campo allowed-tools; nessuna con FINTO_ALLOWED_IGNORATO.
    """
    valore = campi.get("allowed-tools", "")
    if not valore or acceso("FINTO_ALLOWED_IGNORATO"):
        return []
    return re.findall(r"\w+\([^)]*\)|\w+", valore)


def rendi(corpo: str, regole: List[str], stato: Stato) -> Optional[str]:
    """Il corpo con l'output al posto di ogni !`comando`. Se un comando non è
    consentito, l'invocazione si ferma: None, e lo stream è già finito."""
    for comando in RE_INIEZIONE.findall(corpo):
        if not concesso(comando, regole) and not acceso(
                "FINTO_FERMO_IGNORATO"):
            utente("<local-command-stderr>Shell command permission check "
                   "failed for pattern \"!`%s`\": %s</local-command-stderr>"
                   % (comando, NEGATO), stato, isReplay=True)
            risultato("", 0, stato, locale=True, uso=USO_ZERO)
            return None
    if acceso("FINTO_BANG_NON_SOSTITUISCE"):
        return RE_INIEZIONE.sub("(niente)", corpo)
    return RE_INIEZIONE.sub(lambda m: esegui(m.group(1)), corpo)


def chiamata_bash(comando: str, regole: List[str],
                  stato: Stato) -> Optional[str]:
    """Una chiamata Bash del modello: l'output, o None se è negata."""
    ident = "toolu_" + uuid.uuid4().hex[:12]
    assistente([{"type": "tool_use", "id": ident, "name": "Bash",
                 "input": {"command": comando}}], stato)
    if concesso(comando, regole + stato.consentiti):
        uscita = esegui(comando)
        utente([{"tool_use_id": ident, "type": "tool_result",
                 "content": uscita, "is_error": False}], stato)
        return uscita
    emetti({"type": "system", "subtype": "permission_denied",
            "tool_name": "Bash", "tool_use_id": ident,
            "decision_reason_type": "mode", "message": NEGATO,
            "session_id": stato.sid})
    utente([{"type": "tool_result", "content": NEGATO, "is_error": True,
             "tool_use_id": ident}], stato)
    stato.negati.append({"tool_name": "Bash", "tool_use_id": ident,
                         "tool_input": {"command": comando}})
    return None


def invoca_con_bash(comando: str, regole: List[str], stato: Stato) -> None:
    """Il turno in cui Claude esegue un comando e riporta l'esito."""
    uscita = chiamata_bash(comando, regole, stato)
    testo = uscita if uscita is not None else (
        "Non sono riuscito a eseguire `%s` (finto)." % comando)
    assistente([{"type": "text", "text": testo}], stato)
    risultato(testo, 2, stato)


def rispondi(testo: str, stato: Stato, turni: int = 1) -> None:
    assistente([{"type": "text", "text": testo}], stato)
    risultato(testo, turni, stato)


def scena_comandi(corpo: str, campi: Dict[str, str], stato: Stato) -> None:
    """Le skill di M5-D03 con un !`comando` o un comando nel corpo."""
    regole = regole_skill(campi)
    resa = rendi(corpo, regole, stato)
    if resa is None:
        return
    comando = RE_COMANDO.search(resa)
    if comando and acceso("FINTO_DATO_SENZA_STRUMENTI"):
        rispondi(esegui(comando.group(1)), stato)
    elif comando and acceso("FINTO_NON_ESEGUE"):
        rispondi("Non eseguo niente (finto).", stato)
    elif comando:
        invoca_con_bash(comando.group(1), regole, stato)
    elif acceso("FINTO_BANG_STRUMENTO"):
        invoca_con_bash(RE_INIEZIONE.findall(corpo)[0], regole, stato)
    else:
        prima = resa.strip().splitlines()[0]
        rispondi(prima.split("è: ", 1)[-1], stato)


def parola_nella_storia(storia: List[str]) -> Optional[str]:
    """La parola in codice detta prima in questa sessione."""
    for testo in storia:
        trovata = RE_PAROLA.search(testo)
        if trovata:
            return trovata.group(1)
    return None


def scena_fork(storia: List[str], stato: Stato) -> None:
    """context: fork: il subagent, con il corpo della skill come compito."""
    testo = "NON LA VEDO."
    if acceso("FINTO_FORK_VEDE"):
        testo = parola_nella_storia(storia) or testo
    emetti({"type": "system", "subtype": "task_started", "task_id": "a1",
            "description": "/prova-parola", "subagent_type": "general-purpose",
            "session_id": stato.sid, "uuid": str(uuid.uuid4())})
    emetti({"type": "system", "subtype": "task_notification", "task_id": "a1",
            "status": "completed", "session_id": stato.sid,
            "uuid": str(uuid.uuid4())})
    emetti(inizio(stato))
    utente([{"type": "text", "text": "Base directory for this skill: "
             "(finto)"}], stato,
           parent_tool_use_id="forked-command-prova-parola", agent_id="a1")
    assistente([{"type": "text", "text": testo}], stato)
    risultato(testo, 0, stato, locale=True, uso=USO_ZERO)


def scena_parola(campi: Dict[str, str], storia: List[str],
                 stato: Stato) -> None:
    """/prova-parola, senza fork o con."""
    if campi.get("context") == "fork" and not acceso("FINTO_FORK_INLINE"):
        scena_fork(storia, stato)
        return
    emetti(inizio(stato))
    parola = parola_nella_storia(storia)
    if campi.get("context") == "fork" or acceso("FINTO_INLINE_NON_VEDE"):
        parola = None
    rispondi(parola or "NON LA VEDO.", stato)


def file_cambiati() -> List[str]:
    """I file cambiati rispetto all'ultimo commit, come li vede git."""
    return esegui("git diff --name-only HEAD").split()


def risposta_e01() -> str:
    """La risposta della skill di M5-E01."""
    if acceso("FINTO_NON_NOMINA"):
        return "Ci sono modifiche, ma non dico quali (finto)."
    nomi = ", ".join(file_cambiati()) or "nessun file"
    return "Riassunto (finto): è cambiato %s." % nomi


def scena_nome(nome: str, storia: List[str], stato: Stato) -> None:
    """/nome in testa al prompt."""
    letta = leggi_skill(nome)
    if letta is None:
        emetti(inizio(stato))
        rispondi("Non conosco questo comando (finto).", stato)
        return
    campi, corpo = letta
    if nome == "prova-parola":
        scena_parola(campi, storia, stato)
        return
    emetti(inizio(stato))
    if nome == SKILL_E01:
        if rendi(corpo, regole_skill(campi), stato) is not None:
            rispondi(risposta_e01(), stato)
        return
    scena_comandi(corpo, campi, stato)


def scena_richiesta_e01(prompt: str, stato: Stato) -> None:
    """La richiesta di M5-E01: scrive la skill con Write nel percorso che il
    prompt nomina; poi il comando del controllo che il prompt nomina, se gli
    strumenti lo consentono. In dontAsk una scrittura in .claude/ è negata anche
    con Write fra gli strumenti: .claude è un percorso protetto, e la pagina
    delle modalità di permesso dice «dontAsk | Denied»."""
    emetti(inizio(stato))
    ident = "toolu_" + uuid.uuid4().hex[:12]
    bersaglio = RE_BERSAGLIO.search(prompt)
    if bersaglio is None:
        raise Rifiutato("error: la richiesta non nomina lo SKILL.md")
    percorso = bersaglio.group(1)
    assistente([{"type": "tool_use", "id": ident, "name": "Write",
                 "input": {"file_path": percorso}}], stato)
    protetto = percorso.startswith(".claude/") \
        and stato.opzioni.get("--permission-mode") == "dontAsk"
    if "Write" not in stato.consentiti or protetto \
            or acceso("FINTO_NON_SCRIVE"):
        stato.negati.append({"tool_name": "Write", "tool_use_id": ident,
                             "tool_input": {"file_path": percorso}})
        utente([{"type": "tool_result", "content": NEGATO, "is_error": True,
                 "tool_use_id": ident}], stato)
        rispondi("Non posso scrivere il file (finto).", stato, 2)
        return
    os.makedirs(os.path.dirname(percorso), exist_ok=True)
    with open(percorso, "w", encoding="utf-8") as fh:
        fh.write(TESTO_SKILL_ROTTA if acceso("FINTO_SKILL_ROTTA")
                 else TESTO_SKILL)
    if acceso("FINTO_BOZZA_ALTRO"):
        with open(os.path.join("bozza", "appunti.txt"), "w",
                  encoding="utf-8") as fh:
            fh.write("appunti del finto\n")
    utente([{"tool_use_id": ident, "type": "tool_result",
             "content": "File creato (finto)"}], stato)
    comando = RE_CONTROLLO.search(prompt)
    if comando is not None:
        chiamata_bash(comando.group(0), [], stato)
    rispondi("Skill scritta (finto).", stato, 3)


def scena_domanda_e01(stato: Stato) -> None:
    """La domanda naturale di M5-E01."""
    emetti(inizio(stato))
    letta = leggi_skill(SKILL_E01)
    if letta is None or acceso("FINTO_SENZA_CHIAMATA"):
        rispondi("Ho guardato senza la skill (finto).", stato)
        return
    campi, corpo = letta
    ident = "toolu_" + uuid.uuid4().hex[:12]
    assistente([{"type": "tool_use", "id": ident, "name": "Skill",
                 "input": {"skill": SKILL_E01}}], stato)
    regola = "Skill(%s)" % SKILL_E01
    if ("allowed-tools" in campi or "disallowed-tools" in campi) \
            and regola not in stato.consentiti:
        stato.negati.append({"tool_name": "Skill", "tool_use_id": ident,
                             "tool_input": {"skill": SKILL_E01}})
        utente([{"type": "tool_result", "content": NEGATO, "is_error": True,
                 "tool_use_id": ident}], stato)
        rispondi("Ho guardato senza la skill (finto).", stato, 2)
        return
    utente([{"type": "tool_result", "tool_use_id": ident,
             "content": "Launching skill: %s" % SKILL_E01}], stato)
    resa = RE_INIEZIONE.sub(lambda m: esegui(m.group(1)), corpo)
    utente([{"type": "text", "text": "Base directory for this skill: %s\n\n%s"
             % (os.path.join(os.getcwd(), ".claude", "skills", SKILL_E01),
                resa)}], stato, isSynthetic=True)
    turni = 2
    if acceso("FINTO_CON_STRUMENTI"):
        chiamata_bash("git log --oneline -1", [], stato)
        turni = 3
    rispondi(risposta_e01(), stato, turni)


def inizio(stato: Stato) -> dict:
    """L'evento system/init."""
    return {"type": "system", "subtype": "init", "session_id": stato.sid,
            "cwd": os.getcwd(), "skills": skill_elencate(),
            "tools": ["Task", "Bash", "Edit", "Read", "Skill", "Write"],
            "model": stato.opzioni.get("--model", ""),
            "permissionMode": stato.opzioni.get("--permission-mode", ""),
            "claude_code_version": "finto", "uuid": str(uuid.uuid4())}


def recita(prompt: str, storia: List[str], stato: Stato) -> None:
    """La scena del prompt. Raises: Rifiutato se non la conosce."""
    if prompt.startswith("/skill-doctor"):
        emetti(inizio(stato))
        risultato(TESTO_DOCTOR, 0, stato, locale=True, uso=USO_ZERO)
    elif prompt.startswith("/"):
        scena_nome(prompt[1:].split()[0], storia, stato)
    elif prompt.startswith("Ricorda: la parola in codice"):
        emetti(inizio(stato))
        rispondi("ok", stato)
    elif prompt.startswith("Esegui di nuovo"):
        emetti(inizio(stato))
        regole = ["Bash(bash conta.sh)"] if acceso("FINTO_GRANT_RESTA") else []
        if acceso("FINTO_NON_RIPROVA"):
            rispondi("Il risultato è quello di prima (finto).", stato)
        else:
            invoca_con_bash("bash conta.sh", regole, stato)
    elif SKILL_E01 in prompt:
        scena_richiesta_e01(prompt, stato)
    elif prompt.startswith("Che cosa ho cambiato"):
        scena_domanda_e01(stato)
    else:
        raise Rifiutato("error: prompt che il finto non conosce: %s"
                        % prompt[:60])


def percorso_sessione(sid: str) -> str:
    base = os.environ.get("FINTO_SESSIONI")
    if not base:
        raise Rifiutato("error: FINTO_SESSIONI non è impostata")
    os.makedirs(base, exist_ok=True)
    return os.path.join(base, sid + ".json")


def apri_sessione(opzioni: Dict[str, str]) -> Tuple[str, List[str]]:
    """(l'id della sessione, ciò che vi è stato detto prima)."""
    riprende = opzioni.get("--resume")
    if riprende is None:
        return "finta-" + uuid.uuid4().hex[:12], []
    percorso = percorso_sessione(riprende)
    if not os.path.isfile(percorso):
        raise Rifiutato("error: No conversation found with session ID: %s"
                        % riprende)
    with open(percorso, encoding="utf-8") as fh:
        storia = json.load(fh)
    if acceso("FINTO_ALTRA_SESSIONE"):
        return "finta-" + uuid.uuid4().hex[:12], storia
    return riprende, storia


def plugin_validate(argv: List[str]) -> int:
    """claude plugin validate <cartella>."""
    if len(argv) != 1 or not os.path.isdir(argv[0]):
        print("error: serve una cartella (finto)", file=sys.stderr)
        return 1
    if acceso("FINTO_VALIDATE_KO"):
        print("YAML frontmatter failed to parse (finto)")
        return 1
    print("Validation passed (finto)")
    return 0


def main(argv: List[str]) -> int:
    if argv == ["--version"]:
        print("2.1.317 (Claude Code) (finto)")
        return 0
    if argv[:2] == ["plugin", "validate"]:
        registra(argv, "")
        return plugin_validate(argv[2:])
    try:
        opzioni, prompt = argomenti(argv)
        registra(argv, prompt)
        if opzioni.get("--output-format") != "stream-json" \
                or "--verbose" not in opzioni:
            raise Rifiutato("error: il finto vuole --output-format "
                            "stream-json --verbose")
        vietata = os.environ.get("FINTO_ESITO_KO_SE")
        if vietata and vietata in prompt:
            return 1
        sid, storia = apri_sessione(opzioni)
        consentiti = [r for r in opzioni.get("--allowedTools", "").split(",")
                      if r]
        recita(prompt, storia, Stato(opzioni, sid, consentiti, []))
        if "--no-session-persistence" not in opzioni:
            with open(percorso_sessione(sid), "w", encoding="utf-8") as fh:
                json.dump(storia + [prompt], fh)
    except Rifiutato as exc:
        print(str(exc), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
