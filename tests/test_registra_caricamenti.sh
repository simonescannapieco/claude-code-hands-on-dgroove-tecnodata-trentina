#!/bin/bash
#
# Test di tools/registra_caricamenti.py, l'hook InstructionsLoaded del
# Modulo 6: una riga per evento, i percorsi relativi al progetto o «~/…»,
# mai il percorso della home; gli eventi sbagliati e gli usi sbagliati
# escono 1 e 2 senza scrivere niente.
#
# Uso:    bash tests/test_registra_caricamenti.sh
# Uscita: 0 tutti i test superati · 1 almeno un test fallito ·
#         2 precondizione (python3 mancante, lo strumento che non c'è)
set -uo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
ROOT="$(dirname "$(dirname "${SELF}")")"
readonly ROOT
readonly HOOK="${ROOT}/tools/registra_caricamenti.py"

PASS=0
FAIL=0
OUT=""
RC=0
TMP=""

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

cleanup() {
  if [[ -n "${TMP}" && -d "${TMP}" ]]; then
    rm -rf -- "${TMP}"
  fi
}
trap cleanup EXIT

# Esegue l'hook con l'evento $1 su STDIN, in un ambiente con HOME e il
# progetto finti; le variabili in più ($2 …) come assegnazioni VAR=valore.
# Globals: OUT (STDERR), RC.
hook() {
  local evento="$1"
  shift
  OUT="$(printf '%s' "${evento}" | env -i PATH="${PATH}" \
    HOME="${TMP}/casa" CLAUDE_PROJECT_DIR="${TMP}/casa/progetto" \
    PN_CARICAMENTI="${TMP}/registro.jsonl" "$@" \
    python3 -B -I "${HOOK}" 2>&1 >/dev/null)"
  RC=$?
}

# Un evento InstructionsLoaded. Arguments: $1 load_reason, $2 file_path, i
# campi in più come JSON già pronto ($3, facoltativo, con la virgola).
evento() {
  printf '{"session_id":"s1","hook_event_name":"InstructionsLoaded",'
  printf '"cwd":"%s","load_reason":"%s","file_path":"%s",' \
    "${TMP}/casa/progetto" "$1" "$2"
  printf '"memory_type":"Project"%s}' "${3:-}"
}

# La riga n del registro (1 la prima). Arguments: $1 n.
riga() {
  sed -n "$1p" -- "${TMP}/registro.jsonl" 2>/dev/null
}

righe() {
  if [[ -f "${TMP}/registro.jsonl" ]]; then
    wc -l < "${TMP}/registro.jsonl"
  else
    echo 0
  fi
}

nuovo() {
  rm -f -- "${TMP}/registro.jsonl"
}

main() {
  command -v python3 >/dev/null 2>&1 || { echo "manca python3" >&2; exit 2; }
  [[ -r "${HOOK}" ]] || { echo "manca ${HOOK}" >&2; exit 2; }
  TMP="$(mktemp -d)"
  mkdir -p -- "${TMP}/casa/progetto/.claude/rules" "${TMP}/casa/altro"
  local p="${TMP}/casa/progetto"

  echo "registra_caricamenti.py"
  nuovo
  hook "$(evento session_start "${p}/CLAUDE.md")"
  if (( RC == 0 )) && [[ "$(riga 1)" == *'"load_reason": "session_start"'* \
      && "$(riga 1)" == *'"file_path": "CLAUDE.md"'* ]]; then
    pass "session_start: una riga, il percorso relativo al progetto"
  else
    fail "session_start: rc=${RC} riga=«$(riga 1)» ${OUT}"
  fi
  if [[ "$(riga 1)" != *"${TMP}"* ]]; then
    pass "la riga non porta il percorso della home"
  else
    fail "la riga porta il percorso della home: $(riga 1)"
  fi

  hook "$(evento include "${p}/docs/glossario.md" \
    ",\"parent_file_path\":\"${p}/CLAUDE.md\"")"
  if (( RC == 0 )) && (( $(righe) == 2 )) \
      && [[ "$(riga 2)" == *'"parent_file_path": "CLAUDE.md"'* \
        && "$(riga 2)" == *'"file_path": "docs/glossario.md"'* ]]; then
    pass "include: la seconda riga, dopo la prima, con il file che importa"
  else
    fail "include: rc=${RC} righe=$(righe) riga=«$(riga 2)» ${OUT}"
  fi

  nuovo
  hook "$(evento path_glob_match "${p}/.claude/rules/legacy.md" \
    ",\"globs\":[\"legacy/**\"],\"trigger_file_path\":\"${p}/legacy/a.php\"")"
  if (( RC == 0 )) && [[ "$(riga 1)" == *'"globs": ["legacy/**"]'* \
      && "$(riga 1)" == *'"trigger_file_path": "legacy/a.php"'* ]]; then
    pass "path_glob_match: i glob e il file che ha fatto caricare la regola"
  else
    fail "path_glob_match: rc=${RC} riga=«$(riga 1)» ${OUT}"
  fi

  nuovo
  hook "$(evento session_start "${TMP}/casa/altro/CLAUDE.md")"
  if (( RC == 0 )) && [[ "$(riga 1)" == *'"file_path": "~/altro/CLAUDE.md"'* ]]
  then
    pass "un file sotto la home, fuori dal progetto: «~/…»"
  else
    fail "sotto la home: rc=${RC} riga=«$(riga 1)» ${OUT}"
  fi

  nuovo
  hook "$(evento session_start /etc/claude-code/CLAUDE.md)"
  if (( RC == 0 )) \
      && [[ "$(riga 1)" == *'"file_path": "/etc/claude-code/CLAUDE.md"'* ]]
  then
    pass "un file fuori dalla home: il percorso assoluto, com'è"
  else
    fail "fuori dalla home: rc=${RC} riga=«$(riga 1)» ${OUT}"
  fi

  nuovo
  hook "$(evento session_start "${p}/CLAUDE.md")" CLAUDE_PROJECT_DIR=
  if (( RC == 0 )) && [[ "$(riga 1)" == *'"file_path": "CLAUDE.md"'* ]]; then
    pass "senza CLAUDE_PROJECT_DIR: la cartella dal campo cwd"
  else
    fail "senza CLAUDE_PROJECT_DIR: rc=${RC} riga=«$(riga 1)» ${OUT}"
  fi

  nuovo
  hook 'non è JSON'
  if (( RC == 1 )) && [[ "${OUT}" == *"non è JSON"* ]] && (( $(righe) == 0 ))
  then
    pass "un evento che non è JSON: uscita 1, niente scritto"
  else
    fail "non JSON: rc=${RC} righe=$(righe) ${OUT}"
  fi

  hook '{"hook_event_name":"SessionStart","cwd":"/x"}'
  if (( RC == 1 )) && [[ "${OUT}" == *"non è un evento InstructionsLoaded"* ]] \
      && (( $(righe) == 0 )); then
    pass "un altro evento: uscita 1, niente scritto"
  else
    fail "un altro evento: rc=${RC} righe=$(righe) ${OUT}"
  fi

  OUT="$(printf '{}' | python3 -B -I "${HOOK}" in-più 2>&1)"
  RC=$?
  if (( RC == 2 )) && [[ "${OUT}" == *"uso:"* ]]; then
    pass "un argomento: uscita 2, l'uso"
  else
    fail "un argomento: rc=${RC} ${OUT}"
  fi

  mkdir -p -- "${TMP}/registro.jsonl"
  hook "$(evento session_start "${p}/CLAUDE.md")"
  if (( RC == 1 )) && [[ "${OUT}" == *"non riesco a scrivere"* ]]; then
    pass "un registro che non si scrive: uscita 1, il motivo"
  else
    fail "registro non scrivibile: rc=${RC} ${OUT}"
  fi
  rmdir -- "${TMP}/registro.jsonl"

  echo "PASS=${PASS} FAIL=${FAIL}"
  (( FAIL == 0 )) || exit 1
}

main "$@"
