#!/usr/bin/env python3
"""verita.py di M5-E02 -- la verità del controllo, per il docente: per ogni pull
request le regole inserite apposta, come impronte. Le legge da
_docente/chiave_pr.tsv e prima controlla ogni riga:
  - il numero c'è in progetti/gestionale-php/docs/convenzioni.md;
  - un file del pull request: in prove/pr-<n>.patch quella riga è aggiunta e
    contiene il segno;
  - un file fuori dal pull request: nel progetto, com'è, quella riga contiene il
    segno;
  - un file «-»: riga e segno sono «-», la regola non ha un posto.
Poi scrive le impronte SHA-256 di «m5-e02:pr-<n>:<regola>», mai i numeri in
chiaro in verita.json. I numeri delle regole sono pubblici: l'impronta nasconde
quali sono stati inseriti in quale pull request, finché non si è provato.

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
import re
import sys
from typing import Dict, List, Optional, Tuple

ELEMENTO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SALE = "m5-e02"
PROGETTO = "progetti/gestionale-php/"
COLONNE = ("pr", "regola", "file", "riga", "segno", "nota")
RE_REGOLA = re.compile(r"^(\d+\.\d+) ", re.M)
RE_HUNK = re.compile(r"^@@ -\d+(?:,\d+)? \+(\d+)")
NOTA = ("Impronte SHA-256 di «m5-e02:pr-<n>:<regola>»: le regole delle "
        "convenzioni inserite apposta in ogni pull request. La verifica le "
        "confronta con i numeri che la risposta cita.")
USO = ("Uso: verita.py [--chiave <file>]\n"
       "     verita.py --check [--chiave <file>] [--verita <file>]")


class Precondizione(Exception):
    """La verità non si ricava: uscita 2."""


def impronta(pr: str, regola: str) -> str:
    testo = f"{SALE}:pr-{pr}:{regola}"
    return hashlib.sha256(testo.encode("utf-8")).hexdigest()


def leggi_testo(percorso: str) -> str:
    try:
        with open(percorso, encoding="utf-8") as fh:
            return fh.read()
    except (OSError, UnicodeDecodeError) as exc:
        raise Precondizione(f"{percorso} non si legge: {exc}") from exc


def leggi_chiave(percorso: str) -> List[Dict[str, str]]:
    """Le righe della chiave; i commenti, «#», non contano."""
    righe = [r for r in leggi_testo(percorso).splitlines(True)
             if r.strip() and not r.startswith("#")]
    lette = csv.DictReader(righe, delimiter="\t", quoting=csv.QUOTE_NONE)
    if tuple(lette.fieldnames or ()) != COLONNE:
        raise Precondizione(f"{percorso}: le colonne sono "
                            f"{lette.fieldnames!r}, attese {COLONNE!r}")
    return list(lette)


def righe_aggiunte(patch: str) -> Dict[str, Dict[int, str]]:
    """Per ogni file di una patch, le righe aggiunte con il loro numero. Una
    riga di contesto vuota può essere uno spazio o niente: git apply accetta
    tutte e due le forme."""
    aggiunte: Dict[str, Dict[int, str]] = {}
    percorso: Optional[str] = None
    numero = 0
    for riga in patch.split("\n"):
        hunk = RE_HUNK.match(riga)
        if riga.startswith("+++ b/"):
            percorso = riga[len("+++ b/"):]
            aggiunte[percorso] = {}
        elif hunk:
            numero = int(hunk.group(1))
        elif percorso is None or riga.startswith("--- "):
            continue
        elif riga.startswith("+"):
            aggiunte[percorso][numero] = riga[1:]
            numero += 1
        elif riga.startswith(" ") or not riga:
            numero += 1
    return aggiunte


def _controlla_posto(riga: Dict[str, str], radice: str,
                     aggiunte: Dict[str, Dict[int, str]]) -> None:
    dove = f"pr-{riga['pr']}, regola {riga['regola']}, {riga['file']}"
    if riga["file"] == "-":
        if riga["riga"] != "-" or riga["segno"] != "-":
            raise Precondizione(f"{dove}: senza un file, riga e segno sono «-»")
        return
    if not riga["riga"].isdigit():
        raise Precondizione(f"{dove}: la riga «{riga['riga']}» non è un numero")
    numero = int(riga["riga"])
    percorso = PROGETTO + riga["file"]
    if percorso in aggiunte:
        trovata = aggiunte[percorso].get(numero)
    else:
        righe = leggi_testo(os.path.join(radice, percorso)).split("\n")
        trovata = righe[numero - 1] if numero <= len(righe) else None
    if trovata is None or riga["segno"] not in trovata:
        raise Precondizione(f"{dove}: la riga {numero} è «{trovata}», non "
                            f"contiene «{riga['segno']}»")


def verita(radice: str, chiave: str) -> dict:
    """Il contenuto di verita.json. Raises: Precondizione."""
    convenzioni = leggi_testo(os.path.join(radice, PROGETTO, "docs",
                                           "convenzioni.md"))
    regole = set(RE_REGOLA.findall(convenzioni))
    if not regole:
        raise Precondizione("convenzioni.md non ha regole numerate")
    aggiunte_di: Dict[str, Dict[str, Dict[int, str]]] = {}
    voci: Dict[str, List[str]] = {}
    for riga in leggi_chiave(chiave):
        if riga["pr"] not in ("1", "2", "3"):
            raise Precondizione(f"la chiave nomina il pull request "
                                f"«{riga['pr']}»")
        if riga["regola"] not in regole:
            raise Precondizione(f"pr-{riga['pr']}: la regola "
                                f"{riga['regola']} non è nelle convenzioni")
        if riga["pr"] not in aggiunte_di:
            aggiunte_di[riga["pr"]] = righe_aggiunte(leggi_testo(os.path.join(
                ELEMENTO, "prove", f"pr-{riga['pr']}.patch")))
        _controlla_posto(riga, radice, aggiunte_di[riga["pr"]])
        voci.setdefault(riga["pr"], []).append(impronta(riga["pr"],
                                                        riga["regola"]))
    if sorted(voci) != ["1", "2", "3"]:
        raise Precondizione(f"la chiave ha i pull request {sorted(voci)!r}")
    return {"elemento": "M5-E02", "nota": NOTA,
            "pr": {pr: sorted(voci[pr]) for pr in sorted(voci)}}


def leggi_opzioni(argv: List[str]) -> Tuple[bool, str, str]:
    """--check, la chiave, verita.json. Raises: Precondizione."""
    controlla = False
    chiave = os.path.join(ELEMENTO, "_docente", "chiave_pr.tsv")
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
        controlla, chiave, file_verita = leggi_opzioni(argv)
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
          + ", ".join(f"pr-{pr} {len(voci)} regole"
                      for pr, voci in sorted(attesa["pr"].items())))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
