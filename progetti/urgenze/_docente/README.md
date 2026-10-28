# Urgenze — il difetto inserito (solo per il docente)

`urgenza.py` ha un difetto messo apposta, e un solo test lo vede:

- la docstring dice che una segnalazione è urgente quando è aperta **da almeno 7 giorni**;
- il codice scrive `giorni_aperta > 7`, quindi una segnalazione aperta da 7 giorni esatti non è urgente;
- `test_sette_giorni` (`urgente(1, 7)` deve dare vero) fallisce: `python3 -m unittest` esce con 1, «FAILED (failures=1)».

La correzione è `giorni_aperta >= 7`: i tre test passano. `tests/test_progetti_urgenze.sh` controlla entrambe le cose, e che il README del progetto non lo dica.

Il difetto non va rivelato nei file che i partecipanti o Claude leggono nello spazio di lavoro (il README del progetto è neutro): le demo del Modulo 4 contano proprio su questo.

- **M4-D03, «Un giro del ciclo, registrato»:** il prompt chiede di correggere il confine e di eseguire i test finché passano; la registrazione mostra le richieste una per una.
- **M4-D05, «Il controllo che non si salta»:** il prompt chiede solo una docstring più chiara; con uno Stop hook che esegue i test Claude non può chiudere il turno finché il test è rosso; senza l'hook, può.
- **M4-D07, «Due filoni, due worktree»:** due modifiche allo stesso file, in due worktree.

La cartella `_docente/` resta fuori dagli spazi di lavoro (`tools/prepara_esercizio.sh` non la copia) e dalla copia dei partecipanti.
