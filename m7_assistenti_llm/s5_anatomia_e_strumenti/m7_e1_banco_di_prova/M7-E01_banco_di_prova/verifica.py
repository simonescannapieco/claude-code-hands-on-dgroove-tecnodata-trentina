"""verifica.py di M7-E01 «Il banco di prova».

Legge, nello spazio di lavoro, ciò che il partecipante ha fatto:
  conversazione/conversazione.json, trascrizione.md e, se l'assistente ha
      chiamato strumenti, registro.jsonl: la conversazione con la persona
      simulata, scritta da tools/prova_assistente.sh;
  note.md: le note del partecipante.

È fatta quando la conversazione c'è (almeno una risposta dell'assistente) e
note.md ha almeno tre voci, ognuna con il riferimento a ciò che si vede nella
trascrizione: un turno («turno 4», contato dall'inizio) che esiste, o il nome
di uno strumento dell'assistente (quelli di strumenti.json del v0 e quelli
chiamati). Una voce è una riga di elenco: comincia con «- », «* », «+ » o
«1. ». Il contenuto delle note è un dato: si stampa, e non decide l'uscita. La
verifica non giudica se le note colgono qualcosa.

Uso:    python3 -B -I verifica.py <spazio di lavoro>
Uscita: 0 = fatto · 1 = non ancora (dice che cosa manca) · 2 = precondizione
        (spazio di lavoro assente; un file che c'è e non si legge; un errore
        inatteso, mai un traceback)
"""
from __future__ import annotations

import json
import os
import re
import sys
from typing import Any, Dict, List, NamedTuple, Set, Tuple

USO = "Uso: python3 -B -I verifica.py <spazio di lavoro>\n"
CARTELLA = "conversazione"
CONVERSAZIONE = "conversazione.json"
TRASCRIZIONE = "trascrizione.md"
REGISTRO = "registro.jsonl"
NOTE = "note.md"
DEFINIZIONI_V0 = os.path.join("progetti", "assistenza-clienti", "v0",
                              "strumenti.json")
VOCI_MINIME = 3
ESTRATTO = 60
VOCE = re.compile(r"^\s*(?:[-*+]|\d+[.)])\s+(\S.*)$")
TURNO = re.compile(r"\bturn[oi]\s+(?:n\.?\s*)?(\d+)\b", re.IGNORECASE)


class Precondizione(Exception):
    """Un file che c'è e non si legge: uscita 2."""


class Turni(NamedTuple):
    """La conversazione: i messaggi e gli strumenti chiamati."""
    messaggi: List[Dict[str, Any]]
    scenario: str
    versione: str


def leggi_json(percorso: str) -> Any:
    """Un file JSON; Precondizione se non si legge."""
    try:
        with open(percorso, encoding="utf-8") as fh:
            return json.load(fh)
    except (OSError, UnicodeDecodeError, ValueError) as exc:
        raise Precondizione("%s non si legge: %s" % (percorso, exc)) from exc


def leggi_testo(percorso: str) -> str:
    """Un file di testo; Precondizione se non si legge."""
    try:
        with open(percorso, encoding="utf-8") as fh:
            return fh.read()
    except (OSError, UnicodeDecodeError) as exc:
        raise Precondizione("%s non si legge: %s" % (percorso, exc)) from exc


def carica_conversazione(ws: str, problemi: List[str]) -> Turni | None:
    """La conversazione; None (e un problema) se manca o è vuota."""
    cartella = os.path.join(ws, CARTELLA)
    percorso = os.path.join(cartella, CONVERSAZIONE)
    if not os.path.isfile(percorso):
        problemi.append("Manca la conversazione: %s/%s. Lanciate il passo "
                        "con tools/prova_assistente.sh." % (CARTELLA,
                                                            CONVERSAZIONE))
        return None
    dati = leggi_json(percorso)
    if not isinstance(dati, dict) or not isinstance(dati.get("turni"), list):
        raise Precondizione("%s non è una conversazione: manca «turni»"
                            % CONVERSAZIONE)
    messaggi = [t for t in dati["turni"] if isinstance(t, dict)]
    if not any(t.get("ruolo") == "assistente" for t in messaggi):
        problemi.append("La conversazione non ha nessuna risposta "
                        "dell'assistente: rilanciate tools/prova_assistente.sh.")
        return None
    if not os.path.isfile(os.path.join(cartella, TRASCRIZIONE)):
        problemi.append("Manca %s/%s." % (CARTELLA, TRASCRIZIONE))
        return None
    return Turni(messaggi, str(dati.get("scenario", "?")),
                 str(dati.get("versione", "?")))


def conta_registro(ws: str, turni: Turni, problemi: List[str]
                   ) -> List[Dict[str, str]]:
    """Le righe del registro (strumento e capacità); un problema se la
    conversazione ha chiamate e il registro no."""
    percorso = os.path.join(ws, CARTELLA, REGISTRO)
    azioni = sum(len(t.get("azioni") or []) for t in turni.messaggi)
    if not os.path.isfile(percorso):
        if azioni:
            problemi.append("Manca %s/%s: la conversazione ha %d chiamate "
                            "agli strumenti." % (CARTELLA, REGISTRO, azioni))
        else:
            print("(dato) nessuna chiamata agli strumenti: %s non c'è."
                  % REGISTRO)
        return []
    righe: List[Dict[str, str]] = []
    for riga in leggi_testo(percorso).splitlines():
        if not riga.strip():
            continue
        try:
            evento = json.loads(riga)
        except ValueError as exc:
            raise Precondizione("%s: una riga non è JSON" % REGISTRO) from exc
        if isinstance(evento, dict):
            righe.append({"strumento": str(evento.get("strumento", "")),
                          "capacita": str(evento.get("capacita") or "")})
    return righe


def strumenti_noti(ws: str, turni: Turni, registro: List[Dict[str, str]]
                   ) -> Set[str]:
    """I nomi che valgono come citazione di uno strumento."""
    noti = {r[k] for r in registro for k in ("strumento", "capacita") if r[k]}
    for turno in turni.messaggi:
        for azione in turno.get("azioni") or []:
            if isinstance(azione, dict):
                noti.update(str(azione.get(k, ""))
                            for k in ("strumento", "capacita"))
    percorso = os.path.join(ws, DEFINIZIONI_V0)
    if os.path.isfile(percorso):
        dati = leggi_json(percorso)
        if isinstance(dati, list):
            noti.update(str(d.get("name", "")) for d in dati
                        if isinstance(d, dict))
    return {n for n in noti if n}


def voci_di(testo: str) -> List[str]:
    """Le righe di elenco di note.md, fuori dai commenti HTML."""
    senza_commenti = re.sub(r"<!--.*?-->", "", testo, flags=re.DOTALL)
    voci = []
    for riga in senza_commenti.splitlines():
        trovato = VOCE.match(riga)
        if trovato:
            voci.append(trovato.group(1).strip())
    return voci


def citazioni(voce: str, turni: Turni, noti: Set[str]
              ) -> Tuple[List[str], List[str]]:
    """(riferimenti validi, turni citati che non esistono) di una voce."""
    validi: List[str] = []
    fuori: List[str] = []
    numero_messaggi = len(turni.messaggi)
    for numero in TURNO.findall(voce):
        n = int(numero)
        if 1 <= n <= numero_messaggi:
            ruolo = str(turni.messaggi[n - 1].get("ruolo", "?"))
            validi.append("turno %d (%s)" % (n, ruolo))
        else:
            fuori.append(numero)
    for nome in sorted(noti):
        if re.search(r"(?<![A-Za-z0-9_])" + re.escape(nome)
                     + r"(?![A-Za-z0-9_])", voce, re.IGNORECASE):
            validi.append("lo strumento %s" % nome)
    return list(dict.fromkeys(validi)), fuori


def controlla_note(ws: str, turni: Turni, noti: Set[str],
                   problemi: List[str]) -> None:
    """Le voci di note.md: stampa che cosa cita ciascuna (dato) e aggiunge
    un problema se quelle con un riferimento sono meno di tre."""
    percorso = os.path.join(ws, NOTE)
    if not os.path.isfile(percorso):
        problemi.append("Manca %s: scrivetela nello spazio di lavoro." % NOTE)
        return
    voci = voci_di(leggi_testo(percorso))
    buone = 0
    print("%s: %d %s." % (NOTE, len(voci),
                          "voce" if len(voci) == 1 else "voci"))
    for i, voce in enumerate(voci, 1):
        validi, fuori = citazioni(voce, turni, noti)
        estratto = voce[:ESTRATTO] + ("…" if len(voce) > ESTRATTO else "")
        if validi:
            buone += 1
            print("  voce %d: cita %s: «%s»" % (i, ", ".join(validi),
                                                estratto))
        elif fuori:
            print("  voce %d: cita il turno %s, che non c'è (la conversazione "
                  "ha %d messaggi): «%s»" % (i, ", ".join(fuori),
                                             len(turni.messaggi), estratto))
        else:
            print("  voce %d: nessun turno né strumento citato: «%s»"
                  % (i, estratto))
    if buone < VOCI_MINIME:
        problemi.append("%s: %d %s con un turno o uno strumento: ne servono "
                        "almeno %d." % (NOTE, buone,
                                        "voce" if buone == 1 else "voci",
                                        VOCI_MINIME))


def controlla(ws: str) -> int:
    """Tutti i controlli; l'uscita."""
    problemi: List[str] = []
    turni = carica_conversazione(ws, problemi)
    if turni is None:
        return esito(problemi)
    giri = sum(1 for t in turni.messaggi if t.get("ruolo") == "assistente")
    print("La conversazione: scenario %s, versione %s, %d messaggi, %d giri."
          % (turni.scenario, turni.versione, len(turni.messaggi), giri))
    registro = conta_registro(ws, turni, problemi)
    chiamati = sorted({r["strumento"] for r in registro if r["strumento"]})
    print("(dato) le chiamate agli strumenti nel registro: %d%s"
          % (len(registro), (": " + ", ".join(chiamati)) if chiamati else ""))
    if problemi:
        return esito(problemi)
    controlla_note(ws, turni, strumenti_noti(ws, turni, registro), problemi)
    return esito(problemi)


def esito(problemi: List[str]) -> int:
    """Stampa i problemi e dice l'uscita."""
    for riga in problemi:
        print(riga)
    if problemi:
        return 1
    print("Fatto: la conversazione c'è e le note citano ciò che si vede "
          "nella trascrizione.")
    return 0


def main(argv: List[str]) -> int:
    if len(argv) != 1:
        sys.stderr.write(USO)
        return 2
    ws = argv[0]
    if not os.path.isdir(ws):
        sys.stderr.write("verifica: spazio di lavoro assente: %s\n" % ws)
        return 2
    try:
        return controlla(ws)
    except Precondizione as exc:
        sys.stderr.write("verifica: %s\n" % exc)
        return 2


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv[1:]))
    except SystemExit:
        raise
    except BaseException as exc:  # una riga, mai un traceback
        sys.stderr.write("verifica: errore inatteso: %s\n"
                         % type(exc).__name__)
        sys.exit(2)
