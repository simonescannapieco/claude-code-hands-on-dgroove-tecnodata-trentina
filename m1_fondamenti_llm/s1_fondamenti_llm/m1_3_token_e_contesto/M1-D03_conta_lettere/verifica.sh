#!/bin/bash
#
# verifica.sh di M1-D03 -- contare le lettere: i controlli stanno in
# demo/controlla_pesi.py, lo stesso script che il passo 4 del README lancia
# nello spazio di lavoro (python3, già richiesto dal corso). Legge
# conteggi.tsv (intestazione «modello<TAB>testo<TAB>token_entrata») e i tre
# testi dello spazio di lavoro; per ogni modello calcola il peso di ogni
# testo, il doppio meno il singolo, e conta da sé le lettere. Stampa i
# numeri, e come dato, senza verdetto, i token per lettera della parola
# compitata; poi una riga per affermazione:
#   1. ogni parola pesa meno token delle sue lettere;
#   2. la parola compitata pesa più token della parola intera;
#   3. gli stessi pesi su ogni modello (con almeno due modelli completi;
#      con uno solo è «non distinguibile» e l'uscita non cambia).
# Sono garanzie: una sola «non confermata» fa uscire 1.
#
# Uso:    verifica.sh <spazio di lavoro>
# Uscita: 0 = ogni modello presente ha i sei conteggi e ogni affermazione
#             messa alla prova è confermata
#         1 = conteggi.tsv assente, senza intestazione, incompleto o con una
#             riga che non torna, oppure un'affermazione non confermata
#         2 = precondizione (spazio di lavoro assente, python3 mancante, un
#             testo mancante, un file che c'è ma non si legge), oppure il
#             controllo uscito in un altro modo (un segnale, un errore)
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly CONTROLLI="${SELF%/*}/demo/controlla_pesi.py"
FATTO='Fatto: ogni affermazione è stata messa alla prova;'
FATTO+=' gli esiti sono qui sopra.'
readonly FATTO

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
    0) echo "${FATTO}" ;;
    1|2) exit "${rc}" ;;
    *)
      echo "verifica: il controllo è uscito con ${rc}: un errore, non un" \
        "esito" >&2
      exit 2
      ;;
  esac
}

main "$@"
