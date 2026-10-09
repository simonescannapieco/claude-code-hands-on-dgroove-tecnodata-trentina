#!/bin/bash
#
# tests/test_progetti_assistenza.sh — verifica progetti/assistenza-clienti.
#
# Il generatore deterministico (genera.py --check: 0 sul repository, 1 su una
# copia alterata o incompleta, 2 su un JSON illeggibile o un'opzione
# sconosciuta); il canone dei dati sintetici (--canone: 0 sul progetto, 1 su
# ogni valore fuori canone piantato in una copia, 2 su un file non UTF-8); la
# struttura di scenari, conversazioni di riferimento, strumenti del v0,
# procedure e picchi dei guasti nei ticket (--verifica: 0 sul progetto, 1 su
# una copia rovinata, 2 su un JSON illeggibile); l'esclusione di _docente/
# dalla copia per i partecipanti, se il progetto sta in un repository git.
#
# Uso: tests/test_progetti_assistenza.sh
# Uscita: 0 nessun test fallito; 1 almeno un test fallito; 2 prerequisito
# mancante (python3 3.8 o successivo, il progetto, una copia di lavoro).
# Variabile di prova: PYTHON_TEST, l'interprete da usare (predefinito python3).
set -uo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly ROOT="${SELF%/tests/*}"
readonly PROJ="${ROOT}/progetti/assistenza-clienti"
readonly PYTHON="${PYTHON_TEST:-python3}"
readonly CSV="dati/ticket-settimana.csv"
readonly KB_PROVA="kb/kb-01-fibra-nessuna-connessione.md"
readonly SC_PROVA="scenari/sc-01-fibra-assente-guasto-pergine.json"
readonly GC_PROVA="golden/gc-01-guasto-collettivo-pergine.json"
# Valori fuori canone da piantare in una copia: «valore|messaggio atteso».
readonly -a VELENI=(
  'nome@gmail.com|e-mail fuori'  # canon:ok -- planted negative
  '192.168.1.1|IPv4 fuori'  # canon:ok -- planted negative
  '2001:470::1|IPv6 fuori'  # canon:ok -- planted negative
  '+39 0461 123456|telefono fuori'  # canon:ok -- planted negative
  'aa:bb:cc:dd:ee:ff|MAC fuori'  # canon:ok -- planted negative
  '2026-10-01|data fuori'  # canon:ok -- planted negative
)
readonly NOME_FUORI="Laura Rossi"  # canon:ok -- planted negative

TMP=""
COPIA=""
OUT=""
RC=0
PASS=0
FAIL=0
SKIP=0

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }
skip() { echo "  SKIP: $1"; SKIP=$((SKIP + 1)); }
die() { echo "FATAL: $*" >&2; exit 2; }

# pulisci: rimuove la cartella temporanea, mai una vuota, / o un link.
pulisci() {
  if [[ -n "${TMP}" && "${TMP}" != "/" && ! -L "${TMP}" ]]; then
    rm -rf -- "${TMP}"
  fi
}

# genera <cartella del progetto> <opzione…>: imposta OUT (stdout e stderr) e RC.
genera() {
  local cartella="$1"
  shift
  OUT="$("${PYTHON}" -B -I "${cartella}/genera.py" "$@" 2>&1)"
  RC=$?
}

# atteso <descrizione> <rc atteso> <testo atteso>: rc E messaggio insieme.
atteso() {
  if (( RC == $2 )) && grep -q -F -- "$3" <<<"${OUT}"; then
    pass "$1"
  else
    fail "$1 (rc=${RC}, atteso $2 con «$3»): ${OUT:0:300}"
  fi
}

# senza <descrizione> <testo>: rc 0 e nessuna traccia del testo.
senza() {
  if (( RC == 0 )) && ! grep -q -F -- "$2" <<<"${OUT}"; then
    pass "$1"
  else
    fail "$1 (rc=${RC}, «$2» presente): ${OUT:0:300}"
  fi
}

# copia <nome>: copia il progetto nella cartella temporanea; imposta COPIA.
copia() {
  COPIA="${TMP}/$1"
  cp -a -- "${PROJ}" "${COPIA}" || die "copia del progetto non riuscita"
}

# altera_json <file> <operazione>: rovina apposta un JSON di una copia.
altera_json() {
  "${PYTHON}" -B -I - "$1" "$2" <<'PY' || die "JSON di prova non modificato"
import json
import sys
percorso, operazione = sys.argv[1], sys.argv[2]
with open(percorso, encoding="utf-8") as f:
    dati = json.load(f)
if operazione == "senza-da_evitare":
    del dati["da_evitare"]
elif operazione == "senza-input_schema":
    del dati[0]["input_schema"]
elif operazione == "scenario-inesistente":
    dati["scenario"] = "SC-99"
with open(percorso, "w", encoding="utf-8") as f:
    json.dump(dati, f, ensure_ascii=False)
PY
}

test_generatore() {
  echo "Generatore (--check)"
  genera "${PROJ}" --check
  atteso "CSV e conversazioni identici a quelli rigenerati" 0 "identici"
  copia csv-alterato
  printf 'x' >>"${COPIA}/${CSV}"
  genera "${COPIA}" --check
  atteso "un CSV alterato esce con 1" 1 "DIVERSO: ${CSV}"
  copia file-mancante
  rm -f -- "${COPIA}/${GC_PROVA%.json}.md"
  genera "${COPIA}" --check
  atteso "un file generato mancante esce con 1" 1 "MANCANTE: golden/gc-01"
  copia file-in-piu
  printf '# vecchia\n' >"${COPIA}/golden/gc-99-vecchia.md"
  genera "${COPIA}" --check
  atteso "un file generato in più esce con 1" 1 "IN PIÙ: golden/gc-99"
  copia json-rotto
  printf '{' >"${COPIA}/${GC_PROVA}"
  genera "${COPIA}" --check
  atteso "un JSON illeggibile esce con 2" 2 "ERRORE"
  genera "${PROJ}" --sconosciuta
  atteso "un'opzione sconosciuta esce con 2" 2 "uso:"
  if [[ -z "$(find "${PROJ}" -name __pycache__ -print -quit)" ]]; then
    pass "nessuna cartella __pycache__ lasciata nel progetto"
  else
    fail "il generatore ha lasciato una cartella __pycache__"
  fi
}

test_canone() {
  local voce n=0
  echo "Canone dei dati sintetici (--canone)"
  genera "${PROJ}" --canone
  atteso "il progetto rispetta il canone" 0 "OK: canone rispettato"
  senza "nessuna violazione sul progetto pulito" "VIOLAZIONE"
  for voce in "${VELENI[@]}"; do
    n=$((n + 1))
    copia "veleno-${n}"
    printf 'Valore di prova: %s.\n' "${voce%%|*}" >>"${COPIA}/${KB_PROVA}"
    genera "${COPIA}" --canone
    atteso "il canone segnala ${voce%%|*}" 1 "${voce#*|}"
  done
  copia nome
  sed -i "s/Laura Prova/${NOME_FUORI}/" "${COPIA}/${CSV}"
  genera "${COPIA}" --canone
  atteso "il canone segnala un cognome fuori lista" 1 "cognome fuori dalla"
  copia non-utf8
  printf '\xff\xfe\n' >"${COPIA}/kb/kb-99-binario.md"
  genera "${COPIA}" --canone
  atteso "un file non UTF-8 esce con 2" 2 "ERRORE"
}

test_struttura() {
  echo "Struttura (--verifica)"
  genera "${PROJ}" --verifica
  atteso "scenari, conversazioni, strumenti, procedure e picchi a posto" 0 \
    "OK: struttura verificata"
  senza "nessun problema sul progetto pulito" "PROBLEMA"
  copia senza-chiave
  altera_json "${COPIA}/${SC_PROVA}" senza-da_evitare
  genera "${COPIA}" --verifica
  atteso "uno scenario senza «da_evitare» esce con 1" 1 "manca da_evitare"
  copia senza-schema
  altera_json "${COPIA}/v0/strumenti.json" senza-input_schema
  genera "${COPIA}" --verifica
  atteso "uno strumento senza input_schema esce con 1" 1 "input_schema"
  copia scenario-assente
  altera_json "${COPIA}/${GC_PROVA}" scenario-inesistente
  genera "${COPIA}" --verifica
  atteso "una conversazione senza scenario esce con 1" 1 "SC-99 inesistente"
  copia senza-martedi
  grep -v -F -- ',2026-09-08T' "${COPIA}/${CSV}" >"${COPIA}/${CSV}.nuovo"
  mv -- "${COPIA}/${CSV}.nuovo" "${COPIA}/${CSV}"
  genera "${COPIA}" --verifica
  atteso "senza i ticket di martedì manca il picco di Pergine" 1 \
    "picco «fibra Pergine"
  copia scenario-rotto
  printf '{' >"${COPIA}/${SC_PROVA}"
  genera "${COPIA}" --verifica
  atteso "uno scenario illeggibile esce con 2" 2 "ERRORE"
}

test_esportazione() {
  local docente
  echo "Copia per i partecipanti"
  if ! git -C "${ROOT}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    skip "non è un repository git: l'esclusione di _docente/ non si verifica"
    return
  fi
  docente="$(git -C "${ROOT}" check-attr export-ignore -- \
    progetti/assistenza-clienti/_docente/README.md)"
  if [[ "${docente}" == *": export-ignore: set" ]]; then
    pass "_docente/ resta fuori dalla copia per i partecipanti"
  else
    fail "_docente/ non è esclusa dall'esportazione: ${docente}"
  fi
}

main() {
  command -v "${PYTHON}" >/dev/null 2>&1 || die "interprete assente: ${PYTHON}"
  "${PYTHON}" -c 'import sys; sys.exit(sys.version_info < (3, 8))' \
    || die "serve Python 3.8 o successivo"
  [[ -f "${PROJ}/genera.py" ]] || die "progetto assente: ${PROJ}"
  TMP="$(mktemp -d)" || die "mktemp non riuscito"
  trap pulisci EXIT
  test_generatore
  test_canone
  test_struttura
  test_esportazione
  echo "PASS=${PASS} FAIL=${FAIL} SKIP=${SKIP}"
  (( FAIL == 0 )) || exit 1
}

main "$@"
