#!/bin/bash
#
# test_m6_d02.sh -- le prove di M6-D02 «Che cosa entra all'avvio, e che cosa
# quando serve», per il docente (sta in _docente/, il materiale del docente):
#   - l'elemento: i nove posti di progetto/ con un segnaposto ciascuno, il
#     commento a blocco, l'import e il percorso fra backtick, la regola con
#     paths; l'hook identico a tools/registra_caricamenti.py e cablato in
#     .claude/settings.json; i quattro bracci di costo, ognuno la base più una
#     cosa sola, e procedura.md uguale alla scheda KB-10 byte per byte; le
#     frasi di Anthropic nel README, nessun nome interno;
#   - prepara_esercizio.sh e verifica.sh sul punto di partenza (1);
#   - demo/in_classe.sh con il claude finto: le chiamate e le loro opzioni,
#     ogni chiamata nella sua copia fuori dallo spazio di lavoro con le sue
#     parole, nessuna risposta lì mentre le sessioni girano, senza
#     ANTHROPIC_API_KEY, la auto memory spenta; le parole casuali; le
#     precondizioni (2, nessuna chiamata);
#   - controlla_caricamento.py: ogni garanzia che non regge (1, «non
#     confermata»), ogni esecuzione che non la mette alla prova (1, «non
#     distinguibile»), nessun falso allarme sulla parola del file letto; i file
#     rovinati (1), le precondizioni (2), mai un traceback;
#   - verifica.sh: il controllo dell'elemento, mai quello dello spazio di
#     lavoro; _docente/live.sh: tre esecuzioni, le precondizioni;
#   - check_handson.sh senza segnalazioni su questo elemento; shellcheck.
# Mai il claude vero: il finto sta davanti nel PATH, e la suite lo controlla
# prima di usarlo. Gli stream del finto non sono risposte di Claude: provano il
# controllo, non il modello. Gli spazi di lavoro nascono in una cartella
# temporanea, nella base di handson::init_temp_base (mai dentro ~/.claude):
# l'albero del repository non cambia. CASES è il numero dei casi: se ne girano
# di più o di meno la suite esce 2.
#
# Uso:    m6_projects_context/_docente/test_m6_d02.sh
# Uscita: 0 = tutti i casi passano · 1 = almeno un caso fallito · 2 =
#         precondizione (manca python3, git o shellcheck; il finto non viene
#         prima nel PATH), o un numero di casi diverso da CASES
# shellcheck disable=SC2016  # backtick e $ sono il testo delle prove
set -uo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly MOD="${SELF%/_docente/*}"
readonly RADICE="${MOD%/*}"
readonly D02="${MOD}/s5_projects_context/m6_3_claude_md/M6-D02_che_cosa_entra"
readonly CONTROLLO="${D02}/demo/controlla_caricamento.py"
readonly FINTO_PY="${MOD}/_docente/claude_finto_m6_d02_d04.py"
# La libreria del repository, per la base dei file temporanei.
# shellcheck source=../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"
readonly CASES=196
readonly L_AVVIO="All'avvio si caricano CLAUDE.md, CLAUDE.local.md e la regola senza paths"
readonly L_IMPORT='Il file importato con @ si carica con CLAUDE.md'
readonly L_BACKTICK='Un percorso fra backtick non si importa'
readonly L_COMMENTO='Il commento HTML a blocco non entra nel contesto'
readonly L_RICHIESTA="La regola con paths e il CLAUDE.md di sub/ non si caricano all'avvio"
readonly L_REGOLA='La regola con paths si carica quando Claude legge un file che corrisponde'
readonly L_ANNIDATO='Il CLAUDE.md di sub/ si carica quando Claude legge un file di sub/'
readonly NONCONF='non confermata in questa esecuzione'
readonly NONDIST='non distinguibile'
readonly TUTTE='Ogni garanzia è confermata in ogni esecuzione.'
readonly FATTO='Fatto: ogni garanzia è stata messa alla prova'
readonly POSTI=(RADICE COMMENTO IMPORTATO CITATO LOCALE REGOLA REGOLAPHP
  ANNIDATO LETTO)
readonly FILE_POSTI=(CLAUDE.md CLAUDE.md docs/glossario.md docs/escluso.md
  CLAUDE.local.md .claude/rules/generale.md .claude/rules/php.md
  sub/CLAUDE.md sub/nota.txt)
TMP=''
PASS=0
FAIL=0
SKIP=0
RC=0
OUT=''
TUTTO=''
BUONO=''

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
    fail "$1 (rc=${RC}, attesa $2, parola «$3»): ${OUT:0:900}"
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

# Un caso che passa se il comando riesce. Arguments: $1 il nome, poi il
# comando.
vero() {
  local nome="$1"
  shift
  if "$@"; then
    pass "${nome}"
  else
    fail "${nome}"
  fi
}

# Il claude finto davanti nel PATH, e la prova che è lui.
prepara_claude() {
  mkdir -p "${TMP}/finto" "${TMP}/t" || exit 2
  cp -- "${FINTO_PY}" "${TMP}/finto/claude" || exit 2
  chmod +x "${TMP}/finto/claude" || exit 2
  export PATH="${TMP}/finto:${PATH}"
  export HANDSON_NO_PAUSE=1
  unset ANTHROPIC_API_KEY CLAUDE_CODE_EFFORT_LEVEL HANDSON_ENV PN_HANDSON_ROOT
  [[ "$(command -v claude)" == "${TMP}/finto/claude" ]] \
    || { echo "test_m6_d02: il finto non viene prima nel PATH" >&2; exit 2; }
}

# Uno spazio di lavoro nuovo, con prepara_esercizio.sh in una radice nuova.
# Arguments: $1 la variabile da assegnare. Returns: 0; 1 se non riesce.
nuovo_ws() {
  local __r
  __r="$(mktemp -d "${TMP}/radice.XXXXXX")" || exit 2
  "${RADICE}/tools/prepara_esercizio.sh" M6-D02 --radice "${__r}" \
    > "${TMP}/prepara.log" 2>&1 || return 1
  printf -v "$1" '%s' "${__r}/M6-D02"
}

# in_classe.sh dell'elemento sullo spazio di lavoro $1, con le variabili che
# seguono (NOME=valore); RC e OUT come run. Una riga per chiamata in
# $TMP/log.jsonl.
in_classe() {
  local w="$1"
  shift
  : > "${TMP}/log.jsonl"
  run env FINTO_LOG="${TMP}/log.jsonl" FINTO_SPAZIO="${w}" TMPDIR="${TMP}/t" \
    "$@" "${D02}/demo/in_classe.sh" "${w}"
}

# controlla_caricamento.py dell'elemento; RC e OUT come run.
controlla() { run python3 -B -I "${CONTROLLO}" "$@"; }

# Una copia di risposte/ dello spazio di lavoro buono, da rovinare.
# Arguments: $1 la variabile da assegnare.
copia_buona() {
  local __c
  __c="$(mktemp -d "${TMP}/copia.XXXXXX")" || exit 2
  cp -R "${BUONO}/risposte" "${__c}/" || exit 2
  printf -v "$1" '%s' "${__c}"
}

# Il numero di chiamate al finto in $TMP/log.jsonl.
chiamate() { grep -c '"argv"' "${TMP}/log.jsonl"; }

# Una riga di uno stream cambiata con Python.
# Arguments: $1 il file, $2 il codice Python: riceve `e`, l'evento, e lo cambia.
cambia_eventi() {
  python3 -B -I - "$1" "$2" <<'PY' || exit 2
import json, sys
percorso, codice = sys.argv[1:3]
righe = [json.loads(r) for r in open(percorso, encoding="utf-8")]
for e in righe:
    exec(codice)
with open(percorso, "w", encoding="utf-8") as fh:
    for e in righe:
        fh.write(json.dumps(e, ensure_ascii=False) + "\n")
PY
}

# ---------------------------------------------------------------- l'elemento

t_elemento() {
  local f
  for f in README.md verifica.sh demo/in_classe.sh demo/lib_caricamento.sh \
      demo/controlla_caricamento.py demo/domanda_avvio.txt \
      demo/domanda_lettura.txt demo/domanda_costo.txt _docente/live.sh \
      soluzione/LEGGIMI.md; do
    vero "c'è ${f}" test -f "${D02}/${f}"
  done
  vero "verifica.sh è eseguibile" test -x "${D02}/verifica.sh"
  vero "live.sh è eseguibile" test -x "${D02}/_docente/live.sh"
  vero "in_classe.sh è eseguibile" test -x "${D02}/demo/in_classe.sh"
  vero "la libreria non è eseguibile" test ! -x "${D02}/demo/lib_caricamento.sh"
  if [[ -z "$(command find "${D02}/demo" -name '*.parole.json')" ]] \
      && ! grep -rqE '\b[A-Z]+-[A-Z]{6}\b' "${D02}/demo/progetto"; then
    pass "nessuna parola nel repository, solo i segnaposto"
  else
    fail "nessuna parola nel repository, solo i segnaposto"
  fi
  run bash -c 'source "$1" && source "$2" && caricamento::sostituisci "$3" \
    RADICE PAROLA-ABCDEF' _ "${RADICE}/tools/lib_handson.sh" \
    "${D02}/demo/lib_caricamento.sh" "${TMP}/non-c-e.md"
  if (( RC != 0 )) && [[ ! -e "${TMP}/non-c-e.md" ]]; then
    pass "un file che non si legge: la sostituzione fallisce, niente scritto"
  elif [[ -e "${TMP}/non-c-e.md" ]]; then
    fail "un file che non si legge: rc=${RC}, e il file è stato scritto"
  else
    fail "un file che non si legge: rc=${RC}, attesa diversa da 0"
  fi
}

# I nove posti: ogni segnaposto una volta sola, nel suo file.
t_progetto() {
  local p="${D02}/demo/progetto" i chiave quante
  for (( i = 0; i < ${#POSTI[@]}; i++ )); do
    chiave="${POSTI[i]}"
    quante="$(grep -rlF -- "__${chiave}__" "${p}" | wc -l)"
    if (( quante == 1 )) && grep -qF -- "__${chiave}__" "${p}/${FILE_POSTI[i]}"
    then
      pass "il segnaposto ${chiave} sta solo in ${FILE_POSTI[i]}"
    else
      fail "il segnaposto ${chiave} sta solo in ${FILE_POSTI[i]}"
    fi
  done
  run python3 -B -I - "${p}/CLAUDE.md" <<'PY'
import re, sys
testo = open(sys.argv[1], encoding="utf-8").read()
righe = testo.splitlines()
inizio, fine = righe.index("<!--"), righe.index("-->")
assert righe[inizio - 1] == "" and righe[fine + 1] == "", "il commento non è a blocco"
assert "__COMMENTO__" in "\n".join(righe[inizio:fine + 1])
assert "__COMMENTO__" not in "\n".join(righe[:inizio] + righe[fine + 1:])
fuori = re.sub(r"`[^`]*`", "", testo)
assert re.findall(r"(?<![\w`])@([\w./-]+)", fuori) == ["docs/glossario.md"]
assert "`@docs/escluso.md`" in testo
print("ok, CLAUDE.md")
PY
  expect "CLAUDE.md: il commento a blocco, un import, il backtick" 0 'ok, CLAUDE.md'
  vero "la regola con paths ha il frontmatter **/*.php" grep -qxF '  - "**/*.php"' \
    "${p}/.claude/rules/php.md"
  vero "la regola con paths comincia con ---" test "$(head -n 1 \
    "${p}/.claude/rules/php.md")" == '---'
  vero "la regola generale non ha frontmatter" test "$(head -n 1 \
    "${p}/.claude/rules/generale.md")" != '---'
  vero "l'hook è identico a tools/registra_caricamenti.py" cmp -s \
    "${RADICE}/tools/registra_caricamenti.py" \
    "${p}/.claude/hooks/registra_caricamenti.py"
  run python3 -B -I - "${p}/.claude/settings.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
comandi = [h["command"] for g in d["hooks"]["InstructionsLoaded"] for h in g["hooks"]]
assert comandi == ['python3 "$CLAUDE_PROJECT_DIR/.claude/hooks/registra_caricamenti.py"'], comandi
assert "Read(**/.env)" in d["permissions"]["deny"]
print("ok, settings")
PY
  expect "settings.json: l'hook InstructionsLoaded e le regole prudenti" 0 \
    'ok, settings'
  if grep -rqE '<(role|context|instructions|format|constraints)>' "${p}"; then
    fail "nessun tag del corso nei file di istruzioni"
  else
    pass "nessun tag del corso nei file di istruzioni"
  fi
}

# I bracci di costo: la base più una cosa sola; procedura.md è KB-10.
t_costo() {
  local c="${D02}/demo/costo" base procedura
  vero "procedura.md è la scheda KB-10, byte per byte" cmp -s \
    "${RADICE}/progetti/assistenza-clienti/kb/kb-10-trasloco.md" \
    "${c}/procedura.md"
  base="$(cat "${c}/base/CLAUDE.md"; printf x)"
  base="${base%x}"
  procedura="$(cat "${c}/procedura.md"; printf x)"
  procedura="${procedura%x}"
  vero "commento: la base e il testo fra <!-- e -->" test \
    "$(cat "${c}/commento/CLAUDE.md"; printf x)" \
    == "${base}"$'\n<!--\n'"${procedura}"$'-->\nx'
  vero "inline: la base e il testo visibile" test \
    "$(cat "${c}/inline/CLAUDE.md"; printf x)" == "${base}"$'\n'"${procedura}x"
  vero "import: la base e la riga @docs/procedura.md" test \
    "$(cat "${c}/import/CLAUDE.md"; printf x)" \
    == "${base}"$'\n@docs/procedura.md\nx'
  if grep -qE -- '-->|@|`' "${c}/procedura.md"; then
    fail "il testo non ha -->, @ né backtick"
  else
    pass "il testo non ha -->, @ né backtick"
  fi
}

t_readme() {
  local testo frase parola
  testo="$(LC_ALL=C tr -s '[:space:]' ' ' < "${D02}/README.md")"
  while IFS= read -r frase; do
    if [[ "${testo}" == *"${frase}"* ]]; then
      pass "README: «${frase:0:48}…»"
    else
      fail "README: manca «${frase}»"
    fi
  done <<'FRASI'
CLAUDE.md and CLAUDE.local.md files in the directory hierarchy above the working directory are loaded at launch. Files in subdirectories load on demand.
Instead of loading them at launch, Claude Code loads each one once Claude reads, writes, or edits another file in that subdirectory.
CLAUDE.md files can import additional files using @path/to/import syntax.
Import parsing skips Markdown code spans and fenced code blocks. To mention a path in your CLAUDE.md without importing it, wrap it in backticks
Block-level HTML comments (`<!-- maintainer notes -->`) in CLAUDE.md files are stripped before the content is injected into Claude's context.
When you open a CLAUDE.md file directly with the Read tool, comments remain visible.
Rules without paths frontmatter are loaded at launch with the same priority as .claude/CLAUDE.md.
Rules can also be scoped to specific file paths, so they only load into context when Claude works with matching files
A path-scoped rule loads when Claude uses the Read, Write, or Edit tool on a matching file.
Imports help you organize a long file but don't reduce its context cost, because imported files load together with the CLAUDE.md that imports them.
https://code.claude.com/docs/en/memory
https://code.claude.com/docs/en/hooks
tools/prepara_esercizio.sh M6-D02
tools/verifica.sh M6-D02
«VERIFICA OK M6-D02: fatto.»
FRASI
  for parola in 'FACT-' 'M6-X' 'X-37' 'X-38' 'smentit' 'probe' 'oggi' \
      ' D02' '(D02' 'triage'; do
    if [[ "${testo}" == *"${parola}"* ]]; then
      fail "README: «${parola}» non ci sta"
    else
      pass "README: niente «${parola}»"
    fi
  done
}

t_prepara() {
  local w
  if ! nuovo_ws w; then
    fail "prepara_esercizio.sh: $(tail -n 3 "${TMP}/prepara.log")"
    return 0
  fi
  pass "prepara_esercizio.sh"
  vero "lo spazio di lavoro ha progetto/ e costo/" \
    test -f "${w}/progetto/CLAUDE.md" -a -f "${w}/costo/import/CLAUDE.md"
  vero "niente _docente né soluzione" \
    test ! -e "${w}/_docente" -a ! -e "${w}/soluzione"
  vero "le impostazioni prudenti alla radice" test -f "${w}/.claude/settings.json"
  run "${D02}/verifica.sh" "${w}"
  expect "verifica.sh sul punto di partenza: 1" 1 'Manca la cartella risposte/'
  expect_absent "sul punto di partenza nessun «Fatto»" "${FATTO}"
}

# -------------------------------------------------- in_classe.sh, tutto bene

t_buono() {
  nuovo_ws BUONO || { fail "lo spazio di lavoro buono"; return 0; }
  in_classe "${BUONO}"
  expect "in_classe.sh: 0 quando ogni garanzia regge" 0 "${TUTTE}"
  expect_absent "in_classe.sh: nessun «non confermata»" "${NONCONF}"
  expect_absent "in_classe.sh: nessun «non distinguibile»" "${NONDIST}"
  expect "il comando si vede" 0 'claude -p'
  expect "e la chiamata a cui appartiene" 0 '# lettura-1'
  expect "la auto memory spenta, detto sullo schermo" 0 \
    'CLAUDE_CODE_DISABLE_AUTO_MEMORY=1'
  expect "il commento: avvio" 0 "${L_COMMENTO} (avvio, 1): confermata"
  expect "la regola: lettura" 0 "${L_REGOLA} (lettura, 1): confermata"
  expect "il CLAUDE.md di sub/: lettura" 0 "${L_ANNIDATO} (lettura, 1): confermata"
  expect "i riepiloghi" 0 "${L_AVVIO}: confermata 2 su 2"
  expect "i dati dei costi" 0 "Come dato, la prima richiesta dei bracci di costo"
  expect "l'import contro il testo incollato, come dato" 0 '(import ≥ inline: sì)'
  expect "le parole posto per posto" 0 'parole nella risposta: radice sì; commento no'
  expect "il registro nei dati" 0 'path_glob_match .claude/rules/php.md (trigger src/a.php; globs **/*.php)'
  if [[ "$(chiamate)" == 6 ]]; then
    pass "un'esecuzione: sei chiamate"
  else
    fail "un'esecuzione: $(chiamate) chiamate, non 6"
  fi
  run python3 -B -I - "${TMP}/log.jsonl" "${BUONO}" "${D02}/demo" <<'PY'
import json, os, sys
righe = [json.loads(r) for r in open(sys.argv[1], encoding="utf-8") if '"argv"' in r]
ws, demo = sys.argv[2], sys.argv[3]
def testo(nome):
    return open(os.path.join(demo, nome), encoding="utf-8").read().strip()
comuni = {"--model": "sonnet", "--effort": "low", "--permission-mode": "dontAsk",
          "--permission-prompts": "none", "--output-format": "stream-json",
          "--setting-sources": "project,local"}
def op(riga, nome):
    a = riga["argv"]
    return a[a.index(nome) + 1] if nome in a else None
attesi = [("avvio-1", "", "domanda_avvio.txt"), ("lettura-1", "Read", "domanda_lettura.txt")]
attesi += [("costo-" + b, "", "domanda_costo.txt") for b in ("base", "commento", "inline", "import")]
for riga, (nome, strumenti, prompt) in zip(righe, attesi):
    assert riga["prompt"] == testo(prompt), (nome, riga["prompt"])
    assert riga["argv"][0] == "-p" and riga["argv"][-2] == "--", nome
    for chiave, valore in comuni.items():
        assert op(riga, chiave) == valore, (nome, chiave)
    for flag in ("--verbose", "--strict-mcp-config", "--no-session-persistence"):
        assert flag in riga["argv"], (nome, flag)
    assert op(riga, "--tools") == strumenti, (nome, op(riga, "--tools"))
    assert op(riga, "--allowedTools") == (strumenti or None), nome
    assert not riga["chiave"] and not riga["effort_env"], nome
    assert riga["auto_memoria_spenta"] and riga["stdin_nullo"] and riga["git"], nome
    assert not riga["risposte"], (nome, "risposte/ durante le sessioni")
    assert not riga["cwd"].startswith(ws), (nome, riga["cwd"])
    cartella = os.path.basename(riga["cwd"])
    if nome.startswith("costo-"):
        assert cartella == "costo", (nome, riga["cwd"])
    else:
        assert cartella.startswith(nome + "."), (nome, riga["cwd"])
    assert ".claude/caricamenti.jsonl" in riga["file"], nome
    assert ".claude/hooks/registra_caricamenti.py" in riga["file"], nome
for riga in righe[:2]:
    for f in ("CLAUDE.md", "CLAUDE.local.md", "docs/glossario.md", "docs/escluso.md",
              ".claude/rules/generale.md", ".claude/rules/php.md", "sub/CLAUDE.md",
              "sub/nota.txt", "src/a.php", ".gitignore"):
        assert f in riga["file"], (riga["cwd"], f)
for riga in righe[2:]:
    assert riga["file"].count("CLAUDE.md") == 1 and "docs/procedura.md" in riga["file"]
    assert not any(f.startswith(".claude/rules") for f in riga["file"]), riga["file"]
assert len({r["cwd"] for r in righe}) == 3, "avvio, lettura e una cartella per i costi"
assert len({r["cwd"] for r in righe[2:]}) == 1, "i bracci di costo nella stessa cartella"
print("ok, le chiamate")
PY
  expect "ogni chiamata con le sue opzioni, nella sua copia" 0 'ok, le chiamate'
  vero "gli stream in risposte/" test -s "${BUONO}/risposte/lettura-1.jsonl"
  vero "i registri in risposte/" test -s "${BUONO}/risposte/avvio-1.caricamenti.jsonl"
  run python3 -B -I - "${BUONO}/risposte" <<'PY'
import json, re, sys
d = sys.argv[1]
a = json.load(open(d + "/avvio-1.parole.json", encoding="utf-8"))
b = json.load(open(d + "/lettura-1.parole.json", encoding="utf-8"))
assert len(a) == 9 and all(re.match(r"^[A-Z]+-[A-Z]{6}$", v) for v in a.values())
assert not set(a.values()) & set(b.values()), "le parole si ripetono"
print("ok, le parole")
PY
  expect "nove parole per chiamata, nuove a ogni chiamata" 0 'ok, le parole'
  if [[ -z "$(ls -A "${TMP}/t")" ]]; then
    pass "nessun temporaneo resta"
  else
    fail "resta un temporaneo: $(ls -A "${TMP}/t")"
  fi
  run "${D02}/verifica.sh" "${BUONO}"
  expect "verifica.sh dopo in_classe.sh: 0" 0 "${FATTO}"
}

# Due spazi di lavoro, parole diverse.
t_casuali() {
  local w
  nuovo_ws w || { fail "un altro spazio di lavoro"; return 0; }
  in_classe "${w}"
  if cmp -s "${w}/risposte/avvio-1.parole.json" \
      "${BUONO}/risposte/avvio-1.parole.json"; then
    fail "le parole cambiano da uno spazio di lavoro all'altro"
  else
    pass "le parole cambiano da uno spazio di lavoro all'altro"
  fi
}

# ------------------------------------------- le garanzie che non reggono

# Un caso: in_classe.sh con una variabile del finto accesa, che deve uscire 1
# con quel verdetto e senza il riepilogo buono.
# Arguments: $1 il nome, $2 la variabile, $3 la parola.
guasto() {
  local w
  nuovo_ws w || { fail "$1: lo spazio di lavoro"; return 0; }
  in_classe "${w}" "$2=1"
  expect "$1" 1 "$3"
  expect_absent "$1: nessun «Ogni garanzia»" "${TUTTE}"
}

t_guasti() {
  local w
  guasto "il commento entra nel contesto" FINTO_COMMENTO_VISIBILE \
    "${L_COMMENTO} (avvio, 1): ${NONCONF}"
  guasto "un percorso fra backtick si importa" FINTO_BACKTICK_IMPORTA \
    "${L_BACKTICK} (avvio, 1): ${NONCONF}"
  guasto "l'import non si carica" FINTO_IMPORT_ASSENTE \
    "${L_IMPORT} (avvio, 1): ${NONCONF}"
  guasto "CLAUDE.local.md non si carica" FINTO_LOCALE_ASSENTE \
    "${L_AVVIO} (avvio, 1): ${NONCONF}"
  guasto "la regola con paths all'avvio" FINTO_REGOLA_ALL_AVVIO \
    "${L_RICHIESTA} (avvio, 1): ${NONCONF}"
  guasto "sub/CLAUDE.md all'avvio" FINTO_ANNIDATO_ALL_AVVIO \
    "${L_RICHIESTA} (avvio, 1): ${NONCONF}"
  guasto "il Read non carica la regola" FINTO_REGOLA_NON_CARICA \
    "${L_REGOLA} (lettura, 1): ${NONCONF}"
  guasto "il Read in sub/ non carica sub/CLAUDE.md" FINTO_ANNIDATO_NON_CARICA \
    "${L_ANNIDATO} (lettura, 1): ${NONCONF}"
  guasto "Claude non legge: la regola" FINTO_NON_LEGGE \
    "${L_REGOLA} (lettura, 1): ${NONDIST}"
  guasto "Claude non legge: sub/" FINTO_NON_LEGGE \
    "${L_ANNIDATO} (lettura, 1): ${NONDIST}"
  guasto "il Read non riesce" FINTO_READ_ERRORE "non è riuscito"
  guasto "la risposta non dice che cosa vede" FINTO_NON_LA_SO \
    "${L_COMMENTO} (avvio, 1): ${NONDIST}"
  guasto "senza l'hook nessun caricamento" FINTO_SENZA_HOOK \
    "${L_AVVIO} (avvio, 1): ${NONCONF}"
  # La parola del file letto nella risposta è un dato, non un esito.
  nuovo_ws w || { fail "lo spazio di lavoro"; return 0; }
  in_classe "${w}" FINTO_ELENCA_LETTI=1
  expect "la parola del file letto nella risposta: 0, un dato" 0 "${TUTTE}"
  expect "e i dati lo dicono" 0 'file letto sì'
  nuovo_ws w || { fail "lo spazio di lavoro"; return 0; }
  in_classe "${w}" FINTO_COMMENTO_VISIBILE=1
  run "${D02}/verifica.sh" "${w}"
  expect "verifica.sh su una garanzia che non regge: 1" 1 "${NONCONF}"
  expect_absent "verifica.sh: nessun «Fatto»" "${FATTO}"
  expect "chi legge sa che è da segnalare" 1 'da segnalare'
}

# ------------------------------------------------------ i file rovinati

t_rovinati() {
  local c
  controlla "${TMP}/non-c-e"
  expect "lo spazio di lavoro assente: 2" 2 'spazio di lavoro assente'
  c="$(mktemp -d "${TMP}/vuoto.XXXXXX")"
  controlla "${c}"
  expect "manca risposte/: 1" 1 'Manca la cartella risposte/'
  mkdir "${c}/risposte"
  controlla "${c}"
  expect "nessuna esecuzione: 1" 1 'nessuna esecuzione'
  copia_buona c
  controlla "${c}"
  expect "il controllo su una copia buona: 0" 0 "${TUTTE}"
  expect "i secondi con la virgola" 0 '; 1,0 s'
  local f
  for f in lettura-1.jsonl avvio-1.caricamenti.jsonl avvio-1.parole.json \
      costo-import.jsonl costo-base.caricamenti.jsonl; do
    copia_buona c
    rm -f "${c}/risposte/${f}"
    controlla "${c}"
    expect "manca ${f}: 1" 1 "manca risposte/${f}"
  done
  copia_buona c
  cp "${c}/risposte/avvio-1.jsonl" "${c}/risposte/avvio-2.jsonl"
  controlla "${c}"
  expect "una seconda esecuzione a metà: 1" 1 'manca risposte/avvio-2.caricamenti.jsonl'
  copia_buona c
  : > "${c}/risposte/avvio-1.jsonl"
  controlla "${c}"
  expect "uno stream vuoto: 1" 1 'è vuoto'
  copia_buona c
  printf 'non json\n' >> "${c}/risposte/avvio-1.jsonl"
  controlla "${c}"
  expect "una riga che non è JSON: 1" 1 'non è JSON'
  copia_buona c
  printf '[1]\n' >> "${c}/risposte/lettura-1.jsonl"
  controlla "${c}"
  expect "una riga che non è un oggetto: 1" 1 'non è un oggetto JSON'
  copia_buona c
  cambia_eventi "${c}/risposte/avvio-1.jsonl" \
    'e.update(type="altro") if e.get("type") == "result" else None'
  controlla "${c}"
  expect "senza il risultato in fondo: 1" 1 'non finisce con il risultato'
  copia_buona c
  cambia_eventi "${c}/risposte/costo-inline.jsonl" \
    'e.update(is_error=True) if e.get("type") == "result" else None'
  controlla "${c}"
  expect "un risultato con un errore: 1" 1 'ha restituito un errore'
  copia_buona c
  cambia_eventi "${c}/risposte/avvio-1.jsonl" \
    'e.pop("num_turns", None) if e.get("type") == "result" else None'
  controlla "${c}"
  expect "un risultato senza num_turns: 1" 1 'num_turns'
  copia_buona c
  printf '{"load_reason": "boh", "file_path": "CLAUDE.md"}\n' \
    >> "${c}/risposte/avvio-1.caricamenti.jsonl"
  controlla "${c}"
  expect "un motivo di caricamento sconosciuto: 1" 1 'load_reason sconosciuto'
  copia_buona c
  printf '{"radice": "RADICE-abc"}\n' > "${c}/risposte/lettura-1.parole.json"
  controlla "${c}"
  expect "le parole che non vanno: 1" 1 'non è nella forma'
  copia_buona c
  printf 'non json' > "${c}/risposte/lettura-1.parole.json"
  controlla "${c}"
  expect "le parole che non sono JSON: 1" 1 'non è JSON'
  copia_buona c
  rm -f "${c}/risposte/avvio-1.jsonl"
  mkdir "${c}/risposte/avvio-1.jsonl"
  controlla "${c}"
  expect "uno stream che non si legge: 2" 2 'non si legge'
  expect_absent "mai un traceback" 'Traceback'
  controlla --sconosciuta
  expect "un'opzione sconosciuta: 2" 2 'opzione sconosciuta'
  copia_buona c
  controlla "${c}" "${c}"
  expect "due spazi di lavoro: 2" 2 'uno spazio di lavoro per volta'
  run env PN_HANDSON_ROOT="${TMP}/non-c-e" python3 -B -I "${CONTROLLO}" "${c}"
  expect "tools/ che non si trova: 2" 2 'tools/lib_leggi_contesto.py'
  expect_absent "mai un traceback nell'uso" 'Traceback'
}

# Le risposte di forma diversa: la parola del commento in minuscolo l'ha vista.
t_forme() {
  local c parola
  copia_buona c
  parola="$(python3 -B -I -c 'import json,sys; print(json.load(open(sys.argv[1]))["commento"])' \
    "${c}/risposte/avvio-1.parole.json")"
  cambia_eventi "${c}/risposte/avvio-1.jsonl" \
    "e.update(result=e['result'] + ' ${parola,,}') if e.get('type') == 'result' else None"
  controlla "${c}"
  expect "la parola del commento in minuscolo: non confermata" 1 \
    "${L_COMMENTO} (avvio, 1): ${NONCONF}"
  copia_buona c
  cambia_eventi "${c}/risposte/avvio-1.jsonl" \
    "e.update(result=e['result'].lower()) if e.get('type') == 'result' else None"
  controlla "${c}"
  expect "la risposta in minuscolo: la parola della radice c'è lo stesso" 0 \
    "${TUTTE}"
}

# -------------------------------------------- le precondizioni di in_classe

t_precondizioni() {
  local w fuori
  nuovo_ws w || { fail "lo spazio di lavoro"; return 0; }
  in_classe "${w}" PN_ESECUZIONI=abc
  expect "PN_ESECUZIONI non è un numero: 2" 2 'PN_ESECUZIONI'
  in_classe "${w}" PN_ESECUZIONI=0
  expect "PN_ESECUZIONI 0: 2" 2 'PN_ESECUZIONI'
  in_classe "${w}" PN_ESECUZIONI=10
  expect "PN_ESECUZIONI 10: 2" 2 'PN_ESECUZIONI'
  vero "nessuna chiamata" test ! -s "${TMP}/log.jsonl"
  in_classe "${w}" HANDSON_ENV=trainer-api
  expect "HANDSON_ENV trainer-api: 2" 2 'claude-code-pro'
  if env PATH=/usr/bin:/bin bash -c 'command -v claude' > /dev/null; then
    skip "senza claude nel PATH: c'è un claude di sistema"
  else
    run env PATH=/usr/bin:/bin bash "${D02}/demo/in_classe.sh" "${w}"
    expect "senza claude nel PATH: 2" 2 'manca lo strumento: claude'
  fi
  mkdir -p "${w}/risposte"
  in_classe "${w}"
  expect "risposte/ c'è già: 2" 2 'reset_esercizio.sh M6-D02'
  rmdir "${w}/risposte"
  printf 'x\n' > "${w}/sporco.txt"
  in_classe "${w}"
  expect "lo spazio di lavoro con del lavoro: 2" 2 'non è al punto di partenza'
  rm -f "${w}/sporco.txt"
  vero "nessuna chiamata con le precondizioni che non reggono" \
    test ! -s "${TMP}/log.jsonl"
  fuori="$(mktemp -d "${TMP}/fuori.XXXXXX")"
  cp -R "${D02}/demo/." "${fuori}/"
  in_classe "${fuori}"
  expect "una cartella che non è lo spazio di lavoro: 2" 2 \
    'tools/prepara_esercizio.sh M6-D02'
  vero "e lì non scrive risposte/" test ! -e "${fuori}/risposte"
  git -C "${w}" rm -q costo/procedura.md
  git -C "${w}" -c user.name=t -c user.email=t@example.org commit -q -m via
  in_classe "${w}"
  expect "un file del punto di partenza che manca: 2" 2 'costo/procedura.md'
  nuovo_ws w || { fail "lo spazio di lavoro"; return 0; }
  printf -- '- __NUOVA__\n' >> "${w}/progetto/CLAUDE.md"
  git -C "${w}" -c user.name=t -c user.email=t@example.org commit -q -am nuova
  in_classe "${w}"
  expect "un segnaposto senza parola: 2" 2 'un segnaposto senza parola'
  vero "e nessuna chiamata" test ! -s "${TMP}/log.jsonl"
  run env PN_HANDSON_ROOT="${TMP}/non-c-e" bash "${D02}/demo/in_classe.sh" "${w}"
  expect "senza tools/lib_handson.sh: 2" 2 'PN_HANDSON_ROOT'
}

# Una chiamata fallita: uscita 1, ciò che c'è in risposte/, i temporanei via.
t_fallita() {
  local w casa
  nuovo_ws w || { fail "lo spazio di lavoro"; return 0; }
  in_classe "${w}" FINTO_ESITO_KO_SE=sub/nota.txt
  expect "una chiamata fallita: 1" 1 'lettura-1: claude -p è fallito'
  vero "gli stream finiti restano in risposte/" test -s "${w}/risposte/avvio-1.jsonl"
  if [[ -z "$(ls -A "${TMP}/t")" ]]; then
    pass "nessun temporaneo resta"
  else
    fail "resta un temporaneo: $(ls -A "${TMP}/t")"
  fi
  run "${D02}/verifica.sh" "${w}"
  expect "verifica.sh dopo una chiamata fallita: 1" 1 'manca'
  nuovo_ws w || { fail "lo spazio di lavoro"; return 0; }
  in_classe "${w}" ANTHROPIC_API_KEY=finta CLAUDE_CODE_EFFORT_LEVEL=high
  expect "con la chiave nell'ambiente gira lo stesso" 0 "${TUTTE}"
  if grep -q '"chiave": true\|"effort_env": true' "${TMP}/log.jsonl"; then
    fail "ANTHROPIC_API_KEY o CLAUDE_CODE_EFFORT_LEVEL arrivano a claude"
  else
    pass "ANTHROPIC_API_KEY e CLAUDE_CODE_EFFORT_LEVEL non arrivano a claude"
  fi
  casa="${TMP}/casa"
  mkdir -p "${casa}/.claude/t"
  nuovo_ws w || { fail "lo spazio di lavoro"; return 0; }
  : > "${TMP}/log.jsonl"
  run env FINTO_LOG="${TMP}/log.jsonl" HOME="${casa}" \
    TMPDIR="${casa}/.claude/t" "${D02}/demo/in_classe.sh" "${w}"
  expect "TMPDIR dentro ~/.claude: gira" 0 "${TUTTE}"
  if grep -qF "${casa}/.claude" "${TMP}/log.jsonl"; then
    fail "le copie non stanno dentro ~/.claude"
  else
    pass "le copie non stanno dentro ~/.claude"
  fi
}

# ---------------------------------------------------- verifica.sh e live.sh

t_verifica() {
  local w
  run "${D02}/verifica.sh"
  expect "verifica.sh senza argomento: 2" 2 'spazio di lavoro assente'
  run "${D02}/verifica.sh" "${TMP}/non-c-e"
  expect "verifica.sh su una cartella che non c'è: 2" 2 'spazio di lavoro assente'
  nuovo_ws w || { fail "lo spazio di lavoro"; return 0; }
  in_classe "${w}" FINTO_COMMENTO_VISIBILE=1
  printf 'import sys\nprint("%s")\nsys.exit(0)\n' "${TUTTE}" \
    > "${w}/controlla_caricamento.py"
  run "${D02}/verifica.sh" "${w}"
  expect "verifica.sh non si fida del controllo dello spazio di lavoro" 1 \
    "${NONCONF}"
  run env PN_WORKSPACE_ROOT="${BUONO%/*}" "${RADICE}/tools/verifica.sh" M6-D02
  expect "tools/verifica.sh M6-D02" 0 'VERIFICA OK'
}

t_live() {
  local w
  run "${D02}/_docente/live.sh"
  expect "live.sh senza argomenti: 2, e l'uso" 2 'uso: _docente/live.sh'
  run "${D02}/_docente/live.sh" "${TMP}/non-c-e"
  expect "live.sh senza spazio di lavoro: 2" 2 'spazio di lavoro assente'
  nuovo_ws w || { fail "lo spazio di lavoro"; return 0; }
  printf 'x\n' > "${w}/sporco.txt"
  : > "${TMP}/log.jsonl"
  run env FINTO_LOG="${TMP}/log.jsonl" "${D02}/_docente/live.sh" "${w}"
  expect "live.sh su uno spazio di lavoro con del lavoro: 2" 2 \
    'reset_esercizio.sh M6-D02'
  vero "nessuna chiamata al modello" test ! -s "${TMP}/log.jsonl"
  rm -f "${w}/sporco.txt"
  run env HANDSON_ENV=trainer-api FINTO_LOG="${TMP}/log.jsonl" \
    "${D02}/_docente/live.sh" "${w}"
  expect "live.sh con HANDSON_ENV trainer-api: 2" 2 'claude-code-pro'
  run env FINTO_LOG="${TMP}/log.jsonl" FINTO_SPAZIO="${w}" TMPDIR="${TMP}/t" \
    "${D02}/_docente/live.sh" "${w}"
  expect "live.sh: 0 con tre esecuzioni" 0 "${L_COMMENTO}: confermata 3 su 3"
  expect "live.sh: il riepilogo dell'avvio" 0 "${L_AVVIO}: confermata 6 su 6"
  expect "live.sh: verifica.sh dopo" 0 "VERIFICA OK   verifica.sh dell'elemento"
  if [[ "$(chiamate)" == 10 ]]; then
    pass "live.sh: dieci chiamate"
  else
    fail "live.sh: $(chiamate) chiamate, non 10"
  fi
  nuovo_ws w || { fail "lo spazio di lavoro"; return 0; }
  run env FINTO_REGOLA_NON_CARICA=1 PN_ESECUZIONI=1 TMPDIR="${TMP}/t" \
    "${D02}/_docente/live.sh" "${w}"
  expect "live.sh su una garanzia che non regge: 1" 1 "${NONCONF}"
  nuovo_ws w || { fail "lo spazio di lavoro"; return 0; }
  run env FINTO_ESITO_KO_SE='Rispondi solo' TMPDIR="${TMP}/t" \
    "${D02}/_docente/live.sh" "${w}"
  expect "live.sh con una chiamata fallita: 1" 1 'claude -p è fallito'
}

# La registrazione, quando la sessione del docente l'ha messa in soluzione/.
t_soluzione() {
  local w
  vero "soluzione/LEGGIMI.md parla della registrazione" \
    grep -qi 'registrazione' "${D02}/soluzione/LEGGIMI.md"
  if [[ ! -d "${D02}/soluzione/risposte" ]]; then
    skip "soluzione/risposte: la registrazione non c'è ancora"
    return 0
  fi
  nuovo_ws w || { fail "lo spazio di lavoro"; return 0; }
  cp -R "${D02}/soluzione/." "${w}/"
  run "${D02}/verifica.sh" "${w}"
  expect "verifica.sh con la registrazione: 0" 0 "${FATTO}"
}

t_struttura() {
  run "${RADICE}/tools/check_handson.sh"
  if grep -q 'M6-D02' <<< "${OUT}"; then
    fail "check_handson.sh segnala M6-D02: $(grep 'M6-D02' <<< "${OUT}")"
  else
    pass "check_handson.sh non segnala M6-D02"
  fi
}

t_shellcheck() {
  local f
  for f in "${D02}/verifica.sh" "${D02}/_docente/live.sh" \
      "${D02}/demo/in_classe.sh" "${D02}/demo/lib_caricamento.sh" "${SELF}"; do
    if [[ -f "${f}" ]] && (cd "${RADICE}" && shellcheck -x "${f}") \
        > /dev/null 2>&1; then
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
      || { echo "test_m6_d02: manca ${t}" >&2; exit 2; }
  done
  [[ -f "${FINTO_PY}" ]] \
    || { echo "test_m6_d02: manca ${FINTO_PY}" >&2; exit 2; }
  handson::init_temp_base
  TMP="$(mktemp -d "${HANDSON_TEMP_BASE}/test_m6_d02.XXXXXX")" || exit 2
  trap 'chmod -R u+rwX "${TMP}" 2>/dev/null; rm -rf "${TMP}"' EXIT
  prepara_claude
  t_elemento
  t_progetto
  t_costo
  t_readme
  t_prepara
  t_buono
  t_casuali
  t_guasti
  t_rovinati
  t_forme
  t_precondizioni
  t_fallita
  t_verifica
  t_live
  t_soluzione
  t_struttura
  t_shellcheck
  OUT="${TUTTO}"
  expect_absent "in nessuna uscita «smentita»" "smentita"
  echo "PASS=${PASS} FAIL=${FAIL} SKIP=${SKIP}"
  if (( PASS + FAIL + SKIP != CASES )); then
    echo "test_m6_d02: girati $((PASS + FAIL + SKIP)) casi, attesi" \
      "${CASES}" >&2
    exit 2
  fi
  (( FAIL == 0 )) || exit 1
}

main "$@"
