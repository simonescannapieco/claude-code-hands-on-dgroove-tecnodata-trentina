"""controlla_sistema.py -- M7-D01 «Cambia solo il system prompt»: le esecuzioni
di in_classe.sh alla prova.

Legge, nella cartella data (risposte/ dello spazio di lavoro):
  generico-<n>/stream.jsonl     il messaggio del cliente con il system prompt
                                neutro (una riga);
  ciaspolink-<n>/stream.jsonl   lo stesso messaggio con il ruolo di CiaspoLink
                                e la riga «al massimo tre righe»;
  memoria-<n>/   parola.txt (la parola in codice di quell'esecuzione),
                 primo.jsonl (la prima chiamata, con la parola),
                 nuova.jsonl (la domanda in una chiamata nuova, senza --resume),
                 ripresa.jsonl (la domanda nella sessione della prima chiamata,
                 con --resume).
Di ogni esecuzione stampa la risposta, le righe, le parole e i token della
prima richiesta (il contesto di partenza: system prompt, messaggio e ciò che
Claude Code aggiunge da sé). Poi:
  - il confronto fra i due system prompt: quante volte la riga «al massimo tre
    righe», la soglia che il secondo system prompt nomina, è rispettata in
    ciascun braccio, esecuzione per esecuzione: «confermata» se è rispettata
    con il ruolo e non con il system prompt neutro, «non distinguibile» se è
    rispettata in tutti e due, «non confermata in questa esecuzione» se il
    braccio con il ruolo non la rispetta. Il confronto si stampa e non
    decide l'uscita;
  - la memoria, due garanzie che dipendono da come funziona l'API: senza
    --resume la risposta non può contenere la parola (la chiamata non riceve
    la conversazione di prima); con --resume la contiene. Una garanzia che in
    un'esecuzione non vale fa uscire 1.

Uso:    python3 -B -I controlla_sistema.py <cartella delle esecuzioni>
Env:    PN_HANDSON_ROOT  il repository, dove sta tools/lib_leggi_contesto.py
                         (default: la radice sopra la cartella dell'elemento)
Uscita: 0 ogni esecuzione c'è, è finita bene e le due garanzie valgono ·
        1 un'esecuzione che manca, uno stream senza il risultato o con un
        errore, una garanzia che non vale · 2 uso sbagliato, cartella che
        non c'è o senza esecuzioni, uno stream che non si legge,
        tools/lib_leggi_contesto.py che manca, un errore inatteso (una riga,
        mai un traceback)
"""
from __future__ import annotations

import os
import re
import sys
import textwrap
from typing import Dict, List, NamedTuple, Tuple


def _strumenti() -> str:
    """tools/ del repository: PN_HANDSON_ROOT, o la radice sopra la cartella
    dell'elemento (<radice>/m7_…/s5_…/m7_2_…/M7-D01_…/demo/)."""
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

BRACCI = ("generico", "ciaspolink")
QUALE = {"generico": "il system prompt neutro",
         "ciaspolink": "il ruolo di CiaspoLink e al massimo tre righe"}
MASSIMO_RIGHE = 3
ESECUZIONE = re.compile(r"^(generico|ciaspolink|memoria)-([1-9][0-9]*)$")
PAROLA = re.compile(r"^[A-Z]+-[0-9]{4}$")
CONFERMATA = "confermata"
NON_CONFERMATA = "non confermata in questa esecuzione"
NON_DISTINGUIBILE = "non distinguibile"
RIFARE = "rifate la prova (il README dice come)"
USO = "Uso: python3 -B -I controlla_sistema.py <cartella delle esecuzioni>\n"
LARGHEZZA = 76
RIGHE_RISPOSTA = 6


class Incompleto(Exception):
    """Un'esecuzione che manca o non è finita bene: uscita 1."""


class Chiamata(NamedTuple):
    """Ciò che uno stream dice di una chiamata."""
    risposta: str
    righe: int
    parole: int
    prima: int
    turni: int
    secondi: float
    token: int


class Memoria(NamedTuple):
    """Una prova della parte 2: la parola e le sue tre chiamate."""
    nome: str
    parola: str
    primo: Chiamata
    nuova: Chiamata
    ripresa: Chiamata


def migliaia(numero: float) -> str:
    """Il numero intero con il punto delle migliaia."""
    return "{:,}".format(int(numero)).replace(",", ".")


def scrivi_secondi(valore: float) -> str:
    """I secondi con la virgola, un decimale."""
    return ("%.1f" % valore).replace(".", ",")


def con_segno(numero: int) -> str:
    """Il numero con il segno, senza segno lo zero."""
    if numero == 0:
        return "0"
    return ("+" if numero > 0 else "-") + migliaia(abs(numero))


def leggi_chiamata(percorso: str, nome: str) -> Chiamata:
    """Una chiamata da uno stream. I token sono quelli di `usage` della
    chiamata, non `modelUsage`: con --resume il secondo somma anche la
    chiamata di prima. Raises: Incompleto, Problema."""
    if not os.path.isfile(percorso):
        raise Incompleto("manca %s: %s" % (nome, RIFARE))
    esecuzione = lc.leggi_stream(percorso)
    if not esecuzione.completa:
        raise Incompleto("%s: lo stream non finisce con il risultato, la "
                         "chiamata si è interrotta: %s" % (nome, RIFARE))
    if esecuzione.errore:
        raise Incompleto("%s: claude ha restituito un errore: %s"
                         % (nome, RIFARE))
    contesto = lc.leggi_contesto(percorso)
    testo = esecuzione.testo
    righe = [r for r in testo.splitlines() if r.strip()]
    return Chiamata(testo, len(righe), len(testo.split()),
                    contesto.prima_richiesta, int(esecuzione.turni),
                    float(esecuzione.secondi), int(esecuzione.token_usage))


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


def leggi_parola(dentro: str, nome: str) -> str:
    """La parola in codice di un'esecuzione. Raises: Incompleto, Problema."""
    percorso = os.path.join(dentro, "parola.txt")
    if not os.path.isfile(percorso):
        raise Incompleto("manca %s/parola.txt: %s" % (nome, RIFARE))
    try:
        with open(percorso, encoding="utf-8") as fh:
            parola = fh.read().strip()
    except (OSError, UnicodeDecodeError) as exc:
        raise lc.Problema("%s/parola.txt non si legge (%s)" % (nome, exc)) \
            from exc
    if not PAROLA.match(parola):
        raise lc.Problema("%s/parola.txt: «%s» non è una parola in codice"
                          % (nome, parola))
    return parola


def leggi_memoria(cartella: str, numero: int) -> Memoria:
    """Una prova della parte 2. Raises: Incompleto, Problema."""
    nome = "memoria-%d" % numero
    dentro = os.path.join(cartella, nome)
    if not os.path.isdir(dentro):
        raise Incompleto("manca %s/: %s" % (nome, RIFARE))
    parola = leggi_parola(dentro, nome)
    letture = []
    for file_, chi in (("primo", "la prima chiamata"), ("nuova", "la chiamata "
                       "nuova"), ("ripresa", "la chiamata con --resume")):
        letture.append(leggi_chiamata(
            os.path.join(dentro, file_ + ".jsonl"),
            "%s/%s.jsonl (%s)" % (nome, file_, chi)))
    return Memoria(nome, parola, *letture)


def leggi_tutto(cartella: str, numeri: List[int]
                ) -> Tuple[Dict[str, Chiamata], Dict[int, Memoria]]:
    """Tutte le esecuzioni, ogni mancanza in una volta. Raises: Incompleto;
    Problema, al primo stream che non si legge."""
    chiamate: Dict[str, Chiamata] = {}
    memorie: Dict[int, Memoria] = {}
    mancano: List[str] = []
    for numero in numeri:
        for braccio in BRACCI:
            nome = "%s-%d" % (braccio, numero)
            percorso = os.path.join(cartella, nome, "stream.jsonl")
            try:
                chiamate[nome] = leggi_chiamata(percorso,
                                                nome + "/stream.jsonl")
            except Incompleto as exc:
                mancano.append(str(exc))
        try:
            memorie[numero] = leggi_memoria(cartella, numero)
        except Incompleto as exc:
            mancano.append(str(exc))
    if mancano:
        raise Incompleto("\n".join(mancano))
    return chiamate, memorie


def a_capo(testo: str, rientro: str) -> List[str]:
    """La risposta su righe larghe LARGHEZZA, al massimo RIGHE_RISPOSTA."""
    righe = textwrap.wrap(" ".join(testo.split()),
                          LARGHEZZA - len(rientro)) or ["(vuota)"]
    if len(righe) > RIGHE_RISPOSTA:
        righe = righe[:RIGHE_RISPOSTA]
        righe[-1] += " …"
    return [rientro + r for r in righe]


def stampa_chiamata(nome: str, quale: str, chiamata: Chiamata) -> None:
    """Le righe di un'esecuzione della parte 1."""
    print("%s (%s)" % (nome, quale))
    print("  risposta:")
    for riga in a_capo(chiamata.risposta, "    "):
        print(riga)
    print("  righe %d, parole %d; prima richiesta %s token; turni %d, %s s, "
          "%s token" % (chiamata.righe, chiamata.parole,
                        migliaia(chiamata.prima), chiamata.turni,
                        scrivi_secondi(chiamata.secondi),
                        migliaia(chiamata.token)))


def rispetta(chiamata: Chiamata) -> bool:
    """Vero se la risposta sta in MASSIMO_RIGHE righe non vuote."""
    return chiamata.righe <= MASSIMO_RIGHE


def stampa_parte_uno(chiamate: Dict[str, Chiamata],
                     numeri: List[int]) -> None:
    """La parte 1: ogni esecuzione, la soglia e il confronto fra i bracci."""
    print("== Parte 1: lo stesso messaggio, due system prompt ==")
    for numero in numeri:
        for braccio in BRACCI:
            nome = "%s-%d" % (braccio, numero)
            stampa_chiamata(nome, QUALE[braccio], chiamate[nome])
    print()
    print("La riga «al massimo tre righe», che il secondo system prompt nomina"
          " (una soglia del prompt, non di Anthropic):")
    rispettate = {b: sum(rispetta(chiamate["%s-%d" % (b, n)]) for n in numeri)
                  for b in BRACCI}
    print("  rispettata: generico %d su %d, ciaspolink %d su %d" % (
        rispettate["generico"], len(numeri), rispettate["ciaspolink"],
        len(numeri)))
    print("La coppia, esecuzione per esecuzione (differiscono solo nel system "
          "prompt):")
    conferme = 0
    for numero in numeri:
        gen = chiamate["generico-%d" % numero]
        cia = chiamate["ciaspolink-%d" % numero]
        esito = esito_coppia(gen, cia)
        conferme += esito == CONFERMATA
        print("  esecuzione %d: generico %d righe, ciaspolink %d righe: %s"
              % (numero, gen.righe, cia.righe, esito))
    print("  confermata %d su %d" % (conferme, len(numeri)))
    print("La prima richiesta, in token (cambia solo il system prompt):")
    for numero in numeri:
        gen = chiamate["generico-%d" % numero]
        cia = chiamate["ciaspolink-%d" % numero]
        print("  esecuzione %d: generico %s, ciaspolink %s (%s)" % (
            numero, migliaia(gen.prima), migliaia(cia.prima),
            con_segno(cia.prima - gen.prima)))


def esito_coppia(generico: Chiamata, ciaspolink: Chiamata) -> str:
    """L'esito di una coppia, sulla soglia che il system prompt nomina."""
    if not rispetta(ciaspolink):
        return NON_CONFERMATA
    return NON_DISTINGUIBILE if rispetta(generico) else CONFERMATA


def contiene(parola: str, risposta: str) -> bool:
    """Vero se la risposta contiene la parola, senza badare alle maiuscole."""
    return parola.lower() in risposta.lower()


def stampa_memoria(memoria: Memoria) -> bool:
    """Una prova della parte 2; vero se le due garanzie valgono."""
    print("%s (la parola in codice: %s)" % (memoria.nome, memoria.parola))
    print("  la chiamata nuova, senza --resume:")
    for riga in a_capo(memoria.nuova.risposta, "    "):
        print(riga)
    print("  la chiamata nella sessione della prima, con --resume:")
    for riga in a_capo(memoria.ripresa.risposta, "    "):
        print(riga)
    senza = not contiene(memoria.parola, memoria.nuova.risposta)
    con = contiene(memoria.parola, memoria.ripresa.risposta)
    print("  senza --resume la risposta non contiene la parola: %s"
          % (CONFERMATA if senza else NON_CONFERMATA))
    print("  con --resume la risposta contiene la parola: %s"
          % (CONFERMATA if con else NON_CONFERMATA))
    print("  prima richiesta: nuova %s token, ripresa %s (%s)" % (
        migliaia(memoria.nuova.prima), migliaia(memoria.ripresa.prima),
        con_segno(memoria.ripresa.prima - memoria.nuova.prima)))
    return senza and con


def stampa_totale(chiamate: Dict[str, Chiamata],
                  memorie: Dict[int, Memoria]) -> None:
    """Il consumo di tutte le chiamate: dati, non esiti."""
    tutte = list(chiamate.values())
    for memoria in memorie.values():
        tutte += [memoria.primo, memoria.nuova, memoria.ripresa]
    print("Come dati, tutte le %d chiamate: turni %d; token %s; %s s." % (
        len(tutte), sum(c.turni for c in tutte),
        migliaia(sum(c.token for c in tutte)),
        scrivi_secondi(sum(c.secondi for c in tutte))))


def controlla(cartella: str) -> int:
    """Il controllo di una cartella di esecuzioni; l'uscita del contratto."""
    numeri = numeri_esecuzioni(cartella)
    chiamate, memorie = leggi_tutto(cartella, numeri)
    stampa_parte_uno(chiamate, numeri)
    print()
    print("== Parte 2: la memoria, senza e con --resume ==")
    print("Anthropic: «The Messages API is stateless, which means that you "
          "always send the full conversational history to the API.»")
    print("Le due garanzie: senza --resume la chiamata non ha la "
          "conversazione di prima; con --resume sì.")
    tutte = True
    for numero in numeri:
        tutte = stampa_memoria(memorie[numero]) and tutte
    print()
    stampa_totale(chiamate, memorie)
    if not tutte:
        print("Una garanzia non vale in questa esecuzione: lo stream dice "
              "che cosa è successo.")
        return 1
    return 0


def main(argv: List[str]) -> int:
    if len(argv) != 1 or argv[0].startswith("-"):
        sys.stderr.write(USO)
        return 2
    if lc is None:
        sys.stderr.write("controlla_sistema: non trovo "
                         "tools/lib_leggi_contesto.py in %s: date "
                         "PN_HANDSON_ROOT\n" % STRUMENTI)
        return 2
    try:
        return controlla(argv[0])
    except Incompleto as exc:
        print(str(exc))
        return 1
    except lc.Problema as exc:
        sys.stderr.write("controlla_sistema: %s\n" % exc)
        return 2
    except Exception as exc:  # pylint: disable=broad-except
        sys.stderr.write("controlla_sistema: errore inatteso (%s: %s)\n"
                         % (type(exc).__name__, exc))
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
