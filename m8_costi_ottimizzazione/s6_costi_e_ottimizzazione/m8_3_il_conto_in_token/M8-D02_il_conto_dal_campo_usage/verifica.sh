#!/bin/bash
#
# verifica.sh di M8-D02 «Il conto dal campo usage». Il controllo sta in
# demo/controlla_conto.py dell'elemento, lo stesso che c'è nello spazio di
# lavoro: legge i JSON in risposte/, quelli che demo/in_classe.sh o
# _docente/live.sh vi hanno scritto, oppure quelli della registrazione del
# corso; stampa il conto di ogni esecuzione e il confronto fra le coppie. Il
# confronto è un dato e non decide l'uscita.
#
# Uso:    verifica.sh <spazio di lavoro>
# Env:    PN_HANDSON_ROOT  il repository (lo dà tools/verifica.sh; default:
#                          la radice sopra la cartella dell'elemento)
# Uscita: 0 = ogni esecuzione c'è, è finita bene; l'ultima riga è «Fatto: …»
#         · 1 = risposte/ che manca o senza esecuzioni, un'esecuzione che
#         manca, una chiamata fallita o su un altro modello · 2 = precondizione
#         (spazio di lavoro assente; python3 o il controllo che mancano; un
#         JSON che non si legge; il controllo uscito con un codice fuori dal
#         suo contratto)
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly CONTROLLO="${SELF%/*}/demo/controlla_conto.py"
FATTO='Fatto: ogni esecuzione è stata letta; il conto e il confronto sono'
FATTO+=' qui sopra.'
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
  for d in "${ws}/risposte"/breve-* "${ws}/risposte"/lunga-*; do
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
      echo "verifica: controlla_conto.py è uscito con ${rc}, fuori dal" \
        "suo contratto: un errore del controllo, non un esito" >&2
      exit 2
      ;;
  esac
}

main "$@"
