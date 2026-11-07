#!/bin/bash
#
# live.sh di M6-E01 -- i passi del partecipante, in claude -p, per la
# registrazione del corso, in uno spazio di lavoro al punto di partenza (git
# status vuoto; niente CLAUDE.md, prima.md, dopo.md, risposta.txt,
# domanda.jsonl, né il registro dell'hook, che git non vede: altrimenti esce
# 2 e indica tools/reset_esercizio.sh M6-E01):
#   1. /context all con il comando del README, in prima.md;
#   2. il CLAUDE.md di due righe del README, scritto dalla shell con printf;
#   3. /context all di nuovo, in dopo.md;
#   4. la domanda del README, fra «<!-- prompt 1 -->» e «<!-- /prompt 1 -->»,
#      in claude -p al posto della sessione interattiva: Sonnet, effort low,
#      consentiti Read, Glob e Grep, lo stream in domanda.jsonl. Il
#      partecipante salva la risposta con /export, che in -p non c'è
#      («/export isn't available in this environment», prova del corso con
#      Claude Code 2.1.319): verifica.sh la legge dallo stream;
#   5. verifica.sh dell'elemento.
# I due /context all non chiamano il modello; il comando è quello del
# README, con lo STDIN da /dev/null e senza ANTHROPIC_API_KEY né
# CLAUDE_CODE_EFFORT_LEVEL, come in handson::claude_p.
#
# Uso:    _docente/live.sh <spazio di lavoro>
# Env:    le variabili di tools/lib_handson.sh (HANDSON_ENV, se c'è, deve
#         essere claude-code-pro)
# Uscita: 0 = verifica.sh passa · 1 = una chiamata a claude fallita, o
#         verifica.sh esce 1 · 2 = precondizione (spazio di lavoro assente o
#         non al punto di partenza, un file o uno strumento che manca, un
#         prompt che il README non ha), anche di verifica.sh
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
# lo script sta in <radice>/m6_…/s5_…/m6_e1_…/M6-E01_…/_docente/
readonly RADICE="${SELF%/*/*/*/*/*/*}"
readonly ELEMENTO="${SELF%/_docente/*}"
# shellcheck source=../../../../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"

readonly MODELLO=sonnet
readonly STRUMENTI='Read,Glob,Grep'
readonly OPZIONI=(--effort low --strict-mcp-config --no-session-persistence)
# Il comando dei due /context all, quello del README.
readonly CONTESTO=(claude -p "/context all" --model "${MODELLO}"
  --setting-sources "project,local" --strict-mcp-config)
# Le due righe di CLAUDE.md, quelle del printf del README.
readonly RIGA_1='# Gestionale di CiaspoLink'
# shellcheck disable=SC2016  # gli apici inversi sono il testo di CLAUDE.md
RIGA_2='- Test, da progetti/gestionale-php: `../../tools/php.sh composer'
# shellcheck disable=SC2016  # gli apici inversi sono il testo di CLAUDE.md
RIGA_2+=' install`, poi `../../tools/php.sh phpunit`'
readonly RIGA_2
readonly ARTEFATTI=(CLAUDE.md prima.md dopo.md risposta.txt domanda.jsonl
  .claude/caricamenti.jsonl)
# shellcheck disable=SC2034  # la legge handson::claude_p
HANDSON_OUTPUT_FORMAT=stream-json
DOMANDA=''

# Una chiamata fallita: il verdetto KO e la fine, senza quelle che restano.
fallita() {
  handson::verdict ko "$*: claude -p è fallito"
  handson::finish
}

# La domanda del README, fra i suoi marcatori, senza il rientro del blocco di
# codice. Globals: DOMANDA (assegnata); esce 2 se non c'è.
domanda_del_readme() {
  local riga dentro=0 testo=''
  while IFS= read -r riga; do
    case "${riga}" in
      *'<!-- /prompt 1 -->'*) dentro=0; continue ;;
      *'<!-- prompt 1 -->'*) dentro=1; continue ;;
    esac
    if (( dentro == 1 )) && [[ -n "${riga// /}" ]]; then
      testo+="${riga#       }"$'\n'
    fi
  done < "${ELEMENTO}/README.md"
  DOMANDA="$(printf '%s' "${testo}")"
  [[ -n "${DOMANDA}" && "${DOMANDA}" != *$'\n'* ]] \
    || handson::die "il prompt 1 del README non c'è, o non è una riga sola"
}

# Le precondizioni, tutte prima della prima chiamata. Va chiamata nello
# spazio di lavoro.
precondizioni() {
  local f radice stato
  [[ "${HANDSON_ENV}" == claude-code-pro ]] \
    || handson::die "M6-E01 è un elemento claude-code-pro: HANDSON_ENV" \
      "«${HANDSON_ENV}» non vale qui"
  handson::need_tools python3 git
  for f in tools/php.sh .claude/settings.json \
      .claude/hooks/registra_caricamenti.py \
      progetti/gestionale-php/composer.json; do
    handson::need_file "${f}"
  done
  [[ -x "${ELEMENTO}/verifica.sh" ]] \
    || handson::die "verifica.sh dell'elemento assente o non eseguibile"
  radice="$(git rev-parse --show-toplevel 2> /dev/null)" || radice=''
  [[ "${radice}" == "$(pwd -P)" ]] \
    || handson::die "$(pwd -P) non è un repository git: preparatelo con" \
      "tools/prepara_esercizio.sh M6-E01"
  stato="$(git status --porcelain)" || handson::die "git status non riesce"
  [[ -z "${stato}" ]] \
    || handson::die "lo spazio di lavoro non è al punto di partenza (git" \
      "status non è vuoto): tools/reset_esercizio.sh M6-E01"
  for f in "${ARTEFATTI[@]}"; do
    [[ ! -e "${f}" ]] \
      || handson::die "lo spazio di lavoro non è al punto di partenza:" \
        "${f} c'è già: tools/reset_esercizio.sh M6-E01"
  done
  domanda_del_readme
  handson::need_claude
}

# /context all con il comando del README, l'uscita nel file $1.
contesto_in() {
  (
    unset ANTHROPIC_API_KEY CLAUDE_CODE_EFFORT_LEVEL
    handson::run "${CONTESTO[@]}" < /dev/null > "$1"
  ) || fallita "/context all in $1"
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
  local ws="$1"
  [[ -n "${ws}" && -d "${ws}" ]] \
    || handson::die "spazio di lavoro assente: ${ws}"
  cd -- "${ws}" || handson::die "lo spazio di lavoro ${ws} non si apre"
  precondizioni
  handson::banner M6-E01 "Che cosa vede Claude" \
    "Modulo 6, l'esercitazione: il partecipante, emulato in claude -p"
  handson::step "/context all prima del CLAUDE.md, in prima.md"
  contesto_in prima.md
  handson::step "Il CLAUDE.md di due righe, scritto dalla shell"
  handson::run printf '%s\n' "${RIGA_1}" "${RIGA_2}" > CLAUDE.md
  handson::step "/context all dopo il CLAUDE.md, in dopo.md"
  contesto_in dopo.md
  handson::step "La domanda, in claude -p al posto della sessione"
  handson::claude_p "${MODELLO}" "${STRUMENTI}" "${DOMANDA}" \
    "${OPZIONI[@]}" < /dev/null > domanda.jsonl || fallita "la domanda"
  handson::step "La verifica"
  exec 3>&1
  handson::check "il CLAUDE.md caricato e il registro dell'hook" \
    verifica_a_schermo
  handson::finish
}

main "$@"
