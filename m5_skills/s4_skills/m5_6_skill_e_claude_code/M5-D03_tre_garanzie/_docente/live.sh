#!/bin/bash
#
# live.sh di M5-D03 -- la demo del docente, le esecuzioni per la registrazione
# del corso: in_classe.sh dello spazio di lavoro, lo stesso che si lancia in
# aula, con tre esecuzioni per braccio (trentatré chiamate; una coppia si ferma
# prima del modello, zero turni), poi verifica.sh dell'elemento. Le chiamate, le
# loro opzioni e le copie dei bracci stanno in demo/in_classe.sh e in
# demo/lib_coppie.sh: nessuna è diversa da quelle che l'aula vede.
#
# Uso:    _docente/live.sh <spazio di lavoro>
#         lo spazio di lavoro appena preparato (tools/prepara_esercizio.sh
#         M5-D03), con git status pulito
# Env:    PN_ESECUZIONI  quante esecuzioni per braccio, da 1 a 9 (default 3);
#         le variabili di tools/lib_handson.sh (HANDSON_ENV, se c'è, deve essere
#         claude-code-pro)
# Uscita: 0 = ogni garanzia confermata in ogni esecuzione · 1 = una chiamata
#         fallita, una garanzia non confermata, una coppia non distinguibile ·
#         2 = precondizione
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
# lo script sta in <radice>/m5_…/s4_…/m5_6_…/M5-D03_…/_docente/
readonly RADICE="${SELF%/*/*/*/*/*/*}"
readonly ELEMENTO="${SELF%/_docente/*}"
# shellcheck source=../../../../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"

readonly ESECUZIONI="${PN_ESECUZIONI:-3}"

# Le precondizioni, tutte prima della prima chiamata. Va chiamata nello spazio
# di lavoro.
precondizioni() {
  local radice stato
  [[ "${HANDSON_ENV}" == claude-code-pro ]] \
    || handson::die "M5-D03 è un elemento claude-code-pro: HANDSON_ENV" \
      "«${HANDSON_ENV}» non vale qui"
  handson::need_tools python3 git
  handson::need_file in_classe.sh
  handson::need_file controlla_garanzie.py
  [[ -x "${ELEMENTO}/verifica.sh" ]] \
    || handson::die "verifica.sh dell'elemento assente o non eseguibile"
  radice="$(git rev-parse --show-toplevel 2> /dev/null)" || radice=''
  [[ "${radice}" == "$(pwd -P)" ]] \
    || handson::die "$(pwd -P) non è un repository git: preparatelo con" \
      "tools/prepara_esercizio.sh M5-D03"
  stato="$(git status --porcelain)" || handson::die "git status non riesce"
  [[ -z "${stato}" ]] \
    || handson::die "lo spazio di lavoro non è al punto di partenza (git" \
      "status non è vuoto): tools/reset_esercizio.sh M5-D03"
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
  handson::banner M5-D03 "Tre garanzie" \
    "Modulo 5, «Skill e Claude Code»: !, allowed-tools, context: fork"
  handson::run env PN_ESECUZIONI="${ESECUZIONI}" HANDSON_NO_PAUSE=1 \
    bash in_classe.sh || rc=$?
  handson::verdict_rc "${rc}" \
    "le garanzie, ${ESECUZIONI} esecuzioni per braccio"
  if (( rc == 0 )); then
    handson::check "verifica.sh dell'elemento" \
      "${ELEMENTO}/verifica.sh" "$(pwd -P)"
  fi
  handson::finish
}

main "$@"
