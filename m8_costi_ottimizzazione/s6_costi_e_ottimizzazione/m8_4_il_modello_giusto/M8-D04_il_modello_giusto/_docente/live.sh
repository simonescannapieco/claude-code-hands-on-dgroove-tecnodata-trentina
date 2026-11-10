#!/bin/bash
#
# live.sh di M8-D04 -- la prova del docente, le esecuzioni per la registrazione
# del corso: demo/in_classe.sh dell'elemento, lo stesso che si lancia in aula,
# con tre esecuzioni per modello (nove chiamate), poi verifica.sh dell'elemento.
# Le chiamate, le loro opzioni e le cartelle stanno in demo/in_classe.sh:
# nessuna è diversa da quelle che l'aula vede.
#
# Uso:    _docente/live.sh <spazio di lavoro>
#           lo spazio di lavoro appena preparato (tools/prepara_esercizio.sh
#           M8-D04), con git status pulito
# Env:    PN_ESECUZIONI  quante esecuzioni per modello, da 1 a 9 (default 3); le
#         altre di demo/in_classe.sh e di tools/lib_handson.sh
# Uscita: 0 = ogni chiamata è finita e verifica.sh passa · 1 = una chiamata
#         fallita, un'esecuzione senza output strutturato, o verifica.sh che
#         non passa · 2 = precondizione
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
# lo script sta in <radice>/m8_…/s6_…/m8_4_…/M8-D04_…/_docente/
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
  handson::banner M8-D04 "Il modello giusto per il lavoro" \
    "la prova del docente: ${ESECUZIONI} esecuzioni per modello"
  handson::run env PN_ESECUZIONI="${ESECUZIONI}" HANDSON_NO_PAUSE=1 \
    bash "${ELEMENTO}/demo/in_classe.sh" "${ws}" || rc=$?
  handson::verdict_rc "${rc}" \
    "le chiamate e il controllo, ${ESECUZIONI} esecuzioni per modello"
  if (( rc == 0 )); then
    handson::check "verifica.sh dell'elemento" \
      env PN_HANDSON_ROOT="${RADICE}" "${ELEMENTO}/verifica.sh" "${ws}"
  fi
  handson::finish
}

main "$@"
