---
name: audit-configurazione
description: Fa l'audit della configurazione di un apparato di rete contro la checklist del team (categorie AUD-01…AUD-16) e l'inventario, e restituisce un report in tabella (apparato, file, riga, categoria, gravità, descrizione, valore atteso) da usare in una finestra di manutenzione, senza modificare nulla. Da usare quando si chiede di controllare, rivedere o fare l'audit di una configurazione, di dire che problemi ha un apparato, se rispetta gli standard o se è in regola, anche per un apparato appena passato di mano, e per router, switch, OLT, stazioni radio, ponti radio e server.
compatibility: Requires Claude Code and Python 3
allowed-tools: Read Bash(python3 ${CLAUDE_SKILL_DIR}/scripts/controlli_ovvi.py *)
disallowed-tools: Edit Write
---

# Audit di una configurazione

L'audit legge e basta: il report va nella risposta, e i file restano come sono, perché una correzione sugli apparati passa da una finestra di manutenzione. Chi legge il report corregge gli apparati riga per riga: ogni voce deve dire dove guardare, che cosa non va e a quale valore portarlo.

## Procedura

Spunta ogni passo prima di passare al seguente:

- [ ] 1. Esegui `python3 ${CLAUDE_SKILL_DIR}/scripts/controlli_ovvi.py progetti/rete <apparato>`, da solo e con il percorso com'è scritto qui: il permesso della skill vale per questo comando e per nessun altro sulla stessa riga. Stampa in TSV i candidati che si trovano senza ragionare: un candidato non è ancora un problema, va visto sulla riga.
- [ ] 2. Leggi `references/checklist-audit.md`: le categorie, lo standard di ciascuna e la gravità.
- [ ] 3. Leggi la configurazione dell'apparato, `progetti/rete/configurazioni/<apparato>.*` o la cartella con quel nome, e la sua riga di `progetti/rete/inventario.csv`.
- [ ] 4. Passa la configurazione contro **tutte le sedici categorie**, una per una, e annota per ciascuna: problema, a posto o «non si applica» (con il motivo, per esempio nessuna sessione BGP). Non fermarti ai primi problemi trovati.
- [ ] 5. Per le categorie che confrontano con altro, leggi solo ciò che serve (vedi la tabella sotto).
- [ ] 6. Scrivi il report con il modello qui sotto, e controlla che ogni numero di riga sia quello del file.

## Che cosa confrontare, categoria per categoria

| categoria | oltre alla configurazione dell'apparato |
|---|---|
| AUD-09, AUD-12 | la configurazione dell'apparato all'altro capo del collegamento (VLAN ammesse, native VLAN, descrizione speculare) |
| AUD-11 | niente da leggere: lo script del passo 1 cerca già l'indirizzo dell'apparato negli altri apparati e gli indirizzi degli altri nella sua configurazione. Giudica le righe stampate (un indirizzo in un'ACL o in un client RADIUS non è un duplicato). Non aprire altri file e non lanciare ricerche a mano: il permesso della skill non le copre |
| AUD-13 | la colonna del firmware in `inventario.csv` |
| AUD-14 | la tabella del piano radio nella checklist: frequenza, larghezza di canale e potenza, per ogni settore o collegamento. Un valore non scritto in configurazione prende il predefinito del dialetto: se il piano lo vuole esplicito, dillo; se il predefinito coincide, non è un problema |
| AUD-15 | il blocco `client` dell'apparato in `radius-trento-01/clients.conf`. Un segreto cifrato in modo reversibile non va decodificato: se non si può confrontare, scrivilo in «Non verificato» |
| AUD-16 | i pool DHCP e le linee servite dalla VLAN, contate sugli OLT |

Le categorie che non riguardano il tipo di apparato (per esempio PPPoE o BGP su uno switch, radio su un OLT) si segnano «non si applica».

## Modello del report

Apri con una riga di sintesi (apparato, numero di problemi per gravità: conta i problemi, non le righe di tabella), poi la tabella, ordinata per gravità decrescente, con **tutte** le colonne, anche se l'apparato è uno solo:

```markdown
| apparato | file | riga | categoria | gravità | descrizione | valore atteso |
|---|---|---|---|---|---|---|
| sw-esempio-01 | configurazioni/sw-esempio-01.cfg | 17 | AUD-02 | media | server telnet attivo: lo standard ammette solo SSH, HTTPS o NETCONF su SSH | telnet disattivato |
```

Usa i codici e le gravità della checklist. Poi, in questo ordine e solo se hanno contenuto:

1. **Controllate e a posto:** una riga con le categorie senza problemi e, separate, quelle «non si applica».
2. **Non verificato:** che cosa non si è potuto controllare e perché.
3. **Fuori checklist:** una riga ciascuna, che comincia con «Fuori checklist:», solo per un rilievo che chi corregge deve conoscere: un problema su un altro apparato visto leggendolo per un confronto (non entra in tabella, perché non è l'apparato chiesto). Non aprire altri apparati per cercarne, e non annotare ciò che non è un problema, come un valore predefinito innocuo.

Senza problemi, scrivi «Nessun problema trovato» e l'elenco delle categorie controllate.

Chiudi il report senza proporre di correggere: l'audit non modifica niente.

## Esempi

Una riga di configurazione:

```text
snmp-server community public RO
```

La sua riga nel report:

```markdown
| sw-esempio-01 | configurazioni/sw-esempio-01.cfg | 31 | AUD-01 | alta | community SNMP predefinita «public»: lo standard ammette solo SNMPv3 con l'utente monitor | solo SNMPv3, utente monitor (SHA e AES) |
```

Un candidato dello script che resta un candidato: la riga `AUD-02  12  ip http secure-server` parla di HTTPS, che lo standard ammette. Non va nel report.

## Casi limite

- Un problema che riguarda due apparati (VLAN, native VLAN, descrizioni, indirizzi duplicati) si segnala **in tabella su entrambi i file**, ciascuno con la sua riga, anche se l'apparato chiesto è uno solo: chi corregge deve poter aprire la finestra su tutti e due.
- Le configurazioni sono backup datati: non scrivere la data né un avviso sul backup, a meno che la domanda non riguardi lo stato in produzione. Chi legge lo sa già, e la nota non cambia nessuna correzione.
- Un problema su due apparati ha una sola gravità, la stessa su entrambe le righe: la riga dell'altro capo dice che cosa fare lì (anche «niente da cambiare, serve per aprire la finestra»).
- L'apparato chiesto non esiste in `inventario.csv`: dillo e fermati.

## Gotchas

- Le configurazioni sono in dialetti diversi (stile Cisco, MikroTik, Junos, airOS, Huawei): la stessa categoria si legge con parole diverse, quindi la colonna `dialetto` di `inventario.csv` dice che cosa aspettarsi.
- `inventario.csv` è la fonte per l'indirizzo di gestione e per il firmware: se la configurazione dice altro, il problema è nella configurazione.
- Un servizio limitato alla rete di gestione resta fuori standard se è in chiaro (AUD-02): la restrizione d'indirizzo risponde ad AUD-10, non lo sana.
- Un valore dismesso (NTP 192.0.2.244, syslog 192.0.2.243) è un problema anche se c'è un secondo server giusto; un solo server NTP invece di due è un problema a sé.
