#!/usr/bin/env python3
"""I controlli di M1-D02, stessa frase, due lingue; li lancia verifica.sh,
accanto.

Legge conteggi.tsv dello spazio di lavoro: l'intestazione
«modello<TAB>testo<TAB>token_entrata», poi una riga per chiamata, con il
testo it, it-doppia, en o en-doppia (se un testo compare due volte vale
l'ultima riga; un conteggio che non è un numero di al più 12 cifre non
conta). Per ogni modello con i quattro conteggi il peso di una frase è la
crescita dal testo singolo al doppio. I caratteri delle due frasi li conta
in frase_it.txt e frase_en.txt dello spazio di lavoro, senza gli a capo
finali, come li manda il passo 3 del README.

Stampa, per ogni modello completo, i due pesi e i caratteri per token, poi
un verdetto per modello su ciascuna delle due affermazioni di Anthropic che
la demo mette alla prova:
1. «Il numero di token prodotti dallo stesso testo dipende […] dalla
   lingua» (i prezzi): confermata se le due frasi pesano un numero di
   token diverso;
2. «il numero di caratteri rappresentato da un token dipende […] dalla
   lingua» (il glossario): confermata se i caratteri per token delle due
   frasi sono diversi; non distinguibile se manca una delle due frasi.
Con valori uguali il verdetto è non dimostrata in questa esecuzione: un
«dipende» si mostra con una differenza, una frase sola non lo smentisce.
Con un peso che non è positivo i due verdetti sono non distinguibili.

Le due affermazioni dicono «dipende», senza un verso: l'uscita la decide
la completezza della misura, mai il verso della differenza. Il confronto
con la registrazione del corso (27 token contro 17, su Haiku, Sonnet e
Opus) si stampa come dato: «in questa esecuzione sì» se su ogni modello
con i due pesi positivi la frase italiana pesa più di quella inglese,
altrimenti «no».

Scritto per il python3 dei partecipanti, dalla 3.8 in su.

Uso:    python3 -B -I verifica.py <spazio di lavoro>
Uscita: 0 = almeno un modello con i quattro conteggi, e ogni modello
            completo con i due pesi positivi
        1 = conteggi.tsv assente, senza l'intestazione, senza un modello
            completo, oppure un peso che non è positivo (una misura da
            rifare)
        2 = conteggi.tsv o una delle due frasi c'è ma non si legge
            (permessi, codifica), un argomento sbagliato, o un errore che
            il controllo non prevede (una riga, mai un traceback)
"""
from __future__ import annotations

import os
import re
import sys
from typing import Dict, List, Optional, Tuple

FILE = "conteggi.tsv"
INTESTAZIONE = "modello\ttesto\ttoken_entrata"
TESTI = ("it", "it-doppia", "en", "en-doppia")
FRASI = (("it", "frase_it.txt"), ("en", "frase_en.txt"))
BOM = chr(0xFEFF)
# Un conteggio: cifre ASCII, al più 12 (un numero più lungo non è un
# conteggio di token, e i python3 più recenti rifiutano di convertirlo).
NUMERO = re.compile(r"[0-9]{1,12}")
TOKEN = "Il numero di token dello stesso testo dipende dalla lingua (%s)"
CARATTERI = "Quanti caratteri vale un token dipende dalla lingua (%s)"
NON_DIMOSTRATA = "non dimostrata in questa esecuzione"
CONFRONTO = ("Nella registrazione del corso la frase italiana pesa più di "
             "quella inglese (27 contro 17): in questa esecuzione %s")
FATTO = ("Fatto: ogni affermazione è stata messa alla prova; gli esiti sono "
         "qui sopra.")


class Illeggibile(Exception):
    """Un file che c'è ma non si legge: una precondizione, uscita 2."""


def leggi_testo(path: str, nome: str, a_capo: Optional[str] = None) -> str:
    """Il contenuto UTF-8 di un file, o Illeggibile; nome per i messaggi.
    a_capo è il newline di open: None legge CRLF come LF, "" lascia il
    testo com'è."""
    try:
        with open(path, encoding="utf-8", newline=a_capo) as fh:
            return fh.read()
    except UnicodeDecodeError:
        raise Illeggibile("%s non è un testo UTF-8" % nome) from None
    except OSError as exc:
        raise Illeggibile("%s non si legge (%s)" % (nome, exc.strerror)) \
            from None


def leggi_conteggi(testo: str) -> Optional[Dict[str, Dict[str, int]]]:
    """I conteggi per modello e testo, nell'ordine in cui compaiono i
    modelli; None se la prima riga non è l'intestazione. Un BOM in testa
    si ignora; gli a capo CRLF arrivano già come LF (open in modo testo)."""
    righe = testo.lstrip(BOM).split("\n")
    if righe[0] != INTESTAZIONE:
        return None
    conteggi: Dict[str, Dict[str, int]] = {}
    for riga in righe[1:]:
        campi = [c.strip() for c in riga.split("\t")]
        if len(campi) < 3 or not campi[0] or campi[1] not in TESTI:
            continue
        per_testo = conteggi.setdefault(campi[0], {})
        if NUMERO.fullmatch(campi[2]):
            per_testo[campi[1]] = int(campi[2])
    return conteggi


def leggi_frasi(ws: str) -> Tuple[Dict[str, int], List[str]]:
    """I caratteri di ogni frase presente e i file che mancano. Come
    $(cat …) nel passo 3: il testo così com'è, senza gli a capo finali."""
    lunghezze: Dict[str, int] = {}
    mancano: List[str] = []
    for lingua, nome in FRASI:
        path = os.path.join(ws, nome)
        if not os.path.isfile(path):
            mancano.append(nome)
            continue
        lunghezze[lingua] = len(leggi_testo(path, nome, "").rstrip("\n"))
    return lunghezze, mancano


def decimale(valore: float) -> str:
    """Un numero con una cifra decimale e la virgola."""
    return ("%.1f" % valore).replace(".", ",")


def riga_pesi(modello: str, it: int, en: int) -> str:
    """I due pesi e, se sono positivi, quanto l'italiano pesa più o meno
    dell'inglese: un dato, in un verso o nell'altro."""
    if it <= 0 or en <= 0:
        return "%s: italiano %d token, inglese %d" % (modello, it, en)
    segno = "+" if it > en else "-" if it < en else ""
    return ("%s: italiano %d token, inglese %d (%s%d %%)"
            % (modello, it, en, segno, int(abs(it - en) * 100 / en + 0.5)))


def misura(modello: str, it: int, en: int, lunghezze: Dict[str, int],
           mancano: List[str]) -> Tuple[List[str], str, str]:
    """Le righe dei numeri di un modello completo e i due verdetti."""
    numeri = [riga_pesi(modello, it, en)]
    if it <= 0 or en <= 0:
        perche = "non distinguibile (un peso non è positivo)"
        numeri.append("%s: caratteri per token non calcolati, un peso non è "
                      "positivo" % modello)
        return numeri, perche, perche
    token = "confermata" if it != en else NON_DIMOSTRATA
    if mancano:
        assenti = "%s %s" % ("mancano" if len(mancano) > 1 else "manca",
                             " e ".join(mancano))
        numeri.append("%s: caratteri per token non calcolati, %s"
                      % (modello, assenti))
        return numeri, token, "non distinguibile (%s)" % assenti
    car_it, car_en = lunghezze["it"], lunghezze["en"]
    numeri.append("%s: caratteri per token, italiano %s (%d/%d), inglese %s "
                  "(%d/%d)" % (modello, decimale(car_it / it), car_it, it,
                               decimale(car_en / en), car_en, en))
    # Confronto esatto, senza arrotondare: car_it/it e car_en/en.
    diversi = car_it * en != car_en * it
    return numeri, token, "confermata" if diversi else NON_DIMOSTRATA


def esamina(conteggi: Dict[str, Dict[str, int]], lunghezze: Dict[str, int],
            mancano: List[str]) -> Tuple[List[str], List[str], List[bool]]:
    """Stampa i numeri di ogni modello. Restituisce le righe dei verdetti;
    i modelli completi con un peso che non è positivo, da rifare; per gli
    altri modelli completi, se l'italiano pesa più dell'inglese."""
    token: List[str] = []
    car: List[str] = []
    da_rifare: List[str] = []
    piu_pesante: List[bool] = []
    for modello, per_testo in conteggi.items():
        assenti = [t for t in TESTI if t not in per_testo]
        if assenti:
            print("%s: mancano i conteggi di %s: il modello non conta"
                  % (modello, ", ".join(assenti)))
            continue
        it = per_testo["it-doppia"] - per_testo["it"]
        en = per_testo["en-doppia"] - per_testo["en"]
        if it > 0 and en > 0:
            piu_pesante.append(it > en)
        else:
            da_rifare.append(modello)
        numeri, v_token, v_car = misura(modello, it, en, lunghezze, mancano)
        for riga in numeri:
            print(riga)
        token.append("%s: %s" % (TOKEN % modello, v_token))
        car.append("%s: %s" % (CARATTERI % modello, v_car))
    return token + car, da_rifare, piu_pesante


def main(argv: List[str]) -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(errors="replace")
    if len(argv) != 1 or not os.path.isdir(argv[0]):
        sys.stderr.write("verifica.py: serve lo spazio di lavoro\n")
        return 2
    ws = argv[0]
    path = os.path.join(ws, FILE)
    if not os.path.isfile(path):
        print("Manca %s: eseguite i passi del README." % FILE)
        return 1
    try:
        conteggi = leggi_conteggi(leggi_testo(path, FILE))
        lunghezze, mancano = leggi_frasi(ws)
    except Illeggibile as exc:
        sys.stderr.write("verifica: %s\n" % exc)
        return 2
    if conteggi is None:
        print("%s: la prima riga deve essere l'intestazione "
              "«modello<TAB>testo<TAB>token_entrata»." % FILE)
        return 1
    verdetti, da_rifare, piu_pesante = esamina(conteggi, lunghezze, mancano)
    for riga in verdetti:
        print(riga)
    if piu_pesante:
        print(CONFRONTO % ("sì" if all(piu_pesante) else "no"))
    if not da_rifare and not piu_pesante:
        print("Nessun modello con i quattro testi it, it-doppia, en, "
              "en-doppia.")
        return 1
    for modello in da_rifare:
        print("Da rifare: %s: un peso non è positivo, il doppio non pesa più "
              "del singolo: rifate le sue quattro chiamate, dallo spazio di "
              "lavoro." % modello)
    if da_rifare:
        return 1
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
