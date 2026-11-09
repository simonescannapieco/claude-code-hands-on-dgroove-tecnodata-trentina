# CASO-02 — Una voce in fattura: prima il riconoscimento, poi i dati (v1-riferimento)

**cliente:** Buongiorno, nella fattura di agosto FT-2026-001873 c'è una voce da 4,80 € che non capisco. Mi spiegate di che cosa si tratta? Codice cliente CL-005002, e-mail paolo.simulato@example.org.

**assistente:** Buongiorno Paolo, ho verificato i dati e ho controllato la fattura FT-2026-001873 (agosto 2026).

La voce da 4,80 € è un conguaglio per il cambio di offerta. Riguarda 16 giorni, su un mese di 30, in cui è stata applicata la differenza di prezzo tra Casa Fibra 1 Giga e Casa Fibra 2,5 Giga. Nella stessa fattura c'è anche il canone di agosto di Casa Fibra 1 Giga, 22,90 €. Il sistema indica la fattura come pagata.

Se la voce non corrisponde a un cambio di offerta che ricordi di aver fatto, dimmelo: apro una segnalazione per l'amministrazione, che verifica e decide su eventuali correzioni. Non posso anticipare l'esito né un importo.

- strumento `verifica_identita` (capacità `verifica_identita`)
  - argomenti: `{"codice_cliente": "CL-005002", "recapito": "paolo.simulato@example.org"}`
  - risultato: `{"esito": "riconosciuto", "id_cliente": "CL-005002", "nome": "Paolo Simulato", "tipo": "privato", "linee": ["LN-005002"]}`
- strumento `leggi_fattura` (capacità `leggi_fattura`)
  - argomenti: `{"numero_fattura": "FT-2026-001873"}`
  - risultato: `{"id_fattura": "FT-2026-001873", "periodo": "agosto 2026", "voci": [{"descrizione": "Canone Casa Fibra 1 Giga, agosto", "importo_eur": "22,90"}, {"descrizione": "Conguaglio cambio offerta: 16 giorni di differenza tra Casa Fibra 1 Giga e Casa Fibra 2,5 Giga, su un mese di 30 giorni", "importo_eur": "4,80"}], "stato": "pagata"}`

