#!/bin/bash
#
# live.sh di M5-D05 -- la parte locale della demo: i tre ZIP nello spazio di
# lavoro, il controllo locale, una dimostrazione, e la verifica. Il caricamento
# e la chat stanno su claude.ai, e non passano di qui: nessuna chiamata a
# claude.
#
# Uso:    _docente/live.sh <spazio di lavoro>
#         lo spazio di lavoro preparato con tools/prepara_esercizio.sh M5-D05
# Env:    le variabili di tools/lib_handson.sh
# Uscita: 0 = i tre ZIP e i tre esiti attesi · 1 = un esito diverso · 2 =
#         precondizione
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
# lo script sta in <radice>/m5_skills/s4_skills/m5_e4_…/M5-D05_…/_docente/
readonly RADICE="${SELF%/*/*/*/*/*/*}"
readonly ELEMENTO="${SELF%/_docente/*}"
# shellcheck source=../../../../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"

# Un comando con il suo STDOUT sul descrittore 3: handson::check mostra un
# controllo solo su un KO, e qui i dati sono la demo anche quando passa.
# Arguments: il comando. Returns: la sua uscita.
# shellcheck disable=SC2317  # la chiama handson::check, indirettamente
a_schermo() {
  "$@" >&3
}

main() {
  if (( $# != 1 )); then
    echo "uso: _docente/live.sh <spazio di lavoro>" >&2
    exit 2
  fi
  local ws="$1" f
  [[ -n "${ws}" && -d "${ws}" ]] \
    || handson::die "spazio di lavoro assente: ${ws}"
  cd -- "${ws}" || handson::die "lo spazio di lavoro ${ws} non si apre"
  handson::need_tools python3
  for f in impacchetta.sh impacchetta.py controlla.sh; do
    handson::need_file "${f}"
  done
  handson::init_root || exit 2
  export PN_HANDSON_ROOT="${HANDSON_ROOT}"
  handson::banner M5-D05 "La stessa skill in claude.ai" \
    "Modulo 5: la parte locale; il caricamento e la chat stanno su claude.ai"
  handson::step "I tre ZIP"
  handson::run ./impacchetta.sh pacchetti
  exec 3>&1
  handson::step "Il controllo locale"
  handson::check "i tre esiti attesi, una dimostrazione" \
    a_schermo ./controlla.sh pacchetti
  handson::step "La verifica"
  handson::check "i tre ZIP" a_schermo "${ELEMENTO}/verifica.sh" "$(pwd -P)"
  handson::finish
}

main "$@"
