#!/bin/bash
#
# in_classe.sh -- M6-D01 «Il documento che nessun modello ha letto», dal vivo:
# la stessa domanda (domanda.txt) in due bracci, ognuno in una copia nuova
# dello spazio di lavoro, in una cartella temporanea, con un solo commit:
#   senza  la cartella senza la carta dei servizi: c'è solo .claude/;
#   con    la stessa cartella con il CLAUDE.md di con-la-carta/, che importa
#          docs/carta-servizi.md, la carta (carta-servizi.md).
# Prima le esecuzioni senza, poi quelle con; ogni copia sparisce appena la sua
# chiamata è finita. Ogni chiamata è una sessione nuova di claude -p, che non
# resta salvata: Sonnet, effort low, gli stessi strumenti di lettura (Read,
# Glob, Grep) nei due bracci, nessun server MCP, la auto memory spenta,
# stream-json. Ogni comando si vede prima di girare (handson::claude_p).
# Gli stream stanno in una cartella temporanea finché le chiamate non sono
# finite; poi vanno in risposte/, una cartella per esecuzione, e
# controlla_documento.py stampa le esecuzioni, le citazioni e la coppia.
#
# Uso:    <cartella dell'elemento>/demo/in_classe.sh <spazio di lavoro>
#           lo spazio di lavoro appena preparato (tools/prepara_esercizio.sh
#           M6-D01), con git status pulito e senza risposte/
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
# lo script sta in <radice>/m6_…/s5_…/m6_2_…/M6-D01_…/demo/
readonly RADICE="${PN_HANDSON_ROOT:-${SELF%/*/*/*/*/*/*}}"
[[ -f "${RADICE}/tools/lib_handson.sh" ]] || { echo "in_classe.sh: non" \
  "trovo tools/lib_handson.sh in ${RADICE}: lanciatelo dal repository, o" \
  "date PN_HANDSON_ROOT" >&2; exit 2; }
# shellcheck source=../../../../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"

readonly ELEMENTO=M6-D01
readonly MODELLO=sonnet
readonly STRUMENTI='Read,Glob,Grep'
readonly BRACCI=(senza con)
readonly NECESSARI=(carta-servizi.md domanda.txt con-la-carta/CLAUDE.md
  .claude/settings.json controlla_documento.py)
readonly ESECUZIONI="${PN_ESECUZIONI:-1}"
# shellcheck disable=SC2034  # la legge handson::claude_p
HANDSON_OUTPUT_FORMAT='stream-json'
DEPOSITO=''
COPIE=''
COPIA=''
DOMANDA=''

# Gli stream in risposte/ dello spazio di lavoro (la cartella corrente).
# Globals: DEPOSITO.
consegna() {
  mkdir -p risposte || handson::die "non riesco a creare risposte/"
  handson::run cp -R -- "${DEPOSITO}/." risposte/ < /dev/null \
    || handson::die "non riesco a copiare gli stream in risposte/"
}

# La copia di un braccio: .claude/ del commit di partenza, nel braccio con
# anche CLAUDE.md e docs/carta-servizi.md; un repository git con un commit.
# Globals: COPIE; COPIA (assegnata). Arguments: $1 il braccio, $2 il nome.
nuova_copia() {
  COPIA="${COPIE}/$2"
  if ! mkdir -- "${COPIA}" || ! git archive --format=tar HEAD -- .claude \
      | tar -x -C "${COPIA}"; then
    handson::die "non riesco a copiare .claude/ in ${COPIA}"
  fi
  if [[ "$1" == con ]] && { ! mkdir -- "${COPIA}/docs" \
      || ! cp -- con-la-carta/CLAUDE.md "${COPIA}/CLAUDE.md" \
      || ! cp -- carta-servizi.md "${COPIA}/docs/carta-servizi.md"; }; then
    handson::die "non riesco a mettere la carta in ${COPIA}"
  fi
  handson::git_init_workspace "${COPIA}" "${ELEMENTO}" \
    || handson::die "git non riesce a fare il repository di ${COPIA}"
}

# Un'esecuzione: la copia, la chiamata dalla sua cartella, lo stream nel
# deposito, la copia tolta (solo sotto COPIE). Se claude fallisce: risposte/
# con ciò che c'è e uscita 1. Globals: DEPOSITO, COPIA, DOMANDA.
# Arguments: $1 il braccio, $2 il numero.
una_esecuzione() {
  local nome="$1-$2" quale='senza la carta'
  [[ "$1" == senza ]] || quale='con la carta, importata dal CLAUDE.md'
  handson::step "${nome}: la domanda, ${quale}"
  nuova_copia "$1" "${nome}"
  mkdir -- "${DEPOSITO}/${nome}" || handson::die "mkdir non riesce"
  if ! ( cd -- "${COPIA}" && handson::claude_p "${MODELLO}" "${STRUMENTI}" \
      "${DOMANDA}" --tools "${STRUMENTI}" --effort low --strict-mcp-config \
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
# lavoro. Globals: DOMANDA (assegnata).
precondizioni() {
  local f radice segno stato
  [[ "${HANDSON_ENV}" == claude-code-pro ]] \
    || handson::die "${ELEMENTO} è un elemento claude-code-pro: HANDSON_ENV" \
      "«${HANDSON_ENV}» non vale qui"
  handson::need_tools python3 git tar
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
  DOMANDA="$(< domanda.txt)"
  handson::_claude_p_checks "${MODELLO}" "${DOMANDA}"
  handson::_claude_key_ok "${DOMANDA}"
  handson::need_claude
}

main() {
  local ws="${1:-}" braccio n rc=0
  [[ -n "${ws}" && -d "${ws}" ]] \
    || handson::die "spazio di lavoro assente: ${ws}"
  cd -- "${ws}" || handson::die "lo spazio di lavoro ${ws} non si apre"
  precondizioni
  handson::banner "${ELEMENTO}" "Il documento che nessun modello ha letto" \
    "Modulo 6, «Perché il contesto è tutto»"
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
  handson::step "Le esecuzioni, le citazioni e la coppia"
  export PN_HANDSON_ROOT="${RADICE}"
  handson::run python3 -B -I controlla_documento.py risposte < /dev/null \
    || rc=$?
  handson::verdict_rc "${rc}" "il controllo, sulle esecuzioni di risposte/"
  handson::finish
}

main "$@"
