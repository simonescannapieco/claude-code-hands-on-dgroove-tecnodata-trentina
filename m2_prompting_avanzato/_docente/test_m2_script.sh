#!/bin/bash
#
# test_m2_script.sh -- le prove degli script del modulo 2, per il docente
# (sta in _docente/, il materiale del docente):
#   - gli otto verifica.sh: spazio di lavoro assente (2), punto di partenza
#     (1), soluzione (0, senza segnalazioni), il file dei risultati che non si
#     legge (2);
#   - le copie che devono restare identiche: leggi_json.py nelle sei demo;
#     misura.sh, strumenti/kit.py, lo schema, il giudice, le impostazioni,
#     verifica.py e verifica.sh nelle due esercitazioni; il messaggio del
#     cliente in ogni elemento che lo usa, anche dentro i prompt;
#   - kit.py senza claude: i segnaposto, le versioni, i controlli, la
#     consegna al giudice, il giudizio incompleto, il confronto; l'uscita di
#     controlla (0 tutto superato, 1 un controllo no, 2 un errore); i
#     formati rifiutati; mai un traceback su un dato rovinato;
#   - verifica.py: le regole delle due esercitazioni (prompt uguale, nessun
#     miglioramento, telefono ripetuto, registro vuoto, famiglia mancante,
#     due cicli, peggioramento, una famiglia sola che migliora); una misura
#     rovinata da rifare; una cartella che non si legge (2);
#   - leggi_json.py, orario.py e controlla_json.py sui casi limite;
#   - i live.sh e misura.sh con il claude finto (_docente/claude_finto.py):
#     le precondizioni escono 2 senza chiamare claude, una chiamata fallita
#     esce 1 (le demo si fermano lì) e su un esito diverso si legge il
#     messaggio di verifica.sh, le risposte complete escono 0;
#     ANTHROPIC_API_KEY non arriva a claude; il prompt dopo «--», il limite
#     dei 100000 byte, le opzioni di misura.sh;
#   - il frontmatter del giudice, le parole che i partecipanti leggono;
#   - shellcheck -x su ogni script del modulo e su questo.
# Gli spazi di lavoro nascono in una cartella temporanea: l'albero del
# repository non cambia.
#
# Uso:    m2_prompting_avanzato/_docente/test_m2_script.sh
# Uscita: 0 = tutte le prove passano · 1 = almeno una fallita
#         2 = precondizione (manca jq, python3, shellcheck o sha256sum, o la
#             cartella di un elemento)
set -uo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly MOD="${SELF%/_docente/*}"
readonly RADICE="${MOD%/*}"
readonly S1="${MOD}/s1_progettare_il_prompt"
readonly S2="${MOD}/s2_misurare_e_migliorare"
readonly D01="${S1}/m2_1_cambiato_solo_il_prompt/M2-D01_prompt_a_contro_b"
readonly D02="${S1}/m2_3_ruoli_dei_messaggi/M2-D02_system_prompt_nascosto"
readonly D03="${S1}/m2_4_tag_e_struttura/M2-D03_solo_json_o_schema"
readonly D04="${S1}/m2_5_esempi/M2-D04_zero_shot_few_shot"
readonly D05="${S1}/m2_6_ragionamento/M2-D05_ragionare_oggi"
readonly D06="${S2}/m2_7_galleria_degli_orrori/M2-D06_galleria_degli_orrori"
readonly E01="${S1}/m2_e2_prompt_pessimo/M2-E01_prompt_pessimo"
readonly E02="${S2}/m2_e3_tre_prompt_due_cicli/M2-E02_tre_prompt_due_cicli"
readonly DEMO=("${D01}" "${D02}" "${D03}" "${D04}" "${D05}" "${D06}")
readonly ELEMENTI=("${DEMO[@]}" "${E01}" "${E02}")
# Per ogni elemento, nello stesso ordine: il file dei risultati, la frase
# della verifica riuscita.
readonly DATI=(confronto.tsv sistema.tsv esiti.tsv etichette.tsv
  ragionamento.tsv orrori.tsv registro.md registro.md)
readonly OK_FRASE=('Esito come nelle registrazioni del corso.'
  'Esito come nelle registrazioni del corso.'
  'Esito come nelle registrazioni del corso.'
  'Esito come nelle registrazioni del corso.'
  'Esito come nelle registrazioni del corso.'
  'Esito come nelle registrazioni del corso.'
  'Fatto: le misure ci sono' 'Fatto: le misure ci sono')
# ...e la frase della verifica sul punto di partenza.
readonly PARTENZA_FRASE=('Manca confronto.tsv' 'Manca sistema.tsv'
  'Manca esiti.tsv' 'Manca etichette.tsv' 'Manca ragionamento.tsv'
  'Manca orrori.tsv' 'servono almeno v0 e v1' 'servono almeno v0 e v1')
readonly KIT=(misura.sh strumenti/kit.py schema-giudizio.json
  .claude/agents/giudice.md .claude/settings.json)
readonly T=$'\t'
TMP=''
PASS=0
FAIL=0
RC=0
OUT=''

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

# Esegue un comando; RC e OUT (STDOUT e STDERR insieme) per expect.
run() { OUT="$("$@" 2>&1)"; RC=$?; }

# Come run, ma OUT è soltanto lo STDERR del comando.
run_err() { OUT="$("$@" 2>&1 >/dev/null)"; RC=$?; }

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

# Un nuovo spazio di lavoro, con il contenuto di una o più cartelle.
# Arguments: $1 la variabile da assegnare, poi le cartelle da copiare.
ws() {
  local __w __c
  __w="$(mktemp -d "${TMP}/ws.XXXXXX")" || { echo "mktemp" >&2; exit 2; }
  for __c in "${@:2}"; do
    cp -R "${__c}/." "${__w}/"
  done
  printf -v "$1" '%s' "${__w}"
}

# Il punto di partenza di un elemento: demo/ o esercizio/.
partenza() {
  if [[ -d "$1/demo" ]]; then
    printf '%s/demo' "$1"
  else
    printf '%s/esercizio' "$1"
  fi
}

# Un comando con il claude finto davanti nel PATH; il registro delle sue
# chiamate riparte vuoto. Arguments: le variabili NOME=valore e il comando.
finto() {
  : > "${TMP}/chiamate.log"
  run env PATH="${TMP}/bin:${PATH}" HANDSON_NO_PAUSE=1 \
    FINTO_LOG="${TMP}/chiamate.log" "$@"
}

# Come finto, ma OUT è soltanto lo STDERR del comando.
finto_err() {
  : > "${TMP}/chiamate.log"
  run_err env PATH="${TMP}/bin:${PATH}" HANDSON_NO_PAUSE=1 \
    FINTO_LOG="${TMP}/chiamate.log" "$@"
}

# Quante chiamate ha ricevuto il claude finto.
chiamate() { grep -c '^chiamata' "${TMP}/chiamate.log"; }

# Il claude finto in ${TMP}/bin, e in ${TMP}/senza_claude un PATH con
# soltanto python3 e readlink (misura.sh --confronta non chiama claude).
prepara_finto() {
  local t
  mkdir -p "${TMP}/bin" "${TMP}/senza_claude" || exit 2
  cp "${MOD}/_docente/claude_finto.py" "${TMP}/bin/claude" || exit 2
  chmod 755 "${TMP}/bin/claude" || exit 2
  for t in python3 readlink; do
    ln -s "$(command -v "${t}")" "${TMP}/senza_claude/${t}" || exit 2
  done
}

# Scrive il JSON di una risposta riuscita di claude -p.
# Arguments: $1 il file, $2 il testo della risposta, $3 (facoltativo) il
# valore di usage.input_tokens, scritto così com'è nel JSON.
risposta_finta() {
  python3 -B -I - "$1" "$2" "${3:-10}" <<'PY'
import json, sys
percorso, testo, entrata = sys.argv[1:4]
json.dump({"type": "result", "is_error": False, "result": testo,
           "usage": {"input_tokens": json.loads(entrata),
                     "output_tokens": 5},
           "modelUsage": {"claude-finto": {}}},
          open(percorso, "w", encoding="utf-8"))
PY
}

# --- I test ---------------------------------------------------------------

# Ogni verifica.sh: spazio di lavoro assente (2), partenza (1), soluzione
# (0), il file dei risultati che non si legge (2).
t_verifiche_base() {
  local i e nome w
  for i in "${!ELEMENTI[@]}"; do
    e="${ELEMENTI[i]}"
    nome="${e##*/}"
    run "${e}/verifica.sh" "${TMP}/assente"
    expect "${nome}: spazio di lavoro assente" 2 "spazio di lavoro assente"
    ws w "$(partenza "${e}")"
    run "${e}/verifica.sh" "${w}"
    expect "${nome}: la partenza non passa" 1 "${PARTENZA_FRASE[i]}"
    ws w "$(partenza "${e}")" "${e}/soluzione"
    run "${e}/verifica.sh" "${w}"
    expect "${nome}: la soluzione passa" 0 "${OK_FRASE[i]}"
    expect_absent "${nome}: la soluzione non ha segnalazioni" "Non ancora"
    if (( EUID == 0 )); then
      echo "  SKIP: ${nome}: da root ogni file si legge"
      continue
    fi
    chmod 000 "${w}/${DATI[i]}"
    run "${e}/verifica.sh" "${w}"
    expect "${nome}: ${DATI[i]} che non si legge" 2 "non si legge"
  done
}

# Le copie identiche.
t_copie() {
  local d f p
  for d in "${DEMO[@]:1}"; do
    if cmp -s "${D01}/demo/leggi_json.py" "${d}/demo/leggi_json.py"; then
      pass "leggi_json.py uguale in ${d##*/}"
    else fail "leggi_json.py diverso in ${d##*/}"; fi
  done
  for f in "${KIT[@]}"; do
    if cmp -s "${E01}/esercizio/${f}" "${E02}/esercizio/${f}"; then
      pass "${f} uguale nelle due esercitazioni"
    else fail "${f} diverso nelle due esercitazioni"; fi
  done
  for f in verifica.py verifica.sh; do
    if cmp -s "${E01}/${f}" "${E02}/${f}"; then
      pass "${f} uguale nelle due esercitazioni"
    else fail "${f} diverso nelle due esercitazioni"; fi
  done
  for d in "${D01}" "${D03}" "${D06}"; do
    if cmp -s "${E01}/esercizio/dati/messaggio.md" "${d}/demo/messaggio.md"
    then pass "il messaggio di ${d##*/} è quello di M2-E01"
    else fail "il messaggio di ${d##*/} è diverso da quello di M2-E01"; fi
  done
  for p in "${D01}/demo/prompt-a.md" "${D01}/demo/prompt-b.md" \
      "${D03}/demo/richiesta-json.md" "${D06}/demo/orrore-1-vaga.md" \
      "${D06}/demo/orrore-2-divieto.md" "${D06}/demo/cura-2-divieto.md" \
      "${D06}/demo/orrore-3-cinque.md"; do
    if grep -qF -- "$(cat "${E01}/esercizio/dati/messaggio.md")" "${p}"; then
      pass "${p##*/} contiene il messaggio intero"
    else fail "${p##*/} non contiene il messaggio intero"; fi
  done
}

# kit.py, senza claude, in una copia dell'esercizio di M2-E01.
t_kit() {
  local w kit
  ws w "${E01}/esercizio"
  kit="${w}/strumenti/kit.py"
  run python3 -B "${kit}" componi "${w}" v0
  expect "kit: componi sostituisce il segnaposto" 0 "Falegnameria Fittizia"
  expect_absent "kit: componi non lascia graffe" "{{messaggio}}"
  printf 'ciao {{assente}}\n' > "${w}/prompt/v9.md"
  run python3 -B "${kit}" componi "${w}" v9
  expect "kit: segnaposto senza dati" 2 "non c'è un file con quel nome"
  run python3 -B "${kit}" componi "${w}" vx
  expect "kit: versione non valida" 2 "non valida"
  run python3 -B "${kit}" estrai "${w}" v0
  expect "kit: estrai senza risposta" 2 "manca il file"
  mkdir -p "${w}/risposte"
  printf '{"type":"result","is_error":true,"result":"x"}\n' \
    > "${w}/risposte/v0.json"
  run python3 -B "${kit}" controlla "${w}" v0
  expect "kit: controlla su una risposta con errore esce 2" 2 \
    "errore di Claude Code"
  python3 -B -I - "${w}/risposte/v0.json" <<'PY'
import json, sys
t = ("Firma: [Nome e cognome]\nLa richiamiamo al +39 000 000 0103.\n"
     + "parola " * 160)
json.dump({"type": "result", "is_error": False, "result": t,
           "usage": {"input_tokens": 10, "output_tokens": 5},
           "modelUsage": {"claude-finto": {}}}, open(sys.argv[1], "w"))
PY
  run python3 -B "${kit}" controlla "${w}" v0
  expect "kit: controlla trova il telefono" 1 "trovato «000 000 0103»"
  expect "kit: controlla trova il segnaposto" 1 "[Nome e cognome]"
  expect "kit: controlla conta le parole" 1 "Controlli v0: 0 superati su 3"
  run python3 -B "${kit}" consegna "${w}" v0
  expect "kit: la consegna porta la rubrica" 0 "- impegni:"
  expect "kit: la consegna porta i dati" 0 "<procedure>"
  expect "kit: la consegna porta la risposta" 0 "<risposta>"
  mkdir -p "${w}/giudizi"
  printf '%s\n' '{"type":"result","is_error":false,"result":"",' \
    '"structured_output":{"criteri":[{"id":"domande","motivo":"m",' \
    '"rispettato":true}]}}' > "${w}/giudizi/v0.json"
  run python3 -B "${kit}" giudizio "${w}" v0
  expect "kit: il giudizio al singolare" 0 "1 affermazione rispettata su 5"
  expect "kit: un'affermazione non valutata" 0 "non valutato dal giudice"
  printf '{"type":"result","is_error":false,"result":""}\n' \
    > "${w}/giudizi/v0.json"
  run python3 -B "${kit}" giudizio "${w}" v0
  expect "kit: un giudizio senza structured_output" 1 "structured_output"
  printf 'tipo\tvalore\n' > "${w}/controlli.tsv"
  run python3 -B "${kit}" controlla "${w}" v0
  expect "kit: controlli.tsv senza intestazione" 2 "la prima riga"
  run python3 -B "${kit}" boh "${w}"
  expect "kit: comando sconosciuto" 2 "componi   <cartella> <versione>"
}

# verifica.py, sui due modi.
t_verifica_regole() {
  local w f
  ws w "${E01}/esercizio" "${E01}/soluzione"
  cp "${w}/prompt/v0.md" "${w}/prompt/v1.md"
  run "${E01}/verifica.sh" "${w}"
  expect "E01: v1 uguale a v0" 1 "uguale a prompt/v0.md"
  ws w "${E01}/esercizio" "${E01}/soluzione"
  cp "${w}/giudizi/v0.json" "${w}/giudizi/v1.json"
  cp "${w}/controlli/v0.txt" "${w}/controlli/v1.txt"
  run "${E01}/verifica.sh" "${w}"
  expect "E01: nessun miglioramento" 1 "non migliora"
  ws w "${E01}/esercizio" "${E01}/soluzione"
  cp "${w}/risposte/v0.json" "${w}/risposte/v1.json"
  run "${E01}/verifica.sh" "${w}"
  expect "E01: l'ultima versione ripete il telefono" 1 "telefono"
  ws w "${E01}/esercizio" "${E01}/soluzione"
  cp "${E01}/esercizio/registro.md" "${w}/registro.md"
  run "${E01}/verifica.sh" "${w}"
  expect "E01: registro da compilare" 1 "compilate la riga di v0"
  ws w "${E02}/esercizio" "${E02}/soluzione"
  rm -rf "${w}/sistemi"
  run "${E02}/verifica.sh" "${w}"
  expect "E02: una famiglia mancante" 1 "manca la cartella sistemi"
  ws w "${E02}/esercizio" "${E02}/soluzione"
  for f in sviluppo supporto; do
    rm -f "${w}/${f}/risposte/v2.json"
  done
  run "${E02}/verifica.sh" "${w}"
  expect "E02: due cicli su una famiglia sola" 1 \
    "famiglie con due cicli (v2): 1 su tre; ne servono almeno due"
  ws w "${E02}/esercizio" "${E02}/soluzione"
  cp "${w}/sistemi/giudizi/v0.json" "${w}/sistemi/giudizi/v2.json"
  sed -i 's/^totale\t.*/totale\t0\/3/' "${w}/sistemi/controlli/v2.txt"
  run "${E02}/verifica.sh" "${w}"
  expect "E02: una famiglia peggiora" 1 "peggiorano: sistemi"
}

# leggi_json.py, orario.py.
t_aiutanti() {
  local lj="${D01}/demo/leggi_json.py" or="${D05}/demo/orario.py" j
  j='{"type":"result","is_error":false,"result":"ok","usage":'
  j+='{"input_tokens":2,"output_tokens":7},"structured_output":{"a":1}}'
  OUT="$(printf '%s' "${j}" | python3 -B -I "${lj}" token_thinking 2>&1)"
  RC=$?
  expect "leggi_json: thinking assente vale 0" 0 "0"
  OUT="$(printf '%s' "${j}" | python3 -B -I "${lj}" structured_output 2>&1)"
  RC=$?
  expect "leggi_json: structured_output in JSON" 0 '{"a": 1}'
  OUT="$(printf '' | python3 -B -I "${lj}" result 2>&1)"; RC=$?
  expect "leggi_json: nessun JSON" 1 "nessun JSON"
  OUT="$(printf '%s' "${j}" | python3 -B -I "${lj}" boh 2>&1)"; RC=$?
  expect "leggi_json: dato sconosciuto" 2 "Uso"
  j='{"is_error":false,"result":"dalle 09:00 ... alle **9:36** (inizio 9:00)"}'
  OUT="$(printf '%s' "${j}" | python3 -B -I "${or}" 9:00 2>&1)"; RC=$?
  expect "orario: esclude l'orario di partenza" 0 "9:36"
  j='{"result":"**Risposta finale:** esce alle **9:36**.\n\n(il turno '
  j+='inizia alle 9:32)"}'
  OUT="$(printf '%s' "${j}" | python3 -B -I "${or}" 9:00 2>&1)"; RC=$?
  expect "orario: la riga della risposta finale" 0 "9:36"
  expect_absent "orario: non l'orario aggiunto dopo" "9:32"
  OUT="$(printf '%s' '{"result":"alle nove"}' | python3 -B -I "${or}" \
    9:00 2>&1)"; RC=$?
  expect "orario: nessun orario" 1 "nessun orario"
  OUT="$(printf '{}' | python3 -B -I "${or}" nove 2>&1)"; RC=$?
  expect "orario: argomento non valido" 2 "Uso"
}

# controlla_json.py: lo schema che manca, il blocco di codice (la colonna
# blocco_codice, a schermo e in esiti.tsv), enum e chiavi richieste.
t_controlla_json() {
  local w j
  ws w "${D03}/demo"
  mkdir -p "${w}/risposte"
  for j in haiku sonnet; do
    printf '{"is_error":false,"result":"{\\"a\\": 1}"}\n' \
      > "${w}/risposte/solo-json-${j}.json"
  done
  # shellcheck disable=SC2016  # il blocco di codice è testo
  printf '{"is_error":false,"result":"```json\\n{}\\n```"}\n' \
    > "${w}/risposte/solo-json-opus.json"
  run bash -c "cd '${w}' && python3 -B -I controlla_json.py"
  expect "controlla_json: manca lo schema" 1 "schema-haiku.json"
  printf '%s\n' '{"is_error":false,"result":"x","structured_output":' \
    '{"tipo_cliente":"ditta"}}' > "${w}/risposte/schema-haiku.json"
  run bash -c "cd '${w}' && python3 -B -I controlla_json.py"
  expect "controlla_json: il blocco di codice" 0 "solo-json-opus.json  no  sì"
  expect "controlla_json: la colonna blocco_codice a schermo" 0 \
    "file  json_valido  blocco_codice  telefono  schema_valido"
  expect_absent "controlla_json: nessuna colonna recinti" "recinti"
  if [[ "$(head -n 1 "${w}/esiti.tsv")" \
      == "file${T}json_valido${T}blocco_codice${T}telefono${T}schema_valido" ]]
  then pass "controlla_json: la colonna blocco_codice in esiti.tsv"
  else fail "controlla_json: $(head -n 1 "${w}/esiti.tsv")"; fi
  if grep -q "^schema-haiku.json${T}sì${T}—${T}no${T}no$" "${w}/esiti.tsv"
  then pass "controlla_json: enum e chiavi richieste"
  else fail "controlla_json: $(tail -1 "${w}/esiti.tsv")"; fi
}

# I live.sh e misura.sh con il claude finto.
t_finti() {
  local e w v
  for e in "${ELEMENTI[@]}"; do
    ws w "$(partenza "${e}")"
    finto "${e}/_docente/live.sh" "${w}"
    expect "${e##*/}: live.sh con le risposte complete" 0 "VERIFICA OK"
    ws w "$(partenza "${e}")"
    finto FINTO_ESITO=ko "${e}/_docente/live.sh" "${w}"
    if [[ -d "${e}/esercizio" ]]; then
      expect "${e##*/}: claude fallito esce 1" 1 "fallito il passo"
    else
      expect "${e##*/}: claude fallito esce 1" 1 "VERIFICA KO"
    fi
  done
  for e in "${D01}" "${D02}" "${D06}"; do
    ws w "$(partenza "${e}")"
    finto PN_MODELLO=fable "${e}/_docente/live.sh" "${w}"
    expect "${e##*/}: modello non ammesso" 2 "non ammesso"
    v="$(chiamate)"
    if (( v == 0 )); then pass "${e##*/}: nessuna chiamata a claude"
    else fail "${e##*/}: ${v} chiamate a claude"; fi
  done
  ws w "${E01}/esercizio"
  finto ANTHROPIC_API_KEY=finta "${w}/misura.sh" v0
  expect "misura.sh: una misura completa" 0 "Giudizio v0"
  if grep -q 'CHIAVE' "${TMP}/chiamate.log"; then
    fail "misura.sh: ANTHROPIC_API_KEY arriva a claude"
  else pass "misura.sh: ANTHROPIC_API_KEY tolta"; fi
  finto "${w}/misura.sh" v0 --modello fable
  expect "misura.sh: modello non ammesso" 2 "si usa haiku, sonnet o opus"
  finto "${w}/misura.sh" --confronta v0
  expect "misura.sh: confronto senza due versioni" 2 "uso:"
  finto FINTO_ESITO=ko "${w}/misura.sh" v0
  expect "misura.sh: claude fallito" 1 "non è arrivata"
}

# Le due esercitazioni: al primo passo di misura.sh che fallisce la prova
# si ferma, con l'uscita di misura.sh (1 una chiamata fallita, 2 una
# precondizione) e una riga su STDERR che nomina il passo.
t_live_esercitazioni() {
  local e w v primo
  for e in "${E01}" "${E02}"; do
    primo='la misura di v0'
    [[ "${e}" == "${E01}" ]] || primo="sviluppo: ${primo}"
    ws w "$(partenza "${e}")"
    finto_err FINTO_ESITO=ko "${e}/_docente/live.sh" "${w}"
    expect "${e##*/}: una chiamata fallita esce 1, su STDERR il passo" 1 \
      "fallito il passo «${primo}» (uscita 1)"
    v="$(grep -c 'fallito il passo' <<< "${OUT}")"
    if (( v == 1 )); then pass "${e##*/}: il passo fallito in una riga"
    else fail "${e##*/}: ${v} righe sul passo fallito"; fi
    v="$(chiamate)"
    if (( v == 1 )); then pass "${e##*/}: si ferma alla prima chiamata"
    else fail "${e##*/}: ${v} chiamate fallite, attesa una"; fi
    ws w "$(partenza "${e}")"
    rm "${w}/schema-giudizio.json"
    finto_err "${e}/_docente/live.sh" "${w}"
    expect "${e##*/}: una precondizione di misura.sh resta 2" 2 \
      "fallito il passo «${primo}» (uscita 2)"
    v="$(chiamate)"
    if (( v == 0 )); then pass "${e##*/}: precondizione, nessuna chiamata"
    else fail "${e##*/}: ${v} chiamate a claude"; fi
  done
}

# Il prompt arriva a claude come operando, dopo «--»: un prompt che
# comincia con «- » si misura; un testo oltre i 100000 byte si ferma prima
# di ogni chiamata, con un messaggio che nomina i file.
t_operando() {
  local w v
  ws w "${E01}/esercizio"
  cat > "${w}/prompt/v1.md" <<'EOF'
- Ruolo: un operatore dell'assistenza clienti.
- Compito: rispondi al messaggio tra i tag.

<messaggio>
{{messaggio}}
</messaggio>
EOF
  finto "${w}/misura.sh" v1
  expect "misura.sh: un prompt che comincia con «- » si misura" 0 \
    "Giudizio v1"
  expect "misura.sh: il prompt arriva intero, con i tag" 0 \
    "Gentile signor Fittizio"
  ws w "${E01}/esercizio"
  printf 'parola %.0s' {1..17200} > "${w}/dati/messaggio.md"
  finto "${w}/misura.sh" v0
  expect "misura.sh: dati oltre il limite escono 2" 2 \
    "oltre il limite di 100000 byte"
  expect "misura.sh: il limite nomina il file dei dati" 2 \
    "dati/messaggio.md 120400 byte"
  v="$(chiamate)"
  if (( v == 0 )); then pass "misura.sh: oltre il limite, nessuna chiamata"
  else fail "misura.sh: oltre il limite, ${v} chiamate a claude"; fi
  ws w "${E01}/esercizio"
  mkdir -p "${w}/risposte"
  risposta_finta "${w}/risposte/v0.json" "$(printf 'parola %.0s' {1..15000})"
  run python3 -B "${w}/strumenti/kit.py" consegna "${w}" v0
  expect "kit: una consegna al giudice oltre il limite esce 2" 2 \
    "risposte/v0.md 105000 byte"
}

# Il contratto d'uscita di kit.py controlla (0 ogni controllo superato,
# 1 almeno uno non superato, 2 un errore), e mai un traceback su un dato
# rovinato: una cifra Unicode, un TAB nel testo trovato, un usage non
# numerico, un JSON annidato a dismisura.
t_contratto_kit() {
  local w kit
  ws w "${E01}/esercizio"
  kit="${w}/strumenti/kit.py"
  mkdir -p "${w}/risposte"
  risposta_finta "${w}/risposte/v0.json" "Gentile signor Fittizio, a presto."
  run python3 -B "${kit}" controlla "${w}" v0
  expect "kit: controlla con ogni controllo superato esce 0" 0 \
    "3 superati su 3"
  risposta_finta "${w}/risposte/v0.json" "Il suo numero: +39 000 000 0103."
  run python3 -B "${kit}" controlla "${w}" v0
  expect "kit: controlla con un controllo non superato esce 1" 1 \
    "2 superati su 3"
  printf 'tipo\tvalore\tdescrizione\nparole_max\t\xc2\xb2\tdue parole\n' \
    > "${w}/controlli.tsv"
  run python3 -B "${kit}" controlla "${w}" v0
  expect "kit: «²» non è un numero" 2 "«parole_max» vuole un numero"
  expect_absent "kit: «²» senza traceback" "Traceback"
  printf 'tipo\tvalore\tdescrizione\nassente\tcliente,\\s+saluti\tsaluti\n' \
    > "${w}/controlli.tsv"
  risposta_finta "${w}/risposte/v0.json" $'Caro cliente,\tsaluti.'
  run python3 -B "${kit}" controlla "${w}" v0
  expect "kit: un TAB nel testo trovato" 1 "trovato «cliente, saluti»"
  expect_absent "kit: un TAB senza traceback" "Traceback"
  risposta_finta "${w}/risposte/v0.json" "Va bene." '"n/d"'
  run python3 -B "${kit}" estrai "${w}" v0
  expect "kit: un usage non numerico" 1 "input_tokens non è un numero"
  expect_absent "kit: un usage non numerico senza traceback" "Traceback"
  printf '[%.0s' {1..100000} > "${w}/risposte/v0.json"
  run python3 -B "${kit}" estrai "${w}" v0
  expect "kit: un JSON annidato a dismisura" 1 "non è un JSON valido"
  expect_absent "kit: un JSON annidato senza traceback" "Traceback"
}

# misura.sh: i controlli che non girano (qui controlli/ che non si scrive:
# controlli.tsv rotto si ferma già prima della chiamata) fermano la misura
# con l'uscita 2, prima del giudizio; un controllo non superato no.
t_contratto_misura() {
  local w v
  if (( EUID == 0 )); then
    echo "  SKIP: misura.sh: da root ogni cartella si scrive"
  else
    ws w "${E01}/esercizio"
    mkdir -p "${w}/controlli"
    chmod 555 "${w}/controlli"
    finto "${w}/misura.sh" v0
    expect "misura.sh: controlli che non girano escono 2" 2 \
      "i controlli di v0 non sono riusciti"
    expect_absent "misura.sh: dopo i controlli falliti nessun giudizio" \
      "Giudizio v0"
    v="$(chiamate)"
    if (( v == 1 )); then pass "misura.sh: una chiamata sola, la risposta"
    else fail "misura.sh: ${v} chiamate a claude, attesa una"; fi
    chmod 755 "${w}/controlli"
  fi
  ws w "${E01}/esercizio"
  finto "${w}/misura.sh" v0
  expect "misura.sh: un controllo non superato non ferma la misura" 0 \
    "Controlli v0: 1 superato su 3"
  expect "misura.sh: dopo i controlli, il giudizio" 0 "Giudizio v0"
}

# verifica.py: una misura rovinata è da rifare (uscita 1, il comando per
# rifarla), mai un traceback; una cartella che non si legge esce 2.
t_contratto_verifica() {
  local w d
  ws w "${E01}/esercizio" "${E01}/soluzione"
  python3 -B -I - "${w}/risposte/v1.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
d["usage"]["input_tokens"] = "n/d"
json.dump(d, open(sys.argv[1], "w", encoding="utf-8"))
PY
  run "${E01}/verifica.sh" "${w}"
  expect "verifica: un usage non numerico va rimisurato" 1 \
    "misurate di nuovo v1"
  ws w "${E01}/esercizio" "${E01}/soluzione"
  printf '{"type": "result",' > "${w}/giudizi/v1.json"
  run "${E01}/verifica.sh" "${w}"
  expect "verifica: un giudizio rovinato va rimisurato" 1 \
    "giudizi/v1.json non è un JSON valido: misurate di nuovo v1"
  printf '[%.0s' {1..100000} > "${w}/giudizi/v1.json"
  run "${E01}/verifica.sh" "${w}"
  expect "verifica: un JSON annidato a dismisura" 1 "non è un JSON valido"
  expect_absent "verifica: un JSON annidato senza traceback" "Traceback"
  ws w "${E01}/esercizio" "${E01}/soluzione"
  printf '\xff\xfe' > "${w}/controlli/v1.txt"
  run "${E01}/verifica.sh" "${w}"
  expect "verifica: controlli/v1.txt non UTF-8 va rimisurato" 1 \
    "mancano i controlli di v1: misurate di nuovo v1"
  if (( EUID == 0 )); then
    echo "  SKIP: verifica: da root ogni cartella si legge"
    return 0
  fi
  ws w "${E01}/esercizio" "${E01}/soluzione"
  for d in risposte giudizi .; do
    chmod 000 "${w}/${d}"
    run "${E01}/verifica.sh" "${w}"
    expect "verifica: la cartella ${d} che non si legge esce 2" 2 \
      "non si legge"
    chmod 755 "${w}/${d}"
  done
}

# Una precondizione, con il claude finto: uscita 2, la parola attesa, e
# nessuna chiamata a claude. Arguments: $1 il nome, $2 la parola, poi il
# comando.
precondizione() {
  local nome="$1" parola="$2" v
  shift 2
  finto "$@"
  expect "${nome}" 2 "${parola}"
  v="$(chiamate)"
  if (( v == 0 )); then pass "${nome}: nessuna chiamata a claude"
  else fail "${nome}: ${v} chiamate a claude"; fi
}

# I rami fail-closed che nessuna prova toccava, negli strumenti delle
# esercitazioni: le precondizioni di misura.sh; i formati che kit.py
# rifiuta; parole_min e il confronto.
t_rami() {
  local w kit
  ws w "${E01}/esercizio"
  precondizione "misura.sh: una cartella assoluta" "fuori dall'esercizio" \
    "${w}/misura.sh" /tmp v0
  precondizione "misura.sh: una cartella con «..»" "fuori dall'esercizio" \
    "${w}/misura.sh" prompt/.. v0
  precondizione "misura.sh: un'opzione sconosciuta" \
    "opzione sconosciuta: --boh" "${w}/misura.sh" v0 --boh
  precondizione "misura.sh: un effort sbagliato" "effort «max»" \
    "${w}/misura.sh" v0 --effort max
  precondizione "misura.sh: un prompt che manca" "manca ./prompt/v7.md" \
    "${w}/misura.sh" v7
  kit="${w}/strumenti/kit.py"
  cp "${w}/dati/messaggio.md" "${w}/dati/messaggio.txt"
  run python3 -B "${kit}" componi "${w}" v0
  expect "kit: due file di dati con lo stesso nome" 2 \
    "due file si chiamano «messaggio»"
  rm "${w}/dati/messaggio.txt"
  mkdir -p "${w}/risposte"
  risposta_finta "${w}/risposte/v0.json" "una due tre"
  printf -- '- **domande**: di nuovo.\n' >> "${w}/rubrica.md"
  run python3 -B "${kit}" consegna "${w}" v0
  expect "kit: un id della rubrica ripetuto" 2 "compare due volte"
  printf 'tipo\tvalore\tdescrizione\nassente\t[\tuna parentesi\n' \
    > "${w}/controlli.tsv"
  run python3 -B "${kit}" controlla "${w}" v0
  expect "kit: un'espressione non valida" 2 "espressione non valida"
  printf 'tipo\tvalore\tdescrizione\n' > "${w}/controlli.tsv"
  run python3 -B "${kit}" controlla "${w}" v0
  expect "kit: controlli.tsv senza controlli" 2 "non contiene controlli"
  printf 'tipo\tvalore\tdescrizione\nparole_min\t5\talmeno cinque parole\n' \
    > "${w}/controlli.tsv"
  run python3 -B "${kit}" controlla "${w}" v0
  expect "kit: parole_min non raggiunto" 1 "✗ almeno cinque parole (3 parole)"
  risposta_finta "${w}/risposte/v0.json" "una due tre quattro cinque"
  run python3 -B "${kit}" controlla "${w}" v0
  expect "kit: parole_min raggiunto" 0 "✓ almeno cinque parole (5 parole)"
  ws w "${E01}/esercizio" "${E01}/soluzione"
  run python3 -B "${w}/strumenti/kit.py" confronta "${w}" v0 v1
  expect "kit: il confronto, controlli e giudice" 0 \
    "totali: controlli 0/3 → 3/3; giudice 1 → 4 su 5"
  expect "kit: il confronto, i token" 0 "token: in entrata 947 → 1953"
}

# ...e nei live.sh: le precondizioni di una demo e di un'esercitazione; il
# messaggio di verifica.py sulle famiglie che migliorano.
t_rami_live() {
  local w f
  precondizione "M2-D01 live.sh: spazio di lavoro assente" \
    "spazio di lavoro assente" "${D01}/_docente/live.sh" "${TMP}/assente"
  ws w "$(partenza "${D01}")"
  rm "${w}/prompt-b.md"
  precondizione "M2-D01 live.sh: un file di partenza che manca" \
    "file assente o illeggibile: prompt-b.md" "${D01}/_docente/live.sh" "${w}"
  precondizione "M2-E01 live.sh: spazio di lavoro assente" \
    "spazio di lavoro assente" "${E01}/_docente/live.sh" "${TMP}/assente"
  ws w "$(partenza "${E01}")"
  rm "${w}/registro.md"
  precondizione "M2-E01 live.sh: un file di partenza che manca" \
    "file assente o illeggibile: registro.md" "${E01}/_docente/live.sh" "${w}"
  ws w "${E02}/esercizio" "${E02}/soluzione"
  for f in sviluppo supporto; do
    cp "${w}/${f}/giudizi/v0.json" "${w}/${f}/giudizi/v2.json"
    cp "${w}/${f}/controlli/v0.txt" "${w}/${f}/controlli/v2.txt"
  done
  run "${E02}/verifica.sh" "${w}"
  expect "E02: una famiglia sola migliora" 1 \
    "famiglie migliorate: 1 su tre; ne servono almeno due"
}

# Le sei demo: alla prima chiamata fallita si fermano (una chiamata sola);
# su un esito diverso stampano il messaggio di verifica.sh, non soltanto la
# riga del verdetto. L'esito diverso: FINTO_RISPOSTA per cinque demo, per
# M2-D02 un system prompt lungo, che pesa più della metà.
t_demo() {
  local i e w v
  local -a frase=('La risposta a B non è una tabella'
    'Con il system prompt sostituito attesi meno della metà'
    'Con --json-schema atteso un oggetto che rispetta lo schema'
    'attesa la forma degli esempi'
    "Manca l'orario di sportelli, haiku, di-getto"
    "La cura: attesa una risposta che parli dell'indennizzo")
  for i in "${!DEMO[@]}"; do
    e="${DEMO[i]}"
    ws w "$(partenza "${e}")"
    finto FINTO_ESITO=ko "${e}/_docente/live.sh" "${w}"
    v="$(chiamate)"
    if (( RC == 1 && v == 1 )) && grep -qF -- 'VERIFICA KO' <<< "${OUT}"
    then pass "${e##*/}: si ferma alla prima chiamata fallita"
    else fail "${e##*/}: rc=${RC} dopo ${v} chiamate fallite: ${OUT:0:200}"
    fi
    ws w "$(partenza "${e}")"
    if [[ "${e}" == "${D02}" ]]; then
      printf 'Rispondi in italiano. %.0s' {1..600} > "${w}/istruzione.txt"
      finto "${e}/_docente/live.sh" "${w}"
    else
      finto FINTO_RISPOSTA='Non lo so.' "${e}/_docente/live.sh" "${w}"
    fi
    expect "${e##*/}: su un KO il messaggio di verifica.sh" 1 "${frase[i]}"
  done
}

# Le parole che i partecipanti leggono: il controllo di M2-E02 sul blocco
# di codice dice soltanto che cosa controlla.
t_etichette() {
  local w
  run cat "${E02}/esercizio/sviluppo/controlli.tsv"
  expect "M2-E02: il controllo del blocco di codice" 0 \
    "contiene un blocco di codice"
  expect_absent "M2-E02: il controllo non promette una correzione" \
    "codice della correzione"
  ws w "${E02}/esercizio"
  finto "${w}/misura.sh" sviluppo v0
  expect "M2-E02: misura.sh stampa il controllo del blocco di codice" 0 \
    "contiene un blocco di codice"
  run grep -rl -e recinti -e 'virgolette di codice' "${D03}"
  if (( RC == 1 )) && [[ -z "${OUT}" ]]; then
    pass "M2-D03: «blocco di codice», non «recinti» né «virgolette di codice»"
  else fail "M2-D03: i nomi vecchi in ${OUT}"; fi
  ws w "$(partenza "${D06}")" "${D06}/soluzione"
  awk -F'\t' -v OFS='\t' '$1 == "orrore-4-memoria" { $6 = "Va bene." }
    { print }' "${w}/orrori.tsv" > "${w}/orrori.nuovo"
  mv "${w}/orrori.nuovo" "${w}/orrori.tsv"
  run "${D06}/verifica.sh" "${w}"
  expect "M2-D06: la memoria che non chiede" 1 \
    "attesa una risposta che chieda ciò che manca"
}

# Il frontmatter del giudice: su Haiku, senza gli strumenti che scrivono o
# eseguono (disallowedTools), e senza un elenco tools che li riapra.
t_giudice() {
  local g="${E01}/esercizio/.claude/agents/giudice.md"
  run awk 'NR == 1 && /^---$/ { d = 1; next } d && /^---$/ { exit } d' "${g}"
  expect "giudice: niente Bash, Edit, Write, NotebookEdit" 0 \
    "disallowedTools: Bash, Edit, Write, NotebookEdit"
  expect "giudice: su Haiku" 0 "model: haiku"
  if grep -q '^tools:' <<< "${OUT}"; then fail "giudice: una riga tools:"
  else pass "giudice: nessuna riga tools:"; fi
}

# Una misura nuova toglie prima la vecchia della stessa versione: una
# misura fermata a metà non lascia un insieme misto che passa per
# completo. La verifica chiede di misurare di nuovo, il confronto esce 2;
# la versione si controlla prima di togliere qualcosa.
t_misura_nuova() {
  local w
  ws w "${E01}/esercizio" "${E01}/soluzione"
  printf 'assente\tsolo due campi\n' >> "${w}/controlli.tsv"
  finto "${w}/misura.sh" v1
  expect "rimisura: controlli.tsv rotto, misura.sh esce 2" 2 \
    "attesi tre campi"
  run "${E01}/verifica.sh" "${w}"
  expect "rimisura: la verifica chiede di misurare v1" 1 "./misura.sh v1)"
  expect_absent "rimisura: la verifica non dice «Fatto»" "Fatto"
  ws w "${E01}/esercizio" "${E01}/soluzione"
  finto FINTO_RISPOSTA="$(printf 'parola %.0s' {1..15000})" \
    "${w}/misura.sh" v1
  expect "rimisura: una consegna troppo lunga dopo la risposta esce 2" 2 \
    "la consegna al giudice di v1 è troppo lunga"
  run "${E01}/verifica.sh" "${w}"
  expect "rimisura: il giudizio vecchio non conta" 1 \
    "manca giudizi/v1.json: misurate di nuovo v1"
  finto "${w}/misura.sh" --confronta v0 v1
  expect "rimisura: il confronto con una misura a metà esce 2" 2 \
    "la misura di v1 è incompleta"
  ws w "${E01}/esercizio"
  mkdir -p "${w}/risposte"
  printf 'x\n' > "${w}/x.md"
  printf 'x\n' > "${w}/x.json"
  precondizione "misura.sh: una versione che non è vN" \
    "misura.sh: versione «../x» non valida" "${w}/misura.sh" ../x
  if [[ -f "${w}/x.json" ]]; then pass "misura.sh: niente tolto fuori"
  else fail "misura.sh: ha tolto x.json fuori da risposte/"; fi
}

# Prima della chiamata a pagamento, misura.sh controlla ciò che il
# partecipante modifica: le righe di controlli.tsv, gli id della rubrica,
# il peso della consegna al giudice senza la risposta (la rubrica e ogni
# file di dati/, anche quelli che il prompt non usa). Uscita 2, i messaggi
# di sempre, nessuna chiamata.
t_prima_della_chiamata() {
  local w
  ws w "${E01}/esercizio"
  printf 'assente\tsolo due campi\n' >> "${w}/controlli.tsv"
  precondizione "misura.sh: una riga rotta di controlli.tsv" \
    "attesi tre campi" "${w}/misura.sh" v0
  ws w "${E01}/esercizio"
  printf 'tipo\tvalore\tdescrizione\nparole_max\t\xc2\xb2\tdue parole\n' \
    > "${w}/controlli.tsv"
  precondizione "misura.sh: un numero di controlli.tsv che non è un numero" \
    "«parole_max» vuole un numero" "${w}/misura.sh" v0
  ws w "${E01}/esercizio"
  printf -- '- **domande**: di nuovo.\n' >> "${w}/rubrica.md"
  precondizione "misura.sh: un id della rubrica ripetuto" \
    "compare due volte" "${w}/misura.sh" v0
  ws w "${E01}/esercizio"
  printf 'parola %.0s' {1..17200} > "${w}/dati/procedure.md"
  precondizione "misura.sh: un file di dati non usato, oltre il limite" \
    "la consegna al giudice di v0 è troppo lunga" "${w}/misura.sh" v0
}

# Le opzioni di misura.sh: un'opzione senza valore esce 2 con un messaggio
# su STDERR; --help stampa l'uso e basta; --confronta non chiede claude.
# E nessuna attesa in secondi che nessuna fonte registra.
t_opzioni() {
  local w o
  ws w "${E01}/esercizio"
  for o in modello effort; do
    run_err env PATH="${TMP}/bin:${PATH}" "${w}/misura.sh" v0 "--${o}"
    expect "misura.sh: --${o} senza valore esce 2, su STDERR" 2 "${o} «»"
  done
  run "${w}/misura.sh" --help
  expect "misura.sh --help: l'uso" 0 "./misura.sh --confronta [cartella]"
  expect_absent "misura.sh --help: senza le righe di codice" "set -euo"
  ws w "${E01}/esercizio" "${E01}/soluzione"
  run env PATH="${TMP}/senza_claude" "${w}/misura.sh" --confronta v0 v1
  expect "misura.sh --confronta senza claude nel PATH" 0 \
    "totali: controlli 0/3 → 3/3"
  run cat "${E01}/esercizio/misura.sh"
  expect_absent "misura.sh: nessuna attesa in secondi non verificata" \
    "tre secondi"
}

# Lo shellcheck di ogni script del modulo, e di questo.
t_shellcheck() {
  local f
  while IFS= read -r -d '' f; do
    if shellcheck -x "${f}" > /dev/null 2>&1; then
      pass "shellcheck ${f#"${RADICE}"/}"
    else
      fail "shellcheck ${f#"${RADICE}"/}"
    fi
  done < <(find "${MOD}" -name '*.sh' -print0 | sort -z)
}

main() {
  local t
  for t in jq python3 shellcheck sha256sum; do
    command -v "${t}" >/dev/null 2>&1 \
      || { echo "test_m2_script: manca ${t}" >&2; exit 2; }
  done
  for t in "${ELEMENTI[@]}"; do
    [[ -d "${t}" ]] || { echo "test_m2_script: manca ${t}" >&2; exit 2; }
  done
  TMP="$(mktemp -d)" || exit 2
  trap 'chmod -R u+rwX "${TMP}" 2>/dev/null; rm -rf "${TMP}"' EXIT
  cd "${RADICE}" || exit 2
  prepara_finto
  t_verifiche_base
  t_copie
  t_kit
  t_verifica_regole
  t_aiutanti
  t_controlla_json
  t_finti
  t_live_esercitazioni
  t_operando
  t_contratto_kit
  t_contratto_misura
  t_contratto_verifica
  t_opzioni
  t_rami
  t_rami_live
  t_misura_nuova
  t_prima_della_chiamata
  t_giudice
  t_demo
  t_etichette
  t_shellcheck
  echo "PASS=${PASS} FAIL=${FAIL}"
  (( FAIL == 0 )) || exit 1
}

main "$@"
