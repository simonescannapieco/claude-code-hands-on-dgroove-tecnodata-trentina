#!/bin/bash
#
# test_m1_d03.sh -- le prove di M1-D03, «Contare le lettere», per il
# docente (sta in _docente/, che resta fuori dalla copia senza soluzioni di
# tools/esporta_studenti.sh):
#   - il punto di partenza: i quattro testi, nessun file della versione
#     precedente, leggi_json.py identico a quello di M1-D02;
#   - controlla_pesi.py, attraverso verifica.sh e da solo, su conteggi.tsv
#     scritti qui: ogni esito delle tre affermazioni (confermata, non
#     confermata, non distinguibile) e i loro confini (16 token per 16
#     lettere; la compitata che pesa quanto la parola intera; un solo
#     modello che non torna); i token per lettera stampati come dato,
#     senza verdetto; le lettere contate dai testi dello spazio di lavoro
#     (anche accentate, con LC_ALL=C); le righe che non tornano
#     (intestazione, campi, modello, testo, conteggio vuoto, non numerico,
#     in apice o di 5000 cifre, doppio che non pesa più del singolo,
#     conteggi ripetuti diversi), CRLF, BOM e zeri davanti; le
#     precondizioni (spazio di lavoro, testo mancante o senza lettere, file
#     che non si legge, non UTF-8 o cartella, argomenti); mai un Traceback;
#   - le uscite che non sono un esito: un python3 finto che esce 3 o muore
#     di SIGTERM, e un errore che il controllo non prevede (os.path.isdir
#     che solleva), escono 2 con un messaggio, mai 1;
#   - il passo 3 del README, estratto ed eseguito con un claude finto che
#     risponde con JSON sintetici: ogni esito delle affermazioni, e un JSON
#     con errore, nessun JSON, un JSON senza usage, che lasciano un
#     conteggio vuoto; le sue chiamate sono quelle di live.sh, salvo le tre
#     opzioni che handson::claude_p aggiunge e che il README nomina;
#   - _docente/live.sh: con un'esca davanti nel PATH che registra ogni
#     chiamata, le precondizioni escono 2 e claude non riceve nessun prompt
#     (al più claude --version); con il claude finto, l'esito di ogni ramo,
#     le chiamate (testi, ordine, opzioni, modelli di PN_MODELLI), i numeri
#     e gli esiti a schermo anche su un OK, e una precondizione di
#     verifica.sh che diventa l'uscita 2;
#   - shellcheck -x su verifica.sh, live.sh e questo file.
# Gli spazi di lavoro nascono in una cartella temporanea: l'albero del
# repository non cambia; nessun modello viene chiamato. Il file supera le
# 800 righe per scelta: il claude finto, l'esca, il python3 finto e
# l'errore iniettato stanno qui dentro, così la suite non dipende da altri
# file. Il numero di prove di una funzione, nel suo commento, comprende
# quelle delle funzioni che chiama.
#
# Uso:    m1_fondamenti_llm/_docente/test_m1_d03.sh
# Uscita: 0 = tutte le prove passano · 1 = almeno una fallita
#         2 = precondizione (manca uno strumento o un file dell'elemento),
#             oppure le prove eseguite non sono CASES
set -uo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly MOD="${SELF%/_docente/*}"
readonly CARTELLA="${MOD}/s1_fondamenti_llm/m1_3_token_e_contesto"
readonly D03="${CARTELLA}/M1-D03_conta_lettere"
readonly D02="${CARTELLA}/M1-D02_token_lingue"
readonly VERIFICA="${D03}/verifica.sh"
readonly LIVE="${D03}/_docente/live.sh"
readonly PESI="${D03}/demo/controlla_pesi.py"
readonly README="${D03}/README.md"
readonly CASES=98
FATTO='Fatto: ogni affermazione è stata messa alla prova;'
FATTO+=' gli esiti sono qui sopra.'
readonly FATTO
readonly AFF1='Ogni parola pesa meno token delle sue lettere'
readonly AFF2='La parola compitata pesa più token della parola intera'
readonly AFF3='Gli stessi pesi su ogni modello'
readonly NON='non confermata in questa esecuzione'
GLOSSARIO='il glossario descrive token più grandi, usati quando possibile,'
GLOSSARIO+=' e token più piccoli per le parole non comuni o mai viste prima:'
GLOSSARIO+=' in questa esecuzione no'
readonly GLOSSARIO
readonly PER_LETTERA='Token per lettera nella parola compitata'
readonly NON_ESITO='il controllo è uscito con'
readonly PAROLA='interconnessione'
readonly COMPITATA='i n t e r c o n n e s s i o n e'
readonly KO_TRE='VERIFICA KO   le tre affermazioni (verifica.sh) (uscita 1)'
readonly T=$'\t'
TMP=''
ESCA_LOG=''
PASS=0
FAIL=0
SKIP=0
TRACCE=0
ESECUZIONI=0
RC=0
OUT=''
RIGHE=()

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }
skip() { echo "  SKIP: $1"; SKIP=$((SKIP + 1)); }

# Esegue un comando: RC e OUT (STDOUT e STDERR insieme) per le expect;
# conta le esecuzioni e quelle con un Traceback di Python nell'uscita.
# Globals: RC, OUT, ESECUZIONI, TRACCE. Arguments: il comando.
run() {
  OUT="$("$@" 2>&1)"
  RC=$?
  ESECUZIONI=$((ESECUZIONI + 1))
  if [[ "${OUT}" == *Traceback* ]]; then
    TRACCE=$((TRACCE + 1))
  fi
}

# Uscita attesa E ogni testo atteso (grep -F) nell'uscita (RU-01.T3).
# Arguments: $1 il nome, $2 l'uscita attesa, poi i testi.
expect() {
  local nome="$1" atteso="$2" testo
  shift 2
  if (( RC != atteso )); then
    fail "${nome} (rc=${RC}, attesa ${atteso}): ${OUT:0:400}"
    return
  fi
  for testo in "$@"; do
    if ! grep -qF -- "${testo}" <<< "${OUT}"; then
      fail "${nome} (manca «${testo}»): ${OUT:0:400}"
      return
    fi
  done
  pass "${nome}"
}

# Uscita attesa E, per ogni espressione (grep -E), una riga che le
# corrisponde. Arguments: $1 il nome, $2 l'uscita attesa, poi le
# espressioni.
expect_re() {
  local nome="$1" atteso="$2" re
  shift 2
  if (( RC != atteso )); then
    fail "${nome} (rc=${RC}, attesa ${atteso}): ${OUT:0:400}"
    return
  fi
  for re in "$@"; do
    if ! grep -qE -- "${re}" <<< "${OUT}"; then
      fail "${nome} (nessuna riga «${re}»): ${OUT:0:400}"
      return
    fi
  done
  pass "${nome}"
}

# Nessun falso positivo: nessuno dei testi è nell'uscita (RU-01.T5).
# Arguments: $1 il nome, poi i testi.
expect_absent() {
  local nome="$1" testo
  shift
  for testo in "$@"; do
    if grep -qF -- "${testo}" <<< "${OUT}"; then
      fail "${nome}: «${testo}» c'è: ${OUT:0:400}"
      return
    fi
  done
  pass "${nome}"
}

# L'uscita è $2 e l'ultima riga dell'uscita è esattamente $3.
# Arguments: $1 il nome, $2 l'uscita attesa, $3 la riga.
expect_ultima() {
  if (( RC == $2 )) && [[ "${OUT##*$'\n'}" == "$3" ]]; then
    pass "$1"
  else
    fail "$1 (rc=${RC}, ultima riga «${OUT##*$'\n'}»)"
  fi
}

# Una condizione già calcolata: 0 passa, altro fallisce.
# Arguments: $1 il nome, $2 l'esito della condizione, $3 il dettaglio.
expect_vero() {
  if (( $2 == 0 )); then
    pass "$1"
  else
    fail "$1: $3"
  fi
}

# Un nuovo spazio di lavoro con il punto di partenza dell'elemento, come
# lo prepara tools/prepara_esercizio.sh. Arguments: $1 la variabile.
partenza() {
  local __p
  __p="$(mktemp -d "${TMP}/ws.XXXXXX")" || { echo "mktemp" >&2; exit 2; }
  cp -R "${D03}/demo/." "${__p}/" || { echo "cp" >&2; exit 2; }
  printf -v "$1" '%s' "${__p}"
}

# Le sei righe di un modello in RIGHE: i singoli valgono base, base+10 e
# base+20, i doppi il singolo più il peso dato.
# Globals: RIGHE. Arguments: $1 il modello, $2 la base, $3 il peso di
# parola, $4 quello di compitata, $5 quello di strawberry.
sei() {
  RIGHE+=("$1|parola|$2" "$1|parola-doppia|$(($2 + $3))"
    "$1|compitata|$(($2 + 10))" "$1|compitata-doppia|$(($2 + 10 + $4))"
    "$1|strawberry|$(($2 + 20))" "$1|strawberry-doppia|$(($2 + 20 + $5))")
}

# conteggi.tsv nello spazio di lavoro: l'intestazione, poi RIGHE con «|»
# al posto della tabulazione; RIGHE torna vuota.
# Globals: RIGHE. Arguments: $1 lo spazio di lavoro.
scrivi() {
  local r
  printf 'modello\ttesto\ttoken_entrata\n' > "$1/conteggi.tsv"
  for r in ${RIGHE[@]+"${RIGHE[@]}"}; do
    printf '%s\n' "${r//|/${T}}" >> "$1/conteggi.tsv"
  done
  RIGHE=()
}

# Il claude finto e l'esca, in due cartelle da mettere davanti nel PATH.
# Il finto legge gli argomenti come la CLI vera (le opzioni con i loro
# valori, poi il prompt, anche dopo «--»), registra ogni chiamata in
# FINTO_LOG («modello<TAB>testo<TAB>opzioni in ordine, separate da |») e
# risponde secondo FINTO_MODO con un JSON sintetico. I token in entrata
# sono una base per modello più i pezzi del testo: un token ogni quattro
# caratteri di ogni parola (pezzi, il modo di default); un token per
# carattere, spazi compresi (lettere); le parole di una lettera a quattro
# a quattro, così la compitata pesa quanto la parola intera (corta); un
# token in più per parola su sonnet (sonnet_diverso); come
# pezzi, ma alla chiamata di «strawberry strawberry» cancella parola.txt
# (cancella). E poi un JSON con is_error, con uscita 0, così che a dirlo
# sia leggi_json.py (errore); nessun JSON, con uscita 1 (vuoto); un JSON
# senza usage (senza_usage). L'esca registra in ESCA_LOG il primo
# argomento di ogni chiamata; risponde solo a --version.
falsi_claude() {
  mkdir -p "${TMP}/finto" "${TMP}/esca" || exit 2
  cat > "${TMP}/finto/claude" <<'FINTO'
#!/bin/bash
set -uo pipefail
SENZA_VALORE=' -p --print --strict-mcp-config --no-session-persistence '
CON_VALORE=' --model --effort --tools --allowedTools --system-prompt'
CON_VALORE+=' --output-format --permission-mode --permission-prompts'
CON_VALORE+=' --setting-sources '
if [[ "${1:-}" == "--version" ]]; then echo "0.0.0 (finto)"; exit 0; fi
modello=''
prompt=()
opzioni=()
while (( $# > 0 )); do
  if [[ "$1" == "--" ]]; then
    shift
    prompt+=("$@")
    break
  elif [[ "$1" != -* ]]; then
    prompt+=("$1")
  elif [[ "${CON_VALORE}" == *" $1 "* ]]; then
    if (( $# < 2 )); then
      echo "error: option '$1' argument missing" >&2
      exit 1
    fi
    if [[ "$1" == "--model" ]]; then modello="$2"; fi
    opzioni+=("$1=$2")
    shift
  elif [[ "${SENZA_VALORE}" == *" $1 "* ]]; then
    opzioni+=("$1")
  else
    echo "error: unknown option '$1'" >&2
    exit 1
  fi
  shift
done
if (( ${#prompt[@]} != 1 )); then
  echo "error: atteso un prompt, ricevuti ${#prompt[@]}" >&2
  exit 1
fi
testo="${prompt[0]}"
elenco="$(printf '%s\n' "${opzioni[@]}" | LC_ALL=C sort | paste -sd'|' -)"
printf '%s\t%s\t%s\n' "${modello}" "${testo}" "${elenco}" >> "${FINTO_LOG:?}"
modo="${FINTO_MODO:-pezzi}"
testa='{"type":"result","is_error":false,"result":"ok","session_id":"finto"'
case "${modo}" in
  errore)
    echo '{"type":"result","is_error":true,"result":"","session_id":"finto"}'
    exit 0 ;;
  vuoto)
    echo "error: nessuna risposta (finto)" >&2
    exit 1 ;;
  senza_usage)
    echo "${testa}}"
    exit 0 ;;
esac
case "${modello}" in
  sonnet) n=562 ;;
  opus) n=558 ;;
  *) n=560 ;;
esac
singole=0
read -r -a parole <<< "${testo}"
for p in "${parole[@]}"; do
  if [[ "${modo}" == "lettere" ]]; then
    :
  elif [[ "${modo}" == "corta" ]] && (( ${#p} == 1 )); then
    singole=$((singole + 1))
  else
    n=$((n + (${#p} + 3) / 4))
  fi
  if [[ "${modo}" == "sonnet_diverso" && "${modello}" == "sonnet" ]]; then
    n=$((n + 1))
  fi
done
if [[ "${modo}" == "lettere" ]]; then
  n=$((n + ${#testo}))
fi
n=$((n + (singole + 3) / 4))
if [[ "${modo}" == "cancella" && "${testo}" == "strawberry strawberry" ]]
then
  rm -f parola.txt
fi
printf '%s,"usage":{"input_tokens":3,"cache_read_input_tokens":100,' \
  "${testa}"
printf '"cache_creation_input_tokens":%d,"output_tokens":1}}\n' \
  "$((n - 103))"
FINTO
  cat > "${TMP}/esca/claude" <<'ESCA'
#!/bin/bash
printf '%s\n' "${1:-}" >> "${ESCA_LOG:?}"
if [[ "${1:-}" == "--version" ]]; then echo "0.0.0 (esca)"; exit 0; fi
echo "esca: claude chiamato, e non doveva" >&2
exit 1
ESCA
  chmod 755 "${TMP}/finto/claude" "${TMP}/esca/claude" || exit 2
}

# Un python3 finto, da mettere davanti nel PATH: ignora gli argomenti ed
# esce 3; con FINTO_PYTHON=segnale si manda SIGTERM (uscita 143).
python_finto() {
  mkdir -p "${TMP}/python_finto" || exit 2
  cat > "${TMP}/python_finto/python3" <<'PYF'
#!/bin/bash
if [[ "${FINTO_PYTHON:-}" == "segnale" ]]; then
  kill -TERM "$$"
  exit 4
fi
exit 3
PYF
  chmod 755 "${TMP}/python_finto/python3" || exit 2
}

# Un controllo Python con un errore che non prevede: os.path.isdir solleva
# ZeroDivisionError sullo spazio di lavoro, e il controllo gira come
# script (__main__). Arguments: $1 il controllo, $2 lo spazio di lavoro.
guasto() {
  run python3 -B -I - "$1" "$2" <<'PY'
import os
import runpy
import sys

controllo, ws = sys.argv[1:3]
vero = os.path.isdir
os.path.isdir = lambda p: 1 / 0 if p == ws else vero(p)
sys.argv = [controllo, ws]
runpy.run_path(controllo, run_name="__main__")
PY
}

# _docente/live.sh con il claude finto davanti nel PATH; il registro delle
# chiamate riparte vuoto. Arguments: $1 lo spazio di lavoro, poi le
# variabili NOME=valore.
live() {
  local w="$1"
  shift
  : > "${TMP}/live.log"
  run env PATH="${TMP}/finto:${PATH}" HANDSON_NO_PAUSE=1 \
    FINTO_LOG="${TMP}/live.log" "$@" "${LIVE}" "${w}"
}

# Un comando con l'esca davanti nel PATH; il registro dell'esca riparte
# vuoto. Arguments: le variabili NOME=valore, poi il comando.
esca() {
  : > "${ESCA_LOG}"
  run env PATH="${TMP}/esca:${PATH}" HANDSON_NO_PAUSE=1 \
    ESCA_LOG="${ESCA_LOG}" "$@"
}

# Una precondizione di live.sh: uscita 2 con il messaggio atteso, e
# nessun prompt arrivato all'esca; con «nessuna», nemmeno claude --version.
# Arguments: $1 il nome, $2 il messaggio, $3 «nessuna» o «versione».
expect_esca() {
  local altre
  altre="$(grep -cvx -- '--version' "${ESCA_LOG}")"
  if (( RC != 2 )) || ! grep -qF -- "$2" <<< "${OUT}"; then
    fail "$1 (rc=${RC}, attesa 2, «$2»): ${OUT:0:300}"
  elif [[ "$3" == "nessuna" && -s "${ESCA_LOG}" ]]; then
    fail "$1: claude chiamato ($(paste -sd' ' "${ESCA_LOG}"))"
  elif (( altre > 0 )); then
    fail "$1: claude ha ricevuto un prompt"
  else
    pass "$1"
  fi
}

# Il blocco di codice del passo 3 del README, senza il rientro di sette
# spazi. Arguments: $1 il file da scrivere. Returns: 1 se il blocco manca.
estrai_passo_3() {
  awk '/^3\. / { dentro = 1; next }
    dentro && /^       / { print substr($0, 8); preso = 1; next }
    dentro && preso && !/^[[:space:]]*$/ { exit }' "${README}" > "$1"
  [[ -s "$1" ]]
}

# Il passo 3 del README nello spazio di lavoro, con il claude finto; le
# chiamate in readme.log. Arguments: $1 lo script del passo, $2 lo spazio
# di lavoro, $3 FINTO_MODO.
readme() {
  : > "${TMP}/readme.log"
  # shellcheck disable=SC2016  # $1 e $2 li espande la shell figlia
  run env PATH="${TMP}/finto:${PATH}" FINTO_LOG="${TMP}/readme.log" \
    FINTO_MODO="$3" bash -c 'cd -- "$1" && bash -- "$2"' _ "$2" "$1"
}

# --- Le prove ---------------------------------------------------------

# Il punto di partenza: i testi esatti, nessun file della versione
# precedente, leggi_json.py della famiglia di M1-D02. 7 prove.
t_partenza() {
  local d="${D03}/demo" f atteso esito
  for f in "parola.txt|${PAROLA}" "compitata.txt|${COMPITATA}" \
      'strawberry.txt|strawberry' 'istruzione.txt|Rispondi solo: ok'; do
    atteso="${f#*|}"
    esito=1
    if [[ "$(cat -- "${d}/${f%%|*}"; echo x)" == "${atteso}"$'\n'x ]]; then
      esito=0
    fi
    expect_vero "partenza: ${f%%|*} è «${atteso}» e una riga" "${esito}" \
      "contenuto diverso"
  done
  esito=1
  if [[ "$(sed 's/./& /g; s/ $//' "${d}/parola.txt")" \
      == "$(cat -- "${d}/compitata.txt")" ]]; then
    esito=0
  fi
  expect_vero "partenza: compitata.txt è parola.txt, lettera per lettera" \
    "${esito}" "le due parole non coincidono"
  esito=1
  if [[ ! -e "${d}/conta.txt" ]]; then
    esito=0
  fi
  expect_vero "partenza: conta.txt, la domanda di prima, non c'è più" \
    "${esito}" "conta.txt c'è ancora"
  esito=1
  if [[ "$(sha256sum < "${d}/leggi_json.py")" \
      == "$(sha256sum < "${D02}/demo/leggi_json.py")" ]]; then
    esito=0
  fi
  expect_vero "partenza: leggi_json.py identico a quello di M1-D02" \
    "${esito}" "le due copie differiscono"
}

# Le affermazioni attraverso verifica.sh: confermate, ai confini, non
# confermate, non distinguibili; i token per lettera, un dato. 22 prove.
t_verifica_esiti() {
  local w
  run "${VERIFICA}"
  expect "verifica.sh: senza argomento" 2 "spazio di lavoro assente"
  run "${VERIFICA}" "${TMP}/assente"
  expect "verifica.sh: spazio di lavoro assente" 2 "spazio di lavoro assente"
  partenza w
  run "${VERIFICA}" "${w}"
  expect "verifica.sh: il punto di partenza" 1 \
    "Manca conteggi.tsv: eseguite i passi del README."
  sei haiku 560 4 16 3
  sei sonnet 562 4 16 3
  sei opus 558 4 16 3
  scrivi "${w}"
  run "${VERIFICA}" "${w}"
  expect_ultima "verifica.sh: tre modelli, l'ultima riga è la frase finale" \
    0 "${FATTO}"
  expect "verifica.sh: tre modelli, le tre affermazioni confermate" 0 \
    "${AFF1}: confermata" "${AFF2}: confermata" "${AFF3}: confermata"
  expect_absent "verifica.sh: tre modelli, nessun altro esito" \
    "non confermata" "non distinguibile" "Da sistemare"
  expect_re "verifica.sh: le lettere contate dai testi, 16, 16 e 10" 0 \
    "^  parola +«${PAROLA}» +16$" "^  compitata +«${COMPITATA}» +16$" \
    '^  strawberry +«strawberry» +10$'
  expect_re "verifica.sh: i numeri letti e i pesi" 0 \
    '^  haiku +parola +560 +564 +4 +16$' \
    '^  opus +compitata +568 +584 +16 +16$'
  expect_re "verifica.sh: i token per lettera di ogni modello, un dato" 0 \
    "^${PER_LETTERA} \(un dato, senza verdetto\):$" \
    '^  haiku +16 token per 16 lettere$' '^  opus +16 token per 16 lettere$'
  sei haiku 560 15 16 3
  scrivi "${w}"
  run "${VERIFICA}" "${w}"
  expect "verifica.sh: un solo modello, la terza non distinguibile" 0 \
    "${AFF3}: non distinguibile (un solo modello con i sei conteggi" \
    "${AFF1}: confermata" "${FATTO}"
  sei haiku 560 4 16 10
  scrivi "${w}"
  run "${VERIFICA}" "${w}"
  expect "verifica.sh: «strawberry», 10 token per 10 lettere" 1 \
    "${AFF1}: ${NON}" "haiku, «strawberry»: 10 token per 10 lettere" \
    "secondo la documentazione il testo arriva al modello a pezzi"
  expect_absent "verifica.sh: non confermata, niente frase finale" "${FATTO}"
  expect_absent "verifica.sh: un'affermazione derivata, nessun «garantisce»" \
    "garantisce"
  sei haiku 560 16 16 3
  scrivi "${w}"
  run "${VERIFICA}" "${w}"
  expect "verifica.sh: «${PAROLA}», 16 token per 16 lettere" 1 \
    "${AFF1}: ${NON}" "haiku, «${PAROLA}»: 16 token per 16 lettere"
  sei haiku 560 4 15 3
  scrivi "${w}"
  run "${VERIFICA}" "${w}"
  expect "verifica.sh: compitata, 15 token per 16 lettere: un dato" 0 \
    "${AFF2}: confermata" "${PER_LETTERA}" "  haiku   15 token per 16 lettere"
  expect_absent "verifica.sh: i token per lettera non hanno un verdetto" \
    "lettera: confermata" "lettera: non" "almeno un token per lettera"
  sei haiku 560 5 5 3
  scrivi "${w}"
  run "${VERIFICA}" "${w}"
  expect "verifica.sh: la compitata pesa quanto la parola intera" 1 \
    "${AFF2}: ${NON}" "haiku, «${COMPITATA}»: 5 token, «${PAROLA}»: 5" \
    "  ${GLOSSARIO}"
  sei haiku 560 4 16 3
  sei sonnet 562 4 3 3
  scrivi "${w}"
  run "${VERIFICA}" "${w}"
  expect "verifica.sh: su sonnet la compitata pesa meno, la seconda no" 1 \
    "${AFF2}: ${NON}" "sonnet, «${COMPITATA}»: 3 token, «${PAROLA}»: 4"
  expect_absent "verifica.sh: haiku, 16 contro 4, non è fra i casi" \
    "haiku, «${COMPITATA}»"
  sei haiku 560 4 16 3
  sei sonnet 562 5 16 3
  scrivi "${w}"
  run "${VERIFICA}" "${w}"
  expect "verifica.sh: pesi diversi su sonnet" 1 "${AFF3}: ${NON}" \
    "sonnet: parola 5, compitata 16, strawberry 3" \
    "secondo la documentazione i modelli dalla 4.7 in poi usano lo stesso"
  expect "verifica.sh: pesi diversi, le altre due restano confermate" 1 \
    "${AFF1}: confermata" "${AFF2}: confermata"
  run python3 -B -I "${PESI}" "${w}"
  expect "controlla_pesi.py da solo: la stessa uscita 1" 1 "${AFF3}: ${NON}"
}

# Le righe di conteggi.tsv che non tornano. 18 prove.
t_verifica_righe() {
  local w
  partenza w
  printf 'haiku\tparola\t560\n' > "${w}/conteggi.tsv"
  run "${VERIFICA}" "${w}"
  expect "righe: senza intestazione" 1 \
    "la prima riga deve essere l'intestazione"
  : > "${w}/conteggi.tsv"
  run "${VERIFICA}" "${w}"
  expect "righe: file vuoto" 1 "la prima riga deve essere l'intestazione"
  scrivi "${w}"
  run "${VERIFICA}" "${w}"
  expect "righe: solo l'intestazione" 1 "non ha ancora conteggi" \
    "${AFF1}: non distinguibile (nessun modello con i sei conteggi)"
  sei haiku 560 4 16 3
  sei sonnet 562 4 16 3
  unset 'RIGHE[11]'
  scrivi "${w}"
  run "${VERIFICA}" "${w}"
  expect "righe: a sonnet manca un conteggio" 1 \
    "sonnet: mancano i conteggi di strawberry-doppia"
  sei haiku 560 4 16 3
  RIGHE[1]='haiku|parola-doppia|'
  scrivi "${w}"
  run "${VERIFICA}" "${w}"
  expect "righe: un conteggio vuoto" 1 \
    "riga 3: haiku, parola-doppia: conteggio vuoto o non numerico («»)"
  sei haiku 560 4 16 3
  RIGHE[1]='haiku|parola-doppia|12a'
  scrivi "${w}"
  run "${VERIFICA}" "${w}"
  expect "righe: un conteggio non numerico" 1 "non numerico («12a»)"
  sei haiku 560 4 16 3
  RIGHE[1]='haiku|parola-doppia|²'
  scrivi "${w}"
  run "${VERIFICA}" "${w}"
  expect "righe: una cifra in apice non è un conteggio" 1 \
    "non numerico («²»)"
  expect_absent "righe: una cifra in apice, nessun errore inatteso" \
    "errore inatteso"
  sei haiku 560 4 16 3
  RIGHE[1]="haiku|parola-doppia|$(printf '%5000s' '' | tr ' ' 1)"
  scrivi "${w}"
  run "${VERIFICA}" "${w}"
  expect "righe: 5000 cifre non sono un conteggio, accorciate" 1 \
    "non numerico («$(printf '%33s' '' | tr ' ' 1)…»)"
  expect_absent "righe: 5000 cifre, nessun errore inatteso" \
    "$(printf '%100s' '' | tr ' ' 1)" "errore inatteso"
  sei haiku 560 0 16 3
  scrivi "${w}"
  run "${VERIFICA}" "${w}"
  expect "righe: il doppio non pesa più del singolo" 1 \
    "haiku, parola: il doppio (560) non pesa più del singolo (560)"
  sei haiku 560 4 16 3
  RIGHE+=('fable|parola|560')
  scrivi "${w}"
  run "${VERIFICA}" "${w}"
  expect "righe: un modello non previsto" 1 \
    "riga 8: modello «fable» non previsto (haiku, sonnet, opus)"
  sei haiku 560 4 16 3
  RIGHE+=('haiku|parola-tripla|570')
  scrivi "${w}"
  run "${VERIFICA}" "${w}"
  expect "righe: un testo non previsto" 1 "testo «parola-tripla» non previsto"
  sei haiku 560 4 16 3
  RIGHE+=('haiku|parola')
  scrivi "${w}"
  run "${VERIFICA}" "${w}"
  expect "righe: due campi invece di tre" 1 \
    "attesi tre campi separati da tabulazioni, trovati 2"
  sei haiku 560 4 16 3
  RIGHE+=('haiku|parola-doppia|565')
  scrivi "${w}"
  run "${VERIFICA}" "${w}"
  expect "righe: un conteggio ripetuto, diverso" 1 \
    "haiku, parola-doppia: due conteggi diversi (564 e 565)"
  sei haiku 560 4 16 3
  RIGHE+=('haiku|parola-doppia|564')
  scrivi "${w}"
  run "${VERIFICA}" "${w}"
  expect "righe: un conteggio ripetuto, uguale, va bene" 0 "${FATTO}"
  sei haiku 560 4 16 3
  scrivi "${w}"
  sed -i -e 's/$/\r/' -e '1s/^/\xef\xbb\xbf/' -e 's/\t5/\t05/' \
    "${w}/conteggi.tsv"
  run "${VERIFICA}" "${w}"
  expect_re "righe: CRLF, BOM e zeri davanti" 0 \
    '^  haiku +parola +560 +564 +4 +16$' "^${FATTO}$"
  run "${VERIFICA}" "${w}"
  expect_absent "righe: CRLF, BOM e zeri davanti, senza segnalazioni" \
    "Da sistemare" "non confermata"
}

# Le lettere contate dai testi dello spazio di lavoro, e le precondizioni
# di controlla_pesi.py. 11 prove.
t_verifica_testi() {
  local w
  partenza w
  printf 'fragola\n' > "${w}/strawberry.txt"
  sei haiku 560 4 16 7
  scrivi "${w}"
  run "${VERIFICA}" "${w}"
  expect "testi: le lettere vengono dal testo (fragola, 7)" 1 \
    "haiku, «fragola»: 7 token per 7 lettere"
  partenza w
  printf 'perché\n' > "${w}/parola.txt"
  sei haiku 560 2 16 3
  scrivi "${w}"
  run env LC_ALL=C "${VERIFICA}" "${w}"
  expect_re "testi: una lettera accentata conta, anche con LC_ALL=C" 0 \
    '^  parola +«perché» +6$'
  rm -- "${w}/parola.txt"
  run "${VERIFICA}" "${w}"
  expect "testi: parola.txt mancante" 2 "manca parola.txt"
  partenza w
  printf '1 2 3\n' > "${w}/compitata.txt"
  run "${VERIFICA}" "${w}"
  expect "testi: un testo senza lettere" 2 \
    "compitata.txt non contiene lettere"
  partenza w
  printf 'modello\ttesto\ttoken_entrata\nhaiku\tparola\t\xff\n' \
    > "${w}/conteggi.tsv"
  run "${VERIFICA}" "${w}"
  expect "file: conteggi.tsv non UTF-8" 2 "conteggi.tsv non è un testo UTF-8"
  rm -- "${w}/conteggi.tsv"
  mkdir "${w}/conteggi.tsv"
  run "${VERIFICA}" "${w}"
  expect "file: conteggi.tsv è una cartella" 2 "conteggi.tsv non si legge"
  partenza w
  sei haiku 560 4 16 3
  scrivi "${w}"
  if (( EUID == 0 )); then
    skip "file: conteggi.tsv che non si legge (da root ogni file si legge)"
  else
    chmod 000 "${w}/conteggi.tsv"
    run "${VERIFICA}" "${w}"
    expect "file: conteggi.tsv che non si legge" 2 "conteggi.tsv non si legge"
    chmod 644 "${w}/conteggi.tsv"
  fi
  run python3 -B -I "${PESI}" "${w}" altro
  expect "controlla_pesi.py: un argomento di troppo" 2 "Uso:"
  run python3 -B -I "${PESI}" "${TMP}/assente"
  expect "controlla_pesi.py: spazio di lavoro assente" 2 \
    "spazio di lavoro assente"
  # shellcheck disable=SC2016  # $1 lo espande la shell figlia
  run bash -c 'cd -- "$1" && python3 controlla_pesi.py' _ "${w}"
  expect "controlla_pesi.py nello spazio di lavoro, come al passo 4" 0 \
    "il peso è il doppio meno il singolo" "${AFF2}: confermata"
  expect_absent "controlla_pesi.py da solo: la frase finale è di verifica.sh" \
    "${FATTO}"
}

# Le uscite che non sono un esito: verifica.sh con il python3 finto, che
# esce 3 o muore di SIGTERM, e controlla_pesi.py con un errore che non
# prevede. Escono 2 con un messaggio, mai 1 («non ancora»). 3 prove.
t_uscite() {
  local w
  partenza w
  sei haiku 560 4 16 3
  scrivi "${w}"
  run env PATH="${TMP}/python_finto:${PATH}" "${VERIFICA}" "${w}"
  expect "verifica.sh: il controllo esce 3, la verifica esce 2" 2 \
    "${NON_ESITO} 3: un errore, non un esito"
  run env PATH="${TMP}/python_finto:${PATH}" FINTO_PYTHON=segnale \
    "${VERIFICA}" "${w}"
  expect "verifica.sh: il controllo muore di SIGTERM, la verifica esce 2" 2 \
    "${NON_ESITO} 143: un errore, non un esito"
  guasto "${PESI}" "${w}"
  expect "controlla_pesi.py: un errore che non prevede, uscita 2" 2 \
    "controlla_pesi.py: errore inatteso del controllo (ZeroDivisionError"
}

# Il README: le sezioni, e il passo 3 eseguito con il claude finto su JSON
# sintetici. 11 prove.
t_readme() {
  local w s n passo="${TMP}/passo3.sh" tre="${TMP}/passo3_tre.sh" esito=0
  local -a mancano=()
  local sotto atteso
  for s in Obiettivo Tempo Prerequisiti 'Punto di partenza' \
      'Passi in Claude Code' 'Che cosa osservare' Verifica \
      'Se qualcosa va storto' "Impronta d'uso sul piano Pro" \
      'Per approfondire'; do
    n="$(grep -cE -- "^## ${s}([^[:alnum:]_]|\$)" "${README}")"
    if (( n != 1 )); then
      mancano+=("${s}")
    fi
  done
  sotto="$(awk '/^## / { s = $0 } /^### / { print s " > " $0 }' "${README}")"
  atteso="## Che cosa osservare > ### Che cosa dice Anthropic"
  atteso+=$'\n'"## Che cosa osservare > ### Che cosa misura il controllo"
  if (( ${#mancano[@]} > 0 )) || [[ "${sotto}" != "${atteso}" ]]; then
    esito=1
  fi
  expect_vero "README: le dieci sezioni e le due sottosezioni" "${esito}" \
    "sezioni mancanti o doppie: ${mancano[*]-}; sottosezioni: ${sotto}"
  esito=1
  if estrai_passo_3 "${passo}" && grep -q 'claude -p' "${passo}" \
      && (( $(grep -cx 'for m in haiku; do' "${passo}") == 1 )); then
    sed 's/^for m in haiku; do$/for m in haiku sonnet opus; do/' \
      "${passo}" > "${tre}"
    esito=0
  fi
  expect_vero "README: il passo 3 si estrae, con «for m in haiku; do»" \
    "${esito}" "blocco del passo 3 assente o cambiato"
  partenza w
  readme "${passo}" "${w}" pezzi
  run "${VERIFICA}" "${w}"
  expect_ultima "README, passo 3 su Haiku: la verifica passa" 0 "${FATTO}"
  cp -- "${TMP}/readme.log" "${TMP}/readme_haiku.log"
  partenza w
  readme "${tre}" "${w}" pezzi
  run "${VERIFICA}" "${w}"
  expect "README, passo 3 sui tre modelli: la terza confermata" 0 \
    "${AFF3}: confermata" "${FATTO}"
  partenza w
  readme "${passo}" "${w}" lettere
  run "${VERIFICA}" "${w}"
  expect "README, JSON di un token per carattere: la prima no" 1 \
    "${AFF1}: ${NON}" "${AFF2}: confermata"
  partenza w
  readme "${passo}" "${w}" corta
  run "${VERIFICA}" "${w}"
  expect "README, JSON con le lettere a quattro a quattro: la seconda no" 1 \
    "${AFF2}: ${NON}" "${AFF1}: confermata"
  partenza w
  readme "${tre}" "${w}" sonnet_diverso
  run "${VERIFICA}" "${w}"
  expect "README, JSON diversi su sonnet: la terza no" 1 "${AFF3}: ${NON}"
  t_readme_json_storti "${passo}"
  esito=1
  if (( $(wc -l < "${TMP}/readme_haiku.log") == 6 )); then
    esito=0
  fi
  expect_vero "README, passo 3: sei chiamate" "${esito}" \
    "$(wc -l < "${TMP}/readme_haiku.log") chiamate"
}

# Il passo 3 del README con un JSON che non dà il conteggio: leggi_json.py
# lo dice, la riga resta vuota e la verifica la segnala. 3 prove.
# Arguments: $1 lo script del passo.
t_readme_json_storti() {
  local w modo motivo prima
  for modo in 'errore|claude ha restituito un errore' \
      'vuoto|nessun JSON in ingresso' \
      'senza_usage|il JSON non contiene «usage»'; do
    motivo="${modo#*|}"
    modo="${modo%%|*}"
    partenza w
    readme "$1" "${w}" "${modo}"
    prima="${OUT}"
    run "${VERIFICA}" "${w}"
    OUT+=$'\n'"${prima}"
    expect "README, ${modo}: leggi_json.py lo dice, la verifica esce 1" 1 \
      "leggi_json.py: ${motivo}" "conteggio vuoto o non numerico («»)"
  done
}

# live.sh: le precondizioni, con l'esca. 7 prove.
t_live_precondizioni() {
  local w
  esca "${LIVE}"
  expect_esca "live.sh: senza argomento" "spazio di lavoro assente" nessuna
  esca "${LIVE}" "${TMP}/assente"
  expect_esca "live.sh: spazio di lavoro assente" "spazio di lavoro assente" \
    nessuna
  partenza w
  esca PN_MODELLI=fable "${LIVE}" "${w}"
  expect_esca "live.sh: un modello non ammesso" \
    "modello non ammesso in PN_MODELLI: «fable»" nessuna
  esca PN_MODELLI=' ' "${LIVE}" "${w}"
  expect_esca "live.sh: PN_MODELLI vuota" "PN_MODELLI è vuota" nessuna
  rm -- "${w}/strawberry.txt"
  esca "${LIVE}" "${w}"
  expect_esca "live.sh: strawberry.txt mancante" \
    "file assente o illeggibile: strawberry.txt" nessuna
  partenza w
  esca HANDSON_PERMISSION_MODE=nessuna "${LIVE}" "${w}"
  expect_esca "live.sh: modalità di permesso non ammessa" \
    "modalità di permesso non ammessa" versione
  esca HANDSON_ENV=altro "${LIVE}" "${w}"
  expect_esca "live.sh: ambiente non valido" "HANDSON_ENV non valido" \
    versione
}

# live.sh con il claude finto: l'esito, le chiamate, le uscite. 15 prove.
t_live() {
  local w atteso esito mostrati
  partenza w
  live "${w}"
  expect "live.sh: sei chiamate su Haiku, uscita 0" 0 \
    "VERIFICA OK   le tre affermazioni (verifica.sh)"
  expect "live.sh: i numeri e gli esiti a schermo anche su un OK" 0 \
    "il peso è il doppio meno il singolo" "${AFF1}: confermata" "${FATTO}"
  mostrati="$(grep -c '^  \$ claude -p' <<< "${OUT}")"
  expect_vero "live.sh: il comando si vede per le due chiamate del primo" \
    "$(( mostrati == 2 ? 0 : 1 ))" "${mostrati} comandi a schermo"
  atteso="$(printf '%s\n' "${PAROLA}" "${PAROLA} ${PAROLA}" "${COMPITATA}" \
    "${COMPITATA} ${COMPITATA}" strawberry 'strawberry strawberry')"
  esito=1
  if [[ "$(cut -f1 "${TMP}/live.log" | sort -u)" == "haiku" \
      && "$(cut -f2 "${TMP}/live.log")" == "${atteso}" ]]; then
    esito=0
  fi
  expect_vero "live.sh: i sei testi, nell'ordine, tutti su haiku" \
    "${esito}" "$(cut -f1,2 "${TMP}/live.log" | paste -sd'/' -)"
  atteso="$(printf '%s\n' -p --model=haiku --effort=low --tools= \
    '--system-prompt=Rispondi solo: ok' --strict-mcp-config \
    --no-session-persistence --output-format=json \
    --permission-mode=dontAsk --permission-prompts=none \
    --setting-sources=project,local | LC_ALL=C sort | paste -sd'|' -)"
  esito=0
  awk -F'\t' -v a="${atteso}" '$3 != a { e = 1 } END { exit e }' \
    "${TMP}/live.log" || esito=1
  expect_vero "live.sh: le opzioni di ogni chiamata" "${esito}" \
    "$(cut -f3 "${TMP}/live.log" | sort -u)"
  esito=0
  sed -e 's/|--permission-mode=dontAsk//' \
    -e 's/|--permission-prompts=none//' \
    -e 's/|--setting-sources=project,local//' "${TMP}/live.log" \
    | cmp -s - "${TMP}/readme_haiku.log" || esito=1
  expect_vero "live.sh e README: stessi testi, stesse opzioni (salvo tre)" \
    "${esito}" "le chiamate differiscono"
  run "${VERIFICA}" "${w}"
  expect_ultima "live.sh: il suo conteggi.tsv passa la verifica" 0 "${FATTO}"
  t_live_rami
}

# live.sh con il claude finto: i modelli di PN_MODELLI e ogni esito che
# non è un OK. 8 prove.
t_live_rami() {
  local w esito
  partenza w
  live "${w}" PN_MODELLI='haiku sonnet opus'
  expect "live.sh: tre modelli, la terza confermata" 0 \
    "${AFF3}: confermata" "VERIFICA OK"
  esito=1
  if [[ "$(cut -f1 "${TMP}/live.log" | uniq -c | awk '{ print $2 ":" $1 }' \
      | paste -sd' ' -)" == "haiku:6 sonnet:6 opus:6" ]]; then
    esito=0
  fi
  expect_vero "live.sh: diciotto chiamate, sei per modello, in ordine" \
    "${esito}" "$(cut -f1 "${TMP}/live.log" | uniq -c | paste -sd' ' -)"
  partenza w
  live "${w}" FINTO_MODO=lettere
  expect "live.sh: un token per carattere, la prima non confermata" 1 \
    "${KO_TRE}" "${AFF1}: ${NON}"
  partenza w
  live "${w}" FINTO_MODO=sonnet_diverso PN_MODELLI='haiku sonnet opus'
  expect "live.sh: pesi diversi su sonnet, la terza non confermata" 1 \
    "${KO_TRE}" "${AFF3}: ${NON}"
  partenza w
  live "${w}" FINTO_MODO=errore
  expect "live.sh: un JSON con is_error, nessun conteggio, uscita 1" 1 \
    "VERIFICA KO   haiku, testo «parola»: nessun conteggio" \
    "leggi_json.py: claude ha restituito un errore"
  partenza w
  live "${w}" FINTO_MODO=vuoto
  expect "live.sh: claude esce 1 senza JSON, uscita 1" 1 \
    "nessun conteggio" "error: nessuna risposta (finto)"
  partenza w
  live "${w}" FINTO_MODO=senza_usage
  expect "live.sh: un JSON senza usage, uscita 1" 1 "nessun conteggio" \
    "leggi_json.py: il JSON non contiene «usage»"
  partenza w
  live "${w}" FINTO_MODO=cancella
  expect "live.sh: una precondizione di verifica.sh diventa l'uscita 2" 2 \
    "FATALE" "manca parola.txt"
}

# Il controllo di shellcheck -x sugli script di M1-D03 e su questo file.
# 3 prove.
t_shellcheck() {
  local f
  for f in "${VERIFICA}" "${LIVE}" "${SELF}"; do
    run shellcheck -x -- "${f}"
    if (( RC == 0 )) && [[ -z "${OUT}" ]]; then
      pass "shellcheck ${f##*/}"
    else
      fail "shellcheck ${f##*/}: ${OUT:0:300}"
    fi
  done
}

main() {
  local t f
  for t in python3 shellcheck sha256sum paste sort uniq awk sed cmp cut; do
    if ! command -v "${t}" > /dev/null 2>&1; then
      echo "test_m1_d03.sh: manca lo strumento ${t}" >&2
      exit 2
    fi
  done
  for f in "${VERIFICA}" "${LIVE}" "${PESI}" "${README}" \
      "${D02}/demo/leggi_json.py"; do
    if [[ ! -f "${f}" ]]; then
      echo "test_m1_d03.sh: manca ${f#"${MOD}"/}" >&2
      exit 2
    fi
  done
  unset ANTHROPIC_API_KEY HANDSON_ENV HANDSON_PERMISSION_MODE \
    HANDSON_SHOW_CMD HANDSON_NO_PAUSE PN_MODELLI FINTO_MODO FINTO_LOG \
    FINTO_PYTHON
  TMP="$(mktemp -d)" || { echo "mktemp non riesce" >&2; exit 2; }
  readonly TMP
  trap 'chmod -R u+rwx -- "${TMP}" 2> /dev/null; rm -rf -- "${TMP}"' EXIT
  ESCA_LOG="${TMP}/esca.log"
  falsi_claude
  python_finto
  echo "test_m1_d03.sh"
  t_partenza
  t_verifica_esiti
  t_verifica_righe
  t_verifica_testi
  t_uscite
  t_readme
  t_live_precondizioni
  t_live
  t_shellcheck
  expect_vero "mai un Traceback, in ${ESECUZIONI} esecuzioni" \
    "$(( TRACCE == 0 ? 0 : 1 ))" "${TRACCE} uscite con un Traceback"
  echo "PASS=${PASS} FAIL=${FAIL} SKIP=${SKIP}"
  if (( PASS + FAIL + SKIP != CASES )); then
    echo "test_m1_d03.sh: eseguite $((PASS + FAIL + SKIP)) prove," \
      "attese ${CASES}: ne manca una, o ce n'è una in più" >&2
    exit 2
  fi
  (( FAIL == 0 )) || exit 1
}

main "$@"
