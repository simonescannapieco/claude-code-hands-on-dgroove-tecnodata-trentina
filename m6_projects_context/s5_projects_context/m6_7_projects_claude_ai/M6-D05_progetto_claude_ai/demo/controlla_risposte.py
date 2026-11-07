"""controlla_risposte.py -- la stessa domanda, in una chat e in un progetto di
claude.ai (M6-D05): che cosa c'è della carta dei servizi nelle due risposte.

È una dimostrazione: legge le due risposte come le avete salvate, non ciò che
è successo su claude.ai, che si guarda sullo schermo. Legge, nello spazio di
lavoro (la cartella data, o quella corrente), carta-servizi.md, la carta che
va nella conoscenza del progetto, e le due risposte alla domanda di
domanda.txt:
  risposte/chat.txt      una chat nuova, fuori dai progetti, con «Memory»
                         spenta prima del primo messaggio e niente allegato;
  risposte/progetto.txt  una chat nuova nel progetto che ha la carta nella
                         conoscenza, anche lei con «Memory» spenta.
Della carta prende gli articoli («## Art. <n> — <titolo>») e le cifre
dell'art. 4, quello che risponde alla domanda («<n> giorni lavorativi»: 5 e
9). Di ogni risposta stampa l'inizio e, come dati: se ha ciascuna cifra, in
cifre o in lettere; se dice «giorni lavorativi»; gli articoli che cita, e per
ciascuno se la carta lo ha e con quale titolo. Poi, come dato, in quale delle
due risposte ci sono tutte le cifre. Nessuna riga decide: ciò che dice
Anthropic si guarda sullo schermo, e qui si legge soltanto il testo copiato.
Il controllo non scrive niente.

Uso:    python3 controlla_risposte.py [<spazio di lavoro>]
          senza cartella, quella corrente
Uscita: 0 le due risposte ci sono e non sono vuote · 1 una risposta che manca
        o è vuota (dice quale) · 2 uso sbagliato, spazio di lavoro assente, la
        carta che manca o senza le cifre dell'art. 4, un file che non si legge
        o non è testo UTF-8, un errore inatteso (una riga, mai un traceback)
"""
from __future__ import annotations

import os
import re
import sys
import unicodedata
from typing import Dict, List, Optional, Tuple

CARTA = "carta-servizi.md"
ARTICOLO = 4
RISPOSTE = (("risposte/chat.txt", "la chat, senza progetto"),
            ("risposte/progetto.txt", "la chat nel progetto con la carta"))
INIZIO = 160
RE_TITOLO = re.compile(r"^##\s+Art\.\s*(\d+)\s*[—–-]\s*(.+?)\s*$", re.M)
RE_CIFRA_CARTA = re.compile(r"(\d+) giorni lavorativi")
RE_CITATO = re.compile(r"\bart(?:icol[oi]|\.)?\s*(\d+)", re.IGNORECASE)
RE_LAVORATIVI = re.compile(r"giorni\s+lavorativi", re.IGNORECASE)
NUMERI = ("zero", "uno", "due", "tre", "quattro", "cinque", "sei", "sette",
          "otto", "nove", "dieci", "undici", "dodici", "tredici",
          "quattordici", "quindici", "sedici", "diciassette", "diciotto",
          "diciannove", "venti")
DIMOSTRAZIONE = ("Dimostrazione: il controllo legge le due risposte come le "
                 "avete salvate; che cosa ha fatto claude.ai si guarda sullo "
                 "schermo.")
NON_ANCORA = ("Non ancora: manca almeno una risposta; fate la chat indicata, "
              "salvate la risposta nel suo file e rilanciate il controllo.")
USO = "Uso: python3 controlla_risposte.py [<spazio di lavoro>]\n"


class Precondizione(Exception):
    """Un file che non si legge, non è UTF-8 o non ha la forma attesa:
    uscita 2."""


def sino(vero: bool) -> str:
    """sì oppure no."""
    return "sì" if vero else "no"


def leggi(percorso: str) -> Optional[str]:
    """Il testo di un file in forma NFKC, senza i caratteri di formato
    invisibili; None se il file non c'è. Precondizione se non si legge o
    non è testo UTF-8."""
    if not os.path.lexists(percorso):
        return None
    try:
        with open(percorso, "rb") as fh:
            dati = fh.read()
    except OSError as exc:
        raise Precondizione("%s non si legge (%s)"
                            % (percorso, exc.strerror or exc)) from exc
    try:
        testo = unicodedata.normalize("NFKC", dati.decode("utf-8"))
    except UnicodeDecodeError as exc:
        raise Precondizione("%s non è testo UTF-8: salvate di nuovo il file "
                            "come testo UTF-8" % percorso) from exc
    return "".join(c for c in testo if unicodedata.category(c) != "Cf")


def leggi_carta() -> Tuple[Dict[int, str], List[int]]:
    """Gli articoli della carta, numero e titolo, e le cifre dell'art. 4.
    Precondizione se la carta manca o non ha le cifre."""
    testo = leggi(CARTA)
    if testo is None:
        raise Precondizione("manca %s: lo spazio di lavoro non è quello di "
                            "partenza (tools/reset_esercizio.sh M6-D05)"
                            % CARTA)
    titoli = {int(m.group(1)): m.group(2) for m in RE_TITOLO.finditer(testo)}
    inizio = next((m.end() for m in RE_TITOLO.finditer(testo)
                   if int(m.group(1)) == ARTICOLO), None)
    if inizio is None:
        raise Precondizione("%s non ha l'art. %d" % (CARTA, ARTICOLO))
    corpo = testo[inizio:].split("\n## ", 1)[0]
    cifre: List[int] = []
    for cifra in RE_CIFRA_CARTA.findall(corpo):
        if int(cifra) not in cifre:
            cifre.append(int(cifra))
    if not cifre:
        raise Precondizione("%s: l'art. %d non ha «giorni lavorativi»"
                            % (CARTA, ARTICOLO))
    return titoli, cifre


def ha_cifra(testo: str, cifra: int) -> bool:
    """Vero se la risposta ha la cifra, da sola o in lettere."""
    if re.search(r"(?<![\d.,])%d(?![\d])" % cifra, testo):
        return True
    return cifra < len(NUMERI) and re.search(
        r"\b%s\b" % NUMERI[cifra], testo, re.IGNORECASE) is not None


def citati(testo: str) -> List[int]:
    """Gli articoli che la risposta cita, nell'ordine, ciascuno una volta."""
    numeri: List[int] = []
    for numero in RE_CITATO.findall(testo):
        if int(numero) not in numeri:
            numeri.append(int(numero))
    return numeri


def una_riga(testo: str) -> str:
    """L'inizio della risposta, su una riga."""
    riga = " ".join(testo.split())
    return riga if len(riga) <= INIZIO else riga[:INIZIO] + "…"


def esamina(testo: str, titoli: Dict[int, str], cifre: List[int]) -> bool:
    """Stampa i dati di una risposta. Returns: vero se ha tutte le cifre."""
    trovate = [(c, ha_cifra(testo, c)) for c in cifre]
    print("  (dato) le cifre dell'art. %d: %s; «giorni lavorativi»: %s" % (
        ARTICOLO, "; ".join("%d: %s" % (c, sino(v)) for c, v in trovate),
        sino(RE_LAVORATIVI.search(testo) is not None)))
    voci = []
    for numero in citati(testo):
        titolo = titoli.get(numero)
        voci.append("art. %d, nella carta: %s" % (
            numero, "«%s»" % titolo if titolo else "no"))
    print("  (dato) gli articoli citati: %s" % ("; ".join(voci) or "nessuno"))
    return all(v for _, v in trovate)


def controlla() -> int:
    """Il controllo nella cartella corrente: legge tutti i file prima di
    stampare, poi i dati. Returns: 0 o 1. Precondizione per l'uscita 2."""
    titoli, cifre = leggi_carta()
    risposte = [(p, d, leggi(p)) for p, d in RISPOSTE]
    print(DIMOSTRAZIONE)
    print()
    print("La carta, %s: %d articoli; l'art. %d, «%s», dice %s giorni "
          "lavorativi." % (CARTA, len(titoli), ARTICOLO,
                           titoli.get(ARTICOLO, ""),
                           " e ".join(str(c) for c in cifre)))
    complete: List[Tuple[str, bool]] = []
    mancanti = 0
    for percorso, descrizione, testo in risposte:
        if testo is None or not testo.strip():
            sys.stderr.write("controlla_risposte.py: %s %s: salvatevi la "
                             "risposta (%s)\n" % (
                                 percorso, "manca" if testo is None
                                 else "è vuoto", descrizione))
            mancanti += 1
            continue
        print("%s, %s: «%s»" % (percorso, descrizione, una_riga(testo)))
        complete.append((descrizione, esamina(testo, titoli, cifre)))
    if len(complete) == len(RISPOSTE):
        print("\n(dato) tutte le cifre dell'art. %d: %s" % (
            ARTICOLO, "; ".join("%s: %s" % (d, sino(v))
                                for d, v in complete)))
    if mancanti:
        print(NON_ANCORA)
        return 1
    return 0


def errore(messaggio: str) -> int:
    """Il messaggio su STDERR, in una riga; l'uscita 2."""
    sys.stderr.write("controlla_risposte.py: %s\n"
                     % " ".join(messaggio.split()))
    return 2


def main(argv: List[str]) -> int:
    for flusso in (sys.stdout, sys.stderr):
        riconfigura = getattr(flusso, "reconfigure", None)
        if riconfigura is not None:
            riconfigura(errors="replace")
    posizionali = [a for a in argv if not a.startswith("-")]
    if len(posizionali) != len(argv) or len(posizionali) > 1:
        errore("argomenti non validi: %s" % " ".join(argv))
        sys.stderr.write(USO)
        return 2
    ws = posizionali[0] if posizionali else "."
    if not os.path.isdir(ws):
        return errore("spazio di lavoro assente: %s" % ws)
    try:
        os.chdir(ws)
        return controlla()
    except Precondizione as exc:
        return errore(str(exc))
    except Exception as exc:  # pylint: disable=broad-except
        return errore("errore inatteso (%s: %s)" % (type(exc).__name__, exc))


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
