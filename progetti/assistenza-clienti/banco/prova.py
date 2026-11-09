#!/usr/bin/env python3
"""prova.py -- il banco di prova dell'assistente di CiaspoLink.

Mette un assistente (una cartella con system-prompt.md, strumenti.json e,
facoltativo, regole-escalation.md, che finisce in coda al system prompt) davanti
a Claude Code, con il server MCP del banco al posto dei sistemi veri e nessuno
strumento integrato. Tre comandi:

  casi           ogni caso è una sola chiamata (uno snapshot): il messaggio del
                 cliente, il server sui dati dello scenario, le asserzioni. Per
                 misurare e confrontare due versioni. Tre alla volta.
  conversazione  una persona simulata (l'agente «cliente», su Haiku) parla con
                 l'assistente per alcuni giri: per scoprire che cosa non va.
  giudica        l'agente «giudice» applica la rubrica a una conversazione nel
                 formato di golden/; totale e verdetto li calcola il codice.

Ogni chiamata gira in una cartella temporanea fuori dal repository, con un
ambiente ripulito (solo HOME, PATH, LANG, USER, SHELL, TERM e, se ci sono, le
variabili di proxy e certificati e CLAUDE_CONFIG_DIR: niente chiavi API, Claude
Code usa l'abbonamento), --setting-sources project,local, permessi
--permission-mode dontAsk con i soli strumenti del server consentiti.

Una versione con uno strumento che non si può collegare, un caso malformato, un
--scenario che non è uno scenario si fermano qui, prima di ogni chiamata. Una
chiamata senza il server del banco (l'evento init di Claude Code dice che non
si è collegato, o non ne elenca gli strumenti) non è finita.

Uso:    python3 prova.py casi --versione DIR --uscita DIR [--casi DIR]
          [--kb DIR] [--paralleli 1-3] [--schema FILE]
        python3 prova.py conversazione --versione DIR --scenario FILE
          --uscita DIR [--giri N]
        python3 prova.py giudica --conversazione FILE [--conversazione FILE...]
          --uscita DIR
Uscita: 0 = ogni chiamata è finita bene (le asserzioni e i verdetti sono dati e
        non decidono l'uscita) · 1 = una chiamata non è finita · 2 = precondizione
"""
from __future__ import annotations

import argparse
import concurrent.futures
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any, Dict, List, Optional, Sequence, Tuple

# Niente __pycache__ nello spazio di lavoro, anche senza python3 -B: sta prima
# degli import dei moduli locali.
sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent))
import lib_banco  # noqa: E402
import motore  # noqa: E402

QUI = Path(__file__).resolve().parent
PROGETTO = QUI.parent
SERVER = QUI / "server"
AGENTI = QUI / ".claude" / "agents"
STRUMENTI_CONSENTITI = "mcp__assistenza__*"
AMBIENTE_TENUTO = ("HOME", "PATH", "LANG", "USER", "SHELL", "TERM",
                   "HTTPS_PROXY", "HTTP_PROXY", "NO_PROXY", "https_proxy",
                   "http_proxy", "no_proxy", "NODE_EXTRA_CA_CERTS",
                   "SSL_CERT_FILE", "CLAUDE_CONFIG_DIR")
MODELLO_ASSISTENTE = "sonnet"
MODELLO_PERSONA = "haiku"
EFFORT = "low"
SECONDI_MAX = 300
# L'ambiente del server sta fuori dal repository e dalle sue copie: tiene
# fuori le migliaia di file di un .venv, e si riusa fra gli spazi di lavoro.
AMBIENTE_UV = Path.home() / ".cache" / "corso-claude-code" / "banco-server"
FINE_PERSONA = "FINE"
GIRI_MAX = 4
SCHEMA_GIUDICE = {
    "type": "object",
    "properties": {
        "punteggi": {
            "type": "object",
            "properties": {
                "C%d" % i: {"type": ["integer", "null"],
                            "minimum": 0, "maximum": 2}
                for i in range(1, 10)},
            "required": ["C%d" % i for i in range(1, 10)],
        },
        "motivazioni": {"type": "object"},
    },
    "required": ["punteggi", "motivazioni"],
}


class Precondizione(Exception):
    """Qualcosa che impedisce di partire: esce 2."""


def _gia_usata(uscita: Path) -> Precondizione:
    """La cartella di uscita c'è già: una prova non riuscita si cancella e si
    rilancia con lo stesso nome, perché le verifiche leggono nomi fissi."""
    return Precondizione(f"{uscita} esiste già: cancellatela e rilanciate con "
                         "lo stesso nome (un'altra uscita solo per una prova "
                         "in più)")


def _ambiente() -> Dict[str, str]:
    env = {k: os.environ[k] for k in AMBIENTE_TENUTO if k in os.environ}
    env.setdefault("LANG", "C.UTF-8")
    return env


def _prepara_server() -> None:
    """Prepara l'ambiente del server dalle versioni di uv.lock. Se lo facesse
    Claude Code avviando il server, la prima volta scadrebbe il tempo."""
    env = dict(_ambiente(), UV_PROJECT_ENVIRONMENT=str(AMBIENTE_UV))
    try:
        fatto = subprocess.run(
            ["uv", "sync", "--frozen", "--quiet", "--directory", str(SERVER)],
            env=env, stdin=subprocess.DEVNULL, capture_output=True, text=True,
            encoding="utf-8", timeout=SECONDI_MAX, check=False)
    except (OSError, subprocess.TimeoutExpired) as exc:
        raise Precondizione(f"non riesco a lanciare uv: {exc}") from exc
    if fatto.returncode != 0:
        raise Precondizione("il server non si prepara: "
                            + fatto.stderr.strip()[:300])


def _temporanea() -> Path:
    """Una cartella di lavoro fuori dal repository e fuori da ~/.claude."""
    base = tempfile.gettempdir()
    if ".claude" in Path(base).parts and os.path.isdir("/tmp"):
        base = "/tmp"
    return Path(tempfile.mkdtemp(prefix="banco-", dir=base))


def _pulisci(cartella: Path) -> None:
    """Cancella la cartella temporanea e la sessione salvata per quella
    cartella, se una conversazione l'ha lasciata."""
    if cartella.name.startswith("banco-") and not cartella.is_symlink():
        shutil.rmtree(cartella, ignore_errors=True)
    mangle = re.sub(r"[^A-Za-z0-9]", "-", str(cartella))
    configurazione = os.environ.get("CLAUDE_CONFIG_DIR") or os.path.join(
        os.environ.get("HOME", "/nonexistent"), ".claude")
    sessioni = Path(configurazione) / "projects" / mangle
    if sessioni.is_dir() and not sessioni.is_symlink():
        shutil.rmtree(sessioni, ignore_errors=True)


def _system_prompt(versione: Path, destinazione: Path) -> Path:
    """Il system prompt effettivo della versione."""
    testo = (versione / "system-prompt.md").read_text(encoding="utf-8")
    regole = versione / "regole-escalation.md"
    if regole.is_file():
        testo = testo.rstrip("\n") + "\n\n" \
            + regole.read_text(encoding="utf-8")
    destinazione.write_text(testo, encoding="utf-8")
    return destinazione


def _controlla_versione(versione: Path) -> None:
    """I file della versione e le sue definizioni, le stesse che il server
    caricherà: una definizione sbagliata si dice qui, prima di ogni chiamata."""
    for nome in ("system-prompt.md", "strumenti.json"):
        if not (versione / nome).is_file():
            raise Precondizione(f"la versione {versione} non ha {nome}")
    try:
        motore.carica_strumenti(versione / "strumenti.json")
    except motore.Problema as exc:
        raise Precondizione(str(exc)) from exc


def _cartella_kb(kb: Optional[str]) -> Path:
    """La base di conoscenza: quella di --kb, che deve essere una cartella,
    o quella del progetto."""
    if kb is None:
        return PROGETTO / "kb"
    percorso = Path(kb).resolve()
    if not percorso.is_dir():
        raise Precondizione(f"--kb non è una cartella: {percorso}")
    return percorso


def _controlla_scenario(scenario: Dict[str, Any], percorso: Path) -> None:
    """Ciò che serve a una conversazione: l'id, il primo messaggio, la scheda
    del cliente simulato. Un file di golden/ non è uno scenario."""
    for campo in ("id", "messaggio_iniziale"):
        valore = scenario.get(campo)
        if not isinstance(valore, str) or not valore.strip():
            raise Precondizione(f"{percorso} non è uno scenario: manca il campo "
                                f"«{campo}»")
    if not isinstance(scenario.get("persona"), dict):
        raise Precondizione(f"{percorso} non è uno scenario: manca il campo "
                            "«persona»")


def _config_mcp(ws: Path, scenario: Path, kb: Path, strumenti: Path,
                registro: Path) -> Path:
    config = {"mcpServers": {"assistenza": {
        "command": "uv",
        "args": ["run", "--frozen", "--quiet", "--directory", str(SERVER),
                 "server_banco.py"],
        "env": {"BANCO_SCENARIO": str(scenario), "BANCO_KB": str(kb),
                "BANCO_STRUMENTI": str(strumenti),
                "BANCO_REGISTRO": str(registro),
                "UV_PROJECT_ENVIRONMENT": str(AMBIENTE_UV),
                "FASTMCP_CHECK_FOR_UPDATES": "off"}}}}
    percorso = ws / "mcp.json"
    percorso.write_text(json.dumps(config, indent=1), encoding="utf-8")
    return percorso


def _riga_assistente(sp: Path, config: Path, messaggio: str,
                     resume: Optional[str]) -> List[str]:
    argv = ["claude", "-p", "--system-prompt-file", str(sp), "--tools", "",
            "--mcp-config", str(config), "--strict-mcp-config",
            "--allowedTools", STRUMENTI_CONSENTITI,
            "--permission-mode", "dontAsk", "--permission-prompts", "none",
            "--setting-sources", "project,local",
            "--model", MODELLO_ASSISTENTE, "--effort", EFFORT,
            "--output-format", "stream-json", "--verbose"]
    if resume:
        argv += ["--resume", resume]
    return argv + ["--", messaggio]


def _lancia(argv: Sequence[str], cwd: Path) -> Tuple[int, str, str]:
    """Una chiamata di claude. (uscita, STDOUT, STDERR); un timeout è
    un'uscita diversa da zero."""
    try:
        fatto = subprocess.run(list(argv), cwd=str(cwd), env=_ambiente(),
                               stdin=subprocess.DEVNULL,
                               capture_output=True, text=True,
                               encoding="utf-8", timeout=SECONDI_MAX,
                               check=False)
    except subprocess.TimeoutExpired:
        return 124, "", f"più di {SECONDI_MAX} secondi"
    except OSError as exc:
        raise Precondizione(f"non riesco a lanciare claude: {exc}") from exc
    return fatto.returncode, fatto.stdout, fatto.stderr


def _un_caso(caso: Dict[str, Any], versione: Path, uscita: Path,
             kb: Path, scenari: Path, schema: Optional[str]) -> Dict[str, Any]:
    """Una chiamata su un caso: scrive tutto nella cartella del caso."""
    cartella = uscita / caso["id"]
    cartella.mkdir(parents=True)
    ws = _temporanea()
    try:
        registro = cartella / "registro.jsonl"
        sp = _system_prompt(versione, cartella / "system-prompt.usato.md")
        config = _config_mcp(ws, scenari / caso["scenario"], kb,
                             versione / "strumenti.json", registro)
        argv = _riga_assistente(sp, config, caso["messaggio"], None)
        argv[-2:-2] = ["--no-session-persistence"] \
            + (["--json-schema", schema] if schema else [])
        rc, out, err = _lancia(argv, ws)
    finally:
        _pulisci(ws)
    (cartella / "stream.jsonl").write_text(out, encoding="utf-8")
    if err.strip():
        (cartella / "stderr.txt").write_text(err, encoding="utf-8")
    letto = lib_banco.leggi_stream(out)
    chiamate = lib_banco.leggi_registro(registro)
    azioni = lib_banco.azioni_da_registro(chiamate)
    esiti = lib_banco.valuta(caso, chiamate, letto["risposta"])
    esito = {"caso": caso["id"], "titolo": caso.get("titolo", ""),
             "versione": versione.name,
             "scenario": caso["scenario"],
             "completa": letto["completa"] and rc == 0,
             "problema": letto["problema"],
             "errore": letto["errore"],
             "soddisfatte": sum(1 for e in esiti if e["esito"]),
             "totale": len(esiti), "asserzioni": esiti,
             "chiamate": azioni, "risposta": letto["risposta"],
             "strutturato": letto["strutturato"],
             "token_prima_richiesta": letto["token_prima_richiesta"],
             "turni": letto["turni"], "secondi": letto["secondi"]}
    (cartella / "esito.json").write_text(
        json.dumps(esito, ensure_ascii=False, indent=1) + "\n",
        encoding="utf-8")
    (cartella / "trascrizione.md").write_text(
        lib_banco.trascrizione_markdown(
            f"{caso['id']} — {esito['titolo']} ({versione.name})",
            [{"ruolo": "cliente", "testo": caso["messaggio"]},
             {"ruolo": "assistente", "testo": letto["risposta"],
              "azioni": azioni}]), encoding="utf-8")
    return esito


def _carica_casi(cartella: Path, scenari: Path, uscita: Path
                 ) -> List[Dict[str, Any]]:
    percorsi = sorted(cartella.glob("*.json"))
    if not percorsi:
        raise Precondizione(f"nessun caso (*.json) in {cartella}")
    casi = [lib_banco.carica_caso(p, scenari) for p in percorsi]
    visti: set = set()
    for percorso, caso in zip(percorsi, casi):
        if caso["id"] in visti:
            raise Precondizione(f"due casi con lo stesso id, {caso['id']}: "
                                f"{percorso.name} ne ripete uno")
        visti.add(caso["id"])
        if (uscita / caso["id"]).exists():
            raise _gia_usata(uscita)
    return casi


def _leggi_schema(percorso: Optional[str]) -> Optional[str]:
    """Il testo JSON di uno schema per --json-schema, o None."""
    if percorso is None:
        return None
    try:
        return json.dumps(json.loads(Path(percorso).read_text(encoding="utf-8")))
    except (OSError, UnicodeDecodeError, ValueError) as exc:
        raise Precondizione(f"schema illeggibile: {percorso}: {exc}") from exc


def comando_casi(a: argparse.Namespace) -> int:
    versione = Path(a.versione).resolve()
    _controlla_versione(versione)
    scenari = PROGETTO / "scenari"
    uscita = Path(a.uscita).resolve()
    cartella_casi = Path(a.casi).resolve() if a.casi else QUI / "casi"
    casi = _carica_casi(cartella_casi, scenari, uscita)
    kb = _cartella_kb(a.kb)
    schema = _leggi_schema(a.schema)
    _prepara_server()
    uscita.mkdir(parents=True, exist_ok=True)
    with concurrent.futures.ThreadPoolExecutor(a.paralleli) as pool:
        esiti = list(pool.map(
            lambda c: _un_caso(c, versione, uscita, kb, scenari, schema), casi))
    problemi = 0
    for esito in esiti:
        finita = esito["completa"] and not esito["errore"]
        problemi += 0 if finita else 1
        stato = "" if finita else "  non è finita"
        print(f"{esito['caso']:<10} {versione.name:<8} asserzioni "
              f"{esito['soddisfatte']}/{esito['totale']}  "
              f"{len(esito['chiamate'])} chiamate  "
              f"{esito['token_prima_richiesta']} token  "
              f"{esito['secondi']} s{stato}")
        if esito["problema"]:
            print(f"{esito['caso']:<10} {esito['problema']}: questa prova "
                  "non conta, rifatela")
    return 1 if problemi else 0


def _scheda_persona(scenario: Dict[str, Any]) -> Dict[str, Any]:
    """Ciò che la persona sa di sé, e che può dire. La verità nascosta resta
    al server: la persona ne vede solo la propria linea, se è sua."""
    persona = dict(scenario["persona"])
    verita = scenario.get("verita_nascosta") or {}
    propria = (persona.get("cliente") or {}).get("id_cliente") \
        == (verita.get("cliente") or {}).get("id_cliente")
    if propria and verita.get("linee") \
            and "dice di essere" not in str(persona.get("ruolo", "")):
        persona["indirizzo"] = verita["linee"][0].get("indirizzo")
    return {"persona": persona, "cose_che_puoi_dire": scenario.get("seguiti"),
            "canale": scenario.get("canale")}


def _prompt_persona(scenario: Dict[str, Any], turni: List[Dict[str, Any]]) -> str:
    testo = "\n".join(f"{t['ruolo']}: {t['testo']}" for t in turni)
    return ("<persona>\n"
            + json.dumps(_scheda_persona(scenario), ensure_ascii=False, indent=1)
            + "\n</persona>\n<conversation>\n" + testo + "\n</conversation>")


def _persona(ws: Path, scenario: Dict[str, Any], turni: List[Dict[str, Any]]
             ) -> Tuple[Optional[str], Optional[str]]:
    """Il prossimo messaggio del cliente, o FINE; (testo, problema)."""
    argv = ["claude", "-p", "--agent", "cliente", "--tools", "",
            "--strict-mcp-config", "--permission-mode", "dontAsk",
            "--permission-prompts", "none",
            "--setting-sources", "project,local",
            "--model", MODELLO_PERSONA, "--effort", EFFORT,
            "--output-format", "json", "--no-session-persistence",
            "--", _prompt_persona(scenario, turni)]
    rc, out, err = _lancia(argv, ws)
    try:
        dati = json.loads(out)
    except ValueError:
        return None, f"persona: uscita {rc}: {err.strip()[:200]}"
    if rc != 0 or dati.get("is_error"):
        return None, f"persona: uscita {rc}"
    return str(dati.get("result") or "").strip(), None


def _giri(a: argparse.Namespace, scenario: Dict[str, Any], ws: Path,
          sp: Path, config: Path, registro: Path, stream: Any
          ) -> Tuple[List[Dict[str, Any]], Optional[str], Dict[str, float]]:
    """I giri della conversazione; (turni, problema, conteggi)."""
    turni: List[Dict[str, Any]] = []
    sessione: Optional[str] = None
    conteggi = {"secondi": 0.0, "turni": 0}
    messaggio = scenario["messaggio_iniziale"]
    gia_viste = 0
    for giro in range(a.giri):
        rc, out, err = _lancia(
            _riga_assistente(sp, config, messaggio, sessione), ws)
        stream.write(out)
        letto = lib_banco.leggi_stream(out)
        if rc != 0 or not letto["completa"] or letto["errore"]:
            motivo = letto["problema"] or f"uscita {rc}"
            return turni, f"assistente, giro {giro + 1}: {motivo}", conteggi
        sessione = letto["sessione"] or sessione
        conteggi["secondi"] += letto["secondi"]
        conteggi["turni"] += letto["turni"]
        chiamate = lib_banco.leggi_registro(registro)
        nuove = lib_banco.azioni_da_registro(chiamate[gia_viste:])
        gia_viste = len(chiamate)
        turni.append({"ruolo": "cliente", "testo": messaggio})
        risposta: Dict[str, Any] = {"ruolo": "assistente",
                                    "testo": letto["risposta"]}
        if nuove:
            risposta["azioni"] = nuove
        turni.append(risposta)
        if giro == a.giri - 1:
            break
        prossimo, problema = _persona(ws, scenario, turni)
        if problema:
            return turni, problema, conteggi
        if prossimo is None or prossimo.upper() == FINE_PERSONA:
            break
        messaggio = prossimo
    return turni, None, conteggi


def comando_conversazione(a: argparse.Namespace) -> int:
    versione = Path(a.versione).resolve()
    _controlla_versione(versione)
    percorso = Path(a.scenario).resolve()
    scenario = lib_banco.carica_scenario(percorso)
    _controlla_scenario(scenario, percorso)
    if not 1 <= a.giri <= GIRI_MAX:
        raise Precondizione(f"--giri va da 1 a {GIRI_MAX}")
    kb = _cartella_kb(a.kb)
    uscita = Path(a.uscita).resolve()
    if uscita.exists():
        raise _gia_usata(uscita)
    _prepara_server()
    uscita.mkdir(parents=True)
    ws = _temporanea()
    try:
        destinazione = ws / ".claude" / "agents"
        destinazione.mkdir(parents=True)
        shutil.copy(AGENTI / "cliente.md", destinazione / "cliente.md")
        registro = uscita / "registro.jsonl"
        sp = _system_prompt(versione, uscita / "system-prompt.usato.md")
        config = _config_mcp(ws, percorso, kb, versione / "strumenti.json",
                             registro)
        with open(uscita / "stream.jsonl", "w", encoding="utf-8") as stream:
            turni, problema, conteggi = _giri(a, scenario, ws, sp, config,
                                              registro, stream)
    finally:
        _pulisci(ws)
    dati = {"id": f"prova-{scenario['id']}", "scenario": scenario["id"],
            "versione": versione.name, "canale": scenario.get("canale"),
            "turni": turni, "secondi": conteggi["secondi"],
            "turni_modello": conteggi["turni"]}
    (uscita / "conversazione.json").write_text(
        json.dumps(dati, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    titolo = f"{scenario['id']} — {scenario.get('titolo', '')} ({versione.name})"
    (uscita / "trascrizione.md").write_text(
        lib_banco.trascrizione_markdown(titolo, turni), encoding="utf-8")
    print(f"{scenario['id']}: {len(turni) // 2} giri, "
          f"{sum(len(t.get('azioni', [])) for t in turni)} chiamate, "
          f"{conteggi['secondi']:.0f} s -- {uscita / 'trascrizione.md'}")
    if problema:
        print(f"non è finita: {problema}")
        return 1
    return 0


def _prompt_giudice(conversazione: Dict[str, Any],
                    scenario: Dict[str, Any]) -> str:
    rubrica = (PROGETTO / "valutazione" / "rubrica.md").read_text(encoding="utf-8")
    tono = (PROGETTO / "tono-di-voce.md").read_text(encoding="utf-8")
    return ("<rubric>\n" + rubrica + "\n</rubric>\n<tone_guide>\n" + tono
            + "\n</tone_guide>\n<scenario>\n"
            + json.dumps(scenario, ensure_ascii=False, indent=1)
            + "\n</scenario>\n<conversation>\n"
            + json.dumps(conversazione.get("turni"), ensure_ascii=False, indent=1)
            + "\n</conversation>")


def _scenario_di(conversazione: Dict[str, Any]) -> Dict[str, Any]:
    codice = str(conversazione.get("scenario", ""))
    numero = codice.replace("SC-", "").lower()
    trovati = sorted((PROGETTO / "scenari").glob(f"sc-{numero}-*.json"))
    if not trovati:
        raise Precondizione(f"scenario di «{codice}» non trovato in scenari/")
    return lib_banco.carica_scenario(trovati[0])


def _da_giudicare(percorsi: List[Path], uscita: Path
                  ) -> List[Tuple[Dict[str, Any], Dict[str, Any], Path]]:
    """Ogni conversazione, con il suo scenario e la cartella del giudizio:
    controllate tutte prima della prima chiamata."""
    lavori = []
    viste: set = set()
    for percorso in percorsi:
        conversazione = lib_banco.carica_scenario(percorso)
        if not isinstance(conversazione.get("turni"), list) \
                or not conversazione["turni"]:
            raise Precondizione(f"{percorso} non è una conversazione: manca il "
                                "campo «turni»")
        nome = str(conversazione.get("id") or percorso.stem)
        if nome in viste:
            raise Precondizione(f"due conversazioni con lo stesso id: {nome}")
        viste.add(nome)
        cartella = uscita / nome
        if cartella.exists():
            raise Precondizione(f"{cartella} esiste già")
        lavori.append((conversazione, _scenario_di(conversazione), cartella))
    return lavori


def _giudica_una(conversazione: Dict[str, Any], scenario: Dict[str, Any],
                 cartella: Path) -> Dict[str, Any]:
    nome = cartella.name
    cartella.mkdir(parents=True)
    ws = _temporanea()
    try:
        destinazione = ws / ".claude" / "agents"
        destinazione.mkdir(parents=True)
        shutil.copy(AGENTI / "giudice.md", destinazione / "giudice.md")
        argv = ["claude", "-p", "--agent", "giudice", "--tools", "",
                "--strict-mcp-config", "--permission-mode", "dontAsk",
                "--permission-prompts", "none",
                "--setting-sources", "project,local",
                "--model", MODELLO_ASSISTENTE, "--effort", EFFORT,
                "--output-format", "json", "--no-session-persistence",
                "--json-schema", json.dumps(SCHEMA_GIUDICE),
                "--", _prompt_giudice(conversazione, scenario)]
        rc, out, err = _lancia(argv, ws)
    finally:
        _pulisci(ws)
    (cartella / "risposta.json").write_text(out, encoding="utf-8")
    try:
        dati = json.loads(out)
    except ValueError:
        return {"id": nome, "finita": False, "problema": f"uscita {rc}: "
                + err.strip()[:200]}
    voti = dati.get("structured_output") or {}
    punteggi = voti.get("punteggi")
    if rc != 0 or dati.get("is_error") or not isinstance(punteggi, dict):
        return {"id": nome, "finita": False, "problema": f"uscita {rc}"}
    totale, esito = lib_banco.verdetto(punteggi)
    verdetto = {"id": nome, "finita": True, "punteggi": punteggi,
                "motivazioni": voti.get("motivazioni"), "totale": totale,
                "verdetto": esito}
    (cartella / "verdetto.json").write_text(
        json.dumps(verdetto, ensure_ascii=False, indent=1) + "\n",
        encoding="utf-8")
    return verdetto


def comando_giudica(a: argparse.Namespace) -> int:
    uscita = Path(a.uscita).resolve()
    percorsi = [Path(p).resolve() for p in a.conversazione]
    lavori = _da_giudicare(percorsi, uscita)
    uscita.mkdir(parents=True, exist_ok=True)
    with concurrent.futures.ThreadPoolExecutor(3) as pool:
        verdetti = list(pool.map(lambda v: _giudica_una(*v), lavori))
    problemi = 0
    for v in verdetti:
        if not v["finita"]:
            problemi += 1
            print(f"{v['id']}: non è finita: {v['problema']}")
            continue
        print(f"{v['id']}: totale {v['totale']} su 18, {v['verdetto']}")
    return 1 if problemi else 0


def _argomenti(argv: Sequence[str]) -> argparse.Namespace:
    p = argparse.ArgumentParser(description="il banco di prova dell'assistente")
    s = p.add_subparsers(dest="comando", required=True)
    c = s.add_parser("casi", help="snapshot con asserzioni")
    c.add_argument("--versione", required=True)
    c.add_argument("--uscita", required=True)
    c.add_argument("--casi")
    c.add_argument("--kb")
    c.add_argument("--paralleli", type=int, choices=(1, 2, 3), default=3)
    c.add_argument("--schema")
    c.set_defaults(fn=comando_casi)
    d = s.add_parser("conversazione", help="persona simulata")
    d.add_argument("--versione", required=True)
    d.add_argument("--scenario", required=True)
    d.add_argument("--uscita", required=True)
    d.add_argument("--giri", type=int, default=GIRI_MAX)
    d.add_argument("--kb")
    d.set_defaults(fn=comando_conversazione)
    g = s.add_parser("giudica", help="il giudice sulla rubrica")
    g.add_argument("--conversazione", required=True, action="append")
    g.add_argument("--uscita", required=True)
    g.set_defaults(fn=comando_giudica)
    return p.parse_args(argv)


def main(argv: Sequence[str]) -> int:
    a = _argomenti(argv)
    try:
        return a.fn(a)
    except (Precondizione, lib_banco.Problema, motore.Problema) as exc:
        print(f"prova: {exc}", file=sys.stderr)
        return 2
    except KeyboardInterrupt:
        print("prova: interrotta", file=sys.stderr)
        return 2
    except Exception as exc:  # mai un traceback: un errore inatteso esce 2
        testo = " ".join(str(exc).split())
        print(f"prova: errore inatteso ({type(exc).__name__}: {testo})",
              file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
