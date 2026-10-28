#!/usr/bin/env python3
"""verifica.py di M4-E04 «Uno script operativo che gira davvero»: i
controlli di verifica.sh.

Non si fida di ciò che lo script dice di sé, né degli script dello spazio
di lavoro: esegue progetti/gestionale-php/bin/controllo-notturno.php con
tools/php.sh del repository (PN_HANDSON_ROOT), o con PN_PHP_SH, in una
copia del gestionale dello spazio di lavoro, in una cartella temporanea;
lo spazio di lavoro non cambia.

Decidono l'uscita:
  - lo script c'è;
  - il controllo dell'esercizio, nella sua copia originale (esercizio/
    controlla_notturno.py di questo elemento), passa nei sette casi;
  - sui dati di esempio, in un database costruito dai dati originali del
    repository, con --giorno=2026-09-13: l'uscita 1, e per ogni controllo
    le segnalazioni attese, né una di meno né una di più; i due conteggi;
    niente su stderr; il database com'era. Le segnalazioni attese stanno in
    verita.json come impronte SHA-256: la verifica le confronta, non le
    stampa e non le scrive;
  - sugli stessi dati senza le incoerenze (le regole di SPECIFICA.md
    applicate al database): l'uscita 0, nessuna segnalazione, i conteggi;
  - la garanzia del revisore, letta nella sua trascrizione
    (sessioni_claude.py).
Come dati, mai come uscita: NOTA.md, i commit dopo il punto di partenza, i
file cambiati, le sessioni di Claude Code, le chiamate al tool Agent, le
esecuzioni del controllo da parte di Claude.

Uso:    verifica.py <spazio di lavoro>
Uscita: 0 fatto · 1 non ancora, o il revisore ha modificato · 2
        precondizione (spazio di lavoro, lo strumento per PHP, vendor/, i
        dati del gestionale del repository, un file dell'elemento, PHP che
        non si avvia, una trascrizione che non si legge) o un errore
        inatteso: mai un «fatto» quando non può decidere
"""
import datetime
import glob
import hashlib
import importlib.util
import json
import os
import shutil
import sqlite3
import subprocess
import sys
import tempfile
from types import ModuleType
from typing import Dict, List, Set

ELEMENTO = os.path.dirname(os.path.abspath(__file__))
GESTIONALE = "progetti/gestionale-php"
SCRIPT = GESTIONALE + "/bin/controllo-notturno.php"
GIORNO = "2026-09-13"
SALE = "m4-e04"
VERIFICA_DB = GESTIONALE + "/var/verifica"
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


def radice_repository() -> str:
    return os.environ.get("PN_HANDSON_ROOT") or os.path.normpath(
        os.path.join(ELEMENTO, *[os.pardir] * 4))


def strumento_php(radice: str) -> str:
    """tools/php.sh del repository (o PN_PHP_SH), che deve esserci."""
    php = os.environ.get("PN_PHP_SH") or os.path.join(radice, "tools",
                                                      "php.sh")
    if not (os.path.isfile(php) and os.access(php, os.X_OK)):
        raise Precondizione("manca lo strumento per PHP: %s (tools/php.sh "
                            "del repository)" % php)
    return php


def impronta(voce: str, valore: str) -> str:
    return hashlib.sha256(("%s:%s:%s" % (SALE, voce, valore)).encode(
        "utf-8")).hexdigest()


def leggi_verita() -> dict:
    """verita.json dell'elemento: le impronte attese."""
    try:
        with open(os.path.join(ELEMENTO, "verita.json"),
                  encoding="utf-8") as fh:
            verita = json.load(fh)
        assert isinstance(verita["segnalazioni"], dict)
        assert isinstance(verita["conteggi"], dict)
    except (OSError, ValueError, KeyError, TypeError, AssertionError) as exc:
        raise Precondizione("verita.json dell'elemento non si legge (%s)"
                            % exc)
    return verita


def costruisci_campione(radice: str, destinazione: str) -> None:
    """Il database dei dati di esempio, dai dati originali del repository,
    come lo crea bin/inizializza-db.php."""
    base = os.path.join(radice, GESTIONALE, "database")
    dati = sorted(glob.glob(os.path.join(base, "dati", "*.sql")))
    if not os.path.isfile(os.path.join(base, "schema.sql")) or not dati:
        raise Precondizione("mancano i dati del gestionale nel repository: "
                            "%s" % base)
    con = sqlite3.connect(destinazione)
    try:
        with open(os.path.join(base, "schema.sql"), encoding="utf-8") as fh:
            con.executescript(fh.read())
        con.execute("PRAGMA foreign_keys = OFF")
        for file in dati:
            with open(file, encoding="utf-8") as fh:
                con.executescript(fh.read())
        con.commit()
    finally:
        con.close()


def senza_incoerenze(campione: str, destinazione: str) -> None:
    """Gli stessi dati, con le regole di SPECIFICA.md applicate: niente da
    segnalare, gli stessi conteggi."""
    shutil.copyfile(campione, destinazione)
    giorno = datetime.date.fromisoformat(GIORNO)
    ora = GIORNO + "T09:00:00+02:00"
    regole = [
        ("UPDATE linee SET stato = 'cessata', cessata_il = COALESCE("
         "cessata_il, ?) WHERE stato <> 'cessata' AND cliente_id IN "
         "(SELECT id FROM clienti WHERE stato = 'cessato')", (GIORNO,)),
        ("UPDATE linee SET apparato_id = COALESCE(apparato_id, (SELECT id "
         "FROM apparati ORDER BY id LIMIT 1)), porta = CASE WHEN porta IS "
         "NULL OR porta = '' THEN '0/9/9' ELSE porta END WHERE stato = "
         "'attiva' AND (apparato_id IS NULL OR porta IS NULL OR porta = '')",
         ()),
        ("UPDATE attivazioni SET aggiornata_il = ? WHERE stato = "
         "'verifica_tecnica' AND substr(aggiornata_il, 1, 10) < ?",
         (ora, (giorno - datetime.timedelta(days=30)).isoformat())),
        ("UPDATE ticket SET aggiornato_il = ? WHERE stato = "
         "'in_attesa_cliente' AND substr(aggiornato_il, 1, 10) < ?",
         (ora, (giorno - datetime.timedelta(days=21)).isoformat()))]
    con = sqlite3.connect(destinazione)
    try:
        for sql, parametri in regole:
            con.execute(sql, parametri)
        con.commit()
    finally:
        con.close()


def campione(controlla: ModuleType, php: str, copia: str, db: str,
             verita: dict) -> List[str]:
    """Lo script sui dati di esempio: le righe stampate e i problemi."""
    prima = controlla.impronta(os.path.join(copia, db))
    esito = controlla.esegui(php, copia, [SCRIPT, "--db=" + db,
                                          "--giorno=" + GIORNO], copia)
    letta = controlla.leggi_righe(esito.out)
    problemi = []
    print("\nSui dati di esempio (--giorno=%s), in un database costruito dai "
          "dati del repository:" % GIORNO)
    if esito.rc != 1:
        problemi.append("uscita %d, attesa 1" % esito.rc)
    trovate = {}  # type: Dict[str, Set[str]]
    for voce, ident in letta.segnalazioni:
        trovate.setdefault(voce, set()).add(ident)
    for voce in controlla.CONTROLLI:
        attese = set(verita["segnalazioni"].get(voce, []))
        sue = trovate.get(voce, set())
        giuste = {i for i in sue if impronta(voce, i) in attese}
        in_piu = sorted(sue - giuste)
        print("  %s: trovate %d su %d%s" % (
            voce, len(giuste), len(attese),
            "; in più: " + ", ".join(in_piu) if in_piu else ""))
        if len(giuste) < len(attese) or in_piu:
            problemi.append("%s non torna" % voce)
    for voce in controlla.CONTEGGI:
        numero = letta.conteggi.get(voce)
        giusto = numero is not None and impronta(
            voce, str(numero)) == verita["conteggi"].get(voce)
        print("  %s: %s" % (voce, "torna" if giusto else
                            "non torna (stampato %s)" % (
                                "niente" if numero is None else numero)))
        if not giusto:
            problemi.append("il conteggio %s non torna" % voce)
    problemi += altri_problemi(controlla, esito, letta, prima,
                               controlla.impronta(os.path.join(copia, db)))
    for problema in problemi:
        print("  NO  %s" % problema)
    return ["sui dati di esempio: " + "; ".join(problemi)] if problemi else []


def altri_problemi(controlla: ModuleType, esito, letta, prima: str,
                   dopo: str) -> List[str]:
    """Le righe in più, l'ordine dei conteggi, stderr e il database."""
    problemi = []
    if letta.altre:
        problemi.append("su stdout righe che la specifica non prevede: %s"
                        % controlla.mostra("\n".join(letta.altre)))
    if letta.conteggi and not letta.in_fondo:
        problemi.append("i conteggi non sono le ultime due righe")
    if esito.err.strip():
        problemi.append("su stderr, a lavoro riuscito: %s"
                        % controlla.mostra(esito.err))
    if prima != dopo:
        problemi.append("il database è cambiato: il controllo legge soltanto")
    return problemi


def pulito(controlla: ModuleType, php: str, copia: str, db: str,
           verita: dict) -> List[str]:
    """Lo script sui dati di esempio senza le incoerenze."""
    prima = controlla.impronta(os.path.join(copia, db))
    esito = controlla.esegui(php, copia, [SCRIPT, "--db=" + db,
                                          "--giorno=" + GIORNO], copia)
    letta = controlla.leggi_righe(esito.out)
    problemi = [] if esito.rc == 0 else ["uscita %d, attesa 0" % esito.rc]
    if letta.segnalazioni:
        problemi.append("segnala anche: %s" % ", ".join(
            "%s %s" % s for s in letta.segnalazioni[:8]))
    if any(impronta(v, str(letta.conteggi.get(v))) != verita["conteggi"]
           .get(v) for v in controlla.CONTEGGI):
        problemi.append("i conteggi non tornano")
    problemi += altri_problemi(controlla, esito, letta, prima,
                               controlla.impronta(os.path.join(copia, db)))
    if not problemi:
        print("\nSui dati di esempio senza le incoerenze: uscita 0, nessuna "
              "segnalazione, i conteggi tornano.")
        return []
    print("\nSui dati di esempio senza le incoerenze:")
    for problema in problemi:
        print("  NO  %s" % problema)
    return ["sui dati di esempio senza le incoerenze: " + "; ".join(
        problemi)]


def prove(ws: str) -> List[str]:
    """Il controllo dell'esercizio e i dati di esempio, in una copia."""
    radice = radice_repository()
    php = strumento_php(radice)
    if not os.path.isfile(os.path.join(ws, GESTIONALE, "vendor",
                                       "autoload.php")):
        raise Precondizione("manca %s/vendor/autoload.php: dalla cartella "
                            "dello spazio di lavoro, tools/php.sh composer "
                            "install -d %s" % (GESTIONALE, GESTIONALE))
    verita = leggi_verita()
    controlla = carica("controlla_notturno_originale", os.path.join(
        ELEMENTO, "esercizio", "controlla_notturno.py"))
    with tempfile.TemporaryDirectory(prefix="verifica-m4-e04.") as tmp:
        copia = os.path.join(tmp, "spazio")
        shutil.copytree(os.path.join(ws, GESTIONALE),
                        os.path.join(copia, GESTIONALE), symlinks=True,
                        ignore=shutil.ignore_patterns("var", ".phpunit.cache",
                                                      ".phpcs-cache"))
        os.makedirs(os.path.join(copia, VERIFICA_DB))
        db = VERIFICA_DB + "/campione.sqlite"
        costruisci_campione(radice, os.path.join(copia, db))
        senza_incoerenze(os.path.join(copia, db), os.path.join(
            copia, VERIFICA_DB, "pulito.sqlite"))
        try:
            print("Il controllo dell'esercizio, nella sua copia originale:")
            problemi = []
            if controlla.stampa(controlla.casi(copia, php, copia)) != 0:
                problemi.append("il controllo dell'esercizio non passa")
            problemi += campione(controlla, php, copia, db, verita)
            problemi += pulito(controlla, php, copia,
                               VERIFICA_DB + "/pulito.sqlite", verita)
        except controlla.Precondizione as exc:
            raise Precondizione(str(exc))
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
    print("Verifica di M4-E04 «Uno script operativo che gira davvero»\n")
    if os.path.isfile(os.path.join(ws, SCRIPT)):
        manca = prove(ws)
    else:
        print("manca %s: lo script non c'è ancora" % SCRIPT)
        manca = ["manca %s" % SCRIPT]
    dati_lavoro(ws)
    sessioni = carica("sessioni_claude", os.path.join(ELEMENTO,
                                                      "sessioni_claude.py"))
    try:
        righe, segnalazione = sessioni.riepilogo(ws, "controlla_notturno.py")
    except sessioni.Precondizione as exc:
        raise Precondizione(str(exc))
    print("\n" + "\n".join(righe))
    if segnalazione:
        manca.append(segnalazione)
    if manca:
        print("\nNon ancora: %s." % "; ".join(manca))
        return 1
    print("\nFatto: lo script segue la specifica e trova le incoerenze dei "
          "dati di esempio.")
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
