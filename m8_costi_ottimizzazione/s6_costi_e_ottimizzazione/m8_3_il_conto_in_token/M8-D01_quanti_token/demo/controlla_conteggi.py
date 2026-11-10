"""controlla_conteggi.py -- M8-D01 «Quanti token pesa una frase»: i conteggi
dell'endpoint di token counting, letti dai file che demo/chiama.sh ha salvato.

Legge, nella cartella data (risposte/ dello spazio di lavoro), per ogni testo:
  <nome>.richiesta.json  il corpo della richiesta: il modello e il testo;
  <nome>.stato           lo stato HTTP, una riga con il numero;
  <nome>.json            il corpo della risposta, così come l'ha salvato curl.
Stampa la tabella (nome, caratteri del testo, input_tokens) e, quando ci sono
la frase italiana e quella inglese (frase-it e frase-en), la loro differenza:
una misura, nessun verdetto. Decide soltanto ciò che l'endpoint promette: ogni
testo ha un conteggio, un intero positivo, e il conteggio non ha creato un
messaggio (la risposta non porta id, content, stop_reason né usage).

Uso:    python3 -B -I controlla_conteggi.py <cartella delle risposte>
Uscita: 0 ogni testo ha il suo conteggio, un intero positivo, e nessuna
        risposta è un messaggio · 1 un conteggio che manca o che non è un
        intero positivo, uno stato diverso da 200, una risposta che porta i
        campi di un messaggio, una delle due frasi senza l'altra, nessun
        testo contato · 2 uso sbagliato; la cartella che non c'è; uno stato
        che non è un numero; un file che non si legge come JSON o che non è
        come deve essere; un errore inatteso (una riga, mai un traceback)
"""
from __future__ import annotations

import json
import os
import re
import sys
from typing import Any, Dict, List, NamedTuple, Optional, Tuple

USO = "Uso: python3 -B -I controlla_conteggi.py <cartella delle risposte>\n"
RICHIESTA = ".richiesta.json"
STATO = ".stato"
RISPOSTA = ".json"
FRASE_IT = "frase-it"
FRASE_EN = "frase-en"
# I campi di un messaggio creato: l'endpoint di conteggio non deve portarli.
CAMPI_MESSAGGIO = ("id", "content", "stop_reason", "usage")
# Una chiave nel testo di un errore: si maschera, non si stampa mai.
CHIAVE = re.compile(r"sk-ant-[A-Za-z0-9_-]+")


class Precondizione(Exception):
    """Un dato che non si può leggere: uscita 2."""


class Incompleto(Exception):
    """Un conteggio che manca o non è un conteggio: uscita 1."""


class Conteggio(NamedTuple):
    """Un testo contato."""
    nome: str
    caratteri: int
    token: int
    modello: str


def maschera(testo: str) -> str:
    """Il testo con ogni cosa che somiglia a una chiave mascherata."""
    return CHIAVE.sub("<chiave>", testo)


def leggi_json(percorso: str, cosa: str) -> Any:
    """Un file JSON. Raises: Precondizione se non si legge come JSON."""
    try:
        with open(percorso, encoding="utf-8") as fh:
            return json.load(fh)
    except (OSError, UnicodeDecodeError, ValueError) as exc:
        raise Precondizione("%s non si legge come JSON: %s" % (cosa, exc)
                            ) from exc


def leggi_testo(cartella: str, nome: str) -> Tuple[str, str]:
    """Il testo della richiesta e il modello. Raises: Precondizione."""
    cosa = nome + RICHIESTA
    corpo = leggi_json(os.path.join(cartella, cosa), cosa)
    try:
        testo = corpo["messages"][0]["content"]
        modello = corpo["model"]
    except (KeyError, IndexError, TypeError) as exc:
        raise Precondizione("%s non è il corpo di una richiesta: manca %s"
                            % (cosa, exc)) from exc
    if not isinstance(testo, str) or not isinstance(modello, str):
        raise Precondizione("%s non è il corpo di una richiesta" % cosa)
    return testo, modello


def leggi_stato(cartella: str, nome: str) -> Optional[int]:
    """Lo stato HTTP, None se manca. Raises: Precondizione."""
    cosa = nome + STATO
    percorso = os.path.join(cartella, cosa)
    if not os.path.isfile(percorso):
        return None
    try:
        with open(percorso, encoding="utf-8") as fh:
            testo = fh.read().strip()
    except (OSError, UnicodeDecodeError) as exc:
        raise Precondizione("%s non si legge: %s" % (cosa, exc)) from exc
    if not testo.isdigit():
        raise Precondizione("%s non è un numero: «%s»" % (cosa, testo[:40]))
    return int(testo)


def leggi_risposta(cartella: str, nome: str) -> Optional[Dict[str, Any]]:
    """Il corpo della risposta, None se manca. Raises: Precondizione."""
    cosa = nome + RISPOSTA
    percorso = os.path.join(cartella, cosa)
    if not os.path.isfile(percorso):
        return None
    dati = leggi_json(percorso, cosa)
    if not isinstance(dati, dict):
        raise Precondizione("%s non è un oggetto JSON" % cosa)
    return dati


def motivo_errore(risposta: Dict[str, Any]) -> str:
    """Il tipo e il messaggio di un corpo d'errore, mascherati."""
    errore = risposta.get("error")
    if not isinstance(errore, dict):
        return ""
    return " (%s: %s)" % (maschera(str(errore.get("type"))),
                          maschera(str(errore.get("message"))))


def conteggio(cartella: str, nome: str) -> Conteggio:
    """Il conteggio di un testo. Raises: Incompleto, Precondizione."""
    testo, modello = leggi_testo(cartella, nome)
    stato = leggi_stato(cartella, nome)
    if stato is None:
        raise Incompleto("%s: manca %s%s: la chiamata non è finita."
                         % (nome, nome, STATO))
    risposta = leggi_risposta(cartella, nome)
    if risposta is None:
        raise Incompleto("%s: manca %s%s: la chiamata non è finita."
                         % (nome, nome, RISPOSTA))
    if stato != 200:
        raise Incompleto("%s: lo stato HTTP è %d, non 200%s."
                         % (nome, stato, motivo_errore(risposta)))
    token = risposta.get("input_tokens")
    if isinstance(token, bool) or not isinstance(token, int) or token <= 0:
        raise Incompleto("%s: input_tokens non è un intero positivo: %s."
                         % (nome, maschera(repr(token))))
    campi = [c for c in CAMPI_MESSAGGIO if c in risposta]
    if campi:
        raise Incompleto("%s: la risposta porta %s: è un messaggio, non un "
                         "conteggio." % (nome, ", ".join(campi)))
    return Conteggio(nome, len(testo), token, modello)


def nomi_contati(cartella: str) -> List[str]:
    """I nomi dei testi della cartella (i due della demo per primi).
    Raises: Precondizione."""
    try:
        nomi = os.listdir(cartella)
    except OSError as exc:
        raise Precondizione("la cartella %s non esiste o non si apre (%s)"
                            % (cartella, exc.strerror or exc)) from exc
    trovati = sorted(n[:-len(RICHIESTA)] for n in nomi
                     if n.endswith(RICHIESTA))
    ordine = [n for n in (FRASE_IT, FRASE_EN) if n in trovati]
    return ordine + [n for n in trovati if n not in ordine]


def migliaia(numero: int) -> str:
    """Il numero intero con il punto delle migliaia."""
    return "{:,}".format(numero).replace(",", ".")


def con_segno(numero: int) -> str:
    """Il numero con il segno, senza segno lo zero."""
    if numero == 0:
        return "0"
    return ("+" if numero > 0 else "-") + migliaia(abs(numero))


def stampa_tabella(conteggi: List[Conteggio]) -> None:
    """La tabella dei conteggi: nome, caratteri, input_tokens."""
    largo = max([len(c.nome) for c in conteggi] + [len("file")])
    print("%-*s  %9s  %12s" % (largo, "file", "caratteri", "input_tokens"))
    for c in conteggi:
        print("%-*s  %9s  %12s" % (largo, c.nome, migliaia(c.caratteri),
                                   migliaia(c.token)))
    modelli = sorted({c.modello for c in conteggi})
    print("(dato) modello della richiesta: " + ", ".join(modelli))


def stampa_differenza(it: Conteggio, en: Conteggio) -> None:
    """La frase italiana contro quella inglese: una misura."""
    differenza = it.token - en.token
    print("La stessa frase in due lingue: italiano %s token su %s caratteri, "
          "inglese %s su %s: %s token. Una misura, nessun verdetto." % (
              migliaia(it.token), migliaia(it.caratteri),
              migliaia(en.token), migliaia(en.caratteri),
              con_segno(differenza)))


def controlla(cartella: str) -> int:
    """Il controllo di una cartella di conteggi; l'uscita del contratto."""
    if not os.path.isdir(cartella):
        raise Precondizione("la cartella %s non c'è" % cartella)
    nomi = nomi_contati(cartella)
    if not nomi:
        print("In %s nessun testo contato: fate girare chiama.sh." % cartella)
        return 1
    conteggi: List[Conteggio] = []
    problemi: List[str] = []
    for nome in nomi:
        try:
            conteggi.append(conteggio(cartella, nome))
        except Incompleto as exc:
            problemi.append(str(exc))
    if (FRASE_IT in nomi) != (FRASE_EN in nomi):
        problemi.append("Delle due frasi della demo manca una.")
    if conteggi:
        stampa_tabella(conteggi)
    if problemi:
        print("\n".join(problemi))
        print("Non tutti i testi hanno un conteggio valido: vedete sopra.")
        return 1
    per_nome = {c.nome: c for c in conteggi}
    if FRASE_IT in per_nome and FRASE_EN in per_nome:
        stampa_differenza(per_nome[FRASE_IT], per_nome[FRASE_EN])
    print("La garanzia: nessuna risposta porta id, content, stop_reason o "
          "usage: contare non ha creato un messaggio: confermata.")
    print("Fatto: ogni testo ha il suo conteggio; la tabella è qui sopra.")
    return 0


def main(argv: List[str]) -> int:
    if len(argv) != 1 or argv[0].startswith("-"):
        sys.stderr.write(USO)
        return 2
    try:
        return controlla(argv[0])
    except Precondizione as exc:
        sys.stderr.write("controlla_conteggi: %s\n" % exc)
        return 2
    except Exception as exc:  # pylint: disable=broad-except
        sys.stderr.write("controlla_conteggi: errore inatteso (%s)\n"
                         % type(exc).__name__)
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
