#!/usr/bin/env python3
"""verita.py di M5-D04 -- la verità del controllo, per il docente: le regole
che il pull request di demo/pr-demo.patch viola e le categorie inserite in
core-trento-01, come impronte.

Le ricava due volte e pretende che coincidano:
  - le regole: l'elenco del pull request (REGOLE) contro ciò che si legge nella
    patch (CONTROLLI, un controllo per regola), e ogni numero deve esistere in
    progetti/gestionale-php/docs/convenzioni.md;
  - le categorie: le righe di core-trento-01 in
    progetti/rete/_docente/chiave-problemi.tsv contro CATEGORIE, che sono
    quattro.
Poi scrive le impronte SHA-256 di «m5-d04:regola:<numero>» e
«m5-d04:categoria:<codice>», mai i valori.

Uso:    python3 -B -I _docente/verita.py        stampa il JSON (il contenuto di
                                                verita.json)
        python3 -B -I _docente/verita.py --check [--verita <file>]
                                                confronta con verita.json
Env:    PN_HANDSON_ROOT  il repository (default: la radice sopra l'elemento)
Uscita: 0 stampato, o verita.json conferma i dati · 1 verita.json è diversa · 2
        precondizione (un'opzione sbagliata; un file che non si legge; i dati
        che non coincidono)
"""
import csv
import hashlib
import json
import os
import re
import sys
from typing import Callable, List, Tuple

ELEMENTO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SALE = "m5-d04"
APPARATO = "core-trento-01"
REGOLE = ("2.2", "4.1", "4.3", "5.1", "6.2", "7.1", "7.3", "10.2")
CATEGORIE = ("AUD-01", "AUD-02", "AUD-03", "AUD-12")
NOTA = ("Impronte SHA-256 di «m5-d04:regola:<numero>» e «m5-d04:categoria:"
        "<codice>»: le regole che il pull request della demo viola e le "
        "categorie inserite nell'apparato. Il controllo le confronta con ciò "
        "che le risposte citano, senza scriverle in chiaro.")
USO = "Uso: verita.py [--check [--verita <file>]]"


class Precondizione(Exception):
    """La verità non si ricava: uscita 2."""


def impronta(campo: str, valore: str) -> str:
    return hashlib.sha256(("%s:%s:%s" % (SALE, campo, valore)).encode("utf-8")
                          ).hexdigest()


def righe_aggiunte(patch: str) -> Tuple[str, List[str]]:
    """Il testo aggiunto dalla patch e i file che tocca."""
    aggiunte, file_toccati = [], []
    for riga in patch.splitlines():
        if riga.startswith("+++ b/"):
            file_toccati.append(riga[len("+++ b/"):])
        elif riga.startswith("+") and not riga.startswith("+++"):
            aggiunte.append(riga[1:])
    return "\n".join(aggiunte), file_toccati


def query_nel_ciclo(testo: str) -> bool:
    dopo = testo.split("foreach", 1)
    return len(dopo) == 2 and "->query(" in dopo[1].split("}", 1)[0]


CONTROLLI: Tuple[Tuple[str, Callable[[str, List[str]], bool]], ...] = (
    ("2.2", lambda t, _: "declare(strict_types=1)" not in t),
    ("4.1", lambda t, _: re.search(r"function \w+\(\$", t) is not None),
    ("4.3", lambda t, _: re.search(r"(?m)^class ", t) is not None),
    ("5.1", lambda t, _: "= 0.0;" in t and "/ 100" in t),
    ("6.2", lambda t, _: re.search(r"(?m)^\s*echo ", t) is not None),
    ("7.1", lambda t, _: re.search(r"\"\s*\.\s*\$", t) is not None),
    ("7.3", lambda t, _: query_nel_ciclo(t)),
    ("10.2", lambda _, f: not any("/tests/" in p for p in f)),
)


def regole_del_pr(radice: str) -> List[str]:
    """Le regole violate, controllate sulla patch e sulle convenzioni."""
    with open(os.path.join(ELEMENTO, "demo", "pr-demo.patch"),
              encoding="utf-8") as fh:
        testo, file_toccati = righe_aggiunte(fh.read())
    lette = tuple(n for n, controllo in CONTROLLI
                  if controllo(testo, file_toccati))
    if lette != REGOLE:
        raise Precondizione("la patch e l'elenco non coincidono: %r"
                            % (lette,))
    with open(os.path.join(radice, "progetti", "gestionale-php", "docs",
                           "convenzioni.md"), encoding="utf-8") as fh:
        convenzioni = fh.read()
    for numero in REGOLE:
        if re.search(r"(?m)^%s " % re.escape(numero), convenzioni) is None:
            raise Precondizione("la regola %s non è nelle convenzioni"
                                % numero)
    return list(REGOLE)


def categorie_dell_apparato(radice: str) -> List[str]:
    """Le categorie inserite in APPARATO, dalla chiave del docente."""
    with open(os.path.join(radice, "progetti", "rete", "_docente",
                           "chiave-problemi.tsv"), encoding="utf-8",
              newline="") as fh:
        lette = sorted({riga["categoria"]
                        for riga in csv.DictReader(fh, delimiter="\t")
                        if riga["apparato"] == APPARATO})
    if tuple(lette) != CATEGORIE:
        raise Precondizione("la chiave e l'elenco non coincidono: %r" % lette)
    return lette


def verita(radice: str) -> dict:
    """Il contenuto di verita.json."""
    regole = regole_del_pr(radice)
    categorie = categorie_dell_apparato(radice)
    return {"elemento": "M5-D04", "nota": NOTA,
            "revisione": {"regole": sorted(impronta("regola", n)
                                           for n in regole)},
            "audit": {"apparato": APPARATO,
                      "categorie": sorted(impronta("categoria", c)
                                          for c in categorie)}}


def leggi_opzioni(argv: List[str]) -> Tuple[bool, str]:
    """--check e verita.json. Raises: Precondizione, con l'uso."""
    controlla = False
    file_verita = os.path.join(ELEMENTO, "verita.json")
    resto = list(argv)
    while resto:
        arg = resto.pop(0)
        if arg == "--check":
            controlla = True
        elif arg == "--verita" and resto:
            file_verita = resto.pop(0)
        else:
            raise Precondizione(USO)
    return controlla, file_verita


def main(argv: List[str]) -> int:
    radice = os.environ.get("PN_HANDSON_ROOT") or os.path.normpath(
        os.path.join(ELEMENTO, *[os.pardir] * 4))
    try:
        controlla, file_verita = leggi_opzioni(argv)
        attesa = verita(radice)
    except (Precondizione, OSError, KeyError, ValueError) as exc:
        sys.stderr.write("verita: %s\n" % exc)
        return 2
    if not controlla:
        sys.stdout.write(json.dumps(attesa, ensure_ascii=False, indent=2)
                         + "\n")
        return 0
    try:
        with open(file_verita, encoding="utf-8") as fh:
            uguale = json.load(fh) == attesa
    except (OSError, ValueError) as exc:
        sys.stderr.write("verita: %s non si legge (%s)\n" % (file_verita, exc))
        return 2
    if not uguale:
        print("%s è diversa da ciò che dicono la patch e la chiave del docente"
              % file_verita)
        return 1
    print("verita.json conferma i dati: %d regole, %d categorie"
          % (len(REGOLE), len(CATEGORIE)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
