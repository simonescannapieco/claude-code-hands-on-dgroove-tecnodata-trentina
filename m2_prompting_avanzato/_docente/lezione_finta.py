#!/usr/bin/env python3
"""lezione_finta.py -- due lezioni finte per provare controlla_readme.py.

Lo usa test_m2_script.sh; solo libreria standard. Scrive in <cartella> due
README (E01/ ed E02/) che passano ogni controllo, con le versioni di
riferimento e le trascrizioni: la suite le rovina una riga alla volta.

Uso:    lezione_finta.py <cartella>
Uscita: 0 scritta · 2 uso sbagliato, o un file che non si scrive
"""
from __future__ import annotations

import os
import sys
from typing import List, Sequence

SEZIONI = ("Obiettivo", "Tempo", "Prerequisiti", "La teoria che serve",
           "Punto di partenza (tools/prepara_esercizio.sh M2-E01)",
           "Passi in Claude Code", "Che cosa osservare",
           "Verifica (tools/verifica.sh M2-E01)", "Se qualcosa va storto",
           "Impronta d'uso sul piano Pro", "Per approfondire",
           "La soluzione, passo per passo")
COMUNI = ("Perché si misura un prompt", "Gli ingredienti e i loro tag",
          "Che cos'è una pratica", "I due tipi di criterio", "Il giudice",
          "Come si legge un esito", "Gli attrezzi",
          "La regola delle versioni")
SOLO_E01 = ("Le pratiche in M2-E01", "Le versioni di M2-E01")
SOLO_E02 = ("Le famiglie e i due cicli", "Le pratiche in M2-E02",
            "Le versioni di M2-E02", "Il contesto, come pratica",
            "Effort e modello, come pratiche")
DATO = {"sviluppo": ("code", "codice"), "supporto": ("message", "messaggio"),
        "sistemi": ("log", "log")}
RIF = {"sviluppo": ("convention", "convenzione"),
       "supporto": ("tone_guide", "tono"), "sistemi": None}
TRASCRIZIONE = ("data della prova: 2026-11-08\nclaude 2.1.319 (Claude Code)\n"
                "== v0: risposta (sonnet, effort low)\n"
                "Controlli v0: 0 superati su 3\n  ✗ una riga\n"
                "  totali: controlli 0/3 → 3/3\n")
REGOLA = ("- **v0** è il prompt di partenza, e non si tocca;\n"
          "- ogni numero dopo v0 parte da una copia della versione "
          "precedente e mette alla prova una pratica, una sola;\n"
          "- nessuna versione si copia da una più vecchia della precedente.\n")


def scrivi(base: str, rel: str, testo: str) -> None:
    """Scrive un file della lezione, creando le cartelle."""
    percorso = os.path.join(base, rel)
    os.makedirs(os.path.dirname(percorso), exist_ok=True)
    with open(percorso, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(testo)


def versione(famiglia: str, numero: int) -> str:
    """Il prompt di una versione, nel template, un tag per ingrediente."""
    tag, nome = DATO[famiglia]
    riferimento = RIF[famiglia] if numero == 2 else None
    contesto = "I dati sono tra i tag <%s>." % tag
    if numero == 2:
        contesto += " Serve al collega di turno."
    if riferimento:
        contesto += " Il riferimento è tra i tag <%s>." % riferimento[0]
    righe = ["<role>", "Sei un collaudo.", "</role>", "", "<context>",
             contesto, "</context>", "", "<instructions>", "Prova.",
             "</instructions>", "", "<format>", "Breve.", "</format>", "",
             "<constraints>", "Scrivi solo questo.", "</constraints>", "",
             "<%s>" % tag, "{{%s}}" % nome, "</%s>" % tag]
    if riferimento:
        righe += ["", "<%s>" % riferimento[0], "{{%s}}" % riferimento[1],
                  "</%s>" % riferimento[0]]
    return "\n".join(righe) + "\n"


def rientra(testo: str) -> str:
    """Il testo di un blocco, rientrato come in un elenco Markdown."""
    return "\n".join("       " + r if r else ""
                     for r in testo.rstrip("\n").split("\n"))


def blocco_prompt(nome: str, testo: str) -> str:
    """Un prompt fra i suoi marcatori."""
    return "   <!-- prompt %s -->\n\n%s\n\n   <!-- /prompt %s -->\n\n" % (
        nome, rientra(testo), nome)


def corpo(titolo: str) -> str:
    """Il testo di una sottosezione della teoria."""
    if titolo == "Che cos'è una pratica":
        return "Una **pratica** è una frase di prova.\n"
    if titolo == "La regola delle versioni":
        return REGOLA
    return "Testo di %s.\n" % titolo


def titoli_teoria(voce: str, soli: Sequence[str]) -> List[str]:
    """Le sottosezioni della teoria, nell'ordine di quell'esercitazione."""
    titoli = list(COMUNI[:3])
    if voce == "E02":
        titoli[1:1] = [soli[0]]
        titoli.insert(titoli.index(COMUNI[2]) + 1, soli[1])
        resto = list(soli[2:])
    else:
        titoli.append(soli[0])
        resto = list(soli[1:])
    return titoli + list(COMUNI[3:]) + resto


def readme(voce: str, soli: Sequence[str], prompt: Sequence[str]) -> str:
    """Un README che passa ogni controllo."""
    parti = ["# Lezione finta\n\n"]
    for sezione in SEZIONI:
        parti.append("## %s\n\n" % sezione)
        if sezione == "La teoria che serve":
            parti.append("Apertura comune.\n\n")
            for titolo in titoli_teoria(voce, soli):
                parti.append("### %s\n\n%s\n" % (titolo, corpo(titolo)))
        elif sezione == "La soluzione, passo per passo":
            parti.append("Provate prima da soli. La risolvo con la prova "
                         "del docente dell'8 novembre 2026, Claude Code "
                         "2.1.319.\n\n1. Lancio:\n\n")
            parti += prompt
            parti.append("   <!-- estratto trascrizione.txt -->\n\n"
                         "       Controlli v0: 0 superati su 3\n       […]\n"
                         "       totali: controlli 0/3 → 3/3\n\n"
                         "   <!-- /estratto -->\n")
        else:
            parti.append("Testo.\n\n")
    return "".join(parti)


def scrivi_e01(base: str) -> None:
    """La lezione finta di M2-E01."""
    v1 = versione("supporto", 1)
    scrivi(base, "E01/esercizio/prompt/v0.md", "prova\n\n{{messaggio}}\n")
    scrivi(base, "E01/soluzione/prompt/v0.md", "prova\n\n{{messaggio}}\n")
    scrivi(base, "E01/soluzione/prompt/v1.md", v1)
    scrivi(base, "E01/soluzione/trascrizione.txt", TRASCRIZIONE)
    scrivi(base, "E01/README.md",
           readme("E01", SOLO_E01, [blocco_prompt("v1", v1)]))


def scrivi_e02(base: str) -> None:
    """La lezione finta di M2-E02: tre famiglie, v1 e v2."""
    blocchi = []
    for famiglia in DATO:
        partenza = "prova %s\n" % famiglia
        scrivi(base, "E02/esercizio/%s/prompt/v0.md" % famiglia, partenza)
        scrivi(base, "E02/soluzione/%s/prompt/v0.md" % famiglia, partenza)
        for numero in (1, 2):
            testo = versione(famiglia, numero)
            scrivi(base, "E02/soluzione/%s/prompt/v%d.md" % (famiglia, numero),
                   testo)
            blocchi.append(blocco_prompt("%s/v%d" % (famiglia, numero), testo))
    scrivi(base, "E02/soluzione/trascrizione.txt", TRASCRIZIONE)
    scrivi(base, "E02/README.md", readme("E02", SOLO_E02, blocchi))


def main(argv: List[str]) -> int:
    """Scrive le due lezioni in argv[0]."""
    if len(argv) != 1:
        sys.stderr.write("uso: lezione_finta.py <cartella>\n")
        return 2
    try:
        scrivi_e01(argv[0])
        scrivi_e02(argv[0])
    except OSError as exc:
        sys.stderr.write("lezione_finta: %s\n" % exc)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
