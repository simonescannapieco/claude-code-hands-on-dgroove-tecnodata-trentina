#!/bin/bash
#
# test_m4_d02.sh -- le prove di M4-D02 «Un server MCP per la copertura», per
# il docente (sta in _docente/, il materiale del docente):
#   - l'elemento: i suoi file, verifica.sh e _docente/live.sh eseguibili, il
#     README con le dieci sezioni; demo/ senza dati; prepara_esercizio.sh
#     porta la domanda e non il server né il controllo, e verifica.sh vi
#     esce 1;
#   - il progetto uv del server: fastmcp fissato a una versione 3.x esatta,
#     requires-python >= 3.10, un progetto senza pacchetto; uv.lock con la
#     stessa versione e aggiornato (uv lock --check, senza rete);
#   - il server, davvero, con uv run --offline --locked in un ambiente usa
#     e getta (l'albero non cambia): initialize, tools/list (uno strumento,
#     cerca_copertura, in sola lettura, con comune e tecnologia),
#     tools/call (i comuni con la fibra uguali alla verità del controllo e
#     ai tredici attesi; un comune in minuscolo; un comune che non c'è,
#     un errore dello strumento; un comune senza copertura, un elenco
#     vuoto); lo STDOUT solo JSON-RPC; lo stesso in un namespace senza
#     rete (unshare -rn, altrimenti SKIP); COPERTURA_DATI assente,
#     relativa o senza schema.sql: il server esce subito con un messaggio;
#   - controlla_copertura.py: la verità dai dati; i comuni letti in una
#     risposta (elenchi, grassetto, virgole, «e», note, accenti, «Tione di
#     Trento» che non è Trento, «Trentino» che non è un comune); gli stream
#     finti scritti dal claude finto: le due garanzie confermate (0), un
#     server in più, il server non collegato, un nome fuori schema, una
#     chiamata con un altro nome, il server o lo strumento nel braccio
#     senza (1, «non confermata in questa esecuzione»); lo strumento non
#     chiamato e le risposte sbagliate come dati (0); gli stream rotti (1),
#     ma non U+2028 e U+0085 in una riga (0); un file che non si legge, i
#     dati che mancano, argomenti sbagliati, un errore inatteso (2, senza
#     traceback); risposta.txt giusto (0), con comuni che mancano (1, senza
#     dire quali) o in più (1, nominati), vuoto (1);
#   - verifica.sh: spazio di lavoro assente (2), punto di partenza (1), la
#     prova del docente (0, la frase finale per ultima), la vostra prova con
#     il server configurato (0) o no (1, claude mcp get esce 1), claude mcp
#     get che esce oltre 1 (2: un errore, non «non configurato»), claude
#     che manca (2), python3 che manca (2), un controllo che esce 3 o per
#     un segnale (2), sempre con il claude finto davanti nel PATH;
#   - _docente/live.sh: le precondizioni escono 2 senza chiamare claude,
#     anche uno spazio di lavoro con altro oltre a domanda.txt e .claude/
#     (risposte/ e mcp/ di una prova precedente); uv sync che fallisce (2,
#     e il messaggio suggerisce uv sync --frozen);
#     con il claude finto e un uv finto le sei chiamate in ordine, con le
#     stesse opzioni (--tools Read compreso), la domanda, la configurazione
#     del braccio e nessuna chiave; durante ogni chiamata lo spazio di lavoro
#     ha soltanto domanda.txt, .claude/ e .git; le configurazioni in una
#     cartella temporanea fuori dallo spazio di lavoro, tolta alla fine;
#     dopo l'ultima chiamata mcp/ e risposte/ copiate nello spazio di
#     lavoro; le due configurazioni con i percorsi assoluti e uv run
#     --frozen; il comando claude mcp add del README coerente con quella del
#     docente; i verdetti a schermo una volta; la prima chiamata fallita
#     (1, si ferma, e ciò che c'è viene copiato); il server non collegato
#     (1); una modalità di permesso vietata (2, nessuna chiamata);
#   - il README: le frasi di Anthropic parola per parola con il loro
#     indirizzo, il comando di aggiunta (con uv run --frozen) e quello di
#     rimozione, uv sync --frozen che scarica FastMCP la prima volta, perché
#     i due bracci hanno soltanto Read e le risposte entrano alla fine,
#     «braccio» e mai «ramo», nessuna sigla interna; i passi nell'ordine
#     del deck (la preparazione e il passo 1 durante la demo, poi la
#     prova) e «Tempo» come il deck;
#   - shellcheck -x su verifica.sh, live.sh, lib_mcp.sh (che non è
#     eseguibile: si carica con source) e questo file.
# Mai il claude vero: il finto e l'esca stanno davanti nel PATH, e dietro a
# tutti c'è una guardia, un claude che registra ogni invocazione ed esce
# 99: l'ultimo caso controlla che nessun caso sia arrivato fin lì. Gli
# stream finti non sono risposte di Claude: provano il controllo. CASES è
# il numero dei casi: se ne girano di più o di meno la suite esce 2 (un
# caso saltato conta come girato).
#
# Uso:    m4_claude_code_agenti/_docente/test_m4_d02.sh
# Uscita: 0 = tutti i casi passano · 1 = almeno un caso fallito · 2 =
#         precondizione (manca python3, git, shellcheck o uv, la cartella
#         dell'elemento, oppure FastMCP non si risolve senza rete: serve
#         una volta uv sync --directory <server>), o un numero di casi
#         diverso da CASES
set -uo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly MOD="${SELF%/_docente/*}"
readonly RADICE="${MOD%/*}"
D02="${MOD}/s3_agente_nel_repository/m4_4_server_mcp"
D02+="/M4-D02_server_copertura"
readonly D02
readonly SERVER="${D02}/server"
readonly CONTROLLO="${D02}/controlla_copertura.py"
readonly DATI="${RADICE}/progetti/gestionale-php/database"
readonly FINTO_PY="${MOD}/_docente/claude_finto_m4_d01_d02_d08.py"
# shellcheck source=../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"
readonly CASES=106
VERITA='Ala|Arco|Baselga di Pinè|Borgo Valsugana|Caldonazzo|Lavis'
VERITA+='|Levico Terme|Mezzolombardo|Mori|Pergine Valsugana|Riva del Garda'
VERITA+='|Rovereto|Trento'
readonly VERITA
FINE='Fatto: ogni affermazione è stata messa alla prova;'
FINE+=' gli esiti sono qui sopra.'
readonly FINE
readonly PARTENZA='Né risposta.txt né risposte/: eseguite i passi del README.'
readonly NONCONF='non confermata in questa esecuzione'
readonly S249='Con --strict-mcp-config, solo i server di --mcp-config'
readonly S250='Gli strumenti MCP si chiamano mcp__<server>__<tool>'
readonly STRUMENTO=mcp__copertura__cerca_copertura
TMP=''
PASS=0
FAIL=0
SKIP=0
RC=0
OUT=''
TUTTO=''
AMBIENTE=0

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }
skip() { echo "  SKIP: $1"; SKIP=$((SKIP + 1)); }

# Esegue un comando; RC e OUT (STDOUT e STDERR insieme) per expect.
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

# Un nuovo spazio di lavoro: una copia di demo/.
# Arguments: $1 la variabile da assegnare.
ws() {
  local __w
  __w="$(mktemp -d "${TMP}/ws.XXXXXX")" || { echo "mktemp" >&2; exit 2; }
  cp -R "${D02}/demo/." "${__w}/" || exit 2
  printf -v "$1" '%s' "${__w}"
}

# Un'esecuzione finta in risposte/<ramo>-<n>.jsonl, scritta dal claude
# finto con la configurazione MCP del ramo (con: il server copertura;
# senza: nessuno). Arguments: $1 lo spazio, $2 con o senza, $3 n, $4
# «stretta» (con --strict-mcp-config) o «libera», poi NOME=valore per il
# finto.
esecuzione() {
  local w="$1" r="$2" n="$3" modo="$4"
  local -a stretta=(--strict-mcp-config)
  shift 4
  [[ "${modo}" == stretta ]] || stretta=(--verbose)
  mkdir -p "${w}/risposte" || exit 2
  env "$@" python3 -B -I "${FINTO_PY}" -p --allowedTools "${STRUMENTO}" \
    --model sonnet --output-format stream-json --verbose "${stretta[@]}" \
    --mcp-config "${TMP}/mcp-${r}.json" -- "domanda finta" < /dev/null \
    > "${w}/risposte/${r}-${n}.jsonl"
}

# Le tre coppie finte, con le variabili date per il finto.
# Arguments: $1 lo spazio, poi NOME=valore.
coppie() {
  local w="$1" n
  shift
  for n in 1 2 3; do
    esecuzione "${w}" con "${n}" stretta "$@"
    esecuzione "${w}" senza "${n}" stretta "$@"
  done
}

# Cambia uno stream finto con un frammento di Python che riceve gli eventi
# in «eventi» e li può cambiare. Arguments: $1 il file, $2 il frammento.
ritocca() {
  python3 -B -I - "$1" "$2" <<'PY'
import json, sys
percorso, codice = sys.argv[1:3]
eventi = [json.loads(r) for r in open(percorso, encoding="utf-8") if r.strip()]
exec(codice)
with open(percorso, "w", encoding="utf-8") as fh:
    for evento in eventi:
        fh.write(json.dumps(evento, ensure_ascii=False) + "\n")
PY
}

# Il controllo come lo lancia verifica.sh; RC e OUT.
controlla() { run python3 -B -I "${CONTROLLO}" "$@"; }

# Una funzione del controllo, chiamata da Python. Arguments: $1 il codice,
# che vede il modulo come «c», la cartella dei dati in sys.argv[3], e
# stampa ciò che serve.
modulo() {
  run python3 -B -I - "${CONTROLLO}" "$1" "${DATI}" <<'PY'
import importlib.util, sys
spec = importlib.util.spec_from_file_location("controllo", sys.argv[1])
c = importlib.util.module_from_spec(spec)
spec.loader.exec_module(c)
exec(sys.argv[2])
PY
}

# Il ramo dell'errore inatteso: main() del controllo con un controlla() che
# solleva un'eccezione. Arguments: gli argomenti di main.
inatteso() {
  run python3 -B -I -c 'import importlib.util, sys
spec = importlib.util.spec_from_file_location("controllo", sys.argv[1])
modulo = importlib.util.module_from_spec(spec)
spec.loader.exec_module(modulo)
def guasto(*_):
    raise RuntimeError("guasto finto")
modulo.controlla = guasto
sys.exit(modulo.main(sys.argv[2:]))' "${CONTROLLO}" "$@"
}

# Una copia di verifica.sh con un controlla_copertura.py finto accanto:
# esce con il codice dato, o si fa terminare da un segnale.
# Arguments: $1 la variabile da assegnare, $2 il codice o «segnale».
albero_finto() {
  local __a __c
  __a="$(mktemp -d "${TMP}/albero.XXXXXX")" || { echo "mktemp" >&2; exit 2; }
  cp -- "${D02}/verifica.sh" "${__a}/" || exit 2
  __c="${__a}/controlla_copertura.py"
  if [[ "$2" == segnale ]]; then
    printf '%s\n' 'import os, signal' 'os.kill(os.getpid(), signal.SIGTERM)' \
      > "${__c}"
  else
    printf 'import sys\nsys.exit(%d)\n' "$2" > "${__c}"
  fi
  printf -v "$1" '%s' "${__a}"
}

# L'esca, il claude finto, un uv finto (registra gli argomenti in UV_LOG ed
# esce FINTO_UV_ESITO, default 0) e i PATH di prova: senza python3, senza
# uv, senza claude, con il solo readlink. Le due configurazioni MCP finte.
prepara_finti() {
  local t
  mkdir -p "${TMP}/esca" "${TMP}/finto" "${TMP}/uvfinto" \
    "${TMP}/senza_python" "${TMP}/senza_uv" "${TMP}/senza_claude" \
    "${TMP}/solo_readlink" || exit 2
  # shellcheck disable=SC2016  # il corpo è dell'esca
  printf '%s\n' '#!/bin/bash' \
    'printf "invocazione %s\n" "$*" >> "${ESCA_LOG}"' \
    > "${TMP}/esca/claude" || exit 2
  cp -- "${FINTO_PY}" "${TMP}/finto/claude_finto.py" || exit 2
  # shellcheck disable=SC2016  # il corpo è dell'involucro
  printf '%s\n' '#!/bin/bash' \
    'exec python3 "${0%/*}/claude_finto.py" "$@"' \
    > "${TMP}/finto/claude" || exit 2
  # shellcheck disable=SC2016  # il corpo è dell'uv finto
  printf '%s\n' '#!/bin/bash' \
    'printf "%s\n" "$*" >> "${UV_LOG:-/dev/null}"' \
    'exit "${FINTO_UV_ESITO:-0}"' > "${TMP}/uvfinto/uv" || exit 2
  chmod 755 "${TMP}/esca/claude" "${TMP}/finto/claude" "${TMP}/uvfinto/uv" \
    || exit 2
  ln -s "${TMP}/esca/claude" "${TMP}/senza_python/claude" || exit 2
  ln -s "${TMP}/uvfinto/uv" "${TMP}/senza_python/uv" || exit 2
  ln -s "${TMP}/esca/claude" "${TMP}/senza_uv/claude" || exit 2
  ln -s "${TMP}/uvfinto/uv" "${TMP}/senza_claude/uv" || exit 2
  for t in readlink python3; do
    ln -s "$(command -v "${t}")" "${TMP}/senza_uv/${t}" || exit 2
    ln -s "$(command -v "${t}")" "${TMP}/senza_claude/${t}" || exit 2
  done
  ln -s "$(command -v readlink)" "${TMP}/senza_python/readlink" || exit 2
  ln -s "$(command -v readlink)" "${TMP}/solo_readlink/readlink" || exit 2
  t="$(PATH="${TMP}/finto:${PATH}" command -v claude)"
  if [[ "${t}" != "${TMP}/finto/claude" ]]; then
    echo "test_m4_d02: nel PATH di prova claude è ${t}, non il finto" >&2
    exit 2
  fi
  printf '%s\n' '{"mcpServers": {"copertura": {"type": "stdio",' \
    '"command": "uv", "args": ["run"]}}}' > "${TMP}/mcp-con.json" || exit 2
  printf '%s\n' '{"mcpServers": {}}' > "${TMP}/mcp-senza.json" || exit 2
}

# L'ambiente del server, usa e getta: uv sync --offline --locked in
# ${TMP}/venv. AMBIENTE=1 se c'è. Se il progetto c'è, con la versione di
# fastmcp uguale in pyproject.toml e in uv.lock, e la sincronizzazione
# senza rete fallisce, FastMCP non è nella cache di uv: precondizione.
prepara_ambiente() {
  local errore
  [[ -f "${SERVER}/pyproject.toml" && -f "${SERVER}/uv.lock" ]] || return 0
  if errore="$(UV_PROJECT_ENVIRONMENT="${TMP}/venv" uv sync --offline \
      --locked --quiet --directory "${SERVER}" 2>&1)"; then
    AMBIENTE=1
    return 0
  fi
  if versioni_uguali; then
    echo "test_m4_d02: FastMCP non si risolve senza rete: date una volta," \
      "con la rete, uv sync --directory ${SERVER} (${errore:0:200})" >&2
    exit 2
  fi
}

# Vero se la versione di fastmcp fissata in pyproject.toml è quella di
# uv.lock.
versioni_uguali() {
  python3 -B -I - "${SERVER}" <<'PY'
import re, sys
cartella = sys.argv[1]
progetto = open(cartella + "/pyproject.toml", encoding="utf-8").read()
blocco = open(cartella + "/uv.lock", encoding="utf-8").read()
fissata = re.search(r'"fastmcp==([0-9][^"]*)"', progetto)
bloccata = re.search(r'\[\[package\]\]\nname = "fastmcp"\nversion = "([^"]+)"',
                     blocco)
sys.exit(0 if fissata and bloccata
         and fissata.group(1) == bloccata.group(1) else 1)
PY
}

# Il dialogo con il server, una richiesta per volta, in ${TMP}/dialogo.py:
# stampa un riassunto JSON delle risposte.
scrivi_dialogo() {
  cat > "${TMP}/dialogo.py" <<'PY' || exit 2
import json, select, subprocess, sys, time
LIMITE = 90
p = subprocess.Popen(sys.argv[1:], stdin=subprocess.PIPE,
                     stdout=subprocess.PIPE, stderr=subprocess.PIPE)
non_json = 0

def manda(msg):
    p.stdin.write((json.dumps(msg) + "\n").encode("utf-8"))
    p.stdin.flush()

def ricevi(ident):
    global non_json
    fine = time.time() + LIMITE
    while time.time() < fine:
        pronti, _, _ = select.select([p.stdout], [], [], 0.5)
        if not pronti:
            continue
        riga = p.stdout.readline()
        if not riga:
            return None
        try:
            doc = json.loads(riga)
        except ValueError:
            non_json += 1
            continue
        if isinstance(doc, dict) and doc.get("id") == ident:
            return doc
    return None

def righe(risposta):
    if not risposta or "result" not in risposta:
        return None
    ris = risposta["result"]
    strutturato = ris.get("structuredContent")
    if isinstance(strutturato, dict) and "result" in strutturato:
        return strutturato["result"]
    return json.loads(ris["content"][0]["text"])

def chiama(ident, argomenti):
    manda({"jsonrpc": "2.0", "id": ident, "method": "tools/call",
           "params": {"name": "cerca_copertura", "arguments": argomenti}})
    return ricevi(ident)

riassunto = {}
manda({"jsonrpc": "2.0", "id": 1, "method": "initialize",
       "params": {"protocolVersion": "2025-06-18", "capabilities": {},
                  "clientInfo": {"name": "prova-corso", "version": "1"}}})
inizio = ricevi(1)
riassunto["nome"] = inizio and inizio["result"]["serverInfo"]["name"]
manda({"jsonrpc": "2.0", "method": "notifications/initialized"})
manda({"jsonrpc": "2.0", "id": 2, "method": "tools/list"})
elenco = ricevi(2)
strumenti = elenco["result"]["tools"] if elenco else []
riassunto["strumenti"] = [s["name"] for s in strumenti]
if strumenti:
    riassunto["sola_lettura"] = strumenti[0].get(
        "annotations", {}).get("readOnlyHint")
    riassunto["parametri"] = sorted(
        strumenti[0]["inputSchema"].get("properties", {}))
ftth = righe(chiama(3, {"tecnologia": "FTTH"}))
riassunto["ftth"] = ftth is not None and "|".join(sorted(
    r["comune"] for r in ftth if r["indirizzi_coperti"] > 0))
riassunto["ftth_tecnologie"] = ftth is not None and sorted(
    {r["tecnologia"] for r in ftth})
cles = righe(chiama(4, {"comune": "cles"}))
riassunto["cles"] = cles is not None and [
    [r["comune"], r["tecnologia"], r["indirizzi_coperti"]] for r in cles]
sconosciuto = chiama(5, {"comune": "Inesistente"})
riassunto["sconosciuto"] = sconosciuto and [
    sconosciuto["result"].get("isError"),
    sconosciuto["result"]["content"][0]["text"]]
riassunto["male"] = righe(chiama(6, {"comune": "Malé"}))
p.stdin.close()
try:
    p.wait(30)
except subprocess.TimeoutExpired:
    p.kill()
riassunto["non_json"] = non_json
print(json.dumps(riassunto, ensure_ascii=False))
PY
}

# Il server attraverso uv run, senza rete per uv, con COPERTURA_DATI sui
# dati del gestionale; il riassunto in OUT. Arguments: facoltativo un
# prefisso del comando (unshare -rn).
dialogo() {
  if (( AMBIENTE != 1 )); then
    OUT='ambiente del server non pronto'
    RC=2
    return 0
  fi
  OUT="$(COPERTURA_DATI="${DATI}" UV_PROJECT_ENVIRONMENT="${TMP}/venv" \
    "$@" python3 -B -I "${TMP}/dialogo.py" uv run --offline --locked \
    --quiet --directory "${SERVER}" server_copertura.py 2>/dev/null)"
  RC=$?
}

# Un campo del riassunto in OUT, come JSON compatto. Arguments: $1 il campo.
campo() {
  python3 -B -I -c 'import json, sys
print(json.dumps(json.loads(sys.argv[1]).get(sys.argv[2]),
                 ensure_ascii=False, separators=(",", ":")))' \
    "${OUT}" "$1" 2>/dev/null
}

# Il server con un ambiente dato, senza STDIN: deve uscire da solo.
# Arguments: $1 il valore di COPERTURA_DATI ("-" = assente).
avvio() {
  if (( AMBIENTE != 1 )); then
    OUT='ambiente del server non pronto'
    RC=0
    return 0
  fi
  local -a ambiente=(env -u COPERTURA_DATI)
  [[ "$1" == "-" ]] || ambiente=(env "COPERTURA_DATI=$1")
  OUT="$("${ambiente[@]}" UV_PROJECT_ENVIRONMENT="${TMP}/venv" \
    uv run --offline --locked --quiet --directory "${SERVER}" \
    server_copertura.py < /dev/null 2> "${TMP}/avvio.err")"
  RC=$?
  OUT+="$(cat "${TMP}/avvio.err")"
}

# L'esca davanti nel PATH (o un PATH dato), con l'uv finto; live.sh.
# Arguments: $1 lo spazio, $2 facoltativo il PATH.
esca() {
  : > "${TMP}/esca.log"
  run env PATH="${2:-${TMP}/uvfinto:${TMP}/esca:${PATH}}" HANDSON_NO_PAUSE=1 \
    ESCA_LOG="${TMP}/esca.log" "${D02}/_docente/live.sh" "$1"
}

# Una precondizione di live.sh: uscita 2, la parola, nessuna invocazione.
# Arguments: $1 il nome, $2 la parola, poi gli argomenti di esca.
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

# live.sh con il claude finto e l'uv finto, e una ANTHROPIC_API_KEY
# nell'ambiente, che live.sh deve togliere. Arguments: $1 lo spazio, poi
# NOME=valore.
finto() {
  local w="$1"
  shift
  : > "${TMP}/finto.log"
  : > "${TMP}/uv.log"
  run env PATH="${TMP}/uvfinto:${TMP}/finto:${PATH}" HANDSON_NO_PAUSE=1 \
    ANTHROPIC_API_KEY=valore-reale-finto FINTO_LOG="${TMP}/finto.log" \
    UV_LOG="${TMP}/uv.log" "$@" "${D02}/_docente/live.sh" "${w}"
}

# --- L'elemento ----------------------------------------------------------

t_elemento() {
  local f mancanti='' sezione pat ap="'" alt="(’|')"
  for f in README.md demo/domanda.txt controlla_copertura.py verifica.sh \
      _docente/live.sh _docente/lib_mcp.sh soluzione/LEGGIMI.md \
      server/pyproject.toml server/uv.lock server/server_copertura.py; do
    [[ -f "${D02}/${f}" ]] || mancanti+=" ${f}"
  done
  if [[ -z "${mancanti}" ]]; then
    pass "elemento: i suoi file ci sono"
  else
    fail "elemento: mancano${mancanti}"
  fi
  if [[ -x "${D02}/verifica.sh" && -x "${D02}/_docente/live.sh" \
      && ! -x "${D02}/_docente/lib_mcp.sh" ]]; then
    pass "elemento: verifica.sh e live.sh eseguibili, lib_mcp.sh no"
  else
    fail "elemento: il bit di esecuzione di verifica.sh, live.sh o" \
      "lib_mcp.sh non va"
  fi
  mancanti=''
  for sezione in "${HANDSON_README_SECTIONS[@]}"; do
    pat="${sezione//${ap}/${alt}}"
    grep -Eq -- "^##[[:space:]]+${pat}([^[:alnum:]_]|\$)" \
      "${D02}/README.md" 2>/dev/null || mancanti+=" «${sezione}»"
  done
  if [[ -z "${mancanti}" ]]; then
    pass "README: le dieci sezioni"
  else
    fail "README: mancano${mancanti}"
  fi
  f="$(command find "${D02}/demo" -type f ! -name domanda.txt \
    ! -path '*/.claude/*' 2>/dev/null)"
  if [[ -z "${f}" && -f "${D02}/demo/domanda.txt" ]] \
      && ! grep -qiE 'pergine|rovereto|trento' "${D02}/demo/domanda.txt"; then
    pass "elemento: demo/ ha la sola domanda, nessun dato"
  else
    fail "elemento: in demo/ c'è altro: ${f}"
  fi
}

# prepara_esercizio.sh e tools/verifica.sh sul punto di partenza.
t_prepara() {
  local radice w
  radice="$(mktemp -d "${TMP}/radice.XXXXXX")" || exit 2
  run "${RADICE}/tools/prepara_esercizio.sh" M4-D02 --radice "${radice}"
  w="${radice}/M4-D02"
  if (( RC == 0 )) && [[ -f "${w}/domanda.txt" && ! -e "${w}/server" \
      && ! -e "${w}/controlla_copertura.py" && ! -e "${w}/progetti" \
      && ! -e "${w}/soluzione" ]]; then
    pass "prepara: la domanda, niente server, controllo, dati, soluzione"
  else
    fail "prepara: rc=${RC}: ${OUT:0:300}"
  fi
  run "${RADICE}/tools/verifica.sh" M4-D02 --radice "${radice}"
  expect "prepara: sul punto di partenza la verifica esce 1" 1 "${PARTENZA}"
}

# --- Il progetto uv e il server -------------------------------------------

t_progetto() {
  run python3 -B -I - "${SERVER}" <<'PY'
import re, sys
testo = open(sys.argv[1] + "/pyproject.toml", encoding="utf-8").read()
problemi = []
if not re.search(r'"fastmcp==3\.\d+\.\d+"', testo):
    problemi.append("fastmcp non fissato a una 3.x esatta")
if 'requires-python = ">=3.10"' not in testo:
    problemi.append("requires-python non è >=3.10")
if not re.search(r"\[tool\.uv\]\s*\npackage = false", testo):
    problemi.append("non è un progetto senza pacchetto")
print("; ".join(problemi) or "pyproject.toml in ordine")
PY
  expect "progetto: fastmcp 3.x esatto, Python >= 3.10, senza pacchetto" 0 \
    "pyproject.toml in ordine"
  if versioni_uguali 2>/dev/null; then
    pass "progetto: uv.lock ha la versione di pyproject.toml"
  else
    fail "progetto: uv.lock e pyproject.toml hanno versioni diverse"
  fi
  run uv lock --check --offline --directory "${SERVER}"
  if (( RC == 0 )); then
    pass "progetto: uv.lock aggiornato (uv lock --check, senza rete)"
  else
    fail "progetto: uv lock --check: ${OUT:0:300}"
  fi
}

# Il server, davvero: il dialogo.
t_server() {
  local verita
  dialogo
  if (( RC == 0 )) && [[ "$(campo nome)" == '"copertura"' \
      && "$(campo non_json)" == 0 ]]; then
    pass "server: initialize risponde copertura, lo STDOUT è solo JSON-RPC"
  else
    fail "server: initialize, rc=${RC}: ${OUT:0:300}"
  fi
  if [[ "$(campo strumenti)" == '["cerca_copertura"]' ]]; then
    pass "server: un solo strumento, cerca_copertura"
  else
    fail "server: gli strumenti sono $(campo strumenti)"
  fi
  if [[ "$(campo sola_lettura)" == true ]]; then
    pass "server: lo strumento è in sola lettura (readOnlyHint)"
  else
    fail "server: readOnlyHint è $(campo sola_lettura)"
  fi
  if [[ "$(campo parametri)" == '["comune","tecnologia"]' ]]; then
    pass "server: i parametri comune e tecnologia"
  else
    fail "server: i parametri sono $(campo parametri)"
  fi
  if [[ "$(campo ftth)" == "\"${VERITA}\"" \
      && "$(campo ftth_tecnologie)" == '["FTTH"]' ]]; then
    pass "server: i tredici comuni con indirizzi coperti in FTTH"
  else
    fail "server: FTTH dà $(campo ftth) $(campo ftth_tecnologie)"
  fi
  verita="$(python3 -B -I - "${CONTROLLO}" "${DATI}" 2>/dev/null <<'PY'
import importlib.util, sys
spec = importlib.util.spec_from_file_location("controllo", sys.argv[1])
c = importlib.util.module_from_spec(spec)
spec.loader.exec_module(c)
print("|".join(c.verita(sys.argv[2])[0]))
PY
)"
  if [[ "$(campo ftth)" == "\"${verita}\"" ]]; then
    pass "server: gli stessi comuni della verità del controllo"
  else
    fail "server: la verità del controllo è «${verita}»"
  fi
  if [[ "$(campo cles)" == '[["Cles","FWA",34]]' ]]; then
    pass "server: un comune in minuscolo, cles, con la sua riga FWA"
  else
    fail "server: cles dà $(campo cles)"
  fi
  if [[ "$(campo sconosciuto)" == '[true,"comune sconosciuto: Inesistente'* ]]
  then
    pass "server: un comune che non c'è è un errore dello strumento"
  else
    fail "server: Inesistente dà $(campo sconosciuto)"
  fi
  if [[ "$(campo male)" == '[]' ]]; then
    pass "server: un comune senza copertura dà un elenco vuoto"
  else
    fail "server: Malé dà $(campo male)"
  fi
  t_server_senza_rete
  t_server_avvio
}

# Lo stesso dialogo senza rete, in un namespace che non ne ha.
t_server_senza_rete() {
  if ! unshare -rn true > /dev/null 2>&1; then
    skip "server: senza rete (unshare -rn non è disponibile qui)"
    return 0
  fi
  dialogo unshare -rn
  if [[ "$(campo ftth)" == "\"${VERITA}\"" ]]; then
    pass "server: in un namespace senza rete risponde lo stesso"
  else
    fail "server: senza rete, rc=${RC}: ${OUT:0:300}"
  fi
}

# Il server con COPERTURA_DATI assente, relativa o senza schema.sql.
t_server_avvio() {
  local vuota
  avvio -
  if (( RC != 0 )) && grep -qF 'COPERTURA_DATI' <<< "${OUT}" \
      && [[ "${OUT}" != *'"jsonrpc"'* ]]; then
    pass "server: senza COPERTURA_DATI esce subito con un messaggio"
  else
    fail "server: senza COPERTURA_DATI, rc=${RC}: ${OUT:0:300}"
  fi
  avvio progetti/gestionale-php/database
  if (( RC != 0 )) && grep -qF 'assoluto' <<< "${OUT}"; then
    pass "server: COPERTURA_DATI relativa, rifiutata"
  else
    fail "server: COPERTURA_DATI relativa, rc=${RC}: ${OUT:0:300}"
  fi
  vuota="$(mktemp -d "${TMP}/vuota.XXXXXX")" || exit 2
  avvio "${vuota}"
  if (( RC != 0 )) && grep -qF 'schema.sql' <<< "${OUT}"; then
    pass "server: una cartella senza schema.sql, rifiutata"
  else
    fail "server: senza schema.sql, rc=${RC}: ${OUT:0:300}"
  fi
}

# --- controlla_copertura.py ---------------------------------------------

# La verità e i comuni letti in una risposta.
t_lettura() {
  modulo 'ftth, tutti = c.verita(sys.argv[3])
print("|".join(ftth), len(tutti))'
  expect "controllo: la verità, tredici comuni su venti" 0 "${VERITA} 20"
  # shellcheck disable=SC2016  # Python, con un nome fra apici inversi
  modulo 'tutti = c.verita(sys.argv[3])[1]
casi = [("1. **Ala**\n- Arco\n* `Trento`", {"Ala", "Arco", "Trento"}),
        ("Ala, Arco e Lavis.", {"Ala", "Arco", "Lavis"}),
        ("Trento (fino a 2,5 Gbit/s)", {"Trento"}),
        ("ROVERETO; mori", {"Rovereto", "Mori"})]
errati = [t for t, a in casi if c.nominati(t, tutti) != a]
print("forme: " + ("ok" if not errati else repr(errati)))'
  expect "controllo: elenchi, grassetto, virgole, note, maiuscole" 0 \
    "forme: ok"
  modulo 'tutti = c.verita(sys.argv[3])[1]
casi = [("Tione di Trento", {"Tione di Trento"}),
        ("Tione di Trento\nTrento", {"Tione di Trento", "Trento"}),
        ("CiaspoLink opera in Trentino.", set())]
errati = [t for t, a in casi if c.nominati(t, tutti) != a]
print("sovrapposti: " + ("ok" if not errati else repr(errati)))'
  expect "controllo: Tione di Trento non è Trento, il Trentino non conta" 0 \
    "sovrapposti: ok"
  modulo 'tutti = c.verita(sys.argv[3])[1]
casi = [("Baselga di Pine'"'"'", {"Baselga di Pinè"}),
        ("Baselga di Pine", {"Baselga di Pinè"}),
        ("Baselga di Piné", {"Baselga di Pinè"}),
        ("Malè", {"Malé"}), ("Male", set()),
        ("non è male", set())]
errati = [t for t, a in casi if c.nominati(t, tutti) != a]
print("accenti: " + ("ok" if not errati else repr(errati)))'
  expect "controllo: gli accenti e l'apostrofo; male non è Malé" 0 \
    "accenti: ok"
}

# La prova del docente: le garanzie.
t_coppie() {
  local w
  ws w
  controlla "${w}"
  expect "controllo: il punto di partenza, uscita 1" 1 "${PARTENZA}"
  coppie "${w}"
  controlla "${w}"
  expect "controllo: le tre coppie finte, uscita 0" 0 \
    "«${S249}» (senza, 3): confermata"
  expect "controllo: con il server, solo il server copertura" 0 \
    "«${S249}» (con, 1): confermata"
  expect "controllo: il nome dello strumento" 0 "«${S250}» (con, 2): confermata"
  expect "controllo: lo strumento chiamato, come dato" 0 \
    "lo strumento del server chiamato: 3 su 3"
  expect "controllo: le risposte giuste, come dati" 0 \
    "con il server 3 su 3, senza 0 su 3"
  expect "controllo: i dati di un'esecuzione" 0 \
    "con, 1: server copertura (connected)"
  ws w
  coppie "${w}"
  esecuzione "${w}" con 2 libera
  controlla "${w}"
  expect "controllo: un server in più nella sessione, uscita 1" 1 \
    "«${S249}» (con, 2): ${NONCONF}"
  ws w
  coppie "${w}"
  esecuzione "${w}" con 1 stretta FINTO_STATO=failed
  controlla "${w}"
  expect "controllo: il server non collegato, uscita 1" 1 \
    "il server copertura non si è collegato"
  ws w
  coppie "${w}"
  esecuzione "${w}" con 3 stretta \
    FINTO_NOME_STRUMENTO=copertura__cerca_copertura
  controlla "${w}"
  expect "controllo: un nome fuori schema, uscita 1" 1 \
    "«${S250}» (con, 3): ${NONCONF}"
  t_coppie_altre
}

# Le altre garanzie che non tengono, e i dati che non decidono.
t_coppie_altre() {
  local w
  ws w
  coppie "${w}"
  esecuzione "${w}" con 1 stretta FINTO_NOME_USO=mcp__altro__cerca_copertura
  controlla "${w}"
  expect "controllo: una chiamata con un altro nome, uscita 1" 1 \
    "«${S250}» (con, 1): ${NONCONF}"
  ws w
  coppie "${w}"
  cp "${w}/risposte/con-2.jsonl" "${w}/risposte/senza-2.jsonl"
  controlla "${w}"
  expect "controllo: il server nel ramo senza, uscita 1" 1 \
    "«${S249}» (senza, 2): ${NONCONF}"
  ws w
  coppie "${w}"
  ritocca "${w}/risposte/senza-1.jsonl" 'eventi.insert(1, {
    "type": "assistant", "message": {"role": "assistant", "content": [{
    "type": "tool_use", "id": "toolu_x",
    "name": "mcp__copertura__cerca_copertura", "input": {}}]}})'
  controlla "${w}"
  expect "controllo: lo strumento chiamato nel ramo senza, uscita 1" 1 \
    "«${S249}» (senza, 1): ${NONCONF}"
  ws w
  coppie "${w}" FINTO_CHIAMA=0
  controlla "${w}"
  expect "controllo: lo strumento mai chiamato, un dato, uscita 0" 0 \
    "lo strumento del server chiamato: 0 su 3"
  ws w
  coppie "${w}" FINTO_RISPOSTA_CON=$'Trento\nRovereto\nCles'
  controlla "${w}"
  expect "controllo: risposte sbagliate, un dato, uscita 0" 0 \
    "con il server 0 su 3, senza 0 su 3"
  expect "controllo: i comuni in più si nominano" 0 "in più: Cles"
}

# Gli stream rotti, i file e gli argomenti.
t_stream() {
  local w
  ws w
  coppie "${w}"
  rm "${w}/risposte/senza-3.jsonl"
  controlla "${w}"
  expect "controllo: uno stream che manca, uscita 1" 1 \
    "manca risposte/senza-3.jsonl"
  ws w
  coppie "${w}"
  esecuzione "${w}" con 1 stretta FINTO_TRONCO=1
  controlla "${w}"
  expect "controllo: uno stream senza il risultato, uscita 1" 1 \
    "non finisce con il risultato"
  ws w
  coppie "${w}"
  ritocca "${w}/risposte/con-1.jsonl" 'eventi[:] = eventi[-1:]'
  controlla "${w}"
  expect "controllo: soltanto il risultato, uscita 1" 1 "soltanto il risultato"
  ws w
  coppie "${w}"
  printf 'non JSON\n' >> "${w}/risposte/con-1.jsonl"
  controlla "${w}"
  expect "controllo: una riga che non è JSON, uscita 1" 1 "riga 8"
  ws w
  coppie "${w}"
  ritocca "${w}/risposte/con-1.jsonl" 'eventi[-1]["is_error"] = True'
  controlla "${w}"
  expect "controllo: un risultato d'errore, uscita 1" 1 "un errore"
  ws w
  coppie "${w}"
  ritocca "${w}/risposte/senza-1.jsonl" 'del eventi[0]'
  controlla "${w}"
  expect "controllo: uno stream senza init, uscita 1" 1 "system/init"
  expect_absent "controllo: gli stream rotti, nessun traceback" "Traceback"
  # U+2028 e U+0085 dentro un testo: JSON li lascia nella riga così come
  # sono, e la riga resta una sola (lo stream si divide soltanto a \n).
  ws w
  coppie "${w}"
  ritocca "${w}/risposte/con-1.jsonl" \
    'eventi[0]["nota"] = "una riga con i separatori\u0085di Unicode"'
  controlla "${w}"
  expect "controllo: U+2028 e U+0085 in una riga non la spezzano, uscita 0" 0 \
    "«${S249}» (con, 1): confermata"
  t_argomenti "${w}"
}

# I file che non si leggono, i dati, gli argomenti, l'errore inatteso.
# Arguments: $1 uno spazio di lavoro con le risposte.
t_argomenti() {
  local w
  if (( $(id -u) == 0 )); then
    skip "controllo: un file che non si legge (root legge ovunque)"
  else
    ws w
    coppie "${w}"
    chmod 000 "${w}/risposte/con-2.jsonl"
    controlla "${w}"
    expect "controllo: uno stream che non si legge, uscita 2" 2 \
      "non si legge"
    chmod 644 "${w}/risposte/con-2.jsonl"
  fi
  controlla --dati "${TMP}/assente" "$1"
  expect "controllo: i dati che mancano, uscita 2" 2 \
    "i dati del gestionale non si leggono"
  controlla --boh
  expect "controllo: un'opzione sconosciuta, uscita 2" 2 "Uso:"
  controlla "$1" "$1"
  expect "controllo: due spazi di lavoro, uscita 2" 2 "Uso:"
  controlla "${TMP}/assente"
  expect "controllo: spazio di lavoro assente, uscita 2" 2 \
    "spazio di lavoro assente"
  inatteso "$1"
  expect "controllo: un errore inatteso, uscita 2" 2 "errore inatteso"
  expect_absent "controllo: un errore inatteso, nessun traceback" \
    "Traceback"
}

# La prova dei partecipanti: risposta.txt.
t_risposta() {
  local w
  ws w
  tr '|' '\n' <<< "${VERITA}" > "${w}/risposta.txt"
  controlla "${w}"
  expect "risposta: i comuni giusti, uscita 0" 0 \
    "risposta.txt: 13 comuni nominati, giusti 13 su 13"
  ws w
  tr '|' '\n' <<< "${VERITA}" | grep -v -e '^Ala$' -e '^Mori$' \
    > "${w}/risposta.txt"
  controlla "${w}"
  if (( RC == 1 )) && grep -qF 'mancano 2' <<< "${OUT}" \
      && ! grep -qE '(^|[^[:alpha:]])(Ala|Mori)([^[:alpha:]]|$)' <<< "${OUT}"
  then
    pass "risposta: due comuni che mancano, uscita 1, senza dire quali"
  else
    fail "risposta: due che mancano, rc=${RC}: ${OUT:0:300}"
  fi
  ws w
  { tr '|' '\n' <<< "${VERITA}"; echo Cles; } > "${w}/risposta.txt"
  controlla "${w}"
  expect "risposta: un comune in più, uscita 1, nominato" 1 "in più: Cles"
  ws w
  : > "${w}/risposta.txt"
  controlla "${w}"
  expect "risposta: vuota, uscita 1" 1 "risposta.txt: 0 comuni nominati"
}

# --- verifica.sh --------------------------------------------------------

t_verifica() {
  local w a
  run "${D02}/verifica.sh"
  expect "verifica: senza spazio di lavoro, uscita 2" 2 \
    "spazio di lavoro assente"
  ws w
  run "${D02}/verifica.sh" "${w}"
  expect "verifica: il punto di partenza, uscita 1" 1 "${PARTENZA}"
  coppie "${w}"
  run "${D02}/verifica.sh" "${w}"
  expect "verifica: la prova del docente, uscita 0" 0 "${FINE}"
  if [[ "${OUT##*$'\n'}" == "${FINE}" ]]; then
    pass "verifica: la frase finale è l'ultima riga"
  else
    fail "verifica: l'ultima riga è «${OUT##*$'\n'}»"
  fi
  ws w
  tr '|' '\n' <<< "${VERITA}" > "${w}/risposta.txt"
  run env PATH="${TMP}/finto:${PATH}" "${D02}/verifica.sh" "${w}"
  expect "verifica: la vostra prova, il server configurato, uscita 0" 0 \
    "Status: ✓ Connected (finto)"
  run env PATH="${TMP}/finto:${PATH}" FINTO_MCP_GET=no \
    "${D02}/verifica.sh" "${w}"
  expect "verifica: il server non configurato, uscita 1" 1 \
    "non è configurato in questo spazio di lavoro"
  # claude mcp get che esce oltre 1 è un errore della CLI: non dice se il
  # server c'è, e non è «non configurato».
  run env PATH="${TMP}/finto:${PATH}" FINTO_MCP_GET=2 \
    "${D02}/verifica.sh" "${w}"
  expect "verifica: claude mcp get che esce con 2, un errore: uscita 2" 2 \
    "claude mcp get copertura è uscito con 2"
  expect_absent \
    "verifica: un errore di claude mcp get non è «non configurato»" \
    "non è configurato in questo spazio di lavoro"
  run env PATH="${TMP}/senza_claude" "${D02}/verifica.sh" "${w}"
  expect "verifica: claude che manca, uscita 2" 2 "manca claude"
  run env PATH="${TMP}/solo_readlink" "${D02}/verifica.sh" "${w}"
  expect "verifica: python3 che manca, uscita 2" 2 "manca python3"
  albero_finto a 3
  run env PATH="${TMP}/finto:${PATH}" "${a}/verifica.sh" "${w}"
  expect "verifica: un controllo che esce con 3, uscita 2" 2 \
    "controlla_copertura.py è uscito con 3"
  albero_finto a segnale
  run env PATH="${TMP}/finto:${PATH}" "${a}/verifica.sh" "${w}"
  expect "verifica: un controllo terminato da un segnale, uscita 2" 2 \
    "controlla_copertura.py è uscito con 143"
}

# --- _docente/live.sh ---------------------------------------------------

t_live_precondizioni() {
  local w
  precondizione "live: spazio di lavoro assente" "spazio di lavoro assente" \
    "${TMP}/assente"
  ws w
  rm "${w}/domanda.txt"
  precondizione "live: domanda.txt che manca" \
    "file assente o illeggibile: domanda.txt" "${w}"
  ws w
  precondizione "live: uv che manca" "manca lo strumento: uv" "${w}" \
    "${TMP}/senza_uv"
  ws w
  precondizione "live: python3 che manca" "manca lo strumento: python3" \
    "${w}" "${TMP}/senza_python"
  ws w
  esca "${w}" "${TMP}/senza_claude"
  expect "live: claude che manca" 2 "manca lo strumento: claude"
  ws w
  mkdir -p "${w}/risposte" "${w}/mcp"
  : > "${w}/risposte/con-1.jsonl"
  precondizione "live: uno spazio di lavoro con le risposte di prima" \
    "soltanto domanda.txt e .claude/" "${w}"
  ws w
  : > "${TMP}/esca.log"
  run env PATH="${TMP}/uvfinto:${TMP}/esca:${PATH}" HANDSON_NO_PAUSE=1 \
    ESCA_LOG="${TMP}/esca.log" FINTO_UV_ESITO=1 "${D02}/_docente/live.sh" \
    "${w}"
  if (( RC == 2 )) && grep -qF "l'ambiente del server non è pronto" \
      <<< "${OUT}" && ! grep -q -- '-p' "${TMP}/esca.log"; then
    pass "live: uv sync che fallisce, uscita 2, nessuna chiamata al modello"
  else
    fail "live: uv sync che fallisce, rc=${RC}: ${OUT:0:300}"
  fi
  # Il comando suggerito tiene --frozen, come il README: un uv diverso non
  # riscrive uv.lock.
  if grep -qF 'uv sync --frozen --directory' <<< "${OUT}"; then
    pass "live: il messaggio suggerisce uv sync --frozen --directory"
  else
    fail "live: il messaggio non suggerisce uv sync --frozen: ${OUT:0:300}"
  fi
}

# Le chiamate -p del registro, una per riga: la chiave, le opzioni in
# ordine alfabetico e il prompt. Arguments: $1 il registro.
chiamate() {
  python3 -B -I - "$1" <<'PY'
import json, sys
VALORE = {"--model", "--effort", "--tools", "--allowedTools",
          "--output-format", "--setting-sources", "--permission-mode",
          "--permission-prompts", "--mcp-config"}
for riga in open(sys.argv[1], encoding="utf-8"):
    voce = json.loads(riga)
    argv = voce["argv"]
    if argv[:1] != ["-p"]:
        continue
    opzioni, prompt, i = [], None, 1
    while i < len(argv):
        if argv[i] == "--":
            prompt = argv[i + 1]
            break
        if argv[i] in VALORE:
            opzioni.append("%s=%s" % (argv[i], argv[i + 1]))
            i += 2
        else:
            opzioni.append(argv[i])
            i += 1
    print("%s | %s | %s" % (voce["chiave"], " ".join(sorted(opzioni)),
                            prompt))
PY
}

# Le sei chiamate -p di live.sh nel registro del finto, in quattro righe
# in OUT: «opzioni:» (le stesse in ogni chiamata, --tools Read compreso, la
# domanda, nessuna chiave, prima con e poi senza), «pulito:» (durante ogni
# chiamata la cartella corrente, lo spazio di lavoro, ha soltanto
# domanda.txt, .claude e .git), «fuori:» (--mcp-config in una sola cartella
# temporanea, assoluta, fuori dallo spazio di lavoro, che alla fine non
# c'è più), «consegna:» (dopo, nello spazio di lavoro, mcp/con.json,
# mcp/senza.json e le sei risposte). Arguments: $1 il registro, $2 lo
# spazio di lavoro.
analisi() {
  run python3 -B -I - "$1" "$2" <<'PY'
import json, os, sys
log, ws = sys.argv[1:3]
VALORE = {"--model", "--effort", "--tools", "--allowedTools",
          "--output-format", "--setting-sources", "--permission-mode",
          "--permission-prompts", "--mcp-config"}
ATTESE = {"--allowedTools=mcp__copertura__cerca_copertura", "--effort=low",
          "--model=sonnet", "--no-session-persistence",
          "--output-format=stream-json", "--permission-mode=dontAsk",
          "--permission-prompts=none", "--setting-sources=project,local",
          "--strict-mcp-config", "--tools=Read", "--verbose"}
PULITO = {".claude", ".git", "domanda.txt"}
domanda = open(ws + "/domanda.txt", encoding="utf-8").read().rstrip("\n")
voci = [json.loads(r) for r in open(log, encoding="utf-8")]
chiamate = [v for v in voci if v["argv"][:1] == ["-p"]]
opzioni, pulito, fuori, cartelle = [], [], [], set()
if len(chiamate) != 6:
    opzioni.append("%d chiamate" % len(chiamate))
for numero, voce in enumerate(chiamate):
    ramo, argv = ("con", "senza")[numero % 2], voce["argv"]
    trovate, prompt, mcp, i = set(), None, "", 1
    while i < len(argv):
        if argv[i] == "--":
            prompt = argv[i + 1]
            break
        if argv[i] in VALORE:
            if argv[i] == "--mcp-config":
                mcp = argv[i + 1]
            else:
                trovate.add("%s=%s" % (argv[i], argv[i + 1]))
            i += 2
        else:
            trovate.add(argv[i])
            i += 1
    if trovate != ATTESE or prompt != domanda or voce["chiave"]:
        opzioni.append("chiamata %d: %s" % (numero + 1,
                                            sorted(trovate ^ ATTESE)))
    elenco = set(voce["elenco"] or ["?"])
    if not elenco <= PULITO or voce["cartella"] != os.path.basename(ws):
        pulito.append("chiamata %d vede %s" % (numero + 1, sorted(elenco)))
    if not (os.path.isabs(mcp) and mcp.endswith("/mcp/%s.json" % ramo)):
        fuori.append("chiamata %d: --mcp-config %s" % (numero + 1, mcp))
    cartelle.add(os.path.dirname(os.path.dirname(mcp)))
if len(cartelle) != 1:
    fuori.append("cartelle %s" % sorted(cartelle))
for cartella in cartelle:
    if cartella.startswith(ws + "/") or os.path.exists(cartella):
        fuori.append("%s dentro lo spazio di lavoro o ancora lì" % cartella)
attese = sorted("%s-%d.jsonl" % (r, n) for n in (1, 2, 3)
                for r in ("con", "senza"))
consegna = []
if not all(os.path.isfile(ws + "/mcp/%s.json" % r) for r in ("con", "senza")):
    consegna.append("mcp/ incompleta")
if not os.path.isdir(ws + "/risposte") \
        or sorted(os.listdir(ws + "/risposte")) != attese:
    consegna.append("risposte/ diversa")
print("opzioni: " + ("; ".join(opzioni)
                     or "sei chiamate in ordine, con --tools Read"))
print("pulito: " + ("; ".join(pulito)
                    or "soltanto domanda.txt, .claude/ e .git"))
print("fuori: " + ("; ".join(fuori) or "una cartella temporanea fuori "
                   "dallo spazio di lavoro, tolta"))
print("consegna: " + ("; ".join(consegna)
                      or "mcp/ e le sei risposte nello spazio di lavoro"))
PY
}

# Il claude finto: sei chiamate, le configurazioni, il README.
t_live_finto() {
  local w r
  ws w
  finto "${w}"
  expect "live: le sei chiamate finte, uscita 0" 0 "VERIFICA OK"
  r="$(grep -cF "«${S249}» (con, 1): confermata" <<< "${OUT}")"
  if (( r == 1 )); then
    pass "live: i verdetti si vedono, una volta sola"
  else
    fail "live: il verdetto di con, 1 si vede ${r} volte"
  fi
  analisi "${TMP}/finto.log" "${w}"
  expect "live: sei chiamate, con e senza, stesse opzioni, nessuna chiave" 0 \
    "opzioni: sei chiamate in ordine, con --tools Read"
  expect "live: durante ogni chiamata lo spazio di lavoro è pulito" 0 \
    "pulito: soltanto domanda.txt, .claude/ e .git"
  expect "live: le configurazioni fuori dallo spazio di lavoro, poi tolte" 0 \
    "fuori: una cartella temporanea fuori dallo spazio di lavoro, tolta"
  expect "live: dopo l'ultima chiamata mcp/ e risposte/ nello spazio" 0 \
    "consegna: mcp/ e le sei risposte nello spazio di lavoro"
  if grep -qF "sync --locked --offline --quiet --directory" "${TMP}/uv.log"
  then
    pass "live: uv sync --locked --offline prima delle chiamate"
  else
    fail "live: uv sync non è stato chiamato così: $(cat "${TMP}/uv.log")"
  fi
  t_live_configurazioni "${w}"
}

# Le due configurazioni del docente e il comando del README.
# Arguments: $1 lo spazio di lavoro di live.sh.
t_live_configurazioni() {
  local riga
  run python3 -B -I - "$1" "${SERVER}" "${DATI}" <<'PY'
import json, sys
ws, server, dati = sys.argv[1:4]
con = json.load(open(ws + "/mcp/con.json", encoding="utf-8"))
senza = json.load(open(ws + "/mcp/senza.json", encoding="utf-8"))
attesa = {"type": "stdio", "command": "uv",
          "args": ["run", "--frozen", "--directory", server,
                   "server_copertura.py"],
          "env": {"COPERTURA_DATI": dati}}
ok = con == {"mcpServers": {"copertura": attesa}} and \
    senza == {"mcpServers": {}}
print("configurazioni assolute" if ok else "diverse: %r %r" % (con, senza))
PY
  expect "live: le due configurazioni, con i percorsi assoluti" 0 \
    "configurazioni assolute"
  riga="$(grep -m 1 -E '^ +claude mcp add copertura ' "${D02}/README.md")"
  : > "${TMP}/finto.log"
  ( cd "$1" && S="${SERVER}" D="${DATI}" PATH="${TMP}/finto:${PATH}" \
      FINTO_LOG="${TMP}/finto.log" bash -c "${riga}" ) > /dev/null 2>&1
  run python3 -B -I - "${TMP}/finto.log" "$1" <<'PY'
import json, sys
argv = json.loads(open(sys.argv[1], encoding="utf-8").readline())["argv"]
dichiarato = json.load(open(sys.argv[2] + "/mcp/con.json",
                            encoding="utf-8"))["mcpServers"]["copertura"]
taglio = argv.index("--")
attese = (["mcp", "add", "copertura", "-e", "COPERTURA_DATI="
           + dichiarato["env"]["COPERTURA_DATI"]]
          == argv[:taglio]
          and argv[taglio + 1:] == [dichiarato["command"]]
          + dichiarato["args"])
print("README coerente" if attese else "diverso: %r" % argv)
PY
  expect "README: claude mcp add dichiara lo stesso server del docente" 0 \
    "README coerente"
}

# Il claude finto: la prima chiamata fallita, il server non collegato, una
# modalità di permesso vietata.
t_live_esiti() {
  local w r
  ws w
  finto "${w}" FINTO_ESITO=ko
  r="$(chiamate "${TMP}/finto.log" | grep -c .)"
  if (( RC == 1 && r == 1 )) && grep -qF 'VERIFICA KO' <<< "${OUT}" \
      && [[ -f "${w}/mcp/con.json" && -f "${w}/risposte/con-1.jsonl" ]]; then
    pass "live: si ferma alla prima chiamata fallita, e copia ciò che c'è"
  else
    fail "live: rc=${RC} dopo ${r} chiamate: ${OUT:0:300}"
  fi
  ws w
  finto "${w}" FINTO_STATO=failed
  expect "live: il server non collegato, uscita 1" 1 \
    "il server copertura non si è collegato"
  ws w
  finto "${w}" HANDSON_PERMISSION_MODE=bypassPermissions
  r="$(chiamate "${TMP}/finto.log" | grep -c .)"
  if (( RC == 2 && r == 0 )) \
      && grep -qF 'modalità di permesso non ammessa' <<< "${OUT}"; then
    pass "live: bypassPermissions rifiutata prima di chiamare il modello"
  else
    fail "live: bypassPermissions, rc=${RC}, chiamate ${r}"
  fi
}

# --- Il README ----------------------------------------------------------

t_readme() {
  run python3 -B -I - "${D02}/README.md" <<'PY'
import re, sys
testo = open(sys.argv[1], encoding="utf-8").read()
piatto = " ".join(testo.split())
attese = [
    ("MCP servers give Claude Code access to your tools, databases, and "
     "APIs.", "https://code.claude.com/docs/en/mcp"),
    ("Start the session with --strict-mcp-config. Claude Code then uses "
     "only the MCP servers you pass with --mcp-config.",
     "https://code.claude.com/docs/en/mcp"),
    ("MCP tools follow the naming pattern mcp__<server>__<tool>",
     "https://code.claude.com/docs/en/hooks"),
    ("--env accepts multiple KEY=value pairs. If the server name comes "
     "directly after --env, the CLI reads the name as another pair and "
     "rejects it", "https://code.claude.com/docs/en/mcp"),
    ("Relative file paths in command or args are a frequent cause … they "
     "resolve against the directory you launched Claude Code from",
     "https://code.claude.com/docs/en/debug-your-config"),
    ("Local scope is the default. A local-scoped server loads only in the "
     "project where you added it and stays private to you.",
     "https://code.claude.com/docs/en/mcp"),
    ("The flag doesn’t affect MCP tools; to deny those too, use "
     "--disallowedTools \"mcp__*\".",
     "https://code.claude.com/docs/en/cli-reference"),
    ("By default, Claude has access to files in the directory where you "
     "launched it.", "https://code.claude.com/docs/en/permissions"),
    ("If you set dontAsk mode, Claude Code auto-denies every tool call that "
     "would otherwise prompt you",
     "https://code.claude.com/docs/en/permission-modes"),
]
problemi = []
for frase, url in attese:
    if frase not in piatto:
        problemi.append("manca «%s»" % frase[:40])
    if url not in testo:
        problemi.append("manca %s" % url)
if not re.search(r"claude mcp add copertura -e COPERTURA_DATI=\"\$D\" -- "
                 r"uv run --frozen --directory \"\$S\" server_copertura\.py",
                 testo):
    problemi.append("il comando di aggiunta, con uv run --frozen")
if "Run without updating the `uv.lock` file" not in piatto:
    problemi.append("perché --frozen")
if "claude mcp remove copertura" not in testo:
    problemi.append("il comando di rimozione")
if not re.search(r"uv sync --frozen --directory [^\n]*/server\n", testo) \
        or "scarica FastMCP" not in piatto:
    problemi.append("uv sync --frozen che scarica FastMCP")
for segno in ("--tools Read", "cartella temporanea"):
    if segno not in piatto:
        problemi.append("perché soltanto Read e le risposte alla fine")
for sigla in ("FACT-", "M4-X", "sessione principale", "P1 "):
    if sigla in testo:
        problemi.append("sigla interna %s" % sigla)
print("; ".join(problemi) or "README in ordine")
PY
  expect "README: le frasi, i comandi, --frozen, Read, nessuna sigla" 0 \
    "README in ordine"
  run python3 -B -I - "${D02}/README.md" <<'PY'
import re, sys
testo = open(sys.argv[1], encoding="utf-8").read()

def sezione(titolo):
    return testo.split("## " + titolo, 1)[-1].split("\n## ", 1)[0]

problemi = []
# I bracci di una coppia: «braccio», mai «ramo» (che è di git).
if re.search(r"\b[Rr]am[oi]\b", testo):
    problemi.append("«ramo» per un braccio")
# I passi nell'ordine del deck: la preparazione e il passo 1 durante la
# demo, poi la prova, dalla cartella esercitazioni.
passi = sezione("Passi in Claude Code")
segni = ["tools/prepara_esercizio.sh M4-D02", "uv sync --frozen",
         'S="$PWD/', "cd ~/corso-claude-code/M4-D02", "claude mcp add"]
posti = [passi.find(s) for s in segni]
if -1 in posti or posti != sorted(posti):
    problemi.append("i passi non sono nell'ordine del deck")
elif "mentre la demo" not in " ".join(passi[:posti[1]].split()):
    problemi.append("la preparazione e il passo 1 non sono durante la demo")
tempo = " ".join(sezione("Tempo").split())
for atteso in ("3 per la demo del docente", "2 per la vostra prova",
               "continua da solo, con questo README"):
    if atteso not in tempo:
        problemi.append("«Tempo»: manca «%s»" % atteso)
# La prima prova del docente non è una registrazione: la ragione del
# disegno sì, i suoi numeri no.
for vecchio in ("In una prima prova del docente", "2 volte su 3"):
    if vecchio in testo:
        problemi.append("dalla prima prova: «%s»" % vecchio)
print("; ".join(problemi) or "passi come il deck")
PY
  expect "README: bracci, i passi e «Tempo» come il deck" 0 \
    "passi come il deck"
}

# Gli script di M4-D02, la sua libreria e questo file, con shellcheck -x.
t_shellcheck() {
  local f
  for f in "${D02}/verifica.sh" "${D02}/_docente/live.sh" \
      "${D02}/_docente/lib_mcp.sh" "${SELF}"; do
    if shellcheck -x "${f}" > /dev/null 2>&1; then
      pass "shellcheck ${f#"${RADICE}"/}"
    else
      fail "shellcheck ${f#"${RADICE}"/}"
    fi
  done
}

# La guardia: un claude dietro a ogni PATH di prova, che registra ogni
# invocazione in ${TMP}/guardia.log ed esce 99. Un caso che non mette
# davanti il finto o l'esca arriva qui, e mai al claude vero.
# Globals: PATH (vi aggiunge la guardia, davanti al PATH ereditato).
prepara_guardia() {
  mkdir -p "${TMP}/guardia" || exit 2
  # shellcheck disable=SC2016  # il corpo è della guardia
  printf '%s\n' '#!/bin/bash' \
    'printf "%s\n" "$*" >> "${0%/*}/../guardia.log"' 'exit 99' \
    > "${TMP}/guardia/claude" || exit 2
  chmod 755 "${TMP}/guardia/claude" || exit 2
  PATH="${TMP}/guardia:${PATH}"
  export PATH
}

# Mai il claude vero: nessun caso è arrivato alla guardia.
t_guardia() {
  local n=0
  if [[ -s "${TMP}/guardia.log" ]]; then
    n="$(grep -c . "${TMP}/guardia.log")"
  fi
  if (( n == 0 )); then
    pass "mai il claude vero: nessun caso è arrivato oltre i finti"
  else
    fail "${n} invocazioni oltre i finti: $(head -n 3 "${TMP}/guardia.log")"
  fi
}

main() {
  local t
  for t in python3 git shellcheck uv; do
    command -v "${t}" >/dev/null 2>&1 \
      || { echo "test_m4_d02: manca ${t}" >&2; exit 2; }
  done
  [[ -d "${D02}" && -f "${FINTO_PY}" && -d "${DATI}" ]] \
    || { echo "test_m4_d02: manca ${D02}, ${FINTO_PY} o ${DATI}" >&2; exit 2; }
  handson::init_temp_base
  TMP="$(mktemp -d "${HANDSON_TEMP_BASE}/test_m4_d02.XXXXXX")" || exit 2
  trap 'chmod -R u+rwX "${TMP}" 2>/dev/null; rm -rf "${TMP}"' EXIT
  prepara_finti
  prepara_guardia
  prepara_ambiente
  scrivi_dialogo
  t_elemento
  t_prepara
  t_progetto
  t_server
  t_lettura
  t_coppie
  t_stream
  t_risposta
  t_verifica
  t_live_precondizioni
  t_live_finto
  t_live_esiti
  t_readme
  t_shellcheck
  t_guardia
  OUT="${TUTTO}"
  expect_absent "in nessuna uscita «smentita»" "smentita"
  echo "PASS=${PASS} FAIL=${FAIL} SKIP=${SKIP}"
  if (( PASS + FAIL + SKIP != CASES )); then
    echo "test_m4_d02: girati $((PASS + FAIL + SKIP)) casi, attesi" \
      "${CASES}" >&2
    exit 2
  fi
  (( FAIL == 0 )) || exit 1
}

main "$@"
