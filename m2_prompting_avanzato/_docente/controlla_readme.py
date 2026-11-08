#!/usr/bin/env python3
"""controlla_readme.py -- le due esercitazioni del Modulo 2 come lezioni.

Lo usa test_m2_script.sh; solo libreria standard. Ogni comando legge i
file dei due elementi, non scrive niente:

  sezioni    <README>           le dieci sezioni ci sono, «La teoria che
                                serve» è subito prima di «Punto di
                                partenza», «La soluzione, passo per
                                passo» è l'ultima
  pratica    <README>           la parola compare per la prima volta nella
                                sottosezione che la definisce, e mai per
                                dire l'esercitazione
  comune     <README E01> <README E02>
                                nella teoria, le sottosezioni con lo stesso
                                titolo sono uguali byte per byte e
                                nell'ordine atteso, e quelle di un README
                                solo sono quelle attese
  versioni   <E01> <E02>        v0 in soluzione/ è quella di esercizio/,
                                «la versione migliore» non c'è più, e la
                                regola delle versioni dice le sue tre cose
  template   <E02>              le sei versioni di soluzione/ sono nel
                                template: un tag per ingrediente, da solo
                                su una riga, nell'ordine, poi i dati
  differenza <E02>              da v1 a v2 cambiano soltanto <context> e,
                                dove la famiglia lo ha, il tag del
                                documento di riferimento
  soluzione  <elemento>         la soluzione passo per passo: apre dicendo
                                di provare prima, nomina la data e la
                                versione della prova, ogni blocco
                                «prompt NOME» è uguale al suo file e ogni
                                blocco «estratto FILE» sta, riga per riga
                                e nell'ordine, nel suo file di soluzione/

Un estratto si scrive fra <!-- estratto FILE --> e <!-- /estratto -->,
con FILE relativo a soluzione/. Una riga «[…]» salta un pezzo del file; un
«[…]» dentro una riga ne salta un pezzo.

Uscita: 0 il controllo passa («ok: <comando>») · 1 almeno un problema
        («non va: …», uno per riga) · 2 uso sbagliato, un file che non si
        legge o un errore inatteso del controllo; mai un traceback.
"""
from __future__ import annotations

import os
import re
import sys
import textwrap
from typing import Callable, Dict, List, NamedTuple, Optional, Sequence, Tuple

TEORIA = "La teoria che serve"
PARTENZA = "Punto di partenza"
SOLUZIONE = "La soluzione, passo per passo"
# Le sezioni di un README, tutte e nell'ordine: le dieci e queste due.
SEZIONI = ("Obiettivo", "Tempo", "Prerequisiti", TEORIA, PARTENZA,
           "Passi in Claude Code", "Che cosa osservare", "Verifica",
           "Se qualcosa va storto", "Impronta d'uso sul piano Pro",
           "Per approfondire", SOLUZIONE)
COMUNI = ("Perché si misura un prompt", "Gli ingredienti e i loro tag",
          "Che cos'è una pratica", "I due tipi di criterio", "Il giudice",
          "Come si legge un esito", "Gli attrezzi",
          "La regola delle versioni")
DEFINIZIONE = "Che cos'è una pratica"
REGOLA = "La regola delle versioni"
# Le sottosezioni di ogni teoria, tutte e nell'ordine.
ORDINE_E01 = COMUNI[:3] + ("Le pratiche in M2-E01",) + COMUNI[3:] + (
    "Le versioni di M2-E01",)
ORDINE_E02 = (COMUNI[0], "Le famiglie e i due cicli") + COMUNI[1:3] + (
    "Le pratiche in M2-E02",) + COMUNI[3:] + (
    "Le versioni di M2-E02", "Il contesto, come pratica",
    "Effort e modello, come pratiche")
# Le tre cose che la regola delle versioni deve dire.
PAROLE_REGOLA = ("non si tocca", "copia della versione precedente",
                 "nessuna versione si copia da una più vecchia")
VIETATE = ("versione migliore", "dalla migliore", "migliore versione")
# «Pratica» per dire l'esercitazione: un altro significato, già vietato.
ALTRI_SENSI = re.compile(r"\b(?:(?:nella|in|di) pratica|esercitazione pratica"
                         r"|parte pratica)\b")
FAMIGLIE = ("sviluppo", "supporto", "sistemi")
INGREDIENTI = ("role", "context", "instructions", "format", "constraints")
DATO = {"sviluppo": ("code", "codice"), "supporto": ("message", "messaggio"),
        "sistemi": ("log", "log")}
RIFERIMENTO = {"sviluppo": ("convention", "convenzione"),
               "supporto": ("tone_guide", "tono"), "sistemi": None}
ETICHETTA = re.compile(r"^(Ruolo|Contesto|Istruzion[ei]|Formato|Vincoli|"
                       r"Esempi):")
PAROLA = re.compile(r"\bpratic(?:a|he)\b", re.IGNORECASE)
TAG_RIGA = re.compile(r"^</?[a-z_]+>$")
PROMPT_APRI = re.compile(r"^\s*<!-- prompt (\S[^>]*?) -->\s*$")
PROMPT_CHIUDI = re.compile(r"^\s*<!-- /prompt (\S[^>]*?) -->\s*$")
ESTRATTO_APRI = re.compile(r"^\s*<!-- estratto (\S+) -->\s*$")
ESTRATTO_CHIUDI = re.compile(r"^\s*<!-- /estratto -->\s*$")
# Nella soluzione ogni commento HTML è un marcatore: se nessuno dei quattro lo
# riconosce, il blocco che apre non verrebbe confrontato.
MARCATORE = re.compile(r"<!--")
TAGLIO = "[…]"
MESI = ("gennaio", "febbraio", "marzo", "aprile", "maggio", "giugno",
        "luglio", "agosto", "settembre", "ottobre", "novembre", "dicembre")
DATA_RE = re.compile(r"\b(\d{1,2})°?\s+(%s)\s+(\d{4})\b" % "|".join(MESI))
VERSIONE_RE = re.compile(r"Claude Code (\d+\.\d+\.\d+)")
TRASCRIZIONE = "trascrizione.txt"
DATA_TRASCRITTA = re.compile(r"^data della prova: (\d{4}-\d{2}-\d{2})$",
                             re.MULTILINE)
VERSIONE_TRASCRITTA = re.compile(r"^claude (\d+\.\d+\.\d+) \(Claude Code",
                                 re.MULTILINE)
PROMPT_E01 = ("v1",)
PROMPT_E02 = tuple("%s/v%d" % (f, v) for f in FAMIGLIE for v in (1, 2))


class Precondizione(Exception):
    """Un file che non si legge: uscita 2."""


class Blocco(NamedTuple):
    """Un blocco fra due marcatori della soluzione."""
    genere: str          # «prompt» o «estratto»
    nome: str            # il nome del prompt, o il file dell'estratto
    righe: List[str]     # le righe fra i due marcatori, così come sono


def leggi(percorso: str) -> str:
    """Il testo di un file in UTF-8; Precondizione se non si legge."""
    try:
        with open(percorso, encoding="utf-8") as fh:
            return fh.read()
    except (OSError, UnicodeDecodeError) as exc:
        raise Precondizione("%s non si legge (%s)" % (percorso, exc)) from exc


def titoli_sezione(righe: Sequence[str]) -> List[Tuple[int, str]]:
    """(indice, titolo) di ogni sezione «## …» del testo."""
    return [(i, r[3:].strip()) for i, r in enumerate(righe)
            if r.startswith("## ")]


def piegato(testo: str) -> str:
    """Il testo su una riga sola, in minuscolo: un README va a capo dove
    vuole."""
    return " ".join(testo.split()).lower()


def corpo_sezione(righe: Sequence[str], titolo: str) -> Optional[List[str]]:
    """Le righe della sezione dopo il suo titolo, None se non c'è."""
    teste = titoli_sezione(righe)
    for n, (i, nome) in enumerate(teste):
        if nome == titolo:
            fine = teste[n + 1][0] if n + 1 < len(teste) else len(righe)
            return list(righe[i + 1:fine])
    return None


def sottosezioni(corpo: Sequence[str]) -> Tuple[str, List[Tuple[str, str]]]:
    """(il testo prima della prima «### …», [(titolo, testo), …])."""
    teste = [(i, r[4:].strip()) for i, r in enumerate(corpo)
             if r.startswith("### ")]
    primo = teste[0][0] if teste else len(corpo)
    preambolo = "\n".join(corpo[:primo]).strip("\n")
    voci = []
    for n, (i, titolo) in enumerate(teste):
        fine = teste[n + 1][0] if n + 1 < len(teste) else len(corpo)
        voci.append((titolo, "\n".join(corpo[i + 1:fine]).strip("\n")))
    return preambolo, voci


def nome_sezione(titolo: str) -> str:
    """Il nome di una sezione, senza quello che il titolo aggiunge in coda
    («Punto di partenza (tools/…)»)."""
    for sezione in SEZIONI:
        if titolo == sezione or titolo.startswith(sezione + " ("):
            return sezione
    return titolo


def sezioni(readme: str) -> List[str]:
    """Le sezioni, tutte, una volta sola e nell'ordine; la teoria subito
    prima della partenza, la soluzione per ultima."""
    righe = leggi(readme).split("\n")
    titoli = [nome_sezione(t) for _, t in titoli_sezione(righe)]
    problemi = ["manca la sezione «%s»" % s for s in SEZIONI
                if s not in titoli]
    if problemi:
        return problemi
    if titoli.index(TEORIA) != titoli.index(PARTENZA) - 1:
        problemi.append("«%s» non è subito prima di «%s»" % (TEORIA, PARTENZA))
    if titoli[-1] != SOLUZIONE:
        problemi.append("«%s» non è per ultima" % SOLUZIONE)
    if not problemi and titoli != list(SEZIONI):
        problemi.append("le sezioni non sono nell'ordine atteso, una volta "
                        "ciascuna")
    return problemi


def pratica(readme: str) -> List[str]:
    """La parola «pratica» compare per la prima volta nella sua definizione."""
    righe = leggi(readme).split("\n")
    problemi = ["«%s» chiama pratica l'esercitazione" % m.group(0)
                for m in ALTRI_SENSI.finditer(piegato("\n".join(righe)))]
    teoria = corpo_sezione(righe, TEORIA)
    voci = dict(sottosezioni(teoria)[1]) if teoria is not None else {}
    if DEFINIZIONE not in voci:
        return problemi + ["manca la sottosezione «%s»" % DEFINIZIONE]
    if not voci[DEFINIZIONE].startswith("Una **pratica** è"):
        problemi.append("«%s» non comincia con la definizione" % DEFINIZIONE)
    testa = next((i for i, r in enumerate(righe)
                  if r.startswith("### " + DEFINIZIONE)), None)
    prima = next((i for i, r in enumerate(righe) if PAROLA.search(r)), None)
    if prima is None or testa is None or prima < testa:
        problemi.append("la parola compare prima della definizione, alla "
                        "riga %s" % ("?" if prima is None else prima + 1))
    return problemi


def controlla_ordine(titoli: List[str], ordine: Sequence[str],
                     quale: str) -> List[str]:
    """I titoli di una teoria: gli attesi, nell'ordine, una volta sola."""
    problemi = ["manca «%s» in %s" % (t, quale) for t in ordine
                if t not in titoli]
    problemi += ["sottosezione inattesa «%s» in %s" % (t, quale)
                 for t in titoli if t not in ordine]
    if not problemi and titoli != list(ordine):
        problemi.append("in %s le sottosezioni non sono nell'ordine atteso, "
                        "una volta ciascuna" % quale)
    return problemi


def comune(readme1: str, readme2: str) -> List[str]:
    """Le parti comuni delle due teorie sono uguali byte per byte."""
    corpi = []
    for readme in (readme1, readme2):
        corpo = corpo_sezione(leggi(readme).split("\n"), TEORIA)
        if corpo is None:
            return ["manca la sezione «%s» in %s" % (TEORIA, readme)]
        corpi.append(sottosezioni(corpo))
    problemi = controlla_ordine([t for t, _ in corpi[0][1]], ORDINE_E01,
                                "E01")
    problemi += controlla_ordine([t for t, _ in corpi[1][1]], ORDINE_E02,
                                 "E02")
    if corpi[0][0] != corpi[1][0]:
        problemi.append("l'apertura della teoria è diversa")
    voci = [dict(c[1]) for c in corpi]
    for titolo in COMUNI:
        if titolo in voci[0] and titolo in voci[1] \
                and voci[0][titolo] != voci[1][titolo]:
            problemi.append("«%s» è diversa nei due README" % titolo)
    return problemi


def versioni(e01: str, e02: str) -> List[str]:
    """La regola: v0 uguale alla partenza, niente versione migliore."""
    problemi: List[str] = []
    coppie = [(os.path.join(e01, "esercizio", "prompt", "v0.md"),
               os.path.join(e01, "soluzione", "prompt", "v0.md"))]
    coppie += [(os.path.join(e02, "esercizio", f, "prompt", "v0.md"),
                os.path.join(e02, "soluzione", f, "prompt", "v0.md"))
               for f in FAMIGLIE]
    for partenza, copia in coppie:
        if not os.path.isfile(copia):
            problemi.append("manca %s" % copia)
        elif leggi(partenza) != leggi(copia):
            problemi.append("%s non è uguale a %s" % (copia, partenza))
    for e in (e01, e02):
        testo = leggi(os.path.join(e, "README.md"))
        vive = [testo]
        live = os.path.join(e, "_docente", "live.sh")
        if os.path.isfile(live):
            vive.append(leggi(live))
        for parole in VIETATE:
            if any(parole in piegato(t) for t in vive):
                problemi.append("«%s» c'è ancora in %s" % (parole, e))
        corpo = corpo_sezione(testo.split("\n"), TEORIA)
        regola = dict(sottosezioni(corpo)[1]).get(REGOLA, "") if corpo else ""
        regola = " ".join(regola.split())  # il testo va a capo dove vuole
        for parole in PAROLE_REGOLA:
            if parole not in regola:
                problemi.append("in %s la regola non dice «%s»" % (e, parole))
    return problemi


def tag_attesi(famiglia: str, versione: int) -> List[str]:
    """I tag di una versione, nell'ordine."""
    attesi = list(INGREDIENTI) + [DATO[famiglia][0]]
    riferimento = RIFERIMENTO[famiglia]
    if versione == 2 and riferimento:
        attesi.append(riferimento[0])
    return attesi


def blocco_tag(testo: str, tag: str) -> Optional[str]:
    """Il testo fra le righe <tag> e </tag>, None se non c'è."""
    trovato = re.search(r"(?ms)^<%s>\n(.*?)\n</%s>$" % (tag, tag), testo)
    return trovato.group(1) if trovato else None


def problemi_versione(testo: str, famiglia: str, versione: int,
                      nome: str) -> List[str]:
    """Il prompt di una versione nel template, un tag per ingrediente."""
    tag = tag_attesi(famiglia, versione)
    trovati = [r for r in testo.split("\n") if TAG_RIGA.match(r)]
    attesi = [x for t in tag for x in ("<%s>" % t, "</%s>" % t)]
    if trovati != attesi:
        return ["%s: i tag sono %s, attesi %s" % (nome, " ".join(trovati),
                                                  " ".join(attesi))]
    problemi = ["%s: il tag %s è vuoto" % (nome, t) for t in INGREDIENTI
                if not (blocco_tag(testo, t) or "").strip()]
    if any(ETICHETTA.match(r) for r in testo.split("\n")):
        problemi.append("%s: una riga comincia con un'etichetta" % nome)
    if not (blocco_tag(testo, "role") or "").startswith("Sei "):
        problemi.append("%s: il ruolo non comincia con «Sei »" % nome)
    contesto = blocco_tag(testo, "context") or ""
    dati = [DATO[famiglia]]
    riferimento = RIFERIMENTO[famiglia]
    if versione == 2 and riferimento:
        dati.append(riferimento)
    for t, segnaposto in dati:
        if "<%s>" % t not in contesto:
            problemi.append("%s: il contesto non nomina <%s>" % (nome, t))
        if (blocco_tag(testo, t) or "").strip() != "{{%s}}" % segnaposto:
            problemi.append("%s: il tag %s non contiene {{%s}}" % (
                nome, t, segnaposto))
    return problemi


def file_versione(e02: str, famiglia: str, versione: int) -> str:
    """Il file di una versione in soluzione/."""
    return os.path.join(e02, "soluzione", famiglia, "prompt",
                        "v%d.md" % versione)


def template(e02: str) -> List[str]:
    """Le sei versioni di soluzione/ nel template."""
    problemi: List[str] = []
    for famiglia in FAMIGLIE:
        for versione in (1, 2):
            testo = leggi(file_versione(e02, famiglia, versione))
            problemi += problemi_versione(testo, famiglia, versione,
                                          "%s/v%d" % (famiglia, versione))
    return problemi


def differenza(e02: str) -> List[str]:
    """Da v1 a v2 cambiano soltanto <context> e il riferimento."""
    problemi: List[str] = []
    for famiglia in FAMIGLIE:
        v1 = leggi(file_versione(e02, famiglia, 1))
        v2 = leggi(file_versione(e02, famiglia, 2))
        c1, c2 = blocco_tag(v1, "context"), blocco_tag(v2, "context")
        if c1 is None or c2 is None:
            problemi.append("%s: manca il tag context" % famiglia)
            continue
        if c1 == c2:
            problemi.append("%s: il contesto di v2 è uguale a quello di v1"
                            % famiglia)
        attesa = v1.replace("<context>\n%s\n</context>" % c1,
                            "<context>\n%s\n</context>" % c2, 1)
        riferimento = RIFERIMENTO[famiglia]
        if riferimento:
            attesa += "\n<%s>\n{{%s}}\n</%s>\n" % (riferimento[0],
                                                   riferimento[1],
                                                   riferimento[0])
        if attesa != v2:
            problemi.append("%s: da v1 a v2 cambia altro, oltre al contesto "
                            "e al riferimento" % famiglia)
    return problemi


def blocchi(righe: Sequence[str]) -> Tuple[List[Blocco], List[str]]:
    """I blocchi fra i marcatori della soluzione, e i marcatori rotti."""
    trovati: List[Blocco] = []
    problemi: List[str] = []
    aperto: Optional[Tuple[str, str, int]] = None
    for i, riga in enumerate(righe):
        apri_p, apri_e = PROMPT_APRI.match(riga), ESTRATTO_APRI.match(riga)
        chiudi_p, chiudi_e = PROMPT_CHIUDI.match(riga), \
            ESTRATTO_CHIUDI.match(riga)
        if MARCATORE.search(riga) \
                and not (apri_p or apri_e or chiudi_p or chiudi_e):
            problemi.append("un marcatore scritto male: %s" % riga.strip())
            continue
        if aperto is None:
            if apri_p:
                aperto = ("prompt", apri_p.group(1), i)
            elif apri_e:
                aperto = ("estratto", apri_e.group(1), i)
            elif chiudi_p or chiudi_e:
                problemi.append("un marcatore di chiusura senza apertura: %s"
                                % riga.strip())
            continue
        genere, nome, inizio = aperto
        chiude = ((genere == "prompt" and chiudi_p is not None
                   and chiudi_p.group(1) == nome)
                  or (genere == "estratto" and chiudi_e is not None))
        if chiude:
            trovati.append(Blocco(genere, nome, list(righe[inizio + 1:i])))
            aperto = None
    if aperto is not None:
        problemi.append("il blocco «%s %s» non si chiude" % aperto[:2])
    return trovati, problemi


def combacia(riga: str, originale: str) -> bool:
    """La riga di un estratto è quella del file; un «[…]» dentro la riga ne
    salta un pezzo. Il rientro non conta."""
    riga, originale = riga.strip(), originale.strip()
    if TAGLIO in riga:
        pezzi = riga.split(TAGLIO)
        if not any(p.strip() for p in pezzi):
            return False  # una riga di soli tagli non dice niente
        modello = ".*".join(re.escape(p) for p in pezzi)
        return re.fullmatch(modello, originale, re.DOTALL) is not None
    return riga == originale


def spezzoni(righe: Sequence[str]) -> List[List[str]]:
    """Le righe di un estratto, divise dalle righe «[…]»: ogni spezzone
    senza le righe vuote ai bordi, nessuno spezzone fatto solo di vuoti."""
    testo = textwrap.dedent("\n".join(righe)).strip("\n").split("\n")
    parti: List[List[str]] = [[]]
    for riga in testo:
        if riga.strip() == TAGLIO:
            parti.append([])
        else:
            parti[-1].append(riga)
    return ["\n".join(p).strip("\n").split("\n") for p in parti
            if any(r.strip() for r in p)]


def trova_spezzone(pezzo: Sequence[str], righe: Sequence[str],
                   da: int) -> Optional[int]:
    """Il primo indice >= da da cui pezzo sta, riga per riga, in righe."""
    for i in range(da, len(righe) - len(pezzo) + 1):
        if all(combacia(p, righe[i + k]) for k, p in enumerate(pezzo)):
            return i
    return None


def estratto_ok(blocco: Blocco, sorgente: str) -> List[str]:
    """Le righe dell'estratto stanno nel file, nell'ordine."""
    righe = leggi(sorgente).split("\n")
    pezzi = spezzoni(blocco.righe)
    if not pezzi:
        return ["l'estratto %s è vuoto" % blocco.nome]
    da = 0
    for pezzo in pezzi:
        trovato = trova_spezzone(pezzo, righe, da)
        if trovato is None:
            return ["una riga dell'estratto %s non si trova nel file: %s"
                    % (blocco.nome, pezzo[0].strip()[:70])]
        da = trovato + len(pezzo)
    return []


def file_prompt(elemento: str, nome: str) -> str:
    """Il file di un blocco «prompt NOME»: v1, o famiglia/v1."""
    parti = nome.split("/")
    return os.path.join(elemento, "soluzione", *parti[:-1], "prompt",
                        parti[-1] + ".md")


def controlla_blocco(elemento: str, blocco: Blocco) -> List[str]:
    """Un blocco della soluzione contro il suo file."""
    if os.path.isabs(blocco.nome) or ".." in blocco.nome.split("/"):
        return ["il blocco «%s %s» esce da soluzione/" % blocco[:2]]
    if blocco.genere == "prompt":
        percorso = file_prompt(elemento, blocco.nome)
        if not os.path.isfile(percorso):
            return ["manca il file del prompt %s: %s" % (blocco.nome, percorso)]
        testo = textwrap.dedent("\n".join(blocco.righe)).strip("\n")
        if testo != leggi(percorso).rstrip("\n"):
            return ["il prompt %s non è uguale al suo file" % blocco.nome]
        return []
    sorgente = os.path.join(elemento, "soluzione", blocco.nome)
    if not os.path.isfile(sorgente):
        return ["manca il file dell'estratto: %s" % blocco.nome]
    return estratto_ok(blocco, sorgente)


def data_iso(trovata: "re.Match[str]") -> str:
    """Una data in italiano (giorno, mese, anno) in forma AAAA-MM-GG."""
    return "%s-%02d-%02d" % (trovata.group(3),
                             MESI.index(trovata.group(2)) + 1,
                             int(trovata.group(1)))


def apertura(righe: Sequence[str], elemento: str) -> List[str]:
    """Il primo paragrafo: provate prima; le date e le versioni che nomina,
    tutte quelle della trascrizione."""
    primo = re.split(r"\n\s*\n", "\n".join(righe).strip("\n"))[0]
    testo = " ".join(primo.split())
    problemi: List[str] = []
    if "Provate prima" not in testo:
        problemi.append("la soluzione non apre dicendo di provare prima")
    date = {data_iso(m) for m in DATA_RE.finditer(testo)}
    versioni_prova = {m.group(1) for m in VERSIONE_RE.finditer(testo)}
    if not date:
        problemi.append("manca la data della prova")
    if not versioni_prova:
        problemi.append("manca la versione di Claude Code della prova")
    percorso = os.path.join(elemento, "soluzione", TRASCRIZIONE)
    if not os.path.isfile(percorso):
        return problemi + ["manca soluzione/%s" % TRASCRIZIONE]
    trascritta = leggi(percorso)
    d_t, v_t = (DATA_TRASCRITTA.search(trascritta),
                VERSIONE_TRASCRITTA.search(trascritta))
    if date and (d_t is None or date != {d_t.group(1)}):
        problemi.append("la data non è quella della trascrizione")
    if versioni_prova and (v_t is None or versioni_prova != {v_t.group(1)}):
        problemi.append("la versione non è quella della trascrizione")
    return problemi


def soluzione(elemento: str) -> List[str]:
    """La soluzione passo per passo contro i file registrati."""
    righe = leggi(os.path.join(elemento, "README.md")).split("\n")
    corpo = corpo_sezione(righe, SOLUZIONE)
    if corpo is None:
        return ["manca la sezione «%s»" % SOLUZIONE]
    problemi = apertura(corpo, elemento)
    trovati, rotti = blocchi(corpo)
    problemi += rotti
    famiglie = os.path.isdir(
        os.path.join(elemento, "soluzione", FAMIGLIE[0]))
    nomi = [b.nome for b in trovati if b.genere == "prompt"]
    for nome in PROMPT_E02 if famiglie else PROMPT_E01:
        if nome not in nomi:
            problemi.append("manca il blocco del prompt %s" % nome)
    if not any(b.genere == "estratto" for b in trovati):
        problemi.append("nessun estratto nella soluzione: niente di stampato "
                        "è stato confrontato")
    for blocco in trovati:
        problemi += controlla_blocco(elemento, blocco)
    return problemi


COMANDI: Dict[str, Tuple[int, Callable[..., List[str]]]] = {
    "sezioni": (1, sezioni), "pratica": (1, pratica), "comune": (2, comune),
    "versioni": (2, versioni), "template": (1, template),
    "differenza": (1, differenza), "soluzione": (1, soluzione),
}


def main(argv: List[str]) -> int:
    """Esegue un comando; l'uscita è quella del docstring del modulo."""
    if not argv or argv[0] not in COMANDI \
            or len(argv) - 1 != COMANDI[argv[0]][0]:
        sys.stderr.write("uso: controlla_readme.py %s ...\n"
                         % "|".join(COMANDI))
        return 2
    try:
        problemi = COMANDI[argv[0]][1](*argv[1:])
    except Precondizione as exc:
        sys.stderr.write("controlla_readme: %s\n" % exc)
        return 2
    except Exception as exc:  # l'ultima rete: un messaggio, mai un traceback
        sys.stderr.write("controlla_readme: errore inatteso (%s: %s)\n" % (
            type(exc).__name__, " ".join(str(exc).split())))
        return 2
    for problema in problemi:
        print("non va: %s" % problema)
    if problemi:
        return 1
    print("ok: %s" % argv[0])
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
