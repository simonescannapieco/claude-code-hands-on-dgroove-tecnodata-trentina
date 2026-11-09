#!/bin/bash
#
# verifica.sh di M7-E02 «Riprogettare un'interazione». I controlli stanno in
# verifica.py, accanto a questo file: legge le esecuzioni di
# tools/prova_assistente.sh in risultati/v0/ e risultati/v1/, ricalcola le
# asserzioni di ogni caso dallo stream e dal registro del server e confronta le
# due versioni. È fatta quando v1/ c'è ed entrambe le versioni hanno girato su
# ogni caso; il confronto si stampa come dato e non decide l'uscita. Non chiama
# niente: nessun modello, nessuna rete.
#
# Uso:    verifica.sh <spazio di lavoro>
# Env:    PN_HANDSON_ROOT  il repository (lo dà tools/verifica.sh)
# Uscita: 0 = v1/ c'è ed entrambe le versioni hanno girato su ogni caso · 1 =
#         una versione o un caso che manca, una chiamata non finita · 2 =
#         precondizione (spazio di lavoro assente; python3 o verifica.py che
#         mancano; il banco del repository che non si trova; un file che non
#         si legge; verifica.py uscito con un altro codice)
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
