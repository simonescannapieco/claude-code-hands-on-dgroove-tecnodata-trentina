#!/usr/bin/env python3
"""anonimizza.py -- la settimana di ticket senza dati personali.

Legge dati/ticket-settimana.csv (il dizionario delle colonne è
dati/README.md) e scrive anonimo/ticket-anonimi.csv: UTF-8 senza BOM, fine
riga LF, le stesse righe nello stesso ordine, 17 colonne. Toglie
nome_cliente, telefono, email e id_linea; al posto di id_cliente mette in
cliente uno pseudonimo C-001, C-002, … in ordine di prima comparsa; in
oggetto e descrizione sostituisce con [OMESSO] ogni dato personale; le
altre colonne restano come sono.

I dati personali si trovano senza averli mai visti:
  - dalle colonne del file stesso: i nomi dei clienti (le ragioni sociali
    anche senza forma giuridica e, per una ditta «… di Nome Cognome», il
    titolare), i telefoni, le e-mail, i codici cliente e di linea; i
    cognomi dei clienti privati, per riconoscere referenti e familiari
    («Nome Cognome» con uno di quei cognomi);
  - con espressioni regolari: e-mail (anche le utenze PPPoE), indirizzi MAC
    e IPv4, telefoni, codici CL- e LN-, indirizzi (Via, Viale, Vicolo,
    Piazza, Largo, Località… con il civico), l'età («NN anni») e le parole
    della salute.

Uso:    python3 anonimizza.py [entrata] [uscita]
          default dati/ticket-settimana.csv e anonimo/ticket-anonimi.csv
"""
import csv
import os
import re
import sys

ENTRATA = os.path.join("dati", "ticket-settimana.csv")
USCITA = os.path.join("anonimo", "ticket-anonimi.csv")
OMESSO = "[OMESSO]"
COLONNE = ("id_ticket", "aperto_il", "chiuso_il", "canale", "cliente",
           "tipo_cliente", "comune", "tecnologia", "categoria", "priorita",
           "stato", "oggetto", "descrizione", "team",
           "minuti_prima_risposta", "minuti_risoluzione", "soddisfazione")
FORMA_GIURIDICA = re.compile(r"\s+S\.\s?(?:r\.\s?l|n\.\s?c|a\.\s?s)\.?$",
                             re.IGNORECASE)
DITTA = re.compile(r"\s+di\s+", re.IGNORECASE)
REGOLE = (
    re.compile(r"[\w.%+-]+@[\w-]+(?:\.[\w-]+)+"),                  # e-mail
    re.compile(r"\b[0-9A-Fa-f]{2}(?:[:-][0-9A-Fa-f]{2}){5}\b"),     # MAC
    re.compile(r"\b\d{1,3}(?:\.\d{1,3}){3}\b"),                     # IPv4
    re.compile(r"\+\d{2}(?:[ .-]?\d){8,11}\b"),                     # telefoni
    re.compile(r"(?<![\w-])0\d(?:[ .-]?\d){7,10}\b"),
    re.compile(r"\b(?:CL|LN)-\d{6}\b"),                             # codici
    re.compile(r"\b(?:Via|Viale|Vicolo|Piazza|Piazzale|Largo|Corso|Strada"
               r"|Località)\s+(?:[^\W\d_][\w'’]*\s+){0,4}?\d+[A-Za-z]?\b"),
    re.compile(r"\b\d{1,3}\s+anni\b"),                              # età
    re.compile(r"\b(?:telesoccorso|salvavita|pacemaker|dialisi|disabil\w*"
               r"|invalidit\w*|malatti\w*|ricover\w*)\b", re.IGNORECASE),
)


def nomi_e_cognomi(righe):
    """I nomi dei clienti, in tutte le forme da cercare, e i cognomi dei
    clienti privati."""
    nomi, cognomi = set(), set()
    for r in righe:
        nome = r["nome_cliente"].strip()
        if not nome:
            continue
        nomi.add(nome)
        if r["tipo_cliente"] == "privato":
            cognomi.add(nome.split()[-1].capitalize())
            continue
        senza_forma = FORMA_GIURIDICA.sub("", nome)
        nomi.add(senza_forma)
        nomi.update(DITTA.split(senza_forma, maxsplit=1))
    return nomi, cognomi


def valori_dalle_colonne(righe):
    """Telefoni, e-mail, codici e utenze PPPoE delle colonne del file."""
    valori = set()
    for r in righe:
        for colonna in ("telefono", "email", "id_cliente", "id_linea"):
            if r[colonna].strip():
                valori.add(r[colonna].strip())
        if r["id_linea"].strip():
            valori.add(r["id_linea"].replace("-", "").lower())
    return valori


def alternativa(parole):
    """Una sola espressione regolare per un elenco di testi esatti, i più
    lunghi prima, come parole intere e senza badare alle maiuscole."""
    ordinate = sorted(parole, key=len, reverse=True)
    corpo = "|".join(re.escape(p) for p in ordinate)
    return re.compile(r"(?<!\w)(?:%s)(?!\w)" % corpo, re.IGNORECASE)


def regole_del_file(righe):
    """Le espressioni che dipendono dal file: i valori esatti e le persone
    con il cognome di un cliente privato."""
    nomi, cognomi = nomi_e_cognomi(righe)
    esatti = alternativa(nomi | valori_dalle_colonne(righe))
    persone = re.compile(r"\b[A-ZÀ-Ý][a-zà-ÿ]+\s+(?:%s)\b" % "|".join(
        re.escape(c) for c in sorted(cognomi)))
    return esatti, persone


def anonimizza_testo(testo, esatti, persone):
    """Il testo con ogni dato personale sostituito da [OMESSO]: prima le
    e-mail (un'utenza PPPoE contiene il codice della linea), poi i valori
    esatti, le altre regole e le persone."""
    testo = REGOLE[0].sub(OMESSO, testo)
    testo = esatti.sub(OMESSO, testo)
    for regola in REGOLE[1:]:
        testo = regola.sub(OMESSO, testo)
    return persone.sub(OMESSO, testo)


def main(argv):
    entrata = argv[0] if len(argv) > 0 else ENTRATA
    uscita = argv[1] if len(argv) > 1 else USCITA
    with open(entrata, encoding="utf-8", newline="") as fh:
        righe = list(csv.DictReader(fh))
    esatti, persone = regole_del_file(righe)
    pseudonimi = {}
    cartella = os.path.dirname(uscita)
    if cartella:
        os.makedirs(cartella, exist_ok=True)
    with open(uscita, "w", encoding="utf-8", newline="") as fh:
        scrittore = csv.writer(fh, lineterminator="\n")
        scrittore.writerow(COLONNE)
        for r in righe:
            codice = r["id_cliente"].strip()
            if codice and codice not in pseudonimi:
                pseudonimi[codice] = "C-%03d" % (len(pseudonimi) + 1)
            nuova = dict(r, cliente=pseudonimi.get(codice, ""))
            for colonna in ("oggetto", "descrizione"):
                nuova[colonna] = anonimizza_testo(r[colonna], esatti, persone)
            scrittore.writerow([nuova[c] for c in COLONNE])
    print("anonimizza: %d righe scritte in %s, %d clienti con uno pseudonimo."
          % (len(righe), uscita, len(pseudonimi)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
