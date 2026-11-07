#!/bin/bash
#
# in_classe.sh -- M6-D04 dal vivo, «Una modifica a sessione avviata, e dopo
# /compact». Per ogni esecuzione tre sessioni, ognuna un solo processo di
# claude -p con --input-format stream-json, in una copia nuova di progetto/
# con parole in codice casuali (sessione.py, che mostra il comando e ogni
# passo):
#   compact-<n>  domanda; CLAUDE.md riscritto da fuori; domanda; /compact;
#                domanda                              (nessuno strumento)
#   clear-<n>    gli stessi, con /clear al posto di /compact
#   regola-<n>   leggi src/a.php; /compact; elenca; leggi; elenca (solo Read)
# Mai --resume: ogni chiamata ripresa è un processo nuovo, che rilegge i
# CLAUDE.md. Gli stream, i registri dell'hook InstructionsLoaded e i passi
# stanno in una cartella temporanea finché l'ultima sessione non è finita,
# poi vanno in risposte/, e controlla_sessione.py decide ogni garanzia a ogni
# esecuzione.
#
# Uso:    <cartella dell'elemento>/demo/in_classe.sh <spazio di lavoro>
#           dal repository, sullo spazio di lavoro appena preparato (git status
#           pulito); dalla copia nello spazio di lavoro serve PN_HANDSON_ROOT
# Env:    PN_ESECUZIONI       quante esecuzioni, da 1 a 9 (default 1)
#         PN_SESSIONE_ATTESA  i secondi che un passo può durare (default 300)
#         PN_HANDSON_ROOT     il repository (default: dal percorso di questo
#                             file)
#         le variabili di tools/lib_handson.sh (HANDSON_NO_PAUSE, …)
# Uscita: 0 = gli stream si leggono e ogni garanzia è confermata · 1 = una
#         sessione fallita, una garanzia non confermata o non messa alla prova
#         · 2 = precondizione, anche di sessione.py o del controllo
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
# lo script sta in <radice>/m6_…/s5_…/m6_6_…/M6-D04_…/demo/
readonly RADICE="${PN_HANDSON_ROOT:-${SELF%/*/*/*/*/*/*}}"
if [[ ! -f "${RADICE}/tools/lib_handson.sh" ]]; then
  echo "in_classe.sh: non trovo tools/lib_handson.sh in ${RADICE}: lanciatelo" \
    "dal repository, o date PN_HANDSON_ROOT" >&2
  exit 2
fi
# shellcheck source=../../../../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"

readonly ELEMENTO=M6-D04
readonly TIPI=(compact clear regola)
readonly NECESSARI=(sessione.py controlla_sessione.py domanda.txt leggi.txt
  elenca.txt progetto/CLAUDE.md progetto/.claude/rules/php.md
  progetto/.claude/settings.json progetto/.claude/hooks/registra_caricamenti.py
  progetto/src/a.php)
DEPOSITO=''
COPIE=''

# Gli stream, i registri e i passi in risposte/ dello spazio di lavoro.
# Globals: DEPOSITO.
consegna() {
  mkdir -p risposte || handson::die "non riesco a creare risposte/"
  handson::run cp -R -- "${DEPOSITO}/." risposte/ < /dev/null \
    || handson::die "non riesco a copiare gli stream in risposte/"
}

# Le precondizioni, tutte prima della prima sessione. Va chiamata nello
# spazio di lavoro.
precondizioni() {
  local f segno stato
  [[ "${HANDSON_ENV}" == claude-code-pro ]] \
    || handson::die "${ELEMENTO} è un elemento claude-code-pro: HANDSON_ENV" \
      "«${HANDSON_ENV}» non vale qui"
  handson::need_tools python3 git
  segno="$(git config --get corso.elemento 2> /dev/null)" || segno=''
  [[ "${segno}" == "${ELEMENTO}" \
      && "$(git rev-parse --show-toplevel 2> /dev/null)" == "$(pwd -P)" ]] \
    || handson::die "$(pwd -P) non è lo spazio di lavoro di ${ELEMENTO}:" \
      "preparatelo con tools/prepara_esercizio.sh ${ELEMENTO}"
  [[ ! -e risposte ]] \
    || handson::die "risposte/ c'è già: per ricominciare," \
      "tools/reset_esercizio.sh ${ELEMENTO}"
  stato="$(git status --porcelain)" || handson::die "git status non riesce"
  [[ -z "${stato}" ]] \
    || handson::die "lo spazio di lavoro non è al punto di partenza (git" \
      "status non è vuoto): tools/reset_esercizio.sh ${ELEMENTO}"
  for f in "${NECESSARI[@]}"; do
    handson::need_file "${f}"
  done
  [[ "${PN_ESECUZIONI:-1}" =~ ^[1-9]$ ]] \
    || handson::die "PN_ESECUZIONI vuole un numero da 1 a 9, non" \
      "«${PN_ESECUZIONI}»"
  for f in domanda.txt leggi.txt elenca.txt; do
    handson::_claude_key_ok "$(< "${f}")"
  done
  handson::need_claude
}

# Una sessione: sessione.py, con il comando sullo schermo; se fallisce, ciò
# che c'è va in risposte/ e la demo si ferma. Globals: DEPOSITO, COPIE.
# Arguments: $1 il tipo, $2 il numero.
una_sessione() {
  local rc=0
  handson::step "$1-$2"
  handson::run python3 -B -I sessione.py --tipo "$1" --nome "$1-$2" \
    --progetto progetto --copie "${COPIE}" --deposito "${DEPOSITO}" || rc=$?
  if (( rc == 0 )); then
    return 0
  fi
  consegna
  if (( rc >= 2 )); then
    handson::die "sessione.py è uscito con ${rc}: una precondizione"
  fi
  handson::verdict ko "$1-$2: la sessione è fallita"
  handson::finish
}

main() {
  local ws="${1:-}" n t rc=0
  [[ -n "${ws}" && -d "${ws}" ]] \
    || handson::die "spazio di lavoro assente: ${ws}"
  cd -- "${ws}" || handson::die "lo spazio di lavoro ${ws} non si apre"
  precondizioni
  export PN_HANDSON_ROOT="${RADICE}"
  handson::tmpdir DEPOSITO
  handson::tmpdir COPIE
  handson::banner "${ELEMENTO}" \
    "Una modifica a sessione avviata, e dopo /compact" \
    "Modulo 6, «Il budget del contesto»"
  for (( n = 1; n <= ${PN_ESECUZIONI:-1}; n++ )); do
    for t in "${TIPI[@]}"; do
      una_sessione "${t}" "${n}"
    done
  done
  handson::step "Gli stream, i registri e i passi in risposte/"
  consegna
  handson::step "Il controllo"
  handson::run python3 -B -I controlla_sessione.py "$(pwd -P)" \
    < /dev/null || rc=$?
  handson::verdict_rc "${rc}" "le garanzie, sugli stream di risposte/"
  handson::finish
}

main "$@"
