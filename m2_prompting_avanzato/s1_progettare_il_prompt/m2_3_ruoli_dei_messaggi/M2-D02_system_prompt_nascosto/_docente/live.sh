#!/bin/bash
#
# live.sh di M2-D02 -- la demo del docente: il system prompt che non vedete.
# Tre chiamate a Haiku con claude -p, senza strumenti né server MCP, con la
# stessa domanda di una riga («Rispondi solo: ok»):
#   predefinito  con il system prompt di Claude Code;
#   aggiunto     con una riga in coda (--append-system-prompt);
#   sostituito   con una riga al suo posto (--system-prompt).
# I token in entrata e le risposte in sistema.tsv, nello stesso formato dei
# passi del README; i controlli dell'esito sono quelli di verifica.sh.
#
# Uso:    _docente/live.sh <spazio di lavoro>
# Env:    PN_MODELLO  il modello (default haiku; ammessi haiku, sonnet, opus)
#         e le variabili di tools/lib_handson.sh (HANDSON_NO_PAUSE, …)
# Uscita: 0 = esito come registrato · 1 = una chiamata fallita o un esito
#         diverso · 2 = precondizione
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
# lo script sta in <radice>/m2_…/s1_…/m2_3_…/M2-D02_…/_docente/
readonly RADICE="${SELF%/*/*/*/*/*/*}"
readonly CONTROLLO="${SELF%/_docente/*}/verifica.sh"
# shellcheck source=../../../../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"

readonly MODELLO="${PN_MODELLO:-haiku}"

# Una chiamata: il JSON di claude nel file $1, con le opzioni seguenti.
chiama() {
  local json="$1"
  shift
  handson::claude_p "${MODELLO}" "" "$(cat domanda.txt)" --tools "" \
    --effort low --strict-mcp-config --no-session-persistence "$@" \
    < /dev/null > "${json}"
}

# La riga di una variante in sistema.tsv e a schermo.
# Arguments: $1 la variante, $2 il file del suo JSON.
riga() {
  local r
  r="$(jq -er --arg v "$1" 'select(.is_error == false)
    | [$v, ((.usage.input_tokens // 0) + (.usage.cache_creation_input_tokens
      // 0) + (.usage.cache_read_input_tokens // 0)),
      (.result | gsub("\\s+"; " ") | gsub("^ | $"; ""))] | @tsv' \
    "$2")" || return 1
  printf '%s\n' "${r}" >> sistema.tsv
  printf '  %-12s %s token in entrata\n' "$1" "$(cut -f2 <<< "${r}")"
}

fallita() {
  handson::verdict ko "$*"
  handson::finish
}

# Il controllo dell'esito con verifica.sh, e il suo verdetto; su un KO
# stampa anche il messaggio di verifica.sh, che dice che cosa non torna.
# Arguments: $1 la descrizione, $2 lo spazio di lavoro.
esito() {
  local out rc=0
  out="$("${CONTROLLO}" "$2" 2>&1)" || rc=$?
  if (( rc == 0 )); then
    handson::verdict ok "$1"
    return 0
  fi
  printf '%s\n' "${out}"
  handson::verdict ko "$1 (uscita ${rc})"
}

main() {
  local ws="${1:-}" json_p json_a json_s riga_istr
  [[ -n "${ws}" && -d "${ws}" ]] \
    || handson::die "spazio di lavoro assente: ${ws}"
  case "${MODELLO}" in
    haiku|sonnet|opus) ;;
    *) handson::die "modello non ammesso in PN_MODELLO: «${MODELLO}»" ;;
  esac
  cd "${ws}"
  handson::need_tools jq cut
  handson::need_file domanda.txt
  handson::need_file istruzione.txt
  handson::need_claude
  riga_istr="$(cat istruzione.txt)"
  handson::tmpfile json_p
  handson::tmpfile json_a
  handson::tmpfile json_s
  handson::banner M2-D02 "Il system prompt che non vedete" \
    "Modulo 2, «System, user, developer»: tre chiamate a ${MODELLO}"
  printf 'variante\ttoken_entrata\trisposta\n' > sistema.tsv
  handson::step "Con il system prompt di Claude Code"
  { chiama "${json_p}" && riga predefinito "${json_p}"; } \
    || fallita "la chiamata predefinito non ha dato una risposta"
  handson::step "Con una riga in coda"
  { chiama "${json_a}" --append-system-prompt "${riga_istr}" \
      && riga aggiunto "${json_a}"; } \
    || fallita "la chiamata aggiunto non ha dato una risposta"
  handson::step "Con una riga al suo posto"
  { chiama "${json_s}" --system-prompt "${riga_istr}" \
      && riga sostituito "${json_s}"; } \
    || fallita "la chiamata sostituito non ha dato una risposta"
  handson::step "Il controllo dell'esito"
  esito "il system prompt sostituito pesa meno della metà" "${ws}"
  handson::finish
}

main "$@"
