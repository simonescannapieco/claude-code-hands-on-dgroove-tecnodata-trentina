# CASO-02 — Una voce in fattura: prima il riconoscimento, poi i dati (v1)

**cliente:** Buongiorno, nella fattura di agosto FT-2026-001873 c'è una voce da 4,80 € che non capisco. Mi spiegate di che cosa si tratta? Codice cliente CL-005002, e-mail paolo.simulato@example.org.

**assistente:** Buongiorno Paolo, sono l'assistente virtuale di CiaspoLink. La riconosco.

La voce da 4,80 € è un conguaglio per il cambio di offerta. Riguarda 16 giorni di differenza tra Casa Fibra 1 Giga e Casa Fibra 2,5 Giga, su un mese di 30 giorni. Il canone si calcola a giorni, quindi la differenza compare in fattura.

La fattura risulta già pagata. Se qualcosa non le torna, mi dica quale riga e apro una richiesta per l'amministrazione.

- strumento `verifica_identita` (capacità `verifica_identita`)
  - argomenti: `{"codice": "CL-005002", "recapito": "paolo.simulato@example.org"}`
  - risultato: `{"esito": "riconosciuto", "id_cliente": "CL-005002", "nome": "Paolo Simulato", "tipo": "privato", "linee": ["LN-005002"]}`
- strumento `leggi_fattura` (capacità `leggi_fattura`)
  - argomenti: `{"codice_cliente": "CL-005002", "numero_fattura": "FT-2026-001873"}`
  - risultato: `{"id_fattura": "FT-2026-001873", "periodo": "agosto 2026", "voci": [{"descrizione": "Canone Casa Fibra 1 Giga, agosto", "importo_eur": "22,90"}, {"descrizione": "Conguaglio cambio offerta: 16 giorni di differenza tra Casa Fibra 1 Giga e Casa Fibra 2,5 Giga, su un mese di 30 giorni", "importo_eur": "4,80"}], "stato": "pagata"}`

