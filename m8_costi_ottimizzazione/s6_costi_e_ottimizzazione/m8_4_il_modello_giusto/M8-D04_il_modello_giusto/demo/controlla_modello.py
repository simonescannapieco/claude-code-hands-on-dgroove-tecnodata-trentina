"""controlla_modello.py -- M8-D04 «Il modello giusto per il lavoro»: le
chiamate di in_classe.sh alla prova.

Legge, nella cartella data (risposte/ dello spazio di lavoro), una chiamata per
modello ed esecuzione, <modello>-<n>/risposta.json (haiku, sonnet, opus), e
accanto a questo file ticket.jsonl (le etichette attese) e listino.json (i
prezzi). Per ogni esecuzione stampa le etichette giuste contro quelle attese
(da structured_output), i token in entrata (la somma dei tre campi di usage) e
in uscita, total_cost_usd, il costo ricalcolato dal listino, la differenza fra
i due, duration_api_ms e il costo per ticket giusto. Sono dati.

Il costo si ricalcola così: ogni conteggio di usage al suo prezzo: input_tokens
al prezzo di input, la scrittura in cache divisa fra un'ora e cinque minuti
(usage.cache_creation) ai suoi due prezzi, la lettura al suo prezzo, l'output al
prezzo di output. duration_api_ms non è definito da nessuna pagina letta: lo si
stampa come dato, accanto alla riga comparativa della documentazione.

Poi il confronto che l'affermazione di Anthropic permette: per ogni esecuzione,
se il costo per ticket giusto di Haiku è minore di quello di Sonnet e di quello
di Opus («confermata» oppure «non confermata in questa esecuzione», n su N; una
raccomandazione non fa uscire 1). Sul tempo nessun esito: duration_api_ms è un
dato. L'accuratezza è un dato: quante etichette giuste per modello, nessuna
soglia.

Uso:    python3 -B -I controlla_modello.py <cartella delle chiamate>
Uscita: 0 ogni esecuzione c'è ed è finita bene · 1 un'esecuzione che manca, una
        chiamata con un errore o senza structured_output, o con un numero di
        etichette diverso da quello dei ticket · 2 uso sbagliato, cartella che
        non c'è o senza esecuzioni, un JSON che non si legge o senza usage
        valido, ticket.jsonl o listino.json che mancano o non valgono, un
        errore inatteso (una riga, mai un traceback)
"""
from __future__ import annotations

import json
import os
import re
import sys
from typing import Any, Dict, List, NamedTuple, Optional, Tuple

MODELLI = ("haiku", "sonnet", "opus")
ESECUZIONE = re.compile(r"^(haiku|sonnet|opus)-([1-9][0-9]*)$")
CAMPI_USO = ("input_tokens", "cache_creation_input_tokens",
             "cache_read_input_tokens", "output_tokens")
CAMPI_LISTINO = ("input", "output", "cache_write_5m", "cache_write_1h",
                 "cache_read")
CONFERMATA = "confermata"
NON_CONFERMATA = "non confermata in questa esecuzione"
RIFARE = "rifate la prova (il README dice come)"
USO = "Uso: python3 -B -I controlla_modello.py <cartella delle chiamate>\n"
FRASI = (
    ("«High-volume work with outputs you can check | Try Claude Haiku 5.5 "
     "first»",
     "https://platform.claude.com/docs/en/about-claude/models/"
     "optimizing-for-cost-and-intelligence"),
    ("«The lowest latency and price | Claude Haiku 5.5»",
     "https://platform.claude.com/docs/en/about-claude/models/"
     "choosing-a-model"),
    ("«Compare models on cost per completed task, not per token, because "
     "you pay for completed tasks.»",
     "https://platform.claude.com/docs/en/about-claude/models/"
     "optimizing-for-cost-and-intelligence"),
)
FORMA_RIGA = "  %-9s %8s %9s %9s %11s %14s %10s %9s %12s"
INTESTAZIONE = ("esecuz.", "giuste", "token in", "token out",
                "stima ($)", "ricalcolato ($)", "diff. ($)", "ms API",
                "$ per giusto")


class Incompleto(Exception):
    """Un'esecuzione che manca o non è finita bene: uscita 1."""


class Problema(Exception):
    """Un file che non si legge, un uso sbagliato: uscita 2."""


class Esecuzione(NamedTuple):
    """Ciò che il JSON e il listino dicono di una chiamata."""
    nome: str
    modello: str
    giuste: int
    totale: int
    ingresso: int
    uscita: int
    stimato: Optional[float]
    ricalcolato: float
    ms_api: Optional[int]
    secondi: float
    turni: int
    senza_dettaglio: bool

    @property
    def per_giusto(self) -> Optional[float]:
        """Il costo ricalcolato per ticket classificato giusto."""
        return self.ricalcolato / self.giuste if self.giuste else None


def migliaia(numero: float) -> str:
    """Il numero intero con il punto delle migliaia."""
    return "{:,}".format(int(numero)).replace(",", ".")


def dollari(valore: Optional[float]) -> str:
    """Un importo con sei decimali e la virgola, «n.d.» se manca."""
    if valore is None:
        return "n.d."
    return ("%.6f" % (round(valore, 6) + 0.0)).replace(".", ",")


def secondi_txt(valore: float) -> str:
    """I secondi con la virgola, un decimale."""
    return ("%.1f" % valore).replace(".", ",")


def leggi(percorso: str) -> str:
    """Il testo di un file. Raises: Problema."""
    try:
        with open(percorso, encoding="utf-8") as fh:
            return fh.read()
    except (OSError, UnicodeDecodeError) as exc:
        raise Problema("%s non si legge (%s)" % (percorso, exc)) from exc


def attese(cartella: str) -> List[str]:
    """Le etichette attese, da ticket.jsonl nella cartella di questo file.
    Raises: Problema."""
    percorso = os.path.join(cartella, "ticket.jsonl")
    if not os.path.isfile(percorso):
        raise Problema("manca %s" % percorso)
    etichette: List[str] = []
    for numero, riga in enumerate(leggi(percorso).splitlines(), 1):
        if not riga.strip():
            continue
        try:
            dato = json.loads(riga)
        except ValueError as exc:
            raise Problema("%s, riga %d: non è JSON (%s)"
                           % (percorso, numero, exc)) from exc
        if not isinstance(dato, dict) \
                or not isinstance(dato.get("etichetta"), str):
            raise Problema("%s, riga %d: non ha l'etichetta"
                           % (percorso, numero))
        etichette.append(dato["etichetta"])
    if not etichette:
        raise Problema("%s: nessun ticket" % percorso)
    return etichette


def carica_listino(cartella: str) -> Dict[str, Dict[str, float]]:
    """I prezzi per modello, da listino.json. Raises: Problema."""
    percorso = os.path.join(cartella, "listino.json")
    if not os.path.isfile(percorso):
        raise Problema("manca %s" % percorso)
    try:
        dato = json.loads(leggi(percorso))
        modelli = dato["modelli"]
    except (ValueError, KeyError, TypeError) as exc:
        raise Problema("%s non è un listino valido (%s)"
                       % (percorso, exc)) from exc
    prezzi: Dict[str, Dict[str, float]] = {}
    for modello in MODELLI:
        voce = modelli.get(modello) if isinstance(modelli, dict) else None
        if not isinstance(voce, dict):
            raise Problema("%s: manca il modello %s" % (percorso, modello))
        for campo in CAMPI_LISTINO:
            valore = voce.get(campo)
            if isinstance(valore, bool) \
                    or not isinstance(valore, (int, float)) or valore < 0:
                raise Problema("%s: %s.%s non è un prezzo"
                               % (percorso, modello, campo))
        prezzi[modello] = {c: float(voce[c]) for c in CAMPI_LISTINO}
    return prezzi


def intero(valore: Any, nome: str, campo: str) -> int:
    """Un conteggio del JSON, intero non negativo. Raises: Problema."""
    if isinstance(valore, bool) or not isinstance(valore, int) or valore < 0:
        raise Problema("%s: il campo «%s» non è un numero valido: %r"
                       % (nome, campo, valore))
    return valore


def leggi_json(percorso: str, nome: str) -> Dict[str, Any]:
    """Il JSON di una chiamata. Raises: Incompleto, Problema."""
    if not os.path.isfile(percorso):
        raise Incompleto("manca %s: %s" % (nome, RIFARE))
    testo = leggi(percorso)
    if not testo.strip():
        raise Incompleto("%s è vuoto: la chiamata non è finita: %s"
                         % (nome, RIFARE))
    try:
        dato = json.loads(testo)
    except ValueError as exc:
        raise Problema("%s: il JSON non si legge (%s)" % (nome, exc)) from exc
    if not isinstance(dato, dict):
        raise Problema("%s: il JSON non è un oggetto" % nome)
    return dato


def costo_ricalcolato(uso: Dict[str, Any], prezzi: Dict[str, float],
                      nome: str) -> Tuple[float, bool]:
    """Il costo dei conteggi di usage, ognuno al suo prezzo; vero se il JSON
    non ha il dettaglio della scrittura, prezzata allora tutta a 5 minuti.
    Raises: Problema."""
    scritti = uso["cache_creation_input_tokens"]
    dettaglio = uso.get("cache_creation")
    if isinstance(dettaglio, dict):
        un_ora = intero(dettaglio.get("ephemeral_1h_input_tokens"), nome,
                        "cache_creation.ephemeral_1h_input_tokens")
        cinque = intero(dettaglio.get("ephemeral_5m_input_tokens"), nome,
                        "cache_creation.ephemeral_5m_input_tokens")
        resto = max(scritti - un_ora - cinque, 0)
        senza_dettaglio = False
    else:
        un_ora, cinque, resto = 0, scritti, 0
        senza_dettaglio = True
    dollari_per_milione = (
        uso["input_tokens"] * prezzi["input"]
        + un_ora * prezzi["cache_write_1h"]
        + (cinque + resto) * prezzi["cache_write_5m"]
        + uso["cache_read_input_tokens"] * prezzi["cache_read"]
        + uso["output_tokens"] * prezzi["output"])
    return dollari_per_milione / 1e6, senza_dettaglio


def etichette_di(dato: Dict[str, Any], nome: str,
                 quante: int) -> List[str]:
    """Le etichette di structured_output. Raises: Incompleto."""
    uscita = dato.get("structured_output")
    etichette = uscita.get("etichette") if isinstance(uscita, dict) else None
    if not isinstance(etichette, list) or not all(
            isinstance(e, str) for e in etichette):
        raise Incompleto("%s: senza un output strutturato con le etichette: "
                         "%s" % (nome, RIFARE))
    if len(etichette) != quante:
        raise Incompleto("%s: %d etichette invece di %d: %s"
                         % (nome, len(etichette), quante, RIFARE))
    return etichette


def controlla_il_modello(dato: Dict[str, Any], modello: str, nome: str) -> None:
    """La chiamata è su un solo modello, quello della sua cartella.
    Raises: Incompleto."""
    usati = dato.get("modelUsage")
    nomi = sorted(usati) if isinstance(usati, dict) else []
    if len(nomi) != 1 or modello not in nomi[0]:
        raise Incompleto("%s: la chiamata non è su un solo modello %s "
                         "(modelUsage: %s): %s" % (
                             nome, modello, ", ".join(nomi) or "vuoto", RIFARE))


def leggi_esecuzione(cartella: str, modello: str, n: int, giuste: List[str],
                     prezzi: Dict[str, Dict[str, float]]) -> Esecuzione:
    """Una chiamata. Raises: Incompleto, Problema."""
    nome = "%s-%d" % (modello, n)
    dato = leggi_json(os.path.join(cartella, nome, "risposta.json"),
                      nome + "/risposta.json")
    if dato.get("is_error") or dato.get("subtype") != "success":
        raise Incompleto("%s: claude ha restituito un errore: %s"
                         % (nome, RIFARE))
    controlla_il_modello(dato, modello, nome)
    uso = dato.get("usage")
    if not isinstance(uso, dict):
        raise Problema("%s: il campo «usage» non c'è" % nome)
    for campo in CAMPI_USO:
        intero(uso.get(campo), nome, "usage." + campo)
    etichette = etichette_di(dato, nome, len(giuste))
    ricalcolato, senza_dettaglio = costo_ricalcolato(uso, prezzi[modello], nome)
    stimato = dato.get("total_cost_usd")
    return Esecuzione(
        nome, modello, sum(a == b for a, b in zip(etichette, giuste)),
        len(giuste),
        uso["input_tokens"] + uso["cache_creation_input_tokens"]
        + uso["cache_read_input_tokens"], uso["output_tokens"],
        float(stimato) if isinstance(stimato, (int, float))
        and not isinstance(stimato, bool) else None,
        ricalcolato,
        dato.get("duration_api_ms") if isinstance(dato.get("duration_api_ms"),
                                                  int) else None,
        float(intero(dato.get("duration_ms", 0), nome, "duration_ms")) / 1000,
        intero(dato.get("num_turns", 0), nome, "num_turns"), senza_dettaglio)


def numeri_esecuzioni(cartella: str) -> List[int]:
    """I numeri delle esecuzioni della cartella, da 1 al più alto.
    Raises: Problema."""
    try:
        nomi = os.listdir(cartella)
    except OSError as exc:
        raise Problema("la cartella %s non esiste o non si apre (%s)"
                       % (cartella, exc.strerror or exc)) from exc
    numeri = {int(m.group(2)) for m in map(ESECUZIONE.match, nomi)
              if m and os.path.isdir(os.path.join(cartella, m.group(0)))}
    if not numeri:
        raise Problema("nessuna esecuzione in %s: %s" % (cartella, RIFARE))
    return list(range(1, max(numeri) + 1))


def leggi_tutto(cartella: str, giuste: List[str],
                prezzi: Dict[str, Dict[str, float]]
                ) -> Tuple[Dict[Tuple[str, int], Esecuzione], List[int]]:
    """Tutte le esecuzioni, ogni mancanza in una volta. Raises: Incompleto,
    Problema."""
    numeri = numeri_esecuzioni(cartella)
    esecuzioni: Dict[Tuple[str, int], Esecuzione] = {}
    mancano: List[str] = []
    for numero in numeri:
        for modello in MODELLI:
            try:
                esecuzioni[(modello, numero)] = leggi_esecuzione(
                    cartella, modello, numero, giuste, prezzi)
            except Incompleto as exc:
                mancano.append(str(exc))
    if mancano:
        raise Incompleto("\n".join(mancano))
    return esecuzioni, numeri


def stampa_esecuzione(es: Esecuzione) -> None:
    """Una riga della tabella: dati."""
    diff = None if es.stimato is None else es.ricalcolato - es.stimato
    print(FORMA_RIGA % (
        es.nome, "%d/%d" % (es.giuste, es.totale), migliaia(es.ingresso),
        migliaia(es.uscita), dollari(es.stimato), dollari(es.ricalcolato),
        dollari(diff),
        "n.d." if es.ms_api is None else migliaia(es.ms_api),
        dollari(es.per_giusto)))


def stampa_modello(modello: str, gruppo: List[Esecuzione]) -> None:
    """Il riepilogo di un modello su tutte le sue esecuzioni: dati."""
    giuste = sum(e.giuste for e in gruppo)
    totale = sum(e.totale for e in gruppo)
    costo = sum(e.ricalcolato for e in gruppo)
    durate = [e.ms_api for e in gruppo if e.ms_api is not None]
    print("  %s: %d giuste su %d; costo ricalcolato medio per chiamata %s $; "
          "per ticket giusto %s $; ms API medi %s" % (
              modello, giuste, totale, dollari(costo / len(gruppo)),
              dollari(costo / giuste) if giuste else "n.d.",
              migliaia(sum(durate) / len(durate)) if durate else "n.d."))


def stampa_confronto(esecuzioni: Dict[Tuple[str, int], Esecuzione],
                     numeri: List[int]) -> None:
    """Il confronto sul costo per ticket giusto, n su N, e l'accuratezza:
    dati, mai l'uscita."""
    print("Sul costo per ticket giusto, esecuzione per esecuzione (gli stessi "
          "otto ticket sui tre modelli): quello di Haiku è minore di quello "
          "di Sonnet e di quello di Opus?")
    conferme = 0
    pari = 0
    for numero in numeri:
        h, s, o = (esecuzioni[(m, numero)] for m in MODELLI)
        vero = h.per_giusto is not None and all(
            x.per_giusto is None or h.per_giusto < x.per_giusto
            for x in (s, o))
        conferme += vero
        print("  esecuzione %d: haiku %s, sonnet %s, opus %s: %s" % (
            numero, dollari(h.per_giusto), dollari(s.per_giusto),
            dollari(o.per_giusto), CONFERMATA if vero else NON_CONFERMATA))
        pari += h.giuste >= max(s.giuste, o.giuste)
    print("  Il costo per ticket giusto di Haiku è il più basso: confermata "
          "%d su %d." % (conferme, len(numeri)))
    print("Sul tempo nessun esito: duration_api_ms è solo un dato.")
    print("Sull'accuratezza (un dato, nessuna soglia): etichette giuste di "
          "Haiku, Sonnet e Opus, esecuzione per esecuzione:")
    for numero in numeri:
        h, s, o = (esecuzioni[(m, numero)] for m in MODELLI)
        print("  esecuzione %d: haiku %d/%d, sonnet %d/%d, opus %d/%d" % (
            numero, h.giuste, h.totale, s.giuste, s.totale, o.giuste,
            o.totale))
    print("  Haiku pari o meglio degli altri due: %d su %d esecuzioni "
          "(dato)." % (pari, len(numeri)))


def controlla(cartella: str, sorgente: str) -> int:
    """Il controllo di una cartella; l'uscita del contratto."""
    giuste = attese(sorgente)
    prezzi = carica_listino(sorgente)
    esecuzioni, numeri = leggi_tutto(cartella, giuste, prezzi)
    print("Anthropic, sul modello giusto:")
    for frase, url in FRASI:
        print("  %s (%s)" % (frase, url))
    print()
    print("Prezzi dal listino letto il %s; costo per ticket giusto = costo "
          "ricalcolato diviso per le etichette giuste."
          % json.loads(leggi(os.path.join(sorgente, "listino.json")))
          ["letto_il"])
    print(FORMA_RIGA % INTESTAZIONE)
    for numero in numeri:
        for modello in MODELLI:
            stampa_esecuzione(esecuzioni[(modello, numero)])
    print()
    print("Per modello, su tutte le esecuzioni:")
    for modello in MODELLI:
        stampa_modello(modello, [esecuzioni[(modello, n)] for n in numeri])
    print()
    stampa_confronto(esecuzioni, numeri)
    print()
    tutte = list(esecuzioni.values())
    print("Come dati, tutte le %d chiamate: turni %d; token in entrata %s, "
          "in uscita %s; %s s." % (
              len(tutte), sum(e.turni for e in tutte),
              migliaia(sum(e.ingresso for e in tutte)),
              migliaia(sum(e.uscita for e in tutte)),
              secondi_txt(sum(e.secondi for e in tutte))))
    if any(e.senza_dettaglio for e in tutte):
        print("Nota: in almeno un JSON manca usage.cache_creation: quella "
              "scrittura è prezzata tutta a cinque minuti.")
    return 0


def main(argv: List[str]) -> int:
    if len(argv) != 1 or argv[0].startswith("-"):
        sys.stderr.write(USO)
        return 2
    sorgente = os.path.dirname(os.path.realpath(__file__))
    try:
        return controlla(argv[0], sorgente)
    except Incompleto as exc:
        print(str(exc))
        return 1
    except Problema as exc:
        sys.stderr.write("controlla_modello: %s\n" % exc)
        return 2
    except Exception as exc:  # pylint: disable=broad-except
        sys.stderr.write("controlla_modello: errore inatteso (%s: %s)\n"
                         % (type(exc).__name__, exc))
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
