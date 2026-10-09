"""Il canone dei dati sintetici (progetti/README.md) come controllo eseguibile.

genera.py usa questo modulo in due modi: sull'output che genera, prima di
scriverlo, e con `--canone` su tutti i file di testo della cartella. Le funzioni
non leggono file e non stampano: restituiscono elenchi di violazioni, e decide
chi le chiama.

Regole controllate (tra parentesi la riga del canone):
- e-mail solo `@example.org`; l'utenza PPPoE `ln<6 cifre>@ciaspolink.example.org`
  (e-mail, utenze PPPoE)
- nomi di host e indirizzi web solo sotto example.org (nomi di host)
- telefoni solo nella forma `+39 00x xxx xxxx`, nessun numero italiano
  componibile (telefoni)
- IPv4 solo negli intervalli dell'RFC 5737, maschere e wildcard a parte (IPv4)
- IPv6 solo in 2001:db8::/32 (IPv6); MAC solo 00:00:5e:00:53:xx (MAC);
  numeri AS solo 64496-64511 (numeri AS)
- partite IVA con la cifra di controllo sbagliata; mai un codice fiscale
  (partite IVA)
- date solo nella settimana sintetica 2026-09-07 ... 2026-09-13, con il giorno
  della settimana giusto (date e ore)
- identificativi nei formati del canone (identificativi)
- persone: nome di battesimo + cognome della lista fissa; aziende con una
  parola della lista (persone, aziende clienti)
"""

import re
from typing import List, NamedTuple, Optional, Tuple

COGNOMI = ("Esempio", "Prova", "Fittizio", "Campione", "Modello", "Bozza",
           "Simulato", "Inventato", "Ipotetico", "Immaginario", "Provvisorio",
           "Fantasia")

# Le forme che un nome di azienda può usare: gli aggettivi si accordano
# (Falegnameria Fittizia), i nomi restano invariati (Rifugio Campione).
_FORME_AZIENDE = (
    ("Esempio",), ("Prova",), ("Campione",), ("Modello",), ("Bozza",),
    ("Fantasia",),
    ("Fittizio", "Fittizia", "Fittizi", "Fittizie"),
    ("Simulato", "Simulata", "Simulati", "Simulate"),
    ("Inventato", "Inventata", "Inventati", "Inventate"),
    ("Ipotetico", "Ipotetica", "Ipotetici", "Ipotetiche"),
    ("Immaginario", "Immaginaria", "Immaginari", "Immaginarie"),
    ("Provvisorio", "Provvisoria", "Provvisori", "Provvisorie"),
)
_PAROLE_AZIENDE = frozenset(f.lower() for forme in _FORME_AZIENDE
                            for f in forme)
_COGNOMI_MINUSCOLI = frozenset(c.lower() for c in COGNOMI)

DOMINIO_EMAIL = "example.org"
DOMINIO_PPPOE = "ciaspolink.example.org"
GIORNI_SETTIMANA = {7: "lunedì", 8: "martedì", 9: "mercoledì", 10: "giovedì",
                    11: "venerdì", 12: "sabato", 13: "domenica"}
DATE_AMMESSE = tuple("2026-09-%02d" % g for g in sorted(GIORNI_SETTIMANA))
FORMATI_ID = {
    "CL": re.compile(r"CL-\d{6}"),
    "LN": re.compile(r"LN-\d{6}"),
    "AT": re.compile(r"AT-2026-\d{4}"),
    "TK": re.compile(r"TK-2026-\d{5}"),
    "FT": re.compile(r"FT-2026-\d{6}"),
    "RV": re.compile(r"RV-\d{3}"),
}
_PREFISSI_RFC5737 = ((192, 0, 2), (198, 51, 100), (203, 0, 113))
_MESI = ("gennaio", "febbraio", "marzo", "aprile", "maggio", "giugno",
         "luglio", "agosto", "settembre", "ottobre", "novembre", "dicembre")

_RE_EMAIL = re.compile(r"([A-Za-z0-9._%+-]+)@([A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+)")
_RE_URL = re.compile(r"\bhttps?://([A-Za-z0-9.-]+)", re.IGNORECASE)
_RE_DOMINIO = re.compile(
    r"(?<![@\w.-])((?:[A-Za-z0-9-]+\.)+"
    r"(?:it|com|net|org|eu|info|io|biz|cloud|app|dev))\b", re.IGNORECASE)
_RE_TEL_CON_PIU = re.compile(r"(?<![\w+])\+\d[\d ]{5,}\d")
_RE_TEL_CANONICO = re.compile(r"\+39 00\d \d{3} \d{4}")
_RE_TEL_0039 = re.compile(r"(?<!\d)0039 ?\d")
_RE_TEL_NUDO = re.compile(
    r"(?<![\w+\-/.])(?:0\d{1,3}|3\d{2})(?:[ .]?\d){6,8}(?![\w\-/:])")
_RE_IPV4 = re.compile(r"(?<![\d.])(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})"
                      r"(?!\.?\d)")
_RE_ESA_DUEPUNTI = re.compile(
    r"(?<![0-9A-Fa-f:])[0-9A-Fa-f]{0,4}(?::[0-9A-Fa-f]{0,4}){2,7}"
    r"(?![0-9A-Fa-f:])")
_RE_MAC_TRATTINI = re.compile(r"\b[0-9A-Fa-f]{2}(?:-[0-9A-Fa-f]{2}){5}\b")
_RE_AS = re.compile(r"\bAS ?(\d{1,10})\b")
_RE_UNDICI_CIFRE = re.compile(r"(?<!\d)\d{11}(?!\d)")
_RE_CODICE_FISCALE = re.compile(
    r"\b[A-Za-z]{6}\d{2}[A-Za-z]\d{2}[A-Za-z]\d{3}[A-Za-z]\b")
_RE_DATA_ISO = re.compile(r"(?<!\d)(\d{4})-(\d{2})-(\d{2})(?!\d)")
_RE_DATA_TESTO = re.compile(
    r"\b(\d{1,2})°?\s+(" + "|".join(_MESI) + r")\b(?:\s+(\d{4}))?",
    re.IGNORECASE)
_RE_DATA_BARRE = re.compile(r"(?<![\d/])(\d{1,2})/(\d{1,2})/(\d{2}|\d{4})"
                            r"(?![\d/])")
_RE_GIORNO_DATA = re.compile(
    r"\b(lunedì|martedì|mercoledì|giovedì|venerdì|sabato|domenica)\s+"
    r"(\d{1,2})\s+settembre\b", re.IGNORECASE)
_RE_ID = re.compile(r"\b(CL|LN|AT|TK|FT|RV)-[0-9][0-9-]*")


class Violazione(NamedTuple):
    """Una violazione del canone: riga (1 = prima), regola, valore trovato."""
    riga: int
    regola: str
    valore: str


def host_ammesso(host: str) -> bool:
    """Vero se il nome di host è example.org o sta sotto example.org."""
    h = host.lower().rstrip(".")
    return h == DOMINIO_EMAIL or h.endswith("." + DOMINIO_EMAIL)


def email_ammessa(indirizzo: str) -> bool:
    """Vero per un'e-mail @example.org o per un'utenza PPPoE del canone."""
    trovato = _RE_EMAIL.fullmatch(indirizzo)
    if trovato is None:
        return False
    locale, dominio = trovato.group(1), trovato.group(2).lower()
    if dominio == DOMINIO_EMAIL:
        return True
    return dominio == DOMINIO_PPPOE and re.fullmatch(r"ln\d{6}", locale) \
        is not None


def telefono_ammesso(numero: str) -> bool:
    """Vero se il numero è nella forma del canone: +39 00x xxx xxxx."""
    return _RE_TEL_CANONICO.fullmatch(numero) is not None


def data_ammessa(iso: str) -> bool:
    """Vero se la data AAAA-MM-GG cade nella settimana sintetica."""
    return iso in DATE_AMMESSE


def id_ammesso(valore: str) -> bool:
    """Vero se l'identificativo rispetta il formato del suo prefisso."""
    formato = FORMATI_ID.get(valore[:2])
    return formato is not None and formato.fullmatch(valore) is not None


def controlla_persona(nome: str, nomi_ammessi: Optional[frozenset] = None
                      ) -> Optional[str]:
    """Controlla il nome di una persona; restituisce il problema o None.

    Il cognome deve stare nella lista fissa; se `nomi_ammessi` è dato (nomi
    di battesimo in minuscolo), anche il nome deve starci.
    """
    parti = nome.split()
    if len(parti) < 2:
        return "nome di persona senza cognome"
    if parti[-1].lower() not in _COGNOMI_MINUSCOLI:
        return "cognome fuori dalla lista fissa"
    if nomi_ammessi is not None and parti[0].lower() not in nomi_ammessi:
        return "nome di battesimo fuori dall'elenco del generatore"
    return None


def controlla_azienda(nome: str) -> Optional[str]:
    """Un nome di azienda o associazione deve contenere una parola della lista."""
    parole = re.findall(r"[A-Za-zÀ-ÿ]+", nome)
    if any(p.lower() in _PAROLE_AZIENDE for p in parole):
        return None
    return "nome di azienda senza una parola della lista fissa"


def _piva_corretta(cifre: str) -> bool:
    """Vero se le 11 cifre hanno la cifra di controllo giusta (algoritmo P.IVA)."""
    somma = 0
    for posizione, carattere in enumerate(cifre[:10]):
        valore = int(carattere)
        if posizione % 2 == 1:
            valore *= 2
            if valore > 9:
                valore -= 9
        somma += valore
    return (10 - somma % 10) % 10 == int(cifre[10])


def _bit(ottetti: Tuple[int, ...]) -> str:
    return "".join(format(o, "08b") for o in ottetti)


def _ipv4_ammesso(ottetti: Tuple[int, ...]) -> bool:
    if ottetti[:3] in _PREFISSI_RFC5737:
        return True
    bit = _bit(ottetti)
    return "01" not in bit or "10" not in bit  # maschera o wildcard


def _email_e_host(riga: str) -> List[Tuple[str, str]]:
    trovate = []
    for m in _RE_EMAIL.finditer(riga):
        if not email_ammessa(m.group(0)):
            trovate.append(("e-mail fuori da example.org", m.group(0)))
    for m in _RE_URL.finditer(riga):
        if not host_ammesso(m.group(1)):
            trovate.append(("host fuori da example.org", m.group(1)))
    senza_email = _RE_EMAIL.sub(" ", riga)
    for m in _RE_DOMINIO.finditer(senza_email):
        if not host_ammesso(m.group(1)):
            trovate.append(("host fuori da example.org", m.group(1)))
    return trovate


def _indirizzi(riga: str) -> List[Tuple[str, str]]:
    trovate = []
    for m in _RE_IPV4.finditer(riga):
        ottetti = tuple(int(g) for g in m.groups())
        if max(ottetti) <= 255 and not _ipv4_ammesso(ottetti):
            trovate.append(("IPv4 fuori dall'RFC 5737", m.group(0)))
    for m in _RE_ESA_DUEPUNTI.finditer(riga):
        trovate.extend(_classifica_esadecimale(m.group(0)))
    for m in _RE_MAC_TRATTINI.finditer(riga):
        if not m.group(0).lower().startswith("00-00-5e-00-53-"):
            trovate.append(("MAC fuori dall'RFC 7042", m.group(0)))
    for m in _RE_AS.finditer(riga):
        if not 64496 <= int(m.group(1)) <= 64511:
            trovate.append(("numero AS fuori dall'RFC 5398", m.group(0)))
    return trovate


def _classifica_esadecimale(testo: str) -> List[Tuple[str, str]]:
    gruppi = testo.split(":")
    if len(gruppi) == 6 and all(len(g) == 2 for g in gruppi):
        if testo.lower().startswith("00:00:5e:00:53:"):
            return []
        return [("MAC fuori dall'RFC 7042", testo)]
    if "::" not in testo and len(gruppi) <= 3 and \
            all(g.isdigit() and len(g) <= 2 for g in gruppi):
        return []  # un orario, non un indirizzo
    if "::" in testo or len(gruppi) >= 4:
        if not testo.lower().startswith("2001:db8:"):
            return [("IPv6 fuori da 2001:db8::/32", testo)]
    return []


def _telefoni_e_numeri(riga: str) -> List[Tuple[str, str]]:
    trovate = []
    for m in _RE_TEL_CON_PIU.finditer(riga):
        if not telefono_ammesso(m.group(0)):
            trovate.append(("telefono fuori dalla forma +39 00x xxx xxxx",
                            m.group(0)))
    for m in _RE_TEL_0039.finditer(riga):
        trovate.append(("telefono con prefisso 0039", m.group(0)))
    pulita = _RE_UNDICI_CIFRE.sub(" ", _RE_TEL_CANONICO.sub(" ", riga))
    for m in _RE_TEL_NUDO.finditer(pulita):
        trovate.append(("numero di telefono italiano componibile", m.group(0)))
    for m in _RE_UNDICI_CIFRE.finditer(riga):
        contesto = riga[max(0, m.start() - 24):m.start()].upper()
        if "IVA" not in contesto:
            trovate.append(("numero di 11 cifre che non è una partita IVA",
                            m.group(0)))
        elif _piva_corretta(m.group(0)):
            trovate.append(("partita IVA con cifra di controllo giusta",
                            m.group(0)))
    for m in _RE_CODICE_FISCALE.finditer(riga):
        trovate.append(("codice fiscale", m.group(0)))
    return trovate


def _date(riga: str) -> List[Tuple[str, str]]:
    trovate = []
    for m in _RE_DATA_ISO.finditer(riga):
        if not data_ammessa(m.group(0)):
            trovate.append(("data fuori dalla settimana sintetica", m.group(0)))
    for m in _RE_DATA_TESTO.finditer(riga):
        giorno, mese, anno = int(m.group(1)), m.group(2).lower(), m.group(3)
        if mese != "settembre" or giorno not in GIORNI_SETTIMANA or \
                anno not in (None, "2026"):
            trovate.append(("data fuori dalla settimana sintetica", m.group(0)))
    for m in _RE_DATA_BARRE.finditer(riga):
        giorno, mese, anno = (int(m.group(1)), int(m.group(2)), m.group(3))
        if mese != 9 or giorno not in GIORNI_SETTIMANA or \
                anno not in ("26", "2026"):
            trovate.append(("data fuori dalla settimana sintetica", m.group(0)))
    for m in _RE_GIORNO_DATA.finditer(riga):
        nome, giorno = m.group(1).lower(), int(m.group(2))
        if GIORNI_SETTIMANA.get(giorno) != nome:
            trovate.append(("giorno della settimana sbagliato", m.group(0)))
    return trovate


def _identificativi(riga: str) -> List[Tuple[str, str]]:
    trovate = []
    for m in _RE_ID.finditer(riga):
        valore = m.group(0).rstrip("-")
        if not id_ammesso(valore):
            trovate.append(("identificativo fuori formato", valore))
    return trovate


def controlla_riga(riga: str) -> List[Tuple[str, str]]:
    """Tutte le regole di testo su una riga: coppie (regola, valore)."""
    return (_email_e_host(riga) + _indirizzi(riga) + _telefoni_e_numeri(riga)
            + _date(riga) + _identificativi(riga))


def controlla_testo(testo: str) -> List[Violazione]:
    """Applica le regole di testo a ogni riga di un file."""
    violazioni = []
    for numero, riga in enumerate(testo.split("\n"), start=1):
        for regola, valore in controlla_riga(riga):
            violazioni.append(Violazione(numero, regola, valore))
    return violazioni
