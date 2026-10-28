#!/usr/bin/env python3
"""claude_finto_m4_d04_d06.py -- un claude finto per le prove di M4-D04 e
M4-D06 (test_m4_d04.sh, test_m4_d06.sh).

Le suite lo copiano, con il nome «claude», davanti nel PATH: così i
live.sh e il blocco del README di M4-D06 girano per intero senza chiamare
il modello e senza consumare il piano. Gli stream che scrive sono
inventati e dichiarati finti: nessuno è una risposta di Claude. Hanno la
forma degli stream di `claude -p --output-format stream-json --verbose`
(l'evento system/init, i messaggi assistant e user, gli eventi system, il
risultato), e gli effetti sui file li produce il finto stesso, come li
produrrebbe Claude Code: provano i controlli, non il modello.

Gli argomenti: le opzioni che usano i due elementi (OPZIONI, con quanti
valori prendono), poi il prompt, dopo «--» oppure come unico operando.
Rifiuta («error: …», uscita 1) un'opzione che non conosce, un
--output-format diverso da stream-json e lo stream-json senza --verbose.
Con --tools la sessione ha soltanto gli strumenti nominati (nell'evento
init Agent si chiama Task, come in Claude Code); senza, STRUMENTI.

Ogni invocazione aggiunge a FINTO_LOG, se c'è, una riga JSON: gli
argomenti (argv), la cartella (cwd), se ANTHROPIC_API_KEY era
nell'ambiente (chiave) e se tre cartelle sopra c'era risposte/
(risposte_vicine: M4-D06 tiene le risposte lontane dalle sessioni).

Le scene, dal prompt:
  PrioritaTicket.php    M4-D04, il piano. In plan mode legge il file,
                        scrive il piano in $HOME/.claude/plans/ (o nel
                        percorso FINTO_PIANO_PERCORSO) e tenta ExitPlanMode;
                        nelle altre modalità aggiunge un commento al file.
                        FINTO_PIANO_MODIFICA=1 modifica anche in plan mode;
                        FINTO_PIANO_FERMO=1 non modifica fuori dal plan mode.
  01_comuni.sql         M4-D04, la regola deny. Legge .claude/settings.json
                        della cartella: con la regola l'Edit è negato, con
                        il testo del diniego che Claude Code dà nella
                        registrazione del corso (NEGATO_REGOLA), ed entra
                        in permission_denials; senza, il file cambia.
                        FINTO_DENY_IGNORA=1 modifica anche con la regola;
                        FINTO_DENY_NON_TENTA=1 con la regola non tenta;
                        FINTO_DENY_SENZA_ELENCO=1 nega senza elencare;
                        FINTO_DENY_FERMO=1 senza la regola non modifica;
                        FINTO_MESSAGGIO_DINIEGO=1 aggiunge il messaggio
                        system permission_denied.
  rm da_cancellare.txt  M4-D04, l'hook. Esegue davvero gli hook PreToolUse
                        di .claude/settings.json che coprono Bash, con
                        l'ingresso JSON su STDIN: uno che esce con 2 nega la
                        chiamata; altrimenti il file si cancella.
                        FINTO_HOOK_IGNORA, FINTO_HOOK_NON_TENTA,
                        FINTO_HOOK_SENZA_ELENCO, FINTO_HOOK_FERMO come per
                        la regola deny.
  olt-pergine-01        M4-D06. Con il prompt che comincia con «Delega» un
                        Agent (Explore) e i passaggi del subagent, con
                        parent_tool_use_id, poi due risultati; senza, i
                        passaggi nella conversazione principale. Senza
                        Agent fra gli strumenti nessuna delega; i passaggi
                        leggono con Bash se c'è, altrimenti con Read, e
                        cercano con Grep se c'è.
                        FINTO_CONTESTO_DELEGA, FINTO_CONTESTO_SENZA: il
                        contesto dell'ultima richiesta principale (default
                        21000 e 29000); FINTO_RISPOSTA_DELEGA,
                        FINTO_RISPOSTA_SENZA: la risposta; FINTO_NON_DELEGA=1
                        niente Agent nemmeno con «Delega»;
                        FINTO_DELEGA_SEMPRE=1 un Agent anche senza;
                        FINTO_PERDITA=1 un risultato del subagent anche in
                        un messaggio della conversazione principale;
                        FINTO_ORFANO=1 nella principale un risultato di una
                        chiamata che lo stream non mostra;
                        FINTO_SENZA_PASSAGGI=1 l'Agent senza i passaggi del
                        subagent nello stream; FINTO_SENZA_USO=1 l'ultimo
                        messaggio principale senza usage.
  FINTO_ESITO=ko        esce 1 senza stampare nulla.
  FINTO_ESITO_KO_SE=t   esce 1 senza stampare nulla se il prompt contiene t.
  FINTO_TRONCO=1        toglie i risultati finali dallo stream.
Uscita: 0 lo stream · 1 FINTO_ESITO=ko, un argomento rifiutato, un prompt
        che il finto non conosce
"""
import datetime
import json
import os
import re
import subprocess
import sys
from typing import Dict, List, Optional, Tuple

OPZIONI = {"-p": 0, "--print": 0, "--verbose": 0, "--strict-mcp-config": 0,
           "--no-session-persistence": 0, "--model": 1, "--effort": 1,
           "--tools": 1, "--allowedTools": 1, "--disallowedTools": 1,
           "--output-format": 1, "--permission-mode": 1,
           "--permission-prompts": 1, "--setting-sources": 1}
REGOLA = "Edit(/progetti/gestionale-php/database/dati/**)"
PIANO = "progetti/gestionale-php/src/Ticket/PrioritaTicket.php"
DATI = "progetti/gestionale-php/database/dati/01_comuni.sql"
SCARTO = "da_cancellare.txt"
# il testo con cui Claude Code nega l'Edit per una regola deny, come nella
# registrazione del corso, segnato come finto
NEGATO_REGOLA = ("<tool_use_error>File is in a directory that is denied by "
                 "your permission settings.</tool_use_error> (finto)")
RISPOSTA = "inizio: 10:12 | fine: 11:40 | ONT: 40"
STRUMENTI = ["Task", "Bash", "Edit", "Glob", "Grep", "Read", "Write"]
LOG_FINTO = "\n".join("riga di log finta %d del claude finto" % i
                      for i in range(60))
SESSIONE = "sessione-finta"
INIZIO = datetime.datetime(2026, 1, 1)


class Rifiutato(Exception):
    """Argomenti che il finto non accetta: il messaggio d'errore."""


def acceso(nome: str) -> bool:
    """Vero se la variabile d'ambiente vale 1."""
    return os.environ.get(nome) == "1"


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
    if opzioni.get("--output-format") != "stream-json":
        raise Rifiutato("error: il claude finto conosce solo "
                        "--output-format stream-json")
    if "--verbose" not in opzioni:
        raise Rifiutato("error: il claude finto vuole --verbose con "
                        "--output-format stream-json")
    return opzioni, operandi[0]


class Stream:
    """Gli eventi di una chiamata, con id e orari finti in ordine."""

    def __init__(self, cwd: str, modo: str, strumenti: List[str]) -> None:
        self.cwd = cwd
        self.modo = modo
        self.strumenti = strumenti
        self.eventi: List[dict] = []
        self.numero = 0
        self.dinieghi: List[dict] = []
        self.avvio()

    def avvio(self) -> None:
        """L'evento system/init, con gli strumenti disponibili."""
        self.eventi.append({
            "type": "system", "subtype": "init", "cwd": self.cwd,
            "session_id": SESSIONE, "model": "claude-finto",
            "permissionMode": self.modo, "tools": self.strumenti,
            "agents": ["Explore", "general-purpose", "Plan"]})

    def prossimo(self) -> Tuple[int, str]:
        """Un numero nuovo e l'orario finto che gli corrisponde."""
        self.numero += 1
        ora = INIZIO + datetime.timedelta(seconds=self.numero)
        return self.numero, ora.strftime("%Y-%m-%dT%H:%M:%S.000Z")

    def assistente(self, blocchi: List[dict], contesto: int,
                   padre: Optional[str], uso: bool = True) -> None:
        """Un messaggio dell'assistente, con il contesto della richiesta
        (senza usage se uso è falso)."""
        numero, ora = self.prossimo()
        messaggio = {"id": "msg_finto_%d" % numero, "role": "assistant",
                     "content": blocchi}
        if uso:
            messaggio["usage"] = {"input_tokens": 3,
                                  "cache_read_input_tokens": contesto - 3,
                                  "cache_creation_input_tokens": 0,
                                  "output_tokens": 40}
        self.eventi.append({
            "type": "assistant", "parent_tool_use_id": padre,
            "session_id": SESSIONE, "timestamp": ora, "message": messaggio})

    def utente(self, ident: str, testo: str, errore: bool,
               padre: Optional[str]) -> None:
        """Il risultato di uno strumento."""
        _, ora = self.prossimo()
        blocco = {"type": "tool_result", "tool_use_id": ident,
                  "content": testo}
        if errore:
            blocco["is_error"] = True
        self.eventi.append({
            "type": "user", "parent_tool_use_id": padre,
            "session_id": SESSIONE, "timestamp": ora,
            "message": {"role": "user", "content": [blocco]}})

    def strumento(self, nome: str, ingresso: dict, risultato: str,
                  errore: bool = False, padre: Optional[str] = None,
                  contesto: int = 18000, diniego: bool = False) -> str:
        """La chiamata a uno strumento e il suo risultato; con diniego il
        messaggio permission_denied (FINTO_MESSAGGIO_DINIEGO=1) e la voce
        di permission_denials. Returns: l'id della chiamata."""
        ident = "toolu_finto_%d" % (self.numero + 1)
        self.assistente([{"type": "tool_use", "id": ident, "name": nome,
                          "input": ingresso}], contesto, padre)
        if diniego and acceso("FINTO_MESSAGGIO_DINIEGO"):
            self.eventi.append({
                "type": "system", "subtype": "permission_denied",
                "tool_name": nome, "tool_use_id": ident,
                "session_id": SESSIONE})
        self.utente(ident, risultato, errore, padre)
        return ident

    def elenca(self, ident: str, nome: str, ingresso: dict) -> None:
        """Una voce di permission_denials nel risultato."""
        self.dinieghi.append({"tool_name": nome, "tool_use_id": ident,
                              "tool_input": ingresso})

    def testo(self, testo: str, contesto: int, uso: bool = True) -> None:
        """Un messaggio di testo della conversazione principale."""
        self.assistente([{"type": "text", "text": testo}], contesto, None,
                        uso)

    def sistema(self, sottotipo: str, **campi: str) -> None:
        """Un evento system delle attività in background."""
        evento = {"type": "system", "subtype": sottotipo,
                  "session_id": SESSIONE}
        evento.update(campi)
        self.eventi.append(evento)

    def risultato(self, testo: str, indice: int, uso: dict) -> dict:
        """Il messaggio del risultato, come in claude -p."""
        return {"type": "result", "subtype": "success", "is_error": False,
                "result": testo, "result_index": indice, "num_turns": 2,
                "duration_ms": 1000, "session_id": SESSIONE,
                "permission_denials": self.dinieghi,
                "usage": {"input_tokens": 4, "output_tokens": 20},
                "modelUsage": {"claude-finto": uso}}


def leggi_impostazioni(cwd: str) -> dict:
    """.claude/settings.json della cartella, {} se manca o non va."""
    try:
        with open(os.path.join(cwd, ".claude", "settings.json"),
                  encoding="utf-8") as fh:
            doc = json.load(fh)
    except (OSError, ValueError):
        return {}
    return doc if isinstance(doc, dict) else {}


def aggiungi_riga(percorso: str, riga: str, in_testa: bool) -> None:
    """Una riga in fondo al file, o dopo la prima riga."""
    with open(percorso, encoding="utf-8") as fh:
        righe = fh.read().splitlines(True)
    if in_testa and righe:
        righe.insert(1, riga)
    else:
        righe.append(riga)
    with open(percorso, "w", encoding="utf-8") as fh:
        fh.write("".join(righe))


def scena_piano(s: Stream, cwd: str) -> str:
    """M4-D04, il gradino del piano. Returns: il testo della risposta."""
    bersaglio = os.path.join(cwd, PIANO)
    s.strumento("Read", {"file_path": bersaglio}, "contenuto finto")
    commento = {"file_path": bersaglio, "old_string": "<?php",
                "new_string": "<?php\n// commento finto"}
    if s.modo == "plan":
        piano = os.environ.get("FINTO_PIANO_PERCORSO") or os.path.join(
            os.path.expanduser("~"), ".claude", "plans",
            "piano-finto-%d.md" % os.getpid())
        os.makedirs(os.path.dirname(piano), exist_ok=True)
        with open(piano, "w", encoding="utf-8") as fh:
            fh.write("Piano finto del claude finto.\n")
        s.strumento("Write", {"file_path": piano, "content": "Piano finto"},
                    "File created successfully at: %s (finto)" % piano)
        s.strumento("ExitPlanMode", {"plan": "piano finto"},
                    "ExitPlanMode non disponibile (finto)", errore=True)
        if acceso("FINTO_PIANO_MODIFICA"):
            aggiungi_riga(bersaglio, "// commento finto\n", True)
            s.strumento("Edit", commento, "aggiornato (finto)")
        return "Piano finto: un commento sopra l'enum."
    if acceso("FINTO_PIANO_FERMO"):
        return "Non ho modificato niente (finto)."
    aggiungi_riga(bersaglio, "// commento finto\n", True)
    s.strumento("Edit", commento, "aggiornato (finto)")
    return "Fatto (finto): un commento in testa."


def regola_presente(cwd: str) -> bool:
    """Vero se .claude/settings.json nega la modifica dei dati."""
    permessi = leggi_impostazioni(cwd).get("permissions")
    nega = permessi.get("deny") if isinstance(permessi, dict) else None
    # dalla radice, dove il finto lavora, una modifica con lo strumento Edit
    # la nega la regola ancorata come quelle relative
    varianti = (REGOLA, REGOLA.replace("(/", "(", 1),
                REGOLA.replace("(/", "(./", 1))
    return isinstance(nega, list) and any(r in varianti for r in nega)


def scena_deny(s: Stream, cwd: str) -> str:
    """M4-D04, il gradino della regola deny."""
    bersaglio = os.path.join(cwd, DATI)
    s.strumento("Read", {"file_path": bersaglio}, "contenuto finto")
    regola = regola_presente(cwd)
    if regola and acceso("FINTO_DENY_NON_TENTA"):
        return "Non tento la modifica (finto)."
    if not regola and acceso("FINTO_DENY_FERMO"):
        return "Non modifico un file generato (finto)."
    ingresso = {"file_path": bersaglio, "old_string": "(finto)",
                "new_string": "(finto)"}
    if regola and not acceso("FINTO_DENY_IGNORA"):
        ident = s.strumento("Edit", ingresso, NEGATO_REGOLA,
                            errore=True, diniego=True)
        if not acceso("FINTO_DENY_SENZA_ELENCO"):
            s.elenca(ident, "Edit", ingresso)
        return "La modifica è stata negata (finto)."
    aggiungi_riga(bersaglio, "-- elenco controllato a mano\n", False)
    s.strumento("Edit", ingresso, "aggiornato (finto)")
    return "Fatto (finto)."


def hook_bash(cwd: str) -> List[str]:
    """I comandi degli hook PreToolUse il cui matcher copre Bash."""
    hooks = leggi_impostazioni(cwd).get("hooks")
    voci = hooks.get("PreToolUse") if isinstance(hooks, dict) else None
    comandi: List[str] = []
    for voce in voci if isinstance(voci, list) else []:
        matcher = str(voce.get("matcher", ""))
        if matcher not in ("", "*") and not re.fullmatch(matcher, "Bash"):
            continue
        for hook in voce.get("hooks") or []:
            if hook.get("type") == "command":
                comandi.append(str(hook.get("command", "")))
    return comandi


def esegui_hook(cwd: str, comando: str, riga: str) -> Tuple[int, str]:
    """Un hook con l'ingresso di PreToolUse su STDIN: (uscita, STDERR)."""
    ingresso = {"session_id": SESSIONE, "cwd": cwd,
                "hook_event_name": "PreToolUse", "tool_name": "Bash",
                "tool_input": {"command": riga}}
    ambiente = dict(os.environ, CLAUDE_PROJECT_DIR=cwd)
    fatto = subprocess.run(["bash", "-c", comando], input=json.dumps(ingresso),
                           cwd=cwd, env=ambiente, stdout=subprocess.PIPE,
                           stderr=subprocess.PIPE, universal_newlines=True,
                           timeout=60)
    return fatto.returncode, fatto.stderr


def scena_hook(s: Stream, cwd: str) -> str:
    """M4-D04, il gradino dell'hook."""
    riga = "rm " + SCARTO
    hooks = hook_bash(cwd)
    if hooks and acceso("FINTO_HOOK_NON_TENTA"):
        return "Non lo eseguo (finto)."
    if not hooks and acceso("FINTO_HOOK_FERMO"):
        return "Non cancello niente (finto)."
    motivo = None
    for comando in hooks:
        uscita, errore = esegui_hook(cwd, comando, riga)
        if uscita == 2:
            motivo = errore
            break
    ingresso = {"command": riga}
    if motivo is not None and not acceso("FINTO_HOOK_IGNORA"):
        ident = s.strumento("Bash", ingresso,
                            "PreToolUse:Bash hook error (finto): " + motivo,
                            errore=True, diniego=True)
        if not acceso("FINTO_HOOK_SENZA_ELENCO"):
            s.elenca(ident, "Bash", ingresso)
        return "Il comando è stato bloccato da un hook (finto)."
    os.remove(os.path.join(cwd, SCARTO))
    s.strumento("Bash", ingresso, "(Bash completed with no output)")
    return "Fatto (finto)."


def disponibile(s: Stream, nome: str) -> bool:
    """Vero se lo strumento è fra quelli della sessione (Agent compare come
    Task nell'evento init)."""
    return ("Task" if nome == "Agent" else nome) in s.strumenti


def passaggi(s: Stream, contesti: Tuple[int, int],
             padre: Optional[str] = None) -> str:
    """I passaggi di lettura dei log, con il contesto di ciascuno: la
    lettura con Bash se la sessione l'ha, altrimenti con Read; poi, se c'è,
    Grep. Returns: l'id della lettura."""
    if disponibile(s, "Bash"):
        letto = s.strumento("Bash", {"command": "grep olt-pergine-01 syslog"},
                            LOG_FINTO, padre=padre, contesto=contesti[0])
    else:
        letto = s.strumento("Read", {"file_path": "syslog/olt.log"},
                            LOG_FINTO, padre=padre, contesto=contesti[0])
    if disponibile(s, "Grep"):
        s.strumento("Grep", {"pattern": "olt-pergine-01"}, LOG_FINTO,
                    padre=padre, contesto=contesti[1])
    return letto


def scena_delega(s: Stream, prompt: str) -> List[Tuple[str, dict]]:
    """M4-D06: delegare la lettura dei log, oppure no.
    Returns: i testi dei risultati, ciascuno con il suo modelUsage."""
    chiesta = prompt.startswith("Delega")
    lato = "DELEGA" if chiesta else "SENZA"
    contesto = int(os.environ.get("FINTO_CONTESTO_" + lato,
                                  "21000" if chiesta else "29000"))
    risposta = os.environ.get("FINTO_RISPOSTA_" + lato, RISPOSTA)
    delega = ((chiesta and not acceso("FINTO_NON_DELEGA"))
              or acceso("FINTO_DELEGA_SEMPRE")) and disponibile(s, "Agent")
    uso = {"inputTokens": 20, "outputTokens": 2000,
           "cacheReadInputTokens": 140000, "cacheCreationInputTokens": 30000}
    if not delega:
        passaggi(s, (contesto - 8000, contesto - 3000))
        s.testo(risposta, contesto)
        uso = {"inputTokens": 15, "outputTokens": 1100,
               "cacheReadInputTokens": 100000,
               "cacheCreationInputTokens": 18000}
        return [(risposta, uso)]
    agente = s.strumento("Agent", {"description": "Leggi i log (finto)",
                                   "subagent_type": "Explore",
                                   "prompt": "Leggi i log (finto)"},
                         "Async agent launched (finto).",
                         contesto=contesto - 2500)
    s.sistema("task_started", tool_use_id=agente, subagent_type="Explore")
    s.testo("Ho delegato la lettura (finto).", contesto - 2000)
    if not acceso("FINTO_SENZA_PASSAGGI"):
        letto = passaggi(s, (9000, 12000), agente)
        if acceso("FINTO_PERDITA"):
            s.utente(letto, LOG_FINTO, False, None)
    if acceso("FINTO_ORFANO"):
        s.utente("toolu_orfano", LOG_FINTO, False, None)
    s.sistema("task_notification", tool_use_id=agente, status="completed",
              summary="Riassunto finto del subagent.")
    s.avvio()
    s.testo(risposta, contesto, not acceso("FINTO_SENZA_USO"))
    return [("Ho delegato la lettura (finto).", uso), (risposta, uso)]


def registra(argv: List[str]) -> None:
    """Una riga in FINTO_LOG, se c'è."""
    log = os.environ.get("FINTO_LOG")
    if not log:
        return
    vicine = os.path.exists(os.path.join(os.getcwd(), "..", "..", "..",
                                         "risposte"))
    with open(log, "a", encoding="utf-8") as fh:
        fh.write(json.dumps({
            "argv": argv, "cwd": os.getcwd(),
            "chiave": bool(os.environ.get("ANTHROPIC_API_KEY")),
            "risposte_vicine": vicine}, ensure_ascii=False) + "\n")


def scena(s: Stream, cwd: str, prompt: str) -> List[Tuple[str, dict]]:
    """La scena del prompt. Returns: i testi dei risultati con il loro
    modelUsage. Rifiutato se il prompt non è di una scena."""
    uso = {"inputTokens": 10, "outputTokens": 300,
           "cacheReadInputTokens": 30000, "cacheCreationInputTokens": 5000}
    if "PrioritaTicket.php" in prompt:
        return [(scena_piano(s, cwd), uso)]
    if "01_comuni.sql" in prompt:
        return [(scena_deny(s, cwd), uso)]
    if "rm " + SCARTO in prompt:
        return [(scena_hook(s, cwd), uso)]
    if "olt-pergine-01" in prompt:
        return scena_delega(s, prompt)
    raise Rifiutato("error: il claude finto non conosce questo prompt")


def main(argv: List[str]) -> int:
    registra(argv)
    if argv[:1] == ["--version"]:
        print("0.0.0 (Claude Code, finto)")
        return 0
    try:
        opzioni, prompt = argomenti(argv)
        if os.environ.get("FINTO_ESITO", "ok") != "ok":
            return 1
        guasto = os.environ.get("FINTO_ESITO_KO_SE")
        if guasto and guasto in prompt:
            return 1
        cwd = os.getcwd()
        strumenti = [("Task" if t == "Agent" else t)
                     for t in opzioni["--tools"].split(",") if t] \
            if "--tools" in opzioni else list(STRUMENTI)
        s = Stream(cwd, opzioni.get("--permission-mode", "manual"),
                   strumenti)
        risultati = scena(s, cwd, prompt)
    except Rifiutato as exc:
        sys.stderr.write("%s\n" % exc)
        return 1
    eventi = list(s.eventi)
    if not acceso("FINTO_TRONCO"):
        eventi += [s.risultato(testo, indice, uso)
                   for indice, (testo, uso) in enumerate(risultati)]
    for evento in eventi:
        print(json.dumps(evento, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
