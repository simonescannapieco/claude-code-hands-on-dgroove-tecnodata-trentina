#!/bin/bash
#
# applica.sh di M4-E01 -- applica la soluzione di riferimento a uno spazio
# di lavoro: prima le dipendenze del gestionale, come nel punto di partenza
# del README (tools/php.sh composer install -d progetti/gestionale-php,
# solo se vendor/ non c'è), poi spiegazione.md e il test di riferimento
# (soluzione/progetti/, copiato sopra lo spazio di lavoro).
#
# Uso:    soluzione/applica.sh <spazio di lavoro>
# Env:    PN_PHP_SH  un altro strumento per PHP (le prove del docente);
#                    altrimenti tools/php.sh dello spazio di lavoro
# Uscita: 0 = soluzione applicata · 2 = precondizione (spazio di lavoro o
#         gestionale assente, nessuno strumento per PHP, composer che non
#         riesce, una copia che non riesce)
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly SOLUZIONE="${SELF%/*}"
readonly PROGETTO=progetti/gestionale-php

err() { echo "applica: $*" >&2; }

main() {
  local ws="${1:-}" php
  if [[ -z "${ws}" || ! -d "${ws}/${PROGETTO}" ]]; then
    err "spazio di lavoro assente o senza ${PROGETTO}: ${ws}"
    exit 2
  fi
  php="${PN_PHP_SH:-${ws}/tools/php.sh}"
  if [[ ! -x "${php}" ]]; then
    err "manca lo strumento per PHP: ${php}"
    exit 2
  fi
  if [[ ! -f "${ws}/${PROGETTO}/vendor/bin/phpunit" ]]; then
    if ! (cd "${ws}" && "${php}" composer install -d "${PROGETTO}" \
        --no-interaction --no-progress); then
      err "composer install non riesce"
      exit 2
    fi
  fi
  if ! cp -- "${SOLUZIONE}/spiegazione.md" "${ws}/spiegazione.md" \
      || ! cp -R -- "${SOLUZIONE}/progetti/." "${ws}/progetti/"; then
    err "la copia della soluzione non riesce"
    exit 2
  fi
}

main "$@"
