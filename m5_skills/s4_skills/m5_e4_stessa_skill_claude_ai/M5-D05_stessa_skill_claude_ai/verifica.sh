#!/bin/bash
#
# verifica.sh di M5-D05 -- la stessa skill in claude.ai. I controlli stanno in
# verifica.py, accanto a questo file: i tre ZIP di pacchetti/ e, se avete fatto
# la prova, risposta_claude_ai.md, i cui criteri si stampano come dati. Nessuna
# chiamata al modello: il caricamento e la skill si guardano sullo schermo.
#
# Uso:    verifica.sh <spazio di lavoro>
# Uscita: 0 = i tre ZIP ci sono, con la forma giusta; l'ultima riga è «Fatto: …»
#         · 1 = uno ZIP che manca o non va, la risposta copiata vuota · 2 =
#         precondizione (spazio di lavoro assente, python3 o i controlli che
#         mancano, una risposta che non si legge, i controlli usciti con un
#         codice fuori dal loro contratto)
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly CONTROLLI="${SELF%/*}/verifica.py"
FATTO='Fatto: i tre ZIP sono pronti; il caricamento e la risposta si guardano'
FATTO+=' su claude.ai.'
readonly FATTO

main() {
  local ws="${1:-}" rc=0
  if [[ -z "${ws}" || ! -d "${ws}" ]]; then
    echo "verifica: spazio di lavoro assente: ${ws}" >&2
    exit 2
  fi
  if ! command -v python3 > /dev/null 2>&1; then
    echo "verifica: manca python3 (tools/verifica_ambiente.sh)" >&2
    exit 2
  fi
  if [[ ! -f "${CONTROLLI}" || ! -r "${CONTROLLI}" ]]; then
    echo "verifica: manca ${CONTROLLI}" >&2
    exit 2
  fi
  python3 -B -I "${CONTROLLI}" "${ws}" || rc=$?
  case "${rc}" in
    0) echo "${FATTO}" ;;
    1|2) exit "${rc}" ;;
    *)
      echo "verifica: verifica.py è uscito con ${rc}: un errore del" \
        "controllo, non un esito" >&2
      exit 2
      ;;
  esac
}

main "$@"
