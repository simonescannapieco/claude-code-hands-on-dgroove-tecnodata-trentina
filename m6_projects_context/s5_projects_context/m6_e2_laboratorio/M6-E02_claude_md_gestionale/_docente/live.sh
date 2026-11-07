#!/bin/bash
#
# live.sh di M6-E02 -- la prova dal vivo della traccia del gestionale del
# laboratorio del Modulo 6, come la farebbe un partecipante, emulata in
# claude -p: tutto il lavoro sta in m6_projects_context/_docente/lib_lab_m6.sh
# (lab6::una_prova), che dice i passi, che cosa sostituisce l'approvazione
# del partecipante e quali variabili legge. Dodici chiamate: nove di prove,
# tre di scrittura.
#
# Uso:    _docente/live.sh <spazio di lavoro>
# Env:    PN_LIVE_JSON, PN_LAB_STRUMENTI (vedi lib_lab_m6.sh); le variabili di
#         tools/lib_handson.sh
# Uscita: 0 = verifica.sh passa · 1 = una chiamata o un'esecuzione fallita, una
#         garanzia che non regge, un passo che non lascia ciò che deve, o
#         verifica.sh esce 1 · 2 = precondizione (spazio di lavoro assente o
#         con del lavoro, gli stream di una prova di prima, un file o uno
#         strumento che manca, un prompt che il README non ha), anche di
#         verifica.sh
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
# lo script sta in <radice>/m6_…/s5_…/m6_e2_…/M6-E02_…/_docente/
readonly RADICE="${SELF%/*/*/*/*/*/*}"
# shellcheck source=../../../../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"
# shellcheck source=../../../../_docente/lib_lab_m6.sh
source "${RADICE}/m6_projects_context/_docente/lib_lab_m6.sh"

main() {
  if (( $# != 1 )); then
    echo "uso: _docente/live.sh <spazio di lavoro>" >&2
    exit 2
  fi
  local ws="$1"
  [[ -n "${ws}" && -d "${ws}" ]] \
    || handson::die "spazio di lavoro assente: ${ws}"
  handson::banner M6-E02 "Un CLAUDE.md per il gestionale" \
    "Modulo 6, laboratorio, traccia del gestionale: il partecipante, emulato"
  lab6::una_prova M6-E02 "${ws}"
}

main "$@"
