#!/bin/bash
#
# test_m8_e02.sh -- le prove di M8-E02 «Metà dei token, a parità di qualità»,
# per il docente:
#   - l'elemento: i file, i documenti identici a quelli del progetto, i casi
#     (i messaggi degli scenari, controlli e rubriche che si leggono), il
#     listino, v0 (testo sotto prova, senza tag), la v1 di riferimento nel
#     template e almeno il 50 % più corta, il giudice nel template su Haiku;
#   - il README: le dieci sezioni, le frasi di Anthropic con l'indirizzo, il
#     prompt del taglio nel template, niente identificativi interni, niente
#     «oggi», niente segnaposto rimasti;
#   - prepara_esercizio.sh e verifica.sh sul punto di partenza (1);
#   - il kit: gli errori (2, mai un traceback);
#   - misura.sh con il claude finto: quante chiamate, con quali opzioni, le
#     due versioni uguali tranne il prompt, nessuna ANTHROPIC_API_KEY, la
#     tabella, le precondizioni (2, nessuna chiamata: l'esca);
#   - verifica.py su esecuzioni fatte qui con il claude finto: ogni esito
#     (0/1/2), il 50 % stampato come dato e mai come uscita, i file rotti,
#     «confermata», «non confermata» e «non distinguibile»;
#   - _docente/live.sh con il claude finto;
#   - shellcheck -x sugli script e su questo file.
# Mai il claude vero: il finto e l'esca stanno davanti nel PATH, e la suite lo
# controlla prima di usarli. Gli spazi di lavoro nascono in una cartella
# temporanea: l'albero del repository non cambia. CASES è il numero dei casi:
# se ne girano di più o di meno la suite esce 2.
#
# Uso:    m8_costi_ottimizzazione/_docente/test_m8_e02.sh
# Uscita: 0 = tutti i casi passano · 1 = almeno un caso fallito · 2 =
#         precondizione (manca python3, git o shellcheck), o un numero di
#         casi diverso da CASES
set -uo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly MOD="${SELF%/_docente/*}"
readonly RADICE="${MOD%/*}"
readonly SUB="s6_costi_e_ottimizzazione/m8_e2_meta_dei_token"
readonly E02="${MOD}/${SUB}/M8-E02_meta_dei_token"
readonly FINTO_PY="${MOD}/_docente/claude_finto_m8_e02.py"
readonly PROGETTO="${RADICE}/progetti/assistenza-clienti"
# La libreria del repository, per la base dei file temporanei.
# shellcheck source=../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"
readonly CASES=150
readonly DIMO='una dimostrazione'
readonly FATTO='Fatto: almeno una versione dopo v0'
TMP=''
BASE=''
PASS=0
FAIL=0
RC=0
OUT=''
TUTTO=''

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

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
  "${RADICE}/tools/prepara_esercizio.sh" M8-E02 --radice "${__r}" \
    > "${TMP}/prepara.log" 2>&1 || return 1
  printf -v "$1" '%s' "${__r}/M8-E02"
}

# Copia della base già misurata (BASE: v0 e la v1 di riferimento, misurate una
# volta sola all'inizio), per non rifare le misure a ogni prova.
# Arguments: $1 la variabile da assegnare.
copia_base() {
  local __r
  __r="$(mktemp -d "${TMP}/copia.XXXXXX")" || exit 2
  cp -a "${BASE}" "${__r}/M8-E02" || exit 2
  printf -v "$1" '%s' "${__r}/M8-E02"
}

# Sceglie come si comporta il claude finto. Arguments: le parole di FINTO_MODI.
modo() { printf '%s' "$*" > "${TMP}/modi"; }

# L'esca (registra ogni invocazione ed esce 0), il claude finto (un involucro
# che legge i modi da un file) e i PATH ridotti. Esce 2 se nel PATH di prova
# claude non è il finto.
prepara_claude() {
  local t
  mkdir -p "${TMP}/esca" "${TMP}/finto" "${TMP}/senza_claude" \
    "${TMP}/senza_python" "${TMP}/casa" || exit 2
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
  for t in readlink python3 git env sed cat rm mkdir cp; do
    ln -s "$(command -v "${t}")" "${TMP}/senza_claude/${t}" || exit 2
  done
  for t in readlink git env sed cat rm mkdir cp; do
    ln -s "$(command -v "${t}")" "${TMP}/senza_python/${t}" || exit 2
  done
  ln -s "${TMP}/esca/claude" "${TMP}/senza_python/claude" || exit 2
  t="$(PATH="${TMP}/finto:${PATH}" command -v claude)"
  if [[ "${t}" != "${TMP}/finto/claude" ]]; then
    echo "test_m8_e02: nel PATH di prova claude è ${t}, non il finto" >&2
    exit 2
  fi
  modo
}

# Lo script con il finto davanti nel PATH e ANTHROPIC_API_KEY e
# CLAUDE_CODE_EFFORT_LEVEL impostate (lo script le deve togliere); il registro
# riparte vuoto. Arguments: i NOME=valore e il comando.
finto() {
  : > "${TMP}/finto.log"
  run env -u CLAUDE_CONFIG_DIR PATH="${TMP}/finto:${PATH}" \
    HOME="${TMP}/casa" HANDSON_NO_PAUSE=1 ANTHROPIC_API_KEY=valore-finto \
    CLAUDE_CODE_EFFORT_LEVEL=high TMPDIR="${TMP}" "$@"
}

# La misura di una versione con il finto, dallo spazio di lavoro.
# Arguments: $1 lo spazio di lavoro, $2 la versione, poi le opzioni di misura.sh.
misura_v() {
  local w="$1"
  shift
  ( cd "${w}" || exit 2
    env -u CLAUDE_CONFIG_DIR PATH="${TMP}/finto:${PATH}" HOME="${TMP}/casa" \
      HANDSON_NO_PAUSE=1 ANTHROPIC_API_KEY=valore-finto \
      CLAUDE_CODE_EFFORT_LEVEL=high ./misura.sh "$@" ) 2>&1
}

# misura.sh con l'esca davanti nel PATH (o con un PATH dato), dallo spazio di
# lavoro; il registro riparte vuoto. Arguments: $1 il PATH (vuoto per l'esca),
# $2 lo spazio di lavoro, poi gli argomenti di misura.sh.
esca() {
  local percorso="${1:-${TMP}/esca:${PATH}}" w="$2"
  shift 2
  : > "${TMP}/esca.log"
  run env PATH="${percorso}" ESCA_LOG="${TMP}/esca.log" "${w}/misura.sh" "$@"
}

# Una precondizione di misura.sh: uscita 2, la parola attesa, nessuna chiamata.
# Arguments: $1 il nome, $2 la parola, poi come esca.
precondizione() {
  local nome="$1" parola="$2" n
  shift 2
  esca "$@"
  expect "${nome}" 2 "${parola}"
  n="$(grep -c -- 'invocazione' "${TMP}/esca.log")"
  if (( n == 0 )); then
    pass "${nome}: nessuna chiamata al modello"
  else
    fail "${nome}: ${n} chiamate"
  fi
}

# Cambia un campo di un file JSON (un percorso con i punti, come usage.x; il
# valore in JSON). Arguments: $1 il file, $2 il campo, $3 il valore.
json_cambia() {
  python3 -B -I - "$1" "$2" "$3" <<'PY_CAMBIA' || exit 2
import json, sys
f, campo, val = sys.argv[1:4]
d = json.load(open(f, encoding="utf-8"))
nodo = d
pezzi = campo.split(".")
for p in pezzi[:-1]:
    nodo = nodo[p]
nodo[pezzi[-1]] = json.loads(val)
json.dump(d, open(f, "w", encoding="utf-8"), ensure_ascii=False)
PY_CAMBIA
}

# verifica.sh dell'elemento su uno spazio di lavoro.
verifica() { run "${E02}/verifica.sh" "$@"; }

# Cambia un JSON di una misura con un'istruzione Python sul dizionario «d».
# Arguments: $1 il file, $2 l'istruzione.
modifica_json() {
  python3 -B -I -c 'import json, sys
p = sys.argv[1]
d = json.load(open(p, encoding="utf-8"))
exec(sys.argv[2])
json.dump(d, open(p, "w", encoding="utf-8"), ensure_ascii=False)' "$1" "$2"
}

# Le chiamate di un registro del finto, contro le attese: quante, in che
# ordine, con quali opzioni, senza chiave né effort nell'ambiente, STDIN da
# /dev/null; le due versioni uguali tranne il prompt.
# Arguments: $1 il registro, $2 lo spazio di lavoro, $3 quante versioni (1 o 2).
controlla_chiamate() {
  run python3 -B -I - "$1" "$2" "$3" <<'PY'
import json, sys
log, ws, n = sys.argv[1:4]
n = int(n)
chiamate = [json.loads(r) for r in open(log, encoding="utf-8")]
VALORE = {"--model", "--effort", "--output-format", "--setting-sources",
          "--permission-mode", "--permission-prompts", "--tools",
          "--system-prompt", "--agent", "--json-schema"}
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
attese = 6 * n
if len(chiamate) != attese:
    problemi.append("%d chiamate invece di %d" % (len(chiamate), attese))
comuni = (("--setting-sources", "project,local"),
          ("--permission-mode", "dontAsk"), ("--permission-prompts", "none"),
          ("--output-format", "json"))
risposte, giudizi = [], []
for i, c in enumerate(chiamate):
    o, resto = opzioni(c)
    for k, v in comuni:
        if o.get(k) != v:
            problemi.append("chiamata %d: %s" % (i, k))
    for k in ("-p", "--strict-mcp-config", "--no-session-persistence"):
        if o.get(k) is not True:
            problemi.append("chiamata %d: %s" % (i, k))
    if o.get("--tools") != "" or len(resto) != 1:
        problemi.append("chiamata %d: --tools o il prompt" % i)
    if any("dangerously" in a or "bypassPermissions" in a for a in c["argv"]):
        problemi.append("chiamata %d: salta i permessi" % i)
    if c["chiave"] or c["effort"]:
        problemi.append("chiamata %d: ANTHROPIC_API_KEY o EFFORT" % i)
    if not c["stdin_nullo"]:
        problemi.append("chiamata %d: STDIN non è /dev/null" % i)
    if o.get("--agent") == "giudice":
        giudizi.append(c)
        if o.get("--effort") != "low" or "--json-schema" not in o \
                or "--model" in o:
            problemi.append("giudice %d: opzioni" % i)
        if "<rubric>" not in resto[0] or "<answer>" not in resto[0]:
            problemi.append("giudice %d: la consegna" % i)
    else:
        risposte.append(c)
        if o.get("--model") != "sonnet" or o.get("--effort") != "low" \
                or o.get("--system-prompt") != "Rispondi in italiano.":
            problemi.append("risposta %d: opzioni" % i)
# Le chiamate alternate: risposta, giudizio, risposta, giudizio, ...
ordine = ["R" if "--agent" not in c["argv"] else "G" for c in chiamate]
if ordine != ["R", "G"] * (attese // 2):
    problemi.append("ordine delle chiamate: %s" % "".join(ordine))
# Le due versioni: le opzioni identiche, il prompt diverso.
if n == 2:
    a, b = risposte[:3], risposte[3:]
    for x, y in zip(a, b):
        ox, rx = opzioni(x)
        oy, ry = opzioni(y)
        if ox != oy:
            problemi.append("le versioni differiscono in un'opzione")
        if rx == ry:
            problemi.append("le due versioni hanno lo stesso prompt")
print("; ".join(problemi) or "chiamate giuste")
PY
}

# --- L'elemento -------------------------------------------------------------

t_elemento() {
  local f
  for f in README.md verifica.sh verifica.py _docente/live.sh \
      esercizio/misura.sh esercizio/strumenti/kit.py \
      esercizio/schema-giudizio.json esercizio/listino.json \
      esercizio/.claude/agents/giudice.md esercizio/.claude/settings.json \
      esercizio/prompt/v0.md esercizio/documenti/tono.md \
      esercizio/documenti/procedure.md soluzione/prompt/v1.md \
      soluzione/LEGGIMI.md; do
    vero "elemento: ${f}" test -f "${E02}/${f}"
  done
  for f in verifica.sh _docente/live.sh esercizio/misura.sh; do
    vero "elemento: ${f} eseguibile" test -x "${E02}/${f}"
  done
  vero "documenti: tono.md identico alla guida del progetto" \
    cmp -s "${E02}/esercizio/documenti/tono.md" "${PROGETTO}/tono-di-voce.md"
  { cat "${PROGETTO}/kb/kb-11-guasti-collettivi-e-manutenzioni.md"
    printf '\n'
    cat "${PROGETTO}/kb/kb-04-radio-antenna-e-meteo.md"; } \
    > "${TMP}/procedure_attese.md" || exit 2
  vero "documenti: procedure.md è KB-11 e KB-04 del progetto" \
    cmp -s "${E02}/esercizio/documenti/procedure.md" \
    "${TMP}/procedure_attese.md"
  run python3 -B -I - "${E02}" "${PROGETTO}" <<'PY'
import json, os, re, sys
item, progetto = sys.argv[1:3]
leggi = lambda p: open(os.path.join(item, p), encoding="utf-8").read()
problemi = []
# I casi: i messaggi come negli scenari, i file che servono.
sc = {"caso-1": "sc-01-fibra-assente-guasto-pergine.json",
      "caso-2": "sc-02-rifugio-radio-intermittente.json",
      "caso-3": "sc-03-navigazione-a-singhiozzo.json"}
for caso, nome in sc.items():
    d = json.load(open(os.path.join(progetto, "scenari", nome),
                       encoding="utf-8"))
    m = leggi("esercizio/casi/%s/messaggio.md" % caso).strip("\n")
    if m != d["messaggio_iniziale"]:
        problemi.append("%s: il messaggio non è quello dello scenario" % caso)
    for f in ("stato.md", "controlli.tsv", "rubrica.md"):
        if not os.path.isfile(os.path.join(item, "esercizio/casi", caso, f)):
            problemi.append("%s: manca %s" % (caso, f))
    st = leggi("esercizio/casi/%s/stato.md" % caso)
    if "TK-2026-0" not in st or "Canale della risposta" not in st:
        problemi.append("%s: stato.md senza segnalazione o canale" % caso)
    righe = leggi("esercizio/casi/%s/controlli.tsv" % caso).splitlines()
    if righe[0] != "tipo\tvalore\tdescrizione" or len(righe) < 5:
        problemi.append("%s: controlli.tsv" % caso)
    r = leggi("esercizio/casi/%s/rubrica.md" % caso)
    aff = re.findall(r"(?m)^- \*\*([a-z_]+)\*\*: ", r)
    if not 3 <= len(aff) <= 5:
        problemi.append("%s: da tre a cinque affermazioni, sono %d"
                        % (caso, len(aff)))
# v0: testo sotto prova, senza tag del template, con i quattro segnaposto.
v0 = leggi("esercizio/prompt/v0.md")
for s in ("{{tono}}", "{{procedure}}", "{{messaggio}}", "{{stato}}"):
    if s not in v0:
        problemi.append("v0: manca %s" % s)
if "<role>" in v0 or "<instructions>" in v0:
    problemi.append("v0 ha i tag del template")
for parola in ("Chi siamo", "Il formato della risposta", "Alcuni esempi"):
    if parola not in v0:
        problemi.append("v0: manca la sezione %s" % parola)
# La v1 di riferimento: il template, i segnaposto dei casi, più corta.
v1 = leggi("soluzione/prompt/v1.md")
for tag in ("role", "context", "instructions", "format", "constraints"):
    if not (re.search(r"(?m)^<%s>$" % tag, v1)
            and re.search(r"(?m)^</%s>$" % tag, v1)):
        problemi.append("v1: il tag %s" % tag)
if not re.search(r"(?m)^<role>\nSei ", v1):
    problemi.append("v1: il ruolo non comincia con «Sei»")
for s in ("{{messaggio}}", "{{stato}}"):
    if s not in v1:
        problemi.append("v1: manca %s" % s)
if "{{tono}}" in v1 or "{{procedure}}" in v1:
    problemi.append("v1: ha ancora i documenti interi")
if len(v1.encode()) > len(v0.encode()) * 0.8:
    problemi.append("v1 non è più corta di v0")
# Il giudice: nel template, su Haiku; il listino, come il brief lo vuole.
g = leggi("esercizio/.claude/agents/giudice.md")
if not re.search(r"(?m)^model: haiku$", g):
    problemi.append("giudice: model")
for tag in ("role", "context", "instructions", "format", "constraints"):
    if not re.search(r"(?m)^<%s>$" % tag, g):
        problemi.append("giudice: il tag %s" % tag)
listino = json.loads(leggi("esercizio/listino.json"))["modelli"]
atteso = {"haiku": (0.10, 0.50, 0.125, 0.20, 0.01),
          "sonnet": (2, 10, 2.5, 4, 0.10), "opus": (4, 20, 5, 8, 0.20)}
for alias, (i, o, w5, w1, r) in atteso.items():
    voce = listino[alias]
    if (voce["input"], voce["output"], voce["cache_write_5m"],
            voce["cache_write_1h"], voce["cache_read"]) != (i, o, w5, w1, r):
        problemi.append("listino: %s" % alias)
print("; ".join(problemi) or "elemento a posto")
PY
  expect "i casi, v0, la v1 di riferimento, il giudice, il listino" 0 \
    "elemento a posto"
  run python3 -B -I - "${E02}" <<'PY'
import os, sys
item = sys.argv[1]
problemi = []
# Nei file dei partecipanti niente identificativi interni della pianificazione.
for radice, _, nomi in os.walk(os.path.join(item, "esercizio")):
    if ".git" in radice:
        continue
    for nome in nomi:
        if nome.endswith((".pyc",)):
            continue
        testo = open(os.path.join(radice, nome), encoding="utf-8").read()
        for parola in ("FACT-", "M8-X", "X-3", "TODO"):
            if parola in testo:
                problemi.append("%s: «%s»" % (nome, parola))
print("; ".join(problemi) or "nessun identificativo interno")
PY
  expect "esercizio/: niente identificativi interni" 0 \
    "nessun identificativo interno"
}

# Il README: le dieci sezioni, le frasi di Anthropic; niente identificativi
# interni, giornate, «smentita», segnaposto rimasti.
t_readme() {
  run python3 -B -I - "${E02}" <<'PY'
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
for titolo in ("## Punto di partenza (tools/prepara_esercizio.sh M8-E02)",
               "## Verifica (tools/verifica.sh M8-E02)"):
    if titolo not in readme:
        problemi.append("il titolo «%s»" % titolo)
PAGINA = "https://platform.claude.com/docs/en/about-claude/models/" \
    "optimizing-for-cost-and-intelligence"
CE = "https://www.anthropic.com/research/effective-context-engineering-for-ai-agents"
frasi = [
    ("Most agent requests carry tokens that never influence the answer.",
     PAGINA),
    ("Trimming them rarely costs output quality, although not every lever "
     "here saved money when measured.", PAGINA),
    ("you should be striving for the minimal set of information that fully "
     "outlines your expected behavior.", CE),
    ("Note that minimal does not necessarily mean short", CE),
    ("Total input tokens in a request is the summation of input_tokens, "
     "cache_creation_input_tokens, and cache_read_input_tokens.",
     "https://platform.claude.com/docs/en/api/messages/create"),
    ("Price each of the five token counts in a response’s usage at its own "
     "rate", PAGINA),
    ("Both figures are client-side estimates and can differ from your actual "
     "bill.", "https://code.claude.com/docs/en/headless"),
    ("it should not be the model you are testing",
     "https://claude.dev/blog/automating-eval-design-and-hillclimbing/"),
    ("Get validated JSON output matching a JSON Schema after the agent "
     "completes its workflow (print mode only).",
     "https://code.claude.com/docs/en/cli-reference"),
    ("Run shell commands directly without going through Claude by prefixing "
     "your input with !", "https://code.claude.com/docs/en/interactive-mode"),
]
piano = " ".join(readme.split())
for frase, url in frasi:
    if frase not in piano:
        problemi.append("manca «%s»" % frase[:40])
    if url not in readme:
        problemi.append("manca %s" % url)
for vietata in ("smentit", "FACT-", "M8-X", "X-3", "/home/", "@@FIGURE",
                "DA MISURARE"):
    if vietata in readme:
        problemi.append("«%s»" % vietata)
for parola in ("oggi", "domani", "pausa", "pranzo"):
    if re.search(r"\b%s\b" % parola, readme):
        problemi.append("«%s»" % parola)
# Il prompt del taglio, nel template, con i marcatori.
m = re.search(r"<!-- prompt taglio -->\n(.*?)<!-- /prompt taglio -->", readme,
              re.S)
if not m:
    problemi.append("il blocco del prompt taglio")
else:
    corpo = "\n".join(r[7:] if r.startswith("       ") else r
                      for r in m.group(1).splitlines())
    for tag in ("role", "context", "instructions", "format", "constraints"):
        if not re.search(r"(?m)^<%s>$" % tag, corpo):
            problemi.append("taglio: il tag %s" % tag)
    if not re.search(r"(?m)^<role>\nSei ", corpo):
        problemi.append("taglio: il ruolo")
    if len(corpo.split()) < 60:
        problemi.append("taglio: troppo corto")
    if "prompt/v1.md" not in corpo or "{{messaggio}}" not in corpo:
        problemi.append("taglio: i file e i segnaposto")
print("; ".join(problemi) or "README a posto")
PY
  expect "README: sezioni, frasi con l'indirizzo, il prompt del taglio" 0 \
    "README a posto"
}

t_prepara() {
  local ws f
  if ! nuovo_ws ws; then
    fail "prepara_esercizio.sh M8-E02: $(tail -n 3 "${TMP}/prepara.log")"
    return
  fi
  pass "prepara_esercizio.sh M8-E02"
  for f in misura.sh prompt/v0.md documenti/tono.md documenti/procedure.md \
      casi/caso-1/messaggio.md casi/caso-3/rubrica.md strumenti/kit.py \
      schema-giudizio.json listino.json .claude/agents/giudice.md \
      .claude/settings.json; do
    vero "spazio di lavoro: ${f}" test -f "${ws}/${f}"
  done
  vero "spazio di lavoro: misura.sh eseguibile" test -x "${ws}/misura.sh"
  if [[ ! -e "${ws}/soluzione" && ! -e "${ws}/_docente" ]]; then
    pass "spazio di lavoro: niente soluzione/ né _docente/"
  else
    fail "spazio di lavoro: soluzione/ o _docente/"
  fi
  run "${RADICE}/tools/verifica.sh" M8-E02 --radice "${ws%/M8-E02}"
  expect "verifica.sh sul punto di partenza: 1" 1 "v0 non è misurata"
  expect_absent "punto di partenza: nessun «Fatto»" "${FATTO}"
}

# --- Il kit -----------------------------------------------------------------

t_kit() {
  local ws
  nuovo_ws ws || { fail "kit: prepara_esercizio.sh"; return; }
  run bash -c "cd '${ws}' && python3 -B strumenti/kit.py componi caso-1 v0"
  expect "kit: compone v0 con il messaggio" 0 \
    "da poco dopo le dieci non ho più internet"
  expect "kit: compone v0 con la guida al tono" 0 "Il tono di voce"
  expect "kit: compone v0 con le procedure" 0 "KB-11"
  expect_absent "kit: nessun segnaposto rimasto" "{{"
  run bash -c "cd '${ws}' && python3 -B strumenti/kit.py componi caso-9 v0"
  expect "kit: un caso sconosciuto, 2" 2 "sconosciuto"
  run bash -c "cd '${ws}' && python3 -B strumenti/kit.py componi caso-1 V1"
  expect "kit: una versione mal scritta, 2" 2 "non valida"
  run bash -c "cd '${ws}' && python3 -B strumenti/kit.py componi caso-1 v7"
  expect "kit: un prompt che manca, 2" 2 "manca il file"
  printf 'Rispondi al cliente.\n' > "${ws}/prompt/v8.md" || exit 2
  run bash -c "cd '${ws}' && python3 -B strumenti/kit.py componi caso-1 v8"
  expect "kit: un prompt senza i dati del caso, 2" 2 "non contiene {{messaggio}}"
  printf '{{messaggio}} {{stato}} {{inesistente}}\n' \
    > "${ws}/prompt/v9.md" || exit 2
  run bash -c "cd '${ws}' && python3 -B strumenti/kit.py componi caso-2 v9"
  expect "kit: un segnaposto che non c'è, 2" 2 "{{inesistente}}"
  run bash -c "cd '${ws}' && python3 -B strumenti/kit.py riepilogo v5"
  expect "kit: il riepilogo di una versione non misurata, 2" 2 "incompleta"
  run bash -c "cd '${ws}' && python3 -B strumenti/kit.py sconosciuto"
  expect "kit: un comando sconosciuto, 2" 2 "gli attrezzi"
  printf 'non è json\n' > "${ws}/listino.json" || exit 2
  mkdir -p "${ws}/risposte/v3" || exit 2
  printf 'modello\tsonnet\neffort\tlow\n' > "${ws}/risposte/v3/opzioni.tsv"
  run bash -c "cd '${ws}' && python3 -B strumenti/kit.py riepilogo v3"
  expect "kit: un listino illeggibile, 2" 2 "non è un JSON valido"
}

# --- misura.sh --------------------------------------------------------------

t_misura() {
  local ws
  nuovo_ws ws || { fail "misura: prepara_esercizio.sh"; return; }
  finto bash -c "cd '${ws}' && ./misura.sh v0"
  expect "misura v0: esce 0, la tabella" 0 "Riepilogo di v0"
  expect "misura v0: il totale" 0 "totale"
  expect "misura v0: le colonne" 0 "token in"
  expect "misura v0: il comando di claude sullo schermo" 0 \
    '--system-prompt "Rispondi in italiano."'
  expect "misura v0: il giudice sullo schermo" 0 "--agent giudice"
  expect "misura v0: costo e total_cost_usd coincidono (un dato)" 0 \
    "differenza 0,0000"
  controlla_chiamate "${TMP}/finto.log" "${ws}" 1
  expect "misura v0: le sei chiamate, le opzioni, l'ambiente" 0 \
    "chiamate giuste"
  vero "misura v0: le tre risposte" \
    test -s "${ws}/risposte/v0/caso-3.json"
  vero "misura v0: i tre giudizi" \
    test -s "${ws}/giudizi/v0/caso-2.json"
  vero "misura v0: i controlli da leggere" \
    test -s "${ws}/controlli/v0/caso-1.txt"
  vero "misura v0: le opzioni della versione" \
    test -s "${ws}/risposte/v0/opzioni.tsv"
  run python3 -B -I - "${TMP}/finto.log" "${ws}" <<'PY'
import json, sys, os
log, ws = sys.argv[1:3]
c = [json.loads(r) for r in open(log, encoding="utf-8")]
tono = open(os.path.join(ws, "documenti/tono.md"), encoding="utf-8").read().strip()
problemi = []
if tono[:200] not in c[0]["prompt"]:
    problemi.append("il prompt di v0 non porta la guida al tono")
if "Rifugio Campione" not in c[2]["prompt"]:
    problemi.append("il secondo caso")
if "<rubric>" not in c[1]["prompt"] or "stato" in c[1]["prompt"].split("<rubric>")[0]:
    problemi.append("la consegna al giudice")
print("; ".join(problemi) or "prompt giusti")
PY
  expect "misura v0: il prompt composto e la consegna al giudice" 0 \
    "prompt giusti"
  # La v1 di riferimento e il confronto.
  cp -- "${E02}/soluzione/prompt/v1.md" "${ws}/prompt/v1.md" || exit 2
  finto bash -c "cd '${ws}' && ./misura.sh v1"
  expect "misura v1: la tabella" 0 "Riepilogo di v1"
  finto bash -c "cd '${ws}' && ./misura.sh v1"
  run python3 -B -I -c 'import sys, json
print("chiamate=%d" % len([1 for r in open(sys.argv[1], encoding="utf-8")]))' \
    "${TMP}/finto.log"
  expect "misura v1 rilanciata: sei chiamate, i file nuovi" 0 "chiamate=6"
  finto bash -c "cd '${ws}' && ./misura.sh --confronta v0 v1"
  expect "confronta: riduzione" 0 "riduzione dei token in entrata, v0 → v1:"
  expect "confronta: la riga dell'obiettivo, un dato" 0 \
    "obiettivo del laboratorio: almeno il 50 % in meno"
  expect_absent "confronta: nessun verdetto sull'obiettivo" "non ancora"
  # Una prova vuota della riduzione: un v2 lungo come v0 meno le procedure.
  sed 's/{{procedure}}//' "${ws}/prompt/v0.md" > "${ws}/prompt/v2.md" || exit 2
  misura_v "${ws}" v2 > /dev/null || { fail "misura di v2"; return; }
  finto bash -c "cd '${ws}' && ./misura.sh --confronta v0 v2"
  expect "confronta: sotto il 50 %, un dato, esce 0" 0 \
    "almeno il 50 % in meno"
  finto bash -c "cd '${ws}' && ./misura.sh --confronta v0"
  expect "confronta: un argomento solo, 2" 2 "uso:"
  finto bash -c "cd '${ws}' && ./misura.sh --confronta v0 v7"
  expect "confronta: una versione non misurata, 2" 2 "incompleta"
}

t_precondizioni() {
  local ws
  nuovo_ws ws || { fail "precondizioni: prepara_esercizio.sh"; return; }
  precondizione "precondizione: nessuna versione" "uso:" "" "${ws}"
  precondizione "precondizione: una versione mal scritta" "non valida" "" \
    "${ws}" V1
  precondizione "precondizione: un prompt che non c'è" "manca prompt/v3.md" \
    "" "${ws}" v3
  precondizione "precondizione: un modello sconosciuto" "modello" "" "${ws}" \
    v0 --modello gpt
  precondizione "precondizione: un effort sconosciuto" "effort" "" "${ws}" \
    v0 --effort altissimo
  precondizione "precondizione: un'opzione sconosciuta" "opzione sconosciuta" \
    "" "${ws}" v0 --boh
  precondizione "precondizione: senza claude" "manca claude" \
    "${TMP}/senza_claude" "${ws}" v0
  precondizione "precondizione: senza python3" "manca python3" \
    "${TMP}/senza_python" "${ws}" v0
  run "${E02}/esercizio/misura.sh" --aiuto
  expect "precondizione: un'opzione sconosciuta, dal repository" 2 \
    "opzione sconosciuta"
}

t_fallita() {
  local ws
  nuovo_ws ws || { fail "fallita: prepara_esercizio.sh"; return; }
  modo "ko-se=Rifugio"
  finto bash -c "cd '${ws}' && ./misura.sh v0"
  modo
  expect "fallita: una chiamata che fallisce, 1" 1 \
    "la risposta di v0 a caso-2 non è arrivata"
  vero "fallita: il caso prima c'è" test -s "${ws}/giudizi/v0/caso-1.json"
  verifica "${ws}"
  expect "fallita: la verifica dice che la misura è incompleta, 1" 1 \
    "incompleta"
  nuovo_ws ws || { fail "fallita: prepara_esercizio.sh"; return; }
  modo errore-risposta
  finto bash -c "cd '${ws}' && ./misura.sh v0"
  modo
  expect "fallita: una risposta con is_error ferma la misura, 1" 1 \
    "contiene un errore"
  nuovo_ws ws || { fail "fallita: prepara_esercizio.sh"; return; }
  modo errore-giudice
  finto bash -c "cd '${ws}' && ./misura.sh v0"
  modo
  expect "fallita: un giudice con is_error ferma la misura, 1" 1 \
    "contiene un errore"
}

# --- verifica.sh ------------------------------------------------------------

t_verifica_esiti() {
  local ws
  copia_base ws
  verifica "${ws}"
  expect "verifica: una versione ridotta e non peggiore, 0, Fatto" 0 "${FATTO}"
  expect "verifica: la riduzione, un dato" 0 \
    "riduzione dei token in entrata, v0 → v1"
  expect "verifica: il 50 %, un dato" 0 "almeno il 50 % in meno"
  expect "verifica: le frasi senza esito, una dimostrazione" 0 "${DIMO}"
  expect "verifica: la garanzia dello schema" 0 \
    "conforme allo schema (--json-schema), 6 su 6: confermata"
  expect "verifica: la frase di Anthropic stampata" 0 \
    "Most agent requests carry tokens that never influence the answer."
  expect_absent "verifica: nessun esito sulle frasi" "confermata in questa"
  # Una v1 peggiore nei controlli: non passa.
  copia_base ws
  modo corto-no-controlli
  misura_v "${ws}" v1 > /dev/null || fail "misura v1 corto-no-controlli"
  modo
  verifica "${ws}"
  expect "verifica: controlli peggiori: non passa, 1" 1 "è peggiore di v0"
  expect "verifica: controlli peggiori, ma riduzione stampata" 1 \
    "riduzione dei token in entrata"
  # Una v1 peggiore nel giudice: non passa.
  copia_base ws
  modo corto-no-giudice
  misura_v "${ws}" v1 > /dev/null || fail "misura v1 corto-no-giudice"
  modo
  verifica "${ws}"
  expect "verifica: giudice peggiore: non passa, 1" 1 "è peggiore di v0"
  # v1 peggiore e v2 buona: passa (almeno una).
  cp -- "${ws}/prompt/v1.md" "${ws}/prompt/v2.md" || exit 2
  printf '\nRisposta in italiano.\n' >> "${ws}/prompt/v2.md" || exit 2
  misura_v "${ws}" v2 > /dev/null || fail "misura v2"
  verifica "${ws}"
  expect "verifica: v1 peggiore ma v2 buona, 0" 0 "${FATTO}"
  # Una v1 più lunga di v0, non peggiore: non passa, non ha tolto token; il
  # 50 % resta un dato.
  copia_base ws
  cp -- "${ws}/prompt/v0.md" "${ws}/prompt/v1.md" || exit 2
  printf '\nUna riga in più, senza un motivo.\n' >> "${ws}/prompt/v1.md" \
    || exit 2
  misura_v "${ws}" v1 > /dev/null || fail "misura v1 più lunga"
  verifica "${ws}"
  expect "verifica: v1 più lunga, 1" 1 "non pesa meno token in entrata di v0"
  expect "verifica: v1 più lunga, il 50 % un dato" 1 "almeno il 50 % in meno"
  # v1 uguale a v0: non è una versione.
  copia_base ws
  cp -- "${ws}/prompt/v0.md" "${ws}/prompt/v1.md" || exit 2
  misura_v "${ws}" v1 > /dev/null || fail "misura v1 uguale"
  verifica "${ws}"
  expect "verifica: v1 uguale a v0, 1" 1 "uguale a prompt/v0.md"
  # Un altro modello per v1: non si confronta.
  copia_base ws
  misura_v "${ws}" v1 --modello haiku > /dev/null || fail "misura v1 haiku"
  verifica "${ws}"
  expect "verifica: un altro modello, 1" 1 "vengono da"
  # Il prompt cambiato dopo la misura.
  copia_base ws
  printf '\nUna riga aggiunta dopo la misura.\n' >> "${ws}/prompt/v1.md" \
    || exit 2
  verifica "${ws}"
  expect "verifica: il prompt cambiato dopo la misura, 1" 1 \
    "non sono quelli misurati"
  # La misura di v0 fatta su un altro prompt, e v0 rimesso com'era.
  copia_base ws
  cp -- "${ws}/prompt/v0.md" "${TMP}/v0.orig" || exit 2
  printf '\nUna riga in più per la base.\n' >> "${ws}/prompt/v0.md" || exit 2
  misura_v "${ws}" v0 > /dev/null || fail "misura v0 con la riga in più"
  cp -- "${TMP}/v0.orig" "${ws}/prompt/v0.md" || exit 2
  verifica "${ws}"
  expect "verifica: v0 misurata su un altro prompt, 1" 1 \
    "non sono quelli misurati"
  # Una risposta senza usage non vale zero token.
  copia_base ws
  modifica_json "${ws}/risposte/v1/caso-1.json" 'd.pop("usage", None)'
  verifica "${ws}"
  expect "verifica: una risposta senza usage, 1" 1 "manca il campo usage"
  # Un giudizio che non ha giudicato niente.
  copia_base ws
  modifica_json "${ws}/giudizi/v1/caso-1.json" \
    'd["structured_output"]["criteri"] = []'
  verifica "${ws}"
  expect "verifica: un giudizio senza esiti, 1" 1 "non dà un esito per"
  # Le risposte di v1 su un altro modello, le opzioni uguali.
  copia_base ws
  modifica_json "${ws}/risposte/v1/caso-1.json" \
    'd["modelUsage"] = {"claude-haiku-5-5": {}}'
  verifica "${ws}"
  expect "verifica: le risposte su un altro modello, 1" 1 "vengono da"
  # --confronta avvisa di un prompt cambiato dopo la misura.
  copia_base ws
  printf '\nUna riga aggiunta dopo la misura.\n' >> "${ws}/prompt/v1.md" \
    || exit 2
  finto bash -c "cd '${ws}' && ./misura.sh --confronta v0 v1"
  expect "confronta: l'avviso, i file cambiati dopo la misura" 0 \
    "attenzione: i file di v1"
  # Il punto di partenza cambiato.
  copia_base ws
  printf 'x\n' >> "${ws}/casi/caso-1/rubrica.md" || exit 2
  verifica "${ws}"
  expect "verifica: una rubrica cambiata, 1" 1 "è cambiato: il punto di partenza"
  copia_base ws
  printf '\nAggiunta.\n' >> "${ws}/prompt/v0.md" || exit 2
  verifica "${ws}"
  expect "verifica: v0 cambiato, 1" 1 "prompt/v0.md è cambiato"
  copia_base ws
  rm -- "${ws}/casi/caso-2/stato.md" || exit 2
  verifica "${ws}"
  expect "verifica: un file del punto di partenza che manca, 1" 1 \
    "manca casi/caso-2/stato.md"
  # Niente versione dopo v0.
  copia_base ws
  rm -r -- "${ws}/risposte/v1" "${ws}/giudizi/v1" || exit 2
  verifica "${ws}"
  expect "verifica: solo v0, 1" 1 "serve almeno una versione dopo v0"
}

t_verifica_rotti() {
  local ws
  # Una versione incompleta o rotta: 1, con il perché, mai un traceback.
  copia_base ws
  rm -- "${ws}/giudizi/v1/caso-2.json" || exit 2
  verifica "${ws}"
  expect "rotti: un giudizio che manca, 1" 1 "incompleta"
  copia_base ws
  rm -- "${ws}/risposte/v1/opzioni.tsv" || exit 2
  verifica "${ws}"
  expect "rotti: le opzioni che mancano, 1" 1 "incompleta"
  copia_base ws
  printf 'non è json\n' > "${ws}/risposte/v1/caso-1.json" || exit 2
  verifica "${ws}"
  expect "rotti: un JSON della risposta non valido, 1" 1 "non è un JSON valido"
  copia_base ws
  printf '{"type": "altro"}\n' > "${ws}/risposte/v1/caso-1.json" || exit 2
  verifica "${ws}"
  expect "rotti: non è il JSON di claude -p, 1" 1 "non è il JSON di claude -p"
  copia_base ws
  json_cambia "${ws}/risposte/v1/caso-1.json" is_error true
  verifica "${ws}"
  expect "rotti: una risposta con is_error, 1" 1 "contiene un errore"
  copia_base ws
  json_cambia "${ws}/risposte/v1/caso-1.json" usage.input_tokens '"boh"'
  verifica "${ws}"
  expect "rotti: un usage non numerico, 1" 1 "non è un numero"
  copia_base ws
  modo senza-structured
  misura_v "${ws}" v1 > /dev/null
  modo
  verifica "${ws}"
  expect "rotti: un giudizio senza structured_output, 1" 1 \
    "non contiene il giudizio strutturato"
  copia_base ws
  modo fuori-schema
  misura_v "${ws}" v1 > /dev/null
  modo
  verifica "${ws}"
  expect "rotti: un giudizio fuori schema, la garanzia, 1" 1 \
    "in questa esecuzione no"
  copia_base ws
  chmod 000 "${ws}/risposte/v1/caso-1.json" || exit 2
  verifica "${ws}"
  expect "rotti: un file che non si legge, 2" 2 "non si legge"
  chmod 644 "${ws}/risposte/v1/caso-1.json" || exit 2
  # Gli usi sbagliati.
  verifica "${TMP}/non-c-e"
  expect "uso: uno spazio di lavoro che non c'è, 2" 2 "spazio di lavoro assente"
  verifica
  expect "uso: senza argomenti, 2" 2 "spazio di lavoro assente"
  local d
  d="$(mktemp -d "${TMP}/vuota.XXXXXX")" || exit 2
  cp -- "${E02}/verifica.py" "${d}/verifica.py" || exit 2
  run python3 -B -I "${d}/verifica.py" "${BASE}"
  expect "precondizione: il kit che manca, 2" 2 "manca"
}

# --- live.sh ----------------------------------------------------------------

t_live() {
  local ws
  nuovo_ws ws || { fail "live: prepara_esercizio.sh"; return; }
  finto "${E02}/_docente/live.sh" "${ws}"
  expect "live: la prova del docente, 0" 0 "VERIFICA OK   verifica.sh dell'elemento"
  expect "live: la banda dell'elemento" 0 "M8-E02"
  expect "live: il comando di misura sullo schermo" 0 "./misura.sh v0"
  expect "live: il confronto" 0 "--confronta v0 v1"
  expect "live: il 50 %, un dato" 0 "almeno il 50 % in meno"
  controlla_chiamate "${TMP}/finto.log" "${ws}" 2
  expect "live: dodici chiamate, le due versioni uguali tranne il prompt" 0 \
    "chiamate giuste"
  vero "live: la v1 di riferimento è nello spazio di lavoro" \
    cmp -s "${ws}/prompt/v1.md" "${E02}/soluzione/prompt/v1.md"
  run "${RADICE}/tools/verifica.sh" M8-E02 --radice "${ws%/M8-E02}"
  expect "live: poi tools/verifica.sh, 0" 0 "VERIFICA OK   M8-E02: fatto."
  run "${E02}/_docente/live.sh"
  expect "live: senza argomenti, 2" 2 "uso:"
  run "${E02}/_docente/live.sh" "${TMP}/non-c-e"
  expect "live: uno spazio di lavoro che non c'è, 2" 2 \
    "spazio di lavoro assente"
  # Una chiamata che fallisce ferma la prova con la sua uscita.
  nuovo_ws ws || { fail "live: prepara_esercizio.sh"; return; }
  modo "ko-se=Rifugio"
  finto "${E02}/_docente/live.sh" "${ws}"
  modo
  expect "live: una chiamata fallita ferma la prova, 1" 1 \
    "la risposta di v0 a caso-2 non è arrivata"
  expect "live: il passo fallito è nominato" 1 "fallito il passo"
  # La precondizione prima delle chiamate.
  nuovo_ws ws || { fail "live: prepara_esercizio.sh"; return; }
  rm -- "${ws}/casi/caso-1/rubrica.md" || exit 2
  : > "${TMP}/esca.log"
  run env PATH="${TMP}/esca:${PATH}" ESCA_LOG="${TMP}/esca.log" \
    "${E02}/_docente/live.sh" "${ws}"
  expect "live: un caso rotto, 2, prima della prima chiamata" 2 "non si compone"
  local n
  n="$(grep -c -- 'invocazione' "${TMP}/esca.log")"
  if (( n <= 1 )); then
    pass "live: nessuna chiamata al modello ($(grep -c -- '--version' "${TMP}/esca.log") --version)"
  else
    fail "live: ${n} chiamate"
  fi
}

# Gli script di M8-E02 e questo file, con shellcheck -x.
t_shellcheck() {
  local f
  for f in "${E02}/verifica.sh" "${E02}/_docente/live.sh" \
      "${E02}/esercizio/misura.sh" "${SELF}"; do
    if ( cd "${RADICE}" && shellcheck -x -- "${f}" ) > /dev/null 2>&1; then
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
      || { echo "test_m8_e02: manca ${t}" >&2; exit 2; }
  done
  [[ -f "${FINTO_PY}" ]] \
    || { echo "test_m8_e02: manca ${FINTO_PY}" >&2; exit 2; }
  handson::init_temp_base
  TMP="$(mktemp -d "${HANDSON_TEMP_BASE}/test_m8_e02.XXXXXX")" || exit 2
  trap 'chmod -R u+rwX "${TMP}" 2> /dev/null; rm -rf "${TMP}"' EXIT
  prepara_claude
  if ! nuovo_ws BASE; then
    echo "test_m8_e02: la base non si prepara" >&2
    exit 2
  fi
  misura_v "${BASE}" v0 > "${TMP}/base.log" 2>&1 \
    || { echo "test_m8_e02: la base, v0: $(tail -n 3 "${TMP}/base.log")" >&2
         exit 2; }
  cp -- "${E02}/soluzione/prompt/v1.md" "${BASE}/prompt/v1.md" || exit 2
  misura_v "${BASE}" v1 > "${TMP}/base.log" 2>&1 \
    || { echo "test_m8_e02: la base, v1: $(tail -n 3 "${TMP}/base.log")" >&2
         exit 2; }
  t_elemento
  t_readme
  t_prepara
  t_kit
  t_misura
  t_precondizioni
  t_fallita
  t_verifica_esiti
  t_verifica_rotti
  t_live
  t_shellcheck
  OUT="${TUTTO}"
  expect_absent "in nessuna uscita «smentita»" "smentita"
  expect_absent "in nessuna uscita un traceback" "Traceback"
  echo "PASS=${PASS} FAIL=${FAIL}"
  if (( PASS + FAIL != CASES )); then
    echo "test_m8_e02: girati $((PASS + FAIL)) casi, attesi ${CASES}" >&2
    exit 2
  fi
  (( FAIL == 0 )) || exit 1
}

main "$@"
