"""Urgenza di una segnalazione di guasto.

Una segnalazione è urgente quando coinvolge almeno 10 clienti
oppure quando è aperta da almeno 7 giorni.

Esempio d'uso:

>>> urgente(12, 1)
True
>>> urgente(3, 2)
False
"""


def urgente(clienti, giorni_di_apertura):
    return clienti >= 10 or giorni_di_apertura > 7
