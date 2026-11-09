#!/bin/bash
#
# test_m7_d01.sh -- le prove di M7-D01 «Cambia solo il system prompt», per il
# docente (sta in _docente/, il materiale del docente):
#   - l'elemento: i file, i system prompt e i messaggi, il README con le sue
#     dieci sezioni, le frasi di Anthropic con il loro indirizzo, niente
#     identificativi interni, «smentita» o riferimenti alla giornata;
#   - prepara_esercizio.sh e verifica.sh sul punto di partenza (1);
#   - controlla_sistema.py su stream del claude finto: le esecuzioni, il
#     confronto (un esito non cambia l'uscita), le garanzie della parte 2 (1
#     se non valgono), le esecuzioni che mancano o non finiscono (1), gli
#     stream che non si leggono e gli usi sbagliati (2), mai un traceback;
#   - verifica.sh: il controllo dell'elemento, mai quello dello spazio di
#     lavoro; risposte/ che manca o vuota (1); le precondizioni (2);
#   - demo/in_classe.sh e _docente/live.sh con il claude finto: quante
#     chiamate, in che ordine, da quale cartella, con quali opzioni, i bracci
#     diversi soltanto nel system prompt, la chiamata di --resume sulla
#     sessione giusta, la sessione tolta alla fine, nessuna ANTHROPIC_API_KEY,
#     le precondizioni (2, nessuna chiamata: l'esca), una chiamata fallita (1);
#   - shellcheck -x sugli script e su questo file.
# Mai il claude vero: il finto e l'esca stanno davanti nel PATH, e la suite lo
# controlla prima di usarli. CASES è il numero dei casi: se ne girano di più o
# di meno la suite esce 2.
#
# Uso:    m7_assistenti_llm/_docente/test_m7_d01.sh
# Uscita: 0 = tutti i casi passano · 1 = almeno un caso fallito · 2 =
#         precondizione (manca python3, git, tar o shellcheck), o un numero di
#         casi diverso da CASES
set -uo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly MOD="${SELF%/_docente/*}"
readonly RADICE="${MOD%/*}"
D01="${MOD}/s5_anatomia_e_strumenti/m7_2_anatomia"
D01+="/M7-D01_cambia_il_system_prompt"
readonly D01
readonly FINTO_PY="${MOD}/_docente/claude_finto_m7_d01_d04.py"
# La libreria del repository, per la base dei file temporanei.
# shellcheck source=../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"
readonly CASES=104
FATTO='Fatto: ogni esecuzione è stata messa alla prova;'
FATTO+=' gli esiti sono qui sopra.'
readonly FATTO
readonly NONCONF='non confermata in questa esecuzione'
readonly NONDIST='non distinguibile'
readonly SEGUITO='Qual è la parola in codice di questa prova?'
readonly PAROLA='GENZIANA-1234'
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
# aggiunge a TUTTO, dove alla fine non devono esserci «smentita» né traceback.
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
expect_absent() {
  if grep -qF -- "$2" <<< "${OUT}"; then
    fail "$1: «$2» c'è: ${OUT:0:400}"
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

# Uno spazio di lavoro nuovo, con prepara_esercizio.sh in una radice nuova.
# Arguments: $1 la variabile da assegnare. Returns: 0; 1 se non riesce.
nuovo_ws() {
  local __r
  __r="$(mktemp -d "${TMP}/radice.XXXXXX")" || exit 2
  "${RADICE}/tools/prepara_esercizio.sh" M7-D01 --radice "${__r}" \
    > "${TMP}/prepara.log" 2>&1 || return 1
  printf -v "$1" '%s' "${__r}/M7-D01"
}

# Sceglie come si comporta il claude finto. Arguments: le parole di FINTO_MODI.
modo() { printf '%s' "$*" > "${TMP}/modi"; }

# L'esca (registra ogni invocazione ed esce 0), il claude finto (un involucro
# che legge i modi da un file) e i PATH ridotti. Esce 2 se nel PATH di prova
# claude non è il finto.
prepara_claude() {
  local t
  mkdir -p "${TMP}/esca" "${TMP}/finto" "${TMP}/senza_python" \
    "${TMP}/senza_claude" "${TMP}/casa" || exit 2
  # shellcheck disable=SC2016  # il corpo è dell'esca
  printf '%s\n' '#!/bin/bash' \
    'printf "invocazione %s\n" "$*" >> "${ESCA_LOG}"' \
    > "${TMP}/esca/claude" || exit 2
  cat > "${TMP}/finto/claude" <<EOF || exit 2
#!/bin/bash
export FINTO_LOG="${TMP}/finto.log"
FINTO_MODI="\$(cat "${TMP}/modi" 2> /dev/null)"
export FINTO_MODI
exec python3 -B -I "${FINTO_PY}" "\$@"
EOF
  chmod 755 "${TMP}/esca/claude" "${TMP}/finto/claude" || exit 2
  for t in readlink git tar; do
    ln -s "$(command -v "${t}")" "${TMP}/senza_python/${t}" || exit 2
  done
  ln -s "${TMP}/esca/claude" "${TMP}/senza_python/claude" || exit 2
  for t in readlink python3 git tar; do
    ln -s "$(command -v "${t}")" "${TMP}/senza_claude/${t}" || exit 2
  done
  t="$(PATH="${TMP}/finto:${PATH}" command -v claude)"
  if [[ "${t}" != "${TMP}/finto/claude" ]]; then
    echo "test_m7_d01: nel PATH di prova claude è ${t}, non il finto" >&2
    exit 2
  fi
  modo
}

# Una chiamata del finto. Arguments: $1 il system prompt (generico o
# ciaspolink), $2 il prompt, $3 il file dello stream, $4 la cartella di
# partenza, poi le opzioni in più.
finta() {
  local sistema="$1" prompt="$2" uscita="$3" cartella="$4"
  shift 4
  ( cd "${cartella}" && env -u CLAUDE_CONFIG_DIR HOME="${TMP}/casa" \
      "${TMP}/finto/claude" -p --model sonnet --permission-mode dontAsk \
      --permission-prompts none --output-format stream-json --verbose \
      --setting-sources project,local --tools '' \
      --system-prompt-file "${D01}/demo/system-${sistema}.md" --effort low \
      --strict-mcp-config "$@" -- "${prompt}" ) < /dev/null > "${uscita}" \
    || { echo "test_m7_d01: il finto non scrive ${uscita}" >&2; exit 2; }
}

# Una cartella temporanea nuova. Outputs: il percorso.
cartella_temp() { mktemp -d "${TMP}/cartella.XXXXXX" || exit 2; }

# Rifà un'esecuzione della parte 1, con i modi dati.
# Arguments: $1 la cartella degli stream, $2 il nome (generico-1, …), $3 i modi.
rifai() {
  local j="$1" nome="$2" modi="${3:-}" sistema="${2%%-*}"
  modo "${modi}"
  mkdir -p "${j}/${nome}" || exit 2
  finta "${sistema}" "$(< "${D01}/demo/messaggio.txt")" \
    "${j}/${nome}/stream.jsonl" "$(cartella_temp)" --no-session-persistence
  modo
}

# Rifà una prova della parte 2 con le sue tre chiamate, con i modi dati.
# Arguments: $1 la cartella degli stream, $2 il numero, $3 i modi.
rifai_memoria() {
  local j="$1" n="$2" modi="${3:-}" d cartella sessione primo
  d="${j}/memoria-${n}"
  mkdir -p "${d}" || exit 2
  cartella="$(cartella_temp)"
  printf '%s\n' "${PAROLA}" > "${d}/parola.txt" || exit 2
  modo "${modi}"
  primo="La parola in codice di questa prova è ${PAROLA}."
  primo+=" Rispondi solo: ricevuto."
  finta generico "${primo}" "${d}/primo.jsonl" "${cartella}"
  sessione="$(python3 -B -I -c 'import json, sys
d = json.loads(open(sys.argv[1], encoding="utf-8").readline())
print(d["session_id"])' "${d}/primo.jsonl")" || exit 2
  finta generico "${SEGUITO}" "${d}/nuova.jsonl" "${cartella}" \
    --no-session-persistence
  finta generico "${SEGUITO}" "${d}/ripresa.jsonl" "${cartella}" \
    --resume "${sessione}"
  modo
}

# Una cartella nuova di stream, con $2 esecuzioni per braccio.
# Arguments: $1 la variabile da assegnare, $2 quante.
nuova_serie() {
  local __j k b
  __j="$(mktemp -d "${TMP}/json.XXXXXX")" || exit 2
  for (( k = 1; k <= $2; k++ )); do
    for b in generico ciaspolink; do
      rifai "${__j}" "${b}-${k}"
    done
    rifai_memoria "${__j}" "${k}"
  done
  printf -v "$1" '%s' "${__j}"
}

# controlla_sistema.py dell'elemento; RC e OUT come run.
controlla() { run python3 -B -I "${D01}/demo/controlla_sistema.py" "$@"; }

# Lo script con l'esca davanti nel PATH (o con un PATH dato); il registro
# riparte vuoto. Arguments: $1 lo script, $2 lo spazio di lavoro, $3
# facoltativo il PATH, poi le variabili NOME=valore.
esca() {
  local script="$1" w="$2" percorso="${3:-${TMP}/esca:${PATH}}"
  shift 2
  (( $# == 0 )) || shift
  : > "${TMP}/esca.log"
  run env PATH="${percorso}" HANDSON_NO_PAUSE=1 ESCA_LOG="${TMP}/esca.log" \
    "$@" "${script}" "${w}"
}

# Una precondizione: uscita 2, la parola attesa, nessuna chiamata al modello
# (--version a parte). Arguments: $1 il nome, $2 la parola, poi gli argomenti di
# esca.
precondizione() {
  local nome="$1" parola="$2" n
  shift 2
  esca "$@"
  expect "${nome}" 2 "${parola}"
  n="$(grep -c -v -- '--version' "${TMP}/esca.log")"
  if (( n == 0 )); then
    pass "${nome}: nessuna chiamata al modello"
  else
    fail "${nome}: ${n} chiamate"
  fi
}

# Lo script con il finto davanti nel PATH e ANTHROPIC_API_KEY e
# CLAUDE_CODE_EFFORT_LEVEL impostate (lo script le deve togliere); il registro
# riparte vuoto; la casa di prova (le sessioni) ripulita.
# Arguments: $1 lo script, $2 lo spazio di lavoro, poi le variabili NOME=valore.
finto() {
  local script="$1" w="$2"
  shift 2
  : > "${TMP}/finto.log"
  rm -rf "${TMP}/casa/.claude"
  run env -u CLAUDE_CONFIG_DIR PATH="${TMP}/finto:${PATH}" \
    HOME="${TMP}/casa" HANDSON_NO_PAUSE=1 ANTHROPIC_API_KEY=valore-finto \
    CLAUDE_CODE_EFFORT_LEVEL=high TMPDIR="${TMP}" "$@" "${script}" "${w}"
}

# Le chiamate di un registro del finto, contro le attese: quante, in che
# ordine, da quale cartella, con quali opzioni; i bracci diversi soltanto nel
# system prompt; la parte 2 con la sessione giusta.
# Arguments: $1 il registro, $2 lo spazio di lavoro, $3 quante esecuzioni.
controlla_chiamate() {
  run python3 -B -I - "$1" "$2" "$3" "${D01}/demo" <<'PY'
import json, os, re, sys
log, ws, n, demo = sys.argv[1:5]
n = int(n)
chiamate = [json.loads(r) for r in open(log, encoding="utf-8")]
VALORE = {"--model", "--effort", "--output-format", "--setting-sources",
          "--permission-mode", "--permission-prompts", "--tools",
          "--system-prompt-file", "--resume"}
def opzioni(c):
    argv = c["argv"]
    fine, o, j = argv.index("--"), {}, 0
    while j < fine:
        if argv[j] in VALORE:
            o[argv[j]] = argv[j + 1]
            j += 2
        else:
            o[argv[j]] = True
            j += 1
    return o, argv[fine + 1:]
leggi = lambda p: open(os.path.join(demo, p), encoding="utf-8").read().strip()
messaggio, seguito = leggi("messaggio.txt"), leggi("seguito.txt")
problemi = []
attese = n * 2 + n * 3
if len(chiamate) != attese:
    problemi.append("%d chiamate invece di %d" % (len(chiamate), attese))
fisse = (("--model", "sonnet"), ("--effort", "low"),
         ("--output-format", "stream-json"),
         ("--setting-sources", "project,local"), ("--tools", ""),
         ("--permission-mode", "dontAsk"), ("--permission-prompts", "none"))
for i, c in enumerate(chiamate, 1):
    o, resto = opzioni(c)
    for k, v in fisse:
        if o.get(k) != v:
            problemi.append("chiamata %d: %s" % (i, k))
    for k in ("-p", "--verbose", "--strict-mcp-config"):
        if o.get(k) is not True:
            problemi.append("chiamata %d: %s" % (i, k))
    if any("dangerously" in a or "bypassPermissions" in a for a in c["argv"]) \
            or "--allowedTools" in o:
        problemi.append("chiamata %d: salta i permessi o ha --allowedTools" % i)
    if len(resto) != 1:
        problemi.append("chiamata %d: il prompt dopo -- non è uno" % i)
    if os.path.realpath(c["cwd"]).startswith(os.path.realpath(ws) + "/") \
            or os.path.realpath(c["cwd"]) == os.path.realpath(ws):
        problemi.append("chiamata %d: dentro lo spazio di lavoro" % i)
    if c["chiave"] or c["effort"]:
        problemi.append("chiamata %d: ANTHROPIC_API_KEY o EFFORT" % i)
    if not c["stdin_nullo"]:
        problemi.append("chiamata %d: STDIN non è /dev/null" % i)
# I bracci: gli argomenti uguali tranne il file del system prompt.
def senza_sistema(c):
    o, resto = opzioni(c)
    o = dict(o)
    o.pop("--system-prompt-file", None)
    return o, resto
per_esecuzione = {}
for i in range(n):
    gen = chiamate[i]
    cia = chiamate[n + i]
    ogen, ocia = opzioni(gen)[0], opzioni(cia)[0]
    if os.path.basename(ogen["--system-prompt-file"]) != "system-generico.md" \
            or os.path.basename(ocia["--system-prompt-file"]) != "system-ciaspolink.md":
        problemi.append("esecuzione %d: i system prompt" % (i + 1))
    if senza_sistema(gen) != senza_sistema(cia):
        problemi.append("esecuzione %d: i bracci differiscono" % (i + 1))
    if gen["sistema"] == cia["sistema"]:
        problemi.append("esecuzione %d: lo stesso testo di sistema" % (i + 1))
    for c in (gen, cia):
        if opzioni(c)[1] != [messaggio]:
            problemi.append("esecuzione %d: il messaggio" % (i + 1))
        if "--no-session-persistence" not in opzioni(c)[0] \
                or "--resume" in opzioni(c)[0]:
            problemi.append("esecuzione %d: la sessione" % (i + 1))
# Le cartelle dei bracci sono diverse per ogni chiamata.
if len({c["cwd"] for c in chiamate[:2 * n]}) != 2 * n:
    problemi.append("i bracci hanno cartelle ripetute")
# La parte 2: tre chiamate per esecuzione, nella stessa cartella.
risposte = os.path.join(ws, "risposte")
for k in range(n):
    a, b, c = chiamate[2 * n + 3 * k:2 * n + 3 * k + 3]
    numero = k + 1
    if len({a["cwd"], b["cwd"], c["cwd"]}) != 1:
        problemi.append("memoria-%d: tre cartelle diverse" % numero)
    parola_file = open(os.path.join(risposte, "memoria-%d" % numero,
                                    "parola.txt"), encoding="utf-8").read().strip()
    if not re.match(r"^[A-Z]+-[0-9]{4}$", parola_file):
        problemi.append("memoria-%d: la parola «%s»" % (numero, parola_file))
    oa, ra = opzioni(a)
    ob, rb = opzioni(b)
    oc, rc = opzioni(c)
    if parola_file not in ra[0] or "--no-session-persistence" in oa \
            or "--resume" in oa or "@@PAROLA@@" in ra[0]:
        problemi.append("memoria-%d: la prima chiamata" % numero)
    if rb != [seguito] or "--no-session-persistence" not in ob or "--resume" in ob:
        problemi.append("memoria-%d: la chiamata nuova" % numero)
    primo = open(os.path.join(risposte, "memoria-%d" % numero, "primo.jsonl"),
                 encoding="utf-8").readline()
    sessione = json.loads(primo)["session_id"]
    if rc != [seguito] or oc.get("--resume") != sessione:
        problemi.append("memoria-%d: la chiamata con --resume" % numero)
    if "--no-session-persistence" in oc:
        problemi.append("memoria-%d: --resume non deve avere "
                        "--no-session-persistence" % numero)
    if {os.path.basename(opzioni(x)[0]["--system-prompt-file"])
            for x in (a, b, c)} != {"system-generico.md"}:
        problemi.append("memoria-%d: il system prompt" % numero)
print("; ".join(problemi) or "chiamate giuste")
PY
}

# --- L'elemento -------------------------------------------------------------

t_elemento() {
  local f
  for f in README.md verifica.sh demo/system-generico.md \
      demo/system-ciaspolink.md demo/messaggio.txt demo/primo.txt \
      demo/seguito.txt demo/controlla_sistema.py demo/in_classe.sh \
      _docente/live.sh soluzione/LEGGIMI.md; do
    vero "elemento: ${f}" test -f "${D01}/${f}"
  done
  for f in verifica.sh _docente/live.sh demo/in_classe.sh; do
    vero "elemento: ${f} eseguibile" test -x "${D01}/${f}"
  done
  run python3 -B -I - "${D01}/demo" <<'PY'
import os, sys
d = sys.argv[1]
leggi = lambda p: open(os.path.join(d, p), encoding="utf-8").read()
problemi = []
gen, cia = leggi("system-generico.md"), leggi("system-ciaspolink.md")
if len(gen.splitlines()) != 1:
    problemi.append("system-generico.md: una riga")
if len(cia.splitlines()) > 2 or "tre righe" not in cia \
        or "CiaspoLink" not in cia:
    problemi.append("system-ciaspolink.md: il ruolo e al massimo tre righe")
if "CiaspoLink" in gen:
    problemi.append("system-generico.md: niente ruolo")
if "@example" in leggi("messaggio.txt") or "Campione" not in leggi("messaggio.txt"):
    problemi.append("messaggio.txt: la cliente inventata")
if "@@PAROLA@@" not in leggi("primo.txt"):
    problemi.append("primo.txt: il segnaposto")
print("; ".join(problemi) or "testi a posto")
PY
  expect "i testi della demo: i system prompt, il messaggio, primo e seguito" \
    0 "testi a posto"
}

# Il README: le dieci sezioni, le frasi di Anthropic; niente identificativi
# interni, giornate, «smentita».
t_readme() {
  run python3 -B -I - "${D01}" <<'PY'
import os, re, sys
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
for titolo in ("## Punto di partenza (tools/prepara_esercizio.sh M7-D01)",
               "## Verifica (tools/verifica.sh M7-D01)"):
    if titolo not in readme:
        problemi.append("il titolo «%s»" % titolo)
BP = "https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/" \
    "claude-prompting-best-practices"
WM = "https://platform.claude.com/docs/en/build-with-claude/working-with-messages"
HL = "https://code.claude.com/docs/en/headless"
frasi = [
    ("A system prompt is a way of providing context and instructions to "
     "Claude, such as specifying a particular goal or role.",
     "https://platform.claude.com/docs/en/api/messages/create"),
    ("Setting a role in the system prompt focuses Claude's behavior and tone…",
     BP),
    ("The Messages API is stateless, which means that you always send the "
     "full conversational history to the API.", WM),
    ("Use --continue to continue the most recent conversation, or --resume "
     "with a session ID to continue a specific conversation.", HL)]
piano = " ".join(readme.split())
for frase, url in frasi:
    if frase not in piano:
        problemi.append("manca «%s»" % frase[:40])
    if url not in readme:
        problemi.append("manca %s" % url)
for vietata in ("smentit", "FACT-", "M7-X", "X-3", "/home/"):
    if vietata in readme:
        problemi.append("«%s»" % vietata)
for parola in ("oggi", "domani", "pausa", "pranzo"):
    if re.search(r"\b%s\b" % parola, readme):
        problemi.append("«%s»" % parola)
print("; ".join(problemi) or "README a posto")
PY
  expect "README: sezioni, frasi con l'indirizzo, niente di vietato" 0 \
    "README a posto"
}

t_prepara() {
  local ws f
  if ! nuovo_ws ws; then
    fail "prepara_esercizio.sh M7-D01: $(tail -n 3 "${TMP}/prepara.log")"
    return
  fi
  pass "prepara_esercizio.sh M7-D01"
  for f in system-generico.md system-ciaspolink.md messaggio.txt primo.txt \
      seguito.txt controlla_sistema.py in_classe.sh .claude/settings.json; do
    vero "spazio di lavoro: ${f}" test -f "${ws}/${f}"
  done
  if [[ ! -e "${ws}/soluzione" && ! -e "${ws}/_docente" ]]; then
    pass "spazio di lavoro: niente soluzione/ né _docente/"
  else
    fail "spazio di lavoro: soluzione/ o _docente/"
  fi
  run "${RADICE}/tools/verifica.sh" M7-D01 --radice "${ws%/M7-D01}"
  expect "verifica.sh sul punto di partenza: 1" 1 \
    "Manca la cartella risposte/"
}

# --- Il controllo -----------------------------------------------------------

t_controllo() {
  local j
  nuova_serie j 3
  controlla "${j}"
  expect "controllo: tre coppie, tutto a posto, 0" 0 "confermata 3 su 3"
  expect_absent "controllo: nessun «non distinguibile»" "${NONDIST}"
  expect_absent "controllo: nessun «non confermata»" "${NONCONF}"
  expect "controllo: la soglia in ogni braccio" 0 \
    "rispettata: generico 0 su 3, ciaspolink 3 su 3"
  expect "controllo: le righe e i token della prima richiesta" 0 "righe 12"
  expect "controllo: la prima richiesta dei due bracci" 0 \
    "esecuzione 1: generico"
  expect "controllo: le garanzie della parte 2, senza --resume" 0 \
    "senza --resume la risposta non contiene la parola: confermata"
  expect "controllo: le garanzie della parte 2, con --resume" 0 \
    "con --resume la risposta contiene la parola: confermata"
  expect "controllo: i token di tutte le chiamate" 0 \
    "Come dati, tutte le 15 chiamate"
  rifai "${j}" generico-2 generico-breve
  controlla "${j}"
  expect "esito: il generico in tre righe, non distinguibile, 0" 0 \
    "esecuzione 2: generico 2 righe, ciaspolink 2 righe: ${NONDIST}"
  expect "esito: la conta scende a 2 su 3" 0 "confermata 2 su 3"
  rifai "${j}" generico-2
  rifai "${j}" ciaspolink-1 ciaspolink-lungo
  controlla "${j}"
  expect "esito: il ruolo non rispetta la soglia, non confermata, 0" 0 \
    "esecuzione 1: generico 12 righe, ciaspolink 12 righe: ${NONCONF}"
  rifai "${j}" ciaspolink-1
  rifai_memoria "${j}" 2 "sapeva=${PAROLA}"
  controlla "${j}"
  expect "garanzia: senza --resume la parola non deve esserci, 1" 1 \
    "senza --resume la risposta non contiene la parola: ${NONCONF}"
  expect "garanzia: l'uscita 1 ha il suo perché" 1 "Una garanzia non vale"
  rifai_memoria "${j}" 2 dimenticata
  controlla "${j}"
  expect "garanzia: con --resume la parola deve esserci, 1" 1 \
    "con --resume la risposta contiene la parola: ${NONCONF}"
}

t_mancanze() {
  local j
  nuova_serie j 2
  rm -r -- "${j}/ciaspolink-2"
  controlla "${j}"
  expect "mancanza: un'esecuzione senza la sua coppia, 1" 1 \
    "manca ciaspolink-2/stream.jsonl"
  nuova_serie j 2
  rm -r -- "${j}/memoria-2"
  controlla "${j}"
  expect "mancanza: la parte 2 che manca, 1" 1 "manca memoria-2/"
  nuova_serie j 1
  rm -- "${j}/memoria-1/parola.txt"
  controlla "${j}"
  expect "mancanza: parola.txt che manca, 1" 1 "manca memoria-1/parola.txt"
  nuova_serie j 1
  rm -- "${j}/memoria-1/ripresa.jsonl"
  controlla "${j}"
  expect "mancanza: la chiamata con --resume che manca, 1" 1 \
    "manca memoria-1/ripresa.jsonl"
  nuova_serie j 1
  rifai "${j}" generico-1 tronco
  controlla "${j}"
  expect "mancanza: uno stream senza il risultato, 1" 1 \
    "non finisce con il risultato"
  nuova_serie j 1
  rifai "${j}" ciaspolink-1 errore
  controlla "${j}"
  expect "mancanza: un risultato con l'errore, 1" 1 \
    "claude ha restituito un errore"
  nuova_serie j 1
  : > "${j}/generico-1/stream.jsonl"
  controlla "${j}"
  expect "mancanza: uno stream vuoto, 1" 1 "generico-1"
}

t_illeggibili() {
  local j
  nuova_serie j 1
  rifai "${j}" generico-1 riga-rotta
  controlla "${j}"
  expect "illeggibile: una riga che non è JSON, 2" 2 "non è JSON"
  nuova_serie j 1
  printf 'parola-con-minuscole\n' > "${j}/memoria-1/parola.txt" || exit 2
  controlla "${j}"
  expect "illeggibile: parola.txt non è una parola, 2" 2 \
    "non è una parola in codice"
  j="$(mktemp -d "${TMP}/vuota.XXXXXX")"
  controlla "${j}"
  expect "illeggibile: una cartella senza esecuzioni, 2" 2 \
    "nessuna esecuzione"
  controlla "${TMP}/non-c-e"
  expect "illeggibile: una cartella che non c'è, 2" 2 "non esiste"
  controlla
  expect "uso: senza argomenti, 2" 2 "Uso:"
  controlla --aiuto
  expect "uso: un'opzione, 2" 2 "Uso:"
  nuova_serie j 1
  run env PN_HANDSON_ROOT="${TMP}/non-c-e" python3 -B -I \
    "${D01}/demo/controlla_sistema.py" "${j}"
  expect "precondizione: tools/ che non c'è, 2" 2 \
    "non trovo tools/lib_leggi_contesto.py"
}

t_verifica() {
  local ws
  nuovo_ws ws || { fail "verifica: prepara_esercizio.sh"; return; }
  run "${D01}/verifica.sh" "${ws}"
  expect "verifica: senza risposte/, 1" 1 "Manca la cartella risposte/"
  mkdir -p "${ws}/risposte" || exit 2
  run "${D01}/verifica.sh" "${ws}"
  expect "verifica: risposte/ vuota, 1" 1 "nessuna esecuzione"
  local b
  for b in generico ciaspolink; do
    rifai "${ws}/risposte" "${b}-1"
  done
  rifai_memoria "${ws}/risposte" 1
  printf '%s\n' 'print("CONTROLLO FINTO")' \
    > "${ws}/controlla_sistema.py" || exit 2
  run env PN_HANDSON_ROOT="${RADICE}" "${D01}/verifica.sh" "${ws}"
  expect "verifica: una serie completa, 0, «Fatto»" 0 "${FATTO}"
  expect_absent "verifica: il controllo dell'elemento, non della copia" \
    "CONTROLLO FINTO"
  rm -r -- "${ws}/risposte/ciaspolink-1"
  run "${D01}/verifica.sh" "${ws}"
  expect "verifica: un'esecuzione che manca, 1" 1 "manca ciaspolink-1"
  run "${D01}/verifica.sh"
  expect "verifica: senza argomenti, 2" 2 "spazio di lavoro assente"
}

# --- in_classe.sh e live.sh -------------------------------------------------

t_in_classe() {
  local ws
  nuovo_ws ws || { fail "in_classe: prepara_esercizio.sh"; return; }
  finto "${D01}/demo/in_classe.sh" "${ws}" PN_ESECUZIONI=2
  expect "in_classe: due esecuzioni per parte, 0" 0 \
    "VERIFICA OK   il controllo, sulle esecuzioni di risposte/"
  expect "in_classe: il comando sullo schermo" 0 "--no-session-persistence"
  expect "in_classe: --system-prompt-file sullo schermo" 0 \
    "--system-prompt-file"
  expect "in_classe: la coppia, sullo schermo" 0 "confermata 2 su 2"
  controlla_chiamate "${TMP}/finto.log" "${ws}" 2
  expect "in_classe: le chiamate, le cartelle, le opzioni, i bracci" 0 \
    "chiamate giuste"
  if [[ -z "$(compgen -G "${TMP}/casa/.claude/projects/*" || true)" ]]; then
    pass "in_classe: le sessioni salvate non restano"
  else
    fail "in_classe: restano sessioni in ${TMP}/casa/.claude/projects"
  fi
  run git -C "${ws}" status --porcelain
  if [[ "${OUT}" == '?? risposte/' ]]; then
    pass "in_classe: lo spazio di lavoro cambia solo in risposte/"
  else
    fail "in_classe: git status «${OUT}»"
  fi
  run env PN_HANDSON_ROOT="${RADICE}" "${D01}/verifica.sh" "${ws}"
  expect "in_classe: poi verifica.sh, 0" 0 "${FATTO}"
}

t_live() {
  local ws
  nuovo_ws ws || { fail "live: prepara_esercizio.sh"; return; }
  finto "${D01}/_docente/live.sh" "${ws}"
  expect "live: tre esecuzioni per parte, 0" 0 \
    "VERIFICA OK   verifica.sh dell'elemento"
  expect "live: la coppia, tre su tre" 0 "confermata 3 su 3"
  controlla_chiamate "${TMP}/finto.log" "${ws}" 3
  expect "live: le quindici chiamate" 0 "chiamate giuste"
  run "${RADICE}/tools/verifica.sh" M7-D01 --radice "${ws%/M7-D01}"
  expect "live: poi tools/verifica.sh, 0" 0 "VERIFICA OK   M7-D01: fatto."
  run "${D01}/_docente/live.sh"
  expect "live: senza argomenti, 2" 2 "uso:"
}

t_precondizioni() {
  local ws s="${D01}/demo/in_classe.sh"
  nuovo_ws ws || { fail "precondizioni: prepara_esercizio.sh"; return; }
  precondizione "precondizione: una cartella che non è lo spazio" \
    "non è lo spazio di lavoro di M7-D01" "${s}" "${TMP}"
  precondizione "precondizione: nessuno spazio di lavoro" \
    "spazio di lavoro assente" "${s}" ""
  precondizione "precondizione: PN_ESECUZIONI 0" "PN_ESECUZIONI" \
    "${s}" "${ws}" "${TMP}/esca:${PATH}" PN_ESECUZIONI=0
  precondizione "precondizione: HANDSON_ENV claude-ai-pro" \
    "è un elemento claude-code-pro" "${s}" "${ws}" "${TMP}/esca:${PATH}" \
    HANDSON_ENV=claude-ai-pro
  precondizione "precondizione: senza python3" "manca lo strumento: python3" \
    "${s}" "${ws}" "${TMP}/senza_python"
  precondizione "precondizione: senza claude" "manca lo strumento: claude" \
    "${s}" "${ws}" "${TMP}/senza_claude"
  printf 'x\n' > "${ws}/estraneo.txt" || exit 2
  precondizione "precondizione: uno spazio di lavoro cambiato" \
    "non è al punto di partenza" "${s}" "${ws}"
  rm -f -- "${ws}/estraneo.txt"
  mkdir -p "${ws}/risposte" || exit 2
  precondizione "precondizione: risposte/ c'è già" \
    "non è al punto di partenza" "${s}" "${ws}"
  rmdir -- "${ws}/risposte"
  mv -- "${ws}/messaggio.txt" "${TMP}/messaggio.txt" || exit 2
  precondizione "precondizione: il messaggio che manca" \
    "file assente o illeggibile: messaggio.txt" "${s}" "${ws}"
  mv -- "${TMP}/messaggio.txt" "${ws}/messaggio.txt" || exit 2
  precondizione "precondizione: senza tools/lib_handson.sh" \
    "lanciatelo dal repository, o date PN_HANDSON_ROOT" "${s}" "${ws}" \
    "${TMP}/esca:${PATH}" PN_HANDSON_ROOT="${TMP}/non-c-e"
}

t_fallita() {
  local ws
  nuovo_ws ws || { fail "fallita: prepara_esercizio.sh"; return; }
  modo "ko-se=${SEGUITO:0:16}"
  finto "${D01}/demo/in_classe.sh" "${ws}"
  modo
  expect "fallita: la chiamata nuova che fallisce, 1" 1 \
    "VERIFICA KO   memoria-1: la chiamata nuova è fallita"
  vero "fallita: ciò che c'era è in risposte/" \
    test -s "${ws}/risposte/memoria-1/primo.jsonl"
  run "${D01}/verifica.sh" "${ws}"
  expect "fallita: verifica.sh dopo, 1" 1 "memoria-1/nuova.jsonl"
}

# Gli script di M7-D01 e questo file, con shellcheck -x.
t_shellcheck() {
  local f
  for f in "${D01}/verifica.sh" "${D01}/_docente/live.sh" \
      "${D01}/demo/in_classe.sh" "${SELF}"; do
    if ( cd "${RADICE}" && shellcheck -x -- "${f}" ) > /dev/null 2>&1; then
      pass "shellcheck ${f#"${RADICE}"/}"
    else
      fail "shellcheck ${f#"${RADICE}"/}"
    fi
  done
}

main() {
  local t
  for t in python3 git tar shellcheck; do
    command -v "${t}" > /dev/null 2>&1 \
      || { echo "test_m7_d01: manca ${t}" >&2; exit 2; }
  done
  [[ -f "${FINTO_PY}" ]] \
    || { echo "test_m7_d01: manca ${FINTO_PY}" >&2; exit 2; }
  handson::init_temp_base
  TMP="$(mktemp -d "${HANDSON_TEMP_BASE}/test_m7_d01.XXXXXX")" || exit 2
  trap 'chmod -R u+rwX "${TMP}" 2> /dev/null; rm -rf "${TMP}"' EXIT
  prepara_claude
  t_elemento
  t_readme
  t_prepara
  t_controllo
  t_mancanze
  t_illeggibili
  t_verifica
  t_in_classe
  t_live
  t_precondizioni
  t_fallita
  t_shellcheck
  OUT="${TUTTO}"
  expect_absent "in nessuna uscita «smentita»" "smentita"
  expect_absent "in nessuna uscita un traceback" "Traceback"
  echo "PASS=${PASS} FAIL=${FAIL} SKIP=${SKIP}"
  if (( PASS + FAIL + SKIP != CASES )); then
    echo "test_m7_d01: girati $((PASS + FAIL + SKIP)) casi, attesi" \
      "${CASES}" >&2
    exit 2
  fi
  (( FAIL == 0 )) || exit 1
}

main "$@"
