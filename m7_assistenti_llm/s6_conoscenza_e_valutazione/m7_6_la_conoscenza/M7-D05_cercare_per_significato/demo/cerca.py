"""cerca.py -- M7-D05 «Cercare per significato»: la stessa domanda con due
ricerche sui dodici articoli di articoli/.

La ricerca per parole conta, articolo per articolo, quante volte compaiono le
parole della domanda, fuori da quelle vuote (articoli, preposizioni, pronomi).
La ricerca per significato chiede un vettore per ogni articolo e per ogni
domanda a un modello di embedding, sul computer dove gira lo script, e ordina
gli articoli per similarità del coseno con la domanda. Stampa le due classifiche
affiancate, dice quale modello ha usato e con quale digest, e scrive
risposte/risultati.json: le domande, per ogni articolo il conteggio delle
parole, il coseno e i due ranghi.

Il modello è embeddinggemma:300m, su Ollama in ascolto su questo computer: lo
script non avvia nessun servizio e non parla con nessun host che non sia il
computer stesso. Non dice niente su Claude: qui Claude non c'entra.

Uso:    python3 -B -I cerca.py [<spazio di lavoro>]
          senza cartella, quella corrente
Env:    PN_OLLAMA_URL  dove risponde Ollama (default http://127.0.0.1:11434);
                       solo loopback: 127.0.0.1, localhost, ::1
Uscita: 0 = le due classifiche stampate e risposte/risultati.json scritto ·
        2 = precondizione: uso sbagliato; un indirizzo che non è loopback;
        Ollama che non risponde o risponde male; il modello che manca; gli
        articoli o le domande che non si leggono (una riga, mai un traceback)
"""
from __future__ import annotations

import datetime
import json
import math
import os
import re
import sys
import tempfile
import unicodedata
import urllib.error
import urllib.parse
import urllib.request
from itertools import zip_longest
from typing import Any, Dict, List, Sequence, Tuple

URL_DEFAULT = "http://127.0.0.1:11434"
HOST_LOCALI = {"127.0.0.1", "localhost", "::1"}
MODELLO = "embeddinggemma:300m"
# La prima richiesta carica il modello in memoria e può metterci un po'.
SECONDI_RICHIESTA = 180
RIGHE_CLASSIFICA = 5
LARGHEZZA_NOME = 26
USO = "Uso: python3 -B -I cerca.py [<spazio di lavoro>]\n"
PAROLA = re.compile(r"[^\W\d_]+(?:-[^\W\d_]+)*")
# Le parole che una ricerca per parole non cerca: articoli, preposizioni,
# pronomi e congiunzioni, che ci sono ovunque.
PAROLE_VUOTE = frozenset("""
    a ad al alla alle allo ai agli che chi ci come con cui da dal dalla dalle
    dallo dai dagli del della delle dello dei degli di e ed gli i il in l la le
    li lo ma mi mia mie miei mio ne nei negli nel nella nelle nello non o per
    se si su sul sulla sulle sullo sui sugli ti tra tu un una uno vi
    """.split())


class Precondizione(Exception):
    """Qualcosa che impedisce di partire o di finire: uscita 2."""


class SenzaRinvii(urllib.request.HTTPRedirectHandler):
    """Un rinvio non si segue: uscirebbe dal computer."""

    def redirect_request(self, *argomenti: Any, **chiavi: Any) -> None:
        return None


def url_ammesso(base: str) -> str:
    """L'indirizzo di Ollama, solo se è loopback. Raises: Precondizione."""
    parti = urllib.parse.urlsplit(base)
    if parti.scheme != "http" or parti.hostname not in HOST_LOCALI:
        raise Precondizione(
            "l'indirizzo di Ollama dev'essere http su questo computer "
            "(127.0.0.1, localhost o ::1), non «%s»" % base)
    return base.rstrip("/")


def chiedi(base: str, percorso: str, corpo: Any = None) -> Dict[str, Any]:
    """Una richiesta a Ollama: il JSON della risposta. Senza proxy e senza
    rinvii. Raises: Precondizione."""
    apri = urllib.request.build_opener(urllib.request.ProxyHandler({}),
                                       SenzaRinvii()).open
    dati = None if corpo is None else json.dumps(corpo).encode("utf-8")
    richiesta = urllib.request.Request(
        base + percorso, data=dati,
        headers={"Content-Type": "application/json"})
    try:
        with apri(richiesta, timeout=SECONDI_RICHIESTA) as risposta:
            testo = risposta.read()
    except urllib.error.HTTPError as exc:
        raise Precondizione("Ollama ha risposto %d su %s" % (
            exc.code, percorso)) from exc
    except (urllib.error.URLError, OSError) as exc:
        raise Precondizione(
            "Ollama non risponde su %s (%s): è avviato?" % (base, exc)) from exc
    try:
        letto = json.loads(testo.decode("utf-8"))
    except (UnicodeDecodeError, ValueError) as exc:
        raise Precondizione("Ollama ha risposto su %s con un testo che non è "
                            "JSON" % percorso) from exc
    if not isinstance(letto, dict):
        raise Precondizione("Ollama ha risposto su %s con un JSON che non è "
                            "un oggetto" % percorso)
    return letto


def digest_modello(base: str) -> str:
    """Il digest di MODELLO, da /api/tags. Raises: Precondizione."""
    modelli = chiedi(base, "/api/tags").get("models")
    for voce in modelli if isinstance(modelli, list) else []:
        if isinstance(voce, dict) and MODELLO in (voce.get("name"),
                                                  voce.get("model")):
            return str(voce.get("digest") or "non indicato")
    raise Precondizione("il modello %s non è fra quelli di Ollama: è "
                        "scaricato?" % MODELLO)


def versione_ollama(base: str) -> Any:
    """La versione di Ollama, se la dice (è solo un'informazione)."""
    try:
        return chiedi(base, "/api/version").get("version")
    except Precondizione:
        return None


def vettori(base: str, testi: Sequence[str]) -> List[List[float]]:
    """Un vettore per testo, da /api/embed. Raises: Precondizione."""
    letto = chiedi(base, "/api/embed", {"model": MODELLO, "input": list(testi)})
    trovati = letto.get("embeddings")
    if not isinstance(trovati, list) or len(trovati) != len(testi):
        raise Precondizione("Ollama non ha restituito un vettore per ogni "
                            "testo (attesi %d)" % len(testi))
    misure = {len(v) if isinstance(v, list) else -1 for v in trovati}
    if len(misure) != 1 or misure == {0} or -1 in misure:
        raise Precondizione("Ollama ha restituito vettori che non sono "
                            "utilizzabili")
    return trovati


def coseno(a: Sequence[float], b: Sequence[float]) -> float:
    """La similarità del coseno. Raises: Precondizione se un vettore è zero."""
    norma = math.sqrt(sum(x * x for x in a)) * math.sqrt(sum(x * x for x in b))
    if norma == 0:
        raise Precondizione("un vettore è fatto di soli zeri")
    return sum(x * y for x, y in zip(a, b)) / norma


def parole_di(testo: str) -> List[str]:
    """Le parole di un testo, in minuscolo, compresi i doppioni."""
    return PAROLA.findall(unicodedata.normalize("NFKC", testo).lower())


def parole_cercate(domanda: str) -> List[str]:
    """Le parole della domanda da cercare, senza doppioni e senza quelle
    vuote, nell'ordine."""
    viste: List[str] = []
    for parola in parole_di(domanda):
        if parola not in PAROLE_VUOTE and parola not in viste:
            viste.append(parola)
    return viste


def conteggio(cercate: Sequence[str], articolo: str) -> int:
    """Quante volte le parole cercate compaiono nell'articolo."""
    parole = parole_di(articolo)
    return sum(parole.count(c) for c in cercate)


def leggi_file(percorso: str) -> str:
    """Il testo di un file. Raises: Precondizione."""
    try:
        with open(percorso, encoding="utf-8") as fh:
            return fh.read()
    except (OSError, UnicodeDecodeError) as exc:
        raise Precondizione("%s non si legge (%s)" % (percorso, exc)) from exc


def leggi_articoli(ws: str) -> List[Tuple[str, str]]:
    """Gli articoli di articoli/: (nome, testo), in ordine di nome.
    Raises: Precondizione."""
    cartella = os.path.join(ws, "articoli")
    try:
        nomi = sorted(n for n in os.listdir(cartella) if n.endswith(".md"))
    except OSError as exc:
        raise Precondizione("manca la cartella degli articoli %s" % cartella
                            ) from exc
    if not nomi:
        raise Precondizione("nessun articolo (.md) in %s" % cartella)
    return [(n, leggi_file(os.path.join(cartella, n))) for n in nomi]


def leggi_domande(ws: str) -> List[str]:
    """Le domande di domande.txt, una per riga. Raises: Precondizione."""
    domande = [r.strip() for r in leggi_file(os.path.join(ws, "domande.txt"))
               .splitlines() if r.strip()]
    if not domande:
        raise Precondizione("domande.txt è vuoto")
    return domande


def rango(voci: List[Dict[str, Any]], chiave: str, nome: str) -> None:
    """Scrive in ogni voce il rango per valore di chiave, dal più alto; a
    pari valore decide il nome dell'articolo."""
    ordinate = sorted(voci, key=lambda v: (-v[chiave], v["articolo"]))
    for posizione, voce in enumerate(ordinate, 1):
        voce[nome] = posizione


def calcola(domanda: str, vettore: Sequence[float],
            articoli: Sequence[Tuple[str, str]],
            vettori_articoli: Sequence[Sequence[float]]) -> Dict[str, Any]:
    """Le due classifiche di una domanda."""
    cercate = parole_cercate(domanda)
    voci: List[Dict[str, Any]] = []
    for (nome, testo), vettore_articolo in zip(articoli, vettori_articoli):
        voci.append({"articolo": nome,
                     "conteggio_parole": conteggio(cercate, testo),
                     "coseno": round(coseno(vettore, vettore_articolo), 6)})
    rango(voci, "conteggio_parole", "rango_parole")
    rango(voci, "coseno", "rango_significato")
    return {"domanda": domanda, "parole_cercate": cercate, "articoli": voci}


def nome_corto(voce: Dict[str, Any]) -> str:
    """Il nome dell'articolo, senza .md e al massimo LARGHEZZA_NOME."""
    nome = str(voce["articolo"])[:-3] if str(voce["articolo"]).endswith(".md") \
        else str(voce["articolo"])
    return nome[:LARGHEZZA_NOME].ljust(LARGHEZZA_NOME)


def riga_parole(voce: Any) -> str:
    """Una riga della colonna per parole; vuota se la voce non c'è."""
    if voce is None:
        return ""
    return "%2d. %s %3d" % (voce["rango_parole"], nome_corto(voce),
                            voce["conteggio_parole"])


def riga_significato(voce: Any) -> str:
    """Una riga della colonna per significato; vuota se la voce non c'è."""
    if voce is None:
        return ""
    return "%2d. %s %s" % (voce["rango_significato"], nome_corto(voce),
                           ("%.3f" % voce["coseno"]).replace(".", ","))


def stampa_classifiche(domande: Sequence[Dict[str, Any]]) -> None:
    """Le due classifiche di ogni domanda, affiancate."""
    for numero, dati in enumerate(domande, 1):
        voci = dati["articoli"]
        per_parole = sorted((v for v in voci if v["conteggio_parole"] > 0),
                            key=lambda v: v["rango_parole"])[:RIGHE_CLASSIFICA]
        per_significato = sorted(voci, key=lambda v: v["rango_significato"]
                                 )[:RIGHE_CLASSIFICA]
        print("\nDomanda %d: «%s»" % (numero, dati["domanda"]))
        print("  parole cercate: %s" % (", ".join(dati["parole_cercate"])
                                        or "nessuna"))
        print("  %-36s  %s" % ("per parole", "per significato"))
        for sinistra, destra in zip_longest(per_parole, per_significato):
            print("  %-36s  %s" % (riga_parole(sinistra),
                                   riga_significato(destra)))
        if not per_parole:
            print("  (per parole: nessun articolo contiene le parole cercate)")


def intestazione(dati: Dict[str, Any]) -> str:
    """Le righe con il modello, il digest e dove gira."""
    return ("Modello di embedding: %s, su Ollama %s (%s).\n"
            "Digest del modello: %s\n"
            "Non è Claude: Anthropic non ha un modello di embedding suo." % (
                dati["modello"], dati["ollama"], dati["url"], dati["digest"]))


def scrivi_risultati(ws: str, dati: Dict[str, Any]) -> str:
    """risposte/risultati.json, con una sostituzione atomica.
    Returns: il percorso."""
    cartella = os.path.join(ws, "risposte")
    os.makedirs(cartella, exist_ok=True)
    finale = os.path.join(cartella, "risultati.json")
    descrittore, temporaneo = tempfile.mkstemp(prefix=".risultati.",
                                               dir=cartella)
    try:
        with os.fdopen(descrittore, "w", encoding="utf-8") as fh:
            fh.write(json.dumps(dati, ensure_ascii=False, indent=1) + "\n")
        os.replace(temporaneo, finale)
    except OSError:
        os.unlink(temporaneo)
        raise
    return finale


def cerca(ws: str, base: str) -> int:
    """Le due ricerche su tutti gli articoli, per ogni domanda. Returns: 0."""
    articoli = leggi_articoli(ws)
    domande = leggi_domande(ws)
    digest = digest_modello(base)
    vettori_articoli = vettori(base, [t for _, t in articoli])
    vettori_domande = vettori(base, domande)
    risultati = [calcola(d, v, articoli, vettori_articoli)
                 for d, v in zip(domande, vettori_domande)]
    dati = {"modello": MODELLO, "digest": digest,
            "url": base, "ollama": versione_ollama(base),
            "data_utc": datetime.datetime.now(
                datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "articoli": [n for n, _ in articoli], "domande": risultati}
    percorso = scrivi_risultati(ws, dati)
    print(intestazione(dati))
    print("%d articoli, %d domande." % (len(articoli), len(domande)))
    stampa_classifiche(risultati)
    print("\nScritto %s" % os.path.relpath(percorso, ws))
    return 0


def errore(messaggio: str) -> int:
    """Il messaggio su STDERR, in una riga; l'uscita 2."""
    sys.stderr.write("cerca.py: %s\n" % " ".join(messaggio.split()))
    return 2


def main(argv: List[str]) -> int:
    for flusso in (sys.stdout, sys.stderr):
        riconfigura = getattr(flusso, "reconfigure", None)
        if riconfigura is not None:
            riconfigura(errors="replace")
    if len(argv) > 1 or any(a.startswith("-") for a in argv):
        sys.stderr.write(USO)
        return 2
    ws = argv[0] if argv else "."
    if not os.path.isdir(ws):
        return errore("spazio di lavoro assente: %s" % ws)
    try:
        return cerca(ws, url_ammesso(os.environ.get("PN_OLLAMA_URL",
                                                    URL_DEFAULT)))
    except Precondizione as exc:
        return errore(str(exc))
    except Exception as exc:  # mai un traceback: un errore inatteso esce 2
        return errore("errore inatteso (%s: %s)" % (type(exc).__name__, exc))


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
