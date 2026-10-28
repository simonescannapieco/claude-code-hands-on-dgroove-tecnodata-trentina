#!/bin/bash
#
# applica.sh di M4-E03 -- applica la soluzione di riferimento a uno spazio di
# lavoro, come se il lavoro fosse finito: copia la documentazione
# (progetti/gestionale-php/docs/chiusura_mese.md), i test di caratterizzazione
# (progetti/gestionale-php/tests/Integrazione/ChiusuraMeseTest.php) e la
# proposta (PROPOSTA.md); poi, se mancano, installa le dipendenze del
# gestionale con tools/php.sh composer install, come dice il «Punto di
# partenza» del README, così verifica.sh può eseguire i test. Non tocca
# legacy/.
#
# Uso:    soluzione/applica.sh <spazio di lavoro>
# Env:    PN_HANDSON_ROOT  il repository (default: la cartella sopra il
#                          modulo), per tools/php.sh
#         PN_PHP_SH        il php.sh da usare al posto di tools/php.sh
# Uscita: 0 = soluzione applicata · 2 = precondizione (spazio di lavoro o
#         gestionale assenti, php.sh mancante, composer install che
#         fallisce, una copia che non riesce)
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly SOL="${SELF%/*}"
# lo script sta in <radice>/m4_…/s3_…/m4_e2_…/M4-E03_…/soluzione/
readonly RADICE="${PN_HANDSON_ROOT:-${SELF%/*/*/*/*/*/*}}"
readonly PROGETTO=progetti/gestionale-php
readonly FILE=(PROPOSTA.md "${PROGETTO}/docs/chiusura_mese.md"
  "${PROGETTO}/tests/Integrazione/ChiusuraMeseTest.php")

err() { echo "applica: $*" >&2; }

# Copia i file della soluzione nello spazio di lavoro.
# Arguments: $1 lo spazio di lavoro.
# Returns: 0; 1 se una cartella o una copia non riesce.
copia_i_file() {
  local f
  for f in "${FILE[@]}"; do
    if [[ "${f}" == */* ]] && ! mkdir -p -- "$1/${f%/*}"; then
      return 1
    fi
    cp -- "${SOL}/${f}" "$1/${f}" || return 1
  done
}

main() {
  local ws="${1:-}" php
  if [[ -z "${ws}" || ! -d "${ws}" ]]; then
    err "spazio di lavoro assente: ${ws}"
    exit 2
  fi
  if [[ ! -d "${ws}/${PROGETTO}" ]]; then
    err "manca ${PROGETTO} in ${ws}"
    exit 2
  fi
  if ! copia_i_file "${ws}"; then
    err "la copia della soluzione non riesce"
    exit 2
  fi
  if [[ -f "${ws}/${PROGETTO}/vendor/bin/phpunit" ]]; then
    exit 0
  fi
  php="${PN_PHP_SH:-${RADICE}/tools/php.sh}"
  if [[ ! -x "${php}" ]]; then
    err "manca tools/php.sh: ${php}"
    exit 2
  fi
  if ! (cd "${ws}" && "${php}" composer install -d "${PROGETTO}" \
      --no-interaction --no-progress); then
    err "composer install non riesce: le dipendenze del gestionale mancano"
    exit 2
  fi
}

main "$@"
