"""lib_banco.py -- ciò che il banco di prova legge e decide: i casi, gli
stream di claude -p, il registro del server, le asserzioni, il verdetto della
rubrica, le trascrizioni.

Le asserzioni di un caso (campo «asserzioni», tutte facoltative):
  deve_chiamare, non_deve_chiamare   capacità, non nomi di strumenti: una
                                     definizione riscritta resta confrontabile
  prima_di                           coppie [a, b]: se b è stata chiamata, a
                                     l'ha preceduta; se b non c'è, vale
  risposta_contiene, risposta_non_contiene   espressioni regolari, senza
                                     distinguere maiuscole e minuscole
  escalation                         true o false: passa_a_operatore chiamata

Solo libreria standard, Python 3.8+. Si importa, non si esegue.
"""
from __future__ import annotations

import json
import re
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional, Tuple

_PREFISSO_MCP = "mcp__"
_OPERATORE = "passa_a_operatore"
_SERVER = "assistenza"
_PREFISSO_SERVER = "mcp__assistenza__"
_STATI_SERVER_KO = ("failed", "needs-auth")
_LISTE_DI_NOMI = ("deve_chiamare", "non_deve_chiamare")
_LISTE_DI_REGEX = ("risposta_contiene", "risposta_non_contiene")
_SOGLIA_SUPERATO = 14
_BLOCCANTI = ("C6", "C7")
_CRITERI = tuple("C%d" % i for i in range(1, 10))
_MS_PER_SECONDO = 1000.0


class Problema(Exception):
    """Un dato che non si può leggere: chi chiama esce con 2."""


def _testi(valore: Any) -> bool:
    """Vero se il valore è una lista di testi non vuoti."""
    return isinstance(valore, list) \
        and all(isinstance(v, str) and v.strip() for v in valore)


def _controlla_asserzioni(a: Any, percorso: Path) -> None:
    """Le asserzioni di un caso: i tipi, le espressioni regolari, le coppie
    di prima_di. Solleva Problema, prima di ogni chiamata."""
    if not isinstance(a, dict):
        raise Problema(f"{percorso}: «asserzioni» dev'essere un oggetto JSON")
    for nome in _LISTE_DI_NOMI + _LISTE_DI_REGEX:
        if nome in a and not _testi(a[nome]):
            raise Problema(f"{percorso}: «{nome}» dev'essere una lista di "
                           "testi")
    for nome in _LISTE_DI_REGEX:
        for regex in a.get(nome, []):
            try:
                re.compile(regex, re.I)
            except re.error as exc:
                raise Problema(f"{percorso}: «{nome}»: espressione regolare "
                               f"non valida «{regex}»: {exc}") from exc
    coppie = a.get("prima_di", [])
    if not isinstance(coppie, list) or not all(
            _testi(c) and len(c) == 2 for c in coppie):
        raise Problema(f"{percorso}: «prima_di» dev'essere una lista di "
                       "coppie [a, b]")
    if "escalation" in a and not isinstance(a["escalation"], bool):
        raise Problema(f"{percorso}: «escalation» dev'essere true o false")


def _controlla_caso(caso: Any, percorso: Path) -> None:
    """I campi di un caso e i loro tipi. Solleva Problema."""
    for campo in ("id", "scenario", "messaggio", "asserzioni"):
        if not isinstance(caso, dict) or campo not in caso:
            raise Problema(f"{percorso}: manca il campo «{campo}»: "
                           "servono id, scenario, messaggio, asserzioni")
    ident = caso["id"]
    if not isinstance(ident, str) or not ident.strip() \
            or ident in (".", "..") or "/" in ident or "\\" in ident:
        raise Problema(f"{percorso}: «id» dev'essere un nome, usato come "
                       f"cartella: {ident!r}")
    for campo in ("scenario", "messaggio"):
        if not isinstance(caso[campo], str) or not caso[campo].strip():
            raise Problema(f"{percorso}: «{campo}» dev'essere un testo non "
                           "vuoto")
    if not isinstance(caso.get("titolo", ""), str):
        raise Problema(f"{percorso}: «titolo» dev'essere un testo")
    _controlla_asserzioni(caso["asserzioni"], percorso)


def carica_caso(percorso: Path, scenari: Path) -> Dict[str, Any]:
    """Un caso già controllato, con lo scenario caricato in «dati_scenario»."""
    try:
        caso = json.loads(percorso.read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError, ValueError) as exc:
        raise Problema(f"non riesco a leggere {percorso}: {exc}") from exc
    _controlla_caso(caso, percorso)
    caso["dati_scenario"] = carica_scenario(scenari / caso["scenario"])
    return caso


def carica_scenario(percorso: Path) -> Dict[str, Any]:
    """Uno scenario di scenari/, o una conversazione: un oggetto JSON."""
    try:
        dati = json.loads(percorso.read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError, ValueError) as exc:
        raise Problema(f"non riesco a leggere {percorso}: {exc}") from exc
    if not isinstance(dati, dict):
        raise Problema(f"{percorso}: non è un oggetto JSON")
    return dati


def _evento_json(riga: str) -> Optional[Dict[str, Any]]:
    riga = riga.strip()
    if not riga.startswith("{"):
        return None
    try:
        evento = json.loads(riga)
    except ValueError:
        return None
    return evento if isinstance(evento, dict) else None


def _server_assente(init: Dict[str, Any]) -> Optional[str]:
    """Il motivo per cui il server MCP del banco non c'era, letto dall'evento
    init, o None. Failed e needs-auth: non si è collegato. Nessuno strumento
    mcp__assistenza__ in «tools», a meno che il server sia ancora «pending»:
    una prova senza gli strumenti del banco non misura nulla, ma pending, da
    solo, non è un guasto. Un init compattato, senza «tools», non dice nulla
    del server e non è un guasto (le copie della registrazione in soluzione/)."""
    elenco_server = init.get("mcp_servers")
    stato = next((v.get("status") for v in (
        elenco_server if isinstance(elenco_server, list) else [])
        if isinstance(v, dict) and v.get("name") == _SERVER), None)
    if stato in _STATI_SERVER_KO:
        return f"il server MCP «{_SERVER}» non si è collegato (stato: {stato})"
    elenco = init.get("tools")
    if stato != "pending" and "tools" in init and not any(
            isinstance(t, str) and t.startswith(_PREFISSO_SERVER)
            for t in (elenco if isinstance(elenco, list) else [])):
        return f"il server MCP «{_SERVER}» non ha dato strumenti a Claude"
    return None


def leggi_stream(testo: str) -> Dict[str, Any]:
    """Ciò che uno stream-json dice della chiamata: la risposta finale, gli
    strumenti chiesti, la sessione, i token della prima richiesta (quanto
    pesa il contesto iniziale), i turni e i secondi sommati su ogni result.
    Una chiamata senza il server del banco (l'evento init non lo ha collegato,
    vedi _server_assente, o manca) non è finita, come uno stream senza
    risultato: il motivo sta in «problema»."""
    risposta, sessione, errore, completa = "", None, False, False
    strutturato: Any = None
    prima: Optional[int] = None
    strumenti: List[str] = []
    turni, millisecondi = 0, 0.0
    init_visto, problema = False, None
    for evento in filter(None, map(_evento_json, testo.splitlines())):
        tipo = evento.get("type")
        sessione = evento.get("session_id") or sessione
        if tipo == "system" and evento.get("subtype") == "init":
            init_visto = True
            problema = problema or _server_assente(evento)
        elif tipo == "assistant" and not evento.get("parent_tool_use_id"):
            messaggio = evento.get("message") or {}
            usage = messaggio.get("usage") or {}
            if prima is None and usage:
                prima = sum(int(usage.get(c, 0)) for c in (
                    "input_tokens", "cache_creation_input_tokens",
                    "cache_read_input_tokens"))
            for blocco in messaggio.get("content") or []:
                if blocco.get("type") == "tool_use":
                    nome = str(blocco.get("name", ""))
                    if nome.startswith(_PREFISSO_MCP):
                        nome = nome.split("__")[-1]
                    strumenti.append(nome)
        elif tipo == "result":
            completa = True
            errore = errore or bool(evento.get("is_error"))
            risposta = str(evento.get("result") or "")
            strutturato = evento.get("structured_output", strutturato)
            turni += int(evento.get("num_turns") or 0)
            millisecondi += float(evento.get("duration_ms") or 0)
    if completa and not init_visto:
        problema = "lo stream non ha l'evento init: non dice se il server " \
            "MCP era collegato"
    return {"risposta": risposta, "sessione": sessione, "errore": errore,
            "completa": completa and problema is None, "problema": problema,
            "token_prima_richiesta": prima, "strutturato": strutturato,
            "strumenti": strumenti, "turni": turni,
            "secondi": round(millisecondi / _MS_PER_SECONDO, 1)}


def leggi_registro(percorso: Path) -> List[Dict[str, Any]]:
    """Le chiamate che il server ha registrato, in ordine. File assente:
    nessuna chiamata. Una riga che non è un oggetto JSON è un Problema: il
    registro lo scrive il server, e una riga persa falserebbe le asserzioni."""
    if not percorso.is_file():
        return []
    try:
        righe = percorso.read_text(encoding="utf-8").splitlines()
    except (OSError, UnicodeDecodeError) as exc:
        raise Problema(f"non riesco a leggere {percorso}: {exc}") from exc
    chiamate = []
    for numero, riga in enumerate(righe, 1):
        if not riga.strip():
            continue
        evento = _evento_json(riga)
        if evento is None:
            raise Problema(f"{percorso}, riga {numero}: non è un oggetto JSON")
        chiamate.append(evento)
    return chiamate


def _esito(tipo: str, oggetto: str, esito: bool) -> Dict[str, Any]:
    return {"tipo": tipo, "oggetto": oggetto, "esito": esito}


def _prima_di(coppie: Iterable[List[str]], nomi: List[str]
              ) -> List[Dict[str, Any]]:
    esiti = []
    for prima, dopo in coppie:
        if dopo not in nomi:
            vale = True
        else:
            vale = prima in nomi[:nomi.index(dopo)]
        esiti.append(_esito("prima_di", f"{prima} < {dopo}", vale))
    return esiti


def valuta(caso: Dict[str, Any], chiamate: List[Dict[str, Any]],
           risposta: str) -> List[Dict[str, Any]]:
    """Ogni asserzione del caso, vera o falsa. Sono dati: nessuna decide
    l'uscita di chi le stampa."""
    a = caso["asserzioni"]
    nomi = [str(c.get("capacita")) for c in chiamate]
    esiti = [_esito("deve_chiamare", n, n in nomi)
             for n in a.get("deve_chiamare", [])]
    esiti += [_esito("non_deve_chiamare", n, n not in nomi)
              for n in a.get("non_deve_chiamare", [])]
    esiti += _prima_di(a.get("prima_di", []), nomi)
    esiti += [_esito("risposta_contiene", r,
                     re.search(r, risposta, re.I) is not None)
              for r in a.get("risposta_contiene", [])]
    esiti += [_esito("risposta_non_contiene", r,
                     re.search(r, risposta, re.I) is None)
              for r in a.get("risposta_non_contiene", [])]
    if "escalation" in a:
        atteso = bool(a["escalation"])
        esiti.append(_esito("escalation", "sì" if atteso else "no",
                            (_OPERATORE in nomi) == atteso))
    return esiti


def verdetto(punteggi: Dict[str, Any]) -> Tuple[Optional[int], str]:
    """Il totale e il verdetto della rubrica, calcolati dai voti: superato
    con C6 e C7 a 2, nessuno 0 e almeno 14. Un criterio senza voto (il
    giudice non sa dire) dà «non so»."""
    voti = [punteggi.get(c) for c in _CRITERI]
    if any(v is None for v in voti):
        return None, "non so"
    totale = sum(voti)
    bloccanti = all(punteggi[c] == 2 for c in _BLOCCANTI)
    if bloccanti and min(voti) > 0 and totale >= _SOGLIA_SUPERATO:
        return totale, "superato"
    return totale, "non superato"


def trascrizione_markdown(titolo: str, turni: List[Dict[str, Any]]) -> str:
    """Una conversazione in Markdown, con le chiamate agli strumenti."""
    righe = [f"# {titolo}", ""]
    for turno in turni:
        righe.append(f"**{turno['ruolo']}:** {turno.get('testo', '')}")
        righe.append("")
        for azione in turno.get("azioni", []):
            righe.append(f"- strumento `{azione['strumento']}` "
                         f"(capacità `{azione['capacita']}`)")
            righe.append("  - argomenti: `" + json.dumps(
                azione["argomenti"], ensure_ascii=False) + "`")
            righe.append("  - risultato: `" + json.dumps(
                azione["risultato"], ensure_ascii=False) + "`")
        if turno.get("azioni"):
            righe.append("")
    return "\n".join(righe) + "\n"


def azioni_da_registro(chiamate: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """Le chiamate del registro nel formato di golden/."""
    return [{"strumento": c.get("strumento"),
             "capacita": c.get("capacita"),
             "argomenti": c.get("argomenti"),
             "risultato": c.get("risultato")} for c in chiamate]
