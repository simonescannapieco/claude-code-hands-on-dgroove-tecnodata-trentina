#!/bin/bash
#
# live.sh di M4-D05 -- la demo del docente: il controllo che non si salta.
# Due bracci che differiscono in una cosa sola, lo Stop hook di
# .claude/settings.json che esegue i test (impostazioni/con-hook.json e
# impostazioni/senza-hook.json, mostrati con diff prima di cominciare):
# per ogni braccio una copia nuova del progetto delle urgenze,
# esecuzioni/<braccio>-<n>/urgenze/, fatta da nuova_copia.sh come nel
# README, e da lì claude -p con il prompt di prompt.txt, che chiede
# soltanto una docstring più chiara con un esempio. Sonnet, effort low,
# acceptEdits, gli strumenti Read, Edit e Bash(python3 -m unittest*), senza
# server MCP né sessione salvata; lo stream-json di ognuna in
# esecuzioni/<braccio>-<n>/stream.jsonl. Prima il braccio con l'hook, poi
# quello senza; con --esecuzioni N, N esecuzioni per braccio. Gli stessi
# testi e le stesse opzioni del README, più quelle che handson::claude_p
# imposta da sé (--permission-prompts none, --setting-sources
# project,local; la modalità è acceptEdits, salvo un HANDSON_PERMISSION_MODE
# dato). Prima di ogni chiamata: lo spazio di lavoro al punto di partenza
# (git status vuoto), perché ogni copia parta dallo stesso progetto, e le
# impostazioni dei due bracci uguali una volta tolta la chiave hooks. Le
# funzioni stanno in _docente/lib_stop.sh: lì stop::chiedi compone la riga
# di handson::claude_p con --output-format stream-json --verbose (solo lì
# si vedono i blocchi dell'hook), dopo gli stessi controlli della libreria
# e senza ANTHROPIC_API_KEY nell'ambiente; la riga si vede prima di girare
# (handson::run). Poi verifica.sh: i dati e i verdetti si vedono anche
# quando passa.
#
# Uso:    _docente/live.sh [--esecuzioni N] <spazio di lavoro>
#           N da 1 a 9 per braccio (default 1); lo spazio di lavoro appena
#           preparato, con git status pulito
# Env:    le variabili di tools/lib_handson.sh (HANDSON_NO_PAUSE, …);
#         HANDSON_PERMISSION_MODE, se data, al posto di acceptEdits
# Uscita: 0 = la coppia c'è e la garanzia tiene · 1 = una chiamata fallita,
#         un'esecuzione o una coppia che non va, nessun blocco con l'hook, o
#         una segnalazione · 2 = precondizione (anche esecuzioni/ che c'è
#         già, uno spazio di lavoro che non è al punto di partenza, o due
#         impostazioni che differiscono in altro che l'hook, o in niente)
set -euo pipefail

# La modalità della prova, acceptEdits, letta prima della libreria, che
# altrimenti metterebbe la sua (dontAsk).
readonly MODO_DELLA_PROVA="${HANDSON_PERMISSION_MODE:-acceptEdits}"
SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
# lo script sta in <radice>/m4_…/s3_…/m4_7_…/M4-D05_…/_docente/
readonly RADICE="${SELF%/*/*/*/*/*/*}"
readonly CONTROLLO="${SELF%/_docente/*}/verifica.sh"
# shellcheck source=../../../../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"
# shellcheck source=lib_stop.sh
source "${SELF%/*}/lib_stop.sh"
HANDSON_PERMISSION_MODE="${MODO_DELLA_PROVA}"

readonly MODELLO=sonnet
readonly STRUMENTI='Read,Edit,Bash(python3 -m unittest*)'
readonly OPZIONI=(--effort low --strict-mcp-config --no-session-persistence)
readonly BRACCI=(con-hook senza-hook)
readonly NECESSARI=(prompt.txt nuova_copia.sh impostazioni/con-hook.json
  impostazioni/senza-hook.json progetti/urgenze/urgenza.py
  progetti/urgenze/test_urgenza.py)
ESECUZIONI=1
SPAZIO=''

main() {
  local ws f n b domanda cartella
  stop::leggi_argomenti "$@"
  [[ -n "${SPAZIO}" && -d "${SPAZIO}" ]] \
    || handson::die "spazio di lavoro assente: ${SPAZIO}"
  cd "${SPAZIO}"
  ws="$(pwd -P)"
  handson::need_tools python3 git diff
  for f in "${NECESSARI[@]}"; do
    handson::need_file "${f}"
  done
  [[ ! -e esecuzioni ]] \
    || handson::die "ci sono già delle esecuzioni in ${ws}/esecuzioni/;" \
      "per ripartire da capo: tools/reset_esercizio.sh M4-D05"
  stop::al_punto_di_partenza "${ws}"
  stop::uguali_tolto_hook
  domanda="$(< prompt.txt)"
  handson::need_claude
  handson::banner M4-D05 "Il controllo che non si salta" \
    "Modulo 4, «La rete di sicurezza»: lo stesso prompt, con e senza Stop hook"
  handson::step "Le impostazioni dei due bracci: la sola differenza"
  stop::mostra_differenza
  for (( n = 1; n <= ESECUZIONI; n++ )); do
    for b in "${BRACCI[@]}"; do
      cartella="esecuzioni/${b}-${n}"
      handson::step "${b}-${n}: una copia nuova del progetto, poi claude -p"
      handson::run bash nuova_copia.sh "${cartella}" "impostazioni/${b}.json" \
        || handson::die "nuova_copia.sh non riesce a fare ${cartella}"
      stop::chiedi "${cartella}" "${domanda}" \
        || stop::fallita "${b}-${n}: claude -p è fallito"
    done
  done
  handson::step "I due bracci, e che cosa dice Anthropic"
  exec 3>&1
  handson::check "la coppia, con e senza Stop hook" stop::verifica_a_schermo \
    "${ws}"
  handson::finish
}

main "$@"
