#!/bin/bash
#
# in_classe.sh -- M8-D03 «La cache, vista nel contatore», dal vivo. Una serie
# è fatta di cinque chiamate di claude -p, ognuna una sessione nuova, con la
# stessa domanda (domanda.txt) e lo stesso prefisso come --system-prompt-file:
# due procedure della base di conoscenza di CiaspoLink (progetti/) e, in testa,
# una riga con un marcatore nuovo a ogni serie, così ogni serie parte a cache
# fredda. Le cinque chiamate partono dalla stessa cartella temporanea vuota,
# fuori dallo spazio di lavoro, con le stesse opzioni (effort low, nessuno
# strumento, nessun server MCP, output JSON), tranne ciò che il nome dice:
#   1. prima           su Haiku;
#   2. seconda         la stessa chiamata, ripetuta;
#   3. senza-cache     la stessa, con DISABLE_PROMPT_CACHING=1 nell'ambiente;
#   4. sonnet          la stessa, con --model sonnet;
#   5. haiku-di-nuovo  la stessa, ancora su Haiku.
# I JSON vanno in risposte/<serie>-<nome>/risposta.json, il prefisso in
# risposte/<serie>-prefisso.md; poi controlla_cache.py legge usage di ogni
# chiamata e controlla le garanzie. Ogni comando si vede prima di girare
# (handson::claude_p).
#
# Uso:    <cartella dell'elemento>/demo/in_classe.sh <spazio di lavoro>
#           lo spazio di lavoro appena preparato (tools/prepara_esercizio.sh
#           M8-D03), con git status pulito e senza risposte/
# Env:    PN_ESECUZIONI    quante serie, da 1 a 9 (default 1)
#         PN_HANDSON_ROOT  il repository (default: dal percorso di questo
#                          file; dalla copia nello spazio di lavoro va data)
#         le variabili di tools/lib_handson.sh (HANDSON_NO_PAUSE, …)
# Uscita: 0 = ogni chiamata è finita e le garanzie valgono · 1 = una chiamata
#         fallita, o una garanzia che non vale · 2 = precondizione
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
# lo script sta in <radice>/m8_…/s6_…/m8_5_…/M8-D03_…/demo/
readonly RADICE="${PN_HANDSON_ROOT:-${SELF%/*/*/*/*/*/*}}"
[[ -f "${RADICE}/tools/lib_handson.sh" ]] || { echo "in_classe.sh: non" \
  "trovo tools/lib_handson.sh in ${RADICE}: lanciatelo dal repository, o" \
  "date PN_HANDSON_ROOT" >&2; exit 2; }
# shellcheck source=../../../../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"

readonly ELEMENTO=M8-D03
readonly RISPOSTE=risposte
readonly KB=progetti/assistenza-clienti/kb
readonly PROCEDURE=("${KB}/kb-10-trasloco.md"
  "${KB}/kb-13-telefono-di-casa-muto.md")
readonly NECESSARI=(domanda.txt controlla_cache.py .claude/settings.json
  "${PROCEDURE[@]}")
readonly ESECUZIONI="${PN_ESECUZIONI:-1}"
# shellcheck disable=SC2034  # la legge handson::claude_p
HANDSON_OUTPUT_FORMAT='json'
WS=''
CARTELLE=''
DOMANDA=''

# Il prefisso di una serie, su STDOUT: la riga del marcatore, poi le procedure.
# Arguments: $1 il marcatore.
componi_prefisso() {
  local f
  printf 'Marcatore di questa serie: %s.\n' "$1"
  for f in "${PROCEDURE[@]}"; do
    printf '\n'
    cat -- "${f}"
  done
}

# Una cartella temporanea vuota da cui far partire le chiamate di una serie.
# Globals: CARTELLE. Arguments: $1 la variabile da assegnare.
cartella_nuova() {
  local __c
  __c="$(mktemp -d "${CARTELLE}/serie.XXXXXX")" \
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

# Una chiamata della serie, nel suo sottoprocesso: con «spenta» l'unica
# differenza dalla chiamata di prima è DISABLE_PROMPT_CACHING=1, che si vede
# sullo schermo (handson::run) e vale solo qui.
# Arguments: $1 il nome (<serie>-<chiamata>), $2 la cartella di partenza, $3
#   il prefisso, $4 il modello, $5 (facoltativo) «spenta».
una_chiamata() {
  local nome="$1" cartella="$2" prefisso="$3" modello="$4" spenta="${5:-}"
  handson::step "${nome}: ${modello}${spenta:+, con la cache spenta}"
  mkdir -- "${RISPOSTE}/${nome}" || handson::die "mkdir non riesce"
  (
    cd -- "${cartella}" || exit 2
    if [[ -n "${spenta}" ]]; then
      handson::run export DISABLE_PROMPT_CACHING=1
    fi
    handson::claude_p "${modello}" '' "${DOMANDA}" --tools '' \
      --system-prompt-file "${prefisso}" --effort low --strict-mcp-config \
      --no-session-persistence
  ) < /dev/null > "${RISPOSTE}/${nome}/risposta.json" \
    || fallita "${nome}: claude -p è fallito"
}

# Una serie: il prefisso, con il suo marcatore, e le cinque chiamate.
# Globals: WS. Arguments: $1 il numero della serie.
una_serie() {
  local n="$1" marcatore prefisso cartella
  marcatore="$(printf 'CACHE-%04X%04X' "${RANDOM}" "${RANDOM}")"
  prefisso="${WS}/${RISPOSTE}/${n}-prefisso.md"
  componi_prefisso "${marcatore}" > "${prefisso}" \
    || handson::die "non riesco a comporre ${prefisso}"
  cartella_nuova cartella
  handson::step "Serie ${n}: lo stesso prefisso per le cinque chiamate"
  handson::note "il prefisso sta in ${RISPOSTE}/${n}-prefisso.md," \
    "marcatore ${marcatore}"
  una_chiamata "${n}-prima" "${cartella}" "${prefisso}" haiku
  una_chiamata "${n}-seconda" "${cartella}" "${prefisso}" haiku
  una_chiamata "${n}-senza-cache" "${cartella}" "${prefisso}" haiku spenta
  una_chiamata "${n}-sonnet" "${cartella}" "${prefisso}" sonnet
  una_chiamata "${n}-haiku-di-nuovo" "${cartella}" "${prefisso}" haiku
}

# Le precondizioni, prima di ogni chiamata. Va chiamata nello spazio di
# lavoro. Globals: DOMANDA (assegnata).
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
  handson::_claude_p_checks haiku "${DOMANDA}"
  handson::_claude_key_ok "${DOMANDA}"
  handson::need_claude
}

main() {
  local ws="${1:-}" n rc=0
  [[ -n "${ws}" && -d "${ws}" ]] \
    || handson::die "spazio di lavoro assente: ${ws}"
  cd -- "${ws}" || handson::die "lo spazio di lavoro ${ws} non si apre"
  WS="$(pwd -P)"
  precondizioni
  # Impostata nella shell di chi lancia, spegnerebbe la cache in ogni chiamata.
  unset DISABLE_PROMPT_CACHING
  handson::banner "${ELEMENTO}" "La cache, vista nel contatore" \
    "Modulo 8, «La cache»: la prompt caching nel campo usage"
  handson::tmpdir CARTELLE
  mkdir -- "${RISPOSTE}" || handson::die "mkdir ${RISPOSTE} non riesce"
  handson::pause "fare le chiamate"
  for (( n = 1; n <= ESECUZIONI; n++ )); do
    una_serie "${n}"
  done
  handson::step "Che cosa è successo: il controllo legge usage di ogni chiamata"
  handson::run python3 -B -I controlla_cache.py "${RISPOSTE}" < /dev/null \
    || rc=$?
  handson::verdict_rc "${rc}" "il controllo, sulle chiamate di ${RISPOSTE}/"
  handson::finish
}

main "$@"
