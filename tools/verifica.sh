#!/bin/bash
#
# verifica.sh -- verifica il lavoro fatto su una demo o un esercizio: esegue
# il verifica.sh dell'elemento sul suo spazio di lavoro e ne riporta
# l'esito, invariato. Il verifica.sh dell'elemento riceve lo spazio di
# lavoro come primo argomento, gira con lo spazio di lavoro come cartella
# corrente e trova il repository in PN_HANDSON_ROOT (per esempio per
# tools/php.sh); i suoi controlli sono deterministici.
#
# Uso:    tools/verifica.sh <ID> [--radice <cartella>]
#           --radice  la stessa data a prepara_esercizio.sh, se c'era
# Env:    PN_HANDSON_ROOT    il repository (default: la cartella sopra tools/)
#         PN_WORKSPACE_ROOT  la radice degli spazi di lavoro, se non c'è
#                            --radice
# Uscita: 0 = fatto · 1 = non ancora (il verifica.sh dell'elemento dice
#         che cosa manca) · 2 = precondizione: elemento o spazio di lavoro
#         mancante, verifica.sh dell'elemento assente o non eseguibile, o
#         uscito con un codice fuori dal contratto 0/1/2
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
# shellcheck source=lib_handson.sh
source "${SELF%/*}/lib_handson.sh"

usage() {
  cat <<'EOF'
Uso: tools/verifica.sh <ID> [--radice <cartella>]
  <ID>                  l'elemento preparato con tools/prepara_esercizio.sh
  --radice <cartella>   la stessa data a prepara_esercizio.sh, se c'era
EOF
}

main() {
  if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
  fi
  if ! handson::parse_item_args 0 "$@"; then
    usage >&2
    exit 2
  fi
  handson::init_root || exit 2
  handson::find_item "${HANDSON_ARG_ID}" || exit 2
  handson::init_workspace_root "${HANDSON_ARG_RADICE}" || exit 2
  handson::find_workspace || exit 2
  local controllo="${HANDSON_ITEM_DIR}/verifica.sh" rc=0
  if [[ ! -f "${controllo}" || ! -x "${controllo}" ]]; then
    handson::err "${HANDSON_ITEM_ID}: verifica.sh dell'elemento assente o" \
      "non eseguibile"
    exit 2
  fi
  (
    cd "${HANDSON_WORKSPACE}" \
      && PN_HANDSON_ROOT="${HANDSON_ROOT}" "${controllo}" "${HANDSON_WORKSPACE}"
  ) || rc=$?
  case "${rc}" in
    0) printf 'VERIFICA OK   %s: fatto.\n' "${HANDSON_ITEM_ID}" ;;
    1) printf 'NON ANCORA    %s: guarda i messaggi qui sopra.\n' \
         "${HANDSON_ITEM_ID}" ;;
    2) handson::err "${HANDSON_ITEM_ID}: la verifica non può partire" \
         "(precondizione, vedi sopra)" ;;
    *) handson::err "${HANDSON_ITEM_ID}: verifica.sh dell'elemento è uscito" \
         "con ${rc}, fuori dal contratto 0/1/2"
       exit 2 ;;
  esac
  exit "${rc}"
}

main "$@"
