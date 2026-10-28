#!/bin/bash
#
# live.sh di M4-D03 -- la demo del docente: un giro del ciclo, registrato.
# Una sessione di claude -p (o N, con --esecuzioni N), ciascuna in una
# copia nuova del progetto delle urgenze, esecuzioni/giro-<n>/urgenze/,
# fatta da nuova_copia.sh come nel README, e da lì partita: il prompt di
# prompt.txt chiede di correggere il confine dei 7 giorni e di eseguire i
# test finché passano, un comando alla volta. Sonnet, effort low, gli
# strumenti Read, Edit e Bash(python3 -m unittest*), senza server MCP né
# sessione salvata; lo stream-json di ognuna in
# esecuzioni/giro-<n>/stream.jsonl. Gli stessi testi e le stesse opzioni
# del README, più quelle che handson::claude_p imposta da sé
# (--permission-mode dontAsk, --permission-prompts none,
# --setting-sources project,local). handson::claude_p però scrive sempre
# --output-format json e rifiuta un altro --output-format, mentre qui serve
# lo stream-json: solo lì si vedono le richieste una per una. chiedi()
# compone quindi la stessa riga con --output-format stream-json --verbose,
# dopo gli stessi controlli della libreria (modello, prompt, modalità di
# permesso, argomenti vietati, chiavi API) e senza ANTHROPIC_API_KEY
# nell'ambiente; la riga si vede prima di girare (handson::run).
# Poi verifica.sh: la tabella delle richieste, i test rieseguiti e il
# verdetto si vedono anche quando passa.
#
# Uso:    _docente/live.sh [--esecuzioni N] <spazio di lavoro>
#           N da 1 a 9 (default 1); la registrazione del corso ne fa 3;
#           lo spazio di lavoro appena preparato, con git status pulito
# Env:    le variabili di tools/lib_handson.sh (HANDSON_NO_PAUSE, …)
# Uscita: 0 = le esecuzioni ci sono e la garanzia tiene · 1 = una chiamata
#         fallita, un'esecuzione che non va, o una segnalazione · 2 =
#         precondizione (anche esecuzioni/ che c'è già, o uno spazio di
#         lavoro che non è al punto di partenza)
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
# lo script sta in <radice>/m4_…/s3_…/m4_5_…/M4-D03_…/_docente/
readonly RADICE="${SELF%/*/*/*/*/*/*}"
readonly CONTROLLO="${SELF%/_docente/*}/verifica.sh"
# shellcheck source=../../../../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"

readonly MODELLO=sonnet
readonly STRUMENTI='Read,Edit,Bash(python3 -m unittest*)'
readonly OPZIONI=(--effort low --strict-mcp-config --no-session-persistence)
readonly NECESSARI=(prompt.txt nuova_copia.sh .claude/settings.json
  progetti/urgenze/urgenza.py progetti/urgenze/test_urgenza.py)
ESECUZIONI=1
SPAZIO=''

usage() {
  echo "Uso: _docente/live.sh [--esecuzioni N] <spazio di lavoro>" >&2
}

#######################################
# Legge gli argomenti. Globals: ESECUZIONI, SPAZIO (assegnate).
# Arguments: quelli dello script. Returns: 0; esce 2 se non vanno.
#######################################
leggi_argomenti() {
  local n=''
  while (( $# > 0 )); do
    case "$1" in
      --esecuzioni|-n)
        (( $# >= 2 )) || { usage; handson::die "--esecuzioni vuole N"; }
        n="$2"
        shift ;;
      --esecuzioni=*) n="${1#--esecuzioni=}" ;;
      -*) usage; handson::die "opzione sconosciuta: $1" ;;
      *)
        [[ -z "${SPAZIO}" ]] \
          || handson::die "uno spazio di lavoro per volta"
        SPAZIO="$1" ;;
    esac
    shift
  done
  if [[ -n "${n}" ]]; then
    [[ "${n}" =~ ^[1-9]$ ]] \
      || handson::die "--esecuzioni vuole un numero da 1 a 9: «${n}»"
    ESECUZIONI="${n}"
  fi
}

#######################################
# Una sessione, dalla copia della sua esecuzione, con il suo stream-json
# accanto alla copia: la riga di handson::claude_p con --output-format
# stream-json --verbose. I controlli stanno fuori dal sottoprocesso e
# fuori da $(…): una precondizione esce davvero con 2.
# Globals: HANDSON_ENV, HANDSON_PERMISSION_MODE, HANDSON_SETTING_SOURCES
#   (lette).
# Arguments: $1 la cartella dell'esecuzione (esecuzioni/giro-<n>), $2 il
#   prompt.
# Returns: l'uscita di claude.
#######################################
chiedi() {
  local cartella="$1" domanda="$2" arg
  handson::need_tools claude
  handson::_claude_p_checks "${MODELLO}" "${domanda}"
  handson::_claude_key_ok "${domanda}"
  for arg in "${MODELLO}" "${STRUMENTI}" "${OPZIONI[@]}"; do
    handson::_claude_arg_ok "${arg}"
  done
  local -a argv=(claude -p --allowedTools "${STRUMENTI}" --model "${MODELLO}"
    --permission-mode "${HANDSON_PERMISSION_MODE}" --permission-prompts none
    --output-format stream-json --verbose
    --setting-sources "${HANDSON_SETTING_SOURCES}" "${OPZIONI[@]}"
    -- "${domanda}")
  handson::note "claude parte dalla copia: ${cartella}/urgenze/"
  (
    # chiedi gira dentro «… || fallita», dove errexit non vale: l'uscita
    # di un cd fallito si dice qui, prima che claude parta altrove.
    cd "${cartella}/urgenze" || exit 2
    if [[ "${HANDSON_ENV}" != "trainer-api" ]]; then
      if [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
        handson::note "ANTHROPIC_API_KEY è impostata: la tolgo per questo" \
          "comando, così Claude Code usa l'abbonamento"
      fi
      unset ANTHROPIC_API_KEY
    fi
    handson::run "${argv[@]}" < /dev/null > ../stream.jsonl
  )
}

# Una chiamata fallita: il verdetto KO e la fine con uscita 1, senza fare
# le esecuzioni che restano.
fallita() {
  handson::verdict ko "$*"
  handson::finish
}

# verifica.sh con il suo STDOUT sul descrittore 3, che main apre sullo
# STDOUT di live.sh: handson::check mostra l'uscita di un controllo solo
# su un KO, e qui la tabella e il verdetto sono la demo anche quando passa.
# Arguments: $1 lo spazio di lavoro. Returns: l'uscita di verifica.sh.
# shellcheck disable=SC2317  # la chiama handson::check, indirettamente
verifica_a_schermo() {
  "${CONTROLLO}" "$1" >&3
}

main() {
  local ws f n domanda cartella stato
  leggi_argomenti "$@"
  [[ -n "${SPAZIO}" && -d "${SPAZIO}" ]] \
    || handson::die "spazio di lavoro assente: ${SPAZIO}"
  cd "${SPAZIO}"
  ws="$(pwd -P)"
  handson::need_tools python3 git
  for f in "${NECESSARI[@]}"; do
    handson::need_file "${f}"
  done
  [[ ! -e esecuzioni ]] \
    || handson::die "ci sono già delle esecuzioni in ${ws}/esecuzioni/;" \
      "per ripartire da capo: tools/reset_esercizio.sh M4-D03"
  # Ogni esecuzione parte dal progetto del primo commit: nuova_copia.sh ne
  # copia i file così come sono, anche un file cambiato o in più.
  [[ "$(git rev-parse --show-toplevel 2> /dev/null)" == "${ws}" ]] \
    || handson::die "${ws} non è un repository git: preparatelo con" \
      "tools/prepara_esercizio.sh M4-D03"
  stato="$(git status --porcelain)" || handson::die "git status non riesce"
  [[ -z "${stato}" ]] \
    || handson::die "lo spazio di lavoro non è al punto di partenza (git" \
      "status non è vuoto): tools/reset_esercizio.sh M4-D03"
  domanda="$(< prompt.txt)"
  handson::need_claude
  handson::banner M4-D03 "Un giro del ciclo, registrato" \
    "Modulo 4, «Il ciclo degli strumenti»: un giro, richiesta per richiesta"
  for (( n = 1; n <= ESECUZIONI; n++ )); do
    cartella="esecuzioni/giro-${n}"
    handson::step "Giro ${n}: una copia nuova del progetto, poi claude -p"
    handson::run bash nuova_copia.sh "${cartella}" \
      || handson::die "nuova_copia.sh non riesce a fare ${cartella}"
    chiedi "${cartella}" "${domanda}" \
      || fallita "giro ${n}: claude -p è fallito"
  done
  handson::step "Le richieste, una per una, e che cosa dice Anthropic"
  exec 3>&1
  handson::check "il giro del ciclo, richiesta per richiesta" \
    verifica_a_schermo "${ws}"
  handson::finish
}

main "$@"
