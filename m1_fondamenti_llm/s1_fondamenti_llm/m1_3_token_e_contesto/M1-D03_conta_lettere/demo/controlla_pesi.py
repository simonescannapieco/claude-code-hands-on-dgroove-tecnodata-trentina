"""controlla_pesi.py -- quanti token pesano i testi di M1-D03, e le tre
affermazioni che la demo mette alla prova.

Legge, nello spazio di lavoro (l'argomento, oppure la cartella corrente):
  - parola.txt, compitata.txt e strawberry.txt, i testi che le chiamate
    mandano, e ne conta le lettere: solo le lettere, né spazi né altro;
  - conteggi.tsv, scritto dal passo 3 del README o da _docente/live.sh:
    l'intestazione «modello<TAB>testo<TAB>token_entrata», poi una riga per
    chiamata; il testo è parola, compitata o strawberry, da solo o con
    «-doppia» (ripetuto due volte, separato da uno spazio).
Il peso di un testo è il conteggio del doppio meno quello del singolo: ciò
che il modello riceve oltre al testo, uguale nelle due chiamate, si
annulla. Nel doppio la seconda copia arriva dopo uno spazio, quindi il
peso è quello del testo preceduto da uno spazio.

Stampa le lettere, i conteggi e i pesi, e come dato, senza verdetto, i
token per lettera della parola compitata; poi una riga per affermazione,
«confermata», «non confermata in questa esecuzione» oppure «non
distinguibile (perché)»:
  1. ogni parola (parola.txt, strawberry.txt) pesa meno token delle sue
     lettere;
  2. la parola compitata pesa più token della parola intera (parola.txt):
     le stesse lettere, i due testi differiscono solo negli spazi;
  3. gli stessi pesi su ogni modello: si mette alla prova con almeno due
     modelli completi; con uno solo è «non distinguibile» e l'uscita non
     cambia.
Sono garanzie: una sola «non confermata» fa uscire 1.

Scritto per il python3 dei partecipanti, dalla 3.8 in su.

Uso:    python3 controlla_pesi.py [spazio di lavoro]
Uscita: 0 = ogni modello presente ha i sei conteggi e ogni affermazione
            messa alla prova è confermata
        1 = conteggi.tsv assente, senza intestazione, incompleto o con una
            riga che non torna, oppure un'affermazione non confermata
        2 = spazio di lavoro assente, un testo mancante o senza lettere, un
            file che c'è ma non si legge (permessi, codifica), argomenti di
            troppo, o un errore che il controllo non prevede (una riga,
            mai un traceback)
"""
from __future__ import annotations

import os
import re
import sys
from typing import Dict, List, Set, Tuple

FILE = "conteggi.tsv"
INTESTAZIONE = "modello\ttesto\ttoken_entrata"
MODELLI = ("haiku", "sonnet", "opus")
TESTI = ("parola", "compitata", "strawberry")
PAROLE = ("parola", "strawberry")
INTERA = "parola"
COMPITATA = "compitata"
DOPPIA = "-doppia"
ETICHETTE = tuple(t + d for t in TESTI for d in ("", DOPPIA))
# Un conteggio: cifre ASCII, al più 12 (un numero più lungo non è un
# conteggio di token, e i python3 più recenti rifiutano di convertirlo).
NUMERO = re.compile(r"[0-9]{1,12}")
MOSTRA = 34
RIPARTI = "tools/reset_esercizio.sh M1-D03 riparte da capo"
AFFERMAZIONI = (
    "Ogni parola pesa meno token delle sue lettere",
    "La parola compitata pesa più token della parola intera",
    "Gli stessi pesi su ogni modello",
)
GARANZIE = (
    "secondo la documentazione il testo arriva al modello a pezzi, non un "
    "carattere per volta: in questa esecuzione no",
    "il glossario descrive token più grandi, usati quando possibile, e token "
    "più piccoli per le parole non comuni o mai viste prima: in questa "
    "esecuzione no",
    "secondo la documentazione i modelli dalla 4.7 in poi usano lo stesso "
    "tokenizer: in questa esecuzione no",
)
PER_LETTERA = ("Token per lettera nella parola compitata (un dato, senza "
               "verdetto):")

Testi = Dict[str, Tuple[str, int]]
Conteggi = Dict[Tuple[str, str], int]
Pesi = Dict[str, Dict[str, int]]


class Precondizione(Exception):
    """Un testo che manca o un file che non si legge: l'uscita 2."""


def leggi(path: str, nome: str) -> str:
    """Il contenuto UTF-8 di un file, senza BOM; Precondizione se non va."""
    try:
        with open(path, encoding="utf-8-sig") as fh:
            return fh.read()
    except UnicodeDecodeError:
        raise Precondizione("%s non è un testo UTF-8" % nome) from None
    except OSError as exc:
        raise Precondizione("%s non si legge (%s)"
                            % (nome, exc.strerror or exc)) from None


def corto(testo: str) -> str:
    """Il testo fra «», accorciato a MOSTRA caratteri."""
    if len(testo) > MOSTRA:
        testo = testo[:MOSTRA - 1] + "…"
    return "«%s»" % testo


def leggi_testi(ws: str) -> Testi:
    """Per ogni testo, (il testo su una riga, le sue lettere)."""
    testi: Testi = {}
    for nome in TESTI:
        file = nome + ".txt"
        path = os.path.join(ws, file)
        if not os.path.lexists(path):
            raise Precondizione("manca %s, uno dei testi che le chiamate "
                                "mandano: %s" % (file, RIPARTI))
        testo = " ".join(leggi(path, file).split())
        lettere = sum(1 for c in testo if c.isalpha())
        if lettere == 0:
            raise Precondizione("%s non contiene lettere: %s"
                                % (file, RIPARTI))
        testi[nome] = (testo, lettere)
    return testi


def leggi_conteggi(righe: List[str], problemi: List[str]) -> Conteggi:
    """I conteggi delle righe che seguono l'intestazione. Una riga che non
    torna, e un conteggio ripetuto con un altro valore, vanno in problemi
    e non contano."""
    conteggi: Conteggi = {}
    contesi: Set[Tuple[str, str]] = set()
    for numero, riga in enumerate(righe, 2):
        if not riga.strip():
            continue
        campi = [c.strip() for c in riga.split("\t")]
        if len(campi) != 3:
            problemi.append("riga %d: attesi tre campi separati da "
                            "tabulazioni, trovati %d" % (numero, len(campi)))
            continue
        modello, etichetta, valore = campi
        if modello not in MODELLI:
            problemi.append("riga %d: modello «%s» non previsto (%s)"
                            % (numero, modello, ", ".join(MODELLI)))
        elif etichetta not in ETICHETTE:
            problemi.append("riga %d: testo «%s» non previsto (%s, da soli "
                            "o con «%s»)" % (numero, etichetta,
                                             ", ".join(TESTI), DOPPIA))
        elif not NUMERO.fullmatch(valore):
            problemi.append("riga %d: %s, %s: conteggio vuoto o non "
                            "numerico (%s): rifate quella chiamata"
                            % (numero, modello, etichetta, corto(valore)))
        else:
            chiave, n = (modello, etichetta), int(valore)
            if chiave in conteggi and conteggi[chiave] != n:
                if chiave not in contesi:
                    problemi.append("%s, %s: due conteggi diversi (%d e %d): "
                                    "rifate le chiamate di %s"
                                    % (modello, etichetta, conteggi[chiave],
                                       n, modello))
                contesi.add(chiave)
            else:
                conteggi[chiave] = n
    for chiave in contesi:
        del conteggi[chiave]
    return conteggi


def pesi_completi(conteggi: Conteggi, problemi: List[str]) -> Pesi:
    """I pesi di ogni modello presente con i sei conteggi, il doppio meno il
    singolo. Un modello incompleto, o con un peso che non è positivo, va in
    problemi e non conta."""
    pesi: Pesi = {}
    for modello in MODELLI:
        mancanti = [e for e in ETICHETTE if (modello, e) not in conteggi]
        if len(mancanti) == len(ETICHETTE):
            continue
        if mancanti:
            problemi.append("%s: mancano i conteggi di %s"
                            % (modello, ", ".join(mancanti)))
            continue
        suoi = {t: conteggi[(modello, t + DOPPIA)] - conteggi[(modello, t)]
                for t in TESTI}
        storti = [t for t in TESTI if suoi[t] <= 0]
        for t in storti:
            problemi.append("%s, %s: il doppio (%d) non pesa più del singolo "
                            "(%d): rifate le due chiamate, dallo spazio di "
                            "lavoro" % (modello, t,
                                        conteggi[(modello, t + DOPPIA)],
                                        conteggi[(modello, t)]))
        if not storti:
            pesi[modello] = suoi
    return pesi


def stampa_numeri(testi: Testi, conteggi: Conteggi) -> None:
    """Le lettere dei testi, poi i conteggi letti e i pesi."""
    print("I testi e le loro lettere (contate qui: solo le lettere):")
    for nome in TESTI:
        testo, lettere = testi[nome]
        print("  %-11s %-*s %3d" % (nome, MOSTRA + 2, corto(testo), lettere))
    print()
    print("I token in entrata di %s; il peso è il doppio meno il singolo:"
          % FILE)
    print("  %-7s %-11s %8s %7s %5s %8s"
          % ("modello", "testo", "singolo", "doppio", "peso", "lettere"))
    for modello in MODELLI:
        if not any((modello, e) in conteggi for e in ETICHETTE):
            continue
        for nome in TESTI:
            singolo = conteggi.get((modello, nome))
            doppio = conteggi.get((modello, nome + DOPPIA))
            peso = "—"
            if singolo is not None and doppio is not None:
                peso = str(doppio - singolo)
            print("  %-7s %-11s %8s %7s %5s %8d"
                  % (modello, nome, "—" if singolo is None else singolo,
                     "—" if doppio is None else doppio, peso,
                     testi[nome][1]))


def stampa_per_lettera(testi: Testi, pesi: Pesi) -> None:
    """I token per lettera della parola compitata, per ogni modello
    completo: un dato, senza verdetto, perché nessuna delle tre
    affermazioni ne fissa il numero."""
    if not pesi:
        return
    print()
    print(PER_LETTERA)
    for modello in pesi:
        print("  %-7s %d token per %d lettere"
              % (modello, pesi[modello][COMPITATA], testi[COMPITATA][1]))


def verdetto(indice: int, casi: List[str]) -> Tuple[List[str], bool]:
    """Le righe di un'affermazione messa alla prova: confermata se nessun
    caso la smentisce, altrimenti i casi e la garanzia; e se è confermata."""
    if not casi:
        return ["%s: confermata" % AFFERMAZIONI[indice]], True
    righe = ["%s: non confermata in questa esecuzione"
             % AFFERMAZIONI[indice]]
    righe += ["  " + c for c in casi]
    righe.append("  " + GARANZIE[indice])
    return righe, False


def verdetti(testi: Testi, pesi: Pesi) -> Tuple[List[str], bool]:
    """Le righe delle tre affermazioni, e se ogni garanzia messa alla prova
    è confermata; la terza si mette alla prova con almeno due modelli."""
    if not pesi:
        return (["%s: non distinguibile (nessun modello con i sei conteggi)"
                 % a for a in AFFERMAZIONI], False)
    casi = ["%s, %s: %d token per %d lettere"
            % (m, corto(testi[t][0]), pesi[m][t], testi[t][1])
            for m in pesi for t in PAROLE if pesi[m][t] >= testi[t][1]]
    righe, prima = verdetto(0, casi)
    casi = ["%s, %s: %d token, %s: %d"
            % (m, corto(testi[COMPITATA][0]), pesi[m][COMPITATA],
               corto(testi[INTERA][0]), pesi[m][INTERA])
            for m in pesi if pesi[m][COMPITATA] <= pesi[m][INTERA]]
    altre, seconda = verdetto(1, casi)
    righe += altre
    if len(pesi) < 2:
        righe.append("%s: non distinguibile (un solo modello con i sei "
                     "conteggi: ne servono almeno due)" % AFFERMAZIONI[2])
        return righe, prima and seconda
    casi = []
    if len({tuple(p[t] for t in TESTI) for p in pesi.values()}) > 1:
        casi = ["%s: %s" % (m, ", ".join("%s %d" % (t, pesi[m][t])
                                         for t in TESTI)) for m in pesi]
    altre, terza = verdetto(2, casi)
    return righe + altre, prima and seconda and terza


def main(argv: List[str]) -> int:
    for flusso in (sys.stdout, sys.stderr):
        riconfigura = getattr(flusso, "reconfigure", None)
        if riconfigura is not None:
            riconfigura(errors="replace")
    if len(argv) > 1:
        sys.stderr.write(__doc__)
        return 2
    ws = argv[0] if argv else "."
    if not os.path.isdir(ws):
        sys.stderr.write("controlla_pesi.py: spazio di lavoro assente: %s\n"
                         % ws)
        return 2
    path = os.path.join(ws, FILE)
    try:
        testi = leggi_testi(ws)
        if not os.path.lexists(path):
            print("Manca %s: eseguite i passi del README." % FILE)
            return 1
        righe = leggi(path, FILE).split("\n")
    except Precondizione as exc:
        sys.stderr.write("controlla_pesi.py: %s\n" % exc)
        return 2
    if righe[0] != INTESTAZIONE:
        print("%s: la prima riga deve essere l'intestazione "
              "«modello<TAB>testo<TAB>token_entrata»." % FILE)
        return 1
    problemi: List[str] = []
    conteggi = leggi_conteggi(righe[1:], problemi)
    pesi = pesi_completi(conteggi, problemi)
    if not conteggi and not problemi:
        problemi.append("%s non ha ancora conteggi: eseguite il passo 3 del "
                        "README" % FILE)
    stampa_numeri(testi, conteggi)
    stampa_per_lettera(testi, pesi)
    righe_verdetti, confermate = verdetti(testi, pesi)
    print()
    for problema in problemi:
        print("Da sistemare: " + problema)
    if problemi:
        print()
    print("\n".join(righe_verdetti))
    return 0 if confermate and not problemi else 1


def principale(argv: List[str]) -> int:
    """main, con un errore che il controllo non prevede detto in una riga
    e l'uscita 2: mai un traceback, che uscirebbe 1 come un «non ancora»."""
    try:
        return main(argv)
    except Exception as exc:  # ogni errore che il controllo non prevede
        sys.stderr.write("controlla_pesi.py: errore inatteso del controllo "
                         "(%s: %s): segnalatelo al docente\n"
                         % (type(exc).__name__, str(exc)[:200]))
        return 2


if __name__ == "__main__":
    sys.exit(principale(sys.argv[1:]))
