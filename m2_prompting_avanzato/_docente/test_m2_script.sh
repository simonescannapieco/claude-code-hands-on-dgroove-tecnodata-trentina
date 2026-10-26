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
#   - le versioni: misura.sh, kit.py e verifica.py ammettono soltanto vN
#     (^v(0|[1-9][0-9]*)$): v2b e v01 li rifiutano misura.sh e kit.py,
#     verifica.py non li conta né come ultima versione né come ciclo;
#   - verifica.py: le regole delle due esercitazioni (prompt uguale,
#     registro vuoto, famiglia mancante, due cicli); gli esiti che stampa
#     senza fermare la verifica (una pratica non confermata, una famiglia
#     che peggiora o che migliora da sola, il telefono ripetuto nella
#     risposta di v2); una misura rovinata da rifare; una cartella che non
#     si legge (2); i controlli rifatti sulla risposta, in verifica.py e
#     in --confronta: controlli/<v>.txt manomesso, non UTF-8 o assente
#     non cambia né i totali né gli esiti né l'uscita;
#   - leggi_json.py e orario.py sui casi limite (i controlli delle demo e il
#     kit delle esercitazioni hanno le loro suite: test_m2_d01_d02.sh,
#     test_m2_d03.sh … test_m2_d06.sh, test_m2_kit.sh);
#   - i live.sh e misura.sh con il claude finto (_docente/claude_finto.py):
#     le precondizioni escono 2 senza chiamare claude, una chiamata fallita
#     esce 1 (le demo si fermano lì) e su un esito diverso si legge il
#     messaggio di verifica.sh (le sei demo lo stampano con handson::check
#     della libreria, senza una copia locale), le risposte complete
#     escono 0;
#     ANTHROPIC_API_KEY non arriva a claude; il prompt dopo «--», il limite
#     dei 100000 byte, le opzioni di misura.sh;
#   - i live.sh delle due esercitazioni con una verifica.sh finta, in una
#     copia dell'elemento: se la verifica esce 2 la prova esce 2 (una
#     precondizione, su STDERR), se esce 1 resta un KO, se esce 0 passa e
#     ne stampa l'uscita;
#   - il frontmatter del giudice, le parole che i partecipanti leggono;
#   - shellcheck -x su ogni script del modulo e su questo.
# Gli spazi di lavoro nascono in una cartella temporanea: l'albero del
# repository non cambia. I casi si contano: da root i casi dei file e delle
# cartelle che non si leggono sono saltati e contati a parte (SKIP), e un
# numero di casi diverso da CASES esce 2. CASES conta anche uno shellcheck
# per ogni script del modulo: uno script in più o in meno lo cambia.
#
# Uso:    m2_prompting_avanzato/_docente/test_m2_script.sh
# Uscita: 0 = tutte le prove passano · 1 = almeno una fallita
#         2 = precondizione (manca jq, python3, shellcheck o sha256sum, o la
#             cartella di un elemento, o le prove eseguite non sono quante
#             attese)
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
# Per ogni elemento, nello stesso ordine: il file che la verifica legge
# (per M2-D03 e M2-D04 una risposta: la verifica decide dalle risposte,
# mai da esiti.tsv), la frase della verifica riuscita.
readonly FATTO='Fatto: ogni affermazione è stata messa alla prova'
readonly DATI=(confronto.tsv sistema.tsv risposte/schema-haiku.json
  risposte/schema-haiku.json ragionamento.tsv orrori.tsv registro.md
  registro.md)
readonly OK_FRASE=("${FATTO}" "${FATTO}" "${FATTO}" "${FATTO}" "${FATTO}"
  "${FATTO}" "${FATTO}" "${FATTO}")
# ...e la frase della verifica sul punto di partenza.
readonly PARTENZA_FRASE=('Manca confronto.tsv' 'Manca sistema.tsv'
  'Manca la cartella risposte/' 'Manca la cartella risposte/'
  'Manca ragionamento.tsv' 'Manca orrori.tsv' 'servono almeno v0 e v1'
  'servono almeno v0 e v1')
readonly KIT=(misura.sh strumenti/kit.py schema-giudizio.json
  .claude/agents/giudice.md .claude/settings.json)
# Le righe intere che kit.py confronta stampa sul confronto di v0 e v1
# della soluzione di M2-E01.
readonly E01_TOTALI='  totali: controlli 0/3 → 3/3; giudice 2 → 3 su 5'
readonly E01_TOKEN='  token: in entrata 926 → 1932, in uscita 849 → 294'
readonly E01_CRITERI="    su 7 in v0, 6 su 7 in v1; non rispettati in v1: \
impegni)"
# ...e quelle che verifica.py stampa sulla stessa soluzione: i totali di v0
# e di v1, l'esito di chiarezza e i suoi conteggi.
readonly E01_V0="  v0: controlli 0/3, giudice 2/5; due giudizi, stesso esito \
su 5 di 5,"
readonly E01_V1='  v1: controlli 3/3, giudice 3/5'
readonly E01_CHIAREZZA="  v1 rispetto a v0, chiarezza: confermata (criteri \
segnati [chiarezza]"
readonly E01_CONTEGGI="    rispettati: 2 su 7 in v0, 6 su 7 in v1; non \
rispettati in v1: impegni)"
# Nella soluzione di M2-E02, supporto: i totali di v1 che stampa
# verifica.py, quelli del confronto di v0 e v1.
readonly E02_SUP_V1='  v1: controlli 4/4, giudice 4/5'
readonly E02_SUP_TOTALI='  totali: controlli 2/4 → 4/4; giudice 4 → 4 su 5'
readonly CASES=309
TMP=''
PASS=0
FAIL=0
SKIP=0
RC=0
OUT=''

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }
# Un caso che da root non può girare: contato a parte, mai come passato.
skip() { echo "  SKIP: $1"; SKIP=$((SKIP + 1)); }

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

# Uscita attesa E una riga intera di OUT, uguale carattere per carattere.
# Arguments: $1 il nome, $2 l'uscita attesa, $3 la riga (grep -xF).
expect_riga() {
  if (( RC == $2 )) && grep -qxF -- "$3" <<< "${OUT}"; then
    pass "$1"
  else
    fail "$1 (rc=${RC}, attesa $2, riga «$3»): ${OUT:0:300}"
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

# Una copia dell'elemento $2 con la libreria accanto, come nel repository,
# in cui verifica.sh è finta: stampa una riga per canale ed esce con
# STUB_USCITA (default 2). L'albero del repository non cambia.
# Arguments: $1 la variabile da assegnare (l'elemento nella copia), $2
# l'elemento.
albero_finto() {
  local __a_copia __a_rel="${2#"${RADICE}"/}"
  __a_copia="$(mktemp -d "${TMP}/albero.XXXXXX")" \
    || { echo "mktemp" >&2; exit 2; }
  mkdir -p "${__a_copia}/tools" "${__a_copia}/${__a_rel}"
  cp "${RADICE}/tools/lib_handson.sh" "${__a_copia}/tools/"
  cp -R "$2/." "${__a_copia}/${__a_rel}/"
  # shellcheck disable=SC2016  # il corpo è della verifica finta
  printf '%s\n' '#!/bin/bash' 'echo "riga della verifica finta"' \
    'echo "verifica: precondizione finta" >&2' \
    'exit "${STUB_USCITA:-2}"' > "${__a_copia}/${__a_rel}/verifica.sh"
  chmod 755 "${__a_copia}/${__a_rel}/verifica.sh"
  printf -v "$1" '%s' "${__a_copia}/${__a_rel}"
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
      skip "${nome}: ${DATI[i]} che non si legge (da root ogni file si legge)"
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
      "${D06}/demo/cura-1-vaga.md" "${D06}/demo/base-2-formato.md" \
      "${D06}/demo/orrore-2-divieto.md" "${D06}/demo/cura-2-divieto.md" \
      "${D06}/demo/orrore-3-stima.md" "${D06}/demo/cura-3-stima.md" \
      "${D06}/demo/cura-4-memoria.md"; do
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
  # v1 con la risposta e il giudizio di v0: i controlli si rifanno sulla
  # risposta, quindi la copia di controlli/v0.txt non basterebbe.
  ws w "${E01}/esercizio" "${E01}/soluzione"
  cp "${w}/giudizi/v0.json" "${w}/giudizi/v1.json"
  cp "${w}/risposte/v0.json" "${w}/risposte/v1.json"
  run "${E01}/verifica.sh" "${w}"
  expect "E01: v1 che non migliora è un esito, non un errore" 0 \
    "v1 rispetto a v0, chiarezza: non decisa"
  ws w "${E01}/esercizio" "${E01}/soluzione"
  python3 -B -I - "${w}/risposte/v2.json" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as fh:
    doc = json.load(fh)
doc["result"] += "\nLa richiamiamo al +39 000 000 0103."
with open(sys.argv[1], "w", encoding="utf-8") as fh:
    json.dump(doc, fh, ensure_ascii=False)
PY
  run "${E01}/verifica.sh" "${w}"
  expect_riga "E01: il telefono nella risposta di v2 è un dato, senza esito" \
    0 "Il telefono del cliente nella risposta di v2: presente (la risposta \
lo ripete)"
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
  # sistemi peggiora in v2: il giudizio di v0, e una risposta di nove
  # righe senza la porta né il numero di ONT, che non supera nessuno dei
  # tre controlli (si rifanno sulla risposta, non su controlli/v2.txt).
  ws w "${E02}/esercizio" "${E02}/soluzione"
  cp "${w}/sistemi/giudizi/v0.json" "${w}/sistemi/giudizi/v2.json"
  python3 -B -I - "${w}/sistemi/risposte/v2.json" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as fh:
    doc = json.load(fh)
doc["result"] = "\n".join(["Un guasto da controllare."] * 9)
with open(sys.argv[1], "w", encoding="utf-8") as fh:
    json.dump(doc, fh, ensure_ascii=False)
PY
  run "${E02}/verifica.sh" "${w}"
  expect "E02: una famiglia che peggiora è un esito, non un errore" 0 \
    "${FATTO}"
  expect "E02: e peggiora nei controlli, rifatti sulla risposta" 0 \
    "v2: controlli 0/3"
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
  j='{"is_error":false,"result":"ok","modelUsage":{"claude-haiku-5-5":{}}}'
  OUT="$(printf '%s' "${j}" | python3 -B -I "${lj}" modello 2>&1)"; RC=$?
  expect "leggi_json: il modello che ha risposto" 0 "claude-haiku-5-5"
  OUT="$(printf '%s' '{"is_error":false,"result":"ok"}' \
    | python3 -B -I "${lj}" modello 2>&1)"; RC=$?
  expect "leggi_json: modello assente" 1 "quale modello"
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

# Le due esercitazioni con una verifica.sh finta: se la verifica esce 2
# (una precondizione) la prova esce 2, con la riga FATALE su STDERR; se
# esce 1 resta un KO; se esce 0 passa e ne stampa l'uscita, come prima.
t_live_verifica() {
  local e c w
  for e in "${E01}" "${E02}"; do
    albero_finto c "${e}"
    ws w "$(partenza "${e}")"
    finto_err "${c}/_docente/live.sh" "${w}"
    expect "${e##*/}: la verifica esce 2, la prova esce 2 (STDERR)" 2 \
      "una precondizione, non un esito diverso"
    ws w "$(partenza "${e}")"
    finto STUB_USCITA=1 "${c}/_docente/live.sh" "${w}"
    expect "${e##*/}: la verifica esce 1, resta un KO" 1 \
      "VERIFICA KO   verifica.sh dell'elemento (uscita 1)"
    expect_absent "${e##*/}: e nessuna precondizione" "FATALE"
    ws w "$(partenza "${e}")"
    finto STUB_USCITA=0 "${c}/_docente/live.sh" "${w}"
    expect "${e##*/}: la verifica esce 0, la sua uscita si stampa" 0 \
      "riga della verifica finta"
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
    skip "misura.sh: controlli che non girano (da root ogni cartella si" \
      "scrive)"
    skip "misura.sh: dopo i controlli falliti nessun giudizio (da root)"
    skip "misura.sh: una chiamata sola, la risposta (da root)"
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
  printf '\xff\xfe' > "${w}/risposte/v1.json"
  run "${E01}/verifica.sh" "${w}"
  expect "verifica: risposte/v1.json non UTF-8 va rimisurato" 1 \
    "risposte/v1.json non è un JSON valido: misurate di nuovo v1"
  if (( EUID == 0 )); then
    for d in risposte giudizi .; do
      skip "verifica: la cartella ${d} che non si legge (da root si legge)"
    done
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

# I controlli scritti in codice si rifanno sulla risposta: verifica.py e
# --confronta li calcolano da risposte/<v>.json e da controlli.tsv, con le
# funzioni del kit che scrivono controlli/<v>.txt. Quel file è per chi
# legge: manomesso (gli esiti rovesciati, il totale cambiato), non UTF-8 o
# assente, non cambia i totali, l'esito della pratica, i conteggi del
# confronto né l'uscita.
t_controlli_dalla_risposta() {
  local w
  ws w "${E01}/esercizio" "${E01}/soluzione"
  sed -i -e 's/^KO\t/OK\t/' -e 's/^totale\t.*/totale\t3\/3/' \
    "${w}/controlli/v0.txt"
  sed -i -e 's/^OK\t/KO\t/' -e 's/^totale\t.*/totale\t0\/3/' \
    "${w}/controlli/v1.txt"
  run "${E01}/verifica.sh" "${w}"
  expect_riga "controlli/ manomessa: i totali di v0, dalla risposta" 0 \
    "${E01_V0}"
  expect_riga "controlli/ manomessa: i totali di v1, dalla risposta" 0 \
    "${E01_V1}"
  expect_riga "controlli/ manomessa: chiarezza resta confermata" 0 \
    "${E01_CHIAREZZA}"
  expect_riga "controlli/ manomessa: i criteri contati sulle risposte" 0 \
    "${E01_CONTEGGI}"
  expect "controlli/ manomessa: la verifica passa come prima" 0 "${FATTO}"
  run env PATH="${TMP}/senza_claude" "${w}/misura.sh" --confronta v0 v1
  expect_riga "controlli/ manomessa: --confronta, i totali" 0 \
    "${E01_TOTALI}"
  expect_riga "controlli/ manomessa: --confronta, i criteri contati" 0 \
    "${E01_CRITERI}"
  printf '\xff\xfe' > "${w}/controlli/v1.txt"
  rm "${w}/controlli/v0.txt"
  run "${E01}/verifica.sh" "${w}"
  expect "controlli/v0.txt assente, v1.txt non UTF-8: niente da rimisurare" \
    0 "${FATTO}"
  run env PATH="${TMP}/senza_claude" "${w}/misura.sh" --confronta v0 v1
  expect_riga "controlli/v0.txt assente: --confronta non lo chiede" 0 \
    "${E01_TOTALI}"
  ws w "${E02}/esercizio" "${E02}/soluzione"
  sed -i -e 's/^OK\t/KO\t/' -e 's/^totale\t.*/totale\t0\/4/' \
    "${w}/supporto/controlli/v1.txt"
  run "${E02}/verifica.sh" "${w}"
  expect_riga "E02, controlli/ manomessa: i totali di v1 di supporto" 0 \
    "${E02_SUP_V1}"
  run env PATH="${TMP}/senza_claude" "${w}/misura.sh" --confronta supporto \
    v0 v1
  expect_riga "E02, controlli/ manomessa: --confronta supporto, i totali" 0 \
    "${E02_SUP_TOTALI}"
  # controlli.tsv rotto dopo la misura: i controlli non si rifanno, e la
  # verifica dice la riga da correggere (1), senza traceback.
  ws w "${E01}/esercizio" "${E01}/soluzione"
  printf 'assente\tsolo due campi\n' >> "${w}/controlli.tsv"
  run "${E01}/verifica.sh" "${w}"
  expect "controlli.tsv rotto dopo la misura: la verifica dice la riga" 1 \
    "controlli.tsv, riga 5: attesi tre campi"
  expect_absent "controlli.tsv rotto dopo la misura: senza traceback" \
    "Traceback"
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
  expect_riga "kit: il confronto, controlli e giudice" 0 "${E01_TOTALI}"
  expect_riga "kit: il confronto, i token" 0 "${E01_TOKEN}"
}

# ...e nei live.sh: le precondizioni di una demo e di un'esercitazione; una
# famiglia sola che migliora, un esito che verifica.py stampa e basta.
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
  # v2 di sviluppo e di supporto con la risposta e il giudizio di v0: i
  # controlli si rifanno sulla risposta, non su controlli/v2.txt.
  ws w "${E02}/esercizio" "${E02}/soluzione"
  for f in sviluppo supporto; do
    cp "${w}/${f}/giudizi/v0.json" "${w}/${f}/giudizi/v2.json"
    cp "${w}/${f}/risposte/v0.json" "${w}/${f}/risposte/v2.json"
  done
  run "${E02}/verifica.sh" "${w}"
  expect "E02: una famiglia sola che migliora è un esito, non un errore" 0 \
    "${FATTO}"
  expect_riga "E02: v2 di supporto torna alle misure di v0" 0 \
    "  v2: controlli 2/4, giudice 4/5"
}

# Le sei demo: alla prima chiamata fallita si fermano (una chiamata sola);
# su un esito diverso stampano il messaggio di verifica.sh, non soltanto la
# riga del verdetto, con handson::check della libreria e senza una copia
# locale di esito(). L'esito diverso: per M2-D01 un prompt B più corto di A;
# per M2-D02 un system prompt lungo, che pesa più della metà; per M2-D05
# thinking_tokens oltre output_tokens; FINTO_RISPOSTA per le altre tre.
t_demo() {
  local i e w v
  local -a frase=(
    'più token in entrata per B che per A: non confermata in questa esecuzione'
    'benché la riga ci sia: non confermata in questa esecuzione'
    'Con --json-schema, structured_output è validato (garantita): non distinguibile'
    "l'oggetto rispetta lo schema (haiku): chiamata fallita"
    'in questa esecuzione no (R1: 111 su 110'
    'in questa esecuzione no')
  for i in "${!DEMO[@]}"; do
    e="${DEMO[i]}"
    if grep -q '^esito()' "${e}/_docente/live.sh" \
        || ! grep -qF 'handson::check "' "${e}/_docente/live.sh"; then
      fail "${e##*/}: il controllo dell'esito in una copia locale"
    else
      pass "${e##*/}: il controllo dell'esito con handson::check"
    fi
    ws w "$(partenza "${e}")"
    finto FINTO_ESITO=ko "${e}/_docente/live.sh" "${w}"
    v="$(chiamate)"
    if (( RC == 1 && v == 1 )) && grep -qF -- 'VERIFICA KO' <<< "${OUT}"
    then pass "${e##*/}: si ferma alla prima chiamata fallita"
    else fail "${e##*/}: rc=${RC} dopo ${v} chiamate fallite: ${OUT:0:200}"
    fi
    ws w "$(partenza "${e}")"
    if [[ "${e}" == "${D01}" ]]; then
      printf 'Riassumi.\n' > "${w}/prompt-b.md"
      finto "${e}/_docente/live.sh" "${w}"
    elif [[ "${e}" == "${D02}" ]]; then
      printf 'Rispondi in italiano. %.0s' {1..600} > "${w}/istruzione.txt"
      finto "${e}/_docente/live.sh" "${w}"
    elif [[ "${e}" == "${D05}" ]]; then
      finto FINTO_THINKING_OLTRE=1 "${e}/_docente/live.sh" "${w}"
    elif [[ "${e}" == "${D06}" ]]; then
      finto FINTO_RISPOSTA="L'assistenza clienti di CiaspoLink" \
        "${e}/_docente/live.sh" "${w}"
    else
      finto FINTO_RISPOSTA='Non lo so.' "${e}/_docente/live.sh" "${w}"
    fi
    expect "${e##*/}: su un KO il messaggio di verifica.sh" 1 "${frase[i]}"
    expect "${e##*/}: e il verdetto con l'uscita del controllo" 1 \
      "(uscita 1)"
  done
}

# Le versioni: misura.sh, kit.py e verifica.py ammettono soltanto vN
# (^v(0|[1-9][0-9]*)$). Un nome come v2b misura.sh e kit.py lo rifiutano
# (uscita 2); verifica.py non lo conta: in M2-E01 una misura v1b peggiore
# non diventa l'ultima versione, in M2-E02 una misura v1b non è un secondo
# ciclo.
t_versioni() {
  local w f d
  ws w "${E01}/esercizio"
  cp "${w}/prompt/v0.md" "${w}/prompt/v2b.md"
  precondizione "misura.sh: una versione con una lettera, v2b" \
    "versione «v2b» non valida" "${w}/misura.sh" v2b
  run python3 -B "${w}/strumenti/kit.py" componi "${w}" v2b
  expect "kit: una versione con una lettera, v2b" 2 \
    "versione «v2b» non valida"
  ws w "${E01}/esercizio" "${E01}/soluzione"
  for f in risposte/v0.json risposte/v0.md controlli/v0.txt \
      giudizi/v0.json; do
    cp "${w}/${f}" "${w}/${f/v0/v1b}"
  done
  run "${E01}/verifica.sh" "${w}"
  expect "verifica: una misura v1b non è l'ultima versione (E01)" 0 \
    "${FATTO}"
  expect_absent "verifica: e non compare" "v1b"
  ws w "${E02}/esercizio" "${E02}/soluzione"
  for d in sviluppo supporto; do
    rm -f "${w}/${d}/risposte/v2.json"
    for f in risposte/v1.json risposte/v1.md controlli/v1.txt \
        giudizi/v1.json; do
      cp "${w}/${d}/${f}" "${w}/${d}/${f/v1/v1b}"
    done
  done
  run "${E02}/verifica.sh" "${w}"
  expect "verifica: una misura v1b non è un secondo ciclo (E02)" 1 \
    "famiglie con due cicli (v2): 1 su tre; ne servono almeno due"
}

# Uno zero davanti, v01: misura.sh e kit.py lo rifiutano (uscita 2) e
# verifica.py non lo conta. Con ^v[0-9]+$ v01 pareggiava con v1 (quale
# delle due fosse l'ultima dipendeva dall'ordine dei file) e in M2-E02
# contava come secondo ciclo.
t_versioni_zeri() {
  local w f d
  ws w "${E01}/esercizio"
  cp "${w}/prompt/v0.md" "${w}/prompt/v01.md"
  precondizione "misura.sh: una versione con uno zero davanti, v01" \
    "versione «v01» non valida" "${w}/misura.sh" v01
  run python3 -B "${w}/strumenti/kit.py" componi "${w}" v01
  expect "kit: una versione con uno zero davanti, v01" 2 \
    "versione «v01» non valida"
  ws w "${E01}/esercizio" "${E01}/soluzione"
  for f in risposte/v0.json risposte/v0.md controlli/v0.txt \
      giudizi/v0.json; do
    cp "${w}/${f}" "${w}/${f/v0/v01}"
  done
  run "${E01}/verifica.sh" "${w}"
  expect "verifica: una misura v01 non pareggia con v1 (E01)" 0 \
    "${FATTO}"
  expect_absent "verifica: e v01 non compare" "v01"
  ws w "${E02}/esercizio" "${E02}/soluzione"
  for d in sviluppo supporto; do
    rm -f "${w}/${d}/risposte/v2.json"
    for f in risposte/v1.json risposte/v1.md controlli/v1.txt \
        giudizi/v1.json; do
      cp "${w}/${d}/${f}" "${w}/${d}/${f/v1/v01}"
    done
  done
  run "${E02}/verifica.sh" "${w}"
  expect "verifica: una misura v01 non è un secondo ciclo (E02)" 1 \
    "famiglie con due cicli (v2): 1 su tre; ne servono almeno due"
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
  awk -F'\t' -v OFS='\t' '$1 == "orrore-4-memoria" { $13 = "sì" }
    { print }' "${w}/orrori.tsv" > "${w}/orrori.nuovo"
  mv "${w}/orrori.nuovo" "${w}/orrori.tsv"
  run "${D06}/verifica.sh" "${w}"
  expect "M2-D06: la firma concordata nell'orrore della memoria" 1 \
    "in questa esecuzione no"
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
  expect_riga "misura.sh --confronta senza claude nel PATH" 0 \
    "${E01_TOTALI}"
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
  t_finti
  t_live_esercitazioni
  t_live_verifica
  t_operando
  t_contratto_kit
  t_contratto_misura
  t_contratto_verifica
  t_controlli_dalla_risposta
  t_opzioni
  t_rami
  t_rami_live
  t_misura_nuova
  t_versioni
  t_versioni_zeri
  t_prima_della_chiamata
  t_giudice
  t_demo
  t_etichette
  t_shellcheck
  echo "PASS=${PASS} FAIL=${FAIL} SKIP=${SKIP}" \
    "CASES=$((PASS + FAIL + SKIP))/${CASES}"
  if (( PASS + FAIL + SKIP != CASES )); then
    echo "test_m2_script: eseguite $((PASS + FAIL + SKIP)) prove, attese" \
      "${CASES}: un caso manca o non è contato" >&2
    exit 2
  fi
  (( FAIL == 0 )) || exit 1
}

main "$@"
