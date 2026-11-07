#!/bin/bash
#
# prova_contesto.sh -- le prove di un CLAUDE.md nel metodo del Modulo 6: le
# stesse richieste, ciascuna in una sessione nuova di `claude -p`, in una
# copia pulita dello spazio di lavoro, senza i file di istruzioni (base) o
# con quelli che avete scritto (v1, v2). Anthropic consiglia di cominciare
# senza CLAUDE.md, per vedere dove si deve correggere Claude: «We recommend
# starting a project without a CLAUDE.md file so you can see where you
# constantly have to course-correct the model.» (Anthropic Academy, «The
# CLAUDE.md file»). Un controllo legge i risultati, ogni volta da capo.
#
# Uso:    tools/prova_contesto.sh <ID> base|v1|v2 [--radice <cartella>]
#
#   base   ogni richiesta senza CLAUDE.md, CLAUDE.local.md, AGENTS.md e
#          .claude/rules/
#   v1     ogni richiesta con i file di istruzioni dello spazio di lavoro
#   v2     lo stesso, dopo che li avete cambiati
#   --radice  la stessa data a prepara_esercizio.sh, se c'era
#
# Ogni esecuzione lascia in <spazio>/prove-contesto/<versione>/<richiesta>/:
# stream.jsonl, stderr.txt, prompt.txt, strumenti.txt, file-cambiati.txt
# (git status --porcelain della copia), commit.txt e file-committati.txt (i
# commit che Claude ha fatto), diff.txt (git diff dal commit di partenza:
# ciò che è cambiato, nei commit e no) e caricamenti.jsonl (il registro dell'hook
# InstructionsLoaded: che cosa si è caricato e perché). La versione provata
# sta in prove-contesto/<versione>/fotografia/: i file di istruzioni e
# .claude/settings.json. Poi `python3 -B -I <elemento>/verifica.py <spazio>
# --solo-prove` stampa il confronto. Un giro che c'è già non si
# sovrascrive. Al massimo tre esecuzioni insieme, e un giro per volta su uno
# spazio di lavoro; una che fallisce non ferma le altre. Le copie stanno in
# una cartella temporanea che sparisce alla fine (tools/lib_prova_contesto.sh
# dice che cosa contengono). Tutto ciò che si può controllare fallisce prima
# della prima chiamata.
#
# La configurazione è in <elemento>/prove/config, righe «chiave=valore»:
#   modello  default sonnet
#   effort   default low
#   escludi  i percorsi, separati da spazi, che le copie non hanno (gli
#            appunti del team, vendor/…)
#   vietati  le regole negate a ogni esecuzione, per --disallowedTools
# Le richieste sono in <elemento>/prove/richieste.tsv: «id», «strumenti»
# (nomi separati da virgole: --tools e --allowedTools) e «prompt»,
# separati da tabulazioni. Facoltativo <elemento>/prove/prima.sh <copia>
# <id>, eseguibile: gira nella copia prima del suo commit di partenza.
# Obbligatorio <elemento>/verifica.py, con l'opzione --solo-prove.
#
# Env:    PN_HANDSON_ROOT    il repository (default: la cartella sopra tools/)
#         PN_WORKSPACE_ROOT  la radice degli spazi di lavoro, se non c'è
#                            --radice (default ~/corso-claude-code)
# Uscita: 0 = esecuzioni fatte e lette · 1 = un'esecuzione è fallita, o una
#         garanzia non regge (verifica.py esce 1) · 2 = precondizione:
#         argomenti, git, python3 o pgrep che mancano, elemento, spazio di
#         lavoro, configurazione, richieste, l'hook, un giro che c'è già o
#         in corso, verifica.py assente, una v1 o una v2 senza CLAUDE.md
#         alla radice, una v2 uguale alla v1 · 128 + il segnale (130 INT, 143
#         TERM, 129 HUP, 141 PIPE) = interrotto: le sessioni in corso sono
#         ferme e le copie cancellate
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
# shellcheck source=lib_handson.sh
source "${SELF%/*}/lib_handson.sh"
# shellcheck source=lib_prova_contesto.sh
source "${SELF%/*}/lib_prova_contesto.sh"

ARG_ID=''
ARG_VERSIONE=''
ARG_RADICE=''

usage() {
  cat <<'EOF'
Uso: tools/prova_contesto.sh <ID> base|v1|v2 [--radice <cartella>]
  base                 ogni richiesta senza i file di istruzioni
  v1, v2               ogni richiesta con quelli dello spazio di lavoro
  --radice <cartella>  la stessa data a prepara_esercizio.sh, se c'era
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

# Legge gli argomenti: due posizionali e --radice, in qualunque ordine.
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
  (( ${#posti[@]} == 2 )) || sbagliato
  ARG_ID="${posti[0]}" ARG_VERSIONE="${posti[1]}"
  case "${ARG_VERSIONE}" in
    base|v1|v2) ;;
    *) sbagliato "la versione è base, v1 o v2, non «${ARG_VERSIONE}»" ;;
  esac
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
  contesto::leggi_config "${HANDSON_ITEM_DIR}/prove/config"
  contesto::esegui "${ARG_VERSIONE}" "${ARG_RADICE}"
}

main "$@"
