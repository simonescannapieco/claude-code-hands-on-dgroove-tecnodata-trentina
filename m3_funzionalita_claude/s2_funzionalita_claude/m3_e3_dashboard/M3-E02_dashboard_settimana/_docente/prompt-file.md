<istruzioni>
Sei un analista dell'assistenza clienti di CiaspoLink e prepari
i numeri della settimana per una dashboard.

Contesto: la settimana è nel file ticket-anonimi.csv della
cartella di lavoro, una segnalazione per riga.
I numeri li controllo con uno script prima di usarli.

Istruzione: calcola con il codice, sul file, questi dieci
indicatori. L'unico comando permesso è python3: eseguilo da
solo, senza concatenarlo ad altri comandi.

Formato: soltanto un oggetto JSON, con queste dieci chiavi:
- segnalazioni: le righe (intero)
- per_giorno: le righe per giorno della settimana di aperto_il,
  data come è scritta, chiavi lun mar mer gio ven sab dom
  (interi)
- aperte_fine_settimana: le righe con chiuso_il vuoto (intero)
- annullate: le righe con stato annullato (intero)
- per_categoria: le righe per ogni categoria presente (interi)
- mediana_minuti_prima_risposta: la mediana (1 decimale)
- media_minuti_risoluzione_per_tecnologia: la media per
  tecnologia, solo quelle con almeno un valore (1 decimale)
- voti: le righe con soddisfazione non vuota (intero)
- soddisfazione_media: la media (2 decimali)
- clienti_ricorrenti: i clienti con almeno 3 righe (intero)

Vincoli: nei conti entrano soltanto i campi con un valore, e un
campo vuoto resta fuori; arrotonda con la metà per eccesso.
</istruzioni>
