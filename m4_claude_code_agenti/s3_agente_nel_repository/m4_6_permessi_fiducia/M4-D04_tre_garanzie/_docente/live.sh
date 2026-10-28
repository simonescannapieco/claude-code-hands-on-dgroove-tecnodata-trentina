#!/bin/bash
#
# live.sh di M4-D04 -- la demo del docente: tre gradini, tre garanzie.
# Tre coppie di esecuzioni di Claude Code, ognuna su una copia nuova del
# gestionale dello spazio di lavoro, gradini/<coppia>-<con|senza>/ (il
# gestionale in progetti/gestionale-php/ e le impostazioni del braccio in
# .claude/, un repository git con un commit); le due esecuzioni di una
# coppia hanno la stessa richiesta e differiscono in una cosa sola:
#   piano  richieste/piano.txt (un commento in un file), con
#          --permission-mode plan contro acceptEdits; consentiti Read, Edit;
#   deny   richieste/deny.txt (una riga in un file dei dati generati), in
#          acceptEdits, con impostazioni/deny.json (le impostazioni
#          prudenti più la regola deny sui dati, ancorata al progetto:
#          Edit(/progetti/gestionale-php/database/dati/**)) contro quelle
#          prudenti; in tutti e due i bracci --tools Read,Edit e consentiti
#          Read, Edit: la modifica può passare soltanto da Edit, e la coppia
#          differisce nella sola regola;
#   hook   richieste/hook.txt (rm di da_cancellare.txt, un file che la
#          copia porta apposta), in acceptEdits, con impostazioni/hook.json
#          (un hook PreToolUse su Bash che esegue impostazioni/blocca_rm.py)
#          contro quelle prudenti; consentito Bash(rm *).
# Ogni chiamata: claude -p, sonnet, --effort low, --permission-prompts none,
# --output-format stream-json --verbose, --setting-sources project,local,
# --strict-mcp-config, --no-session-persistence; lo stream in
# risposte/<coppia>-<braccio>.jsonl. handson::claude_p lascia scegliere la
# modalità (HANDSON_PERMISSION_MODE), ma scrive sempre --output-format
# json e rifiuta un altro --output-format, mentre qui serve lo stream-json,
# dove si vedono le chiamate e i dinieghi: gradini::chiedi, in
# _docente/lib_gradini.sh con i bracci, le copie e il piano del plan mode,
# compone la stessa riga con la modalità del braccio, dopo gli stessi
# controlli della libreria (modello, prompt, modalità di permesso,
# argomenti vietati, chiavi API), senza ANTHROPIC_API_KEY nell'ambiente, e
# la riga si vede prima di girare (handson::run). Mai bypassPermissions.
# In plan mode Claude Code scrive il piano in plansDirectory, che se non è
# impostato (--setting-sources project,local non legge le impostazioni
# personali) è ~/.claude/plans: subito dopo l'esecuzione in plan mode,
# anche se è fallita, live.sh toglie da lì il file che ha scritto, se l'ha
# scritto, con il percorso preso dal suo stream (controlla_gradini.py
# --piani), e nessun altro: un file che c'era già prima resta.
# Poi controlla_gradini.py dell'elemento decide le garanzie. Infine la
# prova dei partecipanti, senza terminale: impostazioni/deny.json al posto
# di .claude/settings.json dello spazio di lavoro (la regola che il README
# fa aggiungere), richieste/deny.txt in acceptEdits dallo spazio di
# lavoro, con tutti gli strumenti come un partecipante, lo stream in
# risposte/prova.jsonl, e verifica.sh.
#
# Uso:    _docente/live.sh <spazio di lavoro>
#         lo spazio di lavoro appena preparato (tools/prepara_esercizio.sh
#         M4-D04), con git status pulito
# Env:    le variabili di tools/lib_handson.sh (HANDSON_NO_PAUSE, …;
#         HANDSON_ENV, se c'è, deve essere claude-code-pro); HOME (dove
#         sta il piano del plan mode)
# Uscita: 0 = ogni garanzia confermata e la prova dei partecipanti riuscita
#         · 1 = una chiamata fallita, uno stream che non va, una garanzia
#         non confermata o una coppia non distinguibile, la prova non
#         riuscita · 2 = precondizione
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
# lo script sta in <radice>/m4_…/s3_…/m4_6_…/M4-D04_…/_docente/
readonly RADICE="${SELF%/*/*/*/*/*/*}"
readonly ELEMENTO="${SELF%/_docente/*}"
readonly CONTROLLO="${ELEMENTO}/demo/controlla_gradini.py"
# shellcheck source=../../../../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"
# shellcheck source=lib_gradini.sh
source "${SELF%/*}/lib_gradini.sh"

readonly COPPIE=(piano deny hook)
readonly NECESSARI=(controlla_gradini.py richieste/piano.txt
  richieste/deny.txt richieste/hook.txt impostazioni/deny.json
  impostazioni/hook.json impostazioni/blocca_rm.py .claude/settings.json
  "${GRADINI_GESTIONALE}/src/Ticket/PrioritaTicket.php"
  "${GRADINI_GESTIONALE}/database/dati/01_comuni.sql")

# Una chiamata fallita: il verdetto KO e la fine con uscita 1, senza fare
# le chiamate che restano.
fallita() {
  handson::verdict ko "$*"
  handson::finish
}

# Il controllo e verifica.sh con il loro STDOUT sul descrittore 3, che
# main apre sullo STDOUT di live.sh: handson::check mostra l'uscita di un
# controllo solo su un KO, e qui i dati e i verdetti sono la demo anche
# quando passa. Returns: l'uscita del controllo.
# shellcheck disable=SC2317  # le chiama handson::check, indirettamente
controlla_a_schermo() { python3 -B -I "${CONTROLLO}" . >&3; }
# shellcheck disable=SC2317  # la chiama handson::check, indirettamente
verifica_a_schermo() { "${ELEMENTO}/verifica.sh" "$(pwd -P)" >&3; }

# La prova dei partecipanti, senza terminale: la regola nelle impostazioni
# dello spazio di lavoro, la richiesta in acceptEdits, verifica.sh. Va
# chiamata nello spazio di lavoro.
prova_partecipanti() {
  handson::step "La prova dei partecipanti, senza terminale: la regola deny"
  handson::run cp -- impostazioni/deny.json .claude/settings.json
  handson::run git --no-pager diff -- .claude/settings.json
  gradini::chiedi . acceptEdits 'Read,Edit' richieste/deny.txt \
    risposte/prova.jsonl - \
    || fallita "la prova dei partecipanti: claude -p è fallito"
  handson::check "la prova dei partecipanti" verifica_a_schermo
}

# Le precondizioni, tutte prima della prima chiamata al modello: l'ambiente
# dell'elemento, HOME, gli strumenti, i file dello spazio di lavoro e
# dell'elemento, le tre richieste (con i controlli della libreria), il
# punto di partenza, claude. Va chiamata nello spazio di lavoro.
precondizioni() {
  local f stato radice domanda
  [[ "${HANDSON_ENV}" == claude-code-pro ]] \
    || handson::die "M4-D04 è un elemento claude-code-pro: HANDSON_ENV" \
      "«${HANDSON_ENV}» non vale qui (la chiave API resterebbe" \
      "nell'ambiente di claude -p)"
  [[ "${HOME:-}" == /* ]] \
    || handson::die "HOME non è impostata o non è un percorso assoluto:" \
      "serve per togliere il piano del plan mode"
  handson::need_tools python3 git
  for f in "${NECESSARI[@]}" "${CONTROLLO}"; do
    handson::need_file "${f}"
  done
  [[ -x "${ELEMENTO}/verifica.sh" ]] \
    || handson::die "verifica.sh dell'elemento assente o non eseguibile"
  for f in "${COPPIE[@]}"; do
    domanda="$(< "richieste/${f}.txt")"
    handson::_claude_p_checks "${GRADINI_MODELLO}" "${domanda}"
    handson::_claude_key_ok "${domanda}"
  done
  radice="$(git rev-parse --show-toplevel 2> /dev/null)" || radice=''
  [[ "${radice}" == "$(pwd -P)" ]] \
    || handson::die "$(pwd -P) non è un repository git: preparatelo con" \
      "tools/prepara_esercizio.sh M4-D04"
  stato="$(git status --porcelain)" || handson::die "git status non riesce"
  [[ -z "${stato}" ]] \
    || handson::die "lo spazio di lavoro non è al punto di partenza (git" \
      "status non è vuoto): tools/reset_esercizio.sh M4-D04"
  handson::need_claude
}

main() {
  local ws="${1:-}" c b modo consentiti file soli rc
  [[ -n "${ws}" && -d "${ws}" ]] \
    || handson::die "spazio di lavoro assente: ${ws}"
  cd -- "${ws}" || handson::die "lo spazio di lavoro ${ws} non si apre"
  precondizioni
  handson::banner M4-D04 "Tre gradini, tre garanzie" \
    "Modulo 4, «Permessi e scala della fiducia»: plan mode, deny, un hook"
  mkdir -p risposte gradini
  for c in "${COPPIE[@]}"; do
    for b in con senza; do
      IFS=$'\t' read -r modo consentiti file soli \
        < <(gradini::braccio "${c}" "${b}")
      handson::step "${c}, ${b}: ${modo}, ${consentiti}, ${file}"
      gradini::prepara_copia "gradini/${c}-${b}" "${file}" "${c}" \
        || handson::die "non riesco a preparare gradini/${c}-${b}/"
      if [[ "${c}-${b}" == piano-con ]]; then
        gradini::ricorda_piani
      fi
      rc=0
      gradini::chiedi "gradini/${c}-${b}" "${modo}" "${consentiti}" \
        "richieste/${c}.txt" "risposte/${c}-${b}.jsonl" "${soli}" || rc=$?
      # il piano si toglie subito, anche se la chiamata è fallita
      if [[ "${c}-${b}" == piano-con ]]; then
        gradini::togli_piani
      fi
      (( rc == 0 )) || fallita "${c}-${b}: claude -p è fallito"
    done
  done
  handson::step "Le garanzie, dalle sei esecuzioni"
  exec 3>&1
  handson::check "le tre coppie" controlla_a_schermo
  prova_partecipanti
  handson::finish
}

main "$@"
