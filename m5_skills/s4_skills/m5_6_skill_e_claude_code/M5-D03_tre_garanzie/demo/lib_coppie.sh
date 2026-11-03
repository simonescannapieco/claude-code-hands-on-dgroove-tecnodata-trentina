# shellcheck shell=bash
# =====================================================================
# lib_coppie.sh -- di in_classe.sh di M5-D03: le cartelle temporanee, le copie
# dei bracci e le chiamate claude -p
# ---------------------------------------------------------------------
# Libreria: si fa SOURCE, non si esegue. Non usa tools/lib_handson.sh perché lo
# spazio di lavoro sta fuori dal repository: fa le stesse cose per ciò che
# serve qui (il comando si vede prima di girare; ANTHROPIC_API_KEY esce
# dall'ambiente di claude; dontAsk, --permission-prompts none, --setting-sources
# project,local).
#
# Ogni braccio gira in una copia nuova, in una cartella temporanea, con la sua
# skill e i suoi file, in un repository git con un commit: una sessione non
# vede né l'altro braccio né la sua risposta. Gli stream restano in un'altra
# cartella temporanea finché l'ultima chiamata non è finita, e solo allora
# vanno in risposte/.
#
# Globals (lette): SPAZIO, di in_classe.sh; TMPDIR, HOME, HANDSON_NO_PAUSE.
#   (assegnate) DEPOSITO, COPIE, COPIA, PAROLA.
# =====================================================================

readonly COPPIE_MODELLO=sonnet
readonly COPPIE_SICURO='^[A-Za-z0-9._/:=@%+,-]+$'
readonly COPPIE_LARGHEZZA=76
DEPOSITO=''
COPIE=''
COPIA=''

# Una diagnostica su STDERR. Arguments: il messaggio.
coppie::err() { echo "in_classe.sh: $*" >&2; }

# Diagnostica e uscita 2: una precondizione. Arguments: il messaggio.
coppie::die() { coppie::err "$*"; exit 2; }

# Un token incollabile in una shell: nudo se fatto di caratteri innocui,
# altrimenti fra apici singoli. Arguments: $1 il token.
# Outputs: il token su STDOUT.
coppie::quota() {
  local sq="'" esc="'\\''"
  if [[ "$1" =~ ${COPPIE_SICURO} ]]; then
    printf '%s' "$1"
  else
    printf "'%s'" "${1//${sq}/${esc}}"
  fi
}

# Il comando in forma incollabile, su STDERR, nella larghezza dello schermo: a
# capo fra un gruppo di opzioni e l'altro, mai fra un'opzione e il suo valore,
# così undici chiamate stanno sullo schermo dell'aula.
# Arguments: il comando, token per token.
coppie::mostra() {
  local tok q gruppo='' riga='  $'
  local -a gruppi=()
  for tok in "$@"; do
    q="$(coppie::quota "${tok}")"
    if [[ "${tok}" == --* && -n "${gruppo}" ]]; then
      gruppi+=("${gruppo}")
      gruppo="${q}"
    else
      gruppo+="${gruppo:+ }${q}"
    fi
  done
  gruppi+=("${gruppo}")
  for gruppo in "${gruppi[@]}"; do
    if (( ${#riga} + ${#gruppo} + 1 > COPPIE_LARGHEZZA )); then
      printf '%s \\\n' "${riga}" >&2
      riga='     '
    fi
    riga+=" ${gruppo}"
  done
  printf '%s\n\n' "${riga}" >&2
}

# Il titolo di una coppia; su un terminale aspetta Invio, salvo
# HANDSON_NO_PAUSE=1. Arguments: il titolo.
coppie::titolo() {
  printf '\n--- %s\n' "$*"
  if [[ "${HANDSON_NO_PAUSE:-0}" != 1 && -t 0 ]]; then
    printf '[Invio per continuare] ' >&2
    read -r _ || printf '\n' >&2
  fi
}

# La cartella in cui nascono i temporanei: ${TMPDIR:-/tmp}, salvo che stia
# dentro ~/.claude, dove anche un comando consentito può essere negato.
# Outputs: la cartella su STDOUT.
coppie::base_temporanei() {
  local base="${TMPDIR:-/tmp}" reale config
  reale="$(readlink -f "${base}")" || reale="${base}"
  config="$(readlink -f "${HOME:-/}/.claude")" || config=''
  if [[ -n "${config}" && "${reale}/" == "${config}/"* ]]; then
    base=/tmp
  fi
  printf '%s\n' "${base}"
}

# Toglie le cartelle temporanee (agganciata a EXIT); mai un percorso vuoto, /
# o un collegamento simbolico. Globals: DEPOSITO, COPIE.
coppie::pulisci() {
  local d
  for d in "${DEPOSITO}" "${COPIE}"; do
    if [[ -n "${d}" && "${d}" != "/" && -d "${d}" && ! -L "${d}" ]]; then
      rm -rf -- "${d}"
    fi
  done
}

# Le due cartelle temporanee, separate: ciò che una sessione può raggiungere
# dalla sua copia non porta alle risposte. Globals: DEPOSITO, COPIE (assegnate).
coppie::apri_temporanei() {
  local base
  base="$(coppie::base_temporanei)"
  trap coppie::pulisci EXIT
  DEPOSITO="$(mktemp -d "${base}/m5-d03-risposte.XXXXXX")" \
    || coppie::die "non riesco a creare una cartella temporanea in ${base}"
  COPIE="$(mktemp -d "${base}/m5-d03-copie.XXXXXX")" \
    || coppie::die "non riesco a creare una cartella temporanea in ${base}"
}

# Il codice e la parola di questo spazio di lavoro, casuali, nel deposito.
# Nessun codice sta nel repository. Globals: DEPOSITO; PAROLA (assegnata).
coppie::segreti() {
  local codice
  codice="$(python3 -B -I -c 'import secrets; print(secrets.token_hex(8))')" \
    || coppie::die "python3 non riesce a generare il codice"
  PAROLA="$(python3 -B -I -c 'import secrets; print(secrets.token_hex(3))')" \
    || coppie::die "python3 non riesce a generare la parola"
  PAROLA="ciaspola-${PAROLA}"
  printf '%s\n' "${codice}" > "${DEPOSITO}/codice.txt"
  printf '%s\n' "${PAROLA}" > "${DEPOSITO}/parola.txt"
}

# Una copia nuova di un braccio: la sua skill, le impostazioni prudenti dello
# spazio di lavoro, i file dati, un repository git con un commit.
# Globals: SPAZIO, COPIE; COPIA (assegnata). Arguments: $1 il braccio, poi i
# file da copiarvi.
coppie::nuova_copia() {
  local braccio="$1" f
  shift
  COPIA="$(mktemp -d "${COPIE}/${braccio}.XXXXXX")" \
    || coppie::die "non riesco a creare la copia di ${braccio}"
  if ! cp -R "${SPAZIO}/coppie/${braccio}/." "${COPIA}/" \
      || ! cp -- "${SPAZIO}/.claude/settings.json" "${COPIA}/.claude/"; then
    coppie::die "non riesco a riempire la copia di ${braccio}"
  fi
  for f in "$@"; do
    cp -- "${f}" "${COPIA}/" || coppie::die "non riesco a copiare ${f}"
  done
  if ! git -c init.defaultBranch=main -C "${COPIA}" init -q \
      || ! git -C "${COPIA}" add -A \
      || ! git -C "${COPIA}" -c user.name='Corso Claude Code' \
        -c user.email=corso@example.org -c commit.gpgsign=false \
        commit -q --no-verify -m "Punto di partenza di ${braccio}"; then
    coppie::die "git non riesce a fare il repository di ${braccio}"
  fi
}

# Una chiamata: claude -p dalla copia, con lo stream nel deposito. Sonnet con
# effort low, dontAsk, --permission-prompts none (ciò che chiederebbe un
# permesso è negato), stream-json, le sole impostazioni di progetto, nessun
# server MCP. Senza ANTHROPIC_API_KEY, che in -p prenderebbe il posto
# dell'abbonamento, e senza CLAUDE_CODE_EFFORT_LEVEL, che ha la precedenza su
# --effort. Il comando si vede prima di girare.
# Globals: DEPOSITO. Arguments: $1 la copia, $2 il nome dello stream, $3 gli
# strumenti consentiti ("" = nessuno), $4 il prompt, poi le altre opzioni.
# Returns: l'uscita di claude.
coppie::chiedi() {
  local copia="$1" nome="$2" strumenti="$3" prompt="$4"
  shift 4
  local -a argv=(claude -p)
  if [[ -n "${strumenti}" ]]; then
    argv+=(--allowedTools "${strumenti}")
  fi
  argv+=(--model "${COPPIE_MODELLO}" --effort low --permission-mode dontAsk
    --permission-prompts none --output-format stream-json --verbose
    --setting-sources 'project,local' --strict-mcp-config)
  if (( $# > 0 )); then
    argv+=("$@")
  fi
  argv+=(-- "${prompt}")
  printf '  # %s\n' "${nome}" >&2
  coppie::mostra "${argv[@]}"
  ( cd -- "${copia}" \
      && exec env -u ANTHROPIC_API_KEY -u CLAUDE_CODE_EFFORT_LEVEL "${argv[@]}"
  ) < /dev/null > "${DEPOSITO}/${nome}.jsonl"
}

# Gli stream e i segreti in risposte/ dello spazio di lavoro.
# Globals: SPAZIO, DEPOSITO.
coppie::consegna() {
  if ! mkdir -p -- "${SPAZIO}/risposte" \
      || ! cp -- "${DEPOSITO}"/* "${SPAZIO}/risposte/"; then
    coppie::die "non riesco a scrivere in ${SPAZIO}/risposte/"
  fi
}

# Una chiamata fallita: ciò che c'è va in risposte/, e la demo si ferma con 1.
# Arguments: il messaggio.
coppie::fallita() {
  coppie::consegna
  coppie::err "$*: claude -p è fallito"
  exit 1
}
