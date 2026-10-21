#!/bin/bash
#
# verifica.sh di M3-D01 -- un'immagine leggibile. Il controllo sta in
# demo/controlla_lettura.py dell'elemento, lo stesso che i partecipanti
# lanciano nello spazio di lavoro: legge le dodici risposte di risposte/
# (la stessa tabella di allarmi grande e piccola, haiku e sonnet, tre volte
# ciascuna) con verita.json dello spazio di lavoro, stampa che cosa ha
# letto ogni risposta e se è giusto, e dice, per haiku e per sonnet, se la
# prova conferma tre affermazioni di Anthropic:
#   - due raccomandazioni, il testo importante leggibile e non troppo
#     piccolo e le immagini di almeno 1000×1000 pixel, messe alla prova
#     insieme: la grande letta giusta e la piccola no le conferma;
#   - un «può»: con immagini sotto i 200 pixel Claude può sbagliare; un
#     valore sbagliato sulla piccola lo conferma, un «non leggibile» è un
#     rifiuto e non lo conferma.
# I verdetti si stampano e non fanno fallire: sono raccomandazioni e un
# «può». Decide dalle risposte: non legge esiti.tsv e non scrive niente
# (--senza-esiti).
#
# Uso:    verifica.sh <spazio di lavoro>
# Uscita: 0 = le dodici risposte ci sono e si leggono; l'ultima riga è
#         «Fatto: …» · 1 = la cartella risposte/ che manca, o una risposta
#         che manca o non è il JSON riuscito di claude -p · 2 =
#         precondizione (spazio di lavoro assente, python3 o il controllo
#         che mancano, verita.json che non va, un file che non si legge, il
#         controllo uscito con un codice fuori dal suo contratto)
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly CONTROLLO="${SELF%/*}/demo/controlla_lettura.py"
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
      echo "verifica: controlla_lettura.py è uscito con ${rc}: un errore" \
        "del controllo, non un esito" >&2
      exit 2
      ;;
  esac
}

main "$@"
