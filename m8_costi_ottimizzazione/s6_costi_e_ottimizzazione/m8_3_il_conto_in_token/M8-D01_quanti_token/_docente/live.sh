#!/bin/bash
#
# live.sh di M8-D01 -- la prova del docente, per la registrazione del corso:
# demo/chiama.sh dell'elemento, lo stesso che si lancia in aula, sui due testi
# della demo, poi verifica.sh dell'elemento. Serve la chiave del docente
# nell'ambiente: senza ANTHROPIC_API_KEY esce 2 prima di ogni chiamata. La
# chiave non si scrive e non si stampa: arriva a curl sullo STDIN, in
# demo/chiama.sh.
#
# Uso:    _docente/live.sh <spazio di lavoro>
# Env:    ANTHROPIC_API_KEY  la chiave del docente
#         le altre di demo/chiama.sh e di tools/lib_handson.sh
# Uscita: 0 = ogni conteggio è arrivato e verifica.sh passa · 1 = una chiamata
#         fallita, o un conteggio che verifica.sh non accetta · 2 =
#         precondizione (senza la chiave, spazio di lavoro assente), anche
#         di verifica.sh
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
# lo script sta in <radice>/m8_…/s6_…/m8_3_…/M8-D01_…/_docente/
readonly RADICE="${SELF%/*/*/*/*/*/*}"
readonly ELEMENTO="${SELF%/_docente/*}"
# shellcheck source=../../../../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"

main() {
  if (( $# != 1 )); then
    echo "uso: _docente/live.sh <spazio di lavoro>" >&2
    exit 2
  fi
  handson::need_api_key
  local ws="$1" rc=0
  [[ -n "${ws}" && -d "${ws}" ]] \
    || handson::die "spazio di lavoro assente: ${ws}"
  ws="$(cd -- "${ws}" && pwd -P)" \
    || handson::die "lo spazio di lavoro $1 non si apre"
  [[ -x "${ELEMENTO}/verifica.sh" && -f "${ELEMENTO}/demo/chiama.sh" ]] \
    || handson::die "verifica.sh o demo/chiama.sh dell'elemento mancano"
  handson::banner M8-D01 "Quanti token pesa una frase" \
    "la prova del docente, con la sua chiave"
  handson::run env PN_HANDSON_ROOT="${RADICE}" HANDSON_NO_PAUSE=1 \
    bash "${ELEMENTO}/demo/chiama.sh" "${ws}" || rc=$?
  handson::verdict_rc "${rc}" "le POST e i conteggi"
  if (( rc == 0 )); then
    handson::check "verifica.sh dell'elemento" \
      env PN_HANDSON_ROOT="${RADICE}" "${ELEMENTO}/verifica.sh" "${ws}"
  fi
  handson::finish
}

main "$@"
