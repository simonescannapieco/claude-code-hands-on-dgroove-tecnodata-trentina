#!/bin/bash
#
# verifica.sh di M5-D01 -- lo stesso testo in tre posti. Il controllo sta in
# demo/controlla_costo.py dell'elemento, lo stesso che c'è nello spazio di
# lavoro: legge gli stream in risposte/, quelli che demo/in_classe.sh o
# _docente/live.sh vi hanno copiato, oppure quelli della registrazione del
# corso, stampa la prima richiesta di ogni braccio e dice se la prova conferma
# ciò che Anthropic afferma. I confronti non decidono l'uscita; le segnalazioni
# sì.
#
# Uso:    verifica.sh <spazio di lavoro>
# Uscita: 0 = gli stream si leggono e nessuna segnalazione; l'ultima riga è
#         «Fatto: …» · 1 = risposte/ che manca o senza stream, oppure una
#         segnalazione · 2 = precondizione (spazio di lavoro assente; python3 o
#         il controllo che mancano; uno stream che manca o non si legge; il
#         controllo uscito con un codice fuori dal suo contratto)
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly CONTROLLO="${SELF%/*}/demo/controlla_costo.py"
FATTO='Fatto: ogni affermazione è stata messa alla prova;'
FATTO+=' gli esiti sono qui sopra.'
readonly FATTO

main() {
  local ws="${1:-}" f c=0 rc=0
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
  if [[ ! -d "${ws}/risposte" ]]; then
    echo "Manca la cartella risposte/: eseguite i passi del README."
    exit 1
  fi
  for f in "${ws}/risposte"/*.jsonl; do
    if [[ -e "${f}" ]]; then
      c=1
    fi
  done
  if (( c == 0 )); then
    echo "In risposte/ nessuno stream: eseguite i passi del README."
    exit 1
  fi
  python3 -B -I "${CONTROLLO}" "${ws}/risposte" || rc=$?
  case "${rc}" in
    0) echo "${FATTO}" ;;
    1|2) exit "${rc}" ;;
    *)
      echo "verifica: controlla_costo.py è uscito con ${rc}, fuori dal suo" \
        "contratto: un errore del controllo, non un esito" >&2
      exit 2
      ;;
  esac
}

main "$@"
