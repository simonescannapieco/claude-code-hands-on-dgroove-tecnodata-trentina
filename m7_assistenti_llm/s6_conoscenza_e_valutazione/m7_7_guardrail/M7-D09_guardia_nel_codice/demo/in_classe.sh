#!/bin/bash
#
# in_classe.sh -- M7-D09 «La guardia nel codice», dal vivo: le garanzie di
# Claude Code che non dipendono dal modello, ognuna in un suo braccio, ogni
# esecuzione una copia nuova della cartella con il suo .claude/settings.json
# (bracci/<braccio>.json, i tre hook di hook/ sotto .claude/hooks/), con
# claude -p, il server MCP del banco di prova (scenario SC-01, gli strumenti
# di strumenti.json), Sonnet con effort low:
#   divieto-nel-prompt  il divieto solo nel system prompt (nessuna regola);
#   regola-deny         la regola deny in .claude/settings.json, nessun
#                       divieto nel prompt;
#   hook-pre            un hook PreToolUse che esce 2 (blocca_accredito.sh),
#                       con la regola allow di --allowedTools;
#   hook-post           un hook PostToolUse con updatedToolOutput
#                       (maschera_telefono.py) sulla scheda del cliente;
#   hook-prompt         un hook UserPromptSubmit che esce 2 (blocca_prompt.sh).
# Ogni esecuzione: lo stream e il registro del server in risposte/<braccio>-<n>/.
# Poi controlla_guardia.py decide ogni garanzia dai file della corsa: una
# garanzia che non tiene esce 1, per nome. Ogni comando si vede prima di girare.
#
# Uso:    <cartella dell'elemento>/demo/in_classe.sh <spazio di lavoro>
#           lo spazio di lavoro appena preparato (tools/prepara_esercizio.sh
#           M7-D09), con git status pulito e senza risposte/
# Env:    PN_ESECUZIONI    quante esecuzioni per braccio, da 1 a 9 (default 1)
#         PN_HANDSON_ROOT  il repository (default: dal percorso di questo
#                          file; dalla copia nello spazio di lavoro va data)
#         TMPDIR           dove nascono le copie e il deposito degli stream
#         le variabili di tools/lib_handson.sh (HANDSON_NO_PAUSE, …)
# Uscita: 0 = ogni chiamata è finita e ogni garanzia tiene · 1 = una chiamata
#         fallita, o una garanzia che non tiene · 2 = precondizione, anche del
#         controllo
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
# lo script sta in <radice>/m7_…/s6_…/m7_7_guardrail/M7-D09_…/demo/
readonly RADICE="${PN_HANDSON_ROOT:-${SELF%/*/*/*/*/*/*}}"
[[ -f "${RADICE}/tools/lib_handson.sh" ]] || { echo "in_classe.sh: non" \
  "trovo tools/lib_handson.sh in ${RADICE}: lanciatelo dal repository, o" \
  "date PN_HANDSON_ROOT" >&2; exit 2; }
# shellcheck source=../../../../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"
# shellcheck source=lib_guardia.sh
source "${SELF%/*}/lib_guardia.sh"

readonly ELEMENTO=M7-D09
readonly MODELLO=sonnet
readonly STRUMENTI='mcp__assistenza__*'
readonly BRACCI=(divieto-nel-prompt regola-deny hook-pre hook-post hook-prompt)
readonly SERVER=progetti/assistenza-clienti/banco/server
readonly SCENARIO=progetti/assistenza-clienti/scenari/sc-01-fibra-assente-guasto-pergine.json
readonly KB=progetti/assistenza-clienti/kb
readonly NECESSARI=(strumenti.json system-prompt.md system-prompt-divieto.md
  richiesta-accredito.txt richiesta-scheda.txt richiesta-bloccata.txt
  hook/blocca_accredito.sh hook/blocca_prompt.sh hook/maschera_telefono.py
  bracci/divieto-nel-prompt.json bracci/regola-deny.json bracci/hook-pre.json
  bracci/hook-post.json bracci/hook-prompt.json controlla_guardia.py
  "${SERVER}/server_banco.py" "${SCENARIO}" .claude/settings.json
  lib_guardia.sh)
readonly ESECUZIONI="${PN_ESECUZIONI:-1}"
# Lo stesso ambiente del server che usa prova.py: fuori dal repository, si
# riusa fra gli spazi di lavoro.
readonly AMBIENTE_UV="${HOME}/.cache/corso-claude-code/banco-server"
# shellcheck disable=SC2034  # la legge handson::claude_p
HANDSON_OUTPUT_FORMAT='stream-json'
WS=''
DEPOSITO=''
COPIE=''
COPIA=''

# Gli stream e i registri in risposte/ dello spazio di lavoro (la cartella
# corrente). Globals: DEPOSITO.
consegna() {
  mkdir -p risposte || handson::die "non riesco a creare risposte/"
  handson::run cp -R -- "${DEPOSITO}/." risposte/ < /dev/null \
    || handson::die "non riesco a copiare gli stream in risposte/"
}

# Un'esecuzione: la copia, il server con il suo registro, la chiamata dalla
# copia, lo stream nel deposito, la copia tolta. Se claude fallisce: risposte/
# con ciò che c'è e uscita 1. Globals: DEPOSITO, COPIA, WS.
# Arguments: $1 il braccio, $2 il numero.
una_esecuzione() {
  local braccio="$1" nome="$1-$2" sp cfg richiesta
  handson::step "${nome}"
  nuova_copia "${braccio}" "${nome}"
  mkdir -- "${DEPOSITO}/${nome}" || handson::die "mkdir non riesce"
  cfg="${DEPOSITO}/${nome}/mcp.json"
  scrivi_mcp "${cfg}" "${DEPOSITO}/${nome}/registro.jsonl" \
    || handson::die "non riesco a scrivere la configurazione MCP"
  sp="${WS}/$(system_di "${braccio}")"
  richiesta="$(< "${WS}/$(richiesta_di "${braccio}")")"
  if ! ( cd -- "${COPIA}" && handson::claude_p "${MODELLO}" "${STRUMENTI}" \
      "${richiesta}" --tools "" --mcp-config "${cfg}" --strict-mcp-config \
      --effort low --no-session-persistence --system-prompt-file "${sp}" ) \
      < /dev/null > "${DEPOSITO}/${nome}/stream.jsonl"; then
    rm -f -- "${cfg}"
    consegna
    handson::verdict ko "${nome}: claude -p è fallito"
    handson::finish
  fi
  rm -f -- "${cfg}"
  if [[ "${COPIA}" == "${COPIE}/"?* && ! -L "${COPIA}" ]]; then
    rm -rf -- "${COPIA}" || handson::note "non riesco a togliere ${COPIA}"
  fi
}

# Le precondizioni, prima di ogni chiamata. Va chiamata nello spazio di
# lavoro. Globals: WS (assegnata).
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
  WS="$(pwd -P)"
}

main() {
  local ws="${1:-}" braccio n rc=0
  [[ -n "${ws}" && -d "${ws}" ]] \
    || handson::die "spazio di lavoro assente: ${ws}"
  cd -- "${ws}" || handson::die "lo spazio di lavoro ${ws} non si apre"
  precondizioni
  handson::banner "${ELEMENTO}" "La guardia nel codice" \
    "Modulo 7, «I guardrail»"
  handson::tmpdir DEPOSITO
  handson::tmpdir COPIE
  handson::step "L'ambiente del server del banco, una volta sola"
  handson::run env UV_PROJECT_ENVIRONMENT="${AMBIENTE_UV}" \
    uv sync --frozen --quiet --directory "${WS}/${SERVER}" < /dev/null \
    || handson::die "il server del banco non si prepara"
  handson::pause "fare le chiamate"
  for braccio in "${BRACCI[@]}"; do
    for (( n = 1; n <= ESECUZIONI; n++ )); do
      una_esecuzione "${braccio}" "${n}"
    done
  done
  handson::step "Gli stream e i registri nello spazio di lavoro"
  consegna
  handson::step "Le garanzie, dai file delle esecuzioni"
  handson::run python3 -B -I controlla_guardia.py risposte < /dev/null \
    || rc=$?
  handson::verdict_rc "${rc}" "il controllo delle garanzie, su risposte/"
  handson::finish
}

main "$@"
