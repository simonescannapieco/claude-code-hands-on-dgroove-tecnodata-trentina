"""Urgenza di una segnalazione di guasto.

Una segnalazione è urgente se vale almeno una di queste due condizioni:

- coinvolge almeno 10 clienti;
- è aperta da almeno 7 giorni.

Entrambe le soglie sono incluse: 10 clienti o 7 giorni bastano già.

Esempio d'uso:

    >>> urgente(clienti=10, giorni_aperta=0)
    True
    >>> urgente(clienti=1, giorni_aperta=7)
    True
    >>> urgente(clienti=3, giorni_aperta=1)
    False
"""


def urgente(clienti, giorni_aperta):
    return clienti >= 10 or giorni_aperta > 7
