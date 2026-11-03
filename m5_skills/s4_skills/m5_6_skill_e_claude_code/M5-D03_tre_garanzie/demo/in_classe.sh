#!/bin/bash
#
# in_classe.sh -- la demo M5-D03 «Tre garanzie»: quattro coppie di esecuzioni di
# Claude Code, con il comando sullo schermo prima di ogni chiamata; poi
# controlla_garanzie.py legge gli stream e decide. Le due esecuzioni di una
# coppia differiscono in una cosa sola:
#   codice    !`cat codice.txt` contro `cat codice.txt` nel corpo della skill;
#   comando   !`bash conta.sh` con allowed-tools: Bash(bash conta.sh) e senza;
#   permesso  un corpo che chiede di eseguire bash conta.sh, con il campo (poi,
#             con --resume, il messaggio dopo chiede di rifarlo) e senza;
#   parola    un primo turno dice una parola in codice; poi, con --resume,
#             /prova-parola senza context: fork e con.
# Ogni braccio gira in una copia nuova, in una cartella temporanea (vedi
# lib_coppie.sh). I comandi delle chiamate sono quelli di claude -p: ogni
# chiamata ha il suo stream, e il controllo lo legge.
#
# Uso:    bash in_classe.sh    nello spazio di lavoro di M5-D03
# Env:    PN_ESECUZIONI     quante esecuzioni per braccio, da 1 a 9 (default 1)
#         HANDSON_NO_PAUSE  1 = non aspettare Invio prima di ogni coppia
# Uscita: 0 = ogni garanzia confermata in ogni esecuzione · 1 = una chiamata
#         fallita, una garanzia non confermata, una coppia che non mostra la
#         differenza · 2 = precondizione (claude, git o python3 che mancano, uno
#         spazio di lavoro non preparato o con risposte/ già lì)
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly SPAZIO="${SELF%/*}"
# shellcheck source=lib_coppie.sh
source "${SPAZIO}/lib_coppie.sh"

readonly ELEMENTO=M5-D03
readonly ESECUZIONI="${PN_ESECUZIONI:-1}"
readonly NON_SALVARE=--no-session-persistence
readonly STRUMENTI_FORK='Skill,Agent'
DOPO='Esegui di nuovo bash conta.sh con Bash e riporta il risultato,'
DOPO+=" così com'è."
readonly DOPO
readonly BRACCI=(codice-con codice-senza comando-con comando-senza permesso-con
  permesso-senza parola-inline parola-fork)
PAROLA=''

# Le precondizioni, tutte prima della prima chiamata.
precondizioni() {
  local t f segno
  [[ "${ESECUZIONI}" =~ ^[1-9]$ ]] \
    || coppie::die "PN_ESECUZIONI vuole un numero da 1 a 9, non «${ESECUZIONI}»"
  for t in claude git python3; do
    command -v "${t}" > /dev/null 2>&1 || coppie::die "manca ${t}"
  done
  segno="$(git -C "${SPAZIO}" config --get corso.elemento)" || segno=''
  [[ "${segno}" == "${ELEMENTO}" ]] \
    || coppie::die "${SPAZIO} non è lo spazio di lavoro di ${ELEMENTO}:" \
      "preparatelo con tools/prepara_esercizio.sh ${ELEMENTO}"
  [[ ! -e "${SPAZIO}/risposte" ]] \
    || coppie::die "risposte/ c'è già: per ricominciare," \
      "tools/reset_esercizio.sh ${ELEMENTO}"
  for f in conta.sh elenco.txt controlla_garanzie.py .claude/settings.json; do
    [[ -r "${SPAZIO}/${f}" ]] || coppie::die "manca ${f}"
  done
  for f in "${BRACCI[@]}"; do
    [[ -d "${SPAZIO}/coppie/${f}/.claude/skills" ]] \
      || coppie::die "manca il braccio coppie/${f}/"
  done
}

# La coppia codice: il dato con !, o il comando come testo. Arguments: $1 n.
coppia_codice() {
  local b
  coppie::titolo "codice, esecuzione $1: !\`cat codice.txt\` contro" \
    "\`cat codice.txt\` nel corpo"
  for b in con senza; do
    coppie::nuova_copia "codice-${b}" "${DEPOSITO}/codice.txt"
    coppie::chiedi "${COPIA}" "codice-${b}-$1" '' /prova-codice \
      "${NON_SALVARE}" || coppie::fallita "codice-${b}-$1"
  done
}

# La coppia comando: un ! che non è di sola lettura, con allowed-tools e senza.
# Arguments: $1 n.
coppia_comando() {
  local b
  coppie::titolo "comando, esecuzione $1: !\`bash conta.sh\` con" \
    "allowed-tools e senza"
  for b in con senza; do
    coppie::nuova_copia "comando-${b}" "${SPAZIO}/conta.sh" \
      "${SPAZIO}/elenco.txt"
    coppie::chiedi "${COPIA}" "comando-${b}-$1" '' /prova-conta \
      "${NON_SALVARE}" || coppie::fallita "comando-${b}-$1"
  done
}

# La coppia permesso: il comando chiesto dal corpo, con il campo e senza; con
# il campo, anche il messaggio dopo, nella stessa sessione. Arguments: $1 n.
coppia_permesso() {
  local sessione
  coppie::titolo "permesso, esecuzione $1: allowed-tools nel turno, al" \
    "messaggio dopo, senza il campo"
  coppie::nuova_copia permesso-con "${SPAZIO}/conta.sh" "${SPAZIO}/elenco.txt"
  coppie::chiedi "${COPIA}" "permesso-con-$1" '' /prova-esegui \
    || coppie::fallita "permesso-con-$1"
  sessione="$(python3 -B -I "${SPAZIO}/controlla_garanzie.py" --sessione \
    "${DEPOSITO}/permesso-con-$1.jsonl")" \
    || coppie::fallita "permesso-con-$1, senza un ID di sessione"
  coppie::chiedi "${COPIA}" "permesso-con-$1-dopo" '' "${DOPO}" \
    --resume "${sessione}" || coppie::fallita "permesso-con-$1-dopo"
  coppie::nuova_copia permesso-senza "${SPAZIO}/conta.sh" \
    "${SPAZIO}/elenco.txt"
  coppie::chiedi "${COPIA}" "permesso-senza-$1" '' /prova-esegui \
    || coppie::fallita "permesso-senza-$1"
}

# La coppia parola: la stessa parola in un primo turno, poi /prova-parola con
# --resume, senza context: fork e con. Arguments: $1 n.
coppia_parola() {
  local b sessione
  coppie::titolo "parola, esecuzione $1: /prova-parola senza context: fork" \
    "e con"
  for b in inline fork; do
    coppie::nuova_copia "parola-${b}"
    coppie::chiedi "${COPIA}" "parola-${b}-$1-prima" "${STRUMENTI_FORK}" \
      "Ricorda: la parola in codice è ${PAROLA}. Rispondi solo: ok" \
      || coppie::fallita "parola-${b}-$1-prima"
    sessione="$(python3 -B -I "${SPAZIO}/controlla_garanzie.py" --sessione \
      "${DEPOSITO}/parola-${b}-$1-prima.jsonl")" \
      || coppie::fallita "parola-${b}-$1-prima, senza un ID di sessione"
    coppie::chiedi "${COPIA}" "parola-${b}-$1" "${STRUMENTI_FORK}" \
      /prova-parola --resume "${sessione}" \
      || coppie::fallita "parola-${b}-$1"
  done
}

main() {
  local n
  precondizioni
  coppie::apri_temporanei
  coppie::segreti
  for (( n = 1; n <= ESECUZIONI; n++ )); do
    coppia_codice "${n}"
    coppia_comando "${n}"
    coppia_permesso "${n}"
    coppia_parola "${n}"
  done
  coppie::consegna
  printf '\n--- Il controllo legge gli stream\n\n'
  python3 -B -I "${SPAZIO}/controlla_garanzie.py" "${SPAZIO}"
}

main "$@"
