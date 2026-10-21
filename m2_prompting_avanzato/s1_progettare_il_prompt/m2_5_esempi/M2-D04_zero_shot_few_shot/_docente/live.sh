#!/bin/bash
#
# live.sh di M2-D04 -- la demo del docente: zero-shot contro few-shot.
# La stessa segnalazione da classificare nel formato «categoria | priorità |
# team», con claude -p senza strumenti né server MCP, a haiku e a sonnet.
# Quattro varianti, ognuna con una cosa sola cambiata rispetto alla
# precedente:
#   zero-shot      l'istruzione e la segnalazione;
#   few-shot       più due esempi fra i tag <examples> e <example>;
#   con-etichette  più l'elenco delle etichette e «Usa solo le etichette
#                  elencate.»;
#   schema         il prompt di con-etichette con --json-schema e
#                  schema.json (un enum per campo, uguale agli elenchi).
# Gli stessi testi e le stesse opzioni dei passi del README; il JSON di
# ogni chiamata in risposte/<variante>-<modello>.json. Prima di ogni
# chiamata controlla che gli enum di schema.json siano gli elenchi di
# con-etichette.md; alla fine controlla_etichette.py scrive esiti.tsv e
# verifica.sh dice, per ogni modello, se la prova conferma le tre
# affermazioni di Anthropic: i suoi verdetti si vedono anche quando
# passa. In aula i partecipanti provano zero-shot e few-shot in claude.ai.
#
# Uso:    _docente/live.sh <spazio di lavoro>
# Env:    le variabili di tools/lib_handson.sh (HANDSON_NO_PAUSE, …)
# Uscita: 0 = le otto risposte ci sono e la garanzia dello schema è
#         confermata · 1 = una chiamata fallita, una risposta che manca o
#         la garanzia non confermata · 2 = precondizione (anche gli enum di
#         schema.json diversi dagli elenchi, prima di ogni chiamata)
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

# Una chiamata, con il suo JSON in un file.
# Arguments: $1 il modello, $2 il file del prompt, $3 il file del JSON,
#   poi le opzioni in più (--json-schema per la variante schema).
chiedi() {
  local modello="$1" prompt="$2" json="$3"
  shift 3
  handson::claude_p "${modello}" "" "$(cat "${prompt}")" --tools "" \
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

# verifica.sh con il suo STDOUT sul descrittore 3, che main apre sullo
# STDOUT di live.sh: handson::check mostra l'uscita di un controllo solo
# su un KO, e qui i verdetti sono la demo anche quando passa.
# Arguments: $1 lo spazio di lavoro. Returns: l'uscita di verifica.sh.
# shellcheck disable=SC2317  # la chiama handson::check, indirettamente
verifica_a_schermo() {
  "${CONTROLLO}" "$1" >&3
}

main() {
  local ws="${1:-}" m v schema rc=0
  [[ -n "${ws}" && -d "${ws}" ]] \
    || handson::die "spazio di lavoro assente: ${ws}"
  cd "${ws}"
  handson::need_tools python3
  for v in "${VARIANTI[@]}"; do
    handson::need_file "${v}.md"
  done
  handson::need_file schema.json
  handson::need_file istruzione.txt
  handson::need_file controlla_etichette.py
  python3 -B controlla_etichette.py --solo-schema > /dev/null \
    || handson::die "schema.json e con-etichette.md non vanno d'accordo"
  handson::need_claude
  schema="$(cat schema.json)"
  handson::banner M2-D04 "Zero-shot contro few-shot" \
    "Modulo 2, «Esempi»: quattro prompt, due modelli"
  mkdir -p risposte
  for m in "${MODELLI[@]}"; do
    for v in "${VARIANTI[@]}"; do
      handson::step "${m}: ${v}"
      chiedi "${m}" "${v}.md" "risposte/${v}-${m}.json" \
        || fallita "${m}, ${v}: claude -p è fallito"
    done
    handson::step "${m}: schema (con-etichette.md con --json-schema)"
    chiedi "${m}" con-etichette.md "risposte/schema-${m}.json" \
      --json-schema "${schema}" \
      || fallita "${m}, schema: chiamata fallita (claude -p è fallito)"
  done
  # esiti.tsv, come al passo 4 del README; i dati e i verdetti li mostra
  # una volta sola il controllo qui sotto, e un'uscita 1 la dice lui.
  handson::step "esiti.tsv, come nel README"
  python3 -B controlla_etichette.py > /dev/null || rc=$?
  if (( rc >= 2 )); then
    handson::verdict_rc "${rc}" "controlla_etichette.py: le otto risposte"
  fi
  handson::step "Le affermazioni di Anthropic, messe alla prova"
  exec 3>&1
  handson::check "le tre affermazioni, su haiku e su sonnet" \
    verifica_a_schermo "${ws}"
  handson::finish
}

main "$@"
