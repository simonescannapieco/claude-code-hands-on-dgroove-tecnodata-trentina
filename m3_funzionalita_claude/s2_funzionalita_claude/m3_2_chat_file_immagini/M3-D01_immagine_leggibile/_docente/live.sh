#!/bin/bash
#
# live.sh di M3-D01 -- la demo del docente: un'immagine leggibile.
# La stessa tabella di allarmi in due grandezze, allarmi.png (1600×1000) e
# allarmi-piccola.png (160×100), la stessa domanda (prompt.txt, con il nome
# del file al posto di IMMAGINE), lo stesso modello, le stesse opzioni: le
# due chiamate di una coppia differiscono solo nell'immagine e nel suo
# nome, che il prompt nomina. Ogni chiamata parte dalla sottocartella della
# sua grandezza, grande/ o piccola/, che contiene soltanto la sua immagine
# e una copia di .claude/ (come al passo 3 del README; la registrazione del
# corso fa partire ogni chiamata da una cartella nuova con la sola
# immagine). claude -p con
# il solo strumento Read (--tools Read, consentito con --allowedTools Read),
# effort low, senza server MCP, senza salvare la sessione; a haiku e a
# sonnet, tre coppie ciascuno: dodici chiamate, il JSON di ognuna in
# risposte/<grandezza>-<modello>-<n>.json. Gli stessi testi e le stesse
# opzioni del passo 3 del README, più quelle che handson::claude_p imposta
# da sé (--permission-mode dontAsk, --permission-prompts none,
# --setting-sources project,local). Poi controlla_lettura.py scrive
# esiti.tsv, e verifica.sh dice, per ogni modello, che cosa ha letto ogni
# risposta e se la prova conferma le tre affermazioni di Anthropic: i suoi
# verdetti si vedono anche quando passa. In aula i partecipanti provano le
# due immagini in claude.ai.
#
# Uso:    _docente/live.sh <spazio di lavoro>
# Env:    le variabili di tools/lib_handson.sh (HANDSON_NO_PAUSE, …)
# Uscita: 0 = le dodici risposte ci sono e si leggono (i verdetti non
#         decidono l'uscita) · 1 = una chiamata fallita, o una risposta che
#         manca o non va · 2 = precondizione (anche un prompt.txt che non
#         contiene IMMAGINE, prima di ogni chiamata)
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
# lo script sta in <radice>/m3_…/s2_…/m3_2_…/M3-D01_…/_docente/
readonly RADICE="${SELF%/*/*/*/*/*/*}"
readonly CONTROLLO="${SELF%/_docente/*}/verifica.sh"
# shellcheck source=../../../../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"

readonly MODELLI=(haiku sonnet)
readonly GRANDEZZE=(grande piccola)
readonly SEGNAPOSTO=IMMAGINE

# Il file dell'immagine di una grandezza. Arguments: $1 grande o piccola.
# Outputs: il nome del file.
immagine() {
  if [[ "$1" == piccola ]]; then
    echo allarmi-piccola.png
  else
    echo allarmi.png
  fi
}

# Le due sottocartelle, come al passo 3 del README: ognuna con la sua
# immagine soltanto e una copia di .claude/, così le impostazioni dello
# spazio di lavoro valgono anche lì. Va chiamata nello spazio di lavoro.
prepara_cartelle() {
  local g f
  for g in "${GRANDEZZE[@]}"; do
    f="$(immagine "${g}")"
    mkdir -p "${g}"
    cp -- "${f}" "${g}/"
    cp -R -- .claude "${g}/"
  done
}

# Una chiamata dalla sottocartella della sua grandezza, con il suo JSON in
# risposte/ dello spazio di lavoro. Fuori da $(…): una precondizione di
# handson::claude_p esce davvero con 2.
# Arguments: $1 lo spazio di lavoro (assoluto), $2 il modello, $3 la
# grandezza, $4 il file del JSON, relativo allo spazio di lavoro.
# Returns: l'uscita di claude.
chiedi() {
  local domanda f rc=0
  domanda="$(cat "$1/prompt.txt")"
  f="$(immagine "$3")"
  cd "$1/$3"
  handson::claude_p "$2" Read "${domanda//"${SEGNAPOSTO}"/${f}}" \
    --tools Read --effort low --strict-mcp-config --no-session-persistence \
    < /dev/null > "$1/$4" || rc=$?
  cd "$1"
  return "${rc}"
}

# Una chiamata fallita: il verdetto KO e la fine con uscita 1, senza fare
# le chiamate che restano.
fallita() {
  handson::verdict ko "$*"
  handson::finish
}

# verifica.sh con il suo STDOUT sul descrittore 3, che main apre sullo
# STDOUT di live.sh: handson::check mostra l'uscita di un controllo solo
# su un KO, e qui i dati e i verdetti sono la demo anche quando passa.
# Arguments: $1 lo spazio di lavoro. Returns: l'uscita di verifica.sh.
# shellcheck disable=SC2317  # la chiama handson::check, indirettamente
verifica_a_schermo() {
  "${CONTROLLO}" "$1" >&3
}

main() {
  local ws="${1:-}" m n g f rc=0
  [[ -n "${ws}" && -d "${ws}" ]] \
    || handson::die "spazio di lavoro assente: ${ws}"
  cd "${ws}"
  ws="$(pwd -P)"
  handson::need_tools python3 grep
  for f in prompt.txt verita.json allarmi.png allarmi-piccola.png \
      controlla_lettura.py .claude/settings.json; do
    handson::need_file "${f}"
  done
  grep -qF -- "${SEGNAPOSTO}" prompt.txt \
    || handson::die "prompt.txt non nomina l'immagine: manca ${SEGNAPOSTO}"
  handson::need_claude
  handson::banner M3-D01 "Un'immagine leggibile" \
    "Modulo 3, «Chat, file e immagini»: la stessa tabella, grande e piccola"
  prepara_cartelle
  mkdir -p risposte
  for m in "${MODELLI[@]}"; do
    for n in 1 2 3; do
      for g in "${GRANDEZZE[@]}"; do
        handson::step "${m}, coppia ${n}: ${g}/$(immagine "${g}")"
        chiedi "${ws}" "${m}" "${g}" "risposte/${g}-${m}-${n}.json" \
          || fallita "${m}, ${g} ${n}: claude -p è fallito"
      done
    done
  done
  # esiti.tsv, come al passo 4 del README; i dati e i verdetti li mostra
  # una volta sola il controllo qui sotto, e un'uscita 1 la dice lui.
  handson::step "esiti.tsv, come nel README"
  python3 -B -I controlla_lettura.py > /dev/null || rc=$?
  if (( rc >= 2 )); then
    handson::verdict_rc "${rc}" "controlla_lettura.py: le dodici risposte"
  fi
  handson::step "Che cosa ha letto Claude, e le affermazioni di Anthropic"
  exec 3>&1
  handson::check "le dodici risposte, su haiku e su sonnet" \
    verifica_a_schermo "${ws}"
  handson::finish
}

main "$@"
