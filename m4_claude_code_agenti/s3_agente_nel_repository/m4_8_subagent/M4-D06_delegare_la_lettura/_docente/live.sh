#!/bin/bash
#
# live.sh di M4-D06 -- la demo del docente: delegare la lettura.
# La stessa domanda sul guasto di martedì 8 settembre su olt-pergine-01, a
# Claude Code che parte da progetti/rete/log/ dello spazio di lavoro, dove
# ci sono soltanto i log della settimana: nella cartella niente dice la
# risposta. Le coppie: prompt_delega.txt (delega la lettura dei log al
# subagent Explore, con un riassunto breve) e prompt_senza.txt (leggi tu i
# log); i due prompt differiscono soltanto nella prima frase. Ogni
# chiamata: claude -p, sonnet, --effort low, --tools Agent,Read,Grep,Glob
# (fra gli strumenti integrati soltanto questi: Agent lancia il subagent,
# e Bash non c'è, perché un suo ls -la in sola lettura, che di regola non
# chiede il permesso, scriveva negli stream l'utente della macchina),
# consentiti Read, Grep e Glob (su macOS, Linux e WSL Claude Code lascia
# Glob e Grep fuori dagli strumenti predefiniti; nominati, tornano),
# --permission-mode dontAsk
# (HANDSON_PERMISSION_MODE), --permission-prompts none, --output-format
# stream-json --verbose, --setting-sources project,local,
# --strict-mcp-config, --no-session-persistence: le stesse opzioni del
# passo 2 del README.
# handson::claude_p scrive sempre --output-format json e rifiuta un altro
# --output-format, mentre qui serve lo stream-json, dove si vedono i
# messaggi del subagent: chiedi() compone la stessa riga, dopo gli stessi
# controlli della libreria (modello, prompt, modalità di permesso,
# argomenti vietati, chiavi API), senza ANTHROPIC_API_KEY nell'ambiente;
# la riga si vede prima di girare (handson::run).
# Gli stream restano in una cartella temporanea finché l'ultima chiamata
# non è finita, e solo allora vanno in risposte/: mentre una sessione
# gira, nello spazio di lavoro non c'è la risposta di una sessione prima.
# Se una chiamata fallisce, ciò che c'è va in risposte/ prima che la
# cartella temporanea si tolga, e la demo si ferma.
# Poi verifica.sh, con la verità dell'elemento, dice i dati e i verdetti,
# che si vedono anche quando passa.
#
# Uso:    _docente/live.sh <spazio di lavoro>
#         lo spazio di lavoro appena preparato (tools/prepara_esercizio.sh
#         M4-D06), con git status pulito
# Env:    PN_COPPIE quante coppie, da 1 a 9 (default 3); le variabili di
#         tools/lib_handson.sh (HANDSON_NO_PAUSE, HANDSON_PERMISSION_MODE,
#         …; HANDSON_ENV, se c'è, deve essere claude-code-pro)
# Uscita: 0 = gli stream ci sono, si leggono, almeno un'esecuzione con la
#         delega mette alla prova la garanzia e la garanzia tiene (il
#         confronto non decide l'uscita) · 1 = una chiamata fallita, uno
#         stream che non va, la garanzia non confermata o mai messa alla
#         prova · 2 = precondizione
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
# lo script sta in <radice>/m4_…/s3_…/m4_8_…/M4-D06_…/_docente/
readonly RADICE="${SELF%/*/*/*/*/*/*}"
readonly ELEMENTO="${SELF%/_docente/*}"
readonly CONTROLLO="${ELEMENTO}/verifica.sh"
# shellcheck source=../../../../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"

readonly MODELLO=sonnet
readonly DISPONIBILI='Agent,Read,Grep,Glob'
readonly STRUMENTI='Read,Grep,Glob'
readonly OPZIONI=(--effort low --strict-mcp-config --no-session-persistence)
readonly LOG=progetti/rete/log
readonly LATI=(delega senza)
COPPIE="${PN_COPPIE:-3}"
# La cartella temporanea degli stream, finché le chiamate non sono finite.
DEPOSITO=''

# Una chiamata da progetti/rete/log, con il suo stream-json in un file: la
# riga di handson::claude_p con --output-format stream-json --verbose. I
# controlli stanno fuori dal sottoprocesso e fuori da $(…): una
# precondizione esce davvero con 2. L'elemento è claude-code-pro:
# ANTHROPIC_API_KEY esce sempre dall'ambiente di claude.
# Globals: HANDSON_PERMISSION_MODE, HANDSON_SETTING_SOURCES (lette).
# Arguments: $1 il file del prompt, $2 il file dello stream.
# Returns: l'uscita di claude.
chiedi() {
  local domanda arg
  domanda="$(< "$1")"
  handson::need_tools claude
  handson::_claude_p_checks "${MODELLO}" "${domanda}"
  handson::_claude_key_ok "${domanda}"
  for arg in "${MODELLO}" "${DISPONIBILI}" "${STRUMENTI}" "${OPZIONI[@]}"; do
    handson::_claude_arg_ok "${arg}"
  done
  local -a argv=(claude -p --tools "${DISPONIBILI}"
    --allowedTools "${STRUMENTI}" --model "${MODELLO}"
    --permission-mode "${HANDSON_PERMISSION_MODE}" --permission-prompts none
    --output-format stream-json --verbose
    --setting-sources "${HANDSON_SETTING_SOURCES}" "${OPZIONI[@]}"
    -- "${domanda}")
  (
    if [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
      handson::note "ANTHROPIC_API_KEY è impostata: la tolgo per questo" \
        "comando, così Claude Code usa l'abbonamento"
    fi
    unset ANTHROPIC_API_KEY
    cd -- "${LOG}" && handson::run "${argv[@]}"
  ) < /dev/null > "$2"
}

# Gli stream del deposito, copiati in risposte/ dello spazio di lavoro (la
# cartella corrente), per verifica.sh e per lo schermo.
# Globals: DEPOSITO (letta).
consegna() {
  mkdir -p risposte
  handson::run cp -- "${DEPOSITO}"/*.jsonl risposte/
}

# Una chiamata fallita: gli stream che ci sono vanno in risposte/ prima che
# la cartella temporanea si tolga, poi il verdetto KO e la fine con uscita
# 1, senza fare le chiamate che restano.
fallita() {
  consegna
  handson::verdict ko "$*"
  handson::finish
}

# verifica.sh con il suo STDOUT sul descrittore 3, che main apre sullo
# STDOUT di live.sh: handson::check mostra l'uscita di un controllo solo
# su un KO, e qui i dati e i verdetti sono la demo anche quando passa.
# Returns: l'uscita di verifica.sh.
# shellcheck disable=SC2317  # la chiama handson::check, indirettamente
verifica_a_schermo() {
  "${CONTROLLO}" "$(pwd -P)" >&3
}

# Le precondizioni, prima di ogni chiamata: l'ambiente dell'elemento, gli
# strumenti, i file dello spazio di lavoro e dell'elemento (la verifica,
# il controllo, la verità), i log, il punto di partenza, PN_COPPIE, i due
# prompt (con i controlli della libreria), claude. Va chiamata nello
# spazio di lavoro.
precondizioni() {
  local f radice stato domanda
  [[ "${HANDSON_ENV}" == claude-code-pro ]] \
    || handson::die "M4-D06 è un elemento claude-code-pro: HANDSON_ENV" \
      "«${HANDSON_ENV}» non vale qui (la chiave API resterebbe" \
      "nell'ambiente di claude -p)"
  handson::need_tools python3 git
  for f in prompt_delega.txt prompt_senza.txt controlla_delega.py \
      "${ELEMENTO}/demo/controlla_delega.py" "${ELEMENTO}/verita.json"; do
    handson::need_file "${f}"
  done
  [[ -x "${CONTROLLO}" ]] \
    || handson::die "verifica.sh dell'elemento assente o non eseguibile"
  [[ -d "${LOG}/syslog" ]] || handson::die "mancano i log: ${LOG}/"
  radice="$(git rev-parse --show-toplevel 2> /dev/null)" || radice=''
  [[ "${radice}" == "$(pwd -P)" ]] \
    || handson::die "$(pwd -P) non è un repository git: preparatelo con" \
      "tools/prepara_esercizio.sh M4-D06"
  stato="$(git status --porcelain)" || handson::die "git status non riesce"
  [[ -z "${stato}" ]] \
    || handson::die "lo spazio di lavoro non è al punto di partenza (git" \
      "status non è vuoto): tools/reset_esercizio.sh M4-D06"
  [[ "${COPPIE}" =~ ^[1-9]$ ]] \
    || handson::die "PN_COPPIE vuole un numero da 1 a 9, non «${COPPIE}»"
  for f in prompt_delega.txt prompt_senza.txt; do
    domanda="$(< "${f}")"
    handson::_claude_p_checks "${MODELLO}" "${domanda}"
    handson::_claude_key_ok "${domanda}"
  done
  handson::need_claude
}

main() {
  local ws="${1:-}" n lato
  [[ -n "${ws}" && -d "${ws}" ]] \
    || handson::die "spazio di lavoro assente: ${ws}"
  cd -- "${ws}" || handson::die "lo spazio di lavoro ${ws} non si apre"
  precondizioni
  handson::banner M4-D06 "Delegare la lettura" \
    "Modulo 4, «Subagent: delegare o fare da sé»: i log, con e senza Explore"
  handson::tmpdir DEPOSITO
  for (( n = 1; n <= COPPIE; n++ )); do
    for lato in "${LATI[@]}"; do
      handson::step "coppia ${n}: ${lato} (prompt_${lato}.txt)"
      chiedi "prompt_${lato}.txt" "${DEPOSITO}/${lato}-${n}.jsonl" \
        || fallita "${lato}-${n}: claude -p è fallito"
    done
  done
  handson::step "Le risposte nello spazio di lavoro, a sessioni finite"
  consegna
  handson::step "Che cosa vede la conversazione principale, e quanto costa"
  exec 3>&1
  handson::check "le coppie, con la verità dell'elemento" verifica_a_schermo
  handson::finish
}

main "$@"
