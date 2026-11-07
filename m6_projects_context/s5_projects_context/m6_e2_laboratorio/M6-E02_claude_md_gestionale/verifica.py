#!/usr/bin/env python3
"""verifica.py di M6-E02 «Un CLAUDE.md per il gestionale»: i criteri delle
tre richieste del laboratorio, su tools/lib_controlla_contesto.py, che legge
prove-contesto/ dello spazio di lavoro, ogni volta da capo. Non scrive
niente.

Decidono l'uscita, nella libreria, soltanto la garanzia dell'avvio, dal
registro dell'hook InstructionsLoaded di ogni esecuzione (in base nessun file
di istruzioni del progetto si carica; in v1 e in v2 il CLAUDE.md della radice
si carica all'avvio) e, senza --solo-prove, ciò che manca per finire (le tre
versioni con le tre richieste, un CLAUDE.md alla radice, la v2 diversa dalla
v1). I criteri di questo file si stampano come dati, con i confronti fra le
versioni, mai come esito né come uscita:

  t1  PHPUnit ha girato: un riepilogo di PHPUnit nel risultato di un comando;
      le cifre della risposta sono quelle di quel riepilogo; il comando
      passava da tools/php.sh;
  t2  il refuso corretto (in diff.txt la riga del punto di partenza tolta e
      quella del gestionale rimessa); un commit solo; il soggetto nella forma
      di docs/convenzioni.md, 11.1; la riga «Rif: GES-0», che sta soltanto
      negli appunti del team; cambiato soltanto quel file; legacy/ e
      database/dati/ intatti;
  t3  una risposta, con le sue righe; i token della prima richiesta di ogni
      versione li stampa la libreria.

La riga del refuso non è scritta qui: è l'unica riga in cui il file del punto
di partenza dell'elemento differisce da quello del gestionale.

Uso:    verifica.py <spazio di lavoro> [--solo-prove]
Env:    PN_HANDSON_ROOT  il repository (default: la radice sopra l'elemento)
Uscita: 0 fatto (con --solo-prove: le garanzie reggono) · 1 una garanzia che
        non regge, o qualcosa che manca · 2 precondizione (argomenti, spazio di
        lavoro, il repository senza tools/, un file dell'elemento, uno stream o
        un file delle prove che non si legge) o un errore inatteso
"""
from __future__ import annotations

import os
import re
import sys
from typing import Callable, Dict, List, NamedTuple, Optional, Set, Tuple

ELEMENTO = os.path.dirname(os.path.abspath(__file__))
RADICE = os.environ.get("PN_HANDSON_ROOT") or os.path.normpath(
    os.path.join(ELEMENTO, *[os.pardir] * 4))
# -I toglie la cartella dello script dal percorso dei moduli: la libreria è
# quella di tools/ del repository. Senza, si esce 2: 1 vorrebbe dire «non
# ancora».
sys.path.insert(0, os.path.join(RADICE, "tools"))
try:
    # pylint: disable=wrong-import-position
    import lib_controlla_contesto as cc
    from lib_leggi_contesto import Problema, risultati_bash
except ImportError as exc:
    print(f"verifica: non trovo gli strumenti in {RADICE}/tools: {exc}",
          file=sys.stderr)
    sys.exit(2)

IDENT = "M6-E02"
RICHIESTE = ("t1", "t2", "t3")
PROGETTO = "progetti/gestionale-php/"
FILE_REFUSO = PROGETTO + "bin/fatturazione-mensile.php"
INTATTI = (PROGETTO + "legacy/", PROGETTO + "database/dati/")
RIF = "Rif: GES-0"
# docs/convenzioni.md, 11.1: «tipo(ambito): descrizione», con i suoi tipi.
RE_SOGGETTO = re.compile(
    r"^(feat|fix|refactor|test|docs|chore)\([^()\s]+\): \S")
RE_ANSI = re.compile(r"\x1b\[[0-9;]*m")
RE_OK = re.compile(r"\bOK \((\d+) tests?, (\d+) assertions?\)")
RE_TESTS = re.compile(
    r"\bTests: (\d+), Assertions: (\d+)((?:, [A-Za-z ]+: \d+)*)\.")
RE_VOCE = re.compile(r", ([A-Za-z ]+): (\d+)")
RE_ZERO = re.compile(r"(?<![\w.,:])0(?![\w.,:])|\bnessun|\bzero\b",
                     re.IGNORECASE)
LUNGO = 70

Esito = Tuple[bool, str]


class Riepilogo(NamedTuple):
    """Il riepilogo di PHPUnit: la riga, quanti passano, quanti falliscono."""
    riga: str
    passano: int
    falliscono: int


def corto(testo: str) -> str:
    """Una riga sola, al massimo LUNGO caratteri."""
    riga = " ".join(testo.split())
    return riga if len(riga) <= LUNGO else riga[:LUNGO - 1] + "…"


def numero_in(testo: str, n: int) -> bool:
    """Vero se il numero n sta nel testo come numero a sé."""
    return re.search(rf"(?<![\w.,:]){n}(?![\w]|[.,:]\d)", testo) is not None


def riepilogo_di(testo: str) -> Optional[Riepilogo]:
    """L'ultimo riepilogo di PHPUnit di un testo, senza i colori."""
    pulito = RE_ANSI.sub("", testo)
    trovati: List[Tuple[int, Riepilogo]] = []
    for m in RE_OK.finditer(pulito):
        trovati.append((m.start(), Riepilogo(m.group(0), int(m.group(1)), 0)))
    for m in RE_TESTS.finditer(pulito):
        voci = {nome.strip().lower(): int(valore)
                for nome, valore in RE_VOCE.findall(m.group(3))}
        falliti = voci.get("failures", 0) + voci.get("errors", 0)
        fuori = voci.get("skipped", 0) + voci.get("incomplete", 0)
        trovati.append((m.start(), Riepilogo(
            m.group(0), int(m.group(1)) - falliti - fuori, falliti)))
    if not trovati:
        return None
    return max(trovati, key=lambda coppia: coppia[0])[1]


def ultimo_riepilogo(prova: cc.Prova) -> Optional[Riepilogo]:
    """L'ultimo riepilogo di PHPUnit nei risultati dei comandi Bash."""
    trovato = None
    for _, risultato in risultati_bash(
            os.path.join(prova.cartella, "stream.jsonl")):
        riepilogo = riepilogo_di(risultato.testo)
        if riepilogo is not None:
            trovato = riepilogo
    return trovato


def testo_finale(prova: cc.Prova) -> str:
    return prova.contesto.esecuzione.testo if prova.contesto else ""


def phpunit(prova: cc.Prova) -> Esito:
    riepilogo = ultimo_riepilogo(prova)
    if riepilogo is None:
        return False, "nessun riepilogo di PHPUnit nei risultati dei comandi"
    return True, riepilogo.riga


def cifre(prova: cc.Prova) -> Esito:
    riepilogo = ultimo_riepilogo(prova)
    if riepilogo is None:
        return False, "nessun riepilogo di PHPUnit da confrontare"
    testo, mancano = testo_finale(prova), []
    if not numero_in(testo, riepilogo.passano):
        mancano.append(f"i {riepilogo.passano} che passano")
    if riepilogo.falliscono == 0:
        if not RE_ZERO.search(testo):
            mancano.append("lo 0 che fallisce")
    elif not numero_in(testo, riepilogo.falliscono):
        mancano.append(f"i {riepilogo.falliscono} che falliscono")
    if mancano:
        return False, "nella risposta mancano " + " e ".join(mancano)
    return True, (f"{riepilogo.passano} passano e {riepilogo.falliscono} "
                  "falliscono, come nel riepilogo")


def con_php_sh(prova: cc.Prova) -> Esito:
    comandi = prova.contesto.comandi if prova.contesto else []
    usati = [c for c in comandi if "php.sh" in c and "phpunit" in c]
    if not usati:
        return False, (f"{cc.quanti(len(comandi), 'comando', 'comandi')} "
                       "Bash, nessuno lancia PHPUnit con tools/php.sh")
    # Dal comando che lancia PHPUnit, la parte da tools/php.sh in poi: un
    # «cd» o un «ls» prima non dicono niente.
    comando = usati[-1]
    dove = comando.rfind("php.sh", 0, comando.rfind("phpunit"))
    if dove < 0:
        dove = comando.find("php.sh")
    inizio = max(comando.rfind(segno, 0, dove) for segno in " ;&|(") + 1
    return True, corto(comando[inizio:])


def righe_cambiate(diff: str, file: str) -> Tuple[List[str], List[str]]:
    """Le righe tolte e quelle aggiunte di un file, nel diff, senza il segno.
    Le intestazioni di un file («---», «+++») vengono prima del primo «@@»:
    una riga tolta che comincia con «--» resta una riga."""
    tolte: List[str] = []
    aggiunte: List[str] = []
    dentro = nel_blocco = False
    for riga in diff.splitlines():
        if riga.startswith("diff --git "):
            dentro = riga == f"diff --git a/{file} b/{file}"
            nel_blocco = False
        elif dentro and riga.startswith("@@"):
            nel_blocco = True
        elif dentro and nel_blocco and riga.startswith("-"):
            tolte.append(riga[1:])
        elif dentro and nel_blocco and riga.startswith("+"):
            aggiunte.append(riga[1:])
    return tolte, aggiunte


def corretto(prova: cc.Prova, coppia: Tuple[str, str]) -> Esito:
    con_refuso, giusta = coppia
    tolte, aggiunte = righe_cambiate(prova.diff, FILE_REFUSO)
    if con_refuso in tolte and giusta in aggiunte:
        altre = len(tolte) + len(aggiunte) - 2
        cambiate = cc.quanti(altre, "altra riga cambiata",
                             "altre righe cambiate")
        return True, "la riga corretta" + (
            f", e {cambiate} nel file" if altre else "")
    if con_refuso not in tolte:
        return False, ("il refuso è ancora nel file" if not tolte else
                       "il file è cambiato, ma non nella riga del refuso")
    nuove = [r for r in aggiunte if r.strip()]
    return False, "la riga è diversa: " + corto(nuove[0] if nuove else "")


def un_commit(prova: cc.Prova) -> Esito:
    n = len(prova.commit)
    if n == 1:
        return True, "1 commit"
    return False, "nessun commit" if n == 0 else f"{n} commit"


def soggetto(prova: cc.Prova) -> Esito:
    if not prova.commit:
        return False, "nessun commit"
    for commit in prova.commit:
        if not RE_SOGGETTO.match(commit.soggetto):
            return False, f"«{corto(commit.soggetto)}»"
    return True, f"«{corto(prova.commit[0].soggetto)}»"


def riga_rif(prova: cc.Prova) -> Esito:
    if not prova.commit:
        return False, "nessun commit"
    righe = [r.strip() for c in prova.commit for r in c.corpo.splitlines()]
    if RIF in righe:
        return True, RIF
    altre = [r for r in righe if r.lower().startswith("rif")]
    return False, (f"«{corto(altre[0])}»" if altre
                   else "nessuna riga «Rif:» nel messaggio")


def file_cambiati(prova: cc.Prova) -> Set[str]:
    """I file committati e quelli che git status dà ancora cambiati."""
    cambiati = set(prova.committati)
    for riga in prova.cambiati:
        for parte in riga[3:].split(" -> "):
            cambiati.add(parte.strip().strip('"'))
    return cambiati


def soltanto_quel_file(prova: cc.Prova) -> Esito:
    cambiati = file_cambiati(prova)
    if cambiati == {FILE_REFUSO}:
        return True, "1 file"
    if not cambiati:
        return False, "nessun file cambiato"
    altri = sorted(cambiati - {FILE_REFUSO})
    return False, (f"anche {cc.quanti(len(altri), 'altro', 'altri')}: "
                   + corto(", ".join(altri)))


def intatti(prova: cc.Prova) -> Esito:
    toccati = sorted(f for f in file_cambiati(prova) if f.startswith(INTATTI))
    if toccati:
        return False, corto(", ".join(toccati))
    return True, "nessun file lì"


def risposta(prova: cc.Prova) -> Esito:
    righe = [r for r in testo_finale(prova).splitlines() if r.strip()]
    if not righe:
        return False, "nessun testo nella risposta"
    return True, cc.quanti(len(righe), "riga", "righe")


def righe_del_file(percorso: str) -> List[str]:
    try:
        with open(percorso, encoding="utf-8") as fh:
            return fh.read().split("\n")
    except (OSError, UnicodeDecodeError) as exc:
        raise Problema(f"non riesco a leggere {percorso}: {exc}") from exc


def coppia_del_refuso() -> Tuple[str, str]:
    """La riga con il refuso, dal punto di partenza dell'elemento, e quella
    giusta, dal gestionale. Raises: Problema, se i due file non differiscono
    in una riga sola."""
    con = righe_del_file(os.path.join(ELEMENTO, "esercizio", FILE_REFUSO))
    senza = righe_del_file(os.path.join(RADICE, FILE_REFUSO))
    diverse = [(a, b) for a, b in zip(con, senza) if a != b]
    if len(con) != len(senza) or len(diverse) != 1:
        raise Problema(f"{FILE_REFUSO}: il punto di partenza e il gestionale "
                       "devono differire in una riga sola")
    return diverse[0]


def criteri(coppia: Tuple[str, str]
            ) -> Dict[str, List[Tuple[str, Callable[[cc.Prova], Esito]]]]:
    return {
        "t1": [("PHPUnit ha girato", phpunit),
               ("le cifre della risposta sono quelle di PHPUnit", cifre),
               ("con tools/php.sh", con_php_sh)],
        "t2": [("il refuso corretto", lambda p: corretto(p, coppia)),
               ("un commit", un_commit),
               ("il soggetto nella forma di docs/convenzioni.md, 11.1",
                soggetto),
               (f"la riga «{RIF}»", riga_rif),
               ("cambiato soltanto bin/fatturazione-mensile.php",
                soltanto_quel_file),
               ("legacy/ e database/dati/ intatti", intatti)],
        "t3": [("una risposta", risposta)],
    }


def main(argv: List[str]) -> int:
    try:
        coppia = coppia_del_refuso()
    except Problema as exc:
        print(f"verifica: {exc}", file=sys.stderr)
        return 2
    rc = cc.principale(argv, IDENT, RICHIESTE, criteri(coppia))
    if rc == 0 and "--solo-prove" not in argv[1:]:
        print("\nFatto: le tre versioni hanno girato con le tre richieste, il "
              "CLAUDE.md si è caricato dove doveva, e la v2 è diversa dalla "
              "v1. Ogni confronto è fra una sola esecuzione per versione: un "
              "campione.")
    return rc


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv[1:]))
    except Exception as exc:  # pylint: disable=broad-except
        # Un errore inatteso non è «non ancora»: è un controllo che non può
        # decidere.
        print(f"verifica: errore inatteso: {type(exc).__name__}: {exc}",
              file=sys.stderr)
        sys.exit(2)
