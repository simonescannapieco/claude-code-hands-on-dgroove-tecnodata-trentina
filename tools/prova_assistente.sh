#!/bin/bash
#
# prova_assistente.sh -- il punto di ingresso del banco di prova
# dell'assistente: esegue prova.py o confronta.py della copia del banco che sta
# nello spazio di lavoro (progetti/assistenza-clienti/banco/), mostrando il
# comando prima di eseguirlo. La spiegazione dei comandi è nel README del banco.
#
# Uso:    tools/prova_assistente.sh <spazio di lavoro> <comando> [opzioni]
#           comando: casi | conversazione | giudica | confronta
# Uscita: 0 = ogni chiamata è finita bene · 1 = una chiamata che non è finita,
#         o un confronto incompleto · 2 = precondizione (spazio di lavoro o
#         banco assenti, strumenti mancanti, comando sconosciuto)
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
# shellcheck source=lib_handson.sh
source "${SELF%/*}/lib_handson.sh"

readonly BANCO_RELATIVO="progetti/assistenza-clienti/banco"

usage() {
  printf 'Uso: tools/prova_assistente.sh <spazio di lavoro> <comando> [opzioni]\n'
  printf '  comando: casi | conversazione | giudica | confronta\n'
}

main() {
  if (( $# < 2 )); then
    usage >&2
    exit 2
  fi
  local ws="$1" comando="$2" banco script
  shift 2
  [[ -n "${ws}" && -d "${ws}" ]] \
    || handson::die "spazio di lavoro assente: ${ws}"
  ws="$(cd -- "${ws}" && pwd -P)" \
    || handson::die "lo spazio di lavoro non si apre"
  banco="${ws}/${BANCO_RELATIVO}"
  [[ -f "${banco}/prova.py" ]] \
    || handson::die "in ${ws} manca il banco di prova: ${BANCO_RELATIVO}"
  handson::need_tools python3
  local -a argomenti=()
  case "${comando}" in
    casi|conversazione|giudica)
      handson::need_claude
      handson::need_tools uv
      script=prova.py
      argomenti=("${comando}")
      ;;
    confronta)
      script=confronta.py
      ;;
    *)
      usage >&2
      exit 2
      ;;
  esac
  # Questo strumento non ha la pausa dell'aula: tre comandi incollati insieme
  # devono girare tutti e tre.
  HANDSON_NO_PAUSE=1
  handson::run python3 -B -I "${banco}/${script}" \
    ${argomenti[@]+"${argomenti[@]}"} "$@"
}

main "$@"
