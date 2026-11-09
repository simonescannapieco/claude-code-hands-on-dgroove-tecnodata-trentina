"""controlla_risposta.py -- M7-D02 «Solo una POST»: la risposta della
Messages API, letta campo per campo.

Legge, nella cartella data (risposte/ dello spazio di lavoro):
  stato.txt      lo stato HTTP della risposta, una riga con il numero;
  risposta.json  il corpo della risposta, così come l'ha salvato curl.
Stampa lo stato, poi stop_reason e usage, poi modello, id e testo della
risposta. Se la risposta è un errore, stampa il tipo e il messaggio
dell'errore, con ogni cosa che somiglia a una chiave mascherata. Il controllo
decide soltanto ciò che la risposta dice: la risposta è un successo, e porta
stop_reason e usage? Non giudica il testo.

Uso:    python3 -B -I controlla_risposta.py <cartella delle risposte>
Uscita: 0 lo stato è 200 e la risposta ha stop_reason e usage · 1 lo stato non
        è 200, oppure la risposta non ha quei campi, oppure stato.txt o
        risposta.json mancano · 2 uso sbagliato; la cartella che non c'è; uno
        stato che non è un numero; un file che non si legge come JSON; un
        errore inatteso (una riga, mai un traceback)
"""
from __future__ import annotations

import json
import os
import re
import sys
from typing import Any, Dict, List, NoReturn, Tuple

USO = "Uso: python3 -B -I controlla_risposta.py <cartella delle risposte>\n"
STATO = "stato.txt"
RISPOSTA = "risposta.json"
CAMPI_USAGE = ("input_tokens", "output_tokens")
LUNGHEZZA_TESTO = 300
# Una chiave nel testo di un errore: si maschera, non si stampa mai.
CHIAVE = re.compile(r"sk-ant-[A-Za-z0-9_-]+")


class Precondizione(Exception):
    """Un dato che non si può leggere: uscita 2."""


def esci(testo: str) -> "NoReturn":
    """Una precondizione, una riga su STDERR, uscita 2."""
    sys.stderr.write("controlla_risposta: %s\n" % testo)
    sys.exit(2)


def maschera(testo: str) -> str:
    """Il testo con ogni cosa che somiglia a una chiave mascherata."""
    return CHIAVE.sub("<chiave>", testo)


def leggi_stato(cartella: str) -> int | None:
    """Lo stato HTTP, None se stato.txt manca; Precondizione se non si legge."""
    percorso = os.path.join(cartella, STATO)
    if not os.path.isfile(percorso):
        return None
    try:
        with open(percorso, encoding="utf-8") as fh:
            testo = fh.read().strip()
    except (OSError, UnicodeDecodeError) as exc:
        raise Precondizione("%s non si legge: %s" % (STATO, exc)) from exc
    if not testo.isdigit():
        raise Precondizione("%s non è un numero: «%s»" % (STATO, testo[:40]))
    return int(testo)


def leggi_risposta(cartella: str) -> Dict[str, Any] | None:
    """Il corpo della risposta, None se manca; Precondizione se non si legge o
    non è un oggetto JSON."""
    percorso = os.path.join(cartella, RISPOSTA)
    if not os.path.isfile(percorso):
        return None
    try:
        with open(percorso, encoding="utf-8") as fh:
            dati = json.load(fh)
    except (OSError, UnicodeDecodeError, ValueError) as exc:
        raise Precondizione("%s non si legge come JSON: %s" % (RISPOSTA, exc)
                            ) from exc
    if not isinstance(dati, dict):
        raise Precondizione("%s non è un oggetto JSON" % RISPOSTA)
    return dati


def campi_mancanti(risposta: Dict[str, Any]) -> List[str]:
    """I campi che servono e che la risposta non ha."""
    mancanti = []
    if not risposta.get("stop_reason"):
        mancanti.append("stop_reason")
    usage = risposta.get("usage")
    if not isinstance(usage, dict):
        mancanti.append("usage")
    else:
        mancanti += ["usage.%s" % c for c in CAMPI_USAGE
                     if not isinstance(usage.get(c), int)]
    return mancanti


def stampa_errore(risposta: Dict[str, Any]) -> None:
    """Il tipo e il messaggio di un corpo d'errore."""
    errore = risposta.get("error")
    if isinstance(errore, dict):
        print("errore: %s" % maschera(str(errore.get("type"))))
        print("messaggio: %s" % maschera(str(errore.get("message"))))


def testo_risposta(risposta: Dict[str, Any]) -> str:
    """Il testo dei blocchi di testo di content, su una riga."""
    testi = [str(b.get("text", "")) for b in risposta.get("content") or []
             if isinstance(b, dict) and b.get("type") == "text"]
    return " ".join(" ".join(t.split()) for t in testi)


def stampa_riuscita(risposta: Dict[str, Any]) -> None:
    """I campi di una risposta riuscita, uno per uno."""
    usage = risposta["usage"]
    print("stop_reason: %s" % risposta["stop_reason"])
    print("usage: " + " · ".join("%s %s" % (c, usage[c]) for c in CAMPI_USAGE))
    altri = [c for c in usage if c not in CAMPI_USAGE]
    if altri:
        print("(dato) le altre voci di usage: "
              + " · ".join("%s %s" % (c, usage[c]) for c in sorted(altri)))
    print("(dato) model: %s" % risposta.get("model"))
    print("(dato) id: %s" % risposta.get("id"))
    print("(dato) il testo: " + testo_risposta(risposta)[:LUNGHEZZA_TESTO])


def controlla(cartella: str) -> int:
    """Legge stato e risposta, stampa, e dice l'uscita."""
    if not os.path.isdir(cartella):
        raise Precondizione("la cartella %s non c'è" % cartella)
    stato = leggi_stato(cartella)
    risposta = leggi_risposta(cartella)
    if stato is None or risposta is None:
        manca = STATO if stato is None else RISPOSTA
        print("In %s manca %s: la chiamata non è stata fatta fino in fondo."
              % (cartella, manca))
        return 1
    print("stato HTTP: %d" % stato)
    if stato != 200:
        stampa_errore(risposta)
        print("La risposta non è un successo: lo stato non è 200.")
        return 1
    mancanti = campi_mancanti(risposta)
    if mancanti:
        print("La risposta non ha: " + ", ".join(mancanti) + ".")
        return 1
    stampa_riuscita(risposta)
    print("Fatto: la risposta è riuscita; stato, stop_reason e usage sono "
          "qui sopra.")
    return 0


def main(argv: List[str]) -> int:
    if len(argv) != 1:
        sys.stderr.write(USO)
        return 2
    try:
        return controlla(argv[0])
    except Precondizione as exc:
        esci(str(exc))
    return 2


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv[1:]))
    except SystemExit:
        raise
    except BaseException as exc:  # una riga, mai un traceback
        sys.stderr.write("controlla_risposta: errore inatteso: %s\n"
                         % type(exc).__name__)
        sys.exit(2)
