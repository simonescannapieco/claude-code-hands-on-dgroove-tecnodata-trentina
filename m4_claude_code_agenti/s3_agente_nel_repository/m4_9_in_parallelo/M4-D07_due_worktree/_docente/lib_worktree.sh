# shellcheck shell=bash
# =====================================================================
# lib_worktree.sh -- di _docente/live.sh di M4-D07: le precondizioni sul
# repository, le due sessioni di un braccio partite insieme, la pulizia
# dei worktree e la verifica a schermo
# ---------------------------------------------------------------------
# Libreria: si fa SOURCE dopo tools/lib_handson.sh; non si esegue.
#
# worktree::controlla_repository vuole lo spazio di lavoro alla cima di un
# repository git con un commit, senza modifiche, senza esecuzioni/ né i
# worktree e i rami della demo. handson::claude_p scrive sempre
# --output-format json, e qui serve lo stream-json (lì c'è la cartella da
# cui parte ogni sessione): worktree::componi compone la stessa riga con
# --output-format stream-json --verbose, dopo gli stessi controlli della
# libreria, e worktree::lancia_insieme fa partire insieme le due sessioni
# di un braccio, senza ANTHROPIC_API_KEY nell'ambiente, dopo che le loro
# righe si sono viste; un Ctrl-C o un TERM fermano anche le due sessioni
# (worktree::ferma). claude -p non toglie i suoi worktree:
# worktree::pulisci li toglie, con i loro rami. worktree::fallita chiude
# con un KO; worktree::verifica_a_schermo fa vedere i dati e i verdetti
# anche quando la verifica passa.
#
# Globals (lette): MODELLO, STRUMENTI, OPZIONI, NOMI, DOMANDE, PULIRE,
#   CONTROLLO, di live.sh; HANDSON_ENV, HANDSON_PERMISSION_MODE,
#   HANDSON_SETTING_SOURCES, HANDSON_SHOW_CMD, di tools/lib_handson.sh;
#   (assegnata) RIGA, di live.sh.
# =====================================================================

#######################################
# Compone in RIGA la riga di una sessione: quella di handson::claude_p con
# --output-format stream-json --verbose, dopo gli stessi controlli.
# Globals: RIGA (assegnata); HANDSON_PERMISSION_MODE,
#   HANDSON_SETTING_SOURCES (lette).
# Arguments: $1 il prompt, poi le opzioni in più (-w <nome>).
#######################################
worktree::componi() {
  local domanda="$1" arg
  shift
  handson::_claude_p_checks "${MODELLO}" "${domanda}"
  handson::_claude_key_ok "${domanda}"
  for arg in "${MODELLO}" "${STRUMENTI}" "${OPZIONI[@]}" "$@"; do
    handson::_claude_arg_ok "${arg}"
  done
  RIGA=(claude -p "$@" --allowedTools "${STRUMENTI}" --model "${MODELLO}"
    --permission-mode "${HANDSON_PERMISSION_MODE}" --permission-prompts none
    --output-format stream-json --verbose
    --setting-sources "${HANDSON_SETTING_SOURCES}" "${OPZIONI[@]}"
    -- "${domanda}")
}

#######################################
# Esegue RIGA con il suo stream in un file, senza ANTHROPIC_API_KEY (fuori
# dagli elementi trainer-api). Va lanciata in un sottoprocesso (… &): exec
# vi mette claude al posto della shell, così il pid del sottoprocesso è
# quello di claude, e un'interruzione lo ferma davvero.
# Globals: RIGA, HANDSON_ENV (lette). Arguments: $1 il file dello stream.
#######################################
worktree::avvia() {
  if [[ "${HANDSON_ENV}" != "trainer-api" ]]; then
    unset ANTHROPIC_API_KEY
  fi
  exec "${RIGA[@]}" < /dev/null > "$1"
}

#######################################
# Ferma le sessioni di un braccio ancora in corso, poi esce con il codice
# dato: un Ctrl-C o un TERM non lasciano due claude -p a modificare file e
# a creare worktree. La chiamano le trap di worktree::lancia_insieme.
# Arguments: $1 il codice d'uscita (130 per INT, 143 per TERM), poi i pid
#   delle sessioni.
#######################################
# shellcheck disable=SC2317  # la chiamano le trap, indirettamente
worktree::ferma() {
  local uscita="$1"
  shift
  handson::err "interrotto: fermo le sessioni ancora in corso"
  if (( $# > 0 )); then
    # Una sessione già finita non c'è più: kill lo dice, e non è un errore.
    kill -TERM "$@" 2> /dev/null || :
    wait "$@" 2> /dev/null || :
  fi
  exit "${uscita}"
}

#######################################
# Le due sessioni di un braccio, partite insieme: prima si vedono le due
# righe, poi una pausa (su un terminale), poi partono e si aspettano. Le
# trap di INT e TERM, finché si aspetta, fermano anche le due sessioni: i
# figli asincroni di uno script partono con SIGINT ignorato, e un Ctrl-C
# altrimenti fermerebbe soltanto live.sh.
# Arguments: $1 il braccio, senza-worktree o con-worktree.
# Returns: 0 se tutte e due escono con 0; 1 altrimenti.
#######################################
worktree::lancia_insieme() {
  local braccio="$1" i rc falliti=0
  local -a pids=() extra=()
  handson::need_tools claude
  for i in 0 1; do
    extra=()
    [[ "${braccio}" != con-worktree ]] || extra=(-w "${NOMI[i]}")
    worktree::componi "${DOMANDE[i]}" ${extra[@]+"${extra[@]}"}
    if [[ "${HANDSON_SHOW_CMD}" != "0" ]]; then
      handson::show_cmd "${RIGA[@]}" >&2
      handson::note "  lo stream in esecuzioni/${braccio}/${NOMI[i]}.jsonl"
    fi
  done
  if [[ "${HANDSON_ENV}" != "trainer-api" && -n "${ANTHROPIC_API_KEY:-}" ]]
  then
    handson::note "ANTHROPIC_API_KEY è impostata: la tolgo per queste" \
      "sessioni, così Claude Code usa l'abbonamento"
  fi
  handson::pause "eseguirle insieme"
  trap 'worktree::ferma 130 ${pids[@]+"${pids[@]}"}' INT
  trap 'worktree::ferma 143 ${pids[@]+"${pids[@]}"}' TERM
  for i in 0 1; do
    extra=()
    [[ "${braccio}" != con-worktree ]] || extra=(-w "${NOMI[i]}")
    worktree::componi "${DOMANDE[i]}" ${extra[@]+"${extra[@]}"}
    worktree::avvia "esecuzioni/${braccio}/${NOMI[i]}.jsonl" &
    pids+=("$!")
  done
  for i in 0 1; do
    rc=0
    wait "${pids[i]}" || rc=$?
    if (( rc != 0 )); then
      handson::err "${braccio}/${NOMI[i]}: claude -p è uscito con ${rc}"
      falliti=$((falliti + 1))
    fi
  done
  trap - INT TERM
  (( falliti == 0 ))
}

#######################################
# La pulizia dei worktree che claude -p lascia: per ognuno il ramo su cui
# sta, poi git worktree remove --force --force (un worktree bloccato, se
# lo è, lo chiede due volte), poi il ramo. Mai il ramo main.
# Globals: HANDSON_KO (via handson::verdict).
#######################################
worktree::pulisci() {
  local n wt ramo resto
  handson::step "La pulizia: claude -p non toglie i suoi worktree"
  for n in "${NOMI[@]}"; do
    wt=".claude/worktrees/${n}"
    ramo="worktree-${n}"
    if [[ -d "${wt}" ]]; then
      if resto="$(git -C "${wt}" rev-parse --abbrev-ref HEAD 2> /dev/null)"
      then
        ramo="${resto}"
      fi
      handson::run git worktree remove --force --force "${wt}" \
        || handson::verdict ko "il worktree ${wt} non si toglie"
    fi
    if [[ "${ramo}" != main && "${ramo}" != HEAD ]] \
        && git show-ref --verify --quiet "refs/heads/${ramo}"; then
      handson::run git branch -D "${ramo}" \
        || handson::verdict ko "il ramo ${ramo} non si cancella"
    fi
  done
  resto="$(git worktree list --porcelain | grep -c '^worktree ')" \
    || resto='?'
  handson::note "worktree rimasti: ${resto} (il checkout principale)"
}

#######################################
# Le precondizioni sul repository: lo spazio di lavoro è la cima di un
# repository git con un commit, senza modifiche ai file tracciati, senza
# esecuzioni/ né i worktree e i rami della demo. Esce 2 altrimenti.
# Arguments: $1 lo spazio di lavoro (assoluto, la cartella corrente).
#######################################
worktree::controlla_repository() {
  local cima n
  cima="$(git rev-parse --show-toplevel 2> /dev/null)" || cima=''
  if [[ "${cima}" != "$1" ]] || ! git rev-parse --verify -q HEAD \
      > /dev/null; then
    handson::die "lo spazio di lavoro non è un repository git con un" \
      "commit (serve a -w): tools/reset_esercizio.sh M4-D07"
  fi
  git diff --quiet HEAD \
    || handson::die "il checkout principale ha modifiche ai file" \
      "tracciati: tools/reset_esercizio.sh M4-D07"
  [[ ! -e esecuzioni ]] \
    || handson::die "ci sono già delle esecuzioni in $1/esecuzioni/;" \
      "per ripartire da capo: tools/reset_esercizio.sh M4-D07"
  for n in "${NOMI[@]}"; do
    [[ ! -e ".claude/worktrees/${n}" ]] \
      || handson::die "c'è già il worktree .claude/worktrees/${n}: la" \
        "pulizia è in «Se qualcosa va storto» del README"
    ! git show-ref --verify --quiet "refs/heads/worktree-${n}" \
      || handson::die "c'è già il ramo worktree-${n}: la pulizia è in «Se" \
        "qualcosa va storto» del README"
  done
}

# Una sessione o una fotografia fallita: il verdetto KO, la pulizia se i
# worktree ci possono essere, e la fine con uscita 1.
worktree::fallita() {
  handson::verdict ko "$*"
  if (( PULIRE == 1 )); then
    worktree::pulisci
  fi
  handson::finish
}

# verifica.sh con il suo STDOUT sul descrittore 3, che main apre sullo
# STDOUT di live.sh: handson::check mostra l'uscita di un controllo solo
# su un KO, e qui i dati e i verdetti sono la demo anche quando passa.
# Arguments: $1 lo spazio di lavoro. Returns: l'uscita di verifica.sh.
# shellcheck disable=SC2317  # la chiama handson::check, indirettamente
worktree::verifica_a_schermo() {
  "${CONTROLLO}" "$1" >&3
}
