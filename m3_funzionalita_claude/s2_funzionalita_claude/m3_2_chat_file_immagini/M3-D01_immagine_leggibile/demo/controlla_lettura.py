"""controlla_lettura.py -- che cosa ha letto Claude nelle due immagini di
M3-D01, e tre affermazioni di Anthropic alla prova.

Legge, nello spazio di lavoro (la cartella data, o quella corrente),
risposte/<grandezza>-<modello>-<n>.json: il JSON di `claude -p
--output-format json` di dodici chiamate con lo stesso prompt, sulla stessa
tabella di allarmi grande (allarmi.png, 1600×1000) e piccola
(allarmi-piccola.png, 160×100), su haiku e su sonnet, tre volte ciascuna
(n = 1, 2, 3). La verità è in verita.json. Di ogni risposta legge il testo
(«result») e cerca le due righe che il prompt chiede, «critici: N» e
«apparati: …», senza badare alle maiuscole, agli spazi, agli elenchi
puntati e al grassetto di Markdown; oppure «non leggibile». Stampa che
cosa ha letto e se è giusto; poi, per ogni modello, i verdetti e il
riepilogo «confermata n su 3»:
  «Testo leggibile, immagine grande»: due raccomandazioni messe alla prova
      insieme (il testo importante leggibile e non troppo piccolo; immagini
      di almeno 1000×1000 pixel), confrontando ogni coppia, la chiamata n
      sull'immagine grande con la n sulla piccola: confermata se la grande
      dà giusti tutti e due i valori e la piccola no; non distinguibile se
      li danno giusti tutte e due, o nessuna delle due; non confermata in
      questa esecuzione se li dà giusti la piccola e non la grande;
  «Sotto i 200 pixel, Claude può sbagliare»: un «può», su ogni chiamata
      sull'immagine piccola: confermata se la risposta dà un valore
      sbagliato; una risposta che dice «non leggibile» si stampa come un
      rifiuto e non la conferma, come una risposta giusta o senza le due
      righe: non confermata in questa esecuzione. Mai «smentita»: una sola
      esecuzione non smentisce un «può».
I verdetti si stampano e non decidono l'uscita: sono due raccomandazioni e
un «può». Senza --senza-esiti scrive anche esiti.tsv, una riga per file:
  lettura           valori, non leggibile, oppure senza le due righe
  critici           il numero letto (— se manca)
  apparati          i nomi letti, separati da virgola (— se mancano)
  critici_giusti, apparati_giusti   sì, no, oppure — se il valore manca

Uso:    python3 controlla_lettura.py [--senza-esiti] [<spazio di lavoro>]
          senza cartella, quella corrente; con --senza-esiti non scrive e
          non toglie esiti.tsv (lo usa verifica.sh, che non cambia niente)
Uscita: 0 le dodici risposte ci sono e si leggono (i verdetti non decidono
          l'uscita)
        1 manca la cartella risposte/ (nessun esiti.tsv: uno vecchio viene
          tolto), oppure una risposta manca o non è il JSON riuscito di
          claude -p; esiti.tsv ha le righe delle risposte che ci sono
        2 uso sbagliato; lo spazio di lavoro assente; verita.json assente,
          illeggibile o non valido; una risposta che non si legge;
          esiti.tsv che non si scrive; un errore inatteso (una riga, mai un
          traceback): nessun esiti.tsv resta (uno vecchio viene tolto)
"""
from __future__ import annotations

import json
import os
import re
import sys
from typing import Dict, List, NamedTuple, Optional, Tuple

MODELLI = ("haiku", "sonnet")
GRANDEZZE = ("grande", "piccola")
ESECUZIONI = (1, 2, 3)
CARTELLA = "risposte"
VERITA = "verita.json"
ESITI = "esiti.tsv"
INTESTAZIONE = ["file", "modello", "immagine", "esecuzione", "lettura",
                "critici", "apparati", "critici_giusti", "apparati_giusti"]
NA = "—"
VALORI = "valori"
RIFIUTO = "non leggibile"
SENZA_FORMA = "senza le due righe"
S_LEGGIBILE = "Testo leggibile, immagine grande"
S_PICCOLA = "Sotto i 200 pixel, Claude può sbagliare"
CONFERMATA = "confermata"
NON_CONFERMATA = "non confermata in questa esecuzione"
NON_DISTINGUIBILE = "non distinguibile"
PARTENZA = "Manca la cartella risposte/: eseguite i passi del README."
NON_ANCORA = ("Non ancora: una risposta manca o non è il JSON riuscito di "
              "claude -p; rifate la chiamata indicata sopra, poi rilanciate "
              "il controllo.")
USO = ("Uso: python3 controlla_lettura.py [--senza-esiti] "
       "[<spazio di lavoro>]\n")
# Un segno di elenco davanti alla riga: -, *, +, •, >, oppure «1.» o «1)».
PUNTO = re.compile(r"^\s*(?:[-+•>]+|\d+[.)])\s*")
RIGA = re.compile(r"^(critici|apparati)\s*[:=]\s*(.*)$", re.IGNORECASE)
SEPARATORI = re.compile(r"\s*,\s*|\s*;\s*|\s+e\s+|\s+and\s+")
PARENTESI = re.compile(r"\s*\([^)]*\)")
CIFRE = re.compile(r"\d+")
PAROLE = re.compile(r"[a-z]+")
NUMERI = {"zero": 0, "uno": 1, "una": 1, "due": 2, "tre": 3, "quattro": 4,
          "cinque": 5, "sei": 6, "sette": 7, "otto": 8, "nove": 9,
          "dieci": 10}
NESSUNO = ("", "nessuno", "nessun apparato")


class Precondizione(Exception):
    """Un file d'ingresso che manca, non si legge o non va: uscita 2."""


class Mancante(Exception):
    """Una risposta che manca o non è il JSON riuscito di claude -p:
    uscita 1."""


class Verita(NamedTuple):
    """La verità di verita.json: quanti allarmi critici, e di quali
    apparati (in minuscolo)."""
    critici: int
    apparati: Tuple[str, ...]


class Lettura(NamedTuple):
    """Che cosa dice una risposta: il tipo (VALORI, RIFIUTO o
    SENZA_FORMA), il numero e i nomi letti (None se la riga manca o non si
    legge), il testo intero."""
    tipo: str
    critici: Optional[int]
    apparati: Optional[Tuple[str, ...]]
    testo: str


class Giudizio(NamedTuple):
    """Ogni valore letto confrontato con la verità: True giusto, False
    sbagliato, None se il valore manca."""
    critici: Optional[bool]
    apparati: Optional[bool]


Letture = Dict[Tuple[str, str, int], Tuple[Lettura, Giudizio]]


def compatta(testo: str) -> str:
    """Il testo su una riga sola: ogni sequenza di spazi, a capo e
    tabulazioni diventa uno spazio."""
    return " ".join(testo.split())


def taglia(testo: str, quanti: int) -> str:
    """Il testo, al massimo quanti caratteri, con «…» se è tagliato."""
    return testo if len(testo) <= quanti else testo[:quanti - 1] + "…"


def sino(valore: Optional[bool]) -> str:
    """sì, no, oppure — se il valore manca."""
    if valore is None:
        return NA
    return "sì" if valore else "no"


def leggi_verita() -> Verita:
    """verita.json; Precondizione se manca, non si legge o non va."""
    try:
        with open(VERITA, encoding="utf-8") as fh:
            doc = json.load(fh)
    except FileNotFoundError:
        raise Precondizione("manca %s nello spazio di lavoro" % VERITA)
    except (OSError, ValueError, RecursionError) as exc:
        raise Precondizione("%s non si legge (%s)" % (VERITA, exc))
    critici = doc.get("critici") if isinstance(doc, dict) else None
    apparati = doc.get("apparati") if isinstance(doc, dict) else None
    if (not isinstance(critici, int) or isinstance(critici, bool)
            or critici < 0 or not isinstance(apparati, list)
            or not all(isinstance(a, str) and a.strip() for a in apparati)):
        raise Precondizione("%s: attesi «critici», un intero, e "
                            "«apparati», un elenco di nomi" % VERITA)
    return Verita(critici, tuple(a.strip().casefold() for a in apparati))


def pulisci(riga: str) -> str:
    """Una riga senza il grassetto, il corsivo e il codice di Markdown e
    senza il segno di un elenco davanti."""
    for segno in ("**", "__", "`", "*"):
        riga = riga.replace(segno, "")
    return PUNTO.sub("", riga.strip(), count=1).strip()


def numero(valore: str) -> Optional[int]:
    """Il numero di un valore «critici»: le cifre, o una parola da zero a
    dieci; None se non c'è o se il valore dice «non leggibile»."""
    basso = valore.casefold()
    if RIFIUTO in basso:
        return None
    cifre = CIFRE.search(basso)
    if cifre:
        return int(cifre.group())
    for parola in PAROLE.findall(basso):
        if parola in NUMERI:
            return NUMERI[parola]
    return None


def nomi(valore: str) -> Optional[Tuple[str, ...]]:
    """I nomi di un valore «apparati», in minuscolo, nell'ordine in cui
    sono scritti, senza le note fra parentesi; () per «nessuno»; None se
    il valore dice «non leggibile»."""
    basso = PARENTESI.sub("", valore.casefold()).strip()
    if RIFIUTO in basso:
        return None
    if basso.strip(" .-—") in NESSUNO:
        return ()
    voci = [v.strip(" \t«»\"'.:") for v in SEPARATORI.split(basso)]
    return tuple(v for v in voci if v)


def leggi_lettura(testo: str) -> Lettura:
    """Le due righe di una risposta, oppure un rifiuto, oppure niente."""
    trovate: Dict[str, str] = {}
    for riga in testo.splitlines():
        trovata = RIGA.match(pulisci(riga))
        if trovata and trovata.group(1).casefold() not in trovate:
            trovate[trovata.group(1).casefold()] = trovata.group(2)
    critici = numero(trovate["critici"]) if "critici" in trovate else None
    apparati = nomi(trovate["apparati"]) if "apparati" in trovate else None
    if critici is not None or apparati is not None:
        return Lettura(VALORI, critici, apparati, testo)
    if RIFIUTO in compatta(testo).casefold():
        return Lettura(RIFIUTO, None, None, testo)
    return Lettura(SENZA_FORMA, None, None, testo)


def giudica(lettura: Lettura, verita: Verita) -> Giudizio:
    """Ogni valore letto confrontato con la verità; i nomi come insieme,
    in qualunque ordine."""
    critici = (None if lettura.critici is None
               else lettura.critici == verita.critici)
    apparati = (None if lettura.apparati is None
                else set(lettura.apparati) == set(verita.apparati))
    return Giudizio(critici, apparati)


def giusta(giudizio: Giudizio) -> bool:
    """Vero se la risposta dà giusti tutti e due i valori."""
    return giudizio.critici is True and giudizio.apparati is True


def sbagliata(giudizio: Giudizio) -> bool:
    """Vero se la risposta dà almeno un valore sbagliato."""
    return giudizio.critici is False or giudizio.apparati is False


def leggi_risposta(percorso: str) -> str:
    """Il testo («result») del JSON di claude -p in un file di risposte/.
    Mancante se manca o non è una chiamata riuscita; Precondizione se non
    si legge."""
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
    if doc.get("is_error") or doc.get("subtype", "success") != "success":
        raise Mancante("%s: claude ha restituito un errore; rifate quella "
                       "chiamata" % percorso)
    risultato = doc.get("result")
    if not isinstance(risultato, str) or not risultato.strip():
        raise Mancante("%s: manca la risposta («result»); rifate quella "
                       "chiamata" % percorso)
    return risultato


def avviso(messaggio: str) -> None:
    """Una risposta da rifare, o un errore, su STDERR."""
    sys.stderr.write("controlla_lettura.py: %s\n" % messaggio)


def leggi_tutto(verita: Verita) -> Tuple[Letture, int]:
    """Le letture delle risposte che ci sono, e quante mancano o non
    vanno, ciascuna detta su STDERR."""
    letture: Letture = {}
    mancanti = 0
    for modello in MODELLI:
        for n in ESECUZIONI:
            for grandezza in GRANDEZZE:
                percorso = "%s/%s-%s-%d.json" % (CARTELLA, grandezza,
                                                 modello, n)
                try:
                    lettura = leggi_lettura(leggi_risposta(percorso))
                except Mancante as exc:
                    avviso(str(exc))
                    mancanti += 1
                    continue
                letture[(modello, grandezza, n)] = (
                    lettura, giudica(lettura, verita))
    return letture, mancanti


def esito(valore: Optional[bool], giusto: str, sbagliato: str) -> str:
    """Il giudizio di un valore, in parole."""
    if valore is None:
        return "manca"
    return giusto if valore else sbagliato


def dati(modello: str, grandezza: str, n: int, lettura: Lettura,
         giudizio: Giudizio) -> str:
    """La riga dei dati di una risposta: che cosa ha letto, e se è
    giusto."""
    testa = "%s, %s, %d: " % (modello, grandezza, n)
    if lettura.tipo == RIFIUTO:
        return testa + "non leggibile (un rifiuto: nessun valore letto)"
    if lettura.tipo == SENZA_FORMA:
        return testa + "senza le due righe: «%s»" % taglia(
            compatta(lettura.testo), 160)
    critici = NA if lettura.critici is None else str(lettura.critici)
    if lettura.apparati is None:
        apparati = NA
    else:
        apparati = ", ".join(lettura.apparati) or "nessuno"
    return testa + "critici %s (%s); apparati %s (%s)" % (
        critici, esito(giudizio.critici, "giusto", "sbagliato"), apparati,
        esito(giudizio.apparati, "giusti", "sbagliati"))


def verdetto_coppia(grande: Giudizio, piccola: Giudizio) -> str:
    """Le due raccomandazioni su una coppia: la grande letta giusta e la
    piccola no le conferma."""
    sulla_grande, sulla_piccola = giusta(grande), giusta(piccola)
    if sulla_grande and not sulla_piccola:
        return CONFERMATA
    if sulla_grande:
        return NON_DISTINGUIBILE + " (lette giuste tutte e due)"
    if not sulla_piccola:
        return NON_DISTINGUIBILE + " (nessuna delle due letta giusta)"
    return NON_CONFERMATA + " (letta giusta la piccola, non la grande)"


def verdetto_piccola(lettura: Lettura, giudizio: Giudizio) -> str:
    """Il «può» su una chiamata sull'immagine piccola: un valore
    sbagliato lo conferma; un rifiuto non è un errore."""
    if lettura.tipo == RIFIUTO:
        return NON_CONFERMATA + (" (la risposta dice «non leggibile»: un "
                                 "rifiuto, non un errore)")
    if lettura.tipo == SENZA_FORMA:
        return NON_CONFERMATA + " (la risposta non ha le due righe)"
    if sbagliata(giudizio):
        return CONFERMATA
    return NON_CONFERMATA + " (nessun valore sbagliato)"


def stampa_modello(modello: str, letture: Letture) -> None:
    """I dati delle risposte di un modello, poi i suoi verdetti e i due
    riepiloghi: ogni verdetto solo se ci sono le risposte che lo
    decidono."""
    for n in ESECUZIONI:
        for grandezza in GRANDEZZE:
            voce = letture.get((modello, grandezza, n))
            if voce is not None:
                print(dati(modello, grandezza, n, *voce))
    coppie, piccole = [], []
    for n in ESECUZIONI:
        grande = letture.get((modello, "grande", n))
        piccola = letture.get((modello, "piccola", n))
        if grande is not None and piccola is not None:
            coppie.append(verdetto_coppia(grande[1], piccola[1]))
            print("%s (%s, coppia %d): %s" % (S_LEGGIBILE, modello, n,
                                             coppie[-1]))
    for n in ESECUZIONI:
        piccola = letture.get((modello, "piccola", n))
        if piccola is not None:
            piccole.append(verdetto_piccola(*piccola))
            print("%s (%s, piccola %d): %s" % (S_PICCOLA, modello, n,
                                              piccole[-1]))
    for nome, esiti in ((S_LEGGIBILE, coppie), (S_PICCOLA, piccole)):
        if esiti:
            print("%s (%s): %s %d su %d" % (nome, modello, CONFERMATA,
                                            esiti.count(CONFERMATA),
                                            len(esiti)))


def riga_esiti(chiave: Tuple[str, str, int], lettura: Lettura,
               giudizio: Giudizio) -> List[str]:
    """La riga di esiti.tsv di una risposta."""
    modello, grandezza, n = chiave
    critici = NA if lettura.critici is None else str(lettura.critici)
    apparati = NA if lettura.apparati is None else (
        ", ".join(lettura.apparati) or "nessuno")
    return ["%s-%s-%d.json" % (grandezza, modello, n), modello, grandezza,
            str(n), lettura.tipo, critici, compatta(apparati),
            sino(giudizio.critici), sino(giudizio.apparati)]


def scrivi(letture: Letture) -> None:
    """esiti.tsv: l'intestazione e una riga per risposta che c'è,
    nell'ordine dei modelli, delle esecuzioni e delle grandezze."""
    righe = ["\t".join(INTESTAZIONE)]
    for modello in MODELLI:
        for n in ESECUZIONI:
            for grandezza in GRANDEZZE:
                voce = letture.get((modello, grandezza, n))
                if voce is not None:
                    righe.append("\t".join(riga_esiti(
                        (modello, grandezza, n), *voce)))
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
    verita = leggi_verita()
    if not os.path.isdir(CARTELLA):
        print(PARTENZA)
        if scrivi_esiti:
            togli_vecchio()
        return 1
    letture, mancanti = leggi_tutto(verita)
    for modello in MODELLI:
        stampa_modello(modello, letture)
    if mancanti:
        print(NON_ANCORA)
    if scrivi_esiti:
        scrivi(letture)
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
