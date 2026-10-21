"""nuova_parola.py -- la parola in codice di M3-D03, nuova per ogni spazio
di lavoro.

Scrive, nello spazio di lavoro (la cartella data, o quella corrente):
  frase.txt   la frase da incollare nel progetto di prova, «Inizia ogni
              risposta con la parola in codice <parola>.»;
  parola.txt  la parola in codice: una parola di montagna in maiuscolo,
              un trattino e quattro cifre (per esempio GENZIANA-4817),
              estratte con il modulo secrets, così che nessuno la possa
              indovinare. È il file che legge controlla_progetto.py, e si
              scrive per ultimo.
Poi stampa che cosa incollare dove. Se parola.txt c'è già non tocca
niente: le prove fatte con quella parola restano valide. Con --nuova
scrive una parola nuova, e le tre prove vanno rifatte. Non scrive mai
attraverso un collegamento simbolico.

Uso:    python3 nuova_parola.py [--nuova] [<spazio di lavoro>]
          senza cartella, quella corrente
Uscita: 0 frase.txt e parola.txt scritti
        2 uso sbagliato; lo spazio di lavoro assente; parola.txt c'è già
          (senza --nuova); un file che è un collegamento simbolico o che
          non si scrive; un errore inatteso (una riga, mai un traceback)
"""
from __future__ import annotations

import os
import secrets
import sys
from typing import List

# Parole di montagna, senza accenti: con quattro cifre a caso danno una
# parola in codice che nessuno scrive per caso.
PAROLE = ("ABETE", "ARNICA", "BAITA", "CAMOSCIO", "CAMPANULA", "CAPRIOLO",
          "CIRMOLO", "ERMELLINO", "FORCELLA", "GENZIANA", "GHIRO",
          "LARICE", "MALGA", "MARMOTTA", "MIRTILLO", "MUGO", "PERNICE",
          "RODODENDRO", "SASSIFRAGA", "SCOIATTOLO", "STAMBECCO",
          "VEDRETTA")
PAROLA = "parola.txt"
FRASE = "frase.txt"
MODELLO_FRASE = "Inizia ogni risposta con la parola in codice %s."
DESCRIZIONE_NEUTRA = "Progetto di prova del corso"
GIA = ("parola.txt c'è già: la parola delle vostre prove è lì, e la frase "
       "da incollare in frase.txt. Per una parola nuova: python3 "
       "nuova_parola.py --nuova, poi rifate le tre prove.")
USO = "Uso: python3 nuova_parola.py [--nuova] [<spazio di lavoro>]\n"


class Precondizione(Exception):
    """Un file che c'è già, un collegamento simbolico, un file che non si
    scrive: uscita 2."""


def estrai_parola() -> str:
    """Una parola di PAROLE, un trattino e quattro cifre, da 1000 a 9999."""
    return "%s-%d" % (secrets.choice(PAROLE), 1000 + secrets.randbelow(9000))


def scrivi(percorso: str, testo: str) -> None:
    """Scrive il testo nel file, in UTF-8 con a capo LF; Precondizione se
    il file non si scrive."""
    try:
        with open(percorso, "w", encoding="utf-8", newline="\n") as fh:
            fh.write(testo)
    except OSError as exc:
        raise Precondizione("%s non si scrive (%s)"
                            % (percorso, exc.strerror or exc))


def istruzioni(parola: str) -> str:
    """Che cosa incollare dove, per le tre prove."""
    return "\n".join([
        "Parola in codice: %s (in %s)." % (parola, PAROLA),
        "La frase da incollare, anche in %s:" % FRASE,
        "",
        "    " + MODELLO_FRASE % parola,
        "",
        "Dove va, prova per prova (i passi sono nel README):",
        "  A  nella descrizione del progetto di prova, con le istruzioni",
        "     del progetto vuote;",
        "  B  nelle istruzioni del progetto, con la descrizione cambiata in",
        "     «%s»;" % DESCRIZIONE_NEUTRA,
        "  C  da nessuna parte: una chat nuova fuori dal progetto.",
        "Ogni prova è una chat nuova, con «Memory» spenta dal menu «+» prima",
        "del primo messaggio, e la domanda di domanda.txt; le risposte vanno",
        "in risposta-A.txt, risposta-B.txt e risposta-C.txt.",
        "Non scrivete mai la parola in una chat.",
    ])


def genera(nuova: bool) -> int:
    """frase.txt e parola.txt nella cartella corrente, lo spazio di lavoro,
    parola.txt per ultimo; stampa le istruzioni. Precondizione per
    l'uscita 2, prima di scrivere qualunque file."""
    if os.path.lexists(PAROLA) and not nuova:
        raise Precondizione(GIA)
    for percorso in (FRASE, PAROLA):
        if os.path.islink(percorso):
            raise Precondizione("%s è un collegamento simbolico: non lo "
                                "seguo" % percorso)
    parola = estrai_parola()
    scrivi(FRASE, MODELLO_FRASE % parola + "\n")
    scrivi(PAROLA, parola + "\n")
    print(istruzioni(parola))
    return 0


def errore(messaggio: str) -> int:
    """Il messaggio su STDERR, in una riga; l'uscita 2."""
    sys.stderr.write("nuova_parola.py: %s\n" % messaggio)
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
    nuova = False
    posizionali: List[str] = []
    for arg in argv:
        if arg == "--nuova":
            nuova = True
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
        return genera(nuova)
    except Precondizione as exc:
        return errore(str(exc))
    except Exception as exc:  # mai un traceback: un errore inatteso esce 2
        return errore("errore inatteso (%s: %s)"
                      % (type(exc).__name__, " ".join(str(exc).split())))


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
