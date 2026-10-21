#!/usr/bin/env python3
"""kpi_veri.py -- i KPI veri della settimana di ticket, calcolati dal CSV.

Lo usano le verifiche del laboratorio del Modulo 3 (M3-E01, M3-E02 e
M3-E03 ne portano copie identiche byte per byte). Le definizioni sono
quelle di kpi_definizioni.md: un oggetto JSON con esattamente dieci chiavi.
  segnalazioni                    le righe del file (intero)
  per_giorno                      le righe per giorno della settimana di
                                  aperto_il, come è scritta (ora locale):
                                  chiavi lun mar mer gio ven sab dom, tutte
                                  e sette (interi)
  aperte_fine_settimana           le righe con chiuso_il vuoto (intero)
  annullate                       le righe con stato «annullato» (intero)
  per_categoria                   le righe per categoria, solo le categorie
                                  non vuote presenti (interi)
  mediana_minuti_prima_risposta   la mediana di minuti_prima_risposta non
                                  vuoti; con un numero pari di valori la
                                  media dei due centrali (1 decimale)
  media_minuti_risoluzione_per_tecnologia
                                  la media di minuti_risoluzione non vuoti
                                  per tecnologia, solo le tecnologie con
                                  almeno un valore (1 decimale)
  voti                            le righe con soddisfazione non vuota
                                  (intero)
  soddisfazione_media             la media di soddisfazione non vuota
                                  (2 decimali)
  clienti_ricorrenti              i valori distinti non vuoti di cliente con
                                  almeno 3 righe (intero; in un file senza
                                  la colonna cliente, quelli di id_cliente)
Un campo vuoto (anche solo spazi) è un campo senza valore. Una media o una
mediana senza valori vale null.

La regola del confronto: un intero è giusto se è uguale; un decimale se
dista dal valore vero non arrotondato al più mezza unità del suo ultimo
decimale (0,05 con un decimale, 0,005 con due), più 1e-9: un valore
arrotondato bene è sempre giusto, anche con più decimali; un oggetto se ha
le stesse chiavi e ogni valore è giusto. Un null è giusto solo se il vero è
null; un booleano o un testo non sono mai un numero.

Come modulo:
  calcola(percorso) -> dict          i valori veri, non arrotondati
  arrotonda(kpi) -> dict             arrotondati come nelle definizioni
                                     (mezza unità per eccesso)
  confronta(valori, percorso) -> [(chiave, atteso, trovato, ok), ...]
                                     una voce per chiave, in ordine, poi le
                                     chiavi in più (atteso None); atteso è
                                     il valore arrotondato, trovato None se
                                     la chiave manca
Uso:    python3 -B -I kpi_veri.py <csv>   stampa il JSON arrotondato, con le
                                          chiavi in ordine
Uscita: 0 · 2 precondizione (file assente o illeggibile, colonna mancante,
        valore non valido)
"""
from __future__ import annotations

import csv
import datetime as dt
import json
import math
import sys
from fractions import Fraction
from typing import Any, Dict, List, Optional, Sequence, Tuple

GIORNI = ("lun", "mar", "mer", "gio", "ven", "sab", "dom")
CHIAVI = ("aperte_fine_settimana", "annullate", "clienti_ricorrenti",
          "media_minuti_risoluzione_per_tecnologia",
          "mediana_minuti_prima_risposta", "per_categoria", "per_giorno",
          "segnalazioni", "soddisfazione_media", "voti")
DECIMALI = {"mediana_minuti_prima_risposta": 1,
            "media_minuti_risoluzione_per_tecnologia": 1,
            "soddisfazione_media": 2}
COLONNE = ("aperto_il", "chiuso_il", "stato", "categoria", "tecnologia",
           "minuti_prima_risposta", "minuti_risoluzione", "soddisfazione")
MARGINE = Fraction(1, 10 ** 9)

Voce = Tuple[str, Any, Any, bool]


class Precondizione(Exception):
    """I KPI non si possono calcolare da questo file: uscita 2."""


def _leggi(percorso: str) -> Tuple[List[Dict[str, str]], str]:
    """(le righe, la colonna del cliente); Precondizione se il file non
    c'è, non si legge o manca una colonna."""
    try:
        with open(percorso, encoding="utf-8-sig", newline="") as fh:
            lettore = csv.DictReader(fh, strict=True)
            righe = list(lettore)
            intestazione = lettore.fieldnames or []
    except FileNotFoundError:
        raise Precondizione("%s non c'è" % percorso)
    except UnicodeDecodeError:
        raise Precondizione("%s non è un testo UTF-8" % percorso)
    except csv.Error as exc:
        raise Precondizione("%s non è un CSV leggibile (%s)" % (percorso, exc))
    except OSError as exc:
        raise Precondizione("%s non si legge (%s)" % (
            percorso, exc.strerror or type(exc).__name__))
    cliente = "cliente" if "cliente" in intestazione else "id_cliente"
    mancanti = [c for c in COLONNE + (cliente,) if c not in intestazione]
    if mancanti:
        raise Precondizione("%s: mancano le colonne %s" % (
            percorso, ", ".join(mancanti)))
    for numero, riga in enumerate(righe, start=1):
        if None in riga or any(v is None for v in riga.values()):
            raise Precondizione("%s: la riga di dati %d non ha il numero di "
                                "campi dell'intestazione" % (percorso, numero))
    return righe, cliente


def _intero(riga: Dict[str, str], colonna: str, numero: int) -> int:
    testo = riga[colonna].strip()
    if not testo.isdigit() or not testo.isascii():
        raise Precondizione("%s non è un intero non negativo nella riga di "
                            "dati %d" % (colonna, numero))
    return int(testo)


def _giorno(riga: Dict[str, str], numero: int) -> str:
    try:
        data = dt.date.fromisoformat(riga["aperto_il"].strip()[:10])
    except ValueError:
        raise Precondizione("aperto_il non è una data ISO 8601 nella riga di "
                            "dati %d" % numero)
    return GIORNI[data.weekday()]


def _mediana(valori: Sequence[int]) -> Optional[Fraction]:
    ordinati = sorted(valori)
    n = len(ordinati)
    if n == 0:
        return None
    if n % 2:
        return Fraction(ordinati[n // 2])
    return Fraction(ordinati[n // 2 - 1] + ordinati[n // 2], 2)


def _media(valori: Sequence[int]) -> Optional[Fraction]:
    return Fraction(sum(valori), len(valori)) if valori else None


def esatti(percorso: str) -> Dict[str, Any]:
    """I KPI con le medie e la mediana come frazioni esatte."""
    righe, colonna_cliente = _leggi(percorso)
    per_giorno = {g: 0 for g in GIORNI}
    per_categoria: Dict[str, int] = {}
    prima: List[int] = []
    risoluzione: Dict[str, List[int]] = {}
    voti: List[int] = []
    clienti: Dict[str, int] = {}
    for numero, r in enumerate(righe, start=1):
        per_giorno[_giorno(r, numero)] += 1
        categoria = r["categoria"].strip()
        if categoria:
            per_categoria[categoria] = per_categoria.get(categoria, 0) + 1
        if r["minuti_prima_risposta"].strip():
            prima.append(_intero(r, "minuti_prima_risposta", numero))
        tecnologia = r["tecnologia"].strip()
        if r["minuti_risoluzione"].strip() and tecnologia:
            risoluzione.setdefault(tecnologia, []).append(
                _intero(r, "minuti_risoluzione", numero))
        if r["soddisfazione"].strip():
            voti.append(_intero(r, "soddisfazione", numero))
        cliente = r[colonna_cliente].strip()
        if cliente:
            clienti[cliente] = clienti.get(cliente, 0) + 1
    return {
        "segnalazioni": len(righe),
        "per_giorno": per_giorno,
        "aperte_fine_settimana": sum(1 for r in righe
                                     if not r["chiuso_il"].strip()),
        "annullate": sum(1 for r in righe if r["stato"].strip() == "annullato"),
        "per_categoria": per_categoria,
        "mediana_minuti_prima_risposta": _mediana(prima),
        "media_minuti_risoluzione_per_tecnologia": {
            t: _media(v) for t, v in risoluzione.items()},
        "voti": len(voti),
        "soddisfazione_media": _media(voti),
        "clienti_ricorrenti": sum(1 for n in clienti.values() if n >= 3),
    }


def _in_virgola(valore: Any) -> Any:
    """Le frazioni come float, ricorsivamente."""
    if isinstance(valore, dict):
        return {k: _in_virgola(v) for k, v in valore.items()}
    if isinstance(valore, Fraction):
        return float(valore)
    return valore


def calcola(percorso: str) -> Dict[str, Any]:
    """I KPI veri del file, non arrotondati (le medie e la mediana come
    float); Precondizione se non si possono calcolare."""
    return _in_virgola(esatti(percorso))


def _arrotonda_numero(valore: Any, decimali: int) -> Any:
    """Mezza unità per eccesso, sul valore esatto."""
    if valore is None:
        return None
    esatto = Fraction(valore)
    scala = 10 ** decimali
    segno = -1 if esatto < 0 else 1
    arrotondato = Fraction(math.floor(abs(esatto) * scala + Fraction(1, 2)),
                           scala)
    return round(float(segno * arrotondato), decimali)


def arrotonda(kpi: Dict[str, Any]) -> Dict[str, Any]:
    """I KPI arrotondati come nelle definizioni."""
    uscita: Dict[str, Any] = {}
    for chiave, valore in kpi.items():
        decimali = DECIMALI.get(chiave)
        if decimali is None:
            uscita[chiave] = valore
        elif isinstance(valore, dict):
            uscita[chiave] = {k: _arrotonda_numero(v, decimali)
                              for k, v in valore.items()}
        else:
            uscita[chiave] = _arrotonda_numero(valore, decimali)
    return uscita


def _numero_giusto(vero: Optional[Fraction], trovato: Any,
                   decimali: Optional[int]) -> bool:
    if vero is None:
        return trovato is None
    if isinstance(trovato, bool) or not isinstance(trovato, (int, float)):
        return False
    if isinstance(trovato, float) and not math.isfinite(trovato):
        return False
    if decimali is None:
        return Fraction(trovato) == vero
    margine = Fraction(1, 2 * 10 ** decimali) + MARGINE
    return abs(Fraction(trovato) - vero) <= margine


def _giusto(vero: Any, trovato: Any, decimali: Optional[int]) -> bool:
    if isinstance(vero, dict):
        if not isinstance(trovato, dict) or set(trovato) != set(vero):
            return False
        return all(_numero_giusto(_frazione(vero[k]), trovato[k], decimali)
                   for k in vero)
    return _numero_giusto(_frazione(vero), trovato, decimali)


def _frazione(valore: Any) -> Optional[Fraction]:
    return None if valore is None else Fraction(valore)


def confronta(valori: Any, percorso: str) -> List[Voce]:
    """Ogni chiave dei KPI di valori confrontata con il vero calcolato dal
    file: (chiave, atteso arrotondato, trovato, giusto). Le chiavi in più
    sono sbagliate (atteso None); Precondizione se il file non va."""
    veri = esatti(percorso)
    attesi = arrotonda(veri)
    trovati = valori if isinstance(valori, dict) else {}
    voci: List[Voce] = []
    for chiave in CHIAVI:
        if chiave not in trovati:
            voci.append((chiave, attesi[chiave], None, False))
            continue
        voci.append((chiave, attesi[chiave], trovati[chiave],
                     _giusto(veri[chiave], trovati[chiave],
                             DECIMALI.get(chiave))))
    for chiave in sorted(k for k in trovati if k not in CHIAVI):
        voci.append((chiave, None, trovati[chiave], False))
    return voci


def main(argv: Sequence[str]) -> int:
    if len(argv) == 1 and argv[0] in ("-h", "--help"):
        print((__doc__ or "").strip())
        return 0
    if len(argv) != 1:
        sys.stderr.write("uso: python3 -B -I kpi_veri.py <csv>\n")
        return 2
    try:
        kpi = arrotonda(esatti(argv[0]))
    except Precondizione as exc:
        sys.stderr.write("kpi_veri: %s\n" % exc)
        return 2
    print(json.dumps(kpi, ensure_ascii=False, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
