"""Configurazioni in stile Cisco IOS-XE (router) e IOS (switch).

Sintassi ispirata a quella dei router e switch di quella famiglia,
semplificata: non e' l'output esatto di alcun apparato.
"""

from . import base
from . import topologia as T

_XLAT = "dsfd;kfoA,.iyewrkldJKDHSUBsgvca69834ncxv9873254k;fg87"
_B64 = "./0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"


def type7(plain, seed):
    """Offuscamento reversibile «tipo 7» (non e' una cifratura)."""
    out = "%02d" % seed
    for i, char in enumerate(plain):
        out += "%02X" % (ord(char) ^ ord(_XLAT[(seed + i) % 53]))
    return out


def secret9(rng):
    salt = "".join(_B64[rng.randrange(64)] for _ in range(14))
    digest = "".join(_B64[rng.randrange(64)] for _ in range(43))
    return "$9$%s$%s" % (salt, digest)


# Valori per apparato (dove non indicato vale lo standard del NOC).
_PARAMS = {
    "core-trento-01": {
        "changed": base.at(4, 22, 41, 7), "snmp_v2": "public RO",
        "vty": "telnet ssh", "pwenc": False,
        "local_admin": "Ciaspola2024!",
    },
    "core-rovereto-01": {
        "changed": base.at(2, 16, 5, 44), "http": True, "pwenc": False,
        "local_admin": "Ciaspola2024!",
    },
    "sw-trento-01": {
        "changed": base.at(0, 11, 20, 3), "snmp_v2": "private RW",
    },
    "sw-rovereto-01": {
        "changed": base.at(3, 15, 2, 51), "syslog": T.OLD_SYSLOG,
        "mgmt_ip": "192.0.2.13",
    },
}


def _p(name, key, default=None):
    return _PARAMS.get(name, {}).get(key, default)


def _header(dev, rng):
    changed = _p(dev["name"], "changed")
    lines = [
        "!",
        "! Last configuration change at %s by noc" % base.cisco_clock(changed),
        "! NVRAM config last updated at %s by noc"
        % base.cisco_clock(changed + base.secs(37)),
        "!",
        "version %s" % ".".join(dev["fw_run"].split(".")[:2]),
        "service timestamps debug datetime msec localtime show-timezone",
        "service timestamps log datetime msec localtime show-timezone",
    ]
    if _p(dev["name"], "pwenc", True):
        lines.append("service password-encryption")
    else:
        lines.append("no service password-encryption")
    lines += [
        "!",
        "hostname %s" % dev["name"],
        "!",
        "boot-start-marker",
        "boot system flash:packages.conf",
        "boot-end-marker",
        "!",
        "logging buffered 64000 informational",
        "no logging console",
        "enable secret 9 %s" % secret9(rng),
        "!",
        "aaa new-model",
        "aaa group server radius RADIUS-NOC",
        " server name radius-trento-01",
        "aaa authentication login default group RADIUS-NOC local",
        "aaa authorization exec default group RADIUS-NOC local",
        "aaa accounting exec default start-stop group RADIUS-NOC",
        "!",
        "clock timezone CET 1 0",
        "clock summer-time CEST recurring last Sun Mar 2:00 last Sun Oct 3:00",
        "!",
        "ip domain name %s" % T.DOMAIN,
        "ip name-server %s" % " ".join(T.DNS),
        "ip ssh version 2",
        "ip ssh time-out 60",
        "login on-failure log",
        "login on-success log",
        "!",
        "username noc privilege 15 secret 9 %s" % secret9(rng),
    ]
    admin = _p(dev["name"], "local_admin")
    if admin:
        lines.append("username admin privilege 15 password 0 %s" % admin)
    else:
        lines.append("username admin privilege 15 secret 9 %s" % secret9(rng))
    lines.append("!")
    return lines


def _mgmt_services(dev, rng):
    name = dev["name"]
    lines = ["!"]
    if _p(name, "http"):
        lines += ["ip http server", "ip http authentication local"]
    else:
        lines.append("no ip http server")
    lines += ["ip http secure-server", "!",
              "access-list 10 remark gestione e postazione NOC",
              "access-list 10 permit 192.0.2.0 0.0.0.63",
              "access-list 10 deny   any log", "!"]
    community = _p(name, "snmp_v2")
    if community:
        lines.append("snmp-server community %s" % community)
    lines += [
        "snmp-server group NMS v3 priv access 10",
        "snmp-server location %s" % dev["site"],
        "snmp-server contact noc@%s" % T.DOMAIN,
        "snmp-server host %s version 3 priv monitor" % T.NMS,
        "snmp-server enable traps snmp linkdown linkup",
        "!",
        "radius server radius-trento-01",
        " address ipv4 %s auth-port 1812 acct-port 1813" % T.RADIUS,
        " key 7 %s" % type7(T.radius_secret(name), 7 + dev["octet"] % 9),
        "!",
        "logging source-interface %s" % _mgmt_intf(dev),
        "logging host %s" % _p(name, "syslog", T.NMS),
        "logging trap informational",
        "!",
        "ntp source %s" % _mgmt_intf(dev),
    ]
    for server in T.NTP:
        lines.append("ntp server %s" % server)
    lines += [
        "!",
        "line con 0",
        " exec-timeout 5 0",
        " logging synchronous",
        "line vty 0 4",
        " access-class 10 in",
        " exec-timeout 15 0",
        " transport input %s" % _p(name, "vty", "ssh"),
        "line vty 5 15",
        " access-class 10 in",
        " transport input ssh",
        "!",
        "end",
    ]
    return lines


def _mgmt_intf(dev):
    if dev["role"] == "switch":
        return "Vlan999"
    return "Loopback0"


def _p2p_lines(name):
    """Interfacce punto-punto dell'apparato, dall'elenco dei collegamenti."""
    result = []
    for index, (a, ia, b, ib, net) in enumerate(T.P2P):
        base_ip = net.rsplit(".", 1)
        last = int(base_ip[1])
        if name == a:
            result.append((ia, b, ib, "%s.%d" % (base_ip[0], last), index, 0))
        elif name == b:
            result.append((ib, a, ia, "%s.%d" % (base_ip[0], last + 1),
                           index, 1))
    return result


_DESCR_OVERRIDE = {
    ("core-trento-01", "GigabitEthernet0/0/3"):
        "sw-trento-01 Gi1/0/21 - transito rtr-cles-01",
    ("core-trento-01", "GigabitEthernet0/0/4"):
        "sw-trento-01 Gi1/0/21 - transito rtr-cles-01",
}
_PHYS_PEER = {
    ("core-trento-01", "GigabitEthernet0/0/3"): "sw-trento-01 Gi1/0/20",
    ("core-trento-01", "GigabitEthernet0/0/4"): "sw-trento-01 Gi1/0/21",
}


def _router_interfaces(dev):
    name = dev["name"]
    lo = T.LOOPBACK[name]
    lines = ["interface Loopback0", " description router-id e gestione",
             " ip address %s 255.255.255.255" % lo,
             " ipv6 address 2001:db8:c1a5:fe::%s/128" % lo.rsplit(".", 1)[1],
             "!"]
    done_phys = []
    for intf, peer, peer_intf, address, index, side in _p2p_lines(name):
        if "." in intf:
            phys, vlan = intf.split(".")
            if phys not in done_phys:
                done_phys.append(phys)
                descr = _DESCR_OVERRIDE.get((name, phys),
                                            _PHYS_PEER.get((name, phys), ""))
                lines += ["interface %s" % phys,
                          " description %s" % descr,
                          " no ip address", " negotiation auto", "!"]
            lines += ["interface %s" % intf,
                      " description %s %s" % (peer, peer_intf),
                      " encapsulation dot1Q %s" % vlan]
        else:
            lines += ["interface %s" % intf,
                      " description %s %s" % (peer, peer_intf)]
        lines += [" ip address %s 255.255.255.254" % address,
                  " ipv6 address 2001:db8:c1a5:ff::%x/127"
                  % (index * 2 + side),
                  " ip ospf network point-to-point",
                  " ip ospf 1 area 0", " mtu 9100" if "." not in intf
                  else " ip mtu 1500", "!"]
    if name == "core-trento-01":
        lines += ["interface TenGigabitEthernet0/0/5",
                  " description sw-trento-01 Te1/1/3",
                  " no ip address", "!",
                  "interface TenGigabitEthernet0/0/5.20",
                  " description servizi (SBC, DNS, portale hotspot)",
                  " encapsulation dot1Q 20",
                  " ip address 203.0.113.65 255.255.255.224", "!",
                  "interface TenGigabitEthernet0/0/5.999",
                  " description gestione",
                  " encapsulation dot1Q 999",
                  " ip address %s 255.255.255.192" % dev["mgmt4"],
                  " standby 1 ip %s" % T.MGMT_GW,
                  " standby 1 priority 110",
                  " ipv6 address %s/64" % dev["mgmt6"], "!"]
    else:
        lines += ["interface GigabitEthernet0/0/7",
                  " description sw-rovereto-01 Gi1/0/2 (gestione)",
                  " ip address %s 255.255.255.192" % dev["mgmt4"],
                  " ipv6 address %s/64" % dev["mgmt6"], "!"]
    lines += ["interface GigabitEthernet0",
              " description porta di servizio (non cablata)",
              " no ip address", " shutdown", "!"]
    return lines


def _routing(dev):
    name = dev["name"]
    peers = [p for p in ("core-trento-01", "bdr-trento-01", "core-rovereto-01")
             if p != name]
    lines = ["router ospf 1",
             " router-id %s" % T.LOOPBACK[name],
             " passive-interface Loopback0",
             " log-adjacency-changes detail", "!",
             "router bgp %d" % T.OWN_AS,
             " bgp router-id %s" % T.LOOPBACK[name],
             " bgp log-neighbor-changes"]
    for peer in peers:
        lines += [" neighbor %s remote-as %d" % (T.LOOPBACK[peer], T.OWN_AS),
                  " neighbor %s description iBGP %s" % (T.LOOPBACK[peer], peer),
                  " neighbor %s update-source Loopback0" % T.LOOPBACK[peer]]
    lines += [" !", " address-family ipv4"]
    for peer in peers:
        lines.append("  neighbor %s activate" % T.LOOPBACK[peer])
    lines += [" exit-address-family", "!",
              "ip route 0.0.0.0 0.0.0.0 Null0 250 name scarto-di-sicurezza",
              "!"]
    return lines


def render_router(dev, rng):
    lines = _header(dev, rng)
    lines += ["ipv6 unicast-routing", "!"]
    lines += _router_interfaces(dev)
    lines += _routing(dev)
    lines += _mgmt_services(dev, rng)
    return base.lines_to_text(lines)


_SWITCH_PORTS = {
    "sw-trento-01": [
        ("GigabitEthernet1/0/1", "olt-trento-01 0/9/0", "100,210,999", None),
        ("GigabitEthernet1/0/2", "rtr-pergine-01 sfp1 (fibra Pergine)",
         "101,902,999", None),
        ("GigabitEthernet1/0/3", "ptp-trento-01 (ponte radio verso Cles)",
         "103,300,903,999", None),
        ("GigabitEthernet1/0/10", "radius-trento-01", "999", "access"),
        ("GigabitEthernet1/0/11", "dhcp-trento-01", "999", "access"),
        ("GigabitEthernet1/0/12", "sbc-trento-01", "20,999", None),
        ("GigabitEthernet1/0/13", "pbx-trento-01", "999", "access"),
        ("GigabitEthernet1/0/14", "bdr-trento-01 em0 (gestione)", "999",
         "access"),
        ("GigabitEthernet1/0/20", "core-trento-01 Gi0/0/3", "902", None),
        ("GigabitEthernet1/0/21", "core-trento-01 Gi0/0/4", "903", None),
        ("TenGigabitEthernet1/1/1", "bng-trento-01 sfp-sfpplus2",
         "100,101,102,103,210,300,312,999", None),
        ("TenGigabitEthernet1/1/2", "sw-rovereto-01 Te1/1/1 "
         "(fibra Trento-Rovereto)", "102,300,312,999", "native999"),
        ("TenGigabitEthernet1/1/3", "core-trento-01 Te0/0/5", "20,999", None),
    ],
    "sw-rovereto-01": [
        ("GigabitEthernet1/0/1", "olt-rovereto-01 0/9/0", "102,300,312,999",
         None),
        ("GigabitEthernet1/0/2", "core-rovereto-01 Gi0/0/7", "999", "access"),
        ("TenGigabitEthernet1/1/1", "sw-trento-01 Te1/1/2 "
         "(fibra Trento-Rovereto)", "102,300,312,999", None),
    ],
}


def render_switch(dev, rng):
    name = dev["name"]
    lines = _header(dev, rng)
    lines += ["vtp mode transparent", "spanning-tree mode rapid-pvst",
              "spanning-tree extend system-id", "!"]
    used = [int(v) for v in sorted(T.VLANS)]
    if name == "sw-trento-01":
        used = sorted(set(used + [20]))
    for vlan in used:
        label = T.VLANS.get(vlan, "servizi")
        lines += ["vlan %d" % vlan, " name %s" % label, "!"]
    lines += ["cdp run", "!"]
    for port, descr, allowed, mode in _SWITCH_PORTS[name]:
        lines += ["interface %s" % port, " description %s" % descr]
        if mode == "access":
            lines += [" switchport mode access",
                      " switchport access vlan %s" % allowed,
                      " spanning-tree portfast"]
        else:
            lines += [" switchport mode trunk"]
            if mode == "native999":
                lines.append(" switchport trunk native vlan 999")
            lines += [" switchport trunk allowed vlan %s" % allowed,
                      " switchport nonegotiate"]
        lines.append("!")
    lines += ["interface Vlan1", " no ip address", " shutdown", "!",
              "interface Vlan999", " description gestione",
              " ip address %s 255.255.255.192"
              % _p(name, "mgmt_ip", dev["mgmt4"]),
              " ipv6 address %s/64" % dev["mgmt6"], "!",
              "ip default-gateway %s" % T.MGMT_GW, "!"]
    lines += _mgmt_services(dev, rng)
    return base.lines_to_text(lines)


def render(dev, rng):
    if dev["role"] == "switch":
        return render_switch(dev, rng)
    return render_router(dev, rng)
