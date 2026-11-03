#!/bin/bash
#
# prove_skill.sh -- prova una skill nella forma della guida dello standard
# Agent Skills, «Evaluating skill output quality»: ogni caso di
# .claude/skills/<skill>/evals/evals.json gira in una sessione nuova di
# `claude -p`, in una copia pulita dello spazio di lavoro, senza la skill
# (without) o con la skill (with). I risultati stanno in
# <spazio>/<skill>-workspace/iteration-<N>/, e un controllo li legge dagli
# stream, ogni volta da capo.
#
# Uso:    tools/prove_skill.sh <ID> copia esempio|modello [--radice <cartella>]
#         tools/prove_skill.sh <ID> <N> without|with [--radice <cartella>]
#
#   copia esempio  copia riferimenti/skill-di-esempio/<esempio>/ in
#                  .claude/skills/<skill>/, tranne evals/
#   copia modello  copia riferimenti/template-SKILL.md come SKILL.md, con il
#                  nome della skill al posto di nome-della-skill
#                  Con uno SKILL.md già lì non copia niente; evals/ resta com'è.
#   <N> without    la baseline: ogni caso, senza la skill, in
#                  iteration-<N>/eval-<id>/without_skill/
#   <N> with       ogni caso con la skill, in .../eval-<id>/with_skill/, e ogni
#                  richiesta di evals/eval_queries.json in
#                  iteration-<N>/near-miss-<k>/with_skill/; prima fotografa la
#                  skill in iteration-<N>/skill-snapshot/. Da N = 2, se c'è la
#                  fotografia di prima, riusa le esecuzioni with_skill di
#                  iteration-<N-1> come old_skill: le copia, non le rifà.
#   --radice       la stessa data a prepara_esercizio.sh, se c'era
#
# Ogni esecuzione lascia in outputs/: stream.jsonl, stderr.txt, prompt.txt (il
# prompt che ha ricevuto) e file-cambiati.txt (git status --porcelain della
# copia). Poi `python3 -B -I <elemento>/verifica.py <spazio> --solo-prove`
# stampa la tabella e scrive timing.json, grading.json, benchmark.json.
# Un'esecuzione che c'è già non si sovrascrive. Al massimo tre esecuzioni
# insieme, e un giro per volta su uno spazio di lavoro; una che fallisce non
# ferma le altre. Le copie stanno in una cartella temporanea che sparisce alla
# fine: tools/lib_prove_skill.sh dice che cosa contengono. Tutto ciò che si può
# controllare fallisce prima della prima chiamata.
#
# La configurazione è in <elemento>/prove/config, righe «chiave=valore»:
#   skill      il nome della skill (obbligatorio)
#   strumenti  gli strumenti consentiti, separati da virgole (obbligatorio), con
#              Skill(<skill>) fra loro, per esempio
#              Read,Bash(git diff *),Skill(revisione-pr): in claude -p con
#              dontAsk una skill con allowed-tools o disallowed-tools è negata
#              finché le regole non ammettono Skill(<nome>)
#   modello    default sonnet
#   effort     default low
#   esempio    la cartella sotto riferimenti/skill-di-esempio/, default la skill
# Facoltativo <elemento>/prove/prima.sh <copia> <id>, eseguibile: gira nella
# copia prima di ogni caso (id = l'id del caso) e di ogni near-miss (id = q<k>);
# la copia è un repository git con un commit, sul ramo main. Obbligatorio
# <elemento>/verifica.py, con l'opzione --solo-prove (vedi
# tools/lib_controlla_prove.py).
#
# Env:    PN_HANDSON_ROOT    il repository (default: la cartella sopra tools/)
#         PN_WORKSPACE_ROOT  la radice degli spazi di lavoro, se non c'è
#                            --radice (default ~/corso-claude-code)
# Uscita: 0 = esecuzioni fatte e lette · 1 = un'esecuzione è fallita, o una
#         garanzia non regge (verifica.py esce 1) · 2 = precondizione:
#         argomenti, git, python3 o pgrep che mancano, elemento, spazio di
#         lavoro, configurazione, un'esecuzione che c'è già o una di prima non
#         riuscita da riusare, un giro già in corso, uno SKILL.md già lì per
#         copia o assente per with, verifica.py assente · 128 + il segnale
#         (130 INT, 143 TERM, 129 HUP, 141 PIPE) = interrotto: le sessioni in
#         corso sono ferme e le copie cancellate
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
# shellcheck source=lib_handson.sh
source "${SELF%/*}/lib_handson.sh"
# shellcheck source=lib_prove_skill.sh
source "${SELF%/*}/lib_prove_skill.sh"

ARG_ID=''
ARG_AZIONE=''
ARG_MODO=''
ARG_RADICE=''

usage() {
  cat <<'EOF'
Uso: tools/prove_skill.sh <ID> copia esempio|modello [--radice <cartella>]
     tools/prove_skill.sh <ID> <N> without|with [--radice <cartella>]
  copia esempio|modello  la skill di partenza, in .claude/skills/<skill>/
  <N> without            ogni caso senza la skill, in iteration-<N>/
  <N> with               ogni caso e ogni near-miss con la skill
  --radice <cartella>    la stessa data a prepara_esercizio.sh, se c'era
Uscita: 0 fatto · 1 un'esecuzione fallita o una garanzia · 2 precondizione
EOF
}

# Usage su STDERR e uscita 2. Arguments: il messaggio, facoltativo.
sbagliato() {
  if (( $# > 0 )); then
    handson::err "$*"
  fi
  usage >&2
  exit 2
}

# Legge gli argomenti: tre posizionali e --radice, in qualunque ordine.
# Globals: ARG_* (assegnate). Arguments: gli argomenti dello strumento.
leggi_argomenti() {
  local -a posti=()
  while (( $# > 0 )); do
    case "$1" in
      --radice)
        if (( $# < 2 )) || [[ -z "$2" ]]; then
          sbagliato "--radice vuole una cartella"
        fi
        ARG_RADICE="$2"
        shift ;;
      --radice=?*) ARG_RADICE="${1#--radice=}" ;;
      -*) sbagliato "opzione sconosciuta: $1" ;;
      *) posti+=("$1") ;;
    esac
    shift
  done
  (( ${#posti[@]} == 3 )) || sbagliato
  ARG_ID="${posti[0]}" ARG_AZIONE="${posti[1]}" ARG_MODO="${posti[2]}"
  if [[ "${ARG_AZIONE}" == copia ]]; then
    [[ "${ARG_MODO}" == esempio || "${ARG_MODO}" == modello ]] \
      || sbagliato "copia vuole esempio o modello, non «${ARG_MODO}»"
    return 0
  fi
  [[ "${ARG_AZIONE}" =~ ^[1-9][0-9]*$ ]] \
    || sbagliato "atteso copia o il numero dell'iterazione: «${ARG_AZIONE}»"
  [[ "${ARG_MODO}" == without || "${ARG_MODO}" == with ]] \
    || sbagliato "dopo il numero: without o with, non «${ARG_MODO}»"
}

main() {
  if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
  fi
  leggi_argomenti "$@"
  # pgrep: senza, un segnale non fermerebbe le sessioni in corso.
  handson::need_tools git python3 pgrep
  handson::init_root || exit 2
  handson::find_item "${ARG_ID}" || exit 2
  handson::init_workspace_root "${ARG_RADICE}" || exit 2
  handson::find_workspace || exit 2
  prove::leggi_config "${HANDSON_ITEM_DIR}/prove/config"
  prove::imposta_percorsi
  if [[ "${ARG_AZIONE}" == copia ]]; then
    prove::copia_skill "${ARG_MODO}"
    exit 0
  fi
  prove::esegui "${ARG_AZIONE}" "${ARG_MODO}"
}

main "$@"
