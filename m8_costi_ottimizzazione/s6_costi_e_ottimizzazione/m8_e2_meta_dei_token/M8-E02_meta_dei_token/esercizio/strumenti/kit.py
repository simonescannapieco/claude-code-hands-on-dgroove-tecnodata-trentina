#!/usr/bin/env python3
"""kit.py -- gli attrezzi di misura di «Metà dei token, a parità di qualità».

Li usa misura.sh; si possono usare anche da soli, dalla cartella
dell'esercizio. I casi sono le tre cartelle di casi/. Il kit è quello di
M2-E02, copiato e completato per questo laboratorio: sta sopra le 800 righe
per restare una copia confrontabile con l'originale.

  casi                               i nomi dei casi, uno per riga
  componi   <caso> <versione>        il prompt di prompt/<versione>.md con
                                     ogni segnaposto {{nome}} sostituito:
                                     {{messaggio}} e {{stato}} dai file del
                                     caso, gli altri da documenti/<nome>.md;
                                     prima di ogni chiamata controlla anche
                                     che il prompt porti i due dati del caso
                                     e che controlli.tsv e la rubrica si
                                     leggano
  opzioni   <versione> <modello> <effort>
                                     risposte/<versione>/opzioni.tsv: il
                                     modello, l'effort e le impronte (sha256)
                                     del prompt, dei dati dei casi e dei
                                     prompt composti
  estrai    <caso> <versione>        il campo «result» del JSON della risposta,
                                     scritto in risposte/<versione>/<caso>.md
  controlla <caso> <versione>        i controlli di controlli.tsv sulla
                                     risposta; il file controlli/<versione>/
                                     <caso>.txt è da leggere: il riepilogo e la
                                     verifica li rifanno sulla risposta
  consegna  <caso> <versione>        il testo che riceve il giudice: la
                                     rubrica, il messaggio, lo stato, la
                                     risposta, ciascuno nel suo tag
  giudizio  <caso> <versione>        il riepilogo del giudizio del caso
  riepilogo <versione>               la tabella della versione: per caso e in
                                     totale, i token in entrata (la somma dei
                                     tre campi di usage), i token in uscita, il
                                     costo ricalcolato da listino.json, i
                                     controlli superati e le affermazioni
                                     rispettate
  confronta <vA> <vB>                due versioni fianco a fianco, la riduzione
                                     dei token in entrata e la riga
                                     dell'obiettivo del laboratorio (un dato)

Il prompt composto e la consegna al giudice arrivano a claude -p come un
argomento solo: oltre i 100000 byte componi e consegna li rifiutano.

Formati:
  rubrica.md     un'affermazione verificabile per riga: «- **id**: testo»
                 (id in minuscolo, lettere, cifre e _)
  controlli.tsv  intestazione «tipo<TAB>valore<TAB>descrizione», poi una riga
                 per controllo; tipo: assente o presente (valore:
                 un'espressione regolare, senza distinzione tra maiuscole e
                 minuscole), parole_max, parole_min, righe_max (valore: un
                 numero); ogni descrizione una volta sola

Uscita: 0 fatto; per controlla, ogni controllo superato ·
        1 per controlla, almeno un controllo non superato (un esito normale,
        non un errore); per gli altri comandi, un file di misura incompleto o
        con un errore (una risposta con is_error, un usage non numerico, un
        giudizio senza structured_output) ·
        2 uso sbagliato, file assente o illeggibile, formato non valido,
        testo oltre il limite. Mai un traceback: un errore inatteso esce 2,
        con un messaggio di una riga.
"""
from __future__ import annotations

import hashlib
import json
import os
import re
import sys
import textwrap
from typing import Dict, List, NamedTuple, NoReturn, Optional, Sequence, Tuple

# I tre casi del laboratorio, nell'ordine in cui si misurano.
CASI: Tuple[str, ...] = ("caso-1", "caso-2", "caso-3")
# I due dati che ogni versione del prompt deve portare: senza, non è più la
# risposta a quel cliente.
DATI_CASO: Tuple[str, ...] = ("messaggio", "stato")
PLACEHOLDER = re.compile(r"\{\{([a-z][a-z0-9_]*)\}\}")
# «- **id**: testo»
CLAIM = re.compile(r"^- \*\*([a-z][a-z0-9_]*)\*\*:\s+(\S.*)$")
VERSIONE = re.compile(r"v(?:0|[1-9][0-9]*)")   # con fullmatch
NUMERO = re.compile(r"[0-9]+")                 # con fullmatch: cifre ASCII
TIPI = ("assente", "presente", "parole_max", "parole_min", "righe_max")
INTESTAZIONE = ["tipo", "valore", "descrizione"]
# I conteggi di usage che fanno l'entrata; il quarto è l'uscita.
ENTRATA = ("input_tokens", "cache_creation_input_tokens",
           "cache_read_input_tokens")
USCITA = "output_tokens"
# I cinque prezzi di listino.json, per milione di token.
PREZZI = ("input", "output", "cache_write_5m", "cache_write_1h", "cache_read")
MODELLI = ("haiku", "sonnet", "opus")     # gli alias che misura.sh accetta
EFFORT = ("low", "medium", "high")
LISTINO = "listino.json"
SCHEMA_GIUDIZIO = "schema-giudizio.json"
RISPOSTE, CONTROLLI, GIUDIZI = ("risposte", "controlli", "giudizi")
# Il prompt composto e la consegna viaggiano come un argomento solo di
# claude -p, e il sistema operativo ne limita la lunghezza (su Linux
# 128 KiB): oltre questo limite il kit li ferma prima della chiamata.
LIMITE_BYTE = 100000
LARGHEZZA = 76
# L'obiettivo del laboratorio, in percento: un dato da stampare, mai un
# esito né un'uscita.
OBIETTIVO = 50
BOM = chr(0xFEFF)   # il BOM che un editor può mettere in testa a un file
# Il modello del giudice: lo stesso del suo file in .claude/agents/, per
# ricalcolarne il costo.
MODELLO_GIUDICE = "haiku"


class Errore(Exception):
    """Un problema dei dati: l'uscita è il codice che porta (1 o 2)."""

    def __init__(self, messaggio: str, codice: int = 2) -> None:
        super().__init__(messaggio)
        self.codice = codice


def leggi(percorso: str) -> str:
    """Il testo di un file in UTF-8; Errore(2) se manca o non si legge."""
    try:
        with open(percorso, encoding="utf-8") as fh:
            return fh.read()
    except FileNotFoundError:
        raise Errore("manca il file %s" % percorso)
    except (OSError, UnicodeDecodeError) as exc:
        raise Errore("non riesco a leggere %s (%s)" % (percorso, exc))


def senza_bom(testo: str) -> str:
    """Il testo senza il BOM in testa, se c'è."""
    return testo[len(BOM):] if testo.startswith(BOM) else testo


def scrivi(percorso: str, testo: str) -> None:
    """Scrive un file di testo in UTF-8, creando la cartella se serve;
    Errore(2) se non si scrive."""
    cartella = os.path.dirname(percorso)
    try:
        if cartella:
            os.makedirs(cartella, exist_ok=True)
        with open(percorso, "w", encoding="utf-8", newline="\n") as fh:
            fh.write(testo)
    except OSError as exc:
        raise Errore("non riesco a scrivere %s (%s)" % (percorso, exc))


def controlla_versione(versione: str) -> None:
    """Rifiuta un nome di versione diverso da v0, v1, v2, ...: «v» e un
    numero senza zeri davanti."""
    if not VERSIONE.fullmatch(versione):
        raise Errore("versione «%s» non valida: si scrive v0, v1, v2, ..."
                     % versione)


def controlla_caso(caso: str) -> None:
    """Rifiuta un caso che non è uno dei tre."""
    if caso not in CASI:
        raise Errore("caso «%s» sconosciuto: sono %s"
                     % (caso, ", ".join(CASI)))


def avvolgi(testo: str, rientro: str, seguito: Optional[str] = None) -> None:
    """Stampa un testo lungo su più righe, al massimo LARGHEZZA colonne."""
    print(textwrap.fill(testo, LARGHEZZA, initial_indent=rientro,
                        subsequent_indent=rientro if seguito is None
                        else seguito, break_long_words=False,
                        break_on_hyphens=False))


def virgola(valore: float, cifre: int) -> str:
    """Un numero con la virgola, come si scrive in italiano."""
    return ("%.*f" % (cifre, valore)).replace(".", ",")


def dollari(valore: float) -> str:
    """Un importo in dollari, con la virgola."""
    return "%s $" % virgola(valore, 4)


def documenti() -> Dict[str, Tuple[str, str]]:
    """I file di documenti/, per nome senza estensione: {nome: (percorso,
    testo)}."""
    base = "documenti"
    if not os.path.isdir(base):
        return {}
    trovati: Dict[str, Tuple[str, str]] = {}
    try:
        nomi = sorted(os.listdir(base))
    except OSError as exc:
        raise Errore("non riesco a leggere la cartella %s (%s)" % (base, exc))
    for nome in nomi:
        percorso = os.path.join(base, nome)
        if nome.startswith(".") or not os.path.isfile(percorso):
            continue
        radice = nome.split(".", 1)[0]
        if radice in trovati:
            raise Errore("in %s due file si chiamano «%s»: il segnaposto "
                         "{{%s}} sarebbe ambiguo" % (base, radice, radice))
        trovati[radice] = (percorso, leggi(percorso).rstrip("\n"))
    return trovati


def dati_caso(caso: str) -> Dict[str, Tuple[str, str]]:
    """I file del caso che riempiono {{messaggio}} e {{stato}}."""
    controlla_caso(caso)
    trovati: Dict[str, Tuple[str, str]] = {}
    for nome in DATI_CASO:
        percorso = os.path.join("casi", caso, nome + ".md")
        trovati[nome] = (percorso, leggi(percorso).rstrip("\n"))
    return trovati


def nel_limite(testo: str, cosa: str, fonti: List[Tuple[str, str]],
               rimedio: str) -> str:
    """Il testo, se in UTF-8 non supera LIMITE_BYTE; altrimenti Errore(2)
    con il peso del testo e di ogni sua fonte (percorso, testo)."""
    peso = len(testo.encode("utf-8"))
    if peso <= LIMITE_BYTE:
        return testo
    raise Errore("%s: %d byte, oltre il limite di %d byte (%s); %s" % (
        cosa, peso, LIMITE_BYTE, ", ".join(
            "%s %d byte" % (os.path.normpath(p), len(t.encode("utf-8")))
            for p, t in fonti), rimedio))


def componi(caso: str, versione: str) -> str:
    """Il prompt di una versione con i segnaposto sostituiti; prima della
    chiamata a pagamento, controlla anche ciò che serve dopo."""
    controlla_versione(versione)
    controlla_caso(caso)
    percorso = os.path.join("prompt", versione + ".md")
    testo = leggi(percorso)
    usati = sorted(set(PLACEHOLDER.findall(testo)))
    for nome in DATI_CASO:
        if nome not in usati:
            raise Errore("prompt/%s.md non contiene {{%s}}: ogni versione "
                         "deve portare i dati del caso, {{messaggio}} e "
                         "{{stato}}" % (versione, nome))
    disponibili = dict(documenti())
    disponibili.update(dati_caso(caso))
    mancanti = [n for n in usati if n not in disponibili]
    if mancanti:
        raise Errore("il prompt %s usa %s, ma non c'è né un dato del caso né "
                     "un file in documenti/ con quel nome (ci sono: %s)" % (
                         versione, ", ".join("{{%s}}" % n for n in mancanti),
                         ", ".join(sorted(disponibili))))
    composto = PLACEHOLDER.sub(lambda m: disponibili[m.group(1)][1], testo)
    if not composto.strip():
        raise Errore("il prompt %s è vuoto" % versione)
    prompt = nel_limite(composto.rstrip("\n"),
                        "il prompt composto di %s è troppo lungo" % versione,
                        [(percorso, testo)] + [disponibili[n] for n in usati],
                        "accorciate i file di documenti/")
    # Ciò che serve dopo la risposta si controlla prima di chiederla: le
    # righe di controlli.tsv e la rubrica.
    controlli(caso)
    rubrica(caso)
    return prompt


def impronta(parti: Sequence[Tuple[str, str]]) -> str:
    """L'impronta sha256 di una serie di (nome, testo)."""
    h = hashlib.sha256()
    for nome, testo in parti:
        h.update(nome.encode("utf-8") + b"\0" + testo.encode("utf-8") + b"\0")
    return h.hexdigest()


def impronta_prompt(versione: str) -> Optional[str]:
    """L'impronta del prompt di una versione com'è adesso, None se il file
    manca o non si legge."""
    try:
        testo = leggi(os.path.join("prompt", versione + ".md"))
    except Errore:
        return None
    return impronta([("prompt", testo)])


def impronta_composti(versione: str) -> Optional[str]:
    """L'impronta dei prompt composti di una versione sui tre casi, dai file
    come sono adesso (il prompt, i documenti, i dati dei casi); None se non
    si compongono."""
    try:
        return impronta([(caso, componi(caso, versione)) for caso in CASI])
    except Errore:
        return None


def impronta_dati() -> str:
    """L'impronta dei dati dei casi: un dato cambiato vuol dire che due misure
    non si confrontano. (I documenti non si contano: una versione può
    aggiungerne uno suo, più breve; quelli di partenza li guarda la
    verifica.)"""
    parti: List[Tuple[str, str]] = []
    for caso in CASI:
        for nome, (_, testo) in sorted(dati_caso(caso).items()):
            parti.append((caso + "/" + nome, testo))
    return impronta(parti)


def scrivi_opzioni(versione: str, modello: str, effort: str) -> None:
    """risposte/<v>/opzioni.tsv: il modello e l'effort delle risposte e le
    impronte del prompt e dei dati (una riga «chiave<TAB>valore» ciascuno)."""
    controlla_versione(versione)
    if modello not in MODELLI:
        raise Errore("modello «%s»: si usa %s" % (modello, ", ".join(MODELLI)))
    if effort not in EFFORT:
        raise Errore("effort «%s»: si usa %s" % (effort, ", ".join(EFFORT)))
    prompt = impronta_prompt(versione)
    if prompt is None:
        raise Errore("manca il file %s"
                     % os.path.join("prompt", versione + ".md"))
    scrivi(os.path.join(RISPOSTE, versione, "opzioni.tsv"),
           "modello\t%s\neffort\t%s\nprompt\t%s\ndati\t%s\ncomposti\t%s\n"
           % (modello, effort, prompt, impronta_dati(),
              impronta_composti(versione)))


def opzioni_di(versione: str) -> Dict[str, str]:
    """Le righe di risposte/<v>/opzioni.tsv, {} se il file non c'è."""
    percorso = os.path.join(RISPOSTE, versione, "opzioni.tsv")
    if not os.path.isfile(percorso):
        return {}
    voci: Dict[str, str] = {}
    for riga in leggi(percorso).splitlines():
        chiave, _, valore = riga.partition("\t")
        if chiave.strip() and valore.strip():
            voci[chiave.strip()] = valore.strip()
    return voci


def json_di_claude(percorso: str) -> dict:
    """Il JSON di claude -p --output-format json; Errore(1) se è un errore."""
    try:
        doc = json.loads(leggi(percorso))
    except (ValueError, RecursionError) as exc:
        raise Errore("%s non è un JSON valido (%s)" % (percorso, exc), 1)
    if not isinstance(doc, dict) or doc.get("type") != "result":
        raise Errore("%s non è il JSON di claude -p" % percorso, 1)
    if doc.get("is_error"):
        raise Errore("%s contiene un errore di Claude Code: %s" % (
            percorso, str(doc.get("result"))[:200]), 1)
    return doc


def modelli_di(doc: dict) -> List[str]:
    """I modelli del campo modelUsage di un JSON di claude -p, in ordine."""
    uso = doc.get("modelUsage")
    return sorted(str(k) for k in uso) if isinstance(uso, dict) else []


def risposta(caso: str, versione: str) -> str:
    """Il testo della risposta di una versione a un caso."""
    doc = json_di_claude(percorso_risposta(caso, versione))
    testo = doc.get("result")
    if not isinstance(testo, str) or not testo.strip():
        raise Errore("la risposta di %s a %s è vuota" % (versione, caso), 1)
    return testo


def percorso_risposta(caso: str, versione: str) -> str:
    return os.path.join(RISPOSTE, versione, caso + ".json")


def percorso_giudizio(caso: str, versione: str) -> str:
    return os.path.join(GIUDIZI, versione, caso + ".json")


def conteggio(uso: dict, chiave: str, percorso: str,
              obbligatorio: bool = False) -> int:
    """Un conteggio di usage (una stringa di cifre vale il suo numero);
    assente vale 0, o Errore(1) se è obbligatorio; Errore(1) se non è un
    numero intero."""
    valore = uso.get(chiave)
    if valore is None:
        if obbligatorio:
            raise Errore("%s: manca il campo usage.%s: misurate di nuovo la "
                         "versione" % (percorso, chiave), 1)
        return 0
    if isinstance(valore, int) and not isinstance(valore, bool):
        return valore
    if isinstance(valore, str) and NUMERO.fullmatch(valore):
        return int(valore)
    raise Errore("%s: usage.%s non è un numero (%s): misurate di nuovo la "
                 "versione" % (percorso, chiave, json.dumps(
                     valore, ensure_ascii=False)[:40]), 1)


def conteggi(doc: dict, percorso: str) -> Dict[str, int]:
    """I conteggi di usage del JSON di percorso, numeri interi: i tre
    dell'entrata, l'uscita, e le scritture in cache divise per durata
    (ephemeral_1h_input_tokens ed ephemeral_5m_input_tokens). Se la
    divisione manca, tutta la scrittura vale come scrittura a 5 minuti."""
    uso = doc.get("usage")
    if not isinstance(uso, dict) or not uso:
        raise Errore("%s: manca il campo usage: misurate di nuovo la "
                     "versione" % percorso, 1)
    conti = {k: conteggio(uso, k, percorso, True)
             for k in ENTRATA + (USCITA,)}
    if not sum(conti[k] for k in ENTRATA):
        raise Errore("%s: usage non riporta token in entrata: misurate di "
                     "nuovo la versione" % percorso, 1)
    scrittura = uso.get("cache_creation")
    if not isinstance(scrittura, dict):
        scrittura = {}
    ora = conteggio(scrittura, "ephemeral_1h_input_tokens", percorso)
    cinque = conteggio(scrittura, "ephemeral_5m_input_tokens", percorso)
    if ora + cinque != conti["cache_creation_input_tokens"]:
        cinque = max(conti["cache_creation_input_tokens"] - ora, 0)
    conti["1h"], conti["5m"] = ora, cinque
    return conti


def token(doc: dict, percorso: str) -> Tuple[int, int]:
    """(token in entrata, token in uscita) del JSON: l'entrata è la somma dei
    tre campi di usage."""
    conti = conteggi(doc, percorso)
    return sum(conti[k] for k in ENTRATA), conti[USCITA]


def listino() -> Dict[str, Dict[str, float]]:
    """I prezzi di listino.json, per alias; Errore(2) se il file non è come
    deve essere."""
    try:
        doc = json.loads(leggi(LISTINO))
    except (ValueError, RecursionError) as exc:
        raise Errore("%s non è un JSON valido (%s)" % (LISTINO, exc))
    modelli = doc.get("modelli") if isinstance(doc, dict) else None
    if not isinstance(modelli, dict):
        raise Errore("%s: manca l'oggetto «modelli»" % LISTINO)
    prezzi: Dict[str, Dict[str, float]] = {}
    for alias in MODELLI:
        voce = modelli.get(alias)
        if not isinstance(voce, dict):
            raise Errore("%s: manca il modello %s" % (LISTINO, alias))
        riga: Dict[str, float] = {}
        for chiave in PREZZI:
            valore = voce.get(chiave)
            if isinstance(valore, bool) or not isinstance(valore, (int, float)):
                raise Errore("%s: %s.%s non è un numero" % (
                    LISTINO, alias, chiave))
            riga[chiave] = float(valore)
        prezzi[alias] = riga
    return prezzi


def costo(conti: Dict[str, int], prezzi: Dict[str, float]) -> float:
    """Il costo di una chiamata in dollari: ogni conteggio al suo prezzo
    (prezzi per milione di token)."""
    return (conti["input_tokens"] * prezzi["input"]
            + conti["1h"] * prezzi["cache_write_1h"]
            + conti["5m"] * prezzi["cache_write_5m"]
            + conti["cache_read_input_tokens"] * prezzi["cache_read"]
            + conti[USCITA] * prezzi["output"]) / 1000000.0


def estrai(caso: str, versione: str) -> None:
    """Scrive risposte/<v>/<caso>.md e stampa una riga con i token."""
    controlla_versione(versione)
    controlla_caso(caso)
    percorso = percorso_risposta(caso, versione)
    doc = json_di_claude(percorso)
    testo = risposta(caso, versione)
    entrata, uscita = token(doc, percorso)
    scrivi(os.path.join(RISPOSTE, versione, caso + ".md"), testo + "\n")
    print("Risposta %s, %s (%s): %d token in entrata, %d in uscita, %d "
          "parole (la risposta intera è in %s)" % (
              versione, caso, ", ".join(modelli_di(doc))
              or "modello non indicato", entrata, uscita, len(testo.split()),
              os.path.join(RISPOSTE, versione, caso + ".md")))


def controlli(caso: str) -> List[Tuple[str, str, str]]:
    """Le righe di casi/<caso>/controlli.tsv: [(tipo, valore, descrizione)],
    almeno una."""
    controlla_caso(caso)
    percorso = os.path.join("casi", caso, "controlli.tsv")
    righe = senza_bom(leggi(percorso)).splitlines()
    testa = righe[0].rstrip("\r").split("\t") if righe else []
    if testa != INTESTAZIONE:
        raise Errore("%s: la prima riga deve essere «tipo<TAB>valore<TAB>"
                     "descrizione»" % percorso)
    voci: List[Tuple[str, str, str]] = []
    for n, riga in enumerate(righe[1:], start=2):
        riga = riga.rstrip("\r")
        if not riga.strip():
            continue
        campi = riga.split("\t")
        if len(campi) != 3 or campi[0] not in TIPI:
            raise Errore("%s, riga %d: attesi tre campi, e un tipo tra %s"
                         % (percorso, n, ", ".join(TIPI)))
        tipo, valore, descrizione = campi
        if tipo in ("assente", "presente"):
            try:
                re.compile(valore)
            except (re.error, OverflowError, RecursionError) as exc:
                raise Errore("%s, riga %d: espressione non valida (%s)"
                             % (percorso, n, exc))
        elif not NUMERO.fullmatch(valore):
            raise Errore("%s, riga %d: «%s» vuole un numero" % (
                percorso, n, tipo))
        if any(descrizione == v[2] for v in voci):
            raise Errore("%s, riga %d: la descrizione «%s» c'è già" % (
                percorso, n, descrizione))
        voci.append((tipo, valore, descrizione))
    if not voci:
        raise Errore("%s non contiene controlli" % percorso)
    return voci


def esito_controllo(tipo: str, valore: str, testo: str) -> Tuple[bool, str]:
    """(superato, dettaglio) di un controllo sul testo della risposta."""
    if tipo in ("assente", "presente"):
        trovato = re.search(valore, testo, re.IGNORECASE)
        if tipo == "assente":
            return (trovato is None,
                    "trovato «%s»" % " ".join(trovato.group(0).split())
                    if trovato else "")
        return trovato is not None, "" if trovato else "non trovato"
    limite = int(valore)
    if tipo == "righe_max":
        n = len([r for r in testo.splitlines() if r.strip()])
        return n <= limite, "%d righe" % n
    n = len(testo.split())
    if tipo == "parole_max":
        return n <= limite, "%d parole" % n
    return n >= limite, "%d parole" % n


def esegui_controlli(caso: str,
                     versione: str) -> List[Tuple[bool, str, str]]:
    """Ogni controllo del caso sul testo della risposta: [(superato,
    descrizione, dettaglio)]. Lo stesso calcolo per controlla, che ne scrive
    il file, e per il riepilogo e la verifica, che quel file non lo leggono."""
    testo = risposta(caso, versione)
    esiti: List[Tuple[bool, str, str]] = []
    for tipo, valore, descrizione in controlli(caso):
        superato, dettaglio = esito_controllo(tipo, valore, testo)
        esiti.append((superato, descrizione, dettaglio))
    return esiti


def controlla(caso: str, versione: str) -> bool:
    """Scrive controlli/<v>/<caso>.txt (OK/KO per riga, poi il totale) e lo
    stampa: il file è da leggere, nessun esito lo rilegge. Returns: vero se
    ogni controllo è superato."""
    controlla_versione(versione)
    esiti = esegui_controlli(caso, versione)
    superati = sum(1 for ok, _, _ in esiti if ok)
    righe = ["\t".join(["OK" if ok else "KO", descrizione, dettaglio])
             for ok, descrizione, dettaglio in esiti]
    righe.append("totale\t%d/%d" % (superati, len(esiti)))
    scrivi(os.path.join(CONTROLLI, versione, caso + ".txt"),
           "\n".join(righe) + "\n")
    print("Controlli %s, %s: %d %s su %d" % (
        versione, caso, superati,
        "superato" if superati == 1 else "superati", len(esiti)))
    for ok, descrizione, dettaglio in esiti:
        if not ok:
            print("  ✗ %s%s" % (descrizione,
                                " (%s)" % dettaglio if dettaglio else ""))
    return superati == len(esiti)


def rubrica(caso: str) -> List[Tuple[str, str]]:
    """Le affermazioni di casi/<caso>/rubrica.md: [(id, testo)], almeno
    una."""
    controlla_caso(caso)
    percorso = os.path.join("casi", caso, "rubrica.md")
    voci: List[Tuple[str, str]] = []
    visti = set()
    for riga in senza_bom(leggi(percorso)).splitlines():
        m = CLAIM.match(riga.strip())
        if not m:
            continue
        if m.group(1) in visti:
            raise Errore("%s: l'id «%s» compare due volte"
                         % (percorso, m.group(1)))
        visti.add(m.group(1))
        voci.append((m.group(1), m.group(2).strip()))
    if not voci:
        raise Errore("%s non contiene affermazioni nel formato «- **id**: "
                     "testo»" % percorso)
    return voci


def consegna(caso: str, versione: str) -> str:
    """Il testo per il giudice: rubrica, messaggio, stato e risposta,
    ciascuno nel suo tag (che cosa contiene ciascuno lo dice il prompt del
    giudice, in .claude/agents/giudice.md)."""
    controlla_versione(versione)
    dati = dati_caso(caso)
    parti = ["<rubric>"]
    parti += ["- %s: %s" % (i, t) for i, t in rubrica(caso)]
    parti += ["</rubric>", "", "<message>", dati["messaggio"][1],
              "</message>", "", "<line_status>", dati["stato"][1],
              "</line_status>", "", "<answer>",
              risposta(caso, versione).strip("\n"), "</answer>"]
    fonti = [(os.path.join("casi", caso, "rubrica.md"), "\n".join(parti))]
    return nel_limite("\n".join(parti),
                      "la consegna al giudice di %s, %s è troppo lunga"
                      % (versione, caso), fonti,
                      "chiedete nel prompt una risposta più breve")


def esiti_giudice(caso: str,
                  versione: str) -> Dict[str, Tuple[Optional[bool], str]]:
    """{id: (rispettato, motivo)} del giudizio di un caso, per ogni id della
    rubrica; rispettato è None dove il giudice non l'ha valutato."""
    percorso = percorso_giudizio(caso, versione)
    doc = json_di_claude(percorso)
    uscita = doc.get("structured_output")
    if not isinstance(uscita, dict) or not isinstance(
            uscita.get("criteri"), list):
        raise Errore("%s non contiene il giudizio strutturato "
                     "(structured_output.criteri)" % percorso, 1)
    attesi = [i for i, _ in rubrica(caso)]
    trovati: Dict[str, Tuple[Optional[bool], str]] = {}
    for voce in uscita["criteri"]:
        if not isinstance(voce, dict):
            continue
        ident = voce.get("id")
        if ident in attesi and ident not in trovati and isinstance(
                voce.get("rispettato"), bool):
            trovati[ident] = (voce["rispettato"], str(voce.get("motivo", "")))
    return {i: trovati.get(i, (None, "non valutato dal giudice"))
            for i in attesi}


def stampa_giudizio(caso: str, versione: str) -> None:
    """Il riepilogo di un giudizio: quante affermazioni; le non rispettate,
    ognuna con il suo motivo."""
    controlla_versione(versione)
    esiti = esiti_giudice(caso, versione)
    doc = json_di_claude(percorso_giudizio(caso, versione))
    rispettate = sum(1 for ok, _ in esiti.values() if ok)
    print("Giudizio %s, %s (%s): %d %s su %d" % (
        versione, caso, ", ".join(modelli_di(doc)) or "modello non indicato",
        rispettate, "affermazione rispettata" if rispettate == 1
        else "affermazioni rispettate", len(esiti)))
    for ident, (ok, motivo) in esiti.items():
        if not ok:
            print("  ✗ %s: %s" % (ident, motivo))


class RigaCaso(NamedTuple):
    """Le misure di una versione su un caso."""
    caso: str
    entrata: int              # token in entrata (la somma dei tre campi)
    uscita: int               # token in uscita
    costo: float              # ricalcolato da listino.json
    costo_json: Optional[float]   # total_cost_usd del JSON, se c'è
    controlli_ok: int
    controlli_n: int
    giudice_ok: int
    giudice_n: int
    turni: Optional[int]      # num_turns della risposta, se c'è
    secondi: float            # durata della chiamata della risposta
    giudice_entrata: int      # i token della chiamata del giudice
    giudice_uscita: int
    giudice_costo: float
    giudice_secondi: float


class Misura(NamedTuple):
    """Una versione misurata, caso per caso."""
    versione: str
    modello: str
    effort: str
    righe: Tuple[RigaCaso, ...]

    def somma(self, campo: str) -> float:
        return sum(getattr(r, campo) for r in self.righe)


def numero_o_none(valore: object) -> Optional[int]:
    """Un intero, oppure None."""
    if isinstance(valore, int) and not isinstance(valore, bool):
        return valore
    return None


def secondi_di(doc: dict) -> float:
    """I secondi della chiamata, dal campo duration_ms del JSON; 0 se
    manca."""
    valore = doc.get("duration_ms")
    if isinstance(valore, (int, float)) and not isinstance(valore, bool):
        return float(valore) / 1000.0
    return 0.0


def riga_caso(caso: str, versione: str, alias: str,
              prezzi: Dict[str, Dict[str, float]]) -> RigaCaso:
    """Le misure di una versione su un caso; Errore se manca un file di
    misura (2) o se ne contiene uno rotto (1)."""
    percorso = percorso_risposta(caso, versione)
    giudizio = percorso_giudizio(caso, versione)
    for nome in (percorso, giudizio):
        if not os.path.isfile(nome):
            raise Errore("la misura di %s è incompleta (manca %s): misurate "
                         "di nuovo %s (./misura.sh %s)" % (
                             versione, nome, versione, versione))
    doc = json_di_claude(percorso)
    conti = conteggi(doc, percorso)
    cj = doc.get("total_cost_usd")
    costo_j = float(cj) if isinstance(cj, (int, float)) and not isinstance(
        cj, bool) else None
    esiti = esegui_controlli(caso, versione)
    verdetti = esiti_giudice(caso, versione)
    doc_g = json_di_claude(giudizio)
    conti_g = conteggi(doc_g, giudizio)
    return RigaCaso(
        caso, sum(conti[k] for k in ENTRATA), conti[USCITA],
        costo(conti, prezzi[alias]), costo_j,
        sum(1 for ok, _, _ in esiti if ok), len(esiti),
        sum(1 for ok, _ in verdetti.values() if ok), len(verdetti),
        numero_o_none(doc.get("num_turns")), secondi_di(doc),
        sum(conti_g[k] for k in ENTRATA), conti_g[USCITA],
        costo(conti_g, prezzi[MODELLO_GIUDICE]), secondi_di(doc_g))


def misura_versione(versione: str) -> Misura:
    """Le misure di una versione sui tre casi; Errore se è incompleta."""
    controlla_versione(versione)
    opz = opzioni_di(versione)
    modello, effort = opz.get("modello", ""), opz.get("effort", "")
    if modello not in MODELLI:
        raise Errore("la misura di %s è incompleta (manca risposte/%s/"
                     "opzioni.tsv o il modello): misurate di nuovo %s "
                     "(./misura.sh %s)" % (versione, versione, versione,
                                           versione))
    prezzi = listino()
    return Misura(versione, modello, effort,
                  tuple(riga_caso(c, versione, modello, prezzi)
                        for c in CASI))


def riga_tabella(c1: str, c2: str, c3: str, c4: str, c5: str,
                 c6: str) -> str:
    """Una riga della tabella di una versione, a colonne allineate."""
    return "%-8s %9s %9s %12s %10s %10s" % (c1, c2, c3, c4, c5, c6)


def riepilogo(versione: str) -> Misura:
    """La tabella di una versione: per caso e in totale; poi le righe del
    costo dal JSON e del giudice, come dati."""
    misura = misura_versione(versione)
    print("")
    print("Riepilogo di %s (%s, effort %s)"
          % (versione, misura.modello, misura.effort or "?"))
    print(riga_tabella("caso", "token in", "token out", "costo $",
                       "controlli", "giudice"))
    for r in misura.righe:
        print(riga_tabella(r.caso, str(r.entrata), str(r.uscita),
                           virgola(r.costo, 4),
                           "%d/%d" % (r.controlli_ok, r.controlli_n),
                           "%d/%d" % (r.giudice_ok, r.giudice_n)))
    print(riga_tabella(
        "totale", "%d" % misura.somma("entrata"),
        "%d" % misura.somma("uscita"), virgola(misura.somma("costo"), 4),
        "%d/%d" % (misura.somma("controlli_ok"), misura.somma("controlli_n")),
        "%d/%d" % (misura.somma("giudice_ok"), misura.somma("giudice_n"))))
    stampa_costi_e_giudice(misura)
    return misura


def stampa_costi_e_giudice(misura: Misura) -> None:
    """Le righe di dati sotto la tabella: il costo ricalcolato accanto a
    total_cost_usd del JSON, e che cosa è costato il giudice."""
    print("")
    costi_json = [r.costo_json for r in misura.righe]
    if all(c is not None for c in costi_json):
        somma_json = sum(c for c in costi_json if c is not None)
        print("  costo ricalcolato da listino.json: %s; somma dei "
              "total_cost_usd del JSON: %s (differenza %s $; un dato)" % (
                  dollari(misura.somma("costo")), dollari(somma_json),
                  virgola(misura.somma("costo") - somma_json, 4)))
    else:
        print("  costo ricalcolato da listino.json: %s; total_cost_usd non "
              "c'è in tutti i JSON" % dollari(misura.somma("costo")))
    avvolgi("il giudice (haiku): %d chiamate, %d token in entrata, %d in "
            "uscita, %s ricalcolati; durata delle chiamate, risposte e "
            "giudizi: %s s (dati)" % (
                len(misura.righe), misura.somma("giudice_entrata"),
                misura.somma("giudice_uscita"),
                dollari(misura.somma("giudice_costo")),
                virgola(misura.somma("secondi")
                        + misura.somma("giudice_secondi"), 1)), "  ", "    ")


def percento(prima: float, dopo: float) -> float:
    """La riduzione da prima a dopo, in percento (0 se prima è 0)."""
    if prima <= 0:
        return 0.0
    return (prima - dopo) * 100.0 / prima


def righe_riduzione(a: str, b: str, riduzione: float) -> List[str]:
    """Le due righe della riduzione dei token in entrata e dell'obiettivo
    del laboratorio: un dato."""
    return ["riduzione dei token in entrata, %s → %s: %s %%"
            % (a, b, virgola(riduzione, 1)),
            "obiettivo del laboratorio: almeno il %d %% in meno" % OBIETTIVO]


def confronta(a: str, b: str) -> None:
    """Le due versioni fianco a fianco, per caso e in totale, la riduzione
    dei token in entrata e la riga dell'obiettivo del laboratorio. Una
    misura che manca o è rotta si segnala prima di stampare."""
    ma, mb = misura_versione(a), misura_versione(b)
    print("Confronto %s → %s" % (a, b))
    print("%-8s %21s %17s %13s %13s" % ("caso", "token in", "token out",
                                         "controlli", "giudice"))
    for ra, rb in zip(ma.righe, mb.righe):
        print("%-8s %21s %17s %13s %13s" % (
            ra.caso, "%d → %d" % (ra.entrata, rb.entrata),
            "%d → %d" % (ra.uscita, rb.uscita),
            "%d/%d → %d/%d" % (ra.controlli_ok, ra.controlli_n,
                               rb.controlli_ok, rb.controlli_n),
            "%d/%d → %d/%d" % (ra.giudice_ok, ra.giudice_n,
                               rb.giudice_ok, rb.giudice_n)))
    print("%-8s %21s %17s %13s %13s" % (
        "totale", "%d → %d" % (ma.somma("entrata"), mb.somma("entrata")),
        "%d → %d" % (ma.somma("uscita"), mb.somma("uscita")),
        "%d/%d → %d/%d" % (ma.somma("controlli_ok"), ma.somma("controlli_n"),
                           mb.somma("controlli_ok"), mb.somma("controlli_n")),
        "%d/%d → %d/%d" % (ma.somma("giudice_ok"), ma.somma("giudice_n"),
                           mb.somma("giudice_ok"), mb.somma("giudice_n"))))
    print("")
    for riga in righe_riduzione(a, b, percento(ma.somma("entrata"),
                                               mb.somma("entrata"))):
        print("  " + riga)
    print("  costo ricalcolato: %s → %s (un dato: nel prezzo conta anche la "
          "cache)" % (dollari(ma.somma("costo")), dollari(mb.somma("costo"))))
    for versione in (a, b):
        if opzioni_di(versione).get("composti") != impronta_composti(versione):
            avvolgi("attenzione: i file di %s (il prompt, i documenti o i "
                    "casi) sono cambiati dopo la misura: misurate di nuovo "
                    "%s prima di confrontare" % (versione, versione),
                    "  ", "    ")
    if (ma.modello, ma.effort) != (mb.modello, mb.effort):
        avvolgi("attenzione: %s è misurata con %s e effort %s, %s con %s e "
                "effort %s: il confronto vale solo a parità di modello e di "
                "effort" % (a, ma.modello, ma.effort, b, mb.modello,
                            mb.effort), "  ", "    ")


def errore(messaggio: str, codice: int) -> NoReturn:
    """Il messaggio su STDERR e l'uscita."""
    sys.stderr.write("kit.py: %s\n" % messaggio)
    sys.exit(codice)


def main(argv: List[str]) -> int:
    comandi = {"casi": 0, "componi": 2, "opzioni": 3, "estrai": 2,
               "controlla": 2, "consegna": 2, "giudizio": 2, "riepilogo": 1,
               "confronta": 2}
    if not argv or argv[0] not in comandi or len(argv) != comandi[argv[0]] + 1:
        sys.stderr.write(__doc__ or "")
        return 2
    comando = argv[0]
    try:
        if comando == "casi":
            print("\n".join(CASI))
        elif comando == "componi":
            print(componi(argv[1], argv[2]))
        elif comando == "opzioni":
            scrivi_opzioni(argv[1], argv[2], argv[3])
        elif comando == "estrai":
            estrai(argv[1], argv[2])
        elif comando == "controlla":
            return 0 if controlla(argv[1], argv[2]) else 1
        elif comando == "consegna":
            print(consegna(argv[1], argv[2]))
        elif comando == "giudizio":
            stampa_giudizio(argv[1], argv[2])
        elif comando == "riepilogo":
            riepilogo(argv[1])
        else:
            confronta(argv[1], argv[2])
    except Errore as exc:
        # Per controlla l'uscita 1 dice «un controllo non superato»: ogni
        # altro problema, lì, esce 2.
        errore(str(exc), 2 if comando == "controlla" else exc.codice)
    except Exception as exc:  # l'ultima rete: un messaggio, mai un traceback
        errore("errore inatteso (%s: %s): avvisate il docente" % (
            type(exc).__name__, " ".join(str(exc).split())), 2)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
