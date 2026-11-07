#!/bin/bash
#
# in_classe.sh -- M6-D02 dal vivo, «Che cosa entra all'avvio, e che cosa
# quando serve». Per ogni esecuzione due chiamate di claude -p, ognuna in una
# copia nuova di progetto/ con nove parole in codice casuali nei nove posti:
#   avvio-<n>    nessuno strumento (--tools ""): domanda_avvio.txt;
#   lettura-<n>  solo Read: domanda_lettura.txt, legge src/a.php e
#                sub/nota.txt.
# Poi, una volta, i quattro bracci di costo, costo/<braccio>/CLAUDE.md con
# domanda_costo.txt («Rispondi solo: ok»): base, commento, inline, import.
# Ogni copia ha l'hook InstructionsLoaded di progetto/.claude/: il suo
# registro esce con lo stream (vedi lib_caricamento.sh). Ogni comando si vede
# prima di girare (handson::claude_p). Gli stream, i registri e le parole
# vanno in risposte/ quando l'ultima chiamata è finita, e
# controlla_caricamento.py decide ogni garanzia a ogni esecuzione.
#
# Uso:    <cartella dell'elemento>/demo/in_classe.sh <spazio di lavoro>
#           dal repository, sullo spazio di lavoro appena preparato (git status
#           pulito); dalla copia nello spazio di lavoro serve PN_HANDSON_ROOT
# Env:    PN_ESECUZIONI    quante esecuzioni di avvio e lettura, da 1 a 9
#                          (default 1)
#         PN_HANDSON_ROOT  il repository (default: dal percorso di questo file)
#         le variabili di tools/lib_handson.sh (HANDSON_NO_PAUSE, …)
# Uscita: 0 = gli stream si leggono e ogni garanzia è confermata · 1 = una
#         chiamata fallita, una garanzia non confermata o non messa alla prova
#         · 2 = precondizione, anche del controllo
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
# lo script sta in <radice>/m6_…/s5_…/m6_3_…/M6-D02_…/demo/
readonly RADICE="${PN_HANDSON_ROOT:-${SELF%/*/*/*/*/*/*}}"
if [[ ! -f "${RADICE}/tools/lib_handson.sh" ]]; then
  echo "in_classe.sh: non trovo tools/lib_handson.sh in ${RADICE}: lanciatelo" \
    "dal repository, o date PN_HANDSON_ROOT" >&2
  exit 2
fi
# shellcheck source=../../../../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"
# shellcheck source=lib_caricamento.sh
source "${SELF%/*}/lib_caricamento.sh"

readonly ELEMENTO=M6-D02
readonly MODELLO=sonnet
readonly NECESSARI=(domanda_avvio.txt domanda_lettura.txt domanda_costo.txt
  controlla_caricamento.py progetto/.claude/settings.json
  progetto/.claude/hooks/registra_caricamenti.py progetto/src/a.php
  costo/procedura.md)
# shellcheck disable=SC2034  # la legge handson::claude_p
HANDSON_OUTPUT_FORMAT='stream-json'
SPAZIO=''

# Una chiamata fallita: ciò che c'è va in risposte/, il verdetto KO, l'uscita
# 1. Arguments: il testo del verdetto.
fallita() {
  caricamento::consegna
  handson::verdict ko "$*"
  handson::finish
}

# Le precondizioni, tutte prima della prima chiamata. Va chiamata nello spazio
# di lavoro. Globals: SPAZIO (assegnata).
precondizioni() {
  local f segno stato
  [[ "${HANDSON_ENV}" == claude-code-pro ]] \
    || handson::die "${ELEMENTO} è un elemento claude-code-pro: HANDSON_ENV" \
      "«${HANDSON_ENV}» non vale qui"
  handson::need_tools python3 git
  SPAZIO="$(pwd -P)"
  segno="$(git config --get corso.elemento 2> /dev/null)" || segno=''
  [[ "${segno}" == "${ELEMENTO}" \
      && "$(git rev-parse --show-toplevel 2> /dev/null)" == "${SPAZIO}" ]] \
    || handson::die "${SPAZIO} non è lo spazio di lavoro di ${ELEMENTO}:" \
      "preparatelo con tools/prepara_esercizio.sh ${ELEMENTO}"
  [[ ! -e risposte ]] \
    || handson::die "risposte/ c'è già: per ricominciare," \
      "tools/reset_esercizio.sh ${ELEMENTO}"
  stato="$(git status --porcelain)" || handson::die "git status non riesce"
  [[ -z "${stato}" ]] \
    || handson::die "lo spazio di lavoro non è al punto di partenza (git" \
      "status non è vuoto): tools/reset_esercizio.sh ${ELEMENTO}"
  for f in "${NECESSARI[@]}" "${CARICAMENTO_FILE[@]/#/progetto/}"; do
    handson::need_file "${f}"
  done
  for f in "${CARICAMENTO_BRACCI[@]}"; do
    handson::need_file "costo/${f}/CLAUDE.md"
  done
  [[ "${PN_ESECUZIONI:-1}" =~ ^[1-9]$ ]] \
    || handson::die "PN_ESECUZIONI vuole un numero da 1 a 9, non" \
      "«${PN_ESECUZIONI}»"
  for f in domanda_avvio.txt domanda_lettura.txt domanda_costo.txt; do
    handson::_claude_p_checks "${MODELLO}" "$(< "${f}")"
    handson::_claude_key_ok "$(< "${f}")"
  done
  handson::need_claude
}

# Un'esecuzione: avvio e lettura, ognuna nella sua copia, con le sue parole.
# Arguments: $1 il numero.
una_esecuzione() {
  handson::step "Esecuzione $1: avvio-$1 senza strumenti, lettura-$1 con Read"
  handson::pause "le due chiamate"
  caricamento::copia_progetto "avvio-$1"
  caricamento::chiedi "avvio-$1" "" domanda_avvio.txt \
    || fallita "avvio-$1: claude -p è fallito"
  caricamento::copia_progetto "lettura-$1"
  caricamento::chiedi "lettura-$1" Read domanda_lettura.txt \
    || fallita "lettura-$1: claude -p è fallito"
}

# I quattro bracci di costo, la stessa domanda, nessuno strumento.
costi() {
  local b
  handson::step "Il costo: base, commento, inline, import, «Rispondi solo: ok»"
  handson::pause "le quattro chiamate"
  for b in "${CARICAMENTO_BRACCI[@]}"; do
    caricamento::copia_costo "${b}"
    caricamento::chiedi "costo-${b}" "" domanda_costo.txt \
      || fallita "costo-${b}: claude -p è fallito"
  done
}

main() {
  local ws="${1:-}" n rc=0
  [[ -n "${ws}" && -d "${ws}" ]] \
    || handson::die "spazio di lavoro assente: ${ws}"
  cd -- "${ws}" || handson::die "lo spazio di lavoro ${ws} non si apre"
  precondizioni
  export PN_HANDSON_ROOT="${RADICE}"
  caricamento::apri_temporanei
  handson::banner "${ELEMENTO}" \
    "Che cosa entra all'avvio, e che cosa quando serve" \
    "Modulo 6, «CLAUDE.md: istruzioni che si caricano sempre»"
  handson::note "in ogni chiamata CLAUDE_CODE_DISABLE_AUTO_MEMORY=1: la auto" \
    "memory è spenta"
  for (( n = 1; n <= ${PN_ESECUZIONI:-1}; n++ )); do
    una_esecuzione "${n}"
  done
  costi
  handson::step "Gli stream, i registri e le parole in risposte/"
  caricamento::consegna
  handson::step "Il controllo"
  handson::run python3 -B -I controlla_caricamento.py "${SPAZIO}" \
    < /dev/null || rc=$?
  handson::verdict_rc "${rc}" "le garanzie, sugli stream di risposte/"
  handson::finish
}

main "$@"
