"""Eventi dei servizi: registrazioni SIP e assegnazioni DHCP della settimana."""

from . import base
from .base import secs
from . import conf_server
from . import eventi as E
from . import topologia as T

PBX_DEST_OK = "sip:192.0.2.32:5060"
PBX_DEST_BAD = "sip:192.0.2.32:5070"


def dhcp_clients(lines):
    """Linee business in DHCP con il loro indirizzo e la durata del lease."""
    clients = []
    counters = {210: 230, 312: 200}
    for line in lines:
        if line["access"] != "dhcp":
            continue
        if line["vlan"] == 300:
            ip, lease = line["ip"], 86400
        else:
            ip = "198.51.100.%d" % counters[line["vlan"]]
            counters[line["vlan"]] += 1
            lease = conf_server.LEASE_312 if line["vlan"] == 312 else 86400
        clients.append({"line": line, "mac": line["mac"], "ip": ip,
                        "lease": lease, "vlan": line["vlan"]})
    return clients


def dhcp_events(week):
    """(istante, tipo, dati) con tipo in alloc, advert, fail, lfc."""
    rng = week.rng.fork("dhcp")
    events = []
    clients = dhcp_clients(week.lines)
    for client in clients:
        moment = base.WEEK_START + secs(rng.randint(60, client["lease"] // 2))
        while moment < base.WEEK_END:
            events.append((moment, "alloc", dict(client, tid=rng.hexstr(8))))
            moment += secs(client["lease"] // 2 + rng.randint(-120, 120))
    used = [c["ip"] for c in clients if c["vlan"] == 312]
    first, last = conf_server.POOL_312
    low, high = int(first.rsplit(".", 1)[1]), int(last.rsplit(".", 1)[1])
    free = ["198.51.100.%d" % i for i in range(low, high + 1)
            if "198.51.100.%d" % i not in used]
    arrivals = sorted(E.DHCP_FIRST_NEW + secs(rng.randint(0, 97 * 60))
                      for _ in T.SATURDAY_MACS)
    for index, mac_index in enumerate(T.SATURDAY_MACS):
        moment = arrivals[index]
        client = {"line": None, "mac": mac_index, "vlan": 312,
                  "lease": conf_server.LEASE_312}
        if free:
            client["ip"] = free.pop(0)
            events.append((moment, "advert", dict(client, tid=rng.hexstr(8))))
            events.append((moment + secs(1), "alloc",
                           dict(client, tid=rng.hexstr(8))))
            continue
        windows = [(moment, base.at(5, 19, 30) + secs(rng.randint(0, 1800))),
                   (base.at(6, 10, 0) + secs(rng.randint(0, 2400)),
                    base.at(6, 18, 30) + secs(rng.randint(0, 1800)))]
        for start, end in windows:
            attempt = start
            while attempt < end:
                events.append((attempt, "fail",
                               dict(client, ip=None, tid=rng.hexstr(8))))
                attempt += secs(rng.randint(300, 600))
    for hour in range(7 * 24):
        events.append((base.WEEK_START + secs(hour * 3600 + 17 * 60 + 3),
                       "lfc", {}))
    events.sort(key=lambda e: (e[0], e[1], e[2].get("mac", -1)))
    return events


def pool_exhausted_at(events):
    allocs = [e[0] for e in events if e[1] == "alloc" and e[2]["line"] is None]
    return allocs[-1] if allocs else None


def sip_endpoints(week):
    endpoints = []
    dhcp_ip = {c["line"]["id"]: c["ip"] for c in dhcp_clients(week.lines)}
    for line, owner, ext in conf_server.pbx_endpoints(week.lines):
        endpoints.append({"kind": "pbx", "line": line,
                          "user": "%s-%d" % (owner, ext),
                          "domain": "%s.pbx.ciaspolink.example.org" % owner,
                          "src": line["ip"] or dhcp_ip[line["id"]]})
    for line in week.lines:
        if line["extra"] == "voce":
            endpoints.append({"kind": "voce", "line": line,
                              "user": line["id"].replace("-", "").lower(),
                              "domain": "voce.ciaspolink.example.org",
                              "src": None})
    return endpoints


def _register_loop(week, endpoint, rng, events):
    moment = base.WEEK_START + secs(rng.randint(5, 3300))
    last_ok = base.WEEK_START
    expired_logged = False
    while moment < base.WEEK_END:
        src = endpoint["src"]
        if endpoint["kind"] == "voce":
            session = week.session_at(endpoint["line"], moment)
            if session is None:
                up = week.next_up(endpoint["line"], moment)
                retry = up + secs(rng.randint(5, 40)) if up else base.WEEK_END
                expiry = last_ok + secs(3600)
                if expiry < retry and expiry < base.WEEK_END and \
                        not expired_logged:
                    events.append((expiry, "expired", endpoint, None, None))
                    expired_logged = True
                moment = retry
                continue
            src = session.ip
        if endpoint["kind"] == "pbx" and E.SIP_DOWN <= moment < E.SIP_UP:
            events.append((moment, "register", endpoint, 503, src))
            moment += secs(rng.randint(60, 180))
            continue
        events.append((moment, "register", endpoint, 200, src))
        last_ok = moment
        expired_logged = False
        moment += secs(rng.randint(3300, 3500))


def sip_events(week):
    """(istante, tipo, endpoint, codice, ip sorgente) e gli eventi dell'SBC."""
    rng = week.rng.fork("sip")
    events = []
    for endpoint in sip_endpoints(week):
        _register_loop(week, endpoint,
                       rng.fork("sip/" + endpoint["user"]), events)
    events.append((E.SIP_CHANGE, "reload", None, None, PBX_DEST_BAD))
    events.append((E.SIP_CHANGE + secs(30), "probe_fail", None, 408,
                   PBX_DEST_BAD))
    events.append((E.SIP_DOWN, "probe_fail", None, 408, PBX_DEST_BAD))
    events.append((E.SIP_DOWN, "inactive", None, None, PBX_DEST_BAD))
    events.append((E.SIP_ROLLBACK, "reload", None, None, PBX_DEST_OK))
    events.append((E.SIP_UP, "active", None, None, PBX_DEST_OK))
    order = {"reload": 0, "probe_fail": 1, "inactive": 2, "active": 3,
             "expired": 4, "register": 5}
    events.sort(key=lambda e: (e[0], order[e[1]],
                               e[2]["user"] if e[2] else ""))
    return events


def registered_pbx(events, moment):
    """Interni del centralino con una registrazione valida a `moment`."""
    last = {}
    for when, kind, endpoint, code, _ in events:
        if when > moment:
            break
        if kind == "register" and endpoint["kind"] == "pbx" and code == 200:
            last[endpoint["user"]] = when
    return sum(1 for user in sorted(last)
               if (moment - last[user]).total_seconds() < 3600)
