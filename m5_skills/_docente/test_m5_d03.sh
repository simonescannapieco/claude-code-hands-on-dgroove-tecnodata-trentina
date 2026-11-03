#!/bin/bash
#
# test_m5_d03.sh -- le prove di M5-D03 «Tre garanzie», per il docente (sta in
# _docente/, il materiale del docente):
#   - l'elemento: le skill dei bracci passano tools/controlla_skill.py e ogni
#     coppia differisce in una cosa sola; nessun codice nel repository; conta.sh
#     stampa una sentinella che nel suo testo non c'è; le frasi di Anthropic nel
#     README, con il loro indirizzo, nessun nome interno;
#   - prepara_esercizio.sh e verifica.sh sul punto di partenza (1);
#   - demo/in_classe.sh con il claude finto: un'esecuzione per braccio, le
#     chiamate e le loro opzioni, ogni braccio nella sua copia fuori dallo
#     spazio di lavoro, nessuna risposta lì mentre le sessioni girano,
#     --resume con la sessione giusta, senza ANTHROPIC_API_KEY; i temporanei;
#     le precondizioni (2, nessuna chiamata);
#   - controlla_garanzie.py: ogni garanzia che non regge (1, «non confermata»),
#     ogni coppia che non mostra la differenza (1, «non distinguibile»); gli
#     stream rovinati (1), le precondizioni (2), mai un traceback;
#   - verifica.sh: il controllo dell'elemento, mai quello dello spazio di
#     lavoro; _docente/live.sh: tre esecuzioni per braccio, le precondizioni;
#   - check_handson.sh senza segnalazioni su questo elemento; shellcheck.
# Mai il claude vero: il finto sta davanti nel PATH, e la suite lo controlla
# prima di usarlo. Gli stream del finto non sono risposte di Claude: provano il
# controllo, non il modello. Gli spazi di lavoro nascono in una cartella
# temporanea, nella base di handson::init_temp_base (mai dentro ~/.claude):
# l'albero del repository non cambia. CASES è il numero dei casi: se ne girano
# di più o di meno la suite esce 2.
#
# Uso:    m5_skills/_docente/test_m5_d03.sh
# Uscita: 0 = tutti i casi passano · 1 = almeno un caso fallito · 2 =
#         precondizione (manca python3, git o shellcheck; il finto non viene
#         prima nel PATH), o un numero di casi diverso da CASES
# shellcheck disable=SC2016  # backtick e $ sono il testo delle prove
set -uo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly MOD="${SELF%/_docente/*}"
readonly RADICE="${MOD%/*}"
readonly D03="${MOD}/s4_skills/m5_6_skill_e_claude_code/M5-D03_tre_garanzie"
readonly CONTROLLO="${D03}/demo/controlla_garanzie.py"
readonly FINTO_PY="${MOD}/_docente/claude_finto_m5_d03_e01.py"
# La libreria del repository, per la base dei file temporanei.
# shellcheck source=../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"
readonly CASES=215
readonly L_CODICE='! porta il dato prima che Claude legga'
readonly L_COMANDO="Un comando non consentito ferma l'invocazione"
readonly L_TURNO='allowed-tools vale per un turno'
readonly L_FORK='Con context: fork il subagent non vede la conversazione'
readonly NONCONF='non confermata in questa esecuzione'
readonly NONDIST='non distinguibile'
readonly TUTTE='Ogni garanzia è confermata in ogni esecuzione.'
readonly FATTO='Fatto: ogni garanzia è stata messa alla prova'
readonly SENTINELLA='sentinella-4216'
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
    fail "$1 (rc=${RC}, attesa $2, parola «$3»): ${OUT:0:800}"
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
  mkdir -p "${TMP}/finto" "${TMP}/sessioni" || exit 2
  cp -- "${FINTO_PY}" "${TMP}/finto/claude" || exit 2
  chmod +x "${TMP}/finto/claude" || exit 2
  export PATH="${TMP}/finto:${PATH}"
  export FINTO_SESSIONI="${TMP}/sessioni"
  export HANDSON_NO_PAUSE=1
  unset ANTHROPIC_API_KEY CLAUDE_CODE_EFFORT_LEVEL HANDSON_ENV
  [[ "$(command -v claude)" == "${TMP}/finto/claude" ]] \
    || { echo "test_m5_d03: il finto non viene prima nel PATH" >&2; exit 2; }
}

# Uno spazio di lavoro nuovo, con prepara_esercizio.sh in una radice nuova.
# Arguments: $1 la variabile da assegnare. Returns: 0; 1 se non riesce.
nuovo_ws() {
  local __r
  __r="$(mktemp -d "${TMP}/radice.XXXXXX")" || exit 2
  "${RADICE}/tools/prepara_esercizio.sh" M5-D03 --radice "${__r}" \
    > "${TMP}/prepara.log" 2>&1 || return 1
  printf -v "$1" '%s' "${__r}/M5-D03"
}

# in_classe.sh dello spazio di lavoro $1, con le variabili che seguono
# (NOME=valore); RC e OUT come run. La riga di ogni chiamata in $TMP/log.jsonl.
in_classe() {
  local w="$1"
  shift
  : > "${TMP}/log.jsonl"
  run env FINTO_LOG="${TMP}/log.jsonl" FINTO_SPAZIO="${w}" "$@" \
    bash "${w}/in_classe.sh"
}

# controlla_garanzie.py dell'elemento; RC e OUT come run.
controlla() { run python3 -B -I "${CONTROLLO}" "$@"; }

# Una copia dello spazio di lavoro buono, da rovinare.
# Arguments: $1 la variabile da assegnare.
copia_buona() {
  local __c
  __c="$(mktemp -d "${TMP}/copia.XXXXXX")" || exit 2
  cp -R "${BUONO}/risposte" "${__c}/" || exit 2
  printf -v "$1" '%s' "${__c}"
}

# Il numero di righe di $TMP/log.jsonl: le chiamate al finto.
chiamate() { grep -c '' "${TMP}/log.jsonl"; }

# ---------------------------------------------------------------- l'elemento

t_elemento() {
  local f
  for f in README.md verifica.sh demo/controlla_garanzie.py demo/in_classe.sh \
      demo/lib_coppie.sh demo/conta.sh demo/elenco.txt _docente/live.sh \
      soluzione/LEGGIMI.md; do
    vero "c'è ${f}" test -f "${D03}/${f}"
  done
  vero "verifica.sh è eseguibile" test -x "${D03}/verifica.sh"
  vero "live.sh è eseguibile" test -x "${D03}/_docente/live.sh"
  vero "la libreria di demo/ non è eseguibile" \
    test ! -x "${D03}/demo/lib_coppie.sh"
  if [[ -z "$(command find "${D03}/demo" -name 'codice.txt' -o \
      -name 'parola.txt')" ]]; then
    pass "nessun codice e nessuna parola nel repository"
  else
    fail "nessun codice e nessuna parola nel repository"
  fi
}

# Le skill dei bracci: il controllo del corso, i campi delle regole del corso.
t_skill() {
  local d nome
  local -a bracci=(codice-con codice-senza comando-con comando-senza
    permesso-con permesso-senza parola-inline parola-fork)
  for d in "${bracci[@]}"; do
    nome="$(command find "${D03}/demo/coppie/${d}/.claude/skills" -mindepth 1 \
      -maxdepth 1 -type d)"
    run python3 -B -I "${RADICE}/tools/controlla_skill.py" "${nome}"
    expect "${d}: controlla_skill.py senza errori" 0 ' 0 errori'
    if grep -qF 'Da usare quando' "${nome}/SKILL.md" \
        && [[ "$(grep -m1 '^name: ' "${nome}/SKILL.md")" \
          == "name: ${nome##*/}" ]]; then
      pass "${d}: name uguale alla cartella, «Da usare quando …»"
    else
      fail "${d}: name uguale alla cartella, «Da usare quando …»"
    fi
    if grep -q '!`' "${nome}/SKILL.md" \
        && ! grep -qFx 'compatibility: Requires Claude Code' \
          "${nome}/SKILL.md"; then
      fail "${d}: una riga ! senza compatibility"
    else
      pass "${d}: compatibility dove il corpo usa !"
    fi
    if grep -qE '<(role|context|instructions|format|constraints)>' \
        "${nome}/SKILL.md"; then
      fail "${d}: un tag del corso in uno SKILL.md"
    else
      pass "${d}: nessun tag del corso"
    fi
  done
}

# Le due skill di una coppia differiscono in una cosa sola, e nient'altro
# differisce fra le due cartelle.
t_coppie() {
  local c="${D03}/demo/coppie" a b
  local allowed=$'allowed-tools: Bash(bash conta.sh)\n'
  local fork=$'context: fork\n'
  a="$(< "${c}/codice-con/.claude/skills/prova-codice/SKILL.md")"
  b="$(< "${c}/codice-senza/.claude/skills/prova-codice/SKILL.md")"
  vero "codice: differiscono soltanto nel !" test "${a//\!\`/\`}" == "${b}"
  vero "codice: con c'è !\`cat codice.txt\`" \
    grep -qF '!`cat codice.txt`' \
    "${c}/codice-con/.claude/skills/prova-codice/SKILL.md"
  a="$(< "${c}/comando-con/.claude/skills/prova-conta/SKILL.md")"
  b="$(< "${c}/comando-senza/.claude/skills/prova-conta/SKILL.md")"
  vero "comando: differiscono soltanto in allowed-tools" \
    test "${a/"${allowed}"/}" == "${b}"
  vero "comando: !\`bash conta.sh\` nel corpo" \
    grep -qF '!`bash conta.sh`' \
    "${c}/comando-senza/.claude/skills/prova-conta/SKILL.md"
  a="$(< "${c}/permesso-con/.claude/skills/prova-esegui/SKILL.md")"
  b="$(< "${c}/permesso-senza/.claude/skills/prova-esegui/SKILL.md")"
  vero "permesso: differiscono soltanto in allowed-tools" \
    test "${a/"${allowed}"/}" == "${b}"
  a="$(< "${c}/parola-fork/.claude/skills/prova-parola/SKILL.md")"
  b="$(< "${c}/parola-inline/.claude/skills/prova-parola/SKILL.md")"
  vero "parola: differiscono soltanto in context: fork" \
    test "${a/"${fork}"/}" == "${b}"
}

# conta.sh: la sentinella esce soltanto se gira.
t_conta() {
  local righe
  run bash "${D03}/demo/conta.sh"
  righe="$(grep -c '' "${D03}/demo/elenco.txt")"
  expect "conta.sh stampa la sentinella e le righe" 0 \
    "${SENTINELLA}: ${righe} righe"
  if grep -qF "${SENTINELLA}" "${D03}/demo/conta.sh"; then
    fail "la sentinella non sta nel testo di conta.sh"
  else
    pass "la sentinella non sta nel testo di conta.sh"
  fi
  vero "il controllo cerca la stessa sentinella" \
    grep -qF "${SENTINELLA}" "${CONTROLLO}"
}

t_readme() {
  local testo frase parola
  testo="$(LC_ALL=C tr -s '[:space:]' ' ' < "${D03}/README.md")"
  while IFS= read -r frase; do
    if [[ "${testo}" == *"${frase}"* ]]; then
      pass "README: «${frase:0:48}…»"
    else
      fail "README: manca «${frase}»"
    fi
  done <<'FRASI'
The command output replaces the placeholder, so Claude receives actual data, not the command itself.
Outside auto mode, when a command's permission check returns anything other than allow, Claude Code aborts the invocation with the same error.
To keep an unmatched command from aborting here, pre-approve it with allowed-tools.
A failed command aborts the entire skill invocation, not just its own placeholder. Claude never sees the skill content for that invocation.
Tools Claude can use without asking permission during the turn that invokes this skill. The grant clears when you send your next message.
The grant clears when you send your next message, even though the skill content stays in context
It does not restrict which tools are available: every tool remains callable, and your permission settings still govern tools that are not listed.
The subagent doesn't see your conversation history, so the skill's instructions have to stand on their own.
Despite the name, a skill with context: fork doesn't run in a fork of the current conversation
https://code.claude.com/docs/en/skills
Esegui di nuovo bash conta.sh con Bash e riporta il risultato, così com'è.
Ricorda: la parola in codice è ciaspola-
tools/prepara_esercizio.sh M5-D03
tools/verifica.sh M5-D03
Claude Code denies every call that would otherwise prompt … though a mod you installed can still approve some of those calls.
--allowedTools Skill,Agent
tre esecuzioni per braccio e trentatré chiamate
«VERIFICA OK M5-D03: fatto.»
FRASI
  for parola in 'FACT-' 'M5-X' 'X-37' 'X-38' 'smentit' 'probe' 'oggi' \
      ' giro' ' giri' '134.7 s' 'locked-down CI runs'; do
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
  vero "lo spazio di lavoro ha in_classe.sh" test -f "${w}/in_classe.sh"
  vero "lo spazio di lavoro ha i bracci" \
    test -f "${w}/coppie/parola-fork/.claude/skills/prova-parola/SKILL.md"
  vero "niente _docente né soluzione" \
    test ! -e "${w}/_docente" -a ! -e "${w}/soluzione"
  run "${D03}/verifica.sh" "${w}"
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
  expect "e il braccio a cui appartiene" 0 '# permesso-con-1-dopo'
  expect "il dato di !: codice" 0 "${L_CODICE} (codice, 1): confermata"
  expect "il fermo: comando" 0 "${L_COMANDO} (comando, 1): confermata"
  expect "il turno: permesso" 0 "${L_TURNO} (permesso, 1): confermata"
  expect "il fork: parola" 0 "${L_FORK} (parola, 1): confermata"
  expect "i riepiloghi" 0 "${L_FORK}: confermata 1 su 1"
  expect "i dati di un braccio" 0 'codice, con, 1:'
  expect "la risposta col codice, senza strumenti" 0 \
    'il codice nella risposta: sì; strumenti: nessuno'
  expect "il fermo nei dati" 0 'fermata: sì'
  if [[ "$(chiamate)" == 11 ]]; then
    pass "un'esecuzione: undici chiamate"
  else
    fail "un'esecuzione: $(chiamate) chiamate, non 11"
  fi
  run python3 -B -I - "${TMP}/log.jsonl" "${BUONO}" <<'PY'
import json, os, re, sys
righe = [json.loads(r) for r in open(sys.argv[1], encoding="utf-8")]
ws = sys.argv[2]
comuni = {"--model": "sonnet", "--effort": "low",
          "--permission-mode": "dontAsk", "--permission-prompts": "none",
          "--output-format": "stream-json",
          "--setting-sources": "project,local"}
ordine = ["/prova-codice", "/prova-codice", "/prova-conta", "/prova-conta",
          "/prova-esegui", "Esegui di nuovo bash conta.sh con Bash e riporta "
          "il risultato, così com'è.", "/prova-esegui", "Ricorda",
          "/prova-parola", "Ricorda", "/prova-parola"]
def op(riga, nome):
    a = riga["argv"]
    return a[a.index(nome) + 1] if nome in a else None
for n, (riga, atteso) in enumerate(zip(righe, ordine), 1):
    assert riga["prompt"].startswith(atteso), (n, riga["prompt"])
    assert riga["argv"][0] == "-p" and riga["argv"][-2] == "--", n
    for nome, valore in comuni.items():
        assert op(riga, nome) == valore, (n, nome)
    assert "--verbose" in riga["argv"] and "--strict-mcp-config" in riga["argv"]
    assert not riga["chiave"] and not riga["effort_env"], n
    assert riga["stdin_nullo"], n
    assert riga["git"], n
    assert not riga["risposte"], (n, "risposte/ durante le sessioni")
    assert not riga["cwd"].startswith(ws), (n, riga["cwd"])
    assert ".claude" in riga["file"], n
senza_salvare = [n for n, r in enumerate(righe)
                 if "--no-session-persistence" in r["argv"]]
assert senza_salvare == [0, 1, 2, 3], senza_salvare
assert [n for n, r in enumerate(righe) if op(r, "--resume")] == [5, 8, 10]
assert [n for n, r in enumerate(righe) if op(r, "--allowedTools")] \
    == [7, 8, 9, 10]
assert all(op(r, "--allowedTools") == "Skill,Agent"
           for r in righe[7:])
assert righe[4]["cwd"] == righe[5]["cwd"]
assert righe[7]["cwd"] == righe[8]["cwd"]
assert righe[9]["cwd"] == righe[10]["cwd"]
cartelle = {r["cwd"] for r in righe}
assert len(cartelle) == 8, cartelle
assert "codice.txt" in righe[0]["file"] and "codice.txt" in righe[1]["file"]
for n in (2, 3, 4, 6):
    assert "conta.sh" in righe[n]["file"] and "elenco.txt" in righe[n]["file"]
    assert "codice.txt" not in righe[n]["file"]
for n in (7, 9):
    assert "codice.txt" not in righe[n]["file"]
    assert "conta.sh" not in righe[n]["file"]
parola = open(os.path.join(ws, "risposte", "parola.txt"),
              encoding="utf-8").read().strip()
assert parola in righe[7]["prompt"] and parola in righe[9]["prompt"]
assert re.match(r"^Ricorda: la parola in codice è \S+\. Rispondi solo: ok$",
                righe[7]["prompt"]), righe[7]["prompt"]
codice = open(os.path.join(ws, "risposte", "codice.txt"),
              encoding="utf-8").read().strip()
assert re.match(r"^[0-9a-f]{16}$", codice), codice
print("ok, le chiamate")
PY
  expect "ogni chiamata con le sue opzioni, nella sua copia" 0 'ok, le chiamate'
  vero "gli stream in risposte/" test -s "${BUONO}/risposte/parola-fork-1.jsonl"
  run "${D03}/verifica.sh" "${BUONO}"
  expect "verifica.sh dopo in_classe.sh: 0" 0 "${FATTO}"
}

# Due esecuzioni, due spazi di lavoro: il codice e la parola sono casuali.
t_casuali() {
  local w
  nuovo_ws w || { fail "un altro spazio di lavoro"; return 0; }
  in_classe "${w}"
  if cmp -s "${w}/risposte/codice.txt" "${BUONO}/risposte/codice.txt" \
      || cmp -s "${w}/risposte/parola.txt" "${BUONO}/risposte/parola.txt"; then
    fail "il codice e la parola cambiano da uno spazio di lavoro all'altro"
  else
    pass "il codice e la parola cambiano da uno spazio di lavoro all'altro"
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
  guasto "! non porta il dato" FINTO_BANG_NON_SOSTITUISCE \
    "${L_CODICE} (codice, 1): ${NONCONF}"
  guasto "! e uno strumento" FINTO_BANG_STRUMENTO \
    "${L_CODICE} (codice, 1): ${NONDIST}"
  guasto "senza ! il dato arriva lo stesso" FINTO_DATO_SENZA_STRUMENTI \
    "${L_CODICE} (codice, 1): ${NONDIST}"
  guasto "il comando non consentito gira" FINTO_FERMO_IGNORATO \
    "${L_COMANDO} (comando, 1): ${NONCONF}"
  guasto "allowed-tools non pre-approva" FINTO_ALLOWED_IGNORATO \
    "${L_COMANDO} (comando, 1): ${NONCONF}"
  guasto "allowed-tools non concede il turno" FINTO_ALLOWED_IGNORATO \
    "${L_TURNO} (permesso, 1): ${NONCONF}"
  guasto "il permesso resta al messaggio dopo" FINTO_GRANT_RESTA \
    "${L_TURNO} (permesso, 1): ${NONCONF}"
  guasto "Claude non riprova al messaggio dopo" FINTO_NON_RIPROVA \
    "${L_TURNO} (permesso, 1): ${NONDIST}"
  guasto "Claude non esegue" FINTO_NON_ESEGUE \
    "${L_TURNO} (permesso, 1): ${NONDIST}"
  guasto "il subagent vede la parola" FINTO_FORK_VEDE \
    "${L_FORK} (parola, 1): ${NONCONF}"
  guasto "context: fork senza subagent" FINTO_FORK_INLINE \
    "${L_FORK} (parola, 1): ${NONDIST}"
  guasto "senza fork la parola non torna" FINTO_INLINE_NON_VEDE \
    "${L_FORK} (parola, 1): ${NONDIST}"
  guasto "--resume apre un'altra sessione: la parola" FINTO_ALTRA_SESSIONE \
    "${L_FORK} (parola, 1): ${NONDIST}"
  guasto "--resume apre un'altra sessione: il permesso" FINTO_ALTRA_SESSIONE \
    "${L_TURNO} (permesso, 1): ${NONDIST}"
  nuovo_ws w || { fail "lo spazio di lavoro"; return 0; }
  in_classe "${w}" FINTO_GRANT_RESTA=1
  run "${D03}/verifica.sh" "${w}"
  expect "verifica.sh su una garanzia che non regge: 1" 1 "${NONCONF}"
  expect_absent "verifica.sh: nessun «Fatto»" "${FATTO}"
  expect "chi legge sa che è da segnalare" 1 'da segnalare'
}

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

# Il testo del risultato di uno stream cambiato con Python.
# Arguments: $1 il file, $2 l'espressione Python del nuovo testo (riceve `e`).
cambia_risultato() {
  cambia_eventi "$1" \
    "e.update(result=$2) if e.get('type') == 'result' else None"
}

# ------------------------------------------------------ gli stream rovinati

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
  expect "i secondi con la virgola: una chiamata" 0 '; 1,0 s'
  expect "i secondi con la virgola: il totale" 0 '; 11,0 s.'
  expect_absent "mai con il punto" '.0 s'
  rm -f "${c}/risposte/comando-senza-1.jsonl"
  controlla "${c}"
  expect "uno stream che manca: 1" 1 'manca risposte/comando-senza-1.jsonl'
  copia_buona c
  rm -f "${c}/risposte/parola-inline-1-prima.jsonl"
  controlla "${c}"
  expect "il primo turno che manca: 1" 1 'parola-inline-1-prima.jsonl'
  copia_buona c
  cp "${c}/risposte/codice-con-1.jsonl" "${c}/risposte/codice-con-2.jsonl"
  controlla "${c}"
  expect "una seconda esecuzione a metà: 1" 1 \
    'manca risposte/codice-senza-2.jsonl'
  copia_buona c
  : > "${c}/risposte/codice-con-1.jsonl"
  controlla "${c}"
  expect "uno stream vuoto: 1" 1 'è vuoto'
  copia_buona c
  printf 'non json\n' >> "${c}/risposte/codice-con-1.jsonl"
  controlla "${c}"
  expect "una riga che non è JSON: 1" 1 'non è JSON'
  copia_buona c
  printf '[1]\n' >> "${c}/risposte/codice-con-1.jsonl"
  controlla "${c}"
  expect "una riga che non è un oggetto: 1" 1 'non è un oggetto JSON'
  copia_buona c
  cambia_eventi "${c}/risposte/comando-con-1.jsonl" \
    'e.update(type="altro") if e.get("type") == "result" else None'
  controlla "${c}"
  expect "senza il risultato in fondo: 1" 1 'non finisce con il risultato'
  copia_buona c
  cambia_eventi "${c}/risposte/comando-con-1.jsonl" \
    'e.update(is_error=True) if e.get("type") == "result" else None'
  controlla "${c}"
  expect "un risultato con un errore: 1" 1 'ha restituito un errore'
  # Un conto che manca non è zero: «fermata con zero turni» è una garanzia.
  copia_buona c
  cambia_eventi "${c}/risposte/comando-senza-1.jsonl" \
    'e.pop("num_turns", None) if e.get("type") == "result" else None'
  controlla "${c}"
  expect "un risultato senza num_turns: 1, non zero turni" 1 'num_turns'
  expect_absent "senza num_turns nessun «Ogni garanzia»" "${TUTTE}"
  copia_buona c
  cambia_eventi "${c}/risposte/comando-senza-1.jsonl" \
    'e.update(num_turns=1) if e.get("type") == "result" else None'
  controlla "${c}"
  expect "un turno, al singolare" 1 'ha lavorato lo stesso: 1 turno'
  copia_buona c
  cambia_eventi "${c}/risposte/comando-senza-1.jsonl" \
    'e.update(num_turns=2) if e.get("type") == "result" else None'
  controlla "${c}"
  expect "due turni, al plurale" 1 'ha lavorato lo stesso: 2 turni'
  copia_buona c
  rm -f "${c}/risposte/codice.txt"
  controlla "${c}"
  expect "manca il codice: 1" 1 'manca risposte/codice.txt'
  copia_buona c
  : > "${c}/risposte/parola.txt"
  controlla "${c}"
  expect "una parola vuota: 1" 1 'risposte/parola.txt è vuoto'
  copia_buona c
  cambia_eventi "${c}/risposte/codice-con-1.jsonl" \
    'e.update(skills=[]) if e.get("subtype") == "init" else None'
  controlla "${c}"
  expect "la skill non è nell'elenco: 1" 1 "${NONDIST}"
  expect "e dice perché" 1 "non è nell'elenco"
  copia_buona c
  rm -f "${c}/risposte/codice-con-1.jsonl"
  mkdir "${c}/risposte/codice-con-1.jsonl"
  controlla "${c}"
  expect "uno stream che non si legge: 2" 2 'non si legge'
  expect_absent "mai un traceback" 'Traceback'
  controlla --sconosciuta
  expect "un'opzione sconosciuta: 2" 2 'opzione sconosciuta'
  controlla "${c}" "${c}"
  expect "due spazi di lavoro: 2" 2 'uno spazio di lavoro per volta'
  expect_absent "mai un traceback nell'uso" 'Traceback'
  controlla --sessione "${BUONO}/risposte/permesso-con-1.jsonl"
  expect "--sessione stampa l'id" 0 'finta-'
  controlla --sessione "${TMP}/non-c-e.jsonl"
  expect "--sessione su un file che manca: 1" 1 'manca'
  controlla --sessione
  expect "--sessione senza il file: 2" 2 'vuole un file'
}

# Le risposte di forma diversa ma giuste: il codice in mezzo a una frase, una
# sentinella con il markdown intorno, la parola in maiuscolo: il verdetto resta
# lo stesso. La parola in maiuscolo con il fork ha visto la conversazione: un
# confronto esatto la darebbe per confermata.
t_forme() {
  local c codice parola
  copia_buona c
  codice="$(< "${c}/risposte/codice.txt")"
  parola="$(< "${c}/risposte/parola.txt")"
  cambia_risultato "${c}/risposte/codice-con-1.jsonl" \
    "'Il codice è **${codice}**.'"
  cambia_risultato "${c}/risposte/comando-con-1.jsonl" \
    "'\`${SENTINELLA}: 7 righe\`'"
  cambia_risultato "${c}/risposte/parola-inline-1.jsonl" \
    "e['result'].upper()"
  controlla "${c}"
  expect "il dato in mezzo a una frase, la parola in maiuscolo: confermata" 0 \
    "${TUTTE}"
  copia_buona c
  cambia_risultato "${c}/risposte/parola-fork-1.jsonl" "'${parola}'.upper()"
  controlla "${c}"
  expect "con il fork la parola in maiuscolo: non confermata" 1 \
    "${L_FORK} (parola, 1): ${NONCONF}"
  copia_buona c
  cambia_risultato "${c}/risposte/parola-fork-1.jsonl" "'Non la vedo.'"
  controlla "${c}"
  expect "con il fork una risposta di altra forma, senza la parola: 0" 0 \
    "${TUTTE}"
}

# -------------------------------------------- le precondizioni di in_classe

t_precondizioni() {
  local w
  nuovo_ws w || { fail "lo spazio di lavoro"; return 0; }
  in_classe "${w}" PN_ESECUZIONI=abc
  expect "PN_ESECUZIONI non è un numero: 2" 2 'PN_ESECUZIONI'
  in_classe "${w}" PN_ESECUZIONI=0
  expect "PN_ESECUZIONI 0: 2" 2 'PN_ESECUZIONI'
  in_classe "${w}" PN_ESECUZIONI=10
  expect "PN_ESECUZIONI 10: 2" 2 'PN_ESECUZIONI'
  vero "nessuna chiamata" test ! -s "${TMP}/log.jsonl"
  if env PATH=/usr/bin:/bin bash -c 'command -v claude' > /dev/null; then
    skip "senza claude nel PATH: c'è un claude di sistema"
  else
    run env PATH=/usr/bin:/bin bash "${w}/in_classe.sh"
    expect "senza claude nel PATH: 2" 2 'manca claude'
  fi
  mkdir -p "${w}/risposte"
  in_classe "${w}"
  expect "risposte/ c'è già: 2" 2 'reset_esercizio.sh M5-D03'
  vero "nessuna chiamata con risposte/ già lì" test ! -s "${TMP}/log.jsonl"
  rmdir "${w}/risposte"
  local fuori
  fuori="$(mktemp -d "${TMP}/fuori.XXXXXX")"
  cp -R "${D03}/demo/." "${fuori}/"
  in_classe "${fuori}"
  expect "una cartella che non è lo spazio di lavoro: 2" 2 \
    'tools/prepara_esercizio.sh M5-D03'
  vero "e lì non scrive risposte/" test ! -e "${fuori}/risposte"
  mv "${w}/conta.sh" "${w}/conta.sh.via"
  in_classe "${w}"
  expect "un file del punto di partenza che manca: 2" 2 'conta.sh'
  mv "${w}/conta.sh.via" "${w}/conta.sh"
}

# Una chiamata fallita: uscita 1, ciò che c'è in risposte/, i temporanei via.
t_fallita() {
  local w t
  nuovo_ws w || { fail "lo spazio di lavoro"; return 0; }
  t="$(mktemp -d "${TMP}/temporanei.XXXXXX")"
  in_classe "${w}" FINTO_ESITO_KO_SE=/prova-esegui TMPDIR="${t}"
  expect "una chiamata fallita: 1" 1 'claude -p è fallito'
  vero "gli stream finiti restano in risposte/" \
    test -s "${w}/risposte/comando-senza-1.jsonl"
  if [[ -z "$(ls -A "${t}")" ]]; then
    pass "nessun temporaneo resta"
  else
    fail "resta un temporaneo: $(ls -A "${t}")"
  fi
  run "${D03}/verifica.sh" "${w}"
  expect "verifica.sh dopo una chiamata fallita: 1" 1 'manca'
  nuovo_ws w || { fail "lo spazio di lavoro"; return 0; }
  in_classe "${w}" ANTHROPIC_API_KEY=finta CLAUDE_CODE_EFFORT_LEVEL=high
  expect "con la chiave nell'ambiente gira lo stesso" 0 "${TUTTE}"
  if grep -q '"chiave": true\|"effort_env": true' "${TMP}/log.jsonl"; then
    fail "ANTHROPIC_API_KEY o CLAUDE_CODE_EFFORT_LEVEL arrivano a claude"
  else
    pass "ANTHROPIC_API_KEY e CLAUDE_CODE_EFFORT_LEVEL non arrivano a claude"
  fi
  # TMPDIR dentro ~/.claude: le copie vanno in /tmp (lì Claude Code nega).
  local casa="${TMP}/casa"
  mkdir -p "${casa}/.claude/t"
  nuovo_ws w || { fail "lo spazio di lavoro"; return 0; }
  in_classe "${w}" HOME="${casa}" TMPDIR="${casa}/.claude/t"
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
  run "${D03}/verifica.sh"
  expect "verifica.sh senza argomento: 2" 2 'spazio di lavoro assente'
  run "${D03}/verifica.sh" "${TMP}/non-c-e"
  expect "verifica.sh su una cartella che non c'è: 2" 2 \
    'spazio di lavoro assente'
  nuovo_ws w || { fail "lo spazio di lavoro"; return 0; }
  in_classe "${w}" FINTO_GRANT_RESTA=1
  printf 'import sys\nprint("%s")\nsys.exit(0)\n' "${TUTTE}" \
    > "${w}/controlla_garanzie.py"
  run "${D03}/verifica.sh" "${w}"
  expect "verifica.sh non si fida del controllo dello spazio di lavoro" 1 \
    "${NONCONF}"
  nuovo_ws w || { fail "lo spazio di lavoro"; return 0; }
  in_classe "${w}"
  run env PN_WORKSPACE_ROOT="${w%/*}" "${RADICE}/tools/verifica.sh" M5-D03
  expect "tools/verifica.sh M5-D03" 0 'VERIFICA OK'
}

t_live() {
  local w
  run "${D03}/_docente/live.sh"
  expect "live.sh senza argomenti: 2, e l'uso" 2 'uso: _docente/live.sh'
  run "${D03}/_docente/live.sh" "${TMP}/non-c-e"
  expect "live.sh senza spazio di lavoro: 2" 2 'spazio di lavoro assente'
  nuovo_ws w || { fail "lo spazio di lavoro"; return 0; }
  printf 'x\n' > "${w}/sporco.txt"
  : > "${TMP}/log.jsonl"
  run env FINTO_LOG="${TMP}/log.jsonl" "${D03}/_docente/live.sh" "${w}"
  expect "live.sh su uno spazio di lavoro con del lavoro: 2" 2 \
    'reset_esercizio.sh M5-D03'
  vero "nessuna chiamata al modello" test ! -s "${TMP}/log.jsonl"
  rm -f "${w}/sporco.txt"
  run env HANDSON_ENV=trainer-api FINTO_LOG="${TMP}/log.jsonl" \
    "${D03}/_docente/live.sh" "${w}"
  expect "live.sh con HANDSON_ENV trainer-api: 2" 2 'claude-code-pro'
  run env FINTO_LOG="${TMP}/log.jsonl" FINTO_SPAZIO="${w}" \
    "${D03}/_docente/live.sh" "${w}"
  expect "live.sh: 0 con tre esecuzioni per braccio" 0 \
    "${L_CODICE}: confermata 3 su 3"
  expect "live.sh: il riepilogo del fork" 0 "${L_FORK}: confermata 3 su 3"
  if [[ "$(chiamate)" == 33 ]]; then
    pass "live.sh: trentatré chiamate"
  else
    fail "live.sh: $(chiamate) chiamate, non 33"
  fi
  nuovo_ws w || { fail "lo spazio di lavoro"; return 0; }
  run env FINTO_FORK_VEDE=1 PN_ESECUZIONI=1 FINTO_SPAZIO="${w}" \
    "${D03}/_docente/live.sh" "${w}"
  expect "live.sh su una garanzia che non regge: 1" 1 "${NONCONF}"
  nuovo_ws w || { fail "lo spazio di lavoro"; return 0; }
  run env FINTO_ESITO_KO_SE=/prova-conta FINTO_SPAZIO="${w}" \
    "${D03}/_docente/live.sh" "${w}"
  expect "live.sh con una chiamata fallita: 1" 1 'claude -p è fallito'
}

# La registrazione, quando la sessione del docente l'ha messa in soluzione/.
t_soluzione() {
  local w
  vero "soluzione/LEGGIMI.md parla della registrazione" \
    grep -qi 'registrazione' "${D03}/soluzione/LEGGIMI.md"
  if [[ ! -d "${D03}/soluzione/risposte" ]]; then
    skip "soluzione/risposte: la registrazione non c'è ancora"
    return 0
  fi
  nuovo_ws w || { fail "lo spazio di lavoro"; return 0; }
  cp -R "${D03}/soluzione/." "${w}/"
  run "${D03}/verifica.sh" "${w}"
  expect "verifica.sh con la registrazione: 0" 0 "${FATTO}"
  printf '%s\n' "${OUT}" > "${TMP}/uscita.txt"
  # Il README cita le righe che il controllo stampa sulla registrazione.
  run python3 -B -I "${MOD}/_docente/controlla_registrazione.py" \
    "${D03}/README.md" "${TMP}/uscita.txt" <<'FRASI'
= con ! il codice nella risposta, nessuno strumento; senza !: Bash (cat codice.txt), il codice c'è
= con allowed-tools la sentinella nella risposta, nessuno strumento; senza, fermata con zero turni
= con il campo eseguito; al messaggio dopo negato; senza il campo negato
= senza context: fork la parola torna; con context: fork no, e lo stream mostra il subagent
= NON LA VEDO
= ! porta il dato prima che Claude legga: confermata 3 su 3
= Un comando non consentito ferma l'invocazione: confermata 3 su 3
= allowed-tools vale per un turno: confermata 3 su 3
= Con context: fork il subagent non vede la conversazione: confermata 3 su 3
= Ogni garanzia è confermata in ogni esecuzione.
= Come dato, tutte le 33 chiamate: turni 39; token 685.117; 134,7 s.
= token 35.661 (tutti i modelli 70.696)
= 28.835
= 28.840
= 28.828
R Nella registrazione del corso (3 novembre 2026, Claude Code 2.1.317, Sonnet con effort low, tre esecuzioni per braccio
R sull'account del docente, un piano Max
R Use modelUsage, or model_usage in Python, for whole-tree token accounting; the usage field undercounts as soon as nesting occurs.
! La scrive il docente
FRASI
  expect "il README cita le righe del controllo" 0 "in ordine"
}

t_struttura() {
  run "${RADICE}/tools/check_handson.sh"
  if grep -q 'M5-D03' <<< "${OUT}"; then
    fail "check_handson.sh segnala M5-D03: $(grep 'M5-D03' <<< "${OUT}")"
  else
    pass "check_handson.sh non segnala M5-D03"
  fi
}

t_shellcheck() {
  local f
  for f in "${D03}/verifica.sh" "${D03}/_docente/live.sh" \
      "${D03}/demo/in_classe.sh" "${D03}/demo/lib_coppie.sh" \
      "${D03}/demo/conta.sh" "${SELF}"; do
    if [[ -f "${f}" ]] && shellcheck -x "${f}" > /dev/null 2>&1; then
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
      || { echo "test_m5_d03: manca ${t}" >&2; exit 2; }
  done
  [[ -f "${FINTO_PY}" ]] \
    || { echo "test_m5_d03: manca ${FINTO_PY}" >&2; exit 2; }
  handson::init_temp_base
  TMP="$(mktemp -d "${HANDSON_TEMP_BASE}/test_m5_d03.XXXXXX")" || exit 2
  trap 'chmod -R u+rwX "${TMP}" 2>/dev/null; rm -rf "${TMP}"' EXIT
  prepara_claude
  t_elemento
  t_skill
  t_coppie
  t_conta
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
    echo "test_m5_d03: girati $((PASS + FAIL + SKIP)) casi, attesi" \
      "${CASES}" >&2
    exit 2
  fi
  (( FAIL == 0 )) || exit 1
}

main "$@"
