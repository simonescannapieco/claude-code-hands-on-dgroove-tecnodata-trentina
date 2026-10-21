#!/bin/bash
#
# verifica.sh di M1-D04 -- ogni chiamata riparte da zero: catena.tsv
# (intestazione «chiamata<TAB>token_entrata<TAB>risposta», righe A, B, C)
# mette alla prova ciò che dice Anthropic (la Messages API è senza stato:
# a ogni richiesta si manda l'intera cronologia), un verdetto per riga:
#   - B, una sessione nuova, non nomina la linea LN-000204: non può
#     conoscerla (garantito);
#   - C, la sessione di A ripresa con --resume, manda al modello più token
#     di A: la cronologia viene rimandata (garantito);
#   - C nomina la linea: un esito della prova, stampato, che non fa
#     fallire la verifica.
# La linea si riconosce anche scritta in minuscolo o con il trattino che
# non va a capo (U+2011); i numeri, al più 12 cifre, si leggono in base 10
# anche con uno zero davanti; l'intestazione anche con un BOM UTF-8 o un a
# capo CRLF.
#
# Uso:    verifica.sh <spazio di lavoro>
# Uscita: 0 = le risposte ci sono e le due garanzie valgono · 1 =
#         catena.tsv assente o incompleto, o una garanzia che in questa
#         esecuzione non vale · 2 = precondizione (spazio di lavoro
#         assente, catena.tsv che non si legge)
set -euo pipefail

readonly FILE='catena.tsv'
readonly INTESTAZIONE=$'chiamata\ttoken_entrata\trisposta'
readonly LINEA='LN-000204'
readonly TRATTINO_U2011=$'\xe2\x80\x91'
readonly BOM=$'\xef\xbb\xbf'
# Un conteggio di token: cifre ASCII, al più 12, come nei controlli in
# Python; un numero più lungo, nell'aritmetica di bash, cambierebbe valore.
readonly NUMERO='^[0-9]{1,12}$'

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
  prima="${prima%$'\r'}"
  prima="${prima#"${BOM}"}"
  if [[ "${prima}" != "${INTESTAZIONE}" ]]; then
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
    echo "B nomina ${LINEA}: la documentazione garantisce che una sessione"
    echo "  nuova non riceva la conversazione di prima; in questa" \
      "esecuzione no."
    ko=1
  else
    echo "B, una sessione nuova, non conosce ${LINEA}: confermata"
  fi
  if [[ ! "${ta}" =~ ${NUMERO} || ! "${tc}" =~ ${NUMERO} ]]; then
    echo "Token in entrata di A o di C mancanti o non numerici."
    ko=1
  elif (( 10#${tc} <= 10#${ta} )); then
    echo "Token in entrata: A ${ta}, C ${tc}: la documentazione garantisce"
    echo "  la cronologia rimandata a ogni richiesta; in questa esecuzione no."
    ko=1
  else
    echo "Token in entrata: A ${ta}, C ${tc}: la cronologia rimandata," \
      "confermata"
  fi
  if [[ "$(normale "${rc}")" == *"${LINEA}"* ]]; then
    echo "C nomina ${LINEA}: confermata"
  else
    echo "C nomina ${LINEA}: non confermata in questa esecuzione"
  fi
  if (( ko != 0 )); then
    exit 1
  fi
  echo "Fatto: ogni affermazione è stata messa alla prova; gli esiti sono" \
    "qui sopra."
}

main "$@"
