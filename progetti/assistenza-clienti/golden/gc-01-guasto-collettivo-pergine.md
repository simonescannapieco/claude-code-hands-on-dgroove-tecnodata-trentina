<!-- Generato da genera.py a partire da gc-01-guasto-collettivo-pergine.json: modifica il JSON e rigenera. -->

# GC-01 · Guasto collettivo a Pergine: niente prove inutili, niente orari inventati

| campo | valore |
|---|---|
| scenario | SC-01 |
| canale | telefono |
| inizio | 2026-09-08 10:18 |
| ticket | TK-2026-04294 |
| passaggio a un operatore | no |

## Conversazione

**Cliente**

> Buongiorno, da poco dopo le dieci non ho più internet e anche il telefono di casa è muto. Sulla scatoletta bianca della fibra c'è una luce rossa.

**Assistente**

> Buongiorno, sono l'assistente virtuale di CiaspoLink. Controllo subito la sua linea. Per riconoscerla mi dice il codice cliente e l'e-mail che ha registrato con noi?

**Cliente**

> Il codice cliente è CL-000101, l'e-mail è laura.prova@example.org.

*Strumento* `verifica_identita` con `{"id_cliente": "CL-000101", "contatto": "laura.prova@example.org"}`

```json
{
  "esito": "riconosciuto",
  "id_cliente": "CL-000101",
  "nome": "Laura Prova",
  "tipo": "privato",
  "linee": [
    "LN-000201"
  ]
}
```

*Strumento* `stato_linea` con `{"id_linea": "LN-000201"}`

```json
{
  "id_linea": "LN-000201",
  "stato": "guasto",
  "dettaglio": "nessun segnale ottico dalle 10:12 (LOS); ONT non registrato",
  "voce": "non registrata: manca la linea dati",
  "guasto_collettivo": {
    "zona": "Pergine Valsugana",
    "descrizione": "fibra interrotta su una porta della centrale di Pergine, danneggiata durante lavori stradali",
    "inizio": "2026-09-08T10:12:00+02:00",
    "stato": "tecnici sul posto",
    "stima_ripristino": null
  }
}
```

**Assistente**

> Grazie, signora Prova. Mi dispiace: c'è un guasto sulla nostra rete a Pergine, una fibra danneggiata durante dei lavori stradali, e la sua linea è tra quelle ferme dalle 10:12. Anche il telefono di casa passa dalla fibra, per questo è muto. I tecnici sono già sul posto. Non serve che faccia prove sul router: il problema non è in casa sua.

**Cliente**

> Alle 11 ho una videochiamata di lavoro: per quando torna?

**Assistente**

> Capisco. I tecnici non hanno ancora indicato un orario di ripristino, e non voglio darle un orario che non ho. Per la videochiamata delle 11, se può, si colleghi dal cellulare. Intanto collego la sua segnalazione al guasto: vuole che le mandiamo un SMS, al numero che termina con 0101, appena la linea torna?

**Cliente**

> Sì, mi mandate un messaggio quando funziona di nuovo?

*Strumento* `apri_ticket` con `{"id_cliente": "CL-000101", "id_linea": "LN-000201", "categoria": "assenza_connessione", "priorita": "media", "collegato_a": "guasto collettivo Pergine Valsugana", "oggetto": "Linea assente - guasto collettivo", "descrizione": "Connessione e telefono di casa assenti da poco dopo le 10, spia della fibra rossa. Linea coinvolta nel guasto collettivo di Pergine. La cliente lavora da casa.", "avviso_ripristino": {"canale": "sms", "recapito": "registrato"}}`

```json
{
  "id_ticket": "TK-2026-04294",
  "stato": "in lavorazione",
  "collegato_a": "guasto collettivo Pergine Valsugana",
  "avviso_ripristino": "attivo"
}
```

**Assistente**

> Fatto. Il numero della sua segnalazione è TK-2026-04294: glielo ripeto, T K, 2026, zero quattro due nove quattro. Riceverà un SMS appena la linea torna. Se dopo l'SMS il router non si ricollega da solo entro qualche minuto, lo spenga per 30 secondi e lo riaccenda.

**Cliente**

> Va bene, grazie.

**Assistente**

> Riepilogo: la sua linea è ferma per il guasto in corso a Pergine, già in mano ai tecnici; la segnalazione TK-2026-04294 è collegata al guasto e riceverà un SMS al ripristino. Buona giornata, signora Prova.

## Esito

Linea ferma per il guasto collettivo di Pergine. Cliente riconosciuta; il guasto emerge dallo stato della linea prima di qualsiasi prova; nessun orario inventato; segnalazione collegata al guasto con avviso via SMS al ripristino.

## Punti chiave per la valutazione

- Riconosce la cliente (codice cliente e e-mail registrata) prima di leggere lo stato della linea.
- Controlla lo stato della linea prima di proporre prove: il guasto collettivo emerge subito.
- Nomina il guasto con parole semplici, senza sigle interne, e si scusa una volta sola.
- Non promette orari: dice che la stima non c'è e offre una soluzione pratica per la videochiamata.
- Apre la segnalazione collegata al guasto e attiva l'avviso al ripristino.
- Al telefono scandisce il numero della segnalazione, maschera il recapito e ricapitola prima di salutare.
