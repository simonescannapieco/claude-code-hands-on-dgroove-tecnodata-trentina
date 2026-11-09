#!/bin/bash
#
# live.sh di M7-E02 -- i passi del partecipante, emulati, per la registrazione
# del corso, in uno spazio di lavoro al punto di partenza
# (tools/prepara_esercizio.sh M7-E02, senza v1/ né risultati/):
#   1. i tre prompt del README, fra «<!-- prompt N -->» e «<!-- /prompt N -->»,
#      in claude -p al posto della sessione interattiva: Sonnet, effort medium,
#      Read, Glob, Grep, Write ed Edit, nessun server MCP; il secondo e il
#      terzo con --resume della stessa sessione. Il plan mode non c'è, perché in
#      -p i suoi blocchi restano e Claude non scriverebbe;
#   2. tools/prova_assistente.sh casi su v0 e su v1 (dieci chiamate brevi, una
#      per caso e per versione, tre alla volta) e confronta;
#   3. verifica.sh dell'elemento, con l'uscita a schermo.
# I JSON dei tre prompt restano in sessione-live/ dello spazio di lavoro, con
# turni, secondi e token.
#
# Uso:    _docente/live.sh <spazio di lavoro>
# Env:    le variabili di tools/lib_handson.sh (HANDSON_ENV, se c'è, deve
#         essere claude-code-pro)
# Uscita: 0 = ogni chiamata è finita e verifica.sh passa · 1 = una chiamata
#         fallita, una prova non finita, o verifica.sh esce 1 · 2 = precondizione
#         (spazio di lavoro assente o non al punto di partenza, uno strumento o
#         un prompt che mancano), anche di verifica.sh
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
# lo script sta in <radice>/m7_…/s5_…/m7_e2_…/M7-E02_…/_docente/
readonly RADICE="${SELF%/*/*/*/*/*/*}"
readonly ELEMENTO="${SELF%/_docente/*}"
# shellcheck source=../../../../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"

readonly MODELLO=sonnet
readonly STRUMENTI='Read,Glob,Grep,Write,Edit'
readonly OPZIONI=(--effort medium --strict-mcp-config --tools "${STRUMENTI}")
readonly PROGETTO=progetti/assistenza-clienti
readonly CARTELLA_JSON=sessione-live
# shellcheck disable=SC2034  # la legge handson::claude_p
HANDSON_OUTPUT_FORMAT=json
PROMPT_1=''
PROMPT_2=''
PROMPT_3=''
SESSIONE=''

# Una chiamata fallita: il verdetto KO e la fine, senza quelle che restano.
fallita() {
  handson::verdict ko "$*"
  handson::finish
}

# Il prompt N del README, fra i suoi marcatori, senza il rientro comune.
# Arguments: $1 il numero. Outputs: il prompt su STDOUT. Returns: 2 se il
# README non lo ha.
prompt_del_readme() {
  python3 -B -I - "${ELEMENTO}/README.md" "$1" <<'PY'
import sys
import textwrap

righe = open(sys.argv[1], encoding="utf-8").read().split("\n")
n = sys.argv[2]
a = [i for i, r in enumerate(righe) if r.strip() == "<!-- prompt %s -->" % n]
b = [i for i, r in enumerate(righe) if r.strip() == "<!-- /prompt %s -->" % n]
if len(a) != 1 or len(b) != 1 or a[0] > b[0]:
    sys.exit(2)
testo = textwrap.dedent("\n".join(righe[a[0] + 1:b[0]])).strip("\n")
if not testo.strip():
    sys.exit(2)
print(testo)
PY
}

# Le precondizioni, tutte prima della prima chiamata. Va chiamata nello
# spazio di lavoro. Globals: PROMPT_1, PROMPT_2, PROMPT_3 (assegnate).
precondizioni() {
  local radice segno stato f
  [[ "${HANDSON_ENV}" == claude-code-pro ]] \
    || handson::die "M7-E02 è un elemento claude-code-pro: HANDSON_ENV" \
      "«${HANDSON_ENV}» non vale qui"
  handson::need_tools python3 uv jq git
  radice="$(git rev-parse --show-toplevel 2> /dev/null)" || radice=''
  segno="$(git config --get corso.elemento 2> /dev/null)" || segno=''
  [[ "${radice}" == "$(pwd -P)" && "${segno}" == M7-E02 ]] \
    || handson::die "$(pwd -P) non è lo spazio di lavoro di M7-E02:" \
      "preparatelo con tools/prepara_esercizio.sh M7-E02"
  stato="$(git status --porcelain)" || handson::die "git status non riesce"
  [[ -z "${stato}" && ! -e v1 && ! -e risultati ]] \
    || handson::die "lo spazio di lavoro non è al punto di partenza (c'è" \
      "v1/ o risultati/, o git status non è vuoto):" \
      "tools/reset_esercizio.sh M7-E02"
  for f in "${PROGETTO}/banco/prova.py" "${PROGETTO}/v0/system-prompt.md" \
      template-system-prompt-assistente.md; do
    handson::need_file "${f}"
  done
  [[ -x "${ELEMENTO}/verifica.sh" ]] \
    || handson::die "verifica.sh dell'elemento assente o non eseguibile"
  [[ -x "${RADICE}/tools/prova_assistente.sh" ]] \
    || handson::die "manca tools/prova_assistente.sh"
  PROMPT_1="$(prompt_del_readme 1)" \
    || handson::die "il README non ha il prompt 1 fra i suoi marcatori"
  PROMPT_2="$(prompt_del_readme 2)" \
    || handson::die "il README non ha il prompt 2 fra i suoi marcatori"
  PROMPT_3="$(prompt_del_readme 3)" \
    || handson::die "il README non ha il prompt 3 fra i suoi marcatori"
  handson::need_claude
}

# Un prompt in claude -p: il JSON in sessione-live/, il riepilogo. Va chiamata
# nella shell dello script. Globals: SESSIONE (assegnata), CARTELLA_JSON.
# Arguments: $1 il numero del passo, $2 il prompt, poi le opzioni in più.
passo() {
  local numero="$1" testo="$2" uscita riepilogo
  shift 2
  uscita="${CARTELLA_JSON}/passo-${numero}.json"
  if ! handson::claude_p "${MODELLO}" "${STRUMENTI}" "${testo}" \
      "${OPZIONI[@]}" "$@" < /dev/null > "${uscita}"; then
    fallita "passo ${numero}: claude -p è fallito"
  fi
  SESSIONE="$(handson::json_field session_id < "${uscita}")" \
    || fallita "passo ${numero}: il JSON non si legge"
  [[ -n "${SESSIONE}" ]] || fallita "passo ${numero}: nessun ID di sessione"
  riepilogo="$(jq -r '"turni \(.num_turns) · secondi \(.duration_ms / 1000)"' \
    < "${uscita}" 2> /dev/null)" || riepilogo='riepilogo non disponibile'
  handson::note "passo ${numero}: ${riepilogo}"
}

# verifica.sh con il suo STDOUT sul descrittore 3, come in M6-E01.
# shellcheck disable=SC2317  # la chiama handson::check, indirettamente
verifica_a_schermo() {
  PN_HANDSON_ROOT="${RADICE}" "${ELEMENTO}/verifica.sh" "$(pwd -P)" >&3
}

main() {
  if (( $# != 1 )); then
    echo "uso: _docente/live.sh <spazio di lavoro>" >&2
    exit 2
  fi
  local ws="$1" f
  [[ -n "${ws}" && -d "${ws}" ]] \
    || handson::die "spazio di lavoro assente: ${ws}"
  ws="$(cd -- "${ws}" && pwd -P)" \
    || handson::die "lo spazio di lavoro $1 non si apre"
  cd -- "${ws}" || handson::die "lo spazio di lavoro ${ws} non si apre"
  precondizioni
  handson::banner M7-E02 "Riprogettare un'interazione" \
    "Modulo 7, laboratorio: il partecipante, emulato in claude -p"
  mkdir -- "${CARTELLA_JSON}" \
    || handson::die "non riesco a creare ${CARTELLA_JSON}/"
  handson::step "Il primo prompt: il system prompt e le regole di passaggio"
  passo 1 "${PROMPT_1}"
  handson::step "Il secondo prompt: le definizioni degli strumenti"
  passo 2 "${PROMPT_2}" --resume "${SESSIONE}"
  handson::step "Il seguito: i tre file coerenti"
  passo 3 "${PROMPT_3}" --resume "${SESSIONE}"
  for f in v1/system-prompt.md v1/strumenti.json v1/regole-escalation.md; do
    [[ -f "${f}" ]] || fallita "la sessione non ha scritto ${f}"
  done
  handson::step "La prova del v0, cinque casi"
  handson::run "${RADICE}/tools/prova_assistente.sh" "${ws}" casi \
    --versione "${ws}/${PROGETTO}/v0" --uscita "${ws}/risultati/v0" \
    < /dev/null || fallita "la prova del v0 non è finita"
  handson::step "La prova della v1, gli stessi casi"
  handson::run "${RADICE}/tools/prova_assistente.sh" "${ws}" casi \
    --versione "${ws}/v1" --uscita "${ws}/risultati/v1" \
    < /dev/null || fallita "la prova della v1 non è finita"
  handson::step "Il confronto"
  handson::run "${RADICE}/tools/prova_assistente.sh" "${ws}" confronta \
    "${ws}/risultati/v0" "${ws}/risultati/v1" < /dev/null \
    || fallita "il confronto non si fa"
  handson::step "La verifica"
  exec 3>&1
  handson::check "le due versioni sui casi" verifica_a_schermo
  handson::finish
}

main "$@"
