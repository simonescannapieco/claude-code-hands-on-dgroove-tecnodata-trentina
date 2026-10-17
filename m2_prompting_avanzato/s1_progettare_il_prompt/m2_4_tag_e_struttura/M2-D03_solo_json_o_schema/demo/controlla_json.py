"""controlla_json.py -- che cosa hanno restituito le chiamate di M2-D03.

Legge, nello spazio di lavoro, risposte/solo-json-<modello>.json (la
richiesta «SOLO un JSON», per haiku, sonnet e opus) e
risposte/schema-haiku.json (la stessa richiesta con --json-schema), e
scrive esiti.tsv con una riga per file:
  json_valido    la risposta si legge come JSON (per lo schema: c'è
                 structured_output)
  blocco_codice  la risposta arriva dentro un blocco di codice, fra tre
                 apici inversi (```)
  telefono       il telefono del cliente compare nella risposta
  schema_valido  l'oggetto rispetta schema.json: le chiavi richieste, nessuna
                 in più, i valori ammessi
Il controllo dello schema è scritto qui, con la sola libreria standard, per
lo schema di questa demo (oggetto di stringhe, con enum).

Uso:    python3 controlla_json.py
Uscita: 0 esiti.tsv scritto · 1 un file manca o non è il JSON di claude -p
        · 2 uso sbagliato (argomenti), schema.json assente o non valido
"""
from __future__ import annotations

import json
import re
import sys
from typing import List, Optional, Tuple

MODELLI = ("haiku", "sonnet", "opus")
TELEFONO = re.compile(r"000[ .]?000[ .]?0103")
BLOCCO_CODICE = re.compile(r"^\s*```")


def sino(valore: Optional[bool]) -> str:
    """sì, no, oppure — (non si applica)."""
    if valore is None:
        return "—"
    return "sì" if valore else "no"


def rispetta(oggetto: object, schema: dict) -> bool:
    """Vero se l'oggetto rispetta lo schema della demo."""
    if not isinstance(oggetto, dict):
        return False
    campi = schema.get("properties", {})
    if any(k not in oggetto for k in schema.get("required", [])):
        return False
    if schema.get("additionalProperties") is False and any(
            k not in campi for k in oggetto):
        return False
    for chiave, regola in campi.items():
        if chiave not in oggetto:
            continue
        valore = oggetto[chiave]
        if regola.get("type") == "string" and not isinstance(valore, str):
            return False
        if "enum" in regola and valore not in regola["enum"]:
            return False
    return True


def leggi_risposta(percorso: str) -> Tuple[dict, str]:
    """(il JSON di claude -p, il testo di result); SystemExit(1) se non va."""
    try:
        with open(percorso, encoding="utf-8") as fh:
            doc = json.load(fh)
    except (OSError, ValueError) as exc:
        sys.stderr.write("controlla_json.py: %s: %s\n" % (percorso, exc))
        raise SystemExit(1)
    if not isinstance(doc, dict) or doc.get("is_error"):
        sys.stderr.write("controlla_json.py: %s non è una risposta riuscita "
                         "di claude -p\n" % percorso)
        raise SystemExit(1)
    return doc, str(doc.get("result") or "")


def main(argv: List[str]) -> int:
    if argv:
        sys.stderr.write(__doc__)
        return 2
    try:
        with open("schema.json", encoding="utf-8") as fh:
            schema = json.load(fh)
    except (OSError, ValueError) as exc:
        sys.stderr.write("controlla_json.py: schema.json: %s\n" % exc)
        return 2
    righe = ["file\tjson_valido\tblocco_codice\ttelefono\tschema_valido"]
    for modello in MODELLI:
        nome = "solo-json-%s.json" % modello
        _, testo = leggi_risposta("risposte/" + nome)
        try:
            oggetto = json.loads(testo)
            valido = True
        except ValueError:
            oggetto, valido = None, False
        righe.append("\t".join([
            nome, sino(valido), sino(bool(BLOCCO_CODICE.match(testo))),
            sino(bool(TELEFONO.search(testo))),
            sino(rispetta(oggetto, schema)) if valido else "no"]))
    doc, _ = leggi_risposta("risposte/schema-haiku.json")
    oggetto = doc.get("structured_output")
    testo = json.dumps(oggetto, ensure_ascii=False) if oggetto else ""
    righe.append("\t".join([
        "schema-haiku.json", sino(oggetto is not None), "—",
        sino(bool(TELEFONO.search(testo))),
        sino(rispetta(oggetto, schema))]))
    with open("esiti.tsv", "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(righe) + "\n")
    for riga in righe:
        print(riga.replace("\t", "  "))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
