"""lib_controlla_prove.py -- legge le prove di una skill: gli stream di
`claude -p --output-format stream-json --verbose` che tools/prove_skill.sh
lascia in <spazio>/<skill>-workspace/, nella forma della guida dello standard
Agent Skills, «Evaluating skill output quality»
(https://agentskills.io/skill-creation/evaluating-skills). Ricalcola ogni
volta dagli stream timing.json, grading.json e benchmark.json: non legge mai
quei file, così un esito vecchio non può passare per buono.

Lo importa il verifica.py di ogni elemento:

    sys.path.insert(0, os.path.join(os.environ["PN_HANDSON_ROOT"], "tools"))
    import lib_controlla_prove as prove

Qualunque cosa non si riesca a leggere solleva Problema (l'elemento esce 2),
mai un conteggio più piccolo. Si importa soltanto questo modulo: la lettura
degli stream sta in lib_leggi_stream.py e la tabella in lib_stampa_prove.py,
accanto, e ciò che serve si trova qui. Il modulo non è eseguibile.

La lettura di uno stream:
  leggi_stream(percorso) -> Esecuzione, con i campi
    percorso, cartella    il file e la sua cartella (outputs/)
    init_skills           l'elenco «skills» del primo system/init; None se
                          lo stream non ce l'ha
    chiamate_skill        input.skill di ogni tool_use «Skill», anche se il
                          permesso l'ha negato: le chiamate tentate
    chiamate_negate       quelle fra loro il cui id è nei permission_denials
    chiamate_respinte     quelle il cui tool_result ha is_error, le negate
                          escluse; chiamata_riuscita(skill) è vero se ne resta
                          una delle chiamate tentate: il
                          corpo della skill è arrivato
    strumenti             Strumento(nome, input) di ogni tool_use
                          (gli uni e gli altri solo dalle righe «assistant»,
                          una volta per id del blocco)
    testo                 «result» dell'ultimo evento result ("" se non c'è)
    turni, duration_ms, secondi
                          sommati su OGNI evento result: una chiamata ne può
                          avere più d'uno, uno per segmento
    token_totali          ciò che va in timing.json: i token di `modelUsage`
                          dell'ultimo result, tutto l'albero dei subagent,
                          entrata + cache creation + cache read + uscita; se
                          non c'è, token_usage
    token_usage           la stessa somma su `usage` di ogni result, che esclude
                          i subagent: la tabella la stampa accanto quando è
                          diversa
    token_modelli         i token di `modelUsage` (None se non c'è)
    locale                vero se un result ha `local_command`
    segmenti              quanti eventi result
    negati                i permission_denials di tutti i result
    errore                vero se un result ha is_error o un subtype error…
    completa              vero se c'è almeno un result
  file_cambiati(esec) -> le righe di outputs/file-cambiati.txt (il git status
    --porcelain della copia, dopo l'esecuzione)
  timing(esec) -> {"total_tokens": …, "duration_ms": …}

I file dello standard:
  giudica(asserzioni, giudici, esec, contesto) -> il dict di grading.json:
    assertion_results[{text, passed, evidence}], summary{passed, failed, total,
    pass_rate}. giudici: testo esatto dell'asserzione -> funzione (esec,
    contesto) -> (vero o falso, evidenza); un'asserzione senza giudice ha
    passed None ed evidence «da valutare a mano», fuori dal summary; una
    evidenza vuota solleva Problema. pass_rate è None se nessuna è giudicata.
  leggi_evals(cartella_skill) -> il dict di evals/evals.json, controllato
  leggi_query(cartella_skill) -> la lista di evals/eval_queries.json
  riepilogo({configurazione: [(grading, timing), …]}) -> il dict di
    benchmark.json: run_summary{<configurazione>: {pass_rate, time_seconds,
    tokens: {mean, stddev}}, delta{pass_rate, time_seconds, tokens}}; il delta
    è with_skill meno la baseline, old_skill se c'è, altrimenti without_skill
  scrivi_json(percorso, oggetto): UTF-8, due spazi, a capo in fondo
  verdetto(a, b) -> «confermata», «non distinguibile», «non confermata in
    questa misura»

Il controllo di un elemento:
  esamina(ws, skill, giudici, contesto_di, scrivi) -> Esame: legge
    <ws>/<skill>-workspace/iteration-N/eval-<id>/<configurazione>/outputs/
    stream.jsonl e iteration-N/near-miss-<k>/with_skill/outputs/stream.jsonl,
    stampa la tabella su STDOUT e, con scrivi vero, scrive timing.json,
    grading.json, outputs/risposta.md e iteration-N/benchmark.json; il delta di
    benchmark.json è nullo se le due configurazioni hanno giudicato casi
    diversi. contesto_di(id, configurazione) (o None) dà ai giudici ciò che
    serve loro.
    Esame: ws, skill, cartella_skill, evals, iterazioni {N: Iterazione(numero,
    prove, near_miss, benchmark)}, prova(N, id, configurazione) -> Prova
    (iterazione, eval_id, configurazione, cartella, esec, grading, timing) o
    None; una near-miss è NearMiss(iterazione, k, query, should_trigger,
    cartella, esec, timing). esec è None se lo stream manca; grading è None
    se l'esecuzione è incompleta o finita con un errore.
  manca_per_finire(esame, ws, skill) -> le cose che mancano per «fatto», come
    frasi: almeno tre evals; iteration-1 without_skill e with_skill e
    iteration-2 with_skill e old_skill complete per ogni eval; una near-miss
    in entrambe; iteration-1/feedback.json con una stringa (anche vuota) per
    ogni eval-<id>; le due skill-snapshot diverse, senza contare evals/.
  reperti(esame, skill) -> le garanzie che non reggono, come frasi: in un
    without_skill una chiamata riuscita a questa skill o la skill nell'elenco
    (un tentativo negato o respinto è un dato, nella tabella); in un
    with_skill, un old_skill o una near-miss la skill non nell'elenco, o la
    chiamata alla skill negata dal permesso o respinta dallo strumento.
  principale(main, argv) -> l'uscita di main(argv), 0, 1 o 2: un Problema, un
    errore inatteso o un'altra uscita diventano 2, con una riga su STDERR e
    mai un traceback.
"""
from __future__ import annotations

import hashlib
import json
import math
import os
import re
import sys
from typing import Callable, Dict, List, NamedTuple, Optional, Tuple

# La lettura degli stream e la tabella stanno accanto a questo file; -I toglie
# la cartella dello script dal percorso dei moduli. Tutto ciò che il modulo
# documenta si importa da qui. Senza di loro si esce 2: un traceback uscirebbe
# 1, e per un controllo 1 vuol dire «non ancora».
sys.path.insert(0, os.path.dirname(os.path.realpath(__file__)))
try:
    # pylint: disable=wrong-import-position,unused-import
    from lib_leggi_stream import (Esecuzione, Problema,  # noqa: F401
                                  Strumento, file_cambiati, leggi_stream,
                                  timing)
    from lib_stampa_prove import (ORDINE_STAMPA, baseline,  # noqa: F401
                                  stampa_iterazione, verdetto)
except ImportError as exc:
    print("lib_controlla_prove: manca un modulo accanto a questo file: "
          f"{exc}", file=sys.stderr)
    sys.exit(2)

MINIMO_EVALS = 3
DA_VALUTARE = "da valutare a mano"
# Le coppie di «fatto»: l'iterazione e la configurazione.
RICHIESTE = ((1, "without_skill"), (1, "with_skill"),
             (2, "with_skill"), (2, "old_skill"))
ORDINE_JSON = ("with_skill", "old_skill", "without_skill")
RE_ITERAZIONE = re.compile(r"^iteration-([1-9][0-9]*)$")
RE_EVAL = re.compile(r"^eval-(0|[1-9][0-9]*)$")
RE_NEAR_MISS = re.compile(r"^near-miss-([1-9][0-9]*)$")


class Prova(NamedTuple):
    """Un'esecuzione di un caso in una configurazione."""
    iterazione: int
    eval_id: int
    configurazione: str
    cartella: str
    esec: Optional[Esecuzione]
    grading: Optional[dict]
    timing: Optional[dict]


class NearMiss(NamedTuple):
    """Un'esecuzione di una richiesta di evals/eval_queries.json."""
    iterazione: int
    k: int
    query: Optional[str]
    should_trigger: Optional[bool]
    cartella: str
    esec: Optional[Esecuzione]
    timing: Optional[dict]


class Iterazione(NamedTuple):
    """Una cartella iteration-N."""
    numero: int
    prove: List[Prova]
    near_miss: List[NearMiss]
    benchmark: dict


class Esame(NamedTuple):
    """Ciò che esamina ha letto."""
    ws: str
    skill: str
    cartella_skill: str
    evals: dict
    iterazioni: Dict[int, Iterazione]

    def prova(self, numero: int, eval_id: int,
              configurazione: str) -> Optional[Prova]:
        """La Prova di una configurazione, se la cartella c'è."""
        iterazione = self.iterazioni.get(numero)
        for prova in iterazione.prove if iterazione else []:
            if prova.eval_id == eval_id \
                    and prova.configurazione == configurazione:
                return prova
        return None


# --------------------------------------------------------------------------
# Il giudizio
# --------------------------------------------------------------------------

def _giudizio(testo: str, giudice: Callable, esec: Esecuzione,
              contesto: object) -> Tuple[bool, str]:
    try:
        passata, evidenza = giudice(esec, contesto)
    except Problema:
        raise
    except Exception as exc:
        raise Problema(f"il giudice di «{testo}» non riesce: "
                       f"{type(exc).__name__}: {exc}") from exc
    if not isinstance(passata, bool):
        raise Problema(f"il giudice di «{testo}» deve restituire vero o "
                       f"falso, non {passata!r}")
    if not isinstance(evidenza, str) or not evidenza.strip():
        raise Problema(f"il giudice di «{testo}» ha risposto senza evidenza: "
                       "un esito senza prova non vale")
    return passata, evidenza


def giudica(asserzioni: List[str], giudici: Dict[str, Callable],
            esec: Esecuzione, contesto: object) -> dict:
    """Il dict di grading.json (vedi il modulo). Raises: Problema."""
    risultati: List[dict] = []
    for testo in asserzioni:
        giudice = giudici.get(testo)
        if giudice is None:
            risultati.append({"text": testo, "passed": None,
                              "evidence": DA_VALUTARE})
            continue
        passata, evidenza = _giudizio(testo, giudice, esec, contesto)
        risultati.append({"text": testo, "passed": passata,
                          "evidence": evidenza})
    passate = sum(1 for r in risultati if r["passed"] is True)
    fallite = sum(1 for r in risultati if r["passed"] is False)
    totale = passate + fallite
    return {"assertion_results": risultati,
            "summary": {"passed": passate, "failed": fallite, "total": totale,
                        "pass_rate": round(passate / totale, 4)
                        if totale else None}}


# --------------------------------------------------------------------------
# I file dei casi
# --------------------------------------------------------------------------

def _leggi_json(percorso: str) -> object:
    """Un file JSON scritto da una persona: un BOM non è un errore."""
    try:
        with open(percorso, encoding="utf-8-sig") as fh:
            return json.load(fh)
    except (OSError, ValueError) as exc:
        raise Problema(f"{percorso}: non si legge: {exc}") from exc


def _testo_pieno(valore: object) -> bool:
    return isinstance(valore, str) and bool(valore.strip())


def _controlla_caso(caso: object, percorso: str, visti: set) -> None:
    if not isinstance(caso, dict):
        raise Problema(f"{percorso}: un elemento di «evals» non è un oggetto")
    ident = caso.get("id")
    if isinstance(ident, bool) or not isinstance(ident, int) or ident < 0:
        raise Problema(f"{percorso}: «id» dev'essere un intero, 0 o più: "
                       f"{ident!r}")
    if ident in visti:
        raise Problema(f"{percorso}: l'id {ident} è ripetuto")
    visti.add(ident)
    for chiave in ("prompt", "expected_output"):
        if not _testo_pieno(caso.get(chiave)):
            raise Problema(f"{percorso}, id {ident}: «{chiave}» dev'essere un "
                           "testo non vuoto")
    for chiave in ("files", "assertions"):
        valore = caso.get(chiave, [])
        if not isinstance(valore, list) \
                or not all(isinstance(voce, str) for voce in valore):
            raise Problema(f"{percorso}, id {ident}: «{chiave}» dev'essere un "
                           "elenco di testi")


def leggi_evals(cartella_skill: str) -> dict:
    """evals/evals.json, controllato. Raises: Problema."""
    percorso = os.path.join(cartella_skill, "evals", "evals.json")
    dati = _leggi_json(percorso)
    if not isinstance(dati, dict):
        raise Problema(f"{percorso}: non è un oggetto con skill_name ed evals")
    nome = os.path.basename(os.path.abspath(cartella_skill))
    if dati.get("skill_name") != nome:
        raise Problema(f"{percorso}: skill_name è {dati.get('skill_name')!r}, "
                       f"la cartella della skill è {nome!r}")
    casi = dati.get("evals")
    if not isinstance(casi, list) or not casi:
        raise Problema(f"{percorso}: evals dev'essere un elenco non vuoto")
    visti: set = set()
    for caso in casi:
        _controlla_caso(caso, percorso, visti)
    return dati


def leggi_query(cartella_skill: str) -> List[dict]:
    """evals/eval_queries.json, controllato. Raises: Problema."""
    percorso = os.path.join(cartella_skill, "evals", "eval_queries.json")
    dati = _leggi_json(percorso)
    if not isinstance(dati, list) or not dati:
        raise Problema(f"{percorso}: dev'essere un elenco non vuoto")
    for voce in dati:
        if not isinstance(voce, dict) or not _testo_pieno(voce.get("query")):
            raise Problema(f"{percorso}: ogni voce ha «query», un testo non "
                           "vuoto")
        if not isinstance(voce.get("should_trigger"), bool):
            raise Problema(f"{percorso}: ogni voce ha «should_trigger», vero "
                           "o falso")
    return dati


# --------------------------------------------------------------------------
# Il riepilogo
# --------------------------------------------------------------------------

def _statistiche(valori: List[float]) -> dict:
    if not valori:
        return {"mean": None, "stddev": None}
    media = sum(valori) / len(valori)
    scarto = 0.0
    if len(valori) > 1:
        scarto = math.sqrt(sum((v - media) ** 2 for v in valori)
                           / (len(valori) - 1))
    return {"mean": round(media, 4), "stddev": round(scarto, 4)}


def _tasso(grading: dict) -> Optional[float]:
    """Il tasso da passate e totale, se ci sono: non dal valore arrotondato."""
    summary = grading["summary"]
    if summary.get("total"):
        return summary["passed"] / summary["total"]
    return summary.get("pass_rate")


def _medie(coppie: List[Tuple[dict, dict]]) -> Dict[str, List[float]]:
    tassi = [_tasso(g) for g, _ in coppie]
    return {"pass_rate": [t for t in tassi if t is not None],
            "time_seconds": [t["duration_ms"] / 1000 for _, t in coppie],
            "tokens": [t["total_tokens"] for _, t in coppie]}


def _delta(valori: Dict[str, Dict[str, List[float]]]) -> dict:
    base = baseline(valori)
    delta: Dict[str, Optional[float]] = {}
    for misura in ("pass_rate", "time_seconds", "tokens"):
        con = valori.get("with_skill", {}).get(misura)
        senza = valori.get(base, {}).get(misura) if base else None
        delta[misura] = (round(sum(con) / len(con) - sum(senza) / len(senza),
                               4) if con and senza else None)
    return delta


def riepilogo(dati: Dict[str, List[Tuple[dict, dict]]]) -> dict:
    """Il dict di benchmark.json (vedi il modulo)."""
    nomi = [n for n in ORDINE_JSON if n in dati]
    nomi += sorted(n for n in dati if n not in ORDINE_JSON)
    valori = {nome: _medie(dati[nome]) for nome in nomi}
    sommario: Dict[str, dict] = {
        nome: {misura: _statistiche(valori[nome][misura])
               for misura in ("pass_rate", "time_seconds", "tokens")}
        for nome in nomi}
    sommario["delta"] = _delta(valori)
    return {"run_summary": sommario}


def scrivi_json(percorso: str, oggetto: object) -> None:
    """Un file JSON nella forma dello standard. Raises: Problema."""
    try:
        with open(percorso, "w", encoding="utf-8") as fh:
            json.dump(oggetto, fh, ensure_ascii=False, indent=2)
            fh.write("\n")
    except OSError as exc:
        raise Problema(f"non riesco a scrivere {percorso}: {exc}") from exc


# --------------------------------------------------------------------------
# La lettura di una iterazione
# --------------------------------------------------------------------------

def _sottocartelle(cartella: str, prefisso: str,
                   schema: "re.Pattern") -> List[Tuple[int, str]]:
    """Le cartelle <prefisso>N, in ordine di numero; un nome che comincia
    così e non torna è un Problema, mai una prova in meno."""
    trovate: List[Tuple[int, str]] = []
    try:
        nomi = os.listdir(cartella)
    except OSError as exc:
        raise Problema(f"non riesco a leggere {cartella}: {exc}") from exc
    for nome in nomi:
        if not nome.startswith(prefisso):
            continue
        piena = os.path.join(cartella, nome)
        trovato = schema.match(nome)
        if trovato is None or not os.path.isdir(piena):
            raise Problema(f"{piena}: non riconosco questo nome: spostalo "
                           "fuori da questa cartella")
        trovate.append((int(trovato.group(1)), piena))
    return sorted(trovate)


def _togli(percorso: str) -> None:
    """Toglie un file ricalcolato, se c'è. Raises: Problema."""
    try:
        if os.path.exists(percorso):
            os.remove(percorso)
    except OSError as exc:
        raise Problema(f"non riesco a togliere {percorso}: {exc}") from exc


def _scrivi_prova(cartella: str, esec: Optional[Esecuzione],
                  voti: Optional[dict], tempi: Optional[dict]) -> None:
    """I file ricalcolati; un file vecchio di una prova che non ha più quel
    risultato se ne va, così nessuno lo legge per buono."""
    for nome, oggetto in (("timing.json", tempi), ("grading.json", voti)):
        percorso = os.path.join(cartella, nome)
        if oggetto is not None:
            scrivi_json(percorso, oggetto)
        else:
            _togli(percorso)
    risposta = os.path.join(cartella, "outputs", "risposta.md")
    if esec is None or not esec.completa:
        _togli(risposta)
        return
    try:
        with open(risposta, "w", encoding="utf-8") as fh:
            fh.write(esec.testo + "\n")
    except OSError as exc:
        raise Problema(f"non riesco a scrivere {risposta}: {exc}") from exc


def _contesto(contesto_di: Optional[Callable], ident: int,
              configurazione: str) -> object:
    """Ciò che l'elemento dà ai giudici; se non riesce, un Problema."""
    if contesto_di is None:
        return None
    try:
        return contesto_di(ident, configurazione)
    except Problema:
        raise
    except Exception as exc:
        raise Problema(f"contesto_di({ident}, {configurazione}) non riesce: "
                       f"{type(exc).__name__}: {exc}") from exc


def _leggi_prova(numero: int, ident: int, configurazione: str, cartella: str,
                 asserzioni: List[str], giudici: Dict[str, Callable],
                 contesto_di: Optional[Callable], scrivi: bool) -> Prova:
    stream = os.path.join(cartella, "outputs", "stream.jsonl")
    if not os.path.isfile(stream):
        if scrivi:
            _scrivi_prova(cartella, None, None, None)
        return Prova(numero, ident, configurazione, cartella, None, None, None)
    esec = leggi_stream(stream)
    tempi = timing(esec) if esec.completa else None
    voti = None
    if esec.completa and not esec.errore:
        voti = giudica(asserzioni, giudici, esec,
                       _contesto(contesto_di, ident, configurazione))
    if scrivi:
        _scrivi_prova(cartella, esec, voti, tempi)
    return Prova(numero, ident, configurazione, cartella, esec, voti, tempi)


def _configurazioni(cartella: str) -> List[str]:
    try:
        presenti = [nome for nome in os.listdir(cartella)
                    if os.path.isdir(os.path.join(cartella, nome))]
    except OSError as exc:
        raise Problema(f"non riesco a leggere {cartella}: {exc}") from exc
    return ([n for n in ORDINE_STAMPA if n in presenti]
            + sorted(n for n in presenti if n not in ORDINE_STAMPA))


def _voce_near_miss(cartella: str, k: int, query: List[dict]) -> dict:
    """La richiesta di una near-miss: quella che ha ricevuto davvero, se
    tools/prove_skill.sh l'ha lasciata accanto allo stream; eval_queries.json
    può essere cambiato dopo. Senza quel file, per posizione."""
    percorso = os.path.join(cartella, "outputs", "prompt.txt")
    if not os.path.isfile(percorso):
        return query[k - 1] if k <= len(query) else {}
    try:
        with open(percorso, encoding="utf-8") as fh:
            usata = fh.read()
    except (OSError, UnicodeDecodeError) as exc:
        raise Problema(f"non riesco a leggere {percorso}: {exc}") from exc
    for voce in query:
        if voce["query"] == usata:
            return voce
    return {"query": usata}


def _leggi_near_miss(numero: int, k: int, cartella: str, query: List[dict],
                     scrivi: bool) -> NearMiss:
    cartella = os.path.join(cartella, "with_skill")
    voce = _voce_near_miss(cartella, k, query)
    stream = os.path.join(cartella, "outputs", "stream.jsonl")
    esec = leggi_stream(stream) if os.path.isfile(stream) else None
    tempi = timing(esec) if esec is not None and esec.completa else None
    if scrivi and esec is not None:
        _scrivi_prova(cartella, esec, None, tempi)
    return NearMiss(numero, k, voce.get("query"), voce.get("should_trigger"),
                    cartella, esec, tempi)


def _benchmark(prove: List[Prova]) -> dict:
    """benchmark.json di un'iterazione. Il delta confronta gli stessi casi: se
    una configurazione ne ha giudicati altri, un delta direbbe una differenza
    che le esecuzioni non mostrano, e resta nullo."""
    per_conf: Dict[str, List[Tuple[dict, dict]]] = {}
    casi: Dict[str, set] = {}
    for prova in prove:
        if prova.grading is not None:
            per_conf.setdefault(prova.configurazione, []).append(
                (prova.grading, prova.timing))
            casi.setdefault(prova.configurazione, set()).add(prova.eval_id)
    risultato = riepilogo(per_conf)
    base = baseline(per_conf)
    if base and "with_skill" in casi and casi[base] != casi["with_skill"]:
        risultato["run_summary"]["delta"] = {
            "pass_rate": None, "time_seconds": None, "tokens": None}
    return risultato


def _leggi_iterazione(numero: int, cartella: str, casi: Dict[int, dict],
                      query: List[dict], giudici: Dict[str, Callable],
                      contesto_di: Optional[Callable],
                      scrivi: bool) -> Iterazione:
    prove: List[Prova] = []
    for ident, cartella_eval in _sottocartelle(cartella, "eval-", RE_EVAL):
        if ident not in casi:
            raise Problema(f"{cartella_eval}: l'id {ident} di eval-{ident} "
                           "non è in evals.json: rimetti il caso, o sposta "
                           "la cartella")
        for configurazione in _configurazioni(cartella_eval):
            prove.append(_leggi_prova(
                numero, ident, configurazione,
                os.path.join(cartella_eval, configurazione),
                casi[ident].get("assertions", []), giudici, contesto_di,
                scrivi))
    vicine = [_leggi_near_miss(numero, k, piena, query, scrivi) for k, piena
              in _sottocartelle(cartella, "near-miss-", RE_NEAR_MISS)]
    benchmark = _benchmark(prove)
    if scrivi:
        scrivi_json(os.path.join(cartella, "benchmark.json"), benchmark)
    return Iterazione(numero, prove, vicine, benchmark)


# --------------------------------------------------------------------------
# L'esame
# --------------------------------------------------------------------------

def esamina(ws: str, skill: str, giudici: Dict[str, Callable],
            contesto_di: Optional[Callable], scrivi: bool) -> Esame:
    """Legge tutte le iterazioni e stampa la tabella (vedi il modulo).

    Non legge mai grading.json, timing.json né benchmark.json. Raises:
    Problema.
    """
    ws = os.path.abspath(ws)
    cartella_skill = os.path.join(ws, ".claude", "skills", skill)
    dati = leggi_evals(cartella_skill)
    casi = {caso["id"]: caso for caso in dati["evals"]}
    file_query = os.path.join(cartella_skill, "evals", "eval_queries.json")
    query = leggi_query(cartella_skill) if os.path.isfile(file_query) else []
    base = os.path.join(ws, f"{skill}-workspace")
    trovate = (_sottocartelle(base, "iteration-", RE_ITERAZIONE)
               if os.path.isdir(base) else [])
    iterazioni: Dict[int, Iterazione] = {}
    for numero, cartella in trovate:
        iterazioni[numero] = _leggi_iterazione(numero, cartella, casi, query,
                                               giudici, contesto_di, scrivi)
        stampa_iterazione(iterazioni[numero], skill)
    if not iterazioni:
        print(f"Nessuna iterazione ancora in {skill}-workspace/.")
    return Esame(ws, skill, cartella_skill, dati, iterazioni)


# --------------------------------------------------------------------------
# Che cosa manca, che cosa non regge
# --------------------------------------------------------------------------

def _manca_prova(esame: Esame, numero: int, ident: int,
                 configurazione: str) -> Optional[str]:
    prova = esame.prova(numero, ident, configurazione)
    if prova is None or prova.esec is None:
        return f"iterazione {numero}, eval-{ident}: manca {configurazione}"
    dove = f"iterazione {numero}, eval-{ident}, {configurazione}"
    if not prova.esec.completa:
        return f"{dove}: incompleta: lo stream non ha un risultato"
    if prova.esec.errore:
        return f"{dove}: finita con un errore"
    return None


def _manca_near_miss(esame: Esame, numero: int) -> Optional[str]:
    iterazione = esame.iterazioni.get(numero)
    for vicina in iterazione.near_miss if iterazione else []:
        if vicina.esec is not None and vicina.esec.completa \
                and not vicina.esec.errore:
            return None
    return f"iterazione {numero}: manca la near-miss"


def _manca_commenti(base: str, ids: List[int]) -> List[str]:
    nome = "iteration-1/feedback.json"
    percorso = os.path.join(base, "iteration-1", "feedback.json")
    if not os.path.isfile(percorso):
        return [f"{nome}: manca: un commento per ogni caso, anche vuoto"]
    try:
        with open(percorso, encoding="utf-8-sig") as fh:
            dati = json.load(fh)
    except (OSError, ValueError) as exc:
        return [f"{nome}: non è JSON: {exc}"]
    if not isinstance(dati, dict):
        return [f"{nome}: non è un oggetto con una voce per ogni caso"]
    mancanze: List[str] = []
    for ident in ids:
        chiave = f"eval-{ident}"
        if chiave not in dati:
            mancanze.append(f"{nome}: manca la voce {chiave}")
        elif not isinstance(dati[chiave], str):
            mancanze.append(f"{nome}: la voce {chiave} non è una stringa")
    return mancanze


def _albero(cartella: str) -> Dict[str, str]:
    """Il contenuto di una fotografia, senza evals/: percorso -> impronta."""
    impronte: Dict[str, str] = {}
    for radice, cartelle, nomi in os.walk(cartella):
        if radice == cartella and "evals" in cartelle:
            cartelle.remove("evals")
        for nome in nomi:
            pieno = os.path.join(radice, nome)
            try:
                with open(pieno, "rb") as fh:
                    impronte[os.path.relpath(pieno, cartella)] = \
                        hashlib.sha256(fh.read()).hexdigest()
            except OSError as exc:
                raise Problema(f"non riesco a leggere {pieno}: {exc}") from exc
    return impronte


def _manca_versioni(base: str) -> List[str]:
    alberi: List[Dict[str, str]] = []
    mancanze: List[str] = []
    for numero in (1, 2):
        cartella = os.path.join(base, f"iteration-{numero}", "skill-snapshot")
        if os.path.isdir(cartella):
            alberi.append(_albero(cartella))
        else:
            mancanze.append(f"iteration-{numero}/skill-snapshot: manca")
    if not mancanze and alberi[0] == alberi[1]:
        mancanze.append("le due versioni della skill sono uguali: cambia la "
                        "skill prima della seconda iterazione")
    return mancanze


def manca_per_finire(esame: Esame, ws: str, skill: str) -> List[str]:
    """Ciò che manca per «fatto» (vedi il modulo). Raises: Problema."""
    ids = [caso["id"] for caso in esame.evals["evals"]]
    mancanze: List[str] = []
    if len(ids) < MINIMO_EVALS:
        casi = "1 caso" if len(ids) == 1 else f"{len(ids)} casi"
        mancanze.append(f"evals/evals.json ha {casi}: ne servono almeno "
                        f"{MINIMO_EVALS}")
    for numero, configurazione in RICHIESTE:
        for ident in ids:
            motivo = _manca_prova(esame, numero, ident, configurazione)
            if motivo:
                mancanze.append(motivo)
    for numero in (1, 2):
        motivo = _manca_near_miss(esame, numero)
        if motivo:
            mancanze.append(motivo)
    base = os.path.join(os.path.abspath(ws), f"{skill}-workspace")
    mancanze.extend(_manca_commenti(base, ids))
    mancanze.extend(_manca_versioni(base))
    return mancanze


def _chiamata_fermata(dove: str, esec: Esecuzione,
                      skill: str) -> Optional[str]:
    """Una chiamata alla skill che non ha portato il corpo: chi l'ha fermata
    decide il motivo e il rimedio; se è stato anche il permesso, vale quello.
    """
    if skill not in esec.chiamate_skill or esec.chiamata_riuscita(skill):
        return None
    if skill in esec.chiamate_negate:
        return (f"{dove}: la chiamata Skill a {skill} è negata dal permesso, "
                f"e il corpo non è arrivato: in prove/config serve "
                f"Skill({skill}) fra gli strumenti")
    return (f"{dove}: la chiamata Skill a {skill} è respinta dallo strumento, "
            "e il corpo non è arrivato: il motivo è nel tool_result, in "
            "outputs/stream.jsonl")


def _reperti_esecuzione(dove: str, esec: Optional[Esecuzione], skill: str,
                        senza_skill: bool) -> List[str]:
    if esec is None:
        return []
    if esec.completa and esec.init_skills is None:
        raise Problema(f"{esec.percorso}: lo stream non ha l'elenco delle "
                       "skill di system/init: la garanzia non si legge")
    elenco = esec.init_skills or []
    trovati: List[str] = []
    if not senza_skill:
        if esec.init_skills is not None and skill not in elenco:
            trovati.append(f"{dove}: {skill} non è fra le skill disponibili")
        fermata = _chiamata_fermata(dove, esec, skill)
        if fermata:
            trovati.append(fermata)
        return trovati
    # La garanzia è che il corpo non arrivi: un tentativo fermato è un dato.
    if esec.chiamata_riuscita(skill):
        trovati.append(f"{dove}: una chiamata Skill a {skill}, che in questa "
                       "copia non c'è")
    if skill in elenco:
        trovati.append(f"{dove}: {skill} è fra le skill disponibili, e in "
                       "questa copia non dovrebbe esserci")
    return trovati


def reperti(esame: Esame, skill: str) -> List[str]:
    """Le garanzie che non reggono (vedi il modulo). Raises: Problema."""
    trovati: List[str] = []
    for numero in sorted(esame.iterazioni):
        iterazione = esame.iterazioni[numero]
        for prova in iterazione.prove:
            dove = (f"iterazione {numero}, eval-{prova.eval_id}, "
                    f"{prova.configurazione}")
            trovati.extend(_reperti_esecuzione(
                dove, prova.esec, skill,
                prova.configurazione == "without_skill"))
        for vicina in iterazione.near_miss:
            trovati.extend(_reperti_esecuzione(
                f"iterazione {numero}, near-miss {vicina.k}", vicina.esec,
                skill, False))
    return trovati


# --------------------------------------------------------------------------
# L'uscita, e la riga di comando di tools/prove_skill.sh
# --------------------------------------------------------------------------

def principale(funzione: Callable, argv: List[str]) -> int:
    """L'uscita di funzione(argv): 0, 1 o 2 (vedi il modulo)."""
    for canale in (sys.stdout, sys.stderr):
        if hasattr(canale, "reconfigure"):
            canale.reconfigure(encoding="utf-8", errors="replace")
    try:
        esito = funzione(argv)
    except Problema as exc:
        print(f"FATALE: {exc}", file=sys.stderr)
        return 2
    except Exception as exc:  # pylint: disable=broad-except
        print(f"FATALE: errore inatteso: {type(exc).__name__}: {exc}",
              file=sys.stderr)
        return 2
    if esito not in (0, 1, 2) or isinstance(esito, bool):
        print(f"FATALE: un'uscita fuori dal contratto 0/1/2: {esito!r}",
              file=sys.stderr)
        return 2
    return esito
