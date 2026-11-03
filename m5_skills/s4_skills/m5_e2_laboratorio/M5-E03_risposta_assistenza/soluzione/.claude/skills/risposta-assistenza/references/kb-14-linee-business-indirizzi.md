# KB-14 · Linee business: indirizzi IP e DHCP

| | |
|---|---|
| per chi | clienti business, in fibra e via radio |
| canali | assistenza guidata, operatore, servizi IT |
| vedi anche | KB-11 guasti collettivi · KB-05 router del cliente · KB-06 centralino |

## Quando si usa

Il router o il firewall dell'azienda non ottiene l'indirizzo dalla linea, un server non è più raggiungibile sull'indirizzo statico, l'azienda ha cambiato apparato o chiede indirizzi in più.

## Come funziona, in breve

- Le linee business **non usano nome utente e password**: il router o il firewall dell'azienda riceve l'indirizzo dalla nostra rete in automatico (DHCP).
- Con l'opzione **IP statico** l'indirizzo è riservato all'apparato dell'azienda, riconosciuto dal suo indirizzo MAC.
- Un apparato **nuovo** ha un indirizzo MAC diverso: con l'IP statico va comunicato, altrimenti la rete non gli assegna l'indirizzo riservato.

## Prima di tutto

1. Riconosci il cliente (KB-15): uno dei referenti registrati.
2. **Controlla se c'è un guasto in zona** (KB-11): un problema nell'assegnazione degli indirizzi in un'area coinvolge più aziende insieme.
3. Controlla lo stato della linea e se l'apparato dell'azienda ha un indirizzo assegnato.

## Che cosa chiedere

- L'apparato è nuovo o è stato sostituito di recente? Se sì, il suo indirizzo MAC (è sull'etichetta).
- L'apparato vecchio è ancora disponibile?
- Il problema riguarda tutta la rete dell'ufficio o un solo servizio (un server, una telecamera)?

## Passi guidati

1. **Apparato nuovo senza indirizzo, linea regolare, nessun guasto in zona:** se c'è l'IP statico, aggiorna il MAC associato (o passa ai servizi IT, se l'assistenza non può farlo); poi far riavviare l'apparato.
2. **Guasto in zona nell'assegnazione degli indirizzi:** collega la segnalazione al guasto. Soluzione temporanea: se l'apparato vecchio funziona ancora, **ricollegarlo**: il suo indirizzo è ancora assegnato e torna a navigare.
3. **Server non raggiungibile sull'indirizzo statico:** verificare che l'indirizzo sia ancora assegnato all'apparato giusto; le regole del firewall del cliente le controlla il cliente.
4. Non si chiede mai all'azienda di impostare a mano un indirizzo «a caso»: gli indirizzi li assegna la rete.

## Quando passare a un operatore

- Apparato nuovo che non ottiene l'indirizzo dopo il passo 1: servizi IT.
- Richiesta di indirizzi in più: commerciale.
- Più aziende della stessa zona con lo stesso problema e nessun guasto aperto: operatore, che avvisa i tecnici di rete.

## Che cosa dire

> Stamattina sulla rete business della vostra zona sono finiti gli indirizzi per i nuovi apparati: è un guasto nostro e i tecnici ci stanno lavorando. Se avete ancora il router di prima, ricollegandolo tornate a navigare subito.

## Note

- Gli indirizzi MAC e IP di un cliente non si comunicano ad altri.
