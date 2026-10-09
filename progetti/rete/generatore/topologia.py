"""La rete dell'operatore immaginario CiaspoLink: apparati, collegamenti, linee.

Piano di indirizzamento (solo intervalli di documentazione):
  192.0.2.0/26     VLAN 999 di gestione (gateway 192.0.2.62)
  192.0.2.64/27    collegamenti punto-punto /31 fra router
  192.0.2.128/27   loopback dei router
  198.51.100.0/25  pool PPPoE casa-1        198.51.100.128/26  pool PPPoE casa-2
  198.51.100.192/27 business dinamici VLAN 312 (Rovereto)
  198.51.100.224/27 business dinamici VLAN 210 (Trento)
  203.0.113.0/26   business con IP statico (VLAN 300)
  203.0.113.64/27  servizi (SBC, DNS, portale hotspot)
  203.0.113.128/30, 203.0.113.132/30  collegamenti con i due transiti
  2001:db8:c1a5::/48 l'aggregato IPv6 dell'operatore
"""

DOMAIN = "ciaspolink.example.org"
OWN_AS = 64500
TRANSITS = [
    # nome, AS, nostro IPv4, loro IPv4, nostro IPv6, loro IPv6, interfaccia
    ("transito-a", 64496, "203.0.113.130", "203.0.113.129",
     "2001:db8:fa00::1", "2001:db8:fa00::", "xe-0/0/1"),
    ("transito-b", 64497, "203.0.113.134", "203.0.113.133",
     "2001:db8:fb00::1", "2001:db8:fb00::", "xe-0/0/2"),
]
ANNOUNCED_V4 = ["198.51.100.0/24", "203.0.113.0/24"]
ANNOUNCED_V6 = ["2001:db8:c1a5::/48"]

NMS = "192.0.2.43"          # collettore syslog e monitoraggio
NTP = ["192.0.2.44", "192.0.2.45"]
NOC = "192.0.2.50"          # postazione di salto del NOC
OLD_SYSLOG = "192.0.2.243"  # collettore dismesso
OLD_NTP = "192.0.2.244"     # server NTP dismesso
MGMT_GW = "192.0.2.62"
RADIUS = "192.0.2.41"
DHCP = "192.0.2.42"
SBC_PUBLIC = "203.0.113.70"
PBX = "192.0.2.32"
DNS = ["203.0.113.80", "203.0.113.81"]


def radius_secret(label):
    """Segreto condiviso RADIUS sintetico di un client (uno per apparato)."""
    from .base import fnv1a64
    return "nas-%012x" % (fnv1a64("radius/" + label) & 0xFFFFFFFFFFFF)


def mgmt4(octet):
    return "192.0.2.%d" % octet


def mgmt6(octet):
    return "2001:db8:c1a5::%d" % octet


# Ogni apparato: i dati dell'inventario e i parametri da cui nasce la
# configurazione. "fw" e' il firmware registrato in inventario, "fw_run"
# quello che l'apparato esegue davvero.
_D = [
    # nome, ruolo, comune, sito, dialetto, modello, fw, ottetto, installato,
    # rack, uplink (l'apparato a cui si aggregano i servizi, come nel
    # gestionale; vuoto per il nucleo della rete e per i server)
    ("bng-trento-01", "bng", "Trento", "POP Trento, sala apparati",
     "routeros", "concentratore PPPoE 1RU, 12x10G (modello sintetico CK-B12)",
     "7.16.2", 1, "2023-03-14", "TN-R02 U20", ""),
    ("core-trento-01", "core", "Trento", "POP Trento, sala apparati",
     "ios-xe", "router di core 2RU, 8x10G + 8x1G (modello sintetico CK-C28)",
     "17.9.4a", 2, "2022-11-07", "TN-R01 U30", ""),
    ("bdr-trento-01", "border", "Trento", "POP Trento, sala apparati",
     "junos", "router di bordo 1RU, 4x10G (modello sintetico CK-E04)",
     "22.4R3-S2", 3, "2022-11-08", "TN-R01 U34", ""),
    ("core-rovereto-01", "core", "Rovereto", "POP Rovereto",
     "ios-xe", "router di aggregazione 1RU, 4x10G (modello sintetico CK-C14)",
     "17.9.4a", 4, "2023-06-20", "RV-R01 U18", ""),
    ("rtr-pergine-01", "router", "Pergine Valsugana",
     "armadio Pergine Valsugana", "routeros",
     "router 1RU, 10x1G + 1xSFP+ (modello sintetico CK-V11)",
     "7.15.3", 5, "2021-04-12", "PE-A01 U8", "bng-trento-01"),
    ("rtr-cles-01", "router", "Cles", "traliccio Cles",
     "routeros", "router 1RU, 10x1G + 1xSFP+ (modello sintetico CK-V11)",
     "7.15.3", 6, "2022-05-03", "CL-A01 U6", "ptp-cles-01"),
    ("sw-trento-01", "switch", "Trento", "POP Trento, sala apparati",
     "ios", "switch di aggregazione 48x1G + 4x10G (modello sintetico CK-S48)",
     "17.9.4a", 7, "2022-11-07", "TN-R01 U36", ""),
    ("sw-rovereto-01", "switch", "Rovereto", "POP Rovereto",
     "ios", "switch di aggregazione 24x1G + 4x10G (modello sintetico CK-S24)",
     "17.9.4a", 8, "2023-06-20", "RV-R01 U20", ""),
    ("olt-trento-01", "olt", "Trento", "POP Trento, sala apparati",
     "olt", "OLT GPON/XGS-PON, 2 schede da 16 porte (modello sintetico CK-O16)",
     "V5.2.1", 11, "2022-12-01", "TN-R03 U10", "bng-trento-01"),
    ("olt-pergine-01", "olt", "Pergine Valsugana",
     "armadio Pergine Valsugana", "olt",
     "OLT GPON compatta, 8 porte (modello sintetico CK-O08)",
     "V5.2.1", 12, "2021-04-12", "PE-A01 U2", "bng-trento-01"),
    ("olt-rovereto-01", "olt", "Rovereto", "POP Rovereto",
     "olt", "OLT GPON/XGS-PON, 2 schede da 16 porte (modello sintetico CK-O16)",
     "V5.2.1", 13, "2023-06-22", "RV-R02 U10", "bng-trento-01"),
    ("ptp-trento-01", "ptp", "Trento", "traliccio Trento nord",
     "airos", "radio punto-punto 5 GHz con parabola 30 dBi "
     "(modello sintetico CK-L5)", "8.7.11", 20, "2022-05-03", "palo T1",
     "bng-trento-01"),
    ("ptp-cles-01", "ptp", "Cles", "traliccio Cles",
     "airos", "radio punto-punto 5 GHz con parabola 30 dBi "
     "(modello sintetico CK-L5)", "8.7.11", 21, "2022-05-03", "palo C1",
     "bng-trento-01"),
    ("bts-cles-01", "bts", "Cles", "traliccio Cles",
     "routeros", "stazione radio base FWA a tre settori, 3 radio 5 GHz "
     "(modello sintetico CK-W3)", "7.15.3", 22, "2022-05-05", "palo C1",
     "ptp-cles-01"),
    ("bts-cavareno-01", "bts", "Cavareno",
     "traliccio Cavareno", "airos",
     "access point punto-multipunto 5 GHz, settore 90 gradi "
     "(modello sintetico CK-M5)", "8.7.11", 23, "2024-04-18", "palo K1",
     "ptp-cles-01"),
    ("sbc-trento-01", "sbc", "Trento", "POP Trento, sala apparati",
     "kamailio", "server 1RU, session border controller SIP",
     "5.7.4", 31, "2023-09-11", "TN-R04 U12", ""),
    ("pbx-trento-01", "pbx", "Trento",
     "POP Trento, sala apparati", "asterisk",
     "server 1RU, centralino in cloud multi-cliente", "20.9.2", 32,
     "2023-09-11", "TN-R04 U14", ""),
    ("radius-trento-01", "radius", "Trento", "POP Trento, sala apparati",
     "freeradius", "macchina virtuale, autenticazione PPPoE e apparati",
     "3.2.5", 41, "2022-11-15", "TN-R04 VM", ""),
    ("dhcp-trento-01", "dhcp", "Trento", "POP Trento, sala apparati",
     "kea", "macchina virtuale, DHCPv4 per le linee business",
     "2.6.1", 42, "2023-02-02", "TN-R04 VM", ""),
]

# Le descrizioni del gestionale, per gli apparati che vi compaiono.
DESCRIPTION = {
    "bng-trento-01": "BNG: terminazione PPPoE con RADIUS e DHCP delle linee "
                     "business",
    "core-trento-01": "Router di core del POP di Trento",
    "bdr-trento-01": "Router di bordo: BGP con i due transiti",
    "core-rovereto-01": "Router di aggregazione del POP di Rovereto",
    "rtr-pergine-01": "Router di valle di Pergine Valsugana: porta le VLAN "
                      "dell'OLT verso il BNG",
    "rtr-cles-01": "Router di valle della Val di Non: porta le VLAN delle "
                   "stazioni radio verso il BNG",
    "sw-trento-01": "Switch di aggregazione del POP di Trento",
    "sw-rovereto-01": "Switch di aggregazione del POP di Rovereto",
    "olt-trento-01": "OLT GPON e XGS-PON di Trento",
    "olt-pergine-01": "OLT GPON di Pergine Valsugana",
    "olt-rovereto-01": "OLT GPON e XGS-PON di Rovereto",
    "ptp-trento-01": "Ponte radio punto-punto verso Cles, capo di Trento",
    "ptp-cles-01": "Ponte radio punto-punto verso Cles",
    "bts-cles-01": "Stazione radio base FWA di Cles, tre settori",
    "bts-cavareno-01": "Stazione radio base FWA di Cavareno, un settore",
    "sbc-trento-01": "Session border controller SIP per voce e centralino "
                     "cloud",
    "pbx-trento-01": "Centralino cloud multi-cliente",
    "radius-trento-01": "Server RADIUS: utenze PPPoE e accesso agli apparati",
    "dhcp-trento-01": "Server DHCPv4 delle linee business",
}

# Il collegamento fisico verso il nucleo della rete (apparato e porta).
PHYSICAL = {
    "bng-trento-01": "core-trento-01 Te0/0/1",
    "core-trento-01": "bdr-trento-01 xe-0/0/0",
    "bdr-trento-01": "transiti su xe-0/0/1 e xe-0/0/2",
    "core-rovereto-01": "core-trento-01 Te0/0/2",
    "rtr-pergine-01": "sw-trento-01 Gi1/0/2",
    "rtr-cles-01": "ptp-cles-01 eth0",
    "sw-trento-01": "core-trento-01 Te0/0/5",
    "sw-rovereto-01": "sw-trento-01 Te1/1/2",
    "olt-trento-01": "sw-trento-01 Gi1/0/1",
    "olt-pergine-01": "rtr-pergine-01 ether2",
    "olt-rovereto-01": "sw-rovereto-01 Gi1/0/1",
    "ptp-trento-01": "sw-trento-01 Gi1/0/3",
    "ptp-cles-01": "ptp-trento-01 via radio",
    "bts-cles-01": "rtr-cles-01 ether2",
    "bts-cavareno-01": "rtr-cles-01 ether3",
    "sbc-trento-01": "sw-trento-01 Gi1/0/12",
    "pbx-trento-01": "sw-trento-01 Gi1/0/13",
    "radius-trento-01": "sw-trento-01 Gi1/0/10",
    "dhcp-trento-01": "sw-trento-01 Gi1/0/11",
}

DIALECT_LABEL = {
    "ios-xe": "in stile Cisco IOS-XE",
    "ios": "in stile Cisco IOS (switch)",
    "junos": "in stile Juniper Junos",
    "routeros": "in stile MikroTik RouterOS",
    "olt": "in stile CLI di OLT GPON (telaio/scheda/porta)",
    "airos": "in stile Ubiquiti airOS (system.cfg)",
    "kamailio": "in stile Kamailio (SBC SIP)",
    "asterisk": "in stile Asterisk PJSIP",
    "freeradius": "in stile FreeRADIUS",
    "kea": "in stile ISC Kea DHCPv4",
}

# Differenze fra quanto registrato in inventario e quanto gira davvero.
_RUNNING_FW = {"rtr-pergine-01": "6.49.10", "olt-pergine-01": "V3.1.0"}


def _serial(index, name):
    letters = "ABCDEFGHJKLMNPRSTUVWXYZ"
    code = sum(ord(c) for c in name)
    return "CK%02d%s%s%04d" % (21 + index % 5, letters[code % 23],
                               letters[(code // 23) % 23],
                               1000 + (code * 37 + index * 101) % 9000)


DEVICES = []
for _i, _row in enumerate(_D):
    (_name, _role, _comune, _site, _dialect, _model, _fw, _octet,
     _installed, _rack, _uplink) = _row
    DEVICES.append({
        "name": _name, "role": _role, "comune": _comune, "site": _site,
        "dialect": _dialect, "model": _model, "fw": _fw,
        "fw_run": _RUNNING_FW.get(_name, _fw), "octet": _octet,
        "mgmt4": mgmt4(_octet), "mgmt6": mgmt6(_octet),
        "serial": _serial(_i, _name), "installed": _installed,
        "rack": _rack, "uplink": _uplink,
        "host": "%s.%s" % (_name, DOMAIN),
        "description": DESCRIPTION[_name], "physical": PHYSICAL[_name],
    })
DEVICE = {d["name"]: d for d in DEVICES}

LOOPBACK = {"core-trento-01": "192.0.2.129", "bdr-trento-01": "192.0.2.130",
            "bng-trento-01": "192.0.2.131", "core-rovereto-01": "192.0.2.132",
            "rtr-pergine-01": "192.0.2.133", "rtr-cles-01": "192.0.2.134"}

# Collegamenti instradati /31: (a, interfaccia a, b, interfaccia b, rete)
P2P = [
    ("core-trento-01", "TenGigabitEthernet0/0/0", "bdr-trento-01",
     "xe-0/0/0", "192.0.2.64"),
    ("core-trento-01", "TenGigabitEthernet0/0/1", "bng-trento-01",
     "sfp-sfpplus1", "192.0.2.66"),
    ("core-trento-01", "TenGigabitEthernet0/0/2", "core-rovereto-01",
     "TenGigabitEthernet0/0/0", "192.0.2.68"),
    ("core-trento-01", "GigabitEthernet0/0/3.902", "rtr-pergine-01",
     "vlan902", "192.0.2.70"),
    ("core-trento-01", "GigabitEthernet0/0/4.903", "rtr-cles-01",
     "vlan903", "192.0.2.72"),
]

VLANS = {
    100: "pppoe-trento", 101: "pppoe-pergine", 102: "pppoe-rovereto",
    103: "pppoe-valdinon", 210: "biz-trento", 300: "biz-statici",
    312: "biz-rovereto", 902: "transito-pergine", 903: "transito-cles",
    999: "gestione",
}

# Linee con nome: le stesse del gestionale e dell'assistenza clienti.
NAMED_LINES = [
    # linea, cliente, comune, tecnologia, offerta, accesso, apparato,
    # porta, MAC, IPv4 statico, voce
    ("LN-000201", "CL-000101", "Pergine Valsugana", "FTTH", "casa", "pppoe",
     "olt-pergine-01", "0/1/3", 0x01, None, "voce"),
    ("LN-000202", "CL-000102", "Cles", "FWA", "business", "dhcp",
     "bts-cles-01", "S1", 0x02, "203.0.113.2", None),
    ("LN-000203", "CL-000103", "Rovereto", "FTTH", "business", "dhcp",
     "olt-rovereto-01", "0/1/2", 0x03, "203.0.113.3", "centralino:6"),
    ("LN-000204", "CL-000104", "Cles", "FWA", "casa", "pppoe",
     "bts-cles-01", "S2", 0x04, None, None),
    ("LN-000205", "CL-000105", "Riva del Garda", "FTTH", "business", "dhcp",
     "olt-rovereto-01", "0/2/5", 0x05, "203.0.113.5", "hotspot"),
    ("LN-000206", "CL-000106", "Trento", "FTTH", "casa", "pppoe",
     "olt-trento-01", "0/1/7", 0x06, None, None),
]

# Linee generate: (apparato, porta, comune, quante, tecnologia, offerta,
# accesso). La porta 0/1/3 di Pergine ha 39 linee oltre a LN-000201.
_GENERATED = [
    ("olt-pergine-01", "0/1/1", "Pergine Valsugana", 8, "FTTH", "casa", "pppoe"),
    ("olt-pergine-01", "0/1/2", "Pergine Valsugana", 6, "FTTH", "casa", "pppoe"),
    ("olt-pergine-01", "0/1/3", "Pergine Valsugana", 39, "FTTH", "casa", "pppoe"),
    ("olt-trento-01", "0/1/1", "Trento", 10, "FTTH", "casa", "pppoe"),
    ("olt-trento-01", "0/1/2", "Trento", 9, "FTTH", "casa", "pppoe"),
    ("olt-trento-01", "0/1/7", "Trento", 9, "FTTH", "casa", "pppoe"),
    ("olt-trento-01", "0/2/1", "Trento", 6, "FTTH", "business", "dhcp"),
    ("olt-rovereto-01", "0/1/1", "Rovereto", 8, "FTTH", "casa", "pppoe"),
    ("olt-rovereto-01", "0/1/2", "Rovereto", 6, "FTTH", "casa", "pppoe"),
    ("olt-rovereto-01", "0/2/1", "Rovereto", 6, "FTTH", "business", "dhcp"),
    ("olt-rovereto-01", "0/2/2", "Rovereto", 5, "FTTH", "business", "dhcp"),
    ("bts-cles-01", "S1", "Cles", 5, "FWA", "casa", "pppoe"),
    ("bts-cles-01", "S2", "Cles", 5, "FWA", "casa", "pppoe"),
    ("bts-cles-01", "S3", "Cles", 6, "FWA", "casa", "pppoe"),
    ("bts-cavareno-01", "S1", "Cavareno", 7, "FWA", "casa", "pppoe"),
]

# Linee generate: LN-006000-LN-006999 (gli altri progetti usano altri
# intervalli; solo le sei linee con nome sono condivise).
FIRST_GENERATED_LINE = 6000
FIRST_GENERATED_MAC = 0x40
SATURDAY_MACS = list(range(0xE0, 0xE9))


def _vlan_for(line):
    if line["access"] == "dhcp":
        if line["ip"]:
            return 300
        return 210 if line["device"] == "olt-trento-01" else 312
    return {"olt-trento-01": 100, "olt-pergine-01": 101,
            "olt-rovereto-01": 102}.get(line["device"], 103)


def _make_line(line_id, customer, comune, tech, offer, access, device, port,
               mac_index, ip, extra):
    line = {"id": line_id, "customer": customer, "comune": comune,
            "tech": tech, "offer": offer, "access": access,
            "device": device, "port": port, "mac": mac_index, "ip": ip,
            "extra": extra}
    line["user"] = ("%s@%s" % (line_id.replace("-", "").lower(), DOMAIN)
                    if access == "pppoe" else None)
    line["vlan"] = _vlan_for(line)
    return line


def build_lines():
    """Tutte le linee, in ordine stabile: prima quelle con nome."""
    lines = [_make_line(*row) for row in NAMED_LINES]
    number = FIRST_GENERATED_LINE
    mac_index = FIRST_GENERATED_MAC
    for device, port, comune, count, tech, offer, access in _GENERATED:
        for _ in range(count):
            line_id = "LN-%06d" % number
            lines.append(_make_line(line_id, None, comune, tech, offer,
                                    access, device, port, mac_index, None,
                                    None))
            number += 1
            mac_index += 1
    if mac_index > min(SATURDAY_MACS):
        raise ValueError("troppe linee per lo spazio MAC di documentazione")
    # Voce: LN-000201 e otto linee casa; due aziende con centralino cloud.
    pppoe_home = [l for l in lines if l["access"] == "pppoe"
                  and l["id"] != "LN-000201"]
    for line in pppoe_home[5:len(pppoe_home):13][:8]:
        line["extra"] = "voce"
    biz_trento = [l for l in lines if l["vlan"] == 210]
    for line in biz_trento[1:3]:
        line["extra"] = "centralino:3"
    # ONT: numerate per porta PON nell'ordine delle linee.
    counters = {}
    for line in lines:
        key = (line["device"], line["port"])
        counters[key] = counters.get(key, 0) + 1
        line["ont"] = counters[key] - 1
        line["sn"] = "CSLK%08X" % (0xA1000000 + int(line["id"][3:]) * 7919)
    return lines


def lines_by(lines, **criteria):
    return [l for l in lines
            if all(l.get(k) == v for k, v in sorted(criteria.items()))]


# Piano radio (la colonna "piano" del registro radio del NOC).
RADIO_PLAN = {
    "ptp-trento-01": {"freq": 5500, "width": 40, "txpower": 20},
    "ptp-cles-01": {"freq": 5500, "width": 40, "txpower": 20},
    "bts-cles-01/S1": {"freq": 5180, "width": 20, "txpower": 18},
    "bts-cles-01/S2": {"freq": 5220, "width": 20, "txpower": 18},
    "bts-cles-01/S3": {"freq": 5260, "width": 20, "txpower": 18},
    "bts-cavareno-01": {"freq": 5300, "width": 20, "txpower": 18},
}
