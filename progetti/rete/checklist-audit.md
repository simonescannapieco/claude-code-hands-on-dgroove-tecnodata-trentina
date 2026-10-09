# Checklist di audit delle configurazioni

La checklist del team di rete di CiaspoLink: le **categorie di problemi** che un audit delle configurazioni controlla e lo **standard** con cui ogni configurazione va confrontata. Non dice quali apparati hanno quali problemi: trovarli è il lavoro dell'audit.

## Come si usa

Un audit passa ogni file di `configurazioni/` contro ogni categoria e, dove serve, confronta la configurazione con l'inventario (`inventario.csv`) e con la configurazione dell'apparato all'altro capo del collegamento. Per ogni problema trovato riporta:

| campo | esempio di formato |
|---|---|
| apparato | `<ruolo>-<comune>-<nn>` |
| file | il percorso sotto `configurazioni/` |
| riga | il numero della riga che mostra il problema |
| categoria | `AUD-01` … `AUD-16` |
| gravità | `alta`, `media` o `bassa` |
| descrizione | che cosa non va e rispetto a quale standard |

**Gravità.** `alta`: permette un accesso non autorizzato o può interrompere il servizio a molti clienti. `media`: indebolisce la sicurezza, la diagnosi o la capacità, senza danno immediato. `bassa`: rende la rete più difficile da capire e da gestire.

Un problema che riguarda due apparati (per esempio un valore che deve coincidere ai due capi) si segnala su entrambi i file, ciascuno con la sua riga.

## Le categorie

### AUD-01 — SNMP con community predefinite o deboli
**Standard:** solo SNMPv3, utente `monitor` con autenticazione e cifratura (SHA e AES), interrogazioni ammesse solo dalla rete di gestione, trap verso 192.0.2.43. Nessuna community v1/v2c, né predefinita (`public`, `private`) né d'altro nome.

### AUD-02 — Gestione con protocolli in chiaro
**Standard:** gli apparati si gestiscono solo via SSH, HTTPS o NETCONF su SSH. Telnet, HTTP senza TLS e FTP sono disattivati, su ogni tipo di apparato e su ogni interfaccia di gestione.

### AUD-03 — Segreti in chiaro, deboli, predefiniti o riutilizzati
**Standard:** le password degli utenti di gestione sono conservate come hash, mai in chiaro. Nessun valore di fabbrica o di esempio (le credenziali predefinite di un software, i segreti di prova), nessun segreto banale o derivato dal nome del cliente. Mai lo stesso segreto su più apparati o su più utenze, salvo i segreti che per natura coincidono ai due capi di uno stesso collegamento (la chiave di un ponte radio, il segreto fra un apparato e il server RADIUS).

### AUD-04 — NTP mancante o errato
**Standard:** due server, `ntp1.ciaspolink.example.org` (192.0.2.44) e `ntp2.ciaspolink.example.org` (192.0.2.45), e nessun altro. Il vecchio server 192.0.2.244 è dismesso.

### AUD-05 — Destinazione del syslog mancante o errata
**Standard:** un solo collettore, `nms.ciaspolink.example.org` (192.0.2.43), porta UDP 514. Il vecchio collettore 192.0.2.243 è dismesso.

### AUD-06 — Fuso orario errato
**Standard:** ora italiana (Europe/Rome, CET/CEST con il cambio d'ora) su ogni apparato, così che i log si possano confrontare fra loro.

### AUD-07 — MTU e MSS non adatti al PPPoE
**Standard:** sulle sessioni PPPoE MTU e MRU 1492; clamping del TCP MSS attivo (1452), perché i clienti non debbano scoprire da soli la MTU ridotta.

### AUD-08 — BGP senza filtri o senza limite di prefissi
**Standard:** ogni sessione eBGP ha una politica di import che scarta i nostri prefissi e quelli troppo specifici, una politica di export che annuncia solo i nostri aggregati e un limite al numero di prefissi ricevuti.

### AUD-09 — VLAN incoerenti fra due apparati collegati
**Standard:** ai due capi di un collegamento le VLAN ammesse e la native VLAN coincidono. La native VLAN dei trunk resta quella predefinita, se non è concordata ai due capi.

### AUD-10 — ACL di gestione incoerenti o troppo aperte
**Standard:** l'accesso di gestione è ammesso solo dalla rete di gestione 192.0.2.0/26; mai dalle reti dei clienti, mai da qualunque indirizzo.

### AUD-11 — Indirizzi duplicati
**Standard:** ogni indirizzo di gestione è assegnato a un solo apparato e coincide con quello registrato in `inventario.csv`.

### AUD-12 — Descrizioni di interfaccia non veritiere
**Standard:** la descrizione di un'interfaccia o di una porta dice che cosa c'è davvero all'altro capo (apparato e porta). Si verifica con l'indirizzamento, con le VLAN e con la descrizione speculare sull'altro apparato; «riserva» o «non in uso» solo se la porta non serve nessuno.

### AUD-13 — Firmware non allineato all'inventario
**Standard:** la versione software che l'apparato dichiara nella sua configurazione è quella registrata in `inventario.csv`, che è la versione approvata dal team.

### AUD-14 — Parametri radio fuori dal piano
**Standard:** il piano radio del NOC.

| apparato | frequenza (MHz) | larghezza di canale (MHz) | potenza (dBm) |
|---|---|---|---|
| `ptp-trento-01`, `ptp-cles-01` | 5500 | 40 | 20 |
| `bts-cles-01`, settore S1 | 5180 | 20 | 18 |
| `bts-cles-01`, settore S2 | 5220 | 20 | 18 |
| `bts-cles-01`, settore S3 | 5260 | 20 | 18 |
| `bts-cavareno-01` | 5300 | 20 | 18 |

### AUD-15 — Segreto RADIUS diverso fra client e server
**Standard:** il segreto condiviso di ogni apparato che interroga il RADIUS coincide con quello del suo blocco `client` in `radius-trento-01/clients.conf`; ogni apparato ha il suo.

### AUD-16 — DHCP dimensionato male
**Standard:** durata dei lease di un giorno (86400 s) su ogni subnet; ogni pool dinamico lascia libero almeno il 30% degli indirizzi rispetto alle linee che la sua VLAN serve (le linee di una VLAN si contano sugli OLT).
