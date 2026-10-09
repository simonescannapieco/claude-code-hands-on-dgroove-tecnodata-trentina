#!/bin/bash
#
# reset_esercizio.sh -- ricomincia da capo una demo o un esercizio: cancella
# lo spazio di lavoro dell'elemento e lo prepara di nuovo con
# tools/prepara_esercizio.sh. Le modifiche fatte nello spazio di lavoro
# vanno perse; su un terminale chiede conferma (-y non la chiede).
# Cancella solo una cartella che supera tutti i controlli (RU-01.S5): non
# vuota né /, non un collegamento simbolico, esattamente
# <radice>/<ID> e con il segno che vi lascia prepara_esercizio.sh. Se lo
# spazio di lavoro non c'è, lo prepara e basta.
#
# Uso:    tools/reset_esercizio.sh <ID> [--radice <cartella>] [-y|--si]
# Env:    PN_HANDSON_ROOT    il repository (default: la cartella sopra tools/)
#         PN_WORKSPACE_ROOT  la radice degli spazi di lavoro, se non c'è
#                            --radice
# Uscita: 0 = spazio di lavoro di nuovo pronto (o conferma negata: niente
#         toccato) · 2 = precondizione: argomenti, elemento non trovato,
#         cartella che non supera i controlli, git mancante
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
# shellcheck source=lib_handson.sh
source "${SELF%/*}/lib_handson.sh"

usage() {
  cat <<'EOF'
Uso: tools/reset_esercizio.sh <ID> [--radice <cartella>] [-y|--si]
  <ID>                  l'elemento da ricominciare
  --radice <cartella>   la stessa data a prepara_esercizio.sh, se c'era
  -y, --si              non chiedere conferma
EOF
}

# Chiede conferma, ma solo su un terminale e senza -y: negli script e nei
# test non c'è nessuno a cui chiedere.
# Globals: HANDSON_ARG_SI. Arguments: $1 lo spazio di lavoro.
# Returns: 0 sì; 1 no.
conferma() {
  if [[ "${HANDSON_ARG_SI}" == "1" || ! -t 0 ]]; then
    return 0
  fi
  local risposta=''
  printf 'Cancello %s e lo preparo da capo?' "$1" >&2
  printf ' Le modifiche andranno perse. [s/N] ' >&2
  if ! read -r risposta; then
    risposta=''
  fi
  [[ "${risposta}" == [sSyY]* ]]
}

main() {
  if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
  fi
  if ! handson::parse_item_args 1 "$@"; then
    usage >&2
    exit 2
  fi
  handson::need_tools git
  handson::init_root || exit 2
  handson::find_item "${HANDSON_ARG_ID}" || exit 2
  handson::init_workspace_root "${HANDSON_ARG_RADICE}" || exit 2
  local ws="${HANDSON_WORKSPACE_ROOT}/${HANDSON_ITEM_ID}"
  local -a prepara=("${HANDSON_ITEM_ID}")
  if [[ -n "${HANDSON_ARG_RADICE}" ]]; then
    prepara+=(--radice "${HANDSON_ARG_RADICE}")
  fi
  if [[ -e "${ws}" || -L "${ws}" ]]; then
    handson::guard_workspace "${ws}" "${HANDSON_ITEM_ID}" || exit 2
    if ! conferma "${ws}"; then
      printf "Annullato: lo spazio di lavoro resta com'è.\n"
      exit 0
    fi
    rm -rf -- "${ws}"
    printf 'Cancellato: %s\n' "${ws}"
  else
    printf "Lo spazio di lavoro di %s non c'era: lo preparo.\n" \
      "${HANDSON_ITEM_ID}"
  fi
  exec "${SELF%/*}/prepara_esercizio.sh" "${prepara[@]}"
}

main "$@"
