#!/bin/bash
#
# verifica.sh di M1-D01 -- la prossima parola. I controlli stanno in
# verifica.py, accanto a questo file (python3, già richiesto dal corso):
# legge risultati.tsv (intestazione «modello<TAB>parola», poi una riga per
# chiamata), stampa per ogni modello le risposte, le parole diverse e le
# risposte di una parola sola, poi un verdetto per ciascuna affermazione di
# Anthropic che la demo mette alla prova:
#   - input identici possono produrre output diversi (il glossario):
#     confermata con almeno due parole diverse, altrimenti non dimostrata
#     in questa esecuzione (un «possono» non si smentisce);
#   - Claude risponde bene a istruzioni chiare ed esplicite (la guida al
#     prompting), sulla parola sola senza punteggiatura che l'istruzione
#     chiede: una raccomandazione, stampata, che non fa fallire la
#     verifica.
#
# Uso:    verifica.sh <spazio di lavoro>
# Uscita: 0 = ognuno dei tre modelli ha almeno una risposta
#         1 = risultati.tsv assente, senza intestazione o con un modello
#             senza risposte
#         2 = precondizione (spazio di lavoro assente, python3 mancante,
#             risultati.tsv che c'è ma non si legge), oppure il controllo
#             uscito in un altro modo (un segnale, un errore)
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly CONTROLLI="${SELF%/*}/verifica.py"

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
  if [[ ! -r "${CONTROLLI}" ]]; then
    echo "verifica: manca ${CONTROLLI}" >&2
    exit 2
  fi
  python3 -B -I "${CONTROLLI}" "${ws}" || rc=$?
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
