#!/bin/bash
#
# live.sh di M1-D03 -- la parte del docente in Claude Code: a ciascun
# modello (haiku, sonnet, opus) la domanda di conta.txt, N volte, poi
# quella di compitata.txt (scrivere la parola una lettera per riga, poi
# contare), con claude -p, senza strumenti né server MCP. Le risposte a
# schermo e in risposte.tsv, nello stesso formato dei passi del README;
# a capo e tabulazioni delle risposte diventano spazi.
#
# Uso:    _docente/live.sh <spazio di lavoro>
# Env:    PN_RIPETIZIONI  le domande «conta» per modello, da 1 a 10
#                         (default 1); e le variabili di
#                         tools/lib_handson.sh (HANDSON_NO_PAUSE, …)
# Uscita: 0 = ogni chiamata ha dato una risposta · 1 = una chiamata è
#         fallita o ha dato una risposta vuota · 2 = precondizione
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
# lo script sta in <radice>/m1_…/s1_…/m1_3_…/M1-D03_…/_docente/
readonly RADICE="${SELF%/*/*/*/*/*/*}"
# shellcheck source=../../../../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"

readonly MODELLI=(haiku sonnet opus)
readonly RIPETIZIONI="${PN_RIPETIZIONI:-1}"

# Una chiamata: il JSON di claude nel file $3. Va chiamata nella shell
# dello script, non dentro $(…): così una precondizione di
# handson::claude_p (modalità di permesso, ambiente, prompt vuoto) esce
# davvero con 2, invece di diventare una chiamata fallita.
# Arguments: $1 il modello, $2 la domanda (conta o compitata), $3 il file.
# Returns: l'uscita di claude.
chiama() {
  handson::claude_p "$1" "" "$(cat "$2.txt")" --tools "" \
    --system-prompt "$(cat istruzione.txt)" --effort low \
    --strict-mcp-config --no-session-persistence > "$3"
}

# La riga «modello<TAB>domanda<TAB>risposta» di una risposta, su STDOUT.
# Arguments: $1 il modello, $2 la domanda, $3 il file del JSON.
# Returns: 1 se la risposta non c'è.
risposta() {
  local riga
  riga="$(jq -r --arg m "$1" --arg d "$2" 'select(.is_error == false)
    | [$m, $d, (.result | gsub("\\s+"; " ") | gsub("^ | $"; ""))]
    | @tsv' "$3")" || return 1
  [[ -n "${riga##*$'\t'}" ]] || return 1
  printf '%s\n' "${riga}"
}

# Una domanda a un modello, con la riga a schermo e nel file.
# Arguments: $1 il modello, $2 la domanda, $3 il file del JSON.
domanda() {
  local riga
  if chiama "$1" "$2" "$3" && riga="$(risposta "$1" "$2" "$3")"; then
    printf '%s\n' "${riga}" >> risposte.tsv
    printf '  %-7s %-10s %s\n' "$1" "$2" "${riga##*$'\t'}"
  else
    handson::verdict ko "$1, domanda «$2»: nessuna risposta"
  fi
}

main() {
  local ws="${1:-}" m i json
  [[ -n "${ws}" && -d "${ws}" ]] \
    || handson::die "spazio di lavoro assente: ${ws}"
  if [[ ! "${RIPETIZIONI}" =~ ^[1-9][0-9]?$ ]] || (( RIPETIZIONI > 10 )); then
    handson::die "PN_RIPETIZIONI va da 1 a 10, non «${RIPETIZIONI}»"
  fi
  cd "${ws}"
  handson::need_tools jq
  handson::need_file conta.txt
  handson::need_file compitata.txt
  handson::need_file istruzione.txt
  handson::need_claude
  handson::tmpfile json
  handson::banner M1-D03 "Quante n in «interconnessione»?" \
    "Modulo 1, «Token e finestra di contesto»: le n sono 4"
  printf 'modello\tdomanda\trisposta\n' > risposte.tsv
  for m in "${MODELLI[@]}"; do
    handson::step "${m}"
    for (( i = 1; i <= RIPETIZIONI; i++ )); do
      domanda "${m}" conta "${json}"
      HANDSON_SHOW_CMD=0
    done
    HANDSON_SHOW_CMD=1
    domanda "${m}" compitata "${json}"
  done
  handson::finish
}

main "$@"
