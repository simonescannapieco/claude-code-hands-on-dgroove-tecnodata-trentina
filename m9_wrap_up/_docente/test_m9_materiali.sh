#!/bin/bash
#
# test_m9_materiali.sh -- le prove dei materiali del Modulo 9, per il docente
# (sta in _docente/, il materiale del docente):
#   - il questionario: i due file sono quelli che genera_questionario.py
#     scrive; il file XML ha la forma che l'importazione di Moodle si aspetta,
#     e ogni guasto si segnala (i casi in lib_m9_materiali.sh);
#   - l'elenco delle risorse: la data e i link;
#   - i README e la guida del docente dicono ciò che devono dire;
#   - il manifest ha la sola intestazione.
#
# Uso:    m9_wrap_up/_docente/test_m9_materiali.sh
# Uscita: 0 = tutti i test passano · 1 = almeno un test fallito
#         2 = precondizione (uno strumento o un materiale mancante, una prova
#             che non si riesce ad allestire)
set -uo pipefail

unset PN_QUESTIONARIO_DIR

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly DOCENTE="${SELF%/*}"
readonly MODULO="${DOCENTE%/*}"
readonly GENERA="${DOCENTE}/genera_questionario.py"
readonly CONTROLLA="${DOCENTE}/controlla_materiali.py"
readonly GUIDA="${DOCENTE}/importare_il_questionario.md"
readonly CARTELLA="${MODULO}/questionario"
readonly XML="${CARTELLA}/questionario-gradimento.xml"
readonly MD="${CARTELLA}/questionario-gradimento.md"
readonly LEGGIMI="${CARTELLA}/README.md"
readonly RISORSE="${MODULO}/risorse.md"
readonly MANIFEST="${MODULO}/manifest.tsv"
INTESTAZIONE=$'id\tkind\tenv\tsection_dir\tsubdeck_dir'
INTESTAZIONE+=$'\tdeck_path\tminutes\ttitle_it'
readonly INTESTAZIONE
readonly DOMANDE=27

TMP="$(mktemp -d)" || { echo "mktemp non riesce" >&2; exit 2; }
readonly TMP
trap 'rm -rf -- "${TMP}"' EXIT
PASS=0
FAIL=0
RC=0
OUT=''

# shellcheck source=lib_m9_materiali.sh
source "${DOCENTE}/lib_m9_materiali.sh" \
  || { echo "lib_m9_materiali.sh illeggibile" >&2; exit 2; }

# Una cartella nuova con i due file appena generati in TMP/gen.
# Globals: TMP. Arguments: $1 il nome della cartella.
copia_generati() {
  cartella "$1"
  cp "${TMP}/gen/"* "${TMP}/$1/" || die "allestimento fallito: $1"
}

# Le prove del generatore, ciascuna in una cartella sua.
prove_generatore() {
  local n="${TMP}/gen"
  run python3 -B -I "${GENERA}" --check
  expect "i due file del repository sono quelli generati" 0 "coerenti"
  cartella gen
  PN_QUESTIONARIO_DIR="${n}" run python3 -B -I "${GENERA}"
  expect "il generatore scrive i due file" 0 "scritti"
  PN_QUESTIONARIO_DIR="${n}" run python3 -B -I "${GENERA}" --check
  expect "subito dopo risultano coerenti" 0 "coerenti"
  copia_generati md
  echo "ritocco" >> "${TMP}/md/questionario-gradimento.md"
  PN_QUESTIONARIO_DIR="${TMP}/md" run python3 -B -I "${GENERA}" --check
  expect "un .md ritoccato si segnala" 1 "DIVERSO"
  copia_generati xml
  echo "<!-- ritocco -->" >> "${TMP}/xml/questionario-gradimento.xml"
  PN_QUESTIONARIO_DIR="${TMP}/xml" run python3 -B -I "${GENERA}" --check
  expect "un .xml ritoccato si segnala" 1 "DIVERSO"
  copia_generati crlf
  sed -i 's/$/\r/' "${TMP}/crlf/questionario-gradimento.md" \
    || die "allestimento fallito: crlf"
  PN_QUESTIONARIO_DIR="${TMP}/crlf" run python3 -B -I "${GENERA}" --check
  expect "un file con i ritorni a capo cambiati si segnala" 1 "DIVERSO"
  copia_generati byte
  printf '\xff\xfe' >> "${TMP}/byte/questionario-gradimento.md" \
    || die "allestimento fallito: byte"
  PN_QUESTIONARIO_DIR="${TMP}/byte" run python3 -B -I "${GENERA}" --check
  expect "un file che non è UTF-8 è una precondizione" 2 "errore"
  PN_QUESTIONARIO_DIR="${TMP}/assente" run python3 -B -I "${GENERA}" --check
  expect "una cartella assente è una precondizione" 2 "errore"
  echo "non sono una cartella" > "${TMP}/file" || die "allestimento: file"
  PN_QUESTIONARIO_DIR="${TMP}/file" run python3 -B -I "${GENERA}"
  expect "non poter scrivere è una precondizione" 2 "errore"
  run python3 -B -I "${GENERA}" --boh
  expect "un argomento sbagliato è una precondizione" 2 "Uso:"
}

# I README, la guida del docente, il manifest.
prove_documenti() {
  run cat "${LEGGIMI}"
  expect "il README del questionario lo presenta" 0 "anonimo"
  expect_absent "e non contiene la procedura del docente" "Import questions"
  expect_absent "né lo stato delle prove" "non è stato provato"
  run cat "${GUIDA}"
  expect "la guida dice il nome dell'attività" 0 "Questionario di gradimento"
  expect "e dove si importa" 0 "**Actions** → **Import questions**"
  expect "e l'anonimato" 0 "Record user names"
  expect "e l'opzione che cancella le risposte" 0 "Delete old items"
  expect "e che cosa controllare" 0 "${DOMANDE} domande"
  expect "e che la prima importazione è la prova" 0 "non è stato provato"
  run cat "${MODULO}/README.md"
  expect "il README del modulo nomina l'elenco" 0 "risorse.md"
  expect "e il questionario" 0 "questionario/"
  run cat "${MANIFEST}"
  if (( RC == 0 )) && [[ "${OUT}" == "${INTESTAZIONE}" ]]; then
    pass "il manifest ha la sola intestazione"
  else
    fail "il manifest non è la sola intestazione (rc=${RC}): ${OUT:0:200}"
  fi
}

main() {
  local attrezzo materiale
  for attrezzo in python3 grep sed cp cat head mktemp; do
    command -v "${attrezzo}" >/dev/null 2>&1 \
      || { echo "${attrezzo} mancante" >&2; exit 2; }
  done
  for materiale in "${GENERA}" "${CONTROLLA}" "${GUIDA}" "${XML}" "${MD}" \
      "${LEGGIMI}" "${RISORSE}" "${MANIFEST}" "${MODULO}/README.md"; do
    [[ -r "${materiale}" ]] \
      || { echo "materiale assente: ${materiale}" >&2; exit 2; }
  done
  prove_generatore
  prove_xml
  prove_risorse
  prove_documenti
  echo "PASS=${PASS} FAIL=${FAIL}"
  (( FAIL == 0 )) || exit 1
}

main "$@"
