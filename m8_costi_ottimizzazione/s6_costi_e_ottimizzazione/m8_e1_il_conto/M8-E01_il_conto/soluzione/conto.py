"""conto.py -- M8-E01 «Quanto costa una risposta»: una soluzione di riferimento,
scritta per il corso: non è l'uscita della richiesta del passo 3 del README.

Legge risposte/prima.json (il JSON della chiamata di claude -p), listino.json
e volume.txt, nella cartella in cui lo si lancia, e stampa:
  - il costo della chiamata, con ognuno dei cinque conteggi di usage al suo
    prezzo: input non in cache, scrittura in cache a 5 minuti e a 1 ora, lettura
    dalla cache, output;
  - total_cost_usd del JSON, per confronto, con la differenza;
  - il costo di un mese al volume di volume.txt: ticket per i token di input e
    di output di un ticket, ai prezzi base del modello (haiku), senza cache.

Uso:    python3 conto.py   (dallo spazio di lavoro)
Uscita: 0 il conto è stampato · 2 un file che manca o che non va (un messaggio
        su STDERR, mai un traceback)
"""
from __future__ import annotations

import json
import re
import sys
from typing import Any, Dict, Tuple

MODELLO = "haiku"
MILIONE = 1_000_000
RIGA_VOLUME = re.compile(r"^\s*(\w+)\s*=\s*([0-9]+)\s*$")


def dollari(valore: float, decimali: int = 6) -> str:
    """Una cifra in dollari, con la virgola."""
    return ("%.*f $" % (decimali, valore)).replace(".", ",")


def leggi_json(percorso: str) -> Any:
    """Il contenuto di un file JSON."""
    with open(percorso, encoding="utf-8") as fh:
        return json.load(fh)


def leggi_volume(percorso: str) -> Dict[str, int]:
    """Il volume: le righe «nome = numero» di volume.txt."""
    valori: Dict[str, int] = {}
    with open(percorso, encoding="utf-8") as fh:
        for riga in fh:
            trovata = RIGA_VOLUME.match(riga)
            if trovata:
                valori[trovata.group(1)] = int(trovata.group(2))
    return valori


def conteggi(uso: Dict[str, Any],
             prezzi: Dict[str, float]) -> Tuple[Tuple[str, int, float], ...]:
    """I cinque conteggi di usage, ciascuno con il suo prezzo."""
    scrittura = uso["cache_creation"]
    return (
        ("input, non in cache", uso["input_tokens"], prezzi["input"]),
        ("scrittura in cache, 5 minuti",
         scrittura["ephemeral_5m_input_tokens"], prezzi["cache_write_5m"]),
        ("scrittura in cache, 1 ora",
         scrittura["ephemeral_1h_input_tokens"], prezzi["cache_write_1h"]),
        ("lettura dalla cache", uso["cache_read_input_tokens"],
         prezzi["cache_read"]),
        ("output", uso["output_tokens"], prezzi["output"]),
    )


def stampa_conto() -> None:
    """Legge i tre file e stampa il conto."""
    chiamata = leggi_json("risposte/prima.json")
    prezzi = leggi_json("listino.json")["modelli"][MODELLO]
    volume = leggi_volume("volume.txt")
    totale = 0.0
    print("La chiamata di risposte/prima.json, ai prezzi di listino.json:")
    for nome, token, prezzo in conteggi(chiamata["usage"], prezzi):
        costo = token * prezzo / MILIONE
        totale += costo
        print("  %-30s %8d token a %s /M: %s"
              % (nome, token, dollari(prezzo, 3), dollari(costo)))
    print("Costo della chiamata: %s" % dollari(totale))
    dichiarato = float(chiamata["total_cost_usd"])
    print("total_cost_usd del JSON: %s (differenza %s)"
          % (dollari(dichiarato), dollari(abs(dichiarato - totale))))
    ticket = volume["ticket_al_mese"]
    entrata = volume["token_input_per_ticket"]
    uscita = volume["token_output_per_ticket"]
    mese = ticket * (entrata * prezzi["input"]
                     + uscita * prezzi["output"]) / MILIONE
    print("Un mese, %d ticket da %d token in entrata e %d in uscita: %s"
          % (ticket, entrata, uscita, dollari(mese, 2)))


def main() -> int:
    try:
        stampa_conto()
    except (OSError, ValueError, KeyError, TypeError) as exc:
        print("conto: i file non vanno (%s: %s); rifate i passi del README"
              % (type(exc).__name__, exc), file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
