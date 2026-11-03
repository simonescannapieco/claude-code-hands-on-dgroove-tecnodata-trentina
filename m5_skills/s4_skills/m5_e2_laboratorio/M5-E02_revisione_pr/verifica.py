#!/usr/bin/env python3
"""verifica.py di M5-E02 «Una skill di revisione contro le convenzioni del
team»: i giudici delle quattro asserzioni di evals.json e il controllo del
lavoro, su tools/lib_controlla_prove.py. Legge gli stream, ogni volta da capo.

I giudici, uno per asserzione, sul testo finale di ogni esecuzione:
  - le regole citate, cercate come numeri interi («7.1», non «17.1» né «7.10») e
    confrontate per impronta con verita.json; l'evidenza dice quante e quali
    mancano: i numeri delle regole sono pubblici;
  - il file e la riga: per ogni regola inserita apposta che la risposta cita,
    una riga con quel numero, un percorso del pull request o del progetto e un
    numero di riga; non lo chiedono le regole senza un posto (SENZA_RIGA), e le
    altre regole nominate sono un dato;
  - l'esito: «approvabile» o «da modificare» nelle ultime righe;
  - i file: outputs/file-cambiati.txt vuoto.

Con --solo-prove (lo chiama tools/prove_skill.sh): la tabella e i dati, e scrive
timing.json, grading.json, benchmark.json e risposta.md. Senza: la tabella e i
dati, senza scrivere niente, e dice che cosa manca per finire.

Decidono l'uscita soltanto le garanzie (REPERTO) e, senza --solo-prove, ciò che
manca (MANCA): che il lavoro sia stato fatto. Le asserzioni, la skill chiamata o
no, la near-miss, code-review scelta da Claude, i confronti: dati, mai un'uscita.

Uso:    verifica.py <spazio di lavoro> [--solo-prove]
Env:    PN_HANDSON_ROOT  il repository (default: la radice sopra l'elemento)
Uscita: 0 fatto (o, con --solo-prove, letto) · 1 un reperto, o qualcosa che
        manca · 2 precondizione (argomenti, spazio di lavoro, verita.json, una
        patch, le convenzioni, uno stream che non si legge) o un errore inatteso
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

SKILL = "revisione-pr"
SALE = "m5-e02"
PROGETTO = "progetti/gestionale-php"
USO = "Uso: verifica.py <spazio di lavoro> [--solo-prove]"
A_REGOLE = ("Cita con il numero tutte le regole violate inserite apposta nel "
            "pull request")
A_RIGHE = "Indica il file e la riga di ogni rilievo"
A_ESITO = "Chiude con un esito: approvabile o da modificare"
A_FILE = "Non modifica alcun file"
# Le regole che non hanno un posto in un file: dicono dove valgono le altre
# (sezione 1), riguardano il nome di uno script (3.6), il pull request nel suo
# insieme (9.2, 10.5, 11.x) o ciò che manca (9.3, 10.2).
SENZA_RIGA = frozenset({"1.1", "1.2", "1.3", "3.6", "9.2", "9.3", "10.2",
                        "10.5", "11.1", "11.2", "11.3", "11.4"})
# Dopo l'esito possono stare poche righe, come «Fuori regola: …».
RIGHE_FINALI = 5
LUNGHEZZA_CITAZIONE = 120
# Un numero «7.1» intero: non 17.1, 7.10, v7.1, 7.1.2; PHP 8.3 non è una regola.
RE_NUMERO = re.compile(r"(?<![\w.])(?<!PHP )(?<!PHP )(\d{1,2}\.\d{1,2})"
                       r"(?![\w]|\.\d)")
RE_REGOLA = re.compile(r"^(\d+\.\d+) ", re.M)
RE_PERCORSO = re.compile(r"[\w./-]+\.(?:php|sql|md|css|json|xml|dist|lock)\b")
# Il numero di riga: percorso:42, riga 42, righe 12-14, r. 42, linea 42, L42, o
# una cella di tabella con il solo numero.
RE_NUMERO_RIGA = re.compile(
    r"\.\w+[`*]*:[`*]*L?\d{1,5}\b"
    r"|\b(?:[Rr]iga|[Rr]ighe|[Rr]r?\.|[Ll]ine[ae]|[Ll]ines?)\s*\d{1,5}\b"
    r"|\bL\d{1,5}\b"
    r"|\|\s*[`*]*\d{1,5}(?:\s*(?:[-–—,;]|e)\s*\d{1,5})*[`*]*\s*(?=\|)")
RE_ESITO = re.compile(r"\b(?:approvabile|da modificare)\b", re.IGNORECASE)


class Contesto(NamedTuple):
    """Ciò che i giudici sanno di un pull request."""
    pr: int
    inserite: List[str]
    regole: Set[str]
    percorsi: Set[str]


def impronta(pr: int, regola: str) -> str:
    testo = f"{SALE}:pr-{pr}:{regola}"
    return hashlib.sha256(testo.encode("utf-8")).hexdigest()


def _leggi(percorso: str) -> str:
    try:
        with open(percorso, encoding="utf-8") as fh:
            return fh.read()
    except (OSError, UnicodeDecodeError) as exc:
        raise prove.Problema(f"non riesco a leggere {percorso}: {exc}") from exc


def leggi_verita() -> Dict[str, List[str]]:
    """Le impronte di verita.json, per pull request. Raises: Problema."""
    percorso = os.path.join(ELEMENTO, "verita.json")
    try:
        voci = json.loads(_leggi(percorso))["pr"]
        if not isinstance(voci, dict) or not all(
                isinstance(v, list) for v in voci.values()):
            raise ValueError("«pr» non è una mappa di elenchi")
    except (ValueError, KeyError, TypeError) as exc:
        raise prove.Problema(f"{percorso} non si legge: {exc}") from exc
    return voci


def percorsi_del_progetto() -> Set[str]:
    """I file del progetto, relativi alla sua cartella. Raises: Problema."""
    base = os.path.join(RADICE, PROGETTO)
    trovati: Set[str] = set()
    for cartella, sotto, nomi in os.walk(base):
        sotto[:] = [s for s in sotto if s not in ("vendor", "_docente", ".git")]
        for nome in nomi:
            trovati.add(os.path.relpath(os.path.join(cartella, nome), base))
    if not trovati:
        raise prove.Problema(f"non trovo il progetto in {base}")
    return trovati


def percorsi_della_patch(pr: int) -> Set[str]:
    """I file di un pull request, relativi al progetto. Raises: Problema."""
    testo = _leggi(os.path.join(ELEMENTO, "prove", f"pr-{pr}.patch"))
    prefisso = f"+++ b/{PROGETTO}/"
    return {riga[len(prefisso):] for riga in testo.split("\n")
            if riga.startswith(prefisso)}


class Contesti:
    """I contesti dei giudici, uno per pull request, letti una volta sola."""

    def __init__(self) -> None:
        self.verita = leggi_verita()
        testo = _leggi(os.path.join(RADICE, PROGETTO, "docs", "convenzioni.md"))
        self.regole = set(RE_REGOLA.findall(testo))
        if not self.regole:
            raise prove.Problema("convenzioni.md non ha regole numerate")
        self.progetto = percorsi_del_progetto()
        self.letti: Dict[int, Contesto] = {}

    def di(self, ident: int, _configurazione: str) -> Contesto:
        """Il contesto del caso. Raises: Problema."""
        if ident in self.letti:
            return self.letti[ident]
        impronte = self.verita.get(str(ident))
        if impronte is None:
            raise prove.Problema(f"eval-{ident}: verita.json non ha il suo "
                                 "pull request")
        inserite = sorted((r for r in self.regole
                           if impronta(ident, r) in impronte),
                          key=lambda r: [int(n) for n in r.split(".")])
        if len(inserite) != len(impronte):
            raise prove.Problema(f"pr-{ident}: le impronte di verita.json non "
                                 "sono tutte regole delle convenzioni")
        contesto = Contesto(ident, inserite, self.regole,
                            self.progetto | percorsi_della_patch(ident))
        self.letti[ident] = contesto
        return contesto


def numeri_citati(testo: str) -> List[str]:
    """I numeri di forma «n.m» di un testo, senza ripetizioni, in ordine."""
    return list(dict.fromkeys(RE_NUMERO.findall(testo)))


def _citazione(riga: str) -> str:
    return riga.strip()[:LUNGHEZZA_CITAZIONE]


def giudica_regole(esec: prove.Esecuzione,
                   contesto: Contesto) -> Tuple[bool, str]:
    """Cita con il numero tutte le regole inserite nel pull request?"""
    citati = numeri_citati(esec.testo)
    mancano = [r for r in contesto.inserite if r not in citati]
    totale = len(contesto.inserite)
    evidenza = f"{totale - len(mancano)} su {totale}"
    if mancano:
        evidenza += f"; mancano: {', '.join(mancano)}"
    altre = [n for n in citati
             if n in contesto.regole and n not in contesto.inserite]
    if altre:
        evidenza += f"; altre citate: {', '.join(altre)}"
    fuori = [n for n in citati if n not in contesto.regole]
    if fuori:
        evidenza += f"; numeri che le convenzioni non hanno: {', '.join(fuori)}"
    return not mancano, evidenza


def _percorso_noto(token: str, percorsi: Set[str]) -> bool:
    """Vero se il testo è un file del progetto, intero o nella sua parte finale;
    anche scritto dalla radice dello spazio di lavoro."""
    pulito = token[2:] if token.startswith(("a/", "b/", "./")) else token
    if pulito.startswith(PROGETTO + "/"):
        pulito = pulito[len(PROGETTO) + 1:]
    return any(p == pulito or p.endswith("/" + pulito) for p in percorsi)


def ha_il_posto(riga: str, percorsi: Set[str]) -> bool:
    """Vero se una riga ha un percorso noto e un numero di riga."""
    if not any(_percorso_noto(t, percorsi) for t in RE_PERCORSO.findall(riga)):
        return False
    return RE_NUMERO_RIGA.search(riga) is not None


def giudica_righe(esec: prove.Esecuzione,
                  contesto: Contesto) -> Tuple[bool, str]:
    """Il file e la riga di ogni rilievo, sulla stessa riga della risposta."""
    righe = esec.testo.splitlines()
    citate = [n for n in numeri_citati(esec.testo) if n in contesto.regole]
    # Un rilievo è una regola inserita apposta che la risposta cita: una regola
    # nominata in prosa («la 5.2 è rispettata») non è un rilievo, e un numero
    # che resta solo nel discorso non chiede un posto. Le altre sono un dato.
    da_provare = [r for r in citate
                  if r in contesto.inserite and r not in SENZA_RIGA]
    con_posto = [r for r in righe if ha_il_posto(r, contesto.percorsi)]
    if not da_provare:
        if not con_posto:
            return False, ("nessuna riga con un percorso e un numero di riga, "
                           f"regole citate: {', '.join(citate) or 'nessuna'}")
        return True, (f"nessuna regola da collocare; file e riga in "
                      f"«{_citazione(con_posto[0])}»")
    mancano = [regola for regola in da_provare if not any(
        regola in numeri_citati(riga) for riga in con_posto)]
    trovate = len(da_provare) - len(mancano)
    evidenza = f"{trovate} su {len(da_provare)} con file e riga"
    if mancano:
        return False, (f"{evidenza}; senza, sulla stessa riga: "
                       f"{', '.join(mancano)}")
    esempio = next(riga for riga in con_posto
                   if da_provare[0] in numeri_citati(riga))
    senza = [r for r in citate
             if r in contesto.inserite and r in SENZA_RIGA]
    if senza:
        evidenza += f"; senza un posto nel file: {', '.join(senza)}"
    altre = [r for r in citate if r not in contesto.inserite and not any(
        r in numeri_citati(riga) for riga in con_posto)]
    if altre:
        evidenza += f"; altre citate senza il posto: {', '.join(altre)}"
    return True, f"{evidenza}, per esempio «{_citazione(esempio)}»"


def giudica_esito(esec: prove.Esecuzione,
                  _contesto: Contesto) -> Tuple[bool, str]:
    """«approvabile» o «da modificare» nelle ultime righe."""
    righe = [r for r in esec.testo.splitlines() if r.strip()]
    for riga in reversed(righe[-RIGHE_FINALI:]):
        if RE_ESITO.search(riga):
            return True, f"nelle righe finali: «{_citazione(riga)}»"
    return False, (f"nelle ultime {RIGHE_FINALI} righe né «approvabile» né "
                   "«da modificare»")


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


GIUDICI = {A_REGOLE: giudica_regole, A_RIGHE: giudica_righe,
           A_ESITO: giudica_esito, A_FILE: giudica_file}


def _citate_in(prova: prove.Prova, contesto: Contesto) -> Optional[int]:
    """Quante regole inserite cita una prova riuscita; None se non è riuscita."""
    if prova.esec is None or not prova.esec.completa or prova.esec.errore:
        return None
    citati = numeri_citati(prova.esec.testo)
    return sum(1 for r in contesto.inserite if r in citati)


def _stampa_pr(numero: int, ident: int, prove_caso: List[prove.Prova],
               contesto: Contesto) -> None:
    """Le regole citate di un pull request, per configurazione."""
    conti = {p.configurazione: _citate_in(p, contesto) for p in prove_caso}
    riuscite = {c: n for c, n in conti.items() if n is not None}
    if not riuscite:
        return
    totale = len(contesto.inserite)
    print(f"(dato) iterazione {numero}, pr-{ident}, regole inserite citate: "
          + "; ".join(f"{c} {n} su {totale}" for c, n in riuscite.items()))
    base = prove.baseline(riuscite)
    if base and "with_skill" in riuscite:
        print(f"(dato) iterazione {numero}, pr-{ident}, with_skill contro "
              f"{base}: {riuscite['with_skill']} e {riuscite[base]}: "
              f"{prove.verdetto(riuscite['with_skill'], riuscite[base])} "
              "(una sola esecuzione per caso)")


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
            _stampa_pr(numero, ident,
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
