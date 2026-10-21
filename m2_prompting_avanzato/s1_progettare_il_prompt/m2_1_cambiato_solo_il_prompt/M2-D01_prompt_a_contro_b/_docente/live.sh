#!/bin/bash
#
# live.sh di M2-D01 -- la demo del docente: è cambiato solo il prompt.
# Due chiamate a Sonnet con claude -p, senza strumenti né server MCP, sullo
# stesso messaggio di un cliente:
#   A  «Riassumi.» e il messaggio;
#   B  il prompt di cinque righe (ruolo, contesto, istruzione, formato,
#      vincoli) e il messaggio tra tag.
# Token e risposte in confronto.tsv, nello stesso formato dei passi del
# README; il controllo è quello di verifica.sh, che gira una volta e si
# vede per intero (i numeri e un esito per ogni affermazione) prima del
# verdetto.
#
# Uso:    _docente/live.sh <spazio di lavoro>
# Env:    PN_MODELLO  il modello (default sonnet; ammessi haiku, sonnet, opus)
#         e le variabili di tools/lib_handson.sh (HANDSON_NO_PAUSE, …)
# Uscita: 0 = le due risposte ci sono e la garanzia è confermata · 1 = una
#         chiamata fallita o la garanzia non confermata · 2 = precondizione
#         (anche verifica.sh che non può girare)
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
# lo script sta in <radice>/m2_…/s1_…/m2_1_…/M2-D01_…/_docente/
readonly RADICE="${SELF%/*/*/*/*/*/*}"
readonly CONTROLLO="${SELF%/_docente/*}/verifica.sh"
# shellcheck source=../../../../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"

readonly MODELLO="${PN_MODELLO:-sonnet}"

# Una chiamata: il JSON di claude nel file $2. Nella shell dello script,
# non dentro $(…): una precondizione di handson::claude_p esce davvero 2.
# Arguments: $1 il file del prompt, $2 il file del JSON.
chiama() {
  handson::claude_p "${MODELLO}" "" "$(cat "$1")" --tools "" \
    --system-prompt "$(cat istruzione.txt)" --effort low \
    --strict-mcp-config --no-session-persistence < /dev/null > "$2"
}

# La riga di una chiamata in confronto.tsv e a schermo.
# Arguments: $1 il prompt (A, B), $2 il file del suo JSON.
# Returns: 1 se il JSON non ha una risposta.
riga() {
  local r
  r="$(jq -er --arg p "$1" 'select(.is_error == false)
    | [$p, ((.usage.input_tokens // 0) + (.usage.cache_creation_input_tokens
      // 0) + (.usage.cache_read_input_tokens // 0)),
      (.usage.output_tokens // 0),
      (.result | gsub("\\s+"; " ") | gsub("^ | $"; ""))] | @tsv' \
    "$2")" || return 1
  printf '%s\n' "${r}" >> confronto.tsv
  printf '  %s  %s token in entrata, %s in uscita\n' "$1" \
    "$(cut -f2 <<< "${r}")" "$(cut -f3 <<< "${r}")"
}

# Una chiamata senza risposta: il verdetto KO e la fine con uscita 1.
fallita() {
  handson::verdict ko "$*"
  handson::finish
}

# verifica.sh con il suo STDOUT sul descrittore 3, che main apre sullo
# STDOUT di live.sh: handson::check mostra l'uscita di un controllo solo
# su un KO, e qui gli esiti sono la demo anche quando passa; così si
# vedono una volta sola.
# Arguments: $1 lo spazio di lavoro. Returns: l'uscita di verifica.sh.
# shellcheck disable=SC2317  # la chiama handson::check, indirettamente
verifica_a_schermo() {
  "${CONTROLLO}" "$1" >&3
}

main() {
  local ws="${1:-}" json_a json_b
  [[ -n "${ws}" && -d "${ws}" ]] \
    || handson::die "spazio di lavoro assente: ${ws}"
  case "${MODELLO}" in
    haiku|sonnet|opus) ;;
    *) handson::die "modello non ammesso in PN_MODELLO: «${MODELLO}»" ;;
  esac
  cd "${ws}"
  handson::need_tools jq cut
  handson::need_file prompt-a.md
  handson::need_file prompt-b.md
  handson::need_file istruzione.txt
  handson::need_claude
  handson::tmpfile json_a
  handson::tmpfile json_b
  handson::banner M2-D01 "Prompt A contro prompt B" \
    "Modulo 2, «È cambiato solo il prompt»: due chiamate a ${MODELLO}"
  printf 'prompt\ttoken_entrata\ttoken_uscita\trisposta\n' > confronto.tsv
  handson::step "A: «Riassumi.»"
  { chiama prompt-a.md "${json_a}" && riga A "${json_a}"; } \
    || fallita "la chiamata A non ha dato una risposta"
  handson::step "B: il prompt di cinque righe"
  { chiama prompt-b.md "${json_b}" && riga B "${json_b}"; } \
    || fallita "la chiamata B non ha dato una risposta"
  handson::step "Le affermazioni alla prova"
  exec 3>&1
  handson::check "le due risposte ci sono; B manda più token di A" \
    verifica_a_schermo "${ws}"
  handson::finish
}

main "$@"
