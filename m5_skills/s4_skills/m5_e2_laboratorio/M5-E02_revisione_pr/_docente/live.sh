#!/bin/bash
#
# live.sh di M5-E02 -- la prova dal vivo della traccia (a) del laboratorio del
# Modulo 5, come la farebbe un partecipante, emulata in claude -p: tutto il
# lavoro sta in m5_skills/_docente/lib_lab_m5.sh (lab::una_prova), che dice i
# passi, che cosa sostituisce l'approvazione del partecipante e quali variabili
# legge. Tredici chiamate: undici di prove, due di scrittura.
#
# Uso:    _docente/live.sh <spazio di lavoro>
# Env:    PN_FEEDBACK, PN_LIVE_JSON, PN_LAB_STRUMENTI (vedi lib_lab_m5.sh); le
#         variabili di tools/lib_handson.sh
# Uscita: 0 = verifica.sh passa · 1 = una chiamata o un'esecuzione fallita, una
#         garanzia che non regge, o verifica.sh esce 1 · 2 = precondizione
#         (spazio di lavoro assente o con del lavoro, gli stream di una prova
#         di prima, un file o uno strumento che manca, un prompt che il README
#         non ha o che è cambiato), anche di verifica.sh
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
# lo script sta in <radice>/m5_…/s4_…/m5_e2_…/M5-E02_…/_docente/
readonly RADICE="${SELF%/*/*/*/*/*/*}"
# shellcheck source=../../../../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"
# shellcheck source=../../../../_docente/lib_lab_m5.sh
source "${RADICE}/m5_skills/_docente/lib_lab_m5.sh"

main() {
  if (( $# != 1 )); then
    echo "uso: _docente/live.sh <spazio di lavoro>" >&2
    exit 2
  fi
  local ws="$1"
  [[ -n "${ws}" && -d "${ws}" ]] \
    || handson::die "spazio di lavoro assente: ${ws}"
  handson::banner M5-E02 "Una skill di revisione contro le convenzioni" \
    "Modulo 5, laboratorio, traccia (a): il partecipante, emulato in claude -p"
  lab::una_prova M5-E02 "${ws}"
}

main "$@"
