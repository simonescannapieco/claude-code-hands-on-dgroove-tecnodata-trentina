#!/bin/bash
#
# live.sh di M7-D05 -- la prova del docente, sul suo computer: cerca.py dello
# spazio di lavoro (le due ricerche, le classifiche, risposte/risultati.json),
# poi verifica.sh dell'elemento. Non avvia nessun servizio: Ollama deve essere
# già in ascolto su questo computer, con il modello embeddinggemma:300m; se
# non risponde, cerca.py esce 2 con un messaggio chiaro. Nessuna chiamata a
# Claude.
#
# Uso:    _docente/live.sh <spazio di lavoro>
#           lo spazio di lavoro preparato con tools/prepara_esercizio.sh M7-D05
# Env:    PN_OLLAMA_URL   dove risponde Ollama (default: quello di cerca.py;
#                         solo loopback)
#         le variabili di tools/lib_handson.sh (HANDSON_NO_PAUSE, …)
# Uscita: 0 = cerca.py è finito e verifica.sh passa · 1 = verifica.sh non
#         passa · 2 = precondizione (spazio di lavoro assente, python3 o
#         Ollama che mancano o non rispondono)
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
# lo script sta in <radice>/m7_…/s6_…/m7_6_…/M7-D05_…/_docente/
readonly RADICE="${SELF%/*/*/*/*/*/*}"
readonly ELEMENTO="${SELF%/_docente/*}"
# shellcheck source=../../../../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"

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
  handson::need_tools python3
  [[ -x "${ELEMENTO}/verifica.sh" && -f "${ws}/cerca.py" ]] \
    || handson::die "verifica.sh dell'elemento o cerca.py dello spazio di" \
      "lavoro mancano"
  handson::banner M7-D05 "Cercare per significato" \
    "la prova del docente: le due ricerche, sul suo computer"
  handson::pause "cercare"
  (
    cd -- "${ws}" || exit 2
    handson::run python3 -B -I cerca.py
  ) < /dev/null || rc=$?
  handson::verdict_rc "${rc}" "cerca.py, le due ricerche"
  if (( rc == 0 )); then
    handson::check "verifica.sh dell'elemento" \
      env PN_HANDSON_ROOT="${RADICE}" "${ELEMENTO}/verifica.sh" "${ws}"
  fi
  handson::finish
}

main "$@"
