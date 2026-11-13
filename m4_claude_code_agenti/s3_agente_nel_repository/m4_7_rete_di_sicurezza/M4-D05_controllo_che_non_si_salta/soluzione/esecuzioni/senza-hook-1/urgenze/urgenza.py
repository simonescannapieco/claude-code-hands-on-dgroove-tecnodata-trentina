"""Urgenza di una segnalazione di guasto.

Una segnalazione è urgente se vale almeno una di queste due condizioni:

- coinvolge almeno 10 clienti;
- è aperta da almeno 7 giorni.

Esempio d'uso:

    >>> from urgenza import urgente
    >>> urgente(clienti=12, giorni_aperta=1)   # molti clienti coinvolti
    True
    >>> urgente(clienti=2, giorni_aperta=15)   # aperta da molto tempo
    True
    >>> urgente(clienti=3, giorni_aperta=1)    # nessuna delle due condizioni
    False
"""


def urgente(clienti, giorni_aperta):
    return clienti >= 10 or giorni_aperta > 7
