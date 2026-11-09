#!/bin/bash
#
# blocca_prompt.sh -- un hook UserPromptSubmit di M7-D09: se il prompt contiene
# un codice fiscale, lo ferma prima che arrivi a Claude. Claude Code passa il
# prompt su STDIN, in un JSON; il motivo del blocco va su STDERR. Riconosce il
# codice scritto tutto maiuscolo e senza spazi, come nei dati di prova: uno in
# minuscolo o con spazi passa.
#
# Uscita: 2 = il prompt è bloccato · 0 = il prompt passa
set -euo pipefail

readonly CODICE_FISCALE='[A-Z]{6}[0-9]{2}[A-Z][0-9]{2}[A-Z][0-9]{3}[A-Z]'

main() {
  local dati
  dati="$(cat)"
  if [[ "${dati}" =~ ${CODICE_FISCALE} ]]; then
    echo "Prompt bloccato: contiene un codice fiscale." >&2
    exit 2
  fi
}

main "$@"
