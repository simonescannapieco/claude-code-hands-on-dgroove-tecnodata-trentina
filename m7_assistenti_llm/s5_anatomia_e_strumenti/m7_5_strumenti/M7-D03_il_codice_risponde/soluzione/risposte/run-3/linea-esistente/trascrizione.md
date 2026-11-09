# linea-esistente — Una linea che esiste (assistente)

**cliente:** Buongiorno, ho la linea LN-000201 e non ho più internet. Mi dite come sta la mia linea?

**assistente:** La sua linea LN-000201 risulta in guasto: non arriva segnale ottico dalle 10:12. Il motivo è una fibra interrotta nella centrale di Pergine Valsugana, danneggiata durante lavori stradali, e il problema riguarda circa 40 linee.

I tecnici sono già sul posto, ma al momento non c'è una stima di ripristino. Anche la linea voce è ferma, perché dipende dalla stessa connessione.

Un'osservazione sulle date: il sistema registra l'inizio del guasto l'8 settembre 2026, mentre oggi è il 9 novembre. Il dato potrebbe essere un errore di registrazione oppure indicare un guasto aperto da molto tempo. Se la sua interruzione è iniziata oggi, conviene farlo verificare.

- strumento `stato_linea` (capacità `stato_linea`)
  - argomenti: `{"id_linea": "LN-000201"}`
  - risultato: `{"id_linea": "LN-000201", "tecnologia": "FTTH", "offerta": "Casa Fibra 1 Giga", "indirizzo": "Via dell'Esempio 12, 38057 Pergine Valsugana (TN)", "apparato": "olt-pergine-01", "porta": "0/1/3", "stato": "guasto", "dettaglio": "nessun segnale ottico dalle 10:12 (LOS); ONT non registrato", "sessione": {"tipo": "PPPoE", "utente": "ln000201@ciaspolink.example.org", "attiva": false, "ultima_disconnessione": "2026-09-08T10:12:41+02:00"}, "voce": "non registrata: manca la linea dati", "guasto_collettivo": {"zona": "Pergine Valsugana", "descrizione": "fibra interrotta su una porta della centrale di Pergine, danneggiata durante lavori stradali", "inizio": "2026-09-08T10:12:00+02:00", "stato": "tecnici sul posto", "linee_coinvolte": "circa 40", "stima_ripristino": null}}`

