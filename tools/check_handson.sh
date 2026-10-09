#!/bin/bash
#
# check_handson.sh -- controlla la struttura del repository delle
# esercitazioni:
#   - la radice: README.md, PRIMA_DEL_CORSO.md, CLAUDE.md, .gitattributes
#     (con le regole che tengono soluzione/ e _docente/ fuori dalla copia
#     per i partecipanti), .gitignore, .claude/settings.json, progetti/ con
#     i tre progetti, riferimenti/, tools/, tests/;
#   - i nove moduli m<N>_<nome>/, ciascuno con README.md e manifest.tsv;
#   - ogni riga dei manifest: id M<N>-D<nn>/M<N>-E<nn> del modulo giusto e
#     coerente con kind (demo|esercizio), env (claude-code-pro,
#     claude-ai-pro, trainer-api), section_dir, subdeck_dir, deck_path,
#     minutes intero, title_it, le cartelle che nomina;
#   - ogni elemento: README.md con le dieci sezioni, verifica.sh
#     eseguibile, esercizio/ o demo/ secondo kind, soluzione/, progetti.txt
#     che nomina progetti esistenti;
#   - gli id unici in tutto il repository; nessuna cartella di elemento
#     che i manifest non nominano; gli script eseguibili, le librerie
#     (lib_*.sh) no.
# Nella copia per i partecipanti (tools/esporta_studenti.sh) soluzione/ e
# _docente/ non si cercano: devono mancare. Gli alberi di prova di
# tests/fixtures/ restano fuori; i file li elenca git, quindi vendor/ e
# gli altri file ignorati non contano.
#
# Uso:    tools/check_handson.sh
# Env:    PN_HANDSON_ROOT  l'albero da controllare (default: la cartella
#                          sopra tools/)
# Uscita: 0 = tutto in ordine · 1 = almeno una segnalazione
#         2 = precondizione (radice assente, git mancante, non è un
#             repository git)
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
# shellcheck source=lib_handson.sh
source "${SELF%/*}/lib_handson.sh"

usage() {
  printf 'Uso: tools/check_handson.sh\n'
}

# Nella copia per i partecipanti: nessuna soluzione/ né _docente/.
# Returns: 0; 2 se l'elenco non riesce.
check_export() {
  local trovate d
  handson::tmpfile trovate
  handson::trainer_dirs "${HANDSON_ROOT}" "${trovate}" || return 2
  while IFS= read -r d; do
    handson::finding "${d}/" "nella copia per i partecipanti non deve esserci"
  done < "${trovate}"
}

main() {
  if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
  fi
  if (( $# > 0 )); then
    usage >&2
    exit 2
  fi
  handson::need_tools git
  handson::init_root || exit 2
  local elenco n
  handson::tmpfile elenco
  handson::list_files "${elenco}" || exit 2
  handson::check_layout
  for n in 1 2 3 4 5 6 7 8 9; do
    handson::check_module "${n}"
  done
  handson::check_unique_ids || exit 2
  handson::check_orphans "${elenco}"
  handson::check_scripts "${elenco}"
  if handson::is_export; then
    check_export || exit 2
  fi
  local esito=OK
  (( HANDSON_FINDINGS == 0 )) || esito=KO
  printf 'check_handson: %d elementi, %d segnalazioni -- ESITO: %s\n' \
    "${#HANDSON_IDS[@]}" "${HANDSON_FINDINGS}" "${esito}"
  (( HANDSON_FINDINGS == 0 )) || exit 1
}

main "$@"
