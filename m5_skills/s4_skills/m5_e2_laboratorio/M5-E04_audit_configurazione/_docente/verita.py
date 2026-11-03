#!/usr/bin/env python3
"""verita.py di M5-E04 -- la verità del controllo, per il docente: per ogni
apparato dei tre casi di prova le categorie dei problemi inseriti apposta, come
impronte.

Le ricava da progetti/rete/_docente/chiave-problemi.tsv e pretende che
coincidano con ATTESE, che è ciò che i casi di prova mettono alla prova; prima
controlla ogni riga: il marcatore c'è nella configurazione dell'apparato, e la
categoria c'è nella checklist. Poi scrive le impronte SHA-256 di
«m5-e04:<apparato>:<categoria>», mai i codici in chiaro. I codici sono pubblici:
l'impronta nasconde quali sono stati inseriti in quale apparato, finché non si
è provato.

Uso:    python3 -B -I _docente/verita.py [--chiave <file>]
          stampa il JSON su stdout: è il contenuto di verita.json
        python3 -B -I _docente/verita.py --check [--chiave <file>]
          [--verita <file>]
          confronta con verita.json
Env:    PN_HANDSON_ROOT  il repository (default: la radice sopra l'elemento)
Uscita: 0 stampato, o verita.json conferma la chiave · 1 verita.json è diversa
        · 2 argomenti, una chiave che non si legge o che non torna
"""
from __future__ import annotations

import csv
import hashlib
import json
import os
import sys
from typing import Dict, List, Tuple

ELEMENTO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SALE = "m5-e04"
PROGETTO = os.path.join("progetti", "rete")
ATTESE = {"sw-rovereto-01": ("AUD-05", "AUD-11"),
          "olt-pergine-01": ("AUD-10", "AUD-13"),
          "bts-cles-01": ("AUD-02", "AUD-14")}
COLONNE = ("id", "apparato", "file", "marcatore", "occorrenza", "categoria",
           "gravita", "descrizione")
NOTA = ("Impronte SHA-256 di «m5-e04:<apparato>:<categoria>»: le categorie dei "
        "problemi inseriti apposta in ogni apparato dei casi di prova. La "
        "verifica le confronta con i codici che la risposta riporta.")
USO = ("Uso: verita.py [--chiave <file>]\n"
       "     verita.py --check [--chiave <file>] [--verita <file>]")


class Precondizione(Exception):
    """La verità non si ricava: uscita 2."""


def impronta(apparato: str, categoria: str) -> str:
    testo = f"{SALE}:{apparato}:{categoria}"
    return hashlib.sha256(testo.encode("utf-8")).hexdigest()


def leggi_testo(percorso: str) -> str:
    try:
        with open(percorso, encoding="utf-8", newline="") as fh:
            return fh.read()
    except (OSError, UnicodeDecodeError) as exc:
        raise Precondizione(f"{percorso} non si legge: {exc}") from exc


def leggi_chiave(percorso: str) -> List[Dict[str, str]]:
    """Le righe della chiave. Raises: Precondizione."""
    righe = leggi_testo(percorso).splitlines(True)
    lette = csv.DictReader(righe, delimiter="\t", quoting=csv.QUOTE_NONE)
    if tuple(lette.fieldnames or ()) != COLONNE:
        raise Precondizione(f"{percorso}: le colonne sono "
                            f"{lette.fieldnames!r}, attese {COLONNE!r}")
    return list(lette)


def _controlla_riga(riga: Dict[str, str], radice: str, checklist: str) -> None:
    """Il marcatore nella configurazione, la categoria nella checklist."""
    dove = f"{riga['id']}, {riga['apparato']}"
    testo = leggi_testo(os.path.join(radice, PROGETTO, riga["file"]))
    if riga["marcatore"] not in testo:
        raise Precondizione(f"{dove}: {riga['file']} non contiene "
                            f"«{riga['marcatore']}»")
    if f"### {riga['categoria']} " not in checklist:
        raise Precondizione(f"{dove}: {riga['categoria']} non è nella "
                            "checklist")


def verita(radice: str, chiave: str) -> dict:
    """Il contenuto di verita.json. Raises: Precondizione."""
    checklist = leggi_testo(os.path.join(radice, PROGETTO,
                                         "checklist-audit.md"))
    trovate: Dict[str, List[str]] = {apparato: [] for apparato in ATTESE}
    for riga in leggi_chiave(chiave):
        if riga["apparato"] in trovate:
            _controlla_riga(riga, radice, checklist)
            trovate[riga["apparato"]].append(riga["categoria"])
    for apparato, attese in ATTESE.items():
        if tuple(sorted(trovate[apparato])) != attese:
            raise Precondizione(f"{apparato}: la chiave dice "
                                f"{sorted(trovate[apparato])!r}, i casi di "
                                f"prova si aspettano {list(attese)!r}")
    return {"elemento": "M5-E04", "nota": NOTA,
            "apparati": {a: sorted(impronta(a, c) for c in ATTESE[a])
                         for a in sorted(ATTESE)}}


def leggi_opzioni(argv: List[str], radice: str) -> Tuple[bool, str, str]:
    """--check, la chiave, verita.json. Raises: Precondizione."""
    controlla = False
    chiave = os.path.join(radice, PROGETTO, "_docente", "chiave-problemi.tsv")
    file_verita = os.path.join(ELEMENTO, "verita.json")
    resto = list(argv)
    while resto:
        arg = resto.pop(0)
        if arg == "--check":
            controlla = True
        elif arg in ("--chiave", "--verita") and resto:
            if arg == "--chiave":
                chiave = resto.pop(0)
            else:
                file_verita = resto.pop(0)
        else:
            raise Precondizione(USO)
    return controlla, chiave, file_verita


def main(argv: List[str]) -> int:
    radice = os.environ.get("PN_HANDSON_ROOT") or os.path.normpath(
        os.path.join(ELEMENTO, *[os.pardir] * 4))
    try:
        controlla, chiave, file_verita = leggi_opzioni(argv, radice)
        attesa = verita(radice, chiave)
        if not controlla:
            sys.stdout.write(json.dumps(attesa, ensure_ascii=False, indent=2)
                             + "\n")
            return 0
        try:
            uguale = json.loads(leggi_testo(file_verita)) == attesa
        except ValueError as exc:
            raise Precondizione(f"{file_verita} non si legge: {exc}") from exc
    except Precondizione as exc:
        sys.stderr.write(f"verita: {exc}\n")
        return 2
    if not uguale:
        print(f"{file_verita} è diversa da ciò che dice la chiave")
        return 1
    print("verita.json conferma la chiave: "
          + ", ".join(f"{a} {len(v)} categorie"
                      for a, v in sorted(attesa["apparati"].items())))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
