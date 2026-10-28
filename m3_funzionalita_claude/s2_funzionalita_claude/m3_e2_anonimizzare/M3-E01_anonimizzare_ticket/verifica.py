#!/usr/bin/env python3
"""verifica.py di M3-E01 -- il file anonimo, i dati personali rimasti e il
profilo della settimana.

Lo chiama verifica.sh, accanto. Non si fida dei file che Claude può aver
cambiato nello spazio di lavoro: il controllo dei dati personali, le sue
impronte e il CSV grezzo li prende dalle copie originali in esercizio/ di
questo elemento, i KPI veri da kpi_veri.py, accanto. Controlla:
  - anonimo/ticket-anonimi.csv: UTF-8 senza BOM e con fine riga LF; le 17
    colonne nell'ordine; le righe del file grezzo, nello stesso ordine
    (id_ticket); le colonne che restano come sono; le segnalazioni per
    giorno; gli pseudonimi di cliente (C-001, C-002, … in ordine di prima
    comparsa del codice cliente, lo stesso codice sempre con lo stesso,
    vuoto dove il codice è vuoto); oggetto e descrizione: il testo originale
    con [OMESSO] al posto di qualche tratto, e nient'altro di cambiato;
  - i dati personali rimasti, ricalcolati con il controllo originale (i
    nomi a metà accanto a un [OMESSO] compresi): devono essere 0;
  - anonimo/profilo.json: un oggetto JSON con la chiave kpi, giusta chiave
    per chiave rispetto ai KPI veri del file anonimo (la regola di
    kpi_definizioni.md).
Poi stampa, come dato, senza che decida l'uscita: quante [OMESSO] e quanta
parte del testo resta; dalle posizioni (il controllo originale sul testo
grezzo trova dove stanno i dati del corso, e l'allineamento del testo
anonimo con il grezzo dice quali tratti restano), per classe i dati del
corso di cui resta una parte fuori dagli [OMESSO], e quante omissioni non
coprono nessun dato del corso; le esecuzioni del controllo registrate in
anonimo/controlli.log e le loro uscite, e se controlla_pii.py e
impronte.json dello spazio di lavoro sono diversi dagli originali; la frase
della guida di Claude Code sul ciclo con un controllo, «It makes the change,
runs the check, and if something broke it reads the output and fixes it
before running the check again.», senza un esito: il registro lo scrive il
controllo a ogni esecuzione, chiunque lo esegua, e che Claude l'abbia
eseguito lo dicono le sue chiamate, non il registro. Non stampa mai un
valore dei dati personali.

Uso:    verifica.py <spazio di lavoro>
Uscita: 0 il file anonimo, i dati personali rimasti (0) e il profilo sono
        quelli attesi · 1 qualcosa manca o non torna, e la verifica dice che
        cosa · 2 precondizione (spazio di lavoro assente o che non si legge,
        un file originale dell'elemento che manca o non si carica, un file
        dello spazio di lavoro che c'è ma non si legge); mai un traceback
"""
from __future__ import annotations

import csv
import datetime as dt
import importlib.util
import io
import json
import os
import re
import sys
from types import ModuleType
from typing import Any, Dict, List, Optional, Sequence, Tuple

ELEMENTO = os.path.dirname(os.path.abspath(__file__))
ORIGINALI = os.path.join(ELEMENTO, "esercizio")
CONTROLLO = os.path.join(ORIGINALI, "controlla_pii.py")
IMPRONTE = os.path.join(ORIGINALI, "impronte.json")
GREZZO = os.path.join(ORIGINALI, "dati", "ticket-settimana.csv")
KPI_VERI = os.path.join(ELEMENTO, "kpi_veri.py")
ANONIMO = "anonimo/ticket-anonimi.csv"
PROFILO = "anonimo/profilo.json"
LOG = "anonimo/controlli.log"
OMESSO = "[OMESSO]"
COLONNE = ("id_ticket", "aperto_il", "chiuso_il", "canale", "cliente",
           "tipo_cliente", "comune", "tecnologia", "categoria", "priorita",
           "stato", "oggetto", "descrizione", "team",
           "minuti_prima_risposta", "minuti_risoluzione", "soddisfazione")
INVARIATE = ("aperto_il", "chiuso_il", "canale", "tipo_cliente", "comune",
             "tecnologia", "categoria", "priorita", "stato", "team",
             "minuti_prima_risposta", "minuti_risoluzione", "soddisfazione")
TESTI = ("oggetto", "descrizione")
GIORNI = ("lun", "mar", "mer", "gio", "ven", "sab", "dom")
RIGA_LOG = re.compile(r"(\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ)\t([0-9]+)\t"
                      r"([0-9]+|-)")
AFFERMAZIONE = ("«It makes the change, runs the check, and if something "
                "broke it reads the output and fixes it before running the "
                "check again.»")
FONTE = "https://code.claude.com/docs/en/best-practices"
COME_DATO = ("  Come dato: il registro lo scrive il controllo a ogni "
             "esecuzione, chiunque\n  lo esegua. Che Claude l'abbia "
             "eseguito lo dicono le sue chiamate, non il\n  registro.")
IN_PARTE = ("  Un dato rimasto in parte ha una parte fuori dagli [OMESSO], "
            "come il tipo di\n  via o il numero civico di un indirizzo, "
            "o il dominio di un'e-mail: è da\n  guardare. Un nome rimasto a "
            "metà è già un residuo del controllo.")
FINE = ("Fatto: il file anonimo, i dati personali rimasti e il profilo sono "
        "quelli attesi.")


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


def leggi_grezzo() -> List[Dict[str, str]]:
    """Le righe del CSV grezzo originale dell'elemento."""
    dati = leggi_byte(GREZZO)
    if dati is None:
        raise Precondizione("manca %s" % GREZZO)
    try:
        righe = list(csv.DictReader(io.StringIO(dati.decode("utf-8"),
                                                newline="")))
    except (UnicodeDecodeError, csv.Error):
        raise Precondizione("%s non si legge come CSV UTF-8" % GREZZO)
    if not righe or "id_cliente" not in righe[0]:
        raise Precondizione("%s non è il CSV della settimana" % GREZZO)
    return righe


def pseudonimi_attesi(grezze: Sequence[Dict[str, str]]) -> List[str]:
    """C-001, C-002, … in ordine di prima comparsa del codice cliente."""
    assegnati: Dict[str, str] = {}
    uscita = []
    for r in grezze:
        codice = r["id_cliente"]
        if codice and codice not in assegnati:
            assegnati[codice] = "C-%03d" % (len(assegnati) + 1)
        uscita.append(assegnati.get(codice, ""))
    return uscita


def tratti_rimasti(anonimo: str, grezzo: str
                   ) -> Optional[List[Tuple[int, int]]]:
    """Se il testo anonimo è il grezzo con [OMESSO] al posto di qualche
    tratto, i tratti del grezzo che restano, (inizio, fine) in ordine, uno
    prima di ogni [OMESSO] e uno dopo l'ultimo: fra due tratti consecutivi
    sta il tratto omesso (anche vuoto). None se non lo è."""
    pezzi = anonimo.split(OMESSO)
    if len(pezzi) == 1:
        return [(0, len(grezzo))] if anonimo == grezzo else None
    if not grezzo.startswith(pezzi[0]):
        return None
    tratti = [(0, len(pezzi[0]))]
    posizione = len(pezzi[0])
    for pezzo in pezzi[1:-1]:
        trovato = grezzo.find(pezzo, posizione)
        if trovato < 0:
            return None
        posizione = trovato + len(pezzo)
        tratti.append((trovato, posizione))
    ultimo = pezzi[-1]
    if not grezzo.endswith(ultimo) or len(grezzo) - len(ultimo) < posizione:
        return None
    tratti.append((len(grezzo) - len(ultimo), len(grezzo)))
    return tratti


def con_omissioni(anonimo: str, grezzo: str) -> Optional[int]:
    """Quanti caratteri del testo grezzo restano, se il testo anonimo è il
    grezzo con [OMESSO] al posto di qualche tratto; None altrimenti."""
    tratti = tratti_rimasti(anonimo, grezzo)
    return None if tratti is None else sum(b - a for a, b in tratti)


def misura_in_parte(cp: ModuleType, impronte: Any,
                    allineati: Sequence[Tuple[str, List[Tuple[int, int]]]]
                    ) -> Tuple[Dict[str, int], int]:
    """Dalle posizioni, sui testi allineati (il grezzo e i suoi tratti
    rimasti): per classe, i dati del corso (quelli che il controllo
    originale trova nel grezzo) con almeno una lettera o cifra rimasta e
    almeno una omessa; e le omissioni (i tratti fra due tratti rimasti)
    che non coprono nessun dato del corso."""
    in_parte = {c: 0 for c in cp.NOMI_CLASSI}
    senza_dato = 0
    for grezzo, tratti in allineati:
        rimasto = [False] * len(grezzo)
        for a, b in tratti:
            rimasto[a:b] = [True] * (b - a)
        dati = cp.cerca(grezzo, impronte)
        for classe, a, b in dati:
            alfanumerici = [rimasto[i] for i in range(a, b)
                            if grezzo[i].isalnum()]
            if any(alfanumerici) and not all(alfanumerici):
                in_parte[classe] += 1
        for (_a, fine), (inizio, _b) in zip(tratti, tratti[1:]):
            if not (fine < inizio and any(a < inizio and fine < b
                                          for _c, a, b in dati)):
                senza_dato += 1
    return in_parte, senza_dato


def quanti(n: int, singolare: str, plurale: str) -> str:
    """«1 riga», «3 righe»."""
    return "%d %s" % (n, singolare if n == 1 else plurale)


def _giorno(data: str) -> str:
    try:
        return GIORNI[dt.date.fromisoformat(data[:10]).weekday()]
    except ValueError:
        return "?"


def _leggi_anonimo(percorso: str, problemi: List[str]
                   ) -> Optional[Tuple[List[str], List[List[str]]]]:
    """(l'intestazione, le righe) del file anonimo; None, con il problema,
    se manca o non è un CSV UTF-8 senza BOM e con fine riga LF."""
    dati = leggi_byte(percorso)
    if dati is None:
        problemi.append("manca %s: Claude deve scriverlo con anonimizza.py"
                        % percorso)
        return None
    if dati.startswith(b"\xef\xbb\xbf"):
        problemi.append("%s comincia con un BOM: serve UTF-8 senza BOM"
                        % percorso)
    if b"\r" in dati:
        problemi.append("%s ha fine riga CRLF (o un CR): serve LF" % percorso)
    try:
        testo = dati.decode("utf-8-sig")
        righe = [r for r in csv.reader(io.StringIO(testo, newline=""),
                                       strict=True) if r]
    except (UnicodeDecodeError, csv.Error):
        problemi.append("%s non si legge come CSV UTF-8" % percorso)
        return None
    if not righe:
        problemi.append("%s è vuoto" % percorso)
        return None
    return righe[0], righe[1:]


def _confronta_colonne(righe: List[Dict[str, str]],
                       grezze: Sequence[Dict[str, str]],
                       problemi: List[str]) -> None:
    for colonna in INVARIATE:
        diverse = [g["id_ticket"] for r, g in zip(righe, grezze)
                   if r[colonna] != g[colonna]]
        if diverse:
            problemi.append("la colonna %s è cambiata in %s (la prima: %s): "
                            "deve restare com'è" % (
                                colonna, quanti(len(diverse), "riga", "righe"),
                                diverse[0]))
    attesi = [_giorno(g["aperto_il"]) for g in grezze]
    trovati = [_giorno(r["aperto_il"]) for r in righe]
    if [trovati.count(g) for g in GIORNI] != [attesi.count(g)
                                              for g in GIORNI]:
        problemi.append("le segnalazioni per giorno non sono quelle del file "
                        "grezzo")
    pseudonimi = pseudonimi_attesi(grezze)
    sbagliati = [g["id_ticket"] for r, g, p in zip(righe, grezze, pseudonimi)
                 if r["cliente"] != p]
    if sbagliati:
        problemi.append("cliente: pseudonimi diversi da quelli attesi in %s "
                        "(la prima: %s); C-001, C-002, … in ordine di prima "
                        "comparsa del codice cliente, vuoto se il codice è "
                        "vuoto" % (quanti(len(sbagliati), "riga", "righe"),
                                   sbagliati[0]))


def _confronta_testi(righe: List[Dict[str, str]],
                     grezze: Sequence[Dict[str, str]],
                     problemi: List[str], dati: Dict[str, Any]) -> None:
    rimasti = totali = omissioni = 0
    sbagliati: List[str] = []
    allineati: List[Tuple[str, List[Tuple[int, int]]]] = []
    for r, g in zip(righe, grezze):
        for colonna in TESTI:
            omissioni += r[colonna].count(OMESSO)
            totali += len(g[colonna])
            tratti = tratti_rimasti(r[colonna], g[colonna])
            if tratti is None:
                sbagliati.append("%s, %s" % (g["id_ticket"], colonna))
            else:
                rimasti += sum(b - a for a, b in tratti)
                allineati.append((g[colonna], tratti))
    dati["omissioni"] = omissioni
    dati["conservato"] = 100.0 * rimasti / totali if totali else 100.0
    # I testi allineati con il grezzo, per la misura dalle posizioni: solo
    # se lo sono tutti (mai stampati: sono il testo grezzo).
    dati["allineati"] = None if sbagliati else allineati
    if sbagliati:
        problemi.append("oggetto e descrizione: %s non è il testo originale "
                        "con [OMESSO] al posto dei dati personali (il primo: "
                        "%s): si sostituisce, non si riscrive" % (
                            quanti(len(sbagliati), "testo", "testi"),
                            sbagliati[0]))


def controlla_file(percorso: str, grezze: Sequence[Dict[str, str]]
                   ) -> Tuple[List[str], Dict[str, Any]]:
    """I problemi di forma del file anonimo rispetto al grezzo, e i dati
    da stampare (omissioni, parte di testo conservata, i testi allineati
    per misura_in_parte, None se uno non si allinea). La usa anche
    _docente/residui.py."""
    problemi: List[str] = []
    dati: Dict[str, Any] = {}
    letto = _leggi_anonimo(percorso, problemi)
    if letto is None:
        return problemi, dati
    intestazione, righe_csv = letto
    if tuple(intestazione) != COLONNE:
        mancanti = [c for c in COLONNE if c not in intestazione]
        in_piu = [c for c in intestazione if c not in COLONNE]
        problemi.append("l'intestazione non è quella attesa, le 17 colonne "
                        "nell'ordine (mancano: %s; in più: %s)" % (
                            ", ".join(mancanti) or "nessuna",
                            ", ".join(in_piu) or "nessuna"))
        return problemi, dati
    if any(len(r) != len(COLONNE) for r in righe_csv):
        problemi.append("%s ha righe con un numero di campi diverso da 17"
                        % percorso)
        return problemi, dati
    righe = [dict(zip(COLONNE, r)) for r in righe_csv]
    if [r["id_ticket"] for r in righe] != [g["id_ticket"] for g in grezze]:
        problemi.append("le righe non sono quelle del file grezzo nello "
                        "stesso ordine: %d invece di %d, o id_ticket in un "
                        "altro ordine" % (len(righe), len(grezze)))
        return problemi, dati
    _confronta_colonne(righe, grezze, problemi)
    _confronta_testi(righe, grezze, problemi, dati)
    return problemi, dati


def residui(cp: ModuleType, impronte: Any, percorso: str
            ) -> Tuple[Optional[Dict[str, int]], str]:
    """(i residui per classe, "") del controllo originale, o (None, perché
    non ha potuto girare)."""
    try:
        esito = cp.esamina(percorso, impronte)
    except cp.Precondizione as exc:
        return None, str(exc)
    conta = {c: 0 for c in cp.NOMI_CLASSI}
    for r in esito.residui:
        conta[r.classe] += 1
    return conta, ""


def mostra(valore: Any) -> str:
    """Un valore del profilo su una riga: i giorni nel loro ordine, le
    altre chiavi in ordine alfabetico."""
    if isinstance(valore, dict) and set(valore) <= set(GIORNI):
        valore = {g: valore[g] for g in GIORNI if g in valore}
        return json.dumps(valore, ensure_ascii=False)
    return json.dumps(valore, ensure_ascii=False, sort_keys=True)


def stampa_profilo(kv: ModuleType, problemi: List[str],
                   anonimo_presente: bool) -> None:
    """Il profilo: la chiave kpi confrontata con i KPI veri del file
    anonimo (se il file anonimo c'è)."""
    print("\nIl profilo (%s)" % PROFILO)
    dati = leggi_byte(PROFILO)
    if dati is None:
        problemi.append("manca %s: Claude deve scriverlo con profilo.py"
                        % PROFILO)
        print("  manca")
        return
    try:
        profilo = json.loads(dati.decode("utf-8"))
    except (UnicodeDecodeError, ValueError, RecursionError):
        problemi.append("%s non è un JSON valido" % PROFILO)
        print("  non è un JSON valido")
        return
    if not isinstance(profilo, dict) or not isinstance(profilo.get("kpi"),
                                                       dict):
        problemi.append("%s non ha la chiave kpi con un oggetto" % PROFILO)
        print("  senza la chiave kpi")
        return
    if not anonimo_presente:
        print("  i KPI si confrontano con il file anonimo, che manca")
        return
    try:
        voci = kv.confronta(profilo["kpi"], ANONIMO)
    except kv.Precondizione as exc:
        problemi.append("i KPI veri non si calcolano dal file anonimo (%s)"
                        % exc)
        return
    for chiave, atteso, trovato, giusto in voci:
        testo_atteso = "(chiave in più)" if atteso is None else \
            mostra(atteso)
        testo_trovato = "(manca)" if chiave not in profilo["kpi"] else \
            mostra(trovato)
        print("  %-40s %s" % (chiave, "ok" if giusto else "NO"))
        print("      atteso  %s" % testo_atteso)
        print("      trovato %s" % testo_trovato)
    sbagliate = [v[0] for v in voci if not v[3]]
    if sbagliate:
        problemi.append("i KPI del profilo non tornano: %s (le regole sono "
                        "in kpi_definizioni.md)" % ", ".join(sbagliate))


def esecuzioni() -> Tuple[List[int], int]:
    """(le uscite registrate in controlli.log, le righe illeggibili)."""
    dati = leggi_byte(LOG)
    if dati is None:
        return [], 0
    uscite, illeggibili = [], 0
    for riga in dati.decode("utf-8", errors="replace").splitlines():
        m = RIGA_LOG.fullmatch(riga.strip())
        if m is None:
            illeggibili += 1
            continue
        uscite.append(int(m.group(2)))
    return uscite, illeggibili


def stampa_controllo_eseguito() -> None:
    """Come dato: le esecuzioni del controllo registrate, le copie dello
    spazio di lavoro e la frase della guida, senza un esito: il registro lo
    scrive ogni esecuzione del controllo, chiunque la faccia."""
    print("\nIl controllo eseguito nello spazio di lavoro (%s, come dato)"
          % LOG)
    uscite, illeggibili = esecuzioni()
    if uscite:
        print("  esecuzioni registrate: %d; uscite, in ordine: %s" % (
            len(uscite), " ".join(str(u) for u in uscite)))
    else:
        print("  nessuna esecuzione registrata")
    if illeggibili:
        print("  righe che non hanno la forma del registro: %d" % illeggibili)
    for nome, originale in (("controlla_pii.py", CONTROLLO),
                            ("impronte.json", IMPRONTE)):
        presente = leggi_byte(nome)
        if presente is None:
            stato = "manca"
        elif presente == leggi_byte(originale):
            stato = "uguale all'originale"
        else:
            stato = "DIVERSO dall'originale"
        print("  %s dello spazio di lavoro: %s" % (nome, stato))
    print("\nLa guida di Claude Code, su Claude con un controllo: %s"
          % AFFERMAZIONE)
    print("  (%s)" % FONTE)
    print(COME_DATO)


def stampa_in_parte(cp: ModuleType, impronte: Any,
                    dati: Dict[str, Any]) -> None:
    """Come dato: i dati del corso rimasti in parte, per classe, e le
    omissioni senza un dato del corso (misura_in_parte)."""
    print("Come dato, dalle posizioni dei dati del corso nel testo grezzo:")
    if dati.get("allineati") is None:
        print("  non si misura: non tutti i testi sono il testo originale "
              "con [OMESSO]")
        return
    in_parte, senza_dato = misura_in_parte(cp, impronte, dati["allineati"])
    totale = sum(in_parte.values())
    classi = ", ".join("%s %d" % (c, n) for c, n in in_parte.items() if n)
    print("  dati del corso rimasti in parte: %d%s" % (
        totale, " (%s)" % classi if classi else ""))
    print("  omissioni senza un dato del corso: %d" % senza_dato)
    print(IN_PARTE)


def esamina(ws: str) -> int:
    cp = carica("controlla_pii_originale", CONTROLLO)
    kv = carica("kpi_veri_elemento", KPI_VERI)
    try:
        impronte = cp.carica_impronte(IMPRONTE)
    except cp.Precondizione as exc:
        raise Precondizione("le impronte originali dell'elemento: %s" % exc)
    grezze = leggi_grezzo()
    os.chdir(ws)
    print("M3-E01: la verifica di %s e di %s" % (ANONIMO, PROFILO))
    print("\nIl file anonimo")
    problemi, dati = controlla_file(ANONIMO, grezze)
    anonimo_presente = leggi_byte(ANONIMO) is not None
    if not anonimo_presente:
        print("  manca")
    elif not problemi:
        print("  le 17 colonne, le %d righe nell'ordine, le colonne rimaste "
              "com'erano, gli pseudonimi, i testi con [OMESSO]: ok"
              % len(grezze))
    if "omissioni" in dati:
        print("  come dato: %d [OMESSO] in oggetto e descrizione; resta il "
              "%.0f%% dei caratteri del testo originale" % (
                  dati["omissioni"], dati["conservato"]))
    if anonimo_presente:
        conta, perche = residui(cp, impronte, ANONIMO)
        if conta is None:
            problemi.append("il controllo dei dati personali non può girare "
                            "sul file anonimo (%s)" % perche)
        else:
            totale = sum(conta.values())
            print("\nDati personali rimasti, ricalcolati con il controllo "
                  "originale: %d" % totale)
            print("  " + ", ".join("%s %d" % (c, n) for c, n in conta.items()))
            stampa_in_parte(cp, impronte, dati)
            if totale:
                problemi.append("%s nel file anonimo (python3 controlla_pii.py "
                                "--forme dice dove)" % (
                                    "resta 1 dato personale" if totale == 1
                                    else "restano %d dati personali" % totale))
    stampa_profilo(kv, problemi, anonimo_presente)
    stampa_controllo_eseguito()
    if problemi:
        print()
        for p in problemi:
            print("Non ancora: %s." % p)
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
    except Exception as exc:  # l'ultima rete: mai un traceback, e del
        # messaggio solo il tipo, che non può contenere un valore del file
        sys.stderr.write("verifica: errore inatteso (%s)\n"
                         % type(exc).__name__)
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
