<!-- Generato da genera.py a partire da gc-04-wifi-debole-mesh.json: modifica il JSON e rigenera. -->

# GC-04 · Non è un guasto: consigli sul Wi-Fi e ricontatto commerciale senza insistere

| campo | valore |
|---|---|
| scenario | SC-12 |
| canale | chat |
| inizio | 2026-09-13 17:32 |
| ticket | TK-2026-04550 |
| passaggio a un operatore | no |

## Conversazione

**Cliente**

> Ciao! In camera al secondo piano il Wi-Fi prende pochissimo, al piano terra invece va benissimo. È un problema della linea?

**Assistente**

> Ciao! Vediamo subito. Per controllare la linea mi scrivi il codice cliente e l'e-mail che hai registrato?

**Cliente**

> CL-005004, chiara.modello@example.org

*Strumento* `verifica_identita` con `{"id_cliente": "CL-005004", "contatto": "chiara.modello@example.org"}`

```json
{
  "esito": "riconosciuto",
  "id_cliente": "CL-005004",
  "nome": "Chiara Modello",
  "tipo": "privato",
  "linee": [
    "LN-005004"
  ]
}
```

*Strumento* `stato_linea` con `{"id_linea": "LN-005004"}`

```json
{
  "id_linea": "LN-005004",
  "stato": "attiva",
  "dettaglio": "linea regolare; ultimo speed test dal router 930 Mbit/s"
}
```

**Assistente**

> Grazie Chiara. La linea è a posto: al router arrivano 930 Mbit/s, quindi il problema è il Wi-Fi, che fatica a salire fino al secondo piano. Dov'è il router?

**Cliente**

> Il router è in soggiorno, al piano terra, dentro un mobile.

*Strumento* `cerca_kb` con `{"domanda": "Wi-Fi debole ai piani superiori"}`

```json
[
  {
    "id": "KB-03",
    "titolo": "Il Wi-Fi di casa e i sistemi mesh",
    "estratto": "In alto, in un punto centrale della casa, fuori da mobili chiusi… i dispositivi lontani vanno sulla 2,4 GHz."
  }
]
```

**Assistente**

> Il mobile frena parecchio il segnale. Prova così:
>
> 1. sposta il router fuori dal mobile, il più in alto possibile;
> 2. in camera collega il telefono alla rete a 2,4 GHz, che arriva più lontano della 5 GHz.
>
> Poi dimmi come va.

**Cliente**

> L'ho spostato sopra il mobile: va un po' meglio ma non abbastanza. Il mesh quanto costa?

**Assistente**

> Con tre piani è normale che un router solo non basti. Un sistema mesh aggiunge uno o due punti di accesso che formano un'unica rete Wi-Fi in tutta la casa: con un punto al primo piano, la camera sarebbe coperta. Abbiamo l'opzione Wi-Fi Casa Mesh, con installazione compresa; prezzo e condizioni te li dà il commerciale. Vuoi che ti faccia ricontattare?

**Cliente**

> Sì, fatemi ricontattare.

*Strumento* `apri_ticket` con `{"id_cliente": "CL-005004", "id_linea": "LN-005004", "categoria": "wifi", "priorita": "bassa", "destinatario": "commerciale", "oggetto": "Wi-Fi debole in camera - interesse per Wi-Fi Casa Mesh", "descrizione": "Linea regolare (930 Mbit/s al router). Wi-Fi debole nella camera al secondo piano; date le indicazioni sulla posizione del router e sulla rete a 2,4 GHz. La cliente chiede di essere ricontattata per il Wi-Fi Casa Mesh.", "ricontatto": {"recapito": "registrato", "quando": "lunedì in mattinata"}}`

```json
{
  "id_ticket": "TK-2026-04550",
  "stato": "aperto",
  "assegnata_a": "commerciale"
}
```

**Assistente**

> Fatto: richiesta TK-2026-04550. Il commerciale lavora dal lunedì al venerdì, quindi ti ricontatta lunedì in mattinata ai recapiti che hai registrato. Intanto il router fuori dal mobile e la rete a 2,4 GHz in camera ti aiutano già. Buona serata!

## Esito

Linea regolare, Wi-Fi debole al secondo piano: consigli dalla base di conoscenza, spiegazione neutrale del sistema mesh senza prezzi inventati, ricontatto commerciale fissato con un orario vero.

## Punti chiave per la valutazione

- Verifica la linea prima di parlare di Wi-Fi: non è un guasto e lo dice.
- Dà consigli pratici, un passo alla volta, presi dalla base di conoscenza.
- Spiega il mesh in modo neutrale e non inventa il prezzo: lo darà il commerciale.
- Il ricontatto è fissato con il consenso della cliente e con un orario reale (lunedì), non «a breve».
- Non apre guasti né prenota tecnici; dà del tu.
