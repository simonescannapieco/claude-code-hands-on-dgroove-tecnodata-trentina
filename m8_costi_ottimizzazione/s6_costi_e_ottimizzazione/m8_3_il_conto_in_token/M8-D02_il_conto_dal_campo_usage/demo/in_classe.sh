#!/bin/bash
#
# in_classe.sh -- M8-D02 «Il conto dal campo usage», dal vivo. Prima /context,
# che mostra di che cosa è fatto il contesto (e non è una chiamata al modello).
# Poi la stessa domanda (domanda.txt) a Haiku con effort low, nessuno strumento,
# nessun server MCP e un system prompt di una riga (sistema.txt): nel braccio
# breve con formato-breve.txt, nel braccio lunga con formato-lungo.txt, e
# nient'altro di diverso. Ogni chiamata ha --no-session-persistence e parte da
# una cartella temporanea vuota. I JSON di claude -p vanno in risposte/, poi
# controlla_conto.py dice il conto di ogni esecuzione e confronta le coppie.
# Ogni comando si vede prima di girare (handson::claude_p).
#
# Uso:    <cartella dell'elemento>/demo/in_classe.sh <spazio di lavoro>
#           lo spazio di lavoro appena preparato (tools/prepara_esercizio.sh
#           M8-D02), con git status pulito e senza risposte/
# Env:    PN_ESECUZIONI    quante coppie di chiamate, da 1 a 9 (default 1)
#         PN_HANDSON_ROOT  il repository (default: dal percorso di questo
#                          file; dalla copia nello spazio di lavoro va data)
#         le variabili di tools/lib_handson.sh (HANDSON_NO_PAUSE, …)
# Uscita: 0 = ogni chiamata è finita e il controllo ha letto le esecuzioni ·
#         1 = una chiamata fallita o un'esecuzione che il controllo non
#         accetta · 2 = precondizione
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
# lo script sta in <radice>/m8_…/s6_…/m8_3_…/M8-D02_…/demo/
readonly RADICE="${PN_HANDSON_ROOT:-${SELF%/*/*/*/*/*/*}}"
[[ -f "${RADICE}/tools/lib_handson.sh" ]] || { echo "in_classe.sh: non" \
  "trovo tools/lib_handson.sh in ${RADICE}: lanciatelo dal repository, o" \
  "date PN_HANDSON_ROOT" >&2; exit 2; }
# shellcheck source=../../../../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"

readonly ELEMENTO=M8-D02
readonly MODELLO=haiku
readonly BRACCI=(breve lunga)
readonly RISPOSTE=risposte
readonly CONTESTO="${RISPOSTE}/contesto"
readonly NECESSARI=(domanda.txt formato-breve.txt formato-lungo.txt
  sistema.txt listino.json controlla_conto.py .claude/settings.json)
readonly ESECUZIONI="${PN_ESECUZIONI:-1}"
CARTELLA=''
DOMANDA=''
FORMATO_BREVE=''
FORMATO_LUNGO=''
SISTEMA=''

# Una chiamata di claude -p dalla cartella temporanea, con le opzioni di ogni
# chiamata di questa demo e il JSON nel file dato.
# Globals: CARTELLA, MODELLO, SISTEMA. Arguments: $1 il prompt, $2 il file
# d'uscita. Returns: l'uscita di claude.
chiama() {
  ( cd -- "${CARTELLA}" && handson::claude_p "${MODELLO}" '' "$1" \
      --tools '' --system-prompt "${SISTEMA}" --effort low \
      --strict-mcp-config --no-session-persistence ) < /dev/null > "$2"
}

# Una chiamata fallita: la demo finisce con uscita 1.
# Arguments: il testo del verdetto.
fallita() {
  handson::verdict ko "$*"
  handson::finish
}

# /context, prima delle domande: quanto pesa il contesto di partenza, stampato
# dal campo result del JSON. Non è una chiamata al modello.
leggi_contesto() {
  handson::step "/context: di che cosa è fatto il contesto"
  mkdir -- "${CONTESTO}" || handson::die "mkdir ${CONTESTO} non riesce"
  chiama '/context' "${CONTESTO}/risposta.json" \
    || fallita "/context: claude -p è fallito"
  python3 -B -I -c 'import json, sys
print(json.load(open(sys.argv[1], encoding="utf-8")).get("result") or "")' \
    "${CONTESTO}/risposta.json" 2> /dev/null \
    || handson::note "non riesco a leggere ${CONTESTO}/risposta.json: lo" \
      "dirà il controllo"
}

# Una chiamata della coppia. Arguments: $1 il braccio, $2 il numero, $3 il
# prompt del braccio.
una_chiamata() {
  local nome="$1-$2"
  handson::step "${nome}: la domanda, con il formato del braccio «$1»"
  mkdir -- "${RISPOSTE}/${nome}" || handson::die "mkdir non riesce"
  chiama "$3" "${RISPOSTE}/${nome}/risposta.json" \
    || fallita "${nome}: claude -p è fallito"
}

# Le precondizioni, prima di ogni chiamata. Va chiamata nello spazio di
# lavoro. Globals: DOMANDA, FORMATO_*, SISTEMA (assegnate).
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
  [[ ! -e "${RISPOSTE}" && -z "${stato}" ]] \
    || handson::die "lo spazio di lavoro non è al punto di partenza (c'è" \
      "${RISPOSTE}/, o git status non è vuoto):" \
      "tools/reset_esercizio.sh ${ELEMENTO}"
  [[ "${ESECUZIONI}" =~ ^[1-9]$ ]] \
    || handson::die "PN_ESECUZIONI: da 1 a 9, non «${ESECUZIONI}»"
  DOMANDA="$(< domanda.txt)"
  FORMATO_BREVE="$(< formato-breve.txt)"
  FORMATO_LUNGO="$(< formato-lungo.txt)"
  SISTEMA="$(< sistema.txt)"
  for f in "${DOMANDA}" "${FORMATO_BREVE}" "${FORMATO_LUNGO}" "${SISTEMA}"; do
    handson::_claude_p_checks "${MODELLO}" "${f}"
    handson::_claude_key_ok "${f}"
  done
  handson::_claude_arg_ok "${SISTEMA}"
  handson::need_claude
}

main() {
  local ws="${1:-}" braccio n prompt rc=0
  [[ -n "${ws}" && -d "${ws}" ]] \
    || handson::die "spazio di lavoro assente: ${ws}"
  cd -- "${ws}" || handson::die "lo spazio di lavoro ${ws} non si apre"
  precondizioni
  handson::banner "${ELEMENTO}" "Il conto dal campo usage" \
    "Modulo 8, «Il conto in token»"
  handson::tmpdir CARTELLA
  mkdir -- "${RISPOSTE}" || handson::die "mkdir ${RISPOSTE} non riesce"
  handson::pause "fare le chiamate"
  leggi_contesto
  for (( n = 1; n <= ESECUZIONI; n++ )); do
    for braccio in "${BRACCI[@]}"; do
      if [[ "${braccio}" == breve ]]; then
        prompt="${DOMANDA}"$'\n\n'"${FORMATO_BREVE}"
      else
        prompt="${DOMANDA}"$'\n\n'"${FORMATO_LUNGO}"
      fi
      una_chiamata "${braccio}" "${n}" "${prompt}"
    done
  done
  handson::step "Il conto: il controllo legge il JSON di ogni chiamata"
  handson::run python3 -B -I controlla_conto.py "${RISPOSTE}" < /dev/null \
    || rc=$?
  handson::verdict_rc "${rc}" "il conto, sulle esecuzioni di ${RISPOSTE}/"
  handson::finish
}

main "$@"
