#!/bin/bash
#
# misura.sh -- misura una versione di un prompt, in tre passi:
#   1. la risposta: prompt/<versione>.md, con i file di dati/ al posto dei
#      segnaposto {{nome}}, a Claude con claude -p, senza strumenti
#      (risposte/<versione>.json e risposte/<versione>.md);
#   2. i controlli scritti in codice di controlli.tsv
#      (controlli/<versione>.txt);
#   3. il giudizio del subagent «giudice» (.claude/agents/giudice.md) con
#      le affermazioni di rubrica.md, in un JSON vincolato da
#      schema-giudizio.json (giudizi/<versione>.json).
# Poi stampa il riepilogo. Con --confronta mette due versioni già misurate
# fianco a fianco. Ogni comando claude che lancia viene prima stampato.
#
# Uso:    ./misura.sh [cartella] <versione> [--modello M] [--effort E]
#         ./misura.sh --confronta [cartella] <versione> <versione>
#         cartella: la famiglia del prompt (per esempio supporto); senza,
#         la cartella corrente. versione: v0, v1, v2, ... Il modello della
#         risposta (haiku, sonnet, opus; default sonnet) e l'effort (low,
#         medium, high; default low) si cambiano uno per volta.
# Uscita: 0 misurata o confrontata · 1 una chiamata a Claude fallita o un
#         file di misura incompleto · 2 uso sbagliato o precondizione,
#         anche un testo oltre i 100000 byte o controlli che non girano
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly BASE="${SELF%/*}"
readonly KIT="${BASE}/strumenti/kit.py"
readonly SCHEMA="${BASE}/schema-giudizio.json"
readonly AGENTE="${BASE}/.claude/agents/giudice.md"
readonly SISTEMA='Rispondi in italiano.'
readonly COMUNI=(--strict-mcp-config --setting-sources 'project,local'
  --permission-mode dontAsk --permission-prompts none
  --output-format json --no-session-persistence)

err() { echo "misura.sh: $*" >&2; }
die() { err "$*"; exit 2; }

# Stampa il comando, poi lo esegue senza ANTHROPIC_API_KEY (in -p una
# chiave presente verrebbe usata al posto dell'abbonamento Pro) e con
# STDIN da /dev/null (claude -p legge anche lo standard input).
# Arguments: $1 il file d'uscita, poi il comando. Returns: quello di claude.
esegui() {
  local uscita="$1"
  shift
  printf '$ %s\n' "$(mostra "$@")" >&2
  env -u ANTHROPIC_API_KEY "$@" < /dev/null > "${uscita}"
}

# Il comando in una riga leggibile: un argomento lungo (il prompt, lo
# schema) diventa «…», uno vuoto o con spazi va tra virgolette.
mostra() {
  local a riga=''
  for a in "$@"; do
    if (( ${#a} > 40 )) || [[ "${a}" == *$'\n'* ]]; then
      a='«…»'
    elif [[ -z "${a}" || "${a}" == *' '* ]]; then
      a="\"${a}\""
    fi
    riga+="${riga:+ }${a}"
  done
  printf '%s' "${riga}"
}

# Il passo 1: la risposta. Le opzioni prima, poi «--» e il prompt: un
# prompt che comincia con «-» (un elenco puntato) non va preso per
# un'opzione. Arguments: $1 cartella, $2 versione, $3 modello, $4 effort.
# Returns: 1 se claude fallisce.
rispondi() {
  local prompt
  prompt="$(python3 -B "${KIT}" componi "$1" "$2")" || exit 2
  mkdir -p "$1/risposte"
  if ! esegui "$1/risposte/$2.json" claude -p --model "$3" --effort "$4" \
      --tools "" --system-prompt "${SISTEMA}" "${COMUNI[@]}" -- "${prompt}"
  then
    err "la risposta di $2 non è arrivata: vedi $1/risposte/$2.json"
    return 1
  fi
  python3 -B "${KIT}" estrai "$1" "$2"
}

# Il passo 3: il giudizio, con la consegna per ultima, dopo «--».
# Arguments: $1 cartella, $2 versione. Returns: 1 se claude fallisce.
giudica() {
  local consegna
  consegna="$(python3 -B "${KIT}" consegna "$1" "$2")" || exit 2
  mkdir -p "$1/giudizi"
  if ! esegui "$1/giudizi/$2.json" claude -p --agent giudice \
      --json-schema "$(cat "${SCHEMA}")" --tools "" --effort low \
      "${COMUNI[@]}" -- "${consegna}"; then
    err "il giudizio di $2 non è arrivato: vedi $1/giudizi/$2.json"
    return 1
  fi
  python3 -B "${KIT}" giudizio "$1" "$2"
}

main() {
  local modello=sonnet effort=low confronta=0 rc=0 cartella versione
  local -a pos=()
  # Un'opzione senza valore lo lascia vuoto: lo rifiutano, con l'uscita 2,
  # i controlli del modello e dell'effort qui sotto.
  while (( $# > 0 )); do
    case "$1" in
      --confronta) confronta=1 ;;
      --modello) modello="${2:-}"; (( $# < 2 )) || shift ;;
      --effort) effort="${2:-}"; (( $# < 2 )) || shift ;;
      -h|--help) sed -n '/^set -/q; 2,$p' "${SELF}"; exit 0 ;;
      -*) die "opzione sconosciuta: $1" ;;
      *) pos+=("$1") ;;
    esac
    shift
  done
  case "${modello}" in
    haiku|sonnet|opus) ;;
    *) die "modello «${modello}»: si usa haiku, sonnet o opus" ;;
  esac
  case "${effort}" in
    low|medium|high) ;;
    *) die "effort «${effort}»: si usa low, medium o high" ;;
  esac
  command -v python3 >/dev/null 2>&1 || die "manca python3"
  [[ -f "${KIT}" && -f "${SCHEMA}" && -f "${AGENTE}" ]] \
    || die "mancano strumenti/kit.py, schema-giudizio.json o il giudice"
  cd "${BASE}"
  if (( confronta == 1 )); then
    case "${#pos[@]}" in
      2) python3 -B "${KIT}" confronta . "${pos[0]}" "${pos[1]}" ;;
      3) python3 -B "${KIT}" confronta "${pos[0]}" "${pos[1]}" "${pos[2]}" ;;
      *) die "uso: ./misura.sh --confronta [cartella] <versione> <versione>" ;;
    esac
    return
  fi
  command -v claude >/dev/null 2>&1 || die "manca claude"
  case "${#pos[@]}" in
    1) cartella=. versione="${pos[0]}" ;;
    2) cartella="${pos[0]}" versione="${pos[1]}" ;;
    *) die "uso: ./misura.sh [cartella] <versione> [--modello M]" \
         "[--effort E]" ;;
  esac
  [[ "${cartella}" != /* && "${cartella}" != *..* && -d "${cartella}" ]] \
    || die "cartella «${cartella}» assente o fuori dall'esercizio"
  [[ "${versione}" =~ ^v[0-9]+$ ]] \
    || die "versione «${versione}» non valida: si scrive v0, v1, v2, ..."
  [[ -f "${cartella}/prompt/${versione}.md" ]] \
    || die "manca ${cartella}/prompt/${versione}.md"
  # La misura nuova toglie prima la vecchia: se si ferma a metà, la
  # versione resta da misurare, senza file vecchi accanto ai nuovi.
  rm -f -- "${cartella}/risposte/${versione}.json" \
    "${cartella}/risposte/${versione}.md" \
    "${cartella}/controlli/${versione}.txt" \
    "${cartella}/giudizi/${versione}.json" \
    || die "non riesco a togliere la misura precedente di ${versione}"
  echo "== ${versione}: risposta (${modello}, effort ${effort})"
  rispondi "${cartella}" "${versione}" "${modello}" "${effort}" || exit 1
  echo "== ${versione}: controlli"
  python3 -B "${KIT}" controlla "${cartella}" "${versione}" || rc=$?
  (( rc <= 1 )) || die "i controlli di ${versione} non sono riusciti" \
    "(uscita ${rc}): la misura si ferma prima del giudizio"
  echo "== ${versione}: giudizio"
  giudica "${cartella}" "${versione}" || exit 1
}

main "$@"
