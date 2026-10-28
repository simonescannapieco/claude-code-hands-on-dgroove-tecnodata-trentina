#!/usr/bin/env python3
"""php_finto_m4_e01_e02.py -- un tools/php.sh finto per le prove di M4-E01 e
M4-E02 (test_m4_e01.sh, test_m4_e02.sh).

Le suite lo passano, con la variabile PN_PHP_SH, ai verifica.py, ai
soluzione/applica.sh e ai _docente/live.sh dei due elementi: così i
controlli girano senza PHP e senza Docker. Non esegue PHP: decide l'esito
dei test da segni scritti nei file di prova delle suite, dichiarati finti.
I test veri del gestionale (senza segni) per lui sono verdi.

Comandi, come tools/php.sh, nella cartella corrente:
  composer install [-d <cartella> | --working-dir=<cartella>] [opzioni]
      crea <cartella>/vendor/bin/phpunit (un file segno, non PHPUnit) e
      stampa «Generating autoload files (finto)»; uscita 0.
  phpunit [opzioni] [file ...]
      vuole vendor/bin/phpunit nella cartella corrente, altrimenti il
      messaggio di tools/php.sh e l'uscita 2. I file di test sono gli
      argomenti che finiscono in .php, o tutti i tests/**/*Test.php.
      Un file è rosso se contiene «FINTO: rosso», o se una sua riga
      «FINTO-RICHIEDE: <testo>» nomina un testo che nessun file di src/
      contiene; «FINTO: rotto» esce con 255, come un errore fatale di PHP.
      Tutti verdi: «OK (n tests, n assertions)» e uscita 0; altrimenti
      «FAILURES!» con l'elenco e uscita 1.
Env:
  FINTO_PHP_ASSENTE=1  esce con 2 e il messaggio di tools/php.sh quando
                       non trova né PHP né Docker (su STDERR, «php.sh: …»)
  FINTO_PHP_LOG        un file: una riga JSON per invocazione (argv, cwd)
Uscita: 0 · 1 test rossi · 2 errore d'uso o di prerequisiti · 255 «rotto»
"""
import json
import os
import sys
from typing import List

SEGNO_ROSSO = "FINTO: rosso"
SEGNO_ROTTO = "FINTO: rotto"
SEGNO_RICHIEDE = "FINTO-RICHIEDE:"


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
    i = 1
    while i < len(argv):
        if argv[i] == "-d" and i + 1 < len(argv):
            cartella = argv[i + 1]
            i += 2
            continue
        if argv[i].startswith("--working-dir="):
            cartella = argv[i].split("=", 1)[1]
        i += 1
    if not os.path.isfile(os.path.join(cartella, "composer.json")):
        sys.stderr.write("Composer could not find a composer.json file in "
                         "%s (finto)\n" % cartella)
        return 1
    bin_dir = os.path.join(cartella, "vendor", "bin")
    os.makedirs(bin_dir, exist_ok=True)
    with open(os.path.join(bin_dir, "phpunit"), "w", encoding="utf-8") as fh:
        fh.write("segno del php.sh finto: non è PHPUnit\n")
    print("Generating autoload files (finto)")
    return 0


def file_di_test(argv: List[str]) -> List[str]:
    """I file da eseguire: gli argomenti .php, o tutti i *Test.php."""
    scelti = [a for a in argv if a.endswith(".php")]
    if scelti:
        return scelti
    trovati = []
    for radice, _cartelle, nomi in os.walk("tests"):
        for nome in sorted(nomi):
            if nome.endswith("Test.php"):
                trovati.append(os.path.join(radice, nome))
    return sorted(trovati)


def sorgenti() -> str:
    """Il testo di tutti i file di src/, per i segni FINTO-RICHIEDE."""
    parti = []
    for radice, _cartelle, nomi in os.walk("src"):
        for nome in nomi:
            with open(os.path.join(radice, nome), encoding="utf-8",
                      errors="replace") as fh:
                parti.append(fh.read())
    return "\n".join(parti)


def esito(percorso: str, src: str) -> str:
    """«verde», «rosso» o «rotto» di un file di test."""
    if not os.path.isfile(percorso):
        return "rotto"
    with open(percorso, encoding="utf-8", errors="replace") as fh:
        testo = fh.read()
    if SEGNO_ROTTO in testo:
        return "rotto"
    if SEGNO_ROSSO in testo:
        return "rosso"
    for riga in testo.splitlines():
        if SEGNO_RICHIEDE in riga:
            richiesto = riga.split(SEGNO_RICHIEDE, 1)[1].strip()
            if richiesto and richiesto not in src:
                return "rosso"
    return "verde"


def phpunit(argv: List[str]) -> int:
    """phpunit sui file di test, con l'esito dai segni."""
    if not os.path.isfile(os.path.join("vendor", "bin", "phpunit")):
        sys.stderr.write("php.sh: vendor/bin/phpunit non trovato in %s: "
                         "esegui prima «tools/php.sh composer install»\n"
                         % os.getcwd())
        return 2
    src = sorgenti()
    esiti = {f: esito(f, src) for f in file_di_test(argv)}
    print("PHPUnit (finto) dei test di M4-E01 e M4-E02")
    if any(e == "rotto" for e in esiti.values()):
        print("PHP Fatal error (finto) in %s" % ", ".join(
            f for f, e in sorted(esiti.items()) if e == "rotto"))
        return 255
    rossi = sorted(f for f, e in esiti.items() if e == "rosso")
    if rossi:
        print("FAILURES!")
        for f in rossi:
            print("  rosso: %s" % f)
        print("Tests: %d, Failures: %d." % (len(esiti), len(rossi)))
        return 1
    print("OK (%d tests, %d assertions)" % (len(esiti), 2 * len(esiti)))
    return 0


def main(argv: List[str]) -> int:
    registra(argv)
    if os.environ.get("FINTO_PHP_ASSENTE") == "1":
        sys.stderr.write("php.sh: servono PHP >= 8.3 o Docker: non trovo "
                         "né l'uno né l'altro\n")
        return 2
    if not argv:
        sys.stderr.write("Uso: php.sh <comando> [argomenti…] (finto)\n")
        return 2
    if argv[0] == "composer":
        return composer(argv[1:])
    if argv[0] == "phpunit":
        return phpunit(argv[1:])
    sys.stderr.write("php.sh: comando sconosciuto per il finto: %s\n"
                     % argv[0])
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
