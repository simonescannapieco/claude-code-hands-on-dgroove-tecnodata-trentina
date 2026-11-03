#!/usr/bin/env python3
"""controlla_skill.py -- controlla la cartella di una skill contro le regole
che si leggono dai file: la specifica Agent Skills
(https://agentskills.io/specification) e le best practice di Anthropic
(https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices).
Non dice se la skill funziona: quello lo dicono le prove con
tools/prove_skill.sh.

Uso:    python3 -B -I tools/controlla_skill.py <cartella della skill>
          [--caricamento]
        --caricamento  aggiunge le regole di chi carica la skill su claude.ai
Uscita: 0 nessun errore (gli avvisi possono esserci)
        1 almeno un errore (anche: manca SKILL.md in una cartella che c'è)
        2 argomenti sbagliati, una cartella che non esiste, uno SKILL.md che
          non si riesce a leggere
Stampa su STDOUT una riga per segnalazione, «ERRORE <che cosa>: <perché e
che cosa fare>» o «AVVISO <che cosa>: <perché>», poi i dati (le righe del
corpo, i token stimati) e, per ultima, «controlla_skill: <nome o cartella>:
E errori, A avvisi». Si può anche importare: esamina_skill(cartella,
caricamento=False) restituisce un Referto(nome, errori, avvisi, dati).

Gli errori:
- SKILL.md comincia con --- alla prima riga, senza un BOM, e ha un --- che
  chiude;
- il frontmatter è YAML che questo controllo sa leggere: «chiave: valore»
  (semplice, fra apici, fra virgolette), i blocchi >- > | |-, una mappa
  sotto metadata; le liste e le mappe degli altri campi (paths, hooks…) non
  le apre. Con la riga: virgolette non chiuse, una tabulazione nel rientro,
  «: » in un valore semplice, un valore semplice che comincia con [ { * & !
  | > % @ o un backtick (salvo una lista o una mappa chiusa sulla stessa
  riga), una chiave ripetuta, una riga di primo livello che non è
  «chiave: valore» né una voce di lista sotto una chiave senza valore. La
  documentazione di Claude Code dice che con un frontmatter YAML malformato
  il corpo si carica con i metadati vuoti, e Claude non può confrontare la
  richiesta con la description: per questo qui sono errori, anche dove un
  altro lettore li lascia passare;
- name: c'è, da 1 a 64 caratteri, solo a-z 0-9 e trattini, senza trattini
  in testa, in coda o doppi, uguale alla cartella, senza «anthropic» né
  «claude», senza tag XML;
- description: c'è, non è vuota, al massimo 1024 caratteri, senza tag XML né
  parentesi angolari;
- compatibility, se c'è: da 1 a 500 caratteri; metadata, se c'è: una mappa
  da stringa a stringa; allowed-tools, se c'è: una stringa;
- il corpo non è vuoto;
- un file nominato nel corpo sotto references/, scripts/ o assets/ (in
  backtick o in un link Markdown, anche con ${CLAUDE_SKILL_DIR}/ davanti),
  fuori dai blocchi di codice, esiste nella cartella della skill;
- con --caricamento: nessun campo oltre ai sei della specifica.

Gli avvisi:
- tre trattini dentro una riga del frontmatter;
- un campo che non è fra i sei né fra quelli di Claude Code: Claude Code
  ignora senza errori un campo che non riconosce;
- con --caricamento: una riga con !`comando`, che in chat non funziona;
- un corpo oltre le 500 righe o oltre i 5000 token stimati;
- una description senza «quando» o «use when», o che comincia in prima o in
  seconda persona;
- un name vago o troppo generico;
- evals/evals.json che manca, che non si legge o che ha meno di tre
  valutazioni;
- un file di references/ che ne nomina un altro di references/, o che non si
  legge come testo;
- un percorso con la barra rovesciata;
- un segnaposto del modello rimasto nel corpo: <parole>, fuori dai blocchi
  di codice e dai backtick.
"""
from __future__ import annotations

import glob
import json
import os
import re
import sys
from typing import Dict, List, NamedTuple, Optional

# Il lettore del frontmatter sta accanto a questo file; -I toglie la
# cartella dello script dal percorso dei moduli. Chi lancia lo strumento
# senza -B non lascia file compilati nel repository; senza il lettore si esce
# 2: 1 vorrebbe dire che la skill ha errori.
sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.realpath(__file__)))
try:
    # pylint: disable=wrong-import-position
    from lib_leggi_frontmatter import Campo, Riga, leggi_frontmatter
except ImportError as exc:
    print("controlla_skill: manca lib_leggi_frontmatter.py accanto a questo "
          f"file: {exc}", file=sys.stderr)
    sys.exit(2)

CAMPI_STANDARD = ("allowed-tools", "compatibility", "description", "license",
                  "metadata", "name")
CAMPI_CLAUDE_CODE = ("when_to_use", "argument-hint", "arguments",
                     "disable-model-invocation", "user-invocable",
                     "disallowed-tools", "model", "effort", "context",
                     "agent", "background", "hooks", "paths", "shell")
NOMI_VAGHI = ("helper", "utils", "tools", "documents", "data", "files")
PAROLE_RISERVATE = ("anthropic", "claude")
LIMITE_NOME = 64
LIMITE_DESCRIZIONE = 1024
LIMITE_COMPATIBILITA = 500
LIMITE_RIGHE = 500
LIMITE_TOKEN = 5000
MINIMO_EVALS = 3
# Il rapporto token per carattere misurato sulle procedure del corso: una
# stima, e l'output lo dice.
TOKEN_PER_CARATTERE = 0.433

RE_TAG_XML = re.compile(r"<[^<>]*>")
RE_NOME = re.compile(r"^[a-z0-9-]+$")
RE_QUANDO = re.compile(r"\b(?:quando|use when)\b", re.IGNORECASE)
RE_PERSONA = re.compile(r"^(?:io|posso|puoi|ti|i can|you can)\b",
                        re.IGNORECASE)
RE_RECINTO = re.compile(r"^[ \t]*(`{3,}|~{3,})(.*)$")
RE_SPAN = re.compile(r"(`+)(.+?)\1")
RE_LINK = re.compile(r"\[[^\]]*\]\(\s*([^)\s]+)")
RE_INIEZIONE = re.compile(r"(?:^|\s)!`[^`]+`")
RE_CARTELLE = re.compile(
    r"(?:^|[\s\"'=(])(?:\./|\$\{?CLAUDE_SKILL_DIR\}?/)?"
    r"((?:references|scripts|assets)/[^\s\"'`)]*)")
RE_VARIABILE = re.compile(r"\$\{?CLAUDE_SKILL_DIR\}?/([^\s\"'`)]+)")
RE_LINK_CARTELLE = re.compile(r"^(?:\./|\$\{?CLAUDE_SKILL_DIR\}?/)?"
                              r"((?:references|scripts|assets)/.*)$")
RE_BARRA = re.compile(r"\b[A-Za-z]:\\|\b(?:scripts|references|assets)\\"
                      r"|[\w.-]+\\[\w.-]+\.\w+")
RE_SEGNAPOSTO = re.compile(r"<(?!\s)[^<>\n]+(?<!\s)>")
TAG_HTML = frozenset(
    "a abbr b blockquote br code dd del details div dl dt em h1 h2 h3 h4 h5 "
    "h6 hr i img ins kbd li ol p pre s span strong sub summary sup table "
    "tbody td th thead tr u ul".split())

USO = """\
Uso: tools/controlla_skill.py <cartella della skill> [--caricamento]
  --caricamento  aggiunge le regole di chi carica la skill su claude.ai
Uscita: 0 nessun errore · 1 almeno un errore · 2 argomenti, una cartella che
non esiste o un SKILL.md illeggibile"""


class Illeggibile(Exception):
    """SKILL.md c'è, ma il sistema non lo lascia leggere: uscita 2."""


class Referto(NamedTuple):
    """L'esito: il nome, gli errori e gli avvisi senza la parola iniziale, i
    dati."""
    nome: str
    errori: List[str]
    avvisi: List[str]
    dati: List[str]


def _quanti(numero: int, uno: str, molti: str) -> str:
    """«1 errore», «2 errori», «0 errori»: il nome si accorda con il numero."""
    return f"{numero} {uno if numero == 1 else molti}"


# --------------------------------------------------------------------------
# I campi
# --------------------------------------------------------------------------

def _non_stringa(nome: str) -> str:
    return (f"{nome}: per YAML non è una stringa: se è proprio quel testo, "
            "mettilo fra virgolette.")


def _regole_nome(nome: str, cartella: str) -> List[str]:
    errori: List[str] = []
    if len(nome) > LIMITE_NOME:
        errori.append(f"name: ha {len(nome)} caratteri, il massimo è "
                      f"{LIMITE_NOME}.")
    if RE_TAG_XML.search(nome):
        errori.append("name: contiene un tag XML: solo minuscole, cifre e "
                      "trattini.")
    elif not RE_NOME.match(nome):
        errori.append(f"name: «{nome}» non va: solo minuscole, cifre e "
                      "trattini (a-z, 0-9, -).")
    if nome.startswith("-") or nome.endswith("-"):
        errori.append("name: non comincia e non finisce con un trattino.")
    if "--" in nome:
        errori.append("name: niente trattini doppi: togline uno.")
    for parola in PAROLE_RISERVATE:
        if parola in nome:
            errori.append(f"name: «{parola}» è una parola riservata: scegli "
                          "un altro nome.")
    if nome != cartella:
        errori.append(f"name: è «{nome}» ma la cartella si chiama "
                      f"«{cartella}»: devono essere uguali. Cambia uno dei "
                      "due.")
    return errori


def _controlla_nome(campi: Dict[str, Campo], cartella: str,
                    errori: List[str], avvisi: List[str]) -> None:
    campo = campi.get("name")
    if campo is None:
        errori.append(f"name: manca: lo standard lo vuole sempre. Scrivi "
                      f"«name: {cartella}».")
    elif campo.tipo == "vuoto" or (campo.tipo == "stringa"
                                   and not str(campo.valore).strip()):
        errori.append(f"name: è vuoto. Scrivi «name: {cartella}».")
    elif campo.tipo != "rotto" and campo.tipo != "stringa":
        errori.append(_non_stringa("name"))
    elif campo.tipo == "stringa":
        nome = str(campo.valore).strip()
        errori.extend(_regole_nome(nome, cartella))
        if nome in NOMI_VAGHI:
            avvisi.append(f"name: «{nome}» è vago o troppo generico: di' che "
                          "cosa fa la skill, per esempio «revisione-pr».")


def _controlla_descrizione(campi: Dict[str, Campo], errori: List[str],
                           avvisi: List[str]) -> None:
    campo = campi.get("description")
    if campo is None:
        errori.append("description: manca: lo standard la vuole sempre, e "
                      "dice che cosa fa la skill e quando usarla.")
        return
    if campo.tipo == "rotto":
        return
    testo = str(campo.valore).strip() if campo.tipo == "stringa" else ""
    if campo.tipo == "vuoto" or (campo.tipo == "stringa" and not testo):
        errori.append("description: è vuota: di' che cosa fa la skill e "
                      "quando usarla.")
        return
    if campo.tipo != "stringa":
        errori.append(_non_stringa("description"))
        return
    if len(testo) > LIMITE_DESCRIZIONE:
        errori.append(f"description: ha {len(testo)} caratteri, il massimo è "
                      f"{LIMITE_DESCRIZIONE}. Accorciala.")
    if "<" in testo or ">" in testo:
        errori.append("description: niente tag XML né parentesi angolari: "
                      "riscrivi quel pezzo a parole.")
    if not RE_QUANDO.search(testo):
        avvisi.append("description: non dice quando usarla: aggiungi «Da "
                      "usare quando …» con le parole di chi chiede.")
    if RE_PERSONA.match(testo):
        avvisi.append("description: comincia in prima o in seconda persona: "
                      "si scrive sempre in terza persona, perché entra nel "
                      "system prompt.")


def _controlla_altri_campi(campi: Dict[str, Campo],
                           errori: List[str]) -> None:
    campo = campi.get("compatibility")
    if campo is not None and campo.tipo != "rotto":
        lungo = len(str(campo.valore)) if campo.tipo == "stringa" else 0
        if campo.tipo not in ("stringa", "vuoto"):
            errori.append(_non_stringa("compatibility"))
        elif lungo < 1 or lungo > LIMITE_COMPATIBILITA:
            errori.append(f"compatibility: ha {lungo} caratteri: se c'è, ne "
                          f"ha da 1 a {LIMITE_COMPATIBILITA}. Alla maggior "
                          "parte delle skill non serve.")
    campo = campi.get("allowed-tools")
    if campo is not None and campo.tipo not in ("stringa", "rotto"):
        errori.append("allowed-tools: dev'essere una stringa, con i nomi "
                      "separati da spazi: «allowed-tools: Read Bash(git log "
                      "*)».")
    campo = campi.get("metadata")
    if campo is None or campo.tipo == "rotto":
        return
    if campo.tipo != "mappa":
        errori.append("metadata: dev'essere una mappa da stringa a stringa, "
                      "con una riga rientrata «chiave: valore» per ogni voce.")
    elif isinstance(campo.valore, dict):
        for chiave, valore in campo.valore.items():
            if valore is None:
                errori.append(f"metadata: il valore di «{chiave}» non è una "
                              "stringa: mettilo fra virgolette.")


def _controlla_elenco_campi(campi: Dict[str, Campo], caricamento: bool,
                            errori: List[str], avvisi: List[str]) -> None:
    if caricamento:
        di_troppo = sorted(set(campi) - set(CAMPI_STANDARD))
        if di_troppo:
            errori.append(
                "caricamento: il caricamento rifiuta questo frontmatter: «"
                f"Unexpected key(s) in SKILL.md frontmatter: "
                f"{', '.join(di_troppo)}. Allowed properties are: "
                f"{', '.join(sorted(CAMPI_STANDARD))}». Togli quei campi.")
        return
    for chiave in campi:
        if chiave not in CAMPI_STANDARD and chiave not in CAMPI_CLAUDE_CODE:
            avvisi.append(f"campo {chiave}: non è un campo che Claude Code "
                          "riconosce: un campo scritto male si ignora senza "
                          "errori. Controlla il nome, trattini compresi.")


# --------------------------------------------------------------------------
# Il corpo
# --------------------------------------------------------------------------

def _fuori_dai_blocchi(corpo: List[Riga]) -> List[Riga]:
    """Le righe del corpo che non stanno in un blocco di codice recintato."""
    fuori: List[Riga] = []
    apertura = ""
    for numero, testo in corpo:
        recinto = RE_RECINTO.match(testo)
        # Tre backtick con un altro backtick sulla riga sono testo, non un
        # blocco: `` ``` `a` ``` ``.
        if recinto and recinto.group(1)[0] == "`" and "`" in recinto.group(2):
            recinto = None
        if apertura:
            if recinto and recinto.group(1)[0] == apertura[0] \
                    and len(recinto.group(1)) >= len(apertura) \
                    and not recinto.group(2).strip():
                apertura = ""
        elif recinto:
            apertura = recinto.group(1)
        else:
            fuori.append((numero, testo))
    return fuori


def _nominati(testo: str) -> List[str]:
    """I percorsi che una riga nomina dentro la skill."""
    trovati: List[str] = []
    for span in RE_SPAN.finditer(testo):
        codice = span.group(2)
        trovati.extend(RE_CARTELLE.findall(codice))
        trovati.extend(RE_VARIABILE.findall(codice))
    for link in RE_LINK.finditer(testo):
        bersaglio = RE_LINK_CARTELLE.match(link.group(1))
        if bersaglio:
            trovati.append(re.split(r"[#?]", bersaglio.group(1))[0])
    return sorted({re.sub(r":\d+$", "", percorso) for percorso in trovati})


def _esiste_nella_skill(cartella: str, relativo: str) -> bool:
    """Un segnaposto non si può controllare; un glob deve trovare qualcosa;
    un percorso che esce dalla skill non c'è."""
    if any(segno in relativo for segno in "<>{}…") or "..." in relativo:
        return True
    pieno = os.path.normpath(os.path.join(cartella, relativo))
    if not pieno.startswith(cartella + os.sep):
        return False
    if any(segno in relativo for segno in "*?["):
        return bool(glob.glob(pieno))
    if relativo.endswith("/"):
        return os.path.isdir(pieno)
    return os.path.exists(pieno)


def _controlla_nominati(cartella: str, fuori: List[Riga],
                        errori: List[str]) -> None:
    visti = set()
    for numero, testo in fuori:
        for relativo in _nominati(testo):
            if relativo not in visti and not _esiste_nella_skill(cartella,
                                                                 relativo):
                errori.append(
                    f"file {relativo}: la riga {numero} lo nomina, ma nella "
                    "cartella della skill non c'è. Crealo, o correggi il "
                    "percorso: è relativo alla radice della skill.")
            visti.add(relativo)


def _controlla_segnaposto(fuori: List[Riga], avvisi: List[str]) -> None:
    for numero, testo in fuori:
        for trovato in RE_SEGNAPOSTO.findall(RE_SPAN.sub("", testo)):
            interno = trovato[1:-1].strip()
            parola = interno.split(" ")[0].lower() if interno else ""
            if parola in TAG_HTML or interno[:1] in ("/", "!") \
                    or "://" in interno or "@" in interno:
                continue
            avvisi.append(f"riga {numero}: un segnaposto del modello rimasto: "
                          f"{trovato}. Sostituiscilo con il testo vero.")


def _controlla_corpo(cartella: str, corpo: List[Riga], testo: str,
                     caricamento: bool, errori: List[str],
                     avvisi: List[str]) -> List[str]:
    """Il corpo: errori, avvisi e, come valore, le righe di dati."""
    token = int(round(len(testo) * TOKEN_PER_CARATTERE))
    dati = [f"corpo: {_quanti(len(corpo), 'riga', 'righe')}",
            f"token stimati: circa {token} (caratteri × 0,433: il rapporto "
            "misurato sulle procedure del corso; una stima)"]
    if not testo.strip():
        errori.append("corpo: è vuoto: dopo il frontmatter vanno le "
                      "istruzioni per Claude.")
        return dati
    if len(corpo) > LIMITE_RIGHE:
        avvisi.append(f"corpo: {len(corpo)} righe: lo standard chiede di "
                      f"stare sotto le {LIMITE_RIGHE} righe. Sposta il "
                      "dettaglio in references/.")
    if token > LIMITE_TOKEN:
        avvisi.append(f"corpo: circa {token} token stimati: lo standard "
                      f"raccomanda di stare sotto i {LIMITE_TOKEN} token. "
                      "Sposta il dettaglio in references/.")
    fuori = _fuori_dai_blocchi(corpo)
    _controlla_nominati(cartella, fuori, errori)
    if caricamento:
        for numero, riga in fuori:
            if RE_INIEZIONE.search(riga):
                avvisi.append(f"caricamento: riga {numero}: !`comando` è una "
                              "funzione di Claude Code: nella chat di "
                              "claude.ai non funziona.")
    for numero, riga in corpo:
        if RE_BARRA.search(riga):
            avvisi.append(f"riga {numero}: un percorso con la barra "
                          "rovesciata: usa sempre la barra /, anche su "
                          "Windows.")
    _controlla_segnaposto(fuori, avvisi)
    return dati


# --------------------------------------------------------------------------
# I file accanto allo SKILL.md
# --------------------------------------------------------------------------

def _controlla_evals(cartella: str, avvisi: List[str]) -> None:
    percorso = os.path.join(cartella, "evals", "evals.json")
    if not os.path.isfile(percorso):
        avvisi.append("evals: manca evals/evals.json: la checklist di "
                      "Anthropic chiede almeno tre valutazioni.")
        return
    try:
        with open(percorso, encoding="utf-8-sig") as fh:
            dati = json.load(fh)
    except (OSError, ValueError) as exc:
        avvisi.append(f"evals: evals/evals.json non si legge: {exc}.")
        return
    casi = dati.get("evals") if isinstance(dati, dict) else None
    if not isinstance(casi, list):
        avvisi.append("evals: evals/evals.json non si legge: manca l'elenco "
                      "«evals».")
    elif len(casi) < MINIMO_EVALS:
        avvisi.append("evals: evals/evals.json ha "
                      f"{_quanti(len(casi), 'caso', 'casi')}: la checklist di "
                      "Anthropic chiede almeno tre valutazioni.")


def _file_sotto(cartella: str) -> List[str]:
    trovati: List[str] = []
    for radice, _, nomi in os.walk(cartella):
        for nome in nomi:
            trovati.append(os.path.relpath(os.path.join(radice, nome),
                                           cartella))
    return sorted(trovati)


def _controlla_riferimenti(cartella: str, avvisi: List[str]) -> None:
    """Un file di references/ che ne nomina un altro di references/; uno che
    non si legge lo dice, perché lì il controllo non è stato fatto."""
    base = os.path.join(cartella, "references")
    if not os.path.isdir(base):
        return
    file_rif = _file_sotto(base)
    for chi in file_rif:
        try:
            with open(os.path.join(base, chi), encoding="utf-8") as fh:
                testo = fh.read()
        except (OSError, UnicodeDecodeError):
            avvisi.append(f"references/{chi}: non si legge come testo: non ho "
                          "controllato quali altri file nomina.")
            continue
        for altro in file_rif:
            nome = re.escape(os.path.basename(altro))
            if altro != chi and re.search(rf"(?<![\w.-]){nome}(?![\w-])",
                                          testo):
                avvisi.append(
                    f"references/{chi}: nomina references/{altro}: i "
                    "riferimenti stanno a un solo livello da SKILL.md. Fai "
                    "nominare quel file da SKILL.md.")


# --------------------------------------------------------------------------
# L'insieme
# --------------------------------------------------------------------------

def _leggi_testo(percorso: str) -> Optional[str]:
    """Il testo di SKILL.md, con le righe in LF; None se non è UTF-8."""
    try:
        with open(percorso, "rb") as fh:
            grezzo = fh.read()
    except OSError as exc:
        raise Illeggibile(f"non riesco a leggere {percorso}: {exc}") from exc
    try:
        return grezzo.decode("utf-8").replace("\r\n", "\n")
    except UnicodeDecodeError:
        return None


def _chiusura(righe: List[str]) -> int:
    """L'indice del --- che chiude il frontmatter; -1 se manca."""
    for i in range(1, len(righe)):
        if righe[i].rstrip() == "---":
            return i
    return -1


def _errore_cornice(testo: str, righe: List[str], fine: int) -> Optional[str]:
    """Che cosa non va nei due --- che racchiudono il frontmatter."""
    if testo.startswith("\N{ZERO WIDTH NO-BREAK SPACE}"):
        return ("SKILL.md: comincia con un BOM, un carattere invisibile prima "
                "del ---: salvalo in UTF-8 senza BOM.")
    if righe[0].rstrip() != "---":
        return ("frontmatter: la prima riga di SKILL.md dev'essere ---: "
                "Claude Code legge il frontmatter solo se il --- di apertura "
                "è la prima riga del file.")
    if fine < 0:
        return ("frontmatter: manca il --- che chiude il frontmatter: "
                "aggiungilo, su una riga sua, prima del corpo.")
    return None


def _controlla_trattini(righe: List[str], fine: int,
                        avvisi: List[str]) -> None:
    """Tre trattini dentro una riga del frontmatter: un lettore che cerca il
    segno di chiusura può fermarsi lì."""
    for i in range(1, fine):
        if "---" in righe[i]:
            avvisi.append(f"riga {i + 1}: contiene ---, il segno che chiude "
                          "il frontmatter: toglilo da lì, perché un lettore "
                          "può fermarsi a quel punto.")


def esamina_skill(cartella: str, caricamento: bool = False) -> Referto:
    """Controlla una cartella che esiste e restituisce il Referto.

    Raises: Illeggibile se SKILL.md c'è ma il sistema non lo lascia leggere.
    """
    cartella = os.path.abspath(cartella)
    nome_cartella = os.path.basename(cartella)
    percorso = os.path.join(cartella, "SKILL.md")
    errori: List[str] = []
    avvisi: List[str] = []
    if not os.path.isfile(percorso):
        errori.append("SKILL.md: manca nella cartella: una skill è una "
                      "cartella con un file SKILL.md.")
        return Referto(nome_cartella, errori, avvisi, [])
    testo = _leggi_testo(percorso)
    if testo is None:
        errori.append("SKILL.md: non è testo UTF-8: salvalo in UTF-8.")
        return Referto(nome_cartella, errori, avvisi, [])
    righe = testo.split("\n")
    fine = _chiusura(righe)
    cornice = _errore_cornice(testo, righe, fine)
    if cornice is not None:
        errori.append(cornice)
        return Referto(nome_cartella, errori, avvisi, [])
    campi, sintassi = leggi_frontmatter(
        [(i + 1, righe[i]) for i in range(1, fine)])
    errori.extend(sintassi)
    _controlla_trattini(righe, fine, avvisi)
    _controlla_nome(campi, nome_cartella, errori, avvisi)
    _controlla_descrizione(campi, errori, avvisi)
    _controlla_altri_campi(campi, errori)
    _controlla_elenco_campi(campi, caricamento, errori, avvisi)
    corpo_testo = "\n".join(righe[fine + 1:])
    corpo = [(i + 1, righe[i]) for i in range(fine + 1, len(righe))]
    if corpo and not corpo[-1][1]:
        corpo.pop()
    dati = _controlla_corpo(cartella, corpo, corpo_testo, caricamento, errori,
                            avvisi)
    _controlla_evals(cartella, avvisi)
    _controlla_riferimenti(cartella, avvisi)
    nome = campi.get("name")
    valido = nome is not None and nome.tipo == "stringa" and nome.valore
    return Referto(str(nome.valore).strip() if valido else nome_cartella,
                   errori, avvisi, dati)


def _stampa(referto: Referto) -> None:
    for errore in referto.errori:
        print(f"ERRORE {errore}")
    for avviso in referto.avvisi:
        print(f"AVVISO {avviso}")
    for dato in referto.dati:
        print(dato)
    print(f"controlla_skill: {referto.nome}: "
          f"{_quanti(len(referto.errori), 'errore', 'errori')}, "
          f"{_quanti(len(referto.avvisi), 'avviso', 'avvisi')}")


def main(argv: List[str]) -> int:
    if argv and argv[0] in ("-h", "--help"):
        print(USO)
        return 0
    caricamento = "--caricamento" in argv
    resto = [arg for arg in argv if arg != "--caricamento"]
    sconosciute = [arg for arg in resto if arg.startswith("-")
                   and not os.path.exists(arg)]
    if sconosciute:
        print(f"controlla_skill: opzione sconosciuta: {sconosciute[0]}\n{USO}",
              file=sys.stderr)
        return 2
    if len(resto) != 1:
        print(USO, file=sys.stderr)
        return 2
    cartella = resto[0]
    if not os.path.exists(cartella):
        print(f"controlla_skill: la cartella non esiste: {cartella}",
              file=sys.stderr)
        return 2
    if not os.path.isdir(cartella):
        print(f"controlla_skill: non è una cartella: {cartella}",
              file=sys.stderr)
        return 2
    try:
        referto = esamina_skill(cartella, caricamento)
    except Illeggibile as exc:
        print(f"controlla_skill: {exc}", file=sys.stderr)
        return 2
    _stampa(referto)
    return 1 if referto.errori else 0


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    try:
        sys.exit(main(sys.argv[1:]))
    except Exception as exc:  # pylint: disable=broad-except
        print(f"controlla_skill: errore inatteso: {exc}", file=sys.stderr)
        sys.exit(2)
