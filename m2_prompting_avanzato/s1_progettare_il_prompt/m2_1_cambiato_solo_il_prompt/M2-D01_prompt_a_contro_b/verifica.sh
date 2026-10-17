#!/bin/bash
#
# verifica.sh di M2-D01 -- è cambiato solo il prompt: confronto.tsv
# (intestazione «prompt<TAB>token_entrata<TAB>token_uscita<TAB>risposta»,
# righe A e B) mostra l'esito registrato dal corso:
#   - B, il prompt di cinque righe, chiede una tabella e di omettere il
#     telefono del cliente: la risposta è una tabella, senza il telefono;
#   - B manda al modello più token di A: il prompt è più lungo.
# Che cosa ha deciso da solo il modello con A lo giudicate voi, leggendola.
#
# Uso:    verifica.sh <spazio di lavoro>
# Uscita: 0 = esito come registrato · 1 = confronto.tsv assente, incompleto
#         o con un esito diverso · 2 = precondizione (spazio di lavoro
#         assente, confronto.tsv che non si legge)
set -euo pipefail

readonly FILE='confronto.tsv'
readonly INTESTAZIONE=$'prompt\ttoken_entrata\ttoken_uscita\trisposta'
readonly TELEFONO='000[ .]?000[ .]?0103'

# Un campo della riga di un prompt. Arguments: $1 il file, $2 il prompt
# (A, B), $3 il numero del campo. Outputs: il campo.
campo() {
  awk -F'\t' -v p="$2" -v f="$3" \
    '{ sub(/\r$/, "") } NR > 1 && $1 == p { v = $f } END { print v }' "$1"
}

main() {
  local ws="${1:-}" prima='' p ta tb rb ko=0
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
      "«prompt<TAB>token_entrata<TAB>token_uscita<TAB>risposta»."
    exit 1
  fi
  for p in A B; do
    if [[ -z "$(campo "${ws}/${FILE}" "${p}" 4)" ]]; then
      echo "Manca la risposta al prompt ${p}."
      ko=1
    fi
  done
  if (( ko != 0 )); then
    exit 1
  fi
  ta="$(campo "${ws}/${FILE}" A 2)"
  tb="$(campo "${ws}/${FILE}" B 2)"
  rb="$(campo "${ws}/${FILE}" B 4)"
  if [[ "${rb}" =~ ${TELEFONO} ]]; then
    echo "La risposta a B ripete il telefono del cliente: B chiede di ometterlo."
    ko=1
  fi
  if [[ "${rb}" != *'|'* ]]; then
    echo "La risposta a B non è una tabella: B la chiede."
    ko=1
  fi
  if [[ ! "${ta}" =~ ^[0-9]+$ || ! "${tb}" =~ ^[0-9]+$ ]]; then
    echo "Token in entrata di A o di B mancanti o non numerici."
    ko=1
  elif (( 10#${tb} <= 10#${ta} )); then
    echo "B manda ${tb} token, A ${ta}: attesi più token per B."
    ko=1
  else
    echo "Token in entrata: A ${ta}, B ${tb}."
  fi
  if (( ko != 0 )); then
    exit 1
  fi
  echo "Esito come nelle registrazioni del corso."
}

main "$@"
