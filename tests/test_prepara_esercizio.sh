#!/bin/bash
#
# test_prepara_esercizio.sh -- verifica tools/prepara_esercizio.sh su copie
# dell'albero di prova (tests/fixtures/handson/): che cosa entra nello
# spazio di lavoro e che cosa no (soluzione/, _docente/, anche quello dei
# progetti), git con un primo commit e il segno, le impostazioni prudenti
# di .claude/, le opzioni e la radice di default, il riepilogo finale
# secondo il tipo e l'ambiente dell'elemento, e ogni rifiuto con
# uscita 2 (spazio di lavoro già presente, ID sconosciuti o ripetuti,
# cartelle doppie, righe non valide, progetti.txt sbagliato, collegamenti
# simbolici, radici non ammesse, git mancante).
#
# Uso:    tests/test_prepara_esercizio.sh
# Uscita: 0 = tutti i test passano · 1 = almeno un test fallito
#         2 = precondizione (git mancante, albero di prova assente)
set -uo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly REPO="${SELF%/tests/*}"
readonly TOOLS="${REPO}/tools"
readonly FIXTURE="${REPO}/tests/fixtures/handson"
readonly SEZ='m1_fondamenti_llm/s1_fondamenti_llm'
readonly REL_E01="${SEZ}/m1_e1_prova/M1-E01_inventario"
readonly REL_D01="${SEZ}/m1_1_prova/M1-D01_saluto"
# Il rifiuto di una radice in ~/.claude (non comincia con ~: SC2088).
readonly NO_CONFIG='non può essere ~/.claude'
# Il riepilogo quando il passo dopo si lancia dal repository.
readonly DAL_REPOSITORY='  # dalla cartella esercitazioni: i comandi del README'
# Gli spazi di lavoro dei test nascono nella base dei temporanei della
# libreria: mai dentro ~/.claude, anche se TMPDIR punta lì.
# shellcheck source=../tools/lib_handson.sh
source "${TOOLS}/lib_handson.sh"
handson::init_temp_base
TMP="$(mktemp -d "${HANDSON_TEMP_BASE}/test.XXXXXX")" \
  || { echo "mktemp non riesce" >&2; exit 2; }
readonly TMP
trap 'rm -rf -- "${TMP}"' EXIT
unset PN_HANDSON_ROOT PN_WORKSPACE_ROOT ANTHROPIC_API_KEY
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

# Un controllo qualunque. Arguments: $1 il nome, poi il comando.
check() {
  local nome="$1"
  shift
  if "$@"; then pass "${nome}"; else fail "${nome}"; fi
}

is_file() { [[ -f "$1" ]]; }
is_absent() { [[ ! -e "$1" && ! -L "$1" ]]; }
same_text() { [[ "$1" == "$2" ]]; }
jq_true() { jq -e "$1" "$2" >/dev/null 2>&1; }
no_trainer_dirs() {
  [[ -z "$(find "$1" \( -name soluzione -o -name _docente \) -print)" ]]
}

# Un albero di prova completo: la fixture, i file veri della radice e gli
# strumenti, come repository git con un commit. Arguments: $1 la cartella.
make_repo() {
  local d="$1" f
  mkdir -p "${d}" && cp -Rp "${FIXTURE}/." "${d}/" || return 1
  for f in README.md PRIMA_DEL_CORSO.md CLAUDE.md .gitattributes .gitignore; do
    cp -p "${REPO}/${f}" "${d}/${f}" || return 1
  done
  mkdir -p "${d}/.claude" "${d}/tools" "${d}/tests" || return 1
  cp -p "${REPO}/.claude/settings.json" "${d}/.claude/" || return 1
  cp -p "${TOOLS}"/*.sh "${d}/tools/" || return 1
  cp -p "${REPO}/tests/esegui_test.sh" "${d}/tests/" || return 1
  git -C "${d}" init -q && git -C "${d}" add -A \
    && git -C "${d}" -c user.name=Test -c user.email=test@example.org \
      -c commit.gpgsign=false commit -q --no-verify -m albero
}

# Prepara con l'albero $1 e la radice $2. Arguments: $1, $2, poi gli
# argomenti dello strumento.
prepara() {
  local r="$1" w="$2"
  shift 2
  run env PN_HANDSON_ROOT="${r}" PN_WORKSPACE_ROOT="${w}" \
    "${TOOLS}/prepara_esercizio.sh" "$@"
}

t_contenuto() {
  local r="${TMP}/contenuto" ws
  make_repo "${r}/repo" || { fail "albero di prova (contenuto)"; return; }
  ws="${r}/ws/M1-E01"
  prepara "${r}/repo" "${r}/ws" M1-E01
  expect "prepara un esercizio" 0 "Spazio di lavoro pronto per M1-E01"
  expect "indica il comando per partire" 0 "claude"
  expect_absent "nessun errore quando va bene" "FATALE"
  check "copia il punto di partenza esercizio/" is_file "${ws}/compito.md"
  check "copia il progetto di progetti.txt" \
    is_file "${ws}/progetti/rete/inventario.csv"
  check "lascia fuori _docente/ del progetto" \
    is_absent "${ws}/progetti/rete/_docente"
  check "nessuna soluzione/ né _docente/" no_trainer_dirs "${ws}"
  check "il README dell'elemento resta nel repository" \
    is_absent "${ws}/README.md"
  check "aggiunge le impostazioni del repository" \
    cmp -s "${r}/repo/.claude/settings.json" "${ws}/.claude/settings.json"
  check "un solo commit" same_text "$(git -C "${ws}" rev-list --count HEAD)" 1
  check "niente da committare dopo la preparazione" \
    same_text "$(git -C "${ws}" status --porcelain)" ""
  check "il ramo è main" \
    same_text "$(git -C "${ws}" symbolic-ref --short HEAD)" main
  check "il segno dello spazio di lavoro" \
    same_text "$(git -C "${ws}" config --get corso.elemento)" M1-E01
  prepara "${r}/repo" "${r}/ws" M1-E01
  expect "non sovrascrive uno spazio di lavoro esistente" 2 \
    "tools/reset_esercizio.sh M1-E01"
  prepara "${r}/repo" "${r}/ws" M1-D01
  expect "prepara una demo" 0 "(demo)"
  check "copia il punto di partenza demo/" \
    is_file "${r}/ws/M1-D01/istruzioni.md"
}

# Una riga di OUT esattamente uguale, o nessuna. Arguments: $1 la riga.
has_line() { grep -qxF -- "$1" <<< "${OUT}"; }
lacks_line() { ! has_line "$1"; }

# Il riepilogo dice che cosa fare dopo, secondo il tipo e l'ambiente
# dell'elemento: un esercizio parte con claude; una demo rimanda ai
# comandi del README, nel terminale (spesso `claude -p' in un ciclo);
# un elemento su claude.ai si svolge nel browser, e la verifica legge i
# file dello spazio di lavoro che il README fa scrivere o costruire; un
# elemento con l'API lo esegue il docente.
t_suggerimenti() {
  local r="${TMP}/suggerimenti" man
  make_repo "${r}/repo" || { fail "albero di prova (suggerimenti)"; return; }
  prepara "${r}/repo" "${r}/ws" M1-E01
  expect "esercizio: il riepilogo" 0 "Alla fine:"
  check "esercizio: si parte con claude" has_line "  claude"
  prepara "${r}/repo" "${r}/ws" M1-D01
  expect "demo: i comandi del README, nel terminale" 0 \
    "i comandi del README, nel terminale"
  check "demo: nessun claude interattivo" lacks_line "  claude"
  man="${r}/repo/m1_fondamenti_llm/manifest.tsv"
  sed -i 's/^\(M1-D01\tdemo\t\)claude-code-pro/\1claude-ai-pro/' "${man}"
  if ! grep -qF -- $'M1-D01\tdemo\tclaude-ai-pro\t' "${man}"; then
    fail "il manifest di prova non è passato a claude-ai-pro"
    return
  fi
  prepara "${r}/repo" "${r}/ws2" M1-D01
  expect "claude.ai: si svolge su claude.ai" 0 "si svolge su claude.ai"
  expect "claude.ai: la verifica legge i file che il README fa scrivere" 0 \
    "La verifica legge i file che il README vi fa scrivere o costruire:"
  expect_absent "claude.ai: niente rifacimento" "rifacimento"
  expect_absent "claude.ai: niente «Alla fine» senza condizioni" \
    "Alla fine:"
  sed -i 's/^\(M1-D01\tdemo\t\)claude-ai-pro/\1trainer-api/' "${man}"
  if ! grep -qF -- $'M1-D01\tdemo\ttrainer-api\t' "${man}"; then
    fail "il manifest di prova non è passato a trainer-api"
    return
  fi
  prepara "${r}/repo" "${r}/ws3" M1-D01
  expect "API: lo esegue il docente" 0 "lo esegue il docente"
  expect_absent "API: non dice che l'elemento usa l'API" "con l'API"
  check "API: nessun claude interattivo" lacks_line "  claude"
  expect_absent "API: nessun rimando ai comandi del README" \
    "i comandi del README, nel terminale"
  sed -i 's/^\(M1-D01\tdemo\t\)trainer-api/\1trainer-local/' "${man}"
  if ! grep -qF -- $'M1-D01\tdemo\ttrainer-local\t' "${man}"; then
    fail "il manifest di prova non è passato a trainer-local"
    return
  fi
  prepara "${r}/repo" "${r}/ws4" M1-D01
  expect "servizio locale: lo esegue il docente" 0 "lo esegue il docente"
  check "servizio locale: nessun claude interattivo" lacks_line "  claude"
  expect_absent "servizio locale: nessun rimando ai comandi del README" \
    "i comandi del README, nel terminale"
}

# Il README di un elemento: il blocco con la preparazione e la riga dopo.
# Arguments: $1 la cartella dell'elemento, $2 l'ID, $3 la riga dopo (vuota:
# il blocco finisce lì).
readme_con() {
  printf '# Prova\n\n1. Dalla cartella esercitazioni:\n\n' > "$1/README.md"
  printf '       tools/prepara_esercizio.sh %s\n       %s\n\n' "$2" "$3" \
    >> "$1/README.md"
  printf '   Poi il resto.\n' >> "$1/README.md"
}

# Il README con il comando dopo in un passo a parte, come nei laboratori:
# la preparazione, una riga vuota, la prosa del passo, il blocco del comando.
# Arguments: $1 la cartella dell'elemento, $2 l'ID, $3 il comando.
readme_passo_dopo() {
  printf '1. Preparate:\n\n       tools/prepara_esercizio.sh %s\n\n' "$2" \
    > "$1/README.md"
  printf '2. Poi, sempre da qui:\n\n       %s\n' "$3" >> "$1/README.md"
}

# Se nel README il comando che segue la preparazione non è un cd, si lancia
# dal repository: il riepilogo non manda nello spazio di lavoro, né per un
# esercizio né per una demo, che il comando stia nello stesso blocco o nel
# passo dopo. Con un cd, o senza un comando dopo, resta il riepilogo di
# sempre; e un elemento su claude.ai resta quello che è.
t_suggerimenti_dal_repository() {
  local r="${TMP}/dal_repo" man
  make_repo "${r}/repo" || { fail "albero di prova (dal repository)"; return; }
  readme_con "${r}/repo/${REL_E01}" M1-E01 'tools/prova_contesto.sh M1-E01 base'
  prepara "${r}/repo" "${r}/ws1" M1-E01
  expect "esercizio con un comando dopo: dal repository" 0 "${DAL_REPOSITORY}"
  check "esercizio con un comando dopo: nessun cd" \
    lacks_line "  cd ${r}/ws1/M1-E01"
  check "esercizio con un comando dopo: nessun claude" lacks_line "  claude"
  expect "e il README resta il riferimento" 0 "${REL_E01}/README.md"
  readme_con "${r}/repo/${REL_D01}" M1-D01 'demo/in_classe.sh ~/spazio'
  prepara "${r}/repo" "${r}/ws1" M1-D01
  expect "demo con un comando dopo: dal repository" 0 "${DAL_REPOSITORY}"
  check "demo con un comando dopo: nessun cd" lacks_line "  cd ${r}/ws1/M1-D01"
  expect_absent "demo con un comando dopo: niente «poi»" "# poi i comandi"
  readme_passo_dopo "${r}/repo/${REL_E01}" M1-E01 \
    'tools/prove_skill.sh M1-E01 1'
  prepara "${r}/repo" "${r}/ws4" M1-E01
  expect "comando nel passo dopo: dal repository" 0 "${DAL_REPOSITORY}"
  check "comando nel passo dopo: nessun cd" lacks_line "  cd ${r}/ws4/M1-E01"
  check "comando nel passo dopo: nessun claude" lacks_line "  claude"
  readme_passo_dopo "${r}/repo/${REL_E01}" M1-E01 'cd ~/corso-claude-code/x'
  prepara "${r}/repo" "${r}/ws5" M1-E01
  expect_absent "un cd nel passo dopo: non dal repository" "${DAL_REPOSITORY}"
  check "un cd nel passo dopo: il cd" has_line "  cd ${r}/ws5/M1-E01"
  check "un cd nel passo dopo: claude" has_line "  claude"
  readme_con "${r}/repo/${REL_E01}" M1-E01 'cd ~/corso-claude-code/M1-E01'
  prepara "${r}/repo" "${r}/ws2" M1-E01
  expect_absent "esercizio con un cd dopo: non dal repository" \
    "${DAL_REPOSITORY}"
  check "esercizio con un cd dopo: il cd" has_line "  cd ${r}/ws2/M1-E01"
  check "esercizio con un cd dopo: claude" has_line "  claude"
  readme_con "${r}/repo/${REL_D01}" M1-D01 ''
  prepara "${r}/repo" "${r}/ws2" M1-D01
  expect_absent "demo col blocco che finisce: non dal repository" \
    "${DAL_REPOSITORY}"
  check "demo col blocco che finisce: il cd" has_line "  cd ${r}/ws2/M1-D01"
  expect "demo col blocco che finisce: i comandi del README" 0 \
    "# poi i comandi del README, nel terminale"
  man="${r}/repo/m1_fondamenti_llm/manifest.tsv"
  sed -i 's/^\(M1-D01\tdemo\t\)claude-code-pro/\1claude-ai-pro/' "${man}"
  readme_con "${r}/repo/${REL_D01}" M1-D01 'demo/in_classe.sh ~/spazio'
  prepara "${r}/repo" "${r}/ws3" M1-D01
  expect "claude.ai con un comando dopo: resta su claude.ai" 0 \
    "si svolge su claude.ai"
  expect_absent "claude.ai con un comando dopo: non dal repository" \
    "${DAL_REPOSITORY}"
}

t_impostazioni_prudenti() {
  local f="${REPO}/.claude/settings.json"
  if ! command -v jq >/dev/null 2>&1; then
    echo "  SKIP: jq assente, impostazioni non controllate (non è un PASS)"
    return
  fi
  check "settings.json: JSON valido" jq_true . "${f}"
  check "settings.json: niente allow, niente defaultMode, niente bypass" \
    jq_true '(.permissions.allow // [] | length) == 0
      and (.permissions | has("defaultMode") | not)
      and (tostring | test("bypassPermissions|dangerously") | not)' "${f}"
  # shellcheck disable=SC2016  # $d e $r sono variabili di jq, non di bash
  check "settings.json: nega la lettura di .env, .env.* e secrets/" \
    jq_true '.permissions.deny as $d | ["Read(**/.env)", "Read(**/.env.*)",
      "Read(**/secrets/**)"] | all(. as $r | $d | index($r) != null)' "${f}"
}

t_radici() {
  local r="${TMP}/radici"
  make_repo "${r}/repo" || { fail "albero di prova (radici)"; return; }
  prepara "${r}/repo" "${r}/ws" M1-E01 --radice "${r}/altrove"
  expect "--radice sceglie dove" 0 "${r}/altrove/M1-E01"
  check "con --radice non usa la radice di default" is_absent "${r}/ws/M1-E01"
  run env PN_HANDSON_ROOT="${r}/repo" HOME="${r}/casa" \
    "${TOOLS}/prepara_esercizio.sh" M1-D01
  expect "di default ~/corso-claude-code" 0 "${r}/casa/corso-claude-code/M1-D01"
  prepara "${r}/repo" "${r}/ws" M1-D01 --radice relativa
  expect "rifiuta una radice relativa" 2 "percorso assoluto"
  prepara "${r}/repo" "${r}/ws" M1-D01 --radice "${r}/ws/../ws2"
  expect "rifiuta una radice con .." 2 "senza . né .."
  prepara "${r}/repo" "${r}/ws" M1-D01 --radice "${r}/repo/spazi"
  expect "rifiuta una radice dentro il repository" 2 "dentro il repository"
  check "e non crea niente nel repository" is_absent "${r}/repo/spazi"
}

# Lo strumento $1 con l'albero $2 e HOME=$3, poi i suoi argomenti.
con_casa() {
  local t="$1" r="$2" casa="$3"
  shift 3
  run env PN_HANDSON_ROOT="${r}" HOME="${casa}" "${TOOLS}/${t}" "$@"
}

t_radice_config() {
  local r="${TMP}/config" casa="${TMP}/config/casa"
  make_repo "${r}/repo" || { fail "albero di prova (~/.claude)"; return; }
  mkdir -p "${casa}/.claude"
  ln -s "${casa}/.claude" "${r}/collegamento"
  con_casa prepara_esercizio.sh "${r}/repo" "${casa}" M1-D01 \
    --radice "${casa}/.claude/spazi"
  expect "rifiuta una radice dentro ~/.claude" 2 "${NO_CONFIG}"
  check "e non crea niente in ~/.claude" is_absent "${casa}/.claude/spazi"
  con_casa prepara_esercizio.sh "${r}/repo" "${casa}" M1-D01 \
    --radice "${casa}/.claude"
  expect "rifiuta ~/.claude stessa" 2 "${NO_CONFIG}"
  con_casa prepara_esercizio.sh "${r}/repo" "${casa}" M1-D01 \
    --radice "${r}/collegamento/spazi"
  expect "rifiuta un collegamento che porta in ~/.claude" 2 "${NO_CONFIG}"
  check "nemmeno attraverso il collegamento" is_absent "${casa}/.claude/spazi"
  run env PN_HANDSON_ROOT="${r}/repo" HOME="${casa}" \
    PN_WORKSPACE_ROOT="${casa}/.claude/x" \
    "${TOOLS}/prepara_esercizio.sh" M1-D01
  expect "anche con PN_WORKSPACE_ROOT" 2 "${NO_CONFIG}"
  con_casa verifica.sh "${r}/repo" "${casa}" M1-D01 \
    --radice "${casa}/.claude/spazi"
  expect "anche verifica.sh" 2 "${NO_CONFIG}"
  con_casa reset_esercizio.sh "${r}/repo" "${casa}" M1-D01 \
    --radice "${r}/collegamento"
  expect "anche reset_esercizio.sh" 2 "${NO_CONFIG}"
  con_casa prepara_esercizio.sh "${r}/repo" "${casa}" M1-D01 \
    --radice "${casa}/.claudette"
  expect "una cartella che comincia per .claude va bene" 0 \
    "Spazio di lavoro pronto"
}

t_argomenti() {
  local r="${TMP}/argomenti"
  make_repo "${r}/repo" || { fail "albero di prova (argomenti)"; return; }
  prepara "${r}/repo" "${r}/ws"
  expect "senza ID" 2 "manca l'identificativo"
  prepara "${r}/repo" "${r}/ws" M1-Q01
  expect "ID non valido" 2 "identificativo non valido"
  prepara "${r}/repo" "${r}/ws" M1-E07
  expect "ID che nessun manifest elenca" 2 "trovate 0"
  prepara "${r}/repo" "${r}/ws" M1-E01 M1-D01
  expect "un elemento per volta" 2 "un elemento per volta"
  prepara "${r}/repo" "${r}/ws" M1-E01 --boh
  expect "opzione sconosciuta" 2 "opzione sconosciuta"
  prepara "${r}/repo" "${r}/ws" --help
  expect "--help" 0 "Uso: tools/prepara_esercizio.sh"
}

t_righe_e_cartelle() {
  local r="${TMP}/righe" m ultima
  make_repo "${r}/repo" || { fail "albero di prova (righe)"; return; }
  m="${r}/repo/m1_fondamenti_llm/manifest.tsv"
  ultima="$(tail -n 1 "${m}")"
  printf '%s\n' "${ultima}" >> "${m}"
  prepara "${r}/repo" "${r}/ws" M1-E01
  expect "ID ripetuto nel manifest" 2 "trovate 2"
  make_repo "${r}/repo2" || { fail "albero di prova (cartelle)"; return; }
  cp -Rp "${r}/repo2/${REL_E01}" "${r}/repo2/${REL_E01%_*}_doppione"
  prepara "${r}/repo2" "${r}/ws" M1-E01
  expect "due cartelle per lo stesso ID" 2 "trovate 2"
  make_repo "${r}/repo3" || { fail "albero di prova (sezione)"; return; }
  m="${r}/repo3/m1_fondamenti_llm/manifest.tsv"
  awk 'BEGIN { FS = OFS = "\t" } NR == 3 { $4 = "../fuori" } { print }' \
    "${m}" > "${m}.nuovo" && mv "${m}.nuovo" "${m}"
  prepara "${r}/repo3" "${r}/ws" M1-E01
  expect "section_dir con .. rifiutato" 2 "non è valida"
  rm -f "${r}/repo3/m1_fondamenti_llm/manifest.tsv"
  prepara "${r}/repo3" "${r}/ws" M1-E01
  expect "manifest assente" 2 "manifest.tsv: assente"
}

t_progetti_e_collegamenti() {
  local r="${TMP}/progetti"
  make_repo "${r}/repo" || { fail "albero di prova (progetti)"; return; }
  printf 'progetti/inesistente\n' > "${r}/repo/${REL_E01}/progetti.txt"
  prepara "${r}/repo" "${r}/ws" M1-E01
  expect "progetti.txt con un progetto che non c'è" 2 "non esiste"
  check "e nessuno spazio di lavoro a metà" is_absent "${r}/ws/M1-E01"
  printf 'progetti/../tools\n' > "${r}/repo/${REL_E01}/progetti.txt"
  prepara "${r}/repo" "${r}/ws" M1-E01
  expect "progetti.txt con un percorso che esce" 2 "riga non valida"
  ln -s /etc/hostname "${r}/repo/${REL_D01}/demo/collegamento"
  prepara "${r}/repo" "${r}/ws" M1-D01
  expect "rifiuta un collegamento simbolico" 2 "collegamento simbolico"
  check "e nessuno spazio di lavoro a metà (demo)" is_absent "${r}/ws/M1-D01"
}

t_claude_propria() {
  local r="${TMP}/propria"
  make_repo "${r}/repo" || { fail "albero di prova (.claude)"; return; }
  mkdir -p "${r}/repo/${REL_D01}/demo/.claude"
  printf '{"permissions": {"deny": ["Read(**/dati/**)"]}}\n' \
    > "${r}/repo/${REL_D01}/demo/.claude/settings.json"
  prepara "${r}/repo" "${r}/ws" M1-D01
  expect "elemento con la sua .claude/" 0 "Spazio di lavoro pronto"
  check "tiene la .claude/ dell'elemento" grep -qF 'dati' \
    "${r}/ws/M1-D01/.claude/settings.json"
}

t_precondizioni() {
  local r="${TMP}/precondizioni" corto="${TMP}/solo_readlink"
  mkdir -p "${r}/nongit" "${corto}"
  cp -Rp "${FIXTURE}/." "${r}/nongit/"
  cp -p "${REPO}/.gitattributes" "${r}/nongit/"
  mkdir -p "${r}/nongit/.claude"
  cp -p "${REPO}/.claude/settings.json" "${r}/nongit/.claude/"
  prepara "${r}/nongit" "${r}/ws" M1-E01
  expect "fuori da un repository git" 2 "repository git"
  ln -s "$(command -v readlink)" "${corto}/readlink"
  run env PATH="${corto}" PN_HANDSON_ROOT="${r}/nongit" \
    "${TOOLS}/prepara_esercizio.sh" M1-E01
  expect "senza git" 2 "manca lo strumento: git"
  run env PN_HANDSON_ROOT="${r}/manca" "${TOOLS}/prepara_esercizio.sh" M1-E01
  expect "radice del repository assente" 2 "radice del repository non trovata"
}

main() {
  command -v git >/dev/null 2>&1 || { echo "manca git" >&2; exit 2; }
  [[ -d "${FIXTURE}" ]] || { echo "manca ${FIXTURE}" >&2; exit 2; }
  echo "test_prepara_esercizio.sh"
  t_contenuto
  t_suggerimenti
  t_suggerimenti_dal_repository
  t_impostazioni_prudenti
  t_radici
  t_radice_config
  t_argomenti
  t_righe_e_cartelle
  t_progetti_e_collegamenti
  t_claude_propria
  t_precondizioni
  echo "PASS=${PASS} FAIL=${FAIL}"
  (( FAIL == 0 )) || exit 1
}

main "$@"
