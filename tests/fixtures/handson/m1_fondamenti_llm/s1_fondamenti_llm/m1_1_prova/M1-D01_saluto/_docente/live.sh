#!/bin/bash
#
# live.sh di M1-D01 (albero di prova dei test) -- fa le veci di
# un'esecuzione dal vivo senza chiamare nessun modello: scrive saluto.txt
# nello spazio di lavoro e dice se ANTHROPIC_API_KEY gli è arrivata (mai il
# valore), così i test di run_all.sh vedono che cosa riceve.
#
# Uso:    live.sh <spazio di lavoro>
# Uscita: 0 = fatto · 2 = precondizione (spazio di lavoro assente)
set -euo pipefail

main() {
  local ws="${1:-}"
  if [[ -z "${ws}" || ! -d "${ws}" ]]; then
    echo "live: spazio di lavoro assente: ${ws}" >&2
    exit 2
  fi
  if [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
    echo "live: chiave API presente"
  else
    echo "live: chiave API assente"
  fi
  printf 'ciao\n' > "${ws}/saluto.txt"
}

main "$@"
