"""sessioni_claude.py -- le sessioni di Claude Code di uno spazio di lavoro,
lette dai file che Claude Code salva; per verifica.py di M4-E04 e di M4-E05
(lo stesso file nei due elementi).

Claude Code salva le trascrizioni in ~/.claude/projects/<progetto>/
<sessione>.jsonl, e quelle dei subagent in <sessione>/subagents/
agent-<id>.jsonl. <progetto> è il percorso dello spazio di lavoro con ogni
carattere che non è una lettera o una cifra cambiato in «-»: la forma dei
nomi delle cartelle che Claude Code 2.1.312 ha creato per gli spazi di
lavoro del corso. PN_CLAUDE_DIR, se c'è, sta al posto di ~/.claude (le
prove del docente). Si leggono soltanto le sessioni di quello spazio di
lavoro.

Ne ricava, come dati che non decidono l'uscita: quante sessioni; le
chiamate al tool Agent (o Task, il suo nome prima della 2.1.63), per tipo di
subagent; quante volte Claude ha eseguito il controllo dell'esercizio, e
con quale uscita l'ultima volta. E una garanzia, che decide: un subagent
«revisore» definito con soli tools Read, Grep, Glob non usa strumenti che
modificano (Edit, Write, NotebookEdit, MultiEdit). La trascrizione del
revisore si riconosce da uno di tre segni: accanto alla trascrizione, un
agent-<id>.meta.json che porti il valore «revisore» (un file che la
verifica legge se c'è, non uno che la documentazione di Claude Code
promette); il primo messaggio della trascrizione è il prompt di una
chiamata Agent con subagent_type «revisore»; il risultato di quella
chiamata nomina il suo id. Se le trascrizioni riconosciute sono meno delle
chiamate al revisore, la garanzia è «non distinguibile»: una chiamata
senza trascrizione non si controlla. Una trascrizione che non si legge è
una Precondizione: la garanzia non si decide su ciò che non si è letto.

Si usa con riepilogo(spazio di lavoro, nome del controllo): le righe da
stampare e, se la garanzia non ha tenuto, la segnalazione; Precondizione
se una trascrizione non si legge.
"""
import glob
import json
import os
import re
from typing import Dict, Iterator, List, Optional, Set, Tuple

AGENT = ("Agent", "Task")
MODIFICA = ("Edit", "Write", "NotebookEdit", "MultiEdit")
LETTURA = {"Read", "Grep", "Glob"}
REVISORE = "revisore"
TUTTI = "tutti gli strumenti"
USCITA = re.compile(r"uscita: ([0-9]+)\s*$")


class Precondizione(Exception):
    """Una trascrizione che non si legge: verifica.py esce 2."""


def cartelle(ws: str) -> List[str]:
    """Le cartelle delle sessioni dello spazio di lavoro che esistono: dal
    percorso dato e da quello reale, se diversi."""
    base = os.environ.get("PN_CLAUDE_DIR") or os.path.join(
        os.path.expanduser("~"), ".claude")
    trovate = []
    for percorso in (os.path.abspath(ws), os.path.realpath(ws)):
        cartella = os.path.join(base, "projects",
                                re.sub(r"[^A-Za-z0-9]", "-", percorso))
        if os.path.isdir(cartella) and cartella not in trovate:
            trovate.append(cartella)
    return trovate


def righe_json(percorso: str) -> Iterator[dict]:
    """Le righe JSON (oggetti) di una trascrizione; le altre si saltano.
    Una trascrizione che non si apre è una Precondizione, mai «nessuno
    strumento»."""
    try:
        fh = open(percorso, encoding="utf-8", errors="replace")
    except OSError as exc:
        raise Precondizione("una trascrizione di Claude Code non si legge: "
                            "%s (%s)" % (percorso, exc.strerror
                                         or type(exc).__name__))
    with fh:
        for riga in fh:
            try:
                oggetto = json.loads(riga)
            except ValueError:
                continue
            if isinstance(oggetto, dict):
                yield oggetto


def blocchi(oggetto: dict, ruolo: str, tipo: str) -> List[dict]:
    """I blocchi di un tipo nel messaggio di una riga del ruolo dato."""
    messaggio = oggetto.get("message")
    if oggetto.get("type") != ruolo or not isinstance(messaggio, dict):
        return []
    contenuto = messaggio.get("content")
    if not isinstance(contenuto, list):
        return []
    return [b for b in contenuto if isinstance(b, dict)
            and b.get("type") == tipo]


def testo(contenuto) -> str:
    """Il testo di un risultato: una stringa, o i blocchi di testo."""
    if isinstance(contenuto, str):
        return contenuto
    if isinstance(contenuto, list):
        return "\n".join(str(b.get("text", "")) for b in contenuto
                         if isinstance(b, dict))
    return ""


def piatto(stringa: str) -> str:
    return " ".join(stringa.split())


def leggi_principali(sessioni: List[str], controllo: str):
    """Le chiamate Agent (id, tipo, prompt), i risultati per id e le
    esecuzioni del controllo (in ordine), dalle conversazioni principali."""
    agenti = []  # type: List[dict]
    risultati = {}  # type: Dict[str, str]
    controlli = []  # type: List[str]
    for percorso in sessioni:
        for oggetto in righe_json(percorso):
            if oggetto.get("isSidechain") is True:
                continue
            for b in blocchi(oggetto, "assistant", "tool_use"):
                ingresso = b.get("input") if isinstance(b.get("input"),
                                                        dict) else {}
                if b.get("name") in AGENT and isinstance(b.get("id"), str):
                    agenti.append({
                        "id": b["id"],
                        "tipo": str(ingresso.get("subagent_type")
                                    or "general-purpose"),
                        "prompt": str(ingresso.get("prompt") or "")})
                elif b.get("name") == "Bash" and controllo in str(
                        ingresso.get("command", "")):
                    controlli.append(str(b.get("id")))
            for b in blocchi(oggetto, "user", "tool_result"):
                risultati[str(b.get("tool_use_id"))] = testo(
                    b.get("content"))
    return agenti, risultati, controlli


def valori(oggetto, profondita: int = 3) -> Set[str]:
    """I valori stringa di un JSON, fino a una certa profondità."""
    if isinstance(oggetto, str):
        return {oggetto}
    if profondita == 0:
        return set()
    figli = oggetto.values() if isinstance(oggetto, dict) else (
        oggetto if isinstance(oggetto, list) else [])
    insieme = set()  # type: Set[str]
    for figlio in figli:
        insieme |= valori(figlio, profondita - 1)
    return insieme


def primo_messaggio(percorso: str) -> str:
    """Il testo del primo messaggio dell'utente in una trascrizione."""
    for oggetto in righe_json(percorso):
        messaggio = oggetto.get("message")
        if oggetto.get("type") == "user" and isinstance(messaggio, dict):
            return piatto(testo(messaggio.get("content")))
    return ""


def strumenti_usati(percorso: str) -> List[str]:
    """I nomi degli strumenti chiamati in una trascrizione."""
    return [str(b.get("name")) for oggetto in righe_json(percorso)
            for b in blocchi(oggetto, "assistant", "tool_use")]


def trascrizioni_revisore(cartella: str, revisioni: List[dict],
                          risultati: Dict[str, str]) -> List[Tuple[str, str]]:
    """(id, trascrizione) dei subagent riconosciuti come il revisore."""
    prompt = [piatto(c["prompt"]) for c in revisioni
              if len(piatto(c["prompt"])) >= 20]
    testi = " ".join(risultati.get(c["id"], "") for c in revisioni)
    trovate = []
    for file in sorted(glob.glob(os.path.join(cartella, "*", "subagents",
                                              "agent-*.jsonl"))):
        ident = os.path.basename(file)[len("agent-"):-len(".jsonl")]
        try:
            with open(file[:-len(".jsonl")] + ".meta.json",
                      encoding="utf-8") as fh:
                dal_meta = REVISORE in valori(json.load(fh))
        except (OSError, ValueError):
            dal_meta = False
        primo = primo_messaggio(file)
        dal_prompt = bool(primo) and any(p in primo for p in prompt)
        dal_risultato = re.search(r"(?<![0-9A-Za-z])%s(?![0-9A-Za-z])"
                                  % re.escape(ident), testi) is not None
        if dal_meta or dal_prompt or dal_risultato:
            trovate.append((ident, file))
    return trovate


def strumenti_definiti(ws: str) -> Optional[Set[str]]:
    """Gli strumenti della definizione del revisore nello spazio di lavoro;
    None se la definizione non c'è; {TUTTI} se non ha «tools»."""
    percorso = os.path.join(ws, ".claude", "agents", REVISORE + ".md")
    try:
        with open(percorso, encoding="utf-8", errors="replace") as fh:
            testa = re.match(r"---\s*\n(.*?)\n---", fh.read(), re.S)
    except OSError:
        return None
    righe = testa.group(1).splitlines() if testa else []
    for i, riga in enumerate(righe):
        if riga.startswith("tools:"):
            valore = riga.split(":", 1)[1].strip()
            if valore:
                return {s.strip() for s in valore.split(",") if s.strip()}
            return {r.split("-", 1)[1].strip() for r in righe[i + 1:]
                    if re.match(r"\s*-\s+", r)}
    return {TUTTI}


def garanzia(ws: str, cartelle_ws: List[str], agenti: List[dict],
             risultati: Dict[str, str]) -> Tuple[List[str], Optional[str]]:
    """La garanzia del revisore: le righe e, se non ha tenuto, il motivo."""
    revisioni = [c for c in agenti if c["tipo"] == REVISORE]
    if not revisioni:
        return (["(dato) il revisore non è stato chiamato in queste sessioni: "
                 "nessun esito sulla garanzia"], None)
    definiti = strumenti_definiti(ws)
    if definiti is None or not definiti <= LETTURA:
        return (["il revisore dello spazio di lavoro ha %s: la garanzia non "
                 "si applica" % (("tools: " + ", ".join(sorted(definiti)))
                                 if definiti else "nessuna definizione")],
                None)
    sue = [t for c in cartelle_ws
           for t in trascrizioni_revisore(c, revisioni, risultati)]
    if not sue:
        return (["il revisore è stato chiamato %d volte, ma la sua "
                 "trascrizione non si riconosce: nessun esito sulla garanzia"
                 % len(revisioni)], None)
    usati = {ident: [s for s in strumenti_usati(f) if s in MODIFICA]
             for ident, f in sue}
    elenco = "; ".join("agent-%s: %s" % (i, ", ".join(s))
                       for i, s in sorted(usati.items()) if s)
    strumenti = ", ".join(sorted(definiti))
    if elenco:
        return (["il revisore (tools: %s) ha usato strumenti che modificano: "
                 "%s" % (strumenti, elenco)],
                "il revisore ha usato uno strumento che modifica: una "
                "garanzia di Claude Code che qui non ha tenuto")
    if len(sue) < len(revisioni):
        return (["il revisore (tools: %s): %d %s su %d chiamate, nessuno "
                 "strumento che modifica: non distinguibile" % (
                     strumenti, len(sue),
                     "trascrizione" if len(sue) == 1 else "trascrizioni",
                     len(revisioni))], None)
    return (["il revisore (tools: %s): %d %s, nessuno strumento che "
             "modifica: la garanzia vale" % (
                 strumenti, len(sue),
                 "trascrizione" if len(sue) == 1 else "trascrizioni")], None)


def esecuzioni(controllo: str, controlli: List[str],
               risultati: Dict[str, str]) -> str:
    """La riga sulle esecuzioni del controllo, come dato."""
    if not controlli:
        return ("(dato) il controllo (%s) non compare nelle chiamate di "
                "Claude di queste sessioni" % controllo)
    ultima = USCITA.search(risultati.get(controlli[-1], "").rstrip())
    return "(dato) il controllo eseguito da Claude: %d %s, %s" % (
        len(controlli), "volta" if len(controlli) == 1 else "volte",
        "l'ultima con uscita %s" % ultima.group(1) if ultima
        else "l'ultima senza un'uscita leggibile")


def riepilogo(ws: str, controllo: str) -> Tuple[List[str], Optional[str]]:
    """Le righe da stampare sulle sessioni dello spazio di lavoro e, se la
    garanzia del revisore non ha tenuto, la segnalazione."""
    cartelle_ws = cartelle(ws)
    sessioni = sorted((f for c in cartelle_ws
                       for f in glob.glob(os.path.join(c, "*.jsonl"))),
                      key=lambda f: (os.path.getmtime(f), f))
    if not sessioni:
        return (["(dato) nessuna sessione di Claude Code di questo spazio di "
                 "lavoro in ~/.claude/projects/",
                 "(dato) nessun subagent trovato"], None)
    righe = ["(dato) sessioni di Claude Code di questo spazio di lavoro: %d"
             % len(sessioni)]
    agenti, risultati, controlli = leggi_principali(sessioni, controllo)
    if agenti:
        tipi = {}  # type: Dict[str, int]
        for c in agenti:
            tipi[c["tipo"]] = tipi.get(c["tipo"], 0) + 1
        righe.append("(dato) chiamate al tool Agent: %d (%s)" % (
            len(agenti), ", ".join("%s %d" % t for t in sorted(tipi.items()))))
    else:
        righe.append("(dato) nessun subagent trovato")
    righe.append(esecuzioni(controllo, controlli, risultati))
    altre, segnalazione = garanzia(ws, cartelle_ws, agenti, risultati)
    return righe + altre, segnalazione
