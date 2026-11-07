"""controlla_documento.py -- M6-D01 «Il documento che nessun modello ha
letto»: le esecuzioni di in_classe.sh alla prova.

Legge, nella cartella data (risposte/ dello spazio di lavoro), una cartella
per esecuzione, ciascuna con lo stream.jsonl di `claude -p --output-format
stream-json --verbose`:
  senza-<n>/  la domanda in una cartella senza la carta dei servizi;
  con-<n>/    la stessa domanda, con la carta importata dal CLAUDE.md della
              cartella.
Di ogni esecuzione stampa: gli strumenti che Claude ha chiamato e che cosa
hanno trovato; la risposta; se ha le cifre dell'Art. 4 della carta, i giorni
lavorativi che rispondono alla domanda; i numeri della risposta fuori dalle
citazioni, che senza la carta sono inventati (un dato, mai un esito); gli
articoli citati; i token della prima richiesta; turni, secondi e token,
sommati su ogni segmento. Se un risultato di uno strumento, senza la carta,
contiene una riga della carta, lo dice: è la fuga da cercare.

Poi il controllo delle citazioni, una dimostrazione: ogni articolo che la
risposta cita, cercato nella carta (carta-servizi.md, accanto a questo file),
con i suoi numeri, e i numeri della risposta cercati in quegli articoli.

Poi la coppia, esecuzione per esecuzione: con la carta le cifre dell'Art. 4 e
senza no, «confermata»; tutte e due con le cifre, «non distinguibile» (una
fuga da cercare); con la carta senza le cifre, «non confermata in questa
esecuzione»; e «confermata n su N». Un esito non decide l'uscita.

Uso:    python3 -B -I controlla_documento.py <cartella delle esecuzioni>
Env:    PN_HANDSON_ROOT  il repository, dove sta tools/lib_leggi_contesto.py
                         (default: la radice sopra la cartella dell'elemento)
Uscita: 0 ogni esecuzione c'è ed è finita bene · 1 un'esecuzione che manca
        alla sua coppia, uno stream senza il risultato o con un errore: la
        prova va rifatta · 2 uso sbagliato; la cartella che non c'è o senza
        esecuzioni; uno stream che non si legge; la carta o
        tools/lib_leggi_contesto.py che mancano; un errore inatteso (una riga,
        mai un traceback)
"""
from __future__ import annotations

import os
import re
import sys
import textwrap
from typing import Dict, List, NamedTuple, Sequence


def _strumenti() -> str:
    """tools/ del repository: PN_HANDSON_ROOT, o la radice sopra la cartella
    dell'elemento (<radice>/m6_…/s5_…/m6_2_…/M6-D01_…/demo/)."""
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

BRACCI = ("senza", "con")
QUALE = {"senza": "senza la carta",
         "con": "con la carta, importata dal CLAUDE.md"}
ESECUZIONE = re.compile(r"^(senza|con)-([1-9][0-9]*)$")
ART_DOMANDA = 4
CARTA = "carta-servizi.md"
CONFERMATA = "confermata"
NON_CONFERMATA = "non confermata in questa esecuzione"
NON_DISTINGUIBILE = "non distinguibile"
RIFARE = "rifate la prova (il README dice come)"
USO = "Uso: python3 -B -I controlla_documento.py <cartella delle esecuzioni>\n"
LARGHEZZA = 76
RIGHE_RISPOSTA = 8
RIGA_DI_CARTA = 30
CERCA = ("Read", "Grep", "Glob")
VUOTI = ("no matches found", "no files found", "")
# I numeri in lettere che non sono anche parole d'altro («sei», «venti»…).
PAROLE = {"due": 2, "tre": 3, "quattro": 4, "cinque": 5, "sette": 7,
          "otto": 8, "nove": 9, "dieci": 10, "undici": 11, "dodici": 12,
          "quindici": 15, "trenta": 30}
# Un numero intero, anche con il punto delle migliaia; mai un pezzo di un
# decimale («0,2») o di una parola.
NUMERO = re.compile(r"(?<![\w.,])(\d{1,3}(?:\.\d{3})+|\d+)(?!\w|[.,]\d)"
                    r"|\b(%s)\b" % "|".join(PAROLE), re.IGNORECASE)
GIORNI = re.compile(r"(?<![\w.,])(\d+) giorni lavorativi")
# Una data non è una cifra della carta: «il 7 novembre 2026».
MESI = ("gennaio|febbraio|marzo|aprile|maggio|giugno|luglio|agosto|"
        "settembre|ottobre|novembre|dicembre")
DATA = re.compile(r"\b\d{1,2}°?\s+(?:%s)(?:\s+\d{4})?\b" % MESI,
                  re.IGNORECASE)
# Un numero di articolo non è seguito da un'unità: «l'Art. 4, 5 giorni» cita
# l'articolo 4 e dice 5 giorni.
MISURA = r"(?:giorn[oi]|gg\.?|or[ae]|euro|metri)(?!\w)"
NON_MISURA = r"(?!\d)(?!\s+(?:[^\W\d_]+\s+)?%s)" % MISURA
CITAZIONE = re.compile(r"\b(?:art(?:icol[oi])?|artt)\.?\s*(\d+%s"
                       r"(?:\s*(?:,|e)\s*\d+%s)*)" % (NON_MISURA, NON_MISURA),
                       re.IGNORECASE)
SEZIONE = re.compile(r"^## Art\. ([0-9]+) — (.+)$")
ANSI = re.compile(r"\x1b\[[0-9;]*m")


class Incompleto(Exception):
    """Un'esecuzione che manca o non è finita bene: uscita 1."""


class Articolo(NamedTuple):
    """Un articolo della carta: il titolo, le righe, i numeri come vi sono
    scritti."""
    numero: int
    titolo: str
    righe: List[str]
    numeri: List[str]


class Chiamata(NamedTuple):
    """Uno strumento chiamato e il testo del suo risultato."""
    descrizione: str
    risultato: str


class Run(NamedTuple):
    """Che cosa dice un'esecuzione."""
    nome: str
    chiamate: List[Chiamata]
    risposta: str
    numeri: List[str]
    citati: List[int]
    prima: int
    turni: int
    secondi: float
    token: int


def migliaia(numero: float) -> str:
    """Il numero intero con il punto delle migliaia."""
    return "{:,}".format(int(numero)).replace(",", ".")


def secondi(valore: float) -> str:
    """I secondi con la virgola, un decimale."""
    return ("%.1f" % valore).replace(".", ",")


def con_segno(numero: int) -> str:
    """Il numero con il segno, senza segno lo zero."""
    if numero == 0:
        return "0"
    return ("+" if numero > 0 else "-") + migliaia(abs(numero))


def citati_di(testo: str) -> List[int]:
    """I numeri degli articoli citati, nell'ordine, senza doppioni."""
    numeri: List[int] = []
    for gruppo in CITAZIONE.finditer(testo):
        for numero in re.findall(r"\d+", gruppo.group(1)):
            if int(numero) not in numeri:
                numeri.append(int(numero))
    return numeri


def valore(numero: str) -> int:
    """Il valore di un numero scritto in cifre o in lettere."""
    if numero.lower() in PAROLE:
        return PAROLE[numero.lower()]
    return int(numero.replace(".", ""))


def numeri_di(testo: str) -> List[str]:
    """I numeri di un testo, come vi sono scritti, fuori dalle citazioni di
    articoli e dalle date; nell'ordine, ogni valore una volta."""
    fuori = ANSI.sub("", testo)
    for schema in (CITAZIONE, DATA):
        fuori = schema.sub(lambda m: " " * len(m.group(0)), fuori)
    numeri: List[str] = []
    for cifre, parola in NUMERO.findall(fuori):
        numero = parola or cifre
        if valore(numero) not in {valore(n) for n in numeri}:
            numeri.append(numero)
    return numeri


def scrivi_numeri(numeri: Sequence[str]) -> str:
    """«5, 9», o «nessuno»."""
    return ", ".join(numeri) or "nessuno"


def leggi_carta() -> Dict[int, Articolo]:
    """Gli articoli della carta accanto a questo file. Raises: Problema."""
    percorso = os.path.join(os.path.dirname(os.path.realpath(__file__)),
                            CARTA)
    try:
        with open(percorso, encoding="utf-8") as fh:
            righe = fh.read().splitlines()
    except (OSError, UnicodeDecodeError) as exc:
        raise lc.Problema("manca %s accanto al controllo, o non si legge "
                          "(%s)" % (CARTA, exc)) from exc
    articoli: Dict[int, Articolo] = {}
    numero = 0
    titolo = ""
    corpo: List[str] = []
    for riga in righe + ["## fine"]:
        if riga.startswith("## "):
            if numero:
                articoli[numero] = Articolo(numero, titolo, corpo,
                                            numeri_di(" ".join(corpo)))
            sezione = SEZIONE.match(riga)
            numero = int(sezione.group(1)) if sezione else 0
            titolo = sezione.group(2) if sezione else ""
            corpo = []
        elif numero and riga.strip():
            corpo.append(riga.strip())
    if not attese_di(articoli):
        raise lc.Problema("%s non ha l'Art. %d con i suoi giorni lavorativi"
                          % (CARTA, ART_DOMANDA))
    return articoli


def attese_di(articoli: Dict[int, Articolo]) -> List[int]:
    """Le cifre che rispondono alla domanda: i «N giorni lavorativi» dell'Art.
    4."""
    articolo = articoli.get(ART_DOMANDA)
    if articolo is None:
        return []
    return [int(n) for n in GIORNI.findall(" ".join(articolo.righe))]


def relativo(percorso: str, nome: str) -> str:
    """Un percorso da stampare: relativo alla copia dell'esecuzione (la
    cartella <nome> che in_classe.sh ha creato), «~/…» sotto la home,
    altrimenti com'è, segnato «fuori dalla cartella»."""
    dove = percorso.rfind("/%s/" % nome)
    if dove >= 0:
        return percorso[dove + len(nome) + 2:] or "."
    if percorso.endswith("/" + nome):
        return "."
    if not percorso.startswith("/"):
        return percorso
    casa = os.path.expanduser("~")
    if casa not in ("", "/", "~") and percorso.startswith(casa + "/"):
        percorso = "~/" + percorso[len(casa) + 1:]
    return percorso + " (fuori dalla cartella)"


def descrivi(nome: str, ingresso: object, esecuzione: str) -> str:
    """Uno strumento chiamato, con ciò che conta del suo input."""
    if not isinstance(ingresso, dict) or nome not in CERCA:
        return nome
    if nome == "Read":
        return "Read %s" % relativo(str(ingresso.get("file_path", "?")),
                                    esecuzione)
    parti = [nome]
    if ingresso.get("pattern") is not None:
        parti.append("«%s»" % ingresso["pattern"])
    if ingresso.get("glob"):
        parti.append("nei file %s" % ingresso["glob"])
    parti.append("in %s" % (relativo(str(ingresso["path"]), esecuzione)
                            if ingresso.get("path") else "."))
    return " ".join(parti)


def esito_di(testo: str) -> str:
    """Che cosa ha trovato uno strumento, in poche parole."""
    pulito = ANSI.sub("", testo).strip()
    if pulito.lower() in VUOTI:
        return "nessun risultato"
    righe = [r for r in pulito.splitlines() if r.strip()]
    return "1 riga" if len(righe) == 1 else "%d righe" % len(righe)


def chiamate_di(percorso: str, nome: str,
                risultati: Dict[str, lc.Risultato]) -> List[Chiamata]:
    """Gli strumenti chiamati, una volta per id, con il loro risultato."""
    chiamate: List[Chiamata] = []
    visti = set()
    for evento in lc._eventi(percorso):
        messaggio = evento.get("message")
        contenuto = messaggio.get("content") \
            if isinstance(messaggio, dict) else None
        if evento.get("type") != "assistant" \
                or not isinstance(contenuto, list):
            continue
        for blocco in contenuto:
            if not isinstance(blocco, dict) \
                    or blocco.get("type") != "tool_use" \
                    or blocco.get("id") in visti:
                continue
            visti.add(blocco.get("id"))
            risultato = risultati.get(str(blocco.get("id")))
            chiamate.append(Chiamata(
                descrivi(str(blocco.get("name")), blocco.get("input"), nome),
                risultato.testo if risultato is not None else ""))
    return chiamate


def leggi_run(cartella: str, nome: str) -> Run:
    """Un'esecuzione. Raises: Incompleto, Problema."""
    percorso = os.path.join(cartella, nome, "stream.jsonl")
    if not os.path.isfile(percorso):
        raise Incompleto("manca %s/stream.jsonl: %s" % (nome, RIFARE))
    esecuzione = lc.leggi_stream(percorso)
    if not esecuzione.completa:
        raise Incompleto("%s: lo stream non finisce con il risultato, la "
                         "chiamata si è interrotta: %s" % (nome, RIFARE))
    if esecuzione.errore:
        raise Incompleto("%s: claude ha restituito un errore: %s"
                         % (nome, RIFARE))
    contesto = lc.leggi_contesto(percorso)
    risposta = esecuzione.testo
    return Run(nome, chiamate_di(percorso, nome, contesto.risultati),
               risposta, numeri_di(risposta), citati_di(risposta),
               contesto.prima_richiesta, int(esecuzione.turni),
               float(esecuzione.secondi), int(esecuzione.token_totali))


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
    Problema, al primo stream che non si legge."""
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


def a_capo(testo: str, rientro: str) -> List[str]:
    """La risposta su righe di LARGHEZZA, al massimo RIGHE_RISPOSTA."""
    righe = textwrap.wrap(" ".join(ANSI.sub("", testo).split()),
                          LARGHEZZA - len(rientro)) or ["(vuota)"]
    if len(righe) > RIGHE_RISPOSTA:
        righe = righe[:RIGHE_RISPOSTA]
        righe[-1] += " …"
    return [rientro + r for r in righe]


def ha_le_cifre(run: Run, attese: Sequence[int]) -> bool:
    """Vero se la risposta ha tutte le cifre dell'Art. 4."""
    return set(attese) <= {valore(n) for n in run.numeri}


def righe_di_carta(articoli: Dict[int, Articolo]) -> List[str]:
    """Le righe della carta abbastanza lunghe da riconoscerla."""
    return [r for a in articoli.values() for r in a.righe
            if len(r) >= RIGA_DI_CARTA]


def stampa_run(run: Run, attese: Sequence[int], segni: List[str]) -> None:
    """Le righe di un'esecuzione."""
    braccio = run.nome.split("-")[0]
    print("%s (%s)" % (run.nome, QUALE[braccio]))
    print("  strumenti:%s" % ("" if run.chiamate else " nessuno"))
    for chiamata in run.chiamate:
        print("    %s: %s" % (chiamata.descrizione,
                              esito_di(chiamata.risultato)))
        if braccio == "senza" \
                and any(s in chiamata.risultato for s in segni):
            print("    il risultato contiene righe della carta: è la fuga "
                  "da cercare")
    print("  risposta:")
    for riga in a_capo(run.risposta, "    "):
        print(riga)
    print("  le cifre dell'Art. %d, %s giorni lavorativi: %s" % (
        ART_DOMANDA, " e ".join(str(n) for n in attese),
        "sì" if ha_le_cifre(run, attese) else "no"))
    print("  i numeri della risposta, fuori da citazioni e date: %s"
          % scrivi_numeri(run.numeri))
    print("  articoli citati: %s" % (", ".join(
        "Art. %d" % n for n in run.citati) or "nessuno"))
    print("  prima richiesta: %s token; turni %d, %s s, %s token" % (
        migliaia(run.prima), run.turni, secondi(run.secondi),
        migliaia(run.token)))


def stampa_citazioni(letti: Dict[str, Run], numeri: List[int],
                     articoli: Dict[int, Articolo]) -> None:
    """Il controllo delle citazioni: una dimostrazione."""
    print("Il controllo delle citazioni, una dimostrazione: lo script cerca "
          "nella carta")
    print("ogni articolo citato e vi cerca i numeri della risposta.")
    nessuna = True
    for braccio in BRACCI:
        for numero in numeri:
            run = letti["%s-%d" % (braccio, numero)]
            if not run.citati:
                continue
            nessuna = False
            nella_carta: List[int] = []
            for n in run.citati:
                articolo = articoli.get(n)
                if articolo is None:
                    print("  %s, Art. %d: non c'è nella carta" % (run.nome, n))
                    continue
                nella_carta += [valore(x) for x in articolo.numeri]
                print("  %s, Art. %d «%s»: nella carta %s" % (
                    run.nome, n, articolo.titolo,
                    scrivi_numeri(articolo.numeri)))
            fuori = [n for n in run.numeri if valore(n) not in nella_carta]
            print("    i numeri della risposta negli articoli citati: %s" % (
                "tutti" if not fuori else "non " + scrivi_numeri(fuori)))
    if nessuna:
        print("  nessuna risposta cita un articolo")


def verdetto(con: Run, senza: Run, attese: Sequence[int]) -> str:
    """La coppia di un'esecuzione: con la carta contro senza."""
    cifre = " e ".join(str(n) for n in attese)
    if not ha_le_cifre(con, attese):
        return "%s (con la carta, %s giorni non ci sono)" % (NON_CONFERMATA,
                                                            cifre)
    if ha_le_cifre(senza, attese):
        return "%s (%s giorni anche senza la carta: una fuga da cercare)" \
            % (NON_DISTINGUIBILE, cifre)
    return "%s (con la carta %s giorni; senza, no)" % (CONFERMATA, cifre)


def stampa_coppia(letti: Dict[str, Run], numeri: List[int],
                  attese: Sequence[int]) -> None:
    """La coppia, esecuzione per esecuzione, e «confermata n su N»."""
    print("«It only responds to what's currently in context»: la stessa "
          "domanda, con")
    print("la carta nel contesto e senza nessun documento.")
    conferme = 0
    for numero in numeri:
        esito = verdetto(letti["con-%d" % numero],
                         letti["senza-%d" % numero], attese)
        conferme += esito.startswith(CONFERMATA)
        print("  esecuzione %d: %s" % (numero, esito))
    print("  %s %d su %d" % (CONFERMATA, conferme, len(numeri)))


def stampa_dati(letti: Dict[str, Run], numeri: List[int]) -> None:
    """La prima richiesta dei due bracci e il consumo di tutte le chiamate."""
    print("Come dati, la prima richiesta, con la carta e senza:")
    for numero in numeri:
        con, senza = letti["con-%d" % numero], letti["senza-%d" % numero]
        print("  esecuzione %d: con %s, senza %s token (%s)" % (
            numero, migliaia(con.prima), migliaia(senza.prima),
            con_segno(con.prima - senza.prima)))
    tutti = list(letti.values())
    print("Come dati, tutte le %d chiamate: turni %d; token %s; %s s." % (
        len(tutti), sum(r.turni for r in tutti),
        migliaia(sum(r.token for r in tutti)),
        secondi(sum(r.secondi for r in tutti))))


def controlla(cartella: str) -> int:
    """Il controllo: stampa i dati e gli esiti; l'uscita 0."""
    articoli = leggi_carta()
    attese = attese_di(articoli)
    numeri = numeri_esecuzioni(cartella)
    letti = leggi_tutto(cartella, numeri)
    print("La carta: %d articoli; l'Art. %d «%s»" % (
        len(articoli), ART_DOMANDA, articoli[ART_DOMANDA].titolo))
    print("dice %s giorni lavorativi." % " e ".join(str(n) for n in attese))
    segni = righe_di_carta(articoli)
    for braccio in BRACCI:
        for numero in numeri:
            print()
            stampa_run(letti["%s-%d" % (braccio, numero)], attese, segni)
    print()
    stampa_citazioni(letti, numeri, articoli)
    print()
    stampa_coppia(letti, numeri, attese)
    print()
    stampa_dati(letti, numeri)
    return 0


def errore(messaggio: str, uscita: int) -> int:
    """Il messaggio su STDERR, una riga per problema; l'uscita data."""
    for riga in messaggio.split("\n"):
        sys.stderr.write("controlla_documento.py: %s\n" % riga)
    return uscita


def main(argv: List[str]) -> int:
    for flusso in (sys.stdout, sys.stderr):
        riconfigura = getattr(flusso, "reconfigure", None)
        if riconfigura is not None:
            riconfigura(errors="replace")
    if len(argv) != 1 or argv[0].startswith("-"):
        sys.stderr.write(USO)
        return 2
    if lc is None:
        return errore("non trovo tools/lib_leggi_contesto.py in %s: date "
                      "PN_HANDSON_ROOT" % STRUMENTI, 2)
    try:
        return controlla(argv[0])
    except Incompleto as exc:
        return errore(str(exc), 1)
    except lc.Problema as exc:
        return errore(str(exc), 2)
    except Exception as exc:  # mai un traceback: un errore inatteso esce 2
        return errore("errore inatteso (%s: %s)"
                      % (type(exc).__name__, " ".join(str(exc).split())), 2)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
