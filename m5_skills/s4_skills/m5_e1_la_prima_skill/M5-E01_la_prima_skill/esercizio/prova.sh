#!/bin/bash
#
# prova.sh -- la prova della skill in una sessione nuova: una domanda come la
# farebbe chiunque, «Che cosa ho cambiato?», in un claude -p che non ha visto
# scrivere la skill. Lo stream resta in prova/stream.jsonl, e la prova di prima
# in prova/stream-<k>.jsonl; tools/verifica.sh M5-E01 li legge.
# È uno script a sé, senza tools/lib_handson.sh, perché lo spazio di lavoro sta
# fuori dal repository: ha le stesse opzioni (dontAsk, --permission-prompts
# none, --setting-sources project,local), e il comando si vede prima di girare.
# Skill(riassunto-modifiche) fra gli strumenti consentiti fa girare anche una
# skill con allowed-tools nel frontmatter: il README dice perché. Senza
# ANTHROPIC_API_KEY, che in -p prenderebbe il posto dell'abbonamento, e senza
# CLAUDE_CODE_EFFORT_LEVEL, che ha la precedenza su --effort.
#
# Uso:    bash prova.sh    nello spazio di lavoro di M5-E01
# Uscita: 0 = lo stream c'è (che cosa dice, lo dice la verifica) · 1 = claude -p
#         è fallito · 2 = precondizione (claude o python3 che mancano, la skill
#         che manca)
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly SPAZIO="${SELF%/*}"
readonly SKILL=riassunto-modifiche
readonly DOMANDA='Che cosa ho cambiato?'
readonly STREAM=prova/stream.jsonl

err() { echo "prova.sh: $*" >&2; }

# Il comando in una riga incollabile, su STDERR. Arguments: il comando.
mostra() {
  local tok sq="'" esc="'\\''" riga=''
  for tok in "$@"; do
    if [[ ! "${tok}" =~ ^[A-Za-z0-9._/:=@%+,-]+$ ]]; then
      tok="'${tok//${sq}/${esc}}'"
    fi
    riga+="${riga:+ }${tok}"
  done
  printf '  $ %s\n\n' "${riga}" >&2
}

# La prova di prima, se c'è, in prova/stream-<k>.jsonl, il primo k libero.
conserva_la_precedente() {
  local k=1
  [[ -e "${STREAM}" ]] || return 0
  while [[ -e "prova/stream-${k}.jsonl" ]]; do
    k=$((k + 1))
  done
  mv -- "${STREAM}" "prova/stream-${k}.jsonl"
}

# La risposta della prova, dal suo stream.
stampa_risposta() {
  python3 -B -I - "${STREAM}" <<'PY'
import json
import sys

ultimo = {}
with open(sys.argv[1], encoding="utf-8") as fh:
    for riga in fh:
        try:
            evento = json.loads(riga)
        except ValueError:
            continue
        if isinstance(evento, dict) and evento.get("type") == "result":
            ultimo = evento
print("La risposta:\n\n%s" % ultimo.get("result", "(nessun risultato)"))
PY
}

main() {
  local t
  local -a argv=(claude -p --allowedTools "Read,Skill(${SKILL})" --model sonnet
    --effort low --permission-mode dontAsk --permission-prompts none
    --output-format stream-json --verbose --setting-sources 'project,local'
    --strict-mcp-config --no-session-persistence -- "${DOMANDA}")
  for t in claude python3; do
    if ! command -v "${t}" > /dev/null 2>&1; then
      err "manca ${t}: rifate i passi di PRIMA_DEL_CORSO.md"
      exit 2
    fi
  done
  cd -- "${SPAZIO}"
  if [[ ! -f ".claude/skills/${SKILL}/SKILL.md" ]]; then
    err "manca la skill: .claude/skills/${SKILL}/SKILL.md"
    exit 2
  fi
  mkdir -p prova
  mostra "${argv[@]}"
  if ! env -u ANTHROPIC_API_KEY -u CLAUDE_CODE_EFFORT_LEVEL "${argv[@]}" \
      < /dev/null > "${STREAM}.parziale"; then
    err "claude -p è fallito: ciò che ha scritto è in ${STREAM}.parziale"
    exit 1
  fi
  conserva_la_precedente
  mv -- "${STREAM}.parziale" "${STREAM}"
  stampa_risposta
}

main "$@"
