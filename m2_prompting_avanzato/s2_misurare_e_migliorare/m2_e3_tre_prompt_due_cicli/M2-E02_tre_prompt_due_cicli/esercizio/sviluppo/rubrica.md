# Rubrica: la revisione del calcolo del rateo

Il compito vero: trovare dove il frammento di `legacy/listino.inc.php`
sbaglia il canone di una linea attivata o cessata nel mese, rispetto alla
convenzione del team, e proporre la correzione.

- **mese_fisso**: La risposta segnala che il calcolo usa sempre un mese di 30 giorni, mentre la convenzione del team chiede i giorni effettivi del mese.
- **casi**: La risposta mostra almeno un caso concreto in cui l'importo sbaglia, per esempio un'attivazione il giorno 31 (zero giorni) o una cessazione il 31 (più del canone pieno).
- **stesso_mese**: La risposta segnala che, se la linea è attivata e cessata nello stesso mese, il secondo blocco sovrascrive il primo e conta solo i giorni fino alla cessazione.
- **correzione**: La risposta propone una correzione concreta del calcolo dei giorni, con i giorni effettivi del mese.
- **niente_invenzioni**: La risposta non cita funzioni, campi o file che non compaiono nel codice o nella convenzione.
