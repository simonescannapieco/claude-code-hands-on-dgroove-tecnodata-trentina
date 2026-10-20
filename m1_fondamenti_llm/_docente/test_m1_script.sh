#!/bin/bash
#
# test_m1_script.sh -- le prove degli script del modulo 1, per il docente
# (sta in _docente/, il materiale del docente, che resta fuori dalla copia
# senza soluzioni di tools/esporta_studenti.sh):
#   - i sei verifica.sh: spazio di lavoro assente e file che non si legge
#     (uscita 2), la soluzione dell'elemento (0, senza segnalazioni), i casi
#     da segnalare (1) e quelli limite: a capo CRLF, numeri con lo zero
#     davanti, il trattino U+2011, la linea scritta in minuscolo, l'inizio
#     di una risposta tagliato a parole anche con LC_ALL=C;
#   - verifica.py di M1-E01: un JSON con errore, senza modelUsage o con una
#     durata non numerica, numeri della tabella diversi dal JSON, una
#     colonna in più; «Haiku 4.5» e «5,6 sec» accettati;
#   - leggi_json.py: le tre copie identiche, JSON vuoto, non valido o non
#     oggetto (1), uso sbagliato (2), token null contati come zero;
#   - il claude finto legge gli argomenti come la CLI vera: le opzioni,
#     poi «--» e il prompt; un prompt che comincia con «-» passato prima
#     di «--» è un'opzione sconosciuta (uscita 1);
#   - i sei _docente/live.sh con il claude finto: una precondizione di
#     handson::claude_p esce 2 senza chiamare claude, una chiamata fallita
#     esce 1, le risposte complete escono 0; su un esito diverso M1-D04
#     stampa il messaggio di verifica.sh; il controllo di M1-D02, una
#     funzione, va KO con token uguali e OK con i token presi dai byte del
#     prompt; un prompt che comincia con «-» arriva a claude;
#   - il live.sh di M1-E01 con una verifica.sh finta, in una copia
#     dell'elemento: se la verifica esce 2 la prova esce 2 (una
#     precondizione), se esce 1 resta un KO, se esce 0 passa e ne stampa
#     l'uscita;
#   - il manifest.tsv del modulo: la cartella e il deck_path di ogni
#     elemento sono quelli della sua riga;
#   - shellcheck -x su ogni script del modulo e su questo.
# Gli spazi di lavoro nascono in una cartella temporanea: l'albero del
# repository non cambia.
#
# Uso:    m1_fondamenti_llm/_docente/test_m1_script.sh
# Uscita: 0 = tutte le prove passano · 1 = almeno una fallita
#         2 = precondizione (manca jq, python3, shellcheck, iconv o
#             sha256sum, o la cartella di un elemento)
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
# Per ogni elemento, nello stesso ordine: il file dei risultati, la frase
# della verifica riuscita, una parola delle sue segnalazioni.
readonly DATI=(risultati.tsv conteggi.tsv risposte.tsv catena.tsv
  risposte.tsv confronto.md)
readonly OK_PAROLE=('Le risposte dei tre modelli ci sono.'
  'La frase italiana pesa più della sua traduzione inglese.'
  'Le risposte dei tre modelli ci sono (le n sono 4).'
  'Esito come nelle registrazioni del corso.'
  'Le risposte ci sono: rifiutano o inventano?'
  'Confronto compilato e coerente')
readonly KO_PAROLE=('Nessuna risposta' 'atteso italiano' 'Nessuna risposta'
  'dovrebbe' 'Manca la risposta' 'Da sistemare')
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
RC=0
OUT=''

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

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
  local i e nome w
  for i in "${!ELEMENTI[@]}"; do
    e="${ELEMENTI[i]}"
    nome="${e##*/}"
    run "${e}/verifica.sh" "${TMP}/assente"
    expect "${nome}: spazio di lavoro assente" 2 "spazio di lavoro assente"
    ws w "${e}/soluzione"
    run "${e}/verifica.sh" "${w}"
    expect "${nome}: la soluzione passa" 0 "${OK_PAROLE[i]}"
    expect_absent "${nome}: la soluzione non ha segnalazioni" "${KO_PAROLE[i]}"
    if (( EUID == 0 )); then
      echo "  SKIP: ${nome}: da root ogni file si legge"
      continue
    fi
    chmod 000 "${w}/${DATI[i]}"
    run "${e}/verifica.sh" "${w}"
    expect "${nome}: ${DATI[i]} che non si legge" 2 "non si legge"
  done
}

t_casi_d01_d03() {
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
  tsv "${w}/risposte.tsv" 'modello|domanda|risposta' 'haiku|conta|4' \
    'haiku|compitata|4' 'sonnet|conta|3' 'opus|conta|4' 'opus|compitata|4'
  run "${D03}/verifica.sh" "${w}"
  expect "M1-D03: una domanda senza risposta" 1 \
    "Nessuna risposta di sonnet alla domanda «compitata»"
  tsv "${w}/risposte.tsv" 'modello|domanda|risposta' \
    'haiku|conta|uno due tre quattro cinque sei sette otto nove dieci undici' \
    'haiku|compitata|4' 'sonnet|conta|3' 'sonnet|compitata|4' \
    'opus|conta|4' 'opus|compitata|4'
  run "${D03}/verifica.sh" "${w}"
  expect "M1-D03: di una risposta lunga, le prime dieci parole" 0 \
    "«uno due tre quattro cinque sei sette otto nove dieci …»"
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
  expect "M1-D02: l'inglese pesa di più" 1 "atteso italiano > inglese > 0"
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
  expect "M1-D04: zeri davanti e trattino U+2011" 0 "Esito come nelle"
  tsv "${w}/catena.tsv" 'chiamata|token_entrata|risposta' 'A|950|Ricevuto.' \
    'B|577|Forse la ln-000204?' 'C|1000|La linea LN-000204.'
  run "${D04}/verifica.sh" "${w}"
  expect "M1-D04: B nomina la linea, in minuscolo" 1 "B nomina LN-000204"
  tsv "${w}/catena.tsv" 'chiamata|token_entrata|risposta' 'A|950|Ricevuto.' \
    'B|577|Quale linea?' 'C|900|La linea LN-000204.'
  run "${D04}/verifica.sh" "${w}"
  expect "M1-D04: C non manda più token di A" 1 "attesi più token per C"
}

t_casi_d05() {
  local w lunga
  ws w
  tsv "${w}/risposte.tsv" 'modello|turno|risposta' 'haiku|richiesta|No.' \
    'haiku|insisto|No.' 'sonnet|richiesta|No.' 'sonnet|insisto|No.' \
    'opus|richiesta|No.'
  run "${D05}/verifica.sh" "${w}"
  expect "M1-D05: un turno senza risposta" 1 \
    "Manca la risposta di opus al turno «insisto»"
  lunga='Non posso farlo perché la circolare non è nei documenti: è più'
  lunga+=' prudente così, perché città e attività cambiano, però verificherò'
  tsv "${w}/risposte.tsv" 'modello|turno|risposta' "haiku|richiesta|${lunga}" \
    'haiku|insisto|No.' 'sonnet|richiesta|No.' 'sonnet|insisto|No.' \
    'opus|richiesta|No.' 'opus|insisto|No.'
  run env LC_ALL=C "${D05}/verifica.sh" "${w}"
  expect "M1-D05: risposta lunga con LC_ALL=C, tagliata a parole" 0 \
    "e attività …"
  if iconv -f UTF-8 -t UTF-8 <<< "${OUT}" > /dev/null 2>&1; then
    pass "M1-D05: l'inizio tagliato resta UTF-8 valido"
  else
    fail "M1-D05: UTF-8 spezzato: ${OUT:0:200}"
  fi
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
  copie="$(sha256sum "${LJ}" "${D04}/demo/leggi_json.py" \
    "${D05}/demo/leggi_json.py" | cut -d' ' -f1 | sort -u | wc -l)"
  if (( copie == 1 )); then
    pass "leggi_json.py: le tre copie sono identiche"
  else
    fail "leggi_json.py: ${copie} versioni diverse"
  fi
  lj_run '' result
  expect "leggi_json.py: ingresso vuoto" 1 "nessun JSON in ingresso"
  lj_run 'x' result
  expect "leggi_json.py: JSON non valido" 1 "non è un JSON valido"
  lj_run '[1]' result
  expect "leggi_json.py: JSON non oggetto" 1 "non è quello di claude -p"
  lj_run '{"is_error":true,"result":"x"}' result
  expect "leggi_json.py: claude in errore" 1 "ha restituito un errore"
  lj_run '{"usage":{"input_tokens":2,"cache_creation_input_tokens":null,
    "cache_read_input_tokens":5}}' token_entrata
  expect "leggi_json.py: token null contati come zero" 0 "7"
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
  expect "M1-D02 live.sh: token uguali, il controllo (una funzione) è KO" 1 \
    "VERIFICA KO   haiku: italiano > inglese > 0 (uscita 1)"
  ws w "${D02}/demo"
  live "${D02}" "${w}" FINTO_TOKEN=byte
  expect "M1-D02 live.sh: l'italiano pesa di più, il controllo è OK" 0 \
    "VERIFICA OK   haiku: italiano > inglese > 0"
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
    "C non nomina LN-000204: la sessione ripresa dovrebbe ricordarla."
  expect "M1-D04 live.sh: e il verdetto con l'uscita del controllo" 1 \
    "C sì; C manda più token di A (uscita 1)"
  ws w "${D05}/demo"
  live "${D05}" "${w}"
  expect "M1-D05 live.sh: sei risposte, uscita 0" 0 "Ciao"
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
  for t in jq python3 shellcheck iconv sha256sum; do
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
  trap 'rm -rf -- "${TMP}"' EXIT
  unset ANTHROPIC_API_KEY HANDSON_ENV HANDSON_PERMISSION_MODE \
    HANDSON_SHOW_CMD HANDSON_NO_PAUSE PN_RIPETIZIONI PN_MODELLI PN_MODELLO \
    PN_PROMPT
  claude_finto
  echo "test_m1_script.sh"
  t_manifest
  t_verifiche_base
  t_casi_d01_d03
  t_casi_d02
  t_casi_d04
  t_casi_d05
  t_casi_e01
  t_leggi_json
  t_finto
  t_live
  t_live_verifica
  t_shellcheck
  echo "PASS=${PASS} FAIL=${FAIL}"
  (( FAIL == 0 )) || exit 1
}

main "$@"
