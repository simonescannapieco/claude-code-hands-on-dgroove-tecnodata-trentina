import unittest

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
