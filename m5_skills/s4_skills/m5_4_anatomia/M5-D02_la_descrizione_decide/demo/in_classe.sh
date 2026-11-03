#!/bin/bash
#
# in_classe.sh -- M5-D02 dal vivo. Per ogni esecuzione, cinque chiamate, ognuna
# in una cartella nuova prove/<lettera>-<n> dello spazio di lavoro, fatta da
# prepara_braccio.sh, con lo stesso corpo e lo stesso nome della skill:
#   a  vaga          la description vaga, richiesta.txt
#   b  specifica     la description specifica, richiesta.txt
#   c  near_miss     la description specifica, richiesta_near_miss.txt
#   d  manuale       la specifica con disable-model-invocation, richiesta.txt
#   e  manuale_nome  lo stesso file, /prova-d02 e richiesta.txt
# Le cartelle hanno una lettera, perché il loro nome non dica quale braccio
# sono. Sonnet, effort low, Read consentito, nessun server MCP, una sessione
# nuova che non resta salvata, stream-json. Ogni comando si vede prima di girare
# (handson::claude_p).
# Gli stream restano fuori dallo spazio di lavoro finché le chiamate non sono
# finite, così nessuna sessione trova quello di un'altra; poi una copia va in
# risposte/, e controlla_descrizione.py stampa i conteggi e i verdetti. Se una
# chiamata fallisce, ciò che c'è va in risposte/ e la prova si ferma.
#
# Uso:    <cartella dell'elemento>/demo/in_classe.sh <spazio di lavoro>
#           dal repository, sullo spazio di lavoro appena preparato (git status
#           pulito); dalla copia nello spazio di lavoro serve PN_HANDSON_ROOT
# Env:    PN_ESECUZIONI    quante esecuzioni, da 1 a 9 (default 1)
#         PN_LIVE_JSON     dove restano gli stream, fuori dallo spazio di lavoro
#                          (default accanto, <spazio>.prova_dal_vivo); non deve
#                          avere già degli stream
#         PN_HANDSON_ROOT  il repository (default: dal percorso di questo file)
#         le variabili di tools/lib_handson.sh (HANDSON_NO_PAUSE, …)
# Uscita: 0 = gli stream si leggono e il controllo non ha segnalazioni · 1 = una
#         chiamata fallita, o una segnalazione · 2 = precondizione, anche del
#         controllo
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
# lo script sta in <radice>/m5_…/s4_…/m5_4_…/M5-D02_…/demo/
readonly RADICE="${PN_HANDSON_ROOT:-${SELF%/*/*/*/*/*/*}}"
if [[ ! -f "${RADICE}/tools/lib_handson.sh" ]]; then
  echo "in_classe.sh: non trovo tools/lib_handson.sh in ${RADICE}: lanciatelo" \
    "dal repository, o date PN_HANDSON_ROOT" >&2
  exit 2
fi
# shellcheck source=../../../../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"

readonly MODELLO=sonnet
readonly STRUMENTI=Read
# I soli strumenti che la demo ha a disposizione: niente Bash, così una sessione
# non stampa con ls -la il nome del proprietario dei file nello stream.
readonly STRUMENTI_DISPONIBILI=Read,Skill
readonly NOME_SKILL=prova-d02
readonly BRACCI=(vaga specifica near_miss manuale manuale_nome)
readonly LETTERE=(a b c d e)
readonly CARTELLA=prove
readonly NECESSARI=(configurazione.txt richiesta.txt richiesta_near_miss.txt
  descrizione_vaga.txt descrizione_specifica.txt corpo.md prepara_braccio.sh
  controlla_descrizione.py)
# shellcheck disable=SC2034  # la legge handson::claude_p
HANDSON_OUTPUT_FORMAT='stream-json'
JSON=''

# Gli stream, copiati in risposte/ dello spazio di lavoro (la cartella
# corrente). Globals: JSON (letta).
consegna() {
  mkdir -p risposte || handson::die "non riesco a creare risposte/"
  handson::run cp -R -- "${JSON}/." risposte/ < /dev/null \
    || handson::die "non riesco a copiare gli stream in risposte/"
}

# Una chiamata fallita: gli stream che ci sono in risposte/, il verdetto KO e
# la fine con uscita 1. Arguments: il testo del verdetto.
fallita() {
  consegna
  handson::verdict ko "$*"
  handson::finish
}

# Il testo di un braccio. Arguments: $1 il braccio. Outputs: il testo su STDOUT.
testo_di() {
  case "$1" in
    near_miss) printf '%s' "$(< richiesta_near_miss.txt)" ;;
    manuale_nome) printf '/%s %s' "${NOME_SKILL}" "$(< richiesta.txt)" ;;
    *) printf '%s' "$(< richiesta.txt)" ;;
  esac
}

# Una chiamata da una cartella nuova, con lo stream in un file; se fallisce, la
# prova si ferma. Globals: JSON (letta). Arguments: $1 il braccio, $2 la
# lettera, $3 il numero.
chiedi() {
  local braccio="$1" cartella="${CARTELLA}/$2-$3" nome="$1-$3" testo
  handson::step "${nome}"
  handson::run bash prepara_braccio.sh "${cartella}" "${braccio}" < /dev/null \
    || handson::die "prepara_braccio.sh non riesce: ${cartella}"
  testo="$(testo_di "${braccio}")"
  ( cd -- "${cartella}" \
    && handson::claude_p "${MODELLO}" "${STRUMENTI}" "${testo}" --effort low \
      --tools "${STRUMENTI_DISPONIBILI}" --strict-mcp-config \
      --no-session-persistence ) \
    < /dev/null > "${JSON}/${nome}.jsonl" \
    || fallita "${nome}: claude -p è fallito"
}

# La cartella degli stream, fuori dallo spazio di lavoro e senza stream di
# prima, che si mescolerebbero a questi. Va chiamata nello spazio di lavoro.
# Globals: JSON (assegnata).
cartella_json() {
  local ws f
  ws="$(pwd -P)"
  JSON="${PN_LIVE_JSON:-${ws}.prova_dal_vivo}"
  mkdir -p -- "${JSON}" || handson::die "non riesco a creare ${JSON}"
  JSON="$(cd "${JSON}" && pwd -P)" \
    || handson::die "non riesco a leggere ${JSON}"
  if [[ "${JSON}/" == "${ws}/"* ]]; then
    handson::die "gli stream non stanno nello spazio di lavoro: ${JSON}"
  fi
  for f in "${JSON}"/*.jsonl; do
    [[ ! -e "${f}" ]] \
      || handson::die "c'è già una prova in ${JSON}: spostatela o" \
        "cancellatela, e ripartite da tools/reset_esercizio.sh M5-D02"
  done
  handson::note "gli stream in ${JSON}"
}

# Le precondizioni, prima di ogni chiamata. Va chiamata nello spazio di lavoro.
precondizioni() {
  local f radice stato testo
  [[ "${HANDSON_ENV}" == claude-code-pro ]] \
    || handson::die "M5-D02 è un elemento claude-code-pro: HANDSON_ENV" \
      "«${HANDSON_ENV}» non vale qui"
  handson::need_tools python3 git
  for f in "${NECESSARI[@]}"; do
    handson::need_file "${f}"
  done
  radice="$(git rev-parse --show-toplevel 2> /dev/null)" || radice=''
  [[ "${radice}" == "$(pwd -P)" ]] \
    || handson::die "$(pwd -P) non è un repository git: preparatelo con" \
      "tools/prepara_esercizio.sh M5-D02"
  stato="$(git status --porcelain)" || handson::die "git status non riesce"
  [[ -z "${stato}" ]] \
    || handson::die "lo spazio di lavoro non è al punto di partenza (git" \
      "status non è vuoto): tools/reset_esercizio.sh M5-D02"
  [[ "${PN_ESECUZIONI:-1}" =~ ^[1-9]$ ]] \
    || handson::die "PN_ESECUZIONI vuole un numero da 1 a 9, non" \
      "«${PN_ESECUZIONI}»"
  for f in richiesta.txt richiesta_near_miss.txt; do
    testo="$(< "${f}")"
    handson::_claude_p_checks "${MODELLO}" "${testo}"
    handson::_claude_key_ok "${testo}"
  done
  handson::need_claude
}

main() {
  local ws="${1:-}" n i rc=0
  [[ -n "${ws}" && -d "${ws}" ]] \
    || handson::die "spazio di lavoro assente: ${ws}"
  cd -- "${ws}" || handson::die "lo spazio di lavoro ${ws} non si apre"
  precondizioni
  cartella_json
  handson::banner M5-D02 "La descrizione decide" \
    "Modulo 5, «Anatomia di uno SKILL.md»: cambia soltanto la description"
  handson::pause "fare le chiamate"
  for (( n = 1; n <= ${PN_ESECUZIONI:-1}; n++ )); do
    for (( i = 0; i < ${#BRACCI[@]}; i++ )); do
      chiedi "${BRACCI[i]}" "${LETTERE[i]}" "${n}"
    done
  done
  handson::step "Gli stream nello spazio di lavoro, a sessioni finite"
  consegna
  handson::step "I conteggi e i verdetti"
  handson::run python3 -B -I controlla_descrizione.py risposte || rc=$?
  handson::verdict_rc "${rc}" "il controllo, sugli stream di risposte/"
  handson::finish
}

main "$@"
