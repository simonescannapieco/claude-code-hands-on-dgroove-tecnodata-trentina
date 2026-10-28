#!/bin/bash
#
# verifica.sh di M4-E01 «Un file mai visto» -- la spiegazione e il test del
# caso limite. I controlli stanno in verifica.py, accanto a questo file
# (python3, già richiesto dal corso): legge lo spazio di lavoro con git, a
# partire dal suo primo commit, ed esegue i test con tools/php.sh del
# repository, non con la copia dello spazio di lavoro. Stampa anche, come
# dati che non decidono l'uscita: le righe di spiegazione.md, le
# convenzioni dei test del progetto con l'esito della frase della guida sul
# file del test, se il test cade con il confine spostato di un giorno (in
# una copia), i file cambiati fuori da tests/.
#
# Uso:    verifica.sh <spazio di lavoro>
# Env:    PN_HANDSON_ROOT  il repository, per tools/php.sh (lo imposta
#                          tools/verifica.sh)
#         PN_PHP_SH        un altro strumento per PHP (le prove del docente)
# Uscita: 0 = spiegazione.md c'è e un test nuovo passa · 1 = qualcosa manca
#         o non passa · 2 = precondizione (spazio di lavoro assente, python3
#         mancante, git, il gestionale, lo strumento per PHP, vendor/, PHP
#         che non si avvia), un errore inatteso di verifica.py, anche
#         verifica.py uscito con un altro codice
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
  if ! command -v python3 >/dev/null 2>&1; then
    echo "verifica: manca python3 (PRIMA_DEL_CORSO.md, «Python e uv»)" >&2
    exit 2
  fi
  if [[ ! -r "${CONTROLLI}" ]]; then
    echo "verifica: manca ${CONTROLLI}" >&2
    exit 2
  fi
  python3 -B -I "${CONTROLLI}" "${ws}" || rc=$?
  case "${rc}" in
    0|1|2) exit "${rc}" ;;
    *) echo "verifica: il controllo è uscito con ${rc}" >&2
       exit 2 ;;
  esac
}

main "$@"
