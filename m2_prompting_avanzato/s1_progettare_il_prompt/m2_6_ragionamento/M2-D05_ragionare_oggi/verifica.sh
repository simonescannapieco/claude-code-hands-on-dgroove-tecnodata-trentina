#!/bin/bash
#
# verifica.sh di M2-D05 -- ragionare, oggi: ragionamento.tsv, la tabella
# delle sette chiamate dei passi del README (intestazione «modello<TAB>
# effort<TAB>thinking_off<TAB>modello_id<TAB>orario<TAB>token_uscita<TAB>
# token_thinking»), letta da demo/controlla_ragionamento.py dell'elemento:
# prima i numeri, poi una riga per affermazione di Anthropic (V1, una
# garanzia: thinking_tokens minore o uguale a output_tokens; V2, V3, V4:
# confermata, non confermata in questa esecuzione, non dimostrata o non
# distinguibile). L'orario è un dato, mai un verdetto.
#
# Uso:    verifica.sh <spazio di lavoro>
# Uscita: 0 = la tabella è completa e V1 è confermata, qualunque sia
#         l'esito di V2-V4 · 1 = ragionamento.tsv assente o incompleto, o
#         V1 non confermata · 2 = precondizione (spazio di lavoro assente,
#         python3 o il controllo che mancano, ragionamento.tsv che non si
#         legge, un modello che ha risposto diverso da quello della riga)
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly CONTROLLA="${SELF%/*}/demo/controlla_ragionamento.py"
readonly FILE='ragionamento.tsv'
FATTO='Fatto: ogni affermazione è stata messa alla prova; gli esiti sono'
FATTO+=' qui sopra.'
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
  if [[ ! -f "${CONTROLLA}" || ! -r "${CONTROLLA}" ]]; then
    echo "verifica: manca il controllo ${CONTROLLA}" >&2
    exit 2
  fi
  if [[ ! -e "${ws}/${FILE}" ]]; then
    echo "Manca ${FILE}: eseguite i passi del README."
    exit 1
  fi
  if [[ ! -f "${ws}/${FILE}" || ! -r "${ws}/${FILE}" ]]; then
    echo "verifica: ${FILE} non si legge" >&2
    exit 2
  fi
  python3 -B -I "${CONTROLLA}" "${ws}/${FILE}" || rc=$?
  case "${rc}" in
    0) echo "${FATTO}" ;;
    1|2) exit "${rc}" ;;
    *)
      echo "verifica: controlla_ragionamento.py è uscito con ${rc}" >&2
      exit 2
      ;;
  esac
}

main "$@"
