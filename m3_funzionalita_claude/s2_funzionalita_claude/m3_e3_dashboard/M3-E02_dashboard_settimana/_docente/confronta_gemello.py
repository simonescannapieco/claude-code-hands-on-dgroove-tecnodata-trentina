#!/usr/bin/env python3
"""confronta_gemello.py di M3-E02 -- la coppia registrata dal docente: la
tabella incollata nel messaggio contro il file interrogato con il codice.

Legge le esecuzioni di claude -p --output-format json --json-schema della
coppia, in una cartella: incollato-<n>.json (il CSV incollato nel
messaggio, nessuno strumento) e file-<n>.json (il CSV nella cartella di
lavoro, Bash limitato a python3, senza Read), di solito n = 1, 2, 3. Per
ogni esecuzione conta i KPI giusti dell'oggetto structured_output con
kpi_veri.confronta (la regola di kpi_definizioni.md) sul CSV della
settimana, e stampa come dato i token in entrata (input, più cache scritta e
letta) e in uscita, il modello e i turni. Un'esecuzione fallita (un JSON che
non si legge, is_error, nessun structured_output) conta 0 KPI giusti, e lo
dice.

Per ogni coppia n, incollato-n contro file-n, l'esito dell'affermazione
«When the model has to compute over a table … let the model query it with
code execution instead of pasting it in.»: confermata se con il file e il
codice sono giusti più KPI, non distinguibile se sono tanti quanti, non
confermata in questa esecuzione se sono meno; poi in quante coppie su
quante è confermata. L'esito si stampa: non è mai l'uscita, e nessun esito
dice che l'affermazione è falsa.

Uso:    confronta_gemello.py [--csv <file>] [--json] [cartella]
          cartella  le esecuzioni (default: gemello/ nella cartella
                    corrente)
          --csv     il CSV dei KPI veri (default: esercizio/ticket-anonimi.csv
                    di questo elemento)
          --json    il risultato in JSON, per la registrazione
Uscita: 0 misurato · 2 precondizione (argomenti, nessuna coppia o una
        coppia incompleta, il CSV o kpi_veri.py dell'elemento che mancano o
        non si caricano, un'esecuzione che c'è ma non si legge dal disco)
"""
from __future__ import annotations

import importlib.util
import json
import os
import re
import sys
from types import ModuleType
from typing import Any, Dict, List, NamedTuple, Optional, Sequence, Tuple

ELEMENTO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KPI_VERI = os.path.join(ELEMENTO, "kpi_veri.py")
CSV_PREDEFINITO = os.path.join(ELEMENTO, "esercizio", "ticket-anonimi.csv")
CARTELLA_PREDEFINITA = "gemello"
BRACCI = ("incollato", "file")
NOME = re.compile(r"(incollato|file)-([1-9][0-9]*)\.json")
AFFERMAZIONE = ("«When the model has to compute over a table … let the "
                "model query it with code execution instead of pasting it "
                "in.»")
FONTE = ("https://platform.claude.com/docs/en/about-claude/models/"
         "optimizing-for-cost-and-intelligence")
REGOLA = ("confermata se con il file e il codice sono giusti più KPI, non "
          "distinguibile se sono tanti quanti, non confermata in questa "
          "esecuzione se sono meno; un'esecuzione fallita conta 0")


class Precondizione(Exception):
    """Il confronto non può girare: uscita 2."""


class Esecuzione(NamedTuple):
    """Una chiamata della coppia, misurata."""
    braccio: str
    n: int
    giusti: int
    totale: int
    sbagliati: List[str]
    fallita: str
    token_in: Optional[int]
    token_out: Optional[int]
    modelli: List[str]
    turni: Optional[int]


def carica(percorso: str) -> ModuleType:
    if not os.path.isfile(percorso):
        raise Precondizione("manca %s" % percorso)
    try:
        spec = importlib.util.spec_from_file_location("kpi_veri_gemello",
                                                      percorso)
        if spec is None or spec.loader is None:
            raise ImportError("nessun caricatore")
        modulo = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(modulo)  # type: ignore[union-attr]
    except (ImportError, OSError, SyntaxError) as exc:
        raise Precondizione("%s non si carica (%s)" % (percorso, exc))
    return modulo


def coppie(cartella: str) -> List[int]:
    """I numeri delle coppie complete; Precondizione se nessuna, o se a un
    numero manca un braccio."""
    try:
        nomi = os.listdir(cartella)
    except OSError as exc:
        raise Precondizione("la cartella %s non si legge (%s)" % (
            cartella, exc.strerror or type(exc).__name__))
    trovati: Dict[int, set] = {}
    for nome in nomi:
        m = NOME.fullmatch(nome)
        if m:
            trovati.setdefault(int(m.group(2)), set()).add(m.group(1))
    if not trovati:
        raise Precondizione("nessuna esecuzione in %s (attese "
                            "incollato-<n>.json e file-<n>.json)" % cartella)
    for n in sorted(trovati):
        mancanti = [b for b in BRACCI if b not in trovati[n]]
        if mancanti:
            raise Precondizione("la coppia %d è incompleta: manca %s-%d.json"
                                % (n, mancanti[0], n))
    return sorted(trovati)


def intero(valore: Any) -> Optional[int]:
    return valore if isinstance(valore, int) and \
        not isinstance(valore, bool) else None


def token(dati: Dict[str, Any]) -> Tuple[Optional[int], Optional[int]]:
    """(token in entrata, in uscita) dall'usage del JSON."""
    uso = dati.get("usage")
    if not isinstance(uso, dict):
        return None, None
    entrata = [intero(uso.get(k)) for k in (
        "input_tokens", "cache_creation_input_tokens",
        "cache_read_input_tokens")]
    totale = sum(v for v in entrata if v is not None)
    return (totale if any(v is not None for v in entrata) else None,
            intero(uso.get("output_tokens")))


def misura(kv: ModuleType, percorso: str, braccio: str, n: int,
           csv_: str) -> Esecuzione:
    """Una chiamata: i KPI giusti, o perché è fallita."""
    try:
        with open(percorso, "rb") as fh:
            grezzo = fh.read()
    except OSError as exc:
        raise Precondizione("%s non si legge (%s)" % (
            percorso, exc.strerror or type(exc).__name__))
    totale = len(kv.CHIAVI)
    try:
        dati = json.loads(grezzo.decode("utf-8"))
    except (UnicodeDecodeError, ValueError, RecursionError):
        return Esecuzione(braccio, n, 0, totale, [], "il JSON non si legge",
                          None, None, [], None)
    if not isinstance(dati, dict):
        return Esecuzione(braccio, n, 0, totale, [],
                          "non è il JSON di claude -p", None, None, [], None)
    entrata, uscita = token(dati)
    modelli = sorted(dati["modelUsage"]) if isinstance(
        dati.get("modelUsage"), dict) else []
    turni = intero(dati.get("num_turns"))
    oggetto = dati.get("structured_output")
    if dati.get("is_error") is True:
        fallita = "is_error: la chiamata è fallita"
    elif not isinstance(oggetto, dict):
        fallita = "nessun structured_output"
    else:
        voci = kv.confronta(oggetto, csv_)
        sbagliati = [k for k, _, _, ok in voci if not ok]
        giusti = sum(1 for k, _, _, ok in voci if ok and k in kv.CHIAVI)
        return Esecuzione(braccio, n, giusti, totale, sbagliati, "", entrata,
                          uscita, modelli, turni)
    return Esecuzione(braccio, n, 0, totale, [], fallita, entrata, uscita,
                      modelli, turni)


def esito(incollato: Esecuzione, file_: Esecuzione) -> str:
    if file_.giusti > incollato.giusti:
        return "confermata"
    if file_.giusti == incollato.giusti:
        return "non distinguibile"
    return "non confermata in questa esecuzione"


def numero(valore: Optional[int]) -> str:
    return "—" if valore is None else str(valore)


def stampa(csv_: str, esecuzioni: List[Esecuzione],
           esiti: List[Tuple[int, Esecuzione, Esecuzione, str]]) -> None:
    print("M3-E02, la coppia del docente: la tabella incollata nel messaggio")
    print("contro il file interrogato con il codice")
    print("KPI veri calcolati da: %s\n" % csv_)
    print("  %-14s %-11s %-17s %-16s %s" % (
        "esecuzione", "KPI giusti", "token in entrata", "token in uscita",
        "modello"))
    for e in esecuzioni:
        print("  %-14s %-11s %-17s %-16s %s" % (
            "%s-%d" % (e.braccio, e.n), "%d su %d" % (e.giusti, e.totale),
            numero(e.token_in), numero(e.token_out),
            ", ".join(e.modelli) or "—"))
        if e.fallita:
            print("  %-14s esecuzione fallita: %s" % ("", e.fallita))
        elif e.sbagliati:
            print("  %-14s sbagliati: %s" % ("", ", ".join(e.sbagliati)))
    print("\nL'affermazione: %s" % AFFERMAZIONE)
    print("  (%s)" % FONTE)
    for n, inc, fil, risultato in esiti:
        print("  coppia %d: incollato %d, file %d KPI giusti: %s"
              % (n, inc.giusti, fil.giusti, risultato))
    confermate = sum(1 for *_, r in esiti if r == "confermata")
    print("  In questa registrazione: confermata %d su %d." % (
        confermate, len(esiti)))
    print("  La regola: %s. I token sono un dato." % REGOLA)


def in_json(csv_: str, esecuzioni: List[Esecuzione],
            esiti: List[Tuple[int, Esecuzione, Esecuzione, str]]) -> str:
    risultato = {
        "affermazione": AFFERMAZIONE, "fonte": FONTE, "regola": REGOLA,
        "csv": csv_,
        "esecuzioni": [e._asdict() for e in esecuzioni],
        "coppie": [{"n": n, "incollato": i.giusti, "file": f.giusti,
                    "esito": r} for n, i, f, r in esiti],
        "confermate": sum(1 for *_, r in esiti if r == "confermata"),
        "coppie_totali": len(esiti),
    }
    return json.dumps(risultato, ensure_ascii=False, indent=2)


def argomenti(argv: Sequence[str]) -> Tuple[str, str, bool]:
    """(la cartella, il CSV, --json); ValueError se non vanno."""
    cartella, csv_, come_json = None, CSV_PREDEFINITO, False
    resto = list(argv)
    while resto:
        a = resto.pop(0)
        if a == "--json":
            come_json = True
        elif a == "--csv":
            if not resto:
                raise ValueError("--csv vuole un file")
            csv_ = resto.pop(0)
        elif a.startswith("-"):
            raise ValueError("opzione sconosciuta: %s" % a)
        elif cartella is None:
            cartella = a
        else:
            raise ValueError("una cartella sola")
    return cartella or CARTELLA_PREDEFINITA, csv_, come_json


def main(argv: Sequence[str]) -> int:
    if list(argv) in (["-h"], ["--help"]):
        print((__doc__ or "").strip())
        return 0
    try:
        cartella, csv_, come_json = argomenti(argv)
    except ValueError as exc:
        sys.stderr.write("confronta_gemello: %s\nuso: confronta_gemello.py "
                         "[--csv <file>] [--json] [cartella]\n" % exc)
        return 2
    try:
        kv = carica(KPI_VERI)
        if not os.path.isfile(csv_):
            raise Precondizione("manca il CSV %s" % csv_)
        try:
            kv.esatti(csv_)
        except kv.Precondizione as exc:
            raise Precondizione("i KPI veri non si calcolano (%s)" % exc)
        esecuzioni: List[Esecuzione] = []
        esiti: List[Tuple[int, Esecuzione, Esecuzione, str]] = []
        for n in coppie(cartella):
            inc, fil = (misura(kv, os.path.join(cartella, "%s-%d.json"
                                                % (b, n)), b, n, csv_)
                        for b in BRACCI)
            esecuzioni += [inc, fil]
            esiti.append((n, inc, fil, esito(inc, fil)))
    except Precondizione as exc:
        sys.stderr.write("confronta_gemello: %s\n" % exc)
        return 2
    if come_json:
        print(in_json(csv_, esecuzioni, esiti))
    else:
        stampa(csv_, esecuzioni, esiti)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
