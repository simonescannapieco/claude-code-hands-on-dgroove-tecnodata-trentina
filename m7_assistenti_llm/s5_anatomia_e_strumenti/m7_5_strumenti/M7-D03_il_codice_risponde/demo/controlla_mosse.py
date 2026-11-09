"""controlla_mosse.py -- M7-D03 «Il modello chiede, il codice risponde»: le
esecuzioni di in_classe.sh alla prova.

Legge, nella cartella data (risposte/ dello spazio di lavoro), per ogni
esecuzione run-<n>/ i due casi, linea-esistente/ e linea-inesistente/, ciascuno
con stream.jsonl (il `claude -p --output-format stream-json --verbose` della
chiamata), registro.jsonl (il registro del server MCP: una riga per chiamata
allo strumento) ed esito.json (il riepilogo del banco).

Di ogni caso stampa ciò che il modello ha chiesto (lo strumento e gli argomenti,
dallo stream), ciò che il server ha fatto (il risultato, dal registro) e la
risposta. Poi una dimostrazione, che fa lo script e non dice niente su Claude: i
dati della risposta che vengono dal risultato dello strumento, e i numeri, i
codici e gli orari della risposta che nel risultato non ci sono. Poi le due
garanzie, che decidono l'uscita:
  «The model never runs anything on its own»: ogni chiamata che il modello
    chiede nello stream è nel registro del server, con gli stessi argomenti e
    lo stesso risultato, e la risposta arriva dopo il risultato;
  «when a tool returns a result marked isError: true, Claude receives the
    result's text as the tool's error message»: nel caso della linea che non
    esiste il tool_result dello stream ha is_error true e riporta il testo del
    risultato. Stampa com'è, prima di tutto, che cosa c'è in quel blocco.

Uso:    python3 -B -I controlla_mosse.py <cartella delle esecuzioni>
Env:    PN_HANDSON_ROOT  il repository, dove sta tools/lib_leggi_contesto.py
                         (default: la radice sopra la cartella dell'elemento)
Uscita: 0 ogni esecuzione c'è, è finita bene e le garanzie valgono · 1 un caso
        che manca, uno stream senza il risultato o con un errore, una garanzia
        che non vale · 2 uso sbagliato, cartella che non c'è o senza esecuzioni,
        un file che non si legge, tools/lib_leggi_contesto.py che manca, un
        errore inatteso (una riga, mai un traceback)
"""
from __future__ import annotations

import json
import os
import re
import sys
import textwrap
from typing import Any, Dict, List, NamedTuple, Optional, Tuple


def _strumenti() -> str:
    """tools/ del repository: PN_HANDSON_ROOT, o la radice sopra la cartella
    dell'elemento (<radice>/m7_…/s5_…/m7_5_…/M7-D03_…/demo/)."""
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

ESISTENTE = "linea-esistente"
INESISTENTE = "linea-inesistente"
CASI = (ESISTENTE, INESISTENTE)
ESECUZIONE = re.compile(r"^run-([1-9][0-9]*)$")
PREFISSO = "mcp__assistenza__"
CONFERMATA = "confermata"
NON_CONFERMATA = "non confermata in questa esecuzione"
RIFARE = "rifate la prova (il README dice come)"
USO = "Uso: python3 -B -I controlla_mosse.py <cartella delle esecuzioni>\n"
LARGHEZZA = 76
RIGHE_RISPOSTA = 4
LUNGHEZZA_RISULTATO = 200
# Dati che si possono cercare in una risposta: codici, orari, numeri.
DATO = re.compile(r"\b[A-Z]{2}-\d{6}\b|\b\d{1,2}:\d{2}\b|\b\d{2,}\b")
VALORE_BREVE = 40


class Incompleto(Exception):
    """Un caso che manca o non è finito bene: uscita 1."""


class Mossa(NamedTuple):
    """Un tool_use dello stream con il suo tool_result."""
    nome: str
    ingresso: Any
    chiesta: int
    risposta: int
    testo: str
    errore: bool


class Caso(NamedTuple):
    """Ciò che un caso dice: lo stream e il registro del server."""
    nome: str
    mosse: List[Mossa]
    registro: List[Dict[str, Any]]
    risposta: str
    pos_risposta: int
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
    """Le righe del registro del server. Raises: Incompleto, Problema."""
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


def leggi_esito(percorso: str, nome: str) -> Dict[str, Any]:
    """Il riepilogo del banco. Raises: Incompleto, Problema."""
    if not os.path.isfile(percorso):
        raise Incompleto("manca %s: %s" % (nome, RIFARE))
    try:
        with open(percorso, encoding="utf-8") as fh:
            dato = json.load(fh)
    except (OSError, UnicodeDecodeError, ValueError) as exc:
        raise lc.Problema("%s non si legge: %s" % (percorso, exc)) from exc
    if not isinstance(dato, dict):
        raise lc.Problema("%s: non è un oggetto" % percorso)
    return dato


def testo_risultato(contenuto: object) -> str:
    """Il testo di un tool_result, stringa o elenco di blocchi."""
    if isinstance(contenuto, str):
        return contenuto
    if isinstance(contenuto, list):
        return "\n".join(str(p.get("text", "")) for p in contenuto
                         if isinstance(p, dict))
    return ""


def mosse_di(eventi: List[Dict[str, Any]]) -> Tuple[List[Mossa], int]:
    """Le chiamate dello stream, in ordine, e la posizione dell'ultimo testo
    del modello (la risposta). Una chiamata senza risultato ha risposta -1."""
    chieste: List[Dict[str, Any]] = []
    risultati: Dict[str, Tuple[int, str, bool]] = {}
    ultimo_testo = -1
    for pos, evento in enumerate(eventi):
        messaggio = evento.get("message")
        contenuto = messaggio.get("content") \
            if isinstance(messaggio, dict) else None
        if not isinstance(contenuto, list):
            continue
        if evento.get("type") == "assistant" \
                and evento.get("parent_tool_use_id") is None:
            for blocco in contenuto:
                if not isinstance(blocco, dict):
                    continue
                if blocco.get("type") == "tool_use" and all(
                        c["id"] != blocco.get("id") for c in chieste):
                    chieste.append({"id": blocco.get("id"),
                                    "nome": str(blocco.get("name", "")),
                                    "input": blocco.get("input"), "pos": pos})
                elif blocco.get("type") == "text" \
                        and str(blocco.get("text", "")).strip():
                    ultimo_testo = pos
        elif evento.get("type") == "user":
            for blocco in contenuto:
                if isinstance(blocco, dict) \
                        and blocco.get("type") == "tool_result":
                    risultati[str(blocco.get("tool_use_id"))] = (
                        pos, testo_risultato(blocco.get("content")),
                        blocco.get("is_error") is True)
    mosse = []
    for c in chieste:
        pos_r, testo, errore = risultati.get(str(c["id"]), (-1, "", False))
        nome = c["nome"][len(PREFISSO):] if c["nome"].startswith(PREFISSO) \
            else c["nome"]
        mosse.append(Mossa(nome, c["input"], c["pos"], pos_r, testo, errore))
    return mosse, ultimo_testo


def leggi_caso(cartella: str, numero: int, nome: str) -> Caso:
    """Un caso di un'esecuzione. Raises: Incompleto, Problema."""
    dentro = os.path.join(cartella, "run-%d" % numero, nome)
    etichetta = "run-%d/%s" % (numero, nome)
    if not os.path.isdir(dentro):
        raise Incompleto("manca %s/: %s" % (etichetta, RIFARE))
    esito = leggi_esito(os.path.join(dentro, "esito.json"),
                        etichetta + "/esito.json")
    percorso = os.path.join(dentro, "stream.jsonl")
    if not os.path.isfile(percorso):
        raise Incompleto("manca %s/stream.jsonl: %s" % (etichetta, RIFARE))
    esecuzione = lc.leggi_stream(percorso)
    if not esecuzione.completa or esito.get("completa") is False:
        raise Incompleto("%s: la chiamata non è finita: %s"
                         % (etichetta, RIFARE))
    if esecuzione.errore:
        raise Incompleto("%s: claude ha restituito un errore: %s"
                         % (etichetta, RIFARE))
    contesto = lc.leggi_contesto(percorso)
    mosse, pos_risposta = mosse_di(lc._eventi(percorso))
    return Caso(nome, mosse, leggi_registro(os.path.join(dentro,
                                                         "registro.jsonl")),
                esecuzione.testo, pos_risposta, contesto.prima_richiesta,
                int(esecuzione.turni), float(esecuzione.secondi))


def numeri_esecuzioni(cartella: str) -> List[int]:
    """I numeri delle esecuzioni della cartella. Raises: Problema."""
    try:
        nomi = os.listdir(cartella)
    except OSError as exc:
        raise lc.Problema("la cartella %s non esiste o non si apre (%s)"
                          % (cartella, exc.strerror or exc)) from exc
    numeri = sorted({int(m.group(1)) for m in map(ESECUZIONE.match, nomi)
                     if m and os.path.isdir(os.path.join(cartella,
                                                         m.group(0)))})
    if not numeri:
        raise lc.Problema("nessuna esecuzione in %s: %s" % (cartella, RIFARE))
    return numeri


def foglie(valore: Any) -> List[str]:
    """I valori semplici di un JSON, come testo."""
    if isinstance(valore, dict):
        return [t for v in valore.values() for t in foglie(v)]
    if isinstance(valore, list):
        return [t for v in valore for t in foglie(v)]
    return [] if valore is None else [str(valore)]


def dati_cercati(risultato: Any) -> List[str]:
    """I dati di un risultato da cercare in una risposta: i valori brevi e
    i codici, gli orari e i numeri dentro quelli lunghi; senza doppioni."""
    visti: List[str] = []
    for valore in foglie(risultato):
        candidati = [valore] if len(valore) <= VALORE_BREVE else []
        candidati += DATO.findall(valore)
        for candidato in candidati:
            if candidato and candidato not in visti:
                visti.append(candidato)
    return visti


def compare(dato: str, testo: str) -> bool:
    """Vero se il dato compare nel testo, non dentro un dato più lungo (un
    numero dentro un codice o un orario non conta)."""
    return re.search(r"(?<![\w:])%s(?![\w:])" % re.escape(dato.lower()),
                     testo) is not None


def stampa_dimostrazione(caso: Caso) -> None:
    """Dal risultato alla risposta: una dimostrazione, stampata com'è."""
    risultati = [r.get("risultato") for r in caso.registro]
    dati = [d for r in risultati for d in dati_cercati(r)]
    bassa = caso.risposta.lower()
    presi = [d for d in dict.fromkeys(dati) if compare(d, bassa)]
    testo_totale = " ".join(t for r in risultati for t in foglie(r)).lower()
    estranei = [d for d in dict.fromkeys(DATO.findall(caso.risposta))
                if not compare(d, testo_totale)]
    print("  una dimostrazione, che fa lo script: i dati della risposta che "
          "vengono dal risultato: %s" % (", ".join(presi) or "nessuno"))
    print("  numeri, codici e orari della risposta che nel risultato non ci "
          "sono: %s" % (", ".join(estranei) or "nessuno"))


def stesso_risultato(testo: str, risultato: Any) -> bool:
    """Vero se il testo del tool_result è il risultato del registro."""
    try:
        return json.loads(testo) == risultato
    except ValueError:
        return testo.strip() == str(risultato).strip()


def garanzia_registro(caso: Caso) -> Optional[str]:
    """Il problema della prima garanzia in un caso, o None se vale."""
    if not caso.mosse or not caso.registro:
        return "nel registro del server non c'è nessuna chiamata"
    if len(caso.mosse) != len(caso.registro):
        return "%d chiamate nello stream, %d nel registro" % (
            len(caso.mosse), len(caso.registro))
    for numero, (mossa, riga) in enumerate(zip(caso.mosse, caso.registro), 1):
        if riga.get("strumento") != mossa.nome \
                or riga.get("argomenti") != mossa.ingresso:
            return "la chiamata %d: strumento o argomenti diversi fra stream " \
                "e registro" % numero
        if not stesso_risultato(mossa.testo, riga.get("risultato")):
            return "la chiamata %d: il tool_result non è il risultato del " \
                "registro" % numero
        if mossa.risposta < 0 or not mossa.chiesta < mossa.risposta \
                or mossa.risposta >= caso.pos_risposta:
            return "la chiamata %d: il risultato non precede la risposta" \
                % numero
    return None


def stampa_caso(numero: int, caso: Caso) -> bool:
    """Le righe di un caso; vero se le garanzie del caso valgono."""
    print("run-%d, %s" % (numero, caso.nome))
    print("  il modello ha chiesto (stream), il server ha risposto (registro):"
          + ("" if caso.mosse else " nessuna chiamata"))
    for mossa, riga in zip(caso.mosse, caso.registro + [{}] * len(caso.mosse)):
        ris = json.dumps(riga.get("risultato"), ensure_ascii=False)
        if len(ris) > LUNGHEZZA_RISULTATO:
            ris = ris[:LUNGHEZZA_RISULTATO] + "…"
        print("    %s, argomenti %s" % (mossa.nome,
                                        json.dumps(mossa.ingresso,
                                                   ensure_ascii=False)))
        print("      risultato: %s" % ris)
        print("      nel tool_result: is_error %s" % (
            "true" if mossa.errore else "assente o false"))
    print("  la risposta:")
    risposta = textwrap.wrap(" ".join(caso.risposta.split()),
                             LARGHEZZA - 4) or ["(vuota)"]
    if len(risposta) > RIGHE_RISPOSTA:
        risposta = risposta[:RIGHE_RISPOSTA]
        risposta[-1] += " …"
    for riga_testo in risposta:
        print("    " + riga_testo)
    stampa_dimostrazione(caso)
    print("  prima richiesta %s token; turni %d, %s s" % (
        migliaia(caso.prima), caso.turni, scrivi_secondi(caso.secondi)))
    problema = garanzia_registro(caso)
    print("  «The model never runs anything on its own»: %s%s" % (
        CONFERMATA if problema is None else NON_CONFERMATA,
        "" if problema is None else ": " + problema))
    if caso.nome != INESISTENTE:
        return problema is None
    errore = bool(caso.mosse) and caso.mosse[0].errore
    segnato = bool(caso.registro) and caso.registro[0].get("errore") is True
    print("  «Claude receives the result's text as the tool's error message»: "
          "nel registro errore %s, nel tool_result is_error %s: %s" % (
              "sì" if segnato else "no", "true" if errore else "assente",
              CONFERMATA if errore and segnato else NON_CONFERMATA))
    return problema is None and errore and segnato


def controlla(cartella: str) -> int:
    """Il controllo di una cartella di esecuzioni; l'uscita del contratto."""
    numeri = numeri_esecuzioni(cartella)
    casi: Dict[Tuple[int, str], Caso] = {}
    mancano: List[str] = []
    for numero in numeri:
        for nome in CASI:
            try:
                casi[(numero, nome)] = leggi_caso(cartella, numero, nome)
            except Incompleto as exc:
                mancano.append(str(exc))
    if mancano:
        raise Incompleto("\n".join(mancano))
    conferme = 0
    for numero in numeri:
        esiti = [stampa_caso(numero, casi[(numero, nome)]) for nome in CASI]
        conferme += all(esiti)
    print("Le due garanzie, esecuzione per esecuzione: valgono in %d su %d."
          % (conferme, len(numeri)))
    if conferme < len(numeri):
        print("Una garanzia non vale in questa esecuzione: la riga «%s» qui "
              "sopra dice dove." % NON_CONFERMATA)
        return 1
    return 0


def main(argv: List[str]) -> int:
    if len(argv) != 1 or argv[0].startswith("-"):
        sys.stderr.write(USO)
        return 2
    if lc is None:
        sys.stderr.write("controlla_mosse: non trovo "
                         "tools/lib_leggi_contesto.py in %s: date "
                         "PN_HANDSON_ROOT\n" % STRUMENTI)
        return 2
    try:
        return controlla(argv[0])
    except Incompleto as exc:
        print(str(exc))
        return 1
    except lc.Problema as exc:
        sys.stderr.write("controlla_mosse: %s\n" % exc)
        return 2
    except Exception as exc:  # pylint: disable=broad-except
        sys.stderr.write("controlla_mosse: errore inatteso (%s: %s)\n"
                         % (type(exc).__name__, exc))
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
