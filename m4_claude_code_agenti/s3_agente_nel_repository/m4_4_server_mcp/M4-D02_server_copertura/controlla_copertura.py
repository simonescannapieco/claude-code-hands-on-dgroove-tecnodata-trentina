"""controlla_copertura.py -- un server MCP per la copertura (M4-D02).

Sta nella cartella dell'elemento, fuori dallo spazio di lavoro: calcola la
verità dai dati del gestionale (la cartella database/ di
progetti/gestionale-php, caricata in un database SQLite in memoria), cioè
i comuni con almeno un indirizzo coperto dalla fibra FTTH, con una data di
disponibilità. Nello spazio di lavoro non ci sono né i dati né la verità.

Legge, nello spazio di lavoro (la cartella data, o quella corrente), ciò
che trova:

- risposte/<braccio>-<n>.jsonl, braccio con o senza, n = 1, 2, 3: lo
  stream-json delle sei esecuzioni della prova del docente, la stessa
  domanda con --strict-mcp-config e una configurazione --mcp-config che
  dichiara il server copertura (con) o nessun server (senza). Per ogni
  esecuzione stampa, come dati, i server MCP dell'evento system/init con il
  loro stato, gli strumenti chiamati e i comuni della risposta contro la
  verità; poi i verdetti su due garanzie di Anthropic:
    «Con --strict-mcp-config, solo i server di --mcp-config»: con il
      server la sessione ha esattamente il server copertura; senza, nessun
      server MCP, nessuno strumento mcp__ nell'elenco, nessuna chiamata
      mcp__;
    «Gli strumenti MCP si chiamano mcp__<server>__<tool>»: con il server,
      mcp__copertura__cerca_copertura c'è nell'elenco degli strumenti, e
      ogni strumento o chiamata che porta il nome cerca_copertura si
      chiama proprio così.
  Confermata o non confermata in questa esecuzione: sono garanzie, e una
  non confermata fa uscire con 1. Se il server, con, non risulta
  collegato, la prova non è andata come quella registrata (uscita 1) e il
  nome non si decide. Come dati, «n su 3»: lo strumento del server
  chiamato, e le risposte con esattamente i comuni giusti, per braccio.
- risposta.txt: la risposta della vostra prova, l'elenco dei comuni. È
  fatta se nomina esattamente i comuni della verità: dice quanti sono
  giusti e quanti mancano (non quali), e nomina quelli in più.

Mai «smentita». Nessun file: né risposta.txt né risposte/ è il punto di
partenza (uscita 1). Divide lo stream in righe soltanto a ogni a capo
(\\n): un testo può contenere altri separatori di riga di Unicode (U+2028,
U+0085), che JSON lascia così come sono.

Uso:    python3 controlla_copertura.py [--dati <cartella>] [<spazio>]
          --dati  la cartella database/ del gestionale (default: quella
                  del repository, accanto a questo elemento)
Uscita: 0 ciò che c'è va: le garanzie confermate, risposta.txt giusto
        1 il punto di partenza; uno stream che manca o non è lo
          stream-json riuscito di claude -p; il server non collegato; una
          garanzia non confermata in questa esecuzione; risposta.txt con
          comuni che mancano o in più
        2 uso sbagliato; lo spazio di lavoro assente; i dati del gestionale
          che non si leggono; un file che non si legge; un errore
          inatteso (una riga, mai un traceback)
"""
from __future__ import annotations

import json
import os
import re
import sqlite3
import sys
import unicodedata
from typing import Dict, List, NamedTuple, Optional, Sequence, Set, Tuple

BRACCI = ("con", "senza")
ESECUZIONI = (1, 2, 3)
CARTELLA = "risposte"
RISPOSTA = "risposta.txt"
SERVER = "copertura"
STRUMENTO = "mcp__copertura__cerca_copertura"
NOME_STRUMENTO = "cerca_copertura"
COLLEGATO = "connected"
FILE_DATI = ("schema.sql", "dati/01_comuni.sql", "dati/02_rete.sql")
SQL_FTTH = """
SELECT DISTINCT c.nome FROM copertura AS k JOIN comuni AS c
  ON c.id = k.comune_id
WHERE k.tecnologia = 'FTTH' AND k.disponibile_dal IS NOT NULL
ORDER BY c.nome
"""
SQL_COMUNI = "SELECT nome FROM comuni ORDER BY nome"
S249 = "Con --strict-mcp-config, solo i server di --mcp-config"
S250 = "Gli strumenti MCP si chiamano mcp__<server>__<tool>"
CONFERMATA = "confermata"
NON_CONFERMATA = "non confermata in questa esecuzione"
GARANZIA = ("La documentazione garantisce che con --strict-mcp-config Claude "
            "Code usa solo i server di --mcp-config, e che gli strumenti MCP "
            "si chiamano mcp__<server>__<tool>: in questa esecuzione no, "
            "nei verdetti qui sopra.")
PARTENZA = "Né risposta.txt né risposte/: eseguite i passi del README."
NON_ANCORA = ("Non ancora: un'esecuzione manca o il suo file non è lo "
              "stream-json riuscito di claude -p; rifatela, poi rilanciate "
              "il controllo.")
NON_GIUSTA = ("Non ancora: risposta.txt deve nominare esattamente i comuni "
              "con indirizzi coperti dalla fibra FTTH; rifate la domanda "
              "nella sessione con il server, poi rilanciate la verifica.")
GIUSTA = ("i comuni con indirizzi coperti dalla fibra FTTH, né uno di più "
          "né uno di meno.")
USO = ("Uso: python3 controlla_copertura.py [--dati <cartella>] "
       "[<spazio di lavoro>]\n")
INIZIO = 200
ACCENTI = {"è": "e", "é": "e", "à": "a", "ì": "i", "ò": "o", "ù": "u"}


class Precondizione(Exception):
    """Dati o file che non si leggono: uscita 2."""


class Mancante(Exception):
    """Un'esecuzione che manca o non è lo stream-json riuscito di
    claude -p: uscita 1."""


class Esecuzione(NamedTuple):
    """Che cosa dice lo stream di un'esecuzione."""
    server: Tuple[Tuple[str, str], ...]
    strumenti: Tuple[str, ...]
    chiamate: Dict[str, int]
    risposta: str


class Confronto(NamedTuple):
    """I comuni di una risposta contro la verità."""
    nominati: int
    giusti: int
    mancanti: int
    in_piu: Tuple[str, ...]


def compatta(testo: str) -> str:
    """Il testo su una riga sola, al massimo INIZIO caratteri."""
    riga = " ".join(testo.split())
    return riga if len(riga) <= INIZIO else riga[:INIZIO - 1] + "…"


def avviso(messaggio: str) -> None:
    """Un'esecuzione da rifare, o un errore, su STDERR."""
    sys.stderr.write("controlla_copertura.py: %s\n" % messaggio)


# --- La verità ------------------------------------------------------------

def verita(cartella: str) -> Tuple[Tuple[str, ...], Tuple[str, ...]]:
    """(i comuni con indirizzi coperti in FTTH, tutti i comuni), dai file
    del gestionale caricati in SQLite in memoria; Precondizione se non si
    leggono."""
    connessione = sqlite3.connect(":memory:")
    try:
        for nome in FILE_DATI:
            with open(os.path.join(cartella, nome), encoding="utf-8") as fh:
                connessione.executescript(fh.read())
        ftth = tuple(r[0] for r in connessione.execute(SQL_FTTH))
        tutti = tuple(r[0] for r in connessione.execute(SQL_COMUNI))
    except (OSError, sqlite3.Error, UnicodeDecodeError) as exc:
        raise Precondizione("i dati del gestionale non si leggono in %s "
                            "(%s)" % (cartella, exc))
    finally:
        connessione.close()
    if not ftth or not tutti:
        raise Precondizione("i dati del gestionale in %s non hanno comuni "
                            "con la fibra" % cartella)
    return ftth, tutti


# --- I comuni di una risposta ---------------------------------------------

def norma(testo: str) -> str:
    """Il testo in minuscolo, con gli apostrofi tipografici dritti."""
    testo = unicodedata.normalize("NFC", testo).casefold()
    return testo.replace("’", "'").replace("`", "'")


def senza_accenti(testo: str) -> str:
    """Il testo senza segni diacritici."""
    scomposto = unicodedata.normalize("NFD", testo)
    return "".join(c for c in scomposto if not unicodedata.combining(c))


def forme(nome: str) -> Set[str]:
    """Le forme in cui un comune conta: com'è; con l'accento finale scritto
    con l'altro accento o con l'apostrofo; per i nomi di più parole anche
    senza accenti. Un nome di una parola senza accento non conta: «male»
    non è Malé."""
    base = norma(nome)
    risultato = {base}
    vocale = ACCENTI.get(base[-1:])
    if vocale:
        radice = base[:-1]
        risultato.add(radice + vocale + "'")
        if vocale == "e":
            risultato |= {radice + "è", radice + "é"}
    if " " in base:
        risultato.add(senza_accenti(base))
    return risultato


def nominati(testo: str, comuni: Sequence[str]) -> Set[str]:
    """I comuni nominati nel testo, ciascuno come parola intera; prima le
    forme più lunghe, e un nome dentro un altro già trovato non conta
    («Trento» in «Tione di Trento»)."""
    pulito = norma(testo)
    cercate = sorted(((f, nome) for nome in comuni for f in forme(nome)),
                     key=lambda coppia: -len(coppia[0]))
    occupati: List[Tuple[int, int]] = []
    trovati: Set[str] = set()
    for forma, nome in cercate:
        regola = re.compile(r"(?<!\w)" + re.escape(forma) + r"(?!\w)")
        for trovato in regola.finditer(pulito):
            inizio, fine = trovato.span()
            if any(inizio < f and a < fine for a, f in occupati):
                continue
            occupati.append((inizio, fine))
            trovati.add(nome)
    return trovati


def confronta(testo: str, giusti: Sequence[str],
              comuni: Sequence[str]) -> Confronto:
    """I comuni del testo contro quelli giusti."""
    trovati = nominati(testo, comuni)
    attesi = set(giusti)
    return Confronto(len(trovati), len(trovati & attesi),
                     len(attesi - trovati),
                     tuple(sorted(trovati - attesi)))


def descrivi(confronto: Confronto, totale: int) -> str:
    """Il confronto in parole: mai i comuni che mancano, che sono la
    risposta."""
    in_piu = ("in più: " + ", ".join(confronto.in_piu)
              if confronto.in_piu else "in più nessuno")
    return "%d comuni nominati, giusti %d su %d, mancano %d, %s" % (
        confronto.nominati, confronto.giusti, totale, confronto.mancanti,
        in_piu)


def esatta(confronto: Confronto) -> bool:
    """Vero se la risposta nomina esattamente i comuni giusti."""
    return confronto.mancanti == 0 and not confronto.in_piu


# --- Gli stream della prova del docente -----------------------------------

def eventi_di(percorso: str) -> List[dict]:
    """Gli eventi dello stream di un file, se c'è l'init e l'ultimo è il
    risultato riuscito. Mancante se manca o non va; Precondizione se non si
    legge."""
    if not os.path.lexists(percorso):
        raise Mancante("manca %s: rifate quell'esecuzione" % percorso)
    try:
        with open(percorso, "rb") as fh:
            testo = fh.read().decode("utf-8", errors="replace")
    except OSError as exc:
        raise Precondizione("%s non si legge (%s)"
                            % (percorso, exc.strerror or exc))
    eventi: List[dict] = []
    # Soltanto a ogni \n: splitlines() spezzerebbe anche a U+2028 o U+0085
    # dentro un testo, e una riga buona diventerebbe due righe rotte.
    for numero, riga in enumerate(testo.split("\n"), 1):
        if not riga.strip():
            continue
        try:
            evento = json.loads(riga)
        except (ValueError, RecursionError):
            evento = None
        if not isinstance(evento, dict):
            raise Mancante("%s, riga %d: non è un evento dello stream-json "
                           "di claude -p; rifate quell'esecuzione"
                           % (percorso, numero))
        eventi.append(evento)
    if not eventi:
        raise Mancante("%s è vuoto: la chiamata a claude è fallita? "
                       "Rifatela" % percorso)
    if eventi[-1].get("type") != "result":
        raise Mancante("%s: lo stream non finisce con il risultato (la "
                       "chiamata si è interrotta?); rifatela" % percorso)
    if len(eventi) == 1:
        raise Mancante("%s: c'è soltanto il risultato, senza gli eventi "
                       "(è l'uscita di --output-format json?); rifatela con "
                       "--output-format stream-json --verbose" % percorso)
    ultimo = eventi[-1]
    if ultimo.get("is_error") or ultimo.get("subtype", "success") \
            != "success" or not isinstance(ultimo.get("result"), str):
        raise Mancante("%s: claude ha restituito un errore, o nessuna "
                       "risposta; rifate quell'esecuzione" % percorso)
    if not any(e.get("type") == "system" and e.get("subtype") == "init"
               for e in eventi):
        raise Mancante("%s: manca l'evento iniziale (system/init) con i "
                       "server MCP; rifate quell'esecuzione" % percorso)
    return eventi


def chiamate_di(eventi: List[dict]) -> Dict[str, int]:
    """Quante volte è stato chiamato ogni strumento: i blocchi tool_use dei
    messaggi dell'assistente, una volta per id."""
    visti: Set[str] = set()
    conti: Dict[str, int] = {}
    for evento in eventi:
        messaggio = evento.get("message")
        if evento.get("type") != "assistant" or not isinstance(messaggio,
                                                               dict):
            continue
        contenuto = messaggio.get("content")
        for blocco in contenuto if isinstance(contenuto, list) else []:
            if not isinstance(blocco, dict) or blocco.get("type") \
                    != "tool_use":
                continue
            ident = blocco.get("id")
            if isinstance(ident, str) and ident:
                if ident in visti:
                    continue
                visti.add(ident)
            nome = blocco.get("name")
            nome = nome if isinstance(nome, str) and nome else "?"
            conti[nome] = conti.get(nome, 0) + 1
    return conti


def leggi_esecuzione(percorso: str) -> Esecuzione:
    """Che cosa dice lo stream di un'esecuzione."""
    eventi = eventi_di(percorso)
    init = next(e for e in eventi if e.get("type") == "system"
                and e.get("subtype") == "init")
    server: List[Tuple[str, str]] = []
    voci = init.get("mcp_servers")
    for voce in voci if isinstance(voci, list) else []:
        if isinstance(voce, dict):
            server.append((str(voce.get("name", "?")),
                           str(voce.get("status", "?"))))
    strumenti = init.get("tools")
    strumenti = tuple(s for s in strumenti if isinstance(s, str)) \
        if isinstance(strumenti, list) else ()
    return Esecuzione(tuple(server), strumenti, chiamate_di(eventi),
                      eventi[-1]["result"])


def solo_server(braccio: str, esecuzione: Esecuzione) -> bool:
    """La prima garanzia: con, esattamente il server copertura; senza,
    nessun server, nessuno strumento né chiamata mcp__."""
    nomi = [nome for nome, _ in esecuzione.server]
    if braccio == "con":
        return nomi == [SERVER]
    mcp = [s for s in esecuzione.strumenti if s.startswith("mcp__")]
    chiamati = [s for s in esecuzione.chiamate if s.startswith("mcp__")]
    return not nomi and not mcp and not chiamati


def nome_giusto(esecuzione: Esecuzione) -> bool:
    """La seconda garanzia: lo strumento del server c'è con il suo nome
    mcp__<server>__<tool>, e ogni nome che porta cerca_copertura è
    quello."""
    nomi = set(esecuzione.strumenti) | set(esecuzione.chiamate)
    return STRUMENTO in esecuzione.strumenti and all(
        nome == STRUMENTO for nome in nomi if NOME_STRUMENTO in nome)


def collegato(esecuzione: Esecuzione) -> bool:
    """Vero se il server copertura è nello stato «connected»."""
    return (SERVER, COLLEGATO) in esecuzione.server


def dati(braccio: str, n: int, esecuzione: Esecuzione, confronto: Confronto,
         totale: int) -> List[str]:
    """Le righe dei dati di un'esecuzione."""
    server = ", ".join("%s (%s)" % voce for voce in esecuzione.server)
    chiamate = ", ".join("%s %d" % voce for voce
                         in sorted(esecuzione.chiamate.items()))
    return ["%s, %d: server %s; strumenti chiamati: %s"
            % (braccio, n, server or "nessuno", chiamate or "nessuno"),
            "  risposta: %s" % descrivi(confronto, totale),
            "  testo: «%s»" % compatta(esecuzione.risposta)]


def verdetto(esito: bool) -> str:
    """confermata, oppure non confermata in questa esecuzione."""
    return CONFERMATA if esito else NON_CONFERMATA


def esamina(esecuzioni: Dict[Tuple[str, int], Esecuzione],
            giusti: Sequence[str], comuni: Sequence[str]) -> int:
    """I dati, i verdetti e i riepiloghi delle esecuzioni che ci sono;
    l'uscita 0 o 1."""
    esatte = {braccio: 0 for braccio in BRACCI}
    contate = {braccio: 0 for braccio in BRACCI}
    chiamato = 0
    for n in ESECUZIONI:
        for braccio in BRACCI:
            esecuzione = esecuzioni.get((braccio, n))
            if esecuzione is None:
                continue
            confronto = confronta(esecuzione.risposta, giusti, comuni)
            contate[braccio] += 1
            esatte[braccio] += esatta(confronto)
            if braccio == "con" and esecuzione.chiamate.get(STRUMENTO):
                chiamato += 1
            for riga in dati(braccio, n, esecuzione, confronto, len(giusti)):
                print(riga)
    return verdetti(esecuzioni) | riepilogo(esatte, contate, chiamato)


def verdetti(esecuzioni: Dict[Tuple[str, int], Esecuzione]) -> int:
    """I verdetti delle due garanzie; 1 se una non è confermata o se il
    server non si è collegato (allora il nome non si decide)."""
    non_confermate = 0
    scollegato = 0
    for n in ESECUZIONI:
        for braccio in BRACCI:
            esecuzione = esecuzioni.get((braccio, n))
            if esecuzione is None:
                continue
            primo = solo_server(braccio, esecuzione)
            print("«%s» (%s, %d): %s" % (S249, braccio, n, verdetto(primo)))
            non_confermate += 0 if primo else 1
            if braccio != "con":
                continue
            if not collegato(esecuzione):
                stato = ", ".join("%s (%s)" % voce
                                  for voce in esecuzione.server)
                print("«%s» (con, %d): non distinguibile (il server non si "
                      "è collegato)" % (S250, n))
                avviso("con, %d: il server copertura non si è collegato "
                       "(%s): la prova non è andata come quella "
                       "registrata; controllate uv sync e i percorsi della "
                       "configurazione" % (n, stato or "nessun server"))
                scollegato += 1
                continue
            secondo = nome_giusto(esecuzione)
            print("«%s» (con, %d): %s" % (S250, n, verdetto(secondo)))
            non_confermate += 0 if secondo else 1
    if non_confermate:
        print(GARANZIA)
    return 1 if non_confermate or scollegato else 0


def riepilogo(esatte: Dict[str, int], contate: Dict[str, int],
              chiamato: int) -> int:
    """I riepiloghi, come dati: non decidono l'uscita."""
    if contate["con"]:
        print("Dati: lo strumento del server chiamato: %d su %d"
              % (chiamato, contate["con"]))
    if contate["con"] or contate["senza"]:
        print("Dati: risposte con esattamente i comuni giusti: con il "
              "server %d su %d, senza %d su %d"
              % (esatte["con"], contate["con"], esatte["senza"],
                 contate["senza"]))
    return 0


def prova_docente(giusti: Sequence[str], comuni: Sequence[str]) -> int:
    """La prova del docente in risposte/: l'uscita 0 o 1."""
    esecuzioni: Dict[Tuple[str, int], Esecuzione] = {}
    mancanti = 0
    for n in ESECUZIONI:
        for braccio in BRACCI:
            percorso = "%s/%s-%d.jsonl" % (CARTELLA, braccio, n)
            try:
                esecuzioni[(braccio, n)] = leggi_esecuzione(percorso)
            except Mancante as exc:
                avviso(str(exc))
                mancanti += 1
    esito = esamina(esecuzioni, giusti, comuni)
    if mancanti:
        print(NON_ANCORA)
        return 1
    return esito


def prova_vostra(giusti: Sequence[str], comuni: Sequence[str]) -> int:
    """risposta.txt: l'uscita 0 o 1; Precondizione se non si legge."""
    try:
        with open(RISPOSTA, "rb") as fh:
            testo = fh.read().decode("utf-8", errors="replace")
    except OSError as exc:
        raise Precondizione("%s non si legge (%s)"
                            % (RISPOSTA, exc.strerror or exc))
    confronto = confronta(testo, giusti, comuni)
    print("%s: %s" % (RISPOSTA, descrivi(confronto, len(giusti))))
    if esatta(confronto):
        print("%s: %s" % (RISPOSTA, GIUSTA))
        return 0
    print(NON_GIUSTA)
    return 1


def controlla(dati_gestionale: str) -> int:
    """Il controllo nella cartella corrente, lo spazio di lavoro: stampa e
    restituisce l'uscita 0 o 1. Precondizione per l'uscita 2."""
    docente = os.path.isdir(CARTELLA)
    vostra = os.path.lexists(RISPOSTA)
    if not docente and not vostra:
        print(PARTENZA)
        return 1
    giusti, comuni = verita(dati_gestionale)
    esito = 0
    if docente:
        esito |= prova_docente(giusti, comuni)
    if vostra:
        esito |= prova_vostra(giusti, comuni)
    return esito


def errore(messaggio: str) -> int:
    """Il messaggio su STDERR, in una riga; l'uscita 2."""
    avviso(messaggio)
    return 2


def uso(messaggio: str) -> int:
    """Un argomento sbagliato: il motivo e l'uso; l'uscita 2."""
    errore(messaggio)
    sys.stderr.write(USO)
    return 2


def argomenti(argv: List[str]) -> Tuple[Optional[str], List[str]]:
    """(la cartella di --dati o None, gli argomenti posizionali);
    ValueError con il motivo se non vanno."""
    cartella: Optional[str] = None
    posizionali: List[str] = []
    i = 0
    while i < len(argv):
        arg = argv[i]
        if arg == "--dati":
            if i + 1 >= len(argv) or not argv[i + 1]:
                raise ValueError("--dati vuole una cartella")
            cartella = argv[i + 1]
            i += 2
            continue
        if arg.startswith("-"):
            raise ValueError("opzione sconosciuta: %s" % arg)
        posizionali.append(arg)
        i += 1
    if len(posizionali) > 1:
        raise ValueError("uno spazio di lavoro per volta")
    return cartella, posizionali


def main(argv: List[str]) -> int:
    for flusso in (sys.stdout, sys.stderr):
        riconfigura = getattr(flusso, "reconfigure", None)
        if riconfigura is not None:
            riconfigura(errors="replace")
    try:
        cartella, posizionali = argomenti(argv)
    except ValueError as exc:
        return uso(str(exc))
    elemento = os.path.dirname(os.path.abspath(__file__))
    radice = os.path.dirname(os.path.dirname(os.path.dirname(
        os.path.dirname(elemento))))
    predefinita = os.path.join(radice, "progetti", "gestionale-php",
                               "database")
    dati_gestionale = os.path.abspath(cartella or predefinita)
    ws = posizionali[0] if posizionali else "."
    if not os.path.isdir(ws):
        return errore("spazio di lavoro assente: %s" % ws)
    try:
        os.chdir(ws)
    except OSError as exc:
        return errore("lo spazio di lavoro %s non si apre (%s)"
                      % (ws, exc.strerror or exc))
    try:
        return controlla(dati_gestionale)
    except Precondizione as exc:
        return errore(str(exc))
    except Exception as exc:  # mai un traceback: un errore inatteso esce 2
        return errore("errore inatteso (%s: %s)"
                      % (type(exc).__name__, " ".join(str(exc).split())))


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
