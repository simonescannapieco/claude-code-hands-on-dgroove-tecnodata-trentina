"""controlla_giro.py -- un giro del ciclo degli strumenti di Claude Code,
richiesta per richiesta, e un'affermazione di Anthropic alla prova
(M4-D03).

Legge, nello spazio di lavoro (la cartella data, o quella corrente),
esecuzioni/giro-<n>/stream.jsonl: lo stream-json di `claude -p
--output-format stream-json --verbose` di una sessione partita nella copia
esecuzioni/giro-<n>/urgenze/ del progetto delle urgenze. Ogni riga dello
stream è un evento JSON; l'ultima è il risultato. Per ogni esecuzione
stampa:
  - dall'evento di avvio, la versione di Claude Code, il modello e la
    modalità di permesso;
  - le richieste al modello, in ordine: i messaggi dell'assistente della
    conversazione principale (parent_tool_use_id nullo), uno per id: più
    eventi con lo stesso id sono la stessa richiesta, con lo stesso usage,
    e un evento senza id è una richiesta a sé. Di ognuna i token in
    entrata (input_tokens + cache_read_input_tokens +
    cache_creation_input_tokens), la differenza dalla precedente e gli
    strumenti che chiama: il file, relativo alla cartella della sessione,
    o il comando di Bash; «errore» se il risultato è un errore, «negato»
    se il permesso è stato negato. I messaggi senza usage e quelli dei
    subagent restano fuori dal conto, e si contano;
  - i conteggi: richieste, chiamate a strumenti, permessi negati, durata;
  - i test, rieseguiti ora nella copia (python3 -m unittest), come dato:
    verdi, rossi, nessun test, oppure un tempo scaduto.
Poi l'affermazione su ogni esecuzione, «Ogni richiesta rimanda tutta la
conversazione»: confermata se i token in entrata non scendono mai da una
richiesta alla successiva. Una discesa subito dopo una compattazione
(l'evento system/compact_boundary) si stampa come tale; ogni altra discesa
è una segnalazione, «non confermata in questa esecuzione», e l'uscita è 1:
è una garanzia del prodotto, e deve valere a ogni esecuzione. Con una sola
richiesta non c'è niente da confrontare: non distinguibile. Mai
«smentita». Il controllo non scrive niente. Divide lo stream in righe
soltanto a ogni a capo (\\n): un testo può contenere altri separatori di
riga di Unicode, che JSON lascia così come sono.

Uso:    python3 controlla_giro.py [<spazio di lavoro>]
Env:    PN_URGENZE_TIMEOUT  i secondi concessi ai test (default 60)
Uscita: 0 le esecuzioni ci sono, si leggono, e la garanzia tiene in tutte
        1 manca esecuzioni/, o non ha esecuzioni giro-<n>; un'esecuzione
          che manca o non va (lo stream, la copia); oppure una segnalazione
        2 uso sbagliato; lo spazio di lavoro assente; un file che non si
          legge; un errore inatteso (una riga, mai un traceback)
"""
from __future__ import annotations

import json
import os
import re
import subprocess
import sys
import tempfile
from typing import Dict, List, NamedTuple, Optional, Set, Tuple

CARTELLA = "esecuzioni"
NOME = re.compile(r"^giro-([1-9][0-9]*)$")
STREAM = "stream.jsonl"
COPIA = "urgenze"
TIMEOUT = 60
LUNGHEZZA_COMANDO = 60
S_GIRO = "Ogni richiesta rimanda tutta la conversazione"
CONFERMATA = "confermata"
NON_CONFERMATA = "non confermata in questa esecuzione"
NON_DISTINGUIBILE = "non distinguibile"
PARTENZA = ("Manca la cartella esecuzioni/ con le esecuzioni giro-<n>: "
            "eseguite i passi del README.")
# Il controllo vuole buone tutte le esecuzioni di esecuzioni/: una rovinata
# si toglie prima di rifarla (la sua copia ha oggetti git in sola lettura,
# quindi rm -rf), altrimenti resta e la verifica dice ancora 1.
NON_ANCORA = ("Non ancora: un'esecuzione manca o non è lo stream-json "
              "riuscito di claude -p. Togliete la sua cartella, rm -rf "
              "esecuzioni/giro-<n>, e rifatela come nel README (o "
              "ripartite da capo con tools/reset_esercizio.sh M4-D03); poi "
              "rilanciate il controllo.")
SEGNALAZIONI = ("Segnalazioni: %d. Una garanzia del prodotto deve valere a "
                "ogni esecuzione: i dettagli sono qui sopra.")
USO = "Uso: python3 controlla_giro.py [<spazio di lavoro>]\n"
NA = "—"
RAN = re.compile(r"^Ran (\d+) tests?\b", re.M)
STRUMENTI_FILE = ("file_path", "notebook_path", "path")


class Precondizione(Exception):
    """Un file che non si legge, un valore che non va: uscita 2."""


class Mancante(Exception):
    """Un'esecuzione che manca o non è lo stream-json riuscito di claude -p:
    uscita 1."""


class Strumento(NamedTuple):
    """Una chiamata a uno strumento: il nome, il file o il comando, e
    «errore», «negato» o ""."""
    nome: str
    dettaglio: str
    esito: str


class Richiesta(NamedTuple):
    """Una richiesta al modello: i token in entrata, gli strumenti, e
    quante compattazioni la precedono nello stream."""
    entrata: int
    strumenti: Tuple[Strumento, ...]
    compattazioni: int


class Esecuzione(NamedTuple):
    """Che cosa dice un'esecuzione: l'avvio, le richieste, i messaggi
    fuori dal conto, i permessi negati, la durata, i test rieseguiti."""
    nome: str
    avvio: str
    richieste: Tuple[Richiesta, ...]
    senza_usage: int
    subagent: int
    dinieghi: int
    secondi: Optional[int]
    test: str


def quanti(n: int, uno: str, molti: str) -> str:
    """«1 richiesta» oppure «n richieste»."""
    return "%d %s" % (n, uno if n == 1 else molti)


def compatta(testo: str) -> str:
    """Il testo su una riga sola."""
    return " ".join(testo.split())


def taglia(testo: str, quanti_caratteri: int) -> str:
    """Il testo, al massimo quanti_caratteri, con «…» se è tagliato."""
    if len(testo) <= quanti_caratteri:
        return testo
    return testo[:quanti_caratteri - 1] + "…"


def eventi_di(percorso: str) -> List[dict]:
    """Gli eventi dello stream, se l'ultimo è il risultato riuscito.
    Mancante se manca o non va; Precondizione se non si legge."""
    if not os.path.lexists(percorso):
        raise Mancante("manca %s: rifate quell'esecuzione" % percorso)
    try:
        with open(percorso, "rb") as fh:
            testo = fh.read().decode("utf-8", errors="replace")
    except OSError as exc:
        raise Precondizione("%s non si legge (%s)"
                            % (percorso, exc.strerror or exc))
    eventi: List[dict] = []
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
    ultimo = eventi[-1]
    if ultimo.get("type") != "result":
        raise Mancante("%s: lo stream non finisce con il risultato (la "
                       "chiamata si è interrotta?); rifatela" % percorso)
    if len(eventi) == 1:
        raise Mancante("%s: c'è soltanto il risultato, senza gli eventi "
                       "che lo precedono (è l'uscita di --output-format "
                       "json?); rifate la chiamata con --output-format "
                       "stream-json --verbose" % percorso)
    if ultimo.get("is_error") or ultimo.get("subtype", "success") \
            != "success":
        raise Mancante("%s: claude ha restituito un errore; rifate "
                       "quell'esecuzione" % percorso)
    return eventi


def entrata_di(usage: object) -> Optional[int]:
    """I token in entrata di un usage: input, letti dalla cache e scritti
    nella cache; None se l'usage manca o non ha token in entrata."""
    if not isinstance(usage, dict):
        return None
    totale = 0
    for chiave in ("input_tokens", "cache_read_input_tokens",
                   "cache_creation_input_tokens"):
        valore = usage.get(chiave, 0)
        if isinstance(valore, bool) or not isinstance(valore, int):
            return None
        totale += valore
    return totale if totale > 0 else None


def contenuto(evento: dict) -> List[dict]:
    """I blocchi del messaggio di un evento (una lista vuota se non ce
    ne sono)."""
    messaggio = evento.get("message")
    if not isinstance(messaggio, dict):
        return []
    blocchi = messaggio.get("content")
    if not isinstance(blocchi, list):
        return []
    return [b for b in blocchi if isinstance(b, dict)]


def esiti_degli_strumenti(eventi: List[dict]) -> Tuple[Set[str], Set[str]]:
    """(gli id con un risultato d'errore, gli id con il permesso negato)."""
    errori: Set[str] = set()
    negati: Set[str] = set()
    for evento in eventi:
        if evento.get("type") == "user":
            for blocco in contenuto(evento):
                if blocco.get("type") == "tool_result" \
                        and blocco.get("is_error"):
                    errori.add(str(blocco.get("tool_use_id")))
        elif evento.get("type") == "system" \
                and evento.get("subtype") == "permission_denied":
            negati.add(str(evento.get("tool_use_id")))
    for diniego in eventi[-1].get("permission_denials") or []:
        if isinstance(diniego, dict):
            negati.add(str(diniego.get("tool_use_id")))
    return errori, negati


def dettaglio(nome: str, ingresso: object, cwd: str) -> str:
    """Il file (relativo alla cartella della sessione; altrimenti il solo
    nome) o il comando di una chiamata."""
    if not isinstance(ingresso, dict):
        return ""
    if nome == "Bash" and isinstance(ingresso.get("command"), str):
        return "«%s»" % taglia(compatta(ingresso["command"]),
                               LUNGHEZZA_COMANDO)
    for chiave in STRUMENTI_FILE:
        percorso = ingresso.get(chiave)
        if isinstance(percorso, str) and percorso:
            if cwd and percorso.startswith(cwd.rstrip("/") + "/"):
                return os.path.relpath(percorso, cwd)
            return os.path.basename(percorso.rstrip("/")) or percorso
    return ""


class Raccolta:
    """Le richieste di uno stream mentre lo si legge, una per chiave (l'id
    del messaggio, o la posizione dell'evento se l'id manca)."""

    def __init__(self) -> None:
        self.ordine: List[str] = []
        self.entrata: Dict[str, Optional[int]] = {}
        self.compattazioni: Dict[str, int] = {}
        self.strumenti: Dict[str, List[dict]] = {}
        self.visti: Set[str] = set()

    def aggiungi(self, chiave: str, evento: dict, compattazioni: int) -> None:
        """Un evento dell'assistente della conversazione principale."""
        if chiave not in self.entrata:
            self.ordine.append(chiave)
            self.entrata[chiave] = None
            self.compattazioni[chiave] = compattazioni
            self.strumenti[chiave] = []
        if self.entrata[chiave] is None:
            self.entrata[chiave] = entrata_di(evento["message"].get("usage"))
        for blocco in contenuto(evento):
            if blocco.get("type") != "tool_use":
                continue
            ident = blocco.get("id")
            if isinstance(ident, str) and ident:
                if ident in self.visti:
                    continue
                self.visti.add(ident)
            self.strumenti[chiave].append(blocco)


def leggi_richieste(eventi: List[dict],
                    cwd: str) -> Tuple[List[Richiesta], int, int]:
    """(le richieste, i messaggi senza usage, i messaggi dei subagent)."""
    errori, negati = esiti_degli_strumenti(eventi)
    raccolta = Raccolta()
    subagent: Set[str] = set()
    compattazioni = 0
    for posizione, evento in enumerate(eventi):
        if evento.get("type") == "system" \
                and evento.get("subtype") == "compact_boundary":
            compattazioni += 1
            continue
        if evento.get("type") != "assistant" \
                or not isinstance(evento.get("message"), dict):
            continue
        ident = evento["message"].get("id")
        chiave = ident if isinstance(ident, str) and ident \
            else "#%d" % posizione
        if evento.get("parent_tool_use_id"):
            subagent.add(chiave)
            continue
        raccolta.aggiungi(chiave, evento, compattazioni)
    richieste: List[Richiesta] = []
    senza_usage = 0
    for chiave in raccolta.ordine:
        valore = raccolta.entrata[chiave]
        if valore is None:
            senza_usage += 1
            continue
        strumenti = []
        for blocco in raccolta.strumenti[chiave]:
            nome = blocco.get("name")
            nome = nome if isinstance(nome, str) and nome else "?"
            ident = str(blocco.get("id"))
            esito = "negato" if ident in negati else (
                "errore" if ident in errori else "")
            strumenti.append(Strumento(nome, dettaglio(
                nome, blocco.get("input"), cwd), esito))
        richieste.append(Richiesta(valore, tuple(strumenti),
                                   raccolta.compattazioni[chiave]))
    return richieste, senza_usage, len(subagent)


def secondi_dei_test() -> int:
    """I secondi concessi ai test: PN_URGENZE_TIMEOUT, oppure 60."""
    valore = os.environ.get("PN_URGENZE_TIMEOUT", "")
    if not valore:
        return TIMEOUT
    if not valore.isdigit() or int(valore) <= 0:
        raise Precondizione("PN_URGENZE_TIMEOUT non è un numero di secondi: "
                            "%s" % valore)
    return int(valore)


def riesegui_test(copia: str) -> str:
    """I test della copia, rieseguiti ora, in parole: verdi, rossi,
    nessun test, un tempo scaduto, oppure non partono."""
    secondi = secondi_dei_test()
    with tempfile.TemporaryDirectory(prefix="pycache-") as cache:
        try:
            fatto = subprocess.run(
                [sys.executable, "-B", "-I", "-X",
                 "pycache_prefix=" + cache, "-m", "unittest", "-q"],
                cwd=copia, stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT, universal_newlines=True,
                errors="replace", timeout=secondi)
        except subprocess.TimeoutExpired:
            return "non finiscono entro %d s" % secondi
        except OSError as exc:
            return "non partono (%s)" % (exc.strerror or exc)
    righe = [r.strip() for r in fatto.stdout.splitlines() if r.strip()]
    ultima = righe[-1] if righe else NA
    trovati = RAN.search(fatto.stdout)
    if trovati is None:
        return "non partono (%s)" % taglia(ultima, 80)
    numero = int(trovati.group(1))
    if numero == 0:
        return "nessun test (Ran 0 tests)"
    colore = "verdi" if fatto.returncode == 0 else "rossi"
    return "%s (%d test, %s)" % (colore, numero, taglia(ultima, 80))


def leggi_esecuzione(nome: str) -> Esecuzione:
    """Un'esecuzione dello spazio di lavoro (la cartella corrente)."""
    base = "%s/%s" % (CARTELLA, nome)
    eventi = eventi_di("%s/%s" % (base, STREAM))
    avvio = next((e for e in eventi if e.get("type") == "system"
                  and e.get("subtype") == "init"), {})
    cwd = avvio.get("cwd") if isinstance(avvio.get("cwd"), str) else ""
    richieste, senza_usage, subagent = leggi_richieste(eventi, cwd)
    if not richieste:
        raise Mancante("%s/%s: nessuna richiesta al modello nello stream; "
                       "rifate quell'esecuzione" % (base, STREAM))
    copia = "%s/%s" % (base, COPIA)
    if not os.path.isdir(copia):
        raise Mancante("manca la copia %s/: rifate quell'esecuzione"
                       % copia)
    risultato = eventi[-1]
    dinieghi = risultato.get("permission_denials")
    durata = risultato.get("duration_ms")
    secondi = (int(round(durata / 1000))
               if isinstance(durata, (int, float))
               and not isinstance(durata, bool) else None)
    testa = "Claude Code %s, modello %s, modalità %s" % tuple(
        str(avvio.get(k)) if avvio.get(k) else NA
        for k in ("claude_code_version", "model", "permissionMode"))
    return Esecuzione(nome, testa, tuple(richieste), senza_usage, subagent,
                      len(dinieghi) if isinstance(dinieghi, list) else 0,
                      secondi, riesegui_test(copia))


def riga_richiesta(numero: int, richiesta: Richiesta,
                   precedente: Optional[Richiesta]) -> str:
    """La riga della tabella di una richiesta."""
    differenza = ""
    if precedente is not None:
        differenza = " (%+d" % (richiesta.entrata - precedente.entrata)
        if richiesta.compattazioni > precedente.compattazioni:
            differenza += ", dopo la compattazione"
        differenza += ")"
    strumenti = "; ".join(
        " ".join(p for p in (s.nome, s.dettaglio,
                             "(%s)" % s.esito if s.esito else "") if p)
        for s in richiesta.strumenti) or "nessuno strumento"
    return "  richiesta %d: in entrata %d token%s; %s" % (
        numero, richiesta.entrata, differenza, strumenti)


def verdetto(esecuzione: Esecuzione) -> Tuple[str, bool]:
    """(la riga dell'affermazione, vero se è una segnalazione)."""
    richieste = esecuzione.richieste
    if len(richieste) < 2:
        return ("%s (%s): %s: una sola richiesta, niente da confrontare"
                % (S_GIRO, esecuzione.nome, NON_DISTINGUIBILE), False)
    compattate = 0
    for k in range(1, len(richieste)):
        prima, dopo = richieste[k - 1], richieste[k]
        if dopo.entrata >= prima.entrata:
            continue
        if dopo.compattazioni > prima.compattazioni:
            compattate += 1
            continue
        return ("%s (%s): %s: l'entrata scende dalla richiesta %d alla %d, "
                "da %d a %d token; una segnalazione"
                % (S_GIRO, esecuzione.nome, NON_CONFERMATA, k, k + 1,
                   prima.entrata, dopo.entrata), True)
    tranne = ""
    if compattate:
        tranne = ", tranne dopo una compattazione (%d)" % compattate
    return ("%s (%s): %s: l'entrata non scende mai%s, da %d a %d token in "
            "%s" % (S_GIRO, esecuzione.nome, CONFERMATA, tranne,
                    richieste[0].entrata, richieste[-1].entrata,
                    quanti(len(richieste), "richiesta", "richieste")),
            False)


def stampa(esecuzione: Esecuzione) -> bool:
    """I dati di un'esecuzione e il suo verdetto; vero se è una
    segnalazione."""
    nome = esecuzione.nome
    chiamate = sum(len(r.strumenti) for r in esecuzione.richieste)
    conti = [quanti(len(esecuzione.richieste), "richiesta", "richieste")
             + " al modello",
             quanti(chiamate, "chiamata", "chiamate") + " a strumenti",
             quanti(esecuzione.dinieghi, "permesso negato",
                    "permessi negati")]
    if esecuzione.secondi is not None:
        conti.append("%d s" % esecuzione.secondi)
    print("%s: %s" % (nome, esecuzione.avvio))
    print("%s: %s" % (nome, ", ".join(conti)))
    if esecuzione.subagent:
        print("%s: %s di subagent (parent_tool_use_id), fuori dal conto"
              % (nome, quanti(esecuzione.subagent, "messaggio", "messaggi")))
    if esecuzione.senza_usage:
        print("%s: %s dell'assistente senza usage, fuori dal conto"
              % (nome, quanti(esecuzione.senza_usage, "messaggio",
                              "messaggi")))
    precedente = None
    for numero, richiesta in enumerate(esecuzione.richieste, 1):
        print(riga_richiesta(numero, richiesta, precedente))
        precedente = richiesta
    print("%s: i test, rieseguiti ora nella copia: %s"
          % (nome, esecuzione.test))
    riga, segnalazione = verdetto(esecuzione)
    print(riga)
    return segnalazione


def avviso(messaggio: str) -> None:
    """Un'esecuzione da rifare, o un errore, su STDERR."""
    sys.stderr.write("controlla_giro.py: %s\n" % messaggio)


def nomi_delle_esecuzioni() -> List[str]:
    """Le cartelle giro-<n> di esecuzioni/, in ordine di numero."""
    if not os.path.isdir(CARTELLA):
        return []
    try:
        voci = os.listdir(CARTELLA)
    except OSError as exc:
        raise Precondizione("%s/ non si legge (%s)"
                            % (CARTELLA, exc.strerror or exc))
    trovate = [(int(m.group(1)), v) for v in voci
               for m in [NOME.match(v)] if m]
    return [v for _, v in sorted(trovate)]


def controlla() -> int:
    """Il controllo nella cartella corrente, lo spazio di lavoro: stampa
    e restituisce l'uscita 0 o 1. Precondizione per l'uscita 2."""
    nomi = nomi_delle_esecuzioni()
    if not nomi:
        print(PARTENZA)
        return 1
    mancanti = segnalazioni = 0
    for nome in nomi:
        try:
            esecuzione = leggi_esecuzione(nome)
        except Mancante as exc:
            avviso(str(exc))
            mancanti += 1
            continue
        if stampa(esecuzione):
            segnalazioni += 1
    if mancanti:
        print(NON_ANCORA)
    if segnalazioni:
        print(SEGNALAZIONI % segnalazioni)
    return 1 if mancanti or segnalazioni else 0


def errore(messaggio: str) -> int:
    """Il messaggio su STDERR, in una riga; l'uscita 2."""
    avviso(messaggio)
    return 2


def uso(messaggio: str) -> int:
    """Un argomento sbagliato: il motivo e l'uso; l'uscita 2."""
    errore(messaggio)
    sys.stderr.write(USO)
    return 2


def main(argv: List[str]) -> int:
    for flusso in (sys.stdout, sys.stderr):
        riconfigura = getattr(flusso, "reconfigure", None)
        if riconfigura is not None:
            riconfigura(errors="replace")
    posizionali: List[str] = []
    for arg in argv:
        if arg.startswith("-"):
            return uso("opzione sconosciuta: %s" % arg)
        posizionali.append(arg)
    if len(posizionali) > 1:
        return uso("uno spazio di lavoro per volta")
    ws = posizionali[0] if posizionali else "."
    if not os.path.isdir(ws):
        return errore("spazio di lavoro assente: %s" % ws)
    try:
        os.chdir(ws)
    except OSError as exc:
        return errore("lo spazio di lavoro %s non si apre (%s)"
                      % (ws, exc.strerror or exc))
    try:
        return controlla()
    except Precondizione as exc:
        return errore(str(exc))
    except Exception as exc:  # mai un traceback: un errore inatteso esce 2
        return errore("errore inatteso (%s: %s)"
                      % (type(exc).__name__, " ".join(str(exc).split())))


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
