#!/bin/bash
#
# verifica.sh di M1-D05 -- la circolare che non esiste. Il controllo sta in
# demo/controlla_citazioni.py (python3, già richiesto dal corso), lo stesso
# che i partecipanti lanciano nello spazio di lavoro: legge le dodici
# risposte di risposte/ (domanda A o B, senza regole o con le regole,
# haiku, sonnet, opus), stampa i numeri che legge e, per ogni modello, un
# verdetto per ciascuna delle tre affermazioni messe alla prova. Le
# confronta con la circolare e con le domande di demo/, non con le copie
# dello spazio di lavoro, e non scrive niente (--senza-esiti). Le tre
# affermazioni sono raccomandazioni di Anthropic, non garanzie: i verdetti
# si stampano e non fanno fallire la verifica.
#
# Uso:    verifica.sh <spazio di lavoro>
# Uscita: 0 = le dodici risposte ci sono; l'ultima riga è «Fatto: ogni
#             affermazione è stata messa alla prova; gli esiti sono qui
#             sopra.»
#         1 = manca una risposta, o una è incompleta (il controllo dice
#             quale)
#         2 = precondizione (spazio di lavoro assente, python3 mancante, un
#             file che c'è ma non si legge), oppure il controllo uscito in
#             un altro modo (un segnale, un errore)
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly CONTROLLO="${SELF%/*}/demo/controlla_citazioni.py"

main() {
  local ws="${1:-}" rc=0
  if [[ -z "${ws}" || ! -d "${ws}" ]]; then
    echo "verifica: spazio di lavoro assente: ${ws}" >&2
    exit 2
  fi
  if ! command -v python3 >/dev/null 2>&1; then
    echo "verifica: manca python3 (PRIMA_DEL_CORSO.md, «Python e uv»)" >&2
    exit 2
  fi
  if [[ ! -r "${CONTROLLO}" ]]; then
    echo "verifica: manca ${CONTROLLO}" >&2
    exit 2
  fi
  python3 -B -I "${CONTROLLO}" --senza-esiti "${ws}" || rc=$?
  case "${rc}" in
    0|1|2) exit "${rc}" ;;
    *)
      echo "verifica: il controllo è uscito con ${rc}: un errore, non un" \
        "esito" >&2
      exit 2
      ;;
  esac
}

main "$@"
