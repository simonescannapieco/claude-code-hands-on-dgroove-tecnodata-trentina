"""Legge su STDIN il JSON di `claude -p --output-format json` e ne stampa
un dato.

Uso:  ... | python3 leggi_json.py token_entrata   (la somma di input_tokens,
                                                 cache_creation_input_tokens e
                                                 cache_read_input_tokens)
      ... | python3 leggi_json.py result          (la risposta)
      ... | python3 leggi_json.py session_id      (l'ID della sessione)
Uscita: 0 fatto · 1 nessun JSON (per esempio claude non trovato), un JSON
        non valido, senza quel dato (per token_entrata, un «usage» senza
        nessuno dei tre campi) o con un errore · 2 uso sbagliato
"""
from __future__ import annotations

import json
import sys
from typing import List

TOKEN = ("input_tokens", "cache_creation_input_tokens",
         "cache_read_input_tokens")
DATI = ("token_entrata", "result", "session_id")


def errore(messaggio: str) -> int:
    """Il messaggio su STDERR, in una riga; l'uscita 1."""
    sys.stderr.write("leggi_json.py: %s\n" % messaggio)
    return 1


def main(argv: List[str]) -> int:
    if len(argv) != 1 or argv[0] not in DATI:
        sys.stderr.write(__doc__)
        return 2
    testo = sys.stdin.buffer.read().decode("utf-8", errors="replace")
    if not testo.strip():
        return errore("nessun JSON in ingresso: la chiamata a claude è "
                      "fallita?")
    try:
        risposta = json.loads(testo)
    except (ValueError, RecursionError) as exc:
        # RecursionError: un JSON annidato oltre il limite di Python
        return errore("il testo in ingresso non è un JSON valido (%s)" % exc)
    if not isinstance(risposta, dict):
        return errore("il JSON non è quello di claude -p")
    if risposta.get("is_error"):
        return errore("claude ha restituito un errore")
    if argv[0] == "token_entrata":
        uso = risposta.get("usage")
        if not isinstance(uso, dict):
            return errore("il JSON non contiene «usage»")
        presenti = [c for c in TOKEN if uso.get(c) is not None]
        if not presenti:
            return errore("«usage» non contiene i token in entrata (%s)"
                          % ", ".join(TOKEN))
        totale = 0
        for campo in presenti:
            valore = uso[campo]
            if isinstance(valore, bool) or not isinstance(valore, int) \
                    or valore < 0:
                return errore("usage.%s non è un numero (%r)"
                              % (campo, valore))
            totale += valore
        print(totale)
        return 0
    valore = risposta.get(argv[0])
    if valore is None:
        return errore("il JSON non contiene «%s»" % argv[0])
    print(" ".join(str(valore).split()))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
