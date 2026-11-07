# shellcheck shell=bash
# =====================================================================
# lib_prova_contesto.sh -- il lavoro di tools/prova_contesto.sh: la
# configurazione e le richieste dell'elemento, le copie pulite dello spazio
# di lavoro, le esecuzioni, ciò che resta di ognuna.
# ---------------------------------------------------------------------
# Libreria: si fa SOURCE dopo tools/lib_handson.sh, non si esegue (nessun bit
# di esecuzione). La usa solo tools/prova_contesto.sh, che documenta l'uso e
# le uscite. Le precondizioni escono 2 con handson::die prima di ogni
# chiamata: tutte le copie si preparano prima che ne parta una.
#
# Una copia è una cartella temporanea con i file dello spazio di lavoro così
# come sono, senza .git, senza prove-contesto/ (i risultati), senza
# .claude/settings.local.json (le regole salvate da una sessione
# interattiva), senza il registro dell'hook della sessione interattiva e
# senza i percorsi di «escludi=» (gli appunti del team, vendor/…): le
# versioni devono differire soltanto nei file di istruzioni. Nella versione
# base mancano anche tutti i CLAUDE.md, CLAUDE.local.md e AGENTS.md e la
# cartella .claude/rules/. Poi prove/prima.sh, se c'è, e un repository git
# nuovo, con un solo commit e l'identità del corso: ciò che prima.sh cambia
# sta nel commit di partenza, e Claude può fare un commit suo.
#
# Compatibile con il bash 3.2, come lib_handson.sh.
# =====================================================================

if [[ -n "${CONTESTO_LIB_LOADED:-}" ]]; then
  return 0
fi
readonly CONTESTO_LIB_LOADED=1

readonly CONTESTO_ID_RE='^[a-z][a-z0-9-]*$'
readonly CONTESTO_STRUMENTI_RE='^[A-Z][A-Za-z]*(,[A-Z][A-Za-z]*)*$'
readonly CONTESTO_MODELLO_RE='^[A-Za-z0-9._:-]+$'
readonly CONTESTO_EFFORT_RE='^[a-z]+$'
readonly CONTESTO_PERCORSO_RE='^[A-Za-z0-9._-]+(/[A-Za-z0-9._-]+)*$'
readonly CONTESTO_INTESTAZIONE=$'id\tstrumenti\tprompt'
readonly CONTESTO_REGISTRO='.claude/caricamenti.jsonl'
# Al massimo tre esecuzioni insieme, come le prove del Modulo 5: ogni
# richiesta è una sessione nuova, e cinque partecipanti restano nei limiti
# del piano.
readonly CONTESTO_MAX_INSIEME=3

# La configurazione dell'elemento (prove/config).
CONTESTO_MODELLO=sonnet
CONTESTO_EFFORT=low
CONTESTO_ESCLUDI=()
CONTESTO_VIETATI=''
# I percorsi e lo stato di un giro. Gli array vanno per indice, uno per
# richiesta.
CONTESTO_VERSIONE=''
CONTESTO_RILANCIA=''
CONTESTO_BASE=''
CONTESTO_PRIMA=''
CONTESTO_TMP=''
CONTESTO_FALLITE=0
CONTESTO_RICHIESTE=()
CONTESTO_STRUMENTI=()
CONTESTO_COPIE=()
CONTESTO_USCITE=()
CONTESTO_PRIMO=()
CONTESTO_PID=()

# Legge prove/config, «chiave=valore», senza eval: un valore resta un testo.
# Globals: CONTESTO_MODELLO, CONTESTO_EFFORT, CONTESTO_ESCLUDI,
#   CONTESTO_VIETATI (assegnate).
# Arguments: $1 il file. Returns: 0; una riga che non va esce 2.
contesto::leggi_config() {
  local file="$1" riga chiave valore p
  handson::need_file "${file}"
  while IFS= read -r riga || [[ -n "${riga}" ]]; do
    riga="${riga%"${HANDSON_CR}"}"
    case "${riga}" in ''|'#'*) continue ;; esac
    [[ "${riga}" == *=* ]] \
      || handson::die "${file}: una riga senza «=»: «${riga}»"
    chiave="${riga%%=*}"
    valore="${riga#*=}"
    case "${chiave}" in
      modello) CONTESTO_MODELLO="${valore}" ;;
      effort) CONTESTO_EFFORT="${valore}" ;;
      vietati) CONTESTO_VIETATI="${valore}" ;;
      escludi) read -r -a CONTESTO_ESCLUDI <<< "${valore}" ;;
      *) handson::die "${file}: chiave sconosciuta: «${chiave}»" ;;
    esac
  done < "${file}"
  [[ "${CONTESTO_MODELLO}" =~ ${CONTESTO_MODELLO_RE} ]] \
    || handson::die "${file}: «modello=» non va: «${CONTESTO_MODELLO}»"
  [[ "${CONTESTO_EFFORT}" =~ ${CONTESTO_EFFORT_RE} ]] \
    || handson::die "${file}: «effort=» non va: «${CONTESTO_EFFORT}»"
  for p in ${CONTESTO_ESCLUDI[@]+"${CONTESTO_ESCLUDI[@]}"}; do
    [[ "${p}" =~ ${CONTESTO_PERCORSO_RE} && "/${p}/" != */../* \
        && "/${p}/" != */./* ]] \
      || handson::die "${file}: un percorso di «escludi=» che non va: «${p}»"
  done
}

# Le richieste: prove/richieste.tsv, l'intestazione «id strumenti prompt»
# separata da tabulazioni, poi una riga per richiesta. Ogni prompt va in un
# file, che bash legge senza interpretarlo.
# Globals: CONTESTO_TMP (letta); CONTESTO_RICHIESTE, CONTESTO_STRUMENTI
#   (assegnate). Arguments: $1 il file.
contesto::leggi_richieste() {
  local file="$1" riga id strumenti prompt n=0
  handson::need_file "${file}"
  mkdir -- "${CONTESTO_TMP}/prompt" || handson::die "mkdir non riesce"
  CONTESTO_RICHIESTE=() CONTESTO_STRUMENTI=()
  while IFS= read -r riga || [[ -n "${riga}" ]]; do
    riga="${riga%"${HANDSON_CR}"}"
    n=$((n + 1))
    if (( n == 1 )); then
      [[ "${riga}" == "${CONTESTO_INTESTAZIONE}" ]] \
        || handson::die "${file}: l'intestazione è «id, strumenti, prompt»" \
          "separati da tabulazioni"
      continue
    fi
    [[ -n "${riga}" ]] || continue
    IFS=$'\t' read -r id strumenti prompt <<< "${riga}"
    [[ "${id}" =~ ${CONTESTO_ID_RE} ]] \
      || handson::die "${file}, riga ${n}: un id che non va: «${id}»"
    [[ "${strumenti}" =~ ${CONTESTO_STRUMENTI_RE} ]] \
      || handson::die "${file}, riga ${n}: gli strumenti sono nomi" \
        "separati da virgole, senza spazi né regole: «${strumenti}»"
    [[ -n "${prompt}" && ! -e "${CONTESTO_TMP}/prompt/${id}.prompt" ]] \
      || handson::die "${file}, riga ${n}: prompt vuoto o id ripetuto"
    handson::_claude_key_ok "${prompt}"
    printf '%s\n' "${prompt}" > "${CONTESTO_TMP}/prompt/${id}.prompt" \
      || handson::die "non riesco a scrivere il prompt di ${id}"
    CONTESTO_RICHIESTE+=("${id}")
    CONTESTO_STRUMENTI+=("${strumenti}")
  done < "${file}"
  (( ${#CONTESTO_RICHIESTE[@]} > 0 )) \
    || handson::die "${file}: nessuna richiesta"
}

# Cancella un percorso costruito da nomi già controllati: mai vuoto, / o un
# collegamento simbolico (RU-01.S5).
# Arguments: $1 il percorso.
contesto::_cancella() {
  [[ -n "$1" && "$1" != "/" ]] \
    || handson::die "percorso vuoto o /: non cancello niente"
  [[ ! -L "$1" ]] || handson::die "non cancello un collegamento: $1"
  rm -rf -- "$1"
}

# I file di istruzioni di una cartella: ogni CLAUDE.md, CLAUDE.local.md e
# AGENTS.md, e i file sotto .claude/rules/. Arguments: $1 la cartella.
# Outputs: i percorsi relativi, uno per riga, in ordine.
contesto::file_istruzioni() {
  (
    cd -- "$1" || exit 2
    {
      find . \( -name .git -o -name prove-contesto \) -prune -o -type f \
        \( -name CLAUDE.md -o -name CLAUDE.local.md -o -name AGENTS.md \) \
        -print
      if [[ -d .claude/rules ]]; then
        find .claude/rules -type f -print
      fi
    } | sed 's|^\./||' | LC_ALL=C sort -u
  )
}

# Prepara una copia (vedi la testata). Esce 2 se qualcosa non riesce.
# Globals: HANDSON_*, CONTESTO_* (lette). Arguments: $1 la copia, $2 l'id
# della richiesta. Outputs: l'hash del commit di partenza su STDOUT.
contesto::_prepara_copia() {
  local copia="$1" p f
  mkdir -- "${copia}" || handson::die "non riesco a creare ${copia}"
  (
    shopt -s dotglob nullglob
    for voce in "${HANDSON_WORKSPACE}"/*; do
      case "${voce##*/}" in .git|prove-contesto) continue ;; esac
      cp -Rp -- "${voce}" "${copia}/" || exit 2
    done
  ) || handson::die "non riesco a copiare ${HANDSON_WORKSPACE}"
  rm -f -- "${copia}/.claude/settings.local.json" \
    "${copia}/${CONTESTO_REGISTRO}"
  for p in ${CONTESTO_ESCLUDI[@]+"${CONTESTO_ESCLUDI[@]}"}; do
    if [[ -e "${copia}/${p}" || -L "${copia}/${p}" ]]; then
      contesto::_cancella "${copia}/${p}"
    fi
  done
  if [[ "${CONTESTO_VERSIONE}" == base ]]; then
    while IFS= read -r f; do
      rm -f -- "${copia}/${f}"
    done < <(contesto::file_istruzioni "${copia}")
    contesto::_cancella "${copia}/.claude/rules"
  fi
  if [[ -e "${CONTESTO_PRIMA}" ]]; then
    ( cd -- "${copia}" && PN_HANDSON_ROOT="${HANDSON_ROOT}" \
      "${CONTESTO_PRIMA}" "${copia}" "$2" ) >&2 \
      || handson::die "prove/prima.sh non riesce per la richiesta $2"
  fi
  contesto::_git_copia "${copia}"
}

# Il repository della copia: un commit con l'identità del corso, il registro
# dell'hook vuoto e fuori da git. Arguments: $1 la copia.
# Outputs: l'hash del commit di partenza.
contesto::_git_copia() {
  local copia="$1"
  handson::git_init_workspace "${copia}" "${HANDSON_ITEM_ID}" \
    || handson::die "git non riesce ad aprire la copia ${copia}"
  if ! git -C "${copia}" config user.name "${HANDSON_GIT_NAME}" \
      || ! git -C "${copia}" config user.email "${HANDSON_GIT_EMAIL}" \
      || ! git -C "${copia}" config commit.gpgsign false; then
    handson::die "git non riesce a configurare la copia ${copia}"
  fi
  if ! mkdir -p -- "${copia}/.claude" \
      || ! printf '%s\n' "/${CONTESTO_REGISTRO}" \
        >> "${copia}/.git/info/exclude" \
      || ! : > "${copia}/${CONTESTO_REGISTRO}"; then
    handson::die "non riesco a preparare il registro dell'hook in ${copia}"
  fi
  git -C "${copia}" rev-parse HEAD \
    || handson::die "git non dà il commit di partenza della copia"
}

# La versione sotto prova: i file di istruzioni e .claude/settings.json.
# Arguments: $1 la cartella da cui fotografare (la prima copia, già pronta),
# $2 la cartella della fotografia.
contesto::fotografa() {
  local da="$1" foto="$2" f
  mkdir -p -- "${foto}" || handson::die "non riesco a creare ${foto}"
  {
    contesto::file_istruzioni "${da}"
    if [[ -f "${da}/.claude/settings.json" ]]; then
      echo .claude/settings.json
    fi
  } > "${CONTESTO_TMP}/fotografia.txt" \
    || handson::die "non riesco a elencare i file di istruzioni"
  while IFS= read -r f; do
    if ! mkdir -p -- "${foto}/$(dirname -- "${f}")" \
        || ! cp -p -- "${da}/${f}" "${foto}/${f}"; then
      handson::die "non riesco a fotografare ${f}"
    fi
  done < "${CONTESTO_TMP}/fotografia.txt"
}

# Prima della prima chiamata, ciò che verifica.py chiederebbe dopo, con le
# stesse funzioni di lib_controlla_contesto.py: in v1 e in v2 un CLAUDE.md
# alla radice (o .claude/CLAUDE.md); in v2 una fotografia diversa da quella
# della v1. Globals: CONTESTO_*, HANDSON_* (lette). Arguments: $1 la
# fotografia della versione, nella cartella temporanea. Esce 2.
contesto::_controlla_fotografia() {
  local rc=0 v1="${HANDSON_WORKSPACE}/prove-contesto/v1/fotografia"
  [[ "${CONTESTO_VERSIONE}" != base ]] || return 0
  python3 -B -I - "${HANDSON_TOOLS_DIR}" "$1" "${v1}" \
    "${CONTESTO_VERSIONE}" <<'PY' || rc=$?
import os
import sys

sys.path.insert(0, sys.argv[1])
import lib_controlla_contesto as cc  # noqa: E402

foto, v1, versione = sys.argv[2:5]
if cc.radice_della(foto) is None:
    sys.exit(3)
if versione == "v2" and os.path.isdir(v1) and cc.foto_uguali(v1, foto):
    sys.exit(4)
PY
  case "${rc}" in
    0) ;;
    3) handson::die "${CONTESTO_VERSIONE} non ha un CLAUDE.md alla radice" \
         "dello spazio di lavoro (né .claude/CLAUDE.md): nessuna esecuzione" \
         "è partita. Scrivilo, poi rilancia: ${CONTESTO_RILANCIA}" ;;
    4) handson::die "v2 è uguale a v1: i file di istruzioni e" \
         ".claude/settings.json sono quelli di prove-contesto/v1/fotografia," \
         "e nessuna esecuzione è partita. Cambiali, poi rilancia:" \
         "${CONTESTO_RILANCIA}" ;;
    *) handson::die "non riesco a controllare la fotografia della" \
         "${CONTESTO_VERSIONE} (python3 è uscito con ${rc})" ;;
  esac
}

# Le precondizioni, prima di ogni chiamata.
# Globals: HANDSON_*, CONTESTO_* (lette); CONTESTO_PRIMA (assegnata).
contesto::_precondizioni() {
  local ws="${HANDSON_WORKSPACE}" arg
  [[ "${HANDSON_ENV}" == claude-code-pro ]] \
    || handson::die "${HANDSON_ITEM_ID} è un elemento claude-code-pro:" \
      "HANDSON_ENV «${HANDSON_ENV}» non vale qui"
  handson::need_file "${HANDSON_ITEM_DIR}/verifica.py"
  CONTESTO_PRIMA="${HANDSON_ITEM_DIR}/prove/prima.sh"
  if [[ -e "${CONTESTO_PRIMA}" && ! -x "${CONTESTO_PRIMA}" ]]; then
    handson::die "${CONTESTO_PRIMA} non è eseguibile: chmod +x"
  fi
  for arg in "${ws}/.claude" "${ws}/prove-contesto" "${ws}/.claude/rules"; do
    [[ ! -L "${arg}" ]] \
      || handson::die "${arg} è un collegamento simbolico: non lo uso"
  done
  if [[ ! -f "${ws}/.claude/hooks/registra_caricamenti.py" ]] \
      || ! grep -q InstructionsLoaded "${ws}/.claude/settings.json" \
        2> /dev/null; then
    handson::die "nello spazio di lavoro manca l'hook InstructionsLoaded" \
      "(.claude/settings.json e .claude/hooks/registra_caricamenti.py):" \
      "senza, le prove non dicono che cosa si è caricato. Rimettili dal" \
      "punto di partenza dell'elemento, poi riprova."
  fi
  handson::need_claude
  handson::_claude_p_checks "${CONTESTO_MODELLO}" "un prompt"
  for arg in "${CONTESTO_MODELLO}" "${CONTESTO_EFFORT}" "${CONTESTO_VIETATI}"
  do
    handson::_claude_arg_ok "${arg}"
  done
}

# Un giro per volta su uno spazio di lavoro, come le prove del Modulo 5: il
# segno è una cartella accanto allo spazio di lavoro, che toglie
# handson::cleanup all'uscita. Globals: HANDSON_TMPDIRS.
contesto::_prendi_il_turno() {
  local segno="${HANDSON_WORKSPACE_ROOT}/.${HANDSON_ITEM_ID}.prove-in-corso"
  mkdir -- "${segno}" 2> /dev/null \
    || handson::die "c'è già un giro di prove in corso su questo spazio di" \
      "lavoro: aspetta che finisca. Se non ne gira nessuno (uno fermato con" \
      "kill -9, un computer spento), cancella ${segno} e riprova."
  HANDSON_TMPDIRS+=("${segno}")
}

# Un giro che c'è già non si sovrascrive: uscita 2 prima di ogni chiamata.
# Globals: CONTESTO_BASE, CONTESTO_VERSIONE, CONTESTO_RILANCIA.
contesto::_rifiuta_gia_fatto() {
  [[ ! -e "${CONTESTO_BASE}" && ! -L "${CONTESTO_BASE}" ]] \
    || handson::die "prove-contesto/${CONTESTO_VERSIONE} c'è già: non" \
      "sovrascrivo un giro di prove. Per rifarlo cancella ${CONTESTO_BASE}" \
      "e rilancia: ${CONTESTO_RILANCIA}"
}

# Il comando da rilanciare, con --radice se c'era, come lo stampa
# tools/prepara_esercizio.sh. Globals: HANDSON_ITEM_ID,
# HANDSON_WORKSPACE_ROOT, CONTESTO_VERSIONE (lette), CONTESTO_RILANCIA
# (assegnata). Arguments: $1 il valore di --radice ("" se assente).
contesto::_rilancia() {
  local radice=''
  CONTESTO_RILANCIA="tools/prova_contesto.sh ${HANDSON_ITEM_ID}"
  CONTESTO_RILANCIA+=" ${CONTESTO_VERSIONE}"
  if [[ -n "$1" ]]; then
    handson::quote_into radice "${HANDSON_WORKSPACE_ROOT}"
    CONTESTO_RILANCIA+=" --radice ${radice}"
  fi
}

# Tutte le copie, prima che parta una sola esecuzione.
# Globals: CONTESTO_* (CONTESTO_COPIE, CONTESTO_USCITE, CONTESTO_PRIMO
#   assegnate).
contesto::_prepara_tutte() {
  local i id
  for (( i = 0; i < ${#CONTESTO_RICHIESTE[@]}; i++ )); do
    id="${CONTESTO_RICHIESTE[i]}"
    CONTESTO_COPIE[i]="${CONTESTO_TMP}/copia-${i}"
    CONTESTO_USCITE[i]="${CONTESTO_BASE}/${id}"
    CONTESTO_PRIMO[i]="$(contesto::_prepara_copia "${CONTESTO_COPIE[i]}" \
      "${id}")" || exit 2
  done
}

# Le cartelle dei risultati, con il prompt e gli strumenti di ogni
# esecuzione accanto al suo stream: lo stream non li riporta.
# Globals: CONTESTO_* (lette).
contesto::_crea_uscite() {
  local i
  for (( i = 0; i < ${#CONTESTO_RICHIESTE[@]}; i++ )); do
    if ! mkdir -p -- "${CONTESTO_USCITE[i]}" || ! cp -- \
        "${CONTESTO_TMP}/prompt/${CONTESTO_RICHIESTE[i]}.prompt" \
        "${CONTESTO_USCITE[i]}/prompt.txt" \
        || ! printf '%s\n' "${CONTESTO_STRUMENTI[i]}" \
          > "${CONTESTO_USCITE[i]}/strumenti.txt"; then
      handson::die "non riesco a preparare ${CONTESTO_USCITE[i]}: nessuna" \
        "esecuzione è partita"
    fi
  done
}

# Un'esecuzione, in un processo suo: la sessione dalla radice della copia,
# STDIN da /dev/null, lo stream e STDERR nei file, la auto memory spenta
# (CLAUDE_CODE_DISABLE_AUTO_MEMORY=1: le versioni differiscono soltanto nei
# file di istruzioni); poi ciò che resta: file cambiati, commit, registro.
# Arguments: $1 la copia, $2 il file del prompt, $3 la cartella dei
#   risultati, $4 il commit di partenza, $5 gli strumenti.
# Returns: l'uscita di claude; 3 se git o la copia del registro non riesce.
contesto::_una_esecuzione() {
  local prompt rc=0
  local -a vietati=()
  prompt="$(cat -- "$2"; printf x)"
  prompt="${prompt%x}"
  prompt="${prompt%$'\n'}"
  if [[ -n "${CONTESTO_VIETATI}" ]]; then
    vietati=(--disallowedTools "${CONTESTO_VIETATI}")
  fi
  cd -- "$1" || return 2
  export CLAUDE_CODE_DISABLE_AUTO_MEMORY=1
  handson::claude_p "${CONTESTO_MODELLO}" "$5" "${prompt}" --tools "$5" \
    ${vietati[@]+"${vietati[@]}"} --effort "${CONTESTO_EFFORT}" \
    --strict-mcp-config --no-session-persistence \
    > "$3/stream.jsonl" 2> "$3/stderr.txt" < /dev/null || rc=$?
  if ! git -C "$1" status --porcelain > "$3/file-cambiati.txt" \
        2>> "$3/stderr.txt" \
      || ! git -C "$1" log --reverse --format='%s%n%n%b%n----' "$4..HEAD" \
        > "$3/commit.txt" 2>> "$3/stderr.txt" \
      || ! git -C "$1" diff --name-only "$4" HEAD \
        > "$3/file-committati.txt" 2>> "$3/stderr.txt" \
      || ! git -C "$1" diff "$4" > "$3/diff.txt" 2>> "$3/stderr.txt" \
      || ! cp -- "$1/${CONTESTO_REGISTRO}" "$3/caricamenti.jsonl"; then
    (( rc != 0 )) || rc=3
  fi
  return "${rc}"
}

# Parte l'esecuzione i in background. Globals: CONTESTO_* (CONTESTO_PID
# assegnata). Arguments: $1 l'indice.
contesto::_lancia() {
  printf '  parte %s\n' "${CONTESTO_RICHIESTE[$1]}"
  contesto::_una_esecuzione "${CONTESTO_COPIE[$1]}" \
    "${CONTESTO_TMP}/prompt/${CONTESTO_RICHIESTE[$1]}.prompt" \
    "${CONTESTO_USCITE[$1]}" "${CONTESTO_PRIMO[$1]}" \
    "${CONTESTO_STRUMENTI[$1]}" &
  CONTESTO_PID[$1]=$!
}

# Se uno stream dice che la sessione è finita bene: un risultato, nessun
# errore. Arguments: $1 lo stream. Outputs: il motivo, se no.
# Returns: 0 sì, 1 no.
contesto::esito() {
  python3 -B -I - "${HANDSON_TOOLS_DIR}" "$1" <<'PY'
import sys
sys.path.insert(0, sys.argv[1])
import lib_leggi_contesto as lc
try:
    esec = lc.leggi_contesto(sys.argv[2]).esecuzione
except lc.Problema as exc:
    print(exc)
    sys.exit(1)
if not esec.completa:
    print("nessun risultato nello stream")
    sys.exit(1)
if esec.errore:
    print("la sessione è finita con un errore")
    sys.exit(1)
PY
}

# Aspetta l'esecuzione i e dice com'è andata. Globals: CONTESTO_*
# (CONTESTO_FALLITE assegnata). Arguments: $1 l'indice.
contesto::_aspetta() {
  local uscita="${CONTESTO_USCITE[$1]}" id="${CONTESTO_RICHIESTE[$1]}" rc=0
  local perche=''
  wait "${CONTESTO_PID[$1]}" || rc=$?
  CONTESTO_PID[$1]=''
  if (( rc != 0 )); then
    perche="uscita ${rc}, vedi ${uscita#"${HANDSON_WORKSPACE}"/}/stderr.txt"
  else
    perche="$(contesto::esito "${uscita}/stream.jsonl" 2>&1)" || rc=1
  fi
  if (( rc == 0 )); then
    printf '  finita %s\n' "${id}"
  else
    printf '  FALLITA %s: %s\n' "${id}" "${perche}"
    CONTESTO_FALLITE=$((CONTESTO_FALLITE + 1))
  fi
}

# Ferma un processo e tutto ciò che ha avviato. Arguments: $1 il pid.
contesto::_ferma_albero() {
  local figlio
  while IFS= read -r figlio; do
    contesto::_ferma_albero "${figlio}"
  done < <(pgrep -P "$1" 2> /dev/null || true)
  kill -TERM "$1" 2> /dev/null || true
}

# Su un segnale: ferma le sessioni ancora vive e le aspetta, poi esce; solo
# allora handson::cleanup cancella le copie. Arguments: $1 l'uscita.
contesto::_interrompi() {
  local pid vive=0
  set +e
  trap '' INT TERM HUP PIPE
  for pid in ${CONTESTO_PID[@]+"${CONTESTO_PID[@]}"}; do
    if [[ -n "${pid}" ]]; then
      vive=1
      contesto::_ferma_albero "${pid}"
    fi
  done
  wait 2> /dev/null
  if (( vive == 1 )); then
    handson::err "Interrotto: le esecuzioni in corso sono ferme. Per rifare" \
      "il giro cancella ${CONTESTO_BASE} e rilancia lo stesso comando."
  fi
  exit "$1"
}

# Tutte le esecuzioni, al massimo CONTESTO_MAX_INSIEME insieme; `wait` per
# pid, non `wait -n` (bash 3.2). Una che fallisce non ferma le altre.
contesto::_lancia_tutte() {
  local i aspettate=0 totale="${#CONTESTO_RICHIESTE[@]}"
  for (( i = 0; i < totale; i++ )); do
    if (( i - aspettate >= CONTESTO_MAX_INSIEME )); then
      contesto::_aspetta "${aspettate}"
      aspettate=$((aspettate + 1))
    fi
    contesto::_lancia "${i}"
  done
  while (( aspettate < totale )); do
    contesto::_aspetta "${aspettate}"
    aspettate=$((aspettate + 1))
  done
}

# Dopo le esecuzioni: verifica.py --solo-prove stampa la tabella; poi
# l'uscita, 1 se un'esecuzione è fallita, altrimenti quella del controllo.
contesto::_chiudi() {
  local rc=0
  printf '\n'
  ( cd -- "${HANDSON_WORKSPACE}" && PN_HANDSON_ROOT="${HANDSON_ROOT}" \
    python3 -B -I "${HANDSON_ITEM_DIR}/verifica.py" "${HANDSON_WORKSPACE}" \
    --solo-prove ) || rc=$?
  if (( CONTESTO_FALLITE > 0 )); then
    handson::err "${CONTESTO_FALLITE} esecuzione/i fallita/e. Per rifare il" \
      "giro cancella ${CONTESTO_BASE} e rilancia lo stesso comando."
    exit 1
  fi
  case "${rc}" in
    0|1) exit "${rc}" ;;
    *) handson::err "verifica.py non ha potuto leggere le prove" \
         "(uscita ${rc})"
       exit 2 ;;
  esac
}

# Un giro: controlla, prepara, esegue, legge. Non torna: esce con il
# contratto di prova_contesto.sh. La fotografia nasce nella cartella
# temporanea e va in prove-contesto/<versione>/ solo dopo i suoi controlli.
# Arguments: $1 base, v1 o v2; $2 il valore di --radice ("" se assente).
contesto::esegui() {
  CONTESTO_VERSIONE="$1"
  contesto::_rilancia "${2:-}"
  # La modalità è sempre dontAsk, qualunque sia quella dell'ambiente.
  # shellcheck disable=SC2034  # le leggono handson::claude_p e handson::pause
  HANDSON_OUTPUT_FORMAT=stream-json HANDSON_NO_PAUSE=1 \
    HANDSON_PERMISSION_MODE=dontAsk
  CONTESTO_BASE="${HANDSON_WORKSPACE}/prove-contesto/${CONTESTO_VERSIONE}"
  contesto::_precondizioni
  handson::tmpdir CONTESTO_TMP
  CONTESTO_TMP="$(cd -- "${CONTESTO_TMP}" && pwd -P)" \
    || handson::die "non riesco a entrare nella cartella temporanea"
  trap 'contesto::_interrompi 130' INT
  trap 'contesto::_interrompi 143' TERM
  trap 'contesto::_interrompi 129' HUP
  trap 'contesto::_interrompi 141' PIPE
  contesto::_prendi_il_turno
  contesto::_rifiuta_gia_fatto
  contesto::leggi_richieste "${HANDSON_ITEM_DIR}/prove/richieste.tsv"
  contesto::_prepara_tutte
  contesto::fotografa "${CONTESTO_COPIE[0]}" "${CONTESTO_TMP}/fotografia"
  contesto::_controlla_fotografia "${CONTESTO_TMP}/fotografia"
  if ! mkdir -p -- "${CONTESTO_BASE}" || ! cp -Rp -- \
      "${CONTESTO_TMP}/fotografia" "${CONTESTO_BASE}/fotografia"; then
    handson::die "non riesco a scrivere ${CONTESTO_BASE}/fotografia"
  fi
  contesto::_crea_uscite
  printf '%s, versione %s: %d richieste, ognuna in una sessione nuova;' \
    "${HANDSON_ITEM_ID}" "${CONTESTO_VERSIONE}" "${#CONTESTO_RICHIESTE[@]}"
  printf ' modello %s, effort %s, al massimo %d insieme.\n' \
    "${CONTESTO_MODELLO}" "${CONTESTO_EFFORT}" "${CONTESTO_MAX_INSIEME}"
  contesto::_lancia_tutte
  contesto::_chiudi
}
