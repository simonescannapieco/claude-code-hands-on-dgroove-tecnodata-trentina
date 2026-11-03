#!/usr/bin/env python3
"""feedback_docente.py -- scrive iteration-N/feedback.json per una prova senza
una persona davanti (_docente/lib_lab_m5.sh). Un partecipante quel file lo scrive
da sé, dopo aver letto le risposte; qui una riga per caso nasce dalle asserzioni
non passate di quel caso, lette dai grading.json che tools/prove_skill.sh ha
appena scritto. Il file lo dice nel suo testo, nella voce «_nota»: nessuna riga è
il commento di una persona. Un caso senza asserzioni non passate ha la stringa
vuota, come nella forma della guida dello standard: «Empty feedback means the
output looked fine».

Uso:    python3 -B -I feedback_docente.py <cartella iteration-N>
Uscita: 0 scritto · 2 argomenti, una cartella senza casi, un grading.json che
        manca o non si legge, un feedback.json che c'è già: non lo sovrascrive
"""
from __future__ import annotations

import json
import os
import re
import sys
from typing import Dict, List

NOTA = ("Questo file non l'ha scritto una persona: l'ha scritto uno script, "
        "feedback_docente.py, per una prova senza nessuno davanti, una riga "
        "per caso, dalle asserzioni non passate di quel caso.")
RE_EVAL = re.compile(r"^eval-\d+$")


class Precondizione(Exception):
    """Il file non si può scrivere: uscita 2."""


def riga_del_caso(percorso: str) -> str:
    """Le asserzioni non passate di un grading.json, con la loro prova."""
    try:
        with open(percorso, encoding="utf-8") as fh:
            voti = json.load(fh)["assertion_results"]
        fallite: List[str] = [f"«{voce['text']}»: {voce['evidence']}"
                              for voce in voti if voce["passed"] is False]
    except (OSError, ValueError, KeyError, TypeError) as exc:
        raise Precondizione(f"{percorso} non si legge: {exc}") from exc
    return "Non passate: " + "; ".join(fallite) if fallite else ""


def commenti(cartella: str) -> Dict[str, str]:
    """La voce «_nota» e una voce per ogni caso. Raises: Precondizione."""
    try:
        nomi = sorted(n for n in os.listdir(cartella) if RE_EVAL.match(n))
    except OSError as exc:
        raise Precondizione(f"{cartella} non si legge: {exc}") from exc
    if not nomi:
        raise Precondizione(f"{cartella}: nessuna cartella eval-<id>")
    voci = {"_nota": NOTA}
    for nome in nomi:
        voci[nome] = riga_del_caso(os.path.join(cartella, nome, "with_skill",
                                                "grading.json"))
    return voci


def main(argv: List[str]) -> int:
    try:
        if len(argv) != 1:
            raise Precondizione("Uso: feedback_docente.py <cartella "
                                "iteration-N>")
        destinazione = os.path.join(argv[0], "feedback.json")
        if os.path.exists(destinazione):
            raise Precondizione(f"{destinazione} c'è già: non lo sovrascrivo")
        voci = commenti(argv[0])
        with open(destinazione, "w", encoding="utf-8") as fh:
            json.dump(voci, fh, ensure_ascii=False, indent=2)
            fh.write("\n")
    except (Precondizione, OSError) as exc:
        print(f"feedback_docente: {exc}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
