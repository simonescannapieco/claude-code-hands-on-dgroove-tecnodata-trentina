#!/bin/bash
#
# in_classe.sh -- M7-D01 «Cambia solo il system prompt», dal vivo. Due parti,
# con le stesse opzioni (Sonnet, effort low, nessuno strumento integrato,
# nessun server MCP, stream-json), ogni chiamata da una cartella temporanea
# vuota, fuori dallo spazio di lavoro:
#   1. il messaggio di un cliente (messaggio.txt) con due system prompt, e
#      nient'altro di diverso: system-generico.md, una riga neutra, e
#      system-ciaspolink.md, il ruolo con la riga «al massimo tre righe»;
#   2. la memoria. Una parola in codice, diversa per ogni esecuzione (primo.txt,
#      con la parola al posto di @@PAROLA@@), in una prima chiamata che resta
#      salvata; poi la domanda (seguito.txt) in una chiamata nuova, senza
#      --resume, e nella sessione della prima chiamata, con --resume.
# Gli stream vanno in risposte/ e controlla_sistema.py dice, esecuzione per
# esecuzione, che cosa è successo. La sessione salvata della parte 2 viene tolta
# alla fine di ogni esecuzione. Ogni comando si vede prima di girare
# (handson::claude_p).
#
# Uso:    <cartella dell'elemento>/demo/in_classe.sh <spazio di lavoro>
#           lo spazio di lavoro appena preparato (tools/prepara_esercizio.sh
#           M7-D01), con git status pulito e senza risposte/
# Env:    PN_ESECUZIONI    quante esecuzioni per parte, da 1 a 9 (default 1)
#         PN_HANDSON_ROOT  il repository (default: dal percorso di questo
#                          file; dalla copia nello spazio di lavoro va data)
#         le variabili di tools/lib_handson.sh (HANDSON_NO_PAUSE, …)
# Uscita: 0 = ogni chiamata è finita e il controllo ha letto le esecuzioni ·
#         1 = una chiamata fallita, una garanzia che non vale o il controllo
#         che chiede di rifare la prova · 2 = precondizione
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
# lo script sta in <radice>/m7_…/s5_…/m7_2_…/M7-D01_…/demo/
readonly RADICE="${PN_HANDSON_ROOT:-${SELF%/*/*/*/*/*/*}}"
[[ -f "${RADICE}/tools/lib_handson.sh" ]] || { echo "in_classe.sh: non" \
  "trovo tools/lib_handson.sh in ${RADICE}: lanciatelo dal repository, o" \
  "date PN_HANDSON_ROOT" >&2; exit 2; }
# shellcheck source=../../../../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"

readonly ELEMENTO=M7-D01
readonly MODELLO=sonnet
readonly BRACCI=(generico ciaspolink)
readonly RISPOSTE=risposte
readonly SEGNAPOSTO='@@PAROLA@@'
readonly PAROLE=(GENZIANA LARICE CIASPOLA MARMOTTA STAMBECCO CAMOSCIO)
readonly NECESSARI=(system-generico.md system-ciaspolink.md messaggio.txt
  primo.txt seguito.txt controlla_sistema.py .claude/settings.json)
readonly ESECUZIONI="${PN_ESECUZIONI:-1}"
# shellcheck disable=SC2034  # la legge handson::claude_p
HANDSON_OUTPUT_FORMAT='stream-json'
WS=''
CARTELLE=''
MESSAGGIO=''
PRIMO=''
SEGUITO=''

# Una chiamata di claude -p dalla cartella $1 con system-$2.md, il prompt $3,
# lo stream-json nel file $4, le opzioni in più dopo.
# Globals: WS. Arguments: come sopra. Returns: l'uscita di claude.
chiama() {
  local cartella="$1" sistema="$2" prompt="$3" uscita="$4"
  shift 4
  ( cd -- "${cartella}" && handson::claude_p "${MODELLO}" '' "${prompt}" \
      --tools '' --system-prompt-file "${WS}/system-${sistema}.md" \
      --effort low --strict-mcp-config "$@" ) < /dev/null > "${uscita}"
}

# Una cartella temporanea vuota da cui far partire una chiamata; il percorso
# reale, perché è quello con cui Claude Code salva la sessione.
# Globals: CARTELLE. Arguments: $1 la variabile da assegnare.
cartella_nuova() {
  local __c
  __c="$(mktemp -d "${CARTELLE}/run.XXXXXX")" \
    || handson::die "mktemp non riesce a creare una cartella"
  __c="$(cd -- "${__c}" && pwd -P)" || handson::die "${__c} non si apre"
  printf -v "$1" '%s' "${__c}"
}

# Una chiamata fallita: la demo finisce con uscita 1.
# Arguments: il testo del verdetto.
fallita() {
  handson::verdict ko "$*"
  handson::finish
}

# Un'esecuzione della parte 1. Arguments: $1 il braccio, $2 il numero.
una_esecuzione() {
  local nome="$1-$2" cartella
  handson::step "${nome}: il messaggio del cliente, con system-$1.md"
  cartella_nuova cartella
  mkdir -- "${RISPOSTE}/${nome}" || handson::die "mkdir non riesce"
  chiama "${cartella}" "$1" "${MESSAGGIO}" \
    "${RISPOSTE}/${nome}/stream.jsonl" --no-session-persistence \
    || fallita "${nome}: claude -p è fallito"
}

# Il session_id di uno stream, dalla prima riga che lo porta.
# Arguments: $1 lo stream. Outputs: il session_id. Returns: 1 se non c'è.
sessione_di() {
  local riga re='"session_id": ?"([0-9a-f-]+)"'
  while IFS= read -r riga; do
    if [[ "${riga}" =~ ${re} ]]; then
      printf '%s\n' "${BASH_REMATCH[1]}"
      return 0
    fi
  done < "$1"
  return 1
}

# Toglie la sessione salvata per la cartella data, come fa il banco di prova:
# ~/.claude/projects/<il percorso, ogni carattere non alfanumerico un trattino>.
# Mai un percorso vuoto né un collegamento simbolico.
# Arguments: $1 la cartella da cui è partita la chiamata.
togli_sessione() {
  local nome="${1//[^A-Za-z0-9]/-}" base sessioni
  base="${CLAUDE_CONFIG_DIR:-${HOME:-}/.claude}"
  sessioni="${base}/projects/${nome}"
  if [[ -n "${nome}" && -n "${base}" && -d "${sessioni}" \
      && ! -L "${sessioni}" ]]; then
    rm -rf -- "${sessioni}" \
      || handson::note "non riesco a togliere ${sessioni}"
  fi
}

# Un'esecuzione della parte 2: la parola, la domanda senza e con --resume.
# Arguments: $1 il numero dell'esecuzione.
una_memoria() {
  local nome="memoria-$1" cartella parola sessione dentro primo
  handson::step "${nome}: una parola in codice, poi la domanda, due volte"
  cartella_nuova cartella
  dentro="${RISPOSTE}/${nome}"
  mkdir -- "${dentro}" || handson::die "mkdir non riesce"
  parola="${PAROLE[RANDOM % ${#PAROLE[@]}]}-$(( RANDOM % 9000 + 1000 ))"
  printf '%s\n' "${parola}" > "${dentro}/parola.txt" \
    || handson::die "non riesco a scrivere ${dentro}/parola.txt"
  primo="${PRIMO//"${SEGNAPOSTO}"/${parola}}"
  handson::note "la parola in codice di questa esecuzione: ${parola}"
  chiama "${cartella}" generico "${primo}" "${dentro}/primo.jsonl" \
    || fallita "${nome}: la prima chiamata è fallita"
  sessione="$(sessione_di "${dentro}/primo.jsonl")" \
    || fallita "${nome}: nessun session_id nello stream della prima chiamata"
  chiama "${cartella}" generico "${SEGUITO}" "${dentro}/nuova.jsonl" \
    --no-session-persistence \
    || fallita "${nome}: la chiamata nuova è fallita"
  chiama "${cartella}" generico "${SEGUITO}" "${dentro}/ripresa.jsonl" \
    --resume "${sessione}" \
    || fallita "${nome}: la chiamata con --resume è fallita"
  togli_sessione "${cartella}"
}

# Le precondizioni, prima di ogni chiamata. Va chiamata nello spazio di
# lavoro. Globals: MESSAGGIO, PRIMO, SEGUITO (assegnate).
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
  MESSAGGIO="$(< messaggio.txt)"
  PRIMO="$(< primo.txt)"
  SEGUITO="$(< seguito.txt)"
  [[ "${PRIMO}" == *"${SEGNAPOSTO}"* ]] \
    || handson::die "primo.txt non ha il segnaposto ${SEGNAPOSTO}"
  handson::_claude_p_checks "${MODELLO}" "${MESSAGGIO}"
  handson::_claude_key_ok "${MESSAGGIO}"
  handson::need_claude
}

main() {
  local ws="${1:-}" braccio n rc=0
  [[ -n "${ws}" && -d "${ws}" ]] \
    || handson::die "spazio di lavoro assente: ${ws}"
  cd -- "${ws}" || handson::die "lo spazio di lavoro ${ws} non si apre"
  WS="$(pwd -P)"
  precondizioni
  handson::banner "${ELEMENTO}" "Cambia solo il system prompt" \
    "Modulo 7, «Anatomia di un assistente»"
  handson::tmpdir CARTELLE
  mkdir -- "${RISPOSTE}" || handson::die "mkdir ${RISPOSTE} non riesce"
  handson::pause "fare le chiamate"
  for braccio in "${BRACCI[@]}"; do
    for (( n = 1; n <= ESECUZIONI; n++ )); do
      una_esecuzione "${braccio}" "${n}"
    done
  done
  for (( n = 1; n <= ESECUZIONI; n++ )); do
    una_memoria "${n}"
  done
  handson::step "Che cosa è successo: il controllo legge gli stream"
  export PN_HANDSON_ROOT="${RADICE}"
  handson::run python3 -B -I controlla_sistema.py "${RISPOSTE}" < /dev/null \
    || rc=$?
  handson::verdict_rc "${rc}" "il controllo, sulle esecuzioni di ${RISPOSTE}/"
  handson::finish
}

main "$@"
