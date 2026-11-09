"""server_banco.py -- il server MCP del banco di prova: gli strumenti
dell'assistente di CiaspoLink, sui dati sintetici di uno scenario.

Un server locale, su stdio, costruito con FastMCP 3.x (la versione è fissata in
pyproject.toml e in uv.lock). Gli strumenti non sono nel codice: vengono dal file
di definizioni (nome, descrizione, input_schema, il campo facoltativo
«capacita»), letto una volta all'avvio. Ogni chiamata esegue la capacità del
motore (../motore.py) e aggiunge una riga JSON al registro. Un risultato con il
campo «errore» arriva a Claude come errore dello strumento (isError).

Lo avvia prova.py attraverso Claude Code, con percorsi assoluti:
    BANCO_SCENARIO  il file JSON dello scenario
    BANCO_KB        la cartella delle procedure (kb-*.md)
    BANCO_STRUMENTI il file delle definizioni
    BANCO_REGISTRO  il file del registro (una riga JSON per chiamata)
Lo STDOUT è il canale del protocollo: ogni messaggio va su STDERR. Niente rete,
niente chiavi.

Uscita: 2 se una variabile manca, non è un percorso assoluto o i file non si
        leggono: prima di parlare il protocollo, con un messaggio su STDERR;
        altrimenti il server gira finché il client chiude lo STDIN (0).
"""
from __future__ import annotations

import json
import os
import sys
from pathlib import Path
from typing import Any, Dict

# FastMCP non controlla gli aggiornamenti: il server non usa la rete. La
# variabile si imposta prima di importare fastmcp, che la legge allora.
os.environ.setdefault("FASTMCP_CHECK_FOR_UPDATES", "off")

from fastmcp import FastMCP  # noqa: E402
from fastmcp.tools.base import Tool, ToolResult  # noqa: E402
from mcp.types import TextContent  # noqa: E402

# Il motore sta nel progetto, che non deve riempirsi di __pycache__.
sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import motore  # noqa: E402

NOMI_AMBIENTE = ("BANCO_SCENARIO", "BANCO_KB", "BANCO_STRUMENTI",
                 "BANCO_REGISTRO")


class Registro:
    """Il registro delle chiamate: una riga JSON per chiamata, in ordine."""

    def __init__(self, percorso: Path) -> None:
        self._percorso = percorso
        self._numero = 0

    def scrivi(self, strumento: str, capacita: str, argomenti: Dict[str, Any],
               risultato: Dict[str, Any], errore: bool) -> None:
        self._numero += 1
        riga = {"n": self._numero, "strumento": strumento,
                "capacita": capacita, "argomenti": argomenti,
                "risultato": risultato, "errore": errore}
        with self._percorso.open("a", encoding="utf-8") as fh:
            fh.write(json.dumps(riga, ensure_ascii=False) + "\n")


class StrumentoBanco(Tool):
    """Uno strumento definito dal file, eseguito dal motore."""

    capacita: str
    banco: Any
    registro: Any

    async def run(self, arguments: Dict[str, Any]) -> ToolResult:
        risultato, errore, effettiva = self.banco.esegui(self.capacita,
                                                         arguments or {})
        self.registro.scrivi(self.name, effettiva, arguments or {}, risultato,
                             errore)
        testo = json.dumps(risultato, ensure_ascii=False)
        return ToolResult(content=[TextContent(type="text", text=testo)],
                          structured_content=risultato, is_error=errore)


def _percorsi() -> Dict[str, Path]:
    percorsi: Dict[str, Path] = {}
    for nome in NOMI_AMBIENTE:
        valore = os.environ.get(nome, "")
        if not valore or not os.path.isabs(valore):
            raise motore.Problema(f"{nome} manca o non è un percorso assoluto")
        percorsi[nome] = Path(valore)
    return percorsi


def costruisci() -> FastMCP:
    """Il server: scenario, definizioni, registro. Solleva Problema."""
    p = _percorsi()
    try:
        scenario = json.loads(p["BANCO_SCENARIO"].read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError, ValueError) as exc:
        raise motore.Problema(f"scenario illeggibile: {exc}") from exc
    if not p["BANCO_KB"].is_dir():
        raise motore.Problema(f"BANCO_KB non è una cartella: {p['BANCO_KB']}")
    banco = motore.Banco(scenario, p["BANCO_KB"])
    registro = Registro(p["BANCO_REGISTRO"])
    server = FastMCP("assistenza", instructions=(
        "Gli strumenti dell'assistenza clienti di CiaspoLink, su dati sintetici."))
    for d in motore.carica_strumenti(p["BANCO_STRUMENTI"]):
        server.add_tool(StrumentoBanco(
            name=d.nome, description=d.descrizione, parameters=d.schema,
            capacita=d.capacita, banco=banco, registro=registro))
    return server


def main() -> int:
    try:
        server = costruisci()
    except motore.Problema as exc:
        print(f"server_banco: {exc}", file=sys.stderr)
        return 2
    server.run(show_banner=False)
    return 0


if __name__ == "__main__":
    sys.exit(main())
