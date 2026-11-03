#!/bin/bash
#
# conta.sh -- conta le righe di elenco.txt, accanto a questo file, e le stampa
# dopo una sentinella. La sentinella nasce mentre lo script gira: nel testo di
# questo file non c'è, così in uno stream compare soltanto se lo script è stato
# eseguito davvero. La demo la usa per questo, e perché `bash conta.sh` non è
# un comando di sola lettura: `cat` e `wc`, che lo sono, passerebbero comunque.
#
# Uso:    bash conta.sh
# Uscita: 0 = stampato · 2 = elenco.txt che manca
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly ELENCO="${SELF%/*}/elenco.txt"
readonly META=2108

main() {
  local righe
  if [[ ! -r "${ELENCO}" ]]; then
    echo "conta.sh: manca ${ELENCO}" >&2
    exit 2
  fi
  righe="$(wc -l < "${ELENCO}")"
  printf 'sentinella-%d: %d righe\n' "$(( META * 2 ))" "${righe}"
}

main "$@"
