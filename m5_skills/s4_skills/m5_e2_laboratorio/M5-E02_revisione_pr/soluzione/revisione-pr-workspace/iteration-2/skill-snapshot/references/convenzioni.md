# Convenzioni del team

Come scriviamo e come rivediamo il codice del gestionale. Valgono per ogni pull request: chi fa la revisione cita il numero della regola (per esempio «7.3»), chi scrive il codice può usarle come lista di controllo prima di chiedere la revisione.

## 1. Dove valgono

1.1 **Codice nuovo**: `src/`, `bin/`, `public/index.php`, `templates/`, `tests/`, `config/`. Valgono tutte le regole.

1.2 **Codice legacy**: `legacy/`. Valgono solo le regole della sezione 9; il resto si applica al codice che ne esce.

1.3 **File generati**: `database/dati/*.sql` e `composer.lock` non si modificano a mano. I dati si rigenerano con `python3 genera.py`, le dipendenze con Composer.

## 2. Stile

2.1 Il codice segue PSR-12. `vendor/bin/phpcs` (configurato da `phpcs.xml.dist`) termina senza errori. *Verifica:* `tools/php.sh php vendor/bin/phpcs`.

2.2 Ogni file PHP nuovo inizia con `declare(strict_types=1);`.

2.3 Righe di al massimo 120 caratteri.

2.4 Una classe per file. Il namespace è `CiaspoLink\Gestionale\<Modulo>` e rispecchia la cartella sotto `src/` (PSR-4).

2.5 Niente codice commentato lasciato nei file. I TODO hanno un riferimento: `// TODO(nome): …`.

## 3. Nomi

3.1 Il dominio si scrive in italiano, con le parole del database: `Cliente`, `Linea`, `Attivazione`, `VerificaCopertura`. I termini tecnici restano in inglese quando è l'uso comune (PPPoE, DHCP, CSV).

3.2 Classi ed enum in PascalCase; metodi, proprietà e variabili in camelCase; costanti in UPPER_SNAKE_CASE.

3.3 Un repository per tabella principale, chiamato `<Entità>Repository`. I metodi hanno verbi brevi: `trova`, `cerca`, `salva`, `aggiornaStato`, `perCliente`.

3.4 I metodi che rispondono sì o no iniziano con `is`, `ha` o `puo`: `isAperto()`, `puoPassareA()`.

3.5 Niente abbreviazioni, salvo quelle d'uso (id, iva, cap, ip, mac, csv).

3.6 Gli script di `bin/` hanno nome verbo-oggetto, in minuscolo con trattini: `esporta-attivazioni.php`.

## 4. Tipi

4.1 Parametri, valori di ritorno e proprietà sono sempre tipizzati. `mixed` solo ai confini, dove arrivano dati esterni (`$_GET`, righe PDO, file).

4.2 Gli array si documentano con il tipo degli elementi: `@return list<Cliente>`, `@param array<string, int> $importi`.

4.3 Le classi sono `final`, salvo un motivo scritto. Gli oggetti valore hanno proprietà `readonly`.

4.4 Stati e codici con valori chiusi sono enum (`StatoAttivazione`, `StatoTicket`), non stringhe sparse nel codice.

## 5. Importi, date e ore

5.1 Gli importi sono interi in centesimi (`int $importoCent`). Mai `float` per il denaro.

5.2 L'IVA (22 %) si calcola una volta sola, sul totale imponibile del documento, e si arrotonda al centesimo più vicino (le metà per eccesso), come dice `database/schema.sql`. Un test copre un caso in cui il risultato non è un numero intero di centesimi.

5.3 Il rateo del canone è canone × giorni di servizio nel mese ÷ giorni del mese (vedi la tabella `righe_fattura` in `database/schema.sql`).

5.4 Date e ore si salvano in ISO 8601 con l'offset del fuso Europe/Rome (`DateTimeInterface::ATOM`); le date senza ora come AAAA-MM-GG.

5.5 Per ricavare il giorno o il mese locale da una colonna con offset si usa `substr()`: le funzioni `date()`, `datetime()` e `strftime()` di SQLite convertono in UTC.

5.6 Il codice non legge l'orologio di sistema in profondità. La data «di oggi» entra come parametro (per esempio `?DateTimeImmutable $alGiorno`), così i test la possono fissare.

## 6. Errori

6.1 Gli errori sono eccezioni, non valori di ritorno speciali. Una regola di dominio violata lancia un'eccezione del modulo (`TransizioneNonConsentita extends DomainException`); un dato in ingresso non valido lancia `InvalidArgumentException`.

6.2 In `src/` niente `die()`, `exit`, `echo` e niente operatore `@`.

6.3 Niente `catch` vuoti: l'eccezione si gestisce, si rilancia o si registra con il motivo.

6.4 Gli script di `bin/` escono con 0 se il lavoro è fatto, 1 se è rifiutato (per esempio perché già fatto), 2 per un errore d'uso o di sistema. I messaggi di errore vanno su STDERR.

## 7. Database

7.1 Solo PDO con query preparate e parametri con nome. Nessun valore concatenato nell'SQL, neppure se «già ripulito».

7.2 Le query stanno nei repository e nei servizi di calcolo che fanno una sola query aggregata. Controller e template non contengono SQL.

7.3 Niente query dentro un ciclo. Se per ogni elemento serve un altro dato, si carica tutto insieme con una JOIN o con `IN (…)`.

7.4 Più scritture che devono riuscire insieme stanno in una transazione (vedi `WorkflowAttivazioni`).

7.5 Le modifiche dello schema passano da `database/schema.sql`, e da `genera.py` se cambiano i dati, nella stessa pull request, con una nota nella descrizione.

7.6 I vincoli si dichiarano nello schema (FOREIGN KEY, CHECK, UNIQUE) e `PRAGMA foreign_keys = ON` resta attivo.

## 8. Pagine web

8.1 Nei template ogni valore si stampa con `$this->e()`. I controller non costruiscono HTML.

8.2 Solo i controller ricevono `$_GET` e `$_POST`, da `public/index.php`. I servizi ricevono valori già controllati.

8.3 Le azioni che modificano dati usano POST.

## 9. Codice legacy

9.1 In `legacy/` non si aggiungono funzionalità: le novità vanno in `src/`.

9.2 `legacy/` si tocca solo per correggere un difetto o per spostare logica in `src/`. Il titolo della pull request lo dice.

9.3 Prima di cambiare un comportamento legacy si fissa quello attuale con un test di caratterizzazione: un test che descrive che cosa fa oggi il codice, anche quando è sbagliato.

9.4 Niente riformattazioni di file legacy insieme a modifiche di comportamento: rendono illeggibile la differenza.

9.5 Il codice nuovo chiama il legacy solo attraverso una classe ponte in `src/Legacy/` (come `PonteListino`), mai con `require` sparsi.

9.6 Quando una regola esiste sia in `legacy/` sia in `src/`, chi ne corregge una aggiorna anche l'altra, oppure elimina la copia legacy.

## 10. Test

10.1 I test usano PHPUnit. `tests/Unit` contiene i test senza database, `tests/Integrazione` quelli con SQLite in memoria (`Tests\Support\DatabaseDiProva`).

10.2 Ogni modifica a `src/` porta con sé test che falliscono senza la modifica.

10.3 I test hanno nomi che si leggono come frasi: `testRifiutaUnPassaggioNonPrevisto`.

10.4 I test non dipendono dalla data di oggi né dall'ordine in cui girano.

10.5 Prima di chiedere la revisione: `tools/php.sh phpunit` e `tools/php.sh php vendor/bin/phpcs` senza errori.

## 11. Commit e pull request

11.1 I messaggi di commit seguono il formato `tipo(ambito): descrizione`, all'indicativo presente e in italiano: `feat(ticket): aggiunge il filtro per apparato`. Tipi: feat, fix, refactor, test, docs, chore.

11.2 Una pull request fa una cosa sola e resta piccola: indicativamente meno di 400 righe cambiate, dati generati esclusi.

11.3 La descrizione della pull request ha quattro parti: **Cosa**, **Perché**, **Come verificare** (i comandi), **Rischi** (dati, legacy, schema).

11.4 Serve l'approvazione di una persona diversa dall'autore. Chi rivede controlla queste regole e cita il numero di quelle non rispettate.

11.5 Nel repository vanno solo dati sintetici, secondo le regole di `../README.md` (e-mail `@example.org`, indirizzi IP di documentazione e così via). Mai credenziali, mai dati di persone vere.
