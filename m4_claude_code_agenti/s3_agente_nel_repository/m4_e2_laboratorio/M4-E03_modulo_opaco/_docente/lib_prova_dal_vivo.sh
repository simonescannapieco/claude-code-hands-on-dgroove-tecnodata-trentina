# shellcheck shell=bash
#
# lib_prova_dal_vivo.sh -- le funzioni di _docente/live.sh di M4-E03: lo
# spazio di lavoro al punto di partenza, la cartella dei JSON fuori dallo
# spazio di lavoro, i prompt del README, un turno di claude -p con il suo
# JSON, il riepilogo di un turno, l'ID di sessione e la prova dei test fra
# un turno e l'altro.
# Libreria: si fa source, non si esegue. Usa tools/lib_handson.sh e queste
# variabili, che live.sh definisce prima di chiamarla: README, CONTROLLO,
# MODELLO, STRUMENTI, PHP_SH, PROGETTO, TEST_REL; e N_TURNO, il contatore
# dei turni, PROMPT, i prompt del README, e CARTELLA_JSON, che assegna
# prova::cartella_json.

# Le precondizioni nello spazio di lavoro (la cartella corrente), che deve
# essere al punto di partenza, i cinque prompt del README in PROMPT[1…5],
# la cartella dei JSON fuori dallo spazio di lavoro e le dipendenze del
# gestionale, come nel «Punto di partenza» del README.
# Globals: PROMPT, CARTELLA_JSON (assegnate). Returns: 0; esce 2 su una
# precondizione.
# shellcheck disable=SC2034  # PROMPT la legge live.sh
prova::prepara() {
  local f n
  handson::need_tools python3 jq git
  for f in "${README}" "${CONTROLLO}" .claude/settings.json tools/php.sh \
      "${PROGETTO}/legacy/chiusura_mese.inc.php"; do
    handson::need_file "${f}"
  done
  [[ -x "${PHP_SH}" ]] || handson::die "manca il php.sh del corso: ${PHP_SH}"
  [[ -d .git ]] \
    || handson::die "$(pwd -P) non è uno spazio di lavoro preparato"
  prova::al_punto_di_partenza M4-E03
  for n in 1 2 3 4 5; do
    PROMPT[n]="$(prova::prompt "${n}")" \
      || handson::die "il README non ha il prompt ${n} fra i segni"
  done
  handson::need_claude
  prova::cartella_json
  handson::step "Le dipendenze del gestionale, come nel Punto di partenza"
  handson::run "${PHP_SH}" composer install -d "${PROGETTO}" \
    --no-interaction --no-progress \
    || handson::die "le dipendenze del gestionale non si installano"
}

# Lo spazio di lavoro (la cartella corrente) al punto di partenza: git
# status vuoto e nessun commit dopo il primo. Su uno spazio di lavoro già
# usato la prova ripartirebbe dal lavoro di prima, e la verifica potrebbe
# passare su quello. Arguments: $1 l'identificativo dell'elemento, per il
# reset. Returns: 0; esce 2 se lo spazio di lavoro ha già del lavoro.
prova::al_punto_di_partenza() {
  local stato commit
  stato="$(git status --porcelain)" || handson::die "git status non riesce"
  [[ -z "${stato}" ]] \
    || handson::die "lo spazio di lavoro non è al punto di partenza (git" \
      "status non è vuoto): tools/reset_esercizio.sh $1"
  commit="$(git rev-list --count HEAD)" \
    || handson::die "git rev-list non riesce"
  if [[ ! "${commit}" =~ ^[0-9]+$ ]] || (( commit != 1 )); then
    handson::die "lo spazio di lavoro non è al punto di partenza (ci sono" \
      "commit dopo il primo): tools/reset_esercizio.sh $1"
  fi
}

# La cartella dei JSON dei turni, FUORI dallo spazio di lavoro (la cartella
# corrente): PN_LIVE_JSON oppure <spazio di lavoro>.prova_dal_vivo, come
# lab::cartella_json di lib_live_m4_e04_e05.sh. La seconda parte è una
# sessione nuova, che riparte dalla nota: non deve poter leggere le
# risposte della prima. Esce 2 se starebbe dentro.
# Globals: CARTELLA_JSON (assegnata).
prova::cartella_json() {
  local ws reale
  ws="$(pwd -P)" || handson::die "spazio di lavoro illeggibile"
  CARTELLA_JSON="${PN_LIVE_JSON:-${ws}.prova_dal_vivo}"
  mkdir -p -- "${CARTELLA_JSON}" \
    || handson::die "non riesco a creare ${CARTELLA_JSON}"
  reale="$(cd "${CARTELLA_JSON}" && pwd -P)" \
    || handson::die "non riesco a leggere ${CARTELLA_JSON}"
  if [[ "${reale}/" == "${ws}/"* ]]; then
    handson::die "i JSON delle prove non stanno nello spazio di lavoro:" \
      "${reale}"
  fi
  CARTELLA_JSON="${reale}"
  handson::note "i JSON dei turni in ${CARTELLA_JSON}"
}

# Il prompt n del README, fra «<!-- prompt n -->» e «<!-- /prompt n -->»,
# senza il rientro comune.
# Arguments: $1 il numero. Outputs: il prompt su STDOUT.
# Returns: 0; 2 se il README non lo ha.
prova::prompt() {
  python3 -B -I - "${README}" "$1" <<'PY'
import sys
import textwrap

righe = open(sys.argv[1], encoding="utf-8").read().split("\n")
n = sys.argv[2]
a = [i for i, r in enumerate(righe) if r.strip() == "<!-- prompt %s -->" % n]
b = [i for i, r in enumerate(righe) if r.strip() == "<!-- /prompt %s -->" % n]
if len(a) != 1 or len(b) != 1 or a[0] > b[0]:
    sys.exit(2)
testo = textwrap.dedent("\n".join(righe[a[0] + 1:b[0]])).strip("\n")
if not testo.strip():
    sys.exit(2)
print(testo)
PY
}

# Un turno: claude -p su ${MODELLO}, effort medium, senza server MCP, con
# gli strumenti di ${STRUMENTI}; il JSON in ${CARTELLA_JSON}/turno-<n>.json.
# La modalità di permesso è HANDSON_PERMISSION_MODE (dontAsk, o plan per la
# proposta). Va chiamata nella shell dello script, non dentro $(…): così
# una precondizione di handson::claude_p esce davvero con 2.
# Globals: N_TURNO (incrementata). Arguments: $1 il testo, poi le opzioni
# in più (--resume <id>). Returns: l'uscita di claude.
prova::turno() {
  local testo="$1"
  shift
  N_TURNO=$((N_TURNO + 1))
  handson::step "Turno ${N_TURNO} (${HANDSON_PERMISSION_MODE})"
  handson::claude_p "${MODELLO}" "${STRUMENTI}" "${testo}" --effort medium \
    --strict-mcp-config "$@" > "${CARTELLA_JSON}/turno-${N_TURNO}.json"
}

# Il turno della proposta, in plan mode: la stessa prova::turno con
# HANDSON_PERMISSION_MODE=plan soltanto per questa chiamata.
# Arguments: come prova::turno.
prova::turno_in_plan_mode() {
  local HANDSON_PERMISSION_MODE=plan
  prova::turno "$@"
}

# L'ID di sessione dell'ultimo turno.
# Outputs: l'ID su STDOUT. Returns: 1 se il JSON non lo ha.
prova::sessione() {
  jq -er '.session_id | select(type == "string" and length > 0)' \
    "${CARTELLA_JSON}/turno-${N_TURNO}.json"
}

# Turni del modello, durata e token dell'ultimo turno, su STDOUT.
prova::riepilogo() {
  # shellcheck disable=SC2016  # \(…) è di jq, non un'espansione della shell
  local filtro='"  turno \($n): \(.num_turns // "?") turni del modello, '
  filtro+='\(((.duration_ms // 0) / 1000) | floor) s, token in entrata '
  filtro+='\((.usage.input_tokens // 0)'
  filtro+=' + (.usage.cache_creation_input_tokens // 0)'
  filtro+=' + (.usage.cache_read_input_tokens // 0)), in uscita '
  filtro+='\(.usage.output_tokens // 0)"'
  jq -r --arg n "${N_TURNO}" "${filtro}" \
    "${CARTELLA_JSON}/turno-${N_TURNO}.json" \
    || printf '  turno %s: il JSON non si legge\n' "${N_TURNO}"
}

# I test di caratterizzazione sono verdi? Il comando del README, dalla
# radice dello spazio di lavoro, con il php.sh del corso.
# Returns: 0 verdi; 1 rossi, non eseguibili o senza il file del test.
prova::test_verdi() {
  [[ -f "${TEST_REL}" ]] || return 1
  "${PHP_SH}" php "${PROGETTO}/vendor/bin/phpunit" -c "${PROGETTO}" \
    --colors=never "${TEST_REL}" > /dev/null 2>&1
}
