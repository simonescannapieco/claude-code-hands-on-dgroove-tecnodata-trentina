"""controlla_risultati.py -- M7-D05 «Cercare per significato»: legge
risposte/risultati.json e controlla che ci siano tutte le domande di
domande.txt, ognuna con le sue due classifiche; poi stampa le classifiche.

Il controllo non dice niente su Claude e non giudica quale ricerca sia
migliore: dice soltanto se la prova è stata fatta. Non chiama nessun modello e
non apre nessuna connessione.

Uso:    python3 -B -I controlla_risultati.py <spazio di lavoro>
Uscita: 0 = risposte/risultati.json c'è, con tutte le domande e le classifiche
        · 1 = il file manca, non si legge come JSON o una domanda non c'è (dice
        quale) · 2 = uso sbagliato; spazio di lavoro assente; domande.txt che
        manca; un errore inatteso (una riga, mai un traceback)
"""
from __future__ import annotations

import json
import os
import sys
from typing import Any, Dict, List, Sequence

sys.path.insert(0, os.path.dirname(os.path.realpath(__file__)))
import cerca  # noqa: E402  pylint: disable=wrong-import-position

RISULTATI = os.path.join("risposte", "risultati.json")
USO = "Uso: python3 -B -I controlla_risultati.py <spazio di lavoro>\n"
CAMPI_VOCE = ("articolo", "conteggio_parole", "coseno", "rango_parole",
              "rango_significato")


class NonFatta(Exception):
    """La prova non è stata fatta, o non è finita: uscita 1."""


def carica(percorso: str) -> Dict[str, Any]:
    """risposte/risultati.json. Raises: NonFatta."""
    if not os.path.isfile(percorso):
        raise NonFatta("manca %s: lanciate cerca.py" % RISULTATI)
    try:
        with open(percorso, encoding="utf-8") as fh:
            dati = json.load(fh)
    except (OSError, UnicodeDecodeError, ValueError) as exc:
        raise NonFatta("%s non si legge come JSON (%s): rifate la prova"
                       % (RISULTATI, exc)) from exc
    if not isinstance(dati, dict) or not isinstance(dati.get("domande"), list):
        raise NonFatta("%s non ha l'elenco delle domande: rifate la prova"
                       % RISULTATI)
    return dati


def voce_valida(voce: Any) -> bool:
    """Vero se una voce ha i campi di una classifica, dei tipi giusti."""
    if not isinstance(voce, dict) or any(c not in voce for c in CAMPI_VOCE):
        return False
    numeri = [voce[c] for c in ("conteggio_parole", "rango_parole",
                                "rango_significato")]
    return all(isinstance(n, int) and not isinstance(n, bool) for n in numeri) \
        and isinstance(voce["coseno"], (int, float)) \
        and isinstance(voce["articolo"], str)


def controlla_domande(dati: Dict[str, Any], attese: Sequence[str]) -> None:
    """Ogni domanda attesa c'è, con almeno una voce valida. Raises: NonFatta."""
    presenti = {d.get("domanda"): d for d in dati["domande"]
                if isinstance(d, dict)}
    mancano = [d for d in attese if d not in presenti]
    if mancano:
        raise NonFatta("in %s manca la domanda «%s»: rifate la prova"
                       % (RISULTATI, mancano[0]))
    for attesa in attese:
        voci = presenti[attesa].get("articoli")
        cercate = presenti[attesa].get("parole_cercate")
        if not isinstance(voci, list) or not voci \
                or not all(voce_valida(v) for v in voci) \
                or not isinstance(cercate, list):
            raise NonFatta("in %s la domanda «%s» non ha le classifiche: "
                           "rifate la prova" % (RISULTATI, attesa))


def controlla(ws: str) -> int:
    """Il controllo. Returns: 0. Raises: NonFatta, cerca.Precondizione."""
    attese = cerca.leggi_domande(ws)
    dati = carica(os.path.join(ws, RISULTATI))
    controlla_domande(dati, attese)
    print("Modello di embedding: %s, digest %s (Ollama %s), %s." % (
        dati.get("modello"), dati.get("digest"), dati.get("ollama"),
        dati.get("data_utc")))
    print("%d domande su %d in %s." % (len(attese), len(attese), RISULTATI))
    cerca.stampa_classifiche([d for d in dati["domande"]
                              if isinstance(d, dict)
                              and d.get("domanda") in attese])
    return 0


def errore(messaggio: str, uscita: int) -> int:
    """Il messaggio su STDERR, in una riga; l'uscita data."""
    sys.stderr.write("controlla_risultati.py: %s\n"
                     % " ".join(messaggio.split()))
    return uscita


def main(argv: List[str]) -> int:
    for flusso in (sys.stdout, sys.stderr):
        riconfigura = getattr(flusso, "reconfigure", None)
        if riconfigura is not None:
            riconfigura(errors="replace")
    if len(argv) != 1 or argv[0].startswith("-"):
        sys.stderr.write(USO)
        return 2
    if not os.path.isdir(argv[0]):
        return errore("spazio di lavoro assente: %s" % argv[0], 2)
    try:
        return controlla(argv[0])
    except NonFatta as exc:
        return errore(str(exc), 1)
    except cerca.Precondizione as exc:
        return errore(str(exc), 2)
    except Exception as exc:  # mai un traceback: un errore inatteso esce 2
        return errore("errore inatteso (%s: %s)" % (type(exc).__name__, exc), 2)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
