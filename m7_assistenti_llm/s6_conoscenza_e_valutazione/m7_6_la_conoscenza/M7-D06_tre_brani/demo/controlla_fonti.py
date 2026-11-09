"""controlla_fonti.py -- M7-D06 «Tre brani, una risposta con la fonte»: le
esecuzioni di in_classe.sh alla prova.

Legge, nella cartella data (risposte/ dello spazio di lavoro), una cartella per
esecuzione, <braccio>-<n>, con una sottocartella per ogni domanda (i casi di
casi/, accanto a questo file):
  con-permesso-<n>/    il system prompt con la frase che permette di dire
                       «non lo so»;
  senza-permesso-<n>/  lo stesso system prompt, senza quella frase.
Di ogni esecuzione e domanda legge stream.jsonl (l'uscita strutturata: coperta,
codice_procedura, risposta; il server MCP collegato o no; turni, secondi, token)
e registro.jsonl (il registro del server: quali brani ha restituito cerca_kb), e
stampa: che cosa ha cercato Claude e quali brani ha restituito il server; i tre
campi; se il codice è fra i brani restituiti; i numeri della risposta che non
stanno nei brani (un dato, mai un esito: non dicono se la risposta è giusta).

Poi il confronto fra i due bracci, per ogni domanda, dalle esecuzioni:
  la domanda coperta: in quante il codice è quello giusto (un dato);
  la domanda non coperta: in quante coperta è false, cioè la risposta dice che
    i brani non contengono la risposta; «confermata» se il permesso porta più
    risposte di questo tipo, «non distinguibile» se sono tante quante,
    «non confermata in questa misura» se sono di meno (un confronto, come dice
    l'affermazione di Anthropic: mai un'uscita diversa).
L'affermazione dice che il permesso può ridurre: non che elimina. Un esito non
decide l'uscita.

Uso:    python3 -B -I controlla_fonti.py <cartella delle esecuzioni>
Env:    PN_HANDSON_ROOT  il repository, dove sta tools/lib_leggi_contesto.py
                         (default: la radice sopra la cartella dell'elemento)
Uscita: 0 ogni esecuzione c'è ed è finita bene · 1 un'esecuzione che manca
        alla sua coppia, una domanda che manca, una chiamata non finita, senza
        il server del banco o senza l'uscita strutturata: la prova va rifatta ·
        2 uso sbagliato; la
        cartella che non c'è o senza esecuzioni; un file che non si legge; i
        casi o tools/lib_leggi_contesto.py che mancano; un errore inatteso
        (una riga, mai un traceback)
"""
from __future__ import annotations

import json
import os
import re
import sys
import textwrap
from typing import Any, Dict, List, NamedTuple, Optional, Sequence


def _strumenti() -> str:
    """tools/ del repository: PN_HANDSON_ROOT, o la radice sopra la cartella
    dell'elemento (<radice>/m7_…/s6_…/m7_6_…/M7-D06_…/demo/)."""
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

BRACCI = ("con-permesso", "senza-permesso")
QUALE = {"con-permesso": "con il permesso di dire «non lo so»",
         "senza-permesso": "senza quel permesso"}
ESECUZIONE = re.compile(r"^(con-permesso|senza-permesso)-([1-9][0-9]*)$")
CASI = "casi"
RIFARE = "rifate la prova (il README dice come)"
USO = "Uso: python3 -B -I controlla_fonti.py <cartella delle esecuzioni>\n"
LARGHEZZA = 76
RIGHE_RISPOSTA = 6
CONFERMATA = "confermata"
NON_DISTINGUIBILE = "non distinguibile"
NON_CONFERMATA = "non confermata in questa misura"
# I numeri in lettere che non sono anche parole d'altro («sei», «una»…).
PAROLE = {"due": 2, "tre": 3, "quattro": 4, "cinque": 5, "sette": 7,
          "otto": 8, "nove": 9, "dieci": 10, "undici": 11, "dodici": 12,
          "quindici": 15, "venti": 20, "trenta": 30}
CIFRE = re.compile(r"(?<![\w.,])\d{1,3}(?:\.\d{3})+(?:,\d+)?(?![\w])"
                   r"|(?<![\w.,])\d+(?:[.,]\d+)?(?![\w])"
                   r"|\b(%s)\b" % "|".join(PAROLE), re.IGNORECASE)
CODICE_KB = re.compile(r"\bKB-\d+\b", re.IGNORECASE)
SERVER = "assistenza"
PREFISSO_SERVER = "mcp__assistenza__"
STATI_SERVER_KO = ("failed", "needs-auth")


class Incompleto(Exception):
    """Un'esecuzione che manca o non è finita bene: uscita 1."""


class Caso(NamedTuple):
    """Una domanda: l'id, il testo, il codice giusto (None: non coperta)."""
    ident: str
    domanda: str
    codice: Optional[str]


class Domanda(NamedTuple):
    """Ciò che un'esecuzione dice di una domanda."""
    coperta: bool
    codice: Optional[str]
    risposta: str
    cercato: List[str]
    restituiti: List[str]
    fuori: List[str]
    turni: int
    secondi: float
    token: int


def migliaia(numero: float) -> str:
    """Il numero intero con il punto delle migliaia."""
    return "{:,}".format(int(numero)).replace(",", ".")


def virgola(valore: float) -> str:
    """Un numero con la virgola, un decimale."""
    return ("%.1f" % valore).replace(".", ",")


def sino(vero: bool) -> str:
    """sì oppure no."""
    return "sì" if vero else "no"


def leggi_json(percorso: str) -> Any:
    """Un file JSON. Raises: lc.Problema."""
    try:
        with open(percorso, encoding="utf-8") as fh:
            return json.load(fh)
    except (OSError, UnicodeDecodeError, ValueError) as exc:
        raise lc.Problema("%s non si legge come JSON (%s)"
                          % (percorso, exc)) from exc


def leggi_casi() -> List[Caso]:
    """Le domande di casi/, accanto a questo file, in ordine di nome.
    Raises: lc.Problema."""
    cartella = os.path.join(os.path.dirname(os.path.realpath(__file__)), CASI)
    try:
        nomi = sorted(n for n in os.listdir(cartella) if n.endswith(".json"))
    except OSError as exc:
        raise lc.Problema("manca la cartella dei casi %s" % cartella) from exc
    casi = []
    for nome in nomi:
        dati = leggi_json(os.path.join(cartella, nome))
        if not isinstance(dati, dict) \
                or not isinstance(dati.get("id"), str) \
                or not isinstance(dati.get("messaggio"), str):
            raise lc.Problema("il caso %s non ha id e messaggio" % nome)
        casi.append(Caso(dati["id"], dati["messaggio"],
                         dati.get("codice_atteso")))
    if len(casi) != 2 or sum(1 for c in casi if c.codice) != 1:
        raise lc.Problema("servono due casi, uno coperto (con codice_atteso) "
                          "e uno no, in %s" % cartella)
    return casi


def numeri_di(testo: str) -> List[str]:
    """I numeri di un testo, come vi sono scritti, fuori dai codici KB-NN;
    nell'ordine, ogni valore una volta."""
    numeri: List[str] = []
    viste = set()
    for trovato in CIFRE.finditer(CODICE_KB.sub(" ", testo)):
        numero = trovato.group(0)
        valore = canonico(numero)
        if valore not in viste:
            viste.add(valore)
            numeri.append(numero)
    return numeri


def canonico(numero: str) -> str:
    """Il valore di un numero, in cifre: «59», «59,5», «due» → «2»."""
    if numero.lower() in PAROLE:
        return str(PAROLE[numero.lower()])
    decimale = numero.replace(".", "") if "," in numero else numero
    decimale = decimale.replace(",", ".")
    if re.fullmatch(r"\d{1,3}(?:\.\d{3})+", numero):
        decimale = numero.replace(".", "")
    return decimale.rstrip("0").rstrip(".") if "." in decimale else decimale


def leggi_registro(percorso: str) -> List[Dict[str, Any]]:
    """Le chiamate del registro del server, in ordine; file assente: nessuna.
    Raises: lc.Problema."""
    if not os.path.isfile(percorso):
        return []
    chiamate: List[Dict[str, Any]] = []
    try:
        with open(percorso, encoding="utf-8") as fh:
            righe = fh.read().splitlines()
    except (OSError, UnicodeDecodeError) as exc:
        raise lc.Problema("non riesco a leggere %s: %s" % (percorso, exc)
                          ) from exc
    for numero, riga in enumerate(righe, 1):
        if not riga.strip():
            continue
        try:
            evento = json.loads(riga)
        except ValueError as exc:
            raise lc.Problema("%s, riga %d: non è JSON" % (percorso, numero)
                              ) from exc
        if not isinstance(evento, dict):
            raise lc.Problema("%s, riga %d: non è un oggetto JSON"
                              % (percorso, numero))
        chiamate.append(evento)
    return chiamate


def strutturato(risultato: Dict[str, Any], nome: str) -> Dict[str, Any]:
    """L'uscita strutturata dell'ultimo evento result dello stream, controllata.
    Raises: Incompleto."""
    campo = risultato.get("structured_output")
    if not isinstance(campo, dict) \
            or not isinstance(campo.get("coperta"), bool) \
            or not isinstance(campo.get("risposta"), str) \
            or not (campo.get("codice_procedura") is None
                    or isinstance(campo.get("codice_procedura"), str)):
        raise Incompleto("%s: senza l'uscita strutturata richiesta: %s"
                         % (nome, RIFARE))
    return campo


def brani(chiamate: Sequence[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """I brani restituiti dalle chiamate del registro, una volta per id."""
    visti: Dict[str, Dict[str, Any]] = {}
    for chiamata in chiamate:
        risultato = chiamata.get("risultato")
        lista = risultato.get("risultati") if isinstance(risultato, dict) \
            else None
        for brano in lista if isinstance(lista, list) else []:
            if isinstance(brano, dict) and brano.get("id") is not None:
                visti.setdefault(str(brano["id"]).upper(), brano)
    return [visti[k] for k in sorted(visti)]


def cercato(chiamate: Sequence[Dict[str, Any]]) -> List[str]:
    """Che cosa ha chiesto Claude allo strumento, una riga per chiamata."""
    righe = []
    for chiamata in chiamate:
        argomenti = chiamata.get("argomenti")
        testo = ", ".join(str(v) for v in argomenti.values()) \
            if isinstance(argomenti, dict) and argomenti else "—"
        righe.append("%s «%s»" % (chiamata.get("strumento", "?"), testo))
    return righe


def server_assente(eventi: Sequence[Dict[str, Any]]) -> Optional[str]:
    """Il motivo per cui il server del banco non c'era, dall'evento init, o
    None: la stessa regola di lib_banco.leggi_stream del banco. Un init
    compattato, senza «tools», non dice nulla del server e non è un guasto
    (le copie della registrazione in soluzione/)."""
    for evento in eventi:
        if evento.get("type") != "system" or evento.get("subtype") != "init":
            continue
        elenco = evento.get("mcp_servers")
        stato = next((v.get("status") for v in (
            elenco if isinstance(elenco, list) else [])
            if isinstance(v, dict) and v.get("name") == SERVER), None)
        if stato in STATI_SERVER_KO:
            return "il server MCP «%s» non si è collegato (stato: %s)" % (
                SERVER, stato)
        strumenti = evento.get("tools")
        if stato != "pending" and "tools" in evento and not any(
                isinstance(t, str) and t.startswith(PREFISSO_SERVER)
                for t in (strumenti if isinstance(strumenti, list) else [])):
            return "il server MCP «%s» non ha dato strumenti a Claude" % SERVER
        return None
    return "lo stream non ha l'evento init"


def leggi_domanda(cartella: str, nome: str, caso: Caso) -> Domanda:
    """Una domanda di un'esecuzione: l'uscita strutturata e tutto il resto
    dallo stream, i brani dal registro del server. Il riepilogo esito.json non
    si legge: è un file di esiti, scritto prima.
    Raises: Incompleto, lc.Problema."""
    dove = os.path.join(cartella, nome, caso.ident)
    etichetta = "%s/%s" % (nome, caso.ident)
    percorso = os.path.join(dove, "stream.jsonl")
    if not os.path.isfile(percorso):
        raise Incompleto("manca %s/stream.jsonl: %s" % (etichetta, RIFARE))
    uso = lc.leggi_stream(percorso)
    if not uso.completa or uso.errore:
        raise Incompleto("%s: la chiamata non è finita bene: %s"
                         % (etichetta, RIFARE))
    eventi = lc._eventi(percorso)
    assente = server_assente(eventi)
    if assente:
        raise Incompleto("%s: %s: %s" % (etichetta, assente, RIFARE))
    campo = strutturato([e for e in eventi if e.get("type") == "result"][-1],
                        etichetta)
    chiamate = leggi_registro(os.path.join(dove, "registro.jsonl"))
    restituiti = brani(chiamate)
    testi = " ".join(str(b.get("titolo", "")) + " " + str(b.get("estratto", ""))
                     for b in restituiti)
    dentro = {canonico(n) for n in numeri_di(testi)}
    risposta = str(campo["risposta"])
    fuori = [n for n in numeri_di(risposta) if canonico(n) not in dentro]
    return Domanda(campo["coperta"], campo.get("codice_procedura"), risposta,
                   cercato(chiamate),
                   [str(b["id"]).upper() for b in restituiti],
                   fuori, int(uso.turni), float(uso.secondi),
                   int(uso.token_totali))


def numeri_esecuzioni(cartella: str) -> List[int]:
    """I numeri delle esecuzioni della cartella. Raises: lc.Problema."""
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


def leggi_tutto(cartella: str, numeri: Sequence[int], casi: Sequence[Caso]
                ) -> Dict[str, Dict[str, Domanda]]:
    """Tutte le esecuzioni, ogni mancanza in una volta.
    Raises: Incompleto; lc.Problema, al primo file che non si legge."""
    letti: Dict[str, Dict[str, Domanda]] = {}
    mancano: List[str] = []
    for braccio in BRACCI:
        for numero in numeri:
            nome = "%s-%d" % (braccio, numero)
            if not os.path.isdir(os.path.join(cartella, nome)):
                mancano.append("manca l'esecuzione %s: %s" % (nome, RIFARE))
                continue
            letti[nome] = {}
            for caso in casi:
                try:
                    letti[nome][caso.ident] = leggi_domanda(cartella, nome,
                                                            caso)
                except Incompleto as exc:
                    mancano.append(str(exc))
    if mancano:
        raise Incompleto("\n".join(mancano))
    return letti


def a_capo(testo: str, rientro: str) -> List[str]:
    """Il testo su righe di LARGHEZZA, al massimo RIGHE_RISPOSTA."""
    righe = textwrap.wrap(" ".join(testo.split()),
                          LARGHEZZA - len(rientro)) or ["(vuota)"]
    if len(righe) > RIGHE_RISPOSTA:
        righe = righe[:RIGHE_RISPOSTA]
        righe[-1] += " …"
    return [rientro + r for r in righe]


def giusto(domanda: Domanda, caso: Caso) -> bool:
    """Vero se il codice della risposta è quello del caso coperto."""
    return bool(caso.codice) \
        and (domanda.codice or "").strip().upper() == caso.codice


def stampa_domanda(nome: str, caso: Caso, domanda: Domanda) -> None:
    """Le righe di una domanda di un'esecuzione."""
    print("%s, %s: «%s»" % (nome, "coperta" if caso.codice else "non coperta",
                            caso.domanda))
    for riga in domanda.cercato or ["nessuna chiamata a cerca_kb"]:
        print("  cerca: %s" % riga)
    print("  brani restituiti: %s" % (", ".join(domanda.restituiti) or
                                      "nessuno"))
    print("  coperta: %s; codice_procedura: %s%s" % (
        sino(domanda.coperta), domanda.codice or "null",
        "" if not domanda.codice else "; fra i brani restituiti: %s" % sino(
            domanda.codice.strip().upper() in domanda.restituiti)))
    print("  risposta:")
    for riga in a_capo(domanda.risposta, "    "):
        print(riga)
    print("  (dato) numeri della risposta che non stanno nei brani: %s" % (
        ", ".join(domanda.fuori) or "nessuno"))
    print("  turni %d, %s s, %s token" % (domanda.turni,
                                          virgola(domanda.secondi),
                                          migliaia(domanda.token)))


def conta(letti: Dict[str, Dict[str, Domanda]], caso: Caso, braccio: str,
          numeri: Sequence[int], prova: Any) -> int:
    """In quante esecuzioni del braccio vale prova(domanda)."""
    return sum(1 for n in numeri
               if prova(letti["%s-%d" % (braccio, n)][caso.ident]))


def esito_confronto(con: int, senza: int) -> str:
    """Il confronto sulla domanda non coperta: più risposte che dicono che i
    brani non la contengono, con il permesso?"""
    if con > senza:
        return "%s (con il permesso %d, senza %d)" % (CONFERMATA, con, senza)
    if con == senza:
        return "%s (%d contro %d: la stessa cosa con e senza il permesso)" % (
            NON_DISTINGUIBILE, con, senza)
    return "%s (con il permesso %d, senza %d)" % (NON_CONFERMATA, con, senza)


def stampa_confronto(letti: Dict[str, Dict[str, Domanda]],
                     casi: Sequence[Caso], numeri: Sequence[int]) -> None:
    """Per ogni domanda, n su N nei due bracci; e il confronto."""
    n = len(numeri)
    for caso in casi:
        if caso.codice:
            print("La domanda coperta: il codice giusto, %s, nell'uscita "
                  "strutturata (un dato):" % caso.codice)
            for braccio in BRACCI:
                giuste = conta(letti, caso, braccio, numeri,
                               lambda d: giusto(d, caso))
                print("  %s: %d su %d" % (QUALE[braccio], giuste, n))
            continue
        print("La domanda non coperta: coperta false, cioè «i brani non "
              "contengono la risposta» (n su %d):" % n)
        conti = {}
        for braccio in BRACCI:
            conti[braccio] = conta(letti, caso, braccio, numeri,
                                   lambda d: not d.coperta)
            fuori = conta(letti, caso, braccio, numeri, lambda d: bool(d.fuori))
            print("  %s: %d su %d; (dato) con un numero che non sta nei brani: "
                  "%d su %d" % (QUALE[braccio], conti[braccio], n, fuori, n))
        print("«Allow Claude to say \"I don't know\": Explicitly give Claude "
              "permission to admit uncertainty.»:")
        print("  %s" % esito_confronto(conti["con-permesso"],
                                       conti["senza-permesso"]))


def stampa_consumo(letti: Dict[str, Dict[str, Domanda]]) -> None:
    """Il consumo di tutte le chiamate."""
    tutte = [d for run in letti.values() for d in run.values()]
    print("Come dati, tutte le %d chiamate: turni %d; token %s; %s s." % (
        len(tutte), sum(d.turni for d in tutte),
        migliaia(sum(d.token for d in tutte)),
        virgola(sum(d.secondi for d in tutte))))


def controlla(cartella: str) -> int:
    """Il controllo: stampa i dati e gli esiti; l'uscita 0."""
    casi = leggi_casi()
    numeri = numeri_esecuzioni(cartella)
    letti = leggi_tutto(cartella, numeri, casi)
    print("%d esecuzioni per braccio, %d domande; le frasi dei due bracci "
          "differiscono in una: il permesso di dire «non lo so»."
          % (len(numeri), len(casi)))
    for braccio in BRACCI:
        for numero in numeri:
            for caso in casi:
                print()
                nome = "%s-%d" % (braccio, numero)
                stampa_domanda(nome, caso, letti[nome][caso.ident])
    print()
    stampa_confronto(letti, casi, numeri)
    print()
    stampa_consumo(letti)
    return 0


def errore(messaggio: str, uscita: int) -> int:
    """Il messaggio su STDERR, una riga per problema; l'uscita data."""
    for riga in messaggio.split("\n"):
        sys.stderr.write("controlla_fonti.py: %s\n" % riga)
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
