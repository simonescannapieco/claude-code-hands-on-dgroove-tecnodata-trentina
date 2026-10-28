"""Urgenza di una segnalazione di guasto.

Una segnalazione è urgente quando vale almeno una di queste condizioni:

- coinvolge 10 clienti o più;
- è aperta da 7 giorni o più.

La funzione `urgente(clienti, giorni_aperta)` restituisce True se la
segnalazione è urgente, False altrimenti.

Esempio:

    >>> urgente(clienti=12, giorni_aperta=1)
    True
    >>> urgente(clienti=3, giorni_aperta=2)
    False
"""


def urgente(clienti, giorni_aperta):
    return clienti >= 10 or giorni_aperta >= 7
