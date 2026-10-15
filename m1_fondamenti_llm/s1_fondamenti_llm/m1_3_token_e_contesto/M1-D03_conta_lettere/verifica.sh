#!/bin/bash
#
# verifica.sh di M1-D03 -- quante n in «interconnessione»: risposte.tsv
# (intestazione «modello<TAB>domanda<TAB>risposta») contiene, per
# ciascuno dei tre modelli, almeno una risposta alla domanda «conta» e una
# alla domanda «compitata». Le n sono 4: la verifica mostra l'inizio di
# ogni risposta, e il conteggio lo legge chi guarda; un conteggio sbagliato
# è ciò che la demo fa osservare, non un errore della demo.
#
# Uso:    verifica.sh <spazio di lavoro>
# Uscita: 0 = ci sono le risposte dei tre modelli alle due domande
#         1 = risposte.tsv assente, senza intestazione o incompleto
#         2 = precondizione (spazio di lavoro assente, risposte.tsv che non
#             si legge)
set -euo pipefail

readonly FILE='risposte.tsv'
readonly INTESTAZIONE=$'modello\tdomanda\trisposta'
readonly MODELLI=(haiku sonnet opus)
readonly DOMANDE=(conta compitata)
readonly PAROLE=10

# L'inizio di ogni risposta di un modello a una domanda, una per riga: le
# prime PAROLE parole. Si taglia a parole e non a byte, così anche un awk
# che non conosce l'UTF-8 non spezza le lettere accentate.
# Arguments: $1 il file, $2 il modello, $3 la domanda.
# Outputs:   le righe su STDOUT.
inizi() {
  awk -F'\t' -v m="$2" -v d="$3" -v max="${PAROLE}" '
    NR > 1 && $1 == m && $2 == d && $3 != "" {
      n = split($3, w, /[ ]+/); s = ""; k = 0
      for (i = 1; i <= n && k < max; i++) {
        if (w[i] != "") { s = s (k++ ? " " : "") w[i] }
      }
      printf "  «%s%s»\n", s, (n > max ? " …" : "")
    }' "$1"
}

main() {
  local ws="${1:-}" prima='' m d quante ko=0
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
      "«modello<TAB>domanda<TAB>risposta»."
    exit 1
  fi
  for m in "${MODELLI[@]}"; do
    for d in "${DOMANDE[@]}"; do
      quante="$(awk -F'\t' -v m="${m}" -v d="${d}" \
        'NR > 1 && $1 == m && $2 == d && $3 != "" { c++ }
         END { print c + 0 }' "${ws}/${FILE}")"
      if (( quante == 0 )); then
        echo "Nessuna risposta di ${m} alla domanda «${d}»."
        ko=1
      else
        echo "${m}, ${d}:"
        inizi "${ws}/${FILE}" "${m}" "${d}"
      fi
    done
  done
  if (( ko != 0 )); then
    exit 1
  fi
  echo "Le risposte dei tre modelli ci sono (le n sono 4)."
}

main "$@"
