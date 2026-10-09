#!/bin/bash
#
# esporta_studenti.sh -- la copia del repository per i partecipanti: git
# archive di HEAD, che onora le regole export-ignore di .gitattributes
# (fuori ogni soluzione/ e ogni _docente/, anche progetti/*/_docente/),
# estratta in una cartella nuova che diventa un repository git con un solo
# commit, e accanto un bundle, <cartella>.bundle, da consegnare: si clona
# con `git clone <cartella>.bundle <destinazione>`.
#
# Esporta sempre HEAD. Le modifiche non ancora committate NON entrano nella
# copia: lo strumento le elenca su STDERR e prosegue (scelta: un avviso e
# non un rifiuto, per poter provare l'esportazione durante il lavoro; chi
# consegna committa prima).
# Il commit della copia ha la data del commit di HEAD, quindi la stessa
# HEAD dà lo stesso commit. Nella copia c'è il file segno
# .copia_partecipanti: check_handson.sh e run_all.sh vi sanno che
# soluzione/ e _docente/ mancano di proposito. Gli alberi di prova di
# tests/fixtures/ restano nella copia con le loro soluzione/ e _docente/
# finte, così anche lì i test girano.
# Prima del commit la copia viene controllata: se vi resta una soluzione/
# o una _docente/ fuori da tests/fixtures/, lo strumento si ferma con 1 e
# non crea il bundle.
#
# Uso:    tools/esporta_studenti.sh <cartella>
#           <cartella>  nuova o vuota, fuori da questo repository; anche
#                       <cartella>.bundle non deve esistere
# Env:    PN_HANDSON_ROOT  il repository da esportare (default: la
#                          cartella sopra tools/)
# Uscita: 0 = copia e bundle pronti
#         1 = la copia contiene ancora soluzione/ o _docente/: le regole di
#             .gitattributes non bastano, non va consegnata
#         2 = precondizione: argomenti, repository senza commit o non
#             radice di un repository git, cartella non vuota, bundle già
#             presente, git o tar mancanti
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
# shellcheck source=lib_handson.sh
source "${SELF%/*}/lib_handson.sh"

DEST=''
BUNDLE=''

usage() { printf 'Uso: tools/esporta_studenti.sh <cartella>\n'; }

# La destinazione: assoluta, canonica, fuori dal repository, nuova o vuota;
# il bundle accanto non deve esistere.
# Globals: DEST, BUNDLE (assegnate). Arguments: $1 la cartella data.
resolve_dest() {
  local d="$1" genitore nome contenuto
  while [[ "${d}" == */ && "${d}" != "/" ]]; do d="${d%/}"; done
  [[ "${d}" == /* ]] || d="${PWD}/${d}"
  genitore="${d%/*}"
  nome="${d##*/}"
  [[ -n "${genitore}" ]] || genitore='/'
  [[ -n "${nome}" && "${nome}" != "." && "${nome}" != ".." ]] \
    || handson::die "cartella di destinazione non valida: $1"
  [[ -d "${genitore}" ]] || handson::die "la cartella ${genitore} non esiste"
  genitore="$(cd "${genitore}" && pwd -P)"
  DEST="${genitore%/}/${nome}"
  BUNDLE="${DEST}.bundle"
  [[ "${DEST}/" != "${HANDSON_ROOT}/"* ]] \
    || handson::die "la copia non va dentro il repository: ${DEST}"
  if [[ -e "${DEST}" || -L "${DEST}" ]]; then
    [[ -d "${DEST}" && ! -L "${DEST}" ]] \
      || handson::die "${DEST} esiste e non è una cartella"
    contenuto="$(ls -A -- "${DEST}")" || handson::die "non leggo ${DEST}"
    [[ -z "${contenuto}" ]] || handson::die "${DEST} non è vuota"
  fi
  [[ ! -e "${BUNDLE}" && ! -L "${BUNDLE}" ]] \
    || handson::die "il bundle esiste già: ${BUNDLE}"
}

# Il repository da esportare: radice di un repository git, con un commit.
check_repo() {
  local cima
  cima="$(git -C "${HANDSON_ROOT}" rev-parse --show-toplevel 2>/dev/null)" \
    || handson::die "${HANDSON_ROOT} non è un repository git"
  [[ "$(cd "${cima}" && pwd -P)" == "${HANDSON_ROOT}" ]] \
    || handson::die "${HANDSON_ROOT} non è la radice del suo repository git"
  git -C "${HANDSON_ROOT}" rev-parse -q --verify HEAD >/dev/null \
    || handson::die "il repository non ha ancora nessun commit"
}

# Avvisa, su STDERR, delle modifiche non committate (al più 20 righe).
warn_uncommitted() {
  local stato riga n=0
  stato="$(git -C "${HANDSON_ROOT}" status --porcelain)" \
    || handson::die "git status non riesce"
  [[ -n "${stato}" ]] || return 0
  handson::err "ATTENZIONE: modifiche non committate; la copia contiene" \
    "HEAD, senza di loro:"
  while IFS= read -r riga; do
    n=$((n + 1))
    if (( n <= 20 )); then handson::err "    ${riga}"; fi
  done <<< "${stato}"
  if (( n > 20 )); then handson::err "    … e altre $((n - 20))"; fi
}

# Il repository git della copia, con un solo commit, e il suo bundle.
# Arguments: $1 il commit di origine, $2 la sua data.
commit_and_bundle() {
  git -c init.defaultBranch=master -C "${DEST}" init -q \
    && git -C "${DEST}" symbolic-ref HEAD refs/heads/master \
    && git -C "${DEST}" add -A \
    && GIT_AUTHOR_DATE="$2" GIT_COMMITTER_DATE="$2" git -C "${DEST}" \
      -c user.name="${HANDSON_GIT_NAME}" -c user.email="${HANDSON_GIT_EMAIL}" \
      -c commit.gpgsign=false commit -q --no-verify \
      -m "Esercitazioni per i partecipanti (dal commit $1)" \
    && git -C "${DEST}" bundle create "${BUNDLE}" --all \
    && git -C "${DEST}" bundle verify "${BUNDLE}"
}

main() {
  if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then usage; exit 0; fi
  if (( $# != 1 )) || [[ "$1" == -* ]]; then usage >&2; exit 2; fi
  handson::need_tools git tar
  handson::init_root || exit 2
  check_repo
  resolve_dest "$1"
  warn_uncommitted
  local origine data rimaste errori d
  origine="$(git -C "${HANDSON_ROOT}" rev-parse --short HEAD)"
  data="$(git -C "${HANDSON_ROOT}" log -1 --format=%cI HEAD)"
  mkdir -p -- "${DEST}"
  git -C "${HANDSON_ROOT}" archive --format=tar HEAD | tar -xf - -C "${DEST}" \
    || handson::die "git archive o tar non riescono"
  handson::tmpfile rimaste
  handson::trainer_dirs "${DEST}" "${rimaste}" \
    || handson::die "non riesco a controllare la copia"
  if [[ -s "${rimaste}" ]]; then
    handson::err "la copia contiene ancora materiale del docente (non va" \
      "consegnata; controlla .gitattributes):"
    while IFS= read -r d; do handson::err "    ${d}/"; done < "${rimaste}"
    exit 1
  fi
  printf '%s\n' "Copia del repository delle esercitazioni per i" \
    "partecipanti, esportata da tools/esporta_studenti.sh dal commit" \
    "${origine} (${data}). Non contiene le soluzioni (soluzione/) né il" \
    "materiale del docente (_docente/); gli strumenti di tools/ lo sanno" \
    "da questo file." > "${DEST}/${HANDSON_EXPORT_MARK}"
  handson::tmpfile errori
  if ! commit_and_bundle "${origine}" "${data}" > "${errori}" 2>&1; then
    cat "${errori}" >&2
    handson::die "git non riesce a creare il repository o il bundle"
  fi
  printf 'Copia per i partecipanti pronta: %s (commit %s, da %s)\n' \
    "${DEST}" "$(git -C "${DEST}" rev-parse --short HEAD)" "${origine}"
  printf 'Bundle: %s\n  si clona con: git clone %s esercitazioni\n' \
    "${BUNDLE}" "${BUNDLE}"
}

main "$@"
