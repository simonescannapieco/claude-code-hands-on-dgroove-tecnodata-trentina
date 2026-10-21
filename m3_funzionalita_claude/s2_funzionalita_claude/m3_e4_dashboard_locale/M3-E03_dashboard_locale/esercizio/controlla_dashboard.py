#!/usr/bin/env python3
"""controlla_dashboard.py -- i numeri di dashboard.html confrontati con il
profilo della settimana, e ciò che la pagina caricherebbe da fuori.

Legge la pagina (di norma dashboard.html, accanto a questo file) con il
modulo html.parser della libreria standard e vi cerca UN blocco
<script type="application/json" id="kpi"> con l'oggetto dei KPI. Il
riferimento è la chiave kpi di anonimo/profilo.json, il profilo scritto da
M3-E01 o il vostro (un oggetto non vuoto di indicatori, numeri o oggetti di
numeri): il blocco deve avere le stesse chiavi, confrontate una per una con
la regola di kpi_definizioni.md: un intero è giusto se è uguale; un
decimale se dista dal riferimento al più mezza unità del suo ultimo
decimale (0,05 con un decimale, 0,005 con due: per i tre decimali di
kpi_definizioni.md quelli che dice, per un vostro indicatore le cifre con
cui è scritto il riferimento); un oggetto se ha le stesse chiavi e ogni
valore è giusto.

Poi cerca le risorse che la pagina prenderebbe fuori dal suo file:
  - dalla rete: un src, href, srcset, data o poster che comincia con http:,
    https:, ftp: o // nei tag che caricano qualcosa (script, link, img,
    iframe, frame, embed, object, source, video, audio, track, input,
    image, use, base), e un url(…) o un @import verso la rete dentro
    <style> o in un attributo style; e uno script scritto nella pagina
    (JavaScript, non un blocco di dati) che contiene fetch(, import(,
    XMLHttpRequest, WebSocket, EventSource, sendBeacon o un indirizzo
    http:// o https://;
  - da un altro file: gli stessi riferimenti verso un percorso, come
    style.css o grafico.js: la pagina deve stare in un file solo.
Restano nel file, e vanno bene: data:, i riferimenti interni (#…), i
link dei tag a, che non caricano niente, e gli script che non chiamano la
rete.

Stampa per ogni KPI il valore atteso, quello trovato e se va bene, poi le
risorse trovate: soltanto i valori dei KPI, che sono aggregati, mai un
testo dei ticket.

Ogni esecuzione (non -h, non un errore negli argomenti) aggiunge una riga a
controlli_dashboard.log, nella cartella della pagina: l'ora UTC, l'uscita e
il numero di differenze (i problemi del blocco kpi, i KPI che non tornano,
le risorse fuori dal file), «-» se il controllo non ha potuto girare,
separati da tabulazioni.

L'ultima riga che il controllo stampa è sempre la sua uscita, con che cosa
vuol dire: «uscita: 0 …», «uscita: 1 …» o «uscita: 2 …». Si legge lì, senza
bisogno di $?.

Uso:    python3 controlla_dashboard.py [pagina]
          pagina   la pagina da controllare (default dashboard.html,
                   accanto a questo file)
Uscita: 0 i KPI della pagina sono quelli del profilo e la pagina non
        carica niente da fuori · 1 almeno una differenza: un KPI che non
        torna o manca, una chiave in più, una risorsa dalla rete o da un
        altro file, il blocco kpi che manca, è doppio o non contiene un
        oggetto JSON · 2 precondizione: la pagina o anonimo/profilo.json
        mancano o non si leggono, il profilo non ha la chiave kpi con un
        oggetto non vuoto di numeri o di oggetti di numeri,
        controlli_dashboard.log non si scrive, un argomento sbagliato
"""
from __future__ import annotations

import datetime as dt
import decimal
import json
import math
import os
import re
import sys
from fractions import Fraction
from html.parser import HTMLParser
from typing import Any, Dict, List, NamedTuple, Optional, Sequence, Tuple

QUI = os.path.dirname(os.path.abspath(__file__))
PAGINA = "dashboard.html"
PROFILO = os.path.join("anonimo", "profilo.json")
LOG = "controlli_dashboard.log"
# I decimali dei tre indicatori decimali di kpi_definizioni.md; per un altro
# indicatore, le cifre decimali con cui è scritto il riferimento.
DECIMALI = {"mediana_minuti_prima_risposta": 1,
            "media_minuti_risoluzione_per_tecnologia": 1,
            "soddisfazione_media": 2}
GIORNI = ("lun", "mar", "mer", "gio", "ven", "sab", "dom")
MARGINE = Fraction(1, 10 ** 9)
# I tag che caricano qualcosa, e gli attributi con cui lo fanno.
TAG_RISORSE = frozenset((
    "script", "link", "img", "iframe", "frame", "embed", "object", "source",
    "video", "audio", "track", "input", "image", "use", "base"))
ATTRIBUTI = ("src", "href", "xlink:href", "srcset", "data", "poster")
# Il testo dentro questi tag non si vede nella pagina.
NASCOSTI = frozenset(("script", "style", "template"))
# I type di uno <script> che il browser esegue (gli altri sono dati).
TIPI_JS = frozenset((
    "", "module", "text/javascript", "application/javascript",
    "text/ecmascript", "application/ecmascript", "application/x-javascript",
    "text/x-javascript", "application/x-ecmascript", "text/x-ecmascript",
    "text/jscript", "text/livescript"))
# In uno script scritto nella pagina: le chiamate alla rete, con il nome
# con cui si stampano, e gli indirizzi http e https.
CHIAMATE_RETE = (
    (re.compile(r"\bfetch\s*\("), "fetch("),
    (re.compile(r"\bimport\s*\("), "import("),
    (re.compile(r"\bXMLHttpRequest\b"), "XMLHttpRequest"),
    (re.compile(r"\bWebSocket\b"), "WebSocket"),
    (re.compile(r"\bEventSource\b"), "EventSource"),
    (re.compile(r"\bsendBeacon\b"), "sendBeacon"))
URL_SCRIPT = re.compile(r"https?://[^\s\"'`<>()]+", re.I)
NELLA_PAGINA = "<script> nella pagina"
RETE = re.compile(r"\s*(?:https?:|ftp:|//)", re.I)
NEL_FILE = re.compile(r"\s*(?:data:|#|about:|blob:|javascript:|$)", re.I)
URL_CSS = re.compile(r"url\(\s*(['\"]?)(.*?)\1\s*\)", re.I | re.S)
IMPORT_CSS = re.compile(r"@import\s+(['\"])(.*?)\1", re.I)
BLOCCO = '<script type="application/json" id="kpi">'
MOSTRA_AL_PIU = 80


class Precondizione(Exception):
    """Il controllo non può girare: uscita 2."""


class Risorsa(NamedTuple):
    """Un riferimento a qualcosa fuori dal file della pagina."""
    dove: str
    valore: str
    rete: bool


class Pagina(HTMLParser):
    """Il contenuto che serve al controllo: i blocchi kpi, i riferimenti
    dei tag che caricano qualcosa, il CSS, gli script scritti nella pagina,
    il testo visibile."""

    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.blocchi: List[str] = []
        self.riferimenti: List[Tuple[str, str]] = []
        self.stili: List[Tuple[str, str]] = []
        self.script: List[str] = []
        self.testo: List[str] = []
        self._kpi: Optional[List[str]] = None
        self._stile: Optional[List[str]] = None
        self._script: Optional[List[str]] = None
        self._nascosti = 0

    def handle_starttag(self, tag: str,
                        attrs: List[Tuple[str, Optional[str]]]) -> None:
        valori = {k: (v or "") for k, v in attrs}
        if tag in TAG_RISORSE:
            for nome in ATTRIBUTI:
                if nome in valori:
                    self._riferimento(tag, nome, valori[nome])
        if valori.get("style"):
            self.stili.append(("lo stile di <%s>" % tag, valori["style"]))
        if tag == "script":
            tipo = valori.get("type", "").split(";")[0].strip().lower()
            if tipo == "application/json" and valori.get("id") == "kpi":
                self._kpi = []
            elif "src" not in valori and tipo in TIPI_JS:
                self._script = []
        elif tag == "style":
            self._stile = []
        if tag in NASCOSTI:
            self._nascosti += 1

    def _riferimento(self, tag: str, nome: str, valore: str) -> None:
        candidati = [valore]
        if nome == "srcset":
            candidati = [c.strip().split(" ")[0] for c in valore.split(",")]
        for c in candidati:
            self.riferimenti.append(("<%s %s>" % (tag, nome), c))

    def handle_endtag(self, tag: str) -> None:
        if tag == "script" and self._kpi is not None:
            self.blocchi.append("".join(self._kpi))
            self._kpi = None
        elif tag == "script" and self._script is not None:
            self.script.append("".join(self._script))
            self._script = None
        elif tag == "style" and self._stile is not None:
            self.stili.append(("<style>", "".join(self._stile)))
            self._stile = None
        if tag in NASCOSTI and self._nascosti > 0:
            self._nascosti -= 1

    def handle_data(self, data: str) -> None:
        if self._kpi is not None:
            self._kpi.append(data)
        if self._script is not None:
            self._script.append(data)
        if self._stile is not None:
            self._stile.append(data)
        if self._nascosti == 0:
            self.testo.append(data)

    def chiudi(self) -> None:
        """Chiude l'analisi; un blocco kpi, uno script o uno stile lasciati
        aperti in fondo alla pagina contano come chiusi."""
        self.close()
        if self._kpi is not None:
            self.blocchi.append("".join(self._kpi))
        if self._script is not None:
            self.script.append("".join(self._script))
        if self._stile is not None:
            self.stili.append(("<style>", "".join(self._stile)))


def leggi_pagina(percorso: str) -> Pagina:
    """La pagina analizzata; Precondizione se manca, non si legge o non è
    un testo UTF-8."""
    try:
        with open(percorso, encoding="utf-8-sig") as fh:
            testo = fh.read()
    except FileNotFoundError:
        raise Precondizione("manca %s: la scrive genera_dashboard.py"
                            % percorso)
    except UnicodeDecodeError:
        raise Precondizione("%s non è un testo UTF-8" % percorso)
    except OSError as exc:
        raise Precondizione("%s non si legge (%s)" % (
            percorso, exc.strerror or type(exc).__name__))
    pagina = Pagina()
    try:
        pagina.feed(testo)
        pagina.chiudi()
    except Exception as exc:  # html.parser è tollerante, ma non sempre
        raise Precondizione("%s non si legge come HTML (%s)"
                            % (percorso, type(exc).__name__))
    return pagina


def testo_visibile(pagina: Pagina) -> str:
    """Il testo della pagina fuori da script, style e template."""
    return "".join(pagina.testo)


def blocco_kpi(pagina: Pagina) -> Tuple[Optional[Dict[str, Any]], List[str]]:
    """(l'oggetto del blocco kpi, []) oppure (None, [il problema])."""
    if not pagina.blocchi:
        return None, ["nessun blocco %s nella pagina" % BLOCCO]
    if len(pagina.blocchi) > 1:
        return None, ["%d blocchi %s: ne serve uno solo"
                      % (len(pagina.blocchi), BLOCCO)]
    try:
        valori = json.loads(pagina.blocchi[0])
    except (ValueError, RecursionError):
        return None, ["il blocco kpi non è un JSON valido"]
    if not isinstance(valori, dict):
        return None, ["il blocco kpi non contiene un oggetto JSON"]
    return valori, []


def classifica(valore: str) -> Optional[bool]:
    """True se il riferimento va in rete, False se va a un altro file,
    None se resta nel file."""
    if RETE.match(valore):
        return True
    if NEL_FILE.match(valore):
        return None
    return False


def risorse_esterne(pagina: Pagina) -> List[Risorsa]:
    """I riferimenti della pagina a qualcosa fuori dal suo file, e le
    chiamate alla rete degli script scritti nella pagina."""
    trovate: List[Risorsa] = []
    for dove, valore in pagina.riferimenti:
        rete = classifica(valore)
        if rete is not None:
            trovate.append(Risorsa(dove, valore.strip(), rete))
    for dove, css in pagina.stili:
        for m in URL_CSS.finditer(css):
            rete = classifica(m.group(2))
            if rete is not None:
                trovate.append(Risorsa(dove + " url()", m.group(2).strip(),
                                       rete))
        for m in IMPORT_CSS.finditer(css):
            rete = classifica(m.group(2))
            if rete is not None:
                trovate.append(Risorsa(dove + " @import", m.group(2).strip(),
                                       rete))
    for codice in pagina.script:
        trovate += [Risorsa(NELLA_PAGINA, nome, True)
                    for regola, nome in CHIAMATE_RETE if regola.search(codice)]
        indirizzi = dict.fromkeys(m.group(0)
                                  for m in URL_SCRIPT.finditer(codice))
        trovate += [Risorsa(NELLA_PAGINA, u, True) for u in indirizzi]
    return trovate


def _numero(valore: Any) -> bool:
    return (isinstance(valore, (int, float)) and not isinstance(valore, bool)
            and math.isfinite(valore))


def leggi_profilo(percorso: str) -> Dict[str, Any]:
    """La chiave kpi del profilo, il riferimento; Precondizione se manca,
    non si legge o non è un oggetto non vuoto di numeri o di oggetti di
    numeri."""
    try:
        with open(percorso, encoding="utf-8-sig") as fh:
            profilo = json.load(fh)
    except FileNotFoundError:
        raise Precondizione("manca %s, il riferimento del controllo: "
                            "copiatelo da M3-E01" % percorso)
    except (UnicodeDecodeError, ValueError, RecursionError):
        raise Precondizione("%s non è un JSON valido" % percorso)
    except OSError as exc:
        raise Precondizione("%s non si legge (%s)" % (
            percorso, exc.strerror or type(exc).__name__))
    kpi = profilo.get("kpi") if isinstance(profilo, dict) else None
    if not isinstance(kpi, dict) or not kpi or not all(
            v is None or _numero(v) or (isinstance(v, dict) and all(
                x is None or _numero(x) for x in v.values()))
            for v in kpi.values()):
        raise Precondizione("%s non ha la chiave kpi con gli indicatori, "
                            "numeri o oggetti di numeri: ricopiate il "
                            "profilo di M3-E01, o scrivete il vostro"
                            % percorso)
    return kpi


def decimali_di(valore: Any) -> Optional[int]:
    """Le cifre decimali con cui è scritto un riferimento (per un oggetto,
    le più numerose fra i suoi valori); None per un intero."""
    if isinstance(valore, dict):
        cifre = [d for d in map(decimali_di, valore.values())
                 if d is not None]
        return max(cifre) if cifre else None
    if not isinstance(valore, float) or not math.isfinite(valore) \
            or valore.is_integer():
        return None
    esponente = decimal.Decimal(repr(valore)).as_tuple().exponent
    return -esponente if isinstance(esponente, int) and esponente < 0 \
        else None


def _numero_giusto(atteso: Any, trovato: Any,
                   decimali: Optional[int]) -> bool:
    if atteso is None:
        return trovato is None
    if not _numero(trovato):
        return False
    if decimali is None:
        return Fraction(trovato) == Fraction(atteso)
    margine = Fraction(1, 2 * 10 ** decimali) + MARGINE
    return abs(Fraction(trovato) - Fraction(atteso)) <= margine


def giusto(atteso: Any, trovato: Any, decimali: Optional[int]) -> bool:
    """Un valore trovato contro il riferimento, con la regola."""
    if isinstance(atteso, dict):
        return isinstance(trovato, dict) and set(trovato) == set(atteso) \
            and all(_numero_giusto(atteso[k], trovato[k], decimali)
                    for k in atteso)
    return _numero_giusto(atteso, trovato, decimali)


def confronta(valori: Dict[str, Any], attesi: Dict[str, Any]
              ) -> List[Tuple[str, Any, Any, bool]]:
    """(chiave, atteso, trovato, giusto) per ogni chiave del riferimento,
    in ordine alfabetico, poi le chiavi in più (atteso None); trovato None
    se la chiave manca."""
    voci = []
    for chiave in sorted(attesi):
        if chiave not in valori:
            voci.append((chiave, attesi[chiave], None, False))
        else:
            decimali = DECIMALI.get(chiave, decimali_di(attesi[chiave]))
            voci.append((chiave, attesi[chiave], valori[chiave],
                         giusto(attesi[chiave], valori[chiave], decimali)))
    for chiave in sorted(k for k in valori if k not in attesi):
        voci.append((chiave, None, valori[chiave], False))
    return voci


def mostra(valore: Any) -> str:
    """Un valore su una riga, i giorni nel loro ordine, al più 80 caratteri."""
    if isinstance(valore, dict) and valore and set(valore) <= set(GIORNI):
        testo = json.dumps({g: valore[g] for g in GIORNI if g in valore})
    else:
        testo = json.dumps(valore, ensure_ascii=False, sort_keys=True)
    if len(testo) > MOSTRA_AL_PIU:
        testo = testo[:MOSTRA_AL_PIU - 1] + "…"
    return testo


def esamina(percorso: str, nome: str, profilo: str) -> Tuple[int, int]:
    """Il controllo, stampato; (l'uscita, le differenze)."""
    attesi = leggi_profilo(profilo)
    pagina = leggi_pagina(percorso)
    print("controlla_dashboard: %s confrontata con %s" % (nome, PROFILO))
    print("\nI KPI del blocco kpi, confrontati con il profilo")
    valori, problemi = blocco_kpi(pagina)
    differenze = len(problemi)
    for problema in problemi:
        print("  NO  %s" % problema)
    if valori is not None:
        for chiave, atteso, trovato, ok in confronta(valori, attesi):
            print("  %-40s %s" % (chiave, "ok" if ok else "NO"))
            print("      atteso  %s" % ("(chiave in più)" if chiave not in
                                        attesi else mostra(atteso)))
            print("      trovato %s" % (mostra(trovato) if chiave in valori
                                        else "(manca)"))
            differenze += 0 if ok else 1
    print("\nRisorse fuori dal file della pagina")
    risorse = risorse_esterne(pagina)
    if not risorse:
        print("  nessuna: la pagina non carica niente dalla rete né da altri "
              "file")
    for r in risorse:
        valore = r.valore if len(r.valore) <= MOSTRA_AL_PIU else \
            r.valore[:MOSTRA_AL_PIU - 1] + "…"
        print("  NO  %s, %s: %s" % ("dalla rete" if r.rete else
                                    "da un altro file", r.dove, valore))
    differenze += len(risorse)
    return (0 if differenze == 0 else 1), differenze


def scrivi_log(percorso_pagina: str, uscita: int, differenze: str) -> None:
    """Una riga in controlli_dashboard.log, nella cartella della pagina."""
    cartella = os.path.dirname(os.path.abspath(percorso_pagina))
    os.makedirs(cartella, exist_ok=True)
    ora = dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    with open(os.path.join(cartella, LOG), "a", encoding="utf-8",
              newline="\n") as fh:
        fh.write("%s\t%d\t%s\n" % (ora, uscita, differenze))


def argomenti(argv: Sequence[str]) -> Tuple[Optional[str], bool]:
    """(la pagina o None, -h); ValueError su un argomento sbagliato."""
    pagina, aiuto = None, False
    for a in argv:
        if a in ("-h", "--help"):
            aiuto = True
        elif a.startswith("-"):
            raise ValueError("opzione sconosciuta: %s" % a)
        elif pagina is None:
            pagina = a
        else:
            raise ValueError("una pagina sola")
    return pagina, aiuto


def main(argv: Sequence[str]) -> int:
    try:
        pagina, aiuto = argomenti(argv)
    except ValueError as exc:
        sys.stderr.write("controlla_dashboard: %s\nUso: python3 "
                         "controlla_dashboard.py [pagina]\n" % exc)
        print("uscita: 2 — argomenti sbagliati: %s" % exc)
        return 2
    if aiuto:
        print((__doc__ or "").strip())
        return 0
    percorso = pagina if pagina is not None else os.path.join(QUI, PAGINA)
    nome = pagina if pagina is not None else PAGINA
    uscita, differenze, perche = 2, 0, ""
    try:
        uscita, differenze = esamina(percorso, nome,
                                     os.path.join(QUI, PROFILO))
    except Precondizione as exc:
        perche = str(exc)
    except Exception as exc:  # l'ultima rete: un messaggio, mai un traceback
        perche = "errore inatteso (%s)" % type(exc).__name__
    try:
        scrivi_log(percorso, uscita, "-" if uscita == 2 else str(differenze))
    except OSError as exc:
        perche = "non riesco a scrivere %s accanto a %s (%s)" % (
            LOG, nome, exc.strerror or type(exc).__name__)
        uscita = 2
    if uscita == 2:
        sys.stderr.write("controlla_dashboard: %s\n" % perche)
        print("uscita: 2 — il controllo non può girare: %s" % perche)
    elif uscita == 1:
        print("\nuscita: 1 — %d %s da correggere" % (
            differenze, "differenza" if differenze == 1 else "differenze"))
    else:
        print("\nuscita: 0 — i KPI sono quelli del profilo e la pagina non "
              "carica niente da fuori")
    return uscita


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
