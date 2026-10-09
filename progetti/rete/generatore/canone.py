"""Le regole dei dati sintetici (progetti/README.md), controllate sull'output.

controlla_testo() restituisce l'elenco delle violazioni di un testo: ogni
indirizzo IPv4 negli intervalli di documentazione (o una maschera o wildcard),
IPv6 in 2001:db8::/32, MAC in 00:00:5e:00:53:xx, e-mail e nomi di host sotto
example.org, numeri AS in 64496-64511.
"""

import ipaddress
import re

IPV4_DOC = [ipaddress.ip_network(n) for n in
            ("192.0.2.0/24", "198.51.100.0/24", "203.0.113.0/24")]
IPV6_DOC = ipaddress.ip_network("2001:db8::/32")
ASN_MIN, ASN_MAX = 64496, 64511
MAC_PREFIX = "00005e0053"

_IPV4 = re.compile(r"(?<![\d.])(\d{1,3}(?:\.\d{1,3}){3})(?![\d.])")
_IPV6 = re.compile(
    r"(?<![0-9A-Za-z:])((?:[0-9A-Fa-f]{0,4}:){2,7}[0-9A-Fa-f]{0,4})"
    r"(?:/\d{1,3})?(?![0-9A-Za-z:])")
_MAC = re.compile(r"(?<![0-9A-Fa-f:-])((?:[0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2})"
                  r"(?![0-9A-Fa-f:-])")
_MAC_DOTTED = re.compile(r"(?<![0-9A-Fa-f.])([0-9a-f]{4}\.[0-9a-f]{4}\."
                         r"[0-9a-f]{4})(?![0-9A-Fa-f.])")
_EMAIL = re.compile(r"[A-Za-z0-9._%+-]+@([A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+)")
_HOST = re.compile(r"(?<![A-Za-z0-9@.-])((?:[A-Za-z0-9-]+\.)+"
                   r"(?:org|com|net|it|eu|io|info|biz|local|lan|internal)"
                   r")(?![A-Za-z0-9-])")
_ASN = re.compile(r"(?:\bAS\s?|\bremote-as\s+|\bpeer-as\s+|\blocal-as\s+|"
                  r"\bautonomous-system\s+|\brouter bgp\s+|\bas=|"
                  r"\bremote\.as=|\b(?:External|Internal) AS\s+)(\d+)\b")


def _ipv4_ok(text):
    try:
        address = ipaddress.ip_address(text)
    except ValueError:
        return True  # non e' un indirizzo (es. una versione software)
    if any(address in net for net in IPV4_DOC):
        return True
    value = int(address)
    mask_bits = bin(value)[2:].zfill(32)
    if "01" not in mask_bits:  # maschera: uni contigui poi zeri
        return True
    if "10" not in mask_bits:  # wildcard: zeri contigui poi uni
        return True
    return False


def _ipv6_ok(text):
    try:
        address = ipaddress.ip_address(text)
    except ValueError:
        return True  # orari, MAC e simili: non sono indirizzi IPv6
    if address.version != 6:
        return True
    return address == ipaddress.ip_address("::") or address in IPV6_DOC


def _domain_ok(domain):
    domain = domain.lower().rstrip(".")
    return domain == "example.org" or domain.endswith(".example.org")


def controlla_testo(text, label):
    """Elenco di violazioni (stringhe) trovate in `text`."""
    errors = []
    for number, line in enumerate(text.splitlines(), 1):
        where = "%s:%d" % (label, number)
        for found in _IPV4.findall(line):
            if not _ipv4_ok(found):
                errors.append("%s: IPv4 fuori dagli intervalli di "
                              "documentazione: %s" % (where, found))
        for found in _IPV6.findall(line):
            if not _ipv6_ok(found):
                errors.append("%s: IPv6 fuori da 2001:db8::/32: %s"
                              % (where, found))
        for found in _MAC.findall(line):
            digits = re.sub(r"[:-]", "", found).lower()
            if not digits.startswith(MAC_PREFIX):
                errors.append("%s: MAC fuori da 00:00:5e:00:53:xx: %s"
                              % (where, found))
        for found in _MAC_DOTTED.findall(line):
            if not found.replace(".", "").startswith(MAC_PREFIX):
                errors.append("%s: MAC fuori da 00:00:5e:00:53:xx: %s"
                              % (where, found))
        for domain in _EMAIL.findall(line):
            if re.match(r"^[\d.]+$", domain):
                continue  # utente@indirizzo IPv4: lo controlla la regola IPv4
            if not _domain_ok(domain):
                errors.append("%s: e-mail o utenza fuori da example.org: %s"
                              % (where, domain))
        for host in _HOST.findall(line):
            if not _domain_ok(host):
                errors.append("%s: nome di host fuori da example.org: %s"
                              % (where, host))
        for asn in _ASN.findall(line):
            if not ASN_MIN <= int(asn) <= ASN_MAX:
                errors.append("%s: numero AS fuori da 64496-64511: %s"
                              % (where, asn))
    return errors
