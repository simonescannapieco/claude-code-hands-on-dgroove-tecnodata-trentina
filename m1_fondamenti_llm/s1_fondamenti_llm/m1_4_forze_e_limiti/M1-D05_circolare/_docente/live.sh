#!/bin/bash
#
# live.sh di M1-D05 -- la parte del docente in Claude Code: a ciascun
# modello (haiku, sonnet, opus) la richiesta di riassumere una circolare
# che non esiste (richiesta.txt), in una sessione nuova, poi, nella stessa
# sessione ripresa con --resume, l'insistenza con mittente, data e fretta
# (insisto.txt); con claude -p, senza strumenti né server MCP. Le risposte
# a schermo e in risposte.tsv, nello stesso formato dei passi del README;
# a capo e tabulazioni diventano spazi. Rifiuto o invenzione si giudicano
# leggendo: lo script controlla solo che ogni risposta ci sia.
#
# Uso:    _docente/live.sh <spazio di lavoro>
# Env:    le variabili di tools/lib_handson.sh (HANDSON_NO_PAUSE, …)
# Uscita: 0 = sei risposte · 1 = una chiamata fallita o vuota
#         2 = precondizione
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
# lo script sta in <radice>/m1_…/s1_…/m1_4_…/M1-D05_…/_docente/
readonly RADICE="${SELF%/*/*/*/*/*/*}"
# shellcheck source=../../../../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"

readonly MODELLI=(haiku sonnet opus)

# Una chiamata: il JSON di claude nel file $3. Va chiamata nella shell
# dello script, non dentro $(…): così una precondizione di
# handson::claude_p (modalità di permesso, ambiente, prompt vuoto) esce
# davvero con 2, invece di diventare una chiamata fallita.
# Arguments: $1 il modello, $2 il file del prompt, $3 il file del JSON,
#   poi le opzioni in più. Returns: l'uscita di claude.
chiama() {
  local modello="$1" prompt="$2" json="$3"
  shift 3
  handson::claude_p "${modello}" "" "$(cat "${prompt}")" --tools "" \
    --system-prompt "$(cat istruzione.txt)" --effort low \
    --strict-mcp-config "$@" > "${json}"
}

# La riga di una risposta in risposte.tsv e a schermo.
# Arguments: $1 il modello, $2 il turno, $3 il file del JSON.
# Returns: 1 se la risposta non c'è.
riga() {
  local r
  r="$(jq -r --arg m "$1" --arg t "$2" 'select(.is_error == false)
    | [$m, $t, (.result | gsub("\\s+"; " ") | gsub("^ | $"; ""))]
    | @tsv' "$3")" || return 1
  [[ -n "${r##*$'\t'}" ]] || return 1
  printf '%s\n' "${r}" >> risposte.tsv
  printf '  %-7s %-9s %s\n' "$1" "$2" "${r##*$'\t'}"
}

main() {
  local ws="${1:-}" m json sessione
  [[ -n "${ws}" && -d "${ws}" ]] \
    || handson::die "spazio di lavoro assente: ${ws}"
  cd "${ws}"
  handson::need_tools jq
  handson::need_file richiesta.txt
  handson::need_file insisto.txt
  handson::need_file istruzione.txt
  handson::need_claude
  handson::tmpfile json
  handson::banner M1-D05 "La circolare che non esiste" \
    "Modulo 1, «Punti di forza, limiti, allucinazioni»"
  printf 'modello\tturno\trisposta\n' > risposte.tsv
  for m in "${MODELLI[@]}"; do
    handson::step "${m}"
    if ! chiama "${m}" richiesta.txt "${json}" \
        || ! riga "${m}" richiesta "${json}"; then
      handson::verdict ko "${m}, richiesta: nessuna risposta"
      continue
    fi
    if ! sessione="$(jq -er '.session_id' "${json}")"; then
      handson::verdict ko "${m}: nessun ID di sessione da riprendere"
      continue
    fi
    if ! chiama "${m}" insisto.txt "${json}" --resume "${sessione}" \
        || ! riga "${m}" insisto "${json}"; then
      handson::verdict ko "${m}, insistenza: nessuna risposta"
    fi
  done
  handson::finish
}

main "$@"
