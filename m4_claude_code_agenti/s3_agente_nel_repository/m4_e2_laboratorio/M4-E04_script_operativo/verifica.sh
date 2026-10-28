#!/bin/bash
#
# verifica.sh di M4-E04 «Uno script operativo che gira davvero» -- il
# controllo notturno del gestionale, bin/controllo-notturno.php. I controlli
# stanno in verifica.py, accanto a questo file (python3, già richiesto dal
# corso): esegue lo script con tools/php.sh del repository, non con la
# copia dello spazio di lavoro, in una copia del gestionale; prova il
# controllo dell'esercizio nella sua copia originale, poi i dati di esempio
# in un database costruito dai dati del repository, con le segnalazioni
# attese confrontate per impronta (verita.json), e gli stessi dati senza le
# incoerenze; legge la garanzia del revisore nella sua trascrizione. Stampa
# come dati, che non decidono l'uscita: NOTA.md, i commit, i file cambiati,
# le sessioni di Claude Code, le chiamate al tool Agent, le esecuzioni del
# controllo.
#
# Uso:    verifica.sh <spazio di lavoro>
# Env:    PN_HANDSON_ROOT  il repository, per tools/php.sh e i dati (lo
#                          imposta tools/verifica.sh)
#         PN_PHP_SH        un altro strumento per PHP (le prove del docente)
#         PN_CLAUDE_DIR    al posto di ~/.claude (le prove del docente)
# Uscita: 0 = lo script segue la specifica e trova le incoerenze dei dati di
#         esempio · 1 = qualcosa manca o non torna, o il revisore ha
#         modificato file · 2 = precondizione (spazio di lavoro assente,
#         python3 mancante, lo strumento per PHP, vendor/, i dati del
#         gestionale, PHP che non si avvia, una trascrizione che non si
#         legge), un errore inatteso di verifica.py, anche verifica.py
#         uscito con un altro codice
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
