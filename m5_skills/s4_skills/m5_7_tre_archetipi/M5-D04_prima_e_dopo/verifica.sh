#!/bin/bash
#
# verifica.sh di M5-D04 -- prima e dopo, tre archetipi. Il controllo sta in
# demo/controlla_archetipi.py dell'elemento, lo stesso che c'è nello spazio di
# lavoro, e la verità in verita.json dell'elemento, fuori dallo spazio di
# lavoro: le sessioni non la vedono. Legge gli stream di risposte/, stampa i
# dati di ogni esecuzione e dice se la prova conferma ciò che Anthropic afferma.
# Decidono l'uscita soltanto le garanzie: senza la skill, e con la skill spenta
# se c'è il suo set, nessuna chiamata Skill riesce e la skill non è fra le
# disponibili. Il confronto si stampa e non decide.
#
# Uso:    verifica.sh <spazio di lavoro>
# Env:    PN_HANDSON_ROOT  il repository (default: la radice sopra l'elemento)
# Uscita: 0 = almeno una coppia completa, ogni stream si legge, le garanzie
#         tengono; l'ultima riga è «Fatto: …» · 1 = risposte/ che manca, nessuna
#         coppia, una coppia a metà, uno stream incompleto, una garanzia che non
#         regge · 2 = precondizione (spazio di lavoro assente; python3, il
#         controllo o la verità che mancano; il controllo uscito con un codice
#         fuori dal suo contratto)
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly RADICE="${SELF%/*/*/*/*/*}"
readonly CONTROLLO="${SELF%/*}/demo/controlla_archetipi.py"
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
  PN_HANDSON_ROOT="${PN_HANDSON_ROOT:-${RADICE}}" \
    python3 -B -I "${CONTROLLO}" --verita "${VERITA}" "${ws}/risposte" || rc=$?
  case "${rc}" in
    0) echo "${FATTO}" ;;
    1|2) exit "${rc}" ;;
    *)
      echo "verifica: controlla_archetipi.py è uscito con ${rc}, fuori dal" \
        "suo contratto: un errore del controllo, non un esito" >&2
      exit 2
      ;;
  esac
}

main "$@"
