# Il controllo notturno del gestionale

Ogni notte, dopo l'esportazione delle attivazioni, un controllo legge il
database del gestionale di CiaspoLink, l'operatore inventato del corso
(un progetto sintetico), e segnala le incoerenze che il lavoro di ogni
giorno lascia indietro: chi le trova la mattina le sistema prima che
diventino un reclamo o una fattura sbagliata. Il controllo non c'è ancora:
questa è la sua specifica.

## Il comando

    php bin/controllo-notturno.php [--db=percorso] [--giorno=AAAA-MM-GG] [--help]

nella cartella del gestionale, come gli altri script di `bin/`. Dalla
cartella dello spazio di lavoro, con `tools/php.sh`:

    tools/php.sh php progetti/gestionale-php/bin/controllo-notturno.php --giorno=2026-09-13

| opzione | che cosa fa |
|---|---|
| `--db=percorso` | il database; senza, quello di `config/config.php` (`var/gestionale.sqlite`), come negli altri script |
| `--giorno=AAAA-MM-GG` | il giorno del controllo; senza, la data del giorno in cui il controllo gira. I dati di esempio finiscono domenica 13 settembre 2026: per provarli, `--giorno=2026-09-13` |
| `--help` | stampa l'uso, con le opzioni `--db` e `--giorno`, su stdout ed esce con 0 |

## I quattro controlli

Ogni segnalazione è una riga su stdout: il nome del controllo, uno spazio,
l'identificativo, uno spazio e un dettaglio a scelta, tutto su una riga.

| controllo | che cosa segnala | identificativo |
|---|---|---|
| `linea-cliente-cessato` | una linea che non è cessata (stato diverso da `cessata`) di un cliente cessato (stato `cessato`): la fatturazione mensile la fattura ancora | la linea, `LN-…` |
| `linea-senza-apparato` | una linea attiva (stato `attiva`) senza apparato (`apparato_id` vuoto) o senza porta (`porta` vuota) | la linea, `LN-…` |
| `attivazione-ferma` | un'attivazione in verifica tecnica (stato `verifica_tecnica`) il cui ultimo aggiornamento (`aggiornata_il`) è di più di 30 giorni prima del giorno del controllo | l'attivazione, `AT-…` |
| `ticket-in-attesa` | un ticket in attesa del cliente (stato `in_attesa_cliente`) il cui ultimo aggiornamento (`aggiornato_il`) è di più di 21 giorni prima del giorno del controllo | il ticket, `TK-…` |

Le righe vanno nell'ordine della tabella e, dentro ogni controllo, per
identificativo. I giorni si contano fra date: il giorno di `aggiornata_il`
o di `aggiornato_il` sono i suoi primi dieci caratteri, il giorno locale
(regola 5.5 delle convenzioni). Un aggiornamento di esattamente 30 giorni
prima (21 per i ticket) non è ancora una segnalazione; di 31 (22) sì.

## I due conteggi

Le fatture scadute e i clienti sospesi non sono incoerenze: li gestisce la
chiusura di fine mese (`bin/chiusura-mese.php`). Il controllo li conta e
basta, nelle ultime due righe, sempre, anche quando non segnala niente:

    fatture-scadute <numero>
    clienti-sospesi <numero>

`fatture-scadute` conta le fatture (tipo `fattura`, non le note di credito)
con stato `scaduta`; `clienti-sospesi` i clienti con stato `sospeso`. I
conteggi non cambiano l'uscita.

## Un esempio

Con identificativi inventati, che nei dati di esempio non ci sono:

    linea-cliente-cessato LN-009001 cliente CL-009001 cessato, linea attiva
    attivazione-ferma AT-2026-0901 in verifica tecnica dal 2026-05-30
    fatture-scadute 2
    clienti-sospesi 1

## Uscita, stdout e stderr

| uscita | quando |
|---|---|
| 0 | nessuna segnalazione |
| 1 | almeno una segnalazione |
| 2 | il controllo non può girare: il database non c'è, `--giorno` non è una data valida, un'opzione sconosciuta, una query che non riesce |

Su stdout soltanto le righe delle segnalazioni e dei conteggi; su stderr
soltanto i messaggi di errore, con il motivo. Con il database che manca il
controllo esce con 2 **senza crearlo**: un file vuoto al suo posto
fermerebbe `bin/inizializza-db.php` la notte dopo. Il controllo legge
soltanto: non modifica il database e non scrive file.

## Dove sta il codice e come si scrive

- Tutto in `bin/controllo-notturno.php`, come gli altri script di `bin/`:
  l'uso e le uscite nel commento in testa, le opzioni con `getopt`, il
  database da `Applicazione::avvia`, gli errori con `fwrite(STDERR, …)`.
  Il controllo legge con le sue query: per uno script che legge soltanto,
  il team le accetta nello script, preparate (regola 7.1) e mai dentro un
  ciclo (7.3). `src/` e `legacy/` non si toccano.
- Le convenzioni di `progetti/gestionale-php/docs/convenzioni.md`, in
  particolare 2.1 (PSR-12: `phpcs` pulito), 2.2, 2.3 e 6.4; per i commit,
  11.1.

## Come si prova

`python3 controlla_notturno.py`, dalla cartella dello spazio di lavoro,
prova lo script come lo proverebbe la notte. Crea due piccoli database di
prova in `progetti/gestionale-php/var/controllo-notturno/`, uno con
un'incoerenza o due per ogni controllo e uno senza, e vi esegue lo script;
poi lo esegue senza database, con un giorno non valido, con un'opzione
sconosciuta, con `--help`, e ne controlla lo stile con `phpcs`. Per ogni
caso confronta uscita, stdout e stderr con questa specifica e stampa `ok`
o `NO` con il motivo; l'ultima riga dice `uscita: 0` se tutto torna,
`uscita: 1` se qualcosa no, `uscita: 2` se il controllo non può girare (per
esempio perché lo script non c'è ancora). Alla fine cancella i database di
prova. Non sa quali incoerenze ci sono nei dati di esempio: quello lo dice
lo script.
