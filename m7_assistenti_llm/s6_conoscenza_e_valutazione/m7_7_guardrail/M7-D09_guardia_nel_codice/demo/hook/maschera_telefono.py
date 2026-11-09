"""maschera_telefono.py -- un hook PostToolUse di M7-D09: maschera i numeri di
telefono nel risultato di uno strumento, prima che arrivi a Claude.

Claude Code passa su STDIN un JSON con il risultato dello strumento
(tool_response); l'hook risponde su STDOUT con hookSpecificOutput e, in
updatedToolOutput, lo stesso risultato con i numeri mascherati. Riconosce un
solo formato, +39 ddd ddd dddd (il formato dei dati di prova): un numero scritto
in un altro modo passa com'è. Se l'ingresso non si legge, il risultato non
passa: al suo posto un testo che dice che è stato trattenuto.

Uscita: 0 sempre: il risultato mascherato, o il segnaposto, su STDOUT
"""
import json
import re
import sys

TELEFONO = re.compile(r"\+39 \d{3} \d{3} \d{4}")
MASCHERA = "+39 *** *** ****"
TRATTENUTO = ("Risultato trattenuto: il controllo che maschera i numeri di "
              "telefono non è riuscito a leggerlo.")


def main() -> int:
    try:
        dati = json.load(sys.stdin)
        risultato = json.dumps(dati["tool_response"], ensure_ascii=False)
        mascherato = json.loads(TELEFONO.sub(MASCHERA, risultato))
    except (ValueError, KeyError, TypeError):
        mascherato = TRATTENUTO
    print(json.dumps({"hookSpecificOutput": {
        "hookEventName": "PostToolUse",
        "updatedToolOutput": mascherato}}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
