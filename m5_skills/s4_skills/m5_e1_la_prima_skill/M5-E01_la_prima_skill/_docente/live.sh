#!/bin/bash
#
# live.sh di M5-E01 -- la sessione del partecipante, emulata in claude -p, per
# la registrazione del corso, in uno spazio di lavoro al punto di partenza (git
# status vuoto e niente prova/, che git non vede: altrimenti esce 2 e indica
# tools/reset_esercizio.sh M5-E01):
#   1. la piccola modifica, bash prepara_modifica.sh;
#   2. la richiesta del README, fra «<!-- prompt 1 -->» e «<!-- /prompt 1 -->»:
#      Sonnet, effort low, consentiti Write, Read, Edit e il comando del
#      controllo; lo stream in prova/richiesta.jsonl. Un solo cambiamento, il
#      percorso: .claude è un percorso protetto, dove in dontAsk una scrittura è
#      negata anche se Write è consentito («dontAsk | Denied»,
#      https://code.claude.com/docs/en/permission-modes), e in -p non c'è
#      nessuno che approvi. Perciò Claude scrive in bozza/riassunto-modifiche/,
#      e lo script fa ciò che nella sessione interattiva fa l'approvazione del
#      partecipante: porta la cartella in .claude/skills/;
#   3. claude plugin validate .claude/skills e /skill-doctor, senza chiamate al
#      modello: l'uscita del primo si stampa e non decide niente;
#   4. tre volte bash prova.sh, ognuna una sessione nuova, per «n su 3» della
#      chiamata Skill;
#   5. /riassunto-modifiche in una sessione nuova, ciò che il partecipante prova
#      a mano;
#   6. verifica.sh dell'elemento, che legge tutti gli stream di prova/.
# La cartella prova/ è in .gitignore: gli stream non compaiono nel git status
# che la skill legge.
#
# Uso:    _docente/live.sh <spazio di lavoro>
# Env:    le variabili di tools/lib_handson.sh (HANDSON_ENV, se c'è, deve essere
#         claude-code-pro)
# Uscita: 0 = verifica.sh passa · 1 = una chiamata a claude fallita, o
#         verifica.sh esce 1 · 2 = precondizione (spazio di lavoro assente o con
#         del lavoro, un file o uno strumento che manca, un prompt che il README
#         non ha), anche di verifica.sh
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
# lo script sta in <radice>/m5_…/s4_…/m5_e1_…/M5-E01_…/_docente/
readonly RADICE="${SELF%/*/*/*/*/*/*}"
readonly ELEMENTO="${SELF%/_docente/*}"
# shellcheck source=../../../../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"

readonly MODELLO=sonnet
STRUMENTI='Write,Read,Edit,Bash(python3 -B -I controlla_skill.py *)'
readonly STRUMENTI
readonly OPZIONI=(--effort low --strict-mcp-config --no-session-persistence)
readonly SKILL=.claude/skills/riassunto-modifiche
readonly BOZZA=bozza/riassunto-modifiche
HANDSON_OUTPUT_FORMAT=stream-json
PROMPT=''

# Una chiamata fallita: il verdetto KO e la fine, senza quelle che restano.
fallita() {
  handson::verdict ko "$*: claude -p è fallito"
  handson::finish
}

# Il prompt del README, fra i suoi marcatori, senza il rientro del blocco di
# codice. Globals: PROMPT (assegnata); esce 2 se non c'è.
prompt_del_readme() {
  local riga dentro=0 testo=''
  while IFS= read -r riga; do
    case "${riga}" in
      *'<!-- /prompt 1 -->'*) dentro=0; continue ;;
      *'<!-- prompt 1 -->'*) dentro=1; continue ;;
    esac
    if (( dentro == 1 )); then
      testo+="${riga#       }"$'\n'
    fi
  done < "${ELEMENTO}/README.md"
  while [[ "${testo}" == $'\n'* ]]; do
    testo="${testo#$'\n'}"
  done
  PROMPT="$(printf '%s' "${testo}")"
  [[ "${PROMPT}" == *"${SKILL}"* ]] \
    || handson::die "il prompt 1 del README non nomina ${SKILL}"
  PROMPT="${PROMPT//${SKILL}/${BOZZA}}"
}

# La richiesta con il percorso cambiato, poi la cartella in .claude/skills/: in
# -p è il posto dell'approvazione del partecipante.
richiesta() {
  handson::claude_p "${MODELLO}" "${STRUMENTI}" "${PROMPT}" "${OPZIONI[@]}" \
    < /dev/null > prova/richiesta.jsonl || fallita "la richiesta"
  if [[ ! -f "${BOZZA}/SKILL.md" ]]; then
    handson::verdict ko "la richiesta non ha scritto ${BOZZA}/SKILL.md"
    handson::finish
  fi
  handson::run mkdir -p "${SKILL%/*}"
  handson::run mv -- "${BOZZA}" "${SKILL}"
  handson::run rm -rf -- bozza
}

# Le precondizioni, tutte prima della prima chiamata. Va chiamata nello spazio
# di lavoro.
precondizioni() {
  local f radice stato
  [[ "${HANDSON_ENV}" == claude-code-pro ]] \
    || handson::die "M5-E01 è un elemento claude-code-pro: HANDSON_ENV" \
      "«${HANDSON_ENV}» non vale qui"
  handson::need_tools python3 git
  for f in prova.sh prepara_modifica.sh controlla_skill.py \
      lib_leggi_frontmatter.py progetti/urgenze/urgenza.py; do
    handson::need_file "${f}"
  done
  [[ -x "${ELEMENTO}/verifica.sh" ]] \
    || handson::die "verifica.sh dell'elemento assente o non eseguibile"
  radice="$(git rev-parse --show-toplevel 2> /dev/null)" || radice=''
  [[ "${radice}" == "$(pwd -P)" ]] \
    || handson::die "$(pwd -P) non è un repository git: preparatelo con" \
      "tools/prepara_esercizio.sh M5-E01"
  stato="$(git status --porcelain)" || handson::die "git status non riesce"
  [[ -z "${stato}" ]] \
    || handson::die "lo spazio di lavoro non è al punto di partenza (git" \
      "status non è vuoto): tools/reset_esercizio.sh M5-E01"
  [[ ! -e prova ]] \
    || handson::die "lo spazio di lavoro non è al punto di partenza: prova/" \
      "c'è già, e git non la vede: tools/reset_esercizio.sh M5-E01"
  prompt_del_readme
  handson::need_claude
}

# I passi che non chiamano il modello: claude plugin validate, che lascia
# passare alcuni YAML non validi e per questo non decide, e /skill-doctor.
senza_modello() {
  local rc=0
  handson::run claude plugin validate .claude/skills || rc=$?
  printf 'claude plugin validate: uscita %d (un dato: non decide)\n' "${rc}"
  handson::claude_p "${MODELLO}" '' /skill-doctor --strict-mcp-config \
    --no-session-persistence < /dev/null > prova/skill-doctor.jsonl \
    || fallita "/skill-doctor"
}

# verifica.sh con il suo STDOUT sul descrittore 3, che main apre sullo STDOUT
# di live.sh: handson::check mostra l'uscita di un controllo solo su un KO, e
# qui i dati sono ciò che la registrazione legge.
# shellcheck disable=SC2317  # la chiama handson::check, indirettamente
verifica_a_schermo() { "${ELEMENTO}/verifica.sh" "$(pwd -P)" >&3; }

main() {
  if (( $# != 1 )); then
    echo "uso: _docente/live.sh <spazio di lavoro>" >&2
    exit 2
  fi
  local ws="$1" n
  [[ -n "${ws}" && -d "${ws}" ]] \
    || handson::die "spazio di lavoro assente: ${ws}"
  cd -- "${ws}" || handson::die "lo spazio di lavoro ${ws} non si apre"
  precondizioni
  handson::banner M5-E01 "La prima skill" \
    "Modulo 5, l'esercitazione: il partecipante, emulato in claude -p"
  mkdir -p prova
  handson::step "La piccola modifica non committata"
  handson::run bash prepara_modifica.sh
  handson::step "La richiesta del README, con il percorso in bozza/"
  richiesta
  handson::step "I controlli che non chiamano il modello"
  senza_modello
  for n in 1 2 3; do
    handson::step "La prova ${n} di 3: bash prova.sh, una sessione nuova"
    handson::run bash prova.sh || fallita "la prova ${n}"
  done
  handson::step "/riassunto-modifiche, in una sessione nuova"
  handson::claude_p "${MODELLO}" Read /riassunto-modifiche "${OPZIONI[@]}" \
    < /dev/null > prova/nome.jsonl || fallita "/riassunto-modifiche"
  handson::step "La verifica"
  exec 3>&1
  handson::check "la skill e la prova" verifica_a_schermo
  handson::finish
}

main "$@"
