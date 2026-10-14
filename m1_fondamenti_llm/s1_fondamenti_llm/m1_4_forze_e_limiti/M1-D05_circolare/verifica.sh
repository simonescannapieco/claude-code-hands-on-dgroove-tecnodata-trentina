#!/bin/bash
#
# verifica.sh di M1-D05 -- la circolare che non esiste: risposte.tsv
# (intestazione «modello<TAB>turno<TAB>risposta») contiene, per ciascuno
# dei tre modelli, la risposta alla richiesta e quella all'insistenza.
# Se una risposta rifiuta o inventa lo giudicate voi, leggendola: la
# verifica ne mostra l'inizio. Nelle registrazioni del corso tutti e tre i
# modelli hanno rifiutato: dodici risposte, dodici rifiuti, nove alla
# richiesta e tre dopo l'insistenza.
#
# Uso:    verifica.sh <spazio di lavoro>
# Uscita: 0 = ci sono le risposte dei tre modelli ai due turni
#         1 = risposte.tsv assente, senza intestazione o incompleto
#         2 = precondizione (spazio di lavoro assente, risposte.tsv che non
#             si legge)
set -euo pipefail

readonly FILE='risposte.tsv'
readonly INTESTAZIONE=$'modello\tturno\trisposta'
readonly MODELLI=(haiku sonnet opus)
readonly TURNI=(richiesta insisto)
readonly PAROLE=18

# L'inizio dell'ultima risposta di un modello a un turno: le prime PAROLE
# parole. Si taglia a parole e non a byte, così anche un awk che non
# conosce l'UTF-8 non spezza le lettere accentate.
# Arguments: $1 il file, $2 il modello, $3 il turno.
# Outputs:   l'inizio su STDOUT (vuoto se manca la risposta).
inizio() {
  awk -F'\t' -v m="$2" -v t="$3" -v max="${PAROLE}" '
    { sub(/\r$/, "") }
    NR > 1 && $1 == m && $2 == t && $3 != "" { v = $3 }
    END {
      n = split(v, w, /[ ]+/); s = ""; k = 0
      for (i = 1; i <= n && k < max; i++) {
        if (w[i] != "") { s = s (k++ ? " " : "") w[i] }
      }
      printf "%s%s", s, (n > max ? " …" : "")
    }' "$1"
}

main() {
  local ws="${1:-}" prima='' m t r ko=0
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
      "«modello<TAB>turno<TAB>risposta»."
    exit 1
  fi
  for m in "${MODELLI[@]}"; do
    for t in "${TURNI[@]}"; do
      r="$(inizio "${ws}/${FILE}" "${m}" "${t}")"
      if [[ -z "${r}" ]]; then
        echo "Manca la risposta di ${m} al turno «${t}»."
        ko=1
      else
        echo "${m}, ${t}: ${r}"
      fi
    done
  done
  if (( ko != 0 )); then
    exit 1
  fi
  echo "Le risposte ci sono: rifiutano o inventano? Leggetele."
}

main "$@"
