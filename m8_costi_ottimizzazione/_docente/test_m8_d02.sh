#!/bin/bash
#
# test_m8_d02.sh -- le prove di M8-D02 «Il conto dal campo usage», per il
# docente:
#   - l'elemento: i file, i testi, il listino con i prezzi attesi, il README
#     con le dieci sezioni, le frasi di Anthropic con il loro indirizzo, i
#     prompt uguali ai file, niente identificativi interni, «smentita» o
#     riferimenti alla giornata;
#   - prepara_esercizio.sh e verifica.sh sul punto di partenza (1);
#   - controlla_conto.py su JSON del claude finto: il conto di ogni chiamata,
#     il ricalcolo dei cinque conteggi, il confronto (un esito non cambia
#     l'uscita), le esecuzioni che mancano o falliscono (1), i JSON che non si
#     leggono e gli usi sbagliati (2), mai un traceback;
#   - verifica.sh: il controllo dell'elemento, mai quello dello spazio di
#     lavoro; risposte/ che manca o vuota (1); le precondizioni (2);
#   - demo/in_classe.sh e _docente/live.sh con il claude finto: quante
#     chiamate, in che ordine, da quale cartella, con quali opzioni, i bracci
#     diversi soltanto nella richiesta sul formato, nessuna ANTHROPIC_API_KEY,
#     le precondizioni (2, nessuna chiamata: l'esca), una chiamata fallita (1);
#   - shellcheck -x sugli script e su questo file.
# Mai il claude vero: il finto e l'esca stanno davanti nel PATH, e la suite lo
# controlla prima di usarli. Gli spazi di lavoro nascono in una cartella
# temporanea: l'albero del repository non cambia. CASES è il numero dei casi:
# se ne girano di più o di meno la suite esce 2.
#
# Uso:    m8_costi_ottimizzazione/_docente/test_m8_d02.sh
# Uscita: 0 = tutti i casi passano · 1 = almeno un caso fallito · 2 =
#         precondizione (manca python3, git o shellcheck), o un numero di casi
#         diverso da CASES
set -uo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly MOD="${SELF%/_docente/*}"
readonly RADICE="${MOD%/*}"
D02="${MOD}/s6_costi_e_ottimizzazione/m8_3_il_conto_in_token"
D02+="/M8-D02_il_conto_dal_campo_usage"
readonly D02
readonly FINTO_PY="${MOD}/_docente/claude_finto_m8_d02.py"
# La libreria del repository, per la base dei file temporanei.
# shellcheck source=../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"
readonly CASES=125
FATTO='Fatto: ogni esecuzione è stata letta; il conto e il confronto sono'
FATTO+=' qui sopra.'
readonly FATTO
readonly NONCONF='non confermata in questa esecuzione'
readonly NONDIST='non distinguibile'
TMP=''
PASS=0
FAIL=0
RC=0
OUT=''
TUTTO=''

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

# Esegue un comando; RC e OUT (STDOUT e STDERR insieme) per expect; OUT si
# aggiunge a TUTTO, dove alla fine non devono esserci «smentita» né traceback.
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
  "${RADICE}/tools/prepara_esercizio.sh" M8-D02 --radice "${__r}" \
    > "${TMP}/prepara.log" 2>&1 || return 1
  printf -v "$1" '%s' "${__r}/M8-D02"
}

# Sceglie come si comporta il claude finto. Arguments: le parole di FINTO_MODI.
modo() { printf '%s' "$*" > "${TMP}/modi"; }

# L'esca (registra ogni invocazione ed esce 0), il claude finto (un involucro
# che legge i modi da un file) e i PATH ridotti. Esce 2 se nel PATH di prova
# claude non è il finto.
prepara_claude() {
  local t
  mkdir -p "${TMP}/esca" "${TMP}/finto" "${TMP}/senza_python" \
    "${TMP}/senza_claude" || exit 2
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
  chmod 755 "${TMP}/esca/claude" "${TMP}/finto/claude" || exit 2
  for t in readlink git mktemp mkdir cat; do
    ln -s "$(command -v "${t}")" "${TMP}/senza_python/${t}" || exit 2
  done
  ln -s "${TMP}/esca/claude" "${TMP}/senza_python/claude" || exit 2
  for t in readlink python3 git mktemp mkdir cat; do
    ln -s "$(command -v "${t}")" "${TMP}/senza_claude/${t}" || exit 2
  done
  t="$(PATH="${TMP}/finto:${PATH}" command -v claude)"
  if [[ "${t}" != "${TMP}/finto/claude" ]]; then
    echo "test_m8_d02: nel PATH di prova claude è ${t}, non il finto" >&2
    exit 2
  fi
  modo
}

# Una chiamata del finto, come la fa in_classe.sh; il JSON in un file.
# Arguments: $1 il prompt, $2 il file d'uscita.
finta() {
  ( cd "${TMP}" && "${TMP}/finto/claude" -p --model haiku \
      --permission-mode dontAsk --permission-prompts none \
      --output-format json --setting-sources project,local --tools '' \
      --system-prompt "$(< "${D02}/demo/sistema.txt")" --effort low \
      --strict-mcp-config --no-session-persistence -- "$1" ) < /dev/null \
    > "$2" \
    || { echo "test_m8_d02: il finto non scrive $2" >&2; exit 2; }
}

# Il prompt di un braccio: domanda, riga vuota, formato del braccio.
# Arguments: $1 il braccio (breve o lunga). Outputs: il prompt.
prompt_di() {
  local nome=formato-breve
  if [[ "$1" == lunga ]]; then
    nome=formato-lungo
  fi
  printf '%s\n\n%s' "$(< "${D02}/demo/domanda.txt")" \
    "$(< "${D02}/demo/${nome}.txt")"
}

# Rifà una chiamata di una serie, con i modi dati.
# Arguments: $1 la cartella degli esiti, $2 il nome (breve-1, lunga-2,
# contesto), $3 i modi.
rifai() {
  local j="$1" nome="$2" modi="${3:-}"
  mkdir -p "${j}/${nome}" || exit 2
  modo "${modi}"
  if [[ "${nome}" == contesto ]]; then
    finta '/context' "${j}/${nome}/risposta.json"
  else
    finta "$(prompt_di "${nome%%-*}")" "${j}/${nome}/risposta.json"
  fi
  modo
}

# Una cartella nuova di risposte, con $2 coppie.
# Arguments: $1 la variabile da assegnare, $2 quante coppie.
nuova_serie() {
  local __j k b
  __j="$(mktemp -d "${TMP}/json.XXXXXX")" || exit 2
  rifai "${__j}" contesto
  for (( k = 1; k <= $2; k++ )); do
    for b in breve lunga; do
      rifai "${__j}" "${b}-${k}"
    done
  done
  printf -v "$1" '%s' "${__j}"
}

# controlla_conto.py dell'elemento; RC e OUT come run.
controlla() { run python3 -B -I "${D02}/demo/controlla_conto.py" "$@"; }

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
# (--version a parte). Arguments: $1 il nome, $2 la parola, poi gli argomenti
# di esca.
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

# Lo script con il finto davanti nel PATH e ANTHROPIC_API_KEY e
# CLAUDE_CODE_EFFORT_LEVEL impostate (lo script le deve togliere); il registro
# riparte vuoto. Arguments: $1 lo script, $2 lo spazio di lavoro, poi le
# variabili NOME=valore.
finto() {
  local script="$1" w="$2"
  shift 2
  : > "${TMP}/finto.log"
  run env PATH="${TMP}/finto:${PATH}" HANDSON_NO_PAUSE=1 \
    ANTHROPIC_API_KEY=valore-finto CLAUDE_CODE_EFFORT_LEVEL=high \
    TMPDIR="${TMP}" "$@" "${script}" "${w}"
}

# Le chiamate di un registro del finto, contro le attese: quante, in che
# ordine, da quale cartella, con quali opzioni, i bracci diversi soltanto nel
# prompt. Arguments: $1 il registro, $2 lo spazio di lavoro, $3 quante coppie.
controlla_chiamate() {
  run python3 -B -I - "$1" "$2" "$3" "${D02}/demo" <<'PY'
import json, os, sys
log, ws, n, demo = sys.argv[1:5]
n = int(n)
chiamate = [json.loads(r) for r in open(log, encoding="utf-8")]
leggi = lambda p: open(os.path.join(demo, p), encoding="utf-8").read().strip()
domanda = leggi("domanda.txt")
sistema = leggi("sistema.txt")
prompt_breve = domanda + "\n\n" + leggi("formato-breve.txt")
prompt_lungo = domanda + "\n\n" + leggi("formato-lungo.txt")
VALORE = {"--model", "--effort", "--output-format", "--setting-sources",
          "--permission-mode", "--permission-prompts", "--tools",
          "--system-prompt"}
def opzioni(c):
    argv = c["argv"]
    fine, o, j = argv.index("--"), {}, 0
    while j < fine:
        if argv[j] in VALORE:
            o[argv[j]] = argv[j + 1]
            j += 2
        else:
            o[argv[j]] = True
            j += 1
    return o, argv[fine + 1:]
problemi = []
attese = 1 + 2 * n
if len(chiamate) != attese:
    problemi.append("%d chiamate invece di %d" % (len(chiamate), attese))
fisse = (("--model", "haiku"), ("--effort", "low"),
         ("--output-format", "json"), ("--setting-sources", "project,local"),
         ("--tools", ""), ("--permission-mode", "dontAsk"),
         ("--permission-prompts", "none"), ("--system-prompt", sistema))
for i, c in enumerate(chiamate, 1):
    o, resto = opzioni(c)
    for k, v in fisse:
        if o.get(k) != v:
            problemi.append("chiamata %d: %s" % (i, k))
    for k in ("-p", "--strict-mcp-config", "--no-session-persistence"):
        if o.get(k) is not True:
            problemi.append("chiamata %d: %s" % (i, k))
    if any("dangerously" in a or "bypassPermissions" in a for a in c["argv"]) \
            or "--allowedTools" in o or "--verbose" in o or "--resume" in o:
        problemi.append("chiamata %d: un'opzione di troppo" % i)
    if len(resto) != 1:
        problemi.append("chiamata %d: il prompt dopo -- non è uno" % i)
    cwd = os.path.realpath(c["cwd"])
    if cwd == os.path.realpath(ws) or cwd.startswith(
            os.path.realpath(ws) + "/"):
        problemi.append("chiamata %d: dentro lo spazio di lavoro" % i)
    if c["chiave"] or c["effort"]:
        problemi.append("chiamata %d: ANTHROPIC_API_KEY o EFFORT" % i)
    if not c["stdin_nullo"]:
        problemi.append("chiamata %d: STDIN non è /dev/null" % i)
    if c["sistema"] != sistema:
        problemi.append("chiamata %d: il system prompt" % i)
if chiamate and chiamate[0]["prompt"] != "/context":
    problemi.append("la prima chiamata non è /context")
# Le coppie, in fila: breve, lunga, breve, lunga, … uguali fuori dal prompt.
def senza_prompt(c):
    argv = list(c["argv"])
    return argv[:argv.index("--")]
for k in range(n):
    breve, lunga = chiamate[1 + 2 * k], chiamate[2 + 2 * k]
    if opzioni(breve)[1] != [prompt_breve]:
        problemi.append("coppia %d: il prompt breve" % (k + 1))
    if opzioni(lunga)[1] != [prompt_lungo]:
        problemi.append("coppia %d: il prompt lungo" % (k + 1))
    if senza_prompt(breve) != senza_prompt(lunga):
        problemi.append("coppia %d: i bracci differiscono" % (k + 1))
print("; ".join(problemi) or "chiamate giuste")
PY
}

# --- L'elemento -------------------------------------------------------------

t_elemento() {
  local f
  for f in README.md verifica.sh demo/domanda.txt demo/formato-breve.txt \
      demo/formato-lungo.txt demo/sistema.txt demo/listino.json \
      demo/controlla_conto.py demo/in_classe.sh _docente/live.sh \
      soluzione/LEGGIMI.md; do
    vero "elemento: ${f}" test -f "${D02}/${f}"
  done
  for f in verifica.sh _docente/live.sh demo/in_classe.sh; do
    vero "elemento: ${f} eseguibile" test -x "${D02}/${f}"
  done
  run python3 -B -I - "${D02}/demo" <<'PY'
import json, os, sys
d = sys.argv[1]
leggi = lambda p: open(os.path.join(d, p), encoding="utf-8").read()
problemi = []
if len(leggi("domanda.txt").splitlines()) != 1 or "?" not in leggi("domanda.txt"):
    problemi.append("domanda.txt: una domanda su una riga")
if "una riga" not in leggi("formato-breve.txt"):
    problemi.append("formato-breve.txt: una riga")
if "sei sezioni" not in leggi("formato-lungo.txt"):
    problemi.append("formato-lungo.txt: sei sezioni")
if len(leggi("sistema.txt").splitlines()) != 1:
    problemi.append("sistema.txt: una riga")
l = json.loads(leggi("listino.json"))
attesi = {"haiku": (0.10, 0.50, 0.125, 0.20, 0.01),
          "sonnet": (2, 10, 2.5, 4, 0.10),
          "opus": (4, 20, 5, 8, 0.20)}
campi = ("input", "output", "cache_write_5m", "cache_write_1h", "cache_read")
for alias, numeri in attesi.items():
    voce = l["modelli"][alias]
    if tuple(voce[c] for c in campi) != numeri:
        problemi.append("listino: i prezzi di %s" % alias)
if l.get("letto_il") != "2026-11-10" or "pricing" not in l.get("pagina_prezzi", "") \
        or "haiku-5-5" not in l.get("pagina_haiku", ""):
    problemi.append("listino: la data o le pagine")
print("; ".join(problemi) or "testi a posto")
PY
  expect "i testi e il listino della demo" 0 "testi a posto"
}

# Il README: le dieci sezioni, le frasi di Anthropic, i prompt uguali ai file;
# niente identificativi interni, giornate, «smentita».
t_readme() {
  run python3 -B -I - "${D02}" <<'PY'
import os, re, sys
item = sys.argv[1]
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
for titolo in ("## Punto di partenza (tools/prepara_esercizio.sh M8-D02)",
               "## Verifica (tools/verifica.sh M8-D02)"):
    if titolo not in readme:
        problemi.append("il titolo «%s»" % titolo)
OPT = "https://platform.claude.com/docs/en/about-claude/models/" \
    "optimizing-for-cost-and-intelligence"
HL = "https://code.claude.com/docs/en/headless"
frasi = [
    ("Ask for the answer you will read, not the one that looks thorough.",
     OPT),
    ("Price each of the five token counts in a response’s usage at its own "
     "rate", OPT),
    ("Output tokens cost five times input tokens on Claude Haiku 5.5, Claude "
     "Sonnet 5.5, Claude Opus 5.5, Claude Fable 5.2, and Claude Fable 5.1",
     OPT),
    ("Total input tokens in a request is the summation of input_tokens, "
     "cache_creation_input_tokens, and cache_read_input_tokens.",
     "https://platform.claude.com/docs/en/api/messages/create"),
    ("With --output-format json, the response payload includes "
     "total_cost_usd and a per-model cost breakdown", HL),
    ("Both figures are client-side estimates and can differ from your actual "
     "bill.", HL),
    ("Claude Code computes the dollar figure locally from token counts at "
     "list price", "https://code.claude.com/docs/en/costs"),
    ("so on a subscription it is a guide to how much work you did, not a "
     "bill.", "https://claude.dev/blog/what-a-task-costs-on-opus-5-5/"),
    ("Claude Code reports one-hour cache writes under "
     "ephemeral_1h_input_tokens and five-minute cache writes under "
     "ephemeral_5m_input_tokens.",
     "https://code.claude.com/docs/en/prompt-caching"),
    ("Replaces the entire default prompt",
     "https://code.claude.com/docs/en/cli-reference"),
    ("Show session cost, plan usage limits, and activity stats.",
     "https://code.claude.com/docs/en/commands"),
]
piano = " ".join(readme.split())
for frase, url in frasi:
    if " ".join(frase.split()) not in piano:
        problemi.append("manca «%s»" % frase[:50])
    if url not in readme:
        problemi.append("manca %s" % url)
demo = os.path.join(item, "demo")
for nome in ("domanda", "formato-breve", "formato-lungo", "sistema"):
    m = re.search(r"<!-- prompt %s -->\n(.*?)<!-- /prompt %s -->"
                  % (nome, nome), readme, re.S)
    if not m:
        problemi.append("manca il blocco del prompt %s" % nome)
        continue
    blocco = "\n".join(r.strip() for r in m.group(1).splitlines()).strip()
    file_ = open(os.path.join(demo, nome + ".txt"), encoding="utf-8").read().strip()
    if blocco != file_:
        problemi.append("il blocco %s non è il file %s.txt" % (nome, nome))
for vietata in ("smentit", "FACT-", "M8-X", "X-3", "X-4", "/home/", "sk-ant-"):
    if vietata in readme:
        problemi.append("«%s»" % vietata)
for parola in ("oggi", "domani", "pausa", "pranzo"):
    if re.search(r"\b%s\b" % parola, readme):
        problemi.append("«%s»" % parola)
print("; ".join(problemi) or "README a posto")
PY
  expect "README: sezioni, frasi con l'indirizzo, prompt, niente di vietato" \
    0 "README a posto"
}

t_prepara() {
  local ws f
  if ! nuovo_ws ws; then
    fail "prepara_esercizio.sh M8-D02: $(tail -n 3 "${TMP}/prepara.log")"
    return
  fi
  pass "prepara_esercizio.sh M8-D02"
  for f in domanda.txt formato-breve.txt formato-lungo.txt sistema.txt \
      listino.json controlla_conto.py in_classe.sh .claude/settings.json; do
    vero "spazio di lavoro: ${f}" test -f "${ws}/${f}"
  done
  if [[ ! -e "${ws}/soluzione" && ! -e "${ws}/_docente" ]]; then
    pass "spazio di lavoro: niente soluzione/ né _docente/"
  else
    fail "spazio di lavoro: soluzione/ o _docente/"
  fi
  run "${RADICE}/tools/verifica.sh" M8-D02 --radice "${ws%/M8-D02}"
  expect "verifica.sh sul punto di partenza: 1" 1 \
    "Manca la cartella risposte/"
}

# --- Il controllo -----------------------------------------------------------

# Il costo atteso di una chiamata, scritto come lo stampa il controllo: il
# conto rifatto qui, dai cinque conteggi del JSON. Arguments: $1 il JSON.
# Outputs: l'importo con la virgola.
costo_atteso() {
  python3 -B -I -c 'import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
u = d["usage"]; c = u["cache_creation"]
v = (u["input_tokens"] * 0.10 + c["ephemeral_5m_input_tokens"] * 0.125
     + c["ephemeral_1h_input_tokens"] * 0.20
     + u["cache_read_input_tokens"] * 0.01 + u["output_tokens"] * 0.50) / 1e6
print(("%.6f" % v).replace(".", ","))' "$1"
}

t_controllo() {
  local j atteso
  nuova_serie j 3
  controlla "${j}"
  expect "controllo: tre coppie, tutto a posto, 0" 0 "confermata 3 su 3"
  expect_absent "controllo: nessun «non distinguibile»" "${NONDIST}"
  expect_absent "controllo: nessun «non confermata»" "${NONCONF}"
  expect "controllo: la somma dei token in entrata" 0 \
    "= input_tokens 3 + cache_creation "
  expect "controllo: /context è letto" 0 \
    "/context in claude -p: 0 turni, 0 token, 0,000000 \$: non è una"
  expect "controllo: /context non è una chiamata al modello" 0 \
    "non è una chiamata al modello."
  expect "controllo: la tabella di /context" 0 "System prompt"
  expect "controllo: la raccomandazione citata" 0 \
    "Ask for the answer you will read, not the one that looks thorough."
  expect "controllo: l'uscita 40 contro 640, con il rapporto" 0 \
    "uscita 40 → 640 token (×16,0)"
  expect "controllo: la frase sul prezzo dell'output, come dato" 0 \
    "Output tokens cost five times input tokens"
  expect "controllo: il rapporto dal listino, come dato" 0 "5,0 volte"
  expect "controllo: la differenza più grande è zero" 0 \
    "la differenza più grande è 0,000000"
  expect "controllo: il listino con la sua data" 0 "il listino è di 2026-11-10"
  expect "controllo: il totale di tutte le chiamate" 0 \
    "Come dati, tutte le 6 chiamate: turni 6"
  atteso="$(costo_atteso "${j}/lunga-1/risposta.json")"
  expect "controllo: il costo ricalcolato di lunga-1 è quello del JSON" 0 \
    "ricalcolato ${atteso}"
  rifai "${j}" breve-2 lettura
  rifai "${j}" lunga-2 lettura
  controlla "${j}"
  atteso="$(costo_atteso "${j}/lunga-2/risposta.json")"
  expect "controllo: la lettura dalla cache, al suo prezzo" 0 \
    "ricalcolato ${atteso}"
  expect "controllo: la lettura dalla cache, nella somma" 0 \
    "cache_creation 0 + cache_read"
  rifai "${j}" breve-2 cinque-minuti
  rifai "${j}" lunga-2 cinque-minuti
  controlla "${j}"
  atteso="$(costo_atteso "${j}/lunga-2/risposta.json")"
  expect "controllo: la scrittura a cinque minuti, al suo prezzo" 0 \
    "ricalcolato ${atteso}"
  rifai "${j}" lunga-1 costo-diverso
  controlla "${j}"
  expect "dato: total_cost_usd diverso, si stampa la differenza" 0 \
    "differenza 0,000123"
  expect "dato: la differenza non cambia l'uscita" 0 "confermata 3 su 3"
  rifai "${j}" lunga-1
  rifai "${j}" breve-3 pari
  rifai "${j}" lunga-3 pari
  controlla "${j}"
  expect "esito: risposte uguali, non distinguibile, 0" 0 \
    "esecuzione 3: uscita 40 → 40 token (×1,0); costo ricalcolato"
  expect "esito: la riga dice non distinguibile" 0 "${NONDIST}"
  expect "esito: la conta scende a 2 su 3" 0 "confermata 2 su 3"
  rifai "${j}" breve-3
  rifai "${j}" lunga-3 inversa
  controlla "${j}"
  expect "esito: la lunga più corta, non confermata, 0" 0 "${NONCONF}"
  expect "esito: la conta non è di 3 su 3" 0 "confermata 2 su 3"
  rifai "${j}" contesto contesto-costa
  controlla "${j}"
  expect "dato: /context che costa non è 'chiamata al modello'" 0 \
    "(dato) /context in claude -p: 1 turni, 12 token"
  expect_absent "dato: /context che costa, niente di «non è una chiamata»" \
    "non è una chiamata al modello."
}

t_mancanze() {
  local j
  nuova_serie j 2
  rm -r -- "${j}/lunga-2"
  controlla "${j}"
  expect "mancanza: un braccio che manca, 1" 1 "manca lunga-2/risposta.json"
  nuova_serie j 1
  rm -r -- "${j}/contesto"
  controlla "${j}"
  expect "mancanza: /context che manca, 1" 1 "manca contesto/risposta.json"
  nuova_serie j 1
  rifai "${j}" breve-1 errore
  controlla "${j}"
  expect "mancanza: una chiamata con is_error, 1" 1 \
    "breve-1/risposta.json: claude ha restituito un errore"
  nuova_serie j 1
  rifai "${j}" contesto contesto-errore
  controlla "${j}"
  expect "mancanza: /context con is_error, 1" 1 \
    "contesto/risposta.json: claude ha restituito un errore"
  nuova_serie j 1
  rifai "${j}" lunga-1 altro-modello
  controlla "${j}"
  expect "mancanza: una chiamata su Sonnet, 1" 1 \
    "non è su un solo modello Haiku (modelUsage: claude-sonnet-5-5)"
  nuova_serie j 1
  rifai "${j}" lunga-1 due-modelli
  controlla "${j}"
  expect "mancanza: una chiamata con due modelli, 1" 1 "su un solo modello"
  nuova_serie j 1
  rifai "${j}" breve-1 modello-vuoto
  controlla "${j}"
  expect "mancanza: modelUsage vuoto, 1" 1 "modelUsage: vuoto"
}

t_illeggibili() {
  local j
  nuova_serie j 1
  rifai "${j}" breve-1 json-rotto
  controlla "${j}"
  expect "illeggibile: un JSON rotto, 2" 2 "non si legge come JSON"
  nuova_serie j 1
  rifai "${j}" breve-1 senza-usage
  controlla "${j}"
  expect "illeggibile: niente usage, 2" 2 "«usage» non c'è"
  nuova_serie j 1
  rifai "${j}" lunga-1 usage-rotto
  controlla "${j}"
  expect "illeggibile: input_tokens non numerico, 2" 2 \
    "«input_tokens» non è un conteggio di token"
  nuova_serie j 1
  rifai "${j}" lunga-1 senza-costo
  controlla "${j}"
  expect "illeggibile: niente total_cost_usd, 2" 2 "total_cost_usd"
  nuova_serie j 1
  rifai "${j}" lunga-1 senza-split
  controlla "${j}"
  expect "illeggibile: niente usage.cache_creation, 2" 2 \
    "usage.cache_creation"
  j="$(mktemp -d "${TMP}/vuota.XXXXXX")"
  controlla "${j}"
  expect "illeggibile: una cartella senza esecuzioni, 2" 2 \
    "nessuna esecuzione"
  controlla "${TMP}/non-c-e"
  expect "illeggibile: una cartella che non c'è, 2" 2 "non esiste"
  controlla
  expect "uso: senza argomenti, 2" 2 "Uso:"
  controlla --aiuto
  expect "uso: un'opzione, 2" 2 "Uso:"
  # Il listino: il controllo legge quello accanto a sé.
  nuova_serie j 1
  mkdir -p "${TMP}/altrove" || exit 2
  cp -- "${D02}/demo/controlla_conto.py" "${TMP}/altrove/" || exit 2
  printf '{ rotto\n' > "${TMP}/altrove/listino.json" || exit 2
  run python3 -B -I "${TMP}/altrove/controlla_conto.py" "${j}"
  expect "illeggibile: un listino che non è JSON, 2" 2 "listino.json"
  printf '{"letto_il": "x", "pagina_prezzi": "y", %s\n' \
    '"modelli": {"haiku": {"input": 0}}}' \
    > "${TMP}/altrove/listino.json" || exit 2
  run python3 -B -I "${TMP}/altrove/controlla_conto.py" "${j}"
  expect "illeggibile: un listino senza i prezzi, 2" 2 "manca"
  rm -f -- "${TMP}/altrove/listino.json"
  run python3 -B -I "${TMP}/altrove/controlla_conto.py" "${j}"
  expect "illeggibile: nessun listino, 2" 2 "listino.json"
}

t_verifica() {
  local ws
  nuovo_ws ws || { fail "verifica: prepara_esercizio.sh"; return; }
  run "${D02}/verifica.sh" "${ws}"
  expect "verifica: senza risposte/, 1" 1 "Manca la cartella risposte/"
  mkdir -p "${ws}/risposte" || exit 2
  run "${D02}/verifica.sh" "${ws}"
  expect "verifica: risposte/ vuota, 1" 1 "nessuna esecuzione"
  rifai "${ws}/risposte" contesto
  rifai "${ws}/risposte" breve-1
  rifai "${ws}/risposte" lunga-1
  printf '%s\n' 'print("CONTROLLO FINTO")' \
    > "${ws}/controlla_conto.py" || exit 2
  run env PN_HANDSON_ROOT="${RADICE}" "${D02}/verifica.sh" "${ws}"
  expect "verifica: una coppia completa, 0, «Fatto»" 0 "${FATTO}"
  expect_absent "verifica: il controllo dell'elemento, non della copia" \
    "CONTROLLO FINTO"
  rm -r -- "${ws}/risposte/lunga-1"
  run "${D02}/verifica.sh" "${ws}"
  expect "verifica: una chiamata che manca, 1" 1 "manca lunga-1"
  run "${D02}/verifica.sh"
  expect "verifica: senza argomenti, 2" 2 "spazio di lavoro assente"
}

# --- in_classe.sh e live.sh -------------------------------------------------

t_in_classe() {
  local ws
  nuovo_ws ws || { fail "in_classe: prepara_esercizio.sh"; return; }
  finto "${D02}/demo/in_classe.sh" "${ws}" PN_ESECUZIONI=2
  expect "in_classe: due coppie, 0" 0 \
    "VERIFICA OK   il conto, sulle esecuzioni di risposte/"
  expect "in_classe: il comando sullo schermo" 0 "--no-session-persistence"
  expect "in_classe: --system-prompt sullo schermo" 0 "--system-prompt"
  expect "in_classe: /context sullo schermo" 0 "/context"
  expect "in_classe: la tabella di /context sullo schermo" 0 "System prompt"
  expect "in_classe: il confronto, sullo schermo" 0 "confermata 2 su 2"
  controlla_chiamate "${TMP}/finto.log" "${ws}" 2
  expect "in_classe: le chiamate, le cartelle, le opzioni, i bracci" 0 \
    "chiamate giuste"
  run git -C "${ws}" status --porcelain
  if [[ "${OUT}" == '?? risposte/' ]]; then
    pass "in_classe: lo spazio di lavoro cambia solo in risposte/"
  else
    fail "in_classe: git status «${OUT}»"
  fi
  run env PN_HANDSON_ROOT="${RADICE}" "${D02}/verifica.sh" "${ws}"
  expect "in_classe: poi verifica.sh, 0" 0 "${FATTO}"
}

t_live() {
  local ws
  nuovo_ws ws || { fail "live: prepara_esercizio.sh"; return; }
  finto "${D02}/_docente/live.sh" "${ws}"
  expect "live: tre coppie, 0" 0 "VERIFICA OK   verifica.sh dell'elemento"
  expect "live: il confronto, tre su tre" 0 "confermata 3 su 3"
  controlla_chiamate "${TMP}/finto.log" "${ws}" 3
  expect "live: le sette chiamate" 0 "chiamate giuste"
  run "${RADICE}/tools/verifica.sh" M8-D02 --radice "${ws%/M8-D02}"
  expect "live: poi tools/verifica.sh, 0" 0 "VERIFICA OK   M8-D02: fatto."
  run "${D02}/_docente/live.sh"
  expect "live: senza argomenti, 2" 2 "uso:"
}

t_precondizioni() {
  local ws s="${D02}/demo/in_classe.sh"
  nuovo_ws ws || { fail "precondizioni: prepara_esercizio.sh"; return; }
  precondizione "precondizione: una cartella che non è lo spazio" \
    "non è lo spazio di lavoro di M8-D02" "${s}" "${TMP}"
  precondizione "precondizione: nessuno spazio di lavoro" \
    "spazio di lavoro assente" "${s}" ""
  precondizione "precondizione: PN_ESECUZIONI 0" "PN_ESECUZIONI" \
    "${s}" "${ws}" "${TMP}/esca:${PATH}" PN_ESECUZIONI=0
  precondizione "precondizione: HANDSON_ENV claude-ai-pro" \
    "è un elemento claude-code-pro" "${s}" "${ws}" "${TMP}/esca:${PATH}" \
    HANDSON_ENV=claude-ai-pro
  precondizione "precondizione: senza python3" "manca lo strumento: python3" \
    "${s}" "${ws}" "${TMP}/senza_python"
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
  mv -- "${ws}/formato-lungo.txt" "${TMP}/f.txt" || exit 2
  git -C "${ws}" rm -q --cached formato-lungo.txt 2> /dev/null
  precondizione "precondizione: il formato che manca" \
    "file assente o illeggibile: formato-lungo.txt" "${s}" "${ws}"
  mv -- "${TMP}/f.txt" "${ws}/formato-lungo.txt" || exit 2
  git -C "${ws}" add -- formato-lungo.txt
  mv -- "${ws}/listino.json" "${TMP}/l.json" || exit 2
  git -C "${ws}" rm -q --cached listino.json 2> /dev/null
  precondizione "precondizione: il listino che manca" \
    "file assente o illeggibile: listino.json" "${s}" "${ws}"
  mv -- "${TMP}/l.json" "${ws}/listino.json" || exit 2
  git -C "${ws}" add -- listino.json
  precondizione "precondizione: senza tools/lib_handson.sh" \
    "lanciatelo dal repository, o date PN_HANDSON_ROOT" "${s}" "${ws}" \
    "${TMP}/esca:${PATH}" PN_HANDSON_ROOT="${TMP}/non-c-e"
}

t_fallita() {
  local ws
  nuovo_ws ws || { fail "fallita: prepara_esercizio.sh"; return; }
  modo "ko-se=sei sezioni"
  finto "${D02}/demo/in_classe.sh" "${ws}"
  modo
  expect "fallita: la chiamata del braccio lungo che fallisce, 1" 1 \
    "VERIFICA KO   lunga-1: claude -p è fallito"
  vero "fallita: ciò che c'era è in risposte/" \
    test -s "${ws}/risposte/breve-1/risposta.json"
  run "${D02}/verifica.sh" "${ws}"
  expect "fallita: verifica.sh dopo, 1" 1 "lunga-1/risposta.json"
  nuovo_ws ws || { fail "fallita: prepara_esercizio.sh"; return; }
  modo "ko-se=/context"
  finto "${D02}/demo/in_classe.sh" "${ws}"
  modo
  expect "fallita: /context che fallisce, 1" 1 \
    "VERIFICA KO   /context: claude -p è fallito"
}

# Gli script di M8-D02 e questo file, con shellcheck -x.
t_shellcheck() {
  local f
  for f in "${D02}/verifica.sh" "${D02}/_docente/live.sh" \
      "${D02}/demo/in_classe.sh" "${SELF}"; do
    if ( cd "${RADICE}" && shellcheck -x -- "${f}" ) > /dev/null 2>&1; then
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
      || { echo "test_m8_d02: manca ${t}" >&2; exit 2; }
  done
  [[ -f "${FINTO_PY}" ]] \
    || { echo "test_m8_d02: manca ${FINTO_PY}" >&2; exit 2; }
  handson::init_temp_base
  TMP="$(mktemp -d "${HANDSON_TEMP_BASE}/test_m8_d02.XXXXXX")" || exit 2
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
    echo "test_m8_d02: girati $((PASS + FAIL)) casi, attesi ${CASES}" >&2
    exit 2
  fi
  (( FAIL == 0 )) || exit 1
}

main "$@"
