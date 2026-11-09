"""ollama_finto_m7_d05.py -- un Ollama finto per le prove di M7-D05
(test_m7_d05.sh): un server HTTP su 127.0.0.1, una porta libera, con
GET /api/tags, GET /api/version e POST /api/embed.

I vettori che restituisce sono inventati e dichiarati finti: dipendono solo da
frasi del testo (quattro dimensioni, una per argomento), così la prova sa chi
vince. Non sono l'uscita di un modello di embedding: provano lo script e il
controllo, non il modello.

Uso:    python3 -B -I ollama_finto_m7_d05.py <file porta> <file modo> <file log>
          <file porta>  vi scrive la porta quando è pronto
          <file modo>   una parola, riletta a ogni richiesta: ok,
                        senza_modello, errore_500, non_json, pochi_vettori, zeri
          <file log>    una riga JSON per richiesta: percorso, model, input
Uscita: non esce da solo; la suite lo ferma con un segnale.
"""
import json
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Any, Dict, List

MODELLO = "embeddinggemma:300m"
DIGEST = "sha256:0000finto"


def vettore(testo: str) -> List[float]:
    """Il vettore finto di un testo, dalle frasi che contiene."""
    t = testo.lower()
    if "password del wi-fi" in t:
        return [1.0, 0.0, 0.0, 0.0]
    if "spostare la linea" in t or "altra casa" in t:
        return [0.0, 1.0, 0.0, 0.0]
    if "addebito ripetuto" in t or "due volte lo stesso mese" in t:
        return [0.0, 0.0, 1.0, 0.0]
    return [0.0, 0.0, 0.0, 1.0]


class Gestore(BaseHTTPRequestHandler):
    """Le risposte di Ollama, finte."""

    file_modo = ""
    file_log = ""

    def log_message(self, *args: Any) -> None:  # niente sullo STDERR
        return

    def _modo(self) -> str:
        with open(self.file_modo, encoding="utf-8") as fh:
            return fh.read().strip() or "ok"

    def _invia(self, stato: int, corpo: bytes) -> None:
        self.send_response(stato)
        self.send_header("Content-Length", str(len(corpo)))
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(corpo)

    def _invia_json(self, dati: Dict[str, Any]) -> None:
        self._invia(200, json.dumps(dati).encode("utf-8"))

    def _registra(self, voce: Dict[str, Any]) -> None:
        with open(self.file_log, "a", encoding="utf-8") as fh:
            fh.write(json.dumps(voce, ensure_ascii=False) + "\n")

    def do_GET(self) -> None:  # pylint: disable=invalid-name
        self._registra({"percorso": self.path})
        if self.path == "/api/version":
            self._invia_json({"version": "0.0.0-finto"})
        elif self.path == "/api/tags":
            nome = "altro-modello:1" if self._modo() == "senza_modello" \
                else MODELLO
            self._invia_json({"models": [{"name": nome, "model": nome,
                                          "digest": DIGEST}]})
        else:
            self._invia(404, b"{}")

    def do_POST(self) -> None:  # pylint: disable=invalid-name
        lunghezza = int(self.headers.get("Content-Length", "0"))
        corpo = json.loads(self.rfile.read(lunghezza).decode("utf-8"))
        testi = corpo.get("input", [])
        self._registra({"percorso": self.path, "model": corpo.get("model"),
                        "input": len(testi)})
        modo = self._modo()
        if self.path != "/api/embed":
            self._invia(404, b"{}")
        elif modo == "errore_500":
            self._invia(500, b'{"error": "finto"}')
        elif modo == "non_json":
            self._invia(200, b"questa non e' JSON")
        elif modo == "pochi_vettori":
            self._invia_json({"embeddings": [vettore(t) for t in testi[:-1]]})
        elif modo == "zeri":
            self._invia_json({"embeddings": [[0.0, 0.0] for _ in testi]})
        else:
            self._invia_json({"model": corpo.get("model"),
                              "embeddings": [vettore(t) for t in testi]})


def main(argv: List[str]) -> int:
    file_porta, Gestore.file_modo, Gestore.file_log = argv
    server = ThreadingHTTPServer(("127.0.0.1", 0), Gestore)
    with open(file_porta, "w", encoding="utf-8") as fh:
        fh.write(str(server.server_address[1]) + "\n")
    server.serve_forever()
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
