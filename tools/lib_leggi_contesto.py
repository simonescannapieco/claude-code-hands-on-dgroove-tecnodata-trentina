"""lib_leggi_contesto.py -- ciò che i controlli del Modulo 6 leggono di
un'esecuzione di `claude -p --output-format stream-json --verbose` e del
registro dell'hook InstructionsLoaded (tools/registra_caricamenti.py).

Di uno stream, oltre a ciò che dà tools/lib_leggi_stream.py (turni, secondi e
token sommati su tutti i segmenti, gli strumenti chiamati, il testo finale):

- prima_richiesta: i token della prima richiesta al modello della sessione
  principale, quella che porta il contesto di partenza (il system prompt, gli
  strumenti, i CLAUDE.md e le regole caricati all'avvio, il prompt):
  input_tokens + cache_creation_input_tokens + cache_read_input_tokens del
  primo messaggio assistant senza parent_tool_use_id. È la cifra con cui i
  controlli confrontano due versioni dello stesso contesto: lo stesso prompt,
  gli stessi strumenti, un file in più o in meno;
- comandi: i comandi Bash, nell'ordine in cui Claude li ha chiesti;
- risultati: per ogni id di tool_use, il testo del suo tool_result e se è un
  errore.

Del registro dell'hook, un Caricamento per riga, nell'ordine.

Qualunque cosa non si riesca a leggere solleva Problema (quello di
lib_leggi_stream), mai un elenco più corto. Un registro che non c'è è un
Problema: chi esegue la prova lo crea vuoto prima della sessione, così vuoto
vuol dire «niente caricato» e assente vuol dire «la prova non è andata come
doveva». Libreria: nessun bit di esecuzione; chi la importa mette tools/ nel
sys.path.
"""
from __future__ import annotations

import json
from typing import Dict, List, NamedTuple, Optional, Tuple

# _eventi è la lettura delle righe di lib_leggi_stream: la stessa, così i due
# moduli non possono leggere lo stesso file in modi diversi.
from lib_leggi_stream import (Esecuzione, Problema, _eventi,  # noqa: F401
                              leggi_stream)

MOTIVI = ("session_start", "nested_traversal", "path_glob_match", "include",
          "compact")
TOKEN_RICHIESTA = ("input_tokens", "cache_creation_input_tokens",
                   "cache_read_input_tokens")


class Risultato(NamedTuple):
    """Il tool_result di un tool_use: il testo e se è un errore."""
    testo: str
    errore: bool


class Contesto(NamedTuple):
    """Ciò che uno stream dice del contesto di un'esecuzione."""
    esecuzione: Esecuzione
    prima_richiesta: int
    comandi: List[str]
    risultati: Dict[str, Risultato]
    modello: Optional[str]


class Caricamento(NamedTuple):
    """Una riga del registro dell'hook InstructionsLoaded."""
    load_reason: str
    file_path: str
    memory_type: Optional[str]
    trigger_file_path: Optional[str]
    parent_file_path: Optional[str]
    globs: Optional[List[str]]


def _principale(evento: dict) -> bool:
    return evento.get("type") == "assistant" \
        and evento.get("parent_tool_use_id") is None


def _prima_richiesta(eventi: List[dict], percorso: str) -> int:
    for evento in eventi:
        messaggio = evento.get("message")
        if not _principale(evento) or not isinstance(messaggio, dict):
            continue
        usage = messaggio.get("usage")
        if not isinstance(usage, dict):
            continue
        totale = 0
        for chiave in TOKEN_RICHIESTA:
            valore = usage.get(chiave, 0)
            if isinstance(valore, bool) or not isinstance(valore, int) \
                    or valore < 0:
                raise Problema(f"{percorso}: il primo messaggio assistant "
                               f"ha «{chiave}» non valido: {valore!r}")
            totale += valore
        return totale
    raise Problema(f"{percorso}: nessun messaggio assistant con «usage»: "
                   "la prima richiesta non si legge")


def _modello(eventi: List[dict]) -> Optional[str]:
    for evento in eventi:
        if evento.get("type") == "system" and evento.get("subtype") == "init":
            modello = evento.get("model")
            return modello if isinstance(modello, str) else None
    return None


def _testo_blocco(contenuto: object) -> str:
    if isinstance(contenuto, str):
        return contenuto
    if isinstance(contenuto, list):
        parti = []
        for parte in contenuto:
            if isinstance(parte, dict) and parte.get("type") == "text" \
                    and isinstance(parte.get("text"), str):
                parti.append(parte["text"])
        return "\n".join(parti)
    return ""


def _risultati(eventi: List[dict]) -> Dict[str, Risultato]:
    risultati: Dict[str, Risultato] = {}
    for evento in eventi:
        messaggio = evento.get("message")
        if evento.get("type") != "user" or not isinstance(messaggio, dict) \
                or not isinstance(messaggio.get("content"), list):
            continue
        for blocco in messaggio["content"]:
            if not isinstance(blocco, dict) \
                    or blocco.get("type") != "tool_result":
                continue
            ident = blocco.get("tool_use_id")
            if isinstance(ident, str):
                risultati[ident] = Risultato(
                    _testo_blocco(blocco.get("content")),
                    bool(blocco.get("is_error")))
    return risultati


def _comandi(esec: Esecuzione) -> List[str]:
    comandi = []
    for strumento in esec.strumenti:
        if strumento.nome != "Bash":
            continue
        ingresso = strumento.input
        comando = ingresso.get("command") if isinstance(ingresso, dict) \
            else None
        if not isinstance(comando, str):
            raise Problema(f"{esec.percorso}: una chiamata Bash senza "
                           "input.command")
        comandi.append(comando)
    return comandi


def leggi_contesto(percorso: str) -> Contesto:
    """Legge uno stream. Raises: Problema."""
    esec = leggi_stream(percorso)
    eventi = _eventi(percorso)
    return Contesto(esecuzione=esec,
                    prima_richiesta=_prima_richiesta(eventi, percorso),
                    comandi=_comandi(esec), risultati=_risultati(eventi),
                    modello=_modello(eventi))


def risultati_bash(percorso: str) -> List[Tuple[str, Risultato]]:
    """I comandi Bash con il loro risultato, nell'ordine; un comando senza
    risultato (la sessione finita prima) ha un Risultato vuoto, errore.
    Raises: Problema."""
    eventi = _eventi(percorso)
    risultati = _risultati(eventi)
    coppie = []
    visti = set()
    for evento in eventi:
        messaggio = evento.get("message")
        if evento.get("type") != "assistant" \
                or not isinstance(messaggio, dict) \
                or not isinstance(messaggio.get("content"), list):
            continue
        for blocco in messaggio["content"]:
            if not isinstance(blocco, dict) or blocco.get("type") \
                    != "tool_use" or blocco.get("name") != "Bash":
                continue
            ident = blocco.get("id")
            if ident in visti:
                continue
            visti.add(ident)
            ingresso = blocco.get("input")
            comando = ingresso.get("command") \
                if isinstance(ingresso, dict) else None
            if not isinstance(comando, str):
                raise Problema(f"{percorso}: una chiamata Bash senza "
                               "input.command")
            coppie.append((comando, risultati.get(
                ident, Risultato("", True))))
    return coppie


def _campo_testo(dato: dict, campo: str, percorso: str, numero: int,
                 obbligatorio: bool) -> Optional[str]:
    valore = dato.get(campo)
    if valore is None and not obbligatorio:
        return None
    if not isinstance(valore, str) or not valore:
        raise Problema(f"{percorso}, riga {numero}: «{campo}» non è un "
                       f"testo: {valore!r}")
    return valore


def leggi_caricamenti(percorso: str) -> List[Caricamento]:
    """Le righe del registro dell'hook. Raises: Problema."""
    caricamenti: List[Caricamento] = []
    try:
        with open(percorso, encoding="utf-8") as fh:
            righe = fh.read().splitlines()
    except (OSError, UnicodeDecodeError) as exc:
        raise Problema(f"non riesco a leggere il registro {percorso}: "
                       f"{exc}") from exc
    for numero, riga in enumerate(righe, 1):
        if not riga.strip():
            continue
        try:
            dato = json.loads(riga)
        except ValueError as exc:
            raise Problema(f"{percorso}, riga {numero}: non è JSON: "
                           f"{exc}") from exc
        if not isinstance(dato, dict):
            raise Problema(f"{percorso}, riga {numero}: non è un oggetto")
        motivo = _campo_testo(dato, "load_reason", percorso, numero, True)
        if motivo not in MOTIVI:
            raise Problema(f"{percorso}, riga {numero}: load_reason "
                           f"sconosciuto: {motivo!r}")
        globs = dato.get("globs")
        if globs is not None and (not isinstance(globs, list) or not all(
                isinstance(g, str) for g in globs)):
            raise Problema(f"{percorso}, riga {numero}: «globs» non è un "
                           "elenco di testi")
        caricamenti.append(Caricamento(
            load_reason=str(motivo),
            file_path=str(_campo_testo(dato, "file_path", percorso, numero,
                                       True)),
            memory_type=_campo_testo(dato, "memory_type", percorso, numero,
                                     False),
            trigger_file_path=_campo_testo(dato, "trigger_file_path",
                                           percorso, numero, False),
            parent_file_path=_campo_testo(dato, "parent_file_path",
                                          percorso, numero, False),
            globs=globs))
    return caricamenti


def caricati(caricamenti: List[Caricamento], motivo: str) -> List[str]:
    """I file caricati per quel motivo, nell'ordine, ciascuno una volta."""
    visti: List[str] = []
    for caricamento in caricamenti:
        if caricamento.load_reason == motivo \
                and caricamento.file_path not in visti:
            visti.append(caricamento.file_path)
    return visti
