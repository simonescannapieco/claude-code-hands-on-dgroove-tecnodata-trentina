"""controlla_sistema.py -- il controllo di M2-D02, il system prompt che
non vedete.

Lo esegue verifica.sh, nella cartella sopra demo/; nello spazio di lavoro
ne trovate una copia, da leggere. Legge sistema.tsv nello spazio di
lavoro: l'intestazione «variante<TAB>token_entrata<TAB>risposta» e le
righe predefinito, aggiunto e sostituito, come le scrivono i passi del
README e _docente/live.sh; se una riga c'è più volte, vale l'ultima.

Stampa i numeri che legge (i token in entrata e la risposta di ogni
variante) e, come dati, le differenze fra le chiamate; poi un esito per
ogni affermazione:
  - due garanzie della documentazione di Claude Code, che decidono
    l'uscita e confrontano le tre chiamate fra loro:
      --system-prompt sostituisce l'intero prompt predefinito: i token in
      entrata di «sostituito» sono meno di quelli di «predefinito»,
      benché il prompt sostituito contenga la riga e il predefinito no;
      --append-system-prompt aggiunge al prompt predefinito: «aggiunto»
      ha più token in entrata di «predefinito».
    Le tre chiamate differiscono soltanto per l'opzione: il resto (la
    domanda, e ciò che non fa parte del system prompt, come un CLAUDE.md
    personale) pesa lo stesso in tutte e tre e nel confronto si cancella.
    «confermata», oppure «non confermata in questa esecuzione» e l'uscita
    1;
  - l'istruzione «Rispondi solo: ok», per ogni variante, sotto la
    raccomandazione di Anthropic sulle istruzioni chiare ed esplicite:
    «rispettata» se la risposta, tolti spazi e punti ai bordi e senza
    badare alle maiuscole, è «ok», altrimenti «non rispettata in questa
    esecuzione»; l'uscita non cambia.

Uso:    python3 controlla_sistema.py <spazio di lavoro>
Uscita: 0 le tre righe ci sono e le due garanzie sono confermate · 1
        sistema.tsv assente o incompleto (l'intestazione, una risposta, un
        numero di token), o una garanzia non confermata · 2 precondizione:
        argomenti sbagliati, spazio di lavoro assente, sistema.tsv che non
        si legge; mai un traceback: un errore inatteso esce 2, con un
        messaggio di una riga
"""
from __future__ import annotations

import os
import re
import string
import sys
from typing import Dict, List, NamedTuple, Optional

FILE = "sistema.tsv"
INTESTAZIONE = "variante\ttoken_entrata\trisposta"
VARIANTI = ("predefinito", "aggiunto", "sostituito")
LUNGHEZZA_MAX = 60
BORDI = string.whitespace + "."

# Una riga di sistema.tsv con il suo numero.
Riga = NamedTuple("Riga", [("entrata", int), ("risposta", str)])


def errore(messaggio: str) -> None:
    """Una diagnostica di una riga su STDERR."""
    sys.stderr.write("verifica: %s\n" % messaggio)


def leggi(percorso: str) -> Optional[Dict[str, List[str]]]:
    """I campi delle righe di sistema.tsv, per variante (vale l'ultima
    riga); None, dopo un messaggio, se l'intestazione non è quella.
    Solleva OSError se il file non si legge."""
    with open(percorso, "rb") as fh:
        testo = fh.read().decode("utf-8-sig", errors="replace")
    righe = [r[:-1] if r.endswith("\r") else r for r in testo.split("\n")]
    if righe[0] != INTESTAZIONE:
        print("%s: la prima riga deve essere l'intestazione «variante<TAB>"
              "token_entrata<TAB>risposta»." % FILE)
        return None
    campi: Dict[str, List[str]] = {}
    for riga in righe[1:]:
        if riga.strip():
            parti = (riga.split("\t", 2) + ["", ""])[:3]
            campi[parti[0].strip()] = parti
    return campi


def numero(campo: str) -> Optional[int]:
    """Un conteggio di token scritto in cifre; None altrimenti."""
    campo = campo.strip()
    return int(campo) if re.fullmatch(r"[0-9]+", campo) else None


def complete(campi: Dict[str, List[str]]) -> Optional[Dict[str, Riga]]:
    """Le tre righe con il numero di token e la risposta; None, dopo un
    messaggio per ogni dato che manca, se non sono complete."""
    vuota = ["", "", ""]
    righe: Dict[str, Riga] = {}
    for v in VARIANTI:
        entrata = numero(campi.get(v, vuota)[1])
        risposta = campi.get(v, vuota)[2].strip()
        if entrata is None:
            print("Manca il numero di token della variante %s." % v)
        if not risposta:
            print("Manca la risposta della variante %s." % v)
        if entrata is not None and risposta:
            righe[v] = Riga(entrata, risposta)
    if len(righe) < len(VARIANTI):
        print("Rifate i passi 2 e 3 del README, su un %s ricreato con la "
              "sua intestazione." % FILE)
        return None
    return righe


def stampa_dati(righe: Dict[str, Riga]) -> None:
    """I numeri letti: token in entrata e risposta di ogni variante."""
    print("I numeri letti in %s (token in entrata: la somma dei tre campi "
          "di usage):" % FILE)
    for v in VARIANTI:
        risposta = righe[v].risposta
        if len(risposta) > LUNGHEZZA_MAX:
            risposta = risposta[:LUNGHEZZA_MAX] + "…"
        print("  %-12s %d token in entrata, risposta «%s»"
              % (v, righe[v].entrata, risposta))
    print("  %s" % differenze(*(righe[v].entrata for v in VARIANTI)))


def differenze(p: int, a: int, s: int) -> str:
    """Le differenze fra predefinito (p), aggiunto (a) e sostituito (s),
    in parole: dati, non esiti."""
    prima = ("il predefinito pesa %d token più di sostituito" % (p - s)
             if p >= s else
             "il predefinito pesa %d token meno di sostituito" % (s - p))
    seconda = ("la riga in coda ne aggiunge %d" % (a - p) if a >= p
               else "la riga in coda ne toglie %d" % (p - a))
    return "%s; %s" % (prima, seconda)


def esito(affermazione: str, parola: str, vale: bool) -> None:
    """Una riga d'esito: «confermata»/«rispettata» o la sua negazione."""
    print("  %s: %s" % (affermazione, parola if vale
                        else "non %s in questa esecuzione" % parola))


def stampa_garanzie(righe: Dict[str, Riga]) -> bool:
    """Le due garanzie, e che cosa non torna; vero se confermate."""
    p, a, s = (righe[v].entrata for v in VARIANTI)
    sostituito, aggiunto = s < p, a > p
    print("Le garanzie della documentazione di Claude Code, che confrontano "
          "le tre chiamate fra loro: --system-prompt «Sostituisce l'intero "
          "prompt predefinito», --append-system-prompt «Aggiunge al prompt "
          "predefinito»:")
    esito("con --system-prompt meno token in entrata del predefinito, "
          "benché la riga ci sia", "confermata", sostituito)
    esito("con --append-system-prompt più token in entrata del predefinito",
          "confermata", aggiunto)
    if not sostituito:
        print("Con il system prompt sostituito attesi meno token in entrata "
              "del predefinito: sostituito %d, predefinito %d." % (s, p))
        print("La documentazione garantisce che --system-prompt sostituisce "
              "l'intero prompt predefinito: in questa esecuzione no.")
    if not aggiunto:
        print("Con la riga in coda attesi più token in entrata del "
              "predefinito: aggiunto %d, predefinito %d." % (a, p))
        print("La documentazione garantisce che --append-system-prompt "
              "aggiunge al prompt predefinito: in questa esecuzione no.")
    return sostituito and aggiunto


def stampa_istruzione(righe: Dict[str, Riga]) -> None:
    """L'istruzione «Rispondi solo: ok», variante per variante."""
    print("L'istruzione «Rispondi solo: ok» (una raccomandazione: un esito "
          "negativo si legge e non fa fallire la verifica):")
    for v in VARIANTI:
        esito(v, "rispettata",
              righe[v].risposta.strip(BORDI).casefold() == "ok")


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
    stampa_dati(righe)
    confermate = stampa_garanzie(righe)
    stampa_istruzione(righe)
    return 0 if confermate else 1


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
