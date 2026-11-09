#!/bin/bash
#
# live.sh di M7-E01 -- i passi del partecipante, emulati, per la registrazione
# del corso, in uno spazio di lavoro al punto di partenza
# (tools/prepara_esercizio.sh M7-E01, senza conversazione/):
#   1. la conversazione: tools/prova_assistente.sh … conversazione, sul primo
#      scenario del README (la persona simulata, fino a quattro giri,
#      l'assistente v0);
#   2. la lettura della trascrizione: il prompt 1 del README, fra
#      «<!-- prompt 1 -->» e «<!-- /prompt 1 -->», in claude -p al posto
#      della sessione interattiva: Sonnet, effort low, Read, Glob e Grep,
#      nessun server MCP, la sessione salvata per il passo dopo;
#   3. le note: il prompt 2 del README, con --resume della stessa sessione:
#      Claude scrive note.md (consentito anche Write);
#   4. verifica.sh dell'elemento, con l'uscita a schermo.
# In una sessione vera le note le decide il partecipante, che legge la
# trascrizione: qui è il prompt 2 a tenere il posto di quella scelta. I JSON
# dei passi 2 e 3 restano in sessione-live/ dello spazio di lavoro, con
# turni, secondi e token.
#
# Uso:    _docente/live.sh <spazio di lavoro>
# Env:    le variabili di tools/lib_handson.sh (HANDSON_ENV, se c'è, deve
#         essere claude-code-pro)
# Uscita: 0 = ogni chiamata è finita e verifica.sh passa · 1 = una chiamata
#         fallita, o verifica.sh esce 1 · 2 = precondizione (spazio di lavoro
#         assente o non al punto di partenza, uno strumento o un prompt che
#         mancano), anche di verifica.sh
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
# lo script sta in <radice>/m7_…/s5_…/m7_e1_…/M7-E01_…/_docente/
readonly RADICE="${SELF%/*/*/*/*/*/*}"
readonly ELEMENTO="${SELF%/_docente/*}"
# shellcheck source=../../../../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"

readonly MODELLO=sonnet
readonly SCENARIO=sc-16-rimborso-e-password.json
readonly PROGETTO=progetti/assistenza-clienti
readonly LETTURA='Read,Glob,Grep'
readonly SCRITTURA='Read,Glob,Grep,Write'
readonly OPZIONI=(--effort low --strict-mcp-config)
readonly CARTELLA_JSON=sessione-live
# shellcheck disable=SC2034  # la legge handson::claude_p
HANDSON_OUTPUT_FORMAT=json
PROMPT_1=''
PROMPT_2=''
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
# spazio di lavoro. Globals: PROMPT_1, PROMPT_2 (assegnate).
precondizioni() {
  local radice segno stato f
  [[ "${HANDSON_ENV}" == claude-code-pro ]] \
    || handson::die "M7-E01 è un elemento claude-code-pro: HANDSON_ENV" \
      "«${HANDSON_ENV}» non vale qui"
  handson::need_tools python3 uv jq git
  radice="$(git rev-parse --show-toplevel 2> /dev/null)" || radice=''
  segno="$(git config --get corso.elemento 2> /dev/null)" || segno=''
  [[ "${radice}" == "$(pwd -P)" && "${segno}" == M7-E01 ]] \
    || handson::die "$(pwd -P) non è lo spazio di lavoro di M7-E01:" \
      "preparatelo con tools/prepara_esercizio.sh M7-E01"
  stato="$(git status --porcelain)" || handson::die "git status non riesce"
  [[ -z "${stato}" ]] \
    || handson::die "lo spazio di lavoro non è al punto di partenza (git" \
      "status non è vuoto): tools/reset_esercizio.sh M7-E01"
  for f in "${PROGETTO}/banco/prova.py" "${PROGETTO}/v0/system-prompt.md" \
      "${PROGETTO}/scenari/${SCENARIO}" note.md; do
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
  handson::need_claude
}

# Un passo in claude -p: il JSON in sessione-live/, il riepilogo di turni,
# secondi e token. Va chiamata nella shell dello script, non in $(…).
# Globals: SESSIONE (assegnata), CARTELLA_JSON. Arguments: $1 il numero del
# passo, $2 gli strumenti, $3 il prompt, poi le opzioni in più.
passo() {
  local numero="$1" strumenti="$2" testo="$3" uscita riepilogo
  shift 3
  uscita="${CARTELLA_JSON}/passo-${numero}.json"
  if ! handson::claude_p "${MODELLO}" "${strumenti}" "${testo}" \
      "${OPZIONI[@]}" --tools "${strumenti}" "$@" < /dev/null > "${uscita}"
  then
    fallita "passo ${numero}: claude -p è fallito"
  fi
  SESSIONE="$(handson::json_field session_id < "${uscita}")" \
    || fallita "passo ${numero}: il JSON non si legge"
  [[ -n "${SESSIONE}" ]] || fallita "passo ${numero}: nessun ID di sessione"
  riepilogo="$(jq -r '"turni \(.num_turns) · secondi \(.duration_ms / 1000)"' \
    < "${uscita}" 2> /dev/null)" || riepilogo='riepilogo non disponibile'
  handson::note "passo ${numero}: ${riepilogo}"
}

# verifica.sh con il suo STDOUT sul descrittore 3, che main apre sullo STDOUT
# di live.sh: handson::check mostra l'uscita di un controllo solo su un KO, e
# qui i dati sono ciò che la registrazione legge.
# shellcheck disable=SC2317  # la chiama handson::check, indirettamente
verifica_a_schermo() {
  PN_HANDSON_ROOT="${RADICE}" "${ELEMENTO}/verifica.sh" "$(pwd -P)" >&3
}

main() {
  if (( $# != 1 )); then
    echo "uso: _docente/live.sh <spazio di lavoro>" >&2
    exit 2
  fi
  local ws="$1"
  [[ -n "${ws}" && -d "${ws}" ]] \
    || handson::die "spazio di lavoro assente: ${ws}"
  ws="$(cd -- "${ws}" && pwd -P)" \
    || handson::die "lo spazio di lavoro $1 non si apre"
  cd -- "${ws}" || handson::die "lo spazio di lavoro ${ws} non si apre"
  precondizioni
  handson::banner M7-E01 "Il banco di prova" \
    "Modulo 7, l'esercitazione: il partecipante, emulato in claude -p"
  handson::step "La conversazione con la persona simulata"
  handson::run "${RADICE}/tools/prova_assistente.sh" "${ws}" conversazione \
    --versione "${ws}/${PROGETTO}/v0" \
    --scenario "${ws}/${PROGETTO}/scenari/${SCENARIO}" \
    --uscita "${ws}/conversazione" < /dev/null \
    || fallita "la conversazione non è finita"
  mkdir -- "${CARTELLA_JSON}" \
    || handson::die "non riesco a creare ${CARTELLA_JSON}/"
  handson::step "La lettura, al posto della sessione interattiva"
  passo 2 "${LETTURA}" "${PROMPT_1}"
  handson::step "Le note, nella stessa sessione"
  passo 3 "${SCRITTURA}" "${PROMPT_2}" --resume "${SESSIONE}"
  handson::step "La verifica"
  exec 3>&1
  handson::check "la conversazione e le note" verifica_a_schermo
  handson::finish
}

main "$@"
