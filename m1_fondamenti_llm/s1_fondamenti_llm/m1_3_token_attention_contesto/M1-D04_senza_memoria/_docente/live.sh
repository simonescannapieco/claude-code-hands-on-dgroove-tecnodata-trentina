#!/bin/bash
#
# live.sh di M1-D04 -- la demo del docente: ogni chiamata riparte da zero.
# Tre chiamate a Haiku con claude -p, senza strumenti né server MCP:
#   A  in una sessione nuova (salvata): il guasto della linea LN-000204;
#   B  in un'altra sessione nuova: «Quale linea seguo, e che guasto ha?»;
#   C  la stessa domanda nella sessione di A, ripresa con --resume.
# Token in entrata e risposte in catena.tsv, nello stesso formato dei
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
# lo script sta in <radice>/m1_…/s1_…/m1_3_…/M1-D04_…/_docente/
readonly RADICE="${SELF%/*/*/*/*/*/*}"
readonly CONTROLLO="${SELF%/_docente/*}/verifica.sh"
# shellcheck source=../../../../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"

readonly MODELLO="${PN_MODELLO:-haiku}"

# Una chiamata: il JSON di claude nel file $2. Va chiamata nella shell
# dello script, non dentro $(…): così una precondizione di
# handson::claude_p (modalità di permesso, ambiente, prompt vuoto) esce
# davvero con 2, invece di diventare una chiamata fallita.
# Arguments: $1 il file del prompt, $2 il file del JSON, poi le opzioni in
#   più. Returns: l'uscita di claude.
chiama() {
  local prompt="$1" json="$2"
  shift 2
  handson::claude_p "${MODELLO}" "" "$(cat "${prompt}")" --tools "" \
    --system-prompt "$(cat istruzione.txt)" --effort low \
    --strict-mcp-config "$@" > "${json}"
}

# La riga di una chiamata in catena.tsv e a schermo.
# Arguments: $1 la chiamata (A, B, C), $2 il file del suo JSON.
# Returns: 1 se il JSON non ha una risposta.
riga() {
  local r
  r="$(jq -er --arg c "$1" 'select(.is_error == false)
    | [$c, ((.usage.input_tokens // 0) + (.usage.cache_creation_input_tokens
      // 0) + (.usage.cache_read_input_tokens // 0)),
      (.result | gsub("\\s+"; " ") | gsub("^ | $"; ""))] | @tsv' \
    "$2")" || return 1
  printf '%s\n' "${r}" >> catena.tsv
  printf '  %s  %s token in entrata\n     %s\n' "$1" \
    "$(cut -f2 <<< "${r}")" "$(cut -f3 <<< "${r}")"
}

# Una chiamata senza risposta: il verdetto KO e la fine della demo con
# uscita 1, perché il controllo dell'esito chiede tutte e tre le risposte.
# Arguments: il testo del verdetto.
fallita() {
  handson::verdict ko "$*"
  handson::finish
}

main() {
  local ws="${1:-}" json_a json_b json_c sessione
  [[ -n "${ws}" && -d "${ws}" ]] \
    || handson::die "spazio di lavoro assente: ${ws}"
  case "${MODELLO}" in
    haiku|sonnet|opus) ;;
    *) handson::die "modello non ammesso in PN_MODELLO: «${MODELLO}»" ;;
  esac
  cd "${ws}"
  handson::need_tools jq cut
  handson::need_file primo.txt
  handson::need_file domanda.txt
  handson::need_file istruzione.txt
  handson::need_claude
  handson::tmpfile json_a
  handson::tmpfile json_b
  handson::tmpfile json_c
  handson::banner M1-D04 "Ogni chiamata riparte da zero" \
    "Modulo 1, «Token, attention e contesto»: tre chiamate a ${MODELLO}"
  printf 'chiamata\ttoken_entrata\trisposta\n' > catena.tsv
  handson::step "A: una sessione nuova, salvata"
  { chiama primo.txt "${json_a}" && riga A "${json_a}"; } \
    || fallita "la chiamata A non ha dato una risposta"
  sessione="$(jq -er '.session_id' "${json_a}")" \
    || fallita "la chiamata A non ha un ID di sessione"
  handson::step "B: un'altra sessione nuova"
  { chiama domanda.txt "${json_b}" --no-session-persistence \
      && riga B "${json_b}"; } \
    || fallita "la chiamata B non ha dato una risposta"
  handson::step "C: la sessione di A, ripresa"
  { chiama domanda.txt "${json_c}" --resume "${sessione}" \
      && riga C "${json_c}"; } \
    || fallita "la chiamata C non ha dato una risposta"
  handson::step "Il controllo dell'esito"
  handson::check "B non conosce la linea, C sì; C manda più token di A" \
    "${CONTROLLO}" "${ws}"
  handson::finish
}

main "$@"
