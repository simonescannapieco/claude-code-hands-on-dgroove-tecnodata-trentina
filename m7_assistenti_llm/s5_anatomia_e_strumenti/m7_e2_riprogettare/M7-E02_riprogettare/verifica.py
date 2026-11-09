"""verifica.py di M7-E02 «Riprogettare un'interazione».

Legge le esecuzioni dello spazio di lavoro, risultati/v0/ e risultati/v1/, una
cartella per caso (scritte da tools/prova_assistente.sh casi), e per ogni caso e
ogni versione ricalcola tutto dallo stream e dal registro del server: se la
chiamata è finita, che cosa ha chiamato, le asserzioni del caso. Usa lib_banco e
i casi del repository (progetti/assistenza-clienti/banco/), non le loro copie
nello spazio di lavoro; esito.json non si legge.

È fatta quando v1/ c'è e le due versioni hanno girato su ogni caso, ciascuna
chiamata finita bene. Le asserzioni e il confronto delle due versioni si stampano
come dati (righe «(dato)»): non decidono l'uscita. Una riga per ogni gruppo di
asserzioni confronta v1 con v0: «confermata in questa misura» se la v1 ne soddisfa
di più, «non distinguibile» se pari, «non confermata in questa misura» se meno:
sono i dati di una misura piccola, una esecuzione per caso e per versione, e le
due versioni differiscono in tutto ciò che è stato riscritto; nessun esito dice
«smentita».

Uso:    python3 -B -I verifica.py <spazio di lavoro>
Env:    PN_HANDSON_ROOT  il repository, dove stanno lib_banco e i casi (default:
                         la radice sopra la cartella dell'elemento)
Uscita: 0 = v1/ c'è ed entrambe le versioni hanno girato su ogni caso, ogni
        chiamata finita bene · 1 = una versione o un caso che manca, una chiamata
        non finita · 2 = precondizione (spazio di lavoro assente; lib_banco o
        i casi che non si trovano; un file che non si legge)
"""
from __future__ import annotations

import importlib.util
import json
import os
import sys
from typing import Any, Dict, List, NamedTuple, Optional, Tuple

USO = "Uso: python3 -B -I verifica.py <spazio di lavoro>\n"
VERSIONI = ("v0", "v1")
PERCORSO_BANCO = os.path.join("progetti", "assistenza-clienti", "banco")
PERCORSO_SCENARI = os.path.join("progetti", "assistenza-clienti", "scenari")
GRUPPI = (
    ("escalation", ("escalation",),
     "i criteri di passaggio a un operatore, con gli esempi"),
    ("strumenti", ("deve_chiamare", "non_deve_chiamare"),
     "le descrizioni degli strumenti: quali chiamate"),
    ("prima_di", ("prima_di",),
     "la verifica prima dei dati (prima_di)"),
    ("risposta", ("risposta_contiene", "risposta_non_contiene"),
     "che cosa dice la risposta"),
)
FATTO = ("Fatto: v1/ c'è e le due versioni hanno girato su ogni caso; il "
         "confronto è qui sopra, come dato.")


class Precondizione(Exception):
    """Qualcosa che impedisce di partire: uscita 2."""


class Esecuzione(NamedTuple):
    """Un caso di una versione, ricalcolato dallo stream e dal registro."""
    finita: bool
    errore: str
    asserzioni: List[Dict[str, Any]]
    chiamate: List[str]
    token: Optional[int]
    turni: int


def radice_repo() -> str:
    """Il repository: PN_HANDSON_ROOT, o la radice sopra la cartella
    dell'elemento (<radice>/m7_…/s5_…/m7_e2_…/M7-E02_…/verifica.py)."""
    dato = os.environ.get("PN_HANDSON_ROOT")
    if dato:
        return dato
    qui = os.path.realpath(__file__)
    for _ in range(5):
        qui = os.path.dirname(qui)
    return qui


def carica_lib(radice: str) -> Any:
    """lib_banco del repository; Precondizione se non si trova."""
    percorso = os.path.join(radice, PERCORSO_BANCO, "lib_banco.py")
    if not os.path.isfile(percorso):
        raise Precondizione("non trovo %s" % percorso)
    spec = importlib.util.spec_from_file_location("lib_banco", percorso)
    if spec is None or spec.loader is None:
        raise Precondizione("non riesco a caricare %s" % percorso)
    modulo = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(modulo)
    return modulo


def carica_casi(lib: Any, radice: str) -> List[Dict[str, Any]]:
    """I casi del banco, dal repository; Precondizione se non ci sono."""
    cartella = os.path.join(radice, PERCORSO_BANCO, "casi")
    scenari = os.path.join(radice, PERCORSO_SCENARI)
    if not os.path.isdir(cartella):
        raise Precondizione("non trovo i casi in %s" % cartella)
    from pathlib import Path
    try:
        casi = [lib.carica_caso(Path(cartella, nome), Path(scenari))
                for nome in sorted(os.listdir(cartella))
                if nome.endswith(".json")]
    except lib.Problema as exc:
        raise Precondizione("i casi del banco non si leggono: %s" % exc) from exc
    if not casi:
        raise Precondizione("nessun caso in %s" % cartella)
    return casi


def leggi_esecuzione(lib: Any, caso: Dict[str, Any], cartella: str
                     ) -> Tuple[Optional[Esecuzione], Optional[str]]:
    """(l'esecuzione, oppure None e il motivo per cui manca)."""
    from pathlib import Path
    stream = os.path.join(cartella, "stream.jsonl")
    if not os.path.isfile(stream):
        return None, "manca"
    try:
        with open(stream, encoding="utf-8") as fh:
            letto = lib.leggi_stream(fh.read())
    except (OSError, UnicodeDecodeError) as exc:
        raise Precondizione("%s non si legge: %s" % (stream, exc)) from exc
    if not letto["completa"]:
        return None, letto.get("problema") \
            or "lo stream non finisce con il risultato"
    if letto["errore"]:
        return None, "la chiamata è finita con un errore"
    try:
        chiamate = lib.leggi_registro(Path(cartella, "registro.jsonl"))
    except (OSError, UnicodeDecodeError, lib.Problema) as exc:
        raise Precondizione("registro di %s non si legge: %s"
                            % (cartella, exc)) from exc
    asserzioni = lib.valuta(caso, chiamate, letto["risposta"])
    nomi = [str(c.get("capacita")) for c in chiamate]
    return Esecuzione(True, "", asserzioni, nomi,
                      letto["token_prima_richiesta"], letto["turni"]), None


def conclusione(prima: int, dopo: int) -> str:
    if dopo > prima:
        return "confermata in questa misura"
    if dopo == prima:
        return "non distinguibile"
    return "non confermata in questa misura"


def stampa_casi(casi: List[Dict[str, Any]],
                esiti: Dict[str, Dict[str, Esecuzione]]) -> None:
    """Una riga per caso, v0 e v1, e le asserzioni non soddisfatte."""
    print("(dato) caso per caso, v0 -> v1: asserzioni soddisfatte · chiamate · "
          "token della prima richiesta")
    for caso in casi:
        cid = caso["id"]
        pezzi = []
        for versione in VERSIONI:
            e = esiti[versione][cid]
            pezzi.append("%d/%d · %d chiamate · %s token" % (
                sum(1 for a in e.asserzioni if a["esito"]), len(e.asserzioni),
                len(e.chiamate), e.token))
        print("(dato) %-8s %s  ->  %s" % (cid, pezzi[0], pezzi[1]))
        for versione in VERSIONI:
            for a in esiti[versione][cid].asserzioni:
                if not a["esito"]:
                    print("(dato)   %s, %s non soddisfatta: %s %s" % (
                        cid, versione, a["tipo"], a["oggetto"]))


def stampa_confronto(esiti: Dict[str, Dict[str, Esecuzione]],
                     casi: List[Dict[str, Any]]) -> None:
    """Il confronto v1/v0 per gruppo di asserzioni: dati, mai l'uscita."""
    def conta(versione: str, tipi: Tuple[str, ...]) -> Tuple[int, int]:
        fatte, totale = 0, 0
        for caso in casi:
            for a in esiti[versione][caso["id"]].asserzioni:
                if a["tipo"] in tipi:
                    totale += 1
                    fatte += 1 if a["esito"] else 0
        return fatte, totale
    print("(dato) il confronto, v1 rispetto a v0 (una misura piccola: una "
          "esecuzione per caso e per versione):")
    tutti = tuple(t for _, tipi, _ in GRUPPI for t in tipi)
    for nome, tipi, spiegazione in GRUPPI:
        (a, n), (b, _) = conta("v0", tipi), conta("v1", tipi)
        print("(dato) %-10s v0 %d/%d  ->  v1 %d/%d  %s (%s)" % (
            nome, a, n, b, n, conclusione(a, b), spiegazione))
    (a, n), (b, _) = conta("v0", tutti), conta("v1", tutti)
    print("(dato) totale     v0 %d/%d  ->  v1 %d/%d  %s" % (
        a, n, b, n, conclusione(a, b)))


def controlla(ws: str) -> int:
    radice = radice_repo()
    lib = carica_lib(radice)
    casi = carica_casi(lib, radice)
    problemi: List[str] = []
    versione_ws = os.path.join(ws, "v1")
    for nome in ("system-prompt.md", "strumenti.json", "regole-escalation.md"):
        if not os.path.isfile(os.path.join(versione_ws, nome)):
            problemi.append("manca v1/%s: la riprogettazione non è completa."
                            % nome)
    esiti: Dict[str, Dict[str, Esecuzione]] = {v: {} for v in VERSIONI}
    for versione in VERSIONI:
        base = os.path.join(ws, "risultati", versione)
        if not os.path.isdir(base):
            problemi.append("manca la cartella risultati/%s: fate girare i "
                            "casi anche su questa versione." % versione)
            continue
        for caso in casi:
            cartella = os.path.join(base, caso["id"])
            esecuzione, motivo = leggi_esecuzione(lib, caso, cartella)
            if esecuzione is None:
                problemi.append("risultati/%s/%s: %s." % (versione, caso["id"],
                                                         motivo))
            else:
                esiti[versione][caso["id"]] = esecuzione
    if problemi:
        for riga in problemi:
            print(riga)
        return 1
    stampa_casi(casi, esiti)
    stampa_confronto(esiti, casi)
    print(FATTO)
    return 0


def main(argv: List[str]) -> int:
    if len(argv) != 1:
        sys.stderr.write(USO)
        return 2
    ws = argv[0]
    if not os.path.isdir(ws):
        sys.stderr.write("verifica: spazio di lavoro assente: %s\n" % ws)
        return 2
    try:
        return controlla(ws)
    except Precondizione as exc:
        sys.stderr.write("verifica: %s\n" % exc)
        return 2


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv[1:]))
    except SystemExit:
        raise
    except BaseException as exc:  # una riga, mai un traceback
        sys.stderr.write("verifica: errore inatteso: %s: %s\n"
                         % (type(exc).__name__, exc))
        sys.exit(2)
