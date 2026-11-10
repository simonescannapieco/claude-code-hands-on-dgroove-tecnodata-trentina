"""componi.py -- M8-D04 «Il modello giusto per il lavoro»: il prompt della
classificazione. Mette al posto di @@TICKET@@, in prompt.txt, i ticket di
ticket.jsonl numerati (il loro testo, mai l'etichetta) e stampa il prompt
composto; controlla che lo schema chieda tante etichette quanti sono i ticket.

Uso:    python3 -B -I componi.py [cartella]
          la cartella di prompt.txt, ticket.jsonl e schema-etichette.json
          (default: quella di questo file)
Uscita: 0 il prompt su STDOUT · 2 un file che manca o non si legge, una riga
        di ticket.jsonl non valida, lo schema che non corrisponde ai ticket
"""
from __future__ import annotations

import json
import os
import sys
from typing import List, Tuple

SEGNAPOSTO = "@@TICKET@@"
CATEGORIE = ("guasto", "lentezza", "fattura", "attivazione")
USO = "Uso: python3 -B -I componi.py [cartella]\n"


class Problema(Exception):
    """Un file che manca o non è valido: uscita 2."""


def leggi(percorso: str) -> str:
    """Il testo di un file. Raises: Problema."""
    try:
        with open(percorso, encoding="utf-8") as fh:
            return fh.read()
    except (OSError, UnicodeDecodeError) as exc:
        raise Problema("%s non si legge (%s)" % (percorso, exc)) from exc


def carica_ticket(percorso: str) -> List[Tuple[str, str]]:
    """Da ticket.jsonl: per ogni riga (testo, etichetta). Raises: Problema."""
    ticket: List[Tuple[str, str]] = []
    for numero, riga in enumerate(leggi(percorso).splitlines(), 1):
        if not riga.strip():
            continue
        try:
            dato = json.loads(riga)
        except ValueError as exc:
            raise Problema("%s, riga %d: non è JSON (%s)"
                           % (percorso, numero, exc)) from exc
        testo = dato.get("testo") if isinstance(dato, dict) else None
        etichetta = dato.get("etichetta") if isinstance(dato, dict) else None
        if not isinstance(testo, str) or not testo \
                or etichetta not in CATEGORIE:
            raise Problema("%s, riga %d: testo o etichetta non validi"
                           % (percorso, numero))
        ticket.append((testo, etichetta))
    if not ticket:
        raise Problema("%s: nessun ticket" % percorso)
    return ticket


def controlla_schema(percorso: str, quanti: int) -> None:
    """Lo schema chiede esattamente quante etichette ci sono. Raises:
    Problema."""
    try:
        schema = json.loads(leggi(percorso))
        etichette = schema["properties"]["etichette"]
    except (ValueError, KeyError, TypeError) as exc:
        raise Problema("%s: lo schema non si legge (%s)"
                       % (percorso, exc)) from exc
    if etichette.get("minItems") != quanti \
            or etichette.get("maxItems") != quanti:
        raise Problema("%s: chiede da %s a %s etichette, i ticket sono %d"
                       % (percorso, etichette.get("minItems"),
                          etichette.get("maxItems"), quanti))
    if sorted(etichette.get("items", {}).get("enum", [])) \
            != sorted(CATEGORIE):
        raise Problema("%s: le categorie non sono quelle dei ticket" % percorso)


def componi(cartella: str) -> str:
    """Il prompt composto. Raises: Problema."""
    ticket = carica_ticket(os.path.join(cartella, "ticket.jsonl"))
    controlla_schema(os.path.join(cartella, "schema-etichette.json"),
                     len(ticket))
    modello = leggi(os.path.join(cartella, "prompt.txt"))
    if modello.count(SEGNAPOSTO) != 1:
        raise Problema("prompt.txt non ha il segnaposto %s" % SEGNAPOSTO)
    numerati = "\n\n".join("%d. %s" % (i, t)
                           for i, (t, _) in enumerate(ticket, 1))
    return modello.replace(SEGNAPOSTO, numerati).rstrip("\n") + "\n"


def main(argv: List[str]) -> int:
    if len(argv) > 1 or (argv and argv[0].startswith("-")):
        sys.stderr.write(USO)
        return 2
    cartella = argv[0] if argv else os.path.dirname(os.path.realpath(__file__))
    try:
        sys.stdout.write(componi(cartella))
    except Problema as exc:
        sys.stderr.write("componi: %s\n" % exc)
        return 2
    except Exception as exc:  # pylint: disable=broad-except
        sys.stderr.write("componi: errore inatteso (%s: %s)\n"
                         % (type(exc).__name__, exc))
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
