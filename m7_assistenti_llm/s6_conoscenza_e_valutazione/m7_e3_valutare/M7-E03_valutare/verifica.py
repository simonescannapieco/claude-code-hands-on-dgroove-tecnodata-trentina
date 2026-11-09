"""verifica.py -- M7-E03 «Valutare e non regredire»: il lavoro nello spazio di
lavoro, nei tre passi del README.

Legge, nello spazio di lavoro dato:
  1. la taratura del giudice: taratura/etichette.json e i verdetti del giudice
     (giudizi/<id>/verdetto.json, scritti da prova.py giudica). Stampa, per ogni
     conversazione, l'etichetta, il verdetto del giudice e se sono d'accordo.
     L'accordo è un dato: non decide mai l'uscita;
  2. i casi nuovi: casi-nuovi/*.json, almeno due file di caso, nella forma del
     banco (id, scenario, messaggio, asserzioni), sullo stesso scenario, e il
     loro esito in risultati/v1-nuovi/<id>/esito.json. Stampa le asserzioni e
     il loro esito (dati);
  3. la regressione: i cinque casi forniti del banco su due versioni,
     risultati/v0/ e risultati/v1/, ognuno con il suo esito.json finito bene, e
     il file regressione.txt, l'uscita di confronta.py. Stampa la tabella per
     caso, dagli esiti e non dal file: anche questi sono dati.

Decide l'uscita solo la presenza del lavoro, mai un esito.

Uso:    python3 -B -I verifica.py <spazio di lavoro>
Uscita: 0 = i tre passi sono fatti, gli esiti sono qui sopra · 1 = non ancora,
        e dice che cosa manca · 2 = precondizione (lo spazio di lavoro che non
        c'è; un file che non si legge o non è JSON; un errore inatteso: una
        riga, mai un traceback)
"""
from __future__ import annotations

import json
import os
import sys
from typing import Any, Dict, List, Optional, Tuple

ETICHETTE = "taratura/etichette.json"
GIUDIZI = "giudizi"
CASI_NUOVI = "casi-nuovi"
SCENARI = "progetti/assistenza-clienti/scenari"
CASI_FORNITI = "progetti/assistenza-clienti/banco/casi"
RISULTATI = "risultati"
TABELLA = "regressione.txt"
USO = "Uso: python3 -B -I verifica.py <spazio di lavoro>\n"
CAMPI_CASO = ("id", "scenario", "messaggio", "asserzioni")
ASSERZIONI = ("deve_chiamare", "non_deve_chiamare", "prima_di",
              "risposta_contiene", "risposta_non_contiene", "escalation")
FATTO = ("Fatto: il giudice, i casi nuovi e la tabella di regressione ci sono; "
         "gli esiti sono qui sopra.")


class Problema(Exception):
    """Un file che non si legge: uscita 2."""


def leggi_json(percorso: str) -> Any:
    """Il contenuto JSON di un file. Raises: Problema."""
    try:
        with open(percorso, encoding="utf-8") as fh:
            return json.load(fh)
    except (OSError, UnicodeDecodeError) as exc:
        raise Problema("%s: non si legge (%s)" % (percorso, exc)) from exc
    except ValueError as exc:
        raise Problema("%s: non è JSON valido (%s)" % (percorso, exc)) from exc


def taratura(ws: str) -> List[str]:
    """Il passo 1, stampato: le etichette e i verdetti del giudice.
    Returns: ciò che manca."""
    print("1. La taratura del giudice: etichette e verdetti.")
    percorso = os.path.join(ws, ETICHETTE)
    if not os.path.isfile(percorso):
        raise Problema("manca %s: lo spazio di lavoro non è completo" % ETICHETTE)
    dati = leggi_json(percorso)
    conversazioni = dati.get("conversazioni") if isinstance(dati, dict) else None
    if not isinstance(conversazioni, list) or not conversazioni:
        raise Problema("%s non ha la lista «conversazioni»" % ETICHETTE)
    mancano: List[str] = []
    accordo = 0
    nulli = 0
    for voce in conversazioni:
        ident = str(voce.get("id"))
        etichetta = str(voce.get("etichetta"))
        file_verdetto = os.path.join(ws, GIUDIZI, ident, "verdetto.json")
        if not os.path.isfile(file_verdetto):
            print("  %s: etichetta «%s»; il giudizio non c'è ancora" % (
                ident, etichetta))
            mancano.append("il giudizio di %s: passo 2 del README" % ident)
            continue
        verdetto = leggi_json(file_verdetto)
        if not isinstance(verdetto, dict) or "verdetto" not in verdetto:
            mancano.append("il verdetto di %s non è completo" % ident)
            continue
        esito = str(verdetto["verdetto"])
        punteggi = verdetto.get("punteggi") or {}
        vuoti = [c for c, v in punteggi.items() if v is None]
        nulli += len(vuoti)
        accordo += esito == etichetta
        totale = verdetto.get("totale")
        print("  %s: etichetta «%s», giudice «%s», %s: %s%s" % (
            ident, etichetta, esito,
            "totale non calcolato" if totale is None
            else "totale %s su 18" % totale,
            "d'accordo" if esito == etichetta else "NON d'accordo",
            "; il giudice non ha votato %s" % ", ".join(vuoti) if vuoti else ""))
    print("  (dato) accordo con le etichette: %d su %d; voti lasciati a null dal "
          "giudice: %d" % (accordo, len(conversazioni), nulli))
    return mancano


def valida_caso(percorso: str, ws: str) -> Tuple[Optional[Dict[str, Any]], str]:
    """Un file di casi nuovi: (il caso, «») o (None, il problema)."""
    caso = leggi_json(percorso)
    if not isinstance(caso, dict):
        return None, "non è un oggetto JSON"
    assenti = [c for c in CAMPI_CASO if c not in caso]
    if assenti:
        return None, "mancano i campi %s" % ", ".join(assenti)
    if not str(caso["messaggio"]).strip():
        return None, "il messaggio è vuoto"
    if not os.path.isfile(os.path.join(ws, SCENARI, str(caso["scenario"]))):
        return None, "lo scenario %s non esiste in %s" % (caso["scenario"], SCENARI)
    asserzioni = caso["asserzioni"]
    if not isinstance(asserzioni, dict) or not any(
            k in asserzioni and asserzioni[k] not in ([], "", None)
            for k in ASSERZIONI):
        return None, "non ha asserzioni"
    return caso, ""


def esito_caso(ws: str, cartella: str, ident: str
               ) -> Tuple[Optional[Dict[str, Any]], str]:
    """L'esito di un caso: (esito, «») o (None, che cosa non va)."""
    percorso = os.path.join(ws, RISULTATI, cartella, ident, "esito.json")
    if not os.path.isfile(percorso):
        return None, "manca %s" % os.path.relpath(percorso, ws)
    esito = leggi_json(percorso)
    if not isinstance(esito, dict) or not esito.get("completa") \
            or esito.get("errore"):
        return None, "l'esecuzione di %s in %s non è finita" % (ident, cartella)
    return esito, ""


def casi_nuovi(ws: str) -> List[str]:
    """Il passo 2, stampato. Returns: ciò che manca."""
    print("2. Il caso nuovo e il suo opposto.")
    cartella = os.path.join(ws, CASI_NUOVI)
    nomi = sorted(n for n in os.listdir(cartella) if n.endswith(".json")) \
        if os.path.isdir(cartella) else []
    if len(nomi) < 2:
        print("  casi-nuovi/: %d file di caso" % len(nomi))
        return ["i due casi nuovi in casi-nuovi/: passo 3 del README"]
    casi: List[Dict[str, Any]] = []
    mancano: List[str] = []
    for nome in nomi:
        caso, problema = valida_caso(os.path.join(cartella, nome), ws)
        if caso is None:
            print("  %s: %s" % (nome, problema))
            mancano.append("casi-nuovi/%s: %s" % (nome, problema))
            continue
        casi.append(caso)
        print("  %s: %s, scenario %s, %d asserzioni" % (
            nome, caso["id"], caso["scenario"], sum(
                len(v) if isinstance(v, list) else 1
                for v in caso["asserzioni"].values())))
    if len(casi) >= 2 and casi[0]["scenario"] != casi[1]["scenario"]:
        mancano.append("il caso e il suo opposto devono avere lo stesso "
                       "scenario: %s e %s" % (casi[0]["scenario"],
                                              casi[1]["scenario"]))
    for caso in casi:
        esito, problema = esito_caso(ws, "v1-nuovi", str(caso["id"]))
        if esito is None:
            print("  %s: %s" % (caso["id"], problema))
            mancano.append("%s: l'esecuzione del passo 4 (%s)" % (caso["id"],
                                                                  problema))
            continue
        print("  %s su v1: asserzioni %d su %d (dato)" % (
            caso["id"], esito["soddisfatte"], esito["totale"]))
        for riga in esito.get("asserzioni") or []:
            print("    %s %s: %s" % (riga.get("tipo"), riga.get("oggetto"),
                                     "sì" if riga.get("esito") else "NO"))
    return mancano


def regressione(ws: str) -> List[str]:
    """Il passo 3, stampato: la tabella dagli esiti dei casi forniti.
    Returns: ciò che manca."""
    print("3. La regressione: i cinque casi forniti, sulle due versioni.")
    cartella_casi = os.path.join(ws, CASI_FORNITI)
    if not os.path.isdir(cartella_casi):
        raise Problema("manca %s: lo spazio di lavoro non è completo"
                       % CASI_FORNITI)
    ident = sorted(str(leggi_json(os.path.join(cartella_casi, n)).get("id"))
                   for n in os.listdir(cartella_casi) if n.endswith(".json"))
    if not ident:
        raise Problema("nessun caso in %s" % CASI_FORNITI)
    mancano: List[str] = []
    totale_v0, totale_v1, tot_asserzioni, peggiorati = 0, 0, 0, []
    print("  caso      asserzioni in v0   in v1")
    for caso in ident:
        esito_v0, problema_v0 = esito_caso(ws, "v0", caso)
        esito_v1, problema_v1 = esito_caso(ws, "v1", caso)
        if esito_v0 is None:
            mancano.append(problema_v0)
        if esito_v1 is None:
            mancano.append(problema_v1)
        if esito_v0 is None or esito_v1 is None:
            continue
        totale_v0 += esito_v0["soddisfatte"]
        totale_v1 += esito_v1["soddisfatte"]
        tot_asserzioni += esito_v0["totale"]
        if esito_v1["soddisfatte"] < esito_v0["soddisfatte"]:
            peggiorati.append(caso)
        print("  %-9s %d/%-15d %d/%d" % (caso, esito_v0["soddisfatte"],
                                         esito_v0["totale"],
                                         esito_v1["soddisfatte"],
                                         esito_v1["totale"]))
    if not mancano:
        print("  (dato) totale: %d/%d con la v0, %d/%d con la v1; casi "
              "peggiorati con la v1: %s" % (
                  totale_v0, tot_asserzioni, totale_v1, tot_asserzioni,
                  ", ".join(peggiorati) or "nessuno"))
    tabella = os.path.join(ws, TABELLA)
    if not os.path.isfile(tabella) or os.path.getsize(tabella) == 0:
        mancano.append("%s, l'uscita di confronta.py: passo 4 del README"
                       % TABELLA)
    else:
        with open(tabella, encoding="utf-8", errors="replace") as fh:
            testo = fh.read()
        if "totale:" not in testo:
            mancano.append("%s non ha la riga «totale:» di confronta.py"
                           % TABELLA)
    return mancano


def controlla(ws: str) -> int:
    """I tre passi; l'uscita 0 o 1."""
    if not os.path.isdir(ws):
        raise Problema("lo spazio di lavoro non esiste: %s" % ws)
    mancano = taratura(ws)
    print()
    mancano += casi_nuovi(ws)
    print()
    mancano += regressione(ws)
    print()
    if mancano:
        print("Non ancora:")
        for cosa in mancano:
            print("  - %s" % cosa)
        return 1
    print(FATTO)
    return 0


def errore(messaggio: str) -> int:
    sys.stderr.write("verifica.py: %s\n" % messaggio)
    return 2


def main(argv: List[str]) -> int:
    for flusso in (sys.stdout, sys.stderr):
        riconfigura = getattr(flusso, "reconfigure", None)
        if riconfigura is not None:
            riconfigura(errors="replace")
    if len(argv) != 1 or argv[0].startswith("-"):
        sys.stderr.write(USO)
        return 2
    try:
        return controlla(argv[0])
    except Problema as exc:
        return errore(str(exc))
    except Exception as exc:  # mai un traceback: un errore inatteso esce 2
        return errore("errore inatteso (%s: %s)"
                      % (type(exc).__name__, " ".join(str(exc).split())))


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
