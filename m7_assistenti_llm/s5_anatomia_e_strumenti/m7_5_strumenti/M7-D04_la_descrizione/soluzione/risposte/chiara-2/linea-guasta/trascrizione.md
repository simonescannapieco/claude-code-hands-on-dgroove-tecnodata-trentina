# linea-guasta — Una cliente chiede della sua linea e dà codice e recapito (chiara)

**cliente:** Buongiorno, sono Laura Prova, codice cliente CL-000101, e-mail laura.prova@example.org. Non ho più internet da poco dopo le dieci: mi dite qual è la situazione della mia linea?

**assistente:** Buongiorno Laura, la sua linea Casa Fibra 1 Giga (LN-000201) è in guasto. Non arriva più il segnale ottico dalle 10:12.
La causa è una fibra interrotta alla centrale di Pergine Valsugana, danneggiata durante dei lavori stradali. Sono coinvolte circa 40 linee e i tecnici sono già sul posto.
Non c'è ancora una stima del ripristino. Non serve riavviare il modem, perché il problema non dipende dalla sua apparecchiatura.

Nota: il sistema indica come data del guasto l'8 settembre 2026 e non quella di oggi. Se il disservizio per lei è iniziato oggi, la segnalazione potrebbe non essere aggiornata.

- strumento `verifica_identita` (capacità `verifica_identita`)
  - argomenti: `{"codice_cliente": "CL-000101", "recapito": "laura.prova@example.org"}`
  - risultato: `{"esito": "riconosciuto", "id_cliente": "CL-000101", "nome": "Laura Prova", "tipo": "privato", "linee": ["LN-000201"]}`
- strumento `stato_linea` (capacità `stato_linea`)
  - argomenti: `{"id_linea": "LN-000201"}`
  - risultato: `{"id_linea": "LN-000201", "tecnologia": "FTTH", "offerta": "Casa Fibra 1 Giga", "indirizzo": "Via dell'Esempio 12, 38057 Pergine Valsugana (TN)", "apparato": "olt-pergine-01", "porta": "0/1/3", "stato": "guasto", "dettaglio": "nessun segnale ottico dalle 10:12 (LOS); ONT non registrato", "sessione": {"tipo": "PPPoE", "utente": "ln000201@ciaspolink.example.org", "attiva": false, "ultima_disconnessione": "2026-09-08T10:12:41+02:00"}, "voce": "non registrata: manca la linea dati", "guasto_collettivo": {"zona": "Pergine Valsugana", "descrizione": "fibra interrotta su una porta della centrale di Pergine, danneggiata durante lavori stradali", "inizio": "2026-09-08T10:12:00+02:00", "stato": "tecnici sul posto", "linee_coinvolte": "circa 40", "stima_ripristino": null}}`

