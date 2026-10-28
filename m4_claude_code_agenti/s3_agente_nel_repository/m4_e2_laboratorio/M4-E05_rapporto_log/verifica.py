#!/usr/bin/env python3
"""verifica.py di M4-E05 «Il rapporto quotidiano dei log»: i controlli di
verifica.sh.

Non si fida di ciò che lo script dice di sé, né degli script dello spazio
di lavoro: esegue lo script dello spazio di lavoro (rapporto_giornaliero.py
o rapporto_giornaliero.sh) sui log originali del repository
(PN_HANDSON_ROOT), copiati in una cartella temporanea, da una cartella
temporanea; lo spazio di lavoro non cambia.

Decidono l'uscita:
  - c'è uno script, uno solo;
  - il controllo dell'esercizio, nella sua copia originale (esercizio/
    controlla_rapporto.py di questo elemento), passa negli otto casi;
  - martedì 8 settembre: l'uscita 1 e, fra le righe, il disservizio che la
    verifica conosce, con l'apparato, la porta, l'inizio, la fine e le
    linee giusti. Li confronta per impronta (verita.json): stampa per ogni
    campo «sì» o «no», mai il valore atteso;
  - lunedì 7 settembre, un giorno tranquillo: l'uscita 0, nessuna riga;
  - la garanzia del revisore, letta nella sua trascrizione
    (sessioni_claude.py).
Come dati, mai come uscita: gli altri giorni della settimana (l'uscita,
quante righe, il disservizio che la verifica conosce trovato o no),
NOTA.md, i commit dopo il punto di partenza, i file cambiati, le sessioni
di Claude Code, le chiamate al tool Agent, le esecuzioni del controllo da
parte di Claude.

Uso:    verifica.py <spazio di lavoro>
Uscita: 0 fatto · 1 non ancora, o il revisore ha modificato · 2
        precondizione (spazio di lavoro, i log della rete del repository,
        un file dell'elemento, una trascrizione che non si legge) o un
        errore inatteso: mai un «fatto» quando non può decidere
"""
import datetime
import glob
import hashlib
import importlib.util
import json
import os
import shutil
import subprocess
import sys
import tempfile
from types import ModuleType
from typing import Dict, List, Sequence

ELEMENTO = os.path.dirname(os.path.abspath(__file__))
SALE = "m4-e05"
CAMPI = ("apparato", "porta", "inizio", "fine", "linee")
SETTIMANA = ("lunedì", "martedì", "mercoledì", "giovedì", "venerdì",
             "sabato", "domenica")
FILE_MOSTRATI = 10


class Precondizione(Exception):
    """Un controllo che non può partire: il messaggio, uscita 2."""


def carica(nome: str, percorso: str) -> ModuleType:
    """Un modulo dell'elemento; Precondizione se manca o non si carica."""
    if not os.path.isfile(percorso):
        raise Precondizione("manca %s" % percorso)
    try:
        spec = importlib.util.spec_from_file_location(nome, percorso)
        if spec is None or spec.loader is None:
            raise ImportError("nessun caricatore")
        modulo = importlib.util.module_from_spec(spec)
        sys.modules[nome] = modulo
        spec.loader.exec_module(modulo)  # type: ignore[union-attr]
    except (ImportError, OSError, SyntaxError) as exc:
        raise Precondizione("%s non si carica (%s)" % (percorso, exc))
    return modulo


def impronta(campo: str, apparato: str, valore: str = "") -> str:
    testo = "%s:%s:%s" % (SALE, campo, apparato) + (
        ":" + valore if campo != "apparato" else "")
    return hashlib.sha256(testo.encode("utf-8")).hexdigest()


def leggi_verita() -> dict:
    """verita.json dell'elemento: le impronte attese e i giorni."""
    try:
        with open(os.path.join(ELEMENTO, "verita.json"),
                  encoding="utf-8") as fh:
            verita = json.load(fh)
        assert all(c in verita["richiesto"] for c in CAMPI + ("giorno",))
        assert isinstance(verita["tranquillo"], str)
        assert isinstance(verita["dati"], list)
    except (OSError, ValueError, KeyError, TypeError, AssertionError) as exc:
        raise Precondizione("verita.json dell'elemento non si legge (%s)"
                            % exc)
    return verita


def nome_giorno(giorno: str) -> str:
    """«martedì 8 settembre» per 2026-09-08."""
    data = datetime.date.fromisoformat(giorno)
    mesi = ("gennaio", "febbraio", "marzo", "aprile", "maggio", "giugno",
            "luglio", "agosto", "settembre", "ottobre", "novembre",
            "dicembre")
    return "%s %d %s" % (SETTIMANA[data.weekday()], data.day,
                         mesi[data.month - 1])


def quante(n: int) -> str:
    return "nessuna riga" if n == 0 else ("1 riga" if n == 1 else
                                          "%d righe" % n)


def campi_trovati(righe: Sequence[tuple], attesa: dict) -> Dict[str, bool]:
    """Per ogni campo, se una riga con l'apparato atteso lo ha giusto; la
    riga che ne ha di più."""
    migliore = {c: False for c in CAMPI}
    for riga in righe:
        if impronta("apparato", riga[0]) != attesa["apparato"]:
            continue
        sua = {c: impronta(c, riga[0], riga[i]) == attesa[c]
               for i, c in enumerate(CAMPI) if c != "apparato"}
        sua["apparato"] = True
        if sum(sua.values()) > sum(migliore.values()):
            migliore = sua
    return migliore


def richiesto(controlla: ModuleType, script: List[str], tmp: str, log: str,
              attesa: dict) -> List[str]:
    """Il giorno del disservizio che la verifica conosce."""
    giorno = attesa["giorno"]
    esito = controlla.esegui(script, ["--giorno", giorno, "--log", log], tmp)
    letta = controlla.leggi_righe(esito.out)
    print("\n%s (--giorno %s): uscita %d, %s" % (
        nome_giorno(giorno).capitalize(), giorno, esito.rc,
        quante(len(letta.disservizi))))
    campi = campi_trovati(letta.disservizi, attesa)
    print("  il disservizio che la verifica conosce: %s" % " · ".join(
        "%s %s" % (c, "sì" if campi[c] else "no") for c in CAMPI))
    problemi = [] if esito.rc == 1 else ["uscita %d, attesa 1" % esito.rc]
    if not all(campi.values()):
        problemi.append("il disservizio che la verifica conosce non torna "
                        "(%s)" % ", ".join(c for c in CAMPI if not campi[c]))
    if letta.altre:
        problemi.append("righe che non sono nel formato: %s"
                        % controlla.mostra("\n".join(letta.altre)))
    if esito.err.strip():
        problemi.append("su stderr: %s" % controlla.mostra(esito.err))
    for problema in problemi:
        print("  NO  %s" % problema)
    return ["%s: %s" % (nome_giorno(giorno), "; ".join(problemi))] \
        if problemi else []


def tranquillo(controlla: ModuleType, script: List[str], tmp: str, log: str,
               giorno: str) -> List[str]:
    """Il giorno tranquillo: uscita 0 e nessuna riga."""
    esito = controlla.esegui(script, ["--giorno", giorno, "--log", log], tmp)
    righe = [r for r in esito.out.splitlines() if r.strip()]
    print("\n%s, un giorno tranquillo: uscita %d, %s" % (
        nome_giorno(giorno).capitalize(), esito.rc, quante(len(righe))))
    if esito.rc == 0 and not righe and not esito.err.strip():
        return []
    for riga in righe[:5]:
        print("  %s" % riga)
    if esito.err.strip():
        print("  su stderr: %s" % controlla.mostra(esito.err))
    return ["%s, un giorno tranquillo: uscita %d, %s" % (
        nome_giorno(giorno), esito.rc, quante(len(righe)))]


def altri_giorni(controlla: ModuleType, script: List[str], tmp: str,
                 log: str, dati: List[dict]) -> None:
    """Gli altri giorni della settimana, come dati."""
    print("\nGli altri giorni della settimana, come dati, che non decidono "
          "l'uscita:")
    for dato in dati:
        esito = controlla.esegui(script, ["--giorno", dato["giorno"],
                                          "--log", log], tmp)
        righe = controlla.leggi_righe(esito.out).disservizi
        apparato = [r for r in righe
                    if impronta("apparato", r[0]) == dato["apparato"]]
        if any(impronta("inizio", r[0], r[2]) == dato["inizio"]
               for r in apparato):
            trovato = "trovato"
        else:
            trovato = "l'apparato c'è, l'inizio no" if apparato else \
                "non trovato"
        print("(dato) %s: uscita %d, %s; il disservizio che la verifica "
              "conosce: %s" % (dato["nome"], esito.rc, quante(len(righe)),
                               trovato))


def prove(ws: str) -> List[str]:
    """Il controllo dell'esercizio e i log veri, in una copia."""
    radice = os.environ.get("PN_HANDSON_ROOT") or os.path.normpath(
        os.path.join(ELEMENTO, *[os.pardir] * 4))
    originali = os.path.join(radice, "progetti", "rete", "log")
    if not glob.glob(os.path.join(originali, "syslog", "syslog_*.log")):
        raise Precondizione("mancano i log della rete nel repository: %s"
                            % originali)
    verita = leggi_verita()
    controlla = carica("controlla_rapporto_originale", os.path.join(
        ELEMENTO, "esercizio", "controlla_rapporto.py"))
    try:
        script = controlla.comando(ws)
    except controlla.Precondizione as exc:
        raise Precondizione(str(exc))
    with tempfile.TemporaryDirectory(prefix="verifica-m4-e05.") as tmp:
        log = os.path.join(tmp, "log")
        shutil.copytree(originali, log)
        print("Il controllo dell'esercizio, nella sua copia originale:")
        problemi = []
        if controlla.stampa(controlla.casi(script)) != 0:
            problemi.append("il controllo dell'esercizio non passa")
        problemi += richiesto(controlla, script, tmp, log,
                              verita["richiesto"])
        problemi += tranquillo(controlla, script, tmp, log,
                               verita["tranquillo"])
        altri_giorni(controlla, script, tmp, log, verita["dati"])
    return problemi


def git(ws: str, *argomenti: str) -> str:
    fatto = subprocess.run(["git", "-C", ws] + list(argomenti),
                           stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                           check=False)
    return fatto.stdout.decode("utf-8", "replace") if \
        fatto.returncode == 0 else ""


def dati_lavoro(ws: str) -> None:
    """NOTA.md, i commit e i file cambiati, come dati."""
    print("\n(dato) NOTA.md: %s" % ("c'è" if os.path.isfile(os.path.join(
        ws, "NOTA.md")) else "non c'è"))
    primo = git(ws, "rev-list", "--max-parents=0", "HEAD").split()
    if not primo:
        print("(dato) lo spazio di lavoro non ha un primo commit leggibile")
        return
    commit = git(ws, "rev-list", "--count", primo[-1] + "..HEAD").strip()
    print("(dato) commit dopo il punto di partenza: %s" % (commit or "0"))
    cambiati = sorted(set(git(ws, "diff", "--name-only", primo[-1])
                          .split() + git(ws, "ls-files", "--others",
                                         "--exclude-standard").split()))
    print("(dato) file cambiati dal punto di partenza: %d" % len(cambiati))
    for percorso in cambiati[:FILE_MOSTRATI]:
        print("  %s" % percorso)
    if len(cambiati) > FILE_MOSTRATI:
        print("  … e altri %d" % (len(cambiati) - FILE_MOSTRATI))


def main(argv: List[str]) -> int:
    ws = os.path.abspath(argv[1]) if len(argv) > 1 and argv[1] else ""
    if not ws or not os.path.isdir(ws):
        raise Precondizione("spazio di lavoro assente: %s"
                            % (argv[1] if len(argv) > 1 else ""))
    print("Verifica di M4-E05 «Il rapporto quotidiano dei log»\n")
    py = os.path.isfile(os.path.join(ws, "rapporto_giornaliero.py"))
    sh = os.path.isfile(os.path.join(ws, "rapporto_giornaliero.sh"))
    if py and sh:
        print("ci sono tutti e due, rapporto_giornaliero.py e "
              "rapporto_giornaliero.sh: la specifica ne vuole uno")
        manca = ["ci sono tutti e due gli script: tenetene uno solo"]
    elif not (py or sh):
        print("manca rapporto_giornaliero.py (o rapporto_giornaliero.sh): "
              "lo script non c'è ancora")
        manca = ["manca rapporto_giornaliero.py o rapporto_giornaliero.sh"]
    else:
        manca = prove(ws)
    dati_lavoro(ws)
    sessioni = carica("sessioni_claude", os.path.join(ELEMENTO,
                                                      "sessioni_claude.py"))
    try:
        righe, segnalazione = sessioni.riepilogo(ws, "controlla_rapporto.py")
    except sessioni.Precondizione as exc:
        raise Precondizione(str(exc))
    print("\n" + "\n".join(righe))
    if segnalazione:
        manca.append(segnalazione)
    if manca:
        print("\nNon ancora: %s." % "; ".join(manca))
        return 1
    print("\nFatto: il rapporto segue la specifica, trova il disservizio che "
          "la verifica conosce e tace nel giorno tranquillo.")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv))
    except Precondizione as exc:
        sys.stderr.write("verifica: %s\n" % exc)
        sys.exit(2)
    except Exception as exc:  # mai un «fatto» né un «non ancora»
        sys.stdout.flush()
        sys.stderr.write("verifica: errore inatteso, la verifica non può "
                         "decidere: %s: %s\n" % (type(exc).__name__, " ".join(
                             str(exc).split())))
        sys.exit(2)
