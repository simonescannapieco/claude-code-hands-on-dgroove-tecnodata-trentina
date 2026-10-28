#!/usr/bin/env python3
"""verifica.py di M4-E03 -- i controlli di verifica.sh, accanto a questo file.

Controlla, nello spazio di lavoro:
  - progetti/gestionale-php/docs/chiusura_mese.md: le sei sezioni, come
    titoli «## », nell'ordine, ognuna con il suo testo; «Tabelle lette e
    scritte» nomina ogni tabella che la chiusura legge o scrive, anche
    attraverso le funzioni che chiama; «Le sei responsabilità» ha sei voci;
  - PROPOSTA.md: almeno tre passi «## Passo N», numerati 1, 2, 3, …, ognuno
    con la riga «Controllo:» che esegue i test (phpunit);
  - i test di caratterizzazione, i file *Test.php nuovi o cambiati sotto
    progetti/gestionale-php/tests/ rispetto al primo commit (il punto di
    partenza): verdi sul modulo com'era, rossi su una copia rotta apposta.
    Non girano mai nello spazio di lavoro, ma in due copie temporanee del
    progetto con legacy/ preso dal primo commit; nella seconda la verifica
    cambia la riga 29 del modulo in «$simula = true;», e la chiusura vera
    non scrive più niente, come in simulazione. PHP gira con tools/php.sh
    del repository, mai con la copia dello spazio di lavoro;
  - progetti/gestionale-php/legacy/ uguale al primo commit: un file cambiato,
    nel commit o fuori, o un file nuovo è una segnalazione.
Poi stampa come dati, mai come esito: la regola deny nelle impostazioni,
NOTA.md, i piani di plan mode in piani/, i commit e, dalle trascrizioni
delle sessioni di Claude Code di questo spazio di lavoro, le chiamate al
tool Agent (prima della 2.1.63 si chiamava Task: si contano tutti e due),
le trascrizioni dei subagent, le chiamate ExitPlanMode e quelle di Edit o
Write su legacy/.

Le trascrizioni: Claude Code le salva in JSONL in
~/.claude/projects/<progetto>/<sessione>.jsonl, dove <progetto> è il percorso
della cartella di lavoro con i caratteri che non sono lettere o cifre
cambiati in «-» (un nome oltre i 200 caratteri è troncato a 200 e seguito da
un hash del percorso); quelle dei subagent in
<sessione>/subagents/agent-<id>.jsonl. Il formato delle righe è interno a
Claude Code e cambia fra le versioni: ciò che se ne legge è un dato.

Uso:    python3 -B -I verifica.py <spazio di lavoro>
Env:    PN_HANDSON_ROOT (il repository: tools/php.sh), PN_PHP_SH (il php.sh
        da usare al suo posto), PN_CLAUDE_DIR (al posto di ~/.claude)
Uscita: 0 = fatto · 1 = non ancora, con che cosa manca · 2 = precondizione,
        anche un'uscita di PHPUnit che non è un esito dei test (Docker, un
        segnale) o un errore inatteso: mai un «fatto» quando non può
        decidere
"""
import glob
import json
import os
import re
import shutil
import signal
import subprocess
import sys
import tempfile
from typing import Dict, Iterator, List, Sequence, Set, Tuple

PROGETTO = "progetti/gestionale-php"
DOC = PROGETTO + "/docs/chiusura_mese.md"
PROPOSTA = "PROPOSTA.md"
LEGACY = PROGETTO + "/legacy"
TESTS = PROGETTO + "/tests/"
MODULO = "legacy/chiusura_mese.inc.php"
REGOLA_DENY = "Edit(/progetti/gestionale-php/legacy/**)"
SEZIONI = ("Che cosa fa", "Ingressi e uscite", "Tabelle lette e scritte",
           "Effetti collaterali", "Le sei responsabilità", "Rischi")
TABELLE = ("fatture", "righe_fattura", "clienti", "linee", "ticket",
           "provvigioni", "attivazioni", "offerte", "registro_operazioni")
VOCI_ATTESE = 6
PASSI_MINIMI = 3
RIGA_ORIGINALE = "    $simula = !empty($opzioni['simula']);\n"
RIGA_ROTTA = "    $simula = true;\n"
ROTTURA = ("in legacy/chiusura_mese.inc.php, riga 29, «$simula = true;»: "
           "la chiusura vera non scrive più niente, come in simulazione")
INSTALLA = "tools/php.sh composer install -d " + PROGETTO
SECONDI = 900
FINE = ("Fatto: documentazione e proposta complete, i test fissano il "
        "comportamento e legacy/ è com'era.")
ANSI = re.compile(r"\x1b\[[0-9;]*[A-Za-z]")
VOCE = re.compile(r"^\s{0,3}(?:[-*+]|\d+[.)])\s+\S|^###\s")
# L'uscita di PHPUnit: l'avvio, il riepilogo dei fallimenti (uscita 1 per
# fallimenti e test rischiosi, 2 per errori), i test che non si caricano.
AVVIO = re.compile(r"^PHPUnit\b", re.MULTILINE)
FALLITI = re.compile(r"^(?:FAILURES!|ERRORS!|Tests: \d+)", re.MULTILINE)
NON_CARICATI = re.compile(r"An error occurred inside PHPUnit|Fatal error|"
                          r"Parse error")
SUL_ORIGINALE = {
    "rossi": "i test non passano sul codice originale: ",
    "rotti": "i test non si eseguono sul codice originale: ",
    "interrotti": "i test si sono fermati sul codice originale senza il "
                  "riepilogo di PHPUnit (un die() o un exit nel codice "
                  "provato?): ",
    "vuoti": "i file di test non eseguono nessun test: ",
}


class Precondizione(Exception):
    """La verifica non può partire o finire: uscita 2."""


def leggi(percorso: str) -> str:
    with open(percorso, encoding="utf-8", errors="replace") as fh:
        return fh.read()


def git(ws: str, *argomenti: str, entrata: str = "") -> str:
    """Un comando git di sola lettura nello spazio di lavoro, senza i lock
    facoltativi. La verifica non usa git diff né git status, che possono
    riscrivere .git/index."""
    ambiente = dict(os.environ, GIT_OPTIONAL_LOCKS="0")
    esito = subprocess.run(["git", "-C", ws, "-c", "core.quotepath=off"]
                           + list(argomenti), input=entrata,
                           stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                           universal_newlines=True, env=ambiente)
    if esito.returncode != 0:
        raise Precondizione("git %s non riesce: %s" % (
            argomenti[0], esito.stderr.strip()))
    return esito.stdout


def punto_di_partenza(ws: str) -> str:
    """Il primo commit, quello di prepara_esercizio.sh."""
    try:
        radici = git(ws, "rev-list", "--max-parents=0", "HEAD").split()
    except Precondizione:
        radici = []
    if not radici or not os.path.isdir(os.path.join(ws, ".git")):
        raise Precondizione("%s non è uno spazio di lavoro con git: "
                            "preparalo con tools/prepara_esercizio.sh M4-E03"
                            % ws)
    return radici[-1]


def cambiati(ws: str, radice: str, cartella: str) -> List[str]:
    """I file sotto cartella diversi dal primo commit: cambiati (nel commit
    o fuori), nuovi o cancellati. Confronta i contenuti, con git
    hash-object sui file e git ls-tree sul primo commit, che non scrivono
    niente; la data di un file non conta."""
    originali: Dict[str, str] = {}
    for voce in git(ws, "ls-tree", "-r", "-z", radice, "--",
                    cartella).split("\0"):
        if voce:
            info, percorso = voce.split("\t", 1)
            originali[percorso] = info.split()[2]
    elenco = git(ws, "ls-files", "-z", "--cached", "--others",
                 "--exclude-standard", "--", cartella).split("\0")
    presenti = sorted({p for p in elenco
                       if p and os.path.isfile(os.path.join(ws, p))})
    impronte = git(ws, "hash-object", "--stdin-paths",
                   entrata="".join(p + "\n" for p in presenti)).split()
    diversi = {p for p, h in zip(presenti, impronte) if originali.get(p) != h}
    cancellati = {p for p in originali
                  if not os.path.isfile(os.path.join(ws, p))}
    return sorted(diversi | cancellati)


def sezione(titolo: str) -> None:
    print("\n" + titolo)


def esito(problemi: List[str], ok: str) -> List[str]:
    """Stampa i problemi, o la riga ok se non ce ne sono."""
    for problema in problemi:
        print("  NO  " + problema)
    if not problemi:
        print("  ok  " + ok)
    return problemi


# --- La documentazione -----------------------------------------------------

def titoli(testo: str) -> List[Tuple[str, List[str]]]:
    """I titoli «## » e le righe di ciascuno, fino al titolo «## » dopo."""
    blocchi: List[Tuple[str, List[str]]] = []
    for riga in testo.splitlines():
        if re.match(r"^##\s", riga):
            blocchi.append((riga[2:].strip(), []))
        elif blocchi:
            blocchi[-1][1].append(riga)
    return blocchi


def richiesta(titolo: str) -> str:
    """La sezione richiesta che il titolo nomina, oppure ""."""
    t = re.sub(r"[*_`]", "", titolo)
    t = re.sub(r"^\d+\s*[.)]?\s*", "", t).strip().lower()
    for nome in SEZIONI:
        n = nome.lower()
        if t == n or (t.startswith(n) and not t[len(n)].isalnum()):
            return nome
    return ""


def controlla_documentazione(ws: str) -> List[str]:
    percorso = os.path.join(ws, DOC)
    if not os.path.isfile(percorso):
        return ["manca la documentazione: " + DOC]
    trovate: Dict[str, List[str]] = {}
    for titolo, righe in titoli(leggi(percorso)):
        nome = richiesta(titolo)
        if nome and nome not in trovate:
            trovate[nome] = righe
    problemi = ["la documentazione non ha la sezione «%s»" % s
                for s in SEZIONI if s not in trovate]
    if list(trovate) != [s for s in SEZIONI if s in trovate]:
        problemi.append("le sezioni della documentazione non sono "
                        "nell'ordine chiesto: " + " · ".join(SEZIONI))
    for nome, righe in trovate.items():
        if not any(re.search(r"\w", r) for r in righe):
            problemi.append("nella documentazione la sezione «%s» è vuota"
                            % nome)
        elif nome == "Tabelle lette e scritte":
            testo = "\n".join(righe)
            mancano = [t for t in TABELLE if not re.search(
                r"(?<!\w)%s(?!\w)" % t, testo, re.IGNORECASE)]
            if mancano:
                problemi.append("la sezione «Tabelle lette e scritte» non "
                                "nomina: " + ", ".join(mancano))
        elif nome == "Le sei responsabilità":
            voci = sum(1 for r in righe if VOCE.match(r))
            if voci < VOCI_ATTESE:
                problemi.append("la sezione «Le sei responsabilità» ha %d "
                                "voci: ne servono sei" % voci)
    return problemi


# --- La proposta -----------------------------------------------------------

def passi(testo: str) -> List[Tuple[int, List[str]]]:
    """I passi «## Passo N» e le loro righe; un altro titolo li chiude."""
    trovati: List[Tuple[int, List[str]]] = []
    aperto = False
    for riga in testo.splitlines():
        m = re.match(r"^#{2,3}\s+[*_]*Passo\s+(\d+)\b", riga, re.IGNORECASE)
        if m:
            trovati.append((int(m.group(1)), []))
            aperto = True
        elif re.match(r"^#{1,3}\s", riga):
            aperto = False
        elif aperto:
            trovati[-1][1].append(riga)
    return trovati


def controllo_del_passo(righe: List[str]) -> Tuple[bool, bool]:
    """C'è la riga «Controllo:»? Esegue i test (in quella riga o nelle
    quattro dopo, per un comando a capo)?"""
    pulite = [re.sub(r"[*_]", "", r) for r in righe]
    for i, riga in enumerate(pulite):
        if re.match(r"^\s*(?:-\s+)?Controllo\s*:", riga, re.IGNORECASE):
            finestra = " ".join(righe[i:i + 5]).lower()
            return True, "phpunit" in finestra
    return False, False


def controlla_proposta(ws: str) -> Tuple[List[str], int]:
    percorso = os.path.join(ws, PROPOSTA)
    if not os.path.isfile(percorso):
        return ["manca la proposta: PROPOSTA.md, nella radice dello spazio "
                "di lavoro"], 0
    trovati = passi(leggi(percorso))
    numeri = [n for n, _ in trovati]
    problemi = []
    if len(trovati) < PASSI_MINIMI:
        problemi.append("la proposta ha %d passi: ne servono almeno tre"
                        % len(trovati))
    if numeri != list(range(1, len(numeri) + 1)):
        problemi.append("i passi della proposta non sono numerati 1, 2, 3, "
                        "…: " + ", ".join(str(n) for n in numeri))
    for n, righe in trovati:
        ha_controllo, esegue_i_test = controllo_del_passo(righe)
        if not ha_controllo:
            problemi.append("il passo %d della proposta non ha la riga "
                            "«Controllo:»" % n)
        elif not esegue_i_test:
            problemi.append("il controllo del passo %d non esegue i test "
                            "(phpunit)" % n)
    return problemi, len(trovati)


# --- I test, sulle copie ---------------------------------------------------

def php_sh() -> str:
    """tools/php.sh del repository (PN_PHP_SH lo sostituisce)."""
    percorso = os.environ.get("PN_PHP_SH", "")
    if not percorso:
        radice = os.environ.get("PN_HANDSON_ROOT") or os.path.join(
            os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "..")
        percorso = os.path.join(radice, "tools", "php.sh")
    # i test girano dalla cartella della copia: serve un percorso assoluto
    percorso = os.path.abspath(percorso)
    if not (os.path.isfile(percorso) and os.access(percorso, os.X_OK)):
        raise Precondizione("manca tools/php.sh: %s" % percorso)
    return percorso


def esegui(argv: List[str], cartella: str) -> Tuple[int, str]:
    try:
        esito = subprocess.run(argv, cwd=cartella, stdout=subprocess.PIPE,
                               stderr=subprocess.STDOUT, timeout=SECONDI)
    except subprocess.TimeoutExpired:
        raise Precondizione("i test non hanno finito in %d secondi" % SECONDI)
    testo = esito.stdout.decode("utf-8", errors="replace")
    return esito.returncode, ANSI.sub("", testo)


def riassunto(testo: str) -> str:
    """La riga di PHPUnit che riassume l'esito, o l'ultima."""
    righe = [r.strip() for r in testo.splitlines() if r.strip()]
    for riga in reversed(righe):
        if riga.startswith(("OK (", "OK, but", "Tests:", "No tests",
                            "Message:")):
            return riga
    return righe[-1][:200] if righe else "nessuna uscita"


def pronto(ws: str, php: str) -> None:
    """vendor/ c'è e PHP parte: altrimenti una precondizione."""
    progetto = os.path.join(ws, PROGETTO)
    if not os.path.isfile(os.path.join(progetto, "vendor", "bin", "phpunit")):
        raise Precondizione("manca vendor/bin/phpunit nel gestionale: dalla "
                            "radice dello spazio di lavoro, " + INSTALLA)
    rc, testo = esegui([php, "php", "-r", "exit(0);"], progetto)
    if rc != 0:
        raise Precondizione("PHP non parte: " + riassunto(testo))


def copia(ws: str, radice: str, destinazione: str, rompi: bool) -> None:
    """Il progetto in una copia, con legacy/ del primo commit; con rompi,
    la riga di $simula cambiata."""
    shutil.copytree(os.path.join(ws, PROGETTO), destinazione, symlinks=True,
                    ignore=shutil.ignore_patterns(".phpunit.cache"))
    originali = {p[len(PROGETTO) + 1:] for p in git(
        ws, "ls-tree", "-r", "-z", "--name-only", radice, "--",
        LEGACY + "/").split("\0") if p}
    for base, _, nomi in os.walk(os.path.join(destinazione, "legacy")):
        for nome in nomi:
            rel = os.path.relpath(os.path.join(base, nome), destinazione)
            if rel.replace(os.sep, "/") not in originali:
                os.remove(os.path.join(base, nome))
    for rel in originali:
        esito = subprocess.run(["git", "-C", ws, "show", "%s:%s/%s" % (
            radice, PROGETTO, rel)], stdout=subprocess.PIPE,
            stderr=subprocess.PIPE)
        if esito.returncode != 0:
            raise Precondizione("git show non riesce per " + rel)
        percorso = os.path.join(destinazione, rel)
        os.makedirs(os.path.dirname(percorso), exist_ok=True)
        with open(percorso, "wb") as fh:
            fh.write(esito.stdout)
    if rompi:
        rompi_il_modulo(os.path.join(destinazione, MODULO))


def rompi_il_modulo(percorso: str) -> None:
    with open(percorso, encoding="utf-8", newline="") as fh:
        testo = fh.read()
    if testo.count(RIGA_ORIGINALE) != 1:
        raise Precondizione("la verifica non sa rompere questa versione del "
                            "modulo: in %s non trova una volta sola la riga "
                            "di $simula" % MODULO)
    with open(percorso, "w", encoding="utf-8", newline="") as fh:
        fh.write(testo.replace(RIGA_ORIGINALE, RIGA_ROTTA, 1))


def esito_test(php: str, cartella: str, file: List[str],
               dove: str) -> Tuple[str, str, List[str]]:
    """Com'è andata PHPUnit: «verdi» (uscita 0 e «OK»), «rossi» (uscita 1 o
    2 con il riepilogo dei fallimenti), «rotti» (i test non si caricano, un
    errore fatale), «interrotti» (uscita 0 senza «OK», dopo l'avvio),
    «vuoti»; con il riassunto e le ultime righe, la copia chiamata <copia>.
    Ogni altra uscita (Docker, un segnale) è una precondizione, che dice
    dove (sul codice originale, sulla copia rotta): mai un esito dei test."""
    rc, testo = esegui([php, "phpunit", "--colors=never"] + file, cartella)
    testo = testo.replace(cartella, "<copia>")
    coda = [r for r in testo.splitlines() if r.strip()][-15:]
    sintesi = riassunto(testo)
    if rc == 2 and "php.sh:" in testo:
        raise Precondizione("PHP non parte nella copia: " + sintesi)
    if "No tests executed" in testo:
        return "vuoti", sintesi, coda
    if rc == 0 and re.search(r"^OK\b", testo, re.MULTILINE):
        return "verdi", sintesi, coda
    if rc in (1, 2) and FALLITI.search(testo):
        return "rossi", sintesi, coda
    if rc == 255 and NON_CARICATI.search(testo):
        return "rotti", sintesi, coda
    if rc == 0 and AVVIO.search(testo):
        return "interrotti", sintesi, coda
    raise Precondizione("%s, PHPUnit non ha dato un esito dei test (uscita "
                        "%d): %s" % (dove, rc, sintesi))


def giudica(php: str, base: str, file: List[str]) -> List[str]:
    """Il giudice validato: verdi sull'originale, rossi sulla copia rotta.
    Sulla copia rotta conta solo il riepilogo dei fallimenti di PHPUnit:
    qualunque altra uscita è una precondizione, mai un «falliscono»."""
    stato, testo, coda = esito_test(php, os.path.join(base, "originale"),
                                    file, "sul codice originale")
    if stato != "verdi":
        for riga in coda:
            print("      | " + riga)
        return esito([SUL_ORIGINALE[stato] + testo], "")
    print("  ok  sul codice originale i test passano: " + testo)
    print("      la copia rotta apposta: " + ROTTURA)
    stato, testo, _ = esito_test(php, os.path.join(base, "rotta"), file,
                                 "sulla copia rotta apposta")
    if stato == "rossi":
        print("  ok  sulla copia rotta apposta i test falliscono: " + testo)
        return []
    if stato == "verdi":
        return esito(["i test passano anche sulla copia rotta apposta: non "
                      "fissano ciò che la chiusura scrive nel database"], "")
    raise Precondizione("sulla copia rotta apposta, PHPUnit non ha dato un "
                        "esito dei test (%s): %s" % (stato, testo))


def controlla_test(ws: str, radice: str) -> List[str]:
    file = [r[len(PROGETTO) + 1:] for r in cambiati(ws, radice, TESTS)
            if r.endswith("Test.php") and os.path.isfile(os.path.join(ws, r))]
    if not file:
        return esito(["nessun test di caratterizzazione nuovo in " + TESTS],
                     "")
    print("  i test di caratterizzazione: " + ", ".join(file))
    php = php_sh()
    pronto(ws, php)
    base = tempfile.mkdtemp(prefix="verifica-m4-e03.")
    try:
        copia(ws, radice, os.path.join(base, "rotta"), True)
        copia(ws, radice, os.path.join(base, "originale"), False)
        return giudica(php, base, file)
    finally:
        shutil.rmtree(base, ignore_errors=True)


# --- legacy/ e i dati ------------------------------------------------------

def controlla_legacy(ws: str, radice: str) -> List[str]:
    diversi = cambiati(ws, radice, LEGACY + "/")
    if diversi:
        return esito(["legacy/ è cambiato rispetto al punto di partenza: "
                      + ", ".join(diversi)], "")
    return esito([], "legacy/ è com'era al punto di partenza")


def regola_deny(ws: str) -> bool:
    try:
        with open(os.path.join(ws, ".claude", "settings.json"),
                  encoding="utf-8") as fh:
            regole = json.load(fh).get("permissions", {}).get("deny", [])
    except (OSError, ValueError, AttributeError):
        return False
    return isinstance(regole, list) and REGOLA_DENY in regole


def dati_lavoro(ws: str, radice: str) -> None:
    c = "c'è"
    print("  Dati: la regola deny %s nelle impostazioni dello spazio di "
          "lavoro: %s" % (REGOLA_DENY, c if regola_deny(ws) else "non " + c))
    print("  Dati: NOTA.md: %s" % (c if os.path.isfile(
        os.path.join(ws, "NOTA.md")) else "non " + c))
    piani = glob.glob(os.path.join(ws, "piani", "*.md"))
    print("  Dati: piani di plan mode in piani/: %d" % len(piani))
    commit = git(ws, "rev-list", "--count", radice + "..HEAD").strip()
    print("  Dati: commit dopo il punto di partenza: " + commit)


def cartelle_sessioni(ws: str) -> List[str]:
    """Le cartelle di ~/.claude/projects/ di questo spazio di lavoro."""
    base = os.path.join(os.environ.get("PN_CLAUDE_DIR") or os.path.join(
        os.path.expanduser("~"), ".claude"), "projects")
    trovate: List[str] = []
    for percorso in (os.path.abspath(ws), os.path.realpath(ws)):
        nome = re.sub(r"[^A-Za-z0-9]", "-", percorso)
        candidati = [nome]
        if len(nome) > 200:
            try:
                candidati = [d for d in os.listdir(base)
                             if d.startswith(nome[:200])]
            except OSError:
                candidati = []
        for c in candidati:
            cartella = os.path.join(base, c)
            if os.path.isdir(cartella) and cartella not in trovate:
                trovate.append(cartella)
    return trovate


def usi(oggetto: object) -> Iterator[dict]:
    """I blocchi tool_use dentro una riga di trascrizione."""
    if isinstance(oggetto, dict):
        if oggetto.get("type") == "tool_use" and \
                isinstance(oggetto.get("name"), str):
            yield oggetto
        for valore in oggetto.values():
            yield from usi(valore)
    elif isinstance(oggetto, list):
        for valore in oggetto:
            yield from usi(valore)


class Conteggi:
    """Ciò che si legge nelle trascrizioni della conversazione principale:
    le chiamate Agent (o Task) con tipo e messaggio, le ExitPlanMode, le
    chiamate degli strumenti di modifica su legacy/, le righe illeggibili."""

    def __init__(self) -> None:
        self.agent: Dict[str, Tuple[str, str]] = {}
        self.piani: Set[str] = set()
        self.legacy: Set[str] = set()
        self.illeggibili = 0


def conta_uso(uso: dict, mid: str, conti: Conteggi) -> None:
    chiave = str(uso.get("id", "")) or "%s-%d" % (mid, len(conti.agent))
    entrata = uso.get("input") if isinstance(uso.get("input"), dict) else {}
    if uso["name"] in ("Agent", "Task"):
        tipo = entrata.get("subagent_type")
        conti.agent[chiave] = (str(tipo or "senza tipo"), mid)
    elif uso["name"] == "ExitPlanMode":
        conti.piani.add(chiave)
    elif uso["name"] in ("Edit", "Write", "MultiEdit", "NotebookEdit") and \
            LEGACY + "/" in str(entrata.get("file_path", "")):
        conti.legacy.add(chiave)


def leggi_trascrizione(percorso: str, conti: Conteggi) -> None:
    """Una trascrizione: contano solo i messaggi del modello (le righe di
    type «assistant») e i loro blocchi tool_use. Le righe dei subagent
    (isSidechain) si saltano, e così ogni altra riga che ripete le
    chiamate senza il loro messaggio, come la copia di una richiesta
    (api-request-blob): le toglierebbe dal messaggio che le contiene.
    Le righe si separano solo a «\\n»: dentro una stringa JSON possono
    esserci U+2028 e simili, che splitlines() romperebbe."""
    for riga in leggi(percorso).split("\n"):
        if not riga.strip():
            continue
        try:
            record = json.loads(riga)
        except (ValueError, RecursionError):
            conti.illeggibili += 1
            continue
        if not isinstance(record, dict) or record.get("isSidechain") is True:
            continue
        messaggio = record.get("message")
        if record.get("type") != "assistant" or \
                not isinstance(messaggio, dict):
            continue
        mid = str(messaggio.get("id", ""))
        for uso in usi(messaggio.get("content")):
            conta_uso(uso, mid, conti)


def stampa_conteggi(sessioni: int, subagenti: int, conti: Conteggi,
                    regola: bool) -> None:
    tipi: Dict[str, int] = {}
    messaggi: Dict[str, int] = {}
    for tipo, mid in conti.agent.values():
        tipi[tipo] = tipi.get(tipo, 0) + 1
        messaggi[mid] = messaggi.get(mid, 0) + 1
    insieme = sum(n for mid, n in messaggi.items() if mid and n > 1)
    elenco = ", ".join("%s %d" % (t, tipi[t]) for t in sorted(tipi))
    print("  Dati: sessioni di Claude Code di questo spazio di lavoro: %d"
          % sessioni)
    print("  Dati: chiamate Agent: %d%s; nello stesso messaggio: %d" % (
        len(conti.agent), " (%s)" % elenco if elenco else "", insieme))
    print("  Dati: trascrizioni di subagent: %d" % subagenti)
    print("  Dati: piani presentati per l'approvazione (ExitPlanMode): %d"
          % len(conti.piani))
    print("  Dati: chiamate di Edit o Write su legacy/ (%s): %d" % (
        "la regola deny le ferma" if regola else "senza la regola deny",
        len(conti.legacy)))
    if conti.illeggibili:
        print("  Dati: righe delle trascrizioni che non si leggono: %d"
              % conti.illeggibili)


def dati_sessioni(ws: str) -> None:
    cartelle = cartelle_sessioni(ws)
    if not cartelle:
        print("  Dati: nessuna sessione di Claude Code per questo spazio di "
              "lavoro (in ~/.claude/projects/): nessun subagent trovato")
        return
    conti = Conteggi()
    sessioni = subagenti = 0
    for cartella in cartelle:
        for nome in sorted(os.listdir(cartella)):
            percorso = os.path.join(cartella, nome)
            if nome.endswith(".jsonl") and os.path.isfile(percorso):
                sessioni += 1
                leggi_trascrizione(percorso, conti)
        subagenti += len(glob.glob(os.path.join(cartella, "*", "subagents",
                                                "agent-*.jsonl")))
    stampa_conteggi(sessioni, subagenti, conti, regola_deny(ws))


def esamina(ws: str) -> int:
    if not os.path.isdir(ws):
        raise Precondizione("spazio di lavoro assente: %s" % ws)
    radice = punto_di_partenza(ws)
    if not os.path.isdir(os.path.join(ws, PROGETTO)):
        raise Precondizione("manca %s nello spazio di lavoro" % PROGETTO)
    print("M4-E03: la verifica dello spazio di lavoro")
    sezione("La documentazione (%s)" % DOC)
    problemi = esito(controlla_documentazione(ws), "le sei sezioni, in "
                     "ordine, ognuna con il suo testo; le %d tabelle; sei "
                     "responsabilità" % len(TABELLE))
    sezione("La proposta (PROPOSTA.md)")
    trovati, n = controlla_proposta(ws)
    problemi += esito(trovati, "%d passi, ognuno con il suo controllo" % n)
    sezione("Il modulo legacy (%s/)" % LEGACY)
    problemi += controlla_legacy(ws, radice)
    sezione("I test di caratterizzazione")
    problemi += controlla_test(ws, radice)
    sezione("Dati, mai esiti")
    dati_lavoro(ws, radice)
    dati_sessioni(ws)
    print()
    for problema in problemi:
        print("Non ancora: %s." % problema.rstrip("."))
    if problemi:
        return 1
    print(FINE)
    return 0


def interrotta(numero: int, _quadro: object) -> None:
    """SIGTERM o SIGHUP: un'uscita 2 che lascia girare i «finally», così
    le copie temporanee si cancellano."""
    raise SystemExit(2)


def main(argv: Sequence[str]) -> int:
    if len(argv) != 1:
        sys.stderr.write("Uso: verifica.py <spazio di lavoro>\n")
        return 2
    for segnale in (signal.SIGTERM, signal.SIGHUP):
        signal.signal(segnale, interrotta)
    try:
        return esamina(os.path.abspath(argv[0]))
    except Precondizione as errore:
        sys.stdout.flush()
        sys.stderr.write("verifica: %s\n" % errore)
        return 2
    except Exception as errore:  # mai un «fatto» né un «non ancora»
        sys.stdout.flush()
        sys.stderr.write("verifica: errore inatteso, la verifica non può "
                         "decidere: %s: %s\n" % (type(errore).__name__,
                                                  errore))
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
