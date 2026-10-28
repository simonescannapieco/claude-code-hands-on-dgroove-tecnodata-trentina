#!/bin/bash
#
# verifica.sh di M4-E05 «Il rapporto quotidiano dei log» -- lo script del
# rapporto quotidiano dei disservizi, rapporto_giornaliero.py o
# rapporto_giornaliero.sh. I controlli stanno in verifica.py, accanto a
# questo file (python3, già richiesto dal corso): esegue lo script sui log
# originali del repository, copiati in una cartella temporanea; prova il
# controllo dell'esercizio nella sua copia originale, poi martedì 8
# settembre, con il disservizio che la verifica conosce confrontato campo
# per campo per impronta (verita.json), e lunedì 7, un giorno tranquillo;
# legge la garanzia del revisore nella sua trascrizione. Stampa come dati,
# che non decidono l'uscita: gli altri giorni della settimana, NOTA.md, i
# commit, i file cambiati, le sessioni di Claude Code, le chiamate al tool
# Agent, le esecuzioni del controllo.
#
# Uso:    verifica.sh <spazio di lavoro>
# Env:    PN_HANDSON_ROOT  il repository, per i log originali (lo imposta
#                          tools/verifica.sh)
#         PN_CLAUDE_DIR    al posto di ~/.claude (le prove del docente)
# Uscita: 0 = il rapporto segue la specifica, trova il disservizio di
#         martedì e tace lunedì · 1 = qualcosa manca o non torna, o il
#         revisore ha modificato file · 2 = precondizione (spazio di lavoro
#         assente, python3 mancante, i log della rete del repository, un
#         file dell'elemento, una trascrizione che non si legge), un errore
#         inatteso di verifica.py, anche verifica.py uscito con un altro
#         codice
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
