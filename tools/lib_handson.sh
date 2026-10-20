# shellcheck shell=bash
# =====================================================================
# lib_handson.sh -- funzioni condivise dagli strumenti del repository
# delle esercitazioni (tools/*.sh) e dagli script degli elementi (demo,
# _docente/live.sh)
# ---------------------------------------------------------------------
# Libreria: si fa SOURCE, non si esegue (nessun bit di esecuzione).
#
# Tre famiglie di funzioni, nell'ordine del file:
#   1. il contratto d'aula delle demo: il comando si vede PRIMA di girare
#      e la riga stampata è lo stesso array che viene eseguito
#      (handson::run); le pause solo su un terminale; l'esito 0/1/2
#      (handson::check, handson::verdict_rc, handson::finish);
#      handson::claude_p per Claude Code in modalità non interattiva;
#   2. gli elementi: la ricerca nei manifest dei moduli e gli spazi di
#      lavoro (prepararli, trovarli, cancellarli);
#   3. i controlli della struttura di tools/check_handson.sh.
# Le tre famiglie stanno in un solo file per scelta registrata: superano
# insieme le ~800 righe, e la divisione naturale (una libreria per
# famiglia) è pronta lungo i titoli di sezione; nessuno stato passa fra
# le famiglie se non HANDSON_ROOT.
#
# Contratto di uscita degli script che la usano:
#   0  esito riprodotto (demo) · tutto in ordine (strumenti)
#   1  ha girato, ma l'esito è diverso da quello registrato · segnalazioni
#   2  precondizione: manca uno strumento, un file, un argomento valido
# Le funzioni della famiglia 1 escono con 2 (handson::die); quelle delle
# famiglie 2 e 3 restituiscono 2 e lasciano decidere il chiamante
# (run_all.sh raccoglie gli esiti di tutti gli elementi).
#
# Variabili d'ambiente, tutte facoltative:
#   PN_HANDSON_ROOT          la radice del repository (default: la
#                            cartella sopra tools/); i test la puntano su
#                            alberi di prova
#   PN_WORKSPACE_ROOT        dove nascono gli spazi di lavoro (default:
#                            ~/corso-claude-code)
#   HANDSON_NO_PAUSE         1 = non aspettare mai Invio
#   HANDSON_SHOW_CMD         0 = non mostrare i comandi prima di eseguirli
#   HANDSON_ENV              l'ambiente dell'elemento, come nel manifest:
#                            claude-code-pro (default), claude-ai-pro,
#                            trainer-api
#   HANDSON_PERMISSION_MODE  la modalità di permesso di handson::claude_p:
#                            dontAsk (default), manual, acceptEdits, plan
#
# Il corso gira su Linux e su Windows con WSL 2; la libreria resta
# compatibile anche con il bash 3.2: niente array associativi né
# readarray, mai "${a[@]}" di un array vuoto.
# =====================================================================

# Una seconda `source` nello stesso processo non ridefinisce niente.
if [[ -n "${HANDSON_LIB_LOADED:-}" ]]; then
  return 0
fi
readonly HANDSON_LIB_LOADED=1

HANDSON_LIB_FILE="$(readlink -f "${BASH_SOURCE[0]}")"
readonly HANDSON_LIB_FILE
readonly HANDSON_TOOLS_DIR="${HANDSON_LIB_FILE%/*}"

HANDSON_NO_PAUSE="${HANDSON_NO_PAUSE:-0}"
HANDSON_SHOW_CMD="${HANDSON_SHOW_CMD:-1}"
HANDSON_ENV="${HANDSON_ENV:-claude-code-pro}"
HANDSON_PERMISSION_MODE="${HANDSON_PERMISSION_MODE:-dontAsk}"

readonly HANDSON_TAB=$'\t'
readonly HANDSON_CR=$'\r'
readonly HANDSON_NL=$'\n'
HANDSON_MANIFEST_HEADER="id${HANDSON_TAB}kind${HANDSON_TAB}env"
HANDSON_MANIFEST_HEADER+="${HANDSON_TAB}section_dir${HANDSON_TAB}subdeck_dir"
HANDSON_MANIFEST_HEADER+="${HANDSON_TAB}deck_path${HANDSON_TAB}minutes"
HANDSON_MANIFEST_HEADER+="${HANDSON_TAB}title_it"
readonly HANDSON_MANIFEST_HEADER
readonly HANDSON_ID_RE='^M([1-9])-([DE])([0-9][0-9])$'
readonly HANDSON_MODULE_RE='^m([1-9])_[a-z0-9]+(_[a-z0-9]+)*$'
readonly HANDSON_SECTION_RE='^s[1-6]_[a-z0-9]+(_[a-z0-9]+)*$'
readonly HANDSON_SUBDECK_RE='^m([1-9])_e?[1-9][0-9]*_[a-z0-9]+(_[a-z0-9]+)*$'
HANDSON_DECK_RE='^slides/(theory|practice)/m[1-9]_[a-z0-9_]+/'
HANDSON_DECK_RE+='(m[1-9]_e?[1-9][0-9]*_[a-z0-9_]+)$'
readonly HANDSON_DECK_RE
readonly HANDSON_PROJECT_RE='^progetti/[a-z0-9]+(-[a-z0-9]+)*$'
HANDSON_ITEM_PATH_RE='^(m[1-9]_[^/]+/([^/]+/)*'
HANDSON_ITEM_PATH_RE+='M[1-9]-[DE][0-9][0-9]_[^/]+)/'
readonly HANDSON_ITEM_PATH_RE
readonly HANDSON_SAFE_TOKEN_RE='^[A-Za-z0-9._/:=@%+,-]+$'
readonly HANDSON_KINDS=' demo esercizio '
readonly HANDSON_ENVS=' claude-code-pro claude-ai-pro trainer-api '
readonly HANDSON_PERMISSION_MODES=' dontAsk manual acceptEdits plan '
readonly HANDSON_SETTING_SOURCES='project,local'
# Il prefisso delle chiavi API, composto qui perché nel file non compaia
# nessuna forma di chiave che uno scanner di segreti segnalerebbe.
readonly HANDSON_KEY_PREFIX="sk-ant""-"
readonly HANDSON_EXPORT_MARK='.copia_partecipanti'
readonly HANDSON_GIT_NAME='Corso Claude Code'
readonly HANDSON_GIT_EMAIL='corso@example.org'
readonly HANDSON_CMD_WIDTH=76
HANDSON_README_SECTIONS=('Obiettivo' 'Tempo' 'Prerequisiti'
  'Punto di partenza' 'Passi in Claude Code' 'Che cosa osservare'
  'Verifica' 'Se qualcosa va storto' "Impronta d'uso sul piano Pro"
  'Per approfondire')
readonly HANDSON_README_SECTIONS

# Colori solo quando STDOUT e STDERR sono un terminale: nei log e nei test
# il testo resta pulito.
if [[ -t 1 && -t 2 ]]; then
  readonly HANDSON_C_DIM=$'\033[2m' HANDSON_C_HI=$'\033[1m'
  readonly HANDSON_C_OK=$'\033[32m' HANDSON_C_ERR=$'\033[31m'
  readonly HANDSON_C_OFF=$'\033[0m'
else
  readonly HANDSON_C_DIM='' HANDSON_C_HI='' HANDSON_C_OK=''
  readonly HANDSON_C_ERR='' HANDSON_C_OFF=''
fi

# Lo stato: contatori, temporanei, l'elemento trovato e lo spazio di
# lavoro. Le HANDSON_ARG_* e HANDSON_ITEM_* le leggono gli strumenti.
HANDSON_KO=0
HANDSON_PRECOND=0
HANDSON_FINDINGS=0
HANDSON_TMP=''
HANDSON_TMPDIRS=()
HANDSON_FIELDS=()
HANDSON_IDS=()
HANDSON_ITEM_DIRS=()
HANDSON_ROOT=''
HANDSON_WORKSPACE_ROOT=''
HANDSON_WORKSPACE=''
HANDSON_ARG_ID=''
HANDSON_ARG_RADICE=''
HANDSON_ARG_SI=0
HANDSON_ITEM_ID=''
HANDSON_ITEM_DIR=''
HANDSON_ITEM_KIND=''
HANDSON_ITEM_ENV=''
HANDSON_ITEM_START=''
HANDSON_MOTIVO=''
HANDSON_DURATA=0
HANDSON_TEMP_BASE=''

# =====================================================================
# 1. Il contratto d'aula
# =====================================================================

# Scrive una diagnostica su STDERR (RU-01.17).
# Arguments: il messaggio, anche in più pezzi (uniti da uno spazio).
handson::err() {
  printf '%s%s%s\n' "${HANDSON_C_ERR}" "$*" "${HANDSON_C_OFF}" >&2
}

# Diagnostica e uscita 2: precondizione non soddisfatta (RU-01.6, .8).
# Arguments: il messaggio, anche in più pezzi.
handson::die() { handson::err "FATALE: $*"; exit 2; }

# Intestazione di una demo.
# Arguments: $1 il codice dell'elemento, $2 il titolo, $3 la collocazione.
handson::banner() {
  printf '\n%s== %s  %s%s\n' "${HANDSON_C_HI}" "$1" "$2" "${HANDSON_C_OFF}"
  printf '%s   %s%s\n\n' "${HANDSON_C_DIM}" "${3:-}" "${HANDSON_C_OFF}"
}

# Etichetta di un passo della demo. Arguments: il testo.
handson::step() {
  printf '\n%s--- %s%s\n' "${HANDSON_C_HI}" "$*" "${HANDSON_C_OFF}"
}

# Nota a margine, su STDERR. Arguments: il testo.
handson::note() {
  printf '%s%s%s\n' "${HANDSON_C_DIM}" "$*" "${HANDSON_C_OFF}" >&2
}

# Aspetta Invio, ma solo se STDIN è un terminale e HANDSON_NO_PAUSE non è
# 1: gli stessi script servono in aula e nelle prove automatiche.
# Arguments: $1 (facoltativo) che cosa succede dopo.
handson::pause() {
  if [[ "${HANDSON_NO_PAUSE}" == "1" || ! -t 0 ]]; then
    return 0
  fi
  printf '%s[Invio per %s]%s ' "${HANDSON_C_DIM}" "${1:-continuare}" \
    "${HANDSON_C_OFF}" >&2
  if ! read -r _; then
    printf '\n' >&2
  fi
}

# Verifica che i comandi richiesti esistano (RU-01.6).
# Arguments: i nomi dei comandi.
handson::need_tools() {
  local t
  for t in "$@"; do
    command -v "${t}" >/dev/null 2>&1 \
      || handson::die "manca lo strumento: ${t}"
  done
}

# Verifica che un file sia leggibile (RU-01.6). Arguments: $1 il percorso.
handson::need_file() {
  [[ -f "$1" && -r "$1" ]] || handson::die "file assente o illeggibile: $1"
}

# Rende un token incollabile in una shell: nudo se fatto solo di caratteri
# innocui, altrimenti fra apici singoli, con l'apice interno reso '\''.
# Arguments: $1 il nome della variabile da assegnare, $2 il token.
handson::quote_into() {
  local __q_sq="'" __q_esc="'\\''"
  if [[ -n "$2" && "$2" =~ ${HANDSON_SAFE_TOKEN_RE} ]]; then
    printf -v "$1" '%s' "$2"
  else
    printf -v "$1" "'%s'" "${2//${__q_sq}/${__q_esc}}"
  fi
}

# Stampa un comando in forma incollabile: su una riga se è corto,
# altrimenti andando a capo prima di ogni opzione lunga (--…). Va chiamata
# con LO STESSO array che poi viene eseguito -- handson::run lo fa -- così
# quello che l'aula legge non può divergere da quello che gira.
# Arguments: il comando, token per token. Outputs: il comando su STDOUT.
handson::show_cmd() {
  (( $# > 0 )) || return 0
  local tok q riga='' i
  local -a pezzi=()
  for tok in "$@"; do
    handson::quote_into q "${tok}"
    pezzi+=("${q}")
    riga+="${riga:+ }${q}"
  done
  if (( ${#riga} <= HANDSON_CMD_WIDTH )); then
    printf '  %s$%s %s\n\n' "${HANDSON_C_DIM}" "${HANDSON_C_OFF}" "${riga}"
    return 0
  fi
  printf '  %s$%s %s' "${HANDSON_C_DIM}" "${HANDSON_C_OFF}" "${pezzi[0]}"
  for (( i = 1; i < ${#pezzi[@]}; i++ )); do
    if [[ "${pezzi[i]}" == --* ]]; then
      printf ' \\\n      %s' "${pezzi[i]}"
    else
      printf ' %s' "${pezzi[i]}"
    fi
  done
  printf '\n\n'
}

# Mostra un comando e poi lo esegue: la riga stampata e il comando
# eseguito sono LO STESSO array, quindi non possono divergere. Su un
# terminale si ferma prima di eseguirlo. HANDSON_SHOW_CMD=0 lo zittisce.
# Arguments: il comando, token per token.
# Outputs: il comando su STDERR, poi l'uscita del comando.
# Returns: il codice d'uscita del comando.
handson::run() {
  if (( $# == 0 )); then
    handson::die "handson::run: nessun comando"
  fi
  if [[ "${HANDSON_SHOW_CMD}" != "0" ]]; then
    handson::show_cmd "$@" >&2
    handson::pause "eseguirlo"
  fi
  "$@"
}

# Verdetto di un controllo dell'esito; un KO viene contato.
# Globals: HANDSON_KO. Arguments: $1 "ok" oppure "ko", $2 il testo.
handson::verdict() {
  if [[ "$1" == "ok" ]]; then
    printf '%sVERIFICA OK%s   %s\n' "${HANDSON_C_OK}" "${HANDSON_C_OFF}" "$2"
  else
    printf '%sVERIFICA KO%s   %s\n' "${HANDSON_C_ERR}" "${HANDSON_C_OFF}" "$2"
    HANDSON_KO=$((HANDSON_KO + 1))
  fi
}

# Il verdetto di un controllo dell'esito dall'uscita che ha dato: 0 OK; 1
# KO (ha girato, ma l'esito è diverso); 2 o più KO e una precondizione
# contata a parte (il controllo non ha potuto girare: una precondizione,
# un comando che manca, un segnale), che fa uscire handson::finish con 2
# (RU-01.8). Il verdetto KO porta l'uscita. La usano handson::check e gli
# script che eseguono il controllo da sé.
# Globals: HANDSON_KO (via handson::verdict), HANDSON_PRECOND.
# Arguments: $1 l'uscita del controllo, $2 la descrizione.
# Returns: 0; un'uscita che non è un numero esce 2.
handson::verdict_rc() {
  [[ "$1" =~ ^[0-9]+$ ]] \
    || handson::die "handson::verdict_rc: «$1» non è un'uscita"
  if (( 10#$1 == 0 )); then
    handson::verdict ok "$2"
    return 0
  fi
  if (( 10#$1 >= 2 )); then
    HANDSON_PRECOND=$((HANDSON_PRECOND + 1))
  fi
  handson::verdict ko "$2 (uscita $1)"
}

# Esegue un controllo deterministico dell'esito (un comando che esce 0 se
# l'esito è quello registrato, 1 se è diverso) e ne stampa il verdetto con
# handson::verdict_rc, senza fermarsi: un'uscita di 2 o più vale come
# precondizione. Su un OK il controllo resta muto. Su un KO stampa prima
# ciò che il controllo ha scritto, ogni canale sul suo (lo STDOUT, dove
# verifica.sh dice che cosa non torna, su STDOUT; lo STDERR su STDERR).
# Le variabili locali hanno il prefisso __c_, perché un controllo che è
# una funzione veda quelle di chi lo chiama.
# Globals: HANDSON_KO, HANDSON_PRECOND (via handson::verdict_rc),
#   HANDSON_TMP (via handson::tmpfile). Arguments: $1 la descrizione, poi
#   il comando del controllo (senza comando esce 2). Outputs: su un KO
#   l'uscita del controllo; il verdetto su STDOUT.
handson::check() {
  (( $# >= 2 )) \
    || handson::die "handson::check: servono la descrizione e il comando" \
      "del controllo"
  local __c_desc="$1" __c_err __c_out __c_rc=0
  shift
  handson::tmpfile __c_err
  __c_out="$("$@" 2> "${__c_err}")" || __c_rc=$?
  if (( __c_rc != 0 )); then
    if [[ -n "${__c_out}" ]]; then
      printf '%s\n' "${__c_out}"
    fi
    if [[ -s "${__c_err}" ]]; then
      cat -- "${__c_err}" >&2
    fi
  fi
  handson::verdict_rc "${__c_rc}" "${__c_desc}"
}

# Chiude una demo: esce 2 se un controllo non ha potuto girare (è uscito
# con 2 o più: una precondizione), 1 se un controllo è andato KO (ha
# girato, ma l'esito è diverso da quello registrato), altrimenti 0.
# Globals: HANDSON_PRECOND, HANDSON_KO.
handson::finish() {
  if (( HANDSON_PRECOND > 0 )); then
    handson::err "FATALE: ${HANDSON_PRECOND} controllo/i dell'esito non" \
      "hanno potuto girare (uscita 2 o più): una precondizione, non un" \
      "esito diverso"
    exit 2
  fi
  if (( HANDSON_KO > 0 )); then
    handson::err "esito diverso da quello registrato:" \
      "${HANDSON_KO} controllo/i KO"
    exit 1
  fi
  exit 0
}

# Verifica che claude sia installato e ne mostra la versione: esegue
# soltanto claude --version, senza nessun prompt.
handson::need_claude() {
  handson::need_tools claude
  local versione
  versione="$(claude --version 2>/dev/null)" \
    || handson::die "claude --version non risponde"
  handson::note "claude ${versione}"
}

# Pretende ANTHROPIC_API_KEY (solo per gli elementi trainer-api, eseguiti
# dal docente). Non stampa mai il valore.
handson::need_api_key() {
  [[ -n "${ANTHROPIC_API_KEY:-}" ]] \
    || handson::die "elemento del docente con l'API:" \
      "ANTHROPIC_API_KEY non è impostata"
}

# Rifiuta un argomento per claude che contiene quella che sembra una
# chiave API: una chiave non va mai sulla riga di comando, nemmeno nel
# prompt, e non viene stampata nemmeno qui.
# Arguments: $1 l'argomento. Returns: 0 se accettato; altrimenti esce 2.
handson::_claude_key_ok() {
  if [[ "$1" == *"${HANDSON_KEY_PREFIX}"* ]]; then
    handson::die "un argomento per claude contiene quella che sembra" \
      "una chiave API: rifiutato (non lo stampo)"
  fi
  return 0
}

# Rifiuta un argomento per claude prima di «--» (il modello, gli
# strumenti, gli argomenti in più) che salterebbe i controlli dei
# permessi, che handson::claude_p imposta da sé («--» compreso), o che
# contiene quella che sembra una chiave API. Il prompt non passa di qui:
# arriva dopo «--», non è mai un'opzione, e passa soltanto
# handson::_claude_key_ok.
# Arguments: $1 l'argomento. Returns: 0 se accettato; altrimenti esce 2.
handson::_claude_arg_ok() {
  handson::_claude_key_ok "$1"
  case "$1" in
    *dangerously*|*bypassPermissions*)
      handson::die "argomento rifiutato: «$1» salta i controlli dei permessi" ;;
    --|-p|--print|--model|--model=*|--output-format*|--permission-mode*)
      handson::die "argomento rifiutato: «$1» lo imposta handson::claude_p" ;;
    --permission-prompt*|--allowedTools*|--allowed-tools*|--setting-sources*)
      handson::die "argomento rifiutato: «$1» lo imposta handson::claude_p" ;;
    --bare)
      [[ "${HANDSON_ENV}" == "trainer-api" ]] \
        || handson::die "argomento rifiutato: --bare non usa l'abbonamento" \
          "e chiede ANTHROPIC_API_KEY" ;;
  esac
  return 0
}

# Esegue Claude Code in modalità non interattiva come lo fanno le demo e
# le esecuzioni dal vivo: `claude -p` con l'elenco esplicito degli
# strumenti consentiti (sintassi delle regole di permesso, per esempio
# 'Read,Edit,Bash(git diff *)'), il modello esplicito, la modalità
# di permesso esplicita (in -p, se nessuno la imposta, si può partire da
# auto), --permission-prompts none (ciò che chiederebbe un permesso viene
# negato e Claude non riprova) e --output-format json (un JSON con
# `result`, l'ID di sessione e i metadati). Mai
# --dangerously-skip-permissions, mai bypassPermissions, mai auto (lì le
# azioni le rivede un classificatore al posto dell'utente): gira solo ciò
# che l'elenco consente.
# Prima tutte le opzioni, poi «--» e per ultimo il prompt: un prompt che
# comincia con «-» (un elenco puntato, per esempio), passato come
# argomento senza «--» davanti, claude lo legge come un'opzione
# sconosciuta ed esce con 1; dopo «--» lo stesso testo è il prompt
# (provato il 2026-10-17 con Claude Code 2.1.302). Così il prompt può
# cominciare con «-» o citare un'opzione: le opzioni vietate si cercano
# soltanto nel modello, negli strumenti e negli argomenti in più, dove
# anche un «--» è rifiutato; nel prompt si cerca soltanto una chiave API.
# Sempre --setting-sources project,local (claude --help 2.1.295: «list of
# setting sources to load (user, project, local)»): regola nostra, perché
# un elemento non dipenda dalle impostazioni personali di chi lo esegue;
# restano quelle dello spazio di lavoro (.claude/settings.json).
# Fuori dagli elementi trainer-api toglie ANTHROPIC_API_KEY dall'ambiente
# del comando: in -p la chiave, se c'è, viene sempre usata al posto
# dell'abbonamento. Non stampa mai un segreto.
# Globals: HANDSON_ENV, HANDSON_PERMISSION_MODE (lette).
# Arguments: $1 il modello (alias o nome completo), $2 gli strumenti
#   consentiti separati da virgole ("" = nessuno), $3 il prompt (non
#   vuoto); gli argomenti seguenti passano a claude così come sono, prima
#   di «--» (per esempio --resume <ID di sessione> per continuare,
#   --effort low).
#   Convenzione nostra per $2, osservata il 2026-10-09 con Claude Code
#   2.1.295 in dontAsk: --allowedTools Edit non ha autorizzato lo strumento
#   Write, --allowedTools Write sì. Un elemento che crea file elenca Write,
#   uno che modifica file esistenti elenca Edit.
# Outputs: il comando su STDERR, il JSON di claude su STDOUT.
# Returns: il codice d'uscita di claude (0 riuscito, altro fallito).
handson::claude_p() {
  (( $# >= 3 )) \
    || handson::die "handson::claude_p: servono modello, strumenti e prompt"
  local modello="$1" strumenti="$2" prompt="$3" arg
  shift 3
  handson::need_tools claude
  handson::_claude_p_checks "${modello}" "${prompt}"
  handson::_claude_key_ok "${prompt}"
  for arg in "${modello}" "${strumenti}" "$@"; do
    handson::_claude_arg_ok "${arg}"
  done
  local -a argv=(claude -p)
  if [[ -n "${strumenti}" ]]; then
    argv+=(--allowedTools "${strumenti}")
  fi
  argv+=(--model "${modello}" --permission-mode "${HANDSON_PERMISSION_MODE}"
    --permission-prompts none --output-format json
    --setting-sources "${HANDSON_SETTING_SOURCES}")
  if (( $# > 0 )); then
    argv+=("$@")
  fi
  argv+=(-- "${prompt}")
  if [[ "${HANDSON_ENV}" == "trainer-api" ]]; then
    handson::run "${argv[@]}"
    return
  fi
  (
    if [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
      handson::note "ANTHROPIC_API_KEY è impostata: la tolgo per questo" \
        "comando, così Claude Code usa l'abbonamento"
    fi
    unset ANTHROPIC_API_KEY
    handson::run "${argv[@]}"
  )
}

# Le precondizioni di handson::claude_p: modello e prompt non vuoti (il
# prompt può cominciare con «-»: arriva dopo «--»), modalità di permesso,
# ambiente; niente Fable fuori dagli elementi trainer-api (sul piano Pro
# gira solo con gli usage credits a pagamento, e in -p l'addebito avviene
# senza conferma).
# Arguments: $1 il modello, $2 il prompt. Returns: 0; altrimenti esce 2.
handson::_claude_p_checks() {
  [[ -n "$1" ]] \
    || handson::die "handson::claude_p: il modello va indicato esplicitamente"
  [[ -n "$2" ]] \
    || handson::die "handson::claude_p: il prompt non può essere vuoto"
  [[ "${HANDSON_PERMISSION_MODES}" == *" ${HANDSON_PERMISSION_MODE} "* ]] \
    || handson::die "modalità di permesso non ammessa:" \
      "«${HANDSON_PERMISSION_MODE}» (ammesse:${HANDSON_PERMISSION_MODES})"
  [[ "${HANDSON_ENVS}" == *" ${HANDSON_ENV} "* ]] \
    || handson::die "HANDSON_ENV non valido: «${HANDSON_ENV}»"
  if [[ "${HANDSON_ENV}" == "trainer-api" ]]; then
    handson::need_api_key
    return 0
  fi
  case "$1" in
    *[Ff][Aa][Bb][Ll][Ee]*)
      handson::die "Fable sul piano Pro funziona solo con gli usage" \
        "credits a pagamento, e in -p l'addebito avviene senza conferma:" \
        "scegli un altro modello" ;;
  esac
}

# Il valore di un campo di primo livello del JSON letto su STDIN (una
# stringa così com'è, il resto come JSON), vuoto se il campo non c'è.
# Arguments: $1 il nome del campo.
handson::json_field() {
  handson::need_tools jq
  jq -r --arg k "$1" 'if type == "object" and has($k)
    then .[$k] | (if type == "string" then . else tojson end)
    else empty end'
}

# I nomi dei campi di primo livello del JSON letto su STDIN, uno per riga.
handson::json_keys() {
  handson::need_tools jq
  jq -r 'keys_unsorted[]'
}

# Fissa, una volta per processo, la cartella in cui nascono i temporanei:
# ${TMPDIR:-/tmp}, salvo che il suo percorso reale sia ~/.claude o stia al
# suo interno. Lì gli spazi di lavoro sono rifiutati
# (handson::init_workspace_root), e i temporanei comprendono gli spazi di
# lavoro usa e getta di run_all.sh e dei test: allora /tmp, con una nota
# su STDERR. mktemp -d vi crea poi cartelle uniche. La usano anche le
# suite di tests/ che creano spazi di lavoro.
# Globals: TMPDIR, HOME (lette); HANDSON_TEMP_BASE (assegnata).
handson::init_temp_base() {
  [[ -z "${HANDSON_TEMP_BASE}" ]] || return 0
  local base="${TMPDIR:-/tmp}" reale config
  HANDSON_TEMP_BASE="${base}"
  [[ "${base}" == /* && "${HOME:-}" == /* ]] || return 0
  reale="$(handson::canonical "${base}")" || return 0
  config="$(handson::canonical "${HOME%/}/.claude")" || return 0
  if [[ "${reale}/" == "${config}/"* ]]; then
    handson::note "TMPDIR (${base}) sta dentro ~/.claude: i file" \
      "temporanei vanno in /tmp"
    HANDSON_TEMP_BASE=/tmp
  fi
}

# Una cartella temporanea che sparisce all'uscita dello script (RU-01.7),
# nella base di handson::init_temp_base.
# Va chiamata fuori da $(…): registra la cartella nella shell corrente.
# Globals: HANDSON_TMPDIRS, HANDSON_TEMP_BASE. Arguments: $1 il nome della
# variabile da assegnare con il percorso.
handson::tmpdir() {
  local __t_d
  handson::init_temp_base
  __t_d="$(mktemp -d "${HANDSON_TEMP_BASE}/handson.XXXXXX")" \
    || handson::die "mktemp non riesce a creare una cartella temporanea"
  HANDSON_TMPDIRS+=("${__t_d}")
  trap handson::cleanup EXIT
  printf -v "$1" '%s' "${__t_d}"
}

# Un file temporaneo nella cartella temporanea del processo.
# Globals: HANDSON_TMP. Arguments: $1 il nome della variabile da assegnare.
handson::tmpfile() {
  if [[ -z "${HANDSON_TMP}" ]]; then
    handson::tmpdir HANDSON_TMP
  fi
  local __t_f
  __t_f="$(mktemp "${HANDSON_TMP}/f.XXXXXX")" \
    || handson::die "mktemp non riesce a creare un file temporaneo"
  printf -v "$1" '%s' "${__t_f}"
}

# Rimuove le cartelle temporanee registrate (agganciata a EXIT da
# handson::tmpdir); mai un percorso vuoto, / o un collegamento simbolico.
# Globals: HANDSON_TMPDIRS.
handson::cleanup() {
  local d
  if (( ${#HANDSON_TMPDIRS[@]} > 0 )); then
    for d in "${HANDSON_TMPDIRS[@]}"; do
      if [[ -n "${d}" && "${d}" != "/" && -d "${d}" && ! -L "${d}" ]]; then
        rm -rf -- "${d}"
      fi
    done
  fi
  return 0
}

# =====================================================================
# 2. Gli elementi e gli spazi di lavoro
# =====================================================================

# Fissa la radice del repository: PN_HANDSON_ROOT oppure la cartella
# sopra tools/, come percorso assoluto senza collegamenti.
# Globals: HANDSON_ROOT (assegnata). Returns: 0; 2 se non c'è.
handson::init_root() {
  local r="${PN_HANDSON_ROOT:-${HANDSON_TOOLS_DIR}/..}"
  if [[ ! -d "${r}" ]]; then
    handson::err "radice del repository non trovata: ${r}"
    return 2
  fi
  HANDSON_ROOT="$(cd "${r}" && pwd -P)" || return 2
}

# Vero se l'albero è la copia per i partecipanti: tools/esporta_studenti.sh
# vi lascia il file segno, e lì soluzione/ e _docente/ non ci sono.
# Globals: HANDSON_ROOT.
handson::is_export() { [[ -f "${HANDSON_ROOT}/${HANDSON_EXPORT_MARK}" ]]; }

# Legge gli argomenti degli strumenti per un elemento:
#   <ID> [--radice <cartella>] [-y|--si]
# Globals: HANDSON_ARG_ID, HANDSON_ARG_RADICE, HANDSON_ARG_SI (assegnate).
# Arguments: $1 "1" se -y/--si è ammesso, poi gli argomenti dello
# strumento. Returns: 0; 2 con un messaggio se gli argomenti non vanno.
# shellcheck disable=SC2034  # le HANDSON_ARG_* le leggono gli strumenti
handson::parse_item_args() {
  local ammette_si="$1"
  shift
  HANDSON_ARG_ID='' HANDSON_ARG_RADICE='' HANDSON_ARG_SI=0
  while (( $# > 0 )); do
    case "$1" in
      --radice)
        if (( $# < 2 )) || [[ -z "$2" ]]; then
          handson::err "--radice vuole una cartella"
          return 2
        fi
        HANDSON_ARG_RADICE="$2"
        shift ;;
      --radice=?*) HANDSON_ARG_RADICE="${1#--radice=}" ;;
      -y|--si)
        if [[ "${ammette_si}" != "1" ]]; then
          handson::err "opzione sconosciuta: $1"
          return 2
        fi
        HANDSON_ARG_SI=1 ;;
      -*) handson::err "opzione sconosciuta: $1"; return 2 ;;
      *)
        if [[ -n "${HANDSON_ARG_ID}" ]]; then
          handson::err "un elemento per volta (ricevuti ${HANDSON_ARG_ID} e $1)"
          return 2
        fi
        HANDSON_ARG_ID="$1" ;;
    esac
    shift
  done
  if [[ -z "${HANDSON_ARG_ID}" ]]; then
    handson::err "manca l'identificativo dell'elemento (per esempio M4-E01)"
    return 2
  fi
}

# Divide una riga TSV nei suoi campi, anche vuoti (read con IFS=tab li
# fonderebbe). Globals: HANDSON_FIELDS (assegnata). Arguments: $1 la riga.
handson::split_tsv() {
  local resto="$1"
  HANDSON_FIELDS=()
  while [[ "${resto}" == *"${HANDSON_TAB}"* ]]; do
    HANDSON_FIELDS+=("${resto%%"${HANDSON_TAB}"*}")
    resto="${resto#*"${HANDSON_TAB}"}"
  done
  HANDSON_FIELDS+=("${resto}")
}

# Vero se il manifest esiste, si legge e ha l'intestazione attesa.
# Arguments: $1 il percorso del manifest.
handson::manifest_header_ok() {
  local prima=''
  [[ -f "$1" && -r "$1" ]] || return 1
  IFS= read -r prima < "$1" || [[ -n "${prima}" ]] || return 1
  [[ "${prima%"${HANDSON_CR}"}" == "${HANDSON_MANIFEST_HEADER}" ]]
}

# La sola cartella m<N>_<nome> del modulo N.
# Globals: HANDSON_ROOT. Arguments: $1 il numero del modulo.
# Outputs: il percorso su STDOUT. Returns: 0; 2 se nessuna o più d'una.
handson::module_dir() {
  local d
  local -a trovate=()
  for d in "${HANDSON_ROOT}/m$1_"*/; do
    if [[ -d "${d}" ]]; then
      trovate+=("${d%/}")
    fi
  done
  if (( ${#trovate[@]} != 1 )); then
    handson::err "modulo $1: attesa una cartella m$1_<nome>," \
      "trovate ${#trovate[@]}"
    return 2
  fi
  printf '%s\n' "${trovate[0]}"
}

# Il problema di una riga di progetti.txt, oppure niente se va bene.
# Globals: HANDSON_ROOT. Arguments: $1 la riga (senza CR).
# Outputs: il problema su STDOUT.
handson::project_problem() {
  if [[ ! "$1" =~ ${HANDSON_PROJECT_RE} ]]; then
    printf 'riga non valida «%s» (attesa progetti/<nome>)' "$1"
  elif [[ ! -d "${HANDSON_ROOT}/$1" || -L "${HANDSON_ROOT}/$1" ]]; then
    printf '%s non esiste' "$1"
  fi
}

# Trova un elemento: la riga del suo id nel manifest del modulo dà
# section_dir e subdeck_dir; la cartella è l'unica <ID>_* lì sotto.
# Globals: HANDSON_ROOT (letta); HANDSON_ITEM_* (assegnate).
# Arguments: $1 l'identificativo (M<N>-D<nn> o M<N>-E<nn>).
# Returns: 0; 2 con un messaggio (id non valido, nessuna riga o più
#   d'una, campi non validi, nessuna cartella o più d'una).
handson::find_item() {
  local id="$1"
  if [[ ! "${id}" =~ ${HANDSON_ID_RE} ]]; then
    handson::err "identificativo non valido: «${id}» (atteso M<N>-D<nn>" \
      "per una demo, M<N>-E<nn> per un esercizio)"
    return 2
  fi
  local n="${BASH_REMATCH[1]}" lettera="${BASH_REMATCH[2]}" mod righe
  mod="$(handson::module_dir "${n}")" || return 2
  if ! handson::manifest_header_ok "${mod}/manifest.tsv"; then
    handson::err "${mod##*/}/manifest.tsv: assente, illeggibile o con" \
      "un'intestazione diversa da quella attesa"
    return 2
  fi
  if ! righe="$(awk -F'\t' -v id="${id}" \
      'NR > 1 { sub(/\r$/, ""); if ($1 == id) print }' \
      "${mod}/manifest.tsv")"; then
    handson::err "non riesco a leggere ${mod##*/}/manifest.tsv"
    return 2
  fi
  handson::_item_from_row "${id}" "${lettera}" "${mod}" "${righe}"
}

# Seconda metà di handson::find_item: controlla la riga e trova la
# cartella. Arguments: $1 id, $2 D o E, $3 la cartella del modulo, $4 le
# righe trovate.
# shellcheck disable=SC2034  # le HANDSON_ITEM_* le leggono gli strumenti
handson::_item_from_row() {
  local id="$1" mod="$3" quale="${3##*/}/manifest.tsv"
  if [[ -z "$4" || "$4" == *"${HANDSON_NL}"* ]]; then
    handson::err "${id}: attesa una riga in ${quale}," \
      "trovate $(printf '%s' "$4" | grep -c .)"
    return 2
  fi
  handson::split_tsv "$4"
  local kind="${HANDSON_FIELDS[1]:-}" env="${HANDSON_FIELDS[2]:-}"
  local sez="${HANDSON_FIELDS[3]:-}" sub="${HANDSON_FIELDS[4]:-}" ok=1
  (( ${#HANDSON_FIELDS[@]} == 8 )) || ok=0
  [[ "${HANDSON_KINDS}" == *" ${kind} "* ]] || ok=0
  [[ "${HANDSON_ENVS}" == *" ${env} "* ]] || ok=0
  [[ "${sez}" =~ ${HANDSON_SECTION_RE} ]] || ok=0
  [[ "${sub}" =~ ${HANDSON_SUBDECK_RE} ]] || ok=0
  [[ "$2" == "D" && "${kind}" == "demo" ]] \
    || [[ "$2" == "E" && "${kind}" == "esercizio" ]] || ok=0
  if (( ok == 0 )); then
    handson::err "${quale}: la riga di ${id} non è valida" \
      "(tools/check_handson.sh dice perché)"
    return 2
  fi
  local d
  local -a cartelle=()
  for d in "${mod}/${sez}/${sub}/${id}_"*/; do
    if [[ -d "${d}" ]]; then
      cartelle+=("${d%/}")
    fi
  done
  if (( ${#cartelle[@]} != 1 )); then
    handson::err "${id}: attesa una cartella" \
      "${mod##*/}/${sez}/${sub}/${id}_<nome>/, trovate ${#cartelle[@]}"
    return 2
  fi
  HANDSON_ITEM_ID="${id}" HANDSON_ITEM_DIR="${cartelle[0]}"
  HANDSON_ITEM_KIND="${kind}" HANDSON_ITEM_ENV="${env}"
  HANDSON_ITEM_START=esercizio
  if [[ "${kind}" == "demo" ]]; then
    HANDSON_ITEM_START=demo
  fi
}

# Elenca, separati da NUL e relativi alla radice, i file che git consegna
# (tracciati e nuovi, non ignorati).
# Globals: HANDSON_ROOT. Arguments: $1 il file d'uscita, poi facoltativi
# i percorsi a cui limitarsi. Returns: 0; 2 se git non riesce.
handson::list_files() {
  local out="$1"
  shift
  if ! git -C "${HANDSON_ROOT}" ls-files -z --cached --others \
      --exclude-standard -- "$@" > "${out}"; then
    handson::err "git non riesce a elencare i file di ${HANDSON_ROOT}:" \
      "è un repository git?"
    return 2
  fi
}

# Copia in $2 i file che git consegna sotto il percorso $1 (relativo alla
# radice), togliendo il prefisso $1 e lasciando fuori soluzione/ e
# _docente/. Un collegamento simbolico è rifiutato; un file cancellato
# nella copia di lavoro non si copia (lo spazio di lavoro rispecchia la
# copia di lavoro). Globals: HANDSON_ROOT. Returns: 0; 2 su ogni errore.
handson::copy_shippable() {
  local prefisso="$1" dest="$2" elenco f rel dir
  handson::tmpfile elenco
  handson::list_files "${elenco}" "${prefisso}" || return 2
  while IFS= read -r -d '' f; do
    rel="${f#"${prefisso}"/}"
    case "/${rel}/" in
      */soluzione/*|*/_docente/*) continue ;;
    esac
    if [[ -L "${HANDSON_ROOT}/${f}" ]]; then
      handson::err "collegamento simbolico non ammesso: ${f}"
      return 2
    fi
    [[ -e "${HANDSON_ROOT}/${f}" ]] || continue
    dir="${rel%/*}"
    if [[ "${dir}" != "${rel}" ]]; then
      mkdir -p -- "${dest}/${dir}" || return 2
    fi
    cp -p -- "${HANDSON_ROOT}/${f}" "${dest}/${rel}" || return 2
  done < "${elenco}"
}

# Copia nello spazio di lavoro i progetti condivisi che l'elemento elenca
# in progetti.txt (una riga progetti/<nome>; righe vuote e # ignorate),
# con lo stesso percorso: <spazio>/progetti/<nome>/.
# Globals: HANDSON_ITEM_DIR, HANDSON_ITEM_ID. Arguments: $1 lo spazio di
# lavoro. Returns: 0; 2 su una riga non valida o una copia fallita.
handson::copy_projects() {
  local ws="$1" elenco="${HANDSON_ITEM_DIR}/progetti.txt" riga problema
  [[ -e "${elenco}" ]] || return 0
  while IFS= read -r riga || [[ -n "${riga}" ]]; do
    riga="${riga%"${HANDSON_CR}"}"
    case "${riga}" in ''|'#'*) continue ;; esac
    problema="$(handson::project_problem "${riga}")"
    if [[ -n "${problema}" ]]; then
      handson::err "progetti.txt di ${HANDSON_ITEM_ID}: ${problema}"
      return 2
    fi
    mkdir -p -- "${ws}/${riga}" || return 2
    handson::copy_shippable "${riga}" "${ws}/${riga}" || return 2
  done < "${elenco}"
}

# Il percorso canonico di una cartella che può non esistere ancora:
# canonico l'antenato più vicino che esiste, poi il resto così com'è.
# Arguments: $1 un percorso assoluto. Outputs: il percorso su STDOUT.
handson::canonical() {
  local p="$1" resto='' base
  [[ "${p}" == /* ]] || return 2
  while [[ ! -d "${p}" ]]; do
    resto="/${p##*/}${resto}"
    p="${p%/*}"
    [[ -n "${p}" ]] || p='/'
  done
  base="$(cd "${p}" && pwd -P)" || return 2
  printf '%s%s\n' "${base%/}" "${resto}"
}

# Fissa la radice degli spazi di lavoro: --radice, oppure
# PN_WORKSPACE_ROOT, oppure ~/corso-claude-code. Percorso assoluto, senza
# componenti . o .., diverso da /, fuori dal repository (RU-01.S4) e mai
# ~/.claude né dentro ~/.claude, confrontando i percorsi reali (anche
# attraverso un collegamento simbolico). Osservato il 2026-10-09 con
# Claude Code 2.1.295: con lo spazio di lavoro sotto ~/.claude, in dontAsk,
# anche un Write consentito è stato negato; in /tmp no.
# Globals: HANDSON_ROOT, HOME (lette), HANDSON_WORKSPACE_ROOT (assegnata,
# canonica). Arguments: $1 il valore di --radice ("" se assente).
# Returns: 0; 2 con un messaggio.
handson::init_workspace_root() {
  local r="${1:-${PN_WORKSPACE_ROOT:-}}"
  if [[ -z "${r}" ]]; then
    if [[ -z "${HOME:-}" ]]; then
      handson::err "HOME non è impostata: indica la cartella con --radice"
      return 2
    fi
    r="${HOME}/corso-claude-code"
  fi
  while [[ "${r}" == */ && "${r}" != "/" ]]; do
    r="${r%/}"
  done
  if [[ "${r}" != /* || "${r}" == "/" || "${r}/" == */./* \
      || "${r}/" == */../* ]]; then
    handson::err "radice degli spazi di lavoro non ammessa: «${r}»" \
      "(serve un percorso assoluto, diverso da /, senza . né ..)"
    return 2
  fi
  HANDSON_WORKSPACE_ROOT="$(handson::canonical "${r}")" || return 2
  if [[ "${HANDSON_WORKSPACE_ROOT}/" == "${HANDSON_ROOT}/"* ]]; then
    handson::err "gli spazi di lavoro non stanno dentro il repository:" \
      "${HANDSON_WORKSPACE_ROOT}"
    return 2
  fi
  local config
  [[ "${HOME:-}" == /* ]] || return 0
  config="$(handson::canonical "${HOME%/}/.claude")" || return 2
  if [[ "${HANDSON_WORKSPACE_ROOT}/" == "${config}/"* ]]; then
    handson::err "la radice degli spazi di lavoro non può essere ~/.claude" \
      "né stare al suo interno: ${HANDSON_WORKSPACE_ROOT}; scegline" \
      "un'altra con --radice"
    return 2
  fi
}

# Apre lo spazio di lavoro come repository git con un primo commit, così
# `git diff` mostra che cosa è cambiato; il segno corso.elemento nella
# configurazione locale permette a reset_esercizio.sh di riconoscerlo.
# Arguments: $1 lo spazio di lavoro, $2 l'identificativo. Returns: 0; 2.
handson::git_init_workspace() {
  local ws="$1" id="$2"
  git -c init.defaultBranch=main -C "${ws}" init -q || return 2
  git -C "${ws}" symbolic-ref HEAD refs/heads/main || return 2
  git -C "${ws}" config corso.elemento "${id}" || return 2
  git -C "${ws}" add -A || return 2
  git -C "${ws}" -c user.name="${HANDSON_GIT_NAME}" \
    -c user.email="${HANDSON_GIT_EMAIL}" -c commit.gpgsign=false \
    commit -q --no-verify --allow-empty -m "Punto di partenza di ${id}" \
    || return 2
}

# Prepara lo spazio di lavoro dell'elemento già trovato: i progetti di
# progetti.txt, poi esercizio/ o demo/ (che possono sovrascriverne un
# file), le impostazioni prudenti di .claude/settings.json se l'elemento
# non porta una sua .claude/, infine git. Mai soluzione/ né _docente/.
# Globals: HANDSON_ROOT, HANDSON_ITEM_*, HANDSON_WORKSPACE_ROOT (lette);
#   HANDSON_WORKSPACE (assegnata).
# Returns: 0; 2 con un messaggio (e nessuno spazio di lavoro a metà).
handson::prepare_workspace() {
  local id="${HANDSON_ITEM_ID}"
  local partenza="${HANDSON_ITEM_DIR}/${HANDSON_ITEM_START}"
  local ws="${HANDSON_WORKSPACE_ROOT}/${id}"
  if [[ -z "${id}" || ! -d "${partenza}" ]]; then
    handson::err "${id}: manca il punto di partenza" \
      "${partenza#"${HANDSON_ROOT}"/}/"
    return 2
  fi
  if [[ -e "${ws}" || -L "${ws}" ]]; then
    handson::err "lo spazio di lavoro esiste già: ${ws}"
    handson::err "per ricominciare da capo: tools/reset_esercizio.sh ${id}"
    return 2
  fi
  if ! mkdir -p -- "${HANDSON_WORKSPACE_ROOT}" || ! mkdir -- "${ws}"; then
    handson::err "non riesco a creare ${ws}"
    return 2
  fi
  # ws è <radice canonica>/<id valido>, appena creata qui: la cancellazione
  # in caso di errore non può uscire da lì.
  if ! handson::_fill_workspace "${ws}" "${partenza}"; then
    rm -rf -- "${ws}"
    return 2
  fi
  HANDSON_WORKSPACE="${ws}"
}

# Riempie uno spazio di lavoro appena creato (handson::prepare_workspace).
# Arguments: $1 lo spazio di lavoro, $2 la cartella di partenza.
handson::_fill_workspace() {
  local ws="$1" partenza="$2"
  handson::copy_projects "${ws}" || return 2
  handson::copy_shippable "${partenza#"${HANDSON_ROOT}"/}" "${ws}" \
    || return 2
  if [[ ! -e "${ws}/.claude" ]]; then
    if ! mkdir -- "${ws}/.claude" || ! cp -p -- \
        "${HANDSON_ROOT}/.claude/settings.json" "${ws}/.claude/settings.json"
    then
      handson::err "non riesco a copiare .claude/settings.json in ${ws}"
      return 2
    fi
  fi
  if ! handson::git_init_workspace "${ws}" "${HANDSON_ITEM_ID}"; then
    handson::err "git non riesce ad aprire lo spazio di lavoro ${ws}"
    return 2
  fi
}

# Lo spazio di lavoro esistente dell'elemento trovato.
# Globals: HANDSON_WORKSPACE_ROOT, HANDSON_ITEM_ID (lette);
#   HANDSON_WORKSPACE (assegnata). Returns: 0; 2 se non c'è.
handson::find_workspace() {
  HANDSON_WORKSPACE="${HANDSON_WORKSPACE_ROOT}/${HANDSON_ITEM_ID}"
  if [[ ! -d "${HANDSON_WORKSPACE}" ]]; then
    handson::err "lo spazio di lavoro di ${HANDSON_ITEM_ID} non c'è:" \
      "${HANDSON_WORKSPACE}"
    handson::err "preparalo con: tools/prepara_esercizio.sh ${HANDSON_ITEM_ID}"
    return 2
  fi
}

# I controlli prima di cancellare uno spazio di lavoro (RU-01.S5): il
# percorso non è vuoto né /, non è un collegamento simbolico, è proprio
# <radice>/<ID> e porta il segno che vi lascia prepara_esercizio.sh.
# Globals: HANDSON_WORKSPACE_ROOT (letta).
# Arguments: $1 lo spazio di lavoro, $2 l'identificativo.
# Returns: 0 se si può cancellare; 2 con un messaggio.
handson::guard_workspace() {
  local ws="$1" id="$2" reale segno
  if [[ -z "${ws}" || "${ws}" == "/" || -z "${id}" ]]; then
    handson::err "percorso vuoto o /: non cancello niente"
    return 2
  fi
  if [[ -L "${ws}" || ! -d "${ws}" ]]; then
    handson::err "non cancello ${ws}:" \
      "è un collegamento simbolico o non è una cartella"
    return 2
  fi
  reale="$(cd "${ws}" && pwd -P)" || return 2
  if [[ "${reale}" != "${HANDSON_WORKSPACE_ROOT}/${id}" \
      || "${reale}" == "${HOME:-/}" ]]; then
    handson::err "non cancello ${ws}: non è ${HANDSON_WORKSPACE_ROOT}/${id}"
    return 2
  fi
  if [[ ! -d "${reale}/.git" ]] || ! segno="$(git \
      --git-dir="${reale}/.git" config --get corso.elemento)"; then
    handson::err "non cancello ${ws}: non è uno spazio di lavoro" \
      "preparato da prepara_esercizio.sh"
    return 2
  fi
  if [[ "${segno}" != "${id}" ]]; then
    handson::err "non cancello ${ws}: è lo spazio di lavoro di ${segno}," \
      "non di ${id}"
    return 2
  fi
}

# --- Le prove degli elementi (tools/run_all.sh) -------------------------

# Gli ID di tutti i manifest, modulo per modulo, nell'ordine delle righe.
# Globals: HANDSON_IDS (vi aggiunge).
# Returns: 0; 2 se un modulo o un manifest non va.
handson::collect_ids() {
  local n mod elenco id
  handson::tmpfile elenco
  for n in 1 2 3 4 5 6 7 8 9; do
    mod="$(handson::module_dir "${n}")" || return 2
    if ! handson::manifest_header_ok "${mod}/manifest.tsv"; then
      handson::err "${mod##*/}/manifest.tsv: assente, illeggibile o con" \
        "un'intestazione diversa da quella attesa"
      return 2
    fi
    awk -F'\t' 'NR > 1 { sub(/\r$/, ""); if ($1 != "") print $1 }' \
      "${mod}/manifest.tsv" > "${elenco}" || return 2
    while IFS= read -r id; do
      HANDSON_IDS+=("${id}")
    done < "${elenco}"
  done
}

# Applica soluzione/ a uno spazio di lavoro: soluzione/applica.sh
# <spazio> se c'è, altrimenti i suoi file copiati sopra quelli dello
# spazio di lavoro. Arguments: $1 la cartella dell'elemento, $2 lo spazio.
handson::apply_solution() {
  local sol="$1/soluzione"
  if [[ ! -d "${sol}" ]]; then
    echo "manca soluzione/"
    return 1
  fi
  if [[ -f "${sol}/applica.sh" ]]; then
    ( cd "$2" && PN_HANDSON_ROOT="${HANDSON_ROOT}" "${sol}/applica.sh" "$2" )
    return
  fi
  cp -R "${sol}/." "$2/"
}

# I passi 1 e 2 di run_all.sh: in uno spazio di lavoro usa e getta,
# verifica.sh esce 1 sul punto di partenza intatto e 0 con soluzione/.
# Globals: HANDSON_MOTIVO (assegnata). Arguments: $1 id, $2 la cartella
# dell'elemento, $3 il log. Returns: 0 ok; 1 KO; 3 passo 2 saltato (copia
# per i partecipanti, senza soluzione/).
handson::prove_solution() {
  local id="$1" t="${HANDSON_TOOLS_DIR}" radice rc
  handson::tmpdir radice
  if ! "${t}/prepara_esercizio.sh" "${id}" --radice "${radice}" > "$3" 2>&1
  then
    HANDSON_MOTIVO="prepara_esercizio.sh non riesce"
    return 1
  fi
  "${t}/verifica.sh" "${id}" --radice "${radice}" > "$3" 2>&1
  rc=$?
  if (( rc != 1 )); then
    HANDSON_MOTIVO="sul punto di partenza intatto verifica.sh esce ${rc},"
    HANDSON_MOTIVO+=" non 1"
    return 1
  fi
  if handson::is_export; then
    return 3
  fi
  if ! handson::apply_solution "$2" "${radice}/${id}" > "$3" 2>&1; then
    HANDSON_MOTIVO="soluzione/ non si applica"
    return 1
  fi
  "${t}/verifica.sh" "${id}" --radice "${radice}" > "$3" 2>&1
  rc=$?
  if (( rc != 0 )); then
    HANDSON_MOTIVO="con soluzione/ applicata verifica.sh esce ${rc}, non 0"
    return 1
  fi
}

# Il passo 3 di run_all.sh: in uno spazio di lavoro nuovo
# _docente/live.sh <spazio> esce 0, poi verifica.sh esce 0. Agli elementi
# non trainer-api arriva un ambiente senza ANTHROPIC_API_KEY; con
# PN_LIVE_LOGS l'uscita di live.sh resta in <PN_LIVE_LOGS>/<ID>.log.
# Globals: HANDSON_MOTIVO, HANDSON_DURATA (assegnate). Arguments: $1 id,
# $2 la cartella dell'elemento, $3 env, $4 il log.
# Returns: 0 ok; 1 KO; 3 SKIP (nessun live.sh, trainer-api senza chiave).
# shellcheck disable=SC2034  # HANDSON_DURATA la legge run_all.sh
handson::prove_live() {
  local id="$1" live="$2/_docente/live.sh" t="${HANDSON_TOOLS_DIR}"
  local radice rc inizio
  HANDSON_MOTIVO="nessun _docente/live.sh"
  [[ -f "${live}" ]] || return 3
  HANDSON_MOTIVO="elemento trainer-api e ANTHROPIC_API_KEY non è impostata"
  [[ "$3" != "trainer-api" || -n "${ANTHROPIC_API_KEY:-}" ]] || return 3
  handson::tmpdir radice
  HANDSON_MOTIVO="prepara_esercizio.sh non riesce"
  "${t}/prepara_esercizio.sh" "${id}" --radice "${radice}" > "$4" 2>&1 \
    || return 1
  inizio="${SECONDS}"
  if [[ "$3" == "trainer-api" ]]; then
    ( cd "${radice}/${id}" && "${live}" "${radice}/${id}" ) > "$4" 2>&1
  else
    ( cd "${radice}/${id}" && unset ANTHROPIC_API_KEY \
      && "${live}" "${radice}/${id}" ) > "$4" 2>&1
  fi
  rc=$?
  HANDSON_DURATA=$((SECONDS - inizio))
  HANDSON_MOTIVO="non riesco a scrivere ${PN_LIVE_LOGS:-}/${id}.log"
  if [[ -n "${PN_LIVE_LOGS:-}" ]]; then
    cp -- "$4" "${PN_LIVE_LOGS}/${id}.log" || return 1
  fi
  HANDSON_MOTIVO="_docente/live.sh esce ${rc}"
  (( rc == 0 )) || return 1
  "${t}/verifica.sh" "${id}" --radice "${radice}" > "$4" 2>&1
  rc=$?
  HANDSON_MOTIVO="dopo _docente/live.sh verifica.sh esce ${rc}, non 0"
  (( rc == 0 )) || return 1
}

# =====================================================================
# 3. I controlli della struttura (tools/check_handson.sh)
# =====================================================================

# Registra una segnalazione. Globals: HANDSON_FINDINGS.
# Arguments: $1 il percorso relativo alla radice, poi il motivo (anche in
# più pezzi).
handson::finding() {
  local dove="$1"
  shift
  printf '  KO  %s: %s\n' "${dove}" "$*"
  HANDSON_FINDINGS=$((HANDSON_FINDINGS + 1))
}

# I file e le cartelle della radice, e le regole di esportazione.
# Globals: HANDSON_ROOT.
handson::check_layout() {
  local p regola
  for p in README.md PRIMA_DEL_CORSO.md CLAUDE.md .gitattributes \
      .gitignore .claude/settings.json progetti/README.md \
      riferimenti/README.md; do
    [[ -f "${HANDSON_ROOT}/${p}" ]] || handson::finding "${p}" "file mancante"
  done
  for p in progetti/gestionale-php progetti/rete progetti/assistenza-clienti \
      riferimenti tools tests; do
    [[ -d "${HANDSON_ROOT}/${p}" ]] \
      || handson::finding "${p}/" "cartella mancante"
  done
  [[ -f "${HANDSON_ROOT}/.gitattributes" ]] || return 0
  for regola in '**/soluzione export-ignore' '**/soluzione/** export-ignore' \
      '**/_docente export-ignore' '**/_docente/** export-ignore'; do
    grep -qxF -- "${regola}" "${HANDSON_ROOT}/.gitattributes" \
      || handson::finding ".gitattributes" "manca la regola «${regola}»"
  done
}

# Un modulo: la sola cartella m<N>_<nome>, il README, il manifest e ogni
# sua riga. Globals: HANDSON_ROOT. Arguments: $1 il numero del modulo.
handson::check_module() {
  local n="$1" d riga numero=0
  local -a cartelle=()
  for d in "${HANDSON_ROOT}/m${n}_"*/; do
    if [[ -d "${d}" ]]; then
      cartelle+=("${d%/}")
    fi
  done
  if (( ${#cartelle[@]} != 1 )); then
    handson::finding "m${n}_*/" "attesa una cartella per il modulo ${n}," \
      "trovate ${#cartelle[@]}"
    return 0
  fi
  local mod="${cartelle[0]}" nome="${cartelle[0]##*/}"
  [[ "${nome}" =~ ${HANDSON_MODULE_RE} ]] \
    || handson::finding "${nome}/" "nome non valido (m<N>_<parole_minuscole>)"
  [[ -f "${mod}/README.md" ]] \
    || handson::finding "${nome}/README.md" "file mancante"
  if ! handson::manifest_header_ok "${mod}/manifest.tsv"; then
    handson::finding "${nome}/manifest.tsv" "assente, illeggibile o senza" \
      "l'intestazione «id kind env section_dir subdeck_dir deck_path" \
      "minutes title_it» separata da tabulazioni"
    return 0
  fi
  while IFS= read -r riga || [[ -n "${riga}" ]]; do
    numero=$((numero + 1))
    riga="${riga%"${HANDSON_CR}"}"
    if (( numero > 1 )) && [[ -n "${riga}" ]]; then
      handson::check_row "${mod}" "${n}" "${nome}/manifest.tsv:${numero}" \
        "${riga}"
    fi
  done < "${mod}/manifest.tsv"
}

# I campi di una riga del manifest; se sono validi, l'elemento che nomina.
# Globals: HANDSON_FIELDS. Arguments: $1 la cartella del modulo, $2 il suo
# numero, $3 dove (file:riga), $4 la riga.
handson::check_row() {
  local dove="$3" prima="${HANDSON_FINDINGS}"
  handson::split_tsv "$4"
  if (( ${#HANDSON_FIELDS[@]} != 8 )); then
    handson::finding "${dove}" "${#HANDSON_FIELDS[@]} campi invece di 8"
    return 0
  fi
  local id="${HANDSON_FIELDS[0]}" kind="${HANDSON_FIELDS[1]}"
  local env="${HANDSON_FIELDS[2]}" sez="${HANDSON_FIELDS[3]}"
  local sub="${HANDSON_FIELDS[4]}" deck="${HANDSON_FIELDS[5]}"
  local minuti="${HANDSON_FIELDS[6]}" titolo="${HANDSON_FIELDS[7]}"
  handson::check_row_id "${dove}" "$2" "${id}" "${kind}"
  [[ "${HANDSON_ENVS}" == *" ${env} "* ]] \
    || handson::finding "${dove}" "env «${env}» non valido" \
      "(claude-code-pro, claude-ai-pro, trainer-api)"
  [[ "${sez}" =~ ${HANDSON_SECTION_RE} ]] \
    || handson::finding "${dove}" "section_dir «${sez}» non valido" \
      "(atteso s<sessione>_<parole>)"
  if [[ ! "${sub}" =~ ${HANDSON_SUBDECK_RE} || "${BASH_REMATCH[1]}" != "$2" ]]
  then
    handson::finding "${dove}" "subdeck_dir «${sub}» non valido" \
      "(atteso m$2_<k>_<parole> o m$2_e<k>_<parole>)"
  fi
  if [[ ! "${deck}" =~ ${HANDSON_DECK_RE} || "${BASH_REMATCH[2]}" != "${sub}" ]]
  then
    handson::finding "${dove}" "deck_path «${deck}» non valido" \
      "(atteso slides/theory|practice/<deck>/${sub})"
  fi
  [[ "${minuti}" =~ ^[1-9][0-9]*$ ]] \
    || handson::finding "${dove}" "minutes «${minuti}» non è un intero positivo"
  [[ -n "${titolo}" ]] || handson::finding "${dove}" "title_it vuoto"
  if (( HANDSON_FINDINGS == prima )); then
    handson::check_row_dirs "$1" "${dove}" "${id}" "${kind}" "${sez}" "${sub}"
  fi
}

# L'id di una riga e la sua coerenza con il modulo e con kind.
# Globals: HANDSON_IDS. Arguments: $1 dove, $2 il numero del modulo,
# $3 id, $4 kind.
handson::check_row_id() {
  if [[ ! "$3" =~ ${HANDSON_ID_RE} ]]; then
    handson::finding "$1" "id «$3» non valido (M<N>-D<nn> o M<N>-E<nn>)"
    return 0
  fi
  local n="${BASH_REMATCH[1]}" lettera="${BASH_REMATCH[2]}"
  HANDSON_IDS+=("$3")
  [[ "${n}" == "$2" ]] \
    || handson::finding "$1" "$3 appartiene al modulo ${n}, non al $2"
  if [[ "${HANDSON_KINDS}" != *" $4 "* ]]; then
    handson::finding "$1" "kind «$4» non valido (demo o esercizio)"
  elif [[ "${lettera}" == "D" && "$4" != "demo" ]] \
      || [[ "${lettera}" == "E" && "$4" != "esercizio" ]]; then
    handson::finding "$1" "kind «$4» non corrisponde a $3" \
      "(D = demo, E = esercizio)"
  fi
}

# Le cartelle che una riga nomina e l'elemento che vi sta.
# Globals: HANDSON_ROOT, HANDSON_ITEM_DIRS. Arguments: $1 la cartella del
# modulo, $2 dove, $3 id, $4 kind, $5 section_dir, $6 subdeck_dir.
handson::check_row_dirs() {
  local base="$1/$5/$6" id="$3" d rel
  local nome_re="^${id}_[a-z0-9]+(_[a-z0-9]+)*\$"
  local -a cartelle=()
  if [[ ! -d "${base}" ]]; then
    handson::finding "$2" "la cartella ${base#"${HANDSON_ROOT}"/}/ non esiste"
    return 0
  fi
  for d in "${base}/${id}_"*/; do
    if [[ -d "${d}" ]]; then
      cartelle+=("${d%/}")
    fi
  done
  if (( ${#cartelle[@]} != 1 )); then
    handson::finding "$2" "attesa una cartella" \
      "${base#"${HANDSON_ROOT}"/}/${id}_<nome>/, trovate ${#cartelle[@]}"
    return 0
  fi
  rel="${cartelle[0]#"${HANDSON_ROOT}"/}"
  HANDSON_ITEM_DIRS+=("${rel}")
  [[ "${rel##*/}" =~ ${nome_re} ]] \
    || handson::finding "${rel}/" "nome non valido (${id}_<parole_minuscole>)"
  handson::check_item "${cartelle[0]}" "${rel}" "$4"
}

# Il contenuto di un elemento: README con le dieci sezioni, verifica.sh
# eseguibile, il punto di partenza giusto per kind, soluzione/ (non nella
# copia per i partecipanti), progetti.txt valido.
# Arguments: $1 la cartella, $2 la stessa relativa alla radice, $3 kind.
handson::check_item() {
  local item="$1" rel="$2" partenza=esercizio riga problema
  [[ "$3" != "demo" ]] || partenza=demo
  handson::check_readme "${item}/README.md" "${rel}/README.md"
  if [[ ! -f "${item}/verifica.sh" ]]; then
    handson::finding "${rel}/verifica.sh" "mancante"
  elif [[ ! -x "${item}/verifica.sh" ]]; then
    handson::finding "${rel}/verifica.sh" "senza il bit di esecuzione"
  fi
  [[ -d "${item}/${partenza}" ]] \
    || handson::finding "${rel}/${partenza}/" "mancante: è il punto di" \
      "partenza di un elemento «$3»"
  if ! handson::is_export && [[ ! -d "${item}/soluzione" ]]; then
    handson::finding "${rel}/soluzione/" "mancante"
  fi
  [[ -e "${item}/progetti.txt" ]] || return 0
  while IFS= read -r riga || [[ -n "${riga}" ]]; do
    riga="${riga%"${HANDSON_CR}"}"
    case "${riga}" in ''|'#'*) continue ;; esac
    problema="$(handson::project_problem "${riga}")"
    [[ -z "${problema}" ]] \
      || handson::finding "${rel}/progetti.txt" "${problema}"
  done < "${item}/progetti.txt"
}

# Le dieci sezioni del README di un elemento, come titoli «## …»; un
# titolo può proseguire dopo il nome («## Verifica (tools/verifica.sh)»).
# Arguments: $1 il file, $2 lo stesso relativo alla radice.
handson::check_readme() {
  local sezione pat ap="'" alt="(’|')"
  if [[ ! -f "$1" ]]; then
    handson::finding "$2" "mancante"
    return 0
  fi
  for sezione in "${HANDSON_README_SECTIONS[@]}"; do
    pat="${sezione//${ap}/${alt}}"
    grep -Eq -- "^##[[:space:]]+${pat}([^[:alnum:]_]|\$)" "$1" \
      || handson::finding "$2" "manca la sezione «## ${sezione}»"
  done
}

# Gli id ripetuti fra tutti i manifest. Globals: HANDSON_IDS.
# Returns: 0; 2 se il confronto non riesce.
handson::check_unique_ids() {
  (( ${#HANDSON_IDS[@]} > 0 )) || return 0
  local doppi dup
  handson::tmpfile doppi
  printf '%s\n' "${HANDSON_IDS[@]}" | LC_ALL=C sort | uniq -d > "${doppi}" \
    || return 2
  while IFS= read -r dup; do
    handson::finding "m*/manifest.tsv" "l'id ${dup} compare più di una volta"
  done < "${doppi}"
}

# Le cartelle di elementi che nessun manifest nomina, a qualunque
# profondità sotto un modulo. Globals: HANDSON_ITEM_DIRS.
# Arguments: $1 l'elenco dei file (NUL) di handson::list_files.
handson::check_orphans() {
  local f cartella vista nota
  local -a viste=()
  while IFS= read -r -d '' f; do
    [[ "${f}" =~ ${HANDSON_ITEM_PATH_RE} ]] || continue
    cartella="${BASH_REMATCH[1]}"
    for vista in ${viste[@]+"${viste[@]}"}; do
      [[ "${vista}" != "${cartella}" ]] || continue 2
    done
    viste+=("${cartella}")
    for nota in ${HANDSON_ITEM_DIRS[@]+"${HANDSON_ITEM_DIRS[@]}"}; do
      [[ "${nota}" != "${cartella}" ]] || continue 2
    done
    handson::finding "${cartella}/" "nessun manifest nomina questo" \
      "elemento (o la sua riga non è valida)"
  done < "$1"
}

# Gli script eseguibili e le librerie no, fuori dagli alberi di prova e
# dai contenuti degli elementi (esercizio/, demo/, soluzione/: lì uno
# script può essere materia dell'esercizio).
# Arguments: $1 l'elenco dei file (NUL) di handson::list_files.
handson::check_scripts() {
  local f
  while IFS= read -r -d '' f; do
    [[ "${f}" == *.sh && -e "${HANDSON_ROOT}/${f}" ]] || continue
    case "/${f}" in
      /tests/fixtures/*|*/esercizio/*|*/demo/*|*/soluzione/*) continue ;;
    esac
    case "${f##*/}" in
      lib_*.sh)
        [[ ! -x "${HANDSON_ROOT}/${f}" ]] \
          || handson::finding "${f}" "libreria con il bit di esecuzione:" \
            "si usa solo con source (chmod -x)" ;;
      *)
        [[ -x "${HANDSON_ROOT}/${f}" ]] \
          || handson::finding "${f}" "script senza il bit di esecuzione" \
            "(chmod +x)" ;;
    esac
  done < "$1"
}

# Elenca le cartelle soluzione/ e _docente/ di un albero, fuori dagli
# alberi di prova dei test: nella copia per i partecipanti non devono
# esserci. Arguments: $1 la radice dell'albero, $2 il file d'uscita (una
# per riga, relative alla radice). Returns: 0; 2 se find non riesce.
handson::trainer_dirs() {
  local d trovate
  handson::tmpfile trovate
  find "$1" -name .git -prune -o -type d \
    \( -name soluzione -o -name _docente \) -print > "${trovate}" || return 2
  : > "$2"
  while IFS= read -r d; do
    d="${d#"$1"/}"
    case "${d}" in tests/fixtures/*) continue ;; esac
    printf '%s\n' "${d}" >> "$2"
  done < "${trovate}"
}
