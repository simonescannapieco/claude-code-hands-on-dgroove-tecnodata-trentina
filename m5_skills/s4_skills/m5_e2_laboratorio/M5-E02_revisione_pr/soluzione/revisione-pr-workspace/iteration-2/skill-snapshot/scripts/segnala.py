#!/usr/bin/env python3
"""Prepara la revisione di un pull request: legge la differenza rispetto a
main e stampa (1) le righe aggiunte con il numero di riga del file nuovo,
(2) i candidati a violazioni che si riconoscono dal testo, (3) le copie
gemelle in legacy/ o in src/ delle funzioni toccate.

I candidati sono indizi, non giudizi: chi rivede li conferma o li scarta
leggendo il file. Uso: python3 segnala.py [base]   (base predefinita: main)
"""
import re
import subprocess
import sys

BASE = sys.argv[1] if len(sys.argv) > 1 else "main"

# (regola, espressione, che cosa cercare). Solo ciò che il testo di una riga
# aggiunta mostra da solo.
INDIZI = [
    ("5.4", r"format\(\s*['\"]Y-m-d H:i(:s)?['\"]\s*\)", "data e ora senza offset"),
    ("5.6", r"new DateTimeImmutable\(\s*\)|new DateTime\(\s*\)|\btime\(\)|\bdate\(",
     "orologio di sistema letto in profondità"),
    ("5.1", r"\bfloat\b|\(float\)", "float vicino a importi?"),
    ("6.2", r"\b(die|exit)\b|^\s*echo\b|(?<![\w$])@\w", "die/exit/echo/@ in src/"),
    ("6.3", r"catch\s*\([^)]*\)\s*\{\s*\}?\s*$", "catch che può essere vuoto"),
    ("6.4", r"\bexit\(\s*1\s*\)", "uscita 1: è un rifiuto o un errore d'uso?"),
    ("7.1", r"(query|exec)\(.*[\"']\s*\.\s*\$|\"[^\"]*\b(SELECT|INSERT|UPDATE|DELETE)\b[^\"]*\{?\$",
     "valore concatenato nell'SQL"),
    ("7.3", r"\b(foreach|while|for)\b", "ciclo: controlla query al suo interno"),
    ("2.3", r"^.{121,}$", "riga oltre 120 caratteri"),
    ("2.5", r"^\s*//\s*(TODO|FIXME)(?!\()|^\s*//\s*\$|^\s*//.*;\s*$",
     "TODO senza riferimento o codice commentato"),
    ("4.1", r"function\s+\w+\([^)]*\$\w+[,)]|function\s+\w+\([^)]*\)\s*\{?\s*$",
     "parametro o ritorno forse senza tipo"),
    ("8.1", r"<\?=\s*\$(?!this->e)", "valore non passato da $this->e()"),
]


def esegui(*args):
    return subprocess.run(args, capture_output=True, text=True,
                          check=False).stdout


def aggiunte():
    """File -> lista di (numero di riga, testo) delle righe aggiunte."""
    risultato, file, riga = {}, None, 0
    for r in esegui("git", "diff", "-U0", f"{BASE}...HEAD").splitlines():
        if r.startswith("+++ b/"):
            file = r[6:]
            risultato[file] = []
        elif r.startswith("@@"):
            riga = int(re.search(r"\+(\d+)", r).group(1)) - 1
        elif file and r.startswith("+") and not r.startswith("+++"):
            riga += 1
            risultato[file].append((riga, r[1:]))
    return risultato


def radice(file):
    return file.split("src/")[0] if "src/" in file else file.split("legacy/")[0]


def gemelle(file, righe):
    """Funzioni aggiunte con lo stesso nome nell'altra metà del progetto."""
    if "/src/" not in file and "/legacy/" not in file:
        return
    altra = "legacy" if "/src/" in file else "src"
    base = radice(file)
    for numero, testo in righe:
        m = re.search(r"function\s+(\w+)", testo)
        if not m or m.group(1) in ("__construct", "calcola", "esporta"):
            continue
        trovate = esegui("git", "grep", "-n", "-E",
                         rf"function\s+{m.group(1)}\b", "--", f"{base}{altra}")
        for t in trovate.splitlines():
            print(f"  gemella: {file}:{numero} {m.group(1)}() -> {t}")


def main():
    dati = aggiunte()
    if not dati:
        print("Nessuna riga aggiunta rispetto a", BASE)
        return
    print("## Righe aggiunte (file:riga)")
    for file, righe in dati.items():
        if file.endswith(".lock") or "database/dati/" in file:
            print(f"{file}: file generato toccato (1.3)")
            continue
        print(f"\n{file}: {len(righe)} righe aggiunte")
        for numero, testo in righe:
            print(f"{numero:>5}| {testo}")
    print("\n## Candidati (da confermare leggendo il file)")
    for file, righe in dati.items():
        legacy = "/legacy/" in file
        for numero, testo in righe:
            for regola, espressione, nota in INDIZI:
                if legacy and regola != "2.3":
                    continue
                if re.search(espressione, testo):
                    print(f"{regola} {file}:{numero} {nota}")
    print("\n## Copie gemelle (stessa funzione nell'altra metà)")
    for file, righe in dati.items():
        gemelle(file, righe)
    print("\n## Test nella differenza")
    test = [f for f in dati if "/tests/" in f]
    print("\n".join(test) if test else "nessun file di test cambiato (10.2)")
    print("\n## Commit")
    print(esegui("git", "log", "--format=%h %s", f"{BASE}..HEAD"))


if __name__ == "__main__":
    main()
