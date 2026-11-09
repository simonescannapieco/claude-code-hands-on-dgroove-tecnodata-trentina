#!/bin/bash
#
# verifica.sh di M7-D01 -- cambia solo il system prompt. Il controllo sta in
# demo/controlla_sistema.py dell'elemento, lo stesso che c'è nello spazio di
# lavoro: legge le esecuzioni in risposte/, quelle che demo/in_classe.sh o
# _docente/live.sh vi hanno scritto, oppure quelle della registrazione del
# corso; stampa che cosa è successo in ognuna, il confronto fra i due system
# prompt e le due garanzie sulla memoria. Il confronto è un dato e non decide
# l'uscita; le garanzie sì.
#
# Uso:    verifica.sh <spazio di lavoro>
# Env:    PN_HANDSON_ROOT  il repository (lo dà tools/verifica.sh; default:
#                          la radice sopra la cartella dell'elemento)
# Uscita: 0 = ogni esecuzione c'è, è finita bene e le garanzie valgono;
#         l'ultima riga è «Fatto: …» · 1 = risposte/ che manca o senza
#         esecuzioni, un'esecuzione che manca, uno stream senza il risultato
#         o con un errore, una garanzia che non vale · 2 = precondizione
#         (spazio di lavoro assente; python3 o il controllo che mancano; uno
#         stream che non si legge; il controllo uscito con un codice fuori dal
#         suo contratto)
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly CONTROLLO="${SELF%/*}/demo/controlla_sistema.py"
FATTO='Fatto: ogni esecuzione è stata messa alla prova;'
FATTO+=' gli esiti sono qui sopra.'
readonly FATTO

main() {
  local ws="${1:-}" d c=0 rc=0
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
  for d in "${ws}/risposte"/generico-* "${ws}/risposte"/ciaspolink-* \
      "${ws}/risposte"/memoria-*; do
    if [[ -d "${d}" ]]; then
      c=1
    fi
  done
  if (( c == 0 )); then
    echo "In risposte/ nessuna esecuzione: eseguite i passi del README."
    exit 1
  fi
  python3 -B -I "${CONTROLLO}" "${ws}/risposte" || rc=$?
  case "${rc}" in
    0) echo "${FATTO}" ;;
    1|2) exit "${rc}" ;;
    *)
      echo "verifica: controlla_sistema.py è uscito con ${rc}, fuori dal" \
        "suo contratto: un errore del controllo, non un esito" >&2
      exit 2
      ;;
  esac
}

main "$@"
