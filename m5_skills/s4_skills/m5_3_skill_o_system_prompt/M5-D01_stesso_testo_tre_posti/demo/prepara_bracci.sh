#!/bin/bash
#
# prepara_bracci.sh -- i quattro bracci di M5-D01 in <cartella>: lo stesso
# testo (testo.md, accanto a questo file) in tre posti e da nessuna parte.
#   skill/      .claude/skills/procedure-assistenza/SKILL.md, con name,
#               description e il testo come corpo
#   claude_md/  CLAUDE.md, il testo
#   append/     testo.md, che claude riceve con --append-system-prompt-file
#   niente/     nessun file
# Ogni braccio è un repository git a sé, con un solo commit e lo stesso
# messaggio: le cartelle differiscono soltanto nel posto del testo.
#
# Uso:    bash prepara_bracci.sh <cartella>
#           <cartella>/skill e gli altri non devono esserci già
# Uscita: 0 = bracci pronti · 2 = precondizione (argomenti, testo.md che
#         manca, un braccio che c'è già, git che manca o non riesce)
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly TESTO="${SELF%/*}/testo.md"
readonly NOME_SKILL=procedure-assistenza
DESCRIZIONE="Riporta le procedure dell'assistenza clienti di CiaspoLink"
DESCRIZIONE+=' su connessione lenta, speed test, Wi-Fi di casa, sistemi mesh,'
DESCRIZIONE+=' antenna radio e maltempo. Da usare quando si assiste un cliente'
DESCRIZIONE+=' che va piano, che ha il Wi-Fi debole o che ha problemi con'
DESCRIZIONE+=" l'antenna."
readonly DESCRIZIONE
readonly NOME_GIT='Corso Claude Code'
readonly EMAIL_GIT='corso@example.org'
readonly BRACCI=(skill claude_md append niente)

err() { echo "prepara_bracci.sh: $*" >&2; }
die() { err "$@"; exit 2; }

#######################################
# Un repository git con un commit, anche senza file.
# Arguments: $1 la cartella del braccio.
#######################################
commit_iniziale() {
  if ! git -c init.defaultBranch=main -C "$1" init -q \
      || ! git -C "$1" add -A \
      || ! git -C "$1" -c user.name="${NOME_GIT}" \
        -c user.email="${EMAIL_GIT}" -c commit.gpgsign=false \
        commit -q --no-verify --allow-empty -m "Punto di partenza del braccio"
  then
    die "git non riesce a fare il repository del braccio: $1"
  fi
}

#######################################
# Lo SKILL.md del braccio della skill: il frontmatter, poi il testo.
# Arguments: $1 la cartella del braccio.
#######################################
scrivi_skill() {
  local dir="$1/.claude/skills/${NOME_SKILL}"
  mkdir -p -- "${dir}" || die "non riesco a creare ${dir}"
  {
    printf -- '---\nname: %s\ndescription: %s\n---\n\n' "${NOME_SKILL}" \
      "${DESCRIZIONE}"
    cat -- "${TESTO}"
  } > "${dir}/SKILL.md" || die "non riesco a scrivere ${dir}/SKILL.md"
}

main() {
  if (( $# != 1 )) || [[ -z "$1" ]]; then
    die "uso: bash prepara_bracci.sh <cartella>"
  fi
  local cartella="${1%/}" braccio
  command -v git > /dev/null 2>&1 || die "manca git"
  [[ -f "${TESTO}" && -r "${TESTO}" ]] || die "manca ${TESTO}"
  for braccio in "${BRACCI[@]}"; do
    [[ ! -e "${cartella}/${braccio}" ]] \
      || die "il braccio c'è già: ${cartella}/${braccio}"
  done
  for braccio in "${BRACCI[@]}"; do
    mkdir -p -- "${cartella}/${braccio}" \
      || die "non riesco a creare ${cartella}/${braccio}"
  done
  scrivi_skill "${cartella}/skill"
  cp -- "${TESTO}" "${cartella}/claude_md/CLAUDE.md" \
    || die "non riesco a copiare il testo nel braccio claude_md"
  cp -- "${TESTO}" "${cartella}/append/testo.md" \
    || die "non riesco a copiare il testo nel braccio append"
  for braccio in "${BRACCI[@]}"; do
    commit_iniziale "${cartella}/${braccio}"
  done
  echo "I quattro bracci in ${cartella}/: ${BRACCI[*]}"
}

main "$@"
