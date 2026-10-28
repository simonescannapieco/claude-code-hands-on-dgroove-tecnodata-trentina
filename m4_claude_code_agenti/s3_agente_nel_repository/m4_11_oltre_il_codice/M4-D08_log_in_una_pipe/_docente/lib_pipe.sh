# shellcheck shell=bash
# =====================================================================
# lib_pipe.sh -- di _docente/live.sh di M4-D08: claude -p con un file in
# pipe, mostrato prima di girare e registrato in pipe/
# ---------------------------------------------------------------------
# Libreria: si fa SOURCE dopo tools/lib_handson.sh; non si esegue.
#
# handson::claude_p non mette niente in pipe e non separa lo STDERR di
# claude dal comando che mostra: pipe::braccio compone la stessa riga, dopo
# gli stessi controlli della libreria (pipe::controlli), la mostra com'è,
# con la pipe davanti (pipe::mostra), e la esegue senza ANTHROPIC_API_KEY
# (pipe::esegui). Lo stesso comando per i due bracci: Sonnet, effort low,
# nessuno strumento (--tools ""), nessun server MCP (--strict-mcp-config
# senza --mcp-config), nessuna sessione salvata, --output-format json, più
# --permission-mode, --permission-prompts none e --setting-sources come li
# mette handson::claude_p. Di ogni braccio restano in pipe/ lo STDOUT
# (<braccio>.out), lo STDERR (<braccio>.err), il codice d'uscita di claude
# (<braccio>.uscita) e i byte passati (<braccio>.byte).
#
# Globals (lette): HANDSON_SHOW_CMD, HANDSON_PERMISSION_MODE,
#   HANDSON_SETTING_SOURCES, di tools/lib_handson.sh.
# =====================================================================

readonly PIPE_MODELLO=sonnet
readonly PIPE_OPZIONI=(--tools "" --effort low --strict-mcp-config
  --no-session-persistence)

# I controlli della libreria sulla riga di claude: modello, prompt,
# modalità di permesso, argomenti vietati, chiavi API. Fuori da $(…): una
# precondizione esce davvero con 2. Arguments: $1 il prompt.
pipe::controlli() {
  local arg
  handson::_claude_p_checks "${PIPE_MODELLO}" "$1"
  handson::_claude_key_ok "$1"
  for arg in "${PIPE_MODELLO}" "${PIPE_OPZIONI[@]}"; do
    handson::_claude_arg_ok "${arg}"
  done
}

# Mostra un comando già scritto, come lo scrive il README (con il glob o
# la redirezione), prima di eseguirlo, e si ferma su un terminale;
# HANDSON_SHOW_CMD=0 lo zittisce. Arguments: $1 il testo.
pipe::mostra_riga() {
  if [[ "${HANDSON_SHOW_CMD}" == "0" ]]; then
    return 0
  fi
  printf '  $ %s\n\n' "$1" >&2
  handson::pause "eseguirlo"
}

# Mostra la pipe «cat <file> | claude -p …» come si incolla, andando a capo
# prima di ogni opzione lunga come handson::show_cmd, e si ferma su un
# terminale. Arguments: $1 il file, poi il comando claude, token per token.
pipe::mostra() {
  if [[ "${HANDSON_SHOW_CMD}" == "0" ]]; then
    return 0
  fi
  local q tok
  handson::quote_into q "$1"
  shift
  printf '  $ cat %s |' "${q}" >&2
  for tok in "$@"; do
    handson::quote_into q "${tok}"
    if [[ "${tok}" == --* ]]; then
      printf ' \\\n      %s' "${q}" >&2
    else
      printf ' %s' "${q}" >&2
    fi
  done
  printf '\n\n' >&2
  handson::pause "eseguirlo"
}

# La pipe di un braccio, da eseguire in un sottoprocesso: senza
# ANTHROPIC_API_KEY, lo STDOUT e lo STDERR di claude nei file, poi il suo
# codice d'uscita (non quello di cat, che riceve SIGPIPE se claude smette
# di leggere). Arguments: $1 il file in ingresso, $2 la base dei file
# (pipe/<braccio>), poi il comando claude.
pipe::esegui() {
  local ingresso="$1" base="$2"
  local -a st=()
  shift 2
  unset ANTHROPIC_API_KEY
  if cat -- "${ingresso}" | "$@" > "${base}.out" 2> "${base}.err"; then
    st=("${PIPESTATUS[@]}")
  else
    st=("${PIPESTATUS[@]}")
  fi
  printf '%s\n' "${st[1]}" > "${base}.uscita"
}

# Un braccio: i byte dell'ingresso in pipe/<braccio>.byte, la pipe a schermo,
# poi la pipe; un'uscita diversa da zero non ferma la demo, la decide il
# controllo. Arguments: $1 il braccio, $2 il file in ingresso, $3 il prompt.
pipe::braccio() {
  local nome="$1" ingresso="$2" byte
  local -a argv=(claude -p --model "${PIPE_MODELLO}"
    --permission-mode "${HANDSON_PERMISSION_MODE}" --permission-prompts none
    --output-format json --setting-sources "${HANDSON_SETTING_SOURCES}"
    "${PIPE_OPZIONI[@]}" -- "$3")
  byte="$(wc -c < "${ingresso}")"
  printf '%s\n' "${byte//[[:space:]]/}" > "pipe/${nome}.byte"
  pipe::mostra "${ingresso}" "${argv[@]}"
  if [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
    handson::note "ANTHROPIC_API_KEY è impostata: la tolgo per questo" \
      "comando, così Claude Code usa l'abbonamento"
  fi
  ( pipe::esegui "${ingresso}" "pipe/${nome}" "${argv[@]}" )
  handson::note "claude è uscito con $(< "pipe/${nome}.uscita")"
}
