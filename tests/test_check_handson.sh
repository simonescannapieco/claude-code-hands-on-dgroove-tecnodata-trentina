#!/bin/bash
#
# test_check_handson.sh -- verifica tools/check_handson.sh: l'albero di
# prova completo passa senza segnalazioni (anche con l'apostrofo tipografico
# in un titolo e con uno script dentro esercizio/ senza bit di esecuzione);
# poi, una copia per volta, ogni guasto deve dare uscita 1 e la sua
# segnalazione: file e regole della radice, moduli, intestazione e campi del
# manifest, id e cartelle, sezioni del README, verifica.sh, punto di
# partenza, soluzione/, progetti.txt, id ripetuti, cartelle orfane, bit di
# esecuzione di script e librerie; la copia per i partecipanti. vendor/
# ignorato non conta. Radice assente o fuori da git: uscita 2.
#
# Uso:    tests/test_check_handson.sh
# Uscita: 0 = tutti i test passano · 1 = almeno un test fallito
#         2 = precondizione (git mancante, albero di prova assente)
set -uo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly REPO="${SELF%/tests/*}"
readonly TOOLS="${REPO}/tools"
readonly FIXTURE="${REPO}/tests/fixtures/handson"
readonly M1='m1_fondamenti_llm'
readonly REL_E01="${M1}/s1_fondamenti_llm/m1_e1_prova/M1-E01_inventario"
readonly REL_D01="${M1}/s1_fondamenti_llm/m1_1_prova/M1-D01_saluto"
readonly TAB=$'\t'
# La riga di M1-E01 nell'albero di prova, campo per campo.
BASE_RIGA=(M1-E01 esercizio claude-code-pro s1_fondamenti_llm m1_e1_prova
  slides/practice/m1_demo_stesso_prompt/m1_e1_prova 10 T)
readonly BASE_RIGA
TMP="$(mktemp -d)" || { echo "mktemp non riesce" >&2; exit 2; }
readonly TMP
trap 'rm -rf -- "${TMP}"' EXIT
readonly BASE="${TMP}/base"
unset PN_HANDSON_ROOT
PASS=0
FAIL=0
RC=0
OUT=''
R=''

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

# Una copia fresca dell'albero di base in R. Arguments: $1 il nome.
fresh() {
  R="${TMP}/$1"
  cp -Rp "${BASE}" "${R}"
}

# check_handson.sh sulla copia R.
check_r() { run env PN_HANDSON_ROOT="${R}" "${TOOLS}/check_handson.sh"; }

# Sostituisce la riga di un ID nel manifest del Modulo 1 con i campi dati.
# Arguments: $1 l'ID, poi gli otto campi (o quanti se ne vogliono).
riga_m1() {
  local id="$1" nuova m="${R}/${M1}/manifest.tsv"
  shift
  nuova="$(IFS="${TAB}"; printf '%s' "$*")"
  awk -v id="${id}" -v r="${nuova}" 'BEGIN { FS = "\t" }
    $1 == id { print r; next } { print }' "${m}" > "${m}.nuovo" \
    && mv "${m}.nuovo" "${m}"
}

# La riga di M1-E01 con un solo campo cambiato.
# Arguments: $1 il campo (0-7), $2 il valore.
riga_campo() {
  local -a campi=("${BASE_RIGA[@]}")
  campi[$1]="$2"
  riga_m1 M1-E01 "${campi[@]}"
}

t_pulito() {
  fresh pulito
  check_r
  expect "l'albero di prova è in ordine" 0 "2 elementi, 0 segnalazioni"
  expect_absent "nessuna segnalazione" "  KO  "
  mkdir -p "${R}/${REL_E01}/esercizio/script"
  printf '#!/bin/bash\necho rotto\n' \
    > "${R}/${REL_E01}/esercizio/script/da_sistemare.sh"
  mkdir -p "${R}/progetti/rete/vendor"
  printf 'echo x\n' > "${R}/progetti/rete/vendor/terzi.sh"
  check_r
  expect "uno script dentro esercizio/ e vendor/ ignorato non contano" 0 \
    "0 segnalazioni"
}

t_radice() {
  fresh radice1
  rm -f "${R}/PRIMA_DEL_CORSO.md"
  check_r
  expect "file della radice mancante" 1 "PRIMA_DEL_CORSO.md: file mancante"
  fresh radice2
  printf '*.sh text eol=lf\n' > "${R}/.gitattributes"
  check_r
  expect "regola di esportazione mancante" 1 \
    "manca la regola «**/soluzione/** export-ignore»"
  fresh radice3
  rm -rf -- "${R}/progetti/assistenza-clienti"
  check_r
  expect "progetto condiviso mancante" 1 \
    "progetti/assistenza-clienti/: cartella mancante"
  fresh radice4
  rm -rf -- "${R}/m9_wrap_up"
  check_r
  expect "modulo mancante" 1 "attesa una cartella per il modulo 9, trovate 0"
  fresh radice5
  cp -Rp "${R}/m8_costi_ottimizzazione" "${R}/m8_doppione"
  check_r
  expect "due cartelle per lo stesso modulo" 1 "modulo 8, trovate 2"
  fresh radice6
  rm -f "${R}/m3_funzionalita_claude/README.md"
  check_r
  expect "README del modulo mancante" 1 "m3_funzionalita_claude/README.md"
}

t_manifest() {
  fresh man1
  printf 'id kind env section_dir subdeck_dir deck_path minutes title_it\n' \
    > "${R}/m2_prompting_avanzato/manifest.tsv"
  check_r
  expect "intestazione separata da spazi" 1 "senza l'intestazione"
  fresh man2
  riga_m1 M1-E01 "${BASE_RIGA[@]:0:7}"
  check_r
  expect "riga con sette campi" 1 "7 campi invece di 8"
  fresh man3
  riga_campo 1 eserciziox
  check_r
  expect "kind non valido" 1 "kind «eserciziox» non valido"
  fresh man4
  riga_campo 1 demo
  check_r
  expect "kind che non corrisponde all'id" 1 "non corrisponde a M1-E01"
  fresh man5
  riga_campo 2 claude-code-max
  check_r
  expect "env non valido" 1 "env «claude-code-max» non valido"
  fresh man6
  riga_campo 6 10m
  check_r
  expect "minutes non intero" 1 "minutes «10m»"
  fresh man7
  riga_campo 5 slides/practice/m1_demo_stesso_prompt/m1_e2_altro
  check_r
  expect "deck_path che non finisce con subdeck_dir" 1 "deck_path"
  fresh man8
  riga_campo 3 s1_altro
  check_r
  expect "cartella di sezione che non esiste" 1 \
    "s1_altro/m1_e1_prova/ non esiste"
  fresh man9
  riga_campo 7 ""
  check_r
  expect "titolo vuoto" 1 "title_it vuoto"
  fresh man10
  riga_campo 0 M2-E01
  check_r
  expect "id di un altro modulo" 1 "M2-E01 appartiene al modulo 2"
}

t_elementi() {
  fresh el1
  awk '!/^## Tempo/' "${R}/${REL_D01}/README.md" > "${R}/x" \
    && mv "${R}/x" "${R}/${REL_D01}/README.md"
  check_r
  expect "sezione del README mancante" 1 "manca la sezione «## Tempo»"
  fresh el2
  chmod 644 "${R}/${REL_D01}/verifica.sh"
  check_r
  expect "verifica.sh non eseguibile" 1 \
    "verifica.sh: senza il bit di esecuzione"
  fresh el3
  rm -rf -- "${R}/${REL_E01}/soluzione"
  check_r
  expect "soluzione/ mancante" 1 "soluzione/: mancante"
  fresh el4
  mv "${R}/${REL_D01}/demo" "${R}/${REL_D01}/esercizio"
  check_r
  expect "punto di partenza sbagliato per kind" 1 "demo/: mancante"
  fresh el5
  printf 'progetti/inesistente\n' > "${R}/${REL_E01}/progetti.txt"
  check_r
  expect "progetti.txt con un progetto che non c'è" 1 \
    "progetti/inesistente non esiste"
  fresh el6
  mv "${R}/${REL_E01}" "${R}/${REL_E01%_*}_Inventario"
  check_r
  expect "nome della cartella non valido" 1 "nome non valido (M1-E01_"
  fresh el7
  cp -Rp "${R}/${REL_E01}" "${R}/${REL_E01%/*}/M1-E03_orfano"
  check_r
  expect "cartella di elemento che nessun manifest nomina" 1 \
    "M1-E03_orfano/: nessun manifest nomina"
}

t_id_e_script() {
  local riga
  fresh id1
  mkdir -p "${R}/m2_prompting_avanzato/s1_fondamenti_llm"
  riga="M1-E01${TAB}esercizio${TAB}claude-code-pro${TAB}s1_fondamenti_llm"
  riga+="${TAB}m2_e1_prova${TAB}slides/practice/m2_x/m2_e1_prova${TAB}5${TAB}T"
  printf '%s\n' "${riga}" >> "${R}/m2_prompting_avanzato/manifest.tsv"
  check_r
  expect "id ripetuto fra due manifest" 1 "l'id M1-E01 compare più di una volta"
  fresh id2
  printf '# shellcheck shell=bash\n' > "${R}/tools/lib_extra.sh"
  chmod 755 "${R}/tools/lib_extra.sh"
  check_r
  expect "libreria eseguibile" 1 "tools/lib_extra.sh: libreria con il bit"
  fresh id3
  printf '#!/bin/bash\n' > "${R}/tools/nuovo.sh"
  chmod 644 "${R}/tools/nuovo.sh"
  check_r
  expect "script non eseguibile" 1 "tools/nuovo.sh: script senza il bit"
}

t_copia_e_precondizioni() {
  fresh copia1
  printf 'copia per i partecipanti\n' > "${R}/.copia_partecipanti"
  check_r
  expect "copia per i partecipanti con soluzione/" 1 \
    "nella copia per i partecipanti non deve esserci"
  rm -rf -- "${R}/${REL_D01}/soluzione" "${R}/${REL_D01}/_docente" \
    "${R}/${REL_E01}/soluzione" "${R}/${REL_E01}/_docente" \
    "${R}/progetti/rete/_docente"
  check_r
  expect "copia per i partecipanti senza soluzione/: in ordine" 0 \
    "0 segnalazioni"
  mkdir -p "${TMP}/nongit"
  cp -Rp "${BASE}/." "${TMP}/nongit/"
  rm -rf -- "${TMP}/nongit/.git"
  run env PN_HANDSON_ROOT="${TMP}/nongit" "${TOOLS}/check_handson.sh"
  expect "fuori da un repository git" 2 "repository git"
  run env PN_HANDSON_ROOT="${TMP}/manca" "${TOOLS}/check_handson.sh"
  expect "radice assente" 2 "radice del repository non trovata"
  run env PN_HANDSON_ROOT="${BASE}" "${TOOLS}/check_handson.sh" --boh
  expect "argomento in più" 2 "Uso:"
}

main() {
  command -v git >/dev/null 2>&1 || { echo "manca git" >&2; exit 2; }
  [[ -d "${FIXTURE}" ]] || { echo "manca ${FIXTURE}" >&2; exit 2; }
  make_repo "${BASE}" || { echo "albero di prova non costruito" >&2; exit 2; }
  echo "test_check_handson.sh"
  t_pulito
  t_radice
  t_manifest
  t_elementi
  t_id_e_script
  t_copia_e_precondizioni
  echo "PASS=${PASS} FAIL=${FAIL}"
  (( FAIL == 0 )) || exit 1
}

main "$@"
