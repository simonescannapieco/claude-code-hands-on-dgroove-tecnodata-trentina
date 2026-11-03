#!/bin/bash
#
# verifica.sh di M5-E01 «La prima skill» -- I controlli stanno in verifica.py,
# accanto a questo file (python3, già richiesto dal corso). È fatta quando
# tools/controlla_skill.py non trova errori nella skill, il corpo ha una riga
# !`comando` e la prova, prova/stream.jsonl, c'è ed è completa. Stampa come
# dati, che non decidono l'uscita: la chiamata Skill sulla domanda naturale, il
# file cambiato nella risposta, gli strumenti prima della risposta.
#
# Uso:    verifica.sh <spazio di lavoro>
# Env:    PN_HANDSON_ROOT  il repository, per tools/ (tools/verifica.sh lo
#                          imposta)
# Uscita: 0 = fatto · 1 = non ancora (dice che cosa manca) · 2 = precondizione
#         (spazio di lavoro assente, python3 o tools/ che mancano, git che non
#         risponde, un file che non si legge), anche verifica.py uscito con un
#         altro codice
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
