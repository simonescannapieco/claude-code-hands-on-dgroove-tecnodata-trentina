# chiusura_mese()

Documentazione di `legacy/chiusura_mese.inc.php`, scritta leggendo il codice così com'è: descrive che cosa fa la funzione, senza cambiarla. I numeri di riga sono quelli del file nel repository.

## Che cosa fa

`chiusura_mese($anno, $mese, $opzioni)` esegue la chiusura amministrativa di un mese (`AAAA-MM`), in sei fasi una dopo l'altra: segna scadute le fatture non pagate oltre la scadenza, sospende i clienti con troppe fatture scadute, riattiva i sospesi che non ne hanno più, emette le note di credito per gli indennizzi dei guasti dei clienti business, ricalcola le provvigioni dei rivenditori e scrive un report HTML.

La lancia `bin/chiusura-mese.php` (riga 35), il giorno 2 di ogni mese per il mese precedente, con le opzioni `simula` e `oggi`. Nel repository non ci sono altri chiamanti; il commento in testa al modulo dice che anche un vecchio script di backup la chiama per nome.

Le scritture nel database stanno in una transazione aperta all'inizio (riga 56) e confermata alla fine (riga 283). Con l'opzione `simula` la funzione fa gli stessi calcoli, restituisce il riepilogo e non scrive niente.

## Ingressi e uscite

Ingressi:

- `$anno`, `$mese`: il mese da chiudere. Un mese fuori da 1–12 stampa «Mese non valido: …» e restituisce `false`, senza fare altro (righe 44–47).
- `$opzioni['oggi']`: la data di riferimento, `AAAA-MM-GG`; senza, la data del sistema (riga 30). Decide quali fatture sono scadute, la data e la scadenza delle note di credito, l'anno del loro numero e la data scritta nella nota del cliente sospeso.
- `$opzioni['simula']`: se vera, nessuna scrittura, né nel database né del report.
- `$opzioni['verbose']`: vera se manca; stampa una riga per fase e gli avvisi. `bin/chiusura-mese.php` non la passa.
- Le variabili globali di `legacy/inc/config.inc.php`: `$IVA`, `$GG_SCADENZA`, `$SOGLIA_MOROSITA`, `$NOME_AZIENDA`, `$MESI`, `$DEBUG` (riga 26); la connessione `$db` di `legacy/inc/db.inc.php`, aperta sul file `$DB_FILE` se nessuno l'ha già impostata.

Uscite:

- Il valore restituito: `false` per un mese non valido; altrimenti un array con `periodo` (`AAAA-MM`), `scadute` (quante fatture), `sospesi` e `riattivati` (gli id dei clienti), `note_credito` (gli id delle note emesse; `(simulazione)` in simulazione), `provvigioni` (ciò che restituisce `calcola_provvigioni_mese()`, `false` per un mese già liquidato) e `operazioni` (fatture scadute, sospensioni, riattivazioni e note di credito, sommate).
- `bin/chiusura-mese.php` esce con 2 se la funzione restituisce `false`, altrimenti con 0.
- Su STDOUT, con `verbose`: l'intestazione, una riga per fase, il percorso del report e gli avvisi «ATTENZIONE». In simulazione, con `$DEBUG`, anche l'HTML del report.
- Il file `var/report/chiusura-AAAA-MM.html` e le righe del database della sezione qui sotto.

## Tabelle lette e scritte

| tabella | legge | scrive | dove |
|---|---|---|---|
| `fatture` | sì | sì | fase 1: le fatture `emessa` con `scade_il` prima della data di riferimento diventano `scaduta`; fasi 2 e 3: le fatture `scaduta` di ogni cliente; fase 4: la nota di credito del periodo già emessa, la fattura del periodo da collegare, l'inserimento della nota; `prossimo_numero_fattura()` legge l'ultimo numero dell'anno |
| `righe_fattura` | no | sì | fase 4: una riga `indennizzo` per ticket nella nota di credito |
| `clienti` | sì | sì | fase 1: il nome per il report; fase 2: `stato` a `sospeso` e la `note`; fase 3: `stato` a `attivo` e `note` vuota; fase 4: il tipo `azienda` |
| `linee` | sì | sì | fase 2: da `attiva` a `sospesa`; fase 3: da `sospesa` a `attiva`; fase 5: le linee delle attivazioni |
| `ticket` | sì | no | fase 4: i guasti dei clienti business chiusi nel mese |
| `provvigioni` | sì | sì | fase 5, in `calcola_provvigioni_mese()` di `legacy/provvigioni.inc.php`: se il mese è già liquidato; altrimenti cancella e riscrive le righe del mese (non in simulazione) |
| `attivazioni` | sì | no | fase 5: le attivazioni del mese con un rivenditore |
| `offerte` | sì | no | fase 5: la famiglia, Casa o Business, dell'offerta della linea |
| `registro_operazioni` | no | sì | fasi 5 e 6: una riga per le provvigioni e una per la chiusura, con `log_operazione()` di `legacy/inc/db.inc.php` |

## Effetti collaterali

- Scrive nel database, nella transazione: gli stati di fatture, clienti e linee, le note di credito con le loro righe, le provvigioni e il registro delle operazioni.
- Sospendendo un cliente imposta `clienti.note` a «Linea sospesa per morosità il GG/MM/AAAA.» (la data di riferimento); riattivandolo la porta a `NULL`.
- Crea, se manca, la cartella `var/report/` e scrive `var/report/chiusura-AAAA-MM.html`, al posto del report dello stesso mese, se c'era. Se non riesce a scriverlo aggiunge un avviso e va avanti.
- Stampa su STDOUT quando `verbose` è vera (lo è se l'opzione manca); il messaggio di un mese non valido lo stampa sempre, e `calcola_provvigioni_mese()` stampa sempre il suo per un mese già liquidato.
- Legge l'orologio del sistema: la data di riferimento di default, l'ora del piè del report («generato il …»), le date delle righe del registro e delle provvigioni.
- Se il mese da chiudere non è ancora finito rispetto alla data di riferimento, aggiunge un avviso e chiude lo stesso (righe 51–53).

## Le sei responsabilità

1. **Fatture scadute** (righe 59–82): le fatture di tipo `fattura`, `emessa`, con `scade_il` prima della data di riferimento diventano `scaduta`; conta quante sono e il loro totale.
2. **Sospensioni** (righe 84–112): i clienti `attivo` con almeno `$SOGLIA_MOROSITA` fatture `scaduta` (comprese quelle appena segnate) diventano `sospeso`, con la nota, e le loro linee `attiva` diventano `sospesa`.
3. **Riattivazioni** (righe 114–137): i clienti `sospeso` senza fatture `scaduta` tornano `attivo`, con la nota vuota, e le loro linee `sospesa` tornano `attiva`.
4. **Indennizzi** (righe 139–211): per i clienti `azienda`, ogni ticket `guasto` chiuso nel mese e durato più di 24 ore vale 10 euro (1000 centesimi) per ogni giorno, o frazione, oltre il primo, al massimo 100 euro (10000 centesimi); per ogni cliente una nota di credito con importi negativi, l'IVA al `$IVA` per cento, la scadenza a `$GG_SCADENZA` giorni dalla data di riferimento, collegata alla fattura del periodo e con una riga per ticket; se la nota del periodo esiste già, un avviso e nessuna nota nuova. Alle righe 206–207 un blocco commentato conserva il calcolo precedente, una nota per ticket, con una funzione `crea_nota_credito()` che nel repository non c'è.
5. **Provvigioni** (righe 213–234): chiama `calcola_provvigioni_mese($anno, $mese, !$simula)` di `legacy/provvigioni.inc.php` e mette nel report un rigo per rivenditore; se il mese è già liquidato la funzione restituisce `false` e la chiusura lo segnala negli avvisi.
6. **Report** (righe 236–290): l'HTML con l'intestazione, la tabella dei totali, gli avvisi e il dettaglio delle operazioni; fuori dalla simulazione lo scrive in `var/report/`, aggiunge la riga della chiusura al registro e conferma la transazione; poi stampa gli avvisi.

## Rischi

- La funzione è un blocco solo di 278 righe (24–301) che fa sei cose; il commento in testa al modulo chiede di non spezzarla in più funzioni perché un vecchio script di backup la chiama per nome. Quello script non è nel repository: il nome e la firma di `chiusura_mese()` e l'array che restituisce vanno tenuti come sono.
- Le regole degli indennizzi sono numeri scritti nel codice (24 ore, 1000 e 10000 centesimi); l'IVA, la scadenza e la soglia della sospensione sono variabili globali della configurazione del legacy. Chi le cambia deve trovarle in due posti.
- Il risultato dipende dalla data: senza `oggi` vale la data del sistema, e un test che non la passa cambia esito con il calendario.
- La simulazione non dà sempre lo stesso riepilogo della chiusura vera: in simulazione le fatture non cambiano stato, quindi quelle che scadono in questa chiusura non contano per le sospensioni della fase 2.
- Rilanciata sullo stesso mese, la chiusura non emette una seconda nota di credito per lo stesso cliente, ma ricalcola le provvigioni (se il mese non è liquidato), aggiunge righe al registro e riscrive il report.
- Le query passano da `db_query()` e `db_exec()` di `legacy/inc/db.inc.php`: un errore di SQL ferma lo script con `die()`. Un test che fa fallire una query si ferma senza il riepilogo di PHPUnit.
- La chiusura scrive in sei tabelle e in un file: un refactoring si fa solo con i test di caratterizzazione che coprono queste scritture (`tests/Integrazione/ChiusuraMeseTest.php`), verdi prima e dopo ogni passo.
