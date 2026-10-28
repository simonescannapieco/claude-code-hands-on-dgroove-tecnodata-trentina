#!/usr/bin/env python3
"""verifica.py di M4-E01 «Un file mai visto»: i controlli di verifica.sh.

Legge lo spazio di lavoro con git (il primo commit è il punto di partenza)
e non si fida degli script dello spazio di lavoro: esegue PHPUnit con
tools/php.sh del repository (PN_HANDSON_ROOT), o con PN_PHP_SH.

Controlla:
  - spiegazione.md nella radice dello spazio di lavoro, non vuoto; le sue
    righe si stampano come dato: la spiegazione la legge una persona;
  - almeno un file di test nuovo o cambiato sotto
    progetti/gestionale-php/tests/ (rispetto al primo commit, anche se è
    già in un commit), con almeno un metodo di test nuovo, che passa con
    tools/php.sh phpunit;
  - le convenzioni dei test che il progetto ha già, una per riga, e la
    frase della guida decisa sul file: «confermata» se valgono tutte, «non
    confermata in questa esecuzione» se no; un esito sul comportamento di
    Claude, non l'uscita;
  - come dato, in una copia del progetto al primo commit con i test del
    partecipante: se il test cade quando il confine si sposta di un giorno
    (<= diventa < in VerificaCopertura.php); una dimostrazione che il
    controllo costruisce da sé. Prima i test girano sulla copia senza la
    modifica: se lì non passano, il dato è «non provato»;
  - come dato, i file cambiati fuori da tests/ e da spiegazione.md.

Uso:    verifica.py <spazio di lavoro>
Uscita: 0 fatto · 1 non ancora · 2 precondizione (spazio di lavoro, git,
        il gestionale, lo strumento per PHP, vendor/, PHP che non si
        avvia) o un errore inatteso: mai un «fatto» quando non può decidere
"""
import difflib
import io
import os
import re
import shutil
import subprocess
import sys
import tarfile
import tempfile
import textwrap
from typing import List, Tuple

PROGETTO = "progetti/gestionale-php"
TESTS = PROGETTO + "/tests/"
SORGENTE = "src/Copertura/VerificaCopertura.php"
CONFINE = "$riga['disponibile_dal'] <= $giorno"
SPOSTATO = "$riga['disponibile_dal'] < $giorno"
FRASE = ("«Claude examines your existing test files to match the style, "
         "frameworks, and assertion patterns already in use.»")
FONTE = "https://code.claude.com/docs/en/common-workflows"
METODO = re.compile(r"(public\s+)?(static\s+)?function\s+(test\w*)\s*"
                    r"\([^)]*\)\s*(?::\s*(\??\w+))?")
OGGI = re.compile(r"new\s+\\?DateTime(?:Immutable)?\s*\(\s*\)|\bdate\s*\("
                  r"|\btime\s*\(\s*\)|\bstrtotime\s*\(")
USA_DB = re.compile(r"DatabaseDiProva|\bPDO\b|Connessione::|sqlite", re.I)
RIGHE_SPIEGAZIONE = 40


class Precondizione(Exception):
    """Un controllo che non può partire: il messaggio, uscita 2."""


def git(ws: str, *argomenti: str) -> bytes:
    """L'uscita di un comando git nello spazio di lavoro."""
    try:
        fatto = subprocess.run(["git", "-C", ws] + list(argomenti),
                               stdout=subprocess.PIPE,
                               stderr=subprocess.PIPE, check=False)
    except OSError:
        raise Precondizione("manca git")
    if fatto.returncode != 0:
        raise Precondizione("%s non è uno spazio di lavoro preparato "
                            "(git: %s)" % (ws, fatto.stderr.decode(
                                "utf-8", "replace").strip()[:200]))
    return fatto.stdout


def punto_di_partenza(ws: str) -> str:
    """Il primo commit dello spazio di lavoro."""
    if not os.path.isdir(os.path.join(ws, ".git")):
        raise Precondizione("%s non è uno spazio di lavoro preparato "
                            "(manca il repository git)" % ws)
    radici = git(ws, "rev-list", "--max-parents=0", "HEAD").split()
    if len(radici) != 1:
        raise Precondizione("%s non è uno spazio di lavoro preparato "
                            "(atteso un solo primo commit)" % ws)
    return radici[0].decode()


def cambiati(ws: str, base: str) -> List[Tuple[str, str]]:
    """(percorso, «nuovo»|«cambiato»|«cancellato») rispetto al primo commit,
    compresi i file nuovi non ancora aggiunti a git."""
    parti = git(ws, "diff", "--name-status", "--no-renames", "-z",
                base).decode("utf-8", "replace").split("\0")
    nomi = {"A": "nuovo", "D": "cancellato"}
    elenco = [(parti[i + 1], nomi.get(parti[i][:1], "cambiato"))
              for i in range(0, len(parti) - 1, 2) if parti[i]]
    nuovi = git(ws, "ls-files", "--others", "--exclude-standard",
                "-z").decode("utf-8", "replace").split("\0")
    elenco += [(p, "nuovo") for p in nuovi if p]
    return sorted(set(elenco))


def al_punto_di_partenza(ws: str, base: str, percorso: str) -> str:
    """Il testo di un file al primo commit ("" se non c'era)."""
    fatto = subprocess.run(["git", "-C", ws, "show", "%s:%s" % (
        base, percorso)], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                           check=False)
    return fatto.stdout.decode("utf-8", "replace") if fatto.returncode == 0 \
        else ""


def leggi(percorso: str) -> str:
    with open(percorso, encoding="utf-8", errors="replace") as fh:
        return fh.read()


def aggiunte(prima: str, dopo: str) -> str:
    """Le righe che il file ha in più, o cambiate, rispetto a prima."""
    a, b = prima.splitlines(), dopo.splitlines()
    nuove = []  # type: List[str]
    confronto = difflib.SequenceMatcher(None, a, b, autojunk=False)
    for tag, _i1, _i2, j1, j2 in confronto.get_opcodes():
        if tag in ("insert", "replace"):
            nuove.extend(b[j1:j2])
    return "\n".join(nuove)


def convenzioni(rel: str, testo: str, nuove: str
                ) -> Tuple[List[Tuple[str, bool]], int, bool]:
    """Le convenzioni dei test del progetto su un file (rel: il percorso
    dentro il gestionale): i controlli, i metodi di test nuovi, la data."""
    cartelle = rel.split("/")[1:-1]
    ns = "CiaspoLink\\Gestionale\\Tests" + "".join("\\" + c for c in cartelle)
    classe = os.path.basename(rel)[:-len(".php")]
    metodi = METODO.findall(nuove)
    nomi_ok = bool(metodi) and all(
        pub and not sta and re.match(r"^test[A-Z][A-Za-z0-9]*$", nome)
        and tipo == "void" for pub, sta, nome, tipo in metodi)
    usa_db = bool(USA_DB.search(testo))
    controlli = [
        ("declare(strict_types=1)",
         bool(re.search(r"^\s*declare\s*\(\s*strict_types\s*=\s*1\s*\)\s*;",
                        testo, re.M))),
        ("namespace " + ns,
         bool(re.search(r"^\s*namespace\s+" + re.escape(ns) + r"\s*;",
                        testo, re.M))),
        ("final class %s extends TestCase (PHPUnit)" % classe,
         bool(re.search(r"^\s*final\s+class\s+" + re.escape(classe)
                        + r"\s+extends\s+TestCase\b", testo, re.M))
         and "use PHPUnit\\Framework\\TestCase;" in testo),
        ("asserzioni self::assert…, come gli altri test",
         "self::assert" in nuove
         and not re.search(r"\$this->assert|static::assert", nuove)),
        ("metodi nuovi: public function testInCamelCase(): void", nomi_ok),
        ("database dei test: DatabaseDiProva, in tests/Integrazione",
         not usa_db or (rel.startswith("tests/Integrazione/")
                        and "DatabaseDiProva::" in testo)),
    ]
    return controlli, len(metodi), not OGGI.search(nuove)


def strumento_php() -> str:
    """tools/php.sh del repository (o PN_PHP_SH), che deve esserci."""
    radice = os.environ.get("PN_HANDSON_ROOT") or os.path.normpath(
        os.path.join(os.path.dirname(os.path.abspath(__file__)),
                     *[os.pardir] * 4))
    php = os.environ.get("PN_PHP_SH") or os.path.join(radice, "tools",
                                                      "php.sh")
    if not (os.path.isfile(php) and os.access(php, os.X_OK)):
        raise Precondizione("manca lo strumento per PHP: %s (tools/php.sh "
                            "del repository)" % php)
    return php


def phpunit(php: str, cartella: str, file: List[str]) -> Tuple[int, str]:
    """PHPUnit sui file dati, nella cartella del progetto; uscita e testo.
    Un'uscita 2 con un messaggio di php.sh è una precondizione."""
    fatto = subprocess.run([php, "phpunit", "--colors=never"] + file,
                           cwd=cartella, stdout=subprocess.PIPE,
                           stderr=subprocess.PIPE, check=False)
    errori = fatto.stderr.decode("utf-8", "replace")
    if fatto.returncode == 2 and "php.sh:" in errori:
        raise Precondizione("PHP non si avvia: %s (PRIMA_DEL_CORSO.md, "
                            "«Docker, oppure PHP e Composer»)"
                            % errori.strip()[:300])
    return fatto.returncode, fatto.stdout.decode("utf-8", "replace") + errori


def estrai(dati: bytes, destinazione: str) -> None:
    """Estrae l'archivio di git, solo percorsi dentro il gestionale."""
    with tarfile.open(fileobj=io.BytesIO(dati)) as archivio:
        membri = [m for m in archivio.getmembers()
                  if m.name.startswith(PROGETTO + "/") and ".." not in
                  m.name.split("/") and not m.issym() and not m.islnk()]
        archivio.extractall(destinazione, members=membri)


def confine(ws: str, base: str, test: List[str], php: str) -> str:
    """Il dato del confine spostato: «sì», «no» o «non provato (…)». Prima
    i test sulla copia senza la modifica: il confine si prova soltanto se
    lì passano."""
    eseguibili = [t[len(PROGETTO) + 1:] for t in test
                  if t.endswith("Test.php")]
    with tempfile.TemporaryDirectory(prefix="verifica-m4-e01.") as tmp:
        dati = subprocess.run(["git", "-C", ws, "archive", "--format=tar",
                               base, PROGETTO], stdout=subprocess.PIPE,
                              stderr=subprocess.DEVNULL, check=False)
        if dati.returncode != 0:
            return "non provato (git archive non riesce)"
        estrai(dati.stdout, tmp)
        copia = os.path.join(tmp, PROGETTO)
        for rel in test:
            destinazione = os.path.join(tmp, rel)
            os.makedirs(os.path.dirname(destinazione), exist_ok=True)
            shutil.copyfile(os.path.join(ws, rel), destinazione)
        shutil.copytree(os.path.join(ws, PROGETTO, "vendor"),
                        os.path.join(copia, "vendor"), symlinks=True)
        sorgente = os.path.join(copia, SORGENTE)
        codice = leggi(sorgente)
        if codice.count(CONFINE) != 1:
            return "non provato (il confine non si trova nel codice)"
        rc, _testo = phpunit(php, copia, eseguibili)
        if rc != 0:
            return ("non provato (i test non passano sulla copia senza la "
                    "modifica)")
        with open(sorgente, "w", encoding="utf-8") as fh:
            fh.write(codice.replace(CONFINE, SPOSTATO))
        rc, _testo = phpunit(php, copia, eseguibili)
    return "sì" if rc != 0 else "no"


def spiegazione(ws: str, manca: List[str]) -> None:
    """spiegazione.md: c'è, non è vuota, le sue righe come dato."""
    percorso = os.path.join(ws, "spiegazione.md")
    if not os.path.isfile(percorso):
        print("spiegazione.md: non c'è")
        manca.append("manca spiegazione.md")
        return
    righe = [r for r in leggi(percorso).splitlines() if r.strip()]
    if not righe:
        print("spiegazione.md: c'è, ma è vuota")
        manca.append("spiegazione.md è vuota")
        return
    print("spiegazione.md: c'è, %d righe non vuote (il prompt ne chiedeva "
          "al massimo dieci);\nla legge una persona, la verifica no:"
          % len(righe))
    for riga in righe[:RIGHE_SPIEGAZIONE]:
        print("  | %s" % riga)


def esito_frase(tutti: List[Tuple[str, bool]]) -> None:
    """La frase della guida, decisa sul file: confermata o no."""
    print("\nLa frase della guida di Claude Code")
    print(textwrap.fill(FRASE, width=76, initial_indent="  ",
                        subsequent_indent="  "))
    print("  (%s)" % FONTE)
    if all(ok for _nome, ok in tutti):
        print("decisa sul file del test: confermata")
    else:
        print("decisa sul file del test: non confermata in questa "
              "esecuzione (le convenzioni con «no» qui sopra)")


def controlla_test(ws: str, base: str, test: List[Tuple[str, str]],
                   manca: List[str]) -> List[str]:
    """Le convenzioni di ogni test e la frase; i file da eseguire."""
    tutti = []  # type: List[Tuple[str, bool]]
    metodi = 0
    for percorso, stato in test:
        rel = percorso[len(PROGETTO) + 1:]
        testo = leggi(os.path.join(ws, percorso))
        nuove = testo if stato == "nuovo" else aggiunte(
            al_punto_di_partenza(ws, base, percorso), testo)
        controlli, n, data_fissa = convenzioni(rel, testo, nuove)
        metodi += n
        print("\ncome i test che il progetto ha già, %s:" % rel)
        for nome, ok in controlli:
            print("  %-60s %s" % (nome, "sì" if ok else "no"))
        print("  %-60s %s" % ("(dato) la data fissata nel test, regola 10.4",
                              "sì" if data_fissa else "no"))
        tutti += controlli
    esito_frase(tutti)
    if metodi == 0:
        manca.append("nessun metodo di test nuovo")
    return [p for p, _stato in test]


def esegui(ws: str, base: str, test: List[str], manca: List[str]) -> None:
    """Esegue i test con tools/php.sh e prova il confine spostato."""
    php = strumento_php()
    progetto = os.path.join(ws, PROGETTO)
    if not os.path.isfile(os.path.join(progetto, "vendor", "bin", "phpunit")):
        raise Precondizione(
            "mancano le dipendenze del gestionale (vendor/): dalla radice "
            "dello spazio di lavoro, tools/php.sh composer install -d "
            "progetti/gestionale-php")
    eseguibili = [t[len(PROGETTO) + 1:] for t in test if t.endswith("Test.php")]
    rc, testo = phpunit(php, progetto, eseguibili)
    righe = [r for r in testo.splitlines() if r.strip()]
    if rc == 0:
        print("\nil test eseguito con tools/php.sh phpunit: passa")
    else:
        # PHPUnit esce con 1 per un'asserzione fallita e con 2 per un
        # errore nel test; altro (255, un errore fatale di PHP) vuol dire
        # che il file non si esegue.
        print("\nil test eseguito con tools/php.sh phpunit: %s (uscita %d)"
              % ("non passa" if rc in (1, 2) else "non si esegue", rc))
        manca.append("il test non passa" if rc in (1, 2)
                     else "il test non si esegue")
    for riga in righe[-6:]:
        print("  | %s" % riga)
    print("\n(dato) il test cade se il confine si sposta di un giorno: %s"
          % confine(ws, base, test, php))
    print("       (in una copia del gestionale al primo commit, con «<=» "
          "cambiato in «<»\n       in VerificaCopertura.php: una prova che "
          "costruisce la verifica)")


def main(argv: List[str]) -> int:
    ws = os.path.realpath(argv[1]) if len(argv) > 1 and argv[1] else ""
    if not ws or not os.path.isdir(ws):
        raise Precondizione("spazio di lavoro assente: %s"
                            % (argv[1] if len(argv) > 1 else ""))
    base = punto_di_partenza(ws)
    if not os.path.isdir(os.path.join(ws, PROGETTO)):
        raise Precondizione("manca %s nello spazio di lavoro: preparalo con "
                            "tools/prepara_esercizio.sh M4-E01" % PROGETTO)
    elenco = cambiati(ws, base)
    manca = []  # type: List[str]
    print("Verifica di M4-E01 «Un file mai visto»\n")
    spiegazione(ws, manca)
    test = [(p, s) for p, s in elenco if p.startswith(TESTS)
            and s != "cancellato" and os.path.isfile(os.path.join(ws, p))]
    print("\ntest nuovi o cambiati sotto %s: %d" % (TESTS, len(test)))
    for percorso, stato in test:
        print("  %s (%s)" % (percorso[len(TESTS):], stato))
    if not test:
        manca.append("nessun test nuovo o cambiato sotto %s" % TESTS)
    else:
        esegui(ws, base, controlla_test(ws, base, test, manca), manca)
    fuori = [p for p, _s in elenco if not p.startswith(TESTS)
             and p != "spiegazione.md"]
    print("\n(dato) file cambiati fuori da tests/ e da spiegazione.md: %s"
          % (", ".join(fuori) if fuori else "nessuno"))
    if manca:
        print("\nNon ancora: %s." % "; ".join(manca))
        return 1
    print("\nFatto: spiegazione.md c'è e il test nuovo passa.")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv))
    except Precondizione as exc:
        sys.stderr.write("verifica: %s\n" % exc)
        sys.exit(2)
    except Exception as exc:  # mai un «fatto» né un «non ancora»
        sys.stdout.flush()
        sys.stderr.write("verifica: errore inatteso, la verifica non può "
                         "decidere: %s: %s\n" % (type(exc).__name__, " ".join(
                             str(exc).split())))
        sys.exit(2)
