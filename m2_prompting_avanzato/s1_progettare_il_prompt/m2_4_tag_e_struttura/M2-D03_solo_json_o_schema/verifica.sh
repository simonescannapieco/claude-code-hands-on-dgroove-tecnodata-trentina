#!/bin/bash
#
# verifica.sh di M2-D03 -- solo JSON, o uno schema. Il controllo sta in
# demo/controlla_json.py dell'elemento, lo stesso che i partecipanti
# lanciano nello spazio di lavoro: legge schema.json e le risposte di
# risposte/ dello spazio di lavoro, ne stampa i numeri e l'esito di tre
# affermazioni, e mostra la quarta:
#   1. «Se lo chiedete, il JSON arriva valido e conforme», da provare: si
#      conta, e non decide l'uscita;
#   2. «Con --json-schema, structured_output è validato», garantita;
#   3. «Uno schema non valido fa uscire claude con un errore, all'avvio»,
#      garantita;
#   4. «Lo schema controlla la forma, non il contenuto»: una dimostrazione
#      con un oggetto costruito dal controllo, senza verdetto.
# L'esito è «confermata», «non confermata in questa esecuzione» oppure «non
# distinguibile (perché)», quando manca la risposta che serve. Decide dalle
# risposte: non legge esiti.tsv e non scrive niente (--senza-esiti).
#
# Uso:    verifica.sh <spazio di lavoro>
# Uscita: 0 = ogni risposta c'è e le due garanzie sono confermate; l'ultima
#         riga è «Fatto: …» · 1 = la cartella risposte/ che manca, una
#         risposta che manca o non si legge, una garanzia non confermata ·
#         2 = precondizione (spazio di lavoro assente, python3 o il
#         controllo che mancano, schema.json che non è quello della demo,
#         un file che non si legge, il controllo uscito con un codice fuori
#         dal suo contratto)
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly CONTROLLO="${SELF%/*}/demo/controlla_json.py"
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
      echo "verifica: controlla_json.py è uscito con ${rc}: un errore del" \
        "controllo, non un esito" >&2
      exit 2
      ;;
  esac
}

main "$@"
