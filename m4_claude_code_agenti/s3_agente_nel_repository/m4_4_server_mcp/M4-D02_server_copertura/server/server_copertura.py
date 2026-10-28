"""server_copertura.py -- il server MCP del corso: la copertura di
CiaspoLink, in sola lettura.

Un server MCP locale, su stdio, costruito con FastMCP 3.x (la versione è
fissata in pyproject.toml e in uv.lock). Espone un solo strumento,
cerca_copertura: per ogni comune e tecnologia (FTTH, la fibra fino a casa;
FWA, la radio) quanti indirizzi sono coperti, cioè hanno una data di
disponibilità, quanti sono pianificati, senza data, e la velocità massima.
Filtri facoltativi: il comune e la tecnologia.

I dati sono quelli, sintetici, del gestionale di CiaspoLink: la cartella
nella variabile d'ambiente COPERTURA_DATI, cioè database/ di
progetti/gestionale-php (schema.sql, dati/01_comuni.sql e
dati/02_rete.sql). All'avvio il server li carica in un database SQLite in
memoria, ne ricava la tabella della copertura e chiude il database: lo
strumento legge soltanto quella tabella e non può cambiare niente. Niente
rete, niente chiavi.

Lo avvia Claude Code (claude mcp add, oppure --mcp-config), con un
percorso assoluto in COPERTURA_DATI:
    COPERTURA_DATI=<cartella database/> \\
        uv run --directory <questa cartella> server_copertura.py
Lo STDOUT è il canale del protocollo: ogni messaggio va su STDERR.

Uscita: 2 se COPERTURA_DATI manca, non è un percorso assoluto, non indica
        la cartella con i dati del gestionale, o i dati non si leggono:
        prima di parlare il protocollo, con un messaggio su STDERR;
        altrimenti il server gira finché il client chiude lo STDIN (0).
"""
from __future__ import annotations

import os
import sqlite3
import sys
from pathlib import Path
from typing import Literal, NamedTuple, Optional

# FastMCP non controlla gli aggiornamenti: il server non usa la rete. La
# variabile si imposta prima di importare fastmcp, che la legge allora.
os.environ.setdefault("FASTMCP_CHECK_FOR_UPDATES", "off")

from fastmcp import FastMCP  # noqa: E402  (dopo la variabile qui sopra)
from fastmcp.exceptions import ToolError  # noqa: E402

FILE_DATI = ("schema.sql", "dati/01_comuni.sql", "dati/02_rete.sql")
SQL_COPERTURA = """
SELECT c.nome, c.zona, k.tecnologia,
       SUM(k.disponibile_dal IS NOT NULL),
       SUM(k.disponibile_dal IS NULL),
       MAX(k.velocita_max_mbps)
FROM copertura AS k JOIN comuni AS c ON c.id = k.comune_id
GROUP BY c.nome, c.zona, k.tecnologia
ORDER BY c.nome, k.tecnologia
"""
SQL_COMUNI = "SELECT nome FROM comuni ORDER BY nome"
ISTRUZIONI = ("La copertura di CiaspoLink per comune e tecnologia, dai dati "
              "del gestionale: un solo strumento, cerca_copertura, in sola "
              "lettura.")


class Riga(NamedTuple):
    """La copertura di un comune per una tecnologia."""
    comune: str
    zona: str
    tecnologia: str
    coperti: int
    pianificati: int
    velocita: int

    def come_dizionario(self) -> dict:
        """La riga come la restituisce lo strumento."""
        return {"comune": self.comune, "zona": self.zona,
                "tecnologia": self.tecnologia,
                "indirizzi_coperti": self.coperti,
                "indirizzi_pianificati": self.pianificati,
                "velocita_max_mbps": self.velocita}


class DatiNonValidi(Exception):
    """COPERTURA_DATI che non va, o dati che non si leggono: il server
    non parte."""


def cartella_dati() -> Path:
    """La cartella di COPERTURA_DATI, se è un percorso assoluto con i file
    del gestionale; altrimenti DatiNonValidi."""
    valore = os.environ.get("COPERTURA_DATI", "")
    if not valore.strip():
        raise DatiNonValidi("COPERTURA_DATI non è impostata: deve indicare "
                            "la cartella database/ del gestionale, con un "
                            "percorso assoluto")
    cartella = Path(valore)
    if not cartella.is_absolute():
        raise DatiNonValidi("COPERTURA_DATI deve essere un percorso "
                            "assoluto, non «%s»: un percorso relativo si "
                            "risolverebbe dalla cartella in cui gira il "
                            "server" % valore)
    if not cartella.is_dir():
        raise DatiNonValidi("COPERTURA_DATI non è una cartella: %s"
                            % cartella)
    for nome in FILE_DATI:
        if not (cartella / nome).is_file():
            raise DatiNonValidi("in %s manca %s: COPERTURA_DATI deve "
                                "indicare la cartella database/ del "
                                "gestionale" % (cartella, nome))
    return cartella


def carica(cartella: Path) -> tuple[tuple[Riga, ...], tuple[str, ...]]:
    """(la copertura per comune e tecnologia, i nomi di tutti i comuni),
    dai file del gestionale caricati in un database SQLite in memoria, che
    si chiude subito dopo."""
    connessione = sqlite3.connect(":memory:")
    try:
        for nome in FILE_DATI:
            connessione.executescript(
                (cartella / nome).read_text(encoding="utf-8"))
        connessione.execute("PRAGMA query_only = ON")
        righe = tuple(Riga(*r) for r in connessione.execute(SQL_COPERTURA))
        comuni = tuple(r[0] for r in connessione.execute(SQL_COMUNI))
    except (sqlite3.Error, OSError, UnicodeDecodeError) as exc:
        raise DatiNonValidi("i dati in %s non si leggono (%s)"
                            % (cartella, exc))
    finally:
        connessione.close()
    return righe, comuni


def crea_server(righe: tuple[Riga, ...], comuni: tuple[str, ...]) -> FastMCP:
    """Il server, con lo strumento che legge la copertura già caricata."""
    server = FastMCP("copertura", instructions=ISTRUZIONI)
    per_nome = {nome.casefold(): nome for nome in comuni}

    @server.tool(annotations={"readOnlyHint": True, "idempotentHint": True,
                              "openWorldHint": False})
    def cerca_copertura(
            comune: Optional[str] = None,
            tecnologia: Optional[Literal["FTTH", "FWA"]] = None,
    ) -> list[dict]:
        """La copertura di CiaspoLink, dai dati del gestionale: una riga per
        ogni comune e tecnologia (FTTH è la fibra fino a casa, FWA la
        radio), con gli indirizzi coperti (che hanno una data di
        disponibilità), quelli pianificati (senza data) e la velocità
        massima in Mbit/s. Senza filtri, tutti i comuni che hanno almeno un
        indirizzo; comune (il nome, maiuscole indifferenti) e tecnologia
        restringono l'elenco. Un comune senza copertura dà un elenco
        vuoto."""
        scelte = righe
        if comune is not None:
            nome = per_nome.get(comune.strip().casefold())
            if nome is None:
                raise ToolError("comune sconosciuto: %s; i comuni del "
                                "gestionale sono: %s"
                                % (comune.strip(), ", ".join(comuni)))
            scelte = tuple(r for r in scelte if r.comune == nome)
        if tecnologia is not None:
            scelte = tuple(r for r in scelte if r.tecnologia == tecnologia)
        return [r.come_dizionario() for r in scelte]

    return server


def main() -> int:
    try:
        righe, comuni = carica(cartella_dati())
    except DatiNonValidi as exc:
        sys.stderr.write("server_copertura.py: %s\n" % exc)
        return 2
    crea_server(righe, comuni).run(show_banner=False)
    return 0


if __name__ == "__main__":
    sys.exit(main())
