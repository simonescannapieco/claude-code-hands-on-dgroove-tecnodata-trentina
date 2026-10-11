#!/bin/bash
#
# verifica.sh di M1-D04 -- ogni chiamata riparte da zero: catena.tsv
# (intestazione «chiamata<TAB>token_entrata<TAB>risposta», righe A, B, C)
# mostra l'esito registrato dal corso:
#   - B, una sessione nuova, non nomina la linea LN-000204: non la conosce;
#   - C, la sessione di A ripresa con --resume, la nomina;
#   - C manda al modello più token di A: la conversazione viene rimandata.
# La linea si riconosce anche scritta in minuscolo o con il trattino che
# non va a capo (U+2011); i numeri si leggono in base 10 anche con uno zero
# davanti.
#
# Uso:    verifica.sh <spazio di lavoro>
# Uscita: 0 = esito come registrato · 1 = catena.tsv assente, incompleto o
#         con un esito diverso · 2 = precondizione (spazio di lavoro
#         assente, catena.tsv che non si legge)
set -euo pipefail

readonly FILE='catena.tsv'
readonly INTESTAZIONE=$'chiamata\ttoken_entrata\trisposta'
readonly LINEA='LN-000204'
readonly TRATTINO_U2011=$'\xe2\x80\x91'

# Un campo della riga di una chiamata. Arguments: $1 il file, $2 la
# chiamata (A, B, C), $3 il numero del campo. Outputs: il campo.
campo() {
  awk -F'\t' -v c="$2" -v f="$3" \
    '{ sub(/\r$/, "") } NR > 1 && $1 == c { v = $f } END { print v }' "$1"
}

# Il testo in maiuscolo, con U+2011 al posto del trattino normale.
# Arguments: $1 il testo. Outputs: il testo normalizzato.
normale() {
  local s="${1//"${TRATTINO_U2011}"/-}"
  printf '%s' "${s^^}"
}

main() {
  local ws="${1:-}" prima='' c ta tc rb rc ko=0
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
    : # file vuoto, o una riga senza a capo finale: «prima» tiene ciò che c'è
  fi
  if [[ "${prima%$'\r'}" != "${INTESTAZIONE}" ]]; then
    echo "${FILE}: la prima riga deve essere l'intestazione" \
      "«chiamata<TAB>token_entrata<TAB>risposta»."
    exit 1
  fi
  for c in A B C; do
    if [[ -z "$(campo "${ws}/${FILE}" "${c}" 3)" ]]; then
      echo "Manca la risposta della chiamata ${c}."
      ko=1
    fi
  done
  if (( ko != 0 )); then
    exit 1
  fi
  ta="$(campo "${ws}/${FILE}" A 2)"
  tc="$(campo "${ws}/${FILE}" C 2)"
  rb="$(campo "${ws}/${FILE}" B 3)"
  rc="$(campo "${ws}/${FILE}" C 3)"
  echo "B, sessione nuova: ${rb}"
  echo "C, sessione di A ripresa: ${rc}"
  if [[ "$(normale "${rb}")" == *"${LINEA}"* ]]; then
    echo "B nomina ${LINEA}: una sessione nuova non dovrebbe conoscerla."
    ko=1
  fi
  if [[ "$(normale "${rc}")" != *"${LINEA}"* ]]; then
    echo "C non nomina ${LINEA}: la sessione ripresa dovrebbe ricordarla."
    ko=1
  fi
  if [[ ! "${ta}" =~ ^[0-9]+$ || ! "${tc}" =~ ^[0-9]+$ ]]; then
    echo "Token in entrata di A o di C mancanti o non numerici."
    ko=1
  elif (( 10#${tc} <= 10#${ta} )); then
    echo "C manda ${tc} token, A ${ta}: attesi più token per C."
    ko=1
  else
    echo "Token in entrata: A ${ta}, C ${tc}: la conversazione viene rimandata."
  fi
  if (( ko != 0 )); then
    exit 1
  fi
  echo "Esito come nelle registrazioni del corso."
}

main "$@"
