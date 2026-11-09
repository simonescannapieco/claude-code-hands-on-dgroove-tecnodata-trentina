#!/bin/bash
#
# live.sh di M7-E03 -- i passi del partecipante, per la registrazione del
# corso, in uno spazio di lavoro al punto di partenza:
#   1. il giudice sulle tre conversazioni di riferimento e sulla conversazione
#      vera del v0 (prova.py giudica, in giudizi/);
#   2. i due casi nuovi con il prompt del README, fra «<!-- prompt 1 -->» e
#      «<!-- /prompt 1 -->», in claude -p al posto della sessione interattiva:
#      Sonnet, effort low, Read, Glob, Grep e Write, lo stream in
#      sessione-casi.jsonl; poi deve esserci almeno un paio di file in
#      casi-nuovi/;
#   3. la suite: i cinque casi forniti su v0 e su v1-riferimento, i due nuovi
#      su v1-riferimento (dodici chiamate, attraverso prova.py), e la tabella
#      di regressione in regressione.txt, con confronta.py;
#   4. verifica.sh dell'elemento.
# Tutte le chiamate al modello passano da handson::claude_p e da prova.py, che
# ripulisce l'ambiente: mai ANTHROPIC_API_KEY.
#
# Uso:    _docente/live.sh <spazio di lavoro>
#           lo spazio di lavoro appena preparato (tools/prepara_esercizio.sh
#           M7-E03), con git status pulito
# Env:    le variabili di tools/lib_handson.sh
# Uscita: 0 = verifica.sh passa · 1 = una chiamata non finita, i casi nuovi
#         che mancano, o verifica.sh che esce 1 · 2 = precondizione (spazio di
#         lavoro assente o non al punto di partenza, un prompt che il README non
#         ha, uno strumento che manca), anche di verifica.sh
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
# lo script sta in <radice>/m7_…/s6_…/m7_e3_valutare/M7-E03_…/_docente/
readonly RADICE="${SELF%/*/*/*/*/*/*}"
readonly ELEMENTO="${SELF%/_docente/*}"
# shellcheck source=../../../../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"

readonly MODELLO=sonnet
readonly STRUMENTI='Read,Glob,Grep,Write'
readonly BANCO=progetti/assistenza-clienti/banco
readonly GOLDEN=progetti/assistenza-clienti/golden
readonly V0=progetti/assistenza-clienti/v0
readonly V1=v1-riferimento
readonly CONVERSAZIONI=("${GOLDEN}/gc-01-guasto-collettivo-pergine.json"
  "${GOLDEN}/gc-06-marito-chiede-dati.json"
  "${GOLDEN}/gc-10-copertura-fibra-in-arrivo.json"
  taratura/conversazione-v0-sc-20.json)
# shellcheck disable=SC2034  # la legge handson::claude_p
HANDSON_OUTPUT_FORMAT=stream-json
PROMPT_CASI=''

# Un passo che non è finito: il verdetto KO e la fine.
fallito() {
  handson::verdict ko "$1"
  handson::finish
}

# Il prompt 1 del README, fra i suoi marcatori, senza il rientro del blocco di
# codice. Globals: PROMPT_CASI (assegnata); esce 2 se non c'è.
prompt_del_readme() {
  local riga dentro=0 testo=''
  while IFS= read -r riga; do
    case "${riga}" in
      *'<!-- /prompt 1 -->'*) dentro=0; continue ;;
      *'<!-- prompt 1 -->'*) dentro=1; continue ;;
    esac
    if (( dentro == 1 )); then
      testo+="${riga#       }"$'\n'
    fi
  done < "${ELEMENTO}/README.md"
  # Le righe vuote in cima e in fondo non fanno parte del prompt.
  while [[ "${testo}" == $'\n'* ]]; do testo="${testo#$'\n'}"; done
  while [[ "${testo}" == *$'\n' ]]; do testo="${testo%$'\n'}"; done
  PROMPT_CASI="${testo}"
  [[ -n "${PROMPT_CASI}" ]] \
    || handson::die "il prompt 1 del README non c'è"
}

# Le precondizioni, prima di ogni chiamata: lo spazio di lavoro è il suo e al
# punto di partenza. Va chiamata nello spazio di lavoro.
precondizioni() {
  local radice segno stato f
  [[ "${HANDSON_ENV}" == claude-code-pro ]] \
    || handson::die "M7-E03 è un elemento claude-code-pro: HANDSON_ENV" \
      "«${HANDSON_ENV}» non vale qui"
  handson::need_tools python3 git uv
  radice="$(git rev-parse --show-toplevel 2> /dev/null)" || radice=''
  segno="$(git config --get corso.elemento 2> /dev/null)" || segno=''
  [[ "${radice}" == "$(pwd -P)" && "${segno}" == M7-E03 ]] \
    || handson::die "$(pwd -P) non è lo spazio di lavoro di M7-E03"
  stato="$(git status --porcelain)" || handson::die "git status non riesce"
  [[ -z "${stato}" && ! -e giudizi && ! -e risultati ]] \
    || handson::die "lo spazio di lavoro non è al punto di partenza"
  for f in "${CONVERSAZIONI[@]}" "${BANCO}/prova.py" "${BANCO}/confronta.py" \
      "${V1}/system-prompt.md" taratura/etichette.json; do
    handson::need_file "${f}"
  done
  handson::need_claude
}

main() {
  if (( $# != 1 )); then
    echo "uso: _docente/live.sh <spazio di lavoro>" >&2
    exit 2
  fi
  local ws="$1" c rc=0 quanti=0 f
  local -a args=()
  [[ -n "${ws}" && -d "${ws}" ]] \
    || handson::die "spazio di lavoro assente: ${ws}"
  cd -- "${ws}" || handson::die "lo spazio di lavoro ${ws} non si apre"
  ws="$(pwd -P)"
  [[ -x "${ELEMENTO}/verifica.sh" && -f "${ELEMENTO}/README.md" ]] \
    || handson::die "verifica.sh o il README dell'elemento mancano"
  precondizioni
  prompt_del_readme
  handson::banner M7-E03 "Valutare e non regredire" \
    "la prova del docente: i passi del partecipante"
  handson::step "1. Il giudice sulle conversazioni etichettate"
  for c in "${CONVERSAZIONI[@]}"; do args+=(--conversazione "${c}"); done
  handson::run python3 -B -I "${BANCO}/prova.py" giudica "${args[@]}" \
    --uscita giudizi < /dev/null \
    || fallito "il giudice non è finito"
  handson::step "2. I due casi nuovi, con il prompt del README"
  handson::claude_p "${MODELLO}" "${STRUMENTI}" "${PROMPT_CASI}" \
    --tools Read,Glob,Grep,Write --effort low --strict-mcp-config \
    --no-session-persistence < /dev/null > sessione-casi.jsonl \
    || fallito "la sessione per i casi nuovi è fallita"
  for f in casi-nuovi/*.json; do
    if [[ -f "${f}" ]]; then
      quanti=$((quanti + 1))
    fi
  done
  (( quanti >= 2 )) || fallito "mancano i due file di caso in casi-nuovi/"
  handson::step "3. La suite: i casi forniti su v0 e v1, i casi nuovi su v1"
  handson::run python3 -B -I "${BANCO}/prova.py" casi --versione "${V0}" \
    --uscita risultati/v0 < /dev/null || fallito "i casi su v0 non sono finiti"
  handson::run python3 -B -I "${BANCO}/prova.py" casi --versione "${V1}" \
    --uscita risultati/v1 < /dev/null || fallito "i casi su v1 non sono finiti"
  handson::run python3 -B -I "${BANCO}/prova.py" casi --versione "${V1}" \
    --casi casi-nuovi --uscita risultati/v1-nuovi < /dev/null \
    || fallito "i casi nuovi non sono finiti"
  handson::step "La tabella di regressione"
  handson::run python3 -B -I "${BANCO}/confronta.py" risultati/v0 risultati/v1 \
    > regressione.txt < /dev/null || fallito "confronta.py non è finito"
  cat regressione.txt
  handson::step "4. La verifica"
  env PN_HANDSON_ROOT="${RADICE}" "${ELEMENTO}/verifica.sh" "${ws}" || rc=$?
  handson::verdict_rc "${rc}" "verifica.sh dell'elemento"
  handson::finish
}

main "$@"
