#!/bin/bash
#
# test_lib_handson.sh -- verifica il contratto d'aula di tools/lib_handson.sh:
# la riga stampata da handson::run, incollata in bash, rifà esattamente ciò
# che è stato eseguito (stesso array, apici e $ compresi, anche su più
# righe); HANDSON_SHOW_CMD=0 zittisce; le pause non scattano senza
# terminale; handson::check/finish danno 0 o 1, e su un KO handson::check
# stampa l'uscita del controllo, il suo STDOUT su STDOUT e il suo STDERR su
# STDERR, con l'uscita nel verdetto; su un OK il controllo resta muto; un
# controllo che esce con 2 o più (una precondizione, un comando che manca)
# fa uscire handson::finish con 2, e handson::verdict_rc fa lo stesso con
# un'uscita già presa; handson::check senza comando esce 2;
# con set -e lo script prosegue dopo un controllo KO; un controllo che è
# una funzione vede le variabili out e rc di chi lo chiama; le altre
# precondizioni danno 2.
# Poi handson::claude_p con un claude finto: l'argv esatto (-p, strumenti
# consentiti, modello, modalità di permesso, --permission-prompts none,
# --output-format json, gli argomenti in più, poi «--» e per ultimo il
# prompt, anche quando comincia con «-» o cita un'opzione),
# ANTHROPIC_API_KEY tolta fuori dagli elementi trainer-api e passata a
# quelli, mai stampata; i rifiuti (bypassPermissions, auto,
# --dangerously-skip-permissions, anche dentro il valore di un argomento in
# più, argomenti che il helper imposta da sé, «--» compreso, Fable, --bare,
# una chiave nel prompt, prompt vuoto, claude assente). Infine json_field e
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
ERR=''

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

# Esegue un comando; RC e OUT (STDOUT e STDERR insieme) per expect.
run() { OUT="$("$@" 2>&1)"; RC=$?; }

# Come run, ma con i due canali separati: OUT lo STDOUT, ERR lo STDERR.
run_separati() {
  OUT="$("$@" 2> "${TMP}/stderr.txt")"
  RC=$?
  ERR="$(< "${TMP}/stderr.txt")"
}

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

# Un controllo che scrive una riga su ciascun canale ed esce con $1.
# shellcheck disable=SC2317  # la chiama handson::check, indirettamente
controllo_rumoroso() {
  echo "riga-out del controllo"
  echo "riga-err del controllo" >&2
  return "$1"
}

# Un controllo che legge le variabili out e rc di chi lo chiama: esce 0
# solo se vede i loro valori, non quelli di handson::check.
# shellcheck disable=SC2317  # la chiama handson::check, indirettamente
controllo_globali() {
  [[ "${out:-}" == "globale-out" && "${rc:-}" == "globale-rc" ]]
}

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
  local -a nessuno=()
  case "$1" in
    pausa) handson::pause; echo "dopo" ;;
    check_ko) handson::check vero true; handson::check falso false
              handson::finish ;;
    check_ok) handson::check vero true; handson::finish ;;
    check_flussi) handson::check flussi controllo_rumoroso 1
                  handson::finish ;;
    check_muto) handson::check muto controllo_rumoroso 0; handson::finish ;;
    check_vuoto) handson::check "senza comando"; handson::finish ;;
    check_array) handson::check "array vuoto" ${nessuno[@]+"${nessuno[@]}"}
                 handson::finish ;;
    check_globali) out='globale-out' rc='globale-rc'
                   handson::check globali controllo_globali
                   handson::finish ;;
    check_set_e) set -e
                 handson::check fallito false
                 echo "riga dopo il controllo"
                 handson::finish ;;
    verdict_rc) handson::verdict_rc 0 a; handson::verdict_rc 1 b
                handson::verdict_rc 3 c; handson::finish ;;
    verdict_rc_rotto) handson::verdict_rc x d ;;
    check_precond) handson::check precondizione controllo_rumoroso 2
                   handson::check esito controllo_rumoroso 1
                   handson::finish ;;
    check_assente) handson::check assente comando-che-non-esiste-qui
                   handson::finish ;;
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
  run_separati bash "${SELF}" --scenario check_flussi
  if (( RC == 1 )) && grep -qF 'riga-out del controllo' <<< "${OUT}" \
      && grep -qF 'VERIFICA KO   flussi (uscita 1)' <<< "${OUT}"; then
    pass "un controllo KO: il suo STDOUT e il verdetto, con l'uscita, su STDOUT"
  else
    fail "controllo KO, STDOUT (rc=${RC}): ${OUT:0:300}"
  fi
  if grep -qF 'riga-err del controllo' <<< "${ERR}" \
      && ! grep -qF 'riga-err' <<< "${OUT}" \
      && ! grep -qF 'riga-out' <<< "${ERR}"; then
    pass "e il suo STDERR su STDERR"
  else
    fail "controllo KO, STDERR «${ERR:0:200}», STDOUT «${OUT:0:200}»"
  fi
  scenario -- check_muto
  expect "un controllo OK: il verdetto" 0 "VERIFICA OK   muto"
  expect_absent "e il controllo resta muto" "riga-"
  scenario -- manca
  expect "strumento mancante: uscita 2" 2 \
    "manca lo strumento: comando-che-non-esiste-qui"
}

# I casi limite di handson::check: senza comando, un controllo che è una
# funzione, set -e, un controllo che non ha potuto girare (uscita 2 o più).
t_contratto_check() {
  local s
  for s in check_vuoto check_array; do
    scenario -- "${s}"
    expect "${s}: handson::check senza comando esce 2" 2 \
      "handson::check: servono la descrizione e il comando del controllo"
    expect_absent "${s}: e nessun VERIFICA OK" "VERIFICA OK"
  done
  scenario -- check_globali
  expect "un controllo funzione vede out e rc di chi lo chiama" 0 \
    "VERIFICA OK   globali"
  scenario -- check_set_e
  expect "con set -e un controllo KO non ferma lo script" 1 \
    "riga dopo il controllo"
  expect "e il verdetto KO ha l'uscita del controllo" 1 \
    "VERIFICA KO   fallito (uscita 1)"
  run_separati bash "${SELF}" --scenario check_precond
  if (( RC == 2 )) \
      && grep -qF 'VERIFICA KO   precondizione (uscita 2)' <<< "${OUT}" \
      && grep -qF 'VERIFICA KO   esito (uscita 1)' <<< "${OUT}"; then
    pass "un controllo uscito con 2: il verdetto con l'uscita, e finish esce 2"
  else
    fail "controllo uscito con 2 (rc=${RC}): ${OUT:0:300}"
  fi
  if grep -qF 'non hanno potuto girare' <<< "${ERR}"; then
    pass "e su STDERR dice che è una precondizione"
  else
    fail "controllo uscito con 2, STDERR: «${ERR:0:300}»"
  fi
  scenario -- check_assente
  expect "un controllo che non c'è (uscita 127): finish esce 2" 2 \
    "VERIFICA KO   assente (uscita 127)"
  scenario -- verdict_rc
  expect "verdict_rc: 0 è OK" 2 "VERIFICA OK   a"
  expect "verdict_rc: 1 è un KO, con l'uscita" 2 "VERIFICA KO   b (uscita 1)"
  expect "verdict_rc: 3 è un KO e una precondizione, finish esce 2" 2 \
    "VERIFICA KO   c (uscita 3)"
  scenario -- verdict_rc_rotto
  expect "verdict_rc: un'uscita che non è un numero esce 2" 2 \
    "handson::verdict_rc: «x» non è un'uscita"
}

t_claude_argv() {
  local atteso='ARG:-p ARG:--allowedTools ARG:Read,Glob '
  atteso+='ARG:--model ARG:sonnet ARG:--permission-mode ARG:dontAsk '
  atteso+='ARG:--permission-prompts ARG:none ARG:--output-format ARG:json '
  atteso+='ARG:--setting-sources ARG:project,local '
  atteso+='ARG:--resume ARG:abc123 ARG:-- ARG:Riassumi il file '
  scenario ANTHROPIC_API_KEY="${CHIAVE_FINTA}" -- \
    claude sonnet 'Read,Glob' 'Riassumi il file' --resume abc123
  if (( RC == 0 )) && [[ "$(argv_finto)" == "${atteso}" ]]; then
    pass "argv di claude -p esatto: le opzioni, poi «--» e il prompt"
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
  scenario -- claude sonnet Read '- Leggi il file, poi riassumi' --effort low
  if (( RC == 0 )) && [[ "$(argv_finto)" \
      == *'ARG:low ARG:-- ARG:- Leggi il file, poi riassumi ' ]]; then
    pass "un prompt che comincia con «-» passa, dopo «--» e per ultimo"
  else
    fail "prompt con «-»: «$(argv_finto)» (rc=${RC}): ${OUT:0:200}"
  fi
  local cita='Perché non si usa mai --dangerously-skip-permissions?'
  scenario -- claude sonnet Read "${cita}"
  if (( RC == 0 )) && [[ "$(argv_finto)" == *"ARG:-- ARG:${cita} " ]]; then
    pass "un prompt che cita --dangerously-skip-permissions arriva a claude"
  else
    fail "prompt che cita un'opzione: «$(argv_finto)» (rc=${RC}): ${OUT:0:200}"
  fi
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
  scenario -- claude sonnet Read 'Leggi' --append-system-prompt \
    'Non usare mai --dangerously-skip-permissions'
  expect "la stessa parola in un argomento in più resta rifiutata" 2 \
    "salta i controlli"
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
  scenario -- claude sonnet Read ''
  expect "prompt vuoto" 2 "il prompt non può essere vuoto"
  scenario -- claude sonnet Read 'Leggi' --resume abc123 -- 'Altro'
  expect "«--» fra gli argomenti in più" 2 "«--» lo imposta handson::claude_p"
  scenario -- claude sonnet Read 'Leggi' --bare
  expect "--bare fuori da trainer-api" 2 "--bare"
  # La chiave finta si compone qui: nel file non c'è nessuna forma di
  # chiave che uno scanner di segreti possa segnalare.
  local finta="sk-ant""-api03-SEGRETOFINTO"
  scenario -- claude sonnet Read "Usa ${finta}"
  expect "una chiave nel prompt resta rifiutata" 2 "sembra una chiave API"
  expect_absent "e non viene stampata" "SEGRETOFINTO"
  scenario -- claude sonnet Read 'Leggi' --append-system-prompt "Usa ${finta}"
  expect "una chiave in un argomento in più: rifiutata" 2 \
    "sembra una chiave API"
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
  t_contratto_check
  t_claude_argv
  t_claude_stampato
  t_claude_rifiuti
  t_temp_base
  t_varie
  echo "PASS=${PASS} FAIL=${FAIL}"
  (( FAIL == 0 )) || exit 1
}

main "$@"
