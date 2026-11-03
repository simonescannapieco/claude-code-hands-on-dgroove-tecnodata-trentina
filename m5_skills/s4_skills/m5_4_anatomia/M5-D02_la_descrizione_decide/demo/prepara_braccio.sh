#!/bin/bash
#
# prepara_braccio.sh -- una cartella nuova per un'esecuzione di M5-D02:
# configurazione.txt, .claude/skills/prova-d02/SKILL.md e un repository git a
# sé, con un solo commit. Il corpo (corpo.md, accanto a questo file) e il nome
# sono gli stessi in ogni braccio; cambia soltanto la parte sotto prova:
#   vaga          description: descrizione_vaga.txt
#   specifica     description: descrizione_specifica.txt
#   near_miss     come specifica: cambia la richiesta, non il file
#   manuale       come specifica, più disable-model-invocation: true
#   manuale_nome  come manuale: cambia la richiesta, con /prova-d02
#
# Uso:    bash prepara_braccio.sh <cartella> <braccio>
#           <cartella> non deve esserci già
# Uscita: 0 = cartella pronta · 2 = precondizione (argomenti, un braccio
#         sconosciuto, un file che manca, una cartella che c'è già, git che
#         manca o non riesce)
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly DEMO="${SELF%/*}"
readonly NOME_SKILL=prova-d02
readonly NOME_GIT='Corso Claude Code'
readonly EMAIL_GIT='corso@example.org'
readonly NECESSARI=(corpo.md configurazione.txt descrizione_vaga.txt
  descrizione_specifica.txt)

err() { echo "prepara_braccio.sh: $*" >&2; }
die() { err "$@"; exit 2; }

#######################################
# Un repository git con un commit.
# Arguments: $1 la cartella.
#######################################
commit_iniziale() {
  if ! git -c init.defaultBranch=main -C "$1" init -q \
      || ! git -C "$1" add -A \
      || ! git -C "$1" -c user.name="${NOME_GIT}" \
        -c user.email="${EMAIL_GIT}" -c commit.gpgsign=false \
        commit -q --no-verify -m "Punto di partenza della prova"; then
    die "git non riesce a fare il repository: $1"
  fi
}

#######################################
# Lo SKILL.md: name, description, il flag se c'è, poi il corpo.
# Arguments: $1 la cartella, $2 il file della description, $3 la riga del flag
#   (vuota se non c'è).
#######################################
scrivi_skill() {
  local dir="$1/.claude/skills/${NOME_SKILL}" descrizione
  descrizione="$(< "$2")"
  mkdir -p -- "${dir}" || die "non riesco a creare ${dir}"
  {
    printf -- '---\nname: %s\ndescription: %s\n' "${NOME_SKILL}" \
      "${descrizione}"
    if [[ -n "$3" ]]; then
      printf '%s\n' "$3"
    fi
    printf -- '---\n\n'
    cat -- "${DEMO}/corpo.md"
  } > "${dir}/SKILL.md" || die "non riesco a scrivere ${dir}/SKILL.md"
}

main() {
  if (( $# != 2 )) || [[ -z "$1" ]]; then
    die "uso: bash prepara_braccio.sh <cartella> <braccio>"
  fi
  local cartella="${1%/}" braccio="$2" f file='' flag=''
  case "${braccio}" in
    vaga) file=descrizione_vaga.txt ;;
    specifica|near_miss) file=descrizione_specifica.txt ;;
    manuale|manuale_nome)
      file=descrizione_specifica.txt
      flag='disable-model-invocation: true' ;;
    *) die "braccio sconosciuto: ${braccio}" ;;
  esac
  command -v git > /dev/null 2>&1 || die "manca git"
  for f in "${NECESSARI[@]}"; do
    [[ -f "${DEMO}/${f}" && -r "${DEMO}/${f}" ]] || die "manca ${DEMO}/${f}"
  done
  [[ ! -e "${cartella}" ]] || die "la cartella c'è già: ${cartella}"
  mkdir -p -- "${cartella}" || die "non riesco a creare ${cartella}"
  cp -- "${DEMO}/configurazione.txt" "${cartella}/" \
    || die "non riesco a copiare configurazione.txt"
  scrivi_skill "${cartella}" "${DEMO}/${file}" "${flag}"
  commit_iniziale "${cartella}"
  echo "Pronta ${cartella}"
}

main "$@"
