#!/bin/bash
#
# verifica.sh di M4-E03 -- il modulo opaco: la documentazione di
# chiusura_mese(), la proposta di refactoring, i test di caratterizzazione e
# il modulo legacy invariato. I controlli stanno in verifica.py, accanto a
# questo file (python3, già richiesto dal corso): i test girano in due copie
# temporanee del progetto, con tools/php.sh del repository, verdi sul modulo
# com'era e rossi su una copia rotta apposta; legacy/ si confronta con il
# primo commit; i subagent delle sessioni di Claude Code, la nota, i piani e
# i commit si stampano come dati, senza decidere l'uscita.
#
# Uso:    verifica.sh <spazio di lavoro>
# Env:    PN_HANDSON_ROOT, PN_PHP_SH, PN_CLAUDE_DIR (vedi verifica.py)
# Uscita: 0 = documentazione e proposta complete, i test verdi sul modulo e
#         rossi sulla copia rotta, legacy/ com'era · 1 = qualcosa manca o
#         non torna (verifica.py dice che cosa) · 2 = precondizione (spazio
#         di lavoro, python3, git, vendor/ o PHP che mancano), anche
#         verifica.py uscito con un codice fuori dal contratto
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly CONTROLLI="${SELF%/*}/verifica.py"

main() {
  local ws="${1:-}" rc=0 t
  if [[ -z "${ws}" || ! -d "${ws}" ]]; then
    echo "verifica: spazio di lavoro assente: ${ws}" >&2
    exit 2
  fi
  for t in python3 git; do
    if ! command -v "${t}" >/dev/null 2>&1; then
      echo "verifica: manca ${t} (PRIMA_DEL_CORSO.md)" >&2
      exit 2
    fi
  done
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
