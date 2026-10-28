"""Urgenza di una segnalazione di guasto.

Regola: una segnalazione è urgente se vale almeno una di queste condizioni:

- coinvolge 10 clienti o più;
- è aperta da 7 giorni o più.

Le soglie sono incluse: esattamente 10 clienti, o esattamente 7 giorni,
bastano a rendere urgente la segnalazione.

Esempio d'uso:

    >>> from urgenza import urgente
    >>> urgente(clienti=10, giorni_aperta=0)
    True
    >>> urgente(clienti=1, giorni_aperta=7)
    True
    >>> urgente(clienti=3, giorni_aperta=1)
    False
"""


def urgente(clienti, giorni_aperta):
    return clienti >= 10 or giorni_aperta > 7
