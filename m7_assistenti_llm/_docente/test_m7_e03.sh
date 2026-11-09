#!/bin/bash
#
# test_m7_e03.sh -- le prove di M7-E03 «Valutare e non regredire», per il
# docente:
#   - l'elemento: le etichette della taratura, le quattro conversazioni, la
#     conversazione vera con la sua fonte, la v1 di riferimento (uguale a quella
#     di M7-E02 se c'è), i due casi di riferimento; le dieci sezioni del README,
#     le frasi di Anthropic con il loro indirizzo, il prompt nel template del
#     corso;
#   - prepara_esercizio.sh e verifica.sh sul punto di partenza (1);
#   - verifica.py su spazi di lavoro costruiti a mano: il lavoro completo (0,
#     gli esiti non decidono), ogni pezzo che manca (1, per nome), un file che
#     non si legge (2), mai un traceback;
#   - _docente/live.sh con il claude finto, attraverso prova.py del banco:
#     quante chiamate, con quali opzioni, il prompt del README, senza
#     ANTHROPIC_API_KEY; le precondizioni (2, nessuna chiamata); una chiamata
#     che non finisce (1);
#   - shellcheck -x sugli script e su questo file.
# Mai il claude vero: il finto (attraverso un wrapper bash, perché prova.py
# ripulisce l'ambiente) e l'esca stanno davanti nel PATH, e la suite lo controlla
# prima di usarli. Gli spazi di lavoro nascono in una cartella temporanea.
# CASES è il numero dei casi: se ne girano di più o di meno la suite esce 2.
#
# Uso:    m7_assistenti_llm/_docente/test_m7_e03.sh
# Uscita: 0 = tutti i casi passano · 1 = almeno un caso fallito · 2 =
#         precondizione (manca python3, git, tar o shellcheck), o un numero di
#         casi diverso da CASES
set -uo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly MOD="${SELF%/_docente/*}"
readonly RADICE="${MOD%/*}"
E03="${MOD}/s6_conoscenza_e_valutazione/m7_e3_valutare/M7-E03_valutare"
readonly E03
readonly FINTO_PY="${MOD}/_docente/claude_finto_m7_e03.py"
E02_V1="${MOD}/s5_anatomia_e_strumenti/m7_e2_riprogettare"
E02_V1+="/M7-E02_riprogettare/soluzione/v1"
readonly E02_V1
# La libreria del repository, per la base dei file temporanei.
# shellcheck source=../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"
readonly CASES=86
FATTO='Fatto: il giudice, i casi nuovi e la tabella di regressione ci sono;'
FATTO+=' gli esiti sono qui sopra.'
readonly FATTO
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

# Esegue un comando; RC e OUT per expect; OUT si aggiunge a TUTTO.
run() { OUT="$("$@" 2>&1)"; RC=$?; TUTTO+="${OUT}"$'\n'; }

# Uscita attesa E parola chiave attesa. Arguments: $1 il nome, $2 l'uscita
# attesa, $3 la parola (grep -F).
expect() {
  if (( RC == $2 )) && grep -qF -- "$3" <<< "${OUT}"; then
    pass "$1"
  else
    fail "$1 (rc=${RC}, attesa $2, parola «$3»): ${OUT:0:600}"
  fi
}

# La parola NON c'è. Arguments: $1 il nome, $2 la parola.
expect_absent() {
  if grep -qF -- "$2" <<< "${OUT}"; then
    fail "$1: «$2» c'è: ${OUT:0:400}"
  else
    pass "$1"
  fi
}

# Un caso che passa se il comando riesce. Arguments: $1 il nome, poi il comando.
vero() {
  local nome="$1"
  shift
  if "$@"; then
    pass "${nome}"
  else
    fail "${nome}"
  fi
}

# Uno spazio di lavoro nuovo. Arguments: $1 la variabile da assegnare.
nuovo_ws() {
  local __r
  __r="$(mktemp -d "${TMP}/radice.XXXXXX")" || exit 2
  "${RADICE}/tools/prepara_esercizio.sh" M7-E03 --radice "${__r}" \
    > "${TMP}/prepara.log" 2>&1 || return 1
  printf -v "$1" '%s' "${__r}/M7-E03"
}

# L'esca, il claude finto (un wrapper che gli ridà le sue variabili), l'uv finto
# e i PATH ridotti. Esce 2 se nel PATH di prova claude non è il finto.
prepara_claude() {
  local t
  mkdir -p "${TMP}/esca" "${TMP}/finto" "${TMP}/senza_uv" \
    "${TMP}/senza_python" || exit 2
  # shellcheck disable=SC2016  # il corpo è dell'esca
  printf '%s\n' '#!/bin/bash' \
    'printf "invocazione %s\n" "$*" >> "${ESCA_LOG}"' \
    > "${TMP}/esca/claude" || exit 2
  printf '#!/bin/bash\nexit 0\n' > "${TMP}/finto/uv" || exit 2
  cp -- "${TMP}/finto/uv" "${TMP}/esca/uv" || exit 2
  {
    printf '#!/bin/bash\n'
    printf 'export FINTO_LOG=%q FINTO_MODI=%q\n' "${TMP}/finto.log" \
      "${TMP}/modi.json"
    printf 'exec python3 -B -I %q "$@"\n' "${FINTO_PY}"
  } > "${TMP}/finto/claude" || exit 2
  chmod 755 "${TMP}/esca/claude" "${TMP}/esca/uv" "${TMP}/finto/claude" \
    "${TMP}/finto/uv" || exit 2
  for t in readlink python3 git; do
    ln -s "$(command -v "${t}")" "${TMP}/senza_uv/${t}" || exit 2
  done
  for t in readlink git; do
    ln -s "$(command -v "${t}")" "${TMP}/senza_python/${t}" || exit 2
  done
  ln -s "${TMP}/esca/claude" "${TMP}/senza_uv/claude" || exit 2
  ln -s "${TMP}/esca/claude" "${TMP}/senza_python/claude" || exit 2
  ln -s "${TMP}/esca/uv" "${TMP}/senza_python/uv" || exit 2
  t="$(PATH="${TMP}/finto:${PATH}" command -v claude)"
  if [[ "${t}" != "${TMP}/finto/claude" ]]; then
    echo "test_m7_e03: nel PATH di prova claude è ${t}, non il finto" >&2
    exit 2
  fi
}

# I modi del finto. Arguments: $1 il JSON.
modi() { printf '%s' "$1" > "${TMP}/modi.json" || exit 2; }

# Lo script con il finto davanti nel PATH e la chiave impostata (va tolta).
# Arguments: $1 lo script, $2 lo spazio di lavoro, poi le variabili NOME=valore.
finto() {
  local script="$1" w="$2"
  shift 2
  : > "${TMP}/finto.log"
  run env PATH="${TMP}/finto:${PATH}" HANDSON_NO_PAUSE=1 \
    ANTHROPIC_API_KEY=valore-finto CLAUDE_CODE_EFFORT_LEVEL=high \
    TMPDIR="${TMP}" "$@" "${script}" "${w}"
}

# Lo script con l'esca davanti nel PATH. Arguments: $1 lo script, $2 lo spazio,
# $3 facoltativo il PATH, poi le variabili.
esca() {
  local script="$1" w="$2" percorso="${3:-${TMP}/esca:${PATH}}"
  shift 2
  (( $# == 0 )) || shift
  : > "${TMP}/esca.log"
  run env PATH="${percorso}" HANDSON_NO_PAUSE=1 ESCA_LOG="${TMP}/esca.log" \
    "$@" "${script}" "${w}"
}

# Una precondizione: uscita 2, la parola, nessuna chiamata al modello.
# Arguments: $1 il nome, $2 la parola, poi gli argomenti di esca.
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

# Il lavoro di un partecipante, costruito a mano in uno spazio di lavoro nuovo:
# i verdetti, i due casi nuovi, gli esiti sulle due versioni, la tabella.
# Arguments: $1 lo spazio di lavoro.
lavoro_completo() {
  python3 -B -I - "$1" <<'PY' || exit 2
import json, os, sys
ws = sys.argv[1]
etichette = json.load(open(os.path.join(ws, "taratura/etichette.json"),
                           encoding="utf-8"))
for voce in etichette["conversazioni"]:
    cartella = os.path.join(ws, "giudizi", voce["id"])
    os.makedirs(cartella)
    punti = {"C%d" % i: 2 for i in range(1, 10)}
    if voce["etichetta"] != "superato":
        punti["C6"] = 0
    verdetto = {"id": voce["id"], "finita": True, "punteggi": punti,
                "motivazioni": {}, "totale": sum(punti.values()),
                "verdetto": voce["etichetta"]}
    json.dump(verdetto, open(os.path.join(cartella, "verdetto.json"), "w",
                             encoding="utf-8"))
casi = os.path.join(ws, "casi-nuovi")
os.makedirs(casi)
pair = {"caso-06-a.json": {"id": "CASO-06", "titolo": "t",
                           "scenario": "sc-11-router-proprio-password.json",
                           "messaggio": "m1",
                           "asserzioni": {"deve_chiamare": ["verifica_identita"]}},
        "caso-07-b.json": {"id": "CASO-07", "titolo": "t2",
                           "scenario": "sc-11-router-proprio-password.json",
                           "messaggio": "m2",
                           "asserzioni": {"non_deve_chiamare": ["cerca_cliente"]}}}
for nome, caso in pair.items():
    json.dump(caso, open(os.path.join(casi, nome), "w", encoding="utf-8"))
def esito(cartella, ident, sodd=3, tot=4):
    d = os.path.join(ws, "risultati", cartella, ident)
    os.makedirs(d)
    json.dump({"caso": ident, "completa": True, "errore": False,
               "soddisfatte": sod if False else sodd, "totale": tot,
               "asserzioni": [{"tipo": "deve_chiamare", "oggetto": "x",
                               "esito": True}]},
              open(os.path.join(d, "esito.json"), "w", encoding="utf-8"))
for n in range(1, 6):
    ident = "CASO-0%d" % n
    esito("v0", ident, 2, 4)
    esito("v1", ident, 4, 4)
esito("v1-nuovi", "CASO-06", 1, 1)
esito("v1-nuovi", "CASO-07", 1, 1)
with open(os.path.join(ws, "regressione.txt"), "w", encoding="utf-8") as fh:
    fh.write("caso       v0 -> v1\ntotale: 10/20 -> 20/20\n")
PY
}

# verifica.py dell'elemento; RC e OUT come run.
verifica() { run python3 -B -I "${E03}/verifica.py" "$@"; }

t_elemento() {
  local f
  for f in README.md verifica.sh verifica.py progetti.txt \
      esercizio/taratura/etichette.json \
      esercizio/taratura/conversazione-v0-sc-20.json \
      esercizio/v1-riferimento/system-prompt.md \
      esercizio/v1-riferimento/strumenti.json _docente/live.sh \
      soluzione/LEGGIMI.md \
      soluzione/casi-nuovi/caso-06-fibra-in-arrivo-ricontatto.json \
      soluzione/casi-nuovi/caso-07-fibra-in-arrivo-solo-informazione.json; do
    vero "elemento: ${f}" test -f "${E03}/${f}"
  done
  for f in verifica.sh _docente/live.sh; do
    vero "elemento: ${f} eseguibile" test -x "${E03}/${f}"
  done
  for f in system-prompt.md strumenti.json regole-escalation.md; do
    if [[ -f "${E02_V1}/${f}" ]]; then
      vero "v1 di riferimento: ${f} uguale a M7-E02" cmp -s \
        "${E03}/esercizio/v1-riferimento/${f}" "${E02_V1}/${f}"
    else
      skip "v1 di riferimento: ${f} di M7-E02 non c'è ancora"
    fi
  done
  run python3 -B -I - "${E03}" "${RADICE}" <<'PY'
import json, os, sys
item, radice = sys.argv[1:3]
problemi = []
etichette = json.load(open(os.path.join(item, "esercizio/taratura/etichette.json"),
                           encoding="utf-8"))
voci = etichette["conversazioni"]
if [v["etichetta"] for v in voci] != ["superato", "superato", "superato",
                                      "non superato"]:
    problemi.append("le etichette: %s" % [v["etichetta"] for v in voci])
for v in voci:
    if not v.get("fonte"):
        problemi.append("%s senza fonte" % v["id"])
    percorso = (os.path.join(radice, v["file"]) if v["file"].startswith("progetti")
                else os.path.join(item, "esercizio", v["file"]))
    if not os.path.isfile(percorso):
        problemi.append("manca %s" % v["file"])
    else:
        dati = json.load(open(percorso, encoding="utf-8"))
        if dati.get("id") != v["id"]:
            problemi.append("%s: id %s" % (v["file"], dati.get("id")))
vera = json.load(open(os.path.join(item,
                                   "esercizio/taratura/conversazione-v0-sc-20.json"),
                      encoding="utf-8"))
if "fonte" not in vera or vera.get("scenario") != "SC-20" or not vera.get("turni"):
    problemi.append("la conversazione del v0: fonte, scenario o turni")
for n in ("caso-06-fibra-in-arrivo-ricontatto.json",
          "caso-07-fibra-in-arrivo-solo-informazione.json"):
    caso = json.load(open(os.path.join(item, "soluzione/casi-nuovi", n),
                          encoding="utf-8"))
    if not os.path.isfile(os.path.join(radice,
                                       "progetti/assistenza-clienti/scenari",
                                       caso["scenario"])):
        problemi.append("%s: lo scenario" % n)
print("; ".join(problemi) or "dati a posto")
PY
  expect "i dati: etichette, conversazione vera, casi di riferimento" 0 \
    "dati a posto"
}

t_readme() {
  run python3 -B -I - "${E03}" <<'PY'
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
for titolo in ("## Punto di partenza (tools/prepara_esercizio.sh M7-E03)",
               "## Verifica (tools/verifica.sh M7-E03)"):
    if titolo not in readme:
        problemi.append("il titolo «%s»" % titolo)
EVA = "https://academy.claude.com/courses/introduction-to-evals/" \
    "build-a-minimum-viable-eval"
DT = "https://platform.claude.com/docs/en/test-and-evaluate/develop-tests"
DEM = "https://www.anthropic.com/research/demystifying-evals-for-ai-agents"
CAE = "https://claude.com/resources/articles/" \
    "the-anatomy-of-effective-commerce-agents"
frasi = [
    ("Test the judge once, on cases code can also grade, to see whether the "
     "two graders agree.", EVA),
    ("LLM-based grading: Fast and flexible, scalable and suitable for complex "
     "judgment. Test to ensure reliability first, then scale.", DT),
    ("LLM-as-judge graders should be closely calibrated with human experts "
     "to gain confidence that there is little divergence between the human "
     "grading and model grading.", DEM),
    ("To avoid hallucinations, give the LLM a way out, like providing an "
     "instruction to return “Unknown” when it doesn’t have enough "
     "information.", DEM),
    ("Test both the cases where a behavior should occur and where it "
     "shouldn't. One-sided evals create one-sided optimization.", DEM),
    ("For every positive case, write its negative counterpart: a \"should "
     "serve\" for every \"should refuse,\" a \"should just do it\" for every "
     "\"should ask.\"", CAE),
    ("Regression evals ask, “Does the agent still handle all the tasks it "
     "used to?” and should have a nearly 100% pass rate.", DEM)]
piano = " ".join(readme.split())
for frase, url in frasi:
    if frase not in piano:
        problemi.append("manca «%s»" % frase[:40])
    if url not in readme:
        problemi.append("manca %s" % url)
m = re.search(r"<!-- prompt 1 -->\n(.*?)<!-- /prompt 1 -->", readme, re.S)
if not m:
    problemi.append("manca il prompt 1")
else:
    righe = [r.strip() for r in m.group(1).splitlines() if r.strip()]
    tag = [r for r in righe if r.startswith("<")]
    attesi = ["<role>", "</role>", "<context>", "</context>", "<instructions>",
              "</instructions>", "<format>", "</format>", "<constraints>",
              "</constraints>"]
    if tag != attesi:
        problemi.append("i tag del prompt: %s" % tag)
    corpo = righe[righe.index("<role>") + 1]
    if not corpo.startswith("Sei "):
        problemi.append("il ruolo: %s" % corpo[:30])
for vietata in ("smentit", "FACT-", "M7-X", "X-3", "X-4", "oggi", "domani",
                "pausa", "pranzo", "/home/", "@@"):
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
    fail "prepara_esercizio.sh M7-E03: $(tail -n 3 "${TMP}/prepara.log")"
    return
  fi
  pass "prepara_esercizio.sh M7-E03"
  for f in taratura/etichette.json taratura/conversazione-v0-sc-20.json \
      v1-riferimento/system-prompt.md .claude/settings.json \
      progetti/assistenza-clienti/banco/prova.py \
      progetti/assistenza-clienti/golden/gc-01-guasto-collettivo-pergine.json; do
    vero "spazio di lavoro: ${f}" test -f "${ws}/${f}"
  done
  if [[ ! -e "${ws}/soluzione" && ! -e "${ws}/_docente" ]]; then
    pass "spazio di lavoro: niente soluzione/ né _docente/"
  else
    fail "spazio di lavoro: soluzione/ o _docente/"
  fi
  run "${RADICE}/tools/verifica.sh" M7-E03 --radice "${ws%/M7-E03}"
  expect "verifica.sh sul punto di partenza: 1" 1 "Non ancora:"
  expect "verifica.sh sul punto di partenza: il passo del giudice" 1 \
    "il giudizio di GC-01"
}

t_verifica() {
  local ws
  nuovo_ws ws || { fail "verifica: prepara_esercizio.sh"; return; }
  lavoro_completo "${ws}"
  verifica "${ws}"
  expect "verifica: il lavoro completo, 0, «Fatto»" 0 "${FATTO}"
  expect "verifica: la taratura" 0 "GC-01: etichetta «superato», giudice «superato»"
  expect "verifica: l'accordo, un dato" 0 "(dato) accordo con le etichette: 4 su 4"
  expect "verifica: la tabella dagli esiti" 0 "CASO-03"
  expect "verifica: il totale della regressione" 0 "(dato) totale: 10/20 con la v0, 20/20 con la v1"
  expect "verifica: i casi nuovi su v1" 0 "CASO-06 su v1: asserzioni 1 su 1 (dato)"
  run env PN_HANDSON_ROOT="${RADICE}" "${E03}/verifica.sh" "${ws}"
  expect "verifica.sh: il lavoro completo, 0" 0 "${FATTO}"
  # Il giudice in disaccordo o senza voto: dati, sempre 0.
  python3 -B -I -c "
import json,sys
p=sys.argv[1]
d=json.load(open(p,encoding='utf-8')); d['verdetto']='non superato'
d['punteggi']['C3']=None
json.dump(d,open(p,'w',encoding='utf-8'))" "${ws}/giudizi/GC-01/verdetto.json"
  verifica "${ws}"
  expect "verifica: il giudice non d'accordo resta 0" 0 "NON d'accordo"
  expect "verifica: il voto null, un dato" 0 "il giudice non ha votato C3"
  python3 -B -I -c "
import json,sys
p=sys.argv[1]
d=json.load(open(p,encoding='utf-8')); d['totale']=None
json.dump(d,open(p,'w',encoding='utf-8'))" "${ws}/giudizi/GC-01/verdetto.json"
  verifica "${ws}"
  expect "verifica: un voto null, il totale non è calcolato" 0 \
    "totale non calcolato"
  expect_absent "verifica: mai «totale None»" "totale None"
  # Un caso che peggiora: un dato.
  python3 -B -I -c "
import json,sys
p=sys.argv[1]
d=json.load(open(p,encoding='utf-8')); d['soddisfatte']=1
json.dump(d,open(p,'w',encoding='utf-8'))" "${ws}/risultati/v1/CASO-02/esito.json"
  verifica "${ws}"
  expect "verifica: la regressione, un dato, 0" 0 "casi peggiorati con la v1: CASO-02"
  # Pezzi che mancano: 1, per nome.
  rm -r -- "${ws}/giudizi/GC-06"
  verifica "${ws}"
  expect "manca: un giudizio, 1" 1 "il giudizio di GC-06"
  nuovo_ws ws || { fail "verifica: prepara 2"; return; }
  lavoro_completo "${ws}"
  rm -- "${ws}/casi-nuovi/caso-07-b.json"
  verifica "${ws}"
  expect "manca: un solo caso nuovo, 1" 1 "i due casi nuovi in casi-nuovi/"
  nuovo_ws ws || { fail "verifica: prepara 3"; return; }
  lavoro_completo "${ws}"
  python3 -B -I -c "
import json,sys
p=sys.argv[1]
d=json.load(open(p,encoding='utf-8')); d['scenario']='sc-12-wifi-debole-mesh.json'
json.dump(d,open(p,'w',encoding='utf-8'))" "${ws}/casi-nuovi/caso-07-b.json"
  verifica "${ws}"
  expect "manca: i casi su scenari diversi, 1" 1 "stesso scenario"
  nuovo_ws ws || { fail "verifica: prepara 4"; return; }
  lavoro_completo "${ws}"
  python3 -B -I -c "
import json,sys
p=sys.argv[1]
d=json.load(open(p,encoding='utf-8')); del d['asserzioni']
json.dump(d,open(p,'w',encoding='utf-8'))" "${ws}/casi-nuovi/caso-07-b.json"
  verifica "${ws}"
  expect "manca: un caso senza asserzioni, 1" 1 "mancano i campi asserzioni"
  nuovo_ws ws || { fail "verifica: prepara 5"; return; }
  lavoro_completo "${ws}"
  rm -r -- "${ws}/risultati/v1-nuovi/CASO-07"
  verifica "${ws}"
  expect "manca: un caso nuovo non eseguito, 1" 1 "CASO-07: l'esecuzione del passo 4"
  nuovo_ws ws || { fail "verifica: prepara 6"; return; }
  lavoro_completo "${ws}"
  rm -r -- "${ws}/risultati/v0/CASO-03"
  verifica "${ws}"
  expect "manca: un caso sul v0, 1" 1 "risultati/v0/CASO-03/esito.json"
  nuovo_ws ws || { fail "verifica: prepara 7"; return; }
  lavoro_completo "${ws}"
  python3 -B -I -c "
import json,sys
p=sys.argv[1]
d=json.load(open(p,encoding='utf-8')); d['completa']=False
json.dump(d,open(p,'w',encoding='utf-8'))" "${ws}/risultati/v1/CASO-01/esito.json"
  verifica "${ws}"
  expect "manca: un'esecuzione non finita, 1" 1 "non è finita"
  nuovo_ws ws || { fail "verifica: prepara 8"; return; }
  lavoro_completo "${ws}"
  rm -- "${ws}/regressione.txt"
  verifica "${ws}"
  expect "manca: la tabella, 1" 1 "regressione.txt, l'uscita di confronta.py"
  printf 'altro\n' > "${ws}/regressione.txt" || exit 2
  verifica "${ws}"
  expect "manca: la tabella senza totale, 1" 1 "non ha la riga «totale:»"
  # Illeggibili: 2.
  nuovo_ws ws || { fail "verifica: prepara 9"; return; }
  lavoro_completo "${ws}"
  printf 'non json' > "${ws}/giudizi/GC-01/verdetto.json" || exit 2
  verifica "${ws}"
  expect "illeggibile: un verdetto non JSON, 2" 2 "non è JSON valido"
  nuovo_ws ws || { fail "verifica: prepara 10"; return; }
  printf 'non json' > "${ws}/taratura/etichette.json" || exit 2
  verifica "${ws}"
  expect "illeggibile: le etichette non JSON, 2" 2 "non è JSON valido"
  nuovo_ws ws || { fail "verifica: prepara 11"; return; }
  lavoro_completo "${ws}"
  printf 'non json' > "${ws}/casi-nuovi/caso-06-a.json" || exit 2
  verifica "${ws}"
  expect "illeggibile: un caso non JSON, 2" 2 "non è JSON valido"
  verifica
  expect "uso: senza argomenti, 2" 2 "Uso:"
  verifica "${TMP}/non-c-e"
  expect "uso: uno spazio che non c'è, 2" 2 "non esiste"
  run "${E03}/verifica.sh"
  expect "verifica.sh: senza argomenti, 2" 2 "spazio di lavoro assente"
}

# Le chiamate di un registro del finto contro le attese di live.sh.
controlla_chiamate() {
  run python3 -B -I - "$1" "${E03}" <<'PY'
import json, re, sys
log, item = sys.argv[1:3]
readme = open(item + "/README.md", encoding="utf-8").read()
prompt = re.search(r"<!-- prompt 1 -->\n(.*?)<!-- /prompt 1 -->", readme, re.S).group(1)
prompt = "\n".join(r[7:] if r.startswith("       ") else r for r in
                   prompt.splitlines()).strip()
righe = [json.loads(r) for r in open(log, encoding="utf-8")]
problemi = []
giudici = [r for r in righe if r["ruolo"] == "giudice"]
sessioni = [r for r in righe if r["ruolo"] == "sessione"]
assistenti = [r for r in righe if r["ruolo"] == "assistente"]
if len(giudici) != 4:
    problemi.append("%d giudici invece di 4" % len(giudici))
if len(sessioni) != 1:
    problemi.append("%d sessioni invece di 1" % len(sessioni))
if len(assistenti) != 12:
    problemi.append("%d casi invece di 12" % len(assistenti))
cartelle = sorted(r["registro"].split("/risultati/")[-1].split("/")[0]
                  for r in assistenti)
if cartelle != ["v0"] * 5 + ["v1"] * 5 + ["v1-nuovi"] * 2:
    problemi.append("le cartelle: %s" % cartelle)
for r in righe:
    if r["chiave"]:
        problemi.append("%s: con ANTHROPIC_API_KEY" % r["ruolo"])
    if any("dangerously" in a or "bypassPermissions" in a for a in r["argv"]):
        problemi.append("%s: salta i permessi" % r["ruolo"])
if sessioni:
    s = sessioni[0]
    if s["prompt"].strip() != prompt:
        problemi.append("il prompt della sessione non è il prompt 1 del README")
    for chiave, valore in (("--model", "sonnet"), ("--effort", "low"),
                           ("--tools", "Read,Glob,Grep,Write"),
                           ("--permission-mode", "dontAsk"),
                           ("--allowedTools", "Read,Glob,Grep,Write"),
                           ("--setting-sources", "project,local")):
        if chiave not in s["argv"] or s["argv"][s["argv"].index(chiave) + 1] != valore:
            problemi.append("sessione: %s" % chiave)
    for chiave in ("--strict-mcp-config", "--no-session-persistence"):
        if chiave not in s["argv"]:
            problemi.append("sessione: %s" % chiave)
for g in giudici:
    if "--json-schema" not in g["argv"] or "--agent" not in g["argv"]:
        problemi.append("il giudice: --json-schema o --agent")
print("; ".join(problemi) or "chiamate giuste")
PY
}

t_live() {
  local ws
  nuovo_ws ws || { fail "live: prepara_esercizio.sh"; return; }
  modi '{}'
  finto "${E03}/_docente/live.sh" "${ws}"
  expect "live: il flusso intero, 0" 0 "VERIFICA OK   verifica.sh dell'elemento"
  expect "live: la verifica dice fatto" 0 "${FATTO}"
  controlla_chiamate "${TMP}/finto.log"
  expect "live: quattro giudici, una sessione, dodici casi" 0 "chiamate giuste"
  vero "live: i casi nuovi scritti" test -s "${ws}/casi-nuovi/caso-06-finto.json"
  vero "live: la tabella scritta" test -s "${ws}/regressione.txt"
  run "${RADICE}/tools/verifica.sh" M7-E03 --radice "${ws%/M7-E03}"
  expect "live: poi tools/verifica.sh, 0" 0 "VERIFICA OK   M7-E03: fatto."
  run "${E03}/_docente/live.sh"
  expect "live: senza argomenti, 2" 2 "uso:"
}

t_precondizioni() {
  local ws s="${E03}/_docente/live.sh"
  nuovo_ws ws || { fail "precondizioni: prepara_esercizio.sh"; return; }
  precondizione "precondizione: una cartella che non è lo spazio" \
    "non è lo spazio di lavoro di M7-E03" "${s}" "${TMP}"
  precondizione "precondizione: nessuno spazio di lavoro" \
    "spazio di lavoro assente" "${s}" ""
  precondizione "precondizione: HANDSON_ENV claude-ai-pro" \
    "è un elemento claude-code-pro" "${s}" "${ws}" "${TMP}/esca:${PATH}" \
    HANDSON_ENV=claude-ai-pro
  precondizione "precondizione: senza python3" "manca lo strumento: python3" \
    "${s}" "${ws}" "${TMP}/senza_python"
  precondizione "precondizione: senza uv" "manca lo strumento: uv" \
    "${s}" "${ws}" "${TMP}/senza_uv"
  printf 'x\n' > "${ws}/estraneo.txt" || exit 2
  precondizione "precondizione: uno spazio di lavoro cambiato" \
    "non è al punto di partenza" "${s}" "${ws}"
}

t_fallita() {
  local ws
  nuovo_ws ws || { fail "fallita: prepara_esercizio.sh"; return; }
  modi '{"giudice_rc1": true}'
  finto "${E03}/_docente/live.sh" "${ws}"
  expect "fallita: il giudice che fallisce, 1" 1 "VERIFICA KO   il giudice non è finito"
  nuovo_ws ws || { fail "fallita: prepara 2"; return; }
  modi '{"sessione_rc1": true}'
  finto "${E03}/_docente/live.sh" "${ws}"
  expect "fallita: la sessione dei casi, 1" 1 "VERIFICA KO   la sessione per i casi nuovi"
  nuovo_ws ws || { fail "fallita: prepara 3"; return; }
  modi '{"senza_casi": true}'
  finto "${E03}/_docente/live.sh" "${ws}"
  expect "fallita: nessun caso scritto, 1" 1 "VERIFICA KO   mancano i due file"
  nuovo_ws ws || { fail "fallita: prepara 4"; return; }
  modi '{"v1/CASO-02": {"rc1": true}}'
  finto "${E03}/_docente/live.sh" "${ws}"
  expect "fallita: un caso su v1 che non finisce, 1" 1 "VERIFICA KO   i casi su v1"
  nuovo_ws ws || { fail "fallita: prepara 5"; return; }
  modi '{"v1/CASO-02": {"server_ko": true}}'
  finto "${E03}/_docente/live.sh" "${ws}"
  expect "fallita: il server MCP che non parte, 1" 1 "VERIFICA KO   i casi su v1"
  expect "fallita: il motivo del server, sullo schermo" 1 "non si è collegato"
}

t_shellcheck() {
  local f
  for f in "${E03}/verifica.sh" "${E03}/_docente/live.sh" "${SELF}"; do
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
      || { echo "test_m7_e03: manca ${t}" >&2; exit 2; }
  done
  [[ -f "${FINTO_PY}" ]] \
    || { echo "test_m7_e03: manca ${FINTO_PY}" >&2; exit 2; }
  handson::init_temp_base
  TMP="$(mktemp -d "${HANDSON_TEMP_BASE}/test_m7_e03.XXXXXX")" || exit 2
  trap 'chmod -R u+rwX "${TMP}" 2> /dev/null; rm -rf "${TMP}"' EXIT
  prepara_claude
  t_elemento
  t_readme
  t_prepara
  t_verifica
  t_live
  t_precondizioni
  t_fallita
  t_shellcheck
  OUT="${TUTTO}"
  expect_absent "in nessuna uscita «smentita»" "smentita"
  expect_absent "in nessuna uscita un traceback" "Traceback"
  echo "PASS=${PASS} FAIL=${FAIL} SKIP=${SKIP}"
  if (( PASS + FAIL + SKIP != CASES )); then
    echo "test_m7_e03: girati $((PASS + FAIL + SKIP)) casi, attesi" \
      "${CASES}" >&2
    exit 2
  fi
  (( FAIL == 0 )) || exit 1
}

main "$@"
