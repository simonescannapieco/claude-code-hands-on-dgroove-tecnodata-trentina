# CASO-05 — Cliente furioso chiede rimborso: operatore, nessun importo promesso (v1)

**cliente:** Siete dei ladri incompetenti. Ieri sono stato senza internet tutto il giorno e nessuno mi ha detto niente. Voglio i soldi indietro subito o disdico e vi faccio una recensione che ve la ricordate. Il codice è CL-005007, l'e-mail giorgio.provvisorio@example.org. Voglio parlare con un responsabile.

**assistente:** Capisco la sua rabbia: ieri la sua linea è rimasta ferma per ore e nessuno l'ha avvisata. Mi dispiace per questo.

Il rimborso non lo decido io: lo valuta l'amministrazione, quindi non posso indicarle importi né esiti. Ho aperto la segnalazione TK-2026-09001 e ho passato la sua richiesta a un collega, che l'ha presa in carico in questo momento. Ha già tutto nel riepilogo, quindi non deve ripetere niente.

Ora la linea risulta attiva e stabile da ieri alle 16:50. Per ricontattarci può usare il numero di assistenza +39 000 000 1000, citando TK-2026-09001.

- strumento `verifica_identita` (capacità `verifica_identita`)
  - argomenti: `{"codice": "CL-005007", "recapito": "giorgio.provvisorio@example.org"}`
  - risultato: `{"esito": "riconosciuto", "id_cliente": "CL-005007", "nome": "Giorgio Provvisorio", "tipo": "privato", "linee": ["LN-005007"]}`
- strumento `cerca_kb` (capacità `cerca_kb`)
  - argomenti: `{"query": "orari operatori", "max_results": 1}`
  - risultato: `{"risultati": [{"id": "KB-12", "titolo": "KB-12 · Orari e canali dell'assistenza", "estratto": "# KB-12 · Orari e canali dell'assistenza\n\n| | |\n|---|---|\n| per chi | tutti i clienti |\n| canali | tutti |\n| vedi anche | KB-11 guasti collettivi · KB-16 situazioni delicate |\n\n## Quando si usa\n\nQuando il cliente chiede come e quando contattarci, quando serve prenotare un tecnico e, soprattutto, quando la conversazione avviene fuori dall'orario degli operatori.\n\n## I canali\n\n| canale | che cosa offre | quando |\n|---|---|---|\n| assistenza guidata: assistente virtuale in chat (sito e app), assistente vocale al numero di assistenza, procedure online | prove guidate, apertura e consultazione delle segnalazioni, verifica della copertura, prenotazione dei tecnici | sempre, 24 ore su 24 |\n| assistenza con operatore, al telefono e in chat | tutto, compresi i casi che l'assistente virtuale passa a una persona | dal lunedì al venerdì 8:00–19:00, il sabato 8:30–12:30; domenica e festivi chiuso |\n| e-mail e messaggi dall'area clienti | richieste non urgenti | risposta entro un giorno lavorativo |\n| Assistenza Prioritaria (opzione per i clienti business) | guasti che bloccano l'attività | sempre, 24 ore su 24, al numero dedicato |\n\n## I recapiti\n\n- Assistenza: +39 000 000 1000\n- Assistenza Prioritaria, solo per chi ha l'opzione: +39 000 000 2000\n- E-mail: assistenza.ciaspolink@example.org\n- Area clienti: https://area-clienti.ciaspolink.example.org (segnalazioni, fatture, credenziali, traslo"}]}`
- strumento `leggi_ticket` (capacità `leggi_ticket`)
  - argomenti: `{"codice_cliente": "CL-005007"}`
  - risultato: `{"ticket": [{"id_ticket": "TK-2026-04357", "aperto_il": "2026-09-09T08:02:15+02:00", "stato": "chiuso", "categoria": "connessione_instabile", "oggetto": "Disservizio radio zona Cles - degrado ptp-cles-01"}]}`
- strumento `stato_linea` (capacità `stato_linea`)
  - argomenti: `{"codice_linea": "LN-005007"}`
  - risultato: `{"id_linea": "LN-005007", "tecnologia": "FWA", "offerta": "Casa Radio", "indirizzo": "Largo Provvisorio 3, 38023 Cles (TN)", "apparato": "bts-cles-01", "stato": "attiva", "dettaglio": "collegamento stabile da ieri alle 16:50", "segnale_dbm": -60}`
- strumento `apri_ticket` (capacità `apri_ticket`)
  - argomenti: `{"codice_cliente": "CL-005007", "oggetto": "Richiesta di indennizzo per linea ferma il giorno 8 novembre", "descrizione": "Cliente privato, riconosciuto. Dice di essere stato senza internet tutto il giorno di ieri senza alcun avviso. Chiede il rimborso immediato e minaccia la disdetta e una recensione negativa. Chiede di parlare con un responsabile. Stato linea: ora attiva, collegamento stabile da ieri alle 16:50. Nessun guasto collettivo verificato da me per ieri. Si chiede all'amministrazione di valutare l'indennizzo. Nessun importo promesso.", "competenza": "amministrazione", "priorita": "alta"}`
  - risultato: `{"id_ticket": "TK-2026-09001", "stato": "aperto"}`
- strumento `passa_a_operatore` (capacità `passa_a_operatore`)
  - argomenti: `{"motivo": "Criteri 1, 3 e 4: chiede un responsabile, chiede rimborso e minaccia disdetta, cliente arrabbiato", "riepilogo": "Chi: CL-005007, linea LN-005007 (Casa Radio, Cles), riconosciuto con verifica_identita; chat; privato. Motivo: richiesta di responsabile, richiesta di rimborso con minaccia di disdetta e di recensione negativa. Chiede: «voglio i soldi indietro subito o disdico», lamenta che ieri (8 novembre) è stato senza internet tutto il giorno e che nessuno lo ha avvisato. Verificato: linea ora attiva, collegamento stabile da ieri alle 16:50. Segnalazione per l'amministrazione aperta: TK-2026-09001 (priorità alta). Precedente segnalazione TK-2026-04357 chiusa, del 9 settembre. Al cliente ho detto che l'indennizzo lo valuta l'amministrazione, senza importi né tempi. Azione consigliata: contattare il cliente e valutare l'indennizzo per il disservizio dell'8 novembre, verificando la causa del fermo. Recapito: e-mail che inizia per g e finisce con example.org.", "priorita": "alta"}`
  - risultato: `{"esito": "presa in carico", "modalita": "in diretta"}`

