#!/bin/bash
#
# live.sh di M1-D05 -- la parte del docente in Claude Code. Ogni chiamata
# manda la circolare n. 6/2025 di CiaspoLink fra i tag <documento> e, sotto,
# una domanda: A (domanda-documento.txt), a cui la circolare risponde, o B
# (richiesta.txt), il riassunto della n. 7/2025, che la circolare non ha.
# Cambia una cosa sola, l'istruzione di sistema: le tre regole
# (regole.txt) o la sola riga «Rispondi in italiano.» (istruzione.txt).
# Quattro chiamate per modello (haiku, sonnet, opus), dodici in tutto, con
# claude -p, effort low, senza strumenti, server MCP né sessione salvata:
# gli stessi testi e le stesse opzioni dei passi del README. Il JSON di
# ogni chiamata in risposte/<domanda>-<variante>-<modello>.json e la
# risposta a schermo; poi il passo dei partecipanti, controlla_citazioni.py
# (i numeri e i verdetti a schermo, esiti.tsv), e verifica.sh.
#
# Uso:    _docente/live.sh <spazio di lavoro>
# Env:    le variabili di tools/lib_handson.sh (HANDSON_NO_PAUSE, …)
# Uscita: 0 = le dodici risposte ci sono (i verdetti si stampano e non
#         fanno fallire: le affermazioni sono raccomandazioni)
#         1 = una chiamata fallita, o una risposta mancante o incompleta
#         2 = precondizione, anche del controllo o di verifica.sh (uscita 2
#             o più: non hanno potuto girare)
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
# lo script sta in <radice>/m1_…/s1_…/m1_4_…/M1-D05_…/_docente/
readonly RADICE="${SELF%/*/*/*/*/*/*}"
readonly CONTROLLO="${SELF%/_docente/*}/verifica.sh"
# shellcheck source=../../../../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"

readonly MODELLI=(haiku sonnet opus)
readonly DOCUMENTO='circolare-6-2025.md'
# La domanda A e la B, con i loro file; le due varianti, con i file
# dell'istruzione di sistema.
readonly DOMANDE=(A B)
readonly FILE_DOMANDE=(domanda-documento.txt richiesta.txt)
readonly VARIANTI=(senza regole)
readonly FILE_ISTRUZIONI=(istruzione.txt regole.txt)
# Quanti caratteri di una risposta mostrare a schermo.
readonly LUNGHEZZA=240

# Il messaggio di una chiamata: la circolare fra i tag <documento>, una
# riga vuota, la domanda; i due file senza gli a capo finali, come nei
# passi del README. Arguments: $1 il file della domanda.
# Outputs: il messaggio su STDOUT.
messaggio() {
  printf '<documento>\n%s\n</documento>\n\n%s' "$(cat "${DOCUMENTO}")" \
    "$(cat "$1")"
}

# Una chiamata: il JSON di claude nel file $4. Va chiamata nella shell
# dello script, non dentro $(…): così una precondizione di
# handson::claude_p (modalità di permesso, ambiente, prompt vuoto) esce
# davvero con 2, invece di diventare una chiamata fallita.
# Arguments: $1 il modello, $2 il file della domanda, $3 il file
#   dell'istruzione di sistema, $4 il file del JSON.
# Returns: l'uscita di claude.
chiama() {
  handson::claude_p "$1" "" "$(messaggio "$2")" --tools "" \
    --system-prompt "$(cat "$3")" --effort low --strict-mcp-config \
    --no-session-persistence > "$4"
}

# La risposta di una chiamata, a schermo, su una riga e tagliata a
# LUNGHEZZA caratteri (contati da jq, anche con LC_ALL=C).
# Arguments: $1 l'etichetta, $2 il file del JSON.
# Returns: 1 se il JSON non ha una risposta.
mostra() {
  local r
  r="$(jq -er --argjson n "${LUNGHEZZA}" 'select(.is_error == false)
    | .result | select(type == "string")
    | gsub("\\s+"; " ") | gsub("^ | $"; "") | select(length > 0)
    | if length > $n then .[0:$n] + " …" else . end' "$2")" || return 1
  printf '  %-9s %s\n' "$1" "${r}"
}

main() {
  local ws="${1:-}" m i j json rc=0
  [[ -n "${ws}" && -d "${ws}" ]] \
    || handson::die "spazio di lavoro assente: ${ws}"
  cd "${ws}"
  handson::need_tools jq python3
  handson::need_file "${DOCUMENTO}"
  for i in "${!DOMANDE[@]}"; do
    handson::need_file "${FILE_DOMANDE[i]}"
  done
  for j in "${!VARIANTI[@]}"; do
    handson::need_file "${FILE_ISTRUZIONI[j]}"
  done
  handson::need_file controlla_citazioni.py
  handson::need_claude
  handson::banner M1-D05 "La circolare che non esiste" \
    "Modulo 1, «Punti di forza, limiti, allucinazioni»: dodici chiamate"
  mkdir -p risposte
  for m in "${MODELLI[@]}"; do
    handson::step "${m}"
    for i in "${!DOMANDE[@]}"; do
      for j in "${!VARIANTI[@]}"; do
        json="risposte/${DOMANDE[i]}-${VARIANTI[j]}-${m}.json"
        if ! chiama "${m}" "${FILE_DOMANDE[i]}" "${FILE_ISTRUZIONI[j]}" \
            "${json}" || ! mostra "${DOMANDE[i]} ${VARIANTI[j]}" "${json}"
        then
          handson::verdict ko \
            "${m}, ${DOMANDE[i]} ${VARIANTI[j]}: nessuna risposta"
        fi
      done
    done
  done
  handson::step "Il passo dei partecipanti: controlla_citazioni.py"
  handson::run python3 -B -I controlla_citazioni.py || rc=$?
  handson::verdict_rc "${rc}" "controlla_citazioni.py: esiti.tsv e verdetti"
  handson::step "La verifica dell'elemento"
  handson::check "verifica.sh: le dodici risposte ci sono" \
    "${CONTROLLO}" "${ws}"
  handson::finish
}

main "$@"
