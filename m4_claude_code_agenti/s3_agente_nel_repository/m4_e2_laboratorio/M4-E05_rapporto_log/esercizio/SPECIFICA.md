# Il rapporto quotidiano dei disservizi

Ogni mattina il NOC di CiaspoLink, l'operatore inventato del corso (un
progetto sintetico), manda all'assistenza clienti il rapporto dei
disservizi del giorno prima: che cosa si è rotto, dove, da quando a quando,
quante linee ne hanno risentito. Finora lo scrive una persona leggendo i
log; questa è la specifica dello script che lo scrive da sé.

## Il comando

Uno dei due, nella cartella dello spazio di lavoro; lo scegliete voi:

    python3 rapporto_giornaliero.py [--giorno AAAA-MM-GG] [--log <cartella>] [--help]
    bash rapporto_giornaliero.sh [--giorno AAAA-MM-GG] [--log <cartella>] [--help]

| opzione | che cosa fa |
|---|---|
| `--giorno AAAA-MM-GG` | il giorno del rapporto; senza, il giorno prima di quello in cui lo script gira. I log di esempio vanno da lunedì 7 a domenica 13 settembre 2026 |
| `--log <cartella>` | la cartella dei log, con le sottocartelle `syslog/`, `sip/` e `dhcp/`; senza, `progetti/rete/log` accanto allo script |
| `--help` | stampa l'uso, con le opzioni `--giorno` e `--log`, su stdout ed esce con 0 |

## Che cosa legge

Per il giorno G, nella forma AAAA-MM-GG, tre file della cartella dei log,
quelli che il collettore scrive per quel giorno:

- `syslog/syslog_G.log`, il syslog degli apparati di rete;
- `sip/sbc-trento-01_G.log`, il log dell'SBC SIP `sbc-trento-01`;
- `dhcp/kea-dhcp4_G.log`, il log del server DHCP delle linee business,
  `dhcp-trento-01`.

Il formato delle righe di ogni sorgente è in `progetti/rete/README.md`, «I
log della settimana». Se manca uno dei tre file lo script esce con 2: un
rapporto senza tutti i dati non è un giorno tranquillo.

## I cinque tipi di disservizio

Ciascuno ha un messaggio che lo apre e uno che lo chiude. Un disservizio
che si ripete è un disservizio per volta: un ponte radio che cade tre
volte sono tre righe.

| tipo | che cosa | dove e come si riconosce | linee |
|---|---|---|---|
| `fibra` | una porta PON di un OLT perde il segnale ottico | syslog: l'OLT scrive `PON_LOS` con telaio, scheda e porta (`frame`, `slot`, `port`); lo chiude `PON_LOS_CLEAR` della stessa porta | gli ONT di quella porta andati offline con causa LOS (`ONT_OFFLINE … cause LOS`) fra l'apertura e la chiusura, ciascuno contato una volta |
| `radio` | un ponte radio punto-punto perde il collegamento | syslog, apparati `ptp-…`: `link to … lost`; lo chiude `link to … established` dello stesso apparato | `-` |
| `riavvio` | un apparato si riavvia | syslog: una riga con `rebooting`; la chiude `router rebooted` dello stesso apparato | `-` |
| `voce` | l'SBC segna inattiva una destinazione del dispatcher | sip: `destination … (set N) marked inactive`; la chiude `marked active` dello stesso gruppo N, anche se la destinazione è un'altra | `-` |
| `dhcp` | un pool DHCP non ha più indirizzi da dare | dhcp: le righe `ALLOC_ENGINE_V4_ALLOC_FAIL_SUBNET` di una subnet: la prima del giorno lo apre, l'ultima lo chiude | i client rifiutati, ciascun indirizzo MAC contato una volta |

Tutto il resto non entra nel rapporto: per esempio un ONT solo che va
offline per `dying-gasp`, una stazione radio che si disconnette, un'utenza
PPPoE con la password sbagliata, una sessione BGP che cade e torna, gli
accessi del NOC, gli avvisi di NTP.

## L'uscita

Una riga per disservizio su stdout, in ordine di inizio e, a parità, di
apparato, con sei campi separati da un TAB:

| campo | che cosa |
|---|---|
| apparato | il nome dell'apparato che scrive la riga; per `voce` `sbc-trento-01`, per `dhcp` `dhcp-trento-01` |
| porta | per `fibra` telaio/scheda/porta, per esempio `0/1/2`; per `dhcp` la subnet com'è scritta nel log, per esempio `198.51.100.224/27`; altrimenti `-` |
| inizio | ora e minuti del messaggio che lo apre, `HH:MM`, come scritti nella riga (l'orologio dell'apparato), senza i secondi |
| fine | ora e minuti del messaggio che lo chiude; `-` se nel file del giorno non si chiude |
| linee | il numero della colonna «linee» qui sopra, oppure `-` |
| tipo | `fibra`, `radio`, `riavvio`, `voce` o `dhcp` |

Un esempio, con apparati inventati che nei log di esempio non ci sono (fra
un campo e l'altro un TAB):

    olt-levico-01	0/1/2	14:05	14:50	3	fibra
    ptp-levico-01	-	16:20	16:21	-	radio

| uscita | quando |
|---|---|
| 0 | nessun disservizio nel giorno |
| 1 | almeno un disservizio |
| 2 | il rapporto non si può fare: la cartella dei log non c'è, manca uno dei tre file del giorno, `--giorno` non è una data valida, un'opzione sconosciuta |

Su stdout soltanto le righe dei disservizi, senza intestazioni né
riepiloghi; su stderr soltanto i messaggi di errore, con il motivo. Lo
script legge soltanto: non scrive file.

## Come si scrive

- In Python 3.8 o successivo, solo libreria standard: `rapporto_giornaliero.py`;
  oppure in Bash: `rapporto_giornaliero.sh`, con `#!/bin/bash`,
  `set -euo pipefail` e le uscite nel commento in testa. Uno solo dei due,
  nella cartella dello spazio di lavoro.
- L'uso e le uscite nel commento in testa, come negli script del corso.

## Come si prova

`python3 controlla_rapporto.py`, dalla cartella dello spazio di lavoro,
prova lo script su piccole cartelle di log di prova, che crea in una
cartella temporanea: un giorno con un disservizio per tipo e accanto il
rumore di fondo di una settimana qualunque; un giorno tranquillo, con il
rumore soltanto; un giorno senza file; un giorno a cui manca un file.
Esegue lo script in otto casi: `--help`; il giorno con i disservizi; il
giorno tranquillo; la cartella dei log che manca; il giorno senza file;
il file che manca; un giorno non valido; un'opzione sconosciuta. Per ogni
caso confronta uscita, stdout e stderr con questa specifica e stampa `ok`
o `NO` con il motivo; l'ultima riga dice `uscita: 0` se tutto torna,
`uscita: 1` se qualcosa no, `uscita: 2` se il controllo non può girare
(per esempio perché lo script non c'è ancora). Non sa quali disservizi ci
sono nella settimana dei log di esempio: quello lo dice lo script.
