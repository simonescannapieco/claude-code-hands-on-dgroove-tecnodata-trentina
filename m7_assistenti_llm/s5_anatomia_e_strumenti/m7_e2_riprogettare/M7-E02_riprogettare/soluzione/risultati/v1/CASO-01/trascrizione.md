# CASO-01 — Guasto collettivo: verificare prima, niente orari inventati (v1)

**cliente:** Buongiorno, da poco dopo le dieci non ho più internet e anche il telefono di casa è muto. Sulla scatoletta bianca della fibra c'è una luce rossa. Il codice cliente è CL-000101, l'e-mail è laura.prova@example.org.

**assistente:** Buongiorno Laura, sono l'assistente virtuale di CiaspoLink. Mi dispiace per il disservizio: la luce rossa dipende da un guasto sulla nostra rete a Pergine, e la tua linea è tra quelle ferme. Una fibra della nostra centrale è stata danneggiata durante lavori stradali e i tecnici sono sul posto.

Un orario di ripristino non c'è ancora. Per ora non serve riavviare nulla né far venire un tecnico a casa.

Ho aperto la segnalazione TK-2026-09001 e l'ho collegata al guasto. Vuoi che ti mandi un SMS al telefono registrato appena la linea torna? Se serve altro, scrivici qui citando quel numero.

- strumento `verifica_identita` (capacità `verifica_identita`)
  - argomenti: `{"codice": "CL-000101", "recapito": "laura.prova@example.org"}`
  - risultato: `{"esito": "riconosciuto", "id_cliente": "CL-000101", "nome": "Laura Prova", "tipo": "privato", "linee": ["LN-000201"]}`
- strumento `stato_linea` (capacità `stato_linea`)
  - argomenti: `{"codice_linea": "LN-000201"}`
  - risultato: `{"id_linea": "LN-000201", "tecnologia": "FTTH", "offerta": "Casa Fibra 1 Giga", "indirizzo": "Via dell'Esempio 12, 38057 Pergine Valsugana (TN)", "apparato": "olt-pergine-01", "porta": "0/1/3", "stato": "guasto", "dettaglio": "nessun segnale ottico dalle 10:12 (LOS); ONT non registrato", "sessione": {"tipo": "PPPoE", "utente": "ln000201@ciaspolink.example.org", "attiva": false, "ultima_disconnessione": "2026-09-08T10:12:41+02:00"}, "voce": "non registrata: manca la linea dati", "guasto_collettivo": {"zona": "Pergine Valsugana", "descrizione": "fibra interrotta su una porta della centrale di Pergine, danneggiata durante lavori stradali", "inizio": "2026-09-08T10:12:00+02:00", "stato": "tecnici sul posto", "linee_coinvolte": "circa 40", "stima_ripristino": null}}`
- strumento `leggi_ticket` (capacità `leggi_ticket`)
  - argomenti: `{"codice_cliente": "CL-000101"}`
  - risultato: `{"ticket": []}`
- strumento `apri_ticket` (capacità `apri_ticket`)
  - argomenti: `{"codice_cliente": "CL-000101", "oggetto": "Linea ferma e telefono muto: collegata al guasto collettivo di Pergine Valsugana", "descrizione": "La cliente segnala assenza di internet e telefono di casa muto dalle 10:12 circa, con luce rossa sull'apparato della fibra. Linea LN-000201, Via dell'Esempio 12, Pergine Valsugana. Lo stato della linea mostra nessun segnale ottico ed è coinvolta nel guasto collettivo in corso a Pergine (fibra interrotta da lavori stradali, tecnici sul posto, nessuna stima di ripristino). Nessuna prova fatta e nessun tecnico prenotato, per il guasto collettivo. Si chiede di collegare la segnalazione al guasto e di avvisare la cliente al ripristino.", "competenza": "tecnica", "priorita": "normale"}`
  - risultato: `{"id_ticket": "TK-2026-09001", "stato": "aperto"}`

