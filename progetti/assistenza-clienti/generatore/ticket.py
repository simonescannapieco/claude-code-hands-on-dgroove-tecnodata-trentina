"""I ticket della settimana: testi, tempi, stati e i cinque guasti.

Tre famiglie di ticket, poi ordinate per apertura: quelli fissi della storia e
degli scenari (testi.TICKET_FISSI), quelli dei guasti della settimana e quelli
«di fondo» di ogni giorno. I guasti, in ora italiana, con gli stessi orari del
gestionale (progetti/gestionale-php):
- martedì 10:12-11:40, fibra tagliata da lavori stradali sulla porta PON 0/1/3
  di olt-pergine-01, circa 40 linee;
- mercoledì 07:52-16:50, perdite a intermittenza sul ponte radio ptp-cles-01,
  fino al riallineamento dell'antenna;
- giovedì 02:00-02:30, manutenzione programmata di bng-trento-01, annunciata
  la settimana prima: al mattino qualche router non si è ricollegato;
- venerdì 08:04-10:40, registrazioni SIP fallite su sbc-trento-01 per i
  clienti del Centralino Cloud;
- sabato, dalle 9 circa alle 10:55, indirizzi DHCP esauriti sulla VLAN
  business di Rovereto.
"""

import datetime as dt
from typing import Dict, List, NamedTuple, Optional, Sequence, Tuple

from . import canone, testi
from .clienti import (Cliente, Registro, clienti_fissi, nuovo_potenziale,
                      popola)
from .settimana import (FINE_SETTIMANA, ORARIO_TEAM, Caso, allinea, in_orario,
                        istante, mescola, minuti_tra, nell_intervallo)

# Ticket «di fondo» per giorno, da lunedì a domenica (i guasti si aggiungono).
BASE_GIORNO = (54, 46, 44, 42, 40, 16, 9)
# Pesi delle ore di apertura (0-23): giorni feriali, sabato, domenica.
_ORE_FERIALI = (1, 1, 1, 0, 0, 1, 2, 4, 9, 11, 11, 10, 7, 6, 9, 10, 9, 8, 7,
                5, 4, 3, 2, 1)
_ORE_SABATO = (1, 1, 0, 0, 0, 0, 1, 2, 5, 7, 7, 6, 4, 2, 2, 2, 2, 2, 2, 2, 2,
               2, 1, 1)
_ORE_DOMENICA = (1, 0, 0, 0, 0, 0, 0, 1, 1, 2, 3, 3, 2, 2, 2, 3, 3, 3, 3, 3,
                 3, 2, 2, 1)
ORE_PER_GIORNO = (_ORE_FERIALI,) * 5 + (_ORE_SABATO, _ORE_DOMENICA)


class Ticket(NamedTuple):
    """Un ticket prima della numerazione; i tempi sono datetime con fuso."""
    aperto: dt.datetime
    ordine: int
    canale: str
    cliente: Cliente
    tecnologia: str
    categoria: str
    priorita: str
    stato: str
    chiuso: Optional[dt.datetime]
    oggetto: str
    descrizione: str
    team: str
    prima_risposta: Optional[int]
    soddisfazione: Optional[int]
    telefono: str
    email: str
    comune: str
    nome: str


# --- Testi --------------------------------------------------------------------

def utilizzabile(etichetta: str, testo: str, cliente: Cliente) -> bool:
    """Vero se un modello di testo si adatta al cliente."""
    privato = cliente.tipo == "privato"
    regole = {
        "": True, "P": privato, "A": not privato,
        "ASS": cliente.tipo == "associazione",
        "FTTH": cliente.tecnologia == "FTTH",
        "FWA": cliente.tecnologia == "FWA", "VOCE": cliente.voce != "",
        "VOCE_P": privato and cliente.voce != "",
        "VOCE_A": cliente.voce == "Centralino Cloud",
        "HOT": cliente.hotspot, "25": "2,5" in cliente.offerta,
        "P_F": privato and cliente.genere == "f",
        "P_M": privato and cliente.genere == "m",
    }
    if not all(regole[e] for e in etichetta.split("+")):
        return False
    if "{email}" in testo and not cliente.email:
        return False
    if "{referente}" in testo and not cliente.referente:
        return False
    senza_id = ("{id_cliente}", "{id_linea}", "{pppoe}")
    return bool(cliente.id_cliente) or not any(s in testo for s in senza_id)


def scegli_testo(caso: Caso, modelli: Sequence[Tuple[str, str]],
                 cliente: Cliente) -> str:
    adatti = [t for t, e in modelli if utilizzabile(e, t, cliente)]
    return caso.scegli(adatti)


def quando(caso: Caso, t: dt.datetime) -> str:
    if t.hour < 6:
        return caso.scegli(("questa notte", "ieri sera", "circa un'ora"))
    if t.hour < 12:
        return caso.scegli(("stamattina", "questa notte", "ieri sera",
                            "circa un'ora", "un paio d'ore"))
    return caso.scegli(("stamattina", "oggi pomeriggio", "circa un'ora",
                        "un paio d'ore", "ieri"))


def segnaposto(caso: Caso, cliente: Cliente, t: dt.datetime) -> Dict[str, str]:
    """I valori dei segnaposto dei modelli di testo, per questo cliente."""
    privato = cliente.tipo == "privato"
    cognome = cliente.nome.split()[-1] if privato else \
        caso.scegli(canone.COGNOMI)
    altro_comune = caso.pesato(tuple((c, p) for c, p in testi.COMUNI
                                     if c != cliente.comune))
    return {
        "quando": quando(caso, t), "comune": cliente.comune,
        "via": cliente.via, "civico": cliente.civico,
        "comune_nuovo": altro_comune, "via_nuova": caso.scegli(testi.VIE),
        "civico_nuovo": str(caso.intero(1, 60)),
        "telefono": cliente.telefono, "email": cliente.email,
        "id_cliente": cliente.id_cliente, "id_linea": cliente.id_linea,
        "pppoe": "%s@%s" % (cliente.id_linea.replace("-", "").lower(),
                            canone.DOMINIO_PPPOE),
        "offerta": cliente.offerta,
        "mbps": str(caso.intero(3, 25) if cliente.tecnologia == "FWA"
                    else caso.intero(40, 380)),
        "fattura": "FT-2026-%06d" % caso.intero(1700, 2300),
        "importo": "%d,%02d" % (caso.intero(3, 60),
                                caso.scegli((0, 40, 50, 90))),
        "attivazione": "AT-2026-%04d" % caso.intero(700, 950),
        "interni": str(cliente.interni),
        "ip": ("203.0.113.%d" if privato else "198.51.100.%d")
        % caso.intero(2, 254),
        "mac": "00:00:5e:00:53:%02x" % caso.intero(0, 255),
        "nome": cliente.nome, "referente": cliente.referente,
        "intestatario": "intestataria" if cliente.genere == "f"
        else "intestatario",
        "figlio": "%s %s" % (caso.scegli(testi.NOMI_M), cognome),
        "moglie": "%s %s" % (caso.scegli(testi.NOMI_F), cognome),
        "marito": "%s %s" % (caso.scegli(testi.NOMI_M), cognome),
    }


def _minuscola(testo: str) -> str:
    return testo[:1].lower() + testo[1:]


def saluto(caso: Caso, t: dt.datetime, cliente: Cliente) -> str:
    if cliente.tipo != "privato" and caso.probabile(0.3):
        return "Spett.le CiaspoLink,"
    if t.hour < 13:
        return "Buongiorno,"
    if t.hour < 18:
        return caso.scegli(("Buongiorno,", "Salve,"))
    return "Buonasera,"


def congedo(caso: Caso, cliente: Cliente, firma: bool) -> str:
    if firma:
        chi = cliente.nome if cliente.tipo == "privato" else \
            "%s, %s" % (cliente.referente, cliente.nome)
        return "Cordiali saluti, %s" % chi
    return caso.scegli(testi.CHIUSURE)


def dettagli(caso: Caso, cliente: Cliente, valori: Dict[str, str],
             quanti: int) -> List[str]:
    adatti = [t for t, e in testi.DETTAGLI if utilizzabile(e, t, cliente)]
    return [caso.scegli(adatti).format(**valori) for _ in range(quanti)]


def componi(caso: Caso, corpo: str, cliente: Cliente, canale: str,
            t: dt.datetime, valori: Dict[str, str]) -> str:
    """Il testo di un cliente, con i contorni tipici del canale."""
    parti: List[str] = []
    if canale == "e-mail":
        if caso.probabile(0.85):
            parti += [saluto(caso, t, cliente), _minuscola(corpo)]
        else:
            parti.append(corpo)
        if caso.probabile(0.55):
            parti += dettagli(caso, cliente, valori,
                              2 if caso.probabile(0.3) else 1)
        if caso.probabile(0.8):
            parti.append(congedo(caso, cliente, caso.probabile(0.6)))
    elif canale == "portale":
        parti.append(corpo)
        if caso.probabile(0.35):
            parti += dettagli(caso, cliente, valori, 1)
        if caso.probabile(0.3):
            parti.append(congedo(caso, cliente, False))
    else:
        if caso.probabile(0.3):
            parti += [caso.scegli(("Ciao,", "Buongiorno,", "Salve,")),
                      _minuscola(corpo)]
        else:
            parti.append(corpo)
        if caso.probabile(0.3):
            parti += dettagli(caso, cliente, valori, 1)
        messaggio = " ".join(parti).replace("«", "“").replace("»", "”")
        return "Messaggio in chat: «%s»" % messaggio
    return " ".join(parti)


def descrivi(caso: Caso, cliente: Cliente, canale: str, t: dt.datetime,
             del_cliente: Sequence[Tuple[str, str]],
             nota: Sequence[Tuple[str, str]]) -> str:
    """Il testo del ticket: nota dell'operatore, riepilogo o messaggio."""
    valori = segnaposto(caso, cliente, t)
    if canale == "telefono" or (canale == "chat" and caso.probabile(0.5)):
        testo = scegli_testo(caso, nota, cliente).format(**valori)
        if canale == "chat":
            return "Riepilogo dell'assistente virtuale: " + _minuscola(testo)
        if caso.probabile(0.3):
            testo += " Richiamare al %s." % cliente.telefono
        return testo
    corpo = scegli_testo(caso, del_cliente, cliente).format(**valori)
    return componi(caso, corpo, cliente, canale, t, valori)


# --- Tempi, stati, recapiti ---------------------------------------------------

def canale_per(caso: Caso, t: dt.datetime) -> str:
    if in_orario(t, "operatori"):
        return caso.pesato((("telefono", 45), ("chat", 25), ("e-mail", 18),
                            ("portale", 12)))
    return caso.pesato((("chat", 45), ("e-mail", 30), ("portale", 25)))


def prima_risposta(caso: Caso, aperto: dt.datetime, canale: str, team: str,
                   carico: int) -> Optional[int]:
    """Minuti fino alla prima risposta di una persona (None se nessuna)."""
    if team == "assistente_virtuale":
        return None
    if canale == "telefono":
        return caso.intero(0, 2)
    minimo, massimo = {"chat": (2, 20), "e-mail": (20, 240),
                       "portale": (15, 180)}[canale]
    u = caso.unif()
    ritardo = (minimo + int((massimo - minimo) * u * u)) * carico
    t = allinea(caso, aperto + dt.timedelta(minutes=ritardo), "operatori")
    return minuti_tra(aperto, t) if t <= FINE_SETTIMANA else None


def chiusura(caso: Caso, aperto: dt.datetime, categoria: str,
             team: str) -> Optional[dt.datetime]:
    """Quando un ticket si chiude (None se resta aperto a fine settimana)."""
    if team == "assistente_virtuale":
        minimo, massimo = 3, 25
    elif team == "tecnici_campo":
        minimo, massimo = 600, 4320
    else:
        minimo, massimo = testi.DURATE[categoria]
    u = caso.unif()
    t = aperto + dt.timedelta(minutes=minimo + int((massimo - minimo) * u * u))
    if team in ORARIO_TEAM:
        t = allinea(caso, t, ORARIO_TEAM[team])
    return t if t <= FINE_SETTIMANA else None


def soddisfazione(caso: Caso, stato: str, categoria: str, minuti: int,
                  malus: int) -> Optional[int]:
    if stato != "chiuso" or not caso.probabile(0.42):
        return None
    voto = testi.VOTO_BASE[categoria] - malus - (1 if minuti > 2880 else 0)
    voto += caso.pesato(((-1, 2), (0, 4), (1, 3)))
    return max(1, min(5, voto))


def tecnologia_di(cliente: Cliente, categoria: str) -> str:
    if categoria == "telefonia_voip":
        return "VoIP"
    if categoria == "hotspot" or not cliente.tecnologia:
        return "altro"
    return cliente.tecnologia


def priorita_per(caso: Caso, categoria: str, cliente: Cliente) -> str:
    privato, azienda = testi.PRIORITA[categoria]
    base = privato if cliente.tipo == "privato" else azienda
    if caso.probabile(0.08):
        livelli = ("bassa", "media", "alta", "urgente")
        return livelli[min(3, livelli.index(base) + 1)]
    return base


def recapiti(caso: Caso, cliente: Cliente, canale: str) -> Tuple[str, str]:
    """Telefono ed e-mail come li registra il ticket, secondo il canale."""
    quote = {"telefono": (1.0, 0.55), "e-mail": (0.5, 1.0),
             "chat": (0.6, 0.75), "portale": (1.0, 1.0)}[canale]
    telefono = cliente.telefono if caso.probabile(quote[0]) else ""
    email = cliente.email if caso.probabile(quote[1]) else ""
    return telefono, email


def comune_registrato(caso: Caso, cliente: Cliente) -> str:
    varianti = testi.VARIANTI_COMUNE.get(cliente.comune)
    if varianti and caso.probabile(0.05):
        return caso.scegli(varianti)
    return cliente.comune


def nome_registrato(caso: Caso, cliente: Cliente, canale: str) -> str:
    if canale != "telefono" and caso.probabile(0.02):
        return cliente.nome.upper()
    return cliente.nome


def assembla(caso: Caso, aperto: dt.datetime, canale: str, cliente: Cliente,
             categoria: str, team: str, chiuso: Optional[dt.datetime],
             testo: str, oggetto: str, carico: int = 1, malus: int = 0,
             priorita: str = "", annullato: bool = False) -> Ticket:
    """Completa un ticket: risposta, stato, voto, recapiti registrati."""
    prima = prima_risposta(caso, aperto, canale, team, carico)
    minuti = minuti_tra(aperto, chiuso) if chiuso else 0
    if chiuso is not None:
        stato = "annullato" if annullato else "chiuso"
        if team != "assistente_virtuale":
            prima = minuti if prima is None else min(prima, minuti)
    elif prima is None:
        stato = "aperto"
    else:
        stato = caso.pesato((("in_lavorazione", 3), ("in_attesa_cliente", 1)))
    voto = soddisfazione(caso, stato, categoria, minuti, malus)
    telefono, email = recapiti(caso, cliente, canale)
    return Ticket(aperto, 0, canale, cliente, tecnologia_di(cliente, categoria),
                  categoria, priorita or priorita_per(caso, categoria, cliente),
                  stato, chiuso, oggetto, testo, team, prima, voto, telefono,
                  email, comune_registrato(caso, cliente),
                  nome_registrato(caso, cliente, canale))


# --- Ticket di fondo e ticket dei guasti --------------------------------------

def adatto(categoria: str, cliente: Cliente) -> bool:
    if categoria == "hotspot":
        return cliente.hotspot
    if categoria == "rete_aziendale":
        return cliente.tipo != "privato"
    if categoria == "telefonia_voip":
        return cliente.voce != ""
    return True


def ticket_di_fondo(caso: Caso, registro: Registro, giorno: int,
                    clienti: Sequence[Cliente]) -> Ticket:
    """Un ticket ordinario del giorno: ora, canale, cliente, categoria."""
    ora = caso.pesato(tuple(enumerate(ORE_PER_GIORNO[giorno])))
    aperto = istante(giorno, "%02d:%02d" % (ora, caso.intero(0, 59)),
                     caso.intero(0, 59))
    canale = canale_per(caso, aperto)
    categoria = caso.pesato(testi.PESI_CATEGORIA)
    if categoria == "copertura" or (categoria == "informazioni"
                                    and caso.probabile(0.4)):
        cliente = nuovo_potenziale(caso, registro)
    else:
        cliente = caso.scegli([c for c in clienti if adatto(categoria, c)])
    squadre = [(s, p) for s, p in testi.TEAM_CATEGORIA[categoria]
               if canale == "chat" or s != "assistente_virtuale"]
    team = caso.pesato(squadre)
    testo = descrivi(caso, cliente, canale, aperto, testi.CORPI[categoria],
                     testi.NOTE[categoria])
    return assembla(caso, aperto, canale, cliente, categoria, team,
                    chiusura(caso, aperto, categoria, team), testo,
                    caso.scegli(testi.OGGETTI[categoria]))


def ticket_di_guasto(caso: Caso, chiave: str, aperto: dt.datetime,
                     canale: str, cliente: Cliente, categoria: str, team: str,
                     chiuso: Optional[dt.datetime], carico: int = 1,
                     priorita: str = "") -> Ticket:
    """Un ticket legato a uno dei guasti della settimana."""
    testo = descrivi(caso, cliente, canale, aperto,
                     testi.GUASTI_CLIENTE[chiave], testi.GUASTI_NOTA[chiave])
    oggetto = testi.OGGETTO_GUASTO[chiave] if caso.probabile(0.7) else \
        caso.scegli(testi.OGGETTI[categoria])
    return assembla(caso, aperto, canale, cliente, categoria, team, chiuso,
                    testo, oggetto, carico=carico, malus=1, priorita=priorita)


def _alta_se_azienda(cliente: Cliente, privato: str = "media") -> str:
    return privato if cliente.tipo == "privato" else "alta"


def guasto_pergine(caso: Caso, segmento: Sequence[Cliente]) -> List[Ticket]:
    """Martedì 10:12-11:40: fibra tagliata su una porta PON di olt-pergine-01."""
    clienti = mescola(caso, segmento)
    uscita = []
    for cliente in clienti[:26]:
        aperto = nell_intervallo(caso, istante(1, "10:16"), istante(1, "11:38"),
                                 inclinato=True)
        chiuso = nell_intervallo(caso, istante(1, "11:44"), istante(1, "12:20"))
        uscita.append(ticket_di_guasto(
            caso, "pergine", aperto, canale_per(caso, aperto), cliente,
            "assenza_connessione", "noc", chiuso, carico=2,
            priorita=_alta_se_azienda(cliente)))
    for primo in uscita[:2]:  # chi scrive di nuovo da un altro canale
        aperto = primo.aperto + dt.timedelta(minutes=caso.intero(15, 40),
                                             seconds=caso.intero(0, 59))
        canale = "chat" if primo.canale != "chat" else "e-mail"
        testo = componi(caso, caso.scegli(testi.PERGINE_DUPLICATO),
                        primo.cliente, canale, aperto,
                        segnaposto(caso, primo.cliente, aperto))
        uscita.append(assembla(
            caso, aperto, canale, primo.cliente, "assenza_connessione", "noc",
            aperto + dt.timedelta(minutes=caso.intero(3, 15)), testo,
            "Seconda segnalazione - già aperto un ticket", annullato=True,
            priorita=primo.priorita))
    return uscita + _pergine_dopo(caso, clienti[26:])


def _pergine_dopo(caso: Caso, altri: Sequence[Cliente]) -> List[Ticket]:
    """Dopo il ripristino: due router da riavviare, due richieste di indennizzo."""
    uscita = []
    for cliente, testo in zip(altri[:2], testi.PERGINE_DOPO):
        aperto = nell_intervallo(caso, istante(1, "11:46"), istante(1, "12:30"))
        uscita.append(assembla(
            caso, aperto, "telefono", cliente, "assenza_connessione",
            "primo_livello", aperto + dt.timedelta(minutes=caso.intero(10, 40)),
            "%s Guidato il riavvio, servizio ripristinato." % testo,
            "Connessione non ripresa dopo il guasto collettivo", malus=1))
    finestre = ((istante(1, "15:00"), istante(1, "19:00"), "portale"),
                (istante(2, "09:00"), istante(2, "12:00"), "e-mail"))
    for cliente, testo, (da, a, canale) in zip(altri[2:4],
                                              testi.PERGINE_INDENNIZZO,
                                              finestre):
        aperto = nell_intervallo(caso, da, a)
        corpo = componi(caso, testo, cliente, canale, aperto,
                        segnaposto(caso, cliente, aperto))
        uscita.append(assembla(caso, aperto, canale, cliente, "reclamo",
                               "amministrazione", None, corpo,
                               "Richiesta indennizzo per il guasto di martedì"))
    return uscita


def guasto_cles(caso: Caso, segmento: Sequence[Cliente]) -> List[Ticket]:
    """Mercoledì 07:52-16:50: perdite a intermittenza sul ponte ptp-cles-01."""
    clienti = mescola(caso, segmento)
    uscita = []
    for cliente in clienti[:16]:
        aperto = nell_intervallo(caso, istante(2, "07:55"), istante(2, "16:45"))
        categoria = caso.pesato((("connessione_instabile", 10),
                                 ("lentezza", 4), ("assenza_connessione", 2)))
        chiuso = None if caso.probabile(0.1) else \
            nell_intervallo(caso, istante(2, "16:55"), istante(2, "18:30"))
        uscita.append(ticket_di_guasto(caso, "cles", aperto,
                                       canale_per(caso, aperto), cliente,
                                       categoria, "noc", chiuso,
                                       priorita=_alta_se_azienda(cliente)))
    cliente = clienti[16]
    aperto = nell_intervallo(caso, istante(3, "09:00"), istante(3, "12:00"))
    corpo = componi(caso, testi.CLES_RECLAMO, cliente, "e-mail", aperto,
                    segnaposto(caso, cliente, aperto))
    uscita.append(assembla(caso, aperto, "e-mail", cliente, "reclamo",
                           "amministrazione", None, corpo,
                           "Richiesta indennizzo per le interruzioni di ieri"))
    return uscita


def guasto_breve(caso: Caso, chiave: str, clienti: Sequence[Cliente],
                 giorno: int, finestra: Tuple[str, str],
                 chiusura_tra: Optional[Tuple[str, str]], categorie,
                 team: str) -> List[Ticket]:
    """Un guasto di poche ore (manutenzione, voce, DHCP)."""
    uscita = []
    for cliente in clienti:
        aperto = nell_intervallo(caso, istante(giorno, finestra[0]),
                                 istante(giorno, finestra[1]), inclinato=True)
        canale = canale_per(caso, aperto)
        squadra = "assistente_virtuale" if chiave == "bng" and \
            canale == "chat" and caso.probabile(0.5) else team
        if chiusura_tra is None:
            fine = aperto + dt.timedelta(minutes=caso.intero(8, 40))
            chiuso = fine if squadra == "assistente_virtuale" else \
                allinea(caso, fine, "operatori")
        else:
            chiuso = nell_intervallo(caso, istante(giorno, chiusura_tra[0]),
                                     istante(giorno, chiusura_tra[1]))
        priorita = "media" if chiave == "bng" else \
            ("urgente" if chiave == "sbc" and caso.probabile(0.4) else "alta")
        uscita.append(ticket_di_guasto(caso, chiave, aperto, canale, cliente,
                                       caso.pesato(categorie), squadra, chiuso,
                                       carico=2 if chiave == "sbc" else 1,
                                       priorita=priorita))
    return uscita


def guasti(caso: Caso, segmenti: Dict[str, List[Cliente]]) -> List[Ticket]:
    privati = [c for c in segmenti["generale"] if c.tipo == "privato"]
    return (guasto_pergine(caso, segmenti["pergine"])
            + guasto_cles(caso, segmenti["cles"])
            + guasto_breve(caso, "bng", mescola(caso, privati)[:7], 3,
                           ("06:15", "09:45"), None,
                           (("assenza_connessione", 5), ("informazioni", 2)),
                           "primo_livello")
            + guasto_breve(caso, "sbc", mescola(caso, segmenti["centralino"])
                           [:13], 4, ("08:06", "10:36"), ("10:42", "11:30"),
                           (("telefonia_voip", 1),), "voce")
            + guasto_breve(caso, "dhcp",
                           mescola(caso, segmenti["rovereto_dhcp"])[:6], 5,
                           ("08:58", "10:50"), ("10:58", "11:40"),
                           (("rete_aziendale", 1),), "noc"))


def ticket_fissi(clienti: Dict[str, Cliente]) -> List[Ticket]:
    """I ticket della storia condivisa e degli scenari, scritti a mano."""
    uscita = []
    for f in testi.TICKET_FISSI:
        cliente = clienti[f["cliente"]]
        aperto = dt.datetime.fromisoformat(f["aperto"])
        chiuso = dt.datetime.fromisoformat(f["chiuso"]) if f["chiuso"] \
            else None
        uscita.append(Ticket(
            aperto, 0, f["canale"], cliente, f["tecnologia"], f["categoria"],
            f["priorita"], f["stato"], chiuso, f["oggetto"], f["descrizione"],
            f["team"], f["prima"], f["voto"], f["telefono"], f["email"],
            cliente.comune, cliente.nome))
    return uscita


def tutti_i_ticket(caso: Caso) -> List[Ticket]:
    """La settimana intera, ordinata per apertura."""
    fissi = clienti_fissi()
    registro = Registro(fissi)
    segmenti = popola(caso, registro)
    # I segmenti di Pergine, Cles e Rovereto servono solo ai guasti: i ticket
    # di fondo seguono la distribuzione dei clienti tra i comuni.
    clienti_di_fondo = segmenti["centralino"] + segmenti["generale"]
    insieme = ticket_fissi({c.id_cliente or c.nome: c for c in fissi}) + \
        guasti(caso, segmenti)
    for giorno, quanti in enumerate(BASE_GIORNO):
        insieme += [ticket_di_fondo(caso, registro, giorno, clienti_di_fondo)
                    for _ in range(quanti)]
    numerati = [t._replace(ordine=i) for i, t in enumerate(insieme)]
    return sorted(numerati, key=lambda t: (t.aperto, t.ordine))
