#!/bin/bash
#
# applica.sh di M6-E01 -- la soluzione: il CLAUDE.md di due righe, scritto con
# lo stesso printf del README, poi i file della registrazione del corso,
# copiati così come sono: prima.md, dopo.md, risposta.txt e il registro
# dell'hook, .claude/caricamenti.jsonl. CLAUDE.md non sta in soluzione/: un
# CLAUDE.md in una sottocartella di questo repository si caricherebbe nelle
# sessioni di Claude Code che vi leggono un file. Lo si scrive prima di
# copiare dopo.md, come nei passi del README. tools/run_all.sh la applica.
#
# Uso:    soluzione/applica.sh <spazio di lavoro>
# Uscita: 0 = i file sono nello spazio di lavoro · 2 = precondizione (spazio
#         di lavoro assente, un file della registrazione che manca)
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly SOLUZIONE="${SELF%/*}"
readonly RIGA_1='# Gestionale di CiaspoLink'
# shellcheck disable=SC2016  # gli apici inversi sono il testo di CLAUDE.md
RIGA_2='- Test, da progetti/gestionale-php: `../../tools/php.sh composer'
# shellcheck disable=SC2016  # gli apici inversi sono il testo di CLAUDE.md
RIGA_2+=' install`, poi `../../tools/php.sh phpunit`'
readonly RIGA_2
readonly REGISTRATI=(prima.md dopo.md risposta.txt .claude/caricamenti.jsonl)

main() {
  local ws="${1:-}" f
  if [[ -z "${ws}" || ! -d "${ws}" ]]; then
    echo "applica: spazio di lavoro assente: ${ws}" >&2
    exit 2
  fi
  for f in "${REGISTRATI[@]}"; do
    if [[ ! -f "${SOLUZIONE}/${f}" ]]; then
      echo "applica: manca soluzione/${f}: la registrazione del corso non" \
        "c'è ancora" >&2
      exit 2
    fi
  done
  printf '%s\n' "${RIGA_1}" "${RIGA_2}" > "${ws}/CLAUDE.md"
  mkdir -p -- "${ws}/.claude"
  for f in "${REGISTRATI[@]}"; do
    cp -- "${SOLUZIONE}/${f}" "${ws}/${f}"
  done
}

main "$@"
