#!/bin/bash
#
# live.sh di M4-E05 -- la prova dal vivo della traccia (c) del laboratorio,
# la variante dei sistemi, come la farebbe un partecipante che sceglie
# Python, in due parti. I prompt del README, fra le righe «<!-- prompt N
# -->» e «<!-- /prompt N -->», in claude -p su sonnet, effort medium, nello
# spazio di lavoro e con le sue impostazioni di progetto (il revisore di
# .claude/agents/, i piani in piani/), senza server MCP
# (--strict-mcp-config):
#   prima parte   il prompt 1 in plan mode (il piano, che resta in piani/);
#                 i prompt 2, 3 e 4 in dontAsk, ripresi con --resume e
#                 l'ID di sessione del turno prima: in -p il piano non si
#                 approva dalla finestra, e il prompt 2 lo approva; il 3
#                 chiede il revisore; il 4 NOTA.md e il commit;
#   seconda parte il prompt 5 in una sessione nuova, che riparte da NOTA.md;
#                 poi, finché la verifica non passa, fino a due volte il
#                 prompt 6 nella stessa sessione. Una segnalazione sul
#                 revisore non si corregge con un seguito: lì la prova si
#                 ferma.
# Gli strumenti consentiti sono quelli che servono ai passi, uno per
# comando: Read, Write, Edit, il controllo, lo script (in Python o in
# Bash), git add e git commit. In -p le regole allow delle impostazioni di
# una cartella mai autorizzata non valgono: per questo le passa tutte qui.
# git log, git diff, e grep, find, head e wc per guardare i log a pezzi,
# non servono qui: sono comandi di sola lettura, che Claude Code di regola
# esegue senza chiedere. Lo spazio di lavoro dev'essere al punto di
# partenza (git status vuoto, nessun commit dopo il primo): altrimenti
# esce 2 e indica tools/reset_esercizio.sh M4-E05. Ogni turno lascia il
# suo JSON fuori dallo spazio di lavoro (lib_live_m4_e04_e05.sh), e ne
# stampa turni del modello, durata e token. Poi verifica.sh dell'elemento.
#
# Uso:    _docente/live.sh <spazio di lavoro>
# Env:    le variabili di tools/lib_handson.sh (HANDSON_NO_PAUSE, …)
#         PN_LIVE_JSON   la cartella dei JSON (default: accanto allo spazio
#                        di lavoro, <spazio>.prova_dal_vivo)
#         PN_CLAUDE_DIR  passa a verifica.sh (le prove del docente)
# Uscita: 0 = verifica.sh passa · 1 = una chiamata a claude fallita, o
#         verifica.sh esce 1 · 2 = precondizione (spazio di lavoro assente
#         o con del lavoro, un file o uno strumento che manca, un prompt
#         che il README non ha), anche di verifica.sh
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
# lo script sta in <radice>/m4_…/s3_…/m4_e2_…/M4-E05_…/_docente/
readonly RADICE="${SELF%/*/*/*/*/*/*}"
readonly ELEMENTO="${SELF%/_docente/*}"
# shellcheck source=../../../../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"
# shellcheck source=../../../../_docente/lib_live_m4_e04_e05.sh
source "${RADICE}/m4_claude_code_agenti/_docente/lib_live_m4_e04_e05.sh"

# Le variabili che leggono le funzioni lab:: della libreria.
# shellcheck disable=SC2034  # le legge lib_live_m4_e04_e05.sh
readonly LAB_README="${ELEMENTO}/README.md"
readonly LAB_CONTROLLO="${ELEMENTO}/verifica.sh"
STRUMENTI='Read,Write,Edit,Bash(python3 controlla_rapporto.py),'
STRUMENTI+='Bash(python3 rapporto_giornaliero.py *),'
STRUMENTI+='Bash(bash rapporto_giornaliero.sh *),Bash(git add *),'
STRUMENTI+='Bash(git commit *)'
# shellcheck disable=SC2034  # la legge lib_live_m4_e04_e05.sh
readonly LAB_STRUMENTI="${STRUMENTI}"

# I file che servono e i sei prompt del README.
# Arguments: $1 lo spazio di lavoro.
precondizioni() {
  local f
  for f in "${LAB_README}" "${LAB_CONTROLLO}" SPECIFICA.md \
      controlla_rapporto.py .claude/settings.json .claude/agents/revisore.md \
      progetti/rete/README.md; do
    handson::need_file "${f}"
  done
  [[ -d progetti/rete/log/syslog ]] \
    || handson::die "mancano i log della rete in progetti/rete/log/"
  [[ -d .git ]] || handson::die "$1 non è uno spazio di lavoro preparato"
  lab::prompts
}

main() {
  local ws="${1:-}"
  [[ -n "${ws}" && -d "${ws}" ]] \
    || handson::die "spazio di lavoro assente: ${ws}"
  cd "${ws}"
  handson::need_tools python3 jq git
  precondizioni "${ws}"
  lab::al_punto_di_partenza M4-E05
  handson::need_claude
  handson::note "strumenti consentiti: ${LAB_STRUMENTI}"
  handson::banner M4-E05 "Il rapporto quotidiano dei log" \
    "Modulo 4, laboratorio, traccia (c), la rete: il partecipante"
  lab::cartella_json "${ws}"
  lab::due_parti "${ws}"
  lab::verifica "${ws}"
}

main "$@"
