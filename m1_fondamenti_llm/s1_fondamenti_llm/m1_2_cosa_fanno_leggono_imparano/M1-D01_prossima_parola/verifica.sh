#!/bin/bash
#
# verifica.sh di M1-D01 -- la demo della prossima parola: risultati.tsv
# (intestazione «modello<TAB>parola», poi una riga per chiamata) contiene
# almeno una risposta di ciascuno dei tre modelli, haiku, sonnet e opus.
# Che le parole di un modello coincidano, o che i modelli concordino, è
# ciò che la demo fa osservare, non un requisito: la verifica le riassume.
#
# Uso:    verifica.sh <spazio di lavoro>
# Uscita: 0 = ci sono le risposte dei tre modelli
#         1 = risultati.tsv assente, senza intestazione o con un modello
#             senza risposte
#         2 = precondizione (spazio di lavoro assente, risultati.tsv che
#             non si legge)
set -euo pipefail

readonly FILE='risultati.tsv'
readonly INTESTAZIONE=$'modello\tparola'
readonly MODELLI=(haiku sonnet opus)

# Le parole di un modello con quante volte compaiono, su una riga.
# Arguments: $1 il file, $2 il modello. Outputs: il riassunto su STDOUT.
riassunto() {
  awk -F'\t' -v m="$2" '
    NR > 1 && $1 == m && $2 != "" {
      if (!($2 in n)) { ordine[++k] = $2 }
      n[$2]++
    }
    END {
      for (i = 1; i <= k; i++) {
        printf "%s«%s» ×%d", (i > 1 ? ", " : ""), ordine[i], n[ordine[i]]
      }
    }' "$1"
}

main() {
  local ws="${1:-}" prima='' m quante ko=0
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
      "«modello<TAB>parola»."
    exit 1
  fi
  for m in "${MODELLI[@]}"; do
    quante="$(awk -F'\t' -v m="${m}" \
      'NR > 1 && $1 == m && $2 != "" { c++ } END { print c + 0 }' \
      "${ws}/${FILE}")"
    if (( quante == 0 )); then
      echo "Nessuna risposta di ${m} in ${FILE}."
      ko=1
    elif (( quante == 1 )); then
      echo "${m}: 1 risposta -- $(riassunto "${ws}/${FILE}" "${m}")"
    else
      echo "${m}: ${quante} risposte -- $(riassunto "${ws}/${FILE}" "${m}")"
    fi
  done
  if (( ko != 0 )); then
    exit 1
  fi
  echo "Le risposte dei tre modelli ci sono."
}

main "$@"
