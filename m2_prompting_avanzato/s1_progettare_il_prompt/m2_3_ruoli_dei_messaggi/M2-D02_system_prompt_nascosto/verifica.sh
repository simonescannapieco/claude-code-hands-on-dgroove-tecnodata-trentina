#!/bin/bash
#
# verifica.sh di M2-D02 -- il system prompt che non vedete. Il controllo
# sta in demo/controlla_sistema.py, accanto (python3, già richiesto dal
# corso): legge sistema.tsv nello spazio di lavoro (intestazione
# «variante<TAB>token_entrata<TAB>risposta», righe predefinito, aggiunto,
# sostituito), stampa i numeri che legge e un esito per ogni affermazione:
#   - due garanzie della documentazione di Claude Code, che decidono
#     l'uscita e confrontano le tre chiamate fra loro: con --system-prompt
#     meno token in entrata del predefinito, benché la riga ci sia; con
#     --append-system-prompt più token in entrata del predefinito;
#   - l'istruzione «Rispondi solo: ok», per ogni variante: una
#     raccomandazione, «rispettata» o «non rispettata in questa
#     esecuzione», che non cambia l'uscita.
#
# Uso:    verifica.sh <spazio di lavoro>
# Uscita: 0 = le tre righe ci sono e le due garanzie sono confermate · 1 =
#         sistema.tsv assente o incompleto, o una garanzia non confermata
#         · 2 = precondizione (spazio di lavoro assente, python3 o il
#         controllo mancanti, sistema.tsv che non si legge)
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly CONTROLLO="${SELF%/*}/demo/controlla_sistema.py"
readonly FATTO="Fatto: ogni affermazione è stata messa alla prova; gli \
esiti sono qui sopra."

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
  python3 -B -I "${CONTROLLO}" "${ws}" || rc=$?
  case "${rc}" in
    0) echo "${FATTO}" ;;
    1|2) exit "${rc}" ;;
    *) echo "verifica: il controllo è uscito con ${rc}" >&2
       exit 2 ;;
  esac
}

main "$@"
