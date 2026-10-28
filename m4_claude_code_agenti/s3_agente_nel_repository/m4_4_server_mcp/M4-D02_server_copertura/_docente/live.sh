#!/bin/bash
#
# live.sh di M4-D02 -- la demo del docente: un server MCP per la copertura.
# La stessa domanda (domanda.txt: i comuni con indirizzi coperti dalla
# fibra FTTH di CiaspoLink), lo stesso modello (sonnet, effort low), lo
# stesso solo strumento integrato (--tools Read), gli stessi strumenti
# consentiti (soltanto mcp__copertura__cerca_copertura), --strict-mcp-config
# in tutti e due i bracci; cambia soltanto la configurazione di --mcp-config:
# con.json dichiara il server del corso (uv run --frozen --directory
# <cartella del server> server_copertura.py, con COPERTURA_DATI sulla
# cartella database/ del gestionale), senza.json nessun server. Durante le
# sei esecuzioni lo spazio di lavoro ha soltanto domanda.txt, .claude/ e
# .git, e nessuna sessione può leggervi la risposta di un'altra: le
# configurazioni (con i percorsi assoluti) e gli stream stanno in una
# cartella temporanea sotto /tmp, fuori dallo spazio di lavoro, e soltanto
# dopo l'ultima esecuzione (o dopo quella fallita) live.sh li copia in mcp/
# e risposte/. Uno spazio di lavoro con altro (risposte/ e mcp/ di una
# prova precedente, risposta.txt) è una precondizione. Prima, uv sync
# --locked --offline prepara l'ambiente del server senza rete (la prima
# volta, con la rete, uv sync --frozen --directory <server>). Tre coppie,
# prima con e poi senza: sei chiamate, lo stream-json di ognuna in
# risposte/<braccio>-<n>.jsonl. Le configurazioni e le chiamate stanno in
# _docente/lib_mcp.sh: la riga di claude è quella di handson::claude_p con
# --output-format stream-json --verbose, e si vede prima di girare. Poi
# verifica.sh dice se la prova conferma le due garanzie di Anthropic e
# stampa i dati: si vedono anche quando passa.
#
# Uso:    _docente/live.sh <spazio di lavoro>
# Env:    le variabili di tools/lib_handson.sh (HANDSON_NO_PAUSE, …)
# Uscita: 0 = le sei esecuzioni ci sono, il server si è collegato e le
#         garanzie sono confermate · 1 = una chiamata fallita, il server non
#         collegato, o una garanzia non confermata · 2 = precondizione
#         (anche l'ambiente del server che uv non prepara senza rete, o uno
#         spazio di lavoro con altro oltre a domanda.txt e .claude/)
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
# lo script sta in <radice>/m4_…/s3_…/m4_4_…/M4-D02_…/_docente/
readonly RADICE="${SELF%/*/*/*/*/*/*}"
readonly ELEMENTO="${SELF%/_docente/*}"
readonly CONTROLLO="${ELEMENTO}/verifica.sh"
readonly SERVER="${ELEMENTO}/server"
readonly DATI="${RADICE}/progetti/gestionale-php/database"
# shellcheck source=../../../../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"
# shellcheck source=lib_mcp.sh
source "${SELF%/*}/lib_mcp.sh"

readonly BRACCI=(con senza)
# La cartella fuori dallo spazio di lavoro, con mcp/ e risposte/.
FUORI=''

# Ciò che c'è in FUORI, copiato nello spazio di lavoro (la cartella
# corrente), per verifica.sh e per lo schermo. Globals: FUORI (letta).
consegna() {
  cp -R -- "${FUORI}/mcp" "${FUORI}/risposte" .
}

# Una chiamata fallita: ciò che c'è va nello spazio di lavoro, poi il
# verdetto KO e la fine con uscita 1, senza fare le chiamate che restano.
fallita() {
  consegna
  handson::verdict ko "$*"
  handson::finish
}

# verifica.sh con il suo STDOUT sul descrittore 3, che main apre sullo
# STDOUT di live.sh: handson::check mostra l'uscita di un controllo solo
# su un KO, e qui i dati e i verdetti sono la demo anche quando passa.
# Arguments: $1 lo spazio di lavoro. Returns: l'uscita di verifica.sh.
# shellcheck disable=SC2317  # la chiama handson::check, indirettamente
verifica_a_schermo() {
  "${CONTROLLO}" "$1" >&3
}

# L'ambiente del server, senza rete, dalla radice del repository: a
# schermo il percorso relativo.
ambiente_server() {
  handson::step "L'ambiente del server, senza rete: uv sync"
  if ! ( cd "${RADICE}" && handson::run uv sync --locked --offline --quiet \
      --directory "${SERVER#"${RADICE}"/}" ); then
    handson::die "l'ambiente del server non è pronto: date una volta, con" \
      "la rete, uv sync --frozen --directory ${SERVER#"${RADICE}"/}" \
      "(dalla cartella del repository)"
  fi
}

# Le precondizioni: gli strumenti, la domanda, lo spazio di lavoro pulito,
# il server e i dati, dalla cartella corrente, lo spazio di lavoro.
precondizioni() {
  local f
  handson::need_tools python3 uv
  handson::need_file domanda.txt
  mcp::spazio_pulito
  for f in "${SERVER}/pyproject.toml" "${SERVER}/uv.lock" \
      "${SERVER}/server_copertura.py" "${DATI}/schema.sql"; do
    handson::need_file "${f}"
  done
}

main() {
  local ws="${1:-}" domanda n r
  [[ -n "${ws}" && -d "${ws}" ]] \
    || handson::die "spazio di lavoro assente: ${ws}"
  cd "${ws}"
  ws="$(pwd -P)"
  precondizioni
  domanda="$(< domanda.txt)"
  mcp::controlli "${domanda}"
  handson::need_claude
  handson::banner M4-D02 "Un server MCP per la copertura" \
    "Modulo 4, «Un server MCP»: la stessa domanda, con e senza il server"
  ambiente_server
  mcp::cartella_fuori FUORI
  handson::step "Le due configurazioni, fuori dallo spazio di lavoro:" \
    "con.json dichiara il server, senza.json nessuno"
  mcp::configurazioni "${SERVER}" "${DATI}" "${FUORI}/mcp"
  handson::note "con.json: uv run --frozen --directory <cartella del" \
    "server> server_copertura.py, con COPERTURA_DATI sui dati del gestionale"
  for n in 1 2 3; do
    for r in "${BRACCI[@]}"; do
      handson::step "${MCP_MODELLO}, coppia ${n}: ${r} il server"
      mcp::chiedi "${FUORI}/mcp/${r}.json" "${domanda}" \
        "${FUORI}/risposte/${r}-${n}.jsonl" \
        || fallita "${r} ${n}: claude -p è fallito"
    done
  done
  handson::step "Le configurazioni e le risposte nello spazio di lavoro:" \
    "mcp/ e risposte/"
  consegna
  handson::step "Che cosa garantisce Anthropic, e che cosa dice la prova"
  exec 3>&1
  handson::check "le sei esecuzioni, con e senza il server" \
    verifica_a_schermo "${ws}"
  handson::finish
}

main "$@"
