"""controlla_memoria.py -- una chat con la memoria e una senza: due
affermazioni di Anthropic sulla memoria di claude.ai alla prova (M3-D04).

Legge, nello spazio di lavoro (la cartella data, o quella corrente),
codice.txt, il codice di nuovo_codice.py, e le due risposte copiate da
claude.ai alla stessa domanda (domanda.txt), date in due chat nuove che
differiscono soltanto per la memoria:
  risposta-con-memoria.txt    la chat con la memoria accesa;
  risposta-senza-memoria.txt  la chat con «Memory» spenta dal menu «+»
                              prima del primo messaggio.
Di ogni risposta stampa l'inizio, i primi 120 caratteri su una riga, se
contiene il codice e, come dato, se contiene «NON LO SO». Il codice si
cerca senza badare alle maiuscole, al tipo di trattino (anche uno spazio,
o niente, al posto del trattino), ai caratteri invisibili e alle forme
larghe dei caratteri, con o senza il prefisso LP-: basta la parte estratta
a caso, le quattro lettere e le due cifre. Poi le due affermazioni,
ciascuna solo se c'è la sua risposta:
  «Claude può ricordare il contesto delle chat e portarlo nelle
      conversazioni nuove», un «può»: confermata se la risposta con la
      memoria contiene il codice, altrimenti non confermata in questa
      esecuzione. Una sola esecuzione non decide un «può»: l'esito si
      stampa e non decide l'uscita. Il codice può tornare dalla memoria o
      dalla ricerca nelle chat passate: nella chat senza memoria sono
      spente tutte e due;
  «In una chat senza memoria Claude non usa la memoria e non cerca nelle
      chat passate», una garanzia: confermata se la risposta senza memoria
      non contiene il codice; se lo contiene è «non confermata in questa
      esecuzione», con la frase che dice che cosa garantisce la
      documentazione, e l'uscita è 1. La chat con la memoria è anche il
      controllo di questa: se la sua risposta c'è e non contiene il
      codice, il codice non è arrivato alla memoria, e una risposta senza
      memoria che non lo contiene non può mostrare niente: si stampa «non
      distinguibile», con il perché, invece di «confermata» (l'uscita non
      cambia).
Che la risposta dica «NON LO SO» è un dato: il controllo non lo giudica.
Il controllo legge le risposte e non scrive niente.

Uso:    python3 controlla_memoria.py [<spazio di lavoro>]
          senza cartella, quella corrente
Uscita: 0 le due risposte ci sono e la garanzia tiene (l'esito del «può»
          non conta)
        1 codice.txt che manca o è vuoto; una risposta che manca o è vuota
          (l'affermazione dell'altra si dice lo stesso); la garanzia che
          non tiene
        2 uso sbagliato; lo spazio di lavoro assente; codice.txt senza la
          forma di nuovo_codice.py; un file che non si legge o non è testo
          UTF-8; un errore inatteso (una riga, mai un traceback)
"""
from __future__ import annotations

import os
import re
import sys
import unicodedata
from typing import Dict, List, Optional, Tuple

CODICE = "codice.txt"
FORMA_CODICE = re.compile(r"LP-([A-Z]{4})-([0-9]{2})")
# I trattini che un editor o una pagina mettono al posto di «-»: quelli
# tipografici, il meno, quelli piccoli e quelli larghi.
TRATTINI = "".join(chr(c) for c in (
    0x2D, 0x2010, 0x2011, 0x2012, 0x2013, 0x2014, 0x2015, 0x2212, 0xFE58,
    0xFE63, 0xFF0D))
NON_LO_SO = re.compile(r"\bnon\s+lo\s+so\b", re.IGNORECASE)
INIZIO = 120
CON = "con"
SENZA = "senza"
CHAT = (
    (CON, "risposta-con-memoria.txt", "Chat con la memoria"),
    (SENZA, "risposta-senza-memoria.txt", "Chat senza memoria"),
)
S_CON = ("Claude può ricordare il contesto delle chat e portarlo nelle "
         "conversazioni nuove (chat con la memoria)")
S_SENZA = ("In una chat senza memoria Claude non usa la memoria e non cerca "
           "nelle chat passate (chat senza memoria)")
CONFERMATA = "confermata"
NON_CONFERMATA = "non confermata in questa esecuzione"
NON_DISTINGUIBILE = "non distinguibile"
SENZA_CON = ("  Nella chat con la memoria il codice non è comparso: non è "
             "arrivato alla memoria,\n  e la chat senza memoria non può "
             "mostrare che da lì non arriva.")
PUO = ("  È un «può»: l'esito di una sola esecuzione si stampa e non fa "
       "fallire la verifica.")
DA_DOVE = ("  Il codice può tornare dalla memoria o dalla ricerca nelle chat "
           "passate; nella chat senza memoria sono spente tutte e due.")
TOPICS = ("  In Settings > Memory, sotto «Topics», vedete se il codice è "
          "stato salvato.")
GARANZIA = ("  La documentazione garantisce che in una chat con la memoria "
            "spenta Claude non usa la memoria e non cerca nelle chat "
            "passate: in questa esecuzione il codice è comparso.")
MANCA_CODICE = ("Manca codice.txt: lanciate python3 nuovo_codice.py nello "
                "spazio di lavoro (i passi sono nel README).")
VUOTO_CODICE = ("codice.txt è vuoto: lanciate python3 nuovo_codice.py "
                "--nuovo, poi rifate le tre chat con la frase nuova.")
NON_ANCORA = ("Non ancora: manca almeno una risposta; fate la chat "
              "indicata, copiate la risposta nel suo file e rilanciate il "
              "controllo.")
USO = "Uso: python3 controlla_memoria.py [<spazio di lavoro>]\n"

# Di una risposta: (contiene il codice, contiene «NON LO SO»).
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


def regola_del(codice: str) -> "re.Pattern[str]":
    """L'espressione che trova il codice in una risposta: le quattro
    lettere e le due cifre, con in mezzo spazi o trattini di ogni tipo
    (anche niente), con o senza il prefisso, senza badare alle maiuscole.
    Precondizione se il codice non ha la forma di nuovo_codice.py."""
    forma = FORMA_CODICE.fullmatch(codice)
    if forma is None:
        raise Precondizione("codice.txt non ha la forma di nuovo_codice.py "
                            "(LP-, quattro lettere, un trattino, due "
                            "cifre): lanciate python3 nuovo_codice.py "
                            "--nuovo e rifate le tre chat")
    separatore = "[\\s%s]*" % re.escape(TRATTINI)
    return re.compile(re.escape(forma.group(1)) + separatore
                      + re.escape(forma.group(2)), re.IGNORECASE)


def esamina(testo: str, regola: "re.Pattern[str]") -> Tuple[Esito, str]:
    """Di una risposta: (se contiene il codice, se contiene «NON LO SO») e
    l'inizio, su una riga."""
    esito = (regola.search(testo) is not None,
             NON_LO_SO.search(testo) is not None)
    riga = " ".join(testo.split())
    if len(riga) > INIZIO:
        riga = riga[:INIZIO] + "…"
    return esito, riga


def avviso(messaggio: str) -> None:
    """Una risposta da copiare, su STDERR."""
    sys.stderr.write("controlla_memoria.py: %s\n" % messaggio)


def stampa_verdetti(esiti: Dict[str, Esito]) -> bool:
    """Il verdetto di ogni affermazione di cui c'è la risposta: il «può»
    della chat con la memoria, poi la garanzia della chat senza («non
    distinguibile» invece di «confermata» se la risposta con la memoria
    c'è e non contiene il codice). Returns: True se la garanzia non
    tiene."""
    if CON in esiti:
        if esiti[CON][0]:
            print("%s: %s" % (S_CON, CONFERMATA))
            print(DA_DOVE)
        else:
            print("%s: %s" % (S_CON, NON_CONFERMATA))
            print(TOPICS)
        print(PUO)
    if SENZA not in esiti:
        return False
    if not esiti[SENZA][0]:
        if CON in esiti and not esiti[CON][0]:
            print("%s: %s" % (S_SENZA, NON_DISTINGUIBILE))
            print(SENZA_CON)
        else:
            print("%s: %s" % (S_SENZA, CONFERMATA))
        return False
    print("%s: %s" % (S_SENZA, NON_CONFERMATA))
    print(GARANZIA)
    return True


def controlla() -> int:
    """Il controllo nella cartella corrente, lo spazio di lavoro: legge
    tutti i file prima di stampare, poi stampa i dati e i verdetti e
    restituisce l'uscita 0 o 1. Precondizione per l'uscita 2."""
    testo = leggi(CODICE)
    if testo is None:
        print(MANCA_CODICE)
        return 1
    codice = testo.strip().upper()
    if not codice:
        print(VUOTO_CODICE)
        return 1
    regola = regola_del(codice)
    risposte = [(chiave, percorso, nome, leggi(percorso))
                for chiave, percorso, nome in CHAT]
    print("Codice della linea di prova: %s" % codice)
    esiti: Dict[str, Esito] = {}
    mancanti = 0
    for chiave, percorso, nome, risposta in risposte:
        if risposta is None or not risposta.strip():
            if risposta is None:
                avviso("manca %s: fate la %s e copiate nel file la "
                       "risposta di Claude" % (percorso, nome.lower()))
            else:
                avviso("%s è vuoto: copiatevi la risposta di Claude della "
                       "%s" % (percorso, nome.lower()))
            mancanti += 1
            continue
        esiti[chiave], riga = esamina(risposta, regola)
        print("%s (%s): «%s»" % (nome, percorso, riga))
        print("  il codice c'è: %s; NON LO SO: %s"
              % (sino(esiti[chiave][0]), sino(esiti[chiave][1])))
    ko = stampa_verdetti(esiti)
    if mancanti:
        print(NON_ANCORA)
    return 1 if mancanti or ko else 0


def errore(messaggio: str) -> int:
    """Il messaggio su STDERR, in una riga; l'uscita 2."""
    sys.stderr.write("controlla_memoria.py: %s\n" % messaggio)
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
