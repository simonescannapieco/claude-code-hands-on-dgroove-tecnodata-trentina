"""controlla_etichette.py -- che cosa hanno restituito le chiamate di M2-D04,
e tre affermazioni di Anthropic alla prova.

Legge, nello spazio di lavoro (la cartella data, o quella corrente),
risposte/<variante>-<modello>.json, il JSON di `claude -p --output-format
json` delle quattro varianti (zero-shot, few-shot, con-etichette, schema)
su haiku e su sonnet. Per ogni risposta stampa i dati, per ogni modello un
verdetto per ciascuna delle tre affermazioni; senza --senza-esiti scrive
anche esiti.tsv, una riga per file:
  forma_esempi       sì se la risposta è una riga sola nella forma degli
                     esempi: tre campi di lettere minuscole e trattini
                     bassi, separati da « | » (un «Classificazione:»
                     davanti è ammesso: c'è negli esempi); — per schema
  etichette_ammesse  solo per con-etichette, il prompt che le elenca: sì
                     se ogni campo è fra le etichette elencate; — se la
                     risposta non ha la forma, e per le altre varianti
  oggetto_schema     solo per schema: sì se structured_output rispetta
                     schema.json (le chiavi richieste, nessuna in più,
                     ogni valore fra quelli dell'enum, senza badare alle
                     maiuscole, che la documentazione non garantisce); no
                     se non lo rispetta; assente se la chiamata non l'ha
                     restituito (un errore, o il campo che manca); — per
                     le altre varianti
  scelta             la categoria, la priorità e il team come li ha
                     scritti il modello; senza la forma, la risposta
                     intera su una riga. È un dato: il controllo non lo
                     giudica.
I verdetti, per haiku e per sonnet, ciascuno solo se ci sono le risposte
che lo decidono:
  «Gli esempi orientano il formato», una raccomandazione: confermata se la
      forma degli esempi manca con zero-shot e c'è con few-shot; non
      distinguibile se c'è già con zero-shot; non confermata in questa
      esecuzione se manca con few-shot;
  «Con l'elenco nel prompt, forma ed etichette rispettate», una
      raccomandazione: confermata se la risposta di con-etichette ha la
      forma e solo etichette elencate;
  «Con --json-schema, l'oggetto rispetta lo schema», una garanzia:
      confermata se oggetto_schema vale «sì»; un «no» non la conferma; un
      oggetto assente è una chiamata fallita, da rifare.
Prima di leggere le risposte confronta gli enum di schema.json con gli
elenchi di con-etichette.md (le righe «Categorie:», «Priorità:», «Team:»):
devono essere uguali, nello stesso ordine. Con --solo-schema fa soltanto
questo confronto: la demo del docente lo fa prima delle chiamate.

Uso:    python3 controlla_etichette.py [--solo-schema | --senza-esiti]
          [<spazio di lavoro>]
          senza cartella, quella corrente; con --senza-esiti non scrive e
          non toglie esiti.tsv (lo usa verifica.sh, che non cambia niente)
Uscita: 0 le otto risposte ci sono e la garanzia dello schema è confermata
          su tutti e due i modelli (con --solo-schema: gli enum sono uguali
          agli elenchi); le due raccomandazioni non decidono l'uscita
        1 manca la cartella risposte/ (nessun esiti.tsv: uno vecchio viene
          tolto), una risposta manca o non è il JSON riuscito di claude -p,
          una chiamata con lo schema senza oggetto, oppure la garanzia non
          confermata; esiti.tsv ha le righe delle risposte che ci sono
        2 uso sbagliato; lo spazio di lavoro assente; con-etichette.md o
          schema.json assenti, illeggibili o non validi; un enum diverso
          dal suo elenco; una risposta che non si legge; esiti.tsv che non
          si scrive; un errore inatteso (una riga, mai un traceback):
          nessun esiti.tsv resta (uno vecchio viene tolto)
"""
from __future__ import annotations

import json
import os
import re
import sys
from typing import Dict, List, Tuple

MODELLI = ("haiku", "sonnet")
VARIANTI = ("zero-shot", "few-shot", "con-etichette", "schema")
# Ogni campo di schema.json, con la riga di con-etichette.md che lo elenca.
CAMPI = (("categoria", "Categorie:"), ("priorita", "Priorità:"),
         ("team", "Team:"))
CARTELLA = "risposte"
PROMPT = "con-etichette.md"
SCHEMA = "schema.json"
ESITI = "esiti.tsv"
INTESTAZIONE = ["file", "forma_esempi", "etichette_ammesse",
                "oggetto_schema", "scelta"]
FORMA = re.compile(r"[a-z_]+ \| [a-z_]+ \| [a-z_]+")
PREFISSO = re.compile(r"[Cc]lassificazione:[ \t]*")
NA = "—"
S_ESEMPI = "Gli esempi orientano il formato"
S_ELENCO = "Con l'elenco nel prompt, forma ed etichette rispettate"
S_SCHEMA = "Con --json-schema, l'oggetto rispetta lo schema"
CONFERMATA = "confermata"
NON_CONFERMATA = "non confermata in questa esecuzione"
GIA_SENZA = "non distinguibile (la forma degli esempi c'è già senza esempi)"
FALLITA = ("chiamata fallita (la risposta non ha structured_output: rifate "
           "quella chiamata)")
GARANZIA = ("  La documentazione garantisce un output JSON convalidato sullo "
            "schema: in questa esecuzione no.")
PARTENZA = "Manca la cartella risposte/: eseguite i passi del README."
NON_ANCORA = ("Non ancora: una risposta manca o non è il JSON riuscito di "
              "claude -p; rifate la chiamata indicata sopra, poi rilanciate "
              "il controllo.")
USO = ("Uso: python3 controlla_etichette.py [--solo-schema | --senza-esiti] "
       "[<spazio di lavoro>]\n")

Righe = Dict[Tuple[str, str], List[str]]


class Precondizione(Exception):
    """Un file d'ingresso che manca, non si legge o non va: uscita 2."""


class Mancante(Exception):
    """Una risposta che manca o non è il JSON riuscito di claude -p:
    uscita 1."""


def sino(vero: bool) -> str:
    """sì oppure no."""
    return "sì" if vero else "no"


def compatta(testo: str) -> str:
    """Il testo su una riga sola: ogni sequenza di spazi, a capo e
    tabulazioni diventa uno spazio."""
    return " ".join(testo.split())


def nell_elenco(valore: object, elenco: List[object]) -> bool:
    """Vero se il valore è una stringa dell'elenco, senza badare alle
    maiuscole: la documentazione non garantisce le maiuscole dei valori
    enum."""
    if not isinstance(valore, str):
        return False
    return valore.casefold() in [v.casefold() for v in elenco
                                 if isinstance(v, str)]


def testo_di(percorso: str) -> str:
    """Il testo di un file d'ingresso; Precondizione se manca o non si
    legge."""
    try:
        with open(percorso, encoding="utf-8") as fh:
            return fh.read()
    except FileNotFoundError:
        raise Precondizione("manca %s nello spazio di lavoro" % percorso)
    except (OSError, ValueError) as exc:
        raise Precondizione("%s non si legge (%s)" % (percorso, exc))


def elenchi() -> Dict[str, List[str]]:
    """Le etichette elencate in con-etichette.md, per campo di
    schema.json."""
    righe = testo_di(PROMPT).splitlines()
    trovati: Dict[str, List[str]] = {}
    for campo, titolo in CAMPI:
        valori = [r[len(titolo):] for r in righe if r.startswith(titolo)]
        if len(valori) != 1:
            raise Precondizione("%s: attesa una riga «%s …», trovate %d"
                                % (PROMPT, titolo, len(valori)))
        voci = [v.strip() for v in valori[0].strip().rstrip(".").split(",")]
        if not all(voci):
            raise Precondizione("%s: un'etichetta vuota nella riga «%s»"
                                % (PROMPT, titolo))
        trovati[campo] = voci
    return trovati


def forma_valida(schema: object) -> bool:
    """Vero se lo schema ha la forma che rispetta() sa leggere: properties
    un oggetto di oggetti (un enum, se c'è, è un elenco) e required, se
    c'è, un elenco di nomi."""
    if not isinstance(schema, dict):
        return False
    campi = schema.get("properties")
    obbligatori = schema.get("required", [])
    return (isinstance(campi, dict)
            and all(isinstance(r, dict)
                    and isinstance(r.get("enum", []), list)
                    for r in campi.values())
            and isinstance(obbligatori, list)
            and all(isinstance(k, str) for k in obbligatori))


def leggi_schema(etichette: Dict[str, List[str]]) -> dict:
    """schema.json, se ogni suo enum è uguale all'elenco del prompt."""
    try:
        schema = json.loads(testo_di(SCHEMA))
    except (ValueError, RecursionError) as exc:
        raise Precondizione("%s non è un JSON valido (%s)" % (SCHEMA, exc))
    if not forma_valida(schema):
        raise Precondizione("%s: attesi «properties», un oggetto per campo, "
                            "e «required», un elenco di nomi" % SCHEMA)
    for campo, titolo in CAMPI:
        if schema["properties"].get(campo, {}).get("enum") \
                != etichette[campo]:
            raise Precondizione("%s: l'enum di «%s» è diverso dall'elenco "
                                "«%s» di %s" % (SCHEMA, campo, titolo,
                                                PROMPT))
    return schema


def rispetta(oggetto: object, schema: dict) -> bool:
    """Vero se l'oggetto rispetta lo schema: le chiavi richieste, nessuna
    in più se additionalProperties è false, il tipo string, ogni valore
    fra quelli dell'enum senza badare alle maiuscole."""
    if not isinstance(oggetto, dict):
        return False
    campi = schema["properties"]
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
        if "enum" in regola and not nell_elenco(valore, regola["enum"]):
            return False
    return True


def leggi_risposta(percorso: str) -> dict:
    """Il JSON di claude -p in un file di risposte/."""
    if not os.path.lexists(percorso):
        raise Mancante("manca %s: rifate quella chiamata" % percorso)
    try:
        with open(percorso, "rb") as fh:
            testo = fh.read().decode("utf-8", errors="replace")
    except OSError as exc:
        raise Precondizione("%s non si legge (%s)"
                            % (percorso, exc.strerror or exc))
    if not testo.strip():
        raise Mancante("%s è vuoto: la chiamata a claude è fallita? "
                       "Rifatela" % percorso)
    try:
        doc = json.loads(testo)
    except (ValueError, RecursionError):
        doc = None
    if not isinstance(doc, dict):
        raise Mancante("%s non è il JSON di claude -p: rifate quella "
                       "chiamata" % percorso)
    return doc


def riga_testo(percorso: str, doc: dict, variante: str,
               etichette: Dict[str, List[str]]) -> List[str]:
    """La riga di una risposta in testo: zero-shot, few-shot,
    con-etichette."""
    if doc.get("is_error"):
        raise Mancante("%s: claude ha restituito un errore; rifate quella "
                       "chiamata" % percorso)
    risultato = doc.get("result")
    if not isinstance(risultato, str) or not risultato.strip():
        raise Mancante("%s: manca la risposta («result»); rifate quella "
                       "chiamata" % percorso)
    riga = risultato.strip()
    prefisso = PREFISSO.match(riga)
    if prefisso:
        riga = riga[prefisso.end():]
    forma = FORMA.fullmatch(riga) is not None
    ammesse = NA
    if forma and variante == "con-etichette":
        ammesse = sino(all(
            nell_elenco(valore, etichette[campo])
            for valore, (campo, _) in zip(riga.split(" | "), CAMPI)))
    return [os.path.basename(percorso), sino(forma), ammesse, NA,
            riga if forma else compatta(risultato)]


def valore_scelto(oggetto: dict, campo: str) -> str:
    """Il valore di un campo dell'oggetto, come lo ha scritto il modello."""
    valore = oggetto.get(campo)
    if valore is None:
        return NA
    if isinstance(valore, str):
        return compatta(valore)
    return "(non è una stringa)"


def riga_schema(percorso: str, doc: dict, schema: dict) -> List[str]:
    """La riga della risposta con --json-schema: assente se la chiamata
    non ha restituito structured_output."""
    nome = os.path.basename(percorso)
    oggetto = doc.get("structured_output")
    if (doc.get("is_error") or doc.get("subtype", "success") != "success"
            or oggetto is None):
        return [nome, NA, NA, "assente", NA]
    if isinstance(oggetto, dict):
        scelta = " | ".join(valore_scelto(oggetto, c) for c, _ in CAMPI)
    else:
        scelta = "(non è un oggetto)"
    return [nome, NA, NA, sino(rispetta(oggetto, schema)), scelta]


def avviso(messaggio: str) -> None:
    """Una risposta da rifare, su STDERR."""
    sys.stderr.write("controlla_etichette.py: %s\n" % messaggio)


def leggi_righe(schema: dict, etichette: Dict[str, List[str]]
                ) -> Tuple[Righe, int]:
    """Le righe di esiti.tsv delle risposte che ci sono, per (modello,
    variante), e quante mancano o non vanno, ciascuna detta su STDERR.
    Precondizione se una risposta non si legge."""
    righe: Righe = {}
    mancanti = 0
    for modello in MODELLI:
        for variante in VARIANTI:
            percorso = "%s/%s-%s.json" % (CARTELLA, variante, modello)
            try:
                doc = leggi_risposta(percorso)
                if variante == "schema":
                    riga = riga_schema(percorso, doc, schema)
                else:
                    riga = riga_testo(percorso, doc, variante, etichette)
            except Mancante as exc:
                avviso(str(exc))
                mancanti += 1
                continue
            righe[(modello, variante)] = riga
    return righe, mancanti


def dati(modello: str, variante: str, riga: List[str]) -> str:
    """La riga dei dati di una risposta, con i nomi delle colonne di
    esiti.tsv."""
    _, forma, ammesse, oggetto, scelta = riga
    if variante == "con-etichette":
        return "%s, %s: forma_esempi %s, etichette_ammesse %s; scelta: %s" % (
            modello, variante, forma, ammesse, scelta)
    if variante == "schema":
        return "%s, %s: oggetto_schema %s; scelta: %s" % (
            modello, variante, oggetto, scelta)
    return "%s, %s: forma_esempi %s; scelta: %s" % (modello, variante,
                                                     forma, scelta)


def verdetti(modello: str, righe: Righe) -> Tuple[List[str], bool]:
    """I verdetti di un modello che le sue righe permettono di dare; True
    se la garanzia dello schema non è confermata o la sua chiamata è
    fallita."""
    uscita: List[str] = []
    zero = righe.get((modello, "zero-shot"))
    few = righe.get((modello, "few-shot"))
    if zero is not None and few is not None:
        if few[1] != "sì":
            esito = NON_CONFERMATA
        elif zero[1] == "sì":
            esito = GIA_SENZA
        else:
            esito = CONFERMATA
        uscita.append("%s (%s): %s" % (S_ESEMPI, modello, esito))
    lista = righe.get((modello, "con-etichette"))
    if lista is not None:
        esito = (CONFERMATA if lista[1] == "sì" and lista[2] == "sì"
                 else NON_CONFERMATA)
        uscita.append("%s (%s): %s" % (S_ELENCO, modello, esito))
    schema = righe.get((modello, "schema"))
    if schema is None:
        return uscita, False
    if schema[3] == "sì":
        uscita.append("%s (%s): %s" % (S_SCHEMA, modello, CONFERMATA))
        return uscita, False
    if schema[3] == "no":
        uscita += ["%s (%s): %s" % (S_SCHEMA, modello, NON_CONFERMATA),
                   GARANZIA]
    else:
        uscita.append("%s (%s): %s" % (S_SCHEMA, modello, FALLITA))
    return uscita, True


def stampa(righe: Righe) -> bool:
    """Per ogni modello i dati delle sue risposte, poi i suoi verdetti.
    Returns: True se la garanzia dello schema non tiene per un modello."""
    ko = False
    for modello in MODELLI:
        for variante in VARIANTI:
            riga = righe.get((modello, variante))
            if riga is not None:
                print(dati(modello, variante, riga))
        linee, sbagliato = verdetti(modello, righe)
        for linea in linee:
            print(linea)
        ko = ko or sbagliato
    return ko


def scrivi(righe: Righe) -> None:
    """esiti.tsv: l'intestazione e una riga per risposta che c'è, nell'ordine
    dei modelli e delle varianti."""
    testo = "\t".join(INTESTAZIONE) + "\n"
    for modello in MODELLI:
        for variante in VARIANTI:
            riga = righe.get((modello, variante))
            if riga is not None:
                testo += "\t".join(riga) + "\n"
    try:
        with open(ESITI, "w", encoding="utf-8", newline="\n") as fh:
            fh.write(testo)
    except OSError as exc:
        raise Precondizione("%s non si scrive (%s)" % (ESITI, exc))


def togli_vecchio() -> None:
    """Toglie l'esiti.tsv di un'esecuzione precedente: un controllo che
    non ha potuto girare non lascia esiti che sembrano suoi."""
    try:
        os.remove(ESITI)
    except FileNotFoundError:
        return  # non c'era: niente da togliere
    except OSError as exc:
        avviso("il vecchio %s resta (%s) e non vale per questa esecuzione"
               % (ESITI, exc.strerror or exc))


def controlla(solo_schema: bool, scrivi_esiti: bool) -> int:
    """Il controllo nella cartella corrente, lo spazio di lavoro: stampa,
    scrive esiti.tsv se scrivi_esiti, e restituisce l'uscita 0 o 1.
    Precondizione per l'uscita 2."""
    etichette = elenchi()
    schema = leggi_schema(etichette)
    if solo_schema:
        print("%s: gli enum sono uguali agli elenchi di %s."
              % (SCHEMA, PROMPT))
        return 0
    if not os.path.isdir(CARTELLA):
        print(PARTENZA)
        if scrivi_esiti:
            togli_vecchio()
        return 1
    righe, mancanti = leggi_righe(schema, etichette)
    ko = stampa(righe)
    if mancanti:
        print(NON_ANCORA)
    if scrivi_esiti:
        scrivi(righe)
        print("Scritto %s." % ESITI)
    return 1 if mancanti or ko else 0


def errore(messaggio: str) -> int:
    """Il messaggio su STDERR, in una riga; l'uscita 2."""
    avviso(messaggio)
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
    solo_schema = False
    scrivi_esiti = True
    posizionali: List[str] = []
    for arg in argv:
        if arg == "--solo-schema":
            solo_schema = True
        elif arg == "--senza-esiti":
            scrivi_esiti = False
        elif arg.startswith("-"):
            return uso("opzione sconosciuta: %s" % arg)
        else:
            posizionali.append(arg)
    if len(posizionali) > 1:
        return uso("uno spazio di lavoro per volta")
    if solo_schema:
        scrivi_esiti = False  # --solo-schema non scrive e non toglie niente
    ws = posizionali[0] if posizionali else "."
    if not os.path.isdir(ws):
        return errore("spazio di lavoro assente: %s" % ws)
    try:
        os.chdir(ws)
    except OSError as exc:
        return errore("lo spazio di lavoro %s non si apre (%s)"
                      % (ws, exc.strerror or exc))
    try:
        return controlla(solo_schema, scrivi_esiti)
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
