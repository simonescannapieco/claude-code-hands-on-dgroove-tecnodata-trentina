# Rete — materiale del docente

Questa cartella non arriva ai partecipanti (è esclusa dalla copia esportata). Contiene le soluzioni dell'audit e la mappa degli avvenimenti nei log.

## File

| file | che cosa | origine |
|---|---|---|
| `chiave-problemi.tsv` | la chiave dei problemi inseriti: `id, apparato, file, marcatore, occorrenza, categoria, gravita, descrizione` (separatore TAB) | scritto a mano |
| `problemi-inseriti.csv` | la verità di riferimento: `id, apparato, file, riga, categoria, gravita, descrizione, estratto` | generato da `genera.py` |
| `README.md` | questo file | scritto a mano |

`genera.py` legge la chiave, cerca ogni `marcatore` nel file generato (l'`occorrenza`-esima riga che lo contiene), scrive numero di riga ed estratto in `problemi-inseriti.csv` e si ferma con uscita 2 se un marcatore non si trova. Se si cambia il generatore, i numeri di riga si aggiornano da soli; se un marcatore sparisce, la generazione fallisce invece di produrre una verità sbagliata. Senza questa cartella (copia dei partecipanti) il generatore salta la verità di riferimento e `--check` resta verde.

Il codice del generatore è visibile ai partecipanti e contiene i valori delle configurazioni (non la chiave): leggerlo equivale a leggere le configurazioni. La chiave, le categorie assegnate e le descrizioni stanno solo qui.

## I problemi inseriti

40 problemi su 19 apparati (da 1 a 4 per apparato), nelle 16 categorie di `../checklist-audit.md`:

| categoria | quanti | | categoria | quanti |
|---|---|---|---|---|
| AUD-01 SNMP | 5 | | AUD-09 VLAN | 1 |
| AUD-02 gestione in chiaro | 7 | | AUD-10 ACL di gestione | 1 |
| AUD-03 segreti | 6 | | AUD-11 indirizzi duplicati | 1 |
| AUD-04 NTP | 2 | | AUD-12 descrizioni | 2 |
| AUD-05 syslog | 2 | | AUD-13 firmware | 2 |
| AUD-06 fuso orario | 2 | | AUD-14 piano radio | 2 |
| AUD-07 PPPoE MTU/MSS | 2 | | AUD-15 segreto RADIUS | 2 |
| AUD-08 BGP | 1 | | AUD-16 DHCP | 2 |

Due problemi sono «a due capi» e hanno una riga per capo: il segreto RADIUS di `rtr-cles-01` (P19 sull'apparato, P22 in `clients.conf`) e la password locale riutilizzata sui due core (P01, P05). Le gravità sono 18 `alta`, 19 `media`, 3 `bassa`.

Alcuni problemi lasciano tracce anche nei log, utili per esercizi che incrociano configurazione e log:

| problema | traccia |
|---|---|
| P10, P20 syslog verso il collettore dismesso | nessuna riga di `sw-rovereto-01` e di `rtr-cles-01` in `log/syslog/` |
| P11, P34 fuso UTC | le righe di `bdr-trento-01` e di `ptp-cles-01` sono due ore indietro; il collettore le archivia per giorno di ricezione, quindi verso mezzanotte finiscono nel file del giorno «sbagliato» |
| P27 NTP dismesso | `olt-trento-01` deriva fino a ~50 s; `NTP/4/SOURCE_LOST` ogni due ore; allarme `ntp` aperto da martedì |
| P09 indirizzo duplicato | `olt-rovereto-01` segnala `IP_CONFLICT` su 192.0.2.13 ogni 4 ore; il RADIUS ignora l'«unknown client 192.0.2.13» quando il NOC entra in `sw-rovereto-01` |
| P07 native VLAN | `CDP-4-NATIVE_VLAN_MISMATCH` ogni ora da `sw-trento-01` |
| P19/P22 segreto RADIUS | «invalid Message-Authenticator … Shared secret is incorrect» in `log/radius/radius_*.log` a ogni accesso del NOC a `rtr-cles-01` |
| P37, P38 DHCP | l'esaurimento del pool di sabato (sotto) |

## Gli avvenimenti della settimana nei log

Orari in ora italiana (+02:00). Nessun file li etichetta: si ricostruiscono incrociando le sorgenti.

**Martedì 8, 10:12–11:40 — fibra tagliata sulla porta PON 0/1/3 di `olt-pergine-01`** (40 linee FTTH, fra cui LN-000201).
- `log/syslog/syslog_2026-09-08.log`: `GPON/2/PON_LOS` alle 10:12:31, 40 `ONT_OFFLINE … cause LOS` fra 10:12:31 e 10:12:34; `PON_LOS_CLEAR` alle 11:40:04, poi i 40 `ONT_ONLINE` entro un minuto.
- `log/pppoe/bng-trento-01_2026-09-08.log`: 40 «terminating… peer is not responding» fra 10:12:52 e 10:13:04; riconnessioni fra 11:41:10 e 11:45:45.
- `log/radius/accounting_2026-09-08.log`: `Stop` con `Lost-Carrier`, poi `Start`; `radius_2026-09-08.log`: i `Login OK` delle riconnessioni.
- `log/sip/sbc-trento-01_2026-09-08.log`: scadono le registrazioni della voce di LN-000201 e di tre altre linee casa (10:31–10:48).
- `allarmi.csv`: `pon-los` CRITICAL 10:12:45 → RECOVERY 11:41:05; `sessioni-pppoe` WARNING 10:14 (80 su 121) → RECOVERY 11:50 (120 su 121: manca la linea con la password sbagliata, sotto).

**Mercoledì 9, 9:41–17:18 — perdite intermittenti sul ponte radio `ptp-trento-01` ↔ `ptp-cles-01`** (le 24 linee FWA in PPPoE, fra cui LN-000204; LN-000202 è in DHCP con IP statico e si vede negli allarmi di ping).
- `log/syslog/syslog_2026-09-09.log`: 9 episodi «link … lost / established» su `ptp-trento-01` (09:41, 10:27, 11:05, 12:48, 13:36, 14:52, 15:40, 16:21, 17:18) e gli stessi su `ptp-cles-01` con due ore in meno (P34); `airstats` con segnale e capacità degradati fra 09:30 e 17:30; `OSPF-5-ADJCHG` su `core-trento-01` verso 192.0.2.134 per i 6 episodi più lunghi di 40 s.
- `log/pppoe/bng-trento-01_2026-09-09.log`: per i 7 episodi di almeno 20 s le sessioni FWA cadono e si riconnettono (LN-000204 cade 7 volte).
- `allarmi.csv`: `collegamento-radio` su `ptp-cles-01` e `ping-cpe` LN-000202 su `bts-cles-01` a ogni episodio; `segnale-radio` WARNING su `ptp-trento-01` 09:52–17:41.

**Giovedì 10, 02:00–02:30 — manutenzione programmata di `bng-trento-01`** (firmware 7.15.3 → 7.16.2).
- `log/syslog/syslog_2026-09-10.log`: accesso del NOC 01:58:40, pacchetto scaricato 02:02:05, riavvio 02:03:39; su `core-trento-01` e `sw-trento-01` il collegamento va giù alle 02:03:42 e torna alle 02:06:37; «router rebooted» e «installed routeros-7.16.2» alle 02:06:58–59.
- `log/pppoe/bng-trento-01_2026-09-10.log`: nessun «logged out» (le sessioni spariscono col riavvio); `PPPoE server … started` alle 02:07:02, poi 121 riconnessioni fra 02:07:14 e 02:23:02.
- `log/radius/accounting_2026-09-10.log`: `Accounting-On` alle 02:07:07, nessuno `Stop` per le sessioni interrotte, poi i `Start`.
- `allarmi.csv`: `DOWNTIME_START` 02:00, `ping` CRITICAL 02:04 → RECOVERY 02:07, `DOWNTIME_END` 02:30 (121 su 121).

**Venerdì 11, mattina — registrazioni SIP del centralino cloud respinte da `sbc-trento-01`** (fra cui i sei interni di CL-000103).
- `log/sip/sbc-trento-01_2026-09-11.log`: alle 07:52:14 il NOC ricarica il dispatcher e il gruppo 1 punta a `sip:192.0.2.32:5070` (la porta giusta è 5060); due sondaggi falliti (408) e alle 07:53:14 la destinazione è «marked inactive»; dalle 07:54 alle 10:04 ogni REGISTER dei domini `*.pbx.ciaspolink.example.org` riceve 503 (304 per CL-000103); alle 10:04:40 il ripristino, alle 10:05:10 «marked active», dalle 10:05 le registrazioni tornano 200. Le linee voce casa (`voce.ciaspolink.example.org`) non sono toccate: il guasto è solo sul gruppo del centralino.
- `allarmi.csv`: `registrazioni-sip` WARNING 08:04 (9 su 12), CRITICAL 08:29 (5 su 12), RECOVERY 10:07.

**Sabato 12 — pool DHCP esaurito sulla VLAN 312 di Rovereto** (subnet 198.51.100.192/27, pool di 14 indirizzi, 11 linee, lease di 7 giorni: P37, P38).
- `log/dhcp/kea-dhcp4_2026-09-12.log`: dalle 09:10 compaiono 9 MAC nuovi (00:00:5e:00:53:e0–e8); i primi tre ottengono .211, .212, .213 (l'ultimo alle 09:28:29); gli altri sei ricevono `ALLOC_ENGINE_V4_ALLOC_FAIL_SUBNET` a ripetizione fino a sera; domenica di nuovo dalle 10:00 alle 18:55 (`kea-dhcp4_2026-09-13.log`).
- `allarmi.csv`: `pool-dhcp` WARNING 09:15 e 09:23, CRITICAL «pool esaurito» 09:29, mai rientrato.

## Il rumore di fondo

- Accessi del NOC agli apparati nei giorni feriali, a volte con una modifica di configurazione.
- Piccoli guasti di singole linee (circa il 9% delle linee al giorno): ONT in `dying-gasp`, sessioni PPPoE che cadono e tornano, stazioni FWA che si disconnettono.
- Una linea casa, LN-006056, con il router configurato con la password sbagliata: da lunedì 18:22 a martedì 15:12 «authentication failed» ogni 4–7 minuti nel log PPPoE e «Login incorrect» nel RADIUS; martedì alle 15:12:40 il `Login OK`.
- Un flap BGP con il transito B lunedì 23:41–23:44 (in syslog con l'orario UTC di `bdr-trento-01`, negli allarmi con l'ora italiana).
- Allarmi minori: disco del RADIUS mercoledì notte, CPU del BNG venerdì sera, temperatura dell'OLT di Trento domenica.

## Rigenerare

```bash
python3 progetti/rete/genera.py && python3 progetti/rete/genera.py --check
bash tests/test_progetti_rete.sh
```

Per cambiare un problema inserito: si modifica il generatore (`generatore/`), si aggiorna la riga della chiave, si rigenera e si fanno girare i test.
