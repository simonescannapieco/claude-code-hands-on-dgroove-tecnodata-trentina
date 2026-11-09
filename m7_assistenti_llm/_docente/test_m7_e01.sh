#!/bin/bash
#
# test_m7_e01.sh -- le prove di M7-E01 «Il banco di prova», per il docente:
#   - l'elemento: i file, progetti.txt, il modello di note.md senza voci, il
#     README con le dieci sezioni, le frasi di Anthropic con il loro indirizzo,
#     i tre scenari che esistono, i due prompt; niente identificativi interni,
#     «smentita» o riferimenti alla giornata;
#   - prepara_esercizio.sh e verifica.sh sul punto di partenza (1);
#   - verifica.py su conversazioni scritte qui: ogni esito (0), ogni cosa che
#     manca (1), ogni file che non si legge (2), mai un traceback;
#   - _docente/live.sh con il claude finto: la conversazione sul banco, la
#     lettura e le note in claude -p, le opzioni, il prompt del README, senza
#     ANTHROPIC_API_KEY; le precondizioni (2, nessuna chiamata al modello:
#     l'esca); una chiamata fallita (1);
#   - shellcheck -x sugli script e su questo file.
# Mai il claude vero: il finto e l'esca stanno davanti nel PATH, e la suite lo
# controlla prima di usarli. Gli spazi di lavoro nascono in una cartella
# temporanea: l'albero del repository non cambia. CASES è il numero dei casi:
# se ne girano di più o di meno la suite esce 2.
#
# Uso:    m7_assistenti_llm/_docente/test_m7_e01.sh
# Uscita: 0 = tutti i casi passano · 1 = almeno un caso fallito · 2 =
#         precondizione (manca python3, git, jq o shellcheck), o un numero di
#         casi diverso da CASES
set -uo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly MOD="${SELF%/_docente/*}"
readonly RADICE="${MOD%/*}"
readonly SUB="s5_anatomia_e_strumenti/m7_e1_banco_di_prova"
readonly E01="${MOD}/${SUB}/M7-E01_banco_di_prova"
readonly FINTO_PY="${MOD}/_docente/claude_finto_m7_e01.py"
# La libreria del repository, per la base dei file temporanei.
# shellcheck source=../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"
readonly CASES=95
readonly FATTO="Fatto: la conversazione c'è e le note citano"
TMP=''
PASS=0
FAIL=0
RC=0
OUT=''
TUTTO=''

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

# Esegue un comando; RC e OUT (STDOUT e STDERR insieme); OUT si aggiunge a
# TUTTO, dove alla fine non devono esserci «smentita» né traceback.
run() { OUT="$("$@" 2>&1)"; RC=$?; TUTTO+="${OUT}"$'\n'; }

# Uscita attesa E parola chiave attesa (RU-01.T3).
expect() {
  if (( RC == $2 )) && grep -qF -- "$3" <<< "${OUT}"; then
    pass "$1"
  else
    fail "$1 (rc=${RC}, attesa $2, parola «$3»): ${OUT:0:700}"
  fi
}

# Nessun falso positivo: la parola NON c'è (RU-01.T5).
expect_absent() {
  if grep -qF -- "$2" <<< "${OUT}"; then
    fail "$1: «$2» c'è: ${OUT:0:400}"
  else
    pass "$1"
  fi
}

vero() {
  local nome="$1"
  shift
  if "$@"; then pass "${nome}"; else fail "${nome}"; fi
}

# Uno spazio di lavoro nuovo in una radice nuova. Arguments: $1 la variabile.
nuovo_ws() {
  local __r
  __r="$(mktemp -d "${TMP}/radice.XXXXXX")" || exit 2
  "${RADICE}/tools/prepara_esercizio.sh" M7-E01 --radice "${__r}" \
    > "${TMP}/prepara.log" 2>&1 || return 1
  printf -v "$1" '%s' "${__r}/M7-E01"
}

# Il claude finto (uno script che legge i suoi modi da un file, perché prova.py
# ripulisce l'ambiente), uv finto, l'esca e i PATH ridotti.
prepara_finti() {
  local t
  mkdir -p "${TMP}/finto" "${TMP}/esca" "${TMP}/senza_uv" \
    "${TMP}/senza_claude" "${TMP}/senza_jq" || exit 2
  cat > "${TMP}/finto/claude" <<WRAP || exit 2
#!/bin/bash
if [[ -f "${TMP}/modo" ]]; then set -a; source "${TMP}/modo"; set +a; fi
export FINTO_LOG="${TMP}/finto.log"
exec python3 -B -I "${FINTO_PY}" "\$@"
WRAP
  # shellcheck disable=SC2016  # il corpo è di uv finto
  printf '%s\n' '#!/bin/bash' 'exit 0' > "${TMP}/finto/uv" || exit 2
  # shellcheck disable=SC2016  # il corpo è dell'esca
  printf '%s\n' '#!/bin/bash' \
    'printf "invocazione %s\n" "$*" >> "${ESCA_LOG}"' \
    > "${TMP}/esca/claude" || exit 2
  printf '%s\n' '#!/bin/bash' 'exit 0' > "${TMP}/esca/uv" || exit 2
  chmod 755 "${TMP}/finto/claude" "${TMP}/finto/uv" "${TMP}/esca/claude" \
    "${TMP}/esca/uv" || exit 2
  for t in readlink python3 git jq mktemp cat dirname mkdir rm sed; do
    ln -s "$(command -v "${t}")" "${TMP}/senza_uv/${t}" || exit 2
    ln -s "$(command -v "${t}")" "${TMP}/senza_claude/${t}" || exit 2
  done
  ln -s "${TMP}/esca/claude" "${TMP}/senza_uv/claude" || exit 2
  ln -s "${TMP}/esca/uv" "${TMP}/senza_claude/uv" || exit 2
  for t in readlink python3 git mktemp cat dirname mkdir rm sed; do
    ln -s "$(command -v "${t}")" "${TMP}/senza_jq/${t}" || exit 2
  done
  ln -s "${TMP}/esca/claude" "${TMP}/senza_jq/claude" || exit 2
  ln -s "${TMP}/esca/uv" "${TMP}/senza_jq/uv" || exit 2
  t="$(PATH="${TMP}/finto:${PATH}" command -v claude)"
  if [[ "${t}" != "${TMP}/finto/claude" ]]; then
    echo "test_m7_e01: nel PATH di prova claude è ${t}, non il finto" >&2
    exit 2
  fi
}

# Scrive il modo del finto. Arguments: gli assegnamenti NOME=valore.
modo() {
  : > "${TMP}/modo"
  local v
  for v in "$@"; do printf '%q\n' "${v}" >> "${TMP}/modo"; done
}

# Lo script con il finto davanti nel PATH e la chiave nell'ambiente (lo script
# la deve togliere). Arguments: $1 lo script, $2 lo spazio di lavoro, poi le
# variabili NOME=valore.
finto() {
  local script="$1" w="$2"
  shift 2
  : > "${TMP}/finto.log"
  run env PATH="${TMP}/finto:${PATH}" HANDSON_NO_PAUSE=1 \
    ANTHROPIC_API_KEY=valore-finto CLAUDE_CODE_EFFORT_LEVEL=high \
    TMPDIR="${TMP}" "$@" "${script}" "${w}"
}

# Lo script con l'esca davanti nel PATH (o un PATH dato). Arguments: $1 lo
# script, $2 lo spazio di lavoro, $3 il PATH (facoltativo), poi NOME=valore.
esca() {
  local script="$1" w="$2" percorso="${3:-${TMP}/esca:${PATH}}"
  shift 2
  (( $# == 0 )) || shift
  : > "${TMP}/esca.log"
  run env PATH="${percorso}" HANDSON_NO_PAUSE=1 ESCA_LOG="${TMP}/esca.log" \
    "$@" "${script}" "${w}"
}

# Una precondizione: uscita 2, la parola attesa, nessuna chiamata al modello.
precondizione() {
  local nome="$1" parola="$2" n
  shift 2
  esca "$@"
  expect "${nome}" 2 "${parola}"
  n="$(grep -c -v -- '--version' "${TMP}/esca.log")"
  if (( n == 0 )); then
    pass "${nome}: nessuna chiamata al modello"
  else
    fail "${nome}: ${n} chiamate: $(head -n 2 "${TMP}/esca.log")"
  fi
}

# Scrive una conversazione finta nello spazio di lavoro.
# Arguments: $1 lo spazio di lavoro, $2 i turni come «ruolo|testo|strumento;»…
conversazione() {
  local ws="$1" turni="$2"
  mkdir -p "${ws}/conversazione" || exit 2
  python3 -B -I - "${ws}/conversazione" "${turni}" <<'PY' || exit 2
import json, os, sys
cartella, turni = sys.argv[1:3]
msgs, reg = [], []
for pezzo in filter(None, turni.split(";")):
    ruolo, testo, strumento = pezzo.split("|")
    m = {"ruolo": ruolo, "testo": testo}
    if strumento:
        azione = {"strumento": strumento, "capacita": strumento + "_c",
                  "argomenti": {}, "risultato": {}}
        m["azioni"] = [azione]
        reg.append({"n": len(reg) + 1, "strumento": strumento,
                    "capacita": strumento + "_c", "argomenti": {},
                    "risultato": {}, "errore": False})
    msgs.append(m)
d = {"id": "prova-SC-16", "scenario": "SC-16", "versione": "v0", "turni": msgs}
json.dump(d, open(os.path.join(cartella, "conversazione.json"), "w"))
open(os.path.join(cartella, "trascrizione.md"), "w").write("# trascrizione\n")
if reg:
    with open(os.path.join(cartella, "registro.jsonl"), "w") as fh:
        for r in reg:
            fh.write(json.dumps(r) + "\n")
PY
}

# Le righe delle note. Arguments: $1 lo spazio di lavoro, poi le voci.
note() {
  local ws="$1" v
  shift
  printf '# note\n' > "${ws}/note.md" || exit 2
  for v in "$@"; do printf '%s\n' "${v}" >> "${ws}/note.md"; done
}

verifica() { run "${E01}/verifica.sh" "$@"; }

# Le chiamate del finto, contro le attese.
controlla_chiamate() {
  run python3 -B -I - "$1" "$2" <<'PY'
import json, sys, textwrap
log, item = sys.argv[1:3]
righe = [json.loads(r) for r in open(log, encoding="utf-8")]
readme = open(item + "/README.md", encoding="utf-8").read().split("\n")
def prompt(n):
    a = readme.index("   <!-- prompt %d -->" % n)
    b = readme.index("   <!-- /prompt %d -->" % n)
    return textwrap.dedent("\n".join(readme[a + 1:b])).strip("\n")
chiamate = [c for c in righe if c["argv"] != ["--version"]]
def opt(argv, nome):
    return argv[argv.index(nome) + 1] if nome in argv else None
problemi = []
assistenti = [c for c in chiamate if "--mcp-config" in c["argv"]]
persone = [c for c in chiamate if opt(c["argv"], "--agent") == "cliente"]
letture = [c for c in chiamate if "--mcp-config" not in c["argv"]
           and opt(c["argv"], "--agent") is None]
if not assistenti or not persone or len(letture) != 2:
    problemi.append("chiamate: %d %d %d" % (len(assistenti), len(persone),
                                            len(letture)))
for c in assistenti + persone:
    a = c["argv"]
    if opt(a, "--model") != ("haiku" if c in persone else "sonnet"):
        problemi.append("modello %s" % opt(a, "--model"))
    if opt(a, "--effort") != "low" or opt(a, "--permission-mode") != "dontAsk" \
            or opt(a, "--permission-prompts") != "none" \
            or opt(a, "--setting-sources") != "project,local":
        problemi.append("opzioni del banco: %s" % a[:12])
for c in assistenti:
    a = c["argv"]
    if opt(a, "--tools") != "" or opt(a, "--allowedTools") != "mcp__assistenza__*" \
            or "--strict-mcp-config" not in a:
        problemi.append("opzioni dell'assistente: %s" % a)
if letture:
    uno, due = letture[0], letture[-1]
    for c, attesi, numero in ((uno, "Read,Glob,Grep", 1),
                              (due, "Read,Glob,Grep,Write", 2)):
        a = c["argv"]
        if opt(a, "--allowedTools") != attesi or opt(a, "--tools") != attesi:
            problemi.append("lettura %d: strumenti %s" % (numero, a))
        if opt(a, "--model") != "sonnet" or opt(a, "--effort") != "low" \
                or opt(a, "--permission-mode") != "dontAsk" \
                or opt(a, "--permission-prompts") != "none" \
                or opt(a, "--output-format") != "json" \
                or "--strict-mcp-config" not in a:
            problemi.append("lettura %d: opzioni %s" % (numero, a))
        if a[a.index("--") + 1:] != [prompt(numero)]:
            problemi.append("lettura %d: il prompt non è quello del README"
                            % numero)
    if opt(due["argv"], "--resume") != "sessione-finta-e01":
        problemi.append("--resume assente o sbagliato")
for c in chiamate:
    if c["chiave"] or c["effort"]:
        problemi.append("con ANTHROPIC_API_KEY o CLAUDE_CODE_EFFORT_LEVEL")
    if any("dangerously" in x or "bypassPermissions" in x for x in c["argv"]):
        problemi.append("salta i permessi")
print("; ".join(sorted(set(problemi))) or "chiamate giuste")
PY
}

# --- L'elemento -------------------------------------------------------------

t_elemento() {
  local f
  for f in README.md verifica.sh verifica.py progetti.txt esercizio/note.md \
      _docente/live.sh soluzione/LEGGIMI.md; do
    vero "elemento: ${f}" test -f "${E01}/${f}"
  done
  for f in verifica.sh _docente/live.sh; do
    vero "elemento: ${f} eseguibile" test -x "${E01}/${f}"
  done
  run cat "${E01}/progetti.txt"
  expect "progetti.txt: il progetto dell'assistenza" 0 \
    "progetti/assistenza-clienti"
  run python3 -B -I - "${E01}/esercizio/note.md" <<'PY'
import re, sys
righe = open(sys.argv[1], encoding="utf-8").read().splitlines()
voci = [r for r in righe if re.match(r"^\s*(?:[-*+]|\d+[.)])\s+\S", r)]
print("nessuna voce" if not voci else "voci: %r" % voci)
PY
  expect "note.md di partenza: nessuna voce" 0 "nessuna voce"
  run python3 -B -I - "${MOD}/_docente" <<'PY'
import os, sys
c = sys.argv[1]
print("ok" if os.access(os.path.join(c, "test_m7_e01.sh"), os.X_OK)
      else "test non eseguibile")
PY
  expect "la suite è eseguibile" 0 "ok"
}

t_readme() {
  run python3 -B -I - "${E01}" "${RADICE}" <<'PY'
import os, re, sys
item, radice = sys.argv[1:3]
readme = open(os.path.join(item, "README.md"), encoding="utf-8").read()
problemi = []
sezioni = ("Obiettivo", "Tempo", "Prerequisiti", "Punto di partenza",
           "Passi in Claude Code", "Che cosa osservare", "Verifica",
           "Se qualcosa va storto", "Impronta d'uso sul piano Pro",
           "Per approfondire")
titoli = [r[3:] for r in readme.splitlines() if r.startswith("## ")]
if [next((s for s in sezioni if t.startswith(s)), "") for t in titoli] \
        != list(sezioni):
    problemi.append("le dieci sezioni, in ordine: %s" % titoli)
for titolo in ("## Punto di partenza (tools/prepara_esercizio.sh M7-E01)",
               "## Verifica (tools/verifica.sh M7-E01)"):
    if titolo not in readme:
        problemi.append("il titolo «%s»" % titolo)
CA = "https://claude.com/resources/articles/" \
    "the-anatomy-of-effective-commerce-agents"
EV = "https://www.anthropic.com/research/demystifying-evals-for-ai-agents"
frasi = [
    ("Simulated-user evals, in which a second model plays the user and a "
     "judge grades the whole conversation, are a poor tool for measurement.",
     CA),
    ("useful for finding coverage gaps … so use them to discover cases, then "
     "write each case as a snapshot.", CA),
    ("A transcript (also called a trace or trajectory) is the complete "
     "record of a trial, including outputs, tool calls, reasoning, "
     "intermediate results", EV),
    ("You won't know if your graders are working well unless you read the "
     "transcripts and grades from many trials.", EV),
    ("In an interactive session, Claude Code shows the workspace trust "
     "dialog when you start it in a folder you haven’t trusted.",
     "https://code.claude.com/docs/en/security"),
    ("Pro, Max, Ultra, Team, Enterprise, and Anthropic API: defaults to Opus "
     "5.5", "https://code.claude.com/docs/en/model-config"),
    ("When you continue an earlier conversation with --continue or --resume, "
     "the run reports the conversation's whole total, earlier runs' spend "
     "included.", "https://code.claude.com/docs/en/headless")]
piano = " ".join(readme.split())
for frase, url in frasi:
    if " ".join(frase.split()) not in piano:
        problemi.append("manca «%s»" % frase[:50])
    if url not in readme:
        problemi.append("manca %s" % url)
for scenario in re.findall(r"`(sc-\d+-[a-z-]+\.json)`", readme):
    if not os.path.isfile(os.path.join(radice, "progetti", "assistenza-clienti",
                                       "scenari", scenario)):
        problemi.append("lo scenario %s non esiste" % scenario)
if len(set(re.findall(r"`(sc-\d+-[a-z-]+\.json)`", readme))) != 3:
    problemi.append("gli scenari non sono tre")
for n in (1, 2):
    m = re.search(r"<!-- prompt %d -->\n(.*?)<!-- /prompt %d -->" % (n, n),
                  readme, re.S)
    if not m:
        problemi.append("manca il prompt %d" % n)
    elif len(m.group(1).split()) >= 60:
        problemi.append("il prompt %d è troppo lungo per restare semplice" % n)
    elif re.search(r"^\s*<(role|context|instructions)>", m.group(1), re.M):
        problemi.append("il prompt %d ha i tag" % n)
for parola in ("trascrizione.md", "registro.jsonl", "conversazione", "note.md"):
    if parola not in readme:
        problemi.append("manca %s" % parola)
for vietata in ("smentit", "FACT-", "M7-X", "X-3", "X-4", " oggi", "domani",
                "pausa", "pranzo", "/home/", "debolezze"):
    if vietata in readme:
        problemi.append("«%s»" % vietata)
print("; ".join(problemi) or "README a posto")
PY
  expect "README: sezioni, frasi con l'indirizzo, scenari, prompt, niente di vietato" \
    0 "README a posto"
}

t_prepara() {
  local ws f
  if ! nuovo_ws ws; then
    fail "prepara_esercizio.sh M7-E01: $(tail -n 3 "${TMP}/prepara.log")"
    return
  fi
  pass "prepara_esercizio.sh M7-E01"
  for f in note.md .claude/settings.json \
      progetti/assistenza-clienti/v0/system-prompt.md \
      progetti/assistenza-clienti/banco/prova.py \
      progetti/assistenza-clienti/scenari/sc-16-rimborso-e-password.json; do
    vero "spazio di lavoro: ${f}" test -f "${ws}/${f}"
  done
  if [[ ! -e "${ws}/soluzione" && ! -e "${ws}/_docente" \
      && ! -e "${ws}/progetti/assistenza-clienti/_docente" ]]; then
    pass "spazio di lavoro: niente soluzione/ né _docente/"
  else
    fail "spazio di lavoro: soluzione/ o _docente/"
  fi
  run "${RADICE}/tools/verifica.sh" M7-E01 --radice "${ws%/M7-E01}"
  expect "verifica.sh sul punto di partenza: 1" 1 "Manca la conversazione"
}

# La soluzione: copiata su uno spazio di lavoro nuovo, fa passare la verifica;
# niente percorsi personali.
t_soluzione() {
  local ws
  nuovo_ws ws || { fail "soluzione: prepara_esercizio.sh"; return; }
  cp -R "${E01}/soluzione/." "${ws}/" || exit 2
  run "${RADICE}/tools/verifica.sh" M7-E01 --radice "${ws%/M7-E01}"
  expect "soluzione: applicata, la verifica passa" 0 "VERIFICA OK   M7-E01: fatto."
  run grep -rlE "/home/|/Users/|/tmp/m7live" "${E01}/soluzione"
  if (( RC == 1 )); then
    pass "soluzione: nessun percorso personale"
  else
    fail "soluzione: percorsi personali in: ${OUT}"
  fi
  vero "soluzione: la trascrizione del corso" \
    test -s "${E01}/soluzione/conversazione/trascrizione.md"
  vero "soluzione: lo stream non c'è" \
    test ! -e "${E01}/soluzione/conversazione/stream.jsonl"
}

# --- La verifica ------------------------------------------------------------

t_verifica() {
  local ws
  nuovo_ws ws || { fail "verifica: prepara_esercizio.sh"; return; }
  verifica "${ws}"
  expect "verifica: senza conversazione, 1" 1 "Manca la conversazione"
  conversazione "${ws}" \
    "cliente|Buongiorno|;assistente|Vedo la linea|cercaCliente;cliente|Grazie|;assistente|Passo all'operatore|operatore"
  rm -f -- "${ws}/note.md"
  verifica "${ws}"
  expect "verifica: note.md che manca, 1" 1 "Manca note.md"
  printf '# note\nsolo una riga\n' > "${ws}/note.md" || exit 2
  verifica "${ws}"
  expect "verifica: note.md senza voci, 1" 1 "0 voci con un turno"
  note "${ws}" "- turno 2: chiede troppi dati" \
    "- turno 4: promette senza verificare" \
    "- lo strumento cercaCliente legge la scheda intera"
  verifica "${ws}"
  expect "verifica: tre voci con il riferimento, 0" 0 "${FATTO}"
  expect "verifica: la voce con un turno" 0 "voce 1: cita turno 2 (assistente)"
  expect "verifica: la voce con uno strumento" 0 \
    "voce 3: cita lo strumento cercaCliente"
  expect "verifica: conteggio dati, le chiamate" 0 \
    "(dato) le chiamate agli strumenti nel registro: 2"
  expect "verifica: i messaggi e i giri, come dato" 0 \
    "4 messaggi, 2 giri"
  note "${ws}" "- turno 2: uno" "- turno 4: due"
  verifica "${ws}"
  expect "verifica: due voci, 1" 1 "2 voci con un turno"
  note "${ws}" "- turno 2: uno"
  verifica "${ws}"
  expect "verifica: una voce sola, al singolare, 1" 1 "1 voce con un turno"
  expect_absent "verifica: mai «1 voci»" "1 voci"
  note "${ws}" "- turno 2: uno" "- turno 4: due" "- turno 99: tre"
  verifica "${ws}"
  expect "verifica: un turno che non esiste non conta, 1" 1 "che non c'è"
  note "${ws}" "- turno 2: uno" "- turno 4: due" "- una voce senza niente"
  verifica "${ws}"
  expect "verifica: una voce senza riferimento non conta, 1" 1 \
    "nessun turno né strumento citato"
  note "${ws}" "  * turno 2: uno" "  1. turno 4: due" "- OPERATORE: la chiamata"
  verifica "${ws}"
  expect "verifica: elenchi con altri segni e maiuscole, 0" 0 "${FATTO}"
  note "${ws}" "<!-- - turno 2: nel commento -->" "- turno 2: uno" \
    "- turno 4: due"
  verifica "${ws}"
  expect "verifica: le voci nei commenti HTML non contano, 1" 1 \
    "2 voci con un turno"
  # shellcheck disable=SC2016  # gli apici inversi sono il testo della voce
  note "${ws}" "- turno 2: uno" "- turno 4: due" \
    '- `kb_search`: strumento del v0, mai chiamato qui'
  verifica "${ws}"
  expect "verifica: uno strumento del v0 mai chiamato conta, 0" 0 "${FATTO}"
  note "${ws}" "- turno 2: uno" "- turno 4: due" \
    "- turno 2 e turno 4: la stessa cosa"
  verifica "${ws}"
  expect "verifica: voci diverse sullo stesso turno, 0" 0 "${FATTO}"
  note "${ws}" "- turno 2: uno"
  rm -- "${ws}/conversazione/trascrizione.md"
  verifica "${ws}"
  expect "verifica: senza trascrizione, 1" 1 "Manca conversazione/trascrizione.md"
  conversazione "${ws}" "cliente|Buongiorno|"
  note "${ws}" "- turno 1: uno" "- turno 1: due" "- turno 1: tre"
  verifica "${ws}"
  expect "verifica: nessuna risposta dell'assistente, 1" 1 \
    "nessuna risposta dell'assistente"
  conversazione "${ws}" \
    "cliente|Buongiorno|;assistente|Ecco|;cliente|Grazie|;assistente|Prego|"
  rm -f -- "${ws}/conversazione/registro.jsonl"
  note "${ws}" "- turno 1: uno" "- turno 2: due" "- turno 3: tre"
  verifica "${ws}"
  expect "verifica: niente chiamate e niente registro, 0" 0 "${FATTO}"
  expect "verifica: niente registro, come dato" 0 "(dato) nessuna chiamata"
  conversazione "${ws}" \
    "cliente|Buongiorno|;assistente|Ecco|cercaCliente;cliente|Grazie|;assistente|Prego|"
  rm -f -- "${ws}/conversazione/registro.jsonl"
  verifica "${ws}"
  expect "verifica: chiamate senza registro, 1" 1 "Manca conversazione/registro"
  printf '{rotto\n' > "${ws}/conversazione/registro.jsonl" || exit 2
  verifica "${ws}"
  expect "verifica: una riga del registro che non è JSON, 2" 2 "non è JSON"
  printf '{"turni": []}\n' > "${ws}/conversazione/conversazione.json" || exit 2
  verifica "${ws}"
  expect "verifica: una conversazione senza messaggi, 1" 1 \
    "nessuna risposta dell'assistente"
  printf 'non è JSON\n' > "${ws}/conversazione/conversazione.json" || exit 2
  verifica "${ws}"
  expect "verifica: una conversazione che non si legge, 2" 2 "non si legge"
  printf '{"x": 1}\n' > "${ws}/conversazione/conversazione.json" || exit 2
  verifica "${ws}"
  expect "verifica: un JSON senza turni, 2" 2 "non è una conversazione"
  verifica "${TMP}/non-c-e"
  expect "verifica: uno spazio di lavoro che manca, 2" 2 \
    "spazio di lavoro assente"
  run python3 -B -I "${E01}/verifica.py"
  expect "verifica.py: senza argomenti, 2" 2 "Uso:"
  run "${RADICE}/tools/verifica.sh" M7-E01 --radice "${ws%/M7-E01}"
  expect "verifica: tools/verifica.sh riporta l'uscita" 2 \
    "non è una conversazione"
}

# --- live.sh ----------------------------------------------------------------

t_live() {
  local ws
  nuovo_ws ws || { fail "live: prepara_esercizio.sh"; return; }
  modo FINTO_GIRI=2
  finto "${E01}/_docente/live.sh" "${ws}"
  expect "live: 0" 0 "VERIFICA OK   la conversazione e le note"
  expect "live: i dati della verifica sullo schermo" 0 "${FATTO}"
  expect "live: il comando del banco sullo schermo" 0 "prova_assistente.sh"
  controlla_chiamate "${TMP}/finto.log" "${E01}"
  expect "live: banco, persona, lettura e note, con le opzioni giuste" 0 \
    "chiamate giuste"
  vero "live: la conversazione nello spazio di lavoro" \
    test -s "${ws}/conversazione/trascrizione.md"
  vero "live: il registro" test -s "${ws}/conversazione/registro.jsonl"
  vero "live: note.md" test -s "${ws}/note.md"
  vero "live: il JSON della lettura" test -s "${ws}/sessione-live/passo-2.json"
  vero "live: il JSON delle note" test -s "${ws}/sessione-live/passo-3.json"
  run "${RADICE}/tools/verifica.sh" M7-E01 --radice "${ws%/M7-E01}"
  expect "live: poi tools/verifica.sh, 0" 0 "VERIFICA OK   M7-E01: fatto."
  nuovo_ws ws || { fail "live: prepara_esercizio.sh"; return; }
  modo FINTO_GIRI=4
  finto "${E01}/_docente/live.sh" "${ws}"
  expect "live: quattro giri al massimo, 0" 0 "VERIFICA OK"
  run python3 -B -I -c 'import json, sys
d = json.load(open(sys.argv[1]))
print("ok %d" % len(d["turni"]) if len(d["turni"]) == 8 else "turni: %d" % len(d["turni"]))' \
    "${ws}/conversazione/conversazione.json"
  expect "live: al massimo quattro giri, otto messaggi" 0 "ok 8"
  run "${E01}/_docente/live.sh"
  expect "live: senza argomenti, 2" 2 "uso:"
}

t_fallita() {
  local ws
  nuovo_ws ws || { fail "fallita: prepara_esercizio.sh"; return; }
  modo FINTO_ERRORE=1
  finto "${E01}/_docente/live.sh" "${ws}"
  expect "fallita: l'assistente con un errore, 1" 1 \
    "la conversazione non è finita"
  nuovo_ws ws || { fail "fallita: prepara_esercizio.sh"; return; }
  modo FINTO_SERVER_KO=1
  finto "${E01}/_docente/live.sh" "${ws}"
  expect "fallita: il server MCP che non parte, 1" 1 \
    "la conversazione non è finita"
  expect "fallita: il motivo del server, sullo schermo" 1 "non si è collegato"
  nuovo_ws ws || { fail "fallita: prepara_esercizio.sh"; return; }
  modo "FINTO_KO_SE=Leggi conversazione"
  finto "${E01}/_docente/live.sh" "${ws}"
  expect "fallita: la lettura che fallisce, 1" 1 "passo 2"
  vero "fallita: la conversazione resta" \
    test -s "${ws}/conversazione/conversazione.json"
  nuovo_ws ws || { fail "fallita: prepara_esercizio.sh"; return; }
  modo FINTO_NOTE=2
  finto "${E01}/_docente/live.sh" "${ws}"
  expect "fallita: Claude scrive due voci sole: verifica 1" 1 "VERIFICA KO"
  nuovo_ws ws || { fail "fallita: prepara_esercizio.sh"; return; }
  modo FINTO_NOTE_SENZA=1
  finto "${E01}/_docente/live.sh" "${ws}"
  expect "fallita: voci senza riferimento: verifica 1" 1 \
    "nessun turno né strumento citato"
  modo
}

t_precondizioni() {
  local ws s="${E01}/_docente/live.sh"
  nuovo_ws ws || { fail "precondizioni: prepara_esercizio.sh"; return; }
  precondizione "precondizione: una cartella che non è lo spazio" \
    "non è lo spazio di lavoro di M7-E01" "${s}" "${TMP}"
  precondizione "precondizione: nessuno spazio di lavoro" \
    "spazio di lavoro assente" "${s}" ""
  precondizione "precondizione: HANDSON_ENV sbagliato" \
    "è un elemento claude-code-pro" "${s}" "${ws}" "${TMP}/esca:${PATH}" \
    HANDSON_ENV=claude-ai-pro
  precondizione "precondizione: senza uv" "manca lo strumento: uv" \
    "${s}" "${ws}" "${TMP}/senza_uv"
  precondizione "precondizione: senza claude" "manca lo strumento: claude" \
    "${s}" "${ws}" "${TMP}/senza_claude"
  precondizione "precondizione: senza jq" "manca lo strumento: jq" \
    "${s}" "${ws}" "${TMP}/senza_jq"
  printf 'x\n' > "${ws}/estraneo.txt" || exit 2
  precondizione "precondizione: uno spazio di lavoro cambiato" \
    "non è al punto di partenza" "${s}" "${ws}"
  rm -f -- "${ws}/estraneo.txt"
  mv -- "${ws}/note.md" "${TMP}/note.md" || exit 2
  precondizione "precondizione: note.md che manca" \
    "non è al punto di partenza" "${s}" "${ws}"
  mv -- "${TMP}/note.md" "${ws}/note.md" || exit 2
}

t_shellcheck() {
  local f
  for f in "${E01}/verifica.sh" "${E01}/_docente/live.sh" "${SELF}"; do
    if ( cd "${RADICE}" && shellcheck -x -- "${f}" ) > /dev/null 2>&1; then
      pass "shellcheck ${f#"${RADICE}"/}"
    else
      fail "shellcheck ${f#"${RADICE}"/}"
    fi
  done
}

main() {
  local t
  for t in python3 git jq shellcheck; do
    command -v "${t}" > /dev/null 2>&1 \
      || { echo "test_m7_e01: manca ${t}" >&2; exit 2; }
  done
  [[ -f "${FINTO_PY}" ]] \
    || { echo "test_m7_e01: manca ${FINTO_PY}" >&2; exit 2; }
  handson::init_temp_base
  TMP="$(mktemp -d "${HANDSON_TEMP_BASE}/test_m7_e01.XXXXXX")" || exit 2
  trap 'chmod -R u+rwX "${TMP}" 2> /dev/null; rm -rf "${TMP}"' EXIT
  prepara_finti
  t_elemento
  t_readme
  t_prepara
  t_soluzione
  t_verifica
  t_live
  t_fallita
  t_precondizioni
  t_shellcheck
  OUT="${TUTTO}"
  expect_absent "in nessuna uscita «smentita»" "smentita"
  expect_absent "in nessuna uscita un traceback" "Traceback"
  echo "PASS=${PASS} FAIL=${FAIL}"
  if (( PASS + FAIL != CASES )); then
    echo "test_m7_e01: girati $((PASS + FAIL)) casi, attesi ${CASES}" >&2
    exit 2
  fi
  (( FAIL == 0 )) || exit 1
}

main "$@"
