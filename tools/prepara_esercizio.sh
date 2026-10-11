#!/bin/bash
#
# prepara_esercizio.sh -- prepara lo spazio di lavoro di una demo o di un
# esercizio: una cartella nuova FUORI dal repository (di norma
# ~/corso-claude-code/<ID>/) con il punto di partenza dell'elemento
# (esercizio/ o demo/), i progetti condivisi che l'elemento elenca in
# progetti.txt e, se l'elemento non porta una sua .claude/, le
# impostazioni prudenti di .claude/settings.json del repository; poi git
# init e un primo commit, così `git diff` mostra che cosa è cambiato.
# Mai soluzione/ né _docente/. Uno spazio di lavoro che esiste già non si
# tocca: per ricominciare da capo c'è tools/reset_esercizio.sh.
#
# Uso:    tools/prepara_esercizio.sh <ID> [--radice <cartella>]
#           <ID>      M<N>-E<nn> per un esercizio, M<N>-D<nn> per una demo
#           --radice  dove creare <ID>/: un percorso assoluto fuori dal
#                     repository (default ~/corso-claude-code)
# Env:    PN_HANDSON_ROOT    il repository (default: la cartella sopra tools/)
#         PN_WORKSPACE_ROOT  la radice degli spazi di lavoro, se non c'è
#                            --radice
# Uscita: 0 = spazio di lavoro pronto
#         2 = precondizione: argomenti, elemento non trovato o incompleto,
#             spazio di lavoro già presente, git mancante
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
# shellcheck source=lib_handson.sh
source "${SELF%/*}/lib_handson.sh"

usage() {
  cat <<'EOF'
Uso: tools/prepara_esercizio.sh <ID> [--radice <cartella>]
  <ID>                  M<N>-E<nn> per un esercizio, M<N>-D<nn> per una demo
  --radice <cartella>   dove creare <ID>/ (default: ~/corso-claude-code)
EOF
}

# Il riepilogo per chi parte: dove andare, che cosa leggere, come
# verificare e come ricominciare.  Un esercizio parte con claude; una
# demo con i comandi del README (spesso `claude -p' in un ciclo, non una
# sessione interattiva); un elemento su claude.ai non lascia file nello
# spazio di lavoro, e la verifica, quando c'è, è del rifacimento in
# Claude Code che il README propone.
# Globals: HANDSON_WORKSPACE, HANDSON_ITEM_*, HANDSON_ROOT, HANDSON_ARG_RADICE.
print_next_steps() {
  local cartella radice='' readme verifica='Alla fine:        '
  handson::quote_into cartella "${HANDSON_WORKSPACE}"
  if [[ -n "${HANDSON_ARG_RADICE}" ]]; then
    handson::quote_into radice "${HANDSON_WORKSPACE_ROOT}"
    radice=" --radice ${radice}"
  fi
  readme="${HANDSON_ITEM_DIR#"${HANDSON_ROOT}"/}/README.md"
  printf 'Spazio di lavoro pronto per %s (%s): %s\n\n' "${HANDSON_ITEM_ID}" \
    "${HANDSON_ITEM_KIND}" "${HANDSON_WORKSPACE}"
  case "${HANDSON_ITEM_ENV}:${HANDSON_ITEM_KIND}" in
    claude-ai-pro:*)
      printf 'Questo elemento si svolge su claude.ai; i file di partenza\n'
      printf 'sono nella cartella qui sopra.\n'
      verifica='La verifica riguarda il rifacimento in Claude Code,'
      verifica+=$' se il README lo prevede:\n  ' ;;
    trainer-api:*)
      printf "Elemento del docente con l'API: lo esegue il docente.\n" ;;
    *:demo)
      printf '  cd %s\n  # poi i comandi del README, nel terminale\n' \
        "${cartella}" ;;
    *)
      printf '  cd %s\n  claude\n' "${cartella}" ;;
  esac
  printf "\nI passi da seguire sono nel README dell'elemento:\n  %s\n" \
    "${readme}"
  printf '%stools/verifica.sh %s%s\n' "${verifica}" "${HANDSON_ITEM_ID}" \
    "${radice}"
  printf 'Per ricominciare: tools/reset_esercizio.sh %s%s\n' \
    "${HANDSON_ITEM_ID}" "${radice}"
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
  handson::need_tools git
  handson::init_root || exit 2
  handson::find_item "${HANDSON_ARG_ID}" || exit 2
  handson::init_workspace_root "${HANDSON_ARG_RADICE}" || exit 2
  handson::prepare_workspace || exit 2
  print_next_steps
}

main "$@"
