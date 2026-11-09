# linea-guasta — Una cliente chiede della sua linea e dà codice e recapito (vaga)

**cliente:** Buongiorno, sono Laura Prova, codice cliente CL-000101, e-mail laura.prova@example.org. Non ho più internet da poco dopo le dieci: mi dite qual è la situazione della mia linea?

**assistente:** Buongiorno Laura, la sua linea LN-000201 (Casa Fibra 1 Giga, Pergine Valsugana) risulta in guasto. Dai nostri sistemi manca il segnale ottico (LOS) e il modem/ONT non si registra, quindi anche la linea voce non è attiva.

Il guasto risulta iniziato alle 10:12, ma con data 8 settembre 2026 e non oggi. Può controllare che l'ONT sia acceso e che la fibra non sia piegata o scollegata? Se il problema persiste, posso verificare la linea più a fondo.

- strumento `cercaCliente` (capacità `cerca_cliente`)
  - argomenti: `{"q": "CL-000101"}`
  - risultato: `{"cliente": {"id_cliente": "CL-000101", "nome": "Laura Prova", "tipo": "privato", "recapiti_registrati": {"email": "laura.prova@example.org", "telefono": "+39 000 000 0101"}, "servizi": ["Casa Fibra 1 Giga", "Linea voce di casa"]}, "linee": [{"id_linea": "LN-000201", "tecnologia": "FTTH", "offerta": "Casa Fibra 1 Giga", "indirizzo": "Via dell'Esempio 12, 38057 Pergine Valsugana (TN)", "apparato": "olt-pergine-01", "porta": "0/1/3", "stato": "guasto", "dettaglio": "nessun segnale ottico dalle 10:12 (LOS); ONT non registrato", "sessione": {"tipo": "PPPoE", "utente": "ln000201@ciaspolink.example.org", "attiva": false, "ultima_disconnessione": "2026-09-08T10:12:41+02:00"}, "voce": "non registrata: manca la linea dati"}], "fatture": [], "credenziali": {"password_area_clienti": "demo-0101"}, "note_interne": "scheda completa, come la restituisce il v0"}`

