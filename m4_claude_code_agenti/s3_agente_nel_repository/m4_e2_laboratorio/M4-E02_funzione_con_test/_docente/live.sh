#!/bin/bash
#
# live.sh di M4-E02 -- la prova dal vivo della traccia (a) del laboratorio,
# come la farebbe un partecipante, in due parti. Prima le dipendenze del
# gestionale, come nel punto di partenza del README (tools/php.sh composer
# install -d progetti/gestionale-php, con la copia di php.sh dello spazio
# di lavoro), se vendor/ non c'è. Poi i prompt del README, fra le righe
# «<!-- prompt N -->» e «<!-- /prompt N -->», in claude -p su sonnet,
# effort medium, nello spazio di lavoro e con le sue impostazioni di
# progetto (i due subagent di .claude/agents/, i piani in piani/), senza
# server MCP (--strict-mcp-config):
#   prima parte   il prompt 1 in plan mode (il piano, che resta in piani/);
#                 i prompt 2, 3 e 4 in dontAsk, ripresi con --resume e
#                 l'ID di sessione del turno prima: in -p il piano non si
#                 approva dalla finestra, e il prompt 2 lo approva e
#                 lancia il subagent autore-test; il 3 chiede il revisore;
#                 il 4 NOTA.md e il commit;
#   seconda parte il prompt 5 in una sessione nuova, che riparte da NOTA.md,
#                 come chiede il README; poi, finché la verifica non passa,
#                 fino a due volte il prompt 6 nella stessa sessione. Una
#                 segnalazione sul revisore non si corregge con un seguito:
#                 lì la prova si ferma.
# Gli strumenti consentiti sono quelli che servono ai passi: Read, Write,
# Edit, il comando dei test (la regola allow delle impostazioni), git add e
# git commit per i commit. In -p le regole allow delle impostazioni di una
# cartella mai autorizzata non valgono: per questo le passa tutte qui.
# grep, find e le forme di sola lettura di git (git log, git diff) non
# servono qui: sono comandi di sola lettura, che Claude Code di regola
# esegue senza chiedere. Lo spazio di lavoro dev'essere al punto di
# partenza (git status vuoto, nessun commit dopo il primo): altrimenti
# esce 2 e indica tools/reset_esercizio.sh M4-E02. Ogni turno lascia il
# suo JSON FUORI dallo spazio di lavoro, in PN_LIVE_JSON oppure accanto, in
# <spazio di lavoro>.prova_dal_vivo/: la seconda parte, una sessione nuova,
# non deve poter leggere le risposte della prima. Ne stampa turni del
# modello, durata e token. Poi verifica.sh dell'elemento. Le funzioni
# comuni con il live.sh di M4-E01 stanno in
# m4_claude_code_agenti/_docente/lib_live_m4_e01_e02.sh.
#
# Uso:    _docente/live.sh <spazio di lavoro>
# Env:    le variabili di tools/lib_handson.sh (HANDSON_NO_PAUSE, …)
#         PN_LIVE_JSON   la cartella dei JSON (default: accanto allo spazio
#                        di lavoro, <spazio>.prova_dal_vivo)
#         PN_PHP_SH      un altro strumento per PHP (le prove del docente)
#         PN_CLAUDE_DIR  passa a verifica.sh (le prove del docente)
# Uscita: 0 = verifica.sh passa · 1 = una chiamata a claude fallita, o
#         verifica.sh esce 1 · 2 = precondizione (spazio di lavoro assente
#         o con del lavoro, un file o uno strumento che manca, un prompt
#         che il README non ha, composer che non riesce, la cartella dei
#         JSON dentro lo spazio di lavoro), anche di verifica.sh
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
# lo script sta in <radice>/m4_…/s3_…/m4_e2_…/M4-E02_…/_docente/
readonly RADICE="${SELF%/*/*/*/*/*/*}"
readonly ELEMENTO="${SELF%/_docente/*}"
# shellcheck source=../../../../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"
# shellcheck source=../../../../_docente/lib_live_m4_e01_e02.sh
source "${RADICE}/m4_claude_code_agenti/_docente/lib_live_m4_e01_e02.sh"

# Le variabili che leggono le funzioni live:: della libreria.
readonly LIVE_README="${ELEMENTO}/README.md"
readonly LIVE_CONTROLLO="${ELEMENTO}/verifica.sh"
# shellcheck disable=SC2034  # la legge lib_live_m4_e01_e02.sh
readonly LIVE_MODELLO=sonnet
STRUMENTI='Read,Write,Edit,Bash(tools/php.sh php progetti/gestionale-php/'
STRUMENTI+='vendor/bin/phpunit *),Bash(git add *),Bash(git commit *)'
readonly LIVE_STRUMENTI="${STRUMENTI}"
readonly SEGUITI_MASSIMI=2
readonly SEGNO_REVISORE="non ha tenuto"

# Che cosa dice la verifica: «fatto», «segnalazione» (il revisore) o
# «lavoro». Arguments: $1 lo spazio di lavoro. Outputs: la parola.
# Returns: 2 se la verifica non può girare.
stato_del_lavoro() {
  local out rc=0
  out="$("${LIVE_CONTROLLO}" "$1" 2>&1)" || rc=$?
  if (( rc == 0 )); then
    echo fatto
  elif (( rc != 1 )); then
    return 2
  elif [[ "${out}" == *"${SEGNO_REVISORE}"* ]]; then
    echo segnalazione
  else
    echo lavoro
  fi
}

# I file che servono e i sei prompt del README.
# Globals: PROMPT (vi aggiunge). Arguments: $1 lo spazio di lavoro.
precondizioni() {
  local f n testo
  for f in "${LIVE_README}" "${LIVE_CONTROLLO}" SPECIFICA.md \
      .claude/settings.json .claude/agents/revisore.md \
      .claude/agents/autore-test.md \
      "${LIVE_PROGETTO}/src/Ticket/FiltroTicket.php"; do
    handson::need_file "${f}"
  done
  [[ -d .git ]] || handson::die "$1 non è uno spazio di lavoro preparato"
  for n in 1 2 3 4 5 6; do
    testo="$(live::prompt "${n}")" \
      || handson::die "il README non ha il prompt ${n} fra le righe" \
        "«<!-- prompt ${n} -->» e «<!-- /prompt ${n} -->»"
    PROMPT+=("${testo}")
  done
}

PROMPT=()

main() {
  local ws="${1:-}" php stato n
  [[ -n "${ws}" && -d "${ws}" ]] \
    || handson::die "spazio di lavoro assente: ${ws}"
  cd "${ws}"
  handson::need_tools python3 jq git
  precondizioni "${ws}"
  php="$(live::php "${ws}")" || exit 2
  live::al_punto_di_partenza M4-E02
  handson::need_claude
  handson::note "strumenti consentiti: ${LIVE_STRUMENTI}"
  handson::banner M4-E02 "Una funzione nuova, con i test" \
    "Modulo 4, laboratorio, traccia (a): la prova del partecipante"
  handson::step "Le dipendenze del gestionale"
  live::dipendenze "${php}"
  live::cartella_fuori .
  handson::step "Prima parte, turno 1: il piano, in plan mode"
  HANDSON_PERMISSION_MODE=plan
  live::turno 1 "${PROMPT[0]}"
  HANDSON_PERMISSION_MODE=dontAsk
  for n in 2 3 4; do
    handson::step "Prima parte, turno ${n}: ${PROMPT[n - 1]%%$'\n'*}"
    live::turno "${n}" "${PROMPT[n - 1]}" --resume "${LIVE_SESSIONE}"
  done
  handson::step "Seconda parte, turno 5: una sessione nuova, da NOTA.md"
  live::turno 5 "${PROMPT[4]}"
  for (( n = 6; n < 6 + SEGUITI_MASSIMI; n++ )); do
    stato="$(stato_del_lavoro "${ws}")" \
      || handson::die "la verifica dell'elemento non può girare"
    [[ "${stato}" == "lavoro" ]] || break
    handson::step "Seconda parte, turno ${n}: ${PROMPT[5]%%$'\n'*}"
    live::turno "${n}" "${PROMPT[5]}" --resume "${LIVE_SESSIONE}"
  done
  live::verifica "${ws}"
}

main "$@"
