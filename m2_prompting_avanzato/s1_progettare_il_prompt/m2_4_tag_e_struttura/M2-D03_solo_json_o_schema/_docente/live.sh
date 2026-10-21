#!/bin/bash
#
# live.sh di M2-D03 -- la demo del docente: solo JSON, o uno schema.
# Le chiamate dei passi del README, con gli stessi testi e le stesse
# opzioni: claude -p con la richiesta di richiesta-json.md, istruzione.txt
# come system prompt, effort low, senza strumenti né server MCP, senza
# salvare la sessione:
#   1. a haiku, sonnet e opus, a parole: risposte/solo-json-<modello>.json;
#   2. a haiku con --json-schema "$(cat schema.json)":
#      risposte/schema-haiku.json, con l'oggetto in structured_output;
#   3. a haiku con --json-schema "$(cat schema-non-valido.json)", che
#      claude deve rifiutare all'avvio: lo STDOUT in
#      risposte/schema-non-valido.json; dallo STDERR, la riga «… is not a
#      valid JSON Schema …» e ciò che la segue, poi «uscita: N» con il
#      codice d'uscita di claude, in risposte/schema-non-valido.txt.
# Poi controlla_json.py mette alla prova tre affermazioni, mostra la quarta
# (una dimostrazione, senza verdetto) e scrive esiti.tsv, e il verdetto è
# quello di verifica.sh. Una chiamata fallita
# ai passi 1 e 2 ferma la demo; al passo 3 l'uscita diversa da 0 è quella
# attesa, e un'uscita 0 la giudica il controllo.
#
# Uso:    _docente/live.sh <spazio di lavoro>
# Env:    le variabili di tools/lib_handson.sh (HANDSON_NO_PAUSE, …)
# Uscita: 0 = ogni risposta c'è e le due garanzie sono confermate · 1 = una
#         chiamata fallita, una risposta che manca o una garanzia non
#         confermata · 2 = precondizione
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
# lo script sta in <radice>/m2_…/s1_…/m2_4_…/M2-D03_…/_docente/
readonly RADICE="${SELF%/*/*/*/*/*/*}"
readonly CONTROLLO="${SELF%/_docente/*}/verifica.sh"
# shellcheck source=../../../../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"

readonly MODELLI=(haiku sonnet opus)
readonly ERRORE_ATTESO='is not a valid JSON Schema'

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

# Il passo 3: lo schema non valido. Lo STDERR della chiamata porta anche
# il comando, che handson::claude_p stampa prima di eseguirlo: si mostra
# per intero, e in risposte/schema-non-valido.txt vanno soltanto la riga
# d'errore attesa con ciò che la segue, poi «uscita: N». L'uscita di
# claude si cattura senza fermare lo script: qui un'uscita diversa da 0 è
# l'esito atteso.
schema_non_valido() {
  local err rc=0
  handson::tmpfile err
  chiama haiku risposte/schema-non-valido.json \
    --json-schema "$(cat schema-non-valido.json)" 2> "${err}" || rc=$?
  cat -- "${err}" >&2
  awk -v k="${ERRORE_ATTESO}" 'f || index($0, k) { f = 1; print }' \
    "${err}" > risposte/schema-non-valido.txt
  printf 'uscita: %s\n' "${rc}" >> risposte/schema-non-valido.txt
  handson::note "uscita di claude: ${rc} (attesa: diversa da 0, all'avvio)"
}

main() {
  local ws="${1:-}" m rc=0
  [[ -n "${ws}" && -d "${ws}" ]] \
    || handson::die "spazio di lavoro assente: ${ws}"
  cd "${ws}"
  handson::need_tools python3 awk
  handson::need_file richiesta-json.md
  handson::need_file istruzione.txt
  handson::need_file schema.json
  handson::need_file schema-non-valido.json
  handson::need_file controlla_json.py
  handson::need_claude
  handson::banner M2-D03 "Solo JSON, o uno schema" \
    "Modulo 2, «Tag e struttura»: a parole, lo schema, uno non valido"
  mkdir -p risposte
  for m in "${MODELLI[@]}"; do
    handson::step "«SOLO un JSON», a parole: ${m}"
    chiama "${m}" "risposte/solo-json-${m}.json" \
      || fallita "${m}: claude -p è fallito"
  done
  handson::step "La stessa richiesta, con --json-schema: haiku"
  chiama haiku risposte/schema-haiku.json --json-schema "$(cat schema.json)" \
    || fallita "haiku con lo schema: claude -p è fallito"
  handson::step "Lo schema non valido: haiku, claude deve fermarsi all'avvio"
  schema_non_valido
  handson::step "Le affermazioni alla prova, e la dimostrazione"
  python3 -B controlla_json.py || rc=$?
  if (( rc >= 2 )); then
    handson::die "controlla_json.py non ha potuto girare (uscita ${rc})"
  fi
  handson::step "Il controllo dell'esito"
  handson::check "ogni risposta c'è; le garanzie 2 e 3 confermate" \
    "${CONTROLLO}" "${ws}"
  handson::finish
}

main "$@"
