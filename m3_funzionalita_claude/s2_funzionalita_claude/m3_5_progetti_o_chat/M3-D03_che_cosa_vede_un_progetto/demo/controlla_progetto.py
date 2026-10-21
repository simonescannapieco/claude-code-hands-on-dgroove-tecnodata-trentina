"""controlla_progetto.py -- che cosa vede Claude in un progetto di
claude.ai: tre garanzie di Anthropic alla prova (M3-D03).

Legge, nello spazio di lavoro (la cartella data, o quella corrente),
parola.txt, la parola in codice di nuova_parola.py, e le tre risposte
copiate da claude.ai alla stessa domanda (domanda.txt), ciascuna data in
una chat nuova con la memoria spenta:
  risposta-A.txt  la chat nel progetto di prova, con la frase della parola
                  nella descrizione e le istruzioni vuote;
  risposta-B.txt  una chat nel progetto, con la frase nelle istruzioni e
                  una descrizione neutra;
  risposta-C.txt  una chat fuori dal progetto, con le istruzioni di B
                  ancora impostate.
Di ogni risposta stampa l'inizio, i primi 120 caratteri su una riga, se
contiene la parola e se comincia con la parola. La parola si cerca senza
badare alle maiuscole, al tipo di trattino (anche uno spazio, o niente, al
posto del trattino), ai caratteri invisibili e alle forme larghe dei
caratteri; all'inizio della risposta non contano spazi, asterischi,
trattini bassi, cancelletti, il segno >, i segni di un elenco e le
virgolette. Poi le tre garanzie, ciascuna solo se c'è la sua risposta:
  «Claude non vede la descrizione del progetto» (prova A): confermata se
      la risposta non contiene la parola;
  «Claude usa le istruzioni del progetto in tutte le sue chat» (prova B):
      confermata se la risposta contiene la parola; se comincia con la
      parola, come chiede la frase, si stampa come dato: la frase di
      Anthropic dice che Claude usa le istruzioni, non quanto le segue;
  «Le istruzioni valgono solo per le chat del progetto» (prova C):
      confermata se la risposta non contiene la parola.
Sono garanzie del prodotto: una che non tiene è «non confermata in questa
esecuzione», con la frase che dice che cosa garantisce la documentazione,
e l'uscita è 1. La prova B è anche il controllo delle altre due: se la
risposta B c'è e non contiene la parola, la frase non è arrivata a Claude
nemmeno dalle istruzioni, e allora A e C, se non contengono la parola,
non possono mostrare niente: si stampano «non distinguibile», con il
perché, invece di «confermata» (l'uscita è già 1 per B). Il controllo
legge le risposte e non scrive niente; che cosa dice la risposta sul
guasto non lo giudica.

Uso:    python3 controlla_progetto.py [<spazio di lavoro>]
          senza cartella, quella corrente
Uscita: 0 le tre risposte ci sono e le tre garanzie tengono
        1 parola.txt che manca o è vuoto; una risposta che manca o è vuota
          (le garanzie delle altre si dicono lo stesso); una garanzia che
          non tiene
        2 uso sbagliato; lo spazio di lavoro assente; parola.txt senza la
          forma di nuova_parola.py; un file che non si legge o non è testo
          UTF-8; un errore inatteso (una riga, mai un traceback)
"""
from __future__ import annotations

import os
import re
import sys
import unicodedata
from typing import Dict, List, Optional, Tuple

PAROLA = "parola.txt"
FORMA_PAROLA = re.compile(r"([A-Z]{3,})-([0-9]{4})")
# I trattini che un editor o una pagina mettono al posto di «-»: quelli
# tipografici, il meno, quelli piccoli e quelli larghi.
TRATTINI = "".join(chr(c) for c in (
    0x2D, 0x2010, 0x2011, 0x2012, 0x2013, 0x2014, 0x2015, 0x2212, 0xFE58,
    0xFE63, 0xFF0D))
# Le virgolette che possono aprire una risposta: diritte, inverse,
# caporali, alte e basse.
VIRGOLETTE = "".join(chr(c) for c in (
    0x22, 0x27, 0x60, 0xAB, 0xBB, 0x2018, 0x2019, 0x201A, 0x201C, 0x201D,
    0x201E, 0x2039, 0x203A))
# Ciò che all'inizio della risposta non conta, oltre agli spazi: il
# markdown (grassetto, corsivo, titolo, citazione, elenco) e le virgolette.
DAVANTI = "*_#>+" + TRATTINI + VIRGOLETTE
INIZIO = 120
PROVE = (
    ("A", "risposta-A.txt", "la frase nella descrizione del progetto"),
    ("B", "risposta-B.txt", "la frase nelle istruzioni del progetto"),
    ("C", "risposta-C.txt", "una chat fuori dal progetto"),
)
CONFERMATA = "confermata"
NON_CONFERMATA = "non confermata in questa esecuzione"
NON_DISTINGUIBILE = "non distinguibile"
SENZA_B = ("  Nella prova B la parola non è comparsa: la frase non è arrivata "
           "a Claude nemmeno\n  dalle istruzioni, dove doveva arrivare, e "
           "questa prova non può mostrare\n  che non gli arriva da qui.")
# Per ogni prova: l'affermazione, se la risposta la conferma (da: contiene
# la parola, comincia con la parola) e che cosa garantisce la
# documentazione.
GARANZIE = (
    ("A", "Claude non vede la descrizione del progetto",
     lambda c_e, all_inizio: not c_e,
     "  La documentazione garantisce che Claude non vede la descrizione "
     "del progetto: in questa esecuzione la parola è comparsa."),
    ("B", "Claude usa le istruzioni del progetto in tutte le sue chat",
     lambda c_e, all_inizio: c_e,
     "  La documentazione garantisce che Claude usa le istruzioni in tutte "
     "le chat del progetto: in questa esecuzione la parola non è "
     "comparsa."),
    ("C", "Le istruzioni valgono solo per le chat del progetto",
     lambda c_e, all_inizio: not c_e,
     "  La documentazione garantisce che le istruzioni valgono solo per le "
     "chat del progetto: in questa esecuzione la parola è comparsa fuori "
     "dal progetto."),
)
MANCA_PAROLA = ("Manca parola.txt: lanciate python3 nuova_parola.py nello "
                "spazio di lavoro (i passi sono nel README).")
VUOTA_PAROLA = ("parola.txt è vuoto: lanciate python3 nuova_parola.py "
                "--nuova, poi rifate le tre prove con la frase nuova.")
NON_ANCORA = ("Non ancora: manca almeno una risposta; fate la prova "
              "indicata, copiate la risposta nel suo file e rilanciate il "
              "controllo.")
USO = "Uso: python3 controlla_progetto.py [<spazio di lavoro>]\n"

Esito = Tuple[bool, bool]


class Precondizione(Exception):
    """Un file che non si legge, non è UTF-8 o non ha la forma attesa:
    uscita 2."""


def sino(vero: bool) -> str:
    """sì oppure no."""
    return "sì" if vero else "no"


def normalizza(testo: str) -> str:
    """Il testo in forma NFKC (le forme larghe diventano quelle solite),
    senza i caratteri di formato invisibili (il BOM, gli spazi a larghezza
    zero)."""
    testo = unicodedata.normalize("NFKC", testo)
    return "".join(c for c in testo if unicodedata.category(c) != "Cf")


def leggi(percorso: str) -> Optional[str]:
    """Il testo di un file, normalizzato; None se il file non c'è.
    Precondizione se non si legge o non è testo UTF-8."""
    if not os.path.lexists(percorso):
        return None
    try:
        with open(percorso, "rb") as fh:
            dati = fh.read()
    except OSError as exc:
        raise Precondizione("%s non si legge (%s)"
                            % (percorso, exc.strerror or exc))
    try:
        return normalizza(dati.decode("utf-8"))
    except UnicodeDecodeError:
        raise Precondizione("%s non è testo UTF-8: copiate di nuovo la "
                            "risposta e salvate il file come testo UTF-8"
                            % percorso)


def regola_della(parola: str) -> "re.Pattern[str]":
    """L'espressione che trova la parola in una risposta: il nome e le
    cifre, con in mezzo spazi o trattini di ogni tipo (anche niente), senza
    badare alle maiuscole. Precondizione se la parola non ha la forma di
    nuova_parola.py."""
    forma = FORMA_PAROLA.fullmatch(parola)
    if forma is None:
        raise Precondizione("parola.txt non ha la forma di nuova_parola.py "
                            "(una parola in maiuscolo, un trattino, quattro "
                            "cifre): lanciate python3 nuova_parola.py "
                            "--nuova e rifate le tre prove")
    separatore = "[\\s%s]*" % re.escape(TRATTINI)
    return re.compile(re.escape(forma.group(1)) + separatore
                      + re.escape(forma.group(2)), re.IGNORECASE)


def togli_davanti(testo: str) -> str:
    """La risposta senza ciò che all'inizio non conta: spazi, markdown e
    virgolette."""
    i = 0
    while i < len(testo) and (testo[i].isspace() or testo[i] in DAVANTI):
        i += 1
    return testo[i:]


def esamina(testo: str, regola: "re.Pattern[str]") -> Tuple[Esito, str]:
    """Di una risposta: (se contiene la parola, se comincia con la parola)
    e l'inizio, su una riga."""
    c_e = regola.search(testo) is not None
    all_inizio = regola.match(togli_davanti(testo)) is not None
    riga = " ".join(testo.split())
    if len(riga) > INIZIO:
        riga = riga[:INIZIO] + "…"
    return (c_e, all_inizio), riga


def avviso(messaggio: str) -> None:
    """Una risposta da copiare, su STDERR."""
    sys.stderr.write("controlla_progetto.py: %s\n" % messaggio)


def stampa_verdetti(esiti: Dict[str, Esito]) -> bool:
    """Il verdetto di ogni garanzia di cui c'è la risposta; A e C «non
    distinguibile» invece di «confermata» se la risposta B c'è e non
    contiene la parola. Returns: True se una garanzia non tiene."""
    ko = False
    senza_b = "B" in esiti and not esiti["B"][0]
    for lettera, affermazione, tiene, garanzia in GARANZIE:
        if lettera not in esiti:
            continue
        if tiene(*esiti[lettera]):
            if senza_b and lettera != "B":
                print("%s (prova %s): %s" % (affermazione, lettera,
                                             NON_DISTINGUIBILE))
                print(SENZA_B)
            else:
                print("%s (prova %s): %s" % (affermazione, lettera,
                                             CONFERMATA))
            continue
        print("%s (prova %s): %s" % (affermazione, lettera, NON_CONFERMATA))
        print(garanzia)
        ko = True
    return ko


def controlla() -> int:
    """Il controllo nella cartella corrente, lo spazio di lavoro: legge
    tutti i file prima di stampare, poi stampa i dati e i verdetti e
    restituisce l'uscita 0 o 1. Precondizione per l'uscita 2."""
    testo = leggi(PAROLA)
    if testo is None:
        print(MANCA_PAROLA)
        return 1
    parola = testo.strip().upper()
    if not parola:
        print(VUOTA_PAROLA)
        return 1
    regola = regola_della(parola)
    risposte = [(lettera, percorso, descrizione, leggi(percorso))
                for lettera, percorso, descrizione in PROVE]
    print("Parola in codice: %s" % parola)
    esiti: Dict[str, Esito] = {}
    mancanti = 0
    for lettera, percorso, descrizione, risposta in risposte:
        if risposta is None or not risposta.strip():
            if risposta is None:
                avviso("manca %s: fate la prova %s e copiate nel file la "
                       "risposta di Claude" % (percorso, lettera))
            else:
                avviso("%s è vuoto: copiatevi la risposta di Claude della "
                       "prova %s" % (percorso, lettera))
            mancanti += 1
            continue
        esiti[lettera], riga = esamina(risposta, regola)
        print("Prova %s, %s (%s): «%s»" % (lettera, descrizione, percorso,
                                          riga))
        print("  la parola c'è: %s; all'inizio: %s"
              % (sino(esiti[lettera][0]), sino(esiti[lettera][1])))
    ko = stampa_verdetti(esiti)
    if mancanti:
        print(NON_ANCORA)
    return 1 if mancanti or ko else 0


def errore(messaggio: str) -> int:
    """Il messaggio su STDERR, in una riga; l'uscita 2."""
    sys.stderr.write("controlla_progetto.py: %s\n" % messaggio)
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
    posizionali: List[str] = []
    for arg in argv:
        if arg.startswith("-"):
            return uso("opzione sconosciuta: %s" % arg)
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
        return controlla()
    except Precondizione as exc:
        return errore(str(exc))
    except Exception as exc:  # mai un traceback: un errore inatteso esce 2
        return errore("errore inatteso (%s: %s)"
                      % (type(exc).__name__, " ".join(str(exc).split())))


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
