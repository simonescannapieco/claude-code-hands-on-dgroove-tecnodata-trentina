#!/bin/bash
#
# verifica.sh di M4-D05 -- il controllo che non si salta. Il controllo sta
# in controlla_stop.py, accanto a questo file e fuori dallo spazio di
# lavoro: legge le esecuzioni dei due bracci, esecuzioni/con-hook-<n>/ ed
# esecuzioni/senza-hook-<n>/ (lo stream-json di claude -p e la copia del
# progetto in cui ha lavorato, con le sue impostazioni), che differiscono
# soltanto nello Stop hook che esegue i test. Stampa i blocchi dell'hook,
# gli strumenti, i file cambiati e i test rieseguiti in ogni copia, e dice
# se la prova conferma ciò che Anthropic afferma: l'uscita 2 dello Stop
# hook blocca la fine del turno, una garanzia (con l'hook i test devono
# essere verdi alla fine, salvo il tetto degli otto blocchi di fila;
# altrimenti è una segnalazione e la verifica esce 1); Claude continua
# finché il controllo passa, un comportamento («n su N»); senza l'hook,
# i test verdi alla fine sono un dato. Se in nessuna esecuzione con l'hook
# lo Stop hook ha bloccato, la garanzia non si è potuta mettere alla prova
# e la verifica esce 1. Decide dagli stream e dalle copie, e non scrive
# niente.
#
# Uso:    verifica.sh <spazio di lavoro>
# Uscita: 0 = la coppia c'è, si legge e la garanzia tiene; l'ultima riga è
#         «Fatto: …» · 1 = esecuzioni/ o un braccio che manca,
#         un'esecuzione che non va, una coppia che differisce in più
#         dell'hook, nessun blocco con l'hook, oppure una segnalazione ·
#         2 = precondizione (spazio di
#         lavoro assente, python3 o il controllo che mancano, un file che
#         non si legge, il controllo uscito con un codice fuori dal suo
#         contratto)
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly CONTROLLO="${SELF%/*}/controlla_stop.py"
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
      echo "verifica: controlla_stop.py è uscito con ${rc}: un errore" \
        "del controllo, non un esito" >&2
      exit 2
      ;;
  esac
}

main "$@"
