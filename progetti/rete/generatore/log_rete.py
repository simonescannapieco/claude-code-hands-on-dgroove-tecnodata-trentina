"""Syslog degli apparati di rete, come lo scrive il collettore centrale.

Ogni riga: orario (quello dichiarato dall'apparato), nome dell'apparato,
messaggio nel formato del suo sistema operativo. Un file per giorno.
"""

from . import base
from .base import secs
from . import conf_airos
from . import eventi as E
from . import topologia as T

# Apparati il cui syslog non arriva al collettore centrale.
NOT_RECEIVED = ["rtr-cles-01", "sw-rovereto-01"]
UTC_CLOCK = ["bdr-trento-01", "ptp-cles-01"]
DRIFTING = "olt-trento-01"


def _stamp(device, moment):
    if device in UTC_CLOCK:
        return base.iso_utc_skewed(moment)
    if device == DRIFTING:
        drift = 3 + int((moment - base.WEEK_START).total_seconds()) // 12000
        return base.iso(moment + secs(drift))
    return base.iso(moment)


class Syslog(object):
    def __init__(self, week):
        self.week = week
        self.rng = week.rng.fork("log/syslog")
        self.records = []

    def add(self, moment, device, text):
        if device in NOT_RECEIVED:
            return
        self.records.append((moment, device, "%s %s %s"
                             % (_stamp(device, moment), device, text)))

    # --- accessi e modifiche -----------------------------------------

    def logins(self):
        for moment, device, changed in self.week.logins:
            dialect = T.DEVICE[device]["dialect"]
            later = moment + secs(self.rng.randint(120, 1500))
            pid = 3000 + self.rng.randrange(6000)
            if dialect in ("ios", "ios-xe"):
                self.add(moment, device, "%%SEC_LOGIN-5-LOGIN_SUCCESS: Login "
                         "Success [user: noc] [Source: %s] [localport: 22] at "
                         "%s" % (T.NOC, base.cisco_clock(moment)))
                if changed:
                    self.add(later, device, "%%SYS-5-CONFIG_I: Configured "
                             "from console by noc on vty0 (%s)" % T.NOC)
            elif dialect == "junos":
                self.add(moment, device, "sshd[%d]: Accepted publickey for "
                         "noc from %s port %d ssh2"
                         % (pid, T.NOC, 40000 + pid))
                if changed:
                    self.add(later, device, "mgd[%d]: UI_COMMIT: User 'noc' "
                             "requested 'commit' operation (comment: none)"
                             % (pid + 1))
            elif dialect == "routeros":
                self.add(moment, device, "system,info,account user noc "
                         "logged in from %s via ssh" % T.NOC)
                if changed:
                    self.add(later, device, "system,info configuration "
                             "changed by noc")
            elif dialect == "olt":
                self.add(moment, device, "%%%%SYSTEM/5/LOGIN: user noc "
                         "logged in from %s via SSH" % T.NOC)
                if changed:
                    self.add(later, device, "%%CFG/5/SAVE: configuration "
                             "saved by noc")
            elif dialect == "airos":
                self.add(moment, device, "dropbear[%d]: Pubkey auth "
                         "succeeded for 'noc' from %s:%d"
                         % (pid, T.NOC, 40000 + pid))
                if changed:
                    self.add(later, device, "system: configuration applied "
                             "by noc")

    # --- rumore periodico --------------------------------------------

    def periodic(self):
        for hour in range(7 * 24):
            moment = base.WEEK_START + secs(hour * 3600 + 1211)
            self.add(moment, "sw-trento-01", "%CDP-4-NATIVE_VLAN_MISMATCH: "
                     "Native VLAN mismatch discovered on "
                     "TenGigabitEthernet1/1/2 (999), with sw-rovereto-01 "
                     "TenGigabitEthernet1/1/1 (1).")
            if hour % 2 == 0:
                self.add(moment + secs(1500), DRIFTING, "%%%%NTP/4/"
                         "SOURCE_LOST: NTP server %s unreachable, clock not "
                         "synchronized" % T.OLD_NTP)
            if hour % 4 == 1:
                self.add(moment + secs(400), "olt-rovereto-01", "%%%%SYSTEM/"
                         "4/IP_CONFLICT: IP address 192.0.2.13 on vlanif999 "
                         "conflicts with host %s" % base.mac_upper(
                             0x20 + T.DEVICE["sw-rovereto-01"]["octet"]))
        self._radio_stats()

    def _radio_stats(self):
        peers = {"ptp-trento-01": "ptp-cles-01", "ptp-cles-01": "ptp-trento-01"}
        for slot in range(7 * 48):
            moment = base.WEEK_START + secs(slot * 1800 + 47)
            degraded = E.RADIO_DEGRADED[0] <= moment <= E.RADIO_DEGRADED[1]
            for device in ("ptp-trento-01", "ptp-cles-01", "bts-cavareno-01"):
                if device in peers:
                    signal = -52 - self.rng.randint(0, 3)
                    if degraded:
                        signal = -63 - self.rng.randint(0, 11)
                    ccq = 97 - self.rng.randint(0, 3) - (25 if degraded else 0)
                    capacity = 410 - self.rng.randint(0, 25) - (
                        180 if degraded else 0)
                    self.add(moment, device, "airstats: link %s signal %d dBm "
                             "noise -93 dBm ccq %d%% capacity %d/%d Mbps"
                             % (conf_airos.radio_mac(peers[device]).upper(),
                                signal, ccq, capacity, capacity - 12))
                else:
                    stations = len([l for l in self.week.lines
                                    if l["device"] == device])
                    self.add(moment, device, "airstats: stations %d noise "
                             "-91 dBm airtime %d%%" % (
                                 stations, 22 + self.rng.randint(0, 30)))

    # --- interruzioni delle singole linee -----------------------------

    def line_outages(self):
        for moment, line, state, cause in self.week.ont_events:
            frame, board, port = line["port"].split("/")
            if state == "offline":
                text = ("%%%%GPON/4/ONT_OFFLINE: frame %s slot %s port %s "
                        "ONT %d SN %s offline, cause %s"
                        % (frame, board, port, line["ont"], line["sn"], cause))
            else:
                text = ("%%%%GPON/5/ONT_ONLINE: frame %s slot %s port %s ONT "
                        "%d SN %s online" % (frame, board, port, line["ont"],
                                             line["sn"]))
            self.add(moment, line["device"], text)
        for line in self.week.fwa_pppoe:
            for start, end, cause in self.week.outages[line["id"]]:
                if cause != "peer" or self._is_radio_incident(start):
                    continue
                self._fwa_station(line, start - secs(9), False)
                self._fwa_station(line, end - secs(14), True)

    def _is_radio_incident(self, moment):
        return any(s <= moment <= s + secs(d + 120)
                   for s, d in E.RADIO_EPISODES)

    def _fwa_station(self, line, moment, up):
        mac = base.mac_upper(line["mac"])
        if line["device"] == "bts-cles-01":
            sector = "wlan-%s" % line["port"].lower()
            if up:
                text = ("wireless,info %s@%s: connected, signal strength %d"
                        % (mac, sector, -60 - self.rng.randint(0, 9)))
            else:
                text = ("wireless,info %s@%s: disconnected, extensive data "
                        "loss, signal strength %d"
                        % (mac, sector, -77 - self.rng.randint(0, 6)))
        else:
            text = ("wireless: ath0: station %s %s" % (
                mac, "associated" if up else "disassociated (inactivity)"))
        self.add(moment, line["device"], text)

    # --- gli avvenimenti della settimana -------------------------------

    def incidents(self):
        self._pon_cut()
        self._radio_link()
        self._maintenance()
        self._bgp_flap()

    def _pon_cut(self):
        count = len(self.week.pon_lines)
        self.add(E.PON_LOS, "olt-pergine-01", "%%%%GPON/2/PON_LOS: frame 0 "
                 "slot 1 port 3 loss of signal, %d ONT affected" % count)
        self.add(E.PON_FIX, "olt-pergine-01", "%%GPON/5/PON_LOS_CLEAR: "
                 "frame 0 slot 1 port 3 optical signal restored")

    def _radio_link(self):
        for start, duration in E.RADIO_EPISODES:
            end = start + secs(duration)
            for device, peer in (("ptp-trento-01", "ptp-cles-01"),
                                 ("ptp-cles-01", "ptp-trento-01")):
                peer_mac = conf_airos.radio_mac(peer).upper()
                self.add(start + secs(2), device, "wireless: ath0: link to %s "
                         "lost (last signal %d dBm)"
                         % (peer_mac, -78 - self.rng.randint(0, 5)))
                self.add(end, device, "wireless: ath0: link to %s established "
                         "(signal %d dBm, capacity %d/%d Mbps)"
                         % (peer_mac, -66 - self.rng.randint(0, 6),
                            150 + self.rng.randint(0, 60),
                            140 + self.rng.randint(0, 60)))
            if duration >= 40:
                nbr = T.LOOPBACK["rtr-cles-01"]
                self.add(start + secs(40), "core-trento-01", "%%OSPF-5-ADJCHG:"
                         " Process 1, Nbr %s on GigabitEthernet0/0/4.903 from "
                         "FULL to DOWN, Neighbor Down: Dead timer expired"
                         % nbr)
                self.add(end + secs(6 + self.rng.randint(0, 5)),
                         "core-trento-01", "%%OSPF-5-ADJCHG: Process 1, Nbr %s"
                         " on GigabitEthernet0/0/4.903 from LOADING to FULL, "
                         "Loading Done" % nbr)

    def _maintenance(self):
        bng = "bng-trento-01"
        nbr = T.LOOPBACK[bng]
        self.add(E.MAINT_START + secs(125), bng, "system,info package "
                 "routeros-%s downloaded" % E.FW_NEW)
        self.add(E.MAINT_REBOOT - secs(2), bng, "system,info,critical "
                 "upgrade %s -> %s: rebooting by user noc"
                 % (E.FW_OLD, E.FW_NEW))
        self.add(E.MAINT_REBOOT + secs(1), "core-trento-01", "%LINK-3-UPDOWN:"
                 " Interface TenGigabitEthernet0/0/1, changed state to down")
        self.add(E.MAINT_REBOOT + secs(1), "sw-trento-01", "%LINK-3-UPDOWN: "
                 "Interface TenGigabitEthernet1/1/1, changed state to down")
        self.add(E.MAINT_REBOOT + secs(2), "core-trento-01", "%%OSPF-5-ADJCHG:"
                 " Process 1, Nbr %s on TenGigabitEthernet0/0/1 from FULL to "
                 "DOWN, Neighbor Down: Interface down or detached" % nbr)
        self.add(E.MAINT_BACK - secs(21), "core-trento-01", "%LINK-3-UPDOWN: "
                 "Interface TenGigabitEthernet0/0/1, changed state to up")
        self.add(E.MAINT_BACK - secs(21), "sw-trento-01", "%LINK-3-UPDOWN: "
                 "Interface TenGigabitEthernet1/1/1, changed state to up")
        self.add(E.MAINT_BACK, bng, "system,info,critical router rebooted")
        self.add(E.MAINT_BACK + secs(1), bng, "system,info installed "
                 "routeros-%s" % E.FW_NEW)
        self.add(E.MAINT_BACK + secs(14), "core-trento-01", "%%OSPF-5-ADJCHG: "
                 "Process 1, Nbr %s on TenGigabitEthernet0/0/1 from LOADING "
                 "to FULL, Loading Done" % nbr)
        self.add(E.MAINT_END - secs(95), bng, "system,info,account user noc "
                 "logged out from %s via ssh" % T.NOC)

    def _bgp_flap(self):
        down, up = base.at(0, 23, 41, 7), base.at(0, 23, 44, 12)
        peer = T.TRANSITS[1]
        self.add(down, "bdr-trento-01", "rpd[2201]: bgp_hold_timeout: "
                 "NOTIFICATION sent to %s (External AS %d): code 4 (Hold "
                 "Timer Expired Error)" % (peer[3], peer[1]))
        self.add(down, "bdr-trento-01", "rpd[2201]: "
                 "RPD_BGP_NEIGHBOR_STATE_CHANGED: BGP peer %s (External AS "
                 "%d) changed state from Established to Idle (event HoldTime)"
                 % (peer[3], peer[1]))
        self.add(up, "bdr-trento-01", "rpd[2201]: "
                 "RPD_BGP_NEIGHBOR_STATE_CHANGED: BGP peer %s (External AS "
                 "%d) changed state from OpenConfirm to Established (event "
                 "RecvKeepAlive)" % (peer[3], peer[1]))


BGP_FLAP = (base.at(0, 23, 41, 7), base.at(0, 23, 44, 12))


def syslog_files(week):
    log = Syslog(week)
    log.logins()
    log.periodic()
    log.line_outages()
    log.incidents()
    days = {d.strftime("%Y-%m-%d"): [] for d in base.DAYS}
    names = sorted(days)
    for moment, device, text in sorted(log.records,
                                       key=lambda r: (r[0], r[1], r[2])):
        day = base.day_of(moment)
        if 0 <= day < 7:
            days[names[day]].append(text)
    return {"log/syslog/syslog_%s.log" % name: base.lines_to_text(days[name])
            for name in names if days[name]}
