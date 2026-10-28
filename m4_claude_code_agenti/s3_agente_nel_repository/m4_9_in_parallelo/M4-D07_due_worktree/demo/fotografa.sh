#!/bin/bash
#
# fotografa.sh -- la fotografia di git dopo un braccio di M4-D07, da
# prendere subito, prima di ogni pulizia: il controllo decide da questa e
# dagli stream, e si può rifare anche dopo aver tolto i worktree. Scrive
# in esecuzioni/<braccio>/:
#   checkout.txt      git status --porcelain del checkout principale;
#   senza-worktree:   urgenza.py, la copia di progetti/urgenze/urgenza.py;
#   con-worktree:     <nome>.status, git status --porcelain --branch di
#                     .claude/worktrees/<nome> (vuoto se il worktree non
#                     c'è), e <nome>.py, la copia del suo urgenza.py, per
#                     esempio e rinomina.
#
# Uso:    bash fotografa.sh senza-worktree|con-worktree
#           dalla cartella dello spazio di lavoro, la cima del repository
# Uscita: 0 = fotografia fatta (un worktree che manca è registrato come
#         assente) · 2 = precondizione (argomento, non dalla cima di un
#         repository git, la cartella del braccio che manca, git che non
#         riesce, un file che manca)
set -euo pipefail

readonly FILE=progetti/urgenze/urgenza.py
readonly NOMI=(esempio rinomina)

err() { echo "fotografa.sh: $*" >&2; }
die() { err "$@"; exit 2; }

#######################################
# Lo stato di un worktree e la copia del suo urgenza.py; un file di stato
# vuoto se il worktree non c'è.
# Arguments: $1 la cartella del braccio, $2 il nome della sessione.
#######################################
fotografa_worktree() {
  local wt=".claude/worktrees/$2"
  if [[ ! -d "${wt}" ]]; then
    err "il worktree ${wt} non c'è: lo registro come assente"
    : > "$1/$2.status"
    return 0
  fi
  git -C "${wt}" status --porcelain --branch > "$1/$2.status" \
    || die "git status non riesce in ${wt}"
  cp -- "${wt}/${FILE}" "$1/$2.py" || die "manca ${wt}/${FILE}"
}

main() {
  local braccio="${1:-}" dir n cima
  if (( $# != 1 )) || [[ "${braccio}" != senza-worktree \
      && "${braccio}" != con-worktree ]]; then
    die "uso: bash fotografa.sh senza-worktree|con-worktree"
  fi
  command -v git > /dev/null 2>&1 || die "manca git"
  cima="$(git rev-parse --show-toplevel 2> /dev/null)" || cima=''
  [[ -n "${cima}" && "${cima}" == "$(pwd -P)" ]] \
    || die "lanciatelo dalla cartella dello spazio di lavoro, la cima del" \
      "repository git"
  dir="esecuzioni/${braccio}"
  [[ -d "${dir}" ]] || die "manca ${dir}/: prima le due sessioni del braccio"
  git status --porcelain > "${dir}/checkout.txt" \
    || die "git status non riesce nel checkout principale"
  if [[ "${braccio}" == senza-worktree ]]; then
    cp -- "${FILE}" "${dir}/urgenza.py" || die "manca ${FILE}"
  else
    for n in "${NOMI[@]}"; do
      fotografa_worktree "${dir}" "${n}"
    done
  fi
  echo "Fotografia di ${braccio} in ${dir}/"
}

main "$@"
