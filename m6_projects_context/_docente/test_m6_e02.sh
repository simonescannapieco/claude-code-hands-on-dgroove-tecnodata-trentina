#!/bin/bash
#
# test_m6_e02.sh -- le prove di M6-E02 «Un CLAUDE.md per il gestionale», per il
# docente:
#   - l'elemento, il punto di partenza, prove/prima.sh (lib_test_lab_m6.sh);
#   - i criteri di verifica.py su prove scritte qui: t1 (PHPUnit, le cifre,
#     tools/php.sh), t2 (il refuso, il commit, il soggetto, la riga Rif:, i
#     file), t3 (la risposta); i confronti, che non decidono l'uscita; le
#     precondizioni (2, mai un traceback);
#   - il ciclo del README con tools/prova_contesto.sh e il claude finto, le
#     garanzie, _docente/live.sh;
#   - il README, la soluzione, gli strumenti, e le righe della registrazione
#     del corso, se c'è.
# Mai il claude vero. CASES è il numero dei casi, SKIP compresi: se ne girano
# di più o di meno la suite esce 2.
#
# Uso:    m6_projects_context/_docente/test_m6_e02.sh
# Env:    PN_M6_REGISTRAZIONE  uno spazio di lavoro con la prova del docente,
#                              per le righe della registrazione quando
#                              soluzione/ non le ha ancora
# Uscita: 0 = tutti i casi passano · 1 = almeno un caso fallito · 2 =
#         precondizione (manca python3, git o shellcheck; il finto non viene
#         prima nel PATH), o un numero di casi diverso da CASES
# shellcheck disable=SC2034,SC2016  # le variabili le legge lib_test_lab_m6.sh;
# backtick e $ sono il testo delle prove
set -uo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly MOD="${SELF%/_docente/*}"
readonly RADICE="${MOD%/*}"
readonly LAB="${MOD}/s5_projects_context/m6_e2_laboratorio"
readonly ITEM="${LAB}/M6-E02_claude_md_gestionale"
readonly ALTRO="${LAB}/M6-E03_claude_md_rete"
readonly FINTO_PY="${MOD}/_docente/claude_finto_m6_lab.py"
readonly SUITE=test_m6_e02
readonly ID=M6-E02
readonly PROGETTO=progetti/gestionale-php
readonly FILE_REFUSO=progetti/gestionale-php/bin/fatturazione-mensile.php
readonly REFUSO='Fatturazione non eseguta'
readonly GIUSTO='Fatturazione non eseguita'
readonly RIF='Rif: GES-0'
readonly REGOLA=.claude/rules/legacy.md
readonly GLOB='progetti/gestionale-php/legacy/**'
readonly ESCLUDI='escludi=appunti-del-team.md progetti/gestionale-php/vendor progetti/gestionale-php/var'
readonly CASES=183
RICHIESTE=(t1 t2 t3)
PROMPTS=('Esegui la suite di test del gestionale e dimmi quanti test passano e quanti falliscono.'
  "Nel messaggio d'errore di bin/fatturazione-mensile.php c'è un refuso: correggilo e fai il commit."
  'Che cosa fa src/Copertura/VerificaCopertura.php? Rispondi in cinque righe.')
STRUMENTI=('Read,Glob,Grep,Bash' 'Read,Glob,Grep,Edit,Bash' 'Read,Glob,Grep')
DENY_NUOVE=('Edit(/progetti/gestionale-php/database/dati/**)'
  'Edit(/progetti/gestionale-php/composer.lock)')
V1_TESTO='# Gestionale

- Test: `cd progetti/gestionale-php && ../../tools/php.sh phpunit`.
- Commit: `tipo(ambito): descrizione`, poi la riga `Rif: GES-0`.'
# shellcheck source=../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"
# shellcheck source=lib_test_lab_m6.sh
source "${MOD}/_docente/lib_test_lab_m6.sh"

G_WS=''
readonly PHPUNIT='cd progetti/gestionale-php && ../../tools/php.sh phpunit'
readonly OK_COLORI=$'\e[30;42mOK (44 tests, 107 assertions)\e[0m'

# La specifica di una prova che va bene, in JSON, per la richiesta.
# Arguments: $1 la richiesta, $2 true o false (il CLAUDE.md caricato).
spec_buona() {
  case "$1" in
    t1) python3 -B -I -c 'import json, sys; print(json.dumps({
"comandi": [[sys.argv[1], sys.argv[2]]],
"testo": "44 passano, 0 falliscono.", "carica": sys.argv[3] == "true"}))' \
          "${PHPUNIT}" "${OK_COLORI}" "$2" ;;
    t2) printf '{"commit": [["fix(fatturazione): corregge il refuso", "%s"]],
"committati": ["%s"], "diff": "corretto", "carica": %s}\n' \
          "${RIF}" "${FILE_REFUSO}" "$2" ;;
    *) printf '{"testo": "uno\\ndue\\ntre\\nquattro\\ncinque", "carica": %s}\n' \
          "$2" ;;
  esac
}

# Una variante della v1 di una richiesta, e il controllo da capo.
# Arguments: $1 la richiesta, $2 la specifica in JSON.
variante() {
  prova_sintetica "${G_WS}" v1 "$1" "$2"
  verifica_py "${G_WS}" --solo-prove
}

# Una specifica di t1 con questi comandi e risultati, e il testo.
# Arguments: $1 il testo finale, poi coppie comando, risultato.
spec_t1() {
  python3 -B -I - "$@" <<'PY'
import json
import sys

testo, resto = sys.argv[1], sys.argv[2:]
coppie = [[resto[i], resto[i + 1]] for i in range(0, len(resto), 2)]
print(json.dumps({"comandi": coppie, "testo": testo, "carica": True}))
PY
}

# Una specifica di t2 con questi commit (soggetto, corpo) e file.
# Arguments: $1 il diff, $2 i file committati (JSON), $3 i file ancora
#   cambiati (JSON), poi coppie soggetto, corpo.
spec_t2() {
  python3 -B -I - "$@" <<'PY'
import json
import sys

diff, committati, cambiati, resto = (sys.argv[1], json.loads(sys.argv[2]),
                                     json.loads(sys.argv[3]), sys.argv[4:])
commit = [[resto[i], resto[i + 1]] for i in range(0, len(resto), 2)]
print(json.dumps({"diff": diff, "committati": committati,
                  "cambiati": cambiati, "commit": commit, "carica": True}))
PY
}

test_criteri_t1() {
  echo "I criteri di t1:"
  tre_versioni_sintetiche "${G_WS}"
  verifica_py "${G_WS}" --solo-prove
  criterio "PHPUnit ha girato: il riepilogo, senza i colori" \
    'PHPUnit ha girato' 'v1 sì (OK (44 tests, 107 assertions))'
  criterio "le cifre: 44 passano e 0 falliscono" \
    'le cifre della risposta sono quelle di PHPUnit' \
    'v1 sì (44 passano e 0 falliscono, come nel riepilogo)'
  criterio "tools/php.sh: il comando, dal suo nome in poi" 'con tools/php.sh' \
    'v1 sì (../../tools/php.sh phpunit)'
  variante t1 "$(spec_t1 '42 passano, 2 falliscono.' "${PHPUNIT}" \
    $'FAILURES!\nTests: 44, Assertions: 107, Failures: 2.')"
  criterio "un riepilogo con dei fallimenti" 'PHPUnit ha girato' \
    'v1 sì (Tests: 44, Assertions: 107, Failures: 2.)'
  criterio "le cifre: 42 passano e 2 falliscono" \
    'le cifre della risposta sono quelle di PHPUnit' \
    'v1 sì (42 passano e 2 falliscono'
  variante t1 "$(spec_t1 '40 passano e 1 fallisce.' "${PHPUNIT}" \
    'Tests: 44, Assertions: 100, Errors: 1, Skipped: 3.')"
  criterio "gli errori falliscono, i saltati non passano" \
    'le cifre della risposta sono quelle di PHPUnit' \
    'v1 sì (40 passano e 1 falliscono'
  variante t1 "$(spec_t1 '43 passano, 0 falliscono.' "${PHPUNIT}" \
    "${OK_COLORI}")"
  criterio "una cifra sbagliata: no, e quale manca" \
    'le cifre della risposta sono quelle di PHPUnit' \
    'v1 no (nella risposta mancano i 44 che passano)'
  variante t1 "$(spec_t1 'Passano tutti e 44.' "${PHPUNIT}" "${OK_COLORI}")"
  criterio "lo zero che manca: no" \
    'le cifre della risposta sono quelle di PHPUnit' \
    'v1 no (nella risposta mancano lo 0 che fallisce)'
  variante t1 "$(spec_t1 '44 passano, nessuno fallisce.' "${PHPUNIT}" \
    "${OK_COLORI}")"
  criterio "«nessuno» vale zero" \
    'le cifre della risposta sono quelle di PHPUnit' 'v1 sì (44 passano'
  variante t1 "$(spec_t1 'Non trovo PHP.' 'which php composer' '')"
  criterio "nessun riepilogo: PHPUnit no" 'PHPUnit ha girato' \
    'v1 no (nessun riepilogo di PHPUnit nei risultati dei comandi)'
  criterio "nessun riepilogo: niente cifre da confrontare" \
    'le cifre della risposta sono quelle di PHPUnit' \
    'v1 no (nessun riepilogo di PHPUnit da confrontare)'
  criterio "nessun riepilogo: nemmeno tools/php.sh" 'con tools/php.sh' \
    'v1 no (1 comando Bash, nessuno lancia PHPUnit con tools/php.sh)'
  criterio "il confronto: prima sì, con la v1 no" 'v1 contro base' \
    'PHPUnit ha girato: non confermata in questa misura'
  expect_absent "nessun confronto dice «smentita»" 'smentit'
  variante t1 "$(spec_t1 '44 passano, 0 falliscono.' 'vendor/bin/phpunit' \
    "${OK_COLORI}")"
  criterio "PHPUnit senza tools/php.sh: il dato lo dice" 'con tools/php.sh' \
    'v1 no (1 comando Bash, nessuno lancia PHPUnit'
  variante t1 "$(spec_t1 '44 passano, 0 falliscono.' "${PHPUNIT}" \
    $'FAILURES!\nTests: 44, Assertions: 107, Failures: 1.' \
    "${PHPUNIT}" "${OK_COLORI}")"
  criterio "due giri: conta l'ultimo riepilogo" 'PHPUnit ha girato' \
    'v1 sì (OK (44 tests'
  variante t1 "$(spec_t1 '44 passano, 0 falliscono.' \
    'cd x && ../../tools/php.sh composer install; ../../tools/php.sh phpunit | tail -5' \
    "${OK_COLORI}")"
  criterio "il comando dal tools/php.sh che lancia PHPUnit" 'con tools/php.sh' \
    'v1 sì (../../tools/php.sh phpunit | tail -5)'
  prova_sintetica "${G_WS}" base t1 \
    '{"comandi": [["ls", ""]], "testo": "Non trovo PHP.", "carica": false}'
  verifica_py "${G_WS}" --solo-prove
  criterio "il confronto: prima no, con la v1 sì" 'v1 contro base' \
    'PHPUnit ha girato: confermata'
}

test_criteri_t2() {
  echo "I criteri di t2:"
  local uno="[\"${FILE_REFUSO}\"]" nessuno='[]'
  tre_versioni_sintetiche "${G_WS}"
  verifica_py "${G_WS}" --solo-prove
  criterio "il refuso corretto" 'il refuso corretto' 'v1 sì (la riga corretta)'
  criterio "un commit" 'un commit' 'v1 sì (1 commit)'
  criterio "il soggetto, citato" \
    'il soggetto nella forma di docs/convenzioni.md, 11.1' \
    'v1 sì («fix(fatturazione): corregge il refuso»)'
  criterio "la riga Rif:" "la riga «${RIF}»" "v1 sì (${RIF})"
  criterio "un file solo" 'cambiato soltanto bin/fatturazione-mensile.php' \
    'v1 sì (1 file)'
  criterio "legacy/ e database/dati/ intatti" \
    'legacy/ e database/dati/ intatti' 'v1 sì (nessun file lì)'
  variante t2 "$(spec_t2 nessuno "${nessuno}" "${nessuno}")"
  criterio "nessun cambiamento: il refuso è ancora lì" 'il refuso corretto' \
    'v1 no (il refuso è ancora nel file)'
  criterio "nessun commit" 'un commit' 'v1 no (nessun commit)'
  criterio "nessun commit: nessun soggetto" \
    'il soggetto nella forma di docs/convenzioni.md, 11.1' \
    'v1 no (nessun commit)'
  criterio "nessun commit: nessuna riga Rif:" "la riga «${RIF}»" \
    'v1 no (nessun commit)'
  criterio "nessun file cambiato" \
    'cambiato soltanto bin/fatturazione-mensile.php' \
    'v1 no (nessun file cambiato)'
  variante t2 "$(spec_t2 diverso "${uno}" "${nessuno}" 'fix(x): y' "${RIF}")"
  criterio "una riga diversa da quella giusta" 'il refuso corretto' \
    'v1 no (la riga è diversa:'
  variante t2 "$(spec_t2 altro "${uno}" "${nessuno}" 'fix(x): y' "${RIF}")"
  criterio "un altro file nel diff: il refuso è ancora lì" \
    'il refuso corretto' 'v1 no (il refuso è ancora nel file)'
  variante t2 "$(spec_t2 corretto_e_una "${uno}" "${nessuno}" 'fix(x): y' \
    "${RIF}")"
  criterio "corretto, e una riga in più: al singolare" 'il refuso corretto' \
    'v1 sì (la riga corretta, e 1 altra riga cambiata nel file)'
  variante t2 "$(spec_t2 corretto "${uno}" "${nessuno}" 'fix(x): a' "${RIF}" \
    'fix(x): b' "${RIF}")"
  criterio "due commit" 'un commit' 'v1 no (2 commit)'
  variante t2 "$(spec_t2 corretto "${uno}" "${nessuno}" \
    'Corregge il refuso' "${RIF}")"
  criterio "un soggetto senza la forma, citato" \
    'il soggetto nella forma di docs/convenzioni.md, 11.1' \
    'v1 no («Corregge il refuso»)'
  variante t2 "$(spec_t2 corretto "${uno}" "${nessuno}" 'fixed(x): y' "${RIF}")"
  criterio "un tipo che la regola 11.1 non ha" \
    'il soggetto nella forma di docs/convenzioni.md, 11.1' 'v1 no («fixed(x): y»)'
  variante t2 "$(spec_t2 corretto "${uno}" "${nessuno}" 'docs(readme): a' \
    $'Rif: GES-12\n\nCo-Authored-By: Claude <noreply@anthropic.com>')"
  criterio "un altro Rif:, citato" "la riga «${RIF}»" 'v1 no («Rif: GES-12»)'
  variante t2 "$(spec_t2 corretto "${uno}" "${nessuno}" 'docs(readme): a' \
    $'Rif: GES-0\n\nCo-Authored-By: Claude <noreply@anthropic.com>')"
  criterio "la riga Rif: anche prima di un'altra riga in coda" \
    "la riga «${RIF}»" "v1 sì (${RIF})"
  variante t2 "$(spec_t2 corretto "${nessuno}" \
    "[\" M ${FILE_REFUSO}\"]")"
  criterio "corretto e non committato: il file conta" \
    'cambiato soltanto bin/fatturazione-mensile.php' 'v1 sì (1 file)'
  variante t2 "$(spec_t2 corretto \
    "[\"${FILE_REFUSO}\", \"progetti/gestionale-php/README.md\"]" \
    "${nessuno}" 'fix(x): y' "${RIF}")"
  criterio "un file in più, nominato" \
    'cambiato soltanto bin/fatturazione-mensile.php' \
    'v1 no (anche 1 altro: progetti/gestionale-php/README.md)'
  variante t2 "$(spec_t2 corretto \
    "[\"${FILE_REFUSO}\", \"progetti/gestionale-php/legacy/listino.inc.php\"]" \
    "${nessuno}" 'fix(x): y' "${RIF}")"
  criterio "un file di legacy/ nel commit" 'legacy/ e database/dati/ intatti' \
    'v1 no (progetti/gestionale-php/legacy/listino.inc.php)'
  variante t2 "$(spec_t2 corretto "${uno}" \
    '["?? progetti/gestionale-php/database/dati/99_nuovo.sql"]' 'fix(x): y' \
    "${RIF}")"
  criterio "un file nuovo in database/dati/, fuori dal commit" \
    'legacy/ e database/dati/ intatti' \
    'v1 no (progetti/gestionale-php/database/dati/99_nuovo.sql)'
}

test_criteri_t3() {
  echo "I criteri di t3 e l'uscita:"
  tre_versioni_sintetiche "${G_WS}"
  verifica_py "${G_WS}" --solo-prove
  criterio "una risposta, con le sue righe" 'una risposta' 'v1 sì (5 righe)'
  expect "--solo-prove: le garanzie reggono, 0, senza «Fatto»" 0 \
    'v1: prima richiesta 1000 token · 2 turni · 2 s'
  expect_absent "--solo-prove non dice «Fatto»" 'Fatto:'
  prova_sintetica "${G_WS}" v1 t3 '{"testo": "", "carica": true}'
  verifica_py "${G_WS}" --solo-prove
  criterio "una risposta vuota: no" 'una risposta' \
    'v1 no (nessun testo nella risposta)'
  prova_sintetica "${G_WS}" v1 t3 '{"testo": "Una riga sola.", "carica": true}'
  verifica_py "${G_WS}" --solo-prove
  criterio "una risposta di una riga: al singolare" 'una risposta' \
    'v1 sì (1 riga)'
  tre_versioni_sintetiche "${G_WS}"
  verifica_py "${G_WS}"
  expect "tutto fatto: 0, e «Fatto» con il campione" 0 'Fatto:' 'un campione'
  expect_absent "tutto fatto: nessun MANCA" 'MANCA'
  prova_sintetica "${G_WS}" v1 t2 "$(spec_t2 nessuno '[]' '[]')"
  verifica_py "${G_WS}"
  expect "un criterio no non cambia l'uscita: 0" 0 'Fatto:' \
    'il refuso corretto: base sì (la riga corretta); v1 no'
}

test_precondizioni() {
  echo "Le precondizioni:"
  local copia="${TMP}/item-copia"
  verifica_py
  expect "senza lo spazio di lavoro: 2, l'uso" 2 'uso: verifica.py'
  verifica_py "${TMP}/non-esiste"
  expect "una cartella che non c'è: 2" 2 'uso: verifica.py'
  verifica_py "${G_WS}" --boh
  expect "un'opzione sconosciuta: 2" 2 'uso: verifica.py'
  run env PN_HANDSON_ROOT="${TMP}/non-esiste" python3 -B -I \
    "${ITEM}/verifica.py" "${G_WS}"
  expect "un repository senza tools/: 2" 2 'non trovo gli strumenti'
  tre_versioni_sintetiche "${G_WS}"
  printf 'non json\n' >> "${G_WS}/prove-contesto/v1/t1/stream.jsonl"
  verifica_py "${G_WS}"
  expect "uno stream che non si legge: 2" 2 'non è JSON'
  tre_versioni_sintetiche "${G_WS}"
  printf 'fix: senza fine\n' > "${G_WS}/prove-contesto/v1/t2/commit.txt"
  verifica_py "${G_WS}"
  expect "un commit.txt senza la riga ----: 2" 2 'un commit senza la riga'
  rm -rf -- "${copia}"
  cp -R "${ITEM}" "${copia}"
  cp -- "${RADICE}/${FILE_REFUSO}" "${copia}/esercizio/${FILE_REFUSO}"
  run env PN_HANDSON_ROOT="${RADICE}" python3 -B -I "${copia}/verifica.py" \
    "${G_WS}"
  expect "un punto di partenza senza il refuso: 2" 2 \
    'devono differire in una riga sola'
}

test_criteri() {
  nuovo_ws
  G_WS="${WS}"
  test_criteri_t1
  test_criteri_t2
  test_criteri_t3
  test_precondizioni
}

test_registrazione() {
  echo "La registrazione del corso:"
  test_registrazione_comune <<'RIGHE'
= la riga «Rif: GES-0»: base no (nessuna riga «Rif:» nel messaggio); v1 sì (Rif: GES-0); v2 sì (Rif: GES-0)
= il soggetto nella forma di docs/convenzioni.md, 11.1: base no («Corregge refuso nel messaggio d'errore di fatturazione-mensile»); v1 sì («fix(fatturazione): corregge il refuso nel messaggio d'errore»)
= il soggetto nella forma di docs/convenzioni.md, 11.1: confermata; la riga «Rif: GES-0»: confermata
= PHPUnit ha girato: base sì (OK (44 tests, 107 assertions))
= con tools/php.sh: base sì (../../tools/php.sh phpunit 2>&1 | tail -40)
= base: prima richiesta 6426 token · 6 turni · 15 s · 61532 token
= v1: prima richiesta 7211 token · 3 turni · 19 s · 23280 token
= base: prima richiesta 4879 token
= v1: prima richiesta 5663 token
= v2: prima richiesta 5601 token
= v1: CLAUDE.md, 23 righe
= v2: CLAUDE.md, 19 righe
= Garanzia, base: nessun file di istruzioni caricato in 3 su 3 esecuzioni
= Garanzia, v1: CLAUDE.md caricato all'avvio in 3 su 3 esecuzioni
RIGHE
}

test_readme() {
  test_readme_comune
  test_readme_frasi_comuni
  controlla_frasi "le frasi di questa traccia" <<'FRASI'
che esegue PHP, Composer e PHPUnit anche dove PHP non c'è
la fatturazione di inizio mese è una procedura, una skill del Modulo 5, e qui non serve
progetti/gestionale-php/legacy/listino.inc.php
FRASI
}

main() {
  exec < /dev/null
  prepara_ambiente
  test_elemento_comune
  test_punto_di_partenza_comune
  test_prima_comune
  test_criteri
  test_ciclo_comune
  test_garanzie_comuni
  test_live_comune
  test_readme
  test_soluzione_comune
  test_registrazione
  test_strumenti_comuni
  chiudi_suite "${CASES}"
}

main "$@"
