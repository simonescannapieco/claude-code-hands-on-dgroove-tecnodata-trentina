#!/bin/bash
#
# verifica.sh di M2-D06 -- la galleria degli orrori: orrori.tsv
# (intestazione «prova<TAB>token_uscita<TAB>telefono<TAB>indennizzo<TAB>
# importi<TAB>risposta») mostra l'esito registrato dal corso:
#   - il divieto «Non menzionare l'indennizzo» è rispettato: la risposta non
#     nomina l'indennizzo, e così non risponde alla domanda del cliente;
#   - la cura, che dice che cosa scrivere sull'indennizzo, lo nomina;
#   - la memoria presunta: in una sessione nuova il modello chiede ciò che
#     gli manca (una domanda, oppure «non ho accesso», «mi serve», «mi
#     servono», «mi manca»).
# Il documento «carino» e le cinque richieste in una li giudicate voi: la
# tabella dice se compaiono il telefono del cliente e importi in euro.
#
# Uso:    verifica.sh <spazio di lavoro>
# Uscita: 0 = esito come registrato · 1 = orrori.tsv assente, incompleto o
#         con un esito diverso · 2 = precondizione (spazio di lavoro
#         assente, orrori.tsv che non si legge)
set -euo pipefail

readonly FILE='orrori.tsv'
INTESTAZIONE=$'prova\ttoken_uscita\ttelefono\tindennizzo\timporti'
INTESTAZIONE+=$'\trisposta'
readonly INTESTAZIONE
readonly PROVE=(orrore-1-vaga orrore-2-divieto cura-2-divieto orrore-3-cinque
  orrore-4-memoria)
readonly CHIEDE='(\?|[Nn]on ho accesso|[Mm]i serv|[Mm]i manca)'

# Un campo della riga di una prova. Arguments: $1 il file, $2 la prova,
# $3 il numero del campo. Outputs: il campo.
campo() {
  awk -F'\t' -v c="$2" -v f="$3" \
    '{ sub(/\r$/, "") } NR > 1 && $1 == c { v = $f } END { print v }' "$1"
}

main() {
  local ws="${1:-}" prima='' p f ko=0
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
  for p in "${PROVE[@]}"; do
    if [[ -z "$(campo "${ws}/${FILE}" "${p}" 6)" ]]; then
      echo "Manca la risposta a ${p}."
      ko=1
    fi
  done
  if (( ko != 0 )); then
    exit 1
  fi
  f="${ws}/${FILE}"
  echo "Documento carino: telefono $(campo "${f}" orrore-1-vaga 3)," \
    "$(campo "${f}" orrore-1-vaga 2) token in uscita."
  echo "Cinque richieste in una: importi in euro" \
    "$(campo "${f}" orrore-3-cinque 5)," \
    "telefono $(campo "${f}" orrore-3-cinque 3)."
  if [[ "$(campo "${f}" orrore-2-divieto 4)" != "no" ]]; then
    echo "Il divieto: atteso che la risposta non nomini l'indennizzo."
    ko=1
  fi
  if [[ "$(campo "${f}" cura-2-divieto 4)" != "sì" ]]; then
    echo "La cura: attesa una risposta che parli dell'indennizzo."
    ko=1
  fi
  if [[ ! "$(campo "${f}" orrore-4-memoria 6)" =~ ${CHIEDE} ]]; then
    echo "La memoria presunta: attesa una risposta che chieda ciò che manca."
    ko=1
  fi
  if (( ko != 0 )); then
    exit 1
  fi
  echo "Esito come nelle registrazioni del corso."
}

main "$@"
