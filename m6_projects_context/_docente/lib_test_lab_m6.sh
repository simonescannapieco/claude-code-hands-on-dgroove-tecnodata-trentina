# shellcheck shell=bash
# shellcheck disable=SC2154,SC2016  # le variabili le assegna la suite; backtick
# e $ sono il testo delle prove
# =====================================================================
# lib_test_lab_m6.sh -- ciò che le suite di M6-E02 e di M6-E03 hanno in comune,
# per il docente: i contatori, le prove scritte qui, il claude finto, e le
# prove che valgono per tutte e due le tracce del laboratorio: l'elemento, il
# punto di partenza, prove/prima.sh, il ciclo del README, le garanzie, la prova
# dal vivo (_docente/lib_lab_m6.sh), il README, la soluzione, gli strumenti, la
# registrazione del corso.
# ---------------------------------------------------------------------
# Libreria: si fa SOURCE da una suite, dopo tools/lib_handson.sh; non si esegue
# (nessun bit di esecuzione).
#
# Globals:   la suite assegna prima SUITE (il suo nome), ID, ITEM, ALTRO (la
#            cartella dell'altra traccia), MOD, RADICE, SELF, PROGETTO
#            (progetti/<nome>), FILE_REFUSO (relativo allo spazio di lavoro),
#            REFUSO e GIUSTO (il testo sbagliato e quello giusto), RICHIESTE,
#            PROMPTS e STRUMENTI (array, uno per richiesta), RIF, REGOLA (la
#            regola di soluzione/), GLOB, DENY_NUOVE (array), ESCLUDI (la riga
#            di prove/config), V1_TESTO (un CLAUDE.md per il ciclo), FINTO_PY.
#            La libreria assegna TMP, RAD, WS, PASS, FAIL, SKIP, RC, OUT.
#
# Mai il claude vero: il finto sta davanti nel PATH, e prepara_ambiente lo
# controlla prima di usarlo. Gli stream del finto e quelli scritti qui non sono
# risposte di Claude: provano il controllo e gli strumenti, non il modello.
# =====================================================================

TMP=''
RAD=''
WS=''
PASS=0
FAIL=0
SKIP=0
RC=0
OUT=''
N_RAD=0
# Gli identificativi interni che i file per i partecipanti non portano.
INTERNI='FACT-|Tecnodata|[Tt]riage|M[0-9]-X[0-9]|\bX-[0-9]'
INTERNI+='|\b(ASK|OQ|DEC|TD|PQ)-[0-9]|\bB#[0-9]'
readonly INTERNI

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

# Esegue un comando; RC e OUT (STDOUT e STDERR insieme). Lo STDIN è /dev/null
# (main lo apre), salvo un here-doc dato a run.
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

# La riga di un criterio nell'uscita di verifica.py, con ciò che deve avere.
# Arguments: $1 il nome del caso, $2 il criterio, $3 il pezzo atteso.
criterio() {
  local riga
  riga="$(grep -F -- "  $2: " <<< "${OUT}" | head -n 1)"
  if (( RC == 0 )) && [[ -n "${riga}" && "${riga}" == *"$3"* ]]; then
    pass "$1"
  else
    fail "$1 (uscita ${RC}): ${riga:-nessuna riga «$2»} ${OUT:0:300}"
  fi
}

# Le cartelle temporanee e il claude finto nel PATH.
# Globals: TMP (assegnata), PATH, FINTO_LOG (esportate).
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
  export PATH
  export FINTO_LOG="${TMP}/finto.log"
  export HANDSON_NO_PAUSE=1
  unset PN_HANDSON_ROOT PN_WORKSPACE_ROOT PN_LIVE_JSON PN_LAB_STRUMENTI
  unset CLAUDE_CODE_DISABLE_AUTO_MEMORY
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
    wc -l < "${FINTO_LOG}" | tr -d ' '
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

prova_cmd() { run "${RADICE}/tools/prova_contesto.sh" "${ID}" "$1" --radice "${RAD}"; }
verifica_cmd() { run "${RADICE}/tools/verifica.sh" "${ID}" --radice "${RAD}"; }

# verifica.py dell'elemento, con la sua uscita in RC e OUT.
verifica_py() {
  run env PN_HANDSON_ROOT="${RADICE}" python3 -B -I "${ITEM}/verifica.py" "$@"
}

# Il prompt N di un README, senza il rientro comune, come lo legge
# lib_lab_m6.sh. Arguments: $1 il README, $2 il numero. Outputs: il prompt.
prompt_readme() {
  python3 -B -I - "$1" "$2" <<'PY'
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

# Una prova scritta qui, nella forma di quelle di tools/prova_contesto.sh:
# lo stream è inventato, non è una risposta di Claude.
# Arguments: $1 lo spazio di lavoro, $2 la versione, $3 la richiesta, $4 la
#   specifica in JSON: comandi ([comando, risultato]), testo, commit
#   ([soggetto, corpo]), committati, cambiati (righe di git status), diff
#   («corretto», «corretto_e_una» con una riga aggiunta in più, «diverso»,
#   «altro» o «nessuno»), carica (il CLAUDE.md nel registro dell'hook),
#   risultato (false: lo stream senza result).
prova_sintetica() {
  python3 -B -I - "$@" "${ITEM}" "${RADICE}" "${FILE_REFUSO}" <<'PY'
import json
import os
import sys

ws, versione, richiesta, spec, item, radice, file_refuso = sys.argv[1:8]
s = json.loads(spec)
d = os.path.join(ws, "prove-contesto", versione, richiesta)
os.makedirs(d, exist_ok=True)
uso = {"input_tokens": 1, "cache_creation_input_tokens": 999,
       "cache_read_input_tokens": 0}
righe = [{"type": "system", "subtype": "init", "model": "finto"}]
for n, (comando, uscita) in enumerate(s.get("comandi", [])):
    ident = "toolu_sintetico_%d" % n
    righe.append({"type": "assistant", "parent_tool_use_id": None,
                  "message": {"usage": uso, "content": [
                      {"type": "tool_use", "id": ident, "name": "Bash",
                       "input": {"command": comando}}]}})
    righe.append({"type": "user", "message": {"content": [
        {"type": "tool_result", "tool_use_id": ident, "content": uscita}]}})
testo = s.get("testo", "")
righe.append({"type": "assistant", "parent_tool_use_id": None,
              "message": {"usage": uso, "content": [
                  {"type": "text", "text": testo}]}})
if s.get("risultato", True):
    righe.append({"type": "result", "subtype": "success", "is_error": False,
                  "num_turns": 2, "duration_ms": 2000, "result": testo,
                  "usage": {"input_tokens": 1,
                            "cache_creation_input_tokens": 0,
                            "cache_read_input_tokens": 0,
                            "output_tokens": 1}})


def scrivi(nome, contenuto):
    with open(os.path.join(d, nome), "w", encoding="utf-8") as fh:
        fh.write(contenuto)


scrivi("stream.jsonl", "".join(json.dumps(r) + "\n" for r in righe))
scrivi("prompt.txt", "la richiesta %s\n" % richiesta)
scrivi("strumenti.txt", "Read\n")
scrivi("file-cambiati.txt", "".join(r + "\n" for r in s.get("cambiati", [])))
scrivi("file-committati.txt",
       "".join(r + "\n" for r in s.get("committati", [])))
scrivi("commit.txt", "".join("%s\n\n%s\n----\n" % (a, b)
                             for a, b in s.get("commit", [])))
con = open(os.path.join(item, "esercizio", file_refuso),
           encoding="utf-8").read().split("\n")
senza = open(os.path.join(radice, file_refuso),
             encoding="utf-8").read().split("\n")
vecchia, giusta = [(a, b) for a, b in zip(con, senza) if a != b][0]
testa = ("diff --git a/{0} b/{0}\nindex 1111111..2222222 100644\n"
         "--- a/{0}\n+++ b/{0}\n@@ -1,1 +1,1 @@\n").format(file_refuso)
diff = {"corretto": testa + "-" + vecchia + "\n+" + giusta + "\n",
        "corretto_e_una": testa + "-" + vecchia + "\n+" + giusta
        + "\n+una riga in più\n",
        "diverso": testa + "-" + vecchia + "\n+" + giusta + " altro\n",
        "altro": "diff --git a/LEGGIMI b/LEGGIMI\n@@ -1 +1 @@\n-a\n+b\n",
        "nessuno": ""}[s.get("diff", "nessuno")]
scrivi("diff.txt", diff)
carica = ('{"load_reason": "session_start", "file_path": "CLAUDE.md", '
          '"memory_type": "Project", "trigger_file_path": null, '
          '"parent_file_path": null, "globs": null}\n')
scrivi("caricamenti.jsonl", carica if s.get("carica") else "")
PY
}

# La fotografia di una versione. Arguments: $1 lo spazio di lavoro, $2 la
# versione, $3 il testo del CLAUDE.md (vuoto: nessun CLAUDE.md).
foto_sintetica() {
  local f="$1/prove-contesto/$2/fotografia"
  mkdir -p "${f}/.claude"
  cp -- "${ITEM}/esercizio/.claude/settings.json" "${f}/.claude/settings.json"
  if [[ -n "$3" ]]; then
    printf '%s\n' "$3" > "${f}/CLAUDE.md"
  fi
}

# Le tre versioni, ogni richiesta con la specifica buona della suite
# (spec_buona <richiesta> <carica>), il CLAUDE.md diverso fra v1 e v2.
# Arguments: $1 lo spazio di lavoro.
tre_versioni_sintetiche() {
  local v r carica
  rm -rf -- "${1:?}/prove-contesto"
  foto_sintetica "$1" base ''
  foto_sintetica "$1" v1 $'# Progetto\n\n- Una riga.'
  foto_sintetica "$1" v2 $'# Progetto\n\n- Una riga.\n- Due righe.'
  for v in base v1 v2; do
    carica=true
    [[ "${v}" != base ]] || carica=false
    for r in "${RICHIESTE[@]}"; do
      prova_sintetica "$1" "${v}" "${r}" "$(spec_buona "${r}" "${carica}")"
    done
  done
}

# --- l'elemento ---------------------------------------------------------

test_elemento_comune() {
  echo "L'elemento:"
  local f manca=''
  for f in README.md progetti.txt verifica.sh verifica.py prove/config \
      prove/richieste.tsv prove/prima.sh esercizio/.gitignore \
      esercizio/.claude/settings.json \
      esercizio/.claude/hooks/registra_caricamenti.py \
      esercizio/appunti-del-team.md "esercizio/${FILE_REFUSO}" \
      soluzione/CLAUDE.md "soluzione/${REGOLA}" soluzione/.claude/settings.json \
      soluzione/LEGGIMI.md _docente/live.sh; do
    [[ -f "${ITEM}/${f}" ]] || manca+=" ${f}"
  done
  if [[ -z "${manca}" ]]; then
    pass "i file dell'elemento ci sono"
  else
    fail "mancano:${manca}"
  fi
  ok_se "verifica.sh è eseguibile" test -x "${ITEM}/verifica.sh"
  ok_se "live.sh è eseguibile" test -x "${ITEM}/_docente/live.sh"
  ok_se "prove/prima.sh è eseguibile" test -x "${ITEM}/prove/prima.sh"
  ok_se "il punto di partenza non ha un CLAUDE.md né regole" test ! -e \
    "${ITEM}/esercizio/CLAUDE.md" -a ! -e "${ITEM}/esercizio/.claude/rules"
  ok_se "l'hook è la copia di tools/ byte per byte" cmp \
    "${RADICE}/tools/registra_caricamenti.py" \
    "${ITEM}/esercizio/.claude/hooks/registra_caricamenti.py"
  run grep -xF "${PROGETTO}" "${ITEM}/progetti.txt"
  expect "progetti.txt nomina il progetto" 0 "${PROGETTO}"
  run cat "${ITEM}/prove/config"
  expect "prove/config: Sonnet, effort low, che cosa esclude, i divieti" 0 \
    'modello=sonnet' 'effort=low' "${ESCLUDI}" \
    'vietati=Bash(sudo *),Bash(git push *),Bash(curl *),Bash(wget *)'
  for f in /prove-contesto/ /.claude/caricamenti.jsonl /CLAUDE.local.md \
      /.claude/settings.local.json; do
    run grep -xF -- "${f}" "${ITEM}/esercizio/.gitignore"
    expect ".gitignore: ${f}" 0 "${f}"
  done
  run grep -F "lab6::una_prova ${ID} " "${ITEM}/_docente/live.sh"
  expect "live.sh chiama la libreria del laboratorio" 0 'lab6::una_prova'
  test_impostazioni_partenza
  test_richieste
  test_refuso_seminato
}

# Il settings.json del punto di partenza: le regole prudenti del repository e
# l'hook, come lo vogliono gli strumenti; niente allow, niente bypass.
test_impostazioni_partenza() {
  run python3 -B -I - "${ITEM}/esercizio/.claude/settings.json" \
    "${RADICE}/.claude/settings.json" <<'PY'
import json
import sys

sue = json.load(open(sys.argv[1], encoding="utf-8"))
base = json.load(open(sys.argv[2], encoding="utf-8"))
atteso = [{"hooks": [{"type": "command", "command":
           'python3 "$CLAUDE_PROJECT_DIR/.claude/hooks/'
           'registra_caricamenti.py"'}]}]
if sue["permissions"]["deny"] != base["permissions"]["deny"]:
    sys.exit("deny diverse: %r" % sue["permissions"]["deny"])
if sue.get("hooks") != {"InstructionsLoaded": atteso}:
    sys.exit("hooks diversi: %r" % sue.get("hooks"))
if set(sue) != {"permissions", "hooks"} or set(sue["permissions"]) != {
        "deny"} or "bypass" in json.dumps(sue):
    sys.exit("chiavi in più: %r" % sue)
print("impostazioni giuste")
PY
  expect "settings.json: le regole prudenti e l'hook, nient'altro" 0 \
    'impostazioni giuste'
}

# prove/richieste.tsv: l'intestazione, le tre richieste come sono, gli
# strumenti di ciascuna.
test_richieste() {
  local i atteso=''
  for (( i = 0; i < ${#RICHIESTE[@]}; i++ )); do
    atteso+="${RICHIESTE[i]}"$'\t'"${STRUMENTI[i]}"$'\t'"${PROMPTS[i]}"$'\n'
  done
  if [[ "$(< "${ITEM}/prove/richieste.tsv")" \
      == "id"$'\t'"strumenti"$'\t'"prompt"$'\n'"${atteso%$'\n'}" ]]; then
    pass "prove/richieste.tsv: le tre richieste, con i loro strumenti"
  else
    fail "prove/richieste.tsv diverso: $(< "${ITEM}/prove/richieste.tsv")"
  fi
}

# Il refuso: il file del punto di partenza differisce da quello del progetto
# in una riga sola, e di una lettera sola.
test_refuso_seminato() {
  run python3 -B -I - "${ITEM}/esercizio/${FILE_REFUSO}" \
    "${RADICE}/${FILE_REFUSO}" "${REFUSO}" "${GIUSTO}" <<'PY'
import difflib
import sys

con = open(sys.argv[1], encoding="utf-8").read().split("\n")
senza = open(sys.argv[2], encoding="utf-8").read().split("\n")
diverse = [(a, b) for a, b in zip(con, senza) if a != b]
if len(con) != len(senza) or len(diverse) != 1:
    sys.exit("righe diverse: %d" % len(diverse))
a, b = diverse[0]
pezzi = [op for op in difflib.SequenceMatcher(None, a, b).get_opcodes()
         if op[0] != "equal"]
if len(pezzi) != 1 or max(pezzi[0][2] - pezzi[0][1],
                          pezzi[0][4] - pezzi[0][3]) != 1:
    sys.exit("non è una lettera: %r" % pezzi)
if sys.argv[3] not in a or sys.argv[4] not in b:
    sys.exit("il refuso non è quello atteso")
print("una lettera")
PY
  expect "il refuso: una riga, una lettera, nel testo atteso" 0 'una lettera'
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
  local f manca=''
  for f in "${FILE_REFUSO}" appunti-del-team.md .gitignore \
      .claude/settings.json .claude/hooks/registra_caricamenti.py; do
    [[ -f "${WS}/${f}" ]] || manca+=" ${f}"
  done
  if [[ -z "${manca}" ]]; then
    pass "nello spazio di lavoro c'è il punto di partenza"
  else
    fail "nello spazio di lavoro mancano:${manca}"
  fi
  manca=''
  for f in prove verifica.py soluzione _docente "${PROGETTO}/_docente" \
      CLAUDE.md .claude/rules; do
    [[ ! -e "${WS}/${f}" ]] || manca+=" ${f}"
  done
  if [[ -z "${manca}" ]]; then
    pass "nessun CLAUDE.md, nessuna verità, niente _docente/ del progetto"
  else
    fail "nello spazio di lavoro non devono esserci:${manca}"
  fi
  run grep -cF -- "${REFUSO}" "${WS}/${FILE_REFUSO}"
  expect "il refuso è nello spazio di lavoro" 0 1
  run git -C "${WS}" status --porcelain
  expect_absent "il punto di partenza è tutto nel primo commit" '??'
  verifica_cmd
  expect "verifica sul punto di partenza: 1, e dice che cosa manca" 1 \
    'MANCA' 'NON ANCORA' "tools/prova_contesto.sh ${ID} base"
  expect "il comando che manca ripete --radice, che c'era" 1 \
    "tools/prova_contesto.sh ${ID} base --radice $(cd -- "${RAD}" && pwd -P)"
  expect_absent "sul punto di partenza nessuna riga GARANZIA" 'GARANZIA'
  run "${ITEM}/verifica.sh"
  expect "verifica.sh senza argomenti: 2" 2 'spazio di lavoro assente'
  run "${ITEM}/verifica.sh" "${TMP}/non-esiste"
  expect "verifica.sh su una cartella che non c'è: 2" 2 \
    'spazio di lavoro assente'
}

# --- prove/prima.sh -----------------------------------------------------

test_prima_comune() {
  echo "prove/prima.sh:"
  local p="${ITEM}/prove/prima.sh" c="${TMP}/copia-prima"
  run "${p}"
  expect "senza argomenti: 2, l'uso" 2 'uso: prove/prima.sh'
  run "${p}" "${TMP}/non-esiste" t9
  expect "una copia che non c'è: 2" 2 'uso'
  rm -rf -- "${c}"
  mkdir -p "${c}/${FILE_REFUSO%/*}"
  cp -- "${RADICE}/${FILE_REFUSO}" "${c}/${FILE_REFUSO}"
  run "${p}" "${c}" t9
  expect "su una copia corretta: 0" 0
  ok_se "rimette il file del punto di partenza, con il refuso" cmp \
    "${ITEM}/esercizio/${FILE_REFUSO}" "${c}/${FILE_REFUSO}"
  rm -rf -- "${c}"
  mkdir -p "${c}"
  run "${p}" "${c}" t9
  expect "una copia senza il progetto: 2" 2 'la copia non ha'
  mkdir -p "${c}/${FILE_REFUSO%/*}"
  ln -s "${TMP}/altrove" "${c}/${FILE_REFUSO}"
  run "${p}" "${c}" t9
  expect "un collegamento al posto del file: 2" 2 'collegamento'
  ok_se "e non scrive attraverso il collegamento" test ! -e "${TMP}/altrove"
}

# --- il ciclo del README, con il claude finto -----------------------------

test_ciclo_comune() {
  echo "Il ciclo del README, con il claude finto:"
  local i
  log_vuoto
  nuovo_ws
  python3 -B -I - "${WS}/${FILE_REFUSO}" "${REFUSO}" "${GIUSTO}" <<'PY'
import sys

testo = open(sys.argv[1], encoding="utf-8").read()
open(sys.argv[1], "w", encoding="utf-8").write(
    testo.replace(sys.argv[2], sys.argv[3]))
PY
  mkdir -p "${WS}/${PROGETTO}/vendor" "${WS}/${PROGETTO}/var"
  prova_cmd base
  expect "base: tre esecuzioni, la garanzia, il confronto" 0 'finita' \
    'Garanzia, base: nessun file di istruzioni caricato in 3 su 3'
  run dal_log 'r["refuso"]'
  expect_absent "base: ogni copia ha il refuso, anche se lo spazio no" False
  run dal_log '(r["appunti"], r["vendor"])'
  expect_absent "base: nessuna copia ha gli appunti, né vendor/" True
  run dal_log 'r["memoria"]'
  expect_absent "base: la auto memory spenta in ogni esecuzione" None
  run dal_log '" ".join(r["argv"][:r["argv"].index("--")])'
  expect "i flag di ogni prova" 0 '--model sonnet' \
    '--permission-mode dontAsk' '--permission-prompts none' \
    '--output-format stream-json' '--verbose' \
    '--setting-sources project,local' '--effort low' '--strict-mcp-config' \
    '--no-session-persistence' \
    '--disallowedTools Bash(sudo *),Bash(git push *),Bash(curl *),Bash(wget *)'
  run dal_log '"%s|%s" % (r["argv"][r["argv"].index("--tools") + 1], r["prompt"])'
  for (( i = 0; i < ${#RICHIESTE[@]}; i++ )); do
    expect "${RICHIESTE[i]}: i suoi strumenti, la richiesta com'è" 0 \
      "${STRUMENTI[i]}|${PROMPTS[i]}"
  done
  verifica_cmd
  expect "dopo base: non ancora, manca la v1" 1 'MANCA la versione v1'
  printf '%s\n' "${V1_TESTO}" > "${WS}/CLAUDE.md"
  log_vuoto
  prova_cmd v1
  expect "v1: la garanzia, e il confronto con base" 0 \
    "Garanzia, v1: CLAUDE.md caricato all'avvio in 3 su 3" \
    "la riga «${RIF}»: confermata"
  log_vuoto
  prova_cmd v2
  expect "v2 uguale a v1: 2 prima di ogni chiamata, e lo dice" 2 \
    'v2 è uguale a v1' "tools/prova_contesto.sh ${ID} v2 --radice"
  if (( $(chiamate) == 0 )) && [[ ! -e "${WS}/prove-contesto/v2" ]]; then
    pass "v2 uguale a v1: nessuna chiamata, niente in prove-contesto/v2"
  else
    fail "v2 uguale a v1: $(chiamate) chiamate, o prove-contesto/v2 c'è"
  fi
  printf -- '- Una riga in più.\n' >> "${WS}/CLAUDE.md"
  prova_cmd v2
  verifica_cmd
  expect "il ciclo finito: fatto" 0 'VERIFICA OK' 'Fatto' \
    'v2 contro v1:' "Garanzia, v2: CLAUDE.md caricato all'avvio in 3 su 3"
  expect_absent "il ciclo finito: niente che manchi" 'MANCA'
  expect_absent "il ciclo finito: nessuna riga GARANZIA" 'GARANZIA'
}

test_garanzie_comuni() {
  echo "Le garanzie:"
  nuovo_ws
  FINTO_CARICA_SEMPRE=1 prova_cmd base
  expect "un file di istruzioni caricato in base: GARANZIA, 1" 1 \
    'GARANZIA base/' 'senza file di istruzioni si è caricato CLAUDE.md'
  verifica_cmd
  expect "la verifica dice lo stesso: 1" 1 'GARANZIA base/' 'NON ANCORA'
  nuovo_ws
  prova_cmd base
  printf '%s\n' "${V1_TESTO}" > "${WS}/CLAUDE.md"
  FINTO_NON_CARICA=1 prova_cmd v1
  expect "il CLAUDE.md che non si carica in v1: GARANZIA, 1" 1 'GARANZIA v1/' \
    "CLAUDE.md non si è caricato all'avvio"
  nuovo_ws
  FINTO_KO_SU="${PROMPTS[0]:0:20}" prova_cmd base
  expect "un'esecuzione senza risultato: 1, le altre finite" 1 \
    "FALLITA ${RICHIESTE[0]}" "finita ${RICHIESTE[1]}"
  verifica_cmd
  expect "la verifica lo sa: la sessione non è finita bene" 1 \
    "MANCA base/${RICHIESTE[0]}: la sessione non è finita bene"
  nuovo_ws
  FINTO_ERRORE_SU="${PROMPTS[2]:0:20}" prova_cmd base
  expect "un risultato con is_error: 1" 1 "FALLITA ${RICHIESTE[2]}"
}

# --- la prova dal vivo ----------------------------------------------------

# Arguments: facoltative, assegnazioni per l'ambiente (VAR=valore).
live() {
  log_vuoto
  nuovo_ws
  run env "$@" "${ITEM}/_docente/live.sh" "${WS}"
}

test_live_comune() {
  echo "La prova dal vivo, con il claude finto:"
  run "${ITEM}/_docente/live.sh"
  expect "live.sh senza lo spazio di lavoro: 2, e dice l'uso" 2 \
    'uso: _docente/live.sh <spazio di lavoro>'
  run "${ITEM}/_docente/live.sh" "${TMP}/non-esiste"
  expect "live.sh su una cartella che non c'è: 2" 2 'spazio di lavoro assente'
  live ANTHROPIC_API_KEY=finta-non-usata
  expect "live.sh da capo a fondo: 0" 0 'VERIFICA OK' 'Fatto' 'passo 2:' \
    'passo 3:' 'passo 5:' 'prove base:' 'prove v1:' 'prove v2:' \
    'turni del modello' 'la sessione ripresa'
  test_live_chiamate
  test_live_prompt
  test_live_risultato
  test_live_fallimenti
}

test_live_chiamate() {
  run chiamate
  expect "dodici chiamate: nove di prove, tre di scrittura" 0 12
  run dal_log 'r["chiave"]'
  expect_absent "ANTHROPIC_API_KEY non arriva mai a claude" True
  run dal_log 'r["memoria"]'
  expect_absent "la auto memory spenta anche nelle scritture" None
  run dal_log '"--tools" in r["argv"] or " ".join(r["argv"][:r["argv"].index("--")])'
  expect "la scrittura: Sonnet, effort medium, dontAsk, gli strumenti" 0 \
    '--model sonnet' '--effort medium' '--permission-mode dontAsk' \
    '--permission-prompts none' '--output-format stream-json' '--verbose' \
    '--setting-sources project,local' '--strict-mcp-config' \
    '--allowedTools Read,Glob,Grep,Write,Edit'
  run dal_log '"--tools" in r["argv"] or ("--resume" in r["argv"])'
  if [[ "$(grep -c False <<< "${OUT}")" == 1 \
      && "$(grep -c True <<< "${OUT}")" == 11 ]]; then
    pass "/init apre la sessione, il prompt 1 e il seguito la riprendono"
  else
    fail "le riprese: ${OUT}"
  fi
}

test_live_prompt() {
  local atteso1 json="${WS}.prova_dal_vivo"
  atteso1="$(prompt_readme "${ITEM}/README.md" 1)"
  run dal_log 'r["prompt"] == "/init"'
  expect "il primo passo di scrittura è /init" 0 True
  python3 -B -I - "${FINTO_LOG}" "${TMP}/scritture" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as fh:
    righe = [json.loads(r) for r in fh]
scritture = [r for r in righe if "--tools" not in r["argv"]]
for n, r in enumerate(scritture, 1):
    with open("%s.%d" % (sys.argv[2], n), "w", encoding="utf-8") as fh:
        fh.write(r["prompt"])
PY
  if [[ "$(< "${TMP}/scritture.2")" == "${atteso1}" ]]; then
    pass "il prompt 1 è quello del README, così com'è"
  else
    fail "il prompt 1 è diverso: $(< "${TMP}/scritture.2")"
  fi
  run cat "${TMP}/scritture.3"
  expect "il seguito: i percorsi della bozza, il confronto della v1" 0 \
    'bozza/rules/' 'bozza/settings.json' '<verification_result>' \
    'Il confronto delle versioni (dati' "Garanzia, v1:"
  expect_absent "il seguito non nomina .claude/" '.claude/'
  expect_absent "il seguito non ha più la riga da sostituire" \
    'Il confronto delle versioni …'
  ok_se "gli stream stanno fuori dallo spazio di lavoro" test -s \
    "${json}/passo-5.jsonl"
  ok_se "la bozza di /init è tenuta accanto agli stream" test -s \
    "${json}/bozza-init.md"
  ok_se "il confronto della v1 è tenuto accanto agli stream" test -s \
    "${json}/confronto-v1.txt"
}

test_live_risultato() {
  ok_se "alla fine la bozza non c'è più" test ! -e "${WS}/bozza"
  run cat "${WS}/${REGOLA%/*}/"*.md
  expect "la regola è in .claude/rules/, con paths:" 0 'paths:' "${GLOB}"
  run python3 -B -I - "${WS}/.claude/settings.json" \
    "${ITEM}/esercizio/.claude/settings.json" <<'PY'
import json
import sys

nuovo = json.load(open(sys.argv[1], encoding="utf-8"))
vecchio = json.load(open(sys.argv[2], encoding="utf-8"))
if nuovo["hooks"] != vecchio["hooks"]:
    sys.exit("l'hook è cambiato")
if len(nuovo["permissions"]["deny"]) <= len(vecchio["permissions"]["deny"]):
    sys.exit("nessuna regola deny in più")
print("deny in più, l'hook com'era")
PY
  expect "settings.json: le regole deny in più, l'hook com'era" 0 'in più'
  ok_se "le tre versioni hanno girato" test -d "${WS}/prove-contesto/base" \
    -a -d "${WS}/prove-contesto/v1" -a -d "${WS}/prove-contesto/v2"
}

test_live_fallimenti() {
  local n
  nuovo_ws
  printf 'lavoro\n' > "${WS}/appunti-miei.txt"
  log_vuoto
  run "${ITEM}/_docente/live.sh" "${WS}"
  expect "uno spazio di lavoro con del lavoro: 2" 2 \
    "tools/reset_esercizio.sh ${ID}"
  n="$(chiamate)"
  if (( n == 0 )); then pass "e nessuna chiamata"; else fail "${n} chiamate"; fi
  live FINTO_SENZA_INIT=1
  expect "/init che non scrive il file: 1" 1 'passo 2: /init non ha scritto'
  live FINTO_NON_CAMBIA=1
  expect "il prompt 1 che non cambia il file: 1" 1 \
    'passo 3: il CLAUDE.md non è cambiato'
  live FINTO_TOGLIE_HOOK=1
  expect "un seguito che toglie l'hook: 1, prima delle prove della v2" 1 \
    "l'hook InstructionsLoaded non è più quello di prima"
  run chiamate
  expect "tre, tre e tre chiamate: nessuna prova della v2" 0 9
  live FINTO_SEGUITO_NULLO=1
  expect "un seguito che non cambia niente: le prove della v2 non partono" 2 \
    'v2 è uguale a v1' "tools/prova_contesto.sh ${ID} v2 è uscito con 2"
  run chiamate
  expect "un seguito che non cambia niente: nessuna prova della v2" 0 9
  live 'FINTO_KO_SU=<role>'
  expect "il prompt 1 fallito: 1, niente dopo" 1 'VERIFICA KO' 'passo 3'
  run chiamate
  expect "tre prove, /init e il prompt 1" 0 5
  log_vuoto
  nuovo_ws
  mkdir -p "${WS}.prova_dal_vivo/confronto-v1.txt"
  run "${ITEM}/_docente/live.sh" "${WS}"
  expect "il confronto della v1 che non si tiene: 1, e il perché si vede" 1 \
    'VERIFICA KO' 'le prove della v1 non hanno stampato il confronto'
  nuovo_ws
  mkdir -p "${WS}.prova_dal_vivo"
  printf '{}\n' > "${WS}.prova_dal_vivo/passo-2.jsonl"
  log_vuoto
  run "${ITEM}/_docente/live.sh" "${WS}"
  expect "gli stream di una prova di prima: 2" 2 "c'è già una prova"
}

# --- il README ----------------------------------------------------------

test_readme_comune() {
  echo "Il README:"
  test_readme_sezioni
  test_readme_prompt_1
  test_readme_seguito
  test_readme_due_tracce
  test_readme_parole
}

test_readme_sezioni() {
  local r="${ITEM}/README.md" s ok=1 ultimo=0 riga
  for s in 'Obiettivo' 'Tempo' 'Prerequisiti' \
      "Punto di partenza (tools/prepara_esercizio.sh ${ID})" \
      'Passi in Claude Code' 'Che cosa osservare' \
      "Verifica (tools/verifica.sh ${ID})" 'Se qualcosa va storto' \
      "Impronta d'uso sul piano Pro" 'Per approfondire'; do
    riga="$(grep -nF -x -- "## ${s}" "${r}" | head -n 1)"
    riga="${riga%%:*}"
    if [[ -z "${riga}" ]] || (( riga <= ultimo )); then
      ok=0
    else
      ultimo="${riga}"
    fi
  done
  if (( ok == 1 )); then
    pass "le dieci sezioni, in ordine"
  else
    fail "le dieci sezioni non ci sono tutte, in ordine"
  fi
  run grep -c '^## ' "${r}"
  expect "nessuna sezione in più" 0 10
}

test_readme_prompt_1() {
  local p
  p="$(prompt_readme "${ITEM}/README.md" 1)" || p=''
  run python3 -B -I - "${p}" <<'PY'
import re
import sys

testo = sys.argv[1]
TAG = ["role", "context", "instructions", "format", "constraints"]
if re.findall(r"^<([a-z_]+)>$", testo, re.M) != TAG \
        or re.findall(r"^</([a-z_]+)>$", testo, re.M) != TAG:
    sys.exit("i tag non sono i cinque, in ordine")
ruolo = re.search(r"<role>\n(.*?)\n</role>", testo, re.S).group(1)
ruolo = " ".join(ruolo.split())
if not ruolo.startswith("Sei ") or not ruolo.endswith(".") \
        or re.search(r"[.!?] [A-Z]", ruolo):
    sys.exit("il ruolo non è una frase che comincia con «Sei »: %r" % ruolo)
if len(re.sub(r"<[^>]+>", " ", testo).split()) < 60:
    sys.exit("meno di 60 parole")
passi = re.search(r"<instructions>\n(.*?)\n</instructions>", testo,
                  re.S).group(1)
numeri = re.findall(r"^(\d+)\. ", passi, re.M)
if numeri != [str(n) for n in range(1, len(numeri) + 1)] or len(numeri) < 3:
    sys.exit("passi: %r" % numeri)
ultimo = passi[passi.rindex("%s. " % numeri[-1]):]
if "Per ultimo" not in ultimo or "conta le righe" not in ultimo:
    sys.exit("l'ultimo passo non è il controllo: %r" % ultimo)
if any(len(r) > 66 for r in testo.split("\n")):
    sys.exit("una riga oltre 66 colonne")
if ".claude/" in testo:
    sys.exit("nomina .claude/")
print("il template")
PY
  expect "il prompt 1: i cinque tag, il ruolo, i passi, l'ultimo il controllo" \
    0 'il template'
  OUT="$(tr -s '[:space:]' ' ' <<< "${p}")"
  RC=0
  expect "il prompt 1 nomina i file, senza incollarli" 0 'CLAUDE.md' \
    'appunti-del-team.md' '/init'
  expect "il prompt 1: le due domande, il formato del file, sotto 200 righe" 0 \
    'troverebbe leggendo il repository' 'Andrebbe davvero a cercarla' \
    'titoli Markdown ed elenchi puntati' '200 righe' 'CLAUDE.local.md' \
    'regola deny'
}

test_readme_seguito() {
  local p
  p="$(prompt_readme "${ITEM}/README.md" 2)" || p=''
  run python3 -B -I - "${p}" <<'PY'
import re
import sys

testo = sys.argv[1]
TAG = ["context", "instructions", "format", "constraints",
       "verification_result"]
if re.findall(r"^<([a-z_]+)>$", testo, re.M) != TAG \
        or re.findall(r"^</([a-z_]+)>$", testo, re.M) != TAG:
    sys.exit("i tag: %r" % re.findall(r"^<([a-z_]+)>$", testo, re.M))
dati = re.search(r"<verification_result>\n(.*?)\n</verification_result>",
                 testo, re.S).group(1)
if "\n" in dati:
    sys.exit("più di una riga fra i tag verification_result")
passi = re.search(r"<instructions>\n(.*?)\n</instructions>", testo,
                  re.S).group(1)
numeri = re.findall(r"^(\d+)\. ", passi, re.M)
if "Per ultimo" not in passi[passi.rindex("%s. " % numeri[-1]):]:
    sys.exit("l'ultimo passo non è il controllo")
if any(len(r) > 66 for r in testo.split("\n")):
    sys.exit("una riga oltre 66 colonne")
print("il seguito")
PY
  expect "il seguito: i tag senza il ruolo, i dati per ultimi, una riga" 0 \
    'il seguito'
  OUT="$(tr -s '[:space:]' ' ' <<< "${p}")"
  RC=0
  expect "il seguito: la regola con paths, le deny, l'hook com'era" 0 \
    '.claude/rules/' 'paths:' '.claude/settings.json' 'deny' "l'hook"
}

# Lo stesso testo nelle due tracce: il metodo non cambia con il progetto.
test_readme_due_tracce() {
  local n
  for n in 1 2; do
    if [[ "$(prompt_readme "${ITEM}/README.md" "${n}")" \
        == "$(prompt_readme "${ALTRO}/README.md" "${n}")" ]]; then
      pass "il prompt ${n} è lo stesso nelle due tracce"
    else
      fail "il prompt ${n} è diverso nell'altra traccia"
    fi
  done
}

# Le frasi su STDIN, una per riga, parola per parola nel README.
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
  controlla_frasi "le frasi di Anthropic, parola per parola, e le pagine" \
    <<'FRASI'
We recommend starting a project without a CLAUDE.md file so you can see where you constantly have to course-correct the model.
https://academy.claude.com/courses/claude-code-101/the-claude-md-file
Only write down what Claude can't find by reading the repo, or what it would otherwise spend time rediscovering every session.
https://code.claude.com/docs/en/best-practices
Could it find this by reading the code?
Would it actually go and look?
If both are yes, leave it out.
A decision your team made in a meeting
How to confirm work in this repo: the exact test, typecheck, and lint commands, and how to run a single test file
Structure: group related instructions under markdown headers and bullets. Organized sections are easier for Claude to follow than dense paragraphs.
https://code.claude.com/docs/en/memory
target under 200 lines per CLAUDE.md file. Longer files consume more context and reduce adherence.
Keep it under a page, because Claude reads all of it at the start of a session
https://academy.claude.com/courses/ai-native-sdlc-playbook/claude-md
Your CLAUDE.md file loads into the context at the start of every session, so each line in it is part of what every turn resends.
https://claude.dev/blog/what-a-task-costs-on-opus-5-5/
every line in it takes a little of Claude's attention on every task, whether it's relevant or not.
CLAUDE.md and CLAUDE.local.md files in the directory hierarchy above the working directory are loaded at launch.
If an entry is a multi-step procedure or only matters for one part of the codebase, move it to a skill or a path-scoped rule
A path-scoped rule loads when Claude uses the Read, Write, or Edit tool on a matching file.
Claude Code (the harness) has to execute this. This can be a hook, a deny rule, or a managed setting.
Settings rules are enforced by the client … CLAUDE.md instructions shape Claude's behavior but are not a hard enforcement layer.
Edit rules apply to all built-in tools that edit files.
https://code.claude.com/docs/en/permissions
For private per-project preferences that shouldn't be checked into version control, create a CLAUDE.local.md at the project root.
In an interactive session, Claude Code shows the workspace trust dialog when you start it in a folder you haven’t trusted.
https://code.claude.com/docs/en/security
Initialize project with a CLAUDE.md guide.
https://code.claude.com/docs/en/commands
Your project-root and user-level CLAUDE.md files are read once at session start and held in memory.
https://code.claude.com/docs/en/prompt-caching
To confirm the file loaded, run /context all in a session and check the list under Memory files.
Yes, and allow Claude to edit files in this project's .claude folder for this session
https://code.claude.com/docs/en/permission-modes
The new content loads on the next /clear, /compact, or restart.
Pro, Max, Ultra, Team, Enterprise, and Anthropic API: defaults to Opus 5.5
https://code.claude.com/docs/en/model-config
Sonnet handles most coding tasks well and costs less than Opus.
https://code.claude.com/docs/en/costs
These limits are shared across Claude and Claude Code, meaning all activity in both tools counts against the same limits.
https://support.claude.com/en/articles/11145838-use-claude-code-with-your-pro-max-or-ultra-plan
Use modelUsage, or model_usage in Python, for whole-tree token accounting; the usage field undercounts as soon as nesting occurs.
https://code.claude.com/docs/en/agent-sdk/cost-tracking
On Pro, Max, Ultra, Team, and Enterprise it breaks your usage down by skill, subagent, plugin, and MCP server.
claude -p discovers and loads them as an interactive session would
https://code.claude.com/docs/en/headless
Set to 1 to disable auto memory.
https://code.claude.com/docs/en/env-vars
FRASI
  local f manca='' piatto
  piatto="$(LC_ALL=C tr -s '[:space:]' ' ' < "${ITEM}/README.md")"
  for f in "tools/prepara_esercizio.sh ${ID}" \
      "tools/prova_contesto.sh ${ID} base" "tools/prova_contesto.sh ${ID} v1" \
      "tools/prova_contesto.sh ${ID} v2" "tools/verifica.sh ${ID}" \
      'claude --model sonnet --effort medium' '/init' \
      'claude -p "/context all"' 'diff -rN v1/fotografia v2/fotografia' \
      "tools/reset_esercizio.sh ${ID}" 'path_glob_match' 'CLAUDE.local.md' \
      'confermata' 'non distinguibile' 'non confermata in questa misura' \
      'GARANZIA' 'MANCA'; do
    [[ "${piatto}" == *"${f}"* ]] || manca+=" «${f}»"
  done
  if [[ -z "${manca}" ]]; then
    pass "i comandi dei passi e le parole del controllo"
  else
    fail "mancano:${manca}"
  fi
  local i
  for (( i = 0; i < ${#RICHIESTE[@]}; i++ )); do
    [[ "${piatto}" == *"«${PROMPTS[i]}»"* ]] \
      || manca+=" «${PROMPTS[i]}»"
  done
  if [[ -z "${manca}" ]]; then
    pass "il README mostra le tre richieste come sono"
  else
    fail "il README non mostra:${manca}"
  fi
}

test_readme_parole() {
  local r="${ITEM}/README.md"
  local vietate='smentit|prossima sessione|\boggi\b|\bdomani\b|pranzo'
  vietate+='|Percorso A\b|il vostro codice|vostro repository|i vostri file'
  run grep -nEi "${vietate}" "${r}"
  expect "nessuna «smentita», niente orario, niente codice vostro" 1
  run grep -nE "${INTERNI}" "${r}"
  expect "nessun nome interno nel README" 1
  run grep -rnE "${INTERNI}" "${ITEM}/verifica.py" "${ITEM}/verifica.sh" \
    "${ITEM}/prove" "${ITEM}/esercizio"
  expect "nessun nome interno nei file per i partecipanti" 1
  run grep -rnE "${INTERNI}" "${ITEM}/_docente" "${ITEM}/soluzione" \
    "${FINTO_PY}" "${MOD}/_docente/lib_lab_m6.sh"
  expect "nessun nome interno nei file del docente" 1
  run grep -n 'la registrazione: le righe\|le cifre, dalla registrazione' "${r}"
  expect "nessun segnaposto della registrazione rimasto" 1
}

# --- la soluzione --------------------------------------------------------

test_soluzione_comune() {
  echo "La soluzione:"
  local s="${ITEM}/soluzione" n
  n="$(wc -l < "${s}/CLAUDE.md" | tr -d ' ')"
  if (( n <= 19 )); then
    pass "il CLAUDE.md di riferimento sta in una slide: ${n} righe"
  else
    fail "il CLAUDE.md di riferimento ha ${n} righe, oltre 19"
  fi
  run grep -cE '^(# |## |- )' "${s}/CLAUDE.md"
  if (( RC == 0 )) && (( OUT >= 6 )); then
    pass "titoli Markdown ed elenchi puntati"
  else
    fail "titoli ed elenchi: ${OUT}"
  fi
  run grep -nE '^<(role|context|instructions|format|constraints)>' \
    "${s}/CLAUDE.md" "${s}/${REGOLA}"
  expect "nessun tag del template nei file di istruzioni" 1
  run grep -F -- "${RIF%0}" "${s}/CLAUDE.md"
  expect "il CLAUDE.md porta la riga Rif: degli appunti" 0 "${RIF%0}"
  run python3 -B -I - "${s}/${REGOLA}" "${GLOB}" <<'PY'
import re
import sys

testo = open(sys.argv[1], encoding="utf-8").read()
m = re.match(r"---\npaths:\n((?:  - .+\n)+)---\n", testo)
if not m:
    sys.exit("nessun frontmatter con paths:")
globi = [g.strip()[2:].strip().strip('"') for g in m.group(1).splitlines()]
if sys.argv[2] not in globi:
    sys.exit("paths: %r" % globi)
print("paths giusto")
PY
  expect "la regola: il frontmatter con paths: e il suo percorso" 0 \
    'paths giusto'
  test_soluzione_impostazioni
  run cat "${s}/LEGGIMI.md"
  expect "LEGGIMI.md dice che cosa c'è e da dove viene" 0 "${ID}" 'CLAUDE.md' \
    "${REGOLA}"
  test_soluzione_applicata
}

test_soluzione_impostazioni() {
  run python3 -B -I - "${ITEM}/soluzione/.claude/settings.json" \
    "${ITEM}/esercizio/.claude/settings.json" "${DENY_NUOVE[@]}" <<'PY'
import json
import sys

sue = json.load(open(sys.argv[1], encoding="utf-8"))
base = json.load(open(sys.argv[2], encoding="utf-8"))
if sue.get("hooks") != base["hooks"]:
    sys.exit("l'hook non è quello del punto di partenza")
if sue["permissions"]["deny"] != base["permissions"]["deny"] + sys.argv[3:]:
    sys.exit("deny: %r" % sue["permissions"]["deny"])
print("deny giuste")
PY
  expect "settings.json: le regole prudenti, le deny nuove, l'hook" 0 \
    'deny giuste'
}

# soluzione/ copiata su uno spazio di lavoro nuovo: con la registrazione del
# corso in prove-contesto/ la verifica passa; senza, dice che mancano le prove.
test_soluzione_applicata() {
  nuovo_ws
  cp -R "${ITEM}/soluzione/." "${WS}/" || exit 2
  verifica_cmd
  if [[ -d "${ITEM}/soluzione/prove-contesto" ]]; then
    expect "soluzione/ con la registrazione: la verifica passa" 0 'VERIFICA OK'
  else
    expect "soluzione/ senza la registrazione: non ancora, mancano le prove" 1 \
      "MANCA la versione base non ha girato"
  fi
}

# --- la registrazione del corso -------------------------------------------

# Le righe del README che vengono dal controllo, su STDIN («= riga»), contro
# la sua uscita sulla registrazione: soluzione/prove-contesto/, o lo spazio di
# lavoro di PN_M6_REGISTRAZIONE. Senza nessuna delle due: SKIP, contato.
test_registrazione_comune() {
  local ws='' righe f manca=''
  righe="$(cat)"
  if [[ -d "${ITEM}/soluzione/prove-contesto" ]]; then
    nuovo_ws
    cp -R "${ITEM}/soluzione/." "${WS}/" || exit 2
    ws="${WS}"
  elif [[ -n "${PN_M6_REGISTRAZIONE:-}" ]]; then
    ws="${PN_M6_REGISTRAZIONE}"
  fi
  if [[ -z "${ws}" ]]; then
    echo "  SKIP: la registrazione non è ancora in soluzione/prove-contesto/" \
      "(2 casi)"
    SKIP=$((SKIP + 2))
    return 0
  fi
  verifica_py "${ws}"
  while IFS= read -r f; do
    [[ -n "${f}" ]] || continue
    grep -qF -- "${f#= }" <<< "${OUT}" || manca+=" «${f#= }»"
  done <<< "${righe}"
  if (( RC == 0 )) && [[ -z "${manca}" ]]; then
    pass "il README cita le righe che il controllo stampa sulla registrazione"
  else
    fail "registrazione (uscita ${RC}): mancano${manca}"
  fi
  controlla_frasi "le righe citate stanno nel README" \
    <<< "$(sed -n 's/^= //p' <<< "${righe}")"
}

# --- gli strumenti ------------------------------------------------------

# Le funzioni che i verifica.py delle due tracce hanno in comune devono
# restare uguali, byte per byte: una correzione in una traccia va anche
# nell'altra. RC e OUT come run.
test_gemelle() {
  run python3 -B -I - "${ITEM}/verifica.py" "${ALTRO}/verifica.py" <<'PY'
import ast
import sys

GEMELLE = ("corto", "righe_cambiate", "corretto", "un_commit", "soggetto",
           "riga_rif", "file_cambiati", "soltanto_quel_file", "intatti",
           "risposta", "righe_del_file", "testo_finale", "main")


def funzioni(percorso):
    testo = open(percorso, encoding="utf-8").read()
    return {nodo.name: ast.get_source_segment(testo, nodo)
            for nodo in ast.parse(testo).body
            if isinstance(nodo, ast.FunctionDef)}


qui, altra = funzioni(sys.argv[1]), funzioni(sys.argv[2])
diverse = [n for n in GEMELLE if n not in qui or qui.get(n) != altra.get(n)]
if diverse:
    sys.exit("gemelle diverse, o assenti: %s" % ", ".join(diverse))
print("gemelle uguali: %d" % len(GEMELLE))
PY
}

test_strumenti_comuni() {
  echo "shellcheck, check_handson, Python 3.8, bash 3.2:"
  local f lib="${MOD}/_docente/lib_test_lab_m6.sh"
  local lab="${MOD}/_docente/lib_lab_m6.sh"
  for f in "${ITEM}/verifica.sh" "${ITEM}/_docente/live.sh" \
      "${ITEM}/prove/prima.sh" "${SELF}" "${lib}" "${lab}"; do
    run bash -c 'cd "$1" && shellcheck -x -- "$2"' _ "${RADICE}" "${f}"
    expect "shellcheck pulito: ${f#"${MOD}"/}" 0
  done
  run "${RADICE}/tools/check_handson.sh"
  expect_absent "check_handson non segnala niente di ${ID}" "${ID}"
  ok_se "le librerie non hanno il bit di esecuzione" test ! -x "${lib}" \
    -a ! -x "${lab}"
  for f in "${ITEM}/verifica.py" "${FINTO_PY}"; do
    run python3 -B -I -c '
import ast
import sys

ast.parse(open(sys.argv[1], encoding="utf-8").read(), feature_version=(3, 8))
print("ok")' "${f}"
    expect "la sintassi di Python 3.8: ${f##*/}" 0 ok
  done
  test_gemelle
  expect "le funzioni gemelle dei due verifica.py sono uguali" 0 \
    'gemelle uguali: 13'
  local recenti='readarray|mapfile|declare -A|local -A|wait -n'
  recenti+='|\$\{[a-z_]+(,,|\^\^)\}'
  run grep -nE "${recenti}" "${ITEM}/verifica.sh" "${ITEM}/_docente/live.sh" \
    "${ITEM}/prove/prima.sh" "${lab}"
  expect "niente che il bash 3.2 non abbia" 1
  run awk 'length($0) > 80 { print FILENAME ":" FNR }' "${ITEM}/verifica.sh" \
    "${ITEM}/_docente/live.sh" "${ITEM}/prove/prima.sh" "${lab}"
  if [[ "${RC}" == 0 && -z "${OUT}" ]]; then
    pass "gli script stanno in 80 colonne"
  else
    fail "oltre 80 colonne: ${OUT}"
  fi
}

# Il riepilogo: non torna con più o meno casi di quelli attesi, SKIP a parte.
# Globals: PASS, FAIL, SKIP, SUITE. Arguments: $1 i casi attesi.
chiudi_suite() {
  echo "${SUITE}: PASS=${PASS} FAIL=${FAIL} SKIP=${SKIP}"
  (( FAIL == 0 )) || exit 1
  if (( PASS + SKIP != $1 )); then
    echo "${SUITE}: ${PASS} casi e ${SKIP} SKIP, attesi $1" >&2
    exit 2
  fi
}
