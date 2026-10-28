"""Urgenza di una segnalazione di guasto.

Una segnalazione è urgente se vale almeno una di queste condizioni:

- coinvolge 10 clienti o più;
- è aperta da 7 giorni o più.

Le soglie sono incluse: con esattamente 10 clienti, oppure con
esattamente 7 giorni, la segnalazione è già urgente.

Esempio d'uso:

    >>> from urgenza import urgente
    >>> urgente(10, 0)   # soglia sui clienti raggiunta
    True
    >>> urgente(1, 7)    # soglia sui giorni raggiunta
    True
    >>> urgente(3, 1)    # nessuna soglia raggiunta
    False
"""


def urgente(clienti, giorni_aperta):
    return clienti >= 10 or giorni_aperta >= 7
