#!/bin/bash
#
# live.sh di M1-D01 -- la demo del docente, dal vivo: la frase di
# frase.txt, con l'istruzione di sistema di istruzione.txt, data N volte
# a ciascun modello (haiku, sonnet, opus) con claude -p, senza strumenti
# né server MCP; le parole a schermo e in risultati.tsv, nello stesso
# formato dei passi del README. Il primo comando di ogni modello si vede
# per intero prima di girare; le ripetizioni no.
#
# Uso:    _docente/live.sh <spazio di lavoro>
# Env:    PN_RIPETIZIONI  chiamate per modello, da 1 a 20 (default 3)
#         e le variabili di tools/lib_handson.sh (HANDSON_NO_PAUSE, …)
# Uscita: 0 = ogni chiamata ha dato una risposta · 1 = una chiamata è
#         fallita o ha dato una risposta vuota · 2 = precondizione
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
# lo script sta in <radice>/m1_…/s1_…/m1_2_…/M1-D01_…/_docente/
readonly RADICE="${SELF%/*/*/*/*/*/*}"
# shellcheck source=../../../../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"

readonly MODELLI=(haiku sonnet opus)
readonly RIPETIZIONI="${PN_RIPETIZIONI:-3}"
readonly PARTE="Modulo 1, «Cosa fanno, cosa leggono, come imparano»"

# Una chiamata: il JSON di claude nel file $2. Va chiamata nella shell
# dello script, non dentro $(…): così una precondizione di
# handson::claude_p (modalità di permesso, ambiente, prompt vuoto) esce
# davvero con 2, invece di diventare una chiamata fallita.
# Arguments: $1 il modello, $2 il file. Returns: l'uscita di claude.
chiama() {
  handson::claude_p "$1" "" "$(cat frase.txt)" --tools "" \
    --system-prompt "$(cat istruzione.txt)" --effort low \
    --strict-mcp-config --no-session-persistence > "$2"
}

# La riga «modello<TAB>parola» di una risposta, su STDOUT.
# Arguments: $1 il modello, $2 il file del JSON. Returns: 1 se non c'è.
parola() {
  local riga
  riga="$(jq -r --arg m "$1" 'select(.is_error == false)
    | [$m, (.result | gsub("^\\s+|\\s+$"; ""))] | @tsv' "$2")" || return 1
  [[ -n "${riga#*$'\t'}" ]] || return 1
  printf '%s\n' "${riga}"
}

main() {
  local ws="${1:-}" m i riga json
  [[ -n "${ws}" && -d "${ws}" ]] \
    || handson::die "spazio di lavoro assente: ${ws}"
  if [[ ! "${RIPETIZIONI}" =~ ^[1-9][0-9]?$ ]] || (( RIPETIZIONI > 20 )); then
    handson::die "PN_RIPETIZIONI va da 1 a 20, non «${RIPETIZIONI}»"
  fi
  cd "${ws}"
  handson::need_tools jq
  handson::need_file frase.txt
  handson::need_file istruzione.txt
  handson::need_claude
  handson::tmpfile json
  handson::banner M1-D01 "La prossima parola" \
    "${PARTE}: ${RIPETIZIONI} chiamate per modello"
  printf 'modello\tparola\n' > risultati.tsv
  for m in "${MODELLI[@]}"; do
    handson::step "${m}"
    for (( i = 1; i <= RIPETIZIONI; i++ )); do
      if chiama "${m}" "${json}" && riga="$(parola "${m}" "${json}")"; then
        printf '%s\n' "${riga}" >> risultati.tsv
        printf '  %-7s %2d  %s\n' "${m}" "${i}" "${riga#*$'\t'}"
      else
        handson::verdict ko "${m}, chiamata ${i}: nessuna risposta"
      fi
      HANDSON_SHOW_CMD=0
    done
    HANDSON_SHOW_CMD=1
  done
  handson::finish
}

main "$@"
