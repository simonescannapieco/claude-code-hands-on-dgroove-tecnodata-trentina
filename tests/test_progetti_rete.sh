#!/bin/bash
#
# Test di progetti/rete: il generatore deterministico (genera.py --check),
# le regole dei dati sintetici (genera.py --canone), la verita' di
# riferimento dei problemi inseriti, le entita' condivise con il gestionale
# e gli avvenimenti della settimana nei log.
#
# Uso:    bash tests/test_progetti_rete.sh
# Uscita: 0 tutti i test superati, 1 almeno un test fallito,
#         2 precondizione mancante (python3 >= 3.8, il generatore).
# RETE_PYTHON sceglie l'interprete (predefinito: python3).
# Nella copia dei partecipanti (file segno .copia_partecipanti, senza
# progetti/rete/_docente/) le prove che usano il materiale del docente sono
# SKIP; nel repository completo _docente/ deve esserci, o sono FAIL.

set -uo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
ROOT="$(dirname "$(dirname "${SELF}")")"
readonly ROOT
readonly RETE="${ROOT}/progetti/rete"
readonly DOCENTE="${RETE}/_docente"
readonly MARKER="${ROOT}/.copia_partecipanti"
readonly PY="${RETE_PYTHON:-python3}"
readonly SEEDED=40
readonly MIN_LOG_LINES=5000
readonly MAX_LOG_LINES=20000

PASS=0
FAIL=0
SKIP=0
TMP=""
OUT=""
RC=0
KEY_MODE=""

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }
skip() { echo "  SKIP: $1"; SKIP=$((SKIP + 1)); }
err() { echo "test_progetti_rete.sh: $*" >&2; }

cleanup() {
  if [[ -n "${TMP}" && "${TMP}" != "/" && -d "${TMP}" && ! -L "${TMP}" ]]
  then
    rm -rf -- "${TMP}"
  fi
}

#######################################
# Decide come trattare le prove che usano il materiale del docente.
# Globals: DOCENTE, MARKER, KEY_MODE (scritto): «run» se _docente/ c'e';
#   «skip» se manca nella copia dei partecipanti (c'e' il file segno);
#   «missing» se manca nel repository completo, che e' un errore.
#######################################
detect_key_mode() {
  if [[ -d "${DOCENTE}" ]]; then
    KEY_MODE="run"
  elif [[ -e "${MARKER}" ]]; then
    KEY_MODE="skip"
  else
    KEY_MODE="missing"
  fi
}

#######################################
# Arguments: il nome della prova
# Returns: 0 se la prova puo' girare; altrimenti registra SKIP (copia dei
#   partecipanti) o FAIL (repository completo senza _docente/) e torna 1.
#######################################
needs_key() {
  case "${KEY_MODE}" in
    run)
      return 0
      ;;
    skip)
      skip "$1: copia dei partecipanti senza progetti/rete/_docente/"
      ;;
    *)
      fail "$1: progetti/rete/_docente/ manca nel repository completo"
      ;;
  esac
  return 1
}

#######################################
# Esegue genera.py di una cartella con gli argomenti dati.
# Globals: PY, OUT, RC (scritti)
# Arguments: cartella del progetto, argomenti di genera.py
#######################################
run_gen() {
  local dir="$1"
  shift
  OUT="$("${PY}" -B -I "${dir}/genera.py" "$@" 2>&1)"
  RC=$?
}

# Copia completa del progetto in TMP/$1 (senza cache di Python).
full_copy() {
  cp -a -- "${RETE}" "${TMP}/$1" || return 1
  rm -rf -- "${TMP}/$1/generatore/__pycache__"
}

# Copia del solo generatore in TMP/$1: per i controlli del canone.
mini_copy() {
  mkdir -p -- "${TMP}/$1" || return 1
  cp -- "${RETE}/genera.py" "${TMP}/$1/" || return 1
  cp -r -- "${RETE}/generatore" "${TMP}/$1/" || return 1
  rm -rf -- "${TMP}/$1/generatore/__pycache__"
}

#######################################
# Conta le righe di un log con orario in [da, a) che soddisfano un'ERE.
# Arguments: file, da, a (ISO, es. 2026-09-08T10:12), espressione
# Outputs: il numero su STDOUT
#######################################
count_window() {
  awk -v from="$2" -v to="$3" -v re="$4" '
    { stamp = $1; if ($2 ~ /^[0-9][0-9]:/) stamp = $1 "T" $2 }
    stamp >= from && stamp < to && $0 ~ re { n++ }
    END { print n + 0 }' "$1"
}

# --- il generatore ---------------------------------------------------------

test_check_clean() {
  run_gen "${RETE}" --check
  if (( RC == 0 )) && [[ "${OUT}" == *"file identici"* ]]; then
    pass "genera.py --check: ${OUT##*: }"
  else
    fail "genera.py --check rc=${RC}: ${OUT:0:300}"
  fi
}

test_check_detects_changes() {
  local copy="${TMP}/alterata"
  full_copy alterata || { fail "copia non riuscita"; return; }
  echo "riga aggiunta" >>"${copy}/allarmi.csv"
  rm -f -- "${copy}/log/dhcp/kea-dhcp4_2026-09-12.log"
  echo "estraneo" >"${copy}/log/syslog/estraneo.log"
  run_gen "${copy}" --check
  if (( RC == 1 )) && [[ "${OUT}" == *"diverso: allarmi.csv"* ]]; then
    pass "--check segnala un file modificato (rc=1)"
  else
    fail "file modificato non segnalato: rc=${RC}: ${OUT:0:300}"
  fi
  if (( RC == 1 )) &&
    [[ "${OUT}" == *"manca: log/dhcp/kea-dhcp4_2026-09-12.log"* ]]; then
    pass "--check segnala un file mancante (rc=1)"
  else
    fail "file mancante non segnalato: rc=${RC}: ${OUT:0:300}"
  fi
  if (( RC == 1 )) && [[ "${OUT}" == *"log/syslog/estraneo.log"* ]]; then
    pass "--check segnala un file in piu' (rc=1)"
  else
    fail "file in piu' non segnalato: rc=${RC}: ${OUT:0:300}"
  fi
}

test_student_copy() {
  full_copy studenti || { fail "copia non riuscita"; return; }
  rm -rf -- "${TMP}/studenti/_docente"
  run_gen "${TMP}/studenti" --check
  if (( RC == 0 )) && [[ "${OUT}" == *"file identici"* ]] &&
    [[ ! -e "${TMP}/studenti/_docente" ]]; then
    pass "copia dei partecipanti senza _docente/: --check verde"
  else
    fail "copia dei partecipanti: rc=${RC}: ${OUT:0:300}"
  fi
}

test_versions() {
  local version exe found=0 failed=0 out rc
  for version in 3.8 3.9 3.10 3.11 3.12 3.13 3.14; do
    if ! exe="$(command -v "python${version}")"; then
      continue
    fi
    found=$((found + 1))
    out="$("${exe}" -B -I "${RETE}/genera.py" --check 2>&1)"
    rc=$?
    if (( rc != 0 )); then
      failed=$((failed + 1))
      err "python${version}: rc=${rc}: ${out:0:200}"
    fi
  done
  if (( found < 2 )); then
    skip "meno di due versioni di Python disponibili: confronto saltato"
  elif (( failed == 0 )); then
    pass "file identici con ${found} versioni di Python"
  else
    fail "${failed} versioni di Python su ${found} danno file diversi"
  fi
}

test_fail_closed() {
  if needs_key "chiave con un marcatore introvabile"; then
    full_copy chiave || { fail "copia non riuscita"; return; }
    sed -i 's/secret = testing123/secret = testing999/' \
      "${TMP}/chiave/_docente/chiave-problemi.tsv"
    run_gen "${TMP}/chiave" --check
    if (( RC == 2 )) && [[ "${OUT}" == *"marcatore non trovato"* ]]; then
      pass "chiave con un marcatore introvabile: errore (rc=2)"
    else
      fail "marcatore introvabile: rc=${RC}: ${OUT:0:300}"
    fi
  fi
  mini_copy monco || { fail "copia non riuscita"; return; }
  rm -f -- "${TMP}/monco/generatore/canone.py"
  run_gen "${TMP}/monco" --check
  if (( RC == 2 )) && [[ "${OUT}" == *"generatore incompleto"* ]]; then
    pass "generatore incompleto: errore (rc=2)"
  else
    fail "generatore incompleto: rc=${RC}: ${OUT:0:300}"
  fi
  run_gen "${RETE}" --opzione-inesistente
  if (( RC == 2 )) && [[ "${OUT}" == *"usage"* ]]; then
    pass "opzione sconosciuta: errore d'uso (rc=2)"
  else
    fail "opzione sconosciuta: rc=${RC}: ${OUT:0:300}"
  fi
  needs_key "chiave con una riga incompleta" || return 0
  full_copy chiave-monca || { fail "copia non riuscita"; return; }
  printf 'P99\tbng-trento-01\n' \
    >>"${TMP}/chiave-monca/_docente/chiave-problemi.tsv"
  run_gen "${TMP}/chiave-monca" --check
  if (( RC == 2 )) && [[ "${OUT}" == *"chiave incompleta"* ]]; then
    pass "chiave con una riga incompleta: errore (rc=2)"
  else
    fail "riga incompleta della chiave: rc=${RC}: ${OUT:0:300}"
  fi
}

test_write_mode() {
  local target="${TMP}/scrittura" out rc
  run_gen "${RETE}" --out "${target}"
  out="$(diff -r -- "${RETE}/configurazioni" "${target}/configurazioni" \
    2>&1)"
  rc=$?
  if (( RC == 0 && rc == 0 )) && [[ "${OUT}" == *"file scritti"* ]]; then
    pass "genera.py --out scrive gli stessi file del repository"
  else
    fail "genera.py --out rc=${RC} diff rc=${rc}: ${out:0:300}"
  fi
}

test_suite_preconditions() {
  local out rc
  out="$(RETE_PYTHON=python-inesistente bash "${SELF}" 2>&1)"
  rc=$?
  if (( rc == 2 )) && [[ "${out}" == *"interprete non trovato"* ]]; then
    pass "interprete mancante: la suite esce con rc=2"
  else
    fail "interprete mancante: rc=${rc}: ${out:0:300}"
  fi
}

# --- le regole dei dati sintetici ----------------------------------------

test_canon_clean() {
  run_gen "${RETE}" --canone
  if (( RC == 0 )) && [[ "${OUT}" == *"file conformi"* ]] &&
    [[ "${OUT}" != *"fuori"* ]]; then
    pass "canone rispettato: ${OUT##*: }"
  else
    fail "canone: rc=${RC}: ${OUT:0:400}"
  fi
}

# Pianta una riga in una copia minima e verifica che --canone la segnali.
canon_case() {
  local name="$1" line="$2" keyword="$3"
  mini_copy "canone-${name}" || { fail "copia non riuscita"; return; }
  printf '%s\n' "${line}" >"${TMP}/canone-${name}/piantato.cfg"
  run_gen "${TMP}/canone-${name}" --canone
  if (( RC == 1 )) && [[ "${OUT}" == *"${keyword}"* ]] &&
    [[ "${OUT}" == *"piantato.cfg:1"* ]]; then
    pass "canone: ${name} segnalato (rc=1)"
  else
    fail "canone: ${name} non segnalato: rc=${RC}: ${OUT:0:300}"
  fi
}

test_canon_negatives() {
  local -a planted
  planted[0]='host 8.8.8.8'  # canon:ok -- planted negative
  planted[1]='ipv6 2001:4860::1'  # canon:ok -- planted negative
  planted[2]='mac 00:1a:2b:3c:4d:5e'  # canon:ok -- planted negative
  planted[3]='contact noc@esempio.it'  # canon:ok -- planted negative
  planted[4]='ntp server ntp.esempio.com'
  planted[5]='neighbor 203.0.113.9 remote-as 3269'
  canon_case ipv4 "${planted[0]}" 'IPv4 fuori'
  canon_case ipv6 "${planted[1]}" 'IPv6 fuori'
  canon_case mac "${planted[2]}" 'MAC fuori'
  canon_case email "${planted[3]}" 'e-mail'
  canon_case host "${planted[4]}" 'nome di host fuori'
  canon_case asn "${planted[5]}" 'numero AS fuori'
}

test_canon_no_false_positive() {
  local file="${TMP}/canone-valido/valido.cfg"
  mini_copy canone-valido || { fail "copia non riuscita"; return; }
  {
    echo " ip address 192.0.2.4 255.255.255.192"
    echo "access-list 10 permit 192.0.2.0 0.0.0.63"
    echo "version 17.9.4a at 10:12:31 build 2210.139871022552832"
    echo "mac 00:00:5e:00:53:2a 0000.5e00.532a"
    echo "ipv6 address 2001:db8:c1a5::1/64 route ::/0"
    echo "peer-as 64496; AS64500; noc@ciaspolink.example.org"
    echo "sip:201@cl000103.pbx.ciaspolink.example.org"
    echo "mysql://db:secret@pbx-trento-01.ciaspolink.example.org/db"
  } >"${file}"
  run_gen "${TMP}/canone-valido" --canone
  if (( RC == 0 )) && [[ "${OUT}" != *"fuori"* ]]; then
    pass "canone: nessun falso positivo su valori ammessi"
  else
    fail "canone: falso positivo: rc=${RC}: ${OUT:0:300}"
  fi
}

# --- verita' di riferimento ed entita' condivise ---------------------------

test_ground_truth() {
  local out rc
  needs_key "verita' di riferimento" || return 0
  out="$("${PY}" -B -I - "${RETE}" "${SEEDED}" <<'PY' 2>&1
import csv, os, re, sys
root, expected = sys.argv[1], int(sys.argv[2])
def rows(name):
    with open(os.path.join(root, name), encoding="utf-8") as handle:
        return list(csv.DictReader(handle))
truth = rows(os.path.join("_docente", "problemi-inseriti.csv"))
devices = [r["apparato"] for r in rows("inventario.csv")]
with open(os.path.join(root, "checklist-audit.md"), encoding="utf-8") as h:
    checklist = h.read()
errors, per_device = [], {}
for row in truth:
    with open(os.path.join(root, row["file"]), encoding="utf-8") as h:
        lines = h.read().split("\n")
    number = int(row["riga"])
    if not 1 <= number <= len(lines) or \
            lines[number - 1].strip() != row["estratto"]:
        errors.append("%s: la riga %s non e' l'estratto" % (row["id"],
                                                           number))
    if not re.match(r"^AUD-(0[1-9]|1[0-6])$", row["categoria"]) or \
            "### %s " % row["categoria"] not in checklist:
        errors.append("%s: categoria %s" % (row["id"], row["categoria"]))
    if row["gravita"] not in ("alta", "media", "bassa"):
        errors.append("%s: gravita %s" % (row["id"], row["gravita"]))
    if row["apparato"] not in devices:
        errors.append("%s: apparato %s" % (row["id"], row["apparato"]))
    per_device[row["apparato"]] = per_device.get(row["apparato"], 0) + 1
for device in devices:
    if not 1 <= per_device.get(device, 0) <= 4:
        errors.append("%s: %d problemi" % (device,
                                           per_device.get(device, 0)))
if len(truth) != expected:
    errors.append("righe: %d invece di %d" % (len(truth), expected))
print("\n".join(errors) if errors else "righe risolte: %d" % len(truth))
sys.exit(1 if errors else 0)
PY
)"
  rc=$?
  if (( rc == 0 )) && [[ "${out}" == "righe risolte: ${SEEDED}" ]]; then
    pass "verita' di riferimento: ${out}"
  else
    fail "verita' di riferimento rc=${rc}: ${out:0:400}"
  fi
}

test_shared_entities() {
  local out rc
  out="$("${PY}" -B -I - "${RETE}" <<'PY' 2>&1
import csv, json, os, sys
root = sys.argv[1]
expected = {"bng-trento-01": ("192.0.2.1", ""),
            "olt-trento-01": ("192.0.2.11", "bng-trento-01"),
            "olt-pergine-01": ("192.0.2.12", "bng-trento-01"),
            "olt-rovereto-01": ("192.0.2.13", "bng-trento-01"),
            "ptp-cles-01": ("192.0.2.21", "bng-trento-01"),
            "bts-cles-01": ("192.0.2.22", "ptp-cles-01"),
            "sbc-trento-01": ("192.0.2.31", "")}
errors = []
with open(os.path.join(root, "inventario.csv"), encoding="utf-8") as h:
    inventory = {r["apparato"]: r for r in csv.DictReader(h)}
for name in sorted(expected):
    row = inventory.get(name)
    if row is None or (row["ip_gestione"], row["uplink"]) != expected[name]:
        errors.append("inventario: %s" % name)
path = os.path.join(root, "configurazioni", "dhcp-trento-01",
                    "kea-dhcp4.conf")
with open(path, encoding="utf-8") as h:
    kea = json.load(h)
statics = {r["hw-address"]: r["ip-address"]
           for s in kea["Dhcp4"]["subnet4"] if s["id"] == 300
           for r in s["reservations"]}
if statics != {"00:00:5e:00:53:02": "203.0.113.2",
               "00:00:5e:00:53:03": "203.0.113.3",
               "00:00:5e:00:53:05": "203.0.113.5"}:
    errors.append("kea: indirizzi statici %s" % statics)
with open(os.path.join(root, "configurazioni", "olt-pergine-01.cfg"),
          encoding="utf-8") as h:
    olt = h.read().split("\n")
pon3 = [l for l in olt if l.startswith("  ont add 3 ")]
if len(pon3) != 40 or not any('desc "LN-000201"' in l for l in pon3):
    errors.append("olt-pergine-01: %d ONT sulla porta 0/1/3" % len(pon3))
print("\n".join(errors) if errors else "entita' condivise coerenti")
sys.exit(1 if errors else 0)
PY
)"
  rc=$?
  if (( rc == 0 )) && [[ "${out}" == "entita' condivise coerenti" ]]; then
    pass "${out} con il gestionale"
  else
    fail "entita' condivise rc=${rc}: ${out:0:400}"
  fi
  if command grep -q "ln000201@ciaspolink.example.org logged in, .* from \
00:00:5E:00:53:01" "${RETE}"/log/pppoe/*.log; then
    pass "LN-000201 in PPPoE con il MAC del gestionale"
  else
    fail "LN-000201 assente dal log PPPoE con il suo MAC"
  fi
}

# --- gli avvenimenti della settimana ---------------------------------------

# Verifica che count_window rientri fra un minimo e un massimo.
expect_window() {
  local label="$1" min="$2" max="$3" n
  shift 3
  n="$(count_window "$@")"
  if (( n >= min && n <= max )); then
    pass "${label}: ${n}"
  else
    fail "${label}: ${n} righe (attese ${min}-${max})"
  fi
}

test_incidents() {
  local log="${RETE}/log" alarms="${RETE}/allarmi.csv" n
  expect_window "mar 10:12 ONT offline per LOS sulla 0/1/3" 40 40 \
    "${log}/syslog/syslog_2026-09-08.log" 2026-09-08T10:12 \
    2026-09-08T10:13 "olt-pergine-01 .*slot 1 port 3 .*cause LOS"
  expect_window "mar 10:12 LN-000201 perde la sessione" 1 1 \
    "${log}/pppoe/bng-trento-01_2026-09-08.log" 2026-09-08T10:12 \
    2026-09-08T10:14 "ln000201@.*peer is not responding"
  expect_window "mar 11:40 segnale della PON ripristinato" 1 1 \
    "${log}/syslog/syslog_2026-09-08.log" 2026-09-08T11:40 \
    2026-09-08T11:41 "olt-pergine-01 .*PON_LOS_CLEAR"
  expect_window "mer episodi sul ponte radio visti da Trento" 9 9 \
    "${log}/syslog/syslog_2026-09-09.log" 2026-09-09T09:41 \
    2026-09-09T17:20 "ptp-trento-01 wireless: .* lost"
  expect_window "mer LN-000204 cade piu' volte" 5 20 \
    "${log}/pppoe/bng-trento-01_2026-09-09.log" 2026-09-09T09:41 \
    2026-09-09T17:30 "ln000204@.*peer is not responding"
  expect_window "gio 02:0x riavvio del BNG" 1 1 \
    "${log}/syslog/syslog_2026-09-10.log" 2026-09-10T02:00 \
    2026-09-10T02:30 "bng-trento-01 .*router rebooted"
  expect_window "gio 02:07-02:30 riconnessioni PPPoE" 100 200 \
    "${log}/pppoe/bng-trento-01_2026-09-10.log" 2026-09-10T02:07 \
    2026-09-10T02:30 ": connected"
  expect_window "gio Accounting-On dal BNG" 1 1 \
    "${log}/radius/accounting_2026-09-10.log" 2026-09-10T02:00 \
    2026-09-10T02:30 "Acct-Status-Type=Accounting-On"
  expect_window "ven 07:5x modifica del dispatcher dell'SBC" 1 1 \
    "${log}/sip/sbc-trento-01_2026-09-11.log" 2026-09-11T07:50 \
    2026-09-11T08:00 "loaded destination sip:192.0.2.32:5070"
  expect_window "ven registrazioni di CL-000103 respinte" 6 1000 \
    "${log}/sip/sbc-trento-01_2026-09-11.log" 2026-09-11T07:53 \
    2026-09-11T10:06 "from sip:cl000103-20.*-> 503"
  expect_window "ven registrazioni di CL-000103 di nuovo accettate" 6 100 \
    "${log}/sip/sbc-trento-01_2026-09-11.log" 2026-09-11T10:05 \
    2026-09-11T11:00 "from sip:cl000103-20.*-> 200 OK"
  expect_window "ven nessun 503 prima della modifica" 0 0 \
    "${log}/sip/sbc-trento-01_2026-09-11.log" 2026-09-11T00:00 \
    2026-09-11T07:52 "-> 503"
  expect_window "sab pool della VLAN 312 esaurito" 10 2000 \
    "${log}/dhcp/kea-dhcp4_2026-09-12.log" 2026-09-12T09:28 \
    2026-09-13T00:00 "ALLOC_FAIL_SUBNET .*subnet 198.51.100.192/27"
  expect_window "sab nessun rifiuto DHCP prima delle 09:10" 0 0 \
    "${log}/dhcp/kea-dhcp4_2026-09-12.log" 2026-09-12T00:00 \
    2026-09-12T09:10 "ALLOC_FAIL"
  n="$(cat "${log}"/dhcp/kea-dhcp4_2026-09-0[7-9].log \
    "${log}"/dhcp/kea-dhcp4_2026-09-1[01].log | command grep -c ALLOC_FAIL)"
  if (( n == 0 )); then
    pass "nessun rifiuto DHCP da lunedi' a venerdi'"
  else
    fail "${n} rifiuti DHCP prima di sabato"
  fi
  n="$(command grep -c "^2026-09-12T.*,dhcp-trento-01,CRITICAL,pool-dhcp,.*\
pool esaurito" "${alarms}")"
  if (( n == 1 )); then
    pass "allarme di pool esaurito sabato"
  else
    fail "allarmi di pool esaurito sabato: ${n}"
  fi
}

test_volume_and_cache() {
  local total
  total="$(cat "${RETE}"/log/*/*.log | wc -l)"
  if (( total >= MIN_LOG_LINES && total <= MAX_LOG_LINES )); then
    pass "righe di log: ${total}"
  else
    fail "righe di log: ${total} (attese ${MIN_LOG_LINES}-${MAX_LOG_LINES})"
  fi
  if [[ -z "$(command find "${RETE}" -name __pycache__ -print)" ]]; then
    pass "nessuna cache di Python lasciata nel progetto"
  else
    fail "cache di Python nel progetto"
  fi
}

main() {
  if ! command -v "${PY}" >/dev/null 2>&1; then
    err "interprete non trovato: ${PY}"
    exit 2
  fi
  if ! "${PY}" -c 'import sys; sys.exit(sys.version_info < (3, 8))'; then
    err "serve Python 3.8 o successivo"
    exit 2
  fi
  if [[ ! -r "${RETE}/genera.py" ]]; then
    err "generatore non leggibile: ${RETE}/genera.py"
    exit 2
  fi
  TMP="$(mktemp -d)" || { err "mktemp non riuscito"; exit 2; }
  trap cleanup EXIT
  detect_key_mode
  echo "progetti/rete"
  test_check_clean
  test_check_detects_changes
  test_student_copy
  test_versions
  test_fail_closed
  test_write_mode
  test_suite_preconditions
  test_canon_clean
  test_canon_negatives
  test_canon_no_false_positive
  test_ground_truth
  test_shared_entities
  test_incidents
  test_volume_and_cache
  echo "PASS=${PASS} FAIL=${FAIL} SKIP=${SKIP}"
  if (( FAIL > 0 )); then
    exit 1
  fi
}

main "$@"
