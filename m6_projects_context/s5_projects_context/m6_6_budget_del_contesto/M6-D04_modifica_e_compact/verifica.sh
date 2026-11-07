#!/bin/bash
#
# verifica.sh di M6-D04 -- una modifica a sessione avviata, e dopo /compact.
# Il controllo sta in demo/controlla_sessione.py dell'elemento, lo stesso che
# c'è nello spazio di lavoro: legge gli stream, i registri dell'hook e i passi
# delle sessioni in risposte/, stampa i dati di ogni passo e decide ogni
# garanzia a ogni esecuzione. Una garanzia non confermata, o non messa alla
# prova, fa uscire con 1.
#
# Uso:    verifica.sh <spazio di lavoro>
# Env:    PN_HANDSON_ROOT  il repository (tools/verifica.sh lo dà)
# Uscita: 0 = almeno un'esecuzione completa e ogni garanzia confermata;
#         l'ultima riga è «Fatto: …» · 1 = risposte/ che manca, una sessione
#         che manca o non va, una garanzia non confermata o non distinguibile
#         · 2 = precondizione (spazio di lavoro assente; python3 o il
#         controllo che mancano; il controllo uscito con un codice fuori dal
#         suo contratto)
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly CONTROLLO="${SELF%/*}/demo/controlla_sessione.py"
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
      echo "verifica: controlla_sessione.py è uscito con ${rc}, fuori dal" \
        "suo contratto: un errore del controllo, non un esito" >&2
      exit 2
      ;;
  esac
}

main "$@"
