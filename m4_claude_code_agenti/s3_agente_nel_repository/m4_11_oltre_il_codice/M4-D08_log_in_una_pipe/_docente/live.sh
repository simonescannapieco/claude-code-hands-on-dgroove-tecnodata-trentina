#!/bin/bash
#
# live.sh di M4-D08 -- la demo del docente: il log in una pipe. Lo stesso
# comando, claude -p con la stessa domanda (domanda.txt: gli orari del
# guasto di martedì 8 settembre su olt-pergine-01) e senza strumenti
# (--tools ""), riceve in pipe due ingressi: le righe di olt-pergine-01 nel
# syslog della settimana (olt-pergine-01.log, poche decine di KB) e il
# syslog della settimana ripetuto finché supera i 12 MiB (grande.log, oltre
# il tetto di 10 MB in entrambe le letture). Sonnet, effort low, senza
# server MCP, senza salvare la sessione, --output-format json; più
# --permission-mode dontAsk, --permission-prompts none e --setting-sources
# project,local, come li mette handson::claude_p, e senza ANTHROPIC_API_KEY
# nell'ambiente. La pipe sta in _docente/lib_pipe.sh: la riga di claude si
# compone come in handson::claude_p, dopo gli stessi controlli, e si vede
# com'è, con la pipe davanti, prima di girare. Di ogni braccio restano in
# pipe/ lo STDOUT, lo STDERR, il codice d'uscita di claude e i byte
# passati: un'uscita diversa da zero non ferma la demo, la decide il
# controllo. Sono i passi 2 e 3 del README. Poi verifica.sh dice se la
# prova conferma la garanzia di Anthropic sul tetto e stampa gli orari
# della risposta contro la verità: i suoi dati e il suo verdetto si vedono
# anche quando passa. grande.log resta nello spazio di lavoro, che sta
# fuori dal repository.
#
# Uso:    _docente/live.sh <spazio di lavoro>
# Env:    le variabili di tools/lib_handson.sh (HANDSON_NO_PAUSE, …)
# Uscita: 0 = i due bracci ci sono, il filtrato è riuscito e la garanzia è
#         confermata · 1 = un braccio che non va, o la garanzia non
#         confermata · 2 = precondizione
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
# lo script sta in <radice>/m4_…/s3_…/m4_11_…/M4-D08_…/_docente/
readonly RADICE="${SELF%/*/*/*/*/*/*}"
readonly CONTROLLO="${SELF%/_docente/*}/verifica.sh"
# shellcheck source=../../../../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"
# shellcheck source=lib_pipe.sh
source "${SELF%/*}/lib_pipe.sh"

readonly APPARATO=olt-pergine-01
readonly SYSLOG=progetti/rete/log/syslog
readonly FILTRATO=olt-pergine-01.log
readonly GRANDE=grande.log
# Il file grande supera 12 MiB: oltre i 10 MB del tetto, letti come
# 10.000.000 o come 10.485.760 byte.
readonly SOGLIA=$((12 * 1024 * 1024))

# verifica.sh con il suo STDOUT sul descrittore 3, che main apre sullo
# STDOUT di live.sh: handson::check mostra l'uscita di un controllo solo
# su un KO, e qui i dati e il verdetto sono la demo anche quando passa.
# Arguments: $1 lo spazio di lavoro. Returns: l'uscita di verifica.sh.
# shellcheck disable=SC2317  # la chiama handson::check, indirettamente
verifica_a_schermo() {
  "${CONTROLLO}" "$1" >&3
}

# I due ingressi: le righe dell'apparato e il syslog ripetuto oltre la
# soglia. Arguments: i file del syslog della settimana, in ordine.
ingressi() {
  local dim n i ciclo
  handson::step "Le righe di ${APPARATO} nel syslog della settimana"
  pipe::mostra_riga "grep -h ${APPARATO} ${SYSLOG}/syslog_*.log > ${FILTRATO}"
  if ! grep -h -- "${APPARATO}" "$@" > "${FILTRATO}"; then
    handson::die "nessuna riga di ${APPARATO} in ${SYSLOG}/"
  fi
  dim="$(cat -- "$@" | wc -c)"
  if (( dim == 0 )); then
    handson::die "il syslog della settimana in ${SYSLOG}/ è vuoto"
  fi
  n=$(( SOGLIA / dim + 1 ))
  handson::step "Il syslog della settimana ripetuto ${n} volte, oltre" \
    "i 12 MiB"
  ciclo="for i in \$(seq ${n}); do cat ${SYSLOG}/syslog_*.log; done"
  pipe::mostra_riga "${ciclo} > ${GRANDE}"
  for (( i = 0; i < n; i++ )); do
    cat -- "$@"
  done > "${GRANDE}"
  handson::run wc -c "${FILTRATO}" "${GRANDE}"
}

main() {
  local ws="${1:-}" domanda
  local -a giorni=()
  [[ -n "${ws}" && -d "${ws}" ]] \
    || handson::die "spazio di lavoro assente: ${ws}"
  cd "${ws}"
  ws="$(pwd -P)"
  handson::need_tools python3 grep cat wc mkdir
  handson::need_file domanda.txt
  giorni=("${SYSLOG}"/syslog_*.log)
  [[ -f "${giorni[0]}" ]] \
    || handson::die "mancano i file del syslog in ${SYSLOG}/:" \
      "tools/reset_esercizio.sh M4-D08 rifà lo spazio di lavoro"
  domanda="$(< domanda.txt)"
  pipe::controlli "${domanda}"
  handson::need_claude
  handson::banner M4-D08 "Il log in una pipe" \
    "Modulo 4, «Oltre il codice»: lo stesso comando, due ingressi"
  ingressi "${giorni[@]}"
  mkdir -p pipe
  handson::step "Primo braccio: le righe di ${APPARATO}, sotto il tetto"
  pipe::braccio filtrato "${FILTRATO}" "${domanda}"
  handson::step "Secondo braccio: lo stesso comando, con il file grande"
  pipe::braccio grande "${GRANDE}" "${domanda}"
  handson::step "Che cosa garantisce Anthropic, e che cosa dice la prova"
  exec 3>&1
  handson::check "i due bracci" verifica_a_schermo "${ws}"
  handson::finish
}

main "$@"
