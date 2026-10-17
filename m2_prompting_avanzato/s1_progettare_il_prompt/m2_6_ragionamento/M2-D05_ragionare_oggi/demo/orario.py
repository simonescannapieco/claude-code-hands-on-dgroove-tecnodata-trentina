"""Legge su STDIN il JSON di `claude -p --output-format json` e stampa
l'orario finale della risposta, senza lo zero davanti all'ora. Le risposte
passo passo ripetono spesso l'orario di partenza («il servizio inizia alle
9:00») e a volte ne aggiungono un altro dopo la risposta («l'ultimo turno
inizia alle 9:32»): per questo l'orario si cerca, in quest'ordine,
  1. nella riga che dice «risposta finale» (o, se lì non c'è, nelle righe
     dopo): il primo orario diverso da quello di partenza;
  2. fra gli orari in grassetto (**9:36**): l'ultimo diverso da quello di
     partenza;
  3. altrimenti: l'ultimo orario diverso da quello di partenza.

Uso:    ... | python3 orario.py 9:00     (gli sportelli: si parte alle 9:00)
        ... | python3 orario.py 8:00     (le squadre: si parte alle 8:00)
Uscita: 0 fatto · 1 nessun JSON, un JSON non valido o con un errore,
        nessun orario nella risposta · 2 uso sbagliato
"""
from __future__ import annotations

import json
import re
import sys
from typing import List, Optional

ORARIO = re.compile(r"([0-9]{1,2})[:.]([0-9]{2})")
GRASSETTO = re.compile(r"\*\*([^*]*)\*\*")


def errore(messaggio: str) -> int:
    """Il messaggio su STDERR, in una riga; l'uscita 1."""
    sys.stderr.write("orario.py: %s\n" % messaggio)
    return 1


def orari(testo: str, inizio: str) -> List[str]:
    """Gli orari del testo, in ordine, senza quello di partenza."""
    tutti = ["%d:%s" % (int(h), m) for h, m in ORARIO.findall(testo)]
    return [o for o in tutti if o != inizio]


def finale(testo: str, inizio: str) -> Optional[str]:
    """L'orario finale della risposta, con le tre regole del docstring."""
    righe = testo.split("\n")
    for i, riga in enumerate(righe):
        if "risposta finale" in riga.lower():
            for altra in righe[i:]:
                trovati = orari(altra, inizio)
                if trovati:
                    return trovati[0]
            break
    grassetti = [o for g in GRASSETTO.findall(testo) for o in orari(g, inizio)]
    if grassetti:
        return grassetti[-1]
    trovati = orari(testo, inizio)
    return trovati[-1] if trovati else None


def main(argv: List[str]) -> int:
    if len(argv) != 1 or not ORARIO.fullmatch(argv[0]):
        sys.stderr.write(__doc__)
        return 2
    h, m = ORARIO.fullmatch(argv[0]).groups()
    inizio = "%d:%s" % (int(h), m)
    testo = sys.stdin.buffer.read().decode("utf-8", errors="replace")
    try:
        risposta = json.loads(testo)
    except ValueError:
        return errore("il testo in ingresso non è un JSON valido")
    if not isinstance(risposta, dict) or risposta.get("is_error"):
        return errore("il JSON non è una risposta riuscita di claude -p")
    trovato = finale(str(risposta.get("result") or ""), inizio)
    if trovato is None:
        return errore("nessun orario nella risposta")
    print(trovato)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
