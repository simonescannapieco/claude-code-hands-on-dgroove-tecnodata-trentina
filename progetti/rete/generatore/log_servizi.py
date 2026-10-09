"""Log dei servizi: sessioni PPPoE del concentratore, RADIUS, DHCP, SIP.

Ogni funzione restituisce {percorso: testo}, un file per sorgente e giorno.
"""

from . import base
from .base import secs
from . import eventi as E
from . import eventi_servizi as S
from . import topologia as T

_DAY_NAMES = [d.strftime("%Y-%m-%d") for d in base.DAYS]


def _split_by_day(records, path_pattern):
    """records: (istante, testo) -> {percorso del giorno: testo}."""
    days = {name: [] for name in _DAY_NAMES}
    for moment, text in sorted(records, key=lambda r: r[0]):
        day = base.day_of(moment)
        if 0 <= day < 7:
            days[_DAY_NAMES[day]].append(text)
    return {path_pattern % name: base.lines_to_text(rows)
            for name, rows in sorted(days.items()) if rows}


def _counters(rng, seconds):
    rate_in = rng.randint(2000, 40000)
    rate_out = rate_in * rng.randint(3, 12)
    octets_in, octets_out = seconds * rate_in, seconds * rate_out
    return octets_in, octets_out, octets_in // 900, octets_out // 1200


def pppoe_log(week):
    rng = week.rng.fork("log/pppoe")
    out = []

    def add(moment, topic, text):
        out.append((moment, "%s %s %s" % (base.ros_time(moment), topic, text)))

    for session in week.sessions:
        user, mac = session.line["user"], base.mac_upper(session.line["mac"])
        if session.start is not None:
            add(session.start, "pppoe,ppp,info",
                "<pppoe-%s>: authenticated" % mac)
            add(session.start, "pppoe,ppp,info,account",
                "%s logged in, %s from %s" % (user, session.ip, mac))
            add(session.start, "pppoe,ppp,info",
                "<pppoe-%s>: connected" % user)
        if session.end is None or session.cause == "reboot":
            continue
        reason = ("peer is not responding" if session.cause == "peer"
                  else "disconnect request from peer")
        begun = session.start or (base.WEEK_START - secs(
            rng.randint(3600, 9 * 86400)))
        uptime = int((session.end - begun).total_seconds())
        add(session.end, "pppoe,ppp,info",
            "<pppoe-%s>: terminating... - %s" % (user, reason))
        add(session.end, "pppoe,ppp,info,account",
            "%s logged out, %d %d %d %d %d from %s"
            % ((user, uptime) + _counters(rng, uptime) + (mac,)))
    for moment, line in week.failed_auth:
        mac = base.mac_upper(line["mac"])
        add(moment, "pppoe,ppp,info", "<pppoe-%s>: waiting for call..." % mac)
        add(moment + secs(1), "pppoe,ppp,error",
            "<pppoe-%s>: user %s authentication failed" % (mac, line["user"]))
    for vlan in (100, 101, 102, 103):
        add(E.MAINT_BACK + secs(4), "pppoe,info",
            "PPPoE server vlan%d-%s started" % (vlan, T.VLANS[vlan]))
    return _split_by_day(out, "log/pppoe/bng-trento-01_%s.log")


def radius_log(week):
    out = []
    counter = [41870]

    def add(moment, text):
        counter[0] += 1
        out.append((moment, "%s : %s" % (base.ctime_style(moment),
                                         text.replace("#", str(counter[0])))))

    for session in week.sessions:
        if session.start is None:
            continue
        add(session.start, "Auth: (#) Login OK: [%s] (from client "
            "bng-trento-01 port %d cli %s)" % (session.line["user"],
                                               session.port_id,
                                               base.mac_upper(
                                                   session.line["mac"])))
    for moment, line in week.failed_auth:
        add(moment + secs(1), "Auth: (#) Login incorrect (pap: Cleartext "
            "password does not match \"known good\" password): [%s] (from "
            "client bng-trento-01 port 0 cli %s)"
            % (line["user"], base.mac_upper(line["mac"])))
    for moment, device, _ in week.logins:
        dev = T.DEVICE[device]
        if dev["dialect"] in ("airos", "kamailio", "junos"):
            continue
        if device == "rtr-cles-01":
            add(moment, "Error: (#) Received packet from %s with invalid "
                "Message-Authenticator!  (Shared secret is incorrect.) "
                "Dropping packet without response." % dev["mgmt4"])
            continue
        if device == "sw-rovereto-01":
            add(moment, "Error: Ignoring request to auth address * port 1812 "
                "bound to server default from unknown client 192.0.2.13 "
                "port %d proto udp" % (49152 + int(moment.timestamp()) % 9000))
            continue
        add(moment, "Auth: (#) Login OK: [noc] (from client %s port 0 cli %s)"
            % (device, T.NOC))
    return _split_by_day(out, "log/radius/radius_%s.log")


def accounting_log(week):
    rng = week.rng.fork("log/accounting")
    out = []

    def add(moment, fields):
        out.append((moment, "%s %s" % (base.iso(moment), " ".join(
            "%s=%s" % pair for pair in fields))))

    for session in week.sessions:
        line = session.line
        port = "vlan%d-%s" % (line["vlan"], T.VLANS[line["vlan"]])
        ident = [("User-Name", line["user"]),
                 ("Acct-Session-Id", "%08x" % session.sid),
                 ("NAS-IP-Address", "192.0.2.1"), ("NAS-Port-Id", port),
                 ("Framed-IP-Address", session.ip),
                 ("Calling-Station-Id", base.mac_upper(line["mac"]))]
        begun = session.start or (base.WEEK_START - secs(
            rng.randint(600, 43000)))
        if session.start is not None:
            add(session.start, [("Acct-Status-Type", "Start")] + ident)
        stop = session.end or base.WEEK_END
        tick = begun + secs(43200)
        while tick < stop:
            if tick >= base.WEEK_START:
                elapsed = int((tick - begun).total_seconds())
                octets = _counters(rng, elapsed)
                add(tick, [("Acct-Status-Type", "Interim-Update")] + ident +
                    [("Acct-Session-Time", elapsed),
                     ("Acct-Input-Octets", octets[0]),
                     ("Acct-Output-Octets", octets[1])])
            tick += secs(43200)
        if session.end is not None and session.cause != "reboot":
            elapsed = int((session.end - begun).total_seconds())
            octets = _counters(rng, elapsed)
            cause = "Lost-Carrier" if session.cause == "peer" else \
                "User-Request"
            add(session.end, [("Acct-Status-Type", "Stop")] + ident +
                [("Acct-Session-Time", elapsed),
                 ("Acct-Input-Octets", octets[0]),
                 ("Acct-Output-Octets", octets[1]),
                 ("Acct-Terminate-Cause", cause)])
    add(E.MAINT_BACK + secs(9), [("Acct-Status-Type", "Accounting-On"),
                                 ("NAS-IP-Address", "192.0.2.1"),
                                 ("NAS-Identifier", "bng-trento-01")])
    return _split_by_day(out, "log/radius/accounting_%s.log")


def dhcp_log(week, events):
    rng = week.rng.fork("log/dhcp")
    out = []
    thread = "2210.139871022552832"

    def add(moment, level, logger, text):
        stamp = base.kea_time(moment, rng.randrange(1000))
        out.append((moment, "%s %-5s [kea-dhcp4.%s/%s] %s"
                    % (stamp, level, logger, thread, text)))

    for moment, kind, data in events:
        if kind == "lfc":
            add(moment, "INFO", "dhcpsrv", "DHCPSRV_MEMFILE_LFC_START "
                "starting Lease File Cleanup")
            continue
        who = "[hwtype=1 %s], cid=[no info], tid=0x%s" % (
            base.mac(data["mac"]), data["tid"])
        if kind == "advert":
            add(moment, "INFO", "leases", "DHCP4_LEASE_ADVERT %s: lease %s "
                "will be advertised" % (who, data["ip"]))
        elif kind == "alloc":
            add(moment, "INFO", "leases", "DHCP4_LEASE_ALLOC %s: lease %s "
                "has been allocated for %d seconds"
                % (who, data["ip"], data["lease"]))
        else:
            add(moment, "WARN", "alloc-engine",
                "ALLOC_ENGINE_V4_ALLOC_FAIL_SUBNET %s: failed to allocate an "
                "IPv4 address in the subnet 198.51.100.192/27, subnet-id 312, "
                "shared network (none)" % who)
            add(moment, "WARN", "alloc-engine",
                "ALLOC_ENGINE_V4_ALLOC_FAIL %s: failed to allocate an IPv4 "
                "address after 14 attempt(s)" % who)
    return _split_by_day(out, "log/dhcp/kea-dhcp4_%s.log")


def sip_log(week, events):
    out = []
    pid = 2318

    def add(moment, level, text):
        out.append((moment, "%s sbc-trento-01 kamailio[%d]: %s: %s"
                    % (base.iso(moment), pid, level, text)))

    for moment, kind, endpoint, code, extra in events:
        if kind == "register":
            reason = "200 OK" if code == 200 else "503 Service Unavailable"
            add(moment, "NOTICE", "<script>: REGISTER sip:%s from sip:%s@%s "
                "src=%s:5060 -> %s" % (endpoint["domain"], endpoint["user"],
                                       endpoint["domain"], extra or
                                       endpoint["src"], reason))
            if code != 200:
                add(moment, "WARNING", "<script>: ds_select_dst set 1: no "
                    "active destination for %s" % endpoint["domain"])
        elif kind == "expired":
            add(moment, "INFO", "usrloc: contact expired for %s@%s"
                % (endpoint["user"], endpoint["domain"]))
        elif kind == "reload":
            add(moment, "INFO", "<core>: RPC dispatcher.reload from %s "
                "(user noc)" % T.NOC)
            add(moment, "INFO", "dispatcher: set 1: loaded destination %s"
                % extra)
        elif kind == "probe_fail":
            add(moment, "WARNING", "dispatcher: probing %s (set 1) failed "
                "with code %d Request Timeout" % (extra, code))
        elif kind == "inactive":
            add(moment, "ERROR", "dispatcher: destination %s (set 1) "
                "marked inactive" % extra)
        elif kind == "active":
            add(moment, "NOTICE", "dispatcher: destination %s (set 1) "
                "marked active" % extra)
    return _split_by_day(out, "log/sip/sbc-trento-01_%s.log")


def all_service_logs(week):
    dhcp = S.dhcp_events(week)
    sip = S.sip_events(week)
    files = {}
    for part in (pppoe_log(week), radius_log(week), accounting_log(week),
                 dhcp_log(week, dhcp), sip_log(week, sip)):
        files.update(part)
    return files, dhcp, sip
