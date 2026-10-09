"""Esportazioni in stile MikroTik RouterOS (`/export show-sensitive`).

Sintassi ispirata a quella di RouterOS, semplificata: non e' l'output
esatto di alcun apparato.
"""

from . import base
from . import topologia as T

_SNAPSHOT = base.at(6, 23, 50, 0)

_PARAMS = {
    "bng-trento-01": {"snmp": "ciaspolink", "mss": "no", "mtu": 1500},
    "rtr-pergine-01": {"telnet": True},
    "rtr-cles-01": {"syslog": T.OLD_SYSLOG, "ntp": [T.OLD_NTP],
                    "radius_secret": T.radius_secret("rtr-cles-01/2022")},
    "bts-cles-01": {"www": True, "s3_width": "20/40/80mhz-Ceee"},
}


def _p(name, key, default=None):
    return _PARAMS.get(name, {}).get(key, default)


def _header(dev, offset):
    moment = _SNAPSHOT + base.secs(offset)
    if dev["fw_run"].startswith("6."):
        stamp = moment.strftime("%b/%d/%Y %H:%M:%S").lower()
    else:
        stamp = base.ros_time(moment)
    return ["# %s by RouterOS %s" % (stamp, dev["fw_run"]),
            "# software id = %s" % dev["serial"][2:6] + "-" + dev["serial"][6:],
            "#",
            "# model = %s" % dev["model"].split("modello sintetico ")[1]
            .rstrip(")"),
            "# serial number = %s" % dev["serial"]]


def _common(dev):
    name = dev["name"]
    lines = ["/ip dns", "set servers=%s" % ",".join(T.DNS),
             "/ip service"]
    lines.append("set telnet disabled=%s" % ("no" if _p(name, "telnet")
                                              else "yes"))
    lines += ["set ftp disabled=yes",
              # Il servizio web e' attivo di fabbrica: l'esportazione
              # mostra solo cio' che si discosta dal valore predefinito.
              "set www address=192.0.2.0/26" if _p(name, "www")
              else "set www disabled=yes",
              "set ssh address=192.0.2.0/26",
              "set www-ssl address=192.0.2.0/26 certificate=gestione "
              "disabled=no",
              "set api disabled=yes",
              "set winbox address=192.0.2.0/26",
              "set api-ssl disabled=yes"]
    secret = _p(name, "radius_secret", T.radius_secret(name))
    lines += ["/radius",
              "add address=%s secret=%s service=%s src-address=%s "
              "timeout=1s" % (T.RADIUS, secret,
                              "ppp,login" if name == "bng-trento-01"
                              else "login", dev["mgmt4"]),
              "/snmp community"]
    community = _p(name, "snmp")
    if community:
        lines.append("set [ find default=yes ] name=%s" % community)
    else:
        lines += ["set [ find default=yes ] disabled=yes",
                  "add authentication-protocol=SHA1 encryption-protocol=AES "
                  "name=monitor security=private addresses=%s/32" % T.NMS]
    lines += ["/snmp",
              'set contact=noc@%s enabled=yes location="%s" '
              "trap-generators=interfaces trap-target=%s trap-version=3"
              % (T.DOMAIN, dev["site"], T.NMS),
              "/system clock", "set time-zone-name=Europe/Rome",
              "/system identity", "set name=%s" % name,
              "/system logging action",
              "set 3 remote=%s" % _p(name, "syslog", T.NMS),
              "/system logging",
              "add action=remote topics=info",
              "add action=remote topics=error",
              "add action=remote topics=critical",
              "add action=remote topics=warning",
              "add action=remote topics=account",
              "/system ntp client", "set enabled=yes",
              "/system ntp client servers"]
    for server in _p(name, "ntp", T.NTP):
        lines.append("add address=%s" % server)
    lines += ["/user aaa", "set use-radius=yes",
              "/tool mac-server", "set allowed-interface-list=none",
              "/tool mac-server mac-winbox",
              "set allowed-interface-list=none"]
    return lines


def _bng(dev):
    lines = ["/interface bridge", "add name=lo",
             "/interface ethernet",
             "set [ find default-name=sfp-sfpplus1 ] comment="
             '"core-trento-01 Te0/0/1" l2mtu=9100 mtu=9000',
             "set [ find default-name=sfp-sfpplus2 ] comment="
             '"sw-trento-01 Te1/1/1 (VLAN abbonati)" l2mtu=9100',
             "/interface vlan"]
    for vlan in (100, 101, 102, 103, 210, 300, 312, 999):
        lines.append("add interface=sfp-sfpplus2 name=vlan%d-%s vlan-id=%d"
                     % (vlan, T.VLANS[vlan], vlan))
    mtu = _p(dev["name"], "mtu", 1492)
    lines += ["/ip pool",
              "add name=pool-casa-1 ranges=198.51.100.2-198.51.100.126",
              "add name=pool-casa-2 ranges=198.51.100.130-198.51.100.190",
              "add name=pool-casa next-pool=pool-casa-2 "
              "ranges=198.51.100.2-198.51.100.126",
              "/ppp profile",
              "add change-tcp-mss=%s dns-server=%s local-address=198.51.100.1 "
              "name=casa only-one=yes remote-address=pool-casa use-ipv6=yes "
              "use-upnp=no" % (_p(dev["name"], "mss", "yes"), ",".join(T.DNS)),
              "/interface pppoe-server server"]
    for vlan in (100, 101, 102, 103):
        lines.append("add authentication=pap,chap default-profile=casa "
                     "disabled=no interface=vlan%d-%s "
                     "max-mru=%d max-mtu=%d one-session-per-host=yes "
                     "service-name=%s-%d"
                     % (vlan, T.VLANS[vlan], mtu, mtu, T.VLANS[vlan], vlan))
    lines += ["/ip address",
              "add address=%s/26 interface=vlan999-gestione" % dev["mgmt4"],
              "add address=192.0.2.67/31 interface=sfp-sfpplus1",
              "add address=%s interface=lo" % T.LOOPBACK["bng-trento-01"],
              "add address=203.0.113.1/26 interface=vlan300-biz-statici",
              "add address=198.51.100.193/27 interface=vlan312-biz-rovereto",
              "add address=198.51.100.225/27 interface=vlan210-biz-trento",
              "/ipv6 address",
              "add address=%s/64 advertise=no interface=vlan999-gestione"
              % dev["mgmt6"],
              "/ip dhcp-relay"]
    for vlan, local in ((210, "198.51.100.225"), (300, "203.0.113.1"),
                        (312, "198.51.100.193")):
        lines.append("add add-relay-info=yes dhcp-server=%s disabled=no "
                     "interface=vlan%d-%s local-address=%s name=relay-%s"
                     % (T.DHCP, vlan, T.VLANS[vlan], local, T.VLANS[vlan]))
    lines += ["/ppp aaa",
              "set interim-update=12h use-radius=yes",
              "/radius incoming", "set accept=yes",
              "/routing ospf instance",
              "add name=ospf1 originate-default=never router-id=%s"
              % T.LOOPBACK["bng-trento-01"],
              "/routing ospf area", "add instance=ospf1 name=backbone",
              "/routing ospf interface-template",
              "add area=backbone interfaces=sfp-sfpplus1 type=ptp",
              "add area=backbone interfaces=lo passive",
              "/ip firewall filter",
              "add action=accept chain=input connection-state="
              "established,related",
              "add action=accept chain=input protocol=ospf",
              "add action=accept chain=input src-address=192.0.2.0/26",
              "add action=accept chain=input dst-port=67 protocol=udp "
              "comment=\"relay DHCP business\"",
              "add action=drop chain=input in-interface-list=!gestione",
              "/interface list", "add name=gestione",
              "/interface list member",
              "add interface=vlan999-gestione list=gestione"]
    return lines


def _bridge_vlan_lines(uplink, ports):
    """La tabella /interface bridge vlan del bridge di valle."""
    lines = ["/interface bridge vlan"]
    vlan_ports = {}
    for port, _, vlans in [(uplink[0], "", uplink[2])] + list(ports):
        for vlan in vlans:
            vlan_ports.setdefault(vlan, []).append(port)
    for vlan in sorted(vlan_ports):
        tagged = ["br-valle"] + vlan_ports[vlan]
        lines.append("add bridge=br-valle tagged=%s vlan-ids=%d"
                     % (",".join(tagged), vlan))
    return lines


def _valley_v6(dev, uplink, ports, transit_vlan, transit_ip):
    """Il router di valle con RouterOS 6: stesse scelte, sintassi della 6.

    Nell'esportazione della 6 l'OSPF ha istanza predefinita, interfacce e
    reti; le route non hanno routing-table; il client NTP ha primary-ntp e
    secondary-ntp; i valori predefiniti non compaiono.
    """
    name = dev["name"]
    transit = "vlan%d-%s" % (transit_vlan, T.VLANS[transit_vlan])
    prefix, last = transit_ip.rsplit(".", 1)
    network = "%s.%d/31" % (prefix, int(last) & ~1)
    telnet = ("set telnet address=192.0.2.0/26" if _p(name, "telnet")
              else "set telnet disabled=yes")
    lines = ["/interface bridge",
             "add name=br-valle vlan-filtering=yes",
             "/interface ethernet",
             "set [ find default-name=%s ] comment=\"%s\""
             % (uplink[0], uplink[1])]
    for port, comment, _ in ports:
        lines.append("set [ find default-name=%s ] comment=\"%s\""
                     % (port, comment))
    lines += ["/interface vlan",
              "add interface=br-valle name=%s vlan-id=%d"
              % (transit, transit_vlan),
              "add interface=br-valle name=vlan999-gestione vlan-id=999",
              "/routing ospf instance",
              "set [ find default=yes ] router-id=%s" % T.LOOPBACK[name],
              "/snmp community",
              "set [ find default=yes ] disabled=yes",
              "add addresses=%s/32 authentication-protocol=SHA1 "
              "encryption-protocol=AES name=monitor security=private"
              % T.NMS,
              "/system logging action",
              "set 3 remote=%s" % T.NMS,
              "/interface bridge port",
              "add bridge=br-valle interface=%s" % uplink[0]]
    for port, _, _ in ports:
        lines.append("add bridge=br-valle interface=%s" % port)
    lines += _bridge_vlan_lines(uplink, ports)
    lines += ["/ip address",
              "add address=%s/26 interface=vlan999-gestione" % dev["mgmt4"],
              "add address=%s/31 interface=%s" % (transit_ip, transit),
              "add address=%s interface=br-valle" % T.LOOPBACK[name],
              "/ip dns",
              "set servers=%s" % ",".join(T.DNS),
              "/ip route",
              "add comment=\"riserva per la gestione\" distance=200 "
              "dst-address=192.0.2.0/24 gateway=%s" % T.MGMT_GW,
              "/ip service",
              telnet,
              "set ftp disabled=yes",
              "set www disabled=yes",
              "set ssh address=192.0.2.0/26",
              "set www-ssl address=192.0.2.0/26 certificate=gestione "
              "disabled=no",
              "set api disabled=yes",
              "set winbox address=192.0.2.0/26",
              "set api-ssl disabled=yes",
              "/ipv6 address",
              "add address=%s/64 advertise=no interface=vlan999-gestione"
              % dev["mgmt6"],
              "/radius",
              "add address=%s secret=%s service=login src-address=%s "
              "timeout=1s" % (T.RADIUS, T.radius_secret(name), dev["mgmt4"]),
              "/routing ospf interface",
              "add interface=%s network-type=point-to-point" % transit,
              "/routing ospf network",
              "add area=backbone network=%s" % network,
              "/snmp",
              'set contact=noc@%s enabled=yes location="%s" '
              "trap-generators=interfaces trap-target=%s trap-version=3"
              % (T.DOMAIN, dev["site"], T.NMS),
              "/system clock",
              "set time-zone-name=Europe/Rome",
              "/system identity",
              "set name=%s" % name,
              "/system logging",
              "add action=remote topics=info",
              "add action=remote topics=error",
              "add action=remote topics=critical",
              "add action=remote topics=warning",
              "add action=remote topics=account",
              "/system ntp client",
              "set enabled=yes primary-ntp=%s secondary-ntp=%s"
              % (T.NTP[0], T.NTP[1]),
              "/tool mac-server",
              "set allowed-interface-list=none",
              "/tool mac-server mac-winbox",
              "set allowed-interface-list=none",
              "/user aaa",
              "set use-radius=yes"]
    return lines


def _valley(dev, uplink, ports, transit_vlan, transit_ip):
    name = dev["name"]
    lines = ["/interface bridge",
             "add name=br-valle vlan-filtering=yes",
             "/interface ethernet",
             "set [ find default-name=%s ] comment=\"%s\""
             % (uplink[0], uplink[1])]
    for port, comment, _ in ports:
        lines.append("set [ find default-name=%s ] comment=\"%s\""
                     % (port, comment))
    lines += ["/interface vlan",
              "add interface=br-valle name=vlan%d-%s vlan-id=%d"
              % (transit_vlan, T.VLANS[transit_vlan], transit_vlan),
              "add interface=br-valle name=vlan999-gestione vlan-id=999",
              "/interface bridge port",
              "add bridge=br-valle interface=%s" % uplink[0]]
    for port, _, _ in ports:
        lines.append("add bridge=br-valle interface=%s" % port)
    lines += _bridge_vlan_lines(uplink, ports)
    lines += ["/ip address",
              "add address=%s/26 interface=vlan999-gestione" % dev["mgmt4"],
              "add address=%s/31 interface=vlan%d-%s"
              % (transit_ip, transit_vlan, T.VLANS[transit_vlan]),
              "add address=%s interface=br-valle" % T.LOOPBACK[name],
              "/ipv6 address",
              "add address=%s/64 advertise=no interface=vlan999-gestione"
              % dev["mgmt6"],
              "/ip route",
              "add gateway=%s routing-table=main dst-address=192.0.2.0/24 "
              "distance=200 comment=\"riserva per la gestione\"" % T.MGMT_GW,
              "/routing ospf instance",
              "add name=ospf1 router-id=%s" % T.LOOPBACK[name],
              "/routing ospf area", "add instance=ospf1 name=backbone",
              "/routing ospf interface-template",
              "add area=backbone interfaces=vlan%d-%s type=ptp"
              % (transit_vlan, T.VLANS[transit_vlan])]
    return lines


def _bts(dev, lines_cles):
    plan = T.RADIO_PLAN
    lines = ["/interface bridge", "add name=br-fwa vlan-filtering=yes",
             "/interface ethernet",
             "set [ find default-name=ether1 ] comment=\"rtr-cles-01 ether2\"",
             "/interface wireless security-profiles",
             "set [ find default=yes ] supplicant-identity=MikroTik",
             "add authentication-types=wpa2-psk mode=dynamic-keys name=fwa "
             "wpa2-pre-shared-key=Fwa-Cles-7e2d9a41c0b85f36",
             "/interface wireless"]
    for index, sector in enumerate(("S1", "S2", "S3"), 1):
        radio = plan["bts-cles-01/%s" % sector]
        width = "20mhz"
        band = "5ghz-a/n"
        if sector == "S3":
            width = _p(dev["name"], "s3_width", width)
            band = "5ghz-a/n/ac"
        # 20 MHz e' il valore predefinito: l'esportazione non lo riporta.
        width_prop = "" if width == "20mhz" else "channel-width=%s " % width
        lines.append(
            "set [ find default-name=wlan%d ] band=%s %s"
            "country=italy disabled=no frequency=%d installation=outdoor "
            "mode=ap-bridge name=wlan-%s nv2-security=enabled "
            "radio-name=bts-cles-01-%s security-profile=fwa "
            "ssid=ciaspolink-cles-%s tx-power=%d tx-power-mode="
            "all-rates-fixed wireless-protocol=nv2"
            % (index, band, width_prop, radio["freq"], sector.lower(),
               sector.lower(), sector.lower(), radio["txpower"]))
    lines += ["/interface vlan",
              "add interface=br-fwa name=vlan999-gestione vlan-id=999",
              "/interface bridge port",
              "add bridge=br-fwa interface=ether1"]
    for sector in ("s1", "s2", "s3"):
        lines.append("add bridge=br-fwa interface=wlan-%s pvid=103" % sector)
    lines += ["/interface bridge vlan",
              "add bridge=br-fwa tagged=br-fwa,ether1 vlan-ids=999",
              "add bridge=br-fwa tagged=ether1 untagged=wlan-s1,wlan-s2,"
              "wlan-s3 vlan-ids=103",
              "add bridge=br-fwa tagged=ether1,wlan-s1 vlan-ids=300",
              "/interface wireless access-list"]
    for line in lines_cles:
        extra = ""
        if line["vlan"] == 300:
            extra = " vlan-id=300 vlan-mode=use-tag"
        lines.append("add comment=%s interface=wlan-%s mac-address=%s%s"
                     % (line["id"], line["port"].lower(),
                        base.mac_upper(line["mac"]), extra))
    lines += ["/ip address",
              "add address=%s/26 interface=vlan999-gestione" % dev["mgmt4"],
              "/ipv6 address",
              "add address=%s/64 advertise=no interface=vlan999-gestione"
              % dev["mgmt6"],
              "/ip route", "add gateway=%s" % T.MGMT_GW]
    return lines


def render(dev, rng, all_lines):
    name = dev["name"]
    lines = _header(dev, dev["octet"])
    if name == "bng-trento-01":
        lines += _bng(dev)
    elif name == "rtr-pergine-01":
        if not dev["fw_run"].startswith("6."):
            raise ValueError("rtr-pergine-01: atteso RouterOS 6")
        lines += _valley_v6(dev, ("sfp1", "sw-trento-01 Gi1/0/2",
                                  [101, 902, 999]),
                            [("ether2", "olt-pergine-01 0/9/0", [101, 999])],
                            902, "192.0.2.71")
        return base.lines_to_text(lines)
    elif name == "rtr-cles-01":
        lines += _valley(dev, ("ether1", "ptp-cles-01 (ponte radio verso "
                                         "Trento)", [103, 300, 903, 999]),
                         [("ether2", "bts-cles-01 ether1", [103, 300, 999]),
                          ("ether3", "bts-cavareno-01 (fibra di zona)",
                           [103, 999])], 903, "192.0.2.73")
    elif name == "bts-cles-01":
        lines += _bts(dev, [l for l in all_lines
                            if l["device"] == "bts-cles-01"])
    else:
        raise ValueError("apparato RouterOS sconosciuto: %s" % name)
    lines += _common(dev)
    return base.lines_to_text(lines)
