#!/bin/bash
#
# test_m3_d01.sh -- le prove di M3-D01 «Un'immagine leggibile», per il
# docente (sta in _docente/, il materiale del docente):
#   - i dati della demo: allarmi.html ha dieci allarmi, tre «critico», e
#     ognuno è un allarme della settimana di progetti/rete/allarmi.csv
#     (stesso apparato, stesso giorno e ora, la gravità coerente) su un
#     apparato dell'inventario; verita.json dice gli stessi critici; le due
#     immagini sono PNG di 1600×1000 e di 160×100, la grande sotto i 256
#     KB; prompt.txt chiede le due righe o «non leggibile» e nomina
#     IMMAGINE una volta; .claude/settings.json tiene le regole prudenti
#     del repository e nega a Read la pagina, la verità, gli esiti e le
#     risposte; prepara_esercizio.sh porta tutto nello spazio di lavoro, e
#     verifica.sh vi esce 1;
#   - controlla_lettura.py su risposte finte scritte qui: ogni lettura (le
#     due righe con elenchi puntati, grassetto, codice, maiuscole, nomi in
#     un altro ordine, «e», un numero in lettere, note fra parentesi; un
#     valore sbagliato; un nome in più; una riga sola; «nessuno»; «non
#     leggibile», anche come valore; senza le due righe), ogni verdetto
#     delle due raccomandazioni sulle coppie e del «può» sulla piccola, i
#     riepiloghi «n su 3», mai «smentita»; esiti.tsv; le risposte rovinate
#     (manca, vuota, non JSON, un elenco, is_error, un subtype d'errore,
#     senza result o con un result vuoto) con l'uscita 1 e senza
#     traceback; risposte/ che manca (1, un esiti.tsv vecchio tolto);
#     --senza-esiti; le precondizioni con l'uscita 2 (argomenti, spazio di
#     lavoro, verita.json assente, non JSON o non valido, una risposta che
#     non si legge, esiti.tsv che non si scrive, un errore inatteso);
#   - verifica.sh: spazio di lavoro assente (2), punto di partenza (1),
#     risposte complete (0, la frase finale, nessun esiti.tsv scritto),
#     una risposta che manca (1), un esiti.tsv falso che non conta (1),
#     python3 che manca (2), un controllo che esce 3 o per un segnale (2);
#   - _docente/live.sh: le precondizioni escono 2 senza chiamare claude
#     (un claude esca registra ogni invocazione, anche --version); con il
#     claude finto (claude_finto_m3_demo.py, dietro un involucro che
#     registra la cartella da cui parte ogni chiamata e che cosa contiene)
#     le dodici chiamate con i testi e le opzioni del passo 3 del README
#     (il suo blocco gira con lo stesso finto, e le chiamate si
#     confrontano), ciascuna dalla sottocartella della sua grandezza, con
#     soltanto la sua immagine e .claude/, senza ANTHROPIC_API_KEY, i dati
#     e i verdetti a schermo una volta sola anche quando passa; la prima
#     chiamata fallita (si ferma lì); risposte finte che cambiano i
#     verdetti senza far fallire; una modalità di permesso vietata (2,
#     nessuna chiamata al modello);
#   - il README: il titolo dei passi in Claude Code e in claude.ai, la
#     versione minima di Claude Code, il consiglio per WSL 2, la variabile
#     p nel recupero di una chiamata, il blocco della slide in 19 righe ×
#     66 colonne, mai «smentita»;
#   - _docente/genera_immagini.sh: argomenti, cartella d'uscita, pagina,
#     PN_BROWSER e browser che mancano (2); con un browser finto le due
#     immagini delle dimensioni giuste, la piccola dalla cornice; il
#     browser che fallisce (2), che non scrive (1) o che sbaglia una
#     dimensione (1), e allora le immagini vecchie restano; con il browser
#     vero, se c'è, le due immagini in una cartella temporanea (altrimenti
#     SKIP);
#   - shellcheck -x su verifica.sh, live.sh, genera_immagini.sh e questo
#     file.
# Mai il claude vero: il finto e l'esca stanno davanti nel PATH, e la
# suite lo controlla prima di usarli. Le risposte finte non sono risposte
# di Claude: provano il controllo, non il modello. Gli spazi di lavoro
# nascono in una cartella temporanea, nella base di handson::init_temp_base
# (mai dentro ~/.claude, anche se TMPDIR punta lì): l'albero del
# repository non cambia. CASES è il numero dei casi: se ne girano di più o
# di meno la suite esce 2 (un caso saltato conta come girato).
#
# Uso:    m3_funzionalita_claude/_docente/test_m3_d01.sh
# Uscita: 0 = tutti i casi passano · 1 = almeno un caso fallito · 2 =
#         precondizione (manca python3, git o shellcheck, o la cartella
#         dell'elemento), o un numero di casi diverso da CASES
set -uo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly MOD="${SELF%/_docente/*}"
readonly RADICE="${MOD%/*}"
D01="${MOD}/s2_funzionalita_claude/m3_2_chat_file_immagini"
D01+="/M3-D01_immagine_leggibile"
readonly D01
readonly FINTO_PY="${MOD}/_docente/claude_finto_m3_demo.py"
# La libreria del repository, per la base dei file temporanei
# (handson::init_temp_base): mai dentro ~/.claude, dove prepara_esercizio.sh
# rifiuta gli spazi di lavoro, anche se TMPDIR punta lì.
# shellcheck source=../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"
readonly CASES=143
readonly NA='—'
FINE='Fatto: ogni affermazione è stata messa alla prova;'
FINE+=' gli esiti sono qui sopra.'
readonly FINE
readonly PARTENZA='Manca la cartella risposte/: eseguite i passi del README.'
readonly APPARATI='olt-pergine-01, ptp-cles-01, sbc-trento-01'
readonly GIUSTA=$'critici: 3\napparati: '"${APPARATI}"
readonly S_LEGG='Testo leggibile, immagine grande'
readonly S_PICC='Sotto i 200 pixel, Claude può sbagliare'
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
# aggiunge a TUTTO, dove alla fine non deve esserci «smentita».
run() { OUT="$("$@" 2>&1)"; RC=$?; TUTTO+="${OUT}"$'\n'; }

# Uscita attesa E parola chiave attesa (RU-01.T3).
# Arguments: $1 il nome, $2 l'uscita attesa, $3 la parola (grep -F).
expect() {
  if (( RC == $2 )) && grep -qF -- "$3" <<< "${OUT}"; then
    pass "$1"
  else
    fail "$1 (rc=${RC}, attesa $2, parola «$3»): ${OUT:0:400}"
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

# Un nuovo spazio di lavoro: una copia di demo/, con .claude/.
# Arguments: $1 la variabile da assegnare.
ws() {
  local __w
  __w="$(mktemp -d "${TMP}/ws.XXXXXX")" || { echo "mktemp" >&2; exit 2; }
  cp -R "${D01}/demo/." "${__w}/" || exit 2
  printf -v "$1" '%s' "${__w}"
}

# Scrive in risposte/ il JSON di una risposta finta di claude -p.
# Arguments: $1 lo spazio di lavoro, $2 il file, $3 result, poi facoltativi
# chiave=JSON che aggiungono o cambiano un campo (chiave=- lo toglie).
risposta() {
  python3 -B -I - "$@" <<'PY'
import json, os, sys
ws, nome, testo = sys.argv[1:4]
doc = {"type": "result", "subtype": "success", "is_error": False,
       "result": testo, "num_turns": 2, "session_id": "sessione-finta"}
for coppia in sys.argv[4:]:
    chiave, _, valore = coppia.partition("=")
    if valore == "-":
        doc.pop(chiave, None)
    else:
        doc[chiave] = json.loads(valore)
os.makedirs(os.path.join(ws, "risposte"), exist_ok=True)
with open(os.path.join(ws, "risposte", nome), "w", encoding="utf-8") as fh:
    json.dump(doc, fh, ensure_ascii=False)
PY
}

# Le dodici risposte finte: la grande letta giusta, la piccola rifiutata.
# Arguments: $1 lo spazio di lavoro.
complete() {
  local m n
  for m in haiku sonnet; do
    for n in 1 2 3; do
      risposta "$1" "grande-${m}-${n}.json" "${GIUSTA}"
      risposta "$1" "piccola-${m}-${n}.json" 'non leggibile'
    done
  done
}

# controlla_lettura.py nello spazio di lavoro $1, con gli argomenti che
# seguono; RC e OUT come run.
controlla() {
  local w="$1"
  shift
  OUT="$(cd "${w}" && python3 -B -I controlla_lettura.py "$@" 2>&1)"
  RC=$?
  TUTTO+="${OUT}"$'\n'
}

# Uno spazio di lavoro con le risposte complete, poi quelle date (coppie
# file testo), poi il controllo con --senza-esiti.
# Arguments: $1 la variabile da assegnare, poi le coppie.
con() {
  local __c __v="$1"
  shift
  ws __c
  complete "${__c}"
  while (( $# >= 2 )); do
    risposta "${__c}" "$1" "$2"
    shift 2
  done
  controlla "${__c}" --senza-esiti
  printf -v "${__v}" '%s' "${__c}"
}

# I campi dal 5 (lettura) al 9 della riga di un file in esiti.tsv, uniti
# da «|». Arguments: $1 lo spazio di lavoro, $2 il file.
campi() {
  awk -F'\t' -v n="$2" '$1 == n { print $5 "|" $6 "|" $7 "|" $8 "|" $9 }' \
    "$1/esiti.tsv" 2>/dev/null
}

# La risposta di grande-haiku-1 letta come atteso, in esiti.tsv.
# Arguments: $1 lo spazio di lavoro, $2 il caso, $3 la risposta, $4 i
# campi attesi.
lettura_caso() {
  local trovati
  risposta "$1" grande-haiku-1.json "$3"
  controlla "$1"
  trovati="$(campi "$1" grande-haiku-1.json)"
  if (( RC == 0 )) && [[ "${trovati}" == "$4" ]]; then
    pass "lettura: $2"
  else
    fail "lettura: $2 (rc=${RC}, «${trovati}», attesi «$4»)"
  fi
}

# Il ramo dell'errore inatteso: main() del controllo di demo/ con un
# controlla() che solleva un'eccezione. Arguments: gli argomenti di main.
inatteso() {
  run python3 -B -I -c 'import importlib.util, sys
spec = importlib.util.spec_from_file_location("controllo", sys.argv[1])
modulo = importlib.util.module_from_spec(spec)
spec.loader.exec_module(modulo)
def guasto(*_):
    raise RuntimeError("guasto finto")
modulo.controlla = guasto
sys.exit(modulo.main(sys.argv[2:]))' "${D01}/demo/controlla_lettura.py" "$@"
}

# Una copia di verifica.sh e di demo/ in cui il controllo è finto: esce
# con il codice dato, o si fa terminare da un segnale.
# Arguments: $1 la variabile da assegnare (la copia), $2 il codice
# d'uscita, oppure «segnale».
albero_finto() {
  local __a __c
  __a="$(mktemp -d "${TMP}/albero.XXXXXX")" || { echo "mktemp" >&2; exit 2; }
  if ! cp -- "${D01}/verifica.sh" "${__a}/" || ! cp -R "${D01}/demo" "${__a}/"
  then
    echo "test_m3_d01: non riesco a copiare l'elemento" >&2
    exit 2
  fi
  __c="${__a}/demo/controlla_lettura.py"
  if [[ "$2" == segnale ]]; then
    printf '%s\n' 'import os, signal' 'os.kill(os.getpid(), signal.SIGTERM)' \
      > "${__c}"
  else
    printf 'import sys\nsys.exit(%d)\n' "$2" > "${__c}"
  fi
  printf -v "$1" '%s' "${__a}"
}

# L'esca in ${TMP}/esca (registra ogni invocazione ed esce 0); il claude
# finto in ${TMP}/finto, un involucro che, con FINTO_CARTELLE, vi
# aggiunge per ogni chiamata al modello la cartella da cui parte e i file
# che contiene (separati da una tabulazione), poi passa a
# claude_finto_m3_demo.py; ${TMP}/senza_python, un PATH con readlink e
# l'esca; ${TMP}/senza_claude, uno con readlink, python3 e grep. Esce 2 se
# nel PATH di prova il claude trovato non è il finto.
prepara_claude() {
  local t
  mkdir -p "${TMP}/esca" "${TMP}/finto" "${TMP}/senza_python" \
    "${TMP}/senza_claude" || exit 2
  # shellcheck disable=SC2016  # il corpo è dell'esca
  printf '%s\n' '#!/bin/bash' \
    'printf "invocazione %s\n" "$*" >> "${ESCA_LOG}"' \
    > "${TMP}/esca/claude" || exit 2
  cp -- "${FINTO_PY}" "${TMP}/finto/claude_finto.py" || exit 2
  # shellcheck disable=SC2016  # il corpo è dell'involucro
  printf '%s\n' '#!/bin/bash' \
    'if [[ -n "${FINTO_CARTELLE:-}" && "${1:-}" != --version ]]; then' \
    '  elenco="$(ls -A | tr "\n" " ")"' \
    '  printf "%s\t%s\n" "${PWD##*/}" "${elenco}" >> "${FINTO_CARTELLE}"' \
    'fi' \
    'exec python3 "${0%/*}/claude_finto.py" "$@"' \
    > "${TMP}/finto/claude" || exit 2
  chmod 755 "${TMP}/esca/claude" "${TMP}/finto/claude" || exit 2
  ln -s "${TMP}/esca/claude" "${TMP}/senza_python/claude" || exit 2
  ln -s "$(command -v readlink)" "${TMP}/senza_python/readlink" || exit 2
  for t in readlink python3 grep; do
    ln -s "$(command -v "${t}")" "${TMP}/senza_claude/${t}" || exit 2
  done
  t="$(PATH="${TMP}/finto:${PATH}" command -v claude)"
  if [[ "${t}" != "${TMP}/finto/claude" ]]; then
    echo "test_m3_d01: nel PATH di prova claude è ${t}, non il finto" >&2
    exit 2
  fi
}

# live.sh con l'esca davanti nel PATH (o con un PATH dato); il registro
# delle invocazioni riparte vuoto. Arguments: $1 lo spazio di lavoro, $2
# facoltativo il PATH.
esca() {
  : > "${TMP}/esca.log"
  run env PATH="${2:-${TMP}/esca:${PATH}}" HANDSON_NO_PAUSE=1 \
    ESCA_LOG="${TMP}/esca.log" "${D01}/_docente/live.sh" "$1"
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

# live.sh con il claude finto davanti nel PATH e ANTHROPIC_API_KEY
# impostata (live.sh la deve togliere); il registro riparte vuoto.
# Arguments: $1 lo spazio di lavoro, poi le variabili NOME=valore.
finto() {
  local w="$1"
  shift
  : > "${TMP}/finto.log"
  : > "${TMP}/finto.cartelle"
  run env PATH="${TMP}/finto:${PATH}" HANDSON_NO_PAUSE=1 \
    ANTHROPIC_API_KEY=valore-finto FINTO_LOG="${TMP}/finto.log" \
    FINTO_CARTELLE="${TMP}/finto.cartelle" "$@" \
    "${D01}/_docente/live.sh" "${w}"
}

# Le cartelle da cui sono partite le chiamate di live.sh e del blocco del
# README: dodici per parte, le stesse, e ognuna con la sua immagine e
# .claude/ soltanto. Arguments: $1 il registro di live.sh, $2 quello del
# README.
cartelle() {
  run python3 -B -I - "$1" "$2" <<'PY'
import sys
SOLE = {"grande": [".claude", "allarmi.png"],
        "piccola": [".claude", "allarmi-piccola.png"]}

def righe(p):
    return [r.rstrip("\n").split("\t") for r in open(p, encoding="utf-8")
            if r.strip()]
live, readme = righe(sys.argv[1]), righe(sys.argv[2])
problemi = []
if len(live) != 12 or live != readme:
    problemi.append("live.sh %d, README %d, le stesse: %s"
                    % (len(live), len(readme), live == readme))
for cartella, *file in live + readme:
    if SOLE.get(cartella) != sorted(" ".join(file).split()):
        problemi.append("%s: %s" % (cartella, " ".join(file)))
print("; ".join(problemi) or "ogni chiamata dalla cartella della sua immagine")
PY
  expect "live e README: ogni chiamata dalla cartella con la sua immagine" 0 \
    "ogni chiamata dalla cartella della sua immagine"
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

# Il blocco di codice del passo 3 del README, senza il rientro, in un
# file. Arguments: $1 il file. Returns: 0; 1 se il blocco non c'è.
blocco_readme() {
  python3 -B -I - "${D01}/README.md" "$1" <<'PY'
import re, sys
readme, uscita = sys.argv[1:3]
dentro, blocco = False, []
for riga in open(readme, encoding="utf-8").read().splitlines():
    if re.match(r"\d+\. ", riga) or riga.startswith("## "):
        dentro = riga.startswith("3. ")
        continue
    if dentro and riga.startswith(" " * 7):
        blocco.append(riga[7:])
if not any("claude -p" in r for r in blocco):
    sys.exit(1)
with open(uscita, "w", encoding="utf-8") as fh:
    fh.write("\n".join(blocco) + "\n")
PY
}

# --- I dati della demo ----------------------------------------------------

# allarmi.html contro progetti/rete e verita.json.
t_dati() {
  run python3 -B -I - "${D01}/demo" "${RADICE}/progetti/rete" <<'PY'
import csv, json, sys
from html.parser import HTMLParser
demo, rete = sys.argv[1:3]

class Tabella(HTMLParser):
    def __init__(self):
        super().__init__()
        self.righe, self.cella, self.dentro = [], None, False
    def handle_starttag(self, tag, attrs):
        if tag == "tbody":
            self.dentro = True
        elif tag == "tr" and self.dentro:
            self.righe.append([])
        elif tag == "td" and self.dentro:
            self.cella = ""
    def handle_endtag(self, tag):
        if tag == "td" and self.cella is not None:
            self.righe[-1].append(" ".join(self.cella.split()))
            self.cella = None
        elif tag == "tbody":
            self.dentro = False
    def handle_data(self, data):
        if self.cella is not None:
            self.cella += data

t = Tabella()
t.feed(open(demo + "/allarmi.html", encoding="utf-8").read())
righe = t.righe
critici = [r for r in righe if r[2] == "critico"]
print("righe %d, critici %d" % (len(righe), len(critici)))
verita = json.load(open(demo + "/verita.json", encoding="utf-8"))
if verita == {"critici": len(critici),
              "apparati": [r[1] for r in critici]}:
    print("verita coerente")
allarmi = list(csv.DictReader(open(rete + "/allarmi.csv", encoding="utf-8")))
ammesse = {"CRITICAL": {"critico"}, "WARNING": {"maggiore", "minore"}}
def trovata(r):
    for a in allarmi:
        quando = "%s/%s %s" % (a["timestamp"][8:10], a["timestamp"][5:7],
                               a["timestamp"][11:16])
        if (quando, a["apparato"]) == (r[0], r[1]) \
                and a["stato"] == "PROBLEM" \
                and r[2] in ammesse.get(a["gravita"], set()):
            return True
    return False
if righe and all(len(r) == 4 and trovata(r) for r in righe):
    print("allarmi della settimana")
inventario = {r["apparato"] for r in csv.DictReader(
    open(rete + "/inventario.csv", encoding="utf-8"))}
if righe and all(r[1] in inventario for r in righe):
    print("apparati dell'inventario")
PY
  expect "dati: dieci allarmi, tre critici" 0 "righe 10, critici 3"
  expect "dati: verita.json dice gli stessi critici" 0 "verita coerente"
  expect "dati: ogni allarme è della settimana di progetti/rete" 0 \
    "allarmi della settimana"
  expect "dati: ogni apparato è nell'inventario" 0 "apparati dell'inventario"
}

# Le due immagini: PNG delle dimensioni giuste; la grande sotto i 256 KB,
# il limite di Read per un file intero.
t_immagini() {
  local f nome lato_x lato_y
  for f in "allarmi.png 1600 1000" "allarmi-piccola.png 160 100"; do
    read -r nome lato_x lato_y <<< "${f}"
    run python3 -B -I - "${D01}/demo/${nome}" <<'PY'
import struct, sys
testa = open(sys.argv[1], "rb").read(24)
assert testa[:8] == b"\x89PNG\r\n\x1a\n" and testa[12:16] == b"IHDR"
print("%d×%d" % struct.unpack(">II", testa[16:24]))
PY
    expect "immagini: ${nome} è un PNG di ${lato_x}×${lato_y}" 0 \
      "${lato_x}×${lato_y}"
  done
  if (( $(wc -c < "${D01}/demo/allarmi.png") < 262144 )); then
    pass "immagini: allarmi.png sotto i 256 KB"
  else
    fail "immagini: allarmi.png pesa $(wc -c < "${D01}/demo/allarmi.png") byte"
  fi
}

# prompt.txt: le due righe, «non leggibile», IMMAGINE una volta.
t_prompt() {
  local p n
  p="$(cat "${D01}/demo/prompt.txt")"
  n="$(grep -o IMMAGINE <<< "${p}" | wc -l)"
  if (( n == 1 )); then
    pass "prompt: IMMAGINE una volta"
  else
    fail "prompt: IMMAGINE ${n} volte"
  fi
  if [[ "${p}" == *"critici: "* && "${p}" == *"apparati: "* \
      && "${p}" == *"non leggibile"* ]]; then
    pass "prompt: le due righe, oppure «non leggibile»"
  else
    fail "prompt: «${p}»"
  fi
}

# .claude/settings.json: le regole prudenti del repository, più le
# quattro di Read.
t_impostazioni() {
  run python3 -B -I - "${D01}/demo/.claude/settings.json" \
    "${RADICE}/.claude/settings.json" <<'PY'
import json, sys
elemento = json.load(open(sys.argv[1], encoding="utf-8"))["permissions"]
radice = json.load(open(sys.argv[2], encoding="utf-8"))["permissions"]
attese = set(radice["deny"]) | {
    "Read(./allarmi.html)", "Read(./verita.json)", "Read(./esiti.tsv)",
    "Read(./risposte/**)"}
print("regole giuste" if set(elemento["deny"]) == attese
      and set(elemento) == {"deny"} else "regole: %s" % elemento)
PY
  expect "impostazioni: le regole del repository più le quattro di Read" 0 \
    "regole giuste"
}

# prepara_esercizio.sh porta demo/ (con .claude/) nello spazio di lavoro, e
# lì verifica.sh esce 1: il punto di partenza chiede le chiamate.
t_prepara() {
  local r="${TMP}/radice"
  run "${RADICE}/tools/prepara_esercizio.sh" M3-D01 --radice "${r}"
  expect "prepara: lo spazio di lavoro nasce" 0 "Spazio di lavoro pronto"
  if cmp -s "${D01}/demo/.claude/settings.json" \
      "${r}/M3-D01/.claude/settings.json" \
      && [[ -f "${r}/M3-D01/allarmi-piccola.png" \
        && ! -e "${r}/M3-D01/soluzione" && ! -e "${r}/M3-D01/_docente" ]]
  then
    pass "prepara: le impostazioni dell'elemento e le immagini, niente altro"
  else
    fail "prepara: lo spazio di lavoro non è demo/"
  fi
  run "${RADICE}/tools/verifica.sh" M3-D01 --radice "${r}"
  expect "prepara: sul punto di partenza la verifica esce 1" 1 "${PARTENZA}"
}

# --- controlla_lettura.py -------------------------------------------------

# Le risposte complete: l'uscita, esiti.tsv, i dati.
t_complete() {
  local w intestazione
  intestazione="file	modello	immagine	esecuzione	lettura	critici	apparati"
  intestazione+="	critici_giusti	apparati_giusti"
  ws w
  complete "${w}"
  controlla "${w}"
  expect "controlla: risposte complete, uscita 0" 0 "Scritto esiti.tsv."
  expect "controlla: la lettura giusta della grande" 0 \
    "haiku, grande, 1: critici 3 (giusto); apparati ${APPARATI} (giusti)"
  expect "controlla: il rifiuto della piccola" 0 \
    "sonnet, piccola, 3: non leggibile (un rifiuto: nessun valore letto)"
  expect_absent "controlla: senza la frase finale, che è della verifica" \
    "Fatto:"
  if [[ "$(head -n 1 "${w}/esiti.tsv")" == "${intestazione}" ]]; then
    pass "controlla: l'intestazione di esiti.tsv"
  else
    fail "controlla: intestazione «$(head -n 1 "${w}/esiti.tsv")»"
  fi
  if (( $(wc -l < "${w}/esiti.tsv") == 13 )); then
    pass "controlla: dodici righe e l'intestazione"
  else
    fail "controlla: $(wc -l < "${w}/esiti.tsv") righe in esiti.tsv"
  fi
  if [[ "$(campi "${w}" piccola-sonnet-2.json)" \
      == "non leggibile|${NA}|${NA}|${NA}|${NA}" ]]; then
    pass "controlla: la riga di esiti.tsv di un rifiuto"
  else
    fail "controlla: riga «$(campi "${w}" piccola-sonnet-2.json)»"
  fi
}

# Le letture: le due righe in molte forme, i valori sbagliati, i rifiuti.
t_letture() {
  local w giusti="valori|3|${APPARATI}|sì|sì"
  ws w
  complete "${w}"
  lettura_caso "${w}" "elenco puntato e grassetto" \
    $'- **Critici:** 3\n- **Apparati:** '"${APPARATI}" "${giusti}"
  lettura_caso "${w}" "maiuscole, altro ordine, «e»" \
    $'CRITICI: 3\nAPPARATI: SBC-TRENTO-01, ptp-cles-01 e olt-pergine-01' \
    "valori|3|sbc-trento-01, ptp-cles-01, olt-pergine-01|sì|sì"
  lettura_caso "${w}" "un numero in lettere" \
    $'critici: tre\napparati: '"${APPARATI}" "${giusti}"
  lettura_caso "${w}" "note fra parentesi e un punto in fondo" \
    $'critici: 3\napparati: olt-pergine-01 (08/09 10:12), '"${APPARATI#*, }." \
    "${giusti}"
  lettura_caso "${w}" "codice di Markdown e righe in più" \
    $'Ecco:\n\ncritici: `3`\napparati: `olt-pergine-01`, `ptp-cles-01`,'\
$' `sbc-trento-01`' "${giusti}"
  lettura_caso "${w}" "valori sbagliati" \
    $'critici: 2\napparati: olt-pergine-01; ptp-cles-01' \
    "valori|2|olt-pergine-01, ptp-cles-01|no|no"
  lettura_caso "${w}" "un apparato in più" \
    $'critici: 3\napparati: '"${APPARATI}, bng-trento-01" \
    "valori|3|${APPARATI}, bng-trento-01|sì|no"
  lettura_caso "${w}" "una riga sola" 'critici: 3' "valori|3|${NA}|sì|${NA}"
  lettura_caso "${w}" "«nessuno»" $'critici: 0\napparati: nessuno' \
    "valori|0|nessuno|no|no"
  lettura_caso "${w}" "«Non leggibile.»" 'Non leggibile.' \
    "non leggibile|${NA}|${NA}|${NA}|${NA}"
  lettura_caso "${w}" "«non leggibile» come valore" \
    $'critici: non leggibile\napparati: non leggibile' \
    "non leggibile|${NA}|${NA}|${NA}|${NA}"
  lettura_caso "${w}" "senza le due righe" \
    'Vedo una tabella con righe colorate.' \
    "senza le due righe|${NA}|${NA}|${NA}|${NA}"
  expect "lettura: senza le due righe, il testo stampato" 0 \
    "haiku, grande, 1: senza le due righe: «Vedo una tabella con righe"
}

# I verdetti: le due raccomandazioni sulle coppie, il «può» sulla piccola.
t_verdetti() {
  local w
  con w
  expect "verdetti: la grande giusta e la piccola rifiutata conferma" 0 \
    "${S_LEGG} (haiku, coppia 1): confermata"
  expect "verdetti: il riepilogo delle coppie" 0 \
    "${S_LEGG} (sonnet): confermata 3 su 3"
  expect "verdetti: un rifiuto non conferma il «può»" 0 \
    "${S_PICC} (haiku, piccola 2): ${NONCONF} (la risposta dice «non leggibile»"
  expect "verdetti: il riepilogo del «può», 0 su 3" 0 \
    "${S_PICC} (haiku): confermata 0 su 3"
  con w piccola-haiku-1.json $'critici: 1\napparati: bng-trento-01'
  expect "verdetti: un valore sbagliato sulla piccola conferma il «può»" 0 \
    "${S_PICC} (haiku, piccola 1): confermata"
  expect "verdetti: e la coppia resta confermata" 0 \
    "${S_LEGG} (haiku, coppia 1): confermata"
  expect "verdetti: il riepilogo del «può», 1 su 3" 0 \
    "${S_PICC} (haiku): confermata 1 su 3"
  con w piccola-sonnet-2.json "${GIUSTA}"
  expect "verdetti: lette giuste tutte e due, non distinguibile" 0 \
    "${S_LEGG} (sonnet, coppia 2): non distinguibile (lette giuste tutte"
  expect "verdetti: la piccola letta giusta non conferma il «può»" 0 \
    "${S_PICC} (sonnet, piccola 2): ${NONCONF} (nessun valore sbagliato)"
  con w grande-haiku-3.json 'critici: 2'
  expect "verdetti: nessuna delle due giusta, non distinguibile" 0 \
    "${S_LEGG} (haiku, coppia 3): non distinguibile (nessuna delle due"
  con w grande-sonnet-1.json 'non leggibile' piccola-sonnet-1.json "${GIUSTA}"
  expect "verdetti: giusta la piccola e non la grande, non confermata" 0 \
    "${S_LEGG} (sonnet, coppia 1): ${NONCONF} (letta giusta la piccola"
  con w piccola-haiku-3.json 'Una tabella piccola.'
  expect "verdetti: senza le due righe il «può» non è confermato" 0 \
    "${S_PICC} (haiku, piccola 3): ${NONCONF} (la risposta non ha le due"
  con w piccola-sonnet-3.json 'critici: 3'
  expect "verdetti: una riga sola e giusta sulla piccola, coppia" 0 \
    "${S_LEGG} (sonnet, coppia 3): confermata"
  expect "verdetti: una riga sola e giusta sulla piccola, «può»" 0 \
    "${S_PICC} (sonnet, piccola 3): ${NONCONF} (nessun valore sbagliato)"
}

# Le risposte rovinate: uscita 1, il motivo, gli altri verdetti, nessun
# traceback.
t_rovinate() {
  local w
  ws w
  complete "${w}"
  rm "${w}/risposte/piccola-sonnet-3.json"
  controlla "${w}"
  expect "rovinate: una risposta che manca, uscita 1" 1 \
    "manca risposte/piccola-sonnet-3.json: rifate quella chiamata"
  expect "rovinate: il messaggio «Non ancora»" 1 "Non ancora:"
  expect_absent "rovinate: senza la piccola, nessun verdetto per lei" \
    "(sonnet, piccola 3)"
  expect "rovinate: i riepiloghi contano le coppie che ci sono" 1 \
    "${S_LEGG} (sonnet): confermata 2 su 2"
  if (( $(wc -l < "${w}/esiti.tsv") == 12 )); then
    pass "rovinate: esiti.tsv con le undici risposte che ci sono"
  else
    fail "rovinate: $(wc -l < "${w}/esiti.tsv") righe in esiti.tsv"
  fi
  ws w
  complete "${w}"
  : > "${w}/risposte/grande-haiku-2.json"
  controlla "${w}"
  expect "rovinate: una risposta vuota" 1 "grande-haiku-2.json è vuoto"
  printf '{rotto' > "${w}/risposte/grande-haiku-2.json"
  controlla "${w}"
  expect "rovinate: una risposta che non è JSON" 1 \
    "grande-haiku-2.json non è il JSON di claude -p"
  printf '[1, 2]' > "${w}/risposte/grande-haiku-2.json"
  controlla "${w}"
  expect "rovinate: un elenco JSON" 1 \
    "grande-haiku-2.json non è il JSON di claude -p"
  risposta "${w}" grande-haiku-2.json "${GIUSTA}" is_error=true
  controlla "${w}"
  expect "rovinate: is_error" 1 "claude ha restituito un errore"
  risposta "${w}" grande-haiku-2.json "${GIUSTA}" \
    'subtype="error_max_turns"'
  controlla "${w}"
  expect "rovinate: un subtype d'errore" 1 "claude ha restituito un errore"
  risposta "${w}" grande-haiku-2.json "${GIUSTA}" result=-
  controlla "${w}"
  expect "rovinate: senza result" 1 "manca la risposta («result»)"
  risposta "${w}" grande-haiku-2.json '  '
  controlla "${w}"
  expect "rovinate: un result vuoto" 1 "manca la risposta («result»)"
  expect_absent "rovinate: mai un traceback" "Traceback"
}

# risposte/ che manca, --senza-esiti, le precondizioni.
t_precondizioni() {
  local w
  ws w
  printf 'vecchio\n' > "${w}/esiti.tsv"
  controlla "${w}"
  expect "partenza: risposte/ che manca, uscita 1" 1 "${PARTENZA}"
  if [[ ! -e "${w}/esiti.tsv" ]]; then
    pass "partenza: il vecchio esiti.tsv è tolto"
  else
    fail "partenza: il vecchio esiti.tsv resta"
  fi
  printf 'vecchio\n' > "${w}/esiti.tsv"
  controlla "${w}" --senza-esiti
  expect "partenza: con --senza-esiti, uscita 1" 1 "${PARTENZA}"
  if [[ "$(cat "${w}/esiti.tsv")" == vecchio ]]; then
    pass "partenza: --senza-esiti non toglie esiti.tsv"
  else
    fail "partenza: --senza-esiti ha toccato esiti.tsv"
  fi
  rm -f "${w}/esiti.tsv"
  complete "${w}"
  controlla "${w}" --senza-esiti
  if (( RC == 0 )) && [[ ! -e "${w}/esiti.tsv" ]]; then
    pass "--senza-esiti: uscita 0 e nessun esiti.tsv"
  else
    fail "--senza-esiti: rc=${RC}, esiti.tsv $(ls "${w}")"
  fi
  run python3 -B -I "${D01}/demo/controlla_lettura.py" --tutto "${w}"
  expect "precondizione: un'opzione sconosciuta, uscita 2" 2 \
    "opzione sconosciuta: --tutto"
  run python3 -B -I "${D01}/demo/controlla_lettura.py" "${w}" "${w}"
  expect "precondizione: due spazi di lavoro" 2 \
    "uno spazio di lavoro per volta"
  run python3 -B -I "${D01}/demo/controlla_lettura.py" "${TMP}/assente"
  expect "precondizione: spazio di lavoro assente" 2 \
    "spazio di lavoro assente"
  printf 'vecchio\n' > "${w}/esiti.tsv"
  mv "${w}/verita.json" "${w}/verita.tolta"
  controlla "${w}"
  expect "precondizione: verita.json che manca" 2 "manca verita.json"
  if [[ ! -e "${w}/esiti.tsv" ]]; then
    pass "precondizione: il vecchio esiti.tsv è tolto"
  else
    fail "precondizione: il vecchio esiti.tsv resta"
  fi
  printf '{"critici": 3,' > "${w}/verita.json"
  controlla "${w}"
  expect "precondizione: verita.json che non è JSON" 2 \
    "verita.json non si legge"
  printf '{"critici": "3", "apparati": []}' > "${w}/verita.json"
  controlla "${w}"
  expect "precondizione: verita.json con un critici che non è un intero" 2 \
    "attesi «critici», un intero"
  printf '{"critici": 3, "apparati": ["", "x"]}' > "${w}/verita.json"
  controlla "${w}"
  expect "precondizione: verita.json con un nome vuoto" 2 \
    "un elenco di nomi"
  mv "${w}/verita.tolta" "${w}/verita.json"
  mkdir "${w}/esiti.tsv"
  controlla "${w}"
  expect "precondizione: esiti.tsv che non si scrive" 2 \
    "esiti.tsv non si scrive"
  rmdir "${w}/esiti.tsv"
  inatteso --senza-esiti "${w}"
  expect "precondizione: un errore inatteso, uscita 2" 2 \
    "errore inatteso (RuntimeError: guasto finto)"
  expect_absent "precondizione: l'errore inatteso senza traceback" \
    "Traceback"
  if (( EUID == 0 )); then
    skip "precondizione: una risposta che non si legge (da root si legge)"
    return 0
  fi
  chmod 000 "${w}/risposte/grande-sonnet-1.json"
  controlla "${w}"
  expect "precondizione: una risposta che non si legge" 2 \
    "risposte/grande-sonnet-1.json non si legge"
  chmod 644 "${w}/risposte/grande-sonnet-1.json"
}

# --- verifica.sh ----------------------------------------------------------

t_verifica() {
  local w a n
  run "${D01}/verifica.sh"
  expect "verifica: senza spazio di lavoro, uscita 2" 2 \
    "spazio di lavoro assente"
  ws w
  run "${D01}/verifica.sh" "${w}"
  expect "verifica: il punto di partenza, uscita 1" 1 "${PARTENZA}"
  complete "${w}"
  run "${D01}/verifica.sh" "${w}"
  expect "verifica: risposte complete, uscita 0" 0 "${FINE}"
  if [[ "${OUT##*$'\n'}" == "${FINE}" ]]; then
    pass "verifica: la frase finale è l'ultima riga"
  else
    fail "verifica: l'ultima riga è «${OUT##*$'\n'}»"
  fi
  n="$(grep -c ': confermata 3 su 3$' <<< "${OUT}")"
  if (( n == 2 )); then
    pass "verifica: le coppie confermate 3 su 3 per due modelli"
  else
    fail "verifica: ${n} righe «confermata 3 su 3», attese 2"
  fi
  if [[ ! -e "${w}/esiti.tsv" ]]; then
    pass "verifica: non scrive esiti.tsv"
  else
    fail "verifica: ha scritto esiti.tsv"
  fi
  rm "${w}/risposte/grande-haiku-1.json"
  printf 'file\nfinto\n' > "${w}/esiti.tsv"
  run "${D01}/verifica.sh" "${w}"
  expect "verifica: una risposta che manca, con un esiti.tsv falso" 1 \
    "manca risposte/grande-haiku-1.json"
  expect_absent "verifica: una risposta che manca, nessuna frase finale" \
    "Fatto:"
  run env PATH="${TMP}/senza_python" "${D01}/verifica.sh" "${w}"
  expect "verifica: python3 che manca, uscita 2" 2 "manca python3"
  albero_finto a 3
  run "${a}/verifica.sh" "${w}"
  expect "verifica: un controllo che esce con 3, uscita 2" 2 \
    "controlla_lettura.py è uscito con 3"
  albero_finto a segnale
  run "${a}/verifica.sh" "${w}"
  expect "verifica: un controllo terminato da un segnale, uscita 2" 2 \
    "controlla_lettura.py è uscito con 143"
}

# --- _docente/live.sh -----------------------------------------------------

# Le precondizioni escono 2 prima di ogni invocazione di claude.
t_live_precondizioni() {
  local w f
  precondizione "live: spazio di lavoro assente" "spazio di lavoro assente" \
    "${TMP}/assente"
  for f in prompt.txt verita.json allarmi.png allarmi-piccola.png \
      controlla_lettura.py .claude/settings.json; do
    ws w
    rm "${w}/${f}"
    precondizione "live: ${f} che manca" "file assente o illeggibile: ${f}" \
      "${w}"
  done
  ws w
  printf 'Leggi la tabella e rispondi.\n' > "${w}/prompt.txt"
  precondizione "live: prompt.txt senza IMMAGINE" \
    "prompt.txt non nomina l'immagine" "${w}"
  ws w
  precondizione "live: python3 che manca" "manca lo strumento: python3" \
    "${w}" "${TMP}/senza_python"
  ws w
  esca "${w}" "${TMP}/senza_claude"
  expect "live: claude che manca" 2 "manca lo strumento: claude"
}

# Il claude finto: le dodici chiamate, i testi e le opzioni del README.
t_live_finto() {
  local w w2 r
  ws w
  finto "${w}"
  expect "live: le risposte finte, uscita 0" 0 "VERIFICA OK"
  expect "live: i dati e i verdetti si vedono anche quando passa" 0 "${FINE}"
  expect "live: il verdetto delle coppie" 0 \
    "${S_LEGG} (haiku): confermata 3 su 3"
  r="$(grep -cF 'haiku, grande, 1: critici 3' <<< "${OUT}")"
  if (( r == 1 )); then
    pass "live: i dati si vedono una volta sola"
  else
    fail "live: i dati di haiku, grande, 1 si vedono ${r} volte"
  fi
  r="$(chiamate "${TMP}/finto.log")"
  if [[ "${r}" == "12 0" ]]; then
    pass "live: dodici chiamate, nessuna con ANTHROPIC_API_KEY"
  else
    fail "live: chiamate e chiavi «${r}», attese «12 0»"
  fi
  r="$(command find "${w}/risposte" -name '*.json' | wc -l)"
  if (( r == 12 )) && (( $(wc -l < "${w}/esiti.tsv") == 13 )); then
    pass "live: dodici file in risposte/ e dodici righe in esiti.tsv"
  else
    fail "live: ${r} file in risposte/"
  fi
  cp "${TMP}/finto.log" "${TMP}/live.log"
  cp "${TMP}/finto.cartelle" "${TMP}/live.cartelle"
  ws w2
  if ! blocco_readme "${TMP}/passo3.sh"; then
    fail "README: il blocco del passo 3 non c'è"
    return 0
  fi
  : > "${TMP}/readme.log"
  : > "${TMP}/readme.cartelle"
  ( cd "${w2}" && PATH="${TMP}/finto:${PATH}" \
      FINTO_LOG="${TMP}/readme.log" \
      FINTO_CARTELLE="${TMP}/readme.cartelle" bash "${TMP}/passo3.sh" )
  cartelle "${TMP}/live.cartelle" "${TMP}/readme.cartelle"
  run python3 -B -I - "${w}" "${w2}" "${TMP}/live.log" "${TMP}/readme.log" \
    <<'PY'
import json, os, sys
ws, ws2, log_live, log_readme = sys.argv[1:5]
VALORE = {"--model", "--effort", "--tools", "--allowedTools",
          "--output-format", "--setting-sources", "--permission-mode",
          "--permission-prompts"}

def chiamate(log):
    righe = [json.loads(r)["argv"] for r in open(log, encoding="utf-8")]
    return [c for c in righe if c[:1] != ["--version"]]

def analizza(argv):
    """(il prompt, le opzioni): il prompt dopo «--», o l'operando."""
    opzioni, prompt, i = {}, None, 0
    while i < len(argv):
        a = argv[i]
        if a == "--":
            prompt = argv[i + 1]
            break
        if a in VALORE:
            opzioni[a] = argv[i + 1]
            i += 2
        elif a.startswith("-"):
            opzioni[a] = True
            i += 1
        else:
            prompt = a
            i += 1
    return prompt, opzioni

domanda = open(os.path.join(ws, "prompt.txt"), encoding="utf-8").read()
domanda = domanda.rstrip("\n")
attese = []
for m in ("haiku", "sonnet"):
    for n in (1, 2, 3):
        for f in ("allarmi.png", "allarmi-piccola.png"):
            attese.append((m, domanda.replace("IMMAGINE", f)))
live, readme = chiamate(log_live), chiamate(log_readme)
problemi = []
if len(live) != 12 or len(readme) != 12:
    problemi.append("chiamate: live.sh %d, README %d" % (len(live),
                                                        len(readme)))
fisse = (("--tools", "Read"), ("--allowedTools", "Read"),
         ("--effort", "low"), ("--output-format", "json"),
         ("--setting-sources", "project,local"),
         ("--permission-mode", "dontAsk"), ("--permission-prompts", "none"))
for i, (cl, cr, (m, testo)) in enumerate(zip(live, readme, attese)):
    pl, ol = analizza(cl)
    pr, orr = analizza(cr)
    if pl != testo or pr != testo:
        problemi.append("chiamata %d: il prompt" % (i + 1))
    if ol.get("--model") != m:
        problemi.append("chiamata %d: il modello" % (i + 1))
    for chiave, valore in list(orr.items()) + list(fisse):
        if ol.get(chiave) != valore:
            problemi.append("chiamata %d: %s" % (i + 1, chiave))
    for chiave in ("-p", "--strict-mcp-config", "--no-session-persistence"):
        if ol.get(chiave) is not True:
            problemi.append("chiamata %d: %s" % (i + 1, chiave))
if sorted(os.listdir(os.path.join(ws, "risposte"))) \
        != sorted(os.listdir(os.path.join(ws2, "risposte"))):
    problemi.append("i file di risposte/ sono diversi")
print("; ".join(problemi) or "stesse chiamate")
PY
  expect "live e README: stessi testi, stesse opzioni, stessi file" 0 \
    "stesse chiamate"
}

# Il claude finto: la prima chiamata fallita, risposte finte che cambiano
# i verdetti, una modalità di permesso vietata.
t_live_esiti() {
  local w r
  ws w
  finto "${w}" FINTO_ESITO=ko
  r="$(chiamate "${TMP}/finto.log")"
  if (( RC == 1 )) && [[ "${r}" == "1 0" ]] \
      && grep -qF 'VERIFICA KO' <<< "${OUT}"; then
    pass "live: si ferma alla prima chiamata fallita"
  else
    fail "live: rc=${RC} dopo le chiamate «${r}»: ${OUT:0:300}"
  fi
  ws w
  finto "${w}" FINTO_PICCOLA=$'critici: 1\napparati: bng-trento-01'
  expect "live: un errore finto sulla piccola, uscita 0" 0 \
    "${S_PICC} (sonnet): confermata 3 su 3"
  ws w
  finto "${w}" FINTO_GRANDE='Vedo una tabella.'
  expect "live: la grande finta senza le due righe, uscita 0" 0 \
    "${S_LEGG} (haiku, coppia 1): non distinguibile (nessuna delle due"
  ws w
  finto "${w}" HANDSON_PERMISSION_MODE=bypassPermissions
  r="$(chiamate "${TMP}/finto.log")"
  if (( RC == 2 )) && [[ "${r}" == "0 0" ]] \
      && grep -qF 'modalità di permesso non ammessa' <<< "${OUT}"; then
    pass "live: bypassPermissions rifiutata prima di chiamare il modello"
  else
    fail "live: bypassPermissions, rc=${RC}, chiamate «${r}»"
  fi
}

# --- _docente/genera_immagini.sh ------------------------------------------

# Il browser finto in ${TMP}/browser/chromium: registra gli argomenti in
# FINTO_BROWSER_LOG e scrive un PNG bianco delle dimensioni di
# --window-size nel file di --screenshot. FINTO_BROWSER=ko esce 1;
# =niente non scrive; =storto sbaglia di un pixel la piccola.
prepara_browser() {
  mkdir -p "${TMP}/browser" "${TMP}/senza_browser" || exit 2
  cat > "${TMP}/browser/chromium" <<'PY' || exit 2
#!/usr/bin/env python3
import json, os, struct, sys, zlib
argv = sys.argv[1:]
with open(os.environ["FINTO_BROWSER_LOG"], "a", encoding="utf-8") as fh:
    fh.write(json.dumps(argv) + "\n")
modo = os.environ.get("FINTO_BROWSER", "ok")
if modo == "ko":
    sys.exit(1)
lati = next(a.split("=", 1)[1] for a in argv if a.startswith("--window-size="))
uscita = next(a.split("=", 1)[1] for a in argv if a.startswith("--screenshot="))
larga, alta = (int(x) for x in lati.split(","))
if modo == "niente":
    sys.exit(0)
if modo == "storto" and larga == 160:
    larga += 1
def pezzo(tipo, dati):
    return (struct.pack(">I", len(dati)) + tipo + dati
            + struct.pack(">I", zlib.crc32(tipo + dati) & 0xFFFFFFFF))
grezzi = b"".join(b"\x00" + b"\xff\xff\xff" * larga for _ in range(alta))
with open(uscita, "wb") as fh:
    fh.write(b"\x89PNG\r\n\x1a\n"
             + pezzo(b"IHDR", struct.pack(">IIBBBBB", larga, alta, 8, 2, 0,
                                          0, 0))
             + pezzo(b"IDAT", zlib.compress(grezzi)) + pezzo(b"IEND", b""))
PY
  chmod 755 "${TMP}/browser/chromium" || exit 2
  ln -s "$(command -v readlink)" "${TMP}/senza_browser/readlink" || exit 2
  ln -s "$(command -v python3)" "${TMP}/senza_browser/python3" || exit 2
}

# genera_immagini.sh con il browser finto; RC e OUT come run.
# Arguments: $1 la cartella d'uscita, poi le variabili NOME=valore.
genera_finto() {
  local uscita="$1"
  shift
  : > "${TMP}/browser.log"
  run env PN_BROWSER="${TMP}/browser/chromium" \
    FINTO_BROWSER_LOG="${TMP}/browser.log" "$@" \
    "${D01}/_docente/genera_immagini.sh" "${uscita}"
}

# Le dimensioni dei due PNG di una cartella, «LxA LxA», o «assenti».
# Arguments: $1 la cartella.
dimensioni() {
  python3 -B -I - "$1" <<'PY'
import os, struct, sys
fuori = []
for nome in ("allarmi.png", "allarmi-piccola.png"):
    try:
        testa = open(os.path.join(sys.argv[1], nome), "rb").read(24)
        fuori.append("%dx%d" % struct.unpack(">II", testa[16:24]))
    except (OSError, struct.error):
        fuori.append("assente")
print(" ".join(fuori))
PY
}

t_genera() {
  local u a b
  u="$(mktemp -d "${TMP}/uscita.XXXXXX")" || exit 2
  run "${D01}/_docente/genera_immagini.sh" "${u}" "${u}"
  expect "genera: due argomenti, uscita 2" 2 "uso:"
  run "${D01}/_docente/genera_immagini.sh" "${TMP}/assente"
  expect "genera: la cartella d'uscita che manca, uscita 2" 2 \
    "cartella d'uscita assente"
  run env PN_BROWSER="${TMP}/assente/chromium" \
    "${D01}/_docente/genera_immagini.sh" "${u}"
  expect "genera: PN_BROWSER che non c'è, uscita 2" 2 "PN_BROWSER non c'è"
  run env -u PN_BROWSER PATH="${TMP}/senza_browser" \
    "${D01}/_docente/genera_immagini.sh" "${u}"
  expect "genera: nessun browser nel PATH, uscita 2" 2 "nessun browser"
  a="$(mktemp -d "${TMP}/albero.XXXXXX")" || exit 2
  mkdir -p "${a}/_docente" "${a}/demo" || exit 2
  cp -- "${D01}/_docente/genera_immagini.sh" "${a}/_docente/" || exit 2
  run env PN_BROWSER="${TMP}/browser/chromium" \
    FINTO_BROWSER_LOG="${TMP}/browser.log" "${a}/_docente/genera_immagini.sh"
  expect "genera: la pagina che manca, uscita 2" 2 "manca la pagina"
  genera_finto "${u}"
  expect "genera: con il browser finto, uscita 0" 0 \
    "allarmi-piccola.png: 160×100"
  if [[ "$(dimensioni "${u}")" == "1600x1000 160x100" ]]; then
    pass "genera: le due immagini nella cartella d'uscita"
  else
    fail "genera: le immagini sono «$(dimensioni "${u}")»"
  fi
  run python3 -B -I - "${TMP}/browser.log" <<'PY'
import json, sys
chiamate = [json.loads(r) for r in open(sys.argv[1], encoding="utf-8")]
lati = [next(a for a in c if a.startswith("--window-size=")) for c in chiamate]
pagine = [c[-1].rsplit("/", 1)[-1] for c in chiamate]
print(lati, pagine)
PY
  expect "genera: la grande dalla pagina, la piccola dalla cornice" 0 \
    "['--window-size=1600,1000', '--window-size=160,100'] \
['allarmi.html', 'cornice.html']"
  b="$(mktemp -d "${TMP}/uscita.XXXXXX")" || exit 2
  printf 'vecchia\n' > "${b}/allarmi.png"
  genera_finto "${b}" FINTO_BROWSER=ko
  expect "genera: il browser che fallisce, uscita 2" 2 \
    "il browser è uscito con un errore"
  genera_finto "${b}" FINTO_BROWSER=niente
  expect "genera: il browser che non scrive, uscita 1" 1 \
    "il browser non ha scritto un PNG"
  genera_finto "${b}" FINTO_BROWSER=storto
  expect "genera: una dimensione sbagliata, uscita 1" 1 \
    "allarmi-piccola.png: 161×100, attese 160×100"
  if [[ "$(cat "${b}/allarmi.png")" == vecchia \
      && ! -e "${b}/allarmi-piccola.png" ]]; then
    pass "genera: senza le due immagini giuste, le vecchie restano"
  else
    fail "genera: la cartella d'uscita è cambiata"
  fi
}

# Il browser vero, se c'è (non da root: Chromium vuole la sandbox), con
# TMPDIR nella base dei temporanei della suite: con un TMPDIR dentro
# ~/.claude Chromium si interrompe.
t_genera_vero() {
  local b u
  for b in chromium chromium-browser google-chrome google-chrome-stable; do
    if command -v "${b}" > /dev/null 2>&1; then
      break
    fi
    b=''
  done
  if [[ -z "${b}" ]] || (( EUID == 0 )); then
    skip "genera: con il browser vero (nessun browser, o root)"
    return 0
  fi
  u="$(mktemp -d "${TMP}/vero.XXXXXX")" || exit 2
  run env TMPDIR="${HANDSON_TEMP_BASE}" "${D01}/_docente/genera_immagini.sh" \
    "${u}"
  if (( RC == 0 )) && [[ "$(dimensioni "${u}")" == "1600x1000 160x100" ]]
  then
    pass "genera: con il browser vero (${b}), 1600×1000 e 160×100"
  else
    fail "genera: con il browser vero, rc=${RC}: ${OUT:0:300}"
  fi
}

# Il README: i passi in Claude Code e in claude.ai, la versione minima, il
# consiglio per WSL 2, la variabile p nel recupero di una chiamata, il
# blocco del passo 3 con la riga del controllo (quello della slide) in 19
# righe × 66 colonne, mai «smentita».
t_readme() {
  run python3 -B -I - "${D01}/README.md" <<'PY'
import re, sys
testo = open(sys.argv[1], encoding="utf-8").read()
righe = testo.split("\n")
titolo = "## Passi in Claude Code (e in claude.ai)" in righe
print("titolo: %s" % ("sì" if titolo else "no"))
print("versione: %s" % ("sì" if "2.1.293 o successiva" in testo else "no"))
wsl = "/mnt/c/Users/<utente>/Downloads/" in testo
print("wsl: %s" % ("sì" if wsl else "no"))
storto = " ".join(testo.split("## Se qualcosa va storto")[-1].split())
print("recupero: %s" % ("sì" if 'p="$(cat prompt.txt)"' in storto else "no"))
dentro, blocco = False, []
for riga in righe:
    if re.match(r"\d+\. ", riga) or riga.startswith("## "):
        dentro = riga.startswith("3. ")
        continue
    if dentro and riga.startswith(" " * 7):
        blocco.append(riga[7:])
blocco.append("python3 controlla_lettura.py")
misura = (len(blocco), max(len(r) for r in blocco))
print("blocco: %s %d×%d" % ("sì" if misura[0] <= 19 and misura[1] <= 66
                            else "no", misura[0], misura[1]))
print("parola vietata: %s" % ("sì" if "smentit" in testo else "no"))
PY
  expect "README: i passi in Claude Code e in claude.ai" 0 "titolo: sì"
  expect "README: Claude Code 2.1.293 o successiva" 0 "versione: sì"
  expect "README: il consiglio per WSL 2" 0 "wsl: sì"
  expect "README: la variabile p nel recupero di una chiamata" 0 \
    "recupero: sì"
  expect "README: il blocco della slide in 19 righe × 66 colonne" 0 \
    "blocco: sì"
  expect "README: mai «smentita»" 0 "parola vietata: no"
}

# Gli script di M3-D01 e questo file, con shellcheck -x.
t_shellcheck() {
  local f
  for f in "${D01}/verifica.sh" "${D01}/_docente/live.sh" \
      "${D01}/_docente/genera_immagini.sh" "${SELF}"; do
    if shellcheck -x "${f}" > /dev/null 2>&1; then
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
      || { echo "test_m3_d01: manca ${t}" >&2; exit 2; }
  done
  [[ -d "${D01}" && -f "${FINTO_PY}" ]] \
    || { echo "test_m3_d01: manca ${D01} o ${FINTO_PY}" >&2; exit 2; }
  handson::init_temp_base
  TMP="$(mktemp -d "${HANDSON_TEMP_BASE}/test_m3_d01.XXXXXX")" || exit 2
  trap 'chmod -R u+rwX "${TMP}" 2>/dev/null; rm -rf "${TMP}"' EXIT
  prepara_claude
  prepara_browser
  t_dati
  t_immagini
  t_prompt
  t_impostazioni
  t_prepara
  t_complete
  t_letture
  t_verdetti
  t_rovinate
  t_precondizioni
  t_verifica
  t_readme
  t_live_precondizioni
  t_live_finto
  t_live_esiti
  t_genera
  t_genera_vero
  t_shellcheck
  OUT="${TUTTO}"
  expect_absent "in nessuna uscita «smentita»" "smentita"
  echo "PASS=${PASS} FAIL=${FAIL} SKIP=${SKIP}"
  if (( PASS + FAIL + SKIP != CASES )); then
    echo "test_m3_d01: girati $((PASS + FAIL + SKIP)) casi, attesi" \
      "${CASES}" >&2
    exit 2
  fi
  (( FAIL == 0 )) || exit 1
}

main "$@"
