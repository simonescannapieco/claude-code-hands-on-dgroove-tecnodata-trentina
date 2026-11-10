#!/bin/bash
#
# in_classe.sh -- M8-D04 «Il modello giusto per il lavoro», dal vivo. Otto
# ticket dell'assistenza di CiaspoLink (ticket.jsonl) vanno a Claude tutti in un
# prompt (prompt.txt, con i ticket numerati al posto di @@TICKET@@: componi.py),
# con una chiamata di claude -p per ogni modello (haiku, sonnet, opus), effort
# low, con --json-schema: la risposta è l'elenco delle otto etichette, in
# structured_output. Le chiamate differiscono soltanto nel modello; ognuna è una
# sessione nuova, da una cartella temporanea vuota, fuori dallo spazio di
# lavoro. I JSON vanno in risposte/<modello>-<n>/risposta.json, il prompt
# composto in risposte/prompt-composto.txt; poi controlla_modello.py li
# confronta. Ogni comando si vede prima di girare (handson::claude_p).
#
# Uso:    <cartella dell'elemento>/demo/in_classe.sh <spazio di lavoro>
#           lo spazio di lavoro appena preparato (tools/prepara_esercizio.sh
#           M8-D04), con git status pulito e senza risposte/
# Env:    PN_ESECUZIONI    quante esecuzioni per modello, da 1 a 9 (default 1)
#         PN_HANDSON_ROOT  il repository (default: dal percorso di questo
#                          file; dalla copia nello spazio di lavoro va data)
#         le variabili di tools/lib_handson.sh (HANDSON_NO_PAUSE, …)
# Uscita: 0 = ogni chiamata è finita e il controllo ha letto ogni esecuzione ·
#         1 = una chiamata fallita, o un'esecuzione che manca o senza output
#         strutturato · 2 = precondizione
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
# lo script sta in <radice>/m8_…/s6_…/m8_4_…/M8-D04_…/demo/
readonly RADICE="${PN_HANDSON_ROOT:-${SELF%/*/*/*/*/*/*}}"
[[ -f "${RADICE}/tools/lib_handson.sh" ]] || { echo "in_classe.sh: non" \
  "trovo tools/lib_handson.sh in ${RADICE}: lanciatelo dal repository, o" \
  "date PN_HANDSON_ROOT" >&2; exit 2; }
# shellcheck source=../../../../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"

readonly ELEMENTO=M8-D04
readonly RISPOSTE=risposte
readonly MODELLI=(haiku sonnet opus)
readonly NECESSARI=(prompt.txt ticket.jsonl schema-etichette.json listino.json
  componi.py controlla_modello.py .claude/settings.json)
readonly ESECUZIONI="${PN_ESECUZIONI:-1}"
readonly SISTEMA="Sei un classificatore di ticket di assistenza clienti."
# shellcheck disable=SC2034  # la legge handson::claude_p
HANDSON_OUTPUT_FORMAT='json'
CARTELLE=''
PROMPT=''
SCHEMA=''

# Una chiamata fallita: la demo finisce con uscita 1.
# Arguments: il testo del verdetto.
fallita() {
  handson::verdict ko "$*"
  handson::finish
}

# Una chiamata: il prompt composto al modello, da una cartella vuota.
# Globals: CARTELLE, PROMPT, SCHEMA.
# Arguments: $1 il modello, $2 il numero dell'esecuzione.
una_chiamata() {
  local modello="$1" nome="$1-$2" cartella
  cartella="$(mktemp -d "${CARTELLE}/chiamata.XXXXXX")" \
    || handson::die "mktemp non riesce a creare una cartella"
  handson::step "${nome}: gli otto ticket, su ${modello}"
  mkdir -- "${RISPOSTE}/${nome}" || handson::die "mkdir non riesce"
  (
    cd -- "${cartella}" || exit 2
    handson::claude_p "${modello}" '' "${PROMPT}" --tools '' \
      --system-prompt "${SISTEMA}" --json-schema "${SCHEMA}" --effort low \
      --strict-mcp-config --no-session-persistence
  ) < /dev/null > "${RISPOSTE}/${nome}/risposta.json" \
    || fallita "${nome}: claude -p è fallito"
}

# Lo schema di schema-etichette.json su una riga sola (è la stessa cosa, e sul
# comando a schermo si legge). Globals: SCHEMA (assegnata).
carica_schema() {
  SCHEMA="$(python3 -B -I - <<'PY'
import json
print(json.dumps(json.load(open("schema-etichette.json", encoding="utf-8")),
                 ensure_ascii=False))
PY
)" || handson::die "schema-etichette.json non si legge"
}

# Le precondizioni, prima di ogni chiamata. Va chiamata nello spazio di
# lavoro. Globals: PROMPT, SCHEMA (assegnate).
precondizioni() {
  local f radice segno stato
  [[ "${HANDSON_ENV}" == claude-code-pro ]] \
    || handson::die "${ELEMENTO} è un elemento claude-code-pro: HANDSON_ENV" \
      "«${HANDSON_ENV}» non vale qui"
  handson::need_tools python3 git
  radice="$(git rev-parse --show-toplevel 2> /dev/null)" || radice=''
  segno="$(git config --get corso.elemento 2> /dev/null)" || segno=''
  [[ "${radice}" == "$(pwd -P)" && "${segno}" == "${ELEMENTO}" ]] \
    || handson::die "$(pwd -P) non è lo spazio di lavoro di ${ELEMENTO}:" \
      "preparatelo con tools/prepara_esercizio.sh ${ELEMENTO}"
  for f in "${NECESSARI[@]}"; do handson::need_file "${f}"; done
  stato="$(git status --porcelain)" || handson::die "git status non riesce"
  [[ ! -e "${RISPOSTE}" && -z "${stato}" ]] \
    || handson::die "lo spazio di lavoro non è al punto di partenza (c'è" \
      "${RISPOSTE}/, o git status non è vuoto):" \
      "tools/reset_esercizio.sh ${ELEMENTO}"
  [[ "${ESECUZIONI}" =~ ^[1-9]$ ]] \
    || handson::die "PN_ESECUZIONI: da 1 a 9, non «${ESECUZIONI}»"
  PROMPT="$(python3 -B -I componi.py "$(pwd -P)")" \
    || handson::die "non riesco a comporre il prompt dei ticket"
  carica_schema
  handson::_claude_p_checks haiku "${PROMPT}"
  handson::_claude_key_ok "${PROMPT}"
  handson::need_claude
}

main() {
  local ws="${1:-}" n modello rc=0
  [[ -n "${ws}" && -d "${ws}" ]] \
    || handson::die "spazio di lavoro assente: ${ws}"
  cd -- "${ws}" || handson::die "lo spazio di lavoro ${ws} non si apre"
  precondizioni
  handson::banner "${ELEMENTO}" "Il modello giusto per il lavoro" \
    "Modulo 8, «Il modello giusto»: otto ticket, tre modelli, lo stesso prompt"
  handson::tmpdir CARTELLE
  mkdir -- "${RISPOSTE}" || handson::die "mkdir ${RISPOSTE} non riesce"
  printf '%s\n' "${PROMPT}" > "${RISPOSTE}/prompt-composto.txt" \
    || handson::die "non riesco a scrivere il prompt composto"
  handson::pause "fare le chiamate"
  for (( n = 1; n <= ESECUZIONI; n++ )); do
    for modello in "${MODELLI[@]}"; do
      una_chiamata "${modello}" "${n}"
    done
  done
  handson::step "Che cosa è successo: il controllo legge ogni JSON"
  handson::run python3 -B -I controlla_modello.py "${RISPOSTE}" < /dev/null \
    || rc=$?
  handson::verdict_rc "${rc}" "il controllo, sulle chiamate di ${RISPOSTE}/"
  handson::finish
}

main "$@"
