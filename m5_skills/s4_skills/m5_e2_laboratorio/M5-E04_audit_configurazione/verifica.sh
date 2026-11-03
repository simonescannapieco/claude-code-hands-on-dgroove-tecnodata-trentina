#!/bin/bash
#
# verifica.sh di M5-E04 «Una skill di audit delle configurazioni» -- il lavoro
# del laboratorio. I controlli stanno in verifica.py, accanto a questo file:
# legge gli stream delle prove, ogni volta da capo, e non scrive niente. Decide
# che il lavoro è stato fatto: la skill passa il controllo del file, i tre casi
# girati senza la skill e con le due versioni, la near-miss, i commenti in
# iteration-1/feedback.json, le due versioni diverse, e che senza la skill non
# ci sia stata nessuna chiamata alla skill. Tutto il resto, le asserzioni, i
# confronti e i file letti, lo stampa come dati.
#
# Uso:    verifica.sh <spazio di lavoro>
# Env:    PN_HANDSON_ROOT  il repository (lo imposta tools/verifica.sh)
# Uscita: 0 = fatto · 1 = qualcosa manca, o una garanzia non regge · 2 =
#         precondizione (spazio di lavoro assente, python3 mancante, verifica.py
#         assente o uscito con un altro codice, un file che non si legge)
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
