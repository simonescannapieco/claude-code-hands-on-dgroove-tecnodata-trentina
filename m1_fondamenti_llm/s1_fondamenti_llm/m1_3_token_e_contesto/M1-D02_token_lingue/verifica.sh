#!/bin/bash
#
# verifica.sh di M1-D02 -- stessa frase, due lingue: conteggi.tsv
# (intestazione «modello<TAB>testo<TAB>token_entrata») contiene, per
# almeno un modello, i token in entrata dei quattro testi it, it-doppia,
# en, en-doppia. I token di una frase sono la crescita dal testo singolo
# al testo doppio; la verifica chiede che la frase italiana pesi più della
# sua traduzione inglese, che pesi più di zero: l'esito registrato dal
# corso (27 token contro 17, su Haiku, Sonnet e Opus).
#
# Uso:    verifica.sh <spazio di lavoro>
# Uscita: 0 = per ogni modello completo, italiano > inglese > 0
#         1 = conteggi.tsv assente, senza intestazione, senza un modello
#             completo, oppure un esito diverso
#         2 = precondizione (spazio di lavoro assente, conteggi.tsv che non
#             si legge)
set -euo pipefail

readonly FILE='conteggi.tsv'
readonly INTESTAZIONE=$'modello\ttesto\ttoken_entrata'

main() {
  local ws="${1:-}" prima='' esito riga completi=0 ko=0
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
      "«modello<TAB>testo<TAB>token_entrata»."
    exit 1
  fi
  # Per ogni modello con i quattro testi: i token delle due frasi e il
  # confronto; l'ultima riga, «#esito <completi> <ko>», il conto. Un
  # file salvato con a capo CRLF vale come uno con LF.
  esito="$(awk -F'\t' '
    { sub(/\r$/, "") }
    NR > 1 && $3 ~ /^[0-9]+$/ { t[$1, $2] = $3; m[$1] = 1 }
    END {
      completi = 0; ko = 0
      for (x in m) {
        if (!((x, "it") in t && (x, "it-doppia") in t \
            && (x, "en") in t && (x, "en-doppia") in t)) { continue }
        completi++
        it = t[x, "it-doppia"] - t[x, "it"]
        en = t[x, "en-doppia"] - t[x, "en"]
        if (it > en && en > 0) {
          printf "%s: italiano %d token, inglese %d (+%d %%)\n", \
            x, it, en, int((it - en) * 100 / en + 0.5)
        } else {
          printf "%s: italiano %d token, inglese %d: atteso italiano" \
            " > inglese > 0\n", x, it, en
          ko++
        }
      }
      printf "#esito %d %d\n", completi, ko
    }' "${ws}/${FILE}")"
  while IFS= read -r riga; do
    if [[ "${riga}" == '#esito '* ]]; then
      read -r completi ko <<< "${riga#'#esito '}"
    else
      printf '%s\n' "${riga}"
    fi
  done <<< "${esito}"
  if (( completi == 0 )); then
    echo "Nessun modello con i quattro testi it, it-doppia, en, en-doppia."
    exit 1
  fi
  if (( ko > 0 )); then
    exit 1
  fi
  echo "La frase italiana pesa più della sua traduzione inglese."
}

main "$@"
