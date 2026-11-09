#!/bin/bash
#
# verifica.sh di M7-E01 «Il banco di prova». I controlli stanno in verifica.py,
# accanto a questo file (python3, già richiesto dal corso): la conversazione
# con la persona simulata e il suo registro ci sono, e note.md ha almeno tre
# voci, ognuna con un turno o uno strumento. Il contenuto delle note è un dato:
# la verifica lo stampa e non lo giudica. Non chiama niente: nessun modello,
# nessuna rete.
#
# Uso:    verifica.sh <spazio di lavoro>
# Env:    PN_HANDSON_ROOT  il repository (lo dà tools/verifica.sh)
# Uscita: 0 = fatto · 1 = non ancora (dice che cosa manca) · 2 = precondizione
#         (spazio di lavoro assente; python3 o verifica.py che mancano; un
#         file che c'è e non si legge; verifica.py uscito con un altro codice)
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly CONTROLLI="${SELF%/*}/verifica.py"

main() {
  local ws="${1:-}" rc=0
  if [[ -z "${ws}" || ! -d "${ws}" ]]; then
    echo "verifica: spazio di lavoro assente: ${ws}" >&2
    exit 2
  fi
  if ! command -v python3 > /dev/null 2>&1; then
    echo "verifica: manca python3 (tools/verifica_ambiente.sh)" >&2
    exit 2
  fi
  if [[ ! -r "${CONTROLLI}" ]]; then
    echo "verifica: manca ${CONTROLLI}" >&2
    exit 2
  fi
  python3 -B -I "${CONTROLLI}" "${ws}" || rc=$?
  case "${rc}" in
    0|1|2) exit "${rc}" ;;
    *)
      echo "verifica: verifica.py è uscito con ${rc}, fuori dal contratto" >&2
      exit 2
      ;;
  esac
}

main "$@"
