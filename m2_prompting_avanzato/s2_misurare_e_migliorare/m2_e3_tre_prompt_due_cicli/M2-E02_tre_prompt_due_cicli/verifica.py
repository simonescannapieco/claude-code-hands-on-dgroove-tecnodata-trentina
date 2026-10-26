#!/usr/bin/env python3
"""verifica.py di M2-E01 e M2-E02 -- il lavoro di un'esercitazione sui prompt.

Lo chiama verifica.sh, accanto; il file è lo stesso nei due elementi. Le
regole di misura (i controlli di controlli.tsv, le pratiche, le
affermazioni instabili, l'esito di una pratica) non sono copiate qui: le
carica da esercizio/strumenti/kit.py di questo elemento, lo stesso kit
dello spazio di lavoro, così la verifica e ./misura.sh --confronta danno
gli stessi esiti.

Le cartelle di prompt dello spazio di lavoro sono quelle che contengono
prompt/v0.md: la cartella stessa in M2-E01, le famiglie sviluppo, supporto
e sistemi in M2-E02. Una versione è «v» e un numero senza zeri davanti
(v0, v1, v2, ...), come la vuole misura.sh: un file di misura con un altro
nome (v2b, v01) non conta. Controlla il lavoro, non l'esito; per ciascuna
cartella:
  - v0 e almeno v1 misurate, e ogni versione misurata completa: la
    risposta (claude -p senza errori, con un testo e i conteggi di usage in
    numeri) e il giudizio strutturato con un esito per ogni affermazione di
    rubrica.md; v0 giudicata due volte (giudizi/v0.json e
    giudizi/v0-bis.json); un file di misura che manca o è rovinato chiede
    di misurare di nuovo quella versione. I controlli di controlli.tsv si
    rifanno sulla risposta, come in ./misura.sh --confronta:
    controlli/<v>.txt è da leggere, e nessun esito lo legge;
  - prompt/v1.md diverso da prompt/v0.md;
  - registro.md: la riga di ogni versione misurata, con la pratica (v0
    «partenza», le altre una dell'elenco di ./misura.sh --pratiche) e le
    colonne del cambiamento e delle misure compilate;
  - in M2-E02, almeno due famiglie con due cicli (v2).
Poi la garanzia del prodotto: ogni giudizio che porta structured_output lo
porta conforme a schema-giudizio.json (--json-schema). Stampa le misure e
l'esito della pratica di ogni versione dopo v0, confrontata con la
versione da cui parte, come ./misura.sh --confronta: confermata, non
confermata in questa misura o non decisa. Una pratica non confermata è un
risultato, mai un motivo per non passare. In M2-E01 stampa anche, come
dato e senza esito, se la risposta dell'ultima versione ripete il telefono
del cliente, con spazi, punti o trattini fra le cifre.

Uso:    verifica.py <spazio di lavoro>
Uscita: 0 il lavoro c'è e ogni giudizio strutturato rispetta lo schema ·
        1 qualcosa manca o è da misurare di nuovo, o un giudizio
        strutturato non rispetta lo schema (la documentazione lo garantisce)
        · 2 precondizione (spazio di lavoro assente o che non si legge, un
        file o una cartella che c'è ma non si legge, il kit dell'elemento
        che manca o non si carica); mai un traceback: un errore inatteso
        esce 2, con un messaggio di una riga
"""
from __future__ import annotations

import importlib.util
import json
import os
import re
import sys
from types import ModuleType
from typing import Any, Dict, List, NamedTuple, Optional, Tuple

FAMIGLIE = ("sviluppo", "supporto", "sistemi")
VERSIONE = re.compile(r"(v(?:0|[1-9][0-9]*))\.json")  # con fullmatch
TELEFONO = re.compile(r"000[ .-]?000[ .-]?0103")   # come in M2-D01
NUMERO = re.compile(r"[0-9]+")              # con fullmatch: cifre ASCII
# I conteggi di usage che legge strumenti/kit.py: devono essere numeri.
USAGE = ("input_tokens", "cache_creation_input_tokens",
         "cache_read_input_tokens", "output_tokens")
VUOTO = "…"
BIS = "-bis"
KIT = os.path.join("esercizio", "strumenti", "kit.py")
SCHEMA = "schema-giudizio.json"
COLONNE = ("che cosa ho cambiato", "controlli", "giudice")
GARANZIA = ("La documentazione garantisce un JSON convalidato secondo lo "
            "schema (--json-schema)")
FINE = ("Fatto: ogni affermazione è stata messa alla prova; gli esiti sono "
        "qui sopra.")


class Precondizione(Exception):
    """Un file o una cartella che c'è ma non si legge: uscita 2."""


class Misura(NamedTuple):
    """Una versione misurata e completa."""
    superati: int             # i controlli superati
    controlli: int            # quanti sono i controlli
    esiti: Dict[str, bool]    # il giudice, per ogni affermazione
    testo: str                # la risposta


def non_si_legge(percorso: str, exc: Exception) -> Precondizione:
    """La Precondizione di un percorso che c'è ma non si legge."""
    return Precondizione("%s non si legge (%s)" % (
        percorso, getattr(exc, "strerror", None) or exc))


def leggi_byte(percorso: str) -> Optional[bytes]:
    """I byte del file, None se non c'è; Precondizione se c'è ma non si
    legge (i permessi, una cartella al posto del file)."""
    try:
        with open(percorso, "rb") as fh:
            return fh.read()
    except FileNotFoundError:
        return None
    except OSError as exc:
        raise non_si_legge(percorso, exc)


def leggi(percorso: str) -> Optional[str]:
    """Il testo del file in UTF-8, None se non c'è; Precondizione se c'è
    ma non si legge."""
    dati = leggi_byte(percorso)
    try:
        return None if dati is None else dati.decode("utf-8")
    except UnicodeDecodeError as exc:
        raise non_si_legge(percorso, exc)


def ordine(versione: str) -> int:
    """La chiave d'ordine di v0, v1, v2, ...: il numero dopo la «v»."""
    m = re.fullmatch(r"v(0|[1-9][0-9]*)", versione)
    return int(m.group(1)) if m else -1


def misurate(cartella: str) -> List[str]:
    """Le versioni con una risposta in risposte/, in ordine; Precondizione
    se risposte/ c'è ma non si legge."""
    base = os.path.join(cartella, "risposte")
    try:
        nomi = os.listdir(base)
    except FileNotFoundError:
        return []
    except OSError as exc:
        raise non_si_legge(base, exc)
    trovate = [m.group(1) for m in map(VERSIONE.fullmatch, nomi) if m]
    return sorted(trovate, key=ordine)


def carica_kit() -> ModuleType:
    """kit.py di questo elemento, accanto a verifica.py; Precondizione se
    manca o non si carica."""
    percorso = os.path.join(os.path.dirname(os.path.abspath(__file__)), KIT)
    if not os.path.isfile(percorso):
        raise Precondizione("manca %s" % percorso)
    try:
        spec = importlib.util.spec_from_file_location("kit_m2", percorso)
        if spec is None or spec.loader is None:
            raise ImportError("nessun caricatore")
        modulo = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(modulo)  # type: ignore[union-attr]
    except (ImportError, OSError, SyntaxError) as exc:
        raise Precondizione("%s non si carica (%s)" % (percorso, exc))
    return modulo


def json_claude(nome: str) -> Tuple[Optional[dict], str]:
    """(il JSON di claude -p, "") o (None, il problema); nome è il file,
    relativo allo spazio di lavoro."""
    dati = leggi_byte(nome)
    if dati is None:
        return None, "manca %s" % nome
    try:
        doc = json.loads(dati.decode("utf-8"))
    except (ValueError, RecursionError):
        return None, "%s non è un JSON valido" % nome
    if not isinstance(doc, dict) or doc.get("type") != "result":
        return None, "%s non è il JSON di claude -p" % nome
    if doc.get("is_error"):
        return None, "%s contiene un errore di Claude Code" % nome
    return doc, ""


def usage_numerico(doc: dict) -> bool:
    """Vero se i conteggi di usage sono numeri interi, come li vuole
    strumenti/kit.py per il confronto."""
    uso = doc.get("usage") or {}
    if not isinstance(uso, dict):
        return False
    for chiave in USAGE:
        valore = uso.get(chiave)
        if valore is None or (isinstance(valore, int)
                              and not isinstance(valore, bool)):
            continue
        if not (isinstance(valore, str) and NUMERO.fullmatch(valore)):
            return False
    return True


def di_tipo(valore: Any, tipo: Any) -> bool:
    """Vero se il valore è del tipo JSON Schema (o di uno dei tipi)."""
    controlli = {"object": lambda v: isinstance(v, dict),
                 "array": lambda v: isinstance(v, list),
                 "string": lambda v: isinstance(v, str),
                 "boolean": lambda v: isinstance(v, bool),
                 "integer": lambda v: isinstance(v, int)
                 and not isinstance(v, bool),
                 "number": lambda v: isinstance(v, (int, float))
                 and not isinstance(v, bool),
                 "null": lambda v: v is None}
    tipi = tipo if isinstance(tipo, list) else [tipo]
    return any(controlli.get(str(t), lambda v: False)(valore) for t in tipi)


def conforme(valore: Any, schema: Any, dove: str = "") -> str:
    """La prima violazione del valore rispetto allo schema, "" se è
    conforme. Legge la parte di JSON Schema che usa schema-giudizio.json:
    type, enum, properties, required, additionalProperties, items."""
    qui = dove or "structured_output"
    if not isinstance(schema, dict):
        return ""
    if "type" in schema and not di_tipo(valore, schema["type"]):
        return "%s: atteso %s" % (qui, schema["type"])
    if "enum" in schema and valore not in schema["enum"]:
        return "%s: un valore fuori elenco" % qui
    if isinstance(valore, dict):
        proprieta = schema.get("properties") or {}
        for chiave in schema.get("required") or []:
            if chiave not in valore:
                return "%s: manca «%s»" % (qui, chiave)
        if schema.get("additionalProperties") is False:
            for chiave in valore:
                if chiave not in proprieta:
                    return "%s: il campo «%s» non è nello schema" % (
                        qui, chiave)
        for chiave, sotto in proprieta.items():
            if chiave in valore:
                problema = conforme(valore[chiave], sotto, qui + "." + chiave)
                if problema:
                    return problema
    if isinstance(valore, list) and isinstance(schema.get("items"), dict):
        for n, elemento in enumerate(valore):
            problema = conforme(elemento, schema["items"], "%s[%d]" % (qui, n))
            if problema:
                return problema
    return ""


def leggi_schema(problemi: List[str]) -> Optional[dict]:
    """Lo schema del giudice dello spazio di lavoro, None (con il
    problema) se manca o non è un oggetto JSON."""
    testo = leggi(SCHEMA)
    if testo is None:
        problemi.append("manca %s: senza lo schema la garanzia dei giudizi "
                        "strutturati non si mette alla prova (rimettetelo "
                        "com'era nel punto di partenza)" % SCHEMA)
        return None
    try:
        schema = json.loads(testo)
    except (ValueError, RecursionError):
        schema = None
    if not isinstance(schema, dict):
        problemi.append("%s non è uno schema JSON: rimettetelo com'era nel "
                        "punto di partenza" % SCHEMA)
        return None
    return schema


def da_rifare(famiglia: Optional[str], versione: str) -> str:
    """La coda di un messaggio che chiede di misurare di nuovo."""
    return ": misurate di nuovo %s (./misura.sh%s %s)" % (
        versione, " " + famiglia if famiglia else "", versione)


def giudizio(kit: ModuleType, cartella: str, famiglia: Optional[str],
             versione: str, suffisso: str, schema: Optional[dict],
             problemi: List[str],
             garanzia: List[Tuple[str, str]]) -> Optional[Dict[str, bool]]:
    """{id: rispettato} di giudizi/<v><suffisso>.json, completo, o None
    con il problema; ogni structured_output passa la prova dello schema."""
    nome = os.path.normpath(os.path.join(cartella, "giudizi",
                                         versione + suffisso + ".json"))
    doc, problema = json_claude(nome)
    if doc is None:
        problemi.append(problema + da_rifare(famiglia, versione))
        return None
    uscita = doc.get("structured_output")
    if uscita is None:
        problemi.append("%s non ha structured_output: il giudizio non è "
                        "arrivato%s" % (nome, da_rifare(famiglia, versione)))
        return None
    if schema is not None:
        garanzia.append((nome, conforme(uscita, schema)))
        if garanzia[-1][1]:
            return None
    criteri = uscita.get("criteri") if isinstance(uscita, dict) else None
    esiti: Dict[str, bool] = {}
    for voce in criteri if isinstance(criteri, list) else []:
        if isinstance(voce, dict) and isinstance(voce.get("rispettato"), bool):
            esiti.setdefault(str(voce.get("id")), voce["rispettato"])
    attesi = [i for i, _, _ in kit.rubrica(cartella)]
    mancanti = [i for i in attesi if i not in esiti]
    if mancanti:
        problemi.append("%s non valuta: %s%s" % (
            nome, ", ".join(mancanti), da_rifare(famiglia, versione)))
        return None
    return {i: esiti[i] for i in attesi}


def misura(kit: ModuleType, cartella: str, famiglia: Optional[str],
           versione: str, schema: Optional[dict], problemi: List[str],
           garanzia: List[Tuple[str, str]]) -> Optional[Misura]:
    """La misura completa di una versione, o None con il problema: un file
    di misura che manca o è rovinato chiede di misurare di nuovo. I
    controlli si rifanno sulla risposta, con controlli.tsv (il kit), mai
    letti da controlli/<v>.txt."""
    dove = " in %s" % famiglia if famiglia else ""
    nome = os.path.normpath(os.path.join(cartella, "risposte",
                                         versione + ".json"))
    doc, problema = json_claude(nome)
    if doc is None:
        problemi.append(problema + da_rifare(famiglia, versione))
        return None
    testo = doc.get("result")
    if not isinstance(testo, str) or not testo.strip():
        problemi.append("la risposta di %s%s è vuota%s" % (
            versione, dove, da_rifare(famiglia, versione)))
        return None
    if not usage_numerico(doc):
        problemi.append("%s ha un usage non numerico%s" % (
            nome, da_rifare(famiglia, versione)))
        return None
    controlli = kit.esiti_controlli(cartella, versione)
    esiti = giudizio(kit, cartella, famiglia, versione, "", schema, problemi,
                     garanzia)
    if esiti is None:
        return None
    return Misura(sum(controlli.values()), len(controlli), esiti, testo)


def controlla_registro(kit: ModuleType, cartella: str,
                       famiglia: Optional[str], versioni: List[str],
                       problemi: List[str]) -> None:
    """La riga di ogni versione misurata: compilata, con una pratica
    valida."""
    for v in versioni:
        campi, problema = kit.riga_registro(cartella, v)
        if campi is None:
            problemi.append(problema)
            continue
        if any(not campi.get(c) or VUOTO in campi.get(c, "")
               or campi.get(c) == "..." for c in COLONNE):
            problemi.append("registro.md: compilate la riga di %s%s" % (
                v, " di " + famiglia if famiglia else ""))
        pratica, problema = kit.pratica_di(cartella, v)
        if pratica is None:
            problemi.append(problema)


def impronta(kit: ModuleType, cartella: str, versione: str) -> Optional[str]:
    """L'impronta del prompt di una versione: quella registrata alla misura,
    altrimenti quella del file attuale."""
    return (kit.opzioni_di(cartella, versione).get("prompt")
            or kit.impronta_prompt(cartella, versione))


def base_di(kit: ModuleType, cartella: str, versioni: List[str],
            i: int) -> str:
    """La versione da cui parte versioni[i]: la precedente; per una pratica
    a testo invariato (effort, modello, rimisura), la più recente con lo
    stesso prompt."""
    pratica, _ = kit.pratica_di(cartella, versioni[i])
    if pratica in kit.STESSO_TESTO:
        testo = impronta(kit, cartella, versioni[i])
        for v in reversed(versioni[:i]):
            if testo is not None and impronta(kit, cartella, v) == testo:
                return v
    return versioni[i - 1]


def stampa_misure(kit: ModuleType, nome: str, versioni: List[str],
                  misure: Dict[str, Misura], instab: List[str]) -> None:
    """Le misure lette: controlli e giudice di ogni versione; per v0 le
    affermazioni rispettate tutte e due le volte, e le instabili."""
    print("%s, versioni misurate: %s" % (nome[:1].upper() + nome[1:],
                                          ", ".join(versioni)))
    for v in versioni:
        m = misure[v]
        rispettate = sum(1 for i, ok in m.esiti.items()
                         if ok and not (v == "v0" and i in instab))
        riga = "%s: controlli %d/%d, giudice %d/%d" % (
            v, m.superati, m.controlli, rispettate, len(m.esiti))
        if v == "v0":
            riga += "; due giudizi, stesso esito su %d di %d, instabili: " \
                "%s" % (len(m.esiti) - len(instab), len(m.esiti),
                        ", ".join(instab) or "nessuna")
        kit.avvolgi(riga, "  ", "    ")


def stampa_esiti(kit: ModuleType, cartella: str, versioni: List[str],
                 instab: List[str]) -> None:
    """L'esito della pratica di ogni versione dopo v0, come lo dice
    ./misura.sh --confronta."""
    for i in range(1, len(versioni)):
        base = base_di(kit, cartella, versioni, i)
        pratica, esito, perche = kit.esito_pratica(cartella, base,
                                                   versioni[i], instab)
        kit.avvolgi("%s rispetto a %s, %s: %s (%s)" % (
            versioni[i], base, pratica or "pratica non indicata", esito,
            perche), "  ", "    ")


def stampa_telefono(kit: ModuleType, versione: str, testo: str) -> None:
    """M2-E01: se la risposta dell'ultima versione ripete il telefono del
    cliente, un dato stampato e senza esito: nessuna frase di Anthropic lo
    decide, e «nessuna volta» è una soglia, non un'affermazione."""
    riga = "Il telefono del cliente nella risposta di %s: " % versione
    if not TELEFONO.search(leggi(os.path.join("dati", "messaggio.md")) or ""):
        kit.avvolgi(riga + "non cercato (il messaggio non è quello di "
                    "CiaspoLink: il telefono lo cerca controlli.tsv)", "",
                    "  ")
    elif TELEFONO.search(testo):
        print(riga + "presente (la risposta lo ripete)")
    else:
        print(riga + "assente")


def esamina_cartella(kit: ModuleType, cartella: str, famiglia: Optional[str],
                     schema: Optional[dict], problemi: List[str],
                     garanzia: List[Tuple[str, str]]) -> None:
    """Il lavoro di una cartella di prompt; i problemi in problemi."""
    nome = famiglia or "lo spazio di lavoro"
    for f in ("rubrica.md", "controlli.tsv"):
        leggi(os.path.join(cartella, f))   # Precondizione se non si legge
    versioni = misurate(cartella)
    da_misurare = [v for v in ("v0", "v1") if v not in versioni]
    if da_misurare:
        problemi.append("%s: misurate %s; servono almeno v0 e v1 "
                        "(./misura.sh%s %s)" % (
                            nome, ", ".join(versioni) or "nessuna versione",
                            " " + famiglia if famiglia else "",
                            ", poi ".join(da_misurare)))
        return
    if leggi(os.path.join(cartella, "prompt", "v1.md")) == leggi(
            os.path.join(cartella, "prompt", "v0.md")):
        problemi.append("%s: prompt/v1.md è uguale a prompt/v0.md" % nome)
        return
    misure: Dict[str, Misura] = {}
    for v in versioni:
        m = misura(kit, cartella, famiglia, v, schema, problemi, garanzia)
        if m is not None:
            misure[v] = m
    bis = giudizio(kit, cartella, famiglia, "v0", BIS, schema, problemi,
                   garanzia)
    controlla_registro(kit, cartella, famiglia, versioni, problemi)
    if bis is None or len(misure) < len(versioni):
        return
    instab = [i for i, ok in misure["v0"].esiti.items() if bis[i] != ok]
    stampa_misure(kit, nome, versioni, misure, instab)
    stampa_esiti(kit, cartella, versioni, instab)
    if famiglia is None:
        stampa_telefono(kit, versioni[-1], misure[versioni[-1]].testo)


def esamina(kit: ModuleType, problemi: List[str],
            garanzia: List[Tuple[str, str]]) -> None:
    """Le regole di M2-E01 (prompt/v0.md nello spazio di lavoro) o di
    M2-E02 (le tre famiglie); i problemi in problemi. Lo spazio di lavoro
    è la cartella corrente."""
    leggi("registro.md")   # Precondizione se c'è ma non si legge
    schema = leggi_schema(problemi)
    if os.path.exists(os.path.join("prompt", "v0.md")):
        prova(kit, ".", None, schema, problemi, garanzia)
        return
    con_v2 = 0
    for famiglia in FAMIGLIE:
        if not os.path.isdir(famiglia):
            problemi.append("manca la cartella %s" % famiglia)
            continue
        prova(kit, famiglia, famiglia, schema, problemi, garanzia)
        con_v2 += "v2" in misurate(famiglia)
    print("Famiglie con due cicli (v2): %d su tre." % con_v2)
    if con_v2 < 2:
        problemi.append("famiglie con due cicli (v2): %d su tre; ne servono "
                        "almeno due" % con_v2)


def prova(kit: ModuleType, cartella: str, famiglia: Optional[str],
          schema: Optional[dict], problemi: List[str],
          garanzia: List[Tuple[str, str]]) -> None:
    """esamina_cartella, con un formato rifiutato dal kit (una pratica che
    non c'è, un id ripetuto) tra i problemi: è un lavoro da correggere."""
    try:
        esamina_cartella(kit, cartella, famiglia, schema, problemi, garanzia)
    except kit.Errore as exc:
        problemi.append(str(exc))


def stampa_garanzia(kit: ModuleType, garanzia: List[Tuple[str, str]]) -> bool:
    """La riga della garanzia dei giudizi strutturati; falso se un giudizio
    non rispetta lo schema."""
    falliti = ["%s: %s" % (n, p) for n, p in garanzia if p]
    if falliti:
        kit.avvolgi("%s: in questa esecuzione no (%s)" % (
            GARANZIA, "; ".join(falliti)), "", "  ")
        return False
    if garanzia:
        print("Ogni giudizio strutturato è conforme a %s (--json-schema), %d "
              "su %d: confermata" % (SCHEMA, len(garanzia), len(garanzia)))
    else:
        print("Giudizi strutturati conformi a %s: non decisa (nessun giudizio "
              "da leggere)" % SCHEMA)
    return True


def main(argv: List[str]) -> int:
    if len(argv) != 1 or not os.path.isdir(argv[0]):
        sys.stderr.write("verifica: spazio di lavoro assente: %s\n"
                         % (argv[0] if argv else ""))
        return 2
    if not os.access(argv[0], os.R_OK | os.X_OK):
        sys.stderr.write("verifica: lo spazio di lavoro %s non si legge\n"
                         % argv[0])
        return 2
    problemi: List[str] = []
    garanzia: List[Tuple[str, str]] = []
    try:
        kit = carica_kit()      # prima di cambiare cartella: __file__
        os.chdir(argv[0])
        esamina(kit, problemi, garanzia)
        garantita = stampa_garanzia(kit, garanzia)
    except Precondizione as exc:
        sys.stderr.write("verifica: %s\n" % exc)
        return 2
    except Exception as exc:  # l'ultima rete: un messaggio, mai un traceback
        sys.stderr.write("verifica: errore inatteso (%s: %s)\n" % (
            type(exc).__name__, " ".join(str(exc).split())))
        return 2
    if problemi or not garantita:
        for p in problemi:
            print("Non ancora: %s." % p)
        return 1
    print(FINE)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
