#!/usr/bin/env python3
"""verifica.py di M2-E01 e M2-E02 -- le misure di un'esercitazione sui prompt.

Lo chiama verifica.sh, accanto; il file è lo stesso nei due elementi.
Le cartelle di prompt dello spazio di lavoro sono quelle che contengono
prompt/v0.md: la cartella stessa in M2-E01, le famiglie sviluppo, supporto
e sistemi in M2-E02. Una versione è «v» e un numero senza zeri davanti
(v0, v1, v2, ...), come la vuole misura.sh: un file di misura con un altro
nome (v2b, v01) non conta. Per ciascuna cartella controlla:
  - v0 e almeno v1 misurate: risposte/<v>.json (claude -p senza errori,
    con una risposta e i conteggi di usage in numeri), controlli/<v>.txt
    con il suo totale, giudizi/<v>.json con il giudizio strutturato e un
    esito per ogni affermazione di rubrica.md; un file di misura che manca
    o è rovinato chiede di misurare di nuovo quella versione;
  - un prompt nuovo: prompt/v1.md diverso da prompt/v0.md;
  - la misura dell'ultima versione (la più alta) contro quella di v0: la
    somma dei controlli superati e delle affermazioni rispettate. In M2-E01
    deve crescere, e la risposta dell'ultima versione non deve ripetere il
    numero di telefono del cliente; in M2-E02 nessuna famiglia deve
    peggiorare, almeno due devono migliorare, e almeno due devono avere
    due cicli (v2);
  - registro.md compilato: le righe di v0 e v1 (in M2-E02, di ogni
    famiglia) senza «…» nelle colonne del cambiamento e delle misure.
Il giudizio lo dà un modello: rilanciare una misura può cambiarlo.

Uso:    verifica.py <spazio di lavoro>
Uscita: 0 fatto · 1 qualcosa manca, è da misurare di nuovo o non migliora
        · 2 precondizione (spazio di lavoro assente o che non si legge, un
        file o una cartella che c'è ma non si legge); mai un traceback: un
        errore inatteso esce 2, con un messaggio di una riga
"""
from __future__ import annotations

import json
import os
import re
import sys
from typing import Dict, List, Optional, Tuple

FAMIGLIE = ("sviluppo", "supporto", "sistemi")
VERSIONE = re.compile(r"(v(?:0|[1-9][0-9]*))\.json")  # con fullmatch
CLAIM = re.compile(r"^- \*\*([a-z][a-z0-9_]*)\*\*:\s+\S")
TOTALE = re.compile(r"^totale\t([0-9]+)/([0-9]+)$", re.M)
TELEFONO = re.compile(r"000[ .]?000[ .]?0103")
NUMERO = re.compile(r"[0-9]+")              # con fullmatch: cifre ASCII
# I conteggi di usage che legge strumenti/kit.py: devono essere numeri.
USAGE = ("input_tokens", "cache_creation_input_tokens",
         "cache_read_input_tokens", "output_tokens")
VUOTO = "…"


class Precondizione(Exception):
    """Un file o una cartella che c'è ma non si legge: uscita 2."""


def non_si_legge(percorso: str, exc: Exception) -> Precondizione:
    """La Precondizione di un percorso che c'è ma non si legge."""
    return Precondizione("%s non si legge (%s)" % (
        percorso, getattr(exc, "strerror", None) or exc))


def leggi_byte(percorso: str) -> Optional[bytes]:
    """I byte del file, None se non c'è; Precondizione se c'è ma non si
    legge (i permessi, una cartella al posto del file)."""
    try:
        with open(percorso, "rb") as fh:
            return fh.read()
    except FileNotFoundError:
        return None
    except OSError as exc:
        raise non_si_legge(percorso, exc)


def leggi(percorso: str) -> Optional[str]:
    """Il testo del file in UTF-8, None se non c'è; Precondizione se c'è
    ma non si legge."""
    dati = leggi_byte(percorso)
    try:
        return None if dati is None else dati.decode("utf-8")
    except UnicodeDecodeError as exc:
        raise non_si_legge(percorso, exc)


def ordine(versione: str) -> int:
    """La chiave d'ordine di v0, v1, v2, ...: il numero dopo la «v»."""
    m = re.fullmatch(r"v(0|[1-9][0-9]*)", versione)
    return int(m.group(1)) if m else -1


def misurate(cartella: str) -> List[str]:
    """Le versioni con una risposta in risposte/, in ordine; Precondizione
    se risposte/ c'è ma non si legge."""
    base = os.path.join(cartella, "risposte")
    try:
        nomi = os.listdir(base)
    except FileNotFoundError:
        return []
    except OSError as exc:
        raise non_si_legge(base, exc)
    trovate = [m.group(1) for m in map(VERSIONE.fullmatch, nomi) if m]
    return sorted(trovate, key=ordine)


def ids_rubrica(cartella: str) -> List[str]:
    """Gli id delle affermazioni di rubrica.md."""
    testo = leggi(os.path.join(cartella, "rubrica.md")) or ""
    return [m.group(1) for m in map(CLAIM.match, testo.splitlines()) if m]


def json_claude(percorso: str, nome: str) -> Tuple[Optional[dict], str]:
    """(il JSON di claude -p, "") o (None, il problema); nome è il file
    come lo scrive il messaggio."""
    dati = leggi_byte(percorso)
    if dati is None:
        return None, "manca %s" % nome
    try:
        doc = json.loads(dati.decode("utf-8"))
    except (ValueError, RecursionError):
        return None, "%s non è un JSON valido" % nome
    if not isinstance(doc, dict) or doc.get("type") != "result":
        return None, "%s non è il JSON di claude -p" % nome
    if doc.get("is_error"):
        return None, "%s contiene un errore di Claude Code" % nome
    return doc, ""


def usage_numerico(doc: dict) -> bool:
    """Vero se i conteggi di usage sono numeri interi, come li vuole
    strumenti/kit.py per il confronto."""
    uso = doc.get("usage") or {}
    if not isinstance(uso, dict):
        return False
    for chiave in USAGE:
        valore = uso.get(chiave)
        if valore is None or (isinstance(valore, int)
                              and not isinstance(valore, bool)):
            continue
        if not (isinstance(valore, str) and NUMERO.fullmatch(valore)):
            return False
    return True


def testo_misura(percorso: str) -> str:
    """Il testo di un file di misura, "" se manca o non è UTF-8 (una misura
    da rifare); Precondizione se c'è ma non si legge."""
    dati = leggi_byte(percorso)
    try:
        return "" if dati is None else dati.decode("utf-8")
    except UnicodeDecodeError:
        return ""


def file_misura(ws: str, cartella: str, sotto: str,
                versione: str) -> Tuple[Optional[dict], str]:
    """json_claude di <cartella>/<sotto>/<versione>.json nello spazio di
    lavoro, con il percorso relativo nel messaggio."""
    nome = os.path.normpath(os.path.join(cartella, sotto, versione + ".json"))
    return json_claude(os.path.join(ws, nome), nome)


def esiti_giudizio(giudizio: dict) -> Optional[Dict[str, bool]]:
    """{id: rispettato} di structured_output.criteri, None se il giudizio
    non è strutturato."""
    uscita = giudizio.get("structured_output")
    criteri = uscita.get("criteri") if isinstance(uscita, dict) else None
    if not isinstance(criteri, list):
        return None
    esiti: Dict[str, bool] = {}
    for voce in criteri:
        if isinstance(voce, dict) and isinstance(voce.get("rispettato"), bool):
            esiti.setdefault(str(voce.get("id")), voce["rispettato"])
    return esiti


def misura(ws: str, cartella: str, famiglia: Optional[str], versione: str,
           problemi: List[str]) -> Optional[Tuple[int, str]]:
    """(controlli superati + affermazioni rispettate, risposta), o None con
    il problema in problemi: un file di misura che manca o è rovinato
    chiede di misurare di nuovo la versione."""
    base = os.path.join(ws, cartella)
    dove = " in %s" % famiglia if famiglia else ""
    di_nuovo = ": misurate di nuovo %s (./misura.sh%s %s)" % (
        versione, " " + famiglia if famiglia else "", versione)
    doc, problema = file_misura(ws, cartella, "risposte", versione)
    if doc is None:
        problemi.append(problema + di_nuovo)
        return None
    risposta = doc.get("result")
    if not isinstance(risposta, str) or not risposta.strip():
        problemi.append("la risposta di %s%s è vuota%s" % (
            versione, dove, di_nuovo))
        return None
    if not usage_numerico(doc):
        problemi.append("%s ha un usage non numerico%s" % (os.path.normpath(
            os.path.join(cartella, "risposte", versione + ".json")), di_nuovo))
        return None
    tot = TOTALE.search(testo_misura(os.path.join(base, "controlli",
                                                  versione + ".txt")))
    if tot is None:
        problemi.append("mancano i controlli di %s%s%s" % (
            versione, dove, di_nuovo))
        return None
    giudizio, problema = file_misura(ws, cartella, "giudizi", versione)
    esiti = None if giudizio is None else esiti_giudizio(giudizio)
    if esiti is None:
        problemi.append((problema or "il giudizio di %s%s non è strutturato"
                         % (versione, dove)) + di_nuovo)
        return None
    attesi = ids_rubrica(base)
    mancanti = [i for i in attesi if i not in esiti]
    if not attesi or mancanti:
        problemi.append("il giudizio di %s%s non valuta: %s" % (
            versione, dove, ", ".join(mancanti) or "la rubrica è vuota"))
        return None
    rispettate = sum(1 for i in attesi if esiti[i])
    return int(tot.group(1)) + rispettate, risposta


def righe_registro(ws: str) -> List[List[str]]:
    """Le righe della tabella di registro.md, campo per campo."""
    testo = leggi(os.path.join(ws, "registro.md")) or ""
    righe = []
    for riga in testo.splitlines():
        riga = riga.strip()
        if riga.startswith("|") and not re.match(r"^\|[\s|:-]+\|$", riga):
            righe.append([c.strip() for c in riga.strip("|").split("|")])
    return righe


def registro_ok(ws: str, famiglia: Optional[str], versione: str) -> bool:
    """La riga di una versione (e famiglia) c'è, ed è compilata."""
    for campi in righe_registro(ws):
        chiave = campi[:2] if famiglia else campi[:1]
        atteso = [famiglia, versione] if famiglia else [versione]
        if chiave == atteso:
            misure = campi[len(atteso):len(atteso) + 3]
            return len(misure) == 3 and all(
                c and VUOTO not in c and c != "..." for c in misure)
    return False


def controlla(ws: str, cartella: str, famiglia: Optional[str],
              problemi: List[str]) -> Optional[Tuple[int, int, int]]:
    """(misura di v0, dell'ultima, numero di cicli) di una cartella."""
    base = os.path.join(ws, cartella)
    nome = famiglia or "lo spazio di lavoro"
    versioni = misurate(base)
    da_misurare = [v for v in ("v0", "v1") if v not in versioni]
    if da_misurare:
        problemi.append("%s: misurate %s; servono almeno v0 e v1 "
                        "(./misura.sh%s %s)" % (
                            nome, ", ".join(versioni) or "nessuna versione",
                            " " + famiglia if famiglia else "",
                            ", poi ".join(da_misurare)))
        return None
    if leggi(os.path.join(base, "prompt", "v1.md")) == leggi(
            os.path.join(base, "prompt", "v0.md")):
        problemi.append("%s: prompt/v1.md è uguale a prompt/v0.md" % nome)
        return None
    ultima = versioni[-1]
    prima = misura(ws, cartella, famiglia, "v0", problemi)
    dopo = misura(ws, cartella, famiglia, ultima, problemi)
    if prima is None or dopo is None:
        return None
    for v in ("v0", "v1"):
        if not registro_ok(ws, famiglia, v):
            problemi.append("registro.md: compilate la riga di %s%s" % (
                v, " di " + famiglia if famiglia else ""))
    cicli = sum(1 for v in versioni if ordine(v) >= 1)
    if famiglia is None and TELEFONO.search(dopo[1]):
        problemi.append("la risposta di %s ripete il numero di telefono del "
                        "cliente" % ultima)
    print("%s: v0 %d, %s %d (controlli superati + affermazioni "
          "rispettate)" % (nome, prima[0], ultima, dopo[0]))
    return prima[0], dopo[0], cicli


def esamina(ws: str, problemi: List[str]) -> None:
    """Le regole di M2-E01 (prompt/v0.md nello spazio di lavoro) o di
    M2-E02 (le tre famiglie); i problemi in problemi."""
    if os.path.exists(os.path.join(ws, "prompt", "v0.md")):
        esito = controlla(ws, ".", None, problemi)
        if esito and esito[1] <= esito[0]:
            problemi.append("l'ultima versione non migliora la misura "
                            "di v0: un altro ciclo")
        return
    esiti = []
    for famiglia in FAMIGLIE:
        if not os.path.isdir(os.path.join(ws, famiglia)):
            problemi.append("manca la cartella %s" % famiglia)
            continue
        esito = controlla(ws, famiglia, famiglia, problemi)
        if esito:
            esiti.append((famiglia,) + esito)
    if len(esiti) == len(FAMIGLIE):
        peggio = [f for f, a, b, _ in esiti if b < a]
        meglio = [f for f, a, b, _ in esiti if b > a]
        due = [f for f, _, _, c in esiti if c >= 2]
        if peggio:
            problemi.append("peggiorano: %s" % ", ".join(peggio))
        if len(meglio) < 2:
            problemi.append("famiglie migliorate: %d su tre; ne servono "
                            "almeno due" % len(meglio))
        if len(due) < 2:
            problemi.append("famiglie con due cicli (v2): %d su tre; ne "
                            "servono almeno due" % len(due))


def main(argv: List[str]) -> int:
    if len(argv) != 1 or not os.path.isdir(argv[0]):
        sys.stderr.write("verifica: spazio di lavoro assente: %s\n"
                         % (argv[0] if argv else ""))
        return 2
    ws = argv[0]
    if not os.access(ws, os.R_OK | os.X_OK):
        sys.stderr.write("verifica: lo spazio di lavoro %s non si legge\n"
                         % ws)
        return 2
    problemi: List[str] = []
    try:
        esamina(ws, problemi)
    except Precondizione as exc:
        sys.stderr.write("verifica: %s\n" % exc)
        return 2
    except Exception as exc:  # l'ultima rete: un messaggio, mai un traceback
        sys.stderr.write("verifica: errore inatteso (%s: %s)\n" % (
            type(exc).__name__, " ".join(str(exc).split())))
        return 2
    if problemi:
        for p in problemi:
            print("Non ancora: %s." % p)
        return 1
    print("Fatto: le misure ci sono e mostrano il miglioramento.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
