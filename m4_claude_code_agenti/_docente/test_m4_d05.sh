#!/bin/bash
#
# test_m4_d05.sh -- le prove di M4-D05 «Il controllo che non si salta», per
# il docente (sta in _docente/, il materiale del docente):
#   - il punto di partenza: il prompt chiede soltanto la docstring; le
#     impostazioni dei due bracci differiscono soltanto nello Stop hook,
#     che ha la forma della prova (i test su stderr, uscita 2 se
#     falliscono), e hanno le regole prudenti del repository; nessun file
#     di demo/ accenna al difetto; nuova_copia.sh è quella di M4-D03;
#     prepara_esercizio.sh porta tutto nello spazio di lavoro, e lì
#     verifica.sh esce 1; _docente/lib_stop.sh c'è e non è eseguibile;
#   - controlla_stop.py su stream e copie finti scritti qui (percorsi
#     sintetici sotto /tmp/m4ws): i blocchi dello Stop hook e i blocchi di
#     fila senza strumenti, gli strumenti, i file cambiati, i test
#     rieseguiti; le garanzie (con l'hook i test verdi, salvo il tetto
#     degli otto blocchi: altrimenti una segnalazione, uscita 1), il «non
#     distinguibile» senza blocchi, e nessun blocco in nessuna esecuzione
#     con l'hook (1, «Non ancora»), ma non se un'altra ha un blocco (0);
#     il comportamento «n su N», il braccio senza hook come dato; le
#     coppie che non vanno (impostazioni del braccio sbagliate o diverse
#     in altro, blocchi senza hook, modelli diversi, un braccio che manca)
#     con l'uscita 1; gli stream rovinati; un'esecuzione rovinata accanto a
#     una buona (1, con il consiglio di toglierne la cartella), poi tolta
#     (0); le precondizioni con l'uscita 2;
#   - verifica.sh: spazio di lavoro assente (2), punto di partenza (1),
#     coppia buona (0, la frase finale), una segnalazione (1), python3 che
#     manca (2), un controllo che esce 3 o per un segnale (2);
#   - _docente/live.sh: le precondizioni escono 2 senza chiamare claude
#     (l'esca), anche uno spazio di lavoro che non è un repository git o
#     non è al punto di partenza, e le impostazioni dei due bracci che,
#     tolto l'hook, differiscono o non sono JSON; con il claude finto
#     (claude_finto_m4_urgenze.py), che
#     esegue davvero lo Stop hook della copia: i due bracci con il testo e
#     le opzioni del README (il suo blocco gira con lo stesso finto, e le
#     chiamate si confrontano), acceptEdits, dalla copia, senza
#     ANTHROPIC_API_KEY; --esecuzioni 2; il tetto (0), una garanzia che
#     non tiene (1), l'hook ignorato (1), un test allentato (0); la prima
#     chiamata fallita; i controlli della libreria che live.sh riusa;
#   - il README: «l'hook», mai «lo hook»; la cartella rovinata da togliere
#     prima di rifarla; cd - prima della verifica;
#   - shellcheck -x su verifica.sh, live.sh, lib_stop.sh, nuova_copia.sh e
#     questo file.
# Mai il claude vero: il finto e l'esca stanno davanti nel PATH, e la
# suite lo controlla prima di usarli. Gli stream finti non sono risposte
# di Claude: provano il controllo, non il modello. Gli spazi di lavoro
# nascono in una cartella temporanea, nella base di handson::init_temp_base:
# l'albero del repository non cambia. CASES è il numero dei casi: se ne
# girano di più o di meno la suite esce 2 (un caso saltato conta come
# girato).
#
# Uso:    m4_claude_code_agenti/_docente/test_m4_d05.sh
# Uscita: 0 = tutti i casi passano · 1 = almeno un caso fallito · 2 =
#         precondizione (manca python3, git o shellcheck, o la cartella
#         dell'elemento), o un numero di casi diverso da CASES
set -uo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly MOD="${SELF%/_docente/*}"
readonly RADICE="${MOD%/*}"
D05="${MOD}/s3_agente_nel_repository/m4_7_rete_di_sicurezza"
D05+="/M4-D05_controllo_che_non_si_salta"
readonly D05
D03="${MOD}/s3_agente_nel_repository/m4_5_ciclo_strumenti"
D03+="/M4-D03_giro_del_ciclo"
readonly D03
readonly FINTO_PY="${MOD}/_docente/claude_finto_m4_urgenze.py"
readonly URG="${RADICE}/progetti/urgenze"
# shellcheck source=../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"
readonly CASES=132
FINE='Fatto: ogni affermazione è stata messa alla prova;'
FINE+=' gli esiti sono qui sopra.'
readonly FINE
PARTENZA='Manca la cartella esecuzioni/ con le esecuzioni con-hook-<n> e'
PARTENZA+=' senza-hook-<n>: eseguite i passi del README.'
readonly PARTENZA
readonly S_BLOCCA="L'uscita 2 dello Stop hook blocca la fine del turno"
readonly S_CONTINUA='Claude continua finché il controllo passa'
readonly S_SENZA='Senza lo Stop hook, i test verdi alla fine'
readonly NONCONF='non confermata in questa esecuzione'
NESSUNA_PROVA="Non ancora: in nessuna esecuzione con l'hook lo Stop hook ha"
NESSUNA_PROVA+=' bloccato la fine del turno'
readonly NESSUNA_PROVA
# shellcheck disable=SC2016  # $CLAUDE_PROJECT_DIR è del comando dell'hook
HOOK='cd "$CLAUDE_PROJECT_DIR" && python3 -m unittest -q 1>&2 || exit 2'
readonly HOOK
readonly STRUMENTI='Read,Edit,Bash(python3 -m unittest*)'
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
    fail "$1 (rc=${RC}, attesa $2, parola «$3»): ${OUT:0:400}"
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

# Un nuovo spazio di lavoro, come lo prepara prepara_esercizio.sh (senza
# git): demo/, il progetto senza _docente/, le impostazioni del
# repository. Arguments: $1 la variabile da assegnare.
ws() {
  local __w
  __w="$(mktemp -d "${TMP}/ws.XXXXXX")" || { echo "mktemp" >&2; exit 2; }
  if ! cp -R "${D05}/demo/." "${__w}/" \
      || ! mkdir -p "${__w}/progetti/urgenze" "${__w}/.claude" \
      || ! cp -p "${URG}/README.md" "${URG}/genera.py" "${URG}/urgenza.py" \
        "${URG}/test_urgenza.py" "${__w}/progetti/urgenze/" \
      || ! cp -p "${RADICE}/.claude/settings.json" "${__w}/.claude/"; then
    echo "test_m4_d05: non riesco a preparare lo spazio di lavoro" >&2
    exit 2
  fi
  printf -v "$1" '%s' "${__w}"
}

# Uno spazio di lavoro come ws, e in più il repository git con un commit
# che gli dà prepara_esercizio.sh (handson::git_init_workspace): live.sh
# parte soltanto da lì. Arguments: $1 la variabile da assegnare.
ws_git() {
  local __g
  ws __g
  if ! handson::git_init_workspace "${__g}" M4-D05 > /dev/null 2>&1; then
    echo "test_m4_d05: git non riesce ad aprire lo spazio di lavoro" >&2
    exit 2
  fi
  printf -v "$1" '%s' "${__g}"
}

# Fissa nel repository dello spazio di lavoro un file cambiato da un caso,
# così che git status torni vuoto. Arguments: $1 lo spazio di lavoro.
fissa() {
  git -C "$1" -c user.name=Prova -c user.email=prova@example.org \
    -c commit.gpgsign=false commit -q --no-verify -am 'un caso di prova' \
    || { echo "test_m4_d05: git commit non riesce" >&2; exit 2; }
}

# La copia di un'esecuzione, in esecuzioni/<nome>/urgenze/, con il codice
# «verde» (il confine corretto), «rossa» (com'è) o «allentata» (il test
# del confine cambiato), e le impostazioni del braccio: «con» o «senza»
# (i file di demo/impostazioni/), «nessuna», oppure «altra» (quelle senza
# hook con una regola in più).
# Arguments: $1 lo spazio di lavoro, $2 il nome, $3 il codice, $4 le
# impostazioni.
copia() {
  local c="$1/esecuzioni/$2/urgenze"
  mkdir -p "${c}/.claude" || exit 2
  cp -p "${URG}/urgenza.py" "${URG}/test_urgenza.py" "${c}/" || exit 2
  case "$3" in
    verde)
      sed -i 's/giorni_aperta > 7/giorni_aperta >= 7/' "${c}/urgenza.py" ;;
    allentata)
      sed -i 's/assertTrue(urgente(1, 7))/assertFalse(urgente(1, 7))/' \
        "${c}/test_urgenza.py" ;;
  esac
  case "$4" in
    con) cp "${D05}/demo/impostazioni/con-hook.json" \
           "${c}/.claude/settings.json" ;;
    senza) cp "${D05}/demo/impostazioni/senza-hook.json" \
             "${c}/.claude/settings.json" ;;
    altra) sed 's/"Read(\*\*\/\*.key)"/"Read(**\/*.key)", "Read(.\/x)"/' \
             "${D05}/demo/impostazioni/senza-hook.json" \
             > "${c}/.claude/settings.json" ;;
  esac
}

# Scrive lo stream finto di un'esecuzione in esecuzioni/<nome>/stream.jsonl.
# Arguments: $1 lo spazio di lavoro, $2 il nome dell'esecuzione, poi le
# voci, nell'ordine:
#   R[:<strumenti>]  una richiesta con gli strumenti separati da virgole
#       (Read, Edit, Bash; «!» un errore, «?» un permesso negato), oppure
#       un testo;
#   B  il blocco di uno Stop hook (il messaggio sintetico e la notifica);
#   T  una richiesta con un testo che contiene U+2028 e U+0085, che JSON
#       lascia nella riga così come sono;
#   +tronco, +solo, +errore, +subtype; +modello=<m>, +modo=<m> per
#   l'evento di avvio.
stream() {
  python3 -B -I - "$@" <<'PY'
import json, os, sys
ws, nome = sys.argv[1:3]
voci = sys.argv[3:]
cwd = "/tmp/m4ws/esecuzioni/%s/urgenze" % nome
avvio = {"type": "system", "subtype": "init", "cwd": cwd,
         "session_id": "finta", "model": "modello-finto",
         "permissionMode": "acceptEdits", "claude_code_version": "9.9.9"}
for v in voci:
    if v.startswith("+modello="):
        avvio["model"] = v.split("=", 1)[1]
    if v.startswith("+modo="):
        avvio["permissionMode"] = v.split("=", 1)[1]
eventi = [avvio]
dinieghi = []
ingressi = {"Read": {"file_path": cwd + "/urgenza.py"},
            "Edit": {"file_path": cwd + "/urgenza.py", "old_string": "a",
                     "new_string": "b"},
            "Bash": {"command": "python3 -m unittest"}}
n_msg = n_tool = 0
entrata = 17000
for voce in voci:
    if voce.startswith("+"):
        continue
    if voce == "B":
        eventi.append({"type": "user", "isSynthetic": True,
                       "parent_tool_use_id": None,
                       "message": {"role": "user", "content": [{
                           "type": "text",
                           "text": "Stop hook feedback:\n[comando finto]: "
                                   "FAILED (failures=1)\n"}]}})
        eventi.append({"type": "system", "subtype": "notification",
                       "key": "stop-hook-error",
                       "text": "Stop hook error occurred"})
        continue
    n_msg += 1
    entrata += 300
    usage = {"input_tokens": 1, "cache_read_input_tokens": entrata - 1,
             "output_tokens": 5}
    _, _, strumenti = voce.partition(":")
    blocchi = []
    for s in (x for x in strumenti.split(",") if x):
        n_tool += 1
        blocchi.append((s, {"type": "tool_use", "id": "toolu_%d" % n_tool,
                            "name": s.rstrip("!?"),
                            "input": ingressi.get(s.rstrip("!?"), {})}))
    if not blocchi:
        testo = "riga separata\u0085fine" if voce == "T" \
            else "risposta finta"
        blocchi = [("", {"type": "text", "text": testo})]
    for s, b in blocchi:
        eventi.append({"type": "assistant", "parent_tool_use_id": None,
                       "message": {"id": "msg_%d" % n_msg,
                                   "role": "assistant", "content": [b],
                                   "usage": usage}})
        if b["type"] != "tool_use":
            continue
        res = {"type": "tool_result", "tool_use_id": b["id"],
               "content": "finto"}
        if s.endswith("?"):
            dinieghi.append({"tool_name": b["name"], "tool_use_id": b["id"]})
        if s.endswith(("!", "?")):
            res["is_error"] = True
        eventi.append({"type": "user", "parent_tool_use_id": None,
                       "message": {"role": "user", "content": [res]}})
risultato = {"type": "result", "subtype": "success", "is_error": False,
             "result": "finto", "num_turns": n_msg, "duration_ms": 9000,
             "permission_denials": dinieghi}
if "+errore" in voci:
    risultato["is_error"] = True
if "+subtype" in voci:
    risultato["subtype"] = "error_during_execution"
if "+solo" in voci:
    eventi = []
if "+tronco" not in voci:
    eventi.append(risultato)
d = os.path.join(ws, "esecuzioni", nome)
os.makedirs(d, exist_ok=True)
with open(os.path.join(d, "stream.jsonl"), "w", encoding="utf-8") as fh:
    for e in eventi:
        fh.write(json.dumps(e, ensure_ascii=False) + "\n")
PY
}

# Il braccio con l'hook come nella prova: la docstring, un blocco, il
# confine corretto, i test verdi. Arguments: $1 lo spazio, $2 il nome.
con_buona() {
  copia "$1" "${2:-con-hook-1}" verde con
  stream "$1" "${2:-con-hook-1}" R:Read R:Edit R B R:Edit R
}

# Il braccio senza hook come nella prova: la docstring, i test rossi.
# Arguments: $1 lo spazio, $2 il nome.
senza_buona() {
  copia "$1" "${2:-senza-hook-1}" rossa senza
  stream "$1" "${2:-senza-hook-1}" R:Read R:Edit R
}

# Il controllo dell'elemento sullo spazio di lavoro $1 (gli argomenti che
# seguono vanno prima); RC e OUT come run.
controlla() {
  local w="$1"
  shift
  run python3 -B -I "${D05}/controlla_stop.py" "$@" "${w}"
}

# Il ramo dell'errore inatteso: main() del controllo con un controlla()
# che solleva un'eccezione. Arguments: gli argomenti di main.
inatteso() {
  run python3 -B -I -c 'import importlib.util, sys
spec = importlib.util.spec_from_file_location("controllo", sys.argv[1])
modulo = importlib.util.module_from_spec(spec)
spec.loader.exec_module(modulo)
def guasto(*_):
    raise RuntimeError("guasto finto")
modulo.controlla = guasto
sys.exit(modulo.main(sys.argv[2:]))' "${D05}/controlla_stop.py" "$@"
}

# Una copia di verifica.sh in cui il controllo è finto: esce con il codice
# dato, o si fa terminare da un segnale.
# Arguments: $1 la variabile da assegnare (la copia), $2 il codice
# d'uscita, oppure «segnale».
albero_finto() {
  local __a
  __a="$(mktemp -d "${TMP}/albero.XXXXXX")" || { echo "mktemp" >&2; exit 2; }
  cp -- "${D05}/verifica.sh" "${__a}/" || exit 2
  if [[ "$2" == segnale ]]; then
    printf '%s\n' 'import os, signal' 'os.kill(os.getpid(), signal.SIGTERM)' \
      > "${__a}/controlla_stop.py"
  else
    printf 'import sys\nsys.exit(%d)\n' "$2" > "${__a}/controlla_stop.py"
  fi
  printf -v "$1" '%s' "${__a}"
}

# L'esca in ${TMP}/esca (registra ogni invocazione ed esce 0); il claude
# finto in ${TMP}/finto; ${TMP}/senza_python, un PATH con readlink,
# dirname, git e l'esca; ${TMP}/senza_claude, uno con readlink, python3,
# git e diff. Esce 2 se nel PATH di prova il claude trovato non è il finto.
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
  for t in readlink dirname git; do
    ln -s "$(command -v "${t}")" "${TMP}/senza_python/${t}" || exit 2
  done
  for t in readlink python3 git diff; do
    ln -s "$(command -v "${t}")" "${TMP}/senza_claude/${t}" || exit 2
  done
  t="$(PATH="${TMP}/finto:${PATH}" command -v claude)"
  if [[ "${t}" != "${TMP}/finto/claude" ]]; then
    echo "test_m4_d05: nel PATH di prova claude è ${t}, non il finto" >&2
    exit 2
  fi
}

# live.sh con l'esca davanti nel PATH (o con un PATH dato); il registro
# delle invocazioni riparte vuoto. Arguments: $1 lo spazio di lavoro, $2
# facoltativo il PATH, poi gli argomenti in più di live.sh.
esca() {
  local w="$1" p="${2:-${TMP}/esca:${PATH}}"
  shift
  (( $# == 0 )) || shift
  : > "${TMP}/esca.log"
  run env PATH="${p}" HANDSON_NO_PAUSE=1 ESCA_LOG="${TMP}/esca.log" \
    "${D05}/_docente/live.sh" "$@" "${w}"
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
# Arguments: $1 lo spazio di lavoro, poi le variabili NOME=valore, poi
# (dopo «--») gli argomenti in più di live.sh.
finto() {
  local w="$1"
  local -a vars=() extra=()
  shift
  while (( $# > 0 )) && [[ "$1" != "--" ]]; do
    vars+=("$1")
    shift
  done
  (( $# == 0 )) || shift
  extra=("$@")
  : > "${TMP}/finto.log"
  run env PATH="${TMP}/finto:${PATH}" HANDSON_NO_PAUSE=1 \
    ANTHROPIC_API_KEY=valore-finto FINTO_LOG="${TMP}/finto.log" \
    ${vars[@]+"${vars[@]}"} "${D05}/_docente/live.sh" \
    ${extra[@]+"${extra[@]}"} "${w}"
}

# Quante chiamate al modello (non --version) ha ricevuto il finto, e
# quante con ANTHROPIC_API_KEY. Arguments: $1 il registro.
# Outputs: «chiamate chiavi».
chiamate() {
  python3 -B -I - "$1" <<'PY'
import json, sys
righe = [json.loads(r) for r in open(sys.argv[1], encoding="utf-8")]
modello = [r for r in righe if r["argv"][:1] != ["--version"]]
print(len(modello), sum(1 for r in modello if r["chiave"]))
PY
}

# Il blocco di comandi del README fra le righe «<!-- comandi -->» e
# «<!-- /comandi -->», senza il rientro comune, in un file.
# Arguments: $1 il file. Returns: 0; 1 se il blocco non c'è.
blocco_readme() {
  python3 -B -I - "${D05}/README.md" "$1" <<'PY'
import sys, textwrap
righe = open(sys.argv[1], encoding="utf-8").read().split("\n")
segni = [i for i, r in enumerate(righe)
         if r.strip() in ("<!-- comandi -->", "<!-- /comandi -->")]
if len(segni) != 2:
    sys.exit(1)
blocco = textwrap.dedent("\n".join(righe[segni[0] + 1:segni[1]])).strip()
if "claude -p" not in blocco:
    sys.exit(1)
with open(sys.argv[2], "w", encoding="utf-8") as fh:
    fh.write(blocco + "\n")
PY
}

# --- Il punto di partenza ---------------------------------------------------

t_file() {
  local p
  p="$(cat "${D05}/demo/prompt.txt")"
  if [[ "${p}" == *docstring* ]] \
      && ! grep -qiE 'test|confine|giorni|7' <<< "${p}"; then
    pass "prompt: soltanto la docstring, niente test né confine"
  else
    fail "prompt: «${p}»"
  fi
  run python3 -B -I - "${D05}/demo/impostazioni" "${RADICE}/.claude" \
    "${HOOK}" <<'PY'
import json, os, sys
cartella, radice, atteso = sys.argv[1:4]
con = json.load(open(os.path.join(cartella, "con-hook.json")))
senza = json.load(open(os.path.join(cartella, "senza-hook.json")))
prudenti = json.load(open(os.path.join(radice, "settings.json")))
stop = con.get("hooks", {}).get("Stop", [])
comandi = [h.get("command") for v in stop for h in v.get("hooks", [])
           if h.get("type") == "command"]
print("comandi=%r" % comandi)
print("hook=%s" % ("giusto" if comandi == [atteso]
                   and list(con.get("hooks")) == ["Stop"] else "sbagliato"))
resto = dict(con)
resto.pop("hooks", None)
print("resto=%s" % ("uguale" if resto == senza else "diverso"))
print("senza=%s" % ("senza hook" if "hooks" not in senza else "con hook"))
print("prudenti=%s" % ("uguali" if senza.get("permissions")
                        == prudenti.get("permissions") else "diverse"))
PY
  expect "impostazioni: lo Stop hook della prova, uno solo" 0 "hook=giusto"
  expect "impostazioni: i due bracci differiscono solo nell'hook" 0 \
    "resto=uguale"
  expect "impostazioni: senza-hook.json non ha hook" 0 "senza=senza hook"
  expect "impostazioni: le regole prudenti del repository" 0 \
    "prudenti=uguali"
  if grep -rqiE 'confine|7 giorni|sette giorni|>= ?7|difett' \
      "${D05}/demo"; then
    fail "demo/: un file accenna al difetto"
  else
    pass "demo/: nessun file accenna al difetto"
  fi
  if cmp -s "${D05}/demo/nuova_copia.sh" "${D03}/demo/nuova_copia.sh"; then
    pass "nuova_copia.sh è quella di M4-D03"
  else
    fail "nuova_copia.sh è diversa da quella di M4-D03"
  fi
  if [[ ! -e "${D05}/demo/controlla_stop.py" \
      && -f "${D05}/controlla_stop.py" ]]; then
    pass "il controllo sta nella cartella dell'elemento, non in demo/"
  else
    fail "il controllo non è dove deve stare"
  fi
}

# prepara_esercizio.sh porta il progetto e demo/ nello spazio di lavoro, e
# lì verifica.sh esce 1: il punto di partenza chiede le esecuzioni.
t_prepara() {
  local r="${TMP}/radice" w
  run "${RADICE}/tools/prepara_esercizio.sh" M4-D05 --radice "${r}"
  expect "prepara: lo spazio di lavoro nasce" 0 "Spazio di lavoro pronto"
  w="${r}/M4-D05"
  if [[ -f "${w}/progetti/urgenze/urgenza.py" && -f "${w}/prompt.txt" \
      && -f "${w}/nuova_copia.sh" && -f "${w}/impostazioni/con-hook.json" \
      && -f "${w}/impostazioni/senza-hook.json" \
      && ! -e "${w}/progetti/urgenze/_docente" \
      && ! -e "${w}/controlla_stop.py" && ! -e "${w}/soluzione" \
      && ! -e "${w}/_docente" ]]; then
    pass "prepara: il progetto, il prompt, la copia e le impostazioni"
  else
    fail "prepara: lo spazio di lavoro non è quello atteso"
  fi
  run "${RADICE}/tools/verifica.sh" M4-D05 --radice "${r}"
  expect "prepara: sul punto di partenza la verifica esce 1" 1 "${PARTENZA}"
  run bash -c 'cd "$1" && bash nuova_copia.sh esecuzioni/con-hook-1 \
    impostazioni/con-hook.json' _ "${w}"
  if (( RC == 0 )) && cmp -s "${w}/impostazioni/con-hook.json" \
      "${w}/esecuzioni/con-hook-1/urgenze/.claude/settings.json" \
      && [[ "$(git -C "${w}/esecuzioni/con-hook-1/urgenze" rev-parse \
        --show-toplevel)" == "$(cd "${w}/esecuzioni/con-hook-1/urgenze" \
        && pwd -P)" ]]; then
    pass "copia: l'hook del braccio, in un repository a sé"
  else
    fail "copia: rc=${RC}: ${OUT}"
  fi
}

# --- controlla_stop.py ------------------------------------------------------

# La coppia della prova: con l'hook un blocco e i test verdi, senza la
# docstring e i test rossi.
t_coppia_buona() {
  local w
  ws w
  con_buona "${w}"
  senza_buona "${w}"
  controlla "${w}"
  expect "coppia: uscita 0 e la garanzia confermata" 0 \
    "${S_BLOCCA} (con-hook-1): confermata: 1 blocco, e il turno si è \
chiuso con i test verdi"
  expect "coppia: il comportamento confermato" 0 \
    "${S_CONTINUA} (con-hook-1): confermata"
  expect "coppia: il riepilogo del comportamento" 0 \
    "${S_CONTINUA}: confermata 1 su 1"
  expect "coppia: il braccio senza hook, come dato" 0 "${S_SENZA}: 0 su 1"
  expect "coppia: l'avvio" 0 \
    "con-hook-1: Claude Code 9.9.9, modello modello-finto, modalità \
acceptEdits"
  expect "coppia: i blocchi e gli strumenti" 0 \
    "con-hook-1: 1 blocco dello Stop hook (di fila al massimo 1); \
strumenti: Edit 2, Read 1; 0 permessi negati; 9 s"
  expect "coppia: i file cambiati e no" 0 \
    "con-hook-1: cambiati: urgenza.py; invariati: test_urgenza.py"
  expect "coppia: i test con l'hook" 0 \
    "con-hook-1: i test, rieseguiti ora nella copia: verdi (3 test, OK)"
  expect "coppia: senza hook, nessun blocco" 0 \
    "senza-hook-1: 0 blocchi dello Stop hook (di fila al massimo 0); \
strumenti: Edit 1, Read 1"
  expect "coppia: i test senza hook" 0 \
    "senza-hook-1: i test, rieseguiti ora nella copia: rossi (3 test, \
FAILED (failures=1))"
  expect_absent "coppia: nessuna segnalazione" "Segnalazioni"
}

# I verdetti con l'hook: senza blocchi, il tetto, una garanzia che non
# tiene, un test allentato; il braccio senza hook come dato.
t_verdetti() {
  local w
  ws w
  copia "${w}" con-hook-1 verde con
  stream "${w}" con-hook-1 R:Read R:Edit R:Edit R
  senza_buona "${w}"
  controlla "${w}"
  expect "verdetti: nessun blocco e i test verdi, non distinguibile" 1 \
    "${S_BLOCCA} (con-hook-1): non distinguibile: lo Stop hook non ha mai \
bloccato"
  expect "verdetti: e il comportamento, non distinguibile" 1 \
    "${S_CONTINUA} (con-hook-1): non distinguibile"
  expect "verdetti: nessun blocco in nessuna esecuzione, «Non ancora»" 1 \
    "${NESSUNA_PROVA}"
  # Un'esecuzione con l'hook senza blocchi accanto a una che ne ha uno: la
  # garanzia è messa alla prova, e non c'è nessun «Non ancora».
  ws w
  con_buona "${w}"
  copia "${w}" con-hook-2 verde con
  stream "${w}" con-hook-2 R:Read R:Edit R:Edit R
  senza_buona "${w}"
  controlla "${w}"
  expect "verdetti: un blocco in un'esecuzione su due, uscita 0" 0 \
    "${S_BLOCCA} (con-hook-2): non distinguibile"
  expect_absent "verdetti: e nessun «Non ancora»" "Non ancora"
  ws w
  copia "${w}" con-hook-1 rossa con
  stream "${w}" con-hook-1 R:Read R:Edit R B R B R B R B R B R B R B R B R
  senza_buona "${w}"
  controlla "${w}"
  expect "verdetti: il tetto degli otto blocchi, uscita 0" 0 \
    "${S_BLOCCA} (con-hook-1): confermata fino al tetto: 8 blocchi di \
fila senza strumenti"
  expect "verdetti: al tetto il comportamento non è confermato" 0 \
    "${S_CONTINUA} (con-hook-1): ${NONCONF}"
  expect "verdetti: i blocchi contati" 0 \
    "con-hook-1: 8 blocchi dello Stop hook (di fila al massimo 8)"
  ws w
  copia "${w}" con-hook-1 rossa con
  stream "${w}" con-hook-1 R:Read R:Edit R B R B R B R
  senza_buona "${w}"
  controlla "${w}"
  expect "verdetti: i test rossi senza il tetto, una segnalazione" 1 \
    "${S_BLOCCA} (con-hook-1): ${NONCONF}: i test sono rossi e lo stream \
non finisce con il tetto degli otto blocchi di fila; una segnalazione"
  expect "verdetti: la riga delle segnalazioni" 1 "Segnalazioni: 1."
  ws w
  copia "${w}" con-hook-1 rossa con
  stream "${w}" con-hook-1 R:Edit R B R B R B R B R:Bash! B R B R B R B R
  senza_buona "${w}"
  controlla "${w}"
  expect "verdetti: otto blocchi ma uno strumento in mezzo" 1 \
    "con-hook-1: 8 blocchi dello Stop hook (di fila al massimo 4)"
  ws w
  copia "${w}" con-hook-1 rossa con
  stream "${w}" con-hook-1 R:Read R:Edit R B R B R B R B R B R B R B R B \
    R:Edit R
  senza_buona "${w}"
  controlla "${w}"
  expect "verdetti: otto di fila ma non in fondo, una segnalazione" 1 \
    "${S_BLOCCA} (con-hook-1): ${NONCONF}"
  ws w
  copia "${w}" con-hook-1 verde con
  stream "${w}" con-hook-1 R:Read R:Edit T B R:Edit R
  senza_buona "${w}"
  controlla "${w}"
  expect "verdetti: U+2028 e U+0085 in una riga non la spezzano" 0 \
    "${S_BLOCCA} (con-hook-1): confermata: 1 blocco"
  ws w
  copia "${w}" con-hook-1 rossa con
  stream "${w}" con-hook-1 R:Read R:Edit R
  senza_buona "${w}"
  controlla "${w}"
  expect "verdetti: i test rossi e nessun blocco, una segnalazione" 1 \
    "nessun blocco nello stream: l'hook ha girato?"
  ws w
  copia "${w}" con-hook-1 allentata con
  stream "${w}" con-hook-1 R:Read R:Edit R B R:Edit R
  senza_buona "${w}"
  controlla "${w}"
  expect "verdetti: un test allentato fa passare l'hook, uscita 0" 0 \
    "${S_BLOCCA} (con-hook-1): confermata"
  expect "verdetti: e il test cambiato si vede" 0 \
    "con-hook-1: cambiati: test_urgenza.py; invariati: urgenza.py"
  ws w
  con_buona "${w}"
  copia "${w}" senza-hook-1 verde senza
  stream "${w}" senza-hook-1 R:Read R:Edit R:Edit R
  senza_buona "${w}" senza-hook-2
  controlla "${w}"
  expect "verdetti: senza hook, i test verdi in 1 su 2" 0 "${S_SENZA}: 1 su 2"
}

# Le coppie che non vanno: uscita 1, il motivo.
t_coppie_sbagliate() {
  local w
  ws w
  con_buona "${w}"
  copia "${w}" senza-hook-1 rossa senza
  stream "${w}" senza-hook-1 R:Read R:Edit R B R
  controlla "${w}"
  expect "coppie: blocchi in un'esecuzione senza hook" 1 \
    "blocchi dello Stop hook in un'esecuzione senza hook"
  ws w
  copia "${w}" con-hook-1 verde senza
  stream "${w}" con-hook-1 R:Read R:Edit R
  senza_buona "${w}"
  controlla "${w}"
  expect "coppie: la copia con l'hook senza l'hook" 1 \
    "le impostazioni della copia esecuzioni/con-hook-1/urgenze/ non sono \
quelle del braccio con-hook"
  ws w
  con_buona "${w}"
  copia "${w}" senza-hook-1 rossa con
  stream "${w}" senza-hook-1 R:Read R:Edit R
  controlla "${w}"
  expect "coppie: la copia senza hook con l'hook" 1 \
    "non sono quelle del braccio senza-hook"
  ws w
  con_buona "${w}"
  copia "${w}" senza-hook-1 rossa altra
  stream "${w}" senza-hook-1 R:Read R:Edit R
  controlla "${w}"
  expect "coppie: impostazioni diverse in altro" 1 \
    "le copie differiscono in più dello Stop hook"
  ws w
  con_buona "${w}"
  copia "${w}" senza-hook-1 rossa nessuna
  stream "${w}" senza-hook-1 R:Read R:Edit R
  controlla "${w}"
  expect "coppie: una copia senza impostazioni" 1 \
    "esecuzioni/senza-hook-1/urgenze/.claude/settings.json manca o non è JSON"
  ws w
  con_buona "${w}"
  copia "${w}" senza-hook-1 rossa senza
  stream "${w}" senza-hook-1 R:Read R:Edit R +modello=altro
  controlla "${w}"
  expect "coppie: due modelli diversi" 1 \
    "le esecuzioni non hanno lo stesso modello e la stessa modalità"
  ws w
  con_buona "${w}"
  controlla "${w}"
  expect "coppie: il braccio senza hook che manca" 1 \
    "manca il braccio senza-hook"
}

# Gli stream rovinati: uscita 1, il motivo, nessun traceback.
t_rovinati() {
  local w
  ws w
  con_buona "${w}"
  senza_buona "${w}"
  rm "${w}/esecuzioni/con-hook-1/stream.jsonl"
  controlla "${w}"
  expect "rovinati: uno stream che manca, uscita 1" 1 \
    "manca esecuzioni/con-hook-1/stream.jsonl"
  expect "rovinati: il messaggio «Non ancora»" 1 "Non ancora:"
  : > "${w}/esecuzioni/con-hook-1/stream.jsonl"
  controlla "${w}"
  expect "rovinati: uno stream vuoto" 1 "con-hook-1/stream.jsonl è vuoto"
  printf '{"type": "system"}\n{rotto\n' \
    > "${w}/esecuzioni/con-hook-1/stream.jsonl"
  controlla "${w}"
  expect "rovinati: una riga che non è JSON" 1 \
    "con-hook-1/stream.jsonl, riga 2: non è un evento dello stream-json"
  stream "${w}" con-hook-1 R +tronco
  controlla "${w}"
  expect "rovinati: senza il risultato in fondo" 1 \
    "lo stream non finisce con il risultato"
  stream "${w}" con-hook-1 +solo
  controlla "${w}"
  expect "rovinati: soltanto il risultato" 1 \
    "c'è soltanto il risultato, senza gli eventi"
  stream "${w}" con-hook-1 R +errore
  controlla "${w}"
  expect "rovinati: is_error" 1 "claude ha restituito un errore"
  stream "${w}" con-hook-1 R +subtype
  controlla "${w}"
  expect "rovinati: un subtype d'errore" 1 "claude ha restituito un errore"
  stream "${w}" con-hook-1 R:Read R
  rm -rf "${w}/esecuzioni/con-hook-1/urgenze"
  controlla "${w}"
  expect "rovinati: la copia che manca" 1 \
    "manca la copia esecuzioni/con-hook-1/urgenze/"
  expect_absent "rovinati: mai un traceback" "Traceback"
}

# Un'esecuzione rovinata accanto a una buona dello stesso braccio: la
# verifica resta 1 finché la cartella rovinata c'è, e il messaggio dice di
# toglierla; tolta, 0.
t_rifare() {
  local w
  ws w
  copia "${w}" con-hook-1 verde senza
  stream "${w}" con-hook-1 R:Read R:Edit R
  con_buona "${w}" con-hook-2
  senza_buona "${w}"
  controlla "${w}"
  expect "rifare: la rovinata accanto alla buona, uscita 1 e il consiglio" 1 \
    "rm -rf esecuzioni/<braccio>-<n>"
  rm -rf "${w}/esecuzioni/con-hook-1"
  controlla "${w}"
  expect "rifare: tolta la rovinata, uscita 0" 0 \
    "${S_BLOCCA} (con-hook-2): confermata"
}

# esecuzioni/ che manca o è vuota, gli argomenti, le precondizioni.
t_precondizioni() {
  local w
  ws w
  controlla "${w}"
  expect "partenza: esecuzioni/ che manca, uscita 1" 1 "${PARTENZA}"
  mkdir -p "${w}/esecuzioni/giro-1"
  controlla "${w}"
  expect "partenza: esecuzioni/ senza i bracci, uscita 1" 1 "${PARTENZA}"
  con_buona "${w}"
  senza_buona "${w}"
  run python3 -B -I "${D05}/controlla_stop.py" --tutto "${w}"
  expect "precondizione: un'opzione sconosciuta, uscita 2" 2 \
    "opzione sconosciuta: --tutto"
  run python3 -B -I "${D05}/controlla_stop.py" "${w}" "${w}"
  expect "precondizione: due spazi di lavoro" 2 \
    "uno spazio di lavoro per volta"
  run python3 -B -I "${D05}/controlla_stop.py" "${TMP}/assente"
  expect "precondizione: spazio di lavoro assente" 2 \
    "spazio di lavoro assente"
  inatteso "${w}"
  expect "precondizione: un errore inatteso, uscita 2" 2 \
    "errore inatteso (RuntimeError: guasto finto)"
  expect_absent "precondizione: l'errore inatteso senza traceback" \
    "Traceback"
  rm -rf "${w}/progetti"
  controlla "${w}"
  expect "dati: senza il progetto originale, i file non si confrontano" 0 \
    "con-hook-1: cambiati: —; invariati: — (manca progetti/urgenze/)"
  if (( EUID == 0 )); then
    skip "precondizione: uno stream che non si legge (da root si legge)"
    return 0
  fi
  chmod 000 "${w}/esecuzioni/senza-hook-1/stream.jsonl"
  controlla "${w}"
  expect "precondizione: uno stream che non si legge" 2 \
    "esecuzioni/senza-hook-1/stream.jsonl non si legge"
  chmod 644 "${w}/esecuzioni/senza-hook-1/stream.jsonl"
}

# --- verifica.sh ------------------------------------------------------------

t_verifica() {
  local w a
  run "${D05}/verifica.sh"
  expect "verifica: senza spazio di lavoro, uscita 2" 2 \
    "spazio di lavoro assente"
  ws w
  run "${D05}/verifica.sh" "${w}"
  expect "verifica: il punto di partenza, uscita 1" 1 "${PARTENZA}"
  con_buona "${w}"
  senza_buona "${w}"
  run "${D05}/verifica.sh" "${w}"
  expect "verifica: una coppia buona, uscita 0" 0 "${FINE}"
  if [[ "${OUT##*$'\n'}" == "${FINE}" ]]; then
    pass "verifica: la frase finale è l'ultima riga"
  else
    fail "verifica: l'ultima riga è «${OUT##*$'\n'}»"
  fi
  copia "${w}" con-hook-1 rossa con
  stream "${w}" con-hook-1 R:Read R:Edit R B R
  run "${D05}/verifica.sh" "${w}"
  expect "verifica: una segnalazione, uscita 1" 1 "Segnalazioni: 1."
  expect_absent "verifica: una segnalazione, nessuna frase finale" "Fatto:"
  run env PATH="${TMP}/senza_python" "${D05}/verifica.sh" "${w}"
  expect "verifica: python3 che manca, uscita 2" 2 "manca python3"
  albero_finto a 3
  run "${a}/verifica.sh" "${w}"
  expect "verifica: un controllo che esce con 3, uscita 2" 2 \
    "controlla_stop.py è uscito con 3"
  albero_finto a segnale
  run "${a}/verifica.sh" "${w}"
  expect "verifica: un controllo terminato da un segnale, uscita 2" 2 \
    "controlla_stop.py è uscito con 143"
}

# --- _docente/live.sh -------------------------------------------------------

# Le precondizioni escono 2 prima di ogni invocazione di claude.
t_live_precondizioni() {
  local w f
  precondizione "live: spazio di lavoro assente" "spazio di lavoro assente" \
    "${TMP}/assente"
  for f in prompt.txt nuova_copia.sh impostazioni/con-hook.json \
      impostazioni/senza-hook.json progetti/urgenze/test_urgenza.py; do
    ws w
    rm "${w}/${f}"
    precondizione "live: ${f} che manca" "file assente o illeggibile: ${f}" \
      "${w}"
  done
  ws w
  mkdir "${w}/esecuzioni"
  precondizione "live: esecuzioni/ che c'è già" "ci sono già delle esecuzioni" \
    "${w}"
  ws w
  precondizione "live: un numero di esecuzioni sbagliato" \
    "--esecuzioni vuole un numero da 1 a 9" "${w}" "" --esecuzioni 10
  ws w
  precondizione "live: python3 che manca" "manca lo strumento: python3" \
    "${w}" "${TMP}/senza_python"
  # Ogni esecuzione deve partire dallo stesso punto: il progetto com'è nel
  # primo commit dello spazio di lavoro.
  ws w
  precondizione "live: uno spazio di lavoro che non è un repository git" \
    "non è un repository git" "${w}"
  ws_git w
  printf '# una riga in più\n' >> "${w}/progetti/urgenze/urgenza.py"
  precondizione "live: un file del progetto cambiato" \
    "non è al punto di partenza (git status non è vuoto)" "${w}"
  ws_git w
  : > "${w}/progetti/urgenze/nota.txt"
  precondizione "live: un file non tracciato nel progetto" \
    "non è al punto di partenza (git status non è vuoto)" "${w}"
  # Le impostazioni dei due bracci, tolto l'hook, devono essere uguali:
  # live.sh lo dice prima di ogni chiamata.
  ws_git w
  python3 -B -I - "${w}/impostazioni/senza-hook.json" <<'PY' || exit 2
import json, sys
percorso = sys.argv[1]
dati = json.load(open(percorso, encoding="utf-8"))
dati.setdefault("permissions", {}).setdefault("deny", []).append(
    "Read(/progetti/urgenze/test_urgenza.py)")
with open(percorso, "w", encoding="utf-8") as fh:
    json.dump(dati, fh, indent=2)
    fh.write("\n")
PY
  fissa "${w}"
  precondizione "live: le impostazioni dei bracci diverse oltre l'hook" \
    "tolto l'hook, le impostazioni dei due bracci differiscono" "${w}"
  ws_git w
  printf '{"hooks": \n' > "${w}/impostazioni/con-hook.json"
  fissa "${w}"
  precondizione "live: impostazioni che non sono JSON" \
    "impostazioni/con-hook.json non è un oggetto JSON" "${w}"
  ws_git w
  esca "${w}" "${TMP}/senza_claude"
  expect "live: claude che manca" 2 "manca lo strumento: claude"
}

# Il claude finto, che esegue lo Stop hook vero della copia: i due bracci,
# il testo e le opzioni del README.
t_live_finto() {
  local w w2 r
  ws_git w
  finto "${w}"
  expect "live: i due bracci, uscita 0" 0 "VERIFICA OK"
  expect "live: i dati e i verdetti si vedono anche quando passa" 0 "${FINE}"
  expect "live: l'hook ha bloccato, e i test sono verdi" 0 \
    "${S_BLOCCA} (con-hook-1): confermata: 1 blocco"
  expect "live: senza hook i test restano rossi" 0 "${S_SENZA}: 0 su 1"
  expect "live: la riga di claude si vede prima di girare" 0 \
    "--permission-mode acceptEdits"
  r="$(chiamate "${TMP}/finto.log")"
  if [[ "${r}" == "2 0" ]]; then
    pass "live: due chiamate, senza ANTHROPIC_API_KEY"
  else
    fail "live: chiamate e chiavi «${r}», attese «2 0»"
  fi
  cp "${TMP}/finto.log" "${TMP}/live.log"
  ws w2
  if ! blocco_readme "${TMP}/passo.sh"; then
    fail "README: il blocco dei comandi non c'è"
    return 0
  fi
  : > "${TMP}/readme.log"
  ( cd "${w2}" && PATH="${TMP}/finto:${PATH}" \
      FINTO_LOG="${TMP}/readme.log" bash "${TMP}/passo.sh" ) > /dev/null 2>&1
  run python3 -B -I - "${w}" "${w2}" "${TMP}/live.log" "${TMP}/readme.log" \
    "${STRUMENTI}" <<'PY'
import json, os, sys
ws, ws2, log_live, log_readme, strumenti = sys.argv[1:6]
VALORE = {"--model", "--effort", "--tools", "--allowedTools",
          "--output-format", "--setting-sources", "--permission-mode",
          "--permission-prompts"}

def chiamate(log):
    righe = [json.loads(r) for r in open(log, encoding="utf-8")]
    return [r for r in righe if r["argv"][:1] != ["--version"]]

def analizza(argv):
    """(il prompt, le opzioni): il prompt dopo «--», o l'operando."""
    opzioni, prompt, i = {}, None, 0
    while i < len(argv):
        a = argv[i]
        if a == "--":
            prompt = argv[i + 1]
            break
        if a in VALORE:
            opzioni[a] = argv[i + 1]
            i += 2
        elif a.startswith("-"):
            opzioni[a] = True
            i += 1
        else:
            prompt = a
            i += 1
    return prompt, opzioni

testo = open(os.path.join(ws, "prompt.txt"), encoding="utf-8").read()
testo = testo.rstrip("\n")
live, readme = chiamate(log_live), chiamate(log_readme)
problemi = []
if len(live) != 2 or len(readme) != 2:
    problemi.append("chiamate: live.sh %d, README %d" % (len(live),
                                                        len(readme)))
fisse = (("--model", "sonnet"), ("--allowedTools", strumenti),
         ("--effort", "low"), ("--output-format", "stream-json"),
         ("--setting-sources", "project,local"),
         ("--permission-mode", "acceptEdits"),
         ("--permission-prompts", "none"))
for n, (cl, cr, braccio) in enumerate(zip(live, readme,
                                          ("con-hook", "senza-hook")), 1):
    pl, ol = analizza(cl["argv"])
    pr, orr = analizza(cr["argv"])
    if pl != testo or pr != testo:
        problemi.append("chiamata %d: il prompt" % n)
    for chiave, valore in list(orr.items()) + list(fisse):
        if ol.get(chiave) != valore:
            problemi.append("chiamata %d: %s" % (n, chiave))
    for chiave in ("-p", "--verbose", "--strict-mcp-config",
                   "--no-session-persistence"):
        if ol.get(chiave) is not True:
            problemi.append("chiamata %d: %s" % (n, chiave))
    for riga, base in ((cl, ws), (cr, ws2)):
        attesa = os.path.join(os.path.realpath(base), "esecuzioni",
                              braccio + "-1", "urgenze")
        if os.path.realpath(riga["cwd"]) != attesa:
            problemi.append("chiamata %d: la cartella di partenza" % n)
for base in (ws, ws2):
    for braccio in ("con-hook-1", "senza-hook-1"):
        if not os.path.isfile(os.path.join(base, "esecuzioni", braccio,
                                           "stream.jsonl")):
            problemi.append("lo stream di %s" % braccio)
print("; ".join(problemi) or "stesse chiamate")
PY
  expect "live e README: stesso testo, stesse opzioni, dalle copie" 0 \
    "stesse chiamate"
  run python3 -B -I "${D05}/controlla_stop.py" "${w2}"
  expect "README: i comandi del README danno la stessa coppia" 0 \
    "${S_BLOCCA} (con-hook-1): confermata: 1 blocco"
  ws_git w
  finto "${w}" -- --esecuzioni 2
  r="$(chiamate "${TMP}/finto.log")"
  if (( RC == 0 )) && [[ "${r}" == "4 0" ]] \
      && grep -qF "${S_CONTINUA}: confermata 2 su 2" <<< "${OUT}" \
      && grep -qF "${S_SENZA}: 0 su 2" <<< "${OUT}"; then
    pass "live: --esecuzioni 2, quattro copie e quattro chiamate"
  else
    fail "live: --esecuzioni 2, rc=${RC}, chiamate «${r}»"
  fi
}

# Il claude finto: il tetto, una garanzia che non tiene, l'hook ignorato,
# un test allentato, la prima chiamata fallita, uno stream troncato, i
# controlli della libreria.
t_live_esiti() {
  local w r chiave
  ws_git w
  finto "${w}" FINTO_STOP=ostinato
  expect "live: il tetto degli otto blocchi, uscita 0" 0 \
    "confermata fino al tetto: 8 blocchi di fila senza strumenti"
  ws_git w
  finto "${w}" FINTO_STOP=esce
  expect "live: una garanzia che non tiene, uscita 1" 1 \
    "${S_BLOCCA} (con-hook-1): ${NONCONF}"
  ws_git w
  finto "${w}" FINTO_HOOK=ignora
  expect "live: l'hook ignorato, una segnalazione" 1 \
    "nessun blocco nello stream: l'hook ha girato?"
  ws_git w
  finto "${w}" FINTO_STOP=allenta
  expect "live: un test allentato, uscita 0 e il file cambiato" 0 \
    "con-hook-1: cambiati: test_urgenza.py"
  ws_git w
  finto "${w}" FINTO_ESITO=ko
  r="$(chiamate "${TMP}/finto.log")"
  if (( RC == 1 )) && [[ "${r}" == "1 0" ]] \
      && grep -qF 'VERIFICA KO' <<< "${OUT}"; then
    pass "live: si ferma alla prima chiamata fallita"
  else
    fail "live: rc=${RC} dopo le chiamate «${r}»: ${OUT:0:300}"
  fi
  ws_git w
  finto "${w}" FINTO_TRONCO=1
  expect "live: uno stream troncato, uscita 1" 1 \
    "lo stream non finisce con il risultato"
  ws_git w
  finto "${w}" HANDSON_PERMISSION_MODE=bypassPermissions
  r="$(chiamate "${TMP}/finto.log")"
  if (( RC == 2 )) && [[ "${r}" == "0 0" ]] \
      && grep -qF 'modalità di permesso non ammessa' <<< "${OUT}"; then
    pass "live: bypassPermissions rifiutata prima di chiamare il modello"
  else
    fail "live: bypassPermissions, rc=${RC}, chiamate «${r}»"
  fi
  ws_git w
  chiave="sk-ant""-finta"
  printf 'Riscrivi la docstring. %s\n' "${chiave}" > "${w}/prompt.txt"
  fissa "${w}"
  finto "${w}"
  r="$(chiamate "${TMP}/finto.log")"
  if (( RC == 2 )) && [[ "${r}" == "0 0" ]] \
      && grep -qF 'sembra una chiave API' <<< "${OUT}"; then
    pass "live: una chiave API nel prompt rifiutata prima di chiamare"
  else
    fail "live: chiave nel prompt, rc=${RC}, chiamate «${r}»"
  fi
  expect_absent "live: la chiave non si stampa" "${chiave}"
}

# --- Il README --------------------------------------------------------------

t_readme() {
  run python3 -B -I - "${D05}/README.md" <<'PY'
import re, sys
testo = open(sys.argv[1], encoding="utf-8").read()
passi = testo.split("## Passi in Claude Code", 1)[-1].split("\n## ", 1)[0]
problemi = []
trovati = re.findall(r"\b(?:lo|uno|dello|nello|allo|dallo|sullo)\s+hook\b",
                     testo, re.IGNORECASE)
if trovati:
    problemi.append("«l'hook», non %s" % sorted(set(trovati)))
if "rm -rf esecuzioni/" not in testo:
    problemi.append("la cartella rovinata da togliere prima di rifarla")
dopo = passi.split("<!-- /comandi -->", 1)[-1]
verifica = dopo.find("tools/verifica.sh M4-D05")
if verifica == -1 or "cd -" not in dopo[:verifica]:
    problemi.append("cd - prima della verifica")
if re.search(r"\b[Rr]am[oi]\b", testo):
    problemi.append("«ramo» per un braccio")
for sigla in ("FACT-", "M4-X", "sessione principale", "P1 "):
    if sigla in testo:
        problemi.append("sigla interna %s" % sigla)
print("; ".join(problemi) or "README in ordine")
PY
  expect "README: l'hook, la cartella da togliere, cd -" 0 "README in ordine"
}

# Gli script di M4-D05, la sua libreria e questo file, con shellcheck -x;
# la libreria non è eseguibile (si carica con source).
t_shellcheck() {
  local f
  for f in "${D05}/verifica.sh" "${D05}/_docente/live.sh" \
      "${D05}/_docente/lib_stop.sh" "${D05}/demo/nuova_copia.sh" "${SELF}"; do
    if shellcheck -x "${f}" > /dev/null 2>&1; then
      pass "shellcheck ${f#"${RADICE}"/}"
    else
      fail "shellcheck ${f#"${RADICE}"/}"
    fi
  done
  if [[ -f "${D05}/_docente/lib_stop.sh" && ! -x "${D05}/_docente/lib_stop.sh" \
      && -x "${D05}/_docente/live.sh" ]]; then
    pass "live.sh eseguibile, lib_stop.sh no"
  else
    fail "lib_stop.sh manca o è eseguibile, o live.sh non lo è"
  fi
}

main() {
  local t
  for t in python3 git shellcheck; do
    command -v "${t}" >/dev/null 2>&1 \
      || { echo "test_m4_d05: manca ${t}" >&2; exit 2; }
  done
  [[ -d "${D05}" && -f "${FINTO_PY}" && -d "${URG}" ]] \
    || { echo "test_m4_d05: manca ${D05}, ${FINTO_PY} o ${URG}" >&2; exit 2; }
  handson::init_temp_base
  TMP="$(mktemp -d "${HANDSON_TEMP_BASE}/test_m4_d05.XXXXXX")" || exit 2
  trap 'chmod -R u+rwX "${TMP}" 2>/dev/null; rm -rf "${TMP}"' EXIT
  prepara_claude
  t_file
  t_prepara
  t_coppia_buona
  t_verdetti
  t_coppie_sbagliate
  t_rovinati
  t_rifare
  t_precondizioni
  t_verifica
  t_live_precondizioni
  t_live_finto
  t_live_esiti
  t_readme
  t_shellcheck
  OUT="${TUTTO}"
  expect_absent "in nessuna uscita «smentita»" "smentita"
  echo "PASS=${PASS} FAIL=${FAIL} SKIP=${SKIP}"
  if (( PASS + FAIL + SKIP != CASES )); then
    echo "test_m4_d05: girati $((PASS + FAIL + SKIP)) casi, attesi" \
      "${CASES}" >&2
    exit 2
  fi
  (( FAIL == 0 )) || exit 1
}

main "$@"
