#!/bin/bash
#
# live.sh di M2-D05 -- la demo del docente: ragionare, sui modelli di oggi.
# Con claude -p, senza strumenti né server MCP, effort low, a haiku,
# sonnet e opus:
#   sportelli  il problema degli sportelli, di getto («Rispondi solo con
#              l'orario») e passo passo («Ragiona passo passo»);
#   squadre    un problema più lungo, di getto.
# Orario finale, token in uscita e token di ragionamento in
# ragionamento.tsv, nello stesso formato dei passi del README; i controlli
# dell'esito sono quelli di verifica.sh.
#
# Uso:    _docente/live.sh <spazio di lavoro>
# Env:    le variabili di tools/lib_handson.sh (HANDSON_NO_PAUSE, …)
# Uscita: 0 = esito come registrato · 1 = una chiamata fallita o un esito
#         diverso · 2 = precondizione
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
# lo script sta in <radice>/m2_…/s1_…/m2_6_…/M2-D05_…/_docente/
readonly RADICE="${SELF%/*/*/*/*/*/*}"
readonly CONTROLLO="${SELF%/_docente/*}/verifica.sh"
# shellcheck source=../../../../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"

readonly MODELLI=(haiku sonnet opus)

# Una chiamata: il JSON di claude nel file $4. Nella shell dello script,
# non dentro $(…): una precondizione di handson::claude_p esce davvero 2.
# Arguments: $1 il problema (sportelli, squadre), $2 il modello, $3 la
# variante (di-getto, passo-passo), $4 il file temporaneo del JSON.
# Returns: 1 se claude fallisce o risponde con un errore.
chiama() {
  handson::claude_p "$2" "" "$(cat "$1.md")"$'\n'"$(cat "$3.txt")" \
    --tools "" --system-prompt "$(cat istruzione.txt)" --effort low \
    --strict-mcp-config --no-session-persistence < /dev/null > "$4" \
    && jq -e '.is_error != true' "$4" > /dev/null
}

# La riga di una risposta in ragionamento.tsv. L'orario della risposta
# lo legge demo/orario.py, lo stesso dei passi del README: la riga della
# «risposta finale», poi l'orario in grassetto, poi l'ultimo, sempre
# diverso da quello di partenza del problema.
# Arguments: come chiama. Returns: 1 se la risposta non ha un orario.
riga() {
  local r o inizio=9:00
  [[ "$1" != squadre ]] || inizio=8:00
  o="$(python3 -B orario.py "${inizio}" < "$4")" || return 1
  r="$(jq -er --arg p "$1" --arg m "$2" --arg v "$3" --arg o "${o}" \
    'select(.is_error == false)
    | [$p, $m, $v, $o, (.usage.output_tokens // 0),
       (.usage.output_tokens_details.thinking_tokens // 0)] | @tsv' \
    "$4")" || return 1
  printf '%s\n' "${r}" >> ragionamento.tsv
  printf '  %-9s %-7s %-12s %s\n' "$1" "$2" "$3" "$(cut -f4- <<< "${r}")"
}

# Una chiamata fallita: il verdetto KO e la fine con uscita 1, senza fare
# le chiamate che restano.
fallita() {
  handson::verdict ko "$*"
  handson::finish
}

# Una prova: la chiamata, poi la sua riga. Una chiamata fallita chiude la
# demo; una risposta senza orario è un KO, e la demo continua.
# Arguments: come chiama.
prova() {
  chiama "$@" || fallita "$1, $2, $3: claude -p è fallito"
  riga "$@" || handson::verdict ko "$1, $2, $3: nessun orario nella risposta"
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
  local ws="${1:-}" m v json
  [[ -n "${ws}" && -d "${ws}" ]] \
    || handson::die "spazio di lavoro assente: ${ws}"
  cd "${ws}"
  handson::need_tools jq cut python3
  for v in sportelli.md squadre.md di-getto.txt passo-passo.txt \
      istruzione.txt orario.py; do
    handson::need_file "${v}"
  done
  handson::need_claude
  handson::tmpfile json
  handson::banner M2-D05 "Ragionare, oggi" \
    "Modulo 2, «Ragionare»: due problemi, tre modelli"
  printf 'problema\tmodello\tvariante\torario\ttoken_uscita\ttoken_thinking\n' \
    > ragionamento.tsv
  for m in "${MODELLI[@]}"; do
    for v in di-getto passo-passo; do
      handson::step "sportelli, ${m}, ${v}"
      prova sportelli "${m}" "${v}" "${json}"
    done
  done
  for m in "${MODELLI[@]}"; do
    handson::step "squadre, ${m}, di getto"
    prova squadre "${m}" di-getto "${json}"
  done
  handson::step "Il controllo dell'esito"
  esito "tutte le risposte giuste: 9:36 e 15:30" "${ws}"
  handson::finish
}

main "$@"
