#!/bin/bash
#
# verifica.sh di M8-D04 -- il modello giusto per il lavoro. Il controllo sta in
# demo/controlla_modello.py dell'elemento, lo stesso che c'è nello spazio di
# lavoro: legge le chiamate in risposte/, quelle che demo/in_classe.sh o
# _docente/live.sh vi hanno scritto, oppure quelle della registrazione del
# corso; stampa per ogni modello ed esecuzione le etichette giuste, i token, il
# costo e la durata, e il confronto sul prezzo. Il confronto e l'accuratezza
# sono dati: non decidono l'uscita.
#
# Uso:    verifica.sh <spazio di lavoro>
# Uscita: 0 = ogni esecuzione di ogni modello c'è ed è finita bene; l'ultima
#         riga è «Fatto: …» · 1 = risposte/ che manca o senza esecuzioni,
#         un'esecuzione che manca, con un errore o senza structured_output ·
#         2 = precondizione (spazio di lavoro assente; python3 o il controllo
#         che mancano; un JSON che non si legge; il controllo uscito con un
#         codice fuori dal suo contratto)
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly CONTROLLO="${SELF%/*}/demo/controlla_modello.py"
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
  for d in "${ws}/risposte"/haiku-* "${ws}/risposte"/sonnet-* \
      "${ws}/risposte"/opus-*; do
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
      echo "verifica: controlla_modello.py è uscito con ${rc}, fuori dal" \
        "suo contratto: un errore del controllo, non un esito" >&2
      exit 2
      ;;
  esac
}

main "$@"
