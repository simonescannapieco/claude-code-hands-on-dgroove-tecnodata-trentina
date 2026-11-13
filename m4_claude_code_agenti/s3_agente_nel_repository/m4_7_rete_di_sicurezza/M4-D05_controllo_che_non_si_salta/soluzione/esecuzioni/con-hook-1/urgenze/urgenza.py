"""Valutazione dell'urgenza di una segnalazione di guasto.

Una segnalazione è urgente se soddisfa almeno una di queste condizioni:

- coinvolge 10 o più clienti;
- è aperta da 7 o più giorni.

Esempio d'uso:

    >>> from urgenza import urgente
    >>> urgente(clienti=10, giorni_aperta=1)
    True
    >>> urgente(clienti=3, giorni_aperta=7)
    True
    >>> urgente(clienti=3, giorni_aperta=6)
    False
"""


def urgente(clienti, giorni_aperta):
    return clienti >= 10 or giorni_aperta >= 7
