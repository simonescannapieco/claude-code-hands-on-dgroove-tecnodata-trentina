#!/bin/bash
#
# misura.sh -- misura una versione del prompt sui tre casi del laboratorio.
# Per ogni caso di casi/, in tre passi:
#   1. la risposta: prompt/<versione>.md, con i dati del caso e i file di
#      documenti/ al posto dei segnaposto {{nome}}, a Claude con claude -p,
#      senza strumenti (risposte/<versione>/<caso>.json e <caso>.md; in
#      risposte/<versione>/opzioni.tsv il modello, l'effort e le impronte del
#      prompt e dei dati, per dire poi che cosa è cambiato);
#   2. i controlli scritti in codice di controlli.tsv del caso
#      (controlli/<versione>/<caso>.txt);
#   3. il giudizio del subagent «giudice» (.claude/agents/giudice.md) con le
#      affermazioni di rubrica.md del caso, in un JSON vincolato da
#      schema-giudizio.json (giudizi/<versione>/<caso>.json).
# Poi stampa la tabella della versione: i token in entrata (la somma dei tre
# campi di usage), i token in uscita, il costo ricalcolato da listino.json,
# i controlli superati e le affermazioni rispettate, per caso e in totale.
# Con --confronta mette due versioni già misurate fianco a fianco e stampa la
# riduzione dei token in entrata con la riga dell'obiettivo del laboratorio
# (almeno il 50 % in meno: un dato, non un esito). Ogni comando claude che
# lancia viene prima stampato.
#
# Uso:    ./misura.sh <versione> [--modello M] [--effort E]
#         ./misura.sh --confronta <versione> <versione>
#         versione: v0, v1, v2, ... Il modello delle risposte (haiku, sonnet,
#         opus; default sonnet) e l'effort (low, medium, high; default low) si
#         cambiano uno per volta: due versioni si confrontano a parità di
#         modello e di effort.
# Uscita: 0 misurata o confrontata · 1 una chiamata a Claude fallita o un file
#         di misura incompleto · 2 uso sbagliato o precondizione, anche un
#         testo oltre i 100000 byte o controlli che non girano
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly BASE="${SELF%/*}"
readonly KIT="${BASE}/strumenti/kit.py"
readonly SCHEMA="${BASE}/schema-giudizio.json"
readonly AGENTE="${BASE}/.claude/agents/giudice.md"
readonly SISTEMA='Rispondi in italiano.'
# Una versione è «v» e un numero senza zeri davanti: v0, v1, v2, ..., v10.
readonly VERSIONE_RE='^v(0|[1-9][0-9]*)$'
readonly COMUNI=(--strict-mcp-config --setting-sources 'project,local'
  --permission-mode dontAsk --permission-prompts none
  --output-format json --no-session-persistence)

err() { echo "misura.sh: $*" >&2; }
die() { err "$*"; exit 2; }

# Stampa il comando, poi lo esegue senza ANTHROPIC_API_KEY (in -p una chiave
# presente verrebbe usata al posto dell'abbonamento Pro) e senza
# CLAUDE_CODE_EFFORT_LEVEL (ha la precedenza su --effort), con STDIN da
# /dev/null (claude -p legge anche lo standard input).
# Arguments: $1 il file d'uscita, poi il comando. Returns: quello di claude.
esegui() {
  local uscita="$1"
  shift
  printf '$ %s\n' "$(mostra "$@")" >&2
  env -u ANTHROPIC_API_KEY -u CLAUDE_CODE_EFFORT_LEVEL "$@" < /dev/null \
    > "${uscita}"
}

# Il comando in una riga leggibile: un argomento lungo (il prompt, lo schema)
# diventa «…», uno vuoto o con spazi va tra virgolette.
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

# Il passo 1: la risposta di una versione a un caso. Le opzioni prima, poi
# «--» e il prompt: un prompt che comincia con «-» non va preso per
# un'opzione.
# Arguments: $1 caso, $2 versione, $3 modello, $4 effort.
# Returns: 1 se claude fallisce.
rispondi() {
  local prompt uscita="risposte/$2/$1.json"
  prompt="$(python3 -B "${KIT}" componi "$1" "$2")" || exit 2
  if ! esegui "${uscita}" claude -p --model "$3" --effort "$4" \
      --tools "" --system-prompt "${SISTEMA}" "${COMUNI[@]}" -- "${prompt}"
  then
    err "la risposta di $2 a $1 non è arrivata: vedi ${uscita}"
    return 1
  fi
  python3 -B "${KIT}" estrai "$1" "$2"
}

# Il passo 3: il giudizio, con la consegna per ultima, dopo «--».
# Arguments: $1 caso, $2 versione. Returns: 1 se claude fallisce.
giudica() {
  local consegna uscita="giudizi/$2/$1.json"
  consegna="$(python3 -B "${KIT}" consegna "$1" "$2")" || exit 2
  if ! esegui "${uscita}" claude -p --agent giudice \
      --json-schema "$(cat "${SCHEMA}")" --tools "" --effort low \
      "${COMUNI[@]}" -- "${consegna}"; then
    err "il giudizio di $2, $1 non è arrivato: vedi ${uscita}"
    return 1
  fi
  python3 -B "${KIT}" giudizio "$1" "$2"
}

# La misura di una versione: toglie prima quella vecchia (se si ferma a metà,
# la versione resta da misurare, senza file vecchi accanto ai nuovi), poi
# risposta, controlli e giudizio di ogni caso; alla fine la tabella.
# Arguments: $1 versione, $2 modello, $3 effort.
misura() {
  local v="$1" caso rc
  local -a casi=()
  [[ "${v}" =~ ${VERSIONE_RE} ]] || die "versione «${v}» non valida"
  rm -rf -- "risposte/${v}" "controlli/${v}" "giudizi/${v}" \
    || die "non riesco a togliere la misura precedente di ${v}"
  mkdir -p -- "risposte/${v}" "controlli/${v}" "giudizi/${v}" \
    || die "non riesco a creare le cartelle della misura di ${v}"
  while IFS= read -r caso; do
    casi+=("${caso}")
  done < <(python3 -B "${KIT}" casi)
  (( ${#casi[@]} > 0 )) || die "il kit non elenca nessun caso"
  python3 -B "${KIT}" opzioni "${v}" "$2" "$3" \
    || die "non riesco a scrivere le opzioni di ${v}"
  for caso in "${casi[@]}"; do
    echo "== ${v}, ${caso}: risposta ($2, effort $3)"
    rispondi "${caso}" "${v}" "$2" "$3" || exit $?
    echo "== ${v}, ${caso}: controlli"
    rc=0
    python3 -B "${KIT}" controlla "${caso}" "${v}" || rc=$?
    (( rc <= 1 )) || die "i controlli di ${v}, ${caso} non sono riusciti" \
      "(uscita ${rc}): la misura si ferma prima del giudizio"
    echo "== ${v}, ${caso}: giudizio"
    giudica "${caso}" "${v}" || exit $?
  done
  python3 -B "${KIT}" riepilogo "${v}"
}

main() {
  local modello=sonnet effort=low confronta=0 v
  local -a pos=()
  # Un'opzione senza valore lo lascia vuoto: lo rifiutano, con l'uscita 2, i
  # controlli del modello e dell'effort qui sotto.
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
    (( ${#pos[@]} == 2 )) \
      || die "uso: ./misura.sh --confronta <versione> <versione>"
    python3 -B "${KIT}" confronta "${pos[0]}" "${pos[1]}"
    return
  fi
  command -v claude >/dev/null 2>&1 || die "manca claude"
  (( ${#pos[@]} == 1 )) \
    || die "uso: ./misura.sh <versione> [--modello M] [--effort E]"
  v="${pos[0]}"
  [[ "${v}" =~ ${VERSIONE_RE} ]] \
    || die "versione «${v}» non valida: si scrive v0, v1, v2, ..."
  [[ -f "prompt/${v}.md" ]] || die "manca prompt/${v}.md"
  misura "${v}" "${modello}" "${effort}"
}

main "$@"
