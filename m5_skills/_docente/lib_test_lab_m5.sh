# shellcheck shell=bash
# shellcheck disable=SC2154,SC2016  # le variabili le assegna la suite; backtick
# e $ sono il testo delle prove
# =====================================================================
# lib_test_lab_m5.sh -- ciò che le suite di M5-E03 e di M5-E04 hanno in comune,
# per il docente: i contatori, gli stream scritti qui, il claude finto, e le
# prove che valgono per ogni traccia del laboratorio: l'elemento, il punto di
# partenza, le precondizioni, il ciclo del README, le garanzie, la prova dal
# vivo, le parti comuni del README, gli strumenti. Libreria di prova
# (_docente/lib_lab_m5.sh, con le sue prove, è in test_m5_e02.sh).
# ---------------------------------------------------------------------
# Libreria: si fa SOURCE da una suite, dopo tools/lib_handson.sh; non si esegue
# (nessun bit di esecuzione).
#
# Globals:   la suite assegna prima SUITE (il suo nome), ID, SKILL, ITEM, MOD,
#            RADICE, ESEMPIO, PROGETTO (progetti/<nome>), FILE_DEL_PROGETTO (un
#            file che lo spazio di lavoro deve avere), FINTO_PY, FINTO_BASE,
#            NEAR_MISS (una parola della richiesta che non deve attivarla),
#            RICHIESTA (una parola del primo caso), SELF. La libreria assegna
#            TMP, RAD, WS, G_WS, PASS, FAIL, RC, OUT.
#
# Mai il claude vero: il finto sta davanti nel PATH, e prepara_ambiente lo
# controlla prima di usarlo. Gli stream del finto e quelli scritti qui non sono
# risposte di Claude: provano il controllo, non il modello.
# =====================================================================

TMP=''
RAD=''
WS=''
G_WS=''
PASS=0
FAIL=0
RC=0
OUT=''
N_RAD=0
# Gli identificativi interni che i file per i partecipanti non portano.
INTERNI='FACT-|Tecnodata|[Tt]riage|M[0-9]-X[0-9]|\bX-[0-9]'
INTERNI+='|\b(ASK|OQ|DEC|TD|PQ)-[0-9]|\bB#[0-9]'
readonly INTERNI

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

# Esegue un comando; RC e OUT (STDOUT e STDERR insieme) per expect. Lo STDIN è
# /dev/null (main lo apre), salvo un here-doc dato a run.
run() { OUT="$("$@" 2>&1)"; RC=$?; }

# Uscita attesa E parole attese (RU-01.T3); mai un traceback.
# Arguments: $1 il nome, $2 l'uscita attesa, poi le parole (grep -F).
expect() {
  local nome="$1" atteso="$2" parola
  shift 2
  if (( RC != atteso )); then
    fail "${nome} (uscita ${RC}, attesa ${atteso}): ${OUT:0:900}"
    return 0
  fi
  if grep -qF -- 'Traceback' <<< "${OUT}"; then
    fail "${nome} (un traceback): ${OUT:0:900}"
    return 0
  fi
  for parola in "$@"; do
    if ! grep -qF -- "${parola}" <<< "${OUT}"; then
      fail "${nome} (manca «${parola}»): ${OUT:0:900}"
      return 0
    fi
  done
  pass "${nome}"
}

# Nessun falso positivo: la parola NON c'è (RU-01.T5).
# Arguments: $1 il nome, $2 la parola.
expect_absent() {
  if grep -qF -- "$2" <<< "${OUT}"; then
    fail "$1: «$2» c'è: ${OUT:0:900}"
  else
    pass "$1"
  fi
}

# Un caso vero o falso. Arguments: $1 il nome, poi il comando.
ok_se() {
  local nome="$1"
  shift
  if "$@" > /dev/null 2>&1; then
    pass "${nome}"
  else
    fail "${nome}"
  fi
}

# Le cartelle temporanee e il claude finto nel PATH.
# Globals: TMP (assegnata), PATH, FINTO_* (esportate).
prepara_ambiente() {
  local t
  for t in python3 git shellcheck; do
    command -v "${t}" > /dev/null 2>&1 || {
      echo "${SUITE}: manca ${t}" >&2
      exit 2
    }
  done
  handson::init_temp_base
  TMP="$(mktemp -d "${HANDSON_TEMP_BASE}/${SUITE}.XXXXXX")" || {
    echo "${SUITE}: mktemp non riesce" >&2
    exit 2
  }
  trap 'rm -rf "${TMP}"' EXIT
  mkdir -p "${TMP}/bin"
  cp "${FINTO_PY}" "${TMP}/bin/claude" && chmod +x "${TMP}/bin/claude"
  PATH="${TMP}/bin:${PATH}"
  export PATH FINTO_BASE
  export FINTO_LOG="${TMP}/finto.log"
  export FINTO_CHIAVE="${RADICE}/progetti/rete/_docente/chiave-problemi.tsv"
  export HANDSON_NO_PAUSE=1
  unset PN_HANDSON_ROOT PN_WORKSPACE_ROOT PN_FEEDBACK PN_LIVE_JSON
  unset PN_LAB_STRUMENTI
  if [[ "$(command -v claude)" != "${TMP}/bin/claude" ]]; then
    echo "${SUITE}: il finto non viene prima nel PATH" >&2
    exit 2
  fi
}

# Un registro delle chiamate vuoto.
log_vuoto() { : > "${FINTO_LOG}"; rm -f -- "${FINTO_LOG}.sessioni"; }

# Quante chiamate ha ricevuto il finto. Outputs: il numero.
chiamate() {
  if [[ -f "${FINTO_LOG}" ]]; then
    wc -l < "${FINTO_LOG}"
  else
    echo 0
  fi
}

# Un campo di ogni chiamata del finto. Arguments: $1 un'espressione Python su r.
# Outputs: una riga per chiamata.
dal_log() {
  python3 -B -I - "${FINTO_LOG}" "$1" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as fh:
    for riga in fh:
        r = json.loads(riga)
        print(eval(sys.argv[2]))
PY
}

# Uno spazio di lavoro nuovo, in una radice nuova. Globals: RAD, WS, N_RAD.
nuovo_ws() {
  N_RAD=$((N_RAD + 1))
  RAD="${TMP}/radice-${N_RAD}"
  WS="${RAD}/${ID}"
  mkdir -p "${RAD}"
  "${RADICE}/tools/prepara_esercizio.sh" "${ID}" --radice "${RAD}" \
    > /dev/null 2>&1 < /dev/null
}

# tools/prove_skill.sh sullo spazio di lavoro corrente, con la sua uscita in RC
# e OUT. Arguments: gli argomenti dello strumento dopo l'ID.
prove_cmd() {
  run "${RADICE}/tools/prove_skill.sh" "${ID}" "$@" --radice "${RAD}"
}

# verifica.py dell'elemento, con la sua uscita in RC e OUT.
# Arguments: gli argomenti di verifica.py.
verifica_py() {
  run env PN_HANDSON_ROOT="${RADICE}" python3 -B -I "${ITEM}/verifica.py" "$@"
}

# Il prompt N del README, senza il rientro comune, come lo legge la libreria.
# Arguments: $1 il numero. Outputs: il prompt.
prompt_readme() {
  python3 -B -I - "${ITEM}/README.md" "$1" <<'PY'
import sys
import textwrap

righe = open(sys.argv[1], encoding="utf-8").read().split("\n")
n = sys.argv[2]
a = [i for i, r in enumerate(righe) if r.strip() == "<!-- prompt %s -->" % n]
b = [i for i, r in enumerate(righe) if r.strip() == "<!-- /prompt %s -->" % n]
if len(a) != 1 or len(b) != 1 or a[0] > b[0]:
    sys.exit(2)
print(textwrap.dedent("\n".join(righe[a[0] + 1:b[0]])).strip("\n"))
PY
}

# Uno stream scritto qui, nella forma di quelli veri: non è una risposta di
# Claude. Globals: SKILL. Arguments: $1 la cartella della prova, $2 il testo, $3
# facoltativo file-cambiati.txt, $4 facoltativo i blocchi tool_use, in JSON.
stream_di() {
  mkdir -p "$1/outputs"
  python3 -B -I - "$1/outputs/stream.jsonl" "$2" "${SKILL}" "${4:-[]}" <<'PY'
import json
import sys

percorso, testo, skill, blocchi = sys.argv[1:5]
elenco = ["code-review"]
if "without_skill" not in percorso:
    elenco.insert(0, skill)
righe = [
    {"type": "system", "subtype": "init", "session_id": "prova",
     "skills": elenco}]
for n, blocco in enumerate(json.loads(blocchi)):
    righe.append({"type": "assistant", "message": {
        "role": "assistant", "content": [dict(blocco, type="tool_use",
                                              id="toolu_prova_%d" % n)]}})
righe += [
    {"type": "assistant", "message": {
        "role": "assistant", "content": [{"type": "text", "text": testo}]}},
    {"type": "result", "subtype": "success", "is_error": False,
     "num_turns": 2, "duration_ms": 2000, "result": testo,
     "session_id": "prova", "permission_denials": [],
     "usage": {"input_tokens": 1, "cache_creation_input_tokens": 1,
               "cache_read_input_tokens": 1, "output_tokens": 1}},
]
with open(percorso, "w", encoding="utf-8") as fh:
    for riga in righe:
        fh.write(json.dumps(riga, ensure_ascii=False) + "\n")
PY
  printf '%s' "${3:-}" > "$1/outputs/file-cambiati.txt"
}

# Giudica un testo come risposta di un caso e controlla un'asserzione; lascia in
# OUT «true|false l'evidenza». Globals: G_WS, SKILL. Arguments: $1 il nome, $2
# il caso, $3 il testo, $4 l'inizio dell'asserzione, $5 true o false, $6 una
# parola dell'evidenza, $7 facoltativo file-cambiati.txt.
giudica() {
  local nome="$1" caso="$2" testo="$3" quale="$4" atteso="$5" parola="$6" dir
  dir="${G_WS}/${SKILL}-workspace/iteration-1/eval-${caso}/with_skill"
  stream_di "${dir}" "${testo}" "${7:-}"
  verifica_py "${G_WS}" --solo-prove
  if (( RC != 0 )); then
    fail "${nome}: verifica.py esce ${RC}: ${OUT:0:600}"
    return 0
  fi
  run python3 -B -I - "${dir}/grading.json" "${quale}" <<'PY'
import json
import sys

voti = json.load(open(sys.argv[1], encoding="utf-8"))["assertion_results"]
for voce in voti:
    if voce["text"].startswith(sys.argv[2]):
        print(json.dumps(voce["passed"]), voce["evidence"])
        sys.exit(0)
sys.exit("asserzione non trovata")
PY
  if [[ "${OUT}" == "${atteso} "* && "${OUT}" == *"${parola}"* ]]; then
    pass "${nome}"
  else
    fail "${nome} (atteso ${atteso}, «${parola}»): ${OUT:0:600}"
  fi
}

# --- l'elemento ---------------------------------------------------------

# Arguments: i file in più che l'elemento deve avere.
test_elemento_comune() {
  echo "L'elemento:"
  local f manca='' percorso="esercizio/.claude/skills/${SKILL}"
  for f in README.md progetti.txt verifica.sh verifica.py esercizio/.gitignore \
      esercizio/.claude/settings.json "${percorso}/evals/evals.json" \
      "${percorso}/evals/eval_queries.json" esercizio/controlla_skill.py \
      esercizio/lib_leggi_frontmatter.py prove/config soluzione/LEGGIMI.md \
      _docente/live.sh "$@"; do
    [[ -f "${ITEM}/${f}" ]] || manca+=" ${f}"
  done
  if [[ -z "${manca}" ]]; then
    pass "i file dell'elemento ci sono"
  else
    fail "mancano:${manca}"
  fi
  ok_se "verifica.sh è eseguibile" test -x "${ITEM}/verifica.sh"
  ok_se "live.sh è eseguibile" test -x "${ITEM}/_docente/live.sh"
  ok_se "il punto di partenza non ha lo SKILL.md" test ! -e \
    "${ITEM}/${percorso}/SKILL.md"
  ok_se "nessun prove/prima.sh: un caso è solo la sua richiesta" test ! -e \
    "${ITEM}/prove/prima.sh"
  ok_se "evals.json è la copia di riferimenti/ byte per byte" cmp \
    "${ESEMPIO}/evals/evals.json" "${ITEM}/${percorso}/evals/evals.json"
  ok_se "eval_queries.json è la copia di riferimenti/ byte per byte" cmp \
    "${ESEMPIO}/evals/eval_queries.json" \
    "${ITEM}/${percorso}/evals/eval_queries.json"
  ok_se "controlla_skill.py è la copia di tools/ byte per byte" cmp \
    "${RADICE}/tools/controlla_skill.py" "${ITEM}/esercizio/controlla_skill.py"
  ok_se "lib_leggi_frontmatter.py è la copia di tools/ byte per byte" cmp \
    "${RADICE}/tools/lib_leggi_frontmatter.py" \
    "${ITEM}/esercizio/lib_leggi_frontmatter.py"
  run grep -xF '*-workspace/' "${ITEM}/esercizio/.gitignore"
  expect ".gitignore tiene fuori la cartella delle prove" 0 '*-workspace/'
  run grep -xF "${PROGETTO}" "${ITEM}/progetti.txt"
  expect "progetti.txt nomina il progetto" 0 "${PROGETTO}"
  run python3 -B -I - "${ITEM}/esercizio/.claude/settings.json" \
    "${RADICE}/.claude/settings.json" "${SKILL}" <<'PY'
import json
import sys

sue = json.load(open(sys.argv[1], encoding="utf-8"))["permissions"]
base = json.load(open(sys.argv[2], encoding="utf-8"))["permissions"]
attese = base["deny"] + ["Edit(/controlla_skill.py)",
                         "Edit(/lib_leggi_frontmatter.py)",
                         "Edit(/.claude/skills/%s/evals/**)" % sys.argv[3]]
if sorted(sue["deny"]) != sorted(attese):
    sys.exit("deny diverse: %r" % sue["deny"])
if sue.get("allow") or "bypass" in json.dumps(sue):
    sys.exit("regole in più: %r" % sue)
print("regole giuste")
PY
  expect "le regole deny: quelle prudenti, il controllo, evals/" 0 \
    'regole giuste'
  run cat "${ITEM}/prove/config"
  expect "prove/config: la skill, Sonnet, effort low, gli strumenti" 0 \
    "skill=${SKILL}" 'modello=sonnet' 'effort=low' \
    "strumenti=Read,Skill(${SKILL})"
  run cat "${ITEM}/soluzione/LEGGIMI.md"
  expect "soluzione/LEGGIMI.md dice da dove vengono le esecuzioni" 0 \
    'registrazione' "${ID}"
  run grep -F "lab::una_prova ${ID} " "${ITEM}/_docente/live.sh"
  expect "live.sh chiama la libreria del laboratorio" 0 'lab::una_prova'
}

# --- lo spazio di lavoro ------------------------------------------------

test_punto_di_partenza_comune() {
  echo "Lo spazio di lavoro:"
  N_RAD=$((N_RAD + 1))
  RAD="${TMP}/radice-${N_RAD}"
  WS="${RAD}/${ID}"
  mkdir -p "${RAD}"
  run "${RADICE}/tools/prepara_esercizio.sh" "${ID}" --radice "${RAD}"
  expect "prepara_esercizio.sh prepara lo spazio di lavoro" 0 \
    'Spazio di lavoro pronto'
  local f manca='' percorso=".claude/skills/${SKILL}"
  for f in "${FILE_DEL_PROGETTO}" controlla_skill.py lib_leggi_frontmatter.py \
      .gitignore .claude/settings.json "${percorso}/evals/evals.json" \
      "${percorso}/evals/eval_queries.json"; do
    [[ -f "${WS}/${f}" ]] || manca+=" ${f}"
  done
  if [[ -z "${manca}" ]]; then
    pass "nello spazio di lavoro c'è il punto di partenza"
  else
    fail "nello spazio di lavoro mancano:${manca}"
  fi
  manca=''
  for f in prove verita.json verifica.py soluzione _docente \
      "${PROGETTO}/_docente" "${percorso}/SKILL.md"; do
    [[ ! -e "${WS}/${f}" ]] || manca+=" ${f}"
  done
  if [[ -z "${manca}" ]]; then
    pass "nello spazio di lavoro nessuna verità, nessuno SKILL.md"
  else
    fail "nello spazio di lavoro non devono esserci:${manca}"
  fi
  run git -C "${WS}" status --porcelain
  expect_absent "il punto di partenza è tutto nel primo commit" '??'
  run "${RADICE}/tools/verifica.sh" "${ID}" --radice "${RAD}"
  expect "verifica sul punto di partenza: 1, e dice che cosa manca" 1 \
    'MANCA' 'NON ANCORA' 'SKILL.md' 'feedback.json'
  expect_absent "sul punto di partenza nessun reperto" 'REPERTO'
  run python3 -B -I "${WS}/controlla_skill.py" "${WS}/${percorso}"
  expect "il controllo nello spazio di lavoro: senza SKILL.md, 1" 1 'SKILL.md'
  run "${ITEM}/verifica.sh"
  expect "verifica.sh senza argomenti: 2" 2 'spazio di lavoro assente'
  run "${ITEM}/verifica.sh" "${TMP}/non-esiste"
  expect "verifica.sh su una cartella che non c'è: 2" 2 \
    'spazio di lavoro assente'
}

# --- le precondizioni ---------------------------------------------------

# Arguments: nessuno. Globals: G_WS, uno spazio di lavoro già preparato.
test_precondizioni_comuni() {
  local w="${G_WS}" evals dir
  evals="${w}/.claude/skills/${SKILL}/evals/evals.json"
  run env PN_HANDSON_ROOT="${TMP}/non-esiste" python3 -B -I \
    "${ITEM}/verifica.py" "${w}"
  expect "un repository che non c'è: 2" 2 'non-esiste'
  verifica_py
  expect "senza lo spazio di lavoro: 2" 2 'Uso'
  verifica_py "${TMP}/non-esiste"
  expect "su una cartella che non c'è: 2" 2 'spazio di lavoro assente'
  verifica_py "${w}" --boh
  expect "con un'opzione sconosciuta: 2" 2 'Uso'
  dir="${w}/${SKILL}-workspace/iteration-1/eval-1/with_skill"
  mkdir -p "${dir}/outputs"
  printf '{non è JSON\n' > "${dir}/outputs/stream.jsonl"
  verifica_py "${w}"
  expect "uno stream che non si legge: 2" 2 'non è JSON'
  rm -rf -- "${w}/${SKILL}-workspace"
  mv -- "${evals}" "${evals}.via"
  verifica_py "${w}"
  expect "senza i casi di prova: 2" 2 'evals.json'
  mv -- "${evals}.via" "${evals}"
}

# Un'asserzione aggiunta da un partecipante resta da valutare a mano.
# Arguments: $1 il caso, $2 l'indice del caso in evals.json, $3 un testo.
test_asserzione_a_mano() {
  local w="${G_WS}" evals dir
  evals="${w}/.claude/skills/${SKILL}/evals/evals.json"
  cp -- "${evals}" "${TMP}/evals.salvati"
  python3 -B -I - "${evals}" "$2" <<'PY'
import json
import sys

dati = json.load(open(sys.argv[1], encoding="utf-8"))
dati["evals"][int(sys.argv[2])]["assertions"].append("Si legge con piacere")
json.dump(dati, open(sys.argv[1], "w", encoding="utf-8"), ensure_ascii=False)
PY
  dir="${w}/${SKILL}-workspace/iteration-1/eval-$1/with_skill"
  stream_di "${dir}" "$3"
  verifica_py "${w}" --solo-prove
  expect "un'asserzione in più resta da valutare a mano, fuori dai conti" 0 \
    'da valutare a mano in with_skill: «Si legge con piacere'
  cp -- "${TMP}/evals.salvati" "${evals}"
  rm -rf -- "${w}/${SKILL}-workspace"
}

# --- il ciclo del README ------------------------------------------------

test_ciclo_comune() {
  echo "Il ciclo del README, con il claude finto:"
  local prima
  log_vuoto
  nuovo_ws
  prove_cmd 1 without
  expect "la baseline: tre esecuzioni, una tabella" 0 'Iterazione 1' \
    'without_skill: Skill chiamata: no' 'eval-3'
  run dal_log 'r["skill"], r["evals"], r["workspace"], r["bozza"]'
  expect_absent "la baseline: nessuna skill nella copia" "${SKILL}"
  expect_absent "la baseline: nessun evals/, nessun workspace" 'True'
  run dal_log '" ".join(r["argv"][:r["argv"].index("--")])'
  expect "i flag di ogni prova" 0 "--allowedTools Read,Skill(${SKILL})" \
    '--model sonnet' '--permission-mode dontAsk' '--permission-prompts none' \
    '--output-format stream-json' '--verbose' \
    '--setting-sources project,local' '--effort low' '--strict-mcp-config' \
    '--no-session-persistence'
  run dal_log 'r["prompt"]'
  expect "le richieste sono quelle di evals.json, così come sono" 0 \
    "${RICHIESTA}"
  prima="${WS}/${SKILL}-workspace/iteration-1/eval-1/without_skill"
  run cat "${prima}/outputs/risposta.md"
  expect "la baseline: la risposta da leggere" 0 'FINTO'
  run "${RADICE}/tools/verifica.sh" "${ID}" --radice "${RAD}"
  expect "dopo la baseline: non ancora" 1 'MANCA' 'with_skill' 'NON ANCORA'
  prove_cmd copia esempio
  expect "copia esempio: la skill di partenza" 0 'Copiata'
  ok_se "copia esempio non tocca evals/" cmp \
    "${ITEM}/esercizio/.claude/skills/${SKILL}/evals/evals.json" \
    "${WS}/.claude/skills/${SKILL}/evals/evals.json"
  run python3 -B -I "${WS}/controlla_skill.py" "${WS}/.claude/skills/${SKILL}"
  expect "il controllo nello spazio di lavoro: l'esempio passa" 0 '0 errori'
  log_vuoto
  prove_cmd 1 with
  expect "la prima versione: la skill chiamata, il confronto, la near-miss" 0 \
    'with_skill: Skill chiamata: sì' 'near-miss 1: Skill chiamata: no' \
    'dovrebbe attivarla: no' 'confermata (una sola esecuzione per caso)' \
    'Consumo'
  expect "i dati: la skill chiamata n su 3" 0 '(dato)' \
    "${SKILL} chiamata 3 su 3"
  run dal_log 'r["evals"]'
  expect_absent "with: mai evals/ nella copia" 'True'
  run dal_log '"near" if "'"${NEAR_MISS}"'" in r["prompt"] else ""'
  expect "la near-miss c'è" 0 near
  run "${RADICE}/tools/verifica.sh" "${ID}" --radice "${RAD}"
  expect "senza feedback.json: non ancora, e lo dice" 1 'feedback.json' \
    'iterazione 2'
  printf '{"eval-1": "Un commento di una prova.", "eval-2": ""%s' \
    ', "eval-3": ""}' > "${WS}/${SKILL}-workspace/iteration-1/feedback.json"
  printf '\nUna riga in più.\n' >> "${WS}/.claude/skills/${SKILL}/SKILL.md"
  log_vuoto
  prove_cmd 2 with
  expect "la seconda versione: old_skill riusata, non rifatta" 0 \
    'si riusano come old_skill' 'Iterazione 2' 'old_skill: Skill chiamata: sì'
  run wc -l "${FINTO_LOG}"
  expect "la seconda versione: quattro chiamate, come la prima" 0 '4 '
  run "${RADICE}/tools/verifica.sh" "${ID}" --radice "${RAD}"
  expect "il ciclo finito: fatto" 0 'VERIFICA OK' 'Fatto'
  expect_absent "il ciclo finito: niente che manchi" 'MANCA'
  expect_absent "il ciclo finito: nessun reperto" 'REPERTO'
  # Un grading.json cambiato a mano non conta: il controllo legge gli stream.
  # Il caso 2 senza la skill, che con il testo generico del finto non passa.
  local atteso riga
  atteso="$(python3 -B -I - \
    "${prima/eval-1/eval-2}/grading.json" <<'PY'
import json
import sys

dati = json.load(open(sys.argv[1], encoding="utf-8"))
for voce in dati["assertion_results"]:
    voce["passed"] = True
json.dump(dati, open(sys.argv[1], "w", encoding="utf-8"))
print(len(dati["assertion_results"]))
PY
)"
  verifica_py "${WS}"
  riga="${OUT#*eval-2}"
  riga="${riga%%with_skill:*}"
  if (( RC == 0 )) && [[ "${riga}" != *"${atteso} su ${atteso} asserzioni"* ]]
  then
    pass "il controllo non legge grading.json: la tabella resta quella"
  else
    fail "un grading.json cambiato ha cambiato la tabella (${RC}): ${OUT:0:600}"
  fi
}

# Lo stesso giro, con la seconda versione uguale alla prima.
test_versioni_uguali() {
  log_vuoto
  nuovo_ws
  prove_cmd 1 without
  prove_cmd copia esempio
  prove_cmd 1 with
  printf '{"eval-1": "", "eval-2": "", "eval-3": ""}' \
    > "${WS}/${SKILL}-workspace/iteration-1/feedback.json"
  prove_cmd 2 with
  run "${RADICE}/tools/verifica.sh" "${ID}" --radice "${RAD}"
  expect "due versioni uguali: non ancora, e lo dice" 1 'uguali'
  python3 -B -I - "${WS}/.claude/skills/${SKILL}/SKILL.md" "${SKILL}" <<'PY'
import sys

percorso, nome = sys.argv[1:3]
testo = open(percorso, encoding="utf-8").read()
testo = testo.replace("name: " + nome, "name: Nome Sbagliato", 1)
open(percorso, "w", encoding="utf-8").write(testo)
PY
  run "${RADICE}/tools/verifica.sh" "${ID}" --radice "${RAD}"
  expect "una skill che il controllo boccia: non ancora, e lo dice" 1 \
    'MANCA' 'name'
  nuovo_ws
  prove_cmd copia modello
  expect "copia modello: il modello, con il nome della skill" 0 \
    'template-SKILL.md'
  run grep -x "name: ${SKILL}" "${WS}/.claude/skills/${SKILL}/SKILL.md"
  expect "copia modello: name è quello della cartella" 0 "name: ${SKILL}"
}

test_garanzie_comuni() {
  echo "Le garanzie:"
  log_vuoto
  nuovo_ws
  FINTO_CHIAMA_SEMPRE="${SKILL}" prove_cmd 1 without
  expect "senza la skill, una chiamata alla skill: reperto, 1" 1 'REPERTO' \
    "una chiamata Skill a ${SKILL}"
  run "${RADICE}/tools/verifica.sh" "${ID}" --radice "${RAD}"
  expect "la verifica dice lo stesso: 1" 1 'REPERTO' 'NON ANCORA'
  nuovo_ws
  FINTO_ELENCA="${SKILL}" prove_cmd 1 without
  expect "senza la skill, la skill nell'elenco: reperto, 1" 1 'REPERTO' \
    'fra le skill disponibili'
  nuovo_ws
  FINTO_CHIAMA_SEMPRE=code-review prove_cmd 1 without
  expect "senza la skill, un'altra skill scelta da Claude: un dato, 0" 0 \
    'Skill chiamata: no (altre: code-review)' '(dato)' 'code-review'
  expect_absent "un'altra skill non è un reperto" 'REPERTO'
  prove_cmd copia esempio
  FINTO_NEGA_SKILL=1 prove_cmd 1 with
  expect "la chiamata negata dal permesso: reperto, 1" 1 'REPERTO' \
    'negata dal permesso'
  nuovo_ws
  FINTO_SENZA_INIT=1 prove_cmd 1 without
  expect "uno stream senza l'elenco delle skill: non decide, 2" 2 \
    'elenco delle skill'
  nuovo_ws
  FINTO_KO_SU="${RICHIESTA}" prove_cmd 1 without
  expect "un'esecuzione fallita: 1, le altre finite" 1 'FALLITA eval-1' \
    'finita eval-2'
  run "${RADICE}/tools/verifica.sh" "${ID}" --radice "${RAD}"
  expect "la verifica lo sa: incompleta, 1" 1 'NON ANCORA'
  nuovo_ws
  FINTO_ERRORE_SU="${RICHIESTA}" prove_cmd 1 without
  expect "un risultato con is_error: 1" 1 'FALLITA eval-1'
  run "${RADICE}/tools/verifica.sh" "${ID}" --radice "${RAD}"
  expect "la verifica lo sa: finita con un errore" 1 'finita con un errore'
}

# --- la prova dal vivo --------------------------------------------------

# Arguments: facoltative, assegnazioni per l'ambiente (VAR=valore).
live() {
  log_vuoto
  nuovo_ws
  run env "$@" "${ITEM}/_docente/live.sh" "${WS}"
}

test_live_comune() {
  echo "La prova dal vivo, con il claude finto:"
  local atteso1 atteso2 skill_cartella=".claude/skills/${SKILL}" cifre n
  run "${ITEM}/_docente/live.sh"
  expect "live.sh senza lo spazio di lavoro: 2, e dice l'uso" 2 \
    'uso: _docente/live.sh <spazio di lavoro>'
  expect_absent "live.sh senza argomenti non parla di un valore vuoto" 'assente'
  run "${ITEM}/_docente/live.sh" "${TMP}/non-esiste"
  expect "live.sh su una cartella che non c'è: 2" 2 'spazio di lavoro assente'
  live ANTHROPIC_API_KEY=finta-non-usata
  expect "live.sh da capo a fondo: 0" 0 'VERIFICA OK' 'Fatto'
  expect "i passi, con i loro numeri" 0 'passo 1:' 'passo 3:' 'passo 4:' \
    'passo 6:' 'passo 7:' 'turni del modello' 'token'
  cifre="${OUT}"
  run wc -l "${FINTO_LOG}"
  expect "tredici chiamate: undici di prove, due di scrittura" 0 '13 '
  OUT="${cifre}"
  expect_absent "nessun reperto" 'REPERTO'
  run dal_log 'r["chiave"]'
  expect_absent "ANTHROPIC_API_KEY non arriva mai a claude" 'True'
  atteso1="$(prompt_readme 1)"
  atteso1="${atteso1//${skill_cartella}/bozza/${SKILL}}"
  atteso2="$(prompt_readme 2)"
  atteso2="${atteso2//${skill_cartella}/bozza/${SKILL}}"
  python3 -B -I - "${FINTO_LOG}" "${TMP}/scritture" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as fh:
    righe = [json.loads(r) for r in fh]
scritture = [r for r in righe if "<instructions>" in r["prompt"]]
for n, r in enumerate(scritture, 1):
    with open("%s.%d.prompt" % (sys.argv[2], n), "w", encoding="utf-8") as fh:
        fh.write(r["prompt"])
    with open("%s.%d.argv" % (sys.argv[2], n), "w", encoding="utf-8") as fh:
        fh.write(" ".join(r["argv"][:r["argv"].index("--")]))
PY
  for n in 1 2; do
    local atteso="atteso${n}"
    if [[ "$(< "${TMP}/scritture.${n}.prompt")" == "${!atteso}" ]]; then
      pass "il prompt ${n} è quello del README, con il percorso in bozza/"
    else
      fail "il prompt ${n} è diverso: $(< "${TMP}/scritture.${n}.prompt")"
    fi
  done
  run cat "${TMP}/scritture.1.argv"
  expect "la scrittura: Sonnet, effort medium, gli strumenti nominati" 0 \
    '--model sonnet' '--effort medium' '--output-format stream-json' \
    '--permission-mode dontAsk' '--strict-mcp-config' \
    'Read,Edit,Write,Bash(python3 -B -I controlla_skill.py *)'
  run cat "${TMP}/scritture.2.argv"
  expect "il seguito: --resume, stessi flag" 0 '--resume sessione-finta-' \
    '--effort medium'
  ok_se "gli stream stanno fuori dallo spazio di lavoro" test -s \
    "${WS}.prova_dal_vivo/passo-6.jsonl"
  ok_se "alla fine la bozza non c'è più" test ! -e "${WS}/bozza"
  run grep -c 'Riga di prova del finto' "${WS}/${skill_cartella}/SKILL.md"
  expect "la skill ha le due scritture, portate da bozza/" 0 2
  ok_se "evals/ resta la copia di partenza" cmp \
    "${ITEM}/esercizio/${skill_cartella}/evals/evals.json" \
    "${WS}/${skill_cartella}/evals/evals.json"
  run cat "${WS}/${SKILL}-workspace/iteration-1/feedback.json"
  expect "feedback.json dice che l'ha scritto uno script" 0 '_nota' \
    'uno script' 'eval-1' 'eval-2' 'eval-3'
  nuovo_ws
  printf 'lavoro\n' > "${WS}/appunti.txt"
  log_vuoto
  run "${ITEM}/_docente/live.sh" "${WS}"
  expect "uno spazio di lavoro con del lavoro: 2" 2 \
    "tools/reset_esercizio.sh ${ID}"
  n="$(chiamate)"
  if (( n == 0 )); then
    pass "e nessuna chiamata"
  else
    fail "${n} chiamate"
  fi
  live 'FINTO_KO_SU=<role>'
  expect "il prompt 1 fallito: 1, niente dopo" 1 'VERIFICA KO'
  run wc -l "${FINTO_LOG}"
  expect "tre prove e il prompt 1" 0 '4 '
  live FINTO_NEGA_SKILL=1
  expect "la skill negata dal permesso: 1, niente dopo" 1 'REPERTO'
  run wc -l "${FINTO_LOG}"
  expect "tre, il prompt 1 e quattro" 0 '8 '
}

# --- il README ----------------------------------------------------------

test_readme_sezioni() {
  local r="${ITEM}/README.md" s atteso=1 ultimo=0 riga
  run grep -n '^## ' "${r}"
  for s in 'Obiettivo' 'Tempo' 'Prerequisiti' \
      "Punto di partenza (tools/prepara_esercizio.sh ${ID})" \
      'Passi in Claude Code' 'Che cosa osservare' \
      "Verifica (tools/verifica.sh ${ID})" 'Se qualcosa va storto' \
      "Impronta d'uso sul piano Pro" 'Per approfondire'; do
    riga="$(grep -nF -x -- "## ${s}" "${r}" | head -n 1)"
    riga="${riga%%:*}"
    if [[ -z "${riga}" ]] || (( riga <= ultimo )); then
      atteso=0
    else
      ultimo="${riga}"
    fi
  done
  if (( atteso == 1 )); then
    pass "le dieci sezioni, in ordine"
  else
    fail "le dieci sezioni: ${OUT}"
  fi
}

# Arguments: $1 il progetto o il file che il prompt 1 nomina, $2 ciò per cui
# vale ogni istruzione («qualunque …»).
test_readme_prompt() {
  local p1 p2 cartella=".claude/skills/${SKILL}"
  p1="$(prompt_readme 1)" || p1=''
  p2="$(prompt_readme 2)" || p2=''
  run python3 -B -I - "${p1}" "${SKILL}" <<'PY'
import re
import sys

testo, skill = sys.argv[1:3]
TAG = ["role", "context", "instructions", "format", "constraints"]
trovati = re.findall(r"^<([a-z]+)>$", testo, re.M)
chiusi = re.findall(r"^</([a-z]+)>$", testo, re.M)
if trovati != TAG or chiusi != TAG:
    sys.exit("i tag: %r %r" % (trovati, chiusi))
if not re.search(r"<role>\nSei ", testo):
    sys.exit("il ruolo non comincia con «Sei »")
ruolo = re.search(r"<role>\n(.*?)\n</role>", testo, re.S).group(1)
if ruolo.count(".") != 1:
    sys.exit("il ruolo non è una frase: %r" % ruolo)
if len(testo.split()) < 60:
    sys.exit("meno di 60 parole")
istruzioni = re.search(r"<instructions>\n(.*?)\n</instructions>", testo,
                       re.S).group(1)
passi = re.findall(r"^(\d+)\. ", istruzioni, re.M)
if len(passi) < 3:
    sys.exit("passi: %r" % passi)
ultimo = istruzioni[istruzioni.rindex("%s. " % passi[-1]):]
if "python3 -B -I controlla_skill.py .claude/skills/" + skill not in ultimo:
    sys.exit("l'ultimo passo non è il controllo: %r" % ultimo)
print("il template")
PY
  expect "il prompt 1 nel template, l'ultimo passo il controllo" 0 'il template'
  OUT="${p1}"
  RC=0
  expect "il prompt 1 nomina i file, senza incollarli" 0 \
    "${SKILL}-workspace/iteration-1/eval-1/without_skill/outputs/risposta.md" \
    "${cartella}/evals/evals.json" "$1" 'expected_output'
  expect "il prompt 1: i vincoli del file" 0 "${cartella}/" 'evals/' \
    '500 righe' 'Markdown semplice' "$2" 'description'
  expect "il prompt 1: al massimo cinque righe" 0 'cinque righe'
  run python3 -B -I - "${p2}" <<'PY'
import re
import sys

testo = sys.argv[1]
TAG = ["context", "instructions", "format", "constraints"]
if re.findall(r"^<([a-z]+)>$", testo, re.M) != TAG:
    sys.exit("i tag: %r" % re.findall(r"^<([a-z]+)>$", testo, re.M))
print("il seguito")
PY
  expect "il prompt 2: i tag del seguito, senza il ruolo" 0 'il seguito'
  OUT="${p2}"
  RC=0
  expect "il prompt 2 nomina i tre segnali" 0 'grading.json' 'feedback.json' \
    'stream.jsonl'
  expect "il prompt 2 porta le quattro linee guida della guida" 0 \
    'Generalizza' 'snella' 'perché' 'scripts/'
  expect "il prompt 2: l'ultimo passo è il controllo" 0 \
    "python3 -B -I controlla_skill.py ${cartella}"
}

# Le frasi su STDIN, una per riga, parola per parola.
# Arguments: $1 il nome del caso.
controlla_frasi() {
  local piatto f manca=''
  piatto="$(LC_ALL=C tr -s '[:space:]' ' ' < "${ITEM}/README.md")"
  while IFS= read -r f; do
    [[ "${piatto}" == *"${f}"* ]] || manca+=" «${f}»"
  done
  if [[ -z "${manca}" ]]; then
    pass "$1"
  else
    fail "$1: mancano:${manca}"
  fi
}

test_readme_frasi_comuni() {
  controlla_frasi "le frasi del metodo, parola per parola" <<'FRASI'
measure separately whether Claude invokes it on the prompts it should, and whether the output matches what you expect when it does.
Collect a few realistic prompts, run each one in a fresh session with the skill available and again with it turned off
A fresh session matters because leftover context from authoring the skill will mask gaps in the written instructions.
Run Claude on representative tasks without a Skill. … Build three scenarios that test these gaps. … Measure Claude's performance without the Skill.
Write minimal instructions: Create just enough content to address the gaps and pass evaluations.
Iterate: Run evaluations, compare against baseline, and refine.
turn a general-purpose agent into a specialist
Create evaluations BEFORE writing extensive documentation.
Store test cases in evals/evals.json inside your skill directory
Start with 2-3 test cases.
Include at least one prompt that tests a boundary condition
run each test case twice: once with the skill and once without it (or with a previous version)
Each pass through the full eval loop gets its own iteration-N/ directory.
Each eval run should start with a clean context — no leftover state from previous runs or from the skill development process.
When improving an existing skill, use the previous version as your baseline. Snapshot it before editing
The other JSON files (grading.json, timing.json, benchmark.json) are produced during the eval process — by the agent, by scripts, or by you.
Add them after you see your first round of outputs
Reserve assertions for things that can be checked objectively.
are hard to decompose into pass/fail checks. These are better caught during human review.
recording PASS or FAIL with specific evidence
use a verification script — scripts are more reliable than LLM judgment for mechanical checks
Require concrete evidence for a PASS. Don't give the benefit of the doubt.
The delta tells you what the skill costs (more time, more tokens) and what it buys (higher pass rate).
In early iterations with just 2-3 test cases and single runs, focus on the raw pass counts and the delta
Remove or replace assertions that always pass in both configurations.
Study assertions that pass with the skill but fail without. This is where the skill is clearly adding value.
Record specific feedback for each test case and save it in the workspace
"The chart is missing axis labels" is actionable; "looks bad" is not.
Empty feedback means the output looked fine
give all three — along with the current SKILL.md — to an LLM and ask it to propose changes
Generalize from feedback. … Keep the skill lean. … Explain the why. … Bundle repeated work.
Rerun all test cases in a new iteration-<N+1>/ directory.
Effective skills are grounded in real expertise. The key is feeding domain-specific context into the creation process.
Then extract the reusable pattern into a skill.
Internal documentation, runbooks, and style guides
When an agent makes a mistake you have to correct, add the correction to the gotchas section.
This is more reliable than describing the format in prose, because agents pattern-match well against concrete structures.
Read agent execution traces, not just final outputs.
The most valuable negative test cases are near-misses — queries that share keywords or concepts with your skill but actually need something different.
Model behavior is nondeterministic — the same query might trigger the skill on one run but not the next.
Avoid adding specific keywords from failed queries — that's overfitting.
Yes, and allow Claude to edit files in this project's .claude folder for this session
A simple, one-step request like "read this PDF" may not trigger a PDF skill even if the description matches perfectly
Sonnet handles most coding tasks well and costs less than Opus.
These limits are shared across Claude and Claude Code, meaning all activity in both tools counts against the same limits.
On Pro, Max, Ultra, Team, and Enterprise it breaks your usage down by skill, subagent, plugin, and MCP server.
This command requires approval
They don't apply to … arbitrary subprocesses that read or write files indirectly, like a Python or Node script that opens files itself.
Edit rules apply to all built-in tools that edit files.
FRASI
  local piatto f manca=''
  piatto="$(LC_ALL=C tr -s '[:space:]' ' ' < "${ITEM}/README.md")"
  local piattaforma='https://platform.claude.com/docs/en/agents-and-tools'
  for f in 'https://code.claude.com/docs/en/skills' \
      'https://code.claude.com/docs/en/permission-modes' \
      "${piattaforma}/agent-skills/best-practices" \
      "${piattaforma}/agent-skills/overview" \
      'https://agentskills.io/skill-creation/evaluating-skills' \
      'https://agentskills.io/skill-creation/best-practices' \
      'https://agentskills.io/skill-creation/optimizing-descriptions'; do
    [[ "${piatto}" == *"${f}"* ]] || manca+=" ${f}"
  done
  if [[ -z "${manca}" ]]; then
    pass "gli indirizzi delle frasi"
  else
    fail "mancano:${manca}"
  fi
  manca=''
  for f in "tools/prepara_esercizio.sh ${ID}" \
      "tools/prove_skill.sh ${ID} 1 without" \
      "tools/prove_skill.sh ${ID} copia esempio" \
      "tools/prove_skill.sh ${ID} 1 with" \
      "tools/prove_skill.sh ${ID} 2 with" "tools/verifica.sh ${ID}" \
      'old_skill' 'skill-snapshot/' 'feedback.json' 'da valutare a mano' \
      "Skill(${SKILL})" 'allowed-tools' 'undici' 'Sonnet' 'medium' 'M5-D05' \
      "tools/reset_esercizio.sh ${ID}" \
      'con uno script Python dentro un comando Bash' \
      'leggete ogni comando prima di approvarlo' \
      'si ferma prima, con l'\''uscita 2' \
      'un esito da segnalare al docente, con lo stream' \
      'nessuna chiamata riuscita a' 'né respinta dallo strumento' \
      'la chiamata è «respinta dallo strumento»'; do
    [[ "${piatto}" == *"${f}"* ]] || manca+=" «${f}»"
  done
  if [[ -z "${manca}" ]]; then
    pass "i comandi, nell'ordine dei passi, e ciò che il README deve dire"
  else
    fail "mancano:${manca}"
  fi
  run grep -cxF '       cd -' "${ITEM}/README.md"
  expect "il passo 6 torna nella cartella da cui parte il passo 7" 0 1
}

test_readme_parole() {
  local r="${ITEM}/README.md"
  local vietate='smentit|prossima sessione|\boggi\b|\bdomani\b|pranzo'
  vietate+='|Percorso A\b|il vostro codice|i vostri file'
  run grep -nEi "${vietate}" "${r}"
  expect "nessuna «smentita», niente orario, niente codice vostro" 1
  # Il prompt resta com'è registrato: le forme valgono per ciò che ha intorno.
  local forme='un `SKILL\.md`|nel `SKILL\.md`|del `SKILL\.md`'
  forme+='|[Ii]l `SKILL\.md`'
  run grep -nE "${forme}" "${r}"
  expect "le forme: «uno», «nello», «dello», «lo» SKILL.md" 1
  run grep -nF 'la regola `deny` lo ferma' "${r}"
  expect "la regola deny non è detta di ogni comando" 1
  run grep -nF "quella riga non c'è più" "${r}"
  expect "il reperto non vuol dire che la riga manca" 1
  run grep -nE "${INTERNI}" "${r}"
  expect "nessun nome interno nel README" 1
  run grep -rnE "${INTERNI}" "${ITEM}/verifica.py" "${ITEM}/verifica.sh" \
    "${ITEM}/prove" "${ITEM}/esercizio/.claude/settings.json" \
    "${ITEM}/esercizio/.gitignore"
  expect "nessun nome interno nei file per i partecipanti" 1
  run grep -rnE "${INTERNI}" "${ITEM}/_docente" "${ITEM}/soluzione" \
    "${FINTO_PY}"
  expect "nessun nome interno nei file del docente" 1
}

# --- gli strumenti ------------------------------------------------------

# Arguments: i file Python in più da controllare.
test_strumenti_comuni() {
  echo "shellcheck, check_handson, Python 3.8, bash 3.2:"
  local f lib="${MOD}/_docente/lib_test_lab_m5.sh"
  for f in "${ITEM}/verifica.sh" "${ITEM}/_docente/live.sh" "${SELF}" \
      "${lib}"; do
    run bash -c 'cd "$1" && shellcheck -x -- "$2"' _ "${RADICE}" "${f}"
    expect "shellcheck pulito: ${f#"${MOD}"/}" 0
  done
  run "${RADICE}/tools/check_handson.sh"
  expect_absent "check_handson non segnala niente di ${ID}" "${ID}"
  ok_se "la libreria delle prove: nessun bit di esecuzione" test ! -x "${lib}"
  for f in "${ITEM}/verifica.py" "${FINTO_PY}" "$@"; do
    run python3 -B -I -c '
import ast
import sys

ast.parse(open(sys.argv[1], encoding="utf-8").read(), feature_version=(3, 8))
print("ok")' "${f}"
    expect "la sintassi di Python 3.8: ${f##*/}" 0 ok
  done
  local recenti='readarray|mapfile|declare -A|local -A|wait -n'
  recenti+='|\$\{[a-z_]+(,,|\^\^)\}'
  run grep -nE "${recenti}" "${ITEM}/verifica.sh" "${ITEM}/_docente/live.sh"
  expect "niente che il bash 3.2 non abbia" 1
  run python3 -B -I -c '
import sys

for nome in sys.argv[1:]:
    with open(nome, encoding="utf-8") as fh:
        for numero, riga in enumerate(fh, 1):
            if len(riga.rstrip("\n")) > 80:
                print("%s:%d" % (nome, numero))' \
    "${ITEM}/verifica.sh" "${ITEM}/_docente/live.sh"
  if [[ "${RC}" == 0 && -z "${OUT}" ]]; then
    pass "gli script stanno in 80 colonne"
  else
    fail "oltre 80 colonne: ${OUT}"
  fi
}

# Il riepilogo: non torna con più o meno casi di CASES.
# Globals: PASS, FAIL, SUITE. Arguments: $1 i casi attesi.
chiudi_suite() {
  echo "${SUITE}: PASS=${PASS} FAIL=${FAIL}"
  (( FAIL == 0 )) || exit 1
  if (( PASS != $1 )); then
    echo "${SUITE}: ${PASS} casi, attesi $1" >&2
    exit 2
  fi
}
