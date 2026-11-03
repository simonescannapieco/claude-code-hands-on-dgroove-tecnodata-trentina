#!/bin/bash
#
# test_m5_e02.sh -- le prove di M5-E02 «Una skill di revisione contro le
# convenzioni del team» e della libreria del laboratorio, _docente/
# lib_lab_m5.sh, per il docente:
#   - l'elemento: i file, le copie byte per byte (i casi di prova, il controllo
#     e il suo lettore), le regole deny, prove/config;
#   - lo spazio di lavoro di prepara_esercizio.sh: che cosa c'è, che cosa non
#     c'è (prove/, verita.json, soluzione/, _docente/); la verifica sul punto
#     di partenza (1);
#   - prove/prima.sh e i tre pull request, applicati su uno spazio di lavoro
#     appena preparato; i suoi rifiuti (2);
#   - _docente/verita.py: la chiave contro i pull request, le convenzioni e
#     verita.json; i suoi rifiuti;
#   - i giudici di verifica.py su stream scritti qui, buoni, cattivi e mancanti;
#     i dati che non decidono l'uscita; le precondizioni (2, mai un traceback);
#   - il ciclo del README con tools/prove_skill.sh e il claude finto, undici
#     chiamate; le garanzie che non reggono (1);
#   - la libreria: _docente/live.sh da capo a fondo, la bozza fuori da .claude,
#     dove il finto rifiuta di scrivere, come il claude vero; i suoi rifiuti (2,
#     nessuna chiamata); una chiamata fallita (1);
#   - feedback_docente.py;
#   - il README: le dieci sezioni, i prompt, le frasi di Anthropic con il loro
#     indirizzo, nessun nome interno;
#   - shellcheck -x, tools/check_handson.sh, la sintassi di Python 3.8.
# Mai il claude vero: il finto sta davanti nel PATH, e la suite lo controlla
# prima di usarlo. Gli stream del finto e quelli scritti qui non sono risposte
# di Claude: provano il controllo, non il modello. Gli spazi di lavoro nascono
# in una cartella temporanea, nella base di handson::init_temp_base (mai dentro
# ~/.claude): l'albero del repository non cambia. CASES è il numero dei casi: se
# ne girano di più o di meno la suite esce 2.
#
# Uso:    m5_skills/_docente/test_m5_e02.sh
# Uscita: 0 = tutti i casi passano · 1 = almeno un caso fallito · 2 =
#         precondizione (manca python3, git o shellcheck; il finto non viene
#         prima nel PATH), o un numero di casi diverso da CASES
# shellcheck disable=SC2016  # backtick e $ sono il testo delle prove
set -uo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly MOD="${SELF%/_docente/*}"
readonly RADICE="${MOD%/*}"
readonly ITEM="${MOD}/s4_skills/m5_e2_laboratorio/M5-E02_revisione_pr"
readonly LIB="${MOD}/_docente/lib_lab_m5.sh"
readonly FEEDBACK="${MOD}/_docente/feedback_docente.py"
readonly FINTO_PY="${MOD}/_docente/claude_finto_m5_e02.py"
readonly ESEMPIO="${RADICE}/riferimenti/skill-di-esempio/revisione-pr"
readonly ID=M5-E02
readonly SKILL=revisione-pr
readonly PERCORSO_SKILL=".claude/skills/${SKILL}"
readonly CASES=306
# shellcheck source=../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"
# Gli identificativi interni che i file per i partecipanti non portano.
INTERNI='FACT-|Tecnodata|[Tt]riage|M[0-9]-X[0-9]|\bX-[0-9]'
INTERNI+='|\b(ASK|OQ|DEC|TD|PQ)-[0-9]|\bB#[0-9]'
readonly INTERNI
TMP=''
RAD=''
WS=''
G_WS=''
PASS=0
FAIL=0
RC=0
OUT=''
N_RAD=0

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

# Esegue un comando; RC e OUT (STDOUT e STDERR insieme) per expect. Lo STDIN è
# /dev/null (main lo apre), salvo un here-doc dato a run.
run() { OUT="$("$@" 2>&1)"; RC=$?; }

# Uscita attesa E parole attese (RU-01.T3); mai un traceback.
# Arguments: $1 il nome, $2 l'uscita attesa, poi le parole (grep -F).
expect() {
  local nome="$1" atteso="$2" parola
  shift 2
  if (( RC != atteso )); then
    fail "${nome} (uscita ${RC}, attesa ${atteso}): ${OUT:0:900}"
    return 0
  fi
  if grep -qF -- 'Traceback' <<< "${OUT}"; then
    fail "${nome} (un traceback): ${OUT:0:900}"
    return 0
  fi
  for parola in "$@"; do
    if ! grep -qF -- "${parola}" <<< "${OUT}"; then
      fail "${nome} (manca «${parola}»): ${OUT:0:900}"
      return 0
    fi
  done
  pass "${nome}"
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

# Un caso vero o falso. Arguments: $1 il nome, poi il comando.
ok_se() {
  local nome="$1"
  shift
  if "$@" > /dev/null 2>&1; then
    pass "${nome}"
  else
    fail "${nome}"
  fi
}

# Le cartelle temporanee e il claude finto nel PATH.
# Globals: TMP (assegnata), PATH, FINTO_LOG, FINTO_CHIAVE (esportate).
prepara_ambiente() {
  local t
  for t in python3 git shellcheck; do
    command -v "${t}" > /dev/null 2>&1 || {
      echo "test_m5_e02: manca ${t}" >&2
      exit 2
    }
  done
  handson::init_temp_base
  TMP="$(mktemp -d "${HANDSON_TEMP_BASE}/test_m5_e02.XXXXXX")" || {
    echo "test_m5_e02: mktemp non riesce" >&2
    exit 2
  }
  trap 'rm -rf "${TMP}"' EXIT
  mkdir -p "${TMP}/bin"
  cp "${FINTO_PY}" "${TMP}/bin/claude" && chmod +x "${TMP}/bin/claude"
  PATH="${TMP}/bin:${PATH}"
  export PATH
  export FINTO_LOG="${TMP}/finto.log"
  export FINTO_CHIAVE="${ITEM}/_docente/chiave_pr.tsv"
  export HANDSON_NO_PAUSE=1
  unset PN_HANDSON_ROOT PN_WORKSPACE_ROOT PN_FEEDBACK PN_LIVE_JSON
  unset PN_LAB_STRUMENTI
  if [[ "$(command -v claude)" != "${TMP}/bin/claude" ]]; then
    echo "test_m5_e02: il finto non viene prima nel PATH" >&2
    exit 2
  fi
}

# Un registro delle chiamate vuoto.
log_vuoto() { : > "${FINTO_LOG}"; rm -f -- "${FINTO_LOG}.sessioni"; }

# Quante chiamate ha ricevuto il finto. Outputs: il numero.
chiamate() {
  if [[ -f "${FINTO_LOG}" ]]; then
    wc -l < "${FINTO_LOG}"
  else
    echo 0
  fi
}

# Un campo di ogni chiamata del finto. Arguments: $1 un'espressione Python su r.
# Outputs: una riga per chiamata.
dal_log() {
  python3 -B -I - "${FINTO_LOG}" "$1" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as fh:
    for riga in fh:
        r = json.loads(riga)
        print(eval(sys.argv[2]))
PY
}

# Uno spazio di lavoro nuovo, in una radice nuova. Globals: RAD, WS, N_RAD.
nuovo_ws() {
  N_RAD=$((N_RAD + 1))
  RAD="${TMP}/radice-${N_RAD}"
  WS="${RAD}/${ID}"
  mkdir -p "${RAD}"
  "${RADICE}/tools/prepara_esercizio.sh" "${ID}" --radice "${RAD}" \
    > /dev/null 2>&1 < /dev/null
}

# tools/prove_skill.sh sullo spazio di lavoro corrente, con la sua uscita in RC
# e OUT. Arguments: gli argomenti dello strumento dopo l'ID.
prove_cmd() {
  run "${RADICE}/tools/prove_skill.sh" "${ID}" "$@" --radice "${RAD}"
}

# Una copia pulita di uno spazio di lavoro, come quelle di tools/prove_skill.sh:
# un repository git nuovo, un commit, sul ramo main.
# Arguments: $1 da dove, $2 dove.
copia_pulita() {
  mkdir -p "$2"
  (
    shopt -s dotglob nullglob
    for voce in "$1"/*; do
      [[ "${voce##*/}" != .git ]] || continue
      cp -Rp -- "${voce}" "$2/"
    done
  )
  git -C "$2" -c init.defaultBranch=main init -q
  git -C "$2" add -A
  git -C "$2" config user.name "Corso Claude Code"
  git -C "$2" config user.email corso@example.org
  git -C "$2" -c commit.gpgsign=false commit -q --no-verify -m partenza
}

# Il prompt N del README, senza il rientro comune, come lo legge la libreria.
# Arguments: $1 il numero, $2 il README (default quello dell'elemento).
# Outputs: il prompt.
prompt_readme() {
  python3 -B -I - "${2:-${ITEM}/README.md}" "$1" <<'PY'
import sys
import textwrap

righe = open(sys.argv[1], encoding="utf-8").read().split("\n")
n = sys.argv[2]
a = [i for i, r in enumerate(righe) if r.strip() == "<!-- prompt %s -->" % n]
b = [i for i, r in enumerate(righe) if r.strip() == "<!-- /prompt %s -->" % n]
if len(a) != 1 or len(b) != 1 or a[0] > b[0]:
    sys.exit(2)
print(textwrap.dedent("\n".join(righe[a[0] + 1:b[0]])).strip("\n"))
PY
}

# --- l'elemento ---------------------------------------------------------

test_file_elemento() {
  echo "L'elemento:"
  local f manca=''
  for f in README.md progetti.txt verifica.sh verifica.py verita.json \
      esercizio/.gitignore esercizio/.claude/settings.json \
      "esercizio/${PERCORSO_SKILL}/evals/evals.json" \
      "esercizio/${PERCORSO_SKILL}/evals/eval_queries.json" \
      esercizio/controlla_skill.py esercizio/lib_leggi_frontmatter.py \
      prove/config prove/prima.sh prove/pr-1.patch prove/pr-1.msg \
      prove/pr-2.patch prove/pr-2.msg prove/pr-3.patch prove/pr-3.msg \
      soluzione/LEGGIMI.md _docente/live.sh _docente/verita.py \
      _docente/chiave_pr.tsv; do
    [[ -f "${ITEM}/${f}" ]] || manca+=" ${f}"
  done
  if [[ -z "${manca}" ]]; then
    pass "i file dell'elemento ci sono"
  else
    fail "mancano:${manca}"
  fi
  manca=''
  for f in verifica.sh prove/prima.sh _docente/live.sh; do
    [[ -x "${ITEM}/${f}" ]] || manca+=" ${f}"
  done
  if [[ -z "${manca}" ]]; then
    pass "gli script sono eseguibili"
  else
    fail "senza il bit di esecuzione:${manca}"
  fi
  if [[ -f "${LIB}" && ! -x "${LIB}" ]]; then
    pass "lib_lab_m5.sh è una libreria: nessun bit di esecuzione"
  else
    fail "lib_lab_m5.sh manca o è eseguibile"
  fi
  ok_se "il punto di partenza non ha lo SKILL.md" test ! -e \
    "${ITEM}/esercizio/${PERCORSO_SKILL}/SKILL.md"
  ok_se "evals.json è la copia di riferimenti/ byte per byte" cmp \
    "${ESEMPIO}/evals/evals.json" \
    "${ITEM}/esercizio/${PERCORSO_SKILL}/evals/evals.json"
  ok_se "eval_queries.json è la copia di riferimenti/ byte per byte" cmp \
    "${ESEMPIO}/evals/eval_queries.json" \
    "${ITEM}/esercizio/${PERCORSO_SKILL}/evals/eval_queries.json"
  ok_se "controlla_skill.py è la copia di tools/ byte per byte" cmp \
    "${RADICE}/tools/controlla_skill.py" "${ITEM}/esercizio/controlla_skill.py"
  ok_se "lib_leggi_frontmatter.py è la copia di tools/ byte per byte" cmp \
    "${RADICE}/tools/lib_leggi_frontmatter.py" \
    "${ITEM}/esercizio/lib_leggi_frontmatter.py"
  run grep -xF '*-workspace/' "${ITEM}/esercizio/.gitignore"
  expect ".gitignore tiene fuori la cartella delle prove" 0 '*-workspace/'
  run grep -xF 'progetti/gestionale-php' "${ITEM}/progetti.txt"
  expect "progetti.txt nomina il gestionale" 0 'progetti/gestionale-php'
  run python3 -B -I - "${ITEM}/esercizio/.claude/settings.json" \
    "${RADICE}/.claude/settings.json" <<'PY'
import json
import sys

sue = json.load(open(sys.argv[1], encoding="utf-8"))["permissions"]
base = json.load(open(sys.argv[2], encoding="utf-8"))["permissions"]
attese = base["deny"] + ["Edit(/controlla_skill.py)",
                         "Edit(/lib_leggi_frontmatter.py)",
                         "Edit(/.claude/skills/revisione-pr/evals/**)"]
if sorted(sue["deny"]) != sorted(attese):
    sys.exit("deny diverse: %r" % sue["deny"])
if sue.get("allow") or "bypass" in json.dumps(sue):
    sys.exit("regole in più: %r" % sue)
print("regole giuste")
PY
  expect "le regole deny: quelle prudenti, il controllo, evals/" 0 \
    'regole giuste'
  run cat "${ITEM}/prove/config"
  expect "prove/config: la skill, Sonnet, effort low, gli strumenti" 0 \
    "skill=${SKILL}" 'modello=sonnet' 'effort=low' \
    "strumenti=Read,Skill(${SKILL})"
  run python3 -B -I - "${ITEM}/verita.json" <<'PY'
import json
import re
import sys

dati = json.load(open(sys.argv[1], encoding="utf-8"))
if sorted(dati["pr"]) != ["1", "2", "3"]:
    sys.exit("pull request: %r" % sorted(dati["pr"]))
for voci in dati["pr"].values():
    if not all(re.fullmatch(r"[0-9a-f]{64}", voce) for voce in voci):
        sys.exit("una voce non è un'impronta: %r" % voci)
if re.search(r"\b\d{1,2}\.\d\b", json.dumps(dati["pr"])):
    sys.exit("un numero di regola in chiaro")
print("solo impronte")
PY
  expect "verita.json: solo impronte, per i tre pull request" 0 \
    'solo impronte'
}

# --- lo spazio di lavoro ------------------------------------------------

test_punto_di_partenza() {
  echo "Lo spazio di lavoro:"
  N_RAD=$((N_RAD + 1))
  RAD="${TMP}/radice-${N_RAD}"
  WS="${RAD}/${ID}"
  mkdir -p "${RAD}"
  run "${RADICE}/tools/prepara_esercizio.sh" "${ID}" --radice "${RAD}"
  expect "prepara_esercizio.sh prepara lo spazio di lavoro" 0 \
    'Spazio di lavoro pronto'
  local f manca=''
  for f in progetti/gestionale-php/docs/convenzioni.md controlla_skill.py \
      lib_leggi_frontmatter.py .gitignore .claude/settings.json \
      "${PERCORSO_SKILL}/evals/evals.json" \
      "${PERCORSO_SKILL}/evals/eval_queries.json"; do
    [[ -f "${WS}/${f}" ]] || manca+=" ${f}"
  done
  if [[ -z "${manca}" ]]; then
    pass "nello spazio di lavoro c'è il punto di partenza"
  else
    fail "nello spazio di lavoro mancano:${manca}"
  fi
  manca=''
  for f in prove verita.json verifica.py soluzione _docente \
      progetti/gestionale-php/_docente "${PERCORSO_SKILL}/SKILL.md"; do
    [[ ! -e "${WS}/${f}" ]] || manca+=" ${f}"
  done
  if [[ -z "${manca}" ]]; then
    pass "nello spazio di lavoro nessuna verità, nessun pull request"
  else
    fail "nello spazio di lavoro non devono esserci:${manca}"
  fi
  run git -C "${WS}" status --porcelain
  expect_absent "il punto di partenza è tutto nel primo commit" '??'
  run "${RADICE}/tools/verifica.sh" "${ID}" --radice "${RAD}"
  expect "verifica sul punto di partenza: 1, e dice che cosa manca" 1 \
    'MANCA' 'NON ANCORA' 'SKILL.md' 'feedback.json'
  expect_absent "sul punto di partenza nessun reperto" 'REPERTO'
  run python3 -B -I "${WS}/controlla_skill.py" "${WS}/${PERCORSO_SKILL}"
  expect "il controllo nello spazio di lavoro: senza SKILL.md, 1" 1 'SKILL.md'
  run "${ITEM}/verifica.sh"
  expect "verifica.sh senza argomenti: 2" 2 'spazio di lavoro assente'
  run "${ITEM}/verifica.sh" "${TMP}/non-esiste"
  expect "verifica.sh su una cartella che non c'è: 2" 2 \
    'spazio di lavoro assente'
}

# --- i pull request -----------------------------------------------------

# Una copia pulita con prima.sh eseguito. Arguments: $1 l'id, $2 la cartella.
applica() {
  rm -rf -- "$2"
  copia_pulita "${WS}" "$2"
  run "${ITEM}/prove/prima.sh" "$2" "$1"
}

test_pull_request() {
  echo "I pull request:"
  local c="${TMP}/copia" id
  nuovo_ws
  for id in 1 2 3; do
    applica "${id}" "${c}"
    expect "pr-${id}: la patch si applica su uno spazio di lavoro nuovo" 0
    run git -C "${c}" rev-parse --abbrev-ref HEAD
    expect "pr-${id}: HEAD resta sul suo ramo" 0 "pr-${id}"
    run git -C "${c}" status --porcelain
    if [[ -z "${OUT}" ]]; then
      pass "pr-${id}: dopo il commit git status è vuoto"
    else
      fail "pr-${id}: git status non è vuoto: ${OUT}"
    fi
    run git -C "${c}" log -1 --format=%B
    if [[ "${OUT}" == "$(< "${ITEM}/prove/pr-${id}.msg")" ]]; then
      pass "pr-${id}: il messaggio del commit è prove/pr-${id}.msg"
    else
      fail "pr-${id}: il messaggio è «${OUT}»"
    fi
    run git -C "${c}" rev-list --count main..HEAD
    expect "pr-${id}: un commit in più di main" 0 1
  done
  # Il formato di 11.1, tipo(ambito): descrizione.
  local formato='^(feat|fix|refactor|test|docs|chore)\([a-z-]+\): '
  run grep -Eq "${formato}" "${ITEM}/prove/pr-1.msg"
  expect "il messaggio di pr-1 è contro la regola 11.1" 1
  run grep -Eq "${formato}" "${ITEM}/prove/pr-2.msg"
  expect "il messaggio di pr-2 è contro la regola 11.1" 1
  run grep -Fx 'fix iva' "${ITEM}/prove/pr-2.msg"
  expect "il messaggio di pr-2 dice «fix iva»" 0 'fix iva'
  run grep -Eq "${formato}" "${ITEM}/prove/pr-3.msg"
  expect "il messaggio di pr-3 ha il formato, e non dice che cosa fa" 0
  run grep -E 'morosi|esport' "${ITEM}/prove/pr-3.msg"
  expect "il titolo di pr-3 non nomina l'esportazione" 1
  applica 2 "${c}"
  run git -C "${c}" diff --name-only main..HEAD
  if [[ "${OUT}" == */src/Fatturazione/CalcoloTotali.php \
      && "${OUT}" != *$'\n'* ]]; then
    pass "pr-2 cambia il solo calcolo dei totali: niente test, niente legacy"
  else
    fail "pr-2 cambia: ${OUT}"
  fi
  run git -C "${c}" diff main..HEAD
  expect "pr-2 corregge l'IVA con l'arrotondamento" 0 \
    '+        $iva = (int) round($imponibile * self::ALIQUOTA_IVA / 100);'
  applica 1 "${c}"
  run git -C "${c}" diff --name-only main..HEAD
  expect "pr-1: una classe in src/, uno script in bin/, un test" 0 \
    'src/Report/ReportTicketAperti.php' 'bin/export_ticket.php' \
    'tests/Integrazione/ReportTicketApertiTest.php'
  run git -C "${c}" log --all --name-only --format=
  expect_absent "pr-1 non è il pull request della demo M5-D04" \
    'ReportMorosita'
  applica 3 "${c}"
  run git -C "${c}" diff --name-only main..HEAD
  expect "pr-3: il legacy e una classe di src/ fuori da src/Legacy/" 0 \
    'legacy/clienti_lista.php' 'src/Web/CruscottoController.php'
  run git -C "${c}" diff main..HEAD -- \
    progetti/gestionale-php/src/Web/CruscottoController.php
  expect "pr-3: un require nuovo dal codice nuovo al legacy" 0 \
    '+        require_once __DIR__ . '\''/../../legacy/'
  applica q1 "${c}"
  expect "near-miss: la patch di pr-1" 0
  run git -C "${c}" rev-parse --abbrev-ref HEAD
  expect "near-miss: sul ramo pr-1" 0 pr-1
  applica q2 "${c}"
  expect "una seconda near-miss: anche lei su pr-1" 0
  applica 4 "${c}"
  expect "un caso senza pull request: 2, e lo dice" 2 'tre pull request'
  run "${ITEM}/prove/prima.sh"
  expect "prima.sh senza argomenti: 2" 2 'Uso'
  run "${ITEM}/prove/prima.sh" "${TMP}/non-esiste" 1
  expect "prima.sh su una cartella che non è un repository: 2" 2 'repository'
  local altra="${TMP}/prove-rotte"
  rm -rf -- "${altra}"
  mkdir -p "${altra}"
  cp "${ITEM}/prove/prima.sh" "${ITEM}/prove/pr-1.msg" "${altra}/"
  rm -rf -- "${c}"
  copia_pulita "${WS}" "${c}"
  run "${altra}/prima.sh" "${c}" 1
  expect "prima.sh senza la patch: 2" 2 'pr-1.patch'
  rm -f -- "${c}/progetti/gestionale-php/src/Applicazione.php"
  git -C "${c}" add -A
  git -C "${c}" -c commit.gpgsign=false commit -q --no-verify -m tolta
  run "${ITEM}/prove/prima.sh" "${c}" 1
  expect "una patch che non si applica: 2" 2 'non si applica'
  run grep -Eil 'violazion|convenzion|regola [0-9]' \
    "${ITEM}/prove/pr-1.patch" "${ITEM}/prove/pr-2.patch" \
    "${ITEM}/prove/pr-3.patch"
  expect "nessuna patch dice di essere un elenco di difetti" 1
}

# --- la verità ----------------------------------------------------------

test_verita() {
  echo "La verità:"
  local v="${ITEM}/_docente/verita.py" t="${TMP}/verita"
  rm -rf -- "${t}"
  mkdir -p "${t}"
  run python3 -B -I "${v}" --check
  expect "verita.py --check: la chiave conferma verita.json" 0 'conferma'
  run python3 -B -I "${v}"
  if [[ "${RC}" == 0 && "${OUT}" == "$(< "${ITEM}/verita.json")" ]]; then
    pass "verita.py stampa il contenuto di verita.json"
  else
    fail "verita.py stampa altro (${RC}): ${OUT:0:300}"
  fi
  run python3 -B -I - "${ITEM}/_docente/chiave_pr.tsv" <<'PY'
import csv
import sys

D04 = {"2.2", "4.1", "4.3", "5.1", "6.2", "7.1", "7.3", "10.2"}
with open(sys.argv[1], encoding="utf-8", newline="") as fh:
    righe = [r for r in fh if r.strip() and not r.startswith("#")]
chiave = {}
for riga in csv.DictReader(righe, delimiter="\t"):
    chiave.setdefault(riga["pr"], set()).add(riga["regola"])
fuori = chiave["1"] - D04
if len(chiave["1"]) < 6 or len(fuori) < 6 or "11.1" not in chiave["1"]:
    sys.exit("pr-1: %r" % sorted(chiave["1"]))
if chiave["2"] != {"9.6", "10.2", "11.1"}:
    sys.exit("pr-2: %r" % sorted(chiave["2"]))
if chiave["3"] != {"9.1", "9.2", "9.4", "9.5"}:
    sys.exit("pr-3: %r" % sorted(chiave["3"]))
print("chiave come da progetto")
PY
  expect "la chiave: almeno sei regole nuove in pr-1; pr-2 e pr-3 quelle" 0 \
    'chiave come da progetto'
  python3 -B -I - "${ITEM}/verita.json" "${t}/altra.json" <<'PY'
import json
import sys

dati = json.load(open(sys.argv[1], encoding="utf-8"))
dati["pr"]["1"][0] = "0" * 64
json.dump(dati, open(sys.argv[2], "w", encoding="utf-8"))
PY
  run python3 -B -I "${v}" --check --verita "${t}/altra.json"
  expect "una verita.json diversa dalla chiave: 1" 1 'diversa'
  run python3 -B -I "${v}" --check --verita "${t}/non-esiste.json"
  expect "una verita.json che non c'è: 2" 2 'non si legge'
  local chiave="${ITEM}/_docente/chiave_pr.tsv"
  awk -F'\t' 'BEGIN {OFS=FS} $1 == "1" && $2 == "2.4" {$2 = "7.99"} {print}' \
    "${chiave}" > "${t}/regola.tsv"
  run python3 -B -I "${v}" --chiave "${t}/regola.tsv"
  expect "una regola che le convenzioni non hanno: 2" 2 '7.99'
  awk -F'\t' 'BEGIN {OFS=FS} $1 == "1" && $2 == "2.4" {$4 = $4 + 1} {print}' \
    "${chiave}" > "${t}/riga.tsv"
  run python3 -B -I "${v}" --chiave "${t}/riga.tsv"
  expect "una riga della chiave che la patch non ha: 2" 2 'ReportTicketAperti'
  awk -F'\t' 'BEGIN {OFS=FS} $1 == "2" && $2 == "9.6" {$5 = "altro"} {print}' \
    "${chiave}" > "${t}/fuori.tsv"
  run python3 -B -I "${v}" --chiave "${t}/fuori.tsv"
  expect "un file fuori dal pull request senza il suo segno: 2" 2 \
    'funzioni.inc.php'
  run python3 -B -I "${v}" --chiave "${t}/non-esiste.tsv"
  expect "una chiave che non c'è: 2" 2 'non-esiste.tsv'
  printf 'pr\tregola\n1\t2.4\n' > "${t}/colonne.tsv"
  run python3 -B -I "${v}" --chiave "${t}/colonne.tsv"
  expect "una chiave senza le sue colonne: 2" 2 'colonne'
  run python3 -B -I "${v}" --nessuna
  expect "un'opzione sconosciuta: 2" 2 'Uso'
}

# --- i giudici ----------------------------------------------------------

# Uno stream scritto qui, nella forma di quelli veri: non è una risposta di
# Claude. Arguments: $1 la cartella della prova, $2 il testo, $3 facoltativo
# file-cambiati.txt.
stream_di() {
  mkdir -p "$1/outputs"
  python3 -B -I - "$1/outputs/stream.jsonl" "$2" <<'PY'
import json
import sys

percorso, testo = sys.argv[1], sys.argv[2]
elenco = ["code-review"]
if "without_skill" not in percorso:
    elenco.insert(0, "revisione-pr")
righe = [
    {"type": "system", "subtype": "init", "session_id": "prova",
     "skills": elenco},
    {"type": "assistant", "message": {
        "role": "assistant", "content": [{"type": "text", "text": testo}]}},
    {"type": "result", "subtype": "success", "is_error": False,
     "num_turns": 2, "duration_ms": 2000, "result": testo,
     "session_id": "prova", "permission_denials": [],
     "usage": {"input_tokens": 1, "cache_creation_input_tokens": 1,
               "cache_read_input_tokens": 1, "output_tokens": 1}},
]
with open(percorso, "w", encoding="utf-8") as fh:
    for riga in righe:
        fh.write(json.dumps(riga, ensure_ascii=False) + "\n")
PY
  printf '%s' "${3:-}" > "$1/outputs/file-cambiati.txt"
}

# Giudica un testo come risposta di un caso e controlla un'asserzione.
# Globals: G_WS. Arguments: $1 il nome, $2 il caso, $3 il testo, $4 l'inizio
# dell'asserzione, $5 true o false, $6 una parola dell'evidenza, $7 facoltativo
# file-cambiati.txt.
giudica() {
  local nome="$1" caso="$2" testo="$3" quale="$4" atteso="$5" parola="$6" dir
  dir="${G_WS}/${SKILL}-workspace/iteration-1/eval-${caso}/with_skill"
  stream_di "${dir}" "${testo}" "${7:-}"
  run env PN_HANDSON_ROOT="${RADICE}" python3 -B -I "${ITEM}/verifica.py" \
    "${G_WS}" --solo-prove
  if (( RC != 0 )); then
    fail "${nome}: verifica.py esce ${RC}: ${OUT:0:600}"
    return 0
  fi
  run python3 -B -I - "${dir}/grading.json" "${quale}" <<'PY'
import json
import sys

voti = json.load(open(sys.argv[1], encoding="utf-8"))["assertion_results"]
for voce in voti:
    if voce["text"].startswith(sys.argv[2]):
        print(json.dumps(voce["passed"]), voce["evidence"])
        sys.exit(0)
sys.exit("asserzione non trovata")
PY
  if [[ "${OUT}" == "${atteso} "* && "${OUT}" == *"${parola}"* ]]; then
    pass "${nome}"
  else
    fail "${nome} (atteso ${atteso}, «${parola}»): ${OUT:0:600}"
  fi
}

test_giudice_regole() {
  local a='Cita con il numero'
  giudica "regole: tutte citate" 3 '9.1 9.2 9.4 9.5' "${a}" true '4 su 4'
  giudica "regole: una manca, e dice quante e quale" 3 '9.1 9.2 9.4' "${a}" \
    false '3 su 4'
  giudica "regole: l'evidenza nomina il numero che manca" 3 '9.1 9.2 9.4' \
    "${a}" false '9.5'
  giudica "regole: i numeri che mancano sono in ordine di numero" 1 '2.4' \
    "${a}" false 'mancano: 3.5, 3.6, 4.4, 5.4, 6.3, 6.4, 7.2, 10.3, 11.1'
  giudica "regole: 19.1, 9.10, v9.1 e 9.1.2 non sono 9.1" 3 \
    '19.1 9.10 v9.1 9.1.2 9.2 9.4 9.5' "${a}" false '3 su 4'
  giudica "regole: con la punteggiatura e il grassetto sì" 3 \
    '(9.1), **9.2**, `9.4`; regola 9.5.' "${a}" true '4 su 4'
  giudica "regole: quelle di un altro pull request non contano" 3 \
    '9.6 10.2 11.1' "${a}" false '0 su 4'
  giudica "regole: le altre citate sono un dato" 3 \
    '9.1 9.2 9.4 9.5 e anche 7.1' "${a}" true 'altre citate: 7.1'
  giudica "regole: un numero che le convenzioni non hanno è un dato" 3 \
    '9.1 9.2 9.4 9.5 e 7.9' "${a}" true '7.9'
  giudica "regole: PHP 8.3 non è la regola 8.3" 3 \
    '9.1 9.2 9.4 9.5, in PHP 8.3' "${a}" true '4 su 4'
  giudica "regole: pr-2, quelle di ciò che manca" 2 '9.6 10.2 11.1' "${a}" \
    true '3 su 3'
  giudica "regole: una risposta vuota non passa" 3 ' ' "${a}" false '0 su 4'
}

test_giudice_righe() {
  local a='Indica il file' r1 r2
  r1='| 9.1 | legacy/clienti_lista.php | 18 | va in src/ |'
  r2='| 9.4 | legacy/clienti_lista.php | - | riformattato |'
  giudica "righe: la tabella, numero, file e riga" 3 "${r1}" "${a}" true \
    'legacy/clienti_lista.php'
  giudica "righe: una regola senza la riga, e dice quale" 3 \
    "${r1}"$'\n'"${r2}" "${a}" false '9.4'
  giudica "righe: più righe nella stessa cella" 3 \
    '| 9.1 | legacy/clienti_lista.php | 18 e 20 | x |' "${a}" true '18 e 20'
  giudica "righe: la forma percorso:riga" 3 \
    'legacy/clienti_lista.php:18 (9.1)' "${a}" true 'clienti_lista.php:18'
  giudica "righe: la forma «riga N di»" 3 \
    '9.1: riga 18 di legacy/clienti_lista.php' "${a}" true 'riga 18'
  giudica "righe: il percorso dalla radice dello spazio di lavoro" 3 \
    '| 9.1 | progetti/gestionale-php/legacy/clienti_lista.php | 18 | x |' \
    "${a}" true 'progetti/gestionale-php/legacy'
  giudica "righe: un file inventato non vale" 3 \
    '| 9.1 | legacy/inventato.php | 18 | x |' "${a}" false '9.1'
  giudica "righe: un file fuori dalla differenza, nel progetto, vale" 2 \
    '| 9.6 | legacy/inc/funzioni.inc.php | 68 | la copia legacy |' "${a}" \
    true 'funzioni.inc.php'
  giudica "righe: ciò che riguarda il pull request non ha una riga" 2 \
    '| 9.6 | legacy/inc/funzioni.inc.php | 68 | x |
| 10.2 | - | - | manca un test |
| 11.1 | - | - | il messaggio |' "${a}" true '10.2'
  giudica "righe: un numero che non è una riga non vale" 3 \
    '| 9.1 | legacy/clienti_lista.php | - | costa 22 euro |' "${a}" false '9.1'
  giudica "righe: nessuna regola, ma un file e una riga" 3 \
    'legacy/clienti_lista.php:18 non mi convince' "${a}" true \
    'nessuna regola'
  giudica "righe: nessuna regola, nessun file: non passa" 3 'va tutto bene' \
    "${a}" false 'nessuna riga'
  giudica "righe: solo regole senza riga, nessun file: non passa" 3 \
    '9.2 e 11.1 non vanno' "${a}" false 'nessuna riga'
  giudica "righe: la stessa regola nominata prima senza il posto" 3 \
    "La 9.1 è la più grave."$'\n'"${r1}" "${a}" true '1 su 1'
  giudica "righe: PHP 8.3 non chiede una riga" 3 \
    "In PHP 8.3 va bene."$'\n'"${r1}" "${a}" true '1 su 1'
  giudica "righe: una regola non inserita, nominata in prosa, non chiede il posto" 3 \
    "La 5.2 è rispettata."$'\n'"${r1}" "${a}" true '1 su 1'
  giudica "righe: il dato dice quali altre non hanno il posto" 3 \
    "La 5.2 è rispettata."$'\n'"${r1}" "${a}" true 'altre citate senza il posto: 5.2'
}

test_giudice_esito() {
  local a='Chiude con un esito'
  giudica "esito: da modificare" 3 $'tabella\n\nEsito: da modificare' "${a}" \
    true 'da modificare'
  giudica "esito: approvabile" 3 $'Nessuna violazione\n\nEsito: approvabile' \
    "${a}" true 'approvabile'
  giudica "esito: maiuscolo e in grassetto" 3 '**ESITO: DA MODIFICARE**' \
    "${a}" true 'DA MODIFICARE'
  giudica "esito: una nota dopo l'esito" 3 \
    $'Esito: da modificare\n\nFuori regola: un dubbio' "${a}" true \
    'da modificare'
  giudica "esito: lontano dalla fine non è un esito" 3 \
    $'è da modificare\na\nb\nc\nd\ne\nf' "${a}" false 'ultime'
  giudica "esito: nessun esito" 3 'il codice mi sembra in ordine' "${a}" false \
    'ultime'
}

test_giudice_file() {
  local a='Non modifica'
  giudica "file: file-cambiati.txt vuoto" 3 'x' "${a}" true 'vuoto'
  giudica "file: l'evidenza dice che cosa è consentito" 3 'x' "${a}" true \
    'Edit e Write non sono fra gli strumenti consentiti'
  expect_absent "file: l'evidenza non dice che gli strumenti sono solo quelli" \
    'non comprendono'
  giudica "file: un file cambiato non passa, e lo nomina" 3 'x' "${a}" false \
    'nuovo.txt' '?? nuovo.txt'
  local dir="${G_WS}/${SKILL}-workspace/iteration-1/eval-3/with_skill"
  stream_di "${dir}" 'x'
  rm -f -- "${dir}/outputs/file-cambiati.txt"
  run env PN_HANDSON_ROOT="${RADICE}" python3 -B -I "${ITEM}/verifica.py" \
    "${G_WS}" --solo-prove
  expect "file: senza file-cambiati.txt non decide: 2" 2 'file-cambiati.txt'
  stream_di "${dir}" 'x'
}

# Un'asserzione aggiunta da un partecipante, e i dati che non decidono.
test_giudici_dati() {
  local dir w="${G_WS}" evals
  evals="${w}/${PERCORSO_SKILL}/evals/evals.json"
  cp -- "${evals}" "${TMP}/evals.salvati"
  python3 -B -I - "${evals}" <<'PY'
import json
import sys

dati = json.load(open(sys.argv[1], encoding="utf-8"))
dati["evals"][2]["assertions"].append("Spiega perché, con parole chiare")
json.dump(dati, open(sys.argv[1], "w", encoding="utf-8"), ensure_ascii=False)
PY
  dir="${w}/${SKILL}-workspace/iteration-1/eval-3/with_skill"
  stream_di "${dir}" '9.1 9.2 9.4 9.5'
  run env PN_HANDSON_ROOT="${RADICE}" python3 -B -I "${ITEM}/verifica.py" \
    "${w}" --solo-prove
  expect "un'asserzione in più resta da valutare a mano, fuori dai conti" 0 \
    'da valutare a mano in with_skill: «Spiega perché' '2 su 4 asserzioni'
  cp -- "${TMP}/evals.salvati" "${evals}"
  stream_di "${w}/${SKILL}-workspace/iteration-1/eval-3/without_skill" \
    '9.1 e 9.2'
  run env PN_HANDSON_ROOT="${RADICE}" python3 -B -I "${ITEM}/verifica.py" \
    "${w}" --solo-prove
  expect "i dati: le regole inserite citate per configurazione" 0 \
    '(dato)' 'pr-3' 'without_skill 2 su 4' 'with_skill 4 su 4' 'confermata' \
    'una sola esecuzione per caso'
  stream_di "${dir}" '9.1 e 9.2'
  run env PN_HANDSON_ROOT="${RADICE}" python3 -B -I "${ITEM}/verifica.py" \
    "${w}" --solo-prove
  expect "i dati: stesso numero, non distinguibile, uscita 0" 0 \
    'non distinguibile'
  stream_di "${dir}" '9.1'
  run env PN_HANDSON_ROOT="${RADICE}" python3 -B -I "${ITEM}/verifica.py" \
    "${w}" --solo-prove
  expect "i dati: meno regole con la skill, mai smentita, uscita 0" 0 \
    'non confermata in questa misura'
  expect_absent "nessun esito dice «smentita»" 'smentita'
  rm -rf -- "${w}/${SKILL}-workspace"
}

test_precondizioni_verifica() {
  local copia="${TMP}/item-copia" w="${G_WS}"
  rm -rf -- "${copia}"
  cp -R "${ITEM}" "${copia}"
  mkdir -p "${w}/${SKILL}-workspace/iteration-1/eval-1/with_skill"
  stream_di "${w}/${SKILL}-workspace/iteration-1/eval-1/with_skill" 'x'
  local v="${copia}/verifica.py"
  rm -f -- "${copia}/verita.json"
  run env PN_HANDSON_ROOT="${RADICE}" python3 -B -I "${v}" "${w}"
  expect "senza verita.json: 2" 2 'verita.json'
  printf '{rotta' > "${copia}/verita.json"
  run env PN_HANDSON_ROOT="${RADICE}" python3 -B -I "${v}" "${w}"
  expect "con una verita.json che non si legge: 2" 2 'verita.json'
  printf '{"pr": {"2": [], "3": []}}\n' > "${copia}/verita.json"
  run env PN_HANDSON_ROOT="${RADICE}" python3 -B -I "${v}" "${w}"
  expect "un caso che verita.json non ha: 2" 2 'eval-1'
  printf '{"pr": {"1": ["%064d"], "2": [], "3": []}}\n' 0 \
    > "${copia}/verita.json"
  run env PN_HANDSON_ROOT="${RADICE}" python3 -B -I "${v}" "${w}"
  expect "un'impronta che non è di nessuna regola: 2" 2 'impronte'
  cp -- "${ITEM}/verita.json" "${copia}/verita.json"
  rm -f -- "${copia}/prove/pr-1.patch"
  run env PN_HANDSON_ROOT="${RADICE}" python3 -B -I "${v}" "${w}"
  expect "senza la patch del caso: 2" 2 'pr-1.patch'
  cp -- "${ITEM}/prove/pr-1.patch" "${copia}/prove/pr-1.patch"
  run env PN_HANDSON_ROOT="${TMP}/non-esiste" python3 -B -I "${v}" "${w}"
  expect "un repository che non c'è: 2" 2 'non-esiste'
  run env PN_HANDSON_ROOT="${RADICE}" python3 -B -I "${v}"
  expect "senza lo spazio di lavoro: 2" 2 'Uso'
  run env PN_HANDSON_ROOT="${RADICE}" python3 -B -I "${v}" "${TMP}/non-esiste"
  expect "su una cartella che non c'è: 2" 2 'spazio di lavoro assente'
  run env PN_HANDSON_ROOT="${RADICE}" python3 -B -I "${v}" "${w}" --boh
  expect "con un'opzione sconosciuta: 2" 2 'Uso'
  local rotto="${w}/${SKILL}-workspace/iteration-1/eval-1/with_skill/outputs"
  printf '{non è JSON\n' > "${rotto}/stream.jsonl"
  run env PN_HANDSON_ROOT="${RADICE}" python3 -B -I "${v}" "${w}"
  expect "uno stream che non si legge: 2" 2 'non è JSON'
  rm -rf -- "${w}/${SKILL}-workspace"
  local evals="${w}/${PERCORSO_SKILL}/evals/evals.json"
  mv -- "${evals}" "${evals}.via"
  run env PN_HANDSON_ROOT="${RADICE}" python3 -B -I "${v}" "${w}"
  expect "senza i casi di prova: 2" 2 'evals.json'
  mv -- "${evals}.via" "${evals}"
}

test_giudici() {
  echo "I giudici:"
  nuovo_ws
  G_WS="${WS}"
  test_giudice_regole
  test_giudice_righe
  test_giudice_esito
  test_giudice_file
  test_giudici_dati
  test_precondizioni_verifica
}

# --- il ciclo del README ------------------------------------------------

test_ciclo() {
  echo "Il ciclo del README, con il claude finto:"
  log_vuoto
  nuovo_ws
  prove_cmd 1 without
  expect "la baseline: tre esecuzioni, una tabella" 0 'Iterazione 1' \
    'without_skill: Skill chiamata: no' 'eval-3'
  run dal_log 'r["branch"]'
  if [[ "${OUT}" == $'pr-1\npr-2\npr-3' ]] \
      || [[ "$(sort <<< "${OUT}" | tr '\n' ' ')" == 'pr-1 pr-2 pr-3 ' ]]; then
    pass "la baseline: ogni caso sul suo ramo"
  else
    fail "i rami della baseline: ${OUT}"
  fi
  run dal_log 'r["skill"], r["evals"], r["workspace"], r["bozza"]'
  expect_absent "la baseline: nessuna skill nella copia" 'revisione-pr'
  expect_absent "la baseline: nessun evals/, nessun workspace" 'True'
  run dal_log '" ".join(r["argv"][:r["argv"].index("--")])'
  expect "i flag di ogni prova" 0 "--allowedTools Read,Skill(${SKILL})" \
    '--model sonnet' '--permission-mode dontAsk' '--permission-prompts none' \
    '--output-format stream-json' '--verbose' \
    '--setting-sources project,local' '--effort low' '--strict-mcp-config' \
    '--no-session-persistence'
  run dal_log 'r["prompt"]'
  expect "le richieste sono quelle di evals.json, così come sono" 0 \
    'Rivedi il pull request di questo branch rispetto a main.' \
    "ho corretto l'arrotondamento dell'IVA"
  local prima="${WS}/${SKILL}-workspace/iteration-1/eval-1/without_skill"
  run cat "${prima}/outputs/risposta.md"
  expect "la baseline: la risposta da leggere" 0 'FINTO'
  run "${RADICE}/tools/verifica.sh" "${ID}" --radice "${RAD}"
  expect "dopo la baseline: non ancora" 1 'MANCA' 'with_skill' 'NON ANCORA'
  prove_cmd copia esempio
  expect "copia esempio: la skill di partenza" 0 'Copiata'
  ok_se "copia esempio porta anche le convenzioni" test -f \
    "${WS}/${PERCORSO_SKILL}/references/convenzioni.md"
  ok_se "copia esempio non tocca evals/" cmp \
    "${ITEM}/esercizio/${PERCORSO_SKILL}/evals/evals.json" \
    "${WS}/${PERCORSO_SKILL}/evals/evals.json"
  run python3 -B -I "${WS}/controlla_skill.py" "${WS}/${PERCORSO_SKILL}"
  expect "il controllo nello spazio di lavoro: l'esempio passa" 0 '0 errori'
  log_vuoto
  prove_cmd 1 with
  expect "la prima versione: la skill chiamata, il confronto, la near-miss" 0 \
    'with_skill: Skill chiamata: sì' 'near-miss 1: Skill chiamata: no' \
    'dovrebbe attivarla: no' 'confermata (una sola esecuzione per caso)' \
    'Consumo'
  expect "«Non modifica alcun file» passa sempre, e la guida la toglierebbe" \
    0 'Passano sempre in entrambe le configurazioni' \
    '«Non modifica alcun file»' \
    'Remove or replace assertions that always pass in both configurations.'
  expect "i dati: la skill chiamata n su 3" 0 '(dato)' \
    "${SKILL} chiamata 3 su 3" 'without_skill 0 su 10' 'with_skill 10 su 10'
  run dal_log 'r["branch"]+" "+str(r["skill"])+" "+str(r["evals"])'
  expect "with: la copia ha la skill, non evals/" 0 'revisione-pr' 'False'
  expect_absent "with: mai evals/ nella copia" 'True'
  run dal_log '"near" if "messaggio di commit" in r["prompt"] else ""'
  expect "la near-miss c'è" 0 near
  run dal_log 'r["branch"] if "messaggio di commit" in r["prompt"] else "x"'
  expect "la near-miss gira sul ramo pr-1" 0 pr-1
  run "${RADICE}/tools/verifica.sh" "${ID}" --radice "${RAD}"
  expect "senza feedback.json: non ancora, e lo dice" 1 'feedback.json' \
    'iterazione 2'
  printf '{"eval-1": "Manca la riga del messaggio di commit.", "eval-2": ""%s' \
    ', "eval-3": ""}' > "${WS}/${SKILL}-workspace/iteration-1/feedback.json"
  printf '\nUna riga in più.\n' >> "${WS}/${PERCORSO_SKILL}/SKILL.md"
  log_vuoto
  prove_cmd 2 with
  expect "la seconda versione: old_skill riusata, non rifatta" 0 \
    'si riusano come old_skill' 'Iterazione 2' 'old_skill: Skill chiamata: sì'
  run wc -l "${FINTO_LOG}"
  expect "la seconda versione: quattro chiamate, come la prima" 0 '4 '
  run "${RADICE}/tools/verifica.sh" "${ID}" --radice "${RAD}"
  expect "il ciclo finito: fatto" 0 'VERIFICA OK' 'Fatto'
  expect_absent "il ciclo finito: niente che manchi" 'MANCA'
  expect_absent "il ciclo finito: nessun reperto" 'REPERTO'
  # Un grading.json cambiato a mano non conta: il controllo legge gli stream.
  python3 -B -I - "${prima}/grading.json" <<'PY'
import json
import sys

dati = json.load(open(sys.argv[1], encoding="utf-8"))
for voce in dati["assertion_results"]:
    voce["passed"] = True
json.dump(dati, open(sys.argv[1], "w", encoding="utf-8"))
PY
  run env PN_HANDSON_ROOT="${RADICE}" python3 -B -I "${ITEM}/verifica.py" \
    "${WS}"
  expect "il controllo non legge grading.json: la tabella resta quella" 0 \
    'without_skill: Skill chiamata: no' '1 su 4 asserzioni'
}

# Lo stesso giro, con la seconda versione uguale alla prima.
test_versioni_uguali() {
  log_vuoto
  nuovo_ws
  prove_cmd 1 without
  prove_cmd copia esempio
  prove_cmd 1 with
  printf '{"eval-1": "", "eval-2": "", "eval-3": ""}' \
    > "${WS}/${SKILL}-workspace/iteration-1/feedback.json"
  prove_cmd 2 with
  run "${RADICE}/tools/verifica.sh" "${ID}" --radice "${RAD}"
  expect "due versioni uguali: non ancora, e lo dice" 1 'uguali'
  run python3 -B -I - "${WS}/${PERCORSO_SKILL}/SKILL.md" <<'PY'
import sys

percorso = sys.argv[1]
testo = open(percorso, encoding="utf-8").read()
testo = testo.replace("name: revisione-pr", "name: Revisione PR", 1)
open(percorso, "w", encoding="utf-8").write(testo)
PY
  run "${RADICE}/tools/verifica.sh" "${ID}" --radice "${RAD}"
  expect "una skill che il controllo boccia: non ancora, e lo dice" 1 \
    'MANCA' 'name'
  nuovo_ws
  prove_cmd copia modello
  expect "copia modello: il modello, con il nome della skill" 0 \
    'template-SKILL.md'
  run grep -x "name: ${SKILL}" "${WS}/${PERCORSO_SKILL}/SKILL.md"
  expect "copia modello: name è quello della cartella" 0 "name: ${SKILL}"
}

test_garanzie() {
  echo "Le garanzie:"
  log_vuoto
  nuovo_ws
  FINTO_CHIAMA_SEMPRE="${SKILL}" prove_cmd 1 without
  expect "senza la skill, una chiamata alla skill: reperto, 1" 1 'REPERTO' \
    "una chiamata Skill a ${SKILL}"
  run "${RADICE}/tools/verifica.sh" "${ID}" --radice "${RAD}"
  expect "la verifica dice lo stesso: 1" 1 'REPERTO' 'NON ANCORA'
  nuovo_ws
  FINTO_ELENCA="${SKILL}" prove_cmd 1 without
  expect "senza la skill, la skill nell'elenco: reperto, 1" 1 'REPERTO' \
    'fra le skill disponibili'
  nuovo_ws
  FINTO_CHIAMA_SEMPRE=code-review prove_cmd 1 without
  expect "senza la skill, code-review scelta da Claude: un dato, 0" 0 \
    'Skill chiamata: no (altre: code-review)' '(dato)' 'code-review'
  expect_absent "code-review non è un reperto" 'REPERTO'
  prove_cmd copia esempio
  FINTO_NEGA_SKILL=1 prove_cmd 1 with
  expect "la chiamata negata dal permesso: reperto, 1" 1 'REPERTO' \
    'negata dal permesso'
  nuovo_ws
  FINTO_SENZA_INIT=1 prove_cmd 1 without
  expect "uno stream senza l'elenco delle skill: non decide, 2" 2 \
    'elenco delle skill'
  nuovo_ws
  FINTO_RIGA_ROTTA=1 prove_cmd 1 without
  expect "uno stream che non si legge: non decide" 1 'FALLITA'
  nuovo_ws
  FINTO_KO_SU=Rivedi prove_cmd 1 without
  expect "un'esecuzione fallita: 1, le altre finite" 1 'FALLITA eval-1' \
    'finita eval-2'
  nuovo_ws
  FINTO_ERRORE_SU=Rivedi prove_cmd 1 without
  expect "un risultato con is_error: 1" 1 'FALLITA eval-1'
  run "${RADICE}/tools/verifica.sh" "${ID}" --radice "${RAD}"
  expect "la verifica lo sa: finita con un errore" 1 'finita con un errore'
  nuovo_ws
  FINTO_SCRIVI=1 prove_cmd 1 without
  expect "una prova che scrive: l'asserzione non passa, uscita 0" 0 \
    'non passata in without_skill: «Non modifica alcun file»' 'nuovo.txt'
}

# --- la libreria --------------------------------------------------------

# La prova dal vivo, da capo, in uno spazio di lavoro nuovo.
# Arguments: facoltative, assegnazioni per l'ambiente (VAR=valore).
live() {
  log_vuoto
  nuovo_ws
  run env "$@" "${ITEM}/_docente/live.sh" "${WS}"
}

test_libreria_argomenti() {
  run bash -c 'source "$1/tools/lib_handson.sh"; source "$2"
    lab::una_prova x' _ "${RADICE}" "${LIB}"
  expect "lab::una_prova con un solo argomento: 2" 2 'servono'
  run grep -c 'lab::una_prova <ID> <spazio>' "${LIB}"
  expect "la testata dice come si chiama" 0 1
  local parola
  for parola in PN_FEEDBACK PN_LIVE_JSON PN_LAB_STRUMENTI 'prompt 1' \
      'prompt 2' prove/config approvazione bozza/ Globals Returns; do
    run grep -F -- "${parola}" "${LIB}"
    expect "la testata nomina «${parola}»" 0 "${parola}"
  done
  run "${ITEM}/_docente/live.sh"
  expect "live.sh senza lo spazio di lavoro: 2, e dice l'uso" 2 \
    'uso: _docente/live.sh <spazio di lavoro>'
  expect_absent "live.sh senza argomenti non parla di un valore vuoto" 'assente'
  run "${ITEM}/_docente/live.sh" "${TMP}/non-esiste"
  expect "live.sh su una cartella che non c'è: 2" 2 'spazio di lavoro assente'
}

# La modalità della scrittura non dipende dall'ambiente, come nelle prove.
test_libreria_modalita() {
  live HANDSON_PERMISSION_MODE=acceptEdits
  expect "con un'altra modalità nell'ambiente: 0" 0 'VERIFICA OK'
  run dal_log 'r["argv"][r["argv"].index("--permission-mode") + 1]'
  expect "tutte le chiamate in dontAsk, le due scritture comprese" 0 'dontAsk'
  expect_absent "nessuna chiamata nella modalità dell'ambiente" 'acceptEdits'
}

# Uno stream scritto qui, di un turno e con un passo negato: non è una risposta
# di Claude. Il riepilogo di un passo dice il singolare.
test_libreria_riepilogo() {
  local stream="${TMP}/riepilogo.jsonl"
  python3 -B -I - "${stream}" <<'PY'
import json
import sys

righe = [
    {"type": "system", "subtype": "init", "session_id": "prova", "skills": []},
    {"type": "result", "subtype": "success", "is_error": False,
     "num_turns": 1, "duration_ms": 2000, "result": "x",
     "session_id": "prova",
     "permission_denials": [{"tool_name": "Bash", "tool_use_id": "toolu_prova",
                             "tool_input": {"command": "ls"}}],
     "usage": {"input_tokens": 1, "cache_creation_input_tokens": 1,
               "cache_read_input_tokens": 1, "output_tokens": 1}},
]
with open(sys.argv[1], "w", encoding="utf-8") as fh:
    for riga in righe:
        fh.write(json.dumps(riga) + "\n")
PY
  run bash -c 'source "$1/tools/lib_handson.sh"; source "$2"
    lab::_riepilogo "passo 9" "$3"' _ "${RADICE}" "${LIB}" "${stream}"
  expect "il riepilogo di un turno: il singolare" 0 'passo 9: 1 chiamata' \
    '1 turno del modello' '1 negato dal permesso'
  expect_absent "il riepilogo: non «1 turni»" '1 turni'
  expect_absent "il riepilogo: non «1 negati»" '1 negati'
}

# Gli stream di una prova di prima non si sovrascrivono, come in M5-D01.
test_libreria_stream_di_prima() {
  local stato cartella="${TMP}/stream-di-prima"
  nuovo_ws
  mkdir -p "${WS}.prova_dal_vivo"
  printf 'di prima\n' > "${WS}.prova_dal_vivo/passo-3.jsonl"
  log_vuoto
  run "${ITEM}/_docente/live.sh" "${WS}"
  expect "gli stream di una prova di prima: 2, e dice dove" 2 \
    "c'è già una prova" "${ID}.prova_dal_vivo" \
    "tools/reset_esercizio.sh ${ID}"
  stato="$(chiamate)"
  if (( stato == 0 )); then
    pass "e nessuna chiamata"
  else
    fail "${stato} chiamate"
  fi
  run cat "${WS}.prova_dal_vivo/passo-3.jsonl"
  expect "lo stream di prima resta com'è" 0 'di prima'
  nuovo_ws
  mkdir -p "${cartella}"
  printf 'di prima\n' > "${cartella}/passo-6.jsonl"
  log_vuoto
  run env PN_LIVE_JSON="${cartella}" "${ITEM}/_docente/live.sh" "${WS}"
  expect "anche in PN_LIVE_JSON: 2" 2 "c'è già una prova" 'stream-di-prima'
  nuovo_ws
  mkdir -p "${WS}.prova_dal_vivo"
  log_vuoto
  run env FINTO_KO_SU=Rivedi "${ITEM}/_docente/live.sh" "${WS}"
  expect "una cartella vuota non è una prova: si parte" 1 'FALLITA eval-1'
  expect_absent "e non dice che c'è già" "c'è già una prova"
}

test_libreria_da_capo() {
  local atteso1 atteso2 sessione
  live ANTHROPIC_API_KEY=finta-non-usata
  expect "live.sh da capo a fondo: 0" 0 'VERIFICA OK' 'Fatto'
  expect "i passi, con i loro numeri" 0 'passo 1:' 'passo 3:' 'passo 4:' \
    'passo 6:' 'passo 7:' 'turni del modello' 'token'
  local cifre="${OUT}"
  run wc -l "${FINTO_LOG}"
  expect "tredici chiamate: undici di prove, due di scrittura" 0 '13 '
  OUT="${cifre}"
  expect_absent "nessun reperto" 'REPERTO'
  run dal_log 'r["chiave"]'
  expect_absent "ANTHROPIC_API_KEY non arriva mai a claude" 'True'
  atteso1="$(prompt_readme 1)"
  atteso1="${atteso1//${PERCORSO_SKILL}/bozza/${SKILL}}"
  atteso2="$(prompt_readme 2)"
  atteso2="${atteso2//${PERCORSO_SKILL}/bozza/${SKILL}}"
  python3 -B -I - "${FINTO_LOG}" "${TMP}/scritture" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as fh:
    righe = [json.loads(r) for r in fh]
scritture = [r for r in righe if "<instructions>" in r["prompt"]]
for n, r in enumerate(scritture, 1):
    with open("%s.%d.prompt" % (sys.argv[2], n), "w", encoding="utf-8") as fh:
        fh.write(r["prompt"])
    with open("%s.%d.argv" % (sys.argv[2], n), "w", encoding="utf-8") as fh:
        fh.write(" ".join(r["argv"][:r["argv"].index("--")]))
PY
  if [[ "$(< "${TMP}/scritture.1.prompt")" == "${atteso1}" ]]; then
    pass "il prompt 1 è quello del README, con il percorso in bozza/"
  else
    fail "il prompt 1 è diverso: $(< "${TMP}/scritture.1.prompt")"
  fi
  if [[ "$(< "${TMP}/scritture.2.prompt")" == "${atteso2}" ]]; then
    pass "il prompt 2 è quello del README, con il percorso in bozza/"
  else
    fail "il prompt 2 è diverso: $(< "${TMP}/scritture.2.prompt")"
  fi
  run cat "${TMP}/scritture.1.prompt" "${TMP}/scritture.2.prompt"
  expect_absent "nessun prompt di scrittura nomina .claude/skills" \
    '.claude/skills'
  run cat "${TMP}/scritture.1.argv"
  expect "la scrittura: Sonnet, effort medium, gli strumenti nominati" 0 \
    '--model sonnet' '--effort medium' '--output-format stream-json' \
    '--verbose' '--permission-mode dontAsk' '--strict-mcp-config' \
    'Read,Edit,Write,Bash(python3 -B -I controlla_skill.py *)'
  expect_absent "la scrittura si riprende: nessun --no-session-persistence" \
    'no-session-persistence'
  expect_absent "la prima scrittura apre la sessione" '--resume'
  run cat "${TMP}/scritture.2.argv"
  expect "il seguito: --resume, stessi flag" 0 '--resume sessione-finta-' \
    '--effort medium' \
    'Read,Edit,Write,Bash(python3 -B -I controlla_skill.py *)'
  sessione="$(python3 -B -I - "${WS}.prova_dal_vivo/passo-3.jsonl" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as fh:
    righe = [json.loads(r) for r in fh]
print([r for r in righe if r["type"] == "result"][-1]["session_id"])
PY
)"
  expect "il seguito riprende la sessione del prompt 1" 0 "${sessione}"
  ok_se "gli stream stanno fuori dallo spazio di lavoro" test -s \
    "${WS}.prova_dal_vivo/passo-6.jsonl"
  ok_se "nello spazio di lavoro nessuno stream dei passi" test ! -e \
    "${WS}/passo-3.jsonl"
  run dal_log 'r["bozza"] if "<instructions>" not in r["prompt"] else "scrive"'
  expect_absent "nessuna prova vede la bozza" 'True'
  expect "le prove girano senza bozza" 0 'False'
  ok_se "alla fine la bozza non c'è più" test ! -e "${WS}/bozza"
  run grep -c 'Riga di prova del finto' "${WS}/${PERCORSO_SKILL}/SKILL.md"
  expect "la skill ha le due scritture, portate da bozza/" 0 2
  run grep -c 'Riga di prova del finto' \
    "${WS}/${SKILL}-workspace/iteration-1/skill-snapshot/SKILL.md"
  expect "la prima versione ha la prima scrittura" 0 1
  run grep -c 'Riga di prova del finto' \
    "${WS}/${SKILL}-workspace/iteration-2/skill-snapshot/SKILL.md"
  expect "la seconda versione ha tutte e due" 0 2
  ok_se "evals/ resta la copia di partenza" cmp \
    "${ITEM}/esercizio/${PERCORSO_SKILL}/evals/evals.json" \
    "${WS}/${PERCORSO_SKILL}/evals/evals.json"
  run cat "${WS}/${SKILL}-workspace/iteration-1/feedback.json"
  expect "feedback.json dice che l'ha scritto uno script" 0 '_nota' \
    'uno script' 'eval-1' 'eval-2' 'eval-3'
}

test_libreria_bozza() {
  run env FINTO_LOG="${TMP}/diretto.log" bash -c '
    cd "$1" && claude -p --output-format stream-json --verbose -- \
      "<instructions> .claude/skills/revisione-pr </instructions>"' \
    _ "${WS}"
  expect "il finto rifiuta di scrivere sotto .claude/, come il vero" 0 \
    'permission_denials' '"tool_name": "Write"' 'negata'
  run grep -c 'Riga di prova del finto' "${WS}/${PERCORSO_SKILL}/SKILL.md"
  expect "il file sotto .claude/ non è cambiato" 0 2
  live FINTO_TOCCA_EVALS=1
  expect "chi tocca evals/ nella bozza non arriva a evals/: 0" 0 'VERIFICA OK'
  ok_se "evals/ non è cambiato" cmp \
    "${ITEM}/esercizio/${PERCORSO_SKILL}/evals/evals.json" \
    "${WS}/${PERCORSO_SKILL}/evals/evals.json"
  live FINTO_NUOVO_FILE=scripts/aiuto.py
  expect "un file nuovo nella bozza: 0" 0 'VERIFICA OK'
  ok_se "il file nuovo arriva nella skill" test -f \
    "${WS}/${PERCORSO_SKILL}/scripts/aiuto.py"
  live FINTO_TOGLIE_FILE=references/convenzioni.md
  ok_se "un file tolto nella bozza esce dalla skill" test ! -e \
    "${WS}/${PERCORSO_SKILL}/references/convenzioni.md"
  live FINTO_TOGLIE_SKILL=1
  expect "una scrittura che lascia la bozza senza SKILL.md: 1" 1 \
    "bozza/${SKILL}/SKILL.md"
  run wc -l "${FINTO_LOG}"
  expect "e nessuna prova dopo" 0 '4 '
  live FINTO_NON_CAMBIA=1
  expect "un seguito che non cambia niente: 1, la verifica lo dice" 1 'uguali'
}

test_libreria_rifiuti() {
  local stato
  nuovo_ws
  printf 'lavoro\n' > "${WS}/appunti.txt"
  log_vuoto
  run "${ITEM}/_docente/live.sh" "${WS}"
  expect "uno spazio di lavoro con del lavoro: 2" 2 \
    "tools/reset_esercizio.sh ${ID}"
  stato="$(chiamate)"
  if (( stato == 0 )); then
    pass "e nessuna chiamata"
  else
    fail "${stato} chiamate"
  fi
  rm -f -- "${WS}/appunti.txt"
  git -C "${WS}" -c user.name=x -c user.email=x@example.org \
    -c commit.gpgsign=false commit -q --no-verify --allow-empty -m altro
  run "${ITEM}/_docente/live.sh" "${WS}"
  expect "un commit dopo il primo: 2" 2 "tools/reset_esercizio.sh ${ID}"
  nuovo_ws
  mkdir -p "${WS}/${SKILL}-workspace/iteration-1"
  log_vuoto
  run "${ITEM}/_docente/live.sh" "${WS}"
  expect "prove già fatte, che git non vede: 2" 2 \
    "tools/reset_esercizio.sh ${ID}"
  nuovo_ws
  mv -- "${WS}" "${RAD}/altro-nome"
  log_vuoto
  run "${ITEM}/_docente/live.sh" "${RAD}/altro-nome"
  expect "una cartella che non si chiama come l'elemento: 2" 2 "${ID}"
  stato="$(chiamate)"
  if (( stato == 0 )); then
    pass "e nessuna chiamata"
  else
    fail "${stato} chiamate"
  fi
  nuovo_ws
  log_vuoto
  run env PN_LIVE_JSON="${WS}/dentro" "${ITEM}/_docente/live.sh" "${WS}"
  expect "gli stream dentro lo spazio di lavoro: 2" 2 'non stanno'
  run env PN_FEEDBACK="${TMP}/non-esiste" "${ITEM}/_docente/live.sh" "${WS}"
  expect "PN_FEEDBACK che non c'è: 2" 2 'non-esiste'
  stato="$(chiamate)"
  if (( stato == 0 )); then
    pass "e nessuna chiamata"
  else
    fail "${stato} chiamate"
  fi
}

# Un albero del repository con un README cambiato: la riscrittura del prompt
# deve fallire chiusa. Globals: ALBERO (assegnata).
ALBERO=''
prepara_albero() {
  ALBERO="${TMP}/albero"
  local rel p
  rel="${ITEM#"${RADICE}"/}"
  mkdir -p "${ALBERO}/m5_skills/_docente" "${ALBERO}/${rel%/*}" \
    "${ALBERO}/progetti" "${ALBERO}/.claude"
  for p in tools riferimenti; do
    cp -R "${RADICE}/${p}" "${ALBERO}/${p}"
  done
  cp "${RADICE}/.claude/settings.json" "${ALBERO}/.claude/"
  cp -R "${RADICE}/progetti/gestionale-php" "${ALBERO}/progetti/"
  cp "${MOD}/manifest.tsv" "${MOD}/README.md" "${ALBERO}/m5_skills/"
  cp "${LIB}" "${FEEDBACK}" "${ALBERO}/m5_skills/_docente/"
  cp -R "${ITEM}" "${ALBERO}/${rel}"
  git -C "${ALBERO}" -c init.defaultBranch=main init -q
  git -C "${ALBERO}" add -A
}

# La prova nell'albero, con il README trasformato da uno script Python.
# Arguments: $1 il codice Python, che cambia la variabile testo.
con_readme() {
  local rel="${ITEM#"${RADICE}"/}" radice="${TMP}/radice-albero"
  cp -- "${ITEM}/README.md" "${ALBERO}/${rel}/README.md"
  python3 -B -I - "${ALBERO}/${rel}/README.md" "$1" <<'PY'
import sys

percorso = sys.argv[1]
testo = open(percorso, encoding="utf-8").read()
ambiente = {"testo": testo}
exec(sys.argv[2], ambiente)
open(percorso, "w", encoding="utf-8").write(ambiente["testo"])
PY
  rm -rf -- "${radice}"
  mkdir -p "${radice}"
  log_vuoto
  "${ALBERO}/tools/prepara_esercizio.sh" "${ID}" --radice "${radice}" \
    > /dev/null 2>&1 < /dev/null
  run "${ALBERO}/${rel}/_docente/live.sh" "${radice}/${ID}"
}

test_libreria_readme() {
  local n
  prepara_albero
  con_readme 'testo = testo.replace("<!-- prompt 1 -->", "<!-- altro -->")'
  expect "un README senza il prompt 1: 2" 2 'prompt 1'
  n="$(chiamate)"
  if (( n == 0 )); then pass "e nessuna chiamata"; else fail "${n} chiamate"; fi
  con_readme 'testo = testo.replace("<!-- /prompt 2 -->", "<!-- altro -->")'
  expect "un README senza il prompt 2: 2" 2 'prompt 2'
  con_readme '
a, b = testo.split("<!-- prompt 1 -->", 1)
c, d = b.split("<!-- /prompt 1 -->", 1)
c = c.replace(".claude/skills/revisione-pr", "la/skill")
testo = a + "<!-- prompt 1 -->" + c + "<!-- /prompt 1 -->" + d'
  expect "un prompt 1 che non nomina più la cartella della skill: 2" 2 \
    "${PERCORSO_SKILL}"
  n="$(chiamate)"
  if (( n == 0 )); then pass "e nessuna chiamata"; else fail "${n} chiamate"; fi
  con_readme '
a, b = testo.split("<!-- prompt 2 -->", 1)
b = "       Leggi anche .claude/skills/altra-skill/SKILL.md.\n" + b
testo = a + "<!-- prompt 2 -->\n" + b'
  expect "un prompt che nomina un altro percorso sotto .claude/skills: 2" 2 \
    '.claude/skills'
  n="$(chiamate)"
  if (( n == 0 )); then pass "e nessuna chiamata"; else fail "${n} chiamate"; fi
}

test_libreria_fallimenti() {
  live 'FINTO_KO_SU=<role>'
  expect "il prompt 1 fallito: 1, niente dopo" 1 'VERIFICA KO'
  run wc -l "${FINTO_LOG}"
  expect "tre prove e il prompt 1" 0 '4 '
  live 'FINTO_ERRORE_SU=<role>'
  expect "il prompt 1 con un errore: 1" 1 'VERIFICA KO'
  live FINTO_SENZA_SESSIONE=1
  expect "il prompt 1 senza un ID di sessione: 1" 1 'ID di sessione'
  live FINTO_KO_SU=Rivedi
  expect "una prova fallita: 1, niente dopo" 1 'VERIFICA KO' 'FALLITA eval-1'
  run wc -l "${FINTO_LOG}"
  expect "le tre della baseline soltanto" 0 '3 '
  live FINTO_NEGA_SKILL=1
  expect "la skill negata dal permesso: 1, niente dopo" 1 'REPERTO'
  run wc -l "${FINTO_LOG}"
  expect "tre, il prompt 1 e quattro" 0 '8 '
  live FINTO_DUE_SEGMENTI=1
  expect "due segmenti: i turni sono la somma" 0 '8 turni del modello' \
    'in 2 segmenti'
  log_vuoto
  nuovo_ws
  printf '{"eval-1": "Commento di una persona.", "eval-2": "", "eval-3": ""}' \
    > "${TMP}/persona.json"
  run env PN_FEEDBACK="${TMP}/persona.json" "${ITEM}/_docente/live.sh" "${WS}"
  expect "PN_FEEDBACK: il file di una persona" 0 'VERIFICA OK'
  ok_se "PN_FEEDBACK: copiato così com'è" cmp "${TMP}/persona.json" \
    "${WS}/${SKILL}-workspace/iteration-1/feedback.json"
  live PN_LAB_STRUMENTI=Read,Edit,Write
  expect "PN_LAB_STRUMENTI: un elenco diverso, 0" 0 'VERIFICA OK'
  run dal_log '" ".join(r["argv"]) if "<instructions>" in r["prompt"] else ""'
  expect "PN_LAB_STRUMENTI arriva alla scrittura" 0 \
    '--allowedTools Read,Edit,Write --model'
}

test_feedback() {
  echo "feedback_docente.py:"
  local t="${TMP}/feedback" dir
  rm -rf -- "${t}"
  dir="${t}/iteration-1"
  mkdir -p "${dir}/eval-1/with_skill" "${dir}/eval-2/with_skill"
  printf '%s' '{"assertion_results": [
    {"text": "Cita tutto", "passed": false, "evidence": "3 su 4"},
    {"text": "Chiude", "passed": true, "evidence": "ok"},
    {"text": "A mano", "passed": null, "evidence": "da valutare a mano"}]}' \
    > "${dir}/eval-1/with_skill/grading.json"
  printf '%s' '{"assertion_results": [
    {"text": "Chiude", "passed": true, "evidence": "ok"}]}' \
    > "${dir}/eval-2/with_skill/grading.json"
  run python3 -B -I "${FEEDBACK}" "${dir}"
  expect "scrive il file" 0
  run cat "${dir}/feedback.json"
  expect "una riga per caso: le asserzioni non passate, con la prova" 0 \
    '"eval-1"' 'Cita tutto' '3 su 4' '"_nota"' 'uno script'
  expect_absent "ciò che resta a mano non è un commento" 'A mano'
  run python3 -B -I - "${dir}/feedback.json" <<'PY'
import json
import sys

dati = json.load(open(sys.argv[1], encoding="utf-8"))
print(repr(dati["eval-2"]))
PY
  expect "un caso senza asserzioni non passate: la stringa vuota" 0 "''"
  run python3 -B -I "${FEEDBACK}" "${dir}"
  expect "non sovrascrive un feedback.json: 2" 2 'c'\''è già'
  rm -f -- "${dir}/feedback.json" "${dir}/eval-2/with_skill/grading.json"
  run python3 -B -I "${FEEDBACK}" "${dir}"
  expect "senza grading.json: 2" 2 'grading.json'
  run python3 -B -I "${FEEDBACK}"
  expect "senza argomenti: 2" 2 'Uso'
  run python3 -B -I "${FEEDBACK}" "${t}/non-esiste"
  expect "una cartella che non c'è: 2" 2 'non-esiste'
  mkdir -p "${t}/vuota"
  run python3 -B -I "${FEEDBACK}" "${t}/vuota"
  expect "una cartella senza casi: 2" 2 'eval-'
}

# --- il README ----------------------------------------------------------

test_readme_sezioni() {
  local r="${ITEM}/README.md" s
  run grep -n '^## ' "${r}"
  local atteso=1 ultimo=0 riga
  for s in 'Obiettivo' 'Tempo' 'Prerequisiti' \
      "Punto di partenza (tools/prepara_esercizio.sh ${ID})" \
      'Passi in Claude Code' 'Che cosa osservare' \
      "Verifica (tools/verifica.sh ${ID})" 'Se qualcosa va storto' \
      "Impronta d'uso sul piano Pro" 'Per approfondire'; do
    riga="$(grep -nF -x -- "## ${s}" "${r}" | head -n 1)"
    riga="${riga%%:*}"
    if [[ -z "${riga}" ]] || (( riga <= ultimo )); then
      atteso=0
    else
      ultimo="${riga}"
    fi
  done
  if (( atteso == 1 )); then
    pass "le dieci sezioni, in ordine"
  else
    fail "le dieci sezioni: ${OUT}"
  fi
}

test_readme_prompt() {
  local p1 p2 parole
  p1="$(prompt_readme 1)" || p1=''
  p2="$(prompt_readme 2)" || p2=''
  run python3 -B -I - "${p1}" <<'PY'
import re
import sys

testo = sys.argv[1]
TAG = ["role", "context", "instructions", "format", "constraints"]
trovati = re.findall(r"^<([a-z]+)>$", testo, re.M)
chiusi = re.findall(r"^</([a-z]+)>$", testo, re.M)
if trovati != TAG or chiusi != TAG:
    sys.exit("i tag: %r %r" % (trovati, chiusi))
if not re.search(r"<role>\nSei ", testo):
    sys.exit("il ruolo non comincia con «Sei »")
ruolo = re.search(r"<role>\n(.*?)\n</role>", testo, re.S).group(1)
if ruolo.count(".") != 1:
    sys.exit("il ruolo non è una frase: %r" % ruolo)
if len(testo.split()) < 60:
    sys.exit("meno di 60 parole")
istruzioni = re.search(r"<instructions>\n(.*?)\n</instructions>", testo,
                       re.S).group(1)
passi = re.findall(r"^(\d+)\. ", istruzioni, re.M)
if len(passi) < 3:
    sys.exit("passi: %r" % passi)
ultimo = istruzioni[istruzioni.rindex("%s. " % passi[-1]):]
if "python3 -B -I controlla_skill.py .claude/skills/revisione-pr" not in ultimo:
    sys.exit("l'ultimo passo non è il controllo: %r" % ultimo)
print("il template")
PY
  expect "il prompt 1 nel template, l'ultimo passo il controllo" 0 'il template'
  OUT="${p1}"
  RC=0
  expect "il prompt 1 nomina i file, senza incollarli" 0 \
    "${SKILL}-workspace/iteration-1/eval-1/without_skill/outputs/risposta.md" \
    "${PERCORSO_SKILL}/evals/evals.json" \
    'progetti/gestionale-php/docs/convenzioni.md' 'expected_output'
  expect "il prompt 1: i vincoli del file" 0 "${PERCORSO_SKILL}/" 'evals/' \
    '500 righe' 'Markdown semplice' 'qualunque pull' 'request del gestionale' \
    'description'
  expect "il prompt 1: al massimo cinque righe" 0 'cinque righe'
  run python3 -B -I - "${p2}" <<'PY'
import re
import sys

testo = sys.argv[1]
TAG = ["context", "instructions", "format", "constraints"]
if re.findall(r"^<([a-z]+)>$", testo, re.M) != TAG:
    sys.exit("i tag: %r" % re.findall(r"^<([a-z]+)>$", testo, re.M))
print("il seguito")
PY
  expect "il prompt 2: i tag del seguito, senza il ruolo" 0 'il seguito'
  OUT="${p2}"
  RC=0
  expect "il prompt 2 nomina i tre segnali" 0 'grading.json' 'feedback.json' \
    'stream.jsonl'
  expect "il prompt 2 porta le quattro linee guida della guida" 0 \
    'Generalizza' 'snella' 'perché' 'scripts/'
  expect "il prompt 2: l'ultimo passo è il controllo" 0 \
    'python3 -B -I controlla_skill.py .claude/skills/revisione-pr'
  parole="$(printf '%s\n%s\n' "${p1}" "${p2}" | grep -cE '^(Ruolo|Contesto):')"
  if [[ "${parole}" == 0 ]]; then
    pass "nessuna etichetta della forma di prima"
  else
    fail "${parole} etichette"
  fi
}

test_readme_frasi() {
  local r="${ITEM}/README.md" piatto f
  piatto="$(LC_ALL=C tr -s '[:space:]' ' ' < "${r}")"
  local manca=''
  # Le frasi sono lunghe e non si spezzano: una per riga, come nel registro.
  while IFS= read -r f; do
    [[ "${piatto}" == *"${f}"* ]] || manca+=" «${f}»"
  done <<'FRASI'
measure separately whether Claude invokes it on the prompts it should, and whether the output matches what you expect when it does.
Collect a few realistic prompts, run each one in a fresh session with the skill available and again with it turned off
A fresh session matters because leftover context from authoring the skill will mask gaps in the written instructions.
Run Claude on representative tasks without a Skill. … Build three scenarios that test these gaps. … Measure Claude's performance without the Skill.
Write minimal instructions: Create just enough content to address the gaps and pass evaluations.
Iterate: Run evaluations, compare against baseline, and refine.
turn a general-purpose agent into a specialist
Create evaluations BEFORE writing extensive documentation.
/code-review is a bundled skill: its instructions are built into Claude Code, so there is no SKILL.md file on disk to open or edit.
To give every review project rules to follow, add them to your CLAUDE.md.
the review follows your CLAUDE.md, including in a non-interactive -p run. It doesn't read REVIEW.md.
a project or personal skill named code-review runs in place of the bundled one, and the /review alias keeps running the bundled review.
Build your own reviewer: write a reviewer subagent or a review skill
The command works on any plan. The review runs in your own session, so it counts toward your plan's usage or API billing
Changed /code-review at medium effort to also report cleanup and CLAUDE.md conventions findings on models without tuned review settings, including Opus 5.5 and Sonnet 5.5
These can include deterministic scripts or tools for maximum robustness. … code-style — enforces code style, especially styles that Claude does not do well by default.
Store test cases in evals/evals.json inside your skill directory
Start with 2-3 test cases.
Include at least one prompt that tests a boundary condition
run each test case twice: once with the skill and once without it (or with a previous version)
Each pass through the full eval loop gets its own iteration-N/ directory.
Each eval run should start with a clean context — no leftover state from previous runs or from the skill development process.
When improving an existing skill, use the previous version as your baseline. Snapshot it before editing
The other JSON files (grading.json, timing.json, benchmark.json) are produced during the eval process — by the agent, by scripts, or by you.
Add them after you see your first round of outputs
Reserve assertions for things that can be checked objectively.
are hard to decompose into pass/fail checks. These are better caught during human review.
recording PASS or FAIL with specific evidence
use a verification script — scripts are more reliable than LLM judgment for mechanical checks
Require concrete evidence for a PASS. Don't give the benefit of the doubt.
The delta tells you what the skill costs (more time, more tokens) and what it buys (higher pass rate).
In early iterations with just 2-3 test cases and single runs, focus on the raw pass counts and the delta
Remove or replace assertions that always pass in both configurations.
Study assertions that pass with the skill but fail without. This is where the skill is clearly adding value.
Record specific feedback for each test case and save it in the workspace
"The chart is missing axis labels" is actionable; "looks bad" is not.
Empty feedback means the output looked fine
give all three — along with the current SKILL.md — to an LLM and ask it to propose changes
Generalize from feedback. … Keep the skill lean. … Explain the why. … Bundle repeated work.
Rerun all test cases in a new iteration-<N+1>/ directory.
Effective skills are grounded in real expertise. The key is feeding domain-specific context into the creation process.
Then extract the reusable pattern into a skill.
Internal documentation, runbooks, and style guides
When an agent makes a mistake you have to correct, add the correction to the gotchas section.
This is more reliable than describing the format in prose, because agents pattern-match well against concrete structures.
Read agent execution traces, not just final outputs.
The most valuable negative test cases are near-misses — queries that share keywords or concepts with your skill but actually need something different.
Model behavior is nondeterministic — the same query might trigger the skill on one run but not the next.
Avoid adding specific keywords from failed queries — that's overfitting.
Yes, and allow Claude to edit files in this project's .claude folder for this session
Shell command permission check failed for pattern "..."
This command requires approval
They don't apply to … arbitrary subprocesses that read or write files indirectly, like a Python or Node script that opens files itself.
Edit rules apply to all built-in tools that edit files.
A skill can grant itself broad tool access, so review the allowed-tools of skills checked into a repository before you run Claude Code there.
The trailing * enables prefix matching, so Bash(git diff *) allows any command starting with git diff.
FRASI
  if [[ -z "${manca}" ]]; then
    pass "le frasi di Anthropic e della guida, parola per parola"
  else
    fail "mancano:${manca}"
  fi
  manca=''
  local piattaforma='https://platform.claude.com/docs/en/agents-and-tools'
  for f in 'https://code.claude.com/docs/en/skills' \
      'https://code.claude.com/docs/en/code-review-local' \
      'https://code.claude.com/docs/en/changelog' \
      'https://code.claude.com/docs/en/permission-modes' \
      "${piattaforma}/agent-skills/best-practices" \
      "${piattaforma}/agent-skills/overview" \
      'https://agentskills.io/skill-creation/evaluating-skills' \
      'https://agentskills.io/skill-creation/best-practices' \
      'https://agentskills.io/skill-creation/optimizing-descriptions' \
      'https://claude.dev/blog/lessons-from-building-claude-code'; do
    [[ "${piatto}" == *"${f}"* ]] || manca+=" ${f}"
  done
  if [[ -z "${manca}" ]]; then
    pass "gli indirizzi delle frasi"
  else
    fail "mancano:${manca}"
  fi
  manca=''
  for f in "tools/prepara_esercizio.sh ${ID}" \
      "tools/prove_skill.sh ${ID} 1 without" \
      "tools/prove_skill.sh ${ID} copia esempio" \
      "tools/prove_skill.sh ${ID} 1 with" \
      "tools/prove_skill.sh ${ID} 2 with" "tools/verifica.sh ${ID}" \
      'old_skill' 'skill-snapshot/' 'feedback.json' 'da valutare a mano' \
      'code-review' "Skill(${SKILL})" 'allowed-tools' 'undici' 'Sonnet' \
      'medium' 'M5-D05' 'con uno script Python dentro un comando Bash' \
      'leggete ogni comando prima di approvarlo' \
      'con Read e Skill consentiti' \
      'si ferma prima, con l'\''uscita 2' \
      'un esito da segnalare al docente, con lo stream' \
      'nessuna chiamata riuscita a' 'né respinta dallo strumento' \
      'la chiamata è «respinta dallo strumento»'; do
    [[ "${piatto}" == *"${f}"* ]] || manca+=" «${f}»"
  done
  if [[ -z "${manca}" ]]; then
    pass "i comandi, nell'ordine dei passi, e ciò che il README deve dire"
  else
    fail "mancano:${manca}"
  fi
  run grep -cxF '       cd -' "${r}"
  expect "il passo 6 torna nella cartella da cui parte il passo 7" 0 1
}

test_readme_parole() {
  local r="${ITEM}/README.md"
  local vietate='smentit|prossima sessione|\boggi\b|\bdomani\b|pranzo'
  vietate+='|Percorso A\b|il vostro codice|i vostri file'
  run grep -nEi "${vietate}" "${r}"
  expect "nessuna «smentita», niente orario, niente codice vostro" 1
  # Il prompt resta com'è registrato: le forme valgono per ciò che ha intorno.
  local forme='un `SKILL\.md`|nel `SKILL\.md`|del `SKILL\.md`'
  forme+='|[Ii]l `SKILL\.md`'
  run grep -nE "${forme}" "${r}"
  expect "le forme: «uno», «nello», «dello», «lo» SKILL.md" 1
  run grep -nE '(il|sul|del) branch\b' "${r}"
  expect "le forme: «ramo», fuori dalle richieste registrate" 1
  run grep -nE "${INTERNI}" "${r}"
  expect "nessun nome interno nel README" 1
  run grep -rnE "${INTERNI}" "${ITEM}/verifica.py" "${ITEM}/verifica.sh" \
    "${ITEM}/verita.json" "${ITEM}/prove" "${ITEM}/esercizio/.claude/settings.json" \
    "${ITEM}/esercizio/.gitignore"
  expect "nessun nome interno nei file per i partecipanti" 1
  run grep -rnE "${INTERNI}" "${ITEM}/_docente" "${ITEM}/soluzione" "${LIB}" \
    "${FEEDBACK}" "${FINTO_PY}"
  expect "nessun nome interno nei file del docente" 1
  run grep -nE 'export_ticket|ReportTicketAperti|CalcoloTotali|clienti_lista' \
    "${r}"
  expect "il README non anticipa i pull request" 1
  run cat "${ITEM}/soluzione/LEGGIMI.md"
  expect "soluzione/LEGGIMI.md dice da dove vengono le esecuzioni" 0 \
    'registrazione'
}

# Il README e la registrazione: le righe che cita sono quelle che la verifica
# stampa sugli stream di soluzione/.
test_readme_registrazione() {
  nuovo_ws
  cp -R "${ITEM}/soluzione/." "${WS}/" || exit 2
  run "${RADICE}/tools/verifica.sh" "${ID}" --radice "${RAD}"
  expect "la verifica su soluzione/: 0" 0 'Fatto: la skill passa'
  printf '%s\n' "${OUT}" > "${TMP}/uscita.txt"
  run python3 -B -I "${MOD}/_docente/controlla_registrazione.py" \
    "${ITEM}/README.md" "${TMP}/uscita.txt" <<'FRASI'
= with_skill 3, without_skill 2 asserzioni passate: confermata (una sola esecuzione per caso)
= with_skill 4, without_skill 1 asserzione passata: confermata (una sola esecuzione per caso)
= Conteggi: without_skill 5 su 12; with_skill 10 su 12
= Delta, with_skill meno without_skill: pass rate +0,417; tempo +5,9 s; token +23957
= with_skill 4, old_skill 3 asserzioni passate: confermata (una sola esecuzione per caso)
= with_skill 4, old_skill 4 asserzioni passate: non distinguibile (una sola esecuzione per caso)
= Conteggi: old_skill 10 su 12; with_skill 12 su 12
= Delta, with_skill meno old_skill: pass rate +0,167; tempo -0,5 s; token +35096
= iterazione 1: revisione-pr chiamata 3 su 3 in with_skill
= iterazione 2: revisione-pr chiamata 3 su 3 in with_skill
= Claude ha scelto da sé code-review
= pr-1, regole inserite citate: without_skill 0 su 10; with_skill 9 su 10
= pr-2, regole inserite citate: without_skill 0 su 3; with_skill 3 su 3
= pr-3, regole inserite citate: without_skill 0 su 4; with_skill 4 su 4
= pr-1, regole inserite citate: old_skill 9 su 10; with_skill 10 su 10
= Skill chiamata: no; dovrebbe attivarla: no
= Consumo, senza le esecuzioni riusate: 7 chiamate, 33 turni, 618208 token, 164,6 s
= Consumo, senza le esecuzioni riusate: 4 chiamate, 22 turni, 470106 token, 91,2 s
= 63896 token (usage: 35217)
= 9 turni in 2 segmenti, 169250 token (usage: 143238)
= Fatto: la skill passa il controllo del file, le due iterazioni ci sono, i commenti anche, e le due versioni sono diverse.
R Nella registrazione del corso (3 novembre 2026, Claude Code 2.1.317, Sonnet
R sull'account del docente, un piano Max
R 1.088.314
R 196.122
R 537.292
R 733.414
R bozza/revisione-pr/
R Use modelUsage, or model_usage in Python, for whole-tree token accounting; the usage field undercounts as soon as nesting occurs.
R allowed-tools: Bash(python3 *) Bash(git diff *)
R Bash(python3 ${CLAUDE_SKILL_DIR}/scripts/controlli_ovvi.py *)
R Nessuna riga aggiunta rispetto a main
! da 10 a 20 turni attesi
! da 4 a 10 turni attesi
! in una prova del corso
! Read e Skill, senza Edit né Write, passa in tutte e due
! la regola `deny` lo ferma
! Il reperto vuol dire che quella riga non c'è più
FRASI
  expect "il README cita le righe del controllo" 0 'in ordine'
}

# Ciò che il README dice dei prodotti della prova sta in quei file.
test_readme_prodotti() {
  local skill="${ITEM}/soluzione/${PERCORSO_SKILL}"
  local esempio="${RADICE}/riferimenti/skill-di-esempio/audit-configurazione"
  run grep -xF 'allowed-tools: Bash(python3 *) Bash(git diff *)' \
    "${skill}/SKILL.md"
  expect "la nota: la seconda versione concede proprio questo" 0 'python3 *'
  run grep -F 'allowed-tools' \
    "${ITEM}/soluzione/${SKILL}-workspace/iteration-1/skill-snapshot/SKILL.md"
  expect "la nota: la prima versione non lo concede" 1
  run grep -F 'print("Nessuna riga aggiunta rispetto a", BASE)' \
    "${skill}/scripts/segnala.py"
  expect "la nota: segnala.py stampa proprio questo" 0 'Nessuna riga aggiunta'
  run grep -F 'check=False' "${skill}/scripts/segnala.py"
  expect "la nota: segnala.py non guarda se git è riuscito" 0 'check=False'
  run grep -F 'Bash(python3 ${CLAUDE_SKILL_DIR}/scripts/controlli_ovvi.py *)' \
    "${esempio}/SKILL.md"
  expect "la nota: la forma stretta è quella dell'esempio" 0 'controlli_ovvi.py'
}

test_readme() {
  echo "Il README:"
  test_readme_sezioni
  test_readme_prompt
  test_readme_frasi
  test_readme_parole
  test_readme_registrazione
  test_readme_prodotti
}

# --- gli strumenti ------------------------------------------------------

test_strumenti() {
  echo "shellcheck, check_handson, Python 3.8, bash 3.2:"
  local f
  for f in "${ITEM}/verifica.sh" "${ITEM}/prove/prima.sh" \
      "${ITEM}/_docente/live.sh" "${LIB}" "${SELF}"; do
    run bash -c 'cd "$1" && shellcheck -x -- "$2"' _ "${RADICE}" "${f}"
    expect "shellcheck pulito: ${f#"${MOD}"/}" 0
  done
  run "${RADICE}/tools/check_handson.sh"
  expect_absent "check_handson non segnala niente di M5-E02" "${ID}"
  expect_absent "check_handson non segnala la libreria" 'lib_lab_m5'
  for f in "${ITEM}/verifica.py" "${ITEM}/_docente/verita.py" "${FEEDBACK}" \
      "${FINTO_PY}"; do
    run python3 -B -I -c '
import ast
import sys

ast.parse(open(sys.argv[1], encoding="utf-8").read(), feature_version=(3, 8))
print("ok")' "${f}"
    expect "la sintassi di Python 3.8: ${f##*/}" 0 ok
  done
  local recenti='readarray|mapfile|declare -A|local -A|wait -n'
  recenti+='|\$\{[a-z_]+(,,|\^\^)\}'
  run grep -nE "${recenti}" "${LIB}" "${ITEM}/verifica.sh" \
    "${ITEM}/prove/prima.sh" "${ITEM}/_docente/live.sh"
  expect "niente che il bash 3.2 non abbia" 1
  run python3 -B -I -c '
import sys

for nome in sys.argv[1:]:
    with open(nome, encoding="utf-8") as fh:
        for numero, riga in enumerate(fh, 1):
            if len(riga.rstrip("\n")) > 80:
                print("%s:%d" % (nome, numero))' "${LIB}" \
    "${ITEM}/verifica.sh" "${ITEM}/prove/prima.sh" "${ITEM}/_docente/live.sh"
  if [[ "${RC}" == 0 && -z "${OUT}" ]]; then
    pass "gli script stanno in 80 colonne"
  else
    fail "oltre 80 colonne: ${OUT}"
  fi
}

main() {
  exec < /dev/null
  prepara_ambiente
  test_file_elemento
  test_punto_di_partenza
  test_pull_request
  test_verita
  test_giudici
  test_ciclo
  test_versioni_uguali
  test_garanzie
  echo "La libreria e live.sh:"
  test_libreria_argomenti
  test_libreria_modalita
  test_libreria_riepilogo
  test_libreria_stream_di_prima
  test_libreria_da_capo
  test_libreria_bozza
  test_libreria_rifiuti
  test_libreria_readme
  test_libreria_fallimenti
  test_feedback
  test_readme
  test_strumenti
  echo "test_m5_e02: PASS=${PASS} FAIL=${FAIL}"
  (( FAIL == 0 )) || exit 1
  if (( PASS != CASES )); then
    echo "test_m5_e02: ${PASS} casi, attesi ${CASES}" >&2
    exit 2
  fi
}

main "$@"
