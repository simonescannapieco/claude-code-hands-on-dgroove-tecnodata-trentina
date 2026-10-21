"""misura_orrori.py -- che cosa c'è nella risposta di una prova di M2-D06.

Legge su STDIN il JSON di `claude -p --output-format json` di una prova e
stampa su STDOUT la sua riga di orrori.tsv: questi campi, nell'ordine,
separati da una tabulazione.
  prova          il nome della prova: il file del prompt, senza .md
  token_entrata  i token in entrata: input_tokens più
                 cache_creation_input_tokens e cache_read_input_tokens
  token_uscita   i token in uscita: output_tokens
  parole         le parole della risposta: i pezzi fra spazi o a capo
  righe          le righe non vuote
  titoli         le righe di titolo Markdown: da uno a sei # in testa
                 (dopo al più tre spazi), poi uno spazio
  elenchi        le voci di elenco: una riga che comincia con -, *, + o •,
                 o con un numero di una o due cifre seguito da . o ), e
                 poi uno spazio
  tabelle        le righe di tabella: cominciano con | e ne hanno un altro
  grassetti      i tratti in grassetto, fra ** e ** sulla stessa riga
  etichette      solo per orrore-1-vaga e cura-1-vaga: quante delle prime
                 tre righe non vuote cominciano con la loro etichetta,
                 nell'ordine «Problema:», «Quando:», «Richieste:» (anche in
                 grassetto o in corsivo); per le altre prove —
  importi        gli importi in euro: un numero seguito da €, «euro» o
                 «EUR», anche con una grandezza in mezzo («5 mila euro»,
                 «12 k€», «1,5 milioni di euro», «3 mln €»), oppure € o
                 «EUR» seguiti da un numero (maiuscole o minuscole)
  non_indicato   solo per orrore-3-stima e cura-3-stima: sì se la risposta
                 scrive «non indicato» (o «non indicata», «non indicati»,
                 «non indicate»), altrimenti no; per le altre prove —
  firma          solo per orrore-4-memoria e cura-4-memoria: sì se la
                 risposta contiene la firma concordata «L'assistenza
                 clienti di CiaspoLink» (maiuscole o minuscole, apostrofo
                 dritto o tipografico, anche in grassetto), altrimenti no;
                 per le altre prove —
  risposta       la risposta, su una riga

Prima di tutto controlla gli ingressi, accanto a questo file: messaggio.md
e i due prompt della stima (orrore-3-stima.md, cura-3-stima.md) non
devono contenere importi in euro. Così ogni importo di una risposta è
inventato: nessuno viene da ciò che la chiamata ha ricevuto.

Uso:    python3 misura_orrori.py --intestazione    (la prima riga di
                                                   orrori.tsv)
        python3 misura_orrori.py <prova> < <il JSON della prova>
        <prova>: orrore-1-vaga, cura-1-vaga, base-2-formato,
        orrore-2-divieto, cura-2-divieto, orrore-3-stima, cura-3-stima,
        orrore-4-memoria, cura-4-memoria
Uscita: 0 la riga (o l'intestazione) stampata · 1 il JSON in ingresso
        non è una risposta riuscita di claude -p: vuoto, non valido, con
        un errore, senza la risposta o con la risposta vuota, senza
        «usage» o con un conteggio di token che non è un numero · 2 uso
        sbagliato (gli argomenti, una prova sconosciuta), oppure un
        ingresso assente, illeggibile o con un importo in euro. Mai un
        traceback: un errore inatteso esce 2, con un messaggio di una riga.
"""
from __future__ import annotations

import json
import os
import re
import sys
from typing import List

PROVE = ("orrore-1-vaga", "cura-1-vaga", "base-2-formato",
         "orrore-2-divieto", "cura-2-divieto", "orrore-3-stima",
         "cura-3-stima", "orrore-4-memoria", "cura-4-memoria")
CAMPI = ("prova", "token_entrata", "token_uscita", "parole", "righe",
         "titoli", "elenchi", "tabelle", "grassetti", "etichette",
         "importi", "non_indicato", "firma", "risposta")
INGRESSI = ("messaggio.md", "orrore-3-stima.md", "cura-3-stima.md")
TOKEN_ENTRATA = ("input_tokens", "cache_creation_input_tokens",
                 "cache_read_input_tokens")
VAGA = ("orrore-1-vaga", "cura-1-vaga")
STIMA = ("orrore-3-stima", "cura-3-stima")
MEMORIA = ("orrore-4-memoria", "cura-4-memoria")
NON_SI_APPLICA = "—"

TITOLO = re.compile(r"^ {0,3}#{1,6}[ \t]")
ELENCO = re.compile(r"^[ \t]*(?:[-*+•]|[0-9]{1,2}[.)])[ \t]")
TABELLA = re.compile(r"^[ \t]*\|.*\|")
GRASSETTO = re.compile(r"\*\*[^*\n]+\*\*")
# Una grandezza fra il numero e la valuta: «5 mila euro», «12 k€», «1,5
# milioni di euro», «3 mln €». La stessa regola conta gli importi delle
# risposte e cerca quelli degli ingressi.
GRANDEZZA = r"(?:mila|k|mln|milion[ei]|mld|miliard[oi])"
EURO = re.compile(r"[0-9][0-9.,]*\s?(?:%s\s?(?:di\s)?)?(?:€|euro?\b)"
                  r"|(?:€|\beur\b)\s?[0-9][0-9.,]*" % GRANDEZZA,
                  re.IGNORECASE)
NON_INDICATO = re.compile(r"\bnon\s+indicat[oaie]\b", re.IGNORECASE)
ETICHETTE = [re.compile(r"[ \t]*[*_]{0,3}%s[*_]{0,3}:" % nome)
             for nome in ("Problema", "Quando", "Richieste")]
FIRMA = "l'assistenza clienti di ciaspolink"
# Gli apostrofi tipografici diventano dritti; i segni del grassetto e del
# corsivo spariscono.
PULISCI = str.maketrans({"’": "'", "‘": "'", "ʼ": "'", "*": None,
                         "_": None})


class Errore(Exception):
    """Un errore previsto: il messaggio e l'uscita."""

    def __init__(self, messaggio: str, uscita: int) -> None:
        super().__init__(messaggio)
        self.messaggio = messaggio
        self.uscita = uscita


def controlla_ingressi() -> None:
    """Gli ingressi accanto a questo file si leggono e non contengono
    importi in euro; altrimenti Errore con uscita 2."""
    cartella = os.path.dirname(os.path.abspath(__file__))
    for nome in INGRESSI:
        try:
            with open(os.path.join(cartella, nome), encoding="utf-8") as fh:
                testo = fh.read()
        except (OSError, UnicodeDecodeError) as exc:
            raise Errore("%s assente o illeggibile accanto a "
                         "misura_orrori.py (%s)" % (nome, type(exc).__name__),
                         2)
        trovato = EURO.search(testo)
        if trovato:
            raise Errore("%s contiene un importo in euro («%s»): un importo "
                         "nelle risposte potrebbe venire da lì e non essere "
                         "inventato; rimettete il file com'era"
                         % (nome, " ".join(trovato.group(0).split())), 2)


def numero(valore: object, campo: str) -> int:
    """Un conteggio di token: None vale 0; altrimenti un intero >= 0."""
    if valore is None:
        return 0
    if isinstance(valore, bool) or not isinstance(valore, int) or valore < 0:
        raise Errore("%s non è un numero (%r)" % (campo, valore), 1)
    return valore


def leggi(testo: str) -> dict:
    """Il JSON di una risposta riuscita di claude -p; Errore con uscita 1
    se non lo è."""
    if not testo.strip():
        raise Errore("nessun JSON in ingresso: la chiamata a claude è "
                     "fallita?", 1)
    try:
        doc = json.loads(testo)
    except (ValueError, RecursionError) as exc:
        raise Errore("il testo in ingresso non è un JSON valido (%s)"
                     % " ".join(str(exc).split()), 1)
    if not isinstance(doc, dict):
        raise Errore("il JSON non è quello di claude -p", 1)
    if doc.get("is_error"):
        raise Errore("claude ha restituito un errore", 1)
    if not isinstance(doc.get("result"), str):
        raise Errore("il JSON non contiene la risposta («result»)", 1)
    if not doc["result"].strip():
        raise Errore("la risposta è vuota", 1)
    if not isinstance(doc.get("usage"), dict):
        raise Errore("il JSON non contiene «usage»", 1)
    return doc


def conta(regola: re.Pattern[str], righe: List[str]) -> int:
    """Quante righe cominciano come dice la regola."""
    return sum(1 for riga in righe if regola.match(riga))


def sino(vero: bool) -> str:
    """sì oppure no."""
    return "sì" if vero else "no"


def etichette(righe: List[str]) -> int:
    """Quante delle prime tre righe cominciano con la loro etichetta."""
    return sum(1 for riga, regola in zip(righe[:3], ETICHETTE)
               if regola.match(riga))


def ha_firma(testo: str) -> bool:
    """Vero se il testo contiene la firma concordata."""
    piano = " ".join(testo.translate(PULISCI).split()).casefold()
    return FIRMA in piano


def riga(prova: str, doc: dict) -> List[str]:
    """I campi della riga di orrori.tsv di una prova."""
    testo = doc["result"]
    uso = doc["usage"]
    righe = [r for r in testo.splitlines() if r.strip()]
    entrata = sum(numero(uso.get(c), "usage." + c) for c in TOKEN_ENTRATA)
    uscita = numero(uso.get("output_tokens"), "usage.output_tokens")
    return [prova, str(entrata), str(uscita), str(len(testo.split())),
            str(len(righe)), str(conta(TITOLO, righe)),
            str(conta(ELENCO, righe)), str(conta(TABELLA, righe)),
            str(len(GRASSETTO.findall(testo))),
            str(etichette(righe)) if prova in VAGA else NON_SI_APPLICA,
            str(len(EURO.findall(testo))),
            sino(bool(NON_INDICATO.search(testo))) if prova in STIMA
            else NON_SI_APPLICA,
            sino(ha_firma(testo)) if prova in MEMORIA else NON_SI_APPLICA,
            " ".join(testo.split())]


def scrivi(linea: str) -> None:
    """Una riga su STDOUT, in UTF-8 qualunque sia la lingua del sistema."""
    sys.stdout.buffer.write((linea + "\n").encode("utf-8"))
    sys.stdout.flush()


def main(argv: List[str]) -> int:
    if len(argv) != 1 or (argv[0] != "--intestazione"
                          and argv[0] not in PROVE):
        sys.stderr.write(__doc__)
        return 2
    try:
        controlla_ingressi()
        if argv[0] == "--intestazione":
            scrivi("\t".join(CAMPI))
            return 0
        testo = sys.stdin.buffer.read().decode("utf-8", errors="replace")
        scrivi("\t".join(riga(argv[0], leggi(testo))))
        return 0
    except Errore as exc:
        sys.stderr.write("misura_orrori.py: %s\n" % exc.messaggio)
        return exc.uscita
    except Exception as exc:  # mai un traceback: un errore inatteso esce 2
        sys.stderr.write("misura_orrori.py: errore inatteso: %s: %s\n" % (
            type(exc).__name__, " ".join(str(exc).split())))
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
