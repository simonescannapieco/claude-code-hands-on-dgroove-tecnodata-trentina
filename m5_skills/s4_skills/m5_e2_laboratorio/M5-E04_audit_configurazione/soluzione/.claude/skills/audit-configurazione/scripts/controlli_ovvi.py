#!/usr/bin/env python3
"""Stampa i candidati di un audit che si trovano senza ragionare.

Per un apparato della rete di CiaspoLink confronta la sua configurazione con
la sua riga di inventario e cerca le parole che la checklist di audit nomina.
Un candidato non è ancora un problema: va visto sulla riga.

Uso:    controlli_ovvi.py <cartella del progetto rete> <apparato>
        controlli_ovvi.py --help
Stampa: su stdout, in TSV, categoria, file, riga, testo (riga 0: ciò che
        manca dal file); su stderr, i messaggi.
Esempio:
        controlli_ovvi.py progetti/rete sw-rovereto-01
Uscita: 0 = eseguito, anche senza candidati · 2 = argomenti, apparato che
        non esiste in inventario.csv, file che non si legge
"""
import csv
import os
import re
import sys

# Le parole che la checklist di audit nomina nei suoi standard. Solo ciò che
# si riconosce da una riga sola: il resto chiede di ragionare.
PAROLE = (
    ("AUD-01", re.compile(r"community|\b(public|private)\b", re.IGNORECASE)),
    ("AUD-02", re.compile(r"\b(telnet|ftp|http|www)\b", re.IGNORECASE)),
    # Il server NTP e il collettore di syslog dismessi, da AUD-04 e AUD-05.
    ("AUD-04", re.compile(r"\b192\.0\.2\.244\b")),
    ("AUD-05", re.compile(r"\b192\.0\.2\.243\b")),
)
# I campi dell'inventario che la configurazione deve riportare (AUD-11, AUD-13).
CAMPI = (("AUD-11", "ip_gestione"), ("AUD-13", "firmware"))


def errore(messaggio):
    """Scrive il motivo su stderr ed esce 2."""
    sys.stderr.write("controlli_ovvi: %s\n" % messaggio)
    sys.exit(2)


def riga_inventario(progetto, apparato):
    """La riga dell'apparato in inventario.csv."""
    percorso = os.path.join(progetto, "inventario.csv")
    try:
        with open(percorso, encoding="utf-8", newline="") as fh:
            for riga in csv.DictReader(fh):
                if riga.get("apparato") == apparato:
                    return riga
    except OSError as exc:
        errore("non riesco a leggere %s (%s)" % (percorso, exc.strerror))
    errore("%s non è in %s: gli apparati sono nella colonna «apparato»"
           % (apparato, percorso))


def file_apparato(progetto, apparato):
    """I file di configurazione dell'apparato: un file o una cartella."""
    cartella = os.path.join(progetto, "configurazioni")
    try:
        nomi = sorted(os.listdir(cartella))
    except OSError as exc:
        errore("non riesco a leggere %s (%s)" % (cartella, exc.strerror))
    trovati = []
    for nome in nomi:
        percorso = os.path.join(cartella, nome)
        if os.path.isdir(percorso) and nome == apparato:
            trovati += [os.path.join(percorso, n)
                        for n in sorted(os.listdir(percorso))]
        elif os.path.splitext(nome)[0] == apparato:
            trovati.append(percorso)
    if not trovati:
        errore("nessuna configurazione per %s in %s" % (apparato, cartella))
    return trovati


def main(argv):
    if len(argv) == 2 and argv[1] in ("-h", "--help"):
        print(__doc__.strip())
        return 0
    if len(argv) != 3:
        errore("servono due argomenti: la cartella del progetto rete e "
               "l'apparato (--help per l'uso)")
    progetto, apparato = argv[1], argv[2]
    inventario = riga_inventario(progetto, apparato)
    testi = {}
    for percorso in file_apparato(progetto, apparato):
        try:
            with open(percorso, encoding="utf-8") as fh:
                testi[percorso] = fh.read()
        except (OSError, UnicodeDecodeError) as exc:
            errore("non riesco a leggere %s (%s)" % (percorso, exc))
    print("categoria\tfile\triga\ttesto")
    for percorso, testo in testi.items():
        relativo = os.path.relpath(percorso, progetto)
        for numero, riga in enumerate(testo.splitlines(), 1):
            for categoria, parola in PAROLE:
                if parola.search(riga):
                    print("%s\t%s\t%d\t%s"
                          % (categoria, relativo, numero, riga.strip()))
    tutto = "\n".join(testi.values())
    for categoria, campo in CAMPI:
        valore = inventario.get(campo) or ""
        if valore and valore not in tutto:
            print("%s\t-\t0\t%s dell'inventario, %s, non compare nella "
                  "configurazione" % (categoria, campo, valore))
    duplicati(progetto, apparato, inventario, testi)
    return 0


def duplicati(progetto, apparato, inventario, testi):
    """AUD-11: l'indirizzo di gestione dell'apparato compare in un altro
    apparato, o un indirizzo di un altro apparato compare in questo."""
    try:
        with open(os.path.join(progetto, "inventario.csv"),
                  encoding="utf-8", newline="") as fh:
            altri = {r["apparato"]: r.get("ip_gestione") or ""
                     for r in csv.DictReader(fh) if r.get("apparato")}
    except OSError:
        return
    miei = inventario.get("ip_gestione") or ""
    for nome, ip in sorted(altri.items()):
        if nome == apparato or not ip:
            continue
        cerca = re.compile(r"(?<![\d.])%s(?![\d])" % re.escape(ip))
        # Un indirizzo di un altro apparato dentro questa configurazione.
        for percorso, testo in testi.items():
            for numero, riga in enumerate(testo.splitlines(), 1):
                if cerca.search(riga):
                    print("AUD-11\t%s\t%d\t%s è l'indirizzo di %s: %s"
                          % (os.path.relpath(percorso, progetto), numero,
                             ip, nome, riga.strip()))
        # L'indirizzo di questo apparato dentro un altro apparato.
        if not miei:
            continue
        try:
            for percorso in file_apparato(progetto, nome):
                with open(percorso, encoding="utf-8") as fh:
                    for numero, riga in enumerate(fh, 1):
                        if re.search(r"(?<![\d.])%s(?![\d])" % re.escape(miei),
                                     riga):
                            print("AUD-11\t%s\t%d\t%s è l'indirizzo di %s "
                                  "ma compare in %s: %s"
                                  % (os.path.relpath(percorso, progetto),
                                     numero, miei, apparato, nome,
                                     riga.strip()))
        except (OSError, UnicodeDecodeError, SystemExit):
            continue


if __name__ == "__main__":
    sys.exit(main(sys.argv))
