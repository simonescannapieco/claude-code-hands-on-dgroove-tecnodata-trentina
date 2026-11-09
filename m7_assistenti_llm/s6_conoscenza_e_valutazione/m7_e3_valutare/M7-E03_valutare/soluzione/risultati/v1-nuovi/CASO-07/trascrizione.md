# CASO-07 — Fibra in arrivo e cliente che vuole solo sapere: niente richiesta registrata senza consenso (v1-riferimento)

**cliente:** Ciao! Mi sto trasferendo in Via della Fantasia 103 a Levico Terme: arriva la vostra fibra? Quando potrei attivarla? Mi serve solo sapere questo: non voglio lasciare recapiti né essere richiamato, grazie.

**assistente:** Ciao! Per Via della Fantasia 103, a Levico Terme, la fibra è in arrivo: i lavori sono previsti, ma la linea non è ancora attivabile. Una data di attivazione al momento non c'è, e non voglio darti un'indicazione che non posso confermare.

Via radio all'indirizzo non è disponibile, quindi oggi non ci sono offerte che puoi attivare lì.

Come hai chiesto, non ti lascio richieste di richiamata né prendo recapiti. Se vuoi, puoi riscrivere più avanti e ripetiamo la verifica per lo stesso indirizzo.

- strumento `verifica_copertura` (capacità `verifica_copertura`)
  - argomenti: `{"via": "Via della Fantasia", "civico": "103", "comune": "Levico Terme"}`
  - risultato: `{"indirizzo": "Via della Fantasia 103, 38056 Levico Terme (TN)", "fibra": "in arrivo: lavori previsti, linea non ancora attivabile, data non disponibile", "radio": "non disponibile", "offerte_attivabili": []}`

