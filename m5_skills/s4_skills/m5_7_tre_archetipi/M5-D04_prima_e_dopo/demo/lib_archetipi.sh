# shellcheck shell=bash
#
# lib_archetipi.sh -- le parti comuni di in_classe.sh e di _docente/live.sh di
# M5-D04: le cartelle di un archetipo, un'esecuzione, la consegna degli
# stream. Libreria: si fa source dopo tools/lib_handson.sh e dopo
# handson::init_root, e non si esegue.
#
# Un archetipo ha due cartelle, due repository git su main, con il progetto che
# serve e nient'altro:
#   revisione  progetti/gestionale-php, .claude/skills/revisione-pr, e il
#              ramo pr-demo con pr-demo.patch applicato
#   risposta   progetti/assistenza-clienti, .claude/skills/risposta-assistenza
#   audit      progetti/rete, .claude/skills/audit-configurazione
# <spazio>/<archetipo>/ ha la skill, che viene da riferimenti/skill-di-esempio/
# del repository, senza evals/. <spazio>/<archetipo>-senza/ è uguale, tranne
# che è nata senza .claude/skills/<skill>/.
# I bracci: on, dalla cartella con la skill; senza, dalla cartella senza, con lo
# stesso comando; off, dalla cartella con la skill, con in più --settings e
# skillOverrides, che la spegne per quella esecuzione.

# handson::claude_p lo legge: ogni messaggio e ogni risultato, una riga JSON.
# shellcheck disable=SC2034
HANDSON_OUTPUT_FORMAT='stream-json'
readonly ARCHETIPI_ELENCO=(revisione risposta audit)
readonly ARCHETIPI_OPZIONI=(--effort low --strict-mcp-config
  --no-session-persistence)
readonly ARCHETIPI_MESSAGGIO_PR='feat(report): morosita per comune'

# La skill di un archetipo. Arguments: $1 l'archetipo.
# Outputs: il nome. Returns: 0; 2 per un archetipo che non c'è.
archetipi::skill_di() {
  case "$1" in
    revisione) printf 'revisione-pr\n' ;;
    risposta) printf 'risposta-assistenza\n' ;;
    audit) printf 'audit-configurazione\n' ;;
    *) return 2 ;;
  esac
}

# Il progetto di un archetipo. Arguments: $1 l'archetipo.
# Outputs: il nome. Returns: 0; 2 per un archetipo che non c'è.
archetipi::progetto_di() {
  case "$1" in
    revisione) printf 'gestionale-php\n' ;;
    risposta) printf 'assistenza-clienti\n' ;;
    audit) printf 'rete\n' ;;
    *) return 2 ;;
  esac
}

# La richiesta di un archetipo, da richieste.tsv.
# Arguments: $1 il file, $2 l'archetipo. Outputs: la richiesta su STDOUT.
# Returns: 0; 2 con un messaggio se non c'è, o non è una sola.
archetipi::richiesta() {
  local nome testo trovate=0 richiesta=''
  while IFS="${HANDSON_TAB}" read -r nome testo || [[ -n "${nome}" ]]; do
    if [[ "${nome}" == "$2" ]]; then
      richiesta="${testo}"
      trovate=$((trovate + 1))
    fi
  done < "$1"
  if (( trovate != 1 )) || [[ -z "${richiesta}" ]]; then
    handson::err "$1: attesa una richiesta per «$2», trovate ${trovate}"
    return 2
  fi
  printf '%s\n' "${richiesta}"
}

# Il ramo del pull request nella cartella della revisione.
# Arguments: $1 la cartella, $2 il percorso assoluto della patch.
archetipi::_ramo_pr() {
  git -C "$1" checkout -q -b pr-demo || return 2
  git -C "$1" apply -- "$2" || return 2
  git -C "$1" add -A || return 2
  git -C "$1" -c user.name="${HANDSON_GIT_NAME}" \
    -c user.email="${HANDSON_GIT_EMAIL}" -c commit.gpgsign=false \
    commit -q --no-verify -m "${ARCHETIPI_MESSAGGIO_PR}" || return 2
}

# Riempie una cartella appena creata. Senza una skill, il commit nasce senza
# .claude/skills/; tutto il resto è uguale.
# Globals: HANDSON_ROOT. Arguments: $1 la cartella, $2 l'archetipo, $3 la skill
# ("" = nessuna), $4 il progetto, $5 la patch. Returns: 0; 2 su ogni errore.
archetipi::_riempi() {
  local skill_dir="$1/.claude/skills/$3"
  mkdir -p -- "$1/progetti/$4" "$1/.claude" || return 2
  handson::copy_shippable "progetti/$4" "$1/progetti/$4" || return 2
  if [[ -n "$3" ]]; then
    mkdir -p -- "${skill_dir}" || return 2
    handson::copy_shippable "riferimenti/skill-di-esempio/$3" "${skill_dir}" \
      || return 2
    [[ -f "${skill_dir}/SKILL.md" ]] || return 2
    rm -rf -- "${skill_dir}/evals"
  fi
  cp -p -- "${HANDSON_ROOT}/.claude/settings.json" "$1/.claude/settings.json" \
    || return 2
  handson::git_init_workspace "$1" M5-D04 || return 2
  if [[ "$2" == revisione ]]; then
    archetipi::_ramo_pr "$1" "$5" || return 2
  fi
}

# Una delle due cartelle di un archetipo: la prepara, o controlla quella che c'è
# già: un repository git con git status vuoto, così le esecuzioni partono tutte
# dallo stesso punto. Arguments: $1 la cartella, $2 l'archetipo, $3 la skill
# ("" = nessuna), $4 il progetto, $5 la patch.
# Returns: 0; esce 2 con un messaggio se la cartella non va.
archetipi::_una_cartella() {
  local stato
  if [[ -e "$1" || -L "$1" ]]; then
    [[ -d "$1/.git" && ! -L "$1" ]] \
      || handson::die "$1 non è una cartella preparata da qui:" \
        "tools/reset_esercizio.sh M5-D04"
    stato="$(git -C "$1" status --porcelain)" \
      || handson::die "git status non riesce in $1"
    [[ -z "${stato}" ]] \
      || handson::die "$1 non è al punto di partenza: git status non è vuoto"
    return 0
  fi
  mkdir -- "$1" || handson::die "non riesco a creare $1"
  if ! archetipi::_riempi "$1" "$2" "$3" "$4" "$5"; then
    rm -rf -- "$1"
    handson::die "non riesco a preparare $1"
  fi
}

# Prepara le due cartelle di un archetipo. Globals: HANDSON_ROOT (letta).
# Arguments: $1 lo spazio di lavoro, $2 l'archetipo.
# Returns: 0; esce 2 con un messaggio se una cartella non va.
archetipi::prepara() {
  local skill progetto
  skill="$(archetipi::skill_di "$2")" \
    || handson::die "archetipo sconosciuto: $2"
  progetto="$(archetipi::progetto_di "$2")" \
    || handson::die "archetipo sconosciuto: $2"
  archetipi::_una_cartella "$1/$2" "$2" "${skill}" "${progetto}" \
    "$1/pr-demo.patch"
  archetipi::_una_cartella "$1/$2-senza" "$2" '' "${progetto}" \
    "$1/pr-demo.patch"
}

# Un'esecuzione: `claude -p` nella cartella del braccio, con il suo stream in
# un file fuori dallo spazio di lavoro. Se la sessione lascia dei file, il loro
# elenco va accanto allo stream, come dato, e la cartella torna com'era: anche
# l'esecuzione dopo deve partire dallo stesso punto.
# Arguments: $1 lo spazio di lavoro, $2 l'archetipo, $3 il modello, $4 on, senza
# o off, $5 la richiesta, $6 il file dello stream.
# Returns: l'uscita di claude; 2 per un braccio o un archetipo che non c'è.
archetipi::esegui() {
  local cartella="$1/$2" modello="$3" braccio="$4" richiesta="$5"
  local stream="$6" rc=0 skill stato
  local -a extra=("${ARCHETIPI_OPZIONI[@]}")
  skill="$(archetipi::skill_di "$2")" || return 2
  case "${braccio}" in
    on) ;;
    senza) cartella+='-senza' ;;
    off) extra+=(--settings "{\"skillOverrides\":{\"${skill}\":\"off\"}}") ;;
    *) return 2 ;;
  esac
  (
    cd -- "${cartella}" \
      && handson::claude_p "${modello}" "Read,Skill(${skill})" "${richiesta}" \
        "${extra[@]}"
  ) < /dev/null > "${stream}" || rc=$?
  stato="$(git -C "${cartella}" status --porcelain)" || return 2
  if [[ -n "${stato}" ]]; then
    printf '%s\n' "${stato}" > "${stream%.jsonl}.cambiati"
    git -C "${cartella}" checkout -q -- . || return 2
    git -C "${cartella}" clean -fdq || return 2
  fi
  return "${rc}"
}

# Gli stream del deposito, copiati nello spazio di lavoro a sessioni finite:
# mentre una sessione gira, nello spazio di lavoro non c'è lo stream di quella
# prima. Arguments: $1 il deposito, $2 la cartella di destinazione.
archetipi::consegna() {
  local -a stream=("$1"/*)
  mkdir -p -- "$2" || handson::die "non riesco a creare $2"
  if [[ -e "${stream[0]}" ]]; then
    cp -- "${stream[@]}" "$2/" || handson::die "non riesco a copiare in $2"
  fi
}

# Le precondizioni che valgono per tutti e due gli script: l'ambiente
# dell'elemento, gli strumenti, lo spazio di lavoro preparato per M5-D04, i
# file che servono, claude. Arguments: $1 lo spazio di lavoro.
archetipi::precondizioni() {
  local segno f
  [[ "${HANDSON_ENV}" == claude-code-pro ]] \
    || handson::die "M5-D04 è un elemento claude-code-pro: HANDSON_ENV" \
      "«${HANDSON_ENV}» non vale qui"
  handson::need_tools python3 git
  segno="$(git -C "$1" config --get corso.elemento 2> /dev/null)" || segno=''
  [[ "${segno}" == M5-D04 && "$(git -C "$1" rev-parse --show-toplevel)" \
      == "$(cd -- "$1" && pwd -P)" ]] \
    || handson::die "$1 non è lo spazio di lavoro di M5-D04: preparalo con" \
      "tools/prepara_esercizio.sh M5-D04"
  for f in richieste.tsv pr-demo.patch controlla_archetipi.py; do
    handson::need_file "$1/${f}"
  done
}
