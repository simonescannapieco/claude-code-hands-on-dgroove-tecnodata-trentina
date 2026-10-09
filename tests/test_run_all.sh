#!/bin/bash
#
# test_run_all.sh -- verifica tools/run_all.sh su copie dell'albero di
# prova: tutti gli elementi o solo quelli dati; i KO (verifica che passa
# già sul punto di partenza, soluzione che non basta, riga senza cartella,
# live.sh che fallisce); soluzione/applica.sh; --live con gli SKIP (nessun
# live.sh, elemento trainer-api senza chiave), con ANTHROPIC_API_KEY tolta
# agli elementi non trainer-api e mai stampata, con i log in PN_LIVE_LOGS;
# la copia per i partecipanti (soluzione SKIP); «0 item(s)» con i manifest
# vuoti; le precondizioni (manifest o modulo mancanti, intestazione
# sbagliata, ID sconosciuto, opzione sbagliata, PN_LIVE_LOGS non valido).
#
# Uso:    tests/test_run_all.sh
# Uscita: 0 = tutti i test passano · 1 = almeno un test fallito
#         2 = precondizione (git mancante, albero di prova assente)
set -uo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly REPO="${SELF%/tests/*}"
readonly TOOLS="${REPO}/tools"
readonly FIXTURE="${REPO}/tests/fixtures/handson"
readonly SEZ='m1_fondamenti_llm/s1_fondamenti_llm'
readonly REL_E01="${SEZ}/m1_e1_prova/M1-E01_inventario"
readonly REL_D01="${SEZ}/m1_1_prova/M1-D01_saluto"
readonly CHIAVE_FINTA='chiave-finta-di-prova-0042'
readonly TAB=$'\t'
TMP="$(mktemp -d)" || { echo "mktemp non riesce" >&2; exit 2; }
readonly TMP
trap 'rm -rf -- "${TMP}"' EXIT
unset PN_HANDSON_ROOT PN_WORKSPACE_ROOT PN_LIVE_LOGS ANTHROPIC_API_KEY
PASS=0
FAIL=0
RC=0
OUT=''

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

# Esegue un comando; RC e OUT (STDOUT e STDERR insieme) per expect.
run() { OUT="$("$@" 2>&1)"; RC=$?; }

# Uscita attesa E parola chiave attesa (RU-01.T3).
# Arguments: $1 il nome, $2 l'uscita attesa, $3 la parola (grep -F).
expect() {
  if (( RC == $2 )) && grep -qF -- "$3" <<< "${OUT}"; then
    pass "$1"
  else
    fail "$1 (rc=${RC}, attesa $2, parola «$3»): ${OUT:0:400}"
  fi
}

# Nessun falso positivo: la parola NON c'è (RU-01.T5).
expect_absent() {
  if grep -qF -- "$2" <<< "${OUT}"; then
    fail "$1: «$2» c'è"
  else
    pass "$1"
  fi
}

# Un albero di prova completo: la fixture, i file veri della radice e gli
# strumenti, come repository git con un commit. Arguments: $1 la cartella.
make_repo() {
  local d="$1" f
  mkdir -p "${d}" && cp -Rp "${FIXTURE}/." "${d}/" || return 1
  for f in README.md PRIMA_DEL_CORSO.md CLAUDE.md .gitattributes .gitignore; do
    cp -p "${REPO}/${f}" "${d}/${f}" || return 1
  done
  mkdir -p "${d}/.claude" "${d}/tools" "${d}/tests" || return 1
  cp -p "${REPO}/.claude/settings.json" "${d}/.claude/" || return 1
  cp -p "${TOOLS}"/*.sh "${d}/tools/" || return 1
  cp -p "${REPO}/tests/esegui_test.sh" "${d}/tests/" || return 1
  git -C "${d}" init -q && git -C "${d}" add -A \
    && git -C "${d}" -c user.name=Test -c user.email=test@example.org \
      -c commit.gpgsign=false commit -q --no-verify -m albero
}

# run_all.sh sull'albero $1, con gli argomenti che seguono.
run_all() {
  local r="$1"
  shift
  run env PN_HANDSON_ROOT="${r}" "${TOOLS}/run_all.sh" "$@"
}

# Cambia il campo $3 (1-8) della riga di $2 nel manifest del Modulo 1.
# Arguments: $1 l'albero, $2 l'ID, $3 il campo, $4 il valore.
cambia_campo() {
  local m="$1/m1_fondamenti_llm/manifest.tsv"
  awk -v id="$2" -v n="$3" -v v="$4" 'BEGIN { FS = OFS = "\t" }
    $1 == id { $n = v } { print }' "${m}" > "${m}.nuovo" \
    && mv "${m}.nuovo" "${m}"
}

# Sostituisce _docente/live.sh di M1-D01. Arguments: $1 l'albero, $2 il corpo.
finto_live() {
  local f="$1/${REL_D01}/_docente/live.sh"
  printf '#!/bin/bash\nset -euo pipefail\n%s\n' "$2" > "${f}"
  chmod 755 "${f}"
}

t_tutti() {
  local r="${TMP}/tutti"
  make_repo "${r}" || { fail "albero di prova (tutti)"; return; }
  run_all "${r}"
  expect "prova tutti gli elementi" 0 "2 item(s): 2 ok, 0 KO, 0 SKIP"
  expect "una riga per elemento" 0 "M1-D01   ok"
  expect_absent "nessun KO quando va tutto bene" "KO:"
  run_all "${r}" M1-E01
  expect "solo gli ID dati" 0 "1 item(s): 1 ok"
  run_all "${r}" M1-E09
  expect "ID sconosciuto" 2 "trovate 0"
  run_all "${r}" --tutto
  expect "opzione sconosciuta" 2 "opzione sconosciuta"
  run env PN_HANDSON_ROOT="${r}" PN_LIVE_LOGS="${r}/nessuna" \
    "${TOOLS}/run_all.sh" --live
  expect "PN_LIVE_LOGS che non è una cartella" 2 "PN_LIVE_LOGS"
}

t_live() {
  local r="${TMP}/live"
  make_repo "${r}" || { fail "albero di prova (live)"; return; }
  mkdir -p "${r}-log"
  run env PN_HANDSON_ROOT="${r}" PN_LIVE_LOGS="${r}-log" \
    ANTHROPIC_API_KEY="${CHIAVE_FINTA}" "${TOOLS}/run_all.sh" --live
  expect "--live esegue live.sh" 0 "M1-D01   ok · live ok"
  expect "--live senza live.sh: SKIP" 0 "live SKIP: nessun _docente/live.sh"
  expect "uno SKIP non è un ok in più" 0 "2 ok, 0 KO, 1 SKIP"
  expect_absent "la chiave non viene mai stampata" "${CHIAVE_FINTA}"
  run cat "${r}-log/M1-D01.log"
  expect "al live.sh di un elemento Pro la chiave non arriva" 0 \
    "chiave API assente"
  cambia_campo "${r}" M1-D01 3 trainer-api
  run_all "${r}" --live M1-D01
  expect "trainer-api senza chiave: SKIP" 0 "live SKIP: elemento trainer-api"
  run env PN_HANDSON_ROOT="${r}" PN_LIVE_LOGS="${r}-log" \
    ANTHROPIC_API_KEY="${CHIAVE_FINTA}" "${TOOLS}/run_all.sh" --live M1-D01
  expect "trainer-api con la chiave: live ok" 0 "live ok"
  expect_absent "e la chiave non viene stampata" "${CHIAVE_FINTA}"
  run cat "${r}-log/M1-D01.log"
  expect "al live.sh trainer-api la chiave arriva" 0 "chiave API presente"
  cambia_campo "${r}" M1-D01 3 claude-code-pro
  finto_live "${r}" 'echo "esito diverso"; exit 1'
  run_all "${r}" --live M1-D01
  expect "live.sh che fallisce: KO" 1 "live: _docente/live.sh esce 1"
  expect "mostra il log del KO" 1 "| esito diverso"
}

t_ko() {
  local r="${TMP}/ko" riga
  make_repo "${r}" || { fail "albero di prova (ko)"; return; }
  printf 'ciao\n' > "${r}/${REL_D01}/demo/saluto.txt"
  run_all "${r}"
  expect "verifica che passa già sul punto di partenza: KO" 1 "esce 0, non 1"
  expect "e l'altro elemento resta ok" 1 "1 ok, 1 KO"
  rm -f "${r}/${REL_D01}/demo/saluto.txt"
  printf '4\n' > "${r}/${REL_E01}/soluzione/conteggio.txt"
  run_all "${r}" M1-E01
  expect "soluzione che non basta: KO" 1 "con soluzione/ applicata"
  rm -f "${r}/${REL_E01}/soluzione/conteggio.txt"
  # shellcheck disable=SC2016  # $1 è dello script applica.sh di prova
  printf '%s\n' '#!/bin/bash' 'set -euo pipefail' \
    'printf "3\n" > "$1/conteggio.txt"' > "${r}/${REL_E01}/soluzione/applica.sh"
  chmod 755 "${r}/${REL_E01}/soluzione/applica.sh"
  run_all "${r}" M1-E01
  expect "soluzione/applica.sh al posto della copia" 0 "1 ok, 0 KO"
  riga="M1-E02${TAB}esercizio${TAB}claude-code-pro${TAB}s1_fondamenti_llm"
  riga+="${TAB}m1_e1_prova${TAB}slides/practice/m1_demo_stesso_prompt"
  riga+="/m1_e1_prova${TAB}5${TAB}Senza cartella"
  printf '%s\n' "${riga}" >> "${r}/m1_fondamenti_llm/manifest.tsv"
  run_all "${r}"
  expect "riga senza cartella: KO dell'elemento" 1 \
    "la riga del manifest o la cartella non vanno"
}

t_manifest() {
  local r="${TMP}/manifest" m
  make_repo "${r}" || { fail "albero di prova (manifest)"; return; }
  m="${r}/m1_fondamenti_llm/manifest.tsv"
  head -n 1 "${m}" > "${m}.nuovo" && mv "${m}.nuovo" "${m}"
  run_all "${r}"
  expect "manifest senza elementi: 0 item(s)" 0 "0 item(s)"
  printf 'id\tkind\n' > "${r}/m2_prompting_avanzato/manifest.tsv"
  run_all "${r}"
  expect "intestazione sbagliata: precondizione" 2 "intestazione"
  rm -f "${r}/m2_prompting_avanzato/manifest.tsv"
  run_all "${r}"
  expect "manifest assente: precondizione" 2 "manifest.tsv"
  rm -rf -- "${r}/m9_wrap_up"
  cp -p "${r}/m3_funzionalita_claude/manifest.tsv" \
    "${r}/m2_prompting_avanzato/manifest.tsv"
  run_all "${r}"
  expect "modulo assente: precondizione" 2 "modulo 9"
}

t_copia_partecipanti() {
  local r="${TMP}/copia"
  make_repo "${r}" || { fail "albero di prova (copia)"; return; }
  rm -rf -- "${r}/${REL_D01}/soluzione" "${r}/${REL_E01}/soluzione"
  printf 'copia per i partecipanti\n' > "${r}/.copia_partecipanti"
  run_all "${r}"
  expect "nella copia per i partecipanti la soluzione è SKIP" 0 \
    "soluzione SKIP (copia per i partecipanti)"
  expect "e il riepilogo conta gli SKIP" 0 "2 ok, 0 KO, 2 SKIP"
}

# TMPDIR dentro ~/.claude (HOME finta): gli spazi di lavoro usa e getta
# vanno in /tmp, con una sola nota; con TMPDIR altrove nessuna nota.
t_temp() {
  local r="${TMP}/temp" casa="${TMP}/temp_casa" note
  make_repo "${r}" || { fail "albero di prova (temp)"; return; }
  mkdir -p "${casa}/.claude/jobs/j1/tmp" "${casa}/altro"
  run env PN_HANDSON_ROOT="${r}" HOME="${casa}" \
    TMPDIR="${casa}/.claude/jobs/j1/tmp" "${TOOLS}/run_all.sh" --live
  expect "con TMPDIR dentro ~/.claude gli elementi passano" 0 \
    "2 item(s): 2 ok, 0 KO, 1 SKIP"
  expect "una nota dice dove vanno i temporanei" 0 \
    "i file temporanei vanno in /tmp"
  note="$(grep -c 'i file temporanei vanno in /tmp' <<< "${OUT}")"
  if [[ "${note}" == "1" ]]; then
    pass "la nota compare una volta sola"
  else
    fail "la nota compare ${note} volte"
  fi
  run env PN_HANDSON_ROOT="${r}" HOME="${casa}" TMPDIR="${casa}/altro" \
    "${TOOLS}/run_all.sh"
  expect "con TMPDIR altrove gli elementi passano" 0 "2 item(s): 2 ok, 0 KO"
  expect_absent "e nessuna nota" "i file temporanei vanno in /tmp"
}

main() {
  command -v git >/dev/null 2>&1 || { echo "manca git" >&2; exit 2; }
  [[ -d "${FIXTURE}" ]] || { echo "manca ${FIXTURE}" >&2; exit 2; }
  echo "test_run_all.sh"
  t_tutti
  t_live
  t_ko
  t_manifest
  t_copia_partecipanti
  t_temp
  echo "PASS=${PASS} FAIL=${FAIL}"
  (( FAIL == 0 )) || exit 1
}

main "$@"
