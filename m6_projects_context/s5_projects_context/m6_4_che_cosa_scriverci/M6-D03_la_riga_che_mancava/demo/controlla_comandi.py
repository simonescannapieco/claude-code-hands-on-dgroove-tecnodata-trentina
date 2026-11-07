"""controlla_comandi.py -- M6-D03 «Il comando dei test: Claude andrebbe a
cercarlo?»: le esecuzioni di in_classe.sh alla prova.

Legge, nella cartella data (risposte/ dello spazio di lavoro), una cartella
per esecuzione, ciascuna con lo stream.jsonl di `claude -p --output-format
stream-json --verbose`, la stessa richiesta partita da progetti/gestionale-php
di una copia nuova dello spazio di lavoro:
  senza-<n>/  il gestionale senza CLAUDE.md;
  con-<n>/    il gestionale con il CLAUDE.md di quattro righe (con-la-riga/,
              accanto a questo file), che dice il comando dei test.
Di ogni esecuzione stampa: gli strumenti chiamati e i comandi Bash,
nell'ordine; se Claude ha letto il README del gestionale, dove il comando c'è;
se ha usato tools/php.sh; se un risultato di Bash ha il riepilogo di PHPUnit,
cioè se la suite ha girato, e con quali numeri; la risposta e i suoi numeri
contro quel riepilogo; i token della prima richiesta; turni, secondi e token,
sommati su ogni segmento. Sono dati, mai un esito.

Poi la coppia, esecuzione per esecuzione: con la riga la suite ha girato e
senza no, «confermata»; ha girato in tutte e due, «non distinguibile»; con la
riga non ha girato, «non confermata in questa esecuzione»; e «confermata n su
N». Un esito non decide l'uscita.

Uso:    python3 -B -I controlla_comandi.py <cartella delle esecuzioni>
Env:    PN_HANDSON_ROOT  il repository, dove sta tools/lib_leggi_contesto.py
                         (default: la radice sopra la cartella dell'elemento)
Uscita: 0 ogni esecuzione c'è ed è finita bene · 1 un'esecuzione che manca
        alla sua coppia, uno stream senza il risultato o con un errore: la
        prova va rifatta · 2 uso sbagliato; la cartella che non c'è o senza
        esecuzioni; uno stream che non si legge; il CLAUDE.md del braccio o
        tools/lib_leggi_contesto.py che mancano; un errore inatteso (una riga,
        mai un traceback)
"""
from __future__ import annotations

import os
import re
import sys
import textwrap
from typing import Dict, List, NamedTuple, Optional


def _strumenti() -> str:
    """tools/ del repository: PN_HANDSON_ROOT, o la radice sopra la cartella
    dell'elemento (<radice>/m6_…/s5_…/m6_4_…/M6-D03_…/demo/)."""
    radice = os.environ.get("PN_HANDSON_ROOT")
    if not radice:
        radice = os.path.realpath(__file__)
        for _ in range(6):
            radice = os.path.dirname(radice)
    return os.path.join(radice, "tools")


STRUMENTI = _strumenti()
sys.path.insert(0, STRUMENTI)
try:
    import lib_leggi_contesto as lc
    from lib_leggi_stream import Strumento
except ImportError:
    lc = None  # type: ignore[assignment]

BRACCI = ("senza", "con")
QUALE = {"senza": "senza CLAUDE.md",
         "con": "con il CLAUDE.md di quattro righe"}
ESECUZIONE = re.compile(r"^(senza|con)-([1-9][0-9]*)$")
RIGA = os.path.join("con-la-riga", "CLAUDE.md")
CONFERMATA = "confermata"
NON_CONFERMATA = "non confermata in questa esecuzione"
NON_DISTINGUIBILE = "non distinguibile"
RIFARE = "rifate la prova (il README dice come)"
USO = "Uso: python3 -B -I controlla_comandi.py <cartella delle esecuzioni>\n"
LARGHEZZA = 76
RIGHE_RISPOSTA = 6
COMANDO_MAX = 68
ANSI = re.compile(r"\x1b\[[0-9;]*m")
OK = re.compile(r"OK \((\d+) tests?, (\d+) assertions?\)")
CONTI = re.compile(r"Tests: (\d+), Assertions: (\d+)((?:, [A-Za-z ]+: \d+)*)"
                   r"\.")
VOCE = re.compile(r", ([A-Za-z ]+): (\d+)")
NUMERO = re.compile(r"(?<![\w.,])(\d+)(?!\w|[.,]\d)")
ZERO = re.compile(r"\b(?:nessun[oa]?|zero)\b", re.IGNORECASE)
README = re.compile(r"readme", re.IGNORECASE)


class Incompleto(Exception):
    """Un'esecuzione che manca o non è finita bene: uscita 1."""


class Riepilogo(NamedTuple):
    """Il riepilogo di PHPUnit: la riga e i conti."""
    riga: str
    test: int
    asserzioni: int
    falliti: int
    saltati: int

    @property
    def passati(self) -> int:
        """I test che passano: né falliti, né in errore, né saltati."""
        return self.test - self.falliti - self.saltati


class Run(NamedTuple):
    """Che cosa dice un'esecuzione."""
    nome: str
    passi: List[str]
    readme: Optional[int]
    php_sh: bool
    riepilogo: Optional[Riepilogo]
    risposta: str
    prima: int
    turni: int
    secondi: float
    token: int


def migliaia(numero: float) -> str:
    """Il numero intero con il punto delle migliaia."""
    return "{:,}".format(int(numero)).replace(",", ".")


def secondi(valore: float) -> str:
    """I secondi con la virgola, un decimale."""
    return ("%.1f" % valore).replace(".", ",")


def con_segno(numero: int) -> str:
    """Il numero con il segno, senza segno lo zero."""
    if numero == 0:
        return "0"
    return ("+" if numero > 0 else "-") + migliaia(abs(numero))


def maschera(testo: str) -> str:
    """Il testo su una riga, senza colori, con «~» al posto della home."""
    riga = " ".join(ANSI.sub("", testo).split())
    casa = os.path.expanduser("~")
    if casa not in ("", "/", "~"):
        riga = riga.replace(casa + "/", "~/")
    return riga


def breve(testo: str, quanto: int) -> str:
    """Il testo accorciato a quanto caratteri, con «…»."""
    return testo if len(testo) <= quanto else testo[:quanto - 1] + "…"


def relativo(percorso: str, nome: str) -> str:
    """Un percorso relativo alla copia dell'esecuzione (la cartella <nome>
    che in_classe.sh ha creato), altrimenti com'è, con «~» per la home."""
    dove = percorso.rfind("/%s/" % nome)
    if dove >= 0:
        return percorso[dove + len(nome) + 2:] or "."
    return maschera(percorso)


def riepilogo_di(testo: str) -> Optional[Riepilogo]:
    """L'ultimo riepilogo di PHPUnit di un risultato, o None."""
    pulito = ANSI.sub("", testo)
    trovati = []
    for gruppo in OK.finditer(pulito):
        trovati.append((gruppo.start(), Riepilogo(
            gruppo.group(0), int(gruppo.group(1)), int(gruppo.group(2)), 0,
            0)))
    for gruppo in CONTI.finditer(pulito):
        voci = {k.strip().lower(): int(v)
                for k, v in VOCE.findall(gruppo.group(3))}
        trovati.append((gruppo.start(), Riepilogo(
            gruppo.group(0), int(gruppo.group(1)), int(gruppo.group(2)),
            voci.get("failures", 0) + voci.get("errors", 0),
            voci.get("skipped", 0) + voci.get("incomplete", 0))))
    return max(trovati)[1] if trovati else None


def descrivi(strumento: Strumento, nome: str) -> str:
    """Un passo: il comando Bash, o lo strumento e il suo percorso."""
    ingresso = strumento.input if isinstance(strumento.input, dict) else {}
    if strumento.nome == "Bash":
        return "Bash: %s" % breve(maschera(str(ingresso.get("command", ""))),
                                  COMANDO_MAX)
    dove = ingresso.get("file_path") or ingresso.get("path") or "."
    cosa = ingresso.get("pattern")
    return "%s%s %s" % (strumento.nome,
                        " «%s»" % cosa if cosa is not None else "",
                        relativo(str(dove), nome))


def legge_il_readme(strumento: Strumento) -> bool:
    """Vero se il passo legge o cerca nel README del gestionale."""
    ingresso = strumento.input if isinstance(strumento.input, dict) else {}
    if strumento.nome == "Bash":
        return bool(README.search(str(ingresso.get("command", ""))))
    campi = (ingresso.get("file_path"), ingresso.get("path"),
             ingresso.get("glob"), ingresso.get("pattern")
             if strumento.nome == "Glob" else None)
    return any(isinstance(c, str) and README.search(c) for c in campi)


def leggi_run(cartella: str, nome: str) -> Run:
    """Un'esecuzione. Raises: Incompleto, Problema."""
    percorso = os.path.join(cartella, nome, "stream.jsonl")
    if not os.path.isfile(percorso):
        raise Incompleto("manca %s/stream.jsonl: %s" % (nome, RIFARE))
    esecuzione = lc.leggi_stream(percorso)
    if not esecuzione.completa:
        raise Incompleto("%s: lo stream non finisce con il risultato, la "
                         "chiamata si è interrotta: %s" % (nome, RIFARE))
    if esecuzione.errore:
        raise Incompleto("%s: claude ha restituito un errore: %s"
                         % (nome, RIFARE))
    contesto = lc.leggi_contesto(percorso)
    riepilogo = None
    for _, risultato in lc.risultati_bash(percorso):
        trovato = riepilogo_di(risultato.testo)
        riepilogo = trovato or riepilogo
    passi = esecuzione.strumenti
    lettura = [i for i, p in enumerate(passi, 1) if legge_il_readme(p)]
    return Run(nome, [descrivi(p, nome) for p in passi],
               lettura[0] if lettura else None,
               any("php.sh" in c for c in contesto.comandi), riepilogo,
               esecuzione.testo, contesto.prima_richiesta,
               int(esecuzione.turni), float(esecuzione.secondi),
               int(esecuzione.token_totali))


def numeri_esecuzioni(cartella: str) -> List[int]:
    """I numeri delle esecuzioni della cartella. Raises: Problema."""
    try:
        nomi = os.listdir(cartella)
    except OSError as exc:
        raise lc.Problema("la cartella %s non esiste o non si apre (%s)"
                          % (cartella, exc.strerror or exc)) from exc
    numeri = sorted({int(m.group(2)) for m in map(ESECUZIONE.match, nomi)
                     if m and os.path.isdir(os.path.join(cartella,
                                                         m.group(0)))})
    if not numeri:
        raise lc.Problema("nessuna esecuzione in %s: %s" % (cartella, RIFARE))
    return numeri


def leggi_tutto(cartella: str, numeri: List[int]) -> Dict[str, Run]:
    """Tutte le esecuzioni, ogni mancanza in una volta. Raises: Incompleto;
    Problema, al primo stream che non si legge."""
    letti: Dict[str, Run] = {}
    mancano: List[str] = []
    for braccio in BRACCI:
        for numero in numeri:
            nome = "%s-%d" % (braccio, numero)
            try:
                letti[nome] = leggi_run(cartella, nome)
            except Incompleto as exc:
                mancano.append(str(exc))
    if mancano:
        raise Incompleto("\n".join(mancano))
    return letti


def leggi_riga() -> List[str]:
    """Le righe del CLAUDE.md del braccio con. Raises: Problema."""
    percorso = os.path.join(os.path.dirname(os.path.realpath(__file__)),
                            RIGA)
    try:
        with open(percorso, encoding="utf-8") as fh:
            return fh.read().splitlines()
    except (OSError, UnicodeDecodeError) as exc:
        raise lc.Problema("manca %s accanto al controllo, o non si legge "
                          "(%s)" % (RIGA, exc)) from exc


def numeri_della_risposta(run: Run) -> str:
    """I numeri della risposta contro il riepilogo, o i soli numeri."""
    numeri = [int(n) for n in NUMERO.findall(ANSI.sub("", run.risposta))]
    if run.riepilogo is None:
        return "senza un riepilogo: %s" % (
            ", ".join(str(n) for n in numeri) or "nessuno")
    ok = run.riepilogo.passati in numeri
    zero = run.riepilogo.falliti == 0 and bool(ZERO.search(run.risposta))
    ko = run.riepilogo.falliti in numeri or zero
    return "%d passati %s, %d falliti %s" % (
        run.riepilogo.passati, "sì" if ok else "no", run.riepilogo.falliti,
        "sì" if ko else "no")


def stampa_run(run: Run) -> None:
    """Le righe di un'esecuzione."""
    print("%s (%s)" % (run.nome, QUALE[run.nome.split("-")[0]]))
    print("  i passi:%s" % ("" if run.passi else " nessuno"))
    for numero, passo in enumerate(run.passi, 1):
        print("    %d. %s" % (numero, passo))
    print("  il README del gestionale: %s" % (
        "letto, al passo %d" % run.readme if run.readme else "non letto"))
    print("  tools/php.sh: %s" % ("usato" if run.php_sh else "non usato"))
    if run.riepilogo is None:
        print("  la suite: non ha girato (nessun riepilogo di PHPUnit nei "
              "risultati di Bash)")
    else:
        print("  la suite: ha girato, «%s»" % run.riepilogo.riga)
    print("  la risposta:")
    righe = textwrap.wrap(maschera(run.risposta), LARGHEZZA - 4) \
        or ["(vuota)"]
    if len(righe) > RIGHE_RISPOSTA:
        righe = righe[:RIGHE_RISPOSTA]
        righe[-1] += " …"
    for riga in righe:
        print("    " + riga)
    print("  i numeri della risposta: %s" % numeri_della_risposta(run))
    print("  prima richiesta: %s token; turni %d, %s s, %s token" % (
        migliaia(run.prima), run.turni, secondi(run.secondi),
        migliaia(run.token)))


def verdetto(con: Run, senza: Run) -> str:
    """La coppia di un'esecuzione: con la riga contro senza."""
    if con.riepilogo is None:
        return "%s (con la riga la suite non ha girato)" % NON_CONFERMATA
    if senza.riepilogo is not None:
        return "%s (la suite ha girato anche senza)" % NON_DISTINGUIBILE
    return "%s (con la riga la suite ha girato; senza, no)" % CONFERMATA


def stampa_coppia(letti: Dict[str, Run], numeri: List[int]) -> None:
    """La coppia, esecuzione per esecuzione, e «confermata n su N»."""
    print("«Only write down what Claude can't find by reading the repo, or "
          "what it")
    print("would otherwise spend time rediscovering every session»: la "
          "stessa richiesta,")
    print("con le quattro righe e senza.")
    conferme = 0
    for numero in numeri:
        esito = verdetto(letti["con-%d" % numero], letti["senza-%d" % numero])
        conferme += esito.startswith(CONFERMATA)
        print("  esecuzione %d: %s" % (numero, esito))
    print("  %s %d su %d" % (CONFERMATA, conferme, len(numeri)))


def stampa_dati(letti: Dict[str, Run], numeri: List[int]) -> None:
    """La prima richiesta dei due bracci e il consumo, braccio per braccio."""
    print("Come dati, la prima richiesta, con la riga e senza:")
    for numero in numeri:
        con, senza = letti["con-%d" % numero], letti["senza-%d" % numero]
        print("  esecuzione %d: con %s, senza %s token (%s)" % (
            numero, migliaia(con.prima), migliaia(senza.prima),
            con_segno(con.prima - senza.prima)))
    print("Come dati, braccio per braccio:")
    for braccio in BRACCI:
        runs = [letti["%s-%d" % (braccio, n)] for n in numeri]
        print("  %s: la suite ha girato %d su %d, il README letto %d su %d;"
              % (braccio, sum(r.riepilogo is not None for r in runs),
                 len(runs), sum(r.readme is not None for r in runs),
                 len(runs)))
        print("    turni %d, %s s, %s token" % (
            sum(r.turni for r in runs), secondi(sum(r.secondi for r in runs)),
            migliaia(sum(r.token for r in runs))))


def controlla(cartella: str) -> int:
    """Il controllo: stampa i dati e gli esiti; l'uscita 0."""
    riga = leggi_riga()
    numeri = numeri_esecuzioni(cartella)
    letti = leggi_tutto(cartella, numeri)
    print("La richiesta, uguale nei due bracci, da progetti/gestionale-php; "
          "nel braccio")
    print("con, il CLAUDE.md di quella cartella:")
    for testo in riga:
        print(("  | " + testo).rstrip())
    for braccio in BRACCI:
        for numero in numeri:
            print()
            stampa_run(letti["%s-%d" % (braccio, numero)])
    print()
    stampa_coppia(letti, numeri)
    print()
    stampa_dati(letti, numeri)
    return 0


def errore(messaggio: str, uscita: int) -> int:
    """Il messaggio su STDERR, una riga per problema; l'uscita data."""
    for riga in messaggio.split("\n"):
        sys.stderr.write("controlla_comandi.py: %s\n" % riga)
    return uscita


def main(argv: List[str]) -> int:
    for flusso in (sys.stdout, sys.stderr):
        riconfigura = getattr(flusso, "reconfigure", None)
        if riconfigura is not None:
            riconfigura(errors="replace")
    if len(argv) != 1 or argv[0].startswith("-"):
        sys.stderr.write(USO)
        return 2
    if lc is None:
        return errore("non trovo tools/lib_leggi_contesto.py in %s: date "
                      "PN_HANDSON_ROOT" % STRUMENTI, 2)
    try:
        return controlla(argv[0])
    except Incompleto as exc:
        return errore(str(exc), 1)
    except lc.Problema as exc:
        return errore(str(exc), 2)
    except Exception as exc:  # mai un traceback: un errore inatteso esce 2
        return errore("errore inatteso (%s: %s)"
                      % (type(exc).__name__, " ".join(str(exc).split())), 2)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
