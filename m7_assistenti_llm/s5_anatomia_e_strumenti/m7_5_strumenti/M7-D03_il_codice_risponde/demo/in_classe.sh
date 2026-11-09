#!/bin/bash
#
# in_classe.sh -- M7-D03 «Il modello chiede, il codice risponde», dal vivo: il
# banco di prova, in piccolo. L'assistente (assistente/: un system prompt
# breve, uno strumento chiaro collegato alla capacità stato_linea) risponde a
# due messaggi, sui dati di uno scenario: una linea che esiste e una che non
# esiste (casi/). Ogni caso è una chiamata di claude -p, con il server MCP del
# banco, nessuno strumento integrato, Sonnet, effort low (lo fa prova.py del
# banco, nello spazio di lavoro: progetti/assistenza-clienti/banco/). Gli esiti
# vanno in risposte/run-<n>/ e controlla_mosse.py dice, chiamata per chiamata,
# che cosa il modello ha chiesto e che cosa il server ha risposto.
#
# Uso:    <cartella dell'elemento>/demo/in_classe.sh <spazio di lavoro>
#           lo spazio di lavoro appena preparato (tools/prepara_esercizio.sh
#           M7-D03), con git status pulito e senza risposte/
# Env:    PN_ESECUZIONI    quante volte i due casi, da 1 a 9 (default 1)
#         PN_HANDSON_ROOT  il repository (default: dal percorso di questo
#                          file; dalla copia nello spazio di lavoro va data)
#         le variabili di tools/lib_handson.sh (HANDSON_NO_PAUSE, …)
# Uscita: 0 = ogni chiamata è finita e il controllo ha confermato le garanzie ·
#         1 = una chiamata non finita o una garanzia che non vale ·
#         2 = precondizione
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
# lo script sta in <radice>/m7_…/s5_…/m7_5_…/M7-D03_…/demo/
readonly RADICE="${PN_HANDSON_ROOT:-${SELF%/*/*/*/*/*/*}}"
[[ -f "${RADICE}/tools/lib_handson.sh" ]] || { echo "in_classe.sh: non" \
  "trovo tools/lib_handson.sh in ${RADICE}: lanciatelo dal repository, o" \
  "date PN_HANDSON_ROOT" >&2; exit 2; }
# shellcheck source=../../../../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"

readonly ELEMENTO=M7-D03
readonly BANCO=progetti/assistenza-clienti/banco
readonly RISPOSTE=risposte
readonly NECESSARI=(assistente/system-prompt.md assistente/strumenti.json
  casi/linea-esistente.json casi/linea-inesistente.json controlla_mosse.py
  "${BANCO}/prova.py" .claude/settings.json)
readonly ESECUZIONI="${PN_ESECUZIONI:-1}"

# Una esecuzione: i due casi, una chiamata ciascuno, con prova.py del banco.
# Una chiamata non finita: risposte/ con ciò che c'è e uscita 1; un'uscita 2 di
# prova.py è una precondizione.
# Arguments: $1 il numero dell'esecuzione.
una_esecuzione() {
  local rc=0
  handson::step "Esecuzione $1: i due casi, una chiamata per caso"
  handson::run python3 -B -I "${BANCO}/prova.py" casi --versione assistente \
    --casi casi --uscita "${RISPOSTE}/run-$1" < /dev/null || rc=$?
  if (( rc == 2 )); then
    handson::die "prova.py: una precondizione del banco (vedi sopra)"
  fi
  if (( rc != 0 )); then
    handson::verdict ko "esecuzione $1: una chiamata non è finita"
    handson::finish
  fi
}

# Le precondizioni, prima di ogni chiamata. Va chiamata nello spazio di
# lavoro.
precondizioni() {
  local f radice segno stato
  [[ "${HANDSON_ENV}" == claude-code-pro ]] \
    || handson::die "${ELEMENTO} è un elemento claude-code-pro: HANDSON_ENV" \
      "«${HANDSON_ENV}» non vale qui"
  handson::need_tools python3 git uv
  radice="$(git rev-parse --show-toplevel 2> /dev/null)" || radice=''
  segno="$(git config --get corso.elemento 2> /dev/null)" || segno=''
  [[ "${radice}" == "$(pwd -P)" && "${segno}" == "${ELEMENTO}" ]] \
    || handson::die "$(pwd -P) non è lo spazio di lavoro di ${ELEMENTO}:" \
      "preparatelo con tools/prepara_esercizio.sh ${ELEMENTO}"
  for f in "${NECESSARI[@]}"; do handson::need_file "${f}"; done
  stato="$(git status --porcelain)" || handson::die "git status non riesce"
  [[ ! -e "${RISPOSTE}" && -z "${stato}" ]] \
    || handson::die "lo spazio di lavoro non è al punto di partenza (c'è" \
      "${RISPOSTE}/, o git status non è vuoto):" \
      "tools/reset_esercizio.sh ${ELEMENTO}"
  [[ "${ESECUZIONI}" =~ ^[1-9]$ ]] \
    || handson::die "PN_ESECUZIONI: da 1 a 9, non «${ESECUZIONI}»"
  handson::need_claude
}

main() {
  local ws="${1:-}" n rc=0
  [[ -n "${ws}" && -d "${ws}" ]] \
    || handson::die "spazio di lavoro assente: ${ws}"
  cd -- "${ws}" || handson::die "lo spazio di lavoro ${ws} non si apre"
  precondizioni
  handson::banner "${ELEMENTO}" "Il modello chiede, il codice risponde" \
    "Modulo 7, «Strumenti: il modello chiede, il codice esegue»"
  handson::pause "fare le chiamate"
  for (( n = 1; n <= ESECUZIONI; n++ )); do
    una_esecuzione "${n}"
  done
  handson::step "Chi ha chiesto, chi ha risposto: il controllo"
  export PN_HANDSON_ROOT="${RADICE}"
  handson::run python3 -B -I controlla_mosse.py "${RISPOSTE}" < /dev/null \
    || rc=$?
  handson::verdict_rc "${rc}" "il controllo, sulle esecuzioni di ${RISPOSTE}/"
  handson::finish
}

main "$@"
