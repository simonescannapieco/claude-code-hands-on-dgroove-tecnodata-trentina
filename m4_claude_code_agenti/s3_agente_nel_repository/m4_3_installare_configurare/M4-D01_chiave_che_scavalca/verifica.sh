#!/bin/bash
#
# verifica.sh di M4-D01 -- la chiave che scavalca il Pro. Il controllo sta
# in demo/controlla_accesso.py dell'elemento, lo stesso che i partecipanti
# lanciano nello spazio di lavoro: legge stato/senza.json e stato/con.json,
# le due esecuzioni di claude auth status --json (senza ANTHROPIC_API_KEY,
# e con la chiave finta del corso impostata per quel solo comando) salvate
# con --salva, che tiene soltanto loggedIn, authMethod e apiKeySource.
# Stampa che cosa dice ciascuna e se la prova conferma ciò che Anthropic
# garantisce: con ANTHROPIC_API_KEY impostata Claude Code usa la chiave al
# posto dell'abbonamento, anche da collegati. È una garanzia: se non è
# confermata, la verifica esce 1. Non chiama claude e non scrive niente.
#
# Uso:    verifica.sh <spazio di lavoro>
# Uscita: 0 = la garanzia confermata; l'ultima riga è «Fatto: …» · 1 = un
#         file di stato/ che manca o non va, o la garanzia non confermata
#         · 2 = precondizione (spazio di lavoro assente, python3 o il
#         controllo che mancano, un file che non si legge, senza la chiave
#         un accesso che non è l'abbonamento, il controllo uscito con un
#         codice fuori dal suo contratto)
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly CONTROLLO="${SELF%/*}/demo/controlla_accesso.py"
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
      echo "verifica: controlla_accesso.py è uscito con ${rc}: un errore" \
        "del controllo, non un esito" >&2
      exit 2
      ;;
  esac
}

main "$@"
