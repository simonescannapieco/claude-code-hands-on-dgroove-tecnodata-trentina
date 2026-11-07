#!/bin/bash
#
# test_m6_d01.sh -- le prove di M6-D01 «Il documento che nessun modello ha
# letto», per il docente (sta in _docente/, il materiale del docente):
#   - l'elemento: demo/carta-servizi.md è la carta del modulo, la stessa di
#     M6-D05 se c'è; la domanda; il CLAUDE.md del braccio con, che la importa;
#     le dieci sezioni del README, le frasi di Anthropic con il loro
#     indirizzo, il prompt uguale al file; nessun identificativo interno,
#     «smentita» o riferimento alla giornata;
#   - prepara_esercizio.sh e verifica.sh sul punto di partenza (1);
#   - controlla_documento.py su stream del claude finto: le esecuzioni, le
#     citazioni, la coppia (un esito non cambia mai l'uscita, 0); le
#     esecuzioni che mancano o non finiscono (1); gli stream che non si
#     leggono e gli usi sbagliati (2), mai un traceback;
#   - verifica.sh: il controllo dell'elemento, mai quello dello spazio di
#     lavoro; risposte/ che manca o vuota (1); le precondizioni (2);
#   - demo/in_classe.sh e _docente/live.sh con il claude finto: quante
#     chiamate, in che ordine, da quale copia e con quali file, testi e
#     opzioni, senza ANTHROPIC_API_KEY, con la auto memory spenta; le copie
#     tolte; lo spazio di lavoro intatto fuori da risposte/; le precondizioni
#     (2, nessuna chiamata: l'esca); una chiamata fallita (1);
#   - shellcheck -x sugli script e su questo file.
# Mai il claude vero: il finto e l'esca stanno davanti nel PATH, e la suite lo
# controlla prima di usarli. Gli stream del finto non sono risposte di Claude:
# provano il controllo, non il modello. Gli spazi di lavoro nascono in una
# cartella temporanea: l'albero del repository non cambia. CASES è il numero
# dei casi: se ne girano di più o di meno la suite esce 2.
#
# Uso:    m6_projects_context/_docente/test_m6_d01.sh
# Uscita: 0 = tutti i casi passano · 1 = almeno un caso fallito · 2 =
#         precondizione (manca python3, git, tar o shellcheck), o un numero di
#         casi diverso da CASES
set -uo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly MOD="${SELF%/_docente/*}"
readonly RADICE="${MOD%/*}"
D01="${MOD}/s5_projects_context/m6_2_il_contesto_e_tutto"
D01+="/M6-D01_documento_mai_letto"
readonly D01
readonly FINTO_PY="${MOD}/_docente/claude_finto_m6_d01_d03.py"
# La libreria del repository, per la base dei file temporanei.
# shellcheck source=../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"
readonly CASES=105
SHA_CARTA='9976b58d5450e43d6d61d572f298778fa6d7131999da47ab63f64006da4eae4a'
readonly SHA_CARTA
Q='Entro quanti giorni lavorativi va fatto un intervento su un ponte radio'
Q+=' in quota?'
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
  "${RADICE}/tools/prepara_esercizio.sh" M6-D01 --radice "${__r}" \
    > "${TMP}/prepara.log" 2>&1 || return 1
  printf -v "$1" '%s' "${__r}/M6-D01"
}

# L'esca (registra ogni invocazione ed esce 0), il claude finto e i PATH
# ridotti. Esce 2 se nel PATH di prova claude non è il finto.
prepara_claude() {
  local t
  mkdir -p "${TMP}/esca" "${TMP}/finto" "${TMP}/senza_python" \
    "${TMP}/senza_claude" || exit 2
  # shellcheck disable=SC2016  # il corpo è dell'esca
  printf '%s\n' '#!/bin/bash' \
    'printf "invocazione %s\n" "$*" >> "${ESCA_LOG}"' \
    > "${TMP}/esca/claude" || exit 2
  cp -- "${FINTO_PY}" "${TMP}/finto/claude" || exit 2
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
    echo "test_m6_d01: nel PATH di prova claude è ${t}, non il finto" >&2
    exit 2
  fi
}

# Una serie di esecuzioni del finto, come le fa in_classe.sh: una copia per
# esecuzione, in una cartella con il suo nome, con la carta nel braccio con.
# Arguments: $1 la cartella degli stream, $2 quante esecuzioni, poi le
# variabili NOME=valore per tutte.
serie() {
  local json="$1" n="$2" k b
  shift 2
  for (( k = 1; k <= n; k++ )); do
    for b in senza con; do
      rifai "${json}" "${b}-${k}" "$@"
    done
  done
}

# Rifà un'esecuzione della serie, con le variabili date.
# Arguments: $1 la cartella degli stream, $2 il nome (senza-1, con-2…), poi le
# variabili NOME=valore.
rifai() {
  local json="$1" nome="$2" copia
  shift 2
  copia="$(mktemp -d "${TMP}/copie.XXXXXX")/${nome}" || exit 2
  mkdir -p "${copia}/.claude" "${json}/${nome}" || exit 2
  if [[ "${nome}" == con-* ]]; then
    mkdir -p "${copia}/docs" || exit 2
    cp -- "${D01}/demo/con-la-carta/CLAUDE.md" "${copia}/CLAUDE.md" || exit 2
    cp -- "${D01}/demo/carta-servizi.md" "${copia}/docs/" || exit 2
  fi
  ( cd "${copia}" && env "$@" "${TMP}/finto/claude" -p --model sonnet \
      --output-format stream-json --verbose -- "${Q}" ) \
    > "${json}/${nome}/stream.jsonl" \
    || { echo "test_m6_d01: il finto non scrive ${nome}" >&2; exit 2; }
}

# Una cartella nuova di stream, con le esecuzioni da 1 a $2.
# Arguments: $1 la variabile da assegnare, $2 quante esecuzioni.
nuova_serie() {
  local __j
  __j="$(mktemp -d "${TMP}/json.XXXXXX")" || exit 2
  serie "${__j}" "$2"
  printf -v "$1" '%s' "${__j}"
}

# controlla_documento.py dell'elemento; RC e OUT come run.
controlla() { run python3 -B -I "${D01}/demo/controlla_documento.py" "$@"; }

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
# ordine, da quale copia, con quali file, testo e opzioni.
# Arguments: $1 il registro, $2 lo spazio di lavoro, $3 quante esecuzioni.
controlla_chiamate() {
  run python3 -B -I - "$1" "$2" "$3" "${Q}" "${D01}/demo" <<'PY'
import hashlib, json, os, sys
log, ws, n, q, demo = sys.argv[1:6]
def sha(p):
    return hashlib.sha256(open(p, "rb").read()).hexdigest()
righe = [json.loads(r) for r in open(log, encoding="utf-8")]
chiamate = [r for r in righe if r["argv"][:1] != ["--version"]]
attese = (["senza-%d" % k for k in range(1, int(n) + 1)]
          + ["con-%d" % k for k in range(1, int(n) + 1)])
VALORE = {"--model", "--effort", "--output-format", "--setting-sources",
          "--permission-mode", "--permission-prompts", "--allowedTools",
          "--tools"}
fisse = (("--model", "sonnet"), ("--effort", "low"),
         ("--output-format", "stream-json"),
         ("--setting-sources", "project,local"),
         ("--permission-mode", "dontAsk"), ("--permission-prompts", "none"),
         ("--allowedTools", "Read,Glob,Grep"), ("--tools", "Read,Glob,Grep"))
impostazioni = sha(os.path.join(ws, ".claude", "settings.json"))
file_con = {".claude/settings.json": impostazioni,
            "CLAUDE.md": sha(os.path.join(demo, "con-la-carta", "CLAUDE.md")),
            "docs/carta-servizi.md": sha(os.path.join(demo,
                                                     "carta-servizi.md"))}
problemi = []
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
    if os.path.basename(c["cwd"]) != nome:
        problemi.append("chiamata %d: la copia %s, non %s" % (i, c["cwd"],
                                                            nome))
    if os.path.realpath(c["cwd"]).startswith(os.path.realpath(ws) + "/"):
        problemi.append("chiamata %d: dentro lo spazio di lavoro" % i)
    if c["radice"] != c["cwd"]:
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
    attesi = file_con if nome.startswith("con") \
        else {".claude/settings.json": impostazioni}
    if c["file"] != attesi:
        problemi.append("chiamata %d: i file %s" % (i, sorted(c["file"])))
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
    if os.path.exists(c["cwd"]):
        problemi.append("chiamata %d: la copia è rimasta" % i)
print("; ".join(problemi) or "chiamate giuste")
PY
}

# --- L'elemento -------------------------------------------------------------

t_elemento() {
  local f d05
  for f in README.md verifica.sh demo/carta-servizi.md demo/domanda.txt \
      demo/con-la-carta/CLAUDE.md demo/controlla_documento.py \
      demo/in_classe.sh _docente/live.sh soluzione/LEGGIMI.md; do
    vero "elemento: ${f}" test -f "${D01}/${f}"
  done
  for f in verifica.sh _docente/live.sh demo/in_classe.sh; do
    vero "elemento: ${f} eseguibile" test -x "${D01}/${f}"
  done
  run python3 -B -I -c 'import hashlib, sys
print(hashlib.sha256(open(sys.argv[1], "rb").read()).hexdigest())' \
    "${D01}/demo/carta-servizi.md"
  expect "carta-servizi.md: la carta del modulo, byte per byte" 0 \
    "${SHA_CARTA}"
  d05="${MOD}/s5_projects_context/m6_7_projects_claude_ai"
  d05="$(compgen -G "${d05}/M6-D05_*/demo/carta-servizi.md" | head -n 1)"
  if [[ -z "${d05}" ]]; then
    skip "carta-servizi.md di M6-D05: non c'è ancora"
  else
    vero "carta-servizi.md: la stessa di M6-D05" \
      cmp -s "${D01}/demo/carta-servizi.md" "${d05}"
  fi
  run cat -- "${D01}/demo/domanda.txt"
  if [[ "${OUT}" == "${Q}" ]]; then
    pass "domanda.txt: la domanda, una riga"
  else
    fail "domanda.txt: «${OUT}»"
  fi
  run python3 -B -I - "${D01}/demo/con-la-carta/CLAUDE.md" <<'PY'
import re, sys
righe = open(sys.argv[1], encoding="utf-8").read().splitlines()
ok = righe[0].startswith("# ") and len(righe) < 200 and any(
    re.search(r"(?<!`)@docs/carta-servizi\.md(?!`)", r)
    and r.startswith("- ") for r in righe)
print("CLAUDE.md a posto" if ok else "CLAUDE.md: %r" % righe)
PY
  expect "con-la-carta/CLAUDE.md: un titolo e l'import, fuori dai backtick" \
    0 "CLAUDE.md a posto"
}

# Il README: le dieci sezioni, le frasi di Anthropic, il prompt uguale al
# file; niente identificativi interni, giornate, «smentita».
t_readme() {
  run python3 -B -I - "${D01}" "${Q}" <<'PY'
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
for titolo in ("## Punto di partenza (tools/prepara_esercizio.sh M6-D01)",
               "## Verifica (tools/verifica.sh M6-D01)"):
    if titolo not in readme:
        problemi.append("il titolo «%s»" % titolo)
WM = "https://academy.claude.com/courses/ai-capabilities-and-limitations/" \
    "working-memory"
RH = "https://platform.claude.com/docs/en/test-and-evaluate/" \
    "strengthen-guardrails/reduce-hallucinations"
frasi = [
    ("The model doesn't learn from your corrections. It only responds to "
     "what's currently in context.", WM),
    ("Probe 1: Cold start vs. context.", WM),
    ("Even the most advanced language models, such as Claude, can "
     "sometimes generate text that is factually incorrect or inconsistent "
     "with the given context.", RH),
    ("Allow Claude to say \"I don't know\": Explicitly give Claude "
     "permission to admit uncertainty.", RH),
    ("CLAUDE.md files can import additional files using @path/to/import "
     "syntax.", "https://code.claude.com/docs/en/memory")]
piano = " ".join(readme.split())
for frase, url in frasi:
    if frase not in piano:
        problemi.append("manca «%s»" % frase[:40])
    if url not in readme:
        problemi.append("manca %s" % url)
blocco = re.search(r"<!-- prompt 1 -->\n(.*?)<!-- /prompt 1 -->", readme,
                   re.S)
if not blocco or " ".join(blocco.group(1).split()) != q:
    problemi.append("il prompt 1 non è domanda.txt")
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
  local ws f
  if ! nuovo_ws ws; then
    fail "prepara_esercizio.sh M6-D01: $(tail -n 3 "${TMP}/prepara.log")"
    return
  fi
  pass "prepara_esercizio.sh M6-D01"
  for f in carta-servizi.md domanda.txt con-la-carta/CLAUDE.md \
      controlla_documento.py in_classe.sh .claude/settings.json; do
    vero "spazio di lavoro: ${f}" test -f "${ws}/${f}"
  done
  if [[ ! -e "${ws}/soluzione" && ! -e "${ws}/_docente" \
      && ! -e "${ws}/CLAUDE.md" ]]; then
    pass "spazio di lavoro: niente soluzione/, _docente/ né CLAUDE.md"
  else
    fail "spazio di lavoro: soluzione/, _docente/ o CLAUDE.md alla radice"
  fi
  run "${RADICE}/tools/verifica.sh" M6-D01 --radice "${ws%/M6-D01}"
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
  expect "controllo: la carta, l'Art. 4 e i suoi giorni" 0 \
    "dice 5 e 9 giorni lavorativi."
  expect "controllo: gli strumenti, relativi alla copia" 0 \
    "Grep «ponte radio|in quota» in .: nessun risultato"
  expect "controllo: le cifre senza la carta, no" 0 \
    "le cifre dell'Art. 4, 5 e 9 giorni lavorativi: no"
  expect "controllo: le cifre con la carta, sì" 0 \
    "le cifre dell'Art. 4, 5 e 9 giorni lavorativi: sì"
  expect "controllo: le citazioni, una dimostrazione" 0 \
    "con-1, Art. 4 «Interventi sugli apparati in quota»: nella carta 1.200"
  expect "controllo: i numeri della risposta nell'articolo citato" 0 \
    "i numeri della risposta negli articoli citati: tutti"
  expect "controllo: la prima richiesta dei due bracci" 0 \
    "esecuzione 1: con 5.611, senza 5.003 token (+608)"
  expect "controllo: il consumo di tutte le chiamate" 0 \
    "Come dati, tutte le 6 chiamate: turni 12"
  rifai "${j}" senza-2 FINTO_CIFRE_SENZA=1
  controlla "${j}"
  expect "esito: le cifre anche senza la carta, non distinguibile, 0" 0 \
    "esecuzione 2: ${NONDIST}"
  expect "esito: la conta scende a 2 su 3" 0 "confermata 2 su 3"
  expect "esito: i numeri inventati, come dati" 0 \
    "i numeri della risposta, fuori da citazioni e date: 5, 9"
  rifai "${j}" senza-2
  rifai "${j}" con-1 FINTO_SENZA_CIFRE=1
  controlla "${j}"
  expect "esito: con la carta senza le cifre, non confermata, 0" 0 \
    "esecuzione 1: ${NONCONF}"
  rifai "${j}" con-1 FINTO_ARTICOLO=12
  controlla "${j}"
  expect "citazioni: un articolo che la carta non ha" 0 \
    "con-1, Art. 12: non c'è nella carta"
  expect "citazioni: i numeri fuori dagli articoli citati" 0 \
    "i numeri della risposta negli articoli citati: non 5, 9"
  rifai "${j}" con-1 FINTO_DATA=1
  controlla "${j}"
  expect "citazioni: con una data nella risposta, i numeri sono 5 e 9" 0 \
    "i numeri della risposta, fuori da citazioni e date: 5, 9"
  expect_absent "citazioni: il giorno e l'anno della data non sono numeri" \
    "fuori da citazioni e date: 5, 9, "
  expect_absent "citazioni: nessun numero fuori dagli articoli, con la data" \
    "negli articoli citati: non"
  rifai "${j}" con-1
  rifai "${j}" senza-3 "FINTO_PERDITA=${D01}/demo/carta-servizi.md"
  controlla "${j}"
  expect "fuga: un risultato senza la carta che la contiene, 0" 0 \
    "il risultato contiene righe della carta: è la fuga da cercare"
  expect "fuga: il percorso fuori dalla copia, segnato" 0 \
    "(fuori dalla cartella)"
}

t_mancanze() {
  local j
  nuova_serie j 2
  rm -r -- "${j}/con-2"
  controlla "${j}"
  expect "mancanza: un'esecuzione senza la sua coppia, 1" 1 \
    "manca con-2/stream.jsonl"
  nuova_serie j 1
  rifai "${j}" senza-1 FINTO_TRONCO=1
  controlla "${j}"
  expect "mancanza: uno stream senza il risultato, 1" 1 \
    "non finisce con il risultato"
  nuova_serie j 1
  rifai "${j}" con-1 FINTO_ERRORE=1
  controlla "${j}"
  expect "mancanza: un risultato con l'errore, 1" 1 \
    "claude ha restituito un errore"
  nuova_serie j 1
  : > "${j}/senza-1/stream.jsonl"
  controlla "${j}"
  expect "mancanza: uno stream vuoto, 1" 1 "senza-1: lo stream non finisce"
}

t_illeggibili() {
  local j
  nuova_serie j 1
  rifai "${j}" senza-1 FINTO_RIGA_ROTTA=1
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
  controlla --aiuto
  expect "uso: un'opzione, 2" 2 "Uso:"
  nuova_serie j 1
  run env PN_HANDSON_ROOT="${TMP}/non-c-e" python3 -B -I \
    "${D01}/demo/controlla_documento.py" "${j}"
  expect "precondizione: tools/ che non c'è, 2" 2 \
    "non trovo tools/lib_leggi_contesto.py"
  mkdir -p "${TMP}/senza_carta" || exit 2
  cp -- "${D01}/demo/controlla_documento.py" "${TMP}/senza_carta/" || exit 2
  run env PN_HANDSON_ROOT="${RADICE}" python3 -B -I \
    "${TMP}/senza_carta/controlla_documento.py" "${j}"
  expect "precondizione: la carta accanto al controllo che manca, 2" 2 \
    "manca carta-servizi.md"
}

t_verifica() {
  local ws j
  nuovo_ws ws || { fail "verifica: prepara_esercizio.sh"; return; }
  run "${D01}/verifica.sh" "${ws}"
  expect "verifica: senza risposte/, 1" 1 "Manca la cartella risposte/"
  mkdir -p "${ws}/risposte" || exit 2
  run "${D01}/verifica.sh" "${ws}"
  expect "verifica: risposte/ vuota, 1" 1 "nessuna esecuzione"
  serie "${ws}/risposte" 1
  printf '%s\n' 'print("CONTROLLO FINTO")' \
    > "${ws}/controlla_documento.py" || exit 2
  run env PN_HANDSON_ROOT="${RADICE}" "${D01}/verifica.sh" "${ws}"
  expect "verifica: una serie completa, 0, «Fatto»" 0 "${FATTO}"
  expect_absent "verifica: il controllo dell'elemento, non della copia" \
    "CONTROLLO FINTO"
  rm -r -- "${ws}/risposte/con-1"
  run "${D01}/verifica.sh" "${ws}"
  expect "verifica: un'esecuzione che manca, 1" 1 "manca con-1"
  run "${D01}/verifica.sh"
  expect "verifica: senza argomenti, 2" 2 "spazio di lavoro assente"
}

# --- in_classe.sh e live.sh -------------------------------------------------

t_in_classe() {
  local ws
  nuovo_ws ws || { fail "in_classe: prepara_esercizio.sh"; return; }
  finto "${D01}/demo/in_classe.sh" "${ws}" PN_ESECUZIONI=2
  expect "in_classe: due esecuzioni per braccio, 0" 0 \
    "VERIFICA OK   il controllo, sulle esecuzioni di risposte/"
  expect "in_classe: il comando sullo schermo" 0 \
    "--no-session-persistence"
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
  run env PN_HANDSON_ROOT="${RADICE}" "${D01}/verifica.sh" "${ws}"
  expect "in_classe: poi verifica.sh, 0" 0 "${FATTO}"
}

t_live() {
  local ws
  nuovo_ws ws || { fail "live: prepara_esercizio.sh"; return; }
  finto "${D01}/_docente/live.sh" "${ws}"
  expect "live: tre esecuzioni per braccio, 0" 0 \
    "VERIFICA OK   verifica.sh dell'elemento"
  expect "live: la coppia, tre su tre" 0 "confermata 3 su 3"
  controlla_chiamate "${TMP}/finto.log" "${ws}" 3
  expect "live: le sei chiamate" 0 "chiamate giuste"
  run "${RADICE}/tools/verifica.sh" M6-D01 --radice "${ws%/M6-D01}"
  expect "live: poi tools/verifica.sh, 0" 0 "VERIFICA OK   M6-D01: fatto."
  run "${D01}/_docente/live.sh"
  expect "live: senza argomenti, 2" 2 "uso:"
}

t_precondizioni() {
  local ws s="${D01}/demo/in_classe.sh"
  nuovo_ws ws || { fail "precondizioni: prepara_esercizio.sh"; return; }
  precondizione "precondizione: una cartella che non è lo spazio" \
    "non è lo spazio di lavoro di M6-D01" "${s}" "${TMP}"
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
  precondizione "precondizione: senza tools/lib_handson.sh" \
    "lanciatelo dal repository, o date PN_HANDSON_ROOT" "${s}" "${ws}" \
    "${TMP}/esca:${PATH}" PN_HANDSON_ROOT="${TMP}/non-c-e"
}

t_fallita() {
  local ws
  nuovo_ws ws || { fail "fallita: prepara_esercizio.sh"; return; }
  finto "${D01}/demo/in_classe.sh" "${ws}" FINTO_KO_SE=/con-1
  expect "fallita: una chiamata che fallisce, 1" 1 \
    "VERIFICA KO   con-1: claude -p è fallito"
  vero "fallita: ciò che c'era è in risposte/" \
    test -s "${ws}/risposte/senza-1/stream.jsonl"
  run "${D01}/verifica.sh" "${ws}"
  expect "fallita: verifica.sh dopo, 1" 1 "con-1"
}

# Gli script di M6-D01 e questo file, con shellcheck -x.
t_shellcheck() {
  local f
  for f in "${D01}/verifica.sh" "${D01}/_docente/live.sh" \
      "${D01}/demo/in_classe.sh" "${SELF}"; do
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
      || { echo "test_m6_d01: manca ${t}" >&2; exit 2; }
  done
  [[ -f "${FINTO_PY}" ]] \
    || { echo "test_m6_d01: manca ${FINTO_PY}" >&2; exit 2; }
  handson::init_temp_base
  TMP="$(mktemp -d "${HANDSON_TEMP_BASE}/test_m6_d01.XXXXXX")" || exit 2
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
    echo "test_m6_d01: girati $((PASS + FAIL + SKIP)) casi, attesi" \
      "${CASES}" >&2
    exit 2
  fi
  (( FAIL == 0 )) || exit 1
}

main "$@"
