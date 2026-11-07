# shellcheck shell=bash
# =====================================================================
# lib_caricamento.sh -- di in_classe.sh di M6-D02: le parole in codice, le
# copie del progetto e dei bracci di costo, le chiamate claude -p
# ---------------------------------------------------------------------
# Libreria: si fa SOURCE, non si esegue. Usa tools/lib_handson.sh, che
# in_classe.sh carica prima: handson::claude_p mostra ogni comando prima di
# eseguirlo, toglie ANTHROPIC_API_KEY e CLAUDE_CODE_EFFORT_LEVEL dal suo
# ambiente, mette dontAsk, --permission-prompts none e --setting-sources
# project,local.
#
# Ogni chiamata gira in una copia nuova, in una cartella temporanea fuori
# dallo spazio di lavoro: un repository git con un commit, il .gitignore che
# lascia fuori CLAUDE.local.md e il registro dell'hook, il registro vuoto. Le
# nove parole di una copia di progetto/ nascono qui, casuali, per ogni
# chiamata, e vanno al posto dei segnaposto __CHIAVE__ dei nove file. Gli
# stream, i registri e le parole stanno in un'altra cartella temporanea, il
# deposito, finché l'ultima chiamata non è finita.
#
# Globals (lette): MODELLO, SPAZIO (lo spazio di lavoro, assoluto).
#   (assegnate) DEPOSITO, COPIE, COPIA.
# =====================================================================

readonly CARICAMENTO_CHIAVI=(RADICE COMMENTO IMPORTATO CITATO LOCALE REGOLA
  REGOLAPHP ANNIDATO LETTO)
readonly CARICAMENTO_FILE=(CLAUDE.md docs/glossario.md docs/escluso.md
  CLAUDE.local.md .claude/rules/generale.md .claude/rules/php.md
  sub/CLAUDE.md sub/nota.txt)
readonly CARICAMENTO_REGISTRO=.claude/caricamenti.jsonl
# shellcheck disable=SC2034  # la legge in_classe.sh
readonly CARICAMENTO_BRACCI=(base commento inline import)
DEPOSITO=''
COPIE=''
COPIA=''

# Il deposito e le copie, due cartelle temporanee che spariscono all'uscita
# (handson::tmpdir): ciò che una sessione raggiunge dalla sua copia non porta
# alle risposte. Globals: DEPOSITO, COPIE (assegnate).
caricamento::apri_temporanei() {
  handson::tmpdir DEPOSITO
  handson::tmpdir COPIE
}

# Le nove parole di una chiamata, casuali: nel file JSON del deposito e, una
# per riga «CHIAVE PAROLA», su STDOUT. Arguments: $1 il file JSON.
caricamento::parole() {
  python3 -B -I - "$1" <<'PY'
import json
import secrets
import string
import sys

CHIAVI = ("RADICE", "COMMENTO", "IMPORTATO", "CITATO", "LOCALE", "REGOLA",
          "REGOLAPHP", "ANNIDATO", "LETTO")
parole = {c: c + "-" + "".join(secrets.choice(string.ascii_uppercase)
                               for _ in range(6)) for c in CHIAVI}
with open(sys.argv[1], "w", encoding="utf-8") as fh:
    json.dump({c.lower(): p for c, p in parole.items()}, fh, indent=1)
    fh.write("\n")
for c in CHIAVI:
    print(c, parole[c])
PY
}

# Mette una parola al posto del suo segnaposto in un file della copia.
# Arguments: $1 il file, $2 la chiave, $3 la parola.
caricamento::sostituisci() {
  local testo
  testo="$(cat -- "$1" && printf x)" || return 1
  testo="${testo%x}"
  printf '%s' "${testo//__$2__/$3}" > "$1"
}

# Il repository git della copia, con un commit e il .gitignore, poi il
# registro dell'hook, vuoto: vuoto vuol dire «niente caricato», assente «la
# prova non è andata». Arguments: $1 la copia, $2 il suo nome.
caricamento::repository() {
  printf '%s\n' CLAUDE.local.md "${CARICAMENTO_REGISTRO}" > "$1/.gitignore" \
    || handson::die "non riesco a scrivere $1/.gitignore"
  if ! git -c init.defaultBranch=main -C "$1" init -q \
      || ! git -C "$1" add -A \
      || ! git -C "$1" -c user.name="${HANDSON_GIT_NAME}" \
        -c user.email="${HANDSON_GIT_EMAIL}" -c commit.gpgsign=false \
        commit -q --no-verify -m "Punto di partenza di $2"; then
    handson::die "git non riesce a fare il repository di $2"
  fi
  : > "$1/${CARICAMENTO_REGISTRO}" \
    || handson::die "non riesco a creare il registro di $2"
}

# Una copia nuova di progetto/ con nove parole nuove; le parole nel deposito,
# in <nome>.parole.json. Globals: SPAZIO, COPIE, DEPOSITO; COPIA (assegnata).
# Arguments: $1 il nome della chiamata.
caricamento::copia_progetto() {
  local nome="$1" chiave parola f
  local -a parole=()
  COPIA="$(mktemp -d "${COPIE}/${nome}.XXXXXX")" \
    || handson::die "non riesco a creare la copia di ${nome}"
  cp -R -- "${SPAZIO}/progetto/." "${COPIA}/" \
    || handson::die "non riesco a riempire la copia di ${nome}"
  while read -r chiave parola; do
    parole+=("${chiave}" "${parola}")
  done < <(caricamento::parole "${DEPOSITO}/${nome}.parole.json")
  (( ${#parole[@]} == 2 * ${#CARICAMENTO_CHIAVI[@]} )) \
    || handson::die "python3 non ha generato le parole di ${nome}"
  for f in "${CARICAMENTO_FILE[@]}"; do
    set -- "${parole[@]}"
    while (( $# >= 2 )); do
      caricamento::sostituisci "${COPIA}/${f}" "$1" "$2" \
        || handson::die "non riesco a scrivere le parole in ${f}"
      shift 2
    done
    if grep -qE '__[A-Z]+__' -- "${COPIA}/${f}"; then
      handson::die "un segnaposto senza parola in ${f}: progetto/ è cambiato?"
    fi
  done
  caricamento::repository "${COPIA}" "${nome}"
}

# Una copia di un braccio di costo: il suo CLAUDE.md, docs/procedura.md e
# .claude/ con l'hook, uguali nei quattro bracci. I quattro bracci girano
# uno dopo l'altro nella stessa cartella, COPIE/costo, con lo stesso messaggio
# di commit: la cartella di lavoro e lo stato di git entrano nel contesto, e i
# bracci devono differire soltanto nel CLAUDE.md. La copia di prima si toglie.
# Globals: SPAZIO, COPIE; COPIA (assegnata). Arguments: $1 il braccio.
caricamento::copia_costo() {
  COPIA="${COPIE}/costo"
  if [[ -e "${COPIA}" ]]; then
    [[ -d "${COPIA}" && ! -L "${COPIA}" ]] \
      || handson::die "${COPIA} non è una cartella: non la tolgo"
    rm -rf -- "${COPIA}" || handson::die "non riesco a togliere ${COPIA}"
  fi
  mkdir -- "${COPIA}" \
    || handson::die "non riesco a creare la copia del braccio $1"
  if ! mkdir -p -- "${COPIA}/docs" "${COPIA}/.claude/hooks" \
      || ! cp -- "${SPAZIO}/costo/$1/CLAUDE.md" "${COPIA}/CLAUDE.md" \
      || ! cp -- "${SPAZIO}/costo/procedura.md" "${COPIA}/docs/procedura.md" \
      || ! cp -- "${SPAZIO}/progetto/.claude/settings.json" "${COPIA}/.claude/" \
      || ! cp -- "${SPAZIO}/progetto/.claude/hooks/registra_caricamenti.py" \
        "${COPIA}/.claude/hooks/"; then
    handson::die "non riesco a riempire la copia del braccio $1"
  fi
  caricamento::repository "${COPIA}" "costo"
}

# Una chiamata: claude -p dalla copia, Sonnet con effort low, senza server
# MCP, senza salvare la sessione, la auto memory spenta; lo stream e il
# registro dell'hook nel deposito. Globals: MODELLO, DEPOSITO, COPIA.
# Arguments: $1 il nome, $2 gli strumenti ("" = nessuno), $3 il file del
# prompt. Returns: 0; 1 se claude o la copia del registro non riescono.
caricamento::chiedi() {
  local nome="$1" strumenti="$2" prompt
  prompt="$(< "$3")" || handson::die "non riesco a leggere $3"
  printf '  # %s\n' "${nome}" >&2
  ( cd -- "${COPIA}" \
      && export CLAUDE_CODE_DISABLE_AUTO_MEMORY=1 \
      && handson::claude_p "${MODELLO}" "${strumenti}" "${prompt}" \
        --tools "${strumenti}" --effort low --strict-mcp-config \
        --no-session-persistence ) < /dev/null \
    > "${DEPOSITO}/${nome}.jsonl" || return 1
  cp -- "${COPIA}/${CARICAMENTO_REGISTRO}" \
    "${DEPOSITO}/${nome}.caricamenti.jsonl" || return 1
}

# Gli stream, i registri e le parole in risposte/ dello spazio di lavoro.
# Globals: SPAZIO, DEPOSITO.
caricamento::consegna() {
  mkdir -p -- "${SPAZIO}/risposte" \
    || handson::die "non riesco a creare risposte/"
  handson::run cp -R -- "${DEPOSITO}/." "${SPAZIO}/risposte/" < /dev/null \
    || handson::die "non riesco a copiare gli stream in risposte/"
}
