#!/bin/bash
#
# verifica.sh di M2-D04 -- zero-shot contro few-shot: etichette.tsv
# (intestazione «modello<TAB>variante<TAB>risposta», sei righe: haiku e
# sonnet per zero-shot, few-shot, con-etichette) mostra l'esito registrato
# dal corso:
#   - con gli esempi, la risposta prende la forma degli esempi:
#     «categoria | priorità | team», in minuscolo e con il trattino basso;
#   - con l'elenco delle etichette, usa solo etichette ammesse.
# Quale categoria sceglie senza l'elenco lo giudicate voi, leggendola.
#
# Uso:    verifica.sh <spazio di lavoro>
# Uscita: 0 = esito come registrato · 1 = etichette.tsv assente, incompleto
#         o con un esito diverso · 2 = precondizione (spazio di lavoro
#         assente, etichette.tsv che non si legge)
set -euo pipefail

readonly FILE='etichette.tsv'
readonly INTESTAZIONE=$'modello\tvariante\trisposta'
readonly MODELLI=(haiku sonnet)
readonly VARIANTI=(zero-shot few-shot con-etichette)
readonly FORMA='^[a-z_]+ \| [a-z_]+ \| [a-z_]+$'
readonly CATEGORIE=' assenza_connessione lentezza connessione_instabile wifi
  router_configurazione telefonia_voip hotspot rete_aziendale fatturazione
  attivazione copertura trasloco informazioni reclamo '
readonly PRIORITA=' bassa media alta urgente '
readonly TEAM=' primo_livello noc tecnici_campo voce servizi_it
  amministrazione commerciale assistente_virtuale '

# La risposta di un modello a una variante, senza un'eventuale
# «Classificazione:» davanti. Arguments: $1 il file, $2 il modello, $3 la
# variante. Outputs: la risposta.
risposta() {
  awk -F'\t' -v m="$2" -v v="$3" '{ sub(/\r$/, "") }
    NR > 1 && $1 == m && $2 == v { r = $3 } END {
      sub(/^[Cc]lassificazione:[ ]*/, "", r); print r }' "$1"
}

main() {
  local ws="${1:-}" prima='' m v r c p t ko=0
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
      "«modello<TAB>variante<TAB>risposta»."
    exit 1
  fi
  for m in "${MODELLI[@]}"; do
    for v in "${VARIANTI[@]}"; do
      r="$(risposta "${ws}/${FILE}" "${m}" "${v}")"
      if [[ -z "${r}" ]]; then
        echo "Manca la risposta di ${m} a ${v}."
        ko=1
        continue
      fi
      echo "${m}, ${v}: ${r}"
      if [[ "${v}" != zero-shot && ! "${r}" =~ ${FORMA} ]]; then
        echo "  attesa la forma degli esempi: categoria | priorità | team."
        ko=1
      elif [[ "${v}" == con-etichette ]]; then
        IFS='|' read -r c p t <<< "${r// /}"
        if [[ "${CATEGORIE}" != *" ${c}"[[:space:]]* \
            || "${PRIORITA}" != *" ${p} "* || "${TEAM}" != *" ${t}"[[:space:]]* ]]
        then
          echo "  con l'elenco attese solo etichette ammesse."
          ko=1
        fi
      fi
    done
  done
  if (( ko != 0 )); then
    exit 1
  fi
  echo "Esito come nelle registrazioni del corso."
}

main "$@"
