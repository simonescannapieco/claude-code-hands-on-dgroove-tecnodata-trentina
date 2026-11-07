"""lib_controlla_contesto.py -- il controllo comune delle tracce del
laboratorio del Modulo 6 (M6-E02, il gestionale; M6-E03, la rete): legge
prove-contesto/ di uno spazio di lavoro, da capo a ogni chiamata, e confronta
le versioni. Ogni elemento ha il suo verifica.py, con le sue richieste e i
suoi criteri, e chiama principale().

Che cosa decide (le regole del controllo, nel CLAUDE.md del repository):
- la garanzia del prodotto, a ogni esecuzione: in base non si carica nessun
  file di istruzioni del progetto; in v1 e in v2 il CLAUDE.md della radice si
  carica all'avvio, come dice la documentazione: «CLAUDE.md and CLAUDE.local.md
  files in the directory hierarchy above the working directory are loaded at
  launch.» (https://code.claude.com/docs/en/memory). Lo dice il registro
  dell'hook InstructionsLoaded di ogni esecuzione, non la risposta. Una
  garanzia che non regge esce 1, anche con --solo-prove;
- per finire l'esercizio (senza --solo-prove): base, v1 e v2 con tutte le
  richieste, ogni sessione finita bene, un CLAUDE.md alla radice in v1 e in
  v2, una fotografia di v2 diversa da quella di v1.

Che cosa stampa come dati, mai come esito né come uscita: per richiesta e per
versione i criteri dell'elemento, sì o no, con il dettaglio; v1 contro base e
v2 contro v1, criterio per criterio, nelle parole del corso: «confermata»
(prima no, con la versione sì), «non distinguibile» (uguale), «non confermata
in questa misura» (prima sì, con la versione no); i token della prima
richiesta, i turni, i secondi e i token di ogni esecuzione, sommati su tutti i
segmenti; le righe del CLAUDE.md di ogni versione.

Uscita di principale(): 0 garanzie a posto (e, senza --solo-prove, tutto
fatto) · 1 una garanzia non regge, o manca qualcosa per finire · 2 uno
spazio di lavoro o una prova che non si legge. Libreria: nessun bit di
esecuzione; chi la importa mette tools/ nel sys.path.
"""
from __future__ import annotations

import filecmp
import os
import re
import sys
from typing import Callable, Dict, List, NamedTuple, Optional, Sequence, Tuple

from lib_leggi_contesto import (Caricamento, Contesto, Problema, _eventi,
                                leggi_caricamenti, leggi_contesto)

VERSIONI = ("base", "v1", "v2")
RADICE_ISTRUZIONI = ("CLAUDE.md", ".claude/CLAUDE.md")
TIPI_PROGETTO = ("Project", "Local")
# Come HANDSON_SAFE_TOKEN_RE di tools/lib_handson.sh: un percorso così si
# stampa com'è, gli altri fra apici.
RE_SICURO = re.compile(r"^[A-Za-z0-9._/:=@%+,-]+$")


class Commit(NamedTuple):
    soggetto: str
    corpo: str


class Prova(NamedTuple):
    """Un'esecuzione: una richiesta in una versione."""
    versione: str
    richiesta: str
    cartella: str
    prompt: str
    contesto: Optional[Contesto]
    caricamenti: List[Caricamento]
    cambiati: List[str]
    commit: List[Commit]
    committati: List[str]
    diff: str


Esito = Tuple[bool, str]
Criterio = Tuple[str, Callable[[Prova], Esito]]


def quanti(numero: int, uno: str, molti: str) -> str:
    """«1 riga», «2 righe», «0 righe»: il nome si accorda con il numero."""
    return f"{numero} {uno if numero == 1 else molti}"


def _citato(testo: str) -> str:
    """Un argomento da incollare in una shell, come handson::quote_into."""
    if RE_SICURO.match(testo):
        return testo
    return "'" + testo.replace("'", "'\\''") + "'"


def opzione_radice(ws: str) -> str:
    """« --radice <cartella>» quando lo spazio di lavoro non sta nella radice
    di norma (PN_WORKSPACE_ROOT, se no ~/corso-claude-code), come la stampa
    tools/prepara_esercizio.sh: il comando da rilanciare la deve ripetere.
    Altrimenti la stringa vuota."""
    radice = os.path.dirname(os.path.realpath(ws))
    norma = os.environ.get("PN_WORKSPACE_ROOT") or ""
    if not norma and os.environ.get("HOME"):
        norma = os.path.join(os.environ["HOME"], "corso-claude-code")
    if norma and os.path.realpath(norma) == radice:
        return ""
    return " --radice " + _citato(radice)


def _testo(percorso: str) -> str:
    try:
        with open(percorso, encoding="utf-8") as fh:
            return fh.read()
    except (OSError, UnicodeDecodeError) as exc:
        raise Problema(f"non riesco a leggere {percorso}: {exc}") from exc


def _righe(percorso: str) -> List[str]:
    return [r for r in _testo(percorso).splitlines() if r.strip()]


def leggi_commit(percorso: str) -> List[Commit]:
    """commit.txt di prova_contesto.sh: soggetto, riga vuota, corpo, ----."""
    commit, blocco = [], []
    for riga in _testo(percorso).splitlines():
        if riga == "----":
            if blocco:
                commit.append(Commit(blocco[0], "\n".join(blocco[1:]).strip()))
            blocco = []
        else:
            blocco.append(riga)
    if any(r.strip() for r in blocco):
        raise Problema(f"{percorso}: un commit senza la riga «----»")
    return commit


def _contesto(stream: str) -> Optional[Contesto]:
    """Il contesto di uno stream; None se la sessione non ha un risultato
    (un'esecuzione fallita: si rifà, non è un errore del controllo). Uno
    stream con un risultato che non si legge è un Problema."""
    if not any(e.get("type") == "result" for e in _eventi(stream)):
        return None
    return leggi_contesto(stream)


def leggi_prova(base: str, versione: str, richiesta: str) -> Prova:
    """Raises: Problema se un file che prova_contesto.sh lascia non c'è."""
    cartella = os.path.join(base, versione, richiesta)
    contesto = _contesto(os.path.join(cartella, "stream.jsonl"))
    return Prova(
        versione=versione, richiesta=richiesta, cartella=cartella,
        prompt=_testo(os.path.join(cartella, "prompt.txt")).strip(),
        contesto=contesto,
        caricamenti=leggi_caricamenti(os.path.join(cartella,
                                                   "caricamenti.jsonl")),
        cambiati=_righe(os.path.join(cartella, "file-cambiati.txt")),
        commit=leggi_commit(os.path.join(cartella, "commit.txt")),
        committati=_righe(os.path.join(cartella, "file-committati.txt")),
        diff=_testo(os.path.join(cartella, "diff.txt")))


def riuscita(prova: Prova) -> bool:
    c = prova.contesto
    return c is not None and c.esecuzione.completa \
        and not c.esecuzione.errore


def caricati_dal_progetto(prova: Prova) -> List[Caricamento]:
    return [c for c in prova.caricamenti if c.memory_type in TIPI_PROGETTO]


def garanzia(prova: Prova, radice: Optional[str]) -> Optional[str]:
    """Il motivo per cui la garanzia dell'avvio non regge, o None."""
    progetto = caricati_dal_progetto(prova)
    if prova.versione == "base":
        if progetto:
            return (f"base/{prova.richiesta}: senza file di istruzioni si è "
                    f"caricato {progetto[0].file_path}")
        return None
    if radice is None:
        return None
    if not any(c.file_path == radice and c.load_reason == "session_start"
               for c in progetto):
        return (f"{prova.versione}/{prova.richiesta}: {radice} non si è "
                "caricato all'avvio (nessuna riga session_start nel registro "
                "dell'hook)")
    return None


def radice_della(foto: str) -> Optional[str]:
    for nome in RADICE_ISTRUZIONI:
        if os.path.isfile(os.path.join(foto, nome)):
            return nome
    return None


def foto_uguali(a: str, b: str) -> bool:
    confronto = filecmp.dircmp(a, b)
    if confronto.left_only or confronto.right_only or confronto.diff_files \
            or confronto.funny_files:
        return False
    return all(foto_uguali(os.path.join(a, d), os.path.join(b, d))
               for d in confronto.common_dirs)


def parola(prima: bool, dopo: bool) -> str:
    if prima == dopo:
        return "non distinguibile"
    return "confermata" if dopo else "non confermata in questa misura"


def _numeri(prova: Prova) -> str:
    if prova.contesto is None:
        return "nessuno stream"
    e = prova.contesto.esecuzione
    return (f"prima richiesta {prova.contesto.prima_richiesta} token · "
            f"{quanti(int(e.turni), 'turno', 'turni')} · {e.secondi:.0f} s · "
            f"{e.token_totali} token")


class Esame(NamedTuple):
    prove: Dict[Tuple[str, str], Prova]
    radici: Dict[str, Optional[str]]
    righe_radice: Dict[str, int]
    garanzie: List[str]
    mancano: List[str]


def esamina(ws: str, ident: str, richieste: Sequence[str]) -> Esame:
    """Legge prove-contesto/ da capo. Raises: Problema."""
    base = os.path.join(ws, "prove-contesto")
    prove: Dict[Tuple[str, str], Prova] = {}
    radici: Dict[str, Optional[str]] = {}
    righe: Dict[str, int] = {}
    garanzie: List[str] = []
    mancano: List[str] = []
    radice = opzione_radice(ws)
    for v in VERSIONI:
        cartella = os.path.join(base, v)
        if not os.path.isdir(cartella):
            mancano.append(f"la versione {v} non ha girato: "
                           f"tools/prova_contesto.sh {ident} {v}{radice}")
            continue
        foto = os.path.join(cartella, "fotografia")
        radici[v] = radice_della(foto) if v != "base" else None
        if radici[v]:
            righe[v] = len(_testo(os.path.join(foto, radici[v])).splitlines())
        elif v != "base":
            mancano.append(f"{v} non ha un CLAUDE.md alla radice dello spazio "
                           "di lavoro")
        for r in richieste:
            if not os.path.isfile(os.path.join(cartella, r, "stream.jsonl")):
                mancano.append(f"{v}/{r} non c'è: rifate il giro {v}")
                continue
            prova = leggi_prova(base, v, r)
            prove[(v, r)] = prova
            if not riuscita(prova):
                mancano.append(f"{v}/{r}: la sessione non è finita bene, "
                               f"vedi {v}/{r}/stderr.txt")
                continue
            motivo = garanzia(prova, radici.get(v))
            if motivo:
                garanzie.append(motivo)
    if "v1" in radici and "v2" in radici and foto_uguali(
            os.path.join(base, "v1", "fotografia"),
            os.path.join(base, "v2", "fotografia")):
        mancano.append("v2 è uguale a v1: cambiate i file dopo le prove "
                       "della v1, poi rifate il giro v2")
    return Esame(prove, radici, righe, garanzie, mancano)


def _stampa_richiesta(esame: Esame, r: str, criteri: List[Criterio]) -> None:
    presenti = [v for v in VERSIONI if (v, r) in esame.prove]
    if not presenti:
        return
    print(f"\nRichiesta {r}: «{esame.prove[(presenti[0], r)].prompt}»")
    esiti: Dict[Tuple[str, str], bool] = {}
    for nome, giudice in criteri:
        celle = []
        for v in presenti:
            prova = esame.prove[(v, r)]
            if not riuscita(prova):
                celle.append(f"{v} -")
                continue
            vero, dettaglio = giudice(prova)
            esiti[(v, nome)] = vero
            celle.append(f"{v} {'sì' if vero else 'no'} ({dettaglio})")
        print(f"  {nome}: " + "; ".join(celle))
    for prima, dopo in (("base", "v1"), ("v1", "v2")):
        confronti = [f"{nome}: {parola(esiti[(prima, nome)], esiti[(dopo, nome)])}"
                     for nome, _ in criteri
                     if (prima, nome) in esiti and (dopo, nome) in esiti]
        if confronti:
            print(f"  {dopo} contro {prima}: " + "; ".join(confronti))
    for v in presenti:
        print(f"  {v}: {_numeri(esame.prove[(v, r)])}")


def stampa(esame: Esame, richieste: Sequence[str],
           criteri: Dict[str, List[Criterio]]) -> None:
    print("Il confronto delle versioni (dati: i criteri e i confronti non "
          "decidono l'uscita)")
    for v in ("v1", "v2"):
        if esame.radici.get(v):
            righe = quanti(esame.righe_radice[v], "riga", "righe")
            print(f"  {v}: {esame.radici[v]}, {righe}")
    for r in richieste:
        _stampa_richiesta(esame, r, criteri.get(r, []))
    print()
    for v in VERSIONI:
        fatte = [p for (vv, _), p in esame.prove.items()
                 if vv == v and riuscita(p)]
        if not fatte:
            continue
        cosa = ("nessun file di istruzioni caricato" if v == "base" else
                f"{esame.radici.get(v) or 'nessun CLAUDE.md'} caricato "
                "all'avvio")
        buone = [p for p in fatte if garanzia(p, esame.radici.get(v)) is None]
        quante = quanti(len(fatte), "esecuzione", "esecuzioni")
        print(f"Garanzia, {v}: {cosa} in {len(buone)} su {quante}")


def principale(argv: Sequence[str], ident: str, richieste: Sequence[str],
               criteri: Dict[str, List[Criterio]]) -> int:
    """argv: <spazio di lavoro> [--solo-prove]. Returns: l'uscita."""
    if not argv or not os.path.isdir(argv[0]) \
            or any(a != "--solo-prove" for a in argv[1:]):
        print("uso: verifica.py <spazio di lavoro> [--solo-prove]",
              file=sys.stderr)
        return 2
    try:
        esame = esamina(argv[0], ident, richieste)
        stampa(esame, richieste, criteri)
    except Problema as exc:
        print(f"verifica: {exc}", file=sys.stderr)
        return 2
    for motivo in esame.garanzie:
        print(f"GARANZIA {motivo}")
    if "--solo-prove" in argv[1:]:
        return 1 if esame.garanzie else 0
    for cosa in esame.mancano:
        print(f"MANCA {cosa}")
    return 1 if esame.garanzie or esame.mancano else 0
