---
name: audit-configurazione
description: Controlla la configurazione di un apparato di rete contro la checklist di audit del team, le categorie AUD-01…AUD-16, e riporta i problemi in una tabella, senza modificare nulla. Da usare quando si chiede di controllare, rivedere o fare l'audit di una configurazione, o di dire che problemi ha un apparato.
compatibility: Requires Claude Code and Python 3
allowed-tools: Read Bash(python3 ${CLAUDE_SKILL_DIR}/scripts/controlli_ovvi.py *)
disallowed-tools: Edit Write
---

# Audit di una configurazione

L'audit legge e basta: il report va nella risposta, e i file restano come sono, perché una correzione sugli apparati passa da una finestra di manutenzione.

## Procedura

Spunta ogni passo prima di passare al seguente:

- [ ] 1. Esegui `python3 ${CLAUDE_SKILL_DIR}/scripts/controlli_ovvi.py progetti/rete <apparato>`, da solo e con il percorso com'è scritto qui: il permesso della skill vale per questo comando e per nessun altro sulla stessa riga. Stampa in TSV i candidati che si trovano senza ragionare: un candidato non è ancora un problema, va visto sulla riga.
- [ ] 2. Leggi `references/checklist-audit.md`: le categorie, lo standard di ciascuna e la gravità.
- [ ] 3. Leggi la configurazione dell'apparato, `progetti/rete/configurazioni/<apparato>.*` o la cartella con quel nome, e la sua riga di `progetti/rete/inventario.csv`.
- [ ] 4. Passa la configurazione contro ogni categoria, una per una.
- [ ] 5. Solo dove la categoria confronta due capi (AUD-09, AUD-12, AUD-15), leggi la configurazione dell'altro apparato: gli altri file non servono, e leggerli costa.
- [ ] 6. Scrivi il report con il modello qui sotto, e controlla che ogni numero di riga sia quello del file.

## Modello del report

```markdown
| apparato | file | riga | categoria | gravità | descrizione |
|---|---|---|---|---|---|
| sw-esempio-01 | configurazioni/sw-esempio-01.cfg | 17 | AUD-02 | media | server telnet attivo: lo standard ammette solo SSH, HTTPS o NETCONF su SSH |
```

Usa i codici e le gravità della checklist. Senza problemi, scrivi «Nessun problema trovato» e l'elenco delle categorie controllate.

## Esempi

Una riga di configurazione:

```text
snmp-server community public RO
```

La sua riga nel report:

```markdown
| sw-esempio-01 | configurazioni/sw-esempio-01.cfg | 31 | AUD-01 | alta | community SNMP predefinita «public»: lo standard ammette solo SNMPv3 con l'utente monitor |
```

Un candidato dello script che resta un candidato: la riga `AUD-02  12  ip http secure-server` parla di HTTPS, che lo standard ammette. Non va nel report.

## Casi limite

- Un problema che riguarda due apparati si segnala su entrambi i file, ciascuno con la sua riga.
- L'apparato chiesto non esiste in `inventario.csv`: dillo e fermati.
- Un'osservazione fuori dalle sedici categorie non va in tabella: scrivila sotto, in una riga che comincia con «Fuori checklist:».

## Gotchas

- Le configurazioni sono in dialetti diversi (stile Cisco, MikroTik, Junos, airOS): la stessa categoria si legge con parole diverse, quindi la colonna `dialetto` di `inventario.csv` dice che cosa aspettarsi.
- `inventario.csv` è la fonte per l'indirizzo di gestione e per il firmware: se la configurazione dice altro, il problema è nella configurazione.
