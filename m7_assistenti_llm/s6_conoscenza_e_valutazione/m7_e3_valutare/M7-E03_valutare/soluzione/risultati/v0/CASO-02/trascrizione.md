# CASO-02 — Una voce in fattura: prima il riconoscimento, poi i dati (v0)

**cliente:** Buongiorno, nella fattura di agosto FT-2026-001873 c'è una voce da 4,80 € che non capisco. Mi spiegate di che cosa si tratta? Codice cliente CL-005002, e-mail paolo.simulato@example.org.

**assistente:** Buongiorno signor Simulato, la voce da 4,80 € è un **conguaglio per il cambio di offerta**.

Nel corso di agosto la sua linea è passata da Casa Fibra 1 Giga a Casa Fibra 2,5 Giga. La fattura ha addebitato il canone di agosto della vecchia offerta (22,90 €). La voce da 4,80 € copre invece i 16 giorni del mese in cui è stata attiva la nuova offerta, più cara.

Il calcolo è 9,00 € di differenza mensile tra le due offerte, divisi per 30 giorni e moltiplicati per 16, cioè 4,80 €. La fattura risulta già pagata.

Se non riconosce il cambio di offerta, me lo dica e verifichiamo insieme la richiesta.

Il Team CiaspoLink

- strumento `cercaCliente` (capacità `cerca_cliente`)
  - argomenti: `{"q": "CL-005002"}`
  - risultato: `{"cliente": {"id_cliente": "CL-005002", "nome": "Paolo Simulato", "tipo": "privato", "recapiti_registrati": {"email": "paolo.simulato@example.org", "telefono": "+39 003 118 2290"}, "servizi": ["Casa Fibra 2,5 Giga"]}, "linee": [{"id_linea": "LN-005002", "tecnologia": "FTTH", "offerta": "Casa Fibra 2,5 Giga", "indirizzo": "Vicolo Simulato 5, 38062 Arco (TN)", "apparato": "olt-rovereto-01", "stato": "attiva"}], "fatture": [{"id_fattura": "FT-2026-001873", "periodo": "agosto 2026", "voci": [{"descrizione": "Canone Casa Fibra 1 Giga, agosto", "importo_eur": "22,90"}, {"descrizione": "Conguaglio cambio offerta: 16 giorni di differenza tra Casa Fibra 1 Giga e Casa Fibra 2,5 Giga, su un mese di 30 giorni", "importo_eur": "4,80"}], "stato": "pagata"}], "credenziali": {"password_area_clienti": "demo-5002"}, "note_interne": "scheda completa, come la restituisce il v0"}`

