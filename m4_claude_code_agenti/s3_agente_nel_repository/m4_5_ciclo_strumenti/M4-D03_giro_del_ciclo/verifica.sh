#!/bin/bash
#
# verifica.sh di M4-D03 -- un giro del ciclo, registrato. Il controllo sta
# in controlla_giro.py, accanto a questo file e fuori dallo spazio di
# lavoro: legge lo stream-json di ogni esecuzione di esecuzioni/giro-<n>/,
# stampa le richieste al modello una per una (i token in entrata, gli
# strumenti che ciascuna chiama), i conteggi, i test rieseguiti nella
# copia del progetto come dato, e dice se l'esecuzione conferma ciò che
# Anthropic afferma: ogni richiesta rimanda tutta la conversazione, quindi
# i token in entrata non scendono mai da una richiesta alla successiva
# (tranne dopo una compattazione). È una garanzia del prodotto: una
# discesa è una segnalazione, e la verifica esce 1. Decide dagli stream e
# dalle copie, e non scrive niente.
#
# Uso:    verifica.sh <spazio di lavoro>
# Uscita: 0 = le esecuzioni ci sono, si leggono e la garanzia tiene;
#         l'ultima riga è «Fatto: …» · 1 = esecuzioni/ che manca,
#         un'esecuzione che manca o non va, oppure una segnalazione · 2 =
#         precondizione (spazio di lavoro assente, python3 o il controllo
#         che mancano, un file che non si legge, il controllo uscito con un
#         codice fuori dal suo contratto)
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly CONTROLLO="${SELF%/*}/controlla_giro.py"
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
      echo "verifica: controlla_giro.py è uscito con ${rc}: un errore" \
        "del controllo, non un esito" >&2
      exit 2
      ;;
  esac
}

main "$@"
