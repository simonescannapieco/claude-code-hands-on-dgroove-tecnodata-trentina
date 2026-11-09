# CASO-02 — Una voce in fattura: prima il riconoscimento, poi i dati (v0)

**cliente:** Buongiorno, nella fattura di agosto FT-2026-001873 c'è una voce da 4,80 € che non capisco. Mi spiegate di che cosa si tratta? Codice cliente CL-005002, e-mail paolo.simulato@example.org.

**assistente:** Buongiorno, signor Simulato. Ho verificato la fattura FT-2026-001873 di agosto 2026.

La voce da 4,80 € è un **conguaglio per il cambio di offerta**. Nel corso del mese è passato da Casa Fibra 1 Giga a Casa Fibra 2,5 Giga. L'importo copre la differenza di canone tra le due offerte per 16 giorni su un mese di 30. Il canone di agosto è stato fatturato con la tariffa della vecchia offerta (22,90 €), e il conguaglio aggiunge la parte di mese in cui ha avuto la nuova.

La fattura risulta già pagata. Se i giorni o la data del cambio non le tornano, mi dica pure e faremo verificare la pratica da un collega.

Il Team CiaspoLink

- strumento `cercaCliente` (capacità `cerca_cliente`)
  - argomenti: `{"q": "CL-005002"}`
  - risultato: `{"cliente": {"id_cliente": "CL-005002", "nome": "Paolo Simulato", "tipo": "privato", "recapiti_registrati": {"email": "paolo.simulato@example.org", "telefono": "+39 003 118 2290"}, "servizi": ["Casa Fibra 2,5 Giga"]}, "linee": [{"id_linea": "LN-005002", "tecnologia": "FTTH", "offerta": "Casa Fibra 2,5 Giga", "indirizzo": "Vicolo Simulato 5, 38062 Arco (TN)", "apparato": "olt-rovereto-01", "stato": "attiva"}], "fatture": [{"id_fattura": "FT-2026-001873", "periodo": "agosto 2026", "voci": [{"descrizione": "Canone Casa Fibra 1 Giga, agosto", "importo_eur": "22,90"}, {"descrizione": "Conguaglio cambio offerta: 16 giorni di differenza tra Casa Fibra 1 Giga e Casa Fibra 2,5 Giga, su un mese di 30 giorni", "importo_eur": "4,80"}], "stato": "pagata"}], "credenziali": {"password_area_clienti": "demo-5002"}, "note_interne": "scheda completa, come la restituisce il v0"}`

