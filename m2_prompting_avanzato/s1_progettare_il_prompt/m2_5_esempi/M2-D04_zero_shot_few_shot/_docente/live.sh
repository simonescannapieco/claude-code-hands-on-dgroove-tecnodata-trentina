#!/bin/bash
#
# live.sh di M2-D04 -- la demo del docente: zero-shot contro few-shot.
# La stessa segnalazione da classificare nel formato «categoria | priorità |
# team», con claude -p senza strumenti né server MCP, a haiku e a sonnet:
#   zero-shot      l'istruzione sola;
#   few-shot       l'istruzione e due esempi della settimana di ticket;
#   con-etichette  i due esempi e l'elenco delle etichette ammesse.
# Le risposte in etichette.tsv, nello stesso formato dei passi del README;
# i controlli dell'esito sono quelli di verifica.sh. In aula i partecipanti
# provano le prime due in claude.ai.
#
# Uso:    _docente/live.sh <spazio di lavoro>
# Env:    le variabili di tools/lib_handson.sh (HANDSON_NO_PAUSE, …)
# Uscita: 0 = esito come registrato · 1 = una chiamata fallita o un esito
#         diverso · 2 = precondizione
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
# lo script sta in <radice>/m2_…/s1_…/m2_5_…/M2-D04_…/_docente/
readonly RADICE="${SELF%/*/*/*/*/*/*}"
readonly CONTROLLO="${SELF%/_docente/*}/verifica.sh"
# shellcheck source=../../../../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"

readonly MODELLI=(haiku sonnet)
readonly VARIANTI=(zero-shot few-shot con-etichette)

# Una chiamata e la sua riga in etichette.tsv.
# Arguments: $1 il modello, $2 la variante, $3 il file temporaneo del JSON.
classifica() {
  local r
  handson::claude_p "$1" "" "$(cat "$2.md")" --tools "" \
    --system-prompt "$(cat istruzione.txt)" --effort low \
    --strict-mcp-config --no-session-persistence < /dev/null > "$3" \
    || return 1
  r="$(jq -er --arg m "$1" --arg v "$2" 'select(.is_error == false)
    | [$m, $v, (.result | gsub("\\s+"; " ") | gsub("^ | $"; ""))] | @tsv' \
    "$3")" || return 1
  printf '%s\n' "${r}" >> etichette.tsv
  printf '  %-7s %-14s %s\n' "$1" "$2" "$(cut -f3 <<< "${r}")"
}

# Una chiamata senza risposta: il verdetto KO e la fine con uscita 1,
# senza fare le chiamate che restano.
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
  local ws="${1:-}" m v json
  [[ -n "${ws}" && -d "${ws}" ]] \
    || handson::die "spazio di lavoro assente: ${ws}"
  cd "${ws}"
  handson::need_tools jq cut
  for v in "${VARIANTI[@]}"; do
    handson::need_file "${v}.md"
  done
  handson::need_file istruzione.txt
  handson::need_claude
  handson::tmpfile json
  handson::banner M2-D04 "Zero-shot contro few-shot" \
    "Modulo 2, «Esempi»: tre prompt, due modelli"
  printf 'modello\tvariante\trisposta\n' > etichette.tsv
  for m in "${MODELLI[@]}"; do
    for v in "${VARIANTI[@]}"; do
      handson::step "${m}: ${v}"
      classifica "${m}" "${v}" "${json}" \
        || fallita "${m}, ${v}: nessuna risposta"
    done
  done
  handson::step "Il controllo dell'esito"
  esito "con gli esempi la forma; con l'elenco le etichette" "${ws}"
  handson::finish
}

main "$@"
