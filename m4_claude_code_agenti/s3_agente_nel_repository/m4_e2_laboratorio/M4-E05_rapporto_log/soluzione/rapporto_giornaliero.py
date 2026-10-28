#!/usr/bin/env python3
"""rapporto_giornaliero.py -- il rapporto quotidiano dei disservizi della
rete, come lo chiede SPECIFICA.md: legge i log di un giorno (syslog, SBC
SIP, DHCP) e stampa una riga per disservizio, in ordine di inizio, con sei
campi separati da un TAB: apparato, porta, inizio, fine, linee, tipo.

Uso:    python3 rapporto_giornaliero.py [--giorno AAAA-MM-GG]
                                        [--log <cartella>] [--help]
        --giorno  il giorno del rapporto (di norma il giorno prima)
        --log     la cartella dei log (di norma progetti/rete/log accanto
                  a questo script)
Uscita: 0 nessun disservizio · 1 almeno un disservizio · 2 il rapporto non
        si può fare (la cartella dei log non c'è, manca un file del
        giorno, un giorno non valido, un'opzione sconosciuta)
"""
import datetime
import os
import re
import sys
from typing import Dict, FrozenSet, List, Optional, Set, Tuple

QUI = os.path.dirname(os.path.abspath(__file__))
USO = ("Uso: python3 rapporto_giornaliero.py [--giorno AAAA-MM-GG] "
       "[--log <cartella>] [--help]\n"
       "  --giorno AAAA-MM-GG  il giorno del rapporto (di norma il giorno "
       "prima)\n"
       "  --log <cartella>     la cartella dei log (di norma progetti/rete/log"
       " accanto allo script)\n"
       "Uscita: 0 nessun disservizio, 1 almeno un disservizio, 2 il rapporto "
       "non si può fare.\n")
SYSLOG = re.compile(r"^\d{4}-\d\d-\d\dT(\d\d:\d\d):\d\d\S* (\S+) (.*)$")
PON_LOS = re.compile(r"PON_LOS: frame (\d+) slot (\d+) port (\d+)")
PON_CLEAR = re.compile(r"PON_LOS_CLEAR: frame (\d+) slot (\d+) port (\d+)")
ONT_LOS = re.compile(r"ONT_OFFLINE: frame (\d+) slot (\d+) port (\d+) "
                     r"ONT (\d+) .*cause LOS")
LINK = re.compile(r"link to \S+ (lost|established)")
SET = re.compile(r"destination \S+ \(set (\d+)\) marked (inactive|active)")
DHCP = re.compile(r"^\S+ (\d\d:\d\d):\S+ .*ALLOC_ENGINE_V4_ALLOC_FAIL_SUBNET "
                  r"\[hwtype=\d+ ([0-9A-Fa-f:]+)\].* in the subnet "
                  r"([0-9.]+/[0-9]+)")
# apparato, porta, inizio, fine, linee, tipo
Disservizio = Tuple[str, str, str, str, str, str]


class Errore(Exception):
    """Il rapporto non si può fare: uscita 2."""


def opzioni(argv: List[str]) -> Optional[Tuple[str, str]]:
    """Il giorno e la cartella dei log, oppure None dopo l'aiuto stampato;
    Errore su un'opzione sconosciuta o su un giorno non valido."""
    valori = {}  # type: Dict[str, str]
    i = 0
    while i < len(argv):
        if argv[i] in ("--help", "-h"):
            sys.stdout.write(USO)
            return None
        nome, uguale, valore = argv[i].partition("=")
        if nome not in ("--giorno", "--log"):
            raise Errore("opzione sconosciuta: %s\n%s" % (argv[i],
                                                         USO.rstrip()))
        if not uguale:
            if i + 1 >= len(argv):
                raise Errore("%s vuole un valore\n%s" % (nome, USO.rstrip()))
            i += 1
            valore = argv[i]
        valori[nome] = valore
        i += 1
    giorno = valori.get("--giorno") or (
        datetime.date.today() - datetime.timedelta(days=1)).isoformat()
    try:
        datetime.date.fromisoformat(giorno)
    except ValueError:
        raise Errore("giorno non valido: %s (atteso AAAA-MM-GG)" % giorno)
    return giorno, valori.get("--log") or os.path.join(QUI, "progetti",
                                                       "rete", "log")


def leggi_giorno(log: str, giorno: str) -> Dict[str, List[str]]:
    """Le righe dei tre file del giorno; Errore se uno manca."""
    if not os.path.isdir(log):
        raise Errore("la cartella dei log non c'è: %s" % log)
    file = {"syslog": os.path.join(log, "syslog", "syslog_%s.log" % giorno),
            "sip": os.path.join(log, "sip", "sbc-trento-01_%s.log" % giorno),
            "dhcp": os.path.join(log, "dhcp", "kea-dhcp4_%s.log" % giorno)}
    righe = {}
    for nome, percorso in file.items():
        try:
            with open(percorso, encoding="utf-8", errors="replace") as fh:
                righe[nome] = fh.read().splitlines()
        except OSError as exc:
            raise Errore("manca il file %s (%s)" % (
                percorso, exc.strerror or type(exc).__name__))
    return righe


def porta(m: "re.Match") -> str:
    return "%s/%s/%s" % m.group(1, 2, 3)


def dal_syslog(righe: List[str]) -> List[Disservizio]:
    """Fibra, radio e riavvii, dal syslog; chi non si chiude ha fine «-»."""
    trovati = []  # type: List[Disservizio]
    pon = {}  # type: Dict[Tuple[str, str], Tuple[str, Set[str]]]
    radio = {}  # type: Dict[str, str]
    riavvii = {}  # type: Dict[str, str]
    for riga in righe:
        m = SYSLOG.match(riga)
        if m is None:
            continue
        ora, apparato, messaggio = m.groups()
        los, clear = PON_LOS.search(messaggio), PON_CLEAR.search(messaggio)
        ont = ONT_LOS.search(messaggio)
        link = LINK.search(messaggio) if apparato.startswith("ptp-") else None
        if los:
            pon[(apparato, porta(los))] = (ora, set())
        elif ont and (apparato, porta(ont)) in pon:
            pon[(apparato, porta(ont))][1].add(ont.group(4))
        elif clear and (apparato, porta(clear)) in pon:
            inizio, onts = pon.pop((apparato, porta(clear)))
            trovati.append((apparato, porta(clear), inizio, ora,
                            str(len(onts)), "fibra"))
        elif link and link.group(1) == "lost":
            radio.setdefault(apparato, ora)
        elif link and apparato in radio:
            trovati.append((apparato, "-", radio.pop(apparato), ora, "-",
                            "radio"))
        elif "rebooting" in messaggio:
            riavvii.setdefault(apparato, ora)
        elif "router rebooted" in messaggio and apparato in riavvii:
            trovati.append((apparato, "-", riavvii.pop(apparato), ora, "-",
                            "riavvio"))
    trovati += [(a, p, i, "-", str(len(o)), "fibra")
                for (a, p), (i, o) in pon.items()]
    trovati += [(a, "-", i, "-", "-", "radio") for a, i in radio.items()]
    trovati += [(a, "-", i, "-", "-", "riavvio") for a, i in riavvii.items()]
    return trovati


def dal_sip(righe: List[str]) -> List[Disservizio]:
    """Le destinazioni del dispatcher segnate inattive, per gruppo."""
    trovati = []  # type: List[Disservizio]
    aperti = {}  # type: Dict[str, Tuple[str, str]]
    for riga in righe:
        m = SYSLOG.match(riga)
        s = SET.search(m.group(3)) if m else None
        if m is None or s is None:
            continue
        if s.group(2) == "inactive":
            aperti.setdefault(s.group(1), (m.group(2), m.group(1)))
        elif s.group(1) in aperti:
            apparato, inizio = aperti.pop(s.group(1))
            trovati.append((apparato, "-", inizio, m.group(1), "-", "voce"))
    trovati += [(a, "-", i, "-", "-", "voce") for a, i in aperti.values()]
    return trovati


def dal_dhcp(righe: List[str]) -> List[Disservizio]:
    """I pool senza indirizzi: la prima e l'ultima richiesta rifiutata di
    ogni subnet, e i client rifiutati."""
    reti = {}  # type: Dict[str, Tuple[str, str, FrozenSet[str]]]
    for riga in righe:
        m = DHCP.match(riga)
        if m is None:
            continue
        ora, mac, subnet = m.groups()
        inizio, _, client = reti.get(subnet, (ora, ora, frozenset()))
        reti[subnet] = (inizio, ora, client | {mac.lower()})
    return [("dhcp-trento-01", s, i, f, str(len(c)), "dhcp")
            for s, (i, f, c) in reti.items()]


def main(argv: List[str]) -> int:
    try:
        scelte = opzioni(argv)
        if scelte is None:
            return 0
        giorno, log = scelte
        righe = leggi_giorno(log, giorno)
    except Errore as exc:
        sys.stderr.write("rapporto_giornaliero: %s\n" % exc)
        return 2
    disservizi = sorted(dal_syslog(righe["syslog"]) + dal_sip(righe["sip"])
                        + dal_dhcp(righe["dhcp"]),
                        key=lambda d: (d[2], d[0]))
    sys.stdout.write("".join("\t".join(d) + "\n" for d in disservizi))
    return 1 if disservizi else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
