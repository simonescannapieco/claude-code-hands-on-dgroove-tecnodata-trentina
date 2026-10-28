# Nota per riprendere — il rapporto quotidiano dei disservizi

La nota di riferimento del corso: come può essere `NOTA.md` alla fine
della prima parte, quando lo script è finito. La vostra dice a che punto
siete voi.

## Fatto

- `rapporto_giornaliero.py` (Python 3.8 o successivo, solo libreria
  standard), con le opzioni `--giorno`, `--log` e `--help`; i cinque tipi
  di disservizio di `SPECIFICA.md`, dal syslog, dal log dell'SBC e dal log
  del DHCP; una riga per disservizio, sei campi separati da un TAB, in
  ordine di inizio; le uscite 0, 1 e 2, gli errori su stderr.
- `python3 controlla_rapporto.py`: 8 casi su 8, `uscita: 0`.
- La revisione: il diff dal primo commit passato a `@agent-revisore`. Qui
  va la sua risposta (ESITO e PROBLEMI) e che cosa ne è stato corretto.

## Che cosa manca

- Niente, per la specifica. Da decidere con il team: a che ora gira, e a
  chi va il rapporto la mattina.

## Per riprendere

    python3 controlla_rapporto.py
    python3 rapporto_giornaliero.py --giorno 2026-09-08

e, prima dell'ultimo commit, il diff dal primo commit a `@agent-revisore`.
