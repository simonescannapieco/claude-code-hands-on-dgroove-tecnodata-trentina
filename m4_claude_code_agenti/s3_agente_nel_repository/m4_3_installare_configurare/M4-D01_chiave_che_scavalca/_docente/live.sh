#!/bin/bash
#
# live.sh di M4-D01 -- la demo del docente: la chiave che scavalca il Pro.
# Due esecuzioni di claude auth status --json e nessuna chiamata al
# modello: la prima senza ANTHROPIC_API_KEY (env -u la toglie, anche se il
# terminale ne avesse una), la seconda con la chiave finta del corso,
# finta-chiave-del-corso, impostata per quel solo comando (env
# NOME=valore: mai esportata, mai scritta in un file). Differiscono
# soltanto nella chiave. L'uscita di ciascuna passa da
# controlla_accesso.py --salva, che tiene soltanto loggedIn, authMethod e
# apiKeySource: l'e-mail e l'organizzazione dell'account non arrivano né a
# schermo né nei file (stato/senza.json, stato/con.json). Sono i comandi
# del passo 3 del README. Il comando di ciascuna esecuzione si vede prima
# di girare (handson::run); la parte dopo la pipe è sempre --salva. Poi
# verifica.sh dice se la prova conferma la garanzia di Anthropic: i suoi
# dati e il suo verdetto si vedono anche quando passa.
#
# Uso:    _docente/live.sh <spazio di lavoro>
# Env:    le variabili di tools/lib_handson.sh (HANDSON_NO_PAUSE, …)
# Uscita: 0 = la garanzia confermata · 1 = non confermata in questa
#         esecuzione · 2 = precondizione (anche un'uscita di claude auth
#         status che non è JSON, o senza la chiave un accesso che non è
#         l'abbonamento)
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
# lo script sta in <radice>/m4_…/s3_…/m4_3_…/M4-D01_…/_docente/
readonly RADICE="${SELF%/*/*/*/*/*/*}"
readonly CONTROLLO="${SELF%/_docente/*}/verifica.sh"
# shellcheck source=../../../../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"

readonly CHIAVE_FINTA=finta-chiave-del-corso

# Un'esecuzione di claude auth status --json, salvata da --salva nel file
# stato/<quale>.json. Un'uscita 1 di claude (l'accesso non c'è) non ferma
# la demo: il JSON c'è, e decide il controllo; un'uscita che --salva non
# accetta la ferma, con 2.
# Arguments: $1 senza o con, poi il comando.
stato() {
  local file="stato/$1.json"
  local -a st=()
  shift
  if handson::run "$@" | python3 -B -I controlla_accesso.py --salva "${file}"
  then
    return 0
  else
    st=("${PIPESTATUS[@]}")
  fi
  if (( st[1] != 0 )); then
    handson::die "l'uscita di claude auth status non si è potuta salvare" \
      "in ${file} (vedi sopra)"
  fi
  handson::note "claude auth status è uscito con ${st[0]}: decide il" \
    "controllo"
}

# verifica.sh con il suo STDOUT sul descrittore 3, che main apre sullo
# STDOUT di live.sh: handson::check mostra l'uscita di un controllo solo
# su un KO, e qui i dati e il verdetto sono la demo anche quando passa.
# Arguments: $1 lo spazio di lavoro. Returns: l'uscita di verifica.sh.
# shellcheck disable=SC2317  # la chiama handson::check, indirettamente
verifica_a_schermo() {
  "${CONTROLLO}" "$1" >&3
}

main() {
  local ws="${1:-}"
  [[ -n "${ws}" && -d "${ws}" ]] \
    || handson::die "spazio di lavoro assente: ${ws}"
  cd "${ws}"
  ws="$(pwd -P)"
  handson::need_tools python3 env
  handson::need_file controlla_accesso.py
  handson::need_claude
  handson::banner M4-D01 "La chiave che scavalca il Pro" \
    "Modulo 4, «Installare e configurare»: senza e con ANTHROPIC_API_KEY"
  handson::step "Senza ANTHROPIC_API_KEY"
  stato senza env -u ANTHROPIC_API_KEY claude auth status --json
  handson::step "Con ANTHROPIC_API_KEY per questo comando soltanto: una" \
    "chiave finta"
  stato con env "ANTHROPIC_API_KEY=${CHIAVE_FINTA}" claude auth status --json
  handson::step "Che cosa garantisce Anthropic, e che cosa dice la prova"
  exec 3>&1
  handson::check "le due esecuzioni di claude auth status" \
    verifica_a_schermo "${ws}"
  handson::finish
}

main "$@"
