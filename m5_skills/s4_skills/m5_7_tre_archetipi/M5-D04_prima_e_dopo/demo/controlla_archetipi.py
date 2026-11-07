"""controlla_archetipi.py -- la demo M5-D04 alla prova: la stessa richiesta con
la skill di esempio nella cartella (on) e con la cartella senza la skill
(senza), una per archetipo; e, a parte, la skill spenta per un'esecuzione
(off). Legge gli stream di `claude -p --output-format stream-json --verbose`
con tools/lib_controlla_prove.py, ogni volta da capo: mai un file di esiti
scritto prima.

Gli stream stanno nella cartella data: <archetipo>-on-<n>.jsonl e
<archetipo>-senza-<n>.jsonl, una coppia per ogni n; <archetipo>-off-<n>.jsonl,
il set di off, che nelle coppie non entra. Con --modelli:
<archetipo>-haiku.jsonl e <archetipo>-opus.jsonl, la skill accesa.

Per ogni esecuzione stampa la chiamata a Skill; un tentativo respinto, con il
testo dell'errore; i file che gli strumenti nominano sotto .claude/skills/; i
turni, i token e i secondi, come li conta lib_controlla_prove. In on e in
senza, i criteri:
  revisione  le regole inserite nel pull request e citate con il numero, a
             numero intero; gli altri numeri citati, come dati
  risposta   i quattro criteri che si contano: nessuna parola da evitare,
             quelle della guida del tono e dello SKILL.md di esempio, con le
             forme della stessa parola, a parola intera; al massimo tre frasi
             (la forma della chat nella guida); la forma del canale; nessuna
             premessa. La lunghezza in parole, come dato; il testo, per una
             persona
  audit      le categorie inserite nell'apparato che il testo riporta come
             problemi, e le sei colonne del report: l'intestazione, il
             separatore e almeno una riga. Una riga del report conta sempre; un
             codice in una riga che dice che la categoria è a posto, o sotto un
             titolo come «Categorie senza problemi», no. Le altre categorie e
             quelle senza un rilievo, come dati

Poi, per archetipo, il confronto: più criteri con on che con senza,
«confermata»; tanti quanti, «non distinguibile»; meno, «non confermata in
questa esecuzione». Si stampa coppia per coppia e sul totale, e non decide
l'uscita. La chiamata a Skill sta fuori dai criteri: Anthropic chiede di
misurarla a parte.

Le garanzie decidono l'uscita: in senza e in off la skill non è fra quelle
disponibili e nessuna chiamata Skill a quella skill riesce; un tentativo che
lo strumento respinge è un dato. In on deve esserci davvero: fra le
disponibili e, se chiamata, né negata dal permesso né respinta; altrimenti il
braccio non mette alla prova niente. Se senza la skill Claude ne sceglie
un'altra, si nomina, come dato.

Con --modelli stampa gli stessi criteri per modello, come dati, senza verdetti.

La verità sta fuori dallo spazio di lavoro, nella cartella dell'elemento:
verita.json, con le impronte delle regole e delle categorie. Le parole da
evitare e il modo di leggere le categorie sono gli stessi dei controlli del
laboratorio (M5-E03, M5-E04): la suite li confronta.

Uso:    python3 -B -I controlla_archetipi.py [--modelli] [--verita FILE]
          <cartella>
Env:    PN_HANDSON_ROOT  il repository, obbligatorio: gli strumenti e la verità
Uscita: 0 almeno una coppia completa (con --modelli: tutte le esecuzioni), le
          garanzie tengono; il confronto non decide
        1 la cartella manca o non ha coppie; una coppia a metà; uno stream
          incompleto o finito con un errore; una garanzia che non regge
        2 argomenti, PN_HANDSON_ROOT, la verità, uno stream che non si legge,
          un nome di file che non si riconosce; mai un traceback
"""
from __future__ import annotations

import hashlib
import json
import os
import re
import sys
from typing import Dict, List, NamedTuple, Optional, Set, Tuple

SALE = "m5-d04"
ELEMENTO = ("m5_skills", "s4_skills", "m5_7_tre_archetipi",
            "M5-D04_prima_e_dopo")
SKILL = {"revisione": "revisione-pr", "risposta": "risposta-assistenza",
         "audit": "audit-configurazione"}
ORDINE = ("revisione", "risposta", "audit")
MODELLI = ("haiku", "opus")
BRACCI_COPPIA = ("on", "senza")
RE_CORSA = re.compile(r"^(revisione|risposta|audit)-(on|senza|off)-"
                      r"([1-9][0-9]*)\.jsonl$")
RE_FILE_SKILL = re.compile(r"\.claude/skills/([^\s'\"`;&|)]+)")
RE_ERRORE_TOOL = re.compile(r"</?tool_use_error>")
RE_MODELLO = re.compile(r"^(revisione|risposta|audit)-(haiku|opus)\.jsonl$")
RE_HASH = re.compile(r"^[0-9a-f]{64}$")
RE_REGOLA = re.compile(r"(?<![\w.])([1-9]\d?\.[1-9]\d?)(?!\w|\.\d)")
COLONNE = frozenset({"apparato", "file", "riga", "categoria", "gravita",
                     "descrizione"})
RE_CODICE = re.compile(r"(?<![\w-])AUD-\d\d(?![\w-])")
# Una riga, o il titolo di una sezione, che dice che una categoria è a posto, o
# che non è stata vista: non è un rilievo. «non conforme» invece lo è, anche con
# una parola o due in mezzo («non risulta conforme»), e «Conformità» è il nome
# di una voce, non un esito.
RE_A_POSTO = re.compile(
    r"^(?!.*\bnon\s+(?:\w+\s+){0,2}conform[ei]\b).*\bconform[ei]\b"
    r"|senza problemi|senza rilievi"
    r"|nessun problema|nessun rilievo|non\s+(?:\w+\s+){0,2}problem"
    r"|non si applica|non applicabil|a posto|non verificat|scartat",
    re.IGNORECASE)
# Un'etichetta: una riga tutta in grassetto, o breve e chiusa dai due punti.
RE_ETICHETTA = re.compile(r"^(?:\*\*[^*]+\*\*:?|[^-*•\d|#][^|]{0,79}:)$")
RE_VOCE_IN_TESTA = re.compile(r"^(?:[-*•]|\d+[.)])\s+")
RE_SEPARATORE = re.compile(r"^\|?[\s:|-]*-[\s:|-]*\|?$")
# Le parole delle tabelle «invece di» della guida del tono e dello SKILL.md di
# esempio, ciascuna con le forme della stessa parola, che valgono uguale: la
# guida vieta la parola, non il suo singolare. La suite le confronta con i due
# file, nei due sensi.
PAROLE_DA_EVITARE = {
    "la sua problematica": ("problematica", "problematiche"),
    "disservizio": ("disservizio", "disservizi"),
    "degrado": ("degrado",),
    "ticket": ("ticket",),
    "presa in carico": ("presa in carico", "preso in carico",
                        "prese in carico", "presi in carico"),
    "le faremo sapere": ("le faremo sapere", "ti faremo sapere",
                         "vi faremo sapere"),
    "sarà nostra cura": ("sarà nostra cura",),
    "Gentile Cliente": ("gentile cliente",),
    "sicuramente": ("sicuramente",),
    "garantito": ("garantito", "garantita", "garantiti", "garantite"),
    "a breve": ("a breve",),
    "inconveniente": ("inconveniente", "inconvenienti"),
    "ha sbagliato a collegare": ("ha sbagliato a collegare",
                                 "hai sbagliato a collegare"),
    "come già detto": ("come già detto",),
    "OLT": ("olt",),
    "BNG": ("bng",),
    "SBC": ("sbc",),
    "PON": ("pon",),
}


def _espressione_parole() -> "re.Pattern":
    forme = sorted({f for voci in PAROLE_DA_EVITARE.values() for f in voci},
                   key=len, reverse=True)
    pezzi = [r"\s+".join(re.escape(p) for p in f.split()) for f in forme]
    # I nomi degli apparati hanno la forma <ruolo>-<comune>-<nn>.
    pezzi.append(r"[a-z]+-[a-z]+-\d\d")
    return re.compile(r"(?<![\w-])(?:" + "|".join(pezzi) + r")(?![\w-])",
                      re.IGNORECASE)


RE_PAROLE = _espressione_parole()
MASSIMO_FRASI = 3
RE_FRASE = re.compile(r"(?<=[.!?…])\s+|\n+")
RE_PREMESSA = re.compile(
    r"^\W*(?:ecco|certo|bozza|risposta|messaggio|proposta|di seguito|"
    r"ti propongo|potresti|puoi rispondere|ho preparato)\b", re.IGNORECASE)
RE_TITOLO = re.compile(r"(?m)^#{1,6}\s")
RE_VOCE = re.compile(r"(?m)^\s*(?:[-*•]|\d+[.)])\s")
RE_EMOJI = re.compile("[\U0001F300-\U0001FAFF☀-➿]")
ALTRI_MOSTRATI = 12
CONFERMATA = "confermata"
NON_DISTINGUIBILE = "non distinguibile"
NON_CONFERMATA = "non confermata in questa esecuzione"
LETTURA = ("La garanzia di senza: la skill non è fra le disponibili e nessuna "
           "chiamata Skill a quella skill riesce; un'altra skill scelta da "
           "Claude è un dato.\nCome si legge: conta il confronto con "
           "senza, non il punteggio da solo; dove i due bracci fanno lo "
           "stesso, non è la skill.")
LETTURA_OFF = ("La garanzia di off: la skill non è fra le disponibili e "
               "nessuna chiamata Skill a quella skill riesce. I suoi file "
               "restano nella cartella: ciò che Claude ne fa è un dato.")
INTESTA_MODELLI = (
    "Come dati, con la skill accesa. La checklist di Anthropic chiede «Tested "
    "with Haiku, Sonnet, and Opus»: Sonnet sono le altre esecuzioni della "
    "demo. Questa tabella non confronta i modelli.")
USO = ("Uso: python3 -B -I controlla_archetipi.py [--modelli] [--verita FILE] "
       "<cartella>")
MANCA_CARTELLA = "Manca la cartella degli stream {}: eseguite i passi del " \
    "README."
NESSUNA_COPPIA = "Nessuna coppia in {}: eseguite i passi del README."
NON_REGGE = ("La garanzia non regge qui sopra: è un esito da segnalare, non "
             "un voto alla skill.")
RIFARE = "Non ancora: qui sopra ciò che manca o non va; rifate quella coppia."


class Verita(NamedTuple):
    """Le impronte delle regole e delle categorie inserite."""
    regole: Set[str]
    categorie: Set[str]


class Criteri(NamedTuple):
    """I criteri di un'esecuzione: quanti, su quanti, le righe da stampare."""
    punti: int
    totale: int
    righe: List[str]


class Corsa(NamedTuple):
    """Un'esecuzione letta."""
    archetipo: str
    braccio: str
    n: int
    esec: object
    criteri: Optional[Criteri]


class Contesto(NamedTuple):
    """Ciò che serve a tutte le funzioni: gli strumenti e i dati."""
    prove: object
    verita: Verita


def impronta(campo: str, valore: str) -> str:
    testo = f"{SALE}:{campo}:{valore}"
    return hashlib.sha256(testo.encode("utf-8")).hexdigest()


def leggi_verita(percorso: str, prove: object) -> Verita:
    """verita.json; un file che non va è un Problema, mai un conteggio."""
    try:
        with open(percorso, encoding="utf-8") as fh:
            dati = json.load(fh)
        regole = dati["revisione"]["regole"]
        categorie = dati["audit"]["categorie"]
    except (OSError, ValueError, KeyError, TypeError) as exc:
        raise prove.Problema(f"la verità {percorso} non si legge: {exc}") \
            from exc
    for lista in (regole, categorie):
        if not isinstance(lista, list) or not lista or not all(
                isinstance(h, str) and RE_HASH.match(h) for h in lista):
            raise prove.Problema(f"la verità {percorso} non ha la forma "
                                 "giusta: elenchi di impronte")
    return Verita(set(regole), set(categorie))


# --------------------------------------------------------------------------
# I criteri
# --------------------------------------------------------------------------

def criteri_revisione(testo: str, verita: Verita) -> Criteri:
    citate = set(RE_REGOLA.findall(testo))
    trovate = {n for n in citate if impronta("regola", n) in verita.regole}
    altre = sorted(citate - trovate,
                   key=lambda n: [int(p) for p in n.split(".")])
    riga = f"regole inserite citate: {len(trovate)} su {len(verita.regole)}"
    if altre:
        mostrate = ", ".join(altre[:ALTRI_MOSTRATI])
        riga += f"; altre citate: {mostrate}"
        riga += ", …" if len(altre) > ALTRI_MOSTRATI else ""
    return Criteri(len(trovate), len(verita.regole), [riga])


def forma_del_canale(testo: str) -> List[str]:
    """Ciò che nella chat non va: la guida vuole messaggi brevi e un passo alla
    volta, senza emoji né punti esclamativi in serie."""
    difetti = []
    if RE_TITOLO.search(testo):
        difetti.append("titoli")
    if "**" in testo:
        difetti.append("grassetto")
    if len(RE_VOCE.findall(testo)) > 1:
        difetti.append("elenco di più passi")
    if RE_EMOJI.search(testo):
        difetti.append("emoji")
    if "!!" in testo:
        difetti.append("punti esclamativi in serie")
    return difetti


def criteri_risposta(testo: str) -> Criteri:
    trovate = list(dict.fromkeys(
        " ".join(m.group(0).split()) for m in RE_PAROLE.finditer(testo)))
    frasi = [f for f in RE_FRASE.split(testo.strip()) if f.strip()]
    difetti = forma_del_canale(testo)
    premessa = RE_PREMESSA.match(testo.strip()) is not None
    esiti = (not trovate, len(frasi) <= MASSIMO_FRASI, not difetti,
             not premessa)
    righe = [f"parole da evitare: {', '.join(trovate) or 'nessuna'}",
             f"frasi: {len(frasi)}, al massimo {MASSIMO_FRASI} nella chat",
             f"parole: {len(testo.split())} (un dato)",
             "forma del canale: " + (f"no: {', '.join(difetti)}"
                                     if difetti else "sì"),
             f"senza premessa: {'no' if premessa else 'sì'}",
             f"criteri: {sum(esiti)} su {len(esiti)}",
             "il testo, da leggere:"]
    righe += [f"  | {riga}".rstrip() for riga in testo.strip().splitlines()]
    return Criteri(sum(esiti), len(esiti), righe)


def _celle(riga: str) -> List[str]:
    return [cella.strip().strip("*`_ ").lower().replace("à", "a")
            for cella in riga.strip().strip("|").split("|")]


def _in_tabella(riga: str) -> bool:
    return riga.lstrip().startswith("|")


def _righe_dopo(righe: List[str], intestazione: int) -> List[int]:
    """Le righe di una tabella sotto la sua intestazione e il separatore."""
    i = intestazione + 1
    if i >= len(righe) or not _in_tabella(righe[i]) \
            or not RE_SEPARATORE.match(righe[i].strip()):
        return []
    dati: List[int] = []
    for j in range(i + 1, len(righe)):
        if not _in_tabella(righe[j]):
            break
        dati.append(j)
    return dati


def _intestazioni(righe: List[str]) -> List[int]:
    """Le righe con le sei colonne."""
    return [i for i, riga in enumerate(righe)
            if _in_tabella(riga) and COLONNE <= set(_celle(riga))]


def sei_colonne(testo: str) -> bool:
    """Un'intestazione con le sei colonne, il separatore e almeno una riga."""
    righe = testo.splitlines()
    return any(_righe_dopo(righe, i) for i in _intestazioni(righe))


def categorie_nel_testo(testo: str) -> Tuple[List[str], List[str]]:
    """I codici riportati come problemi, e quelli nominati senza un rilievo.

    Una riga del report a sei colonne è un rilievo. Altrove non lo è una riga
    che dice che la categoria è a posto, né ciò che sta in una sezione così:
    fino al titolo seguente, sotto un titolo «#»; fino a una riga vuota dopo il
    contenuto, sotto un'etichetta. Un'etichetta dentro un elenco può aprire una
    sezione, non chiuderla.
    """
    righe = testo.splitlines()
    del_report: Set[int] = set()
    for intestazione in _intestazioni(righe):
        del_report.update(_righe_dopo(righe, intestazione))
    rilievi: Dict[str, None] = {}
    nominate: Dict[str, None] = {}
    sotto_titolo = sotto_etichetta = contenuto = False
    for i, riga in enumerate(righe):
        pura = riga.strip()
        if i in del_report:
            rilievi.update(dict.fromkeys(RE_CODICE.findall(pura)))
            continue
        if not pura:
            if contenuto:
                sotto_etichetta = contenuto = False
            continue
        if pura.startswith("#"):
            sotto_titolo = RE_A_POSTO.search(pura) is not None
            sotto_etichetta = contenuto = False
        elif RE_ETICHETTA.match(pura):
            sotto_etichetta = RE_A_POSTO.search(pura) is not None
            contenuto = False
        elif RE_ETICHETTA.match(RE_VOCE_IN_TESTA.sub("", pura)) \
                and RE_A_POSTO.search(pura):
            sotto_etichetta = True
            contenuto = False
        else:
            contenuto = True
        a_posto = sotto_titolo or sotto_etichetta \
            or RE_A_POSTO.search(pura) is not None
        (nominate if a_posto else rilievi).update(
            dict.fromkeys(RE_CODICE.findall(pura)))
    return (sorted(rilievi), sorted(c for c in nominate if c not in rilievi))


def criteri_audit(testo: str, verita: Verita) -> Criteri:
    rilievi, nominate = categorie_nel_testo(testo)
    trovate = [c for c in rilievi
               if impronta("categoria", c) in verita.categorie]
    altre = [c for c in rilievi if c not in trovate]
    colonne = sei_colonne(testo)
    riga = (f"categorie inserite trovate: {len(trovate)} su "
            f"{len(verita.categorie)}")
    if altre:
        riga += f"; altre categorie: {', '.join(altre)}"
    if nominate:
        riga += f"; senza un rilievo: {', '.join(nominate)}"
    righe = [riga, f"le sei colonne: {'sì' if colonne else 'no'}"]
    return Criteri(len(trovate) + int(colonne), len(verita.categorie) + 1,
                   righe)


def criteri_di(archetipo: str, testo: str, ctx: Contesto) -> Criteri:
    if archetipo == "revisione":
        return criteri_revisione(testo, ctx.verita)
    if archetipo == "risposta":
        return criteri_risposta(testo)
    return criteri_audit(testo, ctx.verita)


# --------------------------------------------------------------------------
# Le esecuzioni
# --------------------------------------------------------------------------

def nomi_stream(cartella: str, schema: "re.Pattern",
                prove: object) -> List[str]:
    """I file .jsonl della cartella; un nome che non torna è un Problema, mai
    una prova in meno."""
    try:
        nomi = sorted(n for n in os.listdir(cartella) if n.endswith(".jsonl"))
    except OSError as exc:
        raise prove.Problema(f"non riesco a leggere {cartella}: {exc}") \
            from exc
    for nome in nomi:
        if schema.match(nome) is None:
            raise prove.Problema(f"{os.path.join(cartella, nome)}: non "
                                 "riconosco questo nome: spostalo fuori da "
                                 "qui")
    return nomi


def leggi_corsa(cartella: str, nome: str, archetipo: str, braccio: str, n: int,
                ctx: Contesto) -> Corsa:
    esec = ctx.prove.leggi_stream(os.path.join(cartella, nome))
    if esec.completa and esec.init_skills is None:
        raise ctx.prove.Problema(f"{esec.percorso}: lo stream non ha l'elenco "
                                 "delle skill di system/init: la garanzia non "
                                 "si legge")
    criteri = None
    if esec.completa and not esec.errore and braccio != "off":
        criteri = criteri_di(archetipo, esec.testo, ctx)
    return Corsa(archetipo, braccio, n, esec, criteri)


def decimale(valore: float) -> str:
    return f"{valore:.1f}".replace(".", ",")


def consumo(esec: object) -> str:
    turni = "1 turno" if esec.turni == 1 else f"{int(esec.turni)} turni"
    segmenti = f" in {esec.segmenti} segmenti" if esec.segmenti > 1 else ""
    return (f"{turni}{segmenti}, {int(esec.token_totali)} token, "
            f"{decimale(esec.secondi)} s")


def stato_chiamata(esec: object, skill: str) -> str:
    """Che cosa è stato di una chiamata a quella skill."""
    if esec.chiamata_riuscita(skill):
        return "sì"
    if skill in esec.chiamate_negate:
        return "no, negata dal permesso"
    if skill in esec.chiamate_respinte:
        return "no, tentata e respinta"
    return "no"


def riga_skill(corsa: Corsa) -> str:
    skill = SKILL[corsa.archetipo]
    esec = corsa.esec
    altre = []
    for nome in sorted({n for n in esec.chiamate_skill if n != skill}):
        stato = stato_chiamata(esec, nome)
        altre.append(nome if stato == "sì" else f"{nome} ({stato[4:]})")
    fine = f"; altre skill: {', '.join(altre)}" if altre else ""
    return f"Skill {skill}: {stato_chiamata(esec, skill)}{fine}"


def blocchi_di(riga: str) -> List[dict]:
    """I blocchi del contenuto di un messaggio di uno stream già letto."""
    evento = json.loads(riga) if riga.strip() else {}
    messaggio = evento.get("message") if isinstance(evento, dict) else None
    contenuto = (messaggio.get("content") if isinstance(messaggio, dict)
                 else None)
    if not isinstance(contenuto, list):
        return []
    return [blocco for blocco in contenuto if isinstance(blocco, dict)]


def testo_risultato(contenuto: object) -> str:
    """Il testo di un tool_result, una stringa o un elenco di blocchi."""
    if isinstance(contenuto, list):
        contenuto = " ".join(str(b.get("text", "")) for b in contenuto
                             if isinstance(b, dict))
    return " ".join(RE_ERRORE_TOOL.sub("", str(contenuto)).split())


def errori_della_skill(esec: object, skill: str) -> List[str]:
    """I testi con cui lo strumento ha respinto le chiamate a quella skill,
    dallo stream: lib_controlla_prove dà i nomi, qui serve anche il testo."""
    if skill not in esec.chiamate_respinte:
        return []
    chiamate: Set[object] = set()
    testi: List[str] = []
    with open(esec.percorso, encoding="utf-8") as fh:
        for riga in fh:
            for blocco in blocchi_di(riga):
                ingresso = blocco.get("input")
                if blocco.get("type") == "tool_use" \
                        and blocco.get("name") == "Skill" \
                        and isinstance(ingresso, dict) \
                        and ingresso.get("skill") == skill:
                    chiamate.add(blocco.get("id"))
                elif blocco.get("type") == "tool_result" \
                        and blocco.get("is_error") \
                        and blocco.get("tool_use_id") in chiamate:
                    testi.append(testo_risultato(blocco.get("content")))
    return testi


def file_della_skill(esec: object) -> List[str]:
    """Ciò che gli strumenti nominano sotto .claude/skills/, una volta per
    voce: lo strumento e il percorso dopo quella cartella."""
    voci: List[str] = []
    for strumento in esec.strumenti:
        if strumento.nome == "Skill" or not isinstance(strumento.input, dict):
            continue
        for valore in strumento.input.values():
            for percorso in RE_FILE_SKILL.findall(valore) \
                    if isinstance(valore, str) else []:
                voce = f"{strumento.nome} {percorso}"
                if voce not in voci:
                    voci.append(voce)
    return voci


def riga_file_skill(esec: object) -> str:
    voci = file_della_skill(esec)
    mostrate = "; ".join(voci[:ALTRI_MOSTRATI]) or "nessuno"
    if len(voci) > ALTRI_MOSTRATI:
        mostrate += "; …"
    return f"file sotto .claude/skills/: {mostrate}"


def mancanza(corsa: Corsa) -> Optional[str]:
    """Che cosa non va in uno stream che non si può giudicare."""
    nome = os.path.basename(corsa.esec.percorso)
    if not corsa.esec.completa:
        return f"{nome}: incompleta, lo stream non ha un risultato"
    if corsa.esec.errore:
        return f"{nome}: finita con un errore"
    return None


def reperti_di(corsa: Corsa) -> List[str]:
    """Le garanzie che non reggono su un'esecuzione che si può leggere."""
    if not corsa.esec.completa:
        return []
    skill = SKILL[corsa.archetipo]
    nome = os.path.basename(corsa.esec.percorso)
    esec = corsa.esec
    elencata = skill in (esec.init_skills or [])
    trovati: List[str] = []
    if corsa.braccio != "on":
        stato = "è spenta" if corsa.braccio == "off" else "non c'è"
        if esec.chiamata_riuscita(skill):
            trovati.append(f"{nome}: una chiamata Skill a {skill} è riuscita, "
                           f"e in questo braccio la skill {stato}")
        if elencata:
            trovati.append(f"{nome}: {skill} è fra le skill disponibili, e in "
                           f"questo braccio {stato}")
        return trovati
    if not elencata:
        trovati.append(f"{nome}: {skill} non è fra le skill disponibili: "
                       "questo braccio non la mette alla prova")
    if skill in esec.chiamate_negate and not esec.chiamata_riuscita(skill):
        trovati.append(f"{nome}: la chiamata Skill a {skill} è negata dal "
                       "permesso: il corpo non è arrivato; fra gli strumenti "
                       f"serve Skill({skill})")
    elif skill in esec.chiamate_respinte and not esec.chiamata_riuscita(skill):
        trovati.append(f"{nome}: la chiamata Skill a {skill} è respinta dallo "
                       "strumento: il corpo non è arrivato")
    return trovati


def stampa_corsa(etichetta: str, corsa: Corsa) -> None:
    print(f"{etichetta}: {riga_skill(corsa)}")
    for testo in errori_della_skill(corsa.esec, SKILL[corsa.archetipo]):
        print(f"  respinta con: {testo}")
    if corsa.criteri is not None:
        for riga in corsa.criteri.righe:
            print(f"  {riga}")
    print(f"  {riga_file_skill(corsa.esec)}")
    if corsa.esec.completa:
        print(f"  {consumo(corsa.esec)}")
    cambiati = corsa.esec.percorso[:-len(".jsonl")] + ".cambiati"
    if os.path.isfile(cambiati):
        with open(cambiati, encoding="utf-8") as fh:
            elenco = " ".join(fh.read().split())
        print(f"  file lasciati dalla sessione (un dato, poi tolti): {elenco}")


# --------------------------------------------------------------------------
# Il confronto
# --------------------------------------------------------------------------

def verdetto(a: int, b: int) -> str:
    if a > b:
        return CONFERMATA
    if a == b:
        return NON_DISTINGUIBILE
    return NON_CONFERMATA


def conta(corse: List[Corsa], skill: str) -> int:
    return sum(1 for c in corse if c.esec.chiamata_riuscita(skill))


def media(corse: List[Corsa]) -> str:
    fatte = [c.esec for c in corse if c.esec.completa]
    if not fatte:
        return "nessuna esecuzione completa"
    token = sum(e.token_totali for e in fatte) / len(fatte)
    secondi = sum(e.secondi for e in fatte) / len(fatte)
    return f"{int(token)} token, {decimale(secondi)} s"


def stampa_riepilogo(archetipo: str, on: List[Corsa], senza: List[Corsa],
                     esiti: List[Tuple[int, int, int]]) -> None:
    skill = SKILL[archetipo]
    print(f"{archetipo}: Skill {skill}: on {conta(on, skill)} su {len(on)}, "
          f"senza {conta(senza, skill)} su {len(senza)}")
    altre: Dict[str, int] = {}
    for corsa in senza:
        for nome in set(corsa.esec.chiamate_skill) - {skill}:
            altre[nome] = altre.get(nome, 0) + 1
    if altre:
        elenco = ", ".join(f"{n} {altre[n]} su {len(senza)}"
                           for n in sorted(altre))
        print(f"{archetipo}: altre skill, senza: {elenco}")
    print(f"{archetipo}: in media, come dato: on {media(on)}; "
          f"senza {media(senza)}")
    negative = sum(1 for c in senza if reperti_di(c))
    print(f"{archetipo}: garanzia di senza: tiene {len(senza) - negative} su "
          f"{len(senza)}")
    if not esiti:
        print(f"{archetipo}: nessuna coppia si confronta")
        return
    punti_on = sum(e[0] for e in esiti)
    punti_senza = sum(e[1] for e in esiti)
    totale = sum(e[2] for e in esiti)
    print(f"{archetipo}: criteri in tutto: on {punti_on}, senza {punti_senza} "
          f"su {totale}: {verdetto(punti_on, punti_senza)}")
    conferme = sum(1 for e in esiti if e[0] > e[1])
    print(f"{archetipo}: coppia per coppia: {CONFERMATA} {conferme} su "
          f"{len(esiti)}")


def esamina_archetipo(archetipo: str, corse: Dict[Tuple[str, int], Corsa],
                      cartella: str) -> Tuple[List[str], List[str]]:
    """Stampa le coppie di un archetipo. Returns: (le mancanze, i reperti)."""
    mancanze: List[str] = []
    reperti: List[str] = []
    esiti: List[Tuple[int, int, int]] = []
    print(f"\n== {archetipo}: la skill {SKILL[archetipo]}, on e senza\n")
    for n in sorted({n for _, n in corse}):
        lati = {b: corse.get((b, n)) for b in BRACCI_COPPIA}
        for braccio in BRACCI_COPPIA:
            corsa = lati[braccio]
            if corsa is None:
                mancanze.append(f"{os.path.basename(cartella)}: manca "
                                f"{archetipo}-{braccio}-{n}.jsonl")
                continue
            stampa_corsa(f"{braccio} {n}", corsa)
            motivo = mancanza(corsa)
            if motivo:
                mancanze.append(motivo)
            reperti.extend(reperti_di(corsa))
        if lati["on"] and lati["senza"] and lati["on"].criteri \
                and lati["senza"].criteri:
            a, b = lati["on"].criteri.punti, lati["senza"].criteri.punti
            totale = lati["on"].criteri.totale
            esiti.append((a, b, totale))
            print(f"coppia {n}: on {a}, senza {b} su {totale}: "
                  f"{verdetto(a, b)}")
        else:
            print(f"coppia {n}: non si confronta")
    print()
    per_braccio = {braccio: [c for (b, _), c in corse.items() if b == braccio]
                   for braccio in BRACCI_COPPIA}
    stampa_riepilogo(archetipo, per_braccio["on"], per_braccio["senza"], esiti)
    return mancanze, reperti


def esamina_off(corse: List[Corsa]) -> Tuple[List[str], List[str]]:
    """Il set di off, a parte. Returns: (le mancanze, i reperti)."""
    mancanze: List[str] = []
    reperti: List[str] = []
    print("\n== off: la skill spenta per una esecuzione, nella sua cartella\n")
    for archetipo in ORDINE:
        sue = [c for c in corse if c.archetipo == archetipo]
        for corsa in sue:
            stampa_corsa(f"{archetipo} off {corsa.n}", corsa)
            motivo = mancanza(corsa)
            if motivo:
                mancanze.append(motivo)
        if sue:
            sui_reperti = [r for c in sue for r in reperti_di(c)]
            buone = sum(1 for c in sue if not reperti_di(c))
            reperti.extend(sui_reperti)
            print(f"{archetipo}: garanzia di off: tiene {buone} su {len(sue)}")
    buone = sum(1 for c in corse if not reperti_di(c))
    tentativi = sum(1 for c in corse
                    if SKILL[c.archetipo] in c.esec.chiamate_respinte)
    con_file = sum(1 for c in corse if file_della_skill(c.esec))
    print(f"\ngaranzia di off, in tutto: tiene {buone} su {len(corse)}")
    print(f"come dati: tentativi respinti: {tentativi} su {len(corse)}; "
          f"file sotto .claude/skills/ nominati da Claude: {con_file} su "
          f"{len(corse)}")
    print(LETTURA_OFF)
    return mancanze, reperti


def esamina_risposte(cartella: str, ctx: Contesto) -> int:
    """Le coppie e il set di off: stampa tutto. Returns: l'uscita."""
    letti: Dict[str, Dict[Tuple[str, int], Corsa]] = {}
    spente: List[Corsa] = []
    for nome in nomi_stream(cartella, RE_CORSA, ctx.prove):
        archetipo, braccio, numero = RE_CORSA.match(nome).groups()
        corsa = leggi_corsa(cartella, nome, archetipo, braccio, int(numero),
                            ctx)
        if braccio == "off":
            spente.append(corsa)
        else:
            letti.setdefault(archetipo, {})[(braccio, corsa.n)] = corsa
    if not letti:
        print(NESSUNA_COPPIA.format(cartella))
        return 1
    mancanze: List[str] = []
    reperti: List[str] = []
    for archetipo in ORDINE:
        if archetipo in letti:
            sue_m, suoi_r = esamina_archetipo(archetipo, letti[archetipo],
                                              cartella)
            mancanze.extend(sue_m)
            reperti.extend(suoi_r)
    print(f"\n{LETTURA}")
    if spente:
        sue_m, suoi_r = esamina_off(spente)
        mancanze.extend(sue_m)
        reperti.extend(suoi_r)
    for voce in mancanze:
        print(f"MANCA: {voce}")
    for voce in reperti:
        print(f"REPERTO: {voce}")
    if reperti:
        print(NON_REGGE)
    if mancanze:
        print(RIFARE)
    return 1 if mancanze or reperti else 0


def esamina_modelli(cartella: str, ctx: Contesto) -> int:
    """Il set dei modelli: gli stessi criteri, come dati. Returns: l'uscita."""
    presenti = nomi_stream(cartella, RE_MODELLO, ctx.prove)
    print(INTESTA_MODELLI)
    problemi: List[str] = []
    for archetipo in ORDINE:
        print(f"\n== {archetipo}: la skill {SKILL[archetipo]}\n")
        for modello in MODELLI:
            nome = f"{archetipo}-{modello}.jsonl"
            if nome not in presenti:
                problemi.append(f"manca {nome}")
                continue
            corsa = leggi_corsa(cartella, nome, archetipo, "on", 1, ctx)
            stampa_corsa(modello, corsa)
            motivo = mancanza(corsa)
            if motivo:
                problemi.append(motivo)
            problemi.extend(reperti_di(corsa))
    for voce in problemi:
        print(f"MANCA: {voce}")
    return 1 if problemi else 0


# --------------------------------------------------------------------------
# La riga di comando
# --------------------------------------------------------------------------

def leggi_argomenti(argv: List[str]) -> Optional[Tuple[bool, Optional[str],
                                                       str]]:
    """(--modelli, --verita, la cartella); None, con il motivo su STDERR."""
    modelli = False
    verita: Optional[str] = None
    posizionali: List[str] = []
    resto = list(argv)
    while resto:
        arg = resto.pop(0)
        if arg == "--modelli":
            modelli = True
        elif arg == "--verita" and resto:
            verita = resto.pop(0)
        elif arg.startswith("-"):
            print(f"controlla_archetipi: opzione sconosciuta: {arg}\n{USO}",
                  file=sys.stderr)
            return None
        else:
            posizionali.append(arg)
    if len(posizionali) != 1:
        print(USO, file=sys.stderr)
        return None
    return modelli, verita, posizionali[0]


def carica_strumenti() -> Optional[Tuple[str, object]]:
    """(il repository, lib_controlla_prove); None, con il motivo su STDERR."""
    radice = os.environ.get("PN_HANDSON_ROOT", "")
    strumenti = os.path.join(radice, "tools")
    if not radice or not os.path.isfile(
            os.path.join(strumenti, "lib_controlla_prove.py")):
        print("controlla_archetipi: PN_HANDSON_ROOT deve essere la cartella "
              "delle esercitazioni: export PN_HANDSON_ROOT=<la cartella>",
              file=sys.stderr)
        return None
    sys.path.insert(0, strumenti)
    # pylint: disable=import-outside-toplevel
    import lib_controlla_prove as prove
    return radice, prove


def esegui(argomenti: Tuple[bool, Optional[str], str], radice: str,
           prove: object) -> int:
    modelli, file_verita, cartella = argomenti
    percorso = file_verita or os.path.join(radice, *ELEMENTO, "verita.json")
    ctx = Contesto(prove, leggi_verita(percorso, prove))
    if not os.path.isdir(cartella):
        print(MANCA_CARTELLA.format(cartella))
        return 1
    if modelli:
        return esamina_modelli(cartella, ctx)
    return esamina_risposte(cartella, ctx)


def main(argv: List[str]) -> int:
    if argv[:1] in (["-h"], ["--help"]):
        print(USO)
        return 0
    argomenti = leggi_argomenti(argv)
    if argomenti is None:
        return 2
    caricati = carica_strumenti()
    if caricati is None:
        return 2
    radice, prove = caricati
    return prove.principale(lambda _: esegui(argomenti, radice, prove), argv)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
