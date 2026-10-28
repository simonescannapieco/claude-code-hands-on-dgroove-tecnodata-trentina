#!/bin/bash
#
# test_m4_e01.sh -- le prove di M4-E01 «Un file mai visto», per il docente:
#   - esercizio/tools/php.sh uguale byte per byte a tools/php.sh, e
#     eseguibile; le impostazioni dello spazio di lavoro (la regola allow
#     del comando dei test, le regole deny del repository più quella sulla
#     copia di php.sh, defaultMode default);
#   - il README: le dieci sezioni, i tre prompt fra i segni, il comando
#     esatto dei test, un comando per volta, nessuna richiesta di stile
#     nel prompt del test (l'affermazione si decide sul file), la citazione
#     e il suo link, nessun identificativo interno, niente macOS (salvo
#     nella frase su Glob e Grep, «su macOS, Linux e WSL») né Percorso A,
#     nessun riferimento all'orario; Manual che chiede per le scritture e
#     per i comandi che non sono di sola lettura, «di regola»;
#   - verifica.sh con un tools/php.sh finto (PN_PHP_SH): il punto di
#     partenza (1, senza bisogno di PHP), la spiegazione sola o vuota (1),
#     un test buono in un file cambiato o nuovo (0, «confermata»), un test
#     con $this->assert (0, «non confermata in questa esecuzione»), con il
#     namespace sbagliato, con il database fuori da tests/Integrazione, un
#     test rosso o che non si esegue (1), nessun metodo nuovo (1), la prova
#     del confine spostato come dato (sì, no, e «non provato» quando i
#     test non passano sulla copia senza la modifica), i file cambiati
#     fuori da tests/ come dato, i commit del partecipante; le
#     precondizioni (2): spazio di lavoro, git, progetto, strumento PHP,
#     vendor/, PHP che non si avvia, un errore inatteso (una riga su
#     stderr);
#   - soluzione/: applica.sh con il finto (0), e una copia che non riesce
#     (2); il test di riferimento aggiunge soltanto; la spiegazione in
#     dieci righe al massimo;
#   - con PHP o Docker davvero (altrimenti SKIP): partenza 1, soluzione 0
#     con «confermata» e il confine che cade, tools/run_all.sh M4-E01;
#   - _docente/live.sh con un claude finto: le precondizioni escono 2 senza
#     chiamare claude, anche uno spazio di lavoro che ha già del lavoro
#     (git status non vuoto, o un commit dopo il primo); i tre turni con
#     --resume, le opzioni (fra gli strumenti nessun grep né find: i
#     comandi di sola lettura girano senza chiedere), i prompt uguali a
#     quelli del README, la chiave tolta, una chiamata fallita, un test
#     mancante (1), le dipendenze installate, prova_dal_vivo/ fuori da
#     git status;
#   - prepara_esercizio.sh e tools/verifica.sh con l'elemento vero;
#   - shellcheck -x sugli script dell'elemento, sulla libreria dei live.sh
#     di M4-E01 e M4-E02 (lib_live_m4_e01_e02.sh) e su questo.
# Gli spazi di lavoro nascono in una cartella temporanea, nella base di
# handson::init_temp_base: l'albero del repository non cambia. Un numero di
# casi diverso da CASES esce 2.
#
# Uso:    m4_claude_code_agenti/_docente/test_m4_e01.sh
# Uscita: 0 = tutte le prove passano (uno SKIP non è un fallimento: è
#         contato e stampato) · 1 = almeno una fallita · 2 = precondizione
#         (manca python3, jq, git o shellcheck, un file dell'elemento; una
#         preparazione non riesce; le prove eseguite non sono quante attese)
set -uo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly MOD="${SELF%/_docente/*}"
readonly RADICE="${MOD%/*}"
readonly E01="${MOD}/s3_agente_nel_repository/m4_e1_un_file_mai_visto/\
M4-E01_file_mai_visto"
readonly PHP_FINTO="${MOD}/_docente/php_finto_m4_e01_e02.py"
readonly CLAUDE_FINTO="${MOD}/_docente/claude_finto_m4_e01_e02.py"
# shellcheck source=../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"
readonly CASES=88
readonly TEST_REL="progetti/gestionale-php/tests/Integrazione"
readonly COMANDO="tools/php.sh php progetti/gestionale-php/vendor/bin/phpunit \
-c progetti/gestionale-php"
readonly REGOLA="Bash(tools/php.sh php progetti/gestionale-php/vendor/bin/\
phpunit *)"
readonly FRASE="Claude examines your existing test files to match the \
style, frameworks, and assertion patterns already in use."
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
    fail "$1 (rc=${RC}, attesa $2, parola «$3»): ${OUT:0:700}"
  fi
}

# Nessun falso positivo: la parola NON c'è (RU-01.T5).
# Arguments: $1 il nome, $2 la parola.
expect_absent() {
  if grep -qF -- "$2" <<< "${OUT}"; then
    fail "$1: «$2» c'è: ${OUT:0:700}"
  else
    pass "$1"
  fi
}

# La preparazione di una prova che non riesce: uscita 2.
rotta() { echo "test_m4_e01: preparazione non riuscita: $*" >&2; exit 2; }

# Un nuovo spazio di lavoro, copia del modello preparato da
# prepara_esercizio.sh. Arguments: $1 la variabile da assegnare, $2
# «vendor» per aggiungere vendor/bin/phpunit (come composer install).
ws() {
  local __w
  __w="$(mktemp -d "${TMP}/ws.XXXXXX")" || rotta "mktemp"
  cp -a "${MODELLO}/." "${__w}/" || rotta "cp del modello"
  if [[ "${2:-}" == "vendor" ]]; then
    mkdir -p "${__w}/progetti/gestionale-php/vendor/bin" || rotta "vendor"
    : > "${__w}/progetti/gestionale-php/vendor/bin/phpunit" || rotta "vendor"
  fi
  printf -v "$1" '%s' "${__w}"
}

# La verifica dell'elemento con il php.sh finto.
# Arguments: $1 lo spazio di lavoro, poi variabili d'ambiente (VAR=valore).
verifica() {
  local w="$1"
  shift
  run env PN_PHP_SH="${PHP_FINTO}" "$@" "${E01}/verifica.sh" "${w}"
}

# La spiegazione finta nello spazio di lavoro. Arguments: $1 lo spazio.
spiegazione() {
  printf '%s\n' "VerificaCopertura dice se un indirizzo è coperto." \
    "La chiama CruscottoController per la pagina della copertura." \
    > "$1/spiegazione.md" || rotta "spiegazione.md"
}

# Un test di prova nello spazio di lavoro, con fx.py.
# Arguments: $1 lo spazio, $2 la variante (vedi fx.py).
fx() { python3 -B -I "${TMP}/fx.py" "$1" "$2" || rotta "fx $2"; }

# fx.py, il claude finto e il claude esca.
prepara() {
  local radice
  cat > "${TMP}/fx.py" <<'PY' || rotta "fx.py"
"""fx.py -- i test di prova di test_m4_e01.sh, scritti nello spazio di
lavoro. Il php.sh finto li giudica dai segni FINTO (non è PHP)."""
import os
import sys

ws, variante = sys.argv[1], sys.argv[2]
INT = os.path.join(ws, "progetti/gestionale-php/tests/Integrazione")
UNIT = os.path.join(ws, "progetti/gestionale-php/tests/Unit/Copertura")
ESISTENTE = os.path.join(INT, "VerificaCoperturaTest.php")
CONFINE = "FINTO-RICHIEDE: $riga['disponibile_dal'] <= $giorno"
METODO = '''
    public function testCopertoDalGiornoInCuiDiventaDisponibile(): void
    {
        // %s
        $esito = self::$verifica->verifica('Pergine Valsugana',
            "Via dell'Esempio", '12', '', new DateTimeImmutable(%s));

        %s($esito->coperto);
    }
'''
NUOVO = '''<?php

declare(strict_types=1);

namespace CiaspoLink\\Gestionale\\Tests\\%s;

use CiaspoLink\\Gestionale\\Tests\\Support\\DatabaseDiProva;
use DateTimeImmutable;
use PHPUnit\\Framework\\TestCase;

final class CoperturaDalGiornoTest extends TestCase
{
    public function testCopertoDalGiornoInCuiDiventaDisponibile(): void
    {
        // %s
        $pdo = DatabaseDiProva::conDati();
        self::assertNotNull($pdo);
    }
}
'''


def aggiungi(metodo):
    with open(ESISTENTE, encoding="utf-8") as fh:
        t = fh.read()
    fine = t.rstrip().rfind("}")
    with open(ESISTENTE, "w", encoding="utf-8") as fh:
        fh.write(t[:fine].rstrip("\n") + "\n" + metodo + "}\n")


def nuovo(cartella, ns, segno):
    os.makedirs(cartella, exist_ok=True)
    with open(os.path.join(cartella, "CoperturaDalGiornoTest.php"), "w",
              encoding="utf-8") as fh:
        fh.write(NUOVO % (ns, segno))


if variante == "buono":
    aggiungi(METODO % (CONFINE, "'2014-02-03'", "self::assertTrue"))
elif variante == "senza_confine":
    aggiungi(METODO % ("nessun segno", "'2014-02-03'", "self::assertTrue"))
elif variante == "stile":
    aggiungi(METODO % (CONFINE, "'2014-02-03'", "$this->assertTrue"))
elif variante == "oggi":
    aggiungi(METODO % (CONFINE, "", "self::assertTrue"))
elif variante == "rosso":
    aggiungi(METODO % ("FINTO: rosso", "'2014-02-03'", "self::assertTrue"))
elif variante == "rotto":
    aggiungi(METODO % ("FINTO: rotto", "'2014-02-03'", "self::assertTrue"))
elif variante == "richiede_src":
    # verde solo con un segno che il partecipante ha messo in src/
    aggiungi(METODO % ("FINTO-RICHIEDE: SEGNO-DELLO-SPAZIO-DI-LAVORO",
                       "'2014-02-03'", "self::assertTrue"))
elif variante == "commento":
    with open(ESISTENTE, "a", encoding="utf-8") as fh:
        fh.write("// solo un commento in fondo\n")
elif variante == "nuovo":
    nuovo(INT, "Integrazione", CONFINE)
elif variante == "namespace":
    nuovo(UNIT, "Integrazione", CONFINE)
elif variante == "unit_db":
    nuovo(UNIT, "Unit\\Copertura", CONFINE)
else:
    sys.exit(2)
PY
  mkdir -p "${TMP}/finto" "${TMP}/esca" || rotta "mkdir"
  cp "${CLAUDE_FINTO}" "${TMP}/finto/claude" || rotta "il claude finto"
  # shellcheck disable=SC2016  # il corpo è dell'esca
  printf '%s\n' '#!/bin/bash' 'echo "chiamata $*" >> "${ESCA_LOG}"' \
    'exit 1' > "${TMP}/esca/claude" || rotta "il claude esca"
  chmod 755 "${TMP}/finto/claude" "${TMP}/esca/claude" || rotta "chmod"
  radice="$(mktemp -d "${TMP}/radice.XXXXXX")" || rotta "mktemp"
  "${RADICE}/tools/prepara_esercizio.sh" M4-E01 --radice "${radice}" \
    > /dev/null 2>&1 || rotta "prepara_esercizio.sh M4-E01"
  MODELLO="${radice}/M4-E01"
  if command -v php > /dev/null 2>&1 \
      || { command -v docker > /dev/null 2>&1 \
        && docker info > /dev/null 2>&1; }; then
    PHP_OK=1
  fi
}

# La copia di tools/php.sh e le impostazioni.
t_copie() {
  if cmp -s "${E01}/esercizio/tools/php.sh" "${RADICE}/tools/php.sh"; then
    pass "esercizio/tools/php.sh è tools/php.sh, byte per byte"
  else
    fail "esercizio/tools/php.sh diverso da tools/php.sh"
  fi
  if [[ -x "${E01}/esercizio/tools/php.sh" ]]; then
    pass "esercizio/tools/php.sh eseguibile"
  else
    fail "esercizio/tools/php.sh senza il bit di esecuzione"
  fi
  run python3 -B -I - "${E01}/esercizio/.claude/settings.json" \
    "${RADICE}/.claude/settings.json" "${REGOLA}" <<'PY'
import json
import sys

e = json.load(open(sys.argv[1], encoding="utf-8"))["permissions"]
r = json.load(open(sys.argv[2], encoding="utf-8"))["permissions"]
print("allow %s" % ("ok" if e.get("allow") == [sys.argv[3]] else "diverso"))
print("deny %s" % ("ok" if e.get("deny") == r["deny"] + [
    "Edit(/tools/php.sh)"] else "diverso"))
print("modo %s" % ("ok" if e.get("defaultMode") == "default" else "diverso"))
PY
  expect "settings: allow, solo il comando dei test" 0 "allow ok"
  expect "settings: deny del repository e della copia di php.sh" 0 "deny ok"
  expect "settings: defaultMode default (Manual)" 0 "modo ok"
  run python3 -B -I - "${E01}/esercizio/.claude/settings.json" \
    "${E01}/README.md" <<'PY'
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
}

# Il README: i prompt (in ${TMP}/prompt-<n>.txt), le sezioni, le citazioni.
t_readme() {
  local f trovati=''
  run python3 -B -I - "${E01}/README.md" "${TMP}" "${COMANDO}" \
    "${FRASE}" <<'PY'
import os
import sys
import textwrap

testo = open(sys.argv[1], encoding="utf-8").read()
righe = testo.split("\n")
for n in (1, 2, 3):
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
uno = lambda n: " ".join(open(os.path.join(sys.argv[2], "prompt-%d.txt" % n),
                              encoding="utf-8").read().split())
if sys.argv[3] in uno(2):
    print("comando ok")
if "da solo, senza concatenarlo ad altri" in uno(2):
    print("un comando per volta ok")
if not any(p in uno(2).lower() for p in ("stile", "come i test",
                                         "convenzion")):
    print("nessuna richiesta di stile ok")
if uno(3) == "Mostrami il comando che hai eseguito e il suo output.":
    print("prove ok")
if sys.argv[4] in " ".join(testo.split()) and \
        "https://code.claude.com/docs/en/common-workflows" in testo:
    print("citazione ok")
if "tools/php.sh composer install -d progetti/gestionale-php" in testo:
    print("installazione ok")
sezioni = ("Obiettivo", "Tempo", "Prerequisiti", "Punto di partenza",
           "Passi in Claude Code", "Che cosa osservare", "Verifica",
           "Se qualcosa va storto", "Impronta d'uso sul piano Pro",
           "Per approfondire")
if all(any(r.startswith("## " + s) for r in righe) for s in sezioni):
    print("sezioni ok")
PY
  expect "README: le dieci sezioni" 0 "sezioni ok"
  expect "README: il prompt 1 fra i segni" 0 "prompt 1 ok"
  expect "README: il prompt 2 fra i segni" 0 "prompt 2 ok"
  expect "README: il prompt 3 fra i segni" 0 "prompt 3 ok"
  expect "README: il prompt 2 nomina il comando dei test" 0 "comando ok"
  expect "README: il prompt 2 chiede un comando per volta" 0 \
    "un comando per volta ok"
  expect "README: il prompt 2 non chiede lo stile dei test" 0 \
    "nessuna richiesta di stile ok"
  expect "README: il prompt 3 chiede le prove" 0 "prove ok"
  expect "README: la frase della guida e il suo link" 0 "citazione ok"
  expect "README: l'installazione dalla radice dello spazio" 0 \
    "installazione ok"
  OUT="$(cat "${E01}/README.md")"
  expect_absent "README: nessun Percorso A" "Percorso A"
  run python3 -B -I - "${E01}/README.md" <<'PY'
import sys

piatto = " ".join(open(sys.argv[1], encoding="utf-8").read().split())
fatto = "macOS, Linux e WSL"
print("glob ok" if "Su %s Claude Code lascia Glob e Grep" % fatto in piatto
      else "glob: manca «Su %s …»" % fatto)
print("macos ok" if "macOS" not in piatto.replace(fatto, "") else
      "macOS fuori dalla frase su Glob e Grep")
manual = ("non è di sola lettura" in piatto and "di regola" in piatto
          and "per ogni azione" not in piatto)
print("manual ok" if manual else
      "manual: «per ogni azione», o niente «di regola»")
PY
  expect "README: Glob e Grep fuori, su macOS, Linux e WSL" 0 "glob ok"
  expect "README: macOS solo nella frase su Glob e Grep" 0 "macos ok"
  expect "README: Manual chiede per ciò che non è di sola lettura" 0 \
    "manual ok"
  if grep -qiE '\boggi\b|prossima sessione|pausa|pranzo' "${E01}/README.md"
  then
    fail "README: un riferimento all'orario"
  else
    pass "README: nessun riferimento all'orario"
  fi
  for f in README.md verifica.sh verifica.py esercizio/.claude/settings.json; do
    if grep -qE -- "${INTERNI}" "${E01}/${f}"; then
      trovati+=" ${f}"
    fi
  done
  if [[ -z "${trovati}" ]]; then
    pass "nessun identificativo interno nei file per i partecipanti"
  else
    fail "identificativi interni in:${trovati}"
  fi
}

# verifica.sh con il php.sh finto: ciò che manca e i test.
t_verifica() {
  local w
  ws w
  verifica "${w}"
  expect "partenza: esce 1" 1 "Non ancora:"
  expect "partenza: manca la spiegazione" 1 "manca spiegazione.md"
  expect "partenza: nessun test" 1 "nessun test nuovo o cambiato"
  verifica "${w}" PN_PHP_SH="${TMP}/non-esiste"
  expect "partenza: senza PHP esce comunque 1, non 2" 1 "Non ancora:"
  ws w
  spiegazione "${w}"
  verifica "${w}"
  expect "solo la spiegazione: 1" 1 "nessun test nuovo o cambiato"
  expect "la spiegazione stampata come dato" 1 \
    "  | La chiama CruscottoController"
  ws w vendor
  : > "${w}/spiegazione.md"
  fx "${w}" buono
  verifica "${w}"
  expect "spiegazione vuota: 1" 1 "spiegazione.md è vuota"
  ws w vendor
  spiegazione "${w}"
  fx "${w}" buono
  verifica "${w}"
  expect "test buono in un file cambiato: 0" 0 "Fatto:"
  expect "test buono: l'affermazione confermata" 0 \
    "decisa sul file del test: confermata"
  expect_absent "test buono: nessun «non confermata»" "non confermata"
  expect "test buono: il file è cambiato" 0 \
    "VerificaCoperturaTest.php (cambiato)"
  expect "test buono: il confine spostato lo fa cadere (dato)" 0 \
    "si sposta di un giorno: sì"
  expect "test buono: nessun file cambiato fuori da tests/" 0 \
    "fuori da tests/ e da spiegazione.md: nessuno"
  ws w vendor
  spiegazione "${w}"
  fx "${w}" nuovo
  verifica "${w}"
  expect "test in un file nuovo: 0 e confermata" 0 \
    "decisa sul file del test: confermata"
  expect "test in un file nuovo: (nuovo)" 0 "CoperturaDalGiornoTest.php (nuovo)"
  ws w vendor
  spiegazione "${w}"
  fx "${w}" stile
  verifica "${w}"
  expect "\$this->assert: l'uscita resta 0" 0 "Fatto:"
  expect "\$this->assert: non confermata in questa esecuzione" 0 \
    "non confermata in questa esecuzione"
  ws w vendor
  spiegazione "${w}"
  fx "${w}" namespace
  verifica "${w}"
  expect "namespace diverso dalla cartella: non confermata" 0 \
    "non confermata in questa esecuzione"
  ws w vendor
  spiegazione "${w}"
  fx "${w}" unit_db
  verifica "${w}"
  expect "database in tests/Unit: non confermata" 0 \
    "non confermata in questa esecuzione"
  ws w vendor
  spiegazione "${w}"
  fx "${w}" oggi
  verifica "${w}"
  expect "la data di oggi: un dato, l'affermazione resta confermata" 0 \
    "decisa sul file del test: confermata"
}

# verifica.sh: test rossi, non eseguibili, senza metodo; i dati.
t_verifica_test() {
  local w
  ws w vendor
  spiegazione "${w}"
  fx "${w}" rosso
  verifica "${w}"
  expect "test rosso: 1" 1 "il test non passa"
  ws w vendor
  spiegazione "${w}"
  fx "${w}" rotto
  verifica "${w}"
  expect "test che non si esegue: 1" 1 "il test non si esegue"
  ws w vendor
  spiegazione "${w}"
  fx "${w}" commento
  verifica "${w}"
  expect "nessun metodo di test nuovo: 1" 1 "nessun metodo di test nuovo"
  ws w vendor
  spiegazione "${w}"
  fx "${w}" senza_confine
  verifica "${w}"
  expect "un test che non prova il confine: 0, il dato dice no" 0 \
    "si sposta di un giorno: no"
  ws w vendor
  spiegazione "${w}"
  fx "${w}" richiede_src
  printf '// SEGNO-DELLO-SPAZIO-DI-LAVORO\n' \
    >> "${w}/progetti/gestionale-php/src/Copertura/VerificaCopertura.php"
  verifica "${w}"
  expect "test verde solo con src/ cambiato: il confine non provato" 0 \
    "si sposta di un giorno: non provato"
  expect_absent "test verde solo con src/ cambiato: mai «sì»" \
    "si sposta di un giorno: sì"
  ws w vendor
  spiegazione "${w}"
  fx "${w}" buono
  printf '// una modifica\n' \
    >> "${w}/progetti/gestionale-php/src/Copertura/VerificaCopertura.php"
  verifica "${w}"
  expect "un file di src/ cambiato: elencato come dato" 0 \
    "src/Copertura/VerificaCopertura.php"
  ws w vendor
  spiegazione "${w}"
  fx "${w}" buono
  git -C "${w}" add -A > /dev/null 2>&1 || rotta "git add"
  git -C "${w}" -c user.name=Prova -c user.email=prova@example.org \
    commit -qm "test: il caso limite" || rotta "git commit"
  verifica "${w}"
  expect "il lavoro già nei commit conta: 0" 0 "Fatto:"
}

# Le precondizioni di verifica.sh: uscita 2.
t_verifica_precondizioni() {
  local w err rc=0
  verifica "${TMP}/non-esiste"
  expect "spazio di lavoro assente: 2" 2 "spazio di lavoro assente"
  run "${E01}/verifica.sh"
  expect "senza argomenti: 2" 2 "spazio di lavoro assente"
  w="$(mktemp -d "${TMP}/nogit.XXXXXX")" || rotta "mktemp"
  verifica "${w}"
  expect "una cartella che non è uno spazio di lavoro: 2" 2 \
    "non è uno spazio di lavoro preparato"
  ws w
  rm -rf "${w}/progetti/gestionale-php" || rotta "rm"
  verifica "${w}"
  expect "senza il gestionale: 2" 2 "manca progetti/gestionale-php"
  ws w vendor
  spiegazione "${w}"
  fx "${w}" buono
  verifica "${w}" PN_PHP_SH="${TMP}/non-esiste"
  expect "un test e nessuno strumento PHP: 2" 2 "manca lo strumento per PHP"
  ws w
  spiegazione "${w}"
  fx "${w}" buono
  verifica "${w}"
  expect "un test e niente vendor/: 2 con il rimedio" 2 \
    "tools/php.sh composer install -d progetti/gestionale-php"
  ws w vendor
  spiegazione "${w}"
  fx "${w}" buono
  verifica "${w}" FINTO_PHP_ASSENTE=1
  expect "PHP che non si avvia: 2" 2 "PHP non si avvia"
  ws w
  spiegazione "${w}"
  chmod 000 "${w}/spiegazione.md" || rotta "chmod"
  if [[ -r "${w}/spiegazione.md" ]]; then
    skip "un errore inatteso: 2 (un file 000 resta leggibile, da root)"
  else
    err="$(env PN_PHP_SH="${PHP_FINTO}" "${E01}/verifica.sh" "${w}" \
      2>&1 > /dev/null)" || rc=$?
    if (( rc == 2 )) && grep -qF "errore inatteso" <<< "${err}" \
        && (( $(wc -l <<< "${err}") == 1 )); then
      pass "un errore inatteso: 2, una riga su stderr"
    else
      fail "un errore inatteso (rc=${rc}): ${err:0:600}"
    fi
  fi
  chmod 644 "${w}/spiegazione.md" || rotta "chmod"
}

# soluzione/ con il finto.
t_soluzione() {
  local w
  ws w
  run env PN_PHP_SH="${PHP_FINTO}" PN_HANDSON_ROOT="${RADICE}" \
    "${E01}/soluzione/applica.sh" "${w}"
  expect "applica.sh con il finto: 0" 0 "Generating autoload files"
  verifica "${w}"
  expect "la soluzione: verifica 0" 0 "Fatto:"
  expect "la soluzione: confermata" 0 "decisa sul file del test: confermata"
  run python3 -B -I - "${MODELLO}/${TEST_REL}/VerificaCoperturaTest.php" \
    "${E01}/soluzione/${TEST_REL}/VerificaCoperturaTest.php" <<'PY'
import difflib
import sys

a = open(sys.argv[1], encoding="utf-8").read().splitlines()
b = open(sys.argv[2], encoding="utf-8").read().splitlines()
tolte = [r for r in difflib.ndiff(a, b) if r.startswith("- ")]
nuovi = [r for r in b if r.strip().startswith("public function test")
         and r not in a]
print("aggiunge soltanto" if not tolte and nuovi else "toglie: %s" % tolte)
PY
  expect "soluzione: il test aggiunge metodi senza togliere righe" 0 \
    "aggiunge soltanto"
  run python3 -B -I - "${E01}/soluzione/spiegazione.md" <<'PY'
import sys

righe = [r for r in open(sys.argv[1], encoding="utf-8").read().splitlines()
         if r.strip()]
chi = all(p in " ".join(righe) for p in ("CruscottoController",
                                          "Applicazione"))
print("spiegazione ok" if 0 < len(righe) <= 10 and chi else
      "spiegazione: %d righe, chiamanti %s" % (len(righe), chi))
PY
  expect "soluzione: spiegazione in dieci righe, con chi la chiama" 0 \
    "spiegazione ok"
  ws w vendor
  rm -f "${w}/${TEST_REL}/VerificaCoperturaTest.php" || rotta "rm"
  mkdir "${w}/${TEST_REL}/VerificaCoperturaTest.php" || rotta "mkdir"
  run env PN_PHP_SH="${PHP_FINTO}" "${E01}/soluzione/applica.sh" "${w}"
  expect "applica.sh: una copia che non riesce esce 2, mai 1" 2 \
    "la copia della soluzione non riesce"
}

# Con PHP o Docker davvero: la partenza, la soluzione, run_all.
t_reale() {
  local radice w
  if (( PHP_OK == 0 )); then
    skip "PHP reale: partenza (né PHP né Docker)"
    skip "PHP reale: soluzione (né PHP né Docker)"
    skip "PHP reale: il confine (né PHP né Docker)"
    skip "PHP reale: run_all (né PHP né Docker)"
    return 0
  fi
  radice="$(mktemp -d "${TMP}/reale.XXXXXX")" || rotta "mktemp"
  "${RADICE}/tools/prepara_esercizio.sh" M4-E01 --radice "${radice}" \
    > /dev/null 2>&1 || rotta "prepara_esercizio.sh"
  w="${radice}/M4-E01"
  run env PN_HANDSON_ROOT="${RADICE}" "${E01}/verifica.sh" "${w}"
  expect "PHP reale: partenza 1" 1 "Non ancora:"
  ( cd "${w}" && PN_HANDSON_ROOT="${RADICE}" \
      "${E01}/soluzione/applica.sh" "${w}" ) > /dev/null 2>&1 \
    || rotta "applica.sh con PHP reale"
  run env PN_HANDSON_ROOT="${RADICE}" "${E01}/verifica.sh" "${w}"
  expect "PHP reale: soluzione 0, confermata" 0 \
    "decisa sul file del test: confermata"
  expect "PHP reale: il confine spostato fa cadere il test" 0 \
    "si sposta di un giorno: sì"
  run "${RADICE}/tools/run_all.sh" M4-E01
  expect "PHP reale: tools/run_all.sh M4-E01" 0 "ESITO: OK"
}

# live.sh con il claude finto in testa al PATH.
# Arguments: $1 lo spazio di lavoro, poi variabili d'ambiente.
live_finto() {
  local w="$1"
  shift
  : > "${TMP}/finto.log"
  : > "${TMP}/php.log"
  run env "$@" PATH="${TMP}/finto:${PATH}" HANDSON_NO_PAUSE=1 \
    FINTO_LOG="${TMP}/finto.log" PN_PHP_SH="${PHP_FINTO}" \
    FINTO_PHP_LOG="${TMP}/php.log" "${E01}/_docente/live.sh" "${w}"
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
    HANDSON_NO_PAUSE=1 "${E01}/_docente/live.sh" "$3"
  if (( RC == 2 )) && grep -qF -- "$2" <<< "${OUT}" \
      && [[ ! -s "${TMP}/esca.log" ]]; then
    pass "$1"
  else
    fail "$1 (rc=${RC}): ${OUT:0:400}"
  fi
}

t_live() {
  local w
  senza_chiamate "live.sh: spazio di lavoro assente esce 2" \
    "spazio di lavoro assente" "${TMP}/non-esiste"
  ws w
  rm "${w}/tools/php.sh" || rotta "rm"
  senza_chiamate "live.sh: senza tools/php.sh esce 2" "tools/php.sh" "${w}"
  ws w
  spiegazione "${w}"
  senza_chiamate "live.sh: git status non vuoto esce 2, con il reset" \
    "tools/reset_esercizio.sh M4-E01" "${w}"
  ws w
  git -C "${w}" -c user.name=Prova -c user.email=prova@example.org \
    commit -q --allow-empty -m "lavoro di prima" || rotta "git commit"
  senza_chiamate "live.sh: un commit dopo il primo esce 2, con il reset" \
    "tools/reset_esercizio.sh M4-E01" "${w}"
  ws w
  live_finto "${w}"
  expect "live.sh: tre turni e la verifica, esce 0" 0 \
    "VERIFICA OK   verifica.sh dell'elemento"
  expect_chiamate "live.sh: tre chiamate" 3
  run python3 -B -I - "${TMP}/finto.log" "${REGOLA}" "${TMP}" <<'PY'
import json
import os
import sys

righe = [json.loads(r) for r in open(sys.argv[1], encoding="utf-8")]
attese = {"--model": "sonnet", "--effort": "medium",
          "--allowedTools": "Read,Write,Edit,%s" % sys.argv[2],
          "--permission-mode": "dontAsk", "--permission-prompts": "none",
          "--output-format": "json", "--setting-sources": "project,local"}
ok = True
for n, r in enumerate(righe, 1):
    a = r["argv"]
    coppie = {a[i]: a[i + 1] for i in range(len(a) - 1)}
    ok &= all(coppie.get(k) == v for k, v in attese.items())
    ok &= "--strict-mcp-config" in a and "-p" in a
    ok &= (coppie.get("--resume") == "sessione-finta-1") == (n > 1)
    prompt = open(os.path.join(sys.argv[3], "prompt-%d.txt" % n),
                  encoding="utf-8").read()
    ok &= a[-1] == prompt and a[-2] == "--"
    ok &= not r["chiave"]
print("opzioni ok" if ok else "opzioni diverse: %s" % righe)
PY
  expect "live.sh: modello, effort, strumenti, --resume, prompt del README" \
    0 "opzioni ok"
  if grep -qF '"composer", "install", "-d", "progetti/gestionale-php"' \
      "${TMP}/php.log"; then
    pass "live.sh: installa le dipendenze come il partecipante"
  else
    fail "live.sh: niente composer install -d progetti/gestionale-php"
  fi
  run env PN_PHP_SH="${PHP_FINTO}" "${E01}/verifica.sh" "${w}"
  expect "live.sh: prova_dal_vivo/ fuori da git status" 0 \
    "fuori da tests/ e da spiegazione.md: nessuno"
  ws w
  live_finto "${w}" ANTHROPIC_API_KEY=chiave-finta
  if grep -qF '"chiave": true' "${TMP}/finto.log"; then
    fail "live.sh: ANTHROPIC_API_KEY arriva a claude"
  else
    pass "live.sh: ANTHROPIC_API_KEY tolta, claude usa l'abbonamento"
  fi
  ws w
  live_finto "${w}" FINTO_ESITO=ko
  expect "live.sh: una chiamata fallita esce 1" 1 \
    "il turno 1 non ha dato una risposta"
  ws w
  live_finto "${w}" FINTO_E01_TEST=no
  expect "live.sh: nessun test scritto, la verifica dice KO" 1 "VERIFICA KO"
}

# Gli strumenti del repository: prepara_esercizio.sh e verifica.sh.
t_integrazione() {
  local radice
  radice="$(mktemp -d "${TMP}/radice.XXXXXX")" || rotta "mktemp"
  run "${RADICE}/tools/prepara_esercizio.sh" M4-E01 --radice "${radice}"
  expect "prepara_esercizio.sh M4-E01" 0 "Spazio di lavoro pronto"
  if [[ -x "${radice}/M4-E01/tools/php.sh" \
      && -f "${radice}/M4-E01/progetti/gestionale-php/src/Copertura/\
VerificaCopertura.php" \
      && ! -e "${radice}/M4-E01/progetti/gestionale-php/_docente" \
      && ! -e "${radice}/M4-E01/spiegazione.md" ]] \
      && grep -qF "Edit(/tools/php.sh)" \
        "${radice}/M4-E01/.claude/settings.json"; then
    pass "lo spazio di lavoro: gestionale, tools/php.sh, le impostazioni"
  else
    fail "lo spazio di lavoro non è il punto di partenza"
  fi
  run "${RADICE}/tools/verifica.sh" M4-E01 --radice "${radice}"
  expect "tools/verifica.sh sul punto di partenza esce 1" 1 "NON ANCORA"
}

t_shellcheck() {
  local f
  for f in "${E01}/verifica.sh" "${E01}/_docente/live.sh" \
      "${E01}/soluzione/applica.sh" "${MOD}/_docente/lib_live_m4_e01_e02.sh" \
      "${SELF}"; do
    if (cd "${RADICE}" && shellcheck -x "${f}") > /dev/null 2>&1; then
      pass "shellcheck ${f#"${RADICE}"/}"
    else
      fail "shellcheck ${f#"${RADICE}"/}"
    fi
  done
}

main() {
  local t
  for t in python3 jq git shellcheck; do
    command -v "${t}" > /dev/null 2>&1 \
      || { echo "test_m4_e01: manca ${t}" >&2; exit 2; }
  done
  for t in README.md progetti.txt verifica.sh verifica.py \
      esercizio/tools/php.sh esercizio/.claude/settings.json \
      soluzione/applica.sh soluzione/spiegazione.md \
      "soluzione/${TEST_REL}/VerificaCoperturaTest.php" _docente/live.sh; do
    [[ -e "${E01}/${t}" ]] || { echo "test_m4_e01: manca ${t}" >&2; exit 2; }
  done
  for t in "${PHP_FINTO}" "${CLAUDE_FINTO}"; do
    [[ -x "${t}" ]] || { echo "test_m4_e01: manca ${t}" >&2; exit 2; }
  done
  handson::init_temp_base
  TMP="$(mktemp -d "${HANDSON_TEMP_BASE}/test_m4_e01.XXXXXX")" || exit 2
  trap 'rm -rf "${TMP}"' EXIT
  prepara
  t_copie
  t_readme
  t_verifica
  t_verifica_test
  t_verifica_precondizioni
  t_soluzione
  t_reale
  t_live
  t_integrazione
  t_shellcheck
  echo "PASS=${PASS} FAIL=${FAIL} SKIP=${SKIP}" \
    "CASES=$((PASS + FAIL + SKIP))/${CASES}"
  if (( PASS + FAIL + SKIP != CASES )); then
    echo "test_m4_e01: eseguite $((PASS + FAIL + SKIP)) prove, attese" \
      "${CASES}: un caso manca o non è contato" >&2
    exit 2
  fi
  (( FAIL == 0 )) || exit 1
}

main "$@"
