"""Urgenza di una segnalazione di guasto.

Una segnalazione è urgente se vale almeno una di queste due condizioni:

* coinvolge almeno 10 clienti;
* è aperta da almeno 7 giorni.

Esempio d'uso:

    >>> urgente(clienti=12, giorni_aperta=1)
    True
    >>> urgente(clienti=3, giorni_aperta=1)
    False
"""


def urgente(clienti, giorni_aperta):
    return clienti >= 10 or giorni_aperta > 7
