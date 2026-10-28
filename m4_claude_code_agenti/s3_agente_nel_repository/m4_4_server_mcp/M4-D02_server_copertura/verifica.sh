#!/bin/bash
#
# verifica.sh di M4-D02 -- un server MCP per la copertura. Il controllo sta
# in controlla_copertura.py, nella cartella dell'elemento e non nello
# spazio di lavoro, perché calcola la verità dai dati del gestionale, che
# nello spazio di lavoro non ci sono. Verifica ciò che trova:
#   - la vostra prova, se c'è risposta.txt: claude mcp get copertura, una
#     chiamata alla CLI e non al modello, deve dire che il server è
#     configurato in questo spazio di lavoro, e risposta.txt deve nominare
#     esattamente i comuni con indirizzi coperti dalla fibra FTTH;
#   - la prova del docente, se c'è risposte/: le sei esecuzioni con e senza
#     il server, con i verdetti di due garanzie di Anthropic (con
#     --strict-mcp-config, solo i server di --mcp-config; gli strumenti MCP
#     si chiamano mcp__<server>__<tool>) e, come dati, gli strumenti
#     chiamati e le risposte contro la verità.
# Non scrive niente.
#
# Uso:    verifica.sh <spazio di lavoro>
# Uscita: 0 = ciò che c'è va; l'ultima riga è «Fatto: …» · 1 = il punto di
#         partenza, il server non configurato (claude mcp get esce con 1),
#         risposta.txt che non nomina esattamente i comuni giusti,
#         un'esecuzione che manca o non va, o una garanzia non confermata ·
#         2 = precondizione (spazio di lavoro assente, python3, claude o il
#         controllo che mancano, claude mcp get uscito con un codice oltre
#         1, i dati del gestionale o un file che non si leggono, il
#         controllo uscito con un codice fuori dal suo contratto)
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly CONTROLLO="${SELF%/*}/controlla_copertura.py"
FATTO='Fatto: ogni affermazione è stata messa alla prova;'
FATTO+=' gli esiti sono qui sopra.'
readonly FATTO

# Il server copertura è configurato nello spazio di lavoro? Lo dice
# claude mcp get, dallo spazio di lavoro: lo scope local vale per la
# cartella in cui si è dato claude mcp add. Stampa la riga dello stato, se
# c'è; mai l'ambiente del server. claude mcp get esce con 1 quando il
# server non c'è; un'uscita oltre 1 è un errore della CLI, che non dice se
# il server c'è: lo si dice su STDERR, e non è «non configurato».
# Arguments: $1 lo spazio di lavoro.
# Returns: 0 configurato; 1 no; 2 claude mcp get uscito con più di 1.
configurato() {
  local uscita rc=0 stato
  uscita="$(cd "$1" && claude mcp get copertura < /dev/null 2>&1)" || rc=$?
  if (( rc >= 2 )); then
    echo "verifica: claude mcp get copertura è uscito con ${rc}: un errore" \
      "della CLI, non un esito (PRIMA_DEL_CORSO.md," \
      "tools/verifica_ambiente.sh)" >&2
    if [[ -n "${uscita}" ]]; then
      printf '  %s\n' "${uscita%%$'\n'*}" >&2
    fi
    return 2
  fi
  if (( rc != 0 )); then
    echo "Il server copertura non è configurato in questo spazio di lavoro" \
      "(claude mcp get copertura esce con ${rc}): aggiungetelo con claude" \
      "mcp add, come nel passo 3 del README, dallo spazio di lavoro."
    if [[ -n "${uscita}" ]]; then
      printf '  %s\n' "${uscita%%$'\n'*}"
    fi
    return 1
  fi
  echo "claude mcp get copertura: il server è configurato in questo spazio" \
    "di lavoro."
  if stato="$(grep -m 1 -E '^[[:space:]]*Status:' <<< "${uscita}")"; then
    printf '  %s\n' "${stato#"${stato%%[![:space:]]*}"}"
  fi
}

main() {
  local ws="${1:-}" rc=0 rc_get=0
  if [[ -z "${ws}" || ! -d "${ws}" ]]; then
    echo "verifica: spazio di lavoro assente: ${ws}" >&2
    exit 2
  fi
  if ! command -v python3 > /dev/null 2>&1; then
    echo "verifica: manca python3 (tools/verifica_ambiente.sh)" >&2
    exit 2
  fi
  if [[ ! -f "${CONTROLLO}" || ! -r "${CONTROLLO}" ]]; then
    echo "verifica: manca il controllo ${CONTROLLO}" >&2
    exit 2
  fi
  if [[ -e "${ws}/risposta.txt" ]]; then
    if ! command -v claude > /dev/null 2>&1; then
      echo "verifica: manca claude, che dice se il server è configurato" \
        "(PRIMA_DEL_CORSO.md)" >&2
      exit 2
    fi
    configurato "${ws}" || rc_get=$?
    if (( rc_get >= 2 )); then
      exit 2
    fi
  fi
  python3 -B -I "${CONTROLLO}" "${ws}" || rc=$?
  case "${rc}" in
    0|1) ;;
    2) exit 2 ;;
    *)
      echo "verifica: controlla_copertura.py è uscito con ${rc}: un errore" \
        "del controllo, non un esito" >&2
      exit 2
      ;;
  esac
  if (( rc != 0 || rc_get != 0 )); then
    exit 1
  fi
  echo "${FATTO}"
}

main "$@"
