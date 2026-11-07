#!/bin/bash
#
# verifica.sh di M6-E01 «Che cosa vede Claude» -- I controlli stanno in
# verifica.py, accanto a questo file (python3, già richiesto dal corso). È
# fatta quando prima.md e dopo.md sono l'uscita di /context all, il
# CLAUDE.md dello spazio di lavoro sta sotto «Memory files» in dopo.md e non
# in prima.md, e il registro dell'hook InstructionsLoaded,
# .claude/caricamenti.jsonl, ha il suo caricamento all'avvio. Stampa come
# dati, che non decidono l'uscita: la risposta alla domanda e i comandi di
# CLAUDE.md che vi compaiono.
#
# Uso:    verifica.sh <spazio di lavoro>
# Env:    PN_HANDSON_ROOT  il repository, per tools/ (tools/verifica.sh lo
#                          imposta)
# Uscita: 0 = fatto · 1 = non ancora, o una garanzia che in questa
#         esecuzione non tiene (dice che cosa) · 2 = precondizione (spazio
#         di lavoro assente, python3 o tools/ che mancano, un file che non si
#         legge o un'uscita di /context che il controllo non sa leggere),
#         anche verifica.py uscito con un altro codice
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
