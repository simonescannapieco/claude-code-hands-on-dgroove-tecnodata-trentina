<!-- Generato da genera.py a partire da gc-02-router-dopo-manutenzione.json: modifica il JSON e rigenera. -->

# GC-02 · Dopo la manutenzione notturna: un passo guidato, la verifica, la chiusura

| campo | valore |
|---|---|
| scenario | SC-04 |
| canale | chat |
| inizio | 2026-09-10 07:48 |
| ticket | TK-2026-04424 |
| passaggio a un operatore | no |

## Conversazione

**Cliente**

> Ciao, stamattina non va internet: sul router la luce Internet è spenta. Ieri sera andava benissimo.

**Assistente**

> Ciao! Controllo subito la tua linea. Mi scrivi il codice cliente e l'e-mail che hai registrato con noi?

**Cliente**

> CL-000106, giulia.fittizio@example.org

*Strumento* `verifica_identita` con `{"id_cliente": "CL-000106", "contatto": "giulia.fittizio@example.org"}`

```json
{
  "esito": "riconosciuto",
  "id_cliente": "CL-000106",
  "nome": "Giulia Fittizio",
  "tipo": "privato",
  "linee": [
    "LN-000206"
  ]
}
```

*Strumento* `stato_linea` con `{"id_linea": "LN-000206"}`

```json
{
  "id_linea": "LN-000206",
  "stato": "attiva",
  "dettaglio": "ONT registrato, segnale ottico regolare",
  "sessione": {
    "tipo": "PPPoE",
    "attiva": false,
    "ultima_disconnessione": "2026-09-10T02:04:12+02:00"
  },
  "manutenzione": {
    "descrizione": "manutenzione programmata della rete, annunciata per e-mail la settimana prima",
    "inizio": "2026-09-10T02:00:00+02:00",
    "fine": "2026-09-10T02:30:00+02:00",
    "stato": "conclusa"
  }
}
```

*Strumento* `apri_ticket` con `{"id_cliente": "CL-000106", "id_linea": "LN-000206", "categoria": "assenza_connessione", "priorita": "media", "oggetto": "Nessuna connessione dopo la manutenzione notturna", "descrizione": "Router senza connessione dopo la manutenzione programmata della notte; linea e fibra regolari, sessione non ripartita."}`

```json
{
  "id_ticket": "TK-2026-04424",
  "stato": "aperto"
}
```

**Assistente**

> Grazie Giulia. Stanotte tra le 2 e le 2:30 c'è stata una manutenzione programmata della nostra rete, annunciata per e-mail la settimana scorsa: la fibra arriva regolarmente, ma il tuo router non si è ricollegato. Spegnilo per 30 secondi e riaccendilo, poi scrivimi quando hai fatto.

**Cliente**

> Fatto, l'ho spento e riacceso.

*Strumento* `stato_linea` con `{"id_linea": "LN-000206"}`

```json
{
  "id_linea": "LN-000206",
  "stato": "attiva",
  "sessione": {
    "tipo": "PPPoE",
    "attiva": true,
    "dalle": "2026-09-10T08:01:40+02:00"
  }
}
```

**Assistente**

> Perfetto: la connessione risulta di nuovo attiva dalle 8:01. Prova pure a navigare.

**Cliente**

> Ora va! Grazie.

*Strumento* `aggiorna_ticket` con `{"id_ticket": "TK-2026-04424", "stato": "chiuso", "nota": "Router non ricollegato dopo la manutenzione notturna; risolto con il riavvio guidato, connessione verificata alle 08:02."}`

```json
{
  "id_ticket": "TK-2026-04424",
  "stato": "chiuso"
}
```

**Assistente**

> Bene! Riepilogo: dopo la manutenzione di stanotte il router non si era ricollegato; l'abbiamo riavviato e la linea è attiva. Ho chiuso la segnalazione TK-2026-04424. Se dovesse ricapitare, scrivici qui.

## Esito

Router non ricollegato dopo la manutenzione notturna annunciata: un solo passo guidato, verifica della sessione, segnalazione chiusa dall'assistente.

## Punti chiave per la valutazione

- Riconosce la cliente prima di leggere la linea.
- Riconosce la manutenzione conclusa e la sessione non ripartita: non fa controllare cavi e spie inutilmente.
- Chiede un solo passo (riavvio di 30 secondi) e poi verifica davvero la sessione.
- Chiude con un riepilogo e il numero della segnalazione; nessun tecnico prenotato.
- Dà del tu, messaggi brevi.
