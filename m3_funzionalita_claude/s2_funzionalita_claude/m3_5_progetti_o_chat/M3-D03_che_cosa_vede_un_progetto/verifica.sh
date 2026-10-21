#!/bin/bash
#
# verifica.sh di M3-D03 -- che cosa vede Claude in un progetto. Il
# controllo sta in demo/controlla_progetto.py dell'elemento, lo stesso che
# i partecipanti trovano nello spazio di lavoro: legge parola.txt e le tre
# risposte copiate da claude.ai (risposta-A.txt, risposta-B.txt,
# risposta-C.txt), ne stampa l'inizio e dice se tengono tre garanzie di
# Anthropic sui progetti:
#   - Claude non vede la descrizione del progetto (prova A: la risposta
#     non contiene la parola);
#   - Claude usa le istruzioni del progetto in tutte le sue chat (prova B:
#     la risposta comincia con la parola);
#   - le istruzioni valgono solo per le chat del progetto (prova C: la
#     risposta non contiene la parola).
# Sono garanzie: una che non tiene fa fallire. Decide dalle risposte e non
# scrive niente.
#
# Uso:    verifica.sh <spazio di lavoro>
# Uscita: 0 = le tre risposte ci sono e le tre garanzie tengono; l'ultima
#         riga è «Fatto: …» · 1 = parola.txt o una risposta che manca o è
#         vuota, o una garanzia che non tiene · 2 = precondizione (spazio
#         di lavoro assente, python3 o il controllo che mancano, parola.txt
#         senza la forma attesa, un file che non si legge o non è testo
#         UTF-8, il controllo uscito con un codice fuori dal suo contratto)
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly CONTROLLO="${SELF%/*}/demo/controlla_progetto.py"
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
      echo "verifica: controlla_progetto.py è uscito con ${rc}: un errore" \
        "del controllo, non un esito" >&2
      exit 2
      ;;
  esac
}

main "$@"
