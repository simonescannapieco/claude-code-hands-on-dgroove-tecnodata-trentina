#!/usr/bin/env python3
"""residui.py di M3-E01 -- i dati personali rimasti in un file, per il
docente.

Conta con il controllo originale dell'elemento (esercizio/controlla_pii.py
e esercizio/impronte.json, mai le copie di uno spazio di lavoro) i dati
personali rimasti, per classe, e lo stampa in JSON: mai un valore, e senza
scrivere niente (nessuna riga in controlli.log). Lo usano _docente/live.sh,
fra un turno e l'altro, e la coppia registrata con e senza il controllo.

Uso:
  residui.py <csv>
      {"file", "presente", "struttura", "residui", "totale", "in_parte",
      "omissioni_senza_dato"}: struttura è l'elenco dei problemi di forma
      rispetto al file grezzo (quelli di verifica.py; vuoto se la forma è
      giusta), residui i dati personali per classe (i nomi a metà accanto
      a un [OMESSO] compresi; null se il file manca o il controllo non può
      girare); in_parte e omissioni_senza_dato la misura dalle posizioni di
      verifica.py, come dato: per classe i dati del corso di cui resta una
      parte fuori dagli [OMESSO], e le omissioni che non coprono nessun
      dato del corso (null se un testo non è il grezzo con [OMESSO])
  residui.py --testo <file>
      un testo qualunque, così com'è (per esempio l'uscita stream-json di
      una sessione): {"file", "residui", "totale"}
  residui.py --coppia <csv con il controllo> <csv senza il controllo>
      i due file di una coppia, e l'esito dell'affermazione «Giving Claude
      a way to verify its work will markedly improve the quality of the
      final result.» in questa coppia: confermata se il file con il
      controllo è migliore, non distinguibile se uguale, non confermata in
      questa esecuzione se peggiore. Migliore: prima la forma giusta
      (struttura vuota), poi meno dati personali rimasti. Se uno dei due
      file manca, o il controllo non gira su di esso, la coppia non decide
      niente: non decidibile (in claude -p, per esempio, un comando fuori
      dalle regole è negato, dove un partecipante risponde).
Uscita: 0 misurato (l'esito si stampa: non è mai l'uscita) · 2
        precondizione (argomenti, un file originale dell'elemento che manca
        o non si carica, un file che c'è ma non si legge)
"""
from __future__ import annotations

import importlib.util
import json
import os
import sys
from types import ModuleType
from typing import Any, Dict, Optional, Sequence, Tuple

ELEMENTO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CONTROLLO = os.path.join(ELEMENTO, "esercizio", "controlla_pii.py")
IMPRONTE = os.path.join(ELEMENTO, "esercizio", "impronte.json")
VERIFICA = os.path.join(ELEMENTO, "verifica.py")
AFFERMAZIONE = ("«Giving Claude a way to verify its work will markedly "
                "improve the quality of the final result.»")
FONTE = ("https://support.claude.com/en/articles/14554000-claude-code-power-"
         "user-tips")
NON_DECIDIBILE = "non decidibile"


class Precondizione(Exception):
    """La misura non può girare: uscita 2."""


def carica(nome: str, percorso: str) -> ModuleType:
    """Un modulo dell'elemento; Precondizione se manca o non si carica."""
    if not os.path.isfile(percorso):
        raise Precondizione("manca %s" % percorso)
    try:
        spec = importlib.util.spec_from_file_location(nome, percorso)
        if spec is None or spec.loader is None:
            raise ImportError("nessun caricatore")
        modulo = importlib.util.module_from_spec(spec)
        sys.modules[nome] = modulo
        spec.loader.exec_module(modulo)  # type: ignore[union-attr]
    except (ImportError, OSError, SyntaxError) as exc:
        raise Precondizione("%s non si carica (%s)" % (percorso, exc))
    return modulo


class Misura:
    """Il controllo originale e la verifica dell'elemento, caricati una
    volta."""

    def __init__(self) -> None:
        self.cp = carica("controlla_pii_originale", CONTROLLO)
        self.verifica = carica("verifica_elemento", VERIFICA)
        try:
            self.impronte = self.cp.carica_impronte(IMPRONTE)
        except self.cp.Precondizione as exc:
            raise Precondizione("le impronte originali: %s" % exc)
        try:
            self.grezze = self.verifica.leggi_grezzo()
        except self.verifica.Precondizione as exc:
            raise Precondizione(str(exc))

    def per_classe(self, trovati: Sequence[str]) -> Dict[str, int]:
        conta = {c: 0 for c in self.cp.NOMI_CLASSI}
        for classe in trovati:
            conta[classe] += 1
        return conta

    def csv(self, percorso: str) -> Dict[str, Any]:
        """La misura di un file anonimo."""
        presente = os.path.exists(percorso)
        try:
            struttura, dati = self.verifica.controlla_file(percorso,
                                                           self.grezze)
        except self.verifica.Precondizione as exc:
            raise Precondizione(str(exc))
        residui: Optional[Dict[str, int]] = None
        if presente:
            try:
                esito = self.cp.esamina(percorso, self.impronte)
                residui = self.per_classe([r.classe for r in esito.residui])
            except self.cp.Precondizione as exc:
                struttura.append("il controllo non gira: %s" % exc)
        in_parte: Optional[Dict[str, int]] = None
        senza_dato: Optional[int] = None
        if dati.get("allineati") is not None:
            in_parte, senza_dato = self.verifica.misura_in_parte(
                self.cp, self.impronte, dati["allineati"])
        return {"file": percorso, "presente": presente,
                "struttura": struttura, "residui": residui,
                "totale": None if residui is None else sum(residui.values()),
                "in_parte": in_parte, "omissioni_senza_dato": senza_dato}

    def testo(self, percorso: str) -> Dict[str, Any]:
        """La misura di un testo qualunque, così com'è."""
        try:
            with open(percorso, encoding="utf-8", errors="replace") as fh:
                contenuto = fh.read()
        except OSError as exc:
            raise Precondizione("%s non si legge (%s)" % (
                percorso, exc.strerror or type(exc).__name__))
        trovati = [c for c, _, _ in self.cp.cerca(contenuto, self.impronte)]
        residui = self.per_classe(trovati)
        return {"file": percorso, "residui": residui,
                "totale": sum(residui.values())}


def qualita(misura: Dict[str, Any]) -> Tuple[int, int]:
    """La chiave d'ordine di un file misurato: più piccola, migliore."""
    return (1 if misura["struttura"] else 0, misura["totale"])


def esito_coppia(con: Dict[str, Any], senza: Dict[str, Any]) -> str:
    """L'esito della coppia (vedi il docstring del modulo): nessuno se un
    file non è misurato, perché manca o il controllo non gira su di esso."""
    if con["totale"] is None or senza["totale"] is None:
        return NON_DECIDIBILE
    if qualita(con) < qualita(senza):
        return "confermata"
    if qualita(con) == qualita(senza):
        return "non distinguibile"
    return "non confermata in questa esecuzione"


def main(argv: Sequence[str]) -> int:
    if list(argv[:1]) in (["-h"], ["--help"]):
        print((__doc__ or "").strip())
        return 0
    try:
        if len(argv) == 1 and not argv[0].startswith("-"):
            risultato: Any = Misura().csv(argv[0])
        elif len(argv) == 2 and argv[0] == "--testo":
            risultato = Misura().testo(argv[1])
        elif len(argv) == 3 and argv[0] == "--coppia":
            misura = Misura()
            con, senza = misura.csv(argv[1]), misura.csv(argv[2])
            risultato = {"con_il_controllo": con, "senza_il_controllo": senza,
                         "affermazione": AFFERMAZIONE, "fonte": FONTE,
                         "esito": esito_coppia(con, senza)}
        else:
            sys.stderr.write("uso: residui.py <csv> | --testo <file> | "
                             "--coppia <csv con> <csv senza>\n")
            return 2
    except Precondizione as exc:
        sys.stderr.write("residui: %s\n" % exc)
        return 2
    print(json.dumps(risultato, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
