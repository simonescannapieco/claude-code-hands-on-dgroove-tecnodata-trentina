# CLAUDE.md

Gestionale PHP 8.3 di CiaspoLink (operatore di connettività immaginario) in `progetti/gestionale-php/`, con codice nuovo in `src/` e vecchio gestionale in `legacy/`.

## Comandi

Si lanciano dalla cartella `progetti/gestionale-php/`. PHP sul portatile spesso non c'è: mai `php` o `composer` diretti, solo `../../tools/php.sh`.

- Prima volta: `../../tools/php.sh composer install`
- Test: `../../tools/php.sh phpunit` (uno solo: `../../tools/php.sh phpunit --filter NomeDelTest`)
- Stile PSR-12: `../../tools/php.sh php vendor/bin/phpcs`
- Script di `bin/`: `../../tools/php.sh php bin/<script>.php`
- Dati di esempio: `python3 genera.py` li rigenera, `python3 genera.py --check` li verifica

## Convenzioni che il codice non dice

- Prima di scrivere o rivedere codice leggi `progetti/gestionale-php/docs/convenzioni.md`; nelle revisioni cita il numero della regola.
- Ogni commit: soggetto `tipo(ambito): descrizione` in italiano (regola 11.1), poi una riga `Rif: GES-<n>` con il numero della richiesta nel tracker; per la manutenzione senza richiesta `Rif: GES-0`. Il tracker non è collegato al repository: quella riga è l'unico legame.
- Prima di chiedere la revisione, `phpunit` e `phpcs` devono passare senza errori.
