"""La settimana sintetica come sequenza di eventi: da qui nascono i log.

Sessioni PPPoE (con i loro indirizzi e identificativi), eventi delle ONT,
episodi del ponte radio, la manutenzione del concentratore, gli accessi del
NOC agli apparati. I file di log sono solo viste diverse di questi eventi.
"""

from . import base
from .base import at, secs
from . import topologia as T

# Gli avvenimenti della settimana (ora italiana).
PON_LOS = at(1, 10, 12, 31)          # martedi': fibra tagliata
PON_FIX = at(1, 11, 40, 4)
PON_PORT = ("olt-pergine-01", "0/1/3")
RADIO_EPISODES = [                   # mercoledi': (inizio, durata in s)
    (at(2, 9, 41, 12), 95), (at(2, 10, 27, 40), 18), (at(2, 11, 5, 3), 140),
    (at(2, 12, 48, 30), 25), (at(2, 13, 36, 55), 210), (at(2, 14, 52, 10), 75),
    (at(2, 15, 40, 0), 12), (at(2, 16, 21, 44), 160), (at(2, 17, 18, 2), 48),
]
RADIO_DEGRADED = (at(2, 9, 30, 0), at(2, 17, 35, 0))
MAINT_START = at(3, 2, 0, 0)         # giovedi': manutenzione del BNG
MAINT_LOGIN = at(3, 1, 58, 40)
MAINT_REBOOT = at(3, 2, 3, 41)
MAINT_BACK = at(3, 2, 6, 58)
MAINT_END = at(3, 2, 30, 0)
FW_OLD, FW_NEW = "7.15.3", "7.16.2"
SIP_CHANGE = at(4, 7, 52, 14)        # venerdi': modifica sull'SBC
SIP_DOWN = SIP_CHANGE + secs(60)
SIP_ROLLBACK = at(4, 10, 4, 40)
SIP_UP = SIP_ROLLBACK + secs(30)
DHCP_FIRST_NEW = at(5, 9, 10, 0)     # sabato: pool della VLAN 312
SESSION_BASE = 0x81A00100
KEEPALIVE_DROP = 20                  # s: sotto questa soglia la sessione regge


class Session(object):
    def __init__(self, line, start, ip, sid):
        self.line = line
        self.start = start            # None: iniziata prima della settimana
        self.end = None               # None: ancora attiva a fine settimana
        self.cause = None             # peer, user, reboot
        self.ip = ip
        self.sid = sid
        self.port_id = 15728640 + (sid & 0xFFFF)


class Week(object):
    """Tutti gli eventi della settimana, calcolati una volta sola."""

    def __init__(self, lines):
        self.lines = lines
        self.rng = base.root_rng()
        self.pppoe = [l for l in lines if l["access"] == "pppoe"]
        self.fwa_pppoe = [l for l in self.pppoe if l["tech"] == "FWA"]
        self.pon_lines = T.lines_by(lines, device=PON_PORT[0],
                                    port=PON_PORT[1])
        self.bad_password = T.lines_by(lines, device="olt-trento-01",
                                       port="0/1/1")[3]
        self.bad_password_window = (at(0, 18, 22, 5), at(1, 15, 12, 40))
        self.outages = {}
        self.sessions = []
        self.failed_auth = []         # (istante, linea)
        self.ont_events = []          # (istante, linea, "offline"/"online", causa)
        self._build_outages()
        self._build_sessions()
        self.logins = self._build_logins()

    # --- interruzioni per linea ------------------------------------------

    def _incident_outages(self, line):
        rng = self.rng.fork("incidenti/" + line["id"])
        result = []
        if (line["device"], line["port"]) == PON_PORT:
            result.append((PON_LOS + secs(rng.randint(21, 33)),
                           PON_FIX + secs(rng.randint(40, 360)), "peer"))
        if line["tech"] == "FWA":
            for start, duration in RADIO_EPISODES:
                if duration < KEEPALIVE_DROP:
                    continue
                result.append((start + secs(rng.randint(11, 16)),
                               start + secs(duration + rng.randint(8, 75)),
                               "peer"))
        result.append((MAINT_REBOOT, MAINT_BACK + secs(rng.randint(12, 1000)),
                       "reboot"))
        if line is self.bad_password:
            result.append((self.bad_password_window[0],
                           self.bad_password_window[1], "user"))
        return result

    def _churn(self, line):
        rng = self.rng.fork("guasti-casuali/" + line["id"])
        result = []
        for day in range(7):
            if not rng.chance(0.09):
                continue
            start = at(day) + secs(rng.randint(6 * 3600 + 1800,
                                               23 * 3600 + 1800))
            if rng.chance(0.6):
                result.append((start, start + secs(rng.randint(20, 180)),
                               "peer"))
            else:
                result.append((start, start + secs(rng.randint(30, 150)),
                               "user"))
        return result

    def _build_outages(self):
        for line in self.pppoe:
            merged = []
            fixed = sorted(self._incident_outages(line), key=lambda o: o[0])
            for outage in sorted(fixed + self._churn(line),
                                 key=lambda o: o[0]):
                clash = any(o[0] - secs(300) < outage[1] and
                            outage[0] < o[1] + secs(300) for o in fixed
                            if o is not outage)
                if outage not in fixed and clash:
                    continue
                if merged and outage[0] < merged[-1][1] + secs(60):
                    continue
                merged.append(outage)
            self.outages[line["id"]] = merged

    # --- sessioni, indirizzi, identificativi ----------------------------

    def _pool(self):
        pool = ["198.51.100.%d" % i for i in range(2, 127)]
        pool += ["198.51.100.%d" % i for i in range(130, 191)]
        return pool

    def _build_sessions(self):
        pool = self._pool()
        in_use = {}
        cursor = [0]
        sid = [SESSION_BASE]

        def allocate(line):
            for step in range(len(pool)):
                ip = pool[(cursor[0] + step) % len(pool)]
                if ip not in in_use:
                    in_use[ip] = line["id"]
                    cursor[0] = (cursor[0] + step + 1) % len(pool)
                    return ip
            raise ValueError("pool PPPoE esaurito")

        def new_session(line, start):
            sid[0] += 1
            return Session(line, start, allocate(line), sid[0])

        timeline = []
        for line in self.pppoe:
            timeline.append((base.WEEK_START, 0, "init", line, None))
            for outage in self.outages[line["id"]]:
                timeline.append((outage[0], 1, "down", line, outage))
                timeline.append((outage[1], 2, "up", line, outage))
        timeline.sort(key=lambda e: (e[0], e[1], e[3]["id"]))
        current = {}
        for moment, _, kind, line, outage in timeline:
            if kind == "init":
                session = new_session(line, None)
            elif kind == "down":
                session = current.pop(line["id"])
                session.end = moment
                session.cause = outage[2]
                del in_use[session.ip]
                continue
            else:
                if line is self.bad_password and outage[2] == "user":
                    self._failed_attempts(line, outage)
                session = new_session(line, moment)
            current[line["id"]] = session
            self.sessions.append(session)
            if line["tech"] == "FTTH":
                self._ont_for(line, outage)
        self.sessions.sort(key=lambda s: (s.start or base.WEEK_START, s.sid))

    def _failed_attempts(self, line, outage):
        rng = self.rng.fork("password-errata")
        moment = outage[0] + secs(rng.randint(90, 200))
        while moment < outage[1] - secs(120):
            self.failed_auth.append((moment, line))
            moment += secs(rng.randint(240, 420))

    def _ont_for(self, line, outage):
        if outage is None or outage[2] != "peer":
            return
        rng = self.rng.fork("ont/%s/%s" % (line["id"], base.iso(outage[0])))
        if (line["device"], line["port"]) == PON_PORT and \
                PON_LOS <= outage[0] <= PON_FIX:
            self.ont_events.append((PON_LOS + secs(rng.randint(0, 3)), line,
                                    "offline", "LOS"))
            self.ont_events.append((PON_FIX + secs(rng.randint(12, 35)), line,
                                    "online", "LOS"))
            return
        self.ont_events.append((outage[0] - secs(rng.randint(8, 15)), line,
                                "offline", "dying-gasp"))
        self.ont_events.append((outage[1] - secs(rng.randint(5, 15)), line,
                                "online", "dying-gasp"))

    def session_at(self, line, moment):
        for session in self.sessions:
            if session.line is not line:
                continue
            started = session.start is None or session.start <= moment
            if started and (session.end is None or moment < session.end):
                return session
        return None

    def next_up(self, line, moment):
        for session in self.sessions:
            if session.line is line and session.start and \
                    session.start > moment:
                return session.start
        return None

    def active_count(self, moment):
        return sum(1 for s in self.sessions
                   if (s.start is None or s.start <= moment)
                   and (s.end is None or moment < s.end))

    # --- accessi del NOC agli apparati --------------------------------

    def _build_logins(self):
        rng = self.rng.fork("accessi-noc")
        logins = []
        for day in range(5):
            for dev in T.DEVICES:
                if dev["dialect"] in ("kea", "freeradius", "kamailio",
                                      "asterisk"):
                    continue
                for _ in range(rng.randrange(3)):
                    moment = at(day, 8, 30) + secs(rng.randint(0, 9 * 3600))
                    logins.append((moment, dev["name"], rng.chance(0.35)))
        logins.append((MAINT_LOGIN, "bng-trento-01", True))
        logins.append((SIP_CHANGE - secs(95), "sbc-trento-01", True))
        logins.append((SIP_ROLLBACK - secs(70), "sbc-trento-01", True))
        logins.sort(key=lambda x: (x[0], x[1]))
        return logins
