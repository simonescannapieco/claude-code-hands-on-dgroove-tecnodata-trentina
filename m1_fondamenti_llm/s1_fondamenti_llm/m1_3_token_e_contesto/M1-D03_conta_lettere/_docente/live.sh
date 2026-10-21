#!/bin/bash
#
# live.sh di M1-D03 -- la demo del docente: contare le lettere. Per ogni
# modello sei chiamate con claude -p, senza strumenti né server MCP: il
# testo di parola.txt («interconnessione»), di compitata.txt (la stessa
# parola, le lettere separate da spazi) e di strawberry.txt, ognuno da solo
# e ripetuto due volte, separato da uno spazio. Testi e opzioni sono quelli
# del passo 3 del README, più le opzioni che handson::claude_p imposta da
# sé. I token in entrata (input_tokens + cache_creation_input_tokens +
# cache_read_input_tokens, letti da demo/leggi_json.py come nel README)
# vanno in conteggi.tsv, nello stesso formato. Poi verifica.sh calcola i
# pesi (il doppio meno il singolo), conta le lettere e mette alla prova le
# tre affermazioni: i numeri e gli esiti restano a schermo anche quando la
# verifica passa.
#
# Uso:    _docente/live.sh <spazio di lavoro>
# Env:    PN_MODELLI  i modelli, separati da spazi (default «haiku»;
#                     ammessi haiku, sonnet, opus): con due o più si mette
#                     alla prova anche la terza affermazione
#         e le variabili di tools/lib_handson.sh (HANDSON_NO_PAUSE, …)
# Uscita: 0 = conteggi completi e ogni affermazione messa alla prova
#         confermata · 1 = una chiamata fallita, un conteggio mancante o
#         un'affermazione non confermata · 2 = precondizione, anche di
#         verifica.sh (la verifica non ha potuto girare)
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
# lo script sta in <radice>/m1_…/s1_…/m1_3_…/M1-D03_…/_docente/
readonly RADICE="${SELF%/*/*/*/*/*/*}"
readonly ELEMENTO="${SELF%/_docente/*}"
readonly CONTROLLO="${ELEMENTO}/verifica.sh"
readonly LEGGI_JSON="${ELEMENTO}/demo/leggi_json.py"
# shellcheck source=../../../../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"

readonly TESTI=(parola compitata strawberry)

# Una chiamata: il JSON di claude nel file $3. Va chiamata nella shell
# dello script, non dentro $(…): così una precondizione di
# handson::claude_p (modalità di permesso, ambiente, testo vuoto) esce
# davvero con 2, invece di diventare una chiamata fallita.
# Arguments: $1 il modello, $2 il testo, $3 il file.
# Returns: l'uscita di claude.
chiama() {
  handson::claude_p "$1" "" "$2" --tools "" \
    --system-prompt "$(cat istruzione.txt)" --effort low \
    --strict-mcp-config --no-session-persistence > "$3"
}

# I token in entrata di una risposta, su STDOUT, letti come nel passo 3
# del README. Arguments: $1 il file del JSON.
# Returns: 1 se il JSON non li ha (leggi_json.py dice perché, su STDERR).
token_entrata() {
  python3 -B -I "${LEGGI_JSON}" token_entrata < "$1"
}

# Le sei chiamate di un modello, con una riga a schermo e una in
# conteggi.tsv per ciascuna; il comando si vede per le due chiamate del
# primo testo, poi torna come l'ha trovato.
# Globals: TESTI (letta), HANDSON_SHOW_CMD (cambiata e ripristinata).
# Arguments: $1 il modello, $2 il file del JSON.
sei_chiamate() {
  local m="$1" json="$2" mostra="${HANDSON_SHOW_CMD}" t singolo etichetta
  local testo n
  for t in "${TESTI[@]}"; do
    singolo="$(cat "${t}.txt")"
    for etichetta in "${t}" "${t}-doppia"; do
      testo="${singolo}"
      if [[ "${etichetta}" == "${t}-doppia" ]]; then
        testo="${singolo} ${singolo}"
      fi
      if chiama "${m}" "${testo}" "${json}" \
          && n="$(token_entrata "${json}")"; then
        printf '%s\t%s\t%s\n' "${m}" "${etichetta}" "${n}" >> conteggi.tsv
        printf '  %-7s %-17s %6s token in entrata\n' "${m}" "${etichetta}" \
          "${n}"
      else
        handson::verdict ko "${m}, testo «${etichetta}»: nessun conteggio"
      fi
    done
    HANDSON_SHOW_CMD=0
  done
  HANDSON_SHOW_CMD="${mostra}"
}

# verifica.sh sullo spazio di lavoro, con la sua uscita sul descrittore 3,
# lo STDOUT di live.sh: handson::check la esegue dentro $(…) e su un OK
# resta muta, ma in aula i pesi e gli esiti si leggono sempre.
# Arguments: $1 lo spazio di lavoro. Returns: l'uscita di verifica.sh.
# shellcheck disable=SC2317  # la chiama handson::check, indirettamente
verifica_a_schermo() {
  "${CONTROLLO}" "$1" >&3 2>&1
}

main() {
  local ws="${1:-}" m f json
  local -a modelli=()
  [[ -n "${ws}" && -d "${ws}" ]] \
    || handson::die "spazio di lavoro assente: ${ws}"
  read -r -a modelli <<< "${PN_MODELLI:-haiku}"
  (( ${#modelli[@]} > 0 )) || handson::die "PN_MODELLI è vuota"
  for m in "${modelli[@]}"; do
    case "${m}" in
      haiku|sonnet|opus) ;;
      *) handson::die "modello non ammesso in PN_MODELLI: «${m}»" ;;
    esac
  done
  cd "${ws}"
  handson::need_tools python3
  for f in "${TESTI[@]}" istruzione; do
    handson::need_file "${f}.txt"
  done
  handson::need_file "${LEGGI_JSON}"
  handson::need_claude
  handson::tmpfile json
  handson::banner M1-D03 "Contare le lettere" \
    "Modulo 1, «Token e finestra di contesto»: quanti token pesa una parola?"
  printf 'modello\ttesto\ttoken_entrata\n' > conteggi.tsv
  for m in "${modelli[@]}"; do
    handson::step "${m}"
    sei_chiamate "${m}" "${json}"
  done
  handson::step "I pesi e le tre affermazioni"
  exec 3>&1
  handson::check "le tre affermazioni (verifica.sh)" verifica_a_schermo \
    "${ws}"
  handson::finish
}

main "$@"
