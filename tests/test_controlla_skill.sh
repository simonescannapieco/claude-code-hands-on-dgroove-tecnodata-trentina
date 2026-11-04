#!/bin/bash
#
# test_controlla_skill.sh -- le prove di tools/controlla_skill.py: ogni
# errore e ogni avviso su una skill costruita in una cartella temporanea
# (uscita E parola chiave); una skill pulita senza segnalazioni (la parola
# chiave assente); le skill di esempio di riferimenti/skill-di-esempio/
# senza errori (risposta-assistenza anche con --caricamento, e nessun avviso
# sui campi); riferimenti/template-SKILL.md, copiato come SKILL.md, che dà
# errori finché non è riempito; gli argomenti (uscita 2); mai un traceback.
# In più lo script di audit-configurazione, controlli_ovvi.py: un inventario
# illeggibile esce 2, un valore si cerca come parola intera.
#
# Uso:    tests/test_controlla_skill.sh
# Uscita: 0 = tutte le prove passano · 1 = almeno una fallita ·
#         2 = precondizione (manca python3)
# shellcheck disable=SC2016  # backtick e ${…} sono il testo delle prove
set -uo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly REPO="${SELF%/tests/*}"
readonly TOOL="${REPO}/tools/controlla_skill.py"
readonly ESEMPI="${REPO}/riferimenti/skill-di-esempio"
readonly TEMPLATE="${REPO}/riferimenti/template-SKILL.md"
D_OK='Controlla le linee di prova e ne riporta lo stato.'
D_OK+=' Da usare quando si chiede di controllare una linea.'
readonly D_OK
readonly CAMPI_CC='when_to_use argument-hint arguments disable-model-invocation
  user-invocable disallowed-tools model effort context agent background hooks
  paths shell'
TMP=''
PASS=0
FAIL=0
RC=0
OUT=''
D=''
N=0

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

# Esegue il controllo su una cartella; RC e OUT (i due canali insieme).
# Arguments: gli argomenti del controllo.
controlla() {
  OUT="$(python3 -B -I "${TOOL}" "$@" 2>&1)"
  RC=$?
}

# Uscita attesa E parole attese (RU-01.T3), e mai un traceback.
# Arguments: $1 il nome, $2 l'uscita attesa, poi le parole (grep -F).
expect() {
  local nome="$1" atteso="$2" parola
  shift 2
  if (( RC != atteso )); then
    fail "${nome} (uscita ${RC}, attesa ${atteso}): ${OUT}"
    return 0
  fi
  if grep -qF -- 'Traceback' <<< "${OUT}"; then
    fail "${nome} (un traceback): ${OUT}"
    return 0
  fi
  for parola in "$@"; do
    if ! grep -qF -- "${parola}" <<< "${OUT}"; then
      fail "${nome} (manca «${parola}»): ${OUT}"
      return 0
    fi
  done
  pass "${nome}"
}

# Uscita attesa E parole assenti (RU-01.T5).
# Arguments: $1 il nome, $2 l'uscita attesa, poi le parole (grep -F).
expect_no() {
  local nome="$1" atteso="$2" parola
  shift 2
  if (( RC != atteso )); then
    fail "${nome} (uscita ${RC}, attesa ${atteso}): ${OUT}"
    return 0
  fi
  for parola in "$@"; do
    if grep -qF -- "${parola}" <<< "${OUT}"; then
      fail "${nome} (c'è «${parola}»): ${OUT}"
      return 0
    fi
  done
  pass "${nome}"
}

# Un percorso che non deve esistere. Arguments: $1 il nome, $2 il percorso.
falso_file() {
  if [[ -e "$2" ]]; then
    fail "$1 ($2 c'è)"
  else
    pass "$1"
  fi
}

# Tre valutazioni nella cartella della skill (così non c'è quell'avviso).
# Arguments: $1 la cartella.
tre_evals() {
  mkdir -p "$1/evals"
  cat > "$1/evals/evals.json" <<'EOF'
{"skill_name": "x", "evals": [
  {"id": 1, "prompt": "a", "expected_output": "b"},
  {"id": 2, "prompt": "a", "expected_output": "b"},
  {"id": 3, "prompt": "a", "expected_output": "b"}]}
EOF
}

# Una cartella nuova per una skill. Globals: D (assegnata), N.
# Arguments: $1 il nome della cartella (default: prova-linea).
nuova() {
  N=$((N + 1))
  D="${TMP}/c${N}/${1:-prova-linea}"
  mkdir -p "${D}"
  tre_evals "${D}"
}

# Scrive uno SKILL.md con il frontmatter dato e un corpo semplice.
# Globals: D. Arguments: $1 il frontmatter (righe), $2 (facoltativo) il
# corpo.
md() {
  local corpo="${2-Corpo della skill.}"
  printf -- '---\n%s\n---\n\n%s\n' "$1" "${corpo}" > "${D}/SKILL.md"
}

# Una skill con il nome giusto e la description buona, più le righe date.
# Globals: D. Arguments: $1 le righe in più (può essere vuoto), $2 il corpo.
md_ok() {
  local fm="name: ${D##*/}"$'\n'"description: ${D_OK}"
  if [[ -n "${1:-}" ]]; then
    fm+=$'\n'"$1"
  fi
  md "${fm}" "${2-Corpo della skill.}"
}

# --- La skill pulita e i dati -------------------------------------------

test_pulita() {
  nuova
  md_ok ''
  controlla "${D}"
  expect 'pulita: uscita 0 e il riepilogo' 0 \
    'controlla_skill: prova-linea: 0 errori, 0 avvisi'
  expect_no 'pulita: nessun ERRORE né AVVISO' 0 'ERRORE' 'AVVISO'
  nuova
  md_ok '' "$(printf 'una riga\ndue righe\ntre righe')"
  printf 'x%.0s' {1..100} >> "${D}/SKILL.md"
  controlla "${D}"
  expect 'i dati: le righe del corpo' 0 'corpo: 5 righe'
  expect 'i dati: i token stimati' 0 'token stimati: circa' \
    'caratteri × 0,433' 'una stima'
  local ultima
  ultima="$(tail -n 1 <<< "${OUT}")"
  if [[ "${ultima}" == 'controlla_skill: prova-linea: 0 errori, 0 avvisi' ]]
  then
    pass "l'ultima riga è il riepilogo"
  else
    fail "l'ultima riga è il riepilogo: ${ultima}"
  fi
  nuova
  printf -- '---\nname: %s\ndescription: %s\n---\n\n' "${D##*/}" "${D_OK}" \
    > "${D}/SKILL.md"
  printf 'x%.0s' {1..1000} >> "${D}/SKILL.md"
  printf '\n' >> "${D}/SKILL.md"
  controlla "${D}"
  expect 'i token: 1002 caratteri fanno circa 434' 0 'circa 434 '
}

# Il riepilogo e i dati si accordano con il numero: «1 errore», «1 avviso».
test_plurali() {
  nuova
  md_ok 'descrizione: x'
  controlla "${D}"
  expect 'un avviso: «1 avviso»' 0 \
    'controlla_skill: prova-linea: 0 errori, 1 avviso'
  expect_no 'un avviso: mai «1 avvisi»' 0 '1 avvisi'
  nuova
  md "name: altro-nome"$'\n'"description: ${D_OK}"
  controlla "${D}"
  expect 'un errore: «1 errore»' 1 \
    'controlla_skill: altro-nome: 1 errore, 0 avvisi'
  expect_no 'un errore: mai «1 errori»' 1 '1 errori'
  nuova
  md "name: Altro"$'\n'"description: ${D_OK}"$'\n''campo-uno: x'\
$'\n''campo-due: y'
  controlla "${D}"
  expect 'due e due: il plurale resta' 1 \
    'controlla_skill: Altro: 2 errori, 2 avvisi'
  nuova
  printf -- '---\nname: %s\ndescription: %s\n---\nUna riga sola.\n' \
    "${D##*/}" "${D_OK}" > "${D}/SKILL.md"
  controlla "${D}"
  expect 'un corpo di una riga: «1 riga»' 0 'corpo: 1 riga'
  expect_no 'un corpo di una riga: mai «1 righe»' 0 '1 righe'
  nuova
  md_ok ''
  printf '{"evals": [{"id": 1}]}\n' > "${D}/evals/evals.json"
  controlla "${D}"
  expect 'un solo caso: «1 caso»' 0 'evals/evals.json ha 1 caso'
  expect_no 'un solo caso: mai «1 casi»' 0 '1 casi'
}

# --- La cornice del frontmatter ------------------------------------------

test_cornice() {
  nuova
  rm -f "${D}/SKILL.md"
  controlla "${D}"
  expect 'manca SKILL.md: errore, non uscita 2' 1 'ERRORE SKILL.md' \
    'controlla_skill: prova-linea: 1 errore, 0 avvisi'
  nuova
  printf '\n---\nname: x\n---\nCorpo\n' > "${D}/SKILL.md"
  controlla "${D}"
  expect 'il --- non è la prima riga' 1 'ERRORE frontmatter' 'prima riga'
  nuova
  printf 'Solo testo.\n' > "${D}/SKILL.md"
  controlla "${D}"
  expect 'nessun frontmatter' 1 'ERRORE frontmatter' 'prima riga'
  nuova
  printf -- '---\nname: x\ndescription: a\n\nCorpo\n' > "${D}/SKILL.md"
  controlla "${D}"
  expect 'manca il --- di chiusura' 1 'ERRORE frontmatter' 'chiude'
  nuova
  printf '' > "${D}/SKILL.md"
  controlla "${D}"
  expect 'un file vuoto' 1 'ERRORE frontmatter' 'prima riga'
  nuova
  printf -- '---\xff\n' > "${D}/SKILL.md"
  controlla "${D}"
  expect 'un file che non è UTF-8' 1 'ERRORE SKILL.md' 'UTF-8'
  nuova
  printf -- '---\r\nname: %s\r\ndescription: %s\r\n---\r\n\r\nCorpo\r\n' \
    "${D##*/}" "${D_OK}" > "${D}/SKILL.md"
  controlla "${D}"
  expect_no 'fine riga CRLF: nessun errore' 0 'ERRORE'
}

# --- Il YAML: ciò che deve essere un errore, con la riga ------------------

test_yaml_virgolette() {
  nuova
  md "name: ${D##*/}"$'\n''description: "non chiusa'
  controlla "${D}"
  expect 'virgolette doppie non chiuse' 1 'ERRORE riga 3' 'virgolette'
  nuova
  md "name: ${D##*/}"$'\n'"description: 'non chiusa"
  controlla "${D}"
  expect 'apice non chiuso' 1 'ERRORE riga 3' 'virgolette'
  nuova
  md "name: ${D##*/}"$'\n'"description: 'l'assistenza'"
  controlla "${D}"
  expect "un apice dentro un valore fra apici" 1 'ERRORE riga 3' 'raddoppia'
  nuova
  md "name: ${D##*/}"$'\n''description: "chiusa" e altro'
  controlla "${D}"
  expect 'testo dopo le virgolette' 1 'ERRORE riga 3' 'dopo le virgolette'
  nuova
  md "name: ${D##*/}"$'\n'"description: \"Con: due punti. Da usare quando\""
  controlla "${D}"
  expect_no 'due punti fra virgolette: va bene' 0 'ERRORE'
  nuova
  md "name: ${D##*/}"$'\n'"description: 'L''assistenza, da usare quando'"
  controlla "${D}"
  expect_no "l'apice raddoppiato: va bene" 0 'ERRORE'
  nuova
  md "name: ${D##*/}"$'\n'"description: \"Da usare \\\"quando\\\"\" # nota"
  controlla "${D}"
  expect_no 'virgolette con escape e un commento: vanno bene' 0 'ERRORE'
}

test_yaml_due_punti() {
  nuova
  md "name: ${D##*/}"$'\n''description: Controlla: tutto: bene'
  controlla "${D}"
  expect 'due punti nel valore (la prova del docente)' 1 'ERRORE riga 3' \
    'due punti' 'virgolette'
  nuova
  md "name: ${D##*/}"$'\n''Controlla: tutto: bene'$'\n'"description: ${D_OK}"
  controlla "${D}"
  expect 'due punti in una riga di primo livello' 1 'ERRORE riga 3' 'due punti'
  nuova
  md "name: ${D##*/}"$'\n''description: finisce con due punti:'
  controlla "${D}"
  expect 'due punti in fondo al valore' 1 'ERRORE riga 3' 'due punti'
  nuova
  md_ok 'allowed-tools: Bash(git:*) Read'
  controlla "${D}"
  expect_no 'due punti senza spazio dopo: va bene' 0 'ERRORE'
}

test_yaml_indicatori() {
  local segno
  for segno in '[' '{' '*' '&' '!' '|' '>' '%' '@' '`'; do
    nuova
    md "name: ${D##*/}"$'\n'"description: ${segno}non va"
    controlla "${D}"
    expect "un valore che comincia con ${segno}" 1 'ERRORE riga 3' 'comincia'
  done
  nuova
  md "name: ${D##*/}"$'\n''description: [non chiusa'
  controlla "${D}"
  expect 'una lista aperta (la prova del docente)' 1 'ERRORE riga 3' \
    'non si chiude'
  nuova
  md_ok 'argument-hint: [issue-number]'
  controlla "${D}"
  expect_no 'una lista chiusa su una riga: va bene' 0 'ERRORE'
  nuova
  md_ok 'argument-hint: [file] [formato]'
  controlla "${D}"
  expect 'due liste sulla stessa riga' 1 'ERRORE riga 4'
  nuova
  md_ok 'hooks: {PreToolUse: [{matcher: "Bash"}]}'
  controlla "${D}"
  expect_no 'una mappa chiusa su una riga: va bene' 0 'ERRORE'
}

test_yaml_struttura() {
  nuova
  md "name: ${D##*/}"$'\n'"description: ${D_OK}"$'\n'"name: altro"
  controlla "${D}"
  expect 'una chiave ripetuta' 1 'ERRORE riga 4' 'ripetuta' 'name' 'riga 2'
  nuova
  md "name: ${D##*/}"$'\n'"questa riga non è una chiave"$'\n'"description: a"
  controlla "${D}"
  expect 'una riga che non è chiave: valore' 1 'ERRORE riga 3' 'chiave'
  nuova
  md "name: ${D##*/}"$'\n'"description:senza-spazio"
  controlla "${D}"
  expect 'chiave senza spazio dopo i due punti' 1 'ERRORE riga 3' 'chiave'
  nuova
  md 'description: a'$'\n''  name: b'$'\n'' -x'
  controlla "${D}"
  expect 'il rientro sbagliato (la prova del docente)' 1 'ERRORE riga 3' \
    'rientr'
  nuova
  md '  name: b'$'\n'"description: ${D_OK}"
  controlla "${D}"
  expect 'una prima riga rientrata' 1 'ERRORE riga 2' 'rientr'
  nuova
  md "name: ${D##*/}"$'\n'"metadata:"$'\n'$'\t'"author: x"$'\n'"description: a"
  controlla "${D}"
  expect 'una tabulazione nel rientro' 1 'ERRORE riga 4' 'tabulazione'
  nuova
  md_ok 'hooks:'$'\n'$'\t''PreToolUse: x'
  controlla "${D}"
  expect 'una tabulazione anche in un campo opaco' 1 'ERRORE riga 5' \
    'tabulazione'
  nuova
  md_ok 'paths:'$'\n''  - "src/**"'$'\n''  - "lib/**"'
  controlla "${D}"
  expect_no 'una lista sotto paths: opaca, va bene' 0 'ERRORE'
  nuova
  md_ok 'hooks:'$'\n''  PreToolUse:'$'\n''    - matcher: "Bash"'
  controlla "${D}"
  expect_no 'una mappa sotto hooks: opaca, va bene' 0 'ERRORE'
  nuova
  md "# un commento"$'\n'"name: ${D##*/}"$'\n\n'"description: ${D_OK} # fine"
  controlla "${D}"
  expect_no 'commenti e righe vuote: vanno bene' 0 'ERRORE'
}

# Per YAML le voci di una lista possono stare in colonna 1, allo stesso rientro
# di una chiave senza valore; altrove una riga così resta un errore.
test_yaml_lista_colonna_1() {
  nuova
  md_ok 'paths:'$'\n''- "src/**"'$'\n''- "lib/**"'
  controlla "${D}"
  expect 'una lista in colonna 1 sotto paths: uscita 0' 0 \
    'prova-linea: 0 errori'
  expect_no 'una lista in colonna 1: nessun errore' 0 'ERRORE'
  nuova
  md "name: ${D##*/}"$'\n''paths:'$'\n''- a'$'\n\n''# un commento'$'\n''- b'\
$'\n'"description: ${D_OK}"
  controlla "${D}"
  expect_no 'la lista finisce alla chiave seguente, che si legge' 0 'ERRORE'
  nuova
  md_ok 'paths:  # i percorsi'$'\n''- a'$'\n''  continua'$'\n''-'$'\n''  b'
  controlla "${D}"
  expect_no 'una voce su due righe e un commento sulla chiave' 0 'ERRORE'
  nuova
  md_ok 'allowed-tools:'$'\n''- Read'$'\n''- Grep'
  controlla "${D}"
  expect 'allowed-tools in colonna 1: la sua regola' 1 \
    'ERRORE allowed-tools' 'stringa'
  expect_no 'allowed-tools in colonna 1: nessun errore di riga' 1 'ERRORE riga'
  nuova
  md "name: ${D##*/}"$'\n''description:'$'\n''- a'
  controlla "${D}"
  expect 'description che è una lista in colonna 1' 1 'ERRORE description' \
    'non è una stringa'
  nuova
  md_ok 'metadata:'$'\n''- a'
  controlla "${D}"
  expect 'metadata che è una lista in colonna 1' 1 'ERRORE metadata' 'mappa'
  nuova
  md_ok 'paths: src/**'$'\n''- a'
  controlla "${D}"
  expect 'una voce sotto una chiave che ha un valore: errore' 1 \
    'ERRORE riga 5' 'chiave'
  nuova
  md '- a'$'\n'"name: ${D##*/}"$'\n'"description: ${D_OK}"
  controlla "${D}"
  expect 'una voce prima di ogni chiave: errore' 1 'ERRORE riga 2' 'chiave'
  nuova
  md_ok 'paths:'$'\n''  - a'$'\n''- b'
  controlla "${D}"
  expect 'una voce in colonna 1 dopo una rientrata: errore' 1 \
    'ERRORE riga 6' 'chiave'
  nuova
  md_ok 'paths:'$'\n''-a'
  controlla "${D}"
  expect 'un trattino senza spazio non è una voce: errore' 1 \
    'ERRORE riga 5' 'chiave'
  nuova
  md_ok 'paths:'$'\n''- a'$'\n'$'\t''b'
  controlla "${D}"
  expect 'una tabulazione sotto una voce in colonna 1' 1 'ERRORE riga 6' \
    'tabulazione'
}

test_yaml_blocchi() {
  local stile
  for stile in '>-' '>' '|' '|-'; do
    nuova
    md "name: ${D##*/}"$'\n'"description: ${stile}"$'\n'\
'  Con: due punti.'$'\n''  Da usare quando serve.'
    controlla "${D}"
    expect_no "un blocco ${stile}: va bene, anche con i due punti" 0 \
      'ERRORE' 'AVVISO'
  done
  nuova
  md "name: ${D##*/}"$'\n''description: >-'
  controlla "${D}"
  expect 'un blocco vuoto è una description vuota' 1 'ERRORE description' \
    'vuota'
  nuova
  md "name: ${D##*/}"$'\n''description: >-'$'\n''  Con <tag> dentro.'
  controlla "${D}"
  expect 'parentesi angolari in un blocco' 1 'ERRORE description' 'angolari'
  nuova
  md "name: ${D##*/}"$'\n''description: >-'$'\n''    Prima riga'$'\n''  Meno.'
  controlla "${D}"
  expect 'un blocco con il rientro che cala' 1 'ERRORE riga 5' 'rientr'
  nuova
  md "name: ${D##*/}"$'\n''description: | testo'
  controlla "${D}"
  expect 'testo sulla riga del blocco' 1 'ERRORE riga 3' 'comincia'
  nuova
  md "name: ${D##*/}"$'\n'"description: Prima parte,"$'\n'\
'  seconda parte. Da usare quando serve.'
  controlla "${D}"
  expect_no 'un valore semplice su due righe: va bene' 0 'ERRORE' 'AVVISO'
  nuova
  md "name: ${D##*/}"$'\n'"description:"$'\n'\
'  Tutta sotto. Da usare quando serve.'
  controlla "${D}"
  expect_no 'un valore semplice sotto la chiave: va bene' 0 'ERRORE' 'AVVISO'
}

# Un valore sulla riga sotto la chiave ha gli stessi controlli di uno sulla
# riga della chiave.
test_yaml_valore_sotto() {
  local valore
  for valore in '"non chiusa' "'non chiusa" '[non chiusa' \
      '[Obsoleta] Controlla' '@acme controlla' '*alias' '&ancora x' '%x' '!x' \
      '| x'; do
    nuova
    md "name: ${D##*/}"$'\n''description:'$'\n'"  ${valore}"
    controlla "${D}"
    expect "un valore sotto la chiave: ${valore}" 1 'ERRORE riga 4'
  done
  nuova
  md "name: ${D##*/}"$'\n''description:'$'\n'\
'  "Controlla le linee: da usare quando serve"'
  controlla "${D}"
  expect_no 'fra virgolette sotto la chiave, con i due punti: va bene' 0 \
    'ERRORE'
  nuova
  md "name: ${D##*/}"$'\n''description:'$'\n''  [a, b]'
  controlla "${D}"
  expect 'una lista chiusa sotto la chiave: non è una stringa' 1 \
    'ERRORE description' 'stringa'
  nuova
  md "name: ${D##*/}"$'\n''description:'$'\n''  >-'$'\n'\
'    Un blocco. Da usare quando serve.'
  controlla "${D}"
  expect_no 'un blocco sotto la chiave: va bene' 0 'ERRORE'
}

# I valori sotto metadata hanno gli stessi controlli di quelli di primo
# livello.
test_yaml_metadata_rigoroso() {
  local valore
  for valore in '@prova' '%x' '*x' '!x' "'Dell'Orto'" '"1.0" beta' \
      '"aperta'; do
    nuova
    md_ok 'metadata:'$'\n'"  autore: ${valore}"
    controlla "${D}"
    expect "metadata: ${valore}" 1 'ERRORE riga 5'
  done
  nuova
  md_ok 'metadata:'$'\n''  version: 1.0 # beta'
  controlla "${D}"
  expect 'metadata: un numero con un commento resta un numero' 1 \
    'ERRORE metadata' 'version'
  nuova
  md_ok 'metadata:'$'\n''  autore: prova # nota: autore'
  controlla "${D}"
  expect_no 'metadata: i due punti in un commento non contano' 0 'ERRORE'
  nuova
  md_ok 'metadata:'$'\n''  autore: "Dell: Orto" # nota'
  controlla "${D}"
  expect_no 'metadata: virgolette con i due punti e un commento' 0 'ERRORE'
  nuova
  md_ok 'metadata: {autore: @x}'
  controlla "${D}"
  expect 'metadata su una riga: un segno vietato' 1 'ERRORE metadata' 'autore'
  nuova
  md_ok 'metadata: {autore: "x" y}'
  controlla "${D}"
  expect 'metadata su una riga: testo dopo le virgolette' 1 'ERRORE metadata' \
    'autore'
}

test_yaml_escape() {
  local mille valore
  mille="$(printf 'x%.0s' {1..1000})"
  for valore in '"Copia in C:\Users\x. Da usare quando serve"' '"a\qb quando"' \
      '"a\xZZb quando"' '"a\u12 quando"' '"a\U0011FFFF quando"'; do
    nuova
    md "name: ${D##*/}"$'\n'"description: ${valore}"
    controlla "${D}"
    expect "un escape che YAML non ha: ${valore}" 1 'ERRORE riga 3' 'escape'
  done
  nuova
  md "name: ${D##*/}"$'\n'\
'description: "Tab\t, a capo\n, \\ e \" da usare quando"'
  controlla "${D}"
  expect_no 'gli escape di YAML: vanno bene' 0 'ERRORE'
  nuova
  md "name: ${D##*/}"$'\n'\
"description: \"\\u00e9Da usare quando ${mille}1234567\""
  controlla "${D}"
  expect_no 'un escape conta un carattere: 1024 vanno bene' 0 'ERRORE'
  nuova
  md "name: ${D##*/}"$'\n'\
"description: \"\\u00e9Da usare quando ${mille}12345678\""
  controlla "${D}"
  expect 'un escape conta un carattere: 1025 no' 1 'ERRORE description' '1024'
}

test_yaml_flusso_appaiato() {
  local valore
  for valore in '[issue-number}' '{a: b]' '[a, {b: c]}'; do
    nuova
    md_ok "argument-hint: ${valore}"
    controlla "${D}"
    expect "le parentesi non appaiate: ${valore}" 1 'ERRORE riga 4'
  done
  nuova
  md_ok 'hooks: [{a: [b]}, {c: d}]'
  controlla "${D}"
  expect_no 'le parentesi appaiate: vanno bene' 0 'ERRORE'
}

test_yaml_blocco_tab() {
  nuova
  md "name: ${D##*/}"$'\n''description: |'$'\n''  Da usare quando serve'\
$'\n''  '$'\t''dopo il rientro'
  controlla "${D}"
  expect_no 'una tabulazione dopo il rientro di un blocco è testo' 0 'ERRORE'
  nuova
  md "name: ${D##*/}"$'\n''description: |'$'\n'$'\t''Da usare quando serve'
  controlla "${D}"
  expect 'un blocco rientrato con la tabulazione' 1 'ERRORE riga 4' \
    'tabulazione'
  nuova
  md "name: ${D##*/}"$'\n''description: |'$'\n''  Da usare quando serve'\
$'\n'$'\t''meno'
  controlla "${D}"
  expect 'una riga del blocco con la tabulazione al posto del rientro' 1 \
    'ERRORE riga 5' 'tabulazione'
}

test_yaml_messaggi() {
  nuova
  md "name : ${D##*/}"$'\n'"description: ${D_OK}"
  controlla "${D}"
  expect 'uno spazio prima dei due punti: dice che cosa vuole' 1 \
    'ERRORE riga 2' 'colonna 1'
  expect_no 'uno spazio prima dei due punti: niente «serve uno spazio»' 1 \
    'serve uno spazio).'
}

test_bom_e_trattini() {
  nuova
  printf '\xef\xbb\xbf---\nname: %s\ndescription: %s\n---\n\nCorpo\n' \
    "${D##*/}" "${D_OK}" > "${D}/SKILL.md"
  controlla "${D}"
  expect 'un BOM in testa: errore, con il motivo vero' 1 'ERRORE SKILL.md' \
    'BOM'
  expect_no 'un BOM in testa: non dice che la prima riga non è ---' 1 \
    'prima riga'
  nuova
  md_ok ''
  printf '\xef\xbb\xbf%s' "$(< "${D}/evals/evals.json")" \
    > "${D}/evals/evals.json"
  controlla "${D}"
  expect_no 'evals.json con un BOM si legge' 0 'AVVISO'
  nuova
  md "name: ${D##*/}"$'\n'\
"description: Elenca --- una per riga. Da usare quando"
  controlla "${D}"
  expect 'tre trattini dentro il frontmatter: un avviso' 0 'AVVISO riga 3' \
    'chiude il frontmatter'
  nuova
  md "name: ${D##*/}"$'\n''description: Da usare quando a--b.'
  controlla "${D}"
  expect_no 'due trattini: nessun avviso' 0 'AVVISO'
}

# --- name ----------------------------------------------------------------

test_name() {
  nuova
  md "description: ${D_OK}"
  controlla "${D}"
  expect 'name assente' 1 'ERRORE name' 'manca'
  nuova
  md 'name:'$'\n'"description: ${D_OK}"
  controlla "${D}"
  expect 'name vuoto' 1 'ERRORE name' 'vuoto'
  nuova 'abcdefghij-abcdefghij-abcdefghij-abcdefghij-abcdefghij-abcdefghij'
  md_ok ''
  controlla "${D}"
  expect 'name di 65 caratteri' 1 'ERRORE name' '64'
  nuova 'abcdefghij-abcdefghij-abcdefghij-abcdefghij-abcdefghij-abcdefghi'
  md_ok ''
  controlla "${D}"
  expect_no 'name di 64 caratteri: va bene' 0 'ERRORE'
  nuova Prova-Linea
  md_ok ''
  controlla "${D}"
  expect 'name con le maiuscole' 1 'ERRORE name' 'minuscole'
  nuova prova_linea
  md_ok ''
  controlla "${D}"
  expect 'name con il trattino basso' 1 'ERRORE name' 'minuscole'
  nuova -prova
  md_ok ''
  controlla "${D}"
  expect 'name con un trattino in testa' 1 'ERRORE name' 'trattino'
  nuova prova-
  md_ok ''
  controlla "${D}"
  expect 'name con un trattino in coda' 1 'ERRORE name' 'trattino'
  nuova prova--linea
  md_ok ''
  controlla "${D}"
  expect 'name con il trattino doppio' 1 'ERRORE name' 'trattini'
  nuova
  md 'name: altro-nome'$'\n'"description: ${D_OK}"
  controlla "${D}"
  expect 'name diverso dalla cartella' 1 'ERRORE name' 'cartella' 'altro-nome'
  nuova anthropic-prova
  md_ok ''
  controlla "${D}"
  expect 'name con anthropic' 1 'ERRORE name' 'anthropic'
  nuova prova-claude
  md_ok ''
  controlla "${D}"
  expect 'name con claude' 1 'ERRORE name' 'claude'
  nuova
  md 'name: <b>prova</b>'$'\n'"description: ${D_OK}"
  controlla "${D}"
  expect 'name con un tag XML' 1 'ERRORE name' 'tag XML'
  nuova 123
  md_ok ''
  controlla "${D}"
  expect 'name che per YAML è un numero' 1 'ERRORE name' 'virgolette'
}

# --- description, compatibility, metadata, allowed-tools ------------------

test_description() {
  local mille
  mille="$(printf 'x%.0s' {1..1000})"
  nuova
  md "name: ${D##*/}"
  controlla "${D}"
  expect 'description assente' 1 'ERRORE description' 'manca'
  nuova
  md "name: ${D##*/}"$'\n''description:'
  controlla "${D}"
  expect 'description vuota' 1 'ERRORE description' 'vuota' "di' che cosa fa"
  expect_no "description vuota: l'imperativo con l'apostrofo" 1 'dì che cosa'
  nuova
  md "name: ${D##*/}"$'\n'"description: ''"
  controlla "${D}"
  expect 'description vuota fra apici' 1 'ERRORE description' 'vuota'
  nuova
  md "name: ${D##*/}"$'\n'"description: Da usare quando ${mille}123456789"
  controlla "${D}"
  expect 'description di 1025 caratteri' 1 'ERRORE description' '1024'
  nuova
  md "name: ${D##*/}"$'\n'"description: Da usare quando ${mille}12345678"
  controlla "${D}"
  expect_no 'description di 1024 caratteri: va bene' 0 'ERRORE'
  nuova
  md "name: ${D##*/}"$'\n''description: Da usare quando c è un <tag> qui.'
  controlla "${D}"
  expect 'description con un tag' 1 'ERRORE description' 'angolari'
  nuova
  md "name: ${D##*/}"$'\n''description: Da usare quando a < b.'
  controlla "${D}"
  expect 'description con una sola parentesi' 1 'ERRORE description' 'angolari'
  nuova
  md "name: ${D##*/}"$'\n''description: true'
  controlla "${D}"
  expect 'description che per YAML non è una stringa' 1 'ERRORE description' \
    'stringa'
  nuova
  md "name: ${D##*/}"$'\n''description: [a, b]'
  controlla "${D}"
  expect 'description che è una lista' 1 'ERRORE description' 'stringa'
}

test_compatibility() {
  local cinquecento
  cinquecento="$(printf 'x%.0s' {1..500})"
  nuova
  md_ok 'compatibility:'
  controlla "${D}"
  expect 'compatibility vuoto' 1 'ERRORE compatibility' '500'
  nuova
  md_ok "compatibility: ${cinquecento}"
  controlla "${D}"
  expect_no 'compatibility di 500 caratteri: va bene' 0 'ERRORE'
  nuova
  md_ok "compatibility: ${cinquecento}x"
  controlla "${D}"
  expect 'compatibility di 501 caratteri' 1 'ERRORE compatibility' '500'
}

test_metadata() {
  nuova
  md_ok 'metadata:'$'\n''  author: example-org'$'\n''  version: "1.0"'
  controlla "${D}"
  expect_no 'metadata, una mappa di stringhe: va bene' 0 'ERRORE'
  nuova
  md_ok 'metadata: {author: example-org, version: "1.0"}'
  controlla "${D}"
  expect_no 'metadata su una riga: va bene' 0 'ERRORE'
  nuova
  md_ok 'metadata: {a: "b, c: d", e: f}'
  controlla "${D}"
  expect_no 'metadata su una riga, virgola e due punti fra virgolette' 0 \
    'ERRORE'
  nuova
  md_ok 'metadata: una stringa'
  controlla "${D}"
  expect 'metadata non è una mappa' 1 'ERRORE metadata' 'mappa'
  nuova
  md_ok 'metadata:'
  controlla "${D}"
  expect 'metadata vuoto' 1 'ERRORE metadata' 'mappa'
  nuova
  md_ok 'metadata:'$'\n''  version: 1.0'
  controlla "${D}"
  expect 'metadata con un valore numerico' 1 'ERRORE metadata' 'version' \
    'virgolette'
  nuova
  md_ok 'metadata: {version: 1.0}'
  controlla "${D}"
  expect 'metadata su una riga con un numero' 1 'ERRORE metadata' 'version'
  nuova
  md_ok 'metadata:'$'\n''  autore:'$'\n''    nome: x'
  controlla "${D}"
  expect 'metadata con un livello annidato' 1 'ERRORE riga 6' 'annidat'
  nuova
  md_ok 'metadata:'$'\n''  - una lista'
  controlla "${D}"
  expect 'metadata con una lista' 1 'ERRORE riga 5' 'chiave'
  nuova
  md_ok 'metadata:'$'\n''  a: uno'$'\n''  a: due'
  controlla "${D}"
  expect 'metadata con una chiave ripetuta' 1 'ERRORE riga 6' 'ripetuta'
  nuova
  md_ok 'metadata:'$'\n''  a: b: c'
  controlla "${D}"
  expect 'metadata con i due punti nel valore' 1 'ERRORE riga 5' 'due punti'
}

test_allowed_tools() {
  nuova
  md_ok 'allowed-tools: Read Bash(git log *)'
  controlla "${D}"
  expect_no 'allowed-tools, una stringa: va bene' 0 'ERRORE'
  nuova
  md_ok 'allowed-tools: [Read, Grep]'
  controlla "${D}"
  expect 'allowed-tools che è una lista su una riga' 1 'ERRORE allowed-tools' \
    'stringa'
  nuova
  md_ok 'allowed-tools:'$'\n''  - Read'$'\n''  - Grep'
  controlla "${D}"
  expect 'allowed-tools che è una lista' 1 'ERRORE allowed-tools' 'stringa'
  nuova
  md_ok 'allowed-tools: true'
  controlla "${D}"
  expect 'allowed-tools che è un booleano' 1 'ERRORE allowed-tools' 'stringa'
}

# --- Il corpo e i suoi file ----------------------------------------------

test_corpo_vuoto() {
  nuova
  md_ok '' ''
  controlla "${D}"
  expect 'corpo vuoto' 1 'ERRORE corpo' 'vuoto'
  nuova
  md_ok '' $'   \n\n  '
  controlla "${D}"
  expect 'corpo di soli spazi' 1 'ERRORE corpo' 'vuoto'
}

test_file_nominati() {
  nuova
  md_ok '' 'Leggi `references/manca.md` prima.'
  controlla "${D}"
  expect 'un file in backtick che non c è' 1 \
    'ERRORE file references/manca.md' 'riga 6'
  nuova
  md_ok '' 'Vedi [la guida](references/manca.md#sezione).'
  controlla "${D}"
  expect 'un link che non c è' 1 'ERRORE file references/manca.md'
  nuova
  md_ok '' 'Esegui `python3 scripts/manca.py <file>`.'
  controlla "${D}"
  expect 'uno script dentro un comando che non c è' 1 \
    'ERRORE file scripts/manca.py'
  nuova
  md_ok '' 'Esegui `python3 ${CLAUDE_SKILL_DIR}/scripts/manca.py`.'
  controlla "${D}"
  expect 'uno script con la variabile che non c è' 1 \
    'ERRORE file scripts/manca.py'
  nuova
  md_ok '' 'Vedi `assets/manca.png`.'
  controlla "${D}"
  expect 'un file in assets che non c è' 1 'ERRORE file assets/manca.png'
  nuova
  md_ok '' 'Vedi `references/../../fuori.md`.'
  mkdir -p "${D}/references"
  : > "${D}/../fuori.md"
  controlla "${D}"
  expect 'un percorso che esce dalla cartella' 1 'ERRORE file'
  nuova
  mkdir -p "${D}/references" "${D}/scripts" "${D}/assets"
  : > "${D}/references/guida.md"
  : > "${D}/scripts/fai.py"
  : > "${D}/assets/logo.png"
  local corpo='Leggi `references/guida.md` e [la guida](references/guida.md).'
  corpo+=$'\n''Esegui `python3 ${CLAUDE_SKILL_DIR}/scripts/fai.py <file>`.'
  corpo+=$'\n''Poi `scripts/fai.py --help`, `assets/logo.png`, e `references/`.'
  corpo+=$'\n''Link con il titolo: [g](./references/guida.md "Guida").'
  md_ok '' "${corpo}"
  controlla "${D}"
  expect_no 'i file che ci sono: nessun errore' 0 'ERRORE'
  nuova
  corpo='I file del progetto: `progetti/rete/scripts/altro.py`.'
  corpo+=$'\n''Un segnaposto: `references/<nome>.md`.'
  corpo+=$'\n''```text'$'\n''references/in-un-blocco.md'$'\n''```'
  md_ok '' "${corpo}"
  controlla "${D}"
  expect_no 'progetto, segnaposto e blocchi: nessun errore' 0 'ERRORE'
  nuova
  md_ok '' 'Tutte: `references/kb-*.md`.'
  controlla "${D}"
  expect 'un glob che non trova niente' 1 'ERRORE file references/kb-*.md'
  nuova
  mkdir -p "${D}/references"
  : > "${D}/references/kb-01.md"
  md_ok '' 'Tutte: `references/kb-*.md`.'
  controlla "${D}"
  expect_no 'un glob che trova: nessun errore' 0 'ERRORE'
  nuova
  md_ok '' 'Vedi [g](${CLAUDE_SKILL_DIR}/references/manca.md).'
  controlla "${D}"
  expect 'un link con la variabile che non c è' 1 \
    'ERRORE file references/manca.md'
  nuova
  mkdir -p "${D}/references"
  : > "${D}/references/guida.md"
  md_ok '' 'Vedi [g](${CLAUDE_SKILL_DIR}/references/guida.md).'
  controlla "${D}"
  expect_no 'un link con la variabile che c è: nessun errore' 0 'ERRORE'
  nuova
  md_ok '' $'1. Esegui:\n    ```bash\n    echo `scripts/manca.sh`\n    ```\n'
  controlla "${D}"
  expect_no 'un blocco rientrato in un elenco è un blocco' 0 'ERRORE'
  nuova
  md_ok '' $'``` `a` ```\n\nLeggi `references/manca.md`.'
  controlla "${D}"
  expect 'tre backtick con un backtick dopo non aprono un blocco' 1 \
    'ERRORE file references/manca.md'
}

# --- --caricamento ---------------------------------------------------------

test_caricamento() {
  nuova
  md_ok 'argument-hint: x'
  controlla "${D}" --caricamento
  expect 'caricamento: un campo in più, con il messaggio della pagina' 1 \
    'ERRORE caricamento' 'la pagina di Anthropic riporta' \
    'Unexpected key(s) in SKILL.md frontmatter: argument-hint. Allowed' \
    'Allowed properties are: allowed-tools, compatibility, description,' \
    'license, metadata, name'
  expect_no 'caricamento: nessun doppio avviso sul campo' 1 'AVVISO campo'
  # Il controllo dice che cosa scrive la pagina, non che cosa fa il sito: nella
  # prova del corso il caricamento non si è fermato.
  expect_no 'caricamento: non dice che il sito rifiuta' 1 'rifiuta'
  nuova
  md_ok 'model: sonnet'$'\n''agent: x'
  controlla "${D}" --caricamento
  expect 'caricamento: più campi, in ordine' 1 'frontmatter: agent, model.'
  nuova
  md_ok 'argument-hint: x'
  controlla "${D}"
  expect_no 'senza --caricamento argument-hint va bene' 0 'ERRORE' 'AVVISO'
  nuova
  md_ok 'license: MIT'$'\n''compatibility: x'$'\n''allowed-tools: Read'\
$'\n''metadata:'$'\n''  a: b'
  controlla "${D}" --caricamento
  expect_no 'caricamento: i sei campi vanno bene' 0 'ERRORE' 'AVVISO'
  nuova
  md_ok '' 'I file: !`ls`'
  controlla "${D}" --caricamento
  expect 'caricamento: una riga con !`…`' 0 'AVVISO caricamento' 'riga 6' \
    'chat'
  nuova
  md_ok '' 'I file: !`ls`'
  controlla "${D}"
  expect_no 'senza --caricamento la riga con !`…` va bene' 0 'AVVISO'
  nuova
  md_ok '' $'```bash\n!`ls`\n```'
  controlla "${D}" --caricamento
  expect_no 'caricamento: !`…` in un blocco è un esempio' 0 'AVVISO'
}

# --- Gli avvisi --------------------------------------------------------------

test_avviso_campi() {
  local campo
  nuova
  md_ok 'descrizione: scritto male'
  controlla "${D}"
  expect 'un campo sconosciuto è un avviso' 0 'AVVISO campo descrizione' \
    'si ignora senza errori'
  # shellcheck disable=SC2086  # l'elenco si divide apposta
  for campo in ${CAMPI_CC} license; do
    nuova
    md_ok "${campo}: x"
    controlla "${D}"
    expect_no "${campo} è un campo noto" 0 'AVVISO campo'
  done
}

test_avviso_lunghezze() {
  local corpo
  nuova
  corpo="$(printf 'r\n%.0s' {1..501})"
  md_ok '' "${corpo}"
  printf 'r\n' >> "${D}/SKILL.md"
  controlla "${D}"
  expect 'un corpo oltre le 500 righe' 0 'AVVISO corpo' '500 righe'
  nuova
  corpo="$(printf 'r\n%.0s' {1..499})"
  md_ok '' "${corpo}"
  controlla "${D}"
  expect_no 'un corpo di 500 righe: nessun avviso' 0 'AVVISO'
  nuova
  corpo="$(printf 'x%.0s' {1..12000})"
  md_ok '' "${corpo}"
  controlla "${D}"
  expect 'un corpo oltre i 5000 token stimati' 0 'AVVISO corpo' '5000 token'
  nuova
  corpo="$(printf 'x%.0s' {1..11000})"
  md_ok '' "${corpo}"
  controlla "${D}"
  expect_no 'un corpo sotto i 5000 token stimati: nessun avviso' 0 'AVVISO'
}

test_avviso_description() {
  local inizio
  nuova
  md "name: ${D##*/}"$'\n''description: Controlla le linee di prova.'
  controlla "${D}"
  expect 'description senza «quando»' 0 'AVVISO description' 'quando'
  nuova
  md "name: ${D##*/}"$'\n''description: Checks lines. Use when asked.'
  controlla "${D}"
  expect_no '«use when» basta' 0 'AVVISO'
  nuova
  md "name: ${D##*/}"$'\n''description: Controlla. Quando serve, si usa.'
  controlla "${D}"
  expect_no '«Quando» maiuscolo basta' 0 'AVVISO'
  for inizio in 'Io' 'Posso' 'Puoi' 'Ti' 'I can' 'You can'; do
    nuova
    md "name: ${D##*/}"$'\n'"description: ${inizio} fare cose quando serve."
    controlla "${D}"
    expect "description che comincia con «${inizio}»" 0 'AVVISO description' \
      'terza persona'
  done
  nuova
  md "name: ${D##*/}"$'\n''description: Possono entrare, quando serve.'
  controlla "${D}"
  expect_no '«Possono» non è «Posso»' 0 'AVVISO'
}

test_avviso_nome_vago() {
  local nome
  for nome in helper utils tools documents data files; do
    nuova "${nome}"
    md_ok ''
    controlla "${D}"
    expect "il nome vago ${nome}" 0 'AVVISO name' 'vago' "di' che cosa fa"
    expect_no "il nome vago ${nome}: l'imperativo con l'apostrofo" 0 \
      'dì che cosa'
  done
  nuova helper-linee
  md_ok ''
  controlla "${D}"
  expect_no 'un nome che contiene helper: nessun avviso' 0 'AVVISO'
}

test_avviso_evals() {
  nuova
  rm -rf "${D}/evals"
  md_ok ''
  controlla "${D}"
  expect 'nessun evals.json' 0 'AVVISO evals' 'manca' 'tre'
  nuova
  cat > "${D}/evals/evals.json" <<'EOF'
{"skill_name": "x", "evals": [{"id": 1, "prompt": "a", "expected_output": "b"},
  {"id": 2, "prompt": "a", "expected_output": "b"}]}
EOF
  md_ok ''
  controlla "${D}"
  expect 'meno di tre valutazioni' 0 'AVVISO evals' '2' 'tre'
  nuova
  printf '{non è JSON' > "${D}/evals/evals.json"
  md_ok ''
  controlla "${D}"
  expect 'un evals.json che non si legge' 0 'AVVISO evals' 'non si legge'
  nuova
  printf '[1, 2, 3]' > "${D}/evals/evals.json"
  md_ok ''
  controlla "${D}"
  expect 'un evals.json senza elenco evals' 0 'AVVISO evals' 'non si legge'
}

test_avviso_riferimenti_annidati() {
  nuova
  mkdir -p "${D}/references"
  printf 'Vedi anche `references/altra.md`.\n' > "${D}/references/guida.md"
  printf 'Fine.\n' > "${D}/references/altra.md"
  md_ok ''
  controlla "${D}"
  expect 'un riferimento che ne nomina un altro' 0 \
    'AVVISO references/guida.md' 'references/altra.md' 'un solo livello'
  nuova
  mkdir -p "${D}/references"
  printf 'Vedi [qui](altra.md).\n' > "${D}/references/guida.md"
  printf 'Fine.\n' > "${D}/references/altra.md"
  md_ok ''
  controlla "${D}"
  expect 'lo stesso con un link relativo' 0 'AVVISO references/guida.md'
  nuova
  mkdir -p "${D}/references"
  printf 'Una guida: guida.md e una-altra.md.\n' > "${D}/references/guida.md"
  printf 'Fine.\n' > "${D}/references/altra.md"
  md_ok ''
  controlla "${D}"
  expect_no 'il proprio nome, o uno che lo contiene: nessun avviso' 0 'AVVISO'
  nuova
  mkdir -p "${D}/references"
  printf '\xff\xfe binario\n' > "${D}/references/binario.dat"
  printf 'Fine.\n' > "${D}/references/altra.md"
  md_ok ''
  controlla "${D}"
  expect_no 'un file binario in references: nessun errore' 0 'ERRORE'
  expect 'un file binario in references: un avviso lo dice' 0 \
    'AVVISO references/binario.dat' 'non si legge come testo'
  if (( EUID != 0 )); then
    nuova
    mkdir -p "${D}/references"
    printf 'Fine.\n' > "${D}/references/chiuso.md"
    chmod 000 "${D}/references/chiuso.md"
    md_ok ''
    controlla "${D}"
    chmod 600 "${D}/references/chiuso.md"
    expect 'un file illeggibile in references: un avviso lo dice' 0 \
      'AVVISO references/chiuso.md' 'non si legge come testo'
  fi
  nuova
  mkdir -p "${D}/references"
  printf 'Fine.\n' > "${D}/references/guida.md"
  md_ok ''
  controlla "${D}"
  expect_no 'un riferimento leggibile: nessun avviso' 0 'non si legge'
}

test_avviso_barra_rovesciata() {
  nuova
  mkdir -p "${D}/scripts"
  md_ok '' 'Esegui scripts\fai.py e poi basta.'
  controlla "${D}"
  expect 'un percorso con la barra rovesciata' 0 'AVVISO riga 6' 'rovesciata'
  nuova
  md_ok '' 'Leggi reference\guida.md prima.'
  controlla "${D}"
  expect 'un altro percorso con la barra rovesciata' 0 'AVVISO riga 6' \
    'rovesciata'
  nuova
  md_ok '' $'```bash\nprintf \'a\\nb\'\ngrep -E \'foo\\.bar\' x\n```'
  controlla "${D}"
  expect_no 'printf e una regex non sono percorsi' 0 'AVVISO'
}

test_avviso_segnaposto() {
  nuova
  md_ok '' '# <Il compito, in poche parole>'
  controlla "${D}"
  expect 'un segnaposto rimasto' 0 'AVVISO riga 6' 'segnaposto' \
    '<Il compito, in poche parole>'
  nuova
  md_ok '' $'```text\n<La forma esatta>\n```\n\nUsa `cmd <apparato>`.'
  controlla "${D}"
  expect_no 'in un blocco e in `…` non è un segnaposto' 0 'AVVISO'
  nuova
  md_ok '' $'<details>\n<summary>Vecchio</summary>\n</details>\n<!-- nota -->'
  controlla "${D}"
  expect_no 'i tag HTML e i commenti non sono segnaposto' 0 'AVVISO'
  nuova
  md_ok '' 'Vedi <https://example.org/x> o <a@example.org>.'
  controlla "${D}"
  expect_no 'gli indirizzi fra parentesi non sono segnaposto' 0 'AVVISO'
  nuova
  md_ok '' 'Se a < b e c > d la linea è lenta.'
  controlla "${D}"
  expect_no 'un confronto a parole non è un segnaposto' 0 'AVVISO'
}

# --- Le skill di esempio e il modello --------------------------------------

test_esempi() {
  local s
  for s in revisione-pr risposta-assistenza audit-configurazione; do
    controlla "${ESEMPI}/${s}"
    expect "esempio ${s}: nessun errore" 0 "controlla_skill: ${s}: 0 errori"
    expect_no "esempio ${s}: nessun avviso sui campi" 0 'AVVISO campo' \
      'segnaposto' 'rovesciata'
  done
  controlla "${ESEMPI}/risposta-assistenza" --caricamento
  expect 'risposta-assistenza si può caricare' 0 \
    'controlla_skill: risposta-assistenza: 0 errori'
  expect_no 'risposta-assistenza: nessun avviso sui campi né su !' 0 \
    'AVVISO campo' 'AVVISO caricamento' 'ERRORE'
}

test_modello() {
  nuova nome-della-skill
  cp -- "${TEMPLATE}" "${D}/SKILL.md"
  controlla "${D}"
  expect 'il modello com è: la description' 1 'ERRORE description' 'angolari'
  expect 'il modello com è: i segnaposto' 1 'AVVISO riga' 'segnaposto'
  nuova altra-cartella
  cp -- "${TEMPLATE}" "${D}/SKILL.md"
  controlla "${D}"
  expect 'il modello in un altra cartella: il nome' 1 'ERRORE name' 'cartella'
  nuova nome-della-skill
  python3 -B -I - "${TEMPLATE}" "${D}/SKILL.md" <<'PY'
import re
import sys

with open(sys.argv[1], encoding="utf-8") as fh:
    testo = fh.read()
testo = testo.replace("<Che cosa fa, in terza persona>", "Controlla le linee")
testo = testo.replace("<le situazioni e le parole di chi chiede>",
                      "si chiede di una linea")
testo = re.sub(r"<[^<>\n]+>", "testo riempito", testo)
with open(sys.argv[2], "w", encoding="utf-8") as fh:
    fh.write(testo)
PY
  controlla "${D}"
  expect 'il modello riempito: nessun errore' 0 '0 errori'
  expect_no 'il modello riempito: nessun segnaposto' 0 'segnaposto' 'ERRORE'
}

# Lo script di audit-configurazione su un piccolo progetto finto, come dice la
# sua testata: 0 anche senza candidati, 2 su un file che non si legge; un valore
# dell'inventario si cerca come parola intera (192.0.2.1 non è in 192.0.2.11).
# Arguments: il testo della configurazione. Globals: RC, OUT.
audit_su() {
  printf '%b' "$1" > "${TMP}/rete/configurazioni/sw-uno.cfg"
  OUT="$(python3 -B -I \
    "${ESEMPI}/audit-configurazione/scripts/controlli_ovvi.py" \
    "${TMP}/rete" sw-uno 2>&1)"
  RC=$?
}

test_script_audit() {
  mkdir -p "${TMP}/rete/configurazioni"
  printf 'apparato,ip_gestione,firmware\nsw-uno,192.0.2.1,1.2\n' \
    > "${TMP}/rete/inventario.csv"
  audit_su 'hostname sw-uno\nip address 192.0.2.1/24\nversion 1.2\n'
  expect 'script: i valori ci sono: uscita 0, la testata' 0 'categoria'
  expect_no 'script: i valori ci sono: nessun candidato' 0 'non compare'
  audit_su '# gestione: 192.0.2.1.\n# firmware (1.2), fine\n'
  expect_no 'script: un valore prima di un punto o di una parentesi' 0 \
    'non compare'
  audit_su 'ip address 192.0.2.11/24\nversion 1.23\n'
  expect 'script: 192.0.2.1 non è in 192.0.2.11, 1.2 non è in 1.23' 0 \
    $'AUD-11\t-\t0\tip_gestione' $'AUD-13\t-\t0\tfirmware' 'non compare'
  audit_su 'ip address 1192.0.2.1/24\nversion 1.2.3\n'
  expect 'script: nemmeno in 1192.0.2.1, né in 1.2.3' 0 \
    $'AUD-11\t-\t0\tip_gestione' $'AUD-13\t-\t0\tfirmware'
  audit_su 'ip address 192x0x2x1/24\n'
  expect 'script: il punto è un punto, non un carattere qualsiasi' 0 \
    $'AUD-11\t-\t0\tip_gestione'
  printf 'apparato,ip_gestione\nsw-\xff,192.0.2.1\n' \
    > "${TMP}/rete/inventario.csv"
  audit_su 'ip address 192.0.2.1/24\n'
  expect 'script: un inventario che non è UTF-8: uscita 2' 2 \
    'non riesco a leggere' 'inventario.csv'
  OUT="$(python3 -B -I \
    "${ESEMPI}/audit-configurazione/scripts/controlli_ovvi.py" \
    "${REPO}/progetti/rete" sw-rovereto-01 2>&1)"
  RC=$?
  expect 'script: sul progetto rete: uscita 0' 0 'categoria'
}

# --- Gli argomenti e la libreria ------------------------------------------

test_argomenti() {
  controlla
  expect 'senza argomenti: uscita 2 e l uso' 2 'Uso'
  controlla "${TMP}/non-esiste"
  expect 'una cartella che non esiste: uscita 2' 2 'non esiste'
  nuova
  md_ok ''
  controlla "${D}" --non-so
  expect 'un opzione sconosciuta: uscita 2' 2 'non-so'
  controlla "${D}" "${D}"
  expect 'due cartelle: uscita 2' 2 'Uso'
  controlla "${D}/SKILL.md"
  expect 'un file invece di una cartella: uscita 2' 2 'non è una cartella'
  controlla --help
  expect '--help: uscita 0 e il contratto' 0 'Uso' '--caricamento'
  controlla "${D}/"
  expect 'la cartella con la barra finale' 0 'prova-linea'
  if ( cd "${D}" && controlla . && [[ "${OUT}" == *'linea: 0 errori'* ]] ); then
    pass 'la cartella corrente, «.»'
  else
    fail 'la cartella corrente, «.»'
  fi
  if (( EUID != 0 )); then
    nuova
    md_ok ''
    chmod 000 "${D}/SKILL.md"
    controlla "${D}"
    chmod 600 "${D}/SKILL.md"
    expect 'uno SKILL.md illeggibile: uscita 2' 2 'non riesco a leggere'
  fi
  nuova
  mkdir "${D}/SKILL.md"
  controlla "${D}"
  expect 'SKILL.md che è una cartella: errore' 1 'ERRORE SKILL.md'
}

# Lo strumento lanciato da solo non lascia file compilati accanto a sé, e
# senza il suo lettore esce 2: 1 vorrebbe dire che ha trovato errori.
test_moduli() {
  local copia="${TMP}/moduli"
  mkdir -p "${copia}/tools"
  nuova
  md_ok ''
  cp -- "${TOOL}" "${TOOL%/*}/lib_leggi_frontmatter.py" "${copia}/tools/"
  OUT="$("${copia}/tools/controlla_skill.py" "${D}" 2>&1)"
  RC=$?
  expect 'lanciato da solo, senza -B: esce 0' 0 'prova-linea: 0 errori'
  falso_file 'lanciato da solo: nessun __pycache__' "${copia}/tools/__pycache__"
  rm -f -- "${copia}/tools/lib_leggi_frontmatter.py"
  OUT="$(python3 -B -I "${copia}/tools/controlla_skill.py" "${D}" 2>&1)"
  RC=$?
  expect 'senza il suo lettore: uscita 2' 2 'lib_leggi_frontmatter'
}

test_ambiente() {
  nuova
  md_ok ''
  OUT="$(LC_ALL=C LANG=C python3 -B -I "${TOOL}" "${D}" 2>&1)"
  RC=$?
  expect 'con il locale C esce lo stesso testo' 0 'caratteri × 0,433'
  OUT="$(env -i PATH="${PATH}" LC_ALL=POSIX \
    python3 -B -I "${TOOL}" "${D}" 2>&1)"
  RC=$?
  expect 'con il locale POSIX e nessun ambiente' 0 'caratteri × 0,433'
  if [[ -x "${TOOL}" ]]; then
    pass 'lo strumento è eseguibile'
  else
    fail 'lo strumento è eseguibile'
  fi
  OUT="$("${TOOL}" "${D}" 2>&1)"
  RC=$?
  expect 'si lancia da solo' 0 'prova-linea: 0 errori'
  nuova
  md_ok 'descrizione: x'
  OUT="$(PN_D="${D}" PN_T="${TOOL%/*}" python3 -B -I - <<'PY' 2>&1
import os
import sys

sys.path.insert(0, os.environ["PN_T"])
import controlla_skill as cs

referto = cs.esamina_skill(os.environ["PN_D"])
print(referto.nome, len(referto.errori), len(referto.avvisi))
print(referto.avvisi[0])
referto = cs.esamina_skill(os.environ["PN_D"], caricamento=True)
print(len(referto.errori), referto.errori[0][:10])
PY
)"
  RC=$?
  expect 'si importa: esamina_skill' 0 'prova-linea 0 1' 'campo descrizione' \
    '1 caricament'
}

main() {
  command -v python3 >/dev/null 2>&1 || {
    echo "test_controlla_skill: manca python3" >&2
    exit 2
  }
  TMP="$(mktemp -d)" || exit 2
  trap 'rm -rf -- "${TMP}"' EXIT
  test_pulita
  test_plurali
  test_cornice
  test_yaml_virgolette
  test_yaml_due_punti
  test_yaml_indicatori
  test_yaml_struttura
  test_yaml_lista_colonna_1
  test_yaml_blocchi
  test_yaml_valore_sotto
  test_yaml_metadata_rigoroso
  test_yaml_escape
  test_yaml_flusso_appaiato
  test_yaml_blocco_tab
  test_yaml_messaggi
  test_bom_e_trattini
  test_name
  test_description
  test_compatibility
  test_metadata
  test_allowed_tools
  test_corpo_vuoto
  test_file_nominati
  test_caricamento
  test_avviso_campi
  test_avviso_lunghezze
  test_avviso_description
  test_avviso_nome_vago
  test_avviso_evals
  test_avviso_riferimenti_annidati
  test_avviso_barra_rovesciata
  test_avviso_segnaposto
  test_esempi
  test_modello
  test_script_audit
  test_argomenti
  test_moduli
  test_ambiente
  echo "PASS=${PASS} FAIL=${FAIL}"
  (( FAIL == 0 )) || exit 1
}

main "$@"
