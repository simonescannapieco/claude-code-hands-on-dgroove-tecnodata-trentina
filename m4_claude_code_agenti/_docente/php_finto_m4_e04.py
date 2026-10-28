#!/usr/bin/env python3
"""php_finto_m4_e04.py -- un tools/php.sh finto per le prove di M4-E04
(test_m4_e04.sh).

La suite lo passa, con la variabile PN_PHP_SH, a controlla_notturno.py, a
verifica.py, a soluzione/applica.sh e a _docente/live.sh: così girano senza
PHP e senza Docker. Non esegue PHP: emula, in Python, gli script che la
prova chiama, e lo dichiara (le uscite finte dicono «(finto)» dove possono).

Comandi, come tools/php.sh, nella cartella corrente:
  composer install [-d <cartella> | --working-dir=<cartella>] [opzioni]
      crea <cartella>/vendor/autoload.php e vendor/bin/phpcs (file segno);
      uscita 0.
  php <percorso>/vendor/bin/phpcs [opzioni] <file.php>
      nessuna uscita e 0; un rapporto finto e 2 se il file contiene
      «FINTO: stile». Senza vendor/bin/phpcs: «Could not open input
      file», 1, come PHP.
  php <percorso>/bin/inizializza-db.php [--db=<file>] [--forza]
      crea il database da database/schema.sql e database/dati/*.sql della
      cartella del gestionale, come lo script vero; 1 se esiste già.
  php <percorso>/bin/controllo-notturno.php [argomenti]
      emula il controllo notturno secondo SPECIFICA.md. La variante si
      legge nel file dello script, dalla riga «FINTO-VARIANTE: <nome>»;
      senza il segno (lo script di riferimento) è «giusto». Le varianti:
        giusto          come la specifica
        manca-una       senza il controllo ticket-in-attesa
        soglia          30 e 21 giorni già segnalati (>= invece di >)
        solo-attive     linea-cliente-cessato solo per le linee attive
        crea-db         senza database crea un file vuoto, poi esce 2
        errori-stdout   i messaggi di errore su stdout
        uscita-zero     esce 0 anche con le segnalazioni
        conta-scadenze  fatture-scadute: ogni documento non pagato e scaduto
        scrive-db       scrive una riga nel database
        rumore-stderr   una riga su stderr anche quando tutto va bene
        riga-strana     una riga d'intestazione su stdout
        aiuto-stderr    l'aiuto su stderr
        prova-fissa     stampa le righe attese dal controllo dello spazio di
                        lavoro sul suo database incoerenze.sqlite, e su ogni
                        altro database soltanto i suoi due conteggi: passa
                        quel controllo senza leggere niente
      Se il file manca: «Could not open input file», uscita 1, come PHP.
  php <altro>     «(finto) script non emulato», uscita 255.
Env:
  FINTO_PHP_ASSENTE=1  esce 2 con il messaggio di tools/php.sh quando non
                       trova né PHP né Docker (su STDERR, «php.sh: …»)
  FINTO_PHP_LOG        un file: una riga JSON per invocazione (argv, cwd)
Uscita: quella dello script emulato; 2 errore d'uso o di prerequisiti
"""
import datetime
import glob
import json
import os
import re
import sqlite3
import sys
from typing import Dict, List, Optional, Tuple

SEGNO_VARIANTE = re.compile(r"FINTO-VARIANTE:\s*([a-z-]+)")
SEGNO_STILE = "FINTO: stile"
USO = ("Uso: php bin/controllo-notturno.php [--db=percorso] "
       "[--giorno=AAAA-MM-GG] [--help] (finto)\n")
# Le righe del database di prova di controlla_notturno.py (prova-fissa).
RIGHE_FISSE = [
    "linea-cliente-cessato LN-009001 (finto)",
    "linea-cliente-cessato LN-009006 (finto)",
    "linea-senza-apparato LN-009003 (finto)",
    "linea-senza-apparato LN-009004 (finto)",
    "attivazione-ferma AT-2026-0901 (finto)",
    "ticket-in-attesa TK-2026-09001 (finto)",
    "fatture-scadute 2",
    "clienti-sospesi 1",
]


def registra(argv: List[str]) -> None:
    """Una riga in FINTO_PHP_LOG, se c'è."""
    log = os.environ.get("FINTO_PHP_LOG")
    if log:
        with open(log, "a", encoding="utf-8") as fh:
            fh.write(json.dumps({"argv": argv, "cwd": os.getcwd()},
                                ensure_ascii=False) + "\n")


def composer(argv: List[str]) -> int:
    """composer install, anche con -d o --working-dir."""
    if not argv or argv[0] != "install":
        sys.stderr.write("php.sh (finto): solo «composer install»\n")
        return 2
    cartella = "."
    for i, arg in enumerate(argv):
        if arg == "-d" and i + 1 < len(argv):
            cartella = argv[i + 1]
        elif arg.startswith("--working-dir="):
            cartella = arg.split("=", 1)[1]
    os.makedirs(os.path.join(cartella, "vendor", "bin"), exist_ok=True)
    for nome in ("autoload.php", os.path.join("bin", "phpcs")):
        with open(os.path.join(cartella, "vendor", nome), "w",
                  encoding="utf-8") as fh:
            fh.write("<?php // finto\n")
    print("Generating autoload files (finto)")
    return 0


def phpcs(argv: List[str]) -> int:
    """phpcs finto: «FINTO: stile» nel file lo sporca."""
    file = [a for a in argv if a.endswith(".php")]
    sporchi = []
    for percorso in file:
        with open(percorso, encoding="utf-8", errors="replace") as fh:
            if SEGNO_STILE in fh.read():
                sporchi.append(percorso)
    if not sporchi:
        return 0
    for percorso in sporchi:
        print("FILE: %s\n 1 | ERROR | Line exceeds maximum limit of 120 "
              "characters (finto)" % percorso)
    return 2


def opzioni(argv: List[str]) -> Dict[str, str]:
    """--nome=valore, --nome valore o --nome; ValueError se sconosciuta."""
    valori = {}  # type: Dict[str, str]
    i = 0
    while i < len(argv):
        m = re.fullmatch(r"--(db|giorno|forza|help)(?:=(.*))?", argv[i])
        if m is None:
            raise ValueError("opzione sconosciuta: %s" % argv[i])
        nome, valore = m.group(1), m.group(2)
        if valore is None and nome in ("db", "giorno"):
            if i + 1 >= len(argv):
                raise ValueError("--%s vuole un valore" % nome)
            valore = argv[i + 1]
            i += 1
        valori[nome] = "" if valore is None else valore
        i += 1
    return valori


def inizializza(script: str, argv: List[str]) -> int:
    """bin/inizializza-db.php: il database da schema e dati."""
    gestionale = os.path.dirname(os.path.dirname(os.path.abspath(script)))
    try:
        valori = opzioni(argv)
    except ValueError as exc:
        sys.stderr.write("%s\n" % exc)
        return 2
    percorso = valori.get("db") or os.path.join(gestionale, "var",
                                                "gestionale.sqlite")
    if os.path.exists(percorso):
        if "forza" not in valori:
            sys.stderr.write("Il database esiste già: %s (usa --forza per "
                             "ricrearlo)\n" % percorso)
            return 1
        os.remove(percorso)
    os.makedirs(os.path.dirname(os.path.abspath(percorso)), exist_ok=True)
    con = sqlite3.connect(percorso)
    try:
        base = os.path.join(gestionale, "database")
        with open(os.path.join(base, "schema.sql"), encoding="utf-8") as fh:
            con.executescript(fh.read())
        con.execute("PRAGMA foreign_keys = OFF")
        for file in sorted(glob.glob(os.path.join(base, "dati", "*.sql"))):
            with open(file, encoding="utf-8") as fh:
                con.executescript(fh.read())
        con.commit()
    finally:
        con.close()
    print("Database creato: %s (finto)" % percorso)
    return 0


def giorno_valido(testo: str) -> Optional[datetime.date]:
    """La data AAAA-MM-GG, o None."""
    if re.fullmatch(r"\d{4}-\d\d-\d\d", testo) is None:
        return None
    try:
        return datetime.date(int(testo[:4]), int(testo[5:7]),
                             int(testo[8:]))
    except ValueError:
        return None


def segnalazioni(con: sqlite3.Connection, giorno: datetime.date,
                 variante: str) -> List[str]:
    """Le righe dei quattro controlli, nell'ordine della specifica."""
    righe = []
    linee = "l.stato = 'attiva'" if variante == "solo-attive" else \
        "l.stato <> 'cessata'"
    for ident, cliente in con.execute(
            "SELECT l.id, l.cliente_id FROM linee l JOIN clienti c ON "
            "c.id = l.cliente_id WHERE c.stato = 'cessato' AND %s "
            "ORDER BY l.id" % linee):
        righe.append("linea-cliente-cessato %s cliente %s (finto)"
                     % (ident, cliente))
    for (ident,) in con.execute(
            "SELECT id FROM linee WHERE stato = 'attiva' AND (apparato_id "
            "IS NULL OR porta IS NULL OR porta = '') ORDER BY id"):
        righe.append("linea-senza-apparato %s (finto)" % ident)
    confronto = "<=" if variante == "soglia" else "<"
    controlli = [("attivazione-ferma", "attivazioni", "aggiornata_il",
                  "verifica_tecnica", 30)]
    if variante != "manca-una":
        controlli.append(("ticket-in-attesa", "ticket", "aggiornato_il",
                          "in_attesa_cliente", 21))
    for nome, tabella, colonna, stato, giorni in controlli:
        limite = (giorno - datetime.timedelta(days=giorni)).isoformat()
        for (ident,) in con.execute(
                "SELECT id FROM %s WHERE stato = ? AND substr(%s, 1, 10) %s "
                "? ORDER BY id" % (tabella, colonna, confronto),
                (stato, limite)):
            righe.append("%s %s (finto)" % (nome, ident))
    return righe


def conteggi(con: sqlite3.Connection, giorno: datetime.date,
             variante: str) -> List[str]:
    """Le due righe dei conteggi."""
    if variante == "conta-scadenze":
        scadute = con.execute(
            "SELECT COUNT(*) FROM fatture WHERE pagata_il IS NULL AND "
            "scade_il < ? AND stato <> 'annullata'",
            (giorno.isoformat(),)).fetchone()[0]
    else:
        scadute = con.execute(
            "SELECT COUNT(*) FROM fatture WHERE tipo = 'fattura' AND "
            "stato = 'scaduta'").fetchone()[0]
    sospesi = con.execute(
        "SELECT COUNT(*) FROM clienti WHERE stato = 'sospeso'").fetchone()[0]
    return ["fatture-scadute %d" % scadute, "clienti-sospesi %d" % sospesi]


def errore(testo: str, variante: str) -> int:
    """Un errore d'uso o di precondizione: il messaggio e l'uscita 2."""
    (sys.stdout if variante == "errori-stdout" else sys.stderr).write(
        testo + "\n")
    return 2


def argomenti_notturno(script: str, argv: List[str],
                       variante: str) -> Tuple[Optional[Dict[str, str]],
                                               int]:
    """Le opzioni lette, oppure (None, uscita) se lo script ha finito."""
    try:
        valori = opzioni(argv)
    except ValueError as exc:
        return None, errore("%s\n%s" % (exc, USO.rstrip()), variante)
    if "forza" in valori:
        return None, errore("opzione sconosciuta: --forza", variante)
    if "help" in valori:
        (sys.stderr if variante == "aiuto-stderr" else sys.stdout).write(
            USO + "  --db=percorso  --giorno=AAAA-MM-GG  --help\n")
        return None, 0
    if "db" not in valori:
        valori["db"] = os.path.join(os.path.dirname(os.path.dirname(
            os.path.abspath(script))), "var", "gestionale.sqlite")
    return valori, 0


def notturno(script: str, argv: List[str], variante: str) -> int:
    """bin/controllo-notturno.php, emulato."""
    valori, uscita = argomenti_notturno(script, argv, variante)
    if valori is None:
        return uscita
    giorno = giorno_valido(valori.get("giorno") or
                           datetime.date.today().isoformat())
    if giorno is None:
        return errore("Giorno non valido: %s (atteso AAAA-MM-GG)"
                      % valori.get("giorno"), variante)
    percorso = valori["db"]
    if not os.path.isfile(percorso):
        if variante == "crea-db":
            open(percorso, "w").close()
        return errore("Database non trovato: %s" % percorso, variante)
    if variante == "prova-fissa":
        righe = RIGHE_FISSE if os.path.basename(percorso) == \
            "incoerenze.sqlite" else RIGHE_FISSE[-2:]
    else:
        con = sqlite3.connect("file:%s?mode=%s" % (
            percorso, "rw" if variante == "scrive-db" else "ro"), uri=True)
        try:
            if variante == "scrive-db":
                con.execute("CREATE TABLE IF NOT EXISTS controllo_finto "
                            "(quando TEXT)")
                con.execute("INSERT INTO controllo_finto VALUES ('ora')")
                con.commit()
            righe = segnalazioni(con, giorno, variante) + conteggi(
                con, giorno, variante)
        finally:
            con.close()
    if variante == "riga-strana":
        print("Controllo notturno del %s (finto)" % giorno.isoformat())
    for riga in righe:
        print(riga)
    if variante == "rumore-stderr":
        sys.stderr.write("controllo eseguito (finto)\n")
    trovate = [r for r in righe if not r.startswith(("fatture-scadute",
                                                     "clienti-sospesi"))]
    return 1 if trovate and variante != "uscita-zero" else 0


def php(argv: List[str]) -> int:
    """php <script> [argomenti]."""
    if not argv:
        sys.stderr.write("php.sh (finto): manca lo script\n")
        return 2
    script, resto = argv[0], argv[1:]
    if not os.path.isfile(script):
        print("Could not open input file: %s" % script)
        return 1
    if script.endswith(os.path.join("vendor", "bin", "phpcs")):
        return phpcs(resto)
    if script.endswith("inizializza-db.php"):
        return inizializza(script, resto)
    if script.endswith("controllo-notturno.php"):
        with open(script, encoding="utf-8", errors="replace") as fh:
            segno = SEGNO_VARIANTE.search(fh.read())
        return notturno(script, resto, segno.group(1) if segno else "giusto")
    sys.stderr.write("(finto) script non emulato: %s\n" % script)
    return 255


def main(argv: List[str]) -> int:
    registra(argv)
    if os.environ.get("FINTO_PHP_ASSENTE") == "1":
        sys.stderr.write("php.sh: servono PHP >= 8.3 o Docker: non trovo né "
                         "l'uno né l'altro\n")
        return 2
    if not argv:
        sys.stderr.write("php.sh (finto): manca il comando\n")
        return 2
    if argv[0] == "composer":
        return composer(argv[1:])
    if argv[0] == "php":
        return php(argv[1:])
    sys.stderr.write("php.sh (finto): comando sconosciuto: %s\n" % argv[0])
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
