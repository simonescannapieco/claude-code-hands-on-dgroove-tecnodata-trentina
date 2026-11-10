#!/bin/bash
#
# verifica.sh di M8-E02 -- il lavoro di «Metà dei token, a parità di
# qualità». I controlli stanno in verifica.py, accanto a questo file (python3,
# già richiesto dal corso), che prende le regole di misura dal kit
# dell'elemento (esercizio/strumenti/kit.py): i file del punto di partenza
# fermi, v0 e almeno una versione dopo v0 misurate sui tre casi, con lo stesso
# modello e lo stesso effort, e una versione non peggiore di v0 nei controlli
# e nel giudice. Stampa la riduzione dei token in entrata, la riga
# dell'obiettivo del laboratorio (un dato, non un esito) e l'esito delle due
# frasi di Anthropic che l'esercitazione mette alla prova.
#
# Uso:    verifica.sh <spazio di lavoro>
# Uscita: 0 = il lavoro c'è, e ogni giudizio strutturato rispetta lo schema
#         · 1 = qualcosa manca, nessuna versione è non peggiore di v0, un file
#         del punto di partenza è cambiato, o un giudizio strutturato non
#         rispetta lo schema · 2 = precondizione (spazio di lavoro assente,
#         python3 mancante, un file che c'è ma non si legge), anche
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
