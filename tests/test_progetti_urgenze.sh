#!/bin/bash
#
# Test di progetti/urgenze: il generatore deterministico (genera.py
# --check, anche su una copia alterata e con una cartella d'uscita che non
# si può creare), il test rosso apposta (il confine dei 7 giorni) che le
# demo del Modulo 4 usano, lo stesso test verde una volta corretto il
# confine, il README del progetto e la sua riga in progetti/README.md.
#
# Uso:    bash tests/test_progetti_urgenze.sh
# Uscita: 0 tutti i test superati, 1 almeno un test fallito,
#         2 precondizione mancante (python3 >= 3.8, il progetto).
# URGENZE_PYTHON sceglie l'interprete (predefinito: python3).
# Nella copia dei partecipanti (file segno .copia_partecipanti, senza
# progetti/urgenze/_docente/) la prova del README del docente è SKIP; nel
# repository completo _docente/ deve esserci, o è FAIL.

set -uo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
ROOT="$(dirname "$(dirname "${SELF}")")"
readonly ROOT
readonly URG="${ROOT}/progetti/urgenze"
readonly MARKER="${ROOT}/.copia_partecipanti"
readonly PY="${URGENZE_PYTHON:-python3}"

PASS=0
FAIL=0
SKIP=0
TMP=""
OUT=""
RC=0

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }
skip() { echo "  SKIP: $1"; SKIP=$((SKIP + 1)); }
err() { echo "test_progetti_urgenze.sh: $*" >&2; }

cleanup() {
  if [[ -n "${TMP}" && "${TMP}" != "/" && -d "${TMP}" && ! -L "${TMP}" ]]
  then
    rm -rf -- "${TMP}"
  fi
}

#######################################
# Esegue un comando, ne tiene uscita e output (STDOUT e STDERR insieme).
# Globals: OUT, RC (scritti). Arguments: il comando.
#######################################
run() {
  OUT="$("$@" 2>&1)"
  RC=$?
}

#######################################
# Precondizioni: python3 >= 3.8 e il progetto con il suo generatore.
#######################################
preflight() {
  if ! command -v "${PY}" > /dev/null 2>&1; then
    err "manca ${PY}"
    exit 2
  fi
  if ! "${PY}" -c 'import sys; sys.exit(sys.version_info < (3, 8))'; then
    err "serve Python 3.8 o successivo"
    exit 2
  fi
  if [[ ! -f "${URG}/genera.py" || ! -r "${URG}/genera.py" ]]; then
    err "manca ${URG}/genera.py"
    exit 2
  fi
}

#######################################
# Una copia del progetto, senza _docente/, in una cartella temporanea.
# Arguments: $1 la cartella di destinazione.
#######################################
copia_progetto() {
  mkdir -p -- "$1"
  cp -p -- "${URG}/genera.py" "${URG}/urgenza.py" "${URG}/test_urgenza.py" \
    "$1/" 2> /dev/null
}

test_check() {
  echo "genera.py --check sui file del repository"
  run "${PY}" -B "${URG}/genera.py" --check
  if (( RC == 0 )) && grep -q "2 file identici" <<< "${OUT}"; then
    pass "i file sono quelli del generatore"
  else
    fail "rc=${RC}: ${OUT}"
  fi
}

test_check_alterato() {
  echo "genera.py --check su una copia alterata"
  local c="${TMP}/alterato"
  if ! copia_progetto "${c}"; then
    fail "non riesco a copiare il progetto"
    return
  fi
  printf '# riga in più\n' >> "${c}/urgenza.py"
  run "${PY}" -B "${c}/genera.py" --check
  if (( RC == 1 )) && grep -q "urgenza.py" <<< "${OUT}"; then
    pass "una copia alterata dà 1 e nomina il file"
  else
    fail "rc=${RC}: ${OUT}"
  fi
}

test_out_impossibile() {
  echo "genera.py --out in una cartella che non si può creare"
  : > "${TMP}/un-file"
  run "${PY}" -B "${URG}/genera.py" --out "${TMP}/un-file/sotto"
  if (( RC == 2 )) && grep -q "errore" <<< "${OUT}"; then
    pass "un'uscita che non si può scrivere dà 2"
  else
    fail "rc=${RC}: ${OUT}"
  fi
}

test_rosso() {
  echo "il test del confine dei 7 giorni è rosso"
  local c="${TMP}/rosso"
  if ! copia_progetto "${c}"; then
    fail "non riesco a copiare il progetto"
    return
  fi
  run bash -c 'cd "$1" && "$2" -B -m unittest -q 2>&1' _ "${c}" "${PY}"
  if (( RC == 1 )) && grep -q "test_sette_giorni" <<< "${OUT}" \
      && grep -q "FAILED (failures=1)" <<< "${OUT}"; then
    pass "un solo test fallisce, quello dei 7 giorni"
  else
    fail "rc=${RC}: ${OUT}"
  fi
}

test_verde() {
  echo "lo stesso test, corretto il confine"
  local c="${TMP}/verde"
  if ! copia_progetto "${c}"; then
    fail "non riesco a copiare il progetto"
    return
  fi
  if ! "${PY}" -B - "${c}/urgenza.py" << 'EOF'
import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
if "giorni_aperta > 7" not in s:
    sys.exit(1)
open(p, "w", encoding="utf-8").write(s.replace("giorni_aperta > 7",
                                               "giorni_aperta >= 7"))
EOF
  then
    fail "urgenza.py non contiene il confine atteso"
    return
  fi
  run bash -c 'cd "$1" && "$2" -B -m unittest -q 2>&1' _ "${c}" "${PY}"
  if (( RC == 0 )) && grep -q "^OK" <<< "${OUT}" \
      && ! grep -q "FAILED" <<< "${OUT}"; then
    pass "con >= 7 i tre test passano"
  else
    fail "rc=${RC}: ${OUT}"
  fi
}

test_readme() {
  echo "i README"
  if [[ -f "${URG}/README.md" ]] && grep -q "python3 -m unittest" \
      "${URG}/README.md"; then
    pass "README.md del progetto, con il comando dei test"
  else
    fail "manca README.md, o non dice come lanciare i test"
  fi
  # shellcheck disable=SC2016  # i backtick sono letterali: la riga Markdown
  if grep -q '^| `urgenze/`' "${ROOT}/progetti/README.md"; then
    pass "la riga del progetto in progetti/README.md"
  else
    fail "progetti/README.md non elenca urgenze/"
  fi
  if [[ ! -f "${URG}/README.md" ]]; then
    fail "manca README.md: non si può dire se è neutro"
  elif grep -q -i -E "rosso|fallisce|sbagliat|difett" "${URG}/README.md"
  then
    fail "il README del progetto rivela il difetto: deve restare neutro"
  else
    pass "il README del progetto non rivela il difetto"
  fi
  if [[ -f "${URG}/_docente/README.md" ]]; then
    pass "_docente/README.md, il difetto inserito spiegato al docente"
  elif [[ -e "${MARKER}" ]]; then
    skip "copia dei partecipanti: _docente/ non c'è"
  else
    fail "manca _docente/README.md nel repository completo"
  fi
}

main() {
  preflight
  TMP="$(mktemp -d)" || { err "mktemp fallito"; exit 2; }
  trap cleanup EXIT
  test_check
  test_check_alterato
  test_out_impossibile
  test_rosso
  test_verde
  test_readme
  echo "PASS=${PASS} FAIL=${FAIL} SKIP=${SKIP}"
  (( FAIL == 0 )) || exit 1
}

main "$@"
