"""motore.py -- le capacità dell'assistenza di CiaspoLink sui dati di uno
scenario: ciò che risponde quando l'assistente del banco di prova chiama uno
strumento.

Le capacità sono fisse (CAPACITA) e leggono la «verità nascosta» dello
scenario; il modello non le vede mai per nome. Vede gli strumenti di un file
di definizioni (nome, descrizione, input_schema), e ogni strumento dice quale
capacità usa: con il campo «capacita», oppure, per i nomi del v0, con la
tabella NOMI_V0, oppure perché si chiama come la capacità. Così si possono
riscrivere le definizioni senza toccare il codice. Gli argomenti si cercano
per forma dentro tutti i valori che lo strumento riceve (un codice CL-…, una
linea LN-…, un'e-mail): una definizione nuova può chiamarli come vuole.

Libreria Python 3.8+, solo libreria standard, senza effetti: nessun file
scritto, nessuna rete. Il server (server/server_banco.py) la importa per le
capacità e le definizioni; prova.py per controllare strumenti.json prima di
ogni chiamata. Non si esegue.
"""
from __future__ import annotations

import copy
import json
import re
from pathlib import Path
from typing import Any, Dict, List, NamedTuple, Optional, Tuple


class Problema(Exception):
    """Una definizione o uno scenario che non si possono usare."""


CAPACITA = (
    "verifica_identita", "stato_linea", "guasti_in_corso", "cerca_kb",
    "cerca_cliente", "leggi_ticket", "apri_ticket", "aggiorna_ticket",
    "chiudi_ticket", "gestisci_ticket", "slot_disponibili",
    "prenota_intervento", "verifica_copertura", "leggi_fattura",
    "registra_accredito", "passa_a_operatore", "invia_sms",
)

NOMI_V0 = {
    "check_linea": "stato_linea", "cercaCliente": "cerca_cliente",
    "ticket": "gestisci_ticket", "chiudi_ticket": "chiudi_ticket",
    "prenota": "prenota_intervento", "copertura": "verifica_copertura",
    "accredito": "registra_accredito", "operatore": "passa_a_operatore",
    "kb_search": "cerca_kb", "invia_sms": "invia_sms",
}

_RE_NOME = re.compile(r"^[a-zA-Z0-9_-]{1,64}$")
_RE_CLIENTE = re.compile(r"\bCL-\d{6}\b", re.I)
_RE_LINEA = re.compile(r"\bLN-\d{6}\b", re.I)
_RE_TICKET = re.compile(r"\bTK-2026-\d{5}\b", re.I)
_RE_FATTURA = re.compile(r"\bFT-2026-\d{6}\b", re.I)
_RE_EMAIL = re.compile(r"[\w.+-]+@[\w.-]+\.\w+")
_RE_TELEFONO = re.compile(r"\+?\d[\d \-]{7,}\d")
_RE_PAROLA = re.compile(r"\w{4,}")
_RE_CIFRA = re.compile(r"\d")
# Parole troppo comuni per dire se una zona riguarda un indirizzo.
_PAROLE_ZONA_VUOTE = frozenset({
    "zona", "dintorni", "rete", "tutti", "clienti", "business", "radio",
    "connessione", "centralino", "cloud", "della", "dello",
})
_MAX_RISULTATI_KB = 5
_RISULTATI_KB = 3
_LUNGHEZZA_ESTRATTO = 1400


class Definizione(NamedTuple):
    """Uno strumento come lo vede il server."""
    nome: str
    descrizione: str
    schema: Dict[str, Any]
    capacita: str


def _capacita_di(voce: Dict[str, Any]) -> Optional[str]:
    """La capacità di una definizione, o None se non è collegata."""
    dichiarata = voce.get("capacita")
    if dichiarata is not None:
        return dichiarata if dichiarata in CAPACITA else None
    nome = voce.get("name", "")
    if nome in NOMI_V0:
        return NOMI_V0[nome]
    return nome if nome in CAPACITA else None


def _definizione(voce: Any, viste: set) -> Definizione:
    """Controlla una voce del file e ne fa una Definizione."""
    if not isinstance(voce, dict):
        raise Problema("ogni strumento dev'essere un oggetto JSON")
    nome = voce.get("name")
    if not isinstance(nome, str) or not _RE_NOME.match(nome):
        raise Problema(f"name non valido: {nome!r}")
    if nome in viste:
        raise Problema(f"strumento doppio: {nome}")
    viste.add(nome)
    if not isinstance(voce.get("description"), str):
        raise Problema(f"{nome}: manca description")
    schema = voce.get("input_schema")
    if not isinstance(schema, dict) or schema.get("type") != "object":
        raise Problema(f"{nome}: input_schema dev'essere un oggetto con "
                       "type: object")
    capacita = _capacita_di(voce)
    if capacita is None:
        raise Problema(f"{nome}: strumento non collegato; il campo «capacita» "
                       f"dev'essere una di queste: {', '.join(CAPACITA)}")
    return Definizione(nome, voce["description"], schema, capacita)


def carica_strumenti(percorso: Path) -> List[Definizione]:
    """Le definizioni di un strumenti.json. Solleva Problema."""
    try:
        dati = json.loads(percorso.read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError, ValueError) as exc:
        raise Problema(f"non riesco a leggere {percorso}: {exc}") from exc
    if not isinstance(dati, list) or not dati:
        raise Problema(f"{percorso}: serve una lista di strumenti")
    viste: set = set()
    return [_definizione(voce, viste) for voce in dati]


def _testi(valore: Any) -> List[str]:
    """Tutti i valori semplici dentro gli argomenti, come testo."""
    if isinstance(valore, dict):
        return [t for v in valore.values() for t in _testi(v)]
    if isinstance(valore, (list, tuple)):
        return [t for v in valore for t in _testi(v)]
    return [] if valore is None else [str(valore)]


def _unito(argomenti: Any) -> str:
    return " ".join(_testi(argomenti))


def _primo(argomenti: Any, regex: "re.Pattern[str]") -> Optional[str]:
    trovato = regex.search(_unito(argomenti))
    return trovato.group(0).upper() if trovato else None


def _cifre(testo: str) -> str:
    return "".join(c for c in testo if c.isdigit())


def _zona_copre(zona: str, indirizzo: str) -> bool:
    """Vero se la zona di un guasto riguarda quell'indirizzo."""
    if "tutti" in zona.lower():
        return True
    parole = {p.lower() for p in _RE_PAROLA.findall(zona)}
    return any(p in indirizzo.lower() for p in parole - _PAROLE_ZONA_VUOTE)


class Banco:
    """Le capacità sui dati di uno scenario. Lo stato che cambia è solo il
    contatore dei numeri assegnati: i dati non si toccano."""

    def __init__(self, scenario: Dict[str, Any], kb: Path) -> None:
        self._dati = scenario.get("verita_nascosta") or {}
        self._kb = kb
        self._contatore = 0

    def esegui(self, capacita: str, argomenti: Dict[str, Any]
               ) -> Tuple[Dict[str, Any], bool, str]:
        """(risultato, errore, capacità effettiva): gestisci_ticket, lo
        strumento unico del v0, si risolve nella capacità che ha usato."""
        if capacita == "gestisci_ticket":
            capacita = self._azione_ticket(argomenti)
        metodo = getattr(self, "_c_" + capacita, None) \
            if capacita in CAPACITA else None
        if metodo is None:
            return {"errore": f"capacità sconosciuta: {capacita}"}, True, \
                capacita
        risultato = metodo(argomenti)
        return risultato, "errore" in risultato, capacita

    def _nuovo(self) -> int:
        self._contatore += 1
        return self._contatore

    @staticmethod
    def _azione_ticket(argomenti: Dict[str, Any]) -> str:
        azione = str(argomenti.get("azione", "")).lower()
        if "chiud" in azione:
            return "chiudi_ticket"
        if "aggiorn" in azione or "modific" in azione:
            return "aggiorna_ticket"
        if "legg" in azione or "cerc" in azione:
            return "leggi_ticket"
        return "apri_ticket"

    def _c_verifica_identita(self, a: Dict[str, Any]) -> Dict[str, Any]:
        cliente = self._dati.get("cliente") or {}
        codice = _primo(a, _RE_CLIENTE)
        testo = _unito(a)
        registrati = list((cliente.get("recapiti_registrati") or {}).values())
        email = {m.lower() for m in _RE_EMAIL.findall(testo)}
        telefoni = {_cifre(t) for t in _RE_TELEFONO.findall(testo)}
        recapito_ok = any(r.lower() in email or _cifre(r) in telefoni
                          for r in registrati)
        if not cliente or codice != cliente.get("id_cliente") \
                or not recapito_ok:
            return {"esito": "non riconosciuto"}
        return {"esito": "riconosciuto", "id_cliente": codice,
                "nome": cliente.get("nome"), "tipo": cliente.get("tipo"),
                "linee": [li["id_linea"]
                          for li in self._dati.get("linee", [])]}

    def _linea(self, a: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        linee = self._dati.get("linee", [])
        codice = _primo(a, _RE_LINEA)
        if codice:
            return next((li for li in linee if li["id_linea"] == codice), None)
        cliente = _primo(a, _RE_CLIENTE)
        if cliente and cliente == (self._dati.get("cliente") or {}) \
                .get("id_cliente") and linee:
            return linee[0]
        testo = _unito(a).lower()
        for linea in linee:
            via = linea.get("indirizzo", "").split(",")[0].lower()
            if via and via in testo:
                return linea
        return None

    def _c_stato_linea(self, a: Dict[str, Any]) -> Dict[str, Any]:
        linea = self._linea(a)
        if linea is None:
            return {"errore": "linea non trovata: serve il codice LN-000000"}
        risultato = copy.deepcopy(linea)
        indirizzo = linea.get("indirizzo", "")
        for chiave, elenco in (("guasto_collettivo", "guasti_in_corso"),
                               ("manutenzione", "manutenzioni")):
            for voce in self._dati.get(elenco, []):
                if _zona_copre(voce.get("zona", ""), indirizzo):
                    risultato[chiave] = copy.deepcopy(voce)
                    break
        return risultato

    def _c_guasti_in_corso(self, a: Dict[str, Any]) -> Dict[str, Any]:
        testo = _unito(a).lower()
        guasti = self._dati.get("guasti_in_corso", [])
        if testo.strip():
            guasti = [g for g in guasti
                      if any(p in g.get("zona", "").lower()
                             for p in _RE_PAROLA.findall(testo))
                      or "tutti" in g.get("zona", "").lower()]
        return {"guasti": copy.deepcopy(guasti)}

    def _procedure(self) -> List[Tuple[str, str, str]]:
        procedure = []
        for percorso in sorted(self._kb.glob("kb-*.md")):
            testo = percorso.read_text(encoding="utf-8")
            prima = testo.splitlines()[0] if testo else ""
            procedure.append((percorso.name[:5].upper(),
                              prima.lstrip("# ").strip(), testo))
        return procedure

    def _c_cerca_kb(self, a: Dict[str, Any]) -> Dict[str, Any]:
        numeri = [v for v in a.values()
                  if isinstance(v, int) and not isinstance(v, bool)]
        quanti = min(numeri[0], _MAX_RISULTATI_KB) if numeri else _RISULTATI_KB
        parole = {p.lower() for t in _testi(a)
                  for p in _RE_PAROLA.findall(t) if not t.isdigit()}
        punteggi = []
        for codice, titolo, testo in self._procedure():
            minuscolo = testo.lower()
            punti = sum(minuscolo.count(p) for p in parole)
            if punti:
                punteggi.append((punti, codice, titolo, testo))
        punteggi.sort(key=lambda v: (-v[0], v[1]))
        return {"risultati": [
            {"id": c, "titolo": t, "estratto": x[:_LUNGHEZZA_ESTRATTO]}
            for _, c, t, x in punteggi[:max(quanti, 1)]]}

    def _c_cerca_cliente(self, a: Dict[str, Any]) -> Dict[str, Any]:
        cliente = self._dati.get("cliente")
        if not cliente:
            return {"risultati": []}
        testo = _unito(a).lower().strip()
        bersaglio = json.dumps([cliente, self._dati.get("linee", [])],
                               ensure_ascii=False).lower()
        if not testo or testo not in bersaglio:
            return {"risultati": []}
        coda = cliente.get("id_cliente", "")[-4:]
        return {"cliente": copy.deepcopy(cliente),
                "linee": copy.deepcopy(self._dati.get("linee", [])),
                "fatture": copy.deepcopy(self._dati.get("fatture", [])),
                "credenziali": {"password_area_clienti": f"demo-{coda}"},
                "note_interne": "scheda completa, come la restituisce il v0"}

    def _c_leggi_ticket(self, a: Dict[str, Any]) -> Dict[str, Any]:
        ticket = self._dati.get("ticket", [])
        codice = _primo(a, _RE_TICKET)
        if codice:
            ticket = [t for t in ticket if t.get("id_ticket") == codice]
            if not ticket:
                return {"errore": f"segnalazione non trovata: {codice}"}
        return {"ticket": copy.deepcopy(ticket)}

    def _c_apri_ticket(self, a: Dict[str, Any]) -> Dict[str, Any]:
        numero = f"TK-2026-{9000 + self._nuovo():05d}"
        return {"id_ticket": numero, "stato": "aperto"}

    def _c_aggiorna_ticket(self, a: Dict[str, Any]) -> Dict[str, Any]:
        codice = _primo(a, _RE_TICKET)
        if not codice:
            return {"errore": "serve il numero della segnalazione"}
        return {"id_ticket": codice, "stato": "in lavorazione"}

    def _c_chiudi_ticket(self, a: Dict[str, Any]) -> Dict[str, Any]:
        codice = _primo(a, _RE_TICKET)
        if not codice:
            return {"errore": "serve il numero della segnalazione"}
        return {"id_ticket": codice, "stato": "chiuso"}

    def _c_slot_disponibili(self, a: Dict[str, Any]) -> Dict[str, Any]:
        return {"fasce": copy.deepcopy(self._dati.get("slot_intervento", []))}

    def _c_prenota_intervento(self, a: Dict[str, Any]) -> Dict[str, Any]:
        testo = _unito(a)
        for fascia in self._dati.get("slot_intervento", []):
            if fascia.get("inizio", "\0") in testo:
                return {"esito": "prenotato",
                        "id_appuntamento": f"AT-2026-{9000 + self._nuovo()}",
                        "fascia": copy.deepcopy(fascia)}
        return {"errore": "fascia non disponibile: controllare le fasce "
                          "libere e passare l'inizio esatto"}

    def _c_verifica_copertura(self, a: Dict[str, Any]) -> Dict[str, Any]:
        copertura = self._dati.get("copertura")
        if not copertura:
            return {"errore": "indirizzo non trovato"}
        testo = _unito(a).lower()
        if not _RE_CIFRA.search(testo):
            return {"errore": "manca il civico: serve via, civico e comune"}
        strada = copertura.get("indirizzo", "").split(",")[0]
        nome_via = _RE_CIFRA.sub("", strada).strip().lower()
        if nome_via not in testo:
            return {"errore": "indirizzo non trovato"}
        return copy.deepcopy(copertura)

    def _c_leggi_fattura(self, a: Dict[str, Any]) -> Dict[str, Any]:
        codice = _primo(a, _RE_FATTURA)
        for fattura in self._dati.get("fatture", []):
            if fattura.get("id_fattura") == codice:
                return copy.deepcopy(fattura)
        return {"errore": "fattura non trovata"}

    def _c_registra_accredito(self, a: Dict[str, Any]) -> Dict[str, Any]:
        return {"registrato": True}

    def _c_passa_a_operatore(self, a: Dict[str, Any]) -> Dict[str, Any]:
        aperti = (self._dati.get("operatori") or {}).get("aperti", True)
        return {"esito": "presa in carico",
                "modalita": "in diretta" if aperti
                else "richiamata all'apertura"}

    def _c_invia_sms(self, a: Dict[str, Any]) -> Dict[str, Any]:
        return {"inviato": True}
