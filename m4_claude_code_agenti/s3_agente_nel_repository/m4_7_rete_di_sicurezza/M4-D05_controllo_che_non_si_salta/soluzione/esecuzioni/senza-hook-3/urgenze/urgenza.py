"""Urgenza di una segnalazione di guasto.

Una segnalazione è urgente se vale almeno una di queste condizioni:

- coinvolge almeno 10 clienti;
- è aperta da almeno 7 giorni.

Le soglie sono inclusive: esattamente 10 clienti, o esattamente 7 giorni,
bastano a rendere urgente la segnalazione.

Esempio d'uso:

    >>> from urgenza import urgente
    >>> urgente(10, 0)   # soglia clienti raggiunta
    True
    >>> urgente(1, 7)    # soglia giorni raggiunta
    True
    >>> urgente(3, 1)    # nessuna soglia raggiunta
    False
"""


def urgente(clienti, giorni_aperta):
    return clienti >= 10 or giorni_aperta > 7
