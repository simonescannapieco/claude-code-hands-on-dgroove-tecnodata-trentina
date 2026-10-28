# Urgenze — un modulo minimo di CiaspoLink

Il progetto più piccolo dei quattro: la regola con cui l'assistenza di CiaspoLink S.r.l. (l'operatore immaginario di `progetti/README.md`) decide se una segnalazione di guasto è urgente, in un modulo Python di poche righe, con i suoi test. Serve alle demo del Modulo 4 sul ciclo degli strumenti, sui controlli e sui worktree: un esempio abbastanza piccolo da leggere per intero su una slide.

| file | che cosa contiene |
|---|---|
| `urgenza.py` | la funzione `urgente(clienti, giorni_aperta)` e, nella docstring, la regola |
| `test_urgenza.py` | tre test `unittest` della funzione |
| `genera.py` | il generatore: `python3 genera.py --check` dice se i file sono quelli originali |

I test si lanciano dalla cartella del progetto:

    python3 -m unittest

Solo libreria standard, Python 3.8 o successivo; nessun dato su persone, aziende o sistemi.
