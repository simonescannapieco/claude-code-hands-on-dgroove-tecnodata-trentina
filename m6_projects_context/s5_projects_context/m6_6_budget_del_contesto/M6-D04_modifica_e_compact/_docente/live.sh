#!/bin/bash
#
# live.sh di M6-D04 -- la prova del docente, le esecuzioni per la registrazione
# del corso: demo/in_classe.sh dell'elemento, lo stesso che si lancia in aula,
# con tre esecuzioni, cioè nove sessioni di claude -p con --input-format
# stream-json (compact, clear e regola, cinque passi ciascuna); poi
# verifica.sh dell'elemento. Le sessioni, le loro opzioni e le copie stanno in
# demo/in_classe.sh e in demo/sessione.py: nessuna è diversa da quelle che
# l'aula vede.
#
# Uso:    _docente/live.sh <spazio di lavoro>
#         lo spazio di lavoro appena preparato (tools/prepara_esercizio.sh
#         M6-D04), con git status pulito
# Env:    PN_ESECUZIONI  quante esecuzioni, da 1 a 9 (default 3); le
#         variabili di tools/lib_handson.sh (HANDSON_ENV, se c'è, deve essere
#         claude-code-pro)
# Uscita: 0 = ogni garanzia confermata in ogni esecuzione · 1 = una sessione
#         fallita, una garanzia non confermata o non messa alla prova ·
#         2 = precondizione
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
# lo script sta in <radice>/m6_…/s5_…/m6_6_…/M6-D04_…/_docente/
readonly RADICE="${SELF%/*/*/*/*/*/*}"
readonly ELEMENTO="${SELF%/_docente/*}"
# shellcheck source=../../../../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"

readonly ESECUZIONI="${PN_ESECUZIONI:-3}"

# Le precondizioni, tutte prima della prima sessione. Va chiamata nello
# spazio di lavoro.
precondizioni() {
  local radice stato
  [[ "${HANDSON_ENV}" == claude-code-pro ]] \
    || handson::die "M6-D04 è un elemento claude-code-pro: HANDSON_ENV" \
      "«${HANDSON_ENV}» non vale qui"
  handson::need_tools python3 git
  handson::need_file "${ELEMENTO}/demo/in_classe.sh"
  [[ -x "${ELEMENTO}/verifica.sh" ]] \
    || handson::die "verifica.sh dell'elemento assente o non eseguibile"
  radice="$(git rev-parse --show-toplevel 2> /dev/null)" || radice=''
  [[ "${radice}" == "$(pwd -P)" ]] \
    || handson::die "$(pwd -P) non è un repository git: preparatelo con" \
      "tools/prepara_esercizio.sh M6-D04"
  stato="$(git status --porcelain)" || handson::die "git status non riesce"
  [[ -z "${stato}" ]] \
    || handson::die "lo spazio di lavoro non è al punto di partenza (git" \
      "status non è vuoto): tools/reset_esercizio.sh M6-D04"
  handson::need_claude
}

main() {
  if (( $# != 1 )); then
    echo "uso: _docente/live.sh <spazio di lavoro>" >&2
    exit 2
  fi
  local ws="$1" rc=0
  [[ -n "${ws}" && -d "${ws}" ]] \
    || handson::die "spazio di lavoro assente: ${ws}"
  cd -- "${ws}" || handson::die "lo spazio di lavoro ${ws} non si apre"
  precondizioni
  handson::banner M6-D04 "Una modifica a sessione avviata, e dopo /compact" \
    "Modulo 6, la prova del docente: ${ESECUZIONI} esecuzioni"
  handson::run env PN_ESECUZIONI="${ESECUZIONI}" HANDSON_NO_PAUSE=1 \
    PN_HANDSON_ROOT="${RADICE}" "${ELEMENTO}/demo/in_classe.sh" \
    "$(pwd -P)" || rc=$?
  handson::verdict_rc "${rc}" "le garanzie, ${ESECUZIONI} esecuzioni"
  if (( rc == 0 )); then
    handson::check "verifica.sh dell'elemento" \
      env PN_HANDSON_ROOT="${RADICE}" "${ELEMENTO}/verifica.sh" "$(pwd -P)"
  fi
  handson::finish
}

main "$@"
