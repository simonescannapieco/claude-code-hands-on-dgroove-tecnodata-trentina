# shellcheck shell=bash
# =====================================================================
# lib_stop.sh -- di _docente/live.sh di M4-D05: gli argomenti, le
# precondizioni della coppia, le chiamate claude -p in stream-json e la
# verifica a schermo
# ---------------------------------------------------------------------
# Libreria: si fa SOURCE dopo tools/lib_handson.sh; non si esegue.
#
# stop::leggi_argomenti legge --esecuzioni N e lo spazio di lavoro.
# stop::al_punto_di_partenza vuole uno spazio di lavoro che sia la cima di
# un repository git con git status vuoto: ogni copia parte dal progetto
# del primo commit. stop::uguali_tolto_hook vuole le impostazioni dei due
# bracci uguali una volta tolta la chiave hooks, come le vuole il
# controllo, e stop::mostra_differenza mostra con diff la sola differenza,
# lo Stop hook. handson::claude_p scrive sempre --output-format json, e
# qui serve lo stream-json: solo lì si vedono i blocchi dell'hook.
# stop::chiedi compone quindi la stessa riga con --output-format
# stream-json --verbose, dopo gli stessi controlli della libreria e senza
# ANTHROPIC_API_KEY nell'ambiente; la riga si vede prima di girare
# (handson::run). stop::fallita chiude con un KO; stop::verifica_a_schermo
# fa vedere i dati e i verdetti anche quando la verifica passa.
#
# Globals (lette): MODELLO, STRUMENTI, OPZIONI, CONTROLLO, di live.sh;
#   HANDSON_ENV, HANDSON_PERMISSION_MODE, HANDSON_SETTING_SOURCES, di
#   tools/lib_handson.sh; (assegnate) ESECUZIONI, SPAZIO, di live.sh.
# =====================================================================

stop::usage() {
  echo "Uso: _docente/live.sh [--esecuzioni N] <spazio di lavoro>" >&2
}

#######################################
# Legge gli argomenti. Globals: ESECUZIONI, SPAZIO (assegnate).
# Arguments: quelli dello script. Returns: 0; esce 2 se non vanno.
#######################################
stop::leggi_argomenti() {
  local n=''
  while (( $# > 0 )); do
    case "$1" in
      --esecuzioni|-n)
        (( $# >= 2 )) || { stop::usage; handson::die "--esecuzioni vuole N"; }
        n="$2"
        shift ;;
      --esecuzioni=*) n="${1#--esecuzioni=}" ;;
      -*) stop::usage; handson::die "opzione sconosciuta: $1" ;;
      *)
        [[ -z "${SPAZIO}" ]] \
          || handson::die "uno spazio di lavoro per volta"
        SPAZIO="$1" ;;
    esac
    shift
  done
  if [[ -n "${n}" ]]; then
    [[ "${n}" =~ ^[1-9]$ ]] \
      || handson::die "--esecuzioni vuole un numero da 1 a 9: «${n}»"
    # shellcheck disable=SC2034  # la legge main, in live.sh
    ESECUZIONI="${n}"
  fi
}

#######################################
# Lo spazio di lavoro (la cartella corrente) è la cima di un repository git
# con git status vuoto: ogni esecuzione parte dal progetto del primo
# commit, perché nuova_copia.sh ne copia i file così come sono, anche un
# file cambiato o in più.
# Arguments: $1 lo spazio di lavoro (assoluto, la cartella corrente).
# Returns: 0; esce 2 altrimenti.
#######################################
stop::al_punto_di_partenza() {
  local stato
  [[ "$(git rev-parse --show-toplevel 2> /dev/null)" == "$1" ]] \
    || handson::die "$1 non è un repository git: preparatelo con" \
      "tools/prepara_esercizio.sh M4-D05"
  stato="$(git status --porcelain)" || handson::die "git status non riesce"
  [[ -z "${stato}" ]] \
    || handson::die "lo spazio di lavoro non è al punto di partenza (git" \
      "status non è vuoto): tools/reset_esercizio.sh M4-D05"
}

#######################################
# Le impostazioni dei due bracci (nella cartella corrente, lo spazio di
# lavoro), tolta la chiave hooks, sono uguali, come le vuole
# controlla_stop.py: la coppia differisce soltanto nell'hook. Lo si dice
# prima di ogni chiamata, non dopo sei. Va chiamata fuori da $(…).
# Returns: 0; esce 2 se un file non è un oggetto JSON, o se differiscono.
#######################################
stop::uguali_tolto_hook() {
  local esito rc=0
  esito="$(python3 -B -I - impostazioni/senza-hook.json \
    impostazioni/con-hook.json <<'PY'
import json, sys
resti = []
for nome in sys.argv[1:3]:
    try:
        with open(nome, encoding="utf-8") as fh:
            dati = json.load(fh)
    except (OSError, ValueError, RecursionError):
        dati = None
    if not isinstance(dati, dict):
        print("%s non è un oggetto JSON" % nome)
        sys.exit(1)
    resti.append({k: v for k, v in dati.items() if k != "hooks"})
if resti[0] != resti[1]:
    print("tolto l'hook, le impostazioni dei due bracci differiscono: la "
          "coppia deve differire soltanto nell'hook")
    sys.exit(1)
PY
)" || rc=$?
  if (( rc != 0 )); then
    [[ -n "${esito}" ]] || esito="il confronto delle impostazioni non riesce"
    handson::die "${esito}"
  fi
}

#######################################
# Una sessione, dalla copia della sua esecuzione, con il suo stream-json
# accanto alla copia: la riga di handson::claude_p con --output-format
# stream-json --verbose. I controlli stanno fuori dal sottoprocesso e
# fuori da $(…): una precondizione esce davvero con 2.
# Globals: HANDSON_ENV, HANDSON_PERMISSION_MODE, HANDSON_SETTING_SOURCES
#   (lette).
# Arguments: $1 la cartella dell'esecuzione (esecuzioni/<braccio>-<n>),
#   $2 il prompt.
# Returns: l'uscita di claude.
#######################################
stop::chiedi() {
  local cartella="$1" domanda="$2" arg
  handson::need_tools claude
  handson::_claude_p_checks "${MODELLO}" "${domanda}"
  handson::_claude_key_ok "${domanda}"
  for arg in "${MODELLO}" "${STRUMENTI}" "${OPZIONI[@]}"; do
    handson::_claude_arg_ok "${arg}"
  done
  local -a argv=(claude -p --allowedTools "${STRUMENTI}" --model "${MODELLO}"
    --permission-mode "${HANDSON_PERMISSION_MODE}" --permission-prompts none
    --output-format stream-json --verbose
    --setting-sources "${HANDSON_SETTING_SOURCES}" "${OPZIONI[@]}"
    -- "${domanda}")
  handson::note "claude parte dalla copia: ${cartella}/urgenze/"
  (
    # stop::chiedi gira dentro «… || stop::fallita», dove errexit non
    # vale: l'uscita di un cd fallito si dice qui, prima che claude parta
    # altrove.
    cd "${cartella}/urgenze" || exit 2
    if [[ "${HANDSON_ENV}" != "trainer-api" ]]; then
      if [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
        handson::note "ANTHROPIC_API_KEY è impostata: la tolgo per questo" \
          "comando, così Claude Code usa l'abbonamento"
      fi
      unset ANTHROPIC_API_KEY
    fi
    handson::run "${argv[@]}" < /dev/null > ../stream.jsonl
  )
}

#######################################
# Mostra la sola differenza fra le impostazioni dei due bracci, lo Stop
# hook; esce 2 se le due impostazioni sono uguali o diff non riesce.
#######################################
stop::mostra_differenza() {
  local rc=0
  handson::run diff impostazioni/senza-hook.json impostazioni/con-hook.json \
    || rc=$?
  (( rc == 1 )) \
    || handson::die "le impostazioni dei due bracci devono differire nello" \
      "Stop hook (diff è uscito con ${rc})"
}

# Una chiamata fallita: il verdetto KO e la fine con uscita 1, senza fare
# le esecuzioni che restano.
stop::fallita() {
  handson::verdict ko "$*"
  handson::finish
}

# verifica.sh con il suo STDOUT sul descrittore 3, che main apre sullo
# STDOUT di live.sh: handson::check mostra l'uscita di un controllo solo
# su un KO, e qui i dati e i verdetti sono la demo anche quando passa.
# Arguments: $1 lo spazio di lavoro. Returns: l'uscita di verifica.sh.
# shellcheck disable=SC2317  # la chiama handson::check, indirettamente
stop::verifica_a_schermo() {
  "${CONTROLLO}" "$1" >&3
}
