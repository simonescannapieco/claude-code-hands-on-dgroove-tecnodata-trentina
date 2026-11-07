#!/bin/bash
#
# test_m6_d04.sh -- le prove di M6-D04 «Una modifica a sessione avviata, e
# dopo /compact», per il docente (sta in _docente/, il materiale del docente):
#   - l'elemento: progetto/ con i due segnaposto, la regola con paths, l'hook
#     identico a tools/registra_caricamenti.py e cablato in
#     .claude/settings.json; i tre testi; le frasi di Anthropic nel README,
#     nessun nome interno;
#   - prepara_esercizio.sh e verifica.sh sul punto di partenza (1);
#   - demo/in_classe.sh e demo/sessione.py con il claude finto: tre sessioni
#     per esecuzione, ognuna un solo processo con --input-format stream-json,
#     i messaggi uno alla volta, la modifica da fuori, nessun --resume, le
#     opzioni, nessuna risposta nello spazio di lavoro mentre le sessioni
#     girano, senza ANTHROPIC_API_KEY, la auto memory spenta, la copia tolta
#     alla fine; le parole casuali; le precondizioni (2, nessuna chiamata);
#     una sessione che non risponde, che si ferma o che sbaglia (1);
#   - controlla_sessione.py: ogni garanzia che non regge (1, «non
#     confermata»), ogni sessione che non la mette alla prova (1, «non
#     distinguibile»); il reperto sulla regola con paths dopo /compact, dopo
#     le garanzie, con le parole della pagina e i conteggi, che non decide
#     mai l'uscita, qualunque cosa faccia la regola; i file rovinati (1), le
#     precondizioni (2), mai un traceback;
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
# Uso:    m6_projects_context/_docente/test_m6_d04.sh
# Uscita: 0 = tutti i casi passano · 1 = almeno un caso fallito · 2 =
#         precondizione (manca python3, git o shellcheck; il finto non viene
#         prima nel PATH), o un numero di casi diverso da CASES
set -uo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly MOD="${SELF%/_docente/*}"
readonly RADICE="${MOD%/*}"
readonly D04="${MOD}/s5_projects_context/m6_6_budget_del_contesto/M6-D04_modifica_e_compact"
readonly CONTROLLO="${D04}/demo/controlla_sessione.py"
readonly FINTO_PY="${MOD}/_docente/claude_finto_m6_d02_d04.py"
# La libreria del repository, per la base dei file temporanei.
# shellcheck source=../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"
readonly CASES=183
readonly L_MODIFICA='Una modifica a CLAUDE.md a sessione avviata non si applica'
readonly L_DISCO='Dopo /compact il CLAUDE.md della radice si rilegge dal disco'
readonly L_COMPACT='Il contenuto nuovo si carica al /compact successivo'
readonly L_CLEAR='Il contenuto nuovo si carica al /clear successivo'
readonly L_LETTURA='La regola con paths si carica quando Claude legge un file che corrisponde'
# La regola con paths dopo /compact non è più una garanzia: il controllo ne
# stampa un reperto, che non decide l'uscita, e la vecchia etichetta non c'è.
readonly L_VECCHIA='Dopo /compact la regola con paths torna solo quando serve'
readonly REPERTO='Reperto: la pagina dice «Rules with paths: frontmatter | Claude Code reloads them on demand» e «Path-scoped rules and nested CLAUDE.md files load into message history when Claude reads, writes, or edits their trigger file, so compaction summarizes them away» (https://code.claude.com/docs/en/context-window); in queste esecuzioni, del '
readonly R_NESSUNO='nessun caricamento della regola dopo /compact al Read di un file che corrisponde'
readonly R_PAROLA='la parola della regola nella risposta subito dopo /compact'
readonly NONCONF='non confermata in questa esecuzione'
readonly NONDIST='non distinguibile'
readonly TUTTE='Ogni garanzia è confermata in ogni esecuzione.'
readonly FATTO='Fatto: ogni garanzia è stata messa alla prova'
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
  # Il finto fa girare l'hook prima di rispondere: il registro è già fermo.
  export PN_SESSIONE_CALMA=0.05 PN_SESSIONE_PAUSA=0
  unset ANTHROPIC_API_KEY CLAUDE_CODE_EFFORT_LEVEL HANDSON_ENV PN_HANDSON_ROOT
  [[ "$(command -v claude)" == "${TMP}/finto/claude" ]] \
    || { echo "test_m6_d04: il finto non viene prima nel PATH" >&2; exit 2; }
}

# Uno spazio di lavoro nuovo, con prepara_esercizio.sh in una radice nuova.
# Arguments: $1 la variabile da assegnare. Returns: 0; 1 se non riesce.
nuovo_ws() {
  local __r
  __r="$(mktemp -d "${TMP}/radice.XXXXXX")" || exit 2
  "${RADICE}/tools/prepara_esercizio.sh" M6-D04 --radice "${__r}" \
    > "${TMP}/prepara.log" 2>&1 || return 1
  printf -v "$1" '%s' "${__r}/M6-D04"
}

# in_classe.sh dell'elemento sullo spazio di lavoro $1, con le variabili che
# seguono (NOME=valore); RC e OUT come run. Una riga per processo e una per
# messaggio in $TMP/log.jsonl.
in_classe() {
  local w="$1"
  shift
  : > "${TMP}/log.jsonl"
  run env FINTO_LOG="${TMP}/log.jsonl" FINTO_SPAZIO="${w}" TMPDIR="${TMP}/t" \
    "$@" "${D04}/demo/in_classe.sh" "${w}"
}

# controlla_sessione.py dell'elemento; RC e OUT come run.
controlla() { run python3 -B -I "${CONTROLLO}" "$@"; }

# Una copia di risposte/ dello spazio di lavoro buono, da rovinare.
# Arguments: $1 la variabile da assegnare.
copia_buona() {
  local __c
  __c="$(mktemp -d "${TMP}/copia.XXXXXX")" || exit 2
  cp -R "${BUONO}/risposte" "${__c}/" || exit 2
  printf -v "$1" '%s' "${__c}"
}

# I processi di claude finto in $TMP/log.jsonl.
processi() { grep -c '"argv"' "${TMP}/log.jsonl"; }

# ---------------------------------------------------------------- l'elemento

t_elemento() {
  local f p="${D04}/demo/progetto"
  for f in README.md verifica.sh demo/in_classe.sh demo/sessione.py \
      demo/controlla_sessione.py demo/domanda.txt demo/leggi.txt \
      demo/elenca.txt _docente/live.sh soluzione/LEGGIMI.md; do
    vero "c'è ${f}" test -f "${D04}/${f}"
  done
  vero "verifica.sh è eseguibile" test -x "${D04}/verifica.sh"
  vero "live.sh è eseguibile" test -x "${D04}/_docente/live.sh"
  vero "in_classe.sh è eseguibile" test -x "${D04}/demo/in_classe.sh"
  vero "il segnaposto della radice in CLAUDE.md" grep -qF '__RADICE__' \
    "${p}/CLAUDE.md"
  vero "il segnaposto della regola in php.md" grep -qF '__REGOLAPHP__' \
    "${p}/.claude/rules/php.md"
  vero "la regola con paths **/*.php" grep -qxF '  - "**/*.php"' \
    "${p}/.claude/rules/php.md"
  vero "l'hook è identico a tools/registra_caricamenti.py" cmp -s \
    "${RADICE}/tools/registra_caricamenti.py" \
    "${p}/.claude/hooks/registra_caricamenti.py"
  run python3 -B -I - "${p}/.claude/settings.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
comandi = [h["command"] for g in d["hooks"]["InstructionsLoaded"] for h in g["hooks"]]
assert comandi == ['python3 "$CLAUDE_PROJECT_DIR/.claude/hooks/registra_caricamenti.py"'], comandi
print("ok, settings")
PY
  expect "settings.json: l'hook InstructionsLoaded" 0 'ok, settings'
  if [[ -z "$(command find "${D04}/demo" -name '*.sessione.json')" ]] \
      && ! grep -rqE '\b[A-Z]+-[A-Z]{6}\b' "${p}"; then
    pass "nessuna parola nel repository, solo i segnaposto"
  else
    fail "nessuna parola nel repository, solo i segnaposto"
  fi
}

t_readme() {
  local testo frase parola
  testo="$(LC_ALL=C tr -s '[:space:]' ' ' < "${D04}/README.md")"
  while IFS= read -r frase; do
    if [[ "${testo}" == *"${frase}"* ]]; then
      pass "README: «${frase:0:48}…»"
    else
      fail "README: manca «${frase}»"
    fi
  done <<'FRASI'
Your project-root and user-level CLAUDE.md files are read once at session start and held in memory.
but the edit also doesn't apply. Claude keeps working with the version that was loaded at session start.
The new content loads on the next /clear, /compact, or restart.
Project-root CLAUDE.md survives compaction: after /compact, Claude re-reads it from disk and re-injects it into the session.
Rules with paths: frontmatter | Claude Code reloads them on demand
Path-scoped rules and nested CLAUDE.md files load into message history when Claude reads, writes, or edits their trigger file, so compaction summarizes them away
The "compact" value fires when instruction files are re-loaded after a compaction event
https://code.claude.com/docs/en/prompt-caching
https://code.claude.com/docs/en/context-window
https://code.claude.com/docs/en/hooks
tools/prepara_esercizio.sh M6-D04
tools/verifica.sh M6-D04
--input-format stream-json
La prova del corso del 7 novembre 2026, con Claude Code 2.1.319, in una sessione sola
o una sessione ripresa con `--resume`, dove ogni messaggio è un processo nuovo, può comportarsi diversamente
il docente rifà la prova prima di ogni edizione del corso
Il reperto sulla regola dopo `/compact` si stampa e non decide l'uscita.
FRASI
  for parola in 'FACT-' 'M6-X' 'X-37' 'X-38' 'smentit' 'probe' 'oggi' \
      ' D04' '(D04' 'triage' "${L_VECCHIA}" 'la verifica esce con 1'; do
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
  vero "lo spazio di lavoro ha progetto/ e sessione.py" \
    test -f "${w}/progetto/CLAUDE.md" -a -f "${w}/sessione.py"
  vero "niente _docente né soluzione" \
    test ! -e "${w}/_docente" -a ! -e "${w}/soluzione"
  run "${D04}/verifica.sh" "${w}"
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
  expect "il comando di sessione.py si vede" 0 'python3 -B -I sessione.py'
  expect "e quello di claude" 0 'claude -p --input-format stream-json'
  expect "la modifica da fuori si vede" 0 'CLAUDE.md riscritto da fuori'
  expect "la modifica: compact" 0 "${L_MODIFICA} (compact, 1): confermata"
  expect "il disco: regola" 0 "${L_DISCO} (regola, 1): confermata"
  expect "il /clear" 0 "${L_CLEAR} (clear, 1): confermata"
  expect "la regola al Read" 0 "${L_LETTURA} (regola, 1): confermata"
  expect_absent "la regola dopo /compact non è più una garanzia" \
    "${L_VECCHIA}"
  expect "il reperto, con le parole della pagina e il suo indirizzo" 0 \
    "${REPERTO}"
  expect "il reperto: la versione delle esecuzioni, una sessione sola" 0 \
    'con Claude Code 2.1.999 (finto), in una sessione sola:'
  expect "il reperto: il finto ricarica la regola, 0 su 1" 0 \
    "${R_NESSUNO}, 0 su 1"
  expect "il reperto: la parola riassunta via, 0 su 1" 0 "${R_PAROLA}, 0 su 1"
  expect "i caricamenti della regola dopo /compact, come dato" 0 \
    'Come dato, i caricamenti della regola dopo /compact: path_glob_match'
  expect "il riassunto nei dati" 0 'nel riassunto: prima'
  expect "la parola della regola dopo /compact, come dato" 0 \
    'Come dato, la parola della regola nella risposta dopo /compact'
  run python3 -B -I - "${OUT}" <<'PY'
import sys
testo = sys.argv[1]
ultima = testo.rindex("La regola con paths si carica quando Claude legge un file che corrisponde: confermata")
reperto = testo.index("Reperto: la pagina dice")
assert ultima < reperto < testo.index("Ogni garanzia è confermata"), "ordine"
print("ok, il reperto dopo le garanzie")
PY
  expect "il reperto dopo i riepiloghi delle garanzie" 0 \
    'ok, il reperto dopo le garanzie'
  if [[ "$(processi)" == 3 ]]; then
    pass "un'esecuzione: tre processi"
  else
    fail "un'esecuzione: $(processi) processi, non 3"
  fi
  run python3 -B -I - "${TMP}/log.jsonl" "${BUONO}" "${D04}/demo" <<'PY'
import json, os, sys
righe = [json.loads(r) for r in open(sys.argv[1], encoding="utf-8")]
ws, demo = sys.argv[2], sys.argv[3]
def testo(nome):
    return open(os.path.join(demo, nome), encoding="utf-8").read().strip()
avvii = [r for r in righe if "argv" in r]
def op(riga, nome):
    a = riga["argv"]
    return a[a.index(nome) + 1] if nome in a else None
comuni = {"--input-format": "stream-json", "--output-format": "stream-json",
          "--model": "sonnet", "--effort": "low", "--permission-mode": "dontAsk",
          "--permission-prompts": "none", "--setting-sources": "project,local"}
for riga, (nome, strumenti) in zip(avvii, (("compact-1", ""), ("clear-1", ""), ("regola-1", "Read"))):
    assert riga["prompt"] is None and "--" not in riga["argv"], nome
    assert "--resume" not in riga["argv"] and "--continue" not in riga["argv"], nome
    for chiave, valore in comuni.items():
        assert op(riga, chiave) == valore, (nome, chiave)
    for flag in ("--verbose", "--strict-mcp-config", "--no-session-persistence"):
        assert flag in riga["argv"], (nome, flag)
    assert op(riga, "--tools") == strumenti, (nome, op(riga, "--tools"))
    assert op(riga, "--allowedTools") == (strumenti or None), nome
    assert not riga["chiave"] and not riga["effort_env"], nome
    assert riga["auto_memoria_spenta"] and riga["git"], nome
    assert not riga["risposte"], (nome, "risposte/ durante le sessioni")
    assert not riga["cwd"].startswith(ws), nome
    assert os.path.basename(riga["cwd"]).startswith(nome + "."), riga["cwd"]
    assert "src/a.php" in riga["file"] and ".claude/caricamenti.jsonl" in riga["file"]
messaggi = {}
for riga in righe:
    if "messaggio" in riga:
        messaggi.setdefault(riga["cwd"], []).append(riga["messaggio"])
domanda, leggi, elenca = testo("domanda.txt"), testo("leggi.txt"), testo("elenca.txt")
attesi = [[domanda, domanda, "/compact", domanda], [domanda, domanda, "/clear", domanda],
          [leggi, "/compact", elenca, leggi, elenca]]
assert [messaggi[r["cwd"]] for r in avvii] == attesi, messaggi
print("ok, i processi e i messaggi")
PY
  expect "un processo per sessione, i messaggi uno alla volta, mai --resume" 0 \
    'ok, i processi e i messaggi'
  run python3 -B -I - "${BUONO}/risposte" <<'PY'
import json, re, sys
d = sys.argv[1]
for nome in ("compact-1", "clear-1", "regola-1"):
    s = json.load(open("%s/%s.sessione.json" % (d, nome), encoding="utf-8"))
    assert all(re.match(r"^[A-Z]+-[A-Z]{6}$", v) for v in s["parole"].values()), s
    assert [p["passo"] for p in s["passi"]] == [1, 2, 3, 4, 5], s["passi"]
    segni = [p["caricamenti"] for p in s["passi"]]
    assert segni == sorted(segni), segni
c = json.load(open(d + "/compact-1.sessione.json", encoding="utf-8"))
assert c["parole"]["radice"].startswith("PRIMA-") and c["parole"]["nuova"].startswith("DOPO-")
print("ok, i passi")
PY
  expect "sessione.json: le parole e i segni del registro" 0 'ok, i passi'
  if [[ -z "$(ls -A "${TMP}/t")" ]]; then
    pass "nessuna copia e nessun temporaneo restano"
  else
    fail "resta un temporaneo: $(ls -A "${TMP}/t")"
  fi
  run "${D04}/verifica.sh" "${BUONO}"
  expect "verifica.sh dopo in_classe.sh: 0" 0 "${FATTO}"
}

t_casuali() {
  local w
  nuovo_ws w || { fail "un altro spazio di lavoro"; return 0; }
  in_classe "${w}"
  if cmp -s "${w}/risposte/compact-1.sessione.json" \
      "${BUONO}/risposte/compact-1.sessione.json"; then
    fail "le parole cambiano da uno spazio di lavoro all'altro"
  else
    pass "le parole cambiano da uno spazio di lavoro all'altro"
  fi
}

# ------------------------------------------- le garanzie che non reggono

# Arguments: $1 il nome, $2 la variabile (NOME=valore o NOME, che vale 1),
# $3 la parola.
guasto() {
  local w variabile="$2"
  [[ "${variabile}" == *=* ]] || variabile+="=1"
  nuovo_ws w || { fail "$1: lo spazio di lavoro"; return 0; }
  in_classe "${w}" "${variabile}"
  expect "$1" 1 "$3"
  expect_absent "$1: nessun «Ogni garanzia»" "${TUTTE}"
}

t_guasti() {
  local w
  guasto "la modifica vale subito: compact" FINTO_MODIFICA_APPLICATA \
    "${L_MODIFICA} (compact, 1): ${NONCONF}"
  guasto "la modifica vale subito: clear" FINTO_MODIFICA_APPLICATA \
    "${L_MODIFICA} (clear, 1): ${NONCONF}"
  guasto "dopo /compact niente si ricarica" FINTO_COMPACT_SENZA_RICARICA \
    "${L_DISCO} (compact, 1): ${NONCONF}"
  guasto "dopo /compact il contenuto di prima" FINTO_COMPACT_VECCHIO \
    "${L_COMPACT} (compact, 1): ${NONCONF}"
  guasto "/compact non compatta" FINTO_NON_COMPATTA \
    "${L_DISCO} (compact, 1): ${NONDIST}"
  guasto "dopo /clear il contenuto di prima" FINTO_CLEAR_VECCHIO \
    "${L_CLEAR} (clear, 1): ${NONCONF}"
  guasto "/clear senza conversazione nuova" FINTO_CLEAR_SENZA_RESET \
    "${L_CLEAR} (clear, 1): ${NONDIST}"
  guasto "il Read non carica la regola" FINTO_REGOLA_NON_CARICA \
    "${L_LETTURA} (regola, 1): ${NONCONF}"
  guasto "Claude non legge" FINTO_NON_LEGGE \
    "${L_LETTURA} (regola, 1): ${NONDIST}"
  guasto "la prima risposta senza la parola" FINTO_PRIMA_SENZA_PAROLA \
    "${L_MODIFICA} (compact, 1): ${NONDIST}"
  guasto "senza l'hook" FINTO_SENZA_HOOK "${L_DISCO} (compact, 1): ${NONCONF}"
  nuovo_ws w || { fail "lo spazio di lavoro"; return 0; }
  in_classe "${w}" FINTO_COMPACT_VECCHIO=1
  run "${D04}/verifica.sh" "${w}"
  expect "verifica.sh su una garanzia che non regge: 1" 1 "${NONCONF}"
  expect_absent "verifica.sh: nessun «Fatto»" "${FATTO}"
  expect "chi legge sa che è da segnalare" 1 'da segnalare'
}

# La regola con paths dopo /compact è un reperto: qualunque cosa faccia, il
# controllo esce con 0 se le cinque garanzie reggono, e i numeri cambiano.
# Arguments: $1 il nome, $2 la variabile del finto, $3 e $4 i due conteggi
# attesi («k su N»).
reperto() {
  local w
  nuovo_ws w || { fail "$1: lo spazio di lavoro"; return 0; }
  in_classe "${w}" "$2=1"
  expect "$1: uscita 0, le garanzie reggono" 0 "${TUTTE}"
  expect "$1: nessun caricamento, $3" 0 "${R_NESSUNO}, $3"
  expect "$1: la parola, $4" 0 "${R_PAROLA}, $4"
  expect_absent "$1: mai un esito sulla regola dopo /compact" "${L_VECCHIA}"
}

t_reperto() {
  local w
  # Ciò che ha visto la prova del corso: la regola resta, nessun evento.
  reperto "la regola resta e non si ricarica" FINTO_REGOLA_RESTA_MUTA \
    '1 su 1' '1 su 1'
  expect "e i dati lo dicono" 0 \
    'Come dato, i caricamenti della regola dopo /compact: nessuno.'
  reperto "la regola torna con la compaction" FINTO_REGOLA_RESTA \
    '0 su 1' '1 su 1'
  expect "e i dati dicono il motivo" 0 \
    'Come dato, i caricamenti della regola dopo /compact: compact .claude/rules/php.md'
  reperto "la regola non torna più" FINTO_REGOLA_NON_TORNA '1 su 1' '0 su 1'
  # Senza il Read del passo 4 la sessione non entra nel primo conteggio.
  nuovo_ws w || { fail "lo spazio di lavoro"; return 0; }
  in_classe "${w}" FINTO_NON_LEGGE=1
  expect "senza Read: il primo conteggio è su 0" 1 "${R_NESSUNO}, 0 su 0"
}

# ------------------------------------------- sessione.py che non va a buon fine

t_sessione() {
  local w
  nuovo_ws w || { fail "lo spazio di lavoro"; return 0; }
  in_classe "${w}" FINTO_MUTO=1 PN_SESSIONE_ATTESA=2
  expect "claude che non risponde: 1" 1 'nessun risultato in 2 secondi'
  expect "e la demo si ferma alla prima sessione" 1 'compact-1: la sessione è fallita'
  vero "ciò che c'è va in risposte/" test -f "${w}/risposte/compact-1.sessione.json"
  if [[ -z "$(ls -A "${TMP}/t")" ]]; then
    pass "nessuna copia resta dopo una sessione fallita"
  else
    fail "resta un temporaneo: $(ls -A "${TMP}/t")"
  fi
  run "${D04}/verifica.sh" "${w}"
  expect "verifica.sh dopo una sessione fallita: 1" 1 'compact-1.jsonl è vuoto'
  nuovo_ws w || { fail "lo spazio di lavoro"; return 0; }
  in_classe "${w}" FINTO_TRONCO_AL=3
  expect "claude che si ferma a metà: 1" 1 'si è fermato prima del risultato'
  nuovo_ws w || { fail "lo spazio di lavoro"; return 0; }
  in_classe "${w}" FINTO_ERRORE_AL=2
  expect "un risultato con un errore: 1" 1 'ha restituito un errore al passo 3'
  nuovo_ws w || { fail "lo spazio di lavoro"; return 0; }
  in_classe "${w}" PN_SESSIONE_ATTESA=0
  expect "PN_SESSIONE_ATTESA non valida: 2" 2 'PN_SESSIONE_ATTESA'
  nuovo_ws w || { fail "lo spazio di lavoro"; return 0; }
  in_classe "${w}" PN_SESSIONE_CALMA=abc
  expect "PN_SESSIONE_CALMA non valida: 2" 2 'PN_SESSIONE_CALMA'
  vero "e nessun processo di claude" test "$(processi)" == 0
  run python3 -B -I "${D04}/demo/sessione.py" --tipo boh --nome boh-1 \
    --progetto "${TMP}" --copie "${TMP}" --deposito "${TMP}"
  expect "sessione.py con un tipo sconosciuto: 2" 2 'compact, clear o regola'
  run python3 -B -I "${D04}/demo/sessione.py" --tipo compact
  expect "sessione.py senza le cartelle: 2" 2 'manca --nome'
  run python3 -B -I "${D04}/demo/sessione.py" --tipo compact --nome compact-1 \
    --progetto "${TMP}/non-c-e" --copie "${TMP}" --deposito "${TMP}"
  expect "sessione.py con una cartella che non c'è: 2" 2 'non è una cartella'
  expect_absent "mai un traceback" 'Traceback'
}

# ------------------------------------------------------ i file rovinati

# Un file JSON cambiato con Python. Arguments: $1 il file, $2 il codice: riceve
# `d`, il dato, e lo cambia.
cambia_json() {
  python3 -B -I - "$1" "$2" <<'PY' || exit 2
import json, sys
percorso, codice = sys.argv[1:3]
d = json.load(open(percorso, encoding="utf-8"))
exec(codice)
json.dump(d, open(percorso, "w", encoding="utf-8"))
PY
}

t_rovinati() {
  local c f
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
  for f in clear-1.jsonl regola-1.caricamenti.jsonl compact-1.sessione.json; do
    copia_buona c
    rm -f "${c}/risposte/${f}"
    controlla "${c}"
    expect "manca ${f}: 1" 1 "manca risposte/${f}"
  done
  copia_buona c
  cp "${c}/risposte/compact-1.jsonl" "${c}/risposte/compact-2.jsonl"
  controlla "${c}"
  expect "una seconda esecuzione a metà: 1" 1 'manca risposte/clear-2.jsonl'
  copia_buona c
  : > "${c}/risposte/compact-1.jsonl"
  controlla "${c}"
  expect "uno stream vuoto: 1" 1 'è vuoto'
  copia_buona c
  printf 'non json\n' >> "${c}/risposte/regola-1.jsonl"
  controlla "${c}"
  expect "una riga che non è JSON: 1" 1 'non è JSON'
  copia_buona c
  python3 -B -I - "${c}/risposte/clear-1.jsonl" <<'PY' || exit 2
import json, sys
righe = open(sys.argv[1], encoding="utf-8").read().splitlines()
ultimo = max(i for i, r in enumerate(righe) if json.loads(r).get("type") == "result")
open(sys.argv[1], "w", encoding="utf-8").write("\n".join(righe[:ultimo]) + "\n")
PY
  controlla "${c}"
  expect "un risultato in meno dei messaggi: 1" 1 '3 risultati per 4 messaggi'
  copia_buona c
  cambia_json "${c}/risposte/compact-1.sessione.json" 'd["passi"].pop()'
  controlla "${c}"
  expect "i passi a metà: 1" 1 'non ha i passi di una sessione compact'
  copia_buona c
  cambia_json "${c}/risposte/regola-1.sessione.json" \
    'd["passi"][4]["caricamenti"] = 99'
  controlla "${c}"
  expect "i segni oltre le righe del registro: 1" 1 'i segni del registro'
  copia_buona c
  cambia_json "${c}/risposte/clear-1.sessione.json" \
    'd["parole"]["nuova"] = "dopo-abc"'
  controlla "${c}"
  expect "una parola che non va: 1" 1 'non è nella forma'
  copia_buona c
  printf '{"load_reason": "boh", "file_path": "CLAUDE.md"}\n' \
    >> "${c}/risposte/compact-1.caricamenti.jsonl"
  controlla "${c}"
  expect "un motivo di caricamento sconosciuto: 1" 1 'load_reason sconosciuto'
  copia_buona c
  rm -f "${c}/risposte/compact-1.jsonl"
  mkdir "${c}/risposte/compact-1.jsonl"
  controlla "${c}"
  expect "uno stream che non si legge: 2" 2 'non si legge'
  expect_absent "mai un traceback" 'Traceback'
  controlla --sconosciuta
  expect "un'opzione sconosciuta: 2" 2 'opzione sconosciuta'
  copia_buona c
  run env PN_HANDSON_ROOT="${TMP}/non-c-e" python3 -B -I "${CONTROLLO}" "${c}"
  expect "tools/ che non si trova: 2" 2 'tools/lib_leggi_contesto.py'
}

# -------------------------------------------- le precondizioni di in_classe

t_precondizioni() {
  local w fuori
  nuovo_ws w || { fail "lo spazio di lavoro"; return 0; }
  in_classe "${w}" PN_ESECUZIONI=abc
  expect "PN_ESECUZIONI non è un numero: 2" 2 'PN_ESECUZIONI'
  in_classe "${w}" PN_ESECUZIONI=10
  expect "PN_ESECUZIONI 10: 2" 2 'PN_ESECUZIONI'
  in_classe "${w}" HANDSON_ENV=trainer-api
  expect "HANDSON_ENV trainer-api: 2" 2 'claude-code-pro'
  vero "nessuna chiamata" test ! -s "${TMP}/log.jsonl"
  if env PATH=/usr/bin:/bin bash -c 'command -v claude' > /dev/null; then
    skip "senza claude nel PATH: c'è un claude di sistema"
  else
    run env PATH=/usr/bin:/bin bash "${D04}/demo/in_classe.sh" "${w}"
    expect "senza claude nel PATH: 2" 2 'manca lo strumento: claude'
  fi
  mkdir -p "${w}/risposte"
  in_classe "${w}"
  expect "risposte/ c'è già: 2" 2 'reset_esercizio.sh M6-D04'
  rmdir "${w}/risposte"
  printf 'x\n' > "${w}/sporco.txt"
  in_classe "${w}"
  expect "lo spazio di lavoro con del lavoro: 2" 2 'non è al punto di partenza'
  rm -f "${w}/sporco.txt"
  fuori="$(mktemp -d "${TMP}/fuori.XXXXXX")"
  cp -R "${D04}/demo/." "${fuori}/"
  in_classe "${fuori}"
  expect "una cartella che non è lo spazio di lavoro: 2" 2 \
    'tools/prepara_esercizio.sh M6-D04'
  git -C "${w}" rm -q elenca.txt
  git -C "${w}" -c user.name=t -c user.email=t@example.org commit -q -m via
  in_classe "${w}"
  expect "un file del punto di partenza che manca: 2" 2 'elenca.txt'
  nuovo_ws w || { fail "lo spazio di lavoro"; return 0; }
  printf -- '- __NUOVA__\n' >> "${w}/progetto/CLAUDE.md"
  git -C "${w}" -c user.name=t -c user.email=t@example.org commit -q -am nuova
  in_classe "${w}"
  expect "un segnaposto senza parola: 2" 2 'un segnaposto senza parola'
  vero "nessuna sessione con le precondizioni che non reggono" \
    test ! -s "${TMP}/log.jsonl"
}

# ---------------------------------------------------- verifica.sh e live.sh

t_verifica() {
  local w
  run "${D04}/verifica.sh"
  expect "verifica.sh senza argomento: 2" 2 'spazio di lavoro assente'
  nuovo_ws w || { fail "lo spazio di lavoro"; return 0; }
  in_classe "${w}" FINTO_MODIFICA_APPLICATA=1
  printf 'import sys\nprint("%s")\nsys.exit(0)\n' "${TUTTE}" \
    > "${w}/controlla_sessione.py"
  run "${D04}/verifica.sh" "${w}"
  expect "verifica.sh non si fida del controllo dello spazio di lavoro" 1 \
    "${NONCONF}"
  run env PN_WORKSPACE_ROOT="${BUONO%/*}" "${RADICE}/tools/verifica.sh" M6-D04
  expect "tools/verifica.sh M6-D04" 0 'VERIFICA OK'
}

t_live() {
  local w
  run "${D04}/_docente/live.sh"
  expect "live.sh senza argomenti: 2, e l'uso" 2 'uso: _docente/live.sh'
  nuovo_ws w || { fail "lo spazio di lavoro"; return 0; }
  printf 'x\n' > "${w}/sporco.txt"
  : > "${TMP}/log.jsonl"
  run env FINTO_LOG="${TMP}/log.jsonl" "${D04}/_docente/live.sh" "${w}"
  expect "live.sh su uno spazio di lavoro con del lavoro: 2" 2 \
    'reset_esercizio.sh M6-D04'
  vero "nessuna sessione" test ! -s "${TMP}/log.jsonl"
  rm -f "${w}/sporco.txt"
  run env FINTO_LOG="${TMP}/log.jsonl" FINTO_SPAZIO="${w}" TMPDIR="${TMP}/t" \
    "${D04}/_docente/live.sh" "${w}"
  expect "live.sh: 0 con tre esecuzioni" 0 "${L_LETTURA}: confermata 3 su 3"
  expect "live.sh: il riepilogo della modifica" 0 "${L_MODIFICA}: confermata 6 su 6"
  expect "live.sh: il reperto sulle tre sessioni della regola" 0 \
    "${R_NESSUNO}, 0 su 3, e ${R_PAROLA}, 0 su 3."
  expect "live.sh: verifica.sh dopo" 0 "VERIFICA OK   verifica.sh dell'elemento"
  if [[ "$(processi)" == 9 ]]; then
    pass "live.sh: nove sessioni"
  else
    fail "live.sh: $(processi) sessioni, non 9"
  fi
  nuovo_ws w || { fail "lo spazio di lavoro"; return 0; }
  run env FINTO_COMPACT_VECCHIO=1 PN_ESECUZIONI=1 TMPDIR="${TMP}/t" \
    "${D04}/_docente/live.sh" "${w}"
  expect "live.sh su una garanzia che non regge: 1" 1 "${NONCONF}"
}

t_soluzione() {
  local w
  vero "soluzione/LEGGIMI.md parla della registrazione" \
    grep -qi 'registrazione' "${D04}/soluzione/LEGGIMI.md"
  if [[ ! -d "${D04}/soluzione/risposte" ]]; then
    skip "soluzione/risposte: la registrazione non c'è ancora"
    return 0
  fi
  nuovo_ws w || { fail "lo spazio di lavoro"; return 0; }
  cp -R "${D04}/soluzione/." "${w}/"
  run "${D04}/verifica.sh" "${w}"
  expect "verifica.sh con la registrazione: 0" 0 "${FATTO}"
}

t_struttura() {
  run "${RADICE}/tools/check_handson.sh"
  if grep -q 'M6-D04' <<< "${OUT}"; then
    fail "check_handson.sh segnala M6-D04: $(grep 'M6-D04' <<< "${OUT}")"
  else
    pass "check_handson.sh non segnala M6-D04"
  fi
}

t_shellcheck() {
  local f
  for f in "${D04}/verifica.sh" "${D04}/_docente/live.sh" \
      "${D04}/demo/in_classe.sh" "${SELF}"; do
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
      || { echo "test_m6_d04: manca ${t}" >&2; exit 2; }
  done
  [[ -f "${FINTO_PY}" ]] \
    || { echo "test_m6_d04: manca ${FINTO_PY}" >&2; exit 2; }
  handson::init_temp_base
  TMP="$(mktemp -d "${HANDSON_TEMP_BASE}/test_m6_d04.XXXXXX")" || exit 2
  trap 'chmod -R u+rwX "${TMP}" 2>/dev/null; rm -rf "${TMP}"' EXIT
  prepara_claude
  t_elemento
  t_readme
  t_prepara
  t_buono
  t_casuali
  t_guasti
  t_reperto
  t_sessione
  t_rovinati
  t_precondizioni
  t_verifica
  t_live
  t_soluzione
  t_struttura
  t_shellcheck
  OUT="${TUTTO}"
  expect_absent "in nessuna uscita «smentita»" "smentita"
  echo "PASS=${PASS} FAIL=${FAIL} SKIP=${SKIP}"
  if (( PASS + FAIL + SKIP != CASES )); then
    echo "test_m6_d04: girati $((PASS + FAIL + SKIP)) casi, attesi" \
      "${CASES}" >&2
    exit 2
  fi
  (( FAIL == 0 )) || exit 1
}

main "$@"
