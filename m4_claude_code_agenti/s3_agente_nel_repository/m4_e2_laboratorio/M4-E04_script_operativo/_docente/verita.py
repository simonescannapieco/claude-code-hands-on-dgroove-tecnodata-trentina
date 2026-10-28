#!/usr/bin/env python3
"""verita.py di M4-E04 -- la verità della verifica, per il docente: le
segnalazioni e i conteggi attesi sui dati di esempio, come impronte.

Li ricava due volte e pretende che coincidano:
  - dalle regole di SPECIFICA.md, applicate con --giorno 2026-09-13 a un
    database costruito dai dati del gestionale (progetti/gestionale-php/
    database/), come lo crea bin/inizializza-db.php;
  - dall'elenco del docente, il paragrafo «Modulo 4: uno script operativo
    che gira davvero» di progetti/gestionale-php/_docente/difetti-noti.md
    (gli identificativi delle incoerenze inserite e i due numeri).
Poi scrive le impronte SHA-256 di «m4-e04:<voce>:<valore>», mai i valori.

Uso:    python3 _docente/verita.py            stampa il JSON su stdout (è
                                              il contenuto di verita.json)
        python3 _docente/verita.py --check [--verita <file>]
                                              confronta con verita.json
Env:    PN_HANDSON_ROOT  il repository (default: la radice sopra l'elemento)
Uscita: 0 stampato, o verita.json conferma i dati · 1 verita.json è
        diversa · 2 precondizione (dati o elenco del docente illeggibili;
        le regole e l'elenco non coincidono)
"""
import datetime
import glob
import hashlib
import json
import os
import re
import sqlite3
import sys
from typing import Dict, List, Set, Tuple

ELEMENTO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GIORNO = "2026-09-13"
SALE = "m4-e04"
TITOLO = "**Modulo 4: uno script operativo che gira davvero.**"
NOTA = ("Impronte SHA-256 di «m4-e04:<voce>:<valore>»: le segnalazioni "
        "attese sui dati di esempio, per controllo, e i due conteggi. La "
        "verifica le confronta con ciò che lo script stampa, senza mai "
        "scriverle in chiaro.")
CHIAVI = (("cessato", "linea-cliente-cessato", "LN"),
          ("senza apparato", "linea-senza-apparato", "LN"),
          ("verifica tecnica", "attivazione-ferma", "AT"),
          ("attesa del cliente", "ticket-in-attesa", "TK"))


class Precondizione(Exception):
    """La verità non si ricava: uscita 2."""


def impronta(voce: str, valore: str) -> str:
    return hashlib.sha256(("%s:%s:%s" % (SALE, voce, valore)).encode(
        "utf-8")).hexdigest()


def dalle_regole(radice: str) -> Tuple[Dict[str, Set[str]], Dict[str, int]]:
    """Le segnalazioni e i conteggi, dalle regole di SPECIFICA.md."""
    base = os.path.join(radice, "progetti", "gestionale-php", "database")
    dati = sorted(glob.glob(os.path.join(base, "dati", "*.sql")))
    if not dati:
        raise Precondizione("nessun dato in %s" % base)
    con = sqlite3.connect(":memory:")
    with open(os.path.join(base, "schema.sql"), encoding="utf-8") as fh:
        con.executescript(fh.read())
    con.execute("PRAGMA foreign_keys = OFF")
    for file in dati:
        with open(file, encoding="utf-8") as fh:
            con.executescript(fh.read())
    giorno = datetime.date.fromisoformat(GIORNO)
    limite = {n: (giorno - datetime.timedelta(days=n)).isoformat()
              for n in (21, 30)}
    query = {
        "linea-cliente-cessato": (
            "SELECT l.id FROM linee l JOIN clienti c ON c.id = l.cliente_id "
            "WHERE c.stato = 'cessato' AND l.stato <> 'cessata'", ()),
        "linea-senza-apparato": (
            "SELECT id FROM linee WHERE stato = 'attiva' AND (apparato_id "
            "IS NULL OR porta IS NULL OR porta = '')", ()),
        "attivazione-ferma": (
            "SELECT id FROM attivazioni WHERE stato = 'verifica_tecnica' "
            "AND substr(aggiornata_il, 1, 10) < ?", (limite[30],)),
        "ticket-in-attesa": (
            "SELECT id FROM ticket WHERE stato = 'in_attesa_cliente' AND "
            "substr(aggiornato_il, 1, 10) < ?", (limite[21],))}
    segnalazioni = {voce: {r[0] for r in con.execute(sql, parametri)}
                    for voce, (sql, parametri) in query.items()}
    conteggi = {
        "fatture-scadute": con.execute(
            "SELECT COUNT(*) FROM fatture WHERE tipo = 'fattura' AND stato "
            "= 'scaduta'").fetchone()[0],
        "clienti-sospesi": con.execute(
            "SELECT COUNT(*) FROM clienti WHERE stato = 'sospeso'")
        .fetchone()[0]}
    con.close()
    return segnalazioni, conteggi


def dall_elenco(radice: str) -> Tuple[Dict[str, Set[str]], Dict[str, int]]:
    """Le stesse cose, dall'elenco del docente."""
    percorso = os.path.join(radice, "progetti", "gestionale-php", "_docente",
                            "difetti-noti.md")
    with open(percorso, encoding="utf-8") as fh:
        testo = fh.read()
    if TITOLO not in testo:
        raise Precondizione("%s non ha il paragrafo %s" % (percorso, TITOLO))
    paragrafo = testo.split(TITOLO, 1)[1].split("\n\n**", 1)[0]
    voci = [r[2:] for r in paragrafo.splitlines() if r.startswith("- ")]
    segnalazioni = {}  # type: Dict[str, Set[str]]
    for chiave, voce, prefisso in CHIAVI:
        righe = [r for r in voci if chiave in r]
        if len(righe) != 1:
            raise Precondizione("l'elenco del docente: %d righe con «%s»"
                                % (len(righe), chiave))
        segnalazioni[voce] = set(re.findall(r"\b%s-[0-9-]+\b" % prefisso,
                                            righe[0]))
    conteggi = {}  # type: Dict[str, int]
    for voce, frase in (("fatture-scadute", "fatture scadute"),
                        ("clienti-sospesi", "clienti sospesi")):
        trovati = [int(n) for r in voci
                   for n in re.findall(r"([0-9]+) %s" % frase, r)]
        if len(trovati) != 1:
            raise Precondizione("l'elenco del docente: «%s» non si legge"
                                % frase)
        conteggi[voce] = trovati[0]
    return segnalazioni, conteggi


def verita(radice: str) -> dict:
    """Il contenuto di verita.json."""
    regole = dalle_regole(radice)
    elenco = dall_elenco(radice)
    if regole != elenco:
        raise Precondizione("le regole di SPECIFICA.md e l'elenco del "
                            "docente non coincidono")
    segnalazioni, conteggi = regole
    return {
        "elemento": "M4-E04",
        "nota": NOTA,
        "giorno": GIORNO,
        "segnalazioni": {voce: sorted(impronta(voce, i) for i in ids)
                         for voce, ids in sorted(segnalazioni.items())},
        "conteggi": {voce: impronta(voce, str(n))
                     for voce, n in sorted(conteggi.items())}}


def main(argv: List[str]) -> int:
    radice = os.environ.get("PN_HANDSON_ROOT") or os.path.normpath(
        os.path.join(ELEMENTO, *[os.pardir] * 4))
    try:
        attesa = verita(radice)
    except (Precondizione, OSError, sqlite3.Error) as exc:
        sys.stderr.write("verita: %s\n" % exc)
        return 2
    testo = json.dumps(attesa, ensure_ascii=False, indent=2) + "\n"
    if "--check" not in argv:
        sys.stdout.write(testo)
        return 0
    file = os.path.join(ELEMENTO, "verita.json")
    if "--verita" in argv and argv.index("--verita") + 1 < len(argv):
        file = argv[argv.index("--verita") + 1]
    try:
        with open(file, encoding="utf-8") as fh:
            uguale = json.load(fh) == attesa
    except (OSError, ValueError) as exc:
        sys.stderr.write("verita: %s non si legge (%s)\n" % (file, exc))
        return 2
    if not uguale:
        print("%s è diversa da ciò che dicono i dati e l'elenco del docente"
              % file)
        return 1
    print("verita.json conferma i dati: %d segnalazioni, %d conteggi" % (
        sum(len(v) for v in attesa["segnalazioni"].values()),
        len(attesa["conteggi"])))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
