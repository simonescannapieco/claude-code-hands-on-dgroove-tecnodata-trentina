#!/bin/bash
#
# live.sh di M1-E01 -- la prova dal vivo dell'esercitazione, come la farebbe
# un partecipante, in tre tempi:
#   1. il prompt scelto, su haiku, sonnet e opus, con claude -p senza
#      strumenti né server MCP: risposte/<modello>.json;
#   2. la sessione interattiva del README, qui in claude -p su sonnet con i
#      soli strumenti Read ed Edit e la consegna di consegna_confronto.txt:
#      Claude scrive i numeri nella tabella di confronto.md;
#   3. la parte del partecipante (il prompt usato, il giudizio, la scelta):
#      la scrive questo script, con un testo che dice che è una prova
#      automatica.
# Poi verifica.sh dell'elemento.
#
# Uso:    _docente/live.sh <spazio di lavoro>
# Env:    PN_PROMPT  il prompt (default prompt/sistemi.md; anche
#                    prompt/sviluppo.md, prompt/supporto.md)
#         e le variabili di tools/lib_handson.sh (HANDSON_NO_PAUSE, …)
# Uscita: 0 = verifica.sh passa · 1 = una chiamata fallita o la verifica
#         non passa · 2 = precondizione
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
# lo script sta in <radice>/m1_…/s1_…/m1_e2_…/M1-E01_…/_docente/
readonly RADICE="${SELF%/*/*/*/*/*/*}"
readonly CONTROLLO="${SELF%/_docente/*}/verifica.sh"
# shellcheck source=../../../../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"

readonly MODELLI=(haiku sonnet opus)
readonly PROMPT="${PN_PROMPT:-prompt/sistemi.md}"
readonly ISTRUZIONE='Rispondi in italiano.'
readonly AUTOMATICA='(prova automatica del docente)'

# La parte del partecipante in confronto.md: il prompt usato, la colonna
# del giudizio, la scelta e il perché, al posto dei «…» rimasti.
parte_del_partecipante() {
  python3 -B -I - confronto.md "${PROMPT}" "${AUTOMATICA}" <<'PY'
import re
import sys

path, prompt, nota = sys.argv[1:4]
with open(path, encoding="utf-8") as fh:
    righe = fh.read().split("\n")
for i, riga in enumerate(righe):
    if riga.startswith("Prompt usato:"):
        righe[i] = "Prompt usato: " + prompt
    elif riga.startswith("Per questo compito sceglierei:"):
        righe[i] = "Per questo compito sceglierei: sonnet"
    elif riga.startswith("Perché:"):
        righe[i] = "Perché: " + nota
    elif re.match(r"\|\s*(haiku|sonnet|opus)\s*\|", riga):
        righe[i] = re.sub(r"\|\s*…\s*\|\s*$", "| " + nota + " |", riga)
with open(path, "w", encoding="utf-8") as fh:
    fh.write("\n".join(righe))
PY
}

main() {
  local ws="${1:-}" m json out rc=0
  [[ -n "${ws}" && -d "${ws}" ]] \
    || handson::die "spazio di lavoro assente: ${ws}"
  case "${PROMPT}" in
    prompt/sistemi.md|prompt/sviluppo.md|prompt/supporto.md) ;;
    *) handson::die "PN_PROMPT non ammesso: «${PROMPT}»" ;;
  esac
  cd "${ws}"
  handson::need_tools python3 jq
  handson::need_file "${PROMPT}"
  handson::need_file confronto.md
  handson::need_file consegna_confronto.txt
  handson::need_claude
  handson::banner M1-E01 "Lo stesso prompt su tre modelli" \
    "Modulo 1, pratica: ${PROMPT}"
  mkdir -p risposte
  for m in "${MODELLI[@]}"; do
    handson::step "1. ${m}"
    handson::claude_p "${m}" "" "$(cat "${PROMPT}")" --tools "" \
      --system-prompt "${ISTRUZIONE}" --effort low --strict-mcp-config \
      > "risposte/${m}.json" \
      || handson::verdict ko "${m}: claude -p è fallito"
  done
  handson::step "2. Claude compila i numeri di confronto.md"
  # Nella shell dello script e non dentro $(…), come al passo 1: una
  # precondizione di handson::claude_p esce davvero con 2.
  handson::tmpfile json
  if handson::claude_p sonnet "Read,Edit" "$(cat consegna_confronto.txt)" \
      --effort low --strict-mcp-config > "${json}"; then
    jq -r '.result // empty' "${json}"
  else
    handson::verdict ko "sonnet: la compilazione dei numeri è fallita"
  fi
  handson::step "3. La parte del partecipante"
  parte_del_partecipante
  handson::step "La verifica"
  out="$("${CONTROLLO}" "${ws}" 2>&1)" || rc=$?
  printf '%s\n' "${out}"
  if (( rc == 0 )); then
    handson::verdict ok "verifica.sh dell'elemento"
  else
    handson::verdict ko "verifica.sh dell'elemento (uscita ${rc})"
  fi
  handson::finish
}

main "$@"
