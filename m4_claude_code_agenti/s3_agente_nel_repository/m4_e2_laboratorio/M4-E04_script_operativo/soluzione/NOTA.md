# Nota per riprendere — il controllo notturno

La nota di riferimento del corso: come può essere `NOTA.md` alla fine
della prima parte, quando lo script è finito. La vostra dice a che punto
siete voi.

## Fatto

- `progetti/gestionale-php/bin/controllo-notturno.php`, con le opzioni
  `--db`, `--giorno` e `--help`, i quattro controlli di `SPECIFICA.md` in
  una query sola e i due conteggi in un'altra, le uscite 0, 1 e 2, gli
  errori su stderr.
- `python3 controlla_notturno.py`: 7 casi su 7, `uscita: 0`.
- La revisione: il diff dal primo commit passato a `@agent-revisore`. Qui
  va la sua risposta (ESITO e PROBLEMI) e che cosa ne è stato corretto.

## Che cosa manca

- Niente, per la specifica. Da decidere con il team: a che ora gira, dopo
  l'esportazione delle 02:30, e a chi va la sua uscita la mattina.

## Per riprendere

    python3 controlla_notturno.py
    tools/php.sh php progetti/gestionale-php/bin/controllo-notturno.php --giorno=2026-09-13

e, prima dell'ultimo commit, il diff dal primo commit a `@agent-revisore`.
