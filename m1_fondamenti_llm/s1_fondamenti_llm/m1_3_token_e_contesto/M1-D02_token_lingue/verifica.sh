#!/bin/bash
#
# verifica.sh di M1-D02 -- stessa frase, due lingue. I controlli stanno in
# verifica.py, accanto a questo file (python3, già richiesto dal corso):
# legge conteggi.tsv (intestazione «modello<TAB>testo<TAB>token_entrata»)
# e, per ogni modello con i quattro testi it, it-doppia, en, en-doppia,
# stampa il peso delle due frasi (la crescita dal testo singolo al doppio)
# e i caratteri per token, contati in frase_it.txt e frase_en.txt. Poi un
# verdetto per ciascuna affermazione di Anthropic che la demo mette alla
# prova: il numero di token dello stesso testo dipende dalla lingua (i
# prezzi), quanti caratteri vale un token dipende dalla lingua (il
# glossario). Le due dicono «dipende», senza un verso: il confronto con la
# registrazione del corso (la frase italiana più pesante, 27 token contro
# 17, su Haiku, Sonnet e Opus) si stampa, sì o no, e non decide l'uscita.
#
# Uso:    verifica.sh <spazio di lavoro>
# Uscita: 0 = almeno un modello con i quattro conteggi, e ogni modello
#             completo con i due pesi positivi
#         1 = conteggi.tsv assente, senza intestazione, senza un modello
#             completo, oppure un peso che non è positivo (da rifare)
#         2 = precondizione (spazio di lavoro assente, python3 mancante,
#             conteggi.tsv o una delle due frasi che c'è ma non si legge),
#             oppure il controllo uscito in un altro modo (un segnale, un
#             errore)
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
