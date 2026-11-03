#!/bin/bash
#
# in_classe.sh di M5-D04 -- una coppia, in aula: la richiesta di un archetipo,
# una volta dalla cartella con la skill e una dalla cartella senza, con lo
# stesso comando, in due sessioni nuove di `claude -p`. Lo script sta nello
# spazio di lavoro, e lì prepara le due cartelle dell'archetipo (la skill la
# copia dal repository, in riferimenti/skill-di-esempio/, senza evals/). Gli
# stream restano in una cartella temporanea finché le due sessioni non sono
# finite; poi vanno in risposte/, con il numero libero dopo quelli che ci sono
# già, e controlla_archetipi.py dice che cosa ha trovato.
#
# Ogni chiamata: Sonnet, effort low, --strict-mcp-config,
# --no-session-persistence, gli strumenti Read e Skill(<skill>), che servono in
# entrambi i bracci. Il comando si vede prima di girare.
#
# Uso:    ./in_classe.sh revisione|risposta|audit
# Env:    PN_HANDSON_ROOT  il repository (la cartella delle esercitazioni):
#                          obbligatoria, qui lo script è fuori dal repository
# Uscita: 0 = la coppia è letta e le garanzie tengono · 1 = una chiamata
#         fallita, uno stream che non va, una garanzia che non regge · 2 =
#         precondizione (PN_HANDSON_ROOT, l'archetipo, lo spazio di lavoro, un
#         file che manca, claude)
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly WS="${SELF%/*}"

if [[ -z "${PN_HANDSON_ROOT:-}" \
    || ! -f "${PN_HANDSON_ROOT}/tools/lib_handson.sh" ]]; then
  echo "in_classe.sh: PN_HANDSON_ROOT deve essere la cartella delle" \
    "esercitazioni: export PN_HANDSON_ROOT=<la cartella>" >&2
  exit 2
fi
# shellcheck source=/dev/null
source "${PN_HANDSON_ROOT}/tools/lib_handson.sh"
# shellcheck source=lib_archetipi.sh
source "${WS}/lib_archetipi.sh"

# Il primo numero di coppia libero. Arguments: $1 la cartella degli stream, $2
# l'archetipo. Outputs: il numero.
prossima_coppia() {
  local n=1
  while [[ -e "$1/$2-on-${n}.jsonl" || -e "$1/$2-senza-${n}.jsonl" ]]; do
    n=$((n + 1))
  done
  printf '%d\n' "${n}"
}

# controlla_archetipi.py con il suo STDOUT sul descrittore 3: handson::check
# mostra un controllo solo su un KO, e qui i dati sono la demo anche quando
# passa. Returns: l'uscita del controllo.
# shellcheck disable=SC2317  # la chiama handson::check, indirettamente
controllo_a_schermo() {
  python3 -B -I "${WS}/controlla_archetipi.py" "${WS}/risposte" >&3
}

main() {
  local archetipo="${1:-}" skill richiesta deposito n braccio
  [[ -n "${archetipo}" ]] \
    || handson::die "manca l'archetipo: revisione, risposta o audit"
  skill="$(archetipi::skill_di "${archetipo}")" \
    || handson::die "archetipo sconosciuto: ${archetipo} (revisione, risposta" \
      "o audit)"
  archetipi::precondizioni "${WS}"
  handson::init_root || exit 2
  richiesta="$(archetipi::richiesta "${WS}/richieste.tsv" "${archetipo}")"
  handson::need_claude
  handson::_claude_p_checks sonnet "${richiesta}"
  handson::banner M5-D04 "Prima e dopo, tre archetipi" \
    "Modulo 5: la stessa richiesta, con la skill ${skill} e senza"
  archetipi::prepara "${WS}" "${archetipo}"
  handson::tmpdir deposito
  n="$(prossima_coppia "${WS}/risposte" "${archetipo}")"
  for braccio in on senza; do
    handson::step "${archetipo}, ${braccio}: una sessione nuova"
    if ! archetipi::esegui "${WS}" "${archetipo}" sonnet "${braccio}" \
        "${richiesta}" "${deposito}/${archetipo}-${braccio}-${n}.jsonl"; then
      archetipi::consegna "${deposito}" "${WS}/risposte"
      handson::verdict ko "${archetipo}, ${braccio}: claude -p è fallito"
      handson::finish
    fi
  done
  archetipi::consegna "${deposito}" "${WS}/risposte"
  handson::step "Che cosa dicono le esecuzioni"
  exec 3>&1
  handson::check "la coppia, letta dagli stream" controllo_a_schermo
  handson::finish
}

main "$@"
