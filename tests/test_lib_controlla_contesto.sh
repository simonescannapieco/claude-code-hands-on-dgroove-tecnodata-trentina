#!/bin/bash
#
# Test di tools/lib_controlla_contesto.py, il controllo comune del
# laboratorio del Modulo 6: le garanzie dell'avvio decidono l'uscita (anche
# con --solo-prove), i criteri e i confronti si stampano come dati, ciò che
# manca per finire esce 1, ciò che non si legge esce 2. Gli spazi di lavoro
# sono sintetici, scritti qui in una cartella temporanea, con un verifica.py
# finto che dichiara due richieste e i loro criteri.
#
# Uso:    bash tests/test_lib_controlla_contesto.sh
# Uscita: 0 tutti i test superati · 1 almeno un test fallito ·
#         2 precondizione (python3 mancante, la libreria che non c'è)
set -uo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
ROOT="$(dirname "$(dirname "${SELF}")")"
readonly ROOT
readonly LIB="${ROOT}/tools/lib_controlla_contesto.py"

PASS=0
FAIL=0
OUT=""
RC=0
TMP=""
WS=""

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

cleanup() {
  if [[ -n "${TMP}" && -d "${TMP}" ]]; then
    rm -rf -- "${TMP}"
  fi
}
trap cleanup EXIT

# Arguments: $1 nome, $2 rc atteso, poi le parole che l'uscita deve avere.
expect() {
  local nome="$1" atteso="$2" parola
  shift 2
  if (( RC != atteso )) || grep -qF Traceback <<< "${OUT}"; then
    fail "${nome}: rc=${RC}, atteso ${atteso}: ${OUT:0:700}"
    return 0
  fi
  for parola in "$@"; do
    if ! grep -qF -- "${parola}" <<< "${OUT}"; then
      fail "${nome}: manca «${parola}»: ${OUT:0:700}"
      return 0
    fi
  done
  pass "${nome}"
}

# Il verifica.py finto: due richieste, un criterio ciascuna.
driver() {
  cat > "${TMP}/verifica.py" <<'EOF'
import sys
sys.path.insert(0, sys.argv.pop(1))
import lib_controlla_contesto as cc

def php(prova):
    usati = [c for c in prova.contesto.comandi if "php.sh" in c]
    return bool(usati), (usati[0] if usati else "nessun tools/php.sh")

def commit(prova):
    return bool(prova.commit), (prova.commit[0].soggetto if prova.commit
                                else "nessun commit")

sys.exit(cc.principale(sys.argv[1:], "M6-E09", ("t1", "t2"),
                       {"t1": [("tools/php.sh", php)],
                        "t2": [("un commit", commit)]}))
EOF
}

controlla() {
  OUT="$(timeout 60 python3 -B -I "${TMP}/verifica.py" "${ROOT}/tools" "$@" \
    2>&1)"
  RC=$?
}

# Lo stesso, con l'ambiente dato prima di «--» (gli argomenti di env).
controlla_con() {
  local -a ambiente=()
  while (( $# > 0 )) && [[ "$1" != "--" ]]; do
    ambiente+=("$1")
    shift
  done
  shift
  OUT="$(env "${ambiente[@]}" timeout 60 python3 -B -I "${TMP}/verifica.py" \
    "${ROOT}/tools" "$@" 2>&1)"
  RC=$?
}

# Nessun falso positivo: nessuna delle parole c'è (RU-01.T5).
# Arguments: $1 nome, poi le parole (grep -F).
expect_assenti() {
  local nome="$1" parola
  shift
  for parola in "$@"; do
    if grep -qF -- "${parola}" <<< "${OUT}"; then
      fail "${nome}: «${parola}» c'è: ${OUT:0:700}"
      return 0
    fi
  done
  pass "${nome}"
}

# Un turno solo nel result di uno stream. Arguments: $1 lo stream.
un_turno() {
  python3 -B -I - "$1" <<'PY'
import sys

testo = open(sys.argv[1], encoding="utf-8").read()
open(sys.argv[1], "w", encoding="utf-8").write(
    testo.replace('"num_turns":2', '"num_turns":1'))
PY
}

# Uno stream con un Bash. Arguments: $1 il file, $2 il comando, $3 i token
# della prima richiesta.
stream() {
  {
    echo '{"type":"system","subtype":"init","model":"finto"}'
    printf '%s%s%s\n' '{"type":"assistant","parent_tool_use_id":null,' \
      "\"message\":{\"usage\":{\"input_tokens\":1,\"cache_creation_input_tokens\":$3,\"cache_read_input_tokens\":0},\"content\":[{\"type\":\"tool_use\"," \
      "\"id\":\"b1\",\"name\":\"Bash\",\"input\":{\"command\":\"$2\"}}]}}"
    echo '{"type":"result","subtype":"success","is_error":false,"num_turns":2,"duration_ms":2000,"result":"fatto","usage":{"input_tokens":1,"cache_creation_input_tokens":0,"cache_read_input_tokens":0,"output_tokens":1}}'
  } > "$1"
}

# Un'esecuzione. Arguments: $1 versione, $2 richiesta, $3 il comando, $4 i
# token, $5 «carica» se l'hook ha registrato il CLAUDE.md all'avvio, $6 il
# soggetto di un commit (vuoto: nessun commit).
esecuzione() {
  local d="${WS}/prove-contesto/$1/$2"
  mkdir -p "${d}"
  stream "${d}/stream.jsonl" "$3" "$4"
  printf 'la richiesta %s\n' "$2" > "${d}/prompt.txt"
  : > "${d}/file-cambiati.txt"
  : > "${d}/file-committati.txt"
  : > "${d}/diff.txt"
  if [[ "$5" == carica ]]; then
    printf '%s\n' '{"load_reason": "session_start", "file_path": "CLAUDE.md", "memory_type": "Project", "trigger_file_path": null, "parent_file_path": null, "globs": null}' \
      > "${d}/caricamenti.jsonl"
  else
    : > "${d}/caricamenti.jsonl"
  fi
  if [[ -n "${6:-}" ]]; then
    printf '%s\n\nRif: GES-0\n\n----\n' "$6" > "${d}/commit.txt"
  else
    : > "${d}/commit.txt"
  fi
}

# Una fotografia. Arguments: $1 versione, $2 il testo del CLAUDE.md (vuoto:
# nessun CLAUDE.md).
foto() {
  local f="${WS}/prove-contesto/$1/fotografia"
  mkdir -p "${f}/.claude"
  printf '{}\n' > "${f}/.claude/settings.json"
  if [[ -n "$2" ]]; then
    printf '%s\n' "$2" > "${f}/CLAUDE.md"
  fi
}

# Uno spazio di lavoro con le tre versioni a posto.
tre_versioni() {
  WS="${TMP}/ws$1"
  foto base ''
  esecuzione base t1 "php vendor/bin/phpunit" 9000 no
  esecuzione base t2 "git status" 9000 no
  foto v1 $'# Gestionale\n- Test: tools/php.sh phpunit'
  esecuzione v1 t1 "../../tools/php.sh phpunit" 9300 carica
  esecuzione v1 t2 "git commit -m x" 9300 carica "fix(fatturazione): corregge"
  foto v2 $'# Gestionale\n- Test: tools/php.sh phpunit\n- Commit: Rif.'
  esecuzione v2 t1 "../../tools/php.sh phpunit" 9350 carica
  esecuzione v2 t2 "git commit -m y" 9350 carica "fix(fatturazione): corregge"
}

main() {
  command -v python3 >/dev/null 2>&1 || { echo "manca python3" >&2; exit 2; }
  [[ -r "${LIB}" ]] || { echo "manca ${LIB}" >&2; exit 2; }
  TMP="$(mktemp -d)"
  driver

  echo "lib_controlla_contesto.py"
  tre_versioni 1
  controlla "${WS}"
  expect "tre versioni a posto: uscita 0" 0 \
    "v1 contro base: tools/php.sh: confermata" \
    "v2 contro v1: tools/php.sh: non distinguibile" \
    "v1 contro base: un commit: confermata" \
    "Garanzia, v1: CLAUDE.md caricato all'avvio in 2 su 2 esecuzioni" \
    "Garanzia, base: nessun file di istruzioni caricato in 2 su 2" \
    "v1: CLAUDE.md, 2 righe" "prima richiesta 9301 token · 2 turni · 2 s"
  if grep -qE '^(MANCA|GARANZIA)' <<< "${OUT}"; then
    fail "tre versioni a posto: una riga MANCA o GARANZIA: ${OUT}"
  else
    pass "tre versioni a posto: nessuna riga MANCA né GARANZIA"
  fi

  tre_versioni 10
  foto v1 '# Gestionale'
  un_turno "${WS}/prove-contesto/v1/t1/stream.jsonl"
  grep -v '"type":"result"' "${WS}/prove-contesto/v1/t2/stream.jsonl" \
    > "${TMP}/s" && mv "${TMP}/s" "${WS}/prove-contesto/v1/t2/stream.jsonl"
  controlla "${WS}" --solo-prove
  expect "al singolare: una riga, un turno, un'esecuzione" 0 \
    "v1: CLAUDE.md, 1 riga" "v1: prima richiesta 9301 token · 1 turno · 2 s" \
    "Garanzia, v1: CLAUDE.md caricato all'avvio in 1 su 1 esecuzione"
  expect_assenti "mai «1 righe», «1 turni», «1 esecuzioni»" '1 righe' \
    '1 turni' '1 esecuzioni'

  WS="${TMP}/ws2"
  foto base ''
  esecuzione base t1 "ls" 9000 no
  esecuzione base t2 "ls" 9000 no
  controlla "${WS}" --solo-prove
  expect "soltanto base, --solo-prove: uscita 0" 0 "Garanzia, base"
  controlla "${WS}"
  expect "soltanto base, verifica: manca v1" 1 \
    "MANCA la versione v1 non ha girato: tools/prova_contesto.sh M6-E09 v1"

  WS="${TMP}/rad/M6-E09"
  foto base ''
  esecuzione base t1 "ls" 9000 no
  esecuzione base t2 "ls" 9000 no
  controlla_con -u PN_WORKSPACE_ROOT HOME="${TMP}/casa" -- "${WS}"
  expect "fuori dalla radice di norma: il comando ripete --radice" 1 \
    "tools/prova_contesto.sh M6-E09 v1 --radice $(cd "${TMP}/rad" && pwd -P)"
  controlla_con PN_WORKSPACE_ROOT="${TMP}/rad" -- "${WS}"
  expect "nella radice di norma: il comando da rilanciare" 1 \
    "MANCA la versione v1 non ha girato: tools/prova_contesto.sh M6-E09 v1"
  expect_assenti "nella radice di norma: senza --radice" '--radice'

  tre_versioni 3
  esecuzione v1 t2 "git commit -m x" 9300 no "fix: x"
  controlla "${WS}" --solo-prove
  expect "un CLAUDE.md che non si carica: GARANZIA, uscita 1 anche --solo-prove" \
    1 "GARANZIA v1/t2: CLAUDE.md non si è caricato all'avvio"

  tre_versioni 4
  esecuzione base t1 "ls" 9000 carica
  controlla "${WS}" --solo-prove
  expect "un file caricato in base: GARANZIA" 1 \
    "GARANZIA base/t1: senza file di istruzioni si è caricato CLAUDE.md"

  tre_versioni 5
  foto v2 $'# Gestionale\n- Test: tools/php.sh phpunit'
  controlla "${WS}"
  expect "v2 uguale a v1: manca un cambiamento" 1 "MANCA v2 è uguale a v1"

  tre_versioni 6
  grep -v '"type":"result"' "${WS}/prove-contesto/v2/t1/stream.jsonl" \
    > "${TMP}/s" && mv "${TMP}/s" "${WS}/prove-contesto/v2/t1/stream.jsonl"
  controlla "${WS}"
  expect "una sessione senza risultato: MANCA, non un errore del controllo" 1 \
    "MANCA v2/t1: la sessione non è finita bene"

  tre_versioni 7
  printf 'non json\n' >> "${WS}/prove-contesto/v1/t1/stream.jsonl"
  controlla "${WS}"
  expect "uno stream che non si legge: uscita 2" 2 "verifica:" "non è JSON"

  tre_versioni 8
  rm -f -- "${WS}/prove-contesto/v1/fotografia/CLAUDE.md"
  controlla "${WS}"
  expect "v1 senza CLAUDE.md alla radice: manca" 1 \
    "MANCA v1 non ha un CLAUDE.md alla radice"

  tre_versioni 9
  printf 'fix: senza fine\n' > "${WS}/prove-contesto/v1/t2/commit.txt"
  controlla "${WS}"
  expect "un commit.txt senza ----: uscita 2" 2 "un commit senza la riga «----»"

  controlla "${TMP}/non-c-e"
  expect "uno spazio di lavoro che non c'è: uscita 2, l'uso" 2 "uso: verifica.py"
  controlla "${TMP}/ws1" --altro
  expect "un'opzione sconosciuta: uscita 2" 2 "uso: verifica.py"

  echo "PASS=${PASS} FAIL=${FAIL}"
  (( FAIL == 0 )) || exit 1
}

main "$@"
