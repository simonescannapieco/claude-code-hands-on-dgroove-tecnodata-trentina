#!/bin/bash
#
# test_m3_d02.sh -- le prove di M3-D02 «Quando Claude cerca sul web», per
# il docente (sta in _docente/, il materiale del docente):
#   - le due domande: stabile.md è quella fissata; attuale.md chiede
#     l'ultima versione nel changelog; tutte e due finiscono con «Rispondi
#     in due frasi» e nessuna dice a Claude di cercare;
#     prepara_esercizio.sh le porta nello spazio di lavoro, e verifica.sh
#     vi esce 1;
#   - conta_ricerche.py su stream finti scritti qui: le chiamate a
#     WebSearch, le sole che sono ricerche, contate una volta per id (e
#     ogni volta senza id); gli altri strumenti, WebFetch compreso, a parte
#     e come dati, con gli indirizzi aperti; le ricerche, gli indirizzi
#     citati (senza la punteggiatura in fondo e senza doppioni), la
#     versione come dato (anche «v2.1.306», mai un indirizzo IP), i
#     dinieghi, l'inizio della risposta; ogni verdetto con il suo perché
#     (anche il solo WebFetch sulla domanda attuale, che non conferma), i
#     riepiloghi «n su 3», mai «smentita»; esiti.tsv; gli stream rovinati
#     (manca, vuoto, una riga non JSON o non oggetto, senza il risultato in
#     fondo, soltanto il risultato, is_error, un subtype d'errore, senza
#     result) con l'uscita 1 e senza traceback; risposte/ che manca (1, un
#     esiti.tsv vecchio tolto); --senza-esiti; le precondizioni con
#     l'uscita 2 (argomenti, spazio di lavoro, un file che non si legge,
#     esiti.tsv che non si scrive, un errore inatteso);
#   - verifica.sh: spazio di lavoro assente (2), punto di partenza (1),
#     stream completi (0, la frase finale, nessun esiti.tsv scritto), una
#     chiamata che manca con un esiti.tsv falso (1), python3 che manca (2),
#     un controllo che esce 3 o per un segnale (2);
#   - _docente/live.sh: le precondizioni escono 2 senza chiamare claude
#     (l'esca); con il claude finto (claude_finto_m3_demo.py) le sei
#     chiamate con i testi e le opzioni del passo 3 del README (il suo
#     blocco gira con lo stesso finto, e le chiamate si confrontano), il
#     solo WebSearch (--tools e --allowedTools, mai WebFetch), lo
#     stream-json con --verbose, senza ANTHROPIC_API_KEY, i dati e il
#     verdetto a schermo una volta sola; la prima chiamata fallita (si
#     ferma lì); stream finti che cambiano il verdetto senza far fallire
#     (anche un WebFetch al posto della ricerca);
#     uno stream troncato (1); i controlli della libreria che live.sh
#     riusa: una modalità di permesso vietata e una chiave API nel prompt
#     (2, nessuna chiamata al modello);
#   - shellcheck -x su verifica.sh, live.sh e questo file.
# Mai il claude vero: il finto e l'esca stanno davanti nel PATH, e la
# suite lo controlla prima di usarli. Gli stream finti non sono risposte
# di Claude: provano il controllo, non il modello. Gli spazi di lavoro
# nascono in una cartella temporanea, nella base di handson::init_temp_base
# (mai dentro ~/.claude, anche se TMPDIR punta lì): l'albero del
# repository non cambia. CASES è il numero dei casi: se ne girano di più o
# di meno la suite esce 2 (un caso saltato conta come girato).
#
# Uso:    m3_funzionalita_claude/_docente/test_m3_d02.sh
# Uscita: 0 = tutti i casi passano · 1 = almeno un caso fallito · 2 =
#         precondizione (manca python3, git o shellcheck, o la cartella
#         dell'elemento), o un numero di casi diverso da CASES
set -uo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly MOD="${SELF%/_docente/*}"
readonly RADICE="${MOD%/*}"
D02="${MOD}/s2_funzionalita_claude/m3_4_ricerca_codice_file"
D02+="/M3-D02_quando_cerca_sul_web"
readonly D02
readonly FINTO_PY="${MOD}/_docente/claude_finto_m3_demo.py"
# La libreria del repository, per la base dei file temporanei
# (handson::init_temp_base): mai dentro ~/.claude, dove prepara_esercizio.sh
# rifiuta gli spazi di lavoro, anche se TMPDIR punta lì.
# shellcheck source=../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"
readonly CASES=104
readonly NA='—'
FINE='Fatto: ogni affermazione è stata messa alla prova;'
FINE+=' gli esiti sono qui sopra.'
readonly FINE
readonly PARTENZA='Manca la cartella risposte/: eseguite i passi del README.'
readonly URL_F='https://changelog.example.org/claude-code'
readonly ATTUALE="Risposta finta: la versione 9.9.9. Fonte: ${URL_F}."
readonly STABILE='Risposta finta, prima frase. Seconda frase finta.'
readonly S_RIC="Cerca per l'attuale, non per lo stabile"
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

# Un nuovo spazio di lavoro: una copia di demo/.
# Arguments: $1 la variabile da assegnare.
ws() {
  local __w
  __w="$(mktemp -d "${TMP}/ws.XXXXXX")" || { echo "mktemp" >&2; exit 2; }
  cp -R "${D02}/demo/." "${__w}/" || exit 2
  printf -v "$1" '%s' "${__w}"
}

# Scrive in risposte/ lo stream-json finto di una chiamata: l'evento
# iniziale, un messaggio dell'assistente per strumento, la risposta, il
# risultato. Arguments: $1 lo spazio di lavoro, $2 il file, $3 la
# risposta, poi gli strumenti chiamati: «Nome», «Nome@id» (lo stesso id
# due volte è lo stesso blocco ripetuto), «Nome@-» (senza id); e le
# varianti: «+tronco» (senza il risultato), «+solo» (soltanto il
# risultato), «+errore» (is_error), «+subtype» (un subtype d'errore),
# «+senza_result», «+diniego» (un diniego in permission_denials).
stream() {
  python3 -B -I - "$@" <<'PY'
import json, os, sys
ws, nome, testo = sys.argv[1:4]
voci = sys.argv[4:]
ingressi = {"WebSearch": {"query": "ricerca finta"},
            "WebFetch": {"url": "https://changelog.example.org/claude-code",
                         "prompt": "domanda finta"}}
eventi = [{"type": "system", "subtype": "init", "session_id": "finta"}]
for numero, voce in enumerate(v for v in voci if not v.startswith("+")):
    strumento, _, ident = voce.partition("@")
    blocco = {"type": "tool_use", "name": strumento,
              "input": ingressi.get(strumento, {})}
    if ident != "-":
        blocco["id"] = ident or "toolu_finto_%d" % numero
    eventi.append({"type": "assistant", "message": {"content": [blocco]}})
    eventi.append({"type": "user", "message": {"content": [{
        "type": "tool_result", "tool_use_id": blocco.get("id", ""),
        "content": "finto"}]}})
eventi.append({"type": "assistant", "message": {"content": [
    {"type": "text", "text": testo}]}})
risultato = {"type": "result", "subtype": "success", "is_error": False,
             "result": testo, "num_turns": 2, "permission_denials": []}
if "+errore" in voci:
    risultato["is_error"] = True
if "+subtype" in voci:
    risultato["subtype"] = "error_during_execution"
if "+senza_result" in voci:
    del risultato["result"]
if "+diniego" in voci:
    risultato["permission_denials"] = [{"tool_name": "WebFetch"}]
if "+solo" in voci:
    eventi = []
if "+tronco" not in voci:
    eventi.append(risultato)
os.makedirs(os.path.join(ws, "risposte"), exist_ok=True)
with open(os.path.join(ws, "risposte", nome), "w", encoding="utf-8") as fh:
    for evento in eventi:
        fh.write(json.dumps(evento, ensure_ascii=False) + "\n")
PY
}

# I sei stream finti di un'esecuzione che conferma: la domanda attuale con
# una ricerca (WebSearch), la stabile senza strumenti. Arguments: $1 lo
# spazio di lavoro.
complete() {
  local n
  for n in 1 2 3; do
    stream "$1" "attuale-${n}.jsonl" "${ATTUALE}" WebSearch
    stream "$1" "stabile-${n}.jsonl" "${STABILE}"
  done
}

# conta_ricerche.py nello spazio di lavoro $1, con gli argomenti che
# seguono; RC e OUT come run.
controlla() {
  local w="$1"
  shift
  OUT="$(cd "${w}" && python3 -B -I conta_ricerche.py "$@" 2>&1)"
  RC=$?
  TUTTO+="${OUT}"$'\n'
}

# Uno spazio di lavoro con gli stream completi, uno cambiato (gli
# argomenti di stream dopo lo spazio di lavoro), poi il controllo con
# --senza-esiti. Arguments: $1 la variabile da assegnare, poi gli
# argomenti di stream.
con() {
  local __c __v="$1"
  shift
  ws __c
  complete "${__c}"
  if (( $# > 0 )); then
    stream "${__c}" "$@"
  fi
  controlla "${__c}" --senza-esiti
  printf -v "${__v}" '%s' "${__c}"
}

# Il ramo dell'errore inatteso: main() del controllo di demo/ con un
# controlla() che solleva un'eccezione. Arguments: gli argomenti di main.
inatteso() {
  run python3 -B -I -c 'import importlib.util, sys
spec = importlib.util.spec_from_file_location("controllo", sys.argv[1])
modulo = importlib.util.module_from_spec(spec)
spec.loader.exec_module(modulo)
def guasto(*_):
    raise RuntimeError("guasto finto")
modulo.controlla = guasto
sys.exit(modulo.main(sys.argv[2:]))' "${D02}/demo/conta_ricerche.py" "$@"
}

# Una copia di verifica.sh e di demo/ in cui il controllo è finto: esce
# con il codice dato, o si fa terminare da un segnale.
# Arguments: $1 la variabile da assegnare (la copia), $2 il codice
# d'uscita, oppure «segnale».
albero_finto() {
  local __a __c
  __a="$(mktemp -d "${TMP}/albero.XXXXXX")" || { echo "mktemp" >&2; exit 2; }
  if ! cp -- "${D02}/verifica.sh" "${__a}/" || ! cp -R "${D02}/demo" "${__a}/"
  then
    echo "test_m3_d02: non riesco a copiare l'elemento" >&2
    exit 2
  fi
  __c="${__a}/demo/conta_ricerche.py"
  if [[ "$2" == segnale ]]; then
    printf '%s\n' 'import os, signal' 'os.kill(os.getpid(), signal.SIGTERM)' \
      > "${__c}"
  else
    printf 'import sys\nsys.exit(%d)\n' "$2" > "${__c}"
  fi
  printf -v "$1" '%s' "${__a}"
}

# L'esca in ${TMP}/esca (registra ogni invocazione ed esce 0); il claude
# finto in ${TMP}/finto; ${TMP}/senza_python, un PATH con readlink e
# l'esca; ${TMP}/senza_claude, uno con readlink e python3. Esce 2 se nel
# PATH di prova il claude trovato non è il finto.
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
  for t in readlink python3; do
    ln -s "$(command -v "${t}")" "${TMP}/senza_claude/${t}" || exit 2
  done
  t="$(PATH="${TMP}/finto:${PATH}" command -v claude)"
  if [[ "${t}" != "${TMP}/finto/claude" ]]; then
    echo "test_m3_d02: nel PATH di prova claude è ${t}, non il finto" >&2
    exit 2
  fi
}

# live.sh con l'esca davanti nel PATH (o con un PATH dato); il registro
# delle invocazioni riparte vuoto. Arguments: $1 lo spazio di lavoro, $2
# facoltativo il PATH.
esca() {
  : > "${TMP}/esca.log"
  run env PATH="${2:-${TMP}/esca:${PATH}}" HANDSON_NO_PAUSE=1 \
    ESCA_LOG="${TMP}/esca.log" "${D02}/_docente/live.sh" "$1"
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
    "${D02}/_docente/live.sh" "${w}"
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

# Il blocco di codice del passo 3 del README, senza il rientro, in un
# file. Arguments: $1 il file. Returns: 0; 1 se il blocco non c'è.
blocco_readme() {
  python3 -B -I - "${D02}/README.md" "$1" <<'PY'
import re, sys
readme, uscita = sys.argv[1:3]
dentro, blocco = False, []
for riga in open(readme, encoding="utf-8").read().splitlines():
    if re.match(r"\d+\. ", riga) or riga.startswith("## "):
        dentro = riga.startswith("3. ")
        continue
    if dentro and riga.startswith(" " * 7):
        blocco.append(riga[7:])
if not any("claude -p" in r for r in blocco):
    sys.exit(1)
with open(uscita, "w", encoding="utf-8") as fh:
    fh.write("\n".join(blocco) + "\n")
PY
}

# --- Le due domande e lo spazio di lavoro ---------------------------------

t_domande() {
  local a s
  a="$(cat "${D02}/demo/attuale.md")"
  s="$(cat "${D02}/demo/stabile.md")"
  if [[ "${s}" == "Che cos'è la fibra FTTH? Rispondi in due frasi." ]]; then
    pass "domande: stabile.md è la domanda fissata"
  else
    fail "domande: stabile.md è «${s}»"
  fi
  if [[ "${a}" == *"Claude Code"* && "${a}" == *changelog* \
      && "${a}" == *"Rispondi in due frasi"* ]]; then
    pass "domande: attuale.md chiede la versione nel changelog, in due frasi"
  else
    fail "domande: attuale.md è «${a}»"
  fi
  if grep -qiE 'cerca|web|search|internet|online|sito' <<< "${a}${s}"; then
    fail "domande: una delle due dice a Claude di cercare"
  else
    pass "domande: nessuna delle due dice a Claude di cercare"
  fi
}

# prepara_esercizio.sh porta demo/ nello spazio di lavoro, e lì
# verifica.sh esce 1: il punto di partenza chiede le chiamate.
t_prepara() {
  local r="${TMP}/radice"
  run "${RADICE}/tools/prepara_esercizio.sh" M3-D02 --radice "${r}"
  expect "prepara: lo spazio di lavoro nasce" 0 "Spazio di lavoro pronto"
  if [[ -f "${r}/M3-D02/attuale.md" && -f "${r}/M3-D02/conta_ricerche.py" \
      && ! -e "${r}/M3-D02/soluzione" && ! -e "${r}/M3-D02/_docente" ]]
  then
    pass "prepara: le domande e il controllo, niente altro"
  else
    fail "prepara: lo spazio di lavoro non è demo/"
  fi
  run "${RADICE}/tools/verifica.sh" M3-D02 --radice "${r}"
  expect "prepara: sul punto di partenza la verifica esce 1" 1 "${PARTENZA}"
}

# --- conta_ricerche.py ----------------------------------------------------

# Gli stream completi: l'uscita, i dati, il verdetto, esiti.tsv.
t_complete() {
  local w riga attesa
  ws w
  complete "${w}"
  controlla "${w}"
  expect "controlla: stream completi, uscita 0" 0 "Scritto esiti.tsv."
  expect "controlla: i dati della domanda attuale" 0 \
    "attuale, 1: WebSearch 1; cercato: «ricerca finta»; citati: ${URL_F}; \
versione nella risposta: 9.9.9"
  expect "controlla: i dati della domanda stabile" 0 \
    "stabile, 2: WebSearch 0; citati: nessuno"
  expect "controlla: l'inizio della risposta" 0 "  risposta: «${STABILE}»"
  expect "controlla: il verdetto di una coppia" 0 \
    "${S_RIC} (coppia 3): confermata"
  expect "controlla: il riepilogo" 0 "${S_RIC}: confermata 3 su 3"
  expect_absent "controlla: senza la frase finale, che è della verifica" \
    "Fatto:"
  if (( $(wc -l < "${w}/esiti.tsv") == 7 )); then
    pass "controlla: sei righe e l'intestazione in esiti.tsv"
  else
    fail "controlla: $(wc -l < "${w}/esiti.tsv") righe in esiti.tsv"
  fi
  riga="$(awk -F'\t' '$1 == "attuale-2.jsonl" { $NF = ""; print }' \
    "${w}/esiti.tsv")"
  attesa="attuale-2.jsonl attuale 2 1 ${NA} ricerca finta ${NA} ${URL_F}"
  attesa+=" 9.9.9 0 "
  if [[ "${riga}" == "${attesa}" ]]; then
    pass "controlla: la riga di esiti.tsv della domanda attuale"
  else
    fail "controlla: riga «${riga}»"
  fi
}

# I conteggi e i dati: una ricerca e una pagina, id ripetuti, senza id,
# altri strumenti, ricerche, indirizzi, versioni, dinieghi, risposte
# lunghe.
t_conteggi() {
  local w lunga
  con w attuale-1.jsonl "${ATTUALE}" WebSearch WebFetch
  expect "conteggi: una ricerca, e la pagina aperta come dato" 0 \
    "attuale, 1: WebSearch 1; cercato: «ricerca finta»; altri strumenti, \
non ricerche: WebFetch 1; aperti: ${URL_F}"
  expect "conteggi: con una ricerca, la pagina in più non cambia niente" 0 \
    "${S_RIC} (coppia 1): confermata"
  con w attuale-1.jsonl "${ATTUALE}" WebSearch@toolu_x WebSearch@toolu_x
  expect "conteggi: lo stesso id due volte conta una volta" 0 \
    "attuale, 1: WebSearch 1;"
  con w attuale-1.jsonl "${ATTUALE}" WebSearch@- WebSearch@-
  expect "conteggi: senza id, ogni blocco conta" 0 \
    "attuale, 1: WebSearch 2;"
  con w stabile-1.jsonl "${STABILE}" Read
  expect "conteggi: un altro strumento si conta a parte" 0 \
    "stabile, 1: WebSearch 0; altri strumenti, non ricerche: Read 1"
  expect "conteggi: e non è una ricerca" 0 "${S_RIC} (coppia 1): confermata"
  con w attuale-2.jsonl "${ATTUALE}" WebSearch +diniego
  expect "conteggi: i dinieghi dei permessi, come dato" 0 \
    "dinieghi dei permessi: 1"
  con w attuale-2.jsonl \
    "La versione è la v2.1.306 (https://a.example.org/x, \
https://a.example.org/x)." \
    WebSearch
  expect "conteggi: la versione con la v, gli indirizzi senza doppioni" 0 \
    "citati: https://a.example.org/x; versione nella risposta: 2.1.306"
  con w attuale-3.jsonl "Il server 203.0.113.5 non dice la versione." \
    WebSearch
  expect "conteggi: un indirizzo IP non è una versione" 0 \
    "versione nella risposta: nessuna"
  lunga="$(printf 'parola %.0s' {1..80})"
  con w stabile-3.jsonl "${lunga}"
  if grep -qE '^  risposta: «(parola ){42}parol…»$' <<< "${OUT}"; then
    pass "conteggi: la risposta tagliata a 300 caratteri"
  else
    fail "conteggi: la risposta lunga non è tagliata a 300 caratteri"
  fi
}

# I verdetti, con il loro perché: decide soltanto WebSearch.
t_verdetti() {
  local w
  con w attuale-1.jsonl "${ATTUALE}"
  expect "verdetti: la domanda attuale senza ricerche" 0 \
    "${S_RIC} (coppia 1): ${NONCONF} (la domanda attuale senza WebSearch)"
  expect "verdetti: il riepilogo, 2 su 3" 0 "${S_RIC}: confermata 2 su 3"
  con w attuale-1.jsonl "${ATTUALE}" WebFetch
  expect "verdetti: il solo WebFetch sull'attuale non conferma" 0 \
    "${S_RIC} (coppia 1): ${NONCONF} (la domanda attuale senza WebSearch)"
  expect "verdetti: e WebFetch si stampa come dato" 0 \
    "attuale, 1: WebSearch 0; altri strumenti, non ricerche: WebFetch 1; \
aperti: ${URL_F}"
  con w attuale-2.jsonl "${ATTUALE}" WebSearch
  expect "verdetti: una ricerca sull'attuale conferma" 0 \
    "${S_RIC} (coppia 2): confermata"
  con w stabile-2.jsonl "${STABILE}" WebSearch WebSearch
  expect "verdetti: la domanda stabile con due ricerche" 0 \
    "${S_RIC} (coppia 2): ${NONCONF} (la domanda stabile con 2 chiamate a \
WebSearch)"
  con w stabile-3.jsonl "${STABILE}" WebFetch
  expect "verdetti: un WebFetch sulla stabile non è una ricerca" 0 \
    "${S_RIC} (coppia 3): confermata"
  con w attuale-3.jsonl "${ATTUALE}" Read
  expect "verdetti: un altro strumento non è una ricerca" 0 \
    "${S_RIC} (coppia 3): ${NONCONF} (la domanda attuale senza WebSearch)"
  ws w
  complete "${w}"
  stream "${w}" attuale-1.jsonl "${ATTUALE}"
  stream "${w}" stabile-1.jsonl "${STABILE}" WebSearch
  controlla "${w}" --senza-esiti
  expect "verdetti: i due perché insieme" 0 \
    "(la domanda attuale senza WebSearch; la domanda stabile con 1 chiamata \
a WebSearch)"
}

# Gli stream rovinati: uscita 1, il motivo, nessun traceback.
t_rovinati() {
  local w
  ws w
  complete "${w}"
  rm "${w}/risposte/stabile-2.jsonl"
  controlla "${w}"
  expect "rovinati: una chiamata che manca, uscita 1" 1 \
    "manca risposte/stabile-2.jsonl: rifate quella chiamata"
  expect "rovinati: il messaggio «Non ancora»" 1 "Non ancora:"
  expect_absent "rovinati: senza la stabile, nessun verdetto della coppia" \
    "(coppia 2)"
  expect "rovinati: il riepilogo conta le coppie che ci sono" 1 \
    "${S_RIC}: confermata 2 su 2"
  if (( $(wc -l < "${w}/esiti.tsv") == 6 )); then
    pass "rovinati: esiti.tsv con le cinque chiamate che ci sono"
  else
    fail "rovinati: $(wc -l < "${w}/esiti.tsv") righe in esiti.tsv"
  fi
  : > "${w}/risposte/stabile-2.jsonl"
  controlla "${w}"
  expect "rovinati: uno stream vuoto" 1 "stabile-2.jsonl è vuoto"
  printf '{"type": "system"}\n{rotto\n' > "${w}/risposte/stabile-2.jsonl"
  controlla "${w}"
  expect "rovinati: una riga che non è JSON" 1 \
    "stabile-2.jsonl, riga 2: non è un evento dello stream-json"
  printf '[1, 2]\n' > "${w}/risposte/stabile-2.jsonl"
  controlla "${w}"
  expect "rovinati: una riga che non è un oggetto" 1 \
    "stabile-2.jsonl, riga 1: non è un evento dello stream-json"
  stream "${w}" stabile-2.jsonl "${STABILE}" +tronco
  controlla "${w}"
  expect "rovinati: senza il risultato in fondo" 1 \
    "lo stream non finisce con il risultato"
  stream "${w}" stabile-2.jsonl "${STABILE}" +solo
  controlla "${w}"
  expect "rovinati: soltanto il risultato" 1 \
    "c'è soltanto il risultato, senza gli eventi"
  stream "${w}" stabile-2.jsonl "${STABILE}" +errore
  controlla "${w}"
  expect "rovinati: is_error" 1 "claude ha restituito un errore"
  stream "${w}" stabile-2.jsonl "${STABILE}" +subtype
  controlla "${w}"
  expect "rovinati: un subtype d'errore" 1 "claude ha restituito un errore"
  stream "${w}" stabile-2.jsonl "${STABILE}" +senza_result
  controlla "${w}"
  expect "rovinati: senza result" 1 "manca la risposta («result»)"
  expect_absent "rovinati: mai un traceback" "Traceback"
}

# risposte/ che manca, --senza-esiti, le precondizioni.
t_precondizioni() {
  local w
  ws w
  printf 'vecchio\n' > "${w}/esiti.tsv"
  controlla "${w}"
  expect "partenza: risposte/ che manca, uscita 1" 1 "${PARTENZA}"
  if [[ ! -e "${w}/esiti.tsv" ]]; then
    pass "partenza: il vecchio esiti.tsv è tolto"
  else
    fail "partenza: il vecchio esiti.tsv resta"
  fi
  printf 'vecchio\n' > "${w}/esiti.tsv"
  controlla "${w}" --senza-esiti
  if (( RC == 1 )) && [[ "$(cat "${w}/esiti.tsv")" == vecchio ]]; then
    pass "partenza: --senza-esiti esce 1 e non toglie esiti.tsv"
  else
    fail "partenza: --senza-esiti, rc=${RC}"
  fi
  rm -f "${w}/esiti.tsv"
  complete "${w}"
  controlla "${w}" --senza-esiti
  if (( RC == 0 )) && [[ ! -e "${w}/esiti.tsv" ]]; then
    pass "--senza-esiti: uscita 0 e nessun esiti.tsv"
  else
    fail "--senza-esiti: rc=${RC}"
  fi
  run python3 -B -I "${D02}/demo/conta_ricerche.py" --tutto "${w}"
  expect "precondizione: un'opzione sconosciuta, uscita 2" 2 \
    "opzione sconosciuta: --tutto"
  run python3 -B -I "${D02}/demo/conta_ricerche.py" "${w}" "${w}"
  expect "precondizione: due spazi di lavoro" 2 \
    "uno spazio di lavoro per volta"
  run python3 -B -I "${D02}/demo/conta_ricerche.py" "${TMP}/assente"
  expect "precondizione: spazio di lavoro assente" 2 \
    "spazio di lavoro assente"
  mkdir "${w}/esiti.tsv"
  controlla "${w}"
  expect "precondizione: esiti.tsv che non si scrive" 2 \
    "esiti.tsv non si scrive"
  rmdir "${w}/esiti.tsv"
  inatteso --senza-esiti "${w}"
  expect "precondizione: un errore inatteso, uscita 2" 2 \
    "errore inatteso (RuntimeError: guasto finto)"
  expect_absent "precondizione: l'errore inatteso senza traceback" \
    "Traceback"
  if (( EUID == 0 )); then
    skip "precondizione: uno stream che non si legge (da root si legge)"
    return 0
  fi
  chmod 000 "${w}/risposte/attuale-3.jsonl"
  controlla "${w}"
  expect "precondizione: uno stream che non si legge" 2 \
    "risposte/attuale-3.jsonl non si legge"
  chmod 644 "${w}/risposte/attuale-3.jsonl"
}

# --- verifica.sh ----------------------------------------------------------

t_verifica() {
  local w a
  run "${D02}/verifica.sh"
  expect "verifica: senza spazio di lavoro, uscita 2" 2 \
    "spazio di lavoro assente"
  ws w
  run "${D02}/verifica.sh" "${w}"
  expect "verifica: il punto di partenza, uscita 1" 1 "${PARTENZA}"
  complete "${w}"
  run "${D02}/verifica.sh" "${w}"
  expect "verifica: stream completi, uscita 0" 0 "${FINE}"
  if [[ "${OUT##*$'\n'}" == "${FINE}" ]]; then
    pass "verifica: la frase finale è l'ultima riga"
  else
    fail "verifica: l'ultima riga è «${OUT##*$'\n'}»"
  fi
  expect "verifica: il riepilogo" 0 "${S_RIC}: confermata 3 su 3"
  if [[ ! -e "${w}/esiti.tsv" ]]; then
    pass "verifica: non scrive esiti.tsv"
  else
    fail "verifica: ha scritto esiti.tsv"
  fi
  stream "${w}" attuale-1.jsonl "${ATTUALE}"
  run "${D02}/verifica.sh" "${w}"
  expect "verifica: un verdetto non confermato non fa fallire" 0 \
    "${S_RIC}: confermata 2 su 3"
  rm "${w}/risposte/attuale-1.jsonl"
  printf 'file\nfinto\n' > "${w}/esiti.tsv"
  run "${D02}/verifica.sh" "${w}"
  expect "verifica: una chiamata che manca, con un esiti.tsv falso" 1 \
    "manca risposte/attuale-1.jsonl"
  expect_absent "verifica: una chiamata che manca, nessuna frase finale" \
    "Fatto:"
  run env PATH="${TMP}/senza_python" "${D02}/verifica.sh" "${w}"
  expect "verifica: python3 che manca, uscita 2" 2 "manca python3"
  albero_finto a 3
  run "${a}/verifica.sh" "${w}"
  expect "verifica: un controllo che esce con 3, uscita 2" 2 \
    "conta_ricerche.py è uscito con 3"
  albero_finto a segnale
  run "${a}/verifica.sh" "${w}"
  expect "verifica: un controllo terminato da un segnale, uscita 2" 2 \
    "conta_ricerche.py è uscito con 143"
}

# --- _docente/live.sh -----------------------------------------------------

# Le precondizioni escono 2 prima di ogni invocazione di claude.
t_live_precondizioni() {
  local w f
  precondizione "live: spazio di lavoro assente" "spazio di lavoro assente" \
    "${TMP}/assente"
  for f in attuale.md stabile.md conta_ricerche.py; do
    ws w
    rm "${w}/${f}"
    precondizione "live: ${f} che manca" "file assente o illeggibile: ${f}" \
      "${w}"
  done
  ws w
  precondizione "live: python3 che manca" "manca lo strumento: python3" \
    "${w}" "${TMP}/senza_python"
  ws w
  esca "${w}" "${TMP}/senza_claude"
  expect "live: claude che manca" 2 "manca lo strumento: claude"
}

# Il claude finto: le sei chiamate, i testi e le opzioni del README.
t_live_finto() {
  local w w2 r
  ws w
  finto "${w}"
  expect "live: gli stream finti, uscita 0" 0 "VERIFICA OK"
  expect "live: i dati e il verdetto si vedono anche quando passa" 0 \
    "${FINE}"
  expect "live: il riepilogo" 0 "${S_RIC}: confermata 3 su 3"
  expect "live: la riga di claude si vede prima di girare" 0 \
    "--output-format stream-json"
  r="$(grep -cF 'attuale, 1: WebSearch 1;' <<< "${OUT}")"
  if (( r == 1 )); then
    pass "live: i dati si vedono una volta sola"
  else
    fail "live: i dati di attuale, 1 si vedono ${r} volte"
  fi
  r="$(chiamate "${TMP}/finto.log")"
  if [[ "${r}" == "6 0" ]]; then
    pass "live: sei chiamate, nessuna con ANTHROPIC_API_KEY"
  else
    fail "live: chiamate e chiavi «${r}», attese «6 0»"
  fi
  run python3 -B -I - "${TMP}/finto.log" <<'PY'
import json, sys
chiamate = [json.loads(r)["argv"] for r in open(sys.argv[1], encoding="utf-8")]
chiamate = [c for c in chiamate if c[:1] != ["--version"]]
def valore(c, opzione):
    return c[c.index(opzione) + 1] if opzione in c else None
buone = [c for c in chiamate if valore(c, "--tools") == "WebSearch"
         and valore(c, "--allowedTools") == "WebSearch"
         and not any("WebFetch" in a for a in c[:c.index("--")])]
print("solo WebSearch in %d chiamate su %d" % (len(buone), len(chiamate)))
PY
  expect "live: --tools WebSearch e --allowedTools WebSearch, mai WebFetch" 0 \
    "solo WebSearch in 6 chiamate su 6"
  r="$(command find "${w}/risposte" -name '*.jsonl' | wc -l)"
  if (( r == 6 )) && (( $(wc -l < "${w}/esiti.tsv") == 7 )); then
    pass "live: sei file in risposte/ e sei righe in esiti.tsv"
  else
    fail "live: ${r} file in risposte/"
  fi
  cp "${TMP}/finto.log" "${TMP}/live.log"
  ws w2
  if ! blocco_readme "${TMP}/passo3.sh"; then
    fail "README: il blocco del passo 3 non c'è"
    return 0
  fi
  : > "${TMP}/readme.log"
  ( cd "${w2}" && PATH="${TMP}/finto:${PATH}" \
      FINTO_LOG="${TMP}/readme.log" bash "${TMP}/passo3.sh" )
  run python3 -B -I - "${w}" "${w2}" "${TMP}/live.log" "${TMP}/readme.log" \
    <<'PY'
import json, os, sys
ws, ws2, log_live, log_readme = sys.argv[1:5]
VALORE = {"--model", "--effort", "--tools", "--allowedTools",
          "--output-format", "--setting-sources", "--permission-mode",
          "--permission-prompts"}

def chiamate(log):
    righe = [json.loads(r)["argv"] for r in open(log, encoding="utf-8")]
    return [c for c in righe if c[:1] != ["--version"]]

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

def leggi(nome):
    with open(os.path.join(ws, nome), encoding="utf-8") as fh:
        return fh.read().rstrip("\n")

attese = [leggi(q + ".md") for n in (1, 2, 3)
          for q in ("attuale", "stabile")]
live, readme = chiamate(log_live), chiamate(log_readme)
problemi = []
if len(live) != 6 or len(readme) != 6:
    problemi.append("chiamate: live.sh %d, README %d" % (len(live),
                                                        len(readme)))
fisse = (("--model", "sonnet"), ("--tools", "WebSearch"),
         ("--allowedTools", "WebSearch"), ("--effort", "low"),
         ("--output-format", "stream-json"),
         ("--setting-sources", "project,local"),
         ("--permission-mode", "dontAsk"), ("--permission-prompts", "none"))
for i, (cl, cr, testo) in enumerate(zip(live, readme, attese)):
    pl, ol = analizza(cl)
    pr, orr = analizza(cr)
    if pl != testo or pr != testo:
        problemi.append("chiamata %d: il prompt" % (i + 1))
    for chiave, valore in list(orr.items()) + list(fisse):
        if ol.get(chiave) != valore:
            problemi.append("chiamata %d: %s" % (i + 1, chiave))
    for chiave in ("-p", "--verbose", "--strict-mcp-config",
                   "--no-session-persistence"):
        if ol.get(chiave) is not True:
            problemi.append("chiamata %d: %s" % (i + 1, chiave))
    if "--" not in cl:
        problemi.append("chiamata %d: il prompt non è dopo «--»" % (i + 1))
if sorted(os.listdir(os.path.join(ws, "risposte"))) \
        != sorted(os.listdir(os.path.join(ws2, "risposte"))):
    problemi.append("i file di risposte/ sono diversi")
print("; ".join(problemi) or "stesse chiamate")
PY
  expect "live e README: stessi testi, stesse opzioni, stessi file" 0 \
    "stesse chiamate"
}

# Il claude finto: la prima chiamata fallita, stream che cambiano il
# verdetto, uno stream troncato, i controlli della libreria.
t_live_esiti() {
  local w r chiave
  ws w
  finto "${w}" FINTO_ESITO=ko
  r="$(chiamate "${TMP}/finto.log")"
  if (( RC == 1 )) && [[ "${r}" == "1 0" ]] \
      && grep -qF 'VERIFICA KO' <<< "${OUT}"; then
    pass "live: si ferma alla prima chiamata fallita"
  else
    fail "live: rc=${RC} dopo le chiamate «${r}»: ${OUT:0:300}"
  fi
  ws w
  finto "${w}" FINTO_STRUMENTI_STABILE=WebSearch
  expect "live: la stabile che cerca, uscita 0" 0 \
    "${S_RIC}: confermata 0 su 3"
  ws w
  finto "${w}" FINTO_STRUMENTI_ATTUALE=
  expect "live: l'attuale che non cerca, uscita 0" 0 \
    "(la domanda attuale senza WebSearch)"
  ws w
  finto "${w}" FINTO_STRUMENTI_ATTUALE=WebFetch
  expect "live: l'attuale con il solo WebFetch, non confermata" 0 \
    "${S_RIC} (coppia 1): ${NONCONF} (la domanda attuale senza WebSearch)"
  expect "live: e WebFetch si stampa come dato" 0 \
    "altri strumenti, non ricerche: WebFetch 1"
  ws w
  finto "${w}" FINTO_TRONCO=1
  expect "live: uno stream troncato, uscita 1" 1 \
    "lo stream non finisce con il risultato"
  ws w
  finto "${w}" HANDSON_PERMISSION_MODE=bypassPermissions
  r="$(chiamate "${TMP}/finto.log")"
  if (( RC == 2 )) && [[ "${r}" == "0 0" ]] \
      && grep -qF 'modalità di permesso non ammessa' <<< "${OUT}"; then
    pass "live: bypassPermissions rifiutata prima di chiamare il modello"
  else
    fail "live: bypassPermissions, rc=${RC}, chiamate «${r}»"
  fi
  ws w
  chiave="sk-ant""-finta"
  printf 'Qual è la versione? %s\n' "${chiave}" > "${w}/attuale.md"
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

# Gli script di M3-D02 e questo file, con shellcheck -x.
t_shellcheck() {
  local f
  for f in "${D02}/verifica.sh" "${D02}/_docente/live.sh" "${SELF}"; do
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
      || { echo "test_m3_d02: manca ${t}" >&2; exit 2; }
  done
  [[ -d "${D02}" && -f "${FINTO_PY}" ]] \
    || { echo "test_m3_d02: manca ${D02} o ${FINTO_PY}" >&2; exit 2; }
  handson::init_temp_base
  TMP="$(mktemp -d "${HANDSON_TEMP_BASE}/test_m3_d02.XXXXXX")" || exit 2
  trap 'chmod -R u+rwX "${TMP}" 2>/dev/null; rm -rf "${TMP}"' EXIT
  prepara_claude
  t_domande
  t_prepara
  t_complete
  t_conteggi
  t_verdetti
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
    echo "test_m3_d02: girati $((PASS + FAIL + SKIP)) casi, attesi" \
      "${CASES}" >&2
    exit 2
  fi
  (( FAIL == 0 )) || exit 1
}

main "$@"
