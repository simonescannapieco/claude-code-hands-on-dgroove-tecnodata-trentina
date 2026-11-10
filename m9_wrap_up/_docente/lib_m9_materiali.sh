# shellcheck shell=bash
#
# lib_m9_materiali.sh -- l'imbragatura delle prove del Modulo 9 e i casi di
# controlla_materiali.py (il questionario e l'elenco), per
# test_m9_materiali.sh (sourced, non eseguibile).
# Le righe della tabella dei casi superano le 80 colonne: sono dati di un
# here-doc, che spezzati non si leggerebbero più (RU-01.14).

# L'allestimento di una prova non riesce: uscita 2, mai un FAIL per il motivo
# sbagliato (RU-01.3).
# Arguments: $* il messaggio. Outputs: STDERR. Returns: non torna, exit 2.
die() { echo "$*" >&2; exit 2; }

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

# Esegue un comando, per expect ed expect_absent.
# Globals: OUT (STDOUT e STDERR insieme), RC. Arguments: il comando.
run() { OUT="$("$@" 2>&1)"; RC=$?; }

# Uscita attesa E parola attesa (RU-01.T3); un Traceback non è mai l'esito
# atteso, anche quando contiene la parola.
# Globals: RC, OUT. Arguments: $1 il nome, $2 l'uscita, $3 la parola (grep -F).
expect() {
  if (( RC == $2 )) && grep -qF -- "$3" <<< "${OUT}" \
      && ! grep -qF -- "Traceback" <<< "${OUT}"; then
    pass "$1"
  else
    fail "$1 (rc=${RC}, attesa $2, parola «$3»): ${OUT:0:300}"
  fi
}

# Nessun falso positivo: la parola non c'è, e grep ha potuto dirlo (RU-01.T5).
# Globals: OUT. Arguments: $1 il nome, $2 la parola (grep -F).
expect_absent() {
  local esito=0
  grep -qF -- "$2" <<< "${OUT}" || esito=$?
  case "${esito}" in
    0) fail "$1: «$2» c'è" ;;
    1) pass "$1" ;;
    *) fail "$1: grep non ha potuto cercare «$2» (rc=${esito})" ;;
  esac
}

# Una cartella nuova per ogni prova (RU-01.T2).
# Globals: TMP. Arguments: $1 il nome. Outputs: nessuno; la crea in TMP.
cartella() { mkdir -p "${TMP}/$1" || die "non riesco a creare ${TMP}/$1"; }

# Una copia del file XML con un testo cambiato: sempre una copia vera, e se il
# testo non c'è l'allestimento si ferma.
# Globals: TMP.
# Arguments: $1 il file di partenza, $2 il nome della copia, $3 il testo da
#            cercare, $4 quello nuovo, $5 "tutte" per cambiarle tutte.
copia_xml() {
  python3 -B -I - "$1" "${TMP}/$2.xml" "$3" "$4" "${5:-una}" <<'PY' \
    || die "allestimento fallito: copia $2"
import sys
sorgente, copia, vecchio, nuovo, quante = sys.argv[1:6]
with open(sorgente, encoding="utf-8", newline="") as ingresso:
    testo = ingresso.read()
if vecchio not in testo:
    sys.exit("la copia non cambia: testo non trovato: " + vecchio)
volte = -1 if quante == "tutte" else 1
with open(copia, "w", encoding="utf-8", newline="") as uscita:
    uscita.write(testo.replace(vecchio, nuovo, volte))
PY
}

# Una copia del file XML senza nessuna domanda: solo le etichette.
# Globals: TMP, XML. Arguments: $1 il nome della copia.
copia_senza_domande() {
  python3 -B -I - "${XML}" "${TMP}/$1.xml" <<'PY' \
    || die "allestimento fallito: copia $1"
import re
import sys
sorgente, copia = sys.argv[1:3]
with open(sorgente, encoding="utf-8", newline="") as ingresso:
    testo = ingresso.read()
domande = re.compile(r' *<ITEM TYPE="(?!label).*?</ITEM>\n', re.S)
with open(copia, "w", encoding="utf-8", newline="") as uscita:
    uscita.write(domande.sub("", testo))
PY
}

# I casi di guasto, uno per regola di controlla_materiali.py:
# nome ~ testo cercato ~ testo nuovo ~ uscita ~ parola ~ una|tutte
# VUOTO sta per «nessun testo».
casi_xml() {
  cat <<'CASI'
spazio del prologo~UTF-8" ?>~UTF-8"?>~1~non riconosce~una
apici del prologo~encoding="UTF-8" ?>~encoding='UTF-8' ?>~1~non riconosce~una
codifica del prologo~encoding="UTF-8"~encoding="ISO-8859-1"~1~deve essere UTF-8~una
codifica inesistente~encoding="UTF-8"~encoding="pippo"~1~deve essere UTF-8~una
versione del file~VERSION="200701"~VERSION="200801"~1~VERSION deve essere~una
radice~FEEDBACK~FEEDBACC~1~la radice~tutte
blocco ITEMS~ITEMS~ITEMZ~1~nessun ITEM~tutte
tipo sconosciuto~TYPE="textarea"~TYPE="pippo"~1~tipo sconosciuto~una
REQUIRED~REQUIRED="1"~REQUIRED="2"~1~REQUIRED deve essere~una
ITEMID non numerico~<![CDATA[1]]>~<![CDATA[uno]]>~1~ITEMID~una
ITEMID ripetuto~<![CDATA[2]]>~<![CDATA[1]]>~1~ITEMID~una
DEPENDITEM~<![CDATA[0]]>~<![CDATA[99]]>~1~DEPENDITEM~una
voto malformato~r>>>>>1####~x>>>>>1####~1~con voto malformata~una
quattro cancelletti nel voto~1####Per niente~1####Per####niente~1~con voto malformata~una
troppe opzioni~|5####Del tutto~|5####A|6####B|7####C|8####D|9####E|10####F|11####G~1~troppe opzioni~una
scelta malformata~r>>>>>Troppo~x>>>>>Troppo~1~a scelta malformata~una
cancelletti nella scelta~Troppo lento|~Troppo####lento|~1~a scelta malformata~una
testo malformato~60|5~60x5~1~di testo malformata~una
etichetta vuota~<p><strong>Il corso nel suo insieme</strong></p>~VUOTO~1~etichetta senza testo~una
domanda vuota~Il ritmo del corso era:~VUOTO~1~domanda senza testo~una
etichetta di analisi~q04_ritmo~Q4-ritmo~1~etichetta di analisi~una
voto facoltativo~<![CDATA[ih]]>~<![CDATA[h]]>~1~facoltativo~una
CASI
}

# Le prove del file XML.
# Globals: XML, CONTROLLA, DOMANDE, TMP.
prove_xml() {
  local nome vecchio nuovo uscita parola quante
  run python3 -B -I "${CONTROLLA}" xml "${XML}"
  expect "il file del repository è coerente" 0 "${DOMANDE} domande"
  expect_absent "e non ha segnalazioni" "ITEM "
  while IFS='~' read -r nome vecchio nuovo uscita parola quante; do
    [[ "${nuovo}" == 'VUOTO' ]] && nuovo=''
    copia_xml "${XML}" "caso" "${vecchio}" "${nuovo}" "${quante}"
    run python3 -B -I "${CONTROLLA}" xml "${TMP}/caso.xml"
    expect "guasto, ${nome}" "${uscita}" "${parola}"
  done < <(casi_xml)
  copia_xml "${XML}" "senza_prologo" '<?xml version="1.0" encoding="UTF-8" ?>
' ''
  run python3 -B -I "${CONTROLLA}" xml "${TMP}/senza_prologo.xml"
  expect "guasto, nessuna dichiarazione" 1 "non riconosce"
  { printf '\xef\xbb\xbf'; cat "${XML}"; } > "${TMP}/bom.xml" \
    || die "allestimento fallito: BOM"
  run python3 -B -I "${CONTROLLA}" xml "${TMP}/bom.xml"
  expect "guasto, BOM" 1 "non riconosce"
  copia_xml "${XML}" "campo1" '<OPTIONS>' '<OPZIONI>'
  copia_xml "${TMP}/campo1.xml" "campo2" '</OPTIONS>' '</OPZIONI>'
  run python3 -B -I "${CONTROLLA}" xml "${TMP}/campo2.xml"
  expect "guasto, campo mancante" 1 "campi mancanti"
  copia_senza_domande "solo_etichette"
  run python3 -B -I "${CONTROLLA}" xml "${TMP}/solo_etichette.xml"
  expect "guasto, nessuna domanda" 1 "nessuna domanda"
  prove_xml_illeggibile
}

# I file che non si leggono: sempre uscita 2, mai una segnalazione (RU-01.T4).
# Globals: XML, CONTROLLA, TMP.
prove_xml_illeggibile() {
  head -n 2 "${XML}" > "${TMP}/rotto.xml" || die "allestimento fallito: rotto"
  run python3 -B -I "${CONTROLLA}" xml "${TMP}/rotto.xml"
  expect "un XML che non si legge è una precondizione" 2 "errore"
  { head -c 60 "${XML}"; printf '\xff\xfe'; } > "${TMP}/byte.xml" \
    || die "allestimento fallito: byte"
  run python3 -B -I "${CONTROLLA}" xml "${TMP}/byte.xml"
  expect "dei byte che non sono UTF-8 sono una precondizione" 2 "errore"
  run python3 -B -I "${CONTROLLA}" xml "${TMP}/inesistente.xml"
  expect "un file mancante è una precondizione" 2 "errore"
  run python3 -B -I "${CONTROLLA}"
  expect "senza argomenti è una precondizione" 2 "Uso:"
  run python3 -B -I "${CONTROLLA}" boh "${XML}"
  expect "un tipo di controllo sconosciuto è una precondizione" 2 "Uso:"
}

# Le prove dell'elenco delle risorse, una per regola di controlla_materiali.py.
# Globals: RISORSE, CONTROLLA, TMP.
prove_risorse() {
  local caso
  run python3 -B -I "${CONTROLLA}" risorse "${RISORSE}"
  expect "l'elenco del repository è coerente" 0 "elenco coerente"
  expect_absent "e nessun link segnalato" "link"
  expect_absent "e la data c'è" "data della verifica"
  sed -E 's/\*\*([0-9]{1,2} [a-z]+ [0-9]{4})\*\*/\1/' "${RISORSE}" \
    > "${TMP}/data.md" || die "allestimento fallito: data"
  run python3 -B -I "${CONTROLLA}" risorse "${TMP}/data.md"
  expect "senza la data in grassetto si segnala" 1 "data della verifica"
  sed -E 's/\*\*[0-9]{1,2} [a-z]+ [0-9]{4}\*\*/**99 pippo 1234**/' \
    "${RISORSE}" > "${TMP}/mese.md" || die "allestimento fallito: mese"
  run python3 -B -I "${CONTROLLA}" risorse "${TMP}/mese.md"
  expect "una data senza un mese vero si segnala" 1 "data della verifica"
  for caso in "[x](ftp://esempio)" "[x](HTTP://esempio)" "[x]( http://e)" \
      "<http://esempio>" "[a]: http://esempio" "vedi http://esempio"; do
    { cat "${RISORSE}"; echo "${caso}"; } > "${TMP}/link.md" \
      || die "allestimento fallito: link"
    run python3 -B -I "${CONTROLLA}" risorse "${TMP}/link.md"
    expect "link che non è https: ${caso}" 1 "https"
  done
  sed -E 's/\]\(https:\/\//] (https:\/\//g' "${RISORSE}" \
    > "${TMP}/prosa.md" || die "allestimento fallito: prosa"
  run python3 -B -I "${CONTROLLA}" risorse "${TMP}/prosa.md"
  expect "un elenco senza link veri si segnala" 1 "nessun link"
  printf '\xff\xfe' > "${TMP}/byte.md" || die "allestimento fallito: byte.md"
  run python3 -B -I "${CONTROLLA}" risorse "${TMP}/byte.md"
  expect "un elenco che non è UTF-8 è una precondizione" 2 "errore"
  run python3 -B -I "${CONTROLLA}" risorse "${TMP}/inesistente.md"
  expect "un elenco mancante è una precondizione" 2 "errore"
}
