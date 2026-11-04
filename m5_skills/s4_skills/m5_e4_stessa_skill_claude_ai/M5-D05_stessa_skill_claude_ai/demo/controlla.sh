#!/bin/bash
#
# controlla.sh di M5-D05 -- una dimostrazione: tools/controlla_skill.py
# --caricamento sui tre ZIP, aperti in una cartella temporanea. Sul primo
# risponde 0 errori; sul secondo dà l'errore con il messaggio che la pagina di
# Anthropic riporta; sul terzo l'errore sui tag XML. Gli ZIP che sbagliano li
# costruisce la demo, e il controllo applica le regole scritte nelle pagine di
# Anthropic: non è il caricamento. Che cosa fa claude.ai si guarda sullo schermo.
#
# Uso:    ./controlla.sh <cartella degli ZIP>
# Env:    PN_HANDSON_ROOT  il repository (la cartella delle esercitazioni):
#                          obbligatoria, qui lo script è fuori dal repository
# Uscita: 0 = i tre esiti attesi · 1 = uno ZIP che dà un esito diverso · 2 =
#         precondizione (argomenti, PN_HANDSON_ROOT, python3, uno ZIP che manca
#         o non si apre, il controllo che non può leggere)
set -euo pipefail

readonly SKILL=risposta-assistenza
readonly ZIP_BUONO="${SKILL}.zip"
readonly ZIP_SETTIMO="${SKILL}-settimo-campo.zip"
readonly ZIP_XML="${SKILL}-tag-xml.zip"
MESSAGGIO='Unexpected key(s) in SKILL.md frontmatter: argument-hint.'
readonly MESSAGGIO
readonly ERRORE_XML='ERRORE description: niente tag XML'
TEMPORANEA=''

err() { echo "controlla.sh: $*" >&2; }

# Toglie la cartella temporanea. Globals: TEMPORANEA.
pulisci() {
  if [[ -n "${TEMPORANEA}" && -d "${TEMPORANEA}" ]]; then
    rm -rf -- "${TEMPORANEA}"
  fi
}

# Apre uno ZIP e vi fa girare il controllo: l'esito su STDOUT.
# Globals: TEMPORANEA, PN_HANDSON_ROOT. Arguments: $1 lo ZIP, $2 una cartella
# nuova. Returns: l'uscita del controllo; 3 se lo ZIP non si apre.
esamina() {
  mkdir -- "${TEMPORANEA}/$2" || return 3
  python3 -B -I -m zipfile -e "$1" "${TEMPORANEA}/$2" > /dev/null 2>&1 \
    || return 3
  python3 -B -I "${PN_HANDSON_ROOT}/tools/controlla_skill.py" --caricamento \
    "${TEMPORANEA}/$2/${SKILL}"
}

# Uno ZIP, con il suo esito atteso: stampa ciò che il controllo dice.
# Arguments: $1 il percorso, $2 una cartella nuova, $3 l'uscita attesa, $4 la
# parola attesa. Returns: 0 se torna; 1 se no; esce 2 se non può leggerlo.
uno_zip() {
  local esito rc=0
  [[ -f "$1" ]] || { err "manca $1: ./impacchetta.sh <cartella>"; exit 2; }
  printf '\n--- %s\n' "${1##*/}"
  esito="$(esamina "$1" "$2")" || rc=$?
  if (( rc >= 2 )); then
    err "${1##*/} non si legge (uscita ${rc})"
    exit 2
  fi
  printf '%s\n' "${esito}"
  if (( rc == $3 )) && grep -qF -- "$4" <<< "${esito}"; then
    return 0
  fi
  printf 'NON TORNA: atteso uscita %d e «%s»\n' "$3" "$4"
  return 1
}

main() {
  local cartella="${1:-}" problemi=0
  if (( $# != 1 )) || [[ -z "${cartella}" ]]; then
    echo "Uso: ./controlla.sh <cartella degli ZIP>" >&2
    exit 2
  fi
  command -v python3 > /dev/null 2>&1 || { err "manca python3"; exit 2; }
  if [[ -z "${PN_HANDSON_ROOT:-}" \
      || ! -f "${PN_HANDSON_ROOT}/tools/controlla_skill.py" ]]; then
    err "PN_HANDSON_ROOT deve essere la cartella delle esercitazioni:" \
      "export PN_HANDSON_ROOT=<la cartella>"
    exit 2
  fi
  TEMPORANEA="$(mktemp -d)" || { err "mktemp non riesce"; exit 2; }
  trap pulisci EXIT
  uno_zip "${cartella}/${ZIP_BUONO}" primo 0 "${SKILL}: 0 errori" \
    || problemi=$((problemi + 1))
  uno_zip "${cartella}/${ZIP_SETTIMO}" secondo 1 "${MESSAGGIO}" \
    || problemi=$((problemi + 1))
  uno_zip "${cartella}/${ZIP_XML}" terzo 1 "${ERRORE_XML}" \
    || problemi=$((problemi + 1))
  printf '\nUna dimostrazione: gli ZIP che sbagliano li costruisce la demo, e'
  printf ' il controllo\napplica le regole delle pagine di Anthropic, non è il'
  printf ' caricamento. Che cosa fa\nil caricamento si guarda su claude.ai.'
  printf ' L'\''avviso su evals/ è atteso: le prove\nrestano fuori dallo ZIP.\n'
  (( problemi == 0 )) || exit 1
}

main "$@"
