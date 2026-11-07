# Gestionale CiaspoLink

Il gestionale PHP sta in `progetti/gestionale-php/`; `tools/php.sh` esegue PHP, Composer e PHPUnit anche dove PHP non c'è.

## Comandi

- Dalla cartella `progetti/gestionale-php/`: `../../tools/php.sh composer install` se manca `vendor/`, poi `../../tools/php.sh phpunit`.

## Convenzioni che il codice non dice

- Ogni commit ha nel messaggio una riga `Rif: GES-<n>`, il numero della richiesta nel tracker del team; `Rif: GES-0` per la manutenzione, come un refuso.
- Il soggetto segue `docs/convenzioni.md`, 11.1: `tipo(ambito): descrizione`, all'indicativo presente.

## Insidie

- `database/dati/` e `composer.lock` si rigenerano, non si modificano: i dati con `python3 genera.py`, le dipendenze con Composer.
