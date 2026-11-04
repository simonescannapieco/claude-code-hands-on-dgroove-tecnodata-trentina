#!/bin/bash
#
# impacchetta.sh di M5-D05 -- i tre ZIP da caricare su claude.ai, dalla skill di
# esempio del repository: risposta-assistenza.zip, senza evals/;
# risposta-assistenza-settimo-campo.zip, la stessa skill con argument-hint nel
# frontmatter; risposta-assistenza-tag-xml.zip, la stessa skill con la
# description fra due tag XML. Li costruisce impacchetta.py, qui accanto, con
# Python: lo zip di sistema non serve.
#
# Uso:    ./impacchetta.sh <cartella>   la crea se non c'è
# Env:    PN_HANDSON_ROOT  il repository (la cartella delle esercitazioni):
#                          obbligatoria, qui lo script è fuori dal repository
# Uscita: 0 = i tre ZIP · 2 = precondizione (argomenti, PN_HANDSON_ROOT,
#         python3, la cartella, la skill di esempio)
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly SKILL_REL=riferimenti/skill-di-esempio/risposta-assistenza

err() { echo "impacchetta.sh: $*" >&2; }

main() {
  local cartella="${1:-}" sorgente
  if (( $# != 1 )) || [[ -z "${cartella}" ]]; then
    echo "Uso: ./impacchetta.sh <cartella>" >&2
    exit 2
  fi
  command -v python3 > /dev/null 2>&1 || { err "manca python3"; exit 2; }
  sorgente="${PN_HANDSON_ROOT:-}/${SKILL_REL}"
  if [[ -z "${PN_HANDSON_ROOT:-}" || ! -f "${sorgente}/SKILL.md" ]]; then
    err "PN_HANDSON_ROOT deve essere la cartella delle esercitazioni:" \
      "export PN_HANDSON_ROOT=<la cartella>"
    exit 2
  fi
  if [[ -e "${cartella}" && ! -d "${cartella}" ]]; then
    err "non è una cartella: ${cartella}"
    exit 2
  fi
  python3 -B -I "${SELF%/*}/impacchetta.py" "${sorgente}" "${cartella}"
}

main "$@"
