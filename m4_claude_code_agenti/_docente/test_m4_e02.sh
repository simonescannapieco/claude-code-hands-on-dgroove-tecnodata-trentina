#!/bin/bash
#
# test_m4_e02.sh -- le prove di M4-E02 «Una funzione nuova, con i test», per
# il docente:
#   - esercizio/tools/php.sh uguale a tools/php.sh; le impostazioni dello
#     spazio di lavoro (allow del comando dei test, le deny del repository
#     più quelle su php.sh, SPECIFICA.md e .claude/agents/, defaultMode
#     default, plansDirectory); i due subagent (il revisore con tools: Read,
#     Grep, Glob e model: haiku, l'autore dei test senza Edit né Bash, tutti
#     e due con un formato di risposta);
#   - SPECIFICA.md: i requisiti numerati, ciascuno con un esempio, i casi di
#     accettazione; i loro numeri ricalcolati qui dai dati del gestionale
#     (SQLite in memoria, la regola «apparato del ticket, del padre o della
#     linea», il giorno locale di aperto_il);
#   - il README: le dieci sezioni, i sei prompt fra i segni, il comando dei
#     test e un comando per volta, i subagent con la @-mention, le frasi di
#     Anthropic e i loro link, nessun identificativo interno, niente macOS
#     né Percorso A, nessun riferimento all'orario; la prima frase del
#     README e di SPECIFICA.md nomina CiaspoLink, l'operatore inventato; il
#     passo 8 torna nella cartella esercitazioni con il suo percorso; la
#     ripresa «più lenta», non «costa»;
#   - verifica.sh con un tools/php.sh finto (PN_PHP_SH) e trascrizioni
#     finte (PN_CLAUDE_DIR): il punto di partenza (1, senza bisogno di PHP);
#     il lavoro completo (0, il giudice valido); i test senza il codice
#     (1); i test che passano anche sul codice di partenza (1); NOTA.md e i
#     commit come dati; le chiamate Agent contate (anche col vecchio nome
#     Task), «nessun subagent trovato» come dato e mai un'uscita 1; il
#     revisore riconosciuto dal meta.json, dal suo primo messaggio o
#     dall'agentId nel risultato; un revisore che modifica è una
#     segnalazione (1); un revisore che non si riconosce, o con la
#     definizione cambiata, non decide; meno trascrizioni del revisore che
#     chiamate, «non distinguibile» (0); le precondizioni (2), anche una
#     trascrizione che non si legge e un errore inatteso (una riga su
#     stderr);
#   - soluzione/applica.sh con il finto, e una copia che non riesce (2);
#     con PHP o Docker davvero (altrimenti SKIP): partenza 1, soluzione 0
#     con il giudice valido, PHP_CodeSniffer pulito sul codice di
#     riferimento, tools/run_all.sh;
#   - _docente/live.sh con un claude finto: le precondizioni escono 2 senza
#     chiamare claude, anche uno spazio di lavoro che ha già del lavoro
#     (git status non vuoto, o un commit dopo il primo); le due parti (il
#     piano in plan mode, poi --resume in dontAsk; la seconda parte in una
#     sessione nuova), i prompt del README, gli strumenti (nessun grep né
#     find), la chiave tolta, i JSON fuori dallo spazio di lavoro; il
#     lavoro finito nella seconda parte; mai finito (i seguiti, uscita 1);
#     una chiamata fallita; un revisore che modifica (1); il piano in
#     piani/;
#   - prepara_esercizio.sh e tools/verifica.sh con l'elemento vero;
#   - shellcheck -x sugli script dell'elemento e su questo.
# Gli spazi di lavoro nascono in una cartella temporanea, nella base di
# handson::init_temp_base; le trascrizioni finte in una cartella temporanea
# passata con PN_CLAUDE_DIR, mai in ~/.claude. Un numero di casi diverso da
# CASES esce 2.
#
# Uso:    m4_claude_code_agenti/_docente/test_m4_e02.sh
# Uscita: 0 = tutte le prove passano (uno SKIP è contato e stampato) ·
#         1 = almeno una fallita · 2 = precondizione (manca python3, jq,
#         git o shellcheck, un file dell'elemento; una preparazione non
#         riesce; le prove eseguite non sono quante attese)
set -uo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly MOD="${SELF%/_docente/*}"
readonly RADICE="${MOD%/*}"
readonly E02="${MOD}/s3_agente_nel_repository/m4_e2_laboratorio/\
M4-E02_funzione_con_test"
readonly PHP_FINTO="${MOD}/_docente/php_finto_m4_e01_e02.py"
readonly CLAUDE_FINTO="${MOD}/_docente/claude_finto_m4_e01_e02.py"
# shellcheck source=../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"
readonly CASES=99
readonly PROGETTO=progetti/gestionale-php
readonly COMANDO="tools/php.sh php progetti/gestionale-php/vendor/bin/phpunit \
-c progetti/gestionale-php"
readonly REGOLA="Bash(tools/php.sh php progetti/gestionale-php/vendor/bin/\
phpunit *)"
# Gli identificativi interni che i file per i partecipanti non portano.
INTERNI='FACT-|Tecnodata|[Tt]riage|Envelope|M[0-9]-X[0-9]|\bX-[0-9]'
INTERNI+='|\b(ASK|OQ|DEC|TD|PQ)-[0-9]|\bB#[0-9]'
readonly INTERNI
TMP=''
MODELLO=''
PHP_OK=0
PASS=0
FAIL=0
SKIP=0
RC=0
OUT=''

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }
skip() { echo "  SKIP: $1"; SKIP=$((SKIP + 1)); }

# Esegue un comando; RC e OUT (STDOUT e STDERR insieme) per expect.
run() { OUT="$("$@" 2>&1)"; RC=$?; }

# Uscita attesa E parola chiave attesa (RU-01.T3).
# Arguments: $1 il nome, $2 l'uscita attesa, $3 la parola (grep -F).
expect() {
  if (( RC == $2 )) && grep -qF -- "$3" <<< "${OUT}"; then
    pass "$1"
  else
    fail "$1 (rc=${RC}, attesa $2, parola «$3»): ${OUT:0:900}"
  fi
}

# Nessun falso positivo: la parola NON c'è (RU-01.T5).
# Arguments: $1 il nome, $2 la parola.
expect_absent() {
  if grep -qF -- "$2" <<< "${OUT}"; then
    fail "$1: «$2» c'è: ${OUT:0:900}"
  else
    pass "$1"
  fi
}

# La preparazione di una prova che non riesce: uscita 2.
rotta() { echo "test_m4_e02: preparazione non riuscita: $*" >&2; exit 2; }

# Un nuovo spazio di lavoro, copia del modello di prepara_esercizio.sh.
# Arguments: $1 la variabile, $2 «vendor» per vendor/bin/phpunit.
ws() {
  local __w
  __w="$(mktemp -d "${TMP}/ws.XXXXXX")" || rotta "mktemp"
  cp -a "${MODELLO}/." "${__w}/" || rotta "cp del modello"
  if [[ "${2:-}" == "vendor" ]]; then
    mkdir -p "${__w}/${PROGETTO}/vendor/bin" || rotta "vendor"
    : > "${__w}/${PROGETTO}/vendor/bin/phpunit" || rotta "vendor"
  fi
  printf -v "$1" '%s' "${__w}"
}

# La verifica dell'elemento con il php.sh finto e le trascrizioni finte.
# Arguments: $1 lo spazio di lavoro, poi variabili d'ambiente.
verifica() {
  local w="$1"
  shift
  run env PN_PHP_SH="${PHP_FINTO}" PN_CLAUDE_DIR="${TMP}/claude" "$@" \
    "${E02}/verifica.sh" "${w}"
}

# Il lavoro di prova nello spazio di lavoro, con fx.py.
# Arguments: $1 lo spazio, poi le varianti (vedi fx.py).
fx() { python3 -B -I "${TMP}/fx.py" "${E02}" "$@" || rotta "fx $*"; }

# Le trascrizioni finte di uno spazio di lavoro, con tr.py.
# Arguments: $1 lo spazio, $2 la variante (vedi tr.py).
tr_finte() {
  python3 -B -I "${TMP}/tr.py" "${TMP}/claude" "$1" "$2" || rotta "tr $2"
}

# fx.py: il lavoro di prova (test finti e codice di riferimento).
scrivi_fx() {
  cat > "${TMP}/fx.py" <<'PY' || rotta "fx.py"
"""fx.py -- il lavoro di prova di test_m4_e02.sh nello spazio di lavoro:
test finti (giudicati dal php.sh finto con i segni FINTO) e il codice di
riferimento di soluzione/. Non è il lavoro di Claude."""
import os
import shutil
import sys

ELEMENTO, ws = sys.argv[1], sys.argv[2]
P = os.path.join(ws, "progetti/gestionale-php")
TEST = '''<?php

declare(strict_types=1);

namespace CiaspoLink\\Gestionale\\Tests\\Integrazione;

use PHPUnit\\Framework\\TestCase;

final class FiltroApparatoTest extends TestCase
{
    public function testFiltraPerApparato(): void
    {
        // Test finto. %s
        self::assertTrue(true);
    }
}
'''
for variante in sys.argv[3:]:
    if variante == "test":
        cartella = os.path.join(P, "tests/Integrazione")
        with open(os.path.join(cartella, "FiltroApparatoTest.php"), "w",
                  encoding="utf-8") as fh:
            fh.write(TEST % "FINTO-RICHIEDE: ?DateTimeImmutable $dal")
    elif variante == "test_debole":
        with open(os.path.join(P, "tests/Integrazione/FiltroApparatoTest.php"),
                  "w", encoding="utf-8") as fh:
            fh.write(TEST % "nessun segno: passa anche senza la funzione")
    elif variante == "codice":
        for parte in ("src/Ticket/FiltroTicket.php",
                      "src/Ticket/TicketRepository.php"):
            shutil.copyfile(os.path.join(ELEMENTO, "soluzione",
                                         "progetti/gestionale-php", parte),
                            os.path.join(P, parte))
    elif variante == "nota":
        with open(os.path.join(ws, "NOTA.md"), "w", encoding="utf-8") as fh:
            fh.write("# Nota di prova\n\nFatto: R1.\nManca: R6.\n")
    elif variante == "revisore_modificabile":
        percorso = os.path.join(ws, ".claude/agents/revisore.md")
        with open(percorso, encoding="utf-8") as fh:
            t = fh.read()
        with open(percorso, "w", encoding="utf-8") as fh:
            fh.write(t.replace("tools: Read, Grep, Glob",
                               "tools: Read, Grep, Glob, Edit", 1))
    else:
        sys.exit(2)
PY
}

# tr.py: le trascrizioni finte di Claude Code di uno spazio di lavoro.
scrivi_tr() {
  cat > "${TMP}/tr.py" <<'PY' || rotta "tr.py"
"""tr.py -- trascrizioni finte di Claude Code per le prove di verifica.py
di M4-E02, nella forma che legge: <base>/projects/<nome>/<sessione>.jsonl
e <sessione>/subagents/agent-<id>.jsonl con il suo meta.json. Il nome è il
percorso dello spazio di lavoro con ogni carattere che non è lettera o
cifra cambiato in «-». Nessuna riga è di Claude."""
import json
import os
import re
import sys

base, ws, variante = sys.argv[1:4]
nome = re.sub(r"[^A-Za-z0-9]", "-", os.path.realpath(ws))
cartella = os.path.join(base, "projects", nome)
SESSIONE = "sessione-di-prova"
os.makedirs(os.path.join(cartella, SESSIONE, "subagents"), exist_ok=True)
principale = os.path.join(cartella, SESSIONE + ".jsonl")


def riga(file, oggetto):
    with open(file, "a", encoding="utf-8") as fh:
        fh.write(json.dumps(oggetto) + "\n")


def agent(n, tipo, prompt, strumenti, meta=True, primo=None, rid=True,
          nome_tool="Agent", trascrizione=True):
    ident = "a%016x" % n
    riga(principale, {"type": "assistant", "message": {
        "role": "assistant", "content": [{
            "type": "tool_use", "id": "toolu_%d" % n, "name": nome_tool,
            "input": {"subagent_type": tipo, "prompt": prompt}}]}})
    testo = "Fatto." + (" agentId: %s (per riprenderlo)" % ident if rid
                        else "")
    riga(principale, {"type": "user", "message": {"role": "user", "content": [
        {"type": "tool_result", "tool_use_id": "toolu_%d" % n,
         "content": [{"type": "text", "text": testo}]}]}})
    if not trascrizione:
        return
    sub = os.path.join(cartella, SESSIONE, "subagents", "agent-%s" % ident)
    riga(sub + ".jsonl", {"type": "user", "isSidechain": True,
                          "message": {"role": "user",
                                      "content": primo or prompt}})
    for k, s in enumerate(strumenti):
        riga(sub + ".jsonl", {"type": "assistant", "isSidechain": True,
                              "message": {"role": "assistant", "content": [{
                                  "type": "tool_use", "id": "s%d_%d" % (n, k),
                                  "name": s, "input": {}}]}})
    if meta:
        with open(sub + ".meta.json", "w", encoding="utf-8") as fh:
            json.dump({"agentType": tipo}, fh)


riga(principale, {"type": "user", "message": {"role": "user",
                                               "content": "prompt di prova"}})
REV = "Confronta questo diff con SPECIFICA.md: (diff di prova)"
if variante == "nessuno":
    pass
elif variante == "task":
    agent(1, "general-purpose", "Scrivi i test", ["Read"], nome_tool="Task")
else:
    agent(1, "autore-test", "Scrivi i test di SPECIFICA.md", ["Read", "Write"])
    if variante == "pulito":
        agent(2, "revisore", REV, ["Read", "Grep"])
    elif variante == "modifica":
        agent(2, "revisore", REV, ["Read", "Edit"])
    elif variante == "solo_prompt":
        agent(2, "revisore", REV, ["Read"], meta=False, rid=False)
    elif variante == "solo_id":
        agent(2, "revisore", REV, ["Read"], meta=False, primo="altro")
    elif variante == "irriconoscibile":
        agent(2, "revisore", REV, ["Read", "Edit"], meta=False,
              primo="altro", rid=False)
    elif variante == "due_una":
        agent(2, "revisore", REV, ["Read", "Grep"])
        agent(3, "revisore", REV, ["Read"], trascrizione=False)
    elif variante != "solo_autore":
        sys.exit(2)
PY
}

# fx.py, tr.py, il claude finto, il claude esca e il modello.
prepara() {
  local radice
  scrivi_fx
  scrivi_tr
  mkdir -p "${TMP}/finto" "${TMP}/esca" "${TMP}/claude" || rotta "mkdir"
  cp "${CLAUDE_FINTO}" "${TMP}/finto/claude" || rotta "il claude finto"
  # shellcheck disable=SC2016  # il corpo è dell'esca
  printf '%s\n' '#!/bin/bash' 'echo "chiamata $*" >> "${ESCA_LOG}"' \
    'exit 1' > "${TMP}/esca/claude" || rotta "il claude esca"
  chmod 755 "${TMP}/finto/claude" "${TMP}/esca/claude" || rotta "chmod"
  radice="$(mktemp -d "${TMP}/radice.XXXXXX")" || rotta "mktemp"
  "${RADICE}/tools/prepara_esercizio.sh" M4-E02 --radice "${radice}" \
    > /dev/null 2>&1 || rotta "prepara_esercizio.sh M4-E02"
  MODELLO="${radice}/M4-E02"
  if command -v php > /dev/null 2>&1 \
      || { command -v docker > /dev/null 2>&1 \
        && docker info > /dev/null 2>&1; }; then
    PHP_OK=1
  fi
}

# La copia di php.sh, le impostazioni, i subagent.
t_copie() {
  if cmp -s "${E02}/esercizio/tools/php.sh" "${RADICE}/tools/php.sh" \
      && [[ -x "${E02}/esercizio/tools/php.sh" ]]; then
    pass "esercizio/tools/php.sh è tools/php.sh, eseguibile"
  else
    fail "esercizio/tools/php.sh diverso da tools/php.sh o non eseguibile"
  fi
  run python3 -B -I - "${E02}/esercizio/.claude/settings.json" \
    "${RADICE}/.claude/settings.json" "${REGOLA}" <<'PY'
import json
import sys

t = json.load(open(sys.argv[1], encoding="utf-8"))
e = t["permissions"]
r = json.load(open(sys.argv[2], encoding="utf-8"))["permissions"]
print("allow %s" % ("ok" if e.get("allow") == [sys.argv[3]] else "diverso"))
print("deny %s" % ("ok" if e.get("deny") == r["deny"] + [
    "Edit(/tools/php.sh)", "Edit(/SPECIFICA.md)",
    "Edit(/.claude/agents/**)"] else "diverso"))
print("modo %s" % ("ok" if e.get("defaultMode") == "default" else "diverso"))
print("piani %s" % ("ok" if t.get("plansDirectory") == "./piani"
                    else "diverso"))
PY
  expect "settings: allow, solo il comando dei test" 0 "allow ok"
  expect "settings: deny su php.sh, SPECIFICA.md e i subagent" 0 "deny ok"
  expect "settings: defaultMode default (Manual)" 0 "modo ok"
  expect "settings: i piani nello spazio di lavoro" 0 "piani ok"
  run python3 -B -I - "${E02}/esercizio/.claude/settings.json" \
    "${E02}/README.md" <<'PY'
import json
import re
import sys

impostazioni, readme = sys.argv[1:3]
with open(impostazioni, encoding="utf-8") as fh:
    deny = json.load(fh)["permissions"]["deny"]
with open(readme, encoding="utf-8") as fh:
    testo = fh.read()
piatto = " ".join(testo.split())
problemi = []
for regola in deny:
    if not re.match(r"(?:Read|Edit)\((?:\*\*/|/[^/])", regola):
        problemi.append("non ancorata: %s" % regola)
    elif regola.startswith("Edit(/") and regola not in testo:
        problemi.append("il README non la cita: %s" % regola)
frasi = ("`path` or `./path` | Path relative to current directory | "
         "`Read(*.env)` | `<cwd>/*.env`",
         "`/path` | Path relative to the settings source | "
         "`Edit(/src/**/*.ts)` | `<primary working directory>/src/**/*.ts` "
         "in project settings")
for frase in frasi:
    if frase not in piatto:
        problemi.append("manca «%s…»" % frase[:24])
if "https://code.claude.com/docs/en/permissions" not in testo:
    problemi.append("manca https://code.claude.com/docs/en/permissions")
print("; ".join(problemi) or "regole ancorate e citate")
PY
  expect "settings e README: le regole deny ancorate, citate, e perché" 0 \
    "regole ancorate e citate"
  run python3 -B -I - "${E02}/esercizio/.claude/agents" <<'PY'
import os
import re
import sys


def testa(nome):
    t = open(os.path.join(sys.argv[1], nome), encoding="utf-8").read()
    m = re.match(r"---\n(.*?)\n---\n(.*)", t, re.S)
    campi = dict(r.split(":", 1) for r in m.group(1).splitlines() if ":" in r)
    return {k.strip(): v.strip() for k, v in campi.items()}, m.group(2)


c, corpo = testa("revisore.md")
if (c.get("name") == "revisore" and c.get("tools") == "Read, Grep, Glob"
        and c.get("model") == "haiku" and c.get("description")
        and "ESITO:" in corpo and "REQUISITI:" in corpo):
    print("revisore ok")
c, corpo = testa("autore-test.md")
strumenti = {s.strip() for s in c.get("tools", "").split(",")}
if (c.get("name") == "autore-test" and "Write" in strumenti
        and not strumenti & {"Edit", "Bash"} and c.get("description")
        and "FILE:" in corpo and "SPECIFICA.md" in corpo):
    print("autore ok")
PY
  expect "il revisore: tools Read, Grep, Glob, haiku, un formato" 0 \
    "revisore ok"
  expect "l'autore dei test: Write senza Edit né Bash, un formato" 0 \
    "autore ok"
}

# SPECIFICA.md: requisiti, esempi, casi di accettazione veri sui dati.
t_specifica() {
  run python3 -B -I - "${E02}/esercizio/SPECIFICA.md" \
    "${RADICE}/${PROGETTO}/database" <<'PY'
import glob
import re
import sqlite3
import sys

testo = open(sys.argv[1], encoding="utf-8").read()
req = re.findall(r"^R(\d)\.", testo, re.M)
blocchi = re.split(r"^R\d\.", testo, flags=re.M)[1:]
if req == [str(i) for i in range(1, 8)] and all(
        "Esempio" in b for b in blocchi[:6]):
    print("requisiti ok")
db = sqlite3.connect(":memory:")
db.executescript(open(sys.argv[2] + "/schema.sql", encoding="utf-8").read())
for f in sorted(glob.glob(sys.argv[2] + "/dati/*.sql")):
    db.executescript(open(f, encoding="utf-8").read())
SQL = ("SELECT t.id FROM ticket t LEFT JOIN ticket p ON p.id = t.padre_id "
       "LEFT JOIN linee l ON l.id = t.linea_id WHERE 1=1")


def conta(apparato=None, dal=None, al=None, categoria=None):
    sql, par = SQL, []
    if apparato:
        sql += " AND ? IN (t.apparato_id, p.apparato_id, l.apparato_id)"
        par.append(apparato)
    if dal:
        sql += " AND substr(t.aperto_il, 1, 10) >= ?"
        par.append(dal)
    if al:
        sql += " AND substr(t.aperto_il, 1, 10) <= ?"
        par.append(al)
    if categoria:
        sql += " AND t.categoria = ?"
        par.append(categoria)
    return len(db.execute(sql, par).fetchall())


S = ("2026-09-07", "2026-09-13")
casi = [conta("olt-pergine-01", "2026-09-08", "2026-09-08"),
        conta("olt-pergine-01", *S), conta("ptp-cles-01", *S),
        conta("bts-cles-01", *S), conta("bng-trento-01"),
        conta(None, "2026-09-08", "2026-09-08"),
        conta("olt-pergine-01", *S, categoria="disservizio"),
        conta("olt-inesistente-01"), conta(None, "2026-09-12")]
print("dati %s" % casi)
righe = {int(m.group(1)): m.group(2) for m in re.finditer(
    r"^\| (\d+) \|[^|]*\| ([^|]*)\|", testo, re.M)}
attesi = {1: "9", 2: "14", 3: "5", 4: "8", 5: "3", 6: "11", 7: "1",
          8: "nessuno"}
if all(righe.get(k, "").strip().startswith(v) for k, v in attesi.items()) \
        and "InvalidArgumentException" in righe.get(9, ""):
    print("tabella ok")
PY
  expect "SPECIFICA.md: R1…R7, ciascuno con un esempio" 0 "requisiti ok"
  expect "SPECIFICA.md: i numeri dei casi sono quelli dei dati" 0 \
    "dati [9, 14, 5, 8, 3, 11, 1, 0, 10]"
  expect "SPECIFICA.md: la tabella dei casi di accettazione" 0 "tabella ok"
}

# Il README: i prompt (in ${TMP}/prompt-<n>.txt), le sezioni, le frasi.
t_readme() {
  local f trovati=''
  run python3 -B -I - "${E02}/README.md" "${TMP}" "${COMANDO}" <<'PY'
import os
import sys
import textwrap

testo = open(sys.argv[1], encoding="utf-8").read()
righe = testo.split("\n")
for n in range(1, 7):
    a = [i for i, r in enumerate(righe)
         if r.strip() == "<!-- prompt %d -->" % n]
    b = [i for i, r in enumerate(righe)
         if r.strip() == "<!-- /prompt %d -->" % n]
    if len(a) == 1 and len(b) == 1 and a[0] < b[0]:
        p = textwrap.dedent("\n".join(righe[a[0] + 1:b[0]])).strip("\n")
        if p.strip():
            open(os.path.join(sys.argv[2], "prompt-%d.txt" % n), "w",
                 encoding="utf-8").write(p)
            print("prompt %d ok" % n)


def uno(n):
    return " ".join(open(os.path.join(sys.argv[2], "prompt-%d.txt" % n),
                         encoding="utf-8").read().split())


if all(sys.argv[3] in uno(n) for n in (1, 2, 5, 6)) and all(
        "da solo" in uno(n) for n in (1, 2, 5, 6)):
    print("comando ok")
if "Prepara un piano" in uno(1) and "@agent" not in uno(1):
    print("piano ok")
if "@agent-autore-test" in uno(2) and all(
        "@agent-revisore" in uno(n) for n in (3, 5, 6)):
    print("subagent ok")
if "Scrivi NOTA.md" in uno(4) and "Leggi NOTA.md" in uno(5):
    print("nota ok")
piatto = " ".join(testo.split())
frasi = ["Running independent pieces of work at the same time",
         "Getting a reviewer that hasn't seen how the code was written",
         "You get parallelism or a fresh pair of eyes out of it, but not a "
         "smarter answer.",
         "Now it's a reviewer that can't edit anything",
         "Run it against the original code to confirm it passes. Then run it "
         "against deliberately broken code to confirm it fails",
         "https://code.claude.com/docs/en/best-practices",
         "https://claude.com/resources/articles/ai-code-migration"]
if all(f in piatto for f in frasi):
    print("frasi ok")
if "--permission-mode plan" in testo and "seconda parte del laboratorio" \
        in testo:
    print("parti ok")
sezioni = ("Obiettivo", "Tempo", "Prerequisiti", "Punto di partenza",
           "Passi in Claude Code", "Che cosa osservare", "Verifica",
           "Se qualcosa va storto", "Impronta d'uso sul piano Pro",
           "Per approfondire")
if all(any(r.startswith("## " + s) for r in righe) for s in sezioni):
    print("sezioni ok")
PY
  expect "README: le dieci sezioni" 0 "sezioni ok"
  for f in 1 2 3 4 5 6; do
    expect "README: il prompt ${f} fra i segni" 0 "prompt ${f} ok"
  done
  expect "README: il comando dei test, da solo, nei prompt che lo usano" 0 \
    "comando ok"
  expect "README: il piano senza @-mention" 0 "piano ok"
  expect "README: i subagent con la @-mention" 0 "subagent ok"
  expect "README: la nota e la ripresa" 0 "nota ok"
  expect "README: le frasi di Anthropic e i link" 0 "frasi ok"
  expect "README: plan mode e la seconda parte del laboratorio" 0 "parti ok"
  OUT="$(cat "${E02}/README.md" "${E02}/esercizio/SPECIFICA.md")"
  expect_absent "README: gli ambienti del corso, non macOS" "macOS"
  expect_absent "README: nessun Percorso A" "Percorso A"
  if grep -qiE '\boggi\b|prossima sessione|pausa|pranzo' \
      "${E02}/README.md" "${E02}/esercizio/SPECIFICA.md"; then
    fail "README e SPECIFICA: un riferimento all'orario"
  else
    pass "README e SPECIFICA: nessun riferimento all'orario"
  fi
  for f in README.md verifica.sh verifica.py esercizio/SPECIFICA.md \
      esercizio/.claude/settings.json esercizio/.claude/agents/revisore.md \
      esercizio/.claude/agents/autore-test.md; do
    if grep -qE -- "${INTERNI}" "${E02}/${f}"; then
      trovati+=" ${f}"
    fi
  done
  if [[ -z "${trovati}" ]]; then
    pass "nessun identificativo interno nei file per i partecipanti"
  else
    fail "identificativi interni in:${trovati}"
  fi
  t_readme_lab "${E02}" M4-E02
}

# Il README e SPECIFICA.md di una traccia del laboratorio: la prima frase
# nomina CiaspoLink, l'operatore inventato del corso; il passo 8 torna in
# esercitazioni con il suo percorso, non con «cd -»; riprendere una
# conversazione lunga «è più lento», non «costa».
# Arguments: $1 la cartella dell'elemento, $2 il suo identificativo.
t_readme_lab() {
  run python3 -B -I - "$1/README.md" "$1/esercizio/SPECIFICA.md" "$2" \
    <<'PY'
import sys

readme, specifica, ident = sys.argv[1:4]


def prima_frase(percorso):
    testo = open(percorso, encoding="utf-8").read()
    corpo = [b for b in testo.split("\n\n")
             if b.strip() and not b.lstrip().startswith("#")]
    return " ".join(corpo[0].split()).split(". ")[0] if corpo else ""


frasi = [prima_frase(p) for p in (readme, specifica)]
print("ciaspolink ok" if all("CiaspoLink" in f and "inventato" in f
                             for f in frasi) else "ciaspolink: %s" % frasi)
testo = open(readme, encoding="utf-8").read()
passo = testo.split("\n8. ", 1)[-1].split("\n## ", 1)[0]
blocco = [r.strip() for r in passo.splitlines() if r.startswith("       ")]
print("ritorno ok" if blocco == ["cd ~/esercitazioni",
                                 "tools/verifica.sh %s" % ident]
      else "ritorno: %s" % blocco)
piatto = " ".join(testo.split())
print("ripresa ok" if "è più lento" in piatto and "invece, costa" not in
      piatto else "ripresa: «costa», o niente «è più lento»")
PY
  expect "README e SPECIFICA: la prima frase nomina CiaspoLink" 0 \
    "ciaspolink ok"
  expect "README: il passo 8 torna in esercitazioni, non con cd -" 0 \
    "ritorno ok"
  expect "README: riprendere una conversazione lunga è più lento" 0 \
    "ripresa ok"
}

# verifica.sh: il lavoro, il giudice, i dati.
t_verifica() {
  local w
  ws w
  verifica "${w}"
  expect "partenza: esce 1" 1 "nessun test nuovo o cambiato"
  verifica "${w}" PN_PHP_SH="${TMP}/non-esiste"
  expect "partenza: senza PHP esce comunque 1, non 2" 1 "Non ancora:"
  expect "partenza: nessun subagent, un dato" 1 "nessun subagent trovato"
  ws w vendor
  fx "${w}" test codice
  verifica "${w}"
  expect "test e codice: 0" 0 "Fatto:"
  expect "test e codice: il giudice è valido" 0 "il giudice è valido"
  expect "test e codice: la suite passa" 0 \
    "la suite intera, sul vostro codice: passa"
  expect "NOTA.md assente: un dato" 0 "(dato) NOTA.md: non c'è"
  expect_absent "test e codice: nessuna segnalazione sul revisore" \
    "non ha tenuto"
  ws w vendor
  fx "${w}" test
  verifica "${w}"
  expect "solo i test: la suite non passa (1)" 1 "la suite non passa"
  expect "solo i test: i test nuovi non passano (1)" 1 \
    "i test nuovi non passano sul vostro codice"
  ws w vendor
  fx "${w}" test_debole codice
  verifica "${w}"
  expect "test che passano anche senza la funzione: 1" 1 \
    "passano anche sul codice di partenza"
  ws w vendor
  fx "${w}" test codice nota
  git -C "${w}" add -A > /dev/null 2>&1 || rotta "git add"
  git -C "${w}" -c user.name=Prova -c user.email=prova@example.org \
    commit -qm "feat(ticket): filtro (prova)" || rotta "git commit"
  verifica "${w}"
  expect "nel commit: 0" 0 "Fatto:"
  expect "NOTA.md: un dato" 0 "(dato) NOTA.md: c'è"
  expect "i commit dopo il punto di partenza: un dato" 0 \
    "(dato) commit dopo il punto di partenza: 1"
}

# verifica.sh: le trascrizioni, le chiamate Agent e il revisore.
t_trascrizioni() {
  local w nome
  ws w vendor
  fx "${w}" test codice
  tr_finte "${w}" pulito
  verifica "${w}"
  expect "Agent: due chiamate contate" 0 "(dato) chiamate al tool Agent: 2"
  expect "Agent: per tipo" 0 "autore-test 1, revisore 1"
  expect "il revisore pulito: la garanzia vale" 0 "la garanzia vale"
  nome="$(realpath "${w}")"
  nome="${nome//[^A-Za-z0-9]/-}"
  expect "la cartella delle sessioni dal percorso dello spazio" 0 "${nome}"
  ws w vendor
  fx "${w}" test codice
  tr_finte "${w}" modifica
  verifica "${w}"
  expect "il revisore che modifica: una segnalazione, 1" 1 "non ha tenuto"
  ws w vendor
  fx "${w}" test codice
  tr_finte "${w}" solo_prompt
  verifica "${w}"
  expect "revisore riconosciuto dal primo messaggio" 0 "la garanzia vale"
  ws w vendor
  fx "${w}" test codice
  tr_finte "${w}" solo_id
  verifica "${w}"
  expect "revisore riconosciuto dall'agentId nel risultato" 0 \
    "la garanzia vale"
  ws w vendor
  fx "${w}" test codice
  tr_finte "${w}" irriconoscibile
  verifica "${w}"
  expect "revisore che non si riconosce: nessun esito, 0" 0 \
    "non si riconosce"
  ws w vendor
  fx "${w}" test codice revisore_modificabile
  tr_finte "${w}" modifica
  verifica "${w}"
  expect "definizione cambiata: la garanzia non si applica, 0" 0 \
    "la garanzia non si applica"
  ws w vendor
  fx "${w}" test codice
  tr_finte "${w}" task
  verifica "${w}"
  expect "il vecchio nome Task conta come Agent" 0 \
    "(dato) chiamate al tool Agent: 1"
  ws w vendor
  fx "${w}" test codice
  tr_finte "${w}" nessuno
  verifica "${w}"
  expect "sessioni senza Agent: nessun subagent, un dato, 0" 0 \
    "nessun subagent trovato"
  ws w vendor
  fx "${w}" test codice
  tr_finte "${w}" solo_autore
  verifica "${w}"
  expect "revisore mai chiamato: nessun esito, 0" 0 \
    "il revisore non è stato chiamato"
  ws w vendor
  fx "${w}" test codice
  tr_finte "${w}" due_una
  verifica "${w}"
  expect "due chiamate al revisore, una trascrizione: non distinguibile" 0 \
    "non distinguibile"
  expect_absent "due chiamate, una trascrizione: mai «la garanzia vale»" \
    "la garanzia vale"
}

# Le precondizioni di verifica.sh: uscita 2.
t_verifica_precondizioni() {
  local w err rc=0 nome sub
  verifica "${TMP}/non-esiste"
  expect "spazio di lavoro assente: 2" 2 "spazio di lavoro assente"
  w="$(mktemp -d "${TMP}/nogit.XXXXXX")" || rotta "mktemp"
  verifica "${w}"
  expect "una cartella che non è uno spazio di lavoro: 2" 2 \
    "non è uno spazio di lavoro preparato"
  ws w
  rm -rf "${w:?}/${PROGETTO}" || rotta "rm"
  verifica "${w}"
  expect "senza il gestionale: 2" 2 "manca progetti/gestionale-php"
  ws w vendor
  fx "${w}" test codice
  verifica "${w}" PN_PHP_SH="${TMP}/non-esiste"
  expect "test e nessuno strumento PHP: 2" 2 "manca lo strumento per PHP"
  ws w
  fx "${w}" test codice
  verifica "${w}"
  expect "test e niente vendor/: 2 con il rimedio" 2 \
    "tools/php.sh composer install -d progetti/gestionale-php"
  ws w vendor
  fx "${w}" test codice
  verifica "${w}" FINTO_PHP_ASSENTE=1
  expect "PHP che non si avvia: 2" 2 "PHP non si avvia"
  ws w vendor
  fx "${w}" test codice
  tr_finte "${w}" pulito
  nome="$(realpath "${w}")"
  sub="${TMP}/claude/projects/${nome//[^A-Za-z0-9]/-}/sessione-di-prova"
  chmod 000 "${sub}"/subagents/agent-*.jsonl || rotta "chmod"
  if [[ -r "${sub}/subagents/agent-a0000000000000002.jsonl" ]]; then
    skip "una trascrizione che non si legge: 2 (da root si legge)"
  else
    verifica "${w}"
    expect "una trascrizione che non si legge: 2, mai «nessuno strumento»" \
      2 "non si legge"
  fi
  chmod 644 "${sub}"/subagents/agent-*.jsonl || rotta "chmod"
  ws w vendor
  fx "${w}" test codice nota
  chmod 000 "${w}/NOTA.md" || rotta "chmod"
  if [[ -r "${w}/NOTA.md" ]]; then
    skip "un errore inatteso: 2 (un file 000 resta leggibile, da root)"
  else
    err="$(env PN_PHP_SH="${PHP_FINTO}" PN_CLAUDE_DIR="${TMP}/claude" \
      "${E02}/verifica.sh" "${w}" 2>&1 > /dev/null)" || rc=$?
    if (( rc == 2 )) && grep -qF "errore inatteso" <<< "${err}" \
        && (( $(wc -l <<< "${err}") == 1 )); then
      pass "un errore inatteso: 2, una riga su stderr"
    else
      fail "un errore inatteso (rc=${rc}): ${err:0:600}"
    fi
  fi
  chmod 644 "${w}/NOTA.md" || rotta "chmod"
}

# soluzione/applica.sh con il finto.
t_soluzione() {
  local w
  ws w
  run env PN_PHP_SH="${PHP_FINTO}" "${E02}/soluzione/applica.sh" "${w}"
  expect "applica.sh con il finto: 0" 0 "Generating autoload files"
  # shellcheck disable=SC2016  # $apparatoId è il nome PHP, letterale
  if grep -qF '$apparatoId' "${w}/${PROGETTO}/src/Ticket/FiltroTicket.php" \
      && [[ -f "${w}/${PROGETTO}/tests/Unit/Ticket/FiltroTicketTest.php" \
        && -f "${w}/NOTA.md" ]]; then
    pass "applica.sh: il codice, i test e la nota di riferimento"
  else
    fail "applica.sh non ha copiato la soluzione"
  fi
  run "${E02}/soluzione/applica.sh" "${TMP}/non-esiste"
  expect "applica.sh senza spazio di lavoro: 2" 2 "spazio di lavoro assente"
  ws w vendor
  rm -f "${w}/${PROGETTO}/src/Ticket/FiltroTicket.php" || rotta "rm"
  mkdir "${w}/${PROGETTO}/src/Ticket/FiltroTicket.php" || rotta "mkdir"
  run env PN_PHP_SH="${PHP_FINTO}" "${E02}/soluzione/applica.sh" "${w}"
  expect "applica.sh: una copia che non riesce esce 2, mai 1" 2 \
    "la copia della soluzione non riesce"
}

# Con PHP o Docker davvero: partenza, soluzione, phpcs, run_all.
t_reale() {
  local radice w
  if (( PHP_OK == 0 )); then
    skip "PHP reale: partenza (né PHP né Docker)"
    skip "PHP reale: soluzione (né PHP né Docker)"
    skip "PHP reale: il giudice (né PHP né Docker)"
    skip "PHP reale: phpcs (né PHP né Docker)"
    skip "PHP reale: run_all (né PHP né Docker)"
    return 0
  fi
  radice="$(mktemp -d "${TMP}/reale.XXXXXX")" || rotta "mktemp"
  "${RADICE}/tools/prepara_esercizio.sh" M4-E02 --radice "${radice}" \
    > /dev/null 2>&1 || rotta "prepara_esercizio.sh"
  w="${radice}/M4-E02"
  run env PN_HANDSON_ROOT="${RADICE}" PN_CLAUDE_DIR="${TMP}/claude" \
    "${E02}/verifica.sh" "${w}"
  expect "PHP reale: partenza 1" 1 "Non ancora:"
  ( cd "${w}" && PN_HANDSON_ROOT="${RADICE}" \
      "${E02}/soluzione/applica.sh" "${w}" ) > /dev/null 2>&1 \
    || rotta "applica.sh con PHP reale"
  run env PN_HANDSON_ROOT="${RADICE}" PN_CLAUDE_DIR="${TMP}/claude" \
    "${E02}/verifica.sh" "${w}"
  expect "PHP reale: soluzione 0" 0 "Fatto:"
  expect "PHP reale: i test nuovi falliscono sul codice di partenza" 0 \
    "il giudice è valido"
  # templates/ resta fuori, come in phpcs.xml.dist del gestionale.
  run bash -c 'cd "$1" && ../../tools/php.sh php vendor/bin/phpcs \
    --no-colors src/Ticket tests/Unit/Ticket tests/Integrazione' _ \
    "${w}/${PROGETTO}"
  if (( RC == 0 )); then
    pass "PHP reale: PHP_CodeSniffer pulito sulla soluzione"
  else
    fail "PHP reale: phpcs sulla soluzione: ${OUT:0:600}"
  fi
  run "${RADICE}/tools/run_all.sh" M4-E02
  expect "PHP reale: tools/run_all.sh M4-E02" 0 "ESITO: OK"
}

# live.sh con il claude finto in testa al PATH.
# Arguments: $1 lo spazio di lavoro, poi variabili d'ambiente.
live_finto() {
  local w="$1"
  shift
  : > "${TMP}/finto.log"
  run env "$@" PATH="${TMP}/finto:${PATH}" HANDSON_NO_PAUSE=1 \
    FINTO_LOG="${TMP}/finto.log" PN_PHP_SH="${PHP_FINTO}" \
    PN_CLAUDE_DIR="${TMP}/claude" FINTO_SOLUZIONE="${E02}/soluzione" \
    "${E02}/_docente/live.sh" "${w}"
}

# Le chiamate del claude finto. Arguments: $1 il nome, $2 quante.
expect_chiamate() {
  local n=0
  n="$(wc -l < "${TMP}/finto.log")"
  if (( n == $2 )); then pass "$1"; else fail "$1: ${n} chiamate, attese $2"; fi
}

# Le precondizioni di live.sh: escono 2 senza chiamare claude.
# Arguments: $1 il nome, $2 la parola, $3 lo spazio di lavoro.
senza_chiamate() {
  : > "${TMP}/esca.log"
  run env PATH="${TMP}/esca:${PATH}" ESCA_LOG="${TMP}/esca.log" \
    HANDSON_NO_PAUSE=1 "${E02}/_docente/live.sh" "$3"
  if (( RC == 2 )) && grep -qF -- "$2" <<< "${OUT}" \
      && [[ ! -s "${TMP}/esca.log" ]]; then
    pass "$1"
  else
    fail "$1 (rc=${RC}): ${OUT:0:400}"
  fi
}

# Le opzioni delle chiamate di live.sh, dal registro del finto.
controlla_opzioni() {
  run python3 -B -I - "${TMP}/finto.log" "${REGOLA}" "${TMP}" <<'PY'
import json
import os
import sys

righe = [json.loads(r) for r in open(sys.argv[1], encoding="utf-8")]
strumenti = ("Read,Write,Edit,%s,Bash(git add *),Bash(git commit *)"
             % sys.argv[2])
ok = len(righe) == 5
for n, r in enumerate(righe, 1):
    a = r["argv"]
    c = {a[i]: a[i + 1] for i in range(len(a) - 1)}
    ok &= c.get("--model") == "sonnet" and c.get("--effort") == "medium"
    ok &= c.get("--allowedTools") == strumenti
    ok &= c.get("--output-format") == "json" and "--strict-mcp-config" in a
    ok &= c.get("--permission-mode") == ("plan" if n == 1 else "dontAsk")
    ok &= c.get("--resume") == {1: None, 5: None}.get(n, "sessione-finta-1")
    prompt = open(os.path.join(sys.argv[3], "prompt-%d.txt" % n),
                  encoding="utf-8").read()
    ok &= a[-1] == prompt and not r["chiave"]
print("opzioni ok" if ok else "opzioni diverse: %s" % righe)
PY
}

t_live() {
  local w
  senza_chiamate "live.sh: spazio di lavoro assente esce 2" \
    "spazio di lavoro assente" "${TMP}/non-esiste"
  ws w
  rm "${w}/SPECIFICA.md" || rotta "rm"
  senza_chiamate "live.sh: senza SPECIFICA.md esce 2" "SPECIFICA.md" "${w}"
  ws w
  rm "${w}/.claude/agents/revisore.md" || rotta "rm"
  senza_chiamate "live.sh: senza il revisore esce 2" "revisore.md" "${w}"
  ws w
  fx "${w}" nota
  senza_chiamate "live.sh: git status non vuoto esce 2, con il reset" \
    "tools/reset_esercizio.sh M4-E02" "${w}"
  ws w
  git -C "${w}" -c user.name=Prova -c user.email=prova@example.org \
    commit -q --allow-empty -m "lavoro di prima" || rotta "git commit"
  senza_chiamate "live.sh: un commit dopo il primo esce 2, con il reset" \
    "tools/reset_esercizio.sh M4-E02" "${w}"
  ws w
  live_finto "${w}" ANTHROPIC_API_KEY=chiave-finta
  expect "live.sh: le due parti e la verifica, esce 0" 0 \
    "VERIFICA OK   verifica.sh dell'elemento"
  expect_chiamate "live.sh: cinque chiamate" 5
  if [[ -f "${w}.prova_dal_vivo/turno-5.json" \
      && ! -e "${w}/prova_dal_vivo" ]]; then
    pass "live.sh: i JSON fuori dallo spazio di lavoro, accanto"
  else
    fail "live.sh: i JSON non sono in ${w}.prova_dal_vivo/"
  fi
  controlla_opzioni
  expect "live.sh: plan, poi dontAsk, --resume, strumenti, prompt, chiave" \
    0 "opzioni ok"
  if [[ -f "${w}/piani/piano-finto.md" ]]; then
    pass "live.sh: il piano nello spazio di lavoro, in piani/"
  else
    fail "live.sh: il piano non è in piani/"
  fi
  ws w
  live_finto "${w}" FINTO_E02_LAVORO=a_meta
  expect "live.sh: finito nella seconda parte, esce 0" 0 "VERIFICA OK"
  expect_chiamate "live.sh: finito nella seconda parte, cinque chiamate" 5
  ws w
  live_finto "${w}" FINTO_E02_LAVORO=mai FINTO_E02_MAI=1
  expect "live.sh: mai finito, esce 1" 1 "VERIFICA KO"
  expect_chiamate "live.sh: mai finito, due seguiti, sette chiamate" 7
  ws w
  live_finto "${w}" FINTO_ESITO=ko
  expect "live.sh: una chiamata fallita esce 1" 1 \
    "il turno 1 non ha dato una risposta"
  ws w
  live_finto "${w}" FINTO_REVISORE=modifica
  expect "live.sh: un revisore che modifica, la verifica dice KO" 1 \
    "non ha tenuto"
}

# Gli strumenti del repository: prepara_esercizio.sh e verifica.sh.
t_integrazione() {
  local radice
  radice="$(mktemp -d "${TMP}/radice.XXXXXX")" || rotta "mktemp"
  run "${RADICE}/tools/prepara_esercizio.sh" M4-E02 --radice "${radice}"
  expect "prepara_esercizio.sh M4-E02" 0 "Spazio di lavoro pronto"
  if [[ -x "${radice}/M4-E02/tools/php.sh" \
      && -f "${radice}/M4-E02/SPECIFICA.md" \
      && -f "${radice}/M4-E02/.claude/agents/revisore.md" \
      && -f "${radice}/M4-E02/.claude/agents/autore-test.md" \
      && ! -e "${radice}/M4-E02/${PROGETTO}/_docente" \
      && ! -e "${radice}/M4-E02/NOTA.md" ]]; then
    pass "lo spazio di lavoro: gestionale, specifica, subagent, php.sh"
  else
    fail "lo spazio di lavoro non è il punto di partenza"
  fi
  run env PN_CLAUDE_DIR="${TMP}/claude" "${RADICE}/tools/verifica.sh" \
    M4-E02 --radice "${radice}"
  expect "tools/verifica.sh sul punto di partenza esce 1" 1 "NON ANCORA"
}

t_shellcheck() {
  local f
  for f in "${E02}/verifica.sh" "${E02}/_docente/live.sh" \
      "${E02}/soluzione/applica.sh" "${SELF}"; do
    if (cd "${RADICE}" && shellcheck -x "${f}") > /dev/null 2>&1; then
      pass "shellcheck ${f#"${RADICE}"/}"
    else
      fail "shellcheck ${f#"${RADICE}"/}"
    fi
  done
}

main() {
  local t
  for t in python3 jq git shellcheck realpath; do
    command -v "${t}" > /dev/null 2>&1 \
      || { echo "test_m4_e02: manca ${t}" >&2; exit 2; }
  done
  for t in README.md progetti.txt verifica.sh verifica.py \
      esercizio/SPECIFICA.md esercizio/tools/php.sh \
      esercizio/.claude/settings.json esercizio/.claude/agents/revisore.md \
      esercizio/.claude/agents/autore-test.md soluzione/applica.sh \
      soluzione/NOTA.md _docente/live.sh; do
    [[ -e "${E02}/${t}" ]] || { echo "test_m4_e02: manca ${t}" >&2; exit 2; }
  done
  for t in "${PHP_FINTO}" "${CLAUDE_FINTO}"; do
    [[ -x "${t}" ]] || { echo "test_m4_e02: manca ${t}" >&2; exit 2; }
  done
  handson::init_temp_base
  TMP="$(mktemp -d "${HANDSON_TEMP_BASE}/test_m4_e02.XXXXXX")" || exit 2
  trap 'rm -rf "${TMP}"' EXIT
  prepara
  t_copie
  t_specifica
  t_readme
  t_verifica
  t_trascrizioni
  t_verifica_precondizioni
  t_soluzione
  t_reale
  t_live
  t_integrazione
  t_shellcheck
  echo "PASS=${PASS} FAIL=${FAIL} SKIP=${SKIP}" \
    "CASES=$((PASS + FAIL + SKIP))/${CASES}"
  if (( PASS + FAIL + SKIP != CASES )); then
    echo "test_m4_e02: eseguite $((PASS + FAIL + SKIP)) prove, attese" \
      "${CASES}: un caso manca o non è contato" >&2
    exit 2
  fi
  (( FAIL == 0 )) || exit 1
}

main "$@"
