"""prove_skill_casi.py -- ciò che tools/prove_skill.sh chiede a Python: leggere
i casi di prova senza che bash interpreti i prompt, e dire se uno stream è di
un'esecuzione riuscita. Le letture sono quelle di lib_controlla_prove.py.

Uso:    python3 -B -I tools/prove_skill_casi.py casi <cartella skill> <uscita>
            [--near-miss]
          scrive <uscita>/eval-<id>.prompt per ogni caso di evals/evals.json e,
          con --near-miss, <uscita>/near-miss-<k>.prompt per ogni richiesta di
          evals/eval_queries.json, byte per byte; su STDOUT un nome per riga
        python3 -B -I tools/prove_skill_casi.py esito <stream>
          dice se lo stream ha un risultato e nessun errore
Uscita: 0 fatto, o un'esecuzione riuscita · 1 (esito) nessun risultato o un
        errore · 2 argomenti sbagliati, o qualcosa che non si riesce a leggere
"""
from __future__ import annotations

import os
import sys
from typing import List

# Il modulo sta accanto a questo file; -I toglie la cartella dello script dal
# percorso dei moduli.
sys.path.insert(0, os.path.dirname(os.path.realpath(__file__)))
try:
    # pylint: disable=wrong-import-position
    import lib_controlla_prove as prove
except ImportError as exc:
    print("prove_skill_casi: manca lib_controlla_prove.py accanto a questo "
          f"file: {exc}", file=sys.stderr)
    sys.exit(2)

USO = """\
Uso: prove_skill_casi.py casi <cartella skill> <uscita> [--near-miss]
     prove_skill_casi.py esito <stream>"""


def _scrivi_prompt(percorso: str, testo: str) -> None:
    """Un prompt in un file. Raises: Problema."""
    if "\0" in testo:
        raise prove.Problema(f"{percorso}: un carattere NUL nel prompt: bash "
                             "non lo può passare a claude")
    try:
        with open(percorso, "w", encoding="utf-8", newline="") as fh:
            fh.write(testo)
    except OSError as exc:
        raise prove.Problema(f"non riesco a scrivere {percorso}: "
                             f"{exc}") from exc


def _comando_casi(argv: List[str]) -> int:
    con_near_miss = "--near-miss" in argv
    resto = [arg for arg in argv if arg != "--near-miss"]
    if len(resto) != 2:
        print(USO, file=sys.stderr)
        return 2
    cartella_skill, uscita = resto
    for caso in prove.leggi_evals(cartella_skill)["evals"]:
        _scrivi_prompt(os.path.join(uscita, f"eval-{caso['id']}.prompt"),
                       caso["prompt"])
        print(f"eval-{caso['id']}")
    if con_near_miss:
        for k, voce in enumerate(prove.leggi_query(cartella_skill), 1):
            _scrivi_prompt(os.path.join(uscita, f"near-miss-{k}.prompt"),
                           voce["query"])
            print(f"near-miss-{k}")
    return 0


def _comando_esito(argv: List[str]) -> int:
    if len(argv) != 1:
        print(USO, file=sys.stderr)
        return 2
    esec = prove.leggi_stream(argv[0])
    if not esec.completa:
        print("nessun risultato nello stream")
        return 1
    if esec.errore:
        print(f"finita con un errore: {esec.testo[:200]}")
        return 1
    return 0


def _comandi(argv: List[str]) -> int:
    comando = argv[0] if argv else ""
    if comando == "casi":
        return _comando_casi(argv[1:])
    if comando == "esito":
        return _comando_esito(argv[1:])
    print(USO, file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(prove.principale(_comandi, sys.argv[1:]))
