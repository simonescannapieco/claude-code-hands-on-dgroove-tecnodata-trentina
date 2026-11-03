#!/bin/bash
#
# live.sh di M5-D01 -- la prova del docente: lo stesso testo in tre posti, tre
# esecuzioni, cioè diciotto chiamate di claude -p. È demo/in_classe.sh
# dell'elemento, che ne fa una: i comandi, i bracci, gli stream e il controllo
# sono gli stessi, e l'intestazione di quel file li dice. Gli stream restano in
# <spazio>.prova_dal_vivo, fuori dallo spazio di lavoro, e una copia va in
# risposte/, da cui legge verifica.sh.
#
# Uso:    _docente/live.sh <spazio di lavoro>
#           lo spazio di lavoro appena preparato (tools/prepara_esercizio.sh
#           M5-D01), con git status pulito
# Env:    PN_ESECUZIONI  quante esecuzioni, da 1 a 9 (default 3)
#         le altre di demo/in_classe.sh
# Uscita: quella di demo/in_classe.sh: 0 = gli stream si leggono e il controllo
#         non ha segnalazioni · 1 = una chiamata fallita, o una segnalazione ·
#         2 = precondizione
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly IN_CLASSE="${SELF%/_docente/*}/demo/in_classe.sh"

main() {
  if (( $# != 1 )); then
    echo "uso: _docente/live.sh <spazio di lavoro>" >&2
    exit 2
  fi
  PN_ESECUZIONI="${PN_ESECUZIONI:-3}" exec bash "${IN_CLASSE}" "$1"
}

main "$@"
