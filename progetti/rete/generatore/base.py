"""Strumenti di base del generatore: numeri pseudo-casuali, orari, MAC.

Il generatore deve dare file identici byte per byte con ogni Python dalla 3.8
in poi: per questo usa un generatore pseudo-casuale esplicito (SplitMix64) e
non usa mai hash() su stringhe, insiemi non ordinati o funzioni trascendenti.
"""

from datetime import datetime, timedelta, timezone

SEED = 20260907

# Ora italiana nella settimana sintetica: ora legale, UTC+2.
TZ = timezone(timedelta(hours=2))
UTC = timezone.utc
WEEK_START = datetime(2026, 9, 7, 0, 0, 0, tzinfo=TZ)
DAYS = [WEEK_START + timedelta(days=i) for i in range(7)]
WEEK_END = WEEK_START + timedelta(days=7)

_MASK64 = (1 << 64) - 1
_MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
           "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
_WEEKDAYS = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]


def fnv1a64(text):
    """Impronta FNV-1a a 64 bit di una stringa (stabile, a differenza di hash())."""
    value = 0xCBF29CE484222325
    for byte in text.encode("utf-8"):
        value ^= byte
        value = (value * 0x100000001B3) & _MASK64
    return value


class Rng:
    """SplitMix64: piccolo, esplicito, identico su ogni versione di Python."""

    def __init__(self, seed):
        self.state = seed & _MASK64

    def _next(self):
        self.state = (self.state + 0x9E3779B97F4A7C15) & _MASK64
        z = self.state
        z = ((z ^ (z >> 30)) * 0xBF58476D1CE4E5B9) & _MASK64
        z = ((z ^ (z >> 27)) * 0x94D049BB133111EB) & _MASK64
        return z ^ (z >> 31)

    def fork(self, label):
        """Un flusso indipendente per ogni sorgente, legato a un'etichetta."""
        return Rng(SEED ^ fnv1a64(label))

    def random(self):
        return (self._next() >> 11) / float(1 << 53)

    def randrange(self, start, stop=None):
        if stop is None:
            start, stop = 0, start
        span = stop - start
        if span <= 0:
            raise ValueError("randrange: intervallo vuoto")
        return start + self._next() % span

    def randint(self, low, high):
        return self.randrange(low, high + 1)

    def chance(self, probability):
        return self.random() < probability

    def choice(self, items):
        return items[self.randrange(len(items))]

    def shuffled(self, items):
        result = list(items)
        for i in range(len(result) - 1, 0, -1):
            j = self.randrange(i + 1)
            result[i], result[j] = result[j], result[i]
        return result

    def sample(self, items, count):
        return self.shuffled(items)[:count]

    def hexstr(self, digits):
        return "".join("0123456789abcdef"[self.randrange(16)]
                       for _ in range(digits))


def root_rng():
    return Rng(SEED)


# --- orari -----------------------------------------------------------------

def at(day, hour=0, minute=0, second=0):
    """Istante del giorno `day` (0 = lunedì 2026-09-07) in ora italiana."""
    return DAYS[day] + timedelta(hours=hour, minutes=minute, seconds=second)


def secs(seconds):
    return timedelta(seconds=seconds)


def iso(moment):
    """2026-09-07T08:15:00+02:00"""
    return moment.astimezone(TZ).strftime("%Y-%m-%dT%H:%M:%S+02:00")


def iso_utc_skewed(moment):
    """Orario di un apparato con l'orologio in UTC, letto dal collettore come
    se fosse ora italiana: due ore indietro rispetto agli altri."""
    shifted = moment.astimezone(UTC).replace(tzinfo=TZ)
    return iso(shifted)


def day_of(moment):
    return (moment.astimezone(TZ) - WEEK_START).days


def ctime_style(moment):
    """Mon Sep  7 08:15:00 2026 (stile dei log di FreeRADIUS)."""
    m = moment.astimezone(TZ)
    return "%s %s %2d %02d:%02d:%02d %d" % (
        _WEEKDAYS[m.weekday()], _MONTHS[m.month - 1], m.day,
        m.hour, m.minute, m.second, m.year)


def cisco_clock(moment):
    """08:15:00 CEST Mon Sep 7 2026"""
    m = moment.astimezone(TZ)
    return "%02d:%02d:%02d CEST %s %s %d %d" % (
        m.hour, m.minute, m.second, _WEEKDAYS[m.weekday()],
        _MONTHS[m.month - 1], m.day, m.year)


def kea_time(moment, millis):
    m = moment.astimezone(TZ)
    return "%s.%03d" % (m.strftime("%Y-%m-%d %H:%M:%S"), millis)


def ros_time(moment):
    return moment.astimezone(TZ).strftime("%Y-%m-%d %H:%M:%S")


# --- indirizzi MAC (RFC 7042: 00:00:5e:00:53:00-ff) ---------------------------

def mac(index):
    if not 0 <= index <= 0xFF:
        raise ValueError("MAC fuori dall'intervallo di documentazione")
    return "00:00:5e:00:53:%02x" % index


def mac_upper(index):
    return mac(index).upper()


def mac_dotted(index):
    """0000.5e00.53xx (stile Cisco)"""
    return "0000.5e00.53%02x" % index


def lines_to_text(lines):
    return "\n".join(lines) + "\n"
