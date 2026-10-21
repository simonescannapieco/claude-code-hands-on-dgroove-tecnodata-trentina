#!/usr/bin/env python3
"""I controlli di M1-E01, lo stesso prompt su tre modelli; li lancia
verifica.sh, accanto.

1. risposte/haiku.json, sonnet.json e opus.json: il JSON di
   `claude -p --output-format json`, senza errore, con una risposta, con
   modelUsage che nomina il modello del file, e con numeri veri in usage e
   in duration_ms.
2. confronto.md: la riga «Prompt usato», le tre righe della tabella e le
   righe «Per questo compito sceglierei» (uno dei tre modelli) e «Perché»
   compilate: una cella o una riga che contiene solo il segnaposto «…»
   non è compilata.
3. I numeri della tabella uguali a quelli dei JSON: token in entrata
   (input_tokens + cache_creation_input_tokens + cache_read_input_tokens),
   token in uscita (output_tokens), secondi (duration_ms / 1000, con uno di
   tolleranza). Chi li ha scritti, voi o Claude, va verificato.

Stampa i secondi e i token di ogni modello, poi il verdetto
sull'affermazione di Anthropic che riguarda i tempi, la latenza comparata
dei tre modelli (Haiku la più veloce, poi Sonnet, poi Opus): sempre non
distinguibile, perché una chiamata per modello non la misura, e la
latenza effettiva dipende anche dalla lunghezza dell'output e dall'effort.
Su un esito riuscito l'ultima riga è la frase FATTO.

Scritto per il python3 dei partecipanti, dalla 3.8 in su.

Uso:    python3 -B -I verifica.py <spazio di lavoro>
Uscita: 0 = tutto compilato e coerente · 1 = qualcosa manca o non torna
        2 = un file che c'è ma non si legge (permessi, codifica), un
            argomento sbagliato, o un errore che il controllo non prevede
            (una riga, mai un traceback)
"""
from __future__ import annotations

import json
import math
import os
import re
import sys
from typing import Dict, List, Optional

MODELLI = ("haiku", "sonnet", "opus")
VUOTO = "…"
COLONNE = 5
CAMPI_ENTRATA = ("input_tokens", "cache_creation_input_tokens",
                 "cache_read_input_tokens")
SECONDI = re.compile(r"^\s*([0-9]+(?:[.,][0-9]+)?)\s*(?:s|sec|secondi)?\s*$",
                     re.IGNORECASE)
# Un numero di token: cifre ASCII, al più 12. isdigit() accetterebbe anche
# le cifre in apice («²»), che int() rifiuta.
TOKEN_CELLA = re.compile(r"[0-9]{1,12}")
# Un numero del JSON (token, millisecondi) sta sotto 10**12, come le celle.
MASSIMO = 10 ** 12
LATENZA = ("Latenza comparata secondo Anthropic, Haiku la più veloce, poi "
           "Sonnet, poi Opus: non distinguibile (una chiamata per modello "
           "non la misura)")
FATTO = ("Fatto: ogni affermazione è stata messa alla prova; gli esiti sono "
         "qui sopra.")


class Illeggibile(Exception):
    """Un file che c'è ma non si legge: una precondizione, uscita 2."""


def leggi_testo(path: str, nome: str) -> str:
    """Il contenuto UTF-8 di un file, o Illeggibile; nome per i messaggi."""
    try:
        with open(path, encoding="utf-8") as fh:
            return fh.read()
    except UnicodeDecodeError:
        raise Illeggibile("%s non è un testo UTF-8" % nome) from None
    except OSError as exc:
        raise Illeggibile("%s non si legge (%s)" % (nome, exc.strerror)) \
            from None


def intero_json(valore: object) -> Optional[int]:
    """Un numero del JSON come intero non negativo sotto MASSIMO; None se
    non lo è. isfinite solo sui float: un intero enorme non si converte."""
    if isinstance(valore, bool) or not isinstance(valore, (int, float)):
        return None
    if isinstance(valore, float) and not math.isfinite(valore):
        return None
    if valore < 0 or valore >= MASSIMO or int(valore) != valore:
        return None
    return int(valore)


def leggi_json(ws: str, modello: str,
               problemi: List[str]) -> Optional[Dict[str, float]]:
    """I numeri di risposte/<modello>.json, o None con un problema."""
    nome = "risposte/%s.json" % modello
    path = os.path.join(ws, "risposte", modello + ".json")
    if not os.path.isfile(path):
        problemi.append("manca %s: rifate la sua chiamata del passo 3" % nome)
        return None
    try:
        dati = json.loads(leggi_testo(path, nome))
    except (ValueError, RecursionError) as exc:
        # RecursionError: un JSON annidato oltre il limite di Python.
        problemi.append("%s non è un JSON valido (%s): rifate la sua "
                        "chiamata del passo 3" % (nome, exc))
        return None
    if not isinstance(dati, dict):
        problemi.append("%s non è il JSON di claude -p" % nome)
        return None
    if dati.get("is_error") or not str(dati.get("result") or "").strip():
        problemi.append("%s: errore o risposta vuota" % nome)
        return None
    usati = dati.get("modelUsage")
    if not isinstance(usati, dict) or not usati:
        problemi.append("%s: manca modelUsage, il modello che ha risposto"
                        % nome)
        return None
    if not any(modello in str(m) for m in usati):
        problemi.append("%s viene da %s, non da %s"
                        % (nome, ", ".join(map(str, usati)), modello))
    uso = dati.get("usage")
    if not isinstance(uso, dict):
        problemi.append("%s: manca usage, i token" % nome)
        return None
    numeri: Dict[str, int] = {}
    for campo in CAMPI_ENTRATA + ("output_tokens",):
        grezzo = uso.get(campo)
        valore = 0 if grezzo is None else intero_json(grezzo)
        if valore is None:
            problemi.append("%s: usage.%s non è un numero (%r)"
                            % (nome, campo, grezzo))
            return None
        numeri[campo] = valore
    durata = intero_json(dati.get("duration_ms"))
    if durata is None:
        problemi.append("%s: duration_ms manca o non è un numero" % nome)
        return None
    return {"entrata": sum(numeri[c] for c in CAMPI_ENTRATA),
            "uscita": numeri["output_tokens"], "secondi": durata / 1000}


def intero(cella: str) -> Optional[int]:
    """Un numero di token, anche scritto con i separatori delle migliaia."""
    pulita = re.sub(r"[\s.,'’]", "", cella)
    return int(pulita) if TOKEN_CELLA.fullmatch(pulita) else None


def decimale(cella: str) -> Optional[float]:
    """Un numero di secondi: 5,6 o 5.6, anche seguito da s, sec, secondi."""
    trovato = SECONDI.match(cella)
    return float(trovato.group(1).replace(",", ".")) if trovato else None


def riga_che_inizia(testo: str, prefisso: str) -> Optional[str]:
    """Il resto della prima riga che comincia con il prefisso."""
    for riga in testo.splitlines():
        if riga.strip().startswith(prefisso):
            return riga.strip()[len(prefisso):].strip()
    return None


def righe_tabella(testo: str, modello: str) -> List[List[str]]:
    """Le righe della tabella la cui prima cella comincia con il modello."""
    trovate = []
    for riga in testo.splitlines():
        if not riga.strip().startswith("|"):
            continue
        celle = [c.strip() for c in riga.strip().strip("|").split("|")]
        parole = celle[0].lower().split()
        if parole and parole[0] == modello:
            trovate.append(celle)
    return trovate


def controlla_confronto(testo: str, numeri: Dict[str, Optional[dict]],
                        problemi: List[str]) -> None:
    """Le righe da compilare e la tabella di confronto.md."""
    for prefisso in ("Prompt usato:", "Per questo compito sceglierei:",
                     "Perché:"):
        valore = riga_che_inizia(testo, prefisso)
        if valore is None:
            problemi.append("confronto.md: manca la riga «%s»" % prefisso)
        elif valore in ("", VUOTO):
            problemi.append("confronto.md: compilate la riga «%s» (c'è "
                            "ancora il segnaposto «…»)" % prefisso)
    scelta = (riga_che_inizia(testo, "Per questo compito sceglierei:")
              or "").lower()
    if scelta not in ("", VUOTO) and not any(m in scelta for m in MODELLI):
        problemi.append("confronto.md: scegliete uno dei tre modelli")
    for modello in MODELLI:
        righe = righe_tabella(testo, modello)
        if not righe:
            problemi.append("confronto.md: manca la riga di %s nella tabella"
                            % modello)
            continue
        celle = righe[-1]
        if len(celle) != COLONNE:
            problemi.append("confronto.md: la riga di %s ha %d colonne invece "
                            "di %d (un «|» dentro una cella?)"
                            % (modello, len(celle), COLONNE))
            continue
        vuote = [i for i, c in enumerate(celle[1:], 2) if c in ("", VUOTO)]
        if vuote:
            problemi.append("confronto.md: nella riga di %s mancano le "
                            "colonne %s" % (modello,
                                            ", ".join(map(str, vuote))))
            continue
        attesi = numeri.get(modello)
        if attesi is None:
            continue
        sec = decimale(celle[1])
        ent, usc = intero(celle[2]), intero(celle[3])
        if ent != attesi["entrata"]:
            problemi.append("%s: token in entrata «%s», nel JSON %d"
                            % (modello, celle[2], attesi["entrata"]))
        if usc != attesi["uscita"]:
            problemi.append("%s: token in uscita «%s», nel JSON %d"
                            % (modello, celle[3], attesi["uscita"]))
        if sec is None:
            problemi.append("%s: secondi «%s»: scrivete un numero, per "
                            "esempio 5,6" % (modello, celle[1]))
        elif abs(sec - attesi["secondi"]) > 1:
            problemi.append("%s: secondi %s, nel JSON %.1f"
                            % (modello, celle[1], attesi["secondi"]))


def main(argv: List[str]) -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(errors="replace")
    if len(argv) != 1 or not os.path.isdir(argv[0]):
        sys.stderr.write("verifica.py: serve lo spazio di lavoro\n")
        return 2
    ws = argv[0]
    problemi: List[str] = []
    try:
        numeri = {m: leggi_json(ws, m, problemi) for m in MODELLI}
        path = os.path.join(ws, "confronto.md")
        if os.path.isfile(path):
            controlla_confronto(leggi_testo(path, "confronto.md"), numeri,
                                problemi)
        else:
            problemi.append("manca confronto.md")
    except Illeggibile as exc:
        sys.stderr.write("verifica: %s\n" % exc)
        return 2
    for modello in MODELLI:
        n = numeri.get(modello)
        if n:
            print("%-6s %5.1f s  %6d token in entrata  %5d in uscita"
                  % (modello, n["secondi"], n["entrata"], n["uscita"]))
    print(LATENZA)
    if problemi:
        print("\n".join("Da sistemare: " + p for p in problemi))
        return 1
    print("Confronto compilato e coerente con le tre risposte.")
    print(FATTO)
    return 0


def principale(argv: List[str]) -> int:
    """main, con un errore che il controllo non prevede detto in una riga
    e l'uscita 2: mai un traceback, che uscirebbe 1 come un «non ancora»."""
    try:
        return main(argv)
    except Exception as exc:  # ogni errore che il controllo non prevede
        sys.stderr.write("verifica.py: errore inatteso del controllo (%s: "
                         "%s): segnalatelo al docente\n"
                         % (type(exc).__name__, str(exc)[:200]))
        return 2


if __name__ == "__main__":
    sys.exit(principale(sys.argv[1:]))
