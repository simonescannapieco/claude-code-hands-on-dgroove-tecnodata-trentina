#!/bin/bash
#
# test_esegui_test.sh -- verifica tests/esegui_test.sh su alberi usa e
# getta con suite e script finti: tutto verde (uscita 0, l'ultima riga di
# ogni suite); una suite che fallisce, una suite non eseguibile, uno script
# con una segnalazione di shellcheck (uscita 1); vendor/ ignorato da git
# resta fuori; le suite dei moduli (m<N>_*/_docente/test_*.sh) girano e
# gli script dei moduli passano da shellcheck, tranne esercizio/, demo/ e
# soluzione/ degli elementi; alle suite non arriva PN_HANDSON_ROOT e lo
# STDIN è chiuso; le precondizioni (nessuna suite, shellcheck mancante,
# fuori da git, argomenti) danno 2.
#
# Uso:    tests/test_esegui_test.sh
# Uscita: 0 = tutti i test passano · 1 = almeno un test fallito
#         2 = precondizione (shellcheck o git mancanti)
set -uo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly REPO="${SELF%/tests/*}"
readonly RUNNER="${REPO}/tests/esegui_test.sh"
TMP="$(mktemp -d)" || { echo "mktemp non riesce" >&2; exit 2; }
readonly TMP
trap 'rm -rf -- "${TMP}"' EXIT
PASS=0
FAIL=0
RC=0
OUT=''

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

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

# Uno script finto. Arguments: $1 il file, $2 i permessi, poi le righe
# dopo lo shebang.
script() {
  local f="$1" modo="$2"
  shift 2
  mkdir -p "${f%/*}"
  printf '%s\n' '#!/bin/bash' 'set -uo pipefail' "$@" > "${f}"
  chmod "${modo}" "${f}"
}

# Un albero minimo: due suite verdi, uno script pulito, .shellcheckrc vero,
# un repository git (senza commit: git elenca anche i file nuovi).
# Arguments: $1 la cartella.
albero() {
  mkdir -p "$1/tests" "$1/tools" "$1/progetti"
  cp -p "${REPO}/.shellcheckrc" "$1/"
  printf 'vendor/\n' > "$1/.gitignore"
  script "$1/tests/test_uno.sh" 755 'echo "PASS=1 FAIL=0"'
  script "$1/tests/test_due.sh" 755 'echo "PASS=2 FAIL=0"'
  script "$1/tools/pulito.sh" 755 'echo "pulito"'
  git -C "$1" init -q
}

# Il runner sull'albero $1.
runner() {
  OUT="$(env PN_HANDSON_ROOT="$1" "${RUNNER}" 2>&1)"
  RC=$?
}

# shellcheck disable=SC2016  # le righe sono codice degli script finti
t_verde() {
  local a="${TMP}/verde"
  albero "${a}"
  mkdir -p "${a}/progetti/x/vendor"
  printf 'echo $1\n' > "${a}/progetti/x/vendor/terzi.sh"
  script "${a}/tests/test_tre.sh" 755 \
    'echo "radice: ${PN_HANDSON_ROOT:-assente}"'
  script "${a}/tests/test_quattro.sh" 755 \
    'if read -r _; then echo "letto"; else echo "STDIN chiuso"; fi'
  runner "${a}"
  expect "tutto verde" 0 \
    "4 suite, 0 KO · shellcheck: 5 file, 0 con segnalazioni"
  expect "l'ultima riga di ogni suite" 0 "PASS=2 FAIL=0"
  expect "alle suite non arriva PN_HANDSON_ROOT" 0 "radice: assente"
  expect "lo STDIN delle suite è chiuso" 0 "STDIN chiuso"
  expect_absent "niente KO quando è tutto verde" "  KO  "
  expect_absent "vendor/ ignorato resta fuori" "terzi.sh"
}

# shellcheck disable=SC2016  # le righe sono codice degli script finti
t_rossi() {
  local a="${TMP}/rossi"
  albero "${a}"
  script "${a}/tests/test_rotto.sh" 755 'echo "FAIL: qualcosa"' 'exit 1'
  runner "${a}"
  expect "una suite che fallisce" 1 "KO  test_rotto.sh"
  expect "con le sue ultime righe" 1 "| FAIL: qualcosa"
  a="${TMP}/rossi2"
  albero "${a}"
  script "${a}/tests/test_fermo.sh" 644 'echo "mai"'
  runner "${a}"
  expect "una suite non eseguibile" 1 "non eseguibile"
  a="${TMP}/rossi3"
  albero "${a}"
  script "${a}/tools/sporco.sh" 755 'echo $1'
  runner "${a}"
  expect "uno script con una segnalazione" 1 "KO  shellcheck tools/sporco.sh"
}

# Le suite dei moduli, m<N>_*/_docente/test_*.sh, girano come quelle di
# tests/ e shellcheck guarda anche gli script dei moduli; una cartella che
# non è un modulo resta fuori, e così i contenuti degli elementi
# (esercizio/, demo/, soluzione/: lì uno script può essere materia
# dell'esercizio, come in handson::check_scripts).
# shellcheck disable=SC2016  # le righe sono codice degli script finti
t_moduli() {
  local a="${TMP}/moduli" s='m1_prova/_docente/test_m1_prova.sh'
  local v='m1_prova/s1/M1-D01_x/verifica.sh' e='m1_prova/s1/M1-E01_y' c
  albero "${a}"
  script "${a}/${s}" 755 'echo "PASS=7 FAIL=0"'
  script "${a}/${v}" 755 'echo "pulito"'
  script "${a}/altro/_docente/test_fuori.sh" 755 'echo $1'
  for c in esercizio demo soluzione; do
    script "${a}/${e}/${c}/da_correggere_${c}.sh" 755 'echo $1'
  done
  runner "${a}"
  expect "la suite di un modulo gira" 0 "ok  ${s}"
  expect "con la sua ultima riga" 0 "PASS=7 FAIL=0"
  expect "suite e script del modulo contati" 0 \
    "3 suite, 0 KO · shellcheck: 5 file, 0 con segnalazioni"
  expect_absent "una cartella che non è un modulo resta fuori" "test_fuori"
  expect_absent "esercizio/, demo/ e soluzione/ restano fuori" \
    "da_correggere"
  a="${TMP}/moduli2"
  albero "${a}"
  script "${a}/${s}" 755 'echo "FAIL: nel modulo"' 'exit 1'
  script "${a}/${v}" 755 'echo $1'
  runner "${a}"
  expect "la suite di un modulo che fallisce" 1 "KO  ${s}"
  expect "con le sue ultime righe" 1 "| FAIL: nel modulo"
  expect "uno script del modulo con una segnalazione" 1 "KO  shellcheck ${v}"
}

t_precondizioni() {
  local a="${TMP}/vuoto" corto="${TMP}/corto"
  mkdir -p "${a}/tests"
  git -C "${a}" init -q
  runner "${a}"
  expect "nessuna suite" 2 "nessuna suite"
  a="${TMP}/nongit"
  albero "${a}"
  rm -rf -- "${a}/.git"
  runner "${a}"
  expect "fuori da git" 2 "repository git"
  mkdir -p "${corto}"
  ln -s "$(command -v readlink)" "${corto}/readlink"
  ln -s "$(command -v git)" "${corto}/git"
  OUT="$(env PATH="${corto}" PN_HANDSON_ROOT="${TMP}/verde" /bin/bash \
    "${RUNNER}" 2>&1)"
  RC=$?
  expect "shellcheck mancante" 2 "manca lo strumento: shellcheck"
  OUT="$(env PN_HANDSON_ROOT="${TMP}/verde" "${RUNNER}" in-piu 2>&1)"
  RC=$?
  expect "argomento in più" 2 "Uso:"
}

main() {
  local t
  for t in git shellcheck; do
    command -v "${t}" >/dev/null 2>&1 || { echo "manca ${t}" >&2; exit 2; }
  done
  echo "test_esegui_test.sh"
  t_verde
  t_rossi
  t_moduli
  t_precondizioni
  echo "PASS=${PASS} FAIL=${FAIL}"
  (( FAIL == 0 )) || exit 1
}

main "$@"
