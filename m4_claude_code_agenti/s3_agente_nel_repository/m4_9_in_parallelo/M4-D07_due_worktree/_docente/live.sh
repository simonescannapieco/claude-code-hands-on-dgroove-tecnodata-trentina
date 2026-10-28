#!/bin/bash
#
# live.sh di M4-D07 -- la demo del docente: due filoni, due worktree. Due
# modifiche allo stesso file, progetti/urgenze/urgenza.py, chieste da due
# sessioni di claude -p partite insieme: prompt-esempio.txt (un esempio in
# formato doctest nella docstring) e prompt-rinomina.txt (il parametro
# giorni_aperta che diventa giorni_di_apertura). Due bracci che
# differiscono in una cosa sola, il worktree:
#   1. senza worktree: le due sessioni nel checkout principale (lo spazio
#      di lavoro, un repository git con un commit); poi fotografa.sh, e il
#      checkout torna al punto di partenza (git checkout);
#   2. con i worktree: le stesse due sessioni con -w esempio e -w rinomina;
#      poi fotografa.sh.
# Prima il braccio senza: così le sue sessioni non trovano nella cartella
# le copie dei worktree. Sonnet, effort low, gli strumenti Read ed Edit,
# senza server MCP né sessione salvata, lo stream-json di ognuna in
# esecuzioni/<braccio>/<nome>.jsonl. Gli stessi testi e le stesse opzioni
# del README, più quelle che handson::claude_p imposta da sé
# (--permission-mode dontAsk, --permission-prompts none, --setting-sources
# project,local). Le funzioni stanno in _docente/lib_worktree.sh: lì
# worktree::componi compone la riga di handson::claude_p con
# --output-format stream-json --verbose (lì c'è la cartella da cui parte
# ogni sessione), dopo gli stessi controlli della libreria, e le due
# sessioni di un braccio partono insieme, senza ANTHROPIC_API_KEY
# nell'ambiente, dopo che le loro righe si sono viste; un Ctrl-C o un
# TERM, mentre girano, fermano anche loro. Poi verifica.sh, con i dati e i
# verdetti a schermo, e la pulizia: claude -p non toglie i suoi worktree,
# e un worktree bloccato (locked), se lo è, chiede a git worktree remove
# --force due volte; poi i rami.
#
# Uso:    _docente/live.sh <spazio di lavoro>
# Env:    le variabili di tools/lib_handson.sh (HANDSON_NO_PAUSE, …)
# Uscita: 0 = i due bracci ci sono e le garanzie tengono · 1 = una
#         sessione fallita, un braccio che non va, una segnalazione, o una
#         pulizia che non riesce · 2 = precondizione (anche uno spazio di
#         lavoro che non è un repository git pulito, esecuzioni/ o un
#         worktree che c'è già) · 130 o 143 = interrotto da un Ctrl-C o da
#         un TERM mentre le sessioni giravano (fermate anche loro)
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
# lo script sta in <radice>/m4_…/s3_…/m4_9_…/M4-D07_…/_docente/
readonly RADICE="${SELF%/*/*/*/*/*/*}"
readonly CONTROLLO="${SELF%/_docente/*}/verifica.sh"
# shellcheck source=../../../../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"
# shellcheck source=lib_worktree.sh
source "${SELF%/*}/lib_worktree.sh"

readonly MODELLO=sonnet
readonly STRUMENTI='Read,Edit'
readonly OPZIONI=(--effort low --strict-mcp-config --no-session-persistence)
readonly NOMI=(esempio rinomina)
readonly NECESSARI=(prompt-esempio.txt prompt-rinomina.txt fotografa.sh
  progetti/urgenze/urgenza.py progetti/urgenze/test_urgenza.py)
DOMANDE=()
RIGA=()
PULIRE=0

main() {
  local ws="${1:-}" f
  [[ -n "${ws}" && -d "${ws}" ]] \
    || handson::die "spazio di lavoro assente: ${ws}"
  cd "${ws}"
  ws="$(pwd -P)"
  handson::need_tools python3 git
  for f in "${NECESSARI[@]}"; do
    handson::need_file "${f}"
  done
  worktree::controlla_repository "${ws}"
  DOMANDE=("$(< prompt-esempio.txt)" "$(< prompt-rinomina.txt)")
  handson::need_claude
  handson::banner M4-D07 "Due filoni, due worktree" \
    "Modulo 4, «In parallelo»: due modifiche allo stesso file, insieme"
  handson::step "Il punto di partenza: un commit, nessuna modifica"
  handson::run git log --oneline
  mkdir -p esecuzioni/senza-worktree
  handson::step "Senza worktree: le due sessioni insieme, nel checkout"
  worktree::lancia_insieme senza-worktree \
    || worktree::fallita "senza worktree: una sessione è fallita"
  handson::step "Subito la fotografia del braccio, poi il checkout com'era"
  handson::run bash fotografa.sh senza-worktree \
    || worktree::fallita "fotografa.sh non riesce"
  handson::run git diff --stat
  handson::run git checkout -- progetti/urgenze
  git diff --quiet HEAD \
    || handson::die "il checkout non è tornato al punto di partenza"
  mkdir -p esecuzioni/con-worktree
  handson::step "Con i worktree: claude -p -w, le due sessioni insieme"
  PULIRE=1
  worktree::lancia_insieme con-worktree \
    || worktree::fallita "con i worktree: una sessione è fallita"
  handson::step "Subito la fotografia del braccio"
  handson::run bash fotografa.sh con-worktree \
    || worktree::fallita "fotografa.sh non riesce"
  handson::run git branch --list 'worktree-*'
  handson::step "I due bracci, e che cosa dice Anthropic"
  exec 3>&1
  handson::check "due filoni, senza e con i worktree" \
    worktree::verifica_a_schermo "${ws}"
  worktree::pulisci
  handson::finish
}

main "$@"
