#!/bin/bash
#
# blocca_accredito.sh -- un hook PreToolUse di M7-D09: ferma ogni chiamata allo
# strumento che registra gli accrediti, prima che arrivi al server. Il matcher
# in settings.json lo fa scattare solo su quello strumento; Claude Code passa
# la chiamata su STDIN, in un JSON, e il motivo del blocco va su STDERR.
#
# Uscita: 2 sempre: per Claude Code è il blocco della chiamata
set -euo pipefail

cat > /dev/null
echo "Accredito bloccato: serve l'approvazione di un responsabile." >&2
exit 2
