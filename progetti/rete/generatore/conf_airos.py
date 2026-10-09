"""File system.cfg in stile Ubiquiti airOS (chiave=valore, in ordine).

Chiavi ispirate a quelle di airOS, semplificate: non e' l'output esatto di
alcun apparato.
"""

from . import base
from . import topologia as T

_B64 = "./0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"

_ROLE = {
    "ptp-trento-01": {"mode": "master", "ssid": "ciaspolink-ptp-cles",
                      "plan": "ptp-trento-01", "peer": "ptp-cles-01"},
    "ptp-cles-01": {"mode": "managed", "ssid": "ciaspolink-ptp-cles",
                    "plan": "ptp-cles-01", "peer": "ptp-trento-01"},
    "bts-cavareno-01": {"mode": "master", "ssid": "ciaspolink-cavareno",
                        "plan": "bts-cavareno-01", "peer": None},
}

_PARAMS = {
    "ptp-trento-01": {"httpd": "enabled", "https": "disabled"},
    "ptp-cles-01": {"snmp": "public", "tz": "GMT"},
    "bts-cavareno-01": {"txpower": 27, "psk": "12345678"},
}


def _p(name, key, default=None):
    return _PARAMS.get(name, {}).get(key, default)


def render(dev, rng, all_lines):
    name = dev["name"]
    role = _ROLE[name]
    plan = T.RADIO_PLAN[role["plan"]]
    md5 = "$1$%s$%s" % ("".join(_B64[rng.randrange(64)] for _ in range(8)),
                        "".join(_B64[rng.randrange(64)] for _ in range(22)))
    # La chiave di un ponte e' per natura la stessa ai due capi.
    link = "-".join(sorted([name, role["peer"] or name]))
    psk = _p(name, "psk", "Ptp-%016x" % base.fnv1a64("psk/" + link))
    keys = {
        "aaa.1.status": "disabled",
        "aaa.status": "disabled",
        "bridge.1.devname": "br0",
        "bridge.1.port.1.devname": "eth0",
        "bridge.1.port.2.devname": "ath0",
        "bridge.status": "enabled",
        "dhcpc.status": "disabled",
        "discovery.status": "disabled",
        "httpd.https.port": "443",
        "httpd.https.status": _p(name, "https", "enabled"),
        "httpd.port": "80",
        "httpd.status": _p(name, "httpd", "disabled"),
        "netconf.1.devname": "eth0",
        "netconf.1.mtu": "1500",
        "netconf.1.status": "enabled",
        "netconf.2.devname": "ath0",
        "netconf.2.mtu": "1500",
        "netconf.2.status": "enabled",
        "netconf.3.devname": "br0.999",
        "netconf.3.ip": dev["mgmt4"],
        "netconf.3.netmask": "255.255.255.192",
        "netconf.3.status": "enabled",
        "netmode": "bridge",
        "ntpclient.1.server": T.NTP[0],
        "ntpclient.1.status": "enabled",
        "ntpclient.2.server": T.NTP[1],
        "ntpclient.2.status": "enabled",
        "radio.1.atpc.status": "enabled",
        "radio.1.chanbw": str(plan["width"]),
        "radio.1.countrycode": "380",
        "radio.1.devname": "ath0",
        "radio.1.freq": str(plan["freq"]),
        "radio.1.mode": role["mode"],
        "radio.1.txpower": str(_p(name, "txpower", plan["txpower"])),
        "resolv.host.1.name": name,
        "resolv.nameserver.1.ip": T.DNS[0],
        "resolv.nameserver.2.ip": T.DNS[1],
        "route.1.gateway": T.MGMT_GW,
        "route.1.ip": "0.0.0.0",
        "route.1.netmask": "0",
        "snmp.contact": "noc@%s" % T.DOMAIN,
        "snmp.location": dev["site"],
        "snmp.status": "enabled",
        "sshd.port": "22",
        "sshd.status": "enabled",
        "syslog.remote.ip": T.NMS,
        "syslog.remote.port": "514",
        "syslog.remote.status": "enabled",
        "syslog.status": "enabled",
        "system.timezone": _p(name, "tz", "CET-1CEST,M3.5.0,M10.5.0/3"),
        "telnetd.status": "disabled",
        "users.1.name": "noc",
        "users.1.password": md5,
        "users.1.status": "enabled",
        "users.status": "enabled",
        "vlan.1.devname": "eth0",
        "vlan.1.id": "999",
        "vlan.1.status": "enabled",
        "wireless.1.devname": "ath0",
        "wireless.1.security.type": "wpa2",
        "wireless.1.ssid": role["ssid"],
        "wireless.1.status": "enabled",
        "wpa.1.psk": psk,
        "wpa.1.pairwise": "CCMP",
        "wpa.status": "enabled",
    }
    # Un system.cfg contiene sempre tutte le chiavi, anche quelle inerti.
    community = _p(name, "snmp")
    if community:
        keys["snmp.community"] = community
        keys["snmp.v3.status"] = "disabled"
        keys["snmp.v3.user"] = ""
    else:
        keys["snmp.status"] = "disabled"
        keys["snmp.community"] = "public"
        keys["snmp.v3.status"] = "enabled"
        keys["snmp.v3.user"] = "monitor"
    keys["snmp.v3.authtype"] = "SHA"
    keys["snmp.v3.privtype"] = "AES"
    keys["wireless.1.mac_acl.policy"] = "allow"
    if role["peer"]:
        keys["wireless.1.ap"] = (base.mac(0x10 + T.DEVICE[role["peer"]]
                                          ["octet"] - 19))
        keys["wireless.1.mac_acl.status"] = "disabled"
    else:
        stations = [l for l in all_lines if l["device"] == name]
        keys["wireless.1.ap"] = ""
        keys["wireless.1.mac_acl.status"] = "enabled"
        for index, line in enumerate(stations, 1):
            keys["wireless.1.mac_acl.%d.mac" % index] = base.mac_upper(
                line["mac"])
            keys["wireless.1.mac_acl.%d.comment" % index] = line["id"]
            keys["wireless.1.mac_acl.%d.status" % index] = "enabled"
    out = ["%s=%s" % (key, keys[key]) for key in sorted(keys)]
    return base.lines_to_text(out)


def radio_mac(name):
    """MAC dell'interfaccia radio di un apparato airOS."""
    return base.mac(0x10 + T.DEVICE[name]["octet"] - 19)
