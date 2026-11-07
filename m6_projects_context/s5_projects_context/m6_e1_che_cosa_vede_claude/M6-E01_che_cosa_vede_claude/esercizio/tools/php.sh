#!/bin/bash
#
# tools/php.sh — esegue PHP, Composer e PHPUnit anche dove PHP non è
# installato, con le immagini Docker ufficiali.
#
# Uso, dalla cartella del progetto (per esempio progetti/gestionale-php):
#   tools/php.sh php <argomenti…>          l'interprete PHP
#   tools/php.sh composer <argomenti…>     Composer
#   tools/php.sh phpunit <argomenti…>      vendor/bin/phpunit della cartella
#                                          corrente
#   tools/php.sh serve [cartella] [porta]  il server web integrato di PHP
#                                          (default: public 8080, cioè
#                                          http://localhost:8080/)
#   tools/php.sh --help
#
# Se sul computer c'è PHP 8.3 o successivo (e, per «composer», Composer) usa
# quelli; altrimenti le immagini ufficiali, con tag esatti:
#   php:8.3.35-cli    per php, phpunit, serve
#   composer:2.10.3   per composer
# Nel container è montata, allo stesso percorso, la radice del repository git
# che contiene la cartella corrente (fuori da un repository: la cartella
# corrente); il container vede solo quella. I file creati appartengono a chi
# lancia lo script, con Docker rootless come con Docker tradizionale.
#
# Variabili facoltative:
#   PHP_SH_DOCKER=1           usa Docker anche se c'è un PHP locale
#   PHP_SH_MOUNT_ROOT=<dir>   cartella da montare al posto della radice git
#   PHP_SH_PHP_IMAGE, PHP_SH_COMPOSER_IMAGE   immagini alternative
#
# Uscita: il codice d'uscita dello strumento eseguito, invariato; 2 per un
# errore d'uso o di prerequisiti (comando sconosciuto, né PHP né Docker,
# demone Docker che non risponde, vendor/bin/phpunit mancante, porta o
# cartella non valida, percorso non montabile).
set -euo pipefail

readonly PHP_IMAGE="${PHP_SH_PHP_IMAGE:-php:8.3.35-cli}"
readonly COMPOSER_IMAGE="${PHP_SH_COMPOSER_IMAGE:-composer:2.10.3}"
readonly MIN_PHP_VERSION_ID=80300
readonly CACHE_IN_CONTAINER=/tmp/composer-cache

err() { echo "php.sh: $*" >&2; }
die() { err "$@"; exit 2; }

usage() {
  cat <<'EOF'
Uso: tools/php.sh <comando> [argomenti…]
  php <argomenti…>          esegue l'interprete PHP
  composer <argomenti…>     esegue Composer
  phpunit <argomenti…>      esegue vendor/bin/phpunit della cartella corrente
  serve [cartella] [porta]  server web integrato (default: public 8080)
  --help                    mostra questo aiuto
EOF
}

# Returns 0 se va usato il php locale (>= 8.3 e Docker non forzato).
use_local_php() {
  if [[ "${PHP_SH_DOCKER:-0}" == "1" ]]; then return 1; fi
  command -v php >/dev/null 2>&1 || return 1
  php -r "exit(PHP_VERSION_ID >= ${MIN_PHP_VERSION_ID} ? 0 : 1);" \
    >/dev/null 2>&1
}

# Globals: DOCKER_SECURITY (out). Esce con 2 se Docker manca o non risponde.
require_docker() {
  local format='{{json .SecurityOptions}}'
  command -v docker >/dev/null 2>&1 \
    || die "servono PHP >= 8.3 o Docker: non trovo né l'uno né l'altro"
  DOCKER_SECURITY="$(docker info --format "${format}" 2>/dev/null)" \
    || die "il demone Docker non risponde («docker info» fallisce)"
}

# Globals: PHP_SH_MOUNT_ROOT (in); MOUNT_ROOT, WORK_DIR (out).
resolve_mount() {
  local root=""
  WORK_DIR="$(pwd -P)"
  if [[ -n "${PHP_SH_MOUNT_ROOT:-}" ]]; then
    root="${PHP_SH_MOUNT_ROOT}"
  elif ! command -v git >/dev/null 2>&1 \
    || ! root="$(git -C "${WORK_DIR}" rev-parse --show-toplevel \
      2>/dev/null)"; then
    root="${WORK_DIR}"
  fi
  MOUNT_ROOT="$(readlink -f -- "${root}")" \
    || die "cartella da montare non valida: ${root}"
  [[ -d "${MOUNT_ROOT}" ]] || die "cartella da montare non valida: ${root}"
  if [[ "${MOUNT_ROOT}" == "/" || "${MOUNT_ROOT}" == *:* ]]; then
    die "percorso non montabile in Docker (radice o con «:»): ${MOUNT_ROOT}"
  fi
  [[ "${WORK_DIR}/" == "${MOUNT_ROOT}/"* ]] \
    || die "la cartella corrente ${WORK_DIR} non è dentro ${MOUNT_ROOT}"
}

# Esegue un comando in un container usa e getta; l'uscita è la sua.
# Arguments: $1 immagine, $2 porta da pubblicare ("" = nessuna), poi comando.
docker_exec() {
  local image="$1" port="$2" uid gid cache
  shift 2
  require_docker
  resolve_mount
  local -a run_args=(run --rm -i -e HOME=/tmp)
  if [[ -t 0 && -t 1 ]]; then run_args+=(-t); fi
  if [[ "${DOCKER_SECURITY}" != *rootless* ]]; then
    uid="$(id -u)"
    gid="$(id -g)"
    run_args+=(--user "${uid}:${gid}")
  fi
  run_args+=(-v "${MOUNT_ROOT}:${MOUNT_ROOT}" -w "${WORK_DIR}")
  if [[ "${image}" == "${COMPOSER_IMAGE}" ]]; then
    cache="${COMPOSER_CACHE_DIR:-${XDG_CACHE_HOME:-${HOME}/.cache}/composer}"
    if [[ "${cache}" != *:* ]] && mkdir -p -- "${cache}"; then
      run_args+=(-v "${cache}:${CACHE_IN_CONTAINER}")
      run_args+=(-e "COMPOSER_CACHE_DIR=${CACHE_IN_CONTAINER}")
    fi
  fi
  if [[ -n "${port}" ]]; then run_args+=(-p "127.0.0.1:${port}:${port}"); fi
  exec docker "${run_args[@]}" "${image}" "$@"
}

cmd_php() {
  if use_local_php; then exec php "$@"; fi
  docker_exec "${PHP_IMAGE}" "" php "$@"
}

cmd_serve() {
  local docroot="${1:-public}" port="${2:-8080}"
  if (( $# > 2 )); then usage >&2; exit 2; fi
  if [[ ! "${port}" =~ ^[1-9][0-9]{3,4}$ ]] || (( port > 65535 )); then
    die "porta non valida: ${port} (serve un numero tra 1024 e 65535)"
  fi
  [[ -d "${docroot}" ]] || die "cartella da servire non trovata: ${docroot}"
  err "server su http://localhost:${port}/ (Ctrl-C per fermarlo)"
  if use_local_php; then exec php -S "127.0.0.1:${port}" -t "${docroot}"; fi
  docker_exec "${PHP_IMAGE}" "${port}" php -S "0.0.0.0:${port}" -t "${docroot}"
}

main() {
  if (( $# == 0 )); then usage >&2; exit 2; fi
  local cmd="$1"
  shift
  case "${cmd}" in
    php) cmd_php "$@" ;;
    composer)
      if [[ "${PHP_SH_DOCKER:-0}" != "1" ]] \
        && command -v composer >/dev/null 2>&1; then
        exec composer "$@"
      fi
      docker_exec "${COMPOSER_IMAGE}" "" composer "$@"
      ;;
    phpunit)
      [[ -f vendor/bin/phpunit ]] || die "vendor/bin/phpunit non trovato in" \
        "$(pwd -P): esegui prima «tools/php.sh composer install»"
      cmd_php vendor/bin/phpunit "$@"
      ;;
    serve) cmd_serve "$@" ;;
    -h | --help) usage ;;
    *) err "comando sconosciuto: ${cmd}"; usage >&2; exit 2 ;;
  esac
}

main "$@"
