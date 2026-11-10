#!/usr/bin/env python3
"""verifica.py di M8-E02 -- il lavoro di «Metà dei token, a parità di qualità».

Lo chiama verifica.sh, accanto. Le regole di misura (i controlli, i token, il
costo ricalcolato, il giudizio) non sono copiate qui: le carica da
esercizio/strumenti/kit.py di questo elemento, lo stesso kit dello spazio di
lavoro, così la verifica e ./misura.sh --confronta dicono le stesse cose. Il
controllo legge le esecuzioni dello spazio di lavoro, mai un file di esiti:
i controlli li rifà sulla risposta di ogni caso.

Che cosa controlla:
  - i file che definiscono la misura, nello spazio di lavoro, uguali a quelli
    del punto di partenza: prompt/v0.md, documenti/, i casi con i loro
    controlli e le loro rubriche, listino.json, lo schema del giudizio e il
    giudice. I criteri e il punto di partenza restano fermi, così le versioni
    si confrontano;
  - ogni versione misurata completa: per ogni caso la risposta (claude -p
    senza errori, un testo, i conteggi di usage in numeri) e il giudizio
    strutturato con un esito per ogni affermazione della rubrica; v0 misurata;
    almeno una versione dopo v0, diversa da v0 e misurata con lo stesso
    modello e lo stesso effort di v0 (una versione misurata con un altro
    modello non si confronta), con il testo del prompt uguale a quello
    misurato;
  - che ogni misura sia quella dei file di adesso (l'impronta dei prompt
    composti, documenti e dati compresi) e che ogni giudizio dia un esito per
    ogni affermazione della rubrica;
  - che almeno una versione dopo v0 pesi meno token in entrata di v0 e non
    sia peggiore: né i controlli superati né le affermazioni rispettate sono
    scesi rispetto a v0, sul totale dei tre casi.
Poi la garanzia del prodotto: ogni giudizio che porta structured_output lo
porta conforme allo schema del giudice (--json-schema).

Stampa, come dati: le misure di ogni versione, la riduzione dei token in
entrata e la riga dell'obiettivo del laboratorio (almeno il 50 % in meno:
una soglia del laboratorio, mai un esito né un'uscita). Stampa poi le due
frasi di Anthropic da cui parte il laboratorio, senza un esito: il prompt è
costruito per il corso, e una coppia di misure su un prompt costruito è una
dimostrazione, che non decide una frase sugli agenti in generale, né una che
dice «rarely».

Uso:    verifica.py <spazio di lavoro>
Uscita: 0 almeno una versione dopo v0 misurata, più leggera e non peggiore di v0, e ogni
        giudizio strutturato rispetta lo schema · 1 non ancora: qualcosa manca
        o è da misurare di nuovo, nessuna versione è non peggiore di v0, un
        file del punto di partenza è cambiato, o un giudizio strutturato non
        rispetta lo schema · 2 precondizione (spazio di lavoro assente o che
        non si legge, un file che c'è ma non si legge, il kit dell'elemento che
        manca o non si carica); mai un traceback: un errore inatteso esce 2,
        con un messaggio di una riga
"""
from __future__ import annotations

import importlib.util
import json
import os
import re
import sys
from types import ModuleType
from typing import Any, List, NamedTuple, Optional, Tuple

ESERCIZIO = "esercizio"
KIT = os.path.join(ESERCIZIO, "strumenti", "kit.py")
DIMOSTRAZIONE = ("una dimostrazione su un prompt costruito per il corso: "
                 "stampa i dati della coppia e non decide le due frasi")
FRASI = (
    "Most agent requests carry tokens that never influence the answer.",
    "Trimming them rarely costs output quality, although not every lever "
    "here saved money when measured.")
FONTE = ("https://platform.claude.com/docs/en/about-claude/models/"
         "optimizing-for-cost-and-intelligence")
GARANZIA = ("La documentazione garantisce un JSON convalidato secondo lo "
            "schema (--json-schema)")
# Il punto di partenza, nello spazio di lavoro: deve restare com'era.
FERMI = (os.path.join("prompt", "v0.md"), "listino.json",
         "schema-giudizio.json", os.path.join(".claude", "agents",
                                              "giudice.md"))
FINE = ("Fatto: almeno una versione dopo v0 è misurata sui tre casi, pesa "
        "meno token in entrata e non è "
        "peggiore di v0; gli esiti sono qui sopra.")


class Precondizione(Exception):
    """Un file o una cartella che c'è ma non si legge: uscita 2."""


def non_si_legge(percorso: str, exc: Exception) -> Precondizione:
    """La Precondizione di un percorso che c'è ma non si legge."""
    return Precondizione("%s non si legge (%s)" % (
        percorso, getattr(exc, "strerror", None) or exc))


def leggi_byte(percorso: str) -> Optional[bytes]:
    """I byte del file, None se non c'è; Precondizione se c'è ma non si
    legge."""
    try:
        with open(percorso, "rb") as fh:
            return fh.read()
    except FileNotFoundError:
        return None
    except OSError as exc:
        raise non_si_legge(percorso, exc)


def carica_kit() -> ModuleType:
    """kit.py di questo elemento, accanto a verifica.py; Precondizione se
    manca o non si carica."""
    percorso = os.path.join(os.path.dirname(os.path.abspath(__file__)), KIT)
    if not os.path.isfile(percorso):
        raise Precondizione("manca %s" % percorso)
    try:
        spec = importlib.util.spec_from_file_location("kit_m8_e02", percorso)
        if spec is None or spec.loader is None:
            raise ImportError("nessun caricatore")
        modulo = importlib.util.module_from_spec(spec)
        sys.modules["kit_m8_e02"] = modulo
        spec.loader.exec_module(modulo)  # type: ignore[union-attr]
    except (ImportError, OSError, SyntaxError) as exc:
        raise Precondizione("%s non si carica (%s)" % (percorso, exc))
    return modulo


def file_del_punto_di_partenza(kit: ModuleType) -> List[str]:
    """I percorsi, relativi allo spazio di lavoro, dei file che definiscono
    la misura: prompt/v0.md, i documenti, i casi, il listino, lo schema e il
    giudice. (La cartella degli esercizi dell'elemento è il riferimento.)"""
    percorsi = list(FERMI)
    for nome in ("tono.md", "procedure.md"):
        percorsi.append(os.path.join("documenti", nome))
    for caso in kit.CASI:
        for nome in ("messaggio.md", "stato.md", "controlli.tsv",
                     "rubrica.md"):
            percorsi.append(os.path.join("casi", caso, nome))
    return percorsi


def integrita(kit: ModuleType, elemento: str, problemi: List[str]) -> None:
    """Ogni file del punto di partenza, nello spazio di lavoro, uguale a
    quello dell'elemento."""
    for percorso in file_del_punto_di_partenza(kit):
        riferimento = leggi_byte(os.path.join(elemento, ESERCIZIO, percorso))
        if riferimento is None:
            raise Precondizione("nell'elemento manca %s" % percorso)
        copia = leggi_byte(percorso)
        if copia is None:
            problemi.append("manca %s: rimettetelo com'era (git checkout -- "
                            "%s) e misurate di nuovo" % (percorso, percorso))
        elif copia != riferimento:
            problemi.append("%s è cambiato: il punto di partenza e i criteri "
                            "restano fermi; rimettetelo com'era (git checkout "
                            "-- %s) e misurate di nuovo" % (percorso, percorso))


def misurate(kit: ModuleType) -> List[str]:
    """Le versioni con una cartella in risposte/, in ordine; Precondizione
    se risposte/ c'è ma non si legge."""
    try:
        nomi = os.listdir(kit.RISPOSTE)
    except FileNotFoundError:
        return []
    except OSError as exc:
        raise non_si_legge(kit.RISPOSTE, exc)
    return sorted((n for n in nomi if kit.VERSIONE.fullmatch(n)
                   and os.path.isdir(os.path.join(kit.RISPOSTE, n))),
                  key=lambda n: int(n[1:]))


def leggibile(percorso: str) -> None:
    """Precondizione se il file c'è ma non si legge."""
    if os.path.exists(percorso) and not os.access(percorso, os.R_OK):
        raise Precondizione("%s non si legge" % percorso)


def controlla_leggibili(kit: ModuleType, versione: str) -> None:
    """I file di misura di una versione che ci sono devono potersi leggere."""
    for caso in kit.CASI:
        leggibile(kit.percorso_risposta(caso, versione))
        leggibile(kit.percorso_giudizio(caso, versione))
    leggibile(os.path.join(kit.RISPOSTE, versione, "opzioni.tsv"))


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
    conforme. Legge la parte di JSON Schema che usa lo schema del giudice:
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


def leggi_schema(elemento: str) -> dict:
    """Lo schema del giudice dell'elemento; Precondizione se manca o non è
    un oggetto JSON."""
    percorso = os.path.join(elemento, ESERCIZIO, "schema-giudizio.json")
    dati = leggi_byte(percorso)
    if dati is None:
        raise Precondizione("manca %s" % percorso)
    try:
        schema = json.loads(dati.decode("utf-8"))
    except (ValueError, RecursionError) as exc:
        raise Precondizione("%s non è un JSON valido (%s)" % (percorso, exc))
    if not isinstance(schema, dict):
        raise Precondizione("%s non è uno schema JSON" % percorso)
    return schema


def giudizi_conformi(kit: ModuleType, versioni: List[str], schema: dict,
                     garanzia: List[Tuple[str, str]]) -> None:
    """Per ogni giudizio che si legge e porta structured_output, l'esito
    della prova dello schema: (percorso, problema o "")."""
    for versione in versioni:
        for caso in kit.CASI:
            nome = kit.percorso_giudizio(caso, versione)
            if not os.path.isfile(nome):
                continue
            try:
                doc = kit.json_di_claude(nome)
            except kit.Errore:
                continue   # un file rotto lo segnala la misura della versione
            uscita = doc.get("structured_output")
            if uscita is not None:
                garanzia.append((nome, conforme(uscita, schema)))


def misura_o_problema(kit: ModuleType, versione: str,
                      problemi: List[str]) -> Optional[Any]:
    """La misura completa di una versione, o None con il problema."""
    controlla_leggibili(kit, versione)
    opzioni = kit.opzioni_di(versione)
    if opzioni and opzioni.get("composti") != kit.impronta_composti(versione):
        problemi.append("i file di %s (il prompt, i documenti o i casi) non "
                        "sono quelli misurati: misurate di nuovo %s "
                        "(./misura.sh %s)" % (versione, versione, versione))
        return None
    try:
        misura = kit.misura_versione(versione)
        for caso in kit.CASI:
            mancanti = [i for i, (ok, _) in kit.esiti_giudice(caso, versione)
                        .items() if ok is None]
            if mancanti:
                problemi.append("il giudizio di %s, %s non dà un esito per "
                                "%s: misurate di nuovo %s" % (
                                    versione, caso, ", ".join(mancanti),
                                    versione))
                return None
        return misura
    except kit.Errore as exc:
        problemi.append(str(exc))
        return None


class Confronto(NamedTuple):
    """Una versione dopo v0, confrontata con v0."""
    misura: Any
    motivo: str          # "" se si confronta, altrimenti perché no
    riduzione: float     # percento dei token in entrata
    meno_token: bool
    peggio_controlli: bool
    peggio_giudice: bool


def modelli_risposte(kit: ModuleType, versione: str) -> List[str]:
    """I modelli che hanno scritto le risposte di una versione, letti dal
    campo modelUsage dei JSON: quelli delle esecuzioni, non delle opzioni."""
    trovati: set = set()
    for caso in kit.CASI:
        trovati.update(kit.modelli_di(kit.json_di_claude(
            kit.percorso_risposta(caso, versione))))
    return sorted(trovati)


def motivo_non_confrontabile(kit: ModuleType, m0: Any, m: Any) -> str:
    """Perché una versione non si confronta con v0, "" se si confronta: lo
    stesso modello e lo stesso effort, nelle opzioni e nei JSON delle
    risposte, il prompt diverso da v0 e uguale a quello misurato."""
    modelli0, modelli = modelli_risposte(kit, "v0"), modelli_risposte(
        kit, m.versione)
    if len(modelli0) != 1 or modelli0 != modelli \
            or m0.modello not in modelli0[0]:
        return ("le risposte di v0 vengono da %s, quelle di %s da %s: "
                "misuratele con lo stesso modello" % (
                    ", ".join(modelli0) or "nessun modello", m.versione,
                    ", ".join(modelli) or "nessun modello"))
    if (m.modello, m.effort) != (m0.modello, m0.effort):
        return ("%s è misurata con %s e effort %s, v0 con %s e effort %s: "
                "misuratela con il modello e l'effort di v0" % (
                    m.versione, m.modello, m.effort, m0.modello, m0.effort))
    if kit.opzioni_di(m.versione).get("dati") != kit.opzioni_di("v0").get(
            "dati"):
        return ("i casi sono cambiati fra v0 e %s: rimisurate entrambe"
                % m.versione)
    testo_v = kit.impronta_prompt(m.versione)
    if testo_v is None:
        return "manca prompt/%s.md: misurate di nuovo %s" % (m.versione,
                                                               m.versione)
    if testo_v == kit.impronta_prompt("v0"):
        return "prompt/%s.md è uguale a prompt/v0.md" % m.versione
    if kit.opzioni_di(m.versione).get("prompt") != testo_v:
        return ("prompt/%s.md è cambiato dopo la misura: misurate di nuovo "
                "%s (./misura.sh %s)" % (m.versione, m.versione, m.versione))
    return ""


def confronta_con_v0(kit: ModuleType, m0: Any, m: Any) -> Confronto:
    """Il confronto di una versione con v0, sui totali dei tre casi."""
    return Confronto(
        m, motivo_non_confrontabile(kit, m0, m),
        kit.percento(m0.somma("entrata"), m.somma("entrata")),
        m.somma("entrata") < m0.somma("entrata"),
        m.somma("controlli_ok") < m0.somma("controlli_ok"),
        m.somma("giudice_ok") < m0.somma("giudice_ok"))


def peggiorati(c: Confronto) -> List[str]:
    """Che cosa è peggiorato, in parole."""
    voci = []
    if c.peggio_controlli:
        voci.append("controlli superati %d/%d" % (
            c.misura.somma("controlli_ok"), c.misura.somma("controlli_n")))
    if c.peggio_giudice:
        voci.append("affermazioni rispettate %d/%d" % (
            c.misura.somma("giudice_ok"), c.misura.somma("giudice_n")))
    return voci


def stampa_misure(kit: ModuleType, m0: Any, confronti: List[Confronto]) -> None:
    """Le misure di ogni versione, come dati."""
    versioni = [m0] + [c.misura for c in confronti]
    print("Versioni misurate: %s" % ", ".join(m.versione for m in versioni))
    for m in versioni:
        kit.avvolgi("%s (%s, effort %s): token in entrata %d, token in uscita "
                    "%d, costo ricalcolato %s, controlli %d/%d, giudice "
                    "%d/%d" % (m.versione, m.modello, m.effort,
                               m.somma("entrata"), m.somma("uscita"),
                               kit.dollari(m.somma("costo")),
                               m.somma("controlli_ok"), m.somma("controlli_n"),
                               m.somma("giudice_ok"), m.somma("giudice_n")),
                    "  ", "    ")


def stampa_confronto(kit: ModuleType, m0: Any, c: Confronto) -> None:
    """La riduzione e l'obiettivo del laboratorio (un dato), poi gli esiti
    delle frasi di Anthropic per questa coppia."""
    print("Confronto %s → %s, sui tre casi:" % ("v0", c.misura.versione))
    for riga in kit.righe_riduzione("v0", c.misura.versione, c.riduzione):
        print("  %s" % riga)
    print("  (una soglia del laboratorio, non una frase di Anthropic: "
          "non decide l'uscita)")
    print("  costo ricalcolato: %s → %s (un dato)" % (
        kit.dollari(m0.somma("costo")), kit.dollari(c.misura.somma("costo"))))
    kit.avvolgi("(dato) token in entrata scesi: %s; controlli e giudice "
                "non peggiori: %s" % (
                    "sì" if c.meno_token else "no",
                    "no" if c.peggio_controlli or c.peggio_giudice else "sì"),
                "  ", "    ")
    if c.motivo:
        kit.avvolgi("(la coppia non si confronta: %s)" % c.motivo, "  ",
                    "    ")
    for frase in FRASI:
        kit.avvolgi("«%s»" % frase, "  ", "    ")
    kit.avvolgi("(%s, letta il 2026-11-10; %s)" % (FONTE, DIMOSTRAZIONE),
                "  ", "    ")


def non_peggiore(c: Confronto) -> bool:
    """Vero se la versione si confronta con v0, pesa meno token in entrata
    e né i controlli né il giudice sono peggiori."""
    return (not c.motivo and c.meno_token and not c.peggio_controlli
            and not c.peggio_giudice)


def problemi_senza_versione_buona(confronti: List[Confronto],
                                  problemi: List[str]) -> None:
    """Se nessuna versione è non peggiore di v0, che cosa manca, versione
    per versione."""
    for c in confronti:
        nome = c.misura.versione
        if c.motivo:
            problemi.append(c.motivo)
        elif c.peggio_controlli or c.peggio_giudice:
            problemi.append("%s è peggiore di v0: %s" % (
                nome, ", ".join(peggiorati(c))))
        elif not c.meno_token:
            problemi.append("%s non pesa meno token in entrata di v0: "
                            "tagliate ancora e misuratela" % nome)


def esamina(kit: ModuleType, elemento: str, problemi: List[str],
            garanzia: List[Tuple[str, str]]) -> None:
    """Il lavoro nello spazio di lavoro: stampa le misure e gli esiti; i
    problemi in problemi. La cartella corrente è lo spazio di lavoro."""
    integrita(kit, elemento, problemi)
    versioni = misurate(kit)
    giudizi_conformi(kit, versioni, leggi_schema(elemento), garanzia)
    if "v0" not in versioni:
        problemi.append("v0 non è misurata (./misura.sh v0)")
        return
    m0 = misura_o_problema(kit, "v0", problemi)
    dopo = [v for v in versioni if v != "v0"]
    if not dopo:
        problemi.append("serve almeno una versione dopo v0 misurata sui tre "
                        "casi (./misura.sh v1)")
        return
    if m0 is None:
        return
    confronti: List[Confronto] = []
    for v in dopo:
        m = misura_o_problema(kit, v, problemi)
        if m is not None:
            confronti.append(confronta_con_v0(kit, m0, m))
    if not confronti:
        return
    stampa_misure(kit, m0, confronti)
    for c in confronti:
        stampa_confronto(kit, m0, c)
    if not any(non_peggiore(c) for c in confronti):
        problemi_senza_versione_buona(confronti, problemi)


def stampa_garanzia(kit: ModuleType, garanzia: List[Tuple[str, str]]) -> bool:
    """La riga della garanzia dei giudizi strutturati; falso se un giudizio
    non rispetta lo schema."""
    falliti = ["%s: %s" % (n, p) for n, p in garanzia if p]
    if falliti:
        kit.avvolgi("%s: in questa esecuzione no (%s)" % (
            GARANZIA, "; ".join(falliti)), "", "  ")
        return False
    if garanzia:
        print("Ogni giudizio strutturato è conforme allo schema "
              "(--json-schema), %d su %d: confermata" % (len(garanzia),
                                                         len(garanzia)))
    else:
        print("Giudizi strutturati conformi allo schema: nessun giudizio da "
              "leggere")
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
        elemento = os.path.dirname(os.path.abspath(__file__))
        os.chdir(argv[0])
        esamina(kit, elemento, problemi, garanzia)
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
