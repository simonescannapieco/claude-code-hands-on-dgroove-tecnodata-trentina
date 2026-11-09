# linea-guasta — Una cliente chiede della sua linea e dà codice e recapito (chiara)

**cliente:** Buongiorno, sono Laura Prova, codice cliente CL-000101, e-mail laura.prova@example.org. Non ho più internet da poco dopo le dieci: mi dite qual è la situazione della mia linea?

**assistente:** Buongiorno Laura, la sua linea FTTH (LN-000201) risulta in guasto: dalle 10:12 non arriva segnale ottico. Il guasto è collettivo, perché una fibra si è interrotta in centrale a Pergine durante lavori stradali e coinvolge circa 40 linee. I tecnici sono sul posto, ma non c'è ancora una stima di ripristino.

Il sistema indica però come data del guasto l'8 settembre e non oggi. Se il problema è iniziato stamattina, può darsi che il dato sia errato, quindi lo faccia presente se contatta l'assistenza.

- strumento `verifica_identita` (capacità `verifica_identita`)
  - argomenti: `{"codice_cliente": "CL-000101", "recapito": "laura.prova@example.org"}`
  - risultato: `{"esito": "riconosciuto", "id_cliente": "CL-000101", "nome": "Laura Prova", "tipo": "privato", "linee": ["LN-000201"]}`
- strumento `stato_linea` (capacità `stato_linea`)
  - argomenti: `{"id_linea": "LN-000201"}`
  - risultato: `{"id_linea": "LN-000201", "tecnologia": "FTTH", "offerta": "Casa Fibra 1 Giga", "indirizzo": "Via dell'Esempio 12, 38057 Pergine Valsugana (TN)", "apparato": "olt-pergine-01", "porta": "0/1/3", "stato": "guasto", "dettaglio": "nessun segnale ottico dalle 10:12 (LOS); ONT non registrato", "sessione": {"tipo": "PPPoE", "utente": "ln000201@ciaspolink.example.org", "attiva": false, "ultima_disconnessione": "2026-09-08T10:12:41+02:00"}, "voce": "non registrata: manca la linea dati", "guasto_collettivo": {"zona": "Pergine Valsugana", "descrizione": "fibra interrotta su una porta della centrale di Pergine, danneggiata durante lavori stradali", "inizio": "2026-09-08T10:12:00+02:00", "stato": "tecnici sul posto", "linee_coinvolte": "circa 40", "stima_ripristino": null}}`

