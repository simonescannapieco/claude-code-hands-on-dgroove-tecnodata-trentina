"""controlla_pipe.py -- il log in una pipe (M4-D08): in modalità non
interattiva Claude Code legge lo STDIN, e lo STDIN in pipe ha un tetto di
10 MB.

Sta nella cartella dell'elemento, fuori dallo spazio di lavoro, perché porta
la verità: gli orari del guasto di martedì 8 settembre su olt-pergine-01,
inizio 10:12 e fine 11:40, dalla mappa degli avvenimenti della rete
(progetti/rete/_docente/README.md, che nello spazio di lavoro non arriva).

Legge, nello spazio di lavoro (la cartella data, o quella corrente), i due
bracci della prova in pipe/<braccio>.{out,err,uscita,byte}: lo STDOUT, lo
STDERR e il codice d'uscita di `claude -p … --output-format json`, e i
byte che gli sono arrivati in pipe. I due bracci hanno lo stesso comando e
la stessa domanda; cambia soltanto l'ingresso:
  filtrato  le righe di olt-pergine-01 nel syslog della settimana, sotto il
            tetto;
  grande    il syslog della settimana ripetuto, oltre i 10 MB.
Stampa, per ciascuno, i byte, l'uscita e i token in entrata (dati); per il
filtrato la risposta e i suoi orari contro la verità (dati: mai un esito,
mai l'uscita); per il grande che cosa ha stampato, il messaggio compreso.
Poi il verdetto sulla garanzia di Anthropic, «Piped stdin is capped at
10MB. If you exceed the cap, Claude Code exits with a clear error and a
non-zero status.»: confermata se il braccio grande esce con un codice
diverso da zero, con un messaggio (su STDERR, oppure un JSON d'errore su
STDOUT) e senza un risultato riuscito; altrimenti non confermata in questa
esecuzione, e l'uscita è 1. Si decide soltanto se il braccio filtrato è
riuscito: se no (un accesso che manca, il limite d'uso, la rete), anche
il grande può fallire per quello, i due bracci non differiscono più
soltanto nell'ingresso, e il verdetto è non distinguibile. Mai «smentita».

Uso:    python3 controlla_pipe.py [<spazio di lavoro>]
Uscita: 0 i due bracci ci sono, il filtrato è riuscito e la garanzia è
          confermata (gli orari non decidono l'uscita)
        1 manca pipe/ o un suo file, o un file non va; il braccio filtrato
          non è riuscito o non sta sotto il tetto; il braccio grande non
          supera i 10 MB; oppure la garanzia non confermata in questa
          esecuzione
        2 uso sbagliato; lo spazio di lavoro assente; un file che non si
          legge; un errore inatteso (una riga, mai un traceback)
"""
from __future__ import annotations

import json
import os
import re
import sys
from typing import Dict, List, NamedTuple, Optional, Tuple

# La verità, dalla mappa degli avvenimenti della settimana nella rete:
# «Martedì 8, 10:12–11:40 — fibra tagliata sulla porta PON 0/1/3 di
# olt-pergine-01» (PON_LOS alle 10:12:31, PON_LOS_CLEAR alle 11:40:04).
INIZIO = "10:12"
FINE = "11:40"
CARTELLA = "pipe"
BRACCI = ("filtrato", "grande")
PARTI = ("out", "err", "uscita", "byte")
# Il tetto, «10MB»: sotto i 10.000.000 byte il braccio filtrato, oltre i
# 10.485.760 (10 MiB) il braccio grande, così che valga in entrambe le letture.
SOTTO = 10 * 1000 * 1000
OLTRE = 10 * 1024 * 1024
VERDETTO = ("Lo stdin in pipe ha un tetto di 10 MB: oltre, Claude Code esce "
            "con un errore chiaro e un'uscita diversa da zero")
CONFERMATA = "confermata"
NON_CONFERMATA = "non confermata in questa esecuzione"
NON_DISTINGUIBILE = "non distinguibile"
GARANZIA = ("La documentazione garantisce che oltre i 10 MB Claude Code "
            "esce con un errore chiaro e un'uscita diversa da zero: in "
            "questa esecuzione no")
# Il tetto si decide soltanto se il braccio filtrato è riuscito: se no
# (nessun accesso, il limite d'uso, la rete), anche il grande può fallire
# per quello, e i due bracci non differiscono più soltanto nell'ingresso.
SENZA_FILTRATO = ("il braccio filtrato non è riuscito, e i due bracci non "
                  "differiscono più soltanto nell'ingresso")
PARTENZA = "Manca la cartella pipe/: eseguite i passi del README."
NON_ANCORA = ("Non ancora: un braccio manca o non va; rifate il braccio "
              "indicato sopra, poi rilanciate il controllo.")
USO = "Uso: python3 controlla_pipe.py [<spazio di lavoro>]\n"
NA = "—"
INIZIO_RISPOSTA = 300
MARKDOWN = re.compile(r"[*_`]")
ORA = r"(\d{1,2})\s*[:.]\s*(\d{2})"
RE_INIZIO = re.compile(r"\binizio\b\W*(?:alle\s+|ore\s+)?" + ORA,
                       re.IGNORECASE)
RE_FINE = re.compile(r"\bfine\b\W*(?:alle\s+|ore\s+)?" + ORA, re.IGNORECASE)


class Precondizione(Exception):
    """Un file che non si legge: uscita 2."""


class Mancante(Exception):
    """Un file del braccio che manca o non va: uscita 1."""


class Braccio(NamedTuple):
    """Un braccio della prova: lo STDOUT, lo STDERR, l'uscita di claude, i
    byte passati in pipe."""
    out: str
    err: str
    uscita: int
    byte: int


def compatta(testo: str) -> str:
    """Il testo su una riga sola, al massimo INIZIO_RISPOSTA caratteri."""
    riga = " ".join(testo.split())
    if len(riga) <= INIZIO_RISPOSTA:
        return riga
    return riga[:INIZIO_RISPOSTA - 1] + "…"


def avviso(messaggio: str) -> None:
    """Un braccio da rifare, o un errore, su STDERR."""
    sys.stderr.write("controlla_pipe.py: %s\n" % messaggio)


def leggi_parte(braccio: str, parte: str) -> str:
    """Il testo di pipe/<braccio>.<parte>. Mancante se manca; Precondizione se
    non si legge."""
    percorso = "%s/%s.%s" % (CARTELLA, braccio, parte)
    if not os.path.lexists(percorso):
        raise Mancante("manca %s: rifate quel braccio" % percorso)
    try:
        with open(percorso, "rb") as fh:
            return fh.read().decode("utf-8", errors="replace")
    except OSError as exc:
        raise Precondizione("%s non si legge (%s)"
                            % (percorso, exc.strerror or exc))


def intero(braccio: str, parte: str, testo: str, cosa: str) -> int:
    """Un intero non negativo scritto in un file; Mancante se non lo è."""
    valore = testo.strip()
    if not valore.isdigit():
        raise Mancante("%s/%s.%s non è %s: rifate quel braccio"
                       % (CARTELLA, braccio, parte, cosa))
    return int(valore)


def leggi_braccio(nome: str) -> Braccio:
    """I quattro file di un braccio."""
    testi = {parte: leggi_parte(nome, parte) for parte in PARTI}
    uscita = intero(nome, "uscita", testi["uscita"], "un codice d'uscita")
    byte = intero(nome, "byte", testi["byte"], "un numero di byte")
    return Braccio(testi["out"], testi["err"], uscita, byte)


def json_di(testo: str) -> Optional[dict]:
    """L'oggetto JSON dello STDOUT (tutto, o la sua ultima riga), oppure
    None."""
    pulito = testo.strip()
    if not pulito:
        return None
    for candidato in (pulito, pulito.splitlines()[-1]):
        try:
            doc = json.loads(candidato)
        except (ValueError, RecursionError):
            continue
        if isinstance(doc, dict):
            return doc
    return None


def riuscito(doc: Optional[dict]) -> bool:
    """Vero se l'oggetto è il risultato riuscito di claude -p."""
    return (doc is not None and doc.get("type") == "result"
            and not doc.get("is_error")
            and doc.get("subtype", "success") == "success"
            and isinstance(doc.get("result"), str))


def token(doc: Optional[dict]) -> str:
    """I token in entrata del risultato (anche quelli in cache), o —."""
    uso = doc.get("usage") if doc is not None else None
    if not isinstance(uso, dict):
        return NA
    voci = [uso.get(k) for k in ("input_tokens", "cache_creation_input_tokens",
                                 "cache_read_input_tokens")]
    numeri = [v for v in voci if isinstance(v, int)
              and not isinstance(v, bool)]
    return str(sum(numeri)) if numeri else NA


def orario(regola, testo: str) -> Optional[str]:
    """Il primo orario dopo la parola della regola, come HH:MM."""
    trovato = regola.search(MARKDOWN.sub("", testo))
    if not trovato:
        return None
    return "%02d:%02d" % (int(trovato.group(1)), int(trovato.group(2)))


def giudizio(letto: Optional[str], vero: str) -> str:
    """Un orario letto contro la verità, in parole."""
    if letto is None:
        return NA
    return "%s (%s)" % (letto, "giusto" if letto == vero else "sbagliato")


def filtrato(braccio: Braccio) -> int:
    """I dati del braccio filtrato; 1 se il braccio non va."""
    doc = json_di(braccio.out)
    print("filtrato: %d byte in pipe; uscita %d; token in entrata %s"
          % (braccio.byte, braccio.uscita, token(doc)))
    problemi = 0
    if not 0 < braccio.byte <= SOTTO:
        avviso("pipe/filtrato.byte: %d byte, non sotto il tetto: il braccio "
               "filtrato porta soltanto le righe di olt-pergine-01; "
               "rifatelo" % braccio.byte)
        problemi = 1
    if braccio.uscita != 0 or not riuscito(doc):
        avviso("il braccio filtrato non è riuscito (uscita %d): rifatelo"
               % braccio.uscita)
        if braccio.err.strip():
            print("  STDERR: «%s»" % compatta(braccio.err))
        return 1
    risposta = doc["result"] if doc is not None else ""
    print("  risposta: «%s»" % compatta(risposta))
    print("  orari: inizio %s · fine %s"
          % (giudizio(orario(RE_INIZIO, risposta), INIZIO),
             giudizio(orario(RE_FINE, risposta), FINE)))
    print("  la verità, dalla mappa degli avvenimenti della rete: inizio "
          "%s, fine %s" % (INIZIO, FINE))
    return problemi


def messaggio(braccio: Braccio, doc: Optional[dict]) -> Tuple[str, str]:
    """(dove, testo) del messaggio d'errore del braccio; ("", "") se non ce
    n'è. Un JSON d'errore su STDOUT conta, come un testo che non è JSON."""
    if braccio.err.strip():
        return "STDERR", braccio.err
    if doc is not None and doc.get("is_error"):
        testo = doc.get("result")
        if not isinstance(testo, str) or not testo.strip():
            testo = json.dumps(doc, ensure_ascii=False)
        return "STDOUT", testo
    if braccio.out.strip() and doc is None:
        return "STDOUT", braccio.out
    return "", ""


def grande(braccio: Braccio) -> Tuple[int, Optional[bool]]:
    """I dati del braccio grande e la garanzia: (1 se il braccio non va,
    True se confermata, False se no, None se non si decide)."""
    doc = json_di(braccio.out)
    successo = riuscito(doc)
    stdout = ("un risultato riuscito su STDOUT, token in entrata %s"
              % token(doc)) if successo else "nessun risultato su STDOUT"
    print("grande: %d byte in pipe; uscita %d; %s"
          % (braccio.byte, braccio.uscita, stdout))
    dove, testo = messaggio(braccio, doc)
    if dove:
        print("  messaggio su %s: «%s»" % (dove, compatta(testo)))
    else:
        print("  nessun messaggio, né su STDERR né su STDOUT")
    if braccio.byte <= OLTRE:
        avviso("pipe/grande.byte: %d byte, non oltre i 10 MB: il braccio "
               "grande non mette alla prova il tetto; rifatelo con il file "
               "grande del README" % braccio.byte)
        return 1, None
    return 0, braccio.uscita != 0 and bool(dove) and not successo


def riuscito_il_filtrato(bracci: Dict[str, Braccio]) -> bool:
    """Vero se il braccio filtrato c'è ed è riuscito: uscita 0 e il
    risultato riuscito di claude -p su STDOUT."""
    braccio = bracci.get("filtrato")
    return (braccio is not None and braccio.uscita == 0
            and riuscito(json_di(braccio.out)))


def controlla() -> int:
    """Il controllo nella cartella corrente, lo spazio di lavoro: stampa e
    restituisce l'uscita 0 o 1. Precondizione per l'uscita 2."""
    if not os.path.isdir(CARTELLA):
        print(PARTENZA)
        return 1
    bracci: Dict[str, Braccio] = {}
    problemi = 0
    for nome in BRACCI:
        try:
            bracci[nome] = leggi_braccio(nome)
        except Mancante as exc:
            avviso(str(exc))
            problemi += 1
    if "filtrato" in bracci:
        problemi += filtrato(bracci["filtrato"])
    esito = 0
    if "grande" in bracci:
        rotto, confermata = grande(bracci["grande"])
        problemi += rotto
        if confermata is not None and not riuscito_il_filtrato(bracci):
            print("%s: %s: %s" % (VERDETTO, NON_DISTINGUIBILE,
                                  SENZA_FILTRATO))
        elif confermata is True:
            print("%s: %s" % (VERDETTO, CONFERMATA))
        elif confermata is False:
            print("%s: %s" % (VERDETTO, NON_CONFERMATA))
            print("%s (uscita %d)." % (GARANZIA, bracci["grande"].uscita))
            esito = 1
    if problemi:
        print(NON_ANCORA)
        return 1
    return esito


def errore(testo: str) -> int:
    """Il messaggio su STDERR, in una riga; l'uscita 2."""
    avviso(testo)
    return 2


def uso(testo: str) -> int:
    """Un argomento sbagliato: il motivo e l'uso; l'uscita 2."""
    errore(testo)
    sys.stderr.write(USO)
    return 2


def main(argv: List[str]) -> int:
    for flusso in (sys.stdout, sys.stderr):
        riconfigura = getattr(flusso, "reconfigure", None)
        if riconfigura is not None:
            riconfigura(errors="replace")
    posizionali: List[str] = []
    for arg in argv:
        if arg.startswith("-"):
            return uso("opzione sconosciuta: %s" % arg)
        posizionali.append(arg)
    if len(posizionali) > 1:
        return uso("uno spazio di lavoro per volta")
    ws = posizionali[0] if posizionali else "."
    if not os.path.isdir(ws):
        return errore("spazio di lavoro assente: %s" % ws)
    try:
        os.chdir(ws)
    except OSError as exc:
        return errore("lo spazio di lavoro %s non si apre (%s)"
                      % (ws, exc.strerror or exc))
    try:
        return controlla()
    except Precondizione as exc:
        return errore(str(exc))
    except Exception as exc:  # mai un traceback: un errore inatteso esce 2
        return errore("errore inatteso (%s: %s)"
                      % (type(exc).__name__, " ".join(str(exc).split())))


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
