# CASO-05 — Cliente furioso chiede rimborso: operatore, nessun importo promesso (v1-riferimento)

**cliente:** Siete dei ladri incompetenti. Ieri sono stato senza internet tutto il giorno e nessuno mi ha detto niente. Voglio i soldi indietro subito o disdico e vi faccio una recensione che ve la ricordate. Il codice è CL-005007, l'e-mail giorgio.provvisorio@example.org. Voglio parlare con un responsabile.

**assistente:** Signor Provvisorio, la riconosco e mi dispiace per il disservizio di ieri e per la mancanza di comunicazione.

Ho passato la conversazione a un collega, con priorità alta. Il passaggio è in diretta. Nel riepilogo ho scritto chi è lei, che ieri è rimasto senza internet tutto il giorno, che nessuno l'ha avvisata e che chiede il rimborso e di parlare con un responsabile. Non dovrà ripetere niente.

Gli importi e i rimborsi li decide l'amministrazione, quindi non posso anticipare cifre. Il collega potrà registrare la richiesta di indennizzo con lei.

- strumento `verifica_identita` (capacità `verifica_identita`)
  - argomenti: `{"codice_cliente": "CL-005007", "recapito": "giorgio.provvisorio@example.org"}`
  - risultato: `{"esito": "riconosciuto", "id_cliente": "CL-005007", "nome": "Giorgio Provvisorio", "tipo": "privato", "linee": ["LN-005007"]}`
- strumento `passa_a_operatore` (capacità `passa_a_operatore`)
  - argomenti: `{"motivo": "Il cliente chiede di parlare con un responsabile e un rimborso per un giorno senza internet.", "riepilogo": "Giorgio Provvisorio, CL-005007, cliente privato riconosciuto (codice cliente ed e-mail verificati). Linea LN-005007. Segnala che ieri è rimasto senza internet tutto il giorno e che nessuno lo ha avvisato. Chiede il rimborso immediato, altrimenti minaccia disdetta e recensione negativa. Chiede di parlare con un responsabile. Non ho ancora controllato lo stato della linea né aperto segnalazioni o richieste di indennizzo; nessuna promessa di importi fatta.", "priorita": "alta"}`
  - risultato: `{"esito": "presa in carico", "modalita": "in diretta"}`

