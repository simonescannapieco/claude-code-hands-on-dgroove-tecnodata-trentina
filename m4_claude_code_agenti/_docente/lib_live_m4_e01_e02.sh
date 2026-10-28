# shellcheck shell=bash
# =====================================================================
# lib_live_m4_e01_e02.sh -- le funzioni comuni dei _docente/live.sh di
# M4-E01 e M4-E02, le prove dal vivo sul gestionale: lo spazio di lavoro
# al punto di partenza, i prompt del README, i turni di claude -p con il
# loro JSON e il loro riepilogo, le dipendenze del gestionale, la
# cartella dei JSON, la verifica finale.
# ---------------------------------------------------------------------
# Libreria: si fa SOURCE dopo tools/lib_handson.sh, non si esegue (nessun
# bit di esecuzione). Le funzioni leggono le variabili che il live.sh
# imposta prima di chiamarle:
#   LIVE_README     il README dell'elemento
#   LIVE_CONTROLLO  il verifica.sh dell'elemento
#   LIVE_MODELLO    il modello di claude -p
#   LIVE_STRUMENTI  gli strumenti consentiti (--allowedTools)
# e lavorano nella cartella corrente, lo spazio di lavoro. La sessione
# dell'ultimo turno completo resta in LIVE_SESSIONE.
# I JSON dei turni, in LIVE_JSON:
#   M4-E01  DENTRO lo spazio di lavoro, in prova_dal_vivo/, fuori da git
#           status (live::cartella_json): la registrazione del corso li
#           legge lì, e le tre sessioni registrate non li hanno mai
#           toccati;
#   M4-E02  FUORI dallo spazio di lavoro, in PN_LIVE_JSON oppure accanto,
#           in <spazio di lavoro>.prova_dal_vivo/ (live::cartella_fuori),
#           come in lib_live_m4_e04_e05.sh: la seconda parte è una
#           sessione nuova, che riparte dalla nota e non deve poter
#           leggere le risposte della prima.
# =====================================================================

LIVE_JSON=prova_dal_vivo
readonly LIVE_PROGETTO=progetti/gestionale-php
# Il riepilogo di un turno, dal JSON di claude -p (filtro di jq).
# shellcheck disable=SC2016  # \(…) è di jq, non un'espansione della shell
LIVE_RIEPILOGO='"  turno \($n): \(.num_turns // "?") turni del modello, '
LIVE_RIEPILOGO+='\(((.duration_ms // 0) / 1000) | floor) s, token in '
LIVE_RIEPILOGO+='entrata \((.usage.input_tokens // 0)'
LIVE_RIEPILOGO+=' + (.usage.cache_creation_input_tokens // 0)'
LIVE_RIEPILOGO+=' + (.usage.cache_read_input_tokens // 0)), in uscita '
LIVE_RIEPILOGO+='\(.usage.output_tokens // 0)"'
readonly LIVE_RIEPILOGO
LIVE_SESSIONE=''

# Il prompt N del README, fra le righe «<!-- prompt N -->» e
# «<!-- /prompt N -->», senza il rientro comune.
# Globals: LIVE_README. Arguments: $1 il numero.
# Outputs: il prompt su STDOUT. Returns: 2 se il README non lo ha.
live::prompt() {
  python3 -B -I - "${LIVE_README}" "$1" <<'PY'
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

# Una chiamata senza risposta: il verdetto KO e la fine con uscita 1.
# Arguments: il testo del verdetto.
live::fallita() {
  handson::verdict ko "$*"
  handson::finish
}

# Lo spazio di lavoro al punto di partenza: git status vuoto e nessun
# commit dopo il primo. Su uno spazio di lavoro già usato la prova
# ripartirebbe dal lavoro di prima, e la verifica potrebbe passare su
# quello. Arguments: $1 l'identificativo dell'elemento, per il reset.
# Returns: 0; esce 2 se lo spazio di lavoro ha già del lavoro.
live::al_punto_di_partenza() {
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

# Un turno: claude -p con il JSON in LIVE_JSON/turno-<n>.json, nella
# modalità di permesso di HANDSON_PERMISSION_MODE; poi il riepilogo e
# l'ID di sessione in LIVE_SESSIONE. Va chiamata nella shell dello script,
# non dentro $(…): così una precondizione di handson::claude_p esce davvero
# con 2, e una risposta che manca chiude con 1.
# Globals: LIVE_MODELLO, LIVE_STRUMENTI, LIVE_JSON (lette); LIVE_SESSIONE
# (assegnata).
# Arguments: $1 il numero del turno, $2 il testo, poi le opzioni in più
# (per esempio --resume <ID>).
live::turno() {
  local n="$1" testo="$2" file
  shift 2
  file="${LIVE_JSON}/turno-${n}.json"
  handson::claude_p "${LIVE_MODELLO}" "${LIVE_STRUMENTI}" "${testo}" \
    --effort medium --strict-mcp-config "$@" > "${file}" \
    || live::fallita "il turno ${n} non ha dato una risposta"
  jq -r --arg n "${n}" "${LIVE_RIEPILOGO}" "${file}" \
    || printf '  turno %s: il JSON non si legge\n' "${n}"
  # shellcheck disable=SC2034  # la leggono i live.sh, per il turno dopo
  LIVE_SESSIONE="$(jq -er \
    '.session_id | select(type == "string" and length > 0)' "${file}")" \
    || live::fallita "il turno ${n} non ha un ID di sessione"
}

# Le dipendenze del gestionale, se mancano, come le installa il
# partecipante dalla radice dello spazio di lavoro.
# Arguments: $1 lo strumento per PHP.
live::dipendenze() {
  if [[ -f "${LIVE_PROGETTO}/vendor/bin/phpunit" ]]; then
    handson::note "le dipendenze del gestionale ci sono già"
    return 0
  fi
  handson::run "$1" composer install -d "${LIVE_PROGETTO}" \
    --no-interaction --no-progress \
    || handson::die "composer install non riesce"
}

# La cartella dei JSON di M4-E01, prova_dal_vivo/ DENTRO lo spazio di
# lavoro, e la sua riga in .git/info/exclude, una volta sola: così resta
# fuori da git status e dalla verifica. Dentro, perché la registrazione
# del corso la legge lì (l'intestazione della libreria).
live::cartella_json() {
  mkdir -p "${LIVE_JSON}" .git/info
  if ! grep -qxF "${LIVE_JSON}/" .git/info/exclude 2> /dev/null; then
    printf '%s/\n' "${LIVE_JSON}" >> .git/info/exclude
  fi
}

# La cartella dei JSON di M4-E02, FUORI dallo spazio di lavoro:
# PN_LIVE_JSON oppure <spazio di lavoro>.prova_dal_vivo, come
# lab::cartella_json di lib_live_m4_e04_e05.sh. Esce 2 se starebbe dentro.
# Globals: LIVE_JSON (assegnata). Arguments: $1 lo spazio di lavoro.
live::cartella_fuori() {
  local ws reale
  ws="$(cd "$1" && pwd -P)" || handson::die "spazio di lavoro illeggibile"
  LIVE_JSON="${PN_LIVE_JSON:-${ws}.prova_dal_vivo}"
  mkdir -p -- "${LIVE_JSON}" \
    || handson::die "non riesco a creare ${LIVE_JSON}"
  reale="$(cd "${LIVE_JSON}" && pwd -P)" \
    || handson::die "non riesco a leggere ${LIVE_JSON}"
  if [[ "${reale}/" == "${ws}/"* ]]; then
    handson::die "i JSON delle prove non stanno nello spazio di lavoro:" \
      "${reale}"
  fi
  LIVE_JSON="${reale}"
  handson::note "i JSON dei turni in ${LIVE_JSON}"
}

# Lo strumento per PHP: PN_PHP_SH o la copia dello spazio di lavoro, che
# deve esserci. Arguments: $1 lo spazio di lavoro.
# Outputs: il percorso su STDOUT. Returns: esce 2 se manca.
live::php() {
  local php="${PN_PHP_SH:-$1/tools/php.sh}"
  [[ -x "${php}" ]] \
    || handson::die "manca tools/php.sh nello spazio di lavoro: ${php}"
  printf '%s\n' "${php}"
}

# La verifica dell'elemento: la sua uscita stampata, il verdetto e la fine
# (0, 1 o 2 come handson::finish). Globals: LIVE_CONTROLLO.
# Arguments: $1 lo spazio di lavoro.
live::verifica() {
  local out rc=0
  handson::step "La verifica"
  out="$("${LIVE_CONTROLLO}" "$1" 2>&1)" || rc=$?
  printf '%s\n' "${out}"
  handson::verdict_rc "${rc}" "verifica.sh dell'elemento"
  handson::finish
}
