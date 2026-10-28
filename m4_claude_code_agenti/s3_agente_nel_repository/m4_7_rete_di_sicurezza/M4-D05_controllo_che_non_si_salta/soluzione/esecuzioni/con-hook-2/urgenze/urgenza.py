"""Urgenza di una segnalazione di guasto.

Una segnalazione è urgente se vale almeno una di queste due condizioni:

- coinvolge 10 clienti o più;
- è aperta da 7 giorni o più.

Esempio d'uso:

    >>> urgente(clienti=10, giorni_aperta=0)
    True
    >>> urgente(clienti=1, giorni_aperta=7)
    True
    >>> urgente(clienti=3, giorni_aperta=1)
    False
"""


def urgente(clienti, giorni_aperta):
    return clienti >= 10 or giorni_aperta >= 7
