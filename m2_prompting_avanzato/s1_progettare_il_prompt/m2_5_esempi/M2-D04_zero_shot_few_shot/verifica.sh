#!/bin/bash
#
# verifica.sh di M2-D04 -- zero-shot contro few-shot. Il controllo sta in
# demo/controlla_etichette.py dell'elemento, lo stesso che i partecipanti
# lanciano nello spazio di lavoro: legge le otto risposte di risposte/
# (quattro varianti, haiku e sonnet), con schema.json e con-etichette.md
# dello spazio di lavoro, ne stampa i dati e dice, per haiku e per sonnet,
# se la prova conferma tre affermazioni di Anthropic:
#   - gli esempi orientano il formato: la forma degli esempi manca con
#     zero-shot e c'è con few-shot (se c'è già con zero-shot, la prova non
#     distingue);
#   - con l'elenco nel prompt, forma ed etichette rispettate: la risposta
#     di con-etichette ha la forma e solo etichette elencate;
#   - con --json-schema l'oggetto rispetta lo schema.
# Le prime due sono raccomandazioni: l'esito si stampa e non fa fallire.
# La terza è una garanzia: un «no» fa fallire, e un oggetto assente è una
# chiamata fallita. La categoria, la priorità e il team si stampano, mai
# si giudicano. Decide dalle risposte: non legge esiti.tsv e non scrive
# niente (--senza-esiti).
#
# Uso:    verifica.sh <spazio di lavoro>
# Uscita: 0 = le otto risposte ci sono e la garanzia dello schema è
#         confermata su tutti e due i modelli; l'ultima riga è «Fatto: …» ·
#         1 = la cartella risposte/ che manca, una risposta che manca o non
#         va, una chiamata con lo schema fallita, o la garanzia non
#         confermata · 2 = precondizione (spazio di lavoro assente, python3
#         o il controllo che mancano, un enum di schema.json diverso dal suo
#         elenco, un file che non si legge, il controllo uscito con un
#         codice fuori dal suo contratto)
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly CONTROLLO="${SELF%/*}/demo/controlla_etichette.py"
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
  python3 -B -I "${CONTROLLO}" --senza-esiti "${ws}" || rc=$?
  case "${rc}" in
    0) echo "${FATTO}" ;;
    1|2) exit "${rc}" ;;
    *)
      echo "verifica: controlla_etichette.py è uscito con ${rc}: un errore" \
        "del controllo, non un esito" >&2
      exit 2
      ;;
  esac
}

main "$@"
