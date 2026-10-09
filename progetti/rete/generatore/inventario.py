"""Inventario degli apparati e allarmi del monitoraggio (CSV)."""

import csv
import io

from . import base
from .base import at, secs
from . import eventi as E
from . import eventi_servizi as S
from . import log_rete
from . import topologia as T

INVENTORY_FIELDS = ["apparato", "ruolo", "descrizione", "comune", "sito",
                    "dialetto", "modello", "firmware", "ip_gestione",
                    "ipv6_gestione", "seriale", "data_installazione", "rack",
                    "uplink", "collegamento_fisico", "nome_host"]
ALARM_FIELDS = ["timestamp", "apparato", "gravita", "controllo", "messaggio",
                "stato"]


def _csv(fields, rows):
    buffer = io.StringIO()
    writer = csv.writer(buffer, lineterminator="\n")
    writer.writerow(fields)
    for row in rows:
        writer.writerow(row)
    return buffer.getvalue()


def inventory():
    rows = []
    for dev in sorted(T.DEVICES, key=lambda d: d["name"]):
        rows.append([dev["name"], dev["role"], dev["description"],
                     dev["comune"], dev["site"],
                     T.DIALECT_LABEL[dev["dialect"]], dev["model"], dev["fw"],
                     dev["mgmt4"], dev["mgmt6"], dev["serial"],
                     dev["installed"], dev["rack"], dev["uplink"],
                     dev["physical"], dev["host"]])
    return _csv(INVENTORY_FIELDS, rows)


class Alarms(object):
    def __init__(self):
        self.rows = []

    def add(self, moment, device, severity, check, message, state):
        self.rows.append((moment, device, severity, check, message, state))

    def pair(self, start, end, device, severity, check, message, recovery):
        self.add(start, device, severity, check, message, "PROBLEM")
        if end is not None:
            self.add(end, device, "OK", check, recovery, "RECOVERY")


def _sessions_message(week, moment):
    return "sessioni PPPoE attive %d su %d" % (week.active_count(moment),
                                               len(week.pppoe))


def _network_alarms(week, alarms):
    flap = log_rete.BGP_FLAP
    alarms.pair(flap[0] + secs(30), flap[1] + secs(30), "bdr-trento-01",
                "CRITICAL", "bgp-sessione", "sessione BGP con 203.0.113.133 "
                "(AS64497) non stabilita", "sessione BGP con 203.0.113.133 "
                "(AS64497) stabilita")
    alarms.pair(E.PON_LOS + secs(14), E.PON_FIX + secs(61), "olt-pergine-01",
                "CRITICAL", "pon-los", "porta PON 0/1/3: perdita di segnale, "
                "%d ONT offline" % len(week.pon_lines),
                "porta PON 0/1/3: segnale ripristinato")
    drop = E.PON_LOS + secs(90)
    back = E.PON_FIX + secs(600)
    alarms.pair(drop, back, "bng-trento-01", "WARNING", "sessioni-pppoe",
                _sessions_message(week, drop) + " (calo improvviso)",
                _sessions_message(week, back))
    for start, duration in E.RADIO_EPISODES:
        if duration < E.KEEPALIVE_DROP:
            continue
        end = start + secs(duration)
        alarms.pair(start + secs(30), end + secs(30), "ptp-cles-01",
                    "CRITICAL", "collegamento-radio", "collegamento con "
                    "ptp-trento-01 interrotto", "collegamento con "
                    "ptp-trento-01 ripristinato")
        alarms.pair(start + secs(45), end + secs(60), "bts-cles-01",
                    "CRITICAL", "ping-cpe", "LN-000202 (203.0.113.2): "
                    "perdita pacchetti 100%", "LN-000202 (203.0.113.2): "
                    "raggiungibile")
    alarms.pair(at(2, 9, 52, 30), at(2, 17, 41, 0), "ptp-trento-01",
                "WARNING", "segnale-radio", "segnale -71 dBm sotto la "
                "soglia di -65 dBm", "segnale -53 dBm")


def _maintenance_alarms(week, alarms):
    alarms.add(E.MAINT_START, "bng-trento-01", "INFO", "manutenzione",
               "inizio manutenzione programmata: aggiornamento firmware "
               "%s -> %s" % (E.FW_OLD, E.FW_NEW), "DOWNTIME_START")
    alarms.pair(E.MAINT_REBOOT + secs(25), E.MAINT_BACK + secs(31),
                "bng-trento-01", "CRITICAL", "ping", "host non raggiungibile",
                "host raggiungibile")
    alarms.add(E.MAINT_END, "bng-trento-01", "INFO", "manutenzione",
               "fine manutenzione programmata; %s"
               % _sessions_message(week, E.MAINT_END), "DOWNTIME_END")


def _sip_alarms(sip, alarms):
    moment = at(4, 7, 0)
    state = "OK"
    while moment < at(4, 12, 0):
        count = S.registered_pbx(sip, moment)
        new = "CRITICAL" if count < 6 else "WARNING" if count < 10 else "OK"
        if new != state:
            message = "interni del centralino registrati %d su 12" % count
            alarms.add(moment, "sbc-trento-01", new, "registrazioni-sip",
                       message, "RECOVERY" if new == "OK" else "PROBLEM")
            state = new
        moment += secs(60)


def _dhcp_alarms(week, dhcp, alarms):
    first, last = S.conf_server.POOL_312
    size = int(last.rsplit(".", 1)[1]) - int(first.rsplit(".", 1)[1]) + 1
    used = len(T.lines_by(week.lines, vlan=312))
    for moment, kind, data in dhcp:
        if kind != "alloc" or data["line"] is not None:
            continue
        used += 1
        percent = used * 100 // size
        if used == size:
            alarms.add(moment + secs(40), "dhcp-trento-01", "CRITICAL",
                       "pool-dhcp", "subnet 198.51.100.192/27 (VLAN 312): "
                       "pool esaurito (%d/%d)" % (used, size), "PROBLEM")
        elif percent >= 85:
            alarms.add(moment + secs(40), "dhcp-trento-01", "WARNING",
                       "pool-dhcp", "subnet 198.51.100.192/27 (VLAN 312): "
                       "pool al %d%% (%d/%d)" % (percent, used, size),
                       "PROBLEM")


def _noise_alarms(alarms):
    alarms.pair(at(2, 3, 10, 0), at(2, 3, 25, 0), "radius-trento-01",
                "WARNING", "disco", "partizione /var al 87%",
                "partizione /var al 61%")
    alarms.pair(at(4, 21, 5, 0), at(4, 21, 35, 0), "bng-trento-01",
                "WARNING", "cpu", "CPU all'83% da 5 minuti", "CPU al 41%")
    alarms.pair(at(6, 15, 20, 0), at(6, 16, 5, 0), "olt-trento-01",
                "WARNING", "temperatura", "temperatura scheda 0/1: 68 C",
                "temperatura scheda 0/1: 54 C")
    alarms.add(at(1, 6, 0, 0), "olt-trento-01", "WARNING", "ntp",
               "orologio non sincronizzato (scarto 12 s)", "PROBLEM")


def alarms_csv(week, dhcp, sip):
    alarms = Alarms()
    _network_alarms(week, alarms)
    _maintenance_alarms(week, alarms)
    _sip_alarms(sip, alarms)
    _dhcp_alarms(week, dhcp, alarms)
    _noise_alarms(alarms)
    rows = sorted(alarms.rows, key=lambda r: (r[0], r[1], r[3], r[5]))
    return _csv(ALARM_FIELDS, [[base.iso(r[0])] + list(r[1:]) for r in rows])
