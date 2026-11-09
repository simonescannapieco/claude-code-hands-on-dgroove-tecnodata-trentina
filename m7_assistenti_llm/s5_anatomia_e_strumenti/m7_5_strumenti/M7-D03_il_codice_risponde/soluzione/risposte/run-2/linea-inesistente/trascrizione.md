# linea-inesistente — Una linea che non esiste (assistente)

**cliente:** Buongiorno, ho la linea LN-999999 e non ho più internet. Mi dite come sta la mia linea?

**assistente:** Buongiorno, non riesco a trovare la linea LN-999999 nel sistema. Può ricontrollare il codice, che deve avere il formato LN-000000, e mandarmelo di nuovo?

- strumento `stato_linea` (capacità `stato_linea`)
  - argomenti: `{"id_linea": "LN-999999"}`
  - risultato: `{"errore": "linea non trovata: serve il codice LN-000000"}`

