#!/bin/bash
#
# tests/test_php_sh.sh — verifica tools/php.sh.
#
# Con un PATH di stub al posto di php, composer e docker: errori d'uso e di
# prerequisiti, scelta tra PHP locale e Docker, argomenti passati a docker
# (utente, montaggio, porta, cache di Composer), codice d'uscita invariato.
# Poi una prova reale con Docker, se disponibile; altrimenti una riga SKIP
# (un test saltato non conta come superato).
#
# Uso: tests/test_php_sh.sh
# Uscita: 0 nessun test fallito; 1 almeno un test fallito; 2 prerequisito
# mancante (php.sh assente, comandi di base introvabili).
set -uo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly ROOT="${SELF%/tests/*}"
readonly PHP_SH="${ROOT}/tools/php.sh"
TMP="$(mktemp -d)"
readonly TMP
trap 'rm -rf "${TMP}"' EXIT
readonly WORK="${TMP}/progetto"
readonly BASE="${TMP}/base"
readonly STUB_LOG="${TMP}/stub.log"
readonly CON_DOCKER="${TMP}/docker:${BASE}"
readonly CON_PHP="${TMP}/php:${BASE}"
readonly CON_ENTRAMBI="${TMP}/php:${TMP}/docker:${BASE}"
readonly IMMAGINE='php:8\.3\.35-cli'

PASS=0
FAIL=0
SKIP=0
pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }
skip() { echo "  SKIP: $1"; SKIP=$((SKIP + 1)); }
die() { echo "FATAL: $*" >&2; exit 2; }

# Comandi di base (link ai veri) e stub di php, composer e docker.
prepara() {
  local tool
  [[ -f "${PHP_SH}" ]] || die "manca ${PHP_SH}"
  mkdir -p "${BASE}" "${TMP}/docker" "${TMP}/php" "${WORK}/public" \
    "${TMP}/home"
  for tool in id readlink mkdir cat; do
    command -v "${tool}" >/dev/null 2>&1 || die "manca ${tool}"
    ln -s "$(command -v "${tool}")" "${BASE}/${tool}"
  done
  cat > "${TMP}/docker/docker" <<'EOF'
#!/bin/bash
echo "docker $*" >> "${STUB_LOG}"
if [[ "$1" == "info" ]]; then
  if [[ "${STUB_GIU:-0}" == "1" ]]; then exit 1; fi
  echo "${STUB_SICUREZZA:-[\"name=seccomp,profile=builtin\"]}"
  exit 0
fi
exit "${STUB_RC:-0}"
EOF
  cat > "${TMP}/php/php" <<'EOF'
#!/bin/bash
if [[ "$1" == "-r" && "$2" == *PHP_VERSION_ID* ]]; then
  exit "${STUB_VECCHIO:-0}"
fi
echo "php $*" >> "${STUB_LOG}"
exit "${STUB_RC:-0}"
EOF
  cat > "${TMP}/php/composer" <<'EOF'
#!/bin/bash
echo "composer $*" >> "${STUB_LOG}"
EOF
  chmod +x "${TMP}/docker/docker" "${TMP}/php/php" "${TMP}/php/composer"
}

# run_sh <PATH> [VAR=valore…] -- <argomenti di php.sh…>: imposta OUT, RC, LOG.
run_sh() {
  local path="$1"
  local -a vars=()
  shift
  while [[ "$1" != "--" ]]; do vars+=("$1"); shift; done
  shift
  : > "${STUB_LOG}"
  OUT="$(cd "${DIR:-${WORK}}" && env PATH="${path}" HOME="${TMP}/home" \
    STUB_LOG="${STUB_LOG}" "${vars[@]}" /bin/bash "${PHP_SH}" "$@" 2>&1)"
  RC=$?
  LOG="$(<"${STUB_LOG}")"
}

# expect <descrizione> <rc atteso> <regex sull'output>
expect() {
  if (( RC == $2 )) && [[ "${OUT}" =~ $3 ]]; then
    pass "$1"
  else
    fail "$1 (rc=${RC}): ${OUT}"
  fi
}

# expect_log <descrizione> <regex> [assente]: il registro degli stub contiene
# (con «assente»: non contiene) la regex.
expect_log() {
  local trovato=0
  if [[ "${LOG}" =~ $2 ]]; then trovato=1; fi
  if [[ "${3:-}" == "assente" ]]; then trovato=$((1 - trovato)); fi
  if (( trovato == 1 )); then pass "$1"; else fail "$1: ${LOG}"; fi
}

test_prerequisiti() {
  run_sh "${BASE}" --
  expect "senza argomenti: uso ed errore 2" 2 "Uso: tools/php.sh"
  run_sh "${BASE}" -- pippo
  expect "comando sconosciuto: errore 2" 2 "comando sconosciuto: pippo"
  run_sh "${BASE}" -- --help
  expect "--help: uscita 0" 0 "Uso: tools/php.sh"
  if [[ "${OUT}" != *sconosciuto* ]]; then
    pass "--help: nessun falso errore"
  else
    fail "--help: ${OUT}"
  fi
  run_sh "${BASE}" -- php -v
  expect "né PHP né Docker: errore 2" 2 "non trovo né l'uno né l'altro"
  run_sh "${CON_DOCKER}" STUB_GIU=1 -- php -v
  expect "demone Docker fermo: errore 2" 2 "demone Docker non risponde"
  mkdir -p "${TMP}/con:due"
  DIR="${TMP}/con:due" run_sh "${CON_DOCKER}" -- php -v
  expect "percorso con due punti: errore 2" 2 "non montabile"
}

test_scelte() {
  local uid gid
  uid="$(id -u)"
  gid="$(id -g)"
  run_sh "${CON_ENTRAMBI}" STUB_RC=5 -- php -v
  expect "PHP locale: uscita 5 passata" 5 "^$"
  expect_log "PHP locale: usato php" "^php -v$"
  expect_log "PHP locale: Docker non usato" "docker" assente
  run_sh "${CON_ENTRAMBI}" STUB_VECCHIO=1 -- php -v
  expect_log "PHP locale vecchio: Docker" "docker run .* ${IMMAGINE} php -v"
  run_sh "${CON_ENTRAMBI}" PHP_SH_DOCKER=1 -- php -v
  expect_log "PHP_SH_DOCKER=1: Docker" "docker run .* ${IMMAGINE} php -v"
  run_sh "${CON_DOCKER}" STUB_RC=7 -- php -r 'exit(7);'
  expect "Docker: uscita 7 passata" 7 "^$"
  expect_log "Docker tradizionale: --user" "--user ${uid}:${gid}"
  expect_log "montaggio e cartella" "-v ${WORK}:${WORK} -w ${WORK}"
  run_sh "${CON_DOCKER}" "STUB_SICUREZZA=[\"name=rootless\"]" -- php -v
  expect_log "Docker rootless: nessun --user" "--user" assente
}

test_comandi() {
  run_sh "${CON_DOCKER}" -- phpunit
  expect "phpunit senza vendor: errore 2" 2 "tools/php.sh composer install"
  mkdir -p "${WORK}/vendor/bin" && : > "${WORK}/vendor/bin/phpunit"
  run_sh "${CON_DOCKER}" -- phpunit --filter Prova
  expect_log "phpunit: argomenti" "php vendor/bin/phpunit --filter Prova$"
  run_sh "${CON_PHP}" -- composer install
  expect_log "composer locale: senza Docker" "^composer install$"
  run_sh "${CON_DOCKER}" -- composer install
  expect_log "composer: immagine" "composer:2\.10\.3 composer install$"
  expect_log "composer: cache montata" \
    "-v ${TMP}/home/\.cache/composer:/tmp/composer-cache"
  run_sh "${CON_DOCKER}" -- serve public 80
  expect "serve: porta non valida, errore 2" 2 "porta non valida: 80"
  run_sh "${CON_DOCKER}" -- serve public 8099
  expect_log "serve: porta solo in locale" \
    "-p 127\.0\.0\.1:8099:8099 .* php -S 0\.0\.0\.0:8099 -t public"
}

# reale <cartella> <codice PHP>: php -r attraverso il vero Docker.
reale() {
  OUT="$(cd "$1" && PHP_SH_DOCKER=1 "${PHP_SH}" php -r "$2" 2>&1)"
  RC=$?
}

test_docker_reale() {
  local dir="${TMP}/reale" proprietario
  if ! command -v docker >/dev/null 2>&1 || ! docker info >/dev/null 2>&1; then
    skip "Docker reale: non disponibile (3 prove saltate)"
    return 0
  fi
  mkdir -p "${dir}"
  reale "${dir}" 'echo PHP_VERSION;'
  expect "Docker reale: PHP 8.3" 0 "^8\.3\.[0-9]+$"
  reale "${dir}" 'exit(3);'
  expect "Docker reale: uscita 3 passata" 3 "^$"
  reale "${dir}" 'file_put_contents("nuovo.txt", "x");'
  proprietario="$(stat -c %u "${dir}/nuovo.txt" 2>/dev/null)"
  if [[ "${proprietario}" == "$(id -u)" ]]; then
    pass "Docker reale: il file appartiene a chi lancia"
  else
    fail "Docker reale: proprietario «${proprietario}»: ${OUT}"
  fi
}

main() {
  prepara
  echo "tools/php.sh"
  test_prerequisiti
  test_scelte
  test_comandi
  test_docker_reale
  echo "PASS=${PASS} FAIL=${FAIL} SKIP=${SKIP}"
  (( FAIL == 0 )) || exit 1
}

main "$@"
