#!/bin/bash
#
# test_m8_d04.sh -- le prove di M8-D04 «Il modello giusto per il lavoro», per il
# docente (sta in _docente/, il materiale del docente):
#   - l'elemento: i file, i ticket, il prompt, lo schema, il listino, il README
#     con le sue dieci sezioni, le frasi di Anthropic con il loro indirizzo,
#     niente identificativi interni, «smentita» o riferimenti alla giornata;
#   - componi.py: i ticket numerati nel prompt, l'etichetta mai; i ticket e lo
#     schema che non vanno (2);
#   - prepara_esercizio.sh e verifica.sh sul punto di partenza (1);
#   - controlla_modello.py su JSON del claude finto: la tabella, il confronto
#     sul prezzo (n su N, non cambia l'uscita), l'accuratezza come dato, le
#     chiamate che mancano o senza output strutturato (1), i JSON che non si
#     leggono e gli usi sbagliati (2), mai un traceback;
#   - verifica.sh: il controllo dell'elemento, mai quello dello spazio di
#     lavoro; risposte/ che manca o vuota (1); le precondizioni (2);
#   - demo/in_classe.sh e _docente/live.sh con il claude finto: quante
#     chiamate, in che ordine, con quali opzioni, le tre diverse soltanto nel
#     modello, il prompt composto, nessuna ANTHROPIC_API_KEY, le precondizioni
#     (2, nessuna chiamata: l'esca), una chiamata fallita (1);
#   - shellcheck -x sugli script e su questo file.
# Mai il claude vero: il finto e l'esca stanno davanti nel PATH, e la suite lo
# controlla prima di usarli. CASES è il numero dei casi: se ne girano di più o
# di meno la suite esce 2.
#
# Uso:    m8_costi_ottimizzazione/_docente/test_m8_d04.sh
# Uscita: 0 = tutti i casi passano · 1 = almeno un caso fallito · 2 =
#         precondizione (manca python3, git, tar o shellcheck), o un numero di
#         casi diverso da CASES
set -uo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly MOD="${SELF%/_docente/*}"
readonly RADICE="${MOD%/*}"
D04="${MOD}/s6_costi_e_ottimizzazione/m8_4_il_modello_giusto"
D04+="/M8-D04_il_modello_giusto"
readonly D04
readonly FINTO_PY="${MOD}/_docente/claude_finto_m8_d04.py"
# La libreria del repository, per la base dei file temporanei.
# shellcheck source=../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"
readonly CASES=132
FATTO='Fatto: ogni esecuzione è stata messa alla prova;'
FATTO+=' gli esiti sono qui sopra.'
readonly FATTO
readonly NONCONF='non confermata in questa esecuzione'
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
  "${RADICE}/tools/prepara_esercizio.sh" M8-D04 --radice "${__r}" \
    > "${TMP}/prepara.log" 2>&1 || return 1
  printf -v "$1" '%s' "${__r}/M8-D04"
}

# Sceglie come si comporta il claude finto. Arguments: le parole di FINTO_MODI.
modo() { printf '%s' "$*" > "${TMP}/modi"; }

# L'esca (registra ogni invocazione ed esce 0), il claude finto (un involucro
# che legge i modi da un file) e i PATH ridotti. Esce 2 se nel PATH di prova
# claude non è il finto.
prepara_claude() {
  local t
  mkdir -p "${TMP}/esca" "${TMP}/finto" "${TMP}/senza_python" \
    "${TMP}/senza_claude" || exit 2
  # shellcheck disable=SC2016  # il corpo è dell'esca
  printf '%s\n' '#!/bin/bash' \
    'printf "invocazione %s\n" "$*" >> "${ESCA_LOG}"' \
    > "${TMP}/esca/claude" || exit 2
  cat > "${TMP}/finto/claude" <<EOF || exit 2
#!/bin/bash
export FINTO_LOG="${TMP}/finto.log"
export FINTO_TICKET="${D04}/demo/ticket.jsonl"
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
    echo "test_m8_d04: nel PATH di prova claude è ${t}, non il finto" >&2
    exit 2
  fi
  modo
}

# Una chiamata del finto, con le opzioni dell'elemento. Arguments: $1 il
# modello, $2 il file d'uscita, $3 la cartella di partenza.
finta() {
  local schema
  schema="$(< "${D04}/demo/schema-etichette.json")"
  ( cd "$3" && "${TMP}/finto/claude" -p --model "$1" \
      --permission-mode dontAsk --permission-prompts none \
      --output-format json --setting-sources project,local --tools '' \
      --system-prompt "Sei un classificatore di ticket di assistenza clienti." \
      --json-schema "${schema}" --effort low --strict-mcp-config \
      --no-session-persistence -- "prompt finto" ) < /dev/null > "$2" \
    || { echo "test_m8_d04: il finto non scrive $2" >&2; exit 2; }
}

# Una cartella temporanea nuova. Outputs: il percorso.
cartella_temp() { mktemp -d "${TMP}/cartella.XXXXXX" || exit 2; }

# Rifà un'esecuzione, con i modi dati.
# Arguments: $1 la cartella delle chiamate, $2 il nome (haiku-1, …), $3 i modi.
rifai() {
  local j="$1" nome="$2" modi="${3:-}"
  modo "${modi}"
  mkdir -p "${j}/${nome}" || exit 2
  finta "${nome%%-*}" "${j}/${nome}/risposta.json" "$(cartella_temp)"
  modo
}

# Una cartella nuova di chiamate, con $2 esecuzioni per modello.
# Arguments: $1 la variabile da assegnare, $2 quante.
nuova_serie() {
  local __j k m
  __j="$(mktemp -d "${TMP}/json.XXXXXX")" || exit 2
  for (( k = 1; k <= $2; k++ )); do
    for m in haiku sonnet opus; do
      rifai "${__j}" "${m}-${k}"
    done
  done
  printf -v "$1" '%s' "${__j}"
}

# controlla_modello.py dell'elemento; RC e OUT come run.
controlla() { run python3 -B -I "${D04}/demo/controlla_modello.py" "$@"; }

# Una copia della cartella demo/ dell'elemento in una cartella nuova.
# Arguments: $1 la variabile da assegnare.
copia_demo() {
  local __d
  __d="$(mktemp -d "${TMP}/demo.XXXXXX")" || exit 2
  cp -R "${D04}/demo/." "${__d}/" || exit 2
  printf -v "$1" '%s' "${__d}"
}

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
# riparte vuoto.
# Arguments: $1 lo script, $2 lo spazio di lavoro, poi le variabili NOME=valore.
finto() {
  local script="$1" w="$2"
  shift 2
  : > "${TMP}/finto.log"
  run env PATH="${TMP}/finto:${PATH}" HANDSON_NO_PAUSE=1 \
    ANTHROPIC_API_KEY=valore-finto CLAUDE_CODE_EFFORT_LEVEL=high \
    TMPDIR="${TMP}" "$@" "${script}" "${w}"
}

# Le chiamate di un registro del finto, contro le attese: quante, in che
# ordine, con quali opzioni, diverse soltanto nel modello, il prompt composto.
# Arguments: $1 il registro, $2 lo spazio di lavoro, $3 quante esecuzioni.
controlla_chiamate() {
  run python3 -B -I - "$1" "$2" "$3" <<'PY'
import json, os, sys
log, ws, n = sys.argv[1:4]
n = int(n)
leggi = lambda p: open(p, encoding="utf-8").read()
chiamate = [json.loads(r) for r in leggi(log).splitlines()]
VALORE = {"--model", "--effort", "--output-format", "--setting-sources",
          "--permission-mode", "--permission-prompts", "--tools",
          "--system-prompt", "--json-schema"}
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
problemi = []
prompt = leggi(os.path.join(ws, "risposte", "prompt-composto.txt")).rstrip("\n")
schema = json.load(open(os.path.join(ws, "schema-etichette.json"),
                        encoding="utf-8"))
atteso = n * 3
if len(chiamate) != atteso:
    problemi.append("%d chiamate invece di %d" % (len(chiamate), atteso))
fisse = (("--effort", "low"), ("--output-format", "json"),
         ("--setting-sources", "project,local"), ("--tools", ""),
         ("--permission-mode", "dontAsk"), ("--permission-prompts", "none"))
MODELLI = ("haiku", "sonnet", "opus")
for i, c in enumerate(chiamate):
    nome = "chiamata %d" % (i + 1)
    o, resto = opzioni(c)
    for k, v in fisse:
        if o.get(k) != v:
            problemi.append("%s: %s" % (nome, k))
    for k in ("-p", "--strict-mcp-config", "--no-session-persistence"):
        if o.get(k) is not True:
            problemi.append("%s: %s" % (nome, k))
    if any("dangerously" in a or "bypassPermissions" in a for a in c["argv"]) \
            or "--allowedTools" in o:
        problemi.append("%s: salta i permessi o ha --allowedTools" % nome)
    if o.get("--model") != MODELLI[i % 3]:
        problemi.append("%s: il modello è %s" % (nome, o.get("--model")))
    if resto != [prompt]:
        problemi.append("%s: il prompt non è quello composto" % nome)
    if json.loads(o["--json-schema"]) != schema:
        problemi.append("%s: lo schema" % nome)
    if c["sistema"] != "Sei un classificatore di ticket di assistenza clienti.":
        problemi.append("%s: il system prompt" % nome)
    cwd = os.path.realpath(c["cwd"])
    radice_ws = os.path.realpath(ws)
    if cwd == radice_ws or cwd.startswith(radice_ws + "/"):
        problemi.append("%s: dentro lo spazio di lavoro" % nome)
    if c["chiave"] or c["effort"]:
        problemi.append("%s: ANTHROPIC_API_KEY o EFFORT" % nome)
    if not c["stdin_nullo"]:
        problemi.append("%s: STDIN non è /dev/null" % nome)
def senza_modello(c):
    o, resto = opzioni(c)
    o = dict(o)
    o.pop("--model", None)
    return json.dumps([sorted(o.items()), resto], sort_keys=True)
if len({senza_modello(c) for c in chiamate}) != 1:
    problemi.append("le chiamate differiscono in altro che nel modello")
print("; ".join(problemi) or "chiamate giuste")
PY
}

# --- L'elemento -------------------------------------------------------------

t_elemento() {
  local f
  for f in README.md verifica.sh demo/ticket.jsonl demo/prompt.txt \
      demo/schema-etichette.json demo/listino.json demo/componi.py \
      demo/controlla_modello.py demo/in_classe.sh _docente/live.sh \
      soluzione/LEGGIMI.md; do
    vero "elemento: ${f}" test -f "${D04}/${f}"
  done
  for f in verifica.sh _docente/live.sh demo/in_classe.sh; do
    vero "elemento: ${f} eseguibile" test -x "${D04}/${f}"
  done
  if [[ ! -e "${D04}/progetti.txt" ]]; then
    pass "elemento: niente progetti.txt, non usa la base di conoscenza"
  else
    fail "elemento: progetti.txt non serve"
  fi
  run python3 -B -I - "${D04}/demo" <<'PY'
import json, os, re, sys
d = sys.argv[1]
leggi = lambda p: open(os.path.join(d, p), encoding="utf-8").read()
problemi = []
righe = [json.loads(r) for r in leggi("ticket.jsonl").splitlines() if r.strip()]
if len(righe) != 8:
    problemi.append("%d ticket" % len(righe))
contegio = {}
cognomi = ("Esempio", "Prova", "Fittizio", "Campione", "Modello", "Bozza",
           "Simulato", "Inventato", "Ipotetico", "Immaginario", "Provvisorio",
           "Fantasia")
for i, r in enumerate(righe, 1):
    if r["numero"] != i:
        problemi.append("ticket %d: il numero" % i)
    if not r["cliente"].endswith(cognomi) or not r["cliente"].split()[0]:
        problemi.append("ticket %d: il cliente" % i)
    if not re.match(r"^TK-2026-04\d{3}$", r["ticket"]):
        problemi.append("ticket %d: l'identificativo" % i)
    if not "2026-09-07" <= r["data"] <= "2026-09-13":
        problemi.append("ticket %d: la data" % i)
    contegio[r["etichetta"]] = contegio.get(r["etichetta"], 0) + 1
if contegio != {"guasto": 2, "lentezza": 2, "fattura": 2, "attivazione": 2}:
    problemi.append("le etichette: %s" % contegio)
prompt = leggi("prompt.txt")
if prompt.count("@@TICKET@@") != 1 or len(prompt.split()) > 59:
    problemi.append("prompt.txt: il segnaposto, breve")
schema = json.loads(leggi("schema-etichette.json"))
e = schema["properties"]["etichette"]
if e["minItems"] != 8 or e["maxItems"] != 8 \
        or sorted(e["items"]["enum"]) != sorted(contegio):
    problemi.append("lo schema")
listino = json.loads(leggi("listino.json"))
attesi = {"haiku": [0.1, 0.5, 0.125, 0.2, 0.01],
          "sonnet": [2, 10, 2.5, 4, 0.1], "opus": [4, 20, 5, 8, 0.2]}
for m, v in attesi.items():
    c = listino["modelli"][m]
    if [c["input"], c["output"], c["cache_write_5m"], c["cache_write_1h"],
            c["cache_read"]] != v:
        problemi.append("il listino di %s" % m)
if listino["letto_il"] != "2026-11-10" \
        or "about-claude/pricing" not in listino["pagina_prezzi"]:
    problemi.append("la data o l'indirizzo del listino")
print("; ".join(problemi) or "testi a posto")
PY
  expect "i ticket, il prompt, lo schema, il listino" 0 "testi a posto"
}

t_componi() {
  local d
  run python3 -B -I "${D04}/demo/componi.py" "${D04}/demo"
  expect "componi: i ticket numerati, 0" 0 "8. Ho pagato la fattura"
  expect_absent "componi: il segnaposto è sparito" "@@TICKET@@"
  expect_absent "componi: nessuna etichetta dei ticket" '"etichetta"'
  expect_absent "componi: nessun campo cliente" "Giulia Campione"
  copia_demo d
  printf '{non json\n' > "${d}/ticket.jsonl" || exit 2
  run python3 -B -I "${d}/componi.py" "${d}"
  expect "componi: una riga che non è JSON, 2" 2 "non è JSON"
  copia_demo d
  printf '{"testo": "x"}\n' > "${d}/ticket.jsonl" || exit 2
  run python3 -B -I "${d}/componi.py" "${d}"
  expect "componi: un ticket senza etichetta, 2" 2 \
    "testo o etichetta non validi"
  copia_demo d
  printf '{"testo": "x", "etichetta": "altro"}\n' > "${d}/ticket.jsonl" \
    || exit 2
  run python3 -B -I "${d}/componi.py" "${d}"
  expect "componi: un'etichetta sconosciuta, 2" 2 \
    "testo o etichetta non validi"
  copia_demo d
  printf '{"testo": "x", "etichetta": "guasto"}\n' > "${d}/ticket.jsonl" \
    || exit 2
  run python3 -B -I "${d}/componi.py" "${d}"
  expect "componi: lo schema non corrisponde ai ticket, 2" 2 "i ticket sono 1"
  copia_demo d
  printf 'Una richiesta senza segnaposto.\n' > "${d}/prompt.txt" || exit 2
  run python3 -B -I "${d}/componi.py" "${d}"
  expect "componi: il prompt senza segnaposto, 2" 2 "segnaposto"
  copia_demo d
  rm -- "${d}/schema-etichette.json"
  run python3 -B -I "${d}/componi.py" "${d}"
  expect "componi: lo schema che manca, 2" 2 "non si legge"
  run python3 -B -I "${D04}/demo/componi.py" -x
  expect "componi: un'opzione, 2" 2 "Uso:"
}

# Il README: le dieci sezioni, le frasi di Anthropic; niente identificativi
# interni, giornate, «smentita».
t_readme() {
  run python3 -B -I - "${D04}" <<'PY'
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
for titolo in ("## Punto di partenza (tools/prepara_esercizio.sh M8-D04)",
               "## Verifica (tools/verifica.sh M8-D04)"):
    if titolo not in readme:
        problemi.append("il titolo «%s»" % titolo)
COSTI = "https://platform.claude.com/docs/en/about-claude/models/" \
    "optimizing-for-cost-and-intelligence"
SCELTA = "https://platform.claude.com/docs/en/about-claude/models/" \
    "choosing-a-model"
ACADEMY = "https://academy.claude.com/courses/claude-platform-101/" \
    "choosing-the-right-model"
frasi = [
    ("High-volume work with outputs you can check | Try Claude Haiku 5.5 "
     "first", COSTI),
    ("Run your examples through Haiku first. If the quality holds, you're "
     "done", ACADEMY),
    ("The lowest latency and price | Claude Haiku 5.5", SCELTA),
    ("Comparative latency | Moderate | Moderate | Fast | Fastest",
     "https://platform.claude.com/docs/en/models/overview"),
    ("Compare models on cost per completed task, not per token, because "
     "you pay for completed tasks.", COSTI),
    ("the right model is the cheapest one whose output you'd actually "
     "ship.", ACADEMY),
    ("Price each of the five token counts in a response’s usage at its "
     "own rate", COSTI),
    ("Claude Code computes the dollar figure locally from token counts at "
     "list price", "https://code.claude.com/docs/en/costs"),
    ("Both figures are client-side estimates and can differ from your "
     "actual bill.", "https://code.claude.com/docs/en/headless"),
    ("To get output conforming to a specific schema, use --output-format "
     "json with --json-schema and a JSON Schema definition.",
     "https://code.claude.com/docs/en/headless"),
    ("The response includes metadata about the request (session ID, usage, "
     "etc.) with the structured output in the structured_output field.",
     "https://code.claude.com/docs/en/headless"),
    ("Pro, Max, Ultra, Team, Enterprise, and Anthropic API: defaults to "
     "Opus 5.5", "https://code.claude.com/docs/en/model-config")]
piano = " ".join(readme.split())
for frase, url in frasi:
    if frase not in piano:
        problemi.append("manca «%s»" % frase[:40])
    if url not in readme:
        problemi.append("manca %s" % url)
for vietata in ("smentit", "FACT-", "M8-X", "X-3", "X-4", "/home/"):
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
    fail "prepara_esercizio.sh M8-D04: $(tail -n 3 "${TMP}/prepara.log")"
    return
  fi
  pass "prepara_esercizio.sh M8-D04"
  for f in ticket.jsonl prompt.txt schema-etichette.json listino.json \
      componi.py controlla_modello.py in_classe.sh .claude/settings.json; do
    vero "spazio di lavoro: ${f}" test -f "${ws}/${f}"
  done
  if [[ ! -e "${ws}/soluzione" && ! -e "${ws}/_docente" ]]; then
    pass "spazio di lavoro: niente soluzione/ né _docente/"
  else
    fail "spazio di lavoro: soluzione/ o _docente/"
  fi
  run "${RADICE}/tools/verifica.sh" M8-D04 --radice "${ws%/M8-D04}"
  expect "verifica.sh sul punto di partenza: 1" 1 \
    "Manca la cartella risposte/"
}

# --- Il controllo -----------------------------------------------------------

t_controllo() {
  local j
  nuova_serie j 3
  controlla "${j}"
  expect "controllo: tre esecuzioni, tutto a posto, 0" 0 \
    "Come dati, tutte le 9 chiamate"
  expect_absent "controllo: nessun «non confermata»" "${NONCONF}"
  expect "controllo: il confronto sul prezzo, 3 su 3" 0 \
    "Il costo per ticket giusto di Haiku è il più basso: confermata 3 su 3."
  expect "controllo: la tabella, una riga per esecuzione" 0 "sonnet-3"
  expect "controllo: le giuste contro le attese" 0 "8/8"
  if (( RC == 0 )) && (( $(grep -cE '^ *(haiku|sonnet|opus)-[0-9] .* 0,000000 '\
      <<< "${OUT}") == 9 )); then
    pass "controllo: il ricalcolo coincide con la stima, riga per riga"
  else
    fail "controllo: il ricalcolo coincide con la stima, riga per riga"
  fi
  expect "controllo: il costo per ticket giusto" 0 "\$ per giusto"
  expect "controllo: la durata dell'API, come dato" 0 "ms API"
  expect "controllo: sul tempo nessun esito" 0 "Sul tempo nessun esito"
  # Una chiamata su un altro modello non vale per quella cartella.
  nuova_serie j 1
  rifai "${j}" "haiku-1" altro-modello
  controlla "${j}"
  expect "controllo: il modello che ha risposto, 1" 1 \
    "non è su un solo modello"
  nuova_serie j 3
  controlla "${j}"
  expect "controllo: il riepilogo per modello" 0 \
    "haiku: 24 giuste su 24"
  expect "controllo: l'accuratezza come dato, nessuna soglia" 0 \
    "Haiku pari o meglio degli altri due: 3 su 3 esecuzioni (dato)."
  expect "controllo: la data del listino" 0 "listino letto il 2026-11-10"
  expect "controllo: la frase di Anthropic" 0 "Try Claude Haiku 5.5 first"
  rifai "${j}" haiku-2 haiku-caro
  controlla "${j}"
  expect "prezzo: Haiku che costa di più, 0 lo stesso" 0 \
    "esecuzione 2: haiku"
  expect "prezzo: la riga dice non confermata" 0 "${NONCONF}"
  expect "prezzo: la conta scende a 2 su 3" 0 \
    "Il costo per ticket giusto di Haiku è il più basso: confermata 2 su 3."
  rifai "${j}" haiku-2
  rifai "${j}" sonnet-1 costo-diverso
  controlla "${j}"
  expect "stima diversa dal ricalcolo: un dato, 0" 0 "-0,500000"
  rifai "${j}" sonnet-1
  rifai "${j}" haiku-1 "sbaglia-modello=haiku:2"
  controlla "${j}"
  expect "accuratezza: due errori di Haiku, 0 lo stesso" 0 \
    "esecuzione 1: haiku 6/8, sonnet 8/8, opus 8/8"
  expect "accuratezza: il dato scende" 0 \
    "Haiku pari o meglio degli altri due: 2 su 3 esecuzioni (dato)."
  rifai "${j}" haiku-1 "senza-dettaglio"
  controlla "${j}"
  expect "listino: senza il dettaglio della scrittura, la nota, 0" 0 \
    "prezzata tutta a cinque minuti"
}

t_mancanze() {
  local j
  nuova_serie j 2
  rm -r -- "${j}/opus-2"
  controlla "${j}"
  expect "mancanza: un'esecuzione, 1" 1 "manca opus-2/risposta.json"
  nuova_serie j 2
  rm -r -- "${j}/haiku-1" "${j}/sonnet-1" "${j}/opus-1"
  controlla "${j}"
  expect "mancanza: una tornata intera, con quella dopo, 1" 1 \
    "manca haiku-1/risposta.json"
  nuova_serie j 1
  rifai "${j}" sonnet-1 senza-strutturato
  controlla "${j}"
  expect "mancanza: senza structured_output, 1" 1 \
    "senza un output strutturato"
  nuova_serie j 1
  rifai "${j}" opus-1 poche-etichette
  controlla "${j}"
  expect "mancanza: etichette che non bastano, 1" 1 "7 etichette invece di 8"
  nuova_serie j 1
  rifai "${j}" haiku-1 errore
  controlla "${j}"
  expect "mancanza: una chiamata con un errore, 1" 1 \
    "claude ha restituito un errore"
  nuova_serie j 1
  : > "${j}/sonnet-1/risposta.json"
  controlla "${j}"
  expect "mancanza: un JSON vuoto, 1" 1 "è vuoto"
}

t_illeggibili() {
  local j d
  nuova_serie j 1
  rifai "${j}" haiku-1 riga-rotta
  controlla "${j}"
  expect "illeggibile: un file che non è JSON, 2" 2 "il JSON non si legge"
  nuova_serie j 1
  rifai "${j}" opus-1 senza-usage
  controlla "${j}"
  expect "illeggibile: il JSON senza usage, 2" 2 "il campo «usage» non c'è"
  nuova_serie j 1
  rifai "${j}" opus-1 usage-testo
  controlla "${j}"
  expect "illeggibile: un conteggio non numerico, 2" 2 "usage.output_tokens"
  nuova_serie j 1
  printf '[1]\n' > "${j}/haiku-1/risposta.json" || exit 2
  controlla "${j}"
  expect "illeggibile: un JSON che non è un oggetto, 2" 2 "non è un oggetto"
  j="$(mktemp -d "${TMP}/vuota.XXXXXX")"
  controlla "${j}"
  expect "illeggibile: una cartella senza esecuzioni, 2" 2 "nessuna esecuzione"
  controlla "${TMP}/non-c-e"
  expect "illeggibile: una cartella che non c'è, 2" 2 "non esiste"
  controlla
  expect "uso: senza argomenti, 2" 2 "Uso:"
  controlla --aiuto
  expect "uso: un'opzione, 2" 2 "Uso:"
  nuova_serie j 1
  copia_demo d
  rm -- "${d}/listino.json"
  run python3 -B -I "${d}/controlla_modello.py" "${j}"
  expect "precondizione: il listino che manca, 2" 2 "manca"
  copia_demo d
  printf '{"modelli": {}}\n' > "${d}/listino.json" || exit 2
  run python3 -B -I "${d}/controlla_modello.py" "${j}"
  expect "precondizione: un listino senza modelli, 2" 2 "manca il modello"
  copia_demo d
  rm -- "${d}/ticket.jsonl"
  run python3 -B -I "${d}/controlla_modello.py" "${j}"
  expect "precondizione: ticket.jsonl che manca, 2" 2 "manca"
}

t_verifica() {
  local ws
  nuovo_ws ws || { fail "verifica: prepara_esercizio.sh"; return; }
  run "${D04}/verifica.sh" "${ws}"
  expect "verifica: senza risposte/, 1" 1 "Manca la cartella risposte/"
  mkdir -p "${ws}/risposte" || exit 2
  run "${D04}/verifica.sh" "${ws}"
  expect "verifica: risposte/ vuota, 1" 1 "nessuna esecuzione"
  rifai "${ws}/risposte" haiku-1
  rifai "${ws}/risposte" sonnet-1
  rifai "${ws}/risposte" opus-1
  printf '%s\n' 'print("CONTROLLO FINTO")' \
    > "${ws}/controlla_modello.py" || exit 2
  run "${D04}/verifica.sh" "${ws}"
  expect "verifica: una tornata completa, 0, «Fatto»" 0 "${FATTO}"
  expect_absent "verifica: il controllo dell'elemento, non della copia" \
    "CONTROLLO FINTO"
  rm -r -- "${ws}/risposte/opus-1"
  run "${D04}/verifica.sh" "${ws}"
  expect "verifica: un'esecuzione che manca, 1" 1 "manca opus-1"
  run "${D04}/verifica.sh"
  expect "verifica: senza argomenti, 2" 2 "spazio di lavoro assente"
}

# --- in_classe.sh e live.sh -------------------------------------------------

t_in_classe() {
  local ws
  nuovo_ws ws || { fail "in_classe: prepara_esercizio.sh"; return; }
  finto "${D04}/demo/in_classe.sh" "${ws}" PN_ESECUZIONI=2
  expect "in_classe: due esecuzioni per modello, 0" 0 \
    "VERIFICA OK   il controllo, sulle chiamate di risposte/"
  expect "in_classe: il comando sullo schermo" 0 "--no-session-persistence"
  expect "in_classe: --json-schema sullo schermo" 0 "--json-schema"
  expect "in_classe: i tre modelli sullo schermo" 0 "--model opus"
  expect "in_classe: il confronto, sullo schermo" 0 \
    "Il costo per ticket giusto di Haiku è il più basso: confermata 2 su 2."
  vero "in_classe: il prompt composto in risposte/" \
    test -s "${ws}/risposte/prompt-composto.txt"
  controlla_chiamate "${TMP}/finto.log" "${ws}" 2
  expect "in_classe: le chiamate, le opzioni, solo il modello diverso" 0 \
    "chiamate giuste"
  run git -C "${ws}" status --porcelain
  if [[ "${OUT}" == '?? risposte/' ]]; then
    pass "in_classe: lo spazio di lavoro cambia solo in risposte/"
  else
    fail "in_classe: git status «${OUT}»"
  fi
  run env PN_HANDSON_ROOT="${RADICE}" "${D04}/verifica.sh" "${ws}"
  expect "in_classe: poi verifica.sh, 0" 0 "${FATTO}"
}

t_live() {
  local ws
  nuovo_ws ws || { fail "live: prepara_esercizio.sh"; return; }
  finto "${D04}/_docente/live.sh" "${ws}"
  expect "live: tre esecuzioni per modello, 0" 0 \
    "VERIFICA OK   verifica.sh dell'elemento"
  expect "live: il confronto, tre su tre" 0 \
    "Il costo per ticket giusto di Haiku è il più basso: confermata 3 su 3."
  controlla_chiamate "${TMP}/finto.log" "${ws}" 3
  expect "live: le nove chiamate" 0 "chiamate giuste"
  run "${RADICE}/tools/verifica.sh" M8-D04 --radice "${ws%/M8-D04}"
  expect "live: poi tools/verifica.sh, 0" 0 "VERIFICA OK   M8-D04: fatto."
  run "${D04}/_docente/live.sh"
  expect "live: senza argomenti, 2" 2 "uso:"
}

t_precondizioni() {
  local ws s="${D04}/demo/in_classe.sh" f
  nuovo_ws ws || { fail "precondizioni: prepara_esercizio.sh"; return; }
  precondizione "precondizione: una cartella che non è lo spazio" \
    "non è lo spazio di lavoro di M8-D04" "${s}" "${TMP}"
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
  for f in ticket.jsonl prompt.txt listino.json; do
    mv -- "${ws}/${f}" "${TMP}/${f}" || exit 2
    precondizione "precondizione: ${f} che manca" \
      "file assente o illeggibile: ${f}" "${s}" "${ws}"
    mv -- "${TMP}/${f}" "${ws}/${f}" || exit 2
  done
  printf '{"testo": "x", "etichetta": "guasto"}\n' > "${ws}/ticket.jsonl" \
    || exit 2
  git -C "${ws}" -c user.name=x -c user.email=x@example.org commit -qa \
    -m 'ticket rotti' || exit 2
  precondizione "precondizione: i ticket che non vanno con lo schema" \
    "non riesco a comporre" "${s}" "${ws}"
  precondizione "precondizione: senza tools/lib_handson.sh" \
    "lanciatelo dal repository, o date PN_HANDSON_ROOT" "${s}" "${ws}" \
    "${TMP}/esca:${PATH}" PN_HANDSON_ROOT="${TMP}/non-c-e"
}

t_fallita() {
  local ws
  nuovo_ws ws || { fail "fallita: prepara_esercizio.sh"; return; }
  modo "ko-modello=sonnet"
  finto "${D04}/demo/in_classe.sh" "${ws}"
  modo
  expect "fallita: la chiamata su Sonnet che fallisce, 1" 1 \
    "VERIFICA KO   sonnet-1: claude -p è fallito"
  vero "fallita: ciò che c'era è in risposte/" \
    test -s "${ws}/risposte/haiku-1/risposta.json"
  run "${D04}/verifica.sh" "${ws}"
  expect "fallita: verifica.sh dopo, 1" 1 "sonnet-1/risposta.json"
}

# Gli script di M8-D04 e questo file, con shellcheck -x.
t_shellcheck() {
  local f
  for f in "${D04}/verifica.sh" "${D04}/_docente/live.sh" \
      "${D04}/demo/in_classe.sh" "${SELF}"; do
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
      || { echo "test_m8_d04: manca ${t}" >&2; exit 2; }
  done
  [[ -f "${FINTO_PY}" ]] \
    || { echo "test_m8_d04: manca ${FINTO_PY}" >&2; exit 2; }
  handson::init_temp_base
  TMP="$(mktemp -d "${HANDSON_TEMP_BASE}/test_m8_d04.XXXXXX")" || exit 2
  trap 'chmod -R u+rwX "${TMP}" 2> /dev/null; rm -rf "${TMP}"' EXIT
  prepara_claude
  t_elemento
  t_componi
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
    echo "test_m8_d04: girati $((PASS + FAIL + SKIP)) casi, attesi" \
      "${CASES}" >&2
    exit 2
  fi
  (( FAIL == 0 )) || exit 1
}

main "$@"
