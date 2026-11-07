#!/bin/bash
#
# test_m6_e01.sh -- le prove di M6-E01 «Che cosa vede Claude», per il docente
# (sta in _docente/, il materiale del docente):
#   - l'elemento: tools/php.sh e lo script dell'hook copie byte per byte di
#     quelli di tools/, l'hook nelle impostazioni con le regole prudenti del
#     repository, il registro fuori da git, nessun CLAUDE.md; il README: le
#     frasi di Anthropic con il loro indirizzo, la domanda in una riga,
#     nessun nome interno;
#   - prepara_esercizio.sh e il punto di partenza;
#   - i comandi dei passi 2, 3 e 4 del README, eseguiti così come sono, con il
#     claude finto: verifica.sh dopo ogni passo (1, 1, 0);
#   - verifica.sh: le due garanzie (0), ognuna che non tiene (1), i passi fuori
#     ordine (1), i file che non si leggono (2); la risposta, da risposta.txt o
#     dallo stream, stampata come dato, senza percorsi personali, mai come
#     uscita;
#   - soluzione/applica.sh e la registrazione; _docente/live.sh, il
#     partecipante emulato, e tools/run_all.sh, anche con --live;
#   - check_handson.sh senza segnalazioni su questo elemento; shellcheck.
# Mai il claude vero: il finto sta davanti nel PATH, e la suite lo controlla
# prima di usarlo. Ciò che il finto scrive non è un'uscita di Claude Code:
# prova la verifica, non il prodotto. Gli spazi di lavoro nascono in una
# cartella temporanea, nella base di handson::init_temp_base (mai dentro
# ~/.claude): l'albero del repository non cambia. CASES è il numero dei
# casi: se ne girano di più o di meno la suite esce 2.
#
# Uso:    m6_projects_context/_docente/test_m6_e01.sh
# Uscita: 0 = tutti i casi passano · 1 = almeno un caso fallito · 2 =
#         precondizione (manca python3, git o shellcheck; il finto non viene
#         prima nel PATH), o un numero di casi diverso da CASES
# shellcheck disable=SC2016  # backtick e $ sono il testo delle prove
set -uo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly MOD="${SELF%/_docente/*}"
readonly RADICE="${MOD%/*}"
E01="${MOD}/s5_projects_context/m6_e1_che_cosa_vede_claude"
E01+="/M6-E01_che_cosa_vede_claude"
readonly E01
readonly FINTO_PY="${MOD}/_docente/claude_finto_m6_e01.py"
# La libreria del repository, per la base dei file temporanei.
# shellcheck source=../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"
readonly CASES=161
readonly DOMANDA='Con quale comando si eseguono i test di questo progetto?'
readonly FATTO='Fatto: CLAUDE.md è sotto «Memory files» in dopo.md'
readonly G_CONTEXT='/context all elenca sotto «Memory files» il CLAUDE.md'
readonly G_HOOK="l'hook InstructionsLoaded scatta all'avvio"
readonly NON_CONF='non confermata in questa esecuzione'
TMP=''
PASS=0
FAIL=0
SKIP=0
RC=0
OUT=''
TUTTO=''

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }
skip() { echo "  SKIP: $1"; SKIP=$((SKIP + 1)); }

# Esegue un comando; RC e OUT (STDOUT e STDERR insieme) per expect; OUT si
# aggiunge a TUTTO, dove alla fine non deve esserci «smentita».
run() { OUT="$("$@" 2>&1)"; RC=$?; TUTTO+="${OUT}"$'\n'; }

# Uscita attesa E parola chiave attesa (RU-01.T3).
# Arguments: $1 il nome, $2 l'uscita attesa, $3 la parola (grep -F).
expect() {
  if (( RC == $2 )) && grep -qF -- "$3" <<< "${OUT}"; then
    pass "$1"
  else
    fail "$1 (rc=${RC}, attesa $2, parola «$3»): ${OUT:0:900}"
  fi
}

# Nessun falso positivo: la parola NON c'è (RU-01.T5).
# Arguments: $1 il nome, $2 la parola.
expect_absent() {
  if grep -qF -- "$2" <<< "${OUT}"; then
    fail "$1: «$2» c'è"
  else
    pass "$1"
  fi
}

# Un caso che passa se il comando riesce. Arguments: $1 il nome, poi il
# comando.
vero() {
  local nome="$1"
  shift
  if "$@"; then
    pass "${nome}"
  else
    fail "${nome}"
  fi
}

# Il claude finto davanti nel PATH, e la prova che è lui.
prepara_claude() {
  mkdir -p "${TMP}/finto" || exit 2
  cp -- "${FINTO_PY}" "${TMP}/finto/claude" || exit 2
  chmod +x "${TMP}/finto/claude" || exit 2
  export PATH="${TMP}/finto:${PATH}"
  export HANDSON_NO_PAUSE=1
  unset ANTHROPIC_API_KEY CLAUDE_CODE_EFFORT_LEVEL HANDSON_ENV FINTO_LOG
  [[ "$(command -v claude)" == "${TMP}/finto/claude" ]] \
    || { echo "test_m6_e01: il finto non viene prima nel PATH" >&2; exit 2; }
}

# Uno spazio di lavoro nuovo, con prepara_esercizio.sh in una radice nuova.
# Arguments: $1 la variabile da assegnare. Returns: 0; 1 se non riesce.
nuovo_ws() {
  local __r
  __r="$(mktemp -d "${TMP}/radice.XXXXXX")" || exit 2
  "${RADICE}/tools/prepara_esercizio.sh" M6-E01 --radice "${__r}" \
    > "${TMP}/prepara.log" 2>&1 || return 1
  printf -v "$1" '%s' "${__r}/M6-E01"
}

# I comandi del passo $2 del README (le righe di codice del punto «$2.»
# della sezione dei passi), in un file. Arguments: $1 il file, $2 il passo.
comandi_del_passo() {
  python3 -B -I - "${E01}/README.md" "$2" > "$1" <<'PY' || exit 2
import re, sys
testo = open(sys.argv[1], encoding="utf-8").read()
passi = testo.split("## Passi in Claude Code", 1)[1].split("\n## ", 1)[0]
punti = re.split(r"(?m)^(?=\d+\. )", passi)
punto = [p for p in punti if p.startswith(sys.argv[2] + ". ")][0]
righe = [r[7:] for r in punto.split("\n") if r.startswith("       ")]
print("\n".join(righe))
PY
}

# Esegue nello spazio di lavoro $1 i comandi dei passi del README dati dopo,
# con le variabili d'ambiente che li precedono (NOME=valore). RC e OUT come
# run.
passi() {
  local w="$1" p
  local -a amb=()
  shift
  while (( $# > 0 )) && [[ "$1" == *=* ]]; do
    amb+=("$1")
    shift
  done
  for p in "$@"; do
    comandi_del_passo "${TMP}/passo.sh" "${p}"
    run env ${amb[@]+"${amb[@]}"} bash -c 'cd "$1" && bash -euo pipefail "$2"' \
      _ "${w}" "${TMP}/passo.sh"
    (( RC == 0 )) || return 0
  done
}

# verifica.sh dell'elemento sullo spazio di lavoro $1; RC e OUT come run.
verifica() { run env PN_HANDSON_ROOT="${RADICE}" "${E01}/verifica.sh" "$@"; }

# Uno spazio di lavoro con i passi 2, 3 e 4 del README fatti.
# Arguments: $1 la variabile da assegnare.
ws_fatto() {
  local __w
  nuovo_ws __w || exit 2
  passi "${__w}" 2 3 4
  (( RC == 0 )) || { echo "test_m6_e01: i passi non girano: ${OUT}" >&2
    exit 2; }
  printf -v "$1" '%s' "${__w}"
}

# Un risposta.txt nella forma di /export, inventato per la prova, con la
# domanda e una risposta. Arguments: $1 lo spazio di lavoro, $2 la risposta.
export_finto() {
  printf '%s\n' ' finto  Claude Code (uscita finta di /export)' \
    "        $1" '' '' "❯ ${DOMANDA}          " '' "● $2" '' \
    '✻ Finto per 1s' > "$1/risposta.txt"
}

# ---------------------------------------------------------------- l'elemento

t_elemento() {
  local f
  for f in README.md verifica.sh verifica.py progetti.txt \
      esercizio/.claude/settings.json \
      esercizio/.claude/hooks/registra_caricamenti.py esercizio/.gitignore \
      esercizio/tools/php.sh _docente/live.sh soluzione/applica.sh \
      soluzione/LEGGIMI.md; do
    vero "c'è ${f}" test -f "${E01}/${f}"
  done
  vero "esercizio/tools/php.sh è una copia byte per byte di tools/php.sh" \
    cmp -s "${E01}/esercizio/tools/php.sh" "${RADICE}/tools/php.sh"
  vero "l'hook è una copia byte per byte di tools/registra_caricamenti.py" \
    cmp -s "${E01}/esercizio/.claude/hooks/registra_caricamenti.py" \
    "${RADICE}/tools/registra_caricamenti.py"
  for f in verifica.sh _docente/live.sh soluzione/applica.sh \
      esercizio/tools/php.sh; do
    vero "${f} è eseguibile" test -x "${E01}/${f}"
  done
  vero "progetti.txt nomina il gestionale" \
    grep -qFx 'progetti/gestionale-php' "${E01}/progetti.txt"
  vero "il registro è fuori da git" \
    grep -qFx '.claude/caricamenti.jsonl' "${E01}/esercizio/.gitignore"
  run python3 -B -I - "${E01}/esercizio/.claude/settings.json" \
    "${RADICE}/.claude/settings.json" <<'PY'
import json, sys
mie = json.load(open(sys.argv[1], encoding="utf-8"))
radice = json.load(open(sys.argv[2], encoding="utf-8"))
hook = {"InstructionsLoaded": [{"hooks": [{"type": "command", "command":
        "python3 \"$CLAUDE_PROJECT_DIR/.claude/hooks/registra_caricamenti.py\""
        }]}]}
assert mie["hooks"] == hook, mie["hooks"]
assert mie["permissions"] == radice["permissions"], mie["permissions"]
assert set(mie) == {"hooks", "permissions"}, sorted(mie)
print("impostazioni giuste")
PY
  expect "l'hook e le regole prudenti del repository" 0 'impostazioni giuste'
  run command find "${E01}/esercizio" "${RADICE}/progetti/gestionale-php" \
    -iname 'CLAUDE.md' -o -iname 'CLAUDE.local.md' -o -iname 'AGENTS.md'
  if [[ -z "${OUT}" ]]; then
    pass "nessun file di istruzioni nel punto di partenza"
  else
    fail "un file di istruzioni nel punto di partenza: ${OUT}"
  fi
}

t_readme() {
  local testo frase parola blocco
  testo="$(tr -s '[:space:]' ' ' < "${E01}/README.md")"
  while IFS= read -r frase; do
    if [[ "${testo}" == *"${frase}"* ]]; then
      pass "README: «${frase:0:48}…»"
    else
      fail "README: manca «${frase}»"
    fi
  done <<'FRASI'
To confirm the file loaded, run /context all in a session and check the list under Memory files.
Run /context all and check the list under Memory files to verify the CLAUDE.md and CLAUDE.local.md files that should load at launch. If one is missing there, Claude can't see it.
CLAUDE.md and CLAUDE.local.md files in the directory hierarchy above the working directory are loaded at launch. Files in subdirectories load on demand.
A CLAUDE.md in a subdirectory of your working directory doesn't appear under Memory files, because it loads on demand rather than at launch.
To test a new one, create it from your shell rather than asking Claude to write it, then ask Claude to read a file in that subdirectory.
https://code.claude.com/docs/en/memory
/context [all] | Visualize current context usage as a colored grid. … Pass all to expand it
https://code.claude.com/docs/en/commands
How to confirm work in this repo: the exact test, typecheck, and lint commands, and how to run a single test file
https://code.claude.com/docs/en/best-practices
Use the InstructionsLoaded hook to log which CLAUDE.md and rules files are loaded, when they load, and why.
InstructionsLoaded | When a CLAUDE.md or .claude/rules/*.md file is loaded into context. Fires at session start and when files are lazily loaded during a session
Why the file was loaded: "session_start", "nested_traversal", "path_glob_match", "include", or "compact"
The hook doesn't support blocking or decision control. It runs asynchronously for observability purposes.
https://code.claude.com/docs/en/hooks
a -p session runs the hooks in a project’s .claude/settings.json and connects the servers in its .mcp.json, even in a folder you’ve never trusted
https://code.claude.com/docs/en/headless
Export the current conversation as plain text. With a filename, writes directly to that file.
In an interactive session, Claude Code shows the workspace trust dialog when you start it in a folder you haven't trusted.
https://code.claude.com/docs/en/security
Pro, Max, Ultra, Team, Enterprise, and Anthropic API: defaults to Opus 5.5
Comma-separated list of setting sources to load (user, project, local).
Only use MCP servers from --mcp-config, ignoring all other MCP configurations
tools/prepara_esercizio.sh M6-E01
tools/verifica.sh M6-E01
tools/reset_esercizio.sh M6-E01
/export risposta.txt
il cursore parte da «No, exit»
Yes, I trust this folder
«VERIFICA OK M6-E01: fatto.»
FRASI
  for parola in 'FACT-' 'M6-X' 'X-37' 'X-38' 'smentit' 'probe' 'oggi' \
      '/home/' 'In preparazione'; do
    if [[ "${testo}" == *"${parola}"* ]]; then
      fail "README: «${parola}» non ci sta"
    else
      pass "README: niente «${parola}»"
    fi
  done
  blocco="$(sed -n '/<!-- prompt 1 -->/,/<!-- \/prompt 1 -->/p' \
    "${E01}/README.md" | sed -e '/<!-- /d' -e '/^ *$/d' -e 's/^ *//')"
  if [[ "${blocco}" == "${DOMANDA}" ]]; then
    pass "il prompt 1 è la domanda, in una riga"
  else
    fail "il prompt 1 non è la domanda: «${blocco}»"
  fi
  if [[ "${blocco}" != *'<'* ]]; then
    pass "la domanda è una richiesta semplice, senza tag (P)"
  else
    fail "la domanda ha dei tag: «${blocco}»"
  fi
  run "${RADICE}/tools/check_handson.sh"
  if grep -q 'M6-E01\|m6_e1_che_cosa_vede_claude' <<< "${OUT}"; then
    fail "check_handson.sh segnala M6-E01: $(grep 'M6-E01' <<< "${OUT}")"
  else
    pass "check_handson.sh non segnala M6-E01"
  fi
}

# ------------------------------------------------------ il punto di partenza

t_prepara() {
  local w
  if ! nuovo_ws w; then
    fail "prepara_esercizio.sh: $(tail -n 3 "${TMP}/prepara.log")"
    return 0
  fi
  pass "prepara_esercizio.sh"
  vero "lo spazio di lavoro ha il gestionale" \
    test -f "${w}/progetti/gestionale-php/composer.json"
  vero "niente _docente del gestionale" \
    test ! -e "${w}/progetti/gestionale-php/_docente"
  vero "tools/php.sh, eseguibile" test -x "${w}/tools/php.sh"
  vero "lo script dell'hook" test -f "${w}/.claude/hooks/registra_caricamenti.py"
  vero "niente soluzione né _docente" \
    test ! -e "${w}/soluzione" -a ! -e "${w}/_docente"
  run command find "${w}" -name .git -prune -o -iname 'CLAUDE*.md' -print
  if [[ -z "${OUT}" ]]; then
    pass "nessun CLAUDE.md nello spazio di lavoro"
  else
    fail "un CLAUDE.md nello spazio di lavoro: ${OUT}"
  fi
  run git -C "${w}" status --porcelain
  if [[ -z "${OUT}" ]]; then
    pass "il punto di partenza ha git status vuoto"
  else
    fail "il punto di partenza ha git status vuoto: ${OUT}"
  fi
  run git -C "${w}" ls-files .gitignore .claude
  expect "nel primo commit: .gitignore e l'hook" 0 \
    '.claude/hooks/registra_caricamenti.py'
  verifica "${w}"
  expect "verifica.sh sul punto di partenza: 1" 1 'manca prima.md'
  expect_absent "sul punto di partenza nessun «Fatto»" "${FATTO}"
}

# ------------------------------------------------- i passi del README, finti

t_passi() {
  local w
  nuovo_ws w || { fail "lo spazio di lavoro"; return 0; }
  : > "${TMP}/log.jsonl"
  passi "${w}" FINTO_LOG="${TMP}/log.jsonl" 2
  expect "il passo 2 gira" 0 'Context Usage'
  run python3 -B -I - "${TMP}/log.jsonl" <<'PY'
import json, sys
righe = [json.loads(r) for r in open(sys.argv[1], encoding="utf-8")]
assert len(righe) == 1, len(righe)
r = righe[0]
assert r["argv"] == ["-p", "/context all", "--model", "sonnet",
                     "--setting-sources", "project,local",
                     "--strict-mcp-config"], r["argv"]
assert not r["chiave"] and not r["claude_md"], r
print("il comando del README")
PY
  expect "il passo 2: il comando, senza CLAUDE.md" 0 'il comando del README'
  verifica "${w}"
  expect "dopo il passo 2: 1, manca CLAUDE.md" 1 'manca CLAUDE.md'
  expect "prima.md senza CLAUDE.md" 1 'il CLAUDE.md dello spazio di lavoro non'
  passi "${w}" 3
  vero "il passo 3 scrive CLAUDE.md, due righe" \
    test "$(grep -c '' "${w}/CLAUDE.md" 2> /dev/null)" = 2
  verifica "${w}"
  expect "dopo il passo 3: 1, manca dopo.md" 1 'manca dopo.md'
  passi "${w}" 4
  expect "il passo 4 mostra il registro" 0 '"load_reason": "session_start"'
  verifica "${w}"
  expect "dopo il passo 4: 0" 0 "${FATTO}"
  expect "la prima garanzia" 0 "${G_CONTEXT} caricato all'avvio: confermata"
  expect "la seconda garanzia" 0 "${G_HOOK} (load_reason session_start):"
  expect "i token del file" 0 'c'"'"'è CLAUDE.md, 31 token (Project)'
  expect "la risposta che manca, come dato" 0 'risposta.txt non c'"'"'è'
  expect_absent "nessuna garanzia che non tiene" "${NON_CONF}"
  expect_absent "nessun percorso dello spazio di lavoro" "${w}"
  run env PN_WORKSPACE_ROOT="${w%/*}" "${RADICE}/tools/verifica.sh" M6-E01
  expect "tools/verifica.sh M6-E01" 0 'VERIFICA OK   M6-E01: fatto.'
  run python3 -B -I - "${w}/.claude/caricamenti.jsonl" <<'PY'
import json, sys
righe = [json.loads(r) for r in open(sys.argv[1], encoding="utf-8")]
assert righe and all(r["file_path"] == "CLAUDE.md" for r in righe), righe
assert all(r["load_reason"] == "session_start" for r in righe), righe
print("il registro relativo allo spazio di lavoro")
PY
  expect "il registro: CLAUDE.md, relativo" 0 'il registro relativo'
  run git -C "${w}" status --porcelain
  expect_absent "il registro non compare in git status" 'caricamenti'
}

# ------------------------------------------------- la risposta, come dato

t_risposta() {
  local w
  ws_fatto w
  export_finto "${w}" "Da ${w}/progetti/gestionale-php, ${HOME}: \`../../tools/php.sh phpunit\`, dice CLAUDE.md."
  verifica "${w}"
  expect "con risposta.txt: 0" 0 "${FATTO}"
  expect "la risposta, come dato" 0 '(dato) la risposta alla domanda: «Da'
  expect "il comando dei test nella risposta" 0 \
    '`../../tools/php.sh phpunit`: sì'
  expect "l'altro comando no" 0 '`../../tools/php.sh composer install`: no'
  expect "la risposta nomina CLAUDE.md" 0 'nomina CLAUDE.md: sì'
  expect "al posto dello spazio di lavoro" 0 '<spazio di lavoro>/progetti'
  expect_absent "mai il percorso dello spazio di lavoro" "${w}"
  expect_absent "mai la cartella di casa" "${HOME}"
  printf '%s\n' "❯ ${DOMANDA}" '' '● Bash(../../tools/php.sh phpunit)' \
    '  ⎿  Error: finto' '' '● Non lo so.' '' '✻ Finto' > "${w}/risposta.txt"
  verifica "${w}"
  expect "le chiamate agli strumenti non sono la risposta" 0 \
    '`../../tools/php.sh phpunit`: no'
  expect "la risposta dopo lo strumento" 0 'domanda: «Non lo so.»'
  printf '%s\n' '❯ Un'"'"'altra domanda' '' '● Sì.' > "${w}/risposta.txt"
  verifica "${w}"
  expect "senza la domanda del README: 0, e il dato lo dice" 0 \
    'la domanda del README non c'"'"'è'
  printf 'Solo la risposta: composer test.\n' > "${w}/risposta.txt"
  verifica "${w}"
  expect "non un /export: letto tutto, come dato" 0 \
    'non è l'"'"'uscita di /export'
  printf '\xff\xfe\n' > "${w}/risposta.txt"
  verifica "${w}"
  expect "una risposta non UTF-8: un dato, 0" 0 '(dato) la risposta non si legge'
  rm -f -- "${w}/risposta.txt"
  ( cd "${w}" && claude -p --model sonnet --output-format stream-json \
      --verbose -- "${DOMANDA}" > domanda.jsonl < /dev/null )
  verifica "${w}"
  expect "dallo stream: 0" 0 'domanda.jsonl, la domanda in claude -p'
  expect "dallo stream: i turni" 0 'turni 1; token 16243'
  expect "dallo stream: la risposta" 0 'Risposta finta del claude finto'
  expect_absent "dallo stream: mai la casa dello stream" '/home/finto'
  printf 'non json\n' > "${w}/domanda.jsonl"
  verifica "${w}"
  expect "uno stream rovinato: un dato, 0" 0 '(dato) la risposta non si legge'
}

# ------------------------------------------------- le garanzie e i passi

t_garanzie() {
  local w
  nuovo_ws w || { fail "lo spazio di lavoro"; return 0; }
  passi "${w}" 2 3
  passi "${w}" FINTO_SENZA_MEMORIA=1 4
  verifica "${w}"
  expect "/context senza CLAUDE.md: 1" 1 "${G_CONTEXT} caricato all'avvio: ${NON_CONF}"
  expect "e dice perché" 1 'CLAUDE.md c'"'"'era già'
  nuovo_ws w || { fail "lo spazio di lavoro"; return 0; }
  passi "${w}" FINTO_SENZA_HOOK=1 2 3 4
  verifica "${w}"
  expect "nessun caricamento nel registro: 1" 1 \
    "${G_HOOK} (load_reason session_start): ${NON_CONF}"
  expect "il registro che non c'è" 1 'non c'"'"'è, e dopo.md mostra'
  : > "${w}/.claude/caricamenti.jsonl"
  verifica "${w}"
  expect "un registro vuoto: 1" 1 'nessuna riga session_start'
  nuovo_ws w || { fail "lo spazio di lavoro"; return 0; }
  passi "${w}" 2 3
  passi "${w}" FINTO_SENZA_TABELLA=1 4
  verifica "${w}"
  expect "«Memory files» senza la tabella: 2" 2 'senza la tabella dei file'
  nuovo_ws w || { fail "lo spazio di lavoro"; return 0; }
  passi "${w}" 3 2 4
  verifica "${w}"
  expect "prima.md dopo CLAUDE.md: 1" 1 'prima.md ha già CLAUDE.md'
  expect_absent "e non è una garanzia che non tiene" "${NON_CONF}"
  nuovo_ws w || { fail "lo spazio di lavoro"; return 0; }
  passi "${w}" 2 4 3
  touch -d "@$(( $(date +%s) + 5 ))" "${w}/CLAUDE.md"
  verifica "${w}"
  expect "dopo.md prima di CLAUDE.md: 1" 1 'è di prima di CLAUDE.md'
  expect_absent "e non è una garanzia che non tiene" "${NON_CONF}"
  ws_fatto w
  printf 'Error: finto, non collegato\n' > "${w}/prima.md"
  verifica "${w}"
  expect "prima.md che non è /context: 1" 1 'prima.md non è l'"'"'uscita'
  ws_fatto w
  printf 'Error: finto\n' > "${w}/dopo.md"
  verifica "${w}"
  expect "dopo.md che non è /context: 1" 1 'dopo.md non è l'"'"'uscita'
  ws_fatto w
  printf '{"permissions": {}}\n' > "${w}/.claude/settings.json"
  verifica "${w}"
  expect "le impostazioni senza l'hook: 1" 1 'l'"'"'hook non è configurato'
  ws_fatto w
  rm -f -- "${w}/.claude/hooks/registra_caricamenti.py"
  verifica "${w}"
  expect "lo script dell'hook che manca: 1" 1 'non è configurato'
  ws_fatto w
  printf '{\n' > "${w}/.claude/settings.json"
  verifica "${w}"
  expect "le impostazioni che non sono JSON: 2" 2 'non è JSON'
  ws_fatto w
  printf 'non json\n' >> "${w}/.claude/caricamenti.jsonl"
  verifica "${w}"
  expect "un registro rovinato: 2" 2 'non è JSON'
  ws_fatto w
  printf '\xff\xfe\n' > "${w}/prima.md"
  verifica "${w}"
  expect "prima.md non UTF-8: 2" 2 'UTF-8'
  ws_fatto w
  printf '%s\n' '## Context Usage' '' '### Memory Files' '' \
    '| Type | Path | Tokens |' '|---|---|---|' \
    '| Project | /altrove/CLAUDE.md | 5 |' > "${w}/prima.md"
  verifica "${w}"
  expect "un CLAUDE.md di un'altra cartella non conta: 0" 0 "${FATTO}"
  expect "e si stampa come dato, senza percorso" 0 \
    'le righe sotto «Memory files»: 1 (Project, 5 token)'
  verifica
  expect "senza argomento: 2" 2 'spazio di lavoro assente'
  verifica "${TMP}/non-c-e"
  expect "una cartella che non c'è: 2" 2 'spazio di lavoro assente'
  expect_absent "mai un traceback" 'Traceback'
}

# ------------------------------------------------ soluzione/ e _docente/live.sh

t_soluzione() {
  local w
  run "${E01}/soluzione/applica.sh" "${TMP}/non-c-e"
  expect "applica.sh su una cartella che non c'è: 2" 2 'spazio di lavoro'
  nuovo_ws w || { fail "lo spazio di lavoro"; return 0; }
  vero "soluzione/LEGGIMI.md parla della registrazione" \
    grep -qi 'registrazione' "${E01}/soluzione/LEGGIMI.md"
  vero "soluzione/ non ha un CLAUDE.md" test ! -e "${E01}/soluzione/CLAUDE.md"
  if [[ ! -f "${E01}/soluzione/dopo.md" ]]; then
    skip "soluzione/: la registrazione non c'è ancora"
    run "${E01}/soluzione/applica.sh" "${w}"
    expect "applica.sh senza la registrazione: 2" 2 'non c'"'"'è ancora'
    skip "il CLAUDE.md di applica.sh"
    skip "con la soluzione: 0"
    skip "il README cita le righe della verifica"
    return 0
  fi
  pass "soluzione/: la registrazione c'è"
  run "${E01}/soluzione/applica.sh" "${w}"
  expect "applica.sh: 0" 0 ''
  comandi_del_passo "${TMP}/passo.sh" 3
  ( cd "${TMP}" && bash -euo pipefail "${TMP}/passo.sh" > /dev/null )
  vero "il CLAUDE.md di applica.sh è quello del README" \
    cmp -s "${w}/CLAUDE.md" "${TMP}/CLAUDE.md"
  verifica "${w}"
  expect "con la soluzione: 0" 0 "${FATTO}"
  printf '%s\n' "${OUT}" > "${TMP}/uscita.txt"
  run python3 -B -I - "${E01}/README.md" "${TMP}/uscita.txt" <<'PY'
import sys
readme = " ".join(open(sys.argv[1], encoding="utf-8").read().split())
uscita = [" ".join(r.split()) for r in open(sys.argv[2], encoding="utf-8")
          if r.strip()]
cercate = [r for r in uscita if r.startswith(("dopo.md:", "/context all",
                                              "l'hook", "(dato) i comandi"))]
mancanti = [r for r in cercate if r not in readme]
print("mancano: %r" % mancanti if mancanti or not cercate else "in ordine")
PY
  expect "il README cita le righe della verifica" 0 'in ordine'
}

t_live() {
  local w
  run "${E01}/_docente/live.sh"
  expect "live.sh senza argomenti: 2, e l'uso" 2 'uso: _docente/live.sh'
  run "${E01}/_docente/live.sh" "${TMP}/non-c-e"
  expect "live.sh senza spazio di lavoro: 2" 2 'spazio di lavoro assente'
  nuovo_ws w || { fail "lo spazio di lavoro"; return 0; }
  printf 'x\n' > "${w}/sporco.txt"
  : > "${TMP}/log.jsonl"
  run env FINTO_LOG="${TMP}/log.jsonl" "${E01}/_docente/live.sh" "${w}"
  expect "live.sh con del lavoro nello spazio: 2" 2 'reset_esercizio.sh M6-E01'
  vero "nessuna chiamata" test ! -s "${TMP}/log.jsonl"
  rm -f -- "${w}/sporco.txt"
  printf '{}\n' > "${w}/.claude/caricamenti.jsonl"
  run env FINTO_LOG="${TMP}/log.jsonl" "${E01}/_docente/live.sh" "${w}"
  expect "live.sh con il registro di prima, che git non vede: 2" 2 \
    'caricamenti.jsonl c'"'"'è già'
  rm -f -- "${w}/.claude/caricamenti.jsonl"
  run env HANDSON_ENV=trainer-api "${E01}/_docente/live.sh" "${w}"
  expect "live.sh con HANDSON_ENV trainer-api: 2" 2 'claude-code-pro'
  : > "${TMP}/log.jsonl"
  run env FINTO_LOG="${TMP}/log.jsonl" ANTHROPIC_API_KEY=finta \
    CLAUDE_CODE_EFFORT_LEVEL=high "${E01}/_docente/live.sh" "${w}"
  expect "live.sh: 0" 0 "${FATTO}"
  expect "live.sh: il verdetto" 0 'VERIFICA OK'
  expect "live.sh: i dati dello stream" 0 'domanda.jsonl, la domanda in claude -p'
  expect "live.sh: il comando si vede" 0 'claude -p '"'"'/context all'"'"
  vero "live.sh: lo stream della domanda" test -s "${w}/domanda.jsonl"
  comandi_del_passo "${TMP}/passo.sh" 3
  ( cd "${TMP}" && bash -euo pipefail "${TMP}/passo.sh" > /dev/null )
  vero "live.sh: il CLAUDE.md del README" \
    cmp -s "${w}/CLAUDE.md" "${TMP}/CLAUDE.md"
  run python3 -B -I - "${TMP}/log.jsonl" <<'PY'
import json, sys
righe = [json.loads(r) for r in open(sys.argv[1], encoding="utf-8")]
assert len(righe) == 3, len(righe)
contesto = ["-p", "/context all", "--model", "sonnet", "--setting-sources",
            "project,local", "--strict-mcp-config"]
assert righe[0]["argv"] == contesto and not righe[0]["claude_md"], righe[0]
assert righe[1]["argv"] == contesto and righe[1]["claude_md"], righe[1]
d = righe[2]
a = d["argv"]
def op(nome):
    return a[a.index(nome) + 1]
assert d["prompt"] == "Con quale comando si eseguono i test di questo progetto?"
assert a[-2] == "--" and a[0] == "-p", a
assert op("--allowedTools") == "Read,Glob,Grep", a
assert op("--model") == "sonnet" and op("--effort") == "low", a
assert op("--permission-mode") == "dontAsk", a
assert op("--permission-prompts") == "none", a
assert op("--output-format") == "stream-json" and "--verbose" in a, a
assert op("--setting-sources") == "project,local", a
assert "--strict-mcp-config" in a and "--no-session-persistence" in a, a
assert all(not r["chiave"] and not r["effort_env"] and r["stdin_nullo"]
           for r in righe), righe
print("ok, le chiamate")
PY
  expect "le chiamate del partecipante emulato" 0 'ok, le chiamate'
  nuovo_ws w || { fail "lo spazio di lavoro"; return 0; }
  run env FINTO_ESITO_KO_SE='/context' "${E01}/_docente/live.sh" "${w}"
  expect "live.sh con /context fallito: 1" 1 'claude -p è fallito'
  nuovo_ws w || { fail "lo spazio di lavoro"; return 0; }
  run env FINTO_SENZA_MEMORIA=1 "${E01}/_docente/live.sh" "${w}"
  expect "live.sh con la garanzia che non tiene: 1" 1 "${NON_CONF}"
}

t_run_all() {
  if [[ ! -f "${E01}/soluzione/dopo.md" ]]; then
    skip "run_all: la registrazione di soluzione/ non c'è ancora"
    skip "run_all --live: la registrazione di soluzione/ non c'è ancora"
    return 0
  fi
  run "${RADICE}/tools/run_all.sh" M6-E01
  expect "run_all: partenza e soluzione" 0 '1 ok, 0 KO'
  run "${RADICE}/tools/run_all.sh" --live M6-E01
  expect "run_all --live, con il finto" 0 'live ok'
}

t_shellcheck() {
  local f
  for f in "${E01}/verifica.sh" "${E01}/_docente/live.sh" \
      "${E01}/soluzione/applica.sh" "${SELF}"; do
    if shellcheck -x "${f}" > /dev/null 2>&1; then
      pass "shellcheck ${f#"${RADICE}"/}"
    else
      fail "shellcheck ${f#"${RADICE}"/}"
    fi
  done
}

main() {
  local t
  for t in python3 git shellcheck; do
    command -v "${t}" > /dev/null 2>&1 \
      || { echo "test_m6_e01: manca ${t}" >&2; exit 2; }
  done
  [[ -f "${FINTO_PY}" ]] \
    || { echo "test_m6_e01: manca ${FINTO_PY}" >&2; exit 2; }
  handson::init_temp_base
  TMP="$(mktemp -d "${HANDSON_TEMP_BASE}/test_m6_e01.XXXXXX")" || exit 2
  trap 'chmod -R u+rwX "${TMP}" 2>/dev/null; rm -rf "${TMP}"' EXIT
  prepara_claude
  t_elemento
  t_readme
  t_prepara
  t_passi
  t_risposta
  t_garanzie
  t_soluzione
  t_live
  t_run_all
  t_shellcheck
  OUT="${TUTTO}"
  expect_absent "in nessuna uscita «smentita»" "smentita"
  echo "PASS=${PASS} FAIL=${FAIL} SKIP=${SKIP}"
  if (( PASS + FAIL + SKIP != CASES )); then
    echo "test_m6_e01: girati $((PASS + FAIL + SKIP)) casi, attesi" \
      "${CASES}" >&2
    exit 2
  fi
  (( FAIL == 0 )) || exit 1
}

main "$@"
