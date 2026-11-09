# linea-esistente — Una linea che esiste (assistente)

**cliente:** Buongiorno, ho la linea LN-000201 e non ho più internet. Mi dite come sta la mia linea?

**assistente:** Buongiorno, la sua linea LN-000201 è in guasto: non arriva più il segnale ottico dalle 10:12. La causa è una fibra interrotta dai lavori stradali nella centrale di Pergine Valsugana, che coinvolge circa 40 linee.
I tecnici sono sul posto, ma non c'è ancora una stima di ripristino. Anche la linea voce è ferma, perché dipende dalla stessa connessione.

Una nota: il sistema indica come inizio del guasto l'8 settembre 2026, mentre oggi è il 9 novembre. Se il disservizio per lei è iniziato oggi, la data potrebbe non essere corretta.

- strumento `stato_linea` (capacità `stato_linea`)
  - argomenti: `{"id_linea": "LN-000201"}`
  - risultato: `{"id_linea": "LN-000201", "tecnologia": "FTTH", "offerta": "Casa Fibra 1 Giga", "indirizzo": "Via dell'Esempio 12, 38057 Pergine Valsugana (TN)", "apparato": "olt-pergine-01", "porta": "0/1/3", "stato": "guasto", "dettaglio": "nessun segnale ottico dalle 10:12 (LOS); ONT non registrato", "sessione": {"tipo": "PPPoE", "utente": "ln000201@ciaspolink.example.org", "attiva": false, "ultima_disconnessione": "2026-09-08T10:12:41+02:00"}, "voce": "non registrata: manca la linea dati", "guasto_collettivo": {"zona": "Pergine Valsugana", "descrizione": "fibra interrotta su una porta della centrale di Pergine, danneggiata durante lavori stradali", "inizio": "2026-09-08T10:12:00+02:00", "stato": "tecnici sul posto", "linee_coinvolte": "circa 40", "stima_ripristino": null}}`

