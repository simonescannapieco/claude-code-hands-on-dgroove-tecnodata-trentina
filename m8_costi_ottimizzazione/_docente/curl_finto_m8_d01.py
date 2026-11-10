#!/usr/bin/env python3
"""curl_finto_m8_d01.py -- un curl finto per le prove di M8-D01
(test_m8_d01.sh).

La suite lo copia, con il nome «curl», davanti nel PATH: così demo/chiama.sh e
_docente/live.sh girano per intero senza chiamare l'API e senza una chiave
vera. I conteggi che scrive sono inventati, calcolati dal testo della richiesta
con una regola qualunque: provano il controllo, non l'API. Le opzioni sono
quelle che usa demo/chiama.sh; un'opzione che non conosce è un errore (uscita
2).

Scrive il corpo della risposta nel file di --output e, su STDOUT, ciò che
chiede --write-out (%{http_code} e \\n). Legge la configurazione dallo STDIN
quando --config vale «-» e il corpo della richiesta dal file di --data-binary
(@percorso, relativo alla cartella corrente).

L'ambiente cambia ciò che succede:
  FINTO_STATO=n           lo stato HTTP (default 200)
  FINTO_CORPO=nome        il corpo: buono (default), errore (401, con il tipo
                          dell'errore), rotto (non è JSON), senza (nessun
                          input_tokens), zero, negativo, stringa
                          (input_tokens non numerico), messaggio (porta i
                          campi di un messaggio creato)
  FINTO_FALLISCE=1        come curl senza rete: niente corpo, uscita 7
  FINTO_FALLISCE_SE=s     come sopra, ma solo se s è nel testo della richiesta
  FINTO_CHIAVE=s          stringa che il corpo d'errore finto contiene, per
                          provare che il controllo la maschera
  FINTO_LOG=file          una riga JSON per invocazione: argv (mai la chiave),
                          url, chiave_in_argv, config_bearer (la
                          configurazione è «Authorization: Bearer » seguita
                          dalla chiave dell'ambiente), config_righe,
                          corpo_sha256, corpo (il corpo letto come JSON),
                          stdin_config

Uscita: 0 risposta scritta · 2 argomenti sbagliati · 7 FINTO_FALLISCE
"""
import hashlib
import json
import os
import sys
from typing import Any, Dict, List, Tuple

OPZIONI = {"--silent": 0, "--show-error": 0, "--max-time": 1, "--request": 1,
           "--config": 1, "--header": 1, "--data-binary": 1, "--output": 1,
           "--write-out": 1}


def conta(testo: str) -> int:
    """Un conteggio inventato: parole, lunghezza e parole lunghe."""
    parole = testo.split()
    return len(parole) + len(testo) // 8 \
        + sum(1 for p in parole if len(p) >= 10)


def corpo_risposta(nome: str, testo: str) -> str:
    """Il corpo della risposta finta."""
    if nome == "rotto":
        return "non è JSON\n"
    if nome == "errore":
        msg = "la chiave non è valida " + os.environ.get("FINTO_CHIAVE", "")
        return json.dumps({"type": "error", "error": {
            "type": "authentication_error", "message": msg}})
    if nome == "senza":
        return json.dumps({"tokens": 3})
    if nome == "zero":
        return json.dumps({"input_tokens": 0})
    if nome == "negativo":
        return json.dumps({"input_tokens": -3})
    if nome == "stringa":
        return json.dumps({"input_tokens": "20"})
    base: Dict[str, Any] = {"input_tokens": conta(testo)}
    if nome == "messaggio":
        base.update({"id": "msg_finto_01", "type": "message",
                     "role": "assistant",
                     "content": [{"type": "text", "text": "ecco"}],
                     "stop_reason": "end_turn",
                     "usage": {"input_tokens": 3, "output_tokens": 2}})
    return json.dumps(base, ensure_ascii=False)


def argomenti(argv: List[str]) -> Tuple[Dict[str, str], List[str], List[str]]:
    """(opzioni con un valore, le intestazioni, gli URL)."""
    opzioni: Dict[str, str] = {}
    intestazioni: List[str] = []
    url: List[str] = []
    i = 0
    while i < len(argv):
        nome = argv[i]
        if nome.startswith("-") and nome not in OPZIONI:
            sys.stderr.write("curl: opzione sconosciuta: %s\n" % nome)
            sys.exit(2)
        if nome.startswith("-"):
            if OPZIONI[nome] == 1:
                if i + 1 >= len(argv):
                    sys.stderr.write("curl: manca il valore di %s\n" % nome)
                    sys.exit(2)
                if nome == "--header":
                    intestazioni.append(argv[i + 1])
                else:
                    opzioni[nome] = argv[i + 1]
                i += 2
            else:
                opzioni[nome] = ""
                i += 1
        else:
            url.append(nome)
            i += 1
    return opzioni, intestazioni, url


def registra(argv: List[str], url: List[str], config: str,
             dati: bytes) -> None:
    """Una riga di FINTO_LOG; la chiave non ci finisce mai."""
    percorso = os.environ.get("FINTO_LOG")
    if not percorso:
        return
    chiave = os.environ.get("ANTHROPIC_API_KEY", "")
    atteso = 'header = "Authorization: Bearer %s"' % chiave
    righe = [r for r in config.splitlines() if r.strip()]
    try:
        corpo = json.loads(dati.decode("utf-8"))
    except ValueError:
        corpo = None
    voce = {"argv": argv if not chiave else
            [a.replace(chiave, "<chiave>") for a in argv],
            "url": url,
            "chiave_in_argv": bool(chiave) and any(chiave in a for a in argv),
            "config_bearer": bool(chiave) and righe == [atteso],
            "config_righe": len(righe),
            "corpo_sha256": hashlib.sha256(dati).hexdigest(),
            "corpo": corpo,
            "stdin_config": "--config" in argv and bool(config)}
    with open(percorso, "a", encoding="utf-8") as fh:
        fh.write(json.dumps(voce, ensure_ascii=False) + "\n")


def main() -> int:
    argv = sys.argv[1:]
    opzioni, _intestazioni, url = argomenti(argv)
    config = sys.stdin.read() if opzioni.get("--config") == "-" else ""
    dati = b""
    if opzioni.get("--data-binary", "").startswith("@"):
        with open(opzioni["--data-binary"][1:], "rb") as fh:
            dati = fh.read()
    registra(argv, url, config, dati)
    testo = ""
    try:
        corpo = json.loads(dati.decode("utf-8")) if dati else {}
        testo = corpo["messages"][0]["content"]
    except (ValueError, KeyError, IndexError, TypeError):
        pass
    if os.environ.get("FINTO_FALLISCE") == "1" \
            or (os.environ.get("FINTO_FALLISCE_SE")
                and os.environ["FINTO_FALLISCE_SE"] in testo):
        sys.stderr.write("curl: (7) Failed to connect\n")
        return 7
    with open(opzioni["--output"], "w", encoding="utf-8") as fh:
        fh.write(corpo_risposta(os.environ.get("FINTO_CORPO", "buono"), testo))
    formato = opzioni.get("--write-out", "")
    stato = os.environ.get("FINTO_STATO", "200")
    sys.stdout.write(formato.replace("%{http_code}", stato)
                     .replace("\\n", "\n"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
