#!/bin/bash
#
# live.sh di M1-D02 -- la demo del docente: quanti token pesa per Claude
# la stessa frase in italiano e in inglese. Per ogni modello quattro
# chiamate con claude -p, senza strumenti né server MCP: la frase
# italiana, la stessa ripetuta due volte, poi l'inglese, singola e doppia.
# I token in entrata (input_tokens + cache_creation_input_tokens +
# cache_read_input_tokens dell'usage del JSON) vanno in conteggi.tsv, nello
# stesso formato dei passi del README. Alla fine verifica.sh dell'elemento
# ne stampa i pesi (la crescita dal testo singolo al doppio), i verdetti e
# il confronto con la registrazione, e ne decide l'esito: i conteggi
# completi e i pesi positivi, mai il verso della differenza.
#
# Uso:    _docente/live.sh <spazio di lavoro>
# Env:    PN_MODELLI  i modelli, separati da spazi (default «haiku»;
#                     ammessi haiku, sonnet, opus)
#         e le variabili di tools/lib_handson.sh (HANDSON_NO_PAUSE, …)
# Uscita: 0 = verifica.sh esce 0 (conteggi completi, pesi positivi) · 1 =
#         una chiamata fallita, o verifica.sh esce 1 · 2 = precondizione
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
# lo script sta in <radice>/m1_…/s1_…/m1_3_…/M1-D02_…/_docente/
readonly RADICE="${SELF%/*/*/*/*/*/*}"
readonly CONTROLLO="${SELF%/_docente/*}/verifica.sh"
# shellcheck source=../../../../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"

readonly TESTI=(it it-doppia en en-doppia)

# Una chiamata: il JSON di claude nel file $3. Va chiamata nella shell
# dello script, non dentro $(…): così una precondizione di
# handson::claude_p (modalità di permesso, ambiente, testo vuoto) esce
# davvero con 2, invece di diventare una chiamata fallita.
# Arguments: $1 il modello, $2 il testo, $3 il file.
# Returns: l'uscita di claude.
chiama() {
  handson::claude_p "$1" "" "$2" --tools "" \
    --system-prompt "$(cat istruzione.txt)" --effort low \
    --strict-mcp-config --no-session-persistence > "$3"
}

# I token in entrata di una risposta, su STDOUT.
# Arguments: $1 il file del JSON. Returns: 1 se il JSON non li ha.
token_entrata() {
  jq -er 'select(.is_error == false) | .usage
    | (.input_tokens // 0) + (.cache_creation_input_tokens // 0)
      + (.cache_read_input_tokens // 0)' "$1"
}

# verifica.sh sullo spazio di lavoro, con la sua uscita sul descrittore 3,
# lo STDOUT di live.sh: handson::check la esegue dentro $(…) e su un OK
# resta muta, ma in aula i pesi e gli esiti si leggono sempre.
# Arguments: $1 lo spazio di lavoro. Returns: l'uscita di verifica.sh.
# shellcheck disable=SC2317  # la chiama handson::check, indirettamente
verifica_a_schermo() {
  "${CONTROLLO}" "$1" >&3 2>&1
}

main() {
  local ws="${1:-}" m t testo n json
  local -a modelli=()
  [[ -n "${ws}" && -d "${ws}" ]] \
    || handson::die "spazio di lavoro assente: ${ws}"
  read -r -a modelli <<< "${PN_MODELLI:-haiku}"
  (( ${#modelli[@]} > 0 )) || handson::die "PN_MODELLI è vuota"
  for m in "${modelli[@]}"; do
    case "${m}" in
      haiku|sonnet|opus) ;;
      *) handson::die "modello non ammesso in PN_MODELLI: «${m}»" ;;
    esac
  done
  cd "${ws}"
  handson::need_tools jq
  handson::need_file frase_it.txt
  handson::need_file frase_en.txt
  handson::need_file istruzione.txt
  handson::need_claude
  handson::tmpfile json
  local frase_it frase_en
  frase_it="$(cat frase_it.txt)"
  frase_en="$(cat frase_en.txt)"
  handson::banner M1-D02 "Stessa frase, due lingue" \
    "Modulo 1, «Token e finestra di contesto»: i token secondo Claude"
  printf 'modello\ttesto\ttoken_entrata\n' > conteggi.tsv
  for m in "${modelli[@]}"; do
    handson::step "${m}"
    for t in "${TESTI[@]}"; do
      case "${t}" in
        it) testo="${frase_it}" ;;
        it-doppia) testo="${frase_it} ${frase_it}" ;;
        en) testo="${frase_en}" ;;
        en-doppia) testo="${frase_en} ${frase_en}" ;;
      esac
      if chiama "${m}" "${testo}" "${json}" \
          && n="$(token_entrata "${json}")"; then
        printf '%s\t%s\t%s\n' "${m}" "${t}" "${n}" >> conteggi.tsv
        printf '  %-7s %-10s %6s token in entrata\n' "${m}" "${t}" "${n}"
      else
        handson::verdict ko "${m}, testo «${t}»: nessun conteggio"
      fi
      HANDSON_SHOW_CMD=0
    done
    HANDSON_SHOW_CMD=1
  done
  handson::step "I pesi e le due affermazioni"
  exec 3>&1
  handson::check "le due affermazioni (verifica.sh)" verifica_a_schermo \
    "${ws}"
  handson::finish
}

main "$@"
