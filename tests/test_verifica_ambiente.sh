#!/bin/bash
#
# test_verifica_ambiente.sh -- verifica tools/verifica_ambiente.sh con un
# PATH fatto solo di comandi finti (uname, claude, git, php, composer,
# docker, python3, python, uv), così ogni caso è deterministico e nessun
# claude vero viene lanciato: tutto presente (uscita 0); ogni pezzo che
# manca o non basta (uscita 1, con il paragrafo di PRIMA_DEL_CORSO.md);
# ANTHROPIC_API_KEY impostata (uscita 1, valore mai stampato); PHP o Docker
# in alternativa; Python 3.8+; i sistemi operativi (macOS, Linux, WSL 2,
# WSL 1, Git Bash, altri); claude chiamato solo con --version; argomenti
# non validi (uscita 2).
#
# Uso:    tests/test_verifica_ambiente.sh
# Uscita: 0 = tutti i test passano · 1 = almeno un test fallito
#         2 = precondizione (lo strumento non c'è)
set -uo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly REPO="${SELF%/tests/*}"
readonly TOOL="${REPO}/tools/verifica_ambiente.sh"
readonly CHIAVE_FINTA='chiave-finta-di-prova-0042'
readonly NON_CORSO='il corso presuppone Linux o Windows con WSL 2'
readonly GUIDA="${REPO}/PRIMA_DEL_CORSO.md"
TMP="$(mktemp -d)" || { echo "mktemp non riesce" >&2; exit 2; }
readonly TMP
trap 'rm -rf -- "${TMP}"' EXIT
readonly LOG="${TMP}/claude.log"
readonly PROC="${TMP}/proc_version"
unset ANTHROPIC_API_KEY
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

# Un comando finto in una cartella; si comporta secondo le variabili FINTO_*.
# Arguments: $1 la cartella, $2 il nome del comando.
# shellcheck disable=SC2016  # i corpi sono codice dei comandi finti
finto() {
  local corpo
  case "$2" in
    uname) corpo='echo "${FINTO_UNAME:-Linux}"' ;;
    claude) corpo='printf "%s\n" "$*" >> "${FINTO_LOG}"
      echo "9.9.9 (Claude Code)"' ;;
    git) corpo='echo "git version 2.43.0"' ;;
    composer) corpo='echo "Composer version 2.7.0"' ;;
    php) corpo='case "$2" in *PHP_VERSION_ID*) echo "${FINTO_PHP_ID:-80301}" ;;
      *) echo "${FINTO_PHP_VER:-8.3.1}" ;; esac' ;;
    docker) corpo='if [[ "${FINTO_DOCKER_GIU:-0}" == "1" ]]; then exit 1; fi
      echo "27.0.0"' ;;
    python3) corpo='echo "Python ${FINTO_PY3:-3.12.1}"' ;;
    python) corpo='echo "Python 3.11.4"' ;;
    uv) corpo='echo "uv 0.9.9"' ;;
  esac
  printf '#!/bin/bash\n%s\n' "${corpo}" > "$1/$2" && chmod 755 "$1/$2"
}

# Una cartella di comandi finti. Arguments: $1 il nome, poi i comandi.
bin() {
  local d="${TMP}/$1" c
  shift
  mkdir -p "${d}"
  for c in "$@"; do
    finto "${d}" "${c}"
  done
}

# Lo strumento con PATH = solo la cartella finta $1; gli altri argomenti
# vanno allo strumento. Il resto dell'ambiente arriva dalle FINTO_*.
ambiente() {
  local d="${TMP}/$1"
  shift
  : > "${LOG}"
  OUT="$(env PATH="${d}" FINTO_LOG="${LOG}" PN_PROC_VERSION="${PROC}" \
    "${TOOL}" "$@" 2>&1)"
  RC=$?
}

t_tutto() {
  printf 'Linux version 6.1.0 (builder@example.org)\n' > "${PROC}"
  ambiente tutto
  expect "tutto presente" 0 "Tutto pronto per il corso."
  expect "mostra la versione di Claude Code" 0 "9.9.9 (Claude Code)"
  expect "riconosce Docker" 0 "Docker: servizio attivo"
  expect_absent "niente da sistemare" "[da fare]"
  if [[ "$(< "${LOG}")" == "--version" ]]; then
    pass "claude chiamato solo con --version (nessun modello)"
  else
    fail "claude chiamato con: $(< "${LOG}")"
  fi
  ambiente tutto extra
  expect "argomento in più" 2 "Uso:"
}

t_mancanze() {
  ambiente senza_uv
  expect "manca uv" 1 \
    "uv: non c'è o non risponde (PRIMA_DEL_CORSO.md, «Python e uv»)"
  ambiente senza_claude
  expect "manca Claude Code" 1 "«Installare Claude Code»"
  ambiente senza_git
  expect "manca git" 1 "git: non c'è"
  OUT="$(env PATH="${TMP}/tutto" FINTO_LOG="${LOG}" PN_PROC_VERSION="${PROC}" \
    ANTHROPIC_API_KEY="${CHIAVE_FINTA}" "${TOOL}" 2>&1)"
  RC=$?
  expect "ANTHROPIC_API_KEY impostata" 1 "è impostata"
  expect_absent "senza mai stamparne il valore" "${CHIAVE_FINTA}"
}

t_php_docker() {
  ambiente php_senza_docker
  expect "PHP 8.3 con Composer al posto di Docker" 0 "PHP e Composer: PHP 8.3.1"
  OUT="$(env PATH="${TMP}/php_senza_docker" FINTO_LOG="${LOG}" \
    PN_PROC_VERSION="${PROC}" FINTO_PHP_ID=80104 FINTO_PHP_VER=8.1.4 \
    "${TOOL}" 2>&1)"
  RC=$?
  expect "PHP 8.1 non basta" 1 "PHP o Docker"
  OUT="$(env PATH="${TMP}/tutto" FINTO_LOG="${LOG}" PN_PROC_VERSION="${PROC}" \
    FINTO_DOCKER_GIU=1 "${TOOL}" 2>&1)"
  RC=$?
  expect "Docker senza servizio attivo, niente PHP" 1 "PHP o Docker"
}

t_python() {
  OUT="$(env PATH="${TMP}/solo_python3" FINTO_LOG="${LOG}" \
    PN_PROC_VERSION="${PROC}" FINTO_PY3=3.7.9 "${TOOL}" 2>&1)"
  RC=$?
  expect "Python 3.7 non basta" 1 "serve Python 3.8"
  ambiente solo_python
  expect "python al posto di python3" 0 "Python 3.11.4 (python)"
}

# Lo strumento con un sistema finto e tutto il resto presente.
# Arguments: $1 l'uscita di uname -s, $2 il contenuto di /proc/version.
sistema() {
  printf '%s\n' "$2" > "${PROC}"
  OUT="$(env PATH="${TMP}/tutto" FINTO_LOG="${LOG}" PN_PROC_VERSION="${PROC}" \
    FINTO_UNAME="$1" "${TOOL}" 2>&1)"
  RC=$?
}

t_sistemi() {
  local kernel='5.15.153.1'  # canon:ok -- kernel version, not an address
  sistema Linux 'Linux version 6.1.0-amd64 (Debian 6.1.0)'
  expect "Linux: in ordine" 0 "sistema operativo: Linux"
  expect_absent "Linux: nessun rifiuto" "presuppone"
  sistema Linux "Linux version ${kernel}-microsoft-standard-WSL2"
  expect "WSL 2: in ordine" 0 "sistema operativo: Windows, WSL 2"
  expect_absent "WSL 2: nessun rifiuto" "presuppone"
  sistema Linux 'Linux version 4.4.0-19041-Microsoft'
  expect "WSL 1: da sistemare" 1 "Windows, WSL 1: ${NON_CORSO}"
  sistema Darwin ''
  expect "macOS: da sistemare" 1 "macOS: ${NON_CORSO}"
  sistema MINGW64_NT-10.0-19045 ''
  expect "Git Bash: da sistemare" 1 "Windows, Git Bash: ${NON_CORSO}"
  sistema MSYS_NT-10.0-19045 ''
  expect "MSYS: da sistemare" 1 "Windows, MSYS: ${NON_CORSO}"
  sistema CYGWIN_NT-10.0-19045 ''
  expect "Cygwin: da sistemare" 1 "Windows, Cygwin: ${NON_CORSO}"
  sistema FreeBSD ''
  expect "un altro sistema: da sistemare" 1 "«FreeBSD»: ${NON_CORSO}"
  expect "e indica il paragrafo della guida" 1 "«Linux o Windows con WSL 2»"
}

# Tutto da sistemare: ogni paragrafo che lo strumento cita esiste come
# titolo «## …» di PRIMA_DEL_CORSO.md.
t_paragrafi() {
  local nome trovati=0 mancanti=''
  bin vuoto uname
  printf 'Linux version 4.4.0-19041-Microsoft\n' > "${PROC}"
  OUT="$(env PATH="${TMP}/vuoto" FINTO_LOG="${LOG}" PN_PROC_VERSION="${PROC}" \
    ANTHROPIC_API_KEY="${CHIAVE_FINTA}" "${TOOL}" 2>&1)"
  RC=$?
  expect "tutto da sistemare" 1 "Da sistemare: 7"
  while IFS= read -r nome; do
    trovati=$((trovati + 1))
    grep -qxF "## ${nome}" "${GUIDA}" || mancanti+=" «${nome}»"
  done < <(grep -o '«[^»]*»' <<< "${OUT}" | sed 's/[«»]//g' | sort -u)
  if (( trovati >= 6 )) && [[ -z "${mancanti}" ]]; then
    pass "ogni paragrafo citato è un titolo di PRIMA_DEL_CORSO.md"
  else
    fail "paragrafi senza titolo:${mancanti} (citati ${trovati})"
  fi
}

main() {
  [[ -x "${TOOL}" ]] || { echo "manca ${TOOL}" >&2; exit 2; }
  echo "test_verifica_ambiente.sh"
  bin tutto uname claude git docker python3 uv
  bin senza_uv uname claude git docker python3
  bin senza_claude uname git docker python3 uv
  bin senza_git uname claude docker python3 uv
  bin php_senza_docker uname claude git php composer python3 uv
  bin solo_python3 uname claude git docker python3 uv
  bin solo_python uname claude git docker python uv
  t_tutto
  t_mancanze
  t_php_docker
  t_python
  t_sistemi
  t_paragrafi
  echo "PASS=${PASS} FAIL=${FAIL}"
  (( FAIL == 0 )) || exit 1
}

main "$@"
