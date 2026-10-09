"""Configurazione in stile Juniper Junos del router di bordo.

Sintassi gerarchica ispirata a quella di Junos, semplificata: non e'
l'output esatto di alcun apparato.
"""

from . import base
from . import topologia as T


def _block(name, body, indent):
    pad = "    " * indent
    return ["%s%s {" % (pad, name)] + body + ["%s}" % pad]


def _st(text, indent):
    end = "" if text.endswith("}") else ";"
    return "%s%s%s" % ("    " * indent, text, end)


def _system(dev, rng):
    hashed = "$6$%s$%s" % (rng.hexstr(16), rng.hexstr(86))
    body = [
        _st("host-name %s" % dev["name"], 2),
        _st("domain-name %s" % T.DOMAIN, 2),
        _st("time-zone UTC", 2),
    ]
    body += _block("root-authentication",
                   [_st('encrypted-password "%s"' % hashed, 3)], 2)
    body += _block("login", _block("user noc", [
        _st("uid 2001", 4), _st("class super-user", 4),
        _st('authentication { ssh-ed25519 "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5'
            'AAAAI%s noc@%s" }' % (rng.hexstr(40), T.DOMAIN), 4)], 3), 2)
    body += _block("services", [
        "            ssh {", _st("protocol-version v2", 4),
        _st("root-login deny", 4), "            }",
        _st("telnet", 3),
        "            netconf {", _st("ssh", 4), "            }",
    ], 2)
    body += _block("syslog", [
        "            host %s {" % T.NMS, _st("any notice", 4),
        _st("authorization info", 4), _st("source-address %s"
                                          % T.LOOPBACK[dev["name"]], 4),
        "            }",
        "            file messages {", _st("any notice", 4),
        _st("authorization info", 4), "            }",
    ], 2)
    body += _block("ntp", [_st("server %s" % s, 3) for s in T.NTP]
                   + [_st("source-address %s" % T.LOOPBACK[dev["name"]], 3)],
                   2)
    body.append(_st("authentication-order password", 2))
    return _block("system", body, 1)


def _interfaces(dev):
    body = []
    links = [(ib, a, ia, net, idx) for idx, (a, ia, b, ib, net)
             in enumerate(T.P2P) if b == dev["name"]]
    for intf, peer, peer_intf, net, idx in links:
        prefix, last = net.rsplit(".", 1)
        body += [
            "        %s {" % intf,
            _st('description "%s %s"' % (peer, peer_intf), 3),
            _st("mtu 9192", 3),
            "            unit 0 {",
            _st("family inet { address %s.%d/31; }" % (prefix, int(last) + 1), 4),
            _st("family inet6 { address 2001:db8:c1a5:ff::%x/127; }"
                % (idx * 2 + 1), 4),
            "            }", "        }"]
    for name, asn, ours4, theirs4, ours6, theirs6, intf in T.TRANSITS:
        body += [
            "        %s {" % intf,
            _st('description "%s AS%d"' % (name, asn), 3),
            "            unit 0 {",
            _st("family inet { address %s/30; }" % ours4, 4),
            _st("family inet6 { address %s/127; }" % ours6, 4),
            "            }", "        }"]
    body += [
        "        em0 {",
        _st('description "sw-trento-01 Gi1/0/14 (gestione)"', 3),
        "            unit 0 {",
        _st("family inet { address %s/26; }" % dev["mgmt4"], 4),
        _st("family inet6 { address %s/64; }" % dev["mgmt6"], 4),
        "            }", "        }",
        "        lo0 {",
        "            unit 0 {",
        _st("family inet { filter { input PROTEGGI-RE; } address %s/32; }"
            % T.LOOPBACK[dev["name"]], 4),
        _st("family inet6 { address 2001:db8:c1a5:fe::130/128; }", 4),
        "            }", "        }"]
    return _block("interfaces", body, 1)


def _policy():
    body = [
        "        prefix-list NOSTRI-V4 {",
        ] + [_st(p, 3) for p in T.ANNOUNCED_V4] + [
        "        }",
        "        prefix-list NOSTRI-V6 {",
        ] + [_st(p, 3) for p in T.ANNOUNCED_V6] + [
        "        }",
        "        policy-statement ESPORTA-TRANSITO {",
        "            term nostri {",
        _st("from prefix-list NOSTRI-V4", 4),
        _st("then accept", 4),
        "            }",
        "            term nostri-v6 {",
        _st("from prefix-list NOSTRI-V6", 4),
        _st("then accept", 4),
        "            }",
        "            term resto { then reject; }",
        "        }",
        "        policy-statement IMPORTA-TRANSITO {",
        "            term nostri-in-ingresso {",
        _st("from prefix-list NOSTRI-V4", 4),
        _st("then reject", 4),
        "            }",
        "            term troppo-specifici {",
        _st("from route-filter 0.0.0.0/0 prefix-length-range /25-/32", 4),
        _st("then reject", 4),
        "            }",
        "            term resto { then { local-preference 100; accept; } }",
        "        }",
    ]
    return _block("policy-options", body, 1)


def _bgp():
    groups = []
    for name, asn, ours4, theirs4, ours6, theirs6, intf in T.TRANSITS:
        stanza = ["            group %s {" % name.upper(),
                  _st("type external", 4),
                  _st('description "%s"' % name, 4),
                  _st("peer-as %d" % asn, 4)]
        if name == "transito-a":
            stanza += [_st("import IMPORTA-TRANSITO", 4),
                       _st("family inet { unicast { prefix-limit { maximum "
                           "1200000; teardown 90 idle-timeout 30; } } }", 4)]
        stanza += [_st("export ESPORTA-TRANSITO", 4),
                   _st("neighbor %s" % theirs4, 4),
                   "            }"]
        groups += stanza
    groups += ["            group IBGP {",
               _st("type internal", 4),
               _st("local-address %s" % T.LOOPBACK["bdr-trento-01"], 4),
               _st("neighbor %s" % T.LOOPBACK["core-trento-01"], 4),
               _st("neighbor %s" % T.LOOPBACK["core-rovereto-01"], 4),
               "            }"]
    body = (["        bgp {", _st("log-updown", 3)] + groups
            + ["        }",
               "        ospf {",
               "            area 0.0.0.0 {",
               _st("interface xe-0/0/0.0 { interface-type p2p; }", 4),
               _st("interface lo0.0 { passive; }", 4),
               "            }", "        }"])
    return _block("protocols", body, 1)


def _firewall():
    body = [
        "        policer LIMITA-ICMP {",
        _st("if-exceeding { bandwidth-limit 1m; burst-size-limit 15k; }", 3),
        _st("then discard", 3),
        "        }",
        "        family inet {",
        "            filter PROTEGGI-RE {",
        "                term gestione {",
        _st("from { source-address { 192.0.2.0/26; } protocol tcp; "
            "destination-port [ ssh netconf ]; }", 5),
        _st("then accept", 5),
        "                }",
        "                term bgp { from { protocol tcp; port bgp; } "
        "then accept; }",
        "                term ntp-e-radius { from { protocol udp; source-port "
        "[ ntp radius ]; } then accept; }",
        "                term icmp { from protocol icmp; then { policer "
        "LIMITA-ICMP; accept; } }",
        "                term resto { then { syslog; discard; } }",
        "            }", "        }"]
    return _block("firewall", body, 1)


def render(dev, rng):
    changed = base.at(0, 21, 14, 2).astimezone(base.UTC)
    header = ["## Last commit: %s UTC by noc"
              % changed.strftime("%Y-%m-%d %H:%M:%S"),
              "version %s;" % dev["fw_run"]]
    lines = []
    lines += _system(dev, rng)
    lines += ["    chassis { aggregated-devices { ethernet { device-count 2; "
              "} } }"]
    lines += _interfaces(dev)
    lines += ["    routing-options {",
              _st("router-id %s" % T.LOOPBACK[dev["name"]], 2),
              _st("autonomous-system %d" % T.OWN_AS, 2),
              "        static {",
              _st("route 198.51.100.0/24 discard", 3),
              _st("route 203.0.113.0/24 discard", 3),
              "        }",
              "    }"]
    lines += _bgp()
    lines += _policy()
    lines += _firewall()
    lines = [l[4:] if l.startswith("    ") else l for l in lines]
    return base.lines_to_text(header + lines)
