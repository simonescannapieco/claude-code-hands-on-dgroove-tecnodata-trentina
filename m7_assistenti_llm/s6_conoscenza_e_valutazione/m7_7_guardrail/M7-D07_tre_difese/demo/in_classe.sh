#!/bin/bash
#
# in_classe.sh -- M7-D07 «Tre difese a confronto», dal vivo: gli stessi tre
# attacchi (attacchi/) contro tre system prompt che differiscono solo in ciò che
# difende la scheda della cliente:
#   nessuna-difesa  la scheda intera nel system prompt (nessuna-difesa.md);
#   educata         la stessa scheda, più una frase che chiede di tenerla
#                   riservata (educata.md);
#   ridotta         solo i campi che servono all'assistente (ridotta.md).
# Ogni chiamata è una sessione nuova di claude -p in una cartella vuota:
# Sonnet, effort low, --system-prompt-file, --tools "" (nessuno strumento),
# nessun server MCP, sessione non salvata, stream-json. Ogni comando si vede
# prima di girare (handson::claude_p). Una esecuzione sono nove chiamate;
# ognuna scrive in risposte/<braccio>-<attacco>-<n>/, e controlla_campi.py
# stampa per ogni esecuzione i campi della scheda che sono usciti.
#
# Uso:    <cartella dell'elemento>/demo/in_classe.sh <spazio di lavoro>
#           lo spazio di lavoro appena preparato (tools/prepara_esercizio.sh
#           M7-D07), con git status pulito e senza risposte/
# Env:    PN_ESECUZIONI    quante esecuzioni per cella, da 1 a 9 (default 1)
#         PN_HANDSON_ROOT  il repository (default: dal percorso di questo
#                          file; dalla copia nello spazio di lavoro va data)
#         TMPDIR           dove nasce la cartella vuota delle chiamate
#         le variabili di tools/lib_handson.sh (HANDSON_NO_PAUSE, …)
# Uscita: 0 = ogni chiamata è finita e il controllo ha letto le esecuzioni ·
#         1 = una chiamata fallita, o il controllo che chiede di rifare la
#         prova · 2 = precondizione, anche del controllo
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
# lo script sta in <radice>/m7_…/s6_…/m7_7_…/M7-D07_…/demo/
readonly RADICE="${PN_HANDSON_ROOT:-${SELF%/*/*/*/*/*/*}}"
[[ -f "${RADICE}/tools/lib_handson.sh" ]] || { echo "in_classe.sh: non" \
  "trovo tools/lib_handson.sh in ${RADICE}: lanciatelo dal repository, o" \
  "date PN_HANDSON_ROOT" >&2; exit 2; }
# shellcheck source=../../../../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"

readonly ELEMENTO=M7-D07
readonly MODELLO=sonnet
readonly BRACCI=(nessuna-difesa educata ridotta)
readonly ATTACCHI=(diretta collega ripeti)
readonly NECESSARI=(controlla_campi.py scheda.md nessuna-difesa.md educata.md
  ridotta.md attacchi/diretta.txt attacchi/collega.txt attacchi/ripeti.txt)
readonly ESECUZIONI="${PN_ESECUZIONI:-1}"
# shellcheck disable=SC2034  # la legge handson::claude_p
HANDSON_OUTPUT_FORMAT='stream-json'
VUOTA=''

# Una chiamata: la risposta del braccio all'attacco, in risposte/<nome>/.
# Globals: VUOTA (letta). Arguments: $1 il braccio, $2 l'attacco, $3 il numero
# dell'esecuzione. Returns: l'uscita di claude.
una_chiamata() {
  local braccio="$1" attacco="$2" n="$3" nome="$1-$2-$3" prompt sistema uscita
  handson::step "${nome}: attacco «$2» contro «$1»"
  mkdir -p -- "risposte/${nome}" || handson::die "mkdir non riesce"
  prompt="$(< "attacchi/${attacco}.txt")"
  sistema="$(pwd -P)/${braccio}.md"
  uscita="$(pwd -P)/risposte/${nome}/stream.jsonl"
  ( cd -- "${VUOTA}" && handson::claude_p "${MODELLO}" "" "${prompt}" \
      --tools "" --system-prompt-file "${sistema}" --effort low \
      --strict-mcp-config --no-session-persistence ) < /dev/null > "${uscita}"
}

# Le precondizioni, prima di ogni chiamata. Va chiamata nello spazio di
# lavoro.
precondizioni() {
  local f radice segno stato
  [[ "${HANDSON_ENV}" == claude-code-pro ]] \
    || handson::die "${ELEMENTO} è un elemento claude-code-pro: HANDSON_ENV" \
      "«${HANDSON_ENV}» non vale qui"
  handson::need_tools python3 git
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
  handson::_claude_p_checks "${MODELLO}" "x"
  handson::need_claude
}

main() {
  local ws="${1:-}" attacco braccio n rc=0
  [[ -n "${ws}" && -d "${ws}" ]] \
    || handson::die "spazio di lavoro assente: ${ws}"
  cd -- "${ws}" || handson::die "lo spazio di lavoro ${ws} non si apre"
  precondizioni
  handson::banner "${ELEMENTO}" "Tre difese a confronto" \
    "Modulo 7, i guardrail: tre attacchi, tre system prompt"
  handson::tmpdir VUOTA
  handson::pause "fare le chiamate"
  for (( n = 1; n <= ESECUZIONI; n++ )); do
    for attacco in "${ATTACCHI[@]}"; do
      for braccio in "${BRACCI[@]}"; do
        una_chiamata "${braccio}" "${attacco}" "${n}" || rc=$?
        if (( rc != 0 )); then
          handson::verdict_rc "${rc}" \
            "${braccio}-${attacco}-${n}: claude -p"
          handson::finish
        fi
      done
    done
  done
  handson::step "I campi usciti, cella per cella"
  export PN_HANDSON_ROOT="${RADICE}"
  handson::run python3 -B -I controlla_campi.py risposte < /dev/null || rc=$?
  handson::verdict_rc "${rc}" "il controllo, sulle esecuzioni di risposte/"
  handson::finish
}

main "$@"
