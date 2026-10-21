#!/usr/bin/env python3
"""controlla_pii.py -- quanti dati personali restano nel file anonimo.

Il controllo conosce i dati personali della settimana di ticket solo come
impronte: impronte.json (versione 2), accanto a questo file, contiene per
ogni classe lo SHA-256 di «sale + forma normalizzata» di ogni valore, mai i
valori, e in «parti» le impronte delle parole dei nomi di persona (le
parole di almeno tre lettere di nomi e cognomi, per nomi e per familiari).
Il controllo cerca in ogni cella del CSV i candidati di ogni classe, li
normalizza come sono state normalizzate le impronte, ne calcola l'impronta e
la cerca. Stampa, per classe, quanti residui trova e in quali segnalazioni
(id_ticket), mai un valore. Con --forme stampa anche, per ogni residuo, la
colonna e la forma: ogni lettera diventa x (X se maiuscola), ogni cifra 9,
il resto resta com'è. Così si corregge un'espressione regolare senza vedere
il dato.

Come si cercano i candidati, classe per classe:
  utenze_pppoe   «ln» + 6 cifre + @ + dominio
  email          nome@dominio
  mac            sei coppie esadecimali, con o senza «:», «-» o «.»
  ip             quattro numeri separati da punti
  telefoni       ogni gruppo di cifre, anche con spazi, punti, trattini o
                 barre fra una cifra e l'altra: ogni sua finestra di 10 cifre
  codici_cliente «CL» + 6 cifre, codici_linea «LN» + 6 cifre (con o senza
                 trattino, maiuscole o minuscole)
  indirizzi, salute, nomi, familiari
                 ogni sequenza da 1 a 5 parole consecutive, le più lunghe
                 prima
  un nome a metà dopo tutte le altre: una parola accanto a un [OMESSO], con
                 soltanto spazi fra le due (da una parte o dall'altra), con
                 l'iniziale maiuscola nel testo e fuori dai residui già
                 trovati, è un residuo dei nomi se la sua forma piegata è
                 fra le parti dei nomi, se no dei familiari se è fra le loro:
                 «Nome [OMESSO]» o «[OMESSO] Cognome», un nome rimasto a metà
Le forme normalizzate:
  parole         ogni parola (lettere e cifre consecutive) senza accenti e in
                 minuscolo, unite da uno spazio: «Via dell'Esempio 12» diventa
                 «via dell esempio 12»;
  telefoni       le 10 cifre della finestra; per un valore, le sue ultime 10
                 cifre (il numero senza il prefisso internazionale);
  email, utenze_pppoe  in minuscolo;
  mac            le 12 cifre esadecimali in minuscolo, senza separatori;
  ip             i quattro numeri senza zeri davanti, separati da punti;
  codici         «CL-» o «LN-» seguito dalle 6 cifre;
  parti dei nomi la parola senza accenti e in minuscolo.
Le classi si cercano nell'ordine qui sopra: un tratto di testo già trovato
come residuo non conta una seconda volta, e le parole non si legano
attraverso un residuo o un [OMESSO].

Ogni esecuzione del controllo (non -h, non un errore negli argomenti)
aggiunge una riga a controlli.log, nella cartella del file controllato, e
crea la cartella se serve: l'ora UTC, l'uscita, il numero di residui («-»
se il controllo non ha potuto girare), separati da tabulazioni.

L'ultima riga dell'uscita dice sempre l'esito, con lo stesso codice con cui
il controllo esce: «uscita: 0 (nessun dato personale rimasto)», «uscita: 1
(restano dati personali: vedi sopra)» o «uscita: 2 (…)». Si legge lì: il
controllo si esegue da solo, senza concatenarlo ad altri comandi e senza
chiedere $?.

Uso:    python3 controlla_pii.py [file] [--forme]
          file      il CSV da controllare (default anonimo/ticket-anonimi.csv,
                    accanto a questo file)
          --forme   anche la colonna e la forma di ogni residuo
Uscita: 0 nessun dato personale rimasto · 1 ne resta almeno uno, o
        l'intestazione ha ancora una colonna da togliere (nome_cliente,
        telefono, email, id_linea, id_cliente) · 2 precondizione: il file
        manca, non si legge, non è un CSV UTF-8 con una riga di intestazione,
        la colonna id_ticket e almeno una riga; impronte.json manca o è
        malformato (anche se non è della versione 2 o non ha le parti dei
        nomi); controlli.log non si scrive
"""
from __future__ import annotations

import csv
import datetime as dt
import hashlib
import json
import os
import re
import sys
import textwrap
import unicodedata
from typing import (Callable, Dict, FrozenSet, Iterator, List, NamedTuple,
                    Optional, Sequence, Tuple)

QUI = os.path.dirname(os.path.abspath(__file__))
IMPRONTE = os.path.join(QUI, "impronte.json")
PREDEFINITO = os.path.join("anonimo", "ticket-anonimi.csv")
LOG = "controlli.log"
OMESSO = "[OMESSO]"
VERSIONE = 2
MAX_PAROLE = 5
MAX_FORME = 20      # residui mostrati per classe con --forme
MAX_TICKET = 15     # segnalazioni elencate per classe
COLONNE_DA_TOGLIERE = ("nome_cliente", "telefono", "email", "id_linea",
                       "id_cliente")
# Le classi, nell'ordine in cui si stampano, con la loro etichetta.
CLASSI = (
    ("nomi", "nomi di persone e di clienti, anche ragioni sociali"),
    ("familiari", "nomi di familiari"),
    ("indirizzi", "indirizzi con il numero civico"),
    ("telefoni", "numeri di telefono"),
    ("email", "indirizzi e-mail"),
    ("utenze_pppoe", "utenze PPPoE"),
    ("mac", "indirizzi MAC"),
    ("ip", "indirizzi IP"),
    ("codici_cliente", "codici cliente (CL-…)"),
    ("codici_linea", "codici di linea (LN-…)"),
    ("salute", "informazioni sulla salute (apparecchi di assistenza, età)"),
)
NOMI_CLASSI = tuple(n for n, _ in CLASSI)
# L'ordine della ricerca: prima le classi con una forma riconoscibile, poi
# quelle fatte di parole.
STRUTTURATE = ("utenze_pppoe", "email", "mac", "ip", "telefoni",
               "codici_cliente", "codici_linea")
A_PAROLE = ("indirizzi", "salute", "nomi", "familiari")
# Le classi delle parti dei nomi di persona, nell'ordine in cui si cercano.
CLASSI_PARTI = ("nomi", "familiari")

RE_PAROLA = re.compile(r"[^\W_]+")
RE_HEX64 = re.compile(r"[0-9a-f]{64}")
RE_CIFRE = re.compile(r"\+?\d(?:[ ./-]?\d)+")
RE_EMAIL = re.compile(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+")
RE_PPPOE = re.compile(
    r"(?<![A-Za-z0-9._%+-])[Ll][Nn]\d{6}@[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+")
RE_MAC = re.compile(
    r"(?<![0-9A-Fa-f])[0-9A-Fa-f]{2}(?:[:.-]?[0-9A-Fa-f]{2}){5}"
    r"(?![0-9A-Fa-f])")
RE_IP = re.compile(r"(?<![\d.])(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})"
                   r"(?!\d)")
RE_CL = re.compile(r"(?<![A-Za-z0-9])[Cc][Ll][ _-]?(\d{6})(?!\d)")
RE_LN = re.compile(r"(?<![A-Za-z0-9])[Ll][Nn][ _-]?(\d{6})(?!\d)")

Normalizza = Callable[["re.Match[str]"], str]
STRUTTURA: Dict[str, Tuple["re.Pattern[str]", Normalizza]] = {
    "utenze_pppoe": (RE_PPPOE, lambda m: m.group(0).lower()),
    "email": (RE_EMAIL, lambda m: m.group(0).lower()),
    "mac": (RE_MAC, lambda m: re.sub(r"[^0-9a-f]", "", m.group(0).lower())),
    "ip": (RE_IP, lambda m: ".".join(str(int(g)) for g in m.groups())),
    "codici_cliente": (RE_CL, lambda m: "CL-" + m.group(1)),
    "codici_linea": (RE_LN, lambda m: "LN-" + m.group(1)),
}


class Precondizione(Exception):
    """Il controllo non può girare: uscita 2."""


class Impronte(NamedTuple):
    """Il contenuto di impronte.json: il sale, le impronte dei valori per
    classe, le impronte delle parti dei nomi per nomi e familiari."""
    sale: str
    classi: Dict[str, FrozenSet[str]]
    parti: Dict[str, FrozenSet[str]]


class Residuo(NamedTuple):
    """Un dato personale rimasto: dove, e la sua forma mascherata."""
    classe: str
    ticket: str
    colonna: str
    forma: str


class Esito(NamedTuple):
    """Il risultato del controllo di un CSV."""
    righe: int
    colonne: List[str]
    da_togliere: List[str]
    residui: List[Residuo]


def piega(parola: str) -> str:
    """La parola senza accenti e in minuscolo."""
    scomposta = unicodedata.normalize("NFKD", parola)
    return "".join(c for c in scomposta
                   if not unicodedata.combining(c)).casefold()


def forma_parole(testo: str) -> str:
    """Le parole del testo, piegate e unite da uno spazio."""
    return " ".join(piega(m.group(0)) for m in RE_PAROLA.finditer(testo))


def forma(classe: str, valore: str) -> str:
    """La forma normalizzata di un valore della classe, come la usano le
    impronte. ValueError se il valore non ha la forma della classe (il
    messaggio non lo ripete)."""
    if classe in A_PAROLE:
        risultato = forma_parole(valore)
        parole = risultato.split(" ") if risultato else []
        if not 1 <= len(parole) <= MAX_PAROLE:
            raise ValueError("un valore di %s non ha da 1 a %d parole"
                             % (classe, MAX_PAROLE))
        return risultato
    if classe == "telefoni":
        cifre = re.sub(r"\D", "", valore)
        if len(cifre) < 10:
            raise ValueError("un valore di telefoni ha meno di 10 cifre")
        return cifre[-10:]
    if classe not in STRUTTURA:
        raise ValueError("classe sconosciuta: %s" % classe)
    regex, normalizza = STRUTTURA[classe]
    trovato = regex.fullmatch(valore)
    if trovato is None:
        raise ValueError("un valore di %s non ha la forma della classe"
                         % classe)
    return normalizza(trovato)


def impronta(sale: str, forma_normalizzata: str) -> str:
    """Lo SHA-256 esadecimale di sale + forma."""
    dati = (sale + forma_normalizzata).encode("utf-8")
    return hashlib.sha256(dati).hexdigest()


def maschera(testo: str) -> str:
    """La forma visibile di un residuo: lettere x o X, cifre 9."""
    uscita = []
    for c in testo:
        if c.isdigit():
            uscita.append("9")
        elif c.isalpha():
            uscita.append("X" if c.isupper() else "x")
        else:
            uscita.append(c)
    return "".join(uscita)


def carica_impronte(percorso: str = IMPRONTE) -> Impronte:
    """impronte.json, controllato; Precondizione se manca o è malformato."""
    try:
        with open(percorso, encoding="utf-8") as fh:
            dati = json.load(fh)
    except FileNotFoundError:
        raise Precondizione("manca impronte.json accanto a controlla_pii.py")
    except (OSError, UnicodeDecodeError, ValueError, RecursionError):
        raise Precondizione("impronte.json non si legge o non è un JSON "
                            "valido")
    if not isinstance(dati, dict) or dati.get("versione") != VERSIONE \
            or not isinstance(dati.get("sale"), str) or not dati["sale"] \
            or not isinstance(dati.get("classi"), dict) \
            or not isinstance(dati.get("parti"), dict):
        raise Precondizione("impronte.json malformato: servono versione %d, "
                            "sale, classi e parti" % VERSIONE)
    if sorted(dati["classi"]) != sorted(NOMI_CLASSI):
        raise Precondizione("impronte.json: le classi non sono quelle del "
                            "controllo")
    if sorted(dati["parti"]) != sorted(CLASSI_PARTI):
        raise Precondizione("impronte.json: le parti non sono quelle del "
                            "controllo (%s)" % " e ".join(CLASSI_PARTI))
    classi = {nome: _elenco(dati["classi"][nome], "nella classe %s" % nome)
              for nome in NOMI_CLASSI}
    if not any(classi.values()):
        raise Precondizione("impronte.json non contiene nessuna impronta: "
                            "il controllo non saprebbe che cosa cercare")
    parti = {nome: _elenco(dati["parti"][nome], "nelle parti di %s" % nome)
             for nome in CLASSI_PARTI}
    return Impronte(dati["sale"], classi, parti)


def _elenco(elenco: object, dove: str) -> FrozenSet[str]:
    """Un elenco di impronte di impronte.json; Precondizione se non è un
    elenco di SHA-256 esadecimali."""
    if not isinstance(elenco, list) or not all(
            isinstance(x, str) and RE_HEX64.fullmatch(x) for x in elenco):
        raise Precondizione("impronte.json: impronte malformate %s" % dove)
    return frozenset(elenco)


def leggi_csv(percorso: str) -> Tuple[List[str], List[List[str]]]:
    """(l'intestazione, le righe di dati) del CSV; Precondizione se non c'è,
    non si legge, non è UTF-8 o non è un CSV regolare. Un BOM in testa è
    tollerato; le righe vuote sono saltate."""
    try:
        with open(percorso, encoding="utf-8-sig", newline="") as fh:
            righe = [r for r in csv.reader(fh, strict=True) if r]
    except FileNotFoundError:
        raise Precondizione("%s non c'è" % percorso)
    except UnicodeDecodeError:
        raise Precondizione("%s non è un testo UTF-8" % percorso)
    except csv.Error as exc:
        raise Precondizione("%s non è un CSV leggibile (%s)" % (percorso, exc))
    except OSError as exc:
        raise Precondizione("%s non si legge (%s)" % (
            percorso, exc.strerror or type(exc).__name__))
    if not righe:
        raise Precondizione("%s è vuoto: manca anche l'intestazione"
                            % percorso)
    intestazione = righe[0]
    if len(set(intestazione)) != len(intestazione):
        raise Precondizione("%s: l'intestazione ripete una colonna"
                            % percorso)
    for numero, riga in enumerate(righe[1:], start=1):
        if len(riga) != len(intestazione):
            raise Precondizione("%s: la riga di dati %d ha %d campi invece di "
                                "%d" % (percorso, numero, len(riga),
                                        len(intestazione)))
    return intestazione, righe[1:]


def _candidati(classe: str, testo: str
               ) -> Iterator[Tuple[int, int, List[str]]]:
    """(inizio, fine, forme) dei candidati di una classe strutturata."""
    if classe == "telefoni":
        for m in RE_CIFRE.finditer(testo):
            cifre = re.sub(r"\D", "", m.group(0))
            if len(cifre) >= 10:
                yield m.start(), m.end(), [cifre[i:i + 10]
                                           for i in range(len(cifre) - 9)]
        return
    regex, normalizza = STRUTTURA[classe]
    for m in regex.finditer(testo):
        yield m.start(), m.end(), [normalizza(m)]


def _sovrapposto(inizio: int, fine: int,
                 occupati: Sequence[Tuple[int, int]]) -> bool:
    return any(inizio < b and a < fine for a, b in occupati)


def _segmenti(testo: str, occupati: Sequence[Tuple[int, int]]
              ) -> List[Tuple[int, int]]:
    """I tratti del testo fuori dai residui già trovati e dagli [OMESSO]."""
    tagli = list(occupati) + [(m.start(), m.end()) for m in
                              re.finditer(re.escape(OMESSO), testo)]
    segmenti, inizio = [], 0
    for a, b in sorted(tagli):
        if a > inizio:
            segmenti.append((inizio, a))
        inizio = max(inizio, b)
    if inizio < len(testo):
        segmenti.append((inizio, len(testo)))
    return segmenti


def _cerca_parole(testo: str, inizio: int, fine: int, impronte: Impronte
                  ) -> List[Tuple[str, int, int]]:
    """Le sequenze di 1-5 parole di un tratto che sono residui, le più
    lunghe prima; una parola conta una volta sola."""
    parole = [(m.start(), m.end(), piega(m.group(0)))
              for m in RE_PAROLA.finditer(testo, inizio, fine)]
    usate = [False] * len(parole)
    trovati = []
    for n in range(min(MAX_PAROLE, len(parole)), 0, -1):
        for i in range(len(parole) - n + 1):
            if any(usate[i:i + n]):
                continue
            chiave = impronta(impronte.sale,
                              " ".join(p[2] for p in parole[i:i + n]))
            for classe in A_PAROLE:
                if chiave in impronte.classi[classe]:
                    trovati.append((classe, parole[i][0],
                                    parole[i + n - 1][1]))
                    usate[i:i + n] = [True] * n
                    break
    return trovati


def _solo_spazi(testo: str, da: int, a: int) -> bool:
    """Fra da e a ci sono soltanto spazi (o niente)."""
    return da <= a and not testo[da:a].strip(" ")


def _nomi_a_meta(testo: str, trovati: Sequence[Tuple[str, int, int]],
                 impronte: Impronte) -> List[Tuple[str, int, int]]:
    """I nomi a metà di un testo: (classe, inizio, fine) di ogni parola con
    l'iniziale maiuscola che tocca un [OMESSO] (soltanto spazi fra le due,
    da una parte o dall'altra), fuori dai residui già trovati, la cui forma
    piegata è fra le parti dei nomi (prima nomi, poi familiari)."""
    omessi = [(m.start(), m.end())
              for m in re.finditer(re.escape(OMESSO), testo)]
    if not omessi:
        return []
    occupati = [(a, b) for _classe, a, b in trovati] + omessi
    uscita = []
    for m in RE_PAROLA.finditer(testo):
        inizio, fine = m.span()
        if not m.group(0)[0].isupper() \
                or _sovrapposto(inizio, fine, occupati) \
                or not any(_solo_spazi(testo, fine, a)
                           or _solo_spazi(testo, b, inizio)
                           for a, b in omessi):
            continue
        chiave = impronta(impronte.sale, piega(m.group(0)))
        for classe in CLASSI_PARTI:
            if chiave in impronte.parti[classe]:
                uscita.append((classe, inizio, fine))
                break
    return uscita


def cerca(testo: str, impronte: Impronte) -> List[Tuple[str, int, int]]:
    """I residui di un testo: (classe, inizio, fine), in ordine. Prima le
    classi strutturate, poi le sequenze di parole, per ultimi i nomi a
    metà accanto a un [OMESSO]."""
    trovati: List[Tuple[str, int, int]] = []
    occupati: List[Tuple[int, int]] = []
    for classe in STRUTTURATE:
        insieme = impronte.classi[classe]
        for inizio, fine, forme in _candidati(classe, testo):
            if _sovrapposto(inizio, fine, occupati):
                continue
            if any(impronta(impronte.sale, f) in insieme for f in forme):
                trovati.append((classe, inizio, fine))
                occupati.append((inizio, fine))
    for inizio, fine in _segmenti(testo, occupati):
        trovati.extend(_cerca_parole(testo, inizio, fine, impronte))
    trovati.extend(_nomi_a_meta(testo, trovati, impronte))
    return sorted(trovati, key=lambda r: (r[1], r[2]))


def esamina(percorso: str, impronte: Impronte) -> Esito:
    """Il controllo di un CSV; Precondizione se non può girare."""
    intestazione, righe = leggi_csv(percorso)
    if "id_ticket" not in intestazione:
        raise Precondizione("%s: manca la colonna id_ticket" % percorso)
    if not righe:
        raise Precondizione("%s non ha righe di dati: niente da controllare"
                            % percorso)
    i_ticket = intestazione.index("id_ticket")
    residui = []
    for numero, riga in enumerate(righe, start=1):
        ticket = riga[i_ticket] or "(riga di dati %d)" % numero
        for colonna, cella in zip(intestazione, riga):
            for classe, inizio, fine in cerca(cella, impronte):
                residui.append(Residuo(classe, ticket, colonna,
                                       maschera(cella[inizio:fine])))
    da_togliere = [c for c in COLONNE_DA_TOGLIERE if c in intestazione]
    return Esito(len(righe), intestazione, da_togliere, residui)


def _elenco_ticket(residui: Sequence[Residuo]) -> List[str]:
    """Le righe dell'elenco delle segnalazioni, ognuna una volta sola, con
    «×n» se ha più residui; oltre MAX_TICKET, quante altre."""
    conta: Dict[str, int] = {}
    for r in residui:
        conta[r.ticket] = conta.get(r.ticket, 0) + 1
    voci = ["%s×%d" % (t, n) if n > 1 else t for t, n in conta.items()]
    righe = textwrap.wrap(", ".join(voci[:MAX_TICKET]), width=56,
                          break_long_words=False, break_on_hyphens=False)
    if len(voci) > MAX_TICKET:
        righe.append("… e altre %d segnalazioni" % (len(voci) - MAX_TICKET))
    return righe


def stampa(nome: str, esito: Esito, forme: bool) -> int:
    """Il rapporto su STDOUT, senza valori; restituisce l'uscita (la riga
    finale con l'uscita la stampa main, dopo il registro)."""
    print("controlla_pii: %s, %d righe, %d colonne" % (
        nome, esito.righe, len(esito.colonne)))
    per_classe: Dict[str, List[Residuo]] = {}
    for r in esito.residui:
        per_classe.setdefault(r.classe, []).append(r)
    for classe, etichetta in CLASSI:
        trovati = per_classe.get(classe, [])
        print("  %-15s %4d  %s" % (classe, len(trovati), etichetta))
        if not trovati:
            continue
        for riga in _elenco_ticket(trovati):
            print("  %-15s       %s" % ("", riga))
        if forme:
            for r in trovati[:MAX_FORME]:
                print("        %s  %s  %s" % (r.ticket, r.colonna, r.forma))
            if len(trovati) > MAX_FORME:
                print("        … altri %d" % (len(trovati) - MAX_FORME))
    if esito.da_togliere:
        print("Colonne da togliere ancora nell'intestazione: %s." % ", ".join(
            esito.da_togliere))
    if esito.residui:
        segnalazioni = len({r.ticket for r in esito.residui})
        print("Residui: %d in %d segnalazioni%s." % (
            len(esito.residui), segnalazioni, "" if forme else
            " (con --forme anche la forma di ogni residuo, mai il valore)"))
    return 1 if esito.residui or esito.da_togliere else 0


def motivo(uscita: int, esito: Optional[Esito]) -> str:
    """Il perché dell'uscita, per la riga finale."""
    if uscita == 0:
        return "nessun dato personale rimasto"
    if uscita == 1 and esito is not None:
        if esito.residui and esito.da_togliere:
            return "restano dati personali e colonne da togliere: vedi sopra"
        if esito.residui:
            return "restano dati personali: vedi sopra"
        return "restano colonne da togliere: vedi sopra"
    return "il controllo non ha potuto girare: vedi sopra"


def scrivi_log(percorso_csv: str, uscita: int, residui: str) -> None:
    """Una riga in controlli.log, nella cartella del file controllato."""
    cartella = os.path.dirname(os.path.abspath(percorso_csv))
    os.makedirs(cartella, exist_ok=True)
    ora = dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    with open(os.path.join(cartella, LOG), "a", encoding="utf-8",
              newline="\n") as fh:
        fh.write("%s\t%d\t%s\n" % (ora, uscita, residui))


def argomenti(argv: Sequence[str]) -> Tuple[Optional[str], bool, bool]:
    """(il file o None, --forme, -h); ValueError su un argomento sbagliato."""
    file, forme, aiuto = None, False, False
    for a in argv:
        if a in ("-h", "--help"):
            aiuto = True
        elif a == "--forme":
            forme = True
        elif a.startswith("-"):
            raise ValueError("opzione sconosciuta: %s" % a)
        elif file is None:
            file = a
        else:
            raise ValueError("un file solo")
    return file, forme, aiuto


def errore(messaggio: str) -> None:
    """Una diagnostica su STDERR, dopo quello che STDOUT ha già: così la
    riga finale resta l'ultima anche con le due uscite insieme."""
    sys.stdout.flush()
    sys.stderr.write("controlla_pii: %s\n" % messaggio)
    sys.stderr.flush()


def finale(uscita: int, perche: str) -> int:
    """La riga finale, l'ultima dell'uscita: l'esito, da leggere al posto
    di $?. Restituisce l'uscita."""
    print("uscita: %d (%s)" % (uscita, perche))
    sys.stdout.flush()
    return uscita


def main(argv: Sequence[str]) -> int:
    try:
        file, forme, aiuto = argomenti(argv)
    except ValueError as exc:
        errore("%s\nUso: python3 controlla_pii.py [file] [--forme]" % exc)
        return finale(2, "argomenti non validi: vedi sopra")
    if aiuto:
        print((__doc__ or "").strip())
        return 0
    percorso = file if file is not None else os.path.join(QUI, PREDEFINITO)
    nome = file if file is not None else PREDEFINITO
    uscita, residui, esito = 2, "-", None
    try:
        esito = esamina(percorso, carica_impronte())
        uscita = stampa(nome, esito, forme)
        residui = str(len(esito.residui))
    except Precondizione as exc:
        errore(str(exc))
    except Exception as exc:  # l'ultima rete: un messaggio, mai un traceback
        errore("errore inatteso (%s)" % type(exc).__name__)
    try:
        scrivi_log(percorso, uscita, residui)
    except OSError as exc:
        errore("non riesco a scrivere %s nella cartella di %s (%s)" % (
            LOG, nome, exc.strerror or type(exc).__name__))
        return finale(2, "il registro %s non si scrive: vedi sopra" % LOG)
    return finale(uscita, motivo(uscita, esito))


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
