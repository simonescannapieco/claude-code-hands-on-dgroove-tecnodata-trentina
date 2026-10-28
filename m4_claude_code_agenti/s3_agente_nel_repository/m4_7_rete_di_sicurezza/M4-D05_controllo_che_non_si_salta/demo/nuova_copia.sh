#!/bin/bash
#
# nuova_copia.sh -- una copia nuova del progetto delle urgenze per
# un'esecuzione: <cartella>/urgenze/, con i file di progetti/urgenze/
# dello spazio di lavoro, le impostazioni di Claude Code in
# .claude/settings.json (quelle date, oppure quelle dello spazio di
# lavoro) e un repository git a sé, con un solo commit. Claude lavora
# nella copia, partendo dalla sua cartella; il progetto dello spazio di
# lavoro resta com'era, pronto per la copia successiva.
#
# Uso:    bash nuova_copia.sh <cartella> [<impostazioni.json>]
#           dalla cartella dello spazio di lavoro; <cartella>/urgenze/ non
#           deve esserci già
# Uscita: 0 = copia pronta · 2 = precondizione (argomenti, il progetto o
#         le impostazioni che mancano, una copia che c'è già, git che manca
#         o non riesce)
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly SPAZIO="${SELF%/*}"
readonly PROGETTO="${SPAZIO}/progetti/urgenze"
readonly NOME_GIT='Corso Claude Code'
readonly EMAIL_GIT='corso@example.org'

err() { echo "nuova_copia.sh: $*" >&2; }
die() { err "$@"; exit 2; }

#######################################
# Copia i file del progetto (soltanto i file, non le sottocartelle come
# __pycache__/) nella copia.
# Arguments: $1 la cartella della copia.
#######################################
copia_file() {
  local f
  for f in "${PROGETTO}"/*; do
    if [[ -f "${f}" ]]; then
      cp -p -- "${f}" "$1/" || die "non riesco a copiare ${f}"
    fi
  done
}

#######################################
# Fa della copia un repository git con un commit.
# Arguments: $1 la cartella della copia.
#######################################
commit_iniziale() {
  if ! git -c init.defaultBranch=main -C "$1" init -q \
      || ! git -C "$1" add -A \
      || ! git -C "$1" -c user.name="${NOME_GIT}" \
        -c user.email="${EMAIL_GIT}" -c commit.gpgsign=false \
        commit -q --no-verify -m "Punto di partenza della copia"; then
    die "git non riesce a fare il repository della copia: $1"
  fi
}

main() {
  if (( $# < 1 || $# > 2 )) || [[ -z "$1" ]]; then
    die "uso: bash nuova_copia.sh <cartella> [<impostazioni.json>]"
  fi
  local impostazioni="${2:-${SPAZIO}/.claude/settings.json}"
  local copia="${1%/}/urgenze"
  command -v git > /dev/null 2>&1 || die "manca git"
  [[ -d "${PROGETTO}" ]] || die "manca il progetto: ${PROGETTO}"
  [[ -f "${impostazioni}" && -r "${impostazioni}" ]] \
    || die "mancano le impostazioni: ${impostazioni}"
  [[ ! -e "${copia}" ]] || die "la copia c'è già: ${copia}"
  mkdir -p -- "${copia}/.claude" || die "non riesco a creare ${copia}"
  copia_file "${copia}"
  cp -- "${impostazioni}" "${copia}/.claude/settings.json" \
    || die "non riesco a copiare le impostazioni in ${copia}"
  commit_iniziale "${copia}"
  echo "Copia pronta: ${copia}"
}

main "$@"
