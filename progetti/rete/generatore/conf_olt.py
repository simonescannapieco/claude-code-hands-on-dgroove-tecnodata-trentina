"""Configurazioni di OLT GPON in stile CLI telaio/scheda/porta.

Sintassi ispirata alle CLI degli OLT GPON piu' diffusi, semplificata: non e'
l'output esatto di alcun apparato.
"""

from . import base
from . import topologia as T

_SNAPSHOT = base.at(6, 23, 50, 0)

_PON_DESC = {
    "olt-trento-01": {"0/1/1": "Trento - zona nord", "0/1/2": "Trento - centro",
                      "0/1/7": "Trento - zona sud",
                      "0/2/1": "Trento - zona artigianale (business)"},
    "olt-pergine-01": {"0/1/1": "Pergine - centro",
                       "0/1/2": "Pergine - zona est",
                       "0/1/3": "Pergine - zona nord e lago"},
    "olt-rovereto-01": {"0/1/1": "Rovereto - centro",
                        "0/1/2": "riserva - non in uso",
                        "0/2/1": "Rovereto - zona industriale (business)",
                        "0/2/2": "Rovereto - zona industriale (business)",
                        "0/2/5": "dorsale Riva del Garda (business)"},
}

_PARAMS = {
    "olt-trento-01": {"telnet": "enable", "ntp": [T.OLD_NTP]},
    "olt-pergine-01": {"acl": "198.51.100.0 0.0.0.255"},
    "olt-rovereto-01": {"snmp_v2": "public"},
}

_UPLINK_VLANS = {"olt-trento-01": [100, 210, 999],
                 "olt-pergine-01": [101, 999],
                 "olt-rovereto-01": [102, 300, 312, 999]}


def _p(name, key, default=None):
    return _PARAMS.get(name, {}).get(key, default)


def _global(dev):
    name = dev["name"]
    saved = _SNAPSHOT + base.secs(10 + dev["octet"])
    lines = ["#",
             "# configurazione salvata il %s (backup settimanale)"
             % base.ros_time(saved),
             "#",
             "software-version %s" % dev["fw_run"],
             "#",
             "[global-config]",
             " sysname %s" % name,
             " time zone-name Europe/Rome",
             " timezone GMT+ 01:00",
             " time dst start 3-lastSun 02:00:00 end 10-lastSun 03:00:00 "
             "adjust 01:00"]
    for server in _p(name, "ntp", T.NTP):
        lines.append(" ntp-service unicast-server %s" % server)
    lines += [" info-center enable",
              " info-center loghost %s facility local5" % T.NMS,
              " info-center loghost source vlanif999"]
    community = _p(name, "snmp_v2")
    if community:
        # Come la chiave RADIUS, la community compare solo cifrata.
        lines += [" snmp-agent sys-info version v2c v3",
                  " snmp-agent community read cipher %%^%%#%016X%%^%%#"
                  % base.fnv1a64("snmp/%s/%s" % (name, community))]
    else:
        lines.append(" snmp-agent sys-info version v3")
    lines += [" snmp-agent usm-user v3 monitor authentication-mode sha "
              "privacy-mode aes128",
              " snmp-agent target-host trap address udp-domain %s params "
              "securityname monitor v3 privacy" % T.NMS,
              " snmp-agent sys-info contact noc@%s" % T.DOMAIN,
              " snmp-agent sys-info location \"%s\"" % dev["site"],
              "#",
              "[security-config]",
              " sysman service telnet %s" % _p(name, "telnet", "disable"),
              " sysman service ssh enable",
              " sysman service http disable",
              " acl 2000",
              "  rule 5 permit source %s"
              % _p(name, "acl", "192.0.2.0 0.0.0.63"),
              "  rule 100 deny",
              " quit",
              " sysman firewall ssh acl 2000",
              " sysman firewall snmp acl 2000",
              " radius-server template noc",
              "  radius-server authentication %s 1812" % T.RADIUS,
              "  radius-server shared-key cipher %%^%%#%s%%^%%#"
              % T.radius_secret(name)[4:].upper(),
              " quit",
              "#"]
    return lines


def _vlans(dev):
    name = dev["name"]
    lines = ["[vlan-config]"]
    for vlan in _UPLINK_VLANS[name]:
        lines += [" vlan %d smart" % vlan,
                  " vlan name %d \"%s\"" % (vlan, T.VLANS[vlan]),
                  " port vlan %d 0/9 0" % vlan]
    lines.append("#")
    return lines


def _profiles():
    return ["[gpon-config]",
            " ont-lineprofile gpon profile-id 10 profile-name \"casa-ftth\"",
            "  tcont 1 dba-profile-id 10",
            "  gem add 1 eth tcont 1",
            "  gem mapping 1 0 vlan 100",
            "  commit",
            " quit",
            " ont-lineprofile gpon profile-id 20 profile-name "
            "\"business-ftth\"",
            "  tcont 1 dba-profile-id 20",
            "  gem add 1 eth tcont 1",
            "  gem mapping 1 0 vlan 200",
            "  commit",
            " quit",
            " ont-srvprofile gpon profile-id 10 profile-name \"router-cliente\"",
            "  ont-port eth 1",
            "  port vlan eth 1 translation 100 user-vlan 100",
            "  commit",
            " quit",
            "#"]


def _pon_ports(dev, lines_here):
    name = dev["name"]
    out = []
    by_board = {}
    for port in sorted(set_of(l["port"] for l in lines_here)):
        frame, board, pon = port.split("/")
        by_board.setdefault("%s/%s" % (frame, board), []).append(int(pon))
    for board in sorted(by_board):
        out.append(" interface gpon %s" % board)
        for pon in by_board[board]:
            port = "%s/%d" % (board, pon)
            out += ["  port desc %d \"%s\"" % (pon, _PON_DESC[name][port]),
                    "  port %d ont-auto-find enable" % pon,
                    "  port %d fec enable" % pon]
            for line in [l for l in lines_here if l["port"] == port]:
                profile = 20 if line["offer"] == "business" else 10
                out.append("  ont add %d %d sn-auth \"%s\" omci "
                           "ont-lineprofile-id %d ont-srvprofile-id 10 "
                           "desc \"%s\"" % (pon, line["ont"], line["sn"],
                                            profile, line["id"]))
        out.append(" quit")
    out.append("#")
    return out


def set_of(values):
    """Valori distinti in ordine di comparsa (mai un set non ordinato)."""
    seen = []
    for value in values:
        if value not in seen:
            seen.append(value)
    return seen


def _service_ports(lines_here):
    out = ["[service-port]"]
    for index, line in enumerate(lines_here, 1):
        user_vlan = 200 if line["offer"] == "business" else 100
        out.append(" service-port %d vlan %d gpon %s ont %d gemport 1 "
                   "multi-service user-vlan %d tag-transform translate "
                   "inbound traffic-table index 6 outbound traffic-table "
                   "index 6" % (index, line["vlan"], line["port"],
                                line["ont"], user_vlan))
    out.append("#")
    return out


def render(dev, rng, all_lines):
    lines_here = [l for l in all_lines if l["device"] == dev["name"]]
    lines_here.sort(key=lambda l: (l["port"], l["ont"]))
    out = _global(dev) + _vlans(dev) + _profiles()
    out += _pon_ports(dev, lines_here)
    out += _service_ports(lines_here)
    out += ["[interface-config]",
            " interface vlanif999",
            "  description gestione",
            "  ip address %s 255.255.255.192" % dev["mgmt4"],
            "  ipv6 address %s/64" % dev["mgmt6"],
            " quit",
            " interface eth 0/9 0",
            "  description \"uplink %s\"" % dev["physical"],
            "  auto-neg disable",
            " quit",
            " ip route-static 0.0.0.0 0.0.0.0 %s" % T.MGMT_GW,
            "#",
            "return"]
    return base.lines_to_text(out)
