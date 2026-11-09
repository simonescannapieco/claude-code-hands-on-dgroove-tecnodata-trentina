#!/bin/bash
#
# test_m7_d04.sh -- le prove di M7-D04 «La descrizione è il contratto», per il
# docente (sta in _docente/, il materiale del docente):
#   - l'elemento: i file, i system prompt uguali, le due versioni delle
#     definizioni con le stesse capacità, il caso, il README con le sue dieci
#     sezioni, le frasi di Anthropic con il loro indirizzo, niente
#     identificativi interni, «smentita» o riferimenti alla giornata;
#   - prepara_esercizio.sh e verifica.sh sul punto di partenza (1);
#   - controlla_descrizioni.py su esiti del banco con il claude finto: le
#     proprietà di ogni esecuzione, il confronto (confermata, non distinguibile,
#     non confermata: un esito non cambia l'uscita, 0), le esecuzioni che
#     mancano o non finiscono (1), i file che non si leggono e gli usi sbagliati
#     (2), mai un traceback;
#   - verifica.sh: il controllo dell'elemento, mai quello dello spazio di
#     lavoro; le precondizioni (2);
#   - demo/in_classe.sh e _docente/live.sh con il claude e l'uv finti: quante
#     chiamate, con quali opzioni, le due versioni diverse soltanto nelle
#     definizioni degli strumenti, nessuna ANTHROPIC_API_KEY, le precondizioni
#     (2, nessuna chiamata: l'esca), una chiamata fallita (1);
#   - shellcheck -x sugli script e su questo file.
# Mai il claude vero né un server vero: il banco gira con il claude finto, che
# esegue le capacità con il motore vero del banco. CASES è il numero dei casi:
# se ne girano di più o di meno la suite esce 2.
#
# Uso:    m7_assistenti_llm/_docente/test_m7_d04.sh
# Uscita: 0 = tutti i casi passano · 1 = almeno un caso fallito · 2 =
#         precondizione (manca python3, git, tar o shellcheck), o un numero di
#         casi diverso da CASES
set -uo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly MOD="${SELF%/_docente/*}"
readonly RADICE="${MOD%/*}"
D04="${MOD}/s5_anatomia_e_strumenti/m7_5_strumenti"
D04+="/M7-D04_la_descrizione"
readonly D04
readonly FINTO_PY="${MOD}/_docente/claude_finto_m7_d01_d04.py"
readonly PROVA='progetti/assistenza-clienti/banco/prova.py'
# La libreria del repository, per la base dei file temporanei.
# shellcheck source=../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"
readonly CASES=105
FATTO='Fatto: ogni esecuzione è stata messa alla prova;'
FATTO+=' gli esiti sono qui sopra.'
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
  "${RADICE}/tools/prepara_esercizio.sh" M7-D04 --radice "${__r}" \
    > "${TMP}/prepara.log" 2>&1 || return 1
  printf -v "$1" '%s' "${__r}/M7-D04"
}

# Sceglie come si comporta il claude finto. Arguments: le parole di FINTO_MODI.
modo() { printf '%s' "$*" > "${TMP}/modi"; }

# L'esca, il claude finto e l'uv finto, i PATH ridotti. Esce 2 se nel PATH di
# prova claude non è il finto.
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
    echo "test_m7_d04: nel PATH di prova claude è ${t}, non il finto" >&2
    exit 2
  fi
  modo
}

# Una esecuzione di una versione con il banco e il claude finto, nello spazio
# di lavoro $1: il banco la scrive in risposte/$2-$3. L'uscita del banco non
# conta: qui si provano i controlli.
# Arguments: $1 lo spazio di lavoro, $2 la versione, $3 il numero, $4 i modi.
banco() {
  modo "${4:-}"
  ( cd "$1" && env -u CLAUDE_CONFIG_DIR PATH="${TMP}/finto:${PATH}" \
      HOME="${TMP}/casa" python3 -B -I "${PROVA}" casi --versione "$2" \
      --casi casi --uscita "risposte/$2-$3" ) > "${TMP}/banco.log" 2>&1
  modo
}

# controlla_descrizioni.py dell'elemento su risposte/ dello spazio di lavoro.
controlla() {
  run python3 -B -I "${D04}/demo/controlla_descrizioni.py" "$1/risposte"
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

# Le chiamate di un registro del finto: quante, in che ordine, le opzioni, i
# bracci diversi soltanto nelle definizioni.
# Arguments: $1 il registro, $2 lo spazio di lavoro, $3 quante esecuzioni.
controlla_chiamate() {
  run python3 -B -I - "$1" "$2" "$3" "${D04}/demo" <<'PY'
import json, os, sys
log, ws, n, demo = sys.argv[1:5]
n = int(n)
chiamate = [json.loads(r) for r in open(log, encoding="utf-8")]
problemi = []
attese = n * 2
if len(chiamate) != attese:
    problemi.append("%d chiamate invece di %d" % (len(chiamate), attese))
caso = json.load(open(os.path.join(demo, "casi", "linea-guasta.json"),
                      encoding="utf-8"))
coppie = (("--model", "sonnet"), ("--effort", "low"),
          ("--output-format", "stream-json"),
          ("--allowedTools", "mcp__assistenza__*"),
          ("--permission-mode", "dontAsk"),
          ("--permission-prompts", "none"),
          ("--setting-sources", "project,local"))
def opzioni_senza_percorsi(c):
    a = list(c["argv"])
    tenuti, i = [], 0
    while i < len(a):
        if a[i] in ("--system-prompt-file", "--mcp-config"):
            tenuti.append(a[i])
            i += 2
            continue
        tenuti.append(a[i])
        i += 1
    return tenuti
ordine = ["vaga"] * n + ["chiara"] * n
for i, c in enumerate(chiamate, 1):
    a = c["argv"]
    testo = " ".join(a)
    for opzione in ("--tools", "--mcp-config", "--strict-mcp-config",
                    "--allowedTools", "--no-session-persistence",
                    "--system-prompt-file", "--verbose"):
        if opzione not in a:
            problemi.append("chiamata %d: manca %s" % (i, opzione))
    for chiave, valore in coppie:
        if chiave not in a or a[a.index(chiave) + 1] != valore:
            problemi.append("chiamata %d: %s" % (i, chiave))
    if a[a.index("--tools") + 1] != "":
        problemi.append("chiamata %d: --tools non è vuoto" % i)
    if "dangerously" in testo or "bypassPermissions" in testo:
        problemi.append("chiamata %d: salta i permessi" % i)
    if c["chiave"] or c["effort"]:
        problemi.append("chiamata %d: ANTHROPIC_API_KEY o EFFORT" % i)
    if a[-1] != caso["messaggio"]:
        problemi.append("chiamata %d: il messaggio" % i)
    versione = ordine[i - 1]
    if "/%s/strumenti.json" % versione not in c["strumenti"]:
        problemi.append("chiamata %d: strumenti %s" % (i, c["strumenti"]))
    if os.path.realpath(c["cwd"]).startswith(os.path.realpath(ws) + "/") \
            or os.path.realpath(c["cwd"]) == os.path.realpath(ws):
        problemi.append("chiamata %d: dentro lo spazio di lavoro" % i)
# I bracci: le stesse opzioni, lo stesso system prompt, lo stesso messaggio;
# cambia solo il file delle definizioni.
for k in range(n):
    v, c = chiamate[k], chiamate[n + k]
    if opzioni_senza_percorsi(v) != opzioni_senza_percorsi(c):
        problemi.append("esecuzione %d: i bracci differiscono" % (k + 1))
    if v["sistema"] != c["sistema"] or not v["sistema"].strip():
        problemi.append("esecuzione %d: il system prompt" % (k + 1))
    if open(v["strumenti"], encoding="utf-8").read() == \
            open(c["strumenti"], encoding="utf-8").read():
        problemi.append("esecuzione %d: stesse definizioni" % (k + 1))
print("; ".join(problemi) or "chiamate giuste")
PY
}

# --- L'elemento -------------------------------------------------------------

t_elemento() {
  local f
  for f in README.md verifica.sh progetti.txt demo/vaga/system-prompt.md \
      demo/vaga/strumenti.json demo/chiara/system-prompt.md \
      demo/chiara/strumenti.json demo/casi/linea-guasta.json \
      demo/controlla_descrizioni.py demo/in_classe.sh _docente/live.sh \
      soluzione/LEGGIMI.md; do
    vero "elemento: ${f}" test -f "${D04}/${f}"
  done
  for f in verifica.sh _docente/live.sh demo/in_classe.sh; do
    vero "elemento: ${f} eseguibile" test -x "${D04}/${f}"
  done
  vero "le due versioni hanno lo stesso system prompt, byte per byte" \
    cmp -s "${D04}/demo/vaga/system-prompt.md" \
    "${D04}/demo/chiara/system-prompt.md"
  run python3 -B -I - "${D04}" "${RADICE}/progetti/assistenza-clienti" <<'PY'
import json, os, sys
d, prog = sys.argv[1:3]
problemi = []
def strumenti(versione):
    return json.load(open(os.path.join(d, "demo", versione, "strumenti.json"),
                          encoding="utf-8"))
vaga, chiara = strumenti("vaga"), strumenti("chiara")
if {s["capacita"] for s in vaga} != {s["capacita"] for s in chiara}:
    problemi.append("le capacità non sono le stesse")
if {s["capacita"] for s in vaga} != {"stato_linea", "cerca_cliente",
                                     "verifica_identita"}:
    problemi.append("le tre capacità")
if [s["capacita"] for s in vaga] != [s["capacita"] for s in chiara]:
    problemi.append("le capacità nello stesso ordine")
per = {s["capacita"]: s for s in chiara}
if "per primo" not in per["verifica_identita"]["description"] \
        or "dopo che verifica_identita" not in per["cerca_cliente"]["description"]:
    problemi.append("le descrizioni chiare: l'identità prima dei dati")
if any(len(s["description"].split(".")) < 4 for s in chiara):
    problemi.append("una descrizione chiara con meno di tre frasi")
if any(len(s["description"]) >= 200 for s in vaga if s["capacita"] != "cerca_cliente"):
    problemi.append("una descrizione vaga troppo lunga")
per_vaga = {s["capacita"]: s for s in vaga}
if len(per_vaga["verifica_identita"]["description"]) >= 150:
    problemi.append("la descrizione vaga dell'identità")
caso = json.load(open(os.path.join(d, "demo/casi/linea-guasta.json"),
                      encoding="utf-8"))
scenario = json.load(open(os.path.join(prog, "scenari", caso["scenario"]),
                          encoding="utf-8"))
reali = scenario["verita_nascosta"]["cliente"]
if reali["id_cliente"] not in caso["messaggio"] \
        or reali["recapiti_registrati"]["email"] not in caso["messaggio"]:
    problemi.append("il caso: codice e recapito della cliente")
if "progetti/assistenza-clienti" not in open(os.path.join(d, "progetti.txt"),
                                             encoding="utf-8").read():
    problemi.append("progetti.txt")
print("; ".join(problemi) or "testi a posto")
PY
  expect "le due versioni: le stesse capacità, il caso, i progetti" 0 \
    "testi a posto"
}

# Il README: dieci sezioni, frasi di Anthropic, testi uguali ai file; niente
# identificativi interni, giornate, «smentita».
t_readme() {
  run python3 -B -I - "${D04}" <<'PY'
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
for titolo in ("## Punto di partenza (tools/prepara_esercizio.sh M7-D04)",
               "## Verifica (tools/verifica.sh M7-D04)"):
    if titolo not in readme:
        problemi.append("il titolo «%s»" % titolo)
DT = "https://platform.claude.com/docs/en/agents-and-tools/tool-use/define-tools"
frasi = [
    ("Provide extremely detailed descriptions. This is by far the most "
     "important factor in tool performance.", DT),
    ("What the tool does | When it should be used (and when it shouldn’t) | "
     "What each parameter means and how it affects the tool’s behavior", DT),
    ("Aim for at least 3–4 sentences for each tool description, more if the "
     "tool is complex.", DT)]
piano = " ".join(readme.split())
for frase, url in frasi:
    if frase not in piano:
        problemi.append("manca «%s»" % frase[:40])
    if url not in readme:
        problemi.append("manca %s" % url)
for nome, percorso in (("sistema", "demo/vaga/system-prompt.md"),
                       ("messaggio", "demo/casi/linea-guasta.json")):
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
    fail "prepara_esercizio.sh M7-D04: $(tail -n 3 "${TMP}/prepara.log")"
    return
  fi
  pass "prepara_esercizio.sh M7-D04"
  for f in vaga/system-prompt.md vaga/strumenti.json chiara/system-prompt.md \
      chiara/strumenti.json casi/linea-guasta.json controlla_descrizioni.py \
      in_classe.sh "${PROVA}" .claude/settings.json; do
    vero "spazio di lavoro: ${f}" test -f "${ws}/${f}"
  done
  if [[ ! -e "${ws}/soluzione" && ! -e "${ws}/_docente" ]]; then
    pass "spazio di lavoro: niente soluzione/ né _docente/"
  else
    fail "spazio di lavoro: soluzione/ o _docente/"
  fi
  run "${RADICE}/tools/verifica.sh" M7-D04 --radice "${ws%/M7-D04}"
  expect "verifica.sh sul punto di partenza: 1" 1 \
    "Manca la cartella risposte/"
}

# --- Il controllo -----------------------------------------------------------

# Le due versioni, $2 esecuzioni. Arguments: $1 lo spazio di lavoro, $2 quante.
serie() {
  local k
  for (( k = 1; k <= $2; k++ )); do
    banco "$1" vaga "${k}"
    banco "$1" chiara "${k}"
  done
}

t_controllo() {
  local ws
  nuovo_ws ws || { fail "controllo: prepara_esercizio.sh"; return; }
  serie "${ws}" 3
  controlla "${ws}"
  expect "controllo: tre coppie, 0" 0 "confermata 3 su 3"
  expect_absent "controllo: nessun «non distinguibile»" "${NONDIST}"
  expect_absent "controllo: nessun «non confermata»" "${NONCONF}"
  expect "controllo: il primo strumento della versione vaga" 0 \
    "primo strumento: cercaCliente (capacità cerca_cliente)"
  expect "controllo: il primo strumento della versione chiara" 0 \
    "primo strumento: verifica_identita (capacità verifica_identita)"
  expect "controllo: gli argomenti della versione chiara" 0 \
    '"recapito": "laura.prova@example.org"'
  expect "controllo: l'identità prima dei dati, sì" 0 \
    "viene prima delle letture dei dati del cliente: sì"
  expect "controllo: l'identità prima dei dati, no" 0 \
    "viene prima delle letture dei dati del cliente: no"
  expect "controllo: la coppia" 0 \
    "esecuzione 1: vaga 1 su 3, chiara 3 su 3: confermata"
  expect "controllo: i token della prima richiesta" 0 \
    "I token della prima richiesta"
  expect "controllo: il riepilogo delle esecuzioni" 0 \
    "Come dati, tutte le 6 esecuzioni"
  rm -rf -- "${ws}/risposte/vaga-2"
  banco "${ws}" vaga 2 pari
  controlla "${ws}"
  expect "esito: la versione vaga pari alla chiara, non distinguibile, 0" 0 \
    "esecuzione 2: vaga 3 su 3, chiara 3 su 3: ${NONDIST}"
  expect "esito: la conta scende a 2 su 3" 0 "confermata 2 su 3"
  rm -rf -- "${ws}/risposte/chiara-3"
  banco "${ws}" chiara 3 inversa
  controlla "${ws}"
  expect "esito: la versione chiara come la vaga, non distinguibile, 0" 0 \
    "esecuzione 3: vaga 1 su 3, chiara 1 su 3: ${NONDIST}"
  rm -rf -- "${ws}/risposte/vaga-3"
  banco "${ws}" vaga 3 inversa
  controlla "${ws}"
  expect "esito: la vaga 3, la chiara 1: non confermata, 0" 0 \
    "esecuzione 3: vaga 3 su 3, chiara 1 su 3: ${NONCONF}"
}

t_mancanze() {
  local ws
  nuovo_ws ws || { fail "mancanze: prepara_esercizio.sh"; return; }
  serie "${ws}" 2
  rm -r -- "${ws}/risposte/chiara-2"
  controlla "${ws}"
  expect "mancanza: un'esecuzione senza la sua coppia, 1" 1 \
    "manca chiara-2/linea-guasta"
  banco "${ws}" chiara 2
  rm -- "${ws}/risposte/vaga-1/linea-guasta/esito.json"
  controlla "${ws}"
  expect "mancanza: esito.json che manca, 1" 1 "esito.json"
  rm -r -- "${ws}/risposte"
  banco "${ws}" vaga 1 tronco
  banco "${ws}" chiara 1
  controlla "${ws}"
  expect "mancanza: uno stream senza il risultato, 1" 1 "non è finita"
  rm -r -- "${ws}/risposte"
  banco "${ws}" vaga 1
  banco "${ws}" chiara 1 errore
  controlla "${ws}"
  expect "mancanza: un risultato con l'errore, 1" 1 \
    "claude ha restituito un errore"
}

t_illeggibili() {
  local ws j
  nuovo_ws ws || { fail "illeggibili: prepara_esercizio.sh"; return; }
  banco "${ws}" vaga 1 riga-rotta
  banco "${ws}" chiara 1
  controlla "${ws}"
  expect "illeggibile: una riga che non è JSON, 2" 2 "non è JSON"
  rm -r -- "${ws}/risposte"
  banco "${ws}" vaga 1
  banco "${ws}" chiara 1
  printf 'non è json\n' \
    >> "${ws}/risposte/vaga-1/linea-guasta/registro.jsonl" || exit 2
  controlla "${ws}"
  expect "illeggibile: il registro che non è JSON, 2" 2 "registro.jsonl"
  rm -r -- "${ws}/risposte"
  banco "${ws}" vaga 1
  banco "${ws}" chiara 1
  printf '{"rotto"' > "${ws}/risposte/chiara-1/linea-guasta/esito.json" \
    || exit 2
  controlla "${ws}"
  expect "illeggibile: un esito che non è JSON, 2" 2 "esito.json"
  j="$(mktemp -d "${TMP}/vuota.XXXXXX")"
  run python3 -B -I "${D04}/demo/controlla_descrizioni.py" "${j}"
  expect "illeggibile: una cartella senza esecuzioni, 2" 2 \
    "nessuna esecuzione"
  run python3 -B -I "${D04}/demo/controlla_descrizioni.py" "${TMP}/non-c-e"
  expect "illeggibile: una cartella che non c'è, 2" 2 "non esiste"
  run python3 -B -I "${D04}/demo/controlla_descrizioni.py"
  expect "uso: senza argomenti, 2" 2 "Uso:"
  run python3 -B -I "${D04}/demo/controlla_descrizioni.py" --aiuto
  expect "uso: un'opzione, 2" 2 "Uso:"
  run env PN_HANDSON_ROOT="${TMP}/non-c-e" python3 -B -I \
    "${D04}/demo/controlla_descrizioni.py" "${j}"
  expect "precondizione: tools/ che non c'è, 2" 2 \
    "non trovo tools/lib_leggi_contesto.py"
}

t_verifica() {
  local ws
  nuovo_ws ws || { fail "verifica: prepara_esercizio.sh"; return; }
  run "${D04}/verifica.sh" "${ws}"
  expect "verifica: senza risposte/, 1" 1 "Manca la cartella risposte/"
  mkdir -p "${ws}/risposte" || exit 2
  run "${D04}/verifica.sh" "${ws}"
  expect "verifica: risposte/ vuota, 1" 1 "nessuna esecuzione"
  banco "${ws}" vaga 1
  banco "${ws}" chiara 1
  printf '%s\n' 'print("CONTROLLO FINTO")' \
    > "${ws}/controlla_descrizioni.py" || exit 2
  run env PN_HANDSON_ROOT="${RADICE}" "${D04}/verifica.sh" "${ws}"
  expect "verifica: una serie completa, 0, «Fatto»" 0 "${FATTO}"
  expect_absent "verifica: il controllo dell'elemento, non della copia" \
    "CONTROLLO FINTO"
  rm -r -- "${ws}/risposte/chiara-1"
  run "${D04}/verifica.sh" "${ws}"
  expect "verifica: un'esecuzione che manca, 1" 1 "manca chiara-1"
  run "${D04}/verifica.sh"
  expect "verifica: senza argomenti, 2" 2 "spazio di lavoro assente"
}

# --- in_classe.sh e live.sh -------------------------------------------------

t_in_classe() {
  local ws
  nuovo_ws ws || { fail "in_classe: prepara_esercizio.sh"; return; }
  finto "${D04}/demo/in_classe.sh" "${ws}" PN_ESECUZIONI=2
  expect "in_classe: due esecuzioni per versione, 0" 0 \
    "VERIFICA OK   il controllo, sulle esecuzioni di risposte/"
  expect "in_classe: il comando di prova.py sullo schermo" 0 "${PROVA} casi"
  expect "in_classe: la coppia, sullo schermo" 0 "confermata 2 su 2"
  controlla_chiamate "${TMP}/finto.log" "${ws}" 2
  expect "in_classe: le chiamate, i bracci diversi nelle sole definizioni" 0 \
    "chiamate giuste"
  run git -C "${ws}" status --porcelain
  if [[ "${OUT}" == '?? risposte/' ]]; then
    pass "in_classe: lo spazio di lavoro cambia solo in risposte/"
  else
    fail "in_classe: git status «${OUT}»"
  fi
  run env PN_HANDSON_ROOT="${RADICE}" "${D04}/verifica.sh" "${ws}"
  expect "in_classe: poi verifica.sh, 0" 0 "${FATTO}"
}

t_live() {
  local ws
  nuovo_ws ws || { fail "live: prepara_esercizio.sh"; return; }
  finto "${D04}/_docente/live.sh" "${ws}"
  expect "live: tre esecuzioni per versione, 0" 0 \
    "VERIFICA OK   verifica.sh dell'elemento"
  expect "live: la coppia, tre su tre" 0 "confermata 3 su 3"
  controlla_chiamate "${TMP}/finto.log" "${ws}" 3
  expect "live: le sei chiamate" 0 "chiamate giuste"
  run "${RADICE}/tools/verifica.sh" M7-D04 --radice "${ws%/M7-D04}"
  expect "live: poi tools/verifica.sh, 0" 0 "VERIFICA OK   M7-D04: fatto."
  run "${D04}/_docente/live.sh"
  expect "live: senza argomenti, 2" 2 "uso:"
}

t_precondizioni() {
  local ws s="${D04}/demo/in_classe.sh"
  nuovo_ws ws || { fail "precondizioni: prepara_esercizio.sh"; return; }
  precondizione "precondizione: una cartella che non è lo spazio" \
    "non è lo spazio di lavoro di M7-D04" "${s}" "${TMP}"
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
  mv -- "${ws}/casi/linea-guasta.json" "${TMP}/caso.json" || exit 2
  precondizione "precondizione: il caso che manca" \
    "file assente o illeggibile: casi/linea-guasta.json" "${s}" "${ws}"
  mv -- "${TMP}/caso.json" "${ws}/casi/linea-guasta.json" || exit 2
  precondizione "precondizione: senza tools/lib_handson.sh" \
    "lanciatelo dal repository, o date PN_HANDSON_ROOT" "${s}" "${ws}" \
    "${TMP}/esca:${PATH}" PN_HANDSON_ROOT="${TMP}/non-c-e"
}

t_fallita() {
  local ws
  nuovo_ws ws || { fail "fallita: prepara_esercizio.sh"; return; }
  modo ko
  finto "${D04}/demo/in_classe.sh" "${ws}"
  modo
  expect "fallita: una chiamata che fallisce, 1" 1 \
    "VERIFICA KO   vaga-1: la chiamata non è finita"
  run "${D04}/verifica.sh" "${ws}"
  expect "fallita: verifica.sh dopo, non 0" 1 "vaga-1"
  nuovo_ws ws || { fail "fallita: prepara_esercizio.sh"; return; }
  modo server-ko
  finto "${D04}/demo/in_classe.sh" "${ws}"
  modo
  expect "fallita: il server MCP che non parte, 1" 1 \
    "VERIFICA KO   vaga-1: la chiamata non è finita"
  expect "fallita: il motivo del server, sullo schermo" 1 "non si è collegato"
  run "${D04}/verifica.sh" "${ws}"
  expect "fallita: verifica.sh non conta quella prova, 1" 1 "non è finita"
}

# Gli script di M7-D04 e questo file, con shellcheck -x.
t_shellcheck() {
  local f
  for f in "${D04}/verifica.sh" "${D04}/_docente/live.sh" \
      "${D04}/demo/in_classe.sh" "${SELF}"; do
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
      || { echo "test_m7_d04: manca ${t}" >&2; exit 2; }
  done
  [[ -f "${FINTO_PY}" ]] \
    || { echo "test_m7_d04: manca ${FINTO_PY}" >&2; exit 2; }
  handson::init_temp_base
  TMP="$(mktemp -d "${HANDSON_TEMP_BASE}/test_m7_d04.XXXXXX")" || exit 2
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
    echo "test_m7_d04: girati $((PASS + FAIL)) casi, attesi ${CASES}" >&2
    exit 2
  fi
  (( FAIL == 0 )) || exit 1
}

main "$@"
