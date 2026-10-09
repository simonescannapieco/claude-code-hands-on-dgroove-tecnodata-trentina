"""I clienti della settimana: quelli fissi della storia e quelli generati.

I clienti fissi (CL-000101...106 della storia condivisa tra i tre progetti, e
quelli degli scenari di prova da CL-005000 a CL-005008) vengono da testi.py;
gli altri sono generati da CL-005009 in su, divisi in segmenti che servono ai
guasti della settimana (Pergine in fibra sulle vie della porta guasta, la zona
radio di Cles, le aziende di Rovereto, i centralini in cloud) più un segmento
generale. Come nel gestionale, la fibra arriva in tutti i comuni serviti
tranne Cles, servita via radio.
"""

from typing import Dict, List, NamedTuple, Sequence, Tuple

from . import canone, testi
from .settimana import Caso, mescola

# I codici di questo progetto: clienti CL-005000...CL-005999 e linee
# LN-005000...LN-005999 (i primi nove per gli scenari, gli altri generati);
# gli altri intervalli appartengono al gestionale.
PRIMO_DEL_PROGETTO = 5000
PRIMO_GENERATO = 5009
ULTIMO_DEL_PROGETTO = 5999
# I clienti e le linee della storia, comuni ai tre progetti.
CLIENTI_CONDIVISI = range(101, 107)
LINEE_CONDIVISE = range(201, 207)


class Cliente(NamedTuple):
    """Un cliente (o un potenziale cliente, con id_cliente vuoto)."""
    id_cliente: str
    tipo: str          # privato | azienda | associazione
    nome: str
    genere: str        # f | m per i privati, vuoto per le organizzazioni
    comune: str
    via: str
    civico: str
    id_linea: str
    tecnologia: str    # FTTH | FWA, vuoto per i potenziali clienti
    offerta: str
    voce: str          # vuoto | Linea voce di casa | Centralino Cloud
    interni: int
    hotspot: bool
    telefono: str
    email: str
    referente: str


class Registro:
    """Telefoni ed e-mail già assegnati, perché nessuno si ripeta."""

    def __init__(self, clienti: Sequence[Cliente]) -> None:
        self._telefoni = {c.telefono for c in clienti} | set(
            testi.ALTRI_TELEFONI)
        self._email = {c.email for c in clienti} | set(testi.ALTRE_EMAIL)

    def telefono(self, caso: Caso) -> str:
        while True:
            numero = "+39 00%d %03d %04d" % (caso.intero(1, 9),
                                             caso.intero(0, 999),
                                             caso.intero(0, 9999))
            if numero not in self._telefoni:
                self._telefoni.add(numero)
                return numero

    def email(self, caso: Caso, cliente_nome: str, tipo: str) -> str:
        base = _base_email(caso, cliente_nome, tipo)
        indirizzo, n = base + "@example.org", 2
        while indirizzo in self._email:
            indirizzo, n = "%s%d@example.org" % (base, n), n + 1
        self._email.add(indirizzo)
        return indirizzo


def clienti_fissi() -> List[Cliente]:
    return [Cliente(**d) for d in testi.CLIENTI_FISSI]


def _ascii(testo: str) -> str:
    sostituzioni = str.maketrans("àèéìòùÀÈÉÌÒÙ", "aeeiouAEEIOU", "'’")
    return testo.translate(sostituzioni)


def _base_email(caso: Caso, nome: str, tipo: str) -> str:
    if tipo == "privato":
        parti = _ascii(nome).lower().split()
        proprio, cognome = parti[0], parti[-1]
        stile = caso.intero(0, 3)
        return ("%s.%s" % (proprio, cognome), "%s.%s" % (proprio[0], cognome),
                proprio + cognome, "%s.%s" % (cognome, proprio))[stile]
    parole = [p for p in _ascii(nome).lower().replace(".", " ").split()
              if p not in ("srl", "snc", "sas", "s", "r", "l", "n", "c", "a")]
    if "di" in parole:
        parole = parole[:parole.index("di")]
    return caso.scegli(("", "info.", "amministrazione.", "ufficio.")) + \
        ".".join(parole)


def nome_persona(caso: Caso) -> Tuple[str, str]:
    """Nome e genere di una persona inventata, mai una della storia."""
    while True:
        genere = "f" if caso.probabile(0.5) else "m"
        nomi = testi.NOMI_F if genere == "f" else testi.NOMI_M
        nome = "%s %s" % (caso.scegli(nomi), caso.scegli(canone.COGNOMI))
        if nome not in testi.NOMI_RISERVATI:
            return nome, genere


def nome_organizzazione(caso: Caso, tipo: str) -> Tuple[str, bool]:
    """Un nome di azienda o associazione e se è un'attività di ospitalità."""
    if tipo == "associazione":
        genere_tipo = caso.scegli(testi.TIPI_ASSOCIAZIONE)
        return "%s %s" % (genere_tipo[0], _parola(caso, genere_tipo[1])), False
    nome = testi.AZIENDE_RISERVATE[0]
    while nome in testi.AZIENDE_RISERVATE:
        tipo_nome, genere = caso.scegli(testi.TIPI_AZIENDA)
        nome = "%s %s" % (tipo_nome, _parola(caso, genere))
    forma = caso.pesato((("S.r.l.", 3), ("S.n.c.", 3), ("S.a.s.", 2),
                         ("", 3), ("ditta", 2)))
    if forma == "ditta":
        nome += " di " + nome_persona(caso)[0]
    elif forma:
        nome += " " + forma
    return nome, tipo_nome in testi.OSPITALITA


def _parola(caso: Caso, genere: str) -> str:
    if caso.probabile(0.25):
        return caso.scegli(testi.NOMI_INVARIATI)
    maschile, femminile = caso.scegli(testi.AGGETTIVI)
    return femminile if genere == "f" else maschile


def crea_cliente(caso: Caso, registro: Registro, numero: int, tipo: str,
                 comune: str, vie: Sequence[str]) -> Cliente:
    """Un cliente generato; la tecnologia viene dal comune (radio a Cles)."""
    tecnologia = "FWA" if comune == testi.COMUNE_RADIO else "FTTH"
    if tipo == "privato":
        nome, genere = nome_persona(caso)
        referente, hotspot = "", False
        voce = "Linea voce di casa" if caso.probabile(
            0.3 if tecnologia == "FTTH" else 0.15) else ""
        offerta = ("Casa Fibra 2,5 Giga" if caso.probabile(0.3)
                   else "Casa Fibra 1 Giga") if tecnologia == "FTTH" \
            else "Casa Radio"
    else:
        (nome, ospitalita), genere = nome_organizzazione(caso, tipo), ""
        referente = nome_persona(caso)[0]
        hotspot = ospitalita and caso.probabile(0.6)
        voce = "Centralino Cloud" if caso.probabile(0.35) else ""
        offerta = ("Business Fibra 2,5 Giga" if caso.probabile(0.4)
                   else "Business Fibra 1 Giga") if tecnologia == "FTTH" \
            else "Business Radio"
    interni = caso.intero(3, 16) if voce == "Centralino Cloud" else 0
    return Cliente("CL-%06d" % numero, tipo, nome, genere, comune,
                   caso.scegli(vie), str(caso.intero(1, 80)),
                   "LN-%06d" % numero, tecnologia, offerta, voce, interni,
                   hotspot, registro.telefono(caso),
                   registro.email(caso, nome, tipo), referente)


def ripartisci(quanti: int, pesi: Sequence[Tuple[str, int]]) -> List[str]:
    """`quanti` voci divise secondo i pesi (resti più grandi, solo interi)."""
    totale = sum(p for _, p in pesi)
    quote = [(voce, quanti * p // totale, quanti * p % totale)
             for voce, p in pesi]
    mancanti = quanti - sum(q for _, q, _ in quote)
    per_resto = sorted(range(len(quote)), key=lambda i: (-quote[i][2], i))
    extra = set(per_resto[:mancanti])
    return [voce for i, (voce, q, _) in enumerate(quote)
            for _ in range(q + (1 if i in extra else 0))]


def popola(caso: Caso, registro: Registro) -> Dict[str, List[Cliente]]:
    """I segmenti di clienti generati, numerati da CL-005009 in su."""
    generale = mescola(caso, ripartisci(180, testi.COMUNI))
    piano = (  # segmento, quanti, tipo (None = misto), comuni (None = pesato)
        ("pergine", 36, "privato", ["Pergine Valsugana"] * 36),
        ("pergine", 8, "azienda", ["Pergine Valsugana"] * 8),
        ("cles", 20, "privato", [testi.COMUNE_RADIO] * 20),
        ("cles", 8, "azienda", [testi.COMUNE_RADIO] * 8),
        ("rovereto_dhcp", 10, "azienda", ["Rovereto"] * 10),
        ("centralino", 18, "azienda", None),
        ("generale", 180, None, generale),
    )
    segmenti: Dict[str, List[Cliente]] = {}
    numero = PRIMO_GENERATO
    for nome_segmento, quanti, tipo, comuni in piano:
        vie = testi.VIE_PORTA_PERGINE if nome_segmento == "pergine" \
            else testi.VIE
        for indice in range(quanti):
            tipo_c = tipo or caso.pesato((("privato", 70), ("azienda", 26),
                                          ("associazione", 4)))
            comune = comuni[indice] if comuni else caso.pesato(testi.COMUNI)
            cliente = crea_cliente(caso, registro, numero, tipo_c, comune, vie)
            if nome_segmento == "centralino":
                cliente = cliente._replace(voce="Centralino Cloud",
                                           interni=caso.intero(3, 16))
            segmenti.setdefault(nome_segmento, []).append(cliente)
            numero += 1
    return segmenti


def nuovo_potenziale(caso: Caso, registro: Registro) -> Cliente:
    """Un potenziale cliente (anche di un comune non servito): senza codici."""
    tipo = caso.pesato((("privato", 80), ("azienda", 15),
                        ("associazione", 5)))
    if tipo == "privato":
        nome, genere = nome_persona(caso)
        referente = ""
    else:
        nome, genere = nome_organizzazione(caso, tipo)[0], ""
        referente = nome_persona(caso)[0]
    comune = caso.scegli(testi.COMUNI_NON_SERVITI) if caso.probabile(0.3) \
        else caso.pesato(testi.COMUNI)
    return Cliente("", tipo, nome, genere, comune, caso.scegli(testi.VIE),
                   str(caso.intero(1, 80)), "", "", "", "", 0, False,
                   registro.telefono(caso), registro.email(caso, nome, tipo),
                   referente)
