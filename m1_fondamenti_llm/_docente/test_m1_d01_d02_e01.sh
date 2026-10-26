#!/bin/bash
#
# test_m1_d01_d02_e01.sh -- le prove dei controlli di M1-D01, M1-D02 e
# M1-E01, per il docente (sta in _docente/, che resta fuori dalla copia
# senza soluzioni di tools/esporta_studenti.sh):
#   - verifica.py di M1-D01, attraverso verifica.sh: ogni ramo dei due
#     verdetti (parole diverse: confermata, non dimostrata, una sola
#     risposta; una parola sola: confermata, non confermata, che non fa
#     fallire), un modello senza risposte, le righe di altri modelli, a
#     capo CRLF e BOM, LC_ALL=C, un file che non è UTF-8, nessun argomento;
#     una risposta su più righe (una riga senza tabulazione continua la
#     risposta di sopra, e le righe unite si contano a schermo), anche una
#     che comincia con un a capo;
#   - verifica.py di M1-D02: i due verdetti (confermata, non dimostrata,
#     non distinguibile senza le frasi o con un peso non positivo); l'uscita
#     decisa dalla completezza e dai pesi positivi, mai dal verso della
#     differenza, che si stampa come confronto con la registrazione (sì o
#     no); un peso non positivo da rifare, un modello incompleto, un
#     conteggio che non è un numero o di 5000 cifre, i file che non si
#     leggono;
#   - verifica.py di M1-E01: la riga sulla latenza, anche su un esito da
#     sistemare, e i JSON rovinati (vuoto, con errore, senza usage, da un
#     altro modello, non UTF-8, annidato oltre il limite di Python, una
#     durata di 311 cifre, un modello con un surrogato isolato); una cifra
#     in apice e una cella di 5000 cifre nella tabella;
#   - per ogni verifica.sh: spazio di lavoro assente (2), punto di partenza
#     (1, con il suo messaggio), soluzione (0, ultima riga la frase finale),
#     il file dei risultati che non si legge (2; saltato da root); un
#     python3 finto che esce 3 o muore di SIGTERM, e un errore che il
#     controllo non prevede: uscita 2 con un messaggio, mai 1; in nessuna
#     uscita un traceback di Python;
#   - i tre _docente/live.sh: le precondizioni escono 2 senza chiamare
#     claude (un claude esca, primo nel PATH, registra ogni chiamata; con
#     una modalità di permesso non ammessa solo «--version»); M1-D01 e
#     M1-D02 dal vivo con il claude esca, poi la loro verifica.sh; il
#     live.sh di M1-D02 esce come la sua verifica.sh, anche con l'inglese
#     più pesante (uscita 0, il confronto «no» a schermo);
#   - shellcheck -x sui tre verifica.sh e su questo file.
# Gli spazi di lavoro nascono in una cartella temporanea: l'albero del
# repository non cambia. Il claude vero non viene mai chiamato.
#
# Uso:    m1_fondamenti_llm/_docente/test_m1_d01_d02_e01.sh
# Uscita: 0 = tutte le prove passano · 1 = almeno una fallita
#         2 = precondizione (manca jq, python3 o shellcheck, o la cartella
#             di un elemento), oppure un numero di prove diverso da CASES
set -uo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly MOD="${SELF%/_docente/*}"
readonly S1="${MOD}/s1_fondamenti_llm"
readonly D01="${S1}/m1_2_cosa_fanno_leggono_imparano/M1-D01_prossima_parola"
readonly D02="${S1}/m1_3_token_e_contesto/M1-D02_token_lingue"
readonly E01="${S1}/m1_e2_stesso_prompt_tre_modelli/M1-E01_stesso_prompt"
readonly ELEMENTI=("${D01}" "${D02}" "${E01}")
readonly CASES=136
FATTO='Fatto: ogni affermazione è stata messa alla prova;'
FATTO+=' gli esiti sono qui sopra.'
readonly FATTO
readonly VARIA='Input identici potrebbero produrre output diversi'
ISTRUZIONE='Istruzione esplicita rispettata,'
ISTRUZIONE+=' una parola sola senza punteggiatura'
readonly ISTRUZIONE
readonly TOKEN='Il numero di token dello stesso testo dipende dalla lingua'
readonly CARATTERI='Quanti caratteri vale un token dipende dalla lingua'
readonly NON_DIM='non dimostrata in questa esecuzione'
CONFRONTO='Nella registrazione del corso la frase italiana pesa più di'
CONFRONTO+=' quella inglese (27 contro 17): in questa esecuzione'
readonly CONFRONTO
readonly NON_ESITO='il controllo è uscito con'
LATENZA='Latenza comparata secondo Anthropic, Haiku la più veloce, poi Sonnet,'
LATENZA+=' poi Opus: non distinguibile (una chiamata per modello non la misura)'
readonly LATENZA
readonly T=$'\t'
TMP=''
PASS=0
FAIL=0
SKIP=0
RC=0
OUT=''

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }
skip() { echo "  SKIP: $1"; SKIP=$((SKIP + 1)); }

# Esegue un comando; RC e OUT (STDOUT e STDERR insieme) per le attese.
run() { OUT="$("$@" 2>&1)"; RC=$?; }

# Vero se l'uscita non contiene un traceback di Python.
senza_traceback() { ! grep -qF -- 'Traceback' <<< "${OUT}"; }

# Uscita attesa E parola attesa (RU-01.T3), e nessun traceback.
# Arguments: $1 il nome, $2 l'uscita attesa, $3 la parola (grep -F).
expect() {
  if (( RC == $2 )) && grep -qF -- "$3" <<< "${OUT}" && senza_traceback
  then
    pass "$1"
  else
    fail "$1 (rc=${RC}, attesa $2, parola «$3»): ${OUT:0:400}"
  fi
}

# Come expect, ma la parola è una riga intera dell'uscita.
expect_riga() {
  if (( RC == $2 )) && grep -qxF -- "$3" <<< "${OUT}" && senza_traceback
  then
    pass "$1"
  else
    fail "$1 (rc=${RC}, attesa $2, riga «$3»): ${OUT:0:400}"
  fi
}

# Nessun falso positivo: la parola NON c'è (RU-01.T5).
expect_absent() {
  if grep -qF -- "$2" <<< "${OUT}"; then
    fail "$1: «$2» c'è"
  else
    pass "$1"
  fi
}

# Uscita 0, nessun traceback, e l'ultima riga è esattamente la frase
# finale. Arguments: $1 il nome.
expect_fatto() {
  if (( RC == 0 )) && [[ "${OUT##*$'\n'}" == "${FATTO}" ]] \
      && senza_traceback; then
    pass "$1"
  else
    fail "$1 (rc=${RC}, attesa 0 e l'ultima riga «${FATTO}»): ${OUT:0:400}"
  fi
}

# Un nuovo spazio di lavoro, con il contenuto delle cartelle indicate,
# nell'ordine. Arguments: $1 la variabile da assegnare, poi le cartelle.
ws() {
  local __w __d
  __w="$(mktemp -d "${TMP}/ws.XXXXXX")" || { echo "mktemp" >&2; exit 2; }
  for __d in "${@:2}"; do
    cp -R "${__d}/." "${__w}/"
  done
  printf -v "$1" '%s' "${__w}"
}

# Scrive un file di righe: ogni argomento è una riga, con «|» al posto
# della tabulazione. Arguments: $1 il file, poi le righe.
tsv() {
  local f="$1" r
  shift
  : > "${f}"
  for r in "$@"; do
    printf '%s\n' "${r//|/${T}}" >> "${f}"
  done
}

# Cambia un campo di primo livello di un JSON: «-» lo toglie, altrimenti
# il valore è un letterale JSON. Arguments: $1 il file, $2 il campo, $3 il
# valore.
json_set() {
  python3 -B -I - "$@" <<'PY'
import json
import sys

path, campo, valore = sys.argv[1:4]
with open(path, encoding="utf-8") as fh:
    dati = json.load(fh)
if valore == "-":
    dati.pop(campo, None)
else:
    dati[campo] = json.loads(valore)
with open(path, "w", encoding="utf-8") as fh:
    json.dump(dati, fh)
PY
}

# Il claude esca: registra ogni chiamata, gli argomenti su una riga, in
# ESCA_LOG; a «--version» risponde. Con ESCA_MODO=parole risponde, a
# turno, «sciopero» e «ritardo»; con ESCA_MODO=token i token in entrata
# sono 500 più i byte del prompt (l'ultimo argomento, dopo «--»); con
# ESCA_MODO=token_inglese, sulla frase inglese, i byte valgono tre volte,
# così l'inglese pesa più dell'italiano; senza ESCA_MODO esce 1. Non è
# mai il claude vero.
claude_esca() {
  mkdir -p "${TMP}/bin"
  cat > "${TMP}/bin/claude" <<'ESCA'
#!/bin/bash
set -uo pipefail
printf '%s\n' "$*" >> "${ESCA_LOG:?}"
if [[ "${1:-}" == "--version" ]]; then echo "0.0.0 (esca)"; exit 0; fi
prompt="${!#}"
case "${ESCA_MODO:-}" in
  parole)
    n=0
    if [[ -f "${ESCA_LOG}.n" ]]; then n="$(cat "${ESCA_LOG}.n")"; fi
    n=$((n + 1))
    echo "${n}" > "${ESCA_LOG}.n"
    parola=ritardo
    if (( n % 2 == 1 )); then parola=sciopero; fi
    printf '{"type":"result","is_error":false,"result":"%s"}\n' "${parola}"
    ;;
  token|token_inglese)
    byte="$(printf '%s' "${prompt}" | wc -c)"
    if [[ "${ESCA_MODO}" == token_inglese && "${prompt}" == *meeting* ]]; then
      byte=$((byte * 3))
    fi
    printf '{"type":"result","is_error":false,"result":"ok","usage":'
    printf '{"input_tokens":%d,"cache_creation_input_tokens":0,' \
      "$((500 + byte))"
    printf '"cache_read_input_tokens":0,"output_tokens":1}}\n'
    ;;
  *)
    echo "claude esca: nessuna risposta prevista" >&2
    exit 1
    ;;
esac
ESCA
  chmod 755 "${TMP}/bin/claude"
}

# Un python3 finto, da mettere davanti nel PATH: ignora gli argomenti ed
# esce 3; con FINTO_PYTHON=segnale si manda SIGTERM (uscita 143).
python_finto() {
  mkdir -p "${TMP}/python_finto"
  cat > "${TMP}/python_finto/python3" <<'PYF'
#!/bin/bash
if [[ "${FINTO_PYTHON:-}" == "segnale" ]]; then
  kill -TERM "$$"
  exit 4
fi
exit 3
PYF
  chmod 755 "${TMP}/python_finto/python3"
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

# Un live.sh con il claude esca davanti nel PATH; il registro riparte
# vuoto. Arguments: $1 l'elemento, $2 lo spazio di lavoro, poi le
# variabili NOME=valore.
live() {
  local e="$1" w="$2"
  shift 2
  : > "${TMP}/esca.log"
  rm -f -- "${TMP}/esca.log.n"
  run env PATH="${TMP}/bin:${PATH}" HANDSON_NO_PAUSE=1 \
    ESCA_LOG="${TMP}/esca.log" "$@" "${e}/_docente/live.sh" "${w}"
}

# Nessuna chiamata a claude, nemmeno «--version». Arguments: $1 il nome.
nessuna_chiamata() {
  if [[ -s "${TMP}/esca.log" ]]; then
    fail "$1: claude chiamato: $(head -c 200 "${TMP}/esca.log")"
  else
    pass "$1"
  fi
}

# Al più «claude --version», mai un prompt. Arguments: $1 il nome.
solo_versione() {
  if grep -qvxF -- '--version' "${TMP}/esca.log"; then
    fail "$1: claude chiamato con un prompt: $(head -c 200 "${TMP}/esca.log")"
  else
    pass "$1"
  fi
}

# --- I test ---------------------------------------------------------------

# Ogni verifica.sh: spazio di lavoro assente (2) e punto di partenza (1).
t_base() {
  local w
  run "${D01}/verifica.sh" "${TMP}/assente"
  expect "M1-D01: spazio di lavoro assente" 2 "spazio di lavoro assente"
  run "${D02}/verifica.sh" "${TMP}/assente"
  expect "M1-D02: spazio di lavoro assente" 2 "spazio di lavoro assente"
  run "${E01}/verifica.sh" "${TMP}/assente"
  expect "M1-E01: spazio di lavoro assente" 2 "spazio di lavoro assente"
  ws w "${D01}/demo"
  run "${D01}/verifica.sh" "${w}"
  expect "M1-D01: punto di partenza" 1 \
    "Manca risultati.tsv: eseguite i passi del README."
  ws w "${D02}/demo"
  run "${D02}/verifica.sh" "${w}"
  expect "M1-D02: punto di partenza" 1 \
    "Manca conteggi.tsv: eseguite i passi del README."
  ws w "${E01}/esercizio"
  run "${E01}/verifica.sh" "${w}"
  expect "M1-E01: punto di partenza" 1 \
    "Da sistemare: manca risposte/haiku.json"
  run python3 -B -I "${D01}/verifica.py"
  expect "M1-D01: verifica.py senza argomenti" 2 "serve lo spazio di lavoro"
  run python3 -B -I "${D02}/verifica.py"
  expect "M1-D02: verifica.py senza argomenti" 2 "serve lo spazio di lavoro"
}

# M1-D01: la soluzione (la registrazione del corso) e ogni ramo dei due
# verdetti.
t_d01_verdetti() {
  local w
  ws w "${D01}/demo" "${D01}/soluzione"
  run "${D01}/verifica.sh" "${w}"
  expect_fatto "M1-D01: la soluzione passa, l'ultima riga è la frase finale"
  expect_riga "M1-D01: soluzione, haiku sempre «maltempo»: non dimostrata" 0 \
    "${VARIA} (haiku): ${NON_DIM}"
  expect_riga "M1-D01: soluzione, una parola sola 20 su 20: confermata" 0 \
    "${ISTRUZIONE} (opus, 20 su 20): confermata"
  expect "M1-D01: soluzione, le parole e le volte" 0 \
    "sonnet: 20 risposte -- «sciopero» ×20"
  ws w
  tsv "${w}/risultati.tsv" 'modello|parola' 'haiku|sciopero' \
    'haiku|ritardo' 'haiku|sciopero' 'sonnet|sciopero' 'sonnet|sciopero' \
    'opus|guasto'
  run "${D01}/verifica.sh" "${w}"
  expect_riga "M1-D01: due parole diverse: confermata" 0 \
    "${VARIA} (haiku): confermata"
  expect "M1-D01: le parole diverse si contano" 0 "parole diverse: 2"
  expect_riga "M1-D01: una sola parola, due risposte: non dimostrata" 0 \
    "${VARIA} (sonnet): ${NON_DIM}"
  expect_riga "M1-D01: una sola risposta: non dimostrata, e perché" 0 \
    "${VARIA} (opus): ${NON_DIM} (una sola risposta)"
  expect_fatto "M1-D01: un «potrebbero» non fa fallire la verifica"
  ws w
  tsv "${w}/risultati.tsv" 'modello|parola' 'haiku|sciopero.' \
    'haiku|lo sciopero' 'haiku|  sciopero  ' 'sonnet|Sciopero' \
    'sonnet|sciopero' 'opus|sciopero'
  run "${D01}/verifica.sh" "${w}"
  expect_riga "M1-D01: punteggiatura e due parole: non confermata" 0 \
    "${ISTRUZIONE} (haiku, 1 su 3): non confermata in questa esecuzione"
  expect_fatto "M1-D01: la raccomandazione non fa fallire la verifica"
  expect_riga "M1-D01: maiuscole diverse sono output diversi" 0 \
    "${VARIA} (sonnet): confermata"
  expect_riga "M1-D01: gli spazi in testa e in coda non contano" 0 \
    "haiku: 3 risposte -- «sciopero.» ×1, «lo sciopero» ×1, «sciopero» ×1"
}

# M1-D01: i casi da segnalare (1) e quelli limite.
t_d01_casi() {
  local w
  ws w
  tsv "${w}/risultati.tsv" 'haiku|sciopero'
  run "${D01}/verifica.sh" "${w}"
  expect "M1-D01: senza intestazione" 1 \
    "la prima riga deve essere l'intestazione «modello<TAB>parola»."
  : > "${w}/risultati.tsv"
  run "${D01}/verifica.sh" "${w}"
  expect "M1-D01: file vuoto" 1 "la prima riga deve essere l'intestazione"
  tsv "${w}/risultati.tsv" 'modello|parola' 'haiku|sciopero' 'sonnet|sciopero'
  run "${D01}/verifica.sh" "${w}"
  expect "M1-D01: un modello senza risposte" 1 \
    "Nessuna risposta di opus in risultati.tsv."
  expect_absent "M1-D01: e niente frase finale" "${FATTO}"
  tsv "${w}/risultati.tsv" 'modello|parola' 'haiku|sciopero' 'sonnet|' \
    'sonnet|   ' 'opus|sciopero'
  run "${D01}/verifica.sh" "${w}"
  expect "M1-D01: righe senza risposta non contano" 1 \
    "Nessuna risposta di sonnet in risultati.tsv."
  tsv "${w}/risultati.tsv" 'modello|parola' 'haiku|sciopero' \
    'sonnet|sciopero' 'opus|sciopero' 'fable|tempesta' 'Haiku|neve'
  run "${D01}/verifica.sh" "${w}"
  expect "M1-D01: righe di altri modelli, contate e ignorate" 0 \
    "Righe di altri modelli, ignorate: 2."
  printf '\xef\xbb\xbfmodello\tparola\r\nhaiku\tsciopero\r\n' \
    > "${w}/risultati.tsv"
  printf 'sonnet\tsciopero\r\nopus\tsciopero\r\n' >> "${w}/risultati.tsv"
  run "${D01}/verifica.sh" "${w}"
  expect_fatto "M1-D01: BOM e a capo CRLF"
  if [[ "${OUT}" == *$'\r'* ]]; then
    fail "M1-D01: un ritorno a capo è rimasto nelle parole"
  else
    pass "M1-D01: nessun ritorno a capo nelle parole"
  fi
  tsv "${w}/risultati.tsv" 'modello|parola' 'haiku|città' 'haiku|città' \
    'sonnet|perché' 'opus|caffè'
  run env LC_ALL=C "${D01}/verifica.sh" "${w}"
  expect "M1-D01: LC_ALL=C, le lettere accentate sono lettere" 0 \
    "haiku: 2 risposte -- «città» ×2"
  expect_riga "M1-D01: LC_ALL=C, una parola sola" 0 \
    "${ISTRUZIONE} (sonnet, 1 su 1): confermata"
  printf 'modello\tparola\nhaiku\tsciop\xe9ro\n' > "${w}/risultati.tsv"
  run "${D01}/verifica.sh" "${w}"
  expect "M1-D01: un file che non è UTF-8, uscita 2" 2 \
    "risultati.tsv non è un testo UTF-8"
}

# M1-D01: una risposta su più righe, come la scrive il printf del passo 3.
# Una riga senza tabulazione continua la risposta di sopra, unita da uno
# spazio; prima di ogni risposta non conta.
t_d01_righe() {
  local w
  ws w
  printf 'modello\tparola\nhaiku\tmaltempo\n\nSpiegazione: la frase' \
    > "${w}/risultati.tsv"
  printf ' parla di un rinvio.\nsonnet\tsciopero\nopus\tsciopero\n' \
    >> "${w}/risultati.tsv"
  run "${D01}/verifica.sh" "${w}"
  expect_riga "M1-D01: una risposta su più righe, letta per intero" 0 \
    "${ISTRUZIONE} (haiku, 0 su 1): non confermata in questa esecuzione"
  expect "M1-D01: le righe di una risposta unite da uno spazio" 0 \
    "haiku: 1 risposta -- «maltempo Spiegazione: la frase parla di…» ×1"
  expect_riga "M1-D01: le righe unite si contano, a schermo" 0 \
    "Righe senza tabulazione, unite alla risposta di sopra: 1."
  printf 'modello\tparola\nhaiku\tsciopero\nsonnet\t\nsciopero\n' \
    > "${w}/risultati.tsv"
  printf 'opus\tsciopero\n' >> "${w}/risultati.tsv"
  run "${D01}/verifica.sh" "${w}"
  expect "M1-D01: una risposta che comincia con un a capo" 0 \
    "sonnet: 1 risposta -- «sciopero» ×1"
  printf 'modello\tparola\nuna riga sola\nhaiku\tsciopero\n' \
    > "${w}/risultati.tsv"
  printf 'sonnet\tsciopero\nopus\tsciopero\n' >> "${w}/risultati.tsv"
  run "${D01}/verifica.sh" "${w}"
  expect "M1-D01: una riga senza tabulazione prima di ogni risposta" 0 \
    "haiku: 1 risposta -- «sciopero» ×1"
}

# M1-D02: la soluzione e i due verdetti.
t_d02_verdetti() {
  local w riga
  ws w "${D02}/demo" "${D02}/soluzione"
  run "${D02}/verifica.sh" "${w}"
  expect_fatto "M1-D02: la soluzione passa, l'ultima riga è la frase finale"
  expect_riga "M1-D02: soluzione, i caratteri per token" 0 \
    "haiku: caratteri per token, italiano 2,4 (66/27), inglese 3,7 (63/17)"
  expect_riga "M1-D02: soluzione, il numero di token: confermata" 0 \
    "${TOKEN} (opus): confermata"
  expect_riga "M1-D02: soluzione, i caratteri per token: confermata" 0 \
    "${CARATTERI} (sonnet): confermata"
  expect_riga "M1-D02: soluzione, il confronto con la registrazione: sì" 0 \
    "${CONFRONTO} sì"
  ws w "${D02}/soluzione"
  run "${D02}/verifica.sh" "${w}"
  riga="${CARATTERI} (haiku): non distinguibile"
  riga+=" (mancano frase_it.txt e frase_en.txt)"
  expect_riga "M1-D02: senza le frasi, non distinguibile" 0 "${riga}"
  expect_fatto "M1-D02: senza le frasi la verifica passa comunque"
  ws w "${D02}/demo" "${D02}/soluzione"
  rm -f -- "${w}/frase_en.txt"
  run "${D02}/verifica.sh" "${w}"
  expect_riga "M1-D02: senza la frase inglese, non distinguibile" 0 \
    "${CARATTERI} (haiku): non distinguibile (manca frase_en.txt)"
  ws w "${D02}/demo"
  tsv "${w}/conteggi.tsv" 'modello|testo|token_entrata' 'haiku|it|500' \
    'haiku|it-doppia|522' 'haiku|en|500' 'haiku|en-doppia|521'
  run "${D02}/verifica.sh" "${w}"
  expect_riga "M1-D02: caratteri per token uguali (66/22, 63/21)" 0 \
    "${CARATTERI} (haiku): ${NON_DIM}"
  expect_fatto "M1-D02: un «dipende» non dimostrato non fa fallire"
}

# M1-D02: l'uscita decisa dalla completezza e dai pesi positivi, mai dal
# verso della differenza: il confronto con la registrazione si stampa, sì
# o no; un peso che non è positivo è una misura da rifare.
t_d02_casi() {
  local w
  ws w "${D02}/demo"
  tsv "${w}/conteggi.tsv" 'modello|testo|token_entrata' 'haiku|it|100' \
    'haiku|it-doppia|117' 'haiku|en|90' 'haiku|en-doppia|107'
  run "${D02}/verifica.sh" "${w}"
  expect_fatto "M1-D02: pesi uguali, la verifica passa"
  expect_riga "M1-D02: pesi uguali, il numero di token: non dimostrata" 0 \
    "${TOKEN} (haiku): ${NON_DIM}"
  expect_riga "M1-D02: pesi uguali, il confronto con la registrazione: no" \
    0 "${CONFRONTO} no"
  expect_riga "M1-D02: pesi uguali, la differenza è un dato" 0 \
    "haiku: italiano 17 token, inglese 17 (0 %)"
  tsv "${w}/conteggi.tsv" 'modello|testo|token_entrata' 'haiku|it|100' \
    'haiku|it-doppia|110' 'haiku|en|90' 'haiku|en-doppia|107'
  run "${D02}/verifica.sh" "${w}"
  expect_fatto "M1-D02: l'inglese pesa di più, la verifica passa"
  expect_riga "M1-D02: e il numero di token dipende dalla lingua" 0 \
    "${TOKEN} (haiku): confermata"
  expect_riga "M1-D02: l'inglese pesa di più, il confronto: no" 0 \
    "${CONFRONTO} no"
  expect_riga "M1-D02: l'inglese pesa di più, la differenza è un dato" 0 \
    "haiku: italiano 10 token, inglese 17 (-41 %)"
  expect_absent "M1-D02: il verso della differenza non è un'attesa" \
    "atteso italiano"
  tsv "${w}/conteggi.tsv" 'modello|testo|token_entrata' 'haiku|it|581' \
    'haiku|it-doppia|608' 'haiku|en|571' 'haiku|en-doppia|588' \
    'sonnet|it|583' 'sonnet|it-doppia|593' 'sonnet|en|573' \
    'sonnet|en-doppia|590'
  run "${D02}/verifica.sh" "${w}"
  expect_riga "M1-D02: versi diversi su due modelli, il confronto: no" 0 \
    "${CONFRONTO} no"
  tsv "${w}/conteggi.tsv" 'modello|testo|token_entrata' 'haiku|it|100' \
    'haiku|it-doppia|90' 'haiku|en|90' 'haiku|en-doppia|107'
  run "${D02}/verifica.sh" "${w}"
  expect_riga "M1-D02: un peso negativo, non distinguibile" 1 \
    "${CARATTERI} (haiku): non distinguibile (un peso non è positivo)"
  expect "M1-D02: un peso negativo, una misura da rifare" 1 \
    "Da rifare: haiku: un peso non è positivo"
  expect_absent "M1-D02: un peso negativo, niente frase finale" "${FATTO}"
  tsv "${w}/conteggi.tsv" 'modello|testo|token_entrata' 'haiku|it|100' \
    'haiku|it-doppia|127' 'haiku|en|90' 'haiku|en-doppia|90'
  run "${D02}/verifica.sh" "${w}"
  expect "M1-D02: l'inglese pesa zero, una misura da rifare, uscita 1" 1 \
    "Da rifare: haiku: un peso non è positivo"
  expect_absent "M1-D02: con un peso zero nessun confronto" "${CONFRONTO}"
  tsv "${w}/conteggi.tsv" 'modello|testo|token_entrata' 'haiku|it|581' \
    'haiku|it-doppia|608' 'haiku|en|571' 'haiku|en-doppia|588' \
    'sonnet|it|583' 'sonnet|it-doppia|583' 'sonnet|en|573' \
    'sonnet|en-doppia|590'
  run "${D02}/verifica.sh" "${w}"
  expect "M1-D02: sonnet con un peso zero, da rifare anche se haiku va" 1 \
    "Da rifare: sonnet: un peso non è positivo"
  expect_riga "M1-D02: il confronto sui modelli con i pesi positivi" 1 \
    "${CONFRONTO} sì"
  tsv "${w}/conteggi.tsv" 'modello|testo|token_entrata' \
    "haiku|it|$(printf '%5000s' '' | tr ' ' 1)" 'haiku|it-doppia|608' \
    'haiku|en|571' 'haiku|en-doppia|588'
  run "${D02}/verifica.sh" "${w}"
  expect "M1-D02: un conteggio di 5000 cifre non conta, mai un traceback" 1 \
    "haiku: mancano i conteggi di it: il modello non conta"
  tsv "${w}/conteggi.tsv" 'modello|testo|token_entrata' 'haiku|it|581' \
    'haiku|it-doppia|608' 'haiku|en|571' 'haiku|en-doppia|588'
  printf '%s\r\n' "$(cat "${D02}/demo/frase_it.txt")" > "${w}/frase_it.txt"
  run "${D02}/verifica.sh" "${w}"
  expect "M1-D02: i caratteri come li manda \$(cat …), CR compreso" 0 \
    "italiano 2,5 (67/27)"
  tsv "${w}/conteggi.tsv" 'modello|testo|token_entrata' 'haiku|it|581' \
    'haiku|it-doppia|608' 'haiku|en|571' 'haiku|en-doppia|588' \
    'sonnet|it|583' 'sonnet|en|573'
  run "${D02}/verifica.sh" "${w}"
  expect "M1-D02: un modello incompleto non conta" 0 \
    "sonnet: mancano i conteggi di it-doppia, en-doppia: il modello non conta"
  tsv "${w}/conteggi.tsv" 'modello|testo|token_entrata' 'haiku|it|abc' \
    'haiku|it-doppia|608' 'haiku|en|571' 'haiku|en-doppia|588'
  run "${D02}/verifica.sh" "${w}"
  expect "M1-D02: un conteggio che non è un numero non conta" 1 \
    "haiku: mancano i conteggi di it: il modello non conta"
  expect "M1-D02: nessun modello completo" 1 \
    "Nessun modello con i quattro testi it, it-doppia, en, en-doppia."
  tsv "${w}/conteggi.tsv" 'haiku|it|581'
  run "${D02}/verifica.sh" "${w}"
  expect "M1-D02: senza intestazione" 1 \
    "la prima riga deve essere l'intestazione"
  printf '\xef\xbb\xbfmodello\ttesto\ttoken_entrata\r\n' > "${w}/conteggi.tsv"
  printf 'haiku\t%s\t%s\r\n' it 0581 it-doppia 0608 en 571 en-doppia 588 \
    >> "${w}/conteggi.tsv"
  run "${D02}/verifica.sh" "${w}"
  expect_riga "M1-D02: BOM, CRLF e zeri davanti" 0 \
    "haiku: italiano 27 token, inglese 17 (+59 %)"
  printf 'modello\ttesto\ttoken_entrata\nhaiku\tit\t5\xe8\n' \
    > "${w}/conteggi.tsv"
  run "${D02}/verifica.sh" "${w}"
  expect "M1-D02: conteggi.tsv che non è UTF-8, uscita 2" 2 \
    "conteggi.tsv non è un testo UTF-8"
}

# M1-E01: la soluzione, la riga sulla latenza e i JSON rovinati.
t_e01() {
  local w
  ws w "${E01}/esercizio" "${E01}/soluzione"
  run "${E01}/verifica.sh" "${w}"
  expect_fatto "M1-E01: la soluzione passa, l'ultima riga è la frase finale"
  expect_riga "M1-E01: la latenza comparata, non distinguibile" 0 \
    "${LATENZA}"
  expect "M1-E01: e i numeri letti" 0 \
    "opus     5.5 s    1542 token in entrata    393 in uscita"
  ws w "${E01}/esercizio" "${E01}/soluzione"
  json_set "${w}/risposte/opus.json" modelUsage '{"claude-sonnet-5-5": {}}'
  run "${E01}/verifica.sh" "${w}"
  expect "M1-E01: un JSON da un altro modello, uscita 1" 1 \
    "risposte/opus.json viene da claude-sonnet-5-5, non da opus"
  expect_absent "M1-E01: e niente frase finale" "${FATTO}"
  ws w "${E01}/esercizio" "${E01}/soluzione"
  : > "${w}/risposte/haiku.json"
  run "${E01}/verifica.sh" "${w}"
  expect "M1-E01: un JSON vuoto, uscita 1" 1 \
    "risposte/haiku.json non è un JSON valido"
  ws w "${E01}/esercizio" "${E01}/soluzione"
  json_set "${w}/risposte/sonnet.json" is_error true
  run "${E01}/verifica.sh" "${w}"
  expect "M1-E01: un JSON con errore, uscita 1" 1 \
    "risposte/sonnet.json: errore o risposta vuota"
  expect_riga "M1-E01: la riga sulla latenza anche su un esito da sistemare" \
    1 "${LATENZA}"
  ws w "${E01}/esercizio" "${E01}/soluzione"
  json_set "${w}/risposte/opus.json" usage -
  run "${E01}/verifica.sh" "${w}"
  expect "M1-E01: un JSON senza usage, uscita 1" 1 \
    "risposte/opus.json: manca usage, i token"
  ws w "${E01}/esercizio" "${E01}/soluzione"
  printf '{"result": "\xe8"}' > "${w}/risposte/haiku.json"
  run "${E01}/verifica.sh" "${w}"
  expect "M1-E01: un JSON che non è UTF-8, uscita 2" 2 \
    "risposte/haiku.json non è un testo UTF-8"
  ws w "${E01}/esercizio" "${E01}/soluzione"
  # 100000 «[»: RecursionError su ogni python3, dal 3.8 al 3.14
  printf '%100000s' '' | tr ' ' '[' > "${w}/risposte/haiku.json"
  run "${E01}/verifica.sh" "${w}"
  expect "M1-E01: un JSON annidato oltre il limite di Python, uscita 1" 1 \
    "risposte/haiku.json non è un JSON valido"
  ws w "${E01}/esercizio" "${E01}/soluzione"
  sed -i 's/| 1544 |/| 1544² |/' "${w}/confronto.md"
  run "${E01}/verifica.sh" "${w}"
  expect "M1-E01: una cifra in apice non è un numero, uscita 1" 1 \
    "haiku: token in entrata «1544²», nel JSON 1544"
  ws w "${E01}/esercizio" "${E01}/soluzione"
  sed -i "s/| 1544 |/| $(printf '%5000s' '' | tr ' ' 1) |/" \
    "${w}/confronto.md"
  run "${E01}/verifica.sh" "${w}"
  expect "M1-E01: una cella di 5000 cifre non è un numero, uscita 1" 1 \
    "haiku: token in entrata «1111"
  ws w "${E01}/esercizio" "${E01}/soluzione"
  json_set "${w}/risposte/opus.json" duration_ms "1$(printf '%0310d' 0)"
  run "${E01}/verifica.sh" "${w}"
  expect "M1-E01: una durata di 311 cifre, uscita 1" 1 \
    "risposte/opus.json: duration_ms manca o non è un numero"
  ws w "${E01}/esercizio" "${E01}/soluzione"
  json_set "${w}/risposte/opus.json" modelUsage '{"\ud800": {}}'
  run "${E01}/verifica.sh" "${w}"
  expect "M1-E01: un modello con un surrogato isolato, uscita 1" 1 \
    "risposte/opus.json viene da ?, non da opus"
}

# Il file dei risultati che non si legge (2); da root ogni file si legge.
t_illeggibili() {
  local w
  if (( EUID == 0 )); then
    skip "M1-D01: risultati.tsv che non si legge (da root si legge)"
    skip "M1-D02: conteggi.tsv che non si legge (da root si legge)"
    skip "M1-D02: frase_it.txt che non si legge (da root si legge)"
    skip "M1-E01: confronto.md che non si legge (da root si legge)"
    return 0
  fi
  ws w "${D01}/demo" "${D01}/soluzione"
  chmod 000 "${w}/risultati.tsv"
  run "${D01}/verifica.sh" "${w}"
  expect "M1-D01: risultati.tsv che non si legge" 2 \
    "risultati.tsv non si legge"
  ws w "${D02}/demo" "${D02}/soluzione"
  chmod 000 "${w}/conteggi.tsv"
  run "${D02}/verifica.sh" "${w}"
  expect "M1-D02: conteggi.tsv che non si legge" 2 "conteggi.tsv non si legge"
  ws w "${D02}/demo" "${D02}/soluzione"
  chmod 000 "${w}/frase_it.txt"
  run "${D02}/verifica.sh" "${w}"
  expect "M1-D02: frase_it.txt che non si legge" 2 "frase_it.txt non si legge"
  ws w "${E01}/esercizio" "${E01}/soluzione"
  chmod 000 "${w}/confronto.md"
  run "${E01}/verifica.sh" "${w}"
  expect "M1-E01: confronto.md che non si legge" 2 "confronto.md non si legge"
}

# Le uscite che non sono un esito: ogni verifica.sh con il python3 finto,
# che esce 3 o muore di SIGTERM, e ogni verifica.py con un errore che non
# prevede. Escono 2 con un messaggio, mai 1 («non ancora»).
t_uscite() {
  local e w nome
  for e in "${ELEMENTI[@]}"; do
    nome="${e##*/}"
    nome="${nome%%_*}"
    ws w
    run env PATH="${TMP}/python_finto:${PATH}" "${e}/verifica.sh" "${w}"
    expect "${nome}: il controllo esce 3, la verifica esce 2" 2 \
      "${NON_ESITO} 3: un errore, non un esito"
    run env PATH="${TMP}/python_finto:${PATH}" FINTO_PYTHON=segnale \
      "${e}/verifica.sh" "${w}"
    expect "${nome}: il controllo muore di SIGTERM, la verifica esce 2" 2 \
      "${NON_ESITO} 143: un errore, non un esito"
    guasto "${e}/verifica.py" "${w}"
    expect "${nome}: verifica.py, un errore che non prevede, uscita 2" 2 \
      "verifica.py: errore inatteso del controllo (ZeroDivisionError"
  done
}

# Le precondizioni dei tre live.sh: uscita 2, e claude mai chiamato.
t_live_precondizioni() {
  local w
  live "${D01}" "${TMP}/assente"
  expect "M1-D01 live.sh: spazio di lavoro assente" 2 \
    "spazio di lavoro assente"
  nessuna_chiamata "M1-D01 live.sh: spazio assente, claude mai chiamato"
  ws w "${D01}/demo"
  live "${D01}" "${w}" PN_RIPETIZIONI=0
  expect "M1-D01 live.sh: PN_RIPETIZIONI fuori misura" 2 \
    "PN_RIPETIZIONI va da 1 a 20"
  nessuna_chiamata "M1-D01 live.sh: PN_RIPETIZIONI, claude mai chiamato"
  rm -f -- "${w}/frase.txt"
  live "${D01}" "${w}"
  expect "M1-D01 live.sh: manca frase.txt" 2 "frase.txt"
  nessuna_chiamata "M1-D01 live.sh: frase.txt, claude mai chiamato"
  ws w "${D01}/demo"
  live "${D01}" "${w}" HANDSON_PERMISSION_MODE=nessuna
  expect "M1-D01 live.sh: modalità di permesso non ammessa" 2 \
    "modalità di permesso non ammessa"
  solo_versione "M1-D01 live.sh: modalità di permesso, nessun prompt"
  live "${D02}" "${TMP}/assente"
  expect "M1-D02 live.sh: spazio di lavoro assente" 2 \
    "spazio di lavoro assente"
  nessuna_chiamata "M1-D02 live.sh: spazio assente, claude mai chiamato"
  ws w "${D02}/demo"
  live "${D02}" "${w}" PN_MODELLI=fable
  expect "M1-D02 live.sh: un modello non ammesso" 2 \
    "modello non ammesso in PN_MODELLI"
  nessuna_chiamata "M1-D02 live.sh: PN_MODELLI, claude mai chiamato"
  rm -f -- "${w}/frase_en.txt"
  live "${D02}" "${w}"
  expect "M1-D02 live.sh: manca frase_en.txt" 2 "frase_en.txt"
  nessuna_chiamata "M1-D02 live.sh: frase_en.txt, claude mai chiamato"
  ws w "${D02}/demo"
  live "${D02}" "${w}" HANDSON_PERMISSION_MODE=nessuna
  expect "M1-D02 live.sh: modalità di permesso non ammessa" 2 \
    "modalità di permesso non ammessa"
  solo_versione "M1-D02 live.sh: modalità di permesso, nessun prompt"
  live "${E01}" "${TMP}/assente"
  expect "M1-E01 live.sh: spazio di lavoro assente" 2 \
    "spazio di lavoro assente"
  nessuna_chiamata "M1-E01 live.sh: spazio assente, claude mai chiamato"
  ws w "${E01}/esercizio"
  live "${E01}" "${w}" PN_PROMPT=prompt/altro.md
  expect "M1-E01 live.sh: un prompt non ammesso" 2 "PN_PROMPT non ammesso"
  nessuna_chiamata "M1-E01 live.sh: PN_PROMPT, claude mai chiamato"
  rm -f -- "${w}/confronto.md"
  live "${E01}" "${w}"
  expect "M1-E01 live.sh: manca confronto.md" 2 "confronto.md"
  nessuna_chiamata "M1-E01 live.sh: confronto.md, claude mai chiamato"
  ws w "${E01}/esercizio"
  live "${E01}" "${w}" HANDSON_PERMISSION_MODE=nessuna
  expect "M1-E01 live.sh: modalità di permesso non ammessa" 2 \
    "modalità di permesso non ammessa"
  solo_versione "M1-E01 live.sh: modalità di permesso, nessun prompt"
}

# M1-D01 e M1-D02 dal vivo con il claude esca, poi la loro verifica.sh: i
# file che live.sh scrive sono quelli che la verifica legge.
t_live_dal_vivo() {
  local w
  ws w "${D01}/demo"
  live "${D01}" "${w}" PN_RIPETIZIONI=2 ESCA_MODO=parole
  expect "M1-D01 live.sh: due chiamate per modello, uscita 0" 0 "ritardo"
  run "${D01}/verifica.sh" "${w}"
  expect_riga "M1-D01: dal vivo, due parole diverse: confermata" 0 \
    "${VARIA} (opus): confermata"
  expect_fatto "M1-D01: dal vivo, la frase finale"
  ws w "${D02}/demo"
  live "${D02}" "${w}" ESCA_MODO=token
  expect "M1-D02 live.sh: quattro chiamate, la sua verifica.sh è OK" 0 \
    "VERIFICA OK   le due affermazioni (verifica.sh)"
  run "${D02}/verifica.sh" "${w}"
  expect_riga "M1-D02: dal vivo, i caratteri per token: confermata" 0 \
    "${CARATTERI} (haiku): confermata"
  expect_fatto "M1-D02: dal vivo, la frase finale"
  ws w "${D02}/demo"
  live "${D02}" "${w}" ESCA_MODO=token_inglese
  expect "M1-D02 live.sh: l'inglese pesa di più, la prova esce 0" 0 \
    "VERIFICA OK   le due affermazioni (verifica.sh)"
  expect "M1-D02 live.sh: e il confronto con la registrazione, no" 0 \
    "${CONFRONTO} no"
}

t_shellcheck() {
  local f
  for f in "${D01}/verifica.sh" "${D02}/verifica.sh" "${E01}/verifica.sh" \
      "${SELF}"; do
    run shellcheck -x -- "${f}"
    if (( RC == 0 )) && [[ -z "${OUT}" ]]; then
      pass "shellcheck ${f#"${MOD}"/}"
    else
      fail "shellcheck ${f#"${MOD}"/}: ${OUT:0:300}"
    fi
  done
}

main() {
  local t e
  for t in jq python3 shellcheck; do
    if ! command -v "${t}" > /dev/null 2>&1; then
      echo "test_m1_d01_d02_e01.sh: manca lo strumento ${t}" >&2
      exit 2
    fi
  done
  for e in "${ELEMENTI[@]}"; do
    if [[ ! -d "${e}" ]]; then
      echo "test_m1_d01_d02_e01.sh: manca la cartella ${e#"${MOD}"/}" >&2
      exit 2
    fi
  done
  TMP="$(mktemp -d)" || { echo "mktemp non riesce" >&2; exit 2; }
  readonly TMP
  trap 'rm -rf -- "${TMP}"' EXIT
  unset ANTHROPIC_API_KEY HANDSON_ENV HANDSON_PERMISSION_MODE \
    HANDSON_SHOW_CMD HANDSON_NO_PAUSE PN_RIPETIZIONI PN_MODELLI PN_PROMPT \
    ESCA_MODO ESCA_LOG FINTO_PYTHON
  claude_esca
  python_finto
  echo "test_m1_d01_d02_e01.sh"
  t_base
  t_d01_verdetti
  t_d01_casi
  t_d01_righe
  t_d02_verdetti
  t_d02_casi
  t_e01
  t_illeggibili
  t_uscite
  t_live_precondizioni
  t_live_dal_vivo
  t_shellcheck
  echo "PASS=${PASS} FAIL=${FAIL} SKIP=${SKIP}"
  if (( PASS + FAIL + SKIP != CASES )); then
    echo "test_m1_d01_d02_e01.sh: $((PASS + FAIL + SKIP)) prove, attese" \
      "${CASES}: una prova manca" >&2
    exit 2
  fi
  (( FAIL == 0 )) || exit 1
}

main "$@"
