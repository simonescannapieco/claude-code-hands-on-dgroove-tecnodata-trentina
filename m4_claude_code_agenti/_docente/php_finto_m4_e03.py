#!/usr/bin/env python3
"""php_finto_m4_e03.py -- un tools/php.sh finto per le prove di M4-E03
(test_m4_e03.sh).

La suite lo passa, con la variabile PN_PHP_SH, a verifica.sh, a
soluzione/applica.sh e a _docente/live.sh dell'elemento: così i controlli
girano senza PHP e senza Docker. Non esegue PHP e non è PHPUnit: decide
l'esito dei test da segni scritti nei file di prova della suite,
dichiarati finti, e dal modulo legacy della cartella del progetto.

Comandi, come tools/php.sh, nella cartella corrente:
  composer install [-d <cartella> | --working-dir=<cartella>] [opzioni]
      crea <cartella>/vendor/bin/phpunit (un file segno) e stampa
      «Generating autoload files (finto)»; uscita 0 (FINTO_COMPOSER=ko: 1).
  php -r <codice>
      la prova che PHP parte: uscita 0.
  php <percorso>/vendor/bin/phpunit [-c <cartella>] [opzioni] [file ...]
  phpunit [opzioni] [file ...]
      i test. Il progetto è la cartella di -c, altrimenti la corrente; con
      «phpunit» serve vendor/bin/phpunit nella cartella corrente (se manca,
      il messaggio di tools/php.sh e l'uscita 2). I file sono gli argomenti
      che finiscono in .php, altrimenti tutti i tests/**/*Test.php. Prima
      di tutto un segno di Docker che non parte, senza l'avvio di PHPUnit:
        «FINTO: docker_sulla_rotta»  esce con 125, ma solo sul modulo rotto;
        «FINTO: docker»              esce con 125 sempre.
      Poi la riga d'avvio «PHPUnit (finto)», e per ogni file:
        «FINTO: rosso»      rosso;
        «FINTO: rotto»      esce con 255, come un errore fatale di PHP;
        «FINTO: interrotto» esce con 0 senza il riepilogo, come un die();
        «FINTO: debole»     verde, anche sul modulo rotto;
        senza segni         un test di caratterizzazione: verde se
                            legacy/chiusura_mese.inc.php del progetto ha la
                            riga originale di $simula, rosso se ha quella
                            rotta, rotto (255) se non ha né l'una né l'altra.
      Tutti verdi: «OK (n tests, m assertions)», uscita 0; altrimenti
      «FAILURES!» e il conto, uscita 1.
Env:
  FINTO_PHP_ASSENTE=1  esce con 2 e il messaggio di tools/php.sh quando non
                       trova né PHP né Docker (su STDERR, «php.sh: …»)
  FINTO_PHP_LOG        un file: una riga JSON per invocazione (argv, cwd)
Uscita: 0 · 1 test rossi · 2 errore d'uso o di prerequisiti · 255 «rotto»
"""
import glob
import json
import os
import sys
from typing import List, Optional, Tuple

ORIGINALE = "    $simula = !empty($opzioni['simula']);\n"
ROTTA = "    $simula = true;"
MODULO = os.path.join("legacy", "chiusura_mese.inc.php")


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
    if os.environ.get("FINTO_COMPOSER") == "ko":
        sys.stderr.write("composer (finto): installazione non riuscita\n")
        return 1
    cartella = "."
    for i, arg in enumerate(argv):
        if arg == "-d" and i + 1 < len(argv):
            cartella = argv[i + 1]
        elif arg.startswith("--working-dir="):
            cartella = arg.split("=", 1)[1]
    binari = os.path.join(cartella, "vendor", "bin")
    os.makedirs(binari, exist_ok=True)
    with open(os.path.join(binari, "phpunit"), "w", encoding="utf-8") as fh:
        fh.write("segno del php.sh finto: non è PHPUnit\n")
    print("Generating autoload files (finto)")
    return 0


def stato_modulo(progetto: str) -> str:
    """«originale», «rotto» o «sconosciuto»: il modulo legacy del progetto."""
    try:
        with open(os.path.join(progetto, MODULO), encoding="utf-8") as fh:
            testo = fh.read()
    except OSError:
        return "sconosciuto"
    if ORIGINALE in testo:
        return "originale"
    if ROTTA in testo:
        return "rotto"
    return "sconosciuto"


def esito_file(percorso: str, modulo: str) -> str:
    """verde, rosso, rotto o interrotto, per un file di test."""
    try:
        with open(percorso, encoding="utf-8") as fh:
            testo = fh.read()
    except OSError:
        return "mancante"
    for segno in ("rosso", "rotto", "interrotto", "debole"):
        if "FINTO: " + segno in testo:
            return "verde" if segno == "debole" else segno
    return {"originale": "verde", "rotto": "rosso"}.get(modulo, "rotto")


def file_di_test(progetto: str, argomenti: List[str]) -> List[str]:
    """I file da provare, relativi alla cartella corrente."""
    scelti = [a for a in argomenti if a.endswith(".php")]
    if scelti:
        return scelti
    trovati = glob.glob(os.path.join(progetto, "tests", "**", "*Test.php"),
                        recursive=True)
    return sorted(trovati)


def docker_non_parte(file: List[str], modulo: str) -> bool:
    """Un segno di Docker che non parte, per questo modulo?"""
    for nome in file:
        try:
            with open(nome, encoding="utf-8") as fh:
                testo = fh.read()
        except OSError:
            continue
        if "FINTO: docker_sulla_rotta" in testo:
            if modulo == "rotto":
                return True
        elif "FINTO: docker" in testo:
            return True
    return False


def phpunit(progetto: str, argomenti: List[str]) -> int:
    """Il PHPUnit finto: decide dai segni e dal modulo."""
    modulo = stato_modulo(progetto)
    file = file_di_test(progetto, argomenti)
    if docker_non_parte(file, modulo):
        sys.stderr.write("docker: Error response from daemon (finto)\n")
        return 125
    print("PHPUnit (finto)\n")
    rossi = 0
    eseguiti = 0
    for nome in file:
        esito = esito_file(nome, modulo)
        if esito == "mancante":
            print('Test file "%s" not found' % nome)
            return 2
        if esito == "rotto":
            sys.stderr.write("PHP Fatal error (finto) in %s\n" % nome)
            return 255
        if esito == "interrotto":
            print("Errore nella query (finto)")
            return 0
        eseguiti += 3
        if esito == "rosso":
            rossi += 1
    if eseguiti == 0:
        print("No tests executed!")
        return 1
    if rossi == 0:
        print("OK (%d tests, %d assertions)" % (eseguiti, eseguiti * 2))
        return 0
    print("FAILURES!")
    print("Tests: %d, Assertions: %d, Failures: %d." % (eseguiti, eseguiti * 2,
                                                         rossi))
    return 1


def configurazione(argomenti: List[str]) -> Tuple[Optional[str], List[str]]:
    """La cartella di -c (o --configuration) e gli altri argomenti."""
    cartella = None
    resto = []
    salta = False
    for i, arg in enumerate(argomenti):
        if salta:
            salta = False
            continue
        if arg in ("-c", "--configuration") and i + 1 < len(argomenti):
            cartella = argomenti[i + 1]
            salta = True
        elif arg.startswith("--configuration="):
            cartella = arg.split("=", 1)[1]
        else:
            resto.append(arg)
    return cartella, resto


def php(argv: List[str]) -> int:
    """php -r … oppure php <…>/vendor/bin/phpunit …"""
    if argv[:1] == ["-r"]:
        return 0
    if argv and argv[0].endswith("vendor/bin/phpunit"):
        if not os.path.isfile(argv[0]):
            sys.stderr.write("Could not open input file: %s\n" % argv[0])
            return 1
        cartella, resto = configurazione(argv[1:])
        return phpunit(cartella or ".", resto)
    sys.stderr.write("php.sh (finto): solo «php -r» e «php …/phpunit»\n")
    return 2


def main(argv: List[str]) -> int:
    registra(argv)
    if os.environ.get("FINTO_PHP_ASSENTE") == "1":
        sys.stderr.write("php.sh: servono PHP >= 8.3 o Docker: non trovo né "
                         "l'uno né l'altro\n")
        return 2
    if not argv:
        sys.stderr.write("Uso: tools/php.sh <comando> [argomenti…]\n")
        return 2
    comando, resto = argv[0], argv[1:]
    if comando == "composer":
        return composer(resto)
    if comando == "php":
        return php(resto)
    if comando == "phpunit":
        if not os.path.isfile(os.path.join("vendor", "bin", "phpunit")):
            sys.stderr.write("php.sh: vendor/bin/phpunit non trovato in %s: "
                             "esegui prima «tools/php.sh composer install»\n"
                             % os.getcwd())
            return 2
        return phpunit(".", resto)
    sys.stderr.write("php.sh: comando sconosciuto: %s\n" % comando)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
