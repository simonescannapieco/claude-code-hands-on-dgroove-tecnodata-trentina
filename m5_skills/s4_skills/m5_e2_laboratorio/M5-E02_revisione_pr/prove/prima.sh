#!/bin/bash
#
# prima.sh di M5-E02 -- prepara la copia pulita di un caso di prova: crea il
# branch del suo pull request, applica la patch e fa il commit con il messaggio
# del pull request, e lascia HEAD lì. Lo chiama tools/prove_skill.sh, una volta
# per ogni copia, prima che parta la sessione. Le patch stanno qui, fuori dallo
# spazio di lavoro: Claude le vede soltanto come differenza fra il branch e
# main.
#
# Uso:    prove/prima.sh <copia> <id>
#           <copia>  un repository git con un commit, sul branch main
#           <id>     1, 2 o 3, il caso di evals.json e il suo pull request;
#                    q<k>, una richiesta di eval_queries.json: gira su pr-1
# Uscita: 0 = HEAD sul branch pr-<n>, con il commit · 2 = precondizione:
#         argomenti, un caso che non ha un pull request, una copia che non è un
#         repository, una patch o un messaggio che manca, una patch che non si
#         applica, un commit che non riesce
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly PROVE="${SELF%/*}"

err() { echo "prima.sh: $*" >&2; }

# Globals: PROVE. Arguments: $1 la copia, $2 il numero del pull request.
applica_pull_request() {
  local copia="$1" n="$2"
  local patch="${PROVE}/pr-${n}.patch" messaggio="${PROVE}/pr-${n}.msg"
  if [[ ! -r "${patch}" || ! -r "${messaggio}" ]]; then
    err "manca ${patch} o ${messaggio}"
    exit 2
  fi
  if ! git -C "${copia}" checkout -q -b "pr-${n}"; then
    err "non riesco a creare il branch pr-${n}"
    exit 2
  fi
  if ! git -C "${copia}" apply --whitespace=nowarn "${patch}"; then
    err "pr-${n}.patch non si applica su ${copia}"
    exit 2
  fi
  if ! git -C "${copia}" add -A \
      || ! git -C "${copia}" -c commit.gpgsign=false commit -q --no-verify \
        -F "${messaggio}"; then
    err "il commit di pr-${n} non riesce"
    exit 2
  fi
}

main() {
  if (( $# != 2 )); then
    err "Uso: prove/prima.sh <copia> <id>"
    exit 2
  fi
  local copia="$1" id="$2" n
  case "${id}" in
    1|2|3) n="${id}" ;;
    q[1-9]*) n=1 ;;
    *) err "il caso ${id} non ha un pull request: M5-E02 ha tre pull" \
         "request, per i casi 1, 2 e 3"
       exit 2 ;;
  esac
  if [[ ! -d "${copia}/.git" ]]; then
    err "${copia} non è un repository git"
    exit 2
  fi
  applica_pull_request "${copia}" "${n}"
}

main "$@"
