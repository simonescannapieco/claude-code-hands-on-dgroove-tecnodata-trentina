#!/bin/bash
#
# verifica.sh di M2-D03 -- solo JSON, o uno schema: esiti.tsv
# (intestazione «file<TAB>json_valido<TAB>blocco_codice<TAB>telefono<TAB>
# schema_valido», scritto da controlla_json.py) mostra l'esito registrato
# dal corso:
#   - le tre risposte alla richiesta «SOLO un JSON» ci sono (se sono JSON
#     valido, e se hanno il telefono del cliente, lo dicono le colonne);
#   - con --json-schema l'oggetto arriva in structured_output e rispetta lo
#     schema.
#
# Uso:    verifica.sh <spazio di lavoro>
# Uscita: 0 = esito come registrato · 1 = esiti.tsv assente, incompleto o
#         con un esito diverso · 2 = precondizione (spazio di lavoro
#         assente, esiti.tsv che non si legge)
set -euo pipefail

readonly FILE='esiti.tsv'
INTESTAZIONE=$'file\tjson_valido\tblocco_codice\ttelefono'
INTESTAZIONE+=$'\tschema_valido'
readonly INTESTAZIONE
readonly MODELLI=(haiku sonnet opus)

# Un campo della riga di un file. Arguments: $1 il file, $2 il nome nella
# prima colonna, $3 il numero del campo. Outputs: il campo.
campo() {
  awk -F'\t' -v c="$2" -v f="$3" \
    '{ sub(/\r$/, "") } NR > 1 && $1 == c { v = $f } END { print v }' "$1"
}

main() {
  local ws="${1:-}" prima='' m ko=0
  if [[ -z "${ws}" || ! -d "${ws}" ]]; then
    echo "verifica: spazio di lavoro assente: ${ws}" >&2
    exit 2
  fi
  if [[ ! -f "${ws}/${FILE}" ]]; then
    echo "Manca ${FILE}: eseguite i passi del README, fino a" \
      "python3 controlla_json.py."
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
    echo "${FILE}: la prima riga deve essere l'intestazione di" \
      "controlla_json.py."
    exit 1
  fi
  for m in "${MODELLI[@]}"; do
    if [[ -z "$(campo "${ws}/${FILE}" "solo-json-${m}.json" 2)" ]]; then
      echo "Manca la risposta di ${m} alla richiesta «SOLO un JSON»."
      ko=1
    else
      echo "${m}: JSON valido" \
        "$(campo "${ws}/${FILE}" "solo-json-${m}.json" 2)," \
        "telefono $(campo "${ws}/${FILE}" "solo-json-${m}.json" 4)."
    fi
  done
  if [[ "$(campo "${ws}/${FILE}" schema-haiku.json 5)" != "sì" ]]; then
    echo "Con --json-schema atteso un oggetto che rispetta lo schema."
    ko=1
  fi
  if (( ko != 0 )); then
    exit 1
  fi
  echo "Esito come nelle registrazioni del corso."
}

main "$@"
