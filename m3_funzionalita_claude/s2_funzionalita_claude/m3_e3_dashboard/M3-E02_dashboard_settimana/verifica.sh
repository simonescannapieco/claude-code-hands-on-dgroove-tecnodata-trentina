#!/bin/bash
#
# verifica.sh di M3-E02 -- i numeri della settimana che avete copiato da
# claude.ai in kpi.json. I controlli stanno in verifica.py, accanto a questo
# file (python3, già richiesto dal corso): calcola i KPI veri dal
# ticket-anonimi.csv dello spazio di lavoro, lo stesso file caricato in
# claude.ai, con kpi_veri.py dell'elemento, mai con una copia dello spazio
# di lavoro. Quanti KPI corrispondono si stampa come dato e non decide
# l'uscita: la decide la forma di kpi.json.
#
# Uso:    verifica.sh <spazio di lavoro>
# Uscita: 0 = kpi.json è un oggetto JSON con le dieci chiavi e i tipi
#         giusti · 1 = kpi.json manca, non è JSON, o ha chiavi o tipi
#         sbagliati · 2 = precondizione (spazio di lavoro assente, python3
#         mancante, un file dell'elemento che manca, ticket-anonimi.csv
#         dello spazio di lavoro che manca o da cui i KPI non si
#         calcolano), anche verifica.py uscito con un altro codice (un
#         segnale, un errore fuori contratto): mai un «non ancora»
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
