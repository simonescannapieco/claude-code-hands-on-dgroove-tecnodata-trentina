#!/usr/bin/env python3
"""I controlli di M1-D01, la prossima parola; li lancia verifica.sh,
accanto.

Legge risultati.tsv dello spazio di lavoro: l'intestazione
«modello<TAB>parola», poi una riga per chiamata, come la scrivono i passi
del README e _docente/live.sh. Per ciascuno dei tre modelli (haiku, sonnet,
opus) conta le risposte, le parole diverse e le risposte fatte di una
parola sola senza punteggiatura (soltanto lettere). Le risposte si
confrontano senza gli spazi in testa e in coda; una riga senza risposta non
conta; le righe di altri modelli si contano a parte e si ignorano. Una riga
senza tabulazione continua la risposta della riga di sopra (il printf del
passo 3 scrive così una risposta di più righe): prima di ogni controllo le
righe si uniscono con uno spazio, così una risposta di più righe non si
legge come la sua prima riga. Quante righe sono state unite si stampa.

Poi, per ogni modello con almeno una risposta, un verdetto su ciascuna
delle due affermazioni di Anthropic che la demo mette alla prova:
1. «input identici possono produrre output diversi» (il glossario):
   confermata se il modello ha dato almeno due parole diverse, altrimenti
   non dimostrata in questa esecuzione. Un «possono» non si smentisce: lo
   dimostra soltanto una parola diversa.
2. «Claude risponde bene a istruzioni chiare ed esplicite» (la guida al
   prompting), sulla richiesta dell'istruzione di sistema, una parola sola
   senza punteggiatura: confermata se lo sono tutte le risposte del
   modello, altrimenti non confermata in questa esecuzione. È una
   raccomandazione: si stampa, e la verifica non fallisce per questa.

Scritto per il python3 dei partecipanti, dalla 3.8 in su.

Uso:    python3 -B -I verifica.py <spazio di lavoro>
Uscita: 0 = ognuno dei tre modelli ha almeno una risposta
        1 = risultati.tsv assente, senza l'intestazione, o un modello
            senza risposte
        2 = risultati.tsv c'è ma non si legge (permessi, codifica), un
            argomento sbagliato, o un errore che il controllo non prevede
            (una riga, mai un traceback)
"""
from __future__ import annotations

import os
import sys
from typing import Dict, List, Optional, Tuple

FILE = "risultati.tsv"
INTESTAZIONE = "modello\tparola"
BOM = chr(0xFEFF)
MODELLI = ("haiku", "sonnet", "opus")
MOSTRA = 40
VARIA = "Input identici possono produrre output diversi (%s)"
ISTRUZIONE = ("Istruzione esplicita rispettata, una parola sola senza "
              "punteggiatura (%s, %d su %d)")
FATTO = ("Fatto: ogni affermazione è stata messa alla prova; gli esiti sono "
         "qui sopra.")

# Le risposte per modello, le righe di altri modelli, le righe unite.
Lettura = Tuple[Dict[str, List[str]], int, int]


class Illeggibile(Exception):
    """Un file che c'è ma non si legge: una precondizione, uscita 2."""


def leggi_testo(path: str, nome: str) -> str:
    """Il contenuto UTF-8 di un file, o Illeggibile; nome per i messaggi."""
    try:
        with open(path, encoding="utf-8") as fh:
            return fh.read()
    except UnicodeDecodeError:
        raise Illeggibile("%s non è un testo UTF-8" % nome) from None
    except OSError as exc:
        raise Illeggibile("%s non si legge (%s)" % (nome, exc.strerror)) \
            from None


def leggi_risposte(testo: str) -> Optional[Lettura]:
    """Le risposte di ogni modello, quante righe nominano un altro modello
    e quante righe senza tabulazione sono state unite alla risposta di
    sopra; None se la prima riga non è l'intestazione. Un BOM in testa si
    ignora; gli a capo CRLF arrivano già come LF (open in modo testo). Una
    riga senza tabulazione continua la risposta di sopra, unita con uno
    spazio; prima di ogni risposta non conta."""
    righe = testo.lstrip(BOM).split("\n")
    if righe[0] != INTESTAZIONE:
        return None
    lette: List[Tuple[str, List[str]]] = []
    unite = 0
    for riga in righe[1:]:
        if "\t" in riga:
            modello, _, risposta = riga.partition("\t")
            lette.append((modello.strip(), [risposta.strip()]))
        elif lette and riga.strip():
            lette[-1][1].append(riga.strip())
            unite += 1
    risposte: Dict[str, List[str]] = {m: [] for m in MODELLI}
    altre = 0
    for modello, pezzi in lette:
        risposta = " ".join(p for p in pezzi if p)
        if not risposta:
            continue
        if modello in risposte:
            risposte[modello].append(risposta)
        else:
            altre += 1
    return risposte, altre, unite


def accorcia(testo: str) -> str:
    """Una risposta da stampare: su una riga, al massimo MOSTRA caratteri."""
    testo = " ".join(testo.split())
    if len(testo) <= MOSTRA:
        return testo
    return testo[:MOSTRA - 1] + "…"


def riassunto(risposte: List[str]) -> str:
    """Le parole diverse, nell'ordine in cui compaiono, con le volte."""
    volte: Dict[str, int] = {}
    for risposta in risposte:
        volte[risposta] = volte.get(risposta, 0) + 1
    return ", ".join("«%s» ×%d" % (accorcia(r), n) for r, n in volte.items())


def verdetti(modello: str, risposte: List[str]) -> List[str]:
    """Le due righe di verdetto di un modello con almeno una risposta."""
    diverse = len(set(risposte))
    if diverse >= 2:
        varia = "confermata"
    elif len(risposte) == 1:
        varia = "non dimostrata in questa esecuzione (una sola risposta)"
    else:
        varia = "non dimostrata in questa esecuzione"
    sole = sum(1 for r in risposte if r.isalpha())
    istruzione = ("confermata" if sole == len(risposte)
                  else "non confermata in questa esecuzione")
    return ["%s: %s" % (VARIA % modello, varia),
            "%s: %s" % (ISTRUZIONE % (modello, sole, len(risposte)),
                        istruzione)]


def main(argv: List[str]) -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(errors="replace")
    if len(argv) != 1 or not os.path.isdir(argv[0]):
        sys.stderr.write("verifica.py: serve lo spazio di lavoro\n")
        return 2
    path = os.path.join(argv[0], FILE)
    if not os.path.isfile(path):
        print("Manca %s: eseguite i passi del README." % FILE)
        return 1
    try:
        letto = leggi_risposte(leggi_testo(path, FILE))
    except Illeggibile as exc:
        sys.stderr.write("verifica: %s\n" % exc)
        return 2
    if letto is None:
        print("%s: la prima riga deve essere l'intestazione "
              "«modello<TAB>parola»." % FILE)
        return 1
    risposte, altre, unite = letto
    righe_verdetto: List[str] = []
    mancano = 0
    for modello in MODELLI:
        elenco = risposte[modello]
        if not elenco:
            print("Nessuna risposta di %s in %s." % (modello, FILE))
            mancano += 1
            continue
        print("%s: %d %s -- %s" % (
            modello, len(elenco), "risposta" if len(elenco) == 1
            else "risposte", riassunto(elenco)))
        print("  parole diverse: %d; una parola sola, senza punteggiatura: "
              "%d su %d" % (len(set(elenco)),
                            sum(1 for r in elenco if r.isalpha()),
                            len(elenco)))
        righe_verdetto.extend(verdetti(modello, elenco))
    if altre:
        print("Righe di altri modelli, ignorate: %d." % altre)
    if unite:
        print("Righe senza tabulazione, unite alla risposta di sopra: %d."
              % unite)
    for riga in righe_verdetto[0::2] + righe_verdetto[1::2]:
        print(riga)
    if mancano:
        return 1
    print("Le risposte dei tre modelli ci sono.")
    print(FATTO)
    return 0


def principale(argv: List[str]) -> int:
    """main, con un errore che il controllo non prevede detto in una riga
    e l'uscita 2: mai un traceback, che uscirebbe 1 come un «non ancora»."""
    try:
        return main(argv)
    except Exception as exc:  # ogni errore che il controllo non prevede
        sys.stderr.write("verifica.py: errore inatteso del controllo (%s: "
                         "%s): segnalatelo al docente\n"
                         % (type(exc).__name__, str(exc)[:200]))
        return 2


if __name__ == "__main__":
    sys.exit(principale(sys.argv[1:]))
