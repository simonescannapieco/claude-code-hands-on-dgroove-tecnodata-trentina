"""Configurazioni dei server: RADIUS, DHCP, SBC SIP, centralino cloud.

Ogni file e' ispirato alla sintassi del software indicato (FreeRADIUS,
ISC Kea, Kamailio, Asterisk PJSIP), semplificata: non e' l'output esatto di
alcuna installazione.
"""

import json

from . import base
from . import topologia as T

# Pool dinamico della VLAN 312 (Rovereto): 14 indirizzi.
POOL_312 = ("198.51.100.200", "198.51.100.213")
POOL_210 = ("198.51.100.230", "198.51.100.250")
LEASE_312 = 604800


def radius_clients(dev, rng):
    out = ["# clients.conf - client RADIUS di %s" % dev["name"],
           "# un blocco per ogni apparato che interroga il server", ""]
    clients = ["bng-trento-01", "core-trento-01", "core-rovereto-01",
               "sw-trento-01", "sw-rovereto-01",
               "rtr-pergine-01", "rtr-cles-01", "bts-cles-01",
               "olt-trento-01", "olt-pergine-01", "olt-rovereto-01"]
    for name in clients:
        device = T.DEVICE[name]
        out += ["client %s {" % name,
                "\tipaddr = %s" % device["mgmt4"],
                "\tsecret = %s" % T.radius_secret(name),
                "\tshortname = %s" % name,
                "\tnas_type = other",
                "\trequire_message_authenticator = yes",
                "\tlimit {",
                "\t\tmax_connections = 16",
                "\t\tlifetime = 0",
                "\t\tidle_timeout = 30",
                "\t}",
                "}", ""]
    out += ["client prova-laboratorio {",
            "\tipaddr = 0.0.0.0/0",
            "\tsecret = testing123",
            "\tshortname = prova",
            "}"]
    return base.lines_to_text(out)


def radius_authorize(dev, rng):
    out = ["# mods-config/files/authorize - regole comuni",
           "# le utenze PPPoE stanno nel database; qui solo i default", "",
           "DEFAULT Framed-Protocol == PPP",
           "\tService-Type = Framed-User,",
           "\tFramed-Protocol = PPP,",
           "\tFramed-MTU = 1492,",
           "\tAcct-Interim-Interval = 43200,",
           "\tFall-Through = Yes", "",
           "DEFAULT Huntgroup-Name == \"apparati\"",
           "\tService-Type = Administrative-User,",
           "\tFall-Through = No"]
    return base.lines_to_text(out)


def kea(dev, rng, all_lines):
    statics = [l for l in all_lines if l["vlan"] == 300]
    subnets = [
        {"id": 210, "subnet": "198.51.100.224/27",
         "relay": {"ip-addresses": ["198.51.100.225"]},
         "pools": [{"pool": "%s - %s" % POOL_210}],
         "option-data": [{"name": "routers", "data": "198.51.100.225"}],
         "user-context": {"vlan": 210, "descrizione": "business Trento"}},
        {"id": 300, "subnet": "203.0.113.0/26",
         "relay": {"ip-addresses": ["203.0.113.1"]},
         "pools": [],
         "option-data": [{"name": "routers", "data": "203.0.113.1"}],
         "reservations": [
             {"hw-address": base.mac(l["mac"]), "ip-address": l["ip"],
              "hostname": l["id"].replace("-", "").lower(),
              "user-context": {"linea": l["id"],
                               "prefisso-ipv6": "2001:db8:c1a5:%s00::/56"
                               % l["id"][-1]}} for l in statics],
         "user-context": {"vlan": 300, "descrizione": "business statici"}},
        {"id": 312, "subnet": "198.51.100.192/27",
         "relay": {"ip-addresses": ["198.51.100.193"]},
         "pools": [{"pool": "%s - %s" % POOL_312}],
         "valid-lifetime": LEASE_312,
         "renew-timer": LEASE_312 // 2,
         "rebind-timer": LEASE_312 * 7 // 8,
         "option-data": [{"name": "routers", "data": "198.51.100.193"}],
         "user-context": {"vlan": 312, "descrizione": "business Rovereto"}},
    ]
    config = {"Dhcp4": {
        "interfaces-config": {"interfaces": ["ens192"],
                              "dhcp-socket-type": "udp"},
        "lease-database": {"type": "memfile", "persist": True,
                           "name": "/var/lib/kea/kea-leases4.csv",
                           "lfc-interval": 3600},
        "valid-lifetime": 86400,
        "renew-timer": 43200,
        "rebind-timer": 75600,
        "authoritative": True,
        "option-data": [
            {"name": "domain-name-servers", "data": ", ".join(T.DNS)},
            {"name": "domain-name", "data": T.DOMAIN}],
        "subnet4": subnets,
        "loggers": [{"name": "kea-dhcp4",
                     "output-options": [
                         {"output": "/var/log/kea/kea-dhcp4.log",
                          "maxver": 8, "maxsize": 10485760}],
                     "severity": "INFO", "debuglevel": 0}],
    }}
    return json.dumps(config, indent=2, ensure_ascii=False) + "\n"


def kamailio(dev, rng):
    out = [
        "#!KAMAILIO",
        "# kamailio.cfg - SBC SIP di %s (estratto)" % dev["name"],
        "",
        "#!define WITH_AUTH",
        "#!define WITH_NAT",
        "#!define DBURL \"mysql://kamailio:kamailiorw@%s/kamailio\""
        % T.DEVICE["pbx-trento-01"]["host"],
        "",
        "debug=2",
        "log_stderror=no",
        "log_facility=LOG_LOCAL0",
        "log_prefix=\"{$mt $hdr(CSeq) $ci} \"",
        "children=8",
        "alias=\"sip.%s\"" % T.DOMAIN,
        "alias=\"voce.%s\"" % T.DOMAIN,
        "listen=udp:%s:5060 advertise %s:5060" % (T.SBC_PUBLIC, T.SBC_PUBLIC),
        "listen=tcp:%s:5060" % T.SBC_PUBLIC,
        "listen=tls:%s:5061" % T.SBC_PUBLIC,
        "listen=udp:%s:5060" % dev["mgmt4"],
        "enable_tls=yes",
        "tcp_connection_lifetime=3605",
        "",
        "loadmodule \"tm.so\"",
        "loadmodule \"sl.so\"",
        "loadmodule \"rr.so\"",
        "loadmodule \"usrloc.so\"",
        "loadmodule \"registrar.so\"",
        "loadmodule \"auth.so\"",
        "loadmodule \"auth_db.so\"",
        "loadmodule \"dispatcher.so\"",
        "loadmodule \"nathelper.so\"",
        "loadmodule \"pike.so\"",
        "loadmodule \"xlog.so\"",
        "",
        "modparam(\"usrloc\", \"db_url\", DBURL)",
        "modparam(\"usrloc\", \"db_mode\", 2)",
        "modparam(\"auth_db\", \"db_url\", DBURL)",
        "modparam(\"auth_db\", \"calculate_ha1\", yes)",
        "modparam(\"auth_db\", \"password_column\", \"password\")",
        "modparam(\"registrar\", \"max_expires\", 3600)",
        "modparam(\"registrar\", \"min_expires\", 300)",
        "modparam(\"dispatcher\", \"list_file\", "
        "\"/etc/kamailio/dispatcher.list\")",
        "modparam(\"dispatcher\", \"ds_ping_interval\", 30)",
        "modparam(\"dispatcher\", \"ds_probing_mode\", 1)",
        "modparam(\"dispatcher\", \"ds_probing_threshold\", 2)",
        "modparam(\"pike\", \"sampling_time_unit\", 2)",
        "modparam(\"pike\", \"reqs_density_per_unit\", 30)",
        "modparam(\"nathelper\", \"natping_interval\", 30)",
        "",
        "request_route {",
        "\troute(REQINIT);",
        "\tif (is_method(\"REGISTER\")) {",
        "\t\tif ($rd =~ \"\\.pbx\\.ciaspolink\\.example\\.org$\") {",
        "\t\t\t# centralino cloud: inoltro al gruppo 1 del dispatcher",
        "\t\t\tif (!ds_select_dst(\"1\", \"4\")) {",
        "\t\t\t\tsl_send_reply(\"503\", \"Service Unavailable\");",
        "\t\t\t\texit;",
        "\t\t\t}",
        "\t\t\tt_relay();",
        "\t\t\texit;",
        "\t\t}",
        "\t\troute(AUTH);",
        "\t\tsave(\"location\");",
        "\t\texit;",
        "\t}",
        "\troute(RELAY);",
        "}",
        "",
        "route[REQINIT] {",
        "\tif (!pike_check_req()) { exit; }",
        "\tif (!mf_process_maxfwd_header(\"10\")) {",
        "\t\tsl_send_reply(\"483\", \"Too Many Hops\");",
        "\t\texit;",
        "\t}",
        "}",
        "",
        "route[AUTH] {",
        "\tif (!auth_check(\"$fd\", \"subscriber\", \"1\")) {",
        "\t\tauth_challenge(\"$fd\", \"0\");",
        "\t\texit;",
        "\t}",
        "}",
    ]
    return base.lines_to_text(out)


def dispatcher_list(dev, rng):
    out = ["# dispatcher.list - gruppi di destinazione dell'SBC",
           "# gruppo 1: centralino cloud (pbx-trento-01)",
           "1 sip:%s:5060 0 0 duid=pbx-trento-01;weight=100" % T.PBX]
    return base.lines_to_text(out)


def pbx_endpoints(all_lines):
    """Interni del centralino cloud: (cliente, dominio, interno)."""
    result = []
    for line in all_lines:
        extra = line["extra"] or ""
        if not extra.startswith("centralino:"):
            continue
        count = int(extra.split(":")[1])
        owner = (line["customer"] or line["id"]).replace("-", "").lower()
        for ext in range(201, 201 + count):
            result.append((line, owner, ext))
    return result


def pjsip(dev, rng, all_lines):
    out = ["; pjsip.conf - centralino cloud multi-cliente di %s" % dev["name"],
           "", "[transport-udp]", "type=transport", "protocol=udp",
           "bind=%s:5060" % T.PBX, "", "[endpoint-base](!)",
           "type=endpoint", "context=uscite", "disallow=all",
           "allow=g722,alaw", "direct_media=no", "rtp_symmetric=yes",
           "force_rport=yes", "rewrite_contact=yes", "",
           "[aor-base](!)", "type=aor", "max_contacts=1",
           "remove_existing=yes", "qualify_frequency=60", ""]
    for line, owner, ext in pbx_endpoints(all_lines):
        name = "%s-%d" % (owner, ext)
        if owner == "cl000103":
            password = "Falegnameria2025"
        else:
            password = "Px%s" % rng.hexstr(18)
        out += ["[%s](endpoint-base)" % name,
                "auth=%s" % name, "aors=%s" % name,
                "callerid=\"Interno %d\" <%d>" % (ext, ext),
                "set_var=CLIENTE=%s" % owner.upper(), "",
                "[%s](aor-base)" % name, "",
                "[%s]" % name, "type=auth", "auth_type=userpass",
                "username=%s" % name, "password=%s" % password,
                "realm=%s.pbx.%s" % (owner, T.DOMAIN), ""]
    return base.lines_to_text(out[:-1])
