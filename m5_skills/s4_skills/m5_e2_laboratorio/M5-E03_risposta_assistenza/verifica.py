#!/usr/bin/env python3
"""verifica.py di M5-E03 «Una skill di risposta nel tono di voce
dell'assistenza»: i giudici delle sei asserzioni di evals.json e il controllo
del lavoro, su tools/lib_controlla_prove.py. Legge gli stream, ogni volta da
capo.

I giudici, uno per asserzione, sul testo finale di ogni esecuzione:
  - il solo messaggio: la prima riga non è una premessa né un titolo, e dopo il
    messaggio non c'è un commento; l'evidenza cita la prima riga;
  - le parole da evitare: quelle della guida del tono e dello SKILL.md di
    esempio, con le forme della stessa parola, a parola intera; l'evidenza le
    nomina;
  - le emoji, per blocchi Unicode, e i punti esclamativi in serie;
  - la forma del canale, che sta qui per id (CANALI): in chat al massimo tre
    frasi e un passo numerato; nell'e-mail una riga «Oggetto:», un saluto con un
    nome, da due a quattro paragrafi, la firma; l'evidenza dice i conteggi;
  - il numero della segnalazione;
  - nessun valore dopo «password», mascherato nell'evidenza, e «area clienti».

Il tono non si decide: si stampa ogni risposta per intero, per una persona, e
il suo giudizio va in iteration-1/feedback.json.

Con --solo-prove (lo chiama tools/prove_skill.sh): la tabella e i dati, e scrive
timing.json, grading.json, benchmark.json e risposta.md. Senza: la tabella e i
dati, senza scrivere niente, e dice che cosa manca per finire.

Decidono l'uscita soltanto le garanzie (REPERTO) e, senza --solo-prove, ciò che
manca (MANCA): che il lavoro sia stato fatto. Le asserzioni, la skill chiamata o
no, la near-miss, i confronti, le risposte: dati, mai un'uscita.

Uso:    verifica.py <spazio di lavoro> [--solo-prove]
Env:    PN_HANDSON_ROOT  il repository (default: la radice sopra l'elemento)
Uscita: 0 fatto (o, con --solo-prove, letto) · 1 un reperto, o qualcosa che
        manca · 2 precondizione (argomenti, spazio di lavoro, un caso senza il
        suo canale, uno stream che non si legge) o un errore inatteso
"""
from __future__ import annotations

import os
import re
import sys
from typing import List, Optional, Tuple

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

SKILL = "risposta-assistenza"
USO = "Uso: verifica.py <spazio di lavoro> [--solo-prove]"
A_SOLO_TESTO = "Contiene il solo testo del messaggio, senza premesse"
A_PAROLE = "Non usa le parole da evitare della guida"
A_EMOJI = "Non contiene emoji né punti esclamativi in serie"
A_CANALE = "Rispetta la forma del canale"
A_NUMERO = "Riporta il numero della segnalazione"
A_PASSWORD = "Non scrive una password e indica l'area clienti"
# Il canale di ogni caso di evals.json.
CANALI = {1: "chat", 2: "e-mail", 3: "chat"}
NUMERO = "TK-2026-04600"
FIRMA = "Il team di assistenza CiaspoLink"
MASSIMO_FRASI = 3
MASSIMO_PASSI = 1
PARAGRAFI_MINIMI = 2
PARAGRAFI_MASSIMI = 4
LUNGHEZZA_CITAZIONE = 120
VUOTA = "la risposta è vuota"
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
RE_PREMESSA = re.compile(
    r"^\W*(?:ecco\b|di seguito\b|qui sotto\b|ti propongo\b|ti suggerisco\b"
    r"|ho preparato\b|ho scritto\b|potresti\b"
    r"|puoi\s+(?:rispondere|rispondergli|risponderle|scrivergli|scriverle"
    r"|dirgli|dirle)\b"
    r"|(?:gli\s+|le\s+)?risponderei\b|rispondigli\b|rispondile\b"
    r"|scrivigli\b|scrivile\b"
    r"|(?:risposta|messaggio|bozza|proposta)\b[^.\n]{0,40}:)",
    re.IGNORECASE)
RE_TITOLO = re.compile(r"^(?:#{1,6}\s|\*\*[^*]+\*\*:?$)")
RE_OGGETTO = re.compile(r"^\W*oggetto\s*:", re.IGNORECASE)
RE_COMMENTO = re.compile(
    r"^\W*(?:nota\b|n\.\s?b\.|ho\s+(?:usato|scritto|tenuto|preparato|evitato"
    r"|omesso|seguito|adattato|scelto)\b"
    r"|(?:questo|il)\s+messaggio\s+(?:è|segue|usa|tiene|resta|rispetta)\b"
    r"|(?:questa|la)\s+risposta\s+(?:è|segue|usa|tiene|resta|rispetta)\b"
    r"|se\s+vuoi\b[^.\n]*\b(?:adatt|riscriv|cambi|accorci|modific|allung)"
    r"|posso\s+(?:adattar|riscriver|cambiar|accorciar|modificar|allungar)"
    r"|vuoi\s+che\s+(?:aggiung|prepar|scriv|riscriv|cambi|adatt|modific"
    r"|accorc|trasform)"
    r"|fammi\s+sapere\s+se\s+(?:vuoi|preferisci))",
    re.IGNORECASE)
# Un separatore o la chiusura di un blocco di codice: ciò che viene dopo non è
# il messaggio.
RE_SEPARATORE = re.compile(r"^(?:-{3,}|\*{3,}|_{3,}|```.*)$")
RE_EMOJI = re.compile("[\U0001F000-\U0001FAFF☀-➿⭐⭕]")
RE_ESCLAMATIVI = re.compile(r"!\s*!")
RE_PASSO = re.compile(r"^\W{0,2}\d+[.)]\s")
RE_VOCE = re.compile(r"^\s*(?:[-*•]|\d+[.)])\s")
# Le abbreviazioni il cui punto non chiude una frase.
RE_ABBREVIAZIONE = re.compile(
    r"\b(?:sig|sigg|dott|ing|avv|geom|arch|rag|prof|es|ecc|nr|n|tel|art)\.",
    re.IGNORECASE)
RE_FINE_FRASE = re.compile(r"[.!?…]+[»\"”')\]*_`]*(?:\s+|$)|\n+")
RE_SALUTO = re.compile(
    r"^\W*(?i:buongiorno|buonasera|salve|gentile|gentilissim[oa]|egregi[oa]"
    r"|car[oa]|spett\S*)\s+"
    r"(?:(?i:signor|signora|sig\.|sig\.ra|dott\.|dott\.ssa|dottor|dottoressa"
    r"|ing\.|avv\.|geom\.|arch\.|rag\.|prof\.|prof\.ssa)\s+)?"
    r"(?P<nome>[A-ZÀ-Ý][\w'’-]+)")
NON_NOMI = frozenset({"Cliente", "Clienti", "Signore", "Signora", "Team"})
LUNGHEZZA_SALUTO = 60
RE_SALUTI_FINALI = re.compile(
    r"^\W*(?:cordiali saluti|distinti saluti|un cordiale saluto|saluti"
    r"|a presto|buona giornata|buon lavoro)\W*$", re.IGNORECASE)
RE_AREA_CLIENTI = re.compile(r"area\s+clienti", re.IGNORECASE)
# «password», un'eventuale specificazione, un segno o «è», e ciò che viene dopo.
RE_DOPO_PASSWORD = re.compile(
    r"password(?:\s+(?:della|del|di|dell['’])\s*\w+)?\s*"
    r"(?P<segno>[:=]|\bè\b|\bsarebbe\b)\s*(?P<resto>[^\n]*)", re.IGNORECASE)
RE_VALORE = re.compile(r"[*_]*(?P<virgolette>[`\"“'‘]?)[*_]*"
                       r"(?P<valore>[^\s`\"”'’,;:.!?()*_]+"
                       r"(?:[-.@#_+/][^\s`\"”'’,;:!?()*_]+)*)")


def _citazione(riga: str) -> str:
    return riga.strip()[:LUNGHEZZA_CITAZIONE]


def _righe_piene(testo: str) -> List[str]:
    return [riga for riga in testo.splitlines() if riga.strip()]


def _commento_dopo(testo: str) -> Optional[str]:
    """Il testo che viene dopo il messaggio: dopo la firma, dopo un separatore
    o la chiusura di un blocco di codice, o un ultimo paragrafo che parla del
    messaggio. None se non c'è."""
    righe = _righe_piene(testo)
    for i, riga in enumerate(righe):
        if FIRMA in riga and i + 1 < len(righe):
            return righe[i + 1]
    for i in range(len(righe) - 1, 0, -1):
        if RE_SEPARATORE.match(righe[i].strip()):
            return righe[i + 1] if i + 1 < len(righe) else None
    paragrafo = re.split(r"\n\s*\n", testo.strip())[-1]
    prime = paragrafo.splitlines()[0].strip()
    ultima = righe[-1].strip()
    for candidata in (prime, ultima):
        if RE_COMMENTO.match(candidata):
            return candidata
    return None


def giudica_solo_testo(esec: prove.Esecuzione,
                       _contesto: object) -> Tuple[bool, str]:
    """La prima riga non è una premessa, e dopo il messaggio non c'è altro."""
    righe = _righe_piene(esec.testo)
    if not righe:
        return False, VUOTA
    prima = righe[0].strip()
    evidenza = f"prima riga: «{_citazione(prima)}»"
    oggetto = RE_OGGETTO.match(prima) is not None
    if not oggetto and (RE_PREMESSA.match(prima) or RE_TITOLO.match(prima)):
        return False, f"{evidenza}: è una premessa o un titolo"
    commento = _commento_dopo(esec.testo)
    if commento:
        return False, (f"{evidenza}; dopo il messaggio: "
                       f"«{_citazione(commento)}»")
    return True, f"{evidenza}; nessun commento dopo il messaggio"


def giudica_parole(esec: prove.Esecuzione,
                   _contesto: object) -> Tuple[bool, str]:
    """Nessuna parola da evitare; l'evidenza nomina quelle trovate."""
    if not esec.testo.strip():
        return False, VUOTA
    trovate = list(dict.fromkeys(
        " ".join(m.group(0).split()) for m in RE_PAROLE.finditer(esec.testo)))
    if trovate:
        return False, f"trovate: {', '.join(trovate)}"
    return True, f"nessuna delle {len(PAROLE_DA_EVITARE)} voci della guida"


def giudica_emoji(esec: prove.Esecuzione,
                  _contesto: object) -> Tuple[bool, str]:
    """Nessuna emoji, nessun «!!»."""
    if not esec.testo.strip():
        return False, VUOTA
    emoji = list(dict.fromkeys(RE_EMOJI.findall(esec.testo)))
    if emoji:
        return False, f"emoji: {' '.join(emoji)}"
    if RE_ESCLAMATIVI.search(esec.testo):
        return False, "punti esclamativi in serie: !!"
    return True, "nessuna emoji e nessun !!"


def _frasi(testo: str) -> int:
    """Le frasi di un testo: finisce con un punto o con una riga a capo."""
    pulito = RE_ABBREVIAZIONE.sub(lambda m: m.group(0)[:-1], testo)
    return sum(1 for pezzo in RE_FINE_FRASE.split(pulito)
               if pezzo and any(c.isalnum() for c in pezzo))


def _forma_chat(testo: str) -> Tuple[bool, str]:
    """Al massimo tre frasi e un passo numerato; la frase del passo non si
    conta."""
    righe = testo.splitlines()
    passi = sum(1 for riga in righe if RE_PASSO.match(riga))
    frasi = _frasi("\n".join(r for r in righe if not RE_PASSO.match(r)))
    giusta = frasi <= MASSIMO_FRASI and passi <= MASSIMO_PASSI
    quante = "1 frase" if frasi == 1 else f"{frasi} frasi"
    nome = "1 passo numerato" if passi == 1 else f"{passi} passi numerati"
    return giusta, (f"chat: {quante}, {nome}; al massimo {MASSIMO_FRASI} "
                    "frasi e un passo")


def _saluto(riga: str) -> Optional[str]:
    trovato = RE_SALUTO.match(riga.strip())
    if trovato and trovato.group("nome") not in NON_NOMI:
        return riga.strip()
    return None


def _paragrafi(testo: str) -> int:
    """I paragrafi del corpo: senza oggetto, saluto, saluti finali e firma; un
    elenco sta con il paragrafo che lo introduce."""
    tenute: List[str] = []
    for riga in testo.splitlines():
        pura = riga.strip()
        fuori = (RE_OGGETTO.match(pura) or FIRMA in pura
                 or RE_SALUTI_FINALI.match(pura)
                 or (RE_SALUTO.match(pura) and len(pura) <= LUNGHEZZA_SALUTO))
        tenute.append("" if fuori else riga)
    blocchi = re.split(r"\n\s*\n", "\n".join(tenute))
    return sum(1 for blocco in blocchi if blocco.strip() and not all(
        RE_VOCE.match(riga) for riga in _righe_piene(blocco)))


def _forma_email(testo: str) -> Tuple[bool, str]:
    righe = [riga.strip() for riga in _righe_piene(testo)]
    oggetto = any(RE_OGGETTO.match(riga) for riga in righe)
    saluti = [s for s in (_saluto(riga) for riga in righe) if s]
    firma = any(FIRMA in riga for riga in righe)
    paragrafi = _paragrafi(testo)
    giusta = (oggetto and bool(saluti) and firma
              and PARAGRAFI_MINIMI <= paragrafi <= PARAGRAFI_MASSIMI)
    saluto = f"sì, «{_citazione(saluti[0])}»" if saluti else "no"
    quanti = "1 paragrafo" if paragrafi == 1 else f"{paragrafi} paragrafi"
    return giusta, (f"e-mail: Oggetto: {'sì' if oggetto else 'no'}; saluto con "
                    f"un nome: {saluto}; {quanti}, da "
                    f"{PARAGRAFI_MINIMI} a {PARAGRAFI_MASSIMI}; firma: "
                    f"{'sì' if firma else 'no'}")


def giudica_canale(esec: prove.Esecuzione, canale: str) -> Tuple[bool, str]:
    """La forma del canale del caso; l'evidenza dice i conteggi."""
    if not esec.testo.strip():
        return False, VUOTA
    if canale == "chat":
        return _forma_chat(esec.testo)
    return _forma_email(esec.testo)


def giudica_numero(esec: prove.Esecuzione,
                   _contesto: object) -> Tuple[bool, str]:
    """Il numero della segnalazione nel testo; l'evidenza cita la riga."""
    for riga in esec.testo.splitlines():
        if NUMERO in riga:
            return True, f"in «{_citazione(riga)}»"
    return False, f"{NUMERO} non c'è"


def _maschera(valore: str) -> str:
    return f"{valore[:2]}…"


def _valore_dopo_password(testo: str) -> Optional[str]:
    """Un valore che sembra una password, dopo «password» e un segno o «è»:
    con una cifra o un simbolo, con maiuscole dentro la parola, fra virgolette,
    o, dopo i due punti o l'uguale, una parola sola fino alla fine della riga.
    Le parole di una frase («è nell'area clienti», «: la trovi») non lo sono."""
    for trovato in RE_DOPO_PASSWORD.finditer(testo):
        valore = RE_VALORE.match(trovato.group("resto"))
        if valore is None or not valore.group("valore"):
            continue
        parola = valore.group("valore")
        dopo = trovato.group("resto")[valore.end():].strip(" *_`\"”'’.,;:!?)")
        da_solo = trovato.group("segno") in ":=" and not dopo
        if (any(c.isdigit() or c in "@#$%&=+/\\" for c in parola)
                or any(c.isupper() for c in parola[1:])
                or valore.group("virgolette") or da_solo):
            return parola
    return None


def giudica_password(esec: prove.Esecuzione,
                     _contesto: object) -> Tuple[bool, str]:
    """Nessun valore dopo «password», e l'area clienti nominata."""
    if not esec.testo.strip():
        return False, VUOTA
    valore = _valore_dopo_password(esec.testo)
    if valore:
        return False, f"dopo «password» un valore: {_maschera(valore)}"
    area = RE_AREA_CLIENTI.search(esec.testo)
    if area is None:
        return False, "nessun valore dopo «password», ma «area clienti» non c'è"
    return True, f"nessun valore dopo «password»; «{area.group(0)}» c'è"


GIUDICI = {A_SOLO_TESTO: giudica_solo_testo, A_PAROLE: giudica_parole,
           A_EMOJI: giudica_emoji, A_CANALE: giudica_canale,
           A_NUMERO: giudica_numero, A_PASSWORD: giudica_password}


def canale_di(ident: int, _configurazione: str) -> str:
    """Il canale del caso. Raises: Problema."""
    canale = CANALI.get(ident)
    if canale is None:
        raise prove.Problema(f"eval-{ident}: verifica.py non ha il suo canale: "
                             "i casi di prova sono quelli di partenza")
    return canale


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


def _stampa_testi(numero: int, iterazione: prove.Iterazione) -> None:
    """Ogni risposta, intera, con la sua lunghezza: old_skill non si ristampa,
    è il testo dell'iterazione prima."""
    for prova in iterazione.prove:
        if prova.configurazione == "old_skill" or prova.esec is None \
                or not prova.esec.completa:
            continue
        conta = len(prova.esec.testo.split())
        parole = "1 parola" if conta == 1 else f"{conta} parole"
        print(f"\niterazione {numero}, eval-{prova.eval_id}, "
              f"{prova.configurazione}, {parole}:")
        for riga in prova.esec.testo.splitlines():
            print(f"  | {riga}".rstrip())


def stampa_dati(esame: prove.Esame) -> None:
    """I dati che non decidono l'uscita."""
    if not esame.iterazioni:
        return
    print("\nCome dati, mai come uscita:")
    for numero in sorted(esame.iterazioni):
        _stampa_chiamate(numero, esame.iterazioni[numero])
    print("\nDa leggere, per una persona: il tono non lo decide il controllo.")
    for numero in sorted(esame.iterazioni):
        _stampa_testi(numero, esame.iterazioni[numero])


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
    esame = prove.esamina(ws, SKILL, GIUDICI, canale_di, scrivi=solo_prove)
    stampa_dati(esame)
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
