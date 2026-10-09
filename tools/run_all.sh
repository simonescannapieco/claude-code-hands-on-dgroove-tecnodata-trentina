#!/bin/bash
#
# run_all.sh -- la prova di ogni elemento, come la farebbe il docente prima
# del corso: per ogni demo ed esercizio dei manifest (o per gli ID dati)
# prepara uno spazio di lavoro usa e getta e prova che
#   1. verifica.sh FALLISCE (uscita 1) sul punto di partenza intatto:
#      l'elemento chiede davvero un lavoro;
#   2. verifica.sh PASSA (uscita 0) dopo che vi si applica soluzione/: i
#      suoi file copiati sopra lo spazio di lavoro, oppure, se c'è,
#      soluzione/applica.sh <spazio di lavoro>;
#   3. con --live, in uno spazio di lavoro nuovo, _docente/live.sh
#      <spazio di lavoro> esce 0 e dopo di lui verifica.sh passa:
#      l'esecuzione dal vivo, scritta con l'elemento. Senza live.sh, o per
#      un elemento trainer-api senza ANTHROPIC_API_KEY, la riga dice SKIP;
#      ai live.sh degli altri elementi arriva un ambiente senza
#      ANTHROPIC_API_KEY, così Claude Code usa l'abbonamento.
# Uno SKIP non è un superamento: il riepilogo li conta a parte. Nella
# copia per i partecipanti (senza soluzione/) il passo 2 è SKIP.
# Con i manifest senza nessun elemento -- il repository prima dei moduli
# -- stampa «0 item(s)» ed esce 0. Un modulo o un manifest assente o con
# l'intestazione sbagliata, un ID sconosciuto, un'opzione sbagliata sono
# invece una precondizione. Le prove stanno in lib_handson.sh
# (handson::prove_solution, handson::prove_live).
#
# Uso:    tools/run_all.sh [--live] [ID ...]
# Env:    PN_HANDSON_ROOT  il repository (default: la cartella sopra tools/)
#         PN_LIVE_LOGS     una cartella esistente: con --live vi resta
#                          l'uscita di ogni live.sh, in <ID>.log
# Uscita: 0 = nessun elemento KO · 1 = almeno un elemento KO
#         2 = precondizione
set -uo pipefail          # raccoglie gli esiti di tutti gli elementi

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
# shellcheck source=lib_handson.sh
source "${SELF%/*}/lib_handson.sh"

LIVE=0
N_OK=0
N_KO=0
N_SKIP=0

usage() {
  cat <<'EOF'
Uso: tools/run_all.sh [--live] [ID ...]
  --live   esegue anche _docente/live.sh di ogni elemento
  ID       solo questi elementi (default: tutti quelli dei manifest)
EOF
}

# Una riga KO con le ultime righe del log, rientrate.
# Globals: N_KO. Arguments: $1 id, $2 il motivo, $3 il log.
esito_ko() {
  local r
  printf '  %-8s KO: %s\n' "$1" "$2"
  while IFS= read -r r; do
    printf '      | %s\n' "${r}"
  done < <(tail -n 15 "$3")
  N_KO=$((N_KO + 1))
}

# Prova un elemento (passi 1-3) e stampa la sua riga.
# Globals: N_OK, N_SKIP, LIVE. Arguments: $1 id.
prova_elemento() {
  local id="$1" log rc riga
  handson::tmpfile log
  if ! handson::find_item "${id}" > "${log}" 2>&1; then
    esito_ko "${id}" "la riga del manifest o la cartella non vanno" "${log}"
    return 0
  fi
  local item="${HANDSON_ITEM_DIR}" env="${HANDSON_ITEM_ENV}"
  handson::prove_solution "${id}" "${item}" "${log}"
  rc=$?
  case "${rc}" in
    0) riga="ok" ;;
    3) riga="ok · soluzione SKIP (copia per i partecipanti)"
       N_SKIP=$((N_SKIP + 1)) ;;
    *) esito_ko "${id}" "${HANDSON_MOTIVO}" "${log}"; return 0 ;;
  esac
  if (( LIVE == 1 )); then
    handson::prove_live "${id}" "${item}" "${env}" "${log}"
    rc=$?
    case "${rc}" in
      0) riga+=" · live ok (${HANDSON_DURATA} s)" ;;
      3) riga+=" · live SKIP: ${HANDSON_MOTIVO}"; N_SKIP=$((N_SKIP + 1)) ;;
      *) esito_ko "${id}" "live: ${HANDSON_MOTIVO}" "${log}"; return 0 ;;
    esac
  fi
  printf '  %-8s %s\n' "${id}" "${riga}"
  N_OK=$((N_OK + 1))
}

main() {
  local arg esito=OK
  local -a dati=()
  for arg in "$@"; do
    case "${arg}" in
      -h|--help) usage; exit 0 ;;
      --live) LIVE=1 ;;
      -*) handson::err "opzione sconosciuta: ${arg}"; usage >&2; exit 2 ;;
      *) dati+=("${arg}") ;;
    esac
  done
  handson::need_tools git
  handson::init_root || exit 2
  if [[ -n "${PN_LIVE_LOGS:-}" && ! -d "${PN_LIVE_LOGS}" ]]; then
    handson::err "PN_LIVE_LOGS non è una cartella: ${PN_LIVE_LOGS}"
    exit 2
  fi
  if (( ${#dati[@]} == 0 )); then
    handson::collect_ids || exit 2
  fi
  for arg in ${dati[@]+"${dati[@]}"}; do
    handson::find_item "${arg}" || exit 2
    HANDSON_IDS+=("${arg}")
  done
  if (( ${#HANDSON_IDS[@]} == 0 )); then
    printf 'run_all: 0 item(s) nei manifest: niente da provare.\n'
    exit 0
  fi
  for arg in "${HANDSON_IDS[@]}"; do
    prova_elemento "${arg}"
  done
  (( N_KO == 0 )) || esito=KO
  printf '\nrun_all: %d item(s): %d ok, %d KO, %d SKIP' \
    "${#HANDSON_IDS[@]}" "${N_OK}" "${N_KO}" "${N_SKIP}"
  printf ' (uno SKIP non è un superamento) -- ESITO: %s\n' "${esito}"
  (( N_KO == 0 )) || exit 1
}

main "$@"
