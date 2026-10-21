#!/bin/bash
#
# live.sh di M2-D05 -- la demo del docente: ragionare, oggi. Il problema
# degli sportelli con «Rispondi direttamente, senza ragionare: scrivi solo
# l'orario.», in sette chiamate con claude -p, senza strumenti né server
# MCP, con «Rispondi in italiano.» come system prompt:
#   R1 haiku low    R2 haiku low, con MAX_THINKING_TOKENS=0 per questa
#                      sola chiamata                        R3 haiku high
#   R4 sonnet low   R5 sonnet high   R6 opus low   R7 opus high
# Le stesse chiamate dei passi del README, con gli stessi testi e le stesse
# opzioni (handson::claude_p aggiunge quelle dei permessi, che senza
# strumenti non hanno effetto). Ogni risposta diventa una riga di
# ragionamento.tsv con
# leggi_json.py e orario.py, come nei passi del README: il modello che ha
# risposto, l'orario (un dato, mai un verdetto), i token in uscita e quelli
# di ragionamento. Poi verifica.sh con handson::check: i numeri e una riga
# per affermazione, a schermo anche quando la verifica passa.
#
# Uso:    _docente/live.sh <spazio di lavoro>
# Env:    le variabili di tools/lib_handson.sh (HANDSON_NO_PAUSE, …).
#         CLAUDE_CODE_EFFORT_LEVEL non deve essere impostata: vale più di
#         --effort, mentre la tabella scrive l'effort chiesto con --effort.
#         MAX_THINKING_TOKENS la toglie lo script: arriva soltanto a R2.
# Uscita: 0 = tabella completa e V1 confermata (verifica.sh esce 0) · 1 =
#         una chiamata fallita (la demo si ferma lì) o verifica.sh esce 1
#         · 2 = precondizione: CLAUDE_CODE_EFFORT_LEVEL impostata, uno
#         strumento o un file che manca, oppure verifica.sh esce 2 (per
#         esempio con un modello che non è quello della riga)
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
# lo script sta in <radice>/m2_…/s1_…/m2_6_…/M2-D05_…/_docente/
readonly RADICE="${SELF%/*/*/*/*/*/*}"
readonly CONTROLLO="${SELF%/_docente/*}/verifica.sh"
# shellcheck source=../../../../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"

readonly SPENTO='MAX_THINKING_TOKENS=0'
# Le sette chiamate, R1-R7, come modello:effort:thinking_off.
readonly PROVE=(haiku:low:no haiku:low:MAX_THINKING_TOKENS=0 haiku:high:no
  sonnet:low:no sonnet:high:no opus:low:no opus:high:no)
readonly FILE_PARTENZA=(sportelli.md direttamente.txt istruzione.txt
  leggi_json.py orario.py)
# Il prompt e il system prompt, letti dai file in main.
PROMPT=''
ISTRUZIONE=''

# Una chiamata, nella shell dello script e non dentro $(…): una
# precondizione di handson::claude_p esce davvero 2. Il JSON va nel file
# $4. Con $3 = MAX_THINKING_TOKENS=0 la variabile arriva a questa sola
# chiamata: un'assegnazione davanti al comando, che non resta nella shell.
# Globals: PROMPT, ISTRUZIONE (lette).
# Arguments: $1 il modello, $2 l'effort, $3 no o MAX_THINKING_TOKENS=0,
#   $4 il file del JSON.
# Returns: il codice d'uscita di claude.
chiama() {
  local -a opzioni=(--effort "$2" --tools "" --system-prompt "${ISTRUZIONE}"
    --strict-mcp-config --no-session-persistence)
  if [[ "$3" == "${SPENTO}" ]]; then
    MAX_THINKING_TOKENS=0 handson::claude_p "$1" "" "${PROMPT}" \
      "${opzioni[@]}" < /dev/null > "$4"
  else
    handson::claude_p "$1" "" "${PROMPT}" "${opzioni[@]}" < /dev/null > "$4"
  fi
}

# La riga di una chiamata in ragionamento.tsv e a schermo, con gli stessi
# comandi dei passi del README: leggi_json.py per il modello che ha
# risposto e per i token, orario.py per l'orario. L'orario è un dato: se la
# risposta non ne ha uno, orario.py lo dice su STDERR e il campo resta
# vuoto, come nei passi del README.
# Arguments: $1 l'etichetta (R1…R7), $2 il modello, $3 l'effort, $4 no o
#   MAX_THINKING_TOKENS=0, $5 il file del JSON.
# Returns: 1 se il JSON non dice il modello o i token (una risposta con un
#   errore, un JSON rovinato).
riga() {
  local id uscita thinking orario
  id="$(python3 -B leggi_json.py modello < "$5")" || return 1
  uscita="$(python3 -B leggi_json.py token_uscita < "$5")" || return 1
  thinking="$(python3 -B leggi_json.py token_thinking < "$5")" || return 1
  if ! orario="$(python3 -B orario.py 9:00 < "$5")"; then
    orario=''
  fi
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$2" "$3" "$4" "${id}" \
    "${orario}" "${uscita}" "${thinking}" >> ragionamento.tsv
  printf '  %s  %s, orario %s, token in uscita %s, di ragionamento %s\n' \
    "$1" "${id}" "${orario:-—}" "${uscita}" "${thinking}"
}

# Una chiamata fallita: il verdetto KO e la fine con uscita 1, senza fare
# le chiamate che restano.
fallita() {
  handson::verdict ko "$*"
  handson::finish
}

# Una prova: la chiamata, poi la sua riga. Una chiamata fallita, o una
# risposta senza il modello o i token, chiude la demo.
# Arguments: $1 l'etichetta, $2 la prova (modello:effort:thinking_off),
#   $3 il file del JSON.
prova() {
  local modello effort spento
  IFS=: read -r modello effort spento <<< "$2"
  if [[ "${spento}" == "${SPENTO}" ]]; then
    handson::step "$1: ${modello}, effort ${effort}, con ${SPENTO} per" \
      "questa sola chiamata"
  else
    handson::step "$1: ${modello}, effort ${effort}"
  fi
  chiama "${modello}" "${effort}" "${spento}" "$3" \
    || fallita "$1 (${modello}, ${effort}): claude -p è fallito"
  riga "$1" "${modello}" "${effort}" "${spento}" "$3" \
    || fallita "$1 (${modello}, ${effort}): il JSON non dice il modello o" \
      "i token"
}

# Il controllo dell'esito: verifica.sh, che stampa i numeri e una riga per
# affermazione. Il suo STDOUT va sul descrittore 3, la copia dello STDOUT
# dello script aperta in main: così l'aula lo legge anche quando la
# verifica passa (handson::check mostra l'uscita di un controllo soltanto
# su un KO). Il codice d'uscita resta quello di verifica.sh.
# Arguments: $1 lo spazio di lavoro.
# shellcheck disable=SC2317  # la chiama handson::check, indirettamente
controllo() {
  "${CONTROLLO}" "$1" >&3
}

main() {
  local ws="${1:-}" f i json
  [[ -n "${ws}" && -d "${ws}" ]] \
    || handson::die "spazio di lavoro assente: ${ws}"
  if [[ -n "${CLAUDE_CODE_EFFORT_LEVEL+x}" ]]; then
    handson::die "CLAUDE_CODE_EFFORT_LEVEL è impostata" \
      "(«${CLAUDE_CODE_EFFORT_LEVEL}»): vale più di --effort, mentre la" \
      "tabella scriverebbe l'effort chiesto con --effort. Toglietela con" \
      "«unset CLAUDE_CODE_EFFORT_LEVEL» e rilanciate."
  fi
  if [[ -n "${MAX_THINKING_TOKENS+x}" ]]; then
    handson::note "MAX_THINKING_TOKENS è impostata: la tolgo, arriva" \
      "soltanto a R2"
  fi
  unset MAX_THINKING_TOKENS
  cd "${ws}"
  handson::need_tools python3
  for f in "${FILE_PARTENZA[@]}"; do
    handson::need_file "${f}"
  done
  handson::need_claude
  PROMPT="$(cat sportelli.md)"$'\n'"$(cat direttamente.txt)"
  ISTRUZIONE="$(cat istruzione.txt)"
  handson::tmpfile json
  exec 3>&1
  handson::banner M2-D05 "Ragionare, oggi" \
    "Modulo 2, «Ragionare, sui modelli di oggi»: sette chiamate"
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' modello effort thinking_off \
    modello_id orario token_uscita token_thinking > ragionamento.tsv
  for i in "${!PROVE[@]}"; do
    prova "R$((i + 1))" "${PROVE[i]}" "${json}"
  done
  handson::step "Il controllo: le affermazioni messe alla prova"
  handson::check "tabella completa, thinking_tokens <= output_tokens (V1)" \
    controllo "${ws}"
  handson::finish
}

main "$@"
