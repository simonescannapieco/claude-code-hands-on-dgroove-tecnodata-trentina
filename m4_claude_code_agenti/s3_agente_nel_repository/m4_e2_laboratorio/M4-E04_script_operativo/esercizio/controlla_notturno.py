#!/usr/bin/env python3
"""controlla_notturno.py -- il controllo da eseguire dopo ogni passo: prova
progetti/gestionale-php/bin/controllo-notturno.php come lo proverebbe la
notte e lo confronta con SPECIFICA.md.

Crea due piccoli database di prova in
progetti/gestionale-php/var/controllo-notturno/ (var/ è fuori da git), con
lo schema del gestionale e poche righe inventate: uno con un'incoerenza o
due per ogni controllo, ciascuna accanto a un caso che incoerenza non è (a
30 e a 21 giorni esatti, una linea cessata, un'attivazione pianificata);
uno senza incoerenze. Esegue lo script con tools/php.sh dello spazio di
lavoro in sette casi: --help; i due database; il database che manca; un
giorno non valido; un'opzione sconosciuta; lo stile, con phpcs. Per ogni
caso confronta uscita, stdout e stderr con la specifica e stampa «ok» o
«NO» con il motivo. Alla fine cancella i database di prova. Non conosce le
incoerenze dei dati di esempio: quelle le trova lo script.

Uso:    python3 controlla_notturno.py
Env:    PN_PHP_SH  un altro strumento per PHP al posto di tools/php.sh
Uscita: l'ultima riga la ripete, «uscita: N». 0 tutti i casi come la
        specifica · 1 almeno un caso no · 2 il controllo non può girare
        (manca lo script, lo schema, tools/php.sh o vendor/; PHP non parte)
"""
import collections
import hashlib
import os
import re
import shutil
import sqlite3
import subprocess
import sys
from typing import Dict, List, Optional, Sequence, Set, Tuple

GESTIONALE = "progetti/gestionale-php"
SCRIPT = GESTIONALE + "/bin/controllo-notturno.php"
PROVA = GESTIONALE + "/var/controllo-notturno"
GIORNO = "2026-06-30"
OLT = "olt-levico-01"
CONTROLLI = ("linea-cliente-cessato", "linea-senza-apparato",
             "attivazione-ferma", "ticket-in-attesa")
CONTEGGI = ("fatture-scadute", "clienti-sospesi")
ATTESE = {("linea-cliente-cessato", "LN-009001"),
          ("linea-cliente-cessato", "LN-009006"),
          ("linea-senza-apparato", "LN-009003"),
          ("linea-senza-apparato", "LN-009004"),
          ("attivazione-ferma", "AT-2026-0901"),
          ("ticket-in-attesa", "TK-2026-09001")}
CONTATI = {"fatture-scadute": 2, "clienti-sospesi": 1}
TEMPO_MASSIMO = 300
MOSTRATE = 8
RIGA_CONTEGGIO = re.compile(r"(%s) ([0-9]+)" % "|".join(CONTEGGI))
RIGA_SEGNALAZIONE = re.compile(r"(\S+) (\S+)(?: .*)?")

Esito = collections.namedtuple("Esito", "rc out err")
Caso = collections.namedtuple("Caso", "nome ok motivi")
Uscita = collections.namedtuple("Uscita",
                                "segnalazioni conteggi altre in_fondo")


class Precondizione(Exception):
    """Il controllo non può girare: uscita 2."""


# --- i database di prova --------------------------------------------------

def _cliente(n: int, nome: str, cognome: str, stato: str) -> tuple:
    return ("CL-0090%02d" % n, "privato", nome, cognome, None, None,
            "%s.%s@example.org" % (nome.lower(), cognome.lower()),
            "+39 000 000 09%02d" % n, "Via dell'Esempio", str(n), 1, None,
            stato, "2024-01-15", None)


def _linea(n: int, stato: str, apparato: Optional[str],
           porta: Optional[str], cessata: Optional[str] = None) -> tuple:
    attiva = None if stato == "in_attivazione" else "2024-02-01"
    return ("LN-0090%02d" % n, "CL-0090%02d" % n, "CASA-PROVA", 1, apparato,
            porta, "pppoe", "ln0090%02d@ciaspolink.example.org" % n, None,
            None, None, stato, attiva, cessata)


def _ora(giorno: str) -> str:
    return giorno + "T10:00:00+02:00"


def _fisse() -> Dict[str, List[tuple]]:
    """Le righe che i due database di prova hanno uguali."""
    fattura = ("fattura", "2026-04", "2026-05-02", "2026-06-01", 2990, 658,
               3648)
    return {
        "comuni": [(1, "Levico Terme", "38056", "TN", "Valsugana")],
        "apparati": [(OLT, "olt", "OLT di prova", 1, "192.0.2.201", None,
                      "in_servizio")],
        "copertura": [(1, 1, "Via dell'Esempio", "1", "", "FTTH", 1000, OLT,
                       "2024-01-01", "2024-01-01")],
        "offerte": [("CASA-PROVA", "Casa Fibra di prova", "Casa", "FTTH",
                     1000, 300, 2990, 0, 1)],
        "clienti": [_cliente(1, "Anna", "Prova", "cessato"),
                    _cliente(2, "Marco", "Esempio", "cessato"),
                    _cliente(3, "Giulia", "Fittizio", "attivo"),
                    _cliente(4, "Luca", "Campione", "attivo"),
                    _cliente(5, "Sara", "Modello", "attivo"),
                    _cliente(6, "Paolo", "Bozza", "cessato"),
                    _cliente(7, "Elena", "Simulato", "sospeso")],
        "fatture": [
            ("FT-2026-009005", "CL-009004") + fattura + ("pagata",
                                                         "2026-05-11", None),
            ("FT-2026-009001", "CL-009007") + fattura + ("scaduta", None,
                                                         None),
            ("FT-2026-009002", "CL-009006") + fattura + ("scaduta", None,
                                                         None),
            ("FT-2026-009003", "CL-009004", "nota_credito", "2026-04",
             "2026-05-02", "2026-06-01", -1000, -220, -1220, "emessa", None,
             "FT-2026-009005"),
            ("FT-2026-009004", "CL-009003", "fattura", "2026-06",
             "2026-06-28", "2026-07-28", 2990, 658, 3648, "emessa", None,
             None)]}


def righe_di_prova(incoerenze: bool) -> Dict[str, List[tuple]]:
    """Le righe del database di prova, tabella per tabella: con le
    incoerenze, o con gli stessi casi sistemati."""
    if incoerenze:
        linee = [_linea(1, "attiva", OLT, "0/1/1"),
                 _linea(3, "attiva", None, None),
                 _linea(4, "attiva", OLT, None),
                 _linea(6, "sospesa", OLT, "0/1/3")]
        ferma, attesa = "2026-05-30", "2026-06-08"
    else:
        linee = [_linea(1, "cessata", OLT, "0/1/1", "2026-05-31"),
                 _linea(3, "attiva", OLT, "0/1/5"),
                 _linea(4, "attiva", OLT, "0/1/6"),
                 _linea(6, "cessata", OLT, "0/1/3", "2026-05-31")]
        ferma, attesa = "2026-06-29", "2026-06-29"
    linee += [_linea(2, "cessata", OLT, "0/1/2", "2026-05-31"),
              _linea(5, "in_attivazione", None, None),
              _linea(7, "sospesa", OLT, "0/1/4")]
    return dict(_fisse(), **{
        "linee": linee,
        "attivazioni": [
            ("AT-2026-0901", "LN-009005", "nuova", "CASA-PROVA", None,
             "verifica_tecnica", _ora("2026-05-28"), None, None, _ora(ferma),
             None, None),
            ("AT-2026-0902", "LN-009005", "nuova", "CASA-PROVA", None,
             "verifica_tecnica", _ora("2026-05-29"), None, None,
             _ora("2026-05-31"), None, None),
            ("AT-2026-0903", "LN-009005", "nuova", "CASA-PROVA", None,
             "pianificata", _ora("2026-03-20"), "2026-07-15", None,
             _ora("2026-04-01"), None, None)],
        "ticket": [
            ("TK-2026-09001", "CL-009003", "LN-009003", None, None, "guasto",
             "media", "in_attesa_cliente", "telefono", "Linea lenta (prova)",
             "Si aspetta la foto del router (prova).", _ora("2026-06-05"),
             _ora(attesa), None, None),
            ("TK-2026-09002", "CL-009004", "LN-009004", None, None, "guasto",
             "media", "in_attesa_cliente", "telefono", "Linea lenta (prova)",
             "Si aspetta la foto del router (prova).", _ora("2026-06-06"),
             _ora("2026-06-09"), None, None),
            ("TK-2026-09003", "CL-009005", None, None, None, "attivazione",
             "bassa", "aperto", "web", "Quando arriva il tecnico? (prova)",
             "Chiede la data dell'installazione (prova).", _ora("2026-04-30"),
             _ora("2026-05-01"), None, None)]})


def crea_database(schema: str, destinazione: str,
                  righe: Dict[str, List[tuple]]) -> None:
    """Un database SQLite dallo schema del gestionale e dalle righe date."""
    with open(schema, encoding="utf-8") as fh:
        sql = fh.read()
    con = sqlite3.connect(destinazione)
    try:
        con.executescript(sql)
        for tabella in ("comuni", "apparati", "copertura", "offerte",
                        "clienti", "linee", "attivazioni", "ticket",
                        "fatture"):
            for riga in righe.get(tabella, []):
                segni = ", ".join("?" * len(riga))
                con.execute("INSERT INTO %s VALUES (%s)" % (tabella, segni),
                            riga)
        con.commit()
    finally:
        con.close()


# --- eseguire lo script e leggerne l'uscita -------------------------------

def strumento_php(radice: str) -> str:
    """PN_PHP_SH, oppure tools/php.sh dello spazio di lavoro."""
    php = os.environ.get("PN_PHP_SH") or os.path.join(radice, "tools",
                                                      "php.sh")
    if not (os.path.isfile(php) and os.access(php, os.X_OK)):
        raise Precondizione("manca tools/php.sh, eseguibile: %s" % php)
    return php


def esegui(php: str, cartella: str, argomenti: Sequence[str],
           monta: Optional[str] = None) -> Esito:
    """php <argomenti> con tools/php.sh, nella cartella data; con monta,
    Docker monta quella cartella (PHP_SH_MOUNT_ROOT)."""
    ambiente = dict(os.environ)
    if monta:
        ambiente["PHP_SH_MOUNT_ROOT"] = monta
    try:
        fatto = subprocess.run([php, "php"] + list(argomenti), cwd=cartella,
                               stdin=subprocess.DEVNULL,
                               stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                               env=ambiente, timeout=TEMPO_MASSIMO,
                               check=False)
    except subprocess.TimeoutExpired:
        return Esito(124, "", "nessuna risposta in %d secondi"
                     % TEMPO_MASSIMO)
    esito = Esito(fatto.returncode, fatto.stdout.decode("utf-8", "replace"),
                  fatto.stderr.decode("utf-8", "replace"))
    if esito.rc == 2 and esito.err.startswith("php.sh:"):
        raise Precondizione("PHP non si avvia: %s (PRIMA_DEL_CORSO.md, "
                            "«Docker, oppure PHP e Composer»)"
                            % esito.err.strip()[:300])
    return esito


def leggi_righe(testo: str) -> Uscita:
    """Le righe di stdout: segnalazioni, conteggi, altre; e se i conteggi
    sono le ultime due righe."""
    segnalazioni = []  # type: List[Tuple[str, str]]
    conteggi = {}  # type: Dict[str, int]
    altre = []  # type: List[str]
    righe = [r for r in testo.splitlines() if r.strip()]
    for riga in righe:
        m = RIGA_CONTEGGIO.fullmatch(riga.strip())
        if m:
            conteggi[m.group(1)] = int(m.group(2))
            continue
        m = RIGA_SEGNALAZIONE.fullmatch(riga.strip())
        if m and m.group(1) in CONTROLLI:
            segnalazioni.append((m.group(1), m.group(2)))
            continue
        altre.append(riga)
    in_fondo = [RIGA_CONTEGGIO.fullmatch(r.strip()).group(1)
                for r in righe[-2:] if RIGA_CONTEGGIO.fullmatch(r.strip())]
    return Uscita(segnalazioni, conteggi, altre, in_fondo == list(CONTEGGI))


def impronta(percorso: str) -> Optional[str]:
    """La SHA-256 del file, None se non c'è."""
    try:
        with open(percorso, "rb") as fh:
            return hashlib.sha256(fh.read()).hexdigest()
    except OSError:
        return None


def elenco(coppie: Set[Tuple[str, str]]) -> str:
    return ", ".join("%s %s" % c for c in sorted(coppie))


def mostra(testo: str) -> str:
    righe = [r for r in testo.strip().splitlines() if r.strip()]
    corto = " | ".join(righe[:3])
    return "«%s»" % (corto if len(corto) <= 160 else corto[:159] + "…")


# --- i sette casi ---------------------------------------------------------

def motivi_lavoro(esito: Esito, attese: Set[Tuple[str, str]],
                  rc_atteso: int, prima: Optional[str],
                  dopo: Optional[str]) -> List[str]:
    """I motivi per cui un'esecuzione su un database di prova non torna."""
    motivi = []
    if esito.rc != rc_atteso:
        motivi.append("uscita %d, attesa %d" % (esito.rc, rc_atteso))
    letta = leggi_righe(esito.out)
    trovate = set(letta.segnalazioni)
    if attese - trovate:
        motivi.append("attese e non trovate: %s" % elenco(attese - trovate))
    if trovate - attese:
        motivi.append("trovate e non attese: %s" % elenco(trovate - attese))
    if len(trovate) != len(letta.segnalazioni):
        motivi.append("una segnalazione ripetuta")
    if letta.conteggi != CONTATI:
        motivi.append("conteggi: attesi %s; trovati %s" % (
            ", ".join("%s %d" % c for c in sorted(CONTATI.items())),
            ", ".join("%s %d" % c for c in sorted(letta.conteggi.items()))
            or "nessuno"))
    elif not letta.in_fondo:
        motivi.append("i conteggi non sono le ultime due righe, "
                      "fatture-scadute poi clienti-sospesi")
    if letta.altre:
        motivi.append("su stdout righe che la specifica non prevede: %s"
                      % mostra("\n".join(letta.altre)))
    if esito.err.strip():
        motivi.append("su stderr, a lavoro riuscito: %s" % mostra(esito.err))
    if prima != dopo:
        motivi.append("il database è cambiato: il controllo legge soltanto")
    return motivi


def motivi_errore(esito: Esito) -> List[str]:
    """I motivi per cui un'esecuzione che deve fallire (uscita 2) no."""
    motivi = []
    if esito.rc != 2:
        motivi.append("uscita %d, attesa 2" % esito.rc)
    if not esito.err.strip():
        motivi.append("nessun messaggio su stderr")
    if esito.out.strip():
        motivi.append("su stdout anche con l'errore: %s" % mostra(esito.out))
    return motivi


def prepara_prova(radice: str) -> str:
    """La cartella dei database di prova, vuota, con i due database."""
    cartella = os.path.join(radice, PROVA)
    if os.path.islink(cartella):
        raise Precondizione("%s è un collegamento simbolico" % PROVA)
    if os.path.isdir(cartella):
        shutil.rmtree(cartella)
    os.makedirs(cartella)
    schema = os.path.join(radice, GESTIONALE, "database", "schema.sql")
    for nome, incoerenze in (("incoerenze", True), ("pulito", False)):
        crea_database(schema, os.path.join(cartella, nome + ".sqlite"),
                      righe_di_prova(incoerenze))
    return cartella


def casi(radice: str, php: str, monta: Optional[str] = None) -> List[Caso]:
    """I sette casi, nello spazio di lavoro che ha radice in radice."""
    prova = prepara_prova(radice)
    try:
        return _casi(radice, php, monta, prova)
    finally:
        if os.path.isdir(prova) and not os.path.islink(prova):
            shutil.rmtree(prova, ignore_errors=True)


def _casi(radice: str, php: str, monta: Optional[str],
          prova: str) -> List[Caso]:
    risultati = []
    esito = esegui(php, radice, [SCRIPT, "--help"], monta)
    motivi = [] if esito.rc == 0 else ["uscita %d, attesa 0" % esito.rc]
    if "--db" not in esito.out or "--giorno" not in esito.out:
        motivi.append("l'uso su stdout non nomina --db e --giorno")
    risultati.append(Caso("--help", not motivi, motivi))
    for nome, attese, rc in (("incoerenze", ATTESE, 1), ("pulito", set(), 0)):
        db = os.path.join(prova, nome + ".sqlite")
        prima = impronta(db)
        esito = esegui(php, radice, [SCRIPT, "--db=%s/%s.sqlite"
                                     % (PROVA, nome), "--giorno=" + GIORNO],
                       monta)
        motivi = motivi_lavoro(esito, attese, rc, prima, impronta(db))
        risultati.append(Caso(
            "il database di prova %s (uscita %d, le segnalazioni, i conteggi)"
            % ("con le incoerenze" if rc else "senza incoerenze", rc),
            not motivi, motivi))
    esito = esegui(php, radice, [SCRIPT, "--db=%s/manca.sqlite" % PROVA,
                                 "--giorno=" + GIORNO], monta)
    motivi = motivi_errore(esito)
    if os.path.exists(os.path.join(prova, "manca.sqlite")):
        motivi.append("il file del database è stato creato")
    risultati.append(Caso("il database che manca (uscita 2, un messaggio su "
                          "stderr, nessun file creato)", not motivi, motivi))
    for nome, extra in (("un giorno non valido", ["--giorno=2026-02-30"]),
                        ("un'opzione sconosciuta",
                         ["--giorno=" + GIORNO, "--sconosciuta"])):
        esito = esegui(php, radice, [SCRIPT, "--db=%s/incoerenze.sqlite"
                                     % PROVA] + extra, monta)
        motivi = motivi_errore(esito)
        risultati.append(Caso("%s (uscita 2, un messaggio su stderr)" % nome,
                              not motivi, motivi))
    esito = esegui(php, os.path.join(radice, GESTIONALE),
                   ["vendor/bin/phpcs", "--no-colors", "-q", "--report=emacs",
                    "bin/controllo-notturno.php"], monta)
    motivi = [] if esito.rc == 0 else problemi_phpcs(esito)
    risultati.append(Caso("lo stile, con phpcs (PSR-12, regola 2.1)",
                          not motivi, motivi))
    return risultati


def problemi_phpcs(esito: Esito) -> List[str]:
    """Le segnalazioni di phpcs, una per riga, con il percorso dal file
    dello script; al più MOSTRATE."""
    righe = [re.sub(r"^.*?(bin/controllo-notturno\.php)", r"\1", r.strip())
             for r in (esito.out + "\n" + esito.err).splitlines()
             if r.strip()]
    altre = ["… e altre %d" % (len(righe) - MOSTRATE)] \
        if len(righe) > MOSTRATE else []
    return ["phpcs segnala problemi:"] + ["  " + r for r in
                                          righe[:MOSTRATE]] + altre


def precondizioni(radice: str) -> str:
    """Lo script, lo schema, vendor/ e tools/php.sh; lo strumento per PHP."""
    if not os.path.isfile(os.path.join(radice, SCRIPT)):
        raise Precondizione("manca %s: scrivilo, poi ripeti il controllo"
                            % SCRIPT)
    if not os.path.isfile(os.path.join(radice, GESTIONALE, "database",
                                       "schema.sql")):
        raise Precondizione("manca %s/database/schema.sql" % GESTIONALE)
    if not os.path.isfile(os.path.join(radice, GESTIONALE, "vendor",
                                       "autoload.php")):
        raise Precondizione("manca %s/vendor/autoload.php: prima tools/php.sh"
                            " composer install -d %s" % (GESTIONALE,
                                                         GESTIONALE))
    return strumento_php(radice)


def stampa(risultati: List[Caso]) -> int:
    """I casi, uno per riga con i motivi sotto; l'uscita."""
    for caso in risultati:
        print("%s  %s" % ("ok" if caso.ok else "NO", caso.nome))
        for motivo in caso.motivi:
            print("      %s" % motivo)
    buoni = sum(1 for c in risultati if c.ok)
    print("\n%d casi su %d come la specifica." % (buoni, len(risultati)))
    return 0 if buoni == len(risultati) else 1


def main() -> int:
    radice = os.path.dirname(os.path.abspath(__file__))
    print("Controllo di %s con SPECIFICA.md\n" % SCRIPT)
    try:
        php = precondizioni(radice)
        uscita = stampa(casi(radice, php))
    except (Precondizione, OSError, sqlite3.Error) as exc:
        print("il controllo non può girare: %s" % exc)
        uscita = 2
    print("uscita: %d" % uscita)
    return uscita


if __name__ == "__main__":
    sys.exit(main())
