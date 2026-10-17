"""Legge su STDIN il JSON di `claude -p --output-format json` e ne stampa
un dato.

Uso:  ... | python3 leggi_json.py token_entrata    (la somma di input_tokens,
                                                  cache_creation_input_tokens e
                                                  cache_read_input_tokens)
      ... | python3 leggi_json.py token_uscita     (output_tokens)
      ... | python3 leggi_json.py token_thinking   (i token del ragionamento,
                                                  0 se il JSON non li riporta)
      ... | python3 leggi_json.py result           (la risposta, su una riga)
      ... | python3 leggi_json.py structured_output (l'oggetto vincolato dallo
                                                  schema, in JSON su una riga)
      ... | python3 leggi_json.py session_id       (l'ID della sessione)
Uscita: 0 fatto · 1 nessun JSON (per esempio claude non trovato), un JSON
        non valido, senza quel dato o con un errore · 2 uso sbagliato
"""
from __future__ import annotations

import json
import sys
from typing import List

TOKEN = ("input_tokens", "cache_creation_input_tokens",
         "cache_read_input_tokens")
DATI = ("token_entrata", "token_uscita", "token_thinking", "result",
        "structured_output", "session_id")


def errore(messaggio: str) -> int:
    """Il messaggio su STDERR, in una riga; l'uscita 1."""
    sys.stderr.write("leggi_json.py: %s\n" % messaggio)
    return 1


def numero(valore: object, campo: str) -> int:
    """Un conteggio di token: None vale 0; altrimenti un intero >= 0."""
    if valore is None:
        return 0
    if isinstance(valore, bool) or not isinstance(valore, int) or valore < 0:
        raise ValueError("%s non è un numero (%r)" % (campo, valore))
    return valore


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
    except ValueError as exc:
        return errore("il testo in ingresso non è un JSON valido (%s)" % exc)
    if not isinstance(risposta, dict):
        return errore("il JSON non è quello di claude -p")
    if risposta.get("is_error"):
        return errore("claude ha restituito un errore")
    uso = risposta.get("usage")
    try:
        if argv[0] in ("token_entrata", "token_uscita", "token_thinking"):
            if not isinstance(uso, dict):
                return errore("il JSON non contiene «usage»")
            if argv[0] == "token_entrata":
                print(sum(numero(uso.get(c), "usage." + c) for c in TOKEN))
            elif argv[0] == "token_uscita":
                print(numero(uso.get("output_tokens"), "usage.output_tokens"))
            else:
                dettagli = uso.get("output_tokens_details") or {}
                print(numero(dettagli.get("thinking_tokens"),
                             "usage.output_tokens_details.thinking_tokens"))
            return 0
    except ValueError as exc:
        return errore(str(exc))
    valore = risposta.get(argv[0])
    if valore is None:
        return errore("il JSON non contiene «%s»" % argv[0])
    if argv[0] == "structured_output":
        print(json.dumps(valore, ensure_ascii=False))
        return 0
    print(" ".join(str(valore).split()))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
