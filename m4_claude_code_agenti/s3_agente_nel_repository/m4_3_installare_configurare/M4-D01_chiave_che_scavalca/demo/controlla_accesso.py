"""controlla_accesso.py -- la chiave che scavalca il Pro (M4-D01): con quale
metodo si autentica Claude Code, senza e con ANTHROPIC_API_KEY.

Due usi, nello spazio di lavoro:

  python3 controlla_accesso.py --salva <file>
      legge su STDIN il JSON di `claude auth status --json` e scrive in
      <file> (creando la sua cartella, se manca) soltanto tre campi:
      loggedIn, authMethod e apiKeySource (null se non c'è). L'e-mail,
      l'organizzazione e ogni altro campo dell'account non arrivano mai nel
      file né a schermo, e un errore non ripete l'ingresso. Stampa che cosa
      ha salvato.

  python3 controlla_accesso.py [<spazio di lavoro>]
      legge stato/senza.json e stato/con.json, le due esecuzioni di
      `claude auth status --json` salvate con --salva: la prima senza
      ANTHROPIC_API_KEY, la seconda con la chiave finta del corso impostata
      per quel solo comando. Stampa che cosa dice ciascuna, poi il
      verdetto su ciò che Anthropic garantisce: con ANTHROPIC_API_KEY
      impostata Claude Code usa la chiave al posto dell'abbonamento, anche
      da collegati. Confermata se la prima dice claude.ai (l'abbonamento) e
      la seconda api_key con apiKeySource ANTHROPIC_API_KEY; altrimenti non
      confermata in questa esecuzione. È una garanzia: se non è confermata
      l'uscita è 1. Mai «smentita». Se già la prima non dice claude.ai, la
      prova non può partire: è una precondizione.

Uscita (--salva): 0 salvato
        2 uso sbagliato; un ingresso vuoto o che non è il JSON di claude
          auth status (nessun file scritto); un file che non si scrive; un
          errore inatteso
Uscita (controllo): 0 la garanzia confermata
        1 manca stato/ o uno dei due file, o un file non va (non è JSON,
          ha tipi sbagliati o campi in più, che non si stampano): rifate
          quel passo; oppure la garanzia non confermata in questa
          esecuzione
        2 uso sbagliato; lo spazio di lavoro assente; un file che non si
          legge; senza la chiave Claude Code non usa l'abbonamento (la
          prova parte da lì); un errore inatteso (una riga, mai un
          traceback)
"""
from __future__ import annotations

import json
import os
import sys
import tempfile
from typing import Dict, List, NamedTuple, Optional

CAMPI = ("loggedIn", "authMethod", "apiKeySource")
CARTELLA = "stato"
FILE = (("senza", "stato/senza.json"), ("con", "stato/con.json"))
ABBONAMENTO = "claude.ai"
CHIAVE = "api_key"
FONTE = "ANTHROPIC_API_KEY"
VERDETTO = ("Con ANTHROPIC_API_KEY impostata, Claude Code usa la chiave al "
            "posto dell'abbonamento")
CONFERMATA = "confermata"
NON_CONFERMATA = "non confermata in questa esecuzione"
GARANZIA = ("La documentazione garantisce che con ANTHROPIC_API_KEY "
            "impostata la chiave si usa al posto dell'abbonamento, anche da "
            "collegati: in questa esecuzione no")
PARTENZA = "Mancano i file di stato/: eseguite i passi del README."
NON_ANCORA = ("Non ancora: un file di stato/ manca o non va; rifate il suo "
              "passo del README, poi rilanciate il controllo.")
USO = ("Uso: python3 controlla_accesso.py --salva <file>\n"
       "     python3 controlla_accesso.py [<spazio di lavoro>]\n")


class Precondizione(Exception):
    """Un file che non si legge, o una prova che non può partire:
    uscita 2."""


class Mancante(Exception):
    """Un file di stato/ che manca o non va: uscita 1."""


class Stato(NamedTuple):
    """I tre campi di un'esecuzione di claude auth status."""
    collegato: bool
    metodo: str
    fonte: Optional[str]


def compatta(testo: str) -> str:
    """Il testo su una riga sola, al massimo 40 caratteri."""
    riga = " ".join(testo.split())
    return riga if len(riga) <= 40 else riga[:39] + "…"


def descrivi(stato: Stato) -> str:
    """I tre campi in parole."""
    parti = ["collegato %s" % ("sì" if stato.collegato else "no"),
             "metodo %s" % compatta(stato.metodo)]
    if stato.fonte is not None:
        parti.append("chiave da %s" % compatta(stato.fonte))
    return " · ".join(parti)


def stato_da(doc: object) -> Stato:
    """I tre campi di un oggetto JSON; ValueError se mancano o hanno tipi
    sbagliati (il messaggio non ripete niente dell'ingresso)."""
    if not isinstance(doc, dict):
        raise ValueError("non è un oggetto")
    collegato = doc.get("loggedIn")
    metodo = doc.get("authMethod")
    fonte = doc.get("apiKeySource")
    if (not isinstance(collegato, bool) or not isinstance(metodo, str)
            or not metodo.strip()
            or not (fonte is None or isinstance(fonte, str))):
        raise ValueError("campi mancanti o di tipo sbagliato")
    return Stato(collegato, metodo, fonte)


def avviso(messaggio: str) -> None:
    """Un file da rifare, o un errore, su STDERR."""
    sys.stderr.write("controlla_accesso.py: %s\n" % messaggio)


def scrivi(percorso: str, stato: Stato) -> None:
    """Il file con i soli tre campi, scritto per intero o per niente."""
    cartella = os.path.dirname(percorso) or "."
    os.makedirs(cartella, exist_ok=True)
    doc = {"loggedIn": stato.collegato, "authMethod": stato.metodo,
           "apiKeySource": stato.fonte}
    fd, provvisorio = tempfile.mkstemp(dir=cartella, prefix=".salva.")
    try:
        with os.fdopen(fd, "w", encoding="utf-8", newline="\n") as fh:
            fh.write(json.dumps(doc, ensure_ascii=False) + "\n")
        os.replace(provvisorio, percorso)
    except BaseException:
        # Si toglie il provvisorio e si rilancia l'errore. Se anche la
        # pulizia fallisce, esce l'errore della pulizia, con quello che
        # l'ha resa necessaria come contesto: in salva() tutti e due danno
        # l'uscita 2, e il file d'arrivo resta com'era.
        if os.path.lexists(provvisorio):
            os.unlink(provvisorio)
        raise


def salva(percorso: str) -> int:
    """--salva: dal JSON di claude auth status su STDIN ai tre campi."""
    dati = sys.stdin.buffer.read().decode("utf-8", errors="replace")
    if not dati.strip():
        avviso("nessun JSON su STDIN: claude auth status ha risposto? "
               "Niente è stato salvato")
        return 2
    try:
        stato = stato_da(json.loads(dati))
    except (ValueError, RecursionError):
        avviso("l'ingresso non è il JSON di claude auth status (non lo "
               "ripeto): niente è stato salvato")
        return 2
    try:
        scrivi(percorso, stato)
    except OSError as exc:
        avviso("%s non si scrive (%s)" % (percorso, exc.strerror or exc))
        return 2
    print("Salvato %s: %s" % (percorso, descrivi(stato)))
    return 0


def leggi(percorso: str) -> Stato:
    """Un file di stato/. Mancante se manca o non va; Precondizione se non
    si legge."""
    if not os.path.lexists(percorso):
        raise Mancante("manca %s: rifate quel passo" % percorso)
    try:
        with open(percorso, encoding="utf-8", errors="replace") as fh:
            testo = fh.read()
    except OSError as exc:
        raise Precondizione("%s non si legge (%s)"
                            % (percorso, exc.strerror or exc))
    try:
        doc = json.loads(testo)
    except (ValueError, RecursionError):
        raise Mancante("%s non è il JSON salvato da --salva: rifate quel "
                       "passo" % percorso)
    if isinstance(doc, dict) and set(doc) - set(CAMPI):
        raise Mancante("%s ha campi in più oltre a loggedIn, authMethod e "
                       "apiKeySource (non li stampo): cancellatelo e rifate "
                       "quel passo con --salva" % percorso)
    try:
        return stato_da(doc)
    except ValueError:
        raise Mancante("%s: loggedIn, authMethod o apiKeySource non vanno; "
                       "rifate quel passo con --salva" % percorso)


def controlla() -> int:
    """Il controllo nella cartella corrente, lo spazio di lavoro: stampa e
    restituisce l'uscita 0 o 1. Precondizione per l'uscita 2."""
    if not os.path.isdir(CARTELLA):
        print(PARTENZA)
        return 1
    stati: Dict[str, Stato] = {}
    mancanti = 0
    for nome, percorso in FILE:
        try:
            stati[nome] = leggi(percorso)
        except Mancante as exc:
            avviso(str(exc))
            mancanti += 1
    if "senza" in stati:
        print("senza ANTHROPIC_API_KEY: %s" % descrivi(stati["senza"]))
    if "con" in stati:
        print("con ANTHROPIC_API_KEY (per quel solo comando): %s"
              % descrivi(stati["con"]))
    if mancanti:
        print(NON_ANCORA)
        return 1
    senza, con = stati["senza"], stati["con"]
    if not senza.collegato or senza.metodo != ABBONAMENTO:
        raise Precondizione(
            "senza la chiave Claude Code non usa l'abbonamento (collegato: "
            "%s, metodo: %s): la prova parte da un accesso con "
            "l'abbonamento; accedete con claude (PRIMA_DEL_CORSO.md, "
            "«Accedere con l'abbonamento Pro») e rifate i passi"
            % ("sì" if senza.collegato else "no", compatta(senza.metodo)))
    if con.metodo == CHIAVE and con.fonte == FONTE:
        print("%s: %s" % (VERDETTO, CONFERMATA))
        return 0
    print("%s: %s" % (VERDETTO, NON_CONFERMATA))
    print("%s (con la chiave: %s)." % (GARANZIA, descrivi(con)))
    return 1


def errore(messaggio: str) -> int:
    """Il messaggio su STDERR, in una riga; l'uscita 2."""
    avviso(messaggio)
    return 2


def uso(messaggio: str) -> int:
    """Un argomento sbagliato: il motivo e l'uso; l'uscita 2."""
    errore(messaggio)
    sys.stderr.write(USO)
    return 2


def main(argv: List[str]) -> int:
    for flusso in (sys.stdout, sys.stderr):
        riconfigura = getattr(flusso, "reconfigure", None)
        if riconfigura is not None:
            riconfigura(errors="replace")
    if argv[:1] == ["--salva"]:
        if len(argv) != 2 or not argv[1] or argv[1].startswith("-"):
            return uso("--salva vuole il file dove salvare")
        try:
            return salva(argv[1])
        except Exception as exc:  # mai un traceback, mai l'ingresso
            return errore("errore inatteso (%s)" % type(exc).__name__)
    posizionali: List[str] = []
    for arg in argv:
        if arg.startswith("-"):
            return uso("opzione sconosciuta: %s" % arg)
        posizionali.append(arg)
    if len(posizionali) > 1:
        return uso("uno spazio di lavoro per volta")
    ws = posizionali[0] if posizionali else "."
    if not os.path.isdir(ws):
        return errore("spazio di lavoro assente: %s" % ws)
    try:
        os.chdir(ws)
    except OSError as exc:
        return errore("lo spazio di lavoro %s non si apre (%s)"
                      % (ws, exc.strerror or exc))
    try:
        return controlla()
    except Precondizione as exc:
        return errore(str(exc))
    except Exception as exc:  # mai un traceback: un errore inatteso esce 2
        return errore("errore inatteso (%s: %s)"
                      % (type(exc).__name__, " ".join(str(exc).split())))


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
