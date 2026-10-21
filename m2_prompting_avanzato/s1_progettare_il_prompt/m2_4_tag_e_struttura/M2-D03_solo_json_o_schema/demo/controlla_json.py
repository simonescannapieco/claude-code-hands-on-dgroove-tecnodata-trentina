"""controlla_json.py -- quattro affermazioni di Anthropic sul JSON (M2-D03).

Tre si mettono alla prova sulle risposte; la quarta si mostra. Legge, nello
spazio di lavoro (la cartella data, o quella corrente):
  schema.json                        lo schema della demo;
  risposte/solo-json-<modello>.json  la richiesta «SOLO un JSON», a parole,
                                     a haiku, sonnet e opus (passo 2);
  risposte/schema-haiku.json         la stessa richiesta con --json-schema,
                                     a haiku (passo 3);
  risposte/schema-non-valido.json    lo STDOUT della stessa chiamata con lo
                                     schema non valido (passo 4);
  risposte/schema-non-valido.txt     il suo STDERR e, per ultima, la riga
                                     «uscita: N» con il codice d'uscita.
Stampa i numeri che legge, l'esito delle affermazioni 1, 2 e 3 e la
dimostrazione della 4; senza --senza-esiti scrive poi esiti.tsv:
l'intestazione «affermazione<TAB>classe<TAB>esito<TAB>dettaglio» e una riga
per affermazione, in quest'ordine:
  1. «Se lo chiedete, il JSON arriva valido e conforme», da provare: per
     ogni modello, il testo intero della risposta si legge come JSON e
     rispetta schema.json? Si conta, e non decide l'uscita.
  2. «Con --json-schema, structured_output è validato», garantita: subtype
     success, e structured_output c'è e rispetta schema.json.
  3. «Uno schema non valido fa uscire claude con un errore, all'avvio»,
     garantita: l'uscita non è 0, c'è la riga «is not a valid JSON Schema»
     (su STDERR, o su STDOUT), e sullo STDOUT non c'è una risposta (né
     result né usage). La riga d'errore con «uscita: 0» e nessuna risposta
     non la decide: la riga «uscita» non è venuta subito dopo claude.
  4. «Lo schema controlla la forma, non il contenuto», una dimostrazione:
     una copia dell'oggetto della 2 con un altro valore ammesso di
     tipo_cliente -- un oggetto modificato dal controllo, non una risposta
     del modello -- rispetta ancora lo schema. La costruisce e la valida il
     controllo, quindi nessuna esecuzione la decide: si stampa con le sue
     righe, nella classe «dimostrazione» e con l'esito «nessun verdetto»,
     e non decide l'uscita. Accanto, un dato e non un verdetto: in quante
     risposte c'è il telefono del cliente.
L'esito è «confermata», «non confermata in questa esecuzione», oppure «non
distinguibile (perché)» quando la risposta che serve manca o non si legge.
Lo schema si controlla qui, con la sola libreria standard e per lo schema
di questa demo (un oggetto di stringhe, con enum): le chiavi richieste,
nessuna in più, il tipo stringa, i valori ammessi.

Uso:    python3 controlla_json.py [--senza-esiti] [<spazio di lavoro>]
          senza cartella, quella corrente; con --senza-esiti non scrive e
          non toglie esiti.tsv (lo usa verifica.sh, che non cambia niente)
Uscita: 0 ogni risposta c'è e le garanzie 2 e 3 sono confermate (la 1 si
          conta e basta, la 4 si mostra)
        1 manca la cartella risposte/ (nessun esiti.tsv: uno vecchio viene
          tolto), una risposta manca o non si legge, oppure una delle due
          garanzie non è confermata; esiti.tsv è scritto lo stesso
        2 uso sbagliato, lo spazio di lavoro assente, schema.json assente o
          non quello della demo, un file che c'è ma non si legge, esiti.tsv
          che non si scrive, un errore inatteso (una riga, mai un
          traceback): nessun esiti.tsv resta (uno vecchio viene tolto)
"""
from __future__ import annotations

import json
import os
import re
import sys
from typing import List, NamedTuple, Optional, Tuple

MODELLI = ("haiku", "sonnet", "opus")
CARTELLA = "risposte"
ESITI = "esiti.tsv"
INTESTAZIONE = "affermazione\tclasse\tesito\tdettaglio"
TELEFONO = re.compile(r"000[ .-]?000[ .-]?0103")
BLOCCO_CODICE = re.compile(r"^\s*```")
ERRORE_ATTESO = "is not a valid JSON Schema"
# Il codice d'uscita: cifre ASCII, al più dodici, così int() non riceve mai
# un testo senza limiti.
USCITA = re.compile(r"^uscita: ([0-9]{1,12})$")
RIGA_MAX = 300  # i caratteri della riga d'errore riportata

GARANTITA = "garantita"
DA_PROVARE = "da provare"
DIMOSTRAZIONE = "dimostrazione"
CONFERMATA = "confermata"
NON_CONFERMATA = "non confermata in questa esecuzione"
NESSUN_VERDETTO = "nessun verdetto"

A_PAROLE = "Se lo chiedete, il JSON arriva valido e conforme"
CON_SCHEMA = "Con --json-schema, structured_output è validato"
SCHEMA_NON_VALIDO = ("Uno schema non valido fa uscire claude con un errore, "
                     "all'avvio")
FORMA = "Lo schema controlla la forma, non il contenuto"
MODIFICATO = ("un oggetto modificato dal controllo, non una risposta del "
              "modello")
PARTENZA = "Manca la cartella risposte/: eseguite i passi del README."
NON_ANCORA = ("Non ancora: una risposta manca o non si legge; rifate il "
              "passo indicato fra parentesi, poi rilanciate il controllo.")
USO = "Uso: python3 controlla_json.py [--senza-esiti] [<spazio di lavoro>]\n"


class Precondizione(Exception):
    """Il controllo non può girare: l'uscita 2."""


class Esito(NamedTuple):
    """Una riga di esiti.tsv."""
    affermazione: str
    classe: str
    esito: str
    dettaglio: str


class Risposta(NamedTuple):
    """Il JSON di una chiamata claude -p, oppure perché non c'è."""
    doc: Optional[dict]
    problema: str


def sino(valore: bool) -> str:
    """sì oppure no."""
    return "sì" if valore else "no"


def pulita(testo: str) -> str:
    """Il testo su una riga, senza tabulazioni né a capo: una cella."""
    return " ".join(testo.split())


def estratto(riga: str) -> str:
    """Una riga d'errore pulita, al più RIGA_MAX caratteri."""
    riga = pulita(riga)
    if len(riga) > RIGA_MAX:
        return riga[:RIGA_MAX - 1] + "…"
    return riga


def minuscola(testo: str) -> str:
    """Il testo con la prima lettera minuscola."""
    return testo[:1].lower() + testo[1:]


def non_distinguibile(perche: str) -> str:
    """L'esito di un'affermazione che una risposta mancante non lascia
    decidere."""
    return "non distinguibile (%s)" % perche


def rispetta(oggetto: object, schema: dict) -> bool:
    """Vero se l'oggetto rispetta lo schema della demo."""
    if not isinstance(oggetto, dict):
        return False
    campi = schema.get("properties", {})
    if any(k not in oggetto for k in schema.get("required", [])):
        return False
    if schema.get("additionalProperties") is False and any(
            k not in campi for k in oggetto):
        return False
    for chiave, regola in campi.items():
        if chiave not in oggetto:
            continue
        valore = oggetto[chiave]
        if regola.get("type") == "string" and not isinstance(valore, str):
            return False
        if "enum" in regola and valore not in regola["enum"]:
            return False
    return True


def schema_della_demo(schema: object) -> bool:
    """Vero se lo schema ha la forma che rispetta() sa leggere, con
    tipo_cliente obbligatorio e almeno due valori ammessi (la 4)."""
    if not isinstance(schema, dict):
        return False
    campi = schema.get("properties")
    richiesti = schema.get("required", [])
    if not isinstance(campi, dict) or not isinstance(richiesti, list):
        return False
    if not all(isinstance(k, str) for k in richiesti):
        return False
    for regola in campi.values():
        if not isinstance(regola, dict):
            return False
        if "enum" in regola and not isinstance(regola["enum"], list):
            return False
    tipo = campi.get("tipo_cliente")
    ammessi = tipo.get("enum") if isinstance(tipo, dict) else None
    return ("tipo_cliente" in richiesti and isinstance(ammessi, list)
            and all(isinstance(v, str) for v in ammessi)
            and len(set(ammessi)) >= 2)


def leggi_testo(percorso: str) -> Optional[str]:
    """Il testo di un file, None se non c'è; i byte che non sono UTF-8
    diventano «�». Un file che c'è ma non si legge: Precondizione."""
    try:
        with open(percorso, encoding="utf-8", errors="replace") as fh:
            return fh.read()
    except FileNotFoundError:
        return None
    except OSError as exc:
        raise Precondizione("%s non si legge (%s)"
                            % (percorso, exc.strerror or exc)) from None


def leggi_risposta(percorso: str) -> Risposta:
    """Il JSON di claude -p in un file, oppure perché non c'è."""
    testo = leggi_testo(percorso)
    if testo is None:
        return Risposta(None, "manca %s" % percorso)
    try:
        doc = json.loads(testo)
    except (ValueError, RecursionError):
        return Risposta(None, "%s non è un JSON valido" % percorso)
    if not isinstance(doc, dict):
        return Risposta(None, "%s non è il JSON di claude -p" % percorso)
    return Risposta(doc, "")


def leggi_schema() -> dict:
    """schema.json; Precondizione se manca o non è lo schema della demo."""
    testo = leggi_testo("schema.json")
    if testo is None:
        raise Precondizione("manca schema.json")
    try:
        schema = json.loads(testo)
    except (ValueError, RecursionError):
        raise Precondizione("schema.json non è un JSON valido") from None
    if not schema_della_demo(schema):
        raise Precondizione("schema.json non è lo schema della demo")
    return schema


def problema_risultato(doc: dict) -> str:
    """Perché un JSON di claude -p non porta una risposta: «» se la porta."""
    if doc.get("is_error"):
        return "la chiamata è finita con un errore (is_error)"
    if not isinstance(doc.get("result"), str):
        return "manca il campo result"
    return ""


def valuta_testo(testo: str, schema: dict) -> Tuple[bool, bool]:
    """(il testo intero si legge come JSON, l'oggetto rispetta lo schema)."""
    try:
        oggetto = json.loads(testo)
    except (ValueError, RecursionError):
        return False, False
    return True, rispetta(oggetto, schema)


def prova_1(schema: dict) -> Tuple[Esito, List[str], List[str]]:
    """L'affermazione 1. Returns: l'esito, le righe dei numeri, i testi
    delle risposte lette (per il telefono)."""
    righe: List[str] = []
    testi: List[str] = []
    parti: List[str] = []
    mancano: List[str] = []
    conformi = 0
    for modello in MODELLI:
        nome = "solo-json-%s.json" % modello
        risposta = leggi_risposta("risposte/" + nome)
        problema = risposta.problema
        if not problema:
            problema = problema_risultato(risposta.doc)
        if problema:
            righe.append("  %s: %s" % (nome, problema))
            parti.append("%s: %s" % (modello, problema))
            mancano.append("%s: rifate la chiamata di %s, passo 2"
                           % (problema, modello))
            continue
        testo = risposta.doc["result"]
        testi.append(testo)
        valido, conforme = valuta_testo(testo, schema)
        conformi += int(conforme)
        nota = ""
        if not valido and BLOCCO_CODICE.match(testo):
            nota = " (dentro un blocco di codice)"
        numeri = "JSON valido %s%s, conforme allo schema %s" % (
            sino(valido), nota, sino(conforme))
        righe.append("  %s: %s, telefono del cliente %s" % (
            nome, numeri, sino(bool(TELEFONO.search(testo)))))
        parti.append("%s: %s" % (modello, numeri))
    conteggio = "%d su %d validi e conformi" % (conformi,
                                                 len(MODELLI) - len(mancano))
    righe.append("  a parole: " + conteggio)
    parti.append(conteggio)
    if mancano:
        esito = non_distinguibile("; ".join(mancano))
    elif conformi == len(MODELLI):
        esito = CONFERMATA
    else:
        esito = NON_CONFERMATA
    return (Esito(A_PAROLE, DA_PROVARE, esito, "; ".join(parti)), righe,
            testi)


def esito_2(doc: dict, presente: bool, conforme: bool) -> str:
    """L'esito della 2 dal JSON della chiamata con lo schema."""
    subtype = doc.get("subtype")
    if doc.get("is_error") or subtype != "success":
        return non_distinguibile(
            "la chiamata è finita con un errore (subtype %s)%s: rifate il "
            "passo 3" % (pulita(str(subtype)),
                         "" if presente else ", senza structured_output"))
    if not presente:
        return non_distinguibile(
            "subtype success ma nessuno structured_output: la "
            "documentazione dice di trattare anche questo caso come un "
            "errore; rifate il passo 3")
    return CONFERMATA if conforme else NON_CONFERMATA


def prova_2(schema: dict) -> Tuple[Esito, List[str], Optional[dict],
                                   Optional[str]]:
    """L'affermazione 2. Returns: l'esito, le righe dei numeri, l'oggetto
    validato (None se non c'è o non rispetta lo schema) e il testo di
    structured_output (per il telefono; None se non c'è)."""
    nome = "schema-haiku.json"
    risposta = leggi_risposta("risposte/" + nome)
    if risposta.doc is None:
        esito = non_distinguibile("%s: rifate il passo 3" % risposta.problema)
        return (Esito(CON_SCHEMA, GARANTITA, esito, risposta.problema),
                ["  %s: %s" % (nome, risposta.problema)], None, None)
    doc = risposta.doc
    oggetto = doc.get("structured_output")
    presente = oggetto is not None
    conforme = presente and rispetta(oggetto, schema)
    subtype = doc.get("subtype")
    numeri = "subtype %s, structured_output %s, conforme allo schema %s" % (
        "assente" if subtype is None else pulita(str(subtype)),
        sino(presente), sino(conforme))
    testo: Optional[str] = None
    riga = "  %s: %s" % (nome, numeri)
    if presente:
        try:
            testo = json.dumps(oggetto, ensure_ascii=False)
        except (ValueError, RecursionError):
            testo = ""
        riga += ", telefono del cliente %s" % sino(
            bool(TELEFONO.search(testo)))
    return (Esito(CON_SCHEMA, GARANTITA, esito_2(doc, presente, conforme),
                  numeri), [riga], oggetto if conforme else None, testo)


def riga_errore(errori: str, uscita_std: str) -> Tuple[str, str]:
    """La prima riga con ERRORE_ATTESO, su STDERR o altrimenti su STDOUT,
    e il canale; ("", "") se non c'è."""
    for canale, testo in (("STDERR", errori), ("STDOUT", uscita_std)):
        for riga in testo.splitlines():
            if ERRORE_ATTESO in riga:
                return estratto(riga), canale
    return "", ""


def descrivi_stdout(testo: str) -> Tuple[bool, str]:
    """(sullo STDOUT c'è una risposta del modello, come si descrive)."""
    if not testo.strip():
        return False, "niente"
    try:
        doc = json.loads(testo)
    except (ValueError, RecursionError):
        return False, "un testo, senza result né usage"
    if isinstance(doc, dict) and ("result" in doc or "usage" in doc):
        return True, "un JSON con result o usage: il modello ha risposto"
    return False, "un JSON senza result né usage"


def esito_3(codice: int, riga: str, risposto: bool) -> str:
    """L'esito della 3: una risposta del modello sullo STDOUT, o
    un'uscita 0 senza la riga d'errore, non la confermano; la riga
    d'errore con «uscita: 0» e nessuna risposta non la decide (la riga
    «uscita» non è venuta subito dopo claude), e nemmeno un'uscita
    diversa da 0 senza la riga (un altro errore)."""
    if riga and risposto:
        return NON_CONFERMATA
    if riga and codice == 0:
        return non_distinguibile(
            "c'è la riga «%s», ma con «uscita: 0» e nessuna risposta sullo "
            "STDOUT: la riga «uscita» va subito dopo claude; rifate il "
            "passo 4" % ERRORE_ATTESO)
    if codice == 0:
        return NON_CONFERMATA
    if not riga:
        return non_distinguibile(
            "claude è uscito con %d, ma senza la riga «%s»: un altro "
            "errore, leggete risposte/schema-non-valido.txt"
            % (codice, ERRORE_ATTESO))
    return CONFERMATA


def prova_3() -> Tuple[Esito, List[str]]:
    """L'affermazione 3: il codice d'uscita, la riga d'errore, lo STDOUT."""
    errori = leggi_testo("risposte/schema-non-valido.txt")
    uscita_std = leggi_testo("risposte/schema-non-valido.json")
    problema = ""
    if errori is None:
        problema = "manca risposte/schema-non-valido.txt"
    elif uscita_std is None:
        problema = "manca risposte/schema-non-valido.json"
    if problema:
        return (Esito(SCHEMA_NON_VALIDO, GARANTITA, non_distinguibile(
            "%s: eseguite il passo 4" % problema), problema),
                ["  schema-non-valido: " + problema])
    codici = [m.group(1) for m in (USCITA.match(r.strip())
                                   for r in errori.splitlines()) if m]
    if not codici:
        problema = ("in risposte/schema-non-valido.txt manca la riga "
                    "«uscita: N»")
        return (Esito(SCHEMA_NON_VALIDO, GARANTITA, non_distinguibile(
            "%s: eseguite il passo 4 per intero" % problema), problema),
                ["  schema-non-valido: " + problema])
    codice = int(codici[-1])
    riga, canale = riga_errore(errori, uscita_std)
    risposto, stdout = descrivi_stdout(uscita_std)
    trovata = ("su %s «%s»" % (canale, riga) if riga
               else "nessuna riga «%s»" % ERRORE_ATTESO)
    numeri = "uscita %d; %s; su STDOUT %s" % (codice, trovata, stdout)
    return (Esito(SCHEMA_NON_VALIDO, GARANTITA,
                  esito_3(codice, riga, risposto), numeri),
            ["  schema-non-valido: " + numeri])


def prova_4(schema: dict, oggetto: Optional[dict],
            testi: List[str]) -> Tuple[Esito, List[str]]:
    """La 4, una dimostrazione senza verdetto: una copia dell'oggetto
    validato, con un altro valore ammesso di tipo_cliente, rispetta ancora
    lo schema; accanto, in quante risposte c'è il telefono del cliente.
    Returns: la riga di esiti.tsv e le righe da stampare."""
    con = sum(1 for testo in testi if TELEFONO.search(testo))
    telefono = "telefono del cliente in %d risposte su %d" % (con,
                                                              len(testi))
    if oggetto is None:
        cambio = "nessun oggetto validato da modificare: vedi l'affermazione 2"
        righe = ["  " + cambio, "  " + telefono]
    else:
        prima = oggetto["tipo_cliente"]
        dopo = [v for v in schema["properties"]["tipo_cliente"]["enum"]
                if v != prima][0]
        copia = dict(oggetto, tipo_cliente=dopo)
        cambio = "tipo_cliente «%s» → «%s» (%s): conforme allo schema %s" % (
            prima, dopo, MODIFICATO, sino(rispetta(copia, schema)))
        righe = ["  la copia: " + cambio, "  " + telefono]
    return (Esito(FORMA, DIMOSTRAZIONE, NESSUN_VERDETTO,
                  "%s; %s" % (cambio, telefono)), righe)


def stampa(righe: List[str], esiti: List[Esito],
           dimostrazione: List[str]) -> None:
    """I numeri letti; una riga per affermazione messa alla prova e, per
    una garanzia non confermata, che cosa garantisce la documentazione;
    poi la dimostrazione della 4, senza verdetto."""
    print("Le risposte, come le legge il controllo:")
    for riga in righe:
        print(riga)
    print("Le affermazioni:")
    for esito in esiti:
        print("  %s (%s): %s" % (esito.affermazione, esito.classe,
                                 esito.esito))
    for numero, esito in enumerate(esiti, start=1):
        if esito.esito != NON_CONFERMATA:
            continue
        if esito.classe == GARANTITA:
            print("La documentazione garantisce che %s: in questa "
                  "esecuzione no." % minuscola(esito.affermazione))
        else:
            print("L'affermazione %d è da provare: si conta, e non fa "
                  "fallire la verifica." % numero)
    print("%s (una dimostrazione, nessun verdetto):" % FORMA)
    for riga in dimostrazione:
        print(riga)


def scrivi(esiti: List[Esito]) -> None:
    """esiti.tsv: l'intestazione e una riga per affermazione."""
    righe = [INTESTAZIONE] + ["\t".join(pulita(c) for c in esito)
                              for esito in esiti]
    try:
        with open(ESITI, "w", encoding="utf-8", newline="\n") as fh:
            fh.write("\n".join(righe) + "\n")
    except OSError as exc:
        raise Precondizione("%s non si scrive (%s)"
                            % (ESITI, exc.strerror or exc)) from None


def togli_vecchio() -> None:
    """Toglie l'esiti.tsv di un'esecuzione precedente: un controllo che
    non ha potuto girare non lascia esiti che sembrano suoi."""
    try:
        os.remove(ESITI)
    except FileNotFoundError:
        return  # non c'era: niente da togliere
    except OSError as exc:
        sys.stderr.write("controlla_json.py: il vecchio %s resta (%s) e non "
                         "vale per questa esecuzione\n"
                         % (ESITI, exc.strerror or exc))


def manca_qualcosa(esiti: List[Esito]) -> bool:
    """Vero se una risposta che serve manca o non si legge."""
    return any(e.esito.startswith("non distinguibile") for e in esiti)


def uscita(esiti: List[Esito]) -> int:
    """1 se una risposta manca o una garanzia non è confermata; 0."""
    if manca_qualcosa(esiti):
        return 1
    if any(e.classe == GARANTITA and e.esito != CONFERMATA for e in esiti):
        return 1
    return 0


def controlla(scrivi_esiti: bool) -> int:
    """Il controllo nella cartella corrente, lo spazio di lavoro: stampa,
    scrive esiti.tsv se scrivi_esiti, e restituisce l'uscita 0 o 1.
    Precondizione per l'uscita 2."""
    schema = leggi_schema()
    if not os.path.isdir(CARTELLA):
        print(PARTENZA)
        if scrivi_esiti:
            togli_vecchio()
        return 1
    esito1, righe1, testi = prova_1(schema)
    esito2, righe2, oggetto, testo2 = prova_2(schema)
    esito3, righe3 = prova_3()
    if testo2 is not None:
        testi = testi + [testo2]
    esito4, righe4 = prova_4(schema, oggetto, testi)
    esiti = [esito1, esito2, esito3]
    stampa(righe1 + righe2 + righe3, esiti, righe4)
    if manca_qualcosa(esiti):
        print(NON_ANCORA)
    if scrivi_esiti:
        scrivi(esiti + [esito4])
        print("Scritto %s." % ESITI)
    return uscita(esiti)


def errore(messaggio: str) -> int:
    """Il messaggio su STDERR, in una riga; l'uscita 2."""
    sys.stderr.write("controlla_json.py: %s\n" % messaggio)
    return 2


def uso(messaggio: str) -> int:
    """Un argomento sbagliato: il motivo e l'uso; l'uscita 2."""
    errore(messaggio)
    sys.stderr.write(USO)
    return 2


def main(argv: List[str]) -> int:
    for flusso in (sys.stdout, sys.stderr):
        riconfigura = getattr(flusso, "reconfigure", None)
        if riconfigura is not None:
            riconfigura(errors="replace")
    scrivi_esiti = True
    posizionali: List[str] = []
    for arg in argv:
        if arg == "--senza-esiti":
            scrivi_esiti = False
        elif arg.startswith("-"):
            return uso("opzione sconosciuta: %s" % arg)
        else:
            posizionali.append(arg)
    if len(posizionali) > 1:
        return uso("uno spazio di lavoro per volta")
    ws = posizionali[0] if posizionali else "."
    if not os.path.isdir(ws):
        return errore("spazio di lavoro assente: %s" % ws)
    try:
        os.chdir(ws)
    except OSError as exc:
        return errore("lo spazio di lavoro %s non si apre (%s)"
                      % (ws, exc.strerror or exc))
    try:
        return controlla(scrivi_esiti)
    except Precondizione as exc:
        errore(str(exc))
    except Exception as exc:  # mai un traceback: un errore inatteso esce 2
        errore("errore inatteso (%s: %s)"
               % (type(exc).__name__, " ".join(str(exc).split())))
    if scrivi_esiti:
        togli_vecchio()
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
