#!/bin/bash
#
# test_esporta_studenti.sh -- verifica tools/esporta_studenti.sh su un
# repository di prova che contiene anche, come quello vero, l'albero di
# prova sotto tests/fixtures/handson/: nella copia per i partecipanti non
# c'è nessuna soluzione/ né _docente/ (nemmeno progetti/rete/_docente/),
# mentre gli alberi di prova tengono le loro; c'è il file segno; la copia è
# un repository git con un solo commit, uguale a ogni esportazione della
# stessa HEAD; il bundle si verifica e si clona; dentro la copia
# check_handson.sh passa e run_all.sh dà la soluzione come SKIP. Poi le
# modifiche non committate (avviso, fuori dalla copia), le regole di
# .gitattributes mancanti (uscita 1, niente bundle) e le precondizioni
# (cartella non vuota o dentro il repository, bundle esistente, nessun
# commit, radice che non è quella del repository, argomenti).
#
# Uso:    tests/test_esporta_studenti.sh
# Uscita: 0 = tutti i test passano · 1 = almeno un test fallito
#         2 = precondizione (git mancante, albero di prova assente)
set -uo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly REPO="${SELF%/tests/*}"
readonly TOOLS="${REPO}/tools"
readonly FIXTURE="${REPO}/tests/fixtures/handson"
readonly REL_D01='m1_fondamenti_llm/s1_fondamenti_llm/m1_1_prova/M1-D01_saluto'
TMP="$(mktemp -d)" || { echo "mktemp non riesce" >&2; exit 2; }
readonly TMP
trap 'rm -rf -- "${TMP}"' EXIT
readonly BASE="${TMP}/base"
unset PN_HANDSON_ROOT PN_WORKSPACE_ROOT
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
    fail "$1 (rc=${RC}, attesa $2, parola «$3»): ${OUT:0:400}"
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

# Le cartelle soluzione/ e _docente/ di un albero, fuori da tests/fixtures/.
trainer_dirs() {
  find "$1" -name .git -prune -o -type d \
    \( -name soluzione -o -name _docente \) -print | grep -v '/tests/fixtures/'
}
no_trainer_dirs() { [[ -z "$(trainer_dirs "$1")" ]]; }

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

# Un commit di tutto ciò che c'è nell'albero $1.
commit_all() {
  git -C "$1" add -A && git -C "$1" -c user.name=Test \
    -c user.email=test@example.org -c commit.gpgsign=false \
    commit -q --no-verify -m aggiunte
}

# esporta_studenti.sh dal repository $1 verso $2.
esporta() { run env PN_HANDSON_ROOT="$1" "${TOOLS}/esporta_studenti.sh" "$2"; }

t_copia() {
  local e="${TMP}/copia"
  esporta "${BASE}" "${e}"
  expect "esporta la copia per i partecipanti" 0 \
    "Copia per i partecipanti pronta"
  expect_absent "nessun avviso se non ci sono modifiche" "ATTENZIONE"
  check "nessuna soluzione/ né _docente/ nella copia" no_trainer_dirs "${e}"
  check "nemmeno progetti/rete/_docente/" \
    is_absent "${e}/progetti/rete/_docente"
  check "le soluzioni degli elementi restano fuori" \
    is_absent "${e}/${REL_D01}/soluzione"
  check "il punto di partenza c'è" is_file "${e}/${REL_D01}/demo/istruzioni.md"
  check "i progetti ci sono" is_file "${e}/progetti/rete/inventario.csv"
  check "gli alberi di prova tengono le loro soluzioni" \
    is_file "${e}/tests/fixtures/handson/${REL_D01}/soluzione/saluto.txt"
  check "e il loro _docente/" \
    is_file "${e}/tests/fixtures/handson/${REL_D01}/_docente/live.sh"
  check "il file segno" is_file "${e}/.copia_partecipanti"
  check "un solo commit" same_text "$(git -C "${e}" rev-list --count HEAD)" 1
  check "niente da committare" \
    same_text "$(git -C "${e}" status --porcelain)" ""
  run git -C "${e}" bundle verify "${e}.bundle"
  expect "il bundle si verifica" 0 "refs/heads/main"
  run git clone -q "${e}.bundle" "${TMP}/clonata"
  expect "il bundle si clona" 0 ""
  check "la copia clonata non ha soluzioni" no_trainer_dirs "${TMP}/clonata"
  run "${e}/tools/check_handson.sh"
  expect "dentro la copia check_handson.sh passa" 0 "0 segnalazioni"
  run "${e}/tools/run_all.sh"
  expect "dentro la copia run_all.sh salta la soluzione" 0 \
    "soluzione SKIP (copia per i partecipanti)"
  esporta "${BASE}" "${TMP}/copia2"
  check "la stessa HEAD dà lo stesso commit" same_text \
    "$(git -C "${e}" rev-parse HEAD)" "$(git -C "${TMP}/copia2" rev-parse HEAD)"
}

t_modifiche() {
  local r="${TMP}/modifiche"
  cp -Rp "${BASE}" "${r}"
  printf 'modifica non committata\n' >> "${r}/README.md"
  printf 'nuovo\n' > "${r}/nuovo_file.txt"
  esporta "${r}" "${TMP}/mod_copia"
  expect "esporta HEAD anche con modifiche non committate" 0 "pronta"
  expect "e avvisa" 0 "ATTENZIONE: modifiche non committate"
  expect "elencando i file" 0 "nuovo_file.txt"
  check "la modifica non entra nella copia" \
    cmp -s "${BASE}/README.md" "${TMP}/mod_copia/README.md"
  check "il file nuovo nemmeno" is_absent "${TMP}/mod_copia/nuovo_file.txt"
}

t_regole_mancanti() {
  local r="${TMP}/senza_regole"
  cp -Rp "${BASE}" "${r}"
  printf '*.sh text eol=lf\n' > "${r}/.gitattributes"
  commit_all "${r}"
  esporta "${r}" "${TMP}/regole_copia"
  expect "senza export-ignore la copia non va consegnata" 1 \
    "materiale del docente"
  check "e il bundle non viene creato" is_absent "${TMP}/regole_copia.bundle"
}

t_precondizioni() {
  local r="${TMP}/pre"
  mkdir -p "${TMP}/piena"
  printf 'x\n' > "${TMP}/piena/occupato.txt"
  esporta "${BASE}" "${TMP}/piena"
  expect "cartella non vuota" 2 "non è vuota"
  mkdir -p "${TMP}/vuota"
  esporta "${BASE}" "${TMP}/vuota"
  expect "cartella vuota esistente accettata" 0 "pronta"
  printf 'x\n' > "${TMP}/solo_bundle.bundle"
  esporta "${BASE}" "${TMP}/solo_bundle"
  expect "bundle già presente" 2 "il bundle esiste già"
  check "e la cartella non viene creata" is_absent "${TMP}/solo_bundle"
  esporta "${BASE}" "${BASE}/dentro"
  expect "cartella dentro il repository" 2 "dentro il repository"
  esporta "${BASE}/progetti" "${TMP}/sotto"
  expect "radice che non è quella del repository" 2 "non è la radice"
  mkdir -p "${r}/vergine"
  git -C "${r}/vergine" init -q
  esporta "${r}/vergine" "${TMP}/vergine_copia"
  expect "repository senza commit" 2 "nessun commit"
  run env PN_HANDSON_ROOT="${BASE}" "${TOOLS}/esporta_studenti.sh"
  expect "senza cartella" 2 "Uso:"
  run env PN_HANDSON_ROOT="${BASE}" "${TOOLS}/esporta_studenti.sh" a b
  expect "due cartelle" 2 "Uso:"
  ( cd "${TMP}" && env PN_HANDSON_ROOT="${BASE}" \
    "${TOOLS}/esporta_studenti.sh" relativa > /dev/null 2>&1 )
  check "una cartella relativa vale rispetto alla cartella corrente" \
    is_file "${TMP}/relativa/.copia_partecipanti"
}

main() {
  command -v git >/dev/null 2>&1 || { echo "manca git" >&2; exit 2; }
  [[ -d "${FIXTURE}" ]] || { echo "manca ${FIXTURE}" >&2; exit 2; }
  make_repo "${BASE}" || { echo "albero di prova non costruito" >&2; exit 2; }
  mkdir -p "${BASE}/tests/fixtures/handson"
  cp -Rp "${FIXTURE}/." "${BASE}/tests/fixtures/handson/"
  commit_all "${BASE}" || { echo "commit non riuscito" >&2; exit 2; }
  echo "test_esporta_studenti.sh"
  t_copia
  t_modifiche
  t_regole_mancanti
  t_precondizioni
  echo "PASS=${PASS} FAIL=${FAIL}"
  (( FAIL == 0 )) || exit 1
}

main "$@"
