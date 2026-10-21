#!/bin/bash
#
# test_m1_script.sh -- le prove degli script del modulo 1, per il docente
# (sta in _docente/, il materiale del docente, che resta fuori dalla copia
# senza soluzioni di tools/esporta_studenti.sh):
#   - i sei verifica.sh: spazio di lavoro assente e file che non si legge
#     (uscita 2, saltata da root), la soluzione dell'elemento (0, senza
#     segnalazioni), i casi da segnalare (1) e quelli limite: a capo CRLF,
#     numeri con lo zero davanti, il trattino U+2011, la linea scritta in
#     minuscolo, l'intestazione di M1-D04 con un BOM, un suo conteggio di
#     30 cifre (1, mai l'aritmetica di bash); in M1-D02 il verso
#     della differenza è un dato, non l'uscita; nessuna riga oltre le 80
#     colonne; i controlli delle demo ricostruite hanno le loro suite
#     (test_m1_d01_d02_e01.sh, test_m1_d03.sh, test_m1_d05.sh);
#   - verifica.py di M1-E01: un JSON con errore, senza modelUsage o con una
#     durata non numerica, numeri della tabella diversi dal JSON, una
#     colonna in più; «Haiku 4.5» e «5,6 sec» accettati;
#   - leggi_json.py: le quattro copie identiche, JSON vuoto, non valido,
#     annidato oltre il limite di Python o non oggetto (1), uso sbagliato
#     (2), token null contati come zero, un «usage» senza nessuno dei tre
#     campi dei token in entrata (1);
#   - il claude finto legge gli argomenti come la CLI vera: le opzioni,
#     poi «--» e il prompt; un prompt che comincia con «-» passato prima
#     di «--» è un'opzione sconosciuta (uscita 1);
#   - i sei _docente/live.sh con il claude finto: una precondizione di
#     handson::claude_p esce 2 senza chiamare claude, una chiamata fallita
#     esce 1, le risposte complete escono 0; su un esito diverso M1-D04
#     stampa il messaggio di verifica.sh; M1-D02 e M1-D04 lasciano l'esito
#     alla loro verifica.sh: M1-D02 va KO con token uguali (pesi zero, da
#     rifare) e OK con i token presi dai byte del prompt; un prompt che
#     comincia con «-» arriva a claude;
#   - il live.sh di M1-E01 con una verifica.sh finta, in una copia
#     dell'elemento: se la verifica esce 2 la prova esce 2 (una
#     precondizione), se esce 1 resta un KO, se esce 0 passa e ne stampa
#     l'uscita;
#   - il manifest.tsv del modulo: la cartella e il deck_path di ogni
#     elemento sono quelli della sua riga;
#   - shellcheck -x su ogni script del modulo e su questo.
# Gli spazi di lavoro nascono in una cartella temporanea: l'albero del
# repository non cambia. Il numero di prove eseguite (anche quelle
# saltate) deve essere CASES.
#
# Uso:    m1_fondamenti_llm/_docente/test_m1_script.sh
# Uscita: 0 = tutte le prove passano · 1 = almeno una fallita
#         2 = precondizione (manca jq, python3, shellcheck o sha256sum,
#             o la cartella di un elemento), oppure le prove eseguite non
#             sono CASES
set -uo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly MOD="${SELF%/_docente/*}"
readonly S1="${MOD}/s1_fondamenti_llm"
readonly D01="${S1}/m1_2_cosa_fanno_leggono_imparano/M1-D01_prossima_parola"
readonly D02="${S1}/m1_3_token_e_contesto/M1-D02_token_lingue"
readonly D03="${S1}/m1_3_token_e_contesto/M1-D03_conta_lettere"
readonly D04="${S1}/m1_3_token_e_contesto/M1-D04_senza_memoria"
readonly D05="${S1}/m1_4_forze_e_limiti/M1-D05_circolare"
readonly E01="${S1}/m1_e2_stesso_prompt_tre_modelli/M1-E01_stesso_prompt"
readonly ELEMENTI=("${D01}" "${D02}" "${D03}" "${D04}" "${D05}" "${E01}")
readonly CASES=111
# Per ogni elemento, nello stesso ordine: il file dei risultati, la frase
# della verifica riuscita, una parola delle sue segnalazioni.
readonly FATTO='Fatto: ogni affermazione è stata messa alla prova'
readonly DATI=(risultati.tsv conteggi.tsv conteggi.tsv catena.tsv
  risposte confronto.md)
readonly OK_PAROLE=("${FATTO}" "${FATTO}" "${FATTO}" "${FATTO}" "${FATTO}"
  "${FATTO}")
readonly KO_PAROLE=('Nessuna risposta' 'Da rifare' 'non confermata'
  'in questa esecuzione no' 'Da completare' 'Da sistemare')
readonly LJ="${D02}/demo/leggi_json.py"
readonly T=$'\t'
readonly U2011=$'\xe2\x80\x91'
RISPOSTA='{"type":"result","is_error":false,"result":"Ciao",'
RISPOSTA+='"session_id":"sessione-finta","usage":{"input_tokens":3,'
RISPOSTA+='"cache_creation_input_tokens":0,"cache_read_input_tokens":0,'
RISPOSTA+='"output_tokens":1}}'
readonly RISPOSTA
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
    fail "$1 (rc=${RC}, attesa $2, parola «$3»): ${OUT:0:300}"
  fi
}

# Nessun falso positivo: la parola NON c'è (RU-01.T5).
expect_absent() {
  if grep -qF -- "$2" <<< "${OUT}"; then
    fail "$1: «$2» c'è"
  else
    pass "$1"
  fi
}

# Un nuovo spazio di lavoro vuoto, con il contenuto di una cartella se
# indicata. Arguments: $1 la variabile da assegnare, $2 (facoltativo) la
# cartella da copiare.
ws() {
  local __w
  __w="$(mktemp -d "${TMP}/ws.XXXXXX")" || { echo "mktemp" >&2; exit 2; }
  if [[ -n "${2:-}" ]]; then
    cp -R "$2/." "${__w}/"
  fi
  printf -v "$1" '%s' "${__w}"
}

# Scrive un file di righe: ogni argomento è una riga, con «|» al posto
# della tabulazione. Arguments: $1 il file, poi le righe.
tsv() {
  local f="$1" r
  shift
  : > "${f}"
  for r in "$@"; do
    printf '%s\n' "${r//|/${T}}" >> "${f}"
  done
}

# Una copia dell'elemento $2 con la libreria accanto, come nel repository,
# in cui verifica.sh è finta: stampa una riga per canale ed esce con
# STUB_USCITA (default 2). L'albero del repository non cambia.
# Arguments: $1 la variabile da assegnare (l'elemento nella copia), $2
# l'elemento.
albero_finto() {
  local __a_radice="${MOD%/*}" __a_copia __a_rel
  __a_rel="${2#"${__a_radice}"/}"
  __a_copia="$(mktemp -d "${TMP}/albero.XXXXXX")" \
    || { echo "mktemp" >&2; exit 2; }
  mkdir -p "${__a_copia}/tools" "${__a_copia}/${__a_rel}"
  cp "${__a_radice}/tools/lib_handson.sh" "${__a_copia}/tools/"
  cp -R "$2/." "${__a_copia}/${__a_rel}/"
  # shellcheck disable=SC2016  # il corpo è della verifica finta
  printf '%s\n' '#!/bin/bash' 'echo "riga della verifica finta"' \
    'echo "verifica: precondizione finta" >&2' \
    'exit "${STUB_USCITA:-2}"' > "${__a_copia}/${__a_rel}/verifica.sh"
  chmod 755 "${__a_copia}/${__a_rel}/verifica.sh"
  printf -v "$1" '%s' "${__a_copia}/${__a_rel}"
}

# Cambia un campo di primo livello di un JSON: «-» lo toglie, altrimenti
# il valore è un letterale JSON (anche NaN). Arguments: $1 il file, $2 il
# campo, $3 il valore.
json_set() {
  python3 -B -I - "$@" <<'PY'
import json
import sys

path, campo, valore = sys.argv[1:4]
with open(path, encoding="utf-8") as fh:
    dati = json.load(fh)
if valore == "-":
    dati.pop(campo, None)
else:
    dati[campo] = json.loads(valore)
with open(path, "w", encoding="utf-8") as fh:
    json.dump(dati, fh)
PY
}

# leggi_json.py con un testo su STDIN. Arguments: $1 il testo, $2 il dato.
lj_run() { OUT="$(printf '%s' "$1" | python3 -B -I "${LJ}" "$2" 2>&1)"; RC=$?; }

# Un live.sh con il claude finto davanti nel PATH; il registro delle sue
# chiamate riparte vuoto. Arguments: $1 l'elemento, $2 lo spazio di
# lavoro, poi le variabili NOME=valore.
live() {
  local e="$1" w="$2"
  shift 2
  : > "${TMP}/chiamate.log"
  run env PATH="${TMP}/bin:${PATH}" HANDSON_NO_PAUSE=1 \
    FINTO_LOG="${TMP}/chiamate.log" "$@" "${e}/_docente/live.sh" "${w}"
}

# Il claude finto: --version risponde; ogni altra chiamata va nel
# registro, poi il finto legge gli argomenti come la CLI vera: le opzioni
# che usano i live.sh del modulo (con i loro valori), poi il prompt, dopo
# «--» oppure come unico argomento che non comincia con «-». Una parola
# che comincia con «-», prima di «--», e non è un'opzione che conosce la
# rifiuta («error: unknown option», uscita 1), come un prompt che manca o
# un secondo prompt. Salvo FINTO_ESITO=ko stampa RISPOSTA; con
# FINTO_TOKEN=byte i token in entrata sono i byte del prompt (la frase
# italiana di M1-D02 ne ha più di quella inglese).
claude_finto() {
  mkdir -p "${TMP}/bin"
  printf '%s\n' "${RISPOSTA}" > "${TMP}/bin/risposta.json"
  cat > "${TMP}/bin/claude" <<'FINTO'
#!/bin/bash
set -uo pipefail
SENZA_VALORE=' -p --print --strict-mcp-config --no-session-persistence '
CON_VALORE=' --model --effort --tools --allowedTools --system-prompt'
CON_VALORE+=' --output-format --permission-mode --permission-prompts'
CON_VALORE+=' --setting-sources --resume '
if [[ "${1:-}" == "--version" ]]; then echo "0.0.0 (finto)"; exit 0; fi
echo "chiamata" >> "${FINTO_LOG:?}"
prompt=()
while (( $# > 0 )); do
  if [[ "$1" == "--" ]]; then
    shift
    prompt+=("$@")
    break
  elif [[ "$1" != -* ]]; then
    prompt+=("$1")
  elif [[ "${CON_VALORE}" == *" $1 "* ]]; then
    if (( $# < 2 )); then
      echo "error: option '$1' argument missing" >&2
      exit 1
    fi
    shift
  elif [[ "${SENZA_VALORE}" != *" $1 "* ]]; then
    echo "error: unknown option '$1'" >&2
    exit 1
  fi
  shift
done
if (( ${#prompt[@]} != 1 )); then
  echo "error: atteso un prompt, ricevuti ${#prompt[@]}" >&2
  exit 1
fi
if [[ "${FINTO_ESITO:-ok}" != "ok" ]]; then exit 1; fi
if [[ "${FINTO_TOKEN:-}" == "byte" ]]; then
  n="$(printf '%s' "${prompt[0]}" | wc -c)"
  jq -c --argjson n "$(( n ))" '.usage.input_tokens = $n' \
    "${0%/*}/risposta.json"
else
  cat "${0%/*}/risposta.json"
fi
FINTO
  chmod 755 "${TMP}/bin/claude"
}

# --- I test ---------------------------------------------------------------

# Ogni verifica.sh: spazio di lavoro assente (2), la soluzione (0, senza
# segnalazioni), il file dei risultati che non si legge (2).
t_verifiche_base() {
  local i e nome w p
  for i in "${!ELEMENTI[@]}"; do
    e="${ELEMENTI[i]}"
    nome="${e##*/}"
    run "${e}/verifica.sh" "${TMP}/assente"
    expect "${nome}: spazio di lavoro assente" 2 "spazio di lavoro assente"
    # il punto di partenza e poi la soluzione, come tools/run_all.sh: una
    # verifica può leggere anche i testi della partenza (M1-D02, M1-D03)
    p="${e}/demo"
    [[ -d "${p}" ]] || p="${e}/esercizio"
    ws w "${p}"
    cp -R "${e}/soluzione/." "${w}/"
    run "${e}/verifica.sh" "${w}"
    expect "${nome}: la soluzione passa" 0 "${OK_PAROLE[i]}"
    expect_absent "${nome}: la soluzione non ha segnalazioni" "${KO_PAROLE[i]}"
    if (( EUID == 0 )); then
      skip "${nome}: ${DATI[i]} che non si legge (da root ogni file si legge)"
      continue
    fi
    chmod 000 "${w}/${DATI[i]}"
    run "${e}/verifica.sh" "${w}"
    expect "${nome}: ${DATI[i]} che non si legge" 2 "non si legge"
  done
}

t_casi_d01() {
  local w
  ws w
  tsv "${w}/risultati.tsv" 'haiku|La'
  run "${D01}/verifica.sh" "${w}"
  expect "M1-D01: senza intestazione" 1 "intestazione"
  tsv "${w}/risultati.tsv" 'modello|parola' 'haiku|La' 'sonnet|Il'
  run "${D01}/verifica.sh" "${w}"
  expect "M1-D01: un modello senza risposte" 1 "Nessuna risposta di opus"
  tsv "${w}/risultati.tsv" 'modello|parola' 'haiku|La' 'sonnet|Il' 'opus|La'
  run "${D01}/verifica.sh" "${w}"
  expect "M1-D01: «1 risposta», al singolare" 0 "haiku: 1 risposta --"
}

t_casi_d02() {
  local w
  ws w
  tsv "${w}/conteggi.tsv" 'modello|testo|token_entrata' 'haiku|it|100' \
    'haiku|it-doppia|127' 'haiku|en|90' 'haiku|en-doppia|107'
  sed -i 's/$/\r/' "${w}/conteggi.tsv"
  run "${D02}/verifica.sh" "${w}"
  expect "M1-D02: righe CRLF" 0 "haiku: italiano 27 token, inglese 17"
  tsv "${w}/conteggi.tsv" 'modello|testo|token_entrata' 'haiku|it|100' \
    'haiku|it-doppia|110' 'haiku|en|90' 'haiku|en-doppia|107'
  run "${D02}/verifica.sh" "${w}"
  expect "M1-D02: l'inglese pesa di più, un dato: la verifica passa" 0 \
    "(27 contro 17): in questa esecuzione no"
  tsv "${w}/conteggi.tsv" 'modello|testo|token_entrata' 'haiku|it|100'
  run "${D02}/verifica.sh" "${w}"
  expect "M1-D02: nessun modello completo" 1 "Nessun modello con i quattro"
}

t_casi_d04() {
  local w
  ws w
  tsv "${w}/catena.tsv" 'chiamata|token_entrata|risposta' 'A|0950|Ricevuto.' \
    'B|0577|Quale linea?' "C|1000|La linea LN${U2011}000204 ha un guasto."
  run "${D04}/verifica.sh" "${w}"
  expect "M1-D04: zeri davanti e trattino U+2011" 0 "Fatto: ogni affermazione"
  tsv "${w}/catena.tsv" 'chiamata|token_entrata|risposta' 'A|950|Ricevuto.' \
    'B|577|Forse la ln-000204?' 'C|1000|La linea LN-000204.'
  run "${D04}/verifica.sh" "${w}"
  expect "M1-D04: B nomina la linea, in minuscolo" 1 "B nomina LN-000204"
  tsv "${w}/catena.tsv" 'chiamata|token_entrata|risposta' 'A|950|Ricevuto.' \
    'B|577|Quale linea?' 'C|900|La linea LN-000204.'
  run "${D04}/verifica.sh" "${w}"
  expect "M1-D04: C non manda più token di A" 1 \
    "la cronologia rimandata a ogni richiesta; in questa esecuzione no"
  tsv "${w}/catena.tsv" 'chiamata|token_entrata|risposta' 'A|950|Ricevuto.' \
    'B|577|Quale linea?' 'C|1000|Non lo so.'
  run "${D04}/verifica.sh" "${w}"
  expect "M1-D04: C non nomina la linea, un consiglio: esce 0" 0 \
    "C nomina LN-000204: non confermata in questa esecuzione"
  tsv "${w}/catena.tsv" 'chiamata|token_entrata|risposta' 'A|950|Ricevuto.' \
    'B|577|Quale linea?' 'C|1000|La linea LN-000204.'
  sed -i -e '1s/^/\xef\xbb\xbf/' -e 's/$/\r/' "${w}/catena.tsv"
  run "${D04}/verifica.sh" "${w}"
  expect "M1-D04: l'intestazione con un BOM, righe CRLF" 0 \
    "Fatto: ogni affermazione"
  # 30 nove: l'aritmetica di bash li riduce in silenzio a un altro numero
  tsv "${w}/catena.tsv" 'chiamata|token_entrata|risposta' 'A|950|Ricevuto.' \
    'B|577|Quale linea?' \
    "C|$(printf '%30s' '' | tr ' ' 9)|La linea LN-000204."
  run "${D04}/verifica.sh" "${w}"
  expect "M1-D04: un conteggio di 30 cifre non è un numero, uscita 1" 1 \
    "Token in entrata di A o di C mancanti o non numerici."
}

# Le righe dei sei verifica.sh: al più 80 colonne (RU-01.14), contate in
# caratteri.
t_colonne() {
  local e
  local -a script=()
  for e in "${ELEMENTI[@]}"; do
    script+=("${e}/verifica.sh")
  done
  run python3 -B -I - "${script[@]}" <<'PY'
import sys

lunghe = []
for path in sys.argv[1:]:
    with open(path, encoding="utf-8") as fh:
        for numero, riga in enumerate(fh, 1):
            if len(riga.rstrip("\n")) > 80:
                lunghe.append("%s:%d" % (path.rsplit("/", 2)[-2], numero))
print(" ".join(lunghe) or "ok")
sys.exit(1 if lunghe else 0)
PY
  expect "i sei verifica.sh: nessuna riga oltre le 80 colonne" 0 ok
}

t_casi_d05() {
  local w
  ws w "${D05}/demo"
  cp -R "${D05}/soluzione/." "${w}/"
  rm -f -- "${w}/risposte/B-regole-opus.json"
  run "${D05}/verifica.sh" "${w}"
  expect "M1-D05: una risposta che manca" 1 \
    "Da completare: manca risposte/B-regole-opus.json"
}

# verifica.py di M1-E01, attraverso verifica.sh: ogni caso parte da una
# copia nuova della soluzione e vi introduce un solo difetto.
t_casi_e01() {
  local w
  ws w "${E01}/soluzione"
  sed -i -e 's/^| haiku |/| Haiku 4.5 |/' \
    -e 's/^\(| sonnet |\) 5.6 |/\1 5,6 sec |/' "${w}/confronto.md"
  run "${E01}/verifica.sh" "${w}"
  expect "M1-E01: «Haiku 4.5» e «5,6 sec» accettati" 0 "Confronto compilato"
  ws w "${E01}/soluzione"
  sed -i 's/| 1544 |/| 1545 |/' "${w}/confronto.md"
  run "${E01}/verifica.sh" "${w}"
  expect "M1-E01: token della tabella diversi dal JSON" 1 \
    "token in entrata «1545», nel JSON 1544"
  ws w "${E01}/soluzione"
  sed -i 's/^\(| opus |.*\)$/\1 in più |/' "${w}/confronto.md"
  run "${E01}/verifica.sh" "${w}"
  expect "M1-E01: una colonna in più" 1 "ha 6 colonne invece di 5"
  ws w "${E01}/soluzione"
  json_set "${w}/risposte/haiku.json" modelUsage -
  run "${E01}/verifica.sh" "${w}"
  expect "M1-E01: JSON senza modelUsage" 1 "manca modelUsage"
  ws w "${E01}/soluzione"
  json_set "${w}/risposte/sonnet.json" is_error true
  run "${E01}/verifica.sh" "${w}"
  expect "M1-E01: JSON con errore" 1 "errore o risposta vuota"
  ws w "${E01}/soluzione"
  json_set "${w}/risposte/opus.json" duration_ms NaN
  run "${E01}/verifica.sh" "${w}"
  expect "M1-E01: durata non numerica" 1 "duration_ms manca o non è un numero"
}

t_leggi_json() {
  local copie
  copie="$(sha256sum "${LJ}" "${D03}/demo/leggi_json.py" \
    "${D04}/demo/leggi_json.py" "${D05}/demo/leggi_json.py" \
    | cut -d' ' -f1 | sort -u | wc -l)"
  if (( copie == 1 )); then
    pass "leggi_json.py: le quattro copie sono identiche"
  else
    fail "leggi_json.py: ${copie} versioni diverse"
  fi
  lj_run '' result
  expect "leggi_json.py: ingresso vuoto" 1 "nessun JSON in ingresso"
  lj_run 'x' result
  expect "leggi_json.py: JSON non valido" 1 "non è un JSON valido"
  # 100000 «[»: RecursionError su ogni python3, dal 3.8 al 3.14
  lj_run "$(printf '%100000s' '' | tr ' ' '[')" result
  expect "leggi_json.py: JSON annidato oltre il limite, uscita 1" 1 \
    "il testo in ingresso non è un JSON valido"
  lj_run '[1]' result
  expect "leggi_json.py: JSON non oggetto" 1 "non è quello di claude -p"
  lj_run '{"is_error":true,"result":"x"}' result
  expect "leggi_json.py: claude in errore" 1 "ha restituito un errore"
  lj_run '{"usage":{"input_tokens":2,"cache_creation_input_tokens":null,
    "cache_read_input_tokens":5}}' token_entrata
  expect "leggi_json.py: token null contati come zero" 0 "7"
  lj_run '{"usage":{"output_tokens":1}}' token_entrata
  expect "leggi_json.py: «usage» senza i tre campi in entrata, uscita 1" 1 \
    "«usage» non contiene i token in entrata"
  lj_run '{"usage":{"input_tokens":null,"cache_read_input_tokens":null}}' \
    token_entrata
  expect "leggi_json.py: i tre campi assenti o null, uscita 1" 1 \
    "«usage» non contiene i token in entrata"
  lj_run '{}' nessuno
  expect "leggi_json.py: uso sbagliato" 2 "Uso:"
}

# Il claude finto legge gli argomenti come la CLI vera: «- prova» prima di
# «--» è un'opzione sconosciuta (uscita 1), dopo «--» è il prompt; senza
# prompt esce 1.
t_finto() {
  local c="${TMP}/bin/claude"
  run env FINTO_LOG="${TMP}/finto.log" "${c}" -p --model haiku '- prova'
  expect "claude finto: «- prova» prima di «--» è un'opzione sconosciuta" 1 \
    "error: unknown option '- prova'"
  run env FINTO_LOG="${TMP}/finto.log" "${c}" -p --model haiku -- '- prova'
  expect "claude finto: dopo «--» «- prova» è il prompt" 0 '"result":"Ciao"'
  run env FINTO_LOG="${TMP}/finto.log" "${c}" -p --tools '' --model haiku
  expect "claude finto: senza prompt esce 1" 1 "atteso un prompt"
}

# I live.sh con il claude finto (R5-8: il contratto d'uscita).
t_live() {
  local e w partenza frase
  for e in "${ELEMENTI[@]}"; do
    partenza="${e}/demo"
    [[ -d "${partenza}" ]] || partenza="${e}/esercizio"
    ws w "${partenza}"
    live "${e}" "${w}" HANDSON_PERMISSION_MODE=nessuna
    expect "${e##*/} live.sh: precondizione di claude_p, uscita 2" 2 \
      "modalità di permesso non ammessa"
    if [[ -s "${TMP}/chiamate.log" ]]; then
      fail "${e##*/} live.sh: claude chiamato malgrado la precondizione"
    else
      pass "${e##*/} live.sh: claude mai chiamato"
    fi
  done
  ws w "${D01}/demo"
  live "${D01}" "${w}" PN_RIPETIZIONI=1
  expect "M1-D01 live.sh: tre risposte, uscita 0" 0 "Ciao"
  run "${D01}/verifica.sh" "${w}"
  expect "M1-D01: il risultati.tsv di live.sh passa la verifica" 0 \
    "${OK_PAROLE[0]}"
  live "${D01}" "${w}" PN_RIPETIZIONI=1 FINTO_ESITO=ko
  expect "M1-D01 live.sh: chiamate fallite, uscita 1" 1 "VERIFICA KO"
  ws w "${D01}/demo"
  frase="$(cat "${w}/frase.txt")"
  printf -- '- %s\n' "${frase}" > "${w}/frase.txt"
  live "${D01}" "${w}" PN_RIPETIZIONI=1
  expect "M1-D01 live.sh: un prompt che comincia con «-» arriva a claude" 0 \
    "Ciao"
  expect_absent "M1-D01 live.sh: e nessun rifiuto" "cominciare con -"
  ws w "${D02}/demo"
  live "${D02}" "${w}"
  expect "M1-D02 live.sh: token uguali, pesi zero da rifare, KO" 1 \
    "VERIFICA KO   le due affermazioni (verifica.sh) (uscita 1)"
  ws w "${D02}/demo"
  live "${D02}" "${w}" FINTO_TOKEN=byte
  expect "M1-D02 live.sh: pesi positivi, la sua verifica.sh è OK" 0 \
    "VERIFICA OK   le due affermazioni (verifica.sh)"
  run "${D02}/verifica.sh" "${w}"
  expect "M1-D02: il conteggi.tsv di live.sh passa la verifica" 0 \
    "${OK_PAROLE[1]}"
  ws w "${D04}/demo"
  live "${D04}" "${w}" FINTO_ESITO=ko
  expect "M1-D04 live.sh: chiamata A fallita, uscita 1" 1 \
    "la chiamata A non ha dato una risposta"
  ws w "${D04}/demo"
  live "${D04}" "${w}"
  expect "M1-D04 live.sh: su un esito diverso il messaggio di verifica.sh" 1 \
    "la cronologia rimandata a ogni richiesta; in questa esecuzione no"
  expect "M1-D04 live.sh: e il verdetto con l'uscita del controllo" 1 \
    "VERIFICA KO   le due garanzie (verifica.sh) (uscita 1)"
  ws w "${D05}/demo"
  live "${D05}" "${w}"
  expect "M1-D05 live.sh: dodici risposte, uscita 0" 0 "Ciao"
}

# Il live.sh di M1-E01 con una verifica.sh finta: se la verifica esce 2
# (una precondizione) la prova esce 2, con la riga FATALE; se esce 1 resta
# un KO; se esce 0 passa e ne stampa l'uscita, come prima.
t_live_verifica() {
  local c w
  albero_finto c "${E01}"
  ws w "${E01}/esercizio"
  live "${c}" "${w}"
  expect "M1-E01 live.sh: la verifica esce 2, la prova esce 2" 2 \
    "una precondizione, non un esito diverso"
  expect "M1-E01 live.sh: e il verdetto con l'uscita della verifica" 2 \
    "VERIFICA KO   verifica.sh dell'elemento (uscita 2)"
  ws w "${E01}/esercizio"
  live "${c}" "${w}" STUB_USCITA=1
  expect "M1-E01 live.sh: la verifica esce 1, resta un KO" 1 \
    "VERIFICA KO   verifica.sh dell'elemento (uscita 1)"
  expect_absent "M1-E01 live.sh: e nessuna precondizione" "FATALE"
  ws w "${E01}/esercizio"
  live "${c}" "${w}" STUB_USCITA=0
  expect "M1-E01 live.sh: la verifica esce 0, la sua uscita si stampa" 0 \
    "riga della verifica finta"
}

# Il manifest.tsv del modulo e le cartelle: ogni elemento sta dove la sua
# riga dice (section_dir/subdeck_dir), e il suo deck_path finisce con
# quel sotto-deck.
t_manifest() {
  local e id dove sez sub deck
  for e in "${ELEMENTI[@]}"; do
    id="${e##*/}"
    id="${id%%_*}"
    dove="${e%/*}"
    dove="${dove#"${MOD}"/}"
    sez='' sub='' deck=''
    IFS="${T}" read -r sez sub deck < <(awk -F'\t' -v id="${id}" \
      'NR > 1 && $1 == id { print $4 "\t" $5 "\t" $6 }' \
      "${MOD}/manifest.tsv")
    if [[ -n "${sub}" && "${sez}/${sub}" == "${dove}" ]]; then
      pass "manifest: ${id} sta in ${dove}"
    else
      fail "manifest: ${id} nomina «${sez}/${sub}», non ${dove}"
    fi
    if [[ -n "${sub}" && "${deck}" == */"${sub}" ]]; then
      pass "manifest: il deck_path di ${id} finisce con ${sub}"
    else
      fail "manifest: il deck_path di ${id} è «${deck}»"
    fi
  done
}

t_shellcheck() {
  local e f
  for e in "${ELEMENTI[@]}"; do
    for f in "${e}/verifica.sh" "${e}/_docente/live.sh"; do
      run shellcheck -x -- "${f}"
      if (( RC == 0 )) && [[ -z "${OUT}" ]]; then
        pass "shellcheck ${f#"${S1}"/}"
      else
        fail "shellcheck ${f#"${S1}"/}: ${OUT:0:300}"
      fi
    done
  done
  run shellcheck -x -- "${SELF}"
  if (( RC == 0 )) && [[ -z "${OUT}" ]]; then
    pass "shellcheck ${SELF##*/}"
  else
    fail "shellcheck ${SELF##*/}: ${OUT:0:300}"
  fi
}

main() {
  local t e
  for t in jq python3 shellcheck sha256sum; do
    if ! command -v "${t}" > /dev/null 2>&1; then
      echo "test_m1_script.sh: manca lo strumento ${t}" >&2
      exit 2
    fi
  done
  for e in "${ELEMENTI[@]}"; do
    if [[ ! -d "${e}" ]]; then
      echo "test_m1_script.sh: manca la cartella ${e#"${MOD}"/}" >&2
      exit 2
    fi
  done
  TMP="$(mktemp -d)" || { echo "mktemp non riesce" >&2; exit 2; }
  readonly TMP
  # chmod prima di rm: t_verifiche_base toglie i permessi a risposte/
  trap 'chmod -R u+rwx -- "${TMP}" 2> /dev/null; rm -rf -- "${TMP}"' EXIT
  unset ANTHROPIC_API_KEY HANDSON_ENV HANDSON_PERMISSION_MODE \
    HANDSON_SHOW_CMD HANDSON_NO_PAUSE PN_RIPETIZIONI PN_MODELLI PN_MODELLO \
    PN_PROMPT
  claude_finto
  echo "test_m1_script.sh"
  t_manifest
  t_verifiche_base
  t_casi_d01
  t_casi_d02
  t_casi_d04
  t_colonne
  t_casi_d05
  t_casi_e01
  t_leggi_json
  t_finto
  t_live
  t_live_verifica
  t_shellcheck
  echo "PASS=${PASS} FAIL=${FAIL} SKIP=${SKIP}"
  if (( PASS + FAIL + SKIP != CASES )); then
    echo "test_m1_script.sh: eseguite $((PASS + FAIL + SKIP)) prove," \
      "attese ${CASES}: una prova manca o è in più" >&2
    exit 2
  fi
  (( FAIL == 0 )) || exit 1
}

main "$@"
