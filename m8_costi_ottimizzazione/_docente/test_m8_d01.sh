#!/bin/bash
#
# test_m8_d01.sh -- le prove di M8-D01 «Quanti token pesa una frase», per il
# docente:
#   - l'elemento: i due testi, i file e i bit di esecuzione; il README con le
#     dieci sezioni, le frasi di Anthropic con il loro indirizzo, il corpo
#     della richiesta mostrato uguale a quello costruito dallo script; niente
#     identificativi interni, «smentita» o riferimenti alla giornata;
#   - prepara_esercizio.sh e verifica.sh sul punto di partenza (1);
#   - controlla_conteggi.py su risposte del curl finto: tutto a posto, i
#     conteggi che mancano o non sono interi positivi, gli errori HTTP, le
#     risposte che sono messaggi (0/1), i file che non si leggono (2), mai
#     un traceback;
#   - verifica.sh: il controllo dell'elemento, mai quello dello spazio di
#     lavoro; le precondizioni (2);
#   - demo/chiama.sh e _docente/live.sh con il curl finto: l'URL, le
#     intestazioni, un corpo per testo, la chiave che passa sullo STDIN e mai
#     fra gli argomenti, nell'output o nei file; i file dati al posto dei due
#     testi; le precondizioni (2, nessuna chiamata: l'esca); curl che fallisce
#     (1), senza file a metà;
#   - shellcheck -x sugli script e su questo file.
# Mai il curl vero e mai una chiave vera: il finto e l'esca stanno davanti nel
# PATH, e la suite lo controlla prima di usarli. Gli spazi di lavoro nascono in
# una cartella temporanea: l'albero del repository non cambia. CASES è il
# numero dei casi: se ne girano di più o di meno la suite esce 2.
#
# Uso:    m8_costi_ottimizzazione/_docente/test_m8_d01.sh
# Uscita: 0 = tutti i casi passano · 1 = almeno un caso fallito · 2 =
#         precondizione (manca python3, git o shellcheck), o un numero di casi
#         diverso da CASES
set -uo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly MOD="${SELF%/_docente/*}"
readonly RADICE="${MOD%/*}"
D01="${MOD}/s6_costi_e_ottimizzazione/m8_3_il_conto_in_token"
D01+="/M8-D01_quanti_token"
readonly D01
readonly FINTO_PY="${MOD}/_docente/curl_finto_m8_d01.py"
# La libreria del repository, per la base dei file temporanei.
# shellcheck source=../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"
readonly CASES=125
# Una stringa da chiave finta: la suite controlla che non compaia mai.
readonly CHIAVE='chiave-finta_di-prova-0123456789'
FRASE_IT='La connessione cade ogni sera verso le nove: potete controllare'
FRASE_IT+=' la linea?'
readonly FRASE_IT
FRASE_EN='The connection drops every evening around nine: can you check'
FRASE_EN+=' the line?'
readonly FRASE_EN
readonly URL='https://api.anthropic.com/v1/messages/count_tokens'
readonly FATTO='Fatto: ogni testo ha il suo conteggio; la tabella è qui sopra.'
# I conteggi inventati del finto per le due frasi (curl_finto_m8_d01.py).
readonly TOKEN_IT=23
readonly TOKEN_EN=21
TMP=''
PASS=0
FAIL=0
RC=0
OUT=''
TUTTO=''

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

# Esegue un comando; RC e OUT (STDOUT e STDERR insieme) per expect; OUT si
# aggiunge a TUTTO, dove alla fine non devono esserci la chiave né traceback.
run() { OUT="$("$@" 2>&1)"; RC=$?; TUTTO+="${OUT}"$'\n'; }

# Uscita attesa E parola chiave attesa (RU-01.T3).
expect() {
  if (( RC == $2 )) && grep -qF -- "$3" <<< "${OUT}"; then
    pass "$1"
  else
    fail "$1 (rc=${RC}, attesa $2, parola «$3»): ${OUT:0:600}"
  fi
}

# Nessun falso positivo: la parola NON c'è (RU-01.T5).
expect_absent() {
  if grep -qF -- "$2" <<< "${OUT}"; then
    fail "$1: «$2» c'è: ${OUT:0:400}"
  else
    pass "$1"
  fi
}

vero() {
  local nome="$1"
  shift
  if "$@"; then pass "${nome}"; else fail "${nome}"; fi
}

# Uno spazio di lavoro nuovo in una radice nuova. Arguments: $1 la variabile.
nuovo_ws() {
  local __r
  __r="$(mktemp -d "${TMP}/radice.XXXXXX")" || exit 2
  "${RADICE}/tools/prepara_esercizio.sh" M8-D01 --radice "${__r}" \
    > "${TMP}/prepara.log" 2>&1 || return 1
  printf -v "$1" '%s' "${__r}/M8-D01"
}

# Uno spazio di lavoro nuovo in una cartella data (non deve esistere).
# Arguments: $1 la cartella che diventa lo spazio di lavoro.
nuovo_ws_in() {
  local __r
  __r="$(mktemp -d "${TMP}/radice.XXXXXX")" || exit 2
  "${RADICE}/tools/prepara_esercizio.sh" M8-D01 --radice "${__r}" \
    > "${TMP}/prepara.log" 2>&1 || return 1
  mv -- "${__r}/M8-D01" "$1" || return 1
}

# Il curl finto, l'esca (un curl che registra soltanto) e i PATH ridotti. Esce
# 2 se nel PATH di prova curl non è il finto.
prepara_curl() {
  local t
  mkdir -p "${TMP}/finto" "${TMP}/esca" "${TMP}/senza_curl" \
    "${TMP}/senza_python" || exit 2
  cp -- "${FINTO_PY}" "${TMP}/finto/curl" || exit 2
  # shellcheck disable=SC2016  # il corpo è dell'esca
  printf '%s\n' '#!/bin/bash' \
    'printf "invocazione %s\n" "$*" >> "${ESCA_LOG}"' \
    > "${TMP}/esca/curl" || exit 2
  chmod 755 "${TMP}/finto/curl" "${TMP}/esca/curl" || exit 2
  for t in readlink git python3 mktemp cat dirname mkdir rm rmdir sed cp; do
    ln -s "$(command -v "${t}")" "${TMP}/senza_curl/${t}" || exit 2
  done
  for t in readlink git curl mktemp cat dirname mkdir rm rmdir sed cp; do
    ln -s "$(command -v "${t}")" "${TMP}/senza_python/${t}" || exit 2
  done
  t="$(PATH="${TMP}/finto:${PATH}" command -v curl)"
  if [[ "${t}" != "${TMP}/finto/curl" ]]; then
    echo "test_m8_d01: nel PATH di prova curl è ${t}, non il finto" >&2
    exit 2
  fi
}

# Lo script con il curl finto davanti nel PATH e la chiave finta nell'ambiente;
# il registro riparte vuoto. Arguments: $1 lo script, $2 lo spazio di lavoro,
# poi NOME=valore fino a «--», poi i file da contare (facoltativi).
finto() {
  local script="$1" w="$2"
  local -a variabili=()
  shift 2
  while (( $# > 0 )) && [[ "$1" != -- ]]; do
    variabili+=("$1")
    shift
  done
  if (( $# > 0 )); then
    shift
  fi
  : > "${TMP}/finto.log"
  run env PATH="${TMP}/finto:${PATH}" HANDSON_NO_PAUSE=1 \
    ANTHROPIC_API_KEY="${CHIAVE}" FINTO_LOG="${TMP}/finto.log" \
    TMPDIR="${TMP}" ${variabili[@]+"${variabili[@]}"} "${script}" "${w}" "$@"
}

# chiama.sh con i file dati e l'esca davanti nel PATH: per le precondizioni
# dei file (il registro va azzerato da chi chiama). Arguments: i file.
esca_con_file() {
  run env PATH="${TMP}/esca:${PATH}" HANDSON_NO_PAUSE=1 \
    ANTHROPIC_API_KEY="${CHIAVE}" ESCA_LOG="${TMP}/esca.log" TMPDIR="${TMP}" \
    "${D01}/demo/chiama.sh" "${TMP}/ws_precondizioni" "$@"
}

# Lo script con l'esca davanti nel PATH (o un PATH dato), senza chiave se non
# è data. Arguments: $1 lo script, $2 lo spazio di lavoro, $3 facoltativo il
# PATH, poi le variabili NOME=valore.
esca() {
  local script="$1" w="$2" percorso="${3:-${TMP}/esca:${PATH}}"
  shift 2
  (( $# == 0 )) || shift
  : > "${TMP}/esca.log"
  run env -u ANTHROPIC_API_KEY PATH="${percorso}" HANDSON_NO_PAUSE=1 \
    ESCA_LOG="${TMP}/esca.log" "$@" "${script}" "${w}"
}

# Una precondizione: uscita 2, la parola attesa, nessuna chiamata di curl.
precondizione() {
  local nome="$1" parola="$2" n
  shift 2
  esca "$@"
  expect "${nome}" 2 "${parola}"
  n="$(grep -c -- 'invocazione' "${TMP}/esca.log")"
  if (( n == 0 )); then
    pass "${nome}: nessuna chiamata di curl"
  else
    fail "${nome}: ${n} chiamate"
  fi
}

# Le chiamate di un registro del finto, contro le attese: una per testo, nel
# giusto ordine, l'URL, le intestazioni, la chiave che arriva dallo STDIN.
# Arguments: $1 il registro, poi i nomi dei testi, poi «--», poi i testi.
controlla_chiamate() {
  local log="$1"
  shift
  run python3 -B -I - "${log}" "${URL}" "$@" <<'PY'
import json, sys
log, url, *resto = sys.argv[1:]
cut = resto.index("--")
nomi, testi = resto[:cut], resto[cut + 1:]
righe = [json.loads(r) for r in open(log, encoding="utf-8")]
problemi = []
if len(righe) != len(nomi):
    problemi.append("%d chiamate invece di %d" % (len(righe), len(nomi)))
for numero, c in enumerate(righe):
    if numero >= len(nomi):
        break
    argv = c.get("argv", [])
    nome = nomi[numero]
    for coppia in (["--request", "POST"], ["--config", "-"],
                   ["--header", "anthropic-version: 2026-10-21"],
                   ["--header", "content-type: application/json"],
                   ["--data-binary", "@risposte/%s.richiesta.json" % nome],
                   ["--output", "risposte/%s.json" % nome]):
        if not any(argv[i:i + 2] == coppia for i in range(len(argv) - 1)):
            problemi.append("%s: manca %s" % (nome, coppia))
    if c.get("url") != [url]:
        problemi.append("%s: l'URL: %s" % (nome, c.get("url")))
    if c.get("chiave_in_argv"):
        problemi.append("%s: la chiave negli argomenti" % nome)
    if not c.get("config_bearer"):
        problemi.append("%s: la chiave non arriva sulla configurazione via "
                        "STDIN" % nome)
    if not c.get("stdin_config"):
        problemi.append("%s: --config - senza STDIN" % nome)
    corpo = c.get("corpo") or {}
    attesa = {"model": "claude-haiku-5-5",
              "messages": [{"role": "user", "content": testi[numero]}]}
    if corpo != attesa:
        problemi.append("%s: il corpo è %r" % (nome, corpo))
print("; ".join(problemi) or "chiamate giuste")
PY
}

# --- L'elemento -------------------------------------------------------------

t_elemento() {
  local f
  for f in README.md verifica.sh demo/testi/frase-it.txt \
      demo/testi/frase-en.txt demo/chiama.sh demo/controlla_conteggi.py \
      _docente/live.sh soluzione/LEGGIMI.md; do
    vero "elemento: ${f}" test -f "${D01}/${f}"
  done
  for f in verifica.sh _docente/live.sh demo/chiama.sh; do
    vero "elemento: ${f} eseguibile" test -x "${D01}/${f}"
  done
  run python3 -B -I - "${D01}/demo/testi" "${FRASE_IT}" "${FRASE_EN}" <<'PY'
import os, sys
d, it, en = sys.argv[1:]
leggi = lambda n: open(os.path.join(d, n), encoding="utf-8").read()
ok = leggi("frase-it.txt") == it + "\n" and leggi("frase-en.txt") == en + "\n"
print("frasi a posto" if ok else "le frasi non sono quelle attese")
PY
  expect "i due testi: la frase italiana e la sua traduzione" 0 "frasi a posto"
}

t_readme() {
  run python3 -B -I - "${D01}" <<'PY'
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
for titolo in ("## Punto di partenza (tools/prepara_esercizio.sh M8-D01)",
               "## Verifica (tools/verifica.sh M8-D01)"):
    if titolo not in readme:
        problemi.append("il titolo «%s»" % titolo)
OV = "https://platform.claude.com/docs/en/api/overview"
TC = "https://platform.claude.com/docs/en/build-with-claude/token-counting"
CT = "https://platform.claude.com/docs/en/api/messages/count_tokens"
PRO = "https://support.claude.com/en/articles/8325606-what-is-the-pro-plan"
frasi = [
    ("Count tokens in a message before sending to manage costs and rate "
     "limits (POST /v1/messages/count_tokens)", OV),
    ("accepts the same structured list of inputs for creating a message, "
     "including support for system prompts, tools, images, and PDFs", TC),
    ("can be used to count the number of tokens in a Message, including "
     "tools, images, and documents, without creating it", CT),
    ("The token count is an estimate. … the actual number of input tokens "
     "used when creating a message might differ by a small amount.", TC),
    ("Token counting is free to use but subject to requests per minute "
     "rate limits based on your usage tier.", TC),
    ("token counting provides an estimate without using caching logic … "
     "prompt caching only occurs during actual message creation.", TC),
    ("Bearer <token>, where <token> is your API key … Legacy fallback for "
     "Authorization, still supported", OV),
    ("anthropic-version | API version (for example, 2026-10-21) | Yes … "
     "content-type | application/json | Yes", OV),
    ("The Pro plan is a paid plan for our Claude chat experience. … The "
     "Pro plan does not include API usage through the Claude Console.", PRO),
]
piano = " ".join(readme.split())
for frase, url in frasi:
    if " ".join(frase.split()) not in piano:
        problemi.append("manca «%s»" % frase[:50])
    if url not in readme:
        problemi.append("manca %s" % url)
if "https://platform.claude.com/docs/en/models/overview" not in readme:
    problemi.append("manca la pagina dei modelli")
frase_it = "La connessione cade ogni sera verso le nove: potete controllare " \
    "la linea?"
attesa = {"model": "claude-haiku-5-5",
          "messages": [{"role": "user", "content": frase_it}]}
blocco = re.search(r"```json\n(.*?)```", readme, re.S)
import json as _json
if not blocco or _json.loads(blocco.group(1)) != attesa:
    problemi.append("il blocco JSON non è il corpo della frase italiana")
for vietata in ("smentit", "FACT-", "M8-X", "X-3", "/home/", "sk-ant-"):
    if vietata in readme:
        problemi.append("«%s»" % vietata)
for parola in ("oggi", "domani", "pausa", "pranzo"):
    if re.search(r"\b%s\b" % parola, readme):
        problemi.append("«%s»" % parola)
print("; ".join(problemi) or "README a posto")
PY
  expect "README: sezioni, frasi con l'indirizzo, corpo, niente di vietato" \
    0 "README a posto"
}

t_prepara() {
  local ws f
  if ! nuovo_ws ws; then
    fail "prepara_esercizio.sh M8-D01: $(tail -n 3 "${TMP}/prepara.log")"
    return
  fi
  pass "prepara_esercizio.sh M8-D01"
  for f in testi/frase-it.txt testi/frase-en.txt chiama.sh \
      controlla_conteggi.py .claude/settings.json; do
    vero "spazio di lavoro: ${f}" test -f "${ws}/${f}"
  done
  if [[ ! -e "${ws}/soluzione" && ! -e "${ws}/_docente" ]]; then
    pass "spazio di lavoro: niente soluzione/ né _docente/"
  else
    fail "spazio di lavoro: soluzione/ o _docente/"
  fi
  run "${RADICE}/tools/verifica.sh" M8-D01 --radice "${ws%/M8-D01}"
  expect "verifica.sh sul punto di partenza: 1" 1 \
    "Manca la cartella risposte/"
}

# --- Il controllo -----------------------------------------------------------

# Scrive in una cartella i tre file di un testo, con il curl finto.
# Arguments: $1 la cartella, $2 il nome, $3 il testo, poi NOME=valore.
un_testo() {
  local c="$1" nome="$2" testo="$3"
  shift 3
  python3 -B -I - "${c}/${nome}.richiesta.json" "${testo}" <<'PY' \
    || { echo "test_m8_d01: non scrivo il corpo" >&2; exit 2; }
import json, sys
percorso, testo = sys.argv[1:]
with open(percorso, "w", encoding="utf-8") as fh:
    json.dump({"model": "claude-haiku-5-5",
               "messages": [{"role": "user", "content": testo}]},
              fh, ensure_ascii=False)
PY
  ( cd "${c}" && env "$@" FINTO_LOG="" python3 -B -I "${FINTO_PY}" --silent \
      --data-binary "@${nome}.richiesta.json" --output "${nome}.json" \
      --write-out '%{http_code}\n' "${URL}" > "${nome}.stato" ) \
    || { echo "test_m8_d01: il finto non scrive" >&2; exit 2; }
}

# Una cartella con le due frasi della demo.
# Arguments: $1 la variabile da assegnare, poi NOME=valore per il finto.
due_frasi() {
  local __c v="$1"
  __c="$(mktemp -d "${TMP}/risp.XXXXXX")" || exit 2
  shift
  un_testo "${__c}" frase-it "${FRASE_IT}" "$@"
  un_testo "${__c}" frase-en "${FRASE_EN}" "$@"
  printf -v "${v}" '%s' "${__c}"
}

controlla() { run python3 -B -I "${D01}/demo/controlla_conteggi.py" "$@"; }

t_controllo() {
  local c
  due_frasi c
  controlla "${c}"
  expect "controllo: i due conteggi, 0" 0 "${FATTO}"
  expect "controllo: la riga della frase italiana" 0 \
    "frase-it         73            ${TOKEN_IT}"
  expect "controllo: la riga della frase inglese" 0 \
    "frase-en         71            ${TOKEN_EN}"
  expect "controllo: la differenza fra le due lingue, una misura" 0 \
    "italiano ${TOKEN_IT} token su 73 caratteri, inglese ${TOKEN_EN} su 71"
  expect "controllo: la differenza è un dato, nessun verdetto" 0 \
    "+2 token. Una misura, nessun verdetto."
  expect "controllo: il modello, come dato" 0 \
    "(dato) modello della richiesta: claude-haiku-5-5"
  expect "controllo: nessun messaggio creato" 0 \
    "contare non ha creato un messaggio"
  expect_absent "controllo: nessun traceback" "Traceback"
  c="$(mktemp -d "${TMP}/risp.XXXXXX")" || exit 2
  un_testo "${c}" v0 "Un prompt piuttosto lungo per il laboratorio."
  un_testo "${c}" v1 "Un prompt corto."
  controlla "${c}"
  expect "controllo: altri file, solo la tabella, 0" 0 "${FATTO}"
  expect "controllo: altri file, la loro riga" 0 "v0"
  expect_absent "controllo: altri file, nessuna differenza IT/EN" "italiano"
}

t_conteggi() {
  local c
  due_frasi c
  rm -f -- "${c}/frase-en.json"
  controlla "${c}"
  expect "un conteggio che manca: niente corpo, 1" 1 \
    "frase-en: manca frase-en.json"
  due_frasi c
  rm -f -- "${c}/frase-it.stato"
  controlla "${c}"
  expect "un conteggio che manca: niente stato, 1" 1 \
    "frase-it: manca frase-it.stato"
  due_frasi c
  rm -f -- "${c}/frase-en.richiesta.json" "${c}/frase-en.json" \
    "${c}/frase-en.stato"
  controlla "${c}"
  expect "una frase senza l'altra, 1" 1 "Delle due frasi della demo manca una"
  c="$(mktemp -d "${TMP}/risp.XXXXXX")" || exit 2
  controlla "${c}"
  expect "una cartella senza testi, 1" 1 "nessun testo contato"
  due_frasi c FINTO_CORPO=senza
  controlla "${c}"
  expect "input_tokens che non c'è, 1" 1 "input_tokens non è un intero positivo"
  due_frasi c FINTO_CORPO=zero
  controlla "${c}"
  expect "input_tokens 0, 1" 1 "input_tokens non è un intero positivo: 0"
  due_frasi c FINTO_CORPO=negativo
  controlla "${c}"
  expect "input_tokens negativo, 1" 1 \
    "input_tokens non è un intero positivo: -3"
  due_frasi c FINTO_CORPO=stringa
  controlla "${c}"
  expect "input_tokens non numerico, 1" 1 \
    "input_tokens non è un intero positivo: '20'"
  due_frasi c FINTO_CORPO=messaggio
  controlla "${c}"
  expect "una risposta che è un messaggio, 1" 1 \
    "è un messaggio, non un conteggio"
  expect "una risposta che è un messaggio: i campi" 1 \
    "id, content, stop_reason, usage"
  due_frasi c FINTO_STATO=401 FINTO_CORPO=errore \
    "FINTO_CHIAVE=sk-""ant-chiave-che-non-esiste"
  controlla "${c}"
  expect "uno stato 401, 1" 1 "lo stato HTTP è 401, non 200"
  expect "uno stato 401: il tipo dell'errore" 1 "authentication_error"
  expect "uno stato 401: una chiave nel messaggio, mascherata" 1 "<chiave>"
  expect_absent "uno stato 401: la chiave dell'errore non si stampa" "sk-""ant-"
}

t_illeggibili() {
  local c
  due_frasi c
  printf 'ottimo\n' > "${c}/frase-it.stato" || exit 2
  controlla "${c}"
  expect "uno stato che non è un numero, 2" 2 "non è un numero"
  due_frasi c FINTO_CORPO=rotto
  controlla "${c}"
  expect "un corpo che non è JSON, 2" 2 "non si legge come JSON"
  due_frasi c
  printf '[1, 2]\n' > "${c}/frase-it.json" || exit 2
  controlla "${c}"
  expect "un JSON che non è un oggetto, 2" 2 "non è un oggetto JSON"
  due_frasi c
  printf '{rotto\n' > "${c}/frase-en.richiesta.json" || exit 2
  controlla "${c}"
  expect "una richiesta che non è JSON, 2" 2 "non si legge come JSON"
  due_frasi c
  printf '{"model": "x"}\n' > "${c}/frase-en.richiesta.json" || exit 2
  controlla "${c}"
  expect "una richiesta senza messaggi, 2" 2 "non è il corpo di una richiesta"
  controlla "${TMP}/non-c-e"
  expect "uso: una cartella che non c'è, 2" 2 "non c'è"
  controlla
  expect "uso: senza argomenti, 2" 2 "Uso:"
  controlla --aiuto
  expect "uso: un'opzione, 2" 2 "Uso:"
}

t_verifica() {
  local ws
  nuovo_ws ws || { fail "verifica: prepara_esercizio.sh"; return; }
  run "${D01}/verifica.sh" "${ws}"
  expect "verifica: senza risposte/, 1" 1 "Manca la cartella risposte/"
  mkdir -p "${ws}/risposte" || exit 2
  run "${D01}/verifica.sh" "${ws}"
  expect "verifica: risposte/ vuota, 1" 1 "nessun testo contato"
  un_testo "${ws}/risposte" frase-it "${FRASE_IT}"
  un_testo "${ws}/risposte" frase-en "${FRASE_EN}"
  printf 'print("CONTROLLO FINTO")\n' > "${ws}/controlla_conteggi.py" || exit 2
  run env PN_HANDSON_ROOT="${RADICE}" "${D01}/verifica.sh" "${ws}"
  expect "verifica: i conteggi del finto, 0, «Fatto»" 0 "${FATTO}"
  expect_absent "verifica: il controllo dell'elemento, non della copia" \
    "CONTROLLO FINTO"
  rm -f -- "${ws}/risposte/frase-it.json"
  run "${D01}/verifica.sh" "${ws}"
  expect "verifica: un conteggio che manca, 1" 1 "manca frase-it.json"
  run "${D01}/verifica.sh"
  expect "verifica: senza argomenti, 2" 2 "spazio di lavoro assente"
}

# --- chiama.sh e live.sh ----------------------------------------------------

t_chiama() {
  local ws
  nuovo_ws ws || { fail "chiama: prepara_esercizio.sh"; return; }
  finto "${D01}/demo/chiama.sh" "${ws}"
  expect "chiama: 0, il controllo ha letto i conteggi" 0 \
    "VERIFICA OK   i conteggi, in risposte/"
  expect "chiama: il comando curl sullo schermo" 0 "--config -"
  expect "chiama: l'URL sullo schermo" 0 "${URL}"
  expect "chiama: la tabella" 0 "${FATTO}"
  expect "chiama: il testo sullo schermo" 0 "${FRASE_IT}"
  expect_absent "chiama: la chiave non si stampa" "${CHIAVE}"
  controlla_chiamate "${TMP}/finto.log" frase-it frase-en -- \
    "${FRASE_IT}" "${FRASE_EN}"
  expect "chiama: URL, intestazioni, corpi, chiave via STDIN, in ordine" 0 \
    "chiamate giuste"
  vero "chiama: lo stato della frase inglese" \
    test -s "${ws}/risposte/frase-en.stato"
  vero "chiama: la risposta della frase inglese" \
    test -s "${ws}/risposte/frase-en.json"
  run grep -rlF -- "${CHIAVE}" "${ws}"
  if (( RC == 1 )); then
    pass "chiama: la chiave in nessun file dello spazio di lavoro"
  else
    fail "chiama: la chiave è in: ${OUT}"
  fi
  run git -C "${ws}" status --porcelain
  if [[ "${OUT}" == '?? risposte/' ]]; then
    pass "chiama: lo spazio di lavoro cambia solo in risposte/"
  else
    fail "chiama: git status «${OUT}»"
  fi
  run env PN_HANDSON_ROOT="${RADICE}" "${D01}/verifica.sh" "${ws}"
  expect "chiama: poi verifica.sh, 0" 0 "${FATTO}"
  finto "${D01}/demo/chiama.sh" "${ws}"
  expect "chiama: lo stesso testo una seconda volta, 2" 2 "c'è già"
  vero "chiama: una seconda volta, nessuna chiamata" \
    test ! -s "${TMP}/finto.log"
}

t_file_dati() {
  local ws dove="${TMP}/prompt" rel
  nuovo_ws ws || { fail "file dati: prepara_esercizio.sh"; return; }
  mkdir -p "${dove}" || exit 2
  printf 'Il prompt v0, intero.\n\n\n' > "${dove}/v0.md" || exit 2
  printf 'Il prompt v1.\n' > "${dove}/v1.md" || exit 2
  rel="${dove}/v1.md"
  cd "${TMP}" || exit 2
  finto "${D01}/demo/chiama.sh" "${ws}" -- "prompt/v0.md" "${rel}"
  cd "${RADICE}" || exit 2
  expect "file dati: uno relativo e uno assoluto, 0" 0 "${FATTO}"
  run python3 -B -I - "${TMP}/finto.log" <<'PY'
import json, sys
righe = [json.loads(r) for r in open(sys.argv[1], encoding="utf-8")]
ok = [r["corpo"]["messages"][0]["content"] for r in righe] == [
    "Il prompt v0, intero.", "Il prompt v1."]
print("file dati giusti" if ok else "corpi: %r" % [r["corpo"] for r in righe])
PY
  expect "file dati: i due file, in ordine, senza gli a capo finali" 0 \
    "file dati giusti"
  vero "file dati: risposte/v0.json" test -s "${ws}/risposte/v0.json"
  vero "file dati: risposte/v1.stato" test -s "${ws}/risposte/v1.stato"
  run test -e "${ws}/risposte/frase-it.json"
  if (( RC != 0 )); then
    pass "file dati: i due testi della demo non si contano"
  else
    fail "file dati: frase-it.json c'è"
  fi
  controlla "${ws}/risposte"
  expect "file dati: la tabella" 0 "${FATTO}"
  expect_absent "file dati: nessuna differenza IT/EN" "italiano"
}

t_live() {
  local ws
  nuovo_ws ws || { fail "live: prepara_esercizio.sh"; return; }
  finto "${D01}/_docente/live.sh" "${ws}"
  expect "live: 0" 0 "VERIFICA OK   verifica.sh dell'elemento"
  expect_absent "live: la chiave non si stampa" "${CHIAVE}"
  controlla_chiamate "${TMP}/finto.log" frase-it frase-en -- \
    "${FRASE_IT}" "${FRASE_EN}"
  expect "live: due chiamate, quelle giuste" 0 "chiamate giuste"
  run "${RADICE}/tools/verifica.sh" M8-D01 --radice "${ws%/M8-D01}"
  expect "live: poi tools/verifica.sh, 0" 0 "VERIFICA OK   M8-D01: fatto."
  run "${D01}/_docente/live.sh"
  expect "live: senza argomenti, 2" 2 "uso:"
  nuovo_ws ws || { fail "live: prepara_esercizio.sh"; return; }
  : > "${TMP}/esca.log"
  run env -u ANTHROPIC_API_KEY PATH="${TMP}/esca:${PATH}" \
    ESCA_LOG="${TMP}/esca.log" "${D01}/_docente/live.sh" "${ws}"
  expect "live: senza la chiave, 2" 2 "ANTHROPIC_API_KEY non è impostata"
  vero "live: senza la chiave, nessuna chiamata di curl" \
    test ! -s "${TMP}/esca.log"
}

t_precondizioni() {
  local ws s="${D01}/demo/chiama.sh"
  nuovo_ws ws || { fail "precondizioni: prepara_esercizio.sh"; return; }
  precondizione "precondizione: nessuna chiave" \
    "ANTHROPIC_API_KEY non è impostata" "${s}" "${ws}"
  precondizione "precondizione: nessuno spazio di lavoro" \
    "spazio di lavoro assente" "${s}" ""
  precondizione "precondizione: una cartella che non è lo spazio" \
    "non è lo spazio di lavoro di M8-D01" "${s}" "${TMP}" \
    "${TMP}/esca:${PATH}" ANTHROPIC_API_KEY="${CHIAVE}"
  precondizione "precondizione: una chiave con caratteri strani" \
    "non si possono" "${s}" "${ws}" "${TMP}/esca:${PATH}" \
    'ANTHROPIC_API_KEY=con"apice'
  precondizione "precondizione: senza curl" "manca lo strumento: curl" \
    "${s}" "${ws}" "${TMP}/senza_curl" ANTHROPIC_API_KEY="${CHIAVE}"
  precondizione "precondizione: senza python3" "manca lo strumento: python3" \
    "${s}" "${ws}" "${TMP}/senza_python" ANTHROPIC_API_KEY="${CHIAVE}"
  precondizione "precondizione: senza tools/lib_handson.sh" \
    "lanciatelo dal repository, o date PN_HANDSON_ROOT" "${s}" "${ws}" \
    "${TMP}/esca:${PATH}" PN_HANDSON_ROOT="${TMP}/non-c-e" \
    ANTHROPIC_API_KEY="${CHIAVE}"
  mv -- "${ws}/testi/frase-en.txt" "${TMP}/frase-en.txt" || exit 2
  precondizione "precondizione: una frase che manca" \
    "file assente o illeggibile: testi/frase-en.txt" "${s}" "${ws}" \
    "${TMP}/esca:${PATH}" ANTHROPIC_API_KEY="${CHIAVE}"
  mv -- "${TMP}/frase-en.txt" "${ws}/testi/frase-en.txt" || exit 2
  mv -- "${ws}/controlla_conteggi.py" "${TMP}/c.py" || exit 2
  precondizione "precondizione: il controllo che manca" \
    "file assente o illeggibile: controlla_conteggi.py" "${s}" "${ws}" \
    "${TMP}/esca:${PATH}" ANTHROPIC_API_KEY="${CHIAVE}"
  mv -- "${TMP}/c.py" "${ws}/controlla_conteggi.py" || exit 2
  t_precondizioni_file
}

# Le precondizioni sui file dati: curl è l'esca, nessuna chiamata deve partire.
t_precondizioni_file() {
  local vuoto="${TMP}/vuoto.txt" a="${TMP}/a" b="${TMP}/b"
  nuovo_ws_in "${TMP}/ws_precondizioni" \
    || { fail "file dati: prepara_esercizio.sh"; return; }
  : > "${vuoto}"
  mkdir -p "${a}" "${b}" || exit 2
  printf 'uno\n' > "${a}/testo.txt" || exit 2
  printf 'due\n' > "${b}/testo.txt" || exit 2
  printf 'x\n' > "${TMP}/.nascosto" || exit 2
  : > "${TMP}/esca.log"
  esca_con_file "${TMP}/non-c-e.txt"
  expect "precondizione: un file che non c'è" 2 "file assente o illeggibile"
  esca_con_file "${vuoto}"
  expect "precondizione: un file vuoto" 2 "non si può contare"
  esca_con_file "${a}/testo.txt" "${b}/testo.txt"
  expect "precondizione: due file con lo stesso nome" 2 "due file si chiamano"
  esca_con_file "${TMP}/.nascosto"
  expect "precondizione: un nome che non si può usare" 2 "non si può usare"
  vero "precondizione: i file dati sbagliati, nessuna chiamata" \
    test ! -s "${TMP}/esca.log"
}

t_fallita() {
  local ws
  nuovo_ws ws || { fail "fallita: prepara_esercizio.sh"; return; }
  finto "${D01}/demo/chiama.sh" "${ws}" FINTO_FALLISCE=1 --
  expect "fallita: curl che non riesce, 1" 1 "curl non è riuscito"
  vero "fallita: nessun file a metà in risposte/" test ! -e "${ws}/risposte"
  expect_absent "fallita: la chiave non si stampa" "${CHIAVE}"
  nuovo_ws ws || { fail "fallita: prepara_esercizio.sh"; return; }
  finto "${D01}/demo/chiama.sh" "${ws}" FINTO_FALLISCE_SE=connection --
  expect "fallita: la seconda POST che non riesce, 1" 1 \
    "curl non è riuscito su frase-en"
  vero "fallita: la seconda POST, nessun file a metà" test ! -e "${ws}/risposte"
  nuovo_ws ws || { fail "fallita: prepara_esercizio.sh"; return; }
  finto "${D01}/demo/chiama.sh" "${ws}" FINTO_STATO=401 FINTO_CORPO=errore --
  expect "fallita: una risposta 401, 1" 1 "authentication_error"
  expect "fallita: 401, verdetto KO" 1 "VERIFICA KO"
}

t_shellcheck() {
  local f
  for f in "${D01}/verifica.sh" "${D01}/_docente/live.sh" \
      "${D01}/demo/chiama.sh" "${SELF}"; do
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
      || { echo "test_m8_d01: manca ${t}" >&2; exit 2; }
  done
  [[ -f "${FINTO_PY}" ]] \
    || { echo "test_m8_d01: manca ${FINTO_PY}" >&2; exit 2; }
  handson::init_temp_base
  TMP="$(mktemp -d "${HANDSON_TEMP_BASE}/test_m8_d01.XXXXXX")" || exit 2
  trap 'chmod -R u+rwX "${TMP}" 2> /dev/null; rm -rf "${TMP}"' EXIT
  prepara_curl
  t_elemento
  t_readme
  t_prepara
  t_controllo
  t_conteggi
  t_illeggibili
  t_verifica
  t_chiama
  t_file_dati
  t_live
  t_precondizioni
  t_fallita
  t_shellcheck
  OUT="${TUTTO}"
  expect_absent "in nessuna uscita «smentita»" "smentita"
  expect_absent "in nessuna uscita un traceback" "Traceback"
  expect_absent "in nessuna uscita la chiave finta" "${CHIAVE}"
  echo "PASS=${PASS} FAIL=${FAIL}"
  if (( PASS + FAIL != CASES )); then
    echo "test_m8_d01: girati $((PASS + FAIL)) casi, attesi ${CASES}" >&2
    exit 2
  fi
  (( FAIL == 0 )) || exit 1
}

main "$@"
