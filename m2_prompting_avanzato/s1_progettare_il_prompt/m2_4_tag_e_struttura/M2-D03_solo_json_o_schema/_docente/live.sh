#!/bin/bash
#
# live.sh di M2-D03 -- la demo del docente: solo JSON, o uno schema.
# La richiesta «rispondi SOLO con un JSON valido» sul messaggio di un
# cliente, con claude -p senza strumenti né server MCP:
#   1. a haiku, sonnet e opus: risposte/solo-json-<modello>.json;
#   2. a haiku con --json-schema e lo schema di schema.json:
#      risposte/schema-haiku.json, con l'oggetto in structured_output.
# Poi controlla_json.py scrive esiti.tsv (JSON valido, blocco di codice,
# telefono del cliente, schema rispettato); i controlli dell'esito sono
# quelli di verifica.sh.
#
# Uso:    _docente/live.sh <spazio di lavoro>
# Env:    le variabili di tools/lib_handson.sh (HANDSON_NO_PAUSE, …)
# Uscita: 0 = esito come registrato · 1 = una chiamata fallita o un esito
#         diverso · 2 = precondizione
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
# lo script sta in <radice>/m2_…/s1_…/m2_4_…/M2-D03_…/_docente/
readonly RADICE="${SELF%/*/*/*/*/*/*}"
readonly CONTROLLO="${SELF%/_docente/*}/verifica.sh"
# shellcheck source=../../../../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"

readonly MODELLI=(haiku sonnet opus)

# Una chiamata: $1 il modello, $2 il file del JSON, poi le opzioni in più.
chiama() {
  local modello="$1" json="$2"
  shift 2
  handson::claude_p "${modello}" "" "$(cat richiesta-json.md)" --tools "" \
    --system-prompt "$(cat istruzione.txt)" --effort low \
    --strict-mcp-config --no-session-persistence "$@" \
    < /dev/null > "${json}"
}

# Una chiamata fallita: il verdetto KO e la fine con uscita 1, senza fare
# le chiamate che restano.
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
  local ws="${1:-}" m schema
  [[ -n "${ws}" && -d "${ws}" ]] \
    || handson::die "spazio di lavoro assente: ${ws}"
  cd "${ws}"
  handson::need_tools python3
  handson::need_file richiesta-json.md
  handson::need_file schema.json
  handson::need_file istruzione.txt
  handson::need_file controlla_json.py
  handson::need_claude
  schema="$(cat schema.json)"
  handson::banner M2-D03 "Solo JSON, o uno schema" \
    "Modulo 2, «Tag e struttura»: tre modelli, poi lo schema"
  mkdir -p risposte
  for m in "${MODELLI[@]}"; do
    handson::step "«SOLO un JSON»: ${m}"
    chiama "${m}" "risposte/solo-json-${m}.json" \
      || fallita "${m}: claude -p è fallito"
  done
  handson::step "La stessa richiesta, con --json-schema: haiku"
  chiama haiku risposte/schema-haiku.json --json-schema "${schema}" \
    || fallita "haiku con lo schema: claude -p è fallito"
  handson::step "Che cosa è arrivato"
  python3 -B controlla_json.py \
    || handson::verdict ko "controlla_json.py non ha scritto esiti.tsv"
  handson::step "Il controllo dell'esito"
  esito "lo schema dà un oggetto valido; le tre risposte ci sono" "${ws}"
  handson::finish
}

main "$@"
