"""controlla_istruzioni.py -- il controllo di M2-D01, prompt A contro
prompt B.

Lo esegue verifica.sh, nella cartella sopra demo/; nello spazio di lavoro
ne trovate una copia, da leggere. Legge confronto.tsv nello spazio di
lavoro: l'intestazione «prompt<TAB>token_entrata<TAB>token_uscita<TAB>
risposta» e le righe A e B, con la risposta su una riga, come le scrivono
i passi del README e _docente/live.sh; se una riga c'è più volte, vale
l'ultima.

Stampa i numeri che legge (token in entrata e in uscita, parole) e che
cosa contiene ogni risposta: la tabella, «non indicato», il nome e il
telefono del cliente. Per A sono soltanto dati: A non chiede niente.
Poi un esito per ogni affermazione:
  - cinque istruzioni del prompt B, sotto la raccomandazione di Anthropic
    sulle istruzioni chiare ed esplicite: «rispettata» o «non rispettata
    in questa esecuzione»; l'uscita non cambia:
      colonne       la prima tabella Markdown ha le colonne Problema,
                    Quando, Impatto, Priorità, Team proposto, in
                    quest'ordine e nessun'altra: l'intestazione sopra la
                    riga dei trattini («Priorità» può continuare, per
                    esempio con «(bassa/media/alta/urgente)»; il grassetto
                    e le maiuscole non contano);
      non indicato  «non indicato» compare almeno una volta;
      nome          non compaiono «Franco», «Fittizio» né «Fittizia», con
                    la maiuscola: chi scrive e la sua azienda;
      telefono      non compare 000 000 0103, con o senza spazi, punti o
                    trattini fra i gruppi;
      parole        al massimo 120: una parola è una sequenza di lettere o
                    cifre, e un apostrofo la unisce alla seguente
                    («l'assistenza» è una parola); i segni della tabella e
                    del grassetto non contano;
  - una garanzia: i token in entrata di B sono più di quelli di A. B manda
    lo stesso messaggio e lo stesso system prompt di A, con cinque righe
    al posto di «Riassumi.», e per la documentazione i tre campi dei token
    in entrata sono tutto l'input: «confermata», oppure «non confermata in
    questa esecuzione» e l'uscita 1.

Uso:    python3 controlla_istruzioni.py <spazio di lavoro>
Uscita: 0 le due risposte ci sono e la garanzia è confermata · 1
        confronto.tsv assente o incompleto (l'intestazione, una risposta, un
        numero di token), o la garanzia non confermata · 2 precondizione:
        argomenti sbagliati, spazio di lavoro assente, confronto.tsv che
        non si legge; mai un traceback: un errore inatteso esce 2, con un
        messaggio di una riga
"""
from __future__ import annotations

import os
import re
import sys
from typing import Dict, List, NamedTuple, Optional

FILE = "confronto.tsv"
INTESTAZIONE = "prompt\ttoken_entrata\ttoken_uscita\trisposta"
PROMPT = (("A", "A, «Riassumi.»"), ("B", "B, il prompt di cinque righe"))
MASSIMO_PAROLE = 120
# Le cinque celle d'intestazione attese, sul testo ripulito e in minuscolo;
# «Priorità» può continuare.
CELLE = (re.compile(r"problema"), re.compile(r"quando"),
         re.compile(r"impatto"), re.compile(r"priorit[àa]\b.*"),
         re.compile(r"team proposto"))
# La riga dei trattini di una tabella Markdown: celle di soli trattini, con
# i due punti dell'allineamento, separate da barre verticali. Non comincia
# dentro una fila di trattini o dopo due punti, così la ricerca resta
# lineare anche su una fila lunghissima.
TRATTINI = re.compile(
    r"(?<![-:])\|?[ \t]*:?-+:?[ \t]*(?:\|[ \t]*:?-+:?[ \t]*)+\|?")
NON_INDICATO = re.compile(r"non\s+indicato", re.IGNORECASE)
NOME = re.compile(r"\b(?:Franco|Fittizio|Fittizia)\b")
TELEFONO = re.compile(r"000[ .-]?000[ .-]?0103")
PAROLA = re.compile(r"[^\W_]+(?:['’][^\W_]+)*")

# Che cosa contiene una risposta.
Esame = NamedTuple("Esame", [("parole", int), ("celle", Optional[List[str]]),
                             ("colonne", bool), ("non_indicato", bool),
                             ("nome", bool), ("telefono", bool)])
# Una riga di confronto.tsv con i suoi numeri.
Riga = NamedTuple("Riga", [("entrata", int), ("uscita", str),
                           ("risposta", str)])


def errore(messaggio: str) -> None:
    """Una diagnostica di una riga su STDERR."""
    sys.stderr.write("verifica: %s\n" % messaggio)


def intestazione(testo: str) -> Optional[List[str]]:
    """Le celle d'intestazione della prima tabella Markdown del testo, senza
    grassetto né spazi in più; None se il testo non ha una riga di
    trattini. Le celle sono quante quelle della riga di trattini. In una
    tabella senza la barra iniziale la prima cella si porta dietro il testo
    che precede la tabella (in confronto.tsv le righe sono unite da spazi):
    di quella cella resta l'ultima parola."""
    trattini = TRATTINI.search(testo)
    if trattini is None:
        return None
    quante = len(re.findall(r"-+", trattini.group(0)))
    sopra = testo[:trattini.start()].rstrip()
    if sopra.endswith("|"):
        sopra = sopra[:-1]
    celle = [" ".join(re.sub(r"[*`]+", "", cella).strip(" _").split())
             for cella in sopra.split("|")[-quante:]]
    if not trattini.group(0).lstrip(" \t").startswith("|"):
        celle[0] = (celle[0].split() or [""])[-1]
    return celle


def esamina(testo: str) -> Esame:
    """Che cosa contiene una risposta: parole, tabella, formule, dati."""
    celle = intestazione(testo)
    colonne = (celle is not None and len(celle) == len(CELLE)
               and all(regola.fullmatch(cella.casefold())
                       for regola, cella in zip(CELLE, celle)))
    return Esame(len(PAROLA.findall(testo)), celle, colonne,
                 NON_INDICATO.search(testo) is not None,
                 NOME.search(testo) is not None,
                 TELEFONO.search(testo) is not None)


def leggi(percorso: str) -> Optional[Dict[str, List[str]]]:
    """I campi delle righe di confronto.tsv, per prompt (vale l'ultima
    riga); None, dopo un messaggio, se l'intestazione non è quella.
    Solleva OSError se il file non si legge."""
    with open(percorso, "rb") as fh:
        testo = fh.read().decode("utf-8-sig", errors="replace")
    righe = [r[:-1] if r.endswith("\r") else r for r in testo.split("\n")]
    if righe[0] != INTESTAZIONE:
        print("%s: la prima riga deve essere l'intestazione «prompt<TAB>"
              "token_entrata<TAB>token_uscita<TAB>risposta»." % FILE)
        return None
    campi: Dict[str, List[str]] = {}
    for riga in righe[1:]:
        if riga.strip():
            parti = (riga.split("\t", 3) + ["", "", ""])[:4]
            campi[parti[0].strip()] = parti
    return campi


def numero(campo: str) -> Optional[int]:
    """Un conteggio di token scritto in cifre; None altrimenti."""
    campo = campo.strip()
    return int(campo) if re.fullmatch(r"[0-9]+", campo) else None


def complete(campi: Dict[str, List[str]]) -> Optional[Dict[str, Riga]]:
    """Le righe A e B con la risposta e i token in entrata; None, dopo un
    messaggio per ogni dato che manca, se non sono complete."""
    vuota = ["", "", "", ""]
    manca = False
    for p, _ in PROMPT:
        if not campi.get(p, vuota)[3].strip():
            print("Manca la risposta al prompt %s." % p)
            manca = True
    entrata = {p: numero(campi.get(p, vuota)[1]) for p, _ in PROMPT}
    if not manca and None in entrata.values():
        print("Token in entrata di A o di B mancanti o non numerici.")
        manca = True
    if manca:
        print("Rifate i passi 2 e 3 del README, su un %s ricreato con la "
              "sua intestazione." % FILE)
        return None
    return {p: Riga(entrata[p] or 0, campi[p][2].strip() or "?",
                    campi[p][3]) for p, _ in PROMPT}


def sino(valore: bool) -> str:
    """sì oppure no."""
    return "sì" if valore else "no"


def stampa_dati(righe: Dict[str, Riga], esami: Dict[str, Esame]) -> None:
    """I numeri letti e che cosa contiene ogni risposta."""
    print("I numeri letti in %s:" % FILE)
    for p, nome in PROMPT:
        print("  %s: %d token in entrata, %s in uscita; %d parole"
              % (nome, righe[p].entrata, righe[p].uscita, esami[p].parole))
    a, b = esami["A"], esami["B"]
    print("Che cosa contiene ogni risposta (per A sono soltanto dati: A non "
          "chiede niente):")
    print("  la tabella: A %s · B %s" % tuple(
        "con le colonne " + " | ".join(e.celle) if e.celle else "nessuna"
        for e in (a, b)))
    print("  «non indicato»: A %s · B %s"
          % (sino(a.non_indicato), sino(b.non_indicato)))
    print("  il nome del cliente: A %s · B %s"
          % (sino(a.nome), sino(b.nome)))
    print("  il telefono del cliente: A %s · B %s"
          % (sino(a.telefono), sino(b.telefono)))


def stampa_istruzioni(b: Esame) -> None:
    """L'esito di ciascuna delle cinque istruzioni di B."""
    print("Cinque istruzioni del prompt B (raccomandazioni: un esito "
          "negativo si legge e non fa fallire la verifica):")
    esiti = (("le colonne Problema, Quando, Impatto, Priorità, Team "
              "proposto", b.colonne),
             ("«non indicato» dove manca un dato", b.non_indicato),
             ("niente nome del cliente", not b.nome),
             ("niente telefono del cliente", not b.telefono),
             ("al massimo %d parole" % MASSIMO_PAROLE,
              b.parole <= MASSIMO_PAROLE))
    for istruzione, rispettata in esiti:
        print("  %s: %s" % (istruzione, "rispettata" if rispettata
                            else "non rispettata in questa esecuzione"))


def stampa_garanzia(righe: Dict[str, Riga]) -> bool:
    """L'esito della garanzia sui token in entrata; vero se confermata."""
    confermata = righe["B"].entrata > righe["A"].entrata
    print("La garanzia (B manda lo stesso messaggio e lo stesso system "
          "prompt di A, con cinque righe al posto di «Riassumi.»):")
    print("  più token in entrata per B che per A: %s"
          % ("confermata" if confermata
             else "non confermata in questa esecuzione"))
    if not confermata:
        print("La documentazione garantisce che i token in entrata contano "
              "tutto l'input, e quello di B è più lungo di quello di A: in "
              "questa esecuzione no.")
        print("Controllate di non avere scambiato le righe: A è "
              "«Riassumi.», B il prompt di cinque righe, con le stesse "
              "opzioni.")
    return confermata


def controlla(spazio: str) -> int:
    """Il controllo di uno spazio di lavoro; l'uscita del contratto."""
    if not os.path.isdir(spazio):
        errore("spazio di lavoro assente: %s" % spazio)
        return 2
    percorso = os.path.join(spazio, FILE)
    if not os.path.exists(percorso):
        print("Manca %s: eseguite i passi del README." % FILE)
        return 1
    try:
        campi = leggi(percorso)
    except OSError:
        errore("%s non si legge" % FILE)
        return 2
    righe = complete(campi) if campi is not None else None
    if righe is None:
        return 1
    esami = {p: esamina(righe[p].risposta) for p, _ in PROMPT}
    stampa_dati(righe, esami)
    stampa_istruzioni(esami["B"])
    return 0 if stampa_garanzia(righe) else 1


def main(argv: List[str]) -> int:
    for flusso in (sys.stdout, sys.stderr):
        if hasattr(flusso, "reconfigure"):
            flusso.reconfigure(errors="replace")
    if len(argv) != 1:
        sys.stderr.write(__doc__)
        return 2
    try:
        return controlla(argv[0])
    except Exception as exc:  # mai un traceback: il contratto dice 2
        errore("errore inatteso (%s: %s)" % (type(exc).__name__, exc))
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
