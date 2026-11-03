#!/bin/bash
#
# prepara_modifica.sh -- la piccola modifica non committata su cui lavora la
# skill: in progetti/urgenze/urgenza.py la soglia dei clienti passa da 10 a 5.
# Il punto di partenza è tutto in un commit, e una skill che riassume le
# modifiche non committate ha bisogno di una modifica.
#
# Uso:    bash prepara_modifica.sh    nello spazio di lavoro di M5-E01
# Uscita: 0 = la modifica c'è · 2 = precondizione (urgenza.py che manca o che
#         non ha la riga da cambiare)
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly SPAZIO="${SELF%/*}"
readonly FILE=progetti/urgenze/urgenza.py
readonly PRIMA='clienti >= 10'
readonly DOPO='clienti >= 5'

err() { echo "prepara_modifica.sh: $*" >&2; }

main() {
  local testo
  if [[ ! -f "${SPAZIO}/${FILE}" ]]; then
    err "manca ${FILE}: preparate lo spazio di lavoro con" \
      "tools/prepara_esercizio.sh M5-E01"
    exit 2
  fi
  testo="$(< "${SPAZIO}/${FILE}")"
  if [[ "${testo}" == *"${DOPO}"* ]]; then
    echo "La modifica c'è già: ${FILE}"
    exit 0
  fi
  if [[ "${testo}" != *"${PRIMA}"* ]]; then
    err "non trovo «${PRIMA}» in ${FILE}: per ricominciare," \
      "tools/reset_esercizio.sh M5-E01"
    exit 2
  fi
  printf '%s\n' "${testo/${PRIMA}/${DOPO}}" > "${SPAZIO}/${FILE}"
  echo "Modifica fatta, non committata: ${FILE}"
}

main "$@"
