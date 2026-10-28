# Proposta di refactoring di chiusura_mese()

Il modulo `progetti/gestionale-php/legacy/chiusura_mese.inc.php` qui non si modifica: la proposta descrive i passi, da fare uno per volta, ciascuno in una pull request a sé (convenzioni 9.2, 9.4 e 11.2). Le regole del team dicono che `legacy/` si tocca per spostare logica in `src/` (9.2) e che il codice nuovo chiama il legacy attraverso una classe ponte (9.5): ogni passo porta una fase in `src/`, con i suoi test, e il modulo la chiama al posto delle sue righe.

Nessun passo cambia il comportamento. Lo prova lo stesso giudice, i test di caratterizzazione di `tests/Integrazione/ChiusuraMeseTest.php`, verdi sul modulo com'è e rossi su una copia rotta apposta: prima e dopo ogni passo devono essere tutti verdi, senza cambiarli. `chiusura_mese()` resta l'unico punto d'ingresso, con lo stesso nome, la stessa firma e lo stesso array restituito, perché la documentazione segnala un chiamante fuori dal repository.

## Passo 1 — Il giudice prima di tutto

I test di caratterizzazione fissano le scritture di ogni fase (fatture scadute, sospensioni, riattivazioni, note di credito con le righe e gli importi, registro, report), il valore restituito e la simulazione. Prima di toccare il codice si eseguono sul modulo com'è e si controlla che siano verdi.

Controllo: `tools/php.sh php progetti/gestionale-php/vendor/bin/phpunit -c progetti/gestionale-php progetti/gestionale-php/tests/Integrazione/ChiusuraMeseTest.php` — 11 test, tutti verdi.

## Passo 2 — I numeri degli indennizzi con un nome

Una classe nuova, `src/Fatturazione/RegoleIndennizzo.php` (`final`, `declare(strict_types=1)`), con le costanti `ORE_FRANCHIGIA = 24`, `IMPORTO_GIORNO_CENT = 1000`, `IMPORTO_MASSIMO_CENT = 10000` e un metodo `importoCent(float $ore): int` che restituisce 0 entro la franchigia; i suoi test unitari in `tests/Unit/Fatturazione/`. Il modulo la chiama al posto delle righe 150–158.

Controllo: `tools/php.sh php progetti/gestionale-php/vendor/bin/phpunit -c progetti/gestionale-php` — tutti verdi, i test di caratterizzazione invariati (gli stessi importi delle note di credito) e quelli nuovi.

## Passo 3 — Le fatture scadute in src/

Un servizio `src/Fatturazione/ScadenzeFatture.php` che, con la connessione e la data di riferimento ricevute come parametri (convenzioni 5.6), segna `scaduta` le fatture emesse e scadute con una query preparata (7.1) e restituisce le righe per il report. La fase 1 del modulo lo chiama e, come adesso, scrive solo fuori dalla simulazione.

Controllo: `tools/php.sh php progetti/gestionale-php/vendor/bin/phpunit -c progetti/gestionale-php` — tutti verdi, compresi i test sulle fatture scadute e sulla simulazione.

## Passo 4 — Sospensioni e riattivazioni in src/

Un servizio `src/Clienti/Morosita.php` con due metodi, `sospendi()` e `riattiva()`, che ricevono la soglia dal modulo (`$SOGLIA_MOROSITA`) e scrivono clienti, linee e nota come le fasi 2 e 3; il modulo li chiama nello stesso ordine e nella stessa transazione.

Controllo: `tools/php.sh php progetti/gestionale-php/vendor/bin/phpunit -c progetti/gestionale-php` — tutti verdi, compresi i test di sospensione, riattivazione e simulazione.

## Passo 5 — Le note di credito degli indennizzi in src/

Un servizio `src/Fatturazione/NoteCreditoIndennizzi.php` che usa `RegoleIndennizzo` del passo 2 e scrive la nota e le sue righe in una transazione (7.4), saltando il cliente che ha già la nota del periodo. Il blocco commentato delle righe 206–207 se ne va con le righe che il servizio sostituisce.

Controllo: `tools/php.sh php progetti/gestionale-php/vendor/bin/phpunit -c progetti/gestionale-php` — tutti verdi, compresi i test sulla nota di credito, sulle righe e sulla seconda chiusura dello stesso mese.

## Passo 6 — chiusura_mese() diventa una regia

Il modulo tiene la funzione con lo stesso nome e la stessa firma, ma soltanto chiama in ordine i servizi dei passi 3–5, la fase delle provvigioni com'è e un `src/Report/ReportChiusura.php` che compone l'HTML; `bin/chiusura-mese.php` non cambia.

Controllo: `tools/php.sh php progetti/gestionale-php/vendor/bin/phpunit -c progetti/gestionale-php` — tutti verdi, compresi i test sul report, sul registro e sul valore restituito.
