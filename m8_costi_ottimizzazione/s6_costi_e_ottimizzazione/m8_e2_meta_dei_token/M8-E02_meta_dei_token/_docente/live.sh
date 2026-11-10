#!/bin/bash
#
# live.sh di M8-E02 -- la prova del docente del laboratorio, per la
# registrazione del corso, con i comandi del README:
#   1. ./misura.sh v0;
#   2. la versione di riferimento: soluzione/prompt/v1.md copiata in
#      prompt/v1.md;
#   3. ./misura.sh v1;
#   4. ./misura.sh --confronta v0 v1;
#   5. verifica.sh dell'elemento.
# Dodici chiamate a claude -p: per ogni versione tre risposte (Sonnet, effort
# low) e tre giudizi (Haiku, effort low). La sessione interattiva del README,
# che scrive v1 con il prompt da incollare, qui non c'è: si applica la
# versione di riferimento, come dice il README nella «Prova del corso».
# Prima della prima chiamata controlla che v0 si componga su ogni caso: una
# cartella rotta ferma la prova prima di pagare le chiamate.
#
# Uso:    _docente/live.sh <spazio di lavoro>
#           lo spazio di lavoro appena preparato (tools/prepara_esercizio.sh
#           M8-E02)
# Env:    le variabili di tools/lib_handson.sh (HANDSON_NO_PAUSE, ...)
# Uscita: 0 = verifica.sh passa · 1 = una chiamata fallita (uscita 1 di
#         misura.sh) o verifica.sh che non passa · 2 = precondizione, anche di
#         misura.sh o di verifica.sh (uscita 2 o più: la verifica non ha
#         potuto girare). Al primo passo di misura.sh che fallisce la prova si
#         ferma, con la sua uscita.
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
# lo script sta in <radice>/m8_…/s6_…/m8_e2_…/M8-E02_…/_docente/
readonly RADICE="${SELF%/*/*/*/*/*/*}"
readonly ELEMENTO="${SELF%/_docente/*}"
readonly CONTROLLO="${ELEMENTO}/verifica.sh"
readonly SOLUZIONE="${ELEMENTO}/soluzione"
readonly CASI=(caso-1 caso-2 caso-3)
# shellcheck source=../../../../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"

# Un passo con misura.sh, mostrato e poi eseguito. Se fallisce la prova si
# ferma qui, con l'uscita di misura.sh (1 una chiamata fallita, 2 una
# precondizione) e una riga su STDERR che nomina il passo.
# Arguments: $1 il passo, poi il comando.
passo() {
  local nome="$1" rc=0
  shift
  handson::run "$@" || rc=$?
  if (( rc != 0 )); then
    handson::err "fallito il passo «${nome}» (uscita ${rc}): la prova si" \
      "ferma qui"
    exit "${rc}"
  fi
}

# Prima di ogni chiamata: lo spazio di lavoro ha ciò che serve e v0 si
# compone su ogni caso (segnaposto, controlli, rubrica, peso).
pronto() {
  local caso
  handson::need_tools python3 git
  handson::need_file misura.sh
  handson::need_file strumenti/kit.py
  handson::need_file prompt/v0.md
  for caso in "${CASI[@]}"; do
    python3 -B strumenti/kit.py componi "${caso}" v0 > /dev/null \
      || handson::die "${caso}: v0 non si compone (il messaggio di kit.py" \
        "è qui sopra)"
  done
}

main() {
  if (( $# != 1 )); then
    echo "uso: _docente/live.sh <spazio di lavoro>" >&2
    exit 2
  fi
  local ws="$1" out rc=0
  [[ -n "${ws}" && -d "${ws}" ]] \
    || handson::die "spazio di lavoro assente: ${ws}"
  ws="$(cd -- "${ws}" && pwd -P)" \
    || handson::die "lo spazio di lavoro $1 non si apre"
  handson::need_file "${SOLUZIONE}/prompt/v1.md"
  [[ -x "${CONTROLLO}" ]] \
    || handson::die "verifica.sh dell'elemento manca o non è eseguibile"
  cd "${ws}"
  pronto
  handson::need_claude
  handson::banner M8-E02 "Metà dei token, a parità di qualità" \
    "la prova del docente: v0, poi la versione di riferimento v1"
  printf 'data della prova: %s\n' "$(date -u +%F)"
  handson::step "La misura di v0"
  passo "la misura di v0" ./misura.sh v0
  handson::step "La versione di riferimento (soluzione/prompt/v1.md)"
  handson::run cp -- "${SOLUZIONE}/prompt/v1.md" prompt/v1.md
  handson::step "La misura di v1"
  passo "la misura di v1" ./misura.sh v1
  handson::step "Il confronto"
  passo "il confronto" ./misura.sh --confronta v0 v1
  handson::step "La verifica"
  out="$(PN_HANDSON_ROOT="${RADICE}" "${CONTROLLO}" "${ws}" 2>&1)" || rc=$?
  printf '%s\n' "${out}"
  handson::verdict_rc "${rc}" "verifica.sh dell'elemento"
  handson::finish
}

main "$@"
