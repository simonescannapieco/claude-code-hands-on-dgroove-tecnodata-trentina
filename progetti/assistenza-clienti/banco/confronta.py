#!/usr/bin/env python3
"""confronta.py -- mette a confronto due versioni dell'assistente provate sui
casi (due cartelle scritte da `prova.py casi`), caso per caso.

Per ogni caso: quante asserzioni soddisfa ciascuna versione, quante chiamate,
i token della prima richiesta. In fondo, sul totale, una riga per
l'affermazione messa alla prova: «confermata in questa misura» se la seconda
versione soddisfa più asserzioni, «non distinguibile» se pari, «non confermata
in questa misura» se meno. Sono dati di una misura piccola: nessun esito dice
«smentita» e nessuno decide l'uscita.

Uso:    python3 confronta.py <cartella versione A> <cartella versione B>
Uscita: 0 = ogni caso c'è in entrambe ed è finito bene · 1 = un caso che manca
        a una versione, o un'esecuzione non finita · 2 = una cartella che non
        c'è, un esito che non si legge o senza i campi, un errore inatteso
        (una riga, mai un traceback)
"""
import json
import sys
from pathlib import Path
from typing import Dict, List

# Niente __pycache__ nello spazio di lavoro, anche senza python3 -B.
sys.dont_write_bytecode = True

CAMPI_ESITO = ("soddisfatte", "totale")


def _controlla_esito(esito: object, percorso: Path) -> None:
    """Un esito ha i numeri che il confronto somma: altrimenti esce 2."""
    assenti = [c for c in CAMPI_ESITO if not isinstance(esito, dict)
               or isinstance(esito.get(c), bool)
               or not isinstance(esito.get(c), int)]
    if assenti:
        print(f"confronta: {percorso} non è un esito di prova.py: mancano i "
              f"campi «{', '.join(assenti)}»", file=sys.stderr)
        sys.exit(2)


def _carica(cartella: Path) -> Dict[str, dict]:
    if not cartella.is_dir():
        print(f"confronta: cartella assente: {cartella}", file=sys.stderr)
        sys.exit(2)
    esiti = {}
    for percorso in sorted(cartella.glob("*/esito.json")):
        try:
            esiti[percorso.parent.name] = json.loads(
                percorso.read_text(encoding="utf-8"))
        except (OSError, UnicodeDecodeError, ValueError) as exc:
            print(f"confronta: non riesco a leggere {percorso}: {exc}",
                  file=sys.stderr)
            sys.exit(2)
        _controlla_esito(esiti[percorso.parent.name], percorso)
    return esiti


def _problemi(casi: List[str], a: Dict[str, dict], b: Dict[str, dict]
              ) -> List[str]:
    problemi = []
    for caso in casi:
        for nome, esiti in (("prima", a), ("seconda", b)):
            esito = esiti.get(caso)
            if esito is None:
                problemi.append(f"{caso}: manca alla {nome} versione")
            elif not esito.get("completa") or esito.get("errore"):
                problemi.append(f"{caso}: l'esecuzione della {nome} "
                                "versione non è finita")
    return problemi


def _riga(caso: str, esito: dict) -> str:
    return (f"{esito['soddisfatte']}/{esito['totale']}"
            f" · {len(esito.get('chiamate', []))} chiamate"
            f" · {esito.get('token_prima_richiesta')} token")


def _conclusione(a: int, b: int) -> str:
    if b > a:
        return "confermata in questa misura"
    if b == a:
        return "non distinguibile"
    return "non confermata in questa misura"


def _confronta() -> int:
    if len(sys.argv) != 3:
        print(__doc__.split("Uscita:")[0], file=sys.stderr)
        return 2
    a, b = _carica(Path(sys.argv[1])), _carica(Path(sys.argv[2]))
    casi = sorted(set(a) | set(b))
    problemi = _problemi(casi, a, b)
    if not casi:
        print("confronta: nessun esito nelle due cartelle", file=sys.stderr)
        return 1
    if problemi:
        for riga in problemi:
            print(riga)
        return 1
    print(f"{'caso':<10} {sys.argv[1]}  ->  {sys.argv[2]}")
    for caso in casi:
        print(f"{caso:<10} {_riga(caso, a[caso])}  ->  {_riga(caso, b[caso])}")
    tot_a = sum(e["soddisfatte"] for e in a.values())
    tot_b = sum(e["soddisfatte"] for e in b.values())
    tot = sum(e["totale"] for e in a.values())
    print(f"totale: {tot_a}/{tot}  ->  {tot_b}/{tot}")
    print(f"la seconda versione rispetto alla prima: {_conclusione(tot_a, tot_b)}")
    return 0


def main() -> int:
    try:
        return _confronta()
    except KeyboardInterrupt:
        print("confronta: interrotto", file=sys.stderr)
        return 2
    except Exception as exc:  # mai un traceback: un errore inatteso esce 2
        testo = " ".join(str(exc).split())
        print(f"confronta: errore inatteso ({type(exc).__name__}: {testo})",
              file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
