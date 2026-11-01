# shellcheck shell=bash
# =====================================================================
# lib_live_m4_e04_e05.sh -- le funzioni comuni dei _docente/live.sh di
# M4-E04 e M4-E05, le due varianti della traccia (c) del laboratorio: lo
# spazio di lavoro al punto di partenza, i prompt del README e il titolo
# del loro turno, i turni di claude -p con il loro stream, il loro ultimo
# risultato e il riepilogo che somma tutti i risultati (lib_turni_m4.sh),
# le due parti della prova, la verifica finale.
# ---------------------------------------------------------------------
# Libreria: si fa SOURCE dopo tools/lib_handson.sh, non si esegue (nessun
# bit di esecuzione). Le funzioni leggono le variabili che il live.sh
# imposta prima di chiamarle:
#   LAB_README     il README dell'elemento
#   LAB_CONTROLLO  il verifica.sh dell'elemento
#   LAB_STRUMENTI  gli strumenti consentiti (--allowedTools)
# e lavorano nella cartella corrente, lo spazio di lavoro.
# I file dei turni (lo stream turno-<n>.jsonl e il suo ultimo risultato,
# turno-<n>.json) stanno FUORI dallo spazio di lavoro: in PN_LIVE_JSON,
# oppure accanto, in <spazio di lavoro>.prova_dal_vivo/. Una sessione
# non deve poter leggere le risposte delle sessioni prima: la seconda
# parte riparte dalla nota, non dal JSON della prima.
# =====================================================================

# shellcheck source=lib_turni_m4.sh
source "${BASH_SOURCE[0]%/*}/lib_turni_m4.sh"

readonly LAB_MODELLO=sonnet
readonly LAB_SEGUITI=2
readonly LAB_SEGNO_REVISORE="non ha tenuto"
LAB_JSON=''
LAB_SESSIONE=''
LAB_PROMPT=()

# Il prompt N del README, fra le righe «<!-- prompt N -->» e
# «<!-- /prompt N -->», senza il rientro comune.
# Globals: LAB_README. Arguments: $1 il numero.
# Outputs: il prompt su STDOUT. Returns: 2 se il README non lo ha.
lab::prompt() {
  python3 -B -I - "${LAB_README}" "$1" <<'PY'
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

# Il titolo del passo di un turno: la prima riga del prompt; se il prompt
# comincia con un tag da solo sulla sua riga (la forma a tag, un tag per
# ingrediente), la riga dopo quel tag: mai un tag.
# Arguments: $1 il prompt. Outputs: la riga su STDOUT.
lab::titolo() {
  local testo="$1" riga tag='^<[a-z_]+>$'
  riga="${testo%%$'\n'*}"
  if [[ "${riga}" =~ ${tag} && "${testo}" == *$'\n'* ]]; then
    testo="${testo#*$'\n'}"
    riga="${testo%%$'\n'*}"
  fi
  printf '%s\n' "${riga}"
}

# I sei prompt del README in LAB_PROMPT; esce 2 se ne manca uno.
# Globals: LAB_PROMPT (vi aggiunge).
lab::prompts() {
  local n testo
  for n in 1 2 3 4 5 6; do
    testo="$(lab::prompt "${n}")" \
      || handson::die "il README non ha il prompt ${n} fra le righe" \
        "«<!-- prompt ${n} -->» e «<!-- /prompt ${n} -->»"
    LAB_PROMPT+=("${testo}")
  done
}

# Lo spazio di lavoro al punto di partenza: git status vuoto e nessun
# commit dopo il primo. Su uno spazio di lavoro già usato la prova
# ripartirebbe dal lavoro di prima, e la verifica potrebbe passare su
# quello. Arguments: $1 l'identificativo dell'elemento, per il reset.
# Returns: 0; esce 2 se lo spazio di lavoro ha già del lavoro.
lab::al_punto_di_partenza() {
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

# Una chiamata senza risposta: il verdetto KO e la fine con uscita 1.
# Arguments: il testo del verdetto.
lab::fallita() {
  handson::verdict ko "$*"
  handson::finish
}

# La cartella dei JSON, fuori dallo spazio di lavoro: PN_LIVE_JSON oppure
# <spazio di lavoro>.prova_dal_vivo. Esce 2 se starebbe dentro.
# Globals: LAB_JSON (assegnata). Arguments: $1 lo spazio di lavoro.
lab::cartella_json() {
  local ws reale
  ws="$(cd "$1" && pwd -P)" || handson::die "spazio di lavoro illeggibile"
  LAB_JSON="${PN_LIVE_JSON:-${ws}.prova_dal_vivo}"
  mkdir -p -- "${LAB_JSON}" \
    || handson::die "non riesco a creare ${LAB_JSON}"
  reale="$(cd "${LAB_JSON}" && pwd -P)" \
    || handson::die "non riesco a leggere ${LAB_JSON}"
  if [[ "${reale}/" == "${ws}/"* ]]; then
    handson::die "i JSON delle prove non stanno nello spazio di lavoro:" \
      "${reale}"
  fi
  LAB_JSON="${reale}"
  handson::note "i JSON dei turni in ${LAB_JSON}"
}

# Un turno: claude -p in stream-json, lo stream in
# LAB_JSON/turno-<n>.jsonl e il suo ultimo risultato in turno-<n>.json
# (turni::chiama), nella modalità di permesso di HANDSON_PERMISSION_MODE;
# poi il riepilogo di tutti i risultati e l'ID di sessione in
# LAB_SESSIONE. Va chiamata nella shell dello script, non dentro $(…):
# così una precondizione di handson::claude_p esce davvero con 2, e una
# risposta che manca chiude con 1.
# Globals: LAB_STRUMENTI, LAB_JSON (lette); LAB_SESSIONE (assegnata).
# Arguments: $1 il numero del turno, $2 il testo, poi le opzioni in più
# (per esempio --resume <ID>).
lab::turno() {
  local n="$1" testo="$2" base
  shift 2
  base="${LAB_JSON}/turno-${n}"
  turni::chiama "${base}" "${LAB_MODELLO}" "${LAB_STRUMENTI}" "${testo}" \
    --effort medium --strict-mcp-config "$@" \
    || lab::fallita "il turno ${n} non ha dato una risposta"
  turni::riepilogo "${n}" "${base}.jsonl"
  LAB_SESSIONE="$(jq -er \
    '.session_id | select(type == "string" and length > 0)' \
    "${base}.json")" \
    || lab::fallita "il turno ${n} non ha un ID di sessione"
}

# Che cosa dice la verifica: «fatto», «segnalazione» (il revisore) o
# «lavoro». Globals: LAB_CONTROLLO. Arguments: $1 lo spazio di lavoro.
# Outputs: la parola. Returns: 2 se la verifica non può girare.
lab::stato() {
  local out rc=0
  out="$("${LAB_CONTROLLO}" "$1" 2>&1)" || rc=$?
  if (( rc == 0 )); then
    echo fatto
  elif (( rc != 1 )); then
    return 2
  elif [[ "${out}" == *"${LAB_SEGNO_REVISORE}"* ]]; then
    echo segnalazione
  else
    echo lavoro
  fi
}

# Le due parti della prova. Prima parte: il prompt 1 in plan mode (il
# piano), i prompt 2, 3 e 4 in dontAsk, ripresi con --resume. Seconda
# parte: il prompt 5 in una sessione nuova; poi, finché la verifica dice
# «lavoro», fino a LAB_SEGUITI volte il prompt 6 nella stessa sessione.
# Una segnalazione sul revisore non si corregge con un seguito.
# Globals: LAB_PROMPT, LAB_SESSIONE, HANDSON_PERMISSION_MODE.
# Arguments: $1 lo spazio di lavoro.
lab::due_parti() {
  local ws="$1" n stato
  handson::step "Prima parte, turno 1: il piano, in plan mode"
  HANDSON_PERMISSION_MODE=plan
  lab::turno 1 "${LAB_PROMPT[0]}"
  # shellcheck disable=SC2034  # la legge handson::claude_p
  HANDSON_PERMISSION_MODE=dontAsk
  for n in 2 3 4; do
    handson::step "Prima parte, turno ${n}:" \
      "$(lab::titolo "${LAB_PROMPT[n - 1]}")"
    lab::turno "${n}" "${LAB_PROMPT[n - 1]}" --resume "${LAB_SESSIONE}"
  done
  handson::step "Seconda parte, turno 5: una sessione nuova, da NOTA.md"
  lab::turno 5 "${LAB_PROMPT[4]}"
  for (( n = 6; n < 6 + LAB_SEGUITI; n++ )); do
    stato="$(lab::stato "${ws}")" \
      || handson::die "la verifica dell'elemento non può girare"
    [[ "${stato}" == "lavoro" ]] || break
    handson::step "Seconda parte, turno ${n}: $(lab::titolo "${LAB_PROMPT[5]}")"
    lab::turno "${n}" "${LAB_PROMPT[5]}" --resume "${LAB_SESSIONE}"
  done
}

# La verifica dell'elemento: la sua uscita stampata, il verdetto e la fine
# (0, 1 o 2 come handson::finish). Globals: LAB_CONTROLLO.
# Arguments: $1 lo spazio di lavoro.
lab::verifica() {
  local out rc=0
  handson::step "La verifica"
  out="$("${LAB_CONTROLLO}" "$1" 2>&1)" || rc=$?
  printf '%s\n' "${out}"
  handson::verdict_rc "${rc}" "verifica.sh dell'elemento"
  handson::finish
}
