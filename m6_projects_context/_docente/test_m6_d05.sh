#!/bin/bash
#
# test_m6_d05.sh -- le prove di M6-D05 «La stessa domanda, in un progetto di
# claude.ai», per il docente (sta in _docente/, il materiale del docente):
#   - l'elemento: i file; la carta dei servizi, la stessa di M6-D01 byte per
#     byte, e la stessa domanda; i due prompt del README uguali ai file della
#     demo, la domanda in una riga e le istruzioni con una frase per tag;
#     nessun live.sh, perché la prova dal vivo è su claude.ai; il README: le
#     dieci sezioni, le frasi di Anthropic con il loro indirizzo, la pulizia per
#     ultima, nessun nome interno;
#   - controlla_risposte.py su risposte inventate dalla suite, che lo dicono:
#     le cifre dell'art. 4 in cifre e in lettere, gli articoli citati e quelli
#     che la carta non ha, il confronto, sempre come dati e come
#     dimostrazione; le risposte che mancano (1) e le precondizioni (2);
#   - verifica.sh e tools/verifica.sh: il punto di partenza (1), le due
#     risposte (0), il controllo dell'elemento e non la copia dello spazio di
#     lavoro;
#   - soluzione/ e tools/run_all.sh, quando le risposte registrate su
#     claude.ai ci sono; finché non ci sono, quei casi sono SKIP;
#   - shellcheck.
# Nessuna chiamata al modello. Gli spazi di lavoro nascono in una cartella
# temporanea, nella base di handson::init_temp_base (mai dentro ~/.claude).
# CASES è il numero dei casi: se ne girano di più o di meno la suite esce 2.
#
# Uso:    m6_projects_context/_docente/test_m6_d05.sh
# Uscita: 0 = tutti i casi passano · 1 = almeno un caso fallito · 2 =
#         precondizione (manca python3, git, shellcheck o sha256sum), o un
#         numero di casi diverso da CASES
set -uo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly MOD="${SELF%/_docente/*}"
readonly RADICE="${MOD%/*}"
readonly SEZ="${MOD}/s5_projects_context"
readonly D05="${SEZ}/m6_7_projects_claude_ai/M6-D05_progetto_claude_ai"
readonly D01="${SEZ}/m6_2_il_contesto_e_tutto/M6-D01_documento_mai_letto"
# shellcheck source=../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"
readonly CASES=100
CARTA_SHA='9976b58d5450e43d6d61d572f298778fa6d7131999da47ab63f64006da4eae4a'
readonly CARTA_SHA
readonly FATTO='Fatto: le due risposte sono salvate.'
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
    fail "$1 (rc=${RC}, attesa $2, parola «$3»): ${OUT:0:700}"
  fi
}

# Nessun falso positivo: la parola NON c'è (RU-01.T5).
# Arguments: $1 il nome, $2 la parola.
assente() {
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

# Uno spazio di lavoro nuovo. Arguments: $1 la variabile da assegnare.
# Returns: 0; 1 se prepara_esercizio.sh non riesce.
nuovo_ws() {
  local __r
  __r="$(mktemp -d "${TMP}/radice.XXXXXX")" || exit 2
  "${RADICE}/tools/prepara_esercizio.sh" M6-D05 --radice "${__r}" \
    > "${TMP}/prepara.log" 2>&1 || return 1
  printf -v "$1" '%s' "${__r}/M6-D05"
}

# Le due risposte, inventate per la prova: $2 nella chat, $3 nel progetto.
# Arguments: $1 lo spazio di lavoro.
risposte() {
  printf '%s\n' "$2" > "$1/risposte/chat.txt" || exit 2
  printf '%s\n' "$3" > "$1/risposte/progetto.txt" || exit 2
}

# Il blocco del README fra «<!-- prompt $1 -->» e «<!-- /prompt $1 -->», senza
# il rientro e le righe vuote in testa e in coda.
blocco() {
  python3 -B -I - "${D05}/README.md" "$1" <<'PY'
import re, sys
testo = open(sys.argv[1], encoding="utf-8").read()
m = re.search(r"<!-- prompt %s -->\n(.*?)\n\s*<!-- /prompt %s -->"
              % (sys.argv[2], sys.argv[2]), testo, re.S)
righe = m.group(1).strip("\n").split("\n") if m else []
print("\n".join(r[7:] if r.startswith("       ") else r.strip()
                for r in righe).strip("\n"))
PY
}

# controlla_risposte.py della copia dello spazio di lavoro; RC e OUT come run.
controlla() { run python3 -B -I "$1/controlla_risposte.py" "${@:2}" "$1"; }

# verifica.sh dell'elemento; RC e OUT come run.
verifica() { run env PN_HANDSON_ROOT="${RADICE}" "${D05}/verifica.sh" "$@"; }

t_elemento() {
  local f
  for f in README.md verifica.sh demo/carta-servizi.md demo/domanda.txt \
      demo/istruzioni-progetto.txt demo/controlla_risposte.py \
      demo/risposte/.gitkeep soluzione/LEGGIMI.md; do
    vero "c'è ${f}" test -f "${D05}/${f}"
  done
  vero "verifica.sh è eseguibile" test -x "${D05}/verifica.sh"
  vero "nessun live.sh: la prova dal vivo è su claude.ai" \
    test ! -e "${D05}/_docente/live.sh"
  run sha256sum "${D05}/demo/carta-servizi.md"
  expect "la carta, byte per byte quella del modulo" 0 "${CARTA_SHA}"
  if [[ -f "${D01}/demo/carta-servizi.md" ]]; then
    vero "la carta è quella di M6-D01" \
      cmp -s "${D05}/demo/carta-servizi.md" "${D01}/demo/carta-servizi.md"
  else
    skip "M6-D01 non ha ancora la sua carta"
  fi
  if [[ -f "${D01}/demo/domanda.txt" ]]; then
    vero "la domanda è quella di M6-D01" \
      cmp -s "${D05}/demo/domanda.txt" "${D01}/demo/domanda.txt"
  else
    skip "M6-D01 non ha ancora la sua domanda"
  fi
  run blocco 1
  if [[ "${OUT}" == "$(cat "${D05}/demo/domanda.txt")" ]]; then
    pass "il prompt 1 del README è domanda.txt"
  else
    fail "il prompt 1 del README non è domanda.txt: «${OUT}»"
  fi
  run blocco 2
  if [[ "${OUT}" == "$(cat "${D05}/demo/istruzioni-progetto.txt")" ]]; then
    pass "il prompt 2 del README è istruzioni-progetto.txt"
  else
    fail "il prompt 2 del README non è istruzioni-progetto.txt: «${OUT}»"
  fi
  run python3 -B -I - "${D05}/demo/domanda.txt" \
    "${D05}/demo/istruzioni-progetto.txt" <<'PY'
import re, sys
domanda = open(sys.argv[1], encoding="utf-8").read()
assert domanda.count("\n") == 1 and "<" not in domanda, domanda
istruzioni = open(sys.argv[2], encoding="utf-8").read()
righe = [r for r in istruzioni.split("\n") if r.strip()]
tag = [r for r in righe if re.fullmatch(r"</?[a-z]+>", r)]
assert tag == ["<instructions>", "</instructions>", "<format>", "</format>"], tag
frasi = [r for r in righe if r not in tag]
assert len(frasi) == 2 and all(f.endswith(".") for f in frasi), frasi
assert len(istruzioni.split()) < 60, len(istruzioni.split())
print("i prompt nella loro forma")
PY
  expect "la domanda in una riga, le istruzioni una frase per tag" 0 \
    'i prompt nella loro forma'
  run command find "${D05}/demo" -iname 'CLAUDE*.md' -o -iname 'AGENTS.md'
  if [[ -z "${OUT}" ]]; then
    pass "nessun file di istruzioni di Claude Code nella demo"
  else
    fail "un file di istruzioni nella demo: ${OUT}"
  fi
}

t_readme() {
  local testo frase parola
  testo="$(tr -s '[:space:]' ' ' < "${D05}/README.md")"
  while IFS= read -r frase; do
    if [[ "${testo}" == *"${frase}"* ]]; then
      pass "README: «${frase:0:48}…»"
    else
      fail "README: manca «${frase}»"
    fi
  done <<'FRASI'
Anything you upload to this space will be used across all of your chats within that project.
https://support.claude.com/en/articles/9519177-how-can-i-create-and-manage-projects
Add instructions for how you'd like Claude to behave and respond … Claude will use these instructions for all the chats within the project.
Give your project a name and description (note that Claude will not have access to these details).
Note: Context is not shared across chats within a project unless the information is added into the project knowledge base.
You can turn memory off for a single chat … by turning off "Memory" in the "+" menu before you send your first message.
A project chat started this way doesn't use or add to the project's memory.
You need to turn memory off before you send the first message. Once the chat starts, the setting can't be changed.
https://support.claude.com/en/articles/11817273-use-claude-s-chat-search-and-memory-to-build-on-previous-context
After you send your first message, a crossed-out memory icon appears next to the chat title.
If you have the new Claude experience, there's no web search toggle. Claude searches the web when it helps.
https://support.claude.com/en/articles/10684626-enable-and-use-web-search
When your project knowledge approaches context limits, Claude seamlessly enables RAG mode to expand capacity by up to 10x while maintaining response quality.
https://support.claude.com/en/articles/9517075-what-are-projects
https://support.claude.com/en/articles/11473015-retrieval-augmented-generation-rag-for-projects
Projects are available to all users, including those with free Claude accounts.
Memory is on by default for Free, Pro, Max, and Ultra plans on the web, Claude Desktop, and Claude Mobile.
If you're on a Pro, Max, or Ultra plan and your message box still shows "Chat" and "Cowork" options, you don't have it yet.
Other existing projects in chat and Cowork stay on the current version for now, and we’ll move them as the rollout expands.
The model menu next to the send button controls three settings
https://support.claude.com/en/articles/8241126-upload-files-to-claude
https://academy.claude.com/courses/claude-101/introduction-to-projects
tools/prepara_esercizio.sh M6-D05
tools/verifica.sh M6-D05
tools/reset_esercizio.sh M6-D05
cat > risposte/chat.txt
cat > risposte/progetto.txt
«+ New Project»
«Set project instructions»
«VERIFICA OK M6-D05: fatto.»
FRASI
  for parola in 'FACT-' 'M6-X' 'M3-X' 'X-37' 'X-38' 'smentit' 'oggi' \
      '/home/'; do
    if [[ "${testo}" == *"${parola}"* ]]; then
      fail "README: «${parola}» non ci sta"
    else
      pass "README: niente «${parola}»"
    fi
  done
  run python3 -B -I - "${D05}/README.md" <<'PY'
import re, sys
testo = open(sys.argv[1], encoding="utf-8").read()
sezione = testo.split("## Passi")[1].split("\n## ")[0]
numeri = re.findall(r"(?m)^(\d+)\. \*\*([^*]+)\*\*", sezione)
print("ultimo: %s" % numeri[-1][1] if numeri else "nessun passo")
PY
  expect "README: la pulizia è l'ultimo passo" 0 'ultimo: La pulizia'
  run "${RADICE}/tools/check_handson.sh"
  if grep -q 'M6-D05\|m6_7_projects_claude_ai' <<< "${OUT}"; then
    fail "check_handson: una segnalazione su M6-D05: $(grep 'M6-D05\|m6_7' \
      <<< "${OUT}")"
  else
    pass "check_handson: nessuna segnalazione su M6-D05"
  fi
}

t_controlla() {
  local w
  nuovo_ws w || { fail "lo spazio di lavoro"; return 0; }
  controlla "${w}"
  expect "nessuna risposta: 1" 1 'manca almeno una risposta'
  expect "e dice quale" 1 'risposte/chat.txt manca'
  risposte "${w}" 'Risposta inventata: non lo so.' ''
  : > "${w}/risposte/progetto.txt"
  controlla "${w}"
  expect "una risposta vuota: 1" 1 'risposte/progetto.txt è vuoto'
  risposte "${w}" \
    'Risposta inventata: di solito entro 15 giorni, o 2,5 (art. 12).' \
    'Risposta inventata: secondo l'"'"'**Art. 4**, entro 5 giorni lavorativi da maggio a ottobre e 9 da novembre ad aprile.'
  controlla "${w}"
  expect "le due risposte: 0" 0 'Dimostrazione: il controllo legge'
  expect "la carta: l'art. 4 e le sue cifre" 0 \
    "l'art. 4, «Interventi sugli apparati in quota», dice 5 e 9"
  expect "15 e 2,5 non sono 5" 0 "le cifre dell'art. 4: 5: no; 9: no"
  expect "un articolo che la carta non ha" 0 'art. 12, nella carta: no'
  expect "le cifre in cifre" 0 "le cifre dell'art. 4: 5: sì; 9: sì"
  expect "l'articolo citato, con il titolo" 0 \
    'art. 4, nella carta: «Interventi sugli apparati in quota»'
  expect "il confronto, come dato" 0 \
    "(dato) tutte le cifre dell'art. 4: la chat, senza progetto: no; la chat nel progetto con la carta: sì"
  assente "nessun verdetto" 'confermata'
  assente "nessuna risposta mancante" 'Non ancora'
  risposte "${w}" 'Risposta inventata: non ho articoli da citare.' \
    'Risposta inventata: articolo 4, entro cinque giorni lavorativi o nove.'
  controlla "${w}"
  expect "le cifre in lettere" 0 "le cifre dell'art. 4: 5: sì; 9: sì; «giorni lavorativi»: sì"
  expect "«articolo 4»" 0 'art. 4, nella carta:'
  expect "nessun articolo citato" 0 'gli articoli citati: nessuno'
  risposte "${w}" 'Risposta inventata: art.4, ５ giorni.' 'Risposta inventata.'
  controlla "${w}"
  expect "«art.4» e le cifre larghe" 0 "le cifre dell'art. 4: 5: sì; 9: no; «giorni lavorativi»: no"
  printf '\xff\xfe\n' > "${w}/risposte/chat.txt"
  controlla "${w}"
  expect "una risposta non UTF-8: 2" 2 'UTF-8'
  controlla "${w}" --tutto
  expect "un'opzione sconosciuta: 2" 2 'Uso:'
  run python3 -B -I "${w}/controlla_risposte.py" "${w}" "${w}"
  expect "due spazi di lavoro: 2" 2 'Uso:'
  run python3 -B -I "${w}/controlla_risposte.py" "${TMP}/non-c-e"
  expect "uno spazio di lavoro che non c'è: 2" 2 'spazio di lavoro assente'
  sed -i 's/^## Art\. 4 .*$/## Articolo quarto/' "${w}/carta-servizi.md"
  controlla "${w}"
  expect "una carta senza l'art. 4: 2" 2 "non ha l'art. 4"
  rm -f -- "${w}/carta-servizi.md"
  controlla "${w}"
  expect "senza la carta: 2" 2 'manca carta-servizi.md'
  assente "mai un traceback" 'Traceback'
}

t_verifica() {
  local w
  verifica "${TMP}/non-c-e"
  expect "verifica: spazio di lavoro assente (2)" 2 'spazio di lavoro'
  nuovo_ws w || { fail "verifica: lo spazio di lavoro non nasce"; return 0; }
  vero "prepara: la carta" test -f "${w}/carta-servizi.md"
  vero "prepara: la cartella delle risposte, vuota" \
    test -d "${w}/risposte" -a ! -e "${w}/risposte/chat.txt"
  vero "prepara: niente soluzione né _docente" \
    test ! -e "${w}/soluzione" -a ! -e "${w}/_docente"
  verifica "${w}"
  expect "verifica: sul punto di partenza (1)" 1 'manca almeno una risposta'
  assente "verifica: sul punto di partenza nessun «Fatto»" "${FATTO}"
  run env PATH="${TMP}/senza_python" "${D05}/verifica.sh" "${w}"
  expect "verifica: senza python3 (2)" 2 'python3'
  printf 'import sys\nsys.exit(0)\n' > "${w}/controlla_risposte.py"
  verifica "${w}"
  expect "verifica: il controllo dell'elemento, non la copia (1)" 1 \
    'manca almeno una risposta'
  risposte "${w}" 'Risposta inventata: non lo so.' \
    'Risposta inventata: 5 e 9 giorni lavorativi, art. 4.'
  verifica "${w}"
  expect "verifica: le due risposte (0)" 0 "${FATTO}"
  run env PN_HANDSON_ROOT="${RADICE}" "${RADICE}/tools/verifica.sh" M6-D05 \
    --radice "${w%/M6-D05}"
  expect "tools/verifica.sh: lo stesso esito (0)" 0 'VERIFICA OK   M6-D05'
}

# La soluzione sono le due risposte registrate su claude.ai: finché non ci
# sono, i casi che le usano sono SKIP (lo stesso numero di casi).
t_soluzione() {
  local w sol="${D05}/soluzione/risposte"
  vero "LEGGIMI: la registrazione" \
    grep -qi 'registrazione' "${D05}/soluzione/LEGGIMI.md"
  vero "LEGGIMI: nessuna risposta scritta a mano" \
    grep -qF 'Nessuna risposta qui si scrive a mano' \
    "${D05}/soluzione/LEGGIMI.md"
  if [[ ! -f "${sol}/chat.txt" || ! -f "${sol}/progetto.txt" ]]; then
    skip "soluzione/risposte/: la registrazione su claude.ai non c'è ancora"
    skip "il README cita il confronto della registrazione"
    skip "il README non dice più «Da registrare»"
    skip "run_all: partenza e soluzione"
    skip "run_all --live: SKIP, nessun live.sh"
    return 0
  fi
  nuovo_ws w || { fail "lo spazio di lavoro"; return 0; }
  cp -R "${D05}/soluzione/." "${w}/" || exit 2
  verifica "${w}"
  expect "con la soluzione: 0" 0 "${FATTO}"
  printf '%s\n' "${OUT}" > "${TMP}/uscita.txt"
  run python3 -B -I - "${D05}/README.md" "${TMP}/uscita.txt" <<'PY'
import sys
readme = " ".join(open(sys.argv[1], encoding="utf-8").read().split())
righe = [" ".join(r.split()) for r in open(sys.argv[2], encoding="utf-8")
         if r.startswith("(dato) tutte le cifre")]
print("in ordine" if righe and all(r in readme for r in righe)
      else "mancano: %r" % righe)
PY
  expect "il README cita il confronto della registrazione" 0 'in ordine'
  if grep -qF 'Da registrare' "${D05}/README.md"; then
    fail "il README dice ancora «Da registrare»"
  else
    pass "il README non dice più «Da registrare»"
  fi
  run "${RADICE}/tools/run_all.sh" M6-D05
  expect "run_all: partenza e soluzione" 0 '1 ok, 0 KO'
  run "${RADICE}/tools/run_all.sh" --live M6-D05
  expect "run_all --live: SKIP, nessun live.sh" 0 \
    'live SKIP: nessun _docente/live.sh'
}

t_shellcheck() {
  local f
  for f in "${SELF}" "${D05}/verifica.sh"; do
    run shellcheck -x "${f}"
    if (( RC == 0 )); then
      pass "shellcheck: ${f##*/}"
    else
      fail "shellcheck: ${f##*/}: ${OUT:0:800}"
    fi
  done
}

main() {
  local t
  for t in python3 git shellcheck sha256sum; do
    command -v "${t}" > /dev/null 2>&1 \
      || { echo "test_m6_d05: manca ${t}" >&2; exit 2; }
  done
  handson::init_temp_base
  TMP="$(mktemp -d "${HANDSON_TEMP_BASE}/test_m6_d05.XXXXXX")" || exit 2
  trap 'chmod -R u+rwX "${TMP}" 2>/dev/null; rm -rf "${TMP}"' EXIT
  mkdir -p "${TMP}/senza_python" || exit 2
  ln -s "$(command -v readlink)" "${TMP}/senza_python/readlink" || exit 2
  t_elemento
  t_readme
  t_controlla
  t_verifica
  t_soluzione
  t_shellcheck
  OUT="${TUTTO}"
  assente "in nessuna uscita «smentita»" "smentita"
  echo "PASS=${PASS} FAIL=${FAIL} SKIP=${SKIP}"
  if (( PASS + FAIL + SKIP != CASES )); then
    echo "test_m6_d05: girati $((PASS + FAIL + SKIP)) casi, attesi" \
      "${CASES}" >&2
    exit 2
  fi
  (( FAIL == 0 )) || exit 1
}

main "$@"
