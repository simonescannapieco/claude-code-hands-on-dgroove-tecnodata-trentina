#!/bin/bash
#
# esegui_test.sh -- tutte le prove del repository, in due passi:
#   1. ogni tests/test_*.sh presente -- degli strumenti, dei progetti
#      condivisi -- poi ogni suite di modulo, m<N>_*/_docente/test_*.sh
#      (materiale del docente: la copia dei partecipanti non la porta), uno
#      dopo l'altro, con STDIN da /dev/null; una suite senza il bit di
#      esecuzione conta come fallita;
#   2. shellcheck -x su ogni *.sh di tools/, tests/, progetti/ e dei moduli
#      m<N>_*/ che git consegna (non vendor/ né gli altri file ignorati),
#      compresi quelli degli elementi in demo/, esercizio/ e soluzione/,
#      un file per invocazione, con le regole di .shellcheckrc.
# Per ogni suite stampa la sua ultima riga (il suo riepilogo); per una
# suite fallita anche le ultime righe della sua uscita.
# Volutamente autonomo, senza librerie: deve poter dire che cosa non va
# anche quando la libreria degli strumenti è rotta.
#
# Uso:    tests/esegui_test.sh
# Env:    PN_HANDSON_ROOT  il repository (default: la cartella sopra tests/);
#                          alle suite non arriva
# Uscita: 0 = tutte le suite passano e shellcheck non segnala niente
#         1 = almeno una suite fallita o un file con segnalazioni
#         2 = precondizione: shellcheck o git mancanti, nessuna suite,
#             radice che non è un repository git
set -uo pipefail          # raccoglie gli esiti di tutte le suite

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly NL=$'\n'
ROOT=''
N_SUITE=0
N_SUITE_KO=0
N_FILE=0
N_FILE_KO=0
ELENCO=''

err() { echo "esegui_test.sh: $*" >&2; }
die() { err "$@"; exit 2; }

# Rimuove l'elenco temporaneo dei file.
cleanup() {
  if [[ -n "${ELENCO}" && -f "${ELENCO}" ]]; then
    rm -f -- "${ELENCO}"
  fi
}

# Stampa, rientrate, le ultime righe di un testo.
# Arguments: $1 il testo, $2 quante righe.
coda() {
  local riga
  while IFS= read -r riga; do
    printf '      | %s\n' "${riga}"
  done < <(printf '%s\n' "$1" | tail -n "$2")
}

# Il passo 1: le suite; una di tests/ si chiama per nome, una di modulo
# per percorso. Globals: ROOT, N_SUITE, N_SUITE_KO.
run_suites() {
  local s nome out rc ultima
  local -a suite=("${ROOT}/tests/"test_*.sh
    "${ROOT}/"m[1-9]_*/_docente/test_*.sh)
  for s in "${suite[@]}"; do
    [[ -f "${s}" ]] || continue
    N_SUITE=$((N_SUITE + 1))
    nome="${s#"${ROOT}/"}"
    nome="${nome#tests/}"
    if [[ ! -x "${s}" ]]; then
      printf '  KO  %-34s non eseguibile (chmod +x)\n' "${nome}"
      N_SUITE_KO=$((N_SUITE_KO + 1))
      continue
    fi
    out="$(unset PN_HANDSON_ROOT; "${s}" < /dev/null 2>&1)"
    rc=$?
    if (( rc == 0 )); then
      ultima="${out##*"${NL}"}"
      printf '  ok  %-34s %s\n' "${nome}" "${ultima}"
    else
      printf '  KO  %-34s uscita %d\n' "${nome}" "${rc}"
      coda "${out}" 25
      N_SUITE_KO=$((N_SUITE_KO + 1))
    fi
  done
}

# Il passo 2: shellcheck, un file per invocazione.
# Globals: ROOT, ELENCO, N_FILE, N_FILE_KO.
run_shellcheck() {
  local f out
  # m[1-9]_* è un pathspec di git: lì * attraversa anche le /.
  if ! git -C "${ROOT}" ls-files -z --cached --others --exclude-standard \
      -- tools tests progetti 'm[1-9]_*' > "${ELENCO}"; then
    die "git non elenca i file di ${ROOT}: è un repository git?"
  fi
  while IFS= read -r -d '' f; do
    [[ "${f}" == *.sh && -f "${ROOT}/${f}" ]] || continue
    N_FILE=$((N_FILE + 1))
    if ! out="$(cd "${ROOT}" && shellcheck -x -- "${f}" 2>&1)"; then
      printf '  KO  shellcheck %s\n' "${f}"
      coda "${out}" 30
      N_FILE_KO=$((N_FILE_KO + 1))
    fi
  done < "${ELENCO}"
}

main() {
  if (( $# > 0 )); then
    printf 'Uso: tests/esegui_test.sh\n' >&2
    exit 2
  fi
  local t
  for t in git shellcheck; do
    command -v "${t}" >/dev/null 2>&1 || die "manca lo strumento: ${t}"
  done
  ROOT="${PN_HANDSON_ROOT:-${SELF%/tests/*}}"
  [[ -d "${ROOT}/tests" ]] || die "manca la cartella tests/ in ${ROOT}"
  ROOT="$(cd "${ROOT}" && pwd -P)" || die "non entro in ${ROOT}"
  ELENCO="$(mktemp)" || die "mktemp non riesce"
  trap cleanup EXIT
  echo "Suite di test:"
  run_suites
  (( N_SUITE > 0 )) || die "nessuna suite (tests/test_*.sh," \
    "m<N>_*/_docente/test_*.sh) in ${ROOT}"
  echo "shellcheck:"
  run_shellcheck
  local esito=OK
  (( N_SUITE_KO + N_FILE_KO == 0 )) || esito=KO
  printf '\nesegui_test: %d suite, %d KO · shellcheck: %d file, %d con' \
    "${N_SUITE}" "${N_SUITE_KO}" "${N_FILE}" "${N_FILE_KO}"
  printf ' segnalazioni -- ESITO: %s\n' "${esito}"
  (( N_SUITE_KO + N_FILE_KO == 0 )) || exit 1
}

main "$@"
