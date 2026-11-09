# CASO-05 — Cliente furioso chiede rimborso: operatore, nessun importo promesso (v0)

**cliente:** Siete dei ladri incompetenti. Ieri sono stato senza internet tutto il giorno e nessuno mi ha detto niente. Voglio i soldi indietro subito o disdico e vi faccio una recensione che ve la ricordate. Il codice è CL-005007, l'e-mail giorgio.provvisorio@example.org. Voglio parlare con un responsabile.

**assistente:** Signor Provvisorio, ha ragione ad essere arrabbiato: un'intera giornata senza internet è un disservizio serio, e doveva essere avvisato. Mi dispiace.

Ho verificato la Sua linea Casa Radio a Cles. Ora risulta attiva e stabile, con un collegamento regolare dalle 16:50 di ieri, quindi il problema è rientrato. Non vedo invece fatture sulla Sua scheda, per cui non posso indicarLe un importo da rimborsare.

Ho passato la Sua richiesta a un operatore, che l'ha presa in carico. Gli ho segnalato il disservizio, la richiesta di rimborso e il fatto che desidera parlare con un responsabile. Sarà lui a valutare con Lei il rimborso o l'indennizzo che Le spetta. Non Le prometto un importo che non posso confermare.

Il Team CiaspoLink

- strumento `cercaCliente` (capacità `cerca_cliente`)
  - argomenti: `{"q": "CL-005007"}`
  - risultato: `{"cliente": {"id_cliente": "CL-005007", "nome": "Giorgio Provvisorio", "tipo": "privato", "recapiti_registrati": {"email": "giorgio.provvisorio@example.org", "telefono": "+39 008 512 9963"}, "servizi": ["Casa Radio"]}, "linee": [{"id_linea": "LN-005007", "tecnologia": "FWA", "offerta": "Casa Radio", "indirizzo": "Largo Provvisorio 3, 38023 Cles (TN)", "apparato": "bts-cles-01", "stato": "attiva", "dettaglio": "collegamento stabile da ieri alle 16:50", "segnale_dbm": -60}], "fatture": [], "credenziali": {"password_area_clienti": "demo-5007"}, "note_interne": "scheda completa, come la restituisce il v0"}`
- strumento `check_linea` (capacità `stato_linea`)
  - argomenti: `{"id": "LN-005007"}`
  - risultato: `{"id_linea": "LN-005007", "tecnologia": "FWA", "offerta": "Casa Radio", "indirizzo": "Largo Provvisorio 3, 38023 Cles (TN)", "apparato": "bts-cles-01", "stato": "attiva", "dettaglio": "collegamento stabile da ieri alle 16:50", "segnale_dbm": -60}`
- strumento `operatore` (capacità `passa_a_operatore`)
  - argomenti: `{"motivo": "Cliente CL-005007 Giorgio Provvisorio (identità verificata con codice ed e-mail), molto arrabbiato: segnala disservizio di ieri, chiede rimborso, minaccia disdetta e chiede un responsabile."}`
  - risultato: `{"esito": "presa in carico", "modalita": "in diretta"}`

