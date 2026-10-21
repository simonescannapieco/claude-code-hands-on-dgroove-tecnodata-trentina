"""nuovo_codice.py -- il codice della linea di prova di M3-D04, nuovo per
ogni spazio di lavoro.

Scrive, nello spazio di lavoro (la cartella data, o quella corrente):
  frase-da-ricordare.txt  la frase della chat in cui Claude deve ricordare
                          il codice, «Ricordati che il codice della linea
                          di prova del corso è <codice>.»;
  codice.txt              il codice: LP- (linea di prova), quattro lettere
                          maiuscole, un trattino e due cifre (per esempio
                          LP-QZKW-37), estratte con il modulo secrets da un
                          alfabeto senza I e O, che si confondono con 1 e
                          0. È il file che legge controlla_memoria.py, e si
                          scrive per ultimo.
Poi stampa che cosa incollare dove. Il codice non compare nei ticket del
corso: se trova il file dei ticket, progetti/assistenza-clienti/dati/
ticket-settimana.csv, nel repository di PN_HANDSON_ROOT, nello spazio di
lavoro o in una cartella sopra questo script, estrae un altro codice
finché né il codice né le sue lettere e cifre vi compaiono; se il file non
c'è, non controlla. Se codice.txt c'è già non tocca niente: le prove fatte
con quel codice restano valide. Con --nuovo scrive un codice nuovo, e le
tre chat vanno rifatte. Non scrive mai attraverso un collegamento
simbolico.

Uso:    python3 nuovo_codice.py [--nuovo] [<spazio di lavoro>]
          senza cartella, quella corrente
Env:    PN_HANDSON_ROOT  facoltativo: il repository delle esercitazioni,
                         dove cercare il file dei ticket
Uscita: 0 frase-da-ricordare.txt e codice.txt scritti
        2 uso sbagliato; lo spazio di lavoro assente; codice.txt c'è già
          (senza --nuovo); il file dei ticket che c'è ma non si legge;
          nessun codice libero dopo 100 estrazioni; un file che è un
          collegamento simbolico o che non si scrive; un errore inatteso
          (una riga, mai un traceback)
"""
from __future__ import annotations

import os
import secrets
import sys
from typing import List

# Le lettere maiuscole senza I e O, che si confondono con 1 e 0.
LETTERE = "ABCDEFGHJKLMNPQRSTUVWXYZ"
PREFISSO = "LP-"
CODICE = "codice.txt"
FRASE = "frase-da-ricordare.txt"
MODELLO_FRASE = "Ricordati che il codice della linea di prova del corso è %s."
TICKET = os.path.join("progetti", "assistenza-clienti", "dati",
                      "ticket-settimana.csv")
TENTATIVI = 100
GIA = ("codice.txt c'è già: il codice delle vostre prove è lì, e la frase "
       "da mandare in frase-da-ricordare.txt. Per un codice nuovo: python3 "
       "nuovo_codice.py --nuovo, poi rifate le tre chat (e togliete dalla "
       "memoria il codice vecchio).")
USO = "Uso: python3 nuovo_codice.py [--nuovo] [<spazio di lavoro>]\n"


class Precondizione(Exception):
    """Un file che c'è già, un collegamento simbolico, un file che non si
    legge o non si scrive, nessun codice libero: uscita 2."""


def estrai_codice() -> str:
    """LP-, quattro lettere di LETTERE, un trattino e due cifre."""
    lettere = "".join(secrets.choice(LETTERE) for _ in range(4))
    return "%s%s-%02d" % (PREFISSO, lettere, secrets.randbelow(100))


def file_dei_ticket() -> List[str]:
    """I file dei ticket che si trovano, senza doppioni: nel repository di
    PN_HANDSON_ROOT, nella cartella corrente (lo spazio di lavoro) e in
    ogni cartella sopra questo script."""
    cartelle: List[str] = []
    radice = os.environ.get("PN_HANDSON_ROOT", "")
    if radice:
        cartelle.append(radice)
    cartelle.append(os.getcwd())
    qui = os.path.dirname(os.path.abspath(__file__))
    while True:
        cartelle.append(qui)
        sopra = os.path.dirname(qui)
        if sopra == qui:
            break
        qui = sopra
    trovati: List[str] = []
    for cartella in cartelle:
        percorso = os.path.join(cartella, TICKET)
        if os.path.isfile(percorso):
            reale = os.path.realpath(percorso)
            if reale not in trovati:
                trovati.append(reale)
    return trovati


def testi_dei_ticket() -> List[str]:
    """Il testo di ogni file dei ticket che si trova, in maiuscolo;
    Precondizione se uno c'è ma non si legge."""
    testi: List[str] = []
    for percorso in file_dei_ticket():
        try:
            with open(percorso, "rb") as fh:
                testi.append(fh.read().decode("utf-8", errors="replace")
                             .upper())
        except OSError as exc:
            raise Precondizione("il file dei ticket %s c'è ma non si legge "
                                "(%s)" % (percorso, exc.strerror or exc))
    return testi


def compare(codice: str, testi: List[str]) -> bool:
    """Vero se il codice, o la sua parte estratta (le lettere, il trattino
    e le cifre), compare in uno dei testi."""
    nucleo = codice[len(PREFISSO):]
    return any(codice in testo or nucleo in testo for testo in testi)


def scegli(testi: List[str]) -> str:
    """Un codice che non compare nei testi dei ticket; Precondizione dopo
    TENTATIVI estrazioni senza un codice libero."""
    for _ in range(TENTATIVI):
        codice = estrai_codice()
        if not compare(codice, testi):
            return codice
    raise Precondizione("nessun codice libero dopo %d estrazioni: ognuno "
                        "compare nei ticket" % TENTATIVI)


def scrivi(percorso: str, testo: str) -> None:
    """Scrive il testo nel file, in UTF-8 con a capo LF; Precondizione se
    il file non si scrive."""
    try:
        with open(percorso, "w", encoding="utf-8", newline="\n") as fh:
            fh.write(testo)
    except OSError as exc:
        raise Precondizione("%s non si scrive (%s)"
                            % (percorso, exc.strerror or exc))


def istruzioni(codice: str) -> str:
    """Che cosa incollare dove, per le tre chat."""
    return "\n".join([
        "Codice della linea di prova: %s (in %s)." % (codice, CODICE),
        "La frase da mandare nella chat da ricordare, anche in %s:" % FRASE,
        "",
        "    " + MODELLO_FRASE % codice,
        "",
        "Poi due chat nuove, fuori da ogni progetto, con la domanda di",
        "domanda.txt; le risposte vanno in due file:",
        "  con la memoria accesa                  -> risposta-con-memoria.txt",
        "  con «Memory» spenta dal menu «+», prima",
        "  del primo messaggio                    -> "
        "risposta-senza-memoria.txt",
        "Alla fine togliete il codice dalla memoria, in Settings > Memory",
        "(l'ultimo passo del README): cancellare le chat non basta.",
    ])


def genera(nuovo: bool) -> int:
    """frase-da-ricordare.txt e codice.txt nella cartella corrente, lo
    spazio di lavoro, codice.txt per ultimo; stampa le istruzioni.
    Precondizione per l'uscita 2, prima di scrivere qualunque file."""
    if os.path.lexists(CODICE) and not nuovo:
        raise Precondizione(GIA)
    for percorso in (FRASE, CODICE):
        if os.path.islink(percorso):
            raise Precondizione("%s è un collegamento simbolico: non lo "
                                "seguo" % percorso)
    codice = scegli(testi_dei_ticket())
    scrivi(FRASE, MODELLO_FRASE % codice + "\n")
    scrivi(CODICE, codice + "\n")
    print(istruzioni(codice))
    return 0


def errore(messaggio: str) -> int:
    """Il messaggio su STDERR, in una riga; l'uscita 2."""
    sys.stderr.write("nuovo_codice.py: %s\n" % messaggio)
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
    nuovo = False
    posizionali: List[str] = []
    for arg in argv:
        if arg == "--nuovo":
            nuovo = True
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
        return genera(nuovo)
    except Precondizione as exc:
        return errore(str(exc))
    except Exception as exc:  # mai un traceback: un errore inatteso esce 2
        return errore("errore inatteso (%s: %s)"
                      % (type(exc).__name__, " ".join(str(exc).split())))


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
