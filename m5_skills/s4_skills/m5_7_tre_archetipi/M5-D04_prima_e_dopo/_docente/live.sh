#!/bin/bash
#
# live.sh di M5-D04 -- le esecuzioni del docente. Il set principale: tre
# archetipi, ognuno con le sue due cartelle dello spazio di lavoro, tre coppie
# ciascuno (PN_COPPIE), dalla cartella con la skill e da quella senza, con lo
# stesso comando: diciotto sessioni nuove di `claude -p` su Sonnet. Poi, una per
# archetipo, la cartella con la skill e la skill spenta con --settings: altre
# tre, la garanzia di off. Ventuno. Il set modelli: le tre richieste, una volta
# ciascuna con la skill accesa, su Haiku e su Opus: sei sessioni, in
# risposte-modelli/, stampate come dati.
#
# Ogni chiamata: --effort low, --strict-mcp-config, --no-session-persistence,
# gli strumenti Read e Skill(<skill>), in tutti i bracci; handson::claude_p
# aggiunge dontAsk, --permission-prompts none e --setting-sources project,local.
# Gli stream restano in una cartella temporanea finché l'ultima sessione non è
# finita; una chiamata fallita ferma il set, e ciò che c'è va nello spazio di
# lavoro. Poi il controllo dice i dati e i verdetti, che si vedono anche quando
# passa.
#
# Uso:    _docente/live.sh <spazio di lavoro> [modelli]
#         uno spazio di lavoro nuovo per ogni set (prepara_esercizio.sh con
#         --radice diverse), con git status vuoto: le sessioni non hanno vicino
#         lo stream di un'altra, e le richieste sono quelle del README
# Env:    PN_COPPIE  le coppie per archetipo nel set principale, da 1 a 9
#                    (default 3); le variabili di tools/lib_handson.sh
# Uscita: 0 = gli stream si leggono e le garanzie tengono (il confronto non
#         decide) · 1 = una chiamata fallita, uno stream che non va, una
#         garanzia che non regge · 2 = precondizione
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
# lo script sta in <radice>/m5_skills/s4_skills/m5_7_…/M5-D04_…/_docente/
readonly RADICE="${SELF%/*/*/*/*/*/*}"
readonly ELEMENTO="${SELF%/_docente/*}"
# shellcheck source=../../../../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"
# shellcheck source=../demo/lib_archetipi.sh
source "${ELEMENTO}/demo/lib_archetipi.sh"

readonly MODELLO=sonnet
readonly MODELLI_DEL_SET=(haiku opus)
COPPIE="${PN_COPPIE:-3}"
WS=''
DEPOSITO=''
DESTINAZIONE=''
INSIEME=principale

# Una chiamata fallita: ciò che c'è va nello spazio di lavoro, poi il verdetto
# KO e la fine con uscita 1, senza fare le chiamate che restano.
fallita() {
  archetipi::consegna "${DEPOSITO}" "${WS}/${DESTINAZIONE}"
  handson::verdict ko "$*"
  handson::finish
}

# Le coppie del set principale. Globals: WS, DEPOSITO, COPPIE.
set_coppie() {
  local archetipo richiesta n braccio
  for archetipo in "${ARCHETIPI_ELENCO[@]}"; do
    richiesta="$(archetipi::richiesta "${WS}/richieste.tsv" "${archetipo}")"
    archetipi::prepara "${WS}" "${archetipo}"
    for (( n = 1; n <= COPPIE; n++ )); do
      for braccio in on senza; do
        handson::step "${archetipo}, coppia ${n}: ${braccio}"
        archetipi::esegui "${WS}" "${archetipo}" "${MODELLO}" "${braccio}" \
          "${richiesta}" "${DEPOSITO}/${archetipo}-${braccio}-${n}.jsonl" \
          || fallita "${archetipo}-${braccio}-${n}: claude -p è fallito"
      done
    done
  done
}

# La garanzia di off: un'esecuzione per archetipo, dalla cartella con la skill.
# Globals: WS, DEPOSITO.
set_off() {
  local archetipo richiesta
  for archetipo in "${ARCHETIPI_ELENCO[@]}"; do
    richiesta="$(archetipi::richiesta "${WS}/richieste.tsv" "${archetipo}")"
    archetipi::prepara "${WS}" "${archetipo}"
    handson::step "${archetipo}: la skill spenta per questa esecuzione"
    archetipi::esegui "${WS}" "${archetipo}" "${MODELLO}" off "${richiesta}" \
      "${DEPOSITO}/${archetipo}-off-1.jsonl" \
      || fallita "${archetipo}-off-1: claude -p è fallito"
  done
}

# Il set dei modelli. Globals: WS, DEPOSITO.
set_modelli() {
  local archetipo richiesta modello
  for archetipo in "${ARCHETIPI_ELENCO[@]}"; do
    richiesta="$(archetipi::richiesta "${WS}/richieste.tsv" "${archetipo}")"
    archetipi::prepara "${WS}" "${archetipo}"
    for modello in "${MODELLI_DEL_SET[@]}"; do
      handson::step "${archetipo}, ${modello}: la skill accesa"
      archetipi::esegui "${WS}" "${archetipo}" "${modello}" on \
        "${richiesta}" "${DEPOSITO}/${archetipo}-${modello}.jsonl" \
        || fallita "${archetipo}-${modello}: claude -p è fallito"
    done
  done
}

# Il controllo con il suo STDOUT sul descrittore 3, che main apre sullo STDOUT
# di live.sh: handson::check mostra un controllo solo su un KO, e qui i dati e i
# verdetti sono la demo anche quando passa. Returns: l'uscita del controllo.
# shellcheck disable=SC2317  # la chiama handson::check, indirettamente
controllo_a_schermo() {
  if [[ "${INSIEME}" == modelli ]]; then
    PN_HANDSON_ROOT="${HANDSON_ROOT}" python3 -B -I \
      "${ELEMENTO}/demo/controlla_archetipi.py" --modelli \
      --verita "${ELEMENTO}/verita.json" "${WS}/${DESTINAZIONE}" >&3
  else
    PN_HANDSON_ROOT="${HANDSON_ROOT}" "${ELEMENTO}/verifica.sh" "${WS}" >&3
  fi
}

# Gli argomenti. Globals: WS, INSIEME, DESTINAZIONE (assegnate).
leggi_argomenti() {
  if (( $# < 1 || $# > 2 )); then
    echo "uso: _docente/live.sh <spazio di lavoro> [modelli]" >&2
    exit 2
  fi
  WS="$1"
  [[ -n "${WS}" && -d "${WS}" ]] \
    || handson::die "spazio di lavoro assente: ${WS}"
  WS="$(cd -- "${WS}" && pwd -P)" \
    || handson::die "lo spazio di lavoro non si apre"
  case "${2:-}" in
    '') DESTINAZIONE=risposte ;;
    modelli) INSIEME=modelli; DESTINAZIONE=risposte-modelli ;;
    *) handson::die "set sconosciuto: «$2» (nessuno, oppure modelli)" ;;
  esac
}

# Le precondizioni, prima di ogni chiamata. Globals: WS, COPPIE, DESTINAZIONE.
precondizioni() {
  local f archetipo richiesta stato
  archetipi::precondizioni "${WS}"
  for f in "${ELEMENTO}/verifica.sh" "${ELEMENTO}/verita.json" \
      "${ELEMENTO}/demo/controlla_archetipi.py"; do
    handson::need_file "${f}"
  done
  [[ "${COPPIE}" =~ ^[1-9]$ ]] \
    || handson::die "PN_COPPIE vuole un numero da 1 a 9, non «${COPPIE}»"
  for f in risposte risposte-modelli; do
    [[ ! -e "${WS}/${f}" ]] \
      || handson::die "${WS}/${f}/ c'è già: ogni set vuole uno spazio di" \
        "lavoro nuovo, così le sessioni non hanno vicino uno stream di prima"
  done
  stato="$(git -C "${WS}" status --porcelain)" \
    || handson::die "git status non riesce in ${WS}"
  [[ -z "${stato}" ]] \
    || handson::die "lo spazio di lavoro non è al punto di partenza (git" \
      "status non è vuoto): tools/reset_esercizio.sh M5-D04"
  for archetipo in "${ARCHETIPI_ELENCO[@]}"; do
    richiesta="$(archetipi::richiesta "${WS}/richieste.tsv" "${archetipo}")"
    handson::_claude_p_checks "${MODELLO}" "${richiesta}"
    handson::_claude_key_ok "${richiesta}"
  done
  handson::need_claude
}

main() {
  leggi_argomenti "$@"
  handson::init_root || exit 2
  precondizioni
  handson::banner M5-D04 "Prima e dopo, tre archetipi" \
    "Modulo 5, le esecuzioni del docente: il set ${INSIEME}"
  handson::tmpdir DEPOSITO
  if [[ "${INSIEME}" == modelli ]]; then
    set_modelli
  else
    set_coppie
    set_off
  fi
  handson::step "Gli stream nello spazio di lavoro, a sessioni finite"
  archetipi::consegna "${DEPOSITO}" "${WS}/${DESTINAZIONE}"
  handson::step "Che cosa dicono le esecuzioni"
  exec 3>&1
  handson::check "le esecuzioni, lette dagli stream" controllo_a_schermo
  handson::finish
}

main "$@"
