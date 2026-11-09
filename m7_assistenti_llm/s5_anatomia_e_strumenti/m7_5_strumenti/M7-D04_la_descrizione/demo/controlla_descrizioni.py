"""controlla_descrizioni.py -- M7-D04 «La descrizione è il contratto»: le
esecuzioni di in_classe.sh alla prova.

Legge, nella cartella data (risposte/ dello spazio di lavoro), una cartella per
esecuzione, <versione>-<n>/linea-guasta/ (vaga, le definizioni nello stile del
v0; chiara, nomi chiari e descrizioni molto dettagliate), con stream.jsonl,
registro.jsonl (il registro del server: una riga per chiamata, con la capacità
usata) ed esito.json.

Di ogni esecuzione stampa le chiamate (strumento, capacità, argomenti), il primo
strumento chiamato, se la verifica d'identità viene prima delle letture dei dati
del cliente (la scheda, la linea), se gli argomenti hanno il formato che la
capacità si aspetta (i codici CL-000000 e LN-000000 e il recapito, ciascuno a
sé), il numero di chiamate, i token della prima richiesta, turni e secondi. Poi
la coppia, esecuzione per esecuzione: la raccomandazione di Anthropic è
«Provide extremely detailed descriptions. This is by far the most important
factor in tool performance.»; il controllo conta su quante delle tre proprietà
(il primo strumento è la verifica d'identità; la verifica precede le letture
dei dati; gli argomenti sono nel formato atteso) la versione fa meglio:
«confermata» se la versione chiara fa meglio della vaga, «non distinguibile» se
pari, «non confermata in questa esecuzione» se fa peggio; poi «confermata n su
N». Il confronto è un dato per la registrazione e non decide l'uscita.

Uso:    python3 -B -I controlla_descrizioni.py <cartella delle esecuzioni>
Env:    PN_HANDSON_ROOT  il repository, dove sta tools/lib_leggi_contesto.py
                         (default: la radice sopra la cartella dell'elemento)
Uscita: 0 ogni esecuzione c'è ed è finita bene · 1 un'esecuzione che manca alla
        sua coppia, uno stream senza il risultato o con un errore: la prova va
        rifatta · 2 uso sbagliato, cartella che non c'è o senza esecuzioni, un
        file che non si legge, tools/lib_leggi_contesto.py che manca, un errore
        inatteso (una riga, mai un traceback)
"""
from __future__ import annotations

import json
import os
import re
import sys
import textwrap
from typing import Any, Dict, List, NamedTuple


def _strumenti() -> str:
    """tools/ del repository: PN_HANDSON_ROOT, o la radice sopra la cartella
    dell'elemento (<radice>/m7_…/s5_…/m7_5_…/M7-D04_…/demo/)."""
    radice = os.environ.get("PN_HANDSON_ROOT")
    if not radice:
        radice = os.path.realpath(__file__)
        for _ in range(6):
            radice = os.path.dirname(radice)
    return os.path.join(radice, "tools")


STRUMENTI = _strumenti()
sys.path.insert(0, STRUMENTI)
try:
    import lib_leggi_contesto as lc
except ImportError:
    lc = None  # type: ignore[assignment]

BRACCI = ("vaga", "chiara")
QUALE = {"vaga": "le definizioni nello stile del v0",
         "chiara": "nomi chiari e descrizioni molto dettagliate"}
CASO = "linea-guasta"
ESECUZIONE = re.compile(r"^(vaga|chiara)-([1-9][0-9]*)$")
IDENTITA = "verifica_identita"
DATI_CLIENTE = ("cerca_cliente", "stato_linea")
CONFERMATA = "confermata"
NON_CONFERMATA = "non confermata in questa esecuzione"
NON_DISTINGUIBILE = "non distinguibile"
RIFARE = "rifate la prova (il README dice come)"
USO = ("Uso: python3 -B -I controlla_descrizioni.py "
       "<cartella delle esecuzioni>\n")
LARGHEZZA = 76
RIGHE_RISPOSTA = 3
CODICE_CLIENTE = re.compile(r"^CL-\d{6}$")
CODICE_LINEA = re.compile(r"^LN-\d{6}$")
EMAIL = re.compile(r"^[\w.+-]+@[\w.-]+\.\w+$")
TELEFONO = re.compile(r"^\+?\d[\d \-]{7,}\d$")


class Incompleto(Exception):
    """Un'esecuzione che manca o non è finita bene: uscita 1."""


class Run(NamedTuple):
    """Ciò che un'esecuzione dice."""
    nome: str
    chiamate: List[Dict[str, Any]]
    risposta: str
    prima: int
    turni: int
    secondi: float


def migliaia(numero: float) -> str:
    """Il numero intero con il punto delle migliaia."""
    return "{:,}".format(int(numero)).replace(",", ".")


def scrivi_secondi(valore: float) -> str:
    """I secondi con la virgola, un decimale."""
    return ("%.1f" % valore).replace(".", ",")


def leggi_registro(percorso: str) -> List[Dict[str, Any]]:
    """Le righe del registro del server; file assente: nessuna chiamata.
    Raises: Problema."""
    if not os.path.isfile(percorso):
        return []
    righe: List[Dict[str, Any]] = []
    try:
        with open(percorso, encoding="utf-8") as fh:
            for numero, riga in enumerate(fh, 1):
                if not riga.strip():
                    continue
                dato = json.loads(riga)
                if not isinstance(dato, dict):
                    raise lc.Problema("%s, riga %d: non è un oggetto"
                                      % (percorso, numero))
                righe.append(dato)
    except (OSError, UnicodeDecodeError, ValueError) as exc:
        raise lc.Problema("%s non si legge: %s" % (percorso, exc)) from exc
    return righe


def leggi_run(cartella: str, nome: str) -> Run:
    """Un'esecuzione. Raises: Incompleto, Problema."""
    dentro = os.path.join(cartella, nome, CASO)
    if not os.path.isdir(dentro):
        raise Incompleto("manca %s/%s: %s" % (nome, CASO, RIFARE))
    try:
        with open(os.path.join(dentro, "esito.json"), encoding="utf-8") as fh:
            esito = json.load(fh)
    except FileNotFoundError as exc:
        raise Incompleto("manca %s/%s/esito.json: %s"
                         % (nome, CASO, RIFARE)) from exc
    except (OSError, UnicodeDecodeError, ValueError) as exc:
        raise lc.Problema("%s/%s/esito.json non si legge: %s"
                          % (nome, CASO, exc)) from exc
    percorso = os.path.join(dentro, "stream.jsonl")
    if not os.path.isfile(percorso):
        raise Incompleto("manca %s/%s/stream.jsonl: %s"
                         % (nome, CASO, RIFARE))
    esecuzione = lc.leggi_stream(percorso)
    if not esecuzione.completa \
            or (isinstance(esito, dict) and esito.get("completa") is False):
        raise Incompleto("%s: la chiamata non è finita: %s" % (nome, RIFARE))
    if esecuzione.errore:
        raise Incompleto("%s: claude ha restituito un errore: %s"
                         % (nome, RIFARE))
    contesto = lc.leggi_contesto(percorso)
    return Run(nome, leggi_registro(os.path.join(dentro, "registro.jsonl")),
               esecuzione.testo, contesto.prima_richiesta,
               int(esecuzione.turni), float(esecuzione.secondi))


def numeri_esecuzioni(cartella: str) -> List[int]:
    """I numeri delle esecuzioni della cartella. Raises: Problema."""
    try:
        nomi = os.listdir(cartella)
    except OSError as exc:
        raise lc.Problema("la cartella %s non esiste o non si apre (%s)"
                          % (cartella, exc.strerror or exc)) from exc
    numeri = sorted({int(m.group(2)) for m in map(ESECUZIONE.match, nomi)
                     if m and os.path.isdir(os.path.join(cartella,
                                                         m.group(0)))})
    if not numeri:
        raise lc.Problema("nessuna esecuzione in %s: %s" % (cartella, RIFARE))
    return numeri


def leggi_tutto(cartella: str, numeri: List[int]) -> Dict[str, Run]:
    """Tutte le esecuzioni, ogni mancanza in una volta. Raises: Incompleto;
    Problema, al primo file che non si legge."""
    letti: Dict[str, Run] = {}
    mancano: List[str] = []
    for braccio in BRACCI:
        for numero in numeri:
            nome = "%s-%d" % (braccio, numero)
            try:
                letti[nome] = leggi_run(cartella, nome)
            except Incompleto as exc:
                mancano.append(str(exc))
    if mancano:
        raise Incompleto("\n".join(mancano))
    return letti


def foglie(valore: Any) -> List[str]:
    """I valori semplici di un JSON, come testo."""
    if isinstance(valore, dict):
        return [t for v in valore.values() for t in foglie(v)]
    if isinstance(valore, list):
        return [t for v in valore for t in foglie(v)]
    return [] if valore is None else [str(valore)]


def recapito(valore: str) -> bool:
    """Vero se il valore è, intero, un'e-mail o un telefono."""
    return EMAIL.match(valore) is not None \
        or TELEFONO.match(valore) is not None


def formato_giusto(capacita: str, argomenti: Any) -> bool:
    """Vero se gli argomenti di una chiamata hanno il formato che la capacità
    si aspetta: ogni dato intero, nel suo valore."""
    valori = foglie(argomenti)
    if capacita == IDENTITA:
        return any(CODICE_CLIENTE.match(v) for v in valori) \
            and any(recapito(v) for v in valori)
    if capacita == "stato_linea":
        return any(CODICE_LINEA.match(v) for v in valori)
    if capacita == "cerca_cliente":
        return any(CODICE_CLIENTE.match(v) or recapito(v) for v in valori)
    return True


def proprieta(chiamate: List[Dict[str, Any]]) -> Dict[str, bool]:
    """Le tre proprietà di un'esecuzione."""
    capacita = [str(c.get("capacita")) for c in chiamate]
    prima_identita = IDENTITA in capacita and all(
        capacita.index(IDENTITA) < i for i, c in enumerate(capacita)
        if c in DATI_CLIENTE)
    giudicate = [c for c in chiamate if str(c.get("capacita")) in
                 (IDENTITA,) + DATI_CLIENTE]
    formati = bool(giudicate) and all(
        formato_giusto(str(c.get("capacita")), c.get("argomenti"))
        for c in giudicate)
    return {"primo": bool(capacita) and capacita[0] == IDENTITA,
            "prima": prima_identita, "formati": formati}


def punti(chiamate: List[Dict[str, Any]]) -> int:
    """Su quante delle tre proprietà l'esecuzione va bene."""
    return sum(proprieta(chiamate).values())


def stampa_run(run: Run) -> None:
    """Le righe di un'esecuzione."""
    braccio = run.nome.split("-")[0]
    print("%s (%s)" % (run.nome, QUALE[braccio]))
    print("  chiamate:%s" % ("" if run.chiamate else " nessuna"))
    for chiamata in run.chiamate:
        print("    %s (capacità %s), argomenti %s" % (
            chiamata.get("strumento"), chiamata.get("capacita"),
            json.dumps(chiamata.get("argomenti"), ensure_ascii=False)))
    primo = run.chiamate[0] if run.chiamate else {}
    print("  primo strumento: %s" % (
        "%s (capacità %s)" % (primo.get("strumento"), primo.get("capacita"))
        if primo else "nessuno"))
    valori = proprieta(run.chiamate)
    print("  il primo strumento è la verifica d'identità: %s"
          % ("sì" if valori["primo"] else "no"))
    print("  la verifica d'identità c'è e viene prima delle letture dei dati "
          "del cliente: %s" % ("sì" if valori["prima"] else "no"))
    print("  gli argomenti hanno il formato atteso: %s"
          % ("sì" if valori["formati"] else "no"))
    print("  chiamate %d; prima richiesta %s token; turni %d, %s s" % (
        len(run.chiamate), migliaia(run.prima), run.turni,
        scrivi_secondi(run.secondi)))
    print("  risposta:")
    risposta = textwrap.wrap(" ".join(run.risposta.split()),
                             LARGHEZZA - 4) or ["(vuota)"]
    if len(risposta) > RIGHE_RISPOSTA:
        risposta = risposta[:RIGHE_RISPOSTA]
        risposta[-1] += " …"
    for riga in risposta:
        print("    " + riga)


def esito_coppia(vaga: Run, chiara: Run) -> str:
    """L'esito di una coppia, sulle tre proprietà."""
    punti_vaga, punti_chiara = punti(vaga.chiamate), punti(chiara.chiamate)
    if punti_chiara > punti_vaga:
        return CONFERMATA
    return NON_DISTINGUIBILE if punti_chiara == punti_vaga \
        else NON_CONFERMATA


def controlla(cartella: str) -> int:
    """Il controllo di una cartella di esecuzioni; l'uscita del contratto."""
    numeri = numeri_esecuzioni(cartella)
    letti = leggi_tutto(cartella, numeri)
    for braccio in BRACCI:
        for numero in numeri:
            stampa_run(letti["%s-%d" % (braccio, numero)])
            print()
    print("La coppia, esecuzione per esecuzione. Anthropic raccomanda: "
          "«Provide extremely detailed descriptions.")
    print("This is by far the most important factor in tool performance.» "
          "Le due versioni differiscono solo nelle definizioni.")
    print("Le proprietà: il primo strumento è la verifica d'identità; la "
          "verifica precede le letture dei dati; gli argomenti sono nel "
          "formato atteso.")
    conferme = 0
    for numero in numeri:
        vaga = letti["vaga-%d" % numero]
        chiara = letti["chiara-%d" % numero]
        esito = esito_coppia(vaga, chiara)
        conferme += esito == CONFERMATA
        print("  esecuzione %d: vaga %d su 3, chiara %d su 3: %s" % (
            numero, punti(vaga.chiamate), punti(chiara.chiamate), esito))
    print("  confermata %d su %d" % (conferme, len(numeri)))
    print("I token della prima richiesta (le definizioni degli strumenti "
          "fanno parte della richiesta):")
    for numero in numeri:
        print("  esecuzione %d: vaga %s, chiara %s" % (
            numero, migliaia(letti["vaga-%d" % numero].prima),
            migliaia(letti["chiara-%d" % numero].prima)))
    print("Come dati, tutte le %d esecuzioni: chiamate agli strumenti %d, "
          "turni %d, %s s." % (
              len(letti), sum(len(r.chiamate) for r in letti.values()),
              sum(r.turni for r in letti.values()),
              scrivi_secondi(sum(r.secondi for r in letti.values()))))
    return 0


def main(argv: List[str]) -> int:
    if len(argv) != 1 or argv[0].startswith("-"):
        sys.stderr.write(USO)
        return 2
    if lc is None:
        sys.stderr.write("controlla_descrizioni: non trovo "
                         "tools/lib_leggi_contesto.py in %s: date "
                         "PN_HANDSON_ROOT\n" % STRUMENTI)
        return 2
    try:
        return controlla(argv[0])
    except Incompleto as exc:
        print(str(exc))
        return 1
    except lc.Problema as exc:
        sys.stderr.write("controlla_descrizioni: %s\n" % exc)
        return 2
    except Exception as exc:  # pylint: disable=broad-except
        sys.stderr.write("controlla_descrizioni: errore inatteso (%s: %s)\n"
                         % (type(exc).__name__, exc))
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
