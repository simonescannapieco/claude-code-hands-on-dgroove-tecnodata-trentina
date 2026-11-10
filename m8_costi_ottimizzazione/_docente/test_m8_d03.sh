#!/bin/bash
#
# test_m8_d03.sh -- le prove di M8-D03 «La cache, vista nel contatore», per il
# docente (sta in _docente/, il materiale del docente):
#   - l'elemento: i file, la domanda, il README con le sue dieci sezioni, le
#     frasi di Anthropic con il loro indirizzo, niente identificativi interni,
#     «smentita» o riferimenti alla giornata;
#   - prepara_esercizio.sh e verifica.sh sul punto di partenza (1);
#   - controlla_cache.py su JSON del claude finto: la tabella, le garanzie (1
#     se non valgono, ciascuna da sé), le chiamate che mancano o finite male
#     (1), i JSON che non si leggono e gli usi sbagliati (2), mai un traceback;
#   - verifica.sh: il controllo dell'elemento, mai quello dello spazio di
#     lavoro; risposte/ che manca o vuota (1); le precondizioni (2);
#   - demo/in_classe.sh e _docente/live.sh con il claude finto: quante
#     chiamate, in che ordine, da quale cartella, con quali opzioni, le cinque
#     chiamate diverse soltanto nel nome, il prefisso uguale nella serie e
#     un marcatore nuovo in ogni serie, nessuna ANTHROPIC_API_KEY, le
#     precondizioni (2, nessuna chiamata: l'esca), una chiamata fallita (1);
#   - shellcheck -x sugli script e su questo file.
# Mai il claude vero: il finto e l'esca stanno davanti nel PATH, e la suite lo
# controlla prima di usarli. CASES è il numero dei casi: se ne girano di più o
# di meno la suite esce 2.
#
# Uso:    m8_costi_ottimizzazione/_docente/test_m8_d03.sh
# Uscita: 0 = tutti i casi passano · 1 = almeno un caso fallito · 2 =
#         precondizione (manca python3, git, tar o shellcheck), o un numero di
#         casi diverso da CASES
set -uo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly MOD="${SELF%/_docente/*}"
readonly RADICE="${MOD%/*}"
D03="${MOD}/s6_costi_e_ottimizzazione/m8_5_la_cache"
D03+="/M8-D03_la_cache_nel_contatore"
readonly D03
readonly FINTO_PY="${MOD}/_docente/claude_finto_m8_d03.py"
# La libreria del repository, per la base dei file temporanei.
# shellcheck source=../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"
readonly CASES=121
FATTO='Fatto: ogni serie è stata messa alla prova;'
FATTO+=' gli esiti sono qui sopra.'
readonly FATTO
readonly NONCONF='non confermata in questa esecuzione'
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
  "${RADICE}/tools/prepara_esercizio.sh" M8-D03 --radice "${__r}" \
    > "${TMP}/prepara.log" 2>&1 || return 1
  printf -v "$1" '%s' "${__r}/M8-D03"
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
export FINTO_CACHE="${TMP}/cache.json"
FINTO_MODI="\$(cat "${TMP}/modi" 2> /dev/null)"
export FINTO_MODI
exec python3 -B -I "${FINTO_PY}" "\$@"
EOF
  chmod 755 "${TMP}/esca/claude" "${TMP}/finto/claude" || exit 2
  for t in readlink git tar; do
    ln -s "$(command -v "${t}")" "${TMP}/senza_python/${t}" || exit 2
  done
  ln -s "${TMP}/esca/claude" "${TMP}/senza_python/claude" || exit 2
  for t in readlink python3 git tar; do
    ln -s "$(command -v "${t}")" "${TMP}/senza_claude/${t}" || exit 2
  done
  t="$(PATH="${TMP}/finto:${PATH}" command -v claude)"
  if [[ "${t}" != "${TMP}/finto/claude" ]]; then
    echo "test_m8_d03: nel PATH di prova claude è ${t}, non il finto" >&2
    exit 2
  fi
  modo
}

# Una chiamata del finto. Arguments: $1 il modello, $2 il file del prefisso, $3
# il file d'uscita, $4 la cartella di partenza, poi le variabili NOME=valore.
finta() {
  local modello="$1" prefisso="$2" uscita="$3" cartella="$4"
  shift 4
  ( cd "${cartella}" && env "$@" "${TMP}/finto/claude" -p --model "${modello}" \
      --permission-mode dontAsk --permission-prompts none \
      --output-format json --setting-sources project,local --tools '' \
      --system-prompt-file "${prefisso}" --effort low --strict-mcp-config \
      --no-session-persistence -- "$(< "${D03}/demo/domanda.txt")" ) \
    < /dev/null > "${uscita}" \
    || { echo "test_m8_d03: il finto non scrive ${uscita}" >&2; exit 2; }
}

# Una cartella temporanea nuova. Outputs: il percorso.
cartella_temp() { mktemp -d "${TMP}/cartella.XXXXXX" || exit 2; }

# Rifà una chiamata, con i modi dati.
# Arguments: $1 la cartella delle chiamate, $2 il nome (1-prima, …), $3 i modi.
rifai() {
  local j="$1" nome="$2" modi="${3:-}" k="${2%%-*}" quale="${2#*-}"
  local modello=haiku
  local -a vars=(X_CLAUDE_FINTO=1)
  [[ "${quale}" != sonnet ]] || modello=sonnet
  [[ "${quale}" != senza-cache ]] || vars=(DISABLE_PROMPT_CACHING=1)
  modo "${modi}"
  mkdir -p "${j}/${nome}" || exit 2
  finta "${modello}" "${j}/${k}-prefisso.md" "${j}/${nome}/risposta.json" \
    "$(cartella_temp)" "${vars[@]}"
  modo
}

# Una serie intera, con un marcatore suo, nella cartella delle chiamate.
# Arguments: $1 la cartella, $2 il numero della serie, $3 il marcatore.
una_serie() {
  local j="$1" k="$2" quale
  printf 'Marcatore di questa serie: %s.\n\nTesto finto del prefisso %s.\n' \
    "$3" "$2" > "${j}/$2-prefisso.md" || exit 2
  for quale in prima seconda senza-cache sonnet haiku-di-nuovo; do
    rifai "${j}" "${k}-${quale}"
  done
}

# Una cartella nuova di chiamate, con $2 serie.
# Arguments: $1 la variabile da assegnare, $2 quante.
nuova_serie() {
  local __j k
  __j="$(mktemp -d "${TMP}/json.XXXXXX")" || exit 2
  rm -f -- "${TMP}/cache.json"
  for (( k = 1; k <= $2; k++ )); do
    una_serie "${__j}" "${k}" "$(printf 'CACHE-%08X' "${k}")"
  done
  printf -v "$1" '%s' "${__j}"
}

# controlla_cache.py dell'elemento; RC e OUT come run.
controlla() { run python3 -B -I "${D03}/demo/controlla_cache.py" "$@"; }

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

# Lo script con il finto davanti nel PATH e ANTHROPIC_API_KEY e
# CLAUDE_CODE_EFFORT_LEVEL impostate (lo script le deve togliere); il registro
# e la cache finta ripartono vuoti.
# Arguments: $1 lo script, $2 lo spazio di lavoro, poi le variabili NOME=valore.
finto() {
  local script="$1" w="$2"
  shift 2
  : > "${TMP}/finto.log"
  rm -f -- "${TMP}/cache.json"
  run env PATH="${TMP}/finto:${PATH}" HANDSON_NO_PAUSE=1 \
    ANTHROPIC_API_KEY=valore-finto CLAUDE_CODE_EFFORT_LEVEL=high \
    TMPDIR="${TMP}" "$@" "${script}" "${w}"
}

# Le chiamate di un registro del finto, contro le attese: quante, in che
# ordine, da quale cartella, con quali opzioni; le cinque chiamate diverse
# soltanto in ciò che il nome dice; il prefisso uguale nella serie e con un
# marcatore nuovo a ogni serie.
# Arguments: $1 il registro, $2 lo spazio di lavoro, $3 quante serie.
controlla_chiamate() {
  run python3 -B -I - "$1" "$2" "$3" <<'PY'
import json, os, re, sys
log, ws, n = sys.argv[1:4]
n = int(n)
leggi = lambda p: open(p, encoding="utf-8").read()
chiamate = [json.loads(r) for r in leggi(log).splitlines()]
VALORE = {"--model", "--effort", "--output-format", "--setting-sources",
          "--permission-mode", "--permission-prompts", "--tools",
          "--system-prompt-file"}
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
domanda = leggi(os.path.join(ws, "domanda.txt")).strip()
kb = os.path.join(ws, "progetti", "assistenza-clienti", "kb")
atteso = ("\n" + leggi(os.path.join(kb, "kb-10-trasloco.md"))
          + "\n" + leggi(os.path.join(kb, "kb-13-telefono-di-casa-muto.md")))
if len(chiamate) != 5 * n:
    problemi.append("%d chiamate invece di %d" % (len(chiamate), 5 * n))
fisse = (("--effort", "low"), ("--output-format", "json"),
         ("--setting-sources", "project,local"), ("--tools", ""),
         ("--permission-mode", "dontAsk"), ("--permission-prompts", "none"))
marcatori = []
for s in range(n):
    gruppo = chiamate[5 * s:5 * s + 5]
    serie = s + 1
    modelli = ("haiku", "haiku", "haiku", "sonnet", "haiku")
    spente = (None, None, "1", None, None)
    if len(gruppo) != 5:
        problemi.append("serie %d: %d chiamate" % (serie, len(gruppo)))
        continue
    prefisso = os.path.realpath(os.path.join(ws, "risposte",
                                             "%d-prefisso.md" % serie))
    for i, c in enumerate(gruppo):
        nome = "serie %d, chiamata %d" % (serie, i + 1)
        o, resto = opzioni(c)
        for k, v in fisse:
            if o.get(k) != v:
                problemi.append("%s: %s" % (nome, k))
        for k in ("-p", "--strict-mcp-config", "--no-session-persistence"):
            if o.get(k) is not True:
                problemi.append("%s: %s" % (nome, k))
        if any("dangerously" in a or "bypassPermissions" in a
               for a in c["argv"]) or "--allowedTools" in o:
            problemi.append("%s: salta i permessi o ha --allowedTools" % nome)
        if o.get("--model") != modelli[i]:
            problemi.append("%s: il modello è %s" % (nome, o.get("--model")))
        if resto != [domanda]:
            problemi.append("%s: il prompt non è la domanda" % nome)
        if os.path.realpath(o.get("--system-prompt-file", "")) != prefisso:
            problemi.append("%s: --system-prompt-file" % nome)
        if c["sistema"] != leggi(prefisso):
            problemi.append("%s: il prefisso letto non è quello" % nome)
        if c["spenta"] != spente[i]:
            problemi.append("%s: cache spenta %s" % (nome, c["spenta"]))
        cwd = os.path.realpath(c["cwd"])
        vs = os.path.realpath(ws)
        if cwd == vs or cwd.startswith(vs + "/"):
            problemi.append("%s: dentro lo spazio di lavoro" % nome)
        if c["chiave"] or c["effort"]:
            problemi.append("%s: ANTHROPIC_API_KEY o EFFORT" % nome)
        if not c["stdin_nullo"]:
            problemi.append("%s: STDIN non è /dev/null" % nome)
    # Le cinque chiamate della serie differiscono solo nel modello della quarta
    # (l'ambiente della terza si guarda qui sopra).
    def senza_modello(c):
        o, resto = opzioni(c)
        o = dict(o)
        o.pop("--model", None)
        return json.dumps([sorted(o.items()), resto])
    if len({senza_modello(c) for c in gruppo}) != 1:
        problemi.append("serie %d: le chiamate differiscono" % serie)
    if len({c["cwd"] for c in gruppo}) != 1:
        problemi.append("serie %d: cartelle di partenza diverse" % serie)
    testo = gruppo[0]["sistema"]
    m = re.match(r"^Marcatore di questa serie: (CACHE-[0-9A-F]{8})\.\n", testo)
    if not m:
        problemi.append("serie %d: la riga del marcatore" % serie)
        continue
    marcatori.append(m.group(1))
    if testo != m.group(0) + atteso:
        problemi.append("serie %d: il prefisso non è marcatore e procedure"
                        % serie)
if len(set(marcatori)) != len(marcatori):
    problemi.append("serie con lo stesso marcatore: %s" % marcatori)
if len({c["cwd"] for c in chiamate}) != n:
    problemi.append("le serie hanno cartelle di partenza ripetute")
print("; ".join(problemi) or "chiamate giuste")
PY
}

# --- L'elemento -------------------------------------------------------------

t_elemento() {
  local f
  for f in README.md verifica.sh progetti.txt demo/domanda.txt \
      demo/controlla_cache.py demo/in_classe.sh _docente/live.sh \
      soluzione/LEGGIMI.md; do
    vero "elemento: ${f}" test -f "${D03}/${f}"
  done
  for f in verifica.sh _docente/live.sh demo/in_classe.sh; do
    vero "elemento: ${f} eseguibile" test -x "${D03}/${f}"
  done
  run python3 -B -I - "${D03}" <<'PY'
import os, sys
item = sys.argv[1]
leggi = lambda p: open(os.path.join(item, p), encoding="utf-8").read()
problemi = []
domanda = leggi("demo/domanda.txt")
if len(domanda.splitlines()) != 1 or len(domanda.split()) > 40:
    problemi.append("domanda.txt: una riga, breve")
if leggi("progetti.txt").split() != ["progetti/assistenza-clienti"]:
    problemi.append("progetti.txt")
print("; ".join(problemi) or "testi a posto")
PY
  expect "i testi della demo: la domanda, progetti.txt" 0 "testi a posto"
}

# Il README: le dieci sezioni, le frasi di Anthropic; niente identificativi
# interni, giornate, «smentita».
t_readme() {
  run python3 -B -I - "${D03}" <<'PY'
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
for titolo in ("## Punto di partenza (tools/prepara_esercizio.sh M8-D03)",
               "## Verifica (tools/verifica.sh M8-D03)"):
    if titolo not in readme:
        problemi.append("il titolo «%s»" % titolo)
CACHE = "https://code.claude.com/docs/en/prompt-caching"
API = "https://platform.claude.com/docs/en/build-with-claude/prompt-caching"
frasi = [
    ("Claude Code manages prompt caching automatically.", CACHE),
    ("Each model has its own cache.", CACHE),
    ("DISABLE_PROMPT_CACHING | Disable for all models", CACHE),
    ("Claude Code reports one-hour cache writes under "
     "ephemeral_1h_input_tokens and five-minute cache writes under "
     "ephemeral_5m_input_tokens.", CACHE),
    ("cache_creation_input_tokens: Number of tokens written to the cache "
     "when creating a new entry", API),
    ("cache_read_input_tokens: Number of tokens retrieved from the cache "
     "for this request", API),
    ("input_tokens: Number of input tokens that were not read from or "
     "used to create a cache", API),
    ("if both cache_creation_input_tokens and cache_read_input_tokens are "
     "0, the prompt was not cached", API),
    ("Total input tokens in a request is the summation of input_tokens, "
     "cache_creation_input_tokens, and cache_read_input_tokens.",
     "https://platform.claude.com/docs/en/api/messages/create"),
    ("512 tokens for Claude Fable 5.2 … Claude Opus 5.5, Claude Opus 5, "
     "Claude Sonnet 5.5 … and Claude Haiku 5.5", API),
    ("Prompt caching references the entire prompt: tools, system, and "
     "messages (in that order), up to and including the block designated "
     "with cache_control.", API),
    ("Pro, Max, Ultra, Team, Enterprise, and Anthropic API: defaults to "
     "Opus 5.5", "https://code.claude.com/docs/en/model-config")]
piano = " ".join(readme.split())
for frase, url in frasi:
    if frase not in piano:
        problemi.append("manca «%s»" % frase[:40])
    if url not in readme:
        problemi.append("manca %s" % url)
for vietata in ("smentit", "FACT-", "M8-X", "X-3", "X-4", "/home/"):
    if vietata in readme:
        problemi.append("«%s»" % vietata)
for parola in ("oggi", "domani", "pausa", "pranzo"):
    if re.search(r"\b%s\b" % parola, readme):
        problemi.append("«%s»" % parola)
print("; ".join(problemi) or "README a posto")
PY
  expect "README: sezioni, frasi con l'indirizzo, niente di vietato" 0 \
    "README a posto"
}

t_prepara() {
  local ws f
  if ! nuovo_ws ws; then
    fail "prepara_esercizio.sh M8-D03: $(tail -n 3 "${TMP}/prepara.log")"
    return
  fi
  pass "prepara_esercizio.sh M8-D03"
  for f in domanda.txt controlla_cache.py in_classe.sh .claude/settings.json \
      progetti/assistenza-clienti/kb/kb-10-trasloco.md \
      progetti/assistenza-clienti/kb/kb-13-telefono-di-casa-muto.md; do
    vero "spazio di lavoro: ${f}" test -f "${ws}/${f}"
  done
  if [[ ! -e "${ws}/soluzione" && ! -e "${ws}/_docente" ]]; then
    pass "spazio di lavoro: niente soluzione/ né _docente/"
  else
    fail "spazio di lavoro: soluzione/ o _docente/"
  fi
  run "${RADICE}/tools/verifica.sh" M8-D03 --radice "${ws%/M8-D03}"
  expect "verifica.sh sul punto di partenza: 1" 1 \
    "Manca la cartella risposte/"
}

# --- Il controllo -----------------------------------------------------------

t_controllo() {
  local j
  # Una chiamata su un altro modello non vale per la garanzia.
  nuova_serie j 1
  rifai "${j}" "1-sonnet" altro-modello
  controlla "${j}"
  expect "controllo: il modello che ha risposto, 1" 1 \
    "non è su un solo modello"
  nuova_serie j 3
  controlla "${j}"
  expect "controllo: tre serie, tutto a posto, 0" 0 \
    "Come dati, tutte le 15 chiamate"
  expect_absent "controllo: nessun «non confermata»" "${NONCONF}"
  expect "controllo: la tabella delle chiamate" 0 "3-haiku-di-nuovo"
  expect "controllo: il marcatore della serie" 0 "marcatore CACHE-00000002"
  expect "controllo: la frase di Anthropic" 0 "Each model has its own cache"
  expect "controllo: la prima, confermata" 0 \
    "la prima chiamata scrive in cache"
  expect "controllo: con la cache spenta" 0 \
    "con DISABLE_PROMPT_CACHING=1 niente in cache"
  expect "controllo: su Sonnet" 0 "su Sonnet la cache di Haiku non vale"
  expect "controllo: di nuovo su Haiku" 0 "tornando su Haiku si legge di nuovo"
  expect "controllo: la seconda legge una parte" 0 \
    "un dato, non per forza tutto il prefisso"
  rifai "${j}" 3-prima "usage=2,2359,0,40"
  controlla "${j}"
  expect "controllo: il punto delle migliaia e i campi" 0 "2.359"
  rifai "${j}" 3-prima "usage=2,2359,0,40 senza-dettaglio"
  controlla "${j}"
  expect "controllo: senza dettaglio cache_creation, n.d., 0" 0 "n.d."
}

# Una garanzia: una serie nuova, una chiamata rifatta, uscita 1, la riga.
# Arguments: $1 il nome, $2 la chiamata, $3 i modi, $4 la riga attesa.
garanzia() {
  local j
  nuova_serie j 1
  rifai "${j}" "1-$2" "$3"
  controlla "${j}"
  expect "garanzia: $1, 1" 1 "$4: ${NONCONF}"
  expect "garanzia: $1, il perché" 1 "Una garanzia non vale"
}

t_garanzie() {
  garanzia "la prima legge" prima "usage=2,2000,5,40" \
    "la prima chiamata scrive in cache (scritti 2.000) e non legge (letti 5)"
  garanzia "la prima non scrive" prima "usage=2,0,0,40" \
    "la prima chiamata scrive in cache (scritti 0) e non legge (letti 0)"
  garanzia "la seconda non legge" seconda "usage=2,2000,0,40" \
    "la stessa chiamata, ripetuta, legge dalla cache (letti 0)"
  local spenta='con DISABLE_PROMPT_CACHING=1 niente in cache'
  local resto=', il prefisso in input_tokens'
  garanzia "con la cache spenta, scrive" senza-cache "usage=2000,5,0,40" \
    "${spenta} (scritti 5, letti 0)${resto} (2.000)"
  garanzia "con la cache spenta, legge" senza-cache "usage=2000,0,5,40" \
    "${spenta} (scritti 0, letti 5)${resto} (2.000)"
  garanzia "con la cache spenta, input 0" senza-cache "usage=0,0,0,40" \
    "${spenta} (scritti 0, letti 0)${resto} (0)"
  local sonnet='su Sonnet la cache di Haiku non vale'
  garanzia "su Sonnet legge" sonnet "usage=2,2000,5,40" \
    "${sonnet} (letti 5) e ne scrive una sua (scritti 2.000)"
  garanzia "su Sonnet non scrive" sonnet "usage=2,0,0,40" \
    "${sonnet} (letti 0) e ne scrive una sua (scritti 0)"
  garanzia "di nuovo su Haiku non legge" haiku-di-nuovo "usage=2,2000,0,40" \
    "tornando su Haiku si legge di nuovo (letti 0)"
  local j
  nuova_serie j 2
  rifai "${j}" 2-seconda "usage=2,2000,0,40"
  controlla "${j}"
  expect "garanzia: basta una serie su due, 1" 1 "serie 2"
  expect "garanzia: la serie 1 resta confermata" 1 \
    "tornando su Haiku si legge di nuovo"
}

t_mancanze() {
  local j
  nuova_serie j 2
  rm -r -- "${j}/2-sonnet"
  controlla "${j}"
  expect "mancanza: una chiamata, 1" 1 "manca 2-sonnet/risposta.json"
  nuova_serie j 1
  rm -- "${j}/1-prefisso.md"
  controlla "${j}"
  expect "mancanza: il prefisso, 1" 1 "manca 1-prefisso.md"
  nuova_serie j 2
  rm -r -- "${j}/1-prima" "${j}/1-seconda" "${j}/1-senza-cache" \
    "${j}/1-sonnet" "${j}/1-haiku-di-nuovo" "${j}/1-prefisso.md"
  controlla "${j}"
  expect "mancanza: una serie intera, con la serie dopo, 1" 1 \
    "manca 1-prima/risposta.json"
  nuova_serie j 1
  rifai "${j}" 1-prima errore
  controlla "${j}"
  expect "mancanza: una chiamata con un errore, 1" 1 \
    "claude ha restituito un errore"
  nuova_serie j 1
  : > "${j}/1-sonnet/risposta.json"
  controlla "${j}"
  expect "mancanza: un JSON vuoto, 1" 1 "è vuoto"
}

t_illeggibili() {
  local j
  nuova_serie j 1
  rifai "${j}" 1-prima riga-rotta
  controlla "${j}"
  expect "illeggibile: un file che non è JSON, 2" 2 "il JSON non si legge"
  nuova_serie j 1
  rifai "${j}" 1-seconda senza-usage
  controlla "${j}"
  expect "illeggibile: il JSON senza usage, 2" 2 "il campo «usage» non c'è"
  nuova_serie j 1
  rifai "${j}" 1-seconda usage-testo
  controlla "${j}"
  expect "illeggibile: un conteggio non numerico, 2" 2 \
    "usage.cache_read_input_tokens"
  nuova_serie j 1
  printf '[1, 2]\n' > "${j}/1-prima/risposta.json" || exit 2
  controlla "${j}"
  expect "illeggibile: un JSON che non è un oggetto, 2" 2 "non è un oggetto"
  nuova_serie j 1
  printf 'una riga qualunque\n' > "${j}/1-prefisso.md" || exit 2
  controlla "${j}"
  expect "illeggibile: il prefisso senza marcatore, 2" 2 \
    "la prima riga non è quella del marcatore"
  j="$(mktemp -d "${TMP}/vuota.XXXXXX")"
  controlla "${j}"
  expect "illeggibile: una cartella senza serie, 2" 2 "nessuna serie"
  controlla "${TMP}/non-c-e"
  expect "illeggibile: una cartella che non c'è, 2" 2 "non esiste"
  controlla
  expect "uso: senza argomenti, 2" 2 "Uso:"
  controlla --aiuto
  expect "uso: un'opzione, 2" 2 "Uso:"
}

t_verifica() {
  local ws
  nuovo_ws ws || { fail "verifica: prepara_esercizio.sh"; return; }
  run "${D03}/verifica.sh" "${ws}"
  expect "verifica: senza risposte/, 1" 1 "Manca la cartella risposte/"
  mkdir -p "${ws}/risposte" || exit 2
  run "${D03}/verifica.sh" "${ws}"
  expect "verifica: risposte/ vuota, 1" 1 "nessuna serie"
  rm -f -- "${TMP}/cache.json"
  una_serie "${ws}/risposte" 1 CACHE-0000000A
  printf '%s\n' 'print("CONTROLLO FINTO")' \
    > "${ws}/controlla_cache.py" || exit 2
  run "${D03}/verifica.sh" "${ws}"
  expect "verifica: una serie completa, 0, «Fatto»" 0 "${FATTO}"
  expect_absent "verifica: il controllo dell'elemento, non della copia" \
    "CONTROLLO FINTO"
  rm -r -- "${ws}/risposte/1-sonnet"
  run "${D03}/verifica.sh" "${ws}"
  expect "verifica: una chiamata che manca, 1" 1 "manca 1-sonnet"
  run "${D03}/verifica.sh"
  expect "verifica: senza argomenti, 2" 2 "spazio di lavoro assente"
}

# --- in_classe.sh e live.sh -------------------------------------------------

t_in_classe() {
  local ws
  nuovo_ws ws || { fail "in_classe: prepara_esercizio.sh"; return; }
  finto "${D03}/demo/in_classe.sh" "${ws}" PN_ESECUZIONI=2
  expect "in_classe: due serie, 0" 0 \
    "VERIFICA OK   il controllo, sulle chiamate di risposte/"
  expect "in_classe: il comando sullo schermo" 0 "--no-session-persistence"
  expect "in_classe: --system-prompt-file sullo schermo" 0 \
    "--system-prompt-file"
  expect "in_classe: la variabile sullo schermo" 0 \
    "export DISABLE_PROMPT_CACHING=1"
  expect "in_classe: le garanzie, sullo schermo" 0 \
    "tornando su Haiku si legge di nuovo"
  controlla_chiamate "${TMP}/finto.log" "${ws}" 2
  expect "in_classe: le chiamate, le cartelle, le opzioni, il prefisso" 0 \
    "chiamate giuste"
  run git -C "${ws}" status --porcelain
  if [[ "${OUT}" == '?? risposte/' ]]; then
    pass "in_classe: lo spazio di lavoro cambia solo in risposte/"
  else
    fail "in_classe: git status «${OUT}»"
  fi
  run env PN_HANDSON_ROOT="${RADICE}" "${D03}/verifica.sh" "${ws}"
  expect "in_classe: poi verifica.sh, 0" 0 "${FATTO}"
  nuovo_ws ws || { fail "in_classe: prepara_esercizio.sh"; return; }
  finto "${D03}/demo/in_classe.sh" "${ws}" DISABLE_PROMPT_CACHING=1
  expect "in_classe: la variabile già nella shell non conta, 0" 0 \
    "VERIFICA OK   il controllo, sulle chiamate di risposte/"
  controlla_chiamate "${TMP}/finto.log" "${ws}" 1
  expect "in_classe: e la variabile solo nella terza chiamata" 0 \
    "chiamate giuste"
}

t_live() {
  local ws
  nuovo_ws ws || { fail "live: prepara_esercizio.sh"; return; }
  finto "${D03}/_docente/live.sh" "${ws}"
  expect "live: tre serie, 0" 0 "VERIFICA OK   verifica.sh dell'elemento"
  expect "live: le garanzie, confermate" 0 "Come dati, tutte le 15 chiamate"
  controlla_chiamate "${TMP}/finto.log" "${ws}" 3
  expect "live: le quindici chiamate" 0 "chiamate giuste"
  run "${RADICE}/tools/verifica.sh" M8-D03 --radice "${ws%/M8-D03}"
  expect "live: poi tools/verifica.sh, 0" 0 "VERIFICA OK   M8-D03: fatto."
  run "${D03}/_docente/live.sh"
  expect "live: senza argomenti, 2" 2 "uso:"
}

t_precondizioni() {
  local ws s="${D03}/demo/in_classe.sh"
  nuovo_ws ws || { fail "precondizioni: prepara_esercizio.sh"; return; }
  precondizione "precondizione: una cartella che non è lo spazio" \
    "non è lo spazio di lavoro di M8-D03" "${s}" "${TMP}"
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
  mv -- "${ws}/domanda.txt" "${TMP}/domanda.txt" || exit 2
  precondizione "precondizione: la domanda che manca" \
    "file assente o illeggibile: domanda.txt" "${s}" "${ws}"
  mv -- "${TMP}/domanda.txt" "${ws}/domanda.txt" || exit 2
  local kb="${ws}/progetti/assistenza-clienti/kb/kb-13-telefono-di-casa-muto.md"
  mv -- "${kb}" "${TMP}/kb13.md" || exit 2
  precondizione "precondizione: una procedura che manca" \
    "file assente o illeggibile" "${s}" "${ws}"
  mv -- "${TMP}/kb13.md" "${kb}" || exit 2
  precondizione "precondizione: senza tools/lib_handson.sh" \
    "lanciatelo dal repository, o date PN_HANDSON_ROOT" "${s}" "${ws}" \
    "${TMP}/esca:${PATH}" PN_HANDSON_ROOT="${TMP}/non-c-e"
}

t_fallita() {
  local ws
  nuovo_ws ws || { fail "fallita: prepara_esercizio.sh"; return; }
  modo "ko-modello=sonnet"
  finto "${D03}/demo/in_classe.sh" "${ws}"
  modo
  expect "fallita: la chiamata su Sonnet che fallisce, 1" 1 \
    "VERIFICA KO   1-sonnet: claude -p è fallito"
  vero "fallita: ciò che c'era è in risposte/" \
    test -s "${ws}/risposte/1-prima/risposta.json"
  run "${D03}/verifica.sh" "${ws}"
  expect "fallita: verifica.sh dopo, 1" 1 "1-sonnet/risposta.json"
}

# Gli script di M8-D03 e questo file, con shellcheck -x.
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
      || { echo "test_m8_d03: manca ${t}" >&2; exit 2; }
  done
  [[ -f "${FINTO_PY}" ]] \
    || { echo "test_m8_d03: manca ${FINTO_PY}" >&2; exit 2; }
  handson::init_temp_base
  TMP="$(mktemp -d "${HANDSON_TEMP_BASE}/test_m8_d03.XXXXXX")" || exit 2
  trap 'chmod -R u+rwX "${TMP}" 2> /dev/null; rm -rf "${TMP}"' EXIT
  prepara_claude
  t_elemento
  t_readme
  t_prepara
  t_controllo
  t_garanzie
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
  echo "PASS=${PASS} FAIL=${FAIL} SKIP=${SKIP}"
  if (( PASS + FAIL + SKIP != CASES )); then
    echo "test_m8_d03: girati $((PASS + FAIL + SKIP)) casi, attesi" \
      "${CASES}" >&2
    exit 2
  fi
  (( FAIL == 0 )) || exit 1
}

main "$@"
