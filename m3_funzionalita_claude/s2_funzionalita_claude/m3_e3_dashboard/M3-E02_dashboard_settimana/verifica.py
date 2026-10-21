#!/usr/bin/env python3
"""verifica.py di M3-E02 -- i numeri della settimana calcolati in
claude.ai e copiati in kpi.json, confrontati con quelli veri.

Lo chiama verifica.sh, accanto. Legge nello spazio di lavoro:
  - kpi.json, l'oggetto JSON copiato da claude.ai. Se l'avete copiato con
    il blocco di codice intorno (```json … ```), il blocco si toglie, e la
    verifica lo dice. Se ha le virgolette tipografiche del testo della
    pagina, “ ”, non è JSON: la verifica lo dice e indica il pulsante
    «Copy» sotto la risposta, che copia le virgolette dritte;
  - ticket-anonimi.csv, il file caricato in claude.ai: da lì calcola i KPI
    veri con kpi_veri.py, accanto a questo file, mai con una copia dello
    spazio di lavoro.
Controlla la forma di kpi.json: un oggetto JSON con esattamente le dieci
chiavi di kpi_definizioni.md e valori del tipo giusto (un intero dove serve
un intero, un numero dove serve un numero; per_giorno con le sette chiavi
lun … dom e valori interi; per_categoria un oggetto di interi;
media_minuti_risoluzione_per_tecnologia un oggetto di numeri). Poi stampa,
per ogni KPI, il valore atteso, quello trovato e se corrisponde, con la
regola di kpi_definizioni.md, e quanti KPI su dieci corrispondono: è un
dato, e non decide l'uscita. Infine stampa, come contesto, che cosa dice
Anthropic di una tabella incollata nel prompt e di una tabella interrogata
con il codice, con la sua misura, e chi decide il confronto fra le due.

Uso:    verifica.py <spazio di lavoro>
Uscita: 0 kpi.json c'è ed è un oggetto JSON con le dieci chiavi e i tipi
        giusti · 1 kpi.json manca, non è JSON, o ha chiavi o tipi sbagliati
        (e la verifica dice quali) · 2 precondizione (spazio di lavoro
        assente o che non si legge, kpi_veri.py dell'elemento che manca o
        non si carica, ticket-anonimi.csv dello spazio di lavoro che manca o
        da cui i KPI non si calcolano, kpi.json che c'è ma non si legge);
        mai un traceback
"""
from __future__ import annotations

import importlib.util
import json
import math
import os
import re
import sys
from types import ModuleType
from typing import Any, List, Optional, Sequence, Tuple

ELEMENTO = os.path.dirname(os.path.abspath(__file__))
KPI_VERI = os.path.join(ELEMENTO, "kpi_veri.py")
KPI_JSON = "kpi.json"
CSV = "ticket-anonimi.csv"
GIORNI = ("lun", "mar", "mer", "gio", "ven", "sab", "dom")
INTERI = ("segnalazioni", "aperte_fine_settimana", "annullate", "voti",
          "clienti_ricorrenti")
NUMERI = ("mediana_minuti_prima_risposta", "soddisfazione_media")
# Gli oggetti, con il tipo dei loro valori.
OGGETTI = (("per_giorno", "intero"), ("per_categoria", "intero"),
           ("media_minuti_risoluzione_per_tecnologia", "numero"))
# Un blocco di codice Markdown intorno a tutto il testo: ```json … ```.
RECINTO = re.compile(r"\A\s*```[^\n`]*\n(.*?)\n[ \t]*```\s*\Z", re.S)
# Le virgolette del testo della pagina di claude.ai, dove la risposta non
# sta in un blocco di codice (la prova del docente): “ e ”.
TIPOGRAFICHE = (chr(0x201C), chr(0x201D))
AFFERMAZIONE = ("«When the model has to compute over a table … let the "
                "model query it with code execution instead of pasting it "
                "in.»")
FONTE = ("https://platform.claude.com/docs/en/about-claude/models/"
         "optimizing-for-cost-and-intelligence")
MISURA = (
    "La misura di Anthropic: 25 domande aggregate su 1.862 righe di un CSV",
    "pubblico, con il thinking disattivato. Con la tabella incollata nel",
    "prompt, circa 91.000 token in entrata a ogni richiesta, Claude Sonnet 5",
    "ha risposto giusto a 7 domande su 25; con il file caricato e",
    "l'esecuzione di codice a tutte e 25, a circa un dodicesimo del costo.",
)
VERIFICARE = ("«complex or mission-critical calculations should be verified "
              "using specialized mathematical software or manual methods.»")
FONTE_VERIFICARE = ("https://support.claude.com/en/articles/10366421-how-"
                    "does-claude-handle-mathematical-equations-and-"
                    "calculations")
# Il risultato della coppia registrata dal docente (README, «Che cosa
# misura il controllo»).
REGISTRAZIONE = (
    "Nella registrazione del corso (21 ottobre 2026, Claude Code 2.1.306,",
    "Sonnet con effort low, tre coppie): KPI giusti incollando 9, 10 e 10,",
    "con il file e il codice 10, 9 e 9: confermata 1 su 3. Come dato, i",
    "token in entrata: da 57.142 a 206.372 incollando, da 29.565 a 30.247",
    "con il file.",
)
FINE = ("Fatto: kpi.json ha le dieci chiavi, con i tipi giusti. Quanti KPI "
        "corrispondono è scritto sopra, come dato: non decide la verifica.")


class Precondizione(Exception):
    """La verifica non può girare: uscita 2."""


def carica(nome: str, percorso: str) -> ModuleType:
    """Un modulo dell'elemento; Precondizione se manca o non si carica."""
    if not os.path.isfile(percorso):
        raise Precondizione("manca %s" % percorso)
    try:
        spec = importlib.util.spec_from_file_location(nome, percorso)
        if spec is None or spec.loader is None:
            raise ImportError("nessun caricatore")
        modulo = importlib.util.module_from_spec(spec)
        sys.modules[nome] = modulo
        spec.loader.exec_module(modulo)  # type: ignore[union-attr]
    except (ImportError, OSError, SyntaxError) as exc:
        raise Precondizione("%s non si carica (%s)" % (percorso, exc))
    return modulo


def leggi_byte(percorso: str) -> Optional[bytes]:
    """I byte del file, None se non c'è; Precondizione se c'è ma non si
    legge."""
    try:
        with open(percorso, "rb") as fh:
            return fh.read()
    except FileNotFoundError:
        return None
    except OSError as exc:
        raise Precondizione("%s non si legge (%s)" % (
            percorso, exc.strerror or type(exc).__name__))


def e_intero(valore: Any) -> bool:
    return isinstance(valore, int) and not isinstance(valore, bool)


def e_numero(valore: Any) -> bool:
    return (isinstance(valore, (int, float)) and not isinstance(valore, bool)
            and math.isfinite(valore))


def descrivi(valore: Any) -> str:
    """Il tipo JSON di un valore, in parole, con il valore se è breve."""
    if valore is None:
        return "null"
    if isinstance(valore, bool):
        return "un booleano (%s)" % json.dumps(valore)
    if isinstance(valore, int):
        return "un intero (%d)" % valore
    if isinstance(valore, float):
        return "un numero con la virgola (%s)" % json.dumps(valore)
    if isinstance(valore, str):
        breve = valore if len(valore) <= 20 else valore[:20] + "…"
        return "un testo (%s)" % json.dumps(breve, ensure_ascii=False)
    if isinstance(valore, list):
        return "un elenco"
    return "un oggetto"


def problemi_oggetto(chiave: str, valore: Any, tipo: str) -> List[str]:
    """I problemi di tipo di uno dei tre oggetti."""
    if not isinstance(valore, dict):
        return ["%s: serve un oggetto, c'è %s" % (chiave, descrivi(valore))]
    problemi = []
    if chiave == "per_giorno" and set(valore) != set(GIORNI):
        dettagli = []
        mancano = [g for g in GIORNI if g not in valore]
        in_piu = sorted(k for k in valore if k not in GIORNI)
        if mancano:
            dettagli.append("mancano " + ", ".join(mancano))
        if in_piu:
            dettagli.append("in più " + ", ".join(in_piu))
        problemi.append("per_giorno: servono le sette chiavi lun, mar, mer, "
                        "gio, ven, sab, dom (%s)" % "; ".join(dettagli))
    prova = e_intero if tipo == "intero" else e_numero
    sbagliate = [k for k in valore if not prova(valore[k])]
    if sbagliate:
        elenco = ", ".join(sbagliate[:5]) + (" …" if len(sbagliate) > 5
                                             else "")
        problemi.append("%s: serve un %s per ogni chiave, non lo è per %s"
                        % (chiave, tipo, elenco))
    return problemi


def problemi_di_forma(kpi: Any, chiavi: Sequence[str]) -> List[str]:
    """Le chiavi e i tipi di kpi.json; vuoto se la forma è giusta."""
    if not isinstance(kpi, dict):
        return ["kpi.json non contiene un oggetto JSON ({ … }), ma %s"
                % descrivi(kpi)]
    if set(kpi) == {"kpi"} and isinstance(kpi["kpi"], dict):
        return ["kpi.json ha soltanto la chiave kpi: servono le dieci chiavi "
                "direttamente, senza l'oggetto kpi intorno"]
    problemi = ["manca la chiave %s" % k for k in chiavi if k not in kpi]
    problemi += ["la chiave %s è in più" % k
                 for k in sorted(kpi) if k not in chiavi]
    for chiave in INTERI:
        if chiave in kpi and not e_intero(kpi[chiave]):
            problemi.append("%s: serve un intero, c'è %s"
                            % (chiave, descrivi(kpi[chiave])))
    for chiave in NUMERI:
        if chiave in kpi and not e_numero(kpi[chiave]):
            problemi.append("%s: serve un numero, c'è %s"
                            % (chiave, descrivi(kpi[chiave])))
    for chiave, tipo in OGGETTI:
        if chiave in kpi:
            problemi += problemi_oggetto(chiave, kpi[chiave], tipo)
    return problemi


def testo_json(dati: bytes, problemi: List[str]) -> Optional[str]:
    """Il testo di kpi.json, senza il blocco di codice se c'è; None, con il
    problema, se non è un testo UTF-8."""
    try:
        testo = dati.decode("utf-8-sig").replace("\r\n", "\n")
    except UnicodeDecodeError:
        problemi.append("kpi.json non è un testo UTF-8: salvatelo come testo "
                        "UTF-8, per esempio con cat > kpi.json")
        print("  non è un testo UTF-8")
        return None
    recinto = RECINTO.match(testo)
    if recinto:
        print("  è racchiuso in un blocco di codice (``` … ```): lo tolgo e "
              "leggo il JSON che contiene")
        return recinto.group(1)
    return testo


def non_json(testo: str, dove: str) -> str:
    """Il problema di un kpi.json che non si legge come JSON, con il
    consiglio che gli serve: le virgolette tipografiche del testo della
    pagina, oppure l'oggetto copiato a metà o con del testo in più."""
    if any(v in testo for v in TIPOGRAFICHE):
        return ("kpi.json ha le virgolette tipografiche “ ” del testo della "
                "pagina, che in JSON non valgono: ricopiate la risposta con il "
                "pulsante «Copy» sotto la risposta di claude.ai, che copia le "
                "virgolette dritte")
    return ("kpi.json non è un JSON valido%s: copiate soltanto l'oggetto, "
            "dalla { alla }" % dove)


def leggi_kpi(problemi: List[str]) -> Tuple[bool, Any]:
    """(letto, il contenuto di kpi.json); stampa che cosa ha trovato."""
    dati = leggi_byte(KPI_JSON)
    if dati is None:
        print("  manca")
        problemi.append("manca kpi.json: copiateci l'oggetto JSON della "
                        "risposta di claude.ai (README, passo 4)")
        return False, None
    testo = testo_json(dati, problemi)
    if testo is None:
        return False, None
    try:
        kpi = json.loads(testo)
    except json.JSONDecodeError as exc:
        print("  non è un JSON valido")
        problemi.append(non_json(testo, " (il primo errore alla riga %d, "
                                 "colonna %d)" % (exc.lineno, exc.colno)))
        return False, None
    except (ValueError, RecursionError):
        print("  non è un JSON valido")
        problemi.append(non_json(testo, ""))
        return False, None
    if isinstance(kpi, dict):
        print("  un oggetto JSON con %d chiavi" % len(kpi))
    return True, kpi


def mostra(valore: Any) -> str:
    """Un valore su una riga: i giorni nel loro ordine, le altre chiavi in
    ordine alfabetico."""
    if isinstance(valore, dict) and valore and set(valore) <= set(GIORNI):
        valore = {g: valore[g] for g in GIORNI if g in valore}
        return json.dumps(valore, ensure_ascii=False)
    return json.dumps(valore, ensure_ascii=False, sort_keys=True)


def stampa_confronto(kv: ModuleType, kpi: Any) -> None:
    """Il confronto chiave per chiave con i KPI veri, come dato."""
    print("\nI KPI di kpi.json, confrontati con quelli veri di %s (la regola "
          "di kpi_definizioni.md; come dato)" % CSV)
    if not isinstance(kpi, dict):
        print("  il confronto chiave per chiave vuole un oggetto JSON")
        return
    voci = kv.confronta(kpi, CSV)
    for chiave, atteso, trovato, giusto in voci:
        testo_atteso = mostra(atteso) if chiave in kv.CHIAVI else \
            "(chiave in più)"
        testo_trovato = mostra(trovato) if chiave in kpi else "(manca)"
        print("  %-40s %s" % (chiave, "ok" if giusto else "NO"))
        print("      atteso  %s" % testo_atteso)
        print("      trovato %s" % testo_trovato)
    giusti = sum(1 for k, _, _, ok in voci if ok and k in kv.CHIAVI)
    print("  Come dato: %d KPI su %d corrispondono." % (giusti,
                                                        len(kv.CHIAVI)))


def stampa_contesto() -> None:
    """Che cosa dice Anthropic, e chi decide il confronto."""
    print("\nChe cosa dice Anthropic, come contesto")
    print("  Perché si verifica: %s" % VERIFICARE)
    print("  (%s)" % FONTE_VERIFICARE)
    print("  Una tabella su cui calcolare: %s" % AFFERMAZIONE)
    print("  (%s)" % FONTE)
    for riga in MISURA:
        print("  " + riga)
    print("  Incollare o caricare è un confronto fra due strade: lo decide la")
    print("  coppia registrata dal docente in Claude Code, non questa verifica.")
    for riga in REGISTRAZIONE:
        print("  " + riga)


def esamina(ws: str) -> int:
    kv = carica("kpi_veri_elemento", KPI_VERI)
    if set(INTERI + NUMERI + tuple(k for k, _ in OGGETTI)) != set(kv.CHIAVI):
        raise Precondizione("kpi_veri.py e la verifica non hanno le stesse "
                            "chiavi")
    os.chdir(ws)
    if not os.path.isfile(CSV):
        raise Precondizione("manca %s nello spazio di lavoro: è il file che "
                            "caricate in claude.ai; copiatelo da M3-E01 "
                            "(README, passo 1) o ripartite con "
                            "tools/reset_esercizio.sh M3-E02" % CSV)
    try:
        kv.esatti(CSV)
    except kv.Precondizione as exc:
        raise Precondizione("i KPI veri non si calcolano da %s (%s)"
                            % (CSV, exc))
    print("M3-E02: la verifica di %s" % KPI_JSON)
    print("\n%s" % KPI_JSON)
    problemi: List[str] = []
    letto, kpi = leggi_kpi(problemi)
    if letto:
        problemi += problemi_di_forma(kpi, kv.CHIAVI)
        stampa_confronto(kv, kpi)
    stampa_contesto()
    if problemi:
        print()
        for problema in problemi:
            print("Non ancora: %s." % problema)
        return 1
    print("\n" + FINE)
    return 0


def main(argv: Sequence[str]) -> int:
    if len(argv) != 1 or not os.path.isdir(argv[0]):
        sys.stderr.write("verifica: spazio di lavoro assente: %s\n"
                         % (argv[0] if argv else ""))
        return 2
    if not os.access(argv[0], os.R_OK | os.X_OK):
        sys.stderr.write("verifica: lo spazio di lavoro %s non si legge\n"
                         % argv[0])
        return 2
    try:
        return esamina(argv[0])
    except Precondizione as exc:
        sys.stderr.write("verifica: %s\n" % exc)
        return 2
    except Exception as exc:  # l'ultima rete: mai un traceback
        sys.stderr.write("verifica: errore inatteso (%s)\n"
                         % type(exc).__name__)
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
