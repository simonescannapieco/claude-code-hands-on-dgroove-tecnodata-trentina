#!/bin/bash
#
# test_m7_d03.sh -- le prove di M7-D03 «Il modello chiede, il codice risponde»,
# per il docente (sta in _docente/, il materiale del docente):
#   - l'elemento: i file, la definizione dello strumento collegata a
#     stato_linea, i due casi sui dati dello scenario, il README con le sue dieci
#     sezioni,
#     le frasi di Anthropic con il loro indirizzo, niente identificativi
#     interni, «smentita» o riferimenti alla giornata;
#   - prepara_esercizio.sh e verifica.sh sul punto di partenza (1);
#   - controlla_mosse.py su esiti del banco con il claude finto: tutto a posto
#     (0), le due garanzie che non valgono (1, ciascuna con il suo perché), un
#     caso che manca o non finisce (1), i file che non si leggono e gli usi
#     sbagliati (2), mai un traceback;
#   - verifica.sh: il controllo dell'elemento, mai quello dello spazio di
#     lavoro; le precondizioni (2);
#   - demo/in_classe.sh e _docente/live.sh con il claude e l'uv finti: quante
#     chiamate, con quali opzioni, nessuna ANTHROPIC_API_KEY, il lavoro in
#     risposte/ soltanto, le precondizioni (2, nessuna chiamata: l'esca), una
#     chiamata fallita (1);
#   - shellcheck -x sugli script e su questo file.
# Mai il claude vero né un server vero: il banco gira con il claude finto, che
# esegue le capacità con il motore vero del banco. CASES è il numero dei casi:
# se ne girano di più o di meno la suite esce 2.
#
# Uso:    m7_assistenti_llm/_docente/test_m7_d03.sh
# Uscita: 0 = tutti i casi passano · 1 = almeno un caso fallito · 2 =
#         precondizione (manca python3, git, tar o shellcheck), o un numero di
#         casi diverso da CASES
set -uo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly MOD="${SELF%/_docente/*}"
readonly RADICE="${MOD%/*}"
D03="${MOD}/s5_anatomia_e_strumenti/m7_5_strumenti"
D03+="/M7-D03_il_codice_risponde"
readonly D03
readonly FINTO_PY="${MOD}/_docente/claude_finto_m7_d01_d04.py"
readonly PROVA='progetti/assistenza-clienti/banco/prova.py'
# La libreria del repository, per la base dei file temporanei.
# shellcheck source=../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"
readonly CASES=102
FATTO='Fatto: ogni esecuzione è stata messa alla prova;'
FATTO+=' gli esiti sono qui sopra.'
readonly FATTO
readonly NONCONF='non confermata in questa esecuzione'
TMP=''
PASS=0
FAIL=0
RC=0
OUT=''
TUTTO=''

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

# Esegue un comando; RC e OUT (STDOUT e STDERR insieme) per expect.
run() { OUT="$("$@" 2>&1)"; RC=$?; TUTTO+="${OUT}"$'\n'; }

# Uscita attesa E parola chiave attesa (RU-01.T3).
# Arguments: $1 il nome, $2 l'uscita attesa, $3 la parola (grep -F).
expect() {
  if (( RC == $2 )) && grep -qF -- "$3" <<< "${OUT}"; then
    pass "$1"
  else
    fail "$1 (rc=${RC}, attesa $2, parola «$3»): ${OUT:0:700}"
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

# Uno spazio di lavoro nuovo, con prepara_esercizio.sh in una radice nuova.
# Arguments: $1 la variabile da assegnare. Returns: 0; 1 se non riesce.
nuovo_ws() {
  local __r
  __r="$(mktemp -d "${TMP}/radice.XXXXXX")" || exit 2
  "${RADICE}/tools/prepara_esercizio.sh" M7-D03 --radice "${__r}" \
    > "${TMP}/prepara.log" 2>&1 || return 1
  printf -v "$1" '%s' "${__r}/M7-D03"
}

# Sceglie come si comporta il claude finto. Arguments: le parole di FINTO_MODI.
modo() { printf '%s' "$*" > "${TMP}/modi"; }

# L'esca, il claude finto e l'uv finto (che prepara_server chiama e non deve
# fare nulla), i PATH ridotti. Esce 2 se nel PATH di prova claude non è il
# finto.
prepara_claude() {
  local t
  mkdir -p "${TMP}/esca" "${TMP}/finto" "${TMP}/senza_uv" \
    "${TMP}/senza_claude" "${TMP}/casa" || exit 2
  # shellcheck disable=SC2016  # il corpo è dell'esca
  printf '%s\n' '#!/bin/bash' \
    'printf "invocazione %s\n" "$*" >> "${ESCA_LOG}"' \
    > "${TMP}/esca/claude" || exit 2
  cat > "${TMP}/finto/claude" <<EOF || exit 2
#!/bin/bash
export FINTO_LOG="${TMP}/finto.log"
FINTO_MODI="\$(cat "${TMP}/modi" 2> /dev/null)"
export FINTO_MODI
exec python3 -B -I "${FINTO_PY}" "\$@"
EOF
  printf '#!/bin/bash\nexit 0\n' > "${TMP}/finto/uv" || exit 2
  printf '#!/bin/bash\nexit 0\n' > "${TMP}/esca/uv" || exit 2
  chmod 755 "${TMP}/esca/claude" "${TMP}/esca/uv" "${TMP}/finto/claude" \
    "${TMP}/finto/uv" || exit 2
  for t in readlink python3 git tar; do
    ln -s "$(command -v "${t}")" "${TMP}/senza_uv/${t}" || exit 2
  done
  ln -s "${TMP}/esca/claude" "${TMP}/senza_uv/claude" || exit 2
  for t in readlink python3 git tar; do
    ln -s "$(command -v "${t}")" "${TMP}/senza_claude/${t}" || exit 2
  done
  ln -s "${TMP}/esca/uv" "${TMP}/senza_claude/uv" || exit 2
  t="$(PATH="${TMP}/finto:${PATH}" command -v claude)"
  if [[ "${t}" != "${TMP}/finto/claude" ]]; then
    echo "test_m7_d03: nel PATH di prova claude è ${t}, non il finto" >&2
    exit 2
  fi
  modo
}

# Una esecuzione dei due casi con il banco e il claude finto, nello spazio di
# lavoro $1: il banco la scrive in risposte/run-$2. L'uscita del banco non
# conta: qui si provano i controlli.
# Arguments: $1 lo spazio di lavoro, $2 il numero, $3 i modi.
banco() {
  modo "${3:-}"
  ( cd "$1" && env -u CLAUDE_CONFIG_DIR PATH="${TMP}/finto:${PATH}" \
      HOME="${TMP}/casa" python3 -B -I "${PROVA}" casi --versione assistente \
      --casi casi --uscita "risposte/run-$2" ) > "${TMP}/banco.log" 2>&1
  modo
}

# controlla_mosse.py dell'elemento su risposte/ dello spazio di lavoro $1.
controlla() {
  run python3 -B -I "${D03}/demo/controlla_mosse.py" "$1/risposte"
}

# Lo script con l'esca davanti nel PATH (o con un PATH dato); il registro
# riparte vuoto. Arguments: $1 lo script, $2 lo spazio di lavoro, $3
# facoltativo il PATH, poi le variabili NOME=valore.
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

# Lo script con il finto davanti nel PATH e ANTHROPIC_API_KEY impostata; il
# registro riparte vuoto. Arguments: $1 lo script, $2 lo spazio di lavoro, poi
# le variabili NOME=valore.
finto() {
  local script="$1" w="$2"
  shift 2
  : > "${TMP}/finto.log"
  run env -u CLAUDE_CONFIG_DIR PATH="${TMP}/finto:${PATH}" \
    HOME="${TMP}/casa" HANDSON_NO_PAUSE=1 ANTHROPIC_API_KEY=valore-finto \
    CLAUDE_CODE_EFFORT_LEVEL=high TMPDIR="${TMP}" "$@" "${script}" "${w}"
}

# Le chiamate di un registro del finto: quante, con quali opzioni, i due casi.
# Arguments: $1 il registro, $2 lo spazio di lavoro, $3 quante esecuzioni.
controlla_chiamate() {
  run python3 -B -I - "$1" "$2" "$3" "${D03}/demo" <<'PY'
import json, os, sys
log, ws, n, demo = sys.argv[1:5]
n = int(n)
chiamate = [json.loads(r) for r in open(log, encoding="utf-8")]
problemi = []
attese = n * 2
if len(chiamate) != attese:
    problemi.append("%d chiamate invece di %d" % (len(chiamate), attese))
casi = {json.load(open(os.path.join(demo, "casi", f), encoding="utf-8"))["messaggio"]
        for f in os.listdir(os.path.join(demo, "casi"))}
sistema = open(os.path.join(demo, "assistente", "system-prompt.md"),
               encoding="utf-8").read()
visti = []
for i, c in enumerate(chiamate, 1):
    a = c["argv"]
    testo = " ".join(a)
    for opzione in ("--tools", "--mcp-config", "--strict-mcp-config",
                    "--allowedTools", "--no-session-persistence",
                    "--system-prompt-file", "--verbose"):
        if opzione not in a:
            problemi.append("chiamata %d: manca %s" % (i, opzione))
    coppie = (("--model", "sonnet"), ("--effort", "low"),
              ("--output-format", "stream-json"),
              ("--allowedTools", "mcp__assistenza__*"),
              ("--permission-mode", "dontAsk"),
              ("--permission-prompts", "none"),
              ("--setting-sources", "project,local"))
    for chiave, valore in coppie:
        if chiave not in a or a[a.index(chiave) + 1] != valore:
            problemi.append("chiamata %d: %s" % (i, chiave))
    if a[a.index("--tools") + 1] != "":
        problemi.append("chiamata %d: --tools non è vuoto" % i)
    if "dangerously" in testo or "bypassPermissions" in testo:
        problemi.append("chiamata %d: salta i permessi" % i)
    if c["chiave"] or c["effort"]:
        problemi.append("chiamata %d: ANTHROPIC_API_KEY o EFFORT" % i)
    if c["sistema"] != sistema:
        problemi.append("chiamata %d: il system prompt" % i)
    if os.path.realpath(c["cwd"]).startswith(os.path.realpath(ws) + "/") \
            or os.path.realpath(c["cwd"]) == os.path.realpath(ws):
        problemi.append("chiamata %d: dentro lo spazio di lavoro" % i)
    visti.append(a[-1])
if set(visti) != casi:
    problemi.append("i messaggi: %s" % sorted(set(visti)))
if visti.count(next(iter(casi), "")) != n:
    problemi.append("i casi per esecuzione non tornano")
print("; ".join(problemi) or "chiamate giuste")
PY
}

# --- L'elemento -------------------------------------------------------------

t_elemento() {
  local f
  for f in README.md verifica.sh progetti.txt demo/assistente/system-prompt.md \
      demo/assistente/strumenti.json demo/casi/linea-esistente.json \
      demo/casi/linea-inesistente.json demo/controlla_mosse.py \
      demo/in_classe.sh _docente/live.sh soluzione/LEGGIMI.md; do
    vero "elemento: ${f}" test -f "${D03}/${f}"
  done
  for f in verifica.sh _docente/live.sh demo/in_classe.sh; do
    vero "elemento: ${f} eseguibile" test -x "${D03}/${f}"
  done
  run python3 -B -I - "${D03}" "${RADICE}/progetti/assistenza-clienti" <<'PY'
import json, os, sys
d, prog = sys.argv[1:3]
problemi = []
strumenti = json.load(open(os.path.join(d, "demo/assistente/strumenti.json"),
                           encoding="utf-8"))
if len(strumenti) != 1 or strumenti[0].get("capacita") != "stato_linea" \
        or strumenti[0].get("name") != "stato_linea":
    problemi.append("uno strumento, collegato a stato_linea")
if len(strumenti[0].get("description", "").split(".")) < 4:
    problemi.append("la descrizione: troppo corta")
scenario = json.load(open(os.path.join(
    prog, "scenari", "sc-01-fibra-assente-guasto-pergine.json"),
    encoding="utf-8"))
linee = {li["id_linea"] for li in scenario["verita_nascosta"]["linee"]}
es = json.load(open(os.path.join(d, "demo/casi/linea-esistente.json"),
                    encoding="utf-8"))
ne = json.load(open(os.path.join(d, "demo/casi/linea-inesistente.json"),
                    encoding="utf-8"))
if "LN-000201" not in es["messaggio"] or "LN-000201" not in linee:
    problemi.append("il caso della linea che esiste")
if "LN-999999" not in ne["messaggio"] or "LN-999999" in linee:
    problemi.append("il caso della linea che non esiste")
if "progetti/assistenza-clienti" not in open(os.path.join(d, "progetti.txt"),
                                             encoding="utf-8").read():
    problemi.append("progetti.txt")
print("; ".join(problemi) or "testi a posto")
PY
  expect "lo strumento, i casi, i progetti" 0 "testi a posto"
}

# Il README: dieci sezioni, frasi di Anthropic, testi uguali ai file; niente
# identificativi interni, giornate, «smentita».
t_readme() {
  run python3 -B -I - "${D03}" <<'PY'
import json, os, re, sys
item = sys.argv[1]
readme = open(os.path.join(item, "README.md"), encoding="utf-8").read()
leggi = lambda p: open(os.path.join(item, p), encoding="utf-8").read().strip()
problemi = []
sezioni = ("Obiettivo", "Tempo", "Prerequisiti", "Punto di partenza",
           "Passi in Claude Code", "Che cosa osservare", "Verifica",
           "Se qualcosa va storto", "Impronta d'uso sul piano Pro",
           "Per approfondire")
titoli = [r[3:] for r in readme.splitlines() if r.startswith("## ")]
if [next((s for s in sezioni if t.startswith(s)), "") for t in titoli] \
        != list(sezioni):
    problemi.append("le dieci sezioni, in ordine: %s" % titoli)
for titolo in ("## Punto di partenza (tools/prepara_esercizio.sh M7-D03)",
               "## Verifica (tools/verifica.sh M7-D03)"):
    if titolo not in readme:
        problemi.append("il titolo «%s»" % titolo)
HW = "https://platform.claude.com/docs/en/agents-and-tools/tool-use/how-tool-use-works"
MCP = "https://code.claude.com/docs/en/mcp"
STDIO = "https://modelcontextprotocol.io/specification/2026-07-28/basic/transports/stdio"
ARCH = "https://modelcontextprotocol.io/docs/2026-07-28/learn/architecture"
WT = "https://www.anthropic.com/research/writing-tools-for-agents"
frasi = [
    ("The model never runs anything on its own. It emits a structured request, "
     "your code (or Anthropic’s servers) runs the operation", HW),
    ("when a tool returns a result marked isError: true, Claude receives the "
     "result's text as the tool's error message.", MCP),
    ("The server MUST NOT write anything to its stdout that is not a valid "
     "MCP message.", STDIO),
    ("The server MAY write UTF-8 strings to stderr for any logging purposes", STDIO),
    ("Stdio transport: Uses standard input/output streams for direct process "
     "communication between local processes on the same machine", ARCH),
    ("an MCP host — an AI application like Claude Code or Claude Desktop — "
     "establishes connections to one or more MCP servers.", ARCH),
    ("Wrapping your tools in a local MCP server … will allow you to connect "
     "and test your tools in Claude Code or the Claude Desktop app.", WT)]
piano = " ".join(readme.split())
for frase, url in frasi:
    if frase not in piano:
        problemi.append("manca «%s»" % frase[:40])
    if url not in readme:
        problemi.append("manca %s" % url)
for nome, percorso in (("sistema", "demo/assistente/system-prompt.md"),
                       ("esistente", "demo/casi/linea-esistente.json"),
                       ("inesistente", "demo/casi/linea-inesistente.json")):
    blocco = re.search(r"<!-- prompt %s -->\n(.*?)<!-- /prompt %s -->" % (nome, nome),
                       readme, re.S)
    atteso = leggi(percorso) if percorso.endswith(".md") \
        else json.loads(leggi(percorso))["messaggio"]
    if not blocco or " ".join(blocco.group(1).split()) != " ".join(atteso.split()):
        problemi.append("il prompt %s non è il file" % nome)
for vietata in ("smentit", "FACT-", "M7-X", "X-3", "/home/"):
    if vietata in readme:
        problemi.append("«%s»" % vietata)
for parola in ("oggi", "domani", "pausa", "pranzo"):
    if re.search(r"\b%s\b" % parola, readme):
        problemi.append("«%s»" % parola)
print("; ".join(problemi) or "README a posto")
PY
  expect "README: sezioni, frasi con l'indirizzo, testi, niente di vietato" 0 \
    "README a posto"
}

t_prepara() {
  local ws f
  if ! nuovo_ws ws; then
    fail "prepara_esercizio.sh M7-D03: $(tail -n 3 "${TMP}/prepara.log")"
    return
  fi
  pass "prepara_esercizio.sh M7-D03"
  for f in assistente/system-prompt.md assistente/strumenti.json \
      casi/linea-esistente.json casi/linea-inesistente.json \
      controlla_mosse.py in_classe.sh "${PROVA}" .claude/settings.json; do
    vero "spazio di lavoro: ${f}" test -f "${ws}/${f}"
  done
  if [[ ! -e "${ws}/soluzione" && ! -e "${ws}/_docente" ]]; then
    pass "spazio di lavoro: niente soluzione/ né _docente/"
  else
    fail "spazio di lavoro: soluzione/ o _docente/"
  fi
  run "${RADICE}/tools/verifica.sh" M7-D03 --radice "${ws%/M7-D03}"
  expect "verifica.sh sul punto di partenza: 1" 1 \
    "Manca la cartella risposte/"
}

# --- Il controllo -----------------------------------------------------------

t_controllo() {
  local ws
  nuovo_ws ws || { fail "controllo: prepara_esercizio.sh"; return; }
  banco "${ws}" 1
  banco "${ws}" 2
  controlla "${ws}"
  expect "controllo: due esecuzioni, tutto a posto, 0" 0 \
    "Le due garanzie, esecuzione per esecuzione: valgono in 2 su 2."
  expect "controllo: lo strumento chiesto, con gli argomenti" 0 \
    'stato_linea, argomenti {"id_linea": "LN-000201"}'
  expect "controllo: il risultato dal registro" 0 \
    '"id_linea": "LN-000201", "tecnologia": "FTTH"'
  expect "controllo: la prima garanzia, confermata" 0 \
    "«The model never runs anything on its own»: confermata"
  expect "controllo: l'errore nel tool_result, is_error true" 0 \
    "nel registro errore sì, nel tool_result is_error true: confermata"
  expect "controllo: la dimostrazione, i dati dal risultato" 0 \
    "i dati della risposta che vengono dal risultato: LN-000201"
  expect "controllo: la dimostrazione, il codice che viene dal messaggio" 0 \
    "che nel risultato non ci sono: LN-999999"
  expect "controllo: i token della prima richiesta" 0 "prima richiesta"
  expect_absent "controllo: nessun «non confermata»" "${NONCONF}"
  rm -rf -- "${ws}/risposte/run-2"
  banco "${ws}" 2 muto
  controlla "${ws}"
  expect "garanzia: nessuna chiamata allo strumento, 1" 1 \
    "nel registro del server non c'è nessuna chiamata"
  expect "garanzia: la riga «non confermata», 1" 1 \
    "«The model never runs anything on its own»: ${NONCONF}"
  rm -rf -- "${ws}/risposte/run-2"
  banco "${ws}" 2 log-diverso
  controlla "${ws}"
  expect "garanzia: il registro non ha la chiamata dello stream, 1" 1 \
    "strumento o argomenti diversi"
  rm -rf -- "${ws}/risposte/run-2"
  banco "${ws}" 2 senza-is-error
  controlla "${ws}"
  expect "garanzia: l'errore senza is_error, 1" 1 \
    "nel tool_result is_error assente: ${NONCONF}"
  rm -rf -- "${ws}/risposte/run-2"
  banco "${ws}" 2 dopo
  controlla "${ws}"
  expect "garanzia: la risposta prima del risultato, 1" 1 \
    "il risultato non precede la risposta"
  rm -rf -- "${ws}/risposte/run-2"
  banco "${ws}" 2
  controlla "${ws}"
  expect "controllo: rifatta l'esecuzione, di nuovo 0" 0 "valgono in 2 su 2"
}

t_mancanze() {
  local ws
  nuovo_ws ws || { fail "mancanze: prepara_esercizio.sh"; return; }
  banco "${ws}" 1
  banco "${ws}" 2
  rm -r -- "${ws}/risposte/run-2/linea-inesistente"
  controlla "${ws}"
  expect "mancanza: un caso che manca, 1" 1 \
    "manca run-2/linea-inesistente"
  rm -r -- "${ws}/risposte/run-2"
  banco "${ws}" 2
  rm -- "${ws}/risposte/run-1/linea-esistente/esito.json"
  controlla "${ws}"
  expect "mancanza: esito.json che manca, 1" 1 "esito.json"
  rm -r -- "${ws}/risposte"
  banco "${ws}" 1 tronco
  controlla "${ws}"
  expect "mancanza: uno stream senza il risultato, 1" 1 "non è finita"
  rm -r -- "${ws}/risposte"
  banco "${ws}" 1 errore
  controlla "${ws}"
  expect "mancanza: un risultato con l'errore, 1" 1 \
    "claude ha restituito un errore"
}

t_illeggibili() {
  local ws j
  nuovo_ws ws || { fail "illeggibili: prepara_esercizio.sh"; return; }
  banco "${ws}" 1 riga-rotta
  controlla "${ws}"
  expect "illeggibile: una riga che non è JSON, 2" 2 "non è JSON"
  rm -r -- "${ws}/risposte"
  banco "${ws}" 1
  printf 'non è json\n' \
    >> "${ws}/risposte/run-1/linea-esistente/registro.jsonl" || exit 2
  controlla "${ws}"
  expect "illeggibile: il registro che non è JSON, 2" 2 "registro.jsonl"
  banco "${ws}" 2
  printf '{"rotto"' > "${ws}/risposte/run-2/linea-esistente/esito.json" \
    || exit 2
  rm -r -- "${ws}/risposte/run-1"
  controlla "${ws}"
  expect "illeggibile: un esito che non è JSON, 2" 2 "esito.json"
  j="$(mktemp -d "${TMP}/vuota.XXXXXX")"
  run python3 -B -I "${D03}/demo/controlla_mosse.py" "${j}"
  expect "illeggibile: una cartella senza esecuzioni, 2" 2 \
    "nessuna esecuzione"
  run python3 -B -I "${D03}/demo/controlla_mosse.py" "${TMP}/non-c-e"
  expect "illeggibile: una cartella che non c'è, 2" 2 "non esiste"
  run python3 -B -I "${D03}/demo/controlla_mosse.py"
  expect "uso: senza argomenti, 2" 2 "Uso:"
  run python3 -B -I "${D03}/demo/controlla_mosse.py" --aiuto
  expect "uso: un'opzione, 2" 2 "Uso:"
  run env PN_HANDSON_ROOT="${TMP}/non-c-e" python3 -B -I \
    "${D03}/demo/controlla_mosse.py" "${j}"
  expect "precondizione: tools/ che non c'è, 2" 2 \
    "non trovo tools/lib_leggi_contesto.py"
}

t_verifica() {
  local ws
  nuovo_ws ws || { fail "verifica: prepara_esercizio.sh"; return; }
  run "${D03}/verifica.sh" "${ws}"
  expect "verifica: senza risposte/, 1" 1 "Manca la cartella risposte/"
  mkdir -p "${ws}/risposte" || exit 2
  run "${D03}/verifica.sh" "${ws}"
  expect "verifica: risposte/ vuota, 1" 1 "nessuna esecuzione"
  banco "${ws}" 1
  printf '%s\n' 'print("CONTROLLO FINTO")' \
    > "${ws}/controlla_mosse.py" || exit 2
  run env PN_HANDSON_ROOT="${RADICE}" "${D03}/verifica.sh" "${ws}"
  expect "verifica: una serie completa, 0, «Fatto»" 0 "${FATTO}"
  expect_absent "verifica: il controllo dell'elemento, non della copia" \
    "CONTROLLO FINTO"
  rm -r -- "${ws}/risposte/run-1/linea-esistente"
  run "${D03}/verifica.sh" "${ws}"
  expect "verifica: un caso che manca, 1" 1 "manca run-1/linea-esistente"
  run "${D03}/verifica.sh"
  expect "verifica: senza argomenti, 2" 2 "spazio di lavoro assente"
}

# --- in_classe.sh e live.sh -------------------------------------------------

t_in_classe() {
  local ws
  nuovo_ws ws || { fail "in_classe: prepara_esercizio.sh"; return; }
  finto "${D03}/demo/in_classe.sh" "${ws}"
  expect "in_classe: un'esecuzione, 0" 0 \
    "VERIFICA OK   il controllo, sulle esecuzioni di risposte/"
  expect "in_classe: il comando di prova.py sullo schermo" 0 "${PROVA} casi"
  expect "in_classe: il controllo, sullo schermo" 0 "valgono in 1 su 1"
  controlla_chiamate "${TMP}/finto.log" "${ws}" 1
  expect "in_classe: le chiamate del banco, le opzioni, nessuna chiave" 0 \
    "chiamate giuste"
  run git -C "${ws}" status --porcelain
  if [[ "${OUT}" == '?? risposte/' ]]; then
    pass "in_classe: lo spazio di lavoro cambia solo in risposte/"
  else
    fail "in_classe: git status «${OUT}»"
  fi
  run env PN_HANDSON_ROOT="${RADICE}" "${D03}/verifica.sh" "${ws}"
  expect "in_classe: poi verifica.sh, 0" 0 "${FATTO}"
}

t_live() {
  local ws
  nuovo_ws ws || { fail "live: prepara_esercizio.sh"; return; }
  finto "${D03}/_docente/live.sh" "${ws}"
  expect "live: tre esecuzioni, 0" 0 \
    "VERIFICA OK   verifica.sh dell'elemento"
  expect "live: le garanzie, tre su tre" 0 "valgono in 3 su 3"
  controlla_chiamate "${TMP}/finto.log" "${ws}" 3
  expect "live: le sei chiamate" 0 "chiamate giuste"
  run "${RADICE}/tools/verifica.sh" M7-D03 --radice "${ws%/M7-D03}"
  expect "live: poi tools/verifica.sh, 0" 0 "VERIFICA OK   M7-D03: fatto."
  run "${D03}/_docente/live.sh"
  expect "live: senza argomenti, 2" 2 "uso:"
}

t_precondizioni() {
  local ws s="${D03}/demo/in_classe.sh"
  nuovo_ws ws || { fail "precondizioni: prepara_esercizio.sh"; return; }
  precondizione "precondizione: una cartella che non è lo spazio" \
    "non è lo spazio di lavoro di M7-D03" "${s}" "${TMP}"
  precondizione "precondizione: nessuno spazio di lavoro" \
    "spazio di lavoro assente" "${s}" ""
  precondizione "precondizione: PN_ESECUZIONI 0" "PN_ESECUZIONI" \
    "${s}" "${ws}" "${TMP}/esca:${PATH}" PN_ESECUZIONI=0
  precondizione "precondizione: HANDSON_ENV claude-ai-pro" \
    "è un elemento claude-code-pro" "${s}" "${ws}" "${TMP}/esca:${PATH}" \
    HANDSON_ENV=claude-ai-pro
  precondizione "precondizione: senza uv" "manca lo strumento: uv" \
    "${s}" "${ws}" "${TMP}/senza_uv"
  precondizione "precondizione: senza claude" "manca lo strumento: claude" \
    "${s}" "${ws}" "${TMP}/senza_claude"
  printf 'x\n' > "${ws}/estraneo.txt" || exit 2
  precondizione "precondizione: uno spazio di lavoro cambiato" \
    "non è al punto di partenza" "${s}" "${ws}"
  rm -f -- "${ws}/estraneo.txt"
  mkdir -p "${ws}/risposte" || exit 2
  precondizione "precondizione: risposte/ c'è già" \
    "non è al punto di partenza" "${s}" "${ws}"
  rmdir -- "${ws}/risposte"
  mv -- "${ws}/casi/linea-esistente.json" "${TMP}/caso.json" || exit 2
  precondizione "precondizione: un caso che manca" \
    "file assente o illeggibile: casi/linea-esistente.json" "${s}" "${ws}"
  mv -- "${TMP}/caso.json" "${ws}/casi/linea-esistente.json" || exit 2
  precondizione "precondizione: senza tools/lib_handson.sh" \
    "lanciatelo dal repository, o date PN_HANDSON_ROOT" "${s}" "${ws}" \
    "${TMP}/esca:${PATH}" PN_HANDSON_ROOT="${TMP}/non-c-e"
}

t_fallita() {
  local ws
  nuovo_ws ws || { fail "fallita: prepara_esercizio.sh"; return; }
  modo ko
  finto "${D03}/demo/in_classe.sh" "${ws}"
  modo
  expect "fallita: una chiamata che fallisce, 1" 1 \
    "VERIFICA KO   esecuzione 1: una chiamata non è finita"
  run "${D03}/verifica.sh" "${ws}"
  expect "fallita: verifica.sh dopo, non 0" 1 "run-1"
  nuovo_ws ws || { fail "fallita: prepara_esercizio.sh"; return; }
  modo server-ko
  finto "${D03}/demo/in_classe.sh" "${ws}"
  modo
  expect "fallita: il server MCP che non parte, 1" 1 \
    "VERIFICA KO   esecuzione 1: una chiamata non è finita"
  expect "fallita: il motivo del server, sullo schermo" 1 "non si è collegato"
  run "${D03}/verifica.sh" "${ws}"
  expect "fallita: verifica.sh non conta quella prova, 1" 1 "non è finita"
}

# Gli script di M7-D03 e questo file, con shellcheck -x.
t_shellcheck() {
  local f
  for f in "${D03}/verifica.sh" "${D03}/_docente/live.sh" \
      "${D03}/demo/in_classe.sh" "${SELF}"; do
    if ( cd "${RADICE}" && shellcheck -x -- "${f}" ) > /dev/null 2>&1; then
      pass "shellcheck ${f#"${RADICE}"/}"
    else
      fail "shellcheck ${f#"${RADICE}"/}"
    fi
  done
}

main() {
  local t
  for t in python3 git tar shellcheck; do
    command -v "${t}" > /dev/null 2>&1 \
      || { echo "test_m7_d03: manca ${t}" >&2; exit 2; }
  done
  [[ -f "${FINTO_PY}" ]] \
    || { echo "test_m7_d03: manca ${FINTO_PY}" >&2; exit 2; }
  handson::init_temp_base
  TMP="$(mktemp -d "${HANDSON_TEMP_BASE}/test_m7_d03.XXXXXX")" || exit 2
  trap 'chmod -R u+rwX "${TMP}" 2> /dev/null; rm -rf "${TMP}"' EXIT
  prepara_claude
  t_elemento
  t_readme
  t_prepara
  t_controllo
  t_mancanze
  t_illeggibili
  t_verifica
  t_in_classe
  t_live
  t_precondizioni
  t_fallita
  t_shellcheck
  OUT="${TUTTO}"
  expect_absent "in nessuna uscita «smentita»" "smentita"
  expect_absent "in nessuna uscita un traceback" "Traceback"
  echo "PASS=${PASS} FAIL=${FAIL}"
  if (( PASS + FAIL != CASES )); then
    echo "test_m7_d03: girati $((PASS + FAIL)) casi, attesi ${CASES}" >&2
    exit 2
  fi
  (( FAIL == 0 )) || exit 1
}

main "$@"
