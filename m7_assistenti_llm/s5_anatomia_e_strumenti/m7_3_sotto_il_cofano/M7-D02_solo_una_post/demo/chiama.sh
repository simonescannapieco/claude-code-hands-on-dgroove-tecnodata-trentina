#!/bin/bash
#
# chiama.sh -- M7-D02 «Solo una POST», dal vivo: la richiesta di corpo.json
# alla Messages API, con curl, e la risposta salvata in risposte/:
# risposta.json, il corpo, e stato.txt, lo stato HTTP. Il comando si vede prima
# di girare; la chiave non si vede mai: arriva a curl in una configurazione
# sullo STDIN («curl --config -»), mai fra gli argomenti e mai in un file. Poi
# controlla_risposta.py stampa la risposta, campo per campo.
#
# Uso:    <cartella dell'elemento>/demo/chiama.sh <spazio di lavoro>
#           lo spazio di lavoro appena preparato (tools/prepara_esercizio.sh
#           M7-D02), senza risposte/
# Env:    ANTHROPIC_API_KEY  la chiave del docente, obbligatoria: letta solo
#                            da qui, mai stampata né scritta in un file
#         PN_HANDSON_ROOT    il repository (default: dal percorso di questo
#                            file; dalla copia nello spazio di lavoro va data)
#         HANDSON_NO_PAUSE   1 = nessuna pausa (tools/lib_handson.sh)
# Uscita: 0 = la risposta c'è, è riuscita e ha stop_reason e usage · 1 = curl
#         non è riuscito, oppure il controllo dice che la risposta non è
#         riuscita o non ha quei campi · 2 = precondizione (spazio di lavoro,
#         chiave, curl o il corpo della richiesta che mancano)
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
# lo script sta in <radice>/m7_…/s5_…/m7_3_…/M7-D02_…/demo/
readonly RADICE="${PN_HANDSON_ROOT:-${SELF%/*/*/*/*/*/*}}"
[[ -f "${RADICE}/tools/lib_handson.sh" ]] || { echo "chiama.sh: non trovo" \
  "tools/lib_handson.sh in ${RADICE}: lanciatelo dal repository, o date" \
  "PN_HANDSON_ROOT" >&2; exit 2; }
# shellcheck source=../../../../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"

readonly ELEMENTO=M7-D02
readonly URL='https://api.anthropic.com/v1/messages'
readonly VERSIONE_API='2026-10-21'
readonly MAX_SECONDI=60
readonly RISPOSTE=risposte

# Toglie ciò che una chiamata interrotta ha lasciato in risposte/, così si
# può rilanciare lo script.
togli_risposte() {
  rm -f -- "${RISPOSTE}/risposta.json" "${RISPOSTE}/stato.txt"
  rmdir -- "${RISPOSTE}" 2> /dev/null || handson::note "${RISPOSTE}/ resta"
}

# La POST: la riga di autorizzazione arriva a curl sullo STDIN, con --config -,
# così non è un argomento (ps) e non finisce in un file; il resto del comando
# si vede prima di girare (handson::run). Il corpo è nel file, lo stato HTTP
# va in stato.txt e il corpo della risposta in risposta.json. Se curl non
# riesce, verdetto KO e fine: uscita 1.
posta() {
  local -a comando=(curl --silent --show-error --max-time "${MAX_SECONDI}"
    --request POST --config - --header "anthropic-version: ${VERSIONE_API}"
    --header "content-type: application/json" --data-binary @corpo.json
    --output "${RISPOSTE}/risposta.json" --write-out '%{http_code}\n'
    "${URL}")
  mkdir -- "${RISPOSTE}" || handson::die "non riesco a creare ${RISPOSTE}/"
  if ! printf 'header = "Authorization: Bearer %s"\n' \
      "${ANTHROPIC_API_KEY}" \
      | handson::run "${comando[@]}" > "${RISPOSTE}/stato.txt"; then
    togli_risposte
    handson::verdict ko "curl non è riuscito: la richiesta non è arrivata"
    handson::finish
  fi
}

# Le precondizioni, prima della chiamata. Va chiamata nello spazio di lavoro.
precondizioni() {
  local f radice segno
  handson::need_tools curl python3 git
  handson::need_api_key
  [[ "${ANTHROPIC_API_KEY}" =~ ^[A-Za-z0-9_.-]+$ ]] \
    || handson::die "ANTHROPIC_API_KEY ha caratteri che non si possono" \
      "mettere nella configurazione di curl: non la uso"
  radice="$(git rev-parse --show-toplevel 2> /dev/null)" || radice=''
  segno="$(git config --get corso.elemento 2> /dev/null)" || segno=''
  [[ "${radice}" == "$(pwd -P)" && "${segno}" == "${ELEMENTO}" ]] \
    || handson::die "$(pwd -P) non è lo spazio di lavoro di ${ELEMENTO}:" \
      "preparatelo con tools/prepara_esercizio.sh ${ELEMENTO}"
  for f in corpo.json controlla_risposta.py; do handson::need_file "${f}"; done
  [[ ! -e "${RISPOSTE}" ]] \
    || handson::die "${RISPOSTE}/ c'è già: lo spazio di lavoro non è al" \
      "punto di partenza (tools/reset_esercizio.sh ${ELEMENTO})"
  python3 -B -I -c 'import json, sys
json.load(open(sys.argv[1], encoding="utf-8"))' corpo.json 2> /dev/null \
    || handson::die "corpo.json non è un JSON valido"
}

main() {
  local ws="${1:-}" rc=0
  [[ -n "${ws}" && -d "${ws}" ]] \
    || handson::die "spazio di lavoro assente: ${ws}"
  cd -- "${ws}" || handson::die "lo spazio di lavoro ${ws} non si apre"
  precondizioni
  handson::banner "${ELEMENTO}" "Solo una POST" \
    "Modulo 7, «Sotto il cofano»: la richiesta che sta sotto un assistente"
  handson::step "Il corpo della richiesta"
  handson::run cat -- corpo.json
  handson::step "La POST, con curl"
  handson::note "la chiave arriva a curl sullo STDIN (--config -): non" \
    "compare sulla riga di comando, e non si scrive in nessun file"
  handson::pause "fare la POST"
  posta
  handson::step "La risposta, campo per campo"
  handson::run python3 -B -I controlla_risposta.py "${RISPOSTE}" \
    < /dev/null || rc=$?
  handson::verdict_rc "${rc}" "la risposta, in ${RISPOSTE}/"
  handson::finish
}

main "$@"
