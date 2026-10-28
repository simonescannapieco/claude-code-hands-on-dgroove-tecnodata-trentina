# shellcheck shell=bash
# =====================================================================
# lib_gradini.sh -- di _docente/live.sh di M4-D04: i bracci delle tre
# coppie, le loro copie del gestionale, le chiamate claude -p in
# stream-json e il piano del plan mode
# ---------------------------------------------------------------------
# Libreria: si fa SOURCE dopo tools/lib_handson.sh; non si esegue.
#
# gradini::braccio dice che cosa distingue un braccio: la modalità, gli
# strumenti consentiti, le impostazioni, gli strumenti disponibili.
# gradini::prepara_copia gli prepara una copia nuova del gestionale, con
# le sue impostazioni, in un repository git con un commit.
# handson::claude_p lascia scegliere la modalità, ma scrive sempre
# --output-format json e rifiuta un altro --output-format, mentre qui
# serve lo stream-json, dove si vedono le chiamate e i dinieghi:
# gradini::chiedi compone la stessa riga con la modalità del braccio, dopo
# gli stessi controlli della libreria (modello, prompt, modalità di
# permesso, argomenti vietati, chiavi API), e la esegue senza
# ANTHROPIC_API_KEY; la riga si vede prima di girare (handson::run). Le
# stesse opzioni per ogni chiamata: Sonnet, effort low,
# --strict-mcp-config, nessuna sessione salvata.
# In plan mode Claude Code scrive il piano in ~/.claude/plans/:
# gradini::ricorda_piani annota che cosa c'era prima, e
# gradini::togli_piani toglie il piano che l'esecuzione ha scritto, e
# nessun altro.
#
# Globals (lette): CONTROLLO, di live.sh; HOME; HANDSON_SETTING_SOURCES,
#   HANDSON_GIT_NAME, HANDSON_GIT_EMAIL, di tools/lib_handson.sh;
#   (assegnata) GRADINI_PIANI_PRIMA.
# =====================================================================

readonly GRADINI_MODELLO=sonnet
readonly GRADINI_OPZIONI=(--effort low --strict-mcp-config
  --no-session-persistence)
readonly GRADINI_GESTIONALE=progetti/gestionale-php
readonly GRADINI_SCARTO=da_cancellare.txt
GRADINI_PIANI_PRIMA=''

# La modalità, gli strumenti consentiti, le impostazioni di un braccio e
# gli strumenti disponibili (--tools: «-» per tutti).
# Arguments: $1 la coppia, $2 il braccio.
# Outputs: «modo consentiti file disponibili», separati da tabulazioni.
gradini::braccio() {
  local modo=acceptEdits consentiti='Read,Edit' file=.claude/settings.json
  local soli=-
  if [[ "$1" == piano && "$2" == con ]]; then
    modo=plan
  fi
  if [[ "$1" == hook ]]; then
    consentiti='Bash(rm *)'
  fi
  if [[ "$1" == deny ]]; then
    soli='Read,Edit'
  fi
  if [[ "$2" == con && "$1" != piano ]]; then
    file="impostazioni/$1.json"
  fi
  printf '%s\t%s\t%s\t%s\n' "${modo}" "${consentiti}" "${file}" "${soli}"
}

# Una copia nuova del gestionale per un braccio: il gestionale, le
# impostazioni del braccio e, per l'hook, lo script e il file da
# cancellare; un repository git con un commit. Va chiamata nello spazio
# di lavoro.
# Globals: HANDSON_GIT_NAME, HANDSON_GIT_EMAIL (lette).
# Arguments: $1 la cartella, $2 il file delle impostazioni, $3 la coppia.
# Returns: 0; 1 se un passo non riesce.
gradini::prepara_copia() {
  mkdir -p "$1/progetti" "$1/.claude" || return 1
  cp -R -- "${GRADINI_GESTIONALE}" "$1/progetti/" || return 1
  cp -- "$2" "$1/.claude/settings.json" || return 1
  if [[ "$3" == hook ]]; then
    mkdir -p "$1/.claude/hooks" || return 1
    cp -- impostazioni/blocca_rm.py "$1/.claude/hooks/" || return 1
    printf '%s %s\n' "File di prova della demo M4-D04: la richiesta chiede" \
      "di cancellarlo." > "$1/${GRADINI_SCARTO}" || return 1
  fi
  git -c init.defaultBranch=main -C "$1" init -q || return 1
  git -C "$1" add -A || return 1
  git -C "$1" -c user.name="${HANDSON_GIT_NAME}" \
    -c user.email="${HANDSON_GIT_EMAIL}" -c commit.gpgsign=false \
    commit -q --no-verify -m "Copia del gestionale per ${1##*/}" || return 1
}

# Una chiamata, con il suo stream-json in un file: la riga di
# handson::claude_p con --output-format stream-json --verbose e la
# modalità del braccio. I controlli stanno fuori dal sottoprocesso e fuori
# da $(…): una precondizione esce davvero con 2. L'elemento è
# claude-code-pro: ANTHROPIC_API_KEY esce sempre dall'ambiente di claude.
# Globals: HANDSON_SETTING_SOURCES (letta).
# Arguments: $1 la cartella da cui parte, $2 la modalità, $3 gli strumenti
#   consentiti, $4 il file della richiesta, $5 il file dello stream, $6
#   gli strumenti disponibili (--tools), «-» per tutti.
# Returns: l'uscita di claude.
gradini::chiedi() {
  local cartella="$1" HANDSON_PERMISSION_MODE="$2" consentiti="$3"
  local domanda arg
  local -a opzioni=("${GRADINI_OPZIONI[@]}")
  if [[ "$6" != - ]]; then
    opzioni=(--tools "$6" "${GRADINI_OPZIONI[@]}")
  fi
  domanda="$(< "$4")"
  handson::need_tools claude
  handson::_claude_p_checks "${GRADINI_MODELLO}" "${domanda}"
  handson::_claude_key_ok "${domanda}"
  for arg in "${GRADINI_MODELLO}" "${consentiti}" "${opzioni[@]}"; do
    handson::_claude_arg_ok "${arg}"
  done
  local -a argv=(claude -p --allowedTools "${consentiti}"
    --model "${GRADINI_MODELLO}"
    --permission-mode "${HANDSON_PERMISSION_MODE}" --permission-prompts none
    --output-format stream-json --verbose
    --setting-sources "${HANDSON_SETTING_SOURCES}" "${opzioni[@]}"
    -- "${domanda}")
  (
    if [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
      handson::note "ANTHROPIC_API_KEY è impostata: la tolgo per questo" \
        "comando, così Claude Code usa l'abbonamento"
    fi
    unset ANTHROPIC_API_KEY
    cd -- "${cartella}" && handson::run "${argv[@]}"
  ) < /dev/null > "$5"
}

# I nomi dei file di ~/.claude/plans/ prima dell'esecuzione in plan mode,
# uno per riga (nessuno se la cartella non c'è), in un file temporaneo.
# Globals: HOME (letta), GRADINI_PIANI_PRIMA (assegnata).
gradini::ricorda_piani() {
  handson::tmpfile GRADINI_PIANI_PRIMA
  if [[ -d "${HOME}/.claude/plans" ]]; then
    ls -A -- "${HOME}/.claude/plans" > "${GRADINI_PIANI_PRIMA}"
  fi
}

# Toglie il piano che l'esecuzione in plan mode ha scritto, anche se la
# chiamata è fallita a metà: soltanto un file .md direttamente in
# ~/.claude/plans/, regolare, che prima non c'era (se non si può sapere,
# resta). Ogni altro percorso resta, e lo si dice. Un controllo --piani
# che non può girare conta come una precondizione (handson::finish esce
# 2). Va chiamata nello spazio di lavoro.
# Globals: HOME, CONTROLLO, GRADINI_PIANI_PRIMA (lette).
gradini::togli_piani() {
  local elenco p nome cartella="${HOME%/}/.claude/plans" reale rc=0 gia
  reale="$(handson::canonical "${cartella}")" || reale="${cartella}"
  handson::tmpfile elenco
  python3 -B -I "${CONTROLLO}" --piani . > "${elenco}" || rc=$?
  if (( rc == 1 )); then
    handson::note "nessun piano da togliere: manca lo stream del plan mode"
    return 0
  elif (( rc != 0 )); then
    handson::verdict_rc "${rc}" "il piano del plan mode da togliere"
    return 0
  fi
  while IFS= read -r -d '' p; do
    nome="${p##*/}"
    gia=0
    grep -qxF -- "${nome}" "${GRADINI_PIANI_PRIMA}" || gia=$?
    if [[ "${nome}" != *.md || ( "${p}" != "${cartella}/${nome}" \
        && "${p}" != "${reale}/${nome}" ) ]]; then
      handson::note "lascio ${p}: non è un piano in ${cartella}/"
    elif [[ -L "${p}" || ! -f "${p}" ]]; then
      handson::note "lascio ${p}: non è un file regolare"
    elif (( gia == 0 )); then
      handson::note "lascio ${p}: c'era già prima della demo"
    elif (( gia >= 2 )); then
      handson::note "lascio ${p}: non so se c'era già prima della demo"
    else
      rm -f -- "${p}"
      handson::note "tolto il piano scritto da questa esecuzione: ${p}"
    fi
  done < "${elenco}"
}
