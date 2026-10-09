#!/bin/bash
#
# test_reset_esercizio.sh -- verifica tools/reset_esercizio.sh su copie
# dell'albero di prova: ricomincia davvero da capo (modifiche e file nuovi
# spariti), prepara uno spazio di lavoro che non c'era, e non cancella mai
# ciò che non supera i controlli (RU-01.S5): un collegamento simbolico, una
# cartella fatta a mano, un repository git senza il segno o con il segno di
# un altro elemento, un percorso vuoto o /. Ogni rifiuto esce con 2 e lascia
# tutto com'era.
#
# Uso:    tests/test_reset_esercizio.sh
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
is_link() { [[ -L "$1" ]]; }
same_text() { [[ "$1" == "$2" ]]; }

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

# Uno strumento con l'albero $1 e la radice degli spazi di lavoro $2.
# Arguments: $1, $2, lo strumento, poi i suoi argomenti.
tool() {
  local r="$1" w="$2" t="$3"
  shift 3
  run env PN_HANDSON_ROOT="${r}" PN_WORKSPACE_ROOT="${w}" \
    "${TOOLS}/${t}" "$@" < /dev/null
}

# Modalità scenario: questo stesso file, con la libreria caricata, chiama
# handson::guard_workspace. Arguments: lo spazio di lavoro, l'ID, la radice.
scenario_guard() {
  # shellcheck source=../tools/lib_handson.sh
  source "${TOOLS}/lib_handson.sh"
  HANDSON_WORKSPACE_ROOT="$3"
  handson::guard_workspace "$1" "$2"
}

t_ricomincia() {
  local r="${TMP}/ricomincia" ws
  make_repo "${r}/repo" || { fail "albero di prova (ricomincia)"; return; }
  ws="${r}/ws/M1-E01"
  tool "${r}/repo" "${r}/ws" prepara_esercizio.sh M1-E01
  printf 'modificato\n' > "${ws}/compito.md"
  printf 'nuovo\n' > "${ws}/nuovo.txt"
  tool "${r}/repo" "${r}/ws" reset_esercizio.sh M1-E01
  expect "ricomincia da capo" 0 "Cancellato: "
  expect "e prepara di nuovo" 0 "Spazio di lavoro pronto per M1-E01"
  expect_absent "nessun rifiuto quando va bene" "non cancello"
  check "il file modificato torna com'era" \
    cmp -s "${r}/repo/${REL_E01}/esercizio/compito.md" "${ws}/compito.md"
  check "il file nuovo sparisce" is_absent "${ws}/nuovo.txt"
  check "di nuovo un solo commit" \
    same_text "$(git -C "${ws}" rev-list --count HEAD)" 1
  tool "${r}/repo" "${r}/ws" reset_esercizio.sh M1-D01 -y
  expect "uno spazio di lavoro che non c'era si prepara e basta" 0 "non c'era"
  check "ed esiste" is_file "${r}/ws/M1-D01/istruzioni.md"
  tool "${r}/repo" "${r}/ws" reset_esercizio.sh M1-D01 --si \
    --radice "${r}/ws"
  expect "-y/--si e --radice accettati" 0 "--radice"
  tool "${r}/repo" "${r}/ws" reset_esercizio.sh M1-D01 --forza
  expect "opzione sconosciuta" 2 "opzione sconosciuta"
}

t_rifiuti() {
  local r="${TMP}/rifiuti" ws
  make_repo "${r}/repo" || { fail "albero di prova (rifiuti)"; return; }
  ws="${r}/ws/M1-E01"
  mkdir -p "${r}/ws" "${r}/bersaglio"
  printf 'da non perdere\n' > "${r}/bersaglio/prezioso.txt"
  ln -s "${r}/bersaglio" "${ws}"
  tool "${r}/repo" "${r}/ws" reset_esercizio.sh M1-E01
  expect "rifiuta un collegamento simbolico" 2 "collegamento simbolico"
  check "il collegamento resta" is_link "${ws}"
  check "il bersaglio resta" is_file "${r}/bersaglio/prezioso.txt"
  rm -f "${ws}"
  mkdir -p "${ws}"
  printf 'lavoro a mano\n' > "${ws}/mio.txt"
  tool "${r}/repo" "${r}/ws" reset_esercizio.sh M1-E01
  expect "rifiuta una cartella fatta a mano" 2 \
    "non è uno spazio di lavoro preparato"
  check "la cartella fatta a mano resta" is_file "${ws}/mio.txt"
  git -C "${ws}" init -q
  tool "${r}/repo" "${r}/ws" reset_esercizio.sh M1-E01
  expect "rifiuta un repository git senza il segno" 2 \
    "non è uno spazio di lavoro preparato"
  check "e lo lascia com'era" is_file "${ws}/mio.txt"
  rm -rf -- "${ws}"
  tool "${r}/repo" "${r}/ws" prepara_esercizio.sh M1-D01
  mv "${r}/ws/M1-D01" "${ws}"
  tool "${r}/repo" "${r}/ws" reset_esercizio.sh M1-E01
  expect "rifiuta lo spazio di lavoro di un altro elemento" 2 \
    "è lo spazio di lavoro di M1-D01"
  check "e lo lascia com'era" is_file "${ws}/istruzioni.md"
}

t_guardie() {
  local r="${TMP}/guardie"
  mkdir -p "${r}/ws/M1-E01"
  run bash "${SELF}" --scenario "" M1-E01 "${r}/ws"
  expect "percorso vuoto: niente da cancellare" 2 "percorso vuoto o /"
  run bash "${SELF}" --scenario / M1-E01 "${r}/ws"
  expect "/: niente da cancellare" 2 "percorso vuoto o /"
  run bash "${SELF}" --scenario "${r}/ws/M1-E01" M1-D01 "${r}/ws"
  expect "il nome deve essere quello dell'elemento" 2 "non è"
  run bash "${SELF}" --scenario "${r}/ws/M1-E01" M1-E01 "${r}/altra"
  expect "deve stare nella radice degli spazi di lavoro" 2 "non è"
}

main() {
  if [[ "${1:-}" == "--scenario" ]]; then
    shift
    scenario_guard "$@"
    exit $?
  fi
  command -v git >/dev/null 2>&1 || { echo "manca git" >&2; exit 2; }
  [[ -d "${FIXTURE}" ]] || { echo "manca ${FIXTURE}" >&2; exit 2; }
  echo "test_reset_esercizio.sh"
  t_ricomincia
  t_rifiuti
  t_guardie
  echo "PASS=${PASS} FAIL=${FAIL}"
  (( FAIL == 0 )) || exit 1
}

main "$@"
