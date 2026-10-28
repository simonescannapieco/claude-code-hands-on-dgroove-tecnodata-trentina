#!/bin/bash
#
# verifica.sh di M4-D07 -- due filoni, due worktree. Il controllo sta in
# controlla_worktree.py, accanto a questo file e fuori dallo spazio di
# lavoro: legge i due bracci di esecuzioni/, senza-worktree/ e
# con-worktree/ (lo stream-json delle due sessioni partite insieme sullo
# stesso file, e la fotografia di git presa subito dopo ogni braccio da
# fotografa.sh), stampa che cosa ha fatto ogni sessione e che cosa c'è in
# ogni checkout e in ogni worktree, e dice se il braccio con i worktree
# conferma ciò che Anthropic afferma di claude -w: un worktree isolato su
# un ramo nuovo, con Claude che parte lì; le modifiche al checkout
# principale bloccate; ogni worktree con la sola modifica della sua
# sessione. Sono garanzie del prodotto: una che non tiene è una
# segnalazione, e la verifica esce 1. Il braccio senza worktree è un dato.
# Decide dagli stream e dalle fotografie, anche dopo la pulizia dei
# worktree, e non scrive niente.
#
# Uso:    verifica.sh <spazio di lavoro>
# Uscita: 0 = i due bracci ci sono, si leggono e le garanzie tengono;
#         l'ultima riga è «Fatto: …» · 1 = esecuzioni/ o un braccio che
#         manca, uno stream o una fotografia che non va, una coppia che non
#         è una coppia, oppure una segnalazione · 2 = precondizione (spazio
#         di lavoro assente, python3 o il controllo che mancano, un file
#         che non si legge, il controllo uscito con un codice fuori dal suo
#         contratto)
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly CONTROLLO="${SELF%/*}/controlla_worktree.py"
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
      echo "verifica: controlla_worktree.py è uscito con ${rc}: un errore" \
        "del controllo, non un esito" >&2
      exit 2
      ;;
  esac
}

main "$@"
