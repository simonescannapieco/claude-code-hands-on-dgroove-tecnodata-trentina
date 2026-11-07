#!/bin/bash
#
# Test di tools/lib_leggi_contesto.py: i token della prima richiesta (solo la
# sessione principale), i comandi Bash e i loro risultati, il modello, il
# registro dell'hook InstructionsLoaded; ogni cosa che non si legge è un
# Problema (uscita 2 del driver), mai un elenco più corto. Gli stream sono
# sintetici, scritti qui in una cartella temporanea.
#
# Uso:    bash tests/test_lib_leggi_contesto.sh
# Uscita: 0 tutti i test superati · 1 almeno un test fallito ·
#         2 precondizione (python3 mancante, la libreria che non c'è)
set -uo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
ROOT="$(dirname "$(dirname "${SELF}")")"
readonly ROOT
readonly LIB="${ROOT}/tools/lib_leggi_contesto.py"

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

# Il driver: legge con la libreria il file $2 come $1 (stream, bash o
# registro) e stampa ciò che ha letto; un Problema esce 2 con il messaggio.
# Globals: OUT, RC.
leggi() {
  OUT="$(timeout 60 python3 -B -I - "${ROOT}/tools" "$1" "$2" 2>&1 <<'EOF'
import sys
sys.path.insert(0, sys.argv[1])
import lib_leggi_contesto as lc
modo, percorso = sys.argv[2], sys.argv[3]
try:
    if modo == "stream":
        c = lc.leggi_contesto(percorso)
        print("prima=%d" % c.prima_richiesta)
        print("comandi=%s" % c.comandi)
        print("modello=%s" % c.modello)
        print("turni=%d" % c.esecuzione.turni)
        for k in sorted(c.risultati):
            print("risultato %s=%r errore=%s" % (k, c.risultati[k].testo,
                                                 c.risultati[k].errore))
    elif modo == "bash":
        for comando, r in lc.risultati_bash(percorso):
            print("bash %r -> %r errore=%s" % (comando, r.testo, r.errore))
    else:
        cc = lc.leggi_caricamenti(percorso)
        print("righe=%d" % len(cc))
        for c in cc:
            print("%s %s trigger=%s globs=%s" % (c.load_reason, c.file_path,
                                                 c.trigger_file_path, c.globs))
        print("avvio=%s" % lc.caricati(cc, "session_start"))
except lc.Problema as exc:
    print("PROBLEMA %s" % exc)
    sys.exit(2)
EOF
)"
  RC=$?
}

# Arguments: $1 nome, $2 rc atteso, $3 parola che l'uscita deve avere,
# $4 parola che non deve avere (facoltativa).
expect() {
  if (( RC == $2 )) && grep -qF -- "$3" <<<"${OUT}" \
      && { [[ -z "${4:-}" ]] || ! grep -qF -- "$4" <<<"${OUT}"; }; then
    pass "$1"
  else
    fail "$1: rc=${RC}, attesi $2 e «$3»: ${OUT:0:400}"
  fi
}

# Uno stream sintetico: init, un messaggio di un subagent, il primo della
# sessione principale con usage, un Bash con il suo risultato, un result.
# Arguments: $1 il file, $2 l'usage del primo messaggio principale.
stream() {
  {
    echo '{"type":"system","subtype":"init","model":"claude-sonnet-5-5"}'
    echo '{"type":"assistant","parent_tool_use_id":"t0","message":{"usage":{"input_tokens":7,"cache_creation_input_tokens":0,"cache_read_input_tokens":0},"content":[]}}'
    printf '%s%s%s\n' '{"type":"assistant","parent_tool_use_id":null,' \
      "\"message\":{\"usage\":$2,\"content\":[{\"type\":\"tool_use\"," \
      '"id":"b1","name":"Bash","input":{"command":"ls -1"}}]}}'
    echo '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"b1","content":[{"type":"text","text":"a"},{"type":"text","text":"b"}]}]}}'
    echo '{"type":"assistant","parent_tool_use_id":null,"message":{"usage":{"input_tokens":1,"cache_creation_input_tokens":0,"cache_read_input_tokens":9000},"content":[{"type":"tool_use","id":"b2","name":"Bash","input":{"command":"git status"}}]}}'
    echo '{"type":"result","subtype":"success","num_turns":3,"duration_ms":1500,"result":"fatto","usage":{"input_tokens":1,"cache_creation_input_tokens":2,"cache_read_input_tokens":3,"output_tokens":4}}'
  } >"$1"
}

main() {
  command -v python3 >/dev/null 2>&1 || { echo "manca python3" >&2; exit 2; }
  [[ -r "${LIB}" ]] || { echo "manca ${LIB}" >&2; exit 2; }
  TMP="$(mktemp -d)"

  echo "lib_leggi_contesto.py: gli stream"
  stream "${TMP}/s.jsonl" \
    '{"input_tokens":3,"cache_creation_input_tokens":1000,"cache_read_input_tokens":2000}'
  leggi stream "${TMP}/s.jsonl"
  expect "la prima richiesta: la somma dei tre campi del primo messaggio" \
    0 "prima=3003"
  expect "il subagent non conta per la prima richiesta" 0 "prima=3003" \
    "prima=7"
  expect "i comandi Bash, nell'ordine" 0 "comandi=['ls -1', 'git status']"
  expect "il modello dall'evento init" 0 "modello=claude-sonnet-5-5"
  expect "i turni sommati da lib_leggi_stream" 0 "turni=3"
  expect "un tool_result in blocchi di testo: uniti" 0 \
    "risultato b1='a\nb' errore=False"

  leggi bash "${TMP}/s.jsonl"
  expect "risultati_bash: un comando senza risultato è vuoto ed errore" 0 \
    "bash 'git status' -> '' errore=True"
  expect "risultati_bash: il comando con il suo risultato" 0 \
    "bash 'ls -1' -> 'a\nb' errore=False"

  stream "${TMP}/neg.jsonl" \
    '{"input_tokens":-1,"cache_creation_input_tokens":0,"cache_read_input_tokens":0}'
  leggi stream "${TMP}/neg.jsonl"
  expect "un conteggio negativo: Problema" 2 "non valido"

  grep -v '"usage"' "${TMP}/s.jsonl" | grep -v '"type":"result"' \
    >"${TMP}/senza.jsonl"
  echo '{"type":"result","subtype":"success","num_turns":1,"duration_ms":1,"result":"x","usage":{"input_tokens":0,"cache_creation_input_tokens":0,"cache_read_input_tokens":0,"output_tokens":0}}' \
    >>"${TMP}/senza.jsonl"
  leggi stream "${TMP}/senza.jsonl"
  expect "nessun messaggio con usage: Problema" 2 "la prima richiesta non si legge"

  sed 's/"input":{"command":"ls -1"}/"input":{}/' "${TMP}/s.jsonl" \
    >"${TMP}/nocmd.jsonl"
  leggi stream "${TMP}/nocmd.jsonl"
  expect "un Bash senza comando: Problema" 2 "senza input.command"

  leggi stream "${TMP}/non-c-e.jsonl"
  expect "uno stream che non c'è: Problema" 2 "PROBLEMA"

  echo "lib_leggi_contesto.py: il registro dell'hook"
  printf '%s\n' \
    '{"load_reason": "session_start", "file_path": "CLAUDE.md", "memory_type": "Project", "trigger_file_path": null, "parent_file_path": null, "globs": null}' \
    '{"load_reason": "include", "file_path": "docs/a.md", "memory_type": "Project", "trigger_file_path": null, "parent_file_path": "CLAUDE.md", "globs": null}' \
    '{"load_reason": "path_glob_match", "file_path": ".claude/rules/legacy.md", "memory_type": "Project", "trigger_file_path": "legacy/a.php", "parent_file_path": null, "globs": ["legacy/**"]}' \
    '{"load_reason": "session_start", "file_path": "CLAUDE.md", "memory_type": "Project", "trigger_file_path": null, "parent_file_path": null, "globs": null}' \
    >"${TMP}/r.jsonl"
  leggi registro "${TMP}/r.jsonl"
  expect "quattro righe, nell'ordine" 0 "righe=4"
  expect "una regola con paths: il file che l'ha fatta caricare e i glob" 0 \
    "path_glob_match .claude/rules/legacy.md trigger=legacy/a.php globs=['legacy/**']"
  expect "caricati all'avvio: ciascuno una volta" 0 "avvio=['CLAUDE.md']" \
    "avvio=['CLAUDE.md', 'CLAUDE.md']"

  : >"${TMP}/vuoto.jsonl"
  leggi registro "${TMP}/vuoto.jsonl"
  expect "un registro vuoto: niente caricato, nessun Problema" 0 "righe=0"

  leggi registro "${TMP}/assente.jsonl"
  expect "un registro che non c'è: Problema" 2 "non riesco a leggere il registro"

  printf '%s\n' '{"load_reason": "per caso", "file_path": "CLAUDE.md"}' \
    >"${TMP}/motivo.jsonl"
  leggi registro "${TMP}/motivo.jsonl"
  expect "un load_reason sconosciuto: Problema" 2 "load_reason sconosciuto"

  printf 'non json\n' >"${TMP}/rotto.jsonl"
  leggi registro "${TMP}/rotto.jsonl"
  expect "una riga che non è JSON: Problema, con il numero" 2 "riga 1: non è JSON"

  printf '%s\n' '{"load_reason": "include", "file_path": ""}' \
    >"${TMP}/vuota.jsonl"
  leggi registro "${TMP}/vuota.jsonl"
  expect "un file_path vuoto: Problema" 2 "«file_path» non è un testo"

  echo "PASS=${PASS} FAIL=${FAIL}"
  (( FAIL == 0 )) || exit 1
}

main "$@"
