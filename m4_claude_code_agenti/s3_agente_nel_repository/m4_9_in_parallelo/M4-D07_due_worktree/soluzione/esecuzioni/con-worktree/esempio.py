"""Urgenza di una segnalazione di guasto.

Una segnalazione è urgente quando coinvolge almeno 10 clienti
oppure quando è aperta da almeno 7 giorni.

Esempio d'uso:

>>> urgente(10, 0)
True
>>> urgente(2, 1)
False
"""


def urgente(clienti, giorni_aperta):
    return clienti >= 10 or giorni_aperta > 7
