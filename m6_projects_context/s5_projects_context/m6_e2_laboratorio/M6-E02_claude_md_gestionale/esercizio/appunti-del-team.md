# Appunti del team del gestionale

Gli appunti che il team del gestionale tiene da quando ci lavora: un po' di
tutto, scritto da persone diverse in momenti diversi. Stanno qui, accanto al
progetto, e non nel suo repository.

## Dalla riunione di giovedì 10 settembre 2026

- Da adesso ogni commit ha nel messaggio una riga `Rif: GES-<n>`, con il
  numero della richiesta nel nostro tracker. La manutenzione che non ha una
  richiesta, come un refuso o una pulizia, porta `Rif: GES-0`. Il tracker
  non è collegato al repository: questa riga è l'unico legame fra i due.
- Il soggetto dei commit resta quello di `docs/convenzioni.md`, la regola
  11.1: `tipo(ambito): descrizione`, all'indicativo presente.

## Come lavoriamo

- PHP sul portatile ce l'hanno in pochi: ogni comando passa da
  `tools/php.sh`, che usa le immagini Docker quando PHP non c'è. Dalla
  cartella `progetti/gestionale-php/`, la prima volta
  `../../tools/php.sh composer install`, poi `../../tools/php.sh phpunit`
  per i test.
- Il CSV delle attivazioni che ogni notte va al magazzino ha il punto e
  virgola come separatore.
- In `legacy/` si corregge un difetto e basta: niente funzionalità nuove,
  prima un test di caratterizzazione, mai una riformattazione insieme a una
  correzione. Sono le regole della sezione 9 di `docs/convenzioni.md`.
- `database/dati/` e `composer.lock` non si modificano mai a mano: i dati
  si rigenerano con `python3 genera.py`, le dipendenze con Composer.

## La fatturazione di inizio mese

1. Il giorno 1, prima la simulazione, dalla cartella del gestionale:
   `../../tools/php.sh php bin/fatturazione-mensile.php --simula`.
2. I totali della simulazione vanno all'amministrazione, che li confronta
   con quelli del mese prima.
3. Con il loro via libera si lancia il giro vero, senza `--simula`.
4. Se qualcosa non torna non si rilancia: si apre una richiesta nel tracker
   e si avvisa Paolo Fittizio.

## Preferenze

- Giulia Esempio: «Quando Claude mi spiega del codice, mi piace che dica il
  file e il numero di riga.»
