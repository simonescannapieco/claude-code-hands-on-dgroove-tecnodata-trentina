#!/bin/bash
#
# verifica.sh di M7-D05 -- cercare per significato. Il controllo sta in
# demo/controlla_risultati.py dell'elemento: legge risposte/risultati.json
# dello spazio di lavoro, quello che cerca.py ha scritto, e controlla che ci
# siano tutte le domande di domande.txt con le due classifiche; poi le stampa.
# Non dice niente su Claude e non chiama nessun modello: è fatta quando la
# prova è stata eseguita.
#
# Uso:    verifica.sh <spazio di lavoro>
# Uscita: 0 = risposte/risultati.json c'è, con tutte le domande; l'ultima riga
#         è «Fatto: …» · 1 = il file che manca, che non si legge o a cui manca
#         una domanda · 2 = precondizione (spazio di lavoro assente; python3,
#         il controllo o domande.txt che mancano; il controllo uscito con un
#         codice fuori dal suo contratto)
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly CONTROLLO="${SELF%/*}/demo/controlla_risultati.py"
readonly FATTO='Fatto: le due ricerche sono in risposte/risultati.json.'

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
  python3 -B -I "${CONTROLLO}" "${ws}" || rc=$?
  case "${rc}" in
    0) echo "${FATTO}" ;;
    1|2) exit "${rc}" ;;
    *)
      echo "verifica: controlla_risultati.py è uscito con ${rc}, fuori dal" \
        "suo contratto: un errore del controllo, non un esito" >&2
      exit 2
      ;;
  esac
}

main "$@"
