#!/bin/bash
#
# test_m6_d03.sh -- le prove di M6-D03 «Il comando dei test: Claude andrebbe a
# cercarlo?», per il docente (sta in _docente/, il materiale del docente):
#   - l'elemento: progetti.txt; demo/tools/php.sh uguale a tools/php.sh; la
#     richiesta; il CLAUDE.md di quattro righe del braccio con; le dieci
#     sezioni del README, le frasi di Anthropic con il loro indirizzo, il
#     prompt uguale al file; nessun identificativo interno, «smentita» o
#     riferimento alla giornata;
#   - prepara_esercizio.sh (il gestionale senza vendor/ né _docente/) e
#     verifica.sh sul punto di partenza (1);
#   - controlla_comandi.py su stream del claude finto: i passi, il README, la
#     suite e i suoi numeri, la coppia (un esito non cambia mai l'uscita, 0);
#     le esecuzioni che mancano o non finiscono (1); gli stream che non si
#     leggono e gli usi sbagliati (2), mai un traceback;
#   - verifica.sh: il controllo dell'elemento, mai quello dello spazio di
#     lavoro; risposte/ che manca o vuota (1); le precondizioni (2);
#   - demo/in_classe.sh e _docente/live.sh con il claude finto: quante
#     chiamate, in che ordine, da quale cartella di quale copia, con quali
#     file, testo e opzioni (Bash per intero, le quattro regole negate), senza
#     ANTHROPIC_API_KEY, con la auto memory spenta; le copie tolte; lo spazio di
#     lavoro intatto fuori da risposte/; le precondizioni (2, nessuna chiamata:
#     l'esca), PHP o Docker compresi; una chiamata fallita (1);
#   - shellcheck -x sugli script e su questo file.
# Mai il claude vero: il finto e l'esca stanno davanti nel PATH, e la suite lo
# controlla prima di usarli; accanto al finto c'è un docker finto, che nessuno
# chiama, perché la precondizione «PHP o Docker» passi anche dove Docker non
# c'è. Gli stream del finto non sono risposte di Claude: provano il controllo,
# non il modello, e il finto non esegue nessun comando. Gli spazi di lavoro
# nascono in una cartella temporanea: l'albero del repository non cambia.
# CASES è il numero dei casi: se ne girano di più o di meno la suite esce 2.
#
# Uso:    m6_projects_context/_docente/test_m6_d03.sh
# Uscita: 0 = tutti i casi passano · 1 = almeno un caso fallito · 2 =
#         precondizione (manca python3, git, tar o shellcheck), o un numero di
#         casi diverso da CASES
set -uo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly MOD="${SELF%/_docente/*}"
readonly RADICE="${MOD%/*}"
D03="${MOD}/s5_projects_context/m6_4_che_cosa_scriverci"
D03+="/M6-D03_la_riga_che_mancava"
readonly D03
readonly FINTO_PY="${MOD}/_docente/claude_finto_m6_d01_d03.py"
# La libreria del repository, per la base dei file temporanei.
# shellcheck source=../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"
readonly CASES=103
readonly GESTIONALE=progetti/gestionale-php
Q='Esegui la suite di test del gestionale e dimmi quanti test passano e'
Q+=' quanti falliscono.'
readonly Q
FATTO='Fatto: ogni esecuzione è stata messa alla prova;'
FATTO+=' gli esiti sono qui sopra.'
readonly FATTO
readonly NONCONF='non confermata in questa esecuzione'
readonly NONDIST='non distinguibile'
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
  "${RADICE}/tools/prepara_esercizio.sh" M6-D03 --radice "${__r}" \
    > "${TMP}/prepara.log" 2>&1 || return 1
  printf -v "$1" '%s' "${__r}/M6-D03"
}

# L'esca (registra ogni invocazione ed esce 0), il claude finto con un docker
# finto accanto e i PATH ridotti. Esce 2 se nel PATH di prova claude non è il
# finto.
prepara_claude() {
  local t d
  for d in esca finto senza_python senza_claude senza_php; do
    mkdir -p "${TMP}/${d}" || exit 2
  done
  # shellcheck disable=SC2016  # il corpo è dell'esca
  printf '%s\n' '#!/bin/bash' \
    'printf "invocazione %s\n" "$*" >> "${ESCA_LOG}"' \
    > "${TMP}/esca/claude" || exit 2
  printf '%s\n' '#!/bin/bash' 'exit 0' > "${TMP}/finto/docker" || exit 2
  cp -- "${FINTO_PY}" "${TMP}/finto/claude" || exit 2
  chmod 755 "${TMP}/esca/claude" "${TMP}/finto/claude" "${TMP}/finto/docker" \
    || exit 2
  for t in readlink git tar; do
    ln -s "$(command -v "${t}")" "${TMP}/senza_python/${t}" || exit 2
  done
  ln -s "${TMP}/esca/claude" "${TMP}/senza_python/claude" || exit 2
  for t in readlink python3 git tar; do
    ln -s "$(command -v "${t}")" "${TMP}/senza_claude/${t}" || exit 2
    ln -s "$(command -v "${t}")" "${TMP}/senza_php/${t}" || exit 2
  done
  ln -s "${TMP}/finto/docker" "${TMP}/senza_claude/docker" || exit 2
  ln -s "${TMP}/esca/claude" "${TMP}/senza_php/claude" || exit 2
  t="$(PATH="${TMP}/finto:${PATH}" command -v claude)"
  if [[ "${t}" != "${TMP}/finto/claude" ]]; then
    echo "test_m6_d03: nel PATH di prova claude è ${t}, non il finto" >&2
    exit 2
  fi
}

# Rifà un'esecuzione di una serie, come la fa in_classe.sh: una copia con il
# nome dell'esecuzione, la chiamata dalla cartella del gestionale, con il
# CLAUDE.md nel braccio con. Arguments: $1 la cartella degli stream, $2 il
# nome (senza-1, con-2…), poi le variabili NOME=valore.
rifai() {
  local json="$1" nome="$2" copia
  shift 2
  copia="$(mktemp -d "${TMP}/copie.XXXXXX")/${nome}" || exit 2
  mkdir -p "${copia}/${GESTIONALE}" "${json}/${nome}" || exit 2
  if [[ "${nome}" == con-* ]]; then
    cp -- "${D03}/demo/con-la-riga/CLAUDE.md" \
      "${copia}/${GESTIONALE}/CLAUDE.md" || exit 2
  fi
  ( cd "${copia}/${GESTIONALE}" && env "$@" "${TMP}/finto/claude" -p \
      --model sonnet --output-format stream-json --verbose -- "${Q}" ) \
    > "${json}/${nome}/stream.jsonl" \
    || { echo "test_m6_d03: il finto non scrive ${nome}" >&2; exit 2; }
}

# Una serie di esecuzioni del finto. Arguments: $1 la cartella degli stream,
# $2 quante esecuzioni.
serie() {
  local k b
  for (( k = 1; k <= $2; k++ )); do
    for b in senza con; do
      rifai "$1" "${b}-${k}"
    done
  done
}

# Una cartella nuova di stream, con le esecuzioni da 1 a $2.
# Arguments: $1 la variabile da assegnare, $2 quante esecuzioni.
nuova_serie() {
  local __j
  __j="$(mktemp -d "${TMP}/json.XXXXXX")" || exit 2
  serie "${__j}" "$2"
  printf -v "$1" '%s' "${__j}"
}

# controlla_comandi.py dell'elemento; RC e OUT come run.
controlla() { run python3 -B -I "${D03}/demo/controlla_comandi.py" "$@"; }

# Lo script con l'esca davanti nel PATH (o con un PATH dato); il registro
# riparte vuoto. Arguments: $1 lo script, $2 lo spazio di lavoro, $3
# facoltativo il PATH, poi le variabili NOME=valore.
esca() {
  local script="$1" w="$2" percorso="${3:-${TMP}/esca:${TMP}/finto:${PATH}}"
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
# riparte vuoto. Arguments: $1 lo script, $2 lo spazio di lavoro, poi le
# variabili NOME=valore.
finto() {
  local script="$1" w="$2"
  shift 2
  : > "${TMP}/finto.log"
  run env PATH="${TMP}/finto:${PATH}" HANDSON_NO_PAUSE=1 \
    ANTHROPIC_API_KEY=valore-finto CLAUDE_CODE_EFFORT_LEVEL=high \
    FINTO_LOG="${TMP}/finto.log" TMPDIR="${TMP}" "$@" "${script}" "${w}"
}

# Le chiamate di un registro del finto, contro le attese: quante, in che
# ordine, da quale cartella di quale copia, con quali file, testo e opzioni.
# Arguments: $1 il registro, $2 lo spazio di lavoro, $3 quante esecuzioni.
controlla_chiamate() {
  run python3 -B -I - "$1" "$2" "$3" "${Q}" "${D03}/demo" "${RADICE}" \
    "${GESTIONALE}" <<'PY'
import hashlib, json, os, subprocess, sys
log, ws, n, q, demo, radice, gest = sys.argv[1:8]
def sha(p):
    return hashlib.sha256(open(p, "rb").read()).hexdigest()
tracciati = subprocess.run(
    ["git", "-C", ws, "ls-files", "--", "progetti", "tools", ".claude"],
    capture_output=True, text=True, check=True).stdout.split()
base = {f: sha(os.path.join(ws, f)) for f in tracciati}
riga = sha(os.path.join(demo, "con-la-riga", "CLAUDE.md"))
righe = [json.loads(r) for r in open(log, encoding="utf-8")]
chiamate = [r for r in righe if r["argv"][:1] != ["--version"]]
attese = (["senza-%d" % k for k in range(1, int(n) + 1)]
          + ["con-%d" % k for k in range(1, int(n) + 1)])
VALORE = {"--model", "--effort", "--output-format", "--setting-sources",
          "--permission-mode", "--permission-prompts", "--allowedTools",
          "--tools", "--disallowedTools"}
VIETATI = "Bash(sudo *),Bash(git push *),Bash(curl *),Bash(wget *)"
STRUMENTI = "Read,Glob,Grep,Bash"
fisse = (("--model", "sonnet"), ("--effort", "low"),
         ("--output-format", "stream-json"),
         ("--setting-sources", "project,local"),
         ("--permission-mode", "dontAsk"), ("--permission-prompts", "none"),
         ("--allowedTools", STRUMENTI), ("--tools", STRUMENTI),
         ("--disallowedTools", VIETATI))
problemi = []
if not base or base.get("tools/php.sh") != sha(os.path.join(radice, "tools",
                                                           "php.sh")):
    problemi.append("tools/php.sh dello spazio di lavoro")
if len(chiamate) != len(attese):
    problemi.append("%d chiamate invece di %d" % (len(chiamate), len(attese)))
for i, (c, nome) in enumerate(zip(chiamate, attese), 1):
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
    if argv[fine + 1:] != [q]:
        problemi.append("chiamata %d: il prompt %r" % (i, argv[fine + 1:]))
    if not c["cwd"].endswith("/%s/%s" % (nome, gest)):
        problemi.append("chiamata %d: la cartella %s" % (i, c["cwd"]))
    if os.path.realpath(c["cwd"]).startswith(os.path.realpath(ws) + "/"):
        problemi.append("chiamata %d: dentro lo spazio di lavoro" % i)
    if c["radice"] != c["cwd"][:-len(gest) - 1]:
        problemi.append("chiamata %d: la radice git %s" % (i, c["radice"]))
    for chiave, valore in fisse:
        if opzioni.get(chiave) != valore:
            problemi.append("chiamata %d: %s" % (i, chiave))
    for chiave in ("-p", "--verbose", "--strict-mcp-config",
                   "--no-session-persistence"):
        if opzioni.get(chiave) is not True:
            problemi.append("chiamata %d: %s" % (i, chiave))
    if any("dangerously" in a or "bypassPermissions" in a for a in argv):
        problemi.append("chiamata %d: salta i permessi" % i)
    attesi = dict(base)
    if nome.startswith("con"):
        attesi[gest + "/CLAUDE.md"] = riga
    if c["file"] != attesi:
        diversi = sorted(set(c["file"].items()) ^ set(attesi.items()))
        problemi.append("chiamata %d: i file %s" % (i, diversi[:4]))
    if any("vendor/" in f for f in c["file"]):
        problemi.append("chiamata %d: vendor/ nella copia" % i)
    if c["commit"] != "1" or not c["pulito"]:
        problemi.append("chiamata %d: commit %s, pulito %s" % (
            i, c["commit"], c["pulito"]))
    if c["chiave"] or c["effort"]:
        problemi.append("chiamata %d: con ANTHROPIC_API_KEY o "
                        "CLAUDE_CODE_EFFORT_LEVEL" % i)
    if c["memoria"] != "1":
        problemi.append("chiamata %d: la auto memory non è spenta" % i)
    if not c["stdin_nullo"]:
        problemi.append("chiamata %d: STDIN non è /dev/null" % i)
    if os.path.exists(c["radice"]):
        problemi.append("chiamata %d: la copia è rimasta" % i)
print("; ".join(problemi) or "chiamate giuste")
PY
}

# --- L'elemento -------------------------------------------------------------

t_elemento() {
  local f
  for f in README.md verifica.sh progetti.txt demo/richiesta.txt \
      demo/con-la-riga/CLAUDE.md demo/tools/php.sh demo/controlla_comandi.py \
      demo/in_classe.sh _docente/live.sh soluzione/LEGGIMI.md; do
    vero "elemento: ${f}" test -f "${D03}/${f}"
  done
  for f in verifica.sh _docente/live.sh demo/in_classe.sh demo/tools/php.sh; do
    vero "elemento: ${f} eseguibile" test -x "${D03}/${f}"
  done
  vero "demo/tools/php.sh: uguale a tools/php.sh, byte per byte" \
    cmp -s "${RADICE}/tools/php.sh" "${D03}/demo/tools/php.sh"
  run cat -- "${D03}/progetti.txt"
  if [[ "${OUT}" == "${GESTIONALE}" ]]; then
    pass "progetti.txt: il gestionale"
  else
    fail "progetti.txt: «${OUT}»"
  fi
  run cat -- "${D03}/demo/richiesta.txt"
  if [[ "${OUT}" == "${Q}" ]]; then
    pass "richiesta.txt: la richiesta, una riga"
  else
    fail "richiesta.txt: «${OUT}»"
  fi
  run python3 -B -I - "${D03}/demo/con-la-riga/CLAUDE.md" <<'PY'
import sys
righe = open(sys.argv[1], encoding="utf-8").read().splitlines()
ok = (len(righe) == 4 and righe[0].startswith("# ") and righe[1] == ""
      and all(r.startswith("- ") for r in righe[2:])
      and "`../../tools/php.sh phpunit`" in righe[2]
      and "`../../tools/php.sh composer install`" in righe[3])
print("quattro righe a posto" if ok else "CLAUDE.md: %r" % righe)
PY
  expect "con-la-riga/CLAUDE.md: un titolo e due righe, i comandi esatti" 0 \
    "quattro righe a posto"
}

# Il README: le dieci sezioni, le frasi di Anthropic, il prompt uguale al
# file; niente identificativi interni, giornate, «smentita».
t_readme() {
  run python3 -B -I - "${D03}" "${Q}" <<'PY'
import os, re, sys
item, q = sys.argv[1:3]
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
for titolo in ("## Punto di partenza (tools/prepara_esercizio.sh M6-D03)",
               "## Verifica (tools/verifica.sh M6-D03)"):
    if titolo not in readme:
        problemi.append("il titolo «%s»" % titolo)
BP = "https://code.claude.com/docs/en/best-practices"
frasi = [
    ("Only write down what Claude can't find by reading the repo, or what "
     "it would otherwise spend time rediscovering every session.", BP),
    ("How to confirm work in this repo: the exact test, typecheck, and lint "
     "commands, and how to run a single test file", BP),
    ("Could it find this by reading the code?", BP),
    ("Would it actually go and look?", BP),
    ("If both are yes, leave it out.", BP),
    ("Structure: group related instructions under markdown headers and "
     "bullets.", "https://code.claude.com/docs/en/memory"),
    ("dontAsk: Claude Code denies every call that would otherwise prompt",
     "https://code.claude.com/docs/en/headless"),
    ("a deny or ask rule covers the invocation Claude usually produces and "
     "isn’t a security boundary around the program",
     "https://code.claude.com/docs/en/permissions")]
piano = " ".join(readme.split())
for frase, url in frasi:
    if frase not in piano:
        problemi.append("manca «%s»" % frase[:40])
    if url not in readme:
        problemi.append("manca %s" % url)
blocco = re.search(r"<!-- prompt 1 -->\n(.*?)<!-- /prompt 1 -->", readme,
                   re.S)
if not blocco or " ".join(blocco.group(1).split()) != q:
    problemi.append("il prompt 1 non è richiesta.txt")
codice = open(os.path.join(item, "demo", "con-la-riga", "CLAUDE.md"),
              encoding="utf-8").read().splitlines()
blocchi = {r.strip() for r in readme.splitlines() if r.startswith("    ")}
if any(r and r not in blocchi for r in codice):
    problemi.append("il README non mostra le quattro righe così come sono")
for vietata in ("smentit", "FACT-", "M6-X", "X-3", "X-4", "oggi",
                "domani", "pausa", "pranzo", "/home/"):
    if vietata in readme:
        problemi.append("«%s»" % vietata)
print("; ".join(problemi) or "README a posto")
PY
  expect "README: sezioni, frasi con l'indirizzo, prompt, niente di vietato" \
    0 "README a posto"
}

t_prepara() {
  local ws
  if ! nuovo_ws ws; then
    fail "prepara_esercizio.sh M6-D03: $(tail -n 3 "${TMP}/prepara.log")"
    return
  fi
  pass "prepara_esercizio.sh M6-D03"
  vero "spazio di lavoro: il README del gestionale" \
    test -f "${ws}/${GESTIONALE}/README.md"
  vero "spazio di lavoro: il composer.json del gestionale" \
    test -f "${ws}/${GESTIONALE}/composer.json"
  vero "spazio di lavoro: tools/php.sh eseguibile" test -x "${ws}/tools/php.sh"
  if [[ ! -e "${ws}/${GESTIONALE}/vendor" \
      && ! -e "${ws}/${GESTIONALE}/_docente" && ! -e "${ws}/soluzione" ]]; then
    pass "spazio di lavoro: niente vendor/, _docente/ né soluzione/"
  else
    fail "spazio di lavoro: vendor/, _docente/ o soluzione/"
  fi
  run git -C "${ws}" ls-files -- '*CLAUDE.md'
  if [[ "${OUT}" == 'con-la-riga/CLAUDE.md' ]]; then
    pass "spazio di lavoro: nessun CLAUDE.md fuori da con-la-riga/"
  else
    fail "spazio di lavoro: i CLAUDE.md «${OUT}»"
  fi
  run "${RADICE}/tools/verifica.sh" M6-D03 --radice "${ws%/M6-D03}"
  expect "verifica.sh sul punto di partenza: 1" 1 \
    "Manca la cartella risposte/"
}

# --- Il controllo -----------------------------------------------------------

t_controllo() {
  local j
  nuova_serie j 3
  controlla "${j}"
  expect "controllo: tre coppie, 0" 0 "confermata 3 su 3"
  expect_absent "controllo: nessun «non distinguibile»" "${NONDIST}"
  expect_absent "controllo: nessun «non confermata»" "${NONCONF}"
  expect "controllo: le quattro righe, stampate" 0 \
    "  | - Test, da questa cartella: \`../../tools/php.sh phpunit\`."
  expect "controllo: i passi, nell'ordine" 0 \
    "2. Bash: ../../tools/php.sh phpunit"
  expect "controllo: la suite che ha girato, con il riepilogo" 0 \
    "la suite: ha girato, «OK (44 tests, 107 assertions)»"
  expect "controllo: la suite che non ha girato" 0 \
    "la suite: non ha girato (nessun riepilogo di PHPUnit"
  expect "controllo: i numeri della risposta contro il riepilogo" 0 \
    "i numeri della risposta: 44 passati sì, 0 falliti sì"
  expect "controllo: il README non letto" 0 \
    "il README del gestionale: non letto"
  expect "controllo: tools/php.sh" 0 "tools/php.sh: usato"
  expect "controllo: la prima richiesta dei due bracci" 0 \
    "esecuzione 1: con 5.047, senza 5.003 token (+44)"
  expect "controllo: i dati per braccio" 0 \
    "senza: la suite ha girato 0 su 3, il README letto 0 su 3;"
  rifai "${j}" senza-2 FINTO_SUITE_SEMPRE=1
  controlla "${j}"
  expect "esito: la suite anche senza la riga, non distinguibile, 0" 0 \
    "esecuzione 2: ${NONDIST} (la suite ha girato anche senza)"
  expect "esito: la conta scende a 2 su 3" 0 "confermata 2 su 3"
  expect "esito: il README letto, al passo" 0 \
    "il README del gestionale: letto, al passo 2"
  rifai "${j}" senza-2
  rifai "${j}" con-1 FINTO_SUITE_MAI=1
  controlla "${j}"
  expect "esito: con la riga la suite non ha girato, non confermata, 0" 0 \
    "esecuzione 1: ${NONCONF}"
  rifai "${j}" con-1 FINTO_FALLITI=2
  controlla "${j}"
  expect "riepilogo: i test falliti" 0 \
    "«Tests: 44, Assertions: 107, Failures: 2.»"
  expect "riepilogo: i numeri della risposta contro i falliti" 0 \
    "42 passati sì, 2 falliti sì"
  rifai "${j}" con-1
  rifai "${j}" senza-1 FINTO_CASA=1
  controlla "${j}"
  expect "comandi: la home stampata come «~»" 0 "ls ~/bin"
  expect_absent "comandi: mai il percorso della home" "${HOME}/bin"
}

t_mancanze() {
  local j
  nuova_serie j 2
  rm -r -- "${j}/senza-2"
  controlla "${j}"
  expect "mancanza: un'esecuzione senza la sua coppia, 1" 1 \
    "manca senza-2/stream.jsonl"
  nuova_serie j 1
  rifai "${j}" con-1 FINTO_TRONCO=1
  controlla "${j}"
  expect "mancanza: uno stream senza il risultato, 1" 1 \
    "non finisce con il risultato"
  nuova_serie j 1
  rifai "${j}" senza-1 FINTO_ERRORE=1
  controlla "${j}"
  expect "mancanza: un risultato con l'errore, 1" 1 \
    "claude ha restituito un errore"
}

t_illeggibili() {
  local j
  nuova_serie j 1
  rifai "${j}" con-1 FINTO_RIGA_ROTTA=1
  controlla "${j}"
  expect "illeggibile: una riga che non è JSON, 2" 2 "non è JSON"
  j="$(mktemp -d "${TMP}/vuota.XXXXXX")"
  controlla "${j}"
  expect "illeggibile: una cartella senza esecuzioni, 2" 2 \
    "nessuna esecuzione"
  controlla "${TMP}/non-c-e"
  expect "illeggibile: una cartella che non c'è, 2" 2 "non esiste"
  controlla
  expect "uso: senza argomenti, 2" 2 "Uso:"
  nuova_serie j 1
  run env PN_HANDSON_ROOT="${TMP}/non-c-e" python3 -B -I \
    "${D03}/demo/controlla_comandi.py" "${j}"
  expect "precondizione: tools/ che non c'è, 2" 2 \
    "non trovo tools/lib_leggi_contesto.py"
  mkdir -p "${TMP}/senza_riga" || exit 2
  cp -- "${D03}/demo/controlla_comandi.py" "${TMP}/senza_riga/" || exit 2
  run env PN_HANDSON_ROOT="${RADICE}" python3 -B -I \
    "${TMP}/senza_riga/controlla_comandi.py" "${j}"
  expect "precondizione: il CLAUDE.md del braccio che manca, 2" 2 \
    "manca con-la-riga/CLAUDE.md"
}

t_verifica() {
  local ws
  nuovo_ws ws || { fail "verifica: prepara_esercizio.sh"; return; }
  run "${D03}/verifica.sh" "${ws}"
  expect "verifica: senza risposte/, 1" 1 "Manca la cartella risposte/"
  mkdir -p "${ws}/risposte" || exit 2
  run "${D03}/verifica.sh" "${ws}"
  expect "verifica: risposte/ vuota, 1" 1 "nessuna esecuzione"
  serie "${ws}/risposte" 1
  printf '%s\n' 'print("CONTROLLO FINTO")' \
    > "${ws}/controlla_comandi.py" || exit 2
  run env PN_HANDSON_ROOT="${RADICE}" "${D03}/verifica.sh" "${ws}"
  expect "verifica: una serie completa, 0, «Fatto»" 0 "${FATTO}"
  expect_absent "verifica: il controllo dell'elemento, non della copia" \
    "CONTROLLO FINTO"
  rm -r -- "${ws}/risposte/senza-1"
  run "${D03}/verifica.sh" "${ws}"
  expect "verifica: un'esecuzione che manca, 1" 1 "manca senza-1"
  run "${D03}/verifica.sh"
  expect "verifica: senza argomenti, 2" 2 "spazio di lavoro assente"
}

# --- in_classe.sh e live.sh -------------------------------------------------

t_in_classe() {
  local ws
  nuovo_ws ws || { fail "in_classe: prepara_esercizio.sh"; return; }
  finto "${D03}/demo/in_classe.sh" "${ws}" PN_ESECUZIONI=2
  expect "in_classe: due esecuzioni per braccio, 0" 0 \
    "VERIFICA OK   il controllo, sulle esecuzioni di risposte/"
  expect "in_classe: le regole negate, sullo schermo" 0 \
    "--disallowedTools 'Bash(sudo *),Bash(git push *),Bash(curl *),"
  expect "in_classe: la coppia, sullo schermo" 0 "confermata 2 su 2"
  controlla_chiamate "${TMP}/finto.log" "${ws}" 2
  expect "in_classe: le chiamate, le copie, i file, le opzioni" 0 \
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
  expect "live: tre esecuzioni per braccio, 0" 0 \
    "VERIFICA OK   verifica.sh dell'elemento"
  expect "live: la coppia, tre su tre" 0 "confermata 3 su 3"
  controlla_chiamate "${TMP}/finto.log" "${ws}" 3
  expect "live: le sei chiamate" 0 "chiamate giuste"
  run "${RADICE}/tools/verifica.sh" M6-D03 --radice "${ws%/M6-D03}"
  expect "live: poi tools/verifica.sh, 0" 0 "VERIFICA OK   M6-D03: fatto."
  run "${D03}/_docente/live.sh"
  expect "live: senza argomenti, 2" 2 "uso:"
}

t_precondizioni() {
  local ws s="${D03}/demo/in_classe.sh"
  nuovo_ws ws || { fail "precondizioni: prepara_esercizio.sh"; return; }
  precondizione "precondizione: una cartella che non è lo spazio" \
    "non è lo spazio di lavoro di M6-D03" "${s}" "${TMP}"
  precondizione "precondizione: nessuno spazio di lavoro" \
    "spazio di lavoro assente" "${s}" ""
  precondizione "precondizione: PN_ESECUZIONI 0" "PN_ESECUZIONI" \
    "${s}" "${ws}" "${TMP}/esca:${TMP}/finto:${PATH}" PN_ESECUZIONI=0
  precondizione "precondizione: HANDSON_ENV claude-ai-pro" \
    "è un elemento claude-code-pro" "${s}" "${ws}" \
    "${TMP}/esca:${TMP}/finto:${PATH}" HANDSON_ENV=claude-ai-pro
  precondizione "precondizione: senza python3" "manca lo strumento: python3" \
    "${s}" "${ws}" "${TMP}/senza_python"
  precondizione "precondizione: senza claude" "manca lo strumento: claude" \
    "${s}" "${ws}" "${TMP}/senza_claude"
  precondizione "precondizione: né PHP né Docker" \
    "servono PHP 8.3 o Docker" "${s}" "${ws}" "${TMP}/senza_php"
  printf 'x\n' > "${ws}/estraneo.txt" || exit 2
  precondizione "precondizione: uno spazio di lavoro cambiato" \
    "non è al punto di partenza" "${s}" "${ws}"
  rm -f -- "${ws}/estraneo.txt"
  mkdir -p "${ws}/risposte" || exit 2
  precondizione "precondizione: risposte/ c'è già" \
    "non è al punto di partenza" "${s}" "${ws}"
  rmdir -- "${ws}/risposte"
  mv -- "${ws}/richiesta.txt" "${TMP}/richiesta.txt" || exit 2
  precondizione "precondizione: la richiesta che manca" \
    "file assente o illeggibile: richiesta.txt" "${s}" "${ws}"
  precondizione "precondizione: senza tools/lib_handson.sh" \
    "lanciatelo dal repository, o date PN_HANDSON_ROOT" "${s}" "${ws}" \
    "${TMP}/esca:${TMP}/finto:${PATH}" PN_HANDSON_ROOT="${TMP}/non-c-e"
}

t_fallita() {
  local ws
  nuovo_ws ws || { fail "fallita: prepara_esercizio.sh"; return; }
  finto "${D03}/demo/in_classe.sh" "${ws}" FINTO_KO_SE=/con-1/
  expect "fallita: una chiamata che fallisce, 1" 1 \
    "VERIFICA KO   con-1: claude -p è fallito"
  vero "fallita: ciò che c'era è in risposte/" \
    test -s "${ws}/risposte/senza-1/stream.jsonl"
  run "${D03}/verifica.sh" "${ws}"
  expect "fallita: verifica.sh dopo, 1" 1 "con-1"
}

# Gli script di M6-D03 e questo file, con shellcheck -x.
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
      || { echo "test_m6_d03: manca ${t}" >&2; exit 2; }
  done
  [[ -f "${FINTO_PY}" ]] \
    || { echo "test_m6_d03: manca ${FINTO_PY}" >&2; exit 2; }
  handson::init_temp_base
  TMP="$(mktemp -d "${HANDSON_TEMP_BASE}/test_m6_d03.XXXXXX")" || exit 2
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
  echo "PASS=${PASS} FAIL=${FAIL} SKIP=${SKIP}"
  if (( PASS + FAIL + SKIP != CASES )); then
    echo "test_m6_d03: girati $((PASS + FAIL + SKIP)) casi, attesi" \
      "${CASES}" >&2
    exit 2
  fi
  (( FAIL == 0 )) || exit 1
}

main "$@"
