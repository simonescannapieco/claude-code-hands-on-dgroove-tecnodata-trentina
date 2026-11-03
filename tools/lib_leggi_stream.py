"""lib_leggi_stream.py -- legge il file di un `claude -p --output-format
stream-json --verbose`: una riga JSON per messaggio e per risultato. Una
chiamata può avere più di un evento result, uno per segmento: quando un
subagent lavora in background, la sua notifica apre un altro segmento. Turni
e durata si sommano su tutti, come fanno i controlli del Modulo 4. I token
sono quelli di `modelUsage` dell'ultimo result, tutto l'albero dei subagent:
«Use modelUsage, or model_usage in Python, for whole-tree token accounting;
the usage field undercounts as soon as nesting occurs.» Dove non c'è, la somma
di `usage`. Vale per una sessione nuova, come quelle di prove_skill.sh: in una
ripresa con --resume modelUsage conta anche la sessione di prima.

Una chiamata Skill che il permesso nega è nel tool_use e nei
permission_denials, con lo stesso id; una che il tool respinge, per esempio una
skill spenta con skillOverrides, ha un tool_result con is_error. In tutti e due
i casi è stata tentata, ma il corpo non è arrivato. Per questo ci sono
chiamate_negate, chiamate_respinte e chiamata_riuscita.

Il modulo da importare è lib_controlla_prove.py, che ridà tutto ciò che è qui
e ne documenta i campi. Qualunque cosa non si riesca a leggere solleva
Problema, mai un conteggio più piccolo. Non è un modulo da eseguire: nessun
bit di esecuzione.
"""
from __future__ import annotations

import json
import math
import os
from typing import List, NamedTuple, Optional, Tuple


class Problema(Exception):
    """Qualcosa che non si riesce a leggere: l'elemento esce 2."""


class Strumento(NamedTuple):
    """Un tool_use: il nome e l'input."""
    nome: str
    input: object


class Esecuzione(NamedTuple):
    """Ciò che uno stream dice di una chiamata (vedi lib_controlla_prove)."""
    percorso: str
    init_skills: Optional[List[str]]
    chiamate_skill: List[str]
    strumenti: List[Strumento]
    testo: str
    turni: int
    secondi: float
    duration_ms: int
    token_totali: int
    segmenti: int
    negati: List[object]
    errore: bool
    completa: bool
    chiamate_negate: List[str]
    chiamate_respinte: List[str]
    token_usage: int
    token_modelli: Optional[float]
    locale: bool

    @property
    def cartella(self) -> str:
        """La cartella dello stream: outputs/."""
        return os.path.dirname(self.percorso)

    def chiamata_riuscita(self, skill: str) -> bool:
        """Vero se almeno una chiamata a quella skill non è stata né negata
        né respinta: il corpo è arrivato."""
        return self.chiamate_skill.count(skill) \
            > self.chiamate_negate.count(skill) \
            + self.chiamate_respinte.count(skill)


def _eventi(percorso: str) -> List[dict]:
    """Le righe di uno stream, in ordine; le righe vuote non contano."""
    eventi: List[dict] = []
    try:
        with open(percorso, encoding="utf-8") as fh:
            for numero, riga in enumerate(fh, 1):
                if not riga.strip():
                    continue
                try:
                    evento = json.loads(riga)
                except ValueError as exc:
                    raise Problema(f"{percorso}, riga {numero}: non è JSON: "
                                   f"{exc}") from exc
                if not isinstance(evento, dict):
                    raise Problema(f"{percorso}, riga {numero}: non è un "
                                   "oggetto JSON")
                eventi.append(evento)
    except (OSError, UnicodeDecodeError) as exc:
        raise Problema(f"non riesco a leggere {percorso}: {exc}") from exc
    return eventi


def _conteggio(dove: object, chiave: str, percorso: str) -> float:
    """Un numero di un evento result; se non si legge, un Problema."""
    valore = dove.get(chiave) if isinstance(dove, dict) else None
    if isinstance(valore, bool) or not isinstance(valore, (int, float)) \
            or not math.isfinite(valore) or valore < 0:
        raise Problema(f"{percorso}: un evento result senza un numero per "
                       f"«{chiave}»: {valore!r}")
    return valore


def _strumenti(eventi: List[dict], percorso: str
               ) -> Tuple[List[Strumento], List[Tuple[str, object]]]:
    """I tool_use delle righe assistant, una volta per id, e le chiamate
    Skill, ciascuna con il suo id: lo stesso messaggio può tornare in un'altra
    riga."""
    strumenti: List[Strumento] = []
    chiamate: List[Tuple[str, object]] = []
    visti = set()
    for evento in eventi:
        messaggio = evento.get("message")
        if evento.get("type") != "assistant" \
                or not isinstance(messaggio, dict) \
                or not isinstance(messaggio.get("content"), list):
            continue
        for blocco in messaggio["content"]:
            if not isinstance(blocco, dict) \
                    or blocco.get("type") != "tool_use":
                continue
            ident = blocco.get("id")
            if ident is not None and ident in visti:
                continue
            visti.add(ident)
            nome = str(blocco.get("name"))
            ingresso = blocco.get("input")
            strumenti.append(Strumento(nome, ingresso))
            if nome == "Skill":
                skill = ingresso.get("skill") \
                    if isinstance(ingresso, dict) else None
                if not isinstance(skill, str) or not skill:
                    raise Problema(f"{percorso}: una chiamata Skill senza "
                                   "input.skill")
                chiamate.append((skill, ident))
    return strumenti, chiamate


def _negate(chiamate: List[Tuple[str, object]],
            negati: List[object]) -> List[str]:
    """Le chiamate Skill il cui id è fra i permission_denials."""
    ids = {voce.get("tool_use_id") for voce in negati
           if isinstance(voce, dict)}
    ids.discard(None)
    return [skill for skill, ident in chiamate if ident in ids]


def _respinte(eventi: List[dict], chiamate: List[Tuple[str, object]],
              negati: List[object]) -> List[str]:
    """Le chiamate Skill il cui tool_result ha is_error, le negate escluse."""
    errori = set()
    for evento in eventi:
        messaggio = evento.get("message")
        contenuto = messaggio.get("content") \
            if isinstance(messaggio, dict) else None
        if evento.get("type") != "user" or not isinstance(contenuto, list):
            continue
        for blocco in contenuto:
            if isinstance(blocco, dict) and blocco.get("is_error") is True \
                    and blocco.get("type") == "tool_result":
                errori.add(blocco.get("tool_use_id"))
    errori.discard(None)
    errori -= {voce.get("tool_use_id") for voce in negati
               if isinstance(voce, dict)}
    return [skill for skill, ident in chiamate if ident in errori]


def _token_modelli(risultati: List[dict]) -> Optional[float]:
    """I token di modelUsage dell'ultimo result, cumulativi per la sessione;
    None se non c'è o non si legge, mai un Problema: allora vale usage."""
    modelli = risultati[-1].get("modelUsage") if risultati else None
    if not isinstance(modelli, dict) or not modelli:
        return None
    totale = 0
    for dati in modelli.values():
        if not isinstance(dati, dict):
            return None
        for chiave in ("inputTokens", "outputTokens", "cacheReadInputTokens",
                       "cacheCreationInputTokens"):
            valore = dati.get(chiave, 0)
            if isinstance(valore, bool) \
                    or not isinstance(valore, (int, float)):
                return None
            totale += valore
    return totale


def _skill_elencate(eventi: List[dict]) -> Optional[List[str]]:
    for evento in eventi:
        if evento.get("type") == "system" and evento.get("subtype") == "init":
            elenco = evento.get("skills")
            if isinstance(elenco, list) \
                    and all(isinstance(nome, str) for nome in elenco):
                return elenco
            return None
    return None


def _testo_finale(risultati: List[dict], percorso: str) -> str:
    if not risultati:
        return ""
    testo = risultati[-1].get("result")
    if testo is None:
        return ""
    if not isinstance(testo, str):
        raise Problema(f"{percorso}: «result» non è un testo")
    return testo


def _token(risultato: dict, percorso: str) -> float:
    usage = risultato.get("usage")
    if not isinstance(usage, dict):
        raise Problema(f"{percorso}: un evento result senza «usage»")
    return sum(_conteggio(usage, chiave, percorso) for chiave in (
        "input_tokens", "cache_creation_input_tokens",
        "cache_read_input_tokens", "output_tokens"))


def leggi_stream(percorso: str) -> Esecuzione:
    """Legge uno stream (vedi lib_controlla_prove). Raises: Problema."""
    eventi = _eventi(percorso)
    strumenti, chiamate = _strumenti(eventi, percorso)
    risultati = [e for e in eventi if e.get("type") == "result"]
    negati: List[object] = []
    for risultato in risultati:
        lista = risultato.get("permission_denials") or []
        if not isinstance(lista, list):
            raise Problema(f"{percorso}: «permission_denials» non è un elenco")
        negati.extend(lista)
    durata = sum(_conteggio(r, "duration_ms", percorso) for r in risultati)
    usage = sum(_token(r, percorso) for r in risultati)
    modelli = _token_modelli(risultati)
    return Esecuzione(
        percorso=percorso, init_skills=_skill_elencate(eventi),
        chiamate_skill=[skill for skill, _ in chiamate], strumenti=strumenti,
        testo=_testo_finale(risultati, percorso),
        turni=sum(_conteggio(r, "num_turns", percorso) for r in risultati),
        secondi=durata / 1000, duration_ms=durata,
        token_totali=usage if modelli is None else int(modelli),
        segmenti=len(risultati), negati=negati,
        errore=any(bool(r.get("is_error"))
                   or str(r.get("subtype", "")).startswith("error")
                   for r in risultati),
        completa=bool(risultati), chiamate_negate=_negate(chiamate, negati),
        chiamate_respinte=_respinte(eventi, chiamate, negati),
        token_usage=usage, token_modelli=modelli,
        locale=any("local_command" in r for r in risultati))


def file_cambiati(esec: Esecuzione) -> List[str]:
    """Le righe di outputs/file-cambiati.txt. Raises: Problema."""
    percorso = os.path.join(esec.cartella, "file-cambiati.txt")
    try:
        with open(percorso, encoding="utf-8") as fh:
            return [riga.rstrip("\n") for riga in fh if riga.strip()]
    except (OSError, UnicodeDecodeError) as exc:
        raise Problema(f"non riesco a leggere {percorso}: {exc}") from exc


def timing(esec: Esecuzione) -> dict:
    """Il dict di timing.json. Raises: Problema, se non c'è un risultato."""
    if not esec.completa:
        raise Problema(f"{esec.percorso}: nessun risultato, nessun timing")
    return {"total_tokens": esec.token_totali, "duration_ms": esec.duration_ms}
