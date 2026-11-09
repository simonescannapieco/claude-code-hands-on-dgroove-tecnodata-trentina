#!/bin/bash
#
# test_m7_e02.sh -- le prove di M7-E02 «Riprogettare un'interazione», per il
# docente:
#   - l'elemento: i file, il modello copiato da riferimenti/, la v1 di
#     riferimento (JSON valido con le capacità del banco, descrizioni di
#     almeno tre frasi, passa_a_operatore con motivo, riepilogo e priorità, il
#     prompt nel template, le regole nel tag procedures);
#   - il README: le dieci sezioni, le frasi di Anthropic con l'indirizzo, i
#     tre prompt (i primi due nel template, il terzo un seguito senza ruolo);
#   - prepara_esercizio.sh e verifica.sh sul punto di partenza (1);
#   - verifica.py sulle esecuzioni fatte qui con il claude finto (i veri
#     prova.py e lib_banco): ogni confronto (sempre 0), le versioni o i casi
#     che mancano, le chiamate non finite (1), ciò che non si legge (2), mai un
#     traceback; il controllo legge le esecuzioni, non esito.json;
#   - _docente/live.sh con il claude finto: tre prompt del README con --resume,
#     effort medium e gli strumenti giusti, dieci prove sul banco, senza
#     ANTHROPIC_API_KEY; le precondizioni (2, nessuna chiamata: l'esca); una
#     chiamata fallita o una prova non finita (1);
#   - shellcheck -x sugli script e su questo file.
# Mai il claude vero: il finto e l'esca stanno davanti nel PATH, e la suite lo
# controlla prima di usarli. Gli spazi di lavoro nascono in una cartella
# temporanea: l'albero del repository non cambia. CASES è il numero dei casi:
# se ne girano di più o di meno la suite esce 2.
#
# Uso:    m7_assistenti_llm/_docente/test_m7_e02.sh
# Uscita: 0 = tutti i casi passano · 1 = almeno un caso fallito · 2 =
#         precondizione (manca python3, git, jq o shellcheck), o un numero di
#         casi diverso da CASES
set -uo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly MOD="${SELF%/_docente/*}"
readonly RADICE="${MOD%/*}"
readonly SUB="s5_anatomia_e_strumenti/m7_e2_riprogettare"
readonly E02="${MOD}/${SUB}/M7-E02_riprogettare"
readonly FINTO_PY="${MOD}/_docente/claude_finto_m7_e02.py"
# La libreria del repository, per la base dei file temporanei.
# shellcheck source=../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"
readonly CASES=96
readonly FATTO="Fatto: v1/ c'è e le due versioni hanno girato"
readonly PROVA="progetti/assistenza-clienti/banco/prova.py"
TMP=''
PASS=0
FAIL=0
RC=0
OUT=''
TUTTO=''

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

run() { OUT="$("$@" 2>&1)"; RC=$?; TUTTO+="${OUT}"$'\n'; }

expect() {
  if (( RC == $2 )) && grep -qF -- "$3" <<< "${OUT}"; then
    pass "$1"
  else
    fail "$1 (rc=${RC}, attesa $2, parola «$3»): ${OUT:0:800}"
  fi
}

expect_absent() {
  if grep -qF -- "$2" <<< "${OUT}"; then
    fail "$1: «$2» c'è: ${OUT:0:400}"
  else
    pass "$1"
  fi
}

vero() {
  local nome="$1"
  shift
  if "$@"; then pass "${nome}"; else fail "${nome}"; fi
}

nuovo_ws() {
  local __r
  __r="$(mktemp -d "${TMP}/radice.XXXXXX")" || exit 2
  "${RADICE}/tools/prepara_esercizio.sh" M7-E02 --radice "${__r}" \
    > "${TMP}/prepara.log" 2>&1 || return 1
  printf -v "$1" '%s' "${__r}/M7-E02"
}

# Il claude finto (uno script che legge i suoi modi da un file), uv finto,
# l'esca e i PATH ridotti.
prepara_finti() {
  local t
  mkdir -p "${TMP}/finto" "${TMP}/esca" "${TMP}/senza_uv" \
    "${TMP}/senza_claude" "${TMP}/senza_jq" || exit 2
  cat > "${TMP}/finto/claude" <<WRAP || exit 2
#!/bin/bash
if [[ -f "${TMP}/modo" ]]; then set -a; source "${TMP}/modo"; set +a; fi
export FINTO_LOG="${TMP}/finto.log"
exec python3 -B -I "${FINTO_PY}" "\$@"
WRAP
  printf '%s\n' '#!/bin/bash' 'exit 0' > "${TMP}/finto/uv" || exit 2
  # shellcheck disable=SC2016  # il corpo è dell'esca
  printf '%s\n' '#!/bin/bash' \
    'printf "invocazione %s\n" "$*" >> "${ESCA_LOG}"' \
    > "${TMP}/esca/claude" || exit 2
  printf '%s\n' '#!/bin/bash' 'exit 0' > "${TMP}/esca/uv" || exit 2
  chmod 755 "${TMP}/finto/claude" "${TMP}/finto/uv" "${TMP}/esca/claude" \
    "${TMP}/esca/uv" || exit 2
  for t in readlink python3 git jq mktemp cat dirname mkdir rm sed; do
    ln -s "$(command -v "${t}")" "${TMP}/senza_uv/${t}" || exit 2
    ln -s "$(command -v "${t}")" "${TMP}/senza_claude/${t}" || exit 2
  done
  ln -s "${TMP}/esca/claude" "${TMP}/senza_uv/claude" || exit 2
  ln -s "${TMP}/esca/uv" "${TMP}/senza_claude/uv" || exit 2
  for t in readlink python3 git mktemp cat dirname mkdir rm sed; do
    ln -s "$(command -v "${t}")" "${TMP}/senza_jq/${t}" || exit 2
  done
  ln -s "${TMP}/esca/claude" "${TMP}/senza_jq/claude" || exit 2
  ln -s "${TMP}/esca/uv" "${TMP}/senza_jq/uv" || exit 2
  t="$(PATH="${TMP}/finto:${PATH}" command -v claude)"
  if [[ "${t}" != "${TMP}/finto/claude" ]]; then
    echo "test_m7_e02: nel PATH di prova claude è ${t}, non il finto" >&2
    exit 2
  fi
}

modo() {
  : > "${TMP}/modo"
  local v
  for v in "$@"; do printf '%q\n' "${v}" >> "${TMP}/modo"; done
}

finto() {
  local script="$1" w="$2"
  shift 2
  : > "${TMP}/finto.log"
  run env PATH="${TMP}/finto:${PATH}" HANDSON_NO_PAUSE=1 \
    ANTHROPIC_API_KEY=valore-finto CLAUDE_CODE_EFFORT_LEVEL=high \
    TMPDIR="${TMP}" "$@" "${script}" "${w}"
}

esca() {
  local script="$1" w="$2" percorso="${3:-${TMP}/esca:${PATH}}"
  shift 2
  (( $# == 0 )) || shift
  : > "${TMP}/esca.log"
  run env PATH="${percorso}" HANDSON_NO_PAUSE=1 ESCA_LOG="${TMP}/esca.log" \
    "$@" "${script}" "${w}"
}

precondizione() {
  local nome="$1" parola="$2" n
  shift 2
  esca "$@"
  expect "${nome}" 2 "${parola}"
  n="$(grep -c -v -- '--version' "${TMP}/esca.log")"
  if (( n == 0 )); then
    pass "${nome}: nessuna chiamata al modello"
  else
    fail "${nome}: ${n} chiamate: $(head -n 2 "${TMP}/esca.log")"
  fi
}

# Le prove sul banco con il claude finto, nello spazio di lavoro; v1/ la crea
# il finto (i prompt di scrittura) se non c'è. Arguments: $1 lo spazio, $2 la
# versione (v0 o v1), $3 la cartella di uscita (default risultati/$2).
prova() {
  local ws="$1" v="$2" u="${3:-risultati/$2}" d
  d="${ws}/progetti/assistenza-clienti/v0"
  [[ "${v}" == v0 ]] || d="${ws}/v1"
  : > "${TMP}/finto.log"
  run env PATH="${TMP}/finto:${PATH}" TMPDIR="${TMP}" \
    python3 -B -I "${ws}/${PROVA}" casi --versione "${d}" \
    --uscita "${ws}/${u}"
}

# Una v1 finta ma ben formata nello spazio di lavoro. Arguments: $1 lo spazio.
v1_finta() {
  local ws="$1"
  mkdir -p "${ws}/v1" || exit 2
  cp -- "${E02}/soluzione/v1/system-prompt.md" "${ws}/v1/" || exit 2
  cp -- "${E02}/soluzione/v1/strumenti.json" "${ws}/v1/" || exit 2
  cp -- "${E02}/soluzione/v1/regole-escalation.md" "${ws}/v1/" || exit 2
}

verifica() { run "${E02}/verifica.sh" "$@"; }

controlla_chiamate() {
  run python3 -B -I - "$1" "${E02}" <<'PY'
import json, sys, textwrap
log, item = sys.argv[1:3]
righe = [json.loads(r) for r in open(log, encoding="utf-8")]
readme = open(item + "/README.md", encoding="utf-8").read().split("\n")
def prompt(n):
    a = readme.index("   <!-- prompt %d -->" % n)
    b = readme.index("   <!-- /prompt %d -->" % n)
    return textwrap.dedent("\n".join(readme[a + 1:b])).strip("\n")
chiamate = [c for c in righe if c["argv"] != ["--version"]]
def opt(argv, nome):
    return argv[argv.index(nome) + 1] if nome in argv else None
problemi = []
scrittura = [c for c in chiamate if "--mcp-config" not in c["argv"]]
banco = [c for c in chiamate if "--mcp-config" in c["argv"]]
if len(scrittura) != 3:
    problemi.append("chiamate di scrittura: %d" % len(scrittura))
if len(banco) != 10:
    problemi.append("chiamate sul banco: %d" % len(banco))
for i, c in enumerate(scrittura, 1):
    a = c["argv"]
    if a[a.index("--") + 1:] != [prompt(i)]:
        problemi.append("scrittura %d: il prompt non è quello del README" % i)
    attese = (("--model", "sonnet"), ("--effort", "medium"),
              ("--allowedTools", "Read,Glob,Grep,Write,Edit"),
              ("--tools", "Read,Glob,Grep,Write,Edit"),
              ("--permission-mode", "dontAsk"),
              ("--permission-prompts", "none"), ("--output-format", "json"),
              ("--setting-sources", "project,local"))
    for k, v in attese:
        if opt(a, k) != v:
            problemi.append("scrittura %d: %s = %s" % (i, k, opt(a, k)))
    if "--strict-mcp-config" not in a:
        problemi.append("scrittura %d: --strict-mcp-config" % i)
    if i == 1 and "--resume" in a:
        problemi.append("scrittura 1: --resume")
    if i > 1 and opt(a, "--resume") != "sessione-finta-e02":
        problemi.append("scrittura %d: --resume %s" % (i, opt(a, "--resume")))
for c in banco:
    a = c["argv"]
    if opt(a, "--model") != "sonnet" or opt(a, "--effort") != "low" \
            or opt(a, "--tools") != "" \
            or opt(a, "--allowedTools") != "mcp__assistenza__*" \
            or "--no-session-persistence" not in a:
        problemi.append("banco: opzioni %s" % a)
for c in chiamate:
    if c["chiave"] or c["effort"]:
        problemi.append("con ANTHROPIC_API_KEY o CLAUDE_CODE_EFFORT_LEVEL")
    if any("dangerously" in x or "bypassPermissions" in x for x in c["argv"]):
        problemi.append("salta i permessi")
print("; ".join(sorted(set(problemi))) or "chiamate giuste")
PY
}

# --- L'elemento -------------------------------------------------------------

t_elemento() {
  local f
  for f in README.md verifica.sh verifica.py progetti.txt \
      esercizio/template-system-prompt-assistente.md _docente/live.sh \
      soluzione/LEGGIMI.md soluzione/v1/system-prompt.md \
      soluzione/v1/strumenti.json soluzione/v1/regole-escalation.md; do
    vero "elemento: ${f}" test -f "${E02}/${f}"
  done
  for f in verifica.sh _docente/live.sh; do
    vero "elemento: ${f} eseguibile" test -x "${E02}/${f}"
  done
  run cat "${E02}/progetti.txt"
  expect "progetti.txt: il progetto dell'assistenza" 0 \
    "progetti/assistenza-clienti"
  vero "il template è la copia di riferimenti/, byte per byte" cmp -s \
    "${E02}/esercizio/template-system-prompt-assistente.md" \
    "${RADICE}/riferimenti/template-system-prompt-assistente.md"
  run python3 -B -I - "${RADICE}/riferimenti/template-system-prompt-assistente.md" <<'PY'
import re, sys
t = open(sys.argv[1], encoding="utf-8").read()
problemi = []
blocco = re.search(r"```text\n(.*?)```", t, re.S)
tag = re.findall(r"^<(role|context|instructions|format|constraints|examples)>$",
                 blocco.group(1) if blocco else "", re.M)
if tag != ["role", "context", "instructions", "format", "constraints",
           "examples"]:
    problemi.append("i tag del modello: %s" % tag)
piano = " ".join(t.split())
DT = "https://platform.claude.com/docs/en/agents-and-tools/tool-use/define-tools"
frasi = [("Provide extremely detailed descriptions. This is by far the most "
          "important factor in tool performance.", DT),
         ("Aim for at least 3–4 sentences for each tool description, more if "
          "the tool is complex.", DT),
         ("Adding explicit escalation criteria with few-shot examples directly "
          "addresses the root cause: unclear decision boundaries.",
          "https://everpath-course-content.s3-accelerate.amazonaws.com/"),
         ("Appropriate escalation triggers: customer requests for a human, "
          "policy exceptions/gaps (not just complex cases), and inability to "
          "make meaningful progress",
          "https://everpath-course-content.s3-accelerate.amazonaws.com/")]
for frase, url in frasi:
    if frase not in piano:
        problemi.append("manca «%s»" % frase[:40])
    if url not in t:
        problemi.append("manca %s" % url)
for titolo in ("## Le definizioni degli strumenti: la lista di controllo",
               "## Il passaggio a un operatore: la lista di controllo"):
    if titolo not in t:
        problemi.append("manca %s" % titolo)
for vietata in ("FACT-", "M7-X", "X-3", "smentit", "oggi", "domani"):
    if vietata in t:
        problemi.append("«%s»" % vietata)
print("; ".join(problemi) or "modello a posto")
PY
  expect "il modello: i tag, le frasi con l'indirizzo, le due liste" 0 \
    "modello a posto"
  run python3 -B -I - "${E02}/soluzione/v1" "${RADICE}" <<'PY'
import json, os, re, sys, importlib.util
v1, radice = sys.argv[1:3]
spec = importlib.util.spec_from_file_location(
    "motore", os.path.join(radice, "progetti/assistenza-clienti/banco/motore.py"))
motore = importlib.util.module_from_spec(spec); spec.loader.exec_module(motore)
problemi = []
dati = json.load(open(os.path.join(v1, "strumenti.json"), encoding="utf-8"))
nomi = [d["name"] for d in dati]
if len(set(nomi)) != len(nomi):
    problemi.append("nomi doppi")
for d in dati:
    if d.get("capacita") not in motore.CAPACITA:
        problemi.append("capacita: %s" % d.get("name"))
    if d.get("input_schema", {}).get("type") != "object":
        problemi.append("schema: %s" % d.get("name"))
    if len(re.findall(r"[.!?](\s|$)", d.get("description", ""))) < 3:
        problemi.append("descrizione corta: %s" % d.get("name"))
for richiesto in ("verifica_identita", "passa_a_operatore", "stato_linea"):
    if richiesto not in nomi:
        problemi.append("manca %s" % richiesto)
op = next(d for d in dati if d["name"] == "passa_a_operatore")
for campo in ("motivo", "riepilogo", "priorita"):
    if campo not in op["input_schema"]["properties"]:
        problemi.append("passa_a_operatore senza %s" % campo)
if {"registra_accredito", "invia_sms", "cerca_cliente"} & set(d["capacita"] for d in dati):
    problemi.append("una capacità che l'assistente non deve avere")
sp = open(os.path.join(v1, "system-prompt.md"), encoding="utf-8").read()
tag = re.findall(r"^<(role|context|instructions|format|constraints|examples)>$", sp, re.M)
if tag != ["role", "context", "instructions", "format", "constraints", "examples"]:
    problemi.append("i tag del prompt: %s" % tag)
if not re.search(r"^<role>\nSei ", sp, re.M):
    problemi.append("il ruolo non comincia con «Sei»")
esempi = len(re.findall(r"^<example>$", sp, re.M))
if not 3 <= esempi <= 5:
    problemi.append("esempi: %d" % esempi)
regole = open(os.path.join(v1, "regole-escalation.md"), encoding="utf-8").read().strip()
if not (regole.startswith("<procedures>\n") and regole.endswith("</procedures>")):
    problemi.append("le regole non stanno nel tag procedures")
print("; ".join(problemi) or "soluzione a posto")
PY
  expect "soluzione/v1: strumenti, prompt nel template, regole nel tag" 0 \
    "soluzione a posto"
}

t_readme() {
  run python3 -B -I - "${E02}" <<'PY'
import os, re, sys, textwrap
item = sys.argv[1]
readme = open(os.path.join(item, "README.md"), encoding="utf-8").read()
problemi = []
sezioni = ("Obiettivo", "Tempo", "Prerequisiti", "Punto di partenza",
           "Passi in Claude Code", "Che cosa osservare", "Verifica",
           "Se qualcosa va storto", "Impronta d'uso sul piano Pro",
           "Per approfondire")
titoli = [r[3:] for r in readme.splitlines() if r.startswith("## ")]
if [next((s for s in sezioni if t.startswith(s)), "") for t in titoli] \
        != list(sezioni):
    problemi.append("le dieci sezioni, in ordine: %s" % titoli)
for titolo in ("## Punto di partenza (tools/prepara_esercizio.sh M7-E02)",
               "## Verifica (tools/verifica.sh M7-E02)"):
    if titolo not in readme:
        problemi.append("il titolo «%s»" % titolo)
EG = ("https://everpath-course-content.s3-accelerate.amazonaws.com/instructor"
      "%2F6nizmqk8tpzpfjvt6qmmav7rh%2Fpublic%2F1783542750%2FClaude+Certified+"
      "Architect+%E2%80%93+Foundations+Exam+Guide.pdf")
frasi = [
    ("Adding explicit escalation criteria with few-shot examples directly "
     "addresses the root cause: unclear decision boundaries.", EG),
    ("Provide extremely detailed descriptions. This is by far the most "
     "important factor in tool performance.",
     "https://platform.claude.com/docs/en/agents-and-tools/tool-use/"
     "define-tools"),
    ("Setting a role in the system prompt focuses Claude's behavior and tone "
     "for your use case. Even a single sentence makes a difference",
     "https://platform.claude.com/docs/en/build-with-claude/"
     "prompt-engineering/claude-prompting-best-practices"),
    ("Implementing programmatic prerequisites that block downstream tool "
     "calls until prerequisite steps have completed (e.g., blocking "
     "process_refund until get_customer has returned a verified customer "
     "ID)", EG),
    ("it’s often better to grade what the agent produced, not the path it "
     "took.", "https://www.anthropic.com/research/"
     "demystifying-evals-for-ai-agents"),
    ("use them to discover cases, then write each case as a snapshot. … "
     "constructing the test state, appending the test user message",
     "https://claude.com/resources/articles/"
     "the-anatomy-of-effective-commerce-agents"),
    ("Claude reads files and proposes a plan but makes no edits until you "
     "approve.", "https://code.claude.com/docs/en/common-workflows"),
    ("In an interactive session, Claude Code shows the workspace trust "
     "dialog when you start it in a folder you haven’t trusted.",
     "https://code.claude.com/docs/en/security"),
    ("Pro, Max, Ultra, Team, Enterprise, and Anthropic API: defaults to Opus "
     "5.5", "https://code.claude.com/docs/en/model-config")]
piano = " ".join(readme.split())
for frase, url in frasi:
    if " ".join(frase.split()) not in piano:
        problemi.append("manca «%s»" % frase[:50])
    if url not in readme:
        problemi.append("manca %s" % url)
righe = readme.split("\n")
def prompt(n):
    a = righe.index("   <!-- prompt %d -->" % n)
    b = righe.index("   <!-- /prompt %d -->" % n)
    return textwrap.dedent("\n".join(righe[a + 1:b])).strip("\n")
ingredienti = ["role", "context", "instructions", "format", "constraints"]
for n in (1, 2):
    p = prompt(n)
    tag = re.findall(r"^<(role|context|instructions|format|constraints|examples)>$", p, re.M)
    if tag != ingredienti:
        problemi.append("prompt %d: i tag %s" % (n, tag))
    if not re.search(r"^<role>\nSei ", p, re.M):
        problemi.append("prompt %d: il ruolo" % n)
    if not re.search(r"^\d+\. Per ultimo ", p, re.M):
        problemi.append("prompt %d: l'ultimo passo non è il controllo" % n)
    if len(p.split()) < 60:
        problemi.append("prompt %d: troppo corto" % n)
p3 = prompt(3)
if "<role>" in p3 or "<instructions>" not in p3:
    problemi.append("il seguito: i tag")
for parola in ("v1/system-prompt.md", "v1/strumenti.json",
               "v1/regole-escalation.md", "risultati/v0", "risultati/v1",
               "prova_assistente.sh", "--permission-mode plan"):
    if parola not in readme:
        problemi.append("manca %s" % parola)
for vietata in ("smentit", "FACT-", "M7-X", "X-3", "X-4", " oggi", "domani",
                "pausa", "pranzo", "/home/", "debolezze"):
    if vietata in readme:
        problemi.append("«%s»" % vietata)
print("; ".join(problemi) or "README a posto")
PY
  expect "README: sezioni, frasi con l'indirizzo, tre prompt, niente di vietato" \
    0 "README a posto"
}

t_prepara() {
  local ws f
  if ! nuovo_ws ws; then
    fail "prepara_esercizio.sh M7-E02: $(tail -n 3 "${TMP}/prepara.log")"
    return
  fi
  pass "prepara_esercizio.sh M7-E02"
  for f in template-system-prompt-assistente.md .claude/settings.json \
      progetti/assistenza-clienti/v0/system-prompt.md \
      progetti/assistenza-clienti/banco/prova.py \
      progetti/assistenza-clienti/banco/casi/caso-05-cliente-furioso.json; do
    vero "spazio di lavoro: ${f}" test -f "${ws}/${f}"
  done
  if [[ ! -e "${ws}/soluzione" && ! -e "${ws}/_docente" \
      && ! -e "${ws}/progetti/assistenza-clienti/_docente" ]]; then
    pass "spazio di lavoro: niente soluzione/ né _docente/"
  else
    fail "spazio di lavoro: soluzione/ o _docente/"
  fi
  run "${RADICE}/tools/verifica.sh" M7-E02 --radice "${ws%/M7-E02}"
  expect "verifica.sh sul punto di partenza: 1" 1 "manca v1/system-prompt.md"
}

# La soluzione di riferimento: una v1 che si carica nel banco.
t_soluzione() {
  run python3 -B -I - "${E02}/soluzione/v1/strumenti.json" "${RADICE}" <<'PY'
import os, sys, importlib.util
from pathlib import Path
strumenti, radice = sys.argv[1:3]
spec = importlib.util.spec_from_file_location(
    "motore", os.path.join(radice, "progetti/assistenza-clienti/banco/motore.py"))
motore = importlib.util.module_from_spec(spec); spec.loader.exec_module(motore)
d = motore.carica_strumenti(Path(strumenti))
print("carica %d strumenti" % len(d))
PY
  expect "soluzione: strumenti.json si carica nel banco" 0 "carica 13 strumenti"
}

# --- La verifica ------------------------------------------------------------

t_verifica() {
  local ws
  nuovo_ws ws || { fail "verifica: prepara_esercizio.sh"; return; }
  modo
  verifica "${ws}"
  expect "verifica: niente v1/ né risultati, 1" 1 "manca v1/system-prompt.md"
  expect "verifica: dice anche risultati/v0" 1 "manca la cartella risultati/v0"
  v1_finta "${ws}"
  prova "${ws}" v0
  expect "le prove della v0 con il finto" 0 "CASO-05"
  verifica "${ws}"
  expect "verifica: la v1 non ha ancora girato, 1" 1 \
    "manca la cartella risultati/v1"
  prova "${ws}" v1
  expect "le prove della v1 con il finto" 0 "CASO-05"
  verifica "${ws}"
  expect "verifica: le due versioni, ogni caso, 0" 0 "${FATTO}"
  expect "verifica: il confronto escalation, come dato" 0 \
    "(dato) escalation v0 4/5  ->  v1 5/5  confermata in questa misura"
  expect "verifica: il totale" 0 \
    "(dato) totale     v0 17/30  ->  v1 30/30  confermata in questa misura"
  expect "verifica: una riga per caso" 0 "(dato) CASO-01"
  expect "verifica: i token della prima richiesta" 0 "7300 token"
  expect "verifica: le asserzioni non soddisfatte, come dati" 0 \
    "CASO-05, v0 non soddisfatta: escalation sì"
  expect_absent "verifica: nessuna asserzione non soddisfatta in v1" \
    ", v1 non soddisfatta:"
  # esito.json che mente: il controllo non lo legge.
  python3 -B -I - "${ws}/risultati/v1/CASO-01/esito.json" <<'PY' || exit 2
import json, sys
e = json.load(open(sys.argv[1], encoding="utf-8"))
e["soddisfatte"] = 0
json.dump(e, open(sys.argv[1], "w", encoding="utf-8"))
PY
  verifica "${ws}"
  expect "verifica: esito.json che mente non cambia niente, 0" 0 \
    "(dato) totale     v0 17/30  ->  v1 30/30  confermata in questa misura"
  rm -rf -- "${ws}/risultati/v1"
  modo FINTO_V1_COME_V0=1
  prova "${ws}" v1
  modo
  verifica "${ws}"
  expect "verifica: v1 come v0, non distinguibile, 0" 0 \
    "(dato) totale     v0 17/30  ->  v1 17/30  non distinguibile"
  expect_absent "verifica: pari non è «smentita»" "smentita"
  rm -rf -- "${ws}/risultati/v1"
  modo FINTO_V1_PEGGIO=1
  prova "${ws}" v1
  modo
  verifica "${ws}"
  expect "verifica: v1 peggio di v0, non confermata, 0" 0 \
    "non confermata in questa misura"
  expect "verifica: anche un confronto che non conferma è un dato, 0" 0 \
    "${FATTO}"
  rm -rf -- "${ws}/risultati/v1"
  prova "${ws}" v1
  rm -rf -- "${ws}/risultati/v1/CASO-03"
  verifica "${ws}"
  expect "verifica: un caso che manca, 1" 1 "risultati/v1/CASO-03: manca"
  prova "${ws}" v1 risultati/altra
  rm -rf -- "${ws}/risultati/v1"
  mv -- "${ws}/risultati/altra" "${ws}/risultati/v1" || exit 2
  verifica "${ws}"
  expect "verifica: di nuovo a posto, 0" 0 "${FATTO}"
  sed -i '/"type": "result"/d' "${ws}/risultati/v1/CASO-02/stream.jsonl"
  verifica "${ws}"
  expect "verifica: uno stream senza il risultato, 1" 1 \
    "risultati/v1/CASO-02: lo stream non finisce con il risultato"
  rm -rf -- "${ws}/risultati/v1"
  modo "FINTO_ERRORE=CASO-04:v1"
  prova "${ws}" v1
  modo
  verifica "${ws}"
  expect "verifica: una chiamata con errore, 1" 1 \
    "risultati/v1/CASO-04: la chiamata è finita con un errore"
  rm -rf -- "${ws}/risultati/v1"
  modo "FINTO_SERVER_KO=CASO-04:v1"
  prova "${ws}" v1
  modo
  expect "prova: il server MCP che non parte, 1" 1 "non è finita"
  expect "prova: il motivo del server" 1 "non si è collegato"
  verifica "${ws}"
  expect "verifica: il server che non parte non è un'esecuzione, 1" 1 \
    "risultati/v1/CASO-04: il server MCP"
  rm -rf -- "${ws}/risultati/v1"
  prova "${ws}" v1
  printf 'non è json\n' >> "${ws}/risultati/v1/CASO-02/registro.jsonl"
  verifica "${ws}"
  expect "verifica: una riga del registro rotta, 2" 2 "non si legge"
  rm -rf -- "${ws}/risultati/v1"
  python3 -B -I - "${ws}/v1/strumenti.json" <<'PY' || exit 2
import json, sys
p = sys.argv[1]; d = json.load(open(p, encoding="utf-8"))
d[0]["capacita"] = "capacita_che_non_esiste"
json.dump(d, open(p, "w", encoding="utf-8"), ensure_ascii=False)
PY
  : > "${TMP}/finto.log"
  prova "${ws}" v1
  expect "prova: una capacita sbagliata in v1, 2" 2 "strumento non collegato"
  if [[ ! -s "${TMP}/finto.log" ]] && [[ ! -d "${ws}/risultati/v1" ]]; then
    pass "prova: una capacita sbagliata in v1, nessuna chiamata"
  else
    fail "prova: capacita sbagliata: chiamate o risultati/v1"
  fi
  cp -- "${E02}/soluzione/v1/strumenti.json" "${ws}/v1/" || exit 2
  prova "${ws}" v1
  rm -f -- "${ws}/v1/regole-escalation.md"
  verifica "${ws}"
  expect "verifica: un file di v1 che manca, 1" 1 "manca v1/regole-escalation.md"
  cp -- "${E02}/soluzione/v1/regole-escalation.md" "${ws}/v1/" || exit 2
  printf '\xff\xfe\n' > "${ws}/risultati/v1/CASO-05/stream.jsonl" || exit 2
  verifica "${ws}"
  expect "verifica: uno stream che non si legge, 2" 2 "non si legge"
  verifica "${TMP}/non-c-e"
  expect "verifica: uno spazio di lavoro che manca, 2" 2 \
    "spazio di lavoro assente"
  run python3 -B -I "${E02}/verifica.py"
  expect "verifica.py: senza argomenti, 2" 2 "Uso:"
  run env PN_HANDSON_ROOT="${TMP}/non-c-e" "${E02}/verifica.sh" "${ws}"
  expect "verifica: il banco del repository che non si trova, 2" 2 "non trovo"
}

# --- live.sh ----------------------------------------------------------------

t_live() {
  local ws
  nuovo_ws ws || { fail "live: prepara_esercizio.sh"; return; }
  modo
  finto "${E02}/_docente/live.sh" "${ws}"
  expect "live: 0" 0 "VERIFICA OK   le due versioni sui casi"
  expect "live: il confronto del banco, sullo schermo" 0 \
    "la seconda versione rispetto alla prima"
  expect "live: i dati della verifica, sullo schermo" 0 "${FATTO}"
  controlla_chiamate "${TMP}/finto.log"
  expect "live: tre prompt del README, dieci prove, le opzioni giuste" 0 \
    "chiamate giuste"
  vero "live: v1/system-prompt.md" test -s "${ws}/v1/system-prompt.md"
  vero "live: v1/strumenti.json" test -s "${ws}/v1/strumenti.json"
  vero "live: il JSON del primo prompt" test -s "${ws}/sessione-live/passo-1.json"
  vero "live: il JSON del seguito" test -s "${ws}/sessione-live/passo-3.json"
  vero "live: risultati/v1/CASO-05/esito.json" \
    test -s "${ws}/risultati/v1/CASO-05/esito.json"
  run "${RADICE}/tools/verifica.sh" M7-E02 --radice "${ws%/M7-E02}"
  expect "live: poi tools/verifica.sh, 0" 0 "VERIFICA OK   M7-E02: fatto."
  run "${E02}/_docente/live.sh"
  expect "live: senza argomenti, 2" 2 "uso:"
}

t_fallita() {
  local ws
  nuovo_ws ws || { fail "fallita: prepara_esercizio.sh"; return; }
  modo "FINTO_KO_SE=definizioni degli strumenti dell'assistente"
  finto "${E02}/_docente/live.sh" "${ws}"
  expect "fallita: il secondo prompt che fallisce, 1" 1 "passo 2"
  vero "fallita: il primo passo aveva scritto il prompt" \
    test -s "${ws}/v1/system-prompt.md"
  nuovo_ws ws || { fail "fallita: prepara_esercizio.sh"; return; }
  modo "FINTO_KO_SE=li rendiamo coerenti"
  finto "${E02}/_docente/live.sh" "${ws}"
  expect "fallita: il seguito che fallisce, 1" 1 "passo 3"
  nuovo_ws ws || { fail "fallita: prepara_esercizio.sh"; return; }
  modo "FINTO_KO_SE=da poco dopo le dieci"
  finto "${E02}/_docente/live.sh" "${ws}"
  expect "fallita: una prova non finita, 1" 1 "la prova del v0 non è finita"
  modo
}

t_precondizioni() {
  local ws s="${E02}/_docente/live.sh"
  nuovo_ws ws || { fail "precondizioni: prepara_esercizio.sh"; return; }
  precondizione "precondizione: una cartella che non è lo spazio" \
    "non è lo spazio di lavoro di M7-E02" "${s}" "${TMP}"
  precondizione "precondizione: nessuno spazio di lavoro" \
    "spazio di lavoro assente" "${s}" ""
  precondizione "precondizione: HANDSON_ENV sbagliato" \
    "è un elemento claude-code-pro" "${s}" "${ws}" "${TMP}/esca:${PATH}" \
    HANDSON_ENV=claude-ai-pro
  precondizione "precondizione: senza uv" "manca lo strumento: uv" \
    "${s}" "${ws}" "${TMP}/senza_uv"
  precondizione "precondizione: senza claude" "manca lo strumento: claude" \
    "${s}" "${ws}" "${TMP}/senza_claude"
  precondizione "precondizione: senza jq" "manca lo strumento: jq" \
    "${s}" "${ws}" "${TMP}/senza_jq"
  mkdir -p "${ws}/v1" || exit 2
  precondizione "precondizione: v1/ c'è già" "non è al punto di partenza" \
    "${s}" "${ws}"
  rm -rf -- "${ws}/v1"
  mkdir -p "${ws}/risultati" || exit 2
  precondizione "precondizione: risultati/ c'è già" \
    "non è al punto di partenza" "${s}" "${ws}"
  rm -rf -- "${ws}/risultati"
  printf 'x\n' > "${ws}/estraneo.txt" || exit 2
  precondizione "precondizione: uno spazio di lavoro cambiato" \
    "non è al punto di partenza" "${s}" "${ws}"
  rm -f -- "${ws}/estraneo.txt"
}

t_shellcheck() {
  local f
  for f in "${E02}/verifica.sh" "${E02}/_docente/live.sh" "${SELF}"; do
    if ( cd "${RADICE}" && shellcheck -x -- "${f}" ) > /dev/null 2>&1; then
      pass "shellcheck ${f#"${RADICE}"/}"
    else
      fail "shellcheck ${f#"${RADICE}"/}"
    fi
  done
}

main() {
  local t
  for t in python3 git jq shellcheck; do
    command -v "${t}" > /dev/null 2>&1 \
      || { echo "test_m7_e02: manca ${t}" >&2; exit 2; }
  done
  [[ -f "${FINTO_PY}" ]] \
    || { echo "test_m7_e02: manca ${FINTO_PY}" >&2; exit 2; }
  handson::init_temp_base
  TMP="$(mktemp -d "${HANDSON_TEMP_BASE}/test_m7_e02.XXXXXX")" || exit 2
  trap 'chmod -R u+rwX "${TMP}" 2> /dev/null; rm -rf "${TMP}"' EXIT
  prepara_finti
  t_elemento
  t_readme
  t_prepara
  t_soluzione
  t_verifica
  t_live
  t_fallita
  t_precondizioni
  t_shellcheck
  OUT="${TUTTO}"
  expect_absent "in nessuna uscita «smentita»" "smentita"
  expect_absent "in nessuna uscita un traceback" "Traceback"
  echo "PASS=${PASS} FAIL=${FAIL}"
  if (( PASS + FAIL != CASES )); then
    echo "test_m7_e02: girati $((PASS + FAIL)) casi, attesi ${CASES}" >&2
    exit 2
  fi
  (( FAIL == 0 )) || exit 1
}

main "$@"
