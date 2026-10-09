#!/bin/bash
#
# test_lib_handson.sh -- verifica il contratto d'aula di tools/lib_handson.sh:
# la riga stampata da handson::run, incollata in bash, rifà esattamente ciò
# che è stato eseguito (stesso array, apici e $ compresi, anche su più
# righe); HANDSON_SHOW_CMD=0 zittisce; le pause non scattano senza
# terminale; handson::check/finish danno 0 o 1; le precondizioni danno 2.
# Poi handson::claude_p con un claude finto: l'argv esatto (-p, strumenti
# consentiti, modello, modalità di permesso, --permission-prompts none,
# --output-format json, gli argomenti in più), ANTHROPIC_API_KEY tolta fuori
# dagli elementi trainer-api e passata a quelli, mai stampata; i rifiuti
# (bypassPermissions, auto, --dangerously-skip-permissions, argomenti che
# il helper imposta da sé, Fable, --bare, una chiave sulla riga di comando,
# prompt che comincia con -, claude assente). Infine json_field e
# json_keys (con jq), tmpdir, la doppia source e la libreria non eseguibile.
# Il file fa anche da pilota: con --scenario <nome> carica la libreria ed
# esegue lo scenario, così il codice degli scenari passa per shellcheck.
#
# Uso:    tests/test_lib_handson.sh
# Uscita: 0 = tutti i test passano · 1 = almeno un test fallito
#         2 = precondizione (la libreria non c'è)
set -uo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly REPO="${SELF%/tests/*}"
readonly LIB="${REPO}/tools/lib_handson.sh"
readonly CHIAVE_FINTA='chiave-finta-di-prova-0042'
readonly JSON='{"result":"ciao","n":3,"o":{"a":1}}'
TMP=''
PASS=0
FAIL=0
RC=0
OUT=''

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

# Esegue un comando; RC e OUT (STDOUT e STDERR insieme) per expect.
run() { OUT="$("$@" 2>&1)"; RC=$?; }

# Uno scenario di questo stesso file, con il claude finto nel PATH.
# Arguments: le variabili d'ambiente (NOME=valore), poi -- , poi lo
# scenario e i suoi argomenti.
scenario() {
  local -a variabili=()
  while (( $# > 0 )) && [[ "$1" != "--" ]]; do
    variabili+=("$1")
    shift
  done
  shift
  run env PATH="${TMP}/bin:${PATH}" ${variabili[@]+"${variabili[@]}"} \
    bash "${SELF}" --scenario "$@"
}

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

# Gli argomenti che il claude finto ha ricevuto, su una riga.
argv_finto() { grep '^ARG:' <<< "${OUT}" | tr '\n' ' '; }

# --- Gli scenari (eseguiti con la libreria caricata) ---------------------

# shellcheck disable=SC2016  # 'x$y' è un token letterale, di proposito
scenario_run() {
  case "$1" in
    corto) handson::run printf '%s|' a 'b c' "d'e" '' 'x$y' ;;
    lungo) handson::run printf '%s|' --uno 'valore lungo lungo lungo lungo' \
             --due 'un altro valore lungo' --tre "con l'apice" fine ;;
    muto) HANDSON_SHOW_CMD=0 handson::run printf 'muto|' ;;
  esac
}

scenario_varie() {
  local d q
  case "$1" in
    pausa) handson::pause; echo "dopo" ;;
    check_ko) handson::check vero true; handson::check falso false
              handson::finish ;;
    check_ok) handson::check vero true; handson::finish ;;
    manca) handson::need_tools comando-che-non-esiste-qui ;;
    tmpdir) handson::tmpdir d; printf 'DIR:%s\n' "${d}"
            if [[ -d "${d}" ]]; then echo "esiste"; fi ;;
    base) handson::init_temp_base; handson::tmpdir d
          printf 'BASE:%s\nDIR:%s\n' "${HANDSON_TEMP_BASE}" "${d}" ;;
    doppia) # shellcheck source=../tools/lib_handson.sh
            source "${LIB}"; echo "ok" ;;
    vuoto) handson::quote_into q ''; printf '[%s]\n' "${q}" ;;
    campo) printf '%s' "${JSON}" | handson::json_field "$2" ;;
    chiavi) printf '%s' "${JSON}" | handson::json_keys ;;
  esac
}

pilota() {
  # shellcheck source=../tools/lib_handson.sh
  source "${LIB}"
  case "$1" in
    run) shift; scenario_run "$@" ;;
    claude) shift; handson::claude_p "$@" ;;
    *) scenario_varie "$@" ;;
  esac
}

# --- I test ---------------------------------------------------------------

t_stesso_array() {
  local cmd="${TMP}/comando.txt" diretto incollato
  diretto="$(bash "${SELF}" --scenario run lungo 2> "${cmd}")"
  # La riga stampata è fatta dai token costanti di questo test: rieseguirla
  # con bash è proprio la prova che si incolla.
  sed -e '1s/^  \$ //' "${cmd}" > "${TMP}/comando.sh"
  incollato="$(bash "${TMP}/comando.sh")"
  if [[ -n "${diretto}" && "${diretto}" == "${incollato}" ]]; then
    pass "la riga stampata, incollata, rifà lo stesso comando (su più righe)"
  else
    fail "stampato ≠ eseguito: «${diretto}» / «${incollato}»"
  fi
  if grep -q ' \\$' "${cmd}" && grep -qF "'con l'\\''apice'" "${cmd}"; then
    pass "a capo prima delle opzioni lunghe e apice reso '\\''"
  else
    fail "impaginazione: $(< "${cmd}")"
  fi
  diretto="$(bash "${SELF}" --scenario run corto 2> "${cmd}")"
  sed -e '1s/^  \$ //' "${cmd}" > "${TMP}/comando.sh"
  incollato="$(bash "${TMP}/comando.sh")"
  if [[ "${diretto}" == "a|b c|d'e||x\$y|" && "${diretto}" == "${incollato}" ]]
  then
    pass "vuoto, spazi, apice e \$ restano quelli eseguiti"
  else
    fail "token particolari: «${diretto}» / «${incollato}»"
  fi
  scenario -- run muto
  expect "HANDSON_SHOW_CMD=0 esegue senza mostrare" 0 "muto|"
  expect_absent "e la riga del comando non c'è" '  $ '
}

# Il comando claude -p stampato, incollato in bash con lo stesso claude
# finto, riceve esattamente gli argomenti di quello eseguito.
t_claude_stampato() {
  local cmd="${TMP}/claude_cmd.txt" diretto incollato
  diretto="$(env PATH="${TMP}/bin:${PATH}" bash "${SELF}" --scenario \
    claude sonnet 'Read,Glob' "Riassumi l'indice" --resume abc123 \
    2> "${cmd}")"
  # La riga stampata è fatta dai token costanti di questo test.
  sed -e '1s/^  \$ //' "${cmd}" > "${TMP}/claude_cmd.sh"
  incollato="$(env PATH="${TMP}/bin:${PATH}" bash "${TMP}/claude_cmd.sh")"
  if [[ "${diretto}" == *"ARG:--setting-sources"* \
      && "${diretto}" == "${incollato}" ]]; then
    pass "claude -p: argv stampato = eseguito, --setting-sources compreso"
  else
    fail "claude -p stampato ≠ eseguito: «${diretto}» / «${incollato}»"
  fi
}

# La base dei temporanei: con TMPDIR dentro ~/.claude (HOME finta) diventa
# /tmp, con una nota; fuori da ~/.claude resta TMPDIR, senza nota.
t_temp_base() {
  local casa="${TMP}/casa" job
  job="${casa}/.claude/jobs/j1/tmp"
  mkdir -p "${job}" "${casa}/altro" "${casa}/.claudette" "${TMP}/vari"
  ln -s "${job}" "${TMP}/vari/verso_claude"
  scenario HOME="${casa}" TMPDIR="${job}" -- base
  expect "TMPDIR dentro ~/.claude: la base diventa /tmp" 0 "BASE:/tmp"
  expect "e una nota su STDERR lo dice" 0 "i file temporanei vanno in /tmp"
  expect "la cartella temporanea nasce in /tmp" 0 "DIR:/tmp/handson."
  scenario HOME="${casa}" TMPDIR="${TMP}/vari/verso_claude" -- base
  expect "anche attraverso un collegamento simbolico" 0 "BASE:/tmp"
  scenario HOME="${casa}" TMPDIR="${casa}/altro" -- base
  expect "TMPDIR fuori da ~/.claude resta quello" 0 "BASE:${casa}/altro"
  expect_absent "e nessuna nota" "i file temporanei vanno in /tmp"
  scenario HOME="${casa}" TMPDIR="${casa}/.claudette" -- base
  expect "una cartella che comincia per .claude non conta" 0 \
    "BASE:${casa}/.claudette"
}

t_contratto() {
  scenario -- pausa
  expect "senza terminale la pausa non aspetta" 0 "dopo"
  expect_absent "e non chiede Invio" "[Invio"
  scenario -- check_ko
  expect "un controllo KO: uscita 1" 1 "VERIFICA KO   falso"
  scenario -- check_ok
  expect "tutti i controlli OK: uscita 0" 0 "VERIFICA OK   vero"
  expect_absent "e nessun KO" "KO"
  scenario -- manca
  expect "strumento mancante: uscita 2" 2 \
    "manca lo strumento: comando-che-non-esiste-qui"
}

t_claude_argv() {
  local atteso='ARG:-p ARG:Riassumi il file ARG:--allowedTools ARG:Read,Glob '
  atteso+='ARG:--model ARG:sonnet ARG:--permission-mode ARG:dontAsk '
  atteso+='ARG:--permission-prompts ARG:none ARG:--output-format ARG:json '
  atteso+='ARG:--setting-sources ARG:project,local '
  atteso+='ARG:--resume ARG:abc123 '
  scenario ANTHROPIC_API_KEY="${CHIAVE_FINTA}" -- \
    claude sonnet 'Read,Glob' 'Riassumi il file' --resume abc123
  if (( RC == 0 )) && [[ "$(argv_finto)" == "${atteso}" ]]; then
    pass "argv di claude -p esatto, nell'ordine"
  else
    fail "argv: «$(argv_finto)» (rc=${RC})"
  fi
  expect "fuori da trainer-api la chiave non arriva a claude" 0 "CHIAVE:assente"
  expect "e lo dice" 0 "la tolgo per questo comando"
  expect "il comando si vede prima di girare" 0 "--permission-prompts none"
  expect "solo le impostazioni di progetto e locali" 0 \
    "--setting-sources project,local"
  expect_absent "la chiave non viene mai stampata" "${CHIAVE_FINTA}"
  expect_absent "mai --dangerously-skip-permissions" "dangerously"
  scenario HANDSON_ENV=trainer-api ANTHROPIC_API_KEY="${CHIAVE_FINTA}" -- \
    claude sonnet '' 'Conta i token'
  expect "trainer-api: la chiave arriva" 0 "CHIAVE:presente"
  expect_absent "senza essere stampata" "${CHIAVE_FINTA}"
  expect_absent "con strumenti vuoti niente --allowedTools" "ARG:--allowedTools"
  scenario HANDSON_PERMISSION_MODE=acceptEdits -- claude haiku Edit 'Correggi'
  expect "acceptEdits ammessa" 0 "ARG:acceptEdits"
}

t_claude_rifiuti() {
  scenario HANDSON_ENV=trainer-api -- claude sonnet '' 'Conta'
  expect "trainer-api senza chiave" 2 "ANTHROPIC_API_KEY non è impostata"
  scenario HANDSON_PERMISSION_MODE=bypassPermissions -- \
    claude sonnet Read 'Leggi'
  expect "bypassPermissions rifiutata" 2 "modalità di permesso non ammessa"
  scenario HANDSON_PERMISSION_MODE=auto -- claude sonnet Read 'Leggi'
  expect "auto rifiutata" 2 "modalità di permesso non ammessa"
  scenario -- claude sonnet Read 'Leggi' --dangerously-skip-permissions
  expect "--dangerously-skip-permissions rifiutato" 2 "salta i controlli"
  scenario -- claude sonnet Read 'Leggi' --permission-mode acceptEdits
  expect "--permission-mode fra gli argomenti in più" 2 "lo imposta"
  scenario -- claude sonnet Read 'Leggi' --setting-sources user,project,local
  expect "--setting-sources fra gli argomenti in più" 2 "lo imposta"
  scenario -- claude sonnet Read 'Leggi' --setting-sources=user
  expect "--setting-sources=… fra gli argomenti in più" 2 "lo imposta"
  scenario -- claude fable Read 'Leggi'
  expect "Fable rifiutato sul piano Pro" 2 "Fable"
  scenario -- claude '' Read 'Leggi'
  expect "modello vuoto" 2 "il modello va indicato"
  scenario -- claude sonnet Read '-Leggi'
  expect "prompt che comincia con -" 2 "cominciare con -"
  scenario -- claude sonnet Read 'Leggi' --bare
  expect "--bare fuori da trainer-api" 2 "--bare"
  # La chiave finta si compone qui: nel file non c'è nessuna forma di
  # chiave che uno scanner di segreti possa segnalare.
  local finta="sk-ant""-api03-SEGRETOFINTO"
  scenario -- claude sonnet Read "Usa ${finta}"
  expect "una chiave sulla riga di comando" 2 "sembra una chiave API"
  expect_absent "e non viene stampata" "SEGRETOFINTO"
  mkdir -p "${TMP}/solo_readlink"
  ln -s "$(command -v readlink)" "${TMP}/solo_readlink/readlink"
  run env PATH="${TMP}/solo_readlink" /bin/bash "${SELF}" --scenario \
    claude sonnet Read 'Leggi'
  expect "claude assente" 2 "manca lo strumento: claude"
}

t_varie() {
  local d
  if command -v jq >/dev/null 2>&1; then
    scenario -- campo result
    expect "json_field: una stringa così com'è" 0 "ciao"
    scenario -- campo o
    expect "json_field: il resto come JSON" 0 '{"a":1}'
    scenario -- campo assente
    if (( RC == 0 )) && [[ -z "${OUT}" ]]; then
      pass "json_field: niente se il campo non c'è"
    else
      fail "json_field assente: «${OUT}»"
    fi
    scenario -- chiavi
    expect "json_keys" 0 "result"
  else
    echo "  SKIP: jq assente, json_field e json_keys non provati (no PASS)"
  fi
  scenario -- tmpdir
  expect "tmpdir crea la cartella" 0 "esiste"
  d="$(sed -n 's/^DIR://p' <<< "${OUT}")"
  if [[ -n "${d}" && ! -e "${d}" ]]; then
    pass "e all'uscita la cancella"
  else
    fail "cartella temporanea rimasta: ${d}"
  fi
  scenario -- doppia
  expect "una seconda source non fallisce" 0 "ok"
  scenario -- vuoto
  expect "un token vuoto si stampa ''" 0 "['']"
  if [[ -f "${LIB}" && ! -x "${LIB}" ]]; then
    pass "la libreria non è eseguibile"
  else
    fail "la libreria manca o è eseguibile"
  fi
}

main() {
  if [[ "${1:-}" == "--scenario" ]]; then
    shift
    pilota "$@"
    exit $?
  fi
  [[ -f "${LIB}" ]] || { echo "manca ${LIB}" >&2; exit 2; }
  TMP="$(mktemp -d)" || { echo "mktemp non riesce" >&2; exit 2; }
  readonly TMP
  trap 'rm -rf -- "${TMP}"' EXIT
  unset ANTHROPIC_API_KEY HANDSON_ENV HANDSON_PERMISSION_MODE \
    HANDSON_SHOW_CMD HANDSON_NO_PAUSE
  mkdir -p "${TMP}/bin"
  # shellcheck disable=SC2016  # il corpo è del claude finto
  printf '%s\n' '#!/bin/bash' 'printf "ARG:%s\n" "$@"' \
    'if [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then echo "CHIAVE:presente"' \
    'else echo "CHIAVE:assente"; fi' > "${TMP}/bin/claude"
  chmod 755 "${TMP}/bin/claude"
  echo "test_lib_handson.sh"
  t_stesso_array
  t_contratto
  t_claude_argv
  t_claude_stampato
  t_claude_rifiuti
  t_temp_base
  t_varie
  echo "PASS=${PASS} FAIL=${FAIL}"
  (( FAIL == 0 )) || exit 1
}

main "$@"
