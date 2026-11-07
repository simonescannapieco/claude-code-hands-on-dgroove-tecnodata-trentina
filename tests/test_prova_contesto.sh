#!/bin/bash
#
# test_prova_contesto.sh -- le prove di tools/prova_contesto.sh, con un
# claude finto (tests/fixtures/prova_contesto/claude_finto.py) davanti nel
# PATH e un piccolo albero del repository, con il suo manifest, in una
# cartella temporanea:
#   - gli errori negli argomenti, nella configurazione, nelle richieste,
#     l'hook che manca, una v1 senza CLAUDE.md alla radice e una v2 uguale
#     alla v1: uscita 2, nessuna chiamata, niente scritto in prove-contesto/;
#   - il comando da rilanciare, con --radice se c'era;
#   - un giro interrotto da SIGINT, SIGTERM e SIGHUP: 130, 143 e 129, le
#     sessioni ferme, i temporanei e il segno del turno cancellati;
#   - base, v1 e v2 da capo a fondo: le opzioni di claude, la auto memory
#     spenta, che cosa c'è nella copia (in base nessun file di istruzioni,
#     mai gli appunti del team né i percorsi esclusi), prima.sh nel commit di
#     partenza, i file lasciati, la fotografia, il registro dell'hook scritto
#     dall'hook vero, un commit di Claude in commit.txt;
#   - un giro che c'è già o in corso: uscita 2; un'esecuzione fallita: uscita
#     1, le altre finite; le uscite di verifica.py; al massimo tre insieme;
#     nessun temporaneo lasciato; un prompt con virgolette, $ e backtick che
#     arriva intatto.
# Mai il claude vero: la suite controlla che il finto venga prima nel PATH.
#
# Uso:    tests/test_prova_contesto.sh
# Uscita: 0 = tutte le prove passano · 1 = almeno una fallita ·
#         2 = precondizione (manca python3, git o pgrep; il finto non viene
#         prima nel PATH)
# shellcheck disable=SC2016  # backtick e $ sono il testo delle prove
set -uo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly REPO="${SELF%/tests/*}"
readonly TOOL="${REPO}/tools/prova_contesto.sh"
readonly FINTO="${REPO}/tests/fixtures/prova_contesto/claude_finto.py"
readonly HOOK="${REPO}/tools/registra_caricamenti.py"
readonly ID=M6-E09
TMP=''
ALBERO=''
ITEM=''
RADICE=''
WS=''
LOG=''
BASE_TEMP=''
PASS=0
FAIL=0
RC=0
OUT=''
N=0

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

cleanup() {
  if [[ -n "${TMP}" && -d "${TMP}" ]]; then
    rm -rf -- "${TMP}"
  fi
}
trap cleanup EXIT

# Uscita attesa E parole attese (RU-01.T3).
# Arguments: $1 il nome, $2 l'uscita attesa, poi le parole (grep -F).
expect() {
  local nome="$1" atteso="$2" parola
  shift 2
  if (( RC != atteso )); then
    fail "${nome} (uscita ${RC}, attesa ${atteso}): ${OUT:0:600}"
    return 0
  fi
  if grep -qF -- 'Traceback' <<< "${OUT}"; then
    fail "${nome} (un traceback): ${OUT:0:600}"
    return 0
  fi
  for parola in "$@"; do
    if ! grep -qF -- "${parola}" <<< "${OUT}"; then
      fail "${nome} (manca «${parola}»): ${OUT:0:600}"
      return 0
    fi
  done
  pass "${nome}"
}

# Una condizione che è un comando. Arguments: $1 il nome, poi il comando.
vero() {
  local nome="$1"
  shift
  if "$@"; then
    pass "${nome}"
  else
    fail "${nome}"
  fi
}

# Esegue un comando nell'ambiente delle prove; RC e OUT. Gli ambienti in più
# (NOME=valore) arrivano prima di «--».
nell_ambiente() {
  local -a variabili=()
  while (( $# > 0 )) && [[ "$1" != "--" ]]; do
    variabili+=("$1")
    shift
  done
  shift
  OUT="$(env PATH="${TMP}/bin:${PATH}" PN_HANDSON_ROOT="${ALBERO}" \
    PN_WORKSPACE_ROOT="${RADICE}" FINTO_LOG="${LOG}" TMPDIR="${BASE_TEMP}" \
    ${variabili[@]+"${variabili[@]}"} "$@" 2>&1 < /dev/null)"
  RC=$?
}

prova() { nell_ambiente -- "${TOOL}" "$@"; }

# Quante chiamate al claude finto sono nel registro.
chiamate() {
  if [[ -f "${LOG}" ]]; then
    grep -c '"evento": "chiamata"' "${LOG}"
  else
    echo 0
  fi
}

# Python sul registro delle chiamate: stampa ciò che il codice su STDIN
# stampa. Globals: OUT, RC.
registro() {
  OUT="$(PN_LOG="${LOG}" python3 -B -I - 2>&1)"
  RC=$?
}

richieste_buone() {
  {
    printf 'id\tstrumenti\tprompt\n'
    printf 't1\tRead,Glob,Grep,Bash\tEsegui i test: «virgolette» "doppie" $HOME `ls`\n'
    printf 't2\tRead,Edit,Bash\tCOMMIT il refuso\n'
    printf 't3\tRead\tChe cosa fa questo progetto?\n'
  } > "${ITEM}/prove/richieste.tsv"
}

config_buona() {
  printf '%s\n' '# le prove' modello=sonnet effort=low \
    'escludi=appunti-del-team.md progetti/x/vendor' \
    'vietati=Bash(sudo *),Bash(git push *)' > "${ITEM}/prove/config"
}

# L'albero del repository, una volta per tutte.
crea_albero() {
  ALBERO="${TMP}/albero"
  ITEM="${ALBERO}/m6_prova/s5_prova/m6_e2_prova/${ID}_prova"
  local es="${ITEM}/esercizio"
  mkdir -p "${ALBERO}/tools" "${ALBERO}/.claude" "${ITEM}/prove" \
    "${es}/.claude/hooks" "${es}/progetti/x/vendor"
  cp "${REPO}"/tools/*.py "${ALBERO}/tools/"
  printf '{}\n' > "${ALBERO}/.claude/settings.json"
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' id kind env section_dir \
    subdeck_dir deck_path minutes title_it > "${ALBERO}/m6_prova/manifest.tsv"
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "${ID}" esercizio claude-code-pro \
    s5_prova m6_e2_prova slides/practice/m6_prova/m6_e2_prova 59 Prova \
    >> "${ALBERO}/m6_prova/manifest.tsv"
  cp "${HOOK}" "${es}/.claude/hooks/registra_caricamenti.py"
  printf '%s\n' '{"hooks": {"InstructionsLoaded": [{"hooks": [{"type":' \
    '"command", "command": "python3 \"$CLAUDE_PROJECT_DIR/.claude/hooks/registra_caricamenti.py\""}]}]}}' \
    > "${es}/.claude/settings.json"
  printf 'C'"'"'è un refusso.\n' > "${es}/LEGGIMI.txt"
  printf 'La forma dei commit: segreta.\n' > "${es}/appunti-del-team.md"
  printf 'una dipendenza\n' > "${es}/progetti/x/vendor/a.txt"
  printf 'codice\n' > "${es}/progetti/x/a.php"
  cat > "${ITEM}/prove/prima.sh" <<'EOF'
#!/bin/bash
set -euo pipefail
printf 'prima %s\n' "$2" > "$1/PRIMA.txt"
EOF
  chmod +x "${ITEM}/prove/prima.sh"
  cat > "${ITEM}/verifica.py" <<'EOF'
"""verifica.py di un elemento finto, per le prove di prova_contesto.sh."""
import os
import sys

leva = os.environ.get("PROVA_USCITA")
if leva:
    sys.exit(int(leva))
print("SOLO-PROVE" if "--solo-prove" in sys.argv[2:] else "VERIFICA")
EOF
  config_buona
  richieste_buone
  git -C "${ALBERO}" init -q
}

# Uno spazio di lavoro nuovo, con il suo registro.
nuovo_ws() {
  N=$((N + 1))
  RADICE="${TMP}/r${N}"
  LOG="${TMP}/log${N}.jsonl"
  BASE_TEMP="${TMP}/temp${N}"
  WS="${RADICE}/${ID}"
  mkdir -p "${BASE_TEMP}"
  nell_ambiente -- "${REPO}/tools/prepara_esercizio.sh" "${ID}"
  if (( RC != 0 )); then
    echo "test_prova_contesto: prepara_esercizio.sh non riesce: ${OUT}" >&2
    exit 2
  fi
}

prove_argomenti() {
  echo "Argomenti, configurazione, richieste, hook"
  nuovo_ws
  prova
  expect "senza argomenti: l'uso" 2 "Uso: tools/prova_contesto.sh"
  prova "${ID}" v3
  expect "una versione che non c'è" 2 "la versione è base, v1 o v2"
  prova "${ID}" base --forse
  expect "un'opzione sconosciuta" 2 "opzione sconosciuta: --forse"
  printf 'colore=blu\n' > "${ITEM}/prove/config"
  prova "${ID}" base
  expect "una chiave sconosciuta in prove/config" 2 "chiave sconosciuta"
  printf 'escludi=../fuori\n' > "${ITEM}/prove/config"
  prova "${ID}" base
  expect "un percorso di escludi= che esce" 2 "un percorso di «escludi=»"
  config_buona
  printf 'id strumenti prompt\nt1\tRead\tx\n' > "${ITEM}/prove/richieste.tsv"
  prova "${ID}" base
  expect "un'intestazione senza tabulazioni" 2 "l'intestazione"
  printf 'id\tstrumenti\tprompt\nt1\tBash(git *)\tx\n' \
    > "${ITEM}/prove/richieste.tsv"
  prova "${ID}" base
  expect "strumenti con una regola" 2 "gli strumenti sono nomi"
  printf 'id\tstrumenti\tprompt\nt1\tRead\tx\nt1\tRead\ty\n' \
    > "${ITEM}/prove/richieste.tsv"
  prova "${ID}" base
  expect "un id ripetuto" 2 "id ripetuto"
  richieste_buone
  mv "${WS}/.claude/settings.json" "${TMP}/settings.json"
  prova "${ID}" base
  expect "l'hook che manca nello spazio di lavoro" 2 "manca l'hook"
  mv "${TMP}/settings.json" "${WS}/.claude/settings.json"
  if (( $(chiamate) == 0 )); then
    pass "nessuna chiamata per un errore di partenza"
  else
    fail "nessuna chiamata per un errore di partenza: $(chiamate) chiamate"
  fi
  prova "${ID}" v1
  expect "v1 senza CLAUDE.md alla radice: 2, prima di ogni chiamata" 2 \
    "v1 non ha un CLAUDE.md alla radice dello spazio di lavoro" \
    "tools/prova_contesto.sh ${ID} v1"
  if (( $(chiamate) == 0 )) && [[ ! -e "${WS}/prove-contesto/v1" ]]; then
    pass "v1 senza CLAUDE.md: nessuna chiamata, prove-contesto/v1 non c'è"
  else
    fail "v1 senza CLAUDE.md: $(chiamate) chiamate, o prove-contesto/v1 c'è"
  fi
}

prove_base() {
  echo "base"
  nuovo_ws
  printf '# Istruzioni\n- Il comando dei test.\n' > "${WS}/CLAUDE.md"
  mkdir -p "${WS}/.claude/rules"
  printf 'Una regola.\n' > "${WS}/.claude/rules/r.md"
  prova "${ID}" base
  expect "base: tre esecuzioni, poi il controllo" 0 "parte t1" \
    "finita t2" "finita t3" "SOLO-PROVE"
  if (( $(chiamate) == 3 )); then
    pass "base: tre chiamate"
  else
    fail "base: tre chiamate, non $(chiamate)"
  fi
  registro <<'EOF'
import json, os
righe = [json.loads(r) for r in open(os.environ["PN_LOG"], encoding="utf-8")]
for r in righe:
    a = r["argv"]
    print("opzioni", "--tools" in a, "--disallowedTools" in a,
          a[a.index("--effort") + 1], a[a.index("--permission-mode") + 1],
          "--strict-mcp-config" in a, "--no-session-persistence" in a)
    print("memoria", r["memoria_spenta"])
    vietati = [f for f in r["file"] if f in ("CLAUDE.md", ".claude/rules/r.md",
               "appunti-del-team.md", "progetti/x/vendor/a.txt")]
    print("vietati", vietati)
    print("prima", "PRIMA.txt" in r["partenza"])
print("prompt", [r["prompt"] for r in righe if "test" in r["prompt"]])
EOF
  expect "base: --tools, --disallowedTools, effort low, dontAsk" 0 \
    "opzioni True True low dontAsk True True"
  expect "base: la auto memory spenta in ogni esecuzione" 0 "memoria 1"
  if grep -qF "vietati ['" <<< "${OUT}"; then
    fail "base: un file che la copia non deve avere: ${OUT}"
  else
    pass "base: nessun file di istruzioni, né appunti né percorsi esclusi"
  fi
  expect "base: prima.sh nel commit di partenza" 0 "prima True"
  expect "base: il prompt intatto, virgolette, \$ e backtick" 0 \
    'Esegui i test: «virgolette» "doppie" $HOME `ls`'
  local u="${WS}/prove-contesto/base"
  vero "base: i file di ogni esecuzione" test -s "${u}/t1/stream.jsonl" \
    -a -f "${u}/t1/prompt.txt" -a -f "${u}/t1/strumenti.txt" \
    -a -f "${u}/t1/file-cambiati.txt" -a -f "${u}/t1/commit.txt" \
    -a -f "${u}/t1/file-committati.txt" -a -f "${u}/t1/caricamenti.jsonl" \
    -a -f "${u}/t1/diff.txt"
  vero "base: il registro dell'hook vuoto, niente caricato" \
    test ! -s "${u}/t1/caricamenti.jsonl"
  vero "base: la fotografia ha soltanto settings.json" test \
    "$(cd "${u}/fotografia" && find . -type f | LC_ALL=C sort | tr '\n' ' ')" \
    = "./.claude/settings.json "
  vero "base: nessun temporaneo lasciato" test -z "$(ls -A "${BASE_TEMP}")"
  prova "${ID}" base
  expect "un giro che c'è già: non si sovrascrive" 2 "c'è già" \
    "cancella ${u}" "rilancia: tools/prova_contesto.sh ${ID} base"
  if grep -qF -- '--radice' <<< "${OUT}"; then
    fail "senza --radice, il comando da rilanciare non la nomina: ${OUT}"
  else
    pass "senza --radice, il comando da rilanciare non la nomina"
  fi
  nell_ambiente PN_WORKSPACE_ROOT="${TMP}/altrove" -- "${TOOL}" "${ID}" base \
    --radice "${RADICE}"
  expect "con --radice, il comando da rilanciare la ripete" 2 "c'è già" \
    "rilancia: tools/prova_contesto.sh ${ID} base --radice ${RADICE}"
}

prove_v1() {
  echo "v1 e v2"
  local u="${WS}/prove-contesto/v1"
  prova "${ID}" v1
  expect "v1: tre esecuzioni" 0 "finita t1" "finita t2" "finita t3"
  vero "v1: il registro dell'hook scritto dall'hook vero, CLAUDE.md all'avvio" \
    grep -qF '"load_reason": "session_start", "file_path": "CLAUDE.md"' \
    "${u}/t3/caricamenti.jsonl"
  vero "v1: la fotografia con CLAUDE.md, la regola e settings.json" test \
    "$(cd "${u}/fotografia" && find . -type f | LC_ALL=C sort | tr '\n' ' ')" \
    = "./.claude/rules/r.md ./.claude/settings.json ./CLAUDE.md "
  vero "v1: il commit di Claude in commit.txt" \
    grep -qF 'docs: corregge il refuso' "${u}/t2/commit.txt"
  vero "v1: i file del commit in file-committati.txt" \
    grep -qxF 'LEGGIMI.txt' "${u}/t2/file-committati.txt"
  vero "v1: un'esecuzione senza commit ha commit.txt vuoto" \
    test ! -s "${u}/t1/commit.txt"
  vero "v1: la riga aggiunta da Claude in diff.txt" \
    grep -qxF '+corretto' "${u}/t2/diff.txt"
  vero "v1: lo spazio di lavoro non cambia" \
    grep -qF 'refusso' "${WS}/LEGGIMI.txt"
  mkdir -- "${RADICE}/.${ID}.prove-in-corso"
  prova "${ID}" v2
  expect "un giro già in corso" 2 "c'è già un giro di prove in corso"
  rmdir -- "${RADICE}/.${ID}.prove-in-corso"
  local prima
  prima="$(chiamate)"
  prova "${ID}" v2
  expect "v2 uguale a v1: 2, prima di ogni chiamata" 2 "v2 è uguale a v1" \
    "tools/prova_contesto.sh ${ID} v2"
  if (( $(chiamate) == prima )) && [[ ! -e "${WS}/prove-contesto/v2" ]]; then
    pass "v2 uguale a v1: nessuna chiamata, prove-contesto/v2 non c'è"
  else
    fail "v2 uguale a v1: $(( $(chiamate) - prima )) chiamate, o c'è v2"
  fi
  printf -- '- Una riga in più.\n' >> "${WS}/CLAUDE.md"
  nell_ambiente FINTO_KO_SU=COMMIT -- "${TOOL}" "${ID}" v2
  expect "un'esecuzione fallita: uscita 1, le altre finite" 1 \
    "FALLITA t2" "finita t1" "finita t3"
  rm -rf -- "${WS}/prove-contesto/v2"
  nell_ambiente PROVA_USCITA=1 -- "${TOOL}" "${ID}" v2
  expect "verifica.py esce 1: uscita 1" 1 "finita t3"
  rm -rf -- "${WS}/prove-contesto/v2"
  nell_ambiente PROVA_USCITA=2 -- "${TOOL}" "${ID}" v2
  expect "verifica.py esce 2: uscita 2, il motivo" 2 \
    "verifica.py non ha potuto leggere le prove"
}

prove_insieme() {
  echo "Al massimo tre insieme"
  nuovo_ws
  {
    printf 'id\tstrumenti\tprompt\n'
    printf 'r%d\tRead\tuna richiesta\n' 1 2 3 4 5
  } > "${ITEM}/prove/richieste.tsv"
  nell_ambiente FINTO_PAUSA=1 -- "${TOOL}" "${ID}" base
  expect "cinque richieste, tutte finite" 0 "finita r5"
  registro <<'EOF'
import json, os
eventi = []
for riga in open(os.environ["PN_LOG"], encoding="utf-8"):
    r = json.loads(riga)
    if r.get("evento") in ("inizio", "fine"):
        eventi.append((r["t"], 1 if r["evento"] == "inizio" else -1))
vive = massimo = 0
for _, d in sorted(eventi):
    vive += d
    massimo = max(massimo, vive)
print("massimo", massimo)
EOF
  expect "mai più di tre esecuzioni insieme" 0 "massimo 3"
  richieste_buone
}

# Quante sessioni del claude finto sono vive. Outputs: il numero.
vive() {
  local n
  n="$(pgrep -f -c -- "${TMP}/bin/claude")"
  echo "${n:-0}"
}

# Un giro interrotto da un segnale, con tre sessioni in corso: l'uscita
# 128 + n, le sessioni ferme, le copie e il segno del turno cancellati (il
# contratto nella testata dello strumento). Con set -m il giro sullo sfondo
# ha il suo gruppo di processi: un SIGINT non è ignorato, come lo sarebbe in
# un job di uno script. Arguments: $1 il segnale, $2 l'uscita attesa.
un_segnale() {
  local pid rc=0 i n=0
  nuovo_ws
  set -m
  env PATH="${TMP}/bin:${PATH}" PN_HANDSON_ROOT="${ALBERO}" \
    PN_WORKSPACE_ROOT="${RADICE}" FINTO_LOG="${LOG}" TMPDIR="${BASE_TEMP}" \
    FINTO_PAUSA=30 "${TOOL}" "${ID}" base > "${TMP}/segnale.txt" 2>&1 \
    < /dev/null &
  pid=$!
  set +m
  for (( i = 0; i < 300; i++ )); do
    n="$(grep -c '"evento": "inizio"' "${LOG}" 2> /dev/null)"
    if (( ${n:-0} >= 3 )); then
      break
    fi
    sleep 0.1
  done
  kill -s "$1" "${pid}"
  wait "${pid}" 2> /dev/null || rc=$?
  for (( i = 0; i < 30; i++ )); do
    if (( $(vive) == 0 )); then
      break
    fi
    sleep 0.1
  done
  OUT="$(< "${TMP}/segnale.txt")"
  RC="${rc}"
  expect "SIG$1 con tre sessioni in corso: uscita $2, e lo dice" "$2" \
    "Interrotto: le esecuzioni in corso sono ferme"
  if (( ${n:-0} >= 3 && $(vive) == 0 )) && [[ -z "$(ls -A "${BASE_TEMP}")" \
      && ! -e "${RADICE}/.${ID}.prove-in-corso" ]]; then
    pass "SIG$1: nessuna sessione viva, né copie né il segno del turno"
  else
    fail "SIG$1: partite ${n:-0}, vive $(vive), temporanei «$(ls -A \
      "${BASE_TEMP}")»"
  fi
}

prove_segnali() {
  echo "Un giro interrotto"
  un_segnale INT 130
  un_segnale TERM 143
  un_segnale HUP 129
}

main() {
  local t
  for t in python3 git pgrep; do
    command -v "${t}" >/dev/null 2>&1 || { echo "manca ${t}" >&2; exit 2; }
  done
  TMP="$(mktemp -d)"
  mkdir -p "${TMP}/bin"
  cp "${FINTO}" "${TMP}/bin/claude"
  chmod +x "${TMP}/bin/claude"
  if [[ "$(PATH="${TMP}/bin:${PATH}" command -v claude)" != "${TMP}/bin/claude" ]]
  then
    echo "test_prova_contesto: il claude finto non viene prima nel PATH" >&2
    exit 2
  fi
  crea_albero
  prove_argomenti
  prove_base
  prove_v1
  prove_insieme
  prove_segnali
  echo "PASS=${PASS} FAIL=${FAIL}"
  (( FAIL == 0 )) || exit 1
}

main "$@"
