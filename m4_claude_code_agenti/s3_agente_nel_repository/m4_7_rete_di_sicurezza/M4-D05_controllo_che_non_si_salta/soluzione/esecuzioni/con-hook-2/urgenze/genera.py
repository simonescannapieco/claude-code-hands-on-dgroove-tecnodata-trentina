#!/usr/bin/env python3
"""Genera il piccolo progetto delle urgenze di CiaspoLink.

Uso:
  python3 genera.py              rigenera i file accanto a questo script
  python3 genera.py --out DIR    rigenera in un'altra cartella
  python3 genera.py --check      rigenera in una cartella temporanea e
                                 confronta byte per byte con i file presenti

Uscita: 0 tutto in ordine, 1 file diversi, 2 errore.
Python 3.8 o successivo, solo libreria standard. Il progetto non contiene
persone, indirizzi né altri dati sintetici: solo una regola e i suoi test.
"""

import sys

sys.dont_write_bytecode = True

import argparse  # noqa: E402
import filecmp  # noqa: E402
import os  # noqa: E402
import tempfile  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))

URGENZA = '''"""Urgenza di una segnalazione di guasto.

Una segnalazione è urgente quando coinvolge almeno 10 clienti
oppure quando è aperta da almeno 7 giorni.
"""


def urgente(clienti, giorni_aperta):
    return clienti >= 10 or giorni_aperta > 7
'''

TEST_URGENZA = '''import unittest

from urgenza import urgente


class TestUrgenza(unittest.TestCase):
    def test_dieci_clienti(self):
        self.assertTrue(urgente(10, 0))

    def test_pochi_clienti_appena_aperta(self):
        self.assertFalse(urgente(3, 1))

    def test_sette_giorni(self):
        self.assertTrue(urgente(1, 7))


if __name__ == "__main__":
    unittest.main()
'''

FILES = {
    "urgenza.py": URGENZA,
    "test_urgenza.py": TEST_URGENZA,
}


def write_all(out):
    """Scrive i file del progetto nella cartella out."""
    os.makedirs(out, exist_ok=True)
    for name, text in FILES.items():
        with open(os.path.join(out, name), "w", encoding="utf-8",
                  newline="\n") as fh:
            fh.write(text)


def check():
    """Rigenera in una cartella temporanea e confronta. Uscita 0 o 1."""
    with tempfile.TemporaryDirectory(prefix="urgenze-") as tmp:
        write_all(tmp)
        different = [name for name in sorted(FILES)
                     if not os.path.isfile(os.path.join(HERE, name))
                     or not filecmp.cmp(os.path.join(tmp, name),
                                        os.path.join(HERE, name),
                                        shallow=False)]
    if different:
        print("genera.py --check: %d file non corrispondono: %s"
              % (len(different), ", ".join(different)), file=sys.stderr)
        return 1
    print("genera.py --check: %d file identici" % len(FILES))
    return 0


def main(argv):
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--check", action="store_true",
                       help="confronta con i file presenti")
    group.add_argument("--out", metavar="DIR",
                       help="rigenera in un'altra cartella")
    args = parser.parse_args(argv)
    try:
        if args.check:
            return check()
        write_all(args.out or HERE)
    except OSError as exc:
        print("genera.py: errore: %s" % exc, file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
