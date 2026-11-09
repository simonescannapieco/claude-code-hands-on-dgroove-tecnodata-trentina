#!/bin/bash
#
# test_m7_d02.sh -- le prove di M7-D02 «Solo una POST», per il docente:
#   - l'elemento: il corpo della richiesta, il README con le dieci sezioni, le
#     frasi di Anthropic con il loro indirizzo, il corpo mostrato uguale al
#     file; niente identificativi interni, «smentita» o riferimenti alla
#     giornata;
#   - prepara_esercizio.sh e verifica.sh sul punto di partenza (1);
#   - controlla_risposta.py su risposte del curl finto: riuscita, errore,
#     campi che mancano (0/1), file che non si leggono (2), mai un traceback;
#   - verifica.sh: il controllo dell'elemento, mai quello dello spazio di
#     lavoro; le precondizioni (2);
#   - demo/chiama.sh e _docente/live.sh con il curl finto: l'URL, le
#     intestazioni, il corpo, la chiave che passa sullo STDIN e mai fra gli
#     argomenti, nell'output o nei file; le precondizioni (2, nessuna
#     chiamata: l'esca); curl che fallisce (1);
#   - shellcheck -x sugli script e su questo file.
# Mai il curl vero e mai una chiave vera: il finto e l'esca stanno davanti nel
# PATH, e la suite lo controlla prima di usarli. Gli spazi di lavoro nascono in
# una cartella temporanea: l'albero del repository non cambia. CASES è il
# numero dei casi: se ne girano di più o di meno la suite esce 2.
#
# Uso:    m7_assistenti_llm/_docente/test_m7_d02.sh
# Uscita: 0 = tutti i casi passano · 1 = almeno un caso fallito · 2 =
#         precondizione (manca python3, git o shellcheck), o un numero di casi
#         diverso da CASES
set -uo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly MOD="${SELF%/_docente/*}"
readonly RADICE="${MOD%/*}"
D02="${MOD}/s5_anatomia_e_strumenti/m7_3_sotto_il_cofano"
D02+="/M7-D02_solo_una_post"
readonly D02
readonly FINTO_PY="${MOD}/_docente/curl_finto_m7_d02.py"
# La libreria del repository, per la base dei file temporanei.
# shellcheck source=../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"
readonly CASES=90
# Una stringa da chiave finta: la suite controlla che non compaia mai.
readonly CHIAVE='chiave-finta_di-prova-0123456789'
FATTO='Fatto: la risposta è riuscita; stato, stop_reason e usage sono qui'
FATTO+=' sopra.'
readonly FATTO
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
  "${RADICE}/tools/prepara_esercizio.sh" M7-D02 --radice "${__r}" \
    > "${TMP}/prepara.log" 2>&1 || return 1
  printf -v "$1" '%s' "${__r}/M7-D02"
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
  for t in readlink git python3 mktemp cat dirname mkdir rm rmdir sed; do
    ln -s "$(command -v "${t}")" "${TMP}/senza_curl/${t}" || exit 2
  done
  for t in readlink git curl mktemp cat dirname mkdir rm rmdir sed; do
    ln -s "$(command -v "${t}")" "${TMP}/senza_python/${t}" || exit 2
  done
  t="$(PATH="${TMP}/finto:${PATH}" command -v curl)"
  if [[ "${t}" != "${TMP}/finto/curl" ]]; then
    echo "test_m7_d02: nel PATH di prova curl è ${t}, non il finto" >&2
    exit 2
  fi
}

# Lo script con il curl finto davanti nel PATH e la chiave finta nell'ambiente;
# il registro riparte vuoto. Arguments: $1 lo script, $2 lo spazio di lavoro,
# poi le variabili NOME=valore.
finto() {
  local script="$1" w="$2"
  shift 2
  : > "${TMP}/finto.log"
  run env PATH="${TMP}/finto:${PATH}" HANDSON_NO_PAUSE=1 \
    ANTHROPIC_API_KEY="${CHIAVE}" FINTO_LOG="${TMP}/finto.log" \
    TMPDIR="${TMP}" "$@" "${script}" "${w}"
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

# Le chiamate di un registro del finto, contro le attese.
controlla_chiamate() {
  run python3 -B -I - "$1" "${D02}/demo/corpo.json" <<'PY'
import hashlib, json, sys
log, corpo = sys.argv[1:3]
righe = [json.loads(r) for r in open(log, encoding="utf-8")]
sha = hashlib.sha256(open(corpo, "rb").read()).hexdigest()
problemi = []
if len(righe) != 1:
    problemi.append("%d chiamate invece di una" % len(righe))
c = righe[0] if righe else {}
argv = c.get("argv", [])
for coppia in (["--request", "POST"], ["--config", "-"],
               ["--header", "anthropic-version: 2026-10-21"],
               ["--header", "content-type: application/json"],
               ["--data-binary", "@corpo.json"],
               ["--output", "risposte/risposta.json"]):
    if not any(argv[i:i + 2] == coppia for i in range(len(argv) - 1)):
        problemi.append("manca %s" % coppia)
if argv[-1:] != ["https://api.anthropic.com/v1/messages"]:
    problemi.append("l'URL: %s" % argv[-1:])
if c.get("chiave_in_argv"):
    problemi.append("la chiave negli argomenti")
if not c.get("config_bearer"):
    problemi.append("la chiave non arriva sulla configurazione via STDIN")
if not c.get("stdin_config"):
    problemi.append("--config - senza STDIN")
if c.get("corpo_sha256") != sha:
    problemi.append("il corpo non è corpo.json")
if not c.get("corpo_json"):
    problemi.append("il corpo non è JSON")
print("; ".join(problemi) or "chiamata giusta")
PY
}

# --- L'elemento -------------------------------------------------------------

t_elemento() {
  local f
  for f in README.md verifica.sh demo/corpo.json demo/chiama.sh \
      demo/controlla_risposta.py _docente/live.sh soluzione/LEGGIMI.md; do
    vero "elemento: ${f}" test -f "${D02}/${f}"
  done
  for f in verifica.sh _docente/live.sh demo/chiama.sh; do
    vero "elemento: ${f} eseguibile" test -x "${D02}/${f}"
  done
  run python3 -B -I - "${D02}/demo/corpo.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
ok = (d.get("model") == "claude-haiku-5-5"
      and isinstance(d.get("max_tokens"), int) and 0 < d["max_tokens"] <= 200
      and isinstance(d.get("messages"), list) and len(d["messages"]) == 1
      and d["messages"][0].get("role") == "user"
      and isinstance(d["messages"][0].get("content"), str)
      and "system" not in d)
print("corpo a posto" if ok else "corpo: %r" % d)
PY
  expect "corpo.json: Haiku, max_tokens piccolo, un messaggio, nessun system" \
    0 "corpo a posto"
}

t_readme() {
  run python3 -B -I - "${D02}" <<'PY'
import os, re, sys
item = sys.argv[1]
readme = open(os.path.join(item, "README.md"), encoding="utf-8").read()
corpo = open(os.path.join(item, "demo", "corpo.json"), encoding="utf-8").read()
problemi = []
sezioni = ("Obiettivo", "Tempo", "Prerequisiti", "Punto di partenza",
           "Passi in Claude Code", "Che cosa osservare", "Verifica",
           "Se qualcosa va storto", "Impronta d'uso sul piano Pro",
           "Per approfondire")
titoli = [r[3:] for r in readme.splitlines() if r.startswith("## ")]
if [next((s for s in sezioni if t.startswith(s)), "") for t in titoli] \
        != list(sezioni):
    problemi.append("le dieci sezioni, in ordine: %s" % titoli)
for titolo in ("## Punto di partenza (tools/prepara_esercizio.sh M7-D02)",
               "## Verifica (tools/verifica.sh M7-D02)"):
    if titolo not in readme:
        problemi.append("il titolo «%s»" % titolo)
OV = "https://platform.claude.com/docs/en/api/overview"
CR = "https://platform.claude.com/docs/en/api/messages/create"
SR = "https://platform.claude.com/docs/en/build-with-claude/" \
    "handling-stop-reasons"
frasi = [
    ("Send messages to Claude for conversational interactions (POST "
     "/v1/messages)", OV),
    ("Bearer <token>, where <token> is your API key … Legacy fallback for "
     "Authorization, still supported", OV),
    ("anthropic-version | API version (for example, 2026-10-21) | Yes … "
     "content-type | application/json | Yes", OV),
    ("max_tokens: number … messages: array of MessageParam … model: Model … "
     "system: optional string or array of TextBlockParam", CR),
    ("The stop_reason field is part of every successful Messages API "
     "response. … stop_reason tells you why Claude completed its response "
     "generation.", SR),
    ("Il modello: `claude-haiku-5-5`, il suo nome nell'API, dalla pagina dei "
     "modelli (https://platform.claude.com/docs/en/models/overview).",
     "https://platform.claude.com/docs/en/models/overview"),
    ("The Pro plan does not include API usage through the Claude Console.",
     "https://support.claude.com/en/articles/8325606-what-is-the-pro-plan")]
piano = " ".join(readme.split())
for frase, url in frasi:
    if " ".join(frase.split()) not in piano:
        problemi.append("manca «%s»" % frase[:50])
    if url not in readme:
        problemi.append("manca %s" % url)
blocco = re.search(r"```json\n(.*?)```", readme, re.S)
if not blocco or "\n".join(
        r[3:] if r.startswith("   ") else r
        for r in blocco.group(1).splitlines()).strip() != corpo.strip():
    problemi.append("il blocco JSON non è corpo.json")
for vietata in ("smentit", "FACT-", "M7-X", "X-3", "X-4", "oggi", "domani",
                "pausa", "pranzo", "/home/", "sk-ant-"):
    if vietata in readme:
        problemi.append("«%s»" % vietata)
print("; ".join(problemi) or "README a posto")
PY
  expect "README: sezioni, frasi con l'indirizzo, corpo uguale, niente di vietato" \
    0 "README a posto"
}

t_prepara() {
  local ws f
  if ! nuovo_ws ws; then
    fail "prepara_esercizio.sh M7-D02: $(tail -n 3 "${TMP}/prepara.log")"
    return
  fi
  pass "prepara_esercizio.sh M7-D02"
  for f in corpo.json chiama.sh controlla_risposta.py .claude/settings.json; do
    vero "spazio di lavoro: ${f}" test -f "${ws}/${f}"
  done
  if [[ ! -e "${ws}/soluzione" && ! -e "${ws}/_docente" ]]; then
    pass "spazio di lavoro: niente soluzione/ né _docente/"
  else
    fail "spazio di lavoro: soluzione/ o _docente/"
  fi
  run "${RADICE}/tools/verifica.sh" M7-D02 --radice "${ws%/M7-D02}"
  expect "verifica.sh sul punto di partenza: 1" 1 \
    "Manca la cartella risposte/"
}

# --- Il controllo -----------------------------------------------------------

# Una cartella con stato.txt e risposta.json scritti dal finto.
# Arguments: $1 la variabile, poi NOME=valore per il finto.
risposta_finta() {
  local __c v="$1"
  __c="$(mktemp -d "${TMP}/risp.XXXXXX")" || exit 2
  shift
  ( cd "${__c}" && env "$@" FINTO_LOG="" python3 -B -I "${FINTO_PY}" \
      --silent --output risposta.json --write-out '%{http_code}\n' \
      https://api.anthropic.com/v1/messages > stato.txt ) \
    || { echo "test_m7_d02: il finto non scrive" >&2; exit 2; }
  printf -v "${v}" '%s' "${__c}"
}

controlla() { run python3 -B -I "${D02}/demo/controlla_risposta.py" "$@"; }

t_controllo() {
  local c
  risposta_finta c
  controlla "${c}"
  expect "controllo: una risposta riuscita, 0" 0 "${FATTO}"
  expect "controllo: lo stato" 0 "stato HTTP: 200"
  expect "controllo: stop_reason" 0 "stop_reason: end_turn"
  expect "controllo: usage" 0 "usage: input_tokens 33 · output_tokens 17"
  expect "controllo: le altre voci di usage, come dato" 0 \
    "(dato) le altre voci di usage: cache_creation_input_tokens 0"
  expect "controllo: il modello, come dato" 0 "(dato) model: claude-haiku-5-5"
  risposta_finta c FINTO_STATO=401 FINTO_CORPO=errore \
    "FINTO_CHIAVE=sk-ant-chiave-che-non-esiste"
  controlla "${c}"
  expect "controllo: una risposta 401, 1" 1 "stato HTTP: 401"
  expect "controllo: 401, il tipo dell'errore" 1 "authentication_error"
  expect "controllo: 401, lo stato non è 200" 1 \
    "La risposta non è un successo"
  expect "controllo: una chiave nel messaggio d'errore, mascherata" 1 \
    "<chiave>"
  expect_absent "controllo: la chiave dell'errore non si stampa" "sk-ant-"
  risposta_finta c FINTO_CORPO=senza_stop
  controlla "${c}"
  expect "controllo: senza stop_reason, 1" 1 "stop_reason"
  risposta_finta c FINTO_CORPO=nullo
  controlla "${c}"
  expect "controllo: stop_reason null, 1" 1 "La risposta non ha: stop_reason"
  risposta_finta c FINTO_CORPO=senza_usage
  controlla "${c}"
  expect "controllo: senza usage, 1" 1 "La risposta non ha: usage"
  rm -f -- "${c}/risposta.json"
  controlla "${c}"
  expect "controllo: risposta.json che manca, 1" 1 "manca risposta.json"
  risposta_finta c
  printf 'ottimo\n' > "${c}/stato.txt" || exit 2
  controlla "${c}"
  expect "controllo: uno stato che non è un numero, 2" 2 "non è un numero"
  risposta_finta c FINTO_CORPO=rotto
  controlla "${c}"
  expect "controllo: un corpo che non è JSON, 2" 2 "non si legge come JSON"
  risposta_finta c
  printf '[1, 2]\n' > "${c}/risposta.json" || exit 2
  controlla "${c}"
  expect "controllo: un JSON che non è un oggetto, 2" 2 \
    "non è un oggetto JSON"
  controlla "${TMP}/non-c-e"
  expect "uso: una cartella che non c'è, 2" 2 "non c'è"
  controlla
  expect "uso: senza argomenti, 2" 2 "Uso:"
}

t_verifica() {
  local ws
  nuovo_ws ws || { fail "verifica: prepara_esercizio.sh"; return; }
  run "${D02}/verifica.sh" "${ws}"
  expect "verifica: senza risposte/, 1" 1 "Manca la cartella risposte/"
  mkdir -p "${ws}/risposte" || exit 2
  run "${D02}/verifica.sh" "${ws}"
  expect "verifica: risposte/ vuota, 1" 1 "manca stato.txt"
  ( cd "${ws}/risposte" && env FINTO_LOG="" python3 -B -I "${FINTO_PY}" \
      --silent --output risposta.json --write-out '%{http_code}\n' \
      https://api.anthropic.com/v1/messages > stato.txt ) || exit 2
  printf 'print("CONTROLLO FINTO")\n' > "${ws}/controlla_risposta.py" || exit 2
  run env PN_HANDSON_ROOT="${RADICE}" "${D02}/verifica.sh" "${ws}"
  expect "verifica: la risposta del finto, 0, «Fatto»" 0 "${FATTO}"
  expect_absent "verifica: il controllo dell'elemento, non della copia" \
    "CONTROLLO FINTO"
  run "${D02}/verifica.sh"
  expect "verifica: senza argomenti, 2" 2 "spazio di lavoro assente"
}

# --- chiama.sh e live.sh ----------------------------------------------------

t_chiama() {
  local ws
  nuovo_ws ws || { fail "chiama: prepara_esercizio.sh"; return; }
  finto "${D02}/demo/chiama.sh" "${ws}"
  expect "chiama: 0, il controllo ha letto la risposta" 0 \
    "VERIFICA OK   la risposta, in risposte/"
  expect "chiama: il comando curl sullo schermo" 0 "--config -"
  expect "chiama: il corpo sullo schermo" 0 '"model": "claude-haiku-5-5"'
  expect_absent "chiama: la chiave non si stampa" "${CHIAVE}"
  controlla_chiamate "${TMP}/finto.log"
  expect "chiama: URL, intestazioni, corpo, chiave via STDIN" 0 \
    "chiamata giusta"
  vero "chiama: stato.txt" test -s "${ws}/risposte/stato.txt"
  vero "chiama: risposta.json" test -s "${ws}/risposte/risposta.json"
  run grep -rlF -- "${CHIAVE}" "${ws}"
  if (( RC == 1 )); then
    pass "chiama: la chiave in nessun file dello spazio di lavoro"
  else
    fail "chiama: la chiave è in: ${OUT}"
  fi
  run env PN_HANDSON_ROOT="${RADICE}" "${D02}/verifica.sh" "${ws}"
  expect "chiama: poi verifica.sh, 0" 0 "${FATTO}"
}

t_live() {
  local ws
  nuovo_ws ws || { fail "live: prepara_esercizio.sh"; return; }
  finto "${D02}/_docente/live.sh" "${ws}"
  expect "live: 0" 0 "VERIFICA OK   verifica.sh dell'elemento"
  expect_absent "live: la chiave non si stampa" "${CHIAVE}"
  controlla_chiamate "${TMP}/finto.log"
  expect "live: una chiamata, quella giusta" 0 "chiamata giusta"
  run "${RADICE}/tools/verifica.sh" M7-D02 --radice "${ws%/M7-D02}"
  expect "live: poi tools/verifica.sh, 0" 0 "VERIFICA OK   M7-D02: fatto."
  run "${D02}/_docente/live.sh"
  expect "live: senza argomenti, 2" 2 "uso:"
  nuovo_ws ws || { fail "live: prepara_esercizio.sh"; return; }
  : > "${TMP}/esca.log"
  run env -u ANTHROPIC_API_KEY PATH="${TMP}/esca:${PATH}" \
    ESCA_LOG="${TMP}/esca.log" "${D02}/_docente/live.sh" "${ws}"
  expect "live: senza la chiave, 2" 2 "ANTHROPIC_API_KEY non è impostata"
  vero "live: senza la chiave, nessuna chiamata di curl" \
    test ! -s "${TMP}/esca.log"
}

t_precondizioni() {
  local ws s="${D02}/demo/chiama.sh"
  nuovo_ws ws || { fail "precondizioni: prepara_esercizio.sh"; return; }
  precondizione "precondizione: nessuna chiave" \
    "ANTHROPIC_API_KEY non è impostata" "${s}" "${ws}"
  precondizione "precondizione: nessuno spazio di lavoro" \
    "spazio di lavoro assente" "${s}" ""
  precondizione "precondizione: una cartella che non è lo spazio" \
    "non è lo spazio di lavoro di M7-D02" "${s}" "${TMP}" \
    "${TMP}/esca:${PATH}" ANTHROPIC_API_KEY="${CHIAVE}"
  precondizione "precondizione: una chiave con caratteri strani" \
    "non si possono" "${s}" "${ws}" "${TMP}/esca:${PATH}" \
    'ANTHROPIC_API_KEY=con"apice'
  precondizione "precondizione: senza curl" "manca lo strumento: curl" \
    "${s}" "${ws}" "${TMP}/senza_curl" ANTHROPIC_API_KEY="${CHIAVE}"
  precondizione "precondizione: senza python3" "manca lo strumento: python3" \
    "${s}" "${ws}" "${TMP}/senza_python" ANTHROPIC_API_KEY="${CHIAVE}"
  mkdir -p "${ws}/risposte" || exit 2
  precondizione "precondizione: risposte/ c'è già" \
    "non è al punto di partenza" "${s}" "${ws}" "${TMP}/esca:${PATH}" \
    ANTHROPIC_API_KEY="${CHIAVE}"
  rmdir -- "${ws}/risposte"
  printf '{rotto\n' > "${ws}/corpo.json" || exit 2
  precondizione "precondizione: corpo.json rotto" "non è un JSON valido" \
    "${s}" "${ws}" "${TMP}/esca:${PATH}" ANTHROPIC_API_KEY="${CHIAVE}"
  precondizione "precondizione: senza tools/lib_handson.sh" \
    "lanciatelo dal repository, o date PN_HANDSON_ROOT" "${s}" "${ws}" \
    "${TMP}/esca:${PATH}" PN_HANDSON_ROOT="${TMP}/non-c-e" \
    ANTHROPIC_API_KEY="${CHIAVE}"
}

t_fallita() {
  local ws
  nuovo_ws ws || { fail "fallita: prepara_esercizio.sh"; return; }
  finto "${D02}/demo/chiama.sh" "${ws}" FINTO_FALLISCE=1
  expect "fallita: curl che non riesce, 1" 1 "curl non è riuscito"
  vero "fallita: nessun file a metà in risposte/" test ! -e "${ws}/risposte"
  expect_absent "fallita: la chiave non si stampa" "${CHIAVE}"
  nuovo_ws ws || { fail "fallita: prepara_esercizio.sh"; return; }
  finto "${D02}/demo/chiama.sh" "${ws}" FINTO_STATO=401 FINTO_CORPO=errore
  expect "fallita: una risposta 401, 1" 1 "authentication_error"
  expect "fallita: 401, verdetto KO" 1 "VERIFICA KO"
}

t_shellcheck() {
  local f
  for f in "${D02}/verifica.sh" "${D02}/_docente/live.sh" \
      "${D02}/demo/chiama.sh" "${SELF}"; do
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
      || { echo "test_m7_d02: manca ${t}" >&2; exit 2; }
  done
  [[ -f "${FINTO_PY}" ]] \
    || { echo "test_m7_d02: manca ${FINTO_PY}" >&2; exit 2; }
  handson::init_temp_base
  TMP="$(mktemp -d "${HANDSON_TEMP_BASE}/test_m7_d02.XXXXXX")" || exit 2
  trap 'chmod -R u+rwX "${TMP}" 2> /dev/null; rm -rf "${TMP}"' EXIT
  prepara_curl
  t_elemento
  t_readme
  t_prepara
  t_controllo
  t_verifica
  t_chiama
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
    echo "test_m7_d02: girati $((PASS + FAIL)) casi, attesi ${CASES}" >&2
    exit 2
  fi
  (( FAIL == 0 )) || exit 1
}

main "$@"
