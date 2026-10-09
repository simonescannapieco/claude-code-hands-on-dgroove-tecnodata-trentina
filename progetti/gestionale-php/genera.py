#!/usr/bin/env python3
"""Genera i dati di esempio del gestionale CiaspoLink (operatore immaginario).

Uso:
    python3 genera.py           riscrive i file di database/dati/
    python3 genera.py --check   rigenera in una cartella temporanea e confronta
                                con database/dati/ (uscita 0 se identici,
                                1 se diversi, 2 per un errore)

Python 3.8 o successivo, solo libreria standard. Il seme è fisso e il caso
passa solo da random.Random(seme).random(): i file sono identici byte per byte
su ogni versione di Python.

Prima di scrivere, il generatore controlla il proprio output: le regole dei
dati sintetici di ../README.md (e-mail, telefoni, indirizzi IP e MAC, cognomi,
partite IVA, formati degli identificativi e delle date), i clienti, le linee,
gli apparati e i disservizi della settimana sintetica comuni ai tre progetti,
l'integrità dei dati caricandoli con lo schema in un SQLite in memoria.
"""

import argparse
import datetime as dt
import math
import os
import random
import re
import sqlite3
import sys
import tempfile

SEME = 20260907
QUI = os.path.dirname(os.path.abspath(__file__))
FILE_SCHEMA = os.path.join(QUI, 'database', 'schema.sql')
CARTELLA_DATI = os.path.join(QUI, 'database', 'dati')

OGGI = dt.date(2026, 9, 13)              # i dati descrivono lo stato a fine giornata
INIZIO_STORICO = dt.date(2025, 9, 1)     # inizio dello storico di ticket, fatture, eventi
ULTIMA_RICHIESTA = dt.date(2026, 7, 31)  # ultima richiesta dei clienti «ordinari»
MESI_FATTURATI = [(2025, m) for m in range(9, 13)] + [(2026, m) for m in range(1, 9)]
PRIMA_FATTURA = {2025: 1397, 2026: 1}    # la numerazione 2025 era già avviata
PRIMO_TICKET = {2025: 611, 2026: 1}
RIGHE_PER_INSERT = 100
DOMINIO_PPPOE = 'ciaspolink.example.org'
GIORNI_MESE_LISTINO = 30                 # come legacy/listino.inc.php
PROVVIGIONE_LISTINO = {'Casa': 4000, 'Business': 8000}  # come legacy/provvigioni.inc.php
ALIQUOTA_IVA = 22
GIORNI_SCADENZA = 30

COGNOMI = ('Esempio', 'Prova', 'Fittizio', 'Campione', 'Modello', 'Bozza',
           'Simulato', 'Inventato', 'Ipotetico', 'Immaginario', 'Provvisorio',
           'Fantasia')
RADICI = ('esempi', 'prov', 'fittizi', 'campion', 'modell', 'bozz', 'simulat',
          'inventat', 'ipotetic', 'immaginari', 'fantasi')
NOMI = ('Marco', 'Luca', 'Andrea', 'Paolo', 'Matteo', 'Stefano', 'Davide',
        'Simone', 'Alessandro', 'Giorgio', 'Roberto', 'Michele', 'Fabio',
        'Nicola', 'Daniele', 'Lorenzo', 'Mattia', 'Tommaso', 'Riccardo',
        'Filippo', 'Mario', 'Franco', 'Sergio', 'Walter', 'Giulia', 'Sara',
        'Chiara', 'Elena', 'Francesca', 'Anna', 'Laura', 'Martina', 'Federica',
        'Silvia', 'Valentina', 'Elisa', 'Serena', 'Ilaria', 'Monica', 'Paola',
        'Sofia', 'Alice', 'Beatrice', 'Irene', 'Marta', 'Cristina', 'Roberta',
        'Lucia')
OPERATORI = ('Elena Modello', 'Davide Bozza', 'Sara Inventato',
             'Matteo Provvisorio', 'Chiara Simulato', 'Paolo Ipotetico')
TECNICI = ('Walter Campione', 'Franco Immaginario', 'Sergio Fantasia',
           'Roberta Esempio')
COLLAUDO = 'collaudo automatico'
NOC = 'NOC'
VIE = ("Via dell'Esempio", 'Via delle Prove', 'Via Fittizia',
       'Via del Campione', 'Via dei Modelli', 'Via della Bozza',
       'Vicolo Simulato', 'Via Inventata', 'Viale Ipotetico',
       'Piazza Immaginaria', 'Largo Provvisorio', 'Via della Fantasia')
MESI = ('gennaio', 'febbraio', 'marzo', 'aprile', 'maggio', 'giugno',
        'luglio', 'agosto', 'settembre', 'ottobre', 'novembre', 'dicembre')

# nome, CAP, zona, apparato, tecnologia, Mbit/s massimi, servito dal,
# clienti generati, quota di aziende
COMUNI = (
    ('Trento', '38122', "Val d'Adige", 'olt-trento-01', 'FTTH', 2500, '2016-01-11', 32, 0.30),
    ('Lavis', '38015', 'Piana Rotaliana', 'olt-trento-01', 'FTTH', 1000, '2018-03-05', 6, 0.30),
    ('Mezzolombardo', '38017', 'Piana Rotaliana', 'olt-trento-01', 'FTTH', 1000, '2018-03-05', 5, 0.30),
    ('Pergine Valsugana', '38057', 'Alta Valsugana', 'olt-pergine-01', 'FTTH', 1000, '2014-02-03', 56, 0.15),
    ('Levico Terme', '38056', 'Alta Valsugana', 'olt-pergine-01', 'FTTH', 1000, '2015-04-13', 8, 0.30),
    ('Caldonazzo', '38052', 'Alta Valsugana', 'olt-pergine-01', 'FTTH', 1000, '2015-04-13', 4, 0.25),
    ('Baselga di Pinè', '38042', 'Alta Valsugana', 'olt-pergine-01', 'FTTH', 1000, '2016-06-06', 4, 0.25),
    ('Borgo Valsugana', '38051', 'Valsugana e Tesino', 'olt-pergine-01', 'FTTH', 1000, '2014-02-03', 8, 0.30),
    ('Rovereto', '38068', 'Vallagarina', 'olt-rovereto-01', 'FTTH', 2500, '2017-02-06', 26, 0.40),
    ('Mori', '38065', 'Vallagarina', 'olt-rovereto-01', 'FTTH', 1000, '2019-01-14', 4, 0.25),
    ('Ala', '38061', 'Vallagarina', 'olt-rovereto-01', 'FTTH', 1000, '2019-01-14', 3, 0.25),
    ('Riva del Garda', '38066', 'Alto Garda', 'olt-rovereto-01', 'FTTH', 1000, '2019-05-06', 11, 0.45),
    ('Arco', '38062', 'Alto Garda', 'olt-rovereto-01', 'FTTH', 1000, '2019-05-06', 7, 0.35),
    ('Cles', '38023', 'Val di Non', 'bts-cles-01', 'FWA', 200, '2015-09-07', 20, 0.35),
    ('Cavalese', '38033', 'Val di Fiemme', None, 'FWA', 200, None, 0, 0.0),
    ('Predazzo', '38037', 'Val di Fiemme', None, None, 0, None, 0, 0.0),
    ('Tione di Trento', '38079', 'Giudicarie', None, None, 0, None, 0, 0.0),
    ('Malé', '38027', 'Val di Sole', None, None, 0, None, 0, 0.0),
    ('Folgaria', '38064', 'Altipiani Cimbri', None, None, 0, None, 0, 0.0),
    ('Primiero San Martino di Castrozza', '38054', 'Primiero', None, None, 0, None, 0, 0.0),
)
PORTE = {
    'Trento': ('0/1/1', '0/1/2', '0/1/3', '0/1/4', '0/1/5', '0/1/6', '0/1/7', '0/1/8'),
    'Lavis': ('0/2/1',), 'Mezzolombardo': ('0/2/2',),
    'Pergine Valsugana': ('0/1/1', '0/1/2', '0/1/4'),
    'Levico Terme': ('0/2/1',), 'Caldonazzo': ('0/2/1',),
    'Baselga di Pinè': ('0/2/2',), 'Borgo Valsugana': ('0/2/3',),
    'Rovereto': ('0/1/1', '0/1/2', '0/1/3', '0/1/4'), 'Mori': ('0/2/1',),
    'Ala': ('0/2/1',), 'Riva del Garda': ('0/2/5',), 'Arco': ('0/2/6',),
    'Cles': ('S1', 'S2', 'S3'),
}
PORTA_PERGINE = '0/1/3'
LINEE_PORTA_PERGINE = 40

APPARATI = (  # id, ruolo, descrizione, comune, IP di gestione, apparato a monte
    ('bng-trento-01', 'bng', 'BNG: terminazione PPPoE con RADIUS e DHCP delle linee business', 'Trento', '192.0.2.1', None),
    ('olt-trento-01', 'olt', 'OLT GPON e XGS-PON di Trento', 'Trento', '192.0.2.11', 'bng-trento-01'),
    ('olt-pergine-01', 'olt', 'OLT GPON di Pergine Valsugana', 'Pergine Valsugana', '192.0.2.12', 'bng-trento-01'),
    ('olt-rovereto-01', 'olt', 'OLT GPON e XGS-PON di Rovereto', 'Rovereto', '192.0.2.13', 'bng-trento-01'),
    ('ptp-cles-01', 'ptp', 'Ponte radio punto-punto verso Cles', 'Cles', '192.0.2.21', 'bng-trento-01'),
    ('bts-cles-01', 'bts', 'Stazione radio base FWA di Cles, tre settori', 'Cles', '192.0.2.22', 'ptp-cles-01'),
    ('sbc-trento-01', 'sbc', 'Session border controller SIP per voce e centralino cloud', 'Trento', '192.0.2.31', None),
)
OFFERTE = (  # codice, nome, famiglia, tecnologia, down, up, canone, attivazione, in listino
    ('CASA_FIBRA_300', 'Casa Fibra 300', 'Casa', 'FTTH', 300, 100, 1990, 3900, 0),
    ('CASA_FIBRA_1G', 'Casa Fibra 1 Giga', 'Casa', 'FTTH', 1000, 300, 2290, 3900, 1),
    ('CASA_FIBRA_25G', 'Casa Fibra 2,5 Giga', 'Casa', 'FTTH', 2500, 500, 3190, 3900, 1),
    ('CASA_RADIO', 'Casa Radio', 'Casa', 'FWA', 100, 20, 2150, 7900, 1),
    ('BIZ_FIBRA_1G', 'Business Fibra 1 Giga', 'Business', 'FTTH', 1000, 1000, 4900, 9900, 1),
    ('BIZ_FIBRA_25G', 'Business Fibra 2,5 Giga', 'Business', 'FTTH', 2500, 1000, 7900, 9900, 1),
    ('BIZ_RADIO', 'Business Radio', 'Business', 'FWA', 200, 50, 4400, 14900, 1),
)
SERVIZI = (  # codice, nome, unità, canone per unità, solo business
    ('HOTSPOT_WIFI', 'Hotspot Wi-Fi', 'linea', 1900, 1),
    ('IP_STATICO', 'IP statico', 'indirizzo', 500, 0),
    ('LINEA_VOCE', 'Linea voce di casa', 'linea', 300, 0),
    ('VOIP_INTERNO', 'Centralino Cloud - interno VoIP', 'interno', 390, 1),
)
RIVENDITORI = (  # ragione sociale, comune, provvigione Casa, Business, dal, attivo
    ('Elettronica Esempio S.n.c.', 'Pergine Valsugana', 4000, 8000, '2016-03-01', 1),
    ('Ferramenta Prova', 'Levico Terme', 4000, 8000, '2016-05-16', 1),
    ('Computer Fittizio S.r.l.', 'Trento', 5000, 9000, '2017-01-09', 1),
    ('Bottega Campione', 'Borgo Valsugana', 4000, 8000, '2016-09-05', 1),
    ('Telefonia Modello', 'Rovereto', 4000, 8000, '2018-02-05', 1),
    ('Cartoleria Bozza', 'Riva del Garda', 4000, 8000, '2019-06-03', 1),
    ('Informatica Simulata S.n.c.', 'Arco', 4000, 8000, '2019-06-17', 1),
    ('Emporio Inventato', 'Cles', 4000, 8000, '2016-03-07', 1),
    ('Tecnica Ipotetica S.r.l.', 'Mezzolombardo', 4500, 8500, '2021-01-18', 1),
    ('Foto Ottica Immaginaria', 'Lavis', 4000, 8000, '2021-05-03', 1),
    ('Elettrodomestici Provvisori', 'Mori', 3500, 7000, '2022-02-07', 1),
    ('Negozio Fantasia', 'Caldonazzo', 4000, 8000, '2022-07-04', 1),
    ('Radio TV Esempio', 'Cavalese', 4000, 8000, '2023-03-06', 1),
    ('Studio Tecnico Prova', 'Baselga di Pinè', 4000, 8000, '2023-09-04', 1),
    ('PC Service Campione', 'Ala', 4000, 8000, '2024-04-08', 1),
    ('Ufficio Moderno Fittizio S.r.l.', 'Tione di Trento', 4000, 8000, '2025-01-13', 0),
)
NOMINATI = (  # i clienti della storia comune ai tre progetti
    dict(id='CL-000101', tipo='privato', nome='Laura', cognome='Prova',
         comune='Pergine Valsugana', via="Via dell'Esempio", civico='12',
         richiesta='2023-04-03T10:20:00', completata='2023-04-18T11:30:00',
         rivenditore='RV-001', linea='LN-000201', offerta='CASA_FIBRA_1G',
         porta='0/1/3', velocita=1000, servizi=(('LINEA_VOCE', 1),),
         mac=0x01, ipv4=None, ipv6=None),
    dict(id='CL-000102', tipo='azienda', ragione_sociale='Rifugio Campione',
         comune='Cles', via='Località Malga Esempio', civico='3',
         richiesta='2022-05-20T09:40:00', completata='2022-06-10T10:15:00',
         rivenditore='RV-008', linea='LN-000202', offerta='BIZ_RADIO',
         porta='S1', velocita=200, servizi=(('IP_STATICO', 1),),
         mac=0x02, ipv4='203.0.113.2', ipv6='2001:db8:c1a5:200::/56'),
    dict(id='CL-000103', tipo='azienda',
         ragione_sociale='Falegnameria Fittizia S.n.c.', comune='Rovereto',
         via='Via delle Prove', civico='4',
         richiesta='2025-02-25T15:05:00', completata='2025-03-12T14:40:00',
         rivenditore='RV-005', linea='LN-000203', offerta='BIZ_FIBRA_25G',
         porta='0/1/2', velocita=2500,
         servizi=(('IP_STATICO', 1), ('VOIP_INTERNO', 6)),
         mac=0x03, ipv4='203.0.113.3', ipv6='2001:db8:c1a5:300::/56'),
    dict(id='CL-000104', tipo='privato', nome='Mario', cognome='Esempio',
         comune='Cles', via='Via del Campione', civico='8',
         richiesta='2024-09-16T17:10:00', completata='2024-10-02T09:50:00',
         rivenditore=None, linea='LN-000204', offerta='CASA_RADIO',
         porta='S2', velocita=100, servizi=(), mac=0x04, ipv4=None, ipv6=None),
    dict(id='CL-000105', tipo='azienda', ragione_sociale='Albergo Modello',
         comune='Riva del Garda', via='Viale Ipotetico', civico='21',
         richiesta='2023-05-02T11:00:00', completata='2023-05-22T10:05:00',
         rivenditore='RV-006', linea='LN-000205', offerta='BIZ_FIBRA_1G',
         porta='0/2/5', velocita=1000,
         servizi=(('HOTSPOT_WIFI', 1), ('IP_STATICO', 1)),
         mac=0x05, ipv4='203.0.113.5', ipv6='2001:db8:c1a5:500::/56'),
    dict(id='CL-000106', tipo='privato', nome='Giulia', cognome='Fittizio',
         comune='Trento', via='Via della Bozza', civico='7',
         richiesta='2026-01-28T18:25:00', completata='2026-02-16T15:20:00',
         rivenditore=None, linea='LN-000206', offerta='CASA_FIBRA_25G',
         porta='0/1/7', velocita=2500, servizi=(), mac=0x06, ipv4=None,
         ipv6=None),
)
# Clienti generati con una storia fissata (gli altri seguono il caso).
# Profili: (tipo, …); in_corso = (tipo, richiesta, stato, tipo di cliente o
# None, giorno pianificato o None).
SPECIALI = {
    'Trento': (('rv003', '2026-07-24T16:10:00', '2026-08-06T10:40:00', 'privato'),
               ('rv003', '2026-07-28T11:35:00', '2026-08-11T15:15:00', 'azienda'),
               ('rv003_in_corso', '2026-08-27T17:05:00', 'pianificata', 'privato', '2026-09-15'),
               ('settimana', '2026-09-07T15:20:00'),
               ('settimana', '2026-09-10T01:12:00'),
               ('in_corso', '2026-09-11T09:45:00', 'richiesta'),
               ('annullata', '2025-11-10T10:30:00'),
               ('moroso',),
               ('disdetta_solo_anagrafica', '2026-06-15'),
               ('ferma', '2026-05-19T14:20:00')),
    'Lavis': (('in_corso', '2026-09-04T12:05:00', 'verifica_tecnica'),),
    'Mezzolombardo': (('ferma', '2026-06-03T09:15:00'),),
    'Pergine Valsugana': tuple([('porta_pergine',)] * (LINEE_PORTA_PERGINE - 1)
                               + [('porta_pergine_cessata',)] * 3
                               + [('moroso',), ('annullata', '2026-02-16T15:45:00'),
                                  ('in_corso', '2026-09-01T10:10:00', 'pianificata',
                                   None, '2026-09-16')]),
    'Levico Terme': (('settimana', '2026-09-08T11:05:00'), ('senza_apparato',)),
    'Baselga di Pinè': (('ferma', '2026-05-26T16:40:00'),),
    'Borgo Valsugana': (('in_corso', '2026-08-24T10:25:00', 'installazione',
                         None, '2026-09-10'),),
    'Rovereto': (('settimana', '2026-09-08T00:34:00'),
                 ('in_corso', '2026-09-07T11:50:00', 'verifica_tecnica'),
                 ('moroso',), ('disdetta_solo_anagrafica', '2026-06-22'),
                 ('annullata', '2026-04-20T09:30:00')),
    'Riva del Garda': (('settimana', '2026-09-09T16:40:00'),),
    'Arco': (('settimana', '2026-09-11T10:30:00'),),
    'Cles': (('in_corso', '2026-09-12T10:15:00', 'richiesta'),
             ('annullata', '2025-12-05T11:20:00')),
}
ATTIVITA = (  # tipo di attività, ospitalità (candidata all'hotspot)
    ('Albergo', True), ('Hotel', True), ('Garni', True), ('Agriturismo', True),
    ('Campeggio', True), ('Bar', True), ('Ristorante', True),
    ('Pizzeria', True), ('Gelateria', True), ('Officina', False),
    ('Autofficina', False), ('Panificio', False), ('Macelleria', False),
    ('Studio Associato', False), ('Studio Dentistico', False),
    ('Impresa Edile', False), ('Idraulica', False), ('Elettrauto', False),
    ('Segheria', False), ('Caseificio', False), ('Cantina', False),
    ('Frutticoltura', False), ('Apicoltura', False), ('Tipografia', False),
    ('Lavanderia', False), ('Carrozzeria', False), ('Parrucchiera', False),
)
FORME = ('', ' S.n.c.', ' S.r.l.', ' S.a.s.')
ASSOCIAZIONI = ('Associazione Culturale', 'Polisportiva', 'Coro',
                'Circolo Ricreativo', 'Sci Club', 'Banda Musicale',
                'Gruppo Volontari')
NOTE_CLIENTI = ('Preferisce essere contattato via e-mail.',
                'Accesso al locale tecnico dal retro.',
                'Chiede preavviso di un giorno per gli interventi.',
                'Fatture da inviare anche al commercialista.',
                'Presente solo nel fine settimana.')
NOTE_ANNULLATE = ('Annullata: copertura insufficiente al sopralluogo.',
                  'Annullata: rinuncia del cliente.',
                  "Annullata: l'edificio non è raggiungibile con la fibra.")
TESTI = {  # categoria -> (oggetto, descrizione); {fattura} = una fattura del cliente
    'guasto': (('Connessione assente', 'Da questa mattina il modem non naviga e la spia della fibra è rossa.'),
               ('Linea che cade più volte al giorno', 'La connessione si interrompe per qualche minuto, più volte al giorno.'),
               ('Modem spento dopo un temporale', 'Dopo il temporale di ieri sera il modem non si accende più.')),
    'guasto_fwa': (('Antenna senza segnale', "Il ricevitore radio sul tetto non risponde e il modem segnala l'assenza di collegamento."),
                   ('Connessione assente', 'Da ieri sera la connessione non funziona, il modem è acceso.')),
    'lentezza': (('Velocità inferiore al profilo', 'Lo speed test via cavo dà valori molto più bassi di quelli del contratto.'),
                 ('Lentezza la sera', 'Dalle 20 alle 23 la navigazione è molto lenta.'),
                 ('Videochiamate che si bloccano', "Durante le videochiamate l'audio e il video si bloccano.")),
    'wifi': (('Wi-Fi debole al piano superiore', 'Al primo piano il segnale Wi-Fi è quasi assente.'),
             ('Cambio password del Wi-Fi', 'Chiede le istruzioni per cambiare la password della rete Wi-Fi.'),
             ('Dispositivi che non si collegano al Wi-Fi', 'La stampante e il televisore non si collegano più alla rete Wi-Fi.')),
    'voce': (('Telefono di casa muto', 'Il telefono collegato al modem non dà il segnale di linea.'),
             ('Chiamate in uscita che non partono', 'Le chiamate verso i cellulari non partono, quelle in arrivo funzionano.')),
    'voce_centralino': (('Interno del centralino non registrato', 'Un interno del centralino cloud risulta non registrato.'),
                        ('Trasferimento di chiamata non funzionante', 'Il trasferimento di chiamata tra due interni non funziona.')),
    'amministrativo': (('Richiesta copia fattura', 'Chiede una copia della fattura {fattura}.'),
                       ('Cambio indirizzo e-mail per le fatture', 'Chiede di inviare le fatture a un nuovo indirizzo e-mail.'),
                       ('Chiarimenti su una fattura', 'Chiede spiegazioni sulle voci della fattura {fattura}.'),
                       ('Informazioni sulla disdetta', 'Chiede la procedura e i tempi per la disdetta del contratto.'),
                       ('Modifica dei dati di pagamento', "Comunica nuovi dati per l'addebito: aggiornati in anagrafica.")),
    'attivazione': (('Stato della richiesta di attivazione', "Chiede a che punto è l'attivazione richiesta."),
                    ("Spostamento dell'appuntamento", "Chiede di spostare l'appuntamento per l'installazione.")),
}


class ErroreGenerazione(Exception):
    """I dati prodotti violano una regola: nessun file viene scritto."""


class Caso:
    """Caso deterministico: usa soltanto Random.random() con seme fisso."""

    def __init__(self, seme):
        self._r = random.Random(seme)

    def unif(self):
        return self._r.random()

    def intero(self, a, b):
        return a + int(self._r.random() * (b - a + 1))

    def scegli(self, seq):
        return seq[int(self._r.random() * len(seq))]

    def prob(self, p):
        return self._r.random() < p

    def pesato(self, coppie):
        totale = sum(peso for _, peso in coppie)
        x = self._r.random() * totale
        for valore, peso in coppie:
            x -= peso
            if x < 0:
                return valore
        return coppie[-1][0]

    def mescola(self, seq):
        out = list(seq)
        for i in range(len(out) - 1, 0, -1):
            j = int(self._r.random() * (i + 1))
            out[i], out[j] = out[j], out[i]
        return out


# --- date e ore -------------------------------------------------------------

def data(s):
    return dt.date(int(s[0:4]), int(s[5:7]), int(s[8:10]))


def momento(s):
    return dt.datetime(int(s[0:4]), int(s[5:7]), int(s[8:10]),
                       int(s[11:13]), int(s[14:16]), int(s[17:19]))


def alle(giorno, ora, minuto):
    return dt.datetime(giorno.year, giorno.month, giorno.day, ora, minuto)


def ultima_domenica(anno, mese):
    giorno = dt.date(anno + mese // 12, mese % 12 + 1, 1) - dt.timedelta(days=1)
    while giorno.weekday() != 6:
        giorno -= dt.timedelta(days=1)
    return giorno


def offset_roma(giorno, ora):
    """'+02:00' in ora legale, '+01:00' in ora solare (regola dell'Unione europea)."""
    inizio, fine = ultima_domenica(giorno.year, 3), ultima_domenica(giorno.year, 10)
    if giorno == inizio:
        legale = ora >= 3
    elif giorno == fine:
        legale = ora < 3
    else:
        legale = inizio < giorno < fine
    return '+02:00' if legale else '+01:00'


def iso(m):
    return m.strftime('%Y-%m-%dT%H:%M:%S') + offset_roma(m.date(), m.hour)


def secondi_utc(s):
    """Secondi dall'epoca di un istante ISO 8601 con offset."""
    locale = momento(s)
    segno = 1 if s[19] == '+' else -1
    offset = dt.timedelta(hours=int(s[20:22]), minutes=int(s[23:25])) * segno
    return (locale - offset - dt.datetime(1970, 1, 1)).total_seconds()


def feriale(giorno):
    while giorno.weekday() >= 5:
        giorno += dt.timedelta(days=1)
    return giorno


def giorni(n):
    return dt.timedelta(days=n)


def data_it(s):
    return '%s/%s/%s' % (s[8:10], s[5:7], s[0:4])


def mese_dopo(anno, mese):
    return (anno + 1, 1) if mese == 12 else (anno, mese + 1)


# --- identità ---------------------------------------------------------------

def cifra_controllo_piva(prime_dieci):
    somma = 0
    for i, cifra in enumerate(prime_dieci):
        if i % 2 == 0:
            somma += cifra
        else:
            doppio = cifra * 2
            somma += doppio - 9 if doppio > 9 else doppio
    return (10 - somma % 10) % 10


class Anagrafe:
    """Nomi, e-mail, telefoni e partite IVA unici."""

    def __init__(self, caso):
        self.caso = caso
        self.riservate = set(OPERATORI + TECNICI + ('Laura Prova', 'Mario Esempio',
                                                     'Giulia Fittizio'))
        self.email = set(('laura.prova@example.org', 'rifugio.campione@example.org',
                          'falegnameria.fittizia@example.org',
                          'mario.esempio@example.org', 'albergo.modello@example.org',
                          'giulia.fittizio@example.org'))
        self.telefoni = set('+39 000 000 %04d' % (100 + i) for i in range(1, 7))
        self.piva = set()
        self.ragioni_sociali = set(('Rifugio Campione', 'Falegnameria Fittizia',
                                    'Albergo Modello'))

    def persona(self, riservata=False):
        """Nome e cognome; mai uguali a quelli del personale o dei nominati."""
        while True:
            nome, cognome = self.caso.scegli(NOMI), self.caso.scegli(COGNOMI)
            completo = nome + ' ' + cognome
            if completo in self.riservate:
                continue
            if riservata:
                self.riservate.add(completo)
            return nome, cognome

    def indirizzo_email(self, base):
        locale = re.sub(r'[^a-z0-9.]', '', base.lower().replace(' ', '.'))
        locale = re.sub(r'\.+', '.', locale).strip('.')
        candidato, n = locale, 1
        while candidato + '@example.org' in self.email:
            n += 1
            candidato = '%s%d' % (locale, n)
        self.email.add(candidato + '@example.org')
        return candidato + '@example.org'

    def telefono(self):
        while True:
            numero = '+39 00%d %03d %04d' % (self.caso.intero(0, 9),
                                             self.caso.intero(0, 999),
                                             self.caso.intero(0, 9999))
            if numero not in self.telefoni:
                self.telefoni.add(numero)
                return numero

    def partita_iva(self):
        while True:
            prime = [0, 0] + [self.caso.intero(0, 9) for _ in range(8)]
            giusta = cifra_controllo_piva(prime)
            piva = ''.join(str(c) for c in prime) + str((giusta + self.caso.intero(1, 9)) % 10)
            if piva not in self.piva:
                self.piva.add(piva)
                return piva

    def ragione_sociale(self, tipo):
        while True:
            cognome = self.caso.scegli(COGNOMI)
            if tipo == 'associazione':
                base, forma, ospitalita = self.caso.scegli(ASSOCIAZIONI) + ' ' + cognome, '', False
            else:
                attivita, ospitalita = self.caso.scegli(ATTIVITA)
                base, forma = attivita + ' ' + cognome, self.caso.scegli(FORME)
            if base not in self.ragioni_sociali:
                self.ragioni_sociali.add(base)
                return base + forma, ospitalita


# --- rete, copertura, rivenditori -------------------------------------------

VIE_PORTA_PERGINE = ("Via dell'Esempio", 'Via delle Prove', 'Via Fittizia',
                     'Vicolo Simulato')
OFFERTA = {o[0]: dict(codice=o[0], nome=o[1], famiglia=o[2], tecnologia=o[3],
                      canone=o[6], attivazione=o[7]) for o in OFFERTE}
NOME_SERVIZIO = {s[0]: s[1] for s in SERVIZI}
PREZZO_SERVIZIO = {s[0]: s[3] for s in SERVIZI}


def info_comune(nome):
    for riga in COMUNI:
        if riga[0] == nome:
            return riga
    raise ErroreGenerazione('comune sconosciuto: ' + nome)


def data_casuale(caso, dal, al):
    return dal + giorni(int(caso.unif() * ((al - dal).days + 1)))


def nuovo_indirizzo(caso, comune, via, civico, scala, **campi):
    indirizzo = dict(comune=comune, via=via, civico=civico, scala=scala,
                     aggiornata=data_casuale(caso, dt.date(2025, 1, 7),
                                             dt.date(2026, 8, 28)).isoformat())
    indirizzo.update(campi)
    return indirizzo


def genera_copertura(caso):
    """Indirizzi coperti o pianificati, per comune; quelli dei nominati per primi."""
    per_comune = {}
    for nome, _cap, _zona, apparato, tecnologia, vmax, dal, n, _quota in COMUNI:
        if tecnologia is None:
            continue
        indirizzi, visti = [], set()
        for c in NOMINATI:
            if c['comune'] == nome:
                visti.add((c['via'], c['civico'], ''))
                indirizzi.append(nuovo_indirizzo(
                    caso, nome, c['via'], c['civico'], '', tecnologia=tecnologia,
                    velocita=c['velocita'], apparato=apparato, porta=c['porta'],
                    dal=dal, nominato=True))
        da_fare = int(n * 1.3) + 6
        while da_fare > 0:
            via, civico = caso.scegli(VIE), str(caso.intero(1, 80))
            scala = '' if caso.prob(0.85) else caso.scegli(('A', 'B', 'C'))
            if (via, civico, scala) in visti:
                continue
            visti.add((via, civico, scala))
            velocita, porta = vmax, None
            if apparato and tecnologia == 'FWA':
                velocita = 200 if caso.prob(0.7) else 100
            if apparato and nome == 'Pergine Valsugana' and via in VIE_PORTA_PERGINE:
                porta = PORTA_PERGINE
            elif apparato:
                porta = caso.scegli(PORTE[nome])
            indirizzi.append(nuovo_indirizzo(
                caso, nome, via, civico, scala, tecnologia=tecnologia,
                velocita=velocita, apparato=apparato, porta=porta, dal=dal,
                nominato=False))
            da_fare -= 1
        per_comune[nome] = indirizzi
    for civico in ('101', '103', '105'):  # fibra in arrivo in una via nuova
        per_comune['Levico Terme'].append(nuovo_indirizzo(
            caso, 'Levico Terme', 'Via della Fantasia', civico, '',
            tecnologia='FTTH', velocita=1000, apparato=None, porta=None,
            dal=None, nominato=False))
    return per_comune


def genera_rivenditori(anagrafe):
    righe = []
    for i, (ragione, comune, casa, business, dal, attivo) in enumerate(RIVENDITORI, 1):
        nome, cognome = anagrafe.persona(riservata=True)
        base = re.sub(r' (S\.n\.c\.|S\.r\.l\.|S\.a\.s\.)$', '', ragione)
        righe.append(dict(id='RV-%03d' % i, ragione=ragione,
                          referente=nome + ' ' + cognome, comune=comune,
                          zona=info_comune(comune)[2],
                          email=anagrafe.indirizzo_email(base),
                          telefono=anagrafe.telefono(),
                          piva=anagrafe.partita_iva(), casa=casa,
                          business=business, dal=dal, attivo=attivo))
    return righe


# --- clienti, linee, attivazioni --------------------------------------------

def richiesta_casuale(caso, dal, al):
    """Un momento tra due date, più probabile verso la fine (clienti in crescita)."""
    giorno = dal + giorni(int((caso.unif() ** 0.5) * (al - dal).days))
    return alle(giorno, caso.intero(9, 18), caso.intero(0, 59))


def notte(caso, giorno):
    minuti = caso.intero(10, 110)
    return alle(giorno, minuti // 60, minuti % 60)


def percorso(caso, richiesta, esito, completata=None, pianificata=None):
    """Passaggi di stato di un'attivazione fino all'esito, con le date chiave.

    Restituisce (passi, giorno di lavoro, completata); passi = [(da, a, momento)].
    """
    passi = [(None, 'richiesta', richiesta)]
    if esito == 'richiesta':
        return passi, None, None
    verifica = alle(richiesta.date() + giorni(caso.intero(1, 2)),
                    caso.intero(9, 11), caso.intero(0, 59))
    passi.append(('richiesta', 'verifica_tecnica', verifica))
    if esito == 'verifica_tecnica':
        return passi, None, None
    if esito == 'annullata':
        fine = alle(verifica.date() + giorni(caso.intero(2, 10)),
                    caso.intero(9, 17), caso.intero(0, 59))
        passi.append(('verifica_tecnica', 'annullata', fine))
        return passi, None, None
    passi.append(('verifica_tecnica', 'pianificata',
                  alle(richiesta.date() + giorni(caso.intero(3, 6)),
                       caso.intero(12, 17), caso.intero(0, 59))))
    if completata is not None:
        lavoro = completata.date() - giorni(1 if completata.hour < 6 else 0)
    elif pianificata is not None:
        lavoro = pianificata
    else:
        lavoro = feriale(richiesta.date() + giorni(caso.intero(8, 24)))
        if caso.prob(0.12):
            completata = notte(caso, lavoro + giorni(1))
        else:
            completata = alle(lavoro, caso.intero(9, 16), caso.intero(0, 59))
    if esito == 'pianificata':
        return passi, lavoro, None
    passi.append(('pianificata', 'installazione', alle(lavoro, 8, 30)))
    if esito == 'installazione':
        return passi, lavoro, None
    passi.append(('installazione', 'completata', completata))
    return passi, lavoro, completata


def storia(caso, profilo, dal):
    """Richiesta, esito dell'attivazione e vicende successive di un cliente."""
    tipo = profilo[0]
    s = dict(esito='completata', completata=None, pianificata=None,
             cessata=None, moroso=False, disdetta=None, rivenditore=None)
    if tipo in ('normale', 'porta_pergine', 'senza_apparato'):
        s['richiesta'] = richiesta_casuale(caso, dal, ULTIMA_RICHIESTA)
    elif tipo == 'porta_pergine_cessata':
        s['richiesta'] = richiesta_casuale(caso, dal, dt.date(2024, 5, 31))
        s['cessata'] = data_casuale(caso, dt.date(2025, 10, 1), dt.date(2026, 8, 25))
    elif tipo in ('moroso', 'disdetta_solo_anagrafica'):
        s['richiesta'] = richiesta_casuale(caso, dal, dt.date(2025, 6, 30))
        s['moroso'] = tipo == 'moroso'
        s['disdetta'] = data(profilo[1]) if len(profilo) > 1 else None
    elif tipo == 'settimana':
        s['completata'] = momento(profilo[1])
        lavoro = s['completata'].date() - giorni(1 if s['completata'].hour < 6 else 0)
        s['richiesta'] = alle(lavoro - giorni(caso.intero(10, 20)),
                              caso.intero(9, 18), caso.intero(0, 59))
    elif tipo == 'rv003':
        s['richiesta'], s['completata'] = momento(profilo[1]), momento(profilo[2])
        s['rivenditore'] = 'RV-003'
    elif tipo in ('in_corso', 'rv003_in_corso'):
        s['richiesta'], s['esito'] = momento(profilo[1]), profilo[2]
        s['pianificata'] = data(profilo[4]) if len(profilo) > 4 else None
        s['rivenditore'] = 'RV-003' if tipo == 'rv003_in_corso' else None
    elif tipo == 'ferma':
        s['richiesta'], s['esito'] = momento(profilo[1]), 'verifica_tecnica'
    elif tipo == 'annullata':
        s['richiesta'], s['esito'] = momento(profilo[1]), 'annullata'
    else:
        raise ErroreGenerazione('profilo sconosciuto: %s' % (profilo,))
    s['passi'], s['lavoro'], completata = percorso(
        caso, s['richiesta'], s['esito'], s['completata'], s['pianificata'])
    s['completata'] = completata
    if tipo == 'normale' and completata is not None:
        attiva = completata.date()
        if attiva < dt.date(2025, 3, 1) and caso.prob(0.07):
            primo = max(attiva + giorni(200), dt.date(2024, 1, 8))
            s['cessata'] = data_casuale(caso, primo, dt.date(2026, 8, 25))
        elif attiva < dt.date(2026, 1, 1) and caso.prob(0.02):
            s['moroso'] = True
    return s


def tipo_cliente(caso, profilo, quota_aziende):
    if profilo[0] in ('rv003', 'rv003_in_corso', 'in_corso') and len(profilo) > 3 \
            and profilo[3] is not None:
        return profilo[3]
    if profilo[0].startswith('porta_pergine'):
        quota_aziende = 0.08
    if caso.prob(quota_aziende):
        return 'azienda'
    return 'associazione' if caso.prob(0.06) else 'privato'


def famiglia_per(caso, tipo):
    if tipo == 'azienda':
        return 'Business'
    if tipo == 'associazione' and caso.prob(0.3):
        return 'Business'
    return 'Casa'


def scegli_indirizzo(caso, indirizzi, profilo, famiglia):
    """Un indirizzo coperto; a Pergine la porta 0/1/3 è riservata ai suoi profili."""
    porta_pergine = profilo[0].startswith('porta_pergine')
    adatti = [i for i in indirizzi
              if not i['nominato'] and i['dal'] is not None
              and (i['comune'] != 'Pergine Valsugana'
                   or (i['porta'] == PORTA_PERGINE) == porta_pergine)
              and not (famiglia == 'Business' and i['tecnologia'] == 'FWA'
                       and i['velocita'] < 200)]
    if not adatti:
        raise ErroreGenerazione('nessun indirizzo adatto per %s' % (profilo,))
    return caso.scegli(adatti)


def scegli_offerta(caso, famiglia, indirizzo, richiesta):
    if indirizzo['tecnologia'] == 'FWA':
        return 'BIZ_RADIO' if famiglia == 'Business' else 'CASA_RADIO'
    if famiglia == 'Business':
        if indirizzo['velocita'] >= 2500 and caso.prob(0.4):
            return 'BIZ_FIBRA_25G'
        return 'BIZ_FIBRA_1G'
    scelte = [('CASA_FIBRA_1G', 55)]
    if indirizzo['velocita'] >= 2500:
        scelte.append(('CASA_FIBRA_25G', 25))
    if richiesta.date() < dt.date(2022, 1, 1):
        scelte.append(('CASA_FIBRA_300', 35))
    return caso.pesato(scelte)


def scegli_rivenditore(caso, zona, richiesta, rivenditori, forzato):
    if forzato:
        return forzato
    adatti = [r['id'] for r in rivenditori
              if r['zona'] == zona and r['attivo'] and data(r['dal']) <= richiesta.date()]
    if adatti and caso.prob(0.45):
        return caso.scegli(adatti)
    return None


def anagrafica(caso, anagrafe, tipo):
    if tipo == 'privato':
        nome, cognome = anagrafe.persona()
        return dict(nome=nome, cognome=cognome, ragione=None, piva=None,
                    email=anagrafe.indirizzo_email(nome + '.' + cognome),
                    telefono=anagrafe.telefono(), ospitalita=False)
    ragione, ospitalita = anagrafe.ragione_sociale(tipo)
    base = re.sub(r' (S\.n\.c\.|S\.r\.l\.|S\.a\.s\.)$', '', ragione)
    return dict(nome=None, cognome=None, ragione=ragione,
                piva=anagrafe.partita_iva() if tipo == 'azienda' else None,
                email=anagrafe.indirizzo_email(base),
                telefono=anagrafe.telefono(), ospitalita=ospitalita)


def operatore_richiesta(caso, rivenditore):
    return rivenditore if rivenditore else caso.scegli(OPERATORI + ('web',))


def nuova_attivazione(caso, linea, s, rivenditore):
    tecnico = None
    if s['completata'] is not None:
        tecnico = COLLAUDO if s['completata'].hour < 6 else caso.scegli(TECNICI)
    elif s['esito'] in ('pianificata', 'installazione'):
        tecnico = caso.scegli(TECNICI)
    passi = []
    for da, a, quando in s['passi']:
        if a == 'richiesta':
            chi = operatore_richiesta(caso, rivenditore)
        elif a in ('installazione', 'completata'):
            chi = tecnico if tecnico else caso.scegli(TECNICI)
        else:
            chi = caso.scegli(OPERATORI)
        passi.append((da, a, quando, chi))
    note = None
    if s['esito'] == 'annullata':
        note = caso.scegli(NOTE_ANNULLATE)
    elif s['esito'] == 'installazione':
        note = 'Installazione sospesa: manca il permesso del condominio per il passaggio della fibra.'
    return dict(linea=linea, tipo='nuova', offerta=linea['offerta'],
                rivenditore=rivenditore, stato=s['esito'],
                richiesta=s['richiesta'],
                pianificata=s['lavoro'] if s['esito'] not in ('richiesta', 'verifica_tecnica', 'annullata') else None,
                completata=s['completata'], aggiornata=passi[-1][2],
                tecnico=tecnico, note=note, passi=passi)


def nuova_linea(cliente, indirizzo, offerta, s, senza_apparato=False):
    if s['esito'] == 'completata':
        stato = 'sospesa' if s['moroso'] else 'attiva'
        attiva_dal = s['completata'].date().isoformat()
        cessata = s['cessata'].isoformat() if s['cessata'] else None
        if cessata:
            stato = 'cessata'
    elif s['esito'] == 'annullata':
        stato, attiva_dal, cessata = 'cessata', None, s['passi'][-1][2].date().isoformat()
    else:
        stato, attiva_dal, cessata = 'in_attivazione', None, None
    return dict(cliente=cliente, offerta=offerta, indirizzo=indirizzo,
                apparato=None if senza_apparato else indirizzo['apparato'],
                porta=None if senza_apparato else indirizzo['porta'],
                accesso='dhcp' if OFFERTA[offerta]['famiglia'] == 'Business' else 'pppoe',
                stato=stato, attiva_dal=attiva_dal, cessata_il=cessata,
                richiesta=s['richiesta'], servizi=[], esito=s['esito'])


def stato_e_note(caso, s):
    if s['esito'] == 'annullata' or s['cessata'] is not None:
        return 'cessato', None
    if s['disdetta'] is not None:
        return 'cessato', 'Disdetta ricevuta il %s.' % data_it(s['disdetta'].isoformat())
    if s['moroso']:
        return 'sospeso', 'Linea sospesa per morosità il 02/09/2026.'
    return 'attivo', caso.scegli(NOTE_CLIENTI) if caso.prob(0.1) else None


def nuovo_cliente(caso, anagrafe, comune, profilo, indirizzi, rivenditori, seq):
    _n, _cap, zona, _app, _tec, _vmax, dal, _num, quota = info_comune(comune)
    tipo = tipo_cliente(caso, profilo, quota)
    famiglia = famiglia_per(caso, tipo)
    anag = anagrafica(caso, anagrafe, tipo)
    s = storia(caso, profilo, data(dal))
    indirizzo = scegli_indirizzo(caso, indirizzi, profilo, famiglia)
    rivenditore = scegli_rivenditore(caso, zona, s['richiesta'], rivenditori, s['rivenditore'])
    offerta = scegli_offerta(caso, famiglia, indirizzo, s['richiesta'])
    stato, note = stato_e_note(caso, s)
    cliente = dict(tipo=tipo, nome=anag['nome'], cognome=anag['cognome'],
                   ragione=anag['ragione'], piva=anag['piva'],
                   email=anag['email'], telefono=anag['telefono'],
                   via=indirizzo['via'], civico=indirizzo['civico'],
                   comune=comune, rivenditore=rivenditore, stato=stato,
                   dal=s['richiesta'].date().isoformat(), note=note,
                   richiesta=s['richiesta'], seq=seq, moroso=s['moroso'],
                   disdetta=s['disdetta'], ospitalita=anag['ospitalita'],
                   profilo=profilo[0])
    linea = nuova_linea(cliente, indirizzo, offerta, s, profilo[0] == 'senza_apparato')
    linea['attivazione'] = nuova_attivazione(caso, linea, s, rivenditore)
    linee = [linea]
    if profilo[0] == 'normale' and tipo == 'azienda' and stato == 'attivo' and caso.prob(0.12):
        seconda = seconda_linea(caso, cliente, linea, indirizzi, famiglia)
        if seconda is not None:
            linee.append(seconda)
    return cliente, linee


def seconda_linea(caso, cliente, prima, indirizzi, famiglia):
    inizio = prima['attivazione']['completata'].date() + giorni(caso.intero(60, 900))
    if inizio > ULTIMA_RICHIESTA:
        return None
    richiesta = alle(inizio, caso.intero(9, 17), caso.intero(0, 59))
    s = dict(esito='completata', completata=None, pianificata=None, cessata=None,
             moroso=False, disdetta=None, rivenditore=None, richiesta=richiesta)
    s['passi'], s['lavoro'], s['completata'] = percorso(caso, richiesta, 'completata')
    indirizzo = scegli_indirizzo(caso, indirizzi, ('normale',), famiglia)
    offerta = scegli_offerta(caso, famiglia, indirizzo, richiesta)
    linea = nuova_linea(cliente, indirizzo, offerta, s)
    linea['attivazione'] = nuova_attivazione(caso, linea, s, cliente['rivenditore'])
    return linea


def cliente_nominato(caso, c, indirizzi):
    richiesta, completata = momento(c['richiesta']), momento(c['completata'])
    indirizzo = [i for i in indirizzi[c['comune']]
                 if i['via'] == c['via'] and i['civico'] == c['civico']][0]
    privato = c['tipo'] == 'privato'
    cliente = dict(id=c['id'], tipo=c['tipo'], nome=c.get('nome'),
                   cognome=c.get('cognome'), ragione=c.get('ragione_sociale'),
                   piva=None, via=c['via'], civico=c['civico'],
                   comune=c['comune'], rivenditore=c['rivenditore'],
                   stato='attivo', dal=richiesta.date().isoformat(), note=None,
                   richiesta=richiesta, seq=0, moroso=False, disdetta=None,
                   ospitalita=False, profilo='nominato',
                   telefono='+39 000 000 0%s' % c['id'][-3:])
    cliente['email'] = ((c['nome'] + '.' + c['cognome']) if privato else
                        re.sub(r' S\.n\.c\.$', '', c['ragione_sociale'])).lower().replace(' ', '.') + '@example.org'
    s = dict(esito='completata', completata=completata, pianificata=None,
             cessata=None, moroso=False, disdetta=None, rivenditore=None,
             richiesta=richiesta)
    s['passi'], s['lavoro'], s['completata'] = percorso(caso, richiesta, 'completata', completata)
    linea = nuova_linea(cliente, indirizzo, c['offerta'], s)
    linea.update(id=c['linea'], mac=c['mac'], ipv4=c['ipv4'], ipv6=c['ipv6'])
    linea['attivazione'] = nuova_attivazione(caso, linea, s, c['rivenditore'])
    linea['servizi'] = [dict(codice=cod, quantita=q, dal=linea['attiva_dal'], al=None)
                        for cod, q in sorted(c['servizi'])]
    return cliente, linea


def servizi_linea(caso, linea, cliente):
    if linea['attiva_dal'] is None:
        return []
    scelti = []
    if OFFERTA[linea['offerta']]['famiglia'] == 'Business':
        if caso.prob(0.6):
            scelti.append(('IP_STATICO', 1))
        if caso.prob(0.3):
            scelti.append(('VOIP_INTERNO', caso.intero(2, 10)))
        if cliente['ospitalita'] and caso.prob(0.7):
            scelti.append(('HOTSPOT_WIFI', 1))
    else:
        if caso.prob(0.3 if cliente['tipo'] == 'privato' else 0.5):
            scelti.append(('LINEA_VOCE', 1))
        if caso.prob(0.04):
            scelti.append(('IP_STATICO', 1))
    attiva = data(linea['attiva_dal'])
    servizi = []
    for codice, quantita in sorted(scelti):
        dal = attiva
        if caso.prob(0.2):
            dal = min(attiva + giorni(caso.intero(30, 400)), dt.date(2026, 8, 31))
        al = linea['cessata_il']
        if al is None and codice == 'LINEA_VOCE' and caso.prob(0.15):
            fine = dal + giorni(caso.intero(90, 700))
            al = fine.isoformat() if fine < dt.date(2026, 8, 31) else None
        if al is not None and al < dal.isoformat():
            continue
        servizi.append(dict(codice=codice, quantita=quantita, dal=dal.isoformat(), al=al))
    return servizi


def genera_clienti(caso, anagrafe, indirizzi, rivenditori):
    nominati, generati, linee = [], [], []
    for c in NOMINATI:
        cliente, linea = cliente_nominato(caso, c, indirizzi)
        nominati.append(cliente)
        linee.append(linea)
    seq = 0
    for nome, *_resto in COMUNI:
        numero = info_comune(nome)[7]
        if numero == 0:
            continue
        speciali = list(SPECIALI.get(nome, ()))
        if len(speciali) > numero:
            raise ErroreGenerazione('troppi clienti speciali a ' + nome)
        for profilo in caso.mescola(speciali + [('normale',)] * (numero - len(speciali))):
            seq += 1
            cliente, nuove = nuovo_cliente(caso, anagrafe, nome, profilo,
                                           indirizzi[nome], rivenditori, seq)
            generati.append(cliente)
            linee.extend(nuove)
    for i, cliente in enumerate(sorted(generati, key=lambda c: (c['richiesta'], c['seq']))):
        cliente['id'] = 'CL-%06d' % (1000 + i)
    nuove = sorted((l for l in linee if 'id' not in l),
                   key=lambda l: (l['richiesta'], l['cliente']['id']))
    for i, linea in enumerate(nuove):
        linea['id'] = 'LN-%06d' % (1000 + i)
    for linea in sorted(linee, key=lambda l: l['id']):
        if linea['cliente']['profilo'] != 'nominato':
            linea['servizi'] = servizi_linea(caso, linea, linea['cliente'])
    clienti = sorted(nominati + generati, key=lambda c: c['id'])
    return clienti, sorted(linee, key=lambda l: l['id'])


def assegna_identificativi_rete(caso, linee):
    """MAC dei CPE installati, IP statici, prefissi IPv6, utenze PPPoE."""
    mac = caso.mescola(range(0x10, 0x100))
    ipv4 = caso.mescola(range(20, 251))
    prefisso = 0x10
    for linea in linee:
        if 'mac' in linea:
            linea['mac'] = '00:00:5e:00:53:%02x' % linea['mac']
            linea['utenza'] = None if linea['accesso'] == 'dhcp' else \
                linea['id'].lower().replace('-', '') + '@' + DOMINIO_PPPOE
            continue
        installata = linea['stato'] in ('attiva', 'sospesa') or linea['attivazione']['stato'] == 'installazione'
        if installata and not mac:
            raise ErroreGenerazione('indirizzi MAC di documentazione esauriti')
        linea['mac'] = '00:00:5e:00:53:%02x' % mac.pop(0) if installata else None
        con_ip = installata and linea['stato'] != 'cessata' and any(
            s['codice'] == 'IP_STATICO' for s in linea['servizi'])
        linea['ipv4'] = '203.0.113.%d' % ipv4.pop(0) if con_ip else None
        linea['ipv6'] = None
        if installata and linea['accesso'] == 'dhcp':
            linea['ipv6'] = '2001:db8:c1a5:%x::/56' % (prefisso << 8)
            prefisso += 1
        linea['utenza'] = None if linea['accesso'] == 'dhcp' else \
            linea['id'].lower().replace('-', '') + '@' + DOMINIO_PPPOE


def cambi_offerta(caso, linee):
    """Tre richieste di passaggio da Casa Fibra 300 a Casa Fibra 1 Giga, in corso."""
    adatte = [l for l in linee if l['offerta'] == 'CASA_FIBRA_300'
              and l['stato'] == 'attiva' and l['cliente']['stato'] == 'attivo']
    attivazioni = []
    for linea, (quando, esito) in zip(sorted(caso.mescola(adatte)[:3], key=lambda l: l['id']),
                                      (('2026-09-02T10:40:00', 'verifica_tecnica'),
                                       ('2026-09-08T16:05:00', 'verifica_tecnica'),
                                       ('2026-09-10T11:25:00', 'richiesta'))):
        s = dict(esito=esito, completata=None, pianificata=None, richiesta=momento(quando))
        s['passi'], s['lavoro'], s['completata'] = percorso(caso, s['richiesta'], esito)
        a = nuova_attivazione(caso, linea, s, linea['cliente']['rivenditore'])
        a.update(tipo='cambio_offerta', offerta='CASA_FIBRA_1G')
        attivazioni.append(a)
    return attivazioni


def numera_attivazioni(attivazioni):
    contatori = {}
    for a in sorted(attivazioni, key=lambda a: (a['richiesta'], a['linea']['id'])):
        anno = a['richiesta'].year
        contatori[anno] = contatori.get(anno, 0) + 1
        a['id'] = 'AT-%d-%04d' % (anno, contatori[anno])
    return sorted(attivazioni, key=lambda a: a['id'])


# --- ticket -----------------------------------------------------------------

PRIORITA = {
    ('guasto', True): (('alta', 60), ('critica', 15), ('media', 25)),
    ('guasto', False): (('media', 55), ('alta', 40), ('critica', 5)),
    ('lentezza', True): (('media', 60), ('alta', 40)),
    ('lentezza', False): (('media', 70), ('alta', 20), ('bassa', 10)),
    ('wifi', True): (('media', 70), ('bassa', 30)),
    ('wifi', False): (('bassa', 60), ('media', 40)),
    ('voce', True): (('alta', 70), ('media', 30)),
    ('voce', False): (('media', 70), ('alta', 30)),
    ('amministrativo', True): (('media', 50), ('bassa', 50)),
    ('amministrativo', False): (('bassa', 70), ('media', 30)),
}
DURATA_MINUTI = {'guasto': (120, 1800), 'lentezza': (240, 5760),
                 'wifi': (30, 2880), 'voce': (60, 2160),
                 'amministrativo': (60, 4320)}


def nuovo_ticket(**campi):
    ticket = dict(cliente=None, linea=None, apparato=None, padre=None,
                  chiuso=None, assegnato=None)
    ticket.update(campi)
    return ticket


def linee_attive_il(linee, giorno, escluse=()):
    s = giorno.isoformat()
    return [l for l in linee if l['attiva_dal'] is not None and l['attiva_dal'] <= s
            and (l['cessata_il'] is None or l['cessata_il'] > s)
            and l['id'] not in escluse]


def in_servizio(linee, giorno, escluse=()):
    """Linee attive di clienti attivi: quelle che telefonano durante un disservizio."""
    return [l for l in linee_attive_il(linee, giorno, escluse)
            if l['stato'] == 'attiva' and l['cliente']['stato'] == 'attivo']


def ha_servizio(linea, codice):
    return any(s['codice'] == codice for s in linea['servizi'])


def business(linea):
    return OFFERTA[linea['offerta']]['famiglia'] == 'Business'


def esito_ticket(caso, aperto, durata):
    """Stato, ultimo aggiornamento e chiusura del ticket alla fine di OGGI."""
    fine = aperto + dt.timedelta(minutes=durata)
    limite = alle(OGGI, 23, 59)
    if fine <= limite:
        if fine.date() <= OGGI - giorni(2):
            return 'chiuso', fine, fine
        return 'risolto', fine, None
    stato = caso.pesato((('aperto', 30), ('in_lavorazione', 50), ('in_attesa_cliente', 20)))
    if stato == 'aperto':
        return stato, aperto, None
    trascorsi = int((limite - aperto).total_seconds() // 60)
    return stato, aperto + dt.timedelta(minutes=int(trascorsi * caso.unif())), None


def ticket_ordinario(caso, linea, giorno):
    cliente, impresa = linea['cliente'], business(linea)
    categoria = caso.pesato((('guasto', 22), ('lentezza', 18), ('wifi', 14),
                             ('voce', 8), ('amministrativo', 30)))
    if categoria == 'voce' and not (ha_servizio(linea, 'LINEA_VOCE')
                                    or ha_servizio(linea, 'VOIP_INTERNO')):
        categoria = 'amministrativo'
    chiave = categoria
    if categoria == 'guasto' and OFFERTA[linea['offerta']]['tecnologia'] == 'FWA':
        chiave = 'guasto_fwa'
    elif categoria == 'voce' and ha_servizio(linea, 'VOIP_INTERNO'):
        chiave = 'voce_centralino'
    oggetto, descrizione = caso.scegli(TESTI[chiave])
    canale = caso.pesato((('telefono', 45), ('email', 20), ('web', 22),
                          ('rivenditore', 8 if cliente['rivenditore'] else 0)))
    if giorno.weekday() >= 5:
        ora = caso.intero(9, 12)
    else:
        ora = caso.intero(7, 22) if canale in ('email', 'web') else caso.intero(8, 18)
    aperto = alle(giorno, ora, caso.intero(0, 59))
    minimo, massimo = DURATA_MINUTI[categoria]
    if categoria == 'guasto' and impresa:
        minimo, massimo = (1560, 4200) if caso.prob(0.15) else (60, 1200)
    stato, aggiornato, chiuso = esito_ticket(caso, aperto, caso.intero(minimo, massimo))
    assegnato = None if stato == 'aperto' and caso.prob(0.5) else caso.scegli(OPERATORI)
    return nuovo_ticket(cliente=cliente,
                        linea=None if categoria == 'amministrativo' else linea,
                        categoria=categoria,
                        priorita=caso.pesato(PRIORITA[(categoria, impresa)]),
                        stato=stato, canale=canale, oggetto=oggetto,
                        descrizione=descrizione, aperto=aperto,
                        aggiornato=aggiornato, chiuso=chiuso, assegnato=assegnato)


def ticket_attivazioni(caso, attivazioni):
    out = []
    for a in attivazioni:
        if a['richiesta'].date() < INIZIO_STORICO or a['stato'] == 'annullata':
            continue
        fine = a['completata'] or alle(OGGI, 18, 0)
        inizio = a['richiesta'] + giorni(3)
        if fine <= inizio or not caso.prob(0.4):
            continue
        minuti = int((fine - inizio).total_seconds() // 60)
        giorno = (inizio + dt.timedelta(minutes=int(minuti * caso.unif()))).date()
        aperto = alle(giorno, caso.intero(9, 17), caso.intero(0, 59))
        if aperto >= fine or aperto <= a['richiesta']:
            continue
        oggetto, descrizione = caso.scegli(TESTI['attivazione'])
        stato, aggiornato, chiuso = esito_ticket(caso, aperto, caso.intero(60, 1440))
        canale = caso.pesato((('telefono', 60), ('email', 25),
                              ('rivenditore', 15 if a['rivenditore'] else 0)))
        out.append(nuovo_ticket(cliente=a['linea']['cliente'], linea=a['linea'],
                                categoria='attivazione', priorita='media',
                                stato=stato, canale=canale, oggetto=oggetto,
                                descrizione=descrizione, aperto=aperto,
                                aggiornato=aggiornato, chiuso=chiuso,
                                assegnato=caso.scegli(OPERATORI)))
    return out


def padre_rete(apparato, categoria, priorita, oggetto, descrizione, aperto, chiuso):
    return nuovo_ticket(apparato=apparato, categoria=categoria, priorita=priorita,
                        stato='chiuso', canale='monitoraggio', oggetto=oggetto,
                        descrizione=descrizione, aperto=aperto, aggiornato=chiuso,
                        chiuso=chiuso, assegnato=NOC)


def figlio(caso, padre, linea, aperto, chiuso, categoria, testo, canale='telefono',
           priorita=None):
    oggetto, descrizione = testo
    return nuovo_ticket(cliente=linea['cliente'], linea=linea, padre=padre,
                        categoria=categoria,
                        priorita=priorita or ('alta' if business(linea) else 'media'),
                        stato='chiuso', canale=canale, oggetto=oggetto,
                        descrizione=descrizione, aperto=aperto, aggiornato=chiuso,
                        chiuso=chiuso, assegnato=caso.scegli(OPERATORI))


def alcune(caso, linee, quante):
    scelte = sorted(caso.mescola(linee)[:quante], key=lambda l: l['id'])
    if len(scelte) < quante:
        raise ErroreGenerazione('linee insufficienti per un disservizio')
    return scelte


def disservizi_settimana(caso, linee, per_id):
    """I cinque disservizi della settimana sintetica, comuni ai tre progetti."""
    out, nominate = [], tuple(n['linea'] for n in NOMINATI)
    g = dt.date(2026, 9, 8)
    p = padre_rete('olt-pergine-01', 'disservizio', 'critica',
                   'Interruzione della fibra sulla porta PON 0/1/3 di olt-pergine-01',
                   'Alle 10:12 il monitoraggio segnala la perdita del segnale su circa 40 ONT '
                   'della porta 0/1/3. Fibra tagliata durante lavori stradali; giunzione '
                   'riparata alle 11:40, linee di nuovo attive.', alle(g, 10, 12), alle(g, 11, 58))
    out.append(p)
    out.append(figlio(caso, p, per_id['LN-000201'], alle(g, 10, 21), alle(g, 11, 52), 'guasto',
                      ('Connessione assente', 'Nessuna connessione da poco dopo le 10; '
                       'la spia della fibra sul modem è rossa.')))
    porta = [l for l in in_servizio(linee, g, nominate)
             if l['apparato'] == 'olt-pergine-01' and l['porta'] == PORTA_PERGINE]
    for (h, m), linea in zip(((10, 16), (10, 27), (10, 33), (10, 41), (10, 58), (11, 9), (11, 24)),
                             alcune(caso, porta, 7)):
        out.append(figlio(caso, p, linea, alle(g, h, m), alle(g, 11, caso.intero(45, 59)),
                          'guasto', caso.scegli((
                              ('Connessione assente', 'Il modem non naviga e la spia della fibra è rossa.'),
                              ('Internet non funziona', "Da circa mezz'ora internet non funziona in tutta la casa."))),
                          canale=caso.scegli(('telefono', 'telefono', 'web'))))
    g = dt.date(2026, 9, 9)
    p = padre_rete('ptp-cles-01', 'disservizio', 'alta',
                   'Perdita di pacchetti intermittente sul ponte radio ptp-cles-01',
                   'Dalle 07:52 il collegamento radio verso Cles perde pacchetti a intervalli e i '
                   'clienti FWA della zona hanno interruzioni. Antenna riallineata alle 16:50, '
                   'collegamento stabile.', alle(g, 7, 52), alle(g, 17, 35))
    out.append(p)
    out.append(figlio(caso, p, per_id['LN-000202'], alle(g, 9, 14), alle(g, 17, 12), 'guasto',
                      ('Connessione che va e viene', 'Da questa mattina il collegamento cade ogni '
                       'pochi minuti e il POS non riesce a collegarsi.')))
    out.append(figlio(caso, p, per_id['LN-000204'], alle(g, 12, 41), alle(g, 17, 28), 'guasto',
                      ('Navigazione a singhiozzo', "La connessione si interrompe più volte all'ora "
                       'da stamattina.'), canale='web'))
    radio = [l for l in in_servizio(linee, g, nominate) if l['apparato'] == 'bts-cles-01']
    for (h, m), canale, linea in zip(((10, 5), (14, 22)), ('telefono', 'email'), alcune(caso, radio, 2)):
        out.append(figlio(caso, p, linea, alle(g, h, m), alle(g, 17, caso.intero(15, 40)), 'guasto',
                          ('Connessione instabile', 'La connessione cade e riparte di continuo.'),
                          canale=canale))
    out.extend(disservizi_fine_settimana(caso, linee, per_id, nominate))
    return out


def disservizi_fine_settimana(caso, linee, per_id, nominate):
    out = []
    g = dt.date(2026, 9, 10)
    p = padre_rete('bng-trento-01', 'manutenzione', 'media',
                   'Manutenzione programmata su bng-trento-01 (10/09, 02:00-02:30)',
                   'Aggiornamento del software del BNG. Nella finestra le sessioni PPPoE cadono e '
                   'si riconnettono da sole; clienti avvisati via e-mail il 03/09.',
                   momento('2026-09-03T15:20:00'), alle(g, 2, 46))
    out.append(p)
    casa = [l for l in in_servizio(linee, g, nominate) if l['accesso'] == 'pppoe']
    for (h, m), linea in zip(((7, 40), (8, 15)), alcune(caso, casa, 2)):
        out.append(figlio(caso, p, linea, alle(g, h, m),
                          alle(g, h, m) + dt.timedelta(minutes=22), 'guasto',
                          ('Connessione assente da stanotte', 'Questa mattina il modem non '
                           'navigava; dopo averlo riavviato funziona.'), priorita='bassa'))
    g = dt.date(2026, 9, 11)
    p = padre_rete('sbc-trento-01', 'disservizio', 'alta',
                   'Registrazioni SIP fallite su sbc-trento-01',
                   'Dalle 08:04 gli interni del centralino cloud non riescono a registrarsi. '
                   'Servizio SIP riavviato alle 10:40, registrazioni regolari.',
                   alle(g, 8, 4), alle(g, 10, 47))
    out.append(p)
    out.append(figlio(caso, p, per_id['LN-000203'], alle(g, 8, 31), alle(g, 10, 52), 'voce',
                      ('Centralino fuori uso', "Nessun telefono dell'ufficio funziona: gli "
                       'apparecchi mostrano «non registrato».')))
    voip = [l for l in in_servizio(linee, g, nominate) if ha_servizio(l, 'VOIP_INTERNO')]
    for (h, m), canale, linea in zip(((8, 50), (9, 12)), ('email', 'telefono'), alcune(caso, voip, 2)):
        out.append(figlio(caso, p, linea, alle(g, h, m), alle(g, 10, caso.intero(50, 59)), 'voce',
                          ('Interni del centralino non registrati', 'Da questa mattina gli interni '
                           'non chiamano e non ricevono.'), canale=canale))
    g = dt.date(2026, 9, 12)
    p = padre_rete(None, 'disservizio', 'alta',
                   'Pool DHCP esaurito sulla VLAN business di Rovereto',
                   'I clienti business di Rovereto in DHCP non ottengono un indirizzo per i nuovi '
                   'dispositivi: il pool della VLAN è esaurito. Pool ampliato e durata dei lease '
                   'ridotta alle 10:55.', alle(g, 9, 26), alle(g, 11, 2))
    out.append(p)
    dhcp = [l for l in in_servizio(linee, g, nominate)
            if l['accesso'] == 'dhcp' and l['indirizzo']['comune'] == 'Rovereto']
    for (h, m), canale, linea in zip(((9, 5), (9, 18)), ('telefono', 'email'), alcune(caso, dhcp, 2)):
        out.append(figlio(caso, p, linea, alle(g, h, m), alle(g, 11, caso.intero(0, 12)), 'guasto',
                          ('Nuovi dispositivi senza indirizzo IP', 'I computer accesi questa mattina '
                           'non ottengono un indirizzo; quelli già accesi funzionano.'),
                          canale=canale))
    return out


def disservizi_passati(caso, linee):
    out, nominate = [], tuple(n['linea'] for n in NOMINATI)
    g = dt.date(2025, 11, 21)
    p = padre_rete('olt-trento-01', 'disservizio', 'critica',
                   'Guasto di alimentazione su olt-trento-01',
                   'Scheda di alimentazione guasta: linee in fibra di Trento, Lavis e '
                   'Mezzolombardo senza servizio dalle 10:05 alle 13:40.',
                   alle(g, 10, 5), alle(g, 13, 52))
    out.append(p)
    trento = [l for l in in_servizio(linee, g, nominate) if l['apparato'] == 'olt-trento-01']
    for (h, m), linea in zip(((10, 12), (10, 20), (10, 41), (11, 30)), alcune(caso, trento, 4)):
        out.append(figlio(caso, p, linea, alle(g, h, m), alle(g, 13, caso.intero(45, 59)), 'guasto',
                          ('Connessione assente', 'Internet non funziona da questa mattina.')))
    g = dt.date(2026, 2, 3)
    p = padre_rete('ptp-cles-01', 'disservizio', 'alta',
                   'Degrado del ponte radio verso Cles per la neve',
                   'Neve accumulata sulle antenne del ponte radio: collegamento degradato fino '
                   'alla pulizia del 04/02 alle 11:30.', alle(g, 6, 40),
                   momento('2026-02-04T11:48:00'))
    out.append(p)
    radio = [l for l in in_servizio(linee, g, nominate) if l['apparato'] == 'bts-cles-01']
    radio = sorted(radio, key=lambda l: (not business(l), l['id']))[:3]
    for (h, m), linea in zip(((7, 35), (8, 10), (9, 2)), radio):
        out.append(figlio(caso, p, linea, alle(g, h, m),
                          momento('2026-02-04T11:%02d:00' % caso.intero(40, 59)), 'guasto',
                          ('Connessione molto lenta', 'Da questa mattina la connessione è '
                           'lentissima e a tratti assente.')))
    return out


def ticket_particolari(caso, linee):
    """Segnalazioni amministrative e ticket rimasti in attesa del cliente."""
    out = []
    adatte = [l for l in linee_attive_il(linee, dt.date(2026, 1, 1))
              if l['offerta'] == 'CASA_FIBRA_1G' and not l['servizi']
              and l['cliente']['stato'] == 'attivo' and l['cliente']['profilo'] != 'nominato'
              and len([x for x in linee if x['cliente'] is l['cliente']]) == 1]
    linea = alcune(caso, adatte, 1)[0]
    out.append(nuovo_ticket(cliente=linea['cliente'], categoria='amministrativo',
                            priorita='bassa', stato='chiuso', canale='email',
                            oggetto='Totale della fattura diverso dal pagamento',
                            descrizione='Il totale sulla copia della fattura {fattura:2026-02} '
                                        "ricevuta via e-mail è di un centesimo più alto dell'importo pagato.",
                            aperto=momento('2026-03-09T09:40:00'),
                            aggiornato=momento('2026-03-11T12:05:00'),
                            chiuso=momento('2026-03-11T12:05:00'),
                            assegnato=caso.scegli(OPERATORI)))
    out.append(nuovo_ticket(categoria='amministrativo', priorita='media',
                            stato='in_lavorazione', canale='rivenditore',
                            oggetto='Provvigioni di agosto da verificare',
                            descrizione='Il rivenditore RV-003 segnala che le provvigioni di agosto '
                                        'non corrispondono alle attivazioni completate nel mese.',
                            aperto=momento('2026-09-04T10:20:00'),
                            aggiornato=momento('2026-09-07T09:30:00'),
                            assegnato='Elena Modello'))
    for giorno, linea in zip(('2026-08-05', '2026-08-12', '2026-08-19'),
                             alcune(caso, [l for l in linee_attive_il(linee, OGGI)
                                           if not business(l) and l['stato'] == 'attiva'
                                           and l['cliente']['profilo'] != 'nominato'], 3)):
        aperto = alle(data(giorno), caso.intero(9, 17), caso.intero(0, 59))
        out.append(nuovo_ticket(cliente=linea['cliente'], linea=linea, categoria='lentezza',
                                priorita='media', stato='in_attesa_cliente', canale='telefono',
                                oggetto='Velocità inferiore al profilo',
                                descrizione='In attesa che il cliente ripeta lo speed test via cavo.',
                                aperto=aperto, aggiornato=aperto + giorni(1),
                                assegnato=caso.scegli(OPERATORI)))
    return out


def genera_ticket(caso, linee, attivazioni):
    per_id = {l['id']: l for l in linee}
    nominate = tuple(n['linea'] for n in NOMINATI)
    ticket = []
    giorno = INIZIO_STORICO
    while giorno <= OGGI:
        pesi = ((0, 70), (1, 25), (2, 5)) if giorno.weekday() >= 5 else \
            ((0, 38), (1, 36), (2, 19), (3, 7))
        quanti = caso.pesato(pesi)
        settimana = giorno >= OGGI - giorni(6)
        if settimana:  # più chiamate; i nominati solo nei ticket dei disservizi
            quanti += caso.intero(1, 2)
        attive = linee_attive_il(linee, giorno, nominate if settimana else ())
        for _ in range(quanti):
            ticket.append(ticket_ordinario(caso, caso.scegli(attive), giorno))
        giorno += giorni(1)
    ticket.extend(ticket_attivazioni(caso, attivazioni))
    ticket.extend(disservizi_passati(caso, linee))
    ticket.extend(disservizi_settimana(caso, linee, per_id))
    ticket.extend(ticket_particolari(caso, linee))
    for seq, t in enumerate(ticket):
        t['seq'] = seq
    contatori = dict(PRIMO_TICKET)
    for t in sorted(ticket, key=lambda t: (t['aperto'], t['seq'])):
        anno = t['aperto'].year
        t['id'] = 'TK-%d-%05d' % (anno, contatori[anno])
        contatori[anno] += 1
    return sorted(ticket, key=lambda t: t['id'])


# --- fatture, note di credito, provvigioni ----------------------------------

def ultimo_giorno(anno, mese):
    a, m = mese_dopo(anno, mese)
    return dt.date(a, m, 1) - giorni(1)


def voci_linea(linea, anno, mese):
    """Voci di una linea in un mese, come calcola_importo_linea() del listino."""
    offerta = OFFERTA[linea['offerta']]
    periodo = '%04d-%02d' % (anno, mese)
    attiva, cessata = linea['attiva_dal'], linea['cessata_il']
    giorni_canone, voce = GIORNI_MESE_LISTINO, 'canone'
    descrizione = '%s - canone %s %d' % (offerta['nome'], MESI[mese - 1], anno)
    if attiva and attiva[:7] == periodo:
        giorni_canone = GIORNI_MESE_LISTINO - int(attiva[8:10]) + 1
        voce = 'rateo'
        descrizione = '%s - canone dal %s (%d gg)' % (offerta['nome'], data_it(attiva), giorni_canone)
    if cessata and cessata[:7] == periodo:
        giorni_canone = int(cessata[8:10])
        voce = 'rateo'
        descrizione = '%s - canone fino al %s (%d gg)' % (offerta['nome'], data_it(cessata), giorni_canone)
    importo = offerta['canone'] * giorni_canone // GIORNI_MESE_LISTINO
    voci = [(voce, descrizione, 1, importo, importo)]
    if attiva and attiva[:7] == periodo:
        voci.append(('attivazione', 'Contributo di attivazione ' + offerta['nome'], 1,
                     offerta['attivazione'], offerta['attivazione']))
    for s in linea['servizi']:
        if s['dal'] <= periodo + '-31' and (s['al'] is None or s['al'] >= periodo + '-01'):
            prezzo, quantita = PREZZO_SERVIZIO[s['codice']], s['quantita']
            nome = NOME_SERVIZIO[s['codice']] + (' x%d' % quantita if quantita > 1 else '')
            voci.append(('servizio', nome, quantita, prezzo, prezzo * quantita))
    if linea['offerta'] == 'CASA_RADIO' and attiva and attiva[:4] == '2025':
        mesi = (anno - int(attiva[:4])) * 12 + mese - int(attiva[5:7])
        if 1 <= mesi <= 12:
            voci.append(('sconto', 'Promo Radio 2025 (%d/12)' % mesi, 1, -500, -500))
    return voci


def arrotonda(numeratore, denominatore):
    """Arrotondamento a metà lontano da zero, come round() di PHP sugli interi."""
    segno = -1 if numeratore < 0 else 1
    return segno * ((abs(numeratore) * 2 + denominatore) // (2 * denominatore))


def documento(cliente, tipo, periodo, emessa, righe, iva, rif=None):
    imponibile = sum(r['importo'] for r in righe)
    return dict(cliente=cliente, tipo=tipo, periodo=periodo, emessa=emessa,
                scade=emessa + giorni(GIORNI_SCADENZA), imponibile=imponibile,
                iva=iva(imponibile), totale=imponibile + iva(imponibile),
                righe=righe, rif=rif)


def fatture_mensili(linee):
    fatture = []
    for anno, mese in MESI_FATTURATI:
        periodo = '%04d-%02d' % (anno, mese)
        fine = ultimo_giorno(anno, mese)
        per_cliente = {}
        for linea in linee:
            if linea['attiva_dal'] is not None and linea['attiva_dal'] <= fine.isoformat() \
                    and (linea['cessata_il'] is None or linea['cessata_il'] >= periodo + '-01'):
                per_cliente.setdefault(linea['cliente']['id'], []).append(linea)
        for cid in sorted(per_cliente):
            righe = []
            for linea in per_cliente[cid]:
                for voce, descrizione, quantita, prezzo, importo in voci_linea(linea, anno, mese):
                    righe.append(dict(linea=linea, voce=voce, descrizione=descrizione,
                                      quantita=quantita, prezzo=prezzo, importo=importo))
            fatture.append(documento(per_cliente[cid][0]['cliente'], 'fattura', periodo,
                                     fine + giorni(1), righe,
                                     lambda imp: int(imp * ALIQUOTA_IVA / 100)))
    return fatture


def note_di_credito(fatture, ticket):
    """Indennizzi ai clienti aziende per i guasti chiusi oltre le 24 ore."""
    per_chiave = {(f['cliente']['id'], f['periodo']): f for f in fatture}
    note = []
    for anno, mese in MESI_FATTURATI:
        periodo = '%04d-%02d' % (anno, mese)
        per_cliente = {}
        for t in ticket:
            c = t['cliente']
            if c is None or c['tipo'] != 'azienda' or t['categoria'] != 'guasto' \
                    or t['stato'] != 'chiuso' or iso(t['chiuso'])[:7] != periodo:
                continue
            ore = (secondi_utc(iso(t['chiuso'])) - secondi_utc(iso(t['aperto']))) / 3600
            if ore <= 24:
                continue
            gg = int(math.ceil((ore - 24) / 24))
            importo = min(1000 * gg, 10000)
            per_cliente.setdefault(c['id'], (c, []))[1].append(dict(
                linea=t['linea'], voce='indennizzo', quantita=1, prezzo=-importo,
                importo=-importo,
                descrizione='Indennizzo disservizio %s (%d gg)' % (t['id'], gg)))
        a, m = mese_dopo(anno, mese)
        for cid in sorted(per_cliente):
            cliente, righe = per_cliente[cid]
            note.append(documento(cliente, 'nota_credito', periodo, dt.date(a, m, 2), righe,
                                  lambda imp: arrotonda(imp * ALIQUOTA_IVA, 100),
                                  per_chiave.get((cid, periodo))))
    return note


def numera_e_incassa(caso, documenti, clienti):
    progressivi = dict(PRIMA_FATTURA)
    for d in sorted(documenti, key=lambda d: (d['emessa'], d['tipo'], d['cliente']['id'])):
        d['id'] = 'FT-%d-%06d' % (d['emessa'].year, progressivi[d['emessa'].year])
        progressivi[d['emessa'].year] += 1
    metodo = {c['id']: 'rid' if caso.prob(0.78) else 'bonifico' for c in clienti}
    for d in sorted(documenti, key=lambda d: d['id']):
        c, pagata = d['cliente'], None
        insoluta = (c['moroso'] and d['periodo'] >= '2026-06') or \
            (c['disdetta'] is not None and d['periodo'] >= c['disdetta'].isoformat()[:7])
        if d['tipo'] == 'fattura' and not insoluta:
            ritardo = 9 if metodo[c['id']] == 'rid' else caso.intero(3, 45)
            pagata = d['emessa'] + giorni(ritardo)
            pagata = pagata if pagata <= OGGI else None
        d['pagata'] = pagata
        if d['tipo'] == 'nota_credito':
            d['stato'] = 'emessa'
        else:
            d['stato'] = 'pagata' if pagata else ('scaduta' if d['scade'] < OGGI else 'emessa')
    return sorted(documenti, key=lambda d: d['id'])


def provvigioni_registrate(attivazioni):
    """Provvigioni dei mesi passati, come le ha registrate provvigioni.inc.php."""
    righe = []
    for anno, mese in MESI_FATTURATI:
        periodo = '%04d-%02d' % (anno, mese)
        conteggi = {}
        for a in attivazioni:
            if a['rivenditore'] and a['stato'] != 'annullata' and iso(a['richiesta'])[:7] == periodo:
                famiglia = OFFERTA[a['linea']['offerta']]['famiglia']
                conteggi.setdefault(a['rivenditore'], {'Casa': 0, 'Business': 0})[famiglia] += 1
        a2, m2 = mese_dopo(anno, mese)
        for rv in sorted(conteggi):
            casa, impresa = conteggi[rv]['Casa'], conteggi[rv]['Business']
            righe.append((rv, periodo, casa, impresa,
                          casa * PROVVIGIONE_LISTINO['Casa'] + impresa * PROVVIGIONE_LISTINO['Business'],
                          '%04d-%02d-02 06:15:00' % (a2, m2),
                          'liquidata' if periodo <= '2026-07' else 'calcolata'))
    return righe


def risolvi_riferimenti(ticket, documenti):
    """Sostituisce {fattura} e {fattura:AAAA-MM} con fatture vere del cliente."""
    for t in ticket:
        if '{fattura' not in t['descrizione']:
            continue
        proprie = [d for d in documenti if d['tipo'] == 'fattura' and d['cliente'] is t['cliente']]
        m = re.search(r'\{fattura(?::(\d{4}-\d{2}))?\}', t['descrizione'])
        if m.group(1):
            scelte = [d for d in proprie if d['periodo'] == m.group(1)]
        else:
            scelte = [d for d in proprie if d['emessa'] <= t['aperto'].date()]
        if scelte:
            t['descrizione'] = t['descrizione'].replace(m.group(0), scelte[-1]['id'])
        else:
            t['oggetto'] = 'Cambio indirizzo e-mail per le fatture'
            t['descrizione'] = 'Chiede di inviare le fatture a un nuovo indirizzo e-mail.'


# --- tabelle e file SQL -----------------------------------------------------

COLONNE = {
    'comuni': ('id', 'nome', 'cap', 'provincia', 'zona'),
    'apparati': ('id', 'ruolo', 'descrizione', 'comune_id', 'ip_gestione', 'uplink_id', 'stato'),
    'copertura': ('id', 'comune_id', 'via', 'civico', 'scala', 'tecnologia',
                  'velocita_max_mbps', 'apparato_id', 'disponibile_dal', 'aggiornata_il'),
    'offerte': ('codice', 'nome', 'famiglia', 'tecnologia', 'download_mbps', 'upload_mbps',
                'canone_cent', 'attivazione_cent', 'in_listino'),
    'servizi': ('codice', 'nome', 'unita', 'canone_cent', 'solo_business'),
    'rivenditori': ('id', 'ragione_sociale', 'referente', 'comune_id', 'email', 'telefono',
                    'partita_iva', 'provvigione_casa_cent', 'provvigione_business_cent',
                    'convenzionato_dal', 'attivo'),
    'clienti': ('id', 'tipo', 'nome', 'cognome', 'ragione_sociale', 'partita_iva', 'email',
                'telefono', 'via', 'civico', 'comune_id', 'rivenditore_id', 'stato',
                'cliente_dal', 'note'),
    'linee': ('id', 'cliente_id', 'offerta_codice', 'copertura_id', 'apparato_id', 'porta',
              'accesso', 'utenza_pppoe', 'mac_cpe', 'ipv4_statico', 'prefisso_ipv6', 'stato',
              'attiva_dal', 'cessata_il'),
    'linee_servizi': ('linea_id', 'servizio_codice', 'quantita', 'dal', 'al'),
    'attivazioni': ('id', 'linea_id', 'tipo', 'offerta_codice', 'rivenditore_id', 'stato',
                    'richiesta_il', 'pianificata_per', 'completata_il', 'aggiornata_il',
                    'tecnico', 'note'),
    'attivazioni_eventi': ('id', 'attivazione_id', 'da_stato', 'a_stato', 'avvenuto_il',
                           'operatore'),
    'ticket': ('id', 'cliente_id', 'linea_id', 'apparato_id', 'padre_id', 'categoria',
               'priorita', 'stato', 'canale', 'oggetto', 'descrizione', 'aperto_il',
               'aggiornato_il', 'chiuso_il', 'assegnato_a'),
    'fatture': ('id', 'cliente_id', 'tipo', 'periodo', 'emessa_il', 'scade_il',
                'imponibile_cent', 'iva_cent', 'totale_cent', 'stato', 'pagata_il',
                'rif_fattura_id'),
    'righe_fattura': ('id', 'fattura_id', 'linea_id', 'voce', 'descrizione', 'quantita',
                      'prezzo_unitario_cent', 'importo_cent'),
    'provvigioni': ('id', 'rivenditore_id', 'periodo', 'attivazioni_casa',
                    'attivazioni_business', 'importo_cent', 'calcolata_il', 'stato'),
}
FILE = (
    ('01_comuni.sql', 'comuni', ('comuni',)),
    ('02_rete.sql', 'apparati e copertura per indirizzo', ('apparati', 'copertura')),
    ('03_catalogo.sql', 'offerte e servizi aggiuntivi', ('offerte', 'servizi')),
    ('04_rivenditori.sql', 'rivenditori', ('rivenditori',)),
    ('05_clienti.sql', 'clienti', ('clienti',)),
    ('06_linee.sql', 'linee e loro servizi aggiuntivi', ('linee', 'linee_servizi')),
    ('07_attivazioni.sql', 'attivazioni e passaggi di stato', ('attivazioni', 'attivazioni_eventi')),
    ('08_ticket.sql', 'ticket di assistenza', ('ticket',)),
    ('09_fatture.sql', 'fatture, note di credito e loro righe', ('fatture', 'righe_fattura')),
    ('10_provvigioni.sql', 'provvigioni dei rivenditori', ('provvigioni',)),
)


def opz(valore, funzione):
    return None if valore is None else funzione(valore)


def righe_rete(indirizzi, id_comune):
    tutti = [i for nome in indirizzi for i in indirizzi[nome]]
    tutti.sort(key=lambda i: (id_comune[i['comune']], i['via'], int(i['civico']),
                              i['scala'], i['tecnologia']))
    copertura = []
    for n, i in enumerate(tutti, 1):
        i['id'] = n
        copertura.append((n, id_comune[i['comune']], i['via'], i['civico'], i['scala'],
                          i['tecnologia'], i['velocita'], i['apparato'], i['dal'],
                          i['aggiornata']))
    apparati = [(a[0], a[1], a[2], id_comune[a[3]], a[4], a[5], 'in_servizio')
                for a in APPARATI]
    return apparati, copertura


def righe_attivazioni(attivazioni):
    att = [(a['id'], a['linea']['id'], a['tipo'], a['offerta'], a['rivenditore'],
            a['stato'], iso(a['richiesta']), opz(a['pianificata'], dt.date.isoformat),
            opz(a['completata'], iso), iso(a['aggiornata']), a['tecnico'], a['note'])
           for a in attivazioni]
    passi = sorted(((quando, a['id'], k, da, verso, chi)
                    for a in attivazioni if a['richiesta'].date() >= INIZIO_STORICO
                    for k, (da, verso, quando, chi) in enumerate(a['passi'])),
                   key=lambda e: (e[0], e[1], e[2]))
    eventi = [(n, e[1], e[3], e[4], iso(e[0]), e[5]) for n, e in enumerate(passi, 1)]
    return att, eventi


def righe_documenti(documenti):
    fatture, righe = [], []
    for d in documenti:
        fatture.append((d['id'], d['cliente']['id'], d['tipo'], d['periodo'],
                        d['emessa'].isoformat(), d['scade'].isoformat(), d['imponibile'],
                        d['iva'], d['totale'], d['stato'], opz(d['pagata'], dt.date.isoformat),
                        opz(d['rif'], lambda f: f['id'])))
        for r in d['righe']:
            righe.append((len(righe) + 1, d['id'], opz(r['linea'], lambda l: l['id']),
                          r['voce'], r['descrizione'], r['quantita'], r['prezzo'], r['importo']))
    return fatture, righe


def tabelle(indirizzi, rivenditori, clienti, linee, attivazioni, ticket, documenti, provvigioni):
    id_comune = {riga[0]: i for i, riga in enumerate(COMUNI, 1)}
    apparati, copertura = righe_rete(indirizzi, id_comune)
    att, eventi = righe_attivazioni(attivazioni)
    fatture, righe = righe_documenti(documenti)
    return {
        'comuni': [(i, r[0], r[1], 'TN', r[2]) for i, r in enumerate(COMUNI, 1)],
        'apparati': apparati, 'copertura': copertura,
        'offerte': list(OFFERTE), 'servizi': list(SERVIZI),
        'rivenditori': [(r['id'], r['ragione'], r['referente'], id_comune[r['comune']],
                         r['email'], r['telefono'], r['piva'], r['casa'], r['business'],
                         r['dal'], r['attivo']) for r in rivenditori],
        'clienti': [(c['id'], c['tipo'], c['nome'], c['cognome'], c['ragione'], c['piva'],
                     c['email'], c['telefono'], c['via'], c['civico'], id_comune[c['comune']],
                     c['rivenditore'], c['stato'], c['dal'], c['note']) for c in clienti],
        'linee': [(l['id'], l['cliente']['id'], l['offerta'], l['indirizzo']['id'],
                   l['apparato'], l['porta'], l['accesso'], l['utenza'], l['mac'], l['ipv4'],
                   l['ipv6'], l['stato'], l['attiva_dal'], l['cessata_il']) for l in linee],
        'linee_servizi': [(l['id'], s['codice'], s['quantita'], s['dal'], s['al'])
                          for l in linee for s in l['servizi']],
        'attivazioni': att, 'attivazioni_eventi': eventi,
        'ticket': [(t['id'], opz(t['cliente'], lambda c: c['id']),
                    opz(t['linea'], lambda l: l['id']), t['apparato'],
                    opz(t['padre'], lambda p: p['id']), t['categoria'], t['priorita'],
                    t['stato'], t['canale'], t['oggetto'], t['descrizione'], iso(t['aperto']),
                    iso(t['aggiornato']), opz(t['chiuso'], iso), t['assegnato'])
                   for t in ticket],
        'fatture': fatture, 'righe_fattura': righe,
        'provvigioni': [(n,) + p for n, p in enumerate(provvigioni, 1)],
    }


def valore_sql(valore):
    if valore is None:
        return 'NULL'
    if isinstance(valore, bool):
        raise ErroreGenerazione('valore booleano nei dati: usare 0 o 1')
    if isinstance(valore, int):
        return str(valore)
    return "'" + valore.replace("'", "''") + "'"


def testo_sql(titolo, nomi, dati):
    righe = ['-- Dati di esempio del gestionale CiaspoLink: %s.' % titolo,
             '-- Generato da genera.py (seme %d): non modificare a mano, rigenerare.' % SEME,
             '']
    for nome in nomi:
        valori = dati[nome]
        for inizio in range(0, len(valori), RIGHE_PER_INSERT):
            blocco = valori[inizio:inizio + RIGHE_PER_INSERT]
            righe.append('INSERT INTO %s (%s) VALUES' % (nome, ', '.join(COLONNE[nome])))
            for k, riga in enumerate(blocco):
                fine = ');' if k == len(blocco) - 1 else '),'
                righe.append('(' + ', '.join(valore_sql(v) for v in riga) + fine)
            righe.append('')
    return '\n'.join(righe).rstrip('\n') + '\n'


def genera():
    """Costruisce tutti i dati; restituisce (tabelle, {file: testo})."""
    caso_rete, caso_clienti, caso_ticket, caso_fatture = (Caso(SEME * 10 + k) for k in range(1, 5))
    anagrafe = Anagrafe(caso_clienti)
    indirizzi = genera_copertura(caso_rete)
    rivenditori = genera_rivenditori(anagrafe)
    clienti, linee = genera_clienti(caso_clienti, anagrafe, indirizzi, rivenditori)
    assegna_identificativi_rete(caso_rete, linee)
    attivazioni = numera_attivazioni([l['attivazione'] for l in linee]
                                     + cambi_offerta(caso_clienti, linee))
    ticket = genera_ticket(caso_ticket, linee, attivazioni)
    fatture = fatture_mensili(linee)
    documenti = numera_e_incassa(caso_fatture, fatture + note_di_credito(fatture, ticket),
                                 clienti)
    risolvi_riferimenti(ticket, documenti)
    dati = tabelle(indirizzi, rivenditori, clienti, linee, attivazioni, ticket, documenti,
                   provvigioni_registrate(attivazioni))
    for nome, righe in dati.items():
        if any(len(r) != len(COLONNE[nome]) for r in righe):
            raise ErroreGenerazione('righe di %s con un numero di colonne sbagliato' % nome)
    return dati, {f: testo_sql(titolo, nomi, dati) for f, titolo, nomi in FILE}


# --- controlli sul proprio output -------------------------------------------

RE_EMAIL = re.compile(r'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+')
RE_PREFISSO = re.compile(r'\+\d{2}(?= ?\d{3})')       # +39 000…, +41 044… (non +02:00)
RE_TELEFONO = re.compile(r'\+39 00\d \d{3} \d{4}(?!\d)')
RE_IPV4 = re.compile(r'(?<![\d.])\d{1,3}(?:\.\d{1,3}){3}(?![\d.])')
RE_IPV6 = re.compile(r'[0-9A-Fa-f:]*::[0-9A-Fa-f:/]*')
RE_MAC = re.compile(r'(?<![0-9A-Fa-f:])[0-9A-Fa-f]{2}(?::[0-9A-Fa-f]{2}){5}(?![0-9A-Fa-f:])')
RE_DATA = re.compile(r"'(\d{4}-\d{2}-\d{2}[^']*)'")
FORMATI_ID = {
    'clienti': r'CL-\d{6}', 'linee': r'LN-\d{6}', 'attivazioni': r'AT-\d{4}-\d{4}',
    'ticket': r'TK-\d{4}-\d{5}', 'fatture': r'FT-\d{4}-\d{6}', 'rivenditori': r'RV-\d{3}',
    'apparati': r'(olt|bng|ptp|bts|sbc)-[a-z]+-\d{2}',
}


def controlla_testo(testo, errori):
    for m in RE_EMAIL.finditer(testo):
        if not re.match(r'^([a-z0-9.]+@example\.org|ln\d{6}@ciaspolink\.example\.org)$',
                        m.group(0)):
            errori.append('e-mail fuori dalle regole: ' + m.group(0))
    for m in RE_PREFISSO.finditer(testo):
        if not RE_TELEFONO.match(testo, m.start()):
            errori.append('telefono fuori dalle regole: ' + testo[m.start():m.start() + 16])
    for m in RE_IPV4.finditer(testo):
        if not m.group(0).startswith(('192.0.2.', '198.51.100.', '203.0.113.')):
            errori.append('IPv4 fuori dagli intervalli di documentazione: ' + m.group(0))
    for m in RE_IPV6.finditer(testo):
        if not m.group(0).startswith('2001:db8:'):
            errori.append('IPv6 fuori da 2001:db8::/32: ' + m.group(0))
    for m in RE_MAC.finditer(testo):
        if not m.group(0).lower().startswith('00:00:5e:00:53:'):
            errori.append('MAC fuori da 00:00:5e:00:53:xx: ' + m.group(0))
    for m in RE_DATA.finditer(testo):
        valore = m.group(1)
        if re.match(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}[+-]\d{2}:\d{2}$', valore):
            if valore[19:] != offset_roma(data(valore), int(valore[11:13])):
                errori.append('offset del fuso sbagliato: ' + valore)
        elif not re.match(r'^\d{4}-\d{2}-\d{2}( \d{2}:\d{2}:\d{2})?$', valore):
            errori.append('data in un formato inatteso: ' + valore)


def colonna(dati, tabella, nome):
    i = COLONNE[tabella].index(nome)
    return [r[i] for r in dati[tabella]]


def controlla_identita(dati, errori):
    for tabella, formato in FORMATI_ID.items():
        for valore in colonna(dati, tabella, 'id'):
            if not re.match('^' + formato + '$', valore):
                errori.append('identificativo fuori formato in %s: %s' % (tabella, valore))
    nominati = set(n['id'] for n in NOMINATI) | set(n['linea'] for n in NOMINATI)
    for valore in colonna(dati, 'clienti', 'id') + colonna(dati, 'linee', 'id'):
        if valore not in nominati and int(valore[3:]) < 1000:
            errori.append('identificativo generato sotto 1000: ' + valore)
    for r in dati['clienti']:
        if r[1] == 'privato' and (r[2] not in NOMI or r[3] not in COGNOMI):
            errori.append('nome fuori dalle liste: %s %s' % (r[2], r[3]))
        if r[1] != 'privato' and not any(x in r[4].lower() for x in RADICI):
            errori.append('ragione sociale non riconoscibile come inventata: ' + r[4])
    for r in dati['rivenditori']:
        nome, cognome = r[2].split(' ')
        if nome not in NOMI or cognome not in COGNOMI or not any(x in r[1].lower() for x in RADICI):
            errori.append('rivenditore fuori dalle regole: %s, %s' % (r[1], r[2]))
    for valore in colonna(dati, 'clienti', 'partita_iva') + colonna(dati, 'rivenditori', 'partita_iva'):
        if valore is None:
            continue
        cifre = [int(c) for c in valore] if re.match(r'^\d{11}$', valore) else None
        if cifre is None or cifra_controllo_piva(cifre[:10]) == cifre[10]:
            errori.append('partita IVA non conforme (serve la cifra di controllo sbagliata): ' + valore)
    persone = set(OPERATORI) | set(TECNICI) | {NOC, COLLAUDO, 'web', None} | \
        set(colonna(dati, 'rivenditori', 'id'))
    for valore in (colonna(dati, 'ticket', 'assegnato_a') + colonna(dati, 'attivazioni', 'tecnico')
                   + colonna(dati, 'attivazioni_eventi', 'operatore')):
        if valore not in persone:
            errori.append('persona sconosciuta: %s' % valore)


def controlla_storia(dati, errori):
    clienti = {r[0]: r for r in dati['clienti']}
    linee = {r[0]: r for r in dati['linee']}
    for n in NOMINATI:
        c, l = clienti.get(n['id']), linee.get(n['linea'])
        atteso = (n.get('nome'), n.get('cognome'), n.get('ragione_sociale'))
        if c is None or (c[2], c[3], c[4]) != atteso or (c[8], c[9]) != (n['via'], n['civico']):
            errori.append('cliente della storia comune diverso dal previsto: ' + n['id'])
        if l is None or (l[1], l[2], l[5], l[11]) != (n['id'], n['offerta'], n['porta'], 'attiva'):
            errori.append('linea della storia comune diversa dal prevista: ' + n['linea'])
    giu = [l for l in dati['linee'] if l[4] == 'olt-pergine-01' and l[5] == PORTA_PERGINE
           and l[12] is not None and l[12] <= '2026-09-08' and l[11] == 'attiva'
           and (l[13] is None or l[13] > '2026-09-08')]
    if len(giu) != LINEE_PORTA_PERGINE:
        errori.append('linee attive sulla porta 0/1/3 di olt-pergine-01: %d invece di %d'
                      % (len(giu), LINEE_PORTA_PERGINE))
    ticket = dati['ticket']
    padri = {}
    for apparato, inizio in (('olt-pergine-01', '2026-09-08T10:12'), ('ptp-cles-01', '2026-09-09T07:52'),
                             ('bng-trento-01', '2026-09-03T15:20'), ('sbc-trento-01', '2026-09-11T08:04'),
                             (None, '2026-09-12T09:26')):
        trovati = [t for t in ticket if t[3] == apparato and t[11].startswith(inizio) and t[8] == 'monitoraggio']
        if len(trovati) != 1:
            errori.append('disservizio mancante: %s %s' % (apparato, inizio))
        else:
            padri[inizio] = trovati[0][0]
    for linea, inizio in (('LN-000201', '2026-09-08T10:12'), ('LN-000202', '2026-09-09T07:52'),
                          ('LN-000204', '2026-09-09T07:52'), ('LN-000203', '2026-09-11T08:04')):
        if not any(t[2] == linea and t[4] == padri.get(inizio) for t in ticket):
            errori.append('ticket collegato al disservizio mancante per ' + linea)


def controlla_integrita(testi, errori):
    connessione = sqlite3.connect(':memory:')
    try:
        with open(FILE_SCHEMA, encoding='utf-8') as f:
            connessione.executescript(f.read())
        connessione.execute('PRAGMA foreign_keys = OFF')
        for nome in sorted(testi):
            connessione.executescript(testi[nome])
        for riga in connessione.execute('PRAGMA foreign_key_check').fetchall()[:10]:
            errori.append('riferimento non valido: %s' % (riga,))
        esito = connessione.execute('PRAGMA integrity_check').fetchone()[0]
        if esito != 'ok':
            errori.append('integrità SQLite: ' + esito)
    except sqlite3.Error as e:
        errori.append('i dati non si caricano nello schema: %s' % e)
    finally:
        connessione.close()


def verifica(dati, testi):
    errori = []
    for nome in sorted(testi):
        controlla_testo(testi[nome], errori)
    controlla_identita(dati, errori)
    controlla_storia(dati, errori)
    controlla_integrita(testi, errori)
    if errori:
        raise ErroreGenerazione('%d controlli falliti:\n  %s' % (len(errori), '\n  '.join(errori[:30])))


# --- scrittura e confronto --------------------------------------------------

def scrivi(testi, cartella):
    os.makedirs(cartella, exist_ok=True)
    for nome in sorted(testi):
        with open(os.path.join(cartella, nome), 'w', encoding='utf-8', newline='\n') as f:
            f.write(testi[nome])


def confronta(nuova, attuale):
    """0 se le due cartelle hanno gli stessi file .sql identici, 1 altrimenti."""
    def elenco(cartella):
        if not os.path.isdir(cartella):
            return []
        return sorted(f for f in os.listdir(cartella) if f.endswith('.sql'))
    diversi = []
    for nome in sorted(set(elenco(nuova)) | set(elenco(attuale))):
        percorsi = (os.path.join(nuova, nome), os.path.join(attuale, nome))
        if not all(os.path.isfile(p) for p in percorsi):
            diversi.append(nome + ' (manca da una delle due parti)')
            continue
        with open(percorsi[0], 'rb') as a, open(percorsi[1], 'rb') as b:
            if a.read() != b.read():
                diversi.append(nome)
    if diversi:
        print('genera.py --check: dati diversi da quelli rigenerati: ' + ', '.join(diversi),
              file=sys.stderr)
        return 1
    print('genera.py --check: %d file identici in database/dati/' % len(elenco(nuova)))
    return 0


def main():
    parser = argparse.ArgumentParser(
        description='Genera i dati di esempio del gestionale CiaspoLink in database/dati/.')
    parser.add_argument('--check', action='store_true',
                        help='rigenera in una cartella temporanea e confronta (0 identici, 1 diversi, 2 errore)')
    argomenti = parser.parse_args()
    try:
        dati, testi = genera()
        verifica(dati, testi)
        if argomenti.check:
            with tempfile.TemporaryDirectory() as cartella:
                scrivi(testi, cartella)
                return confronta(cartella, CARTELLA_DATI)
        scrivi(testi, CARTELLA_DATI)
        for vecchio in sorted(os.listdir(CARTELLA_DATI)):
            if vecchio.endswith('.sql') and vecchio not in testi:
                os.remove(os.path.join(CARTELLA_DATI, vecchio))
    except ErroreGenerazione as e:
        print('genera.py: ' + str(e), file=sys.stderr)
        return 2
    except (OSError, sqlite3.Error) as e:
        print('genera.py: errore: %s' % e, file=sys.stderr)
        return 2
    for nome in ('clienti', 'linee', 'attivazioni', 'ticket', 'fatture', 'righe_fattura'):
        print('%-14s %5d righe' % (nome, len(dati[nome])))
    print('scritti %d file in %s' % (len(testi), os.path.relpath(CARTELLA_DATI)))
    return 0


if __name__ == '__main__':
    sys.exit(main())
