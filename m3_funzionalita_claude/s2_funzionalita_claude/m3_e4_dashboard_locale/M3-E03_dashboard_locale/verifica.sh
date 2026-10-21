#!/bin/bash
#
# verifica.sh di M3-E03 -- la dashboard locale, dashboard.html. I controlli
# stanno in verifica.py, accanto a questo file (python3, già richiesto dal
# corso): ricalcola i KPI veri dal file anonimo dello spazio di lavoro con
# kpi_veri.py dell'elemento, legge la pagina con la copia originale del
# controllo (esercizio/controlla_dashboard.py di questo elemento) e non si
# fida degli script dello spazio di lavoro. Stampa anche, come dato, i
# numeri nel testo della pagina, le esecuzioni del controllo registrate in
# controlli_dashboard.log e la frase della guida che l'esercizio mette
# alla prova, senza un esito: il registro lo scrive il controllo, chiunque
# lo esegua, e che l'abbia eseguito Claude lo dicono le chiamate della
# sessione. I dati non decidono l'uscita.
#
# Uso:    verifica.sh <spazio di lavoro>
# Uscita: 0 = dashboard.html c'è, il suo blocco kpi ha i KPI veri e la
#         pagina non carica niente da fuori · 1 = qualcosa manca o non
#         torna · 2 = precondizione (spazio di lavoro assente, python3
#         mancante, un file dell'elemento che manca, il file anonimo dello
#         spazio di lavoro che manca o da cui i KPI non si calcolano), anche
#         verifica.py uscito con un altro codice (un segnale, un errore fuori
#         contratto): mai un «non ancora»
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
