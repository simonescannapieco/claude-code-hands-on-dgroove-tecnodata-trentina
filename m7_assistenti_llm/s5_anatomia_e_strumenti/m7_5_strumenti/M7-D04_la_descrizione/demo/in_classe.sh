#!/bin/bash
#
# in_classe.sh -- M7-D04 «La descrizione è il contratto», dal vivo: due versioni
# dello stesso assistente, che differiscono soltanto nelle definizioni degli
# strumenti. Stesso system prompt breve, stesso messaggio di una cliente che dà
# codice e recapito, stessi dati di uno scenario; in vaga/ le definizioni nello
# stile del v0 (nomi e descrizioni vaghe), in chiara/ nomi chiari e descrizioni
# molto dettagliate; le capacità sono le stesse. Ogni versione fa il caso con
# prova.py del banco (progetti/assistenza-clienti/banco/ dello spazio di
# lavoro): una chiamata di claude -p, il server MCP del banco, nessuno strumento
# integrato, Sonnet, effort low. Gli esiti vanno in risposte/<versione>-<n>/ e
# controlla_descrizioni.py confronta le due versioni, esecuzione per esecuzione.
#
# Uso:    <cartella dell'elemento>/demo/in_classe.sh <spazio di lavoro>
#           lo spazio di lavoro appena preparato (tools/prepara_esercizio.sh
#           M7-D04), con git status pulito e senza risposte/
# Env:    PN_ESECUZIONI    quante esecuzioni per versione, da 1 a 9 (default 1)
#         PN_HANDSON_ROOT  il repository (default: dal percorso di questo
#                          file; dalla copia nello spazio di lavoro va data)
#         le variabili di tools/lib_handson.sh (HANDSON_NO_PAUSE, …)
# Uscita: 0 = ogni chiamata è finita e il controllo ha letto le esecuzioni ·
#         1 = una chiamata non finita, o il controllo che chiede di rifare la
#         prova · 2 = precondizione
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
# lo script sta in <radice>/m7_…/s5_…/m7_5_…/M7-D04_…/demo/
readonly RADICE="${PN_HANDSON_ROOT:-${SELF%/*/*/*/*/*/*}}"
[[ -f "${RADICE}/tools/lib_handson.sh" ]] || { echo "in_classe.sh: non" \
  "trovo tools/lib_handson.sh in ${RADICE}: lanciatelo dal repository, o" \
  "date PN_HANDSON_ROOT" >&2; exit 2; }
# shellcheck source=../../../../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"

readonly ELEMENTO=M7-D04
readonly BANCO=progetti/assistenza-clienti/banco
readonly RISPOSTE=risposte
readonly BRACCI=(vaga chiara)
readonly NECESSARI=(vaga/system-prompt.md vaga/strumenti.json
  chiara/system-prompt.md chiara/strumenti.json casi/linea-guasta.json
  controlla_descrizioni.py "${BANCO}/prova.py" .claude/settings.json)
readonly ESECUZIONI="${PN_ESECUZIONI:-1}"

# Una esecuzione di una versione: il caso, una chiamata, con prova.py del
# banco. Un'uscita 2 di prova.py è una precondizione.
# Arguments: $1 la versione (vaga o chiara), $2 il numero dell'esecuzione.
una_esecuzione() {
  local rc=0
  handson::step "$1-$2: il messaggio della cliente, con le definizioni di $1/"
  handson::run python3 -B -I "${BANCO}/prova.py" casi --versione "$1" \
    --casi casi --uscita "${RISPOSTE}/$1-$2" < /dev/null || rc=$?
  if (( rc == 2 )); then
    handson::die "prova.py: una precondizione del banco (vedi sopra)"
  fi
  if (( rc != 0 )); then
    handson::verdict ko "$1-$2: la chiamata non è finita"
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
  local ws="${1:-}" braccio n rc=0
  [[ -n "${ws}" && -d "${ws}" ]] \
    || handson::die "spazio di lavoro assente: ${ws}"
  cd -- "${ws}" || handson::die "lo spazio di lavoro ${ws} non si apre"
  precondizioni
  handson::banner "${ELEMENTO}" "La descrizione è il contratto" \
    "Modulo 7, «Strumenti: il modello chiede, il codice esegue»"
  handson::pause "fare le chiamate"
  for braccio in "${BRACCI[@]}"; do
    for (( n = 1; n <= ESECUZIONI; n++ )); do
      una_esecuzione "${braccio}" "${n}"
    done
  done
  handson::step "Le due versioni a confronto: il controllo"
  export PN_HANDSON_ROOT="${RADICE}"
  handson::run python3 -B -I controlla_descrizioni.py "${RISPOSTE}" \
    < /dev/null || rc=$?
  handson::verdict_rc "${rc}" "il controllo, sulle esecuzioni di ${RISPOSTE}/"
  handson::finish
}

main "$@"
