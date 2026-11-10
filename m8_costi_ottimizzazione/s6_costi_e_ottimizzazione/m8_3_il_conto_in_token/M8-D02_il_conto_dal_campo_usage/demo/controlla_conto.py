"""controlla_conto.py -- M8-D02 «Il conto dal campo usage»: il conto di ogni
esecuzione di in_classe.sh, letto dal JSON di `claude -p --output-format json`.

Legge, nella cartella data (risposte/ dello spazio di lavoro):
  contesto/risposta.json   /context, prima delle domande;
  breve-<n>/risposta.json  la domanda, con la richiesta di una riga sola;
  lunga-<n>/risposta.json  la stessa domanda, con la richiesta di una relazione
                           in sei sezioni;
e listino.json, accanto a questo script: i prezzi a listino in dollari per
milione di token.

Di ogni esecuzione stampa i token in entrata (la somma di input_tokens,
cache_creation_input_tokens e cache_read_input_tokens), i token in uscita,
total_cost_usd e il costo ricalcolato dal listino (input, scrittura in cache a
un'ora e a cinque minuti, lettura dalla cache e output, ciascuno al suo
prezzo), con la differenza fra i due: una dimostrazione, stampata come dato.

Poi la coppia, esecuzione per esecuzione: il rapporto fra le due risposte, in
token in uscita e in costo ricalcolato, e l'esito: «confermata» se la risposta
lunga ha più token in uscita e un costo ricalcolato più alto, «non
distinguibile» se i due numeri coincidono, «non confermata in questa
esecuzione» altrimenti. Una raccomandazione non fa fallire il controllo:
l'esito si conta «n su N» e non decide l'uscita.

Uso:    python3 -B -I controlla_conto.py <cartella delle esecuzioni>
Uscita: 0 ogni esecuzione c'è ed è finita bene · 1 un'esecuzione che manca, una
        chiamata con un errore, un'esecuzione su un altro modello · 2 uso
        sbagliato, cartella che non c'è o senza esecuzioni, un JSON che non si
        legge o a cui mancano i campi del conto, listino.json che non va, un
        errore inatteso (una riga, mai un traceback)
"""
from __future__ import annotations

import json
import os
import re
import sys
import textwrap
from typing import Any, Dict, List, NamedTuple, Tuple

USO = "Uso: python3 -B -I controlla_conto.py <cartella delle esecuzioni>\n"
LISTINO = "listino.json"
LARGHEZZA_RISPOSTA = 90
ALIAS = "haiku"
BRACCI = ("breve", "lunga")
ESECUZIONE = re.compile(r"^(breve|lunga)-([1-9][0-9]*)$")
CONTESTO = "contesto"
RISPOSTA = "risposta.json"
CAMPI_PREZZO = ("input", "output", "cache_write_5m", "cache_write_1h",
                "cache_read")
CONFERMATA = "confermata"
NON_CONFERMATA = "non confermata in questa esecuzione"
NON_DISTINGUIBILE = "non distinguibile"
RIFARE = "rifate la prova (il README dice come)"
MILIONE = 1_000_000


class Problema(Exception):
    """Qualcosa che non si riesce a leggere: uscita 2."""


class Incompleto(Exception):
    """Un'esecuzione che manca o non è finita bene: uscita 1."""


class Listino(NamedTuple):
    """I prezzi di un modello, con la loro provenienza."""
    prezzi: Dict[str, float]
    letto_il: str
    pagina: str


class Esecuzione(NamedTuple):
    """Il conto di una chiamata."""
    nome: str
    input_tokens: int
    creati_5m: int
    creati_1h: int
    letti: int
    uscita: int
    costo_json: float
    costo_ricalcolato: float
    turni: int
    secondi: float
    risposta: str

    @property
    def entrata(self) -> int:
        """I token in entrata: la somma dei tre campi del JSON."""
        return self.input_tokens + self.creati_5m + self.creati_1h + self.letti


def migliaia(numero: int) -> str:
    """Il numero intero con il punto delle migliaia."""
    return "{:,}".format(numero).replace(",", ".")


def dollari(valore: float) -> str:
    """Un importo con la virgola, sei decimali (mai «-0,000000»)."""
    return ("%.6f" % (round(valore, 6) + 0.0)).replace(".", ",")


def scrivi_decimale(valore: float, decimali: int = 1) -> str:
    """Un numero con la virgola."""
    return ("%.*f" % (decimali, valore)).replace(".", ",")


def leggi_oggetto(percorso: str, nome: str) -> Dict[str, Any]:
    """Un file JSON che deve essere un oggetto. Raises: Problema."""
    try:
        with open(percorso, encoding="utf-8") as fh:
            dati = json.load(fh)
    except (OSError, UnicodeDecodeError, ValueError) as exc:
        raise Problema("%s non si legge come JSON (%s)" % (nome, exc)) from exc
    if not isinstance(dati, dict):
        raise Problema("%s non è un oggetto JSON" % nome)
    return dati


def leggi_risposta(percorso: str, etichetta: str) -> Dict[str, Any]:
    """Il JSON di una chiamata, che deve esserci e non essere vuoto: una
    chiamata interrotta lascia un file vuoto. Raises: Incompleto, Problema."""
    if not os.path.isfile(percorso):
        raise Incompleto("manca %s: %s" % (etichetta, RIFARE))
    if os.path.getsize(percorso) == 0:
        raise Incompleto("%s è vuoto: la chiamata non è finita: %s"
                         % (etichetta, RIFARE))
    return leggi_oggetto(percorso, etichetta)


def leggi_listino(percorso: str) -> Listino:
    """I prezzi del modello della demo. Raises: Problema."""
    dati = leggi_oggetto(percorso, LISTINO)
    try:
        voce = dati["modelli"][ALIAS]
        prezzi = {campo: voce[campo] for campo in CAMPI_PREZZO}
        letto_il, pagina = dati["letto_il"], dati["pagina_prezzi"]
    except (KeyError, TypeError) as exc:
        raise Problema("%s: manca %s" % (LISTINO, exc)) from exc
    for campo, valore in prezzi.items():
        if isinstance(valore, bool) or not isinstance(valore, (int, float)) \
                or valore <= 0:
            raise Problema("%s: il prezzo «%s» di %s non è un numero positivo"
                           % (LISTINO, campo, ALIAS))
    if not isinstance(letto_il, str) or not isinstance(pagina, str):
        raise Problema("%s: letto_il e pagina_prezzi vanno scritti come testo"
                       % LISTINO)
    return Listino({k: float(v) for k, v in prezzi.items()}, letto_il, pagina)


def conteggio(dove: Dict[str, Any], chiave: str, nome: str) -> int:
    """Un conteggio di token, intero non negativo. Raises: Problema."""
    valore = dove.get(chiave)
    if isinstance(valore, bool) or not isinstance(valore, int) or valore < 0:
        raise Problema("%s: «%s» non è un conteggio di token: %r"
                       % (nome, chiave, valore))
    return valore


def numero_json(dati: Dict[str, Any], chiave: str, nome: str) -> float:
    """Un numero non negativo del JSON. Raises: Problema."""
    valore = dati.get(chiave)
    if isinstance(valore, bool) or not isinstance(valore, (int, float)) \
            or valore < 0:
        raise Problema("%s: «%s» non è un numero: %r" % (nome, chiave, valore))
    return float(valore)


def controlla_modello(dati: Dict[str, Any], nome: str) -> None:
    """La chiamata è su un solo modello, Haiku.
    Raises: Incompleto, Problema."""
    modelli = dati.get("modelUsage")
    if not isinstance(modelli, dict):
        raise Problema("%s: «modelUsage» non c'è" % nome)
    nomi = sorted(modelli)
    if len(nomi) != 1 or ALIAS not in nomi[0]:
        raise Incompleto("%s: la chiamata non è su un solo modello Haiku "
                         "(modelUsage: %s): %s"
                         % (nome, ", ".join(nomi) or "vuoto", RIFARE))


def leggi_usage(dati: Dict[str, Any], nome: str) -> Tuple[int, int, int, int,
                                                          int]:
    """I cinque conteggi di usage: input, scrittura a 5 minuti e a un'ora,
    lettura, output. Raises: Problema."""
    usage = dati.get("usage")
    if not isinstance(usage, dict):
        raise Problema("%s: «usage» non c'è" % nome)
    entrata = conteggio(usage, "input_tokens", nome)
    creati = conteggio(usage, "cache_creation_input_tokens", nome)
    letti = conteggio(usage, "cache_read_input_tokens", nome)
    uscita = conteggio(usage, "output_tokens", nome)
    dettaglio = usage.get("cache_creation")
    if not isinstance(dettaglio, dict):
        raise Problema("%s: «usage.cache_creation» non c'è: la scrittura in "
                       "cache non si prezza" % nome)
    cinque = conteggio(dettaglio, "ephemeral_5m_input_tokens", nome)
    ora = conteggio(dettaglio, "ephemeral_1h_input_tokens", nome)
    if cinque + ora != creati:
        raise Problema("%s: «cache_creation» a 5 minuti e a un'ora non "
                       "fanno %d" % (nome, creati))
    return entrata, cinque, ora, letti, uscita


def costo(prezzi: Dict[str, float], usage: Tuple[int, int, int, int, int]
          ) -> float:
    """Il costo a listino: ogni conteggio al suo prezzo."""
    entrata, cinque, ora, letti, uscita = usage
    return (entrata * prezzi["input"] + cinque * prezzi["cache_write_5m"]
            + ora * prezzi["cache_write_1h"] + letti * prezzi["cache_read"]
            + uscita * prezzi["output"]) / MILIONE


def leggi_chiamata(cartella: str, nome: str, prezzi: Dict[str, float]
                   ) -> Esecuzione:
    """Il conto di una chiamata. Raises: Incompleto, Problema."""
    etichetta = "%s/%s" % (nome, RISPOSTA)
    dati = leggi_risposta(os.path.join(cartella, nome, RISPOSTA), etichetta)
    if dati.get("is_error") or dati.get("subtype") != "success":
        raise Incompleto("%s: claude ha restituito un errore: %s"
                         % (etichetta, RIFARE))
    controlla_modello(dati, etichetta)
    usage = leggi_usage(dati, etichetta)
    entrata, cinque, ora, letti, uscita = usage
    testo = dati.get("result")
    return Esecuzione(nome, entrata, cinque, ora, letti, uscita,
                      numero_json(dati, "total_cost_usd", etichetta),
                      costo(prezzi, usage),
                      int(numero_json(dati, "num_turns", etichetta)),
                      numero_json(dati, "duration_ms", etichetta) / 1000,
                      testo if isinstance(testo, str) else "")


def numeri_esecuzioni(cartella: str) -> List[int]:
    """I numeri delle coppie della cartella. Raises: Problema."""
    try:
        nomi = os.listdir(cartella)
    except OSError as exc:
        raise Problema("la cartella %s non esiste o non si apre (%s)"
                       % (cartella, exc.strerror or exc)) from exc
    numeri = sorted({int(m.group(2)) for m in map(ESECUZIONE.match, nomi)
                     if m and os.path.isdir(os.path.join(cartella,
                                                         m.group(0)))})
    if not numeri:
        raise Problema("nessuna esecuzione in %s: %s" % (cartella, RIFARE))
    return numeri


def leggi_tutte(cartella: str, numeri: List[int], prezzi: Dict[str, float]
                ) -> Dict[str, Esecuzione]:
    """Tutte le chiamate, ogni mancanza in una volta. Raises: Incompleto;
    Problema, al primo JSON che non si legge."""
    chiamate: Dict[str, Esecuzione] = {}
    mancano: List[str] = []
    for numero in numeri:
        for braccio in BRACCI:
            nome = "%s-%d" % (braccio, numero)
            try:
                chiamate[nome] = leggi_chiamata(cartella, nome, prezzi)
            except Incompleto as exc:
                mancano.append(str(exc))
    if mancano:
        raise Incompleto("\n".join(mancano))
    return chiamate


def leggi_contesto(cartella: str) -> Dict[str, Any]:
    """Il JSON di /context. Raises: Incompleto, Problema."""
    etichetta = "%s/%s" % (CONTESTO, RISPOSTA)
    dati = leggi_risposta(os.path.join(cartella, CONTESTO, RISPOSTA),
                          etichetta)
    if dati.get("is_error") or dati.get("subtype") != "success":
        raise Incompleto("%s: claude ha restituito un errore: %s"
                         % (etichetta, RIFARE))
    return dati


def stampa_contesto(dati: Dict[str, Any], etichetta: str) -> None:
    """Il contesto di partenza: la tabella di /context e che cosa è costato,
    come dati."""
    usage = dati.get("usage") if isinstance(dati.get("usage"), dict) else {}
    token = sum(v for k, v in usage.items()
                if k in ("input_tokens", "output_tokens",
                         "cache_creation_input_tokens",
                         "cache_read_input_tokens") and isinstance(v, int))
    turni = numero_json(dati, "num_turns", etichetta)
    costo_json = numero_json(dati, "total_cost_usd", etichetta)
    print("== /context: il contesto di partenza ==")
    testo = dati.get("result")
    if isinstance(testo, str) and testo.strip():
        for riga in testo.strip().splitlines():
            print("  " + riga)
    print("(dato) /context in claude -p: %d turni, %s token, %s $%s"
          % (turni, migliaia(token), dollari(costo_json),
             ": non è una chiamata al modello." if not (turni or token
                                                        or costo_json)
             else "."))


def stampa_esecuzione(chiamata: Esecuzione) -> None:
    """Il conto di una chiamata: i token e i due costi."""
    print("%s: in %s = input_tokens %s + cache_creation %s + cache_read %s; "
          "out %s" % (chiamata.nome, migliaia(chiamata.entrata),
                      migliaia(chiamata.input_tokens),
                      migliaia(chiamata.creati_5m + chiamata.creati_1h),
                      migliaia(chiamata.letti), migliaia(chiamata.uscita)))
    print("  (dato) total_cost_usd %s · ricalcolato %s · differenza %s"
          % (dollari(chiamata.costo_json),
             dollari(chiamata.costo_ricalcolato),
             dollari(chiamata.costo_json - chiamata.costo_ricalcolato)))
    if chiamata.creati_1h and chiamata.creati_5m:
        print("  (dato) cache_creation: a un'ora %s, a cinque minuti %s"
              % (migliaia(chiamata.creati_1h), migliaia(chiamata.creati_5m)))
    print("  risposta: " + inizio_risposta(chiamata.risposta))


def inizio_risposta(testo: str) -> str:
    """L'inizio della risposta, su una riga."""
    return textwrap.shorten(" ".join(testo.split()) or "(vuota)",
                            width=LARGHEZZA_RISPOSTA, placeholder=" …")


def rapporto(numero: float, base: float) -> str:
    """Il rapporto scritto «×n,n»; «–» se la base è zero."""
    if base <= 0:
        return "–"
    return "×" + scrivi_decimale(numero / base)


def esito_coppia(breve: Esecuzione, lunga: Esecuzione) -> str:
    """L'esito di una coppia: la lunga ha più uscita e costa di più."""
    if lunga.uscita > breve.uscita \
            and lunga.costo_ricalcolato > breve.costo_ricalcolato:
        return CONFERMATA
    if lunga.uscita == breve.uscita \
            and lunga.costo_ricalcolato == breve.costo_ricalcolato:
        return NON_DISTINGUIBILE
    return NON_CONFERMATA


def stampa_coppie(chiamate: Dict[str, Esecuzione], numeri: List[int]) -> None:
    """Il confronto, esecuzione per esecuzione."""
    print("La raccomandazione (Anthropic): «Ask for the answer you will read, "
          "not the one that looks thorough.»")
    print("La coppia differisce soltanto nella richiesta sul formato. Che "
          "cosa si confronta: i token in uscita e il costo ricalcolato.")
    conferme = 0
    for numero in numeri:
        breve = chiamate["breve-%d" % numero]
        lunga = chiamate["lunga-%d" % numero]
        esito = esito_coppia(breve, lunga)
        conferme += esito == CONFERMATA
        print("  esecuzione %d: uscita %s → %s token (%s); costo ricalcolato "
              "%s → %s (%s): %s" % (
                  numero, migliaia(breve.uscita), migliaia(lunga.uscita),
                  rapporto(lunga.uscita, breve.uscita),
                  dollari(breve.costo_ricalcolato),
                  dollari(lunga.costo_ricalcolato),
                  rapporto(lunga.costo_ricalcolato,
                           breve.costo_ricalcolato), esito))
    print("  la risposta lunga con più token in uscita e un costo più alto: "
          "confermata %d su %d" % (conferme, len(numeri)))


def stampa_dati(listino: Listino, chiamate: Dict[str, Esecuzione]) -> None:
    """La frase sui prezzi, le somme e il totale: dati, nessun verdetto."""
    prezzi = listino.prezzi
    print("(dato) Anthropic: «Output tokens cost five times input tokens on "
          "Claude Haiku 5.5, Claude Sonnet 5.5, Claude Opus 5.5, Claude Fable "
          "5.2, and Claude Fable 5.1»; nel listino di %s %s $ contro %s $ per "
          "milione: %s volte." % (
              ALIAS, scrivi_decimale(prezzi["output"], 2),
              scrivi_decimale(prezzi["input"], 2),
              scrivi_decimale(prezzi["output"] / prezzi["input"])))
    massima = max(abs(c.costo_json - c.costo_ricalcolato)
                  for c in chiamate.values())
    print("(dato) fra total_cost_usd e il costo ricalcolato dai cinque "
          "conteggi la differenza più grande è %s $, una dimostrazione: "
          "Anthropic scrive che Claude Code calcola la cifra a listino dai "
          "conteggi dei token." % dollari(massima))
    print("(dato) il listino è di %s: %s" % (listino.letto_il, listino.pagina))
    tutte = list(chiamate.values())
    print("Come dati, tutte le %d chiamate: turni %d; token in entrata %s, "
          "in uscita %s; %s s." % (
              len(tutte), sum(c.turni for c in tutte),
              migliaia(sum(c.entrata for c in tutte)),
              migliaia(sum(c.uscita for c in tutte)),
              scrivi_decimale(sum(c.secondi for c in tutte))))


def controlla(cartella: str, percorso_listino: str) -> int:
    """Il controllo di una cartella di esecuzioni; l'uscita del contratto."""
    listino = leggi_listino(percorso_listino)
    numeri = numeri_esecuzioni(cartella)
    contesto = leggi_contesto(cartella)
    chiamate = leggi_tutte(cartella, numeri, listino.prezzi)
    stampa_contesto(contesto, "%s/%s" % (CONTESTO, RISPOSTA))
    print()
    print("== Il conto di ogni esecuzione ==")
    print("(dato) il listino in dollari per milione di token: input %s, "
          "output %s, scrittura a un'ora %s, a cinque minuti %s, lettura %s"
          % tuple(scrivi_decimale(listino.prezzi[c], 3) for c in
                  ("input", "output", "cache_write_1h", "cache_write_5m",
                   "cache_read")))
    for numero in numeri:
        for braccio in BRACCI:
            stampa_esecuzione(chiamate["%s-%d" % (braccio, numero)])
    print()
    print("== La coppia: la stessa domanda, due formati ==")
    stampa_coppie(chiamate, numeri)
    print()
    stampa_dati(listino, chiamate)
    return 0


def main(argv: List[str]) -> int:
    if len(argv) != 1 or argv[0].startswith("-"):
        sys.stderr.write(USO)
        return 2
    accanto = os.path.dirname(os.path.realpath(__file__))
    try:
        return controlla(argv[0], os.path.join(accanto, LISTINO))
    except Incompleto as exc:
        print(str(exc))
        return 1
    except Problema as exc:
        sys.stderr.write("controlla_conto: %s\n" % exc)
        return 2
    except Exception as exc:  # pylint: disable=broad-except
        sys.stderr.write("controlla_conto: errore inatteso (%s: %s)\n"
                         % (type(exc).__name__, exc))
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
