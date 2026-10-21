#!/bin/bash
#
# verifica.sh di M2-D01 -- prompt A contro prompt B. Il controllo sta in
# demo/controlla_istruzioni.py, accanto (python3, già richiesto dal corso):
# legge confronto.tsv nello spazio di lavoro (intestazione
# «prompt<TAB>token_entrata<TAB>token_uscita<TAB>risposta», righe A e B),
# stampa i numeri che legge e un esito per ogni affermazione:
#   - cinque istruzioni del prompt B (le cinque colonne della tabella,
#     «non indicato», niente nome, niente telefono, al massimo 120 parole):
#     raccomandazioni, «rispettata» o «non rispettata in questa
#     esecuzione», che non cambiano l'uscita;
#   - la garanzia: B manda più token in entrata di A, perché manda lo
#     stesso messaggio con cinque righe al posto di «Riassumi.».
#
# Uso:    verifica.sh <spazio di lavoro>
# Uscita: 0 = le due risposte ci sono e la garanzia è confermata · 1 =
#         confronto.tsv assente o incompleto, o la garanzia non confermata
#         · 2 = precondizione (spazio di lavoro assente, python3 o il
#         controllo mancanti, confronto.tsv che non si legge)
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly CONTROLLO="${SELF%/*}/demo/controlla_istruzioni.py"
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
