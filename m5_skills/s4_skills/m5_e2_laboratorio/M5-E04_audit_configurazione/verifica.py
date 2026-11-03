#!/usr/bin/env python3
"""verifica.py di M5-E04 «Una skill di audit delle configurazioni»: i giudici
delle tre asserzioni di evals.json e il controllo del lavoro, su
tools/lib_controlla_prove.py. Legge gli stream, ogni volta da capo.

I giudici, uno per asserzione, sul testo finale di ogni esecuzione:
  - le categorie: i codici AUD-nn che il testo riporta come problemi,
    confrontati per impronta con verita.json, per l'apparato del caso
    (APPARATI); l'evidenza dice quante su quante, e non nomina quelle che
    mancano. Le altre categorie sono un dato: un audit vero ne trova altre, e la
    chiave è ciò che è stato inserito, non tutto ciò che non va. Non conta un
    codice in una riga che dice che la categoria è a posto, o sotto un titolo
    come «Categorie senza problemi»: nominarla non vuol dire averla trovata;
  - la tabella: un'intestazione con le sei colonne, il separatore e almeno una
    riga; l'evidenza cita l'intestazione;
  - i file: outputs/file-cambiati.txt vuoto.

Con --solo-prove (lo chiama tools/prove_skill.sh): la tabella e i dati, e scrive
timing.json, grading.json, benchmark.json e risposta.md. Senza: la tabella e i
dati, senza scrivere niente, e dice che cosa manca per finire.

Decidono l'uscita soltanto le garanzie (REPERTO) e, senza --solo-prove, ciò che
manca (MANCA): che il lavoro sia stato fatto. Le asserzioni, la skill chiamata o
no, la near-miss, i confronti, i file letti: dati, mai un'uscita.

Uso:    verifica.py <spazio di lavoro> [--solo-prove]
Env:    PN_HANDSON_ROOT  il repository (default: la radice sopra l'elemento)
Uscita: 0 fatto (o, con --solo-prove, letto) · 1 un reperto, o qualcosa che
        manca · 2 precondizione (argomenti, spazio di lavoro, verita.json, un
        caso senza il suo apparato, uno stream che non si legge) o un errore
        inatteso
"""
from __future__ import annotations

import hashlib
import json
import os
import re
import sys
from typing import Dict, List, NamedTuple, Optional, Set, Tuple

ELEMENTO = os.path.dirname(os.path.abspath(__file__))
RADICE = os.environ.get("PN_HANDSON_ROOT") or os.path.normpath(
    os.path.join(ELEMENTO, *[os.pardir] * 4))
# I moduli stanno in tools/ del repository; -I toglie la cartella dello script
# dal percorso dei moduli. Il controllo è quello del repository, non la copia
# dello spazio di lavoro. Senza di loro si esce 2: 1 vorrebbe dire «non ancora».
sys.path.insert(0, os.path.join(RADICE, "tools"))
try:
    # pylint: disable=wrong-import-position
    import controlla_skill
    import lib_controlla_prove as prove
except ImportError as exc:
    print(f"verifica: non trovo gli strumenti in {RADICE}/tools: {exc}",
          file=sys.stderr)
    sys.exit(2)

SKILL = "audit-configurazione"
SALE = "m5-e04"
USO = "Uso: verifica.py <spazio di lavoro> [--solo-prove]"
A_CATEGORIE = "Trova le categorie dei problemi inseriti apposta nell'apparato"
A_TABELLA = ("Riporta i problemi in una tabella con apparato, file, riga, "
             "categoria, gravità e descrizione")
A_FILE = "Non modifica alcun file"
# L'apparato di ogni caso di evals.json.
APPARATI = {1: "sw-rovereto-01", 2: "olt-pergine-01", 3: "bts-cles-01"}
CODICI = tuple(f"AUD-{numero:02d}" for numero in range(1, 17))
COLONNE = frozenset({"apparato", "file", "riga", "categoria", "gravita",
                     "descrizione"})
RADICE_RETE = "progetti/rete/"
RADICE_SKILL = f".claude/skills/{SKILL}/"
LUNGHEZZA_CITAZIONE = 120
RE_CODICE = re.compile(r"(?<![\w-])AUD-\d\d(?![\w-])")
# Una riga, o il titolo di una sezione, che dice che una categoria è a posto, o
# che non è stata vista: non è un rilievo. «non conforme» invece lo è, anche con
# una parola o due in mezzo («non risulta conforme»), e «Conformità» è il nome
# di una voce, non dice com'è. Vale per la riga intera, non per un solo codice.
RE_A_POSTO = re.compile(
    r"^(?!.*\bnon\s+(?:\w+\s+){0,2}conform[ei]\b).*\bconform[ei]\b"
    r"|senza problemi|senza rilievi"
    r"|nessun problema|nessun rilievo|non\s+(?:\w+\s+){0,2}problem"
    r"|non si applica|non applicabil|a posto|non verificat|scartat",
    re.IGNORECASE)
# Un'etichetta: una riga tutta in grassetto, o breve e chiusa dai due punti.
RE_ETICHETTA = re.compile(r"^(?:\*\*[^*]+\*\*:?|[^-*•\d|#][^|]{0,79}:)$")
RE_VOCE = re.compile(r"^(?:[-*•]|\d+[.)])\s+")
RE_SEPARATORE = re.compile(r"^\|?[\s:|-]*-[\s:|-]*\|?$")


class Contesto(NamedTuple):
    """Ciò che i giudici sanno di un caso."""
    ident: int
    apparato: str
    inserite: List[str]


def impronta(apparato: str, categoria: str) -> str:
    testo = f"{SALE}:{apparato}:{categoria}"
    return hashlib.sha256(testo.encode("utf-8")).hexdigest()


def leggi_verita() -> Dict[str, List[str]]:
    """Le impronte di verita.json, per apparato. Raises: Problema."""
    percorso = os.path.join(ELEMENTO, "verita.json")
    try:
        with open(percorso, encoding="utf-8") as fh:
            voci = json.load(fh)["apparati"]
        if not isinstance(voci, dict) or not all(
                isinstance(v, list) for v in voci.values()):
            raise ValueError("«apparati» non è una mappa di elenchi")
    except (OSError, ValueError, KeyError, TypeError) as exc:
        raise prove.Problema(f"{percorso} non si legge: {exc}") from exc
    return voci


class Contesti:
    """I contesti dei giudici, uno per caso, letti una volta sola."""

    def __init__(self) -> None:
        self.verita = leggi_verita()
        self.letti: Dict[int, Contesto] = {}

    def di(self, ident: int, _configurazione: str) -> Contesto:
        """Il contesto del caso. Raises: Problema."""
        if ident in self.letti:
            return self.letti[ident]
        apparato = APPARATI.get(ident)
        if apparato is None:
            raise prove.Problema(f"eval-{ident}: verifica.py non ha il suo "
                                 "apparato: i casi di prova sono quelli di "
                                 "partenza")
        impronte = self.verita.get(apparato)
        if impronte is None:
            raise prove.Problema(f"eval-{ident}: verita.json non ha {apparato}")
        inserite = [c for c in CODICI if impronta(apparato, c) in impronte]
        if len(inserite) != len(impronte):
            raise prove.Problema(f"{apparato}: le impronte di verita.json non "
                                 "sono tutte categorie della checklist")
        contesto = Contesto(ident, apparato, inserite)
        self.letti[ident] = contesto
        return contesto


def _citazione(riga: str) -> str:
    return riga.strip()[:LUNGHEZZA_CITAZIONE]


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
        elif RE_ETICHETTA.match(RE_VOCE.sub("", pura)) \
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


def giudica_categorie(esec: prove.Esecuzione,
                      contesto: Contesto) -> Tuple[bool, str]:
    """Trova le categorie inserite nell'apparato del caso? Quante su quante:
    non dice quali mancano."""
    rilievi, nominate = categorie_nel_testo(esec.testo)
    trovate = [c for c in contesto.inserite if c in rilievi]
    totale = len(contesto.inserite)
    evidenza = f"{len(trovate)} su {totale} categorie inserite"
    altre = [c for c in rilievi if c not in contesto.inserite]
    if altre:
        evidenza += f"; altre categorie: {', '.join(altre)}"
    if nominate:
        evidenza += f"; senza un rilievo: {', '.join(nominate)}"
    return len(trovate) == totale, evidenza


def giudica_tabella(esec: prove.Esecuzione,
                    _contesto: Contesto) -> Tuple[bool, str]:
    """Una tabella Markdown con le sei colonne e almeno una riga."""
    righe = esec.testo.splitlines()
    intestazioni = _intestazioni(righe)
    if not intestazioni:
        altra = next((r for r in righe if _in_tabella(r)), None)
        if altra is None:
            return False, "nessuna tabella"
        return False, ("nessuna tabella con le sei colonne; la prima ha: "
                       f"«{_citazione(altra)}»")
    for intestazione in intestazioni:
        dati = _righe_dopo(righe, intestazione)
        if dati:
            quante = "1 riga" if len(dati) == 1 else f"{len(dati)} righe"
            return True, (f"intestazione: «{_citazione(righe[intestazione])}», "
                          f"{quante}")
    return False, (f"intestazione: «{_citazione(righe[intestazioni[0]])}», ma "
                   "nessuna riga sotto il separatore")


def giudica_file(esec: prove.Esecuzione,
                 _contesto: Contesto) -> Tuple[bool, str]:
    """Nessun file cambiato nella copia. Nella registrazione del corso, in
    dontAsk, con Read e Skill consentiti, senza Edit né Write, è passata in
    entrambe le configurazioni: ciò che si è visto lì, non una garanzia."""
    cambiati = prove.file_cambiati(esec)
    if cambiati:
        return False, f"file-cambiati.txt: {'; '.join(cambiati[:5])}"
    return True, ("file-cambiati.txt è vuoto; Edit e Write non sono fra gli "
                  "strumenti consentiti di prove/config")


GIUDICI = {A_CATEGORIE: giudica_categorie, A_TABELLA: giudica_tabella,
           A_FILE: giudica_file}


def _relativo(percorso: str) -> str:
    """Un percorso di Read senza la copia temporanea, che non c'è più."""
    if RADICE_SKILL in percorso:
        return "skill: " + percorso.split(RADICE_SKILL, 1)[1]
    if RADICE_RETE in percorso:
        return percorso.split(RADICE_RETE, 1)[1]
    return os.path.basename(percorso)


def _letti(esec: prove.Esecuzione) -> List[str]:
    """I file letti con Read, una volta ciascuno, nell'ordine."""
    letti: Dict[str, None] = {}
    for strumento in esec.strumenti:
        ingresso = strumento.input
        if strumento.nome == "Read" and isinstance(ingresso, dict) \
                and isinstance(ingresso.get("file_path"), str):
            letti[_relativo(ingresso["file_path"])] = None
    return list(letti)


def _di_altri_apparati(letti: List[str], apparato: str) -> int:
    return sum(1 for percorso in letti if percorso.startswith("configurazioni/")
               and apparato not in percorso)


def _riga_della_prova(numero: int, prova: prove.Prova,
                      contesto: Contesto) -> str:
    """Ciò che un'esecuzione ha trovato in più e che cosa ha letto."""
    esec = prova.esec
    rilievi, nominate = categorie_nel_testo(esec.testo)
    altre = [c for c in rilievi if c not in contesto.inserite]
    letti = _letti(esec)
    bash = sum(1 for strumento in esec.strumenti if strumento.nome == "Bash")
    pezzi = []
    if altre:
        pezzi.append(f"altre categorie: {', '.join(altre)}")
    if nominate:
        pezzi.append(f"senza un rilievo: {', '.join(nominate)}")
    pezzi.append(f"letti con Read: {', '.join(letti) or 'nessuno'}")
    pezzi.append("di altri apparati: "
                 f"{_di_altri_apparati(letti, contesto.apparato)}")
    pezzi.append(f"comandi Bash: {bash}")
    return (f"(dato) iterazione {numero}, eval-{prova.eval_id}, "
            f"{prova.configurazione}: " + "; ".join(pezzi))


def _trovate_in(prova: prove.Prova, contesto: Contesto) -> Optional[int]:
    """Quante categorie inserite trova una prova riuscita; None altrimenti."""
    if prova.esec is None or not prova.esec.completa or prova.esec.errore:
        return None
    rilievi = categorie_nel_testo(prova.esec.testo)[0]
    return sum(1 for c in contesto.inserite if c in rilievi)


def _stampa_caso(numero: int, ident: int, prove_caso: List[prove.Prova],
                 contesto: Contesto) -> None:
    """Le categorie inserite trovate, per configurazione, e che cosa ha letto
    ogni esecuzione fatta: old_skill riusa quelle dell'iterazione prima."""
    conti = {p.configurazione: _trovate_in(p, contesto) for p in prove_caso}
    riuscite = {c: n for c, n in conti.items() if n is not None}
    if not riuscite:
        return
    totale = len(contesto.inserite)
    print(f"(dato) iterazione {numero}, eval-{ident} ({contesto.apparato}), "
          "categorie inserite trovate: "
          + "; ".join(f"{c} {n} su {totale}" for c, n in riuscite.items()))
    base = prove.baseline(riuscite)
    if base and "with_skill" in riuscite:
        print(f"(dato) iterazione {numero}, eval-{ident}, with_skill contro "
              f"{base}: {riuscite['with_skill']} e {riuscite[base]}: "
              f"{prove.verdetto(riuscite['with_skill'], riuscite[base])} "
              "(una sola esecuzione per caso)")
    for prova in prove_caso:
        if prova.configurazione != "old_skill" and prova.esec is not None \
                and prova.esec.completa and not prova.esec.errore:
            print(_riga_della_prova(numero, prova, contesto))


def _stampa_chiamate(numero: int, iterazione: prove.Iterazione) -> None:
    """La skill chiamata n su N, e le altre skill che Claude ha scelto."""
    con = [p.esec for p in iterazione.prove
           if p.configurazione == "with_skill"
           and p.esec is not None and p.esec.completa]
    if con:
        chiamate = sum(1 for e in con if e.chiamata_riuscita(SKILL))
        print(f"(dato) iterazione {numero}: {SKILL} chiamata {chiamate} su "
              f"{len(con)} in with_skill")
    senza = [p.esec for p in iterazione.prove
             if p.configurazione == "without_skill" and p.esec is not None]
    altre = sorted({nome for e in senza for nome in e.chiamate_skill
                    if nome != SKILL})
    if altre:
        print(f"(dato) iterazione {numero}, without_skill: Claude ha scelto da "
              f"sé {', '.join(altre)}")


def stampa_dati(esame: prove.Esame, contesti: Contesti) -> None:
    """I dati che non decidono l'uscita."""
    if not esame.iterazioni:
        return
    print("\nCome dati, mai come uscita:")
    for numero in sorted(esame.iterazioni):
        iterazione = esame.iterazioni[numero]
        _stampa_chiamate(numero, iterazione)
        for ident in sorted({p.eval_id for p in iterazione.prove}):
            _stampa_caso(numero, ident,
                         [p for p in iterazione.prove if p.eval_id == ident],
                         contesti.di(ident, ""))


def leggi_argomenti(argv: List[str]) -> Tuple[str, bool]:
    """Lo spazio di lavoro e --solo-prove. Raises: Problema."""
    if not argv or argv[0].startswith("-") \
            or any(arg != "--solo-prove" for arg in argv[1:]):
        raise prove.Problema(USO)
    if not os.path.isdir(argv[0]):
        raise prove.Problema(f"spazio di lavoro assente: {argv[0]}")
    return argv[0], "--solo-prove" in argv[1:]


def main(argv: List[str]) -> int:
    ws, solo_prove = leggi_argomenti(argv)
    contesti = Contesti()
    esame = prove.esamina(ws, SKILL, GIUDICI, contesti.di, scrivi=solo_prove)
    stampa_dati(esame, contesti)
    trovati = prove.reperti(esame, SKILL)
    for riga in trovati:
        print(f"REPERTO {riga}")
    if solo_prove:
        return 1 if trovati else 0
    mancano = prove.manca_per_finire(esame, ws, SKILL)
    mancano += controlla_skill.esamina_skill(esame.cartella_skill).errori
    for riga in mancano:
        print(f"MANCA {riga}")
    if trovati or mancano:
        return 1
    print("\nFatto: la skill passa il controllo del file, le due iterazioni ci "
          "sono, i commenti anche, e le due versioni sono diverse.")
    return 0


if __name__ == "__main__":
    sys.exit(prove.principale(main, sys.argv[1:]))
