#!/bin/bash
#
# live.sh di M4-E01 -- la prova dal vivo dell'esercitazione, come la farebbe
# un partecipante, in uno spazio di lavoro al punto di partenza (git status
# vuoto, nessun commit dopo il primo: altrimenti esce 2 e indica
# tools/reset_esercizio.sh M4-E01). Prima le dipendenze del gestionale,
# come nel punto di partenza del README (tools/php.sh composer install -d
# progetti/gestionale-php, con la copia di php.sh dello spazio di lavoro),
# se vendor/ non c'è; poi i tre prompt del README, fra le righe
# «<!-- prompt N -->» e «<!-- /prompt N -->», in claude -p su sonnet, effort
# medium, nello spazio di lavoro e con le sue impostazioni di progetto,
# senza server MCP (--strict-mcp-config). Il secondo e il terzo turno
# riprendono la sessione con --resume e l'ID di sessione del JSON del turno
# prima. Gli strumenti consentiti sono quelli che servono ai passi: Read,
# Write, Edit, il comando dei test (la regola allow delle impostazioni
# dello spazio di lavoro). Per cercare, grep e find non servono qui: sono
# comandi di sola lettura, che Claude Code di regola esegue senza chiedere.
# Ogni turno lascia il suo JSON in prova_dal_vivo/turno-<n>.json, una
# cartella che lo script mette in .git/info/exclude dello spazio di lavoro
# (così resta fuori da git status e dalla verifica; dentro, perché la
# registrazione del corso la legge lì), e ne stampa i turni del modello, la
# durata e i token; del terzo turno, le prove chieste, stampa la risposta.
# Poi verifica.sh dell'elemento. Le funzioni comuni con il live.sh di
# M4-E02 stanno in m4_claude_code_agenti/_docente/lib_live_m4_e01_e02.sh.
#
# Uso:    _docente/live.sh <spazio di lavoro>
# Env:    le variabili di tools/lib_handson.sh (HANDSON_NO_PAUSE, …)
#         PN_PHP_SH  un altro strumento per PHP (le prove del docente)
# Uscita: 0 = verifica.sh passa · 1 = una chiamata a claude fallita, o
#         verifica.sh esce 1 · 2 = precondizione (spazio di lavoro assente
#         o con del lavoro, un file o uno strumento che manca, un prompt
#         che il README non ha, composer che non riesce), anche di
#         verifica.sh
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
# lo script sta in <radice>/m4_…/s3_…/m4_e1_…/M4-E01_…/_docente/
readonly RADICE="${SELF%/*/*/*/*/*/*}"
readonly ELEMENTO="${SELF%/_docente/*}"
# shellcheck source=../../../../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"
# shellcheck source=../../../../_docente/lib_live_m4_e01_e02.sh
source "${RADICE}/m4_claude_code_agenti/_docente/lib_live_m4_e01_e02.sh"

# Le variabili che leggono le funzioni live:: della libreria.
# shellcheck disable=SC2034  # le legge lib_live_m4_e01_e02.sh
readonly LIVE_README="${ELEMENTO}/README.md"
# shellcheck disable=SC2034  # le legge lib_live_m4_e01_e02.sh
readonly LIVE_CONTROLLO="${ELEMENTO}/verifica.sh"
# shellcheck disable=SC2034  # le legge lib_live_m4_e01_e02.sh
readonly LIVE_MODELLO=sonnet
STRUMENTI='Read,Write,Edit,Bash(tools/php.sh php progetti/gestionale-php/'
STRUMENTI+='vendor/bin/phpunit *)'
readonly LIVE_STRUMENTI="${STRUMENTI}"

# I file che servono e i tre prompt del README.
# Globals: PROMPT (vi aggiunge). Arguments: $1 lo spazio di lavoro.
precondizioni() {
  local f n testo
  for f in "${LIVE_README}" "${LIVE_CONTROLLO}" .claude/settings.json \
      "${LIVE_PROGETTO}/src/Copertura/VerificaCopertura.php"; do
    handson::need_file "${f}"
  done
  [[ -d .git ]] || handson::die "$1 non è uno spazio di lavoro preparato"
  for n in 1 2 3; do
    testo="$(live::prompt "${n}")" \
      || handson::die "il README non ha il prompt ${n} fra le righe" \
        "«<!-- prompt ${n} -->» e «<!-- /prompt ${n} -->»"
    PROMPT+=("${testo}")
  done
}

PROMPT=()

main() {
  local ws="${1:-}" php n riga
  [[ -n "${ws}" && -d "${ws}" ]] \
    || handson::die "spazio di lavoro assente: ${ws}"
  cd "${ws}"
  handson::need_tools python3 jq git
  precondizioni "${ws}"
  php="$(live::php "${ws}")" || exit 2
  live::al_punto_di_partenza M4-E01
  handson::need_claude
  handson::note "strumenti consentiti: ${LIVE_STRUMENTI}"
  handson::banner M4-E01 "Un file mai visto" \
    "Modulo 4, il riscaldamento del laboratorio: la prova del partecipante"
  handson::step "Le dipendenze del gestionale"
  live::dipendenze "${php}"
  live::cartella_json
  handson::step "Turno 1: la spiegazione"
  live::turno 1 "${PROMPT[0]}"
  for n in 2 3; do
    handson::step "Turno ${n}: ${PROMPT[n - 1]%%$'\n'*}"
    live::turno "${n}" "${PROMPT[n - 1]}" --resume "${LIVE_SESSIONE}"
  done
  handson::step "Le prove chieste al turno 3, come le ha date Claude"
  while IFS= read -r riga; do
    printf '  | %s\n' "${riga}"
  done < <(jq -r '.result // ""' "${LIVE_JSON}/turno-3.json")
  live::verifica "${ws}"
}

main "$@"
