"""La settimana sintetica: calendario, orari e caso controllato.

Da lunedì 2026-09-07 a domenica 2026-09-13, ora legale italiana (+02:00). Il
generatore pseudo-casuale ha un seme fisso ed è usato solo attraverso
random(): gli stessi numeri su ogni Python dalla 3.8 alla 3.14, perché
l'algoritmo di random() e il calcolo in virgola mobile delle moltiplicazioni
sono gli stessi ovunque (niente funzioni trascendenti, niente hash()).
"""

import datetime as dt
import random
from typing import Sequence, Tuple

SEME = 20260907
FUSO = dt.timezone(dt.timedelta(hours=2))  # ora legale italiana (CEST)
LUNEDI = dt.datetime(2026, 9, 7, tzinfo=FUSO)
FINE_SETTIMANA = dt.datetime(2026, 9, 13, 23, 59, 59, tzinfo=FUSO)
# Orari in minuti dalla mezzanotte, da lunedì a domenica: assistenza con
# operatore, tecnici sul campo, uffici (amministrazione e commerciale).
ORARI = {
    "operatori": (((480, 1140),),) * 5 + (((510, 750),), ()),
    "campo": (((510, 1050),),) * 5 + (((510, 750),), ()),
    "ufficio": (((540, 1050),),) * 5 + ((), ()),
}
ORARIO_TEAM = {"primo_livello": "operatori", "voce": "operatori",
               "servizi_it": "operatori", "tecnici_campo": "campo",
               "amministrazione": "ufficio", "commerciale": "ufficio"}


class Caso:
    """Il generatore pseudo-casuale, usato solo attraverso random()."""

    def __init__(self, seme: int) -> None:
        self._r = random.Random(seme)

    def unif(self) -> float:
        return self._r.random()

    def intero(self, minimo: int, massimo: int) -> int:
        """Un intero tra minimo e massimo, estremi inclusi."""
        return minimo + int(self._r.random() * (massimo - minimo + 1))

    def scegli(self, voci: Sequence):
        return voci[int(self._r.random() * len(voci))]

    def pesato(self, coppie: Sequence[Tuple[object, int]]):
        """Sceglie da coppie (voce, peso intero)."""
        resto = self._r.random() * sum(p for _, p in coppie)
        for voce, peso in coppie:
            resto -= peso
            if resto < 0:
                return voce
        return coppie[-1][0]

    def probabile(self, p: float) -> bool:
        return self._r.random() < p


def istante(giorno: int, ora: str, secondi: int = 0) -> dt.datetime:
    """Il momento `ora` (HH:MM) del giorno `giorno` (0 = lunedì)."""
    h, m = (int(x) for x in ora.split(":"))
    return LUNEDI + dt.timedelta(days=giorno, hours=h, minutes=m,
                                 seconds=secondi)


def minuti_tra(da: dt.datetime, a: dt.datetime) -> int:
    return (a - da) // dt.timedelta(minutes=1)


def nell_intervallo(caso: Caso, inizio: dt.datetime, fine: dt.datetime,
                    inclinato: bool = False) -> dt.datetime:
    """Un istante tra inizio e fine; `inclinato` lo avvicina all'inizio."""
    u = caso.unif()
    if inclinato:
        u = u * u
    secondi = (fine - inizio) // dt.timedelta(seconds=1)
    return inizio + dt.timedelta(seconds=int(secondi * u))


def in_orario(t: dt.datetime, orario: str) -> bool:
    minuto = t.hour * 60 + t.minute
    return any(a <= minuto < b for a, b in ORARI[orario][t.weekday()])


def allinea(caso: Caso, t: dt.datetime, orario: str) -> dt.datetime:
    """Sposta t alla prima finestra di `orario` (t stesso, se ci cade già)."""
    for _ in range(9):
        minuto = t.hour * 60 + t.minute
        for inizio, fine in ORARI[orario][t.weekday()]:
            if inizio <= minuto < fine:
                return t
            if minuto < inizio:
                base = t.replace(hour=inizio // 60, minute=inizio % 60)
                return base + dt.timedelta(minutes=caso.intero(2, 40))
        t = (t + dt.timedelta(days=1)).replace(hour=0, minute=0)
    return t


def mescola(caso: Caso, voci: Sequence) -> list:
    """Una copia mescolata (Fisher-Yates) di voci."""
    copia = list(voci)
    for i in range(len(copia) - 1, 0, -1):
        j = caso.intero(0, i)
        copia[i], copia[j] = copia[j], copia[i]
    return copia
