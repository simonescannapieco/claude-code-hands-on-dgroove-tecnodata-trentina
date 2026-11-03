#!/bin/bash
#
# verifica.sh di M5-D03 -- tre garanzie. Il controllo sta in
# demo/controlla_garanzie.py dell'elemento, lo stesso che c'è nello spazio di
# lavoro: legge gli stream delle quattro coppie in risposte/, stampa i dati di
# ogni braccio e decide ogni garanzia a ogni esecuzione. Una garanzia non
# confermata, o una coppia che non mostra la differenza, fa uscire con 1.
#
# Uso:    verifica.sh <spazio di lavoro>
# Uscita: 0 = almeno un'esecuzione completa e ogni garanzia confermata; l'ultima
#         riga è «Fatto: …» · 1 = risposte/ che manca, un'esecuzione a metà, uno
#         stream che non è lo stream-json riuscito di claude -p, una garanzia
#         non confermata, una coppia non distinguibile · 2 = precondizione (spazio
#         di lavoro assente; python3 o il controllo che mancano; il controllo
#         uscito con un codice fuori dal suo contratto)
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly CONTROLLO="${SELF%/*}/demo/controlla_garanzie.py"
FATTO='Fatto: ogni garanzia è stata messa alla prova;'
FATTO+=' gli esiti sono qui sopra.'
readonly FATTO

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
    echo "verifica: manca ${CONTROLLO}" >&2
    exit 2
  fi
  python3 -B -I "${CONTROLLO}" "${ws}" || rc=$?
  case "${rc}" in
    0) echo "${FATTO}" ;;
    1|2) exit "${rc}" ;;
    *)
      echo "verifica: controlla_garanzie.py è uscito con ${rc}, fuori dal suo" \
        "contratto: un errore del controllo, non un esito" >&2
      exit 2
      ;;
  esac
}

main "$@"
