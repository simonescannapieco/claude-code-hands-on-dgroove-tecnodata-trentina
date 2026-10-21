#!/bin/bash
#
# live.sh di M3-D02 -- la demo del docente: quando Claude cerca sul web.
# Due domande che differiscono in una cosa, il bisogno di informazioni
# attuali: attuale.md (l'ultima versione di Claude Code nel changelog
# ufficiale) e stabile.md (che cos'è la fibra FTTH). Stesso modello
# (sonnet), un solo strumento per il web, WebSearch (il solo disponibile,
# --tools WebSearch, e il solo consentito, --allowedTools WebSearch): le
# frasi di Anthropic parlano di cercare, e WebFetch, che apre una pagina
# già nota, non è offerto, così non prende il posto di una ricerca. Effort
# low, senza server MCP, senza salvare la sessione; tre coppie, prima la
# domanda attuale e poi la stabile: sei chiamate, lo stream-json di ognuna
# in risposte/<domanda>-<n>.jsonl. Gli
# stessi testi e le stesse opzioni del passo 3 del README, più
# --permission-mode dontAsk, --permission-prompts none e
# --setting-sources project,local, come li mette handson::claude_p.
# handson::claude_p però scrive sempre --output-format json e rifiuta un
# altro --output-format, mentre qui serve lo stream-json: solo lì si vede
# quale strumento ha girato. chiedi() compone quindi la stessa riga di
# handson::claude_p con --output-format stream-json --verbose, dopo gli
# stessi controlli della libreria (modello, prompt, modalità di permesso,
# argomenti vietati, chiavi API) e senza ANTHROPIC_API_KEY nell'ambiente;
# la riga si vede prima di girare (handson::run).
# Poi conta_ricerche.py scrive esiti.tsv, e verifica.sh dice, coppia per
# coppia, se la prova conferma ciò che Anthropic descrive: i suoi dati e il
# suo verdetto si vedono anche quando passa. In aula i partecipanti
# provano le due domande in claude.ai.
#
# Uso:    _docente/live.sh <spazio di lavoro>
# Env:    le variabili di tools/lib_handson.sh (HANDSON_NO_PAUSE, …)
# Uscita: 0 = le sei chiamate ci sono e si leggono (il verdetto non decide
#         l'uscita) · 1 = una chiamata fallita, o una chiamata che manca o
#         non va · 2 = precondizione
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
# lo script sta in <radice>/m3_…/s2_…/m3_4_…/M3-D02_…/_docente/
readonly RADICE="${SELF%/*/*/*/*/*/*}"
readonly CONTROLLO="${SELF%/_docente/*}/verifica.sh"
# shellcheck source=../../../../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"

readonly MODELLO=sonnet
readonly STRUMENTI=WebSearch
readonly DOMANDE=(attuale stabile)
readonly OPZIONI=(--tools "${STRUMENTI}" --effort low --strict-mcp-config
  --no-session-persistence)

# Una chiamata, con il suo stream-json in un file: la riga di
# handson::claude_p con --output-format stream-json --verbose. I controlli
# stanno fuori dal sottoprocesso e fuori da $(…): una precondizione esce
# davvero con 2.
# Globals: HANDSON_ENV, HANDSON_PERMISSION_MODE, HANDSON_SETTING_SOURCES
#   (lette). Arguments: $1 il file del prompt, $2 il file dello stream.
# Returns: l'uscita di claude.
chiedi() {
  local domanda arg
  domanda="$(cat -- "$1")"
  handson::need_tools claude
  handson::_claude_p_checks "${MODELLO}" "${domanda}"
  handson::_claude_key_ok "${domanda}"
  for arg in "${MODELLO}" "${STRUMENTI}" "${OPZIONI[@]}"; do
    handson::_claude_arg_ok "${arg}"
  done
  local -a argv=(claude -p --allowedTools "${STRUMENTI}" --model "${MODELLO}"
    --permission-mode "${HANDSON_PERMISSION_MODE}" --permission-prompts none
    --output-format stream-json --verbose
    --setting-sources "${HANDSON_SETTING_SOURCES}" "${OPZIONI[@]}"
    -- "${domanda}")
  if [[ "${HANDSON_ENV}" == "trainer-api" ]]; then
    handson::run "${argv[@]}" < /dev/null > "$2"
    return
  fi
  (
    if [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
      handson::note "ANTHROPIC_API_KEY è impostata: la tolgo per questo" \
        "comando, così Claude Code usa l'abbonamento"
    fi
    unset ANTHROPIC_API_KEY
    handson::run "${argv[@]}" < /dev/null > "$2"
  )
}

# Una chiamata fallita: il verdetto KO e la fine con uscita 1, senza fare
# le chiamate che restano.
fallita() {
  handson::verdict ko "$*"
  handson::finish
}

# verifica.sh con il suo STDOUT sul descrittore 3, che main apre sullo
# STDOUT di live.sh: handson::check mostra l'uscita di un controllo solo
# su un KO, e qui i dati e il verdetto sono la demo anche quando passa.
# Arguments: $1 lo spazio di lavoro. Returns: l'uscita di verifica.sh.
# shellcheck disable=SC2317  # la chiama handson::check, indirettamente
verifica_a_schermo() {
  "${CONTROLLO}" "$1" >&3
}

main() {
  local ws="${1:-}" n q rc=0
  [[ -n "${ws}" && -d "${ws}" ]] \
    || handson::die "spazio di lavoro assente: ${ws}"
  cd "${ws}"
  handson::need_tools python3
  for q in "${DOMANDE[@]}"; do
    handson::need_file "${q}.md"
  done
  handson::need_file conta_ricerche.py
  handson::need_claude
  handson::banner M3-D02 "Quando Claude cerca sul web" \
    "Modulo 3, «Web search, Research, codice e file»: attuale e stabile"
  mkdir -p risposte
  for n in 1 2 3; do
    for q in "${DOMANDE[@]}"; do
      handson::step "${MODELLO}, coppia ${n}: la domanda ${q}"
      chiedi "${q}.md" "risposte/${q}-${n}.jsonl" \
        || fallita "${q} ${n}: claude -p è fallito"
    done
  done
  # esiti.tsv, come al passo 4 del README; i dati e il verdetto li mostra
  # una volta sola il controllo qui sotto, e un'uscita 1 la dice lui.
  handson::step "esiti.tsv, come nel README"
  python3 -B -I conta_ricerche.py > /dev/null || rc=$?
  if (( rc >= 2 )); then
    handson::verdict_rc "${rc}" "conta_ricerche.py: le sei chiamate"
  fi
  handson::step "Quando ha cercato Claude, e che cosa dice Anthropic"
  exec 3>&1
  handson::check "le sei chiamate, coppia per coppia" \
    verifica_a_schermo "${ws}"
  handson::finish
}

main "$@"
