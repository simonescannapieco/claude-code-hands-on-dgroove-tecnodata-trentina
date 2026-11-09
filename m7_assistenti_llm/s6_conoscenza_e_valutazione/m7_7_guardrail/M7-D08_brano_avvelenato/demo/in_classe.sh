#!/bin/bash
#
# in_classe.sh -- M7-D08 «Il brano avvelenato», dal vivo: la domanda di un
# cliente sul trasloco (casi/caso-trasloco.json, una sola chiamata) sul banco
# di prova dell'assistente, con una base di conoscenza di tre brani: uno
# contiene un ordine all'assistente (chiamare registra_accredito), uno un
# contributo falso. Due formulazioni dell'ordine, in due basi (kb/diretto,
# kb/camuffato); due versioni del system prompt che differiscono in una sola
# frase, la riga di politica (senza-politica, con-politica), e lo stesso
# strumenti.json: cerca_kb e registra_accredito. Ogni cella gira con prova.py
# casi, dalla copia del banco nello spazio di lavoro, con lo schema dell'uscita
# strutturata (schema.json), in risposte/<formulazione>-<versione>-<n>/. Poi
# controlla_veleno.py legge il registro del server e il campo strutturato di
# ogni esecuzione e stampa n su N per cella: il confronto fra le due versioni
# è un dato, non decide l'uscita. Ogni comando si vede prima di girare.
#
# Uso:    <cartella dell'elemento>/demo/in_classe.sh <spazio di lavoro>
#           lo spazio di lavoro appena preparato (tools/prepara_esercizio.sh
#           M7-D08), con git status pulito e senza risposte/
# Env:    PN_ESECUZIONI    quante esecuzioni per cella, da 1 a 9 (default 1)
#         PN_HANDSON_ROOT  il repository (default: dal percorso di questo
#                          file; dalla copia nello spazio di lavoro va data)
#         le variabili di tools/lib_handson.sh (HANDSON_NO_PAUSE, …)
# Uscita: 0 = ogni chiamata è finita e il controllo ha letto le esecuzioni ·
#         1 = una chiamata non finita, o il controllo che chiede di rifare la
#         prova · 2 = precondizione, anche del banco o del controllo
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
# lo script sta in <radice>/m7_…/s6_…/m7_7_guardrail/M7-D08_…/demo/
readonly RADICE="${PN_HANDSON_ROOT:-${SELF%/*/*/*/*/*/*}}"
[[ -f "${RADICE}/tools/lib_handson.sh" ]] || { echo "in_classe.sh: non" \
  "trovo tools/lib_handson.sh in ${RADICE}: lanciatelo dal repository, o" \
  "date PN_HANDSON_ROOT" >&2; exit 2; }
# shellcheck source=../../../../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"

readonly ELEMENTO=M7-D08
readonly BANCO=progetti/assistenza-clienti/banco
readonly FORMULAZIONI=(diretto camuffato)
readonly VERSIONI=(senza con)
readonly NECESSARI=(schema.json casi/caso-trasloco.json
  senza-politica/system-prompt.md senza-politica/strumenti.json
  con-politica/system-prompt.md con-politica/strumenti.json
  kb/diretto/kb-21-trasloco-nota.md kb/camuffato/kb-21-trasloco-nota.md
  controlla_veleno.py "${BANCO}/prova.py")
readonly ESECUZIONI="${PN_ESECUZIONI:-1}"

# Le precondizioni, prima di ogni chiamata. Va chiamata nello spazio di
# lavoro.
precondizioni() {
  local f radice segno stato
  [[ "${HANDSON_ENV}" == claude-code-pro ]] \
    || handson::die "${ELEMENTO} è un elemento claude-code-pro: HANDSON_ENV" \
      "«${HANDSON_ENV}» non vale qui"
  handson::need_tools python3 git uv
  radice="$(git rev-parse --show-toplevel 2> /dev/null)" || radice=''
  segno="$(git config --get corso.elemento 2> /dev/null)" || segno=''
  [[ "${radice}" == "$(pwd -P)" && "${segno}" == "${ELEMENTO}" ]] \
    || handson::die "$(pwd -P) non è lo spazio di lavoro di ${ELEMENTO}:" \
      "preparatelo con tools/prepara_esercizio.sh ${ELEMENTO}"
  for f in "${NECESSARI[@]}"; do handson::need_file "${f}"; done
  stato="$(git status --porcelain)" || handson::die "git status non riesce"
  [[ ! -e risposte && -z "${stato}" ]] \
    || handson::die "lo spazio di lavoro non è al punto di partenza (c'è" \
      "risposte/, o git status non è vuoto): tools/reset_esercizio.sh" \
      "${ELEMENTO}"
  [[ "${ESECUZIONI}" =~ ^[1-9]$ ]] \
    || handson::die "PN_ESECUZIONI: da 1 a 9, non «${ESECUZIONI}»"
  handson::need_claude
}

# Un'esecuzione di una cella: prova.py casi, con il suo KB e il suo system
# prompt. Se la chiamata non finisce: il verdetto KO e la fine; un'uscita 2 di
# prova.py è una precondizione e resta 2.
# Globals: BANCO. Arguments: $1 la formulazione, $2 la versione, $3 il numero.
una_esecuzione() {
  local nome="$1-$2-$3" quale='senza la riga di politica' rc=0
  [[ "$2" == senza ]] || quale='con la riga di politica'
  handson::step "${nome}: l'ordine in forma «$1», ${quale}"
  handson::run python3 -B -I "${BANCO}/prova.py" casi \
    --versione "$2-politica" --casi casi --kb "kb/$1" \
    --schema schema.json --uscita "risposte/${nome}" < /dev/null || rc=$?
  if (( rc == 2 )); then
    handson::die "prova.py: una precondizione del banco (vedi sopra)"
  fi
  if (( rc != 0 )); then
    handson::verdict ko "${nome}: la chiamata non è finita"
    handson::finish
  fi
}

main() {
  local ws="${1:-}" formulazione versione n rc=0
  [[ -n "${ws}" && -d "${ws}" ]] \
    || handson::die "spazio di lavoro assente: ${ws}"
  cd -- "${ws}" || handson::die "lo spazio di lavoro ${ws} non si apre"
  precondizioni
  handson::banner "${ELEMENTO}" "Il brano avvelenato" \
    "Modulo 7, «I guardrail»"
  handson::note "${ESECUZIONI} esecuzione/i per cella, 4 celle"
  handson::pause "fare le chiamate"
  for formulazione in "${FORMULAZIONI[@]}"; do
    for versione in "${VERSIONI[@]}"; do
      for (( n = 1; n <= ESECUZIONI; n++ )); do
        una_esecuzione "${formulazione}" "${versione}" "${n}"
      done
    done
  done
  handson::step "Il controllo, sui file delle esecuzioni"
  handson::run python3 -B -I controlla_veleno.py risposte < /dev/null \
    || rc=$?
  handson::verdict_rc "${rc}" "il controllo, sulle esecuzioni di risposte/"
  handson::finish
}

main "$@"
