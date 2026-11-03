#!/bin/bash
#
# applica.sh di M5-E01 -- applica la soluzione di riferimento a uno spazio di
# lavoro: la modifica non committata (prepara_modifica.sh dello spazio di
# lavoro), la skill di riferimento in .claude/skills/riassunto-modifiche/ e, se
# il docente l'ha registrata, la prova in prova/. Non fa commit.
#
# Uso:    soluzione/applica.sh <spazio di lavoro>
# Uscita: 0 = soluzione applicata · 2 = precondizione (spazio di lavoro assente
#         o senza prepara_modifica.sh, una copia che non riesce)
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly SOLUZIONE="${SELF%/*}"
readonly SKILL=.claude/skills/riassunto-modifiche

err() { echo "applica: $*" >&2; }

main() {
  local ws="${1:-}"
  if [[ -z "${ws}" || ! -f "${ws}/prepara_modifica.sh" ]]; then
    err "spazio di lavoro assente o senza prepara_modifica.sh: ${ws}"
    exit 2
  fi
  bash "${ws}/prepara_modifica.sh" || exit 2
  if ! mkdir -p "${ws}/${SKILL}" \
      || ! cp -- "${SOLUZIONE}/${SKILL}/SKILL.md" "${ws}/${SKILL}/"; then
    err "la copia della skill non riesce"
    exit 2
  fi
  if [[ -d "${SOLUZIONE}/prova" ]]; then
    cp -R -- "${SOLUZIONE}/prova" "${ws}/" \
      || { err "la copia della prova non riesce"; exit 2; }
  fi
}

main "$@"
