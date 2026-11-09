#!/bin/bash
#
# verifica.sh di M7-D02 «Solo una POST». Il controllo sta in
# demo/controlla_risposta.py dell'elemento, lo stesso dello spazio di lavoro:
# legge risposte/stato.txt e risposte/risposta.json, quelli che demo/chiama.sh
# o _docente/live.sh vi hanno scritto, oppure quelli della registrazione del
# corso, e dice campo per campo stato, stop_reason e usage. Non chiama niente:
# nessuna rete, nessuna chiave.
#
# Uso:    verifica.sh <spazio di lavoro>
# Env:    PN_HANDSON_ROOT  il repository (lo dà tools/verifica.sh)
# Uscita: 0 = la risposta c'è ed è riuscita, con stop_reason e usage · 1 =
#         risposte/ che manca o senza i suoi file, oppure una risposta che
#         non è un successo o che non ha quei campi · 2 = precondizione
#         (spazio di lavoro assente; python3 o il controllo che mancano; un
#         file che non si legge; il controllo uscito con un codice fuori dal
#         suo contratto)
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly CONTROLLO="${SELF%/*}/demo/controlla_risposta.py"

main() {
  local ws="${1:-}" rc=0
  if [[ -z "${ws}" || ! -d "${ws}" ]]; then
    echo "verifica: spazio di lavoro assente: ${ws}" >&2
    exit 2
  fi
  if ! command -v python3 > /dev/null 2>&1; then
    echo "verifica: manca python3 (tools/verifica_ambiente.sh)" >&2
    exit 2
  fi
  if [[ ! -f "${CONTROLLO}" || ! -r "${CONTROLLO}" ]]; then
    echo "verifica: manca il controllo ${CONTROLLO}" >&2
    exit 2
  fi
  if [[ ! -d "${ws}/risposte" ]]; then
    echo "Manca la cartella risposte/: eseguite i passi del README."
    exit 1
  fi
  python3 -B -I "${CONTROLLO}" "${ws}/risposte" || rc=$?
  case "${rc}" in
    0|1|2) exit "${rc}" ;;
    *)
      echo "verifica: controlla_risposta.py è uscito con ${rc}, fuori dal" \
        "suo contratto: un errore del controllo, non un esito" >&2
      exit 2
      ;;
  esac
}

main "$@"
