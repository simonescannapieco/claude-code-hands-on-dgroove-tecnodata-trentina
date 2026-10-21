#!/usr/bin/env python3
"""costruisci_impronte.py -- le impronte dei dati personali della settimana di
ticket, per il docente.

Elenca i dati personali che il generatore del progetto
(progetti/assistenza-clienti/genera.py e generatore/, letti e mai cambiati)
ha messo apposta nel CSV della settimana, prendendoli dai dati del generatore
stesso, non dal testo:
  - le colonne di ogni riga: nome_cliente (nomi: la persona; per
    un'organizzazione la ragione sociale senza la forma giuridica e, per una
    ditta «… di Nome Cognome», anche la persona), telefono, email,
    id_cliente, id_linea;
  - i ticket generati: il generatore gira di nuovo con il suo seme, e di
    ogni testo si registrano i valori dei segnaposto (ticket.segnaposto,
    legati al ticket da ticket.assembla). Sono dati personali quelli che
    compaiono nel testo: {nome} e {referente} (nomi), {figlio}, {moglie},
    {marito} (familiari), {telefono}, {email}, «{via} {civico}» e
    «{via_nuova} {civico_nuovo}» (indirizzi; {via} da sola se il testo non
    ha il civico), {id_cliente}, {id_linea}, {pppoe}, {ip}, {mac}; la salute:
    la parola del telesoccorso (testi.DETTAGLI);
  - i ticket fissi della storia (testi.TICKET_FISSI, scritti a mano): i
    valori del loro cliente, i registri del generatore (ALTRI_TELEFONI,
    ALTRE_EMAIL, NOMI_RISERVATI: un nome riservato che non è il cliente né
    il suo referente è un familiare), le forme del canone (canone.py:
    telefoni, e-mail e utenze PPPoE, MAC, IPv4 di documentazione), le vie
    del generatore (testi.VIE e quelle dei clienti) seguite dal civico, la
    salute (telesoccorso, l'età «NN anni»).
Le parti dei nomi: dei dati di tipo persona delle classi nomi e familiari
(nome_cliente dei privati, {nome} e {referente} dei ticket generati quando
sono persone, la persona di una ditta «… di Nome Cognome», le persone dei
ticket fissi e di NOMI_RISERVATI), ogni parola di almeno tre lettere,
piegata come la piega il controllo, per classe; le ragioni sociali non ne
danno, perché le loro parole sono nomi comuni.
Prima controlla che il generatore, rieseguito così, riproduca byte per byte
il CSV del progetto; poi che il controllo dell'esercizio
(esercizio/controlla_pii.py, con le stesse forme normalizzate) trovi sul CSV
grezzo ogni dato elencato, al suo posto, e nient'altro (sul grezzo non c'è
nessun [OMESSO], e la regola dei nomi a metà non scatta); poi, su copie dei
testi grezzi (oggetto e descrizione) in cui ogni nome di persona piantato
ha l'ultima parola, oppure la prima, al posto di un [OMESSO], che il
controllo trovi in ogni posto un nome a metà della classe a cui lo
attribuisce (prima nomi, poi familiari) e nient'altro; e dove il nome
intero è al posto di un [OMESSO], nessun nome a metà. Stampa per classe le
impronte, le occorrenze nei testi (oggetto e descrizione) e le righe, accanto
ai numeri della verità del progetto (progetti/assistenza-clienti/_docente/
README.md), come dato, e i conteggi delle prove sui nomi a metà. Scrive
esercizio/impronte.json, versione 2 (sale fisso, impronte e parti ordinate:
rieseguirlo dà gli stessi byte), e copia in esercizio/dati/ il CSV e il
dizionario delle colonne del progetto. Non stampa mai un valore, salvo
--debug, e allora solo su STDERR.

Uso:    python3 -B _docente/costruisci_impronte.py [--controlla] [--debug]
          --controlla  costruisce in una cartella temporanea e confronta con
                       esercizio/ byte per byte, senza scrivere nell'elemento
          --debug      i valori in chiaro, su STDERR (solo per il docente)
Env:    PN_HANDSON_ROOT  il repository (default: cinque cartelle sopra questa)
Uscita: 0 fatto (con --controlla: identici) · 1 il controllo non trova un
        dato elencato o ne trova uno in più, o non trova un nome a metà o
        ne trova uno in più; con --controlla, un file diverso · 2
        precondizione (il progetto o il controllo mancano, il generatore
        non riproduce il CSV, un valore senza la forma della sua classe)
"""
from __future__ import annotations

import csv
import importlib.util
import io
import json
import os
import re
import shutil
import sys
import tempfile
from pathlib import Path
from types import ModuleType
from typing import Dict, List, NamedTuple, Optional, Sequence, Set, Tuple

SELF = Path(__file__).resolve()
ELEMENTO = SELF.parents[1]
ESERCIZIO = ELEMENTO / "esercizio"
RADICE = Path(os.environ.get("PN_HANDSON_ROOT") or SELF.parents[5]).resolve()
PROGETTO = RADICE / "progetti" / "assistenza-clienti"
FILE_CSV = Path("dati") / "ticket-settimana.csv"
FILE_DIZIONARIO = Path("dati") / "README.md"
FILE_IMPRONTE = Path("impronte.json")
SALE = "69b281bad4d432d581c8e24fabb26105"
# La parola che porta l'informazione sulla salute nei testi del generatore
# (la frase del telesoccorso di testi.DETTAGLI e il ticket fisso del
# telesoccorso), e l'età scritta in un ticket fisso.
SALUTE = ("telesoccorso",)
ETA = re.compile(r"(?<!\w)\d{1,3} anni(?!\w)")
# Le forme giuridiche di clienti.nome_organizzazione, come parole piegate;
# «di» separa la ditta dalla persona.
FORME_GIURIDICHE = (("s", "r", "l"), ("s", "n", "c"), ("s", "a", "s"))
PARENTELE = ("figlio", "moglie", "marito")
# Le parti dei nomi: le parole con almeno tante lettere.
MIN_LETTERE = 3
# Le colonne di testo, e le tre copie dei testi grezzi delle prove sui nomi
# a metà: che cosa va al posto di un [OMESSO] in ogni nome di persona.
TESTI = ("descrizione", "oggetto")
OMESSO = "[OMESSO]"
VARIANTI = (
    ("ultima", "Con l'ultima parola di ogni nome di persona al posto di un "
               "[OMESSO]"),
    ("prima", "Con la prima parola di ogni nome di persona al posto di un "
              "[OMESSO]"),
    ("intero", "Con il nome intero al posto di un [OMESSO]"))
# La verità del progetto (progetti/assistenza-clienti/_docente/README.md,
# «Che cosa trova una profilazione del CSV»): dati personali nei testi.
VERITA = (("telefoni", ("telefoni",), 47, "47 telefoni"),
          ("email + utenze_pppoe", ("email", "utenze_pppoe"), 12, "12 e-mail"),
          ("indirizzi", ("indirizzi",), 7, "7 indirizzi"),
          ("familiari", ("familiari",), 5, "5 familiari con nome e cognome"),
          ("mac", ("mac",), 6, "6 indirizzi MAC"),
          ("ip", ("ip",), 10, "10 indirizzi IP"))
VERITA_SALUTE = ("TK-2026-04286", "TK-2026-04312", "TK-2026-04345",
                 "TK-2026-04553")


class Precondizione(Exception):
    """Le impronte non si possono costruire: uscita 2."""


class Piantato(NamedTuple):
    """Un dato personale messo dal generatore: dove sta e quante volte."""
    classe: str
    valore: str
    tipo: str        # persona, organizzazione o "" (nomi e familiari)
    ticket: str
    colonna: str
    volte: int


def carica(nome: str, percorso: Path) -> ModuleType:
    """Un modulo Python da un file; Precondizione se manca o non si carica."""
    if not percorso.is_file():
        raise Precondizione("manca %s" % percorso)
    try:
        spec = importlib.util.spec_from_file_location(nome, str(percorso))
        if spec is None or spec.loader is None:
            raise ImportError("nessun caricatore")
        modulo = importlib.util.module_from_spec(spec)
        sys.modules[nome] = modulo
        spec.loader.exec_module(modulo)  # type: ignore[union-attr]
    except (ImportError, OSError, SyntaxError) as exc:
        raise Precondizione("%s non si carica (%s)" % (percorso, exc))
    return modulo


def esegui_generatore(genera: ModuleType
                      ) -> Tuple[str, List[object], Dict[Tuple[object, str],
                                                         Dict[str, str]]]:
    """(il CSV, i ticket in ordine, i valori dei segnaposto per ticket
    generato): il generatore rieseguito con il suo seme, con
    ticket.segnaposto e ticket.assembla avvolti per registrare i valori."""
    from generatore import settimana  # type: ignore[import-not-found]
    from generatore import ticket as modulo  # type: ignore[import-not-found]
    originali = (modulo.segnaposto, modulo.assembla)
    in_attesa: List[Optional[Dict[str, str]]] = [None]
    valori: Dict[Tuple[object, str], Dict[str, str]] = {}

    def segnaposto(*args, **kwargs):  # type: ignore[no-untyped-def]
        v = originali[0](*args, **kwargs)
        in_attesa[0] = v
        return v

    def assembla(*args, **kwargs):  # type: ignore[no-untyped-def]
        t = originali[1](*args, **kwargs)
        chiave = (t.aperto, t.descrizione)
        if chiave in valori:
            raise Precondizione("due ticket generati con la stessa apertura "
                                "e lo stesso testo")
        # Un testo senza segnaposto (i riavvii dopo il guasto di Pergine):
        # nessun valore.
        valori[chiave] = in_attesa[0] or {}
        in_attesa[0] = None
        return t

    modulo.segnaposto, modulo.assembla = segnaposto, assembla
    try:
        ticket = modulo.tutti_i_ticket(settimana.Caso(settimana.SEME))
    finally:
        modulo.segnaposto, modulo.assembla = originali
    return genera.testo_csv(ticket), ticket, valori


def presente(valore: str, testo: str) -> int:
    """Quante volte il valore compare nel testo come parole intere."""
    if not valore:
        return 0
    return len(re.findall(r"(?<!\w)%s(?!\w)" % re.escape(valore), testo))


def dal_generato(numero: str, t, v: Dict[str, str]) -> List[Piantato]:
    """I dati personali di un ticket generato, dai valori dei segnaposto
    (un dizionario vuoto per un testo senza segnaposto)."""
    persona = "persona" if t.cliente.tipo == "privato" else "organizzazione"
    voci: List[Tuple[str, str, str]] = []
    completi: List[str] = []
    if v:
        voci += [("nomi", v["nome"], persona),
                 ("nomi", v["referente"], "persona")]
        voci += [("familiari", v[k], "persona") for k in PARENTELE]
        voci += [("telefoni", v["telefono"], ""), ("email", v["email"], ""),
                 ("codici_cliente", v["id_cliente"], ""),
                 ("codici_linea", v["id_linea"], ""),
                 ("ip", v["ip"], ""), ("mac", v["mac"], "")]
        if v["id_linea"]:
            voci.append(("utenze_pppoe", v["pppoe"], ""))
        completi = ["%s %s" % (v["via"], v["civico"]),
                    "%s %s" % (v["via_nuova"], v["civico_nuovo"])]
        voci += [("indirizzi", c, "") for c in completi]
    uscita = []
    for colonna, testo in (("descrizione", t.descrizione),
                           ("oggetto", t.oggetto)):
        conteggi = [(classe, valore, tipo, presente(valore, testo))
                    for classe, valore, tipo in voci]
        conteggi += [("salute", s, "", len(re.findall(re.escape(s), testo,
                                                      re.I)))
                     for s in SALUTE]
        # La via del cliente da sola (un testo senza il civico), fuori dagli
        # indirizzi completi: mai la via nuova, che è scelta a caso.
        resto = testo
        for c in completi:
            resto = resto.replace(c, " ")
        if v:
            conteggi.append(("indirizzi", v["via"], "",
                             presente(v["via"], resto)))
        for classe, valore, tipo, volte in conteggi:
            if volte:
                uscita.append(Piantato(classe, valore, tipo, numero, colonna,
                                       volte))
    return uscita


def dal_fisso(numero: str, f: Dict[str, object], c: Dict[str, object],
              testi: ModuleType, canone: ModuleType) -> List[Piantato]:
    """I dati personali di un ticket fisso della storia, dal suo cliente,
    dai registri e dalle forme del canone."""
    persona = "persona" if c["tipo"] == "privato" else "organizzazione"
    propri = {str(c["nome"]), str(c["referente"])}
    voci = [("nomi", str(c["nome"]), persona),
            ("nomi", str(c["referente"]), "persona"),
            ("telefoni", str(c["telefono"]), ""),
            ("email", str(c["email"]), ""),
            ("indirizzi", "%s %s" % (c["via"], c["civico"]), ""),
            ("codici_cliente", str(c["id_cliente"]), ""),
            ("codici_linea", str(c["id_linea"]), "")]
    if c["id_linea"]:
        voci.append(("utenze_pppoe", "%s@%s" % (
            str(c["id_linea"]).replace("-", "").lower(),
            canone.DOMINIO_PPPOE), ""))
    voci += [("telefoni", n, "") for n in testi.ALTRI_TELEFONI]
    voci += [("email", e, "") for e in testi.ALTRE_EMAIL]
    voci += [("nomi" if n in propri else "familiari", n, "persona")
             for n in sorted(testi.NOMI_RISERVATI)]
    vie = sorted(set(testi.VIE) | {str(x["via"]) for x in
                                   testi.CLIENTI_FISSI})
    uscita = []
    for colonna in ("descrizione", "oggetto"):
        testo = str(f[colonna])
        lista = list(voci)
        lista += [("telefoni", m.group(0), "")
                  for m in canone._RE_TEL_CANONICO.finditer(testo)]
        for m in canone._RE_EMAIL.finditer(testo):
            pppoe = m.group(2).lower() == canone.DOMINIO_PPPOE
            lista.append(("utenze_pppoe" if pppoe else "email", m.group(0),
                          ""))
        lista += [("mac", m.group(0), "") for m in re.finditer(
            r"00:00:5e:00:53:[0-9a-f]{2}", testo, re.I)]
        for m in canone._RE_IPV4.finditer(testo):
            if tuple(int(g) for g in m.groups())[:3] in \
                    canone._PREFISSI_RFC5737:
                lista.append(("ip", m.group(0), ""))
        for via in vie:
            lista += [("indirizzi", m.group(0), "") for m in re.finditer(
                r"%s \d+(?!\w)" % re.escape(via), testo)]
        lista += [("salute", m.group(0), "") for m in ETA.finditer(testo)]
        lista += [("salute", s, "") for s in SALUTE]
        visti: Set[Tuple[str, str]] = set()
        for classe, valore, tipo in lista:
            if (classe, valore) in visti:
                continue
            visti.add((classe, valore))
            volte = presente(valore, testo) if classe != "salute" else \
                len(re.findall(re.escape(valore), testo, re.I))
            if volte:
                uscita.append(Piantato(classe, valore, tipo, numero, colonna,
                                       volte))
    return uscita


def dalle_colonne(testo_csv: str) -> List[Piantato]:
    """I dati personali delle colonne che il file anonimo toglie."""
    uscita = []
    for riga in csv.DictReader(io.StringIO(testo_csv)):
        ticket = riga["id_ticket"]
        persona = "persona" if riga["tipo_cliente"] == "privato" \
            else "organizzazione"
        for colonna, classe, tipo in (
                ("nome_cliente", "nomi", persona), ("telefono", "telefoni", ""),
                ("email", "email", ""), ("id_cliente", "codici_cliente", ""),
                ("id_linea", "codici_linea", "")):
            if riga[colonna]:
                uscita.append(Piantato(classe, riga[colonna], tipo, ticket,
                                       colonna, 1))
    return uscita


def forme(cp: ModuleType, p: Piantato) -> List[Tuple[str, str]]:
    """Le (classe, forma normalizzata) di un dato: per un'organizzazione la
    ragione sociale senza forma giuridica e, per una ditta, la persona."""
    if p.tipo != "organizzazione":
        return [(p.classe, cp.forma(p.classe, p.valore))]
    parole = cp.forma_parole(p.valore).split(" ")
    for giuridica in FORME_GIURIDICHE:
        if len(parole) > len(giuridica) and \
                tuple(parole[-len(giuridica):]) == giuridica:
            parole = parole[:-len(giuridica)]
            break
    if "di" in parole[1:]:
        i = parole.index("di", 1)
        return [(p.classe, cp.forma(p.classe, " ".join(parole[:i]))),
                ("nomi", cp.forma("nomi", " ".join(parole[i + 1:])))]
    return [(p.classe, cp.forma(p.classe, " ".join(parole)))]


def elenca(genera: ModuleType, testo_csv: str, ticket: Sequence[object],
           valori: Dict[Tuple[object, str], Dict[str, str]]
           ) -> List[Piantato]:
    """Tutti i dati personali messi dal generatore, colonne e testi."""
    from generatore import canone, testi  # type: ignore[import-not-found]
    clienti = {str(c["id_cliente"] or c["nome"]): c
               for c in testi.CLIENTI_FISSI}
    fissi = {(str(f["aperto"]), str(f["descrizione"])): f
             for f in testi.TICKET_FISSI}
    piantati = dalle_colonne(testo_csv)
    generati = 0
    for indice, t in enumerate(ticket):
        numero = "TK-2026-%05d" % (genera.PRIMO_TICKET + indice)
        f = fissi.get((t.aperto.isoformat(), t.descrizione))
        v = valori.get((t.aperto, t.descrizione))
        if f is None and v is not None:
            generati += 1
            piantati += dal_generato(numero, t, v)
            continue
        if f is None or v is not None:
            raise Precondizione("%s: un ticket né generato né fisso, o "
                                "tutti e due" % numero)
        piantati += dal_fisso(numero, f, clienti[str(f["cliente"])], testi,
                              canone)
    if generati + len(fissi) != len(ticket):
        raise Precondizione("i ticket fissi e quelli generati non tornano")
    return piantati


def impronte_di(cp: ModuleType, piantati: Sequence[Piantato]
                ) -> Dict[str, Set[str]]:
    """Le impronte per classe; Precondizione su un valore senza forma."""
    classi: Dict[str, Set[str]] = {c: set() for c in cp.NOMI_CLASSI}
    for p in piantati:
        try:
            for classe, f in forme(cp, p):
                classi[classe].add(cp.impronta(SALE, f))
        except ValueError as exc:
            raise Precondizione("%s, %s: %s" % (p.ticket, p.colonna, exc))
    return classi


def persona_grezza(cp: ModuleType, p: Piantato) -> Optional[str]:
    """Il nome di persona di un dato, così com'è scritto: il valore di una
    persona; di una ditta «… di Nome Cognome» la persona, senza la forma
    giuridica; None per un'altra organizzazione o un dato d'altro tipo."""
    if p.tipo == "persona":
        return p.valore
    if p.tipo != "organizzazione":
        return None
    parole = list(cp.RE_PAROLA.finditer(p.valore))
    piegate = [cp.piega(m.group(0)) for m in parole]
    for giuridica in FORME_GIURIDICHE:
        n = len(giuridica)
        if len(piegate) > n and tuple(piegate[-n:]) == giuridica:
            parole, piegate = parole[:-n], piegate[:-n]
            break
    if "di" not in piegate[1:-1]:
        return None
    i = piegate.index("di", 1)
    return p.valore[parole[i + 1].start():parole[-1].end()]


def parti_di(cp: ModuleType, piantati: Sequence[Piantato]
             ) -> Dict[str, Set[str]]:
    """Le impronte delle parti dei nomi, per classe (nomi, familiari): ogni
    parola di almeno MIN_LETTERE lettere dei nomi di persona, piegata."""
    parti: Dict[str, Set[str]] = {c: set() for c in cp.CLASSI_PARTI}
    for p in piantati:
        nome = persona_grezza(cp, p) if p.classe in parti else None
        for m in cp.RE_PAROLA.finditer(nome or ""):
            if sum(1 for c in m.group(0) if c.isalpha()) >= MIN_LETTERE:
                parti[p.classe].add(cp.impronta(SALE, cp.piega(m.group(0))))
    return parti


def attribuita(cp: ModuleType, classi: Dict[str, Set[str]], classe: str,
               f: str) -> str:
    """La classe a cui il controllo attribuisce una forma: la prima, nel suo
    ordine di ricerca, che ne ha l'impronta."""
    chiave = cp.impronta(SALE, f)
    for c in cp.STRUTTURATE + cp.A_PAROLE:
        if chiave in classi[c]:
            return c
    return classe


def verifica_controllo(cp: ModuleType, impronte: object,
                       classi: Dict[str, Set[str]],
                       piantati: Sequence[Piantato], csv_grezzo: Path,
                       debug: bool) -> Tuple[int, int, int]:
    """Il controllo sul CSV grezzo: (posizioni attese, mancanti, in più)."""
    trovate = {(r.classe, r.ticket, r.colonna)
               for r in cp.esamina(str(csv_grezzo), impronte).residui}
    attese = {(attribuita(cp, classi, cl, f), p.ticket, p.colonna)
              for p in piantati for cl, f in forme(cp, p)}
    mancanti, in_piu = attese - trovate, trovate - attese
    if debug:
        for etichetta, insieme in (("non trovato", mancanti),
                                   ("trovato in più", in_piu)):
            for classe, t, colonna in sorted(insieme):
                valori = sorted({p.valore for p in piantati if p.ticket == t
                                 and p.colonna == colonna})
                sys.stderr.write("DEBUG %s: %s %s %s %s\n" % (
                    etichetta, classe, t, colonna, valori))
    return len(attese), len(mancanti), len(in_piu)


def nomi_nei_testi(cp: ModuleType, piantati: Sequence[Piantato]
                   ) -> Dict[Tuple[str, str], List[str]]:
    """I nomi di persona piantati in oggetto e descrizione, così come sono
    scritti, per (segnalazione, colonna)."""
    nomi: Dict[Tuple[str, str], List[str]] = {}
    for p in piantati:
        nome = persona_grezza(cp, p) if p.classe in cp.CLASSI_PARTI \
            and p.colonna in TESTI else None
        if nome:
            nomi.setdefault((p.ticket, p.colonna), []).append(nome)
    return nomi


def occorrenze(testo: str, nomi: Sequence[str]) -> List[Tuple[int, int]]:
    """Dove stanno i nomi nel testo, come parole intere e senza
    sovrapporsi, i più lunghi per primi; in ordine."""
    trovate: List[Tuple[int, int]] = []
    for nome in sorted(set(nomi), key=len, reverse=True):
        for m in re.finditer(r"(?<!\w)%s(?!\w)" % re.escape(nome), testo):
            if not any(m.start() < b and a < m.end() for a, b in trovate):
                trovate.append(m.span())
    return sorted(trovate)


def variante(cp: ModuleType, testo: str, posti: Sequence[Tuple[int, int]],
             come: str) -> Tuple[str, List[Tuple[int, int]]]:
    """Il testo con ogni nome dei posti al posto di un [OMESSO] come dice
    come (l'ultima parola, la prima, il nome intero), e dove stanno, nel
    testo nuovo, le parole rimaste accanto all'[OMESSO]."""
    pezzi: List[str] = []
    tenute: List[Tuple[int, int]] = []
    lunghezza = pos = 0
    for a, b in posti:
        pezzi.append(testo[pos:a])
        lunghezza += a - pos
        nome = testo[a:b]
        if come == "intero" or " " not in nome:
            nuovo = OMESSO
        elif come == "ultima":
            resto = nome.rsplit(" ", 1)[0]
            nuovo = resto + " " + OMESSO
            m = list(cp.RE_PAROLA.finditer(resto))[-1]
            tenute.append((lunghezza + m.start(), lunghezza + m.end()))
        else:
            resto = nome.split(" ", 1)[1]
            nuovo = OMESSO + " " + resto
            m = next(cp.RE_PAROLA.finditer(resto))
            inizio = lunghezza + len(OMESSO) + 1
            tenute.append((inizio + m.start(), inizio + m.end()))
        pezzi.append(nuovo)
        lunghezza += len(nuovo)
        pos = b
    pezzi.append(testo[pos:])
    return "".join(pezzi), tenute


def classe_della_parte(cp: ModuleType, impronte: object, parola: str
                       ) -> Optional[str]:
    """La classe a cui il controllo attribuisce una parte: la prima, nel
    suo ordine, che ne ha l'impronta; None se nessuna."""
    chiave = cp.impronta(SALE, cp.piega(parola))
    return next((c for c in cp.CLASSI_PARTI
                 if chiave in impronte.parti[c]), None)  # type: ignore


def stampa_meta(frase: str, come: str, conti: Tuple[int, int, int]) -> None:
    """La riga di una prova sui nomi a metà: (posti, mancanti, in più)."""
    posti, mancanti, in_piu = conti
    if come == "intero":
        print("%s, il controllo %s" % (frase, (
            "trova %d nomi a metà: nessuno era atteso." % in_piu if in_piu
            else "non trova nessun nome a metà (%d posti)." % posti)))
    elif mancanti or in_piu:
        print("%s, il controllo: su %d posti, %d senza un nome a metà della "
              "classe attesa e %d nomi a metà in più." % (
                  frase, posti, mancanti, in_piu))
    else:
        print("%s, il controllo trova un nome a metà in ognuno dei %d posti, "
              "della classe a cui lo attribuisce, e nient'altro."
              % (frase, posti))


def verifica_meta(cp: ModuleType, impronte: object,
                  piantati: Sequence[Piantato], testo_csv: str,
                  debug: bool) -> bool:
    """Le prove sui nomi a metà, sulle copie dei testi grezzi (VARIANTI):
    i nomi a metà sono i residui che il controllo trova con le parti e non
    senza. Stampa i conteggi; True se una prova non tiene."""
    vuote = {c: frozenset() for c in cp.CLASSI_PARTI}
    senza_parti = impronte._replace(parti=vuote)  # type: ignore
    nomi = nomi_nei_testi(cp, piantati)
    righe = list(csv.DictReader(io.StringIO(testo_csv)))
    ko = False
    for come, frase in VARIANTI:
        posti = mancanti = in_piu = 0
        for riga in righe:
            for colonna in TESTI:
                elenco = nomi.get((riga["id_ticket"], colonna))
                if not elenco:
                    continue
                dove = occorrenze(riga[colonna], elenco)
                nuovo, tenute = variante(cp, riga[colonna], dove, come)
                posti += len(dove) if come == "intero" else len(tenute)
                attesi = {(classe_della_parte(cp, impronte, nuovo[a:b]), a, b)
                          for a, b in tenute}
                trovati = set(cp.cerca(nuovo, impronte)) \
                    - set(cp.cerca(nuovo, senza_parti))
                mancanti += len(attesi - trovati)
                in_piu += len(trovati - attesi)
                if debug and attesi != trovati:
                    sys.stderr.write("DEBUG nomi a metà, %s: %s %s\n" % (
                        come, riga["id_ticket"], colonna))
        stampa_meta(frase, come, (posti, mancanti, in_piu))
        ko = ko or bool(mancanti or in_piu)
    return ko


def stampa_conteggi(cp: ModuleType, classi: Dict[str, Set[str]],
                    piantati: Sequence[Piantato]) -> List[str]:
    """I conteggi per classe e il confronto con la verità del progetto;
    restituisce le voci diverse."""
    nei_testi = [p for p in piantati if p.colonna in ("descrizione",
                                                      "oggetto")]
    print("  %-15s %8s %11s %6s" % ("classe", "impronte", "occorrenze",
                                     "righe"))
    for classe in cp.NOMI_CLASSI:
        sue = [p for p in nei_testi if p.classe == classe]
        print("  %-15s %8d %11d %6d" % (classe, len(classi[classe]),
                                         sum(p.volte for p in sue),
                                         len({p.ticket for p in sue})))
    diverse = []
    for nome, gruppo, numero, testo in VERITA:
        sue = [p for p in nei_testi if p.classe in gruppo]
        occorrenze = sum(p.volte for p in sue)
        righe = len({p.ticket for p in sue})
        esito = "uguale alle occorrenze" if occorrenze == numero else (
            "uguale alle righe" if righe == numero else "diverso")
        if esito == "diverso":
            diverse.append(nome)
        print("  verità del progetto, %s: %s; nei testi %d occorrenze in %d "
              "righe: %s" % (nome, testo, occorrenze, righe, esito))
    salute = sorted({p.ticket for p in nei_testi if p.classe == "salute"})
    if tuple(salute) != VERITA_SALUTE:
        diverse.append("salute")
    print("  salute nelle righe: %s (verità del progetto: %s)" % (
        ", ".join(salute), ", ".join(VERITA_SALUTE)))
    return diverse


def scrivi(uscita: Path, classi: Dict[str, Set[str]],
           parti: Dict[str, Set[str]]) -> None:
    """impronte.json e le copie del CSV e del dizionario in uscita/."""
    (uscita / "dati").mkdir(parents=True, exist_ok=True)
    documento = {
        "versione": 2,
        "sale": SALE,
        "descrizione": ("Le impronte dei dati personali della settimana di "
                        "ticket: per ogni classe, lo SHA-256 di sale + forma "
                        "normalizzata di ogni valore; in parti, per nomi e "
                        "familiari, lo SHA-256 di sale + ogni parola di "
                        "almeno tre lettere dei nomi di persona, piegata. "
                        "Le forme sono spiegate in controlla_pii.py."),
        "classi": {c: sorted(s) for c, s in classi.items()},
        "parti": {c: sorted(s) for c, s in parti.items()},
    }
    testo = json.dumps(documento, ensure_ascii=False, indent=1,
                       sort_keys=True) + "\n"
    with open(uscita / FILE_IMPRONTE, "w", encoding="utf-8",
              newline="\n") as fh:
        fh.write(testo)
    for relativo in (FILE_CSV, FILE_DIZIONARIO):
        shutil.copyfile(str(PROGETTO / relativo), str(uscita / relativo))


def confronta(costruita: Path) -> List[str]:
    """I file di esercizio/ diversi da quelli costruiti."""
    diversi = []
    for relativo in (FILE_IMPRONTE, FILE_CSV, FILE_DIZIONARIO):
        presente_ = ESERCIZIO / relativo
        if not presente_.is_file() or presente_.read_bytes() != \
                (costruita / relativo).read_bytes():
            diversi.append(str(Path("esercizio") / relativo))
    return diversi


def costruisci(controlla: bool, debug: bool) -> int:
    for percorso in (PROGETTO / "genera.py", PROGETTO / FILE_CSV,
                     PROGETTO / FILE_DIZIONARIO):
        if not percorso.is_file():
            raise Precondizione("manca %s" % percorso)
    cp = carica("controlla_pii_elemento", ESERCIZIO / "controlla_pii.py")
    sys.dont_write_bytecode = True
    sys.path.insert(0, str(PROGETTO))
    genera = carica("genera", PROGETTO / "genera.py")
    testo_csv, ticket, valori = esegui_generatore(genera)
    with open(PROGETTO / FILE_CSV, encoding="utf-8", newline="") as fh:
        if fh.read() != testo_csv:
            raise Precondizione("il generatore, rieseguito, non riproduce "
                                "%s: le impronte sarebbero sbagliate"
                                % FILE_CSV)
    print("costruisci_impronte: il generatore riproduce %s byte per byte "
          "(%d righe)." % (FILE_CSV, len(ticket)))
    piantati = elenca(genera, testo_csv, ticket, valori)
    classi = impronte_di(cp, piantati)
    parti = parti_di(cp, piantati)
    impronte = cp.Impronte(SALE,
                           {c: frozenset(s) for c, s in classi.items()},
                           {c: frozenset(s) for c, s in parti.items()})
    if debug:
        for p in sorted(piantati):
            sys.stderr.write("DEBUG %s\t%s\t%s\t%s\t%d\n" % (
                p.classe, p.ticket, p.colonna, p.valore, p.volte))
    diverse = stampa_conteggi(cp, classi, piantati)
    print("  parti dei nomi: %s" % ", ".join(
        "%s %d" % (c, len(s)) for c, s in parti.items()))
    attese, mancanti, in_piu = verifica_controllo(
        cp, impronte, classi, piantati, PROGETTO / FILE_CSV, debug)
    rc = 0
    if mancanti or in_piu:
        print("Il controllo sul CSV grezzo: su %d posizioni attese, %d non "
              "trovate e %d trovate in più (con --debug, quali)."
              % (attese, mancanti, in_piu))
        rc = 1
    else:
        print("Il controllo sul CSV grezzo trova ogni dato elencato, nelle "
              "sue %d posizioni (classe, segnalazione, colonna), e "
              "nient'altro." % attese)
    if verifica_meta(cp, impronte, piantati, testo_csv, debug):
        rc = 1
    print("Diverse dalla verità del progetto, come dato: %s." % (
        ", ".join(diverse) if diverse else "nessuna"))
    totale = sum(len(s) for s in classi.values())
    n_parti = sum(len(s) for s in parti.values())
    if controlla:
        with tempfile.TemporaryDirectory() as cartella:
            scrivi(Path(cartella), classi, parti)
            diversi = confronta(Path(cartella))
        if diversi:
            print("DIVERSI da quelli che costruisce: %s." % ", ".join(
                diversi))
            return 1
        print("Identici byte per byte: esercizio/%s (%d impronte, %d parti "
              "dei nomi), esercizio/%s, esercizio/%s." % (
                  FILE_IMPRONTE, totale, n_parti, FILE_CSV, FILE_DIZIONARIO))
        return rc
    scrivi(ESERCIZIO, classi, parti)
    print("Scritti: esercizio/%s (%d impronte, %d parti dei nomi), "
          "esercizio/%s, esercizio/%s." % (FILE_IMPRONTE, totale, n_parti,
                                           FILE_CSV, FILE_DIZIONARIO))
    return rc


def main(argv: Sequence[str]) -> int:
    opzioni = set(argv)
    if opzioni & {"-h", "--help"}:
        print((__doc__ or "").strip())
        return 0
    if not opzioni <= {"--controlla", "--debug"}:
        sys.stderr.write("costruisci_impronte: argomenti non riconosciuti; "
                         "uso: costruisci_impronte.py [--controlla] "
                         "[--debug]\n")
        return 2
    try:
        return costruisci("--controlla" in opzioni, "--debug" in opzioni)
    except Precondizione as exc:
        sys.stderr.write("costruisci_impronte: %s\n" % exc)
        return 2
    except (OSError, ValueError, KeyError) as exc:
        sys.stderr.write("costruisci_impronte: errore (%s)\n"
                         % type(exc).__name__)
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
