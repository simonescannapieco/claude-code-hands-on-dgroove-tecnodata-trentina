# NOTA — il filtro dei ticket per apparato e per date

Il punto in cui è il lavoro, per riprenderlo in una sessione nuova.

## Fatto

- R1, R2: `FiltroTicket::$apparatoId`; `TicketRepository::cerca()` lo cerca
  nel ticket, nel ticket padre e nella linea (`:apparato IN (…)`, con le
  due LEFT JOIN solo quando serve).
- R3, R4: `$dal` e `$al`, sul giorno locale di `aperto_il`
  (`substr(t.aperto_il, 1, 10)`, regola 5.5), combinati con gli altri
  criteri.
- R5: un intervallo rovesciato nel costruttore lancia
  `InvalidArgumentException`.
- R6: `daParametri()` legge `apparato`, `dal`, `al`; i valori non validi
  si ignorano.
- R7: i tre campi nel modulo di `templates/ticket_elenco.php`.
- I test: `tests/Unit/Ticket/FiltroTicketTest.php` (R5, R6) e i casi di
  accettazione 1–8 in `tests/Integrazione/TicketRepositoryTest.php`.

## Manca

- Niente di SPECIFICA.md. Da provare a mano: la pagina Ticket. Dalla
  cartella del gestionale, `../../tools/php.sh php bin/inizializza-db.php`
  e poi `../../tools/php.sh serve public 8080`.

## Per riprendere

- Il controllo, dalla cartella dello spazio di lavoro:
  `tools/php.sh php progetti/gestionale-php/vendor/bin/phpunit -c progetti/gestionale-php`
- Prima di un commit: `git diff` dal primo commit, e `@agent-revisore` per
  confrontarlo con SPECIFICA.md.
