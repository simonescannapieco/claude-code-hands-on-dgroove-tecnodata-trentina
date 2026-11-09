#!/bin/bash
#
# test_m7_d09.sh -- le prove di M7-D09 «La guardia nel codice», per il docente:
#   - l'elemento: i due system prompt che differiscono nel divieto, gli
#     strumenti, le cinque impostazioni per braccio, i tre hook, che escono con
#     il codice giusto e non mostrano mai un traceback; le dieci sezioni del
#     README, le frasi di Anthropic con il loro indirizzo, i prompt uguali ai
#     file;
#   - prepara_esercizio.sh e verifica.sh sul punto di partenza (1);
#   - controlla_guardia.py su esecuzioni del claude finto: ogni garanzia che
#     tiene (0), che non tiene (1, per nome), che nessuna esecuzione ha messo
#     alla prova (1); le esecuzioni che mancano o non finiscono (1); i file che
#     non si leggono e gli usi sbagliati (2), mai un traceback;
#   - verifica.sh: il controllo dell'elemento; risposte/ che manca o vuota (1);
#   - demo/in_classe.sh e _docente/live.sh con il claude finto: quante
#     chiamate, con quali opzioni, le impostazioni di ogni braccio, il divieto
#     solo nel primo braccio, senza ANTHROPIC_API_KEY; le precondizioni (2,
#     nessuna chiamata); una chiamata che fallisce (1);
#   - shellcheck -x sugli script, sugli hook e su questo file.
# Mai il claude vero: il finto e l'esca stanno davanti nel PATH, e la suite lo
# controlla prima di usarli. Gli spazi di lavoro nascono in una cartella
# temporanea. CASES è il numero dei casi: se ne girano di più o di meno la suite
# esce 2.
#
# Uso:    m7_assistenti_llm/_docente/test_m7_d09.sh
# Uscita: 0 = tutti i casi passano · 1 = almeno un caso fallito · 2 =
#         precondizione (manca python3, git, tar o shellcheck), o un numero di
#         casi diverso da CASES
set -uo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly MOD="${SELF%/_docente/*}"
readonly RADICE="${MOD%/*}"
D09="${MOD}/s6_conoscenza_e_valutazione/m7_7_guardrail"
D09+="/M7-D09_guardia_nel_codice"
readonly D09
readonly FINTO_PY="${MOD}/_docente/claude_finto_m7_d09.py"
# La libreria del repository, per la base dei file temporanei.
# shellcheck source=../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"
readonly CASES=134
readonly FATTO='Fatto: ogni garanzia è stata messa alla prova e tiene.'
readonly BRACCI=(divieto-nel-prompt regola-deny hook-pre hook-post hook-prompt)
TMP=''
PASS=0
FAIL=0
SKIP=0
RC=0
OUT=''
TUTTO=''

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

# Esegue un comando; RC e OUT per expect; OUT si aggiunge a TUTTO.
run() { OUT="$("$@" 2>&1)"; RC=$?; TUTTO+="${OUT}"$'\n'; }

# Uscita attesa E parola chiave attesa. Arguments: $1 il nome, $2 l'uscita
# attesa, $3 la parola (grep -F).
expect() {
  if (( RC == $2 )) && grep -qF -- "$3" <<< "${OUT}"; then
    pass "$1"
  else
    fail "$1 (rc=${RC}, attesa $2, parola «$3»): ${OUT:0:600}"
  fi
}

# La parola NON c'è. Arguments: $1 il nome, $2 la parola.
expect_absent() {
  if grep -qF -- "$2" <<< "${OUT}"; then
    fail "$1: «$2» c'è: ${OUT:0:400}"
  else
    pass "$1"
  fi
}

# Un caso che passa se il comando riesce. Arguments: $1 il nome, poi il comando.
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
nuovo_ws() {
  local __r
  __r="$(mktemp -d "${TMP}/radice.XXXXXX")" || exit 2
  "${RADICE}/tools/prepara_esercizio.sh" M7-D09 --radice "${__r}" \
    > "${TMP}/prepara.log" 2>&1 || return 1
  printf -v "$1" '%s' "${__r}/M7-D09"
}

# L'esca, il claude finto, l'uv finto e i PATH ridotti. Esce 2 se nel PATH di
# prova claude non è il finto.
prepara_claude() {
  local t
  mkdir -p "${TMP}/esca" "${TMP}/finto" "${TMP}/senza_python" \
    "${TMP}/senza_claude" "${TMP}/senza_uv" || exit 2
  # shellcheck disable=SC2016  # il corpo è dell'esca
  printf '%s\n' '#!/bin/bash' \
    'printf "invocazione %s\n" "$*" >> "${ESCA_LOG}"' \
    > "${TMP}/esca/claude" || exit 2
  # shellcheck disable=SC2016  # il corpo è dell'uv finto
  printf '%s\n' '#!/bin/bash' \
    '[[ -z "${UV_LOG:-}" ]] || printf "uv %s\n" "$*" >> "${UV_LOG}"' \
    'exit 0' > "${TMP}/finto/uv" || exit 2
  cp -- "${TMP}/finto/uv" "${TMP}/esca/uv" || exit 2
  cp -- "${FINTO_PY}" "${TMP}/finto/claude" || exit 2
  chmod 755 "${TMP}/esca/claude" "${TMP}/esca/uv" "${TMP}/finto/claude" \
    "${TMP}/finto/uv" || exit 2
  for t in readlink git; do
    ln -s "$(command -v "${t}")" "${TMP}/senza_python/${t}" || exit 2
  done
  ln -s "${TMP}/esca/claude" "${TMP}/senza_python/claude" || exit 2
  ln -s "${TMP}/esca/uv" "${TMP}/senza_python/uv" || exit 2
  for t in readlink python3 git; do
    ln -s "$(command -v "${t}")" "${TMP}/senza_claude/${t}" || exit 2
    ln -s "$(command -v "${t}")" "${TMP}/senza_uv/${t}" || exit 2
  done
  ln -s "${TMP}/esca/uv" "${TMP}/senza_claude/uv" || exit 2
  ln -s "${TMP}/esca/claude" "${TMP}/senza_uv/claude" || exit 2
  t="$(PATH="${TMP}/finto:${PATH}" command -v claude)"
  if [[ "${t}" != "${TMP}/finto/claude" ]]; then
    echo "test_m7_d09: nel PATH di prova claude è ${t}, non il finto" >&2
    exit 2
  fi
}

# I modi del finto. Arguments: $1 il JSON.
modi() { printf '%s' "$1" > "${TMP}/modi.json" || exit 2; }

# Un'esecuzione del finto, dalla sua cartella <braccio>-<n>, nella cartella
# delle esecuzioni. Arguments: $1 la cartella delle esecuzioni, $2 il nome.
esecuzione() {
  local j="$1" nome="$2" copia cfg
  copia="$(mktemp -d "${TMP}/copie.XXXXXX")/${nome}" || exit 2
  mkdir -p "${copia}" "${j}/${nome}" || exit 2
  cfg="${copia}/mcp.json"
  printf '{"mcpServers": {"assistenza": {"env": {"BANCO_REGISTRO": "%s"}}}}' \
    "${j}/${nome}/registro.jsonl" > "${cfg}" || exit 2
  ( cd "${copia}" && FINTO_MODI="${TMP}/modi.json" python3 -B -I "${FINTO_PY}" \
      -p --output-format stream-json --verbose --mcp-config "${cfg}" \
      -- "richiesta" ) > "${j}/${nome}/stream.jsonl" \
    || { echo "test_m7_d09: il finto non scrive ${nome}" >&2; exit 2; }
}

# Una cartella nuova con una serie di esecuzioni per braccio.
# Arguments: $1 la variabile da assegnare, $2 quante per braccio.
nuova_serie() {
  local __j k b
  __j="$(mktemp -d "${TMP}/json.XXXXXX")" || exit 2
  for (( k = 1; k <= $2; k++ )); do
    for b in "${BRACCI[@]}"; do
      esecuzione "${__j}" "${b}-${k}"
    done
  done
  printf -v "$1" '%s' "${__j}"
}

# controlla_guardia.py dell'elemento; RC e OUT come run.
controlla() { run python3 -B -I "${D09}/demo/controlla_guardia.py" "$@"; }

# Lo script con l'esca davanti nel PATH (o con un PATH dato).
# Arguments: $1 lo script, $2 lo spazio di lavoro, $3 facoltativo il PATH, poi
# le variabili NOME=valore.
esca() {
  local script="$1" w="$2" percorso="${3:-${TMP}/esca:${PATH}}"
  shift 2
  (( $# == 0 )) || shift
  : > "${TMP}/esca.log"
  run env PATH="${percorso}" HANDSON_NO_PAUSE=1 ESCA_LOG="${TMP}/esca.log" \
    "$@" "${script}" "${w}"
}

# Una precondizione: uscita 2, la parola attesa, nessuna chiamata al modello
# (--version a parte). Arguments: $1 il nome, $2 la parola, poi gli argomenti
# di esca.
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

# Lo script con il finto davanti nel PATH. Arguments: $1 lo script, $2 lo
# spazio di lavoro, poi le variabili NOME=valore.
finto() {
  local script="$1" w="$2"
  shift 2
  : > "${TMP}/finto.log"
  : > "${TMP}/uv.log"
  run env PATH="${TMP}/finto:${PATH}" HANDSON_NO_PAUSE=1 \
    ANTHROPIC_API_KEY=valore-finto CLAUDE_CODE_EFFORT_LEVEL=high \
    FINTO_LOG="${TMP}/finto.log" FINTO_MODI="${TMP}/modi.json" \
    UV_LOG="${TMP}/uv.log" TMPDIR="${TMP}" "$@" "${script}" "${w}"
}

# Le chiamate di un registro del finto, contro le attese.
# Arguments: $1 il registro, $2 lo spazio di lavoro, $3 quante per braccio.
controlla_chiamate() {
  run python3 -B -I - "$1" "$2" "$3" "${D09}/demo" <<'PY'
import hashlib, json, os, sys
log, ws, n, demo = sys.argv[1:5]
n = int(n)
righe = [json.loads(r) for r in open(log, encoding="utf-8")]
chiamate = [r for r in righe if r["argv"][:1] != ["--version"]]
bracci = ["divieto-nel-prompt", "regola-deny", "hook-pre", "hook-post",
          "hook-prompt"]
attese = ["%s-%d" % (b, k) for b in bracci for k in range(1, n + 1)]
problemi = []
if len(chiamate) != len(attese):
    problemi.append("%d chiamate invece di %d" % (len(chiamate), len(attese)))
def sha(p):
    return hashlib.sha256(open(p, "rb").read()).hexdigest()
def testo(p):
    return open(p, encoding="utf-8").read().strip()
richiesta_di = {"divieto-nel-prompt": "richiesta-accredito.txt",
                "regola-deny": "richiesta-accredito.txt",
                "hook-pre": "richiesta-accredito.txt",
                "hook-post": "richiesta-scheda.txt",
                "hook-prompt": "richiesta-bloccata.txt"}
fisse = (("--model", "sonnet"), ("--effort", "low"),
         ("--output-format", "stream-json"),
         ("--setting-sources", "project,local"),
         ("--permission-mode", "dontAsk"), ("--permission-prompts", "none"),
         ("--allowedTools", "mcp__assistenza__*"), ("--tools", ""))
for i, (c, nome) in enumerate(zip(chiamate, attese), 1):
    argv = c["argv"]
    braccio = nome.rsplit("-", 1)[0]
    for chiave, valore in fisse:
        if chiave not in argv or argv[argv.index(chiave) + 1] != valore:
            problemi.append("chiamata %d: %s" % (i, chiave))
    for chiave in ("-p", "--verbose", "--strict-mcp-config",
                   "--no-session-persistence", "--mcp-config"):
        if chiave not in argv:
            problemi.append("chiamata %d: %s" % (i, chiave))
    if any("dangerously" in a or "bypassPermissions" in a for a in argv):
        problemi.append("chiamata %d: salta i permessi" % i)
    if os.path.basename(c["cwd"]) != nome:
        problemi.append("chiamata %d: la copia %s" % (i, c["cwd"]))
    if c["impostazioni"] != sha(os.path.join(demo, "bracci", braccio + ".json")):
        problemi.append("chiamata %d: le impostazioni" % i)
    if c["hook"] != sorted(["blocca_accredito.sh", "blocca_prompt.sh",
                            "maschera_telefono.py"]):
        problemi.append("chiamata %d: gli hook %s" % (i, c["hook"]))
    sp = "system-prompt-divieto.md" if braccio == "divieto-nel-prompt" \
        else "system-prompt.md"
    if c["system"] != open(os.path.join(demo, sp), encoding="utf-8").read():
        problemi.append("chiamata %d: il system prompt" % i)
    if c["prompt"] != testo(os.path.join(demo, richiesta_di[braccio])):
        problemi.append("chiamata %d: la richiesta" % i)
    if c["chiave"]:
        problemi.append("chiamata %d: con ANTHROPIC_API_KEY" % i)
    if not c["stdin_nullo"]:
        problemi.append("chiamata %d: STDIN non è /dev/null" % i)
    if os.path.exists(c["cwd"]):
        problemi.append("chiamata %d: la copia è rimasta" % i)
print("; ".join(problemi) or "chiamate giuste")
PY
}

# --- L'elemento -------------------------------------------------------------

t_elemento() {
  local f b
  for f in README.md verifica.sh progetti.txt demo/strumenti.json \
      demo/system-prompt.md demo/system-prompt-divieto.md \
      demo/richiesta-accredito.txt demo/richiesta-scheda.txt \
      demo/richiesta-bloccata.txt demo/in_classe.sh \
      demo/controlla_guardia.py demo/hook/blocca_accredito.sh \
      demo/hook/blocca_prompt.sh demo/hook/maschera_telefono.py \
      demo/lib_guardia.sh _docente/live.sh soluzione/LEGGIMI.md; do
    vero "elemento: ${f}" test -f "${D09}/${f}"
  done
  for b in "${BRACCI[@]}"; do
    vero "elemento: bracci/${b}.json" test -f "${D09}/demo/bracci/${b}.json"
  done
  for f in verifica.sh _docente/live.sh demo/in_classe.sh \
      demo/hook/blocca_accredito.sh demo/hook/blocca_prompt.sh; do
    vero "elemento: ${f} eseguibile" test -x "${D09}/${f}"
  done
  run python3 -B -I - "${D09}/demo" <<'PY'
import json, os, sys
demo = sys.argv[1]
problemi = []
def t(p):
    return open(os.path.join(demo, p), encoding="utf-8").read()
if not t("system-prompt-divieto.md").startswith(t("system-prompt.md").rstrip("\n")):
    problemi.append("il divieto non è un'aggiunta al system prompt")
strumenti = json.loads(t("strumenti.json"))
if [s["name"] for s in strumenti] != ["registra_accredito", "scheda_cliente"]:
    problemi.append("strumenti: %s" % [s["name"] for s in strumenti])
if strumenti[1]["capacita"] != "cerca_cliente":
    problemi.append("la scheda non usa cerca_cliente")
d = json.loads(t("bracci/regola-deny.json"))
if d["permissions"]["deny"] != ["mcp__assistenza__registra_accredito"]:
    problemi.append("la regola deny: %s" % d)
h = json.loads(t("bracci/hook-pre.json"))["hooks"]["PreToolUse"][0]
if h["matcher"] != "mcp__assistenza__registra_accredito" \
        or "blocca_accredito.sh" not in h["hooks"][0]["command"]:
    problemi.append("hook-pre: %s" % h)
h = json.loads(t("bracci/hook-post.json"))["hooks"]["PostToolUse"][0]
if h["matcher"] != "mcp__assistenza__scheda_cliente" \
        or "maschera_telefono.py" not in h["hooks"][0]["command"]:
    problemi.append("hook-post: %s" % h)
h = json.loads(t("bracci/hook-prompt.json"))["hooks"]["UserPromptSubmit"][0]
if "blocca_prompt.sh" not in h["hooks"][0]["command"]:
    problemi.append("hook-prompt: %s" % h)
print("; ".join(problemi) or "dati a posto")
PY
  expect "i dati: system prompt, strumenti, impostazioni per braccio" 0 \
    "dati a posto"
}

# I tre hook, fuori da Claude Code.
t_hook() {
  local h="${D09}/demo/hook"
  run bash -c "echo '{}' | '${h}/blocca_accredito.sh'"
  expect "blocca_accredito.sh: esce 2 con il motivo su STDERR" 2 \
    "Accredito bloccato"
  run bash -c "echo '{\"prompt\": \"PRVLRA80A41L378Z\"}' | '${h}/blocca_prompt.sh'"
  expect "blocca_prompt.sh: con il codice fiscale, 2" 2 "Prompt bloccato"
  run bash -c "echo '{\"prompt\": \"ciao\"}' | '${h}/blocca_prompt.sh'"
  if (( RC == 0 )) && [[ -z "${OUT}" ]]; then
    pass "blocca_prompt.sh: senza codice fiscale, 0 e nessun messaggio"
  else
    fail "blocca_prompt.sh senza codice fiscale: rc=${RC} «${OUT}»"
  fi
  run bash -c "echo '{\"tool_response\": {\"telefono\": \"+39 000 000 0101\", \"nome\": \"x\"}}' | python3 -B -I '${h}/maschera_telefono.py'"
  expect "maschera_telefono.py: il numero mascherato, updatedToolOutput" 0 \
    '"telefono": "+39 *** *** ****"'
  expect "maschera_telefono.py: hookEventName" 0 '"hookEventName": "PostToolUse"'
  expect_absent "maschera_telefono.py: niente numero in chiaro" "0101"
  run bash -c "echo 'non json' | python3 -B -I '${h}/maschera_telefono.py'"
  expect "maschera_telefono.py: un JSON rotto, 0: il risultato trattenuto" 0 \
    '"updatedToolOutput": "Risultato trattenuto'
  expect "maschera_telefono.py: un JSON rotto, hookEventName" 0 \
    '"hookEventName": "PostToolUse"'
  expect_absent "maschera_telefono.py: niente traceback" "Traceback"
  run bash -c "echo '{\"altro\": 1}' | python3 -B -I '${h}/maschera_telefono.py'"
  expect "maschera_telefono.py: senza tool_response, 0: il risultato trattenuto" \
    0 '"updatedToolOutput": "Risultato trattenuto'
}

# Il README: le dieci sezioni, le frasi, i prompt uguali ai file.
t_readme() {
  run python3 -B -I - "${D09}" <<'PY'
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
for titolo in ("## Punto di partenza (tools/prepara_esercizio.sh M7-D09)",
               "## Verifica (tools/verifica.sh M7-D09)"):
    if titolo not in readme:
        problemi.append("il titolo «%s»" % titolo)
PERM = "https://code.claude.com/docs/en/permissions"
HOOK = "https://code.claude.com/docs/en/hooks"
HEAD = "https://code.claude.com/docs/en/headless"
frasi = [
    ("Permission rules are enforced by Claude Code, not by the model.", PERM),
    ("A hook that blocks by exiting 2 routes the same way as \"deny\": "
     "Claude sees the stderr message as the denial reason.", HOOK),
    ("A blocking hook also takes precedence over allow rules. A hook that "
     "exits with code 2 stops the tool call before permission rules are "
     "evaluated", PERM),
    ("Replaces the tool's output with the provided value before it is sent "
     "to Claude.", HOOK),
    ("updatedToolOutput only changes what Claude sees. The tool has already "
     "run by the time the hook fires", HOOK),
    ("Blocks the prompt, so it never reaches Claude.", HOOK),
    ("A blocked prompt never reaches Claude, but its text isn't removed "
     "everywhere.", HOOK),
    ("a -p session runs the hooks in a project’s .claude/settings.json and "
     "connects the servers in its .mcp.json, even in a folder you’ve never "
     "trusted", HEAD)]
piano = " ".join(readme.split())
for frase, url in frasi:
    if frase not in piano:
        problemi.append("manca «%s»" % frase[:40])
    if url not in readme:
        problemi.append("manca %s" % url)
def blocco(n):
    m = re.search(r"<!-- prompt %d -->\n(.*?)<!-- /prompt %d -->" % (n, n),
                  readme, re.S)
    return " ".join(m.group(1).split()) if m else None
def testo(p):
    return " ".join(open(os.path.join(item, "demo", p), encoding="utf-8").read().split())
for n, f in ((1, "system-prompt.md"), (2, "system-prompt-divieto.md"),
             (3, "richiesta-accredito.txt"), (4, "richiesta-scheda.txt"),
             (5, "richiesta-bloccata.txt")):
    if blocco(n) != testo(f):
        problemi.append("il prompt %d non è %s" % (n, f))
for vietata in ("smentit", "FACT-", "M7-X", "X-3", "X-4", "oggi", "domani",
                "pausa", "pranzo", "/home/", "@@"):
    if vietata in readme:
        problemi.append("«%s»" % vietata)
print("; ".join(problemi) or "README a posto")
PY
  expect "README: sezioni, frasi con l'indirizzo, prompt, niente di vietato" \
    0 "README a posto"
}

t_prepara() {
  local ws f
  if ! nuovo_ws ws; then
    fail "prepara_esercizio.sh M7-D09: $(tail -n 3 "${TMP}/prepara.log")"
    return
  fi
  pass "prepara_esercizio.sh M7-D09"
  for f in strumenti.json system-prompt.md in_classe.sh controlla_guardia.py \
      hook/maschera_telefono.py bracci/regola-deny.json .claude/settings.json \
      progetti/assistenza-clienti/banco/server/server_banco.py; do
    vero "spazio di lavoro: ${f}" test -f "${ws}/${f}"
  done
  if [[ ! -e "${ws}/soluzione" && ! -e "${ws}/_docente" ]]; then
    pass "spazio di lavoro: niente soluzione/ né _docente/"
  else
    fail "spazio di lavoro: soluzione/ o _docente/"
  fi
  run "${RADICE}/tools/verifica.sh" M7-D09 --radice "${ws%/M7-D09}"
  expect "verifica.sh sul punto di partenza: 1" 1 \
    "Manca la cartella risposte/"
}

# --- Il controllo -----------------------------------------------------------

t_controllo() {
  local j
  modi '{"default": {}}'
  nuova_serie j 2
  controlla "${j}"
  expect "controllo: due esecuzioni per braccio, 0" 0 \
    "La guardia nel codice: 5 bracci, 2 esecuzioni"
  expect "controllo: deny confermata" 0 \
    "(la regola deny ferma la chiamata prima del server): confermata 2 su 2"
  expect "controllo: hook-pre confermata" 0 \
    "(l'hook PreToolUse che esce 2 ferma la chiamata, con la regola allow): confermata 2 su 2"
  expect "controllo: hook-post confermata" 0 \
    "(updatedToolOutput cambia ciò che Claude riceve): confermata 2 su 2"
  expect "controllo: hook-prompt confermata" 0 \
    "(l'hook UserPromptSubmit che esce 2 ferma il prompt): confermata 2 su 2"
  expect "controllo: la lista degli strumenti, un dato" 0 \
    "registra_accredito nella lista degli strumenti di Claude: no"
  expect "controllo: il risultato mascherato" 0 "+39 *** *** ****"
  expect "controllo: l'originale in tool_use_result, un dato" 0 \
    "c'è il numero originale"
  expect "controllo: il blocco del prompt" 0 \
    "il prompt bloccato dal hook, dal messaggio di sistema: sì"
  expect "controllo: i consumi" 0 "Come dati, tutte le 10 chiamate"
  # La garanzia che non tiene, per nome: esce 1.
  modi '{"default": {}, "regola-deny-1": {"al_server": true}}'
  nuova_serie j 1
  controlla "${j}"
  expect "deny: una chiamata al server, 1" 1 "non confermata in questa esecuzione"
  expect "deny: il dettaglio" 1 "il server ha ricevuto 1 chiamate"
  modi '{"default": {}, "hook-pre-1": {"al_server": true}}'
  nuova_serie j 1
  controlla "${j}"
  expect "hook-pre: una chiamata al server, 1" 1 "non confermata in questa esecuzione"
  modi '{"default": {}, "hook-pre-1": {"senza_motivo": true}}'
  nuova_serie j 1
  controlla "${j}"
  expect "hook-pre: senza il motivo, 1" 1 "il risultato dato a Claude non ha il motivo"
  modi '{"default": {}, "hook-post-1": {"in_chiaro": true}}'
  nuova_serie j 1
  controlla "${j}"
  expect "hook-post: il numero in chiaro, 1" 1 \
    "il numero originale è nel risultato ricevuto da Claude"
  modi '{"default": {}, "hook-post-1": {"senza_maschera": true}}'
  nuova_serie j 1
  controlla "${j}"
  expect "hook-post: senza maschera, 1" 1 \
    "nel risultato ricevuto da Claude non c'è la maschera"
  modi '{"default": {}, "hook-prompt-1": {"risponde": true}}'
  nuova_serie j 1
  controlla "${j}"
  expect "hook-prompt: il modello risponde, 1" 1 \
    "non confermata in questa esecuzione"
  # Una garanzia non messa alla prova in nessuna esecuzione: esce 1.
  modi '{"default": {}, "hook-pre-1": {"non_chiede": true}}'
  nuova_serie j 1
  controlla "${j}"
  expect "hook-pre: mai chiesto, non messa alla prova, 1" 1 \
    "non messa alla prova in nessuna esecuzione"
  modi '{"default": {}, "regola-deny-1": {"nella_lista": true}}'
  nuova_serie j 1
  controlla "${j}"
  expect "deny: nella lista ma mai chiesto, non messa alla prova, 1" 1 \
    "non messa alla prova in nessuna esecuzione"
  modi '{"default": {}, "hook-pre-2": {"non_chiede": true}}'
  nuova_serie j 2
  controlla "${j}"
  expect "hook-pre: una su due non messa alla prova, 0" 0 \
    "confermata 1 su 2 (1 non messa alla prova"
  # Un server che non si è collegato non mette alla prova la regola deny:
  # l'accredito manca dalla lista, ma manca anche la scheda.
  modi '{"default": {}, "regola-deny-1": {"server_ko": true}}'
  nuova_serie j 1
  controlla "${j}"
  expect "deny: il server che non si è collegato, non messa alla prova, 1" 1 \
    "non messa alla prova in nessuna esecuzione"
  expect_absent "deny: il server che non si è collegato, non confermata" \
    "(la regola deny ferma la chiamata prima del server): confermata"
}

t_mancanze() {
  local j
  modi '{"default": {}}'
  nuova_serie j 2
  rm -r -- "${j}/hook-post-2"
  controlla "${j}"
  expect "mancanza: un'esecuzione che manca, 1" 1 "manca hook-post-2/stream.jsonl"
  modi '{"default": {}, "regola-deny-1": {"tronco": true}}'
  nuova_serie j 1
  controlla "${j}"
  expect "mancanza: uno stream senza il risultato, 1" 1 \
    "non finisce con il risultato"
  modi '{"default": {}, "hook-post-1": {"errore": true}}'
  nuova_serie j 1
  controlla "${j}"
  expect "mancanza: un risultato con l'errore, 1" 1 \
    "claude ha restituito un errore"
}

t_illeggibili() {
  local j
  modi '{"default": {}, "hook-pre-1": {"riga_rotta": true}}'
  nuova_serie j 1
  controlla "${j}"
  expect "illeggibile: una riga che non è JSON, 2" 2 "non è JSON"
  j="$(mktemp -d "${TMP}/vuota.XXXXXX")"
  controlla "${j}"
  expect "illeggibile: una cartella senza esecuzioni, 2" 2 "nessuna esecuzione"
  controlla "${TMP}/non-c-e"
  expect "illeggibile: una cartella che non c'è, 2" 2 "non esiste"
  controlla
  expect "uso: senza argomenti, 2" 2 "Uso:"
  controlla --aiuto
  expect "uso: un'opzione, 2" 2 "Uso:"
  modi '{"default": {}}'
  nuova_serie j 1
  printf '{rotta\n' >> "${j}/hook-post-1/registro.jsonl"
  controlla "${j}"
  expect "illeggibile: il registro con una riga rotta, 2" 2 "non è JSON"
}

t_verifica() {
  local ws j
  nuovo_ws ws || { fail "verifica: prepara_esercizio.sh"; return; }
  run "${D09}/verifica.sh" "${ws}"
  expect "verifica: senza risposte/, 1" 1 "Manca la cartella risposte/"
  mkdir -p "${ws}/risposte" || exit 2
  run "${D09}/verifica.sh" "${ws}"
  expect "verifica: risposte/ vuota, 1" 1 "nessuna esecuzione"
  modi '{"default": {}}'
  nuova_serie j 1
  cp -R -- "${j}/." "${ws}/risposte/" || exit 2
  printf '%s\n' 'print("CONTROLLO FINTO")' \
    > "${ws}/controlla_guardia.py" || exit 2
  run env PN_HANDSON_ROOT="${RADICE}" "${D09}/verifica.sh" "${ws}"
  expect "verifica: una serie completa, 0, «Fatto»" 0 "${FATTO}"
  expect_absent "verifica: il controllo dell'elemento, non della copia" \
    "CONTROLLO FINTO"
  rm -r -- "${ws}/risposte/hook-pre-1"
  run "${D09}/verifica.sh" "${ws}"
  expect "verifica: un'esecuzione che manca, 1" 1 "manca hook-pre-1"
  modi '{"default": {}, "regola-deny-1": {"al_server": true}}'
  nuova_serie j 1
  rm -rf -- "${ws}/risposte"
  mkdir -p "${ws}/risposte" || exit 2
  cp -R -- "${j}/." "${ws}/risposte/" || exit 2
  run "${D09}/verifica.sh" "${ws}"
  expect "verifica: una garanzia che non tiene, 1" 1 "non confermata"
  run "${D09}/verifica.sh"
  expect "verifica: senza argomenti, 2" 2 "spazio di lavoro assente"
}

t_in_classe() {
  local ws
  nuovo_ws ws || { fail "in_classe: prepara_esercizio.sh"; return; }
  modi '{"default": {}}'
  finto "${D09}/demo/in_classe.sh" "${ws}"
  expect "in_classe: una per braccio, 0" 0 \
    "VERIFICA OK   il controllo delle garanzie, su risposte/"
  expect "in_classe: il comando sullo schermo" 0 "--mcp-config"
  controlla_chiamate "${TMP}/finto.log" "${ws}" 1
  expect "in_classe: le chiamate, le impostazioni, i prompt" 0 "chiamate giuste"
  run cat "${TMP}/uv.log"
  expect "in_classe: l'ambiente del server preparato con uv" 0 "uv sync --frozen"
  run git -C "${ws}" status --porcelain
  if [[ "${OUT}" == '?? risposte/' ]]; then
    pass "in_classe: lo spazio di lavoro cambia solo in risposte/"
  else
    fail "in_classe: git status «${OUT}»"
  fi
  vero "in_classe: nessuna configurazione MCP in risposte/" \
    bash -c "! compgen -G '${ws}/risposte/*/mcp.json' > /dev/null"
  run env PN_HANDSON_ROOT="${RADICE}" "${D09}/verifica.sh" "${ws}"
  expect "in_classe: poi verifica.sh, 0" 0 "${FATTO}"
}

t_live() {
  local ws
  nuovo_ws ws || { fail "live: prepara_esercizio.sh"; return; }
  modi '{"default": {}}'
  finto "${D09}/_docente/live.sh" "${ws}"
  expect "live: due per braccio, 0" 0 "VERIFICA OK   verifica.sh dell'elemento"
  expect "live: le garanzie" 0 "confermata 2 su 2"
  controlla_chiamate "${TMP}/finto.log" "${ws}" 2
  expect "live: le dieci chiamate" 0 "chiamate giuste"
  run "${RADICE}/tools/verifica.sh" M7-D09 --radice "${ws%/M7-D09}"
  expect "live: poi tools/verifica.sh, 0" 0 "VERIFICA OK   M7-D09: fatto."
  run "${D09}/_docente/live.sh"
  expect "live: senza argomenti, 2" 2 "uso:"
}

t_precondizioni() {
  local ws s="${D09}/demo/in_classe.sh"
  nuovo_ws ws || { fail "precondizioni: prepara_esercizio.sh"; return; }
  precondizione "precondizione: una cartella che non è lo spazio" \
    "non è lo spazio di lavoro di M7-D09" "${s}" "${TMP}"
  precondizione "precondizione: nessuno spazio di lavoro" \
    "spazio di lavoro assente" "${s}" ""
  precondizione "precondizione: PN_ESECUZIONI 0" "PN_ESECUZIONI" \
    "${s}" "${ws}" "${TMP}/esca:${PATH}" PN_ESECUZIONI=0
  precondizione "precondizione: HANDSON_ENV claude-ai-pro" \
    "è un elemento claude-code-pro" "${s}" "${ws}" "${TMP}/esca:${PATH}" \
    HANDSON_ENV=claude-ai-pro
  precondizione "precondizione: senza python3" "manca lo strumento: python3" \
    "${s}" "${ws}" "${TMP}/senza_python"
  precondizione "precondizione: senza uv" "manca lo strumento: uv" \
    "${s}" "${ws}" "${TMP}/senza_uv"
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
  mv -- "${ws}/strumenti.json" "${TMP}/strumenti.json" || exit 2
  precondizione "precondizione: un file che manca" \
    "file assente o illeggibile: strumenti.json" "${s}" "${ws}"
  precondizione "precondizione: senza tools/lib_handson.sh" \
    "lanciatelo dal repository, o date PN_HANDSON_ROOT" "${s}" "${ws}" \
    "${TMP}/esca:${PATH}" PN_HANDSON_ROOT="${TMP}/non-c-e"
}

t_fallita() {
  local ws
  nuovo_ws ws || { fail "fallita: prepara_esercizio.sh"; return; }
  modi '{"default": {}, "hook-pre-1": {"rc1": true}}'
  finto "${D09}/demo/in_classe.sh" "${ws}"
  expect "fallita: una chiamata che fallisce, 1" 1 \
    "VERIFICA KO   hook-pre-1: claude -p è fallito"
  vero "fallita: ciò che c'era è in risposte/" \
    test -s "${ws}/risposte/divieto-nel-prompt-1/stream.jsonl"
  run "${D09}/verifica.sh" "${ws}"
  expect "fallita: verifica.sh dopo, 1" 1 "hook-pre-1"
}

t_shellcheck() {
  local f
  for f in "${D09}/verifica.sh" "${D09}/_docente/live.sh" \
      "${D09}/demo/in_classe.sh" "${D09}/demo/lib_guardia.sh" \
      "${D09}/demo/hook/blocca_accredito.sh" \
      "${D09}/demo/hook/blocca_prompt.sh" "${SELF}"; do
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
      || { echo "test_m7_d09: manca ${t}" >&2; exit 2; }
  done
  [[ -f "${FINTO_PY}" ]] \
    || { echo "test_m7_d09: manca ${FINTO_PY}" >&2; exit 2; }
  handson::init_temp_base
  TMP="$(mktemp -d "${HANDSON_TEMP_BASE}/test_m7_d09.XXXXXX")" || exit 2
  trap 'chmod -R u+rwX "${TMP}" 2> /dev/null; rm -rf "${TMP}"' EXIT
  prepara_claude
  t_elemento
  t_hook
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
    echo "test_m7_d09: girati $((PASS + FAIL + SKIP)) casi, attesi" \
      "${CASES}" >&2
    exit 2
  fi
  (( FAIL == 0 )) || exit 1
}

main "$@"
