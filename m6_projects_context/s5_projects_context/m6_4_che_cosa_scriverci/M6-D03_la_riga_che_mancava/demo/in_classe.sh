#!/bin/bash
#
# in_classe.sh -- M6-D03 «Il comando dei test: Claude andrebbe a cercarlo?», dal
# vivo: la stessa richiesta (richiesta.txt) in due bracci, ognuno in una copia
# nuova dello spazio di lavoro, in una cartella temporanea, con un solo
# commit e senza vendor/, così ogni esecuzione parte dal primo composer
# install:
#   senza  il gestionale (progetti/gestionale-php), tools/php.sh e .claude/;
#   con    lo stesso, con il CLAUDE.md di con-la-riga/ nella cartella del
#          gestionale: quattro righe, il comando dei test.
# Prima le esecuzioni senza, poi quelle con; ogni copia sparisce appena la sua
# chiamata è finita. Ogni chiamata parte da progetti/gestionale-php, in una
# sessione nuova di claude -p che non resta salvata: Sonnet, effort low, Read,
# Glob, Grep e Bash, Bash consentito per intero nella copia usa e getta, meno
# sudo, git push, curl e wget; nessun server MCP, la auto memory spenta,
# stream-json. Ogni comando si vede prima di girare (handson::claude_p).
# Gli stream stanno in una cartella temporanea finché le chiamate non sono
# finite; poi vanno in risposte/, una cartella per esecuzione, e
# controlla_comandi.py stampa i comandi, la suite e la coppia.
#
# Uso:    <cartella dell'elemento>/demo/in_classe.sh <spazio di lavoro>
#           lo spazio di lavoro appena preparato (tools/prepara_esercizio.sh
#           M6-D03), con git status pulito e senza risposte/
# Env:    PN_ESECUZIONI    quante esecuzioni per braccio, da 1 a 9 (default 1)
#         PN_HANDSON_ROOT  il repository (default: dal percorso di questo
#                          file; dalla copia nello spazio di lavoro va data)
#         TMPDIR           dove nascono le copie e il deposito degli stream
#         le variabili di tools/lib_handson.sh (HANDSON_NO_PAUSE, …)
# Uscita: 0 = ogni chiamata è finita e il controllo ha letto le esecuzioni ·
#         1 = una chiamata fallita, o il controllo che chiede di rifare la
#         prova · 2 = precondizione, anche del controllo
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
# lo script sta in <radice>/m6_…/s5_…/m6_4_…/M6-D03_…/demo/
readonly RADICE="${PN_HANDSON_ROOT:-${SELF%/*/*/*/*/*/*}}"
[[ -f "${RADICE}/tools/lib_handson.sh" ]] || { echo "in_classe.sh: non" \
  "trovo tools/lib_handson.sh in ${RADICE}: lanciatelo dal repository, o" \
  "date PN_HANDSON_ROOT" >&2; exit 2; }
# shellcheck source=../../../../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"

readonly ELEMENTO=M6-D03
readonly MODELLO=sonnet
readonly STRUMENTI='Read,Glob,Grep,Bash'
readonly VIETATI='Bash(sudo *),Bash(git push *),Bash(curl *),Bash(wget *)'
readonly GESTIONALE=progetti/gestionale-php
readonly BRACCI=(senza con)
readonly NECESSARI=(richiesta.txt con-la-riga/CLAUDE.md tools/php.sh
  "${GESTIONALE}/composer.json" .claude/settings.json controlla_comandi.py)
readonly ESECUZIONI="${PN_ESECUZIONI:-1}"
# shellcheck disable=SC2034  # la legge handson::claude_p
HANDSON_OUTPUT_FORMAT='stream-json'
DEPOSITO=''
COPIE=''
COPIA=''
RICHIESTA=''

# Gli stream in risposte/ dello spazio di lavoro (la cartella corrente).
# Globals: DEPOSITO.
consegna() {
  mkdir -p risposte || handson::die "non riesco a creare risposte/"
  handson::run cp -R -- "${DEPOSITO}/." risposte/ < /dev/null \
    || handson::die "non riesco a copiare gli stream in risposte/"
}

# La copia di un braccio: progetti/, tools/ e .claude/ del commit di partenza
# (niente vendor/), nel braccio con anche il CLAUDE.md del gestionale; un
# repository git con un commit. Globals: COPIE; COPIA (assegnata).
# Arguments: $1 il braccio, $2 il nome dell'esecuzione.
nuova_copia() {
  COPIA="${COPIE}/$2"
  if ! mkdir -- "${COPIA}" || ! git archive --format=tar HEAD -- progetti \
      tools .claude | tar -x -C "${COPIA}"; then
    handson::die "non riesco a copiare lo spazio di lavoro in ${COPIA}"
  fi
  if [[ "$1" == con ]] && ! cp -- con-la-riga/CLAUDE.md \
      "${COPIA}/${GESTIONALE}/CLAUDE.md"; then
    handson::die "non riesco a mettere il CLAUDE.md in ${COPIA}"
  fi
  handson::git_init_workspace "${COPIA}" "${ELEMENTO}" \
    || handson::die "git non riesce a fare il repository di ${COPIA}"
}

# Un'esecuzione: la copia, la chiamata dalla cartella del gestionale, lo
# stream nel deposito, la copia tolta (solo sotto COPIE). Se claude fallisce:
# risposte/ con ciò che c'è e uscita 1. Globals: DEPOSITO, COPIA, RICHIESTA.
# Arguments: $1 il braccio, $2 il numero.
una_esecuzione() {
  local nome="$1-$2" quale='senza CLAUDE.md'
  [[ "$1" == senza ]] || quale='con il CLAUDE.md di quattro righe'
  handson::step "${nome}: la richiesta, ${quale}"
  nuova_copia "$1" "${nome}"
  mkdir -- "${DEPOSITO}/${nome}" || handson::die "mkdir non riesce"
  if ! ( cd -- "${COPIA}/${GESTIONALE}" && handson::claude_p "${MODELLO}" \
      "${STRUMENTI}" "${RICHIESTA}" --tools "${STRUMENTI}" \
      --disallowedTools "${VIETATI}" --effort low --strict-mcp-config \
      --no-session-persistence ) < /dev/null \
      > "${DEPOSITO}/${nome}/stream.jsonl"; then
    consegna
    handson::verdict ko "${nome}: claude -p è fallito"
    handson::finish
  fi
  if [[ "${COPIA}" == "${COPIE}/"?* && ! -L "${COPIA}" ]]; then
    rm -rf -- "${COPIA}" || handson::note "non riesco a togliere ${COPIA}"
  fi
}

# Le precondizioni, prima di ogni chiamata. Va chiamata nello spazio di
# lavoro. Globals: RICHIESTA (assegnata).
precondizioni() {
  local f radice segno stato
  [[ "${HANDSON_ENV}" == claude-code-pro ]] \
    || handson::die "${ELEMENTO} è un elemento claude-code-pro: HANDSON_ENV" \
      "«${HANDSON_ENV}» non vale qui"
  handson::need_tools python3 git tar
  command -v php > /dev/null 2>&1 || command -v docker > /dev/null 2>&1 \
    || handson::die "servono PHP 8.3 o Docker (tools/verifica_ambiente.sh)"
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
  RICHIESTA="$(< richiesta.txt)"
  handson::_claude_p_checks "${MODELLO}" "${RICHIESTA}"
  handson::_claude_key_ok "${RICHIESTA}"
  handson::need_claude
}

main() {
  local ws="${1:-}" braccio n rc=0
  [[ -n "${ws}" && -d "${ws}" ]] \
    || handson::die "spazio di lavoro assente: ${ws}"
  cd -- "${ws}" || handson::die "lo spazio di lavoro ${ws} non si apre"
  precondizioni
  handson::banner "${ELEMENTO}" \
    "Il comando dei test: Claude andrebbe a cercarlo?" \
    "Modulo 6, «Che cosa scriverci, e che cosa no»"
  handson::tmpdir DEPOSITO
  handson::tmpdir COPIE
  export CLAUDE_CODE_DISABLE_AUTO_MEMORY=1
  handson::note "CLAUDE_CODE_DISABLE_AUTO_MEMORY=1: la auto memory è spenta"
  handson::pause "fare le chiamate"
  for braccio in "${BRACCI[@]}"; do
    for (( n = 1; n <= ESECUZIONI; n++ )); do
      una_esecuzione "${braccio}" "${n}"
    done
  done
  handson::step "Gli stream nello spazio di lavoro, a sessioni finite"
  consegna
  handson::step "I comandi, la suite e la coppia"
  export PN_HANDSON_ROOT="${RADICE}"
  handson::run python3 -B -I controlla_comandi.py risposte < /dev/null \
    || rc=$?
  handson::verdict_rc "${rc}" "il controllo, sulle esecuzioni di risposte/"
  handson::finish
}

main "$@"
