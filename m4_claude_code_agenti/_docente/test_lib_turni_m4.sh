#!/bin/bash
#
# test_lib_turni_m4.sh -- verifica _docente/lib_turni_m4.sh, la libreria dei
# turni delle prove dal vivo del laboratorio del Modulo 4, con un claude
# finto: turni::chiama scrive lo stream in <base>.jsonl e il suo ultimo
# risultato in <base>.json, ed esce 0; esce 1, con il suo messaggio su
# STDERR, quando claude fallisce, quando lo stream non ha un risultato e
# quando ha una riga che non è JSON. Il formato stream-json resta del
# turno: un handson::claude_p chiamato dopo chiede di nuovo
# --output-format json, senza --verbose. turni::riepilogo somma i
# risultati, con i segmenti; la libreria caricata due volte nello stesso
# processo non dà errori.
#
# Uso:    m4_claude_code_agenti/_docente/test_lib_turni_m4.sh
# Env:    PN_HANDSON_ROOT  il repository (default: la cartella sopra il
#                          modulo)
#         PN_LIB_TURNI     la libreria da provare (default: quella accanto
#                          a questo file)
# Uscita: 0 = tutti i test passano · 1 = almeno un test fallito
#         2 = precondizione (una libreria, jq o un file temporaneo che
#         mancano)
set -uo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly MOD="${SELF%/_docente/*}"
readonly RADICE="${PN_HANDSON_ROOT:-${MOD%/*}}"
readonly LIB_HANDSON="${RADICE}/tools/lib_handson.sh"
readonly LIB_TURNI="${PN_LIB_TURNI:-${MOD}/_docente/lib_turni_m4.sh}"
readonly CASES=11
TMP=''
PASS=0
FAIL=0
RC=0
OUT=''

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }
rotta() { echo "test_lib_turni_m4: precondizione: $*" >&2; exit 2; }

# Esegue un comando; RC e OUT (STDOUT e STDERR insieme) per expect.
run() { OUT="$("$@" 2>&1)"; RC=$?; }

# Uscita attesa E parola chiave attesa (RU-01.T3).
# Arguments: $1 il nome, $2 l'uscita attesa, $3 la parola (grep -F).
expect() {
  if (( RC == $2 )) && grep -qF -- "$3" <<< "${OUT}"; then
    pass "$1"
  else
    fail "$1 (rc=${RC}, attesa $2, parola «$3»): ${OUT:0:600}"
  fi
}

# Nessun falso positivo: la parola NON c'è (RU-01.T5).
# Arguments: $1 il nome, $2 la parola.
expect_absent() {
  if grep -qF -- "$2" <<< "${OUT}"; then
    fail "$1: «$2» c'è: ${OUT:0:600}"
  else
    pass "$1"
  fi
}

# Il claude finto: scrive il suo argv in FINTO_LOG, una riga per chiamata,
# e su STDOUT lo stream che FINTO_STREAM chiede (buono, senza, rotto,
# fallisce).
scrivi_finto() {
  mkdir -p "${TMP}/bin" || rotta "mkdir"
  cat > "${TMP}/bin/claude" <<'FINTO' || rotta "claude finto"
#!/bin/bash
if [[ "${1:-}" == "--version" ]]; then
  echo "0.0.0 (Claude Code, finto)"
  exit 0
fi
printf '%s\n' "$*" >> "${FINTO_LOG}"
case "${FINTO_STREAM:-buono}" in
  buono)
    printf '%s\n' '{"type":"system","subtype":"init","session_id":"s1"}' \
      '{"type":"result","result_index":0,"num_turns":3,"duration_ms":1500,'\
'"session_id":"s1","usage":{"input_tokens":10,'\
'"cache_creation_input_tokens":100,"cache_read_input_tokens":1000,'\
'"output_tokens":50}}' \
      '{"type":"user","message":{"content":"<task-notification>"}}' \
      '{"type":"result","result_index":1,"num_turns":2,"duration_ms":600,'\
'"origin":{"kind":"task-notification"},"session_id":"s1","usage":'\
'{"input_tokens":5,"cache_creation_input_tokens":50,'\
'"cache_read_input_tokens":500,"output_tokens":25}}' ;;
  senza)
    printf '%s\n' '{"type":"system","subtype":"init","session_id":"s1"}' \
      '{"type":"assistant","message":{"content":[]}}' ;;
  rotto)
    printf '%s\n' '{"type":"system","subtype":"init","session_id":"s1"}' \
      '{"type":"result", rotto' ;;
  fallisce)
    echo "errore finto" >&2
    exit 3 ;;
esac
FINTO
  chmod +x "${TMP}/bin/claude" || rotta "chmod"
}

# Un turno con il claude finto, in una shell nuova che carica le due
# librerie; dopo il turno, «rc=<n>»; con «e-poi», anche un
# handson::claude_p semplice, il cui argv va nel registro.
# Arguments: $1 lo stream finto, $2 la base dei file, $3 «e-poi» o niente.
turno() {
  : > "${TMP}/argv.log" || rotta "argv.log"
  # shellcheck disable=SC2016  # $1…$4 sono della shell figlia
  run env PATH="${TMP}/bin:${PATH}" FINTO_LOG="${TMP}/argv.log" \
    FINTO_STREAM="$1" HANDSON_SHOW_CMD=0 HANDSON_NO_PAUSE=1 \
    bash -c 'source "$1" && source "$2" || exit 2
      turni::chiama "$3" sonnet Read "Ciao"
      echo "rc=$?"
      if [[ "$4" == e-poi ]]; then
        handson::claude_p sonnet Read "Di nuovo" > /dev/null
        echo "formato dopo: ${HANDSON_OUTPUT_FORMAT}"
      fi' _ "${LIB_HANDSON}" "${LIB_TURNI}" "$2" "${3:-}"
}

# Il turno con due risultati: lo stream, l'ultimo risultato, il riepilogo;
# e il formato che non esce dal turno.
t_buono() {
  local base="${TMP}/turno-1" riepilogo primo secondo atteso
  turno buono "${base}" e-poi
  primo="$(sed -n 1p "${TMP}/argv.log")"
  secondo="$(sed -n 2p "${TMP}/argv.log")"
  expect "uno stream con due risultati: esce 0" 0 "rc=0"
  if [[ "$(jq -s 'map(select(.type == "result")) | length' \
      "${base}.jsonl" 2> /dev/null)" == 2 \
      && "$(jq -r '[.result_index, .origin.kind] | join(" ")' \
        "${base}.json" 2> /dev/null)" == "1 task-notification" ]]; then
    pass "lo stream intero in .jsonl, l'ultimo risultato in .json"
  else
    fail "i file del turno: $(cat "${base}.json" 2> /dev/null)"
  fi
  if [[ "${primo}" == *"--output-format stream-json --verbose "* ]]; then
    pass "il turno chiede stream-json, con --verbose"
  else
    fail "l'argv del turno: ${primo}"
  fi
  if [[ "${secondo}" == *"--output-format json "* \
      && "${secondo}" != *"--verbose"* ]]; then
    pass "un handson::claude_p dopo il turno chiede di nuovo json"
  else
    fail "l'argv dopo il turno: ${secondo}"
  fi
  expect "e HANDSON_OUTPUT_FORMAT resta json" 0 "formato dopo: json"
  # shellcheck disable=SC2016  # $1 e $2 sono della shell figlia
  riepilogo="$(bash -c 'source "$1" && turni::riepilogo 1 "$2"' _ \
    "${LIB_TURNI}" "${base}.jsonl" 2>&1)"
  atteso="  turno 1: 5 turni del modello in 2 segmenti, 2 s, token in entrata"
  atteso+=" 1665, in uscita 75"
  if [[ "${riepilogo}" == "${atteso}" ]]; then
    pass "il riepilogo somma i due risultati e conta i segmenti"
  else
    fail "il riepilogo: ${riepilogo}"
  fi
}

# Gli errori: ognuno esce 1, con il suo messaggio.
t_errori() {
  turno senza "${TMP}/turno-senza"
  expect "uno stream senza risultato: 1, e lo dice" 0 "non ha un risultato"
  expect "...con rc=1" 0 "rc=1"
  turno rotto "${TMP}/turno-rotto"
  expect "una riga che non è JSON: 1, e lo dice" 0 \
    "ha una riga che non è JSON"
  turno fallisce "${TMP}/turno-fallito"
  expect "claude che fallisce: 1, e lo dice" 0 "claude -p è uscito con 3"
}

# La libreria caricata due volte nello stesso processo.
t_due_volte() {
  # shellcheck disable=SC2016  # $1 è della shell figlia
  run bash -c 'source "$1" && source "$1" && echo "caricata due volte"' _ \
    "${LIB_TURNI}"
  if (( RC == 0 )) && [[ "${OUT}" == "caricata due volte" ]]; then
    pass "la libreria caricata due volte: nessun errore, nessun messaggio"
  else
    fail "la libreria caricata due volte (rc=${RC}): ${OUT:0:300}"
  fi
}

main() {
  command -v jq > /dev/null 2>&1 || rotta "manca jq"
  [[ -r "${LIB_HANDSON}" && -r "${LIB_TURNI}" ]] \
    || rotta "una libreria non si legge: ${LIB_HANDSON} ${LIB_TURNI}"
  TMP="$(mktemp -d)" || rotta "mktemp"
  trap 'rm -rf "${TMP}"' EXIT
  scrivi_finto
  t_buono
  t_errori
  t_due_volte
  local totale=$((PASS + FAIL))
  echo "test_lib_turni_m4: PASS=${PASS} FAIL=${FAIL} (casi ${totale} di" \
    "${CASES})"
  if (( totale != CASES )); then
    echo "test_lib_turni_m4: eseguiti ${totale} casi invece di ${CASES}" >&2
    exit 2
  fi
  (( FAIL == 0 ))
}

main "$@"
