#!/bin/bash
#
# test_m2_d04.sh -- le prove di M2-D04 «Zero-shot contro few-shot», per il
# docente (sta in _docente/, il materiale del docente):
#   - i prompt: ogni variante cambia una cosa sola rispetto alla precedente
#     (gli esempi fra tag, poi la regola e gli elenchi);
#   - controlla_etichette.py su risposte scritte qui: ogni valore di ogni
#     colonna (la forma, anche con «Classificazione:» davanti, il
#     grassetto, due righe, una maiuscola; le etichette elencate o no;
#     l'oggetto conforme, con una maiuscola, fuori dall'enum, con una
#     chiave in meno o in più, non una stringa, non un oggetto, assente per
#     un errore o per il campo che manca, con l'uscita 1 quando la garanzia
#     non tiene); le risposte rovinate (un file che manca, vuoto, non
#     JSON, un elenco, is_error, senza result, annidato a dismisura, non
#     UTF-8) con l'uscita 1 e senza traceback; le precondizioni con
#     l'uscita 2 e un esiti.tsv vecchio tolto (argomenti, spazio di
#     lavoro, schema.json e con-etichette.md, gli enum diversi dagli
#     elenchi, una risposta che non si legge, esiti.tsv che non si scrive,
#     un errore inatteso); la cartella risposte/ che manca (1);
#     --senza-esiti, che non scrive né toglie esiti.tsv; --solo-schema;
#   - verifica.sh, che fa girare il controllo di demo/ sulle risposte con
#     --senza-esiti e non legge esiti.tsv: spazio di lavoro assente (2),
#     punto di partenza (1), risposte complete e confermate (0, con la
#     frase finale, nessun esiti.tsv scritto), ogni verdetto delle tre
#     affermazioni (le raccomandazioni non fanno fallire, la garanzia sì,
#     la chiamata fallita), una risposta che manca (1), risposte/ tolta con
#     un esiti.tsv vecchio (1), un esiti.tsv falso che non conta (1), un
#     enum cambiato (2), una risposta che non si legge (2), python3 che
#     manca (2), un controllo che esce con un codice fuori dal contratto o
#     per un segnale (2);
#   - _docente/live.sh: le precondizioni escono 2 senza chiamare claude
#     (un claude esca davanti nel PATH registra ogni invocazione, anche
#     --version); con un claude finto scritto qui, le otto chiamate con i
#     testi e le opzioni del passo 3 del README (il suo blocco gira con lo
#     stesso finto, e le sue chiamate si confrontano con quelle di
#     live.sh), i verdetti a schermo anche quando passa, la prima chiamata
#     fallita (si ferma lì), la garanzia non confermata, la chiamata con lo
#     schema senza oggetto, controlla_etichette.py che esce 2 dopo le
#     chiamate (una precondizione: live.sh esce 2);
#   - shellcheck -x su verifica.sh, live.sh e questo file.
# Mai il claude vero: il finto e l'esca stanno davanti nel PATH, e la
# suite lo controlla prima di usarli. Gli spazi di lavoro nascono in una
# cartella temporanea: l'albero del repository non cambia. CASES è il
# numero dei casi: se ne girano di più o di meno la suite esce 2 (un caso
# saltato da root conta come girato).
#
# Uso:    m2_prompting_avanzato/_docente/test_m2_d04.sh
# Uscita: 0 = tutti i casi passano · 1 = almeno un caso fallito · 2 =
#         precondizione (manca python3 o shellcheck, o la cartella
#         dell'elemento), o un numero di casi diverso da CASES
set -uo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly MOD="${SELF%/_docente/*}"
D04="${MOD}/s1_progettare_il_prompt/m2_5_esempi"
D04+="/M2-D04_zero_shot_few_shot"
readonly D04
readonly CASES=141
readonly T=$'\t'
readonly NA='—'
FINE='Fatto: ogni affermazione è stata messa alla prova;'
FINE+=' gli esiti sono qui sopra.'
readonly FINE
readonly PARTENZA='Manca la cartella risposte/: eseguite i passi del README.'
readonly OGGETTO='{"categoria": "lentezza", "priorita": "media", "team": "noc"}'
FUORI='{"categoria": "backup_lento", "priorita": "media",'
FUORI+=' "team": "noc"}'
readonly FUORI
GARANZIA='La documentazione garantisce un output JSON convalidato sullo'
GARANZIA+=' schema: in questa esecuzione no.'
readonly GARANZIA
TMP=''
PASS=0
FAIL=0
SKIP=0
RC=0
OUT=''

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

# Un nuovo spazio di lavoro: una copia di demo/.
# Arguments: $1 la variabile da assegnare.
ws() {
  local __w
  __w="$(mktemp -d "${TMP}/ws.XXXXXX")" || { echo "mktemp" >&2; exit 2; }
  cp -R "${D04}/demo/." "${__w}/" || exit 2
  printf -v "$1" '%s' "${__w}"
}

# Scrive in risposte/ il JSON di una risposta riuscita di claude -p.
# Arguments: $1 lo spazio di lavoro, $2 il file (per esempio
# few-shot-haiku.json), $3 result, poi facoltativi chiave=JSON che
# aggiungono o cambiano un campo (chiave=- lo toglie).
risposta() {
  python3 -B -I - "$@" <<'PY'
import json, os, sys
ws, nome, testo = sys.argv[1:4]
doc = {"type": "result", "subtype": "success", "is_error": False,
       "result": testo, "usage": {"input_tokens": 9, "output_tokens": 5},
       "modelUsage": {"claude-finto": {}}}
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

# La risposta con --json-schema: l'oggetto in structured_output e in
# result. Arguments: $1 lo spazio di lavoro, $2 il modello, $3 l'oggetto
# in JSON, poi altri chiave=JSON come per risposta.
oggetto() {
  risposta "$1" "schema-$2.json" "$3" "structured_output=$3" "${@:4}"
}

# Le otto risposte di un'esecuzione che conferma le tre affermazioni:
# zero-shot senza la forma, few-shot con «Classificazione:» davanti,
# con-etichette con le etichette elencate, schema con l'oggetto nell'enum.
# Arguments: $1 lo spazio di lavoro.
complete() {
  local m
  for m in haiku sonnet; do
    risposta "$1" "zero-shot-${m}.json" \
      $'**Backup | Alta | Infrastruttura**\n\nMotivo: i backup.'
    risposta "$1" "few-shot-${m}.json" \
      'Classificazione: backup_lento | media | noc'
    risposta "$1" "con-etichette-${m}.json" 'lentezza | media | noc'
    oggetto "$1" "${m}" "${OGGETTO}"
  done
}

# controlla_etichette.py nello spazio di lavoro $1, con gli argomenti che
# seguono; RC e OUT come run.
controlla() {
  local w="$1"
  shift
  OUT="$(cd "${w}" && python3 -B -I controlla_etichette.py "$@" 2>&1)"
  RC=$?
}

# Un campo della riga di un file in esiti.tsv. Arguments: $1 lo spazio di
# lavoro, $2 il file, $3 il numero del campo. Outputs: il campo.
campo() {
  awk -F'\t' -v n="$2" -v f="$3" '$1 == n { print $f }' "$1/esiti.tsv"
}

# La riga di un file in esiti.tsv è esattamente quella attesa.
# Arguments: $1 il nome del caso, $2 lo spazio di lavoro, $3 il file, poi
# i campi attesi dopo il nome del file.
expect_riga() {
  local nome="$1" w="$2" file="$3" attesa trovata
  shift 3
  attesa="$(IFS="${T}"; printf '%s' "${file}${T}$*")"
  trovata="$(awk -F'\t' -v n="${file}" '$1 == n' "${w}/esiti.tsv" \
    2>/dev/null)"
  if [[ "${trovata}" == "${attesa}" ]]; then
    pass "${nome}"
  else
    fail "${nome}: «${trovata}», attesa «${attesa}»"
  fi
}

# Le risposte complete, una cambiata, poi verifica.sh, che fa girare da
# sé il controllo: RC e OUT sono quelli di verifica.sh. Arguments: $1 la
# variabile da assegnare con lo spazio di lavoro, poi gli argomenti di
# risposta dopo lo spazio di lavoro (il file, result, chiave=JSON).
verifica_con() {
  local __v
  ws __v
  complete "${__v}"
  risposta "${__v}" "${@:2}"
  run "${D04}/verifica.sh" "${__v}"
  printf -v "$1" '%s' "${__v}"
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
sys.exit(modulo.main(sys.argv[2:]))' "${D04}/demo/controlla_etichette.py" "$@"
}

# Una copia di verifica.sh e di demo/ in cui il controllo è finto: esce
# con il codice dato, o si fa terminare da un segnale. L'albero del
# repository non cambia. Arguments: $1 la variabile da assegnare (la
# copia), $2 il codice d'uscita, oppure «segnale».
albero_finto() {
  local __a __c
  __a="$(mktemp -d "${TMP}/albero.XXXXXX")" || { echo "mktemp" >&2; exit 2; }
  if ! cp -- "${D04}/verifica.sh" "${__a}/" || ! cp -R "${D04}/demo" "${__a}/"
  then
    echo "test_m2_d04: non riesco a copiare l'elemento" >&2
    exit 2
  fi
  __c="${__a}/demo/controlla_etichette.py"
  if [[ "$2" == segnale ]]; then
    printf '%s\n' 'import os, signal' 'os.kill(os.getpid(), signal.SIGTERM)' \
      > "${__c}"
  else
    printf 'import sys\nsys.exit(%d)\n' "$2" > "${__c}"
  fi
  printf -v "$1" '%s' "${__a}"
}

# Il claude esca in ${TMP}/esca (bash: registra ogni invocazione, anche
# --version, ed esce 0); il claude finto in ${TMP}/finto (python3:
# registra ogni invocazione in JSON e risponde come claude -p
# --output-format json); ${TMP}/senza_python, un PATH con readlink e
# l'esca; ${TMP}/senza_claude, uno con readlink e python3. Esce 2 se nel
# PATH di prova il claude trovato non è il finto.
prepara_claude() {
  local t
  mkdir -p "${TMP}/esca" "${TMP}/finto" "${TMP}/senza_python" \
    "${TMP}/senza_claude" || exit 2
  # shellcheck disable=SC2016  # il corpo è dell'esca
  printf '%s\n' '#!/bin/bash' \
    'printf "invocazione %s\n" "$*" >> "${ESCA_LOG}"' \
    > "${TMP}/esca/claude" || exit 2
  cat > "${TMP}/finto/claude" <<'PY' || exit 2
#!/usr/bin/env python3
"""Il claude finto di test_m2_d04.sh: registra in FINTO_LOG gli argomenti
di ogni invocazione (JSON, una riga) e risponde come claude -p
--output-format json. FINTO_ESITO=ko: esce 1 senza stampare. Con
--json-schema: structured_output è FINTO_OGGETTO (default l'oggetto
nell'enum), tolto con FINTO_SCHEMA=assente; con FINTO_TOCCA_SCHEMA=1
toglie un'etichetta dall'enum di schema.json nella cartella corrente.
Senza: «lentezza | media | noc» se il prompt ha gli esempi, altrimenti
«Prestazioni | Media | Rete»."""
import json
import os
import sys

argv = sys.argv[1:]
with open(os.environ["FINTO_LOG"], "a", encoding="utf-8") as fh:
    fh.write(json.dumps(argv, ensure_ascii=False) + "\n")
if argv[:1] == ["--version"]:
    print("0.0.0 (il claude finto di test_m2_d04.sh)")
    sys.exit(0)
if os.environ.get("FINTO_ESITO") == "ko":
    sys.exit(1)
if "--json-schema" in argv and os.environ.get("FINTO_TOCCA_SCHEMA") == "1":
    with open("schema.json", encoding="utf-8") as fh:
        schema = json.load(fh)
    schema["properties"]["team"]["enum"].pop()
    with open("schema.json", "w", encoding="utf-8") as fh:
        json.dump(schema, fh)
prompt = ""
if "--" in argv:
    prompt = argv[argv.index("--") + 1]
elif "-p" in argv and argv.index("-p") + 1 < len(argv):
    prompt = argv[argv.index("-p") + 1]
doc = {"type": "result", "subtype": "success", "is_error": False,
       "usage": {"input_tokens": 9, "output_tokens": 5},
       "modelUsage": {"claude-finto": {}}}
if "--json-schema" in argv:
    oggetto = json.loads(os.environ.get("FINTO_OGGETTO", json.dumps(
        {"categoria": "lentezza", "priorita": "media", "team": "noc"})))
    doc["result"] = json.dumps(oggetto)
    if os.environ.get("FINTO_SCHEMA") != "assente":
        doc["structured_output"] = oggetto
elif "<examples>" in prompt:
    doc["result"] = "lentezza | media | noc"
else:
    doc["result"] = "Prestazioni | Media | Rete"
print(json.dumps(doc, ensure_ascii=False))
PY
  chmod 755 "${TMP}/esca/claude" "${TMP}/finto/claude" || exit 2
  ln -s "${TMP}/esca/claude" "${TMP}/senza_python/claude" || exit 2
  for t in readlink python3; do
    if [[ "${t}" != python3 ]]; then
      ln -s "$(command -v "${t}")" "${TMP}/senza_python/${t}" || exit 2
    fi
    ln -s "$(command -v "${t}")" "${TMP}/senza_claude/${t}" || exit 2
  done
  t="$(PATH="${TMP}/finto:${PATH}" command -v claude)"
  if [[ "${t}" != "${TMP}/finto/claude" ]]; then
    echo "test_m2_d04: nel PATH di prova claude è ${t}, non il finto" >&2
    exit 2
  fi
}

# live.sh con l'esca davanti nel PATH (o con un PATH dato); il registro
# delle invocazioni riparte vuoto. Arguments: $1 lo spazio di lavoro (o un
# percorso che non c'è), $2 facoltativo il PATH.
esca() {
  : > "${TMP}/esca.log"
  run env PATH="${2:-${TMP}/esca:${PATH}}" HANDSON_NO_PAUSE=1 \
    ESCA_LOG="${TMP}/esca.log" "${D04}/_docente/live.sh" "$1"
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

# live.sh con il claude finto davanti nel PATH; il registro riparte vuoto.
# Arguments: $1 lo spazio di lavoro, poi le variabili NOME=valore per il
# finto.
finto() {
  local w="$1"
  shift
  : > "${TMP}/finto.log"
  run env PATH="${TMP}/finto:${PATH}" HANDSON_NO_PAUSE=1 \
    FINTO_LOG="${TMP}/finto.log" "$@" "${D04}/_docente/live.sh" "${w}"
}

# Quante chiamate (non --version) ha ricevuto il finto.
# Arguments: $1 il registro.
chiamate() { grep -vc '^\["--version"\]$' "$1"; }

# --- I test ---------------------------------------------------------------

# I prompt: few-shot è zero-shot con il solo blocco degli esempi fra tag;
# con-etichette è few-shot con la regola e gli elenchi.
t_prompt() {
  run python3 -B -I - "${D04}/demo" <<'PY'
import sys
d = sys.argv[1]
z, f, c = (open("%s/%s.md" % (d, n), encoding="utf-8").read().splitlines()
           for n in ("zero-shot", "few-shot", "con-etichette"))
problemi = []
if not (f[:2] + f[12:] == z and f[2] == "<examples>" and f[11] == "</examples>"
        and f[3] == "<example>" and f[6] == "</example>"):
    problemi.append("few-shot non è zero-shot più gli esempi fra tag")
if "segui gli esempi" in "\n".join(f + c).lower():
    problemi.append("«segui gli esempi» c'è ancora")
if not (c[0] == f[0] + " Usa solo le etichette elencate." and c[1] == ""
        and c[2].startswith("Categorie: ") and c[3].startswith("Priorità: ")
        and c[4].startswith("Team: ") and c[5] == "" and c[6:] == f[2:]):
    problemi.append("con-etichette non è few-shot più la regola e gli elenchi")
print("; ".join(problemi) or "una cosa sola per variante")
PY
  expect "i prompt: una cosa sola cambiata per variante" 0 \
    "una cosa sola per variante"
}

# controlla_etichette.py su risposte complete: l'intestazione, le righe,
# ogni variante.
t_colonne() {
  local w intestazione
  intestazione="file${T}forma_esempi${T}etichette_ammesse${T}oggetto_schema"
  intestazione+="${T}scelta"
  ws w
  complete "${w}"
  controlla "${w}"
  expect "controlla: risposte complete, uscita 0" 0 "Scritto esiti.tsv."
  expect "controlla: i dati e i verdetti, come li stampa la verifica" 0 \
    "Con --json-schema, l'oggetto rispetta lo schema (sonnet): confermata"
  expect_absent "controlla: senza la frase finale, che è della verifica" \
    "Fatto:"
  if [[ "$(head -n 1 "${w}/esiti.tsv")" == "${intestazione}" ]]; then
    pass "controlla: l'intestazione di esiti.tsv"
  else fail "controlla: intestazione «$(head -n 1 "${w}/esiti.tsv")»"; fi
  if (( $(wc -l < "${w}/esiti.tsv") == 9 )); then
    pass "controlla: otto righe e l'intestazione"
  else fail "controlla: $(wc -l < "${w}/esiti.tsv") righe in esiti.tsv"; fi
  expect_riga "controlla: zero-shot senza la forma, la risposta su una riga" \
    "${w}" zero-shot-haiku.json no "${NA}" "${NA}" \
    '**Backup | Alta | Infrastruttura** Motivo: i backup.'
  expect_riga "controlla: few-shot con «Classificazione:» davanti" "${w}" \
    few-shot-haiku.json sì "${NA}" "${NA}" 'backup_lento | media | noc'
  expect_riga "controlla: con-etichette con le etichette elencate" "${w}" \
    con-etichette-sonnet.json sì sì "${NA}" 'lentezza | media | noc'
  expect_riga "controlla: schema con l'oggetto nell'enum" "${w}" \
    schema-sonnet.json "${NA}" "${NA}" sì 'lentezza | media | noc'
}

# forma_esempi di few-shot di haiku per una risposta.
# Arguments: $1 lo spazio di lavoro, $2 il caso, $3 la risposta, $4 la
# forma attesa.
forma_caso() {
  local trovata
  risposta "$1" few-shot-haiku.json "$3"
  controlla "$1"
  trovata="$(campo "$1" few-shot-haiku.json 2)"
  if (( RC == 0 )) && [[ "${trovata}" == "$4" ]]; then
    pass "forma_esempi: $2 dà $4"
  else
    fail "forma_esempi: $2 (rc=${RC}, «${trovata}», atteso «$4»)"
  fi
}

# forma_esempi: i casi limite della forma degli esempi.
t_forma() {
  local w
  ws w
  complete "${w}"
  forma_caso "${w}" "il grassetto" '**backup_lento | media | noc**' no
  forma_caso "${w}" "una seconda riga" \
    $'backup_lento | media | noc\nMotivo: il backup.' no
  forma_caso "${w}" "una maiuscola" 'Backup_lento | media | noc' no
  forma_caso "${w}" "«Classificazione:» su una riga a sé" \
    $'Classificazione:\nbackup_lento | media | noc' no
  forma_caso "${w}" "uno spazio in più" 'backup_lento |  media | noc' no
  forma_caso "${w}" "un punto in fondo" 'backup_lento | media | noc.' no
  forma_caso "${w}" "gli spazi intorno" $'  backup_lento | media | noc \n' sì
}

# etichette_ammesse: solo per con-etichette, e solo con la forma.
t_etichette() {
  local w
  ws w
  complete "${w}"
  risposta "${w}" con-etichette-haiku.json 'backup_lento | media | noc'
  risposta "${w}" con-etichette-sonnet.json 'Lentezza | Media | NOC'
  risposta "${w}" few-shot-sonnet.json 'lentezza | media | noc'
  controlla "${w}"
  expect "etichette: le risposte si leggono" 0 \
    "haiku, con-etichette: forma_esempi sì, etichette_ammesse no;"
  expect_riga "etichette: una categoria fuori dall'elenco dà no" "${w}" \
    con-etichette-haiku.json sì no "${NA}" 'backup_lento | media | noc'
  expect_riga "etichette: senza la forma non si giudicano" "${w}" \
    con-etichette-sonnet.json no "${NA}" "${NA}" 'Lentezza | Media | NOC'
  expect_riga "etichette: few-shot non ha l'elenco, solo la scelta" "${w}" \
    few-shot-sonnet.json sì "${NA}" "${NA}" 'lentezza | media | noc'
}

# oggetto_schema di haiku per un oggetto, e l'uscita del controllo: 0 se
# l'oggetto rispetta lo schema, 1 se no o se manca (la garanzia non
# confermata, una chiamata fallita). Arguments: $1 lo spazio di lavoro, $2
# il caso, $3 il valore atteso, $4 la scelta attesa, poi gli argomenti di
# oggetto dopo il modello.
schema_caso() {
  local w="$1" caso="$2" atteso="$3" scelta="$4" uscita=1
  shift 4
  if [[ "${atteso}" == sì ]]; then uscita=0; fi
  oggetto "${w}" haiku "$@"
  controlla "${w}"
  if (( RC != uscita )); then
    fail "oggetto_schema: ${caso} (rc=${RC}, attesa ${uscita}): ${OUT:0:300}"
    return 0
  fi
  expect_riga "oggetto_schema: ${caso} dà ${atteso}" "${w}" \
    schema-haiku.json "${NA}" "${NA}" "${atteso}" "${scelta}"
}

# oggetto_schema: ogni valore, anche con una maiuscola (la documentazione
# non le garantisce) e per una chiamata senza oggetto.
t_schema() {
  local w
  ws w
  complete "${w}"
  schema_caso "${w}" "una maiuscola, confrontata senza badarci" sì \
    'Lentezza | MEDIA | noc' \
    '{"categoria": "Lentezza", "priorita": "MEDIA", "team": "noc"}'
  schema_caso "${w}" "un valore fuori dall'enum" no \
    'backup_lento | media | noc' \
    '{"categoria": "backup_lento", "priorita": "media", "team": "noc"}'
  schema_caso "${w}" "una chiave che manca" no "lentezza | media | ${NA}" \
    '{"categoria": "lentezza", "priorita": "media"}'
  schema_caso "${w}" "una chiave in più" no 'lentezza | media | noc' \
    '{"categoria": "lentezza", "priorita": "media", "team": "noc", "x": "y"}'
  schema_caso "${w}" "un valore che non è una stringa" no \
    '(non è una stringa) | media | noc' \
    '{"categoria": 3, "priorita": "media", "team": "noc"}'
  schema_caso "${w}" "un elenco al posto dell'oggetto" no \
    '(non è un oggetto)' '["lentezza", "media", "noc"]'
  schema_caso "${w}" "structured_output che manca" assente "${NA}" \
    "${OGGETTO}" 'structured_output=-'
  schema_caso "${w}" "structured_output null" assente "${NA}" \
    "${OGGETTO}" 'structured_output=null'
  schema_caso "${w}" "is_error" assente "${NA}" "${OGGETTO}" 'is_error=true'
  schema_caso "${w}" "subtype di errore" assente "${NA}" "${OGGETTO}" \
    'subtype="error_max_structured_output_retries"'
}

# Cambia l'enum di un campo in uno schema.json: «togli» ne toglie l'ultima
# etichetta, «scambia» scambia le prime due. Arguments: $1 il file, $2 il
# campo, $3 togli o scambia.
cambia_enum() {
  python3 -B -I - "$@" <<'PY'
import json, sys
percorso, campo, come = sys.argv[1:4]
with open(percorso, encoding="utf-8") as fh:
    schema = json.load(fh)
enum = schema["properties"][campo]["enum"]
if come == "togli":
    enum.pop()
else:
    enum[0], enum[1] = enum[1], enum[0]
with open(percorso, "w", encoding="utf-8") as fh:
    json.dump(schema, fh, ensure_ascii=False, indent=2)
PY
}

# Una risposta rovinata: uscita 1, la parola attesa, nessun traceback.
# Arguments: $1 lo spazio di lavoro, $2 il caso, $3 la parola.
rovinata() {
  controlla "$1"
  expect "rovinata: $2" 1 "$3"
  expect_absent "rovinata: $2, senza traceback" "Traceback"
}

# Le risposte rovinate: uscita 1, esiti.tsv con le righe delle altre.
t_rovinate() {
  local w
  ws w
  complete "${w}"
  rm "${w}/risposte/few-shot-sonnet.json"
  rovinata "${w}" "un file che manca" "manca risposte/few-shot-sonnet.json"
  if (( $(wc -l < "${w}/esiti.tsv") == 8 )) \
      && [[ -z "$(campo "${w}" few-shot-sonnet.json 1)" ]]; then
    pass "rovinata: esiti.tsv ha le righe delle altre sette"
  else fail "rovinata: esiti.tsv dopo un file che manca"; fi
  : > "${w}/risposte/few-shot-sonnet.json"
  rovinata "${w}" "un file vuoto" "è vuoto"
  printf 'non json' > "${w}/risposte/few-shot-sonnet.json"
  rovinata "${w}" "un testo che non è JSON" "non è il JSON di claude -p"
  printf '[1, 2]' > "${w}/risposte/few-shot-sonnet.json"
  rovinata "${w}" "un elenco JSON" "non è il JSON di claude -p"
  python3 -B -I -c 'import sys; open(sys.argv[1], "w").write("[" * 100000)' \
    "${w}/risposte/few-shot-sonnet.json"
  rovinata "${w}" "un JSON annidato a dismisura" "non è il JSON di claude -p"
  printf '\xff\xfe{' > "${w}/risposte/few-shot-sonnet.json"
  rovinata "${w}" "byte che non sono UTF-8" "non è il JSON di claude -p"
  risposta "${w}" few-shot-sonnet.json 'x' 'is_error=true'
  rovinata "${w}" "is_error" "claude ha restituito un errore"
  risposta "${w}" few-shot-sonnet.json 'x' 'result=-'
  rovinata "${w}" "senza result" "manca la risposta"
  risposta "${w}" few-shot-sonnet.json 'x' 'result=42'
  rovinata "${w}" "result che non è un testo" "manca la risposta"
  risposta "${w}" few-shot-sonnet.json '   '
  rovinata "${w}" "result vuoto" "manca la risposta"
  risposta "${w}" few-shot-sonnet.json 'backup_lento | media | noc'
  printf 'x' > "${w}/risposte/schema-haiku.json"
  rovinata "${w}" "lo schema, un testo che non è JSON" \
    "risposte/schema-haiku.json non è il JSON di claude -p"
}

# Le precondizioni di controlla_etichette.py: uscita 2, e nessun esiti.tsv
# vecchio resta; la cartella risposte/ che manca: uscita 1.
t_precondizioni() {
  local w
  ws w
  printf 'vecchio\n' > "${w}/esiti.tsv"
  controlla "${w}"
  expect "senza risposte/: uscita 1" 1 "${PARTENZA}"
  if [[ ! -e "${w}/esiti.tsv" ]]; then
    pass "senza risposte/: l'esiti.tsv vecchio è tolto"
  else fail "senza risposte/: l'esiti.tsv vecchio è rimasto"; fi
  ws w
  complete "${w}"
  controlla "${w}" --boh
  expect "precondizione: un argomento sconosciuto" 2 "Uso:"
  controlla "${w}" --solo-schema --boh
  expect "precondizione: due argomenti" 2 "Uso:"
  controlla "${w}" . .
  expect "precondizione: due spazi di lavoro" 2 \
    "uno spazio di lavoro per volta"
  controlla "${w}" "${TMP}/assente"
  expect "precondizione: uno spazio di lavoro che non c'è" 2 \
    "spazio di lavoro assente: ${TMP}/assente"
  controlla "${w}"
  cambia_enum "${w}/schema.json" categoria togli
  controlla "${w}"
  expect "precondizione: un'etichetta che manca nell'enum" 2 \
    "l'enum di «categoria» è diverso dall'elenco «Categorie:» di"
  expect_absent "precondizione: nessuna risposta letta" "zero-shot-haiku"
  if [[ ! -e "${w}/esiti.tsv" ]]; then
    pass "precondizione: l'esiti.tsv vecchio è tolto"
  else fail "precondizione: l'esiti.tsv vecchio è rimasto"; fi
  cp "${D04}/demo/schema.json" "${w}/schema.json"
  cambia_enum "${w}/schema.json" priorita scambia
  controlla "${w}"
  expect "precondizione: l'enum in un altro ordine" 2 "l'enum di «priorita»"
  printf '{"properties": []}' > "${w}/schema.json"
  controlla "${w}"
  expect "precondizione: properties non è un oggetto" 2 "attesi «properties»"
  printf '{"properties": {"team": {"enum": null}}}' > "${w}/schema.json"
  controlla "${w}"
  expect "precondizione: un enum che non è un elenco" 2 "attesi «properties»"
  printf '{"properties": ' > "${w}/schema.json"
  controlla "${w}"
  expect "precondizione: schema.json non è JSON" 2 \
    "schema.json non è un JSON valido"
  expect_absent "precondizione: schema.json rovinato, senza traceback" \
    "Traceback"
  rm "${w}/schema.json"
  controlla "${w}"
  expect "precondizione: schema.json che manca" 2 "manca schema.json"
  cp "${D04}/demo/schema.json" "${w}/schema.json"
  sed -i '/^Team: /d' "${w}/con-etichette.md"
  controlla "${w}"
  expect "precondizione: con-etichette.md senza la riga Team:" 2 \
    "attesa una riga «Team: …», trovate 0"
  cp "${D04}/demo/con-etichette.md" "${w}/con-etichette.md"
  sed -i 's/^Priorità: .*/&\n&/' "${w}/con-etichette.md"
  controlla "${w}"
  expect "precondizione: due righe Priorità:" 2 "trovate 2"
  rm "${w}/con-etichette.md"
  controlla "${w}"
  expect "precondizione: con-etichette.md che manca" 2 \
    "manca con-etichette.md"
  cp "${D04}/demo/con-etichette.md" "${w}/con-etichette.md"
  rm -f "${w}/esiti.tsv"
  mkdir "${w}/esiti.tsv"
  controlla "${w}"
  expect "precondizione: esiti.tsv che non si scrive" 2 \
    "esiti.tsv non si scrive"
  rmdir "${w}/esiti.tsv"
  printf 'vecchio\n' > "${w}/esiti.tsv"
  inatteso --senza-esiti "${w}"
  expect "precondizione: un errore inatteso esce 2, senza traceback" 2 \
    "errore inatteso (RuntimeError: guasto finto)"
  if [[ "$(cat "${w}/esiti.tsv")" == vecchio ]]; then
    pass "--senza-esiti: l'esiti.tsv vecchio resta com'è"
  else fail "--senza-esiti: esiti.tsv è cambiato"; fi
  inatteso "${w}"
  if [[ ! -e "${w}/esiti.tsv" ]]; then
    pass "precondizione: l'errore inatteso toglie l'esiti.tsv vecchio"
  else fail "precondizione: dopo l'errore inatteso esiti.tsv è rimasto"; fi
  if (( EUID == 0 )); then
    skip "precondizione: una risposta che non si legge (da root si legge)"
    skip "precondizione: senza la risposta che non si legge, nessun esiti.tsv"
    return 0
  fi
  controlla "${w}"
  chmod 000 "${w}/risposte/zero-shot-haiku.json"
  controlla "${w}"
  expect "precondizione: una risposta che non si legge" 2 \
    "risposte/zero-shot-haiku.json non si legge"
  if [[ ! -e "${w}/esiti.tsv" ]]; then
    pass "precondizione: una risposta che non si legge, nessun esiti.tsv"
  else fail "precondizione: con una risposta illeggibile esiti.tsv resta"; fi
}

# --solo-schema: soltanto gli enum contro gli elenchi, senza risposte.
t_solo_schema() {
  local w
  ws w
  controlla "${w}" --solo-schema
  expect "--solo-schema: gli enum di demo/ sono gli elenchi" 0 \
    "gli enum sono uguali agli elenchi di con-etichette.md"
  if [[ ! -e "${w}/esiti.tsv" ]]; then
    pass "--solo-schema: non scrive esiti.tsv"
  else fail "--solo-schema: ha scritto esiti.tsv"; fi
  sed -i 's/"noc",/"nOc",/' "${w}/schema.json"
  controlla "${w}" --solo-schema
  expect "--solo-schema: un enum diverso" 2 "l'enum di «team»"
}

# verifica.sh: le uscite di base e le risposte complete. Nessun caso lancia
# prima controlla_etichette.py: la verifica fa girare da sé il controllo
# di demo/, e non scrive esiti.tsv.
t_verifica_base() {
  local w n
  run "${D04}/verifica.sh" "${TMP}/assente"
  expect "verifica: spazio di lavoro assente" 2 "spazio di lavoro assente"
  ws w
  run "${D04}/verifica.sh" "${w}"
  expect "verifica: il punto di partenza" 1 "${PARTENZA}"
  complete "${w}"
  run "${D04}/verifica.sh" "${w}"
  expect "verifica: risposte complete e confermate" 0 "${FINE}"
  if [[ "${OUT##*$'\n'}" == "${FINE}" ]]; then
    pass "verifica: la frase finale è l'ultima riga"
  else fail "verifica: l'ultima riga è «${OUT##*$'\n'}»"; fi
  n="$(grep -c ': confermata$' <<< "${OUT}")"
  if (( n == 6 )); then
    pass "verifica: tre affermazioni confermate per due modelli"
  else fail "verifica: ${n} righe «confermata», attese 6"; fi
  expect "verifica: i dati di few-shot" 0 \
    "haiku, few-shot: forma_esempi sì; scelta: backup_lento | media | noc"
  expect "verifica: i dati dello schema" 0 \
    "sonnet, schema: oggetto_schema sì; scelta: lentezza | media | noc"
  if [[ ! -e "${w}/esiti.tsv" ]]; then
    pass "verifica: non scrive esiti.tsv"
  else fail "verifica: ha scritto esiti.tsv"; fi
  if (( EUID == 0 )); then
    skip "verifica: una risposta che non si legge (da root si legge)"
    return 0
  fi
  chmod 000 "${w}/risposte/schema-haiku.json"
  run "${D04}/verifica.sh" "${w}"
  expect "verifica: una risposta che non si legge" 2 \
    "risposte/schema-haiku.json non si legge"
}

# verifica.sh: ogni verdetto delle tre affermazioni.
t_verdetti() {
  local w
  verifica_con w zero-shot-haiku.json 'backup_lento | alta | noc'
  expect "esempi: la forma c'è già senza esempi, non fallisce" 0 \
    "Gli esempi orientano il formato (haiku): non distinguibile ("
  verifica_con w few-shot-sonnet.json 'Backup Lento | Media | NOC'
  expect "esempi: con gli esempi la forma manca, non fallisce" 0 \
    "Gli esempi orientano il formato (sonnet): non confermata in questa"
  risposta "${w}" zero-shot-sonnet.json 'backup_lento | alta | noc'
  run "${D04}/verifica.sh" "${w}"
  expect "esempi: manca con gli esempi e c'è senza, non confermata" 0 \
    "Gli esempi orientano il formato (sonnet): non confermata in questa"
  verifica_con w con-etichette-haiku.json 'backup_lento | media | noc'
  expect "elenco: un'etichetta fuori dall'elenco, non fallisce" 0 \
    "forma ed etichette rispettate (haiku): non confermata in questa"
  verifica_con w con-etichette-sonnet.json '**lentezza | media | noc**'
  expect "elenco: senza la forma, non fallisce" 0 \
    "forma ed etichette rispettate (sonnet): non confermata in questa"
  verifica_con w schema-haiku.json "${OGGETTO}" "structured_output=${FUORI}"
  expect "schema: un valore fuori dall'enum fa fallire" 1 "${GARANZIA}"
  expect "schema: il verdetto non confermata" 1 \
    "l'oggetto rispetta lo schema (haiku): non confermata in questa"
  expect_absent "schema: nessuna frase finale" "Fatto:"
  verifica_con w schema-sonnet.json "${OGGETTO}" 'structured_output=-'
  expect "schema: un oggetto assente è una chiamata fallita" 1 \
    "l'oggetto rispetta lo schema (sonnet): chiamata fallita"
  expect_absent "schema: la chiamata fallita non è una smentita" \
    "La documentazione garantisce"
}

# verifica.sh decide dalle risposte, mai da esiti.tsv: una risposta che
# manca (1); risposte/ tolta con un esiti.tsv vecchio (1); un esiti.tsv
# tutto confermato, con un oggetto fuori dall'enum (1); un enum cambiato
# (2: la verifica non è verde); python3 che manca (2); un controllo che
# esce con un codice fuori dal contratto, o per un segnale (2).
t_verifica_rovinata() {
  local w a
  ws w
  complete "${w}"
  rm "${w}/risposte/few-shot-sonnet.json"
  run "${D04}/verifica.sh" "${w}"
  expect "verifica: una risposta che manca" 1 \
    "manca risposte/few-shot-sonnet.json: rifate quella chiamata"
  expect_absent "verifica: senza few-shot nessun verdetto sugli esempi" \
    "Gli esempi orientano il formato (sonnet)"
  expect "verifica: gli altri verdetti si danno" 1 \
    "l'oggetto rispetta lo schema (sonnet): confermata"
  ws w
  complete "${w}"
  controlla "${w}"
  rm -r "${w}/risposte"
  run "${D04}/verifica.sh" "${w}"
  expect "verifica: risposte/ tolta, con un esiti.tsv vecchio" 1 \
    "${PARTENZA}"
  expect_absent "verifica: risposte/ tolta, nessuna frase finale" "Fatto:"
  ws w
  complete "${w}"
  controlla "${w}"
  oggetto "${w}" haiku "${OGGETTO}" "structured_output=${FUORI}"
  run "${D04}/verifica.sh" "${w}"
  expect "verifica: un esiti.tsv tutto confermato non conta" 1 \
    "${GARANZIA}"
  ws w
  complete "${w}"
  controlla "${w}"
  cambia_enum "${w}/schema.json" team togli
  run "${D04}/verifica.sh" "${w}"
  expect "verifica: un enum cambiato, uscita 2" 2 "l'enum di «team»"
  expect_absent "verifica: un enum cambiato, nessuna frase finale" "Fatto:"
  ws w
  complete "${w}"
  run env PATH="${TMP}/senza_python" "${D04}/verifica.sh" "${w}"
  expect "verifica: python3 che manca, uscita 2" 2 "manca python3"
  albero_finto a 3
  run "${a}/verifica.sh" "${w}"
  expect "verifica: un controllo che esce con 3, uscita 2" 2 \
    "controlla_etichette.py è uscito con 3"
  albero_finto a segnale
  run "${a}/verifica.sh" "${w}"
  expect "verifica: un controllo terminato da un segnale, uscita 2" 2 \
    "controlla_etichette.py è uscito con 143"
}

# live.sh: le precondizioni escono 2 prima di ogni invocazione di claude.
t_live_precondizioni() {
  local w f
  precondizione "live: spazio di lavoro assente" "spazio di lavoro assente" \
    "${TMP}/assente"
  for f in few-shot.md schema.json istruzione.txt controlla_etichette.py; do
    ws w
    rm "${w}/${f}"
    precondizione "live: ${f} che manca" "file assente o illeggibile: ${f}" \
      "${w}"
  done
  ws w
  sed -i 's/"urgente"/"critica"/' "${w}/schema.json"
  precondizione "live: un enum diverso dal suo elenco" \
    "non vanno d'accordo" "${w}"
  ws w
  precondizione "live: python3 che manca" "manca lo strumento: python3" \
    "${w}" "${TMP}/senza_python"
  ws w
  esca "${w}" "${TMP}/senza_claude"
  expect "live: claude che manca" 2 "manca lo strumento: claude"
}

# live.sh con il claude finto: le otto chiamate, gli stessi testi e le
# stesse opzioni del passo 3 del README, i verdetti a schermo.
t_live_finto() {
  local w r w2
  ws w
  finto "${w}"
  expect "live: le risposte complete escono 0" 0 "VERIFICA OK"
  expect "live: i verdetti si vedono anche quando passa" 0 "${FINE}"
  expect "live: il verdetto sugli esempi" 0 \
    "Gli esempi orientano il formato (haiku): confermata"
  # Il controllo scrive esiti.tsv in silenzio: i verdetti, una volta sola.
  r="$(grep -cF 'Gli esempi orientano il formato (haiku): confermata' \
    <<< "${OUT}")"
  if (( r == 1 )); then pass "live: i verdetti si vedono una volta sola"
  else fail "live: il verdetto sugli esempi si vede ${r} volte"; fi
  r="$(chiamate "${TMP}/finto.log")"
  if (( r == 8 )); then pass "live: otto chiamate"
  else fail "live: ${r} chiamate, attese 8"; fi
  r="$(command find "${w}/risposte" -name '*.json' | wc -l)"
  if (( r == 8 )) && (( $(wc -l < "${w}/esiti.tsv") == 9 )); then
    pass "live: otto file in risposte/ e otto righe in esiti.tsv"
  else fail "live: ${r} file in risposte/"; fi
  cp "${TMP}/finto.log" "${TMP}/live.log"
  ws w2
  if ! blocco_readme "${TMP}/passo3.sh"; then
    fail "README: il blocco del passo 3 non c'è"
    return 0
  fi
  : > "${TMP}/readme.log"
  ( cd "${w2}" && PATH="${TMP}/finto:${PATH}" \
      FINTO_LOG="${TMP}/readme.log" bash "${TMP}/passo3.sh" )
  run python3 -B -I - "${w}" "${TMP}/live.log" "${TMP}/readme.log" \
    <<'PY'
import json, sys
ws, log_live, log_readme = sys.argv[1:4]
VALORE = {"--model", "--effort", "--tools", "--system-prompt",
          "--output-format", "--json-schema", "--setting-sources",
          "--permission-mode", "--permission-prompts", "--allowedTools"}

def chiamate(log):
    righe = [json.loads(r) for r in open(log, encoding="utf-8")]
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

def leggi(nome):
    return open("%s/%s" % (ws, nome), encoding="utf-8").read().rstrip("\n")

attese = []
for m in ("haiku", "sonnet"):
    for v in ("zero-shot", "few-shot", "con-etichette"):
        attese.append((m, leggi(v + ".md"), None))
    attese.append((m, leggi("con-etichette.md"), leggi("schema.json")))
live, readme = chiamate(log_live), chiamate(log_readme)
problemi = []
if len(live) != 8 or len(readme) != 8:
    problemi.append("chiamate: live.sh %d, README %d" % (len(live),
                                                        len(readme)))
fisse = (("--tools", ""), ("--effort", "low"),
         ("--system-prompt", "Rispondi in italiano."),
         ("--output-format", "json"), ("--setting-sources", "project,local"))
for i, (cl, cr, (m, testo, schema)) in enumerate(zip(live, readme, attese)):
    pl, ol = analizza(cl)
    pr, orr = analizza(cr)
    if pl != testo or pr != testo:
        problemi.append("chiamata %d: il prompt" % (i + 1))
    if ol.get("--model") != m or ol.get("--json-schema") != schema:
        problemi.append("chiamata %d: modello o schema" % (i + 1))
    for chiave, valore in list(orr.items()) + list(fisse):
        if ol.get(chiave) != valore:
            problemi.append("chiamata %d: %s" % (i + 1, chiave))
    for chiave in ("-p", "--strict-mcp-config", "--no-session-persistence"):
        if ol.get(chiave) is not True:
            problemi.append("chiamata %d: %s" % (i + 1, chiave))
print("; ".join(problemi) or "stesse chiamate")
PY
  expect "live e README: stessi testi e stesse opzioni, lo schema in V4" 0 \
    "stesse chiamate"
}

# Il blocco di codice del passo 3 del README, senza il rientro, in un
# file. Arguments: $1 il file. Returns: 0; 1 se il blocco non c'è.
blocco_readme() {
  python3 -B -I - "${D04}/README.md" "$1" <<'PY'
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

# live.sh con il claude finto: una chiamata fallita, la garanzia non
# confermata, la chiamata con lo schema senza oggetto.
t_live_esiti() {
  local w r
  ws w
  finto "${w}" FINTO_ESITO=ko
  r="$(chiamate "${TMP}/finto.log")"
  if (( RC == 1 && r == 1 )) && grep -qF 'VERIFICA KO' <<< "${OUT}"; then
    pass "live: si ferma alla prima chiamata fallita"
  else fail "live: rc=${RC} dopo ${r} chiamate: ${OUT:0:300}"; fi
  ws w
  finto "${w}" FINTO_OGGETTO="${FUORI}"
  expect "live: un oggetto fuori dall'enum esce 1" 1 "${GARANZIA}"
  expect "live: e il verdetto KO del controllo" 1 "(uscita 1)"
  ws w
  finto "${w}" FINTO_SCHEMA=assente
  expect "live: la chiamata con lo schema senza oggetto esce 1" 1 \
    "chiamata fallita"
  ws w
  finto "${w}" FINTO_TOCCA_SCHEMA=1
  expect "live: controlla_etichette.py che esce 2 è una precondizione" 2 \
    "controlla_etichette.py: le otto risposte (uscita 2)"
}

# Gli script di M2-D04 e questo file, con shellcheck -x.
t_shellcheck() {
  local f
  for f in "${D04}/verifica.sh" "${D04}/_docente/live.sh" "${SELF}"; do
    if shellcheck -x "${f}" > /dev/null 2>&1; then
      pass "shellcheck ${f#"${MOD%/*}"/}"
    else
      fail "shellcheck ${f#"${MOD%/*}"/}"
    fi
  done
}

main() {
  local t
  for t in python3 shellcheck; do
    command -v "${t}" >/dev/null 2>&1 \
      || { echo "test_m2_d04: manca ${t}" >&2; exit 2; }
  done
  [[ -d "${D04}" ]] || { echo "test_m2_d04: manca ${D04}" >&2; exit 2; }
  TMP="$(mktemp -d)" || exit 2
  trap 'chmod -R u+rwX "${TMP}" 2>/dev/null; rm -rf "${TMP}"' EXIT
  prepara_claude
  t_prompt
  t_colonne
  t_forma
  t_etichette
  t_schema
  t_rovinate
  t_precondizioni
  t_solo_schema
  t_verifica_base
  t_verdetti
  t_verifica_rovinata
  t_live_precondizioni
  t_live_finto
  t_live_esiti
  t_shellcheck
  echo "PASS=${PASS} FAIL=${FAIL} SKIP=${SKIP}"
  if (( PASS + FAIL + SKIP != CASES )); then
    echo "test_m2_d04: girati $((PASS + FAIL + SKIP)) casi, attesi" \
      "${CASES}" >&2
    exit 2
  fi
  (( FAIL == 0 )) || exit 1
}

main "$@"
