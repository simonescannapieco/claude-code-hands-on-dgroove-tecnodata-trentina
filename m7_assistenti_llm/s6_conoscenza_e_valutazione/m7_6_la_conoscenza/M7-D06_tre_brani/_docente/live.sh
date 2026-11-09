#!/bin/bash
#
# live.sh di M7-D06 -- la prova del docente, le esecuzioni per la registrazione
# del corso: demo/in_classe.sh dell'elemento, lo stesso che si lancia in aula,
# con tre esecuzioni per braccio (due bracci, due domande: dodici chiamate di
# claude -p, dentro il banco di prova), poi verifica.sh dell'elemento.
#
# Uso:    _docente/live.sh <spazio di lavoro>
#           lo spazio di lavoro appena preparato (tools/prepara_esercizio.sh
#           M7-D06), con git status pulito
# Env:    PN_ESECUZIONI  quante esecuzioni per braccio, da 1 a 9 (default 3);
#         le altre di demo/in_classe.sh e di tools/lib_handson.sh
# Uscita: 0 = ogni chiamata è finita e verifica.sh passa · 1 = una chiamata
#         fallita, o verifica.sh che non passa · 2 = precondizione
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
# lo script sta in <radice>/m7_…/s6_…/m7_6_…/M7-D06_…/_docente/
readonly RADICE="${SELF%/*/*/*/*/*/*}"
readonly ELEMENTO="${SELF%/_docente/*}"
# shellcheck source=../../../../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"

readonly ESECUZIONI="${PN_ESECUZIONI:-3}"

main() {
  if (( $# != 1 )); then
    echo "uso: _docente/live.sh <spazio di lavoro>" >&2
    exit 2
  fi
  local ws="$1" rc=0
  [[ -n "${ws}" && -d "${ws}" ]] \
    || handson::die "spazio di lavoro assente: ${ws}"
  ws="$(cd -- "${ws}" && pwd -P)" \
    || handson::die "lo spazio di lavoro $1 non si apre"
  [[ -x "${ELEMENTO}/verifica.sh" && -f "${ELEMENTO}/demo/in_classe.sh" ]] \
    || handson::die "verifica.sh o demo/in_classe.sh dell'elemento mancano"
  handson::banner M7-D06 "Tre brani, una risposta con la fonte" \
    "la prova del docente: ${ESECUZIONI} esecuzioni per braccio"
  handson::run env PN_ESECUZIONI="${ESECUZIONI}" HANDSON_NO_PAUSE=1 \
    bash "${ELEMENTO}/demo/in_classe.sh" "${ws}" || rc=$?
  handson::verdict_rc "${rc}" \
    "le esecuzioni e il controllo, ${ESECUZIONI} per braccio"
  if (( rc == 0 )); then
    handson::check "verifica.sh dell'elemento" \
      env PN_HANDSON_ROOT="${RADICE}" "${ELEMENTO}/verifica.sh" "${ws}"
  fi
  handson::finish
}

main "$@"
