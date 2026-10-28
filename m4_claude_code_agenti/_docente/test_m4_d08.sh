#!/bin/bash
#
# test_m4_d08.sh -- le prove di M4-D08 «Il log in una pipe», per il docente
# (sta in _docente/, il materiale del docente):
#   - l'elemento: i suoi file, verifica.sh e _docente/live.sh eseguibili,
#     il README con le dieci sezioni, progetti.txt con progetti/rete, la
#     domanda; la verità di controlla_pipe.py (10:12 e 11:40) è quella di
#     progetti/rete/_docente/README.md e del syslog di olt-pergine-01;
#     prepara_esercizio.sh porta la rete senza _docente/ e senza il
#     controllo, e verifica.sh vi esce 1;
#   - il controllo, su esecuzioni finte scritte qui: la garanzia
#     confermata con il messaggio su STDERR o in un JSON d'errore su
#     STDOUT (0); il braccio grande che riesce, o esce senza messaggio (1,
#     «non confermata in questa esecuzione»); il braccio grande che non
#     supera i 10 MB, il braccio filtrato che fallisce (1, e il tetto non
#     distinguibile), un file che manca o
#     non va (1); gli orari della risposta in più forme, giusti o
#     sbagliati, come dati (0); un file che non si legge, argomenti
#     sbagliati, un errore inatteso (2, senza traceback);
#   - verifica.sh: spazio di lavoro assente (2), punto di partenza (1),
#     confermata (0, la frase finale per ultima), non confermata (1),
#     python3 che manca (2), un controllo che esce 3 o per un segnale (2);
#   - _docente/live.sh: le precondizioni escono 2 senza chiamare claude;
#     con il claude finto i due bracci con lo stesso comando (le stesse
#     opzioni e la stessa domanda; nessuno strumento) e due ingressi, le
#     righe di olt-pergine-01 e il file grande oltre i 12 MiB, senza
#     ANTHROPIC_API_KEY; i file di pipe/; il comando a schermo; il blocco
#     del README dà le stesse invocazioni e gli stessi ingressi; un finto
#     senza tetto (1), un braccio filtrato che fallisce (1, il tetto non
#     distinguibile), una modalità di permesso vietata (2, nessuna
#     chiamata);
#   - il README: le frasi di Anthropic parola per parola con il loro
#     indirizzo, nessuna sigla interna; «braccio filtrato», «braccio
#     grande», mai «ramo»;
#   - shellcheck -x su verifica.sh, live.sh, lib_pipe.sh (che non è
#     eseguibile: si carica con source) e questo file.
# Mai il claude vero: il finto e l'esca stanno davanti nel PATH. Le
# esecuzioni finte non sono risposte di Claude: provano il controllo, non
# il modello. Gli spazi di lavoro nascono in una cartella temporanea:
# l'albero del repository non cambia. CASES è il numero dei casi: se ne
# girano di più o di meno la suite esce 2 (un caso saltato conta come
# girato).
#
# Uso:    m4_claude_code_agenti/_docente/test_m4_d08.sh
# Uscita: 0 = tutti i casi passano · 1 = almeno un caso fallito · 2 =
#         precondizione (manca python3, git o shellcheck, o la cartella
#         dell'elemento), o un numero di casi diverso da CASES
set -uo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly MOD="${SELF%/_docente/*}"
readonly RADICE="${MOD%/*}"
D08="${MOD}/s3_agente_nel_repository/m4_11_oltre_il_codice"
D08+="/M4-D08_log_in_una_pipe"
readonly D08
readonly FINTO_PY="${MOD}/_docente/claude_finto_m4_d01_d02_d08.py"
readonly CONTROLLO="${D08}/controlla_pipe.py"
# shellcheck source=../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"
readonly CASES=71
FINE='Fatto: ogni affermazione è stata messa alla prova;'
FINE+=' gli esiti sono qui sopra.'
readonly FINE
readonly PARTENZA='Manca la cartella pipe/: eseguite i passi del README.'
readonly NONCONF='non confermata in questa esecuzione'
readonly VERDETTO='Lo stdin in pipe ha un tetto di 10 MB'
# Le righe di olt-pergine-01 nel syslog della settimana, in byte, e il
# file grande della prova: oltre 12 MiB.
readonly GRANDE=$((12 * 1024 * 1024 + 1))
OK_FILTRATO='{"type": "result", "subtype": "success", "is_error": false,'
OK_FILTRATO+=' "result": "inizio 10:12 | fine 11:40", "num_turns": 1,'
OK_FILTRATO+=' "usage": {"input_tokens": 3, "cache_creation_input_tokens":'
OK_FILTRATO+=' 4000, "cache_read_input_tokens": 0, "output_tokens": 12}}'
readonly OK_FILTRATO
readonly ERRORE='Error: finto: stdin oltre il tetto'
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

# Un nuovo spazio di lavoro: una copia di demo/ e di progetti/rete senza
# _docente/, come lo prepara prepara_esercizio.sh.
# Arguments: $1 la variabile da assegnare.
ws() {
  local __w
  __w="$(mktemp -d "${TMP}/ws.XXXXXX")" || { echo "mktemp" >&2; exit 2; }
  mkdir -p "${__w}/progetti" || exit 2
  cp -R "${RADICE}/progetti/rete" "${__w}/progetti/" || exit 2
  rm -rf "${__w}/progetti/rete/_docente"
  cp -R "${D08}/demo/." "${__w}/" || exit 2
  printf -v "$1" '%s' "${__w}"
}

# Un braccio finto in pipe/. Arguments: $1 lo spazio di lavoro, $2 il braccio,
# $3 l'uscita, $4 i byte, $5 lo STDOUT, $6 lo STDERR ("-" = quel file non
# c'è, per $3…$6).
braccio() {
  local base="$1/pipe/$2"
  mkdir -p "$1/pipe" || exit 2
  if [[ "$3" != "-" ]]; then printf '%s\n' "$3" > "${base}.uscita"; fi
  if [[ "$4" != "-" ]]; then printf '%s\n' "$4" > "${base}.byte"; fi
  if [[ "$5" != "-" ]]; then printf '%s' "$5" > "${base}.out"; fi
  if [[ "$6" != "-" ]]; then printf '%s' "$6" > "${base}.err"; fi
}

# I due bracci di un'esecuzione riuscita: il filtrato con gli orari giusti,
# il grande fermato con un errore su STDERR. Arguments: $1 lo spazio.
buoni() {
  braccio "$1" filtrato 0 13564 "${OK_FILTRATO}" ''
  braccio "$1" grande 1 "${GRANDE}" '' "${ERRORE}"
}

# Il JSON del braccio filtrato con la risposta data. Arguments: $1 il testo.
filtrato_con() {
  python3 -B -I -c 'import json, sys
print(json.dumps({"type": "result", "subtype": "success", "is_error": False,
                  "result": sys.argv[1], "num_turns": 1}))' "$1"
}

# Il controllo come lo lancia verifica.sh; RC e OUT.
controlla() { run python3 -B -I "${CONTROLLO}" "$@"; }

# Il caso dell'errore inatteso: main() del controllo con un controlla() che
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

# Una copia di verifica.sh con un controlla_pipe.py finto accanto: esce
# con il codice dato, o si fa terminare da un segnale.
# Arguments: $1 la variabile da assegnare, $2 il codice o «segnale».
albero_finto() {
  local __a __c
  __a="$(mktemp -d "${TMP}/albero.XXXXXX")" || { echo "mktemp" >&2; exit 2; }
  cp -- "${D08}/verifica.sh" "${__a}/" || exit 2
  __c="${__a}/controlla_pipe.py"
  if [[ "$2" == segnale ]]; then
    printf '%s\n' 'import os, signal' 'os.kill(os.getpid(), signal.SIGTERM)' \
      > "${__c}"
  else
    printf 'import sys\nsys.exit(%d)\n' "$2" > "${__c}"
  fi
  printf -v "$1" '%s' "${__a}"
}

# L'esca, il claude finto e i PATH senza python3 o senza claude, come nelle
# suite del Modulo 3. Esce 2 se il claude del PATH di prova non è il finto.
prepara_claude() {
  local t
  mkdir -p "${TMP}/esca" "${TMP}/finto" "${TMP}/senza_python" \
    "${TMP}/senza_claude" "${TMP}/solo_readlink" || exit 2
  # shellcheck disable=SC2016  # il corpo è dell'esca
  printf '%s\n' '#!/bin/bash' \
    'printf "invocazione %s\n" "$*" >> "${ESCA_LOG}"' \
    > "${TMP}/esca/claude" || exit 2
  cp -- "${FINTO_PY}" "${TMP}/finto/claude_finto.py" || exit 2
  # shellcheck disable=SC2016  # il corpo è dell'involucro
  printf '%s\n' '#!/bin/bash' \
    'exec python3 "${0%/*}/claude_finto.py" "$@"' \
    > "${TMP}/finto/claude" || exit 2
  chmod 755 "${TMP}/esca/claude" "${TMP}/finto/claude" || exit 2
  ln -s "${TMP}/esca/claude" "${TMP}/senza_python/claude" || exit 2
  ln -s "$(command -v readlink)" "${TMP}/senza_python/readlink" || exit 2
  ln -s "$(command -v readlink)" "${TMP}/solo_readlink/readlink" || exit 2
  for t in readlink python3 grep cat wc mkdir; do
    ln -s "$(command -v "${t}")" "${TMP}/senza_claude/${t}" || exit 2
  done
  t="$(PATH="${TMP}/finto:${PATH}" command -v claude)"
  if [[ "${t}" != "${TMP}/finto/claude" ]]; then
    echo "test_m4_d08: nel PATH di prova claude è ${t}, non il finto" >&2
    exit 2
  fi
}

# live.sh con l'esca davanti nel PATH (o con un PATH dato).
# Arguments: $1 lo spazio di lavoro, $2 facoltativo il PATH.
esca() {
  : > "${TMP}/esca.log"
  run env PATH="${2:-${TMP}/esca:${PATH}}" HANDSON_NO_PAUSE=1 \
    ESCA_LOG="${TMP}/esca.log" "${D08}/_docente/live.sh" "$1"
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

# live.sh con il claude finto e una ANTHROPIC_API_KEY nell'ambiente, che
# live.sh deve togliere. Arguments: $1 lo spazio, poi NOME=valore.
finto() {
  local w="$1"
  shift
  : > "${TMP}/finto.log"
  run env PATH="${TMP}/finto:${PATH}" HANDSON_NO_PAUSE=1 \
    ANTHROPIC_API_KEY=valore-reale-finto FINTO_LOG="${TMP}/finto.log" "$@" \
    "${D08}/_docente/live.sh" "${w}"
}

# Le chiamate -p del registro, una per riga: la chiave, i byte dello STDIN,
# le opzioni in ordine alfabetico (con --setting-sources,
# --permission-mode e --permission-prompts solo se $2 è «tutte») e il
# prompt. Arguments: $1 il registro, $2 «tutte» o «readme».
chiamate() {
  python3 -B -I - "$1" "$2" <<'PY'
import json, sys
VALORE = {"--model", "--effort", "--tools", "--allowedTools",
          "--output-format", "--setting-sources", "--permission-mode",
          "--permission-prompts"}
SOLO_LIVE = {"--setting-sources", "--permission-mode", "--permission-prompts"}
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
            coppia = "%s=%s" % (argv[i], argv[i + 1])
            i += 2
        else:
            coppia = argv[i]
            i += 1
        if sys.argv[2] == "tutte" or coppia.split("=")[0] not in SOLO_LIVE:
            opzioni.append(coppia)
    print("%s | %s | %s | %s" % (voce["chiave"], voce["stdin"],
                                 " ".join(sorted(opzioni)), prompt))
PY
}

# I blocchi di codice del README che contengono le parole date, senza il
# rientro, uno dopo l'altro nel file $1. Returns: 1 se uno non c'è.
blocchi_readme() {
  python3 -B -I - "${D08}/README.md" "$@" <<'PY'
import sys
readme, uscita = sys.argv[1:3]
blocchi, attuale = [], []
for riga in open(readme, encoding="utf-8").read().splitlines():
    if riga.startswith(" " * 7):
        attuale.append(riga[7:])
    elif riga.strip() == "" and attuale:
        attuale.append("")
    elif attuale:
        blocchi.append(attuale)
        attuale = []
if attuale:
    blocchi.append(attuale)
testo = []
for segno in sys.argv[3:]:
    scelti = [b for b in blocchi if any(segno in r for r in b)]
    if len(scelti) != 1:
        sys.exit(1)
    testo += scelti[0]
with open(uscita, "w", encoding="utf-8") as fh:
    fh.write("\n".join(testo).strip("\n") + "\n")
PY
}

# --- L'elemento e la verità -----------------------------------------------

t_elemento() {
  local f mancanti='' sezione pat ap="'" alt="(’|')"
  for f in README.md progetti.txt demo/domanda.txt controlla_pipe.py \
      verifica.sh _docente/live.sh _docente/lib_pipe.sh \
      soluzione/LEGGIMI.md; do
    [[ -f "${D08}/${f}" ]] || mancanti+=" ${f}"
  done
  if [[ -z "${mancanti}" ]]; then
    pass "elemento: i suoi file ci sono"
  else
    fail "elemento: mancano${mancanti}"
  fi
  if [[ -x "${D08}/verifica.sh" && -x "${D08}/_docente/live.sh" \
      && ! -x "${D08}/_docente/lib_pipe.sh" ]]; then
    pass "elemento: verifica.sh e live.sh eseguibili, lib_pipe.sh no"
  else
    fail "elemento: il bit di esecuzione di verifica.sh, live.sh o" \
      "lib_pipe.sh non va"
  fi
  mancanti=''
  for sezione in "${HANDSON_README_SECTIONS[@]}"; do
    pat="${sezione//${ap}/${alt}}"
    grep -Eq -- "^##[[:space:]]+${pat}([^[:alnum:]_]|\$)" \
      "${D08}/README.md" 2>/dev/null || mancanti+=" «${sezione}»"
  done
  if [[ -z "${mancanti}" ]]; then
    pass "README: le dieci sezioni"
  else
    fail "README: mancano${mancanti}"
  fi
  if [[ "$(cat "${D08}/progetti.txt" 2>/dev/null)" == "progetti/rete" ]]; then
    pass "elemento: progetti.txt porta progetti/rete"
  else
    fail "elemento: progetti.txt non è «progetti/rete»"
  fi
  run cat "${D08}/demo/domanda.txt"
  if (( RC == 0 )) && grep -qF 'olt-pergine-01' <<< "${OUT}" \
      && grep -qF 'martedì 8 settembre' <<< "${OUT}" \
      && grep -qF "'inizio HH:MM | fine HH:MM'" <<< "${OUT}"; then
    pass "elemento: la domanda nomina l'apparato, il giorno e la forma"
  else
    fail "elemento: la domanda non va: ${OUT:0:200}"
  fi
}

# La verità del controllo contro il README del docente e il syslog.
t_verita() {
  run python3 -B -I - "${CONTROLLO}" "${RADICE}/progetti/rete" <<'PY'
import importlib.util, re, sys
spec = importlib.util.spec_from_file_location("controllo", sys.argv[1])
modulo = importlib.util.module_from_spec(spec)
spec.loader.exec_module(modulo)
rete = sys.argv[2]
readme = open(rete + "/_docente/README.md", encoding="utf-8").read()
voce = re.search(r"Martedì 8, (\d\d:\d\d)–(\d\d:\d\d) — fibra tagliata"
                 r"[^\n]*`olt-pergine-01`", readme)
syslog = open(rete + "/log/syslog/syslog_2026-09-08.log",
              encoding="utf-8").read()
los = re.search(r"T(\d\d:\d\d):\d\d\+02:00 olt-pergine-01 %%GPON/2/PON_LOS:",
                syslog)
clear = re.search(r"T(\d\d:\d\d):\d\d\+02:00 olt-pergine-01 "
                  r"%%GPON/5/PON_LOS_CLEAR:", syslog)
verita = (modulo.INIZIO, modulo.FINE)
if voce and los and clear and verita == voce.groups() \
        == (los.group(1), clear.group(1)):
    print("la verità del controllo è quella del README e del syslog")
else:
    print("diverse: %s %s %s %s" % (verita, voce and voce.groups(),
                                   los and los.group(1),
                                   clear and clear.group(1)))
PY
  expect "verità: 10:12 e 11:40, dal README del docente e dal syslog" 0 \
    "la verità del controllo è quella del README e del syslog"
}

# prepara_esercizio.sh e tools/verifica.sh sul punto di partenza.
t_prepara() {
  local radice w n
  radice="$(mktemp -d "${TMP}/radice.XXXXXX")" || exit 2
  run "${RADICE}/tools/prepara_esercizio.sh" M4-D08 --radice "${radice}"
  w="${radice}/M4-D08"
  n="$(command find "${w}/progetti/rete/log/syslog" -name 'syslog_*.log' \
    2>/dev/null | wc -l)"
  if (( RC == 0 && n == 7 )) && [[ -f "${w}/domanda.txt" \
      && ! -e "${w}/progetti/rete/_docente" \
      && ! -e "${w}/controlla_pipe.py" && ! -e "${w}/soluzione" ]]; then
    pass "prepara: la rete senza _docente/, la domanda, niente verità"
  else
    fail "prepara: rc=${RC}, syslog ${n}: ${OUT:0:300}"
  fi
  run "${RADICE}/tools/verifica.sh" M4-D08 --radice "${radice}"
  expect "prepara: sul punto di partenza la verifica esce 1" 1 "${PARTENZA}"
}

# --- Il controllo -------------------------------------------------------

t_controllo() {
  local w
  ws w
  controlla "${w}"
  expect "controllo: il punto di partenza, uscita 1" 1 "${PARTENZA}"
  buoni "${w}"
  controlla "${w}"
  expect "controllo: il tetto, confermata, uscita 0" 0 \
    "${VERDETTO}: oltre, Claude Code esce con un errore chiaro"
  expect "controllo: confermata" 0 "zero: confermata"
  expect "controllo: gli orari giusti, come dati" 0 \
    "inizio 10:12 (giusto) · fine 11:40 (giusto)"
  expect "controllo: i byte e l'uscita del braccio grande" 0 \
    "grande: ${GRANDE} byte in pipe; uscita 1"
  expect "controllo: il messaggio su STDERR, come dato" 0 \
    "messaggio su STDERR: «${ERRORE}»"
  expect "controllo: i token del braccio filtrato, come dato" 0 \
    "token in entrata 4003"
  ws w
  buoni "${w}"
  braccio "${w}" grande 0 "${GRANDE}" "${OK_FILTRATO}" ''
  controlla "${w}"
  expect "controllo: il braccio grande che riesce, uscita 1" 1 "${NONCONF}"
  ws w
  buoni "${w}"
  braccio "${w}" grande 1 "${GRANDE}" '' ''
  controlla "${w}"
  expect "controllo: il braccio grande senza messaggio, uscita 1" 1 "${NONCONF}"
  ws w
  buoni "${w}"
  braccio "${w}" grande 1 "${GRANDE}" '{"type": "result", "subtype":
 "error_during_execution", "is_error": true, "result": "Errore finto"}' ''
  controlla "${w}"
  expect "controllo: il messaggio in un JSON d'errore, uscita 0" 0 \
    "messaggio su STDOUT: «Errore finto»"
  t_controllo_bracci
  t_controllo_orari
  t_controllo_file
}

# I bracci che non mettono alla prova il tetto, o non riescono.
t_controllo_bracci() {
  local w
  ws w
  buoni "${w}"
  braccio "${w}" grande 1 10485760 '' "${ERRORE}"
  controlla "${w}"
  expect "controllo: il braccio grande che non supera i 10 MB, uscita 1" 1 \
    "non oltre i 10 MB"
  ws w
  buoni "${w}"
  braccio "${w}" filtrato 1 13564 '' 'Error: finto'
  controlla "${w}"
  expect "controllo: il braccio filtrato che fallisce, uscita 1" 1 \
    "il braccio filtrato non è riuscito (uscita 1)"
  # Con il filtrato fallito i due bracci non differiscono più soltanto
  # nell'ingresso: il tetto non si decide.
  expect "controllo: il filtrato fallito, il tetto non distinguibile" 1 \
    "${VERDETTO}: oltre, Claude Code esce con un errore chiaro e \
un'uscita diversa da zero: non distinguibile: il braccio filtrato non è \
riuscito"
  expect_absent "controllo: e il tetto non confermato" \
    "diversa da zero: confermata"
  ws w
  buoni "${w}"
  braccio "${w}" filtrato 0 13564 'non JSON' ''
  controlla "${w}"
  expect "controllo: il braccio filtrato senza JSON, uscita 1" 1 \
    "il braccio filtrato non è riuscito"
}

# Gli orari della risposta: dati, in più forme.
t_controllo_orari() {
  local w
  ws w
  buoni "${w}"
  braccio "${w}" filtrato 0 13564 \
    "$(filtrato_con '**Inizio:** 10.12 | **Fine:** 11.40')" ''
  controlla "${w}"
  expect "controllo: orari con il punto e il grassetto" 0 \
    "inizio 10:12 (giusto) · fine 11:40 (giusto)"
  braccio "${w}" filtrato 0 13564 \
    "$(filtrato_con 'Il guasto: inizio alle 10:13, fine alle 11:41.')" ''
  controlla "${w}"
  expect "controllo: orari sbagliati, come dati, uscita 0" 0 \
    "inizio 10:13 (sbagliato) · fine 11:41 (sbagliato)"
  braccio "${w}" filtrato 0 13564 "$(filtrato_con 'Non lo so.')" ''
  controlla "${w}"
  expect "controllo: una risposta senza orari, uscita 0" 0 \
    "inizio — · fine —"
  braccio "${w}" filtrato 0 13564 \
    "$(filtrato_con 'Infine: inizio 10:12 | fine 11:40')" ''
  controlla "${w}"
  expect "controllo: «Infine» non è la fine" 0 \
    "inizio 10:12 (giusto) · fine 11:40 (giusto)"
}

# I file che mancano o non vanno, e gli argomenti.
t_controllo_file() {
  local w
  ws w
  buoni "${w}"
  rm "${w}/pipe/grande.err"
  controlla "${w}"
  expect "controllo: un file che manca, uscita 1" 1 "manca pipe/grande.err"
  ws w
  buoni "${w}"
  braccio "${w}" grande uno "${GRANDE}" '' "${ERRORE}"
  controlla "${w}"
  expect "controllo: un'uscita che non è un numero, uscita 1" 1 \
    "pipe/grande.uscita"
  if (( $(id -u) == 0 )); then
    skip "controllo: un file che non si legge (root legge ovunque)"
  else
    ws w
    buoni "${w}"
    chmod 000 "${w}/pipe/grande.err"
    controlla "${w}"
    expect "controllo: un file che non si legge, uscita 2" 2 "non si legge"
    chmod 644 "${w}/pipe/grande.err"
  fi
  controlla --boh
  expect "controllo: un'opzione sconosciuta, uscita 2" 2 "Uso:"
  controlla "${w}" "${w}"
  expect "controllo: due spazi di lavoro, uscita 2" 2 "Uso:"
  controlla "${TMP}/assente"
  expect "controllo: spazio di lavoro assente, uscita 2" 2 \
    "spazio di lavoro assente"
  inatteso "${w}"
  expect "controllo: un errore inatteso, uscita 2" 2 "errore inatteso"
  expect_absent "controllo: un errore inatteso, nessun traceback" \
    "Traceback"
}

# --- verifica.sh --------------------------------------------------------

t_verifica() {
  local w a
  run "${D08}/verifica.sh"
  expect "verifica: senza spazio di lavoro, uscita 2" 2 \
    "spazio di lavoro assente"
  ws w
  run "${D08}/verifica.sh" "${w}"
  expect "verifica: il punto di partenza, uscita 1" 1 "${PARTENZA}"
  buoni "${w}"
  run "${D08}/verifica.sh" "${w}"
  expect "verifica: confermata, uscita 0" 0 "${FINE}"
  if [[ "${OUT##*$'\n'}" == "${FINE}" ]]; then
    pass "verifica: la frase finale è l'ultima riga"
  else
    fail "verifica: l'ultima riga è «${OUT##*$'\n'}»"
  fi
  braccio "${w}" grande 0 "${GRANDE}" "${OK_FILTRATO}" ''
  run "${D08}/verifica.sh" "${w}"
  expect "verifica: non confermata, uscita 1" 1 "${NONCONF}"
  expect_absent "verifica: non confermata, nessuna frase finale" "Fatto:"
  run env PATH="${TMP}/solo_readlink" "${D08}/verifica.sh" "${w}"
  expect "verifica: python3 che manca, uscita 2" 2 "manca python3"
  albero_finto a 3
  run "${a}/verifica.sh" "${w}"
  expect "verifica: un controllo che esce con 3, uscita 2" 2 \
    "controlla_pipe.py è uscito con 3"
  albero_finto a segnale
  run "${a}/verifica.sh" "${w}"
  expect "verifica: un controllo terminato da un segnale, uscita 2" 2 \
    "controlla_pipe.py è uscito con 143"
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
  rm -rf "${w}/progetti/rete/log/syslog"
  precondizione "live: il syslog che manca" "progetti/rete/log/syslog" "${w}"
  ws w
  precondizione "live: python3 che manca" "manca lo strumento: python3" \
    "${w}" "${TMP}/senza_python"
  ws w
  esca "${w}" "${TMP}/senza_claude"
  expect "live: claude che manca" 2 "manca lo strumento: claude"
}

# Il claude finto: due bracci, lo stesso comando, due ingressi.
t_live_finto() {
  local w w2 r filtrato
  ws w
  finto "${w}"
  expect "live: i due bracci finti, uscita 0" 0 "VERIFICA OK"
  expect "live: il verdetto si vede anche quando passa" 0 "zero: confermata"
  expect "live: la pipe si vede prima di girare" 0 \
    "cat olt-pergine-01.log | claude -p"
  filtrato="$(grep -h olt-pergine-01 \
    "${RADICE}"/progetti/rete/log/syslog/syslog_*.log | wc -c)"
  r="$(chiamate "${TMP}/finto.log" tutte)"
  run python3 -B -I - "${r}" "${filtrato}" "${w}" <<'PY'
import sys
righe = sys.argv[1].splitlines()
filtrato, ws = int(sys.argv[2]), sys.argv[3]
domanda = open(ws + "/domanda.txt", encoding="utf-8").read().rstrip("\n")
attese = ("--effort=low --model=sonnet --no-session-persistence "
          "--output-format=json --permission-mode=dontAsk "
          "--permission-prompts=none --setting-sources=project,local "
          "--strict-mcp-config --tools=")
problemi = []
if len(righe) != 2:
    problemi.append("%d chiamate" % len(righe))
else:
    for riga in righe:
        chiave, letti, opzioni, prompt = riga.split(" | ", 3)
        if chiave != "None":
            problemi.append("la chiave %s" % chiave)
        if opzioni != attese:
            problemi.append("opzioni %s" % opzioni)
        if prompt != domanda:
            problemi.append("il prompt")
    if int(righe[0].split(" | ")[1]) != filtrato:
        problemi.append("lo STDIN del braccio filtrato")
    if int(righe[1].split(" | ")[1]) <= 12 * 1024 * 1024:
        problemi.append("lo STDIN del braccio grande")
print("; ".join(problemi) or "due chiamate uguali, due ingressi")
PY
  expect "live: stesse opzioni, stessa domanda, nessuna chiave, due ingressi" \
    0 "due chiamate uguali, due ingressi"
  if [[ "$(cat "${w}/pipe/filtrato.uscita" 2>/dev/null)" == 0 \
      && "$(cat "${w}/pipe/grande.uscita" 2>/dev/null)" == 1 \
      && "$(cat "${w}/pipe/filtrato.byte" 2>/dev/null)" == "${filtrato}" \
      && -s "${w}/pipe/grande.err" ]]; then
    pass "live: i file di pipe/ con le uscite, i byte e il messaggio"
  else
    fail "live: i file di pipe/ non vanno"
  fi
  cp "${TMP}/finto.log" "${TMP}/live.log"
  ws w2
  # shellcheck disable=SC2016  # il segno è il testo del README, alla lettera
  if ! blocchi_readme "${TMP}/passi.sh" "grep -h olt-pergine-01" \
      'pipe/$r.uscita'; then
    fail "README: i blocchi dei passi 2 e 3 non ci sono"
    return 0
  fi
  : > "${TMP}/finto.log"
  ( cd "${w2}" && env -u ANTHROPIC_API_KEY PATH="${TMP}/finto:${PATH}" \
      FINTO_LOG="${TMP}/finto.log" bash "${TMP}/passi.sh" ) > /dev/null 2>&1
  if [[ "$(chiamate "${TMP}/live.log" readme)" \
      == "$(chiamate "${TMP}/finto.log" readme)" ]] \
      && cmp -s "${w}/olt-pergine-01.log" "${w2}/olt-pergine-01.log" \
      && cmp -s "${w}/grande.log" "${w2}/grande.log" \
      && cmp -s "${w}/pipe/grande.byte" "${w2}/pipe/grande.byte"; then
    pass "live e README: stesse chiamate, stessi ingressi"
  else
    fail "live e README: chiamate o ingressi diversi"
  fi
}

# Il claude finto: senza tetto, il braccio filtrato che fallisce, una
# modalità di permesso vietata.
t_live_esiti() {
  local w r
  ws w
  finto "${w}" FINTO_TETTO=0
  expect "live: un claude senza tetto, uscita 1" 1 "${NONCONF}"
  ws w
  finto "${w}" FINTO_ESITO=ko
  expect "live: il braccio filtrato che fallisce, uscita 1" 1 \
    "il braccio filtrato non è riuscito"
  expect "live: ogni chiamata fallita, il tetto non distinguibile" 1 \
    "diversa da zero: non distinguibile: il braccio filtrato non è riuscito"
  expect_absent "live: e il tetto non confermato" \
    "diversa da zero: confermata"
  ws w
  finto "${w}" HANDSON_PERMISSION_MODE=bypassPermissions
  r="$(chiamate "${TMP}/finto.log" tutte | grep -c .)"
  if (( RC == 2 && r == 0 )) \
      && grep -qF 'modalità di permesso non ammessa' <<< "${OUT}"; then
    pass "live: bypassPermissions rifiutata prima di chiamare il modello"
  else
    fail "live: bypassPermissions, rc=${RC}, chiamate ${r}"
  fi
}

# --- Il README ----------------------------------------------------------

t_readme() {
  run python3 -B -I - "${D08}/README.md" <<'PY'
import sys
testo = open(sys.argv[1], encoding="utf-8").read()
piatto = " ".join(testo.split())
attese = [
    "Non-interactive mode reads stdin, so you can pipe data in and redirect "
    "the response out like any other command-line tool.",
    "Piped stdin is capped at 10MB. If you exceed the cap, Claude Code exits "
    "with a clear error and a non-zero status.",
]
problemi = ["manca «%s»" % f[:40] for f in attese if f not in piatto]
if "https://code.claude.com/docs/en/headless" not in testo:
    problemi.append("manca l'indirizzo della pagina")
for sigla in ("FACT-", "M4-X", "sessione principale", "P1 "):
    if sigla in testo:
        problemi.append("sigla interna %s" % sigla)
print("; ".join(problemi) or "README in ordine")
PY
  expect "README: le frasi, l'indirizzo, nessuna sigla" 0 "README in ordine"
  run python3 -B -I - "${D08}/README.md" <<'PY'
import re, sys
testo = open(sys.argv[1], encoding="utf-8").read()
piatto = " ".join(testo.split())
problemi = []
for atteso in ("braccio filtrato", "braccio grande"):
    if atteso not in piatto:
        problemi.append("manca «%s»" % atteso)
if re.search(r"\b[Rr]am[oi]\b", testo):
    problemi.append("«ramo» per un braccio")
if "non distinguibile" not in piatto:
    problemi.append("il tetto non distinguibile se il filtrato non riesce")
print("; ".join(problemi) or "bracci in ordine")
PY
  expect "README: braccio filtrato e braccio grande, mai «ramo»" 0 \
    "bracci in ordine"
}

# Gli script di M4-D08, la sua libreria e questo file, con shellcheck -x.
t_shellcheck() {
  local f
  for f in "${D08}/verifica.sh" "${D08}/_docente/live.sh" \
      "${D08}/_docente/lib_pipe.sh" "${SELF}"; do
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
      || { echo "test_m4_d08: manca ${t}" >&2; exit 2; }
  done
  [[ -d "${D08}" && -f "${FINTO_PY}" ]] \
    || { echo "test_m4_d08: manca ${D08} o ${FINTO_PY}" >&2; exit 2; }
  handson::init_temp_base
  TMP="$(mktemp -d "${HANDSON_TEMP_BASE}/test_m4_d08.XXXXXX")" || exit 2
  trap 'chmod -R u+rwX "${TMP}" 2>/dev/null; rm -rf "${TMP}"' EXIT
  prepara_claude
  t_elemento
  t_verita
  t_prepara
  t_controllo
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
    echo "test_m4_d08: girati $((PASS + FAIL + SKIP)) casi, attesi" \
      "${CASES}" >&2
    exit 2
  fi
  (( FAIL == 0 )) || exit 1
}

main "$@"
