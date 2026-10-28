#!/bin/bash
#
# verifica.sh di M4-D06 -- delegare la lettura. Il controllo sta in
# demo/controlla_delega.py dell'elemento, lo stesso che c'è nello spazio di
# lavoro, e la verità in verita.json dell'elemento, fuori dallo spazio di
# lavoro: le sessioni non la vedono. Legge gli stream delle coppie in
# risposte/ (la stessa domanda sui log, delegando la lettura al subagent
# Explore o leggendo da sé), stampa i dati di ogni esecuzione e dice se la
# prova conferma ciò che Anthropic afferma:
#   - la garanzia: la conversazione principale vede soltanto il risultato
#     del subagent, mai i risultati delle sue chiamate; se no, uscita 1,
#     e uscita 1 anche se nessuna esecuzione con la delega la mette alla
#     prova (nessun subagent al lavoro nello stream);
#   - il confronto: con la delega il contesto principale all'ultima
#     richiesta è più piccolo; il verdetto si stampa e non decide l'uscita.
# I token di tutti i modelli e le risposte contro la verità sono dati.
#
# Uso:    verifica.sh <spazio di lavoro>
# Uscita: 0 = almeno una coppia completa, gli stream si leggono, almeno
#         un'esecuzione mette alla prova la garanzia e la garanzia tiene;
#         l'ultima riga è «Fatto: …» · 1 = risposte/ che manca, nessuna
#         coppia, una coppia a metà, uno stream che non è lo stream-json
#         riuscito di claude -p, la garanzia non confermata o mai messa
#         alla prova ·
#         2 = precondizione (spazio di lavoro assente; python3, il
#         controllo o la verità che mancano; il controllo uscito con un
#         codice fuori dal suo contratto)
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly CONTROLLO="${SELF%/*}/demo/controlla_delega.py"
readonly VERITA="${SELF%/*}/verita.json"
FATTO='Fatto: ogni affermazione è stata messa alla prova;'
FATTO+=' gli esiti sono qui sopra.'
readonly FATTO

main() {
  local ws="${1:-}" f rc=0
  if [[ -z "${ws}" || ! -d "${ws}" ]]; then
    echo "verifica: spazio di lavoro assente: ${ws}" >&2
    exit 2
  fi
  if ! command -v python3 > /dev/null 2>&1; then
    echo "verifica: manca python3 (tools/verifica_ambiente.sh)" >&2
    exit 2
  fi
  for f in "${CONTROLLO}" "${VERITA}"; do
    if [[ ! -f "${f}" || ! -r "${f}" ]]; then
      echo "verifica: manca ${f}" >&2
      exit 2
    fi
  done
  python3 -B -I "${CONTROLLO}" --verita "${VERITA}" "${ws}" || rc=$?
  case "${rc}" in
    0) echo "${FATTO}" ;;
    1|2) exit "${rc}" ;;
    *)
      echo "verifica: controlla_delega.py è uscito con ${rc}, fuori dal" \
        "suo contratto: un errore del controllo, non un esito" >&2
      exit 2
      ;;
  esac
}

main "$@"
