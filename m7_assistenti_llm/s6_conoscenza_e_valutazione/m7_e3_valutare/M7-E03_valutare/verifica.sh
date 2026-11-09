#!/bin/bash
#
# verifica.sh di M7-E03 «Valutare e non regredire» -- i controlli stanno in
# verifica.py, accanto a questo file: la taratura del giudice (i suoi verdetti
# contro le etichette, un dato), il caso nuovo e il suo opposto (esistono, sono
# sullo stesso scenario, sono stati eseguiti), la tabella di regressione sui
# cinque casi forniti, le due versioni. È fatta quando il lavoro c'è: gli esiti
# si stampano e non la decidono.
#
# Uso:    verifica.sh <spazio di lavoro>
# Env:    PN_HANDSON_ROOT  il repository (lo dà tools/verifica.sh; non serve
#                          al controllo)
# Uscita: 0 = i tre passi sono fatti · 1 = non ancora, e dice che cosa manca ·
#         2 = precondizione (spazio di lavoro assente, python3 o il controllo
#         che mancano, un file che non si legge)
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly CONTROLLO="${SELF%/*}/verifica.py"

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
  if [[ ! -f "${CONTROLLO}" || ! -r "${CONTROLLO}" ]]; then
    echo "verifica: manca il controllo ${CONTROLLO}" >&2
    exit 2
  fi
  python3 -B -I "${CONTROLLO}" "${ws}" || rc=$?
  case "${rc}" in
    0|1|2) exit "${rc}" ;;
    *)
      echo "verifica: verifica.py è uscito con ${rc}, fuori dal suo" \
        "contratto: un errore del controllo, non un esito" >&2
      exit 2
      ;;
  esac
}

main "$@"
