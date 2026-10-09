#!/bin/bash
#
# test_verifica.sh -- verifica tools/verifica.sh su copie dell'albero di
# prova: l'esito del verifica.sh dell'elemento passa invariato (1 sul punto
# di partenza, 0 dopo la soluzione, 2 sulle sue precondizioni), il suo
# contratto (spazio di lavoro come $1 e come cartella corrente, repository
# in PN_HANDSON_ROOT), e le uscite 2: spazio di lavoro mancante, radice
# diversa, verifica.sh assente o non eseguibile, codice fuori contratto,
# ID sconosciuto.
#
# Uso:    tests/test_verifica.sh
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
  run env PN_HANDSON_ROOT="${r}" PN_WORKSPACE_ROOT="${w}" "${TOOLS}/${t}" "$@"
}

# Sostituisce il verifica.sh di M1-E01 con uno script di prova.
# Arguments: $1 l'albero, $2 il corpo dello script.
finto_verifica() {
  local f="$1/${REL_E01}/verifica.sh"
  printf '#!/bin/bash\nset -euo pipefail\n%s\n' "$2" > "${f}"
  chmod 755 "${f}"
}

t_esiti() {
  local r="${TMP}/esiti"
  make_repo "${r}/repo" || { fail "albero di prova (esiti)"; return; }
  tool "${r}/repo" "${r}/ws" prepara_esercizio.sh M1-E01
  tool "${r}/repo" "${r}/ws" verifica.sh M1-E01
  expect "sul punto di partenza: non ancora" 1 "NON ANCORA"
  expect "riporta il messaggio dell'elemento" 1 "Manca conteggio.txt"
  printf '7\n' > "${r}/ws/M1-E01/conteggio.txt"
  tool "${r}/repo" "${r}/ws" verifica.sh M1-E01
  expect "con un risultato sbagliato: non ancora" 1 "non è il numero"
  cp "${r}/repo/${REL_E01}/soluzione/conteggio.txt" "${r}/ws/M1-E01/"
  tool "${r}/repo" "${r}/ws" verifica.sh M1-E01
  expect "con la soluzione: fatto" 0 "VERIFICA OK"
  expect_absent "nessun «non ancora» quando è fatto" "NON ANCORA"
}

t_spazio_di_lavoro() {
  local r="${TMP}/spazio"
  make_repo "${r}/repo" || { fail "albero di prova (spazio)"; return; }
  tool "${r}/repo" "${r}/ws" verifica.sh M1-D01
  expect "spazio di lavoro mancante" 2 "tools/prepara_esercizio.sh M1-D01"
  tool "${r}/repo" "${r}/ws" prepara_esercizio.sh M1-D01 --radice "${r}/altra"
  tool "${r}/repo" "${r}/ws" verifica.sh M1-D01
  expect "senza la stessa --radice non lo trova" 2 "non c'è"
  tool "${r}/repo" "${r}/ws" verifica.sh M1-D01 --radice "${r}/altra"
  expect "con la stessa --radice sì" 1 "NON ANCORA"
  tool "${r}/repo" "${r}/ws" verifica.sh M1-E05
  expect "ID sconosciuto" 2 "trovate 0"
  tool "${r}/repo" "${r}/ws" verifica.sh
  expect "senza ID" 2 "manca l'identificativo"
}

t_contratto() {
  local r="${TMP}/contratto" ws
  make_repo "${r}/repo" || { fail "albero di prova (contratto)"; return; }
  tool "${r}/repo" "${r}/ws" prepara_esercizio.sh M1-E01
  ws="$(cd "${r}/ws/M1-E01" && pwd -P)"
  # shellcheck disable=SC2016  # il corpo è dello script di prova
  finto_verifica "${r}/repo" 'printf "ARG=%s\nPWD=%s\nROOT=%s\n" "$1" \
    "${PWD}" "${PN_HANDSON_ROOT:-}"'
  tool "${r}/repo" "${r}/ws" verifica.sh M1-E01
  expect "lo spazio di lavoro come primo argomento" 0 "ARG=${ws}"
  expect "lo spazio di lavoro come cartella corrente" 0 "PWD=${ws}"
  expect "il repository in PN_HANDSON_ROOT" 0 \
    "ROOT=$(cd "${r}/repo" && pwd -P)"
  finto_verifica "${r}/repo" 'echo "manca un prerequisito" >&2; exit 2'
  tool "${r}/repo" "${r}/ws" verifica.sh M1-E01
  expect "uscita 2 dell'elemento: precondizione" 2 "precondizione"
  finto_verifica "${r}/repo" 'exit 3'
  tool "${r}/repo" "${r}/ws" verifica.sh M1-E01
  expect "uscita fuori contratto: 2" 2 "fuori dal contratto"
  chmod 644 "${r}/repo/${REL_E01}/verifica.sh"
  tool "${r}/repo" "${r}/ws" verifica.sh M1-E01
  expect "verifica.sh non eseguibile" 2 "non eseguibile"
  rm -f "${r}/repo/${REL_E01}/verifica.sh"
  tool "${r}/repo" "${r}/ws" verifica.sh M1-E01
  expect "verifica.sh assente" 2 "assente"
}

main() {
  command -v git >/dev/null 2>&1 || { echo "manca git" >&2; exit 2; }
  [[ -d "${FIXTURE}" ]] || { echo "manca ${FIXTURE}" >&2; exit 2; }
  echo "test_verifica.sh"
  t_esiti
  t_spazio_di_lavoro
  t_contratto
  echo "PASS=${PASS} FAIL=${FAIL}"
  (( FAIL == 0 )) || exit 1
}

main "$@"
