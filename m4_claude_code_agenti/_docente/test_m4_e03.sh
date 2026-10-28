#!/bin/bash
#
# test_m4_e03.sh -- le prove di M4-E03 «Un modulo opaco: documentarlo e
# proporre il refactoring», per il docente:
#   - i file dell'elemento: progetti.txt; esercizio/tools/php.sh uguale a
#     tools/php.sh ed eseguibile; le impostazioni (la regola deny su
#     legacy/ e quella sulla copia di php.sh accanto alle regole del
#     repository, il comando dei test consentito, defaultMode default,
#     plansDirectory piani); la riga che la verifica rompe, una volta sola
#     e alla riga 29 del modulo, che non è fra i file dei difetti del
#     Modulo 5;
#   - il README: le dieci sezioni; i cinque prompt fra i segni; i due
#     subagent Explore in parallelo con il formato dei riassunti; le sei
#     sezioni della documentazione, nell'ordine; il comando dei test, un
#     comando per volta, la chiusura vera; il formato della proposta; le
#     citazioni con i loro link, solo link ufficiali; nessun identificativo
#     interno, niente macOS né Percorso A, nessun riferimento all'orario;
#   - verifica.sh con il php.sh finto (PN_PHP_SH) e una cartella di Claude
#     di prova (PN_CLAUDE_DIR): il punto di partenza (1, senza PHP); la
#     soluzione (0); la documentazione (mancante, una sezione, una vuota,
#     l'ordine, una tabella, le voci; i titoli numerati vanno bene), la
#     proposta (mancante, due passi, un salto, un passo senza controllo, un
#     controllo senza i test; il grassetto va bene), i test (rossi, rotti,
#     interrotti sull'originale; verdi anche sulla copia rotta; Docker che
#     non parte sull'originale o sulla copia rotta, una precondizione e mai
#     «falliscono»; un file che non è un test non conta), legacy/ cambiato
#     (nel commit, fuori, un file nuovo; i test girano lo stesso sul modulo
#     originale); i dati (la regola deny, NOTA.md, i piani, i commit, le
#     sessioni con le chiamate Agent e Task, i doppioni, le righe dei
#     subagent, una riga rotta, ExitPlanMode, le modifiche tentate su
#     legacy/, U+2028 dentro una riga, una riga troppo annidata, una cartella
#     oltre i 200 caratteri) mai come uscita; la verifica non scrive nello
#     spazio di lavoro, nemmeno in .git/index, e non usa il suo php.sh; le
#     precondizioni (2), anche un errore inatteso e python3 o git mancanti;
#   - soluzione/: applica.sh con il finto (copia e installa; con vendor/ non
#     reinstalla; precondizioni; una copia che non riesce, 2); il test di
#     riferimento nelle convenzioni del progetto; la documentazione che
#     descrive senza giudicare;
#   - con PHP o Docker davvero (altrimenti SKIP): la soluzione passa, un
#     test solo in simulazione no, il punto di partenza no,
#     tools/run_all.sh M4-E03;
#   - _docente/live.sh con un claude finto: le precondizioni escono 2 senza
#     chiamare claude, anche uno spazio di lavoro che ha già del lavoro (git
#     status non vuoto, o un commit dopo il primo); le due parti, sei
#     chiamate, --resume giusti, plan mode solo per la proposta, le opzioni
#     e gli strumenti, i prompt uguali a quelli del README, la chiave tolta,
#     le dipendenze installate, i seguiti sui test, una chiamata fallita
#     (1), legacy/ toccato (1), un test debole mai sistemato (1), una
#     documentazione incompleta sistemata dal turno che porta le righe «Non
#     ancora» della verifica (0), nessun subagent (0, è un dato), i JSON
#     fuori dallo spazio di lavoro, in <spazio>.prova_dal_vivo/;
#   - il README: il passo 8 torna in esercitazioni con il suo percorso;
#     Manual chiede per ciò che non è di sola lettura, «di regola»; i
#     traguardi e il tool Agent; la nota sui JSON della prova del corso;
#   - prepara_esercizio.sh e tools/verifica.sh con l'elemento vero, e
#     check_handson.sh senza segnalazioni su M4-E03;
#   - shellcheck -x sugli script dell'elemento e su questo; la sintassi dei
#     tre file Python.
# Gli spazi di lavoro nascono in una cartella temporanea, nella base di
# handson::init_temp_base: l'albero del repository non cambia. Un numero di
# casi diverso da CASES esce 2.
#
# Uso:    m4_claude_code_agenti/_docente/test_m4_e03.sh
# Uscita: 0 = tutte le prove passano (uno SKIP non è un fallimento: è
#         contato e stampato) · 1 = almeno una fallita · 2 = precondizione
#         (manca python3, jq, git o shellcheck, un file dell'elemento; una
#         preparazione non riesce; le prove eseguite non sono quante attese)
set -uo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly MOD="${SELF%/_docente/*}"
readonly RADICE="${MOD%/*}"
readonly E03="${MOD}/s3_agente_nel_repository/m4_e2_laboratorio/\
M4-E03_modulo_opaco"
readonly SOL="${E03}/soluzione"
readonly PHP_FINTO="${MOD}/_docente/php_finto_m4_e03.py"
readonly CLAUDE_FINTO="${MOD}/_docente/claude_finto_m4_e03.py"
# shellcheck source=../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"
readonly CASES=187
readonly PROGETTO="progetti/gestionale-php"
readonly TEST_REL="${PROGETTO}/tests/Integrazione/ChiusuraMeseTest.php"
readonly DOC_REL="${PROGETTO}/docs/chiusura_mese.md"
readonly MODULO_REL="${PROGETTO}/legacy/chiusura_mese.inc.php"
readonly COMANDO="tools/php.sh php ${PROGETTO}/vendor/bin/phpunit \
-c ${PROGETTO}"
readonly REGOLA_TEST="Bash(tools/php.sh php ${PROGETTO}/vendor/bin/phpunit *)"
readonly REGOLA_DENY="Edit(/${PROGETTO}/legacy/**)"
STRUMENTI="Read,Write,Edit,${REGOLA_TEST},Bash(git add *),"
STRUMENTI+="Bash(git commit *)"
readonly STRUMENTI
readonly APPROVAZIONE="Il piano è approvato: procedi come dice il piano."
readonly TAB=$'\t'
readonly FINE="Fatto: documentazione e proposta complete, i test fissano \
il comportamento e legacy/ è com'era."
# Gli identificativi interni che i file per i partecipanti non portano.
INTERNI='FACT-|Tecnodata|[Tt]riage|Envelope|M[0-9]-X[0-9]|\bX-[0-9]'
INTERNI+='|\b(ASK|OQ|DEC|TD|PQ)-[0-9]|\bB#[0-9]'
readonly INTERNI
TMP=''
MODELLO=''
CLAUDE_VUOTA=''
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
rotta() { echo "test_m4_e03: preparazione non riuscita: $*" >&2; exit 2; }

# Un nuovo spazio di lavoro, copia del modello preparato da
# prepara_esercizio.sh. Arguments: $1 la variabile da assegnare, $2
# «vendor» per aggiungere vendor/bin/phpunit (come composer install), $3
# (facoltativo) la cartella in cui crearlo.
ws() {
  local __w
  __w="$(mktemp -d "${3:-${TMP}}/ws.XXXXXX")" || rotta "mktemp"
  cp -a "${MODELLO}/." "${__w}/" || rotta "cp del modello"
  if [[ "${2:-}" == "vendor" ]]; then
    mkdir -p "${__w}/${PROGETTO}/vendor/bin" || rotta "vendor"
    : > "${__w}/${PROGETTO}/vendor/bin/phpunit" || rotta "vendor"
  fi
  printf -v "$1" '%s' "${__w}"
}

# La verifica dell'elemento con il php.sh finto e senza sessioni.
# Arguments: $1 lo spazio di lavoro, poi variabili d'ambiente (VAR=valore).
verifica() {
  local w="$1"
  shift
  run env PN_PHP_SH="${PHP_FINTO}" PN_CLAUDE_DIR="${CLAUDE_VUOTA}" "$@" \
    "${E03}/verifica.sh" "${w}"
}

# La soluzione con il php.sh finto. Arguments: $1 lo spazio di lavoro.
soluzione() {
  env PN_PHP_SH="${PHP_FINTO}" "${SOL}/applica.sh" "$1" > /dev/null 2>&1 \
    || rotta "soluzione/applica.sh"
}

# Una variante dei file dello spazio di lavoro, con fx.py.
# Arguments: $1 lo spazio, $2 la variante, $3 l'argomento (facoltativo).
fx() { python3 -B -I "${TMP}/fx.py" "$@" || rotta "fx $*"; }

# Un commit nello spazio di lavoro. Arguments: $1 lo spazio, $2 il messaggio.
fai_commit() {
  git -C "$1" add -A > /dev/null 2>&1 || rotta "git add"
  git -C "$1" -c user.name=prova -c user.email=prova@example.org \
    -c commit.gpgsign=false commit -q -m "$2" > /dev/null 2>&1 \
    || rotta "git commit"
}

# fx.py: le varianti dei file dello spazio di lavoro.
scrivi_fx() {
  cat > "${TMP}/fx.py" <<'PY' || rotta "fx.py"
"""fx.py -- le varianti di test_m4_e03.sh, scritte nello spazio di lavoro.
Il php.sh finto giudica i test dai segni FINTO (non è PHP)."""
import json
import os
import re
import sys

ws, variante = sys.argv[1], sys.argv[2]
arg = sys.argv[3] if len(sys.argv) > 3 else ""
PROG = os.path.join(ws, "progetti", "gestionale-php")
DOC = os.path.join(PROG, "docs", "chiusura_mese.md")
PROP = os.path.join(ws, "PROPOSTA.md")
TEST = os.path.join(PROG, "tests", "Integrazione", "ChiusuraMeseTest.php")
MODULO = os.path.join(PROG, "legacy", "chiusura_mese.inc.php")
IMP = os.path.join(ws, ".claude", "settings.json")
RIGA = "    $simula = !empty($opzioni['simula']);\n"
DEBOLE = '''<?php

declare(strict_types=1);

namespace CiaspoLink\\Gestionale\\Tests\\Integrazione;

use CiaspoLink\\Gestionale\\Tests\\Support\\DatabaseDiProva;
use PHPUnit\\Framework\\TestCase;

final class ChiusuraMeseTest extends TestCase
{
    public function testInSimulazioneRestituisceIlPeriodo(): void
    {
        require_once __DIR__ . '/../../legacy/chiusura_mese.inc.php';
        $GLOBALS['db'] = DatabaseDiProva::vuoto();

        $esito = chiusura_mese(2026, 8, [
            'oggi' => '2026-09-02',
            'verbose' => false,
            'simula' => true,
        ]);

        self::assertSame('2026-08', $esito['periodo']);
    }
}
'''


def leggi(p):
    with open(p, encoding="utf-8") as fh:
        return fh.read()


def scrivi(p, t):
    os.makedirs(os.path.dirname(p), exist_ok=True)
    with open(p, "w", encoding="utf-8") as fh:
        fh.write(t)


def blocchi(testo, schema):
    out = [[None, []]]
    for riga in testo.split("\n"):
        m = re.match(schema, riga)
        if m:
            out.append([m.group(1), [riga]])
        else:
            out[-1][1].append(riga)
    return out


def unisci(bb):
    return "\n".join(r for _, righe in bb for r in righe)


SEZ = r"^## (.+?)\s*$"
PASSO = r"^#{2,3}\s+Passo\s+(\d+)"

if variante == "doc_senza":
    scrivi(DOC, unisci([b for b in blocchi(leggi(DOC), SEZ) if b[0] != arg]))
elif variante == "doc_vuota":
    bb = blocchi(leggi(DOC), SEZ)
    for b in bb:
        if b[0] == arg:
            b[1] = [b[1][0], ""]
    scrivi(DOC, unisci(bb))
elif variante == "doc_ordine":
    bb = blocchi(leggi(DOC), SEZ)
    bb[1], bb[2] = bb[2], bb[1]
    scrivi(DOC, unisci(bb))
elif variante == "doc_senza_tabella":
    scrivi(DOC, re.sub(r"\b%s\b" % re.escape(arg), "tabella", leggi(DOC)))
elif variante == "doc_voci":
    bb = blocchi(leggi(DOC), SEZ)
    for b in bb:
        if b[0] == "Le sei responsabilità":
            tenute, voci = [], 0
            for r in b[1]:
                if re.match(r"^\s*(\d+[.)]|[-*+])\s+", r):
                    voci += 1
                    if voci > int(arg):
                        continue
                tenute.append(r)
            b[1] = tenute
    scrivi(DOC, unisci(bb))
elif variante == "doc_numerati":
    bb = blocchi(leggi(DOC), SEZ)
    for k, b in enumerate(bb[1:], start=1):
        b[1][0] = "## %d. %s" % (k, b[0])
    scrivi(DOC, unisci(bb))
elif variante == "prop_passi":
    bb = blocchi(leggi(PROP), PASSO)
    scrivi(PROP, unisci([b for b in bb if b[0] is None
                         or int(b[0]) <= int(arg)]))
elif variante == "prop_salto":
    scrivi(PROP, re.sub(r"(?m)^(#{2,3}\s+Passo\s+)2\b", r"\g<1>4",
                        leggi(PROP), count=1))
elif variante == "prop_senza_controllo":
    bb = blocchi(leggi(PROP), PASSO)
    for b in bb:
        if b[0] == arg:
            b[1] = [r for r in b[1] if "Controllo" not in r]
    scrivi(PROP, unisci(bb))
elif variante == "prop_senza_test":
    bb = blocchi(leggi(PROP), PASSO)
    for b in bb:
        if b[0] == arg:
            b[1] = ["Controllo: `php -l bin/chiusura-mese.php` — nessun errore"
                    if "Controllo" in r else r for r in b[1]]
    scrivi(PROP, unisci(bb))
elif variante == "prop_grassetto":
    scrivi(PROP, re.sub(r"(?m)^Controllo:", "**Controllo:**", leggi(PROP)))
elif variante == "test_segno":
    with open(TEST, "a", encoding="utf-8") as fh:
        fh.write("// FINTO: %s\n" % arg)
elif variante == "test_aiuto":
    scrivi(os.path.join(PROG, "tests", "Support", "AiutoChiusura.php"),
           "<?php\n// FINTO: rosso\n")
elif variante == "test_debole_vero":
    scrivi(TEST, DEBOLE)
elif variante == "legacy_tocca":
    with open(MODULO, "a", encoding="utf-8") as fh:
        fh.write("// ritocco\n")
elif variante == "legacy_nuovo":
    scrivi(os.path.join(PROG, "legacy", "nuovo.inc.php"), "<?php\n")
elif variante == "senza_simula":
    scrivi(MODULO, leggi(MODULO).replace(
        RIGA, "    $simula = !empty($opzioni['prova']);\n"))
elif variante == "regola_via":
    with open(IMP, encoding="utf-8") as fh:
        d = json.load(fh)
    d["permissions"]["deny"] = [r for r in d["permissions"]["deny"]
                                if "legacy" not in r]
    scrivi(IMP, json.dumps(d, indent=2) + "\n")
elif variante == "php_rotto":
    php = os.path.join(ws, "tools", "php.sh")
    scrivi(php, "#!/bin/bash\nexit 7\n")
    os.chmod(php, 0o755)
else:
    sys.exit(2)
PY
}

# sessioni.py: trascrizioni finte, a forma di quelle di Claude Code.
scrivi_sessioni() {
  cat > "${TMP}/sessioni.py" <<'PY' || rotta "sessioni.py"
"""sessioni.py -- trascrizioni FINTE per test_m4_e03.sh, a forma di quelle
di Claude Code: scritte solo nella cartella di prova, mai in ~/.claude."""
import json
import os
import re
import sys

base, ws, variante = sys.argv[1:4]
nome = re.sub(r"[^A-Za-z0-9]", "-", os.path.realpath(ws))
if variante == "lunga":
    nome = nome[:200] + "-hashfinto"
cartella = os.path.join(base, "projects", nome)
os.makedirs(cartella, exist_ok=True)


def uso(i, strumento, tipo=None, descrizione="compito finto"):
    entrata = {"description": descrizione, "prompt": "compito finto"}
    if tipo:
        entrata["subagent_type"] = tipo
    return {"type": "tool_use", "id": "toolu_finto_%d" % i,
            "name": strumento, "input": entrata}


def assistente(mid, blocchi, laterale=False):
    return {"type": "assistant", "isSidechain": laterale, "sessionId": "s1",
            "message": {"id": mid, "role": "assistant", "content": blocchi}}


def modifica(i, percorso):
    return {"type": "tool_use", "id": "toolu_finto_%d" % i, "name": "Edit",
            "input": {"file_path": os.path.join(ws, percorso),
                      "old_string": "a", "new_string": "b"}}


righe = []
if variante in ("due", "lunga"):
    righe.append(assistente("m1", [uso(1, "Agent", "Explore"),
                                   uso(2, "Agent", "Explore")]))
if variante == "due":
    righe += [assistente("m1", [uso(1, "Agent", "Explore")]),
              assistente("m2", [uso(3, "Task", "general-purpose")]),
              assistente("m9", [uso(9, "Agent", "Explore")], laterale=True),
              assistente("m3", [uso(4, "ExitPlanMode")]),
              assistente("m4", [modifica(5, "progetti/gestionale-php/legacy/"
                                            "chiusura_mese.inc.php"),
                                modifica(6, "progetti/gestionale-php/tests/"
                                            "Integrazione/X.php")]),
              # U+2028 dentro una stringa: una riga sola di JSONL
              assistente("m5", [uso(7, "Agent", "Explore",
                                    "prima seconda")])]
if variante == "profonda":
    righe.append(assistente("m1", [uso(1, "Agent", "Explore")]))
with open(os.path.join(cartella, "s1.jsonl"), "w", encoding="utf-8") as fh:
    for r in righe:
        fh.write(json.dumps(r, ensure_ascii=False) + "\n")
    if variante == "due":
        fh.write("{ riga rotta\n")
    if variante == "profonda":
        fh.write("[" * 100000 + "]" * 100000 + "\n")
if variante == "due":
    sub = os.path.join(cartella, "s1", "subagents")
    os.makedirs(sub, exist_ok=True)
    for k in (1, 2):
        with open(os.path.join(sub, "agent-finto%d.jsonl" % k), "w") as fh:
            fh.write("{}\n")
PY
}

# I file di aiuto, il claude finto, il modello dello spazio di lavoro e la
# prova che PHP gira davvero (tools/php.sh, con PHP o con Docker).
prepara() {
  local radice
  handson::need_tools python3 jq git shellcheck
  for f in "${PHP_FINTO}" "${CLAUDE_FINTO}"; do
    [[ -x "${f}" ]] || rotta "manca o non è eseguibile: ${f}"
  done
  scrivi_fx
  scrivi_sessioni
  mkdir -p "${TMP}/finto" "${TMP}/claude-vuota" || rotta "mkdir"
  CLAUDE_VUOTA="${TMP}/claude-vuota"
  cp "${CLAUDE_FINTO}" "${TMP}/finto/claude" || rotta "il claude finto"
  chmod 755 "${TMP}/finto/claude" || rotta "chmod"
  radice="$(mktemp -d "${TMP}/radice.XXXXXX")" || rotta "mktemp"
  if "${RADICE}/tools/prepara_esercizio.sh" M4-E03 --radice "${radice}" \
      > /dev/null 2>&1; then
    MODELLO="${radice}/M4-E03"
  fi
  if (cd "${TMP}" && "${RADICE}/tools/php.sh" php -r 'exit(0);') \
      > /dev/null 2>&1; then
    PHP_OK=1
  fi
}

# I file dell'elemento e le impostazioni dello spazio di lavoro.
t_file() {
  run cat "${E03}/progetti.txt"
  expect "progetti.txt: il gestionale" 0 "${PROGETTO}"
  if cmp -s "${E03}/esercizio/tools/php.sh" "${RADICE}/tools/php.sh"; then
    pass "esercizio/tools/php.sh è tools/php.sh, byte per byte"
  else
    fail "esercizio/tools/php.sh diverso da tools/php.sh"
  fi
  local f
  for f in esercizio/tools/php.sh verifica.sh soluzione/applica.sh \
      _docente/live.sh; do
    if [[ -x "${E03}/${f}" ]]; then
      pass "${f} eseguibile"
    else
      fail "${f} assente o senza il bit di esecuzione"
    fi
  done
  if [[ -f "${E03}/_docente/lib_prova_dal_vivo.sh" \
      && ! -x "${E03}/_docente/lib_prova_dal_vivo.sh" ]]; then
    pass "la libreria di live.sh c'è e non è eseguibile"
  else
    fail "_docente/lib_prova_dal_vivo.sh assente o eseguibile"
  fi
  run python3 -B -I - "${E03}/esercizio/.claude/settings.json" \
    "${RADICE}/.claude/settings.json" "${REGOLA_TEST}" "${REGOLA_DENY}" <<'PY'
import json
import sys

d = json.load(open(sys.argv[1], encoding="utf-8"))
e = d["permissions"]
r = json.load(open(sys.argv[2], encoding="utf-8"))["permissions"]
print("allow %s" % ("ok" if e.get("allow") == [sys.argv[3]] else "diverso"))
attese = r["deny"] + ["Edit(/tools/php.sh)", sys.argv[4]]
print("deny %s" % ("ok" if e.get("deny") == attese else "diverso"))
print("modo %s" % ("ok" if e.get("defaultMode") == "default" else "diverso"))
print("piani %s" % ("ok" if d.get("plansDirectory") == "piani" else "no"))
PY
  expect "impostazioni: allow, solo il comando dei test" 0 "allow ok"
  expect "impostazioni: deny del repository, di php.sh e di legacy/" 0 \
    "deny ok"
  expect "impostazioni: defaultMode default (Manual)" 0 "modo ok"
  expect "impostazioni: plansDirectory piani" 0 "piani ok"
  run python3 -B -I - "${E03}/esercizio/.claude/settings.json" \
    "${E03}/README.md" <<'PY'
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
  expect "impostazioni e README: le regole deny ancorate, citate, e perché" \
    0 "regole ancorate e citate"
}

# La riga che la verifica rompe, e il modulo fuori dai difetti del Modulo 5.
t_modulo() {
  run python3 -B -I - "${RADICE}/${MODULO_REL}" <<'PY'
import sys

righe = open(sys.argv[1], encoding="utf-8").read().split("\n")
pos = [i + 1 for i, r in enumerate(righe)
       if r == "    $simula = !empty($opzioni['simula']);"]
print("righe %s" % pos)
PY
  expect "il modulo ha la riga di \$simula una volta, alla 29" 0 "righe [29]"
  run python3 -B -I - "${RADICE}/${PROGETTO}/_docente/difetti-noti.md" <<'PY'
import sys

testo = open(sys.argv[1], encoding="utf-8").read()
inizio = testo.index("## 1.")
fine = testo.index("## 2.")
print("nei difetti: %s" % ("chiusura_mese.inc.php" in testo[inizio:fine]))
PY
  expect "il modulo rotto dalla verifica non è un file dei difetti" 0 \
    "nei difetti: False"
}

# I prompt del README fra i segni, in ${TMP}/prompt-<n>.txt.
estrai_prompt() {
  python3 -B -I - "${E03}/README.md" "${TMP}" <<'PY'
import os
import sys
import textwrap

righe = [r.strip() for r in
         open(sys.argv[1], encoding="utf-8").read().split("\n")]
testo = open(sys.argv[1], encoding="utf-8").read().split("\n")
for n in range(1, 6):
    a = [i for i, r in enumerate(righe) if r == "<!-- prompt %d -->" % n]
    b = [i for i, r in enumerate(righe) if r == "<!-- /prompt %d -->" % n]
    if len(a) == 1 and len(b) == 1 and a[0] < b[0]:
        p = textwrap.dedent("\n".join(testo[a[0] + 1:b[0]])).strip("\n")
        if p.strip():
            with open(os.path.join(sys.argv[2], "prompt-%d.txt" % n), "w",
                      encoding="utf-8") as fh:
                fh.write(p)
            print("prompt %d ok" % n)
PY
}

# Un prompt su una riga sola, con gli spazi ridotti. Arguments: $1 il numero.
prompt_in_riga() { tr -s ' \n' ' ' < "${TMP}/prompt-$1.txt"; }

# Il README: le sezioni, i prompt, le citazioni, ciò che non deve esserci.
t_readme() {
  local n s
  run estrai_prompt
  for n in 1 2 3 4 5; do
    expect "README: il prompt ${n} fra i segni" 0 "prompt ${n} ok"
  done
  OUT="$(cat "${E03}/README.md")"
  RC=0
  for s in Obiettivo Tempo Prerequisiti "Punto di partenza" \
      "Passi in Claude Code" "Che cosa osservare" Verifica \
      "Se qualcosa va storto" "Impronta d'uso sul piano Pro" \
      "Per approfondire"; do
    if grep -q "^## ${s}" <<< "${OUT}"; then
      pass "README: la sezione «${s}»"
    else
      fail "README: manca la sezione «${s}»"
    fi
  done
  OUT="$(prompt_in_riga 1 2>/dev/null)"
  expect "prompt 1: due subagent Explore" 0 "Usa due subagent Explore"
  expect "prompt 1: in parallelo" 0 "in parallelo, nello stesso messaggio"
  expect "prompt 1: un riassunto breve, in un formato" 0 \
    "un riassunto breve in questo formato"
  OUT="$(prompt_in_riga 2 2>/dev/null)"
  expect "prompt 2: le sei sezioni, in ordine" 0 \
    "Che cosa fa · Ingressi e uscite · Tabelle lette e scritte · Effetti \
collaterali · Le sei responsabilità · Rischi"
  expect "prompt 2: descrivere senza giudicare" 0 "senza giudicarlo"
  expect "prompt 2: il controllo finale della ricetta" 0 \
    "controlla che abbia le sei sezioni"
  OUT="$(prompt_in_riga 3 2>/dev/null)"
  expect "prompt 3: il comando dei test" 0 "${COMANDO} ${TEST_REL}"
  expect "prompt 3: un comando per volta" 0 \
    "da solo, senza concatenarlo ad altri"
  expect "prompt 3: la chiusura vera" 0 "senza simulazione"
  expect "prompt 3: il legacy non si modifica" 0 \
    "Non modificare niente in ${PROGETTO}/legacy/"
  OUT="$(prompt_in_riga 4 2>/dev/null)"
  expect "prompt 4: NOTA.md" 0 "Scrivi NOTA.md"
  OUT="$(prompt_in_riga 5 2>/dev/null)"
  expect "prompt 5: il formato dei passi" 0 "«## Passo N — titolo»"
  expect "prompt 5: la riga del controllo" 0 "«Controllo: »"
  expect "prompt 5: almeno tre passi" 0 "almeno tre"
  if [[ -s "${TMP}/prompt-5.txt" \
      && "$(head -c 1 "${TMP}/prompt-5.txt")" != "/" ]]; then
    pass "prompt 5: senza /plan davanti (plan mode lo sceglie chi lo usa)"
  else
    fail "prompt 5 assente o comincia con /"
  fi
  t_readme_citazioni
  t_readme_vietati
}

# Le citazioni di Anthropic, ognuna con il suo link, e soltanto link
# ufficiali.
t_readme_citazioni() {
  run python3 -B -I - "${E03}/README.md" <<'PY'
import re
import sys

testo = " ".join(open(sys.argv[1], encoding="utf-8").read().split())
BP = "https://code.claude.com/docs/en/best-practices"
CW = "https://code.claude.com/docs/en/common-workflows"
CITAZIONI = [
    ("571", "Broad codebase searches go to the built-in Explore agent.", BP),
    ("569", "Keeping long output, like a full test run or a wide search, "
            "out of your main conversation", BP),
    ("572", "Ask for short summaries back, so twenty results don't fill "
            "your context anyway.", BP),
    ("347", "find functions without proper JSDoc comments in the auth "
            "module…check if the documentation follows our project "
            "standards", CW),
    ("344", "refactor utils.js to use ES2024 features while maintaining "
            "the same behavior…Do refactoring in small, testable increments",
     CW),
    ("358", "Run it against the original code to confirm it passes. Then "
            "run it against deliberately broken code to confirm it fails",
     "https://claude.com/resources/articles/ai-code-migration"),
    ("360", "Nothing edits your legacy source.…Start with one module or one "
            "unit as a pilot, not the whole estate.",
     "https://github.com/anthropics/claude-plugins-official/tree/main/"
     "plugins/code-modernization"),
    ("120", "Deny rules block in every mode, including bypassPermissions.",
     "https://code.claude.com/docs/en/permission-modes"),
]
for chiave, frase, url in CITAZIONI:
    print("citazione %s %s" % (chiave, "ok" if frase in testo and url in testo
                               else "manca"))
UFFICIALI = ("https://code.claude.com/", "https://claude.com/",
             "https://github.com/anthropics/", "https://www.anthropic.com/",
             "https://support.claude.com/", "https://academy.claude.com/",
             "https://www.youtube.com/watch?v=OwMu0pyYZBc")
altri = [u for u in re.findall(r"https?://[^\s)»>`]+", testo)
         if not u.startswith(UFFICIALI)]
print("link non ufficiali: %s" % (altri or "nessuno"))
PY
  local k
  for k in 571 569 572 347 344 358 360 120; do
    expect "README: la citazione (${k}) e il suo link" 0 "citazione ${k} ok"
  done
  expect "README: soltanto link ufficiali" 0 "link non ufficiali: nessuno"
}

# Ciò che i file per i partecipanti non portano; un file che manca è un
# fallimento, non un'assenza vuota (RU-01.T5).
t_readme_vietati() {
  local f
  for f in README.md verifica.sh verifica.py esercizio/.claude/settings.json
  do
    if [[ ! -s "${E03}/${f}" ]]; then
      fail "${f}: manca"
    elif grep -qE -- "${INTERNI}" "${E03}/${f}"; then
      fail "${f}: un identificativo interno"
    else
      pass "${f}: nessun identificativo interno"
    fi
  done
  if [[ ! -s "${E03}/README.md" ]]; then
    fail "README: manca (Percorso A, macOS, orario)"
    fail "README: manca"
    fail "README: manca"
    return 0
  fi
  OUT="$(cat "${E03}/README.md")"
  expect_absent "README: nessun Percorso A" "Percorso A"
  expect_absent "README: gli ambienti del corso, non macOS" "macOS"
  if grep -qiE '\boggi\b|prossima sessione|pausa|pranzo' "${E03}/README.md"
  then
    fail "README: un riferimento all'orario della giornata"
  else
    pass "README: nessun riferimento all'orario della giornata"
  fi
  run python3 -B -I - "${E03}/README.md" <<'PY'
import sys

testo = open(sys.argv[1], encoding="utf-8").read()
piatto = " ".join(testo.split())
passo = testo.split("\n8. ", 1)[-1].split("\n## ", 1)[0]
blocco = [r.strip() for r in passo.splitlines() if r.startswith("       ")]
print("ritorno ok" if blocco == ["cd ~/esercitazioni",
                                 "tools/verifica.sh M4-E03"]
      else "ritorno: %s" % blocco)
print("manual ok" if "non è di sola lettura" in piatto
      and "di regola" in piatto else "manual: niente «di regola»")
print("termini ok" if "Checkpoint" not in piatto and "Traguardo:" in piatto
      and "strumento Agent" not in piatto
      else "termini: «Checkpoint» o «strumento Agent»")
print("json ok" if "letto con `grep` anche i JSON" in piatto
      else "json: manca la nota sui JSON della prova del corso")
PY
  expect "README: il passo 8 torna in esercitazioni, non con cd -" 0 \
    "ritorno ok"
  expect "README: Manual chiede per ciò che non è di sola lettura" 0 \
    "manual ok"
  expect "README: Traguardo, non Checkpoint; il tool Agent" 0 "termini ok"
  expect "README: la prova del corso e i JSON della prima parte" 0 \
    "json ok"
}

# verifica.sh sul punto di partenza e con la soluzione.
t_partenza_soluzione() {
  local w
  ws w
  verifica "${w}" FINTO_PHP_ASSENTE=1
  expect "partenza: 1, manca la documentazione (senza PHP)" 1 \
    "manca la documentazione: ${DOC_REL}"
  expect "partenza: manca la proposta" 1 "manca la proposta: PROPOSTA.md"
  expect "partenza: nessun test di caratterizzazione" 1 \
    "nessun test di caratterizzazione nuovo"
  expect "partenza: l'ultima riga" 1 "Non ancora:"
  ws w
  soluzione "${w}"
  verifica "${w}"
  expect "soluzione: 0, fatto" 0 "${FINE}"
  expect "soluzione: i test passano sul codice originale" 0 \
    "sul codice originale i test passano"
  expect "soluzione: i test falliscono sulla copia rotta" 0 \
    "sulla copia rotta apposta i test falliscono"
  expect "soluzione: che cosa rompe la copia" 0 "riga 29"
  expect "soluzione: legacy/ com'era" 0 "legacy/ è com'era"
  expect "soluzione: NOTA.md come dato" 0 "Dati: NOTA.md: non c'è"
  expect "soluzione: la regola deny come dato" 0 "${REGOLA_DENY}"
  expect_absent "soluzione: nessun «Non ancora»" "Non ancora:"
}

# La documentazione: le sezioni, l'ordine, le tabelle, le voci.
t_documentazione() {
  local w
  ws w
  soluzione "${w}"
  fx "${w}" doc_senza Rischi
  verifica "${w}"
  expect "documentazione senza «Rischi»: 1" 1 \
    "la documentazione non ha la sezione «Rischi»"
  ws w
  soluzione "${w}"
  fx "${w}" doc_vuota "Effetti collaterali"
  verifica "${w}"
  expect "una sezione vuota: 1" 1 "la sezione «Effetti collaterali» è vuota"
  ws w
  soluzione "${w}"
  fx "${w}" doc_ordine
  verifica "${w}"
  expect "le sezioni fuori ordine: 1" 1 "non sono nell'ordine chiesto"
  ws w
  soluzione "${w}"
  fx "${w}" doc_senza_tabella offerte
  verifica "${w}"
  expect "una tabella non nominata: 1" 1 \
    "la sezione «Tabelle lette e scritte» non nomina: offerte"
  ws w
  soluzione "${w}"
  fx "${w}" doc_voci 5
  verifica "${w}"
  expect "cinque responsabilità: 1" 1 \
    "la sezione «Le sei responsabilità» ha 5 voci"
  ws w
  soluzione "${w}"
  fx "${w}" doc_numerati
  verifica "${w}"
  expect "i titoli numerati vanno bene: 0" 0 "${FINE}"
}

# La proposta: i passi, la numerazione, i controlli.
t_proposta() {
  local w
  ws w
  soluzione "${w}"
  rm -f "${w}/PROPOSTA.md"
  verifica "${w}"
  expect "senza proposta: 1" 1 "manca la proposta: PROPOSTA.md"
  ws w
  soluzione "${w}"
  fx "${w}" prop_passi 2
  verifica "${w}"
  expect "due passi: 1" 1 "la proposta ha 2 passi: ne servono almeno tre"
  ws w
  soluzione "${w}"
  fx "${w}" prop_salto
  verifica "${w}"
  expect "un salto nella numerazione: 1" 1 "non sono numerati 1, 2, 3"
  ws w
  soluzione "${w}"
  fx "${w}" prop_senza_controllo 2
  verifica "${w}"
  expect "un passo senza controllo: 1" 1 \
    "il passo 2 della proposta non ha la riga «Controllo:»"
  ws w
  soluzione "${w}"
  fx "${w}" prop_senza_test 3
  verifica "${w}"
  expect "un controllo che non esegue i test: 1" 1 \
    "il controllo del passo 3 non esegue i test"
  ws w
  soluzione "${w}"
  fx "${w}" prop_grassetto
  verifica "${w}"
  expect "il controllo in grassetto va bene: 0" 0 "${FINE}"
}

# I test: sul modulo originale e sulla copia rotta.
t_test() {
  local w
  ws w
  soluzione "${w}"
  fx "${w}" test_segno rosso
  verifica "${w}"
  expect "test rossi sull'originale: 1" 1 \
    "i test non passano sul codice originale"
  ws w
  soluzione "${w}"
  fx "${w}" test_segno rotto
  verifica "${w}"
  expect "test rotti (errore fatale): 1" 1 \
    "i test non si eseguono sul codice originale"
  ws w
  soluzione "${w}"
  fx "${w}" test_segno docker
  verifica "${w}"
  expect "Docker che non parte: 2, mai un esito dei test" 2 \
    "sul codice originale, PHPUnit non ha dato un esito dei test (uscita 125)"
  ws w
  soluzione "${w}"
  fx "${w}" test_segno docker_sulla_rotta
  verifica "${w}"
  expect "Docker che non parte sulla copia rotta: 2, mai «falliscono»" 2 \
    "sulla copia rotta apposta, PHPUnit non ha dato un esito dei test"
  expect_absent "...e niente «Fatto»" "Fatto:"
  ws w
  soluzione "${w}"
  fx "${w}" test_segno interrotto
  verifica "${w}"
  expect "test interrotti senza riepilogo: 1" 1 "senza il riepilogo di PHPUnit"
  ws w
  soluzione "${w}"
  fx "${w}" test_segno debole
  verifica "${w}"
  expect "test verdi anche sulla copia rotta: 1" 1 \
    "i test passano anche sulla copia rotta apposta"
  expect "...e dice che cosa manca" 1 "ciò che la chiusura scrive"
  ws w
  soluzione "${w}"
  fx "${w}" test_aiuto
  verifica "${w}"
  expect "un file che non è un *Test.php non conta: 0" 0 "${FINE}"
  expect_absent "...e non è nell'elenco" "AiutoChiusura.php"
}

# legacy/: cambiato nel commit, fuori dal commit, un file nuovo.
t_legacy() {
  local w
  ws w
  soluzione "${w}"
  fx "${w}" legacy_tocca
  fai_commit "${w}" "ritocco del legacy"
  verifica "${w}"
  expect "legacy/ cambiato e nel commit: 1" 1 \
    "legacy/ è cambiato rispetto al punto di partenza"
  expect "...il file nominato" 1 "legacy/chiusura_mese.inc.php"
  expect "...i test girano lo stesso sul modulo originale" 1 \
    "sul codice originale i test passano"
  ws w
  soluzione "${w}"
  fx "${w}" legacy_tocca
  verifica "${w}"
  expect "legacy/ cambiato fuori dal commit: 1" 1 \
    "legacy/ è cambiato rispetto al punto di partenza"
  ws w
  soluzione "${w}"
  fx "${w}" legacy_nuovo
  verifica "${w}"
  expect "un file nuovo in legacy/: 1" 1 "legacy/nuovo.inc.php"
  ws w
  soluzione "${w}"
  fx "${w}" regola_via
  verifica "${w}"
  expect "senza la regola deny: 0, è un dato" 0 "${FINE}"
  expect "...e lo dice" 0 "nelle impostazioni dello spazio di lavoro: non c'è"
}

# I dati: mai un'uscita.
t_dati() {
  local w c
  ws w
  soluzione "${w}"
  printf '# Nota\n' > "${w}/NOTA.md"
  mkdir -p "${w}/piani" && printf '# Piano\n' > "${w}/piani/uno.md"
  fai_commit "${w}" "la nota"
  verifica "${w}"
  expect "dati: NOTA.md c'è" 0 "Dati: NOTA.md: c'è"
  expect "dati: un piano in piani/" 0 "piani di plan mode in piani/: 1"
  expect "dati: un commit" 0 "commit dopo il punto di partenza: 1"
  expect "dati: nessuna sessione" 0 "nessuna sessione di Claude Code"
  c="$(mktemp -d "${TMP}/claude.XXXXXX")" || rotta "mktemp"
  python3 -B -I "${TMP}/sessioni.py" "${c}" "${w}" due || rotta "sessioni"
  verifica "${w}" PN_CLAUDE_DIR="${c}"
  expect "sessioni: Agent e Task, senza doppioni né righe laterali" 0 \
    "chiamate Agent: 4 (Explore 3, general-purpose 1)"
  expect "sessioni: due nello stesso messaggio" 0 \
    "nello stesso messaggio: 2"
  expect "sessioni: le trascrizioni dei subagent" 0 \
    "trascrizioni di subagent: 2"
  expect "sessioni: ExitPlanMode" 0 "(ExitPlanMode): 1"
  expect "sessioni: le modifiche tentate su legacy/, non le altre" 0 \
    "su legacy/ (la regola deny le ferma): 1"
  expect "sessioni: la riga rotta contata" 0 "che non si leggono: 1"
  t_dati_cartelle
}

# Le sessioni: una cartella senza chiamate e una oltre i 200 caratteri.
t_dati_cartelle() {
  local w c lunga
  ws w
  soluzione "${w}"
  c="$(mktemp -d "${TMP}/claude.XXXXXX")" || rotta "mktemp"
  python3 -B -I "${TMP}/sessioni.py" "${c}" "${w}" vuota || rotta "sessioni"
  verifica "${w}" PN_CLAUDE_DIR="${c}"
  expect "sessioni senza subagent: 0, è un dato" 0 "chiamate Agent: 0"
  ws w
  soluzione "${w}"
  c="$(mktemp -d "${TMP}/claude.XXXXXX")" || rotta "mktemp"
  python3 -B -I "${TMP}/sessioni.py" "${c}" "${w}" profonda \
    || rotta "sessioni"
  verifica "${w}" PN_CLAUDE_DIR="${c}"
  expect "una riga JSON troppo annidata: contata, mai un'uscita" 0 \
    "che non si leggono: 1"
  lunga="${TMP}/$(printf 'cartella%.0s' {1..24})"
  mkdir -p "${lunga}" || rotta "mkdir lunga"
  ws w "" "${lunga}"
  soluzione "${w}"
  c="$(mktemp -d "${TMP}/claude.XXXXXX")" || rotta "mktemp"
  python3 -B -I "${TMP}/sessioni.py" "${c}" "${w}" lunga || rotta "sessioni"
  verifica "${w}" PN_CLAUDE_DIR="${c}"
  expect "cartella oltre i 200 caratteri, trovata dal prefisso" 0 \
    "chiamate Agent: 2 (Explore 2)"
}

# La verifica non scrive nello spazio di lavoro e non usa il suo php.sh.
t_pulizia() {
  local w prima dopo finta
  ws w
  soluzione "${w}"
  prima="$(cd "${w}" && git status --porcelain --ignored && find . -path \
    ./.git -prune -o -print | LC_ALL=C sort)"
  verifica "${w}"
  dopo="$(cd "${w}" && git status --porcelain --ignored && find . -path \
    ./.git -prune -o -print | LC_ALL=C sort)"
  if [[ "${prima}" == "${dopo}" ]]; then
    pass "la verifica non scrive nello spazio di lavoro"
  else
    fail "la verifica ha cambiato lo spazio di lavoro"
  fi
  # un file tracciato con la data cambiata e lo stesso contenuto: git diff
  # aggiornerebbe l'indice, la verifica no
  touch -d '2001-01-01' "${w}/${PROGETTO}/composer.json" || rotta "touch"
  prima="$(sha256sum "${w}/.git/index")"
  verifica "${w}"
  dopo="$(sha256sum "${w}/.git/index")"
  if [[ "${prima}" == "${dopo}" ]]; then
    pass "la verifica non aggiorna .git/index"
  else
    fail "la verifica ha riscritto .git/index"
  fi
  finta="$(mktemp -d "${TMP}/radice.XXXXXX")" || rotta "mktemp"
  if ! mkdir -p "${finta}/tools" \
      || ! cp "${PHP_FINTO}" "${finta}/tools/php.sh"; then
    rotta "la radice finta"
  fi
  ws w
  soluzione "${w}"
  fx "${w}" php_rotto
  run env PN_HANDSON_ROOT="${finta}" PN_CLAUDE_DIR="${CLAUDE_VUOTA}" \
    "${E03}/verifica.sh" "${w}"
  expect "il php.sh del repository, non quello dello spazio di lavoro" 0 \
    "${FINE}"
}

# Le precondizioni: uscita 2.
t_precondizioni() {
  local w
  verifica "${TMP}/non-esiste"
  expect "spazio di lavoro assente: 2" 2 "spazio di lavoro assente"
  w="$(mktemp -d "${TMP}/nogit.XXXXXX")" || rotta "mktemp"
  verifica "${w}"
  expect "senza git: 2" 2 "tools/prepara_esercizio.sh M4-E03"
  ws w
  rm -rf "${w:?}/${PROGETTO}"
  verifica "${w}"
  expect "senza il progetto: 2" 2 "manca ${PROGETTO}"
  ws w
  soluzione "${w}"
  rm -rf "${w:?}/${PROGETTO}/vendor"
  verifica "${w}"
  expect "test senza vendor/: 2, con il comando" 2 \
    "tools/php.sh composer install -d ${PROGETTO}"
  ws w
  soluzione "${w}"
  verifica "${w}" FINTO_PHP_ASSENTE=1
  expect "test senza PHP: 2" 2 "PHP non parte"
  ws w
  soluzione "${w}"
  run env PN_PHP_SH="${TMP}/nessun-php.sh" PN_CLAUDE_DIR="${CLAUDE_VUOTA}" \
    "${E03}/verifica.sh" "${w}"
  expect "senza php.sh: 2" 2 "manca tools/php.sh"
  ws w
  fx "${w}" senza_simula
  git -C "${w}" add -A > /dev/null 2>&1 || rotta "git add"
  git -C "${w}" -c user.name=prova -c user.email=prova@example.org \
    -c commit.gpgsign=false commit -q --amend --no-edit > /dev/null 2>&1 \
    || rotta "git commit --amend"
  soluzione "${w}"
  verifica "${w}"
  expect "un modulo che la verifica non sa rompere: 2" 2 "non sa rompere"
  ws w
  soluzione "${w}"
  chmod 000 "${w}/${DOC_REL}" || rotta "chmod"
  verifica "${w}"
  chmod 644 "${w}/${DOC_REL}" || rotta "chmod"
  expect "un errore inatteso (un file che non si legge): 2, mai 1" 2 \
    "errore inatteso"
  t_senza_strumenti
}

# verifica.sh senza python3 e senza git: uscita 2.
# Arguments: nessuno. Un PATH con i soli comandi elencati.
t_senza_strumenti() {
  local w bin t
  ws w
  bin="$(mktemp -d "${TMP}/bin.XXXXXX")" || rotta "mktemp"
  for t in bash env readlink dirname git; do
    ln -s "$(command -v "${t}")" "${bin}/${t}" || rotta "ln ${t}"
  done
  run env PATH="${bin}" "${E03}/verifica.sh" "${w}"
  expect "senza python3: 2" 2 "manca python3"
  rm -f "${bin}/git" || rotta "rm git"
  ln -s "$(command -v python3)" "${bin}/python3" || rotta "ln python3"
  run env PATH="${bin}" "${E03}/verifica.sh" "${w}"
  expect "senza git: 2" 2 "manca git"
}

# soluzione/: applica.sh e i file di riferimento.
t_soluzione() {
  local w log
  ws w
  log="${TMP}/php-applica.log"
  run env PN_PHP_SH="${PHP_FINTO}" FINTO_PHP_LOG="${log}" \
    "${SOL}/applica.sh" "${w}"
  expect "applica.sh: 0" 0 ""
  if [[ -f "${w}/${DOC_REL}" && -f "${w}/${TEST_REL}" \
      && -f "${w}/PROPOSTA.md" && -f "${w}/${PROGETTO}/vendor/bin/phpunit" ]]
  then
    pass "applica.sh: documentazione, test, proposta e dipendenze"
  else
    fail "applica.sh: manca qualcosa nello spazio di lavoro"
  fi
  : > "${log}"
  run env PN_PHP_SH="${PHP_FINTO}" FINTO_PHP_LOG="${log}" \
    "${SOL}/applica.sh" "${w}"
  if (( RC == 0 )) && ! grep -q composer "${log}"; then
    pass "applica.sh: con vendor/ non reinstalla"
  else
    fail "applica.sh: rc=${RC}, composer di nuovo: $(cat "${log}")"
  fi
  run env PN_PHP_SH="${PHP_FINTO}" "${SOL}/applica.sh" "${TMP}/non-esiste"
  expect "applica.sh senza spazio di lavoro: 2" 2 "spazio di lavoro assente"
  ws w
  run env PN_PHP_SH="${PHP_FINTO}" FINTO_COMPOSER=ko "${SOL}/applica.sh" \
    "${w}"
  expect "applica.sh con composer che fallisce: 2" 2 "composer"
  ws w
  rm -rf "${w:?}/${PROGETTO}/docs" || rotta "rm"
  : > "${w}/${PROGETTO}/docs" || rotta "docs"
  run env PN_PHP_SH="${PHP_FINTO}" "${SOL}/applica.sh" "${w}"
  expect "applica.sh: una copia che non riesce esce 2, mai 1" 2 \
    "la copia della soluzione non riesce"
  t_soluzione_file
}

# Il test e la documentazione di riferimento.
t_soluzione_file() {
  local t="${SOL}/${TEST_REL}" d="${SOL}/${DOC_REL}"
  if grep -q '^declare(strict_types=1);' "${t}" \
      && grep -q '^namespace CiaspoLink\\Gestionale\\Tests\\Integrazione;' \
        "${t}" \
      && grep -q '^final class ChiusuraMeseTest extends TestCase' "${t}" \
      && grep -q 'self::assert' "${t}" \
      && ! grep -qF "\$this->assert" "${t}"; then
    pass "il test di riferimento segue le convenzioni dei test"
  else
    fail "il test di riferimento non segue le convenzioni"
  fi
  if grep -q 'FINTO' "${t}" "${d}" "${SOL}/PROPOSTA.md"; then
    fail "un segno FINTO nella soluzione"
  else
    pass "nessun segno FINTO nella soluzione"
  fi
  if grep -qiE 'difett|\bbug\b|sbagliat|errat[oi]|\bD[1-9]\b' "${d}"; then
    fail "la documentazione di riferimento giudica il codice"
  else
    pass "la documentazione di riferimento descrive senza giudicare"
  fi
}

# Con PHP o Docker davvero: la soluzione, un test debole, il punto di
# partenza, run_all.sh.
t_php_vero() {
  local n
  if (( PHP_OK == 0 )); then
    for n in 1 2 3 4 5 6; do
      skip "con PHP vero (${n}): né PHP né Docker"
    done
    return 0
  fi
  local w w2
  ws w
  run "${SOL}/applica.sh" "${w}"
  expect "PHP vero: applica.sh installa le dipendenze" 0 ""
  run env PN_CLAUDE_DIR="${CLAUDE_VUOTA}" "${E03}/verifica.sh" "${w}"
  expect "PHP vero: la soluzione passa" 0 "${FINE}"
  expect "PHP vero: rossi sulla copia rotta" 0 \
    "sulla copia rotta apposta i test falliscono"
  ws w2
  cp -a "${w}/${PROGETTO}/vendor" "${w2}/${PROGETTO}/" || rotta "vendor"
  run env PN_CLAUDE_DIR="${CLAUDE_VUOTA}" "${E03}/verifica.sh" "${w2}"
  expect "PHP vero: il punto di partenza, 1" 1 \
    "nessun test di caratterizzazione"
  if ! cp -a "${SOL}/." "${w2}/" || ! rm -f "${w2}/applica.sh"; then
    rotta "la copia della soluzione"
  fi
  fx "${w2}" test_debole_vero
  run env PN_CLAUDE_DIR="${CLAUDE_VUOTA}" "${E03}/verifica.sh" "${w2}"
  expect "PHP vero: un test solo in simulazione non basta" 1 \
    "i test passano anche sulla copia rotta apposta"
  run "${RADICE}/tools/run_all.sh" M4-E03
  expect "PHP vero: tools/run_all.sh M4-E03" 0 "1 ok, 0 KO"
}

# live.sh con il claude finto. Arguments: $1 lo spazio di lavoro, poi le
# variabili d'ambiente (VAR=valore). Il registro in ${TMP}/live.log.
live() {
  local w="$1"
  shift
  : > "${TMP}/live.log"
  : > "${TMP}/live-php.log"
  run env PATH="${TMP}/finto:${PATH}" FINTO_LOG="${TMP}/live.log" \
    FINTO_PHP_LOG="${TMP}/live-php.log" PN_PHP_SH="${PHP_FINTO}" \
    PN_CLAUDE_DIR="${TMP}/claude-live" HANDSON_NO_PAUSE=1 \
    ANTHROPIC_API_KEY=prova-non-una-chiave "$@" \
    "${E03}/_docente/live.sh" "${w}"
}

# Le chiamate del registro del claude finto, in ${TMP}/chiamate.txt: una
# riga per chiamata, separati da tabulazioni il modo, la sessione ripresa,
# il prompt su una riga, gli strumenti, il resto delle opzioni (i prompt
# hanno «|», le tabulazioni no).
leggi_chiamate() {
  python3 -B -I - "${TMP}/live.log" > "${TMP}/chiamate.txt" <<'PY'
import json
import sys

for riga in open(sys.argv[1], encoding="utf-8"):
    d = json.loads(riga)
    a = d["argv"]
    if a == ["--version"]:
        continue
    i = a.index("--")
    opz = a[:i]

    def val(nome):
        return opz[opz.index(nome) + 1] if nome in opz else "-"

    altro = " ".join(x for x in ("--strict-mcp-config",) if x in opz)
    print("\t".join([val("--permission-mode"), val("--resume"),
                    " ".join(" ".join(a[i + 1:]).split()),
                    val("--allowedTools"),
                    "%s %s %s %s chiave=%s" % (val("--model"), val("--effort"),
                                               val("--output-format"), altro,
                                               d["chiave"])]))
PY
}

# live.sh: le precondizioni.
t_live_precondizioni() {
  local w
  live "${TMP}/non-esiste"
  expect "live: spazio di lavoro assente, 2" 2 "spazio di lavoro assente"
  ws w
  rm -f "${w}/.claude/settings.json"
  live "${w}"
  expect "live: senza impostazioni, 2" 2 ".claude/settings.json"
  ws w
  rm -f "${w}/tools/php.sh"
  live "${w}"
  expect "live: senza tools/php.sh, 2" 2 "tools/php.sh"
  if [[ ! -s "${TMP}/live.log" ]]; then
    pass "live: le precondizioni non chiamano claude"
  else
    fail "live: claude chiamato: $(cat "${TMP}/live.log")"
  fi
  ws w
  : > "${w}/NOTA.md"
  live "${w}"
  if (( RC == 2 )) && grep -qF "tools/reset_esercizio.sh M4-E03" \
      <<< "${OUT}" && [[ ! -s "${TMP}/live.log" ]]; then
    pass "live: git status non vuoto, 2 con il reset, senza claude"
  else
    fail "live: git status non vuoto (rc=${RC}): ${OUT:0:400}"
  fi
  ws w
  git -C "${w}" -c user.name=prova -c user.email=prova@example.org \
    -c commit.gpgsign=false commit -q --allow-empty -m "lavoro di prima" \
    > /dev/null 2>&1 || rotta "git commit"
  live "${w}"
  if (( RC == 2 )) && grep -qF "tools/reset_esercizio.sh M4-E03" \
      <<< "${OUT}" && [[ ! -s "${TMP}/live.log" ]]; then
    pass "live: un commit dopo il primo, 2 con il reset, senza claude"
  else
    fail "live: un commit dopo il primo (rc=${RC}): ${OUT:0:400}"
  fi
}

# live.sh: le due parti, le chiamate e le loro opzioni.
t_live() {
  local w n
  t_live_precondizioni
  ws w
  live "${w}"
  expect "live: 0, la verifica passa" 0 "VERIFICA OK"
  expect "live: i subagent come dato" 0 "chiamate Agent: 2 (Explore 2)"
  leggi_chiamate
  n="$(wc -l < "${TMP}/chiamate.txt")"
  if (( n == 6 )); then
    pass "live: sei chiamate"
  else
    fail "live: ${n} chiamate invece di sei"
  fi
  run cut -f 1,2 "${TMP}/chiamate.txt"
  local attese
  attese="$(printf '%s\t%s\n' dontAsk - dontAsk sessione-finta-1 \
    dontAsk sessione-finta-1 dontAsk sessione-finta-1 plan - \
    dontAsk sessione-finta-5)"
  if [[ "${OUT}" == "${attese}" ]]; then
    pass "live: due sessioni con --resume, plan mode solo per la proposta"
  else
    fail "live: modi e sessioni: ${OUT}"
  fi
  t_live_prompt
  run cut -f 4,5 "${TMP}/chiamate.txt"
  if [[ "$(sort -u <<< "${OUT}")" == "${STRUMENTI}${TAB}sonnet medium json \
--strict-mcp-config chiave=False" ]]; then
    pass "live: strumenti, modello, effort, json, niente MCP, chiave tolta"
  else
    fail "live: opzioni: $(sort -u <<< "${OUT}")"
  fi
  if grep -q '"composer"' "${TMP}/live-php.log" \
      && [[ -f "${w}/${PROGETTO}/vendor/bin/phpunit" ]]; then
    pass "live: installa le dipendenze del gestionale"
  else
    fail "live: le dipendenze non installate"
  fi
  if [[ -f "${w}.prova_dal_vivo/turno-6.json" && ! -e "${w}/prova_dal_vivo" ]]
  then
    pass "live: i JSON fuori dallo spazio di lavoro, accanto"
  else
    fail "live: prova_dal_vivo/ manca o è in git status"
  fi
  t_live_esiti
}

# live.sh: i prompt uguali a quelli del README, poi l'approvazione.
t_live_prompt() {
  local n atteso trovato
  for n in 1 2 3 4 5; do
    atteso="$(prompt_in_riga "${n}")"
    trovato="$(sed -n "${n}p" "${TMP}/chiamate.txt" | cut -f 3)"
    if [[ -n "${atteso}" && "${trovato}" == "${atteso% }" ]]; then
      pass "live: la chiamata ${n} è il prompt ${n} del README"
    else
      fail "live: chiamata ${n}: «${trovato:0:80}…»"
    fi
  done
  trovato="$(sed -n '6p' "${TMP}/chiamate.txt" | cut -f 3)"
  if [[ "${trovato}" == "${APPROVAZIONE}" ]]; then
    pass "live: la sesta chiamata approva il piano"
  else
    fail "live: chiamata 6: «${trovato}»"
  fi
}

# live.sh: i seguiti sui test e gli esiti diversi.
t_live_esiti() {
  local w
  ws w
  live "${w}" FINTO_E03_TEST=rosso
  expect "live: test rossi, poi corretti con un seguito: 0" 0 "VERIFICA OK"
  leggi_chiamate
  if grep -q 'Esegui di nuovo i test' "${TMP}/chiamate.txt" \
      && (( $(wc -l < "${TMP}/chiamate.txt") == 7 )); then
    pass "live: un seguito sui test, sette chiamate"
  else
    fail "live: seguiti: $(cut -f 3 "${TMP}/chiamate.txt")"
  fi
  ws w
  live "${w}" FINTO_E03_TEST=rosso FINTO_E03_MAI=1
  expect "live: test mai corretti, 1" 1 "i test non passano sul codice"
  leggi_chiamate
  if (( $(grep -c 'Esegui di nuovo i test' "${TMP}/chiamate.txt") == 2 ))
  then
    pass "live: al massimo due seguiti"
  else
    fail "live: seguiti: $(grep -c 'Esegui di nuovo' "${TMP}/chiamate.txt")"
  fi
  ws w
  live "${w}" FINTO_KO_ALLA=3
  expect "live: una chiamata fallita, 1" 1 "turno 3"
  ws w
  live "${w}" FINTO_E03_LEGACY=tocca
  expect "live: legacy/ toccato, 1" 1 "legacy/ è cambiato"
  ws w
  live "${w}" FINTO_E03_TEST=debole FINTO_E03_MAI=1
  expect "live: test deboli, mai sistemati, 1" 1 "anche sulla copia rotta"
  ws w
  live "${w}" FINTO_E03_DOC=senza_rischi
  expect "live: documentazione incompleta, sistemata dopo la verifica: 0" 0 \
    "VERIFICA OK"
  leggi_chiamate
  if (( $(wc -l < "${TMP}/chiamate.txt") == 7 )) && sed -n '7p' \
      "${TMP}/chiamate.txt" | cut -f 3 | grep -qF \
      "Non ancora: la documentazione non ha la sezione «Rischi»"; then
    pass "live: il turno di correzione porta le righe «Non ancora»"
  else
    fail "live: correzione: $(sed -n '7p' "${TMP}/chiamate.txt" | cut -f 3)"
  fi
  ws w
  live "${w}" FINTO_E03_AGENT=nessuno
  expect "live: nessun subagent, 0 (è un dato)" 0 "chiamate Agent: 0"
  local qui="${PWD}"
  ws w
  cd "${w%/*}" || rotta "cd"
  live "${w##*/}"
  cd "${qui}" || rotta "cd"
  expect "live: uno spazio di lavoro dato con un percorso relativo: 0" 0 \
    "VERIFICA OK"
}

# prepara_esercizio.sh, tools/verifica.sh e check_handson.sh con
# l'elemento vero.
t_strumenti() {
  if [[ -n "${MODELLO}" ]] \
      && cmp -s "${MODELLO}/.claude/settings.json" \
        "${E03}/esercizio/.claude/settings.json" \
      && [[ -x "${MODELLO}/tools/php.sh" \
        && ! -e "${MODELLO}/${PROGETTO}/_docente" ]] \
      && cmp -s "${MODELLO}/${MODULO_REL}" "${RADICE}/${MODULO_REL}"; then
    pass "prepara_esercizio.sh: impostazioni, php.sh, gestionale"
  else
    fail "prepara_esercizio.sh M4-E03: lo spazio di lavoro non è quello atteso"
  fi
  local radice
  radice="$(mktemp -d "${TMP}/radice.XXXXXX")" || rotta "mktemp"
  "${RADICE}/tools/prepara_esercizio.sh" M4-E03 --radice "${radice}" \
    > /dev/null 2>&1
  run env PN_CLAUDE_DIR="${CLAUDE_VUOTA}" "${RADICE}/tools/verifica.sh" \
    M4-E03 --radice "${radice}"
  expect "tools/verifica.sh M4-E03 sul punto di partenza: 1" 1 "NON ANCORA"
  run "${RADICE}/tools/check_handson.sh"
  if grep -q 'M4-E03' <<< "${OUT}"; then
    fail "check_handson.sh segnala M4-E03: $(grep 'M4-E03' <<< "${OUT}")"
  else
    pass "check_handson.sh: niente su M4-E03"
  fi
}

# Gli script passati a shellcheck; la sintassi dei file Python.
t_shellcheck() {
  local f
  local analizza='import ast, sys; ast.parse(open(sys.argv[1]).read())'
  for f in "${E03}/verifica.sh" "${SOL}/applica.sh" "${E03}/_docente/live.sh" \
      "${E03}/_docente/lib_prova_dal_vivo.sh" "${SELF}"; do
    run shellcheck -x "${f}"
    expect "shellcheck ${f##*/}" 0 ""
  done
  for f in "${E03}/verifica.py" "${PHP_FINTO}" "${CLAUDE_FINTO}"; do
    run python3 -B -I -c "${analizza}" "${f}"
    expect "la sintassi di ${f##*/}" 0 ""
  done
}

main() {
  handson::tmpdir TMP
  prepara
  t_file
  t_modulo
  t_readme
  if [[ -z "${MODELLO}" ]]; then
    fail "prepara_esercizio.sh M4-E03 non prepara lo spazio di lavoro"
  else
    t_partenza_soluzione
    t_documentazione
    t_proposta
    t_test
    t_legacy
    t_dati
    t_pulizia
    t_precondizioni
    t_soluzione
    t_php_vero
    t_live
  fi
  t_strumenti
  t_shellcheck
  local totale=$((PASS + FAIL + SKIP))
  echo "test_m4_e03: PASS=${PASS} FAIL=${FAIL} SKIP=${SKIP} (casi ${totale}" \
    "di ${CASES})"
  if (( totale != CASES )); then
    echo "test_m4_e03: eseguiti ${totale} casi invece di ${CASES}" >&2
    exit 2
  fi
  (( FAIL == 0 )) || exit 1
}

main "$@"
