"""controlla_cache.py -- M8-D03 «La cache, vista nel contatore»: le chiamate
di in_classe.sh alla prova.

Legge, nella cartella data (risposte/ dello spazio di lavoro), le serie. Una
serie n è fatta di:
  <n>-prefisso.md                   il prefisso della serie (la prima riga è
                                    il marcatore, poi le procedure);
  <n>-prima/risposta.json           la prima chiamata, su Haiku;
  <n>-seconda/risposta.json         la stessa chiamata, ripetuta;
  <n>-senza-cache/risposta.json     la stessa con DISABLE_PROMPT_CACHING=1;
  <n>-sonnet/risposta.json          la stessa con --model sonnet;
  <n>-haiku-di-nuovo/risposta.json  la stessa, ancora su Haiku.
Di ogni chiamata stampa i conteggi di usage: input_tokens, i token scritti in
cache (cache_creation_input_tokens), quelli letti dalla cache
(cache_read_input_tokens), la loro somma (il totale in entrata), i token in
uscita, e la scrittura divisa fra un'ora e cinque minuti (usage.cache_creation:
ephemeral_1h_input_tokens ed ephemeral_5m_input_tokens). Sono dati.

Poi le garanzie di ogni serie, dette dalle frasi di Anthropic sulla cache di
Claude Code. Ciascuna è confermata o no, e una che in una serie non vale fa
uscire 1:
  - la prima chiamata scrive e non legge (scritti > 0, letti = 0);
  - la seconda legge (letti > 0: non per forza tutto il prefisso);
  - con DISABLE_PROMPT_CACHING=1 niente in cache (scritti = 0, letti = 0) e
    il prefisso tutto in input_tokens (input_tokens > 0);
  - su Sonnet la cache di Haiku non vale: letti = 0 e scritti > 0;
  - tornando su Haiku si legge di nuovo (letti > 0).

Uso:    python3 -B -I controlla_cache.py <cartella delle chiamate>
Uscita: 0 ogni serie è completa e le garanzie valgono · 1 una serie o una
        chiamata che manca, una chiamata con un errore, una garanzia che non
        vale · 2 uso sbagliato, cartella che non c'è o senza serie, un JSON
        che non si legge o senza usage valido, un errore inatteso (una riga,
        mai un traceback)
"""
from __future__ import annotations

import json
import os
import re
import sys
from typing import Any, Dict, List, NamedTuple, Optional, Tuple

CHIAMATE = ("prima", "seconda", "senza-cache", "sonnet", "haiku-di-nuovo")
ESECUZIONE = re.compile(r"^([1-9][0-9]*)-(%s)$" % "|".join(CHIAMATE))
MARCATORE = re.compile(r"^Marcatore di questa serie: (CACHE-[0-9A-F]{8})\.$")
CONFERMATA = "confermata"
NON_CONFERMATA = "non confermata in questa esecuzione"
RIFARE = "rifate la prova (il README dice come)"
USO = "Uso: python3 -B -I controlla_cache.py <cartella delle chiamate>\n"
FRASI = (
    "«Claude Code manages prompt caching automatically.»",
    "«Each model has its own cache. Switching with /model means the next "
    "request reads the entire conversation history with no cache hits»",
    "«DISABLE_PROMPT_CACHING | Disable for all models»",
)
PAGINA = "https://code.claude.com/docs/en/prompt-caching"
INTESTAZIONE = ("chiamata", "modello", "input", "scritti", "letti", "totale",
                "output", "1 h", "5 min")
FORMA_RIGA = "  %-16s %-18s %7s %8s %8s %8s %7s %8s %8s"


class Incompleto(Exception):
    """Una serie o una chiamata che manca o non è finita bene: uscita 1."""


class Problema(Exception):
    """Un file che non si legge, un uso sbagliato: uscita 2."""


class Chiamata(NamedTuple):
    """Ciò che il JSON dice di una chiamata."""
    nome: str
    modelli: str
    ingresso: int
    scritti: int
    letti: int
    uscita: int
    un_ora: Optional[int]
    cinque_minuti: Optional[int]
    secondi: float
    turni: int

    @property
    def totale(self) -> int:
        """Il totale in entrata: la somma dei tre campi di usage."""
        return self.ingresso + self.scritti + self.letti


class Serie(NamedTuple):
    """Una serie: il numero, il marcatore, le sue cinque chiamate."""
    numero: int
    marcatore: str
    chiamate: Dict[str, Chiamata]


def migliaia(numero: float) -> str:
    """Il numero intero con il punto delle migliaia."""
    return "{:,}".format(int(numero)).replace(",", ".")


def scrivi_secondi(valore: float) -> str:
    """I secondi con la virgola, un decimale."""
    return ("%.1f" % valore).replace(".", ",")


def conteggio(valore: Optional[int]) -> str:
    """Un conteggio, «n.d.» se il JSON non lo dà."""
    return "n.d." if valore is None else migliaia(valore)


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
    try:
        with open(percorso, encoding="utf-8") as fh:
            testo = fh.read()
    except (OSError, UnicodeDecodeError) as exc:
        raise Problema("%s non si legge (%s)" % (nome, exc)) from exc
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


def leggi_uso(dato: Dict[str, Any], nome: str) -> Dict[str, Any]:
    """Il campo usage di un JSON, con i suoi conteggi. Raises: Problema."""
    uso = dato.get("usage")
    if not isinstance(uso, dict):
        raise Problema("%s: il campo «usage» non c'è" % nome)
    for campo in ("input_tokens", "cache_creation_input_tokens",
                  "cache_read_input_tokens", "output_tokens"):
        intero(uso.get(campo), nome, "usage." + campo)
    return uso


def leggi_chiamata(cartella: str, numero: int, quale: str) -> Chiamata:
    """Una chiamata della serie. Raises: Incompleto, Problema."""
    nome = "%d-%s" % (numero, quale)
    dato = leggi_json(os.path.join(cartella, nome, "risposta.json"),
                      nome + "/risposta.json")
    if dato.get("is_error") or dato.get("subtype") != "success":
        raise Incompleto("%s: claude ha restituito un errore: %s"
                         % (nome, RIFARE))
    atteso = "sonnet" if quale == "sonnet" else "haiku"
    usati = dato.get("modelUsage")
    nomi = sorted(usati) if isinstance(usati, dict) else []
    if len(nomi) != 1 or atteso not in nomi[0]:
        raise Incompleto("%s: la chiamata non è su un solo modello %s "
                         "(modelUsage: %s): %s" % (
                             nome, atteso, ", ".join(nomi) or "vuoto", RIFARE))
    uso = leggi_uso(dato, nome)
    dettaglio = uso.get("cache_creation")
    if isinstance(dettaglio, dict):
        un_ora = intero(dettaglio.get("ephemeral_1h_input_tokens"), nome,
                        "cache_creation.ephemeral_1h_input_tokens")
        cinque_minuti = intero(dettaglio.get("ephemeral_5m_input_tokens"),
                               nome, "cache_creation.ephemeral_5m_input_tokens")
    else:
        un_ora = cinque_minuti = None
    modelli = dato.get("modelUsage")
    return Chiamata(
        nome, ", ".join(sorted(modelli)) if isinstance(modelli, dict) and
        modelli else "n.d.", uso["input_tokens"],
        uso["cache_creation_input_tokens"], uso["cache_read_input_tokens"],
        uso["output_tokens"], un_ora, cinque_minuti,
        float(intero(dato.get("duration_ms", 0), nome, "duration_ms")) / 1000,
        intero(dato.get("num_turns", 0), nome, "num_turns"))


def leggi_marcatore(cartella: str, numero: int) -> str:
    """Il marcatore di una serie, dalla prima riga del prefisso.
    Raises: Incompleto, Problema."""
    nome = "%d-prefisso.md" % numero
    percorso = os.path.join(cartella, nome)
    if not os.path.isfile(percorso):
        raise Incompleto("manca %s: %s" % (nome, RIFARE))
    try:
        with open(percorso, encoding="utf-8") as fh:
            prima = fh.readline().strip()
    except (OSError, UnicodeDecodeError) as exc:
        raise Problema("%s non si legge (%s)" % (nome, exc)) from exc
    trovato = MARCATORE.match(prima)
    if not trovato:
        raise Problema("%s: la prima riga non è quella del marcatore: «%s»"
                       % (nome, prima[:60]))
    return trovato.group(1)


def leggi_serie(cartella: str, numero: int) -> Serie:
    """Una serie intera, ogni mancanza in una volta. Raises: Incompleto,
    Problema."""
    mancano: List[str] = []
    marcatore = ""
    try:
        marcatore = leggi_marcatore(cartella, numero)
    except Incompleto as exc:
        mancano.append(str(exc))
    chiamate: Dict[str, Chiamata] = {}
    for quale in CHIAMATE:
        try:
            chiamate[quale] = leggi_chiamata(cartella, numero, quale)
        except Incompleto as exc:
            mancano.append(str(exc))
    if mancano:
        raise Incompleto("\n".join(mancano))
    return Serie(numero, marcatore, chiamate)


def numeri_serie(cartella: str) -> List[int]:
    """I numeri delle serie della cartella, da 1 al più alto.
    Raises: Problema."""
    try:
        nomi = os.listdir(cartella)
    except OSError as exc:
        raise Problema("la cartella %s non esiste o non si apre (%s)"
                       % (cartella, exc.strerror or exc)) from exc
    numeri = {int(m.group(1)) for m in map(ESECUZIONE.match, nomi)
              if m and os.path.isdir(os.path.join(cartella, m.group(0)))}
    if not numeri:
        raise Problema("nessuna serie in %s: %s" % (cartella, RIFARE))
    return list(range(1, max(numeri) + 1))


def leggi_tutto(cartella: str) -> List[Serie]:
    """Tutte le serie, ogni mancanza in una volta. Raises: Incompleto,
    Problema."""
    serie: List[Serie] = []
    mancano: List[str] = []
    for numero in numeri_serie(cartella):
        try:
            serie.append(leggi_serie(cartella, numero))
        except Incompleto as exc:
            mancano.append(str(exc))
    if mancano:
        raise Incompleto("\n".join(mancano))
    return serie


def stampa_tabella(serie: Serie) -> None:
    """La tabella dei conteggi di una serie: dati."""
    print(FORMA_RIGA % INTESTAZIONE)
    for quale in CHIAMATE:
        chiamata = serie.chiamate[quale]
        print(FORMA_RIGA % (
            chiamata.nome, chiamata.modelli, migliaia(chiamata.ingresso),
            migliaia(chiamata.scritti), migliaia(chiamata.letti),
            migliaia(chiamata.totale), migliaia(chiamata.uscita),
            conteggio(chiamata.un_ora), conteggio(chiamata.cinque_minuti)))


def garanzie(serie: Serie) -> List[Tuple[str, bool]]:
    """Le garanzie di una serie: il testo e se valgono."""
    prima, seconda, spenta, sonnet, ancora = (serie.chiamate[q]
                                              for q in CHIAMATE)
    return [
        ("la prima chiamata scrive in cache (scritti %s) e non legge "
         "(letti %s)" % (migliaia(prima.scritti), migliaia(prima.letti)),
         prima.scritti > 0 and prima.letti == 0),
        ("la stessa chiamata, ripetuta, legge dalla cache (letti %s)"
         % migliaia(seconda.letti), seconda.letti > 0),
        ("con DISABLE_PROMPT_CACHING=1 niente in cache (scritti %s, letti "
         "%s), il prefisso in input_tokens (%s)"
         % (migliaia(spenta.scritti), migliaia(spenta.letti),
            migliaia(spenta.ingresso)),
         spenta.scritti == 0 and spenta.letti == 0 and spenta.ingresso > 0),
        ("su Sonnet la cache di Haiku non vale (letti %s) e ne scrive una "
         "sua (scritti %s)"
         % (migliaia(sonnet.letti), migliaia(sonnet.scritti)),
         sonnet.letti == 0 and sonnet.scritti > 0),
        ("tornando su Haiku si legge di nuovo (letti %s)"
         % migliaia(ancora.letti), ancora.letti > 0),
    ]


def stampa_serie(serie: Serie) -> bool:
    """Una serie: la tabella, una riga di dati, le garanzie. Vero se tutte
    valgono."""
    print("== Serie %d (marcatore %s) ==" % (serie.numero, serie.marcatore))
    stampa_tabella(serie)
    prima, seconda = serie.chiamate["prima"], serie.chiamate["seconda"]
    print("La seconda chiamata ha letto %s token dei %s scritti dalla "
          "prima: un dato, non per forza tutto il prefisso."
          % (migliaia(seconda.letti), migliaia(prima.scritti)))
    print("Le garanzie della serie %d:" % serie.numero)
    tutte = True
    for testo, vale in garanzie(serie):
        print("  %s: %s" % (testo, CONFERMATA if vale else NON_CONFERMATA))
        tutte = tutte and vale
    return tutte


def stampa_totale(tutte: List[Serie]) -> None:
    """Il consumo di tutte le chiamate: dati, non esiti."""
    chiamate = [c for s in tutte for c in s.chiamate.values()]
    print("Come dati, tutte le %d chiamate: turni %d; token in entrata %s, "
          "in uscita %s; %s s." % (
              len(chiamate), sum(c.turni for c in chiamate),
              migliaia(sum(c.totale for c in chiamate)),
              migliaia(sum(c.uscita for c in chiamate)),
              scrivi_secondi(sum(c.secondi for c in chiamate))))


def controlla(cartella: str) -> int:
    """Il controllo di una cartella di chiamate; l'uscita del contratto."""
    tutte = leggi_tutto(cartella)
    print("Anthropic, sulla cache in Claude Code (%s):" % PAGINA)
    for frase in FRASI:
        print("  " + frase)
    print()
    valgono = True
    for serie in tutte:
        valgono = stampa_serie(serie) and valgono
        print()
    stampa_totale(tutte)
    if not valgono:
        print("Una garanzia non vale in questa esecuzione: il JSON dice che "
              "cosa è successo.")
        return 1
    return 0


def main(argv: List[str]) -> int:
    if len(argv) != 1 or argv[0].startswith("-"):
        sys.stderr.write(USO)
        return 2
    try:
        return controlla(argv[0])
    except Incompleto as exc:
        print(str(exc))
        return 1
    except Problema as exc:
        sys.stderr.write("controlla_cache: %s\n" % exc)
        return 2
    except Exception as exc:  # pylint: disable=broad-except
        sys.stderr.write("controlla_cache: errore inatteso (%s: %s)\n"
                         % (type(exc).__name__, exc))
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
