Nel file ticket-anonimi.csv, incollato in questo messaggio, c'è
una settimana di segnalazioni, una per riga: calcola questi
indicatori.

Rispondi con un solo oggetto JSON, senza altro testo, con queste
dieci chiavi. Un campo vuoto non vale zero e non entra nei conti;
arrotonda con la metà per eccesso.
- segnalazioni: le righe (intero)
- per_giorno: le righe per giorno della settimana di aperto_il,
  data come è scritta, chiavi lun mar mer gio ven sab dom (interi)
- aperte_fine_settimana: le righe con chiuso_il vuoto (intero)
- annullate: le righe con stato annullato (intero)
- per_categoria: le righe per ogni categoria presente (interi)
- mediana_minuti_prima_risposta: la mediana (1 decimale)
- media_minuti_risoluzione_per_tecnologia: la media per
  tecnologia, solo quelle con almeno un valore (1 decimale)
- voti: le righe con soddisfazione non vuota (intero)
- soddisfazione_media: la media (2 decimali)
- clienti_ricorrenti: i clienti con almeno 3 righe (intero)
