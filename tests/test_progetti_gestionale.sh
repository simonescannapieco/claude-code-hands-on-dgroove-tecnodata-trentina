#!/bin/bash
#
# tests/test_progetti_gestionale.sh — verifica progetti/gestionale-php.
#
# Senza PHP: genera.py --check (0 sui dati del repository, 1 su una copia
# alterata o incompleta, 2 senza schema), schema e dati caricati in SQLite,
# regole dei dati sintetici su tutti i file del progetto (e il loro
# controllo su un esempio pulito e su uno sbagliato), assenza di CLAUDE.md
# e .claude/, _docente/ esclusa dall'esportazione.
# Con PHP 8.3 o Docker, in una copia del progetto: php -l su ogni file,
# composer install, PHPUnit, PHP_CodeSniffer, creazione del database e due
# script di bin/. Senza né PHP né Docker queste prove diventano una riga SKIP.
#
# Uso: tests/test_progetti_gestionale.sh
# Uscita: 0 nessun test fallito; 1 almeno un test fallito; 2 prerequisito
# mancante (python3, il progetto o tools/php.sh assenti).
set -uo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly ROOT="${SELF%/tests/*}"
readonly PROJ="${ROOT}/progetti/gestionale-php"
readonly PHP_SH="${ROOT}/tools/php.sh"
TMP="$(mktemp -d)"
readonly TMP
trap 'rm -rf "${TMP}"' EXIT

PASS=0
FAIL=0
SKIP=0
pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }
skip() { echo "  SKIP: $1"; SKIP=$((SKIP + 1)); }
die() { echo "FATAL: $*" >&2; exit 2; }

# esegui <comando…>: imposta OUT (stdout e stderr) e RC.
esegui() {
  OUT="$("$@" 2>&1)"
  RC=$?
}

# expect <descrizione> <rc atteso> <regex sull'output>
expect() {
  if (( RC == $2 )) && [[ "${OUT}" =~ $3 ]]; then
    pass "$1"
  else
    fail "$1 (rc=${RC}): ${OUT:0:600}"
  fi
}

# Le regole dei dati sintetici (../progetti/README.md) sui file indicati:
# e-mail, telefoni (la forma giusta a ogni «+NN»), IPv4, MAC.
# Stampa una riga per violazione; uscita 0 nessuna, 1 almeno una.
canone() {
  python3 -B -I - "$@" <<'EOF'
import re, sys
EMAIL = re.compile(r'[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+')
PREFISSO = re.compile(r'\+\d{2}(?= ?\d{3})')
TEL = re.compile(r'\+39 00\d \d{3} \d{4}(?!\d)')
IPV4 = re.compile(r'(?<![\d.])\d{1,3}(?:\.\d{1,3}){3}(?![\d.])')
MAC = re.compile(r'(?<![0-9A-Fa-f:])[0-9A-Fa-f]{2}(?::[0-9A-Fa-f]{2}){5}'
                 r'(?![0-9A-Fa-f:])')
DOC = ('192.0.2.', '198.51.100.', '203.0.113.')
trovate = []
for nome in sys.argv[1:]:
    testo = open(nome, encoding='utf-8', errors='replace').read()
    for m in EMAIL.finditer(testo):
        v = m.group(0)
        if not (v.endswith('@example.org') or
                re.fullmatch(r'ln\d{6}@ciaspolink\.example\.org', v)):
            trovate.append('%s: e-mail %s' % (nome, v))
    trovate += ['%s: telefono %s' % (nome, testo[m.start():m.start() + 16])
                for m in PREFISSO.finditer(testo)
                if not TEL.match(testo, m.start())]
    trovate += ['%s: IPv4 %s' % (nome, m.group(0))
                for m in IPV4.finditer(testo)
                if not m.group(0).startswith(DOC)]
    trovate += ['%s: MAC %s' % (nome, m.group(0))
                for m in MAC.finditer(testo)
                if not m.group(0).lower().startswith('00:00:5e:00:53:')]
print('\n'.join(trovate[:20]) or 'nessuna violazione')
sys.exit(1 if trovate else 0)
EOF
}

# Carica schema e dati in un SQLite in memoria e controlla i fatti essenziali.
carica_dati() {
  python3 -B -I - "${PROJ}/database" <<'EOF'
import glob, sqlite3, sys
cartella = sys.argv[1]
db = sqlite3.connect(':memory:')
db.executescript(open(cartella + '/schema.sql', encoding='utf-8').read())
db.execute('PRAGMA foreign_keys = OFF')
for nome in sorted(glob.glob(cartella + '/dati/*.sql')):
    db.executescript(open(nome, encoding='utf-8').read())
uno = lambda sql: db.execute(sql).fetchone()[0]
errori = ['riferimenti non validi: %d' % len(db.execute(
    'PRAGMA foreign_key_check').fetchall())] if db.execute(
    'PRAGMA foreign_key_check').fetchall() else []
minimi = {'clienti': 200, 'linee': 200, 'rivenditori': 10, 'ticket': 300,
          'fatture': 1000, 'righe_fattura': 2000, 'attivazioni': 200}
for tabella, minimo in sorted(minimi.items()):
    if uno('SELECT COUNT(*) FROM ' + tabella) < minimo:
        errori.append('%s: meno di %d righe' % (tabella, minimo))
nominati = uno("SELECT COUNT(*) FROM linee WHERE id BETWEEN 'LN-000201' AND "
               "'LN-000206' AND cliente_id BETWEEN 'CL-000101' AND 'CL-000106'")
apparati = uno("SELECT COUNT(*) FROM apparati WHERE id IN ("
               "'olt-pergine-01', 'olt-trento-01', 'olt-rovereto-01', "
               "'bng-trento-01', 'ptp-cles-01', 'bts-cles-01', "
               "'sbc-trento-01')")
if (nominati, apparati) != (6, 7):
    errori.append('storia comune: %d linee nominate, %d apparati' % (
        nominati, apparati))
print('; '.join(errori) or 'dati caricati: %d clienti, %d fatture' % (
    uno('SELECT COUNT(*) FROM clienti'), uno('SELECT COUNT(*) FROM fatture')))
sys.exit(1 if errori else 0)
EOF
}

test_generatore() {
  local copia="${TMP}/generatore"
  esegui python3 -B "${PROJ}/genera.py" --check
  expect "genera.py --check sui dati del repository" 0 "file identici"
  mkdir -p "${copia}"
  cp -a "${PROJ}/genera.py" "${PROJ}/database" "${copia}/"
  sed -i '0,/Prova/s//Prava/' "${copia}/database/dati/05_clienti.sql"
  esegui python3 -B "${copia}/genera.py" --check
  expect "copia alterata: uscita 1" 1 "diversi.*05_clienti\.sql"
  rm -- "${copia}/database/dati/10_provvigioni.sql"
  esegui python3 -B "${copia}/genera.py" --check
  expect "copia incompleta: uscita 1" 1 "10_provvigioni\.sql \(manca"
  rm -- "${copia}/database/schema.sql"
  esegui python3 -B "${copia}/genera.py" --check
  expect "copia senza schema: uscita 2" 2 "genera\.py: errore"
}

test_dati_e_regole() {
  local -a file=()
  esegui carica_dati
  expect "schema e dati in SQLite" 0 "^dati caricati"
  # genera.py è escluso: contiene i modelli dei valori, non i dati; i dati
  # che produce (database/dati/) sono controllati.
  readarray -t file < <(cd "${PROJ}" && command find . \
    \( -path ./vendor -o -path ./var -o -path ./.phpunit.cache \) -prune \
    -o -type f ! -name composer.lock ! -name genera.py -print | sort)
  esegui canone "${file[@]/#/${PROJ}/}"
  expect "regole dei dati sintetici (${#file[@]} file)" 0 "nessuna violazione"
  printf '%s\n' "laura.prova@example.org +39 000 000 0101 203.0.113.5" \
    "00:00:5e:00:53:2a ln000201@ciaspolink.example.org" > "${TMP}/buono.txt"
  esegui canone "${TMP}/buono.txt"
  expect "controllo delle regole: esempio pulito accettato" 0 "nessuna"
  local -a cattivi=(
    'mario@posta.it'   # canon:ok -- planted negative
    '+39 0461 123456'  # canon:ok -- planted negative
    '10.1.2.3'         # canon:ok -- planted negative
  )
  printf '%s\n' "${cattivi[*]}" > "${TMP}/cattivo.txt"
  esegui canone "${TMP}/cattivo.txt"
  expect "controllo delle regole: esempio sbagliato respinto" 1 \
    "e-mail .*telefono .*IPv4 "
  if [[ ! -e "${PROJ}/CLAUDE.md" && ! -e "${PROJ}/.claude" ]]; then
    pass "nessun CLAUDE.md né .claude/ nel progetto"
  else
    fail "CLAUDE.md o .claude/ presenti in ${PROJ}"
  fi
  esegui git -C "${ROOT}" check-attr export-ignore -- \
    progetti/gestionale-php/_docente/difetti-noti.md
  expect "_docente/ esclusa dall'esportazione" 0 "export-ignore: set"
}

# Copia il progetto senza vendor/, var/ e cache, nella cartella indicata.
copia_progetto() {
  local voce
  mkdir -p "$1"
  for voce in "${PROJ}"/* "${PROJ}"/.[!.]*; do
    case "${voce##*/}" in
      vendor | var | .phpunit.cache) ;;
      *) cp -a -- "${voce}" "$1/" ;;
    esac
  done
}

test_php() {
  local dir="${TMP}/progetto" lint
  if ! command -v php >/dev/null 2>&1 \
    && ! { command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; }
  then
    skip "PHP: né PHP né Docker disponibili (8 prove saltate)"
    return 0
  fi
  copia_progetto "${dir}"
  # codice PHP: le $ non vanno espanse dalla shell
  # shellcheck disable=SC2016
  lint='$e = 0; $n = 0; foreach (new RecursiveIteratorIterator(new
    RecursiveDirectoryIterator(".", FilesystemIterator::SKIP_DOTS)) as $f) {
    if (substr($f, -4) !== ".php" || strpos($f, "./vendor/") === 0) continue;
    $n++; exec(PHP_BINARY . " -l " . escapeshellarg($f) . " 2>&1", $o, $r);
    if ($r !== 0) { echo implode("\n", $o), "\n"; $e++; } $o = []; }
    echo "$n file, $e con errori\n"; exit($e === 0 ? 0 : 1);'
  cd "${dir}" || die "copia del progetto non accessibile"
  esegui "${PHP_SH}" php -r "${lint}"
  expect "php -l su ogni file PHP" 0 "[0-9]+ file, 0 con errori"
  esegui "${PHP_SH}" composer install --no-interaction --no-progress
  expect "composer install" 0 "Generating autoload files"
  esegui "${PHP_SH}" phpunit --colors=never
  expect "PHPUnit" 0 "OK \([0-9]+ tests"
  esegui "${PHP_SH}" php vendor/bin/phpcs --no-colors
  expect "PHP_CodeSniffer (PSR-12)" 0 ""
  esegui "${PHP_SH}" php bin/inizializza-db.php
  expect "bin/inizializza-db.php" 0 "Database creato"
  esegui "${PHP_SH}" php bin/inizializza-db.php
  expect "bin/inizializza-db.php di nuovo: uscita 1" 1 "esiste già"
  esegui "${PHP_SH}" php bin/esporta-attivazioni.php --giorno=2026-09-08
  expect "bin/esporta-attivazioni.php" 0 "completate il 2026-09-08 esportate"
  esegui "${PHP_SH}" php bin/fatturazione-mensile.php --periodo=2026-13
  expect "periodo non valido: uscita 2" 2 "Periodo non valido"
  cd "${ROOT}" || die "radice del repository non accessibile"
}

main() {
  command -v python3 >/dev/null 2>&1 || die "serve python3"
  [[ -f "${PROJ}/genera.py" && -x "${PHP_SH}" ]] \
    || die "mancano ${PROJ}/genera.py o ${PHP_SH}"
  echo "progetti/gestionale-php"
  test_generatore
  test_dati_e_regole
  test_php
  echo "PASS=${PASS} FAIL=${FAIL} SKIP=${SKIP}"
  (( FAIL == 0 )) || exit 1
}

main "$@"
