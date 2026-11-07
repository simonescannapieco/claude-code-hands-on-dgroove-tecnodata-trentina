#!/bin/bash
#
# verifica.sh di M6-E03 «Un CLAUDE.md per la rete» -- il lavoro del
# laboratorio. I controlli stanno in verifica.py, accanto a questo file, su
# tools/lib_controlla_contesto.py: legge le prove di tools/prova_contesto.sh
# in prove-contesto/, ogni volta da capo, e non scrive niente. Decidono
# l'uscita la garanzia dell'avvio (in base nessun file di istruzioni del
# progetto si carica, in v1 e in v2 il CLAUDE.md della radice sì, dal
# registro dell'hook di ogni esecuzione) e che il lavoro sia fatto: le tre
# versioni con le tre richieste, un CLAUDE.md alla radice, la v2 diversa
# dalla v1. I criteri delle richieste e i confronti li stampa come dati.
#
# Uso:    verifica.sh <spazio di lavoro>
# Env:    PN_HANDSON_ROOT  il repository (lo imposta tools/verifica.sh)
# Uscita: 0 = fatto · 1 = qualcosa manca, o una garanzia non regge · 2 =
#         precondizione (spazio di lavoro assente, python3 mancante,
#         verifica.py assente o uscito con un altro codice, un file che non
#         si legge)
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
