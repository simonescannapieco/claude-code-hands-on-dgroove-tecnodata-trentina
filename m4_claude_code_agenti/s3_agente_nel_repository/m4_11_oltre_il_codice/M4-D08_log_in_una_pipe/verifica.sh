#!/bin/bash
#
# verifica.sh di M4-D08 -- il log in una pipe. Il controllo sta in
# controlla_pipe.py, nella cartella dell'elemento e non nello spazio di
# lavoro, perché porta la verità (gli orari del guasto di martedì 8
# settembre su olt-pergine-01). Legge i due bracci di pipe/: lo stesso
# claude -p con la stessa domanda, che riceve in pipe le righe di
# olt-pergine-01 (sotto il tetto) o il syslog della settimana ripetuto
# (oltre i 10 MB). Stampa, come dati, i byte, le uscite, i token, la
# risposta e i suoi orari contro la verità, e il messaggio del braccio grande;
# poi se la prova conferma la garanzia di Anthropic: oltre i 10 MB Claude
# Code esce con un errore chiaro e un'uscita diversa da zero. È una
# garanzia: se non è confermata, la verifica esce 1. Gli orari non decidono
# l'uscita. Non chiama claude e non scrive niente.
#
# Uso:    verifica.sh <spazio di lavoro>
# Uscita: 0 = i due bracci ci sono, il filtrato è riuscito e la garanzia è
#         confermata; l'ultima riga è «Fatto: …» · 1 = un braccio che manca o
#         non va, o la garanzia non confermata · 2 = precondizione (spazio
#         di lavoro assente, python3 o il controllo che mancano, un file
#         che non si legge, il controllo uscito con un codice fuori dal suo
#         contratto)
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly CONTROLLO="${SELF%/*}/controlla_pipe.py"
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
      echo "verifica: controlla_pipe.py è uscito con ${rc}: un errore" \
        "del controllo, non un esito" >&2
      exit 2
      ;;
  esac
}

main "$@"
