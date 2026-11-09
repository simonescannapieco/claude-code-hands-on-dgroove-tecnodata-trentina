#!/bin/bash
#
# in_classe.sh -- M7-D06 «Tre brani, una risposta con la fonte», dal vivo: le
# stesse due domande (casi/) in due versioni dell'assistente che differiscono
# in una frase del system prompt, il permesso di dire «non lo so»:
#   con-permesso    la frase c'è (con-permesso/system-prompt.md);
#   senza-permesso  la frase non c'è (senza-permesso/system-prompt.md).
# Ogni esecuzione è un giro del banco di prova, prova.py casi, con le sue
# due chiamate di claude -p (Sonnet, effort low, nessuno strumento integrato,
# il solo server MCP del banco con la ricerca cerca_kb, sui tre brani di kb/,
# l'uscita strutturata di schema.json); le due domande di ogni giro girano
# insieme. Lo fa il banco: ambiente ripulito, niente chiavi API, permessi
# dontAsk con i soli strumenti del server. Ogni comando si vede prima di
# girare (handson::run). Le esecuzioni vanno in risposte/<braccio>-<n>/ e
# controlla_fonti.py stampa le domande, i brani, i campi e il confronto.
#
# Uso:    <cartella dell'elemento>/demo/in_classe.sh <spazio di lavoro>
#           lo spazio di lavoro appena preparato (tools/prepara_esercizio.sh
#           M7-D06), con git status pulito e senza risposte/
# Env:    PN_ESECUZIONI    quante esecuzioni per braccio, da 1 a 9 (default 1)
#         PN_HANDSON_ROOT  il repository (default: dal percorso di questo
#                          file; dalla copia nello spazio di lavoro va data)
#         TMPDIR           dove il banco crea le sue cartelle temporanee
#         le variabili di tools/lib_handson.sh (HANDSON_NO_PAUSE, …)
# Uscita: 0 = ogni chiamata è finita e il controllo ha letto le esecuzioni ·
#         1 = una chiamata fallita, o il controllo che chiede di rifare la
#         prova · 2 = precondizione, anche del banco o del controllo
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
# lo script sta in <radice>/m7_…/s6_…/m7_6_…/M7-D06_…/demo/
readonly RADICE="${PN_HANDSON_ROOT:-${SELF%/*/*/*/*/*/*}}"
[[ -f "${RADICE}/tools/lib_handson.sh" ]] || { echo "in_classe.sh: non" \
  "trovo tools/lib_handson.sh in ${RADICE}: lanciatelo dal repository, o" \
  "date PN_HANDSON_ROOT" >&2; exit 2; }
# shellcheck source=../../../../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"

readonly ELEMENTO=M7-D06
readonly BANCO=progetti/assistenza-clienti/banco/prova.py
readonly BRACCI=(con-permesso senza-permesso)
readonly NECESSARI=("${BANCO}" controlla_fonti.py schema.json
  con-permesso/system-prompt.md con-permesso/strumenti.json
  senza-permesso/system-prompt.md senza-permesso/strumenti.json
  casi/caso-1-coperta.json casi/caso-2-non-coperta.json
  kb/kb-90-router-comodato-guasto.md kb/kb-91-router-fine-contratto.md
  kb/kb-92-presa-ottica.md)
readonly ESECUZIONI="${PN_ESECUZIONI:-1}"

# Un giro del banco, un braccio per un'esecuzione. Globals: nessuna.
# Arguments: $1 il braccio, $2 il numero dell'esecuzione.
# Returns: l'uscita del banco.
un_giro() {
  handson::step "$1-$2: le due domande, ${1/-/ }"
  handson::run python3 -B -I "${BANCO}" casi --versione "$1" --casi casi \
    --kb kb --schema schema.json --uscita "risposte/$1-$2" < /dev/null
}

# Le precondizioni, prima di ogni chiamata. Va chiamata nello spazio di lavoro.
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
  [[ ! -e risposte && -z "${stato}" ]] \
    || handson::die "lo spazio di lavoro non è al punto di partenza (c'è" \
      "risposte/, o git status non è vuoto): tools/reset_esercizio.sh" \
      "${ELEMENTO}"
  [[ "${ESECUZIONI}" =~ ^[1-9]$ ]] \
    || handson::die "PN_ESECUZIONI: da 1 a 9, non «${ESECUZIONI}»"
  handson::need_claude
}

main() {
  local ws="${1:-}" braccio n rc=0
  [[ -n "${ws}" && -d "${ws}" ]] \
    || handson::die "spazio di lavoro assente: ${ws}"
  cd -- "${ws}" || handson::die "lo spazio di lavoro ${ws} non si apre"
  precondizioni
  handson::banner "${ELEMENTO}" "Tre brani, una risposta con la fonte" \
    "Modulo 7, la conoscenza: il permesso di dire «non lo so»"
  handson::pause "fare le chiamate"
  for (( n = 1; n <= ESECUZIONI; n++ )); do
    for braccio in "${BRACCI[@]}"; do
      un_giro "${braccio}" "${n}" || rc=$?
      if (( rc != 0 )); then
        handson::verdict_rc "${rc}" "${braccio}-${n}: il banco di prova"
        handson::finish
      fi
    done
  done
  handson::step "Le domande, i brani, i campi e il confronto"
  export PN_HANDSON_ROOT="${RADICE}"
  handson::run python3 -B -I controlla_fonti.py risposte < /dev/null || rc=$?
  handson::verdict_rc "${rc}" "il controllo, sulle esecuzioni di risposte/"
  handson::finish
}

main "$@"
