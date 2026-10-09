"""Le verifiche di struttura del materiale dell'assistenza clienti.

genera.py le esegue con `--verifica`: scenari, conversazioni di riferimento,
strumenti del v0, base di conoscenza, istruzioni del v0 e settimana di ticket
(colonne, numero di righe, picchi dei guasti, clienti della storia). Ogni
funzione restituisce l'elenco dei problemi trovati; un file illeggibile o un
JSON non valido solleva ValueError (o OSError) e il comando esce con 2.
"""

import csv
import json
from pathlib import Path
from typing import Callable, Dict, List, Sequence, Tuple

from . import canone

CHIAVI_SCENARIO = ("id", "titolo", "ostile", "flag", "incidente", "momento",
                   "canale", "persona", "messaggio_iniziale", "seguiti",
                   "verita_nascosta", "esito_atteso", "escalation_attesa",
                   "motivo_escalation", "da_evitare", "kb", "ticket_csv")
CHIAVI_GOLDEN = ("id", "scenario", "titolo", "canale", "inizio", "turni",
                 "esito", "punti_chiave")
FLAG_OSTILI = ("prompt_injection", "dati_altrui", "ingegneria_sociale",
               "cliente_offensivo", "fuori_ambito", "falso_tecnico")
SEZIONI_KB = ("## Quando si usa", "## Passi guidati",
              "## Quando passare a un operatore", "## Che cosa dire")
INCIDENTI = (None, "pergine", "cles", "bng", "sbc", "dhcp")
CANALI = ("telefono", "e-mail", "chat", "portale")
MIN_SCENARI, MIN_OSTILI, MIN_GOLDEN, MIN_KB, MIN_STRUMENTI = 12, 4, 6, 12, 5
PAROLE_PROMPT = (1500, 2500)
RIGHE_CSV = (250, 450)
CLIENTI_STORIA = tuple("CL-0001%02d" % n for n in range(1, 7))

Riga = Dict[str, str]


def _ora(r: Riga) -> str:
    return r["aperto_il"][11:16]


def _giorno(r: Riga, giorno: int) -> bool:
    return r["aperto_il"].startswith("2026-09-%02d" % giorno)


# I picchi dei guasti: (nome, condizione su una riga, minimo atteso).
PICCHI: Tuple[Tuple[str, Callable[[Riga], bool], int], ...] = (
    ("fibra Pergine, martedì 10:12-12:30",
     lambda r: _giorno(r, 8) and "10:12" <= _ora(r) <= "12:30"
     and r["comune"].lower().startswith("pergine"), 20),
    ("radio Cles, mercoledì",
     lambda r: _giorno(r, 9) and r["tecnologia"] == "FWA", 10),
    ("manutenzione, giovedì 06-10",
     lambda r: _giorno(r, 10) and "06:00" <= _ora(r) < "10:00"
     and "manutenzione" in (r["oggetto"] + r["descrizione"]).lower(), 4),
    ("voce, venerdì 08:04-10:40",
     lambda r: _giorno(r, 11) and "08:04" <= _ora(r) <= "10:40"
     and r["tecnologia"] == "VoIP", 8),
    ("DHCP Rovereto, sabato",
     lambda r: _giorno(r, 12) and r["categoria"] == "rete_aziendale"
     and r["comune"].lower().startswith("rovereto"), 4),
)


def leggi_json(percorso: Path):
    try:
        return json.loads(percorso.read_text(encoding="utf-8"))
    except ValueError as errore:
        raise ValueError("%s: JSON non valido (%s)" % (percorso.name, errore))


def verifica_csv(percorso: Path, colonne: Sequence[str]
                 ) -> Tuple[List[str], List[Riga]]:
    """Colonne, numero di righe, picchi dei guasti, clienti della storia."""
    with percorso.open(encoding="utf-8", newline="") as f:
        lettore = csv.DictReader(f)
        righe = list(lettore)
        intestazione = tuple(lettore.fieldnames or ())
    problemi = []
    if intestazione != tuple(colonne):
        problemi.append("dati: le colonne del CSV non sono quelle attese")
        return problemi, righe
    if not RIGHE_CSV[0] <= len(righe) <= RIGHE_CSV[1]:
        problemi.append("dati: %d righe, fuori dall'intervallo %d-%d"
                        % (len(righe), RIGHE_CSV[0], RIGHE_CSV[1]))
    for nome, condizione, minimo in PICCHI:
        quante = sum(1 for r in righe if condizione(r))
        if quante < minimo:
            problemi.append("dati: picco «%s» assente (%d righe, almeno %d)"
                            % (nome, quante, minimo))
    presenti = {r["id_cliente"] for r in righe}
    problemi += ["dati: manca il cliente della storia %s" % c
                 for c in CLIENTI_STORIA if c not in presenti]
    return problemi, righe


def _verifica_uno_scenario(percorso: Path, s: dict, ticket: Dict[str, Riga],
                           kb: Sequence[str]) -> List[str]:
    nome = percorso.name
    mancanti = [k for k in CHIAVI_SCENARIO if k not in s]
    if mancanti:
        return ["%s: manca %s" % (nome, ", ".join(mancanti))]
    problemi = []
    if s["id"].lower() != nome[:5]:
        problemi.append("%s: l'id %s non corrisponde al file" % (nome, s["id"]))
    if s["incidente"] not in INCIDENTI or s["canale"] not in CANALI:
        problemi.append("%s: incidente o canale sconosciuto" % nome)
    if not canone.data_ammessa(str(s["momento"])[:10]):
        problemi.append("%s: momento fuori dalla settimana" % nome)
    problemi += ["%s: procedura %s inesistente" % (nome, k)
                 for k in s["kb"] if k not in kb]
    codice = s["ticket_csv"]
    if codice:
        cliente = (s["persona"].get("cliente") or {}).get("id_cliente", "")
        riga = ticket.get(codice)
        if riga is None or riga["id_cliente"] != cliente:
            problemi.append("%s: ticket %s assente dal CSV o di un altro "
                            "cliente" % (nome, codice))
    return problemi


def verifica_scenari(radice: Path, righe: Sequence[Riga]
                     ) -> Tuple[List[str], Dict[str, dict]]:
    """Ogni scenario e l'insieme: quanti, quanti ostili, quali attacchi."""
    ticket = {r["id_ticket"]: r for r in righe}
    kb = [p.name[:5].upper() for p in sorted((radice / "kb").glob("kb-*.md"))]
    problemi: List[str] = []
    scenari: Dict[str, dict] = {}
    for percorso in sorted((radice / "scenari").glob("sc-*.json")):
        s = leggi_json(percorso)
        problemi += _verifica_uno_scenario(percorso, s, ticket, kb)
        scenari[str(s.get("id"))] = s
    ostili = [s for s in scenari.values() if s.get("ostile") is True]
    if len(scenari) < MIN_SCENARI or len(ostili) < MIN_OSTILI:
        problemi.append("scenari: %d scenari e %d ostili (almeno %d e %d)"
                        % (len(scenari), len(ostili), MIN_SCENARI,
                           MIN_OSTILI))
    coperti = {f for s in ostili for f in s.get("flag", [])}
    problemi += ["scenari: nessuno scenario ostile con il flag %s" % f
                 for f in FLAG_OSTILI if f not in coperti]
    return problemi, scenari


def verifica_golden(radice: Path, scenari: Dict[str, dict]) -> List[str]:
    """Ogni conversazione di riferimento: chiavi, scenario, ticket, Markdown."""
    problemi = []
    sorgenti = sorted((radice / "golden").glob("gc-*.json"))
    for percorso in sorgenti:
        g = leggi_json(percorso)
        mancanti = [k for k in CHIAVI_GOLDEN if k not in g]
        if mancanti:
            problemi.append("%s: manca %s" % (percorso.name,
                                              ", ".join(mancanti)))
            continue
        s = scenari.get(g["scenario"])
        if s is None:
            problemi.append("%s: scenario %s inesistente" % (percorso.name,
                                                             g["scenario"]))
        elif (g["esito"] or {}).get("ticket") != s["ticket_csv"]:
            problemi.append("%s: ticket diverso da quello dello scenario"
                            % percorso.name)
        if not percorso.with_suffix(".md").is_file():
            problemi.append("%s: manca la versione Markdown" % percorso.name)
    if len(sorgenti) < MIN_GOLDEN:
        problemi.append("golden: %d conversazioni (almeno %d)"
                        % (len(sorgenti), MIN_GOLDEN))
    return problemi


def verifica_strumenti(radice: Path) -> List[str]:
    """v0/strumenti.json: un elenco di strumenti, ognuno con input_schema."""
    strumenti = leggi_json(radice / "v0" / "strumenti.json")
    if not isinstance(strumenti, list) or len(strumenti) < MIN_STRUMENTI:
        return ["strumenti: atteso un elenco di almeno %d strumenti"
                % MIN_STRUMENTI]
    problemi = []
    for posizione, s in enumerate(strumenti, start=1):
        if not isinstance(s, dict) or not all(
                isinstance(s.get(k), str) for k in ("name", "description")):
            problemi.append("strumenti: il n. %d non ha name e description"
                            % posizione)
            continue
        schema = s.get("input_schema")
        if not isinstance(schema, dict) or schema.get("type") != "object" \
                or not isinstance(schema.get("properties"), dict):
            problemi.append("strumenti: %s senza un input_schema di tipo "
                            "object con properties" % s["name"])
    return problemi


def verifica_testi(radice: Path) -> List[str]:
    """Le procedure della KB e la lunghezza delle istruzioni del v0."""
    problemi = []
    procedure = sorted((radice / "kb").glob("kb-*.md"))
    if len(procedure) < MIN_KB:
        problemi.append("kb: %d procedure (almeno %d)" % (len(procedure),
                                                          MIN_KB))
    for percorso in procedure:
        testo = percorso.read_text(encoding="utf-8")
        problemi += ["%s: manca la sezione «%s»" % (percorso.name, sezione)
                     for sezione in SEZIONI_KB if sezione not in testo]
    parole = len((radice / "v0" / "system-prompt.md").read_text(
        encoding="utf-8").split())
    if not PAROLE_PROMPT[0] <= parole <= PAROLE_PROMPT[1]:
        problemi.append("v0: le istruzioni hanno %d parole (attese %d-%d)"
                        % (parole, PAROLE_PROMPT[0], PAROLE_PROMPT[1]))
    return problemi


def verifica_tutto(radice: Path, file_csv: str, colonne: Sequence[str]
                   ) -> Tuple[List[str], str]:
    """Tutte le verifiche; restituisce i problemi e un riepilogo."""
    problemi, righe = verifica_csv(radice / file_csv, colonne)
    da_scenari, scenari = verifica_scenari(radice, righe)
    problemi += da_scenari + verifica_golden(radice, scenari)
    problemi += verifica_strumenti(radice) + verifica_testi(radice)
    ostili = sum(1 for s in scenari.values() if s.get("ostile") is True)
    golden = len(list((radice / "golden").glob("gc-*.json")))
    riepilogo = "%d ticket, %d scenari (%d ostili), %d conversazioni" % (
        len(righe), len(scenari), ostili, golden)
    return problemi, riepilogo
