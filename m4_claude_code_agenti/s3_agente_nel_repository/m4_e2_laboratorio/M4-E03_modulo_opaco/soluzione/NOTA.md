# NOTA — fine della prima parte

## Che cosa è fatto

- La mappa di `chiusura_mese()`, dai due riassunti dei subagent Explore:
  chi la chiama e quali tabelle legge e scrive.
- La documentazione, `progetti/gestionale-php/docs/chiusura_mese.md`,
  con le sei sezioni, nel suo commit.
- I test di caratterizzazione,
  `progetti/gestionale-php/tests/Integrazione/ChiusuraMeseTest.php`,
  verdi sul modulo com'è, nel loro commit.

## Che cosa resta per la seconda parte

- La proposta di refactoring di `chiusura_mese()`, in plan mode:
  `PROPOSTA.md` nella radice dello spazio di lavoro, a passi piccoli,
  ciascuno con la sua riga «Controllo:» che esegue i test.
- `progetti/gestionale-php/legacy/` resta com'è.

## I comandi per riprendere

- Dalla radice dello spazio di lavoro, `claude`, poi plan mode
  (Shift+Tab) e il prompt 5 del README.
- I test di caratterizzazione:
  `tools/php.sh php progetti/gestionale-php/vendor/bin/phpunit -c progetti/gestionale-php progetti/gestionale-php/tests/Integrazione/ChiusuraMeseTest.php`
