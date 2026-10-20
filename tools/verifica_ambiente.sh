#!/bin/bash
#
# verifica_ambiente.sh -- controlla, prima del corso, che sul computer ci
# sia tutto quello che serve alle esercitazioni e, per ciò che manca, dice
# quale paragrafo di PRIMA_DEL_CORSO.md leggere:
#   - il sistema operativo: Linux, oppure Windows con WSL 2 (ogni altro
#     sistema, WSL 1 compreso, è da sistemare);
#   - Claude Code (il comando claude) e la sua versione;
#   - ANTHROPIC_API_KEY non impostata: con la chiave impostata Claude Code
#     userebbe la chiave invece dell'abbonamento Pro (il valore non viene
#     mai stampato);
#   - git;
#   - PHP 8.3 o successivo con Composer, oppure Docker con il servizio
#     attivo (tools/php.sh usa l'uno o l'altro);
#   - python3, il comando con cui le esercitazioni lanciano Python, con
#     Python 3.8 o successivo (un comando python senza python3 non basta),
#     e uv.
# Di Claude Code esegue soltanto claude --version: nessun prompt, nessuna
# richiesta al modello.
# Volutamente autonomo, senza librerie: è il primo script che si lancia, e
# deve poter dire che cosa manca anche su un computer appena preparato.
#
# Uso:    tools/verifica_ambiente.sh
# Env:    PN_PROC_VERSION  il file da cui riconoscere WSL (default:
#                          /proc/version); serve ai test
# Uscita: 0 = tutto presente · 1 = qualcosa da sistemare
#         2 = precondizione (argomenti non validi)
set -euo pipefail

readonly PROC_VERSION="${PN_PROC_VERSION:-/proc/version}"
readonly MIN_PHP_ID=80300
readonly MIN_PY_MINOR=8
readonly PY_RE='^Python 3\.([0-9]+)'
readonly GUIDA='PRIMA_DEL_CORSO.md'
readonly USO='Uso: tools/verifica_ambiente.sh'
readonly NL=$'\n'
DA_FARE=0

# Una riga di esito. Arguments: $1 che cosa, poi il dettaglio.
ok() { local cosa="$1"; shift; printf '  [ok]        %s: %s\n' "${cosa}" "$*"; }

# Una riga da sistemare, contata. Globals: DA_FARE.
# Arguments: $1 che cosa, poi che cosa fare (anche in più pezzi).
da_fare() {
  local cosa="$1"
  shift
  printf '  [da fare]   %s: %s\n' "${cosa}" "$*"
  DA_FARE=$((DA_FARE + 1))
}

# Un comando che deve rispondere: ok con la sua prima uscita, altrimenti
# da sistemare. Arguments: $1 l'etichetta, $2 il paragrafo della guida,
# poi il comando.
presente() {
  local cosa="$1" paragrafo="$2" v=''
  shift 2
  if command -v "$1" >/dev/null 2>&1 && v="$("$@" 2>/dev/null)" \
      && [[ -n "${v}" ]]; then
    ok "${cosa}" "${v%%"${NL}"*}"
  else
    da_fare "${cosa}" "non c'è o non risponde (${GUIDA}, «${paragrafo}»)"
  fi
}

# Il sistema operativo: in ordine solo Linux e Windows con WSL 2; ogni
# altro (macOS, Git Bash/MSYS, Cygwin, WSL 1, …) è da sistemare.
check_os() {
  local s='' v='' nome
  s="$(uname -s 2>/dev/null)" || s='sconosciuto'
  if [[ -r "${PROC_VERSION}" ]]; then
    v="$(< "${PROC_VERSION}")"
  fi
  case "${s}:${v}" in
    Linux:*WSL2*) ok "sistema operativo" "Windows, WSL 2"; return 0 ;;
    Linux:*[Mm]icrosoft*) nome="Windows, WSL 1" ;;
    Linux:*) ok "sistema operativo" "Linux"; return 0 ;;
    Darwin:*) nome="macOS" ;;
    MINGW*) nome="Windows, Git Bash" ;;
    MSYS*) nome="Windows, MSYS" ;;
    CYGWIN*) nome="Windows, Cygwin" ;;
    *) nome="«${s}»" ;;
  esac
  da_fare "sistema operativo" "${nome}: il corso presuppone Linux o Windows" \
    "con WSL 2 (${GUIDA}, «Linux o Windows con WSL 2»)"
}

check_api_key() {
  if [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
    da_fare "ANTHROPIC_API_KEY" "è impostata: Claude Code userebbe la" \
      "chiave invece dell'abbonamento Pro; toglila (${GUIDA}," \
      "«La chiave API non serve»)"
  else
    ok "ANTHROPIC_API_KEY" "non impostata: Claude Code usa l'abbonamento"
  fi
}

check_php_docker() {
  local id='' v=''
  if command -v php >/dev/null 2>&1 && command -v composer >/dev/null 2>&1 \
      && id="$(php -r 'echo PHP_VERSION_ID;' 2>/dev/null)" \
      && [[ "${id}" =~ ^[0-9]+$ ]] && (( id >= MIN_PHP_ID )); then
    ok "PHP e Composer" "PHP $(php -r 'echo PHP_VERSION;' 2>/dev/null)"
  elif command -v docker >/dev/null 2>&1 \
      && v="$(docker version --format '{{.Server.Version}}' 2>/dev/null)" \
      && [[ -n "${v}" ]]; then
    ok "Docker" "servizio attivo, versione ${v}"
  else
    da_fare "PHP o Docker" "serve PHP 8.3 o successivo con Composer," \
      "oppure Docker con il servizio attivo" \
      "(${GUIDA}, «Docker, oppure PHP e Composer»)"
  fi
}

# Python: conta soltanto python3, il comando che lanciano gli script delle
# esercitazioni; un python accanto non lo sostituisce.
check_python() {
  local v=''
  if command -v python3 >/dev/null 2>&1 \
      && v="$(python3 --version 2>&1)" && [[ "${v}" =~ ${PY_RE} ]] \
      && (( BASH_REMATCH[1] >= MIN_PY_MINOR )); then
    ok "Python" "${v} (python3)"
  elif command -v python3 >/dev/null 2>&1; then
    da_fare "Python" "python3 c'è, ma serve Python 3.8 o successivo" \
      "(${GUIDA}, «Python e uv»)"
  elif command -v python >/dev/null 2>&1; then
    da_fare "Python" "c'è il comando python, ma non python3, quello che" \
      "lanciano le esercitazioni: installate Python 3.8 o successivo in" \
      "modo che risponda python3 --version (${GUIDA}, «Python e uv»)"
  else
    da_fare "Python" "serve Python 3.8 o successivo, con il comando python3" \
      "(${GUIDA}, «Python e uv»)"
  fi
}

main() {
  case "$#:${1:-}" in
    0:) ;;
    1:-h|1:--help) printf '%s\n' "${USO}"; exit 0 ;;
    *) printf '%s\n' "${USO}" >&2; exit 2 ;;
  esac
  printf "Controllo dell'ambiente per le esercitazioni\n\n"
  check_os
  presente "Claude Code" "Installare Claude Code" claude --version
  check_api_key
  presente "git" "git" git --version
  check_php_docker
  check_python
  presente "uv" "Python e uv" uv --version
  if (( DA_FARE == 0 )); then
    printf '\nTutto pronto per il corso.\n'
    exit 0
  fi
  printf '\nDa sistemare: %d. Le istruzioni sono in %s.\n' "${DA_FARE}" \
    "${GUIDA}"
  exit 1
}

main "$@"
