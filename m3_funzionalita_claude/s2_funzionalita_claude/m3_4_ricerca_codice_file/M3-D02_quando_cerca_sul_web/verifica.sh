#!/bin/bash
#
# verifica.sh di M3-D02 -- quando Claude cerca sul web. Il controllo sta in
# demo/conta_ricerche.py dell'elemento, lo stesso che i partecipanti
# lanciano nello spazio di lavoro: legge lo stream-json delle sei chiamate
# di risposte/ (la domanda attuale e quella stabile, tre volte ciascuna, a
# sonnet con il solo WebSearch), stampa quante volte Claude ha chiamato
# WebSearch e che cosa ha cercato, gli altri strumenti come dati, gli
# indirizzi citati e l'inizio di ogni risposta, e dice, coppia per coppia,
# se la prova conferma ciò che Anthropic descrive: Claude cerca quando la
# domanda chiede informazioni attuali, e risponde senza cercare quando
# basta un sapere stabile. Solo una chiamata a WebSearch conta come
# ricerca. Il verdetto si stampa e non fa fallire. Decide dalle chiamate:
# non legge esiti.tsv e non scrive niente (--senza-esiti).
#
# Uso:    verifica.sh <spazio di lavoro>
# Uscita: 0 = le sei chiamate ci sono e si leggono; l'ultima riga è
#         «Fatto: …» · 1 = la cartella risposte/ che manca, o una chiamata
#         che manca o non è lo stream-json riuscito di claude -p · 2 =
#         precondizione (spazio di lavoro assente, python3 o il controllo
#         che mancano, un file che non si legge, il controllo uscito con un
#         codice fuori dal suo contratto)
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly CONTROLLO="${SELF%/*}/demo/conta_ricerche.py"
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
  python3 -B -I "${CONTROLLO}" --senza-esiti "${ws}" || rc=$?
  case "${rc}" in
    0) echo "${FATTO}" ;;
    1|2) exit "${rc}" ;;
    *)
      echo "verifica: conta_ricerche.py è uscito con ${rc}: un errore" \
        "del controllo, non un esito" >&2
      exit 2
      ;;
  esac
}

main "$@"
