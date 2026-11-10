#!/bin/bash
#
# test_m8_e01.sh -- le prove di M8-E01 «Quanto costa una risposta», per il
# docente (sta in _docente/, il materiale del docente):
#   - l'elemento: i file, il messaggio, il listino e il volume; il README con
#     le sue dieci sezioni, le frasi di Anthropic con il loro indirizzo, il
#     comando del passo 2 e la richiesta del passo 3; niente identificativi
#     interni, giornate o «smentita»;
#   - prepara_esercizio.sh e verifica.sh sul punto di partenza (1);
#   - verifica.py su JSON del claude finto: la soluzione (0), il confronto con
#     total_cost_usd (un dato: non cambia l'uscita), i formati dei numeri, i
#     conto.py che non vanno (1: non gira, non finisce, non stampa un numero,
#     ha i numeri scritti nel codice), il JSON che non va (1), i file che non
#     si leggono (2), gli usi sbagliati (2), mai un traceback;
#   - soluzione/conto.py;
#   - il comando del README e _docente/live.sh con il claude finto: una sola
#     chiamata, le opzioni del README, nessuna ANTHROPIC_API_KEY nell'ambiente
#     di claude, le precondizioni (2, nessuna chiamata), la chiamata che
#     fallisce (1);
#   - shellcheck -x sugli script e su questo file.
# Mai il claude vero: il finto e l'esca stanno davanti nel PATH, e la suite lo
# controlla prima di usarli. CASES è il numero dei casi: se ne girano di più o
# di meno la suite esce 2.
#
# Uso:    m8_costi_ottimizzazione/_docente/test_m8_e01.sh
# Uscita: 0 = tutti i casi passano · 1 = almeno un caso fallito · 2 =
#         precondizione (manca python3, git o shellcheck), o un numero di casi
#         diverso da CASES
set -uo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly MOD="${SELF%/_docente/*}"
readonly RADICE="${MOD%/*}"
E01="${MOD}/s6_costi_e_ottimizzazione/m8_e1_il_conto/M8-E01_il_conto"
readonly E01
readonly FINTO_PY="${MOD}/_docente/claude_finto_m8_e01.py"
# La libreria del repository, per la base dei file temporanei.
# shellcheck source=../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"
readonly CASES=148
# Il comando del passo 2 del README, su una riga: quello che il README deve
# dare e che i casi qui sotto eseguono.
# shellcheck disable=SC2016  # la riga si esegue con bash -c, nello spazio
COMANDO='claude -p "$(cat messaggio.txt)" --model haiku --effort low'
COMANDO+=' --output-format json --tools "" --strict-mcp-config'
COMANDO+=' --setting-sources project,local --permission-mode dontAsk'
COMANDO+=' --permission-prompts none --no-session-persistence'
COMANDO+=' > risposte/prima.json'
readonly COMANDO
readonly FATTO='Fatto: conto.py stampa il conto della chiamata e quello del mese'
readonly RIPRODUCE='il calcolo riproduce total_cost_usd'
readonly NON_RIPRODUCE='il calcolo non riproduce total_cost_usd'
readonly ALTRI='con altri numeri negli stessi file'
readonly BASE_CONTO='import json, re, sys
d = json.load(open("risposte/prima.json", encoding="utf-8"))
p = json.load(open("listino.json", encoding="utf-8"))["modelli"]["haiku"]
testo = open("volume.txt", encoding="utf-8").read()
v = dict(re.findall(r"(?m)^(\w+) = ([0-9]+)$", testo))
u = d["usage"]
c = u["cache_creation"]
costo = (u["input_tokens"] * p["input"]
         + c["ephemeral_5m_input_tokens"] * p["cache_write_5m"]
         + c["ephemeral_1h_input_tokens"] * p["cache_write_1h"]
         + u["cache_read_input_tokens"] * p["cache_read"]
         + u["output_tokens"] * p["output"]) / 1e6
mese = int(v["ticket_al_mese"]) * (
    int(v["token_input_per_ticket"]) * p["input"]
    + int(v["token_output_per_ticket"]) * p["output"]) / 1e6'
TMP=''
PASS=0
FAIL=0
SKIP=0
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
  "${RADICE}/tools/prepara_esercizio.sh" M8-E01 --radice "${__r}" \
    > "${TMP}/prepara.log" 2>&1 || return 1
  printf -v "$1" '%s' "${__r}/M8-E01"
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
  for t in readlink git; do
    ln -s "$(command -v "${t}")" "${TMP}/senza_python/${t}" || exit 2
  done
  ln -s "${TMP}/esca/claude" "${TMP}/senza_python/claude" || exit 2
  for t in readlink python3 git; do
    ln -s "$(command -v "${t}")" "${TMP}/senza_claude/${t}" || exit 2
  done
  t="$(PATH="${TMP}/finto:${PATH}" command -v claude)"
  if [[ "${t}" != "${TMP}/finto/claude" ]]; then
    echo "test_m8_e01: nel PATH di prova claude è ${t}, non il finto" >&2
    exit 2
  fi
  modo
}

# Il passo 2 del README, così come si legge lì, con il finto al posto di
# claude: risposte/prima.json nello spazio di lavoro.
# Arguments: $1 lo spazio di lavoro.
chiamata_finta() {
  mkdir -p "$1/risposte" || exit 2
  ( cd "$1" && PATH="${TMP}/finto:${PATH}" bash -c "${COMANDO}" ) \
    < /dev/null || { echo "test_m8_e01: il finto non riesce" >&2; exit 2; }
}

# Cambia risposte/prima.json con il codice Python dato, su d (il JSON).
# Arguments: $1 lo spazio di lavoro, $2 il codice.
ritocca() {
  python3 -B -I - "$1/risposte/prima.json" "$2" <<'PY' \
    || { echo "test_m8_e01: ritocca non riesce" >&2; exit 2; }
import json, sys
percorso, codice = sys.argv[1:3]
d = json.load(open(percorso, encoding="utf-8"))
exec(codice)
json.dump(d, open(percorso, "w", encoding="utf-8"), ensure_ascii=False)
PY
}

# conto.py: BASE_CONTO (i calcoli giusti) e poi le righe date.
# Arguments: $1 lo spazio di lavoro, poi le righe.
conto_con() {
  local ws="$1"
  shift
  { printf '%s\n' "${BASE_CONTO}"; printf '%s\n' "$@"; } > "${ws}/conto.py" \
    || exit 2
}

# verifica.sh dell'elemento; RC e OUT come run.
# Arguments: $1 lo spazio di lavoro, poi facoltative le variabili NOME=valore.
verifica_ws() {
  local ws="$1"
  shift
  run env "$@" "${E01}/verifica.sh" "${ws}"
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

# La chiamata di un registro del finto, contro il comando del README: una
# sola, le stesse opzioni, il messaggio, dallo spazio di lavoro, senza chiave
# né effort nell'ambiente, con STDIN vuoto.
# Arguments: $1 il registro, $2 lo spazio di lavoro.
controlla_chiamata() {
  run python3 -B -I - "$1" "$2" "${COMANDO}" <<'PY'
import json, os, shlex, sys
log, ws, comando = sys.argv[1:4]
chiamate = [json.loads(r) for r in open(log, encoding="utf-8")]
problemi = []
if len(chiamate) != 1:
    problemi.append("%d chiamate invece di una" % len(chiamate))
else:
    c = chiamate[0]
    argv = c["argv"]
    fine = argv.index("--")
    def coppie(a):
        fuori, j = {}, 0
        conValore = {"--model", "--effort", "--output-format", "--tools",
                     "--setting-sources", "--permission-mode",
                     "--permission-prompts"}
        while j < len(a):
            if a[j] in conValore:
                fuori[a[j]] = a[j + 1]
                j += 2
            else:
                fuori[a[j]] = True
                j += 1
        return fuori
    attese = shlex.split(comando)
    # claude -p "$(cat messaggio.txt)" … > risposte/prima.json
    attese = attese[3:attese.index(">")]
    if coppie(argv[:fine]) != {**coppie(attese), "-p": True}:
        problemi.append("le opzioni: %s" % (argv[:fine],))
    if any("dangerously" in a or "bypassPermissions" in a for a in argv) \
            or "--allowedTools" in argv:
        problemi.append("salta i permessi o ha --allowedTools")
    messaggio = open(os.path.join(ws, "messaggio.txt"), encoding="utf-8").read().strip()
    if argv[fine + 1:] != [messaggio] or c["prompt"] != messaggio:
        problemi.append("il prompt non è il messaggio")
    if os.path.realpath(c["cwd"]) != os.path.realpath(ws):
        problemi.append("non parte dallo spazio di lavoro: %s" % c["cwd"])
    if c["chiave"] or c["effort"]:
        problemi.append("ANTHROPIC_API_KEY o CLAUDE_CODE_EFFORT_LEVEL")
    if not c["stdin_nullo"]:
        problemi.append("STDIN non è /dev/null")
print("; ".join(problemi) or "chiamata giusta")
PY
}

# --- L'elemento -------------------------------------------------------------

t_elemento() {
  local f
  for f in README.md verifica.sh verifica.py esercizio/messaggio.txt \
      esercizio/listino.json esercizio/volume.txt _docente/live.sh \
      soluzione/conto.py soluzione/LEGGIMI.md; do
    vero "elemento: ${f}" test -f "${E01}/${f}"
  done
  for f in verifica.sh _docente/live.sh; do
    vero "elemento: ${f} eseguibile" test -x "${E01}/${f}"
  done
  run python3 -B -I - "${E01}" <<'PY'
import json, os, re, sys
item = sys.argv[1]
leggi = lambda p: open(os.path.join(item, p), encoding="utf-8").read()
problemi = []
messaggio = leggi("esercizio/messaggio.txt")
if len(messaggio.strip().splitlines()) != 1 or "@" in messaggio:
    problemi.append("messaggio.txt: una riga, nessun indirizzo")
if not re.search(r"\b(Esempio|Prova|Fittizio|Campione|Modello|Bozza|Simulato|"
                 r"Inventato|Ipotetico|Immaginario|Provvisorio|Fantasia)\b",
                 messaggio):
    problemi.append("messaggio.txt: un cognome della lista")
volume = dict(re.findall(r"(?m)^(\w+) = ([0-9]+)$", leggi("esercizio/volume.txt")))
if volume != {"ticket_al_mese": "10000", "token_input_per_ticket": "1000",
              "token_output_per_ticket": "150"}:
    problemi.append("volume.txt: %s" % volume)
listino = json.loads(leggi("esercizio/listino.json"))
ATTESI = {"haiku": (0.10, 0.50, 0.125, 0.20, 0.01),
          "sonnet": (2, 10, 2.5, 4, 0.10), "opus": (4, 20, 5, 8, 0.20)}
CHIAVI = ("input", "output", "cache_write_5m", "cache_write_1h", "cache_read")
for alias, attesi in ATTESI.items():
    trovati = tuple(listino["modelli"][alias][k] for k in CHIAVI)
    if trovati != attesi:
        problemi.append("listino.json, %s: %s" % (alias, trovati))
if listino.get("letto_il") != "2026-11-10":
    problemi.append("listino.json: la data")
if listino.get("pagina_prezzi") != "https://platform.claude.com/docs/en/about-claude/pricing":
    problemi.append("listino.json: la pagina")
if listino.get("pagina_haiku") != \
        "https://platform.claude.com/docs/en/models/haiku-5-5/overview":
    problemi.append("listino.json: la pagina di Haiku")
print("; ".join(problemi) or "dati a posto")
PY
  expect "i dati: il messaggio, il volume, il listino con data e pagine" 0 \
    "dati a posto"
  run python3 -B -I - "${E01}" <<'PY'
import os, re, sys
item = sys.argv[1]
problemi = []
for nome in ("esercizio/messaggio.txt", "esercizio/listino.json",
             "esercizio/volume.txt", "verifica.sh", "verifica.py", "README.md"):
    testo = open(os.path.join(item, nome), encoding="utf-8").read()
    for vietata in ("FACT-", "M8-X", "M7-X", "X-3", "/home/", "smentit"):
        if vietata in testo:
            problemi.append("%s: «%s»" % (nome, vietata))
    for parola in ("oggi", "domani", "stamattina", "pausa", "pranzo"):
        if re.search(r"\b%s\b" % parola, testo, re.I):
            problemi.append("%s: «%s»" % (nome, parola))
print("; ".join(problemi) or "niente di vietato")
PY
  expect "i file visibili: niente di vietato" 0 "niente di vietato"
}

# Il README: le dieci sezioni, le frasi di Anthropic con l'indirizzo, il
# comando del passo 2, la richiesta del passo 3.
t_readme() {
  run python3 -B -I - "${E01}" "${COMANDO}" <<'PY'
import os, re, sys
item, comando = sys.argv[1:3]
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
for titolo in ("## Punto di partenza (tools/prepara_esercizio.sh M8-E01)",
               "## Verifica (tools/verifica.sh M8-E01)"):
    if titolo not in readme:
        problemi.append("il titolo «%s»" % titolo)
COSTI = "https://platform.claude.com/docs/en/about-claude/models/" \
    "optimizing-for-cost-and-intelligence"
frasi = [
    ("Price each of the five token counts in a response’s usage at its own "
     "rate", COSTI),
    ("Claude Code computes the dollar figure locally from token counts at "
     "list price", "https://code.claude.com/docs/en/costs"),
    ("Both figures are client-side estimates and can differ from your actual "
     "bill.", "https://code.claude.com/docs/en/headless"),
    ("With --output-format json, the response payload includes total_cost_usd "
     "and a per-model cost breakdown",
     "https://code.claude.com/docs/en/headless"),
    ("Total input tokens in a request is the summation of input_tokens, "
     "cache_creation_input_tokens, and cache_read_input_tokens.",
     "https://platform.claude.com/docs/en/api/messages/create"),
    ("Claude Code reports one-hour cache writes under "
     "ephemeral_1h_input_tokens and five-minute cache writes under "
     "ephemeral_5m_input_tokens.", "https://code.claude.com/docs/en/prompt-caching"),
]
piano = " ".join(readme.split())
for frase, url in frasi:
    if frase not in piano:
        problemi.append("manca «%s»" % frase[:40])
    if url not in readme:
        problemi.append("manca %s" % url)
for url in ("https://platform.claude.com/docs/en/about-claude/pricing",
            "https://platform.claude.com/docs/en/models/haiku-5-5/overview"):
    if url not in readme:
        problemi.append("manca %s" % url)
unito = re.sub(r"\\\n\s*", "", readme)
if comando not in unito:
    problemi.append("il comando del passo 2")
if "mkdir -p risposte" not in readme or "python3 conto.py" not in readme \
        or "tools/verifica.sh M8-E01" not in readme:
    problemi.append("i passi 2, 3 e 4")
m = re.search(r"<!-- prompt richiesta -->\n(.*?)\n\s*<!-- /prompt richiesta -->",
              readme, re.S)
if not m:
    problemi.append("il blocco della richiesta")
else:
    testo = " ".join(m.group(1).split())
    parole = len(testo.split())
    if not 0 < parole < 60:
        problemi.append("la richiesta: %d parole" % parole)
    for nome in ("conto.py", "risposte/prima.json", "listino.json",
                 "volume.txt", "total_cost_usd"):
        if nome not in testo:
            problemi.append("la richiesta non nomina %s" % nome)
    if re.search(r"</?(role|context|instructions)>", testo):
        problemi.append("la richiesta ha i tag: è di classe P")
print("; ".join(problemi) or "README a posto")
PY
  expect "README: sezioni, frasi con l'indirizzo, comando, richiesta" 0 \
    "README a posto"
  run grep -c "2\.1\.322" "${E01}/README.md"
  if (( RC == 0 )) && (( OUT >= 1 )); then
    pass "README: la versione di Claude Code delle misure"
  else
    fail "README: manca la versione di Claude Code (rc=${RC}): ${OUT}"
  fi
}

t_prepara() {
  local ws f
  if ! nuovo_ws ws; then
    fail "prepara_esercizio.sh M8-E01: $(tail -n 3 "${TMP}/prepara.log")"
    return
  fi
  pass "prepara_esercizio.sh M8-E01"
  for f in messaggio.txt listino.json volume.txt .claude/settings.json; do
    vero "spazio di lavoro: ${f}" test -f "${ws}/${f}"
  done
  if [[ ! -e "${ws}/soluzione" && ! -e "${ws}/_docente" \
      && ! -e "${ws}/verifica.py" ]]; then
    pass "spazio di lavoro: niente soluzione/, _docente/ né verifica.py"
  else
    fail "spazio di lavoro: soluzione/, _docente/ o verifica.py"
  fi
  run "${RADICE}/tools/verifica.sh" M8-E01 --radice "${ws%/M8-E01}"
  expect "tools/verifica.sh sul punto di partenza: 1" 1 \
    "Manca risposte/prima.json"
  expect "tools/verifica.sh sul punto di partenza: anche conto.py" 1 \
    "Manca conto.py"
  expect "tools/verifica.sh sul punto di partenza: «non ancora»" 1 \
    "NON ANCORA    M8-E01"
}

# --- Il controllo -----------------------------------------------------------

t_soluzione_nel_controllo() {
  local ws
  nuovo_ws ws || { fail "controllo: prepara_esercizio.sh"; return; }
  chiamata_finta "${ws}"
  cp -- "${E01}/soluzione/conto.py" "${ws}/conto.py" || exit 2
  printf '%s\n' 'print("CONTROLLO FINTO")' > "${ws}/verifica.py" || exit 2
  verifica_ws "${ws}" PN_HANDSON_ROOT="${RADICE}"
  expect "controllo: la soluzione, 0, «Fatto»" 0 "${FATTO}"
  expect_absent "controllo: il controllo dell'elemento, non della copia" \
    "CONTROLLO FINTO"
  expect "controllo: il totale ricalcolato" 0 "totale ricalcolato"
  expect "controllo: il costo, 0,000866 $" 0 '0,000866 $'
  expect "controllo: la riga «riproduce», con la differenza" 0 "${RIPRODUCE}"
  expect "controllo: la differenza è un dato" 0 "(dato) differenza dal ricalcolo"
  expect_absent "controllo: nessun «non riproduce»" "${NON_RIPRODUCE}"
  expect "controllo: i token in entrata sommati" 0 "12412"
  expect "controllo: il mese, 1,75 $" 0 '1,75 $'
  expect "controllo: la prova con altri numeri" 0 "${ALTRI}"
  expect "controllo: il conto della copia" 0 '0,449050 $'
  expect "controllo: il mese della copia" 0 '49,00 $'
  run "${RADICE}/tools/verifica.sh" M8-E01 --radice "${ws%/M8-E01}"
  expect "tools/verifica.sh: «fatto»" 0 "VERIFICA OK   M8-E01: fatto."
  ritocca "${ws}" 'd["total_cost_usd"] = 0.01'
  verifica_ws "${ws}"
  expect "dato: total_cost_usd diverso non cambia l'uscita, 0" 0 "${FATTO}"
  expect "dato: la riga «non riproduce»" 0 "${NON_RIPRODUCE}"
  expect "dato: la differenza stampata" 0 '0,009134 $'
  expect_absent "dato: nessun «riproduce»" "${RIPRODUCE} entro"
}

t_formati() {
  local ws
  nuovo_ws ws || { fail "formati: prepara_esercizio.sh"; return; }
  chiamata_finta "${ws}"
  conto_con "${ws}" 'print("%.6f" % costo)' 'print("%.2f" % mese)'
  verifica_ws "${ws}"
  expect "formati: all'inglese, 0" 0 "${FATTO}"
  conto_con "${ws}" 'print(("%.6f $" % costo).replace(".", ","))' \
    'print(("%.2f $" % mese).replace(".", ","))'
  verifica_ws "${ws}"
  expect "formati: all'italiana, 0" 0 "${FATTO}"
  conto_con "${ws}" 'print("$%.6f" % costo)' 'print("Un mese: $%.2f." % mese)'
  verifica_ws "${ws}"
  expect "formati: il dollaro davanti, il punto finale, 0" 0 "${FATTO}"
  conto_con "${ws}" 'print("%.4e" % costo)' 'print("%.2f" % mese)'
  verifica_ws "${ws}"
  expect "formati: la notazione esponenziale, 0" 0 "${FATTO}"
  conto_con "${ws}" 'print(costo)' 'print(mese)'
  verifica_ws "${ws}"
  expect "formati: i float di python, 0" 0 "${FATTO}"
  conto_con "${ws}" 'print("%.6f" % (costo + 0.00005))' 'print("%.2f" % mese)'
  verifica_ws "${ws}"
  expect "formati: entro il centesimo di centesimo, 0" 0 "${FATTO}"
  expect "formati: la differenza del conto si vede" 0 '0,000050 $'
  conto_con "${ws}" 'sys.stdout.buffer.write(b"\xff\xfe costo\n")' \
    'print("%.6f" % costo)' 'print("%.2f" % mese)'
  verifica_ws "${ws}"
  expect "formati: byte che non sono UTF-8, 0, mai un traceback" 0 "${FATTO}"
  printf 'ticket_al_mese = 10000000\ntoken_input_per_ticket = 1000\n%s\n' \
    'token_output_per_ticket = 150' > "${ws}/volume.txt" || exit 2
  conto_con "${ws}" 'print("%.6f" % costo)' \
    'print("{:,.2f}".format(mese).replace(",", "X").replace(".", ",").replace("X", "."))'
  verifica_ws "${ws}"
  expect "formati: le migliaia col punto, e il volume dello spazio, 0" 0 \
    "${FATTO}"
  expect "formati: il mese da questo volume" 0 '1750,00 $'
}

t_conti_sbagliati() {
  local ws
  nuovo_ws ws || { fail "conti: prepara_esercizio.sh"; return; }
  chiamata_finta "${ws}"
  printf '%s\n' 'import sys' 'sys.stderr.write("boom\n")' 'sys.exit(3)' \
    > "${ws}/conto.py" || exit 2
  verifica_ws "${ws}"
  expect "conto: esce con 3, 1" 1 "conto.py non gira: è uscito con 3"
  expect "conto: lo STDERR si vede" 1 "boom"
  printf 'def (\n' > "${ws}/conto.py" || exit 2
  verifica_ws "${ws}"
  expect "conto: un errore di sintassi, 1" 1 "conto.py non gira"
  printf 'pass\n' > "${ws}/conto.py" || exit 2
  verifica_ws "${ws}"
  expect "conto: non stampa niente, 1" 1 \
    "conto.py non stampa il costo della chiamata"
  expect "conto: e nemmeno il mese" 1 "conto.py non stampa il costo del mese"
  conto_con "${ws}" 'print("%.2f" % costo)' 'print("%.2f" % mese)'
  verifica_ws "${ws}"
  expect "conto: due decimali soltanto, 1" 1 "almeno sei decimali"
  expect "conto: il ricalcolo si vede nel messaggio" 1 '0,000866 $'
  conto_con "${ws}" 'print("%.6f" % (costo + 0.0002))' 'print("%.2f" % mese)'
  verifica_ws "${ws}"
  expect "conto: fuori dalla tolleranza, 1" 1 \
    "conto.py non stampa il costo della chiamata"
  conto_con "${ws}" 'print("%.6f" % costo)'
  verifica_ws "${ws}"
  expect "conto: senza il mese, 1" 1 "conto.py non stampa il costo del mese"
  conto_con "${ws}" 'print("%.2f" % mese)'
  verifica_ws "${ws}"
  expect "conto: senza il costo, 1" 1 \
    "conto.py non stampa il costo della chiamata"
  conto_con "${ws}" 'print(d["total_cost_usd"])' 'print("%.2f" % mese)'
  verifica_ws "${ws}"
  expect "conto: copia total_cost_usd e non calcola, 1" 1 "${ALTRI}"
  printf '%s\n' 'print("0.000866")' 'print("1.75")' > "${ws}/conto.py" \
    || exit 2
  verifica_ws "${ws}"
  expect "conto: i numeri scritti nel codice, 1" 1 "${ALTRI}"
  conto_con "${ws}" \
    'p = {"input": 0.10, "output": 0.50, "cache_write_5m": 0.125,' \
    '     "cache_write_1h": 0.20, "cache_read": 0.01}' \
    'print("%.6f" % ((u["input_tokens"] * p["input"]
      + c["ephemeral_5m_input_tokens"] * p["cache_write_5m"]
      + c["ephemeral_1h_input_tokens"] * p["cache_write_1h"]
      + u["cache_read_input_tokens"] * p["cache_read"]
      + u["output_tokens"] * p["output"]) / 1e6))' \
    'print("%.2f" % (int(v["ticket_al_mese"]) * (
      int(v["token_input_per_ticket"]) * p["input"]
      + int(v["token_output_per_ticket"]) * p["output"]) / 1e6))'
  verifica_ws "${ws}"
  expect "conto: i prezzi scritti nel codice, 1" 1 "${ALTRI}"
  conto_con "${ws}" 'print("%.6f" % costo)' 'print("%.2f" % (mese * 2))'
  verifica_ws "${ws}"
  expect "conto: un mese sbagliato, 1" 1 "conto.py non stampa il costo del mese"
  printf '%s\n' 'import time' 'time.sleep(30)' > "${ws}/conto.py" || exit 2
  verifica_ws "${ws}" PN_TIMEOUT_CONTO=1
  expect "conto: non finisce, 1" 1 "conto.py non è finito"
  rm -f -- "${ws}/conto.py"
  verifica_ws "${ws}"
  expect "conto: manca, 1" 1 "Manca conto.py"
}

t_json() {
  local ws
  nuovo_ws ws || { fail "json: prepara_esercizio.sh"; return; }
  cp -- "${E01}/soluzione/conto.py" "${ws}/conto.py" || exit 2
  # Un caso: il nome, il ritocco, la parola attesa; ogni volta il JSON da capo.
  caso_json() {
    chiamata_finta "${ws}"
    ritocca "${ws}" "$2"
    verifica_ws "${ws}"
    expect "json: $1, 1" 1 "$3"
  }
  caso_json "senza usage" 'del d["usage"]' "non ha il campo usage"
  caso_json "un conteggio che è una parola" \
    'd["usage"]["output_tokens"] = "molti"' "non è un conteggio di token"
  caso_json "un conteggio negativo" 'd["usage"]["input_tokens"] = -1' \
    "non è un conteggio di token"
  caso_json "un conteggio booleano" \
    'd["usage"]["cache_read_input_tokens"] = True' \
    "non è un conteggio di token"
  caso_json "senza cache_creation" 'del d["usage"]["cache_creation"]' \
    "la suddivisione della scrittura in cache"
  caso_json "scritture che non tornano" \
    'd["usage"]["cache_creation_input_tokens"] = 999' "non torna"
  caso_json "senza total_cost_usd" 'del d["total_cost_usd"]' \
    "total_cost_usd"
  caso_json "total_cost_usd non numerico" 'd["total_cost_usd"] = "gratis"' \
    "total_cost_usd"
  caso_json "is_error" 'd["is_error"] = True' "non è finita bene"
  caso_json "type diverso" 'd["type"] = "altro"' "non è finita bene"
  caso_json "subtype d'errore" 'd["subtype"] = "error_max_turns"' \
    "non è finita bene"
  caso_json "senza modelUsage" 'del d["modelUsage"]' "modelUsage"
  caso_json "su sonnet" 'd["modelUsage"] = {"claude-sonnet-5-5": {}}' \
    "non su haiku"
  caso_json "due modelli" \
    'd["modelUsage"] = {"claude-haiku-5-5": {}, "claude-sonnet-5-5": {}}' \
    "più di un modello"
  : > "${ws}/risposte/prima.json"
  verifica_ws "${ws}"
  expect "json: un file vuoto, 1" 1 "non è un JSON"
  printf 'Credit balance too low\n' > "${ws}/risposte/prima.json" || exit 2
  verifica_ws "${ws}"
  expect "json: una riga di testo, 1" 1 "non è un JSON"
  printf '[1, 2]\n' > "${ws}/risposte/prima.json" || exit 2
  verifica_ws "${ws}"
  expect "json: una lista, 1" 1 "non è il JSON di una chiamata"
  rm -f -- "${ws}/risposte/prima.json"
  verifica_ws "${ws}"
  expect "json: manca, 1" 1 "Manca risposte/prima.json"
  mkdir -- "${ws}/risposte/prima.json" || exit 2
  verifica_ws "${ws}"
  expect "json: una cartella al posto del file, 2" 2 "non si legge"
  rmdir -- "${ws}/risposte/prima.json"
}

t_file() {
  local ws orig
  nuovo_ws ws || { fail "file: prepara_esercizio.sh"; return; }
  chiamata_finta "${ws}"
  cp -- "${E01}/soluzione/conto.py" "${ws}/conto.py" || exit 2
  orig="$(< "${ws}/listino.json")"
  rm -f -- "${ws}/listino.json"
  verifica_ws "${ws}"
  expect "listino: manca, 2" 2 "manca listino.json"
  printf 'non json\n' > "${ws}/listino.json" || exit 2
  verifica_ws "${ws}"
  expect "listino: non è JSON, 2" 2 "listino.json non è un JSON"
  printf '{"modelli": {"sonnet": {}}}\n' > "${ws}/listino.json" || exit 2
  verifica_ws "${ws}"
  expect "listino: senza haiku, 2" 2 "la voce del modello haiku"
  printf '%s\n' "${orig//0.125/\"caro\"}" > "${ws}/listino.json" || exit 2
  verifica_ws "${ws}"
  expect "listino: un prezzo che è una parola, 2" 2 "non è un numero"
  printf '%s\n' "${orig}" > "${ws}/listino.json" || exit 2
  orig="$(< "${ws}/volume.txt")"
  rm -f -- "${ws}/volume.txt"
  verifica_ws "${ws}"
  expect "volume: manca, 2" 2 "manca volume.txt"
  printf 'ticket: molti\n' > "${ws}/volume.txt" || exit 2
  verifica_ws "${ws}"
  expect "volume: una riga che non si legge, 2" 2 "riga non valida"
  printf 'ticket_al_mese = 10000\n' > "${ws}/volume.txt" || exit 2
  verifica_ws "${ws}"
  expect "volume: una voce che manca, 2" 2 "manca token_input_per_ticket"
  printf 'ticket_al_mese = 0\ntoken_input_per_ticket = 1000\n%s\n' \
    'token_output_per_ticket = 150' > "${ws}/volume.txt" || exit 2
  verifica_ws "${ws}"
  expect "volume: zero ticket, 2" 2 "positivi"
  printf '%s\n' "${orig}" > "${ws}/volume.txt" || exit 2
  verifica_ws "${ws}"
  expect "file: rimessi a posto, 0" 0 "${FATTO}"
  verifica_ws "${ws}" PN_TIMEOUT_CONTO=abc
  expect "env: PN_TIMEOUT_CONTO non è un numero, 2" 2 "PN_TIMEOUT_CONTO"
  run python3 -B -I "${E01}/verifica.py"
  expect "uso: senza argomenti, 2" 2 "Uso:"
  run python3 -B -I "${E01}/verifica.py" --aiuto
  expect "uso: un'opzione, 2" 2 "Uso:"
  run python3 -B -I "${E01}/verifica.py" "${TMP}/non-c-e"
  expect "uso: uno spazio di lavoro che non c'è, 2" 2 "non esiste"
  run "${E01}/verifica.sh"
  expect "verifica.sh: senza argomenti, 2" 2 "spazio di lavoro assente"
  run "${E01}/verifica.sh" "${TMP}/non-c-e"
  expect "verifica.sh: una cartella che non c'è, 2" 2 "spazio di lavoro assente"
}

t_listino_cambiato() {
  local ws
  nuovo_ws ws || { fail "listino: prepara_esercizio.sh"; return; }
  chiamata_finta "${ws}"
  cp -- "${E01}/soluzione/conto.py" "${ws}/conto.py" || exit 2
  python3 -B -I -c 'import json, sys
p = sys.argv[1]
d = json.load(open(p, encoding="utf-8"))
d["modelli"]["haiku"]["output"] = 0
json.dump(d, open(p, "w", encoding="utf-8"))' "${ws}/listino.json"
  verifica_ws "${ws}"
  expect "listino cambiato nello spazio di lavoro, 1" 1 \
    "listino.json è cambiato"
}

t_soluzione_script() {
  local ws
  nuovo_ws ws || { fail "soluzione: prepara_esercizio.sh"; return; }
  chiamata_finta "${ws}"
  cp -- "${E01}/soluzione/conto.py" "${ws}/conto.py" || exit 2
  run bash -c "cd '${ws}' && python3 -B -I conto.py"
  expect "soluzione: gira, 0" 0 "Costo della chiamata"
  expect "soluzione: il costo all'italiana" 0 '0,000866 $'
  expect "soluzione: total_cost_usd per confronto" 0 "total_cost_usd del JSON"
  expect "soluzione: il mese" 0 '1,75 $'
  rm -f -- "${ws}/risposte/prima.json"
  run bash -c "cd '${ws}' && python3 -B -I conto.py"
  expect "soluzione: senza prima.json, 2, un messaggio" 2 "prima.json"
  expect_absent "soluzione: mai un traceback" "Traceback"
}

# --- Il comando del README e live.sh ----------------------------------------

t_comando() {
  local ws
  nuovo_ws ws || { fail "comando: prepara_esercizio.sh"; return; }
  : > "${TMP}/finto.log"
  chiamata_finta "${ws}"
  vero "comando del README: scrive risposte/prima.json" \
    test -s "${ws}/risposte/prima.json"
  run python3 -B -I - "${TMP}/finto.log" "${COMANDO}" <<'PY'
import json, shlex, sys
log, comando = sys.argv[1:3]
chiamate = [json.loads(r) for r in open(log, encoding="utf-8")]
attese = shlex.split(comando)
attese = attese[3:attese.index(">")]
if len(chiamate) != 1 or chiamate[0]["argv"][0] != "-p":
    print("una chiamata con -p: %s" % chiamate)
else:
    # Il finto ha ricevuto -p, il messaggio e poi le opzioni, così come sono
    # scritte nel README.
    print("opzioni giuste" if chiamate[0]["argv"][2:] == attese else
          "le opzioni: %s" % (chiamate[0]["argv"],))
PY
  expect "comando del README: le opzioni arrivano a claude" 0 "opzioni giuste"
}

t_live() {
  local ws
  nuovo_ws ws || { fail "live: prepara_esercizio.sh"; return; }
  finto "${E01}/_docente/live.sh" "${ws}"
  expect "live: 0, e il verdetto di verifica.sh" 0 \
    "VERIFICA OK   verifica.sh dell'elemento"
  expect "live: il comando di claude sullo schermo" 0 \
    "--no-session-persistence"
  expect "live: lo script della soluzione sullo schermo" 0 "conto.py"
  expect "live: l'uscita di verifica.sh si vede" 0 "${FATTO}"
  controlla_chiamata "${TMP}/finto.log" "${ws}"
  expect "live: la chiamata, le opzioni, la cartella, l'ambiente" 0 \
    "chiamata giusta"
  vero "live: risposte/prima.json" test -s "${ws}/risposte/prima.json"
  vero "live: conto.py è quello della soluzione" \
    cmp -s "${E01}/soluzione/conto.py" "${ws}/conto.py"
  run git -C "${ws}" status --porcelain
  if [[ "${OUT}" == $'?? conto.py\n?? risposte/' ]]; then
    pass "live: lo spazio di lavoro cambia solo in conto.py e risposte/"
  else
    fail "live: git status «${OUT}»"
  fi
  run "${RADICE}/tools/verifica.sh" M8-E01 --radice "${ws%/M8-E01}"
  expect "live: poi tools/verifica.sh, 0" 0 "VERIFICA OK   M8-E01: fatto."
  run "${E01}/_docente/live.sh"
  expect "live: senza argomenti, 2" 2 "uso:"
}

t_precondizioni() {
  local ws s="${E01}/_docente/live.sh"
  nuovo_ws ws || { fail "precondizioni: prepara_esercizio.sh"; return; }
  precondizione "precondizione: una cartella che non è lo spazio" \
    "non è lo spazio di lavoro di M8-E01" "${s}" "${TMP}"
  precondizione "precondizione: nessuno spazio di lavoro" \
    "spazio di lavoro assente" "${s}" ""
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
  printf 'pass\n' > "${ws}/conto.py" || exit 2
  precondizione "precondizione: conto.py c'è già" \
    "non è al punto di partenza" "${s}" "${ws}"
  rm -f -- "${ws}/conto.py"
  mv -- "${ws}/messaggio.txt" "${TMP}/messaggio.txt" || exit 2
  precondizione "precondizione: il messaggio che manca" \
    "file assente o illeggibile: messaggio.txt" "${s}" "${ws}"
  mv -- "${TMP}/messaggio.txt" "${ws}/messaggio.txt" || exit 2
}

t_fallita() {
  local ws
  nuovo_ws ws || { fail "fallita: prepara_esercizio.sh"; return; }
  modo ko
  finto "${E01}/_docente/live.sh" "${ws}"
  modo
  expect "fallita: claude che esce 1, 1" 1 "VERIFICA KO   la chiamata"
  if [[ ! -e "${ws}/conto.py" ]]; then
    pass "fallita: lo script non parte"
  else
    fail "fallita: c'è conto.py"
  fi
  nuovo_ws ws || { fail "fallita: prepara_esercizio.sh"; return; }
  modo errore
  finto "${E01}/_docente/live.sh" "${ws}"
  modo
  expect "fallita: un JSON con is_error, 1" 1 "VERIFICA KO"
  vero "fallita: ciò che c'era è in risposte/" \
    test -s "${ws}/risposte/prima.json"
  nuovo_ws ws || { fail "fallita: prepara_esercizio.sh"; return; }
  modo non-json
  finto "${E01}/_docente/live.sh" "${ws}"
  modo
  expect "fallita: un'uscita che non è JSON, conto.py non gira, 1" 1 \
    "VERIFICA KO   conto.py di soluzione/ è fallito"
}

# Gli script di M8-E01 e questo file, con shellcheck -x.
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
  for t in python3 git shellcheck; do
    command -v "${t}" > /dev/null 2>&1 \
      || { echo "test_m8_e01: manca ${t}" >&2; exit 2; }
  done
  [[ -f "${FINTO_PY}" ]] \
    || { echo "test_m8_e01: manca ${FINTO_PY}" >&2; exit 2; }
  handson::init_temp_base
  TMP="$(mktemp -d "${HANDSON_TEMP_BASE}/test_m8_e01.XXXXXX")" || exit 2
  trap 'chmod -R u+rwX "${TMP}" 2> /dev/null; rm -rf "${TMP}"' EXIT
  prepara_claude
  t_elemento
  t_readme
  t_prepara
  t_soluzione_nel_controllo
  t_formati
  t_conti_sbagliati
  t_json
  t_file
  t_listino_cambiato
  t_soluzione_script
  t_comando
  t_live
  t_precondizioni
  t_fallita
  t_shellcheck
  OUT="${TUTTO}"
  expect_absent "in nessuna uscita «smentita»" "smentita"
  expect_absent "in nessuna uscita un traceback" "Traceback"
  echo "PASS=${PASS} FAIL=${FAIL} SKIP=${SKIP}"
  if (( PASS + FAIL + SKIP != CASES )); then
    echo "test_m8_e01: girati $((PASS + FAIL + SKIP)) casi, attesi" \
      "${CASES}" >&2
    exit 2
  fi
  (( FAIL == 0 )) || exit 1
}

main "$@"
