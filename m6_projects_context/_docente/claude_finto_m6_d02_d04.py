#!/usr/bin/env python3
"""claude_finto_m6_d02_d04.py -- un claude finto per le prove di M6-D02 e
M6-D04 (test_m6_d02.sh, test_m6_d04.sh).

Le suite lo copiano, con il nome «claude», davanti nel PATH: così
in_classe.sh, sessione.py e i live.sh girano per intero senza chiamare il
modello e senza consumare il piano. Gli stream che scrive sono inventati e
dichiarati finti: nessuno è una risposta di Claude. Hanno la forma degli
stream di `claude -p --output-format stream-json --verbose` (system/init, i
messaggi assistant e user, compact_boundary, conversation_reset, il risultato
di ogni messaggio), e provano i controlli, non il modello.

Fa ciò che la documentazione dice di Claude Code, con i file veri della
cartella in cui gira: all'avvio carica CLAUDE.md senza i commenti HTML a
blocco, i file che importa con @ fuori dai backtick, CLAUDE.local.md (se
--setting-sources ha local) e le regole di .claude/rules/ senza paths; una
regola con paths quando legge con Read un file che corrisponde, un CLAUDE.md
di una sottocartella quando legge un file lì; una modifica a CLAUDE.md non la
vede finché non vengono /compact (il CLAUDE.md della radice e le regole senza
paths si rileggono dal disco, le altre tornano quando servono) o /clear. Per
ogni caricamento fa girare l'hook InstructionsLoaded di .claude/settings.json
della cartella, quello vero, con un evento della forma della documentazione.

Due modi:
  -p … -- <prompt>                         un prompt, uno stream
  -p --input-format stream-json …          i messaggi su STDIN, una riga
                                           JSON ciascuno, un risultato per
                                           messaggio; finisce quando STDIN si
                                           chiude
Rifiuta («error: …», uscita 1) un'opzione che non conosce, un --output-format
diverso da stream-json, lo stream-json senza --verbose, un --permission-mode
diverso da dontAsk, un modello Fable. «--version» stampa una versione finta.

Le scene, dal testo:
  Elenca tutte le parole in codice …     le parole delle istruzioni caricate
  Leggi il file src/a.php e il file sub/nota.txt …
                                         due Read, poi le parole
  Senza leggere file, qual è la parola … la parola del CLAUDE.md caricato
  Senza leggere file, elenca …           le parole delle istruzioni caricate
  Leggi src/a.php, …                     un Read, poi «letto»
  Rispondi solo: ok                      «ok»
  /compact, /clear                       come Claude Code, zero turni
I token di una richiesta crescono con le istruzioni caricate: 3.000, più un
quarto dei caratteri, più 20 per ogni file di istruzioni (finti).

Ogni invocazione aggiunge a FINTO_LOG, se c'è, una riga JSON: argv, cwd,
prompt, chiave (ANTHROPIC_API_KEY nell'ambiente?), effort_env
(CLAUDE_CODE_EFFORT_LEVEL?), auto_memoria_spenta
(CLAUDE_CODE_DISABLE_AUTO_MEMORY=1?), stdin_nullo, git (la cartella ha
.git?), file (i file della cartella) e, con FINTO_SPAZIO, risposte (c'era
<spazio>/risposte/?); in stream-json anche una riga per messaggio.

Le variabili per mettere alla prova i controlli (=1 per accendere):
  FINTO_COMMENTO_VISIBILE    il commento HTML resta nel contesto
  FINTO_BACKTICK_IMPORTA     un @percorso fra backtick si importa
  FINTO_IMPORT_ASSENTE       l'import non si carica
  FINTO_LOCALE_ASSENTE       CLAUDE.local.md non si carica
  FINTO_REGOLA_ALL_AVVIO     la regola con paths si carica all'avvio
  FINTO_ANNIDATO_ALL_AVVIO   sub/CLAUDE.md si carica all'avvio
  FINTO_REGOLA_NON_CARICA    il Read di un file che corrisponde non carica la
                             regola
  FINTO_ANNIDATO_NON_CARICA  il Read in sub/ non carica sub/CLAUDE.md
  FINTO_NON_LEGGE            Claude non legge i file che il prompt chiede
  FINTO_READ_ERRORE          ogni Read finisce con un errore
  FINTO_ELENCA_LETTI         fra le parole anche quelle dei file letti
  FINTO_NON_LA_SO            ogni elenco risponde NON LA SO
  FINTO_PRIMA_SENZA_PAROLA   al primo messaggio la risposta non ha la parola
  FINTO_MODIFICA_APPLICATA   la modifica a CLAUDE.md vale subito
  FINTO_COMPACT_SENZA_RICARICA  dopo /compact niente si ricarica
  FINTO_COMPACT_VECCHIO      dopo /compact l'hook scatta, ma il contenuto è
                             quello di prima
  FINTO_NON_COMPATTA         /compact non compatta: niente compact_boundary
  FINTO_CLEAR_VECCHIO        dopo /clear il contenuto è quello di prima
  FINTO_CLEAR_SENZA_RESET    /clear senza conversation_reset
  FINTO_REGOLA_RESTA         dopo /compact la regola con paths torna con la
                             compaction (load_reason compact)
  FINTO_REGOLA_NON_TORNA     dopo /compact la regola non si ricarica più
  FINTO_REGOLA_RESTA_MUTA    dopo /compact la regola con paths resta nel
                             contesto, senza nessun evento dell'hook, e non si
                             ricarica: ciò che ha visto la prova del corso del
                             7 novembre 2026, in una sessione sola
  FINTO_SENZA_HOOK           non fa girare l'hook
  FINTO_TRONCO               in -p esce prima del risultato
  FINTO_ERRORE               in -p il risultato è un errore
  FINTO_TRONCO_AL=k          in stream-json esce al messaggio k, senza il suo
                             risultato
  FINTO_ERRORE_AL=k          in stream-json il risultato del messaggio k è un
                             errore
  FINTO_MUTO                 in stream-json non risponde mai
  FINTO_ESITO_KO_SE=t        esce 1 senza stampare se il prompt, o un
                             messaggio, contiene t
Uscita: 0 lo stream · 1 FINTO_ESITO_KO_SE, un argomento rifiutato, un prompt
        che il finto non conosce
"""
import datetime
import fnmatch
import json
import os
import re
import subprocess
import sys
import uuid
from typing import Dict, List, Optional, Tuple

OPZIONI = {"-p": 0, "--print": 0, "--verbose": 0, "--strict-mcp-config": 0,
           "--no-session-persistence": 0, "--model": 1, "--effort": 1,
           "--allowedTools": 1, "--output-format": 1, "--input-format": 1,
           "--permission-mode": 1, "--permission-prompts": 1,
           "--setting-sources": 1, "--tools": 1}
RE_PAROLA = re.compile(r"\b[A-Z]+-[A-Z]{6}\b")
RE_COMMENTO = re.compile(r"<!--.*?-->", re.S)
RE_CODICE = re.compile(r"`[^`\n]*`")
RE_IMPORT = re.compile(r"(?<![\w`])@([\w./-]+)")
RE_IMPORT_BACKTICK = re.compile(r"`@([\w./-]+)`")
MODELLO = "claude-finto"


class Rifiutato(Exception):
    """Argomenti che il finto non accetta: il messaggio d'errore."""


def acceso(nome: str) -> bool:
    return os.environ.get(nome) == "1"


def ora() -> str:
    return datetime.datetime.now(datetime.timezone.utc).strftime(
        "%Y-%m-%dT%H:%M:%S.000Z")


def argomenti(argv: List[str]) -> Tuple[Dict[str, str], Optional[str]]:
    """(le opzioni con i loro valori, il prompt o None in stream-json)."""
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
    return opzioni, None


def controlla_opzioni(opzioni: Dict[str, str], prompt: Optional[str]) -> None:
    if opzioni.get("--output-format") != "stream-json":
        raise Rifiutato("error: il finto vuole --output-format stream-json")
    if "--verbose" not in opzioni:
        raise Rifiutato("error: stream-json requires --verbose")
    if opzioni.get("--permission-mode") != "dontAsk":
        raise Rifiutato("error: il finto vuole --permission-mode dontAsk")
    if "fable" in opzioni.get("--model", "").lower():
        raise Rifiutato("error: niente Fable nelle prove")
    if prompt is None and opzioni.get("--input-format") != "stream-json":
        raise Rifiutato("error: manca il prompt dopo --")
    if prompt is not None and "--input-format" in opzioni:
        raise Rifiutato("error: con --input-format stream-json niente prompt")


def registra(dato: dict) -> None:
    percorso = os.environ.get("FINTO_LOG")
    if not percorso:
        return
    with open(percorso, "a", encoding="utf-8") as fh:
        fh.write(json.dumps(dato, ensure_ascii=False) + "\n")


def file_qui() -> List[str]:
    visti = []
    for radice, cartelle, nomi in os.walk("."):
        cartelle[:] = [c for c in cartelle if c != ".git"]
        for nome in nomi:
            visti.append(os.path.relpath(os.path.join(radice, nome), "."))
    return sorted(visti)


def registra_avvio(argv: List[str], prompt: Optional[str]) -> None:
    riga = {"argv": argv, "cwd": os.getcwd(), "prompt": prompt,
            "chiave": "ANTHROPIC_API_KEY" in os.environ,
            "effort_env": "CLAUDE_CODE_EFFORT_LEVEL" in os.environ,
            "auto_memoria_spenta":
                os.environ.get("CLAUDE_CODE_DISABLE_AUTO_MEMORY") == "1",
            "stdin_nullo": prompt is not None and os.path.samestat(
                os.fstat(0), os.stat(os.devnull)),
            "git": os.path.isdir(".git"), "file": file_qui()}
    spazio = os.environ.get("FINTO_SPAZIO")
    if spazio:
        riga["risposte"] = os.path.exists(os.path.join(spazio, "risposte"))
    registra(riga)


def emetti(evento: dict) -> None:
    print(json.dumps(evento, ensure_ascii=False), flush=True)


def leggi(rel: str) -> str:
    with open(rel, encoding="utf-8", errors="replace") as fh:
        return fh.read()


def frontmatter(testo: str) -> Tuple[List[str], str]:
    """(i globs di paths, il corpo senza il frontmatter)."""
    if not testo.startswith("---\n"):
        return [], testo
    fine = testo.find("\n---\n", 4)
    if fine < 0:
        return [], testo
    globs, dentro = [], False
    for riga in testo[4:fine].splitlines():
        if riga.startswith("paths:"):
            dentro = True
        elif dentro and riga.strip().startswith("- "):
            globs.append(riga.strip()[2:].strip().strip("\"'"))
        else:
            dentro = False
    return globs, testo[fine + 5:]


def corrisponde(rel: str, glob: str) -> bool:
    if fnmatch.fnmatch(rel, glob):
        return True
    return glob.startswith("**/") and fnmatch.fnmatch(
        os.path.basename(rel), glob[3:])


class Sessione:
    """Ciò che il finto ha nel contesto, e l'hook."""

    def __init__(self, fonti: str) -> None:
        self.cwd = os.getcwd()
        self.fonti = set(fonti.split(",")) if fonti else set()
        self.sid = "finta-" + uuid.uuid4().hex[:12]
        self.istruzioni: Dict[str, str] = {}
        self.regole_caricate: set = set()
        self.annidati: set = set()
        self.compattata = False
        self.da_ricaricare: Optional[str] = None
        self.indice = 0
        self.cumulato = 0
        self.messaggi = 0
        self.messaggi_ricevuti = 0

    # --- l'hook ----------------------------------------------------------
    def hook(self, rel: str, motivo: str, tipo: str = "Project",
             trigger: Optional[str] = None, genitore: Optional[str] = None,
             globs: Optional[List[str]] = None) -> None:
        if acceso("FINTO_SENZA_HOOK"):
            return
        try:
            impostazioni = json.loads(leggi(os.path.join(".claude",
                                                         "settings.json")))
        except (OSError, ValueError):
            return
        gruppi = (impostazioni.get("hooks") or {}).get("InstructionsLoaded")
        evento = {"session_id": self.sid,
                  "transcript_path": "/tmp/finto/trascrizione.jsonl",
                  "cwd": self.cwd, "hook_event_name": "InstructionsLoaded",
                  "file_path": os.path.join(self.cwd, rel),
                  "memory_type": tipo, "load_reason": motivo}
        if trigger:
            evento["trigger_file_path"] = os.path.join(self.cwd, trigger)
        if genitore:
            evento["parent_file_path"] = os.path.join(self.cwd, genitore)
        if globs is not None:
            evento["globs"] = globs
        ambiente = dict(os.environ, CLAUDE_PROJECT_DIR=self.cwd)
        for gruppo in gruppi or []:
            for voce in gruppo.get("hooks") or []:
                if voce.get("type") == "command" and voce.get("command"):
                    subprocess.run(["bash", "-c", voce["command"]],
                                   input=json.dumps(evento), text=True,
                                   env=ambiente, cwd=self.cwd, timeout=30,
                                   stdout=subprocess.DEVNULL)

    # --- i caricamenti ---------------------------------------------------
    def carica_radice(self, motivo: str, dal_disco: bool = True) -> None:
        """CLAUDE.md, i suoi import, CLAUDE.local.md, le regole senza paths."""
        if "project" in self.fonti and os.path.isfile("CLAUDE.md"):
            if dal_disco or "CLAUDE.md" not in self.istruzioni:
                testo = leggi("CLAUDE.md")
                if not acceso("FINTO_COMMENTO_VISIBILE"):
                    testo = RE_COMMENTO.sub("", testo)
                self.istruzioni["CLAUDE.md"] = testo
            self.hook("CLAUDE.md", motivo)
            self.importa(self.istruzioni["CLAUDE.md"])
        if "local" in self.fonti and os.path.isfile("CLAUDE.local.md") \
                and not acceso("FINTO_LOCALE_ASSENTE"):
            self.istruzioni["CLAUDE.local.md"] = leggi("CLAUDE.local.md")
            self.hook("CLAUDE.local.md", motivo, "Local")
        for rel, globs, corpo in self.regole():
            if not globs or acceso("FINTO_REGOLA_ALL_AVVIO") or (
                    motivo == "compact" and acceso("FINTO_REGOLA_RESTA")):
                self.istruzioni[rel] = corpo
                self.hook(rel, motivo)
        if acceso("FINTO_ANNIDATO_ALL_AVVIO") and os.path.isfile(
                os.path.join("sub", "CLAUDE.md")):
            self.istruzioni["sub/CLAUDE.md"] = leggi("sub/CLAUDE.md")
            self.hook("sub/CLAUDE.md", motivo)

    def importa(self, testo: str) -> None:
        if acceso("FINTO_IMPORT_ASSENTE"):
            return
        nomi = RE_IMPORT.findall(RE_CODICE.sub("", testo))
        if acceso("FINTO_BACKTICK_IMPORTA"):
            nomi += RE_IMPORT_BACKTICK.findall(testo)
        for rel in nomi:
            if os.path.isfile(rel):
                self.istruzioni[rel] = leggi(rel)
                self.hook(rel, "include", genitore="CLAUDE.md")

    def regole(self) -> List[Tuple[str, List[str], str]]:
        cartella = os.path.join(".claude", "rules")
        if "project" not in self.fonti or not os.path.isdir(cartella):
            return []
        trovate = []
        for nome in sorted(os.listdir(cartella)):
            if nome.endswith(".md"):
                rel = ".claude/rules/" + nome
                globs, corpo = frontmatter(leggi(rel))
                trovate.append((rel, globs, corpo))
        return trovate

    def dopo_lettura(self, rel: str) -> None:
        """La regola che corrisponde e il CLAUDE.md della cartella del file."""
        for regola, globs, corpo in self.regole():
            if not globs or regola in self.regole_caricate \
                    or acceso("FINTO_REGOLA_NON_CARICA") \
                    or (self.compattata and acceso("FINTO_REGOLA_NON_TORNA")):
                continue
            if any(corrisponde(rel, g) for g in globs):
                self.regole_caricate.add(regola)
                self.istruzioni[regola] = corpo
                self.hook(regola, "path_glob_match", trigger=rel, globs=globs)
        cartella = os.path.dirname(rel)
        annidato = os.path.join(cartella, "CLAUDE.md") if cartella else ""
        if annidato and os.path.isfile(annidato) \
                and annidato not in self.annidati \
                and not acceso("FINTO_ANNIDATO_NON_CARICA"):
            self.annidati.add(annidato)
            self.istruzioni[annidato] = leggi(annidato)
            self.hook(annidato, "nested_traversal", trigger=rel)

    def compatta(self) -> None:
        """Dopo /compact: le regole con paths e i CLAUDE.md annidati escono
        dal contesto, la radice si ricarica al messaggio dopo. Con
        FINTO_REGOLA_RESTA_MUTA le regole con paths restano, già caricate."""
        resta = acceso("FINTO_REGOLA_RESTA_MUTA")
        for rel, globs, _ in self.regole():
            if globs and not acceso("FINTO_REGOLA_ALL_AVVIO") and not resta:
                self.istruzioni.pop(rel, None)
        for annidato in self.annidati:
            self.istruzioni.pop(annidato, None)
        if not resta:
            self.regole_caricate.clear()
        self.annidati.clear()
        self.compattata = True
        if not acceso("FINTO_COMPACT_SENZA_RICARICA"):
            self.da_ricaricare = "compact"

    def azzera(self) -> None:
        self.istruzioni = {} if not acceso("FINTO_CLEAR_VECCHIO") \
            else self.istruzioni
        self.regole_caricate.clear()
        self.annidati.clear()
        self.sid = "finta-" + uuid.uuid4().hex[:12]
        self.cumulato = 0
        self.da_ricaricare = "clear"

    def prima_del_messaggio(self) -> None:
        if self.messaggi == 0:
            self.carica_radice("session_start")
        elif self.da_ricaricare == "compact":
            self.carica_radice("compact",
                               dal_disco=not acceso("FINTO_COMPACT_VECCHIO"))
        elif self.da_ricaricare == "clear":
            self.carica_radice("session_start",
                               dal_disco=not acceso("FINTO_CLEAR_VECCHIO"))
        elif acceso("FINTO_MODIFICA_APPLICATA") and "CLAUDE.md" \
                in self.istruzioni:
            testo = RE_COMMENTO.sub("", leggi("CLAUDE.md"))
            self.istruzioni["CLAUDE.md"] = testo
        self.da_ricaricare = None
        self.messaggi += 1

    # --- ciò che dice ----------------------------------------------------
    def parole(self, letti: Dict[str, str]) -> List[str]:
        testi = list(self.istruzioni.values())
        if acceso("FINTO_ELENCA_LETTI"):
            testi += list(letti.values())
        trovate: List[str] = []
        for testo in testi:
            for parola in RE_PAROLA.findall(testo):
                if parola not in trovate:
                    trovate.append(parola)
        return trovate

    def token(self, extra: int = 0) -> dict:
        caratteri = sum(len(t) for t in self.istruzioni.values()) + extra
        totale = 3000 + caratteri // 4 + 20 * len(self.istruzioni)
        return {"input_tokens": 3, "cache_creation_input_tokens": 100,
                "cache_read_input_tokens": totale - 103, "output_tokens": 10}


def init(s: Sessione, strumenti: List[str]) -> None:
    emetti({"type": "system", "subtype": "init", "cwd": s.cwd,
            "session_id": s.sid, "model": MODELLO, "tools": strumenti,
            "permissionMode": "dontAsk",
            "claude_code_version": "2.1.999 (finto)",
            "memory_paths": {"auto": "/home/finto/.claude/projects/x/memory"}})


def assistente(s: Sessione, blocchi: List[dict], uso: dict) -> None:
    emetti({"type": "assistant", "message": {
        "model": MODELLO, "id": "msg_" + uuid.uuid4().hex[:12],
        "type": "message", "role": "assistant", "content": blocchi,
        "usage": uso}, "parent_tool_use_id": None, "session_id": s.sid,
        "uuid": str(uuid.uuid4())})


def utente(s: Sessione, contenuto: object) -> None:
    emetti({"type": "user", "message": {"role": "user",
                                        "content": contenuto},
            "parent_tool_use_id": None, "session_id": s.sid,
            "uuid": str(uuid.uuid4()), "timestamp": ora()})


def somma(usi: List[dict]) -> dict:
    return {k: sum(u.get(k, 0) for u in usi) for k in (
        "input_tokens", "cache_creation_input_tokens",
        "cache_read_input_tokens", "output_tokens")}


def modelli(uso: dict) -> dict:
    return {MODELLO: {"inputTokens": uso["input_tokens"],
                      "outputTokens": uso["output_tokens"],
                      "cacheReadInputTokens": uso["cache_read_input_tokens"],
                      "cacheCreationInputTokens":
                          uso["cache_creation_input_tokens"]}}


def guasto(nome: str, s: Sessione, ultimo: bool) -> bool:
    """Vero se il guasto vale per questo risultato: in -p l'ultimo (FINTO_X=1),
    in stream-json quello del messaggio numero FINTO_X_AL."""
    if ultimo:
        return acceso(nome)
    return os.environ.get(nome + "_AL", "") == str(s.messaggi_ricevuti)


def risultato(s: Sessione, testo: str, turni: int, usi: List[dict],
              ultimo: bool, locale: Optional[str] = None,
              millisecondi: Optional[int] = None) -> None:
    if guasto("FINTO_TRONCO", s, ultimo):
        sys.exit(0)
    uso = somma(usi)
    s.cumulato += sum(uso.values())
    evento = {"type": "result", "subtype": "success", "is_error": False,
              "num_turns": turni,
              "duration_ms": millisecondi if millisecondi is not None
              else 1000 * max(turni, 1),
              "result": testo, "session_id": s.sid, "usage": uso,
              "modelUsage": modelli(uso),
              "model_usage_since_last_result": modelli(uso),
              "permission_denials": [], "result_index": s.indice}
    if locale:
        evento["local_command"] = locale
        evento["usage"] = {k: 0 for k in uso}
    if guasto("FINTO_ERRORE", s, ultimo):
        evento.update(subtype="error_during_execution", is_error=True)
    s.indice += 1
    emetti(evento)


def scena_letture(s: Sessione, file: List[str], consentiti: List[str]
                  ) -> Tuple[Dict[str, str], List[dict], int]:
    """I Read di una scena: (i testi letti, gli usage, i turni)."""
    letti: Dict[str, str] = {}
    usi: List[dict] = []
    if acceso("FINTO_NON_LEGGE") or "Read" not in consentiti:
        return letti, usi, 0
    for rel in file:
        ident = "toolu_finto_" + uuid.uuid4().hex[:10]
        uso = s.token(sum(len(t) for t in letti.values()))
        usi.append(uso)
        assistente(s, [{"type": "tool_use", "id": ident, "name": "Read",
                        "input": {"file_path": os.path.join(s.cwd, rel)}}],
                   uso)
        errore = acceso("FINTO_READ_ERRORE")
        testo = "File does not exist. (finto)" if errore else leggi(rel)
        utente(s, [{"type": "tool_result", "tool_use_id": ident,
                    "content": testo, "is_error": errore}])
        if not errore:
            letti[rel] = testo
            s.dopo_lettura(rel)
    return letti, usi, len(file)


def risposta_di(s: Sessione, testo: str, consentiti: List[str]
                ) -> Optional[Tuple[str, int, List[dict]]]:
    """(il testo della risposta, i turni, gli usage) per un prompt; None se
    il finto non lo conosce."""
    testo = testo.strip()
    letti: Dict[str, str] = {}
    usi: List[dict] = []
    turni = 0
    if testo.startswith("Leggi il file src/a.php e il file sub/nota.txt"):
        letti, usi, turni = scena_letture(s, ["src/a.php", "sub/nota.txt"],
                                          consentiti)
        scena = "elenca"
    elif testo.startswith("Leggi src/a.php"):
        letti, usi, turni = scena_letture(s, ["src/a.php"], consentiti)
        scena = "letto"
    elif testo.startswith("Elenca tutte le parole in codice") \
            or testo.startswith("Senza leggere file, elenca"):
        scena = "elenca"
    elif testo.startswith("Senza leggere file, qual è la parola"):
        scena = "parola"
    elif testo == "Rispondi solo: ok":
        scena = "ok"
    else:
        return None
    if scena == "elenca":
        trovate = s.parole(letti)
        risposta = "\n".join(trovate) if trovate \
            and not acceso("FINTO_NON_LA_SO") else "NON LA SO"
    elif scena == "parola":
        trovate = RE_PAROLA.findall(s.istruzioni.get("CLAUDE.md", ""))
        risposta = trovate[0] if trovate and not (
            acceso("FINTO_PRIMA_SENZA_PAROLA") and s.messaggi == 1) \
            else "NON LA SO"
    elif scena == "letto":
        risposta = "letto"
    else:
        risposta = "ok"
    uso = s.token(sum(len(t) for t in letti.values()))
    usi.append(uso)
    assistente(s, [{"type": "text", "text": risposta}], uso)
    return risposta, turni + 1, usi


def compatta(s: Sessione, ultimo: bool) -> None:
    if acceso("FINTO_NON_COMPATTA"):
        risultato(s, "", 0, [], ultimo, millisecondi=10)
        return
    emetti({"type": "system", "subtype": "status", "status": "compacting",
            "session_id": s.sid})
    emetti({"type": "system", "subtype": "status", "status": None,
            "compact_result": "success", "session_id": s.sid})
    prima = sum(s.token().values())
    s.compatta()
    emetti({"type": "system", "subtype": "compact_boundary",
            "session_id": s.sid, "compact_metadata": {
                "trigger": "manual", "pre_tokens": prima,
                "post_tokens": 800}})
    utente(s, "This session is being continued from a previous conversation "
              "that ran out of context. (riassunto finto)")
    utente(s, "<local-command-stdout>Compacted </local-command-stdout>")
    uso = {"input_tokens": 2000, "cache_creation_input_tokens": 300,
           "cache_read_input_tokens": 2700, "output_tokens": 800}
    risultato(s, "", 0, [uso], ultimo, locale="compact", millisecondi=2000)
    # usage di una compaction: zero, come in Claude Code; i token sono in
    # model_usage_since_last_result


def azzera(s: Sessione, ultimo: bool) -> None:
    if not acceso("FINTO_CLEAR_SENZA_RESET"):
        emetti({"type": "conversation_reset", "trigger": "clear",
                "new_conversation_id": str(uuid.uuid4()),
                "session_id": s.sid})
    s.azzera()
    init(s, [])
    risultato(s, "", 0, [], ultimo, locale="clear", millisecondi=21)


def strumenti_di(opzioni: Dict[str, str]) -> List[str]:
    return [t for t in opzioni.get("--tools", "").split(",") if t]


def modo_prompt(opzioni: Dict[str, str], prompt: str) -> int:
    s = Sessione(opzioni.get("--setting-sources", ""))
    consentiti = strumenti_di(opzioni)
    init(s, consentiti)
    s.prima_del_messaggio()
    fatto = risposta_di(s, prompt, consentiti)
    if fatto is None:
        sys.stderr.write("claude finto: prompt sconosciuto: %s\n" % prompt)
        return 1
    risposta, turni, usi = fatto
    risultato(s, risposta, turni, usi, True)
    return 0


def modo_stream(opzioni: Dict[str, str], chiudi_su: str) -> int:
    """Un messaggio per riga di STDIN, appena arriva: chi scrive aspetta il
    risultato prima di mandare il prossimo."""
    s = Sessione(opzioni.get("--setting-sources", ""))
    consentiti = strumenti_di(opzioni)
    while True:
        riga = sys.stdin.readline()
        if not riga:
            return 0
        if not riga.strip():
            continue
        messaggio = json.loads(riga)
        testo = messaggio["message"]["content"]
        s.messaggi_ricevuti += 1
        registra({"messaggio": testo, "cwd": s.cwd})
        if chiudi_su and chiudi_su in testo:
            return 1
        if acceso("FINTO_MUTO"):
            continue
        init(s, consentiti)
        if testo.strip() == "/compact":
            compatta(s, False)
            continue
        if testo.strip() == "/clear":
            azzera(s, False)
            continue
        s.prima_del_messaggio()
        fatto = risposta_di(s, testo, consentiti)
        if fatto is None:
            sys.stderr.write("claude finto: messaggio sconosciuto: %s\n"
                             % testo)
            return 1
        risposta, turni, usi = fatto
        risultato(s, risposta, turni, usi, False)


def main(argv: List[str]) -> int:
    if argv == ["--version"]:
        print("2.1.999 (Claude Code, finto)")
        return 0
    try:
        opzioni, prompt = argomenti(argv)
        controlla_opzioni(opzioni, prompt)
    except Rifiutato as exc:
        sys.stderr.write(str(exc) + "\n")
        return 1
    registra_avvio(argv, prompt)
    chiudi_su = os.environ.get("FINTO_ESITO_KO_SE", "")
    if prompt is not None:
        if chiudi_su and chiudi_su in prompt:
            return 1
        return modo_prompt(opzioni, prompt)
    return modo_stream(opzioni, chiudi_su)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
