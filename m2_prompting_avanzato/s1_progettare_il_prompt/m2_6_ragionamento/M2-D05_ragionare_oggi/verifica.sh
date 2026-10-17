#!/bin/bash
#
# verifica.sh di M2-D05 -- ragionare, sui modelli di oggi: ragionamento.tsv
# (intestazione «problema<TAB>modello<TAB>variante<TAB>orario<TAB>
# token_uscita<TAB>token_thinking») mostra l'esito registrato dal corso:
# sui modelli di oggi le risposte sono giuste anche di getto, senza
# «ragiona passo passo» -- 9:36 per gli sportelli, 15:30 per le squadre.
# Quanti token di ragionamento ha usato ogni risposta lo dice la tabella.
#
# Uso:    verifica.sh <spazio di lavoro>
# Uscita: 0 = esito come registrato · 1 = ragionamento.tsv assente,
#         incompleto o con un orario diverso · 2 = precondizione (spazio di
#         lavoro assente, ragionamento.tsv che non si legge)
set -euo pipefail

readonly FILE='ragionamento.tsv'
INTESTAZIONE=$'problema\tmodello\tvariante\torario\ttoken_uscita'
INTESTAZIONE+=$'\ttoken_thinking'
readonly INTESTAZIONE
readonly MODELLI=(haiku sonnet opus)

# L'orario di una riga, senza lo zero davanti all'ora.
# Arguments: $1 il file, $2 problema, $3 modello, $4 variante.
orario() {
  awk -F'\t' -v p="$2" -v m="$3" -v v="$4" '{ sub(/\r$/, "") }
    NR > 1 && $1 == p && $2 == m && $3 == v { o = $4 } END {
      sub(/^0/, "", o); print o }' "$1"
}

# Controlla una riga. Arguments: $1 il file, $2 problema, $3 modello,
# $4 variante, $5 l'orario giusto. Returns: 1 se manca o è diverso.
controlla() {
  local o
  o="$(orario "$1" "$2" "$3" "$4")"
  if [[ -z "${o}" ]]; then
    echo "Manca l'orario di ${2}, ${3}, ${4}."
    return 1
  fi
  if [[ "${o}" != "$5" ]]; then
    echo "${2}, ${3}, ${4}: ${o}, atteso ${5}."
    return 1
  fi
  echo "${2}, ${3}, ${4}: ${o}"
}

main() {
  local ws="${1:-}" prima='' m v ko=0
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
    echo "${FILE}: la prima riga deve essere l'intestazione dei passi del" \
      "README."
    exit 1
  fi
  for m in "${MODELLI[@]}"; do
    for v in di-getto passo-passo; do
      controlla "${ws}/${FILE}" sportelli "${m}" "${v}" 9:36 || ko=1
    done
    controlla "${ws}/${FILE}" squadre "${m}" di-getto 15:30 || ko=1
  done
  if (( ko != 0 )); then
    exit 1
  fi
  echo "Esito come nelle registrazioni del corso."
}

main "$@"
