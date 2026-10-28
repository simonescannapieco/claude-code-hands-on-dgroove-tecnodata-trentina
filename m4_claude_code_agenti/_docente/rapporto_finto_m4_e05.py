#!/usr/bin/env python3
"""rapporto_finto_m4_e05.py -- le varianti di un rapporto quotidiano per le
prove di M4-E05 (test_m4_e05.sh e il claude finto).

Esegue lo script di riferimento con gli stessi argomenti e ne piega
l'uscita in una variante che SPECIFICA.md boccia: così la suite prova il
controllo e la verifica su script sbagliati in un modo solo, e dichiarato.
Non è lo script di un partecipante né di Claude.

Uso:    rapporto_finto_m4_e05.py <variante> <riferimento.py> [argomenti]
Varianti:
  giusto          l'uscita del riferimento, com'è
  fine-sbagliata  per la fibra, la fine uguale all'inizio
  senza-linee     il campo linee sempre «-»
  spazi           i campi separati da due spazi invece che da un TAB
  uscita-zero     esce 0 anche con i disservizi
  cartella-zero   senza la cartella dei log esce 0, in silenzio
  giorno-vuoto    senza nessuno dei tre file del giorno esce 0, in silenzio
  errori-stdout   i messaggi di errore su stdout
  bgp             una riga in più per ogni sessione BGP che cade
  ordine          le righe in ordine inverso
  fibra-sola      soltanto le righe della fibra
  prova-fissa     le righe attese dal controllo dello spazio di lavoro il
                  2026-06-02, nient'altro gli altri giorni
  aiuto-stderr    l'aiuto su stderr
  scrive-file     scrive un file nella cartella dei log
Uscita: quella della variante
"""
import os
import re
import subprocess
import sys
from typing import List, Optional, Tuple

FISSE = ["bng-levico-01\t-\t03:10\t03:13\t-\triavvio",
         "sbc-trento-01\t-\t08:00\t08:45\t-\tvoce",
         "dhcp-trento-01\t198.51.100.224/27\t11:00\t11:30\t2\tdhcp",
         "olt-levico-01\t0/1/2\t14:05\t14:50\t3\tfibra",
         "ptp-levico-01\t-\t16:20\t16:21\t-\tradio",
         "ptp-levico-01\t-\t23:55\t-\t-\tradio"]
BGP = re.compile(r"^\S+T(\d\d:\d\d):\S+ (\S+) .*BGP peer .*changed state "
                 r"from Established")


def valore(argomenti: List[str], nome: str) -> Optional[str]:
    """Il valore di --nome, nella forma --nome valore o --nome=valore."""
    for i, arg in enumerate(argomenti):
        if arg == nome and i + 1 < len(argomenti):
            return argomenti[i + 1]
        if arg.startswith(nome + "="):
            return arg.split("=", 1)[1]
    return None


def file_del_giorno(log: str, giorno: str) -> List[str]:
    return [os.path.join(log, "syslog", "syslog_%s.log" % giorno),
            os.path.join(log, "sip", "sbc-trento-01_%s.log" % giorno),
            os.path.join(log, "dhcp", "kea-dhcp4_%s.log" % giorno)]


def righe_bgp(log: str, giorno: str) -> List[str]:
    """Una riga di rapporto per ogni sessione BGP che cade."""
    try:
        with open(file_del_giorno(log, giorno)[0], encoding="utf-8") as fh:
            trovate = [BGP.match(r) for r in fh]
    except OSError:
        return []
    return ["%s\t-\t%s\t-\t-\tradio" % (m.group(2), m.group(1))
            for m in trovate if m]


def piega(variante: str, righe: List[str], rc: int, log: str,
          giorno: str) -> Tuple[List[str], int]:
    """Le righe e l'uscita della variante, su un'uscita riuscita."""
    if variante == "fine-sbagliata":
        righe = [re.sub(r"^([^\t]*\t[^\t]*\t)([^\t]*)\t[^\t]*(\t.*\tfibra)$",
                        r"\1\2\t\2\3", r) for r in righe]
    elif variante == "senza-linee":
        righe = [re.sub(r"^((?:[^\t]*\t){4})[^\t]*", r"\1-", r)
                 for r in righe]
    elif variante == "spazi":
        righe = [r.replace("\t", "  ") for r in righe]
    elif variante == "bgp":
        righe = righe + righe_bgp(log, giorno)
        rc = 1 if righe else rc
    elif variante == "ordine":
        righe = list(reversed(righe))
    elif variante == "fibra-sola":
        righe = [r for r in righe if r.endswith("\tfibra")]
        rc = 1 if righe else 0
    elif variante == "prova-fissa":
        righe = FISSE if giorno == "2026-06-02" else []
        rc = 1 if righe else 0
    if variante == "uscita-zero":
        rc = 0
    return righe, rc


def main(argv: List[str]) -> int:
    variante, riferimento, argomenti = argv[0], argv[1], argv[2:]
    log = valore(argomenti, "--log") or ""
    giorno = valore(argomenti, "--giorno") or ""
    if variante == "cartella-zero" and log and not os.path.isdir(log):
        return 0
    if variante == "giorno-vuoto" and log and os.path.isdir(log) and not any(
            os.path.exists(f) for f in file_del_giorno(log, giorno)):
        return 0
    if variante == "scrive-file" and log and os.path.isdir(log):
        with open(os.path.join(log, "rapporto-finto.txt"), "w",
                  encoding="utf-8") as fh:
            fh.write("(finto)\n")
    fatto = subprocess.run([sys.executable, "-B", riferimento] + argomenti,
                           stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                           check=False)
    out = fatto.stdout.decode("utf-8")
    err = fatto.stderr.decode("utf-8")
    if "--help" in argomenti:
        (sys.stderr if variante == "aiuto-stderr" else sys.stdout).write(out)
        return fatto.returncode
    if fatto.returncode not in (0, 1):
        (sys.stdout if variante == "errori-stdout" else sys.stderr).write(err)
        return fatto.returncode
    righe, rc = piega(variante, [r for r in out.splitlines() if r],
                      fatto.returncode, log, giorno)
    sys.stdout.write("".join(r + "\n" for r in righe))
    sys.stderr.write(err)
    return rc


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
