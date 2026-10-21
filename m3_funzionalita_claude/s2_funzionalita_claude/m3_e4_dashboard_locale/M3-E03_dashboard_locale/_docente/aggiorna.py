#!/usr/bin/env python3
"""aggiorna.py di M3-E03 -- le copie di M3-E01 in questo elemento e i
riferimenti prodotti dalla soluzione, per il docente.

M3-E03 parte dai file che produce M3-E01. Chi non ha finito M3-E01 usa le
copie di riferimento di questo elemento, che restano uguali byte per byte a
quelle di M3-E01:
  kpi_veri.py                           <- M3-E01 kpi_veri.py
  esercizio/kpi_definizioni.md          <- M3-E01 esercizio/kpi_definizioni.md
  esercizio/anonimo/ticket-anonimi.csv  <- M3-E01 soluzione/anonimo/ticket-anonimi.csv
  esercizio/anonimo/profilo.json        <- M3-E01 soluzione/anonimo/profilo.json
Poi i riferimenti di soluzione/, prodotti eseguendo gli script in uno spazio
di lavoro temporaneo fatto con quelle copie, mai scritti a mano né da un
modello:
  soluzione/dashboard.html             python3 genera_dashboard.py
  soluzione/controlli_dashboard.log    python3 controlla_dashboard.py, una
                                        volta, sulla pagina appena scritta

Senza opzioni riscrive le copie e i riferimenti; con --controlla non scrive
niente e dice se le copie e la pagina sono uguali (la pagina si rigenera
nello spazio temporaneo) e se il registro ha la forma di un'esecuzione
passata. Si rilancia quando cambia M3-E01, genera_dashboard.py o
controlla_dashboard.py.

Uso:    python3 -B -I _docente/aggiorna.py [--controlla]
Env:    PN_M3_E01  la cartella di M3-E01 (default: quella del modulo)
Uscita: 0 scritto, o con --controlla tutto uguale · 1 con --controlla
        qualcosa è diverso (e dice che cosa) · 2 precondizione (argomenti,
        M3-E01 o un file che mancano, uno script della soluzione o il
        controllo che non passano, un file che non si scrive)
"""
from __future__ import annotations

import os
import re
import shutil
import subprocess
import sys
import tempfile
from typing import List, Sequence, Tuple

ELEMENTO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SEZIONE = os.path.dirname(os.path.dirname(ELEMENTO))
E01 = os.environ.get("PN_M3_E01") or os.path.join(
    SEZIONE, "m3_e2_anonimizzare", "M3-E01_anonimizzare_ticket")
# (da M3-E01, in questo elemento)
COPIE = (
    ("kpi_veri.py", "kpi_veri.py"),
    ("esercizio/kpi_definizioni.md", "esercizio/kpi_definizioni.md"),
    ("soluzione/anonimo/ticket-anonimi.csv",
     "esercizio/anonimo/ticket-anonimi.csv"),
    ("soluzione/anonimo/profilo.json", "esercizio/anonimo/profilo.json"),
)
GENERA = os.path.join(ELEMENTO, "soluzione", "genera_dashboard.py")
CONTROLLO = os.path.join(ELEMENTO, "esercizio", "controlla_dashboard.py")
PAGINA = "soluzione/dashboard.html"
REGISTRO = "soluzione/controlli_dashboard.log"
RIGA_PASSATA = re.compile(rb"\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ\t0\t0\n")


class Precondizione(Exception):
    """Lo script non può fare il suo lavoro: uscita 2."""


def leggi(percorso: str) -> bytes:
    try:
        with open(percorso, "rb") as fh:
            return fh.read()
    except OSError as exc:
        raise Precondizione("%s non si legge (%s)" % (
            percorso, exc.strerror or type(exc).__name__))


def esegui(cartella: str, script: str) -> None:
    risultato = subprocess.run(
        [sys.executable, "-B", script], cwd=cartella,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False)
    if risultato.returncode != 0:
        coda = risultato.stdout.decode("utf-8", "replace").strip()[-300:]
        raise Precondizione("%s è uscito con %d: %s"
                            % (script, risultato.returncode, coda))


def riferimenti(copie: List[Tuple[str, bytes, str]]) -> Tuple[bytes, bytes]:
    """(la pagina, il registro) prodotti in uno spazio di lavoro
    temporaneo con le copie di M3-E01 e gli script dell'elemento."""
    with tempfile.TemporaryDirectory(prefix="m3-e03-") as tmp:
        for dest, dati, _ in copie:
            if dest.startswith("esercizio/"):
                percorso = os.path.join(tmp, dest[len("esercizio/"):])
                os.makedirs(os.path.dirname(percorso), exist_ok=True)
                with open(percorso, "wb") as fh:
                    fh.write(dati)
        for script in (GENERA, CONTROLLO):
            if not os.path.isfile(script):
                raise Precondizione("manca %s" % script)
            shutil.copyfile(script, os.path.join(tmp,
                                                 os.path.basename(script)))
        esegui(tmp, "genera_dashboard.py")
        esegui(tmp, "controlla_dashboard.py")
        return (leggi(os.path.join(tmp, "dashboard.html")),
                leggi(os.path.join(tmp, "controlli_dashboard.log")))


def attesi() -> Tuple[List[Tuple[str, bytes, str]], bytes, bytes]:
    if not os.path.isdir(E01):
        raise Precondizione("M3-E01 non c'è: %s" % E01)
    copie = [(dest, leggi(os.path.join(E01, sorgente)), "M3-E01 " + sorgente)
             for sorgente, dest in COPIE]
    pagina, registro = riferimenti(copie)
    return copie, pagina, registro


def stato(dest: str, dati: bytes) -> str:
    percorso = os.path.join(ELEMENTO, dest)
    if not os.path.isfile(percorso):
        return "MANCA"
    return "uguale" if leggi(percorso) == dati else "DIVERSO"


def controlla(copie: List[Tuple[str, bytes, str]], pagina: bytes) -> int:
    voci = [(d, stato(d, b), o) for d, b, o in copie]
    voci.append((PAGINA, stato(PAGINA, pagina),
                 "genera_dashboard.py sulle copie"))
    registro = os.path.join(ELEMENTO, REGISTRO)
    if not os.path.isfile(registro):
        forma = "MANCA"
    elif RIGA_PASSATA.fullmatch(leggi(registro)):
        forma = "uguale"
    else:
        forma = "DIVERSO"
    voci.append((REGISTRO, forma, "una riga: ora UTC, uscita 0, 0 "
                 "differenze"))
    for dest, risultato, origine in voci:
        print("  %-38s %-8s (%s)" % (dest, risultato, origine))
    diversi = sum(1 for _, r, _ in voci if r != "uguale")
    if diversi:
        print("aggiorna: %d file da aggiornare: python3 -B -I "
              "_docente/aggiorna.py" % diversi)
        return 1
    print("aggiorna: le copie e i riferimenti sono quelli attesi.")
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
        print("  %-38s scritto (%s)" % (dest, origine))
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
        copie, pagina, registro = attesi()
        if argv:
            return controlla(copie, pagina)
        return scrivi(copie + [
            (PAGINA, pagina, "genera_dashboard.py sulle copie"),
            (REGISTRO, registro, "controlla_dashboard.py sulla pagina")])
    except Precondizione as exc:
        sys.stderr.write("aggiorna: %s\n" % exc)
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
