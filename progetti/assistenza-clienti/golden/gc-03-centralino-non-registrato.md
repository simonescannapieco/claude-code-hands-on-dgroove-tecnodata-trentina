<!-- Generato da genera.py a partire da gc-03-centralino-non-registrato.json: modifica il JSON e rigenera. -->

# GC-03 · Centralino fermo: il guasto della piattaforma e la deviazione d'emergenza

| campo | valore |
|---|---|
| scenario | SC-05 |
| canale | telefono |
| inizio | 2026-09-11 08:29 |
| ticket | TK-2026-04477 |
| passaggio a un operatore | no |

## Conversazione

**Cliente**

> Buongiorno, sono Franco Fittizio della Falegnameria Fittizia: tutti i telefoni dell'ufficio dicono «non registrato» e non entra nessuna chiamata. Internet invece funziona.

**Assistente**

> Buongiorno, signor Fittizio, sono l'assistente virtuale di CiaspoLink. Verifico subito. Per riconoscerla mi dice il codice cliente e l'e-mail registrata dell'azienda?

**Cliente**

> Il codice cliente è CL-000103; la mail registrata è falegnameria.fittizia@example.org.

*Strumento* `verifica_identita` con `{"id_cliente": "CL-000103", "contatto": "falegnameria.fittizia@example.org", "persona": "Franco Fittizio"}`

```json
{
  "esito": "riconosciuto",
  "id_cliente": "CL-000103",
  "nome": "Falegnameria Fittizia S.n.c.",
  "tipo": "azienda",
  "referente_registrato": true,
  "linee": [
    "LN-000203"
  ]
}
```

*Strumento* `stato_linea` con `{"id_linea": "LN-000203"}`

```json
{
  "id_linea": "LN-000203",
  "stato": "attiva",
  "dettaglio": "linea dati regolare",
  "voce": {
    "servizio": "Centralino Cloud",
    "interni": 6,
    "interni_registrati": 0,
    "dettaglio": "registrazioni rifiutate dalla piattaforma voce dalle 08:04"
  },
  "guasto_collettivo": {
    "zona": "tutti i clienti del Centralino Cloud",
    "descrizione": "i telefoni non riescono a registrarsi sulla piattaforma voce",
    "inizio": "2026-09-11T08:04:00+02:00",
    "stato": "tecnici al lavoro",
    "stima_ripristino": null
  }
}
```

*Strumento* `apri_ticket` con `{"id_cliente": "CL-000103", "id_linea": "LN-000203", "categoria": "telefonia_voip", "priorita": "alta", "collegato_a": "guasto piattaforma voce", "oggetto": "Centralino Cloud non registrato", "descrizione": "Tutti e sei gli interni «non registrato», nessuna chiamata in entrata; linea dati regolare. Collegato al guasto della piattaforma voce."}`

```json
{
  "id_ticket": "TK-2026-04477",
  "stato": "in lavorazione",
  "collegato_a": "guasto piattaforma voce"
}
```

**Assistente**

> Grazie. Le spiego che cosa succede: da poco dopo le 8 c'è un problema sulla nostra piattaforma voce, e i telefoni dei clienti del Centralino Cloud non riescono a registrarsi. Non dipende dai vostri apparecchi né dalla vostra rete, quindi non serve riavviare i telefoni. I tecnici ci stanno già lavorando, e ho aperto la sua segnalazione collegata al guasto.

**Cliente**

> Come faccio a non perdere le chiamate dei clienti?

*Strumento* `cerca_kb` con `{"domanda": "deviazione d'emergenza delle chiamate del Centralino Cloud"}`

```json
[
  {
    "id": "KB-06",
    "titolo": "Centralino Cloud: interni «non registrato»",
    "estratto": "Portale del centralino → «Instradamento» → «Deviazione d'emergenza», inserire il numero e salvare. Si disattiva dallo stesso punto quando il servizio torna."
  }
]
```

**Assistente**

> Può deviare le chiamate in arrivo su un cellulare dal portale del centralino. Lei è l'amministratore, quindi può farlo subito: entri nel portale del centralino e apra la voce Instradamento. Mi dica quando c'è.

**Cliente**

> Ci sono.

**Assistente**

> Bene. Ora apra Deviazione d'emergenza, inserisca il numero del cellulare e salvi. Mi dica quando ha fatto.

**Cliente**

> Fatto, ho messo il mio cellulare. Mi richiamate su questo numero quando è a posto? È il +39 003 870 4412.

*Strumento* `aggiorna_ticket` con `{"id_ticket": "TK-2026-04477", "nota": "Deviazione d'emergenza attivata dal cliente sul cellulare. Richiamare al +39 003 870 4412 a guasto risolto."}`

```json
{
  "id_ticket": "TK-2026-04477",
  "stato": "in lavorazione"
}
```

**Assistente**

> Perfetto: da adesso le chiamate verso l'ufficio arrivano sul suo cellulare, e quando il servizio torna la deviazione si toglie dallo stesso punto. La segnalazione è la TK-2026-04477: T K, 2026, zero quattro quattro sette sette. La richiamiamo al numero che termina con 4412 appena il servizio è di nuovo regolare; un orario, per ora, non ce l'ho. Riepilogo: guasto sulla nostra piattaforma voce, chiamate deviate sul suo cellulare, richiamata a guasto risolto. Buon lavoro.

## Esito

Interni del Centralino Cloud non registrati per il guasto della piattaforma voce: referente riconosciuto, segnalazione collegata subito, nessun riavvio inutile, deviazione d'emergenza guidata passo per passo, richiamata a guasto risolto.

## Punti chiave per la valutazione

- Riconosce il referente registrato dell'azienda.
- Trova il guasto della piattaforma voce, apre subito la segnalazione collegata e non fa riavviare i telefoni.
- Guida la deviazione d'emergenza un passo alla volta, con conferma, senza elenchi (telefono).
- Registra nella segnalazione il recapito per la richiamata.
- Non promette orari; scandisce il numero della segnalazione, maschera il recapito e ricapitola.
