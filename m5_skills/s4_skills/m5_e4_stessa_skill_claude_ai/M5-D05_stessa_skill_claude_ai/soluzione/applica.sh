#!/bin/bash
#
# applica.sh di M5-D05 -- la soluzione: i tre ZIP, costruiti dallo script dello
# spazio di lavoro. Ciò che succede su claude.ai non sta qui: lo si guarda sullo
# schermo. tools/run_all.sh la applica con PN_HANDSON_ROOT già impostata.
#
# Uso:    soluzione/applica.sh <spazio di lavoro>
# Env:    PN_HANDSON_ROOT  il repository
# Uscita: 0 = i tre ZIP · 2 = precondizione (spazio di lavoro o script assenti,
#         PN_HANDSON_ROOT, python3)
set -euo pipefail

main() {
  local ws="${1:-}"
  if [[ -z "${ws}" || ! -x "${ws}/impacchetta.sh" ]]; then
    echo "applica: spazio di lavoro assente o senza impacchetta.sh: ${ws}" >&2
    exit 2
  fi
  "${ws}/impacchetta.sh" "${ws}/pacchetti"
}

main "$@"
