#!/bin/bash
#
# verifica.sh di M3-D04 -- una chat senza memoria. Il controllo sta in
# demo/controlla_memoria.py dell'elemento, lo stesso che i partecipanti
# trovano nello spazio di lavoro: legge codice.txt e le due risposte
# copiate da claude.ai (risposta-con-memoria.txt,
# risposta-senza-memoria.txt), ne stampa l'inizio e dice l'esito di due
# affermazioni di Anthropic sulla memoria:
#   - Claude può ricordare il contesto delle chat e portarlo nelle
#     conversazioni nuove (la risposta con la memoria contiene il codice):
#     un «può», che si stampa e non fa fallire;
#   - in una chat senza memoria Claude non usa la memoria e non cerca
#     nelle chat passate (la risposta senza memoria non contiene il
#     codice): una garanzia, che fa fallire se non tiene.
# Decide dalle risposte e non scrive niente.
#
# Uso:    verifica.sh <spazio di lavoro>
# Uscita: 0 = le due risposte ci sono e la garanzia tiene; l'ultima riga è
#         «Fatto: …» · 1 = codice.txt o una risposta che manca o è vuota,
#         o la garanzia che non tiene · 2 = precondizione (spazio di lavoro
#         assente, python3 o il controllo che mancano, codice.txt senza la
#         forma attesa, un file che non si legge o non è testo UTF-8, il
#         controllo uscito con un codice fuori dal suo contratto)
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly CONTROLLO="${SELF%/*}/demo/controlla_memoria.py"
FATTO='Fatto: ogni affermazione è stata messa alla prova;'
FATTO+=' gli esiti sono qui sopra.'
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
  if [[ ! -f "${CONTROLLO}" || ! -r "${CONTROLLO}" ]]; then
    echo "verifica: manca il controllo ${CONTROLLO}" >&2
    exit 2
  fi
  python3 -B -I "${CONTROLLO}" "${ws}" || rc=$?
  case "${rc}" in
    0) echo "${FATTO}" ;;
    1|2) exit "${rc}" ;;
    *)
      echo "verifica: controlla_memoria.py è uscito con ${rc}: un errore" \
        "del controllo, non un esito" >&2
      exit 2
      ;;
  esac
}

main "$@"
