#!/bin/bash
#
# live.sh di M2-D06 -- la demo del docente: la galleria degli orrori.
# Quattro prompt sbagliati sul messaggio di un cliente, e la cura del
# divieto, con claude -p a sonnet, senza strumenti né server MCP:
#   orrore-1-vaga     «Fammi un documento carino su questo messaggio»;
#   orrore-2-divieto  «Non menzionare l'indennizzo»;
#   cura-2-divieto    che cosa scrivere sull'indennizzo, invece del divieto;
#   orrore-3-cinque   cinque richieste in una;
#   orrore-4-memoria  «Come ti ho detto ieri…», in una sessione nuova.
# Token in uscita, telefono del cliente, indennizzo nominato, importi in
# euro e risposte in orrori.tsv, nello stesso formato dei passi del README;
# i controlli dell'esito sono quelli di verifica.sh.
#
# Uso:    _docente/live.sh <spazio di lavoro>
# Env:    PN_MODELLO  il modello (default sonnet; ammessi haiku, sonnet, opus)
#         e le variabili di tools/lib_handson.sh (HANDSON_NO_PAUSE, …)
# Uscita: 0 = esito come registrato · 1 = una chiamata fallita o un esito
#         diverso · 2 = precondizione
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
# lo script sta in <radice>/m2_…/s2_…/m2_7_…/M2-D06_…/_docente/
readonly RADICE="${SELF%/*/*/*/*/*/*}"
readonly CONTROLLO="${SELF%/_docente/*}/verifica.sh"
# shellcheck source=../../../../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"

readonly MODELLO="${PN_MODELLO:-sonnet}"
readonly PROVE=(orrore-1-vaga orrore-2-divieto cura-2-divieto orrore-3-cinque
  orrore-4-memoria)

# Una prova e la sua riga in orrori.tsv.
# Arguments: $1 la prova, $2 il file temporaneo del JSON.
prova() {
  local r
  handson::claude_p "${MODELLO}" "" "$(cat "$1.md")" --tools "" \
    --system-prompt "$(cat istruzione.txt)" --effort low \
    --strict-mcp-config --no-session-persistence < /dev/null > "$2" \
    || return 1
  r="$(jq -er --arg p "$1" 'select(.is_error == false)
    | .result as $t
    | [$p, (.usage.output_tokens // 0),
       (if ($t | test("000[ .]?000[ .]?0103")) then "sì" else "no" end),
       (if ($t | test("indennizz"; "i")) then "sì" else "no" end),
       ([$t | scan("[0-9][0-9.,]*[ ]?(€|euro)|€[ ]?[0-9]")] | length),
       ($t | gsub("\\s+"; " ") | gsub("^ | $"; ""))] | @tsv' \
    "$2")" || return 1
  printf '%s\n' "${r}" >> orrori.tsv
  printf '  %-17s %s token, telefono %s, indennizzo %s, importi %s\n' \
    "$1" "$(cut -f2 <<< "${r}")" "$(cut -f3 <<< "${r}")" \
    "$(cut -f4 <<< "${r}")" "$(cut -f5 <<< "${r}")"
}

# Una prova senza risposta: il verdetto KO e la fine con uscita 1, senza
# fare le chiamate che restano.
fallita() {
  handson::verdict ko "$*"
  handson::finish
}

main() {
  local ws="${1:-}" p json
  [[ -n "${ws}" && -d "${ws}" ]] \
    || handson::die "spazio di lavoro assente: ${ws}"
  case "${MODELLO}" in
    haiku|sonnet|opus) ;;
    *) handson::die "modello non ammesso in PN_MODELLO: «${MODELLO}»" ;;
  esac
  cd "${ws}"
  handson::need_tools jq cut
  for p in "${PROVE[@]}"; do
    handson::need_file "${p}.md"
  done
  handson::need_file istruzione.txt
  handson::need_claude
  handson::tmpfile json
  handson::banner M2-D06 "La galleria degli orrori" \
    "Modulo 2, «La galleria degli orrori»: cinque prove a ${MODELLO}"
  printf 'prova\ttoken_uscita\ttelefono\tindennizzo\timporti\trisposta\n' \
    > orrori.tsv
  for p in "${PROVE[@]}"; do
    handson::step "${p}"
    prova "${p}" "${json}" || fallita "${p}: nessuna risposta"
  done
  handson::step "Il controllo dell'esito"
  handson::check "divieto rispettato, cura che risponde, memoria che chiede" \
    "${CONTROLLO}" "${ws}"
  handson::finish
}

main "$@"
