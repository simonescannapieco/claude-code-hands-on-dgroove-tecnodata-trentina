#!/usr/bin/env python3
"""Generatore deterministico dei dati dell'assistenza clienti di CiaspoLink.

Produce, per la settimana sintetica da lunedì 2026-09-07 a domenica 2026-09-13:
- dati/ticket-settimana.csv, una settimana di ticket di assistenza;
- golden/gc-*.md, la versione leggibile di ogni conversazione di riferimento
  golden/gc-*.json (la fonte è il JSON: il Markdown si rigenera).

Uso, da qualunque cartella:
  python3 genera.py            rigenera i file
  python3 genera.py --check    rigenera in una cartella temporanea e confronta
                               byte per byte (uscita 0 identici, 1 diversi,
                               2 errore)
  python3 genera.py --canone   controlla il canone dei dati sintetici
                               (progetti/README.md) su ogni file di testo di
                               questa cartella (uscita 0 rispettato,
                               1 violazioni, 2 errore)
  python3 genera.py --verifica controlla la struttura di scenari,
                               conversazioni, strumenti, procedure e dati
                               (uscita 0 corretta, 1 problemi, 2 errore)

Python 3.8 o successivo, solo libreria standard; le parti stanno in
generatore/. Lo stesso codice dà gli stessi byte su ogni versione dalla 3.8
alla 3.14: seme fisso, generatore pseudo-casuale usato solo attraverso
random(), niente hash() di stringhe, ordine di scrittura sempre esplicito.
"""

import csv
import datetime as dt
import io
import json
import sys
import tempfile
from pathlib import Path
from typing import Dict, List, Sequence, Tuple

QUI = Path(__file__).resolve().parent
sys.dont_write_bytecode = True  # nessuna cartella __pycache__ nel progetto
if str(QUI) not in sys.path:
    sys.path.insert(0, str(QUI))
from generatore import canone, testi, verifiche  # noqa: E402
from generatore.clienti import (CLIENTI_CONDIVISI, LINEE_CONDIVISE,  # noqa: E402
                                PRIMO_DEL_PROGETTO, ULTIMO_DEL_PROGETTO)
from generatore.settimana import SEME, Caso, minuti_tra  # noqa: E402
from generatore.ticket import Ticket, tutti_i_ticket  # noqa: E402

PRIMO_TICKET = 4213
TICKET_DEL_PROGETTO = range(4000, 5000)  # i ticket del gestionale: 1-999
FILE_CSV = "dati/ticket-settimana.csv"
CARTELLA_GOLDEN = "golden"
ESTENSIONI_TESTO = (".md", ".json", ".jsonl", ".csv", ".tsv", ".txt",
                    ".yaml", ".yml")
COLONNE = ("id_ticket", "aperto_il", "chiuso_il", "canale", "id_cliente",
           "tipo_cliente", "nome_cliente", "telefono", "email", "comune",
           "id_linea", "tecnologia", "categoria", "priorita", "stato",
           "oggetto", "descrizione", "team", "minuti_prima_risposta",
           "minuti_risoluzione", "soddisfazione")
CHIAVI_GOLDEN = verifiche.CHIAVI_GOLDEN
OPZIONI = ("--check", "--canone", "--verifica")
USO = "uso: python3 genera.py [--check | --canone | --verifica]"


# --- Scrittura e verifica del CSV ---------------------------------------------

def _campo_csv(valore: str) -> str:
    if any(c in valore for c in ',"\n\r') or valore != valore.strip():
        return '"' + valore.replace('"', '""') + '"'
    return valore


def riga_csv(numero: int, t: Ticket) -> Tuple[str, ...]:
    minuti = str(minuti_tra(t.aperto, t.chiuso)) if t.chiuso else ""
    return ("TK-2026-%05d" % numero, t.aperto.isoformat(),
            t.chiuso.isoformat() if t.chiuso else "", t.canale,
            t.cliente.id_cliente, t.cliente.tipo, t.nome, t.telefono, t.email,
            t.comune, t.cliente.id_linea, t.tecnologia, t.categoria,
            t.priorita, t.stato, t.oggetto, t.descrizione, t.team,
            "" if t.prima_risposta is None else str(t.prima_risposta), minuti,
            "" if t.soddisfazione is None else str(t.soddisfazione))


def testo_csv(ticket: Sequence[Ticket]) -> str:
    righe = [COLONNE] + [riga_csv(PRIMO_TICKET + i, t)
                         for i, t in enumerate(ticket)]
    return "".join(",".join(_campo_csv(v) for v in r) + "\n" for r in righe)


def nel_proprio_intervallo(campo: str, valore: str) -> bool:
    """Vero se il codice sta negli intervalli assegnati a questo progetto."""
    numero = int(valore.rsplit("-", 1)[1])
    if campo == "id_ticket":
        return numero in TICKET_DEL_PROGETTO
    condivisi = CLIENTI_CONDIVISI if campo == "id_cliente" else LINEE_CONDIVISE
    return numero in condivisi or \
        PRIMO_DEL_PROGETTO <= numero <= ULTIMO_DEL_PROGETTO


def verifica_riga(r: Dict[str, str]) -> List[str]:
    """Il canone e la coerenza interna di una riga del CSV generato."""
    errori = []
    if r["tipo_cliente"] == "privato":
        problema = canone.controlla_persona(r["nome_cliente"],
                                            testi.NOMI_AMMESSI)
    else:
        problema = canone.controlla_azienda(r["nome_cliente"])
    errori += [problema] if problema else []
    if r["telefono"] and not canone.telefono_ammesso(r["telefono"]):
        errori.append("telefono fuori canone")
    if r["email"] and not canone.email_ammessa(r["email"]):
        errori.append("e-mail fuori canone")
    if r["comune"] not in testi.COMUNI_AMMESSI:
        errori.append("comune fuori elenco")
    for campo in ("id_ticket", "id_cliente", "id_linea"):
        if r[campo] and not canone.id_ammesso(r[campo]):
            errori.append("%s fuori formato" % campo)
        elif r[campo] and not nel_proprio_intervallo(campo, r[campo]):
            errori.append("%s fuori dagli intervalli del progetto" % campo)
    for campo in ("aperto_il", "chiuso_il"):
        if r[campo] and (not canone.data_ammessa(r[campo][:10])
                         or not r[campo].endswith("+02:00")):
            errori.append("%s fuori dalla settimana" % campo)
    if bool(r["chiuso_il"]) != (r["stato"] in ("chiuso", "annullato")):
        errori.append("stato e data di chiusura incoerenti")
    if r["minuti_risoluzione"] and r["minuti_prima_risposta"] and \
            int(r["minuti_prima_risposta"]) > int(r["minuti_risoluzione"]):
        errori.append("prima risposta dopo la risoluzione")
    return errori


def verifica_csv(testo: str) -> List[str]:
    errori = ["%s: %s %s" % (FILE_CSV, v.regola, v.valore)
              for v in canone.controlla_testo(testo)]
    for r in csv.DictReader(io.StringIO(testo)):
        errori += ["%s %s: %s" % (FILE_CSV, r["id_ticket"], e)
                   for e in verifica_riga(r)]
    return errori


# --- Conversazioni di riferimento ----------------------------------------------

def _citazione(testo: str) -> List[str]:
    return [("> " + riga) if riga else ">" for riga in testo.split("\n")]


def _ora(iso: str) -> str:
    t = dt.datetime.fromisoformat(iso)
    return "%s %02d:%02d" % (t.date().isoformat(), t.hour, t.minute)


def rendi_golden(conv: dict, nome_json: str) -> str:
    """La versione Markdown di una conversazione di riferimento."""
    mancanti = [k for k in CHIAVI_GOLDEN if k not in conv]
    if mancanti:
        raise ValueError("%s: mancano le chiavi %s" % (nome_json,
                                                       ", ".join(mancanti)))
    esito = conv["esito"]
    righe = ["<!-- Generato da genera.py a partire da %s: modifica il JSON e "
             "rigenera. -->" % nome_json, "",
             "# %s · %s" % (conv["id"], conv["titolo"]), "",
             "| campo | valore |", "|---|---|",
             "| scenario | %s |" % conv["scenario"],
             "| canale | %s |" % conv["canale"],
             "| inizio | %s |" % _ora(conv["inizio"]),
             "| ticket | %s |" % (esito.get("ticket") or "nessuno"),
             "| passaggio a un operatore | %s |" % (
                 "sì" if esito.get("escalation") else "no"), "",
             "## Conversazione", ""]
    for turno in conv["turni"]:
        for azione in turno.get("azioni", []):
            righe += ["*Strumento* `%s` con `%s`" % (
                azione["strumento"],
                json.dumps(azione["argomenti"], ensure_ascii=False)), "",
                "```json", json.dumps(azione["risultato"], ensure_ascii=False,
                                      indent=2), "```", ""]
        chi = "Cliente" if turno["ruolo"] == "cliente" else "Assistente"
        righe += ["**%s**" % chi, ""] + _citazione(turno["testo"]) + [""]
    righe += ["## Esito", "", esito.get("riassunto", ""), "",
              "## Punti chiave per la valutazione", ""]
    righe += ["- " + p for p in conv["punti_chiave"]]
    return "\n".join(righe) + "\n"


# --- Comandi ------------------------------------------------------------------

def genera(radice: Path, uscita: Path) -> List[str]:
    """Scrive in `uscita` i file generati; restituisce i percorsi relativi."""
    prodotti: Dict[str, str] = {}
    testo = testo_csv(tutti_i_ticket(Caso(SEME)))
    errori = verifica_csv(testo)
    if errori:
        raise RuntimeError("il CSV generato viola il canone: " +
                           "; ".join(errori[:5]))
    prodotti[FILE_CSV] = testo
    for sorgente in sorted((radice / CARTELLA_GOLDEN).glob("gc-*.json")):
        conv = json.loads(sorgente.read_text(encoding="utf-8"))
        markdown = rendi_golden(conv, sorgente.name)
        violazioni = canone.controlla_testo(markdown)
        if violazioni:
            raise RuntimeError("%s viola il canone: %s %s" % (
                sorgente.name, violazioni[0].regola, violazioni[0].valore))
        prodotti["%s/%s.md" % (CARTELLA_GOLDEN, sorgente.stem)] = markdown
    for relativo in sorted(prodotti):
        destinazione = uscita / relativo
        destinazione.parent.mkdir(parents=True, exist_ok=True)
        with destinazione.open("w", encoding="utf-8", newline="\n") as f:
            f.write(prodotti[relativo])
    return sorted(prodotti)


def generati_presenti(radice: Path) -> List[str]:
    presenti = [FILE_CSV] if (radice / FILE_CSV).is_file() else []
    presenti += ["%s/%s" % (CARTELLA_GOLDEN, p.name) for p in
                 sorted((radice / CARTELLA_GOLDEN).glob("gc-*.md"))]
    return presenti


def confronta(radice: Path) -> int:
    """Rigenera in una cartella temporanea e confronta byte per byte."""
    with tempfile.TemporaryDirectory() as cartella:
        prodotti = genera(radice, Path(cartella))
        differenze = []
        for relativo in prodotti:
            presente = radice / relativo
            if not presente.is_file():
                differenze.append("MANCANTE: " + relativo)
            elif presente.read_bytes() != (Path(cartella) / relativo
                                           ).read_bytes():
                differenze.append("DIVERSO: " + relativo)
        differenze += ["IN PIÙ: " + r for r in generati_presenti(radice)
                       if r not in prodotti]
    if differenze:
        print("\n".join(differenze))
        print("%d file diversi da quelli rigenerati: esegui `python3 "
              "genera.py` per riallinearli." % len(differenze))
        return 1
    print("OK: %d file generati identici byte per byte." % len(prodotti))
    return 0


def violazioni_strutturate(percorso: Path, testo: str) -> List[str]:
    """Nomi di persone e aziende nei campi dove il formato li rende certi."""
    problemi = []
    if percorso.suffix == ".csv":
        for r in csv.DictReader(io.StringIO(testo)):
            if "nome_cliente" in r and "tipo_cliente" in r:
                problemi.append(canone.controlla_persona(r["nome_cliente"])
                                if r["tipo_cliente"] == "privato"
                                else canone.controlla_azienda(r["nome_cliente"]))
    elif percorso.suffix == ".json" and percorso.parent.name == "scenari":
        persona = json.loads(testo).get("persona") or {}
        if persona.get("nome"):
            problemi.append(canone.controlla_persona(persona["nome"]))
        cliente = persona.get("cliente") or {}
        if cliente.get("nome"):
            problemi.append(canone.controlla_persona(cliente["nome"])
                            if cliente.get("tipo") == "privato"
                            else canone.controlla_azienda(cliente["nome"]))
    return [p for p in problemi if p]


def controlla_canone(radice: Path) -> int:
    """Il canone su ogni file di testo della cartella (codice escluso)."""
    file = sorted(p for p in radice.rglob("*") if p.is_file()
                  and p.suffix in ESTENSIONI_TESTO
                  and "__pycache__" not in p.parts)
    trovate = []
    for percorso in file:
        relativo = percorso.relative_to(radice).as_posix()
        testo = percorso.read_text(encoding="utf-8")
        trovate += ["VIOLAZIONE %s:%d: %s: %s" % (relativo, v.riga, v.regola,
                                                  v.valore)
                    for v in canone.controlla_testo(testo)]
        trovate += ["VIOLAZIONE %s: %s" % (relativo, p)
                    for p in violazioni_strutturate(percorso, testo)]
    if trovate:
        print("\n".join(trovate))
        print("Violazioni del canone: %d." % len(trovate))
        return 1
    print("OK: canone rispettato in %d file." % len(file))
    return 0


def verifica(radice: Path) -> int:
    """La struttura di scenari, conversazioni, strumenti, procedure e dati."""
    problemi, riepilogo = verifiche.verifica_tutto(radice, FILE_CSV, COLONNE)
    if problemi:
        print("\n".join("PROBLEMA " + p for p in problemi))
        print("Problemi di struttura: %d." % len(problemi))
        return 1
    print("OK: struttura verificata: %s." % riepilogo)
    return 0


def main(argomenti: Sequence[str]) -> int:
    if list(argomenti) in (["-h"], ["--help"]):
        print(USO)
        return 0
    if len(argomenti) > 1 or (argomenti and argomenti[0] not in OPZIONI):
        print("ERRORE: argomenti non riconosciuti: %s\n%s"
              % (" ".join(argomenti), USO), file=sys.stderr)
        return 2
    try:
        if not argomenti:
            for relativo in genera(QUI, QUI):
                print("scritto: " + relativo)
            return 0
        if argomenti[0] == "--check":
            return confronta(QUI)
        if argomenti[0] == "--canone":
            return controlla_canone(QUI)
        return verifica(QUI)
    except (OSError, ValueError, KeyError, IndexError, RuntimeError) as errore:
        print("ERRORE: %s" % errore, file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
