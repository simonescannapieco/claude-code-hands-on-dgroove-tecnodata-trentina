#!/usr/bin/env python3
"""controlla_rapporto.py -- il controllo da eseguire dopo ogni passo: prova
rapporto_giornaliero.py (o rapporto_giornaliero.sh) su piccole cartelle di
log di prova e lo confronta con SPECIFICA.md.

Crea i log di prova in una cartella temporanea, nei formati dei log di
progetti/rete/log, con apparati inventati: un giorno con un disservizio per
tipo (e uno che a fine giornata non si è chiuso) accanto al rumore di fondo
di una settimana qualunque; un giorno tranquillo, con il rumore soltanto;
un giorno senza file; un giorno a cui manca il file dell'SBC. Esegue lo
script in otto casi: --help; il giorno con i disservizi; il giorno
tranquillo; la cartella dei log che manca; il giorno senza file; il file
che manca; un giorno non valido; un'opzione sconosciuta. Per ogni caso
confronta uscita, stdout e stderr con la specifica e stampa «ok» o «NO» con
il motivo. Alla fine cancella i log di prova. Non conosce i disservizi
della settimana dei log di esempio: quelli li trova lo script.

Uso:    python3 controlla_rapporto.py
Uscita: l'ultima riga la ripete, «uscita: N». 0 tutti i casi come la
        specifica · 1 almeno un caso no · 2 il controllo non può girare
        (nessuno script, o tutti e due)
"""
import collections
import hashlib
import os
import re
import shutil
import subprocess
import sys
import tempfile
from typing import Dict, List, Sequence, Set, Tuple

SCRIPT_PY = "rapporto_giornaliero.py"
SCRIPT_SH = "rapporto_giornaliero.sh"
TIPI = ("fibra", "radio", "riavvio", "voce", "dhcp")
TEMPO_MASSIMO = 120
ORA = re.compile(r"[0-2][0-9]:[0-5][0-9]")
GIORNO, TRANQUILLO, SENZA_FILE, SENZA_SIP = (
    "2026-06-02", "2026-06-01", "2026-06-03", "2026-06-04")
ATTESE = {("bng-levico-01", "-", "03:10", "03:13", "-", "riavvio"),
          ("sbc-trento-01", "-", "08:00", "08:45", "-", "voce"),
          ("dhcp-trento-01", "198.51.100.224/27", "11:00", "11:30", "2",
           "dhcp"),
          ("olt-levico-01", "0/1/2", "14:05", "14:50", "3", "fibra"),
          ("ptp-levico-01", "-", "16:20", "16:21", "-", "radio"),
          ("ptp-levico-01", "-", "23:55", "-", "-", "radio")}

Esito = collections.namedtuple("Esito", "rc out err")
Caso = collections.namedtuple("Caso", "nome ok motivi")
Righe = collections.namedtuple("Righe", "disservizi altre")


class Precondizione(Exception):
    """Il controllo non può girare: uscita 2."""


# --- i log di prova -------------------------------------------------------

def _gpon(giorno: str, ora: str, testo: str) -> str:
    return "%sT%s+02:00 olt-levico-01 %%%%GPON/%s" % (giorno, ora, testo)


def _rumore(giorno: str) -> List[str]:
    """Il rumore di fondo del syslog: niente che sia un disservizio."""
    sn = "SN CSLKA000000"
    return [
        "%sT00:15:02+02:00 olt-levico-01 %%%%NTP/4/SOURCE_LOST: NTP server "
        "192.0.2.44 unreachable, clock not synchronized" % giorno,
        "%sT09:31:59+02:00 core-trento-01 %%SEC_LOGIN-5-LOGIN_SUCCESS: Login "
        "Success [user: noc] [Source: 192.0.2.50] [localport: 22]" % giorno,
        _gpon(giorno, "09:20:11", "4/ONT_OFFLINE: frame 0 slot 1 port 1 ONT "
              "4 %s4 offline, cause dying-gasp" % sn),
        _gpon(giorno, "09:22:40", "5/ONT_ONLINE: frame 0 slot 1 port 1 ONT 4 "
              "%s4 online" % sn),
        "%sT18:00:00+02:00 bts-levico-01 wireless,info 00:00:5E:00:53:B5@"
        "wlan-s1: disconnected, extensive data loss, signal strength -80"
        % giorno,
        "%sT18:02:00+02:00 bts-levico-01 wireless,info 00:00:5E:00:53:B5@"
        "wlan-s1: connected, signal strength -66" % giorno,
        "%sT21:41:07+02:00 bdr-trento-01 rpd[2201]: RPD_BGP_NEIGHBOR_STATE_"
        "CHANGED: BGP peer 203.0.113.133 (External AS 64497) changed state "
        "from Established to Idle (event HoldTime)" % giorno,
        "%sT21:44:12+02:00 bdr-trento-01 rpd[2201]: RPD_BGP_NEIGHBOR_STATE_"
        "CHANGED: BGP peer 203.0.113.133 (External AS 64497) changed state "
        "from OpenConfirm to Established (event RecvKeepAlive)" % giorno]


def _disservizi(giorno: str) -> List[str]:
    """Le righe del syslog dei disservizi di prova."""
    ptp = "%sT%s+02:00 ptp-levico-01 wireless: ath0: link to 00:00:5E:00:53:21"
    sn = "SN CSLKA00000"
    righe = [
        "%sT03:10:00+02:00 bng-levico-01 system,info,critical upgrade "
        "7.15.3 -> 7.16.2: rebooting by user noc" % giorno,
        "%sT03:13:30+02:00 bng-levico-01 system,info,critical router "
        "rebooted" % giorno,
        _gpon(giorno, "14:05:10", "2/PON_LOS: frame 0 slot 1 port 2 loss of "
              "signal, 3 ONT affected")]
    righe += [_gpon(giorno, "14:05:1%d" % n, "4/ONT_OFFLINE: frame 0 slot 1 "
                    "port 2 ONT %d %s1%d offline, cause LOS" % (n, sn, n))
              for n in range(3)]
    righe += [
        _gpon(giorno, "14:30:00", "4/ONT_OFFLINE: frame 0 slot 1 port 1 ONT 6 "
              "%s06 offline, cause dying-gasp" % sn),
        _gpon(giorno, "14:50:03", "5/PON_LOS_CLEAR: frame 0 slot 1 port 2 "
              "optical signal restored")]
    righe += [_gpon(giorno, "14:50:2%d" % n, "5/ONT_ONLINE: frame 0 slot 1 "
                    "port 2 ONT %d %s1%d online" % (n, sn, n))
              for n in range(3)]
    righe += [(ptp % (giorno, "16:20:05")) + " lost (last signal -81 dBm)",
              (ptp % (giorno, "16:21:40")) + " established (signal -69 dBm, "
              "capacity 160/170 Mbps)",
              (ptp % (giorno, "23:55:00")) + " lost (last signal -82 dBm)"]
    return righe


def _sip(giorno: str, disservizio: bool) -> List[str]:
    testa = "%sT%s+02:00 sbc-trento-01 kamailio[2318]: "
    registra = ("NOTICE: <script>: REGISTER sip:voce.ciaspolink.example.org "
                "from sip:ln009001@voce.ciaspolink.example.org "
                "src=198.51.100.10:5060 -> %s")
    righe = [(testa % (giorno, "07:58:00")) + registra % "200 OK"]
    if disservizio:
        righe += [
            (testa % (giorno, "08:00:10")) + "ERROR: dispatcher: destination "
            "sip:192.0.2.40:5070 (set 2) marked inactive",
            (testa % (giorno, "08:10:00")) + registra % "503 Service "
            "Unavailable",
            (testa % (giorno, "08:44:50")) + "INFO: dispatcher: set 2: loaded "
            "destination sip:192.0.2.40:5060",
            (testa % (giorno, "08:45:20")) + "NOTICE: dispatcher: destination "
            "sip:192.0.2.40:5060 (set 2) marked active"]
    return righe + [(testa % (giorno, "12:05:16")) + registra % "200 OK"]


def _dhcp(giorno: str, disservizio: bool) -> List[str]:
    testa = "%s %s WARN  [kea-dhcp4.alloc-engine/2210.139871022552832] "
    righe = ["%s 10:58:00.100 INFO  [kea-dhcp4.leases/2210.139871022552832] "
             "DHCP4_LEASE_ALLOC [hwtype=1 00:00:5e:00:53:a1], cid=[no info], "
             "tid=0x1a2b3c01: lease 198.51.100.225 has been allocated for "
             "604800 seconds" % giorno]
    if disservizio:
        for ora, mac in (("11:00:00", "a2"), ("11:15:00", "a3"),
                         ("11:30:00", "a2")):
            client = "[hwtype=1 00:00:5e:00:53:%s], cid=[no info], " \
                "tid=0x1a2b3c02: failed to allocate an IPv4 address " % mac
            righe += [
                (testa % (giorno, ora + ".200")) + "ALLOC_ENGINE_V4_"
                "ALLOC_FAIL_SUBNET " + client + "in the subnet "
                "198.51.100.224/27, subnet-id 210, shared network (none)",
                (testa % (giorno, ora + ".201")) + "ALLOC_ENGINE_V4_"
                "ALLOC_FAIL " + client + "after 14 attempt(s)"]
    return righe


def scrivi(percorso: str, righe: Sequence[str]) -> None:
    os.makedirs(os.path.dirname(percorso), exist_ok=True)
    with open(percorso, "w", encoding="utf-8") as fh:
        fh.write("".join(r + "\n" for r in righe))


def crea_log(cartella: str) -> None:
    """La cartella dei log di prova: quattro giorni, uno per caso."""
    for giorno, disservizio, con_sip in ((TRANQUILLO, False, True),
                                         (GIORNO, True, True),
                                         (SENZA_SIP, False, False)):
        syslog = _rumore(giorno) + (_disservizi(giorno) if disservizio
                                    else [])
        scrivi(os.path.join(cartella, "syslog", "syslog_%s.log" % giorno),
               sorted(syslog))
        if con_sip:
            scrivi(os.path.join(cartella, "sip", "sbc-trento-01_%s.log"
                                % giorno), _sip(giorno, disservizio))
        scrivi(os.path.join(cartella, "dhcp", "kea-dhcp4_%s.log" % giorno),
               _dhcp(giorno, disservizio))


# --- eseguire lo script e leggerne l'uscita -------------------------------

def comando(radice: str) -> List[str]:
    """Il comando dello script dello spazio di lavoro: uno, non due."""
    py = os.path.join(radice, SCRIPT_PY)
    sh = os.path.join(radice, SCRIPT_SH)
    if os.path.isfile(py) and os.path.isfile(sh):
        raise Precondizione("ci sono tutti e due, %s e %s: tenetene uno solo"
                            % (SCRIPT_PY, SCRIPT_SH))
    if os.path.isfile(py):
        return [sys.executable, "-B", py]
    if os.path.isfile(sh):
        return ["bash", sh]
    raise Precondizione("manca %s (o %s): scrivetene uno, poi ripetete il "
                        "controllo" % (SCRIPT_PY, SCRIPT_SH))


def esegui(script: Sequence[str], argomenti: Sequence[str],
           cartella: str) -> Esito:
    """Lo script con gli argomenti, nella cartella data."""
    try:
        fatto = subprocess.run(list(script) + list(argomenti), cwd=cartella,
                               stdin=subprocess.DEVNULL,
                               stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                               timeout=TEMPO_MASSIMO, check=False)
    except subprocess.TimeoutExpired:
        return Esito(124, "", "nessuna risposta in %d secondi"
                     % TEMPO_MASSIMO)
    return Esito(fatto.returncode, fatto.stdout.decode("utf-8", "replace"),
                 fatto.stderr.decode("utf-8", "replace"))


def campi_validi(campi: Sequence[str]) -> bool:
    return (len(campi) >= 6 and all(campi[:6])
            and ORA.fullmatch(campi[2]) is not None
            and (campi[3] == "-" or ORA.fullmatch(campi[3]) is not None)
            and (campi[4] == "-" or campi[4].isdigit())
            and campi[5] in TIPI)


def leggi_righe(testo: str) -> Righe:
    """Le righe di stdout: i disservizi (i primi sei campi, separati da un
    TAB) e le righe che non sono nel formato."""
    disservizi = []  # type: List[Tuple[str, ...]]
    altre = []  # type: List[str]
    for riga in testo.splitlines():
        if not riga.strip():
            continue
        campi = [c.strip() for c in riga.split("\t")]
        if campi_validi(campi):
            disservizi.append(tuple(campi[:6]))
        else:
            altre.append(riga)
    return Righe(disservizi, altre)


def fotografia(cartella: str) -> Dict[str, str]:
    """I file della cartella, ciascuno con la sua impronta."""
    foto = {}
    for base, _, file in os.walk(cartella):
        for nome in file:
            percorso = os.path.join(base, nome)
            with open(percorso, "rb") as fh:
                foto[os.path.relpath(percorso, cartella)] = hashlib.sha256(
                    fh.read()).hexdigest()
    return foto


def mostra(testo: str) -> str:
    righe = [r for r in testo.strip().splitlines() if r.strip()]
    corto = " | ".join(righe[:3])
    return "«%s»" % (corto if len(corto) <= 160 else corto[:159] + "…")


def elenco(righe: Set[Tuple[str, ...]]) -> str:
    return "; ".join(" ".join(r) for r in sorted(righe))


# --- gli otto casi --------------------------------------------------------

def motivi_rapporto(esito: Esito, attese: Set[Tuple[str, ...]],
                    rc_atteso: int, prima: Dict[str, str],
                    dopo: Dict[str, str]) -> List[str]:
    """I motivi per cui un rapporto su un giorno di prova non torna."""
    motivi = []
    if esito.rc != rc_atteso:
        motivi.append("uscita %d, attesa %d" % (esito.rc, rc_atteso))
    letta = leggi_righe(esito.out)
    trovate = set(letta.disservizi)
    if attese - trovate:
        motivi.append("attese e non trovate: %s" % elenco(attese - trovate))
    if trovate - attese:
        motivi.append("trovate e non attese: %s" % elenco(trovate - attese))
    if len(trovate) != len(letta.disservizi):
        motivi.append("una riga ripetuta")
    ordine = [(r[2], r[0]) for r in letta.disservizi]
    if ordine != sorted(ordine):
        motivi.append("le righe non sono in ordine di inizio")
    if letta.altre:
        motivi.append("righe che non sono nel formato (sei campi separati da "
                      "un TAB): %s" % mostra("\n".join(letta.altre)))
    if esito.err.strip():
        motivi.append("su stderr, a lavoro riuscito: %s" % mostra(esito.err))
    if prima != dopo:
        motivi.append("la cartella dei log è cambiata: il rapporto legge "
                      "soltanto")
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


def casi(script: Sequence[str]) -> List[Caso]:
    """Gli otto casi, sui log di prova in una cartella temporanea."""
    with tempfile.TemporaryDirectory(prefix="controlla-rapporto.") as tmp:
        log = os.path.join(tmp, "log")
        crea_log(log)
        return _casi(script, tmp, log)


def _casi(script: Sequence[str], tmp: str, log: str) -> List[Caso]:
    risultati = []
    esito = esegui(script, ["--help"], tmp)
    motivi = [] if esito.rc == 0 else ["uscita %d, attesa 0" % esito.rc]
    if "--giorno" not in esito.out or "--log" not in esito.out:
        motivi.append("l'uso su stdout non nomina --giorno e --log")
    risultati.append(Caso("--help", not motivi, motivi))
    for nome, giorno, attese, rc in (
            ("il giorno con un disservizio per tipo", GIORNO, ATTESE, 1),
            ("il giorno tranquillo, con il solo rumore di fondo", TRANQUILLO,
             set(), 0)):
        prima = fotografia(log)
        esito = esegui(script, ["--giorno", giorno, "--log", log], tmp)
        motivi = motivi_rapporto(esito, attese, rc, prima, fotografia(log))
        risultati.append(Caso("%s (uscita %d, le righe)" % (nome, rc),
                              not motivi, motivi))
    for nome, argomenti in (
            ("la cartella dei log che manca",
             ["--giorno", GIORNO, "--log", os.path.join(tmp, "manca")]),
            ("il giorno senza file", ["--giorno", SENZA_FILE, "--log", log]),
            ("il giorno a cui manca il file dell'SBC",
             ["--giorno", SENZA_SIP, "--log", log]),
            ("un giorno non valido", ["--giorno", "2026-06-31", "--log", log]),
            ("un'opzione sconosciuta",
             ["--giorno", GIORNO, "--log", log, "--sconosciuta"])):
        motivi = motivi_errore(esegui(script, argomenti, tmp))
        risultati.append(Caso("%s (uscita 2, un messaggio su stderr)" % nome,
                              not motivi, motivi))
    return risultati


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
    print("Controllo del rapporto quotidiano con SPECIFICA.md\n")
    try:
        uscita = stampa(casi(comando(radice)))
    except (Precondizione, OSError) as exc:
        print("il controllo non può girare: %s" % exc)
        uscita = 2
    print("uscita: %d" % uscita)
    return uscita


if __name__ == "__main__":
    sys.exit(main())
