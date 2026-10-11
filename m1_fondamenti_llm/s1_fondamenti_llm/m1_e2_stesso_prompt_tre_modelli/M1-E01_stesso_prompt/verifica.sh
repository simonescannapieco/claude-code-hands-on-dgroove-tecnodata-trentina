#!/bin/bash
#
# verifica.sh di M1-E01 -- lo stesso prompt su tre modelli. I controlli
# stanno in verifica.py, accanto a questo file (python3, già richiesto dal
# corso): i tre JSON di risposte/, confronto.md compilato, e i numeri della
# tabella uguali a quelli dei JSON. Chi li ha scritti, voi o Claude, va
# verificato: è parte dell'esercizio.
#
# Uso:    verifica.sh <spazio di lavoro>
# Uscita: 0 = tutto compilato e coerente · 1 = qualcosa manca o non torna
#         2 = precondizione (spazio di lavoro assente, python3 mancante, un
#             file che c'è ma non si legge)
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly CONTROLLI="${SELF%/*}/verifica.py"

main() {
  local ws="${1:-}"
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
  python3 -B -I "${CONTROLLI}" "${ws}"
}

main "$@"
