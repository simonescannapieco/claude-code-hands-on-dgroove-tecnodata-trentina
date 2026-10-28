#!/bin/bash
#
# test_m4_d06.sh -- le prove di M4-D06 «Delegare la lettura», per il
# docente (sta in _docente/, il materiale del docente):
#   - l'elemento: progetti.txt; i due prompt, che differiscono soltanto
#     nella prima frase; la verità in verita.json, accanto all'elemento e
#     fuori da demo/, uguale a quella di progetti/rete/_docente/README.md;
#     il controllo senza la verità dentro; le dieci sezioni del README, le
#     frasi di Anthropic con il loro indirizzo; nessun nome interno,
#     nessun percorso personale, nessuna «smentita»;
#   - prepara_esercizio.sh: i log senza il materiale del docente, nessuna
#     verità nello spazio di lavoro; verifica.sh sul punto di partenza (1);
#   - controlla_delega.py su stream del claude finto: la garanzia (nessun
#     risultato del subagent nella conversazione principale), il
#     confronto del contesto principale coppia per coppia e «n su N», le
#     coppie che non si distinguono, i dati (tutti i modelli, le risposte
#     contro la verità, gli strumenti, le durate); gli stream rovinati e le
#     coppie a metà (1); le precondizioni (2), mai un traceback; il finto
#     con --tools, come Claude Code: senza Agent nessuna delega, senza
#     Bash il subagent legge con Read;
#   - verifica.sh: il controllo e la verità dell'elemento, mai quelli
#     dello spazio di lavoro; le precondizioni (2);
#   - _docente/live.sh con il claude finto (claude_finto_m4_d04_d06.py): le
#     coppie (PN_COPPIE, 3 se non c'è), ogni chiamata da progetti/rete/log
#     con i suoi testi e le sue opzioni (--tools Agent,Read,Grep,Glob:
#     nessuno stream usa Bash), senza ANTHROPIC_API_KEY, e nessuna
#     risposta nello spazio di lavoro mentre le sessioni girano; il blocco
#     del README fa le stesse chiamate; le precondizioni (2, nessuna
#     chiamata: l'esca); gli esiti diversi (1); una chiamata fallita dopo
#     una riuscita: lo stream finito resta in risposte/;
#   - il README: i comandi di sola lettura «di regola» senza permesso, Glob
#     e Grep su macOS, Linux e WSL, i token della registrazione, il tool
#     Agent, gli ONT, cd - prima della verifica;
#   - shellcheck -x su verifica.sh, live.sh e questo file.
# Mai il claude vero: il finto e l'esca stanno davanti nel PATH, e la
# suite lo controlla prima di usarli. Gli stream del finto non sono
# risposte di Claude: provano il controllo, non il modello. Gli spazi di
# lavoro nascono in una cartella temporanea, nella base di
# handson::init_temp_base (mai dentro ~/.claude): l'albero del repository
# non cambia. CASES è il numero dei casi: se ne girano di più o di meno la
# suite esce 2.
#
# Uso:    m4_claude_code_agenti/_docente/test_m4_d06.sh
# Uscita: 0 = tutti i casi passano · 1 = almeno un caso fallito · 2 =
#         precondizione (manca python3, git o shellcheck), o un numero di
#         casi diverso da CASES
set -uo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly MOD="${SELF%/_docente/*}"
readonly RADICE="${MOD%/*}"
D06="${MOD}/s3_agente_nel_repository/m4_8_subagent"
D06+="/M4-D06_delegare_la_lettura"
readonly D06
readonly FINTO_PY="${MOD}/_docente/claude_finto_m4_d04_d06.py"
readonly RETE_DOCENTE="${RADICE}/progetti/rete/_docente/README.md"
# La libreria del repository, per la base dei file temporanei
# (handson::init_temp_base): mai dentro ~/.claude, dove
# prepara_esercizio.sh rifiuta gli spazi di lavoro.
# shellcheck source=../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"
readonly CASES=142
DOMANDA="Martedì 8 settembre 2026 un guasto su olt-pergine-01 ha messo fuori"
DOMANDA+=" servizio insieme più linee di clienti. Quando è cominciato, quando è"
DOMANDA+=" finito (quando le ONT sono tornate in linea) e quante linee di"
DOMANDA+=" clienti (ONT) ha coinvolto? Rispondi in una riga: 'inizio: HH:MM |"
DOMANDA+=" fine: HH:MM | ONT: N'."
readonly DOMANDA
P_DELEGA="Delega la lettura dei log a un subagent Explore e fatti riportare"
P_DELEGA+=" solo un riassunto breve. ${DOMANDA}"
readonly P_DELEGA
readonly P_SENZA="Non delegare a subagent: leggi tu i log. ${DOMANDA}"
S_GARANZIA='La conversazione principale vede solo il risultato del'
S_GARANZIA+=' subagent'
readonly S_GARANZIA
S_CONTESTO='Un subagent tiene i log fuori dalla conversazione'
S_CONTESTO+=' principale'
readonly S_CONTESTO
readonly CONF='confermata'
readonly NONCONF='non confermata in questa esecuzione'
readonly NONDIST='non distinguibile'
readonly GIUSTA='inizio: 10:12 | fine: 11:40 | ONT: 40'
FATTO='Fatto: ogni affermazione è stata messa alla prova;'
FATTO+=' gli esiti sono qui sopra.'
readonly FATTO
readonly PARTENZA='Manca la cartella risposte/'
readonly NESSUNA_PROVA='nessuna esecuzione con la delega'
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
    fail "$1 (rc=${RC}, attesa $2, parola «$3»): ${OUT:0:600}"
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

# Uno spazio di lavoro nuovo, con prepara_esercizio.sh in una radice nuova.
# Arguments: $1 la variabile da assegnare.
# Returns: 0; 1 se prepara_esercizio.sh non riesce.
nuovo_ws() {
  local __r
  __r="$(mktemp -d "${TMP}/radice.XXXXXX")" || exit 2
  "${RADICE}/tools/prepara_esercizio.sh" M4-D06 --radice "${__r}" \
    > "${TMP}/prepara.log" 2>&1 || return 1
  printf -v "$1" '%s' "${__r}/M4-D06"
}

# Uno spazio di lavoro finto per il controllo: soltanto risposte/.
# Arguments: $1 la variabile da assegnare.
ws_finto() {
  local __w
  __w="$(mktemp -d "${TMP}/ws.XXXXXX")" || exit 2
  mkdir -p "${__w}/risposte" "${__w}/progetti/rete/log" || exit 2
  printf -v "$1" '%s' "${__w}"
}

# Lo stream di una chiamata del claude finto, scritto in risposte/.
# Arguments: $1 lo spazio di lavoro, $2 il nome (delega-1, senza-2, …),
# poi le variabili del finto NOME=valore.
stream() {
  local w="$1" nome="$2" prompt="${P_SENZA}"
  shift 2
  if [[ "${nome}" == delega-* ]]; then
    prompt="${P_DELEGA}"
  fi
  ( cd "${w}/progetti/rete/log" && env "$@" "${TMP}/finto/claude" -p \
      --model sonnet --output-format stream-json --verbose -- "${prompt}" ) \
    > "${w}/risposte/${nome}.jsonl" \
    || { echo "test_m4_d06: il finto non scrive ${nome}" >&2; exit 2; }
}

# Come stream, con --tools: la coppia n di una sessione con soltanto gli
# strumenti integrati nominati. Arguments: $1 lo spazio di lavoro, $2 il
# numero della coppia, $3 il valore di --tools.
coppia_tools() {
  local w="$1" lato prompt
  for lato in delega senza; do
    prompt="${P_SENZA}"
    if [[ "${lato}" == delega ]]; then
      prompt="${P_DELEGA}"
    fi
    ( cd "${w}/progetti/rete/log" && "${TMP}/finto/claude" -p \
        --model sonnet --tools "$3" --output-format stream-json \
        --verbose -- "${prompt}" ) \
      > "${w}/risposte/${lato}-$2.jsonl" \
      || { echo "test_m4_d06: il finto non scrive ${lato}-$2" >&2; exit 2; }
  done
}

# Le coppie complete che confermano: delega-n e senza-n per n = 1..$2.
# Arguments: $1 lo spazio di lavoro, $2 quante coppie.
coppie() {
  local n
  for (( n = 1; n <= $2; n++ )); do
    stream "$1" "delega-${n}"
    stream "$1" "senza-${n}"
  done
}

# controlla_delega.py dell'elemento con la verità dell'elemento sullo
# spazio di lavoro $1, con gli argomenti che seguono; RC e OUT come run.
controlla() {
  local w="$1"
  shift
  run python3 -B -I "${D06}/demo/controlla_delega.py" \
    --verita "${D06}/verita.json" "$@" "${w}"
}

# L'esca in ${TMP}/esca (registra ogni invocazione ed esce 0); il claude
# finto in ${TMP}/finto; ${TMP}/senza_python, un PATH con readlink e
# l'esca; ${TMP}/senza_claude, uno con readlink, python3 e git. Esce 2 se
# nel PATH di prova il claude trovato non è il finto.
prepara_claude() {
  local t
  mkdir -p "${TMP}/esca" "${TMP}/finto" "${TMP}/senza_python" \
    "${TMP}/senza_claude" || exit 2
  # shellcheck disable=SC2016  # il corpo è dell'esca
  printf '%s\n' '#!/bin/bash' \
    'printf "invocazione %s\n" "$*" >> "${ESCA_LOG}"' \
    > "${TMP}/esca/claude" || exit 2
  cp -- "${FINTO_PY}" "${TMP}/finto/claude" || exit 2
  chmod 755 "${TMP}/esca/claude" "${TMP}/finto/claude" || exit 2
  ln -s "${TMP}/esca/claude" "${TMP}/senza_python/claude" || exit 2
  ln -s "$(command -v readlink)" "${TMP}/senza_python/readlink" || exit 2
  for t in readlink python3 git; do
    ln -s "$(command -v "${t}")" "${TMP}/senza_claude/${t}" || exit 2
  done
  t="$(PATH="${TMP}/finto:${PATH}" command -v claude)"
  if [[ "${t}" != "${TMP}/finto/claude" ]]; then
    echo "test_m4_d06: nel PATH di prova claude è ${t}, non il finto" >&2
    exit 2
  fi
}

# live.sh con l'esca davanti nel PATH (o con un PATH dato); il registro
# delle invocazioni riparte vuoto. Arguments: $1 lo spazio di lavoro, $2
# facoltativo il PATH, poi le variabili NOME=valore.
esca() {
  local w="$1" percorso="${2:-${TMP}/esca:${PATH}}"
  shift
  (( $# == 0 )) || shift
  : > "${TMP}/esca.log"
  run env PATH="${percorso}" HANDSON_NO_PAUSE=1 ESCA_LOG="${TMP}/esca.log" \
    "$@" "${D06}/_docente/live.sh" "${w}"
}

# Una precondizione di live.sh: uscita 2, la parola attesa, e nessuna
# invocazione dell'esca. Arguments: $1 il nome, $2 la parola, poi gli
# argomenti di esca.
precondizione() {
  local nome="$1" parola="$2" n
  shift 2
  esca "$@"
  expect "${nome}" 2 "${parola}"
  n="$(grep -c . "${TMP}/esca.log")"
  if (( n == 0 )); then
    pass "${nome}: nessuna invocazione di claude"
  else
    fail "${nome}: ${n} invocazioni di claude"
  fi
}

# live.sh con il claude finto davanti nel PATH e ANTHROPIC_API_KEY
# impostata (live.sh la deve togliere); il registro riparte vuoto.
# Arguments: $1 lo spazio di lavoro, poi le variabili NOME=valore.
finto() {
  local w="$1"
  shift
  : > "${TMP}/finto.log"
  run env PATH="${TMP}/finto:${PATH}" HANDSON_NO_PAUSE=1 \
    ANTHROPIC_API_KEY=valore-finto FINTO_LOG="${TMP}/finto.log" "$@" \
    "${D06}/_docente/live.sh" "${w}"
}

# Le chiamate al modello di un registro del finto, contro le attese:
# quante, da quale cartella, con quali prompt e opzioni, senza chiave e
# senza risposte vicine. Arguments: $1 il registro, $2 lo spazio di
# lavoro, $3 quante coppie.
controlla_chiamate() {
  run python3 -B -I - "$1" "$2" "$3" "${P_DELEGA}" "${P_SENZA}" <<'PY'
import json, os, sys
log, ws, n, delega, senza = sys.argv[1:6]
righe = [json.loads(r) for r in open(log, encoding="utf-8")]
chiamate = [r for r in righe if r["argv"][:1] != ["--version"]]
attese = [p for _ in range(int(n)) for p in (delega, senza)]
VALORE = {"--model", "--effort", "--tools", "--allowedTools",
          "--output-format", "--setting-sources", "--permission-mode",
          "--permission-prompts"}
fisse = (("--model", "sonnet"), ("--effort", "low"),
         ("--tools", "Agent,Read,Grep,Glob"),
         ("--allowedTools", "Read,Grep,Glob"),
         ("--output-format", "stream-json"),
         ("--setting-sources", "project,local"),
         ("--permission-mode", "dontAsk"), ("--permission-prompts", "none"))
problemi = []
if len(chiamate) != len(attese):
    problemi.append("%d chiamate invece di %d" % (len(chiamate), len(attese)))
log_dir = os.path.realpath(os.path.join(ws, "progetti", "rete", "log"))
for i, (c, prompt) in enumerate(zip(chiamate, attese), 1):
    argv = c["argv"]
    if "--" not in argv:
        problemi.append("chiamata %d: il prompt non è dopo «--»" % i)
        continue
    fine, opzioni, j = argv.index("--"), {}, 0
    while j < fine:
        if argv[j] in VALORE:
            opzioni[argv[j]] = argv[j + 1]
            j += 2
        else:
            opzioni[argv[j]] = True
            j += 1
    if argv[fine + 1:] != [prompt]:
        problemi.append("chiamata %d: il prompt" % i)
    if os.path.realpath(c["cwd"]) != log_dir:
        problemi.append("chiamata %d: la cartella %s" % (i, c["cwd"]))
    for chiave, valore in fisse:
        if opzioni.get(chiave) != valore:
            problemi.append("chiamata %d: %s" % (i, chiave))
    for chiave in ("-p", "--verbose", "--strict-mcp-config",
                   "--no-session-persistence"):
        if opzioni.get(chiave) is not True:
            problemi.append("chiamata %d: %s" % (i, chiave))
    if c["chiave"]:
        problemi.append("chiamata %d: con ANTHROPIC_API_KEY" % i)
    if c["risposte_vicine"]:
        problemi.append("chiamata %d: risposte/ già nello spazio" % i)
print("; ".join(problemi) or "chiamate giuste")
PY
}

# Il blocco di codice del passo 2 del README, senza il rientro, in un
# file. Arguments: $1 il file. Returns: 0; 1 se il blocco non c'è.
blocco_readme() {
  python3 -B -I - "${D06}/README.md" "$1" <<'PY'
import re, sys
readme, uscita = sys.argv[1:3]
dentro, blocco = False, []
try:
    righe = open(readme, encoding="utf-8").read().splitlines()
except OSError:
    sys.exit(1)
for riga in righe:
    if re.match(r"\d+\. ", riga) or riga.startswith("## "):
        dentro = riga.startswith("2. ")
        continue
    if dentro and riga.startswith(" " * 7):
        blocco.append(riga[7:])
if not any("claude -p" in r for r in blocco):
    sys.exit(1)
with open(uscita, "w", encoding="utf-8") as fh:
    fh.write("\n".join(blocco) + "\n")
PY
}

# --- L'elemento -------------------------------------------------------------

t_elemento() {
  local f
  for f in README.md progetti.txt verita.json verifica.sh \
      demo/controlla_delega.py demo/prompt_delega.txt demo/prompt_senza.txt \
      _docente/live.sh soluzione/LEGGIMI.md; do
    if [[ -f "${D06}/${f}" ]]; then
      pass "elemento: ${f}"
    else
      fail "elemento: manca ${f}"
    fi
  done
  for f in verifica.sh _docente/live.sh; do
    vero "elemento: ${f} eseguibile" test -x "${D06}/${f}"
  done
  run cat -- "${D06}/progetti.txt"
  expect "elemento: progetti.txt porta la rete" 0 "progetti/rete"
  run python3 -B -I - "${D06}" "${P_DELEGA}" "${P_SENZA}" "${DOMANDA}" <<'PY'
import os, sys
item, delega, senza, domanda = sys.argv[1:5]
problemi = []
for nome, atteso in (("prompt_delega.txt", delega),
                     ("prompt_senza.txt", senza)):
    try:
        with open(os.path.join(item, "demo", nome), encoding="utf-8") as fh:
            if fh.read().rstrip("\n") != atteso:
                problemi.append(nome)
    except OSError:
        problemi.append("manca " + nome)
if not (delega.endswith(domanda) and senza.endswith(domanda)):
    problemi.append("la domanda comune")
print("; ".join(problemi) or "prompt giusti")
PY
  expect "elemento: i due prompt, che differiscono nella prima frase" 0 \
    "prompt giusti"
}

# La verità: accanto all'elemento, uguale a quella del docente della rete;
# mai in demo/, mai nel controllo.
t_verita() {
  run python3 -B -I - "${D06}" "${RETE_DOCENTE}" <<'PY'
import json, os, re, sys
item, rete = sys.argv[1:3]
problemi = []
try:
    with open(os.path.join(item, "verita.json"), encoding="utf-8") as fh:
        verita = json.load(fh)
except (OSError, ValueError) as exc:
    print("verita.json non si legge (%s)" % exc)
    sys.exit(0)
attesa = {"inizio": "10:12", "fine": "11:40", "ont": 40}
if {k: verita.get(k) for k in attesa} != attesa or "linee" in verita:
    problemi.append("verita.json: %s" % verita)
testo = open(rete, encoding="utf-8").read()
riga = re.search(r"Martedì 8, (\d\d:\d\d)–(\d\d:\d\d) — fibra tagliata "
                 r"sulla porta PON 0/1/3 di `olt-pergine-01`\*\* \((\d+) linee",
                 testo)
ont = re.search(r"(\d+) `ONT_OFFLINE … cause LOS`", testo)
if not riga or not ont or (riga.group(1), riga.group(2), int(riga.group(3)),
                           int(ont.group(1))) != (
        verita.get("inizio"), verita.get("fine"), verita.get("ont"),
        verita.get("ont")):
    problemi.append("diversa dal README del docente della rete")
for cartella, _, file in os.walk(os.path.join(item, "demo")):
    for nome in file:
        with open(os.path.join(cartella, nome), encoding="utf-8") as fh:
            contenuto = fh.read()
        if "10:12" in contenuto or "11:40" in contenuto:
            problemi.append("demo/%s contiene la verità" % nome)
print("; ".join(problemi) or "verità a posto")
PY
  expect "verità: accanto all'elemento, uguale al docente, fuori da demo/" 0 \
    "verità a posto"
}

# Il README: le dieci sezioni, le frasi di Anthropic e i loro indirizzi;
# niente nomi interni, percorsi personali, giornate, «smentita».
t_readme() {
  run python3 -B -I - "${D06}" <<'PY'
import os, re, sys
item = sys.argv[1]
with open(os.path.join(item, "README.md"), encoding="utf-8") as fh:
    readme = fh.read()
problemi = []
sezioni = ("Obiettivo", "Tempo", "Prerequisiti", "Punto di partenza",
           "Passi in Claude Code", "Che cosa osservare", "Verifica",
           "Se qualcosa va storto", "Impronta d'uso sul piano Pro",
           "Per approfondire")
titoli = [r[3:] for r in readme.splitlines() if r.startswith("## ")]
if [next((s for s in sezioni if t.startswith(s)), "") for t in titoli] \
        != list(sezioni):
    problemi.append("le dieci sezioni, in ordine: %s" % titoli)
if "## Punto di partenza (tools/prepara_esercizio.sh M4-D06)" not in readme:
    problemi.append("il titolo del punto di partenza")
if "## Verifica (tools/verifica.sh M4-D06)" not in readme:
    problemi.append("il titolo della verifica")
frasi = [
    ("The parent doesn't see the subagent's intermediate tool calls or "
     "outputs, only that final result.",
     "https://code.claude.com/docs/en/tools-reference"),
    ("Use one when a side task would flood your main conversation with "
     "search results, logs, or file contents you won't reference again",
     "https://code.claude.com/docs/en/sub-agents"),
    ("Keeping long output, like a full test run or a wide search, out of "
     "your main conversation",
     "https://code.claude.com/docs/en/best-practices"),
    ("What they cost you is mostly tokens, since every subagent sends its "
     "own requests and they count against the same usage as your main "
     "conversation.", "https://code.claude.com/docs/en/best-practices"),
    ("You get parallelism or a fresh pair of eyes out of it, but not a "
     "smarter answer.", "https://code.claude.com/docs/en/best-practices"),
    ("Use modelUsage, or model_usage in Python, for whole-tree token "
     "accounting; the usage field undercounts as soon as nesting occurs.",
     "https://code.claude.com/docs/en/agent-sdk/cost-tracking"),
    ("Their parent_tool_use_id field says which run each one belongs to. "
     "Messages from the main conversation carry null in that field.",
     "https://code.claude.com/docs/en/headless"),
    ("In version 2.1.63, the Task tool was renamed to Agent.",
     "https://code.claude.com/docs/en/sub-agents"),
    ("The set includes ls, cat, echo, pwd, head, tail, grep, find, wc, "
     "which, diff, stat, du, cd, and read-only forms of git.",
     "https://code.claude.com/docs/en/permissions"),
    ("Specify the list of available tools from the built-in set.",
     "claude --help"),
    ("You name Glob or Grep in --tools or --allowedTools when you start "
     "the session", "https://code.claude.com/docs/en/tools-reference"),
]
piatto = " ".join(readme.split())
if "### Perché le sessioni non hanno Bash" not in readme:
    problemi.append("manca il perché delle sessioni senza Bash")
if "comando di Bash che le regole non coprono" in piatto:
    problemi.append("il README porta ancora l'esempio di Bash")
for pezzo in ("quante linee di clienti (ONT)",
              "'inizio: HH:MM | fine: HH:MM | ONT: N'"):
    if pezzo not in piatto:
        problemi.append("il README non porta la domanda: «%s»" % pezzo)
if "linee: N" in piatto:
    problemi.append("il README porta ancora «linee: N»")
for frase, url in frasi:
    if frase not in piatto:
        problemi.append("manca la frase «%s…»" % frase[:40])
    if url not in readme:
        problemi.append("manca l'indirizzo %s" % url)
maniglie = re.compile(r"\bFACT-(?:C|M[0-9])-[0-9]{3}\b|\bM[0-9]-X[0-9]+\b"
                      r"|\bX-[0-9]+\b|(?<![\w-])D(?:0[1-9]|[12][0-9]|3[01])\b"
                      r"|\b(?:ASK|OQ|DEC|TD|PQ)-[0-9]+\b|(?i:\btriage\b)")
for cartella, _, file in os.walk(item):
    for nome in file:
        percorso = os.path.join(cartella, nome)
        rel = os.path.relpath(percorso, item)
        try:
            with open(percorso, encoding="utf-8") as fh:
                testo = fh.read()
        except (OSError, UnicodeDecodeError):
            continue
        for m in maniglie.finditer(testo):
            problemi.append("%s: un nome interno «%s»" % (rel, m.group()))
        if "/home/" in testo:
            problemi.append("%s: un percorso personale" % rel)
        if "smentit" in testo:
            problemi.append("%s: «smentita»" % rel)
if re.search(r"(?i)\boggi\b|prossima sessione|\bpausa\b|pranzo", readme):
    problemi.append("il README parla della giornata")
print("; ".join(problemi) or "README in ordine")
PY
  expect "README: sezioni, frasi, indirizzi e nessun nome interno" 0 \
    "README in ordine"
  run python3 -B -I - "${D06}/README.md" <<'PY'
import sys
readme = open(sys.argv[1], encoding="utf-8").read()
piatto = " ".join(readme.split())
passi = readme.split("## Passi in Claude Code", 1)[-1].split("\n## ", 1)[0]
problemi = []
frasi = [
    ("Claude Code recognizes a built-in set of Bash commands as read-only "
     "and runs them without a permission prompt in every mode, except as "
     "permissions.blockReadsOutsideWorkingDirectories changes for paths "
     "outside your working directories.",
     "https://code.claude.com/docs/en/permissions"),
    ("On macOS, Linux, and WSL, Claude Code leaves Glob and Grep out of the "
     "default tool set", "https://code.claude.com/docs/en/tools-reference"),
]
for frase, url in frasi:
    if frase not in piatto or url not in readme:
        problemi.append("manca la frase «%s…»" % frase[:40])
for atteso in ("di regola", "su macOS, Linux e WSL", "188.296", "117.147",
               "circa 100.000", "il tool Agent", "ONT coinvolti"):
    if atteso not in piatto:
        problemi.append("manca «%s»" % atteso)
for vecchio in ("solo se", "290.000", "strumento Agent", "ONT coinvolte"):
    if vecchio in piatto:
        problemi.append("c'è ancora «%s»" % vecchio)
# «le ONT» soltanto dentro la domanda, che si cita com'è nei prompt.
if "le ONT" in piatto.replace("quando le ONT sono tornate in linea", ""):
    problemi.append("«le ONT» fuori dalla domanda")
# Dopo il blocco del passo 2, che si dà dallo spazio di lavoro, cd - torna
# alla cartella esercitazioni prima della verifica.
blocco = passi.find('mv "$r"/*.jsonl risposte/')
verifica = passi.find("tools/verifica.sh M4-D06")
torna = passi.find("cd -", blocco)
if -1 in (blocco, verifica, torna) or not blocco < torna < verifica:
    problemi.append("cd - prima della verifica")
print("; ".join(problemi) or "README aggiornato")
PY
  expect "README: di regola, macOS, i token, il tool Agent, gli ONT, cd -" 0 \
    "README aggiornato"
}

# prepara_esercizio.sh: i log senza il materiale del docente, nessuna
# verità; verifica.sh esce 1 sul punto di partenza.
t_prepara() {
  local w n
  if ! nuovo_ws w; then
    fail "prepara: prepara_esercizio.sh non riesce: $(cat "${TMP}/prepara.log")"
    return 0
  fi
  if [[ -d "${w}/progetti/rete/log/syslog" && -f "${w}/controlla_delega.py" \
      && -f "${w}/prompt_delega.txt" && ! -e "${w}/progetti/rete/_docente" \
      && ! -e "${w}/soluzione" && ! -e "${w}/_docente" ]]; then
    pass "prepara: i log e la demo, senza il materiale del docente"
  else
    fail "prepara: lo spazio di lavoro non è quello atteso"
  fi
  n="$(command find "${w}" -name verita.json | wc -l)"
  if (( n == 0 )); then
    pass "prepara: nessuna verità nello spazio di lavoro"
  else
    fail "prepara: ${n} verita.json nello spazio di lavoro"
  fi
  run ls -A "${w}/progetti/rete/log"
  if [[ "$(tr '\n' ' ' <<< "${OUT}")" == "dhcp pppoe radius sip syslog " ]]
  then
    pass "prepara: in progetti/rete/log soltanto i log"
  else
    fail "prepara: in progetti/rete/log c'è «${OUT}»"
  fi
  run "${RADICE}/tools/verifica.sh" M4-D06 --radice "${w%/*}"
  expect "prepara: sul punto di partenza la verifica esce 1" 1 "${PARTENZA}"
}

# --- controlla_delega.py ----------------------------------------------------

# Le coppie complete: l'uscita, i dati, i verdetti.
t_complete() {
  local w
  ws_finto w
  coppie "${w}" 3
  controlla "${w}"
  expect "controllo: tre coppie, uscita 0" 0 "${S_CONTESTO}: ${CONF} 3 su 3"
  expect "controllo: la garanzia" 0 "${S_GARANZIA}: ${CONF} 3 su 3"
  expect "controllo: la garanzia di una coppia" 0 \
    "${S_GARANZIA} (delega, 2): ${CONF}"
  expect "controllo: il confronto di una coppia" 0 \
    "${S_CONTESTO} (coppia 1): ${CONF} (21.000 token contro 29.000)"
  expect "controllo: l'Agent come dato" 0 "Agent 1 (Explore)"
  expect "controllo: gli strumenti del subagent come dato" 0 \
    "strumenti del subagent: Bash 1, Grep 1"
  expect "controllo: gli strumenti senza delega come dato" 0 \
    "strumenti: Bash 1, Grep 1"
  expect "controllo: il contesto principale come dato" 0 \
    "contesto principale all'ultima richiesta: 29.000 token"
  expect "controllo: tutti i modelli come dato" 0 \
    "tutti i modelli: 170.020 token in entrata, 2.000 in uscita"
  expect "controllo: la risposta contro la verità" 0 "«${GIUSTA}»: giusta"
  expect "controllo: le risposte giuste come dato" 0 \
    "risposte giuste: 3 su 3 con la delega, 3 su 3 senza"
  expect "controllo: la durata come dato" 0 "durata:"
  expect_absent "controllo: la frase finale è della verifica" "Fatto:"
  expect_absent "controllo: nessun «non confermata»" "${NONCONF}"
  ws_finto w
  coppie "${w}" 1
  controlla "${w}"
  expect "controllo: una coppia sola basta" 0 "${S_CONTESTO}: ${CONF} 1 su 1"
  run python3 -B -I "${D06}/demo/controlla_delega.py" "${w}"
  expect "controllo: senza la verità, le risposte non si confrontano" 0 \
    "nessuna verità"
  expect_absent "controllo: senza la verità nessun «giusta»" ": giusta"
}

# I verdetti che cambiano: mai un'uscita diversa da 0 per il confronto.
t_verdetti() {
  local w
  ws_finto w
  coppie "${w}" 2
  stream "${w}" delega-2 FINTO_CONTESTO_DELEGA=29000
  controlla "${w}"
  expect "verdetti: lo stesso contesto, non distinguibile, uscita 0" 0 \
    "${S_CONTESTO} (coppia 2): ${NONDIST}"
  expect "verdetti: e il riepilogo" 0 "${S_CONTESTO}: ${CONF} 1 su 2"
  ws_finto w
  coppie "${w}" 1
  stream "${w}" delega-1 FINTO_CONTESTO_DELEGA=35000
  controlla "${w}"
  expect "verdetti: più contesto con la delega, non confermata, uscita 0" 0 \
    "${S_CONTESTO} (coppia 1): ${NONCONF}"
  ws_finto w
  coppie "${w}" 1
  stream "${w}" delega-1 FINTO_NON_DELEGA=1
  controlla "${w}"
  expect "verdetti: nessun subagent con la delega, non distinguibile" 1 \
    "${S_CONTESTO} (coppia 1): ${NONDIST} (nessun subagent"
  expect "verdetti: e la garanzia non si mette alla prova" 1 \
    "${S_GARANZIA} (delega, 1): ${NONDIST} (nessun subagent"
  expect "verdetti: nessuna esecuzione la mette alla prova: non ancora (1)" \
    1 "${NESSUNA_PROVA}"
  ws_finto w
  coppie "${w}" 2
  stream "${w}" delega-2 FINTO_NON_DELEGA=1
  controlla "${w}"
  expect "verdetti: una coppia su due senza delega, uscita 0" 0 \
    "${S_GARANZIA}: ${CONF} 1 su 1"
  expect_absent "verdetti: e niente «non ancora»" "${NESSUNA_PROVA}"
  ws_finto w
  coppie "${w}" 1
  stream "${w}" delega-1 FINTO_SENZA_PASSAGGI=1
  controlla "${w}"
  expect "verdetti: l'Agent senza passaggi del subagent, non distinguibile" 1 \
    "${S_GARANZIA} (delega, 1): ${NONDIST} (nessun risultato"
  ws_finto w
  coppie "${w}" 1
  stream "${w}" delega-1 FINTO_SENZA_USO=1
  controlla "${w}"
  expect "verdetti: l'ultimo messaggio principale senza usage" 0 \
    "${S_CONTESTO} (coppia 1): ${NONDIST} (manca il contesto"
  ws_finto w
  coppie "${w}" 1
  stream "${w}" senza-1 FINTO_DELEGA_SEMPRE=1
  controlla "${w}"
  expect "verdetti: un subagent anche senza delega, non distinguibile" 0 \
    "${S_CONTESTO} (coppia 1): ${NONDIST} (un subagent anche"
  ws_finto w
  coppie "${w}" 1
  stream "${w}" delega-1 \
    'FINTO_RISPOSTA_DELEGA=inizio: 10:12 | fine: 11:41 | ONT: 40'
  stream "${w}" senza-1 'FINTO_RISPOSTA_SENZA=Non lo so.'
  controlla "${w}"
  expect "verdetti: una risposta sbagliata è un dato, uscita 0" 0 \
    "sbagliata (fine 11:41, attesa 11:40)"
  expect "verdetti: una risposta senza la riga è un dato" 0 "senza la riga"
  expect "verdetti: le risposte giuste come dato" 0 \
    "risposte giuste: 0 su 1 con la delega, 0 su 1 senza"
  ws_finto w
  coppie "${w}" 1
  stream "${w}" delega-1 \
    'FINTO_RISPOSTA_DELEGA=inizio: 10:12 | fine: 11:40 | ONT: 84'
  stream "${w}" senza-1 \
    'FINTO_RISPOSTA_SENZA=inizio: 10:12 | fine: 11:40 | linee: 82'
  controlla "${w}"
  expect "verdetti: le ONT sbagliate sono un dato, uscita 0" 0 \
    "sbagliata (ONT 84, attese 40)"
  expect "verdetti: «linee» al posto di «ONT» non vale come ONT" 0 \
    "sbagliata (ONT mancanti)"
}

# La garanzia: un risultato del subagent nella conversazione principale.
t_garanzia() {
  local w
  ws_finto w
  coppie "${w}" 2
  stream "${w}" delega-2 FINTO_PERDITA=1
  controlla "${w}"
  expect "garanzia: un risultato del subagent nella principale (1)" 1 \
    "${S_GARANZIA} (delega, 2): ${NONCONF}"
  expect "garanzia: è da segnalare" 1 "da segnalare"
  ws_finto w
  coppie "${w}" 1
  stream "${w}" delega-1 FINTO_ORFANO=1
  controlla "${w}"
  expect "garanzia: nella principale un risultato senza la sua chiamata (1)" \
    1 "${S_GARANZIA} (delega, 1): ${NONCONF}"
  ws_finto w
  coppie "${w}" 1
  python3 -B -I - "${w}/risposte/senza-1.jsonl" <<'PY'
import json, re, sys
p = sys.argv[1]
eventi = [json.loads(r) for r in open(p, encoding="utf-8") if r.strip()]
for evento in eventi:
    for blocco in (evento.get("message") or {}).get("content") or []:
        if blocco.get("type") == "tool_result":
            blocco["content"] = "prima dopo"
    if "timestamp" in evento:
        evento["timestamp"] = re.sub(r"\.\d+Z$", ".1234567Z",
                                     evento["timestamp"])
with open(p, "w", encoding="utf-8") as fh:
    for evento in eventi:
        fh.write(json.dumps(evento, ensure_ascii=False) + "\n")
PY
  controlla "${w}"
  expect "letture: un U+2028 dentro uno stream si legge (0)" 0 \
    "${S_CONTESTO}: ${CONF} 1 su 1"
  if grep -qE '^senza, 1: .*durata: [0-9]+ s$' <<< "${OUT}"; then
    pass "letture: la durata anche con sette cifre di frazione"
  else
    fail "letture: la durata con sette cifre: ${OUT:0:400}"
  fi
}

# Il finto con --tools, come Claude Code: la sessione ha soltanto gli
# strumenti integrati nominati. Senza Agent nessuna delega, e la garanzia
# non si mette alla prova (1); con Agent e senza Bash il subagent legge
# con Read.
t_finto_tools() {
  local w
  ws_finto w
  coppia_tools "${w}" 1 Read,Grep,Glob
  controlla "${w}"
  expect "finto: --tools senza Agent, nessuna delega (1)" 1 "${NESSUNA_PROVA}"
  ws_finto w
  coppia_tools "${w}" 1 Agent,Read,Grep,Glob
  controlla "${w}"
  expect "finto: --tools Agent,Read,Grep,Glob, la delega senza Bash" 0 \
    "strumenti del subagent: Read 1, Grep 1"
}

# Gli stream e le coppie che non vanno: uscita 1, con il perché, senza
# traceback. Arguments: $1 il nome, $2 la parola, $3 la funzione che
# rovina lo spazio di lavoro (lo riceve).
rovinato() {
  local w
  ws_finto w
  coppie "${w}" 2
  "$3" "${w}"
  controlla "${w}"
  expect "$1" 1 "$2"
  expect_absent "$1: nessun traceback" "Traceback"
}
senza_partner() { rm -f -- "$1/risposte/senza-2.jsonl"; }
nessuna_coppia() { rm -f -- "$1/risposte/"*.jsonl; }
senza_risposte() { rm -rf -- "$1/risposte"; }
stream_vuoto() { : > "$1/risposte/delega-1.jsonl"; }
riga_non_json() { printf 'non json\n' >> "$1/risposte/senza-1.jsonl"; }
troncato() { stream "$1" delega-2 FINTO_TRONCO=1; }
con_errore() {
  sed -i 's/"is_error": false/"is_error": true/' "$1/risposte/senza-2.jsonl"
}

t_rovinati() {
  rovinato "rovinati: una coppia a metà" "manca risposte/senza-2.jsonl" \
    senza_partner
  rovinato "rovinati: nessuna coppia" "nessuna coppia" nessuna_coppia
  rovinato "rovinati: risposte/ che manca" "${PARTENZA}" senza_risposte
  rovinato "rovinati: uno stream vuoto" "è vuoto" stream_vuoto
  rovinato "rovinati: una riga non JSON" "non è JSON" riga_non_json
  rovinato "rovinati: uno stream troncato" \
    "lo stream non finisce con il risultato" troncato
  rovinato "rovinati: is_error" "claude ha restituito un errore" con_errore
  local w
  ws_finto w
  coppie "${w}" 1
  printf 'appunti\n' > "${w}/risposte/note.txt"
  controlla "${w}"
  expect "rovinati: un file che non è una risposta non conta" 0 \
    "${S_CONTESTO}: ${CONF} 1 su 1"
}

# Le precondizioni del controllo: uscita 2, senza traceback.
t_precondizioni() {
  local w
  controlla "${TMP}/assente"
  expect "precondizioni: spazio di lavoro assente (2)" 2 \
    "spazio di lavoro assente"
  run python3 -B -I "${D06}/demo/controlla_delega.py" --boh
  expect "precondizioni: un'opzione sconosciuta (2)" 2 "Uso:"
  run python3 -B -I "${D06}/demo/controlla_delega.py" --verita
  expect "precondizioni: --verita senza file (2)" 2 "Uso:"
  ws_finto w
  coppie "${w}" 1
  run python3 -B -I "${D06}/demo/controlla_delega.py" \
    --verita "${TMP}/assente.json" "${w}"
  expect "precondizioni: la verità che manca (2)" 2 "non si legge"
  printf '{"inizio": "10.12", "fine": "11:40", "ont": 40}\n' \
    > "${TMP}/verita_rotta.json"
  run python3 -B -I "${D06}/demo/controlla_delega.py" \
    --verita "${TMP}/verita_rotta.json" "${w}"
  expect "precondizioni: una verità che non va (2)" 2 "non va"
  printf '{"inizio": "10:12", "fine": "11:40", "linee": 40}\n' \
    > "${TMP}/verita_vecchia.json"
  run python3 -B -I "${D06}/demo/controlla_delega.py" \
    --verita "${TMP}/verita_vecchia.json" "${w}"
  expect "precondizioni: una verità con «linee» invece di «ont» (2)" 2 \
    "non va"
  printf '[1]\n' > "${TMP}/verita_lista.json"
  run python3 -B -I "${D06}/demo/controlla_delega.py" \
    --verita "${TMP}/verita_lista.json" "${w}"
  expect "precondizioni: una verità che non è un oggetto (2)" 2 "non va"
  run python3 -B -I -c 'import importlib.util, sys
spec = importlib.util.spec_from_file_location("controllo", sys.argv[1])
modulo = importlib.util.module_from_spec(spec)
spec.loader.exec_module(modulo)
def guasto(*_):
    raise RuntimeError("guasto finto")
modulo.controlla = guasto
sys.exit(modulo.main(sys.argv[2:]))' "${D06}/demo/controlla_delega.py" "${w}"
  expect "precondizioni: un errore inatteso (2)" 2 "errore inatteso"
  expect_absent "precondizioni: senza traceback" "Traceback"
}

# --- verifica.sh ------------------------------------------------------------

# Una copia di verifica.sh, di verita.json e di demo/ in cui il controllo è
# finto: esce con il codice dato, o si fa terminare da un segnale.
# Arguments: $1 la variabile da assegnare (la copia), $2 il codice
# d'uscita, oppure «segnale».
albero_finto() {
  local __a __c
  __a="$(mktemp -d "${TMP}/albero.XXXXXX")" || exit 2
  if ! cp -- "${D06}/verifica.sh" "${D06}/verita.json" "${__a}/" \
      || ! cp -R "${D06}/demo" "${__a}/"; then
    echo "test_m4_d06: non riesco a copiare l'elemento" >&2
    exit 2
  fi
  __c="${__a}/demo/controlla_delega.py"
  if [[ "$2" == segnale ]]; then
    printf '%s\n' 'import os, signal' 'os.kill(os.getpid(), signal.SIGTERM)' \
      > "${__c}"
  else
    printf 'import sys\nsys.exit(%d)\n' "$2" > "${__c}"
  fi
  printf -v "$1" '%s' "${__a}"
}

t_verifica() {
  local w a
  run "${D06}/verifica.sh" "${TMP}/assente"
  expect "verifica: spazio di lavoro assente (2)" 2 "spazio di lavoro assente"
  ws_finto w
  run "${D06}/verifica.sh" "${w}"
  expect "verifica: nessuna coppia (1)" 1 "nessuna coppia"
  coppie "${w}" 3
  run "${D06}/verifica.sh" "${w}"
  expect "verifica: le coppie, uscita 0 e la frase finale" 0 "${FATTO}"
  expect "verifica: con la verità dell'elemento" 0 "«${GIUSTA}»: giusta"
  printf 'import sys\nsys.exit(0)\n' > "${w}/controlla_delega.py"
  rm -f -- "${w}/risposte/senza-3.jsonl"
  run "${D06}/verifica.sh" "${w}"
  expect "verifica: il controllo dell'elemento, non quello dello spazio" 1 \
    "manca risposte/senza-3.jsonl"
  run env PATH="${TMP}/senza_python" "${D06}/verifica.sh" "${w}"
  expect "verifica: python3 che manca (2)" 2 "manca python3"
  albero_finto a 3
  run "${a}/verifica.sh" "${w}"
  expect "verifica: un controllo che esce 3 (2)" 2 "fuori dal suo contratto"
  albero_finto a segnale
  run "${a}/verifica.sh" "${w}"
  expect "verifica: un controllo terminato da un segnale (2)" 2 \
    "fuori dal suo contratto"
}

# --- _docente/live.sh -------------------------------------------------------

t_live_precondizioni() {
  local w f
  precondizione "live: spazio di lavoro assente" "spazio di lavoro assente" \
    "${TMP}/assente"
  for f in prompt_delega.txt prompt_senza.txt controlla_delega.py; do
    nuovo_ws w || { fail "live: nessuno spazio di lavoro"; return 0; }
    rm -f -- "${w}/${f}"
    precondizione "live: ${f} che manca" "file assente o illeggibile: ${f}" \
      "${w}"
  done
  nuovo_ws w || return 0
  rm -rf -- "${w}/progetti/rete/log"
  precondizione "live: i log che mancano" "mancano i log" "${w}"
  nuovo_ws w || return 0
  touch "${w}/nuovo.txt"
  precondizione "live: lo spazio di lavoro non è al punto di partenza" \
    "non è al punto di partenza" "${w}"
  nuovo_ws w || return 0
  precondizione "live: python3 che manca" "manca lo strumento: python3" \
    "${w}" "${TMP}/senza_python"
  esca "${w}" "${TMP}/senza_claude"
  expect "live: claude che manca" 2 "manca lo strumento: claude"
  for f in 0 10 tre; do
    precondizione "live: PN_COPPIE=${f}" "PN_COPPIE" "${w}" \
      "${TMP}/esca:${PATH}" "PN_COPPIE=${f}"
  done
  precondizione "live: HANDSON_ENV=trainer-api, rifiutato" "claude-code-pro" \
    "${w}" "${TMP}/esca:${PATH}" HANDSON_ENV=trainer-api \
    ANTHROPIC_API_KEY=valore-finto
  mkdir -p "${TMP}/chiusa"
  chmod 000 "${TMP}/chiusa"
  precondizione "live: uno spazio di lavoro in cui non si entra" \
    "non si apre" "${TMP}/chiusa"
  chmod 755 "${TMP}/chiusa"
}

# Il claude finto: le coppie, i testi e le opzioni, le risposte lontane;
# il blocco del README fa le stesse chiamate.
t_live_finto() {
  local w w2 r
  nuovo_ws w || { fail "live: nessuno spazio di lavoro"; return 0; }
  finto "${w}"
  expect "live: tre coppie con il finto, uscita 0" 0 "VERIFICA OK"
  expect "live: i verdetti si vedono anche quando passa" 0 "${FATTO}"
  expect "live: il riepilogo del confronto" 0 "${S_CONTESTO}: ${CONF} 3 su 3"
  expect "live: la riga di claude si vede prima di girare" 0 \
    "--output-format stream-json"
  r="$(grep -cF "${S_CONTESTO}: ${CONF} 3 su 3" <<< "${OUT}")"
  if (( r == 1 )); then
    pass "live: i verdetti si vedono una volta sola"
  else
    fail "live: il riepilogo si vede ${r} volte"
  fi
  controlla_chiamate "${TMP}/finto.log" "${w}" 3
  expect "live: sei chiamate da progetti/rete/log, testi e opzioni" 0 \
    "chiamate giuste"
  r="$(command find "${w}/risposte" -name '*.jsonl' | wc -l)"
  if (( r == 6 )); then
    pass "live: sei stream in risposte/"
  else
    fail "live: ${r} stream in risposte/"
  fi
  grep -qF '"name": "Bash"' "${w}/risposte/"*.jsonl
  r=$?
  if (( r == 1 )); then
    pass "live: nessuno stream usa Bash"
  else
    fail "live: Bash negli stream, o nessuno stream (grep rc=${r})"
  fi
  nuovo_ws w || return 0
  finto "${w}" PN_COPPIE=1
  expect "live: PN_COPPIE=1, una coppia" 0 "${S_CONTESTO}: ${CONF} 1 su 1"
  controlla_chiamate "${TMP}/finto.log" "${w}" 1
  expect "live: PN_COPPIE=1, due chiamate" 0 "chiamate giuste"
  if ! blocco_readme "${TMP}/passo2.sh"; then
    fail "README: il blocco del passo 2 non c'è"
    return 0
  fi
  nuovo_ws w2 || return 0
  : > "${TMP}/readme.log"
  ( cd "${w2}" && PATH="${TMP}/finto:${PATH}" \
      FINTO_LOG="${TMP}/readme.log" bash "${TMP}/passo2.sh" ) \
    > /dev/null 2>&1
  controlla_chiamate "${TMP}/readme.log" "${w2}" 1
  expect "README: il passo 2 fa le chiamate di live.sh" 0 "chiamate giuste"
  run "${RADICE}/tools/verifica.sh" M4-D06 --radice "${w2%/*}"
  expect "README: dopo il passo 2 la verifica passa" 0 "${FATTO}"
}

# Il claude finto che cambia gli esiti, e i controlli della libreria.
t_live_esiti() {
  local w r chiave
  nuovo_ws w || { fail "live: nessuno spazio di lavoro"; return 0; }
  finto "${w}" FINTO_ESITO=ko
  r="$(python3 -B -I -c 'import json, sys
r = [json.loads(x) for x in open(sys.argv[1], encoding="utf-8")]
print(len([x for x in r if x["argv"][:1] != ["--version"]]))' \
    "${TMP}/finto.log")"
  if (( RC == 1 )) && [[ "${r}" == "1" ]] \
      && grep -qF 'VERIFICA KO' <<< "${OUT}"; then
    pass "live: si ferma alla prima chiamata fallita"
  else
    fail "live: rc=${RC} dopo ${r} chiamate: ${OUT:0:300}"
  fi
  # La seconda chiamata (senza la delega) fallisce dopo una riuscita: lo
  # stream finito non si perde con la cartella temporanea, va in risposte/.
  nuovo_ws w || return 0
  finto "${w}" FINTO_ESITO_KO_SE="Non delegare"
  if (( RC == 1 )) && grep -qF 'VERIFICA KO' <<< "${OUT}" \
      && [[ -s "${w}/risposte/delega-1.jsonl" ]]; then
    pass "live: una chiamata fallita, lo stream finito resta in risposte/"
  else
    fail "live: dopo la chiamata fallita, rc=${RC}, risposte/:" \
      "$(ls -A "${w}/risposte" 2>&1)"
  fi
  nuovo_ws w || return 0
  finto "${w}" FINTO_PERDITA=1
  expect "live: la garanzia non confermata, uscita 1" 1 \
    "${S_GARANZIA}: ${NONCONF}"
  nuovo_ws w || return 0
  finto "${w}" FINTO_TRONCO=1
  expect "live: uno stream troncato, uscita 1" 1 \
    "lo stream non finisce con il risultato"
  nuovo_ws w || return 0
  finto "${w}" FINTO_NON_DELEGA=1
  expect "live: nessuna delega, non distinguibile, uscita 1" 1 \
    "${S_CONTESTO}: ${CONF} 0 su 3"
  expect "live: nessuna delega, non ancora" 1 "${NESSUNA_PROVA}"
  nuovo_ws w || return 0
  finto "${w}" HANDSON_PERMISSION_MODE=bypassPermissions
  if (( RC == 2 )) && [[ ! -s "${TMP}/finto.log" ]] \
      && grep -qF 'modalità di permesso non ammessa' <<< "${OUT}"; then
    pass "live: bypassPermissions rifiutata prima di chiamare il modello"
  else
    fail "live: bypassPermissions, rc=${RC}: ${OUT:0:300}"
  fi
  nuovo_ws w || return 0
  chiave="sk-ant""-finta"
  printf 'Delega la lettura. %s\n' "${chiave}" > "${w}/prompt_delega.txt"
  git -C "${w}" -c user.name=Prova -c user.email=prova@example.org \
    commit -q -am 'prompt con una chiave' || true
  finto "${w}"
  if (( RC == 2 )) && grep -qF 'sembra una chiave API' <<< "${OUT}"; then
    pass "live: una chiave API nel prompt rifiutata prima di chiamare"
  else
    fail "live: chiave nel prompt, rc=${RC}: ${OUT:0:300}"
  fi
  expect_absent "live: la chiave non si stampa" "${chiave}"
}

# Gli script di M4-D06 e questo file, con shellcheck -x.
t_shellcheck() {
  local f
  for f in "${D06}/verifica.sh" "${D06}/_docente/live.sh" "${SELF}"; do
    if [[ -f "${f}" ]] && shellcheck -x "${f}" > /dev/null 2>&1; then
      pass "shellcheck ${f#"${RADICE}"/}"
    else
      fail "shellcheck ${f#"${RADICE}"/}"
    fi
  done
}

main() {
  local t
  for t in python3 git shellcheck; do
    command -v "${t}" >/dev/null 2>&1 \
      || { echo "test_m4_d06: manca ${t}" >&2; exit 2; }
  done
  [[ -f "${FINTO_PY}" && -f "${RETE_DOCENTE}" ]] \
    || { echo "test_m4_d06: manca ${FINTO_PY} o ${RETE_DOCENTE}" >&2
         exit 2; }
  handson::init_temp_base
  TMP="$(mktemp -d "${HANDSON_TEMP_BASE}/test_m4_d06.XXXXXX")" || exit 2
  trap 'chmod -R u+rwX "${TMP}" 2>/dev/null; rm -rf "${TMP}"' EXIT
  prepara_claude
  t_elemento
  t_verita
  t_readme
  t_prepara
  t_complete
  t_verdetti
  t_garanzia
  t_finto_tools
  t_rovinati
  t_precondizioni
  t_verifica
  t_live_precondizioni
  t_live_finto
  t_live_esiti
  t_shellcheck
  OUT="${TUTTO}"
  expect_absent "in nessuna uscita «smentita»" "smentita"
  echo "PASS=${PASS} FAIL=${FAIL} SKIP=${SKIP}"
  if (( PASS + FAIL + SKIP != CASES )); then
    echo "test_m4_d06: girati $((PASS + FAIL + SKIP)) casi, attesi" \
      "${CASES}" >&2
    exit 2
  fi
  (( FAIL == 0 )) || exit 1
}

main "$@"
