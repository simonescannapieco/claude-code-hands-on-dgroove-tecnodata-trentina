#!/bin/bash
#
# verifica.sh di M1-D01 (albero di prova dei test) -- la demo finisce con
# un file saluto.txt che contiene la parola «ciao».
#
# Uso:    verifica.sh <spazio di lavoro>
# Uscita: 0 = saluto.txt dice ciao · 1 = saluto.txt assente o diverso
#         2 = precondizione (spazio di lavoro assente)
set -euo pipefail

main() {
  local ws="${1:-}" testo
  if [[ -z "${ws}" || ! -d "${ws}" ]]; then
    echo "verifica: spazio di lavoro assente: ${ws}" >&2
    exit 2
  fi
  if [[ ! -f "${ws}/saluto.txt" ]]; then
    echo "Manca saluto.txt."
    exit 1
  fi
  testo="$(tr -d '[:space:]' < "${ws}/saluto.txt")"
  if [[ "${testo}" != "ciao" ]]; then
    echo "saluto.txt dice «${testo}», non «ciao»."
    exit 1
  fi
  echo "saluto.txt dice ciao."
}

main "$@"
