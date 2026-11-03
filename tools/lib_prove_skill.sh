# shellcheck shell=bash
# =====================================================================
# lib_prove_skill.sh -- il lavoro di tools/prove_skill.sh: la configurazione
# dell'elemento, la copia della skill di partenza, le esecuzioni in copie
# pulite dello spazio di lavoro.
# ---------------------------------------------------------------------
# Libreria: si fa SOURCE dopo tools/lib_handson.sh, non si esegue (nessun bit
# di esecuzione). La usa solo tools/prove_skill.sh, che documenta l'uso e le
# uscite. Le precondizioni escono 2 con handson::die, prima di ogni chiamata:
# tutte le copie si preparano prima che ne parta una, così un elemento rotto
# non consuma niente.
#
# Una copia è una cartella temporanea con i file dello spazio di lavoro così
# come sono, modifiche comprese, senza <skill>-workspace/; senza evals/, così
# Claude non legge le asserzioni; nel braccio without senza la skill. Ha un
# repository git nuovo, con un solo commit e l'identità del corso, perché né
# la storia dello spazio di lavoro (dove la skill e gli evals sono già
# committati) né una modifica della copia finiscano nella sessione o in
# file-cambiati.txt. Non ha .claude/settings.local.json: lì Claude Code salva
# le regole di «Yes, and don't ask again» e gli stati del menu /skills di una
# sessione interattiva, e due bracci devono differire in una cosa sola.
#
# Compatibile con il bash 3.2, come lib_handson.sh.
# =====================================================================

if [[ -n "${PROVE_LIB_LOADED:-}" ]]; then
  return 0
fi
readonly PROVE_LIB_LOADED=1

readonly PROVE_NOME_RE='^[a-z0-9]+(-[a-z0-9]+)*$'
readonly PROVE_MODELLO_RE='^[A-Za-z0-9._:-]+$'
readonly PROVE_EFFORT_RE='^[a-z]+$'
readonly PROVE_CASO_RE='^(eval-[0-9]+|near-miss-[1-9][0-9]*)$'
# Al massimo tre esecuzioni insieme: ogni caso è una sessione nuova, come
# chiede la guida dello standard («Each eval run should start with a clean
# context»), e una traccia ne fa undici. È una scelta del corso, per restare
# nei limiti del piano con più partecipanti.
readonly PROVE_MAX_INSIEME=3

# La configurazione dell'elemento (prove/config).
PROVE_SKILL=''
PROVE_MODELLO=sonnet
PROVE_EFFORT=low
PROVE_STRUMENTI=''
PROVE_ESEMPIO=''
# I percorsi e lo stato di un giro. Gli array vanno per indice, uno per caso.
PROVE_DIR_SKILL=''
PROVE_BASE=''
PROVE_PRIMA=''
PROVE_TMP=''
PROVE_N=''
PROVE_CONF=''
PROVE_FALLITE=0
PROVE_CASI=()
PROVE_COPIE=()
PROVE_USCITE=()
PROVE_PID=()

# Legge prove/config, «chiave=valore», senza eval: un valore resta un testo.
# Globals: PROVE_SKILL, PROVE_MODELLO, PROVE_EFFORT, PROVE_STRUMENTI,
#   PROVE_ESEMPIO (assegnate).
# Arguments: $1 il file. Returns: 0; una riga che non va esce 2.
prove::leggi_config() {
  local file="$1" riga chiave valore ha_strumenti=0
  handson::need_file "${file}"
  while IFS= read -r riga || [[ -n "${riga}" ]]; do
    riga="${riga%"${HANDSON_CR}"}"
    case "${riga}" in ''|'#'*) continue ;; esac
    [[ "${riga}" == *=* ]] \
      || handson::die "${file}: una riga senza «=»: «${riga}»"
    chiave="${riga%%=*}"
    valore="${riga#*=}"
    case "${chiave}" in
      skill) PROVE_SKILL="${valore}" ;;
      modello) PROVE_MODELLO="${valore}" ;;
      effort) PROVE_EFFORT="${valore}" ;;
      esempio) PROVE_ESEMPIO="${valore}" ;;
      strumenti) PROVE_STRUMENTI="${valore}"; ha_strumenti=1 ;;
      *) handson::die "${file}: chiave sconosciuta: «${chiave}»" ;;
    esac
  done < "${file}"
  (( ha_strumenti == 1 )) \
    || handson::die "${file}: manca «strumenti=…», gli strumenti consentiti"
  prove::_valida_config "${file}"
}

# I valori di prove/config che finiscono in un percorso o in un comando.
# Globals: PROVE_* (lette; PROVE_ESEMPIO assegnata se è vuota).
# Arguments: $1 il file, per i messaggi.
prove::_valida_config() {
  [[ "${PROVE_SKILL}" =~ ${PROVE_NOME_RE} ]] \
    || handson::die "$1: «skill=» non va: «${PROVE_SKILL}»"
  PROVE_ESEMPIO="${PROVE_ESEMPIO:-${PROVE_SKILL}}"
  [[ "${PROVE_ESEMPIO}" =~ ${PROVE_NOME_RE} ]] \
    || handson::die "$1: «esempio=» non va: «${PROVE_ESEMPIO}»"
  [[ "${PROVE_MODELLO}" =~ ${PROVE_MODELLO_RE} ]] \
    || handson::die "$1: «modello=» non va: «${PROVE_MODELLO}»"
  [[ "${PROVE_EFFORT}" =~ ${PROVE_EFFORT_RE} ]] \
    || handson::die "$1: «effort=» non va: «${PROVE_EFFORT}»"
}

# Fissa i percorsi dello spazio di lavoro e rifiuta i collegamenti simbolici:
# una cartella della skill che è un collegamento porterebbe le cancellazioni
# nella copia fino ai file veri (RU-01.S5).
# Globals: HANDSON_WORKSPACE (letta); PROVE_DIR_SKILL, PROVE_BASE (assegnate).
prove::imposta_percorsi() {
  local p ws="${HANDSON_WORKSPACE}"
  PROVE_DIR_SKILL="${ws}/.claude/skills/${PROVE_SKILL}"
  PROVE_BASE="${ws}/${PROVE_SKILL}-workspace"
  for p in "${ws}/.claude" "${ws}/.claude/skills" "${PROVE_DIR_SKILL}" \
      "${PROVE_BASE}"; do
    [[ ! -L "${p}" ]] \
      || handson::die "${p} è un collegamento simbolico: non lo uso"
  done
}

# Copia ogni voce di una cartella, punti compresi, tranne quelle nominate.
# Arguments: $1 da, $2 a (esiste già), poi i nomi da lasciare fuori.
# Returns: 0; 2 se una copia non riesce.
prove::copia_tranne() {
  local da="$1" a="$2"
  shift 2
  (
    shopt -s dotglob nullglob
    for voce in "${da}"/*; do
      for escluso in "$@"; do
        [[ "${voce##*/}" != "${escluso}" ]] || continue 2
      done
      cp -Rp -- "${voce}" "${a}/" || exit 2
    done
  )
}

# Cancella una cartella costruita da nomi già controllati: mai un percorso
# vuoto, / o un collegamento simbolico (RU-01.S5).
# Arguments: $1 la cartella.
prove::_cancella() {
  [[ -n "$1" && "$1" != "/" ]] \
    || handson::die "percorso vuoto o /: non cancello niente"
  [[ ! -L "$1" ]] || handson::die "non cancello un collegamento: $1"
  rm -rf -- "$1"
}

# `copia esempio` e `copia modello`. Mai sopra uno SKILL.md: il lavoro del
# partecipante non si sovrascrive; evals/ non si tocca.
# Globals: PROVE_DIR_SKILL, HANDSON_ROOT. Arguments: $1 esempio o modello.
prove::copia_skill() {
  local dest="${PROVE_DIR_SKILL}" incollabile
  if [[ -e "${dest}/SKILL.md" ]]; then
    handson::die "${dest}/SKILL.md c'è già: non lo sovrascrivo. Per" \
      "ricominciare, spostalo o cancellalo tu."
  fi
  mkdir -p -- "${dest}" || handson::die "non riesco a creare ${dest}"
  if [[ "$1" == esempio ]]; then
    prove::_copia_esempio "${dest}"
  else
    prove::_copia_modello "${dest}"
  fi
  handson::quote_into incollabile "${dest}"
  printf 'Adesso adattala, e controlla il file con:\n'
  printf '  python3 -B -I tools/controlla_skill.py %s\n' "${incollabile}"
}

# L'esempio porta più file: non ne va sopra nessuno di quelli del partecipante,
# tranne evals/, che non copia.
# Arguments: $1 la cartella di arrivo.
prove::_copia_esempio() {
  local da="${HANDSON_ROOT}/riferimenti/skill-di-esempio/${PROVE_ESEMPIO}" voce
  [[ -f "${da}/SKILL.md" ]] \
    || handson::die "manca la skill di esempio: ${da}/SKILL.md"
  for voce in "$1"/* "$1"/.[!.]*; do
    [[ -e "${voce}" || -L "${voce}" ]] || continue
    [[ "${voce##*/}" == evals ]] \
      || handson::die "${voce} c'è già: non ci copio sopra l'esempio. Per" \
        "ripartire dall'esempio, spostalo tu."
  done
  prove::copia_tranne "${da}" "$1" evals \
    || handson::die "non riesco a copiare ${da}"
  printf 'Copiata: riferimenti/skill-di-esempio/%s in .claude/skills/%s/\n' \
    "${PROVE_ESEMPIO}" "${PROVE_SKILL}"
}

# Il nome della skill entra con un'espansione di bash, non con sed: il modello
# può contenere qualsiasi carattere.
# Arguments: $1 la cartella di arrivo.
prove::_copia_modello() {
  local modello="${HANDSON_ROOT}/riferimenti/template-SKILL.md" testo
  handson::need_file "${modello}"
  testo="$(cat -- "${modello}"; printf x)" \
    || handson::die "non riesco a leggere ${modello}"
  testo="${testo%x}"
  printf '%s' "${testo//nome-della-skill/${PROVE_SKILL}}" > "$1/SKILL.md" \
    || handson::die "non riesco a scrivere $1/SKILL.md"
  printf 'Copiata: riferimenti/template-SKILL.md in .claude/skills/%s/\n' \
    "${PROVE_SKILL}"
}

# Tutto ciò che deve valere prima di una qualsiasi chiamata.
# Globals: HANDSON_ITEM_DIR, HANDSON_ITEM_ID, PROVE_* (lette); PROVE_PRIMA
#   (assegnata). Arguments: $1 la configurazione.
prove::_precondizioni() {
  [[ "${HANDSON_ENV}" == claude-code-pro ]] \
    || handson::die "${HANDSON_ITEM_ID} è un elemento claude-code-pro:" \
      "HANDSON_ENV «${HANDSON_ENV}» non vale qui (la chiave API resterebbe" \
      "nell'ambiente di claude -p)"
  handson::need_file "${HANDSON_ITEM_DIR}/verifica.py"
  PROVE_PRIMA="${HANDSON_ITEM_DIR}/prove/prima.sh"
  if [[ -e "${PROVE_PRIMA}" && ! -x "${PROVE_PRIMA}" ]]; then
    handson::die "${PROVE_PRIMA} non è eseguibile: chmod +x"
  fi
  if [[ "$1" == with_skill && ! -f "${PROVE_DIR_SKILL}/SKILL.md" ]]; then
    handson::die "manca .claude/skills/${PROVE_SKILL}/SKILL.md: scrivilo, o" \
      "parti da: tools/prove_skill.sh ${HANDSON_ITEM_ID} copia esempio"
  fi
  handson::need_claude
  handson::_claude_p_checks "${PROVE_MODELLO}" "un prompt"
  local arg
  for arg in "${PROVE_MODELLO}" "${PROVE_STRUMENTI}" "${PROVE_EFFORT}"; do
    handson::_claude_arg_ok "${arg}"
  done
  # In claude -p con dontAsk una skill con allowed-tools o disallowed-tools è
  # negata finché le regole non ammettono Skill(<nome>): prima di spendere una
  # chiamata. Vale per tutti e due i bracci, che differiscono in una cosa sola.
  [[ ",${PROVE_STRUMENTI//, /,}," == *",Skill(${PROVE_SKILL}),"* ]] \
    || handson::die "prove/config: fra gli strumenti manca" \
      "Skill(${PROVE_SKILL}): in claude -p con dontAsk una skill con" \
      "allowed-tools o disallowed-tools è negata finché le regole non" \
      "ammettono Skill(<nome>)."
}

# Un giro per volta su uno spazio di lavoro: due insieme supererebbero il tetto
# di PROVE_MAX_INSIEME, e il controllo dell'uno leggerebbe a metà gli stream
# dell'altro. Il segno è una cartella accanto allo spazio di lavoro; lo toglie
# handson::cleanup, all'uscita, soltanto a chi l'ha creato.
# Globals: HANDSON_WORKSPACE_ROOT, HANDSON_ITEM_ID (lette); HANDSON_TMPDIRS.
prove::_prendi_il_turno() {
  local segno="${HANDSON_WORKSPACE_ROOT}/.${HANDSON_ITEM_ID}.prove-in-corso"
  mkdir -- "${segno}" 2> /dev/null \
    || handson::die "c'è già un giro di prove in corso su questo spazio di" \
      "lavoro: aspetta che finisca. Se non ne gira nessuno (uno fermato con" \
      "kill -9, un computer spento), cancella ${segno} e riprova."
  HANDSON_TMPDIRS+=("${segno}")
}

# I casi: un file per prompt, che bash legge senza interpretarlo.
# Globals: PROVE_TMP, PROVE_DIR_SKILL, HANDSON_TOOLS_DIR (lette); PROVE_CASI
#   (assegnata). Arguments: $1 la configurazione.
prove::_leggi_casi() {
  local elenco="${PROVE_TMP}/casi.txt" nome
  local -a opzioni=()
  if [[ "$1" == with_skill ]]; then
    opzioni+=(--near-miss)
  fi
  mkdir -- "${PROVE_TMP}/prompt" || handson::die "mkdir non riesce"
  python3 -B -I "${HANDSON_TOOLS_DIR}/prove_skill_casi.py" casi \
    "${PROVE_DIR_SKILL}" "${PROVE_TMP}/prompt" \
    ${opzioni[@]+"${opzioni[@]}"} > "${elenco}" \
    || handson::die "non riesco a leggere i casi di prova di ${PROVE_SKILL}"
  PROVE_CASI=()
  while IFS= read -r nome; do
    [[ "${nome}" =~ ${PROVE_CASO_RE} ]] \
      || handson::die "un nome di caso che non va: «${nome}»"
    PROVE_CASI+=("${nome}")
  done < "${elenco}"
  (( ${#PROVE_CASI[@]} > 0 )) \
    || handson::die "nessun caso da provare per ${PROVE_SKILL}"
}

# Rifiuta un'esecuzione che c'è già: uscita 2 prima di ogni chiamata. Il
# messaggio dice tutto ciò che va cancellato per rifare il giro, non solo la
# cartella trovata per prima, e l'iterazione seguente nella stessa
# configurazione.
# Arguments: $1 N, $2 la cartella outputs/, $3 la configurazione.
prove::_rifiuta_se_c_e() {
  [[ ! -e "$2" ]] || handson::die "iterazione $1: ${2#"${PROVE_BASE}"/} c'è" \
    "già: non sovrascrivo un'esecuzione. Per rifare questo giro" \
    "$(prove::_come_rifare "$1" "$3") Oppure usa l'iterazione seguente:" \
    "tools/prove_skill.sh ${HANDSON_ITEM_ID} $(($1 + 1)) ${3%_skill}"
}

# Una cartella dei risultati, se c'è, è una cartella vera: un file creerebbe un
# errore a metà giro, un collegamento porterebbe le scritture altrove.
# Arguments: $1 il percorso.
prove::_cartella_ammessa() {
  [[ ! -L "$1" ]] || handson::die "$1 è un collegamento simbolico: non lo uso"
  [[ ! -e "$1" || -d "$1" ]] || handson::die "$1 non è una cartella: spostalo"
}

# Globals: PROVE_CASI, PROVE_BASE. Arguments: $1 N, $2 la configurazione.
prove::_rifiuta_gia_fatte() {
  local iter="${PROVE_BASE}/iteration-$1" nome p
  prove::_cartella_ammessa "${iter}"
  for nome in "${PROVE_CASI[@]}"; do
    for p in "${iter}/${nome}" "${iter}/${nome}/$2"; do
      prove::_cartella_ammessa "${p}"
    done
    prove::_rifiuta_se_c_e "$1" "${iter}/${nome}/$2/outputs" "$2"
    if [[ "$2" == with_skill && "${nome}" == eval-* ]] && (( $1 >= 2 )); then
      prove::_cartella_ammessa "${iter}/${nome}/old_skill"
      prove::_rifiuta_se_c_e "$1" "${iter}/${nome}/old_skill/outputs" "$2"
    fi
  done
}

# Che cosa cancellare per rifare un giro: un'esecuzione che c'è già non si
# sovrascrive. Arguments: $1 N, $2 la configurazione. Outputs: la frase.
prove::_come_rifare() {
  local iter="${PROVE_BASE}/iteration-$1"
  printf 'cancella %s/eval-*/%s' "${iter}" "$2"
  if [[ "$2" == with_skill ]]; then
    printf ', %s/near-miss-*' "${iter}"
    if (( $1 >= 2 )); then
      printf ', %s/eval-*/old_skill' "${iter}"
    fi
  fi
  printf ' e rilancia lo stesso comando.'
}

# Un'esecuzione fallita non diventa la baseline della seguente: si controlla
# prima della prima chiamata. Globals: PROVE_CASI, PROVE_BASE,
# HANDSON_TOOLS_DIR. Arguments: $1 N.
prove::_controlla_precedenti() {
  (( $1 >= 2 )) || return 0
  local prec=$(($1 - 1)) prima nome
  prima="${PROVE_BASE}/iteration-${prec}"
  [[ -d "${prima}/skill-snapshot" ]] || return 0
  for nome in "${PROVE_CASI[@]}"; do
    [[ "${nome}" == eval-* && -d "${prima}/${nome}/with_skill" ]] || continue
    python3 -B -I "${HANDSON_TOOLS_DIR}/prove_skill_casi.py" esito \
      "${prima}/${nome}/with_skill/outputs/stream.jsonl" > /dev/null 2>&1 \
      || handson::die "iteration-${prec}/${nome}/with_skill non è riuscita:" \
        "non la riuso come old_skill. Rifai prima l'iterazione ${prec}:" \
        "$(prove::_come_rifare "${prec}" with_skill)"
  done
}

# Prepara una copia (vedi la testata) ed esegue prima.sh, se c'è. Esce 2 se
# qualcosa non riesce.
# Arguments: $1 la copia, $2 la configurazione, $3 l'id per prima.sh.
prove::_prepara_copia() {
  local copia="$1" skill="$1/.claude/skills/${PROVE_SKILL}"
  mkdir -- "${copia}" || handson::die "non riesco a creare ${copia}"
  prove::copia_tranne "${HANDSON_WORKSPACE}" "${copia}" .git \
    "${PROVE_SKILL}-workspace" \
    || handson::die "non riesco a copiare ${HANDSON_WORKSPACE}"
  rm -f -- "${copia}/.claude/settings.local.json"
  if [[ "$2" == without_skill ]]; then
    prove::_cancella "${skill}"
  else
    prove::_cancella "${skill}/evals"
  fi
  handson::git_init_workspace "${copia}" "${HANDSON_ITEM_ID}" \
    || handson::die "git non riesce ad aprire la copia ${copia}"
  if ! git -C "${copia}" config user.name "${HANDSON_GIT_NAME}" \
      || ! git -C "${copia}" config user.email "${HANDSON_GIT_EMAIL}"; then
    handson::die "git non riesce a configurare la copia ${copia}"
  fi
  if [[ -e "${PROVE_PRIMA}" ]]; then
    ( cd -- "${copia}" && PN_HANDSON_ROOT="${HANDSON_ROOT}" \
      "${PROVE_PRIMA}" "${copia}" "$3" ) >&2 \
      || handson::die "prove/prima.sh non riesce per il caso $3"
  fi
}

# Tutte le copie, prima che parta una sola esecuzione. Controlla anche che
# nessun prompt contenga una chiave API.
# Globals: PROVE_CASI, PROVE_TMP (lette); PROVE_COPIE, PROVE_USCITE
#   (assegnate). Arguments: $1 N, $2 la configurazione.
prove::_prepara_tutte() {
  local i=0 nome id_caso
  for nome in "${PROVE_CASI[@]}"; do
    handson::_claude_key_ok "$(< "${PROVE_TMP}/prompt/${nome}.prompt")"
    id_caso="${nome#eval-}"
    if [[ "${nome}" == near-miss-* ]]; then
      id_caso="q${nome#near-miss-}"
    fi
    PROVE_COPIE[i]="${PROVE_TMP}/esecuzione-${i}"
    PROVE_USCITE[i]="${PROVE_BASE}/iteration-$1/${nome}/$2/outputs"
    prove::_prepara_copia "${PROVE_COPIE[i]}" "$2" "${id_caso}"
    i=$((i + 1))
  done
}

# La versione sotto prova, senza evals/: iteration-N/skill-snapshot/. Una
# fotografia rimasta da un giro senza esecuzioni si rifà.
# Globals: PROVE_BASE, PROVE_DIR_SKILL. Arguments: $1 N.
prove::_fotografa() {
  local foto="${PROVE_BASE}/iteration-$1/skill-snapshot"
  mkdir -p -- "${PROVE_BASE}/iteration-$1" \
    || handson::die "non riesco a creare ${PROVE_BASE}/iteration-$1"
  prove::_cancella "${foto}"
  mkdir -- "${foto}" || handson::die "non riesco a creare ${foto}"
  prove::copia_tranne "${PROVE_DIR_SKILL}" "${foto}" evals \
    || handson::die "non riesco a fotografare ${PROVE_DIR_SKILL}"
}

# old_skill: le esecuzioni with_skill dell'iterazione prima, copiate e non
# rifatte, dove la guida dello standard le rifarebbe: si risparmia la quota
# del piano. grading.json e timing.json li ricalcola il controllo.
# Globals: PROVE_BASE, PROVE_CASI. Arguments: $1 N.
prove::_riusa_precedenti() {
  (( $1 >= 2 )) || return 0
  local prima="${PROVE_BASE}/iteration-$(($1 - 1))" nome
  if [[ ! -d "${prima}/skill-snapshot" ]]; then
    printf "Nessuna fotografia dell'iterazione %d: niente old_skill.\n" \
      "$(($1 - 1))"
    return 0
  fi
  for nome in "${PROVE_CASI[@]}"; do
    [[ "${nome}" == eval-* ]] || continue
    if [[ ! -d "${prima}/${nome}/with_skill" ]]; then
      printf "%s: nessuna esecuzione dell'iterazione %d da riusare.\n" \
        "${nome}" "$(($1 - 1))"
      continue
    fi
    if ! mkdir -p -- "${PROVE_BASE}/iteration-$1/${nome}" \
        || ! cp -Rp -- "${prima}/${nome}/with_skill" \
          "${PROVE_BASE}/iteration-$1/${nome}/old_skill"; then
      handson::die "non riesco a riusare ${prima}/${nome}/with_skill"
    fi
  done
  printf "Le esecuzioni dell'iterazione %d si riusano come old_skill, non si" \
    "$(($1 - 1))"
  printf ' rifanno: si risparmia la quota del piano.\n'
}

# Un'esecuzione, in un processo suo: la sessione dalla radice della copia,
# STDIN da /dev/null, lo stream e STDERR nei file, poi ciò che ha cambiato.
# Il prompt si legge dal file: mai eval, mai senza virgolette.
# Arguments: $1 la copia, $2 il file del prompt, $3 la cartella outputs/.
# Returns: l'uscita di claude; 3 se git status non riesce.
prove::_una_esecuzione() {
  local prompt rc=0
  prompt="$(cat -- "$2"; printf x)"
  prompt="${prompt%x}"
  cd -- "$1" || return 2
  handson::claude_p "${PROVE_MODELLO}" "${PROVE_STRUMENTI}" "${prompt}" \
    --effort "${PROVE_EFFORT}" --strict-mcp-config --no-session-persistence \
    > "$3/stream.jsonl" 2> "$3/stderr.txt" < /dev/null || rc=$?
  git -C "$1" status --porcelain > "$3/file-cambiati.txt" \
    2>> "$3/stderr.txt" || (( rc != 0 )) || rc=3
  return "${rc}"
}

# Tutte le cartelle outputs/, con il prompt di ogni esecuzione accanto al suo
# stream: lo stream non lo riporta, e evals.json può cambiare dopo. Prima della
# prima chiamata, così un errore qui non lascia sessioni a metà.
# Globals: PROVE_CASI, PROVE_USCITE, PROVE_TMP, PROVE_N, PROVE_CONF.
prove::_crea_uscite() {
  local i
  for (( i = 0; i < ${#PROVE_CASI[@]}; i++ )); do
    if ! mkdir -p -- "${PROVE_USCITE[i]}" || ! cp -- \
        "${PROVE_TMP}/prompt/${PROVE_CASI[i]}.prompt" \
        "${PROVE_USCITE[i]}/prompt.txt"; then
      handson::die "non riesco a preparare ${PROVE_USCITE[i]}: nessuna" \
        "esecuzione è partita. $(prove::_come_rifare "${PROVE_N}" \
        "${PROVE_CONF}")"
    fi
  done
}

# Parte l'esecuzione i in background. Globals: PROVE_* (PROVE_PID assegnata).
# Arguments: $1 l'indice.
prove::_lancia() {
  local nome="${PROVE_CASI[$1]}"
  printf '  parte %s\n' "${nome}"
  prove::_una_esecuzione "${PROVE_COPIE[$1]}" \
    "${PROVE_TMP}/prompt/${nome}.prompt" "${PROVE_USCITE[$1]}" &
  PROVE_PID[$1]=$!
}

# Aspetta l'esecuzione i e controlla la sua uscita e il suo stream: un'uscita
# 0 con un is_error, o senza un risultato, è un'esecuzione fallita.
# Globals: PROVE_FALLITE. Arguments: $1 l'indice.
prove::_aspetta() {
  local uscita="${PROVE_USCITE[$1]}" nome="${PROVE_CASI[$1]}" rc=0 perche=''
  wait "${PROVE_PID[$1]}" || rc=$?
  # Finita: il suo pid può tornare a un altro processo, e nessuno va fermato.
  PROVE_PID[$1]=''
  if (( rc != 0 )); then
    perche="uscita ${rc}, vedi ${uscita#"${HANDSON_WORKSPACE}"/}/stderr.txt"
  else
    perche="$(python3 -B -I "${HANDSON_TOOLS_DIR}/prove_skill_casi.py" \
      esito "${uscita}/stream.jsonl" 2>&1)" || rc=1
  fi
  if (( rc == 0 )); then
    printf '  finita %s\n' "${nome}"
  else
    printf '  FALLITA %s: %s\n' "${nome}" "${perche}"
    PROVE_FALLITE=$((PROVE_FALLITE + 1))
  fi
}

# Ferma un processo e tutto ciò che ha avviato: il pid di un'esecuzione è del
# suo sottoprocesso, e claude sta due livelli sotto. Che pgrep ci sia lo
# controlla prove_skill.sh prima di cominciare; qui la sua uscita diversa da 0
# vuol dire nessun figlio. Arguments: $1 il pid.
prove::_ferma_albero() {
  local figlio
  while IFS= read -r figlio; do
    prove::_ferma_albero "${figlio}"
  done < <(pgrep -P "$1" 2> /dev/null || true)
  kill -TERM "$1" 2> /dev/null || true
}

# Su un segnale: ferma le sessioni ancora vive e le aspetta, poi esce, e solo
# allora handson::cleanup cancella le copie: una sessione non deve restare a
# consumare il piano in una cartella che non c'è più. Senza `set -e`: un errore
# di scrittura su una pipe chiusa non deve saltare il resto.
# Globals: PROVE_PID, PROVE_N, PROVE_CONF. Arguments: $1 l'uscita.
prove::_interrompi() {
  local pid vive=0
  set +e
  trap '' INT TERM HUP PIPE
  for pid in ${PROVE_PID[@]+"${PROVE_PID[@]}"}; do
    if [[ -n "${pid}" ]]; then
      vive=1
      prove::_ferma_albero "${pid}"
    fi
  done
  wait 2> /dev/null
  if (( vive == 1 )); then
    handson::err "Interrotto: le esecuzioni in corso sono ferme. Per rifare" \
      "questo giro $(prove::_come_rifare "${PROVE_N}" "${PROVE_CONF}")"
  fi
  exit "$1"
}

# Tutte le esecuzioni, al massimo PROVE_MAX_INSIEME insieme: la più vecchia
# si aspetta prima di farne partire un'altra. `wait` per pid, non `wait -n`:
# il bash 3.2 non ce l'ha. Una che fallisce non ferma le altre.
# Globals: PROVE_CASI.
prove::_lancia_tutte() {
  local i aspettate=0 totale="${#PROVE_CASI[@]}"
  for (( i = 0; i < totale; i++ )); do
    if (( i - aspettate >= PROVE_MAX_INSIEME )); then
      prove::_aspetta "${aspettate}"
      aspettate=$((aspettate + 1))
    fi
    prove::_lancia "${i}"
  done
  while (( aspettate < totale )); do
    prove::_aspetta "${aspettate}"
    aspettate=$((aspettate + 1))
  done
}

# Dopo le esecuzioni: verifica.py --solo-prove stampa la tabella e scrive
# timing, grading e benchmark. Poi l'uscita: 1 se un'esecuzione è fallita, con
# che cosa cancellare per rifarla; altrimenti quella del controllo.
# Globals: HANDSON_*, PROVE_FALLITE, PROVE_BASE. Arguments: $1 N, $2 la
# configurazione.
prove::_chiudi() {
  local rc=0
  printf '\n'
  ( cd -- "${HANDSON_WORKSPACE}" && PN_HANDSON_ROOT="${HANDSON_ROOT}" \
    python3 -B -I "${HANDSON_ITEM_DIR}/verifica.py" "${HANDSON_WORKSPACE}" \
    --solo-prove ) || rc=$?
  if (( PROVE_FALLITE > 0 )); then
    handson::err "${PROVE_FALLITE} esecuzione/i fallita/e. Per rifare questo" \
      "giro $(prove::_come_rifare "$1" "$2")"
    exit 1
  fi
  case "${rc}" in
    0|1) exit "${rc}" ;;
    *) handson::err "verifica.py non ha potuto leggere le prove (uscita ${rc})"
       exit 2 ;;
  esac
}

# `<N> without` e `<N> with`: controlla, prepara, esegue, legge. Non torna:
# esce con il contratto di prove_skill.sh.
# Globals: quasi tutte (vedi sopra). Arguments: $1 N, $2 without o with.
prove::esegui() {
  local n="$1" conf=without_skill quante
  [[ "$2" == without ]] || conf=with_skill
  PROVE_N="${n}" PROVE_CONF="${conf}"
  # La modalità è sempre dontAsk, qualunque sia quella dell'ambiente.
  # shellcheck disable=SC2034  # le leggono handson::claude_p e handson::pause
  HANDSON_OUTPUT_FORMAT=stream-json HANDSON_NO_PAUSE=1 \
    HANDSON_PERMISSION_MODE=dontAsk
  prove::_precondizioni "${conf}"
  handson::tmpdir PROVE_TMP
  # Assoluto anche con un TMPDIR relativo: ogni esecuzione cambia cartella.
  PROVE_TMP="$(cd -- "${PROVE_TMP}" && pwd -P)" \
    || handson::die "non riesco a entrare nella cartella temporanea"
  # Da qui in poi un segnale ferma anche le sessioni in corso, prima che
  # l'uscita cancelli le copie in cui lavorano.
  trap 'prove::_interrompi 130' INT
  trap 'prove::_interrompi 143' TERM
  trap 'prove::_interrompi 129' HUP
  trap 'prove::_interrompi 141' PIPE
  prove::_prendi_il_turno
  prove::_leggi_casi "${conf}"
  prove::_rifiuta_gia_fatte "${n}" "${conf}"
  if [[ "${conf}" == with_skill ]]; then
    prove::_controlla_precedenti "${n}"
  fi
  prove::_prepara_tutte "${n}" "${conf}"
  if [[ "${conf}" == with_skill ]]; then
    prove::_fotografa "${n}"
    prove::_riusa_precedenti "${n}"
  fi
  prove::_crea_uscite
  quante="${#PROVE_CASI[@]} esecuzioni, ognuna"
  if (( ${#PROVE_CASI[@]} == 1 )); then
    quante='1 esecuzione,'
  fi
  printf '%s, iterazione %s, %s: %s in una sessione nuova' \
    "${HANDSON_ITEM_ID}" "${n}" "${conf}" "${quante}"
  printf '; modello %s, effort %s, al massimo %d insieme.\n' \
    "${PROVE_MODELLO}" "${PROVE_EFFORT}" "${PROVE_MAX_INSIEME}"
  prove::_lancia_tutte
  prove::_chiudi "${n}" "${conf}"
}
