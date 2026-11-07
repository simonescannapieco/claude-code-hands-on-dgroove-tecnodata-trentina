#!/bin/bash
#
# verifica.sh di M6-D05 -- la stessa domanda, in un progetto di claude.ai. Il
# controllo sta in demo/controlla_risposte.py dell'elemento, lo stesso che i
# partecipanti trovano nello spazio di lavoro: legge la carta dei servizi e le
# due risposte salvate da claude.ai, risposte/chat.txt e
# risposte/progetto.txt, e stampa come dati le cifre dell'art. 4 della carta
# e gli articoli che ciascuna cita. È una dimostrazione: ciò che fa claude.ai
# si guarda sullo schermo, e nessun dato decide l'uscita. Nessuna chiamata al
# modello.
#
# Uso:    verifica.sh <spazio di lavoro>
# Uscita: 0 = le due risposte ci sono e non sono vuote; l'ultima riga è
#         «Fatto: …» · 1 = una risposta che manca o è vuota · 2 =
#         precondizione (spazio di lavoro assente, python3 o il controllo che
#         mancano, la carta che manca, un file che non si legge o non è testo
#         UTF-8, il controllo uscito con un codice fuori dal suo contratto)
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly CONTROLLO="${SELF%/*}/demo/controlla_risposte.py"
FATTO='Fatto: le due risposte sono salvate. Ciò che dice Anthropic si guarda'
FATTO+=' sullo schermo; le righe (dato) dicono che cosa c'"'"'è nei due file.'
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
      echo "verifica: controlla_risposte.py è uscito con ${rc}: un errore" \
        "del controllo, non un esito" >&2
      exit 2
      ;;
  esac
}

main "$@"
