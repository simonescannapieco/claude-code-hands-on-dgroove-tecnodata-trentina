#!/bin/bash
#
# prima.sh di M6-E03 -- tools/prova_contesto.sh lo esegue in ogni copia dello
# spazio di lavoro, prima del commit di partenza della copia: rimette il
# refuso nello standard di AUD-02 di progetti/rete/checklist-audit.md, dal
# file del punto di partenza dell'elemento. Così ogni versione prova la
# seconda richiesta sullo stesso file, anche se nello spazio di lavoro il
# refuso è già corretto.
#
# Uso:    prove/prima.sh <copia> <id della richiesta>
# Uscita: 0 = refuso rimesso · 2 = precondizione (argomenti, una copia senza
#         il progetto rete, il file del punto di partenza che manca)
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly ELEMENTO="${SELF%/prove/*}"
readonly FILE='progetti/rete/checklist-audit.md'

err() { echo "prima.sh: $*" >&2; }

main() {
  if (( $# != 2 )) || [[ -z "$1" || ! -d "$1" ]]; then
    err "uso: prove/prima.sh <copia> <id della richiesta>"
    exit 2
  fi
  local copia="$1" partenza="${ELEMENTO}/esercizio/${FILE}"
  if [[ ! -f "${partenza}" || ! -r "${partenza}" ]]; then
    err "manca il file del punto di partenza: ${partenza}"
    exit 2
  fi
  if [[ ! -d "${copia}/${FILE%/*}" || -L "${copia}/${FILE}" ]]; then
    err "la copia non ha ${FILE%/*}/, o il file è un collegamento"
    exit 2
  fi
  if ! cp -- "${partenza}" "${copia}/${FILE}"; then
    err "non riesco a rimettere ${FILE} nella copia"
    exit 2
  fi
}

main "$@"
