# Rete — configurazioni, log e inventario di CiaspoLink

La rete dell'operatore immaginario **CiaspoLink S.r.l.** (vedi `../README.md`): fibra fino a casa e accesso radio (FWA) nelle valli del Trentino, PPPoE con autenticazione RADIUS per le linee casa, DHCP per le linee business, SIP per la voce e il centralino cloud. Tutto è **sintetico**: apparati, indirizzi, clienti e avvenimenti sono inventati e seguono le regole dei dati sintetici di `../README.md`.

Qui trovate quello che un team di rete ha sotto mano ogni giorno: le configurazioni degli apparati, una settimana di log, l'inventario, gli allarmi del monitoraggio e la checklist con cui il team controlla le configurazioni.

## Che cosa c'è

| percorso | che cosa contiene | origine |
|---|---|---|
| `configurazioni/` | le configurazioni dei 19 apparati, salvate dal backup settimanale di domenica 13 settembre 2026 alle 23:50 | generato |
| `log/syslog/` | il syslog degli apparati di rete raccolto dal collettore centrale, un file per giorno | generato |
| `log/pppoe/` | le sessioni PPPoE del concentratore `bng-trento-01`, un file per giorno | generato |
| `log/radius/` | `radius_<giorno>.log` (autenticazioni) e `accounting_<giorno>.log` (inizio, aggiornamento e fine delle sessioni) | generato |
| `log/dhcp/` | il log del server DHCPv4 delle linee business | generato |
| `log/sip/` | il log dell'SBC SIP `sbc-trento-01` | generato |
| `inventario.csv` | l'inventario degli apparati | generato |
| `allarmi.csv` | gli allarmi del monitoraggio nella settimana | generato |
| `checklist-audit.md` | la checklist del team: le categorie di problemi che un audit delle configurazioni controlla e gli standard di riferimento | scritto a mano |
| `README.md` | questo file | scritto a mano |
| `genera.py`, `generatore/` | il generatore che produce tutti i file «generato» | scritto a mano |

I file generati non si modificano a mano: si cambia il generatore e si rigenera.

## Gli apparati e i loro dialetti

Ogni configurazione è scritta in un dialetto che un operatore radio e fibra usa davvero. La sintassi è **ispirata** a quella del sistema indicato e semplificata: non è l'output esatto di alcun apparato o software.

| dialetto | apparati | file |
|---|---|---|
| in stile Cisco IOS-XE | `core-trento-01`, `core-rovereto-01` | `<apparato>.cfg` |
| in stile Cisco IOS (switch) | `sw-trento-01`, `sw-rovereto-01` | `<apparato>.cfg` |
| in stile Juniper Junos | `bdr-trento-01` | `bdr-trento-01.conf` |
| in stile MikroTik RouterOS | `bng-trento-01`, `rtr-pergine-01`, `rtr-cles-01`, `bts-cles-01` | `<apparato>.rsc` |
| in stile CLI di OLT GPON (telaio/scheda/porta) | `olt-trento-01`, `olt-pergine-01`, `olt-rovereto-01` | `<apparato>.cfg` |
| in stile Ubiquiti airOS | `ptp-trento-01`, `ptp-cles-01`, `bts-cavareno-01` | `<apparato>/system.cfg` |
| in stile FreeRADIUS | `radius-trento-01` | `clients.conf`, `authorize` |
| in stile ISC Kea DHCPv4 | `dhcp-trento-01` | `kea-dhcp4.conf` |
| in stile Kamailio | `sbc-trento-01` | `kamailio.cfg`, `dispatcher.list` |
| in stile Asterisk PJSIP | `pbx-trento-01` | `pjsip.conf` |

I nomi seguono lo schema `<ruolo>-<comune>-<nn>`. In sintesi la rete è fatta così:

- **Trento** è il POP principale: router di bordo con due transiti (AS64496 e AS64497; l'operatore è AS64500), router di core, concentratore PPPoE (BNG), switch di aggregazione, server RADIUS e DHCP, SBC e centralino cloud, l'OLT di Trento.
- **Pergine Valsugana**: un router di valle e un OLT GPON, collegati a Trento in fibra.
- **Rovereto**: un router di aggregazione, uno switch e un OLT che serve anche una dorsale verso Riva del Garda; il collegamento con Trento è una fibra dedicata.
- **Val di Non**: un ponte radio punto-punto (`ptp-trento-01` ↔ `ptp-cles-01`) porta il traffico a Cles, dove un router di valle alimenta la stazione radio base a tre settori `bts-cles-01` e, via fibra di zona, quella di Cavareno.

### Piano di indirizzamento

| rete | uso |
|---|---|
| 192.0.2.0/26 | VLAN 999 di gestione (gateway 192.0.2.62); 192.0.2.43 è il collettore syslog e il monitoraggio, 192.0.2.44 e .45 i server NTP, 192.0.2.50 la postazione del NOC |
| 192.0.2.64/27 | collegamenti punto-punto fra router (/31) |
| 192.0.2.128/27 | loopback dei router |
| 198.51.100.0/25, 198.51.100.128/26 | pool degli indirizzi delle sessioni PPPoE |
| 198.51.100.192/27 | linee business con indirizzo dinamico, VLAN 312 (Rovereto) |
| 198.51.100.224/27 | linee business con indirizzo dinamico, VLAN 210 (Trento) |
| 203.0.113.0/26 | linee business con indirizzo statico, VLAN 300 |
| 203.0.113.64/27 | servizi: SBC 203.0.113.70, DNS 203.0.113.80 e .81 |
| 203.0.113.128/30, 203.0.113.132/30 | collegamenti con i due transiti |
| 2001:db8:c1a5::/48 | l'aggregato IPv6 dell'operatore |

VLAN: 100–103 sessioni PPPoE (Trento, Pergine, Rovereto, Val di Non) · 210, 300, 312 linee business · 902, 903 transito verso i router di valle · 999 gestione.

## I log della settimana

La settimana va da lunedì 7 a domenica 13 settembre 2026; in Italia vale l'ora legale (UTC+2). Ogni sorgente scrive nel proprio formato:

| sorgente | formato di una riga |
|---|---|
| `log/syslog/syslog_<giorno>.log` | `2026-09-08T10:12:31+02:00 <apparato> <messaggio nel formato dell'apparato>` |
| `log/pppoe/bng-trento-01_<giorno>.log` | `2026-09-08 10:12:52 pppoe,ppp,info <messaggio>` |
| `log/radius/radius_<giorno>.log` | `Tue Sep  8 11:41:03 2026 : Auth: (<n>) Login OK: [<utenza>] (from client <nas> port <n> cli <MAC>)` |
| `log/radius/accounting_<giorno>.log` | `2026-09-08T11:41:03+02:00 Acct-Status-Type=Start User-Name=… Acct-Session-Id=… …` |
| `log/dhcp/kea-dhcp4_<giorno>.log` | `2026-09-12 09:28:29.198 INFO  [kea-dhcp4.leases/…] DHCP4_LEASE_ALLOC …` |
| `log/sip/sbc-trento-01_<giorno>.log` | `2026-09-11T07:52:14+02:00 sbc-trento-01 kamailio[2318]: INFO: …` |

Due avvertenze, come nella realtà:

- nel syslog l'orario è quello **dichiarato dall'apparato**, mentre il collettore divide i file per giorno di **ricezione**: un apparato con l'orologio sbagliato lascia righe con orari fuori posto;
- un apparato che non manda il syslog al collettore giusto semplicemente non compare.

Nei log trovate il rumore di fondo di una settimana qualunque (accessi del NOC, piccoli guasti delle singole linee, rinnovi DHCP, registrazioni SIP) e alcuni avvenimenti più seri: trovarli, datarli e ricostruirli fa parte delle esercitazioni.

## Inventario e allarmi

- `inventario.csv`: `apparato, ruolo, descrizione, comune, sito, dialetto, modello, firmware, ip_gestione, ipv6_gestione, seriale, data_installazione, rack, uplink, collegamento_fisico, nome_host`. `firmware` è la versione registrata dal team; `uplink` è l'apparato a cui si aggregano i servizi (come nel gestionale; vuoto per il nucleo della rete e per i server); `collegamento_fisico` è l'apparato e la porta a cui l'apparato è collegato. I modelli sono inventati.
- `allarmi.csv`: `timestamp, apparato, gravita, controllo, messaggio, stato`. `gravita` vale CRITICAL, WARNING, OK o INFO; `stato` vale PROBLEM, RECOVERY, DOWNTIME_START o DOWNTIME_END. Un PROBLEM senza RECOVERY è un allarme ancora aperto a fine settimana.

Le sei linee con nome compaiono anche nel gestionale e nell'assistenza clienti (`LN-000201` … `LN-000206`); le altre linee (`LN-006000` e seguenti) esistono solo qui.

## Rigenerare e verificare

Dalla radice del repository (Python 3.8 o successivo, solo libreria standard):

```bash
python3 progetti/rete/genera.py            # rigenera tutti i file generati
python3 progetti/rete/genera.py --check    # rigenera in una cartella temporanea e confronta byte per byte
python3 progetti/rete/genera.py --canone   # controlla le regole dei dati sintetici su ogni file
bash tests/test_progetti_rete.sh           # i test del progetto
```

Uscita: `0` tutto in ordine, `1` file diversi o regole violate, `2` errore. Il seme è fisso: la stessa versione del generatore produce sempre gli stessi byte, con qualunque Python dalla 3.8 in poi.
