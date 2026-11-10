#!/bin/bash
#
# live.sh di M8-E01 -- la prova del docente, per la registrazione del corso, in
# uno spazio di lavoro al punto di partenza (tools/prepara_esercizio.sh
# M8-E01, senza risposte/ né conto.py):
#   1. il passo 2 del README, come lo fa un partecipante: mkdir risposte e la
#      chiamata di claude -p con il messaggio di messaggio.txt, su Haiku con
#      effort low, le opzioni di quel comando (qui attraverso
#      handson::claude_p: stesse opzioni, in un altro ordine), il JSON in
#      risposte/prima.json;
#   2. al posto della sessione interattiva del passo 3, conto.py di soluzione/,
#      copiato nello spazio di lavoro e lanciato;
#   3. verifica.sh dell'elemento, con l'uscita a schermo.
# Il JSON e conto.py restano nello spazio di lavoro: il docente li importa come
# registrazione del corso.
#
# Uso:    _docente/live.sh <spazio di lavoro>
# Env:    le variabili di tools/lib_handson.sh (HANDSON_ENV, se c'è, deve
#         essere claude-code-pro)
# Uscita: 0 = la chiamata è finita e verifica.sh passa · 1 = la chiamata
#         fallita, o verifica.sh che esce 1 · 2 = precondizione (spazio di
#         lavoro assente o non al punto di partenza, uno strumento o un file
#         che mancano), anche di verifica.sh
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
# lo script sta in <radice>/m8_…/s6_…/m8_e1_…/M8-E01_…/_docente/
readonly RADICE="${SELF%/*/*/*/*/*/*}"
readonly ELEMENTO="${SELF%/_docente/*}"
# shellcheck source=../../../../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"

readonly ID=M8-E01
readonly MODELLO=haiku
# Le opzioni del passo 2 del README che handson::claude_p non mette da sé.
readonly OPZIONI=(--effort low --tools '' --strict-mcp-config
  --no-session-persistence)
readonly RISPOSTE=risposte
readonly SOLUZIONE="${ELEMENTO}/soluzione/conto.py"
# shellcheck disable=SC2034  # la legge handson::claude_p
HANDSON_OUTPUT_FORMAT=json
MESSAGGIO=''

# Una chiamata fallita: il verdetto KO e la fine.
fallita() {
  handson::verdict ko "$*"
  handson::finish
}

# Le precondizioni, tutte prima della chiamata. Va chiamata nello spazio di
# lavoro. Globals: MESSAGGIO (assegnata).
precondizioni() {
  local f radice segno stato
  [[ "${HANDSON_ENV}" == claude-code-pro ]] \
    || handson::die "${ID} è un elemento claude-code-pro: HANDSON_ENV" \
      "«${HANDSON_ENV}» non vale qui"
  handson::need_tools python3 git
  radice="$(git rev-parse --show-toplevel 2> /dev/null)" || radice=''
  segno="$(git config --get corso.elemento 2> /dev/null)" || segno=''
  [[ "${radice}" == "$(pwd -P)" && "${segno}" == "${ID}" ]] \
    || handson::die "$(pwd -P) non è lo spazio di lavoro di ${ID}:" \
      "preparatelo con tools/prepara_esercizio.sh ${ID}"
  for f in messaggio.txt listino.json volume.txt "${SOLUZIONE}"; do
    handson::need_file "${f}"
  done
  stato="$(git status --porcelain)" || handson::die "git status non riesce"
  [[ ! -e "${RISPOSTE}" && ! -e conto.py && -z "${stato}" ]] \
    || handson::die "lo spazio di lavoro non è al punto di partenza (c'è" \
      "${RISPOSTE}/ o conto.py, o git status non è vuoto):" \
      "tools/reset_esercizio.sh ${ID}"
  MESSAGGIO="$(< messaggio.txt)"
  handson::_claude_p_checks "${MODELLO}" "${MESSAGGIO}"
  handson::_claude_key_ok "${MESSAGGIO}"
  handson::need_claude
}

main() {
  if (( $# != 1 )); then
    echo "uso: _docente/live.sh <spazio di lavoro>" >&2
    exit 2
  fi
  local ws="$1" rc=0
  [[ -n "${ws}" && -d "${ws}" ]] \
    || handson::die "spazio di lavoro assente: ${ws}"
  ws="$(cd -- "${ws}" && pwd -P)" \
    || handson::die "lo spazio di lavoro $1 non si apre"
  cd -- "${ws}" || handson::die "lo spazio di lavoro ${ws} non si apre"
  precondizioni
  handson::banner "${ID}" "Quanto costa una risposta" \
    "la prova del docente: la chiamata del passo 2 e la soluzione"
  handson::note "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  handson::step "Passo 2 del README: la chiamata, su Haiku con effort low"
  mkdir -- "${RISPOSTE}" || handson::die "mkdir ${RISPOSTE} non riesce"
  handson::claude_p "${MODELLO}" '' "${MESSAGGIO}" "${OPZIONI[@]}" \
    < /dev/null > "${RISPOSTE}/prima.json" \
    || fallita "la chiamata di claude -p è fallita"
  handson::step "Passo 3 del README: conto.py di soluzione/, al posto della" \
    "sessione interattiva"
  handson::run cp -- "${SOLUZIONE}" conto.py || handson::die "cp non riesce"
  handson::run python3 -B -I conto.py < /dev/null \
    || fallita "conto.py di soluzione/ è fallito"
  handson::step "Passo 4 del README: la verifica"
  handson::run env PN_HANDSON_ROOT="${RADICE}" "${ELEMENTO}/verifica.sh" \
    "${ws}" < /dev/null || rc=$?
  handson::verdict_rc "${rc}" "verifica.sh dell'elemento"
  handson::finish
}

main "$@"
