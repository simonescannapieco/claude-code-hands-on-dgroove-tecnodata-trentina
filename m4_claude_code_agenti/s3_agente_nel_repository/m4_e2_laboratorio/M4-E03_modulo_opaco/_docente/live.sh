#!/bin/bash
#
# live.sh di M4-E03 -- la prova dal vivo della traccia (b) del laboratorio,
# come la farebbe un partecipante, in due parti, con i prompt del README
# (fra le righe «<!-- prompt n -->» e «<!-- /prompt n -->»), in claude -p su
# sonnet con effort medium, nello spazio di lavoro e con le sue impostazioni
# di progetto, senza server MCP (--strict-mcp-config):
#   - prima di tutto le dipendenze del gestionale, come nel «Punto di
#     partenza»: tools/php.sh composer install -d progetti/gestionale-php;
#   - la prima parte, una sessione: i prompt 1 (la mappa, con due subagent
#     Explore), 2 (la documentazione), 3 (i test di caratterizzazione) e 4
#     (NOTA.md), ripresi con --resume e l'ID di sessione del JSON; dopo il
#     prompt 3, se i test non sono verdi, fino a due seguiti «Esegui di nuovo
#     i test …»;
#   - la seconda parte, una sessione nuova che parte dalla nota: il prompt 5
#     in plan mode (--permission-mode plan) e poi, ripresa in dontAsk, il
#     messaggio «Il piano è approvato: procedi come dice il piano.», che fa
#     le veci dell'approvazione che il partecipante dà con un clic;
#   - la verifica, come la lancerebbe il partecipante: se dice «Non
#     ancora», un turno in più nella stessa sessione le passa le sue righe
#     «Non ancora: …» e chiede di sistemarle (una volta sola).
# Gli strumenti consentiti: Read, Write, Edit, il comando dei test (la regola
# allow delle impostazioni, che in -p in una cartella mai approvata non vale
# e va ripetuta qui) e i due comandi dei commit, git add e git commit; in
# dontAsk un altro comando che chiederebbe un permesso viene negato, dove il
# partecipante si vede chiedere il permesso; i comandi di sola lettura
# (grep, find, le forme di sola lettura di git), di regola, non lo
# chiedono. Lo spazio di lavoro dev'essere al punto di partenza (git status
# vuoto, nessun commit dopo il primo): altrimenti esce 2 e indica
# tools/reset_esercizio.sh M4-E03. Ogni turno lascia il suo JSON FUORI
# dallo spazio di lavoro, in PN_LIVE_JSON oppure accanto, in <spazio di
# lavoro>.prova_dal_vivo/: la seconda parte, una sessione nuova, non deve
# poter leggere le risposte della prima. Ne stampa i turni del modello, la
# durata e i token. Poi verifica.sh.
#
# Uso:    _docente/live.sh <spazio di lavoro>
# Env:    PN_PHP_SH     il php.sh da usare (default: tools/php.sh del
#                       repository); le variabili di tools/lib_handson.sh
#         PN_LIVE_JSON  la cartella dei JSON (default: accanto allo spazio
#                       di lavoro, <spazio>.prova_dal_vivo)
# Uscita: 0 = verifica.sh passa · 1 = una chiamata a claude fallita, o
#         verifica.sh esce 1 · 2 = precondizione (spazio di lavoro assente
#         o con del lavoro, un file o uno strumento che manca, un prompt
#         che il README non ha, le dipendenze che non si installano, la
#         cartella dei JSON dentro lo spazio di lavoro), anche di
#         verifica.sh
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
# lo script sta in <radice>/m4_…/s3_…/m4_e2_…/M4-E03_…/_docente/
readonly RADICE="${SELF%/*/*/*/*/*/*}"
readonly ELEMENTO="${SELF%/_docente/*}"
readonly CONTROLLO="${ELEMENTO}/verifica.sh"
readonly README="${ELEMENTO}/README.md"
# shellcheck source=../../../../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"
# shellcheck source=lib_prova_dal_vivo.sh
source "${SELF%/*}/lib_prova_dal_vivo.sh"

readonly MODELLO=sonnet
readonly PROGETTO=progetti/gestionale-php
readonly TEST_REL="${PROGETTO}/tests/Integrazione/ChiusuraMeseTest.php"
readonly COMANDO="tools/php.sh php ${PROGETTO}/vendor/bin/phpunit"
STRUMENTI="Read,Write,Edit,Bash(${COMANDO} *),Bash(git add *),"
STRUMENTI+="Bash(git commit *)"
readonly STRUMENTI
readonly PHP_SH="${PN_PHP_SH:-${RADICE}/tools/php.sh}"
# La assegna prova::cartella_json: fuori dallo spazio di lavoro.
CARTELLA_JSON=''
readonly APPROVAZIONE="Il piano è approvato: procedi come dice il piano."
SEGUITO_TEST="Esegui di nuovo i test con ${COMANDO} -c ${PROGETTO}"
SEGUITO_TEST+=" ${TEST_REL}, da solo, senza concatenarlo ad altri, e"
SEGUITO_TEST+=" correggi i test finché passano. Non modificare niente in"
SEGUITO_TEST+=" ${PROGETTO}/legacy/. Poi fai il commit del test."
readonly SEGUITO_TEST
readonly SEGUITI_MASSIMI=2
readonly CORREZIONE="La verifica dello spazio di lavoro dice che manca ancora"
CORREZIONE_FINE="Sistema questi punti, un comando per volta, senza modificare"
CORREZIONE_FINE+=" niente in ${PROGETTO}/legacy/, e fai il commit di ciò che"
CORREZIONE_FINE+=" cambi."
readonly CORREZIONE_FINE
readonly TITOLO="Un modulo opaco: documentarlo e proporre il refactoring"
readonly DOVE="Modulo 4, laboratorio, traccia (b): la prova del partecipante"
N_TURNO=0
SESSIONE=''
PROMPT=()

# Una chiamata senza risposta: il verdetto KO e la fine con uscita 1.
# Arguments: il testo del verdetto.
fallita() {
  handson::verdict ko "$*"
  handson::finish
}

# Un turno della sessione data (o di una nuova, con ""), con il suo
# riepilogo. Globals: SESSIONE (assegnata). Arguments: $1 la sessione, $2
# il testo. Returns: 0; esce 1 se claude non risponde o non dà la sessione.
turno() {
  local -a ripresa=()
  if [[ -n "$1" ]]; then
    ripresa=(--resume "$1")
  fi
  prova::turno "$2" ${ripresa[@]+"${ripresa[@]}"} \
    || fallita "il turno ${N_TURNO} non ha dato una risposta"
  prova::riepilogo
  SESSIONE="$(prova::sessione)" \
    || fallita "il turno ${N_TURNO} non ha un ID di sessione"
}

# La prima parte: mappa, documentazione, test (con i seguiti) e nota.
prima_parte() {
  local k
  SESSIONE=''
  turno '' "${PROMPT[1]}"
  turno "${SESSIONE}" "${PROMPT[2]}"
  turno "${SESSIONE}" "${PROMPT[3]}"
  for (( k = 1; k <= SEGUITI_MASSIMI; k++ )); do
    if prova::test_verdi; then
      break
    fi
    turno "${SESSIONE}" "${SEGUITO_TEST}"
  done
  turno "${SESSIONE}" "${PROMPT[4]}"
}

# La seconda parte: il piano in plan mode, poi l'approvazione.
seconda_parte() {
  prova::turno_in_plan_mode "${PROMPT[5]}" \
    || fallita "il turno ${N_TURNO} non ha dato una risposta"
  prova::riepilogo
  SESSIONE="$(prova::sessione)" \
    || fallita "il turno ${N_TURNO} non ha un ID di sessione"
  turno "${SESSIONE}" "${APPROVAZIONE}"
}

# La verifica come la lancia il partecipante; se dice «Non ancora», un turno
# con le sue righe «Non ancora: …». Arguments: $1 lo spazio di lavoro.
correggi() {
  local out righe rc=0
  out="$("${CONTROLLO}" "$1" 2>&1)" || rc=$?
  (( rc == 1 )) || return 0
  righe="$(grep '^Non ancora: ' <<< "${out}")" || return 0
  handson::step "La verifica dice «Non ancora»: un turno per sistemare"
  turno "${SESSIONE}" "${CORREZIONE}:"$'\n'"${righe}"$'\n'"${CORREZIONE_FINE}"
}

main() {
  local ws="${1:-}" out rc=0
  [[ -n "${ws}" && -d "${ws}" ]] \
    || handson::die "spazio di lavoro assente: ${ws}"
  # il percorso assoluto prima del cd: la verifica lo riceve dopo
  ws="$(cd "${ws}" && pwd -P)" || handson::die "non entro in ${ws}"
  cd "${ws}"
  prova::prepara
  handson::note "strumenti consentiti: ${STRUMENTI}"
  handson::banner M4-E03 "${TITOLO}" "${DOVE}"
  handson::step "Prima parte"
  prima_parte
  handson::step "Seconda parte, in una sessione nuova"
  seconda_parte
  correggi "${ws}"
  handson::step "La verifica"
  out="$("${CONTROLLO}" "${ws}" 2>&1)" || rc=$?
  printf '%s\n' "${out}"
  handson::verdict_rc "${rc}" "verifica.sh dell'elemento"
  handson::finish
}

main "$@"
