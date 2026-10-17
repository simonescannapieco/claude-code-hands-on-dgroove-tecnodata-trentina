#!/bin/bash
#
# verifica.sh di M2-E01 e M2-E02 -- le misure di un'esercitazione sui
# prompt. I controlli stanno in verifica.py, accanto a questo file (python3,
# già richiesto dal corso): v0 e v1 misurate, il prompt cambiato, la misura
# migliorata, registro.md compilato. Il giudizio lo dà un modello: se la
# verifica dice che una versione non migliora, un altro ciclo è la risposta.
#
# Uso:    verifica.sh <spazio di lavoro>
# Uscita: 0 = misure complete e miglioramento · 1 = qualcosa manca o non
#         migliora · 2 = precondizione (spazio di lavoro assente, python3
#         mancante, un file che c'è ma non si legge)
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly CONTROLLI="${SELF%/*}/verifica.py"

main() {
  local ws="${1:-}"
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
  python3 -B -I "${CONTROLLI}" "${ws}"
}

main "$@"
