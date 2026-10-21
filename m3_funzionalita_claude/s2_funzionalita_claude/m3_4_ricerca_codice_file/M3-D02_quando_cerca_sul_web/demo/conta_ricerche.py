"""conta_ricerche.py -- quando Claude ha cercato sul web nelle chiamate di
M3-D02, e un'affermazione di Anthropic alla prova.

Legge, nello spazio di lavoro (la cartella data, o quella corrente),
risposte/<domanda>-<n>.jsonl: lo stream-json di `claude -p --output-format
stream-json --verbose` di sei chiamate a sonnet con un solo strumento per
il web, WebSearch: tre sulla domanda attuale (attuale.md, l'ultima
versione di Claude Code nel changelog ufficiale) e tre sulla domanda
stabile (stabile.md, che cos'è la fibra FTTH); n = 1, 2, 3. Ogni riga
dello stream è un evento JSON; l'ultima è il risultato. Per ogni chiamata
stampa quante volte Claude ha chiamato WebSearch (i blocchi tool_use dei
messaggi dell'assistente con quel nome, contati una volta per id) e che
cosa ha cercato; gli altri strumenti, se ce ne sono (WebFetch, per
esempio, con gli indirizzi che ha aperto), come dati e mai come ricerche;
gli indirizzi citati nella risposta, i primi 300 caratteri della risposta
e, per la domanda attuale, il numero di versione che la risposta dà: un
dato, che il controllo non giudica. Poi il verdetto di ogni coppia, la
chiamata n della domanda attuale con la n della stabile, e il riepilogo
«confermata n su 3»:
  «Cerca per l'attuale, non per lo stabile»: confermata se per la domanda
      attuale Claude ha chiamato WebSearch almeno una volta e per la
      stabile mai; altrimenti non confermata in questa esecuzione, con il
      perché. Solo una chiamata a WebSearch è una ricerca: aprire una
      pagina non lo è. Mai «smentita»: una sola esecuzione non smentisce
      ciò che Anthropic descrive.
Il verdetto si stampa e non decide l'uscita. Senza --senza-esiti scrive
anche esiti.tsv, una riga per file: le chiamate a WebSearch, gli altri
strumenti, le ricerche, gli indirizzi aperti (da altri strumenti) e
citati, la versione (solo per la domanda attuale), i dinieghi dei
permessi, l'inizio della risposta.

Uso:    python3 conta_ricerche.py [--senza-esiti] [<spazio di lavoro>]
          senza cartella, quella corrente; con --senza-esiti non scrive e
          non toglie esiti.tsv (lo usa verifica.sh, che non cambia niente)
Uscita: 0 le sei chiamate ci sono e si leggono (il verdetto non decide
          l'uscita)
        1 manca la cartella risposte/ (nessun esiti.tsv: uno vecchio viene
          tolto), oppure una chiamata manca o il suo file non è lo
          stream-json riuscito di claude -p (una riga che non è JSON, uno
          stream che non finisce con il risultato o che ha soltanto il
          risultato, un errore); esiti.tsv ha le righe delle chiamate che
          ci sono
        2 uso sbagliato; lo spazio di lavoro assente; un file che non si
          legge; esiti.tsv che non si scrive; un errore inatteso (una riga,
          mai un traceback): nessun esiti.tsv resta (uno vecchio viene
          tolto)
"""
from __future__ import annotations

import json
import os
import re
import sys
from typing import Dict, List, NamedTuple, Tuple

DOMANDE = ("attuale", "stabile")
ESECUZIONI = (1, 2, 3)
CARTELLA = "risposte"
ESITI = "esiti.tsv"
INTESTAZIONE = ["file", "domanda", "esecuzione", "websearch",
                "altri_strumenti", "cercato", "aperti", "citati",
                "versione", "dinieghi", "risposta"]
# Il solo strumento che è una ricerca; ogni altro si stampa come dato.
RICERCA = "WebSearch"
NA = "—"
S_RICERCA = "Cerca per l'attuale, non per lo stabile"
CONFERMATA = "confermata"
NON_CONFERMATA = "non confermata in questa esecuzione"
PARTENZA = "Manca la cartella risposte/: eseguite i passi del README."
NON_ANCORA = ("Non ancora: una chiamata manca o il suo file non è lo "
              "stream-json riuscito di claude -p; rifate la chiamata "
              "indicata sopra, poi rilanciate il controllo.")
USO = ("Uso: python3 conta_ricerche.py [--senza-esiti] "
       "[<spazio di lavoro>]\n")
URL = re.compile(r"https?://[^\s<>()\[\]{}«»\"'`|]+")
VERSIONE = re.compile(r"(?<![\d.])(\d+\.\d+\.\d+)(?!\.?\d)")
INIZIO = 300


class Precondizione(Exception):
    """Un file che non si legge o non si scrive: uscita 2."""


class Mancante(Exception):
    """Una chiamata che manca o non è lo stream-json riuscito di
    claude -p: uscita 1."""


class Chiamata(NamedTuple):
    """Che cosa dice lo stream di una chiamata: le chiamate a ogni
    strumento, le ricerche, gli indirizzi aperti e citati, la versione
    nella risposta ("" se non c'è), i dinieghi, la risposta."""
    strumenti: Dict[str, int]
    cercato: Tuple[str, ...]
    aperti: Tuple[str, ...]
    citati: Tuple[str, ...]
    versione: str
    dinieghi: int
    risposta: str


Chiamate = Dict[Tuple[str, int], Chiamata]


def compatta(testo: str) -> str:
    """Il testo su una riga sola: ogni sequenza di spazi, a capo e
    tabulazioni diventa uno spazio."""
    return " ".join(testo.split())


def taglia(testo: str, quanti: int) -> str:
    """Il testo, al massimo quanti caratteri, con «…» se è tagliato."""
    return testo if len(testo) <= quanti else testo[:quanti - 1] + "…"


def senza_doppi(voci: List[str]) -> Tuple[str, ...]:
    """Le voci senza ripetizioni, nell'ordine in cui compaiono."""
    viste: List[str] = []
    for voce in voci:
        if voce and voce not in viste:
            viste.append(voce)
    return tuple(viste)


def eventi_di(percorso: str) -> List[dict]:
    """Gli eventi dello stream in un file di risposte/, se l'ultimo è il
    risultato riuscito. Mancante se manca o non va; Precondizione se non
    si legge."""
    if not os.path.lexists(percorso):
        raise Mancante("manca %s: rifate quella chiamata" % percorso)
    try:
        with open(percorso, "rb") as fh:
            testo = fh.read().decode("utf-8", errors="replace")
    except OSError as exc:
        raise Precondizione("%s non si legge (%s)"
                            % (percorso, exc.strerror or exc))
    eventi: List[dict] = []
    for numero, riga in enumerate(testo.splitlines(), 1):
        if not riga.strip():
            continue
        try:
            evento = json.loads(riga)
        except (ValueError, RecursionError):
            evento = None
        if not isinstance(evento, dict):
            raise Mancante("%s, riga %d: non è un evento dello stream-json "
                           "di claude -p; rifate quella chiamata"
                           % (percorso, numero))
        eventi.append(evento)
    if not eventi:
        raise Mancante("%s è vuoto: la chiamata a claude è fallita? "
                       "Rifatela" % percorso)
    ultimo = eventi[-1]
    if ultimo.get("type") != "result":
        raise Mancante("%s: lo stream non finisce con il risultato (la "
                       "chiamata si è interrotta?); rifatela" % percorso)
    if len(eventi) == 1:
        raise Mancante("%s: c'è soltanto il risultato, senza gli eventi "
                       "che lo precedono (è l'uscita di --output-format "
                       "json?); rifate la chiamata con --output-format "
                       "stream-json --verbose" % percorso)
    if ultimo.get("is_error") or ultimo.get("subtype", "success") \
            != "success":
        raise Mancante("%s: claude ha restituito un errore; rifate quella "
                       "chiamata" % percorso)
    risposta = ultimo.get("result")
    if not isinstance(risposta, str) or not risposta.strip():
        raise Mancante("%s: manca la risposta («result»); rifate quella "
                       "chiamata" % percorso)
    return eventi


def blocchi_tool_use(eventi: List[dict]) -> List[dict]:
    """I blocchi tool_use dei messaggi dell'assistente, una volta per id
    (un blocco senza id conta ogni volta che compare)."""
    visti = set()
    blocchi: List[dict] = []
    for evento in eventi:
        messaggio = evento.get("message")
        if evento.get("type") != "assistant" or not isinstance(messaggio,
                                                               dict):
            continue
        contenuto = messaggio.get("content")
        if not isinstance(contenuto, list):
            continue
        for blocco in contenuto:
            if not isinstance(blocco, dict) or blocco.get("type") \
                    != "tool_use":
                continue
            ident = blocco.get("id")
            if isinstance(ident, str) and ident:
                if ident in visti:
                    continue
                visti.add(ident)
            blocchi.append(blocco)
    return blocchi


def leggi_chiamata(percorso: str) -> Chiamata:
    """Che cosa dice lo stream di una chiamata."""
    eventi = eventi_di(percorso)
    strumenti: Dict[str, int] = {}
    cercato: List[str] = []
    aperti: List[str] = []
    for blocco in blocchi_tool_use(eventi):
        nome = blocco.get("name")
        nome = nome if isinstance(nome, str) and nome else "?"
        strumenti[nome] = strumenti.get(nome, 0) + 1
        ingresso = blocco.get("input")
        if not isinstance(ingresso, dict):
            continue
        if nome == RICERCA and isinstance(ingresso.get("query"), str):
            cercato.append(compatta(ingresso["query"]))
        if nome != RICERCA and isinstance(ingresso.get("url"), str):
            aperti.append(ingresso["url"].strip())
    ultimo = eventi[-1]
    risposta = ultimo["result"]
    dinieghi = ultimo.get("permission_denials")
    versione = VERSIONE.search(risposta)
    return Chiamata(
        strumenti, senza_doppi(cercato), senza_doppi(aperti),
        senza_doppi([u.rstrip(".,;:!?") for u in URL.findall(risposta)]),
        versione.group(1) if versione else "",
        len(dinieghi) if isinstance(dinieghi, list) else 0, risposta)


def ricerche(chiamata: Chiamata) -> int:
    """Le chiamate a WebSearch: le sole che sono ricerche."""
    return chiamata.strumenti.get(RICERCA, 0)


def altri(chiamata: Chiamata) -> str:
    """Gli altri strumenti chiamati, con quante volte; "" se nessuno. Sono
    dati: nessuno di loro è una ricerca."""
    return ", ".join("%s %d" % (nome, quante) for nome, quante
                     in sorted(chiamata.strumenti.items())
                     if nome != RICERCA)


def avviso(messaggio: str) -> None:
    """Una chiamata da rifare, o un errore, su STDERR."""
    sys.stderr.write("conta_ricerche.py: %s\n" % messaggio)


def leggi_tutto() -> Tuple[Chiamate, int]:
    """Le chiamate che ci sono, e quante mancano o non vanno, ciascuna
    detta su STDERR."""
    chiamate: Chiamate = {}
    mancanti = 0
    for n in ESECUZIONI:
        for domanda in DOMANDE:
            percorso = "%s/%s-%d.jsonl" % (CARTELLA, domanda, n)
            try:
                chiamate[(domanda, n)] = leggi_chiamata(percorso)
            except Mancante as exc:
                avviso(str(exc))
                mancanti += 1
    return chiamate, mancanti


def elenco(voci: Tuple[str, ...]) -> str:
    """Le voci separate da uno spazio, oppure «nessuno»."""
    return " ".join(voci) if voci else "nessuno"


def dati(domanda: str, n: int, chiamata: Chiamata) -> List[str]:
    """Le righe dei dati di una chiamata."""
    parti = ["WebSearch %d" % ricerche(chiamata)]
    if chiamata.cercato:
        parti.append("cercato: %s" % " | ".join(
            "«%s»" % q for q in chiamata.cercato))
    if altri(chiamata):
        parti.append("altri strumenti, non ricerche: %s" % altri(chiamata))
    if chiamata.aperti:
        parti.append("aperti: %s" % elenco(chiamata.aperti))
    parti.append("citati: %s" % elenco(chiamata.citati))
    if domanda == "attuale":
        parti.append("versione nella risposta: %s"
                     % (chiamata.versione or "nessuna"))
    if chiamata.dinieghi:
        parti.append("dinieghi dei permessi: %d" % chiamata.dinieghi)
    return ["%s, %d: %s" % (domanda, n, "; ".join(parti)),
            "  risposta: «%s»" % taglia(compatta(chiamata.risposta),
                                        INIZIO)]


def volte(quante: int) -> str:
    """«1 chiamata» oppure «n chiamate»."""
    return "1 chiamata" if quante == 1 else "%d chiamate" % quante


def verdetto(attuale: Chiamata, stabile: Chiamata) -> str:
    """Il verdetto di una coppia: almeno una chiamata a WebSearch per la
    domanda attuale e nessuna per la stabile lo conferma. Gli altri
    strumenti non contano: non sono ricerche."""
    sull_attuale, sulla_stabile = ricerche(attuale), ricerche(stabile)
    if sull_attuale >= 1 and sulla_stabile == 0:
        return CONFERMATA
    motivi = []
    if sull_attuale == 0:
        motivi.append("la domanda attuale senza WebSearch")
    if sulla_stabile > 0:
        motivi.append("la domanda stabile con %s a WebSearch"
                      % volte(sulla_stabile))
    return "%s (%s)" % (NON_CONFERMATA, "; ".join(motivi))


def stampa(chiamate: Chiamate) -> None:
    """I dati delle chiamate, coppia per coppia, poi i verdetti e il
    riepilogo: ogni verdetto solo se ci sono le due chiamate della
    coppia."""
    for n in ESECUZIONI:
        for domanda in DOMANDE:
            chiamata = chiamate.get((domanda, n))
            if chiamata is not None:
                for riga in dati(domanda, n, chiamata):
                    print(riga)
    esiti = []
    for n in ESECUZIONI:
        attuale = chiamate.get(("attuale", n))
        stabile = chiamate.get(("stabile", n))
        if attuale is not None and stabile is not None:
            esiti.append(verdetto(attuale, stabile))
            print("%s (coppia %d): %s" % (S_RICERCA, n, esiti[-1]))
    if esiti:
        print("%s: %s %d su %d" % (S_RICERCA, CONFERMATA,
                                   esiti.count(CONFERMATA), len(esiti)))


def riga_esiti(domanda: str, n: int, chiamata: Chiamata) -> List[str]:
    """La riga di esiti.tsv di una chiamata."""
    return ["%s-%d.jsonl" % (domanda, n), domanda, str(n),
            str(ricerche(chiamata)), altri(chiamata) or NA,
            compatta(" | ".join(chiamata.cercato)) or NA,
            compatta(" ".join(chiamata.aperti)) or NA,
            compatta(" ".join(chiamata.citati)) or NA,
            (chiamata.versione or NA) if domanda == "attuale" else NA,
            str(chiamata.dinieghi),
            taglia(compatta(chiamata.risposta), INIZIO)]


def scrivi(chiamate: Chiamate) -> None:
    """esiti.tsv: l'intestazione e una riga per chiamata che c'è,
    coppia per coppia."""
    righe = ["\t".join(INTESTAZIONE)]
    for n in ESECUZIONI:
        for domanda in DOMANDE:
            chiamata = chiamate.get((domanda, n))
            if chiamata is not None:
                righe.append("\t".join(riga_esiti(domanda, n, chiamata)))
    try:
        with open(ESITI, "w", encoding="utf-8", newline="\n") as fh:
            fh.write("\n".join(righe) + "\n")
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


def controlla(scrivi_esiti: bool) -> int:
    """Il controllo nella cartella corrente, lo spazio di lavoro: stampa,
    scrive esiti.tsv se scrivi_esiti, e restituisce l'uscita 0 o 1.
    Precondizione per l'uscita 2."""
    if not os.path.isdir(CARTELLA):
        print(PARTENZA)
        if scrivi_esiti:
            togli_vecchio()
        return 1
    chiamate, mancanti = leggi_tutto()
    stampa(chiamate)
    if mancanti:
        print(NON_ANCORA)
    if scrivi_esiti:
        scrivi(chiamate)
        print("Scritto %s." % ESITI)
    return 1 if mancanti else 0


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
