#!/bin/bash
#
# test_m5_d01.sh -- le prove di M5-D01 «Lo stesso testo in tre posti», per il
# docente (sta in _docente/, il materiale del docente):
#   - l'elemento: demo/testo.md è kb-01, kb-02 e kb-03 di
#     progetti/assistenza-clienti/kb/, byte per byte; le domande; le dieci
#     sezioni del README, le frasi di Anthropic con il loro indirizzo, i
#     prompt uguali ai file; nessun nome interno, percorso personale,
#     «smentita» o riferimento alla giornata;
#   - prepara_esercizio.sh e verifica.sh sul punto di partenza (1);
#   - prepara_bracci.sh: i quattro bracci, repository git puliti, che
#     differiscono soltanto nel posto del testo; controlla_skill.py passa sulla
#     skill; le precondizioni (2);
#   - controlla_costo.py su stream del claude finto: la tabella, i dati, i
#     verdetti (mai un'uscita diversa da 0 per un confronto); le segnalazioni
#     (1); gli stream che mancano o non si leggono (2), mai un traceback;
#   - verifica.sh: il controllo dell'elemento, mai quello dello spazio di
#     lavoro; le precondizioni (2);
#   - demo/in_classe.sh e _docente/live.sh con il claude finto: quante chiamate,
#     da quale cartella, con quali testi e opzioni, senza ANTHROPIC_API_KEY,
#     gli stream fuori dallo spazio di lavoro finché le sessioni girano; le
#     precondizioni (2, nessuna chiamata: l'esca); una chiamata fallita (1);
#   - shellcheck -x sugli script e su questo file.
# Mai il claude vero: il finto e l'esca stanno davanti nel PATH, e la suite lo
# controlla prima di usarli. Gli stream del finto non sono risposte di Claude:
# provano il controllo, non il modello. Gli spazi di lavoro nascono in una
# cartella temporanea, nella base di handson::init_temp_base: l'albero del
# repository non cambia. CASES è il numero dei casi: se ne girano di più o di
# meno la suite esce 2.
#
# Uso:    m5_skills/_docente/test_m5_d01.sh
# Uscita: 0 = tutti i casi passano · 1 = almeno un caso fallito · 2 =
#         precondizione (manca python3, git o shellcheck), o un numero di casi
#         diverso da CASES
set -uo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly MOD="${SELF%/_docente/*}"
readonly RADICE="${MOD%/*}"
D01="${MOD}/s4_skills/m5_3_skill_o_system_prompt"
D01+="/M5-D01_stesso_testo_tre_posti"
readonly D01
readonly FINTO_PY="${MOD}/_docente/claude_finto_m5_d01_d02.py"
readonly KB="${RADICE}/progetti/assistenza-clienti/kb"
# La libreria del repository, per la base dei file temporanei.
# shellcheck source=../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"
readonly CASES=179
readonly Q='Rispondi solo: ok'
INV="/procedure-assistenza Qual è la velocità massima in upload"
INV+=" dell'offerta Casa Radio?"
readonly INV
readonly DOPO='E in download?'
FATTO='Fatto: ogni affermazione è stata messa alla prova;'
FATTO+=' gli esiti sono qui sopra.'
readonly FATTO
readonly NONCONF='non confermata in questa esecuzione'
readonly NONDIST='non distinguibile'
readonly S_CLAUDE='Skill contro CLAUDE.md'
readonly S_APPEND='Skill contro append'
TMP=''
PASS=0
FAIL=0
SKIP=0
RC=0
OUT=''
TUTTO=''

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }
skip() { echo "  SKIP: $1"; SKIP=$((SKIP + 1)); }

# Esegue un comando; RC e OUT (STDOUT e STDERR insieme) per expect; OUT si
# aggiunge a TUTTO, dove alla fine non devono esserci «smentita» né traceback.
run() { OUT="$("$@" 2>&1)"; RC=$?; TUTTO+="${OUT}"$'\n'; }

# Uscita attesa E parola chiave attesa (RU-01.T3).
# Arguments: $1 il nome, $2 l'uscita attesa, $3 la parola (grep -F).
expect() {
  if (( RC == $2 )) && grep -qF -- "$3" <<< "${OUT}"; then
    pass "$1"
  else
    fail "$1 (rc=${RC}, attesa $2, parola «$3»): ${OUT:0:600}"
  fi
}

# Nessun falso positivo: la parola NON c'è (RU-01.T5).
# Arguments: $1 il nome, $2 la parola.
expect_absent() {
  if grep -qF -- "$2" <<< "${OUT}"; then
    fail "$1: «$2» c'è: ${OUT:0:400}"
  else
    pass "$1"
  fi
}

# Un caso che passa se il comando riesce.
# Arguments: $1 il nome, poi il comando.
vero() {
  local nome="$1"
  shift
  if "$@"; then
    pass "${nome}"
  else
    fail "${nome}"
  fi
}

# Uno spazio di lavoro nuovo, con prepara_esercizio.sh in una radice nuova.
# Arguments: $1 la variabile da assegnare.
# Returns: 0; 1 se prepara_esercizio.sh non riesce.
nuovo_ws() {
  local __r
  __r="$(mktemp -d "${TMP}/radice.XXXXXX")" || exit 2
  "${RADICE}/tools/prepara_esercizio.sh" M5-D01 --radice "${__r}" \
    > "${TMP}/prepara.log" 2>&1 || return 1
  printf -v "$1" '%s' "${__r}/M5-D01"
}

# L'esca (registra ogni invocazione ed esce 0), il claude finto e i PATH
# ridotti. Esce 2 se nel PATH di prova claude non è il finto.
prepara_claude() {
  local t
  mkdir -p "${TMP}/esca" "${TMP}/finto" "${TMP}/senza_python" \
    "${TMP}/senza_claude" || exit 2
  # shellcheck disable=SC2016  # il corpo è dell'esca
  printf '%s\n' '#!/bin/bash' \
    'printf "invocazione %s\n" "$*" >> "${ESCA_LOG}"' \
    > "${TMP}/esca/claude" || exit 2
  cp -- "${FINTO_PY}" "${TMP}/finto/claude" || exit 2
  chmod 755 "${TMP}/esca/claude" "${TMP}/finto/claude" || exit 2
  for t in readlink git; do
    ln -s "$(command -v "${t}")" "${TMP}/senza_python/${t}" || exit 2
  done
  ln -s "${TMP}/esca/claude" "${TMP}/senza_python/claude" || exit 2
  for t in readlink python3 git; do
    ln -s "$(command -v "${t}")" "${TMP}/senza_claude/${t}" || exit 2
  done
  t="$(PATH="${TMP}/finto:${PATH}" command -v claude)"
  if [[ "${t}" != "${TMP}/finto/claude" ]]; then
    echo "test_m5_d01: nel PATH di prova claude è ${t}, non il finto" >&2
    exit 2
  fi
}

# Uno stream del finto, in un file. Arguments: $1 la cartella degli stream, $2
# il nome senza estensione, $3 la cartella da cui parte, $4 il prompt, poi le
# variabili NOME=valore e, dopo «--», le opzioni in più del finto.
stream_finto() {
  local json="$1" nome="$2" dir="$3" prompt="$4"
  local -a vars=() piu=()
  shift 4
  while (( $# > 0 )) && [[ "$1" != -- ]]; do
    vars+=("$1")
    shift
  done
  if (( $# > 0 )); then
    shift
    piu=("$@")
  fi
  ( cd "${dir}" && env FINTO_SESSIONI="${TMP}/sessioni" \
      ${vars[@]+"${vars[@]}"} "${TMP}/finto/claude" -p --model sonnet \
      --output-format stream-json --verbose ${piu[@]+"${piu[@]}"} \
      -- "${prompt}" ) > "${json}/${nome}.jsonl" \
    || { echo "test_m5_d01: il finto non scrive ${nome}" >&2; exit 2; }
}

# L'ID di sessione del risultato di uno stream. Arguments: $1 il file.
sessione_di() {
  python3 -B -I -c 'import json, sys
print([json.loads(r) for r in open(sys.argv[1], encoding="utf-8")][-1]
      ["session_id"])' "$1"
}

# Rifà uno stream di una serie, con le variabili date.
# Arguments: $1 la cartella degli stream, $2 il nome (skill-1, skill_dopo-2…),
# poi le variabili NOME=valore.
rifai() {
  local json="$1" nome="$2" b="${2%-*}" n="${2##*-}" id
  shift 2
  case "${b}" in
    skill_invocata)
      stream_finto "${json}" "${nome}" "${TMP}/bracci/skill" "${INV}" "$@" ;;
    skill_dopo)
      id="$(sessione_di "${json}/skill_invocata-${n}.jsonl")" || exit 2
      stream_finto "${json}" "${nome}" "${TMP}/bracci/skill" "${DOPO}" "$@" \
        -- --resume "${id}" ;;
    append)
      stream_finto "${json}" "${nome}" "${TMP}/bracci/append" "${Q}" "$@" \
        -- --no-session-persistence --append-system-prompt-file testo.md ;;
    *)
      stream_finto "${json}" "${nome}" "${TMP}/bracci/${b}" "${Q}" "$@" \
        -- --no-session-persistence ;;
  esac
}

# Le sei chiamate di un'esecuzione, da bracci costruiti da prepara_bracci.sh.
# Arguments: $1 la cartella degli stream, $2 il numero.
serie() {
  local nome
  for nome in niente skill claude_md append skill_invocata skill_dopo; do
    rifai "$1" "${nome}-$2"
  done
}

# Una cartella nuova di stream, con le esecuzioni da 1 a $2.
# Arguments: $1 la variabile da assegnare, $2 quante esecuzioni.
nuova_serie() {
  local __j __n
  __j="$(mktemp -d "${TMP}/json.XXXXXX")" || exit 2
  for (( __n = 1; __n <= $2; __n++ )); do
    serie "${__j}" "${__n}"
  done
  printf -v "$1" '%s' "${__j}"
}

# controlla_costo.py dell'elemento; RC e OUT come run.
controlla() { run python3 -B -I "${D01}/demo/controlla_costo.py" "$@"; }

# Lo script con l'esca davanti nel PATH (o con un PATH dato); il registro
# riparte vuoto. Arguments: $1 lo script, $2 lo spazio di lavoro, $3 facoltativo
# il PATH, poi le variabili NOME=valore.
esca() {
  local script="$1" w="$2" percorso="${3:-${TMP}/esca:${PATH}}"
  shift 2
  (( $# == 0 )) || shift
  : > "${TMP}/esca.log"
  run env PATH="${percorso}" HANDSON_NO_PAUSE=1 ESCA_LOG="${TMP}/esca.log" \
    "$@" "${script}" "${w}"
}

# Una precondizione: uscita 2, la parola attesa, nessuna chiamata al modello
# (--version a parte). Arguments: $1 il nome, $2 la parola, poi gli argomenti di
# esca.
precondizione() {
  local nome="$1" parola="$2" n
  shift 2
  esca "$@"
  expect "${nome}" 2 "${parola}"
  n="$(grep -c -v -- '--version' "${TMP}/esca.log")"
  if (( n == 0 )); then
    pass "${nome}: nessuna chiamata al modello"
  else
    fail "${nome}: ${n} chiamate"
  fi
}

# Lo script con il finto davanti nel PATH e ANTHROPIC_API_KEY impostata (lo
# script la deve togliere); il registro riparte vuoto.
# Arguments: $1 lo script, $2 lo spazio di lavoro, poi le variabili NOME=valore.
finto() {
  local script="$1" w="$2"
  shift 2
  : > "${TMP}/finto.log"
  run env PATH="${TMP}/finto:${PATH}" HANDSON_NO_PAUSE=1 \
    ANTHROPIC_API_KEY=valore-finto FINTO_LOG="${TMP}/finto.log" \
    FINTO_SESSIONI="${TMP}/sessioni" "$@" "${script}" "${w}"
}

# Le chiamate di un registro del finto, contro le attese.
# Arguments: $1 il registro, $2 lo spazio di lavoro, $3 quante esecuzioni, $4 la
# cartella degli stream.
controlla_chiamate() {
  run python3 -B -I - "$1" "$2" "$3" "$4" "${Q}" "${INV}" "${DOPO}" <<'PY'
import json, os, sys
log, ws, n, json_dir, q, inv, dopo = sys.argv[1:8]
righe = [json.loads(r) for r in open(log, encoding="utf-8")]
chiamate = [r for r in righe if r["argv"][:1] != ["--version"]]
attese = []
for k in range(1, int(n) + 1):
    for b in ("niente", "skill", "claude_md", "append"):
        attese.append((b, q, True, b == "append", None))
    attese.append(("skill", inv, False, False, None))
    attese.append(("skill", dopo, False, False, k))
VALORE = {"--model", "--effort", "--output-format", "--setting-sources",
          "--permission-mode", "--permission-prompts", "--resume",
          "--append-system-prompt-file", "--allowedTools"}
fisse = (("--model", "sonnet"), ("--effort", "low"),
         ("--output-format", "stream-json"),
         ("--setting-sources", "project,local"),
         ("--permission-mode", "dontAsk"), ("--permission-prompts", "none"))
problemi = []
if len(chiamate) != len(attese):
    problemi.append("%d chiamate invece di %d" % (len(chiamate), len(attese)))
for i, (c, (b, testo, senza, app, resume)) in enumerate(
        zip(chiamate, attese), 1):
    argv = c["argv"]
    if "--" not in argv:
        problemi.append("chiamata %d: il prompt non è dopo «--»" % i)
        continue
    fine, opzioni, j = argv.index("--"), {}, 0
    while j < fine:
        if argv[j] in VALORE:
            opzioni[argv[j]] = argv[j + 1]
            j += 2
        else:
            opzioni[argv[j]] = True
            j += 1
    if argv[fine + 1:] != [testo]:
        problemi.append("chiamata %d: il prompt %r" % (i, argv[fine + 1:]))
    attesa = os.path.realpath(os.path.join(ws, "bracci", b))
    if os.path.realpath(c["cwd"]) != attesa:
        problemi.append("chiamata %d: la cartella %s" % (i, c["cwd"]))
    for chiave, valore in fisse:
        if opzioni.get(chiave) != valore:
            problemi.append("chiamata %d: %s" % (i, chiave))
    for chiave in ("-p", "--verbose", "--strict-mcp-config"):
        if opzioni.get(chiave) is not True:
            problemi.append("chiamata %d: %s" % (i, chiave))
    if ("--no-session-persistence" in opzioni) != senza:
        problemi.append("chiamata %d: --no-session-persistence" % i)
    if opzioni.get("--append-system-prompt-file") != ("testo.md" if app
                                                      else None):
        problemi.append("chiamata %d: --append-system-prompt-file" % i)
    if "--allowedTools" in opzioni:
        problemi.append("chiamata %d: --allowedTools" % i)
    if resume is None and "--resume" in opzioni:
        problemi.append("chiamata %d: --resume" % i)
    if resume is not None:
        file = os.path.join(json_dir, "skill_invocata-%d.jsonl" % resume)
        ultima = [json.loads(r) for r in open(file, encoding="utf-8")][-1]
        if opzioni.get("--resume") != ultima["session_id"]:
            problemi.append("chiamata %d: la sessione ripresa" % i)
    if c["chiave"]:
        problemi.append("chiamata %d: con ANTHROPIC_API_KEY" % i)
    if not c["stdin_nullo"]:
        problemi.append("chiamata %d: STDIN non è /dev/null" % i)
    if c["risposte_vicine"]:
        problemi.append("chiamata %d: risposte/ già nello spazio" % i)
    if c["stream_vicini"]:
        problemi.append("chiamata %d: uno stream nello spazio" % i)
print("; ".join(problemi) or "chiamate giuste")
PY
}

# --- L'elemento -------------------------------------------------------------

t_elemento() {
  local f
  for f in README.md verifica.sh demo/testo.md demo/domanda.txt \
      demo/domanda_invocata.txt demo/domanda_dopo.txt demo/prepara_bracci.sh \
      demo/controlla_costo.py demo/in_classe.sh _docente/live.sh; do
    vero "elemento: ${f}" test -f "${D01}/${f}"
  done
  vero "elemento: soluzione/" test -d "${D01}/soluzione"
  for f in verifica.sh _docente/live.sh demo/in_classe.sh \
      demo/prepara_bracci.sh; do
    vero "elemento: ${f} eseguibile" test -x "${D01}/${f}"
  done
  cat "${KB}"/kb-02-*.md "${KB}"/kb-03-*.md "${KB}"/kb-04-*.md \
    > "${TMP}/kb.md"
  vero "testo.md: kb-02, kb-03 e kb-04, byte per byte" \
    cmp -s "${TMP}/kb.md" "${D01}/demo/testo.md"
  run cat -- "${D01}/demo/domanda.txt"
  expect "domanda.txt: la domanda dei quattro bracci" 0 "${Q}"
  run cat -- "${D01}/demo/domanda_invocata.txt"
  expect "domanda_invocata.txt: /procedure-assistenza con una domanda" 0 \
    "${INV}"
  run cat -- "${D01}/demo/domanda_dopo.txt"
  expect "domanda_dopo.txt: la domanda del turno dopo" 0 "${DOPO}"
  run python3 -B -I - "${D01}/demo/testo.md" <<'PY'
import sys
testo = open(sys.argv[1], encoding="utf-8").read()
righe = testo.count("\n")
casa = "| Casa Radio | radio | 100 Mbit/s / 20 Mbit/s |"
ok = righe < 500 and casa in testo
print("testo a posto" if ok else "righe %d, %s" % (righe, casa in testo))
PY
  expect "testo.md: sotto le 500 righe, con la riga della domanda" 0 \
    "testo a posto"
}

# Il README: le dieci sezioni, le frasi di Anthropic, i prompt uguali ai file;
# niente nomi interni, percorsi personali, giornate, «smentita».
t_readme() {
  run python3 -B -I - "${D01}" <<'PY'
import os, re, sys
item = sys.argv[1]
with open(os.path.join(item, "README.md"), encoding="utf-8") as fh:
    readme = fh.read()
problemi = []
sezioni = ("Obiettivo", "Tempo", "Prerequisiti", "Punto di partenza",
           "Passi in Claude Code", "Che cosa osservare", "Verifica",
           "Se qualcosa va storto", "Impronta d'uso sul piano Pro",
           "Per approfondire")
titoli = [r[3:] for r in readme.splitlines() if r.startswith("## ")]
if [next((s for s in sezioni if t.startswith(s)), "") for t in titoli] \
        != list(sezioni):
    problemi.append("le dieci sezioni, in ordine: %s" % titoli)
for titolo in ("## Punto di partenza (tools/prepara_esercizio.sh M5-D01)",
               "## Verifica (tools/verifica.sh M5-D01)"):
    if titolo not in readme:
        problemi.append("il titolo «%s»" % titolo)
SKILLS = "https://code.claude.com/docs/en/skills"
STEERING = ("https://claude.com/resources/articles/"
            "steering-claude-code-skills-hooks-rules-subagents-and-more")
OVERVIEW = "https://code.claude.com/docs/en/features-overview"
SPEC = "https://agentskills.io/specification"
frasi = [
    ("A long release procedure sitting in a skill doesn't weigh on your "
     "unrelated bug fix the way it would in CLAUDE.md.",
     "https://code.claude.com/docs/en/best-practices"),
    ("Appending the system prompt can have a higher context cost compared to "
     "other methods of passing instructions.", STEERING),
    ("It increases input tokens, though prompt caching reduces this cost "
     "after the first request in a session.", STEERING),
    ("Unlike CLAUDE.md content, a skill’s body loads only when it’s used, so "
     "long reference material costs almost nothing until you need it.",
     SKILLS),
    ("(default) | Yes | Yes | Description always in context, full skill "
     "loads when invoked", SKILLS),
    ("When you or Claude invoke a skill, the rendered SKILL.md content enters "
     "the conversation as a single message and stays there across later "
     "turns.", SKILLS),
    ("total_input_tokens = cache_read_input_tokens + "
     "cache_creation_input_tokens + input_tokens",
     "https://platform.claude.com/docs/en/build-with-claude/prompt-caching"),
    ("CLAUDE.md | Session start | Full content of each file that loads at "
     "session start | Every request", OVERVIEW),
    ("Skills | Session start + when used | Descriptions at start, full "
     "content when used | Low (descriptions every request)", OVERVIEW),
    ("Keep your main SKILL.md under 500 lines. Move detailed reference "
     "material to separate files.", SPEC),
    ("Instructions (< 5000 tokens recommended): The full SKILL.md body is "
     "loaded when the skill is activated", SPEC),
    ("User-invoked skills and custom commands work. Include /skill-name in "
     "the prompt string and Claude Code expands it before running.",
     "https://code.claude.com/docs/en/headless"),
    ("«VERIFICA OK M5-D01: fatto.»", SKILLS),
]
piatto = " ".join(readme.split())
for frase, url in frasi:
    if frase not in piatto:
        problemi.append("manca la frase «%s…»" % frase[:40])
    if url not in readme:
        problemi.append("manca l'indirizzo %s" % url)
for numero, nome in ((1, "domanda.txt"), (2, "domanda_invocata.txt"),
                     (3, "domanda_dopo.txt")):
    blocco = re.search(r"<!-- prompt %d -->\n(.*?)\n\s*<!-- /prompt %d -->"
                       % (numero, numero), readme, re.S)
    with open(os.path.join(item, "demo", nome), encoding="utf-8") as fh:
        atteso = fh.read().strip()
    if not blocco or blocco.group(1).strip() != atteso:
        problemi.append("il prompt %d non è %s" % (numero, nome))
maniglie = re.compile(r"\bFACT-(?:C|M[0-9])-[0-9]{3}\b|\bM[0-9]-X[0-9]+\b"
                      r"|\bX-[0-9]+\b|(?<![\w-])D(?:0[1-9]|[12][0-9]|3[01])\b"
                      r"|\b(?:ASK|OQ|DEC|TD|PQ)-[0-9]+\b|(?i:\btriage\b)")
for cartella, sotto, file in os.walk(item):
    sotto[:] = [d for d in sotto if d != "soluzione"]
    for nome in file:
        rel = os.path.relpath(os.path.join(cartella, nome), item)
        try:
            with open(os.path.join(cartella, nome), encoding="utf-8") as fh:
                testo = fh.read()
        except (OSError, UnicodeDecodeError):
            continue
        for m in maniglie.finditer(testo):
            problemi.append("%s: un nome interno «%s»" % (rel, m.group()))
        if "/home/" in testo:
            problemi.append("%s: un percorso personale" % rel)
        if "smentit" in testo:
            problemi.append("%s: «smentita»" % rel)
if re.search(r"(?i)\boggi\b|prossima sessione|\bpausa\b|pranzo", readme):
    problemi.append("il README parla della giornata")
print("; ".join(problemi) or "README in ordine")
PY
  expect "README: sezioni, frasi, indirizzi, prompt, nessun nome interno" 0 \
    "README in ordine"
}

# prepara_esercizio.sh: i file della demo; nessun progetto né materiale del
# docente; verifica.sh esce 1 sul punto di partenza.
t_prepara() {
  local w
  if ! nuovo_ws w; then
    fail "prepara: prepara_esercizio.sh non riesce: $(cat "${TMP}/prepara.log")"
    return 0
  fi
  if [[ -f "${w}/testo.md" && -f "${w}/controlla_costo.py" \
      && -f "${w}/prepara_bracci.sh" && -f "${w}/in_classe.sh" \
      && -f "${w}/.claude/settings.json" && ! -e "${w}/_docente" \
      && ! -e "${w}/soluzione" && ! -e "${w}/progetti" \
      && ! -e "${w}/bracci" ]]; then
    pass "prepara: i file della demo, senza il materiale del docente"
  else
    fail "prepara: lo spazio di lavoro non è quello atteso: $(ls -A "${w}")"
  fi
  run "${RADICE}/tools/verifica.sh" M5-D01 --radice "${w%/*}"
  expect "prepara: sul punto di partenza la verifica esce 1" 1 \
    "Manca la cartella risposte/"
}

# --- prepara_bracci.sh ------------------------------------------------------

t_bracci() {
  local b f
  run bash "${D01}/demo/prepara_bracci.sh" "${TMP}/bracci"
  if (( RC != 0 )); then
    fail "bracci: prepara_bracci.sh esce ${RC}: ${OUT:0:300}"
    mkdir -p "${TMP}/bracci/"{skill,claude_md,append,niente}
  else
    pass "bracci: prepara_bracci.sh esce 0"
  fi
  for b in skill claude_md append niente; do
    vero "bracci: ${b} è un repository git" test -d "${TMP}/bracci/${b}/.git"
    run git -C "${TMP}/bracci/${b}" status --porcelain
    if (( RC == 0 )) && [[ -z "${OUT}" ]]; then
      pass "bracci: ${b} è pulito"
    else
      fail "bracci: ${b}: rc=${RC}, «${OUT}»"
    fi
    run git -C "${TMP}/bracci/${b}" rev-list --count HEAD
    expect "bracci: ${b} ha un commit" 0 "1"
  done
  f="${TMP}/bracci/skill/.claude/skills/procedure-assistenza/SKILL.md"
  run git -C "${TMP}/bracci/skill" ls-files
  expect "bracci: nel braccio della skill soltanto SKILL.md" 0 \
    ".claude/skills/procedure-assistenza/SKILL.md"
  expect_absent "bracci: nessun CLAUDE.md nel braccio della skill" "CLAUDE.md"
  run python3 -B -I - "${f}" "${D01}/demo/testo.md" <<'PY'
import re, sys
skill = open(sys.argv[1], encoding="utf-8").read()
testo = open(sys.argv[2], encoding="utf-8").read()
m = re.match(r"---\nname: procedure-assistenza\n"
             r"description: (.*)\n---\n\n", skill)
if not m or skill[m.end():] != testo:
    print("il corpo non è testo.md")
elif "Da usare quando" not in m.group(1):
    print("la description non dice quando")
else:
    print("skill a posto")
PY
  expect "bracci: la skill, name, description e corpo uguale a testo.md" 0 \
    "skill a posto"
  run python3 -B -I "${RADICE}/tools/controlla_skill.py" "${f%/*}"
  expect "bracci: controlla_skill.py passa sulla skill" 0 "0 errori"
  expect_absent "bracci: la description dice quando usarla" \
    "AVVISO description"
  vero "bracci: CLAUDE.md è testo.md" \
    cmp -s "${TMP}/bracci/claude_md/CLAUDE.md" "${D01}/demo/testo.md"
  vero "bracci: nel braccio dell'append, testo.md" \
    cmp -s "${TMP}/bracci/append/testo.md" "${D01}/demo/testo.md"
  run git -C "${TMP}/bracci/niente" ls-files
  if (( RC == 0 )) && [[ -z "${OUT}" ]]; then
    pass "bracci: niente non ha file"
  else
    fail "bracci: niente ha «${OUT}»"
  fi
  run bash "${D01}/demo/prepara_bracci.sh" "${TMP}/bracci"
  expect "bracci: una cartella che c'è già, uscita 2" 2 "c'è già"
  run bash "${D01}/demo/prepara_bracci.sh"
  expect "bracci: senza argomenti, uscita 2" 2 "uso:"
  mkdir -p "${TMP}/solo_script"
  cp -- "${D01}/demo/prepara_bracci.sh" "${TMP}/solo_script/"
  run bash "${TMP}/solo_script/prepara_bracci.sh" "${TMP}/altri"
  expect "bracci: senza testo.md, uscita 2" 2 "testo.md"
  vero "bracci: senza testo.md nessun braccio" test ! -e "${TMP}/altri"
}

# --- controlla_costo.py -----------------------------------------------------

# Tre esecuzioni pulite: la tabella, i dati, i verdetti.
t_complete() {
  local j
  nuova_serie j 3
  controlla "${j}"
  expect "controllo: tre esecuzioni, uscita 0" 0 "confermata 3 su 3"
  expect "controllo: righe e caratteri del testo" 0 \
    "testo.md: 187 righe, 10.859 caratteri."
  expect "controllo: il primo confronto" 0 "${S_CLAUDE}"
  expect "controllo: il secondo confronto" 0 "${S_APPEND}"
  expect "controllo: il verdetto di un'esecuzione" 0 \
    "esecuzione 2: confermata (17.050 token contro 21.669)"
  expect "controllo: una riga della tabella" 0 \
    "1      17.000      17.050      21.669      21.669"
  expect "controllo: sopra il braccio niente" 0 \
    "skill +50, claude_md +4.669, append +4.669"
  expect "controllo: append contro claude_md, come dato" 0 \
    "append meno claude_md 0"
  expect "controllo: invocata meno non invocata, e il turno dopo" 0 \
    "non invocata 17.050; invocata 21.719 (+4.669); turno dopo 21.735 (+4.685)"
  expect "controllo: la risposta dell'invocata" 0 "20 Mbit/s"
  expect "controllo: la risposta del turno dopo" 0 "100 Mbit/s"
  expect "controllo: Skill sulla domanda, come dato" 0 \
    "Chiamate a Skill sulla domanda, nel braccio della skill: 0 su 3."
  expect_absent "controllo: nessuna segnalazione" "SEGNALAZIONE"
  expect_absent "controllo: nessun «non confermata»" "${NONCONF}"
  expect_absent "controllo: la frase finale è della verifica" "Fatto:"
  nuova_serie j 1
  controlla "${j}"
  expect "controllo: un'esecuzione sola basta" 0 "confermata 1 su 1"
}

# I verdetti che cambiano: mai un'uscita diversa da 0 per un confronto.
t_verdetti() {
  local j
  nuova_serie j 3
  rifai "${j}" skill-2 FINTO_PRIMA=21669
  controlla "${j}"
  expect "verdetti: lo stesso conto, non distinguibile, uscita 0" 0 \
    "esecuzione 2: ${NONDIST} (21.669 token"
  expect "verdetti: e il riepilogo" 0 "confermata 2 su 3"
  rifai "${j}" skill-2 FINTO_PRIMA=30000
  controlla "${j}"
  expect "verdetti: skill sopra, non confermata, uscita 0" 0 \
    "esecuzione 2: ${NONCONF} (30.000 token contro 21.669)"
  expect "verdetti: il riepilogo non conta quella" 0 "confermata 2 su 3"
  expect_absent "verdetti: nessuna segnalazione per un confronto" \
    "SEGNALAZIONE"
  nuova_serie j 1
  rifai "${j}" append-1 FINTO_PRIMA=21500
  rifai "${j}" claude_md-1 FINTO_PRIMA=21000
  controlla "${j}"
  expect "verdetti: append contro claude_md resta un dato" 0 \
    "append meno claude_md +500"
  rifai "${j}" append-1 FINTO_PRIMA=20500
  controlla "${j}"
  expect "verdetti: append sotto claude_md resta un dato" 0 \
    "append meno claude_md -500"
  expect_absent "verdetti: nessun verdetto fra append e claude_md" \
    "${NONCONF}"
}

# Le segnalazioni: uscita 1.
t_segnalazioni() {
  local j b
  for b in claude_md append niente; do
    nuova_serie j 1
    rifai "${j}" "${b}-1" FINTO_SKILL_SEMPRE=code-review
    controlla "${j}"
    expect "segnalazione: Skill nel braccio ${b}, uscita 1" 1 \
      "SEGNALAZIONE ${b}-1: una chiamata a Skill (code-review)"
  done
  nuova_serie j 1
  rifai "${j}" skill-1 FINTO_SKILL_SEMPRE=procedure-assistenza
  controlla "${j}"
  expect "Skill nel braccio della skill: un dato, uscita 0" 0 \
    "Chiamate a Skill sulla domanda, nel braccio della skill: 1 su 1."
  expect_absent "Skill nel braccio della skill: nessuna segnalazione" \
    "SEGNALAZIONE"
  nuova_serie j 1
  rifai "${j}" skill-1 FINTO_SENZA_SKILL_INIT=1
  controlla "${j}"
  expect "segnalazione: il braccio della skill senza la skill, uscita 1" 1 \
    "SEGNALAZIONE skill-1: procedure-assistenza non è fra le skill"
  nuova_serie j 1
  rifai "${j}" skill_invocata-1 FINTO_SENZA_SKILL_INIT=1
  controlla "${j}"
  expect "segnalazione: anche nella sessione invocata, uscita 1" 1 \
    "SEGNALAZIONE skill_invocata-1"
  nuova_serie j 1
  stream_finto "${j}" niente-1 "${TMP}/bracci/skill" "${Q}" \
    -- --no-session-persistence
  controlla "${j}"
  expect "segnalazione: la skill dov'è fuori posto, uscita 1" 1 \
    "SEGNALAZIONE niente-1: procedure-assistenza è fra le skill"
}

# Gli stream che mancano o non si leggono: uscita 2, mai un conteggio più
# piccolo né un traceback.
t_illeggibili() {
  local j v
  nuova_serie j 2
  rm -- "${j}/append-2.jsonl" "${j}/skill_dopo-1.jsonl"
  controlla "${j}"
  expect "illeggibile: uno stream che manca, uscita 2" 2 "append-2.jsonl"
  expect "illeggibile: li dice tutti" 2 "skill_dopo-1.jsonl"
  expect_absent "illeggibile: nessuna tabella a metà" "confermata"
  nuova_serie j 1
  : > "${j}/append-1.jsonl"
  controlla "${j}"
  expect "illeggibile: uno stream vuoto, uscita 2" 2 "append-1.jsonl è vuoto"
  for v in "FINTO_RIGA_ROTTA=1:non è JSON" \
      "FINTO_TRONCO=1:non finisce con il risultato" \
      "FINTO_ERRORE=1:un errore" "FINTO_SENZA_INIT=1:system/init" \
      "FINTO_INIT_SENZA_ELENCO=1:system/init" \
      "FINTO_SENZA_ASSISTENTE=1:nessun messaggio dell'assistente" \
      "FINTO_SENZA_USO=1:usage" "FINTO_CAMPO_MANCANTE=1:usage" \
      "FINTO_ZERO=1:zero token"; do
    nuova_serie j 1
    rifai "${j}" skill-1 "${v%%:*}"
    controlla "${j}"
    expect "illeggibile: ${v%%=*}, uscita 2" 2 "${v#*:}"
  done
  nuova_serie j 1
  printf '\xff\xfe non è UTF-8\n' > "${j}/skill-1.jsonl"
  controlla "${j}"
  expect "illeggibile: non è UTF-8, uscita 2" 2 "non si legge"
  nuova_serie j 1
  if (( EUID != 0 )); then
    chmod 000 "${j}/skill-1.jsonl"
    controlla "${j}"
    expect "illeggibile: un file senza permessi, uscita 2" 2 "non si legge"
    chmod 644 "${j}/skill-1.jsonl"
  else
    skip "illeggibile: un file senza permessi (da root si legge)"
  fi
  j="$(mktemp -d "${TMP}/json.XXXXXX")" || exit 2
  controlla "${j}"
  expect "illeggibile: una cartella senza stream, uscita 2" 2 "nessuno stream"
  controlla "${TMP}/non_esiste"
  expect "illeggibile: una cartella che non c'è, uscita 2" 2 "non esiste"
  controlla
  expect "illeggibile: senza argomenti, uscita 2" 2 "Uso:"
  controlla "${j}" "${j}"
  expect "illeggibile: due cartelle, uscita 2" 2 "Uso:"
  controlla --boh
  expect "illeggibile: un'opzione sconosciuta, uscita 2" 2 "Uso:"
  mkdir -p "${TMP}/solo_controllo"
  cp -- "${D01}/demo/controlla_costo.py" "${TMP}/solo_controllo/"
  nuova_serie j 1
  run python3 -B -I "${TMP}/solo_controllo/controlla_costo.py" "${j}"
  expect "illeggibile: senza testo.md accanto, uscita 2" 2 "testo.md"
}

# --- verifica.sh ------------------------------------------------------------

t_verifica() {
  local w j
  run "${D01}/verifica.sh"
  expect "verifica: senza argomenti, uscita 2" 2 "spazio di lavoro assente"
  run "${D01}/verifica.sh" "${TMP}/non_esiste"
  expect "verifica: uno spazio che non c'è, uscita 2" 2 \
    "spazio di lavoro assente"
  nuovo_ws w || { fail "verifica: nessuno spazio di lavoro"; return 0; }
  run env PATH="${TMP}/senza_python" "${D01}/verifica.sh" "${w}"
  expect "verifica: senza python3, uscita 2" 2 "manca python3"
  run "${D01}/verifica.sh" "${w}"
  expect "verifica: senza risposte/, uscita 1" 1 "Manca la cartella risposte/"
  mkdir -p "${w}/risposte"
  run "${D01}/verifica.sh" "${w}"
  expect "verifica: risposte/ vuota, uscita 1" 1 "nessuno stream"
  rmdir "${w}/risposte"
  nuova_serie j 3
  cp -R "${j}" "${w}/risposte"
  run "${D01}/verifica.sh" "${w}"
  expect "verifica: gli stream ci sono, uscita 0" 0 "${FATTO}"
  expect "verifica: stampa i verdetti" 0 "confermata 3 su 3"
  rifai "${w}/risposte" skill-1 FINTO_PRIMA=30000
  run "${D01}/verifica.sh" "${w}"
  expect "verifica: un confronto non confermato non la ferma" 0 "${FATTO}"
  expect "verifica: ma lo dice" 0 "${NONCONF}"
  rifai "${w}/risposte" niente-2 FINTO_SKILL_SEMPRE=code-review
  run "${D01}/verifica.sh" "${w}"
  expect "verifica: una segnalazione, uscita 1" 1 "SEGNALAZIONE niente-2"
  expect_absent "verifica: niente «Fatto» con una segnalazione" "Fatto:"
  printf 'import sys\nsys.exit(0)\n' > "${w}/controlla_costo.py"
  run "${D01}/verifica.sh" "${w}"
  expect "verifica: il controllo dell'elemento, non quello dello spazio" 1 \
    "SEGNALAZIONE niente-2"
  rm -- "${w}/risposte/append-3.jsonl"
  rifai "${w}/risposte" niente-2
  run "${D01}/verifica.sh" "${w}"
  expect "verifica: uno stream che manca, uscita 2" 2 "append-3.jsonl"
}

# --- demo/in_classe.sh e _docente/live.sh -----------------------------------

t_live_precondizioni() {
  local w ic="${D01}/demo/in_classe.sh" chiave
  nuovo_ws w || { fail "live: nessuno spazio di lavoro"; return 0; }
  precondizione "in classe: uno spazio che non c'è" "spazio di lavoro assente" \
    "${ic}" "${TMP}/non_esiste"
  precondizione "in classe: senza claude" "manca lo strumento: claude" \
    "${ic}" "${w}" "${TMP}/senza_claude"
  precondizione "in classe: senza python3" "manca lo strumento: python3" \
    "${ic}" "${w}" "${TMP}/senza_python"
  precondizione "in classe: PN_ESECUZIONI=0" "PN_ESECUZIONI" \
    "${ic}" "${w}" "" PN_ESECUZIONI=0
  precondizione "in classe: PN_ESECUZIONI non è un numero" "PN_ESECUZIONI" \
    "${ic}" "${w}" "" PN_ESECUZIONI=tre
  precondizione "in classe: HANDSON_ENV sbagliato" "claude-code-pro" \
    "${ic}" "${w}" "" HANDSON_ENV=trainer-api
  precondizione "in classe: bypassPermissions" "modalità di permesso" \
    "${ic}" "${w}" "" HANDSON_PERMISSION_MODE=bypassPermissions
  precondizione "in classe: PN_LIVE_JSON dentro lo spazio" "non stanno" \
    "${ic}" "${w}" "" PN_LIVE_JSON="${w}/dentro"
  mkdir -p "${TMP}/vecchi"
  : > "${TMP}/vecchi/niente-1.jsonl"
  precondizione "in classe: una prova che c'è già" "c'è già una prova" \
    "${ic}" "${w}" "" PN_LIVE_JSON="${TMP}/vecchi"
  rm -- "${w}/domanda.txt"
  precondizione "in classe: un file che manca" "domanda.txt" "${ic}" "${w}"
  git -C "${w}" checkout -q -- domanda.txt
  : > "${w}/sporco.txt"
  precondizione "in classe: non al punto di partenza" "punto di partenza" \
    "${ic}" "${w}"
  rm -- "${w}/sporco.txt"
  rm -rf -- "${w}/.git"
  precondizione "in classe: non è un repository git" "repository git" \
    "${ic}" "${w}"
  nuovo_ws w || return 0
  chiave="sk-ant""-finta"
  printf 'Rispondi. %s\n' "${chiave}" > "${w}/domanda.txt"
  git -C "${w}" -c user.name=Prova -c user.email=prova@example.org \
    commit -q -am 'domanda con una chiave' || true
  precondizione "in classe: una chiave API nella domanda" \
    "sembra una chiave API" "${ic}" "${w}"
  expect_absent "in classe: la chiave non si stampa" "${chiave}"
  nuovo_ws w || return 0
  run env PATH="${TMP}/esca:${PATH}" ESCA_LOG="${TMP}/esca.log" \
    HANDSON_NO_PAUSE=1 "${w}/in_classe.sh" "${w}"
  expect "in classe: dalla copia nello spazio, senza il repository" 2 \
    "lib_handson.sh"
  precondizione "live: uno spazio che non c'è" "spazio di lavoro assente" \
    "${D01}/_docente/live.sh" "${TMP}/non_esiste"
  run "${D01}/_docente/live.sh"
  expect "live: senza argomenti, uscita 2" 2 "uso:"
}

t_live_finto() {
  local w ic="${D01}/demo/in_classe.sh" n
  nuovo_ws w || { fail "live: nessuno spazio di lavoro"; return 0; }
  finto "${D01}/_docente/live.sh" "${w}"
  expect "live: tre esecuzioni, uscita 0" 0 "confermata 3 su 3"
  expect "live: il comando si vede" 0 "claude -p"
  expect "live: l'append si vede" 0 "--append-system-prompt-file testo.md"
  expect "live: il verdetto OK" 0 "VERIFICA OK"
  controlla_chiamate "${TMP}/finto.log" "${w}" 3 "${w}.prova_dal_vivo"
  expect "live: diciotto chiamate, con i testi e le opzioni giuste" 0 \
    "chiamate giuste"
  n="$(command find "${w}/risposte" -name '*.jsonl' | wc -l)"
  if (( n == 18 )); then
    pass "live: diciotto stream in risposte/"
  else
    fail "live: ${n} stream in risposte/"
  fi
  n="$(command find "${w}.prova_dal_vivo" -name '*.jsonl' | wc -l)"
  if (( n == 18 )); then
    pass "live: diciotto stream fuori dallo spazio di lavoro"
  else
    fail "live: ${n} stream in ${w}.prova_dal_vivo"
  fi
  run "${RADICE}/tools/verifica.sh" M5-D01 --radice "${w%/*}"
  expect "live: dopo la prova la verifica passa" 0 "${FATTO}"
  nuovo_ws w || return 0
  finto "${ic}" "${w}"
  expect "in classe: un'esecuzione, uscita 0" 0 "confermata 1 su 1"
  controlla_chiamate "${TMP}/finto.log" "${w}" 1 "${w}.prova_dal_vivo"
  expect "in classe: sei chiamate" 0 "chiamate giuste"
  nuovo_ws w || return 0
  finto "${ic}" "${w}" PN_ESECUZIONI=2 PN_LIVE_JSON="${TMP}/altrove"
  expect "in classe: PN_ESECUZIONI=2" 0 "confermata 2 su 2"
  controlla_chiamate "${TMP}/finto.log" "${w}" 2 "${TMP}/altrove"
  expect "in classe: PN_LIVE_JSON, dodici chiamate" 0 "chiamate giuste"
  nuovo_ws w || return 0
  finto "${w}/in_classe.sh" "${w}" PN_HANDSON_ROOT="${RADICE}"
  expect "in classe: dalla copia nello spazio, con PN_HANDSON_ROOT" 0 \
    "confermata 1 su 1"
}

t_live_esiti() {
  local w ic="${D01}/demo/in_classe.sh" n
  nuovo_ws w || { fail "live: nessuno spazio di lavoro"; return 0; }
  finto "${ic}" "${w}" FINTO_ESITO_KO_SE=claude_md
  n="$(grep -c 'claude_md' "${TMP}/finto.log")"
  if (( RC == 1 )) && (( n == 1 )) && grep -qF 'VERIFICA KO' <<< "${OUT}" \
      && [[ -s "${w}/risposte/skill-1.jsonl" ]]; then
    pass "in classe: si ferma alla chiamata fallita, gli altri in risposte/"
  else
    fail "in classe: chiamata fallita: rc=${RC}, ${n}: ${OUT:0:300}"
  fi
  nuovo_ws w || return 0
  finto "${ic}" "${w}" FINTO_ESITO_KO_SE=download
  expect "in classe: la ripresa fallita, uscita 1" 1 "skill_dopo-1"
  nuovo_ws w || return 0
  finto "${ic}" "${w}" FINTO_TRONCO=1
  expect "in classe: uno stream senza risultato, nessun ID, uscita 1" 1 \
    "nessun ID di sessione"
  nuovo_ws w || return 0
  finto "${ic}" "${w}" FINTO_SKILL_SEMPRE=code-review
  expect "in classe: una segnalazione, uscita 1" 1 "VERIFICA KO"
  expect "in classe: e la segnalazione si vede" 1 "SEGNALAZIONE niente-1"
  nuovo_ws w || return 0
  finto "${ic}" "${w}" FINTO_ZERO=1
  expect "in classe: stream che non si leggono, uscita 2" 2 "zero token"
}

# Il README e la registrazione: le righe che cita sono quelle che verifica.sh
# stampa sugli stream di soluzione/. Qui anche le uscite dello strumento che lo
# controlla, controlla_registrazione.py: le altre suite lo usano soltanto.
t_registrazione() {
  local w uscita="${TMP}/uscita.txt"
  local s="${MOD}/_docente/controlla_registrazione.py"
  nuovo_ws w || { fail "registrazione: lo spazio di lavoro"; return 0; }
  cp -R "${D01}/soluzione/." "${w}/" || exit 2
  run "${D01}/verifica.sh" "${w}"
  expect "registrazione: verifica.sh su soluzione/, uscita 0" 0 "${FATTO}"
  printf '%s\n' "${OUT}" > "${uscita}"
  run python3 -B -I "${s}" "${D01}/README.md" "${uscita}" <<'FRASI'
= skill +124, claude_md +4.980, append +4.842; append meno claude_md -138
= non invocata 17.395; invocata 22.388 (+4.993)
= 22.532 (+5.137)
= 22.540 (+5.145)
= 22.551 (+5.156)
= confermata 3 su 3
= Chiamate a Skill sulla domanda, nel braccio della skill: 0 su 3.
R Nella registrazione del corso (3 novembre 2026, Claude Code 2.1.317, Sonnet con effort low, tre esecuzioni
R sull'account del docente, un piano Max
R 372.657
R 45.154, 45.169 e 45.196
! <!-- registrazione
! si aggiunge qui
! atteso a chiamata
FRASI
  expect "registrazione: il README cita le righe del controllo" 0 "in ordine"
  run python3 -B -I "${s}" "${D01}/README.md" "${uscita}" \
    <<< '= una frase che non sta da nessuna parte'
  expect "registrazione: una frase che manca, uscita 1" 1 "manca nel README"
  run python3 -B -I "${s}" "${D01}/README.md" "${uscita}" \
    <<< '= Per approfondire'
  expect "registrazione: una frase fuori dal controllo, uscita 1" 1 \
    "non è nell'uscita"
  run python3 -B -I "${s}" "${D01}/README.md" "${uscita}" <<< '! Per approfondire'
  expect "registrazione: una frase vietata, uscita 1" 1 "non ci deve stare"
  run python3 -B -I "${s}" "${D01}/README.md" "${uscita}" <<< 'senza segno'
  expect "registrazione: una riga senza segno, uscita 2" 2 "senza segno"
  run python3 -B -I "${s}" "${D01}/README.md" "${uscita}" <<< ''
  expect "registrazione: nessuna frase, uscita 2" 2 "nessuna frase"
  run python3 -B -I "${s}" "${TMP}/non-c-e" "${uscita}" <<< '= una frase'
  expect "registrazione: un README che non c'è, uscita 2" 2 "non-c-e"
}

# Gli script di M5-D01 e questo file, con shellcheck -x.
t_shellcheck() {
  local f
  for f in "${D01}/verifica.sh" "${D01}/_docente/live.sh" \
      "${D01}/demo/in_classe.sh" "${D01}/demo/prepara_bracci.sh" "${SELF}"; do
    if [[ -f "${f}" ]] \
        && ( cd "${RADICE}" && shellcheck -x -- "${f}" ) > /dev/null 2>&1; then
      pass "shellcheck ${f#"${RADICE}"/}"
    else
      fail "shellcheck ${f#"${RADICE}"/}"
    fi
  done
}

main() {
  local t
  for t in python3 git shellcheck; do
    command -v "${t}" >/dev/null 2>&1 \
      || { echo "test_m5_d01: manca ${t}" >&2; exit 2; }
  done
  [[ -f "${FINTO_PY}" ]] \
    || { echo "test_m5_d01: manca ${FINTO_PY}" >&2; exit 2; }
  handson::init_temp_base
  TMP="$(mktemp -d "${HANDSON_TEMP_BASE}/test_m5_d01.XXXXXX")" || exit 2
  trap 'chmod -R u+rwX "${TMP}" 2>/dev/null; rm -rf "${TMP}"' EXIT
  prepara_claude
  t_elemento
  t_readme
  t_prepara
  t_bracci
  t_complete
  t_verdetti
  t_segnalazioni
  t_illeggibili
  t_verifica
  t_live_precondizioni
  t_live_finto
  t_live_esiti
  t_registrazione
  t_shellcheck
  OUT="${TUTTO}"
  expect_absent "in nessuna uscita «smentita»" "smentita"
  expect_absent "in nessuna uscita un traceback" "Traceback"
  echo "PASS=${PASS} FAIL=${FAIL} SKIP=${SKIP}"
  if (( PASS + FAIL + SKIP != CASES )); then
    echo "test_m5_d01: girati $((PASS + FAIL + SKIP)) casi, attesi" \
      "${CASES}" >&2
    exit 2
  fi
  (( FAIL == 0 )) || exit 1
}

main "$@"
