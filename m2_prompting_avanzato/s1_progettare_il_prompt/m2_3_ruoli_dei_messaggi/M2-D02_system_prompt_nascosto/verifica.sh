#!/bin/bash
#
# verifica.sh di M2-D02 -- il system prompt che non vedete: sistema.tsv
# (intestazione «variante<TAB>token_entrata<TAB>risposta», righe
# predefinito, aggiunto, sostituito) mostra l'esito registrato dal corso:
#   - con una riga al posto del system prompt di Claude Code, i token in
#     entrata scendono a meno della metà;
#   - con la riga in coda, restano almeno quelli del predefinito.
#
# Uso:    verifica.sh <spazio di lavoro>
# Uscita: 0 = esito come registrato · 1 = sistema.tsv assente, incompleto o
#         con un esito diverso · 2 = precondizione (spazio di lavoro
#         assente, sistema.tsv che non si legge)
set -euo pipefail

readonly FILE='sistema.tsv'
readonly INTESTAZIONE=$'variante\ttoken_entrata\trisposta'
readonly VARIANTI=(predefinito aggiunto sostituito)

# Un campo della riga di una variante. Arguments: $1 il file, $2 la
# variante, $3 il numero del campo. Outputs: il campo.
campo() {
  awk -F'\t' -v c="$2" -v f="$3" \
    '{ sub(/\r$/, "") } NR > 1 && $1 == c { v = $f } END { print v }' "$1"
}

main() {
  local ws="${1:-}" prima='' v t tp ta ts ko=0
  if [[ -z "${ws}" || ! -d "${ws}" ]]; then
    echo "verifica: spazio di lavoro assente: ${ws}" >&2
    exit 2
  fi
  if [[ ! -f "${ws}/${FILE}" ]]; then
    echo "Manca ${FILE}: eseguite i passi del README."
    exit 1
  fi
  if [[ ! -r "${ws}/${FILE}" ]]; then
    echo "verifica: ${FILE} non si legge" >&2
    exit 2
  fi
  if ! IFS= read -r prima < "${ws}/${FILE}"; then
    : # file vuoto, o una riga senza a capo finale
  fi
  if [[ "${prima%$'\r'}" != "${INTESTAZIONE}" ]]; then
    echo "${FILE}: la prima riga deve essere l'intestazione" \
      "«variante<TAB>token_entrata<TAB>risposta»."
    exit 1
  fi
  for v in "${VARIANTI[@]}"; do
    t="$(campo "${ws}/${FILE}" "${v}" 2)"
    if [[ ! "${t}" =~ ^[0-9]+$ ]]; then
      echo "Manca il numero di token della variante ${v}."
      ko=1
    fi
  done
  if (( ko != 0 )); then
    exit 1
  fi
  tp="$(campo "${ws}/${FILE}" predefinito 2)"
  ta="$(campo "${ws}/${FILE}" aggiunto 2)"
  ts="$(campo "${ws}/${FILE}" sostituito 2)"
  echo "Token in entrata: predefinito ${tp}, aggiunto ${ta}, sostituito ${ts}."
  if (( 10#${ts} * 2 >= 10#${tp} )); then
    echo "Con il system prompt sostituito attesi meno della metà dei token."
    ko=1
  fi
  if (( 10#${ta} < 10#${tp} )); then
    echo "Con la riga in coda attesi almeno i token del predefinito."
    ko=1
  fi
  if (( ko != 0 )); then
    exit 1
  fi
  echo "Esito come nelle registrazioni del corso."
}

main "$@"
