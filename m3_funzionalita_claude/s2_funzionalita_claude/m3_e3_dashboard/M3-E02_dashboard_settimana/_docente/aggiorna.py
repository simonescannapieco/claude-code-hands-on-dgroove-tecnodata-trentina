#!/usr/bin/env python3
"""aggiorna.py di M3-E02 -- le copie di M3-E01 in questo elemento e il
riferimento calcolato, per il docente.

M3-E02 parte dai file che produce M3-E01. Chi non ha finito M3-E01 usa le
copie di riferimento di questo elemento, che restano uguali byte per byte a
quelle di M3-E01:
  kpi_veri.py                    <- M3-E01 kpi_veri.py
  esercizio/kpi_definizioni.md   <- M3-E01 esercizio/kpi_definizioni.md
  esercizio/ticket-anonimi.csv   <- M3-E01 soluzione/anonimo/ticket-anonimi.csv
e soluzione/kpi.json è il riferimento calcolato: i KPI veri del file
anonimo, scritti come li stampa kpi_veri.py (le chiavi in ordine, rientro di
due spazi, un a capo in fondo). Lo calcola lo script, non un modello.

Senza opzioni riscrive le copie e il riferimento; con --controlla non scrive
niente e dice se sono uguali. Si rilancia quando cambia M3-E01: la sua
soluzione, kpi_veri.py o kpi_definizioni.md.

Uso:    python3 -B -I _docente/aggiorna.py [--controlla]
Env:    PN_M3_E01  la cartella di M3-E01 (default: quella del modulo)
Uscita: 0 scritto, o con --controlla tutto uguale · 1 con --controlla
        qualcosa è diverso (e dice che cosa) · 2 precondizione (argomenti,
        M3-E01 o un suo file che mancano, i KPI che non si calcolano, un
        file che non si scrive)
"""
from __future__ import annotations

import importlib.util
import json
import os
import sys
from typing import List, Sequence, Tuple

ELEMENTO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SEZIONE = os.path.dirname(os.path.dirname(ELEMENTO))
E01 = os.environ.get("PN_M3_E01") or os.path.join(
    SEZIONE, "m3_e2_anonimizzare", "M3-E01_anonimizzare_ticket")
# (da M3-E01, in questo elemento)
COPIE = (
    ("kpi_veri.py", "kpi_veri.py"),
    ("esercizio/kpi_definizioni.md", "esercizio/kpi_definizioni.md"),
    ("soluzione/anonimo/ticket-anonimi.csv", "esercizio/ticket-anonimi.csv"),
)
RIFERIMENTO = "soluzione/kpi.json"


class Precondizione(Exception):
    """Lo script non può fare il suo lavoro: uscita 2."""


def leggi(percorso: str) -> bytes:
    try:
        with open(percorso, "rb") as fh:
            return fh.read()
    except OSError as exc:
        raise Precondizione("%s non si legge (%s)" % (
            percorso, exc.strerror or type(exc).__name__))


def kpi_json(csv_: str) -> bytes:
    """I KPI veri del file, come li stampa kpi_veri.py di M3-E01."""
    percorso = os.path.join(E01, "kpi_veri.py")
    try:
        spec = importlib.util.spec_from_file_location("kpi_veri_e01",
                                                      percorso)
        if spec is None or spec.loader is None:
            raise ImportError("nessun caricatore")
        kv = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(kv)  # type: ignore[union-attr]
        kpi = kv.arrotonda(kv.esatti(csv_))
    except (ImportError, OSError, SyntaxError) as exc:
        raise Precondizione("%s non si carica (%s)" % (percorso, exc))
    except Exception as exc:  # la Precondizione di kpi_veri
        raise Precondizione("i KPI di %s non si calcolano (%s)"
                            % (csv_, exc))
    testo = json.dumps(kpi, ensure_ascii=False, indent=2, sort_keys=True)
    return (testo + "\n").encode("utf-8")


def attesi() -> List[Tuple[str, bytes, str]]:
    """(il percorso nell'elemento, i byte attesi, da dove vengono)."""
    if not os.path.isdir(E01):
        raise Precondizione("M3-E01 non c'è: %s" % E01)
    voci = [(dest, leggi(os.path.join(E01, sorgente)), "M3-E01 " + sorgente)
            for sorgente, dest in COPIE]
    csv_ = os.path.join(E01, COPIE[2][0])
    voci.append((RIFERIMENTO, kpi_json(csv_),
                 "kpi_veri.py sul file anonimo di M3-E01"))
    return voci


def controlla(voci: Sequence[Tuple[str, bytes, str]]) -> int:
    diversi = 0
    for dest, dati, origine in voci:
        percorso = os.path.join(ELEMENTO, dest)
        if not os.path.isfile(percorso):
            stato = "MANCA"
            diversi += 1
        elif leggi(percorso) == dati:
            stato = "uguale"
        else:
            stato = "DIVERSO"
            diversi += 1
        print("  %-30s %-8s (%s)" % (dest, stato, origine))
    if diversi:
        print("aggiorna: %d file da aggiornare: python3 -B -I "
              "_docente/aggiorna.py" % diversi)
        return 1
    print("aggiorna: le copie e il riferimento sono identici byte per byte.")
    return 0


def scrivi(voci: Sequence[Tuple[str, bytes, str]]) -> int:
    for dest, dati, origine in voci:
        percorso = os.path.join(ELEMENTO, dest)
        try:
            os.makedirs(os.path.dirname(percorso), exist_ok=True)
            with open(percorso, "wb") as fh:
                fh.write(dati)
        except OSError as exc:
            raise Precondizione("%s non si scrive (%s)" % (
                dest, exc.strerror or type(exc).__name__))
        print("  %-30s scritto (%s)" % (dest, origine))
    return 0


def main(argv: Sequence[str]) -> int:
    if list(argv) in (["-h"], ["--help"]):
        print((__doc__ or "").strip())
        return 0
    if list(argv) not in ([], ["--controlla"]):
        sys.stderr.write("uso: python3 -B -I _docente/aggiorna.py "
                         "[--controlla]\n")
        return 2
    try:
        voci = attesi()
        return controlla(voci) if argv else scrivi(voci)
    except Precondizione as exc:
        sys.stderr.write("aggiorna: %s\n" % exc)
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
