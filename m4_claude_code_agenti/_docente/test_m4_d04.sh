#!/bin/bash
#
# test_m4_d04.sh -- le prove di M4-D04 «Tre gradini, tre garanzie», per il
# docente (sta in _docente/, il materiale del docente):
#   - l'elemento: progetti.txt; le tre richieste; le impostazioni dei due
#     gradini (la regola deny, l'hook) uguali alle impostazioni prudenti
#     del repository più una cosa sola; la soluzione della prova dei
#     partecipanti uguale alla regola deny e al JSON del README; le dieci
#     sezioni del README, le frasi di Anthropic con il loro indirizzo e le
#     richieste; nessun nome interno della pianificazione, nessun percorso
#     personale, nessun file dei difetti inseriti del gestionale (la
#     sezione 1 di difetti-noti.md);
#   - blocca_rm.py, lo script dell'hook: esce con 2 e il motivo su STDERR
#     per un rm in posizione di comando, con 0 e in silenzio altrimenti,
#     con 2 su un ingresso che non legge;
#   - prepara_esercizio.sh e verifica.sh, la prova dei partecipanti: il
#     punto di partenza (1), la soluzione (0), la regola scritta con «./»
#     (0), la regola altrove, un JSON rotto, il file che manca, i dati
#     cambiati (1), anche dopo un commit, e il comando che la verifica
#     consiglia li riporta al punto di partenza (0); le precondizioni
#     (2); run_all.sh M4-D04;
#   - _docente/live.sh con il claude finto (claude_finto_m4_d04_d06.py):
#     le sei chiamate delle tre coppie e la prova dei partecipanti, ognuna
#     dalla sua cartella, con la sua modalità, i suoi strumenti e la sua
#     richiesta, senza ANTHROPIC_API_KEY; le copie del gestionale, ognuna
#     un repository git con le sue impostazioni; il piano del plan mode
#     tolto da $HOME/.claude/plans/, e soltanto lui; le precondizioni (2,
#     nessuna chiamata a claude: l'esca); gli esiti diversi (1);
#   - controlla_gradini.py sugli spazi di lavoro che live.sh lascia: le
#     garanzie confermate e ogni modo in cui non lo sono (1), anche un
#     tentativo fallito per un altro motivo, che non è un diniego (1); i
#     dinieghi, dati e mai un verdetto: una chiamata negata fuori
#     dall'elenco permission_denials, o con il messaggio
#     permission_denied, si stampa e non cambia l'uscita (0); gli stream
#     e le copie rovinati (1); le precondizioni (2), mai un traceback;
#   - shellcheck -x su verifica.sh, live.sh, lib_gradini.sh (la sua
#     libreria, che non è eseguibile) e questo file; in nessuna uscita
#     «smentita».
# Mai il claude vero: il finto e l'esca stanno davanti nel PATH, e la
# suite lo controlla prima di usarli. Gli stream del finto non sono
# risposte di Claude: provano il controllo, non il modello. Gli spazi di
# lavoro nascono in una cartella temporanea, nella base di
# handson::init_temp_base (mai dentro ~/.claude), con una HOME finta per
# il piano del plan mode: l'albero del repository e la HOME vera non
# cambiano. CASES è il numero dei casi: se ne girano di più o di meno la
# suite esce 2.
#
# Uso:    m4_claude_code_agenti/_docente/test_m4_d04.sh
# Uscita: 0 = tutti i casi passano · 1 = almeno un caso fallito · 2 =
#         precondizione (manca python3, git o shellcheck), o un numero di
#         casi diverso da CASES
set -uo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly MOD="${SELF%/_docente/*}"
readonly RADICE="${MOD%/*}"
D04="${MOD}/s3_agente_nel_repository/m4_6_permessi_fiducia"
D04+="/M4-D04_tre_garanzie"
readonly D04
readonly FINTO_PY="${MOD}/_docente/claude_finto_m4_d04_d06.py"
readonly DIFETTI="${RADICE}/progetti/gestionale-php/_docente/difetti-noti.md"
# La libreria del repository, per la base dei file temporanei
# (handson::init_temp_base): mai dentro ~/.claude, dove
# prepara_esercizio.sh rifiuta gli spazi di lavoro.
# shellcheck source=../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"
readonly CASES=246
readonly REGOLA='Edit(/progetti/gestionale-php/database/dati/**)'
readonly SENZA_BARRA='senza la barra iniziale'
readonly DATI='progetti/gestionale-php/database/dati'
readonly FILE_DATI="${DATI}/01_comuni.sql"
readonly FILE_PIANO='progetti/gestionale-php/src/Ticket/PrioritaTicket.php'
P_PIANO="Aggiungi in testa a ${FILE_PIANO} un commento di una riga che"
P_PIANO+=" spieghi a che cosa serve l'enum. Non fare altro."
readonly P_PIANO
P_DENY="In ${FILE_DATI} aggiungi in fondo la riga «-- elenco controllato a"
P_DENY+=" mano». Il file è generato, ma la modifica è voluta. Non fare"
P_DENY+=" altro."
readonly P_DENY
P_HOOK="Esegui esattamente questo comando e nient'altro:"
P_HOOK+=" rm da_cancellare.txt"
readonly P_HOOK
S_PIANO='Plan mode non modifica i file finché il piano non è approvato,'
S_PIANO+=' anche con -p'
readonly S_PIANO
S_DENY='Una regola deny blocca la modifica in ogni modalità; qui in'
S_DENY+=' acceptEdits'
readonly S_DENY
readonly S_HOOK='Un hook PreToolUse che esce con 2 blocca la chiamata'
# L'inizio del verdetto sull'elenco dei dinieghi, che il controllo non dà
# più: l'elenco e i messaggi permission_denied sono dati.
readonly ELENCO_VERDETTO="Con stream-json il diniego è nell'elenco"
readonly CONF='confermata'
readonly NONCONF='non confermata in questa esecuzione'
readonly NONDIST='non distinguibile'
readonly UN_ESITO_DIVERSO='Esito diverso da quello atteso: 1 verdetti'
# Le due chiamate che le impostazioni negano, come il controllo le stampa.
readonly NEGATA_DENY="Edit ${FILE_DATI}"
readonly NEGATA_HOOK='Bash «rm da_cancellare.txt»'
# Il comando che la verifica consiglia per riportare i dati al punto di
# partenza, anche dopo un commit.
# shellcheck disable=SC2016  # è il testo del consiglio, non si espande
CONSIGLIO='git checkout "$(git rev-list --max-parents=0 HEAD)" --'
CONSIGLIO+=" ${DATI}"
readonly CONSIGLIO
readonly MANCA_REGOLA='manca la regola'
FATTO_PROVA="Fatto: la regola deny c'è e i dati generati non sono"
FATTO_PROVA+=" cambiati."
readonly FATTO_PROVA
readonly TUTTE='Ogni garanzia è confermata in questa esecuzione.'
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
    fail "$1 (rc=${RC}, attesa $2, parola «$3»): ${OUT:0:600}"
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

# Un diniego come il controllo lo stampa fra i dati di un'esecuzione.
# Arguments: $1 la chiamata negata; $2 se è nell'elenco permission_denials
#   del risultato, $3 se lo stream ha il messaggio permission_denied: «sì»
#   o «no».
# Outputs: il testo, su STDOUT.
dinieghi() {
  local elenco="elenco permission_denials: $2"
  printf 'dinieghi: %s (%s; messaggio permission_denied: %s)' "$1" \
    "${elenco}" "$3"
}

# Uno spazio di lavoro nuovo, con prepara_esercizio.sh in una radice nuova.
# Arguments: $1 la variabile da assegnare.
# Returns: 0; 1 se prepara_esercizio.sh non riesce.
nuovo_ws() {
  local __r
  __r="$(mktemp -d "${TMP}/radice.XXXXXX")" || exit 2
  "${RADICE}/tools/prepara_esercizio.sh" M4-D04 --radice "${__r}" \
    > "${TMP}/prepara.log" 2>&1 || return 1
  printf -v "$1" '%s' "${__r}/M4-D04"
}

# L'esca in ${TMP}/esca (registra ogni invocazione ed esce 0); il claude
# finto in ${TMP}/finto; tre PATH senza uno strumento: ${TMP}/senza_python
# (readlink e l'esca), ${TMP}/senza_git (readlink, python3, l'esca),
# ${TMP}/senza_claude (readlink, python3, git). Esce 2 se nel PATH di
# prova il claude trovato non è il finto.
prepara_claude() {
  local t
  mkdir -p "${TMP}/esca" "${TMP}/finto" "${TMP}/senza_python" \
    "${TMP}/senza_git" "${TMP}/senza_claude" "${TMP}/casa" || exit 2
  # shellcheck disable=SC2016  # il corpo è dell'esca
  printf '%s\n' '#!/bin/bash' \
    'printf "invocazione %s\n" "$*" >> "${ESCA_LOG}"' \
    > "${TMP}/esca/claude" || exit 2
  cp -- "${FINTO_PY}" "${TMP}/finto/claude" || exit 2
  chmod 755 "${TMP}/esca/claude" "${TMP}/finto/claude" || exit 2
  ln -s "${TMP}/esca/claude" "${TMP}/senza_python/claude" || exit 2
  ln -s "${TMP}/esca/claude" "${TMP}/senza_git/claude" || exit 2
  ln -s "$(command -v readlink)" "${TMP}/senza_python/readlink" || exit 2
  for t in readlink python3; do
    ln -s "$(command -v "${t}")" "${TMP}/senza_git/${t}" || exit 2
  done
  for t in readlink python3 git; do
    ln -s "$(command -v "${t}")" "${TMP}/senza_claude/${t}" || exit 2
  done
  t="$(PATH="${TMP}/finto:${PATH}" command -v claude)"
  if [[ "${t}" != "${TMP}/finto/claude" ]]; then
    echo "test_m4_d04: nel PATH di prova claude è ${t}, non il finto" >&2
    exit 2
  fi
}

# live.sh con l'esca davanti nel PATH (o con un PATH dato); il registro
# delle invocazioni riparte vuoto. Arguments: $1 lo spazio di lavoro, $2
# facoltativo il PATH.
esca() {
  : > "${TMP}/esca.log"
  run env PATH="${2:-${TMP}/esca:${PATH}}" HOME="${TMP}/casa" \
    HANDSON_NO_PAUSE=1 ESCA_LOG="${TMP}/esca.log" \
    "${D04}/_docente/live.sh" "$1"
}

# Una precondizione di live.sh: uscita 2, la parola attesa, e nessuna
# invocazione dell'esca. Arguments: $1 il nome, $2 la parola, poi gli
# argomenti di esca.
precondizione() {
  local nome="$1" parola="$2" n
  shift 2
  esca "$@"
  expect "${nome}" 2 "${parola}"
  n="$(grep -c . "${TMP}/esca.log")"
  if (( n == 0 )); then
    pass "${nome}: nessuna invocazione di claude"
  else
    fail "${nome}: ${n} invocazioni di claude"
  fi
}

# Una precondizione di live.sh con un ambiente dato: l'esca davanti nel
# PATH, uscita 2, la parola attesa, nessuna invocazione dell'esca.
# Arguments: $1 il nome, $2 la parola, $3 lo spazio di lavoro, poi gli
# argomenti di env (NOME=valore, -u NOME).
precondizione_env() {
  local nome="$1" parola="$2" w="$3" n
  shift 3
  : > "${TMP}/esca.log"
  run env PATH="${TMP}/esca:${PATH}" HOME="${TMP}/casa" HANDSON_NO_PAUSE=1 \
    ESCA_LOG="${TMP}/esca.log" env "$@" "${D04}/_docente/live.sh" "${w}"
  expect "${nome}" 2 "${parola}"
  n="$(grep -c . "${TMP}/esca.log")"
  if (( n == 0 )); then
    pass "${nome}: nessuna invocazione di claude"
  else
    fail "${nome}: ${n} invocazioni di claude"
  fi
}

# Una modifica di un file dello spazio di lavoro, in un commit, così lo
# spazio di lavoro resta al punto di partenza per git status.
# Arguments: $1 lo spazio di lavoro, $2 il file, $3 il contenuto.
in_un_commit() {
  printf '%s' "$3" > "$1/$2"
  git -C "$1" -c user.name=Prova -c user.email=prova@example.org \
    commit -q -am "cambia $2" || true
}

# live.sh con il claude finto davanti nel PATH, una HOME finta e
# ANTHROPIC_API_KEY impostata (live.sh la deve togliere); il registro
# riparte vuoto. Arguments: $1 lo spazio di lavoro, poi le variabili
# NOME=valore.
finto() {
  local w="$1"
  shift
  : > "${TMP}/finto.log"
  run env PATH="${TMP}/finto:${PATH}" HOME="${TMP}/casa" HANDSON_NO_PAUSE=1 \
    ANTHROPIC_API_KEY=valore-finto FINTO_LOG="${TMP}/finto.log" "$@" \
    "${D04}/_docente/live.sh" "${w}"
}

# Quante chiamate al modello (non --version) ha ricevuto il finto, e
# quante con ANTHROPIC_API_KEY. Arguments: $1 il registro.
# Outputs: «chiamate chiavi».
chiamate() {
  python3 -B -I - "$1" <<'PY'
import json, sys
righe = [json.loads(r) for r in open(sys.argv[1], encoding="utf-8")]
modello = [r for r in righe if r["argv"][:1] != ["--version"]]
print(len(modello), sum(1 for r in modello if r["chiave"]))
PY
}

# Uno spazio di lavoro dopo live.sh con il finto, copiato dal primo che è
# andato bene (BUONO), per le prove del controllo. Arguments: $1 la
# variabile da assegnare. Returns: 0; 1 se non c'è uno spazio buono.
copia_buono() {
  local __c
  [[ -n "${BUONO}" && -d "${BUONO}" ]] || return 1
  __c="$(mktemp -d "${TMP}/copia.XXXXXX")" || exit 2
  cp -a -- "${BUONO}/." "${__c}/" || exit 2
  printf -v "$1" '%s' "${__c}"
}

# controlla_gradini.py dell'elemento sullo spazio di lavoro $1, con gli
# argomenti che seguono; RC e OUT come run.
controlla() {
  local w="$1"
  shift
  run python3 -B -I "${D04}/demo/controlla_gradini.py" "$@" "${w}"
}

# --- L'elemento -------------------------------------------------------------

t_elemento() {
  local f
  for f in README.md progetti.txt verifica.sh demo/controlla_gradini.py \
      demo/richieste/piano.txt demo/richieste/deny.txt \
      demo/richieste/hook.txt demo/impostazioni/deny.json \
      demo/impostazioni/hook.json demo/impostazioni/blocca_rm.py \
      _docente/live.sh _docente/lib_gradini.sh \
      soluzione/.claude/settings.json soluzione/LEGGIMI.md
  do
    if [[ -f "${D04}/${f}" ]]; then
      pass "elemento: ${f}"
    else
      fail "elemento: manca ${f}"
    fi
  done
  for f in verifica.sh _docente/live.sh; do
    vero "elemento: ${f} eseguibile" test -x "${D04}/${f}"
  done
  if [[ -f "${D04}/_docente/lib_gradini.sh" \
      && ! -x "${D04}/_docente/lib_gradini.sh" ]]; then
    pass "elemento: _docente/lib_gradini.sh, una libreria, non eseguibile"
  else
    fail "elemento: _docente/lib_gradini.sh manca o è eseguibile"
  fi
  run cat -- "${D04}/progetti.txt"
  expect "elemento: progetti.txt porta il gestionale" 0 \
    "progetti/gestionale-php"
  run python3 -B -I - "${D04}/demo/richieste" "${P_PIANO}" "${P_DENY}" \
    "${P_HOOK}" <<'PY'
import os, sys
cartella, *attese = sys.argv[1:]
nomi = ("piano.txt", "deny.txt", "hook.txt")
problemi = []
for nome, attesa in zip(nomi, attese):
    try:
        with open(os.path.join(cartella, nome), encoding="utf-8") as fh:
            testo = fh.read()
    except OSError:
        problemi.append("manca " + nome)
        continue
    if testo.rstrip("\n") != attesa:
        problemi.append(nome)
print("; ".join(problemi) or "richieste giuste")
PY
  expect "elemento: le tre richieste, una per file" 0 "richieste giuste"
}

# Le impostazioni dei due gradini e la soluzione: la base del repository
# più una cosa sola.
t_impostazioni() {
  run python3 -B -I - "${RADICE}/.claude/settings.json" "${D04}" \
    "${REGOLA}" <<'PY'
import json, os, sys
base_p, item, regola = sys.argv[1:4]
def leggi(rel):
    with open(os.path.join(item, rel), encoding="utf-8") as fh:
        return json.load(fh)
try:
    with open(base_p, encoding="utf-8") as fh:
        base = json.load(fh)
    deny = leggi("demo/impostazioni/deny.json")
    hook = leggi("demo/impostazioni/hook.json")
    sol = leggi("soluzione/.claude/settings.json")
except (OSError, ValueError) as exc:
    print("non si leggono (%s)" % exc)
    sys.exit(0)
problemi = []
attesa = json.loads(json.dumps(base))
attesa["permissions"]["deny"].append(regola)
if deny != attesa:
    problemi.append("deny.json non è la base più la regola")
if sol != deny:
    problemi.append("la soluzione non è deny.json")
if {k: v for k, v in hook.items() if k != "hooks"} != base:
    problemi.append("hook.json non è la base più gli hook")
voci = hook.get("hooks", {}).get("PreToolUse", [])
if list(hook.get("hooks", {})) != ["PreToolUse"] or len(voci) != 1:
    problemi.append("hook.json: un solo hook PreToolUse")
else:
    comandi = [h.get("command", "") for h in voci[0].get("hooks", [])
               if h.get("type") == "command"]
    if (voci[0].get("matcher") != "Bash" or len(comandi) != 1
            or ".claude/hooks/blocca_rm.py" not in comandi[0]):
        problemi.append("hook.json: il matcher Bash e blocca_rm.py")
print("; ".join(problemi) or "impostazioni giuste")
PY
  expect "impostazioni: la base del repository più una cosa sola" 0 \
    "impostazioni giuste"
  vero "impostazioni: la soluzione è deny.json, byte per byte" \
    cmp -s "${D04}/demo/impostazioni/deny.json" \
    "${D04}/soluzione/.claude/settings.json"
}

# Il README: le dieci sezioni, le frasi di Anthropic e i loro indirizzi,
# le richieste, il JSON della prova uguale alla soluzione; niente nomi
# interni, percorsi personali, giornate; niente file dei difetti inseriti
# in nessun file dell'elemento.
t_readme() {
  run python3 -B -I - "${D04}" "${DIFETTI}" "${P_PIANO}" "${P_DENY}" \
    "${P_HOOK}" "${REGOLA}" <<'PY'
import json, os, re, sys
item, difetti, *richieste, regola = sys.argv[1:]
with open(os.path.join(item, "README.md"), encoding="utf-8") as fh:
    readme = fh.read()
problemi = []
sezioni = ("Obiettivo", "Tempo", "Prerequisiti", "Punto di partenza",
           "Passi in Claude Code", "Che cosa osservare", "Verifica",
           "Se qualcosa va storto", "Impronta d'uso sul piano Pro",
           "Per approfondire")
titoli = [r[3:] for r in readme.splitlines() if r.startswith("## ")]
if [t for t in titoli if t.startswith(sezioni)] != titoli or \
        [next((s for s in sezioni if t.startswith(s)), "") for t in titoli] \
        != list(sezioni):
    problemi.append("le dieci sezioni, in ordine: %s" % titoli)
if "## Punto di partenza (tools/prepara_esercizio.sh M4-D04)" not in readme:
    problemi.append("il titolo del punto di partenza")
if "## Verifica (tools/verifica.sh M4-D04)" not in readme:
    problemi.append("il titolo della verifica")
frasi = [
    ("Plan mode tells Claude to research and propose changes without "
     "making them. … Except in interactive terminal sessions with bypass "
     "permissions available, edits stay blocked until you approve the "
     "plan.", "https://code.claude.com/docs/en/permission-modes"),
    ("Plan mode keeps its blocks wherever Claude Code runs without an "
     "interactive terminal, including non-interactive runs with -p",
     "https://code.claude.com/docs/en/permission-modes"),
    ("Deny rules block in every mode, including bypassPermissions.",
     "https://code.claude.com/docs/en/permission-modes"),
    ("Edit rules apply to all built-in tools that edit files.",
     "https://code.claude.com/docs/en/permissions"),
    ("Exit with code 2 to block the action. On events that can block, "
     "Claude Code stops the action: a PreToolUse hook blocks the tool call",
     "https://code.claude.com/docs/en/hooks"),
    ("With --output-format stream-json, denials appear as permission_denied"
     " system messages, and the final result message lists them in "
     "permission_denials.", "https://code.claude.com/docs/en/headless"),
    ("Starting on August 14, new sessions on Pro, Max, and Team plans will"
     " run in auto mode.",
     "https://claude.com/resources/articles/auto-mode-default-in-claude-code"),
    ("press Shift+Tab to cycle permission modes. From auto, the first press"
     " switches to default, and the cycle then runs default → acceptEdits → "
     "plan.", "https://code.claude.com/docs/en/permission-modes"),
    ("`path` or `./path` | Path relative to current directory | "
     "`Read(*.env)` | `<cwd>/*.env`",
     "https://code.claude.com/docs/en/permissions"),
    ("`/path` | Path relative to the settings source | `Edit(/src/**/*.ts)`"
     " | `<primary working directory>/src/**/*.ts` in project settings",
     "https://code.claude.com/docs/en/permissions"),
    ("Output redirects: for > file, >> file, or 2> file, the check covers "
     "your Edit allow and deny rules, protected paths, and the working "
     "directories.", "https://code.claude.com/docs/en/permissions"),
    ("They don't apply … to arbitrary subprocesses that read or write files "
     "indirectly, like a Python or Node script that opens files itself.",
     "https://code.claude.com/docs/en/permissions"),
    ("Choose where Claude Code stores the plan files it writes in plan mode."
     " … Default: unset, so Claude Code uses `~/.claude/plans`",
     "https://code.claude.com/docs/en/settings-reference"),
]
piatto = " ".join(readme.split())
if "in plan mode Claude ha scritto il piano" in piatto:
    problemi.append("resta l'osservazione della prova sul piano")
if "prova del corso" in piatto:
    problemi.append("resta la prova del corso sul cd e sulla redirezione")
if "2 su 2" in piatto:
    problemi.append("resta il verdetto sull'elenco dei dinieghi")
if "qui in acceptEdits" not in piatto:
    problemi.append("la regola deny senza il caso che la demo decide")
if "rifatta dal docente con `claude -p` invece che in una sessione" \
        not in piatto:
    problemi.append("la prova senza terminale non dice chi l'ha rifatta")
parti = readme.split("### Che cosa dice Anthropic", 1)
if len(parti) != 2:
    problemi.append("manca la parte «Che cosa dice Anthropic»")
elif "permission_denials" in parti[1].split("\n### ", 1)[0]:
    problemi.append("l'elenco dei dinieghi fra le frasi messe alla prova")
if "Edit(progetti/gestionale-php" in readme \
        and "barra iniziale" not in piatto:
    problemi.append("una regola relativa senza la spiegazione")
for frase, url in frasi:
    if frase not in piatto:
        problemi.append("manca la frase «%s…»" % frase[:40])
    if url not in readme:
        problemi.append("manca l'indirizzo %s" % url)
for richiesta in richieste:
    if richiesta not in piatto:
        problemi.append("manca la richiesta «%s…»" % richiesta[:30])
blocchi, blocco = [], []
for riga in readme.splitlines() + [""]:
    if riga.startswith("       ") and riga.strip():
        blocco.append(riga.strip())
    elif blocco:
        blocchi.append("\n".join(blocco))
        blocco = []
if "cd -\ntools/verifica.sh M4-D04" not in blocchi:
    problemi.append("la verifica senza il cd - per tornare a esercitazioni")
json_prova = [b for b in blocchi if regola in b and b.startswith("{")]
try:
    with open(os.path.join(item, "soluzione/.claude/settings.json"),
              encoding="utf-8") as fh:
        soluzione = json.load(fh)
    if len(json_prova) != 1 or json.loads(json_prova[0]) != soluzione:
        problemi.append("il JSON della prova non è la soluzione")
except (OSError, ValueError) as exc:
    problemi.append("il JSON della prova (%s)" % exc)
maniglie = re.compile(r"\bFACT-(?:C|M[0-9])-[0-9]{3}\b|\bM[0-9]-X[0-9]+\b"
                      r"|\bX-[0-9]+\b|(?<![\w-])D(?:0[1-9]|[12][0-9]|3[01])\b"
                      r"|\b(?:ASK|OQ|DEC|TD|PQ)-[0-9]+\b|(?i:\btriage\b)")
giornata = re.compile(r"(?i)\boggi\b|prossima sessione|\bpausa\b|pranzo")
with open(difetti, encoding="utf-8") as fh:
    sezione1 = fh.read().split("## 2.")[0]
nomi = {os.path.basename(p.split(":")[0])
        for p in re.findall(r"`([^`]+\.(?:php|inc\.php))[^`]*`", sezione1)}
for cartella, _, file in os.walk(item):
    for nome in file:
        percorso = os.path.join(cartella, nome)
        rel = os.path.relpath(percorso, item)
        try:
            with open(percorso, encoding="utf-8") as fh:
                testo = fh.read()
        except (OSError, UnicodeDecodeError):
            continue
        for m in maniglie.finditer(testo):
            problemi.append("%s: un nome interno «%s»" % (rel, m.group()))
        if "/home/" in testo:
            problemi.append("%s: un percorso personale" % rel)
        if "smentit" in testo:
            problemi.append("%s: «smentita»" % rel)
        for n in sorted(nomi):
            if n in testo:
                problemi.append("%s: il file dei difetti %s" % (rel, n))
if giornata.search(readme):
    problemi.append("il README parla della giornata")
if len(nomi) < 10:
    problemi.append("difetti-noti.md: %d file soltanto" % len(nomi))
print("; ".join(problemi) or "README in ordine")
PY
  expect "README: sezioni, frasi, richieste, JSON e nessun nome interno" 0 \
    "README in ordine"
}

# --- blocca_rm.py, lo script dell'hook --------------------------------------

# Lo script dell'hook con un comando di Bash nell'ingresso JSON; RC, OUT
# (STDOUT) ed ERR (STDERR) a parte. Arguments: $1 il comando, oppure
# l'ingresso intero se $2 è «grezzo».
ERR=''
hook() {
  local ingresso="$1"
  if [[ "${2:-}" != grezzo ]]; then
    ingresso="$(python3 -B -I -c 'import json, sys
print(json.dumps({"hook_event_name": "PreToolUse", "tool_name": "Bash",
                  "tool_input": {"command": sys.argv[1]}}))' "$1")"
  fi
  OUT="$(python3 -B -I "${D04}/demo/impostazioni/blocca_rm.py" \
    <<< "${ingresso}" 2> "${TMP}/hook.err")"
  RC=$?
  ERR="$(cat "${TMP}/hook.err")"
}

t_hook() {
  local c
  # shellcheck disable=SC2016  # i comandi sono testi per l'hook, non per bash
  for c in 'rm da_cancellare.txt' 'rm -f da_cancellare.txt' '/bin/rm x' \
      'ls; rm x' 'cd a && rm -rf b' 'find . -name x | xargs rm' \
      'sudo rm x' 'echo $(rm x)' '(rm x)' $'# togli il file\nrm x' \
      'echo a#b; rm x' 'if true; then rm x; fi' '! rm x' '{ rm x; }' \
      'find . -name x -exec rm {} ;' 'timeout 5 rm x' 'echo "$(rm x)"'; do
    hook "${c}"
    if (( RC == 2 )) && [[ -z "${OUT}" ]] \
        && grep -qF "Bloccato dall'hook del progetto" <<< "${ERR}"; then
      pass "hook: blocca «${c}», il motivo su STDERR"
    else
      fail "hook: «${c}» rc=${RC} err=«${ERR}»"
    fi
  done
  for c in 'ls -la' 'echo rm' 'grep rm README.md' 'git rm --cached x' \
      'cat rmdir.txt' 'echo "# rm"' $'# un commento\nls'; do
    hook "${c}"
    if (( RC == 0 )) && [[ -z "${OUT}${ERR}" ]]; then
      pass "hook: lascia passare «${c}» in silenzio"
    else
      fail "hook: «${c}» rc=${RC} err=«${ERR}»"
    fi
  done
  hook "echo 'senza chiusura"
  if (( RC == 2 )) && grep -qF 'non riesco a leggere' <<< "${ERR}"; then
    pass "hook: un comando che non si legge si blocca"
  else
    fail "hook: comando illeggibile rc=${RC} err=«${ERR}»"
  fi
  for c in 'non è JSON' '{"tool_input": {}}' '[1, 2]'; do
    hook "${c}" grezzo
    if (( RC == 2 )) && grep -qF 'non riesco a leggere' <<< "${ERR}"; then
      pass "hook: un ingresso che non va («${c}») si blocca"
    else
      fail "hook: ingresso «${c}» rc=${RC} err=«${ERR}»"
    fi
  done
  hook "$(python3 -B -I -c 'print("[" * 100000 + "]" * 100000)')" grezzo
  if (( RC == 2 )) && grep -qF 'non riesco a leggere' <<< "${ERR}" \
      && ! grep -qF 'Traceback' <<< "${ERR}"; then
    pass "hook: un JSON troppo annidato si blocca, senza traceback"
  else
    fail "hook: JSON annidato rc=${RC} err=«${ERR:0:200}»"
  fi
}

# --- La prova dei partecipanti: prepara_esercizio.sh e verifica.sh ------------

# verifica.sh sullo spazio di lavoro $1 (con un PATH dato in $2).
verifica() {
  run env PATH="${2:-${PATH}}" "${D04}/verifica.sh" "$1"
}

# La regola nelle impostazioni dello spazio di lavoro, come la soluzione.
# Arguments: $1 lo spazio di lavoro.
con_regola() {
  cp -- "${D04}/soluzione/.claude/settings.json" "$1/.claude/settings.json"
}

# Il comando che la verifica consiglia (CONSIGLIO), eseguito nello spazio
# di lavoro: i dati generati come al primo commit. Il suo esito lo dice la
# verifica che segue. Arguments: $1 lo spazio di lavoro.
segui_consiglio() {
  ( cd -- "$1" \
      && git checkout "$(git rev-list --max-parents=0 HEAD)" -- "${DATI}" ) \
    > /dev/null 2>&1
}

t_prepara() {
  local w
  if ! nuovo_ws w; then
    fail "prepara: prepara_esercizio.sh non riesce: $(cat "${TMP}/prepara.log")"
    return 0
  fi
  if [[ -f "${w}/${FILE_DATI}" && -f "${w}/${FILE_PIANO}" \
      && -f "${w}/controlla_gradini.py" && -f "${w}/impostazioni/deny.json" \
      && -f "${w}/richieste/deny.txt" \
      && ! -e "${w}/progetti/gestionale-php/_docente" \
      && ! -e "${w}/soluzione" && ! -e "${w}/_docente" ]]; then
    pass "prepara: il gestionale e la demo, senza il materiale del docente"
  else
    fail "prepara: lo spazio di lavoro non è quello atteso"
  fi
  vero "prepara: le impostazioni prudenti del repository" \
    cmp -s "${RADICE}/.claude/settings.json" "${w}/.claude/settings.json"
  verifica "${w}"
  expect "verifica: sul punto di partenza esce 1" 1 "${MANCA_REGOLA}"
  expect_absent "verifica: sul punto di partenza i dati sono a posto" \
    "dati generati sono cambiati"
  cp -R "${D04}/soluzione/." "${w}/"
  verifica "${w}"
  expect "verifica: con la soluzione esce 0" 0 "${FATTO_PROVA}"
  expect_absent "verifica: con la soluzione nessun «non ancora»" "Non ancora"
}

# Le varianti della prova: ognuna in uno spazio di lavoro nuovo.
t_verifica() {
  local w forma
  for forma in '(' '(./'; do
    nuovo_ws w || { fail "verifica: nessuno spazio di lavoro"; return 0; }
    python3 -B -I - "${w}/.claude/settings.json" "${REGOLA}" "${forma}" \
      <<'PY'
import json, sys
percorso, regola, forma = sys.argv[1:4]
doc = json.load(open(percorso, encoding="utf-8"))
doc["permissions"]["deny"].append(regola.replace("(/", forma, 1))
json.dump(doc, open(percorso, "w", encoding="utf-8"), indent=2)
PY
    verifica "${w}"
    expect "verifica: la regola relativa «${forma}…» non basta (1)" 1 \
      "${SENZA_BARRA}"
    expect "verifica: e dice perché, con la cartella corrente" 1 \
      "dopo un cd"
    expect_absent "verifica: una regola relativa non è «Fatto»" "Fatto:"
  done
  nuovo_ws w || return 0
  python3 -B -I - "${w}/.claude/settings.json" "${REGOLA}" <<'PY'
import json, sys
percorso, regola = sys.argv[1:3]
doc = json.load(open(percorso, encoding="utf-8"))
doc["permissions"]["allow"] = [regola]
json.dump(doc, open(percorso, "w", encoding="utf-8"), indent=2)
PY
  verifica "${w}"
  expect "verifica: la regola in allow, non in deny (1)" 1 "${MANCA_REGOLA}"
  nuovo_ws w || return 0
  printf '{\n  "permissions": {\n    "deny": [\n      "%s",\n    ]\n' \
    "${REGOLA}" > "${w}/.claude/settings.json"
  verifica "${w}"
  expect "verifica: un JSON rotto (1)" 1 "non è un JSON valido"
  expect "verifica: dice la riga del JSON rotto" 1 "riga "
  nuovo_ws w || return 0
  rm -f -- "${w}/.claude/settings.json"
  verifica "${w}"
  expect "verifica: il file delle impostazioni che manca (1)" 1 \
    "manca .claude/settings.json"
  nuovo_ws w || return 0
  con_regola "${w}"
  printf -- '-- elenco controllato a mano\n' >> "${w}/${FILE_DATI}"
  verifica "${w}"
  expect "verifica: la regola c'è ma i dati sono cambiati (1)" 1 \
    "dati generati sono cambiati"
  expect "verifica: dice quale file" 1 "01_comuni.sql"
  expect_absent "verifica: la regola, lì, non manca" "${MANCA_REGOLA}"
  expect "verifica: consiglia il comando per il primo commit (1)" 1 \
    "${CONSIGLIO}"
  segui_consiglio "${w}"
  verifica "${w}"
  expect "verifica: seguito il consiglio, senza commit (0)" 0 \
    "${FATTO_PROVA}"
  nuovo_ws w || return 0
  printf -- '-- elenco controllato a mano\n' >> "${w}/${FILE_DATI}"
  verifica "${w}"
  expect "verifica: senza la regola e con i dati cambiati, tutte e due" 1 \
    "${MANCA_REGOLA}"
  expect "verifica: e i dati" 1 "dati generati sono cambiati"
  nuovo_ws w || return 0
  con_regola "${w}"
  touch "${w}/${DATI}/99_nuovo.sql"
  verifica "${w}"
  expect "verifica: un file nuovo fra i dati (1)" 1 "99_nuovo.sql"
  nuovo_ws w || return 0
  con_regola "${w}"
  printf -- '-- elenco controllato a mano\n' >> "${w}/${FILE_DATI}"
  git -C "${w}" -c user.name=Prova -c user.email=prova@example.org \
    commit -q -am 'la modifica dei dati in un commit' || true
  verifica "${w}"
  expect "verifica: una modifica dei dati già in un commit (1)" 1 \
    "dati generati sono cambiati"
  expect "verifica: anche dopo un commit consiglia il primo commit (1)" 1 \
    "${CONSIGLIO}"
  segui_consiglio "${w}"
  verifica "${w}"
  expect "verifica: seguito il consiglio dopo un commit (0)" 0 \
    "${FATTO_PROVA}"
  nuovo_ws w || return 0
  con_regola "${w}"
  printf -- '-- un file nuovo\n' > "${w}/${DATI}/99_nuovo.sql"
  git -C "${w}" add -- "${DATI}"
  git -C "${w}" -c user.name=Prova -c user.email=prova@example.org \
    commit -q -m 'un file nuovo fra i dati, in un commit'
  verifica "${w}"
  expect "verifica: un file nuovo già in un commit, segnato A (1)" 1 \
    $'A\t'"${DATI}/99_nuovo.sql"
  segui_consiglio "${w}"
  rm -f -- "${w}/${DATI}/99_nuovo.sql"
  verifica "${w}"
  expect "verifica: il consiglio e il file nuovo tolto (0)" 0 \
    "${FATTO_PROVA}"
  nuovo_ws w || return 0
  con_regola "${w}"
  git -C "${w}" rm -rq -- "${DATI}" || true
  git -C "${w}" -c user.name=Prova -c user.email=prova@example.org \
    commit -q -m 'senza i dati' || true
  verifica "${w}"
  expect "verifica: i dati tolti in un commit (1)" 1 \
    "dati generati sono cambiati"
}

# Le precondizioni di verifica.sh: uscita 2.
t_verifica_precondizioni() {
  local w
  verifica "${TMP}/assente"
  expect "verifica: spazio di lavoro assente (2)" 2 "spazio di lavoro assente"
  nuovo_ws w || { fail "verifica: nessuno spazio di lavoro"; return 0; }
  con_regola "${w}"
  verifica "${w}" "${TMP}/senza_python"
  expect "verifica: python3 che manca (2)" 2 "manca python3"
  verifica "${w}" "${TMP}/senza_git"
  expect "verifica: git che manca (2)" 2 "manca git"
  rm -rf -- "${w}/.git"
  verifica "${w}"
  expect "verifica: uno spazio di lavoro che non è un repository git (2)" 2 \
    "non è un repository git"
  mkdir -p "${TMP}/chiusa"
  chmod 000 "${TMP}/chiusa"
  verifica "${TMP}/chiusa"
  expect "verifica: uno spazio di lavoro in cui non si entra (2)" 2 \
    "non si apre"
  chmod 755 "${TMP}/chiusa"
}

t_run_all() {
  run "${RADICE}/tools/run_all.sh" M4-D04
  expect "run_all: M4-D04, partenza e soluzione" 0 "1 ok, 0 KO"
}

# --- _docente/live.sh -------------------------------------------------------

# Le precondizioni escono 2 prima di ogni invocazione di claude.
t_live_precondizioni() {
  local w f
  precondizione "live: spazio di lavoro assente" "spazio di lavoro assente" \
    "${TMP}/assente"
  for f in controlla_gradini.py richieste/piano.txt richieste/deny.txt \
      richieste/hook.txt impostazioni/deny.json impostazioni/hook.json \
      impostazioni/blocca_rm.py .claude/settings.json "${FILE_PIANO}" \
      "${FILE_DATI}"; do
    nuovo_ws w || { fail "live: nessuno spazio di lavoro"; return 0; }
    rm -f -- "${w}/${f}"
    precondizione "live: ${f} che manca" "file assente o illeggibile" "${w}"
  done
  nuovo_ws w || return 0
  touch "${w}/nuovo.txt"
  precondizione "live: lo spazio di lavoro non è al punto di partenza" \
    "non è al punto di partenza" "${w}"
  nuovo_ws w || return 0
  precondizione "live: python3 che manca" "manca lo strumento: python3" \
    "${w}" "${TMP}/senza_python"
  precondizione "live: git che manca" "manca lo strumento: git" \
    "${w}" "${TMP}/senza_git"
  esca "${w}" "${TMP}/senza_claude"
  expect "live: claude che manca" 2 "manca lo strumento: claude"
  precondizione_env "live: HANDSON_ENV=trainer-api, rifiutato" \
    "claude-code-pro" "${w}" HANDSON_ENV=trainer-api \
    ANTHROPIC_API_KEY=valore-finto
  precondizione_env "live: senza HOME" "HOME" "${w}" -u HOME
  mkdir -p "${TMP}/chiusa"
  chmod 000 "${TMP}/chiusa"
  precondizione_env "live: uno spazio di lavoro in cui non si entra" \
    "non si apre" "${TMP}/chiusa"
  chmod 755 "${TMP}/chiusa"
  nuovo_ws w || return 0
  in_un_commit "${w}" richieste/deny.txt ''
  precondizione_env "live: una richiesta vuota, prima di ogni chiamata" \
    "il prompt non può essere vuoto" "${w}"
  nuovo_ws w || return 0
  in_un_commit "${w}" richieste/hook.txt "rm da_cancellare.txt sk-ant""-finta"
  precondizione_env "live: una chiave in una richiesta, prima di chiamare" \
    "sembra una chiave API" "${w}"
  expect_absent "live: la chiave della richiesta non si stampa" \
    "sk-ant""-finta"
}

# Le chiamate del registro del finto, contro quelle attese: cartella,
# modalità, strumenti, richiesta, opzioni fisse, il prompt dopo «--».
# Arguments: $1 il registro, $2 lo spazio di lavoro.
controlla_chiamate() {
  run python3 -B -I - "$1" "$2" "${P_PIANO}" "${P_DENY}" "${P_HOOK}" <<'PY'
import json, os, sys
log, ws, piano, deny, hook = sys.argv[1:6]
ws = os.path.realpath(ws)
solo = "Read,Edit"
attese = [("gradini/piano-con", "plan", "Read,Edit", piano, None),
          ("gradini/piano-senza", "acceptEdits", "Read,Edit", piano, None),
          ("gradini/deny-con", "acceptEdits", "Read,Edit", deny, solo),
          ("gradini/deny-senza", "acceptEdits", "Read,Edit", deny, solo),
          ("gradini/hook-con", "acceptEdits", "Bash(rm *)", hook, None),
          ("gradini/hook-senza", "acceptEdits", "Bash(rm *)", hook, None),
          (".", "acceptEdits", "Read,Edit", deny, None)]
VALORE = {"--model", "--effort", "--allowedTools", "--output-format",
          "--setting-sources", "--permission-mode", "--permission-prompts",
          "--tools"}
righe = [json.loads(r) for r in open(log, encoding="utf-8")]
chiamate = [r for r in righe if r["argv"][:1] != ["--version"]]
problemi = []
if len(chiamate) != len(attese):
    problemi.append("%d chiamate invece di %d" % (len(chiamate), len(attese)))
fisse = (("--model", "sonnet"), ("--effort", "low"),
         ("--output-format", "stream-json"),
         ("--setting-sources", "project,local"),
         ("--permission-prompts", "none"))
for i, (c, (cartella, modo, strumenti, prompt, soli)) in enumerate(
        zip(chiamate, attese), 1):
    argv, opzioni, j = c["argv"], {}, 0
    if "--" not in argv:
        problemi.append("chiamata %d: il prompt non è dopo «--»" % i)
        continue
    fine = argv.index("--")
    while j < fine:
        if argv[j] in VALORE:
            opzioni[argv[j]] = argv[j + 1]
            j += 2
        else:
            opzioni[argv[j]] = True
            j += 1
    if os.path.realpath(c["cwd"]) != os.path.realpath(
            os.path.join(ws, cartella)):
        problemi.append("chiamata %d: la cartella %s" % (i, c["cwd"]))
    if opzioni.get("--permission-mode") != modo:
        problemi.append("chiamata %d: la modalità" % i)
    if opzioni.get("--allowedTools") != strumenti:
        problemi.append("chiamata %d: gli strumenti" % i)
    if opzioni.get("--tools") != soli:
        problemi.append("chiamata %d: --tools %s" % (i, opzioni.get("--tools")))
    if argv[fine + 1:] != [prompt]:
        problemi.append("chiamata %d: la richiesta" % i)
    for chiave, valore in fisse:
        if opzioni.get(chiave) != valore:
            problemi.append("chiamata %d: %s" % (i, chiave))
    for chiave in ("-p", "--verbose", "--strict-mcp-config",
                   "--no-session-persistence"):
        if opzioni.get(chiave) is not True:
            problemi.append("chiamata %d: %s" % (i, chiave))
    if any("bypass" in a or "dangerously" in a for a in argv):
        problemi.append("chiamata %d: salta i permessi" % i)
print("; ".join(problemi) or "chiamate giuste")
PY
}

# Le copie del gestionale lasciate da live.sh: ognuna un repository git
# con un commit, le sue impostazioni, la copia del gestionale; le due
# copie dell'hook con lo script e il file da cancellare.
# Arguments: $1 lo spazio di lavoro.
controlla_copie() {
  run python3 -B -I - "$1" "${RADICE}/.claude/settings.json" "${D04}" <<'PY'
import filecmp, json, os, subprocess, sys
ws, base_p, item = sys.argv[1:4]
def leggi(p):
    with open(p, encoding="utf-8") as fh:
        return json.load(fh)
base = leggi(base_p)
deny = leggi(os.path.join(item, "demo/impostazioni/deny.json"))
hook = leggi(os.path.join(item, "demo/impostazioni/hook.json"))
attese = {"piano-con": base, "piano-senza": base, "deny-con": deny,
          "deny-senza": base, "hook-con": hook, "hook-senza": base}
problemi = []
for nome, impostazioni in attese.items():
    copia = os.path.join(ws, "gradini", nome)
    git = subprocess.run(["git", "-C", copia, "log", "--oneline"],
                         stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                         universal_newlines=True)
    if git.returncode != 0 or len(git.stdout.splitlines()) != 1:
        problemi.append("%s: non è un repository git con un commit" % nome)
    try:
        if leggi(os.path.join(copia, ".claude/settings.json")) != impostazioni:
            problemi.append("%s: le impostazioni" % nome)
    except (OSError, ValueError):
        problemi.append("%s: le impostazioni non si leggono" % nome)
    if not os.path.isfile(os.path.join(
            copia, "progetti/gestionale-php/composer.json")):
        problemi.append("%s: manca il gestionale" % nome)
    if os.path.exists(os.path.join(copia, "progetti/gestionale-php/_docente")):
        problemi.append("%s: c'è il materiale del docente" % nome)
    script = os.path.join(copia, ".claude/hooks/blocca_rm.py")
    if nome.startswith("hook"):
        if not filecmp.cmp(script, os.path.join(
                item, "demo/impostazioni/blocca_rm.py"), shallow=False):
            problemi.append("%s: lo script dell'hook" % nome)
    elif os.path.exists(script) or os.path.exists(
            os.path.join(copia, "da_cancellare.txt")):
        problemi.append("%s: l'hook o il file da cancellare" % nome)
print("; ".join(problemi) or "copie giuste")
PY
}

# Il claude finto: le sei chiamate e la prova, le copie, il piano tolto,
# le impostazioni della prova, i verdetti.
t_live_finto() {
  local w r n
  nuovo_ws w || { fail "live: nessuno spazio di lavoro"; return 0; }
  rm -rf -- "${TMP}/casa/.claude"
  mkdir -p "${TMP}/casa/.claude/plans"
  printf 'un piano del docente\n' > "${TMP}/casa/.claude/plans/mio.md"
  finto "${w}"
  expect "live: il claude finto, uscita 0" 0 "VERIFICA OK   le tre coppie"
  expect "live: la prova dei partecipanti" 0 \
    "VERIFICA OK   la prova dei partecipanti"
  expect "live: il verdetto del piano" 0 "${S_PIANO}: ${CONF}"
  expect "live: il verdetto della regola deny, in acceptEdits" 0 \
    "${S_DENY}: ${CONF}"
  expect "live: il verdetto dell'hook" 0 "${S_HOOK}: ${CONF}"
  expect "live: il diniego della regola, un dato" 0 \
    "$(dinieghi "${NEGATA_DENY}" sì no)"
  expect "live: il diniego dell'hook, un dato" 0 \
    "$(dinieghi "${NEGATA_HOOK}" sì no)"
  expect_absent "live: nessun verdetto sull'elenco dei dinieghi" \
    "${ELENCO_VERDETTO}"
  expect "live: la riga finale del controllo" 0 "${TUTTE}"
  expect "live: la riga di claude si vede prima di girare" 0 \
    "--output-format stream-json"
  expect "live: dice quale piano ha tolto" 0 "tolto il piano"
  r="$(grep -cF "${S_DENY}: ${CONF}" <<< "${OUT}")"
  if (( r == 1 )); then
    pass "live: i verdetti si vedono una volta sola"
  else
    fail "live: il verdetto della regola deny si vede ${r} volte"
  fi
  r="$(chiamate "${TMP}/finto.log")"
  if [[ "${r}" == "7 0" ]]; then
    pass "live: sette chiamate, nessuna con ANTHROPIC_API_KEY"
  else
    fail "live: chiamate e chiavi «${r}», attese «7 0»"
  fi
  controlla_chiamate "${TMP}/finto.log" "${w}"
  expect "live: cartelle, modalità, strumenti, richieste, opzioni" 0 \
    "chiamate giuste"
  controlla_copie "${w}"
  expect "live: le copie, una per esecuzione" 0 "copie giuste"
  n="$(command find "${TMP}/casa/.claude/plans" -type f | wc -l)"
  if [[ -f "${TMP}/casa/.claude/plans/mio.md" ]] && (( n == 1 )); then
    pass "live: tolto il piano di questa esecuzione, e soltanto lui"
  else
    fail "live: in plans/ restano ${n} file"
  fi
  vero "live: la prova, con le impostazioni della soluzione" \
    cmp -s "${D04}/soluzione/.claude/settings.json" "${w}/.claude/settings.json"
  run git -C "${w}" status --porcelain -- "${DATI}"
  if (( RC == 0 )) && [[ -z "${OUT}" ]]; then
    pass "live: la prova non ha cambiato i dati dello spazio di lavoro"
  else
    fail "live: i dati dello spazio di lavoro: ${OUT}"
  fi
  r="$(command find "${w}/risposte" -name '*.jsonl' | wc -l)"
  if (( r == 7 )); then
    pass "live: sette stream in risposte/"
  else
    fail "live: ${r} stream in risposte/"
  fi
  BUONO="${w}"
}

# Il claude finto che cambia gli esiti: un esito diverso esce 1, con il
# suo perché. Arguments: $1 il nome, $2 la parola attesa, poi le variabili
# del finto.
esito_diverso() {
  local nome="$1" parola="$2" w
  shift 2
  nuovo_ws w || { fail "${nome}: nessuno spazio di lavoro"; return 0; }
  finto "${w}" "$@"
  expect "${nome}" 1 "${parola}"
  expect_absent "${nome}: nessun traceback" "Traceback"
}

t_live_esiti() {
  local w r
  esito_diverso "live: la regola ignorata, non confermata" \
    "${S_DENY}: ${NONCONF}" FINTO_DENY_IGNORA=1
  esito_diverso "live: la regola ignorata, e la prova lo vede" \
    "dati generati sono cambiati" FINTO_DENY_IGNORA=1
  esito_diverso "live: con la regola Claude non tenta, non distinguibile" \
    "${S_DENY}: ${NONDIST}" FINTO_DENY_NON_TENTA=1
  esito_diverso "live: senza la regola nessuna modifica, non distinguibile" \
    "${S_DENY}: ${NONDIST}" FINTO_DENY_FERMO=1
  esito_diverso "live: il plan mode che modifica, non confermata" \
    "${S_PIANO}: ${NONCONF}" FINTO_PIANO_MODIFICA=1
  esito_diverso "live: senza plan mode nessuna modifica, non distinguibile" \
    "${S_PIANO}: ${NONDIST}" FINTO_PIANO_FERMO=1
  esito_diverso "live: l'hook ignorato, non confermata" \
    "${S_HOOK}: ${NONCONF}" FINTO_HOOK_IGNORA=1
  esito_diverso "live: senza l'hook nessun rm, non distinguibile" \
    "${S_HOOK}: ${NONDIST}" FINTO_HOOK_FERMO=1
  esito_diverso "live: con l'hook Claude non tenta, non distinguibile" \
    "${S_HOOK}: ${NONDIST}" FINTO_HOOK_NON_TENTA=1
  esito_diverso "live: uno stream troncato" \
    "lo stream non finisce con il risultato" FINTO_TRONCO=1
  nuovo_ws w || return 0
  finto "${w}" FINTO_ESITO=ko
  r="$(chiamate "${TMP}/finto.log")"
  if (( RC == 1 )) && [[ "${r}" == "1 0" ]] \
      && grep -qF 'VERIFICA KO' <<< "${OUT}"; then
    pass "live: si ferma alla prima chiamata fallita"
  else
    fail "live: rc=${RC} dopo le chiamate «${r}»: ${OUT:0:300}"
  fi
  nuovo_ws w || return 0
  mkdir -p "${TMP}/altrove"
  finto "${w}" FINTO_PIANO_PERCORSO="${TMP}/altrove/piano.md"
  expect "live: un piano fuori da ~/.claude/plans resta, uscita 0" 0 \
    "lascio ${TMP}/altrove/piano.md"
  vero "live: e il file c'è ancora" test -f "${TMP}/altrove/piano.md"
  nuovo_ws w || return 0
  rm -rf -- "${TMP}/casa/.claude"
  mkdir -p "${TMP}/casa/.claude/plans"
  finto "${w}" FINTO_ESITO_KO_SE=01_comuni.sql
  r="$(command find "${TMP}/casa/.claude/plans" -type f | wc -l)"
  if (( RC == 1 && r == 0 )) && grep -qF 'tolto il piano' <<< "${OUT}"; then
    pass "live: una chiamata fallita dopo il plan mode, il piano tolto"
  else
    fail "live: chiamata fallita, rc=${RC}, ${r} file in plans/"
  fi
  nuovo_ws w || return 0
  printf 'un piano del docente\n' > "${TMP}/casa/.claude/plans/mio.md"
  finto "${w}" FINTO_PIANO_PERCORSO="${TMP}/casa/.claude/plans/mio.md"
  expect "live: un piano che c'era già prima resta" 0 \
    "c'era già prima della demo"
  vero "live: e il file c'è ancora" \
    test -f "${TMP}/casa/.claude/plans/mio.md"
}

# I dinieghi sono dati: una chiamata negata fuori dall'elenco
# permission_denials, o con il messaggio permission_denied, si stampa e
# non cambia l'uscita, che decidono le tre garanzie.
t_live_dinieghi() {
  local w
  nuovo_ws w || { fail "live: nessuno spazio di lavoro"; return 0; }
  finto "${w}" FINTO_DENY_SENZA_ELENCO=1
  expect "live: il diniego della regola fuori dall'elenco, uscita 0" 0 \
    "$(dinieghi "${NEGATA_DENY}" no no)"
  expect "live: fuori dall'elenco, le tre garanzie confermate" 0 "${TUTTE}"
  expect_absent "live: fuori dall'elenco, nessun «non confermata»" \
    "${NONCONF}"
  nuovo_ws w || return 0
  finto "${w}" FINTO_HOOK_SENZA_ELENCO=1
  expect "live: il diniego dell'hook fuori dall'elenco, uscita 0" 0 \
    "$(dinieghi "${NEGATA_HOOK}" no no)"
  expect "live: e la prova dei partecipanti" 0 \
    "VERIFICA OK   la prova dei partecipanti"
  nuovo_ws w || return 0
  finto "${w}" FINTO_MESSAGGIO_DINIEGO=1
  expect "live: il messaggio permission_denied, un dato (0)" 0 \
    "$(dinieghi "${NEGATA_DENY}" sì sì)"
  expect "live: il messaggio permission_denied dell'hook (0)" 0 \
    "$(dinieghi "${NEGATA_HOOK}" sì sì)"
  nuovo_ws w || return 0
  finto "${w}" FINTO_DENY_SENZA_ELENCO=1 FINTO_HOOK_IGNORA=1
  expect "live: l'hook ignorato e un diniego fuori dall'elenco (1)" 1 \
    "${S_HOOK}: ${NONCONF}"
  expect "live: l'uscita la decide la garanzia, non l'elenco" 1 \
    "${UN_ESITO_DIVERSO}"
}

# --- controlla_gradini.py ---------------------------------------------------

# Ritocca uno stream di uno spazio di lavoro copiato. Arguments: $1 lo
# stream, $2 l'azione: «modifica <percorso>» (una chiamata Edit riuscita
# su un file della copia, prima del risultato), «due_risultati» (il
# risultato due volte: i dinieghi solo nel primo), «u2028» (un U+2028
# vero dentro il testo di un risultato di uno strumento), «senza_elenco»
# (il risultato con l'elenco permission_denials vuoto), «elenco_estraneo»
# (nell'elenco anche una chiamata che lo stream non mostra),
# «altro_errore <testo>» (ogni risultato d'errore di uno strumento dice
# <testo> e l'elenco è vuoto: un tentativo fallito che non è un diniego),
# «testo_neutro» (ogni risultato d'errore dice un testo qualunque, e
# l'elenco resta).
ritocca() {
  python3 -B -I - "$@" <<'PY'
import json, os, sys
percorso, azione = sys.argv[1:3]
eventi = [json.loads(r) for r in open(percorso, encoding="utf-8")
          if r.strip()]
risultato = eventi.pop()
if azione == "modifica":
    cwd = next(e["cwd"] for e in eventi if e.get("subtype") == "init")
    file = os.path.join(cwd, sys.argv[3])
    eventi.append({"type": "assistant", "parent_tool_use_id": None,
                   "message": {"id": "msg_aggiunto", "content": [{
                       "type": "tool_use", "id": "toolu_aggiunto",
                       "name": "Edit", "input": {"file_path": file}}]}})
    eventi.append({"type": "user", "parent_tool_use_id": None,
                   "message": {"content": [{
                       "type": "tool_result", "tool_use_id": "toolu_aggiunto",
                       "content": "aggiornato (ritocco)"}]}})
    eventi.append(risultato)
elif azione == "due_risultati":
    ultimo = dict(risultato, permission_denials=[])
    eventi += [risultato, ultimo]
elif azione == "u2028":
    for evento in eventi:
        for blocco in (evento.get("message") or {}).get("content") or []:
            if blocco.get("type") == "tool_result":
                blocco["content"] = "prima dopo"
    eventi.append(risultato)
elif azione == "senza_elenco":
    eventi.append(dict(risultato, permission_denials=[]))
elif azione == "elenco_estraneo":
    cwd = next(e["cwd"] for e in eventi if e.get("subtype") == "init")
    voce = {"tool_name": "Read", "tool_use_id": "toolu_estraneo",
            "tool_input": {"file_path": os.path.join(cwd, "estraneo.txt")}}
    elenco = list(risultato.get("permission_denials") or []) + [voce]
    eventi.append(dict(risultato, permission_denials=elenco))
elif azione in ("altro_errore", "testo_neutro"):
    testo = sys.argv[3] if azione == "altro_errore" else "errore (ritocco)"
    for evento in eventi:
        for blocco in (evento.get("message") or {}).get("content") or []:
            if blocco.get("type") == "tool_result" and blocco.get("is_error"):
                blocco["content"] = testo
                if "tool_use_result" in evento:
                    evento["tool_use_result"] = "Error: " + testo
    if azione == "altro_errore":
        risultato = dict(risultato, permission_denials=[])
    eventi.append(risultato)
with open(percorso, "w", encoding="utf-8") as fh:
    for evento in eventi:
        fh.write(json.dumps(evento, ensure_ascii=False) + "\n")
PY
}

t_controllo() {
  local w
  if ! copia_buono w; then
    skip "controllo: nessuno spazio di lavoro buono da live.sh"
    return 0
  fi
  controlla "${w}"
  expect "controllo: lo spazio di lavoro di live.sh, uscita 0" 0 "${TUTTE}"
  expect "controllo: il piano scritto fuori dal progetto, come dato" 0 \
    "scritto fuori dal progetto:"
  expect "controllo: il diniego della regola, come dato" 0 \
    "$(dinieghi "${NEGATA_DENY}" sì no)"
  expect "controllo: il diniego dell'hook, come dato" 0 \
    "$(dinieghi "${NEGATA_HOOK}" sì no)"
  expect "controllo: la regola deny decisa in acceptEdits" 0 \
    "${S_DENY}: ${CONF}"
  expect_absent "controllo: nessun verdetto sull'elenco dei dinieghi" \
    "${ELENCO_VERDETTO}"
  expect "controllo: il file da cancellare c'è ancora con l'hook" 0 \
    "da_cancellare.txt c'è"
  expect "controllo: senza l'hook non c'è più" 0 \
    "da_cancellare.txt non c'è più"
  expect "controllo: la modifica senza plan mode" 0 "M ${FILE_PIANO}"
  expect_absent "controllo: nessun «non confermata»" "${NONCONF}"
  copia_buono w
  printf '// a mano\n' >> "${w}/gradini/piano-con/${FILE_PIANO}"
  controlla "${w}"
  expect "controllo: un file cambiato in plan mode (1)" 1 \
    "${S_PIANO}: ${NONCONF}"
  copia_buono w
  rm -f -- "${w}/gradini/hook-con/da_cancellare.txt"
  controlla "${w}"
  expect "controllo: il file cancellato nonostante l'hook (1)" 1 \
    "${S_HOOK}: ${NONCONF}"
  copia_buono w
  cp -- "${RADICE}/.claude/settings.json" \
    "${w}/gradini/deny-con/.claude/settings.json"
  controlla "${w}"
  expect "controllo: la coppia deny senza la regola nella copia con (1)" 1 \
    "non differisce soltanto nella regola"
  copia_buono w
  sed -i 's/"permissionMode": "plan"/"permissionMode": "acceptEdits"/' \
    "${w}/risposte/piano-con.jsonl"
  controlla "${w}"
  expect "controllo: la modalità sbagliata nell'avvio (1)" 1 \
    "attesa «plan»"
  copia_buono w
  ritocca "${w}/risposte/piano-con.jsonl" modifica "${FILE_PIANO}"
  controlla "${w}"
  expect "controllo: una modifica riuscita in plan mode, anche a git pulito" \
    1 "${S_PIANO}: ${NONCONF}"
  copia_buono w
  ritocca "${w}/risposte/deny-con.jsonl" modifica "${FILE_DATI}"
  controlla "${w}"
  expect "controllo: una modifica riuscita sui dati con la regola (1)" 1 \
    "${S_DENY}: ${NONCONF}"
  copia_buono w
  git -C "${w}/gradini/hook-senza" -c user.name=Prova \
    -c user.email=prova@example.org commit -q -am 'senza il file' || true
  controlla "${w}"
  expect "controllo: senza l'hook il file non risulta cancellato (1)" 1 \
    "${S_HOOK}: ${NONDIST}"
  copia_buono w
  ritocca "${w}/risposte/deny-con.jsonl" due_risultati
  controlla "${w}"
  expect "controllo: il diniego in un risultato prima dell'ultimo (0)" 0 \
    "$(dinieghi "${NEGATA_DENY}" sì no)"
  copia_buono w
  ritocca "${w}/risposte/deny-con.jsonl" senza_elenco
  controlla "${w}"
  expect "controllo: il diniego della regola fuori dall'elenco (0)" 0 \
    "$(dinieghi "${NEGATA_DENY}" no no)"
  expect "controllo: fuori dall'elenco, le tre garanzie confermate" 0 \
    "${TUTTE}"
  copia_buono w
  ritocca "${w}/risposte/hook-con.jsonl" senza_elenco
  controlla "${w}"
  expect "controllo: il diniego dell'hook fuori dall'elenco (0)" 0 \
    "$(dinieghi "${NEGATA_HOOK}" no no)"
  copia_buono w
  ritocca "${w}/risposte/piano-senza.jsonl" elenco_estraneo
  controlla "${w}"
  expect "controllo: una voce dell'elenco senza la sua chiamata, un dato" 0 \
    "$(dinieghi "Read estraneo.txt" sì no)"
  copia_buono w
  ritocca "${w}/risposte/deny-con.jsonl" altro_errore \
    "File has not been read yet. Read it first before writing to it."
  controlla "${w}"
  expect "controllo: con la regola una modifica fallita, non negata (1)" 1 \
    "${S_DENY}: ${NONDIST}"
  expect_absent "controllo: e non è un diniego fra i dati" \
    "dinieghi: ${NEGATA_DENY}"
  copia_buono w
  ritocca "${w}/risposte/hook-con.jsonl" altro_errore \
    "rm: cannot remove 'da_cancelare.txt': No such file or directory"
  controlla "${w}"
  expect "controllo: con l'hook un rm fallito, non bloccato (1)" 1 \
    "${S_HOOK}: ${NONDIST}"
  copia_buono w
  ritocca "${w}/risposte/deny-con.jsonl" testo_neutro
  controlla "${w}"
  expect "controllo: il diniego della regola, dall'elenco soltanto (0)" 0 \
    "${S_DENY}: ${CONF}"
  copia_buono w
  ritocca "${w}/risposte/hook-senza.jsonl" u2028
  controlla "${w}"
  expect "controllo: un U+2028 dentro uno stream si legge (0)" 0 "${TUTTE}"
  copia_buono w
  chmod 000 "${w}/gradini/deny-con/.claude/settings.json"
  controlla "${w}"
  expect "controllo: impostazioni che non si leggono (2)" 2 "non si legge"
  chmod 644 "${w}/gradini/deny-con/.claude/settings.json"
  copia_buono w
  sed -i 's#Edit(/progetti/#Edit(progetti/#' \
    "${w}/gradini/deny-con/.claude/settings.json"
  controlla "${w}"
  expect "controllo: la copia con la regola relativa di prima (1)" 1 \
    "non differisce soltanto nella regola"
  copia_buono w
  sed -i 's/"tools": \["Read", "Edit"\]/"tools": ["Read", "Edit", "Bash"]/' \
    "${w}/risposte/deny-senza.jsonl"
  controlla "${w}"
  expect "controllo: le due esecuzioni deny con strumenti diversi (1)" 1 \
    "non ha gli stessi strumenti"
}

# Gli stream e le copie rovinati: uscita 1, con il perché, senza
# traceback. Arguments: $1 il nome, $2 la parola, $3 il comando che
# rovina lo spazio di lavoro (riceve lo spazio di lavoro).
rovinato() {
  local w
  copia_buono w || { skip "$1"; return 0; }
  "$3" "${w}"
  controlla "${w}"
  expect "$1" 1 "$2"
  expect_absent "$1: nessun traceback" "Traceback"
}
senza_risposte() { rm -rf -- "$1/risposte"; }
senza_stream() { rm -f -- "$1/risposte/hook-senza.jsonl"; }
stream_vuoto() { : > "$1/risposte/deny-con.jsonl"; }
riga_non_json() { printf 'non json\n' >> "$1/risposte/deny-con.jsonl"; }
riga_lista() { printf '[1]\n' >> "$1/risposte/deny-con.jsonl"; }
senza_risultato() {
  python3 -B -I - "$1/risposte/deny-con.jsonl" <<'PY'
import sys
p = sys.argv[1]
righe = open(p, encoding="utf-8").read().splitlines()
open(p, "w", encoding="utf-8").write("\n".join(righe[:-1]) + "\n")
PY
}
con_errore() {
  sed -i 's/"is_error": false/"is_error": true/' "$1/risposte/deny-senza.jsonl"
}
con_sottotipo() {
  sed -i 's/"subtype": "success"/"subtype": "error_during_execution"/' \
    "$1/risposte/piano-con.jsonl"
}
senza_avvio() {
  sed -i '/"subtype": "init"/d' "$1/risposte/hook-con.jsonl"
}
senza_copia() { rm -rf -- "$1/gradini/deny-senza"; }
senza_git() { rm -rf -- "$1/gradini/piano-senza/.git"; }

t_rovinati() {
  rovinato "rovinati: risposte/ che manca" "Manca la cartella risposte/" \
    senza_risposte
  rovinato "rovinati: uno stream che manca" \
    "manca risposte/hook-senza.jsonl" senza_stream
  rovinato "rovinati: uno stream vuoto" "è vuoto" stream_vuoto
  rovinato "rovinati: una riga non JSON" "non è JSON" riga_non_json
  rovinato "rovinati: una riga che non è un oggetto" \
    "non è un oggetto JSON" riga_lista
  rovinato "rovinati: senza il risultato in fondo" \
    "lo stream non finisce con il risultato" senza_risultato
  rovinato "rovinati: is_error" "claude ha restituito un errore" con_errore
  rovinato "rovinati: un subtype d'errore" "claude ha restituito un errore" \
    con_sottotipo
  rovinato "rovinati: senza l'evento di avvio" "manca l'evento di avvio" \
    senza_avvio
  rovinato "rovinati: una copia che manca" "manca la copia gradini/deny-senza" \
    senza_copia
  rovinato "rovinati: una copia senza git" "non è un repository git" senza_git
}

# Le precondizioni del controllo: uscita 2, senza traceback; --piani.
t_controllo_precondizioni() {
  local w
  controlla "${TMP}/assente"
  expect "controllo: spazio di lavoro assente (2)" 2 "spazio di lavoro assente"
  run python3 -B -I "${D04}/demo/controlla_gradini.py" --boh
  expect "controllo: un'opzione sconosciuta (2)" 2 "Uso:"
  run python3 -B -I "${D04}/demo/controlla_gradini.py" a b
  expect "controllo: due spazi di lavoro (2)" 2 "Uso:"
  copia_buono w || { skip "controllo: precondizioni"; return 0; }
  run env PATH="${TMP}/senza_git" "$(command -v python3)" -B -I \
    "${D04}/demo/controlla_gradini.py" "${w}"
  expect "controllo: git che manca (2)" 2 "manca git"
  run python3 -B -I -c 'import importlib.util, sys
spec = importlib.util.spec_from_file_location("controllo", sys.argv[1])
modulo = importlib.util.module_from_spec(spec)
spec.loader.exec_module(modulo)
def guasto(*_):
    raise RuntimeError("guasto finto")
modulo.controlla = guasto
sys.exit(modulo.main(sys.argv[2:]))' "${D04}/demo/controlla_gradini.py" "${w}"
  expect "controllo: un errore inatteso (2)" 2 "errore inatteso"
  expect_absent "controllo: senza traceback" "Traceback"
  run python3 -B -I "${D04}/demo/controlla_gradini.py" --piani "${w}"
  expect "controllo: --piani stampa il piano del plan mode" 0 \
    "${TMP}/casa/.claude/plans/piano-finto-"
  rm -f -- "${w}/risposte/piano-con.jsonl"
  run python3 -B -I "${D04}/demo/controlla_gradini.py" --piani "${w}"
  expect "controllo: --piani senza lo stream del piano (1)" 1 \
    "manca risposte/piano-con.jsonl"
}

# Gli script di M4-D04, la sua libreria e questo file, con shellcheck -x.
t_shellcheck() {
  local f
  for f in "${D04}/verifica.sh" "${D04}/_docente/live.sh" \
      "${D04}/_docente/lib_gradini.sh" "${SELF}"; do
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
    command -v "${t}" >/dev/null 2>&1 \
      || { echo "test_m4_d04: manca ${t}" >&2; exit 2; }
  done
  [[ -f "${FINTO_PY}" ]] \
    || { echo "test_m4_d04: manca ${FINTO_PY}" >&2; exit 2; }
  handson::init_temp_base
  TMP="$(mktemp -d "${HANDSON_TEMP_BASE}/test_m4_d04.XXXXXX")" || exit 2
  trap 'chmod -R u+rwX "${TMP}" 2>/dev/null; rm -rf "${TMP}"' EXIT
  prepara_claude
  t_elemento
  t_impostazioni
  t_readme
  t_hook
  t_prepara
  t_verifica
  t_verifica_precondizioni
  t_run_all
  t_live_precondizioni
  t_live_finto
  t_live_esiti
  t_live_dinieghi
  t_controllo
  t_rovinati
  t_controllo_precondizioni
  t_shellcheck
  OUT="${TUTTO}"
  expect_absent "in nessuna uscita «smentita»" "smentita"
  echo "PASS=${PASS} FAIL=${FAIL} SKIP=${SKIP}"
  if (( PASS + FAIL + SKIP != CASES )); then
    echo "test_m4_d04: girati $((PASS + FAIL + SKIP)) casi, attesi" \
      "${CASES}" >&2
    exit 2
  fi
  (( FAIL == 0 )) || exit 1
}

main "$@"
