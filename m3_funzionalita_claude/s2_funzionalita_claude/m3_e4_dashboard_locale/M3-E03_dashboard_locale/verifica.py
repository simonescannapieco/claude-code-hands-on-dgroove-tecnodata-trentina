#!/usr/bin/env python3
"""verifica.py di M3-E03 -- la dashboard locale: dashboard.html, i suoi
numeri, ciò che caricherebbe da fuori e il ciclo del controllo.

Lo chiama verifica.sh, accanto. Non si fida degli script dello spazio di
lavoro, che Claude può aver cambiato:
  - i KPI veri li ricalcola dal file anonimo dello spazio di lavoro,
    anonimo/ticket-anonimi.csv, con kpi_veri.py accanto a questo file;
  - la pagina la legge da sé, con le funzioni della copia originale del
    controllo (esercizio/controlla_dashboard.py di questo elemento), senza
    eseguirlo: niente si aggiunge al registro.
Controlla che dashboard.html ci sia e si legga; che abbia un solo blocco
<script type="application/json" id="kpi"> con un oggetto JSON uguale,
chiave per chiave, ai KPI veri, con la regola di kpi_definizioni.md; che
non carichi niente dalla rete né da altri file (uno script nella pagina
che chiama la rete compreso).
Stampa anche, come dato, senza che decida l'uscita: se ogni KPI fatto di
un numero solo compare nel testo visibile della pagina, con il punto o la
virgola decimale; se genera_dashboard.py c'è; le esecuzioni del controllo
registrate in controlli_dashboard.log e se controlla_dashboard.py dello
spazio di lavoro è diverso dall'originale; la frase della guida di Claude
Code «Claude does the work, runs the check, reads the result, and iterates
until the check passes.», senza un esito: il registro lo scrive il
controllo a ogni esecuzione, chiunque lo esegua, e che Claude l'abbia
eseguito lo dicono le sue chiamate, non il registro.

Uso:    verifica.py <spazio di lavoro>
Uscita: 0 la pagina c'è, il suo blocco kpi ha i KPI veri e non carica niente
        da fuori · 1 qualcosa manca o non torna, e la verifica dice che cosa
        · 2 precondizione (spazio di lavoro assente o che non si legge, un
        file originale dell'elemento che manca o non si carica, il file
        anonimo dello spazio di lavoro che manca o da cui i KPI non si
        calcolano); mai un traceback
"""
from __future__ import annotations

import importlib.util
import json
import os
import re
import sys
from types import ModuleType
from typing import Any, List, Optional, Sequence, Tuple

ELEMENTO = os.path.dirname(os.path.abspath(__file__))
KPI_VERI = os.path.join(ELEMENTO, "kpi_veri.py")
CONTROLLO = os.path.join(ELEMENTO, "esercizio", "controlla_dashboard.py")
PAGINA = "dashboard.html"
CSV = "anonimo/ticket-anonimi.csv"
LOG = "controlli_dashboard.log"
SCRIPT = "genera_dashboard.py"
GIORNI = ("lun", "mar", "mer", "gio", "ven", "sab", "dom")
RIGA_LOG = re.compile(r"(\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ)\t([0-9]+)\t"
                      r"([0-9]+|-)")
AFFERMAZIONE = ("«Claude does the work, runs the check, reads the result, "
                "and iterates until the check passes.»")
FONTE = "https://code.claude.com/docs/en/best-practices"
COME_DATO = ("  Come dato: il registro lo scrive il controllo a ogni "
             "esecuzione, chiunque\n  lo esegua. Che Claude l'abbia "
             "eseguito lo dicono le sue chiamate, non il\n  registro.")
FINE = ("Fatto: la pagina c'è, i suoi KPI sono quelli veri e non carica "
        "niente da fuori.")


class Precondizione(Exception):
    """La verifica non può girare: uscita 2."""


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


def leggi_byte(percorso: str) -> Optional[bytes]:
    """I byte del file, None se non c'è; Precondizione se c'è ma non si
    legge."""
    try:
        with open(percorso, "rb") as fh:
            return fh.read()
    except FileNotFoundError:
        return None
    except OSError as exc:
        raise Precondizione("%s non si legge (%s)" % (
            percorso, exc.strerror or type(exc).__name__))


def mostra(valore: Any) -> str:
    """Un valore su una riga: i giorni nel loro ordine, le altre chiavi in
    ordine alfabetico; al più 80 caratteri."""
    if isinstance(valore, dict) and valore and set(valore) <= set(GIORNI):
        testo = json.dumps({g: valore[g] for g in GIORNI if g in valore})
    else:
        testo = json.dumps(valore, ensure_ascii=False, sort_keys=True)
    return testo if len(testo) <= 80 else testo[:79] + "…"


def nel_testo(testo: str, valore: Any, decimali: int) -> bool:
    """Il numero compare nel testo, con il punto o la virgola decimale, e
    non come parte di un numero più lungo."""
    if valore is None:
        return False
    cifre = "%.*f" % (decimali, valore)
    intera, _, frazione = cifre.partition(".")
    corpo = re.escape(intera) + (r"[.,]" + re.escape(frazione)
                                 if frazione else "")
    schema = r"(?<![\d.,])" + corpo + r"(?![\d]|[.,]\d)"
    return re.search(schema, testo) is not None


def stampa_blocco(kv: ModuleType, cd: ModuleType, pagina: Any,
                  problemi: List[str]) -> Optional[dict]:
    """Il blocco kpi confrontato con i KPI veri; restituisce l'oggetto."""
    print("\nI KPI del blocco kpi, confrontati con quelli veri di %s (la "
          "regola di kpi_definizioni.md)" % CSV)
    valori, difetti = cd.blocco_kpi(pagina)
    for difetto in difetti:
        print("  NO  %s" % difetto)
        problemi.append(difetto)
    if valori is None:
        return None
    voci = kv.confronta(valori, CSV)
    for chiave, atteso, trovato, giusto in voci:
        print("  %-40s %s" % (chiave, "ok" if giusto else "NO"))
        print("      atteso  %s" % (mostra(atteso) if chiave in kv.CHIAVI
                                    else "(chiave in più)"))
        print("      trovato %s" % (mostra(trovato) if chiave in valori
                                    else "(manca)"))
    sbagliate = [v[0] for v in voci if not v[3]]
    if sbagliate:
        problemi.append("i KPI del blocco kpi non tornano: %s (le regole sono "
                        "in kpi_definizioni.md)" % ", ".join(sbagliate))
    return valori


def stampa_testo(kv: ModuleType, cd: ModuleType, pagina: Any) -> None:
    """Come dato: i KPI fatti di un numero solo, nel testo visibile."""
    print("\nGli stessi numeri nel testo visibile della pagina (come dato)")
    veri = kv.arrotonda(kv.esatti(CSV))
    testo = cd.testo_visibile(pagina)
    scalari = [k for k in kv.CHIAVI if not isinstance(veri[k], dict)]
    trovati = 0
    for chiave in scalari:
        decimali = kv.DECIMALI.get(chiave, 0)
        presente = nel_testo(testo, veri[chiave], decimali)
        trovati += 1 if presente else 0
        valore = "—" if veri[chiave] is None else \
            ("%.*f" % (decimali, veri[chiave])).replace(".", ",")
        print("  %-32s %-8s %s" % (chiave, valore, "sì" if presente else "no"))
    print("  %d valori su %d nel testo della pagina." % (trovati,
                                                        len(scalari)))


def stampa_rete(cd: ModuleType, pagina: Any, problemi: List[str]) -> None:
    print("\nRisorse fuori dal file della pagina (con il controllo originale)")
    risorse = cd.risorse_esterne(pagina)
    if not risorse:
        print("  nessuna: la pagina non carica niente dalla rete né da altri "
              "file")
        return
    for r in risorse:
        valore = r.valore if len(r.valore) <= 80 else r.valore[:79] + "…"
        print("  NO  %s, %s: %s" % ("dalla rete" if r.rete else
                                    "da un altro file", r.dove, valore))
    rete = sum(1 for r in risorse if r.rete)
    parti = ["%d %s %s" % (n, "risorsa" if n == 1 else "risorse", dove)
             for n, dove in ((rete, "dalla rete"),
                             (len(risorse) - rete, "da altri file")) if n]
    problemi.append("la pagina carica %s: deve stare in un file solo, che si "
                    "apre senza rete" % " e ".join(parti))


def esecuzioni() -> Tuple[List[int], int]:
    """(le uscite registrate in controlli_dashboard.log, le righe
    illeggibili)."""
    dati = leggi_byte(LOG)
    if dati is None:
        return [], 0
    uscite, illeggibili = [], 0
    for riga in dati.decode("utf-8", errors="replace").splitlines():
        m = RIGA_LOG.fullmatch(riga.strip())
        if m is None:
            illeggibili += 1
            continue
        uscite.append(int(m.group(2)))
    return uscite, illeggibili


def stampa_ciclo() -> None:
    """Come dato: le esecuzioni registrate, la copia del controllo dello
    spazio di lavoro, lo script e la frase della guida, senza un esito: il
    registro lo scrive ogni esecuzione del controllo, chiunque la faccia."""
    print("\nIl controllo eseguito nello spazio di lavoro (%s, come dato)"
          % LOG)
    uscite, illeggibili = esecuzioni()
    if uscite:
        print("  esecuzioni registrate: %d; uscite, in ordine: %s" % (
            len(uscite), " ".join(str(u) for u in uscite)))
    else:
        print("  nessuna esecuzione registrata")
    if illeggibili:
        print("  righe che non hanno la forma del registro: %d" % illeggibili)
    presente = leggi_byte("controlla_dashboard.py")
    if presente is None:
        stato = "manca"
    elif presente == leggi_byte(CONTROLLO):
        stato = "uguale all'originale"
    else:
        stato = "DIVERSO dall'originale"
    print("  controlla_dashboard.py dello spazio di lavoro: %s" % stato)
    print("  %s: %s" % (SCRIPT, "c'è" if os.path.isfile(SCRIPT)
                        else "manca"))
    print("\nLa guida di Claude Code: %s" % AFFERMAZIONE)
    print("  (%s)" % FONTE)
    print(COME_DATO)


def esamina(ws: str) -> int:
    kv = carica("kpi_veri_elemento", KPI_VERI)
    cd = carica("controlla_dashboard_originale", CONTROLLO)
    os.chdir(ws)
    if not os.path.isfile(CSV):
        raise Precondizione("manca %s nello spazio di lavoro: copiatelo da "
                            "M3-E01 (README, passo 1) o ripartite con "
                            "tools/reset_esercizio.sh M3-E03" % CSV)
    try:
        kv.esatti(CSV)
    except kv.Precondizione as exc:
        raise Precondizione("i KPI veri non si calcolano da %s (%s)"
                            % (CSV, exc))
    print("M3-E03: la verifica di %s" % PAGINA)
    print("\nLa pagina (%s)" % PAGINA)
    problemi: List[str] = []
    dati = leggi_byte(PAGINA)
    pagina = None
    if dati is None:
        print("  manca")
        problemi.append("manca %s: la scrive genera_dashboard.py" % PAGINA)
    else:
        print("  c'è, %d byte" % len(dati))
        try:
            pagina = cd.leggi_pagina(PAGINA)
        except cd.Precondizione as exc:
            print("  non si legge")
            problemi.append(str(exc))
    if pagina is not None:
        stampa_blocco(kv, cd, pagina, problemi)
        stampa_testo(kv, cd, pagina)
        stampa_rete(cd, pagina, problemi)
    stampa_ciclo()
    if problemi:
        print()
        for problema in problemi:
            print("Non ancora: %s." % problema)
        return 1
    print("\n" + FINE)
    return 0


def main(argv: Sequence[str]) -> int:
    if len(argv) != 1 or not os.path.isdir(argv[0]):
        sys.stderr.write("verifica: spazio di lavoro assente: %s\n"
                         % (argv[0] if argv else ""))
        return 2
    if not os.access(argv[0], os.R_OK | os.X_OK):
        sys.stderr.write("verifica: lo spazio di lavoro %s non si legge\n"
                         % argv[0])
        return 2
    try:
        return esamina(argv[0])
    except Precondizione as exc:
        sys.stderr.write("verifica: %s\n" % exc)
        return 2
    except Exception as exc:  # l'ultima rete: mai un traceback, e del
        # messaggio solo il tipo
        sys.stderr.write("verifica: errore inatteso (%s)\n"
                         % type(exc).__name__)
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
