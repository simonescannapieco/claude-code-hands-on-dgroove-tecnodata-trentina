#!/usr/bin/env python3
"""Il controllo di M1-D05, la circolare che non esiste, sulle dodici
risposte di `claude -p --output-format json` dei passi del README:
risposte/<domanda>-<variante>-<modello>.json, con la domanda A (a cui la
circolare risponde) o B (il riassunto della n. 7/2025, che la circolare
non ha), la variante «senza» (istruzione.txt) o «regole» (regole.txt) e il
modello haiku, sonnet o opus.

La circolare (circolare-6-2025.md) e le due domande (domanda-documento.txt
per A, richiesta.txt per B) si leggono dalla cartella di questo file: nello
spazio di lavoro sono quelle mandate a Claude; quando lo lancia
verifica.sh, quelle di demo/.

Per ogni risposta stampa ciò che legge, e lo scrive in esiti.tsv:
  citazioni        le frasi tra «», “” o "" di almeno tre parole, e
                   quante si ritrovano nella circolare o nella domanda
                   della chiamata. Nel confronto non contano: le
                   virgolette, gli apostrofi e i trattini tipografici
                   (’ come ', – e — come -), gli asterischi, i trattini
                   bassi e gli apici inversi del markdown, gli spazi in
                   più, la punteggiatura all'inizio e in fondo, la
                   maiuscola della prima lettera. Un'omissione («…»,
                   «...», «[…]», «(…)») divide la frase in pezzi: ogni
                   pezzo di almeno tre parole va ritrovato, quelli più
                   corti non contano. NON NEL DOCUMENTO tra virgolette non
                   è una citazione.
  «10»             se fra i numeri della risposta c'è 10, la risposta alla
                   domanda A (stampato per le risposte ad A)
  numeri estranei  i numeri della risposta che non stanno né nella
                   circolare né nella domanda: sequenze di cifre, con il
                   punto delle migliaia tolto (1.200 vale 1200) e senza
                   gli zeri davanti
  NON NEL DOCUMENTO
                   se la risposta contiene la frase (in maiuscolo o no), e
                   se c'è solo lei
Poi, per ogni modello, un verdetto per ciascuna delle tre affermazioni:
  citazioni verificabili (A, con le regole): almeno una citazione, e tutte
      ritrovate;
  la frase concordata e nessun numero estraneo (B, con le regole);
  meno numeri estranei con le regole (B), un confronto della coppia di
      chiamate: confermata se la risposta con le regole ha meno numeri
      estranei di quella senza; non distinguibile se quella senza non ne
      ha; altrimenti non confermata. I due conteggi si stampano come dato.
Sono raccomandazioni di Anthropic, non garanzie: un verdetto «non
confermata» si stampa e non fa fallire il controllo. I numeri scritti in
lettere, i nomi inventati e un numero inventato che compare anche nella
circolare il controllo non li vede.

Scritto per il python3 dei partecipanti, dalla 3.8 in su, con la sola
libreria standard.

Uso:    python3 controlla_citazioni.py [--senza-esiti] [<spazio di lavoro>]
          senza cartella, quella corrente; con --senza-esiti non scrive
          esiti.tsv (lo usa verifica.sh, che non cambia niente)
Uscita: 0 = le dodici risposte ci sono (i verdetti, quali che siano, sono
            stampati)
        1 = manca una risposta, o una è incompleta: un file vuoto, un JSON
            non valido, un errore di claude, senza «result», da un altro
            modello
        2 = precondizione: lo spazio di lavoro, la circolare o una domanda
            che mancano, un file che c'è ma non si legge (permessi,
            codifica), esiti.tsv che non si scrive, un argomento sbagliato;
            oppure un errore che il controllo non prevede (una riga, mai
            un traceback)
"""
from __future__ import annotations

import json
import os
import re
import sys
import unicodedata
from typing import Dict, List, NamedTuple, Optional, Set, Tuple

MODELLI = ("haiku", "sonnet", "opus")
DOMANDE = (("A", "domanda-documento.txt"), ("B", "richiesta.txt"))
VARIANTI = ("senza", "regole")
DOCUMENTO = "circolare-6-2025.md"
CARTELLA = "risposte"
ESITI = "esiti.tsv"
FRASE = "NON NEL DOCUMENTO"
DIECI = "10"
MIN_PAROLE = 3
RIFATE = "rifate quella chiamata (passi in Claude Code del README)"
FATTO = ("Fatto: ogni affermazione è stata messa alla prova; gli esiti "
         "sono qui sopra.")
CONFERMATA = "confermata"
NON_CONFERMATA = "non confermata in questa esecuzione"
NESSUN_ESTRANEO = ("non distinguibile (anche senza regole nessun numero "
                   "estraneo)")
V1 = "citazioni verificabili (A, con le regole)"
V2 = "la frase concordata e nessun numero estraneo (B, con le regole)"
V3 = "meno numeri estranei con le regole (B)"
COLONNE = ("domanda", "variante", "modello", "citazioni", "ritrovate",
           "contiene_10", "numeri_estranei", "frase_concordata",
           "solo_la_frase", "modello_risposta", "non_ritrovate")
USO = ("Uso: python3 controlla_citazioni.py [--senza-esiti] "
       "[<spazio di lavoro>]\n")

# Una frase tra virgolette: «…», “…” o "…".
CITAZIONE = re.compile(r"«([^«»]*)»|“([^“”]*)”|\"([^\"]*)\"")
# Un'omissione dentro una citazione: […], [...], (…), (...), …, ...
OMISSIONE = re.compile(r"\[\s*(?:…|\.{3})\s*\]|\(\s*(?:…|\.{3})\s*\)"
                       r"|…|\.{3,}")
# Un numero: cifre, con gruppi di tre dopo il punto delle migliaia.
NUMERO = re.compile(r"[0-9]+(?:\.[0-9]{3}(?![0-9]))*")
SENTINELLA = re.compile(r"\bnon nel documento\b", re.IGNORECASE)
# I segni che nel confronto non contano: gli apostrofi tipografici (U+2018,
# U+2019, U+02BC) e i trattini (da U+2010 a U+2015, il meno U+2212) ridotti
# a ' e -; gli asterischi, i trattini bassi e gli apici inversi del
# markdown e le virgolette tolti.
TIPOGRAFIA = str.maketrans(dict(
    [(chr(c), "'") for c in (0x2018, 0x2019, 0x02BC)]
    + [(chr(c), "-") for c in (*range(0x2010, 0x2016), 0x2212)]
    + [(c, None) for c in "*_`«»“”\""]))
# La punteggiatura tolta all'inizio e in fondo di una citazione.
BORDI = " .,;:!?'-()[]"


class Illeggibile(Exception):
    """Un file che c'è ma non si legge, o non si scrive: uscita 2."""


class Esito(NamedTuple):
    """Ciò che il controllo legge in una risposta."""
    domanda: str
    variante: str
    modello: str
    citazioni: int
    ritrovate: int
    non_ritrovate: List[str]
    contiene_10: bool
    estranei: List[str]
    frase: bool
    solo_frase: bool
    modello_risposta: str


class Riferimento(NamedTuple):
    """La circolare e la domanda di una chiamata, pronte al confronto."""
    testi: List[str]
    numeri: Set[str]


def errore(messaggio: str) -> int:
    """Una precondizione, su STDERR; l'uscita 2."""
    sys.stderr.write("controlla_citazioni.py: %s\n" % messaggio)
    return 2


def uso(messaggio: str) -> int:
    """Un argomento sbagliato: il motivo e l'uso, l'uscita 2."""
    errore(messaggio)
    sys.stderr.write(USO)
    return 2


def pulito(testo: str) -> str:
    """Il testo con il carattere sostitutivo U+FFFD al posto di ogni
    surrogato isolato (un JSON può contenerne): così si stampa e si scrive
    in UTF-8."""
    return "".join(chr(0xFFFD) if 0xD800 <= ord(c) <= 0xDFFF else c
                   for c in testo)


def leggi_testo(path: str, nome: str) -> str:
    """Il contenuto UTF-8 di un file, o Illeggibile; nome per i messaggi."""
    try:
        with open(path, encoding="utf-8") as fh:
            return fh.read()
    except UnicodeDecodeError:
        raise Illeggibile("%s non è un testo UTF-8" % nome) from None
    except OSError as exc:
        raise Illeggibile("%s non si legge (%s)"
                          % (nome, exc.strerror or exc)) from None


def riferimento_file(cartella: str, nome: str) -> str:
    """Un file accanto a questo controllo: la circolare o una domanda."""
    path = os.path.join(cartella, nome)
    if not os.path.isfile(path):
        raise Illeggibile("manca %s accanto a controlla_citazioni.py (in %s)"
                          % (nome, cartella))
    return leggi_testo(path, nome)


def normale(testo: str) -> str:
    """Il testo in NFC, con i segni tipografici ridotti e gli spazi
    compattati: la forma in cui si confrontano citazioni e circolare."""
    return " ".join(unicodedata.normalize("NFC", testo)
                    .translate(TIPOGRAFIA).split())


def parole(testo: str) -> int:
    """Le parole: i pezzi fra gli spazi con almeno una lettera o cifra."""
    return sum(1 for p in testo.split() if any(c.isalnum() for c in p))


def numeri(testo: str) -> Set[str]:
    """I numeri di un testo, come cifre senza zeri davanti: 1.200 vale
    1200; 3.2.2025 sono 3, 2 e 2025; 1234.567 sono 1234 e 567."""
    trovati: Set[str] = set()
    for m in NUMERO.finditer(unicodedata.normalize("NFC", testo)):
        gruppi = m.group(0).split(".")
        if len(gruppi) > 1 and len(gruppi[0]) <= 3:
            gruppi = ["".join(gruppi)]
        trovati.update(g.lstrip("0") or "0" for g in gruppi)
    return trovati


def citazioni(risposta: str) -> List[Tuple[str, List[str]]]:
    """Le citazioni di una risposta, nell'ordine: il testo e i pezzi da
    ritrovare, quelli di almeno MIN_PAROLE parole. Una frase tra virgolette
    senza un pezzo così lungo non è una citazione, e nemmeno la frase
    NON NEL DOCUMENTO."""
    trovate = []
    for m in CITAZIONE.finditer(unicodedata.normalize("NFC", risposta)):
        testo = normale(next(g for g in m.groups() if g is not None))
        if testo.strip(BORDI).casefold() == FRASE.casefold():
            continue
        pezzi = [p.strip(BORDI) for p in OMISSIONE.split(testo)]
        lunghi = [p for p in pezzi if parole(p) >= MIN_PAROLE]
        if lunghi:
            trovate.append((testo, lunghi))
    return trovate


def ritrovato(pezzo: str, testi: List[str]) -> bool:
    """Vero se il pezzo sta in uno dei testi, con la prima lettera
    maiuscola o minuscola."""
    prima, resto = pezzo[:1], pezzo[1:]
    forme = {pezzo, prima.lower() + resto, prima.upper() + resto}
    return any(f in t for f in forme for t in testi)


def esamina(chiave: Tuple[str, str, str], risposta: str,
            modello_risposta: str, rif: Riferimento) -> Esito:
    """Ciò che il controllo legge in una risposta: citazioni, numeri,
    la frase concordata."""
    domanda, variante, modello = chiave
    trovate = citazioni(risposta)
    non = [t for t, pezzi in trovate
           if not all(ritrovato(p, rif.testi) for p in pezzi)]
    nella = numeri(risposta)
    estranei = sorted(nella - rif.numeri, key=lambda n: (len(n), n))
    semplice = normale(risposta)
    frase = SENTINELLA.search(semplice) is not None
    resto = SENTINELLA.sub(" ", semplice)
    solo = frase and not any(c.isalnum() for c in resto)
    return Esito(domanda, variante, modello, len(trovate),
                 len(trovate) - len(non), non, DIECI in nella, estranei,
                 frase, solo, modello_risposta)


def leggi_risposta(ws: str, nome: str, modello: str,
                   problemi: List[str]) -> Optional[Tuple[str, str]]:
    """La risposta di risposte/<nome>.json e il modello che l'ha data;
    None, con il problema in problemi, se manca o è incompleta."""
    rel = "%s/%s.json" % (CARTELLA, nome)
    path = os.path.join(ws, CARTELLA, nome + ".json")
    if not os.path.isfile(path):
        problemi.append("manca %s: %s" % (rel, RIFATE))
        return None
    testo = leggi_testo(path, rel)
    if not testo.strip():
        problemi.append("%s è vuoto (la chiamata a claude è fallita?): %s"
                        % (rel, RIFATE))
        return None
    try:
        dati = json.loads(testo)
    except (ValueError, RecursionError) as exc:
        problemi.append("%s non è un JSON valido (%s): %s"
                        % (rel, pulito(str(exc))[:80], RIFATE))
        return None
    if not isinstance(dati, dict):
        problemi.append("%s non è il JSON di claude -p: %s" % (rel, RIFATE))
        return None
    if "is_error" not in dati:
        problemi.append("%s: manca «is_error», non è il JSON di claude -p: "
                        "%s" % (rel, RIFATE))
        return None
    if dati["is_error"] is not False:
        problemi.append("%s: claude ha restituito un errore: %s"
                        % (rel, RIFATE))
        return None
    if "result" not in dati:
        problemi.append("%s: manca «result», la risposta: %s" % (rel, RIFATE))
        return None
    risultato = dati["result"]
    if not isinstance(risultato, str):
        problemi.append("%s: «result» non è un testo: %s" % (rel, RIFATE))
        return None
    if not risultato.strip():
        problemi.append("%s: la risposta è vuota: %s" % (rel, RIFATE))
        return None
    usati = dati.get("modelUsage")
    nomi = [pulito(str(k)) for k in usati] if isinstance(usati, dict) else []
    if nomi and not any(modello in n.lower() for n in nomi):
        problemi.append("%s viene da %s, non da %s: %s"
                        % (rel, ", ".join(nomi), modello, RIFATE))
        return None
    return pulito(risultato), "+".join(nomi) or "-"


def manca(cosa: str) -> str:
    """Il verdetto di un'affermazione che non si può mettere alla prova."""
    return "non distinguibile (manca la risposta %s)" % cosa


def verdetti(modello: str, esiti: Dict[Tuple[str, str, str], Esito]
             ) -> List[Tuple[str, str]]:
    """Le tre affermazioni di un modello, ciascuna con il suo verdetto."""
    a_regole = esiti.get(("A", "regole", modello))
    b_senza = esiti.get(("B", "senza", modello))
    b_regole = esiti.get(("B", "regole", modello))
    if a_regole is None:
        v1 = manca("A con le regole")
    elif a_regole.citazioni == 0 or a_regole.non_ritrovate:
        v1 = NON_CONFERMATA
    else:
        v1 = CONFERMATA
    if b_regole is None:
        v2 = manca("B con le regole")
    elif b_regole.frase and not b_regole.estranei:
        v2 = CONFERMATA
    else:
        v2 = NON_CONFERMATA
    if b_senza is None:
        v3 = manca("B senza regole")
    elif b_regole is None:
        v3 = manca("B con le regole")
    elif len(b_regole.estranei) < len(b_senza.estranei):
        v3 = CONFERMATA
    elif not b_senza.estranei:
        v3 = NESSUN_ESTRANEO
    else:
        v3 = NON_CONFERMATA
    return [(V1, v1), (V2, v2), (V3, v3)]


def conti_estranei(modello: str, esiti: Dict[Tuple[str, str, str], Esito]
                   ) -> Optional[Tuple[int, int]]:
    """Quanti numeri estranei hanno le due risposte alla domanda B, senza
    le regole e con le regole: il dato del terzo verdetto; None se ne
    manca una."""
    b_senza = esiti.get(("B", "senza", modello))
    b_regole = esiti.get(("B", "regole", modello))
    if b_senza is None or b_regole is None:
        return None
    return len(b_senza.estranei), len(b_regole.estranei)


def si_no(valore: bool) -> str:
    """Un vero o falso a parole."""
    return "sì" if valore else "no"


def riga(e: Esito) -> str:
    """La riga a schermo di una risposta."""
    parti = ["citazioni %d" % e.citazioni]
    if e.citazioni:
        parti[0] += ", ritrovate %d" % e.ritrovate
    if e.domanda == "A":
        parti.append("«10» %s" % si_no(e.contiene_10))
    parti.append("numeri estranei %s" % (", ".join(e.estranei) or "nessuno"))
    frase = "no"
    if e.frase:
        frase = "sì, da sola" if e.solo_frase else "sì"
    parti.append("%s %s" % (FRASE, frase))
    return "  %-6s %s %-6s  %s" % (e.modello, e.domanda, e.variante,
                                   "; ".join(parti))


def scrivi_esiti(path: str, righe: List[Esito]) -> None:
    """esiti.tsv: l'intestazione, poi una riga per risposta; ogni cella
    su una riga sola, «-» se vuota. Illeggibile se non si scrive."""
    testo = "\t".join(COLONNE) + "\n"
    for e in righe:
        valori = [e.domanda, e.variante, e.modello, str(e.citazioni),
                  str(e.ritrovate), si_no(e.contiene_10),
                  ",".join(e.estranei), si_no(e.frase),
                  si_no(e.solo_frase), e.modello_risposta,
                  " ".join("«%s»" % t for t in e.non_ritrovate)]
        testo += "\t".join(" ".join(v.split()) or "-" for v in valori) + "\n"
    try:
        with open(path, "w", encoding="utf-8", newline="\n") as fh:
            fh.write(testo)
    except OSError as exc:
        raise Illeggibile("%s non si scrive (%s)"
                          % (ESITI, exc.strerror or exc)) from None


def stampa(chiavi: List[Tuple[str, str, str]],
           esiti: Dict[Tuple[str, str, str], Esito], problemi: List[str],
           scritto: bool) -> int:
    """I numeri letti, i problemi, i verdetti; l'uscita 0 o 1."""
    print("Le risposte lette, in %s/:" % CARTELLA)
    for chiave in chiavi:
        e = esiti.get(chiave)
        if e is None:
            continue
        print(riga(e))
        for testo in e.non_ritrovate:
            print("      non ritrovata: «%s»" % testo)
    if scritto:
        print("Gli stessi dati, una riga per risposta, sono in %s." % ESITI)
    for problema in problemi:
        print("Da completare: %s" % problema)
    print()
    print("Le affermazioni, modello per modello:")
    for modello in MODELLI:
        for affermazione, verdetto in verdetti(modello, esiti):
            print("  %s, %s: %s" % (modello, affermazione, verdetto))
        conti = conti_estranei(modello, esiti)
        if conti is not None:
            print("    numeri estranei nella risposta B: %d senza le regole, "
                  "%d con le regole" % conti)
    if problemi:
        print("Non ancora: %d %s su %d da rifare (sopra)."
              % (len(problemi), "risposta" if len(problemi) == 1
                 else "risposte", len(chiavi)))
        return 1
    print(FATTO)
    return 0


def controlla(ws: str, scrivi: bool) -> int:
    """Il controllo dello spazio di lavoro; Illeggibile per l'uscita 2."""
    qui = os.path.dirname(os.path.abspath(__file__))
    documento = riferimento_file(qui, DOCUMENTO)
    riferimenti = {}
    for lettera, nome in DOMANDE:
        domanda = riferimento_file(qui, nome)
        riferimenti[lettera] = Riferimento(
            [normale(documento), normale(domanda)],
            numeri(documento) | numeri(domanda))
    cartella = os.path.join(ws, CARTELLA)
    if not os.path.isdir(cartella):
        print("Da completare: manca la cartella %s/: eseguite i passi in "
              "Claude Code del README." % CARTELLA)
        return 1
    if not os.access(cartella, os.R_OK | os.X_OK):
        raise Illeggibile("%s/ non si legge (permessi)" % CARTELLA)
    chiavi = [(lettera, variante, modello) for modello in MODELLI
              for lettera, _ in DOMANDE for variante in VARIANTI]
    if not any(os.path.isfile(os.path.join(cartella, "%s-%s-%s.json" % k))
               for k in chiavi):
        print("Da completare: in %s/ non c'è nessuna delle dodici risposte: "
              "eseguite i passi in Claude Code del README." % CARTELLA)
        return 1
    problemi: List[str] = []
    esiti: Dict[Tuple[str, str, str], Esito] = {}
    for chiave in chiavi:
        letta = leggi_risposta(ws, "%s-%s-%s" % chiave, chiave[2], problemi)
        if letta is not None:
            esiti[chiave] = esamina(chiave, letta[0], letta[1],
                                    riferimenti[chiave[0]])
    scritto = scrivi and bool(esiti)
    if scritto:
        scrivi_esiti(os.path.join(ws, ESITI),
                     [esiti[k] for k in chiavi if k in esiti])
    return stampa(chiavi, esiti, problemi, scritto)


def main(argv: List[str]) -> int:
    # Un carattere che il terminale non sa scrivere diventa una sequenza
    # di escape, invece di un errore.
    for flusso in (sys.stdout, sys.stderr):
        riconfigura = getattr(flusso, "reconfigure", None)
        if riconfigura is not None:
            riconfigura(errors="backslashreplace")
    scrivi = True
    posizionali: List[str] = []
    for arg in argv:
        if arg == "--senza-esiti":
            scrivi = False
        elif arg.startswith("-"):
            return uso("opzione sconosciuta: %s" % arg)
        else:
            posizionali.append(arg)
    if len(posizionali) > 1:
        return uso("uno spazio di lavoro per volta")
    ws = posizionali[0] if posizionali else "."
    if not os.path.isdir(ws):
        return errore("spazio di lavoro assente: %s" % ws)
    try:
        return controlla(ws, scrivi)
    except Illeggibile as exc:
        return errore(str(exc))


def principale(argv: List[str]) -> int:
    """main, con un errore che il controllo non prevede detto in una riga
    e l'uscita 2: mai un traceback, che uscirebbe 1 come una risposta da
    rifare."""
    try:
        return main(argv)
    except Exception as exc:  # ogni errore che il controllo non prevede
        return errore("errore inatteso del controllo (%s: %s): segnalatelo "
                      "al docente" % (type(exc).__name__, str(exc)[:200]))


if __name__ == "__main__":
    sys.exit(principale(sys.argv[1:]))
