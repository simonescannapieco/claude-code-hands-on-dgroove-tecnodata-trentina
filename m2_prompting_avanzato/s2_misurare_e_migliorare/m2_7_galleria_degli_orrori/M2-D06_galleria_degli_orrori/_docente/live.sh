#!/bin/bash
#
# live.sh di M2-D06 -- la demo del docente: la galleria degli orrori.
# Quattro coppie di prompt sul messaggio di un cliente, ogni orrore contro
# la sua cura, una differenza per coppia; una chiamata per prova, nove in
# tutto, con claude -p a sonnet, senza strumenti né server MCP, con le
# stesse opzioni e gli stessi testi dei passi del README:
#   orrore-1-vaga, cura-1-vaga         la richiesta vaga, poi formato e
#                                      vincoli;
#   base-2-formato, orrore-2-divieto,  il riepilogo senza indicazioni sul
#   cura-2-divieto                     formato, con il divieto del
#                                      markdown, con la prosa chiesta in
#                                      positivo;
#   orrore-3-stima, cura-3-stima       la stima dei costi, poi solo le
#                                      informazioni del messaggio;
#   orrore-4-memoria, cura-4-memoria   «Come ti ho detto ieri…» senza il
#                                      messaggio, poi il formato concordato
#                                      e il messaggio nel prompt.
# Il JSON di ogni chiamata va in risposte/<prova>.json, misura_orrori.py
# ne aggiunge la riga a orrori.tsv, e verifica.sh stampa i numeri e
# l'esito di ogni affermazione anche quando il controllo passa
# (handson::check, su un OK, resta muto: le righe passano dal
# descrittore 3, lo STDOUT di questo script).
#
# Uso:    _docente/live.sh <spazio di lavoro>
# Env:    PN_MODELLO  il modello (default sonnet; ammessi haiku, sonnet, opus)
#         e le variabili di tools/lib_handson.sh (HANDSON_NO_PAUSE, …)
# Uscita: 0 = le nove risposte ci sono e la garanzia (la firma concordata
#         manca nella memoria presunta) è confermata · 1 = una chiamata
#         fallita, una risposta mancante o la garanzia non confermata ·
#         2 = precondizione (spazio di lavoro, modello, un file di
#         partenza, un importo in euro negli ingressi, claude assente)
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
# lo script sta in <radice>/m2_…/s2_…/m2_7_…/M2-D06_…/_docente/
readonly RADICE="${SELF%/*/*/*/*/*/*}"
readonly CONTROLLO="${SELF%/_docente/*}/verifica.sh"
# shellcheck source=../../../../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"

readonly MODELLO="${PN_MODELLO:-sonnet}"
readonly PROVE=(orrore-1-vaga cura-1-vaga base-2-formato orrore-2-divieto
  cura-2-divieto orrore-3-stima cura-3-stima orrore-4-memoria cura-4-memoria)

# Una prova: la chiamata, il suo JSON in risposte/<prova>.json, la sua
# riga in orrori.tsv e a schermo. Arguments: $1 la prova.
# Returns: 0; 1 se la chiamata fallisce o il suo JSON non è una risposta
# riuscita; una misura che non può girare (uscita 2) esce 2.
prova() {
  local p="$1" riga rc=0
  handson::claude_p "${MODELLO}" "" "$(cat "${p}.md")" --effort low \
    --tools "" --strict-mcp-config --no-session-persistence \
    --system-prompt "$(cat istruzione.txt)" < /dev/null \
    > "risposte/${p}.json" || return 1
  riga="$(python3 misura_orrori.py "${p}" < "risposte/${p}.json")" || rc=$?
  if (( rc >= 2 )); then
    handson::die "misura_orrori.py non può misurare ${p} (uscita ${rc})"
  fi
  (( rc == 0 )) || return 1
  printf '%s\n' "${riga}" >> orrori.tsv
  printf '  %-17s token in uscita %s, parole %s, righe %s\n' "${p}" \
    "$(cut -f3 <<< "${riga}")" "$(cut -f4 <<< "${riga}")" \
    "$(cut -f5 <<< "${riga}")"
}

# Una prova senza risposta: il verdetto KO e la fine con uscita 1, senza
# fare le chiamate che restano.
fallita() {
  handson::verdict ko "$*"
  handson::finish
}

# Il controllo dell'esito: verifica.sh, con le sue righe sul descrittore 3.
# Arguments: $1 lo spazio di lavoro. Returns: l'uscita di verifica.sh.
# shellcheck disable=SC2317  # la chiama handson::check, indirettamente
controllo() {
  "${CONTROLLO}" "$1" >&3
}

main() {
  local ws="${1:-}" p intestazione
  [[ -n "${ws}" && -d "${ws}" ]] \
    || handson::die "spazio di lavoro assente: ${ws}"
  case "${MODELLO}" in
    haiku|sonnet|opus) ;;
    *) handson::die "modello non ammesso in PN_MODELLO: «${MODELLO}»" ;;
  esac
  cd "${ws}"
  handson::need_tools python3 cut
  for p in "${PROVE[@]}"; do
    handson::need_file "${p}.md"
  done
  handson::need_file istruzione.txt
  handson::need_file messaggio.md
  handson::need_file misura_orrori.py
  handson::tmpfile intestazione
  python3 misura_orrori.py --intestazione > "${intestazione}" \
    || handson::die "misura_orrori.py rifiuta gli ingressi (vedi sopra)"
  handson::need_claude
  handson::banner M2-D06 "La galleria degli orrori" \
    "Modulo 2, «La galleria degli orrori»: nove prove a ${MODELLO}"
  mkdir -p risposte
  cp -- "${intestazione}" orrori.tsv
  for p in "${PROVE[@]}"; do
    handson::step "${p}"
    prova "${p}" || fallita "${p}: nessuna risposta"
  done
  handson::step "Il controllo dell'esito"
  exec 3>&1
  handson::check "nove risposte, la firma assente nella memoria presunta" \
    controllo "${ws}"
  handson::finish
}

main "$@"
