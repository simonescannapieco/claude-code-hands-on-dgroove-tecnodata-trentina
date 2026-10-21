#!/bin/bash
#
# verifica.sh di M2-E01 e M2-E02 -- il lavoro di un'esercitazione sui
# prompt. I controlli stanno in verifica.py, accanto a questo file (python3,
# già richiesto dal corso), che prende le regole di misura dal kit
# dell'elemento (esercizio/strumenti/kit.py): v0 giudicata due volte, v1
# diversa da v0, ogni versione misurata e scritta in registro.md con la sua
# pratica (in M2-E02, due famiglie con v2). Poi stampa le misure e l'esito
# di ogni pratica: una pratica non confermata è un risultato, e la verifica
# non fallisce per questo.
#
# Uso:    verifica.sh <spazio di lavoro>
# Uscita: 0 = il lavoro c'è, e ogni giudizio strutturato rispetta lo
#         schema · 1 = qualcosa manca o è da misurare di nuovo, o un
#         giudizio strutturato non rispetta lo schema · 2 = precondizione
#         (spazio di lavoro assente, python3 mancante, un file che c'è ma
#         non si legge), anche verifica.py uscito con un altro codice (un
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
