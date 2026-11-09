# linea-inesistente — Una linea che non esiste (assistente)

**cliente:** Buongiorno, ho la linea LN-999999 e non ho più internet. Mi dite come sta la mia linea?

**assistente:** Buongiorno, non trovo nessuna linea con il codice LN-999999. Può ricontrollarlo, per esempio sulla fattura o nel contratto? Il formato è LN- seguito da 6 cifre. Appena me lo conferma, verifico lo stato.

- strumento `stato_linea` (capacità `stato_linea`)
  - argomenti: `{"id_linea": "LN-999999"}`
  - risultato: `{"errore": "linea non trovata: serve il codice LN-000000"}`

