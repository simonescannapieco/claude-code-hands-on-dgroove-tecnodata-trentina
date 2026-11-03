#!/bin/bash
#
# test_m5_e01.sh -- le prove di M5-E01 «La prima skill», per il docente (sta in
# _docente/, il materiale del docente):
#   - l'elemento: esercizio/controlla_skill.py e il suo lettore, copie byte per
#     byte di quelli di tools/; la skill di riferimento, che passa il controllo,
#     con i campi e le righe ! che il disegno chiede e senza allowed-tools; il
#     README: le frasi di Anthropic con il loro indirizzo, il prompt sotto le 60
#     parole, nessun nome interno;
#   - prepara_esercizio.sh e prepara_modifica.sh;
#   - esercizio/prova.sh con il claude finto: una sessione nuova con le sue
#     opzioni, lo stream in prova/stream.jsonl, le prove di prima conservate;
#     le precondizioni (2), una chiamata fallita (1);
#   - verifica.sh sulla skill e sullo stream: buoni (0), cattivi (1), assenti
#     (1, 2); la chiamata Skill, il file nominato e gli strumenti stampati come
#     dati, mai come uscita;
#   - soluzione/applica.sh; _docente/live.sh, il partecipante emulato;
#   - check_handson.sh senza segnalazioni su questo elemento; shellcheck.
# Mai il claude vero: il finto sta davanti nel PATH, e la suite lo controlla
# prima di usarlo. Gli stream del finto non sono risposte di Claude: provano la
# verifica, non il modello. Gli spazi di lavoro nascono in una cartella
# temporanea, nella base di handson::init_temp_base (mai dentro ~/.claude):
# l'albero del repository non cambia. CASES è il numero dei casi: se ne girano
# di più o di meno la suite esce 2.
#
# Uso:    m5_skills/_docente/test_m5_e01.sh
# Uscita: 0 = tutti i casi passano · 1 = almeno un caso fallito · 2 =
#         precondizione (manca python3, git o shellcheck; il finto non viene
#         prima nel PATH), o un numero di casi diverso da CASES
# shellcheck disable=SC2016  # backtick e $ sono il testo delle prove
set -uo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly MOD="${SELF%/_docente/*}"
readonly RADICE="${MOD%/*}"
readonly E01="${MOD}/s4_skills/m5_e1_la_prima_skill/M5-E01_la_prima_skill"
readonly FINTO_PY="${MOD}/_docente/claude_finto_m5_d03_e01.py"
# La libreria del repository, per la base dei file temporanei.
# shellcheck source=../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"
readonly CASES=211
readonly SKILL_REL=.claude/skills/riassunto-modifiche
readonly FATTO='Fatto: la skill passa il controllo'
readonly D_CHIAMATA='(dato) la chiamata Skill sulla domanda naturale'
readonly D_FILE='(dato) il file cambiato nella risposta'
readonly D_STRUMENTI='(dato) gli strumenti, oltre a Skill, prima della risposta'
readonly D_CORPO='(dato) il corpo arrivato a Claude'
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
    fail "$1 (rc=${RC}, attesa $2, parola «$3»): ${OUT:0:800}"
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
  mkdir -p "${TMP}/finto" "${TMP}/sessioni" || exit 2
  cp -- "${FINTO_PY}" "${TMP}/finto/claude" || exit 2
  chmod +x "${TMP}/finto/claude" || exit 2
  export PATH="${TMP}/finto:${PATH}"
  export FINTO_SESSIONI="${TMP}/sessioni"
  export HANDSON_NO_PAUSE=1
  unset ANTHROPIC_API_KEY CLAUDE_CODE_EFFORT_LEVEL HANDSON_ENV
  [[ "$(command -v claude)" == "${TMP}/finto/claude" ]] \
    || { echo "test_m5_e01: il finto non viene prima nel PATH" >&2; exit 2; }
}

# Uno spazio di lavoro nuovo, con prepara_esercizio.sh in una radice nuova.
# Arguments: $1 la variabile da assegnare. Returns: 0; 1 se non riesce.
nuovo_ws() {
  local __r
  __r="$(mktemp -d "${TMP}/radice.XXXXXX")" || exit 2
  "${RADICE}/tools/prepara_esercizio.sh" M5-E01 --radice "${__r}" \
    > "${TMP}/prepara.log" 2>&1 || return 1
  printf -v "$1" '%s' "${__r}/M5-E01"
}

# Uno spazio di lavoro con la modifica e la skill di riferimento.
# Arguments: $1 la variabile da assegnare.
ws_con_skill() {
  local __w
  nuovo_ws __w || exit 2
  bash "${__w}/prepara_modifica.sh" > /dev/null || exit 2
  mkdir -p "${__w}/.claude/skills" || exit 2
  cp -R "${E01}/soluzione/${SKILL_REL}" "${__w}/.claude/skills/" || exit 2
  printf -v "$1" '%s' "${__w}"
}

# prova.sh dello spazio di lavoro $1, con le variabili che seguono; RC e OUT
# come run, la riga di ogni chiamata in $TMP/log.jsonl.
prova() {
  local w="$1"
  shift
  : > "${TMP}/log.jsonl"
  run env FINTO_LOG="${TMP}/log.jsonl" FINTO_SPAZIO="${w}" "$@" \
    bash "${w}/prova.sh"
}

# verifica.sh dell'elemento sullo spazio di lavoro $1; RC e OUT come run.
verifica() { run "${E01}/verifica.sh" "$@"; }

# Il numero di righe di $TMP/log.jsonl: le chiamate al finto.
chiamate() { grep -c '' "${TMP}/log.jsonl"; }

# ---------------------------------------------------------------- l'elemento

t_elemento() {
  local f
  for f in README.md verifica.sh verifica.py progetti.txt esercizio/prova.sh \
      esercizio/prepara_modifica.sh esercizio/.gitignore _docente/live.sh \
      soluzione/applica.sh soluzione/LEGGIMI.md \
      "soluzione/${SKILL_REL}/SKILL.md"; do
    vero "c'è ${f}" test -f "${E01}/${f}"
  done
  for f in controlla_skill.py lib_leggi_frontmatter.py; do
    vero "esercizio/${f} è una copia byte per byte di tools/${f}" \
      cmp -s "${E01}/esercizio/${f}" "${RADICE}/tools/${f}"
  done
  vero "verifica.sh è eseguibile" test -x "${E01}/verifica.sh"
  vero "live.sh è eseguibile" test -x "${E01}/_docente/live.sh"
  vero "applica.sh è eseguibile" test -x "${E01}/soluzione/applica.sh"
  vero "progetti.txt nomina le urgenze" \
    grep -qFx 'progetti/urgenze' "${E01}/progetti.txt"
  vero "prova/ è fuori da git" grep -qFx 'prova/' "${E01}/esercizio/.gitignore"
  vero "la cartella delle skill c'è fin dal punto di partenza" \
    test -f "${E01}/esercizio/.claude/skills/.gitkeep"
  vero "esercizio/.claude/settings.json è una copia di quello della radice" \
    cmp -s "${E01}/esercizio/.claude/settings.json" \
    "${RADICE}/.claude/settings.json"
}

t_riferimento() {
  local s="${E01}/soluzione/${SKILL_REL}/SKILL.md"
  run python3 -B -I "${RADICE}/tools/controlla_skill.py" "${s%/SKILL.md}"
  expect "la skill di riferimento: controlla_skill.py senza errori" 0 \
    'riassunto-modifiche: 0 errori'
  expect_absent "e senza avvisi sulla description" 'description:'
  vero "name" grep -qFx 'name: riassunto-modifiche' "${s}"
  vero "«Da usare quando si chiede che cosa è cambiato»" \
    grep -qF 'Da usare quando si chiede che cosa è cambiato' "${s}"
  vero "compatibility" \
    grep -qFx 'compatibility: Requires Claude Code and git' "${s}"
  if grep -q '^allowed-tools:' "${s}"; then
    fail "nessun allowed-tools"
  else
    pass "nessun allowed-tools"
  fi
  vero "!\`git status --short\`" grep -qFx '!`git status --short`' "${s}"
  vero "!\`git diff HEAD\`" grep -qFx '!`git diff HEAD`' "${s}"
  vero "i passi numerati" grep -qE '^1\. ' "${s}"
  vero "il terzo passo: niente modifiche" grep -qE '^3\. ' "${s}"
  vero "il terzo passo: «di'», l'imperativo di dire" \
    grep -qF "3. Se non ci sono modifiche, di' che" "${s}"
  vero "un modello della risposta" grep -q '^## Modello della risposta' "${s}"
  vero "un esempio" grep -q '^## Esempio' "${s}"
  if grep -qE '<(role|context|instructions|format|constraints)>' "${s}"; then
    fail "nessun tag del corso nello SKILL.md"
  else
    pass "nessun tag del corso nello SKILL.md"
  fi
}

t_readme() {
  local testo frase parola richiesta parole
  testo="$(LC_ALL=C tr -s '[:space:]' ' ' < "${E01}/README.md")"
  while IFS= read -r frase; do
    if [[ "${testo}" == *"${frase}"* ]]; then
      pass "README: «${frase:0:48}…»"
    else
      fail "README: manca «${frase}»"
    fi
  done <<'FRASI'
Claude uses skills when relevant, or you can invoke one directly with /skill-name.
The command output replaces the placeholder, so Claude receives actual data, not the command itself.
A fresh session matters because leftover context from authoring the skill will mask gaps in the written instructions.
To find SKILL.md files whose frontmatter doesn't parse, run claude plugin validate on the skills directory
YAML frontmatter failed to parse
No description in frontmatter.
Run /skill-doctor to see what each of your skills costs and how often it gets used, so you can decide which ones to turn off.
context = this skill's one-line listing in the system prompt, included every turn
To see which skills synced, run /skills. The menu lists them under claude.ai sync.
Yes, and allow Claude to edit files in this project's .claude folder for this session
https://code.claude.com/docs/en/permission-modes
Use the skills-ref reference library to validate your skills
https://code.claude.com/docs/en/skills
https://agentskills.io/specification
tools/prepara_esercizio.sh M5-E01
tools/verifica.sh M5-E01
bash prepara_modifica.sh
bash prova.sh
/riassunto-modifiche
/skill-doctor
claude plugin validate .claude/skills
riferimenti/template-SKILL.md
If you create a top-level skills directory that didn't exist when the session started, run /reload-skills to pick up the skills you put there.
/skill-doctor moved — skill usage and context costs now live in this Stats tab.
il cursore parte da «No, exit»
Yes, I trust this folder
This command requires approval
python3 -B -I controlla_skill.py .claude/skills/riassunto-modifiche
si chiude con Esc
«VERIFICA OK M5-E01: fatto.»
FRASI
  for parola in 'FACT-' 'M5-X' 'X-37' 'X-38' 'smentit' 'probe' 'oggi' \
      'primo esempio' '9.5 s' '16.2 s' '9.4 s' '1 avvisi'; do
    if [[ "${testo}" == *"${parola}"* ]]; then
      fail "README: «${parola}» non ci sta"
    else
      pass "README: niente «${parola}»"
    fi
  done
  if grep -qF 'primo esempio' "${E01}/soluzione/LEGGIMI.md"; then
    fail "LEGGIMI: «primo esempio» non ci sta: nessuna fonte lo dice"
  else
    pass "LEGGIMI: niente «primo esempio»"
  fi
  richiesta="$(sed -n '/<!-- prompt 1 -->/,/<!-- \/prompt 1 -->/p' \
    "${E01}/README.md" | sed -e '/<!-- /d')"
  parole="$(wc -w <<< "${richiesta}")"
  if (( parole > 0 && parole < 60 )); then
    pass "il prompt sta sotto le 60 parole (${parole})"
  else
    fail "il prompt: ${parole} parole, non da 1 a 59"
  fi
  vero "il prompt nomina il comando del controllo" grep -qF \
    'python3 -B -I controlla_skill.py .claude/skills/riassunto-modifiche' \
    <<< "${richiesta}"
  vero "il prompt chiede le due righe !" grep -qF \
    '!`git diff HEAD`' <<< "${richiesta}"
}

# ------------------------------------------------------ il punto di partenza

t_prepara() {
  local w
  if ! nuovo_ws w; then
    fail "prepara_esercizio.sh: $(tail -n 3 "${TMP}/prepara.log")"
    return 0
  fi
  pass "prepara_esercizio.sh"
  vero "lo spazio di lavoro ha le urgenze" \
    test -f "${w}/progetti/urgenze/urgenza.py"
  vero "niente _docente delle urgenze" \
    test ! -e "${w}/progetti/urgenze/_docente"
  vero "lo spazio di lavoro ha prova.sh" test -f "${w}/prova.sh"
  vero "e il controllo della skill, che gira da lì" \
    test -f "${w}/lib_leggi_frontmatter.py"
  vero "niente soluzione né _docente" \
    test ! -e "${w}/soluzione" -a ! -e "${w}/_docente"
  vero "nessuna skill nel punto di partenza" \
    test ! -e "${w}/${SKILL_REL}"
  vero "ma la cartella delle skill c'è già, prima della sessione" \
    test -d "${w}/.claude/skills"
  vero "e le impostazioni sono quelle del repository" \
    cmp -s "${w}/.claude/settings.json" "${RADICE}/.claude/settings.json"
  run git -C "${w}" ls-files .claude
  expect "nel primo commit: la cartella delle skill" 0 '.claude/skills/.gitkeep'
  expect "nel primo commit: le impostazioni" 0 '.claude/settings.json'
  run git -C "${w}" status --porcelain
  if [[ -z "${OUT}" ]]; then
    pass "il punto di partenza ha git status vuoto"
  else
    fail "il punto di partenza ha git status vuoto: ${OUT}"
  fi
  verifica "${w}"
  expect "verifica.sh sul punto di partenza: 1" 1 'manca la skill'
  expect_absent "sul punto di partenza nessun «Fatto»" "${FATTO}"
}

t_modifica() {
  local w
  nuovo_ws w || { fail "lo spazio di lavoro"; return 0; }
  run bash "${w}/prepara_modifica.sh"
  expect "prepara_modifica.sh" 0 'urgenza.py'
  run git -C "${w}" status --short
  expect "git vede la modifica" 0 ' M progetti/urgenze/urgenza.py'
  if [[ "$(git -C "${w}" status --short | grep -c '')" == 1 ]]; then
    pass "un file solo cambiato"
  else
    fail "un file solo cambiato: $(git -C "${w}" status --short)"
  fi
  vero "la soglia nel codice cambia" \
    grep -qF 'clienti >= 5' "${w}/progetti/urgenze/urgenza.py"
  vero "la docstring no" \
    grep -qF 'almeno 10 clienti' "${w}/progetti/urgenze/urgenza.py"
  run bash "${w}/prepara_modifica.sh"
  expect "una seconda volta: 0, già fatta" 0 'già'
  printf 'x = 1\n' > "${w}/progetti/urgenze/urgenza.py"
  run bash "${w}/prepara_modifica.sh"
  expect "un urgenza.py diverso: 2" 2 'non trovo'
  rm -f "${w}/progetti/urgenze/urgenza.py"
  run bash "${w}/prepara_modifica.sh"
  expect "senza urgenza.py: 2" 2 'manca'
}

# --------------------------------------------------------------- prova.sh

t_prova() {
  local w
  ws_con_skill w
  prova "${w}"
  expect "prova.sh: 0" 0 'Riassunto (finto)'
  expect "il comando si vede" 0 'claude -p'
  vero "lo stream in prova/stream.jsonl" test -s "${w}/prova/stream.jsonl"
  run python3 -B -I - "${TMP}/log.jsonl" "${w}" <<'PY'
import json, sys
righe = [json.loads(r) for r in open(sys.argv[1], encoding="utf-8")]
assert len(righe) == 1, len(righe)
r = righe[0]
a = r["argv"]
def op(nome):
    return a[a.index(nome) + 1]
assert a[0] == "-p" and a[-2] == "--"
assert r["prompt"] == "Che cosa ho cambiato?", r["prompt"]
assert op("--allowedTools") == "Read,Skill(riassunto-modifiche)"
assert op("--model") == "sonnet" and op("--effort") == "low"
assert op("--permission-mode") == "dontAsk"
assert op("--permission-prompts") == "none"
assert op("--output-format") == "stream-json" and "--verbose" in a
assert op("--setting-sources") == "project,local"
assert "--strict-mcp-config" in a and "--no-session-persistence" in a
assert "--resume" not in a
assert not r["chiave"] and not r["effort_env"] and r["stdin_nullo"]
assert r["cwd"] == sys.argv[2], r["cwd"]
print("ok, le opzioni")
PY
  expect "le opzioni di prova.sh" 0 'ok, le opzioni'
  run git -C "${w}" status --short
  expect_absent "prova/ non compare in git status" 'prova/'
  prova "${w}"
  expect "una seconda prova: 0" 0 'Riassunto (finto)'
  vero "la prova di prima resta" test -s "${w}/prova/stream-1.jsonl"
  vero "e l'ultima è stream.jsonl" test -s "${w}/prova/stream.jsonl"
  prova "${w}" ANTHROPIC_API_KEY=finta CLAUDE_CODE_EFFORT_LEVEL=high
  if grep -q '"chiave": true\|"effort_env": true' "${TMP}/log.jsonl"; then
    fail "ANTHROPIC_API_KEY o CLAUDE_CODE_EFFORT_LEVEL arrivano a claude"
  else
    pass "ANTHROPIC_API_KEY e CLAUDE_CODE_EFFORT_LEVEL non arrivano a claude"
  fi
  vero "la terza prova: stream-2.jsonl" test -s "${w}/prova/stream-2.jsonl"
}

t_prova_male() {
  local w
  nuovo_ws w || { fail "lo spazio di lavoro"; return 0; }
  prova "${w}"
  expect "prova.sh senza la skill: 2" 2 'manca la skill'
  vero "senza la skill nessuna chiamata" test ! -s "${TMP}/log.jsonl"
  ws_con_skill w
  run env PATH="${TMP}/solo" "$(command -v bash)" "${w}/prova.sh"
  expect "prova.sh senza claude nel PATH: 2" 2 'manca claude'
  prova "${w}" FINTO_ESITO_KO_SE=cambiato
  expect "una chiamata fallita: 1" 1 'claude -p è fallito'
  vero "nessuno stream da una chiamata fallita" \
    test ! -e "${w}/prova/stream.jsonl"
  verifica "${w}"
  expect "verifica.sh dopo una chiamata fallita: 1" 1 'manca la prova'
}

# ------------------------------------------------------------- verifica.sh

t_verifica_buona() {
  local w
  ws_con_skill w
  prova "${w}"
  verifica "${w}"
  expect "la skill e la prova: 0" 0 "${FATTO}"
  expect "il controllo della skill si vede" 0 'riassunto-modifiche: 0 errori'
  expect "il dato della chiamata" 0 "${D_CHIAMATA}: sì"
  expect "il dato del file" 0 "${D_FILE}: urgenza.py: sì"
  expect "il dato degli strumenti" 0 "${D_STRUMENTI}: nessuno"
  expect "il dato del corpo" 0 \
    "${D_CORPO}: nessun !\`comando\` rimasto: sì; urgenza.py: sì"
  expect "il riepilogo delle prove" 0 'la chiamata Skill riuscita in 1 su 1'
  expect_absent "sul conto pulito nessuna prova lasciata fuori" 'non lett'
  expect "i consumi" 0 'turni'
  expect "i secondi con la virgola" 0 '1,0 s'
  expect_absent "mai con il punto" '1.0 s'
  expect "un avviso, al singolare" 0 '0 errori, 1 avviso'
  expect_absent "nessun «1 avvisi»" '1 avvisi'
  expect_absent "nessun «Non ancora»" 'Non ancora'
  prova "${w}"
  verifica "${w}"
  expect "due prove: 2 su 2" 0 'la chiamata Skill riuscita in 2 su 2'
  run env PN_WORKSPACE_ROOT="${w%/*}" "${RADICE}/tools/verifica.sh" M5-E01
  expect "tools/verifica.sh M5-E01" 0 'VERIFICA OK'
}

# Ciò che non decide l'uscita: stampato, e l'uscita resta 0.
t_verifica_dati() {
  local w
  ws_con_skill w
  prova "${w}" FINTO_SENZA_CHIAMATA=1
  verifica "${w}"
  expect "senza la chiamata: 0" 0 "${FATTO}"
  expect "senza la chiamata: il dato dice no" 0 "${D_CHIAMATA}: no"
  expect "senza la chiamata: il corpo non c'è" 0 \
    "${D_CORPO}: nello stream non c'è"
  ws_con_skill w
  prova "${w}" FINTO_NON_NOMINA=1
  verifica "${w}"
  expect "il file non nominato: 0" 0 "${FATTO}"
  expect "il file non nominato: il dato dice no" 0 "${D_FILE}: urgenza.py: no"
  ws_con_skill w
  prova "${w}" FINTO_CON_STRUMENTI=1
  verifica "${w}"
  expect "uno strumento prima della risposta: 0" 0 "${FATTO}"
  expect "uno strumento: il dato lo nomina" 0 "${D_STRUMENTI}: Bash 1"
  # Una skill con allowed-tools: la regola Skill(...) di prova.sh la fa girare.
  ws_con_skill w
  sed -i 's/^compatibility:/allowed-tools: Read\n&/' \
    "${w}/${SKILL_REL}/SKILL.md"
  prova "${w}"
  verifica "${w}"
  expect "una skill con allowed-tools: la chiamata passa" 0 "${D_CHIAMATA}: sì"
  # Una chiamata negata: un finto senza la regola, com'è senza Skill(...).
  run python3 -B -I - "${w}/prova/stream.jsonl" <<'PY'
import json, sys
righe = [json.loads(r) for r in open(sys.argv[1], encoding="utf-8")]
ident = None
for e in righe:
    if e.get("type") == "assistant":
        for b in e["message"]["content"]:
            if b.get("name") == "Skill":
                ident = b["id"]
for e in righe:
    if e.get("type") == "result":
        e["permission_denials"] = [{"tool_name": "Skill", "tool_use_id": ident}]
with open(sys.argv[1], "w", encoding="utf-8") as fh:
    for e in righe:
        fh.write(json.dumps(e, ensure_ascii=False) + "\n")
PY
  verifica "${w}"
  expect "una chiamata negata: 0, e il dato lo dice" 0 "negata dal permesso"
  expect_absent "e non è «respinta»" "respinta"
  # Una chiamata che lo strumento respinge: un altro motivo, un altro rimedio.
  ws_con_skill w
  prova "${w}"
  run python3 -B -I - "${w}/prova/stream.jsonl" <<'PY'
import json, sys
righe = [json.loads(r) for r in open(sys.argv[1], encoding="utf-8")]
ident = None
for e in righe:
    if e.get("type") == "assistant":
        for b in e["message"]["content"]:
            if b.get("name") == "Skill":
                ident = b["id"]
for e in righe:
    contenuto = e.get("message", {}).get("content")
    if e.get("type") == "user" and isinstance(contenuto, list):
        for b in contenuto:
            if b.get("tool_use_id") == ident:
                b["is_error"] = True
with open(sys.argv[1], "w", encoding="utf-8") as fh:
    for e in righe:
        fh.write(json.dumps(e, ensure_ascii=False) + "\n")
PY
  verifica "${w}"
  expect "una chiamata respinta: 0, e il dato lo dice" 0 \
    "respinta dallo strumento"
  expect_absent "e non è «negata dal permesso»" "negata dal permesso"
  # Le prove che il conto lascia fuori si dicono: mai un N più piccolo in
  # silenzio.
  ws_con_skill w
  prova "${w}" FINTO_ERRORE=1
  prova "${w}" FINTO_TRONCO=1
  prova "${w}"
  prova "${w}"
  verifica "${w}"
  expect "due prove fuori dal conto: 0, e il dato lo dice" 0 \
    'riuscita in 2 su 2; 2 non lette o fallite'
  printf 'non json\n' > "${w}/prova/stream-1.jsonl"
  rm -f "${w}/prova/stream-2.jsonl"
  verifica "${w}"
  expect "una prova sola fuori dal conto, anche illeggibile" 0 \
    'riuscita in 2 su 2; 1 non letta o fallita'
  # Nessuna modifica: il dato lo dice.
  ws_con_skill w
  git -C "${w}" checkout -q -- progetti/urgenze/urgenza.py
  prova "${w}"
  verifica "${w}"
  expect "senza modifiche: 0" 0 "${FATTO}"
  expect "senza modifiche: il dato lo dice" 0 'nessun file cambiato'
  # Un git diff che non riesce non è «nessun file cambiato».
  ws_con_skill w
  prova "${w}"
  printf 'non è un riferimento\n' > "${w}/.git/HEAD"
  verifica "${w}"
  expect "un git diff che non riesce: 2" 2 'git diff'
  expect_absent "e non è «nessun file cambiato»" 'nessun file cambiato'
}

t_verifica_male() {
  local w
  verifica
  expect "senza argomento: 2" 2 'spazio di lavoro assente'
  verifica "${TMP}/non-c-e"
  expect "una cartella che non c'è: 2" 2 'spazio di lavoro assente'
  expect_absent "mai un traceback" 'Traceback'
  ws_con_skill w
  verifica "${w}"
  expect "la skill senza la prova: 1" 1 'manca la prova'
  expect_absent "senza la prova nessun «Fatto»" "${FATTO}"
  prova "${w}"
  sed -i '/^description:/d' "${w}/${SKILL_REL}/SKILL.md"
  verifica "${w}"
  expect "senza description: 1" 1 'description: manca'
  expect "un errore, al singolare, nella riga del controllo" 1 \
    'riassunto-modifiche: 1 errore,'
  expect "un errore, al singolare, in ciò che manca" 1 \
    'la skill ha 1 errore (qui sopra)'
  expect_absent "senza description nessun «Fatto»" "${FATTO}"
  ws_con_skill w
  prova "${w}"
  sed -i 's/^name: .*/name: un-altro-nome/' "${w}/${SKILL_REL}/SKILL.md"
  verifica "${w}"
  expect "name diverso dalla cartella: 1" 1 'name:'
  ws_con_skill w
  prova "${w}"
  sed -i '/^!`/d' "${w}/${SKILL_REL}/SKILL.md"
  verifica "${w}"
  expect "senza righe !: 1" 1 'nessuna riga'
  ws_con_skill w
  prova "${w}"
  sed -i -e 's/^!`git status --short`$/```\n&\n```/' \
    -e '/^!`git diff HEAD`$/d' "${w}/${SKILL_REL}/SKILL.md"
  verifica "${w}"
  expect "una riga ! soltanto in un blocco di codice: 1" 1 'nessuna riga'
  ws_con_skill w
  prova "${w}" FINTO_TRONCO=1
  verifica "${w}"
  expect "una prova interrotta: 1" 1 'non è completa'
  ws_con_skill w
  prova "${w}" FINTO_ERRORE=1
  verifica "${w}"
  expect "una prova finita con un errore: 1" 1 'non è completa'
  ws_con_skill w
  prova "${w}"
  printf 'non json\n' >> "${w}/prova/stream.jsonl"
  verifica "${w}"
  expect "uno stream rovinato: 1" 1 'non si legge'
  ws_con_skill w
  prova "${w}"
  : > "${w}/prova/stream.jsonl"
  verifica "${w}"
  expect "uno stream vuoto: 1" 1 'non è completa'
  ws_con_skill w
  mkdir -p "${w}/prova/stream.jsonl"
  verifica "${w}"
  expect "uno stream che è una cartella: 2" 2 'stream.jsonl'
  # verifica.sh usa il controllo del repository, non la copia dello spazio.
  ws_con_skill w
  prova "${w}"
  sed -i '/^description:/d' "${w}/${SKILL_REL}/SKILL.md"
  printf 'import sys\nsys.exit(0)\n' > "${w}/controlla_skill.py"
  verifica "${w}"
  expect "non si fida della copia del controllo nello spazio di lavoro" 1 \
    'description: manca'
}

# La copia del controllo gira nello spazio di lavoro, come dice il prompt.
t_controllo_copia() {
  local w
  ws_con_skill w
  run bash -c 'cd "$1" && python3 -B -I controlla_skill.py "$2"' _ "${w}" \
    "${SKILL_REL}"
  expect "il controllo dallo spazio di lavoro: 0" 0 '0 errori'
  sed -i '/^description:/d' "${w}/${SKILL_REL}/SKILL.md"
  run bash -c 'cd "$1" && python3 -B -I controlla_skill.py "$2"' _ "${w}" \
    "${SKILL_REL}"
  expect "il controllo su una skill senza description: 1" 1 'ERRORE description'
}

# ------------------------------------------------ soluzione/ e _docente/live.sh

t_soluzione() {
  local w
  nuovo_ws w || { fail "lo spazio di lavoro"; return 0; }
  run "${E01}/soluzione/applica.sh" "${w}"
  vero "applica.sh: la skill c'è" test -f "${w}/${SKILL_REL}/SKILL.md"
  vero "applica.sh: la modifica c'è" \
    grep -qF 'clienti >= 5' "${w}/progetti/urgenze/urgenza.py"
  run "${E01}/soluzione/applica.sh" "${TMP}/non-c-e"
  expect "applica.sh su una cartella che non c'è: 2" 2 'spazio di lavoro'
  vero "soluzione/LEGGIMI.md parla della registrazione" \
    grep -qi 'registrazione' "${E01}/soluzione/LEGGIMI.md"
  if [[ ! -f "${E01}/soluzione/prova/stream.jsonl" ]]; then
    skip "soluzione/prova: la registrazione non c'è ancora"
    verifica "${w}"
    expect "con la soluzione senza lo stream: 1" 1 'manca la prova'
    return 0
  fi
  pass "soluzione/prova: la registrazione c'è"
  verifica "${w}"
  expect "con la soluzione e la registrazione: 0" 0 "${FATTO}"
  printf '%s\n' "${OUT}" > "${TMP}/uscita.txt"
  # Il README cita le righe che la verifica stampa sulla registrazione.
  run python3 -B -I "${MOD}/_docente/controlla_registrazione.py" \
    "${E01}/README.md" "${TMP}/uscita.txt" <<'FRASI'
= (dato) tutte le prove di prova/: la chiamata Skill riuscita in 3 su 3
= (dato) la chiamata Skill sulla domanda naturale: sì
= (dato) il file cambiato nella risposta: urgenza.py: sì
= (dato) gli strumenti, oltre a Skill, prima della risposta: nessuno
= (dato) il corpo arrivato a Claude: nessun !`comando` rimasto: sì; urgenza.py: sì
= chiamate Skill: 0; strumenti: nessuno; il file nella risposta: urgenza.py: sì; turni 1; token 19192; 9,5 s
= riassunto-modifiche projectSettings ~80 - 0× never
= turni 4; token 58870; 16,2 s
= turni 3; token 36620; 9,4 s
= controlla_skill: riassunto-modifiche: 0 errori, 1 avviso
R Nella registrazione del corso (3 novembre 2026, Claude Code 2.1.317, Sonnet con effort low
R sull'account del docente, un piano Max
R bozza/
R 36.583
R 36.548
! La scrive il docente
FRASI
  expect "il README cita le righe della verifica" 0 "in ordine"
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
  expect "live.sh con del lavoro nello spazio: 2" 2 'reset_esercizio.sh M5-E01'
  vero "nessuna chiamata" test ! -s "${TMP}/log.jsonl"
  rm -f "${w}/sporco.txt"
  # prova/ è in .gitignore: git status non vede gli stream di prima.
  mkdir -p "${w}/prova"
  printf '{}\n' > "${w}/prova/stream.jsonl"
  : > "${TMP}/log.jsonl"
  run env FINTO_LOG="${TMP}/log.jsonl" "${E01}/_docente/live.sh" "${w}"
  expect "live.sh con le prove di prima: 2" 2 'reset_esercizio.sh M5-E01'
  expect "e dice perché" 2 'prova/'
  vero "nessuna chiamata con le prove di prima" test ! -s "${TMP}/log.jsonl"
  rm -rf "${w}/prova"
  run env HANDSON_ENV=trainer-api "${E01}/_docente/live.sh" "${w}"
  expect "live.sh con HANDSON_ENV trainer-api: 2" 2 'claude-code-pro'
  run env FINTO_LOG="${TMP}/log.jsonl" FINTO_SPAZIO="${w}" \
    "${E01}/_docente/live.sh" "${w}"
  expect "live.sh: 0" 0 "${FATTO}"
  expect "live.sh: «n su 3»" 0 'la chiamata Skill riuscita in 3 su 3'
  expect "live.sh: il dato di /nome" 0 '(dato) /riassunto-modifiche'
  expect "live.sh: il dato di /skill-doctor" 0 '(dato) /skill-doctor'
  expect "live.sh: la prova di plugin validate" 0 'Validation passed'
  run python3 -B -I - "${TMP}/log.jsonl" "${w}" "${E01}/README.md" <<'PY'
import json, re, sys
righe = [json.loads(r) for r in open(sys.argv[1], encoding="utf-8")]
ws = sys.argv[2]
readme = open(sys.argv[3], encoding="utf-8").read()
blocco = re.search(r"<!-- prompt 1 -->\n(.*?)\n\s*<!-- /prompt 1 -->", readme,
                   re.S).group(1)
atteso = "\n".join(r[7:] for r in blocco.strip("\n").split("\n"))
assert ".claude/skills/riassunto-modifiche" in atteso
atteso = atteso.replace(".claude/skills/riassunto-modifiche",
                        "bozza/riassunto-modifiche")
prompt = [r for r in righe if r["argv"][:2] != ["plugin", "validate"]]
assert prompt[0]["prompt"] == atteso.strip(), prompt[0]["prompt"]
a = prompt[0]["argv"]
regole = "Write,Read,Edit,Bash(python3 -B -I controlla_skill.py *)"
assert a[a.index("--allowedTools") + 1] == regole, a
assert a[a.index("--effort") + 1] == "low"
assert "--strict-mcp-config" in a and "--no-session-persistence" in a
assert a[a.index("--output-format") + 1] == "stream-json"
domande = [r for r in prompt if r["prompt"] == "Che cosa ho cambiato?"]
assert len(domande) == 3, len(domande)
assert all("--no-session-persistence" in r["argv"] for r in domande)
assert all(not r["chiave"] for r in righe)
assert any(r["prompt"] == "/riassunto-modifiche" for r in prompt)
assert any(r["prompt"] == "/skill-doctor" for r in prompt)
assert any(r["argv"] == ["plugin", "validate", ".claude/skills"] for r in righe)
print("ok, le chiamate")
PY
  expect "le chiamate del partecipante emulato" 0 'ok, le chiamate'
  vero "la skill è arrivata in .claude/skills/" \
    test -f "${w}/${SKILL_REL}/SKILL.md"
  vero "bozza/ non resta" test ! -e "${w}/bozza"
  run git -C "${w}" status --short
  expect_absent "gli stream di prova/ non compaiono in git status" 'prova/'
  nuovo_ws w || { fail "lo spazio di lavoro"; return 0; }
  run env FINTO_NON_SCRIVE=1 FINTO_SPAZIO="${w}" "${E01}/_docente/live.sh" \
    "${w}"
  expect "live.sh se la richiesta non scrive la skill: 1" 1 \
    'la richiesta non ha scritto'
  # Un altro file in bozza/ non ferma la prova a metà, senza un verdetto.
  nuovo_ws w || { fail "lo spazio di lavoro"; return 0; }
  run env FINTO_BOZZA_ALTRO=1 FINTO_SPAZIO="${w}" "${E01}/_docente/live.sh" \
    "${w}"
  expect "live.sh se Claude lascia altro in bozza/: 0" 0 "${FATTO}"
  vero "e bozza/ non resta" test ! -e "${w}/bozza"
  nuovo_ws w || { fail "lo spazio di lavoro"; return 0; }
  run env FINTO_SKILL_ROTTA=1 FINTO_SPAZIO="${w}" "${E01}/_docente/live.sh" \
    "${w}"
  expect "live.sh con una skill che non passa: 1" 1 'description: manca'
  nuovo_ws w || { fail "lo spazio di lavoro"; return 0; }
  run env FINTO_ESITO_KO_SE='riassunto-modifiche' FINTO_SPAZIO="${w}" \
    "${E01}/_docente/live.sh" "${w}"
  expect "live.sh con la richiesta fallita: 1" 1 'la richiesta'
  nuovo_ws w || { fail "lo spazio di lavoro"; return 0; }
  run env FINTO_VALIDATE_KO=1 FINTO_SPAZIO="${w}" "${E01}/_docente/live.sh" \
    "${w}"
  expect "plugin validate che esce 1 non decide l'uscita" 0 "${FATTO}"
  expect "e si vede" 0 'claude plugin validate: uscita 1'
}

t_struttura() {
  run "${RADICE}/tools/check_handson.sh"
  if grep -q 'M5-E01' <<< "${OUT}"; then
    fail "check_handson.sh segnala M5-E01: $(grep 'M5-E01' <<< "${OUT}")"
  else
    pass "check_handson.sh non segnala M5-E01"
  fi
}

t_shellcheck() {
  local f
  for f in "${E01}/verifica.sh" "${E01}/_docente/live.sh" \
      "${E01}/esercizio/prova.sh" "${E01}/esercizio/prepara_modifica.sh" \
      "${E01}/soluzione/applica.sh" "${SELF}"; do
    if [[ -f "${f}" ]] && shellcheck -x "${f}" > /dev/null 2>&1; then
      pass "shellcheck ${f#"${RADICE}"/}"
    else
      fail "shellcheck ${f#"${RADICE}"/}"
    fi
  done
}

# Gli strumenti per le prove senza claude nel PATH: i soli che prova.sh chiede.
prepara_solo() {
  local t
  mkdir -p "${TMP}/solo" || exit 2
  for t in readlink git python3 mkdir mv; do
    ln -s "$(command -v "${t}")" "${TMP}/solo/${t}" || exit 2
  done
}

main() {
  local t
  for t in python3 git shellcheck; do
    command -v "${t}" > /dev/null 2>&1 \
      || { echo "test_m5_e01: manca ${t}" >&2; exit 2; }
  done
  [[ -f "${FINTO_PY}" ]] \
    || { echo "test_m5_e01: manca ${FINTO_PY}" >&2; exit 2; }
  handson::init_temp_base
  TMP="$(mktemp -d "${HANDSON_TEMP_BASE}/test_m5_e01.XXXXXX")" || exit 2
  trap 'chmod -R u+rwX "${TMP}" 2>/dev/null; rm -rf "${TMP}"' EXIT
  prepara_claude
  prepara_solo
  t_elemento
  t_riferimento
  t_readme
  t_prepara
  t_modifica
  t_prova
  t_prova_male
  t_verifica_buona
  t_verifica_dati
  t_verifica_male
  t_controllo_copia
  t_soluzione
  t_live
  t_struttura
  t_shellcheck
  OUT="${TUTTO}"
  expect_absent "in nessuna uscita «smentita»" "smentita"
  echo "PASS=${PASS} FAIL=${FAIL} SKIP=${SKIP}"
  if (( PASS + FAIL + SKIP != CASES )); then
    echo "test_m5_e01: girati $((PASS + FAIL + SKIP)) casi, attesi" \
      "${CASES}" >&2
    exit 2
  fi
  (( FAIL == 0 )) || exit 1
}

main "$@"
