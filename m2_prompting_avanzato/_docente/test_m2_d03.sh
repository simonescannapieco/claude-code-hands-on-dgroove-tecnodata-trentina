#!/bin/bash
#
# test_m2_d03.sh -- le prove di M2-D03 «Solo JSON, o uno schema», per il
# docente (sta in _docente/, il materiale del docente), senza il claude
# vero:
#   - controlla_json.py su risposte sintetiche scritte qui, ogni esito di
#     ogni affermazione. La 1: confermata; non confermata da un blocco di
#     codice e da ogni regola dello schema (una chiave in più, una che
#     manca, un valore non ammesso, un tipo sbagliato), con l'uscita che
#     resta 0; non distinguibile per una risposta che manca, is_error,
#     senza result, un file che non è JSON o non è un oggetto. La 2:
#     confermata; non confermata (un oggetto fuori dallo schema); non
#     distinguibile (structured_output null, oppure assente con un subtype
#     di errore; il file che manca). La 3: confermata (la riga su STDERR,
#     su STDOUT, con gli a capo di Windows, troncata se lunga); non
#     confermata (uscita 0; una risposta del modello sullo STDOUT); non
#     distinguibile (un altro errore, la riga «uscita: N» che manca o con
#     un numero lunghissimo, uno dei due file che manca, la riga d'errore
#     con «uscita: 0» e nessuna risposta). La 4, una dimostrazione senza
#     verdetto e senza classe di garanzia: lo scambio di tipo_cliente nei
#     due versi e l'etichetta dell'oggetto modificato; nessuna copia senza
#     un oggetto validato. Il telefono contato, anche con i trattini;
#   - i dati rovinati, mai con un traceback: un JSON annidato a dismisura,
#     nel file o nella risposta; byte che non sono UTF-8; le precondizioni
#     (uscita 2): gli argomenti, lo spazio di lavoro, schema.json assente
#     (e un esiti.tsv vecchio tolto), rovinato o non quello della demo, un
#     file che non si legge, esiti.tsv che non si scrive, un errore
#     inatteso; la cartella risposte/ che manca (1, e un esiti.tsv vecchio
#     tolto); --senza-esiti non scrive e non toglie esiti.tsv;
#   - verifica.sh, che fa girare il controllo di demo/ sulle risposte con
#     --senza-esiti e non legge esiti.tsv: spazio di lavoro assente (2),
#     punto di partenza (1), un'esecuzione completa e confermata (0, la
#     frase finale per ultima, nessun esiti.tsv scritto), la 1 non
#     confermata (0), una garanzia non confermata (1), una risposta che
#     manca (1), risposte/ tolta con un esiti.tsv vecchio (1), un esiti.tsv
#     falso che non conta (1), schema.json cambiato (2), una risposta che
#     non si legge (2), python3 che manca (2), un controllo che esce con un
#     codice fuori dal contratto (2);
#   - _docente/live.sh con un claude finto davanti nel PATH, che registra
#     ogni chiamata e i suoi argomenti: le precondizioni escono 2 senza
#     chiamarlo; con le risposte complete esce 0 dopo cinque chiamate, con
#     i testi dei file (lo schema come testo del file) e le opzioni della
#     registrazione del corso; lo STDOUT e la riga d'errore dello schema
#     non valido separati; uno schema non valido accettato esce 1; una
#     chiamata fallita ferma la demo (1); controlla_json.py che non può
#     girare esce 2; ANTHROPIC_API_KEY non arriva a claude;
#   - il README: il passo dello schema non valido e le opzioni di live.sh,
#     le due sottosezioni di «Che cosa osservare»;
#   - shellcheck -x su verifica.sh, live.sh e su questa prova.
# I casi si contano: se ne gira un numero diverso da CASES la prova esce 2
# (un caso saltato o aggiunto senza contarlo); da root i casi dei file che
# non si leggono sono saltati, e contati a parte.
#
# Uso:    m2_prompting_avanzato/_docente/test_m2_d03.sh
# Uscita: 0 = tutte le prove passano · 1 = almeno una fallita · 2 =
#         precondizione (manca python3, shellcheck o un file dell'elemento,
#         il claude finto non è il primo nel PATH, un numero di casi
#         diverso da CASES)
set -uo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly MOD="${SELF%/_docente/*}"
ELEMENTO="${MOD}/s1_progettare_il_prompt/m2_4_tag_e_struttura"
ELEMENTO+='/M2-D03_solo_json_o_schema'
readonly ELEMENTO
readonly LIVE="${ELEMENTO}/_docente/live.sh"
readonly VERIFICA="${ELEMENTO}/verifica.sh"
readonly CASES=122
readonly T=$'\t'
ERRORE='Error: --json-schema is not a valid JSON Schema: data/type must'
ERRORE+=' be equal to one of the allowed values'
readonly ERRORE
OGGETTO='{"tipo_cliente": "azienda", "servizio": "centralino",'
OGGETTO+=' "problema": "centralino fermo", "urgenza": "alta",'
OGGETTO+=' "azione_richiesta": "richiamare al +39 000 000 0103"}'
readonly OGGETTO
FATTO='Fatto: ogni affermazione è stata messa alla prova;'
FATTO+=' gli esiti sono qui sopra.'
readonly FATTO
readonly A_PAROLE='Se lo chiedete, il JSON arriva valido e conforme'
readonly CON_SCHEMA='Con --json-schema, structured_output è validato'
NON_VALIDO='Uno schema non valido fa uscire claude con un errore,'
NON_VALIDO+=" all'avvio"
readonly NON_VALIDO
readonly FORMA='Lo schema controlla la forma, non il contenuto'
readonly DIMOSTRA="${FORMA} (una dimostrazione, nessun verdetto):"
readonly PARTENZA='Manca la cartella risposte/: eseguite i passi del README.'
readonly NON_CONF='non confermata in questa esecuzione'
readonly GARANTISCE='La documentazione garantisce che'
SMENTITA_2="${GARANTISCE} con --json-schema, structured_output è validato:"
SMENTITA_2+=' in questa esecuzione no.'
readonly SMENTITA_2
SMENTITA_3="${GARANTISCE} uno schema non valido fa uscire claude con un"
SMENTITA_3+=" errore, all'avvio: in questa esecuzione no."
readonly SMENTITA_3
TMP=''
PASS=0
FAIL=0
SKIP=0
RC=0
OUT=''

# --- Gli aiutanti -----------------------------------------------------------

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }
skip() { echo "  SKIP: $1"; SKIP=$((SKIP + 1)); }

# Esegue un comando; RC e OUT (STDOUT e STDERR insieme) per expect.
run() { OUT="$("$@" 2>&1)"; RC=$?; }

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

# Un caso deciso da una condizione appena valutata.
# Arguments: $1 il nome, $2 l'uscita della condizione, $3 che cosa dire.
check() {
  if (( $2 == 0 )); then
    pass "$1"
  else
    fail "$1: $3"
  fi
}

# Un nuovo spazio di lavoro: il punto di partenza dell'elemento e la
# cartella risposte/. Arguments: $1 la variabile da assegnare.
ws() {
  local __w
  __w="$(mktemp -d "${TMP}/ws.XXXXXX")" \
    || { echo "test_m2_d03: mktemp" >&2; exit 2; }
  if ! cp -R "${ELEMENTO}/demo/." "${__w}/" \
      || ! mkdir -p "${__w}/risposte"; then
    echo "test_m2_d03: non riesco a preparare ${__w}" >&2
    exit 2
  fi
  printf -v "$1" '%s' "${__w}"
}

# Scrive il JSON sintetico di una chiamata claude -p.
# Arguments: $1 il file; $2 «testo», con $3 il result; oppure $2 «schema»,
# con $3 lo structured_output in JSON («null» un null, «-» nessun campo),
# $4 il subtype e $5 is_error («true» o «false»).
risposta() {
  python3 -B -I - "$@" <<'PY'
import json
import sys
percorso, tipo = sys.argv[1], sys.argv[2]
doc = {"type": "result", "subtype": "success", "is_error": False,
       "usage": {"input_tokens": 3, "output_tokens": 5}}
if tipo == "testo":
    doc["result"] = sys.argv[3]
else:
    if sys.argv[3] != "-":
        doc["structured_output"] = json.loads(sys.argv[3])
    doc["result"] = ""
    doc["subtype"] = sys.argv[4]
    doc["is_error"] = sys.argv[5] == "true"
with open(percorso, "w", encoding="utf-8") as fh:
    json.dump(doc, fh, ensure_ascii=False)
PY
}

# L'oggetto della demo con una regola dello schema infranta, in JSON.
# Arguments: $1 la regola: in_piu, manca, valore, tipo.
variante() {
  python3 -B -I - "$1" "${OGGETTO}" <<'PY'
import json
import sys
regola, oggetto = sys.argv[1], json.loads(sys.argv[2])
if regola == "in_piu":
    oggetto["nota"] = "una chiave in più"
elif regola == "manca":
    del oggetto["azione_richiesta"]
elif regola == "valore":
    oggetto["urgenza"] = "altissima"
else:
    oggetto["servizio"] = 42
print(json.dumps(oggetto, ensure_ascii=False))
PY
}

# Rovina il file di una risposta.
# Arguments: $1 il file, $2 come: manca, errore (is_error), senza_result,
# non_json, non_oggetto.
rovina() {
  case "$2" in
    manca) rm -- "$1" ;;
    errore)
      printf '{"type": "result", "is_error": true, "result": "x"}\n' > "$1" ;;
    senza_result) printf '{"type": "result", "is_error": false}\n' > "$1" ;;
    non_json) printf 'non è JSON\n' > "$1" ;;
    non_oggetto) printf '[1, 2]\n' > "$1" ;;
  esac
}

# Le risposte di un'esecuzione in cui ogni affermazione è confermata.
# Arguments: $1 lo spazio di lavoro; $2 (facoltativo) l'oggetto, in JSON.
completo() {
  local m oggetto="${2:-${OGGETTO}}"
  for m in haiku sonnet opus; do
    risposta "$1/risposte/solo-json-${m}.json" testo "${oggetto}"
  done
  risposta "$1/risposte/schema-haiku.json" schema "${oggetto}" success false
  : > "$1/risposte/schema-non-valido.json"
  printf '%s\nuscita: 1\n' "${ERRORE}" > "$1/risposte/schema-non-valido.txt"
}

# controlla_json.py nello spazio di lavoro $1, con gli argomenti che
# seguono: RC e OUT per expect.
controlla() {
  OUT="$(cd "$1" && python3 -B -I controlla_json.py "${@:2}" 2>&1)"
  RC=$?
}

# Il ramo dell'errore inatteso: main() del controllo di demo/ con un
# controlla() che solleva un'eccezione. Arguments: gli argomenti di main
# (--senza-esiti, lo spazio di lavoro). RC e OUT per expect.
inatteso() {
  run python3 -B -I -c 'import importlib.util, sys
spec = importlib.util.spec_from_file_location("controllo", sys.argv[1])
modulo = importlib.util.module_from_spec(spec)
spec.loader.exec_module(modulo)
def guasto(*_):
    raise RuntimeError("guasto finto")
modulo.controlla = guasto
sys.exit(modulo.main(sys.argv[2:]))' "${ELEMENTO}/demo/controlla_json.py" "$@"
}

# Una copia di verifica.sh e di demo/ in cui il controllo è finto: esce
# con il codice dato, o si fa terminare da un segnale. L'albero del
# repository non cambia. Arguments: $1 la variabile da assegnare (la
# copia), $2 il codice d'uscita, oppure «segnale».
albero_finto() {
  local __a
  __a="$(mktemp -d "${TMP}/albero.XXXXXX")" \
    || { echo "test_m2_d03: mktemp" >&2; exit 2; }
  if ! cp -- "${VERIFICA}" "${__a}/" || ! cp -R "${ELEMENTO}/demo" "${__a}/"
  then
    echo "test_m2_d03: non riesco a copiare l'elemento" >&2
    exit 2
  fi
  if [[ "$2" == segnale ]]; then
    printf '%s\n' 'import os, signal' 'os.kill(os.getpid(), signal.SIGTERM)' \
      > "${__a}/demo/controlla_json.py"
  else
    printf 'import sys\nsys.exit(%d)\n' "$2" > "${__a}/demo/controlla_json.py"
  fi
  printf -v "$1" '%s' "${__a}"
}

# Un comando con il claude finto davanti nel PATH; i suoi registri
# ripartono vuoti. Arguments: le variabili NOME=valore e il comando.
finto() {
  : > "${TMP}/chiamate.log"
  : > "${TMP}/argomenti.log"
  run env PATH="${TMP}/bin:${PATH}" HANDSON_NO_PAUSE=1 \
    FINTO_LOG="${TMP}/chiamate.log" FINTO_ARGV="${TMP}/argomenti.log" \
    FINTO_ERRORE="${ERRORE}" FINTO_OGGETTO="${OGGETTO}" "$@"
}

# Quante chiamate ha ricevuto il claude finto (--version escluso).
chiamate() { grep -c '^chiamata' "${TMP}/chiamate.log"; }

# Il claude finto in ${TMP}/bin. --version risponde senza registrare; ogni
# altra chiamata scrive una riga in FINTO_LOG («CHIAVE» se riceve
# ANTHROPIC_API_KEY) e i suoi argomenti in FINTO_ARGV, una riga JSON. Con
# FINTO_ESITO=ko esce 1 senza stampare. Uno schema con «"oggetto"» lo
# rifiuta come Claude Code (uscita 1, FINTO_ERRORE su STDERR, niente su
# STDOUT), salvo FINTO_ACCETTA=1; altrimenti risponde con FINTO_OGGETTO,
# in result e, con --json-schema, in structured_output.
prepara_finto() {
  mkdir -p "${TMP}/bin" || exit 2
  cat > "${TMP}/bin/claude" <<'PY' || exit 2
#!/usr/bin/env python3
"""Il claude finto di test_m2_d03.sh: nessuna chiamata a un modello."""
import json
import os
import sys

argv = sys.argv[1:]
if argv[:1] == ["--version"]:
    print("0.0.0 (Claude Code, finto)")
    sys.exit(0)
with open(os.environ["FINTO_LOG"], "a", encoding="utf-8") as fh:
    fh.write("chiamata %s\n"
             % ("CHIAVE" if os.environ.get("ANTHROPIC_API_KEY") else "-"))
with open(os.environ["FINTO_ARGV"], "a", encoding="utf-8") as fh:
    fh.write(json.dumps(argv, ensure_ascii=False) + "\n")
if os.environ.get("FINTO_ESITO", "ok") != "ok":
    sys.exit(1)
schema = None
for i in range(len(argv) - 1):
    if argv[i] == "--json-schema":
        schema = argv[i + 1]
if (schema is not None and '"oggetto"' in schema
        and os.environ.get("FINTO_ACCETTA") != "1"):
    sys.stderr.write(os.environ["FINTO_ERRORE"] + "\n")
    sys.exit(1)
oggetto = json.loads(os.environ["FINTO_OGGETTO"])
doc = {"type": "result", "subtype": "success", "is_error": False,
       "result": json.dumps(oggetto, ensure_ascii=False),
       "usage": {"input_tokens": 3, "output_tokens": 5}}
if schema is not None:
    doc["structured_output"] = oggetto
print(json.dumps(doc, ensure_ascii=False))
PY
  chmod 755 "${TMP}/bin/claude" || exit 2
  # Un PATH con il solo readlink, senza python3, per verifica.sh.
  mkdir -p "${TMP}/solo_readlink" || exit 2
  ln -s "$(command -v readlink)" "${TMP}/solo_readlink/readlink" || exit 2
}

# Il claude finto dev'essere il primo nel PATH delle prove: il claude vero
# non si chiama mai. Esce 2 se non lo è.
finto_primo() {
  local trovato
  trovato="$(env PATH="${TMP}/bin:${PATH}" bash -c 'command -v claude')"
  if [[ "${trovato}" != "${TMP}/bin/claude" ]]; then
    echo "test_m2_d03: il claude finto non è il primo nel PATH" \
      "(${trovato})" >&2
    exit 2
  fi
}

# --- controlla_json.py ------------------------------------------------------

# Un'esecuzione completa: le tre affermazioni confermate; la 4, una
# dimostrazione senza verdetto, con l'oggetto modificato e la sua
# etichetta; il telefono contato; esiti.tsv.
t_confermate() {
  local w copia
  ws w
  completo "${w}"
  controlla "${w}"
  expect "controlla: completa, uscita 0" 0 "Scritto esiti.tsv."
  expect "controlla: 1 confermata" 0 "${A_PAROLE} (da provare): confermata"
  expect "controlla: 2 confermata" 0 "${CON_SCHEMA} (garantita): confermata"
  expect "controlla: 3 confermata" 0 "${NON_VALIDO} (garantita): confermata"
  expect "controlla: la 4, una dimostrazione senza verdetto" 0 "${DIMOSTRA}"
  expect_absent "controlla: la 4 non è fra le garanzie" "${FORMA} (garantita)"
  expect "controlla: la 1 contata" 0 "a parole: 3 su 3 validi e conformi"
  expect "controlla: la 3, la riga su STDERR e niente su STDOUT" 0 \
    "uscita 1; su STDERR «${ERRORE}»; su STDOUT niente"
  copia="tipo_cliente «azienda» → «privato» (un oggetto modificato dal"
  copia+=" controllo, non una risposta del modello): conforme allo schema sì"
  expect "controlla: la 4, la copia con la sua etichetta" 0 "${copia}"
  expect "controlla: il telefono contato" 0 \
    "telefono del cliente in 4 risposte su 4"
  expect_absent "controlla: completa, nessuna garanzia smentita" \
    "${GARANTISCE}"
  [[ "$(head -n 1 "${w}/esiti.tsv")" \
      == "affermazione${T}classe${T}esito${T}dettaglio" ]] \
    && (( $(wc -l < "${w}/esiti.tsv") == 5 )) \
    && grep -qF -- "${A_PAROLE}${T}da provare${T}confermata${T}" \
      "${w}/esiti.tsv" \
    && grep -qF -- "${FORMA}${T}dimostrazione${T}nessun verdetto${T}" \
      "${w}/esiti.tsv"
  check "controlla: esiti.tsv, l'intestazione e quattro righe" $? \
    "$(cat "${w}/esiti.tsv")"
}

# La 1: un blocco di codice e ogni regola dello schema la rendono «non
# confermata», con l'uscita che resta 0; una risposta che manca o non è
# quella di claude -p la rende «non distinguibile», con l'uscita 1.
t_parole() {
  local w r atteso
  local -a nomi=(manca errore senza_result non_json non_oggetto)
  local -a parole=('manca risposte/solo-json-opus.json'
    'la chiamata è finita con un errore (is_error)'
    'manca il campo result'
    'risposte/solo-json-opus.json non è un JSON valido'
    'risposte/solo-json-opus.json non è il JSON di claude -p')
  ws w
  completo "${w}"
  risposta "${w}/risposte/solo-json-opus.json" testo \
    $'```json\n'"${OGGETTO}"$'\n```'
  controlla "${w}"
  expect "1: un blocco di codice non è JSON valido" 0 \
    "solo-json-opus.json: JSON valido no (dentro un blocco di codice)"
  expect "1: non confermata, e l'uscita resta 0" 0 \
    "${A_PAROLE} (da provare): ${NON_CONF}"
  expect "1: contata" 0 "a parole: 2 su 3 validi e conformi"
  expect_absent "1: una raccomandazione non è una garanzia smentita" \
    "${GARANTISCE}"
  for r in in_piu manca valore tipo; do
    ws w
    completo "${w}"
    risposta "${w}/risposte/solo-json-opus.json" testo "$(variante "${r}")"
    controlla "${w}"
    expect "1: lo schema non accetta la regola infranta ${r}" 0 \
      "solo-json-opus.json: JSON valido sì, conforme allo schema no"
  done
  for r in "${!nomi[@]}"; do
    ws w
    completo "${w}"
    rovina "${w}/risposte/solo-json-opus.json" "${nomi[r]}"
    controlla "${w}"
    atteso="(da provare): non distinguibile (${parole[r]}: rifate la"
    atteso+=" chiamata di opus, passo 2)"
    expect "1: ${nomi[r]}, non distinguibile e uscita 1" 1 "${atteso}"
  done
}

# La 2: un oggetto fuori dallo schema non la conferma (e la 4 resta senza
# copia); structured_output null, oppure assente con un errore, o il
# file che manca, la lasciano «non distinguibile». Uscita 1 ogni volta.
t_schema() {
  local w atteso
  ws w
  completo "${w}"
  risposta "${w}/risposte/schema-haiku.json" schema \
    "${OGGETTO/azienda/ditta}" success false
  controlla "${w}"
  expect "2: un oggetto fuori dallo schema, non confermata" 1 \
    "${CON_SCHEMA} (garantita): ${NON_CONF}"
  expect "2: la documentazione garantisce, in questa esecuzione no" 1 \
    "${SMENTITA_2}"
  expect "4: senza un oggetto validato, nessuna copia" 1 \
    "  nessun oggetto validato da modificare: vedi l'affermazione 2"
  expect_absent "4: senza un oggetto validato, nessun verdetto" \
    "${FORMA} (garantita)"
  ws w
  completo "${w}"
  risposta "${w}/risposte/schema-haiku.json" schema null success false
  controlla "${w}"
  atteso="non distinguibile (subtype success ma nessuno structured_output:"
  atteso+=" la documentazione dice di trattare anche questo caso come un"
  atteso+=" errore; rifate il passo 3)"
  expect "2: structured_output null, non distinguibile" 1 "${atteso}"
  ws w
  completo "${w}"
  risposta "${w}/risposte/schema-haiku.json" schema - \
    error_max_structured_output_retries true
  controlla "${w}"
  atteso="non distinguibile (la chiamata è finita con un errore (subtype"
  atteso+=" error_max_structured_output_retries), senza structured_output:"
  atteso+=" rifate il passo 3)"
  expect "2: un subtype di errore, senza il campo" 1 "${atteso}"
  ws w
  completo "${w}"
  rm "${w}/risposte/schema-haiku.json"
  controlla "${w}"
  expect "2: il file che manca" 1 \
    "non distinguibile (manca risposte/schema-haiku.json: rifate il passo 3)"
  expect "il telefono, sulle sole risposte che ci sono" 1 \
    "telefono del cliente in 3 risposte su 3"
}

# La 3 non confermata (uscita 1): claude esce con 0, oppure il modello
# risponde; non distinguibile con un altro errore, senza la riga «uscita:
# N» o senza uno dei due file.
t_non_valido_no() {
  local w f atteso
  ws w
  completo "${w}"
  risposta "${w}/risposte/schema-non-valido.json" schema "${OGGETTO}" \
    success false
  printf 'uscita: 0\n' > "${w}/risposte/schema-non-valido.txt"
  controlla "${w}"
  expect "3: uscita 0, non confermata" 1 \
    "${NON_VALIDO} (garantita): ${NON_CONF}"
  expect "3: la documentazione garantisce, in questa esecuzione no" 1 \
    "${SMENTITA_3}"
  ws w
  completo "${w}"
  risposta "${w}/risposte/schema-non-valido.json" schema "${OGGETTO}" \
    success false
  controlla "${w}"
  expect "3: la riga d'errore, ma il modello ha risposto" 1 \
    "su STDOUT un JSON con result o usage: il modello ha risposto"
  expect "3: e non è confermata" 1 "${NON_VALIDO} (garantita): ${NON_CONF}"
  ws w
  completo "${w}"
  printf 'Error: Invalid API key\nuscita: 1\n' \
    > "${w}/risposte/schema-non-valido.txt"
  controlla "${w}"
  atteso="non distinguibile (claude è uscito con 1, ma senza la riga «is"
  atteso+=" not a valid JSON Schema»: un altro errore, leggete"
  atteso+=" risposte/schema-non-valido.txt)"
  expect "3: un altro errore, non distinguibile" 1 "${atteso}"
  ws w
  completo "${w}"
  printf '%s\n' "${ERRORE}" > "${w}/risposte/schema-non-valido.txt"
  controlla "${w}"
  expect "3: senza la riga «uscita: N»" 1 \
    "manca la riga «uscita: N»: eseguite il passo 4 per intero)"
  ws w
  completo "${w}"
  printf '%s\nuscita: 0\n' "${ERRORE}" > "${w}/risposte/schema-non-valido.txt"
  controlla "${w}"
  atteso="(garantita): non distinguibile (c'è la riga «is not a valid JSON"
  atteso+=" Schema», ma con «uscita: 0» e nessuna risposta sullo STDOUT: la"
  atteso+=" riga «uscita» va subito dopo claude; rifate il passo 4)"
  expect "3: la riga d'errore con «uscita: 0», non distinguibile" 1 \
    "${atteso}"
  expect_absent "3: la riga d'errore con «uscita: 0», nessuna smentita" \
    "${GARANTISCE}"
  ws w
  completo "${w}"
  printf '%s\nuscita: %s\n' "${ERRORE}" "$(printf '9%.0s' {1..5000})" \
    > "${w}/risposte/schema-non-valido.txt"
  controlla "${w}"
  expect "3: un codice d'uscita di 5000 cifre non è un codice" 1 \
    "manca la riga «uscita: N»: eseguite il passo 4 per intero)"
  expect_absent "3: le 5000 cifre, nessun traceback" "Traceback"
  for f in schema-non-valido.txt schema-non-valido.json; do
    ws w
    completo "${w}"
    rm "${w}/risposte/${f}"
    controlla "${w}"
    expect "3: manca ${f}" 1 \
      "non distinguibile (manca risposte/${f}: eseguite il passo 4)"
  done
}

# La 3 confermata in altri modi (uscita 0): la riga su STDOUT; gli a capo
# di Windows; una diagnostica lunga, troncata.
t_non_valido_si() {
  local w lunga
  ws w
  completo "${w}"
  printf '%s\n' "${ERRORE}" > "${w}/risposte/schema-non-valido.json"
  printf 'uscita: 1\n' > "${w}/risposte/schema-non-valido.txt"
  controlla "${w}"
  expect "3: la riga su STDOUT, confermata" 0 "su STDOUT «${ERRORE}»"
  ws w
  completo "${w}"
  printf '%s\r\nuscita: 1\r\n' "${ERRORE}" \
    > "${w}/risposte/schema-non-valido.txt"
  controlla "${w}"
  expect "3: gli a capo di Windows" 0 "${NON_VALIDO} (garantita): confermata"
  ws w
  completo "${w}"
  printf -v lunga '%s' "${ERRORE}" ' e poi ancora'{1..40}
  printf '%s\nuscita: 1\n' "${lunga}" > "${w}/risposte/schema-non-valido.txt"
  controlla "${w}"
  expect "3: una diagnostica lunga, troncata" 0 "…»; su STDOUT niente"
  expect_absent "3: e senza la sua coda" "ancora40"
}

# La 4 nell'altro verso, «privato» che diventa «azienda»; il telefono che
# non c'è, e quello scritto con i trattini.
t_forma() {
  local w oggetto
  oggetto="${OGGETTO/azienda/privato}"
  oggetto="${oggetto/al +39 000 000 0103/il cliente}"
  ws w
  completo "${w}" "${oggetto}"
  controlla "${w}"
  expect "4: «privato» diventa «azienda» nella copia" 0 \
    "tipo_cliente «privato» → «azienda»"
  expect "4: il telefono che non c'è" 0 \
    "telefono del cliente in 0 risposte su 4"
  ws w
  completo "${w}" "${OGGETTO/+39 000 000 0103/+39 000-000-0103}"
  controlla "${w}"
  expect "il telefono con i trattini si conta" 0 \
    "telefono del cliente in 4 risposte su 4"
}

# Le precondizioni (uscita 2): gli argomenti, lo spazio di lavoro,
# schema.json, esiti.tsv che non si scrive, un file che non si legge, un
# errore inatteso; la cartella risposte/ che manca esce 1.
t_precondizioni() {
  local w schema
  ws w
  controlla "${w}" --boh
  expect "controlla: un'opzione sconosciuta, uscita 2" 2 "Uso:"
  controlla "${w}" . .
  expect "controlla: due spazi di lavoro, uscita 2" 2 \
    "uno spazio di lavoro per volta"
  controlla "${w}" "${TMP}/assente"
  expect "controlla: uno spazio di lavoro che non c'è, uscita 2" 2 \
    "spazio di lavoro assente: ${TMP}/assente"
  ws w
  completo "${w}"
  printf 'vecchio\n' > "${w}/esiti.tsv"
  rm -r "${w}/risposte"
  controlla "${w}"
  expect "controlla: manca la cartella risposte/, uscita 1" 1 "${PARTENZA}"
  [[ ! -e "${w}/esiti.tsv" ]]
  check "controlla: senza risposte/, un esiti.tsv vecchio tolto" $? \
    "esiti.tsv è rimasto"
  ws w
  completo "${w}"
  printf 'vecchio\n' > "${w}/esiti.tsv"
  inatteso --senza-esiti "${w}"
  expect "controlla: un errore inatteso esce 2, senza traceback" 2 \
    "errore inatteso (RuntimeError: guasto finto)"
  [[ "$(cat "${w}/esiti.tsv")" == vecchio ]]
  check "controlla: con --senza-esiti l'esiti.tsv vecchio resta" $? \
    "esiti.tsv cambiato"
  inatteso "${w}"
  [[ ! -e "${w}/esiti.tsv" ]]
  check "controlla: un errore inatteso toglie l'esiti.tsv vecchio" $? \
    "esiti.tsv è rimasto"
  ws w
  completo "${w}"
  printf 'vecchio\n' > "${w}/esiti.tsv"
  rm "${w}/schema.json"
  controlla "${w}"
  expect "controlla: manca schema.json, uscita 2" 2 "manca schema.json"
  [[ ! -e "${w}/esiti.tsv" ]]
  check "controlla: un esiti.tsv vecchio, tolto" $? "esiti.tsv è rimasto"
  printf '{\n' > "${w}/schema.json"
  controlla "${w}"
  expect "controlla: schema.json rovinato, uscita 2" 2 \
    "schema.json non è un JSON valido"
  schema='{"properties": {"tipo_cliente": {"enum": ["azienda"]}},'
  schema+=' "required": ["tipo_cliente"]}'
  printf '%s\n' "${schema}" > "${w}/schema.json"
  controlla "${w}"
  expect "controlla: uno schema che non è quello della demo, uscita 2" 2 \
    "schema.json non è lo schema della demo"
  ws w
  completo "${w}"
  mkdir "${w}/esiti.tsv"
  controlla "${w}"
  expect "controlla: esiti.tsv che non si scrive, uscita 2" 2 \
    "esiti.tsv non si scrive"
  if (( EUID == 0 )); then
    skip "controlla: da root ogni file si legge"
    return 0
  fi
  ws w
  completo "${w}"
  chmod 000 "${w}/risposte/schema-haiku.json"
  controlla "${w}"
  expect "controlla: un file che non si legge, uscita 2" 2 \
    "risposte/schema-haiku.json non si legge"
}

# I dati rovinati, mai con un traceback: un JSON annidato a dismisura, nel
# file o nella risposta; byte che non sono UTF-8.
t_rovinati() {
  local w
  ws w
  completo "${w}"
  printf '[%.0s' {1..100000} > "${w}/risposte/solo-json-opus.json"
  controlla "${w}"
  expect "controlla: un file annidato a dismisura, uscita 1" 1 \
    "risposte/solo-json-opus.json non è un JSON valido"
  expect_absent "controlla: il file annidato, nessun traceback" "Traceback"
  ws w
  completo "${w}"
  risposta "${w}/risposte/solo-json-opus.json" testo \
    "$(printf '[%.0s' {1..100000})"
  controlla "${w}"
  expect "controlla: una risposta annidata a dismisura, JSON valido no" 0 \
    "solo-json-opus.json: JSON valido no"
  expect_absent "controlla: la risposta annidata, nessun traceback" \
    "Traceback"
  ws w
  completo "${w}"
  printf '{"type": "result", "is_error": false, "result": "\xff"}\n' \
    > "${w}/risposte/solo-json-opus.json"
  controlla "${w}"
  expect "controlla: byte che non sono UTF-8, letti senza traceback" 0 \
    "solo-json-opus.json: JSON valido no"
}

# --- verifica.sh ------------------------------------------------------------

# verifica.sh: le uscite 0, 1 e 2 sulle risposte, e la frase finale per
# ultima. Nessun caso lancia prima controlla_json.py: la verifica fa
# girare da sé il controllo di demo/, e non scrive esiti.tsv.
t_verifica() {
  local w
  run "${VERIFICA}" "${TMP}/assente"
  expect "verifica: spazio di lavoro assente" 2 "spazio di lavoro assente"
  ws w
  rmdir "${w}/risposte"
  run "${VERIFICA}" "${w}"
  expect "verifica: il punto di partenza" 1 "${PARTENZA}"
  ws w
  completo "${w}"
  run "${VERIFICA}" "${w}"
  [[ "${OUT##*$'\n'}" == "${FATTO}" ]]
  check "verifica: completa, la frase finale per ultima" $? "${OUT:0:400}"
  expect "verifica: completa, uscita 0" 0 \
    "${NON_VALIDO} (garantita): confermata"
  expect_absent "verifica: completa, senza segnalazioni" "Non ancora"
  [[ ! -e "${w}/esiti.tsv" ]]
  check "verifica: non scrive esiti.tsv" $? "esiti.tsv scritto"
  ws w
  completo "${w}"
  risposta "${w}/risposte/solo-json-opus.json" testo "non JSON"
  run "${VERIFICA}" "${w}"
  expect "verifica: la 1 non confermata, uscita 0" 0 "${FATTO}"
  expect "verifica: e lo dice, da provare" 0 \
    "L'affermazione 1 è da provare: si conta, e non fa fallire la verifica."
  ws w
  completo "${w}"
  risposta "${w}/risposte/schema-haiku.json" schema \
    "${OGGETTO/azienda/ditta}" success false
  run "${VERIFICA}" "${w}"
  expect "verifica: la 2 non confermata, uscita 1" 1 "${SMENTITA_2}"
  ws w
  completo "${w}"
  printf 'uscita: 0\n' > "${w}/risposte/schema-non-valido.txt"
  run "${VERIFICA}" "${w}"
  expect "verifica: la 3 non confermata, uscita 1" 1 "${SMENTITA_3}"
  expect_absent "verifica: la 3 non confermata, niente frase finale" \
    "${FATTO}"
  ws w
  completo "${w}"
  rm "${w}/risposte/solo-json-sonnet.json"
  run "${VERIFICA}" "${w}"
  expect "verifica: una risposta che manca, uscita 1" 1 \
    "Non ancora: una risposta manca o non si legge"
}

# verifica.sh decide dalle risposte, mai da esiti.tsv: risposte/ tolta con
# un esiti.tsv vecchio (1); un esiti.tsv tutto confermato, con una
# risposta che non conferma (1); schema.json cambiato (2); python3 che
# manca (2); un controllo che esce con un codice fuori dal contratto, o
# per un segnale (2); una risposta che non si legge (2).
t_verifica_risposte() {
  local w a
  ws w
  completo "${w}"
  controlla "${w}"
  rm -r "${w}/risposte"
  run "${VERIFICA}" "${w}"
  expect "verifica: risposte/ tolta, con un esiti.tsv vecchio" 1 \
    "${PARTENZA}"
  expect_absent "verifica: risposte/ tolta, nessuna frase finale" "${FATTO}"
  ws w
  completo "${w}"
  controlla "${w}"
  printf 'uscita: 0\n' > "${w}/risposte/schema-non-valido.txt"
  run "${VERIFICA}" "${w}"
  expect "verifica: un esiti.tsv tutto confermato non conta" 1 \
    "${SMENTITA_3}"
  ws w
  completo "${w}"
  controlla "${w}"
  printf '{\n' > "${w}/schema.json"
  run "${VERIFICA}" "${w}"
  expect "verifica: schema.json cambiato, uscita 2" 2 \
    "schema.json non è un JSON valido"
  expect_absent "verifica: schema.json cambiato, nessuna frase finale" \
    "${FATTO}"
  ws w
  completo "${w}"
  run env PATH="${TMP}/solo_readlink" "${VERIFICA}" "${w}"
  expect "verifica: python3 che manca, uscita 2" 2 "manca python3"
  albero_finto a 3
  run "${a}/verifica.sh" "${w}"
  expect "verifica: un controllo che esce con 3, uscita 2" 2 \
    "controlla_json.py è uscito con 3"
  albero_finto a segnale
  run "${a}/verifica.sh" "${w}"
  expect "verifica: un controllo terminato da un segnale, uscita 2" 2 \
    "controlla_json.py è uscito con 143"
  if (( EUID == 0 )); then
    skip "verifica: da root ogni file si legge"
    return 0
  fi
  chmod 000 "${w}/risposte/schema-haiku.json"
  run "${VERIFICA}" "${w}"
  expect "verifica: una risposta che non si legge, uscita 2" 2 \
    "risposte/schema-haiku.json non si legge"
}

# --- _docente/live.sh -------------------------------------------------------

# Una precondizione di live.sh: uscita 2, la parola attesa e nessuna
# chiamata al claude finto. Arguments: $1 il nome, $2 la parola, poi il
# comando.
precondizione() {
  local nome="$1" parola="$2" v
  shift 2
  finto "$@"
  expect "${nome}: uscita 2" 2 "${parola}"
  v="$(chiamate)"
  (( v == 0 ))
  check "${nome}: nessuna chiamata a claude" $? "${v} chiamate"
}

# Le precondizioni di live.sh, senza chiamare claude.
t_live_precondizioni() {
  local w f
  precondizione "live: nessuno spazio di lavoro" "spazio di lavoro assente" \
    "${LIVE}"
  precondizione "live: spazio di lavoro assente" "spazio di lavoro assente" \
    "${LIVE}" "${TMP}/assente"
  for f in richiesta-json.md istruzione.txt schema.json \
      schema-non-valido.json controlla_json.py; do
    ws w
    rm "${w}/${f}"
    precondizione "live: manca ${f}" "file assente o illeggibile: ${f}" \
      "${LIVE}" "${w}"
  done
}

# I testi e le opzioni che il claude finto ha ricevuto: le cinque chiamate,
# nell'ordine, con i testi dei file e le opzioni della registrazione.
# Arguments: $1 lo spazio di lavoro. Outputs: «argomenti: ok» o i problemi.
argomenti() {
  python3 -B -I - "${TMP}/argomenti.log" "$1" <<'PY'
import json
import os
import sys

registro, ws = sys.argv[1], sys.argv[2]


def testo(nome):
    """Il file com'è dopo $(cat …): senza gli a capo finali."""
    with open(os.path.join(ws, nome), encoding="utf-8") as fh:
        return fh.read().rstrip("\n")


def valore(opzioni, nome):
    """Il valore di un'opzione, None se non c'è."""
    return opzioni[opzioni.index(nome) + 1] if nome in opzioni else None


with open(registro, encoding="utf-8") as fh:
    chiamate = [json.loads(riga) for riga in fh]
modelli = ["haiku", "sonnet", "opus", "haiku", "haiku"]
schemi = [None, None, None, testo("schema.json"),
          testo("schema-non-valido.json")]
attese = {"--system-prompt": testo("istruzione.txt"), "--effort": "low",
          "--tools": "", "--output-format": "json",
          "--setting-sources": "project,local",
          "--permission-mode": "dontAsk", "--permission-prompts": "none"}
problemi = []
if len(chiamate) != len(modelli):
    problemi.append("%d chiamate" % len(chiamate))
for n, argv in enumerate(chiamate[:len(modelli)], 1):
    opzioni = argv[:argv.index("--")] if "--" in argv else argv
    if argv[-2:] != ["--", testo("richiesta-json.md")]:
        problemi.append("chiamata %d: il prompt" % n)
    if valore(opzioni, "--model") != modelli[n - 1]:
        problemi.append("chiamata %d: il modello" % n)
    if valore(opzioni, "--json-schema") != schemi[n - 1]:
        problemi.append("chiamata %d: lo schema" % n)
    for nome, atteso in attese.items():
        if valore(opzioni, nome) != atteso:
            problemi.append("chiamata %d: %s" % (n, nome))
    for nome in ("-p", "--strict-mcp-config", "--no-session-persistence"):
        if nome not in opzioni:
            problemi.append("chiamata %d: manca %s" % (n, nome))
print("argomenti: " + ("; ".join(problemi) or "ok"))
PY
}

# live.sh con le risposte complete (0), con uno schema non valido accettato
# (1), con una chiamata fallita (1, alla prima), con controlla_json.py che
# non può girare (2), con ANTHROPIC_API_KEY.
t_live() {
  local w v txt
  ws w
  finto "${LIVE}" "${w}"
  expect "live: le risposte complete, uscita 0" 0 "VERIFICA OK"
  v="$(chiamate)"
  (( v == 5 ))
  check "live: cinque chiamate" $? "${v} chiamate"
  txt="${w}/risposte/schema-non-valido.txt"
  [[ "$(head -n 1 "${txt}")" == "${ERRORE}" ]] \
    && [[ "$(tail -n 1 "${txt}")" == 'uscita: 1' ]] \
    && (( $(wc -l < "${txt}") == 2 ))
  check "live: la riga d'errore e l'uscita, senza il comando stampato" $? \
    "$(cat "${txt}")"
  [[ -f "${w}/risposte/schema-non-valido.json" \
      && ! -s "${w}/risposte/schema-non-valido.json" ]]
  check "live: lo STDOUT dello schema non valido, vuoto e a parte" $? \
    "$(cat "${w}/risposte/schema-non-valido.json" 2>&1)"
  OUT="$(argomenti "${w}")"
  RC=$?
  expect "live: i testi dei file e le opzioni della registrazione" 0 \
    "argomenti: ok"
  ws w
  finto FINTO_ACCETTA=1 "${LIVE}" "${w}"
  expect "live: uno schema non valido accettato, uscita 1" 1 \
    "${SMENTITA_3}"
  expect "live: e il verdetto KO" 1 "VERIFICA KO"
  ws w
  finto FINTO_ESITO=ko "${LIVE}" "${w}"
  v="$(chiamate)"
  (( RC == 1 && v == 1 )) && grep -qF -- 'VERIFICA KO' <<< "${OUT}"
  check "live: si ferma alla prima chiamata fallita" $? \
    "rc=${RC}, ${v} chiamate: ${OUT:0:300}"
  ws w
  printf '{\n' > "${w}/schema.json"
  finto "${LIVE}" "${w}"
  expect "live: controlla_json.py che non può girare, uscita 2" 2 \
    "controlla_json.py non ha potuto girare (uscita 2)"
  ws w
  finto ANTHROPIC_API_KEY=finta "${LIVE}" "${w}"
  if grep -q 'CHIAVE' "${TMP}/chiamate.log"; then
    fail "live: ANTHROPIC_API_KEY arriva a claude"
  else
    pass "live: ANTHROPIC_API_KEY non arriva a claude"
  fi
}

# --- Il README e shellcheck -------------------------------------------------

# Il README: il passo dello schema non valido come lo manda live.sh, le
# stesse opzioni nei tre passi con claude, le due sottosezioni.
t_readme() {
  local r="${ELEMENTO}/README.md" riga n ok=0
  # shellcheck disable=SC2016  # $(…) e $? sono testo del README
  for riga in '--json-schema "$(cat schema-non-valido.json)"' \
      '> risposte/schema-non-valido.json 2> risposte/schema-non-valido.txt' \
      'echo "uscita: $?" >> risposte/schema-non-valido.txt'; do
    grep -qF -- "${riga}" "${r}" || ok=1
  done
  check "README: il passo dello schema non valido" "${ok}" \
    "manca una riga del passo"
  ok=0
  # shellcheck disable=SC2016  # $(…) è testo del README
  for riga in '--tools "" --system-prompt "$(cat istruzione.txt)"' \
      '--strict-mcp-config --no-session-persistence' \
      'claude -p "$(cat richiesta-json.md)" --model'; do
    n="$(grep -cF -- "${riga}" "${r}")"
    (( n == 3 )) || ok=1
  done
  check "README: le stesse opzioni nei tre passi con claude" "${ok}" \
    "un passo senza le opzioni di live.sh"
  grep -qx '### Che cosa dice Anthropic' "${r}" \
    && grep -qx '### Che cosa misura il controllo' "${r}"
  check "README: le due sottosezioni di «Che cosa osservare»" $? \
    "manca una sottosezione"
}

# Lo shellcheck degli script dell'elemento e di questa prova.
t_shellcheck() {
  local f
  for f in "${VERIFICA}" "${LIVE}" "${SELF}"; do
    shellcheck -x "${f}" > /dev/null 2>&1
    check "shellcheck ${f##*/}" $? "shellcheck -x ${f}"
  done
}

# Toglie la cartella temporanea: mai un percorso vuoto, / o un
# collegamento simbolico (RU-01.S5).
pulisci() {
  if [[ -n "${TMP}" && "${TMP}" != "/" && -d "${TMP}" && ! -L "${TMP}" ]]
  then
    chmod -R u+rwX "${TMP}" 2> /dev/null
    rm -rf -- "${TMP}"
  fi
}

main() {
  local t
  for t in python3 shellcheck awk; do
    command -v "${t}" > /dev/null 2>&1 \
      || { echo "test_m2_d03: manca ${t}" >&2; exit 2; }
  done
  for t in "${ELEMENTO}/demo/controlla_json.py" \
      "${ELEMENTO}/demo/schema-non-valido.json" "${ELEMENTO}/README.md" \
      "${VERIFICA}" "${LIVE}"; do
    [[ -f "${t}" ]] || { echo "test_m2_d03: manca ${t}" >&2; exit 2; }
  done
  TMP="$(mktemp -d)" || { echo "test_m2_d03: mktemp" >&2; exit 2; }
  trap pulisci EXIT
  prepara_finto
  finto_primo
  t_confermate
  t_parole
  t_schema
  t_non_valido_no
  t_non_valido_si
  t_forma
  t_precondizioni
  t_rovinati
  t_verifica
  t_verifica_risposte
  t_live_precondizioni
  t_live
  t_readme
  t_shellcheck
  echo "PASS=${PASS} FAIL=${FAIL} SKIP=${SKIP}"
  if (( PASS + FAIL + SKIP != CASES )); then
    echo "test_m2_d03: girati $((PASS + FAIL + SKIP)) casi, attesi" \
      "${CASES}: un caso manca o non è contato" >&2
    exit 2
  fi
  (( FAIL == 0 )) || exit 1
}

main "$@"
