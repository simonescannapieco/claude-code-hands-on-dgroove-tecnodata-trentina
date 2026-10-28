#!/bin/bash
#
# test_m4_d03.sh -- le prove di M4-D03 «Un giro del ciclo, registrato»,
# per il docente (sta in _docente/, il materiale del docente):
#   - il prompt (il confine, il comando dei test, un comando alla volta) e
#     lo spazio di lavoro di prepara_esercizio.sh (il progetto senza
#     _docente/, il prompt, nuova_copia.sh, nessun controllo), dove
#     verifica.sh esce 1;
#   - demo/nuova_copia.sh: la copia del progetto con le impostazioni e un
#     repository git di un commit; le precondizioni con l'uscita 2;
#   - controlla_giro.py su stream finti scritti qui (percorsi sintetici
#     sotto /tmp/m4ws): le richieste in ordine, un id contato una volta,
#     un evento senza id una richiesta a sé, i messaggi senza usage e dei
#     subagent fuori dal conto, gli strumenti con i percorsi relativi, i
#     comandi, gli errori e i dinieghi; la garanzia (l'entrata non scende:
#     una discesa è una segnalazione, uscita 1, tranne dopo una
#     compattazione); i test rieseguiti nella copia come dato (verdi,
#     rossi, nessun test, un tempo scaduto); gli stream rovinati con
#     l'uscita 1 e senza traceback; un'esecuzione rovinata accanto a una
#     buona (1, con il consiglio di toglierne la cartella), poi tolta (0);
#     le precondizioni con l'uscita 2;
#   - verifica.sh: spazio di lavoro assente (2), punto di partenza (1),
#     esecuzione buona (0, la frase finale), una segnalazione (1), python3
#     che manca (2), un controllo che esce 3 o per un segnale (2);
#   - _docente/live.sh: le precondizioni escono 2 senza chiamare claude
#     (l'esca), anche uno spazio di lavoro che non è un repository git o
#     che non è al punto di partenza (un file del progetto cambiato, un
#     file non tracciato); con il claude finto (claude_finto_m4_urgenze.py)
#     l'esecuzione con il testo e le opzioni del README (il suo blocco gira
#     con lo stesso finto, e le chiamate si confrontano), dalla copia, lo
#     stream-json con --verbose, senza ANTHROPIC_API_KEY, la tabella a
#     schermo una volta sola; --esecuzioni 3; la prima chiamata fallita;
#     una discesa (1) e una compattazione (0); i controlli della libreria
#     che live.sh riusa (una modalità di permesso vietata, una chiave API
#     nel prompt: 2, nessuna chiamata);
#   - il README: «ogni richiesta pesa più della precedente» (e nessun
#     «giro» per una richiesta), ogni giro-1 del blocco da cambiare, la
#     cartella rovinata da togliere prima di rifarla, cd - prima della
#     verifica;
#   - shellcheck -x su verifica.sh, live.sh, nuova_copia.sh e questo file.
# Mai il claude vero: il finto e l'esca stanno davanti nel PATH, e la
# suite lo controlla prima di usarli. Gli stream finti non sono risposte
# di Claude: provano il controllo, non il modello. Gli spazi di lavoro
# nascono in una cartella temporanea, nella base di handson::init_temp_base:
# l'albero del repository non cambia. CASES è il numero dei casi: se ne
# girano di più o di meno la suite esce 2 (un caso saltato conta come
# girato).
#
# Uso:    m4_claude_code_agenti/_docente/test_m4_d03.sh
# Uscita: 0 = tutti i casi passano · 1 = almeno un caso fallito · 2 =
#         precondizione (manca python3, git o shellcheck, o la cartella
#         dell'elemento), o un numero di casi diverso da CASES
set -uo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly MOD="${SELF%/_docente/*}"
readonly RADICE="${MOD%/*}"
D03="${MOD}/s3_agente_nel_repository/m4_5_ciclo_strumenti"
D03+="/M4-D03_giro_del_ciclo"
readonly D03
readonly FINTO_PY="${MOD}/_docente/claude_finto_m4_urgenze.py"
readonly URG="${RADICE}/progetti/urgenze"
# La libreria del repository, per la base dei file temporanei
# (handson::init_temp_base): mai dentro ~/.claude.
# shellcheck source=../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"
readonly CASES=117
FINE='Fatto: ogni affermazione è stata messa alla prova;'
FINE+=' gli esiti sono qui sopra.'
readonly FINE
PARTENZA='Manca la cartella esecuzioni/ con le esecuzioni giro-<n>:'
PARTENZA+=' eseguite i passi del README.'
readonly PARTENZA
readonly S_GIRO='Ogni richiesta rimanda tutta la conversazione'
readonly NONCONF='non confermata in questa esecuzione'
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
  if ! cp -R "${D03}/demo/." "${__w}/" \
      || ! mkdir -p "${__w}/progetti/urgenze" "${__w}/.claude" \
      || ! cp -p "${URG}/README.md" "${URG}/genera.py" "${URG}/urgenza.py" \
        "${URG}/test_urgenza.py" "${__w}/progetti/urgenze/" \
      || ! cp -p "${RADICE}/.claude/settings.json" "${__w}/.claude/"; then
    echo "test_m4_d03: non riesco a preparare lo spazio di lavoro" >&2
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
  if ! handson::git_init_workspace "${__g}" M4-D03 > /dev/null 2>&1; then
    echo "test_m4_d03: git non riesce ad aprire lo spazio di lavoro" >&2
    exit 2
  fi
  printf -v "$1" '%s' "${__g}"
}

# Fissa nel repository dello spazio di lavoro un file cambiato da un caso,
# così che git status torni vuoto. Arguments: $1 lo spazio di lavoro.
fissa() {
  git -C "$1" -c user.name=Prova -c user.email=prova@example.org \
    -c commit.gpgsign=false commit -q --no-verify -am 'un caso di prova' \
    || { echo "test_m4_d03: git commit non riesce" >&2; exit 2; }
}

# La copia del progetto di un'esecuzione, in esecuzioni/<nome>/urgenze/:
# «verde» con il confine corretto, «rossa» com'è, «senza_test» senza
# test_urgenza.py, «lenta» con un test che dura cinque secondi.
# Arguments: $1 lo spazio di lavoro, $2 il nome dell'esecuzione, $3 il tipo.
copia() {
  local c="$1/esecuzioni/$2/urgenze"
  mkdir -p "${c}" || exit 2
  cp -p "${URG}/urgenza.py" "${URG}/test_urgenza.py" "${c}/" || exit 2
  case "$3" in
    verde)
      sed -i 's/giorni_aperta > 7/giorni_aperta >= 7/' "${c}/urgenza.py" ;;
    senza_test) rm -f "${c}/test_urgenza.py" ;;
    lenta)
      printf '%s\n' 'import time' 'import unittest' '' '' \
        'class TestLento(unittest.TestCase):' \
        '    def test_lento(self):' '        time.sleep(5)' \
        > "${c}/test_urgenza.py" ;;
  esac
}

# Scrive lo stream finto di un'esecuzione in esecuzioni/<nome>/stream.jsonl.
# Arguments: $1 lo spazio di lavoro, $2 il nome dell'esecuzione, poi le
# voci, nell'ordine:
#   R<n>[:<strumenti>]  una richiesta nuova con <n> token in entrata e gli
#       strumenti separati da virgole (Read, Edit, Bash; «!» dopo il nome
#       un risultato con errore, «?» un permesso negato), oppure un testo;
#   N<n>  un messaggio dell'assistente senza id;  U  uno senza usage;
#   S<n>  un messaggio di un subagent;  C  una compattazione;
#   T<n>  una richiesta con un testo che contiene U+2028 e U+0085, che
#       JSON lascia nella riga così come sono;
#   +tronco (senza il risultato), +solo (soltanto il risultato), +errore
#   (is_error), +subtype (un subtype d'errore), +senza_init.
stream() {
  python3 -B -I - "$@" <<'PY'
import json, os, sys
ws, nome = sys.argv[1:3]
voci = sys.argv[3:]
cwd = "/tmp/m4ws/esecuzioni/%s/urgenze" % nome
eventi = [{"type": "system", "subtype": "init", "cwd": cwd,
           "session_id": "finta", "model": "modello-finto",
           "permissionMode": "dontAsk", "claude_code_version": "9.9.9"}]
dinieghi = []
ingressi = {"Read": {"file_path": cwd + "/urgenza.py"},
            "Edit": {"file_path": cwd + "/urgenza.py", "old_string": "a",
                     "new_string": "b"},
            "Bash": {"command": "python3 -m unittest"}}
n_msg = n_tool = 0
def usage(n):
    return {"input_tokens": 1, "cache_creation_input_tokens": 9,
            "cache_read_input_tokens": n - 10, "output_tokens": 5}
def assistente(blocco, ident, n, padre=None, con_usage=True):
    m = {"role": "assistant", "content": [blocco]}
    if ident is not None:
        m["id"] = ident
    if con_usage:
        m["usage"] = usage(n)
    eventi.append({"type": "assistant", "message": m,
                   "parent_tool_use_id": padre})
for voce in voci:
    if voce.startswith("+"):
        continue
    if voce == "C":
        eventi.append({"type": "system", "subtype": "compact_boundary"})
    elif voce == "U":
        n_msg += 1
        assistente({"type": "text", "text": "x"}, "msg_%d" % n_msg, 0,
                   con_usage=False)
    elif voce[0] in "NS":
        n_msg += 1
        assistente({"type": "text", "text": "x"},
                   None if voce[0] == "N" else "msg_%d" % n_msg,
                   int(voce[1:]), "toolu_padre" if voce[0] == "S" else None)
    elif voce[0] == "T":
        n_msg += 1
        assistente({"type": "text", "text": "riga separata\u0085fine"},
                   "msg_%d" % n_msg, int(voce[1:]))
    elif voce[0] == "R":
        n_msg += 1
        testa, _, strumenti = voce[1:].partition(":")
        n = int(testa)
        if not strumenti:
            assistente({"type": "text", "text": "risposta finta"},
                       "msg_%d" % n_msg, n)
        for s in (x for x in strumenti.split(",") if x):
            nome_s = s.rstrip("!?")
            n_tool += 1
            ident = "toolu_%d" % n_tool
            assistente({"type": "tool_use", "id": ident, "name": nome_s,
                        "input": ingressi.get(nome_s, {})},
                       "msg_%d" % n_msg, n)
            res = {"type": "tool_result", "tool_use_id": ident,
                   "content": "finto"}
            if s.endswith("?"):
                dinieghi.append({"tool_name": nome_s, "tool_use_id": ident})
                eventi.append({"type": "system",
                               "subtype": "permission_denied",
                               "tool_name": nome_s, "tool_use_id": ident})
            if s.endswith(("!", "?")):
                res["is_error"] = True
            eventi.append({"type": "user", "parent_tool_use_id": None,
                           "message": {"role": "user", "content": [res]}})
risultato = {"type": "result", "subtype": "success", "is_error": False,
             "result": "finto", "num_turns": n_msg, "duration_ms": 21000,
             "permission_denials": dinieghi}
if "+errore" in voci:
    risultato["is_error"] = True
if "+subtype" in voci:
    risultato["subtype"] = "error_during_execution"
if "+senza_init" in voci:
    eventi = eventi[1:]
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

# Un'esecuzione buona: cinque richieste che crescono, la copia verde.
# Arguments: $1 lo spazio di lavoro, $2 il nome (default giro-1).
buona() {
  local nome="${2:-giro-1}"
  copia "$1" "${nome}" verde
  stream "$1" "${nome}" R17300:Read R17600:Bash! R17900:Edit \
    R18200:Bash R18500
}

# Il controllo dell'elemento sullo spazio di lavoro $1 (gli argomenti che
# seguono vanno prima); RC e OUT come run.
controlla() {
  local w="$1"
  shift
  run python3 -B -I "${D03}/controlla_giro.py" "$@" "${w}"
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
sys.exit(modulo.main(sys.argv[2:]))' "${D03}/controlla_giro.py" "$@"
}

# Una copia di verifica.sh in cui il controllo è finto: esce con il codice
# dato, o si fa terminare da un segnale.
# Arguments: $1 la variabile da assegnare (la copia), $2 il codice
# d'uscita, oppure «segnale».
albero_finto() {
  local __a
  __a="$(mktemp -d "${TMP}/albero.XXXXXX")" || { echo "mktemp" >&2; exit 2; }
  cp -- "${D03}/verifica.sh" "${__a}/" || exit 2
  if [[ "$2" == segnale ]]; then
    printf '%s\n' 'import os, signal' 'os.kill(os.getpid(), signal.SIGTERM)' \
      > "${__a}/controlla_giro.py"
  else
    printf 'import sys\nsys.exit(%d)\n' "$2" > "${__a}/controlla_giro.py"
  fi
  printf -v "$1" '%s' "${__a}"
}

# L'esca in ${TMP}/esca (registra ogni invocazione ed esce 0); il claude
# finto in ${TMP}/finto; ${TMP}/senza_python, un PATH con readlink,
# dirname, git e l'esca; ${TMP}/senza_claude, uno con readlink, python3 e
# git. Esce 2 se nel PATH di prova il claude trovato non è il finto.
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
  for t in readlink python3 git; do
    ln -s "$(command -v "${t}")" "${TMP}/senza_claude/${t}" || exit 2
  done
  t="$(PATH="${TMP}/finto:${PATH}" command -v claude)"
  if [[ "${t}" != "${TMP}/finto/claude" ]]; then
    echo "test_m4_d03: nel PATH di prova claude è ${t}, non il finto" >&2
    exit 2
  fi
}

# live.sh con l'esca davanti nel PATH (o con un PATH dato); il registro
# delle invocazioni riparte vuoto. Arguments: $1 lo spazio di lavoro, $2
# facoltativo il PATH, poi gli argomenti in più di live.sh (prima dello
# spazio di lavoro).
esca() {
  local w="$1" p="${2:-${TMP}/esca:${PATH}}"
  shift
  (( $# == 0 )) || shift
  : > "${TMP}/esca.log"
  run env PATH="${p}" HANDSON_NO_PAUSE=1 ESCA_LOG="${TMP}/esca.log" \
    "${D03}/_docente/live.sh" "$@" "${w}"
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
    ${vars[@]+"${vars[@]}"} "${D03}/_docente/live.sh" \
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
  python3 -B -I - "${D03}/README.md" "$1" <<'PY'
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

# --- Il prompt e lo spazio di lavoro ---------------------------------------

t_file() {
  local p
  p="$(cat "${D03}/demo/prompt.txt")"
  if [[ "${p}" == *"confine dei 7 giorni"* \
      && "${p}" == *"python3 -m unittest"* \
      && "${p}" == *"comando alla volta"* ]]; then
    pass "prompt: il confine, il comando dei test, un comando alla volta"
  else
    fail "prompt: «${p}»"
  fi
  if [[ ! -e "${D03}/demo/controlla_giro.py" \
      && -f "${D03}/controlla_giro.py" ]]; then
    pass "il controllo sta nella cartella dell'elemento, non in demo/"
  else
    fail "il controllo non è dove deve stare"
  fi
}

# prepara_esercizio.sh porta il progetto e demo/ nello spazio di lavoro, e
# lì verifica.sh esce 1: il punto di partenza chiede l'esecuzione.
t_prepara() {
  local r="${TMP}/radice" w
  run "${RADICE}/tools/prepara_esercizio.sh" M4-D03 --radice "${r}"
  expect "prepara: lo spazio di lavoro nasce" 0 "Spazio di lavoro pronto"
  w="${r}/M4-D03"
  if [[ -f "${w}/progetti/urgenze/urgenza.py" && -f "${w}/prompt.txt" \
      && -f "${w}/nuova_copia.sh" && -f "${w}/.claude/settings.json" \
      && ! -e "${w}/progetti/urgenze/_docente" \
      && ! -e "${w}/controlla_giro.py" && ! -e "${w}/soluzione" \
      && ! -e "${w}/_docente" ]]; then
    pass "prepara: il progetto, il prompt e la copia, niente altro"
  else
    fail "prepara: lo spazio di lavoro non è quello atteso"
  fi
  run "${RADICE}/tools/verifica.sh" M4-D03 --radice "${r}"
  expect "prepara: sul punto di partenza la verifica esce 1" 1 "${PARTENZA}"
}

# --- demo/nuova_copia.sh ----------------------------------------------------

t_copia() {
  local w c n
  ws w
  run bash -c 'cd "$1" && bash nuova_copia.sh esecuzioni/giro-1' _ "${w}"
  expect "copia: pronta" 0 "Copia pronta: esecuzioni/giro-1/urgenze"
  c="${w}/esecuzioni/giro-1/urgenze"
  if cmp -s "${c}/urgenza.py" "${URG}/urgenza.py" \
      && cmp -s "${c}/test_urgenza.py" "${URG}/test_urgenza.py" \
      && cmp -s "${c}/.claude/settings.json" "${w}/.claude/settings.json"
  then
    pass "copia: i file del progetto e le impostazioni dello spazio"
  else
    fail "copia: i file non sono quelli attesi"
  fi
  n="$(git -C "${c}" rev-list --count HEAD 2>/dev/null)"
  if [[ "${n}" == 1 && -z "$(git -C "${c}" status --porcelain)" \
      && "$(git -C "${c}" rev-parse --show-toplevel)" == "$(cd "${c}" \
        && pwd -P)" ]]; then
    pass "copia: un repository git a sé, con un commit, pulito"
  else
    fail "copia: il repository git non è quello atteso (${n})"
  fi
  printf '{"finte": true}\n' > "${w}/altre.json"
  run bash -c 'cd "$1" && bash nuova_copia.sh esecuzioni/giro-2 altre.json' \
    _ "${w}"
  if (( RC == 0 )) && cmp -s "${w}/altre.json" \
      "${w}/esecuzioni/giro-2/urgenze/.claude/settings.json"; then
    pass "copia: le impostazioni date"
  else
    fail "copia: le impostazioni date, rc=${RC}: ${OUT}"
  fi
  run bash -c 'cd "$1" && bash nuova_copia.sh esecuzioni/giro-1' _ "${w}"
  expect "copia: una copia che c'è già, uscita 2" 2 "la copia c'è già"
  run bash "${w}/nuova_copia.sh"
  expect "copia: senza cartella, uscita 2" 2 "uso:"
  run bash -c 'cd "$1" && bash nuova_copia.sh esecuzioni/giro-3 assenti.json' \
    _ "${w}"
  expect "copia: impostazioni che mancano, uscita 2" 2 \
    "mancano le impostazioni"
  rm -rf "${w}/progetti"
  run bash -c 'cd "$1" && bash nuova_copia.sh esecuzioni/giro-4' _ "${w}"
  expect "copia: il progetto che manca, uscita 2" 2 "manca il progetto"
}

# --- controlla_giro.py ------------------------------------------------------

# Un'esecuzione buona: la tabella, i conteggi, i test, il verdetto.
t_buona() {
  local w
  ws w
  buona "${w}"
  controlla "${w}"
  expect "buona: uscita 0 e il verdetto" 0 \
    "${S_GIRO} (giro-1): confermata: l'entrata non scende mai, da 17300 a \
18500 token in 5 richieste"
  expect "buona: l'avvio" 0 \
    "giro-1: Claude Code 9.9.9, modello modello-finto, modalità dontAsk"
  expect "buona: i conteggi" 0 \
    "giro-1: 5 richieste al modello, 4 chiamate a strumenti, 0 permessi \
negati, 21 s"
  expect "buona: la prima richiesta, il percorso relativo" 0 \
    "  richiesta 1: in entrata 17300 token; Read urgenza.py"
  expect "buona: la crescita e il comando, con il suo errore" 0 \
    "  richiesta 2: in entrata 17600 token (+300); Bash «python3 -m \
unittest» (errore)"
  expect "buona: l'ultima richiesta, senza strumenti" 0 \
    "  richiesta 5: in entrata 18500 token (+300); nessuno strumento"
  expect "buona: i test rieseguiti nella copia, come dato" 0 \
    "giro-1: i test, rieseguiti ora nella copia: verdi (3 test, OK)"
  expect_absent "buona: nessuna segnalazione" "Segnalazioni"
  ws w
  copia "${w}" giro-1 rossa
  stream "${w}" giro-1 R17300:Read R17600:Bash! R17900
  controlla "${w}"
  expect "buona: i test rossi sono un dato, uscita 0" 0 \
    "giro-1: i test, rieseguiti ora nella copia: rossi (3 test, FAILED \
(failures=1))"
}

# I conteggi: un id contato una volta, gli eventi senza id, senza usage e
# dei subagent, i dinieghi.
t_conteggi() {
  local w
  ws w
  copia "${w}" giro-1 verde
  stream "${w}" giro-1 R17300:Read R17600:Edit,Bash? R17900
  controlla "${w}"
  expect "conteggi: due strumenti nella stessa richiesta, un id" 0 \
    "  richiesta 2: in entrata 17600 token (+300); Edit urgenza.py; Bash \
«python3 -m unittest» (negato)"
  expect "conteggi: tre richieste e i dinieghi" 0 \
    "giro-1: 3 richieste al modello, 3 chiamate a strumenti, 1 permesso \
negato, 21 s"
  ws w
  copia "${w}" giro-1 verde
  stream "${w}" giro-1 R17300 N17400 R17500
  controlla "${w}"
  expect "conteggi: un messaggio senza id è una richiesta a sé" 0 \
    "  richiesta 2: in entrata 17400 token (+100); nessuno strumento"
  ws w
  copia "${w}" giro-1 verde
  stream "${w}" giro-1 R17300 U R17500
  controlla "${w}"
  expect "conteggi: un messaggio senza usage, fuori dal conto" 0 \
    "giro-1: 1 messaggio dell'assistente senza usage, fuori dal conto"
  expect "conteggi: e le richieste sono due" 0 "giro-1: 2 richieste"
  ws w
  copia "${w}" giro-1 verde
  stream "${w}" giro-1 R17300 S9000 S9100 R17500
  controlla "${w}"
  expect "conteggi: i subagent fuori dal conto, nessuna discesa" 0 \
    "giro-1: 2 messaggi di subagent (parent_tool_use_id), fuori dal conto"
  expect "conteggi: e la garanzia tiene" 0 "(giro-1): confermata"
  ws w
  copia "${w}" giro-1 verde
  stream "${w}" giro-1 R17300 R17300 R17400
  controlla "${w}"
  expect "conteggi: un'entrata uguale non è una discesa" 0 \
    "  richiesta 2: in entrata 17300 token (+0); nessuno strumento"
}

# La garanzia: una discesa è una segnalazione, tranne dopo una
# compattazione.
t_garanzia() {
  local w
  ws w
  copia "${w}" giro-1 verde
  stream "${w}" giro-1 R17300:Read R17600:Bash! R17100:Edit R17400
  controlla "${w}"
  expect "garanzia: una discesa, uscita 1" 1 \
    "${S_GIRO} (giro-1): ${NONCONF}: l'entrata scende dalla richiesta 2 \
alla 3, da 17600 a 17100 token; una segnalazione"
  expect "garanzia: la riga delle segnalazioni" 1 "Segnalazioni: 1."
  expect "garanzia: la discesa nella tabella" 1 \
    "  richiesta 3: in entrata 17100 token (-500); Edit urgenza.py"
  ws w
  copia "${w}" giro-1 verde
  stream "${w}" giro-1 R17300:Read R17600 C R9000:Edit R9300
  controlla "${w}"
  expect "garanzia: dopo una compattazione, uscita 0" 0 \
    "  richiesta 3: in entrata 9000 token (-8600, dopo la compattazione); \
Edit urgenza.py"
  expect "garanzia: il verdetto dice la compattazione" 0 \
    "confermata: l'entrata non scende mai, tranne dopo una compattazione \
(1), da 17300 a 9300 token in 4 richieste"
  ws w
  copia "${w}" giro-1 verde
  stream "${w}" giro-1 R17300 C R9000 R9300 R9200
  controlla "${w}"
  expect "garanzia: una discesa lontana dalla compattazione, uscita 1" 1 \
    "l'entrata scende dalla richiesta 3 alla 4, da 9300 a 9200 token"
  ws w
  buona "${w}" giro-1
  copia "${w}" giro-2 verde
  stream "${w}" giro-2 R17300 R17200
  controlla "${w}"
  expect "garanzia: due esecuzioni, la seconda con una discesa" 1 \
    "${S_GIRO} (giro-2): ${NONCONF}"
  expect "garanzia: la prima resta confermata" 1 \
    "${S_GIRO} (giro-1): confermata"
  ws w
  copia "${w}" giro-1 verde
  stream "${w}" giro-1 R17300
  controlla "${w}"
  expect "garanzia: una sola richiesta, niente da confrontare" 0 \
    "${S_GIRO} (giro-1): non distinguibile: una sola richiesta, niente \
da confrontare"
  stream "${w}" giro-1 R17300 U U
  controlla "${w}"
  expect "garanzia: una sola richiesta con usage, la stessa cosa" 0 \
    "${S_GIRO} (giro-1): non distinguibile"
  stream "${w}" giro-1 R17300:Read T17600 R17900
  controlla "${w}"
  expect "garanzia: U+2028 e U+0085 in una riga non la spezzano" 0 \
    "${S_GIRO} (giro-1): confermata: l'entrata non scende mai, da 17300 a \
17900 token in 3 richieste"
}

# Gli stream rovinati: uscita 1, il motivo, nessun traceback.
t_rovinati() {
  local w
  ws w
  buona "${w}"
  rm "${w}/esecuzioni/giro-1/stream.jsonl"
  controlla "${w}"
  expect "rovinati: uno stream che manca, uscita 1" 1 \
    "manca esecuzioni/giro-1/stream.jsonl"
  expect "rovinati: il messaggio «Non ancora»" 1 "Non ancora:"
  : > "${w}/esecuzioni/giro-1/stream.jsonl"
  controlla "${w}"
  expect "rovinati: uno stream vuoto" 1 "giro-1/stream.jsonl è vuoto"
  printf '{"type": "system"}\n{rotto\n' > "${w}/esecuzioni/giro-1/stream.jsonl"
  controlla "${w}"
  expect "rovinati: una riga che non è JSON" 1 \
    "giro-1/stream.jsonl, riga 2: non è un evento dello stream-json"
  printf '[1, 2]\n' > "${w}/esecuzioni/giro-1/stream.jsonl"
  controlla "${w}"
  expect "rovinati: una riga che non è un oggetto" 1 \
    "giro-1/stream.jsonl, riga 1: non è un evento dello stream-json"
  stream "${w}" giro-1 R17300 +tronco
  controlla "${w}"
  expect "rovinati: senza il risultato in fondo" 1 \
    "lo stream non finisce con il risultato"
  stream "${w}" giro-1 +solo
  controlla "${w}"
  expect "rovinati: soltanto il risultato" 1 \
    "c'è soltanto il risultato, senza gli eventi"
  stream "${w}" giro-1 R17300 +errore
  controlla "${w}"
  expect "rovinati: is_error" 1 "claude ha restituito un errore"
  stream "${w}" giro-1 R17300 +subtype
  controlla "${w}"
  expect "rovinati: un subtype d'errore" 1 "claude ha restituito un errore"
  stream "${w}" giro-1 U
  controlla "${w}"
  expect "rovinati: nessuna richiesta al modello" 1 \
    "nessuna richiesta al modello nello stream"
  stream "${w}" giro-1 R17300 R17600
  rm -rf "${w}/esecuzioni/giro-1/urgenze"
  controlla "${w}"
  expect "rovinati: la copia che manca" 1 \
    "manca la copia esecuzioni/giro-1/urgenze/"
  expect_absent "rovinati: mai un traceback" "Traceback"
}

# Un'esecuzione rovinata accanto a una buona: la verifica resta 1 finché
# la cartella rovinata c'è, e il messaggio dice di toglierla; tolta, 0.
t_rifare() {
  local w
  ws w
  buona "${w}" giro-1
  printf '{rotto\n' > "${w}/esecuzioni/giro-1/stream.jsonl"
  buona "${w}" giro-2
  controlla "${w}"
  expect "rifare: la rovinata accanto alla buona, uscita 1 e il consiglio" 1 \
    "rm -rf esecuzioni/giro-<n>"
  rm -rf "${w}/esecuzioni/giro-1"
  controlla "${w}"
  expect "rifare: tolta la rovinata, uscita 0" 0 \
    "${S_GIRO} (giro-2): confermata"
}

# esecuzioni/ che manca o è vuota, gli argomenti, le precondizioni.
t_precondizioni() {
  local w
  ws w
  controlla "${w}"
  expect "partenza: esecuzioni/ che manca, uscita 1" 1 "${PARTENZA}"
  mkdir -p "${w}/esecuzioni/altro"
  controlla "${w}"
  expect "partenza: esecuzioni/ senza giro-<n>, uscita 1" 1 "${PARTENZA}"
  buona "${w}"
  run python3 -B -I "${D03}/controlla_giro.py" --tutto "${w}"
  expect "precondizione: un'opzione sconosciuta, uscita 2" 2 \
    "opzione sconosciuta: --tutto"
  run python3 -B -I "${D03}/controlla_giro.py" "${w}" "${w}"
  expect "precondizione: due spazi di lavoro" 2 \
    "uno spazio di lavoro per volta"
  run python3 -B -I "${D03}/controlla_giro.py" "${TMP}/assente"
  expect "precondizione: spazio di lavoro assente" 2 \
    "spazio di lavoro assente"
  inatteso "${w}"
  expect "precondizione: un errore inatteso, uscita 2" 2 \
    "errore inatteso (RuntimeError: guasto finto)"
  expect_absent "precondizione: l'errore inatteso senza traceback" \
    "Traceback"
  ws w
  copia "${w}" giro-1 senza_test
  stream "${w}" giro-1 R17300 R17600
  controlla "${w}"
  expect "test: nessun test nella copia, un dato" 0 \
    "giro-1: i test, rieseguiti ora nella copia: nessun test (Ran 0 tests)"
  ws w
  copia "${w}" giro-1 lenta
  stream "${w}" giro-1 R17300 R17600
  run env PN_URGENZE_TIMEOUT=1 python3 -B -I "${D03}/controlla_giro.py" \
    "${w}"
  expect "test: un tempo scaduto, un dato" 0 \
    "giro-1: i test, rieseguiti ora nella copia: non finiscono entro 1 s"
  if (( EUID == 0 )); then
    skip "precondizione: uno stream che non si legge (da root si legge)"
    return 0
  fi
  ws w
  buona "${w}"
  chmod 000 "${w}/esecuzioni/giro-1/stream.jsonl"
  controlla "${w}"
  expect "precondizione: uno stream che non si legge" 2 \
    "esecuzioni/giro-1/stream.jsonl non si legge"
  chmod 644 "${w}/esecuzioni/giro-1/stream.jsonl"
}

# --- verifica.sh ------------------------------------------------------------

t_verifica() {
  local w a
  run "${D03}/verifica.sh"
  expect "verifica: senza spazio di lavoro, uscita 2" 2 \
    "spazio di lavoro assente"
  ws w
  run "${D03}/verifica.sh" "${w}"
  expect "verifica: il punto di partenza, uscita 1" 1 "${PARTENZA}"
  buona "${w}"
  run "${D03}/verifica.sh" "${w}"
  expect "verifica: un'esecuzione buona, uscita 0" 0 "${FINE}"
  if [[ "${OUT##*$'\n'}" == "${FINE}" ]]; then
    pass "verifica: la frase finale è l'ultima riga"
  else
    fail "verifica: l'ultima riga è «${OUT##*$'\n'}»"
  fi
  stream "${w}" giro-1 R17300 R17200
  run "${D03}/verifica.sh" "${w}"
  expect "verifica: una segnalazione, uscita 1" 1 "Segnalazioni: 1."
  expect_absent "verifica: una segnalazione, nessuna frase finale" "Fatto:"
  run env PATH="${TMP}/senza_python" "${D03}/verifica.sh" "${w}"
  expect "verifica: python3 che manca, uscita 2" 2 "manca python3"
  albero_finto a 3
  run "${a}/verifica.sh" "${w}"
  expect "verifica: un controllo che esce con 3, uscita 2" 2 \
    "controlla_giro.py è uscito con 3"
  albero_finto a segnale
  run "${a}/verifica.sh" "${w}"
  expect "verifica: un controllo terminato da un segnale, uscita 2" 2 \
    "controlla_giro.py è uscito con 143"
}

# --- _docente/live.sh -------------------------------------------------------

# Le precondizioni escono 2 prima di ogni invocazione di claude.
t_live_precondizioni() {
  local w f
  precondizione "live: spazio di lavoro assente" "spazio di lavoro assente" \
    "${TMP}/assente"
  for f in prompt.txt nuova_copia.sh progetti/urgenze/urgenza.py; do
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
    "--esecuzioni vuole un numero da 1 a 9" "${w}" "" --esecuzioni 0
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
  ws_git w
  esca "${w}" "${TMP}/senza_claude"
  expect "live: claude che manca" 2 "manca lo strumento: claude"
}

# Il claude finto: un'esecuzione, il testo e le opzioni del README.
t_live_finto() {
  local w w2 r
  ws_git w
  finto "${w}"
  expect "live: un'esecuzione, uscita 0" 0 "VERIFICA OK"
  expect "live: la tabella e il verdetto si vedono anche quando passa" 0 \
    "${FINE}"
  expect "live: il verdetto" 0 "${S_GIRO} (giro-1): confermata"
  expect "live: la riga di claude si vede prima di girare" 0 \
    "--output-format stream-json"
  r="$(grep -cF '  richiesta 1: in entrata' <<< "${OUT}")"
  if (( r == 1 )); then
    pass "live: la tabella si vede una volta sola"
  else
    fail "live: la richiesta 1 si vede ${r} volte"
  fi
  r="$(chiamate "${TMP}/finto.log")"
  if [[ "${r}" == "1 0" ]]; then
    pass "live: una chiamata, senza ANTHROPIC_API_KEY"
  else
    fail "live: chiamate e chiavi «${r}», attese «1 0»"
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
if len(live) != 1 or len(readme) != 1:
    problemi.append("chiamate: live.sh %d, README %d" % (len(live),
                                                        len(readme)))
else:
    pl, ol = analizza(live[0]["argv"])
    pr, orr = analizza(readme[0]["argv"])
    if pl != testo or pr != testo:
        problemi.append("il prompt")
    fisse = (("--model", "sonnet"), ("--allowedTools", strumenti),
             ("--effort", "low"), ("--output-format", "stream-json"),
             ("--setting-sources", "project,local"),
             ("--permission-mode", "dontAsk"),
             ("--permission-prompts", "none"))
    for chiave, valore in list(orr.items()) + list(fisse):
        if ol.get(chiave) != valore:
            problemi.append(chiave)
    for chiave in ("-p", "--verbose", "--strict-mcp-config",
                   "--no-session-persistence"):
        if ol.get(chiave) is not True:
            problemi.append(chiave)
    if "--" not in live[0]["argv"]:
        problemi.append("il prompt non è dopo «--»")
    for riga, base in ((live[0], ws), (readme[0], ws2)):
        attesa = os.path.join(os.path.realpath(base), "esecuzioni",
                              "giro-1", "urgenze")
        if os.path.realpath(riga["cwd"]) != attesa:
            problemi.append("la cartella di partenza")
for base in (ws, ws2):
    if not os.path.isfile(os.path.join(base, "esecuzioni", "giro-1",
                                       "stream.jsonl")):
        problemi.append("lo stream in esecuzioni/giro-1/")
print("; ".join(problemi) or "stesse chiamate")
PY
  expect "live e README: stesso testo, stesse opzioni, dalla copia" 0 \
    "stesse chiamate"
  ws_git w
  finto "${w}" -- --esecuzioni 3
  r="$(chiamate "${TMP}/finto.log")"
  if (( RC == 0 )) && [[ "${r}" == "3 0" ]] \
      && grep -qF "${S_GIRO} (giro-3): confermata" <<< "${OUT}"; then
    pass "live: --esecuzioni 3, tre copie e tre chiamate"
  else
    fail "live: --esecuzioni 3, rc=${RC}, chiamate «${r}»"
  fi
}

# Il claude finto: la prima chiamata fallita, una discesa, una
# compattazione, nessuna correzione, uno stream troncato, i controlli della
# libreria.
t_live_esiti() {
  local w r chiave
  ws_git w
  finto "${w}" FINTO_ESITO=ko -- --esecuzioni 2
  r="$(chiamate "${TMP}/finto.log")"
  if (( RC == 1 )) && [[ "${r}" == "1 0" ]] \
      && grep -qF 'VERIFICA KO' <<< "${OUT}"; then
    pass "live: si ferma alla prima chiamata fallita"
  else
    fail "live: rc=${RC} dopo le chiamate «${r}»: ${OUT:0:300}"
  fi
  ws_git w
  finto "${w}" FINTO_CALO=1
  expect "live: una discesa è una segnalazione, uscita 1" 1 \
    "${S_GIRO} (giro-1): ${NONCONF}"
  ws_git w
  finto "${w}" FINTO_CALO=1 FINTO_COMPATTA=1
  expect "live: dopo una compattazione, uscita 0" 0 \
    "tranne dopo una compattazione (1)"
  ws_git w
  finto "${w}" FINTO_GIRO=non_corregge
  expect "live: nessuna correzione, i test rossi come dato" 0 \
    "giro-1: i test, rieseguiti ora nella copia: rossi"
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
  printf 'Correggi il confine. %s\n' "${chiave}" > "${w}/prompt.txt"
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
  run python3 -B -I - "${D03}/README.md" <<'PY'
import re, sys
testo = open(sys.argv[1], encoding="utf-8").read()
piatto = " ".join(testo.split())
passi = testo.split("## Passi in Claude Code", 1)[-1].split("\n## ", 1)[0]
problemi = []
if "ogni richiesta pesa più della precedente" not in piatto:
    problemi.append("manca «ogni richiesta pesa più della precedente»")
if "giro del ciclo pesa" in piatto:
    problemi.append("«giro» per una richiesta")
if "al posto di ogni `giro-1` del blocco" not in piatto:
    problemi.append("manca «al posto di ogni `giro-1` del blocco»")
if "rm -rf esecuzioni/" not in testo:
    problemi.append("la cartella rovinata da togliere prima di rifarla")
dopo = passi.split("<!-- /comandi -->", 1)[-1]
verifica = dopo.find("tools/verifica.sh M4-D03")
if verifica == -1 or "cd -" not in dopo[:verifica]:
    problemi.append("cd - prima della verifica")
if re.search(r"\b[Rr]am[oi]\b", testo):
    problemi.append("«ramo» per un braccio")
for sigla in ("FACT-", "M4-X", "sessione principale", "P1 "):
    if sigla in testo:
        problemi.append("sigla interna %s" % sigla)
print("; ".join(problemi) or "README in ordine")
PY
  expect "README: le richieste, il blocco, la cartella da togliere, cd -" 0 \
    "README in ordine"
}

# Gli script di M4-D03 e questo file, con shellcheck -x.
t_shellcheck() {
  local f
  for f in "${D03}/verifica.sh" "${D03}/_docente/live.sh" \
      "${D03}/demo/nuova_copia.sh" "${SELF}"; do
    if shellcheck -x "${f}" > /dev/null 2>&1; then
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
      || { echo "test_m4_d03: manca ${t}" >&2; exit 2; }
  done
  [[ -d "${D03}" && -f "${FINTO_PY}" && -d "${URG}" ]] \
    || { echo "test_m4_d03: manca ${D03}, ${FINTO_PY} o ${URG}" >&2; exit 2; }
  handson::init_temp_base
  TMP="$(mktemp -d "${HANDSON_TEMP_BASE}/test_m4_d03.XXXXXX")" || exit 2
  trap 'chmod -R u+rwX "${TMP}" 2>/dev/null; rm -rf "${TMP}"' EXIT
  prepara_claude
  t_file
  t_prepara
  t_copia
  t_buona
  t_conteggi
  t_garanzia
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
    echo "test_m4_d03: girati $((PASS + FAIL + SKIP)) casi, attesi" \
      "${CASES}" >&2
    exit 2
  fi
  (( FAIL == 0 )) || exit 1
}

main "$@"
