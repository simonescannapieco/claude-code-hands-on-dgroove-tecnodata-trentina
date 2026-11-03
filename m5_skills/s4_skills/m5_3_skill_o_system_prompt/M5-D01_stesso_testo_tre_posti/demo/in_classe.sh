#!/bin/bash
#
# in_classe.sh -- M5-D01 dal vivo. Costruisce i quattro bracci in bracci/ dello
# spazio di lavoro (prepara_bracci.sh), poi, per ogni esecuzione: la stessa
# domanda (domanda.txt) in niente, skill, claude_md e append, ognuna in una
# sessione nuova che non resta salvata; nel braccio della skill
# domanda_invocata.txt, /procedure-assistenza con una domanda, e con --resume
# domanda_dopo.txt, nella stessa sessione, che resta salvata per questo. Sonnet,
# effort low, nessuno strumento consentito, nessun server MCP, stream-json. Ogni
# comando si vede prima di girare (handson::claude_p).
# Gli stream restano fuori dallo spazio di lavoro finché le chiamate non sono
# finite, così nessuna sessione trova quello di un'altra; poi una copia va in
# risposte/, e controlla_costo.py stampa la tabella e i verdetti. Se una
# chiamata fallisce, ciò che c'è va in risposte/ e la prova si ferma.
#
# Uso:    <cartella dell'elemento>/demo/in_classe.sh <spazio di lavoro>
#           dal repository, sullo spazio di lavoro appena preparato (git status
#           pulito); dalla copia nello spazio di lavoro serve PN_HANDSON_ROOT
# Env:    PN_ESECUZIONI    quante esecuzioni, da 1 a 9 (default 1)
#         PN_LIVE_JSON     dove restano gli stream, fuori dallo spazio di lavoro
#                          (default accanto, <spazio>.prova_dal_vivo); non deve
#                          avere già degli stream
#         PN_HANDSON_ROOT  il repository (default: dal percorso di questo file)
#         le variabili di tools/lib_handson.sh (HANDSON_NO_PAUSE, …)
# Uscita: 0 = gli stream si leggono e il controllo non ha segnalazioni · 1 = una
#         chiamata fallita, o una segnalazione · 2 = precondizione, anche del
#         controllo
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
# lo script sta in <radice>/m5_…/s4_…/m5_3_…/M5-D01_…/demo/
readonly RADICE="${PN_HANDSON_ROOT:-${SELF%/*/*/*/*/*/*}}"
if [[ ! -f "${RADICE}/tools/lib_handson.sh" ]]; then
  echo "in_classe.sh: non trovo tools/lib_handson.sh in ${RADICE}: lanciatelo" \
    "dal repository, o date PN_HANDSON_ROOT" >&2
  exit 2
fi
# shellcheck source=../../../../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"

readonly MODELLO=sonnet
readonly CARTELLA=bracci
readonly NECESSARI=(testo.md domanda.txt domanda_invocata.txt domanda_dopo.txt
  prepara_bracci.sh controlla_costo.py)
# shellcheck disable=SC2034  # la legge handson::claude_p
HANDSON_OUTPUT_FORMAT='stream-json'
JSON=''

# Gli stream, copiati in risposte/ dello spazio di lavoro (la cartella
# corrente). Globals: JSON (letta).
consegna() {
  mkdir -p risposte || handson::die "non riesco a creare risposte/"
  handson::run cp -R -- "${JSON}/." risposte/ < /dev/null \
    || handson::die "non riesco a copiare gli stream in risposte/"
}

# Una chiamata fallita: gli stream che ci sono in risposte/, il verdetto KO e
# la fine con uscita 1. Arguments: il testo del verdetto.
fallita() {
  consegna
  handson::verdict ko "$*"
  handson::finish
}

# Una chiamata dalla cartella di un braccio, con lo stream in un file; se
# fallisce, la prova si ferma. Globals: JSON (letta). Arguments: $1 il braccio,
# $2 il nome dello stream, $3 il file del testo, poi le opzioni in più.
chiedi() {
  local braccio="$1" nome="$2" testo
  testo="$(< "$3")"
  shift 3
  handson::step "${nome}"
  ( cd -- "${CARTELLA}/${braccio}" \
    && handson::claude_p "${MODELLO}" "" "${testo}" --effort low \
      --strict-mcp-config "$@" ) < /dev/null > "${JSON}/${nome}.jsonl" \
    || fallita "${nome}: claude -p è fallito"
}

# L'ID di sessione del risultato, l'ultima riga di uno stream.
# Arguments: $1 lo stream. Outputs: l'ID su STDOUT. Returns: 0; 1 se non c'è.
id_sessione() {
  python3 -B -I -c 'import json, sys
evento = json.loads(open(sys.argv[1], encoding="utf-8").readlines()[-1])
if evento.get("type") != "result":
    sys.exit(1)
print(evento["session_id"])' "$1" 2> /dev/null
}

# Un'esecuzione: i quattro bracci, poi la skill invocata e il turno dopo.
# Arguments: $1 il numero.
una_esecuzione() {
  local n="$1" b id
  for b in niente skill claude_md; do
    chiedi "${b}" "${b}-${n}" domanda.txt --no-session-persistence
  done
  chiedi append "append-${n}" domanda.txt --no-session-persistence \
    --append-system-prompt-file testo.md
  chiedi skill "skill_invocata-${n}" domanda_invocata.txt
  id="$(id_sessione "${JSON}/skill_invocata-${n}.jsonl")" \
    || fallita "skill_invocata-${n}: nessun ID di sessione nello stream"
  chiedi skill "skill_dopo-${n}" domanda_dopo.txt --resume "${id}"
}

# La cartella degli stream, fuori dallo spazio di lavoro e senza stream di
# prima, che si mescolerebbero a questi. Va chiamata nello spazio di lavoro.
# Globals: JSON (assegnata).
cartella_json() {
  local ws f
  ws="$(pwd -P)"
  JSON="${PN_LIVE_JSON:-${ws}.prova_dal_vivo}"
  mkdir -p -- "${JSON}" || handson::die "non riesco a creare ${JSON}"
  JSON="$(cd "${JSON}" && pwd -P)" \
    || handson::die "non riesco a leggere ${JSON}"
  if [[ "${JSON}/" == "${ws}/"* ]]; then
    handson::die "gli stream non stanno nello spazio di lavoro: ${JSON}"
  fi
  for f in "${JSON}"/*.jsonl; do
    [[ ! -e "${f}" ]] \
      || handson::die "c'è già una prova in ${JSON}: spostatela o" \
        "cancellatela, e ripartite da tools/reset_esercizio.sh M5-D01"
  done
  handson::note "gli stream in ${JSON}"
}

# Le precondizioni, prima di ogni chiamata. Va chiamata nello spazio di lavoro.
precondizioni() {
  local f radice stato testo
  [[ "${HANDSON_ENV}" == claude-code-pro ]] \
    || handson::die "M5-D01 è un elemento claude-code-pro: HANDSON_ENV" \
      "«${HANDSON_ENV}» non vale qui"
  handson::need_tools python3 git
  for f in "${NECESSARI[@]}"; do
    handson::need_file "${f}"
  done
  radice="$(git rev-parse --show-toplevel 2> /dev/null)" || radice=''
  [[ "${radice}" == "$(pwd -P)" ]] \
    || handson::die "$(pwd -P) non è un repository git: preparatelo con" \
      "tools/prepara_esercizio.sh M5-D01"
  stato="$(git status --porcelain)" || handson::die "git status non riesce"
  [[ -z "${stato}" ]] \
    || handson::die "lo spazio di lavoro non è al punto di partenza (git" \
      "status non è vuoto): tools/reset_esercizio.sh M5-D01"
  [[ "${PN_ESECUZIONI:-1}" =~ ^[1-9]$ ]] \
    || handson::die "PN_ESECUZIONI vuole un numero da 1 a 9, non" \
      "«${PN_ESECUZIONI}»"
  for f in domanda.txt domanda_invocata.txt domanda_dopo.txt; do
    testo="$(< "${f}")"
    handson::_claude_p_checks "${MODELLO}" "${testo}"
    handson::_claude_key_ok "${testo}"
  done
  handson::need_claude
}

main() {
  local ws="${1:-}" n rc=0
  [[ -n "${ws}" && -d "${ws}" ]] \
    || handson::die "spazio di lavoro assente: ${ws}"
  cd -- "${ws}" || handson::die "lo spazio di lavoro ${ws} non si apre"
  precondizioni
  cartella_json
  handson::banner M5-D01 "Lo stesso testo in tre posti" \
    "Modulo 5, «Quando una skill batte un system prompt lungo»"
  handson::pause "costruire i bracci e fare le chiamate"
  handson::run bash prepara_bracci.sh "${CARTELLA}" < /dev/null \
    || handson::die "prepara_bracci.sh non riesce"
  for (( n = 1; n <= ${PN_ESECUZIONI:-1}; n++ )); do
    una_esecuzione "${n}"
  done
  handson::step "Gli stream nello spazio di lavoro, a sessioni finite"
  consegna
  handson::step "La tabella e i verdetti"
  handson::run python3 -B -I controlla_costo.py risposte || rc=$?
  handson::verdict_rc "${rc}" "il controllo, sugli stream di risposte/"
  handson::finish
}

main "$@"
