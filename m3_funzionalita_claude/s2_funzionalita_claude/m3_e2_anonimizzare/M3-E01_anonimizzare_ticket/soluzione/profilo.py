#!/usr/bin/env python3
"""profilo.py -- il profilo della settimana, dal file anonimo.

Legge anonimo/ticket-anonimi.csv e scrive anonimo/profilo.json:
  - kpi: gli indicatori di kpi_definizioni.md, con le sue regole;
  - campi_vuoti: per ogni colonna con campi vuoti, quanti;
  - comuni: quante segnalazioni per comune, come è scritto, e i gruppi di
    scritture che cominciano con la stessa parola (PERGINE VALSUGANA,
    Pergine, Pergine Valsugana);
  - annullate: le segnalazioni annullate;
  - possibili_doppioni: le coppie di segnalazioni dello stesso cliente
    aperte a meno di un'ora l'una dall'altra.

Uso:    python3 profilo.py [entrata] [uscita]
          default anonimo/ticket-anonimi.csv e anonimo/profilo.json
"""
import csv
import datetime as dt
import json
import os
import re
import statistics
import sys
from decimal import ROUND_HALF_UP, Decimal

ENTRATA = os.path.join("anonimo", "ticket-anonimi.csv")
USCITA = os.path.join("anonimo", "profilo.json")
GIORNI = ("lun", "mar", "mer", "gio", "ven", "sab", "dom")
UN_ORA = dt.timedelta(hours=1)


def arrotonda(valore, decimali):
    """Mezza unità per eccesso; None resta None."""
    if valore is None:
        return None
    passo = Decimal(1).scaleb(-decimali)
    return float(Decimal(str(valore)).quantize(passo, rounding=ROUND_HALF_UP))


def media(valori):
    return Decimal(sum(valori)) / Decimal(len(valori)) if valori else None


def interi(righe, colonna):
    return [int(r[colonna]) for r in righe if r[colonna].strip()]


def kpi(righe):
    """Gli indicatori di kpi_definizioni.md."""
    per_giorno = {g: 0 for g in GIORNI}
    for r in righe:
        giorno = dt.date.fromisoformat(r["aperto_il"][:10]).weekday()
        per_giorno[GIORNI[giorno]] += 1
    per_categoria, per_tecnologia, per_cliente = {}, {}, {}
    for r in righe:
        if r["categoria"]:
            per_categoria[r["categoria"]] = per_categoria.get(
                r["categoria"], 0) + 1
        if r["minuti_risoluzione"].strip() and r["tecnologia"]:
            per_tecnologia.setdefault(r["tecnologia"], []).append(
                int(r["minuti_risoluzione"]))
        if r["cliente"]:
            per_cliente[r["cliente"]] = per_cliente.get(r["cliente"], 0) + 1
    prima = interi(righe, "minuti_prima_risposta")
    voti = interi(righe, "soddisfazione")
    return {
        "segnalazioni": len(righe),
        "per_giorno": per_giorno,
        "aperte_fine_settimana": sum(1 for r in righe
                                     if not r["chiuso_il"].strip()),
        "annullate": sum(1 for r in righe if r["stato"] == "annullato"),
        "per_categoria": per_categoria,
        "mediana_minuti_prima_risposta": arrotonda(
            statistics.median(prima) if prima else None, 1),
        "media_minuti_risoluzione_per_tecnologia": {
            t: arrotonda(media(v), 1) for t, v in per_tecnologia.items()},
        "voti": len(voti),
        "soddisfazione_media": arrotonda(media(voti), 2),
        "clienti_ricorrenti": sum(1 for n in per_cliente.values() if n >= 3),
    }


def comuni(righe):
    """Le segnalazioni per comune e le scritture con la stessa prima
    parola."""
    conta = {}
    for r in righe:
        conta[r["comune"]] = conta.get(r["comune"], 0) + 1
    gruppi = {}
    for comune in conta:
        chiave = re.sub(r"\s*\(tn\)$", "", comune.casefold()).split()[0]
        gruppi.setdefault(chiave, []).append(comune)
    varianti = {k: sorted(v) for k, v in gruppi.items() if len(v) > 1}
    return {"segnalazioni_per_comune": conta,
            "scritture_con_la_stessa_prima_parola": varianti}


def possibili_doppioni(righe):
    """Le coppie dello stesso cliente aperte a meno di un'ora."""
    coppie = []
    for i, a in enumerate(righe):
        for b in righe[i + 1:]:
            if not a["cliente"] or a["cliente"] != b["cliente"]:
                continue
            t_a = dt.datetime.fromisoformat(a["aperto_il"])
            t_b = dt.datetime.fromisoformat(b["aperto_il"])
            if abs(t_b - t_a) < UN_ORA:
                coppie.append([a["id_ticket"], b["id_ticket"]])
    return coppie


def main(argv):
    entrata = argv[0] if len(argv) > 0 else ENTRATA
    uscita = argv[1] if len(argv) > 1 else USCITA
    with open(entrata, encoding="utf-8", newline="") as fh:
        lettore = csv.DictReader(fh)
        righe = list(lettore)
        colonne = lettore.fieldnames or []
    profilo = {
        "kpi": kpi(righe),
        "campi_vuoti": {c: n for c in colonne
                        for n in [sum(1 for r in righe if not r[c].strip())]
                        if n},
        "comuni": comuni(righe),
        "annullate": [r["id_ticket"] for r in righe
                      if r["stato"] == "annullato"],
        "possibili_doppioni": possibili_doppioni(righe),
    }
    with open(uscita, "w", encoding="utf-8", newline="\n") as fh:
        json.dump(profilo, fh, ensure_ascii=False, indent=2, sort_keys=True)
        fh.write("\n")
    print("profilo: %s scritto, %d segnalazioni." % (uscita, len(righe)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
