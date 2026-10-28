#!/usr/bin/env python3
"""verita.py di M4-E05 -- la verità della verifica, per il docente: il
disservizio che la verifica conosce, il giorno tranquillo e, per gli altri
giorni, l'apparato e l'inizio, come impronte.

Li ricava due volte e pretende che coincidano:
  - dalla mappa del docente, progetti/rete/_docente/README.md («Gli
    avvenimenti della settimana nei log»): il taglio della fibra di
    martedì 8 (apparato, porta, inizio, fine, linee) e, dove la mappa lo
    scrive, l'ora d'inizio degli altri;
  - dalle regole di SPECIFICA.md applicate ai log di progetti/rete/log/
    con lo script di riferimento (soluzione/rapporto_giornaliero.py): la
    riga di martedì dell'apparato della mappa, nessuna riga lunedì 7, e
    negli altri giorni la prima riga dell'apparato della mappa.
Poi scrive le impronte SHA-256 di «m4-e05:<campo>:<apparato>[:<valore>]»,
mai i valori.

Uso:    python3 _docente/verita.py            stampa il JSON su stdout (è
                                              il contenuto di verita.json)
        python3 _docente/verita.py --check [--verita <file>]
                                              confronta con verita.json
Env:    PN_HANDSON_ROOT  il repository (default: la radice sopra l'elemento)
Uscita: 0 stampato, o verita.json conferma i dati · 1 verita.json è
        diversa · 2 precondizione (log, mappa o riferimento illeggibili; la
        mappa e le regole non coincidono)
"""
import hashlib
import importlib.util
import json
import os
import re
import sys
from types import ModuleType
from typing import Dict, List, Optional, Tuple

ELEMENTO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SALE = "m4-e05"
RICHIESTO = "2026-09-08"
TRANQUILLO = "2026-09-07"
FIBRA = re.compile(r"\*\*Martedì 8, (\d\d:\d\d)–(\d\d:\d\d) — fibra tagliata "
                   r"sulla porta PON (\d+/\d+/\d+) di `([a-z0-9-]+)`\*\* "
                   r"\((\d+) linee")
# giorno, nome, apparato della mappa, ora d'inizio scritta nella mappa
DATI = (("2026-09-09", "mercoledì 9", "ptp-trento-01", "09:41"),
        ("2026-09-10", "giovedì 10", "bng-trento-01", "02:03"),
        ("2026-09-11", "venerdì 11", "sbc-trento-01", "07:53"),
        ("2026-09-12", "sabato 12", "dhcp-trento-01", None),
        ("2026-09-13", "domenica 13", "dhcp-trento-01", "10:00"))
NOTA = ("Impronte SHA-256 di «m4-e05:<campo>:<apparato>[:<valore>]»: il "
        "disservizio che la verifica conosce, nel giorno richiesto, e per "
        "gli altri giorni l'apparato e l'inizio; il giorno tranquillo. La "
        "verifica le confronta con le righe del rapporto, senza mai "
        "scriverle in chiaro.")


class Precondizione(Exception):
    """La verità non si ricava: uscita 2."""


def impronta(campo: str, apparato: str, valore: str = "") -> str:
    testo = "%s:%s:%s" % (SALE, campo, apparato) + (
        ":" + valore if campo != "apparato" else "")
    return hashlib.sha256(testo.encode("utf-8")).hexdigest()


def riferimento() -> ModuleType:
    percorso = os.path.join(ELEMENTO, "soluzione", "rapporto_giornaliero.py")
    spec = importlib.util.spec_from_file_location("riferimento", percorso)
    if spec is None or spec.loader is None:
        raise Precondizione("manca %s" % percorso)
    modulo = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(modulo)  # type: ignore[union-attr]
    return modulo


def rapporto(rif: ModuleType, log: str, giorno: str) -> List[Tuple[str, ...]]:
    """Le righe del rapporto di un giorno, con le regole del riferimento."""
    try:
        righe = rif.leggi_giorno(log, giorno)
    except rif.Errore as exc:
        raise Precondizione(str(exc))
    return sorted(rif.dal_syslog(righe["syslog"]) + rif.dal_sip(righe["sip"])
                  + rif.dal_dhcp(righe["dhcp"]), key=lambda d: (d[2], d[0]))


def dalla_mappa(mappa: str) -> Tuple[str, str, str, str, str]:
    """Il taglio della fibra di martedì: apparato, porta, inizio, fine,
    linee."""
    m = FIBRA.search(mappa)
    if m is None:
        raise Precondizione("la mappa del docente non descrive il taglio "
                            "della fibra di martedì 8")
    inizio, fine, porta, apparato, linee = m.groups()
    return apparato, porta, inizio, fine, linee


def verita(radice: str) -> dict:
    """Il contenuto di verita.json."""
    log = os.path.join(radice, "progetti", "rete", "log")
    with open(os.path.join(radice, "progetti", "rete", "_docente",
                           "README.md"), encoding="utf-8") as fh:
        mappa = fh.read()
    rif = riferimento()
    attesa = dalla_mappa(mappa)
    righe = [r for r in rapporto(rif, log, RICHIESTO) if r[0] == attesa[0]]
    if [r[:5] for r in righe] != [attesa]:
        raise Precondizione("la mappa del docente e le regole non "
                            "coincidono su martedì 8: %r" % righe)
    if rapporto(rif, log, TRANQUILLO):
        raise Precondizione("con le regole lunedì 7 non è tranquillo")
    dati = []
    for giorno, nome, apparato, ora in DATI:
        sue = [r for r in rapporto(rif, log, giorno) if r[0] == apparato]
        inizio = sue[0][2] if sue else None  # type: Optional[str]
        if inizio is None or (ora is not None and (
                inizio != ora or ora not in mappa)):
            raise Precondizione("la mappa del docente e le regole non "
                                "coincidono su %s" % nome)
        dati.append({"giorno": giorno, "nome": nome,
                     "apparato": impronta("apparato", apparato),
                     "inizio": impronta("inizio", apparato, inizio)})
    richiesto = {"giorno": RICHIESTO, "nome": "martedì 8 settembre"}
    richiesto.update({c: impronta(c, attesa[0], v) for c, v in zip(
        ("apparato", "porta", "inizio", "fine", "linee"), attesa)})
    return {"elemento": "M4-E05", "nota": NOTA, "richiesto": richiesto,
            "tranquillo": TRANQUILLO, "dati": dati}


def main(argv: List[str]) -> int:
    radice = os.environ.get("PN_HANDSON_ROOT") or os.path.normpath(
        os.path.join(ELEMENTO, *[os.pardir] * 4))
    try:
        attesa = verita(radice)
    except (Precondizione, OSError, ImportError) as exc:
        sys.stderr.write("verita: %s\n" % exc)
        return 2
    if "--check" not in argv:
        sys.stdout.write(json.dumps(attesa, ensure_ascii=False, indent=2)
                         + "\n")
        return 0
    file = os.path.join(ELEMENTO, "verita.json")
    if "--verita" in argv and argv.index("--verita") + 1 < len(argv):
        file = argv[argv.index("--verita") + 1]
    try:
        with open(file, encoding="utf-8") as fh:
            uguale = json.load(fh) == attesa
    except (OSError, ValueError) as exc:
        sys.stderr.write("verita: %s non si legge (%s)\n" % (file, exc))
        return 2
    if not uguale:
        print("%s è diversa da ciò che dicono i log e la mappa del docente"
              % file)
        return 1
    print("verita.json conferma i dati: il disservizio di martedì 8, il "
          "giorno tranquillo, %d altri giorni" % len(attesa["dati"]))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
