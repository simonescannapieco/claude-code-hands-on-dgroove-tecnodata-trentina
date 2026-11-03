"""controlla_registrazione.py -- per le suite del Modulo 5: il README di un
elemento e la registrazione del corso dicono la stessa cosa? Le righe che il
README cita devono essere quelle che il controllo dell'elemento stampa sugli
stream di soluzione/, parola per parola. Gli spazi e gli a capo non contano.

Uso:    python3 -B -I controlla_registrazione.py <README.md> <uscita.txt>
        con le frasi sullo STDIN, una per riga, con un segno davanti:
          = <testo>  sta nel README e nell'uscita del controllo
          R <testo>  sta nel README: una cifra che il controllo non stampa
          ! <testo>  non sta nel README: un segnaposto, una frase superata
        le righe vuote non contano
Uscita: 0 = tutte a posto, «registrazione in ordine» · 1 = una o più non a
        posto, una riga per ciascuna · 2 = un file che non si legge, una riga
        senza segno, nessuna frase
Non è un modulo da eseguire: nessun bit di esecuzione.
"""
from __future__ import annotations

import sys
from typing import List


def piatto(testo: str) -> str:
    """Il testo con ogni sequenza di spazi e di a capo ridotta a uno spazio."""
    return " ".join(testo.split())


def problemi(readme: str, uscita: str, righe: List[str]) -> List[str]:
    """Le frasi non a posto. Solleva ValueError su una riga senza segno, o se
    non c'è nessuna frase: una prova vuota non deve passare."""
    trovati: List[str] = []
    contate = 0
    for riga in righe:
        if not riga.strip():
            continue
        segno, frase = riga[:2], piatto(riga[2:])
        if segno not in ("= ", "R ", "! ") or not frase:
            raise ValueError("una riga senza segno: %r" % riga)
        contate += 1
        if segno == "! ":
            if frase in readme:
                trovati.append("non ci deve stare nel README: «%s»" % frase)
            continue
        if frase not in readme:
            trovati.append("manca nel README: «%s»" % frase)
        if segno == "= " and frase not in uscita:
            trovati.append("non è nell'uscita del controllo: «%s»" % frase)
    if not contate:
        raise ValueError("nessuna frase")
    return trovati


def main(argv: List[str]) -> int:
    """Vedi la testata del file."""
    if len(argv) != 3:
        print("uso: controlla_registrazione.py <README.md> <uscita.txt>",
              file=sys.stderr)
        return 2
    try:
        with open(argv[1], encoding="utf-8") as fh:
            readme = piatto(fh.read())
        with open(argv[2], encoding="utf-8") as fh:
            uscita = piatto(fh.read())
        trovati = problemi(readme, uscita, sys.stdin.read().splitlines())
    except (OSError, UnicodeDecodeError, ValueError) as exc:
        print("controlla_registrazione: %s" % exc, file=sys.stderr)
        return 2
    for riga in trovati:
        print(riga)
    if trovati:
        return 1
    print("registrazione in ordine")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
