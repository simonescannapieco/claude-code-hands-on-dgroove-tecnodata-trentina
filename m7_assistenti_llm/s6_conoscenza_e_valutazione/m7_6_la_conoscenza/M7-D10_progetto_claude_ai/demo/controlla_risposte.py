"""controlla_risposte.py -- la stessa domanda, in una chat e in un progetto di
claude.ai (M7-D10): che cosa c'è delle procedure nelle due risposte.

È una dimostrazione: legge le due risposte come le avete salvate, non ciò che
è successo su claude.ai, che si guarda sullo schermo. Legge, nello spazio di
lavoro (la cartella data, o quella corrente), la procedura che risponde alla
domanda (conoscenza/kb-12-orari-e-canali.md: il suo codice, KB-12, e il numero
dell'Assistenza Prioritaria) e le due risposte alla domanda di domanda.txt:
  risposte/chat.txt      una chat nuova, fuori dai progetti, con «Memory»
                         spenta prima del primo messaggio e niente allegato;
  risposte/progetto.txt  una chat nuova nel progetto che ha nella conoscenza
                         le procedure di conoscenza/, anche lei con «Memory»
                         spenta.
Di ogni risposta stampa l'inizio e, come dati: se ha il codice della procedura,
se ha il numero (in cifre, con o senza spazi), e i codici KB-NN che cita, per
ciascuno se è fra le procedure caricate. Poi, come dato, in quale delle due
risposte ci sono il codice e il numero insieme. Nessuna riga decide: ciò che
dice Anthropic si guarda sullo schermo, e qui si legge soltanto il testo
copiato. Il controllo non scrive niente e non chiama nessun modello.

Uso:    python3 controlla_risposte.py [<spazio di lavoro>]
          senza cartella, quella corrente
Uscita: 0 le due risposte ci sono e non sono vuote · 1 una risposta che manca
        o è vuota (dice quale) · 2 uso sbagliato, spazio di lavoro assente, la
        procedura che manca o senza il numero, un file che non si legge o non
        è testo UTF-8, un errore inatteso (una riga, mai un traceback)
"""
from __future__ import annotations

import os
import re
import sys
import unicodedata
from typing import List, Optional, Tuple

CONOSCENZA = "conoscenza"
PROCEDURA = os.path.join(CONOSCENZA, "kb-12-orari-e-canali.md")
RISPOSTE = (("risposte/chat.txt", "la chat, senza progetto"),
            ("risposte/progetto.txt",
             "la chat nel progetto con le procedure"))
INIZIO = 160
RE_TITOLO = re.compile(r"^#\s+(KB-\d+)\s*·\s*(.+?)\s*$", re.M)
RE_NUMERO_PRIORITARIA = re.compile(
    r"^-\s*Assistenza Prioritaria.*?:\s*(\+?[\d ]+?)\s*$", re.M)
RE_CODICE = re.compile(r"\bkb[-\s]?(\d{2})\b", re.IGNORECASE)
RE_FILE_KB = re.compile(r"^kb-(\d{2})-.*\.md$")
RE_FRA_CIFRE = re.compile(r"(?<=\d)[\s.\-/ ](?=\d)")
PREFISSO_ITALIA = "39"
DIMOSTRAZIONE = ("Dimostrazione: il controllo legge le due risposte come le "
                 "avete salvate; che cosa ha fatto claude.ai si guarda sullo "
                 "schermo.")
NON_ANCORA = ("Non ancora: manca almeno una risposta; fate la chat indicata, "
              "salvate la risposta nel suo file e rilanciate il controllo.")
USO = "Uso: python3 controlla_risposte.py [<spazio di lavoro>]\n"


class Precondizione(Exception):
    """Un file che non si legge, non è UTF-8 o non ha la forma attesa:
    uscita 2."""


def sino(vero: bool) -> str:
    """sì oppure no."""
    return "sì" if vero else "no"


def leggi(percorso: str) -> Optional[str]:
    """Il testo di un file in forma NFKC, senza i caratteri di formato
    invisibili; None se il file non c'è. Precondizione se non si legge o
    non è testo UTF-8."""
    if not os.path.lexists(percorso):
        return None
    try:
        with open(percorso, "rb") as fh:
            dati = fh.read()
    except OSError as exc:
        raise Precondizione("%s non si legge (%s)"
                            % (percorso, exc.strerror or exc)) from exc
    try:
        testo = unicodedata.normalize("NFKC", dati.decode("utf-8"))
    except UnicodeDecodeError as exc:
        raise Precondizione("%s non è testo UTF-8: salvate di nuovo il file "
                            "come testo UTF-8" % percorso) from exc
    return "".join(c for c in testo if unicodedata.category(c) != "Cf")


def leggi_procedura() -> Tuple[str, str, str]:
    """Il codice, il titolo e il numero dell'Assistenza Prioritaria. Le cifre
    del numero sono senza prefisso internazionale. Precondizione se la
    procedura manca o non ha il numero."""
    testo = leggi(PROCEDURA)
    if testo is None:
        raise Precondizione("manca %s: lo spazio di lavoro non è quello di "
                            "partenza (tools/reset_esercizio.sh M7-D10)"
                            % PROCEDURA)
    titolo = RE_TITOLO.search(testo)
    numero = RE_NUMERO_PRIORITARIA.search(testo)
    if titolo is None or numero is None:
        raise Precondizione("%s non ha il titolo «# KB-NN · …» o il numero "
                            "dell'Assistenza Prioritaria" % PROCEDURA)
    return titolo.group(1), titolo.group(2), numero.group(1).strip()


def caricate() -> List[str]:
    """I codici delle procedure di conoscenza/."""
    try:
        nomi = os.listdir(CONOSCENZA)
    except OSError as exc:
        raise Precondizione("manca la cartella %s/" % CONOSCENZA) from exc
    codici = []
    for nome in sorted(nomi):
        m = RE_FILE_KB.match(nome)
        if m:
            codici.append("KB-%s" % m.group(1))
    return codici


def cifre_numero(numero: str) -> str:
    """Le cifre del numero, senza il prefisso internazionale."""
    cifre = "".join(c for c in numero if c.isdigit())
    return cifre[len(PREFISSO_ITALIA):] \
        if numero.strip().startswith("+") else cifre


def ha_numero(testo: str, cifre: str) -> bool:
    """Vero se la risposta ha il numero, anche con spazi, punti o trattini
    fra le cifre, e con o senza il prefisso."""
    unito = RE_FRA_CIFRE.sub("", testo)
    return cifre in unito


def citati(testo: str) -> List[str]:
    """I codici KB-NN che la risposta cita, nell'ordine, ciascuno una
    volta."""
    codici: List[str] = []
    for cifre in RE_CODICE.findall(testo):
        codice = "KB-%s" % cifre
        if codice not in codici:
            codici.append(codice)
    return codici


def una_riga(testo: str) -> str:
    """L'inizio della risposta, su una riga."""
    riga = " ".join(testo.split())
    return riga if len(riga) <= INIZIO else riga[:INIZIO] + "…"


def esamina(testo: str, codice: str, cifre: str,
            caricati: List[str]) -> bool:
    """Stampa i dati di una risposta. Returns: vero se ha codice e numero."""
    trovati = citati(testo)
    con_codice = codice in trovati
    con_numero = ha_numero(testo, cifre)
    print("  (dato) il codice %s: %s; il numero dell'Assistenza Prioritaria: "
          "%s" % (codice, sino(con_codice), sino(con_numero)))
    voci = ["%s, fra le procedure caricate: %s" % (c, sino(c in caricati))
            for c in trovati]
    print("  (dato) i codici citati: %s" % ("; ".join(voci) or "nessuno"))
    return con_codice and con_numero


def controlla() -> int:
    """Il controllo nella cartella corrente: legge tutti i file prima di
    stampare, poi i dati. Returns: 0 o 1. Precondizione per l'uscita 2."""
    codice, titolo, numero = leggi_procedura()
    caricati = caricate()
    cifre = cifre_numero(numero)
    risposte = [(p, d, leggi(p)) for p, d in RISPOSTE]
    print(DIMOSTRAZIONE)
    print()
    print("La procedura, %s: %s, «%s»; il numero dell'Assistenza Prioritaria: "
          "%s; procedure caricate: %s." % (PROCEDURA, codice, titolo, numero,
                                           ", ".join(caricati)))
    complete: List[Tuple[str, bool]] = []
    mancanti = 0
    for percorso, descrizione, testo in risposte:
        if testo is None or not testo.strip():
            sys.stderr.write("controlla_risposte.py: %s %s: salvatevi la "
                             "risposta (%s)\n" % (
                                 percorso, "manca" if testo is None
                                 else "è vuoto", descrizione))
            mancanti += 1
            continue
        print("%s, %s: «%s»" % (percorso, descrizione, una_riga(testo)))
        complete.append((descrizione, esamina(testo, codice, cifre,
                                              caricati)))
    if len(complete) == len(RISPOSTE):
        print("\n(dato) il codice e il numero insieme: %s" % "; ".join(
            "%s: %s" % (d, sino(v)) for d, v in complete))
    if mancanti:
        print(NON_ANCORA)
        return 1
    return 0


def errore(messaggio: str) -> int:
    """Il messaggio su STDERR, in una riga; l'uscita 2."""
    sys.stderr.write("controlla_risposte.py: %s\n"
                     % " ".join(messaggio.split()))
    return 2


def main(argv: List[str]) -> int:
    for flusso in (sys.stdout, sys.stderr):
        riconfigura = getattr(flusso, "reconfigure", None)
        if riconfigura is not None:
            riconfigura(errors="replace")
    posizionali = [a for a in argv if not a.startswith("-")]
    if len(posizionali) != len(argv) or len(posizionali) > 1:
        errore("argomenti non validi: %s" % " ".join(argv))
        sys.stderr.write(USO)
        return 2
    ws = posizionali[0] if posizionali else "."
    if not os.path.isdir(ws):
        return errore("spazio di lavoro assente: %s" % ws)
    try:
        os.chdir(ws)
        return controlla()
    except Precondizione as exc:
        return errore(str(exc))
    except Exception as exc:  # pylint: disable=broad-except
        return errore("errore inatteso (%s: %s)" % (type(exc).__name__, exc))


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
