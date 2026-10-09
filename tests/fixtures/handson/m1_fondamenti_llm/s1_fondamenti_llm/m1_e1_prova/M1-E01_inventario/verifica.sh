#!/bin/bash
#
# verifica.sh di M1-E01 (albero di prova dei test) -- l'esercizio chiede di
# contare gli apparati di progetti/rete/inventario.csv (le righe dopo
# l'intestazione) e di scrivere il numero in conteggio.txt.
#
# Uso:    verifica.sh <spazio di lavoro>
# Uscita: 0 = conteggio giusto · 1 = conteggio.txt assente o sbagliato
#         2 = precondizione (spazio di lavoro o inventario assente)
set -euo pipefail

main() {
  local ws="${1:-}" attesi scritto
  if [[ -z "${ws}" || ! -d "${ws}" ]]; then
    echo "verifica: spazio di lavoro assente: ${ws}" >&2
    exit 2
  fi
  if [[ ! -f "${ws}/progetti/rete/inventario.csv" ]]; then
    echo "verifica: manca progetti/rete/inventario.csv" >&2
    exit 2
  fi
  attesi="$(awk 'END { print NR - 1 }' "${ws}/progetti/rete/inventario.csv")"
  if [[ ! -f "${ws}/conteggio.txt" ]]; then
    echo "Manca conteggio.txt."
    exit 1
  fi
  scritto="$(tr -d '[:space:]' < "${ws}/conteggio.txt")"
  if [[ "${scritto}" != "${attesi}" ]]; then
    echo "conteggio.txt dice «${scritto}»: non è il numero degli apparati."
    exit 1
  fi
  echo "Conteggio giusto: ${attesi} apparati."
}

main "$@"
