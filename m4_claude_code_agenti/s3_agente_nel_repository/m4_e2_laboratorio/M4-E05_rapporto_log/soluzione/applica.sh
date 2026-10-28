#!/bin/bash
#
# applica.sh di M4-E05 -- applica la soluzione di riferimento a uno spazio
# di lavoro: lo script del rapporto, in Python (rapporto_giornaliero.py),
# e NOTA.md, copiati nella cartella dello spazio di lavoro. Non fa commit:
# la verifica prova lo script com'è nello spazio di lavoro.
#
# Uso:    soluzione/applica.sh <spazio di lavoro>
# Uscita: 0 = soluzione applicata · 2 = precondizione (spazio di lavoro
#         assente o senza progetti/rete, una copia che non riesce)
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly SOLUZIONE="${SELF%/*}"

err() { echo "applica: $*" >&2; }

main() {
  local ws="${1:-}"
  if [[ -z "${ws}" || ! -d "${ws}/progetti/rete" ]]; then
    err "spazio di lavoro assente o senza progetti/rete: ${ws}"
    exit 2
  fi
  if ! cp -- "${SOLUZIONE}/rapporto_giornaliero.py" \
      "${ws}/rapporto_giornaliero.py" \
      || ! cp -- "${SOLUZIONE}/NOTA.md" "${ws}/NOTA.md"; then
    err "la copia della soluzione non riesce"
    exit 2
  fi
}

main "$@"
