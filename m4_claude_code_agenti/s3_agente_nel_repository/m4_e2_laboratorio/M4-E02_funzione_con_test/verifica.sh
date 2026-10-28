#!/bin/bash
#
# verifica.sh di M4-E02 «Una funzione nuova, con i test» -- il filtro dei
# ticket per apparato e per date, con i suoi test. I controlli stanno in
# verifica.py, accanto a questo file (python3, già richiesto dal corso):
# legge lo spazio di lavoro con git, a partire dal suo primo commit, ed
# esegue PHPUnit con tools/php.sh del repository, non con la copia dello
# spazio di lavoro. Decidono l'uscita: la suite intera e i test nuovi che
# passano sul codice dello spazio di lavoro, i test nuovi che falliscono in
# una copia del gestionale al primo commit (il giudice valido), e la
# garanzia del revisore di sola lettura, letta nella sua trascrizione.
# Stampa come dati, che non decidono l'uscita: NOTA.md, i commit, i file
# cambiati, le sessioni di Claude Code dello spazio di lavoro e le chiamate
# al tool Agent.
#
# Uso:    verifica.sh <spazio di lavoro>
# Env:    PN_HANDSON_ROOT  il repository, per tools/php.sh (lo imposta
#                          tools/verifica.sh)
#         PN_PHP_SH        un altro strumento per PHP (le prove del docente)
#         PN_CLAUDE_DIR    al posto di ~/.claude (le prove del docente)
# Uscita: 0 = la suite passa e i test nuovi falliscono sul codice di
#         partenza · 1 = qualcosa manca o non passa, o il revisore ha
#         modificato file · 2 = precondizione (spazio di lavoro assente,
#         python3 mancante, git, il gestionale, lo strumento per PHP,
#         vendor/, PHP che non si avvia, una trascrizione che non si
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
