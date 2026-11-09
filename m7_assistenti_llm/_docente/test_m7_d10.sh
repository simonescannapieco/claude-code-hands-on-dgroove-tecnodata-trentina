#!/bin/bash
#
# test_m7_d10.sh -- le prove di M7-D10 «L'assistente in un progetto di
# claude.ai», per il docente (sta in _docente/, il materiale del docente):
#   - l'elemento: i file; le procedure di conoscenza/, byte per byte quelle del
#     progetto assistenza-clienti; la domanda; le istruzioni del progetto nel
#     template; i due prompt del README uguali ai file della demo; nessun
#     live.sh, perché la prova dal vivo è su claude.ai; il README: le dieci
#     sezioni, le frasi di Anthropic con il loro indirizzo, la pulizia per
#     ultima, nessun nome interno;
#   - controlla_risposte.py su risposte inventate dalla suite, che lo dicono:
#     il codice e il numero, i codici citati e quelli che non sono fra le
#     procedure caricate, il confronto, sempre come dati e come
#     dimostrazione; le risposte che mancano (1) e le precondizioni (2);
#   - verifica.sh e tools/verifica.sh: il punto di partenza (1), le due
#     risposte (0), il controllo dell'elemento e non la copia dello spazio di
#     lavoro;
#   - soluzione/, quando le risposte registrate su claude.ai ci sono; finché
#     non ci sono, quei casi sono SKIP;
#   - shellcheck.
# Nessuna chiamata al modello. Gli spazi di lavoro nascono in una cartella
# temporanea, nella base di handson::init_temp_base (mai dentro ~/.claude).
# CASES è il numero dei casi: se ne girano di più o di meno la suite esce 2.
#
# Uso:    m7_assistenti_llm/_docente/test_m7_d10.sh
# Uscita: 0 = tutti i casi passano · 1 = almeno un caso fallito · 2 =
#         precondizione (manca python3, git o shellcheck), o un numero di casi
#         diverso da CASES
set -uo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly MOD="${SELF%/_docente/*}"
readonly RADICE="${MOD%/*}"
D10="${MOD}/s6_conoscenza_e_valutazione/m7_6_la_conoscenza"
D10+="/M7-D10_progetto_claude_ai"
readonly D10
readonly KB="${RADICE}/progetti/assistenza-clienti/kb"
# shellcheck source=../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"
readonly CASES=103
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
  "${RADICE}/tools/prepara_esercizio.sh" M7-D10 --radice "${__r}" \
    > "${TMP}/prepara.log" 2>&1 || return 1
  printf -v "$1" '%s' "${__r}/M7-D10"
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
  python3 -B -I - "${D10}/README.md" "$1" <<'PY'
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
verifica() { run env PN_HANDSON_ROOT="${RADICE}" "${D10}/verifica.sh" "$@"; }

t_elemento() {
  local f
  for f in README.md verifica.sh demo/domanda.txt demo/istruzioni-progetto.txt \
      demo/controlla_risposte.py demo/risposte/.gitkeep soluzione/LEGGIMI.md; do
    vero "c'è ${f}" test -f "${D10}/${f}"
  done
  vero "verifica.sh è eseguibile" test -x "${D10}/verifica.sh"
  vero "nessun live.sh: la prova dal vivo è su claude.ai" \
    test ! -e "${D10}/_docente/live.sh"
  for f in kb-08-fatture-e-pagamenti.md kb-10-trasloco.md \
      kb-11-guasti-collettivi-e-manutenzioni.md kb-12-orari-e-canali.md; do
    vero "conoscenza/${f}: la copia del progetto, byte per byte" \
      cmp -s "${D10}/demo/conoscenza/${f}" "${KB}/${f}"
  done
  run blocco 1
  if [[ "${OUT}" == "$(cat "${D10}/demo/domanda.txt")" ]]; then
    pass "il prompt 1 del README è domanda.txt"
  else
    fail "il prompt 1 del README non è domanda.txt: «${OUT}»"
  fi
  run blocco 2
  if [[ "${OUT}" == "$(cat "${D10}/demo/istruzioni-progetto.txt")" ]]; then
    pass "il prompt 2 del README è istruzioni-progetto.txt"
  else
    fail "il prompt 2 del README non è istruzioni-progetto.txt: «${OUT}»"
  fi
  run python3 -B -I - "${D10}/demo/domanda.txt" \
    "${D10}/demo/istruzioni-progetto.txt" <<'PY'
import re, sys
domanda = open(sys.argv[1], encoding="utf-8").read()
assert domanda.count("\n") == 1 and "<" not in domanda, domanda
istruzioni = open(sys.argv[2], encoding="utf-8").read()
righe = [r for r in istruzioni.split("\n") if r.strip()]
tag = [r for r in righe if re.fullmatch(r"</?[a-z]+>", r)]
nomi = [t for t in tag if not t.startswith("</")]
assert nomi == ["<role>", "<context>", "<instructions>", "<format>",
                "<constraints>"], nomi
ruolo = re.search(r"<role>\n(.*?)\n</role>", istruzioni, re.S).group(1)
assert ruolo.startswith("Sei ") and "\n" not in ruolo, ruolo
assert len(re.sub(r"</?\w+>", "", istruzioni).split()) >= 60
assert "1. " in istruzioni and "3. " in istruzioni
print("i prompt nella loro forma")
PY
  expect "la domanda in una riga, le istruzioni nel template" 0 \
    'i prompt nella loro forma'
  run python3 -B -I - "${D10}/demo/conoscenza/kb-12-orari-e-canali.md" <<'PY'
import re, sys
t = open(sys.argv[1], encoding="utf-8").read()
print("il numero" if "+39 000 000 2000" in t else "manca")
PY
  expect "la procedura KB-12 ha il numero dell'Assistenza Prioritaria" 0 \
    'il numero'
  run command find "${D10}/demo" -iname 'CLAUDE*.md' -o -iname 'AGENTS.md'
  if [[ -z "${OUT}" ]]; then
    pass "nessun file di istruzioni di Claude Code nella demo"
  else
    fail "un file di istruzioni nella demo: ${OUT}"
  fi
}

t_readme() {
  local testo frase parola
  testo="$(tr -s '[:space:]' ' ' < "${D10}/README.md")"
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
In addition, you can define project instructions for each project to further tailor Claude's responses.
https://support.claude.com/en/articles/9517075-what-are-projects
When your project knowledge approaches the context window limit, Claude will automatically enable RAG mode to expand your project's capacity by up to 10x
https://support.claude.com/en/articles/11473015-retrieval-augmented-generation-rag-for-projects
Use clear, descriptive filenames … Well-named files help Claude understand and retrieve the right information more effectively.
Projects are available to all users, including those with free Claude accounts.
Memory is on by default for Free, Pro, Max, and Ultra plans on the web, Claude Desktop, and Claude Mobile.
If you're on a Pro, Max, or Ultra plan and your message box still shows "Chat" and "Cowork" options, you don't have it yet.
Other existing projects in chat and Cowork stay on the current version for now, and we’ll move them as the rollout expands.
The model menu next to the send button controls three settings: which Claude model … how much effort … and whether it uses thinking.
https://support.claude.com/en/articles/8664678-change-the-model-effort-and-thinking-settings
https://academy.claude.com/courses/claude-101/introduction-to-projects
tools/prepara_esercizio.sh M7-D10
tools/verifica.sh M7-D10
tools/reset_esercizio.sh M7-D10
cat > risposte/chat.txt
cat > risposte/progetto.txt
«+ New Project»
«Set project instructions»
«VERIFICA OK M7-D10: fatto.»
FRASI
  for parola in 'FACT-' 'M7-X' 'M3-X' 'X-37' 'X-38' 'smentit' 'oggi' \
      '/home/'; do
    if [[ "${testo}" == *"${parola}"* ]]; then
      fail "README: «${parola}» non ci sta"
    else
      pass "README: niente «${parola}»"
    fi
  done
  run python3 -B -I - "${D10}/README.md" <<'PY'
import re, sys
testo = open(sys.argv[1], encoding="utf-8").read()
sezione = testo.split("## Passi")[1].split("\n## ")[0]
numeri = re.findall(r"(?m)^(\d+)\. \*\*([^*]+)\*\*", sezione)
print("ultimo: %s" % numeri[-1][1] if numeri else "nessun passo")
PY
  expect "README: la pulizia è l'ultimo passo" 0 'ultimo: La pulizia'
  run "${RADICE}/tools/check_handson.sh"
  if grep -q 'M7-D10' <<< "${OUT}"; then
    fail "check_handson: una segnalazione su M7-D10: $(grep 'M7-D10' \
      <<< "${OUT}")"
  else
    pass "check_handson: nessuna segnalazione su M7-D10"
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
    'Risposta inventata: non conosco quel numero, forse KB-99.' \
    'Risposta inventata: il numero è +39 000 000 2000, vedi KB-12.'
  controlla "${w}"
  expect "le due risposte: 0" 0 'Dimostrazione: il controllo legge'
  expect "la procedura: il codice e il numero" 0 \
    'KB-12, «Orari e canali dell'"'"'assistenza»; il numero dell'"'"'Assistenza Prioritaria: +39 000 000 2000'
  expect "le procedure caricate" 0 'procedure caricate: KB-08, KB-10, KB-11, KB-12'
  expect "nella chat, codice e numero no" 0 \
    "il codice KB-12: no; il numero dell'Assistenza Prioritaria: no"
  expect "un codice che non è fra le caricate" 0 \
    'KB-99, fra le procedure caricate: no'
  expect "nel progetto, codice e numero sì" 0 \
    "il codice KB-12: sì; il numero dell'Assistenza Prioritaria: sì"
  expect "il codice citato, fra le caricate" 0 \
    'KB-12, fra le procedure caricate: sì'
  expect "il confronto, come dato" 0 \
    "(dato) il codice e il numero insieme: la chat, senza progetto: no; la chat nel progetto con le procedure: sì"
  assente "nessun verdetto" 'confermata'
  assente "nessuna risposta mancante" 'Non ancora'
  risposte "${w}" 'Risposta inventata: non ho codici da citare.' \
    'Risposta inventata: al numero +390000002000 (kb-12).'
  controlla "${w}"
  expect "il numero senza spazi, il codice in minuscolo" 0 \
    "il codice KB-12: sì; il numero dell'Assistenza Prioritaria: sì"
  expect "nessun codice citato" 0 'i codici citati: nessuno'
  risposte "${w}" 'Risposta inventata: 2000.' \
    'Risposta inventata: 000.000.2000, KB-08.'
  controlla "${w}"
  expect "un codice diverso: il codice KB-12 no" 0 \
    "il codice KB-12: no; il numero dell'Assistenza Prioritaria: sì"
  expect "il codice e il numero non insieme" 0 \
    "(dato) il codice e il numero insieme: la chat, senza progetto: no; la chat nel progetto con le procedure: no"
  printf '\xff\xfe\n' > "${w}/risposte/chat.txt"
  controlla "${w}"
  expect "una risposta non UTF-8: 2" 2 'UTF-8'
  controlla "${w}" --tutto
  expect "un'opzione sconosciuta: 2" 2 'Uso:'
  run python3 -B -I "${w}/controlla_risposte.py" "${w}" "${w}"
  expect "due spazi di lavoro: 2" 2 'Uso:'
  run python3 -B -I "${w}/controlla_risposte.py" "${TMP}/non-c-e"
  expect "uno spazio di lavoro che non c'è: 2" 2 'spazio di lavoro assente'
  sed -i 's/^- Assistenza Prioritaria.*/- Assistenza: x/' \
    "${w}/conoscenza/kb-12-orari-e-canali.md"
  controlla "${w}"
  expect "una procedura senza il numero: 2" 2 \
    "il numero dell'Assistenza Prioritaria"
  rm -f -- "${w}/conoscenza/kb-12-orari-e-canali.md"
  controlla "${w}"
  expect "senza la procedura: 2" 2 'manca conoscenza/kb-12-orari-e-canali.md'
  assente "mai un traceback" 'Traceback'
}

t_verifica() {
  local w
  verifica "${TMP}/non-c-e"
  expect "verifica: spazio di lavoro assente (2)" 2 'spazio di lavoro'
  nuovo_ws w || { fail "verifica: lo spazio di lavoro non nasce"; return 0; }
  vero "prepara: le procedure" test -f "${w}/conoscenza/kb-10-trasloco.md"
  vero "prepara: la cartella delle risposte, vuota" \
    test -d "${w}/risposte" -a ! -e "${w}/risposte/chat.txt"
  vero "prepara: niente soluzione né _docente" \
    test ! -e "${w}/soluzione" -a ! -e "${w}/_docente"
  verifica "${w}"
  expect "verifica: sul punto di partenza (1)" 1 'manca almeno una risposta'
  assente "verifica: sul punto di partenza nessun «Fatto»" "${FATTO}"
  run env PATH="${TMP}/senza_python" "${D10}/verifica.sh" "${w}"
  expect "verifica: senza python3 (2)" 2 'python3'
  printf 'import sys\nsys.exit(0)\n' > "${w}/controlla_risposte.py"
  verifica "${w}"
  expect "verifica: il controllo dell'elemento, non la copia (1)" 1 \
    'manca almeno una risposta'
  risposte "${w}" 'Risposta inventata: non lo so.' \
    'Risposta inventata: +39 000 000 2000, KB-12.'
  verifica "${w}"
  expect "verifica: le due risposte (0)" 0 "${FATTO}"
  run env PN_HANDSON_ROOT="${RADICE}" "${RADICE}/tools/verifica.sh" M7-D10 \
    --radice "${w%/M7-D10}"
  expect "tools/verifica.sh: lo stesso esito (0)" 0 'VERIFICA OK   M7-D10'
}

# La soluzione sono le due risposte registrate su claude.ai: finché non ci
# sono, i casi che le usano sono SKIP (lo stesso numero di casi).
t_soluzione() {
  local w sol="${D10}/soluzione/risposte"
  vero "LEGGIMI: la registrazione" \
    grep -qi 'registrazione' "${D10}/soluzione/LEGGIMI.md"
  vero "LEGGIMI: nessuna risposta scritta a mano" \
    grep -qF 'Nessuna risposta qui si scrive a mano' \
    "${D10}/soluzione/LEGGIMI.md"
  if [[ ! -f "${sol}/chat.txt" || ! -f "${sol}/progetto.txt" ]]; then
    skip "soluzione/risposte/: la registrazione su claude.ai non c'è ancora"
    skip "il README non dice più «Da registrare»"
    skip "run_all: partenza e soluzione"
    skip "run_all --live: SKIP, nessun live.sh"
    return 0
  fi
  nuovo_ws w || { fail "lo spazio di lavoro"; return 0; }
  cp -R "${D10}/soluzione/." "${w}/" || exit 2
  verifica "${w}"
  expect "con la soluzione: 0" 0 "${FATTO}"
  if grep -qF 'Da registrare' "${D10}/README.md"; then
    fail "il README dice ancora «Da registrare»"
  else
    pass "il README non dice più «Da registrare»"
  fi
  run "${RADICE}/tools/run_all.sh" M7-D10
  expect "run_all: partenza e soluzione" 0 '1 ok, 0 KO'
  run "${RADICE}/tools/run_all.sh" --live M7-D10
  expect "run_all --live: SKIP, nessun live.sh" 0 \
    'live SKIP: nessun _docente/live.sh'
}

t_shellcheck() {
  local f
  for f in "${SELF}" "${D10}/verifica.sh"; do
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
  for t in python3 git shellcheck; do
    command -v "${t}" > /dev/null 2>&1 \
      || { echo "test_m7_d10: manca ${t}" >&2; exit 2; }
  done
  handson::init_temp_base
  TMP="$(mktemp -d "${HANDSON_TEMP_BASE}/test_m7_d10.XXXXXX")" || exit 2
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
    echo "test_m7_d10: girati $((PASS + FAIL + SKIP)) casi, attesi" \
      "${CASES}" >&2
    exit 2
  fi
  (( FAIL == 0 )) || exit 1
}

main "$@"
