#!/usr/bin/env python3
"""Controlla i materiali del Modulo 9: il questionario per Moodle e l'elenco.

Il questionario: la forma che l'importazione del modulo Feedback di Moodle
4.5 si aspetta, letta nei suoi sorgenti (mod/feedback/import.php): il
prologo che feedback_check_xml_utf8 accetta, in UTF-8; la radice FEEDBACK con
VERSION 200701 e il blocco ITEMS; per ogni ITEM i campi che l'importazione
legge, un ITEMID unico, DEPENDITEM 0 o un ITEMID del file; le presentazioni
dalle classi degli elementi, senza i separatori di Moodle nel testo di
un'opzione; un voto facoltativo che non entra vuoto nelle medie (opzione i).
Accetta soltanto le forme che questo questionario usa, non tutte quelle che
Moodle conosce. Non importa il file in un Moodle: quella prova la fa il
docente sulla sua piattaforma (importare_il_questionario.md).

L'elenco delle risorse: la data della verifica in grassetto, con un mese
vero; almeno un link Markdown; ogni indirizzo in https. Le parole interne
della pianificazione non le cerca qui: le cerca la spazzata del corso.

Uso:     python3 -B -I controlla_materiali.py xml <file>
         python3 -B -I controlla_materiali.py risorse <file>
Uscita:  0 = tutto a posto · 1 = almeno una segnalazione
         2 = uso sbagliato, file illeggibile o XML che non si legge
"""

from __future__ import annotations

import re
import sys
import xml.etree.ElementTree as ET

VERSIONE_MOODLE = "200701"
CAMPI = ("ITEMID", "ITEMTEXT", "ITEMLABEL", "PRESENTATION", "OPTIONS",
         "DEPENDITEM", "DEPENDVALUE")
TIPI = ("multichoicerated", "multichoice", "textarea", "label")
MASSIMO_OPZIONI = 10  # FEEDBACK_MULTICHOICERATED_MAXCOUNT
# Il modello di feedback_check_xml_utf8 (mod/feedback/import.php).
RE_PROLOGO = re.compile(rb'^<\?xml.+(encoding="([a-z0-9-]*)").+\?>',
                        re.I | re.S)
OPZIONE = r"[^|#<>]+"  # né | né i separatori ####, >>>>>, <<<<<
RE_VOTO = re.compile(
    rf"^r>>>>>\d+####{OPZIONE}(\|\d+####{OPZIONE})*<<<<<1$")
RE_SCELTA = re.compile(rf"^r>>>>>{OPZIONE}(\|{OPZIONE})*<<<<<1$")
RE_TESTO = re.compile(r"^\d+\|\d+$")
RE_ETICHETTA = re.compile(r"^q\d\d_[a-z0-9_]+$")

MESI = ("gennaio|febbraio|marzo|aprile|maggio|giugno|luglio|agosto|"
        "settembre|ottobre|novembre|dicembre")
RE_DATA = re.compile(rf"\*\*\d{{1,2}} (?:{MESI}) \d{{4}}\*\*")
RE_INDIRIZZO = re.compile(r"\b([A-Za-z][A-Za-z0-9+.-]*)://[^\s)>]*")
RE_LINK_MD = re.compile(r"\]\(https://")


def _testi(item: ET.Element) -> dict[str, str]:
    """I campi di un ITEM, ripuliti come fa import.php."""
    testi = {}
    for campo in CAMPI:
        nodo = item.find(campo)
        testi[campo] = ("" if nodo is None or nodo.text is None
                        else nodo.text.strip())
    return testi


def _regole_presentazione(tipo: str, presenta: str) -> list[str]:
    """Le regole della presentazione per un tipo di elemento."""
    if tipo == "multichoicerated":
        if not RE_VOTO.match(presenta):
            return ["presentazione con voto malformata"]
        if presenta.count("####") > MASSIMO_OPZIONI:
            return ["troppe opzioni"]
    elif tipo == "multichoice" and not RE_SCELTA.match(presenta):
        return ["presentazione a scelta malformata"]
    elif tipo == "textarea" and not RE_TESTO.match(presenta):
        return ["presentazione di testo malformata"]
    elif tipo == "label" and not presenta:
        return ["etichetta senza testo"]
    return []


def _regole_domanda(tipo: str, richiesta: str,
                    valori: dict[str, str]) -> list[str]:
    """Le regole del testo, dell'etichetta e delle opzioni di una domanda."""
    if tipo == "label":
        return []
    problemi = []
    if not valori["ITEMTEXT"]:
        problemi.append("domanda senza testo")
    if not RE_ETICHETTA.match(valori["ITEMLABEL"]):
        problemi.append("etichetta di analisi malformata")
    if (tipo == "multichoicerated" and richiesta == "0"
            and "i" not in valori["OPTIONS"]):
        problemi.append("voto facoltativo senza l'opzione i: "
                        "i vuoti entrerebbero nelle medie")
    return problemi


def controlla_item(item: ET.Element, gia_visti: frozenset[str],
                   identita_del_file: frozenset[str]) -> list[str]:
    """Le segnalazioni di un ITEM; non cambia gli insiemi che riceve."""
    tipo = item.get("TYPE", "")
    if tipo not in TIPI:
        return [f"tipo sconosciuto: {tipo!r}"]
    problemi = []
    richiesta = item.get("REQUIRED", "")
    if richiesta not in ("0", "1"):
        problemi.append("REQUIRED deve essere 0 o 1")
    mancanti = [c for c in CAMPI if item.find(c) is None]
    if mancanti:
        return [f"campi mancanti: {', '.join(mancanti)}"] + problemi
    valori = _testi(item)
    identita = valori["ITEMID"]
    if not identita.isdigit() or identita in gia_visti:
        problemi.append(f"ITEMID non valido o ripetuto: {identita!r}")
    dipende = valori["DEPENDITEM"]
    if dipende != "0" and dipende not in identita_del_file:
        problemi.append(f"DEPENDITEM senza l'ITEM da cui dipende: {dipende!r}")
    return (problemi + _regole_presentazione(tipo, valori["PRESENTATION"])
            + _regole_domanda(tipo, richiesta, valori))


def _problemi_prologo(dati: bytes) -> list[str]:
    """Il prologo come lo vuole feedback_check_xml_utf8, in UTF-8: il suo
    modello comincia dal primo byte, e un BOM basta a fallirlo."""
    trovato = RE_PROLOGO.match(dati)
    if not trovato:
        return ["prologo che Moodle non riconosce: "
                '<?xml version="1.0" encoding="UTF-8" ?>']
    if trovato.group(2).lower() != b"utf-8":
        return ["la codifica del prologo deve essere UTF-8"]
    return []


def _segnalazioni_radice(radice: ET.Element) -> tuple[list[str], int, int]:
    """Le segnalazioni del file letto, il numero di voci e di domande."""
    segnalazioni = []
    if radice.tag != "FEEDBACK":
        segnalazioni.append("la radice non è FEEDBACK")
    if radice.get("VERSION") != VERSIONE_MOODLE:
        segnalazioni.append(f"VERSION deve essere {VERSIONE_MOODLE}")
    blocco = radice.find("ITEMS")
    items = [] if blocco is None else blocco.findall("ITEM")
    if not items:
        segnalazioni.append("nessun ITEM")
    identita_del_file = frozenset(_testi(i)["ITEMID"] for i in items)
    domande = sum(1 for i in items if i.get("TYPE") != "label")
    gia_visti: frozenset[str] = frozenset()
    for posizione, item in enumerate(items, start=1):
        for problema in controlla_item(item, gia_visti, identita_del_file):
            segnalazioni.append(f"ITEM {posizione}: {problema}")
        gia_visti = gia_visti | {_testi(item)["ITEMID"]}
    if items and not domande:
        segnalazioni.append("nessuna domanda")
    return segnalazioni, len(items), domande


def controlla_xml(percorso: str) -> int:
    """Controlla il file XML. Restituisce il codice d'uscita."""
    try:
        with open(percorso, "rb") as ingresso:
            dati = ingresso.read()
    except OSError as problema:
        print(f"errore: {problema}", file=sys.stderr)
        return 2
    segnalazioni = _problemi_prologo(dati)
    voci = domande = 0
    if not segnalazioni:
        try:
            radice = ET.fromstring(dati)
        except (ET.ParseError, LookupError, ValueError) as problema:
            print(f"errore: XML che non si legge: {problema}",
                  file=sys.stderr)
            return 2
        segnalazioni, voci, domande = _segnalazioni_radice(radice)
    for riga in segnalazioni:
        print(riga)
    if segnalazioni:
        return 1
    print(f"questionario coerente: {voci} voci, {domande} domande")
    return 0


def controlla_risorse(percorso: str) -> int:
    """Controlla l'elenco delle risorse. Restituisce il codice d'uscita."""
    try:
        with open(percorso, encoding="utf-8") as ingresso:
            testo = ingresso.read()
    except (OSError, UnicodeDecodeError) as problema:
        print(f"errore: {problema}", file=sys.stderr)
        return 2
    segnalazioni = []
    if not RE_DATA.search(testo):
        segnalazioni.append("manca la data della verifica in grassetto")
    for trovato in RE_INDIRIZZO.finditer(testo):
        if trovato.group(1).lower() != "https":
            segnalazioni.append(f"link che non è https: {trovato.group(0)}")
    if not RE_LINK_MD.search(testo):
        segnalazioni.append("nessun link Markdown in https")
    for riga in segnalazioni:
        print(riga)
    if segnalazioni:
        return 1
    print("elenco coerente")
    return 0


def main(argomenti: list[str]) -> int:
    """Il punto d'ingresso."""
    if len(argomenti) != 2 or argomenti[0] not in ("xml", "risorse"):
        print(__doc__, file=sys.stderr)
        return 2
    if argomenti[0] == "xml":
        return controlla_xml(argomenti[1])
    return controlla_risorse(argomenti[1])


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
