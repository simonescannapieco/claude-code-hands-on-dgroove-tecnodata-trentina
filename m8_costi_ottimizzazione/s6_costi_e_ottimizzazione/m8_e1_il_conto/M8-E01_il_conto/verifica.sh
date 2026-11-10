#!/bin/bash
#
# verifica.sh di M8-E01 «Quanto costa una risposta». I controlli stanno in
# verifica.py, accanto a questo file: legge risposte/prima.json, listino.json e
# volume.txt dello spazio di lavoro, ricalcola il conto della chiamata e quello
# del mese, stampa il confronto con total_cost_usd come dato e controlla che
# conto.py stampi i due numeri, anche con altri numeri negli stessi file. Non
# chiama niente: nessun modello, nessuna rete.
#
# Uso:    verifica.sh <spazio di lavoro>
# Env:    PN_TIMEOUT_CONTO  i secondi concessi a conto.py, ogni volta (default
#                           20)
# Uscita: 0 = una chiamata riuscita su haiku e conto.py stampa i due numeri ·
#         1 = risposte/prima.json o conto.py che mancano, una chiamata non
#         riuscita o non su haiku, conto.py che non gira, non finisce o non
#         stampa i due numeri · 2 = precondizione (spazio di lavoro assente;
#         python3 o verifica.py che mancano; listino.json, volume.txt o un
#         file che non si leggono; verifica.py uscito con un altro codice)
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
  if ! command -v python3 > /dev/null 2>&1; then
    echo "verifica: manca python3 (tools/verifica_ambiente.sh)" >&2
    exit 2
  fi
  if [[ ! -r "${CONTROLLI}" ]]; then
    echo "verifica: manca ${CONTROLLI}" >&2
    exit 2
  fi
  python3 -B -I "${CONTROLLI}" "${ws}" || rc=$?
  case "${rc}" in
    0|1|2) exit "${rc}" ;;
    *)
      echo "verifica: verifica.py è uscito con ${rc}, fuori dal contratto" >&2
      exit 2
      ;;
  esac
}

main "$@"
