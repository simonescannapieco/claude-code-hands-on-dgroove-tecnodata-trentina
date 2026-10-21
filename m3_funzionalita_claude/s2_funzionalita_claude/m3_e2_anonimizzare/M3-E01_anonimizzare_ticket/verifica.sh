#!/bin/bash
#
# verifica.sh di M3-E01 -- il file anonimo, i dati personali rimasti e il
# profilo della settimana. I controlli stanno in verifica.py, accanto a
# questo file (python3, già richiesto dal corso): prende il controllo dei
# dati personali, le sue impronte e il CSV grezzo dalle copie originali in
# esercizio/, i KPI veri da kpi_veri.py, e non si fida delle copie dello
# spazio di lavoro. Stampa anche, come dato, le esecuzioni del controllo
# registrate in anonimo/controlli.log e la frase della guida che
# l'esercizio mette alla prova, senza un esito: il registro lo scrive il
# controllo, chiunque lo esegua, e che l'abbia eseguito Claude lo dicono
# le chiamate della sessione. Il dato non decide l'uscita.
#
# Uso:    verifica.sh <spazio di lavoro>
# Uscita: 0 = il file anonimo, i dati personali rimasti (0) e il profilo
#         sono quelli attesi · 1 = qualcosa manca o non torna · 2 =
#         precondizione (spazio di lavoro assente, python3 mancante, un file
#         originale dell'elemento che manca), anche verifica.py uscito con un
#         altro codice (un segnale, un errore fuori contratto): mai un «non
#         ancora»
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly CONTROLLI="${SELF%/*}/verifica.py"

main() {
  local ws="${1:-}" rc=0
  if [[ -z "${ws}" || ! -d "${ws}" ]]; then
    echo "verifica: spazio di lavoro assente: ${ws}" >&2
    exit 2
  fi
  if ! command -v python3 >/dev/null 2>&1; then
    echo "verifica: manca python3 (PRIMA_DEL_CORSO.md, «Python e uv»)" >&2
    exit 2
  fi
  if [[ ! -r "${CONTROLLI}" ]]; then
    echo "verifica: manca ${CONTROLLI}" >&2
    exit 2
  fi
  python3 -B -I "${CONTROLLI}" "${ws}" || rc=$?
  case "${rc}" in
    0|1|2) exit "${rc}" ;;
    *) echo "verifica: il controllo è uscito con ${rc}" >&2
       exit 2 ;;
  esac
}

main "$@"
