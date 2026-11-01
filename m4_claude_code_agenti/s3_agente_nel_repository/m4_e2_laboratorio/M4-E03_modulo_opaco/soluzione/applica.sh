#!/bin/bash
#
# applica.sh di M4-E03 -- applica la soluzione di riferimento a uno spazio di
# lavoro, come se il lavoro fosse finito: copia la documentazione
# (progetti/gestionale-php/docs/chiusura_mese.md), i test di caratterizzazione
# (progetti/gestionale-php/tests/Integrazione/ChiusuraMeseTest.php), la nota
# (NOTA.md) e la proposta (PROPOSTA.md), e fa i commit che i passi del README
# chiedono, uno per file, nel loro ordine (un file già uguale a HEAD non ne
# fa: due applicazioni di seguito danno gli stessi commit); poi, se mancano,
# installa le dipendenze del gestionale con tools/php.sh composer install,
# come dice il «Punto di partenza» del README, così verifica.sh può eseguire
# i test. Non tocca legacy/.
#
# Uso:    soluzione/applica.sh <spazio di lavoro>
# Env:    PN_HANDSON_ROOT  il repository (default: la cartella sopra il
#                          modulo), per tools/php.sh
#         PN_PHP_SH        il php.sh da usare al posto di tools/php.sh
# Uscita: 0 = soluzione applicata · 2 = precondizione (spazio di lavoro o
#         gestionale assenti, uno spazio di lavoro che non è la radice del
#         suo repository git o che è il repository del corso, php.sh
#         mancante, composer install che fallisce, una copia o un commit
#         che non riesce)
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly SOL="${SELF%/*}"
# lo script sta in <radice>/m4_…/s3_…/m4_e2_…/M4-E03_…/soluzione/
readonly RADICE="${PN_HANDSON_ROOT:-${SELF%/*/*/*/*/*/*}}"
readonly PROGETTO=progetti/gestionale-php
# I file, nell'ordine dei passi che ne chiedono il commit (prompt 2, 3, 4 e
# 5 del README), ciascuno con il messaggio del suo commit (regola 11.1).
readonly FILE=("${PROGETTO}/docs/chiusura_mese.md"
  "${PROGETTO}/tests/Integrazione/ChiusuraMeseTest.php" NOTA.md PROPOSTA.md)
readonly MESSAGGI=("docs(chiusura-mese): documenta chiusura_mese()"
  "test(chiusura-mese): fissa il comportamento di chiusura_mese()"
  "docs(nota): riassume la prima parte e come riprendere"
  "docs(proposta): propone il refactoring di chiusura_mese()")
readonly NOME='Corso Claude Code'
readonly EMAIL='corso@example.org'

err() { echo "applica: $*" >&2; }

# Lo spazio di lavoro è la radice del suo repository git, e non il
# repository del corso: i commit della soluzione vanno lì, e soltanto lì.
# Arguments: $1 lo spazio di lavoro.
# Returns: 0; 1, con il motivo su STDERR, altrimenti.
radice_propria() {
  local qui cima corso
  qui="$(cd "$1" && pwd -P)" || return 1
  cima="$(git -C "$1" rev-parse --show-toplevel 2> /dev/null)" || cima=''
  if [[ "${cima}" != "${qui}" ]]; then
    err "$1 non è la radice di un repository git: la soluzione fa i suoi" \
      "commit soltanto in uno spazio di lavoro di tools/prepara_esercizio.sh"
    return 1
  fi
  corso="$(cd "${RADICE}" 2> /dev/null && pwd -P)" || corso=''
  if [[ -n "${corso}" && "${qui}" == "${corso}" ]]; then
    err "$1 è il repository del corso, non uno spazio di lavoro"
    return 1
  fi
}

# Copia i file della soluzione nello spazio di lavoro.
# Arguments: $1 lo spazio di lavoro.
# Returns: 0; 1 se una cartella o una copia non riesce.
copia_i_file() {
  local f
  for f in "${FILE[@]}"; do
    if [[ "${f}" == */* ]] && ! mkdir -p -- "$1/${f%/*}"; then
      return 1
    fi
    cp -- "${SOL}/${f}" "$1/${f}" || return 1
  done
}

# Un commit per file, nell'ordine dei passi, solo se il file cambia HEAD.
# Arguments: $1 lo spazio di lavoro.
# Returns: 0; 1 se git add o git commit non riesce.
fai_i_commit() {
  local i
  for i in "${!FILE[@]}"; do
    git -C "$1" add -- "${FILE[i]}" || return 1
    if ! git -C "$1" diff --cached --quiet -- "${FILE[i]}"; then
      git -C "$1" -c user.name="${NOME}" -c user.email="${EMAIL}" \
        -c commit.gpgsign=false commit -q --no-verify \
        -m "${MESSAGGI[i]}" -- "${FILE[i]}" || return 1
    fi
  done
}

main() {
  local ws="${1:-}" php
  if [[ -z "${ws}" || ! -d "${ws}" ]]; then
    err "spazio di lavoro assente: ${ws}"
    exit 2
  fi
  if ! radice_propria "${ws}"; then
    exit 2
  fi
  if [[ ! -d "${ws}/${PROGETTO}" ]]; then
    err "manca ${PROGETTO} in ${ws}"
    exit 2
  fi
  if ! copia_i_file "${ws}"; then
    err "la copia della soluzione non riesce"
    exit 2
  fi
  if ! fai_i_commit "${ws}"; then
    err "i commit della soluzione non riescono"
    exit 2
  fi
  if [[ -f "${ws}/${PROGETTO}/vendor/bin/phpunit" ]]; then
    exit 0
  fi
  php="${PN_PHP_SH:-${RADICE}/tools/php.sh}"
  if [[ ! -x "${php}" ]]; then
    err "manca tools/php.sh: ${php}"
    exit 2
  fi
  if ! (cd "${ws}" && "${php}" composer install -d "${PROGETTO}" \
      --no-interaction --no-progress); then
    err "composer install non riesce: le dipendenze del gestionale mancano"
    exit 2
  fi
}

main "$@"
