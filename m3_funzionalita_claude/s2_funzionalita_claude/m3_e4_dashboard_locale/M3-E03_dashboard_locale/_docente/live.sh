#!/bin/bash
#
# live.sh di M3-E03 -- la prova dal vivo dell'esercitazione, come la farebbe
# un partecipante sul percorso B: il prompt del README (fra le righe
# «<!-- prompt -->» e «<!-- /prompt -->») in claude -p su sonnet, effort
# medium, nello spazio di lavoro e con le sue impostazioni di progetto,
# senza server MCP (--strict-mcp-config). Gli strumenti consentiti sono
# Read, Write, Edit e, esattamente, le regole Bash di permissions.allow
# delle impostazioni dello spazio di lavoro (i comandi dell'esercizio):
# in dontAsk un altro comando viene negato, dove il partecipante si vede
# chiedere il permesso. Finché la verifica
# dell'elemento non passa, fino a tre turni in più nella stessa sessione,
# ripresa con --resume e l'ID di sessione del JSON:
#   - se dashboard.html manca, «Scrivi, se manca, ed esegui
#     genera_dashboard.py come chiedeva il primo messaggio; poi esegui
#     python3 controlla_dashboard.py e correggi finché esce 0. …»;
#   - altrimenti «Esegui python3 controlla_dashboard.py e correggi
#     genera_dashboard.py finché il controllo esce con 0. …»;
#   e tutti e due finiscono come il prompt del README: «Esegui ogni comando
#   da solo, senza concatenarlo ad altri, e leggi l'uscita del controllo
#   nella sua ultima riga.»
# Ogni turno lascia il suo JSON in prova_dal_vivo/turno-<n>.json dello
# spazio di lavoro e ne stampa i turni del modello, la durata e i token.
# Poi verifica.sh dell'elemento.
#
# Uso:    _docente/live.sh <spazio di lavoro>
# Env:    le variabili di tools/lib_handson.sh (HANDSON_NO_PAUSE, …)
# Uscita: 0 = verifica.sh passa · 1 = una chiamata a claude fallita, o
#         verifica.sh esce 1 · 2 = precondizione (spazio di lavoro, un file
#         o uno strumento che manca, il prompt che il README non ha, le
#         impostazioni senza regole Bash), anche di verifica.sh
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
# lo script sta in <radice>/m3_…/s2_…/m3_e4_…/M3-E03_…/_docente/
readonly RADICE="${SELF%/*/*/*/*/*/*}"
readonly ELEMENTO="${SELF%/_docente/*}"
readonly CONTROLLO="${ELEMENTO}/verifica.sh"
readonly README="${ELEMENTO}/README.md"
# shellcheck source=../../../../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"

readonly MODELLO=sonnet
# Gli strumenti dei file, davanti alle regole Bash delle impostazioni.
readonly STRUMENTI_FILE='Read,Write,Edit'
readonly IMPOSTAZIONI=.claude/settings.json
# Le regole Bash di permissions.allow, unite da virgole (filtro di jq).
REGOLE_BASH='[.permissions.allow[]? | select(type == "string"'
REGOLE_BASH+=' and startswith("Bash("))] | join(",")'
readonly REGOLE_BASH
STRUMENTI=''
UN_COMANDO="Esegui ogni comando da solo, senza concatenarlo ad altri, e"
UN_COMANDO+=" leggi l'uscita del controllo nella sua ultima riga."
readonly UN_COMANDO
SEGUITO_PAGINA='Scrivi, se manca, ed esegui genera_dashboard.py come'
SEGUITO_PAGINA+=' chiedeva il primo messaggio; poi esegui python3'
SEGUITO_PAGINA+=" controlla_dashboard.py e correggi finché esce 0."
SEGUITO_PAGINA+=" ${UN_COMANDO}"
readonly SEGUITO_PAGINA
SEGUITO_CONTROLLO='Esegui python3 controlla_dashboard.py e correggi'
SEGUITO_CONTROLLO+=" genera_dashboard.py finché il controllo esce con 0."
SEGUITO_CONTROLLO+=" ${UN_COMANDO}"
readonly SEGUITO_CONTROLLO
readonly SEGUITI_MASSIMI=3
readonly CARTELLA_JSON=prova_dal_vivo
# Il riepilogo di un turno, dal JSON di claude -p (filtro di jq).
# shellcheck disable=SC2016  # \(…) è di jq, non un'espansione della shell
RIEPILOGO='"  turno \($n): \(.num_turns // "?") turni del modello, '
RIEPILOGO+='\(((.duration_ms // 0) / 1000) | floor) s, token in entrata '
RIEPILOGO+='\((.usage.input_tokens // 0)'
RIEPILOGO+=' + (.usage.cache_creation_input_tokens // 0)'
RIEPILOGO+=' + (.usage.cache_read_input_tokens // 0)), in uscita '
RIEPILOGO+='\(.usage.output_tokens // 0)"'
readonly RIEPILOGO

# Il prompt del README, fra le due righe segno, senza il rientro comune.
# Outputs: il prompt su STDOUT. Returns: 2 se il README non lo ha.
prompt_del_readme() {
  python3 -B -I - "${README}" <<'PY'
import sys
import textwrap

righe = open(sys.argv[1], encoding="utf-8").read().split("\n")
segni = [i for i, r in enumerate(righe)
         if r.strip() in ("<!-- prompt -->", "<!-- /prompt -->")]
if len(segni) != 2 or righe[segni[0]].strip() != "<!-- prompt -->":
    sys.exit(2)
testo = textwrap.dedent("\n".join(righe[segni[0] + 1:segni[1]])).strip("\n")
if not testo.strip():
    sys.exit(2)
print(testo)
PY
}

# Un turno: il JSON in prova_dal_vivo/turno-<n>.json. Va chiamata nella
# shell dello script, non dentro $(…): così una precondizione di
# handson::claude_p esce davvero con 2.
# Arguments: $1 il numero del turno, $2 il testo, poi le opzioni in più.
# Returns: l'uscita di claude.
turno() {
  local n="$1" testo="$2"
  shift 2
  handson::claude_p "${MODELLO}" "${STRUMENTI}" "${testo}" --effort medium \
    --strict-mcp-config "$@" > "${CARTELLA_JSON}/turno-${n}.json"
}

# Gli strumenti consentiti: Read, Write, Edit e le regole Bash di
# permissions.allow delle impostazioni dello spazio di lavoro.
# Globals: STRUMENTI (assegnata). Returns: 0; esce 2 se le impostazioni
# non si leggono o non hanno nessuna regola Bash.
strumenti_delle_impostazioni() {
  local regole
  regole="$(jq -r "${REGOLE_BASH}" "${IMPOSTAZIONI}")" \
    || handson::die "${IMPOSTAZIONI} non si legge come JSON"
  [[ -n "${regole}" ]] \
    || handson::die "${IMPOSTAZIONI}: nessuna regola Bash in" \
      "permissions.allow, e senza i comandi dell'esercizio la prova non" \
      "ha senso"
  STRUMENTI="${STRUMENTI_FILE},${regole}"
}

# Turni del modello, durata e token di un turno, su STDOUT.
# Arguments: $1 il numero del turno.
riepilogo() {
  jq -r --arg n "$1" "${RIEPILOGO}" "${CARTELLA_JSON}/turno-$1.json" \
    || printf '  turno %s: il JSON non si legge\n' "$1"
}

# L'ID di sessione di un turno. Arguments: $1 il numero del turno.
# Outputs: l'ID su STDOUT. Returns: 1 se il JSON non lo ha.
sessione_di() {
  jq -er '.session_id | select(type == "string" and length > 0)' \
    "${CARTELLA_JSON}/turno-$1.json"
}

# Che cosa manca, dopo un turno: «fatto» (la verifica passa), «pagina»
# (dashboard.html manca) o «controllo» (la pagina c'è ma non passa).
# Arguments: $1 lo spazio di lavoro.
# Outputs: la parola su STDOUT. Returns: 2 se la verifica non può girare.
stato_del_lavoro() {
  local rc=0
  "${CONTROLLO}" "$1" > /dev/null 2>&1 || rc=$?
  if (( rc == 0 )); then
    echo fatto
  elif (( rc != 1 )); then
    return 2
  elif [[ ! -f dashboard.html ]]; then
    echo pagina
  else
    echo controllo
  fi
}

# Una chiamata senza risposta: il verdetto KO e la fine con uscita 1.
# Arguments: il testo del verdetto.
fallita() {
  handson::verdict ko "$*"
  handson::finish
}

main() {
  local ws="${1:-}" prompt sessione stato seguito n f out rc=0
  [[ -n "${ws}" && -d "${ws}" ]] \
    || handson::die "spazio di lavoro assente: ${ws}"
  cd "${ws}"
  handson::need_tools python3 jq
  handson::need_file "${README}"
  handson::need_file "${CONTROLLO}"
  for f in kpi_definizioni.md controlla_dashboard.py \
      anonimo/ticket-anonimi.csv anonimo/profilo.json .claude/settings.json; do
    handson::need_file "${f}"
  done
  prompt="$(prompt_del_readme)" \
    || handson::die "il README non ha il prompt fra le righe" \
      "«<!-- prompt -->» e «<!-- /prompt -->»"
  strumenti_delle_impostazioni
  handson::need_claude
  handson::note "strumenti consentiti: ${STRUMENTI}"
  handson::banner M3-E03 "La stessa dashboard in Claude Code" \
    "Modulo 3, laboratorio: la prova del partecipante, percorso B"
  mkdir -p "${CARTELLA_JSON}"
  handson::step "Turno 1: il prompt del README"
  turno 1 "${prompt}" || fallita "il turno 1 non ha dato una risposta"
  riepilogo 1
  sessione="$(sessione_di 1)" || fallita "il turno 1 non ha un ID di sessione"
  for (( n = 2; n <= SEGUITI_MASSIMI + 1; n++ )); do
    stato="$(stato_del_lavoro "${ws}")" \
      || handson::die "la verifica dell'elemento non può girare"
    case "${stato}" in
      fatto) break ;;
      pagina) seguito="${SEGUITO_PAGINA}" ;;
      *) seguito="${SEGUITO_CONTROLLO}" ;;
    esac
    handson::step "Turno ${n}: ${seguito}"
    turno "${n}" "${seguito}" --resume "${sessione}" \
      || fallita "il turno ${n} non ha dato una risposta"
    riepilogo "${n}"
    sessione="$(sessione_di "${n}")" \
      || fallita "il turno ${n} non ha un ID di sessione"
  done
  handson::step "La verifica"
  out="$("${CONTROLLO}" "${ws}" 2>&1)" || rc=$?
  printf '%s\n' "${out}"
  handson::verdict_rc "${rc}" "verifica.sh dell'elemento"
  handson::finish
}

main "$@"
