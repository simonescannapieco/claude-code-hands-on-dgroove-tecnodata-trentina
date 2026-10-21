#!/bin/bash
#
# test_m2_kit.sh -- le prove del kit di misura delle due esercitazioni del
# modulo 2 (M2-E01 e M2-E02), per il docente: le pratiche sui criteri, il
# giudice due volte su v0, l'esito di una pratica in --confronta, la
# verifica del lavoro e le precondizioni dei due live.sh.
#   - kit.py: i due formati di rubrica.md e di controlli.tsv (con e senza
#     la pratica), una pratica che non c'è, ✓ e ✗ con la pratica, la
#     consegna al giudice senza le pratiche; la riga della prova del
#     giudice; l'elenco delle pratiche (rimisura solo in M2-E01), con le
#     regole che confrontano vA e vB; un BOM in testa a controlli.tsv,
#     rubrica.md o registro.md, che non cambia l'esito; il telefono con i
#     trattini;
#   - ogni esito di --confronta, mai «smentita»: sui criteri segnati con la
#     pratica, contati in vA e in vB, confermata (più criteri in vB),
#     non decisa (lo stesso numero; nessun criterio; solo affermazioni
#     instabili; nessun criterio con un esito nelle due versioni; pratica
#     da scrivere, fuori elenco o senza riga; testo uguale; due cose
#     insieme; dati cambiati), non confermata in questa misura (meno
#     criteri in vB); effort (confermata, la stessa misura, non
#     confermata, senza margine, effort non registrato o uguale), modello,
#     ruolo, rimisura, partenza; il segno «(instabile)» e il totale di v0;
#     l'avviso dello stesso modello;
#   - i dati rovinati (nessun JSON, is_error, un campo che manca, uno
#     schema non rispettato) gestiti dal contratto, mai con un traceback;
#   - misura.sh con il claude finto del modulo: tre chiamate su v0 con il
#     secondo giudizio, due sulle altre versioni, le opzioni registrate,
#     CLAUDE_CODE_EFFORT_LEVEL che non arriva a claude, la misura nuova
#     che toglie il secondo giudizio vecchio, --pratiche senza claude;
#   - verifica.sh: spazio di lavoro assente (2), punto di partenza (1),
#     lavoro completo (0, e l'ultima riga è la frase finale), una garanzia
#     non confermata (1), una pratica non confermata (0), il secondo
#     giudizio che manca, una pratica fuori elenco, una riga da compilare
#     o che manca, v1 uguale a v0 (1), il registro che non si legge (2),
#     il kit dell'elemento che manca o che si rompe (2); l'uscita di
#     verifica.py (0, 1 e 2 passano, un'altra uscita o un segnale diventa
#     2); il telefono nella risposta di M2-E01, un dato senza esito; le
#     famiglie con v2 di M2-E02;
#   - i due live.sh: le precondizioni escono 2 senza chiamare claude (un
#     claude esca davanti nel PATH registra ogni chiamata), in M2-E02
#     anche ogni famiglia prima della prima chiamata; con il claude finto
#     del modulo la prova intera esce 0, con 7 e 21 chiamate;
#   - shellcheck -x sugli script dei due elementi e su questo.
# Gli spazi di lavoro nascono in una cartella temporanea: l'albero del
# repository non cambia. I casi si contano: da root i casi dei file che
# non si leggono sono saltati e contati a parte (SKIP), e un numero di
# casi diverso da CASES esce 2.
#
# Uso:    m2_prompting_avanzato/_docente/test_m2_kit.sh
# Uscita: 0 = tutte le prove passano · 1 = almeno una fallita ·
#         2 = precondizione (manca python3 o shellcheck, la cartella di un
#             elemento, la preparazione di una prova non riesce, o le prove
#             eseguite non sono quante attese)
set -uo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly MOD="${SELF%/_docente/*}"
readonly RADICE="${MOD%/*}"
readonly E01="${MOD}/s1_progettare_il_prompt/m2_e2_prompt_pessimo/\
M2-E01_prompt_pessimo"
readonly E02="${MOD}/s2_misurare_e_migliorare/m2_e3_tre_prompt_due_cicli/\
M2-E02_tre_prompt_due_cicli"
readonly FINTO="${MOD}/_docente/claude_finto.py"
readonly CASES=163
readonly SONNET=claude-sonnet-finto
readonly HAIKU=claude-haiku-finto
readonly OPUS=claude-opus-finto
readonly TEL='Gentile cliente, la richiamiamo al +39 000 000 0103. [Nome]'
readonly BUONA="Gentile signor Fittizio, la richiesta è aperta. \
L'assistenza clienti di CiaspoLink"
readonly ALTRA="Gentile signor Fittizio, abbiamo aperto la richiesta. \
L'assistenza clienti di CiaspoLink"
readonly FINE="Fatto: ogni affermazione è stata messa alla prova; gli \
esiti sono qui sopra."
readonly GUIDA="https://platform.claude.com/docs/it/build-with-claude/\
prompt-engineering/claude-prompting-best-practices"
readonly BOM=$'\xef\xbb\xbf'
readonly TEL_PRESENTE="Il telefono del cliente nella risposta di v2: presente \
(la risposta lo ripete)"
TMP=''
PASS=0
FAIL=0
SKIP=0
RC=0
OUT=''

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }
# Un caso che da root non può girare: contato a parte, mai come passato.
skip() { echo "  SKIP: $1"; SKIP=$((SKIP + 1)); }

# Esegue un comando; RC e OUT (STDOUT e STDERR insieme) per expect.
run() { OUT="$("$@" 2>&1)"; RC=$?; }

# OUT su una riga sola: kit.py manda a capo le righe lunghe, e una parola
# attesa può stare a cavallo di due righe.
piano() { tr -s ' \n' '  ' <<< "${OUT}"; }

# Uscita attesa E parola chiave attesa (RU-01.T3).
# Arguments: $1 il nome, $2 l'uscita attesa, $3 la parola (grep -F).
expect() {
  if (( RC == $2 )) && grep -qF -- "$3" <<< "$(piano)"; then
    pass "$1"
  else
    fail "$1 (rc=${RC}, attesa $2, parola «$3»): ${OUT:0:400}"
  fi
}

# Uscita attesa E una riga intera di OUT, uguale carattere per carattere.
# Arguments: $1 il nome, $2 l'uscita attesa, $3 la riga (grep -xF).
expect_riga() {
  if (( RC == $2 )) && grep -qxF -- "$3" <<< "${OUT}"; then
    pass "$1"
  else
    fail "$1 (rc=${RC}, attesa $2, riga «$3»): ${OUT:0:400}"
  fi
}

# Nessun falso positivo: la parola NON c'è (RU-01.T5).
# Arguments: $1 il nome, $2 la parola.
expect_absent() {
  if grep -qF -- "$2" <<< "$(piano)"; then
    fail "$1: «$2» c'è"
  else
    pass "$1"
  fi
}

# La preparazione di una prova che non riesce: uscita 2.
rotta() { echo "test_m2_kit: preparazione non riuscita: $*" >&2; exit 2; }

# Un nuovo spazio di lavoro, con il contenuto di una o più cartelle.
# Arguments: $1 la variabile da assegnare, poi le cartelle da copiare.
ws() {
  local __ws_d __ws_c
  __ws_d="$(mktemp -d "${TMP}/ws.XXXXXX")" || rotta "mktemp"
  for __ws_c in "${@:2}"; do
    cp -R "${__ws_c}/." "${__ws_d}/" || rotta "cp ${__ws_c}"
  done
  printf -v "$1" '%s' "${__ws_d}"
}

# I file sintetici di una misura, con ${TMP}/fx.py.
fx() { python3 -B -I "${TMP}/fx.py" "$@" || rotta "fx $1 $2"; }

# kit.py di uno spazio di lavoro, eseguito nella sua cartella.
# Arguments: $1 lo spazio, poi gli argomenti di kit.py.
kit() {
  local w="$1"
  shift
  (cd "${w}" && python3 -B strumenti/kit.py "$@")
}

# Una versione misurata con file sintetici: il prompt, la risposta, i
# controlli e le opzioni con kit.py (come misura.sh), il giudizio.
# Arguments: $1 spazio, $2 cartella, $3 versione, $4 il file del prompt
#   ("" = quello che c'è), $5 la risposta, $6 il modello (haiku, sonnet,
#   opus), $7 l'effort, poi gli esiti del giudice: id=1, id=0, id=x (non
#   valutato) o @tutti=1, @tutti=0.
versione() {
  local w="$1" c="$2" v="$3" p="$4" t="$5" m="$6" e="$7" rc=0
  shift 7
  mkdir -p "${w}/${c}/risposte" "${w}/${c}/giudizi" || rotta "mkdir"
  if [[ -n "${p}" ]]; then
    cp "${p}" "${w}/${c}/prompt/${v}.md" || rotta "cp ${p}"
  fi
  fx risposta "${w}/${c}/risposte/${v}.json" "${t}" "claude-${m}-finto"
  kit "${w}" controlla "${c}" "${v}" > /dev/null || rc=$?
  (( rc <= 1 )) || rotta "controlla ${c} ${v}: uscita ${rc}"
  kit "${w}" opzioni "${c}" "${v}" "${m}" "${e}" || rotta "opzioni ${v}"
  fx giudizio "${w}/${c}/giudizi/${v}.json" "${HAIKU}" \
    "${w}/${c}/rubrica.md" "$@"
}

# registro.md di M2-E01 con le righe date, «versione:pratica», compilate.
# Arguments: $1 lo spazio, poi le righe.
registro_e01() {
  local w="$1" r
  shift
  {
    printf '# Registro delle versioni\n\n'
    printf '| versione | pratica | che cosa ho cambiato | controlli |'
    printf ' giudice | note |\n|---|---|---|---|---|---|\n'
    for r in "$@"; do
      printf '| %s | %s | una cosa | 1/3 | 1/5 | prova |\n' \
        "${r%%:*}" "${r#*:}"
    done
  } > "${w}/registro.md" || rotta "registro"
}

# Uno spazio di lavoro di M2-E01 con v0 e v1 misurate: v0 ripete il
# telefono e lascia un segnaposto, v1 no; il giudice di v0, le due volte,
# rispetta solo «lei», quello di v1 tutto tranne «fatti»; il registro
# compilato, v1 con la pratica $2 (default chiarezza).
# Arguments: $1 la variabile da assegnare, $2 la pratica di v1.
e01() {
  local __w
  ws __w "${E01}/esercizio"
  versione "${__w}" . v0 "" "${TEL}" sonnet low @tutti=0 lei=1
  fx giudizio "${__w}/giudizi/v0-bis.json" "${HAIKU}" \
    "${__w}/rubrica.md" @tutti=0 lei=1
  versione "${__w}" . v1 "${E01}/soluzione/prompt/v1.md" "${BUONA}" \
    sonnet low @tutti=1 fatti=0
  registro_e01 "${__w}" v0:partenza "v1:${2:-chiarezza}"
  printf -v "$1" '%s' "${__w}"
}

# Uno spazio di lavoro di M2-E02 con v0, v1 e v2 misurate nelle famiglie
# date (le versioni di soluzione/, il giudice che rispetta tutto da v1)
# e v0, v1 nelle altre; il registro compilato.
# Arguments: $1 la variabile da assegnare, poi le famiglie con v2.
e02() {
  local __w f v
  ws __w "${E02}/esercizio"
  printf '| famiglia | versione | pratica | che cosa ho cambiato |' \
    > "${__w}/registro.md"
  printf ' controlli | giudice | note |\n|---|---|---|---|---|---|---|\n' \
    >> "${__w}/registro.md"
  for f in sviluppo supporto sistemi; do
    versione "${__w}" "${f}" v0 "" "Una risposta." sonnet low @tutti=0
    fx giudizio "${__w}/${f}/giudizi/v0-bis.json" "${HAIKU}" \
      "${__w}/${f}/rubrica.md" @tutti=0
    versione "${__w}" "${f}" v1 "${E02}/soluzione/${f}/prompt/v1.md" \
      "${BUONA}" sonnet low @tutti=1
    printf '| %s | v0 | partenza | x | 1/2 | 0/5 | p |\n' "${f}" \
      >> "${__w}/registro.md"
    printf '| %s | v1 | chiarezza | x | 1/2 | 5/5 | p |\n' "${f}" \
      >> "${__w}/registro.md"
  done
  for f in "${@:2}"; do
    versione "${__w}" "${f}" v2 "${E02}/soluzione/${f}/prompt/v2.md" \
      "${ALTRA}" sonnet low @tutti=1
    printf '| %s | v2 | contesto | x | 1/2 | 5/5 | p |\n' "${f}" \
      >> "${__w}/registro.md"
  done
  printf -v "$1" '%s' "${__w}"
}

# Il claude finto del modulo in ${TMP}/finto; un claude esca in
# ${TMP}/esca che registra ogni chiamata ed esce 1; in ${TMP}/spia un
# claude che scrive in SPIA_LOG se CLAUDE_CODE_EFFORT_LEVEL gli arriva, poi
# passa la chiamata al finto; fx.py.
prepara() {
  mkdir -p "${TMP}/finto" "${TMP}/esca" "${TMP}/spia" || rotta "mkdir"
  cp "${FINTO}" "${TMP}/finto/claude" || rotta "il claude finto"
  # shellcheck disable=SC2016  # il corpo è dell'esca
  printf '%s\n' '#!/bin/bash' 'echo "chiamata $*" >> "${ESCA_LOG}"' \
    'exit 1' > "${TMP}/esca/claude" || rotta "il claude esca"
  # shellcheck disable=SC2016  # il corpo è della spia
  printf '%s\n' '#!/bin/bash' \
    'echo "effort ${CLAUDE_CODE_EFFORT_LEVEL-assente}" >> "${SPIA_LOG}"' \
    'exec "${SPIA_FINTO}" "$@"' > "${TMP}/spia/claude" || rotta "la spia"
  chmod 755 "${TMP}/finto/claude" "${TMP}/esca/claude" "${TMP}/spia/claude" \
    || rotta "chmod"
  cat > "${TMP}/fx.py" <<'PY' || rotta "fx.py"
"""fx.py -- i file sintetici delle prove: una risposta o un giudizio."""
import json
import re
import sys

comando, percorso = sys.argv[1], sys.argv[2]
if comando == "risposta":
    testo, modello = sys.argv[3], sys.argv[4]
    doc = {"type": "result", "is_error": False, "result": testo,
           "usage": {"input_tokens": 100, "output_tokens": 20},
           "modelUsage": {modello: {}}}
else:
    modello, rubrica = sys.argv[3], sys.argv[4]
    ids = [m.group(1) for m in (re.match(r"^- \*\*([a-z_]+)\*\*", r)
           for r in open(rubrica, encoding="utf-8")) if m]
    esiti = {}
    for voce in sys.argv[5:]:
        chiave, _, valore = voce.partition("=")
        for i in (ids if chiave == "@tutti" else [chiave]):
            esiti[i] = valore
    criteri = [{"id": i, "motivo": "m", "rispettato": v == "1"}
               for i, v in esiti.items() if v != "x"]
    doc = {"type": "result", "is_error": False, "result": "",
           "structured_output": {"criteri": criteri},
           "modelUsage": {modello: {}}}
json.dump(doc, open(percorso, "w", encoding="utf-8"), ensure_ascii=False)
PY
}

# Un comando con il claude finto davanti nel PATH; ${TMP}/chiamate.log
# riparte vuoto. Arguments: le variabili NOME=valore e il comando.
finto() {
  : > "${TMP}/chiamate.log"
  run env PATH="${TMP}/finto:${PATH}" HANDSON_NO_PAUSE=1 \
    FINTO_LOG="${TMP}/chiamate.log" "$@"
}

# Quante chiamate ha ricevuto il claude finto.
chiamate() { grep -c '^chiamata' "${TMP}/chiamate.log"; }

# Un comando con il claude esca davanti nel PATH: deve uscire 2 con la
# parola, senza nessuna chiamata. Arguments: $1 il nome, $2 la parola,
# poi il comando.
senza_chiamate() {
  local nome="$1" parola="$2" n
  shift 2
  : > "${TMP}/esca.log"
  run env PATH="${TMP}/esca:${PATH}" HANDSON_NO_PAUSE=1 \
    ESCA_LOG="${TMP}/esca.log" "$@"
  expect "${nome}" 2 "${parola}"
  n="$(grep -c '^chiamata' "${TMP}/esca.log")"
  if (( n == 0 )); then pass "${nome}: nessuna chiamata a claude"
  else fail "${nome}: ${n} chiamate a claude"; fi
}

# Una copia dell'elemento $2 con la libreria accanto, come nel
# repository. Arguments: $1 la variabile (l'elemento nella copia), $2
# l'elemento.
albero() {
  local __a __rel="${2#"${RADICE}"/}"
  __a="$(mktemp -d "${TMP}/albero.XXXXXX")" || rotta "mktemp"
  mkdir -p "${__a}/tools" "${__a}/${__rel}" || rotta "mkdir"
  cp "${RADICE}/tools/lib_handson.sh" "${__a}/tools/" || rotta "lib"
  cp -R "$2/." "${__a}/${__rel}/" || rotta "cp $2"
  printf -v "$1" '%s' "${__a}/${__rel}"
}

# --- I test ---------------------------------------------------------------

# I formati: la pratica facoltativa in rubrica.md e in controlli.tsv, una
# pratica che non c'è, ✓ e ✗ con la pratica, la consegna senza pratiche.
t_formati() {
  local w
  e01 w
  run kit "${w}" controlla . v0
  expect "kit: ✗ con la pratica" 1 \
    "✗ [chiarezza] il numero di telefono del cliente non compare"
  run kit "${w}" giudizio . v1
  expect "kit: ✓ con la pratica" 0 "✓ [chiarezza] domande"
  expect "kit: l'affermazione di contesto" 0 "✗ [contesto] fatti"
  run kit "${w}" consegna . v1
  expect "kit: la consegna senza le pratiche" 0 "- domande: La risposta"
  expect_absent "kit: e senza le quadre" "[chiarezza]"
  sed -i 's/^- \*\*\([a-z_]*\)\*\* \[[a-z]*\]:/- **\1**:/' "${w}/rubrica.md"
  printf 'tipo\tvalore\tdescrizione\nparole_max\t150\tcorta\n' \
    > "${w}/controlli.tsv"
  run kit "${w}" controlla . v1
  expect "kit: controlli.tsv senza la colonna pratica" 0 "✓ corta (11 parole)"
  run kit "${w}" giudizio . v1
  expect "kit: rubrica.md senza pratiche" 0 "✓ domande: m"
  printf -- '- **altra** [boh]: x.\n' >> "${w}/rubrica.md"
  run kit "${w}" consegna . v1
  expect "kit: una pratica che non c'è, in rubrica.md" 2 \
    "la pratica «boh» non c'è"
  e01 w
  printf 'tipo\tvalore\tdescrizione\tpratica\nparole_max\t150\tcorta\n' \
    > "${w}/controlli.tsv"
  printf 'parole_min\t2\tlunga\ttag\n' >> "${w}/controlli.tsv"
  run kit "${w}" controlla . v1
  expect "kit: tre e quattro campi sotto l'intestazione con pratica" 0 \
    "✓ [tag] lunga"
  printf 'parole_min\t2\taltra\tboh\n' >> "${w}/controlli.tsv"
  run kit "${w}" controlla . v1
  expect "kit: una pratica che non c'è, in controlli.tsv" 2 \
    "la pratica «boh» non c'è"
  printf 'tipo\tvalore\tdescrizione\tpratica\nparole_min\t2\ta\tb\tc\n' \
    > "${w}/controlli.tsv"
  run kit "${w}" controlla . v1
  expect "kit: cinque campi" 2 "attesi tre campi (o quattro, con la pratica)"
  printf 'tipo\tvalore\tdescrizione\nparole_min\t2\ta\nparole_max\t9\ta\n' \
    > "${w}/controlli.tsv"
  run kit "${w}" controlla . v1
  expect "kit: una descrizione ripetuta" 2 "la descrizione «a» c'è già"
  printf 'tipo\tvalore\tdescrizione\tnota\n' > "${w}/controlli.tsv"
  run kit "${w}" controlla . v1
  expect "kit: un'intestazione diversa" 2 "la prima riga"
}

# La prova del giudice: la riga di kit.py stabilita.
t_stabilita() {
  local w
  e01 w
  run kit "${w}" stabilita . v0
  expect "stabilità: tutto uguale" 0 \
    "stesso esito due volte su 5 affermazioni di 5; instabili: nessuna."
  expect "stabilità: il secondo giudizio stampato" 0 \
    "Giudizio v0, la seconda volta (${HAIKU})"
  fx giudizio "${w}/giudizi/v0-bis.json" "${HAIKU}" "${w}/rubrica.md" \
    @tutti=0 lei=0 firma=x
  run kit "${w}" stabilita . v0
  expect "stabilità: una diversa e una non valutata" 0 \
    "su 3 affermazioni di 5; instabili: lei, firma."
  expect "stabilità: l'instabile non è una prova" 0 \
    "Un'affermazione instabile non è una prova"
  rm "${w}/giudizi/v0-bis.json"
  run kit "${w}" stabilita . v0
  expect "stabilità: senza il secondo giudizio esce 2" 2 "manca il file"
}

# L'elenco delle pratiche: rimisura solo dove il prompt è uno; le regole
# confrontano vA e vB, e nessuna dice «smentita».
t_pratiche() {
  local w
  ws w "${E01}/esercizio"
  run kit "${w}" pratiche .
  expect "pratiche: la frase italiana di chiarezza" 0 \
    "«Più precisamente spieghi cosa vuoi, migliore sarà il risultato.»"
  expect "pratiche: rimisura in M2-E01" 0 "rimisura"
  expect "pratiche: il link della guida" 0 "${GUIDA}"
  expect "pratiche: i criteri si contano in vA e in vB" 0 \
    "confermata se vB ne rispetta più di vA, non decisa se lo stesso \
numero, non confermata in questa misura se meno"
  expect "pratiche: gli esiti del confronto" 0 "dice l'esito della pratica \
di vB: confermata, non confermata in questa misura o non decisa"
  expect_absent "pratiche: mai «smentita» in M2-E01" "smentit"
  ws w "${E02}/esercizio"
  run kit "${w}" pratiche .
  expect "pratiche: effort in M2-E02" 0 "traduzione nostra"
  expect "pratiche: effort, la stessa misura non decide" 0 \
    "non decisa se è la stessa, non confermata in questa misura se è più \
bassa"
  expect_absent "pratiche: niente rimisura in M2-E02" "rimisura"
  expect_absent "pratiche: mai «smentita» in M2-E02" "smentit"
  ws w "${E01}/esercizio"
  senza_chiamate "misura.sh --pratiche con altri argomenti" \
    "uso: ./misura.sh --pratiche" "${w}/misura.sh" --pratiche v0
}

# I due giudizi di v0 con gli stessi esiti (nessuna affermazione
# instabile). Arguments: $1 lo spazio, poi gli esiti, come per fx.
giudizi_v0() {
  local w="$1"
  shift
  fx giudizio "${w}/giudizi/v0.json" "${HAIKU}" "${w}/rubrica.md" "$@"
  fx giudizio "${w}/giudizi/v0-bis.json" "${HAIKU}" "${w}/rubrica.md" "$@"
}

# Gli esiti di --confronta per le pratiche lette sui criteri: i criteri
# segnati con la pratica che hanno un esito in vA e in vB, senza le
# affermazioni instabili, contati nelle due versioni. Più criteri
# rispettati in vB: confermata; lo stesso numero: non decisa; meno: non
# confermata in questa misura; mai «smentita». In e01, con chiarezza, v0
# rispetta 2 criteri su 7 (al massimo 150 parole, lei), v1 tutti e 7.
t_esiti_criteri() {
  local w
  e01 w
  run kit "${w}" confronta . v0 v1
  expect "chiarezza confermata: più criteri rispettati in v1 che in v0" 0 \
    "esito della pratica: confermata (criteri segnati [chiarezza] \
rispettati: 2 su 7 in v0, 7 su 7 in v1)"
  expect "chiarezza: la frase di Anthropic" 0 "pratica di v1: chiarezza"
  expect "il totale di v0" 0 "totali: controlli 1/3 → 3/3; giudice 1 → 4 su 5"
  expect_absent "giudice e risposta da modelli diversi" "stesso modello"
  fx giudizio "${w}/giudizi/v1.json" "${HAIKU}" "${w}/rubrica.md" \
    @tutti=1 fatti=0 firma=0
  run kit "${w}" confronta . v0 v1
  expect "chiarezza: un criterio mancato in v1, più criteri che in v0" 0 \
    "confermata (criteri segnati [chiarezza] rispettati: 2 su 7 in v0, 6 \
su 7 in v1; non rispettati in v1: firma)"
  giudizi_v0 "${w}" @tutti=0 lei=1 domande=1
  fx giudizio "${w}/giudizi/v1.json" "${HAIKU}" "${w}/rubrica.md" @tutti=0
  run kit "${w}" confronta . v0 v1
  expect "chiarezza non decisa: lo stesso numero in v0 e in v1" 0 \
    "non decisa (criteri segnati [chiarezza] rispettati: 3 su 7 in v0, 3 \
su 7 in v1; lo stesso numero: questa coppia non lo dice; non rispettati \
in v1: domande, impegni, lei, firma)"
  giudizi_v0 "${w}" @tutti=1
  run kit "${w}" confronta . v0 v1
  expect "chiarezza non confermata: meno criteri rispettati in v1" 0 \
    "esito della pratica: non confermata in questa misura (criteri \
segnati [chiarezza] rispettati: 5 su 7 in v0, 3 su 7 in v1; non \
rispettati in v1: domande, impegni, lei, firma)"
  expect_absent "non confermata: mai «smentita»" "smentit"
  e01 w
  fx giudizio "${w}/giudizi/v1.json" "${HAIKU}" "${w}/rubrica.md" \
    @tutti=1 firma=x
  run kit "${w}" confronta . v0 v1
  expect "chiarezza: un criterio senza esito in v1 non si conta" 0 \
    "confermata (criteri segnati [chiarezza] rispettati: 2 su 6 in v0, 6 \
su 6 in v1; escluso 1 criterio senza esito in v0 o in v1)"
  e01 w tag
  run kit "${w}" confronta . v0 v1
  expect "tag: nessun criterio" 0 \
    "non decisa (nessun criterio è segnato [tag]"
  e01 w contesto
  fx giudizio "${w}/giudizi/v1.json" "${HAIKU}" "${w}/rubrica.md" \
    @tutti=1 fatti=x
  run kit "${w}" confronta . v0 v1
  expect "contesto: nessun criterio con un esito in v0 e in v1" 0 \
    "non decisa (nessun criterio segnato [contesto] ha un esito in v0 e \
in v1)"
  e01 w contesto
  fx giudizio "${w}/giudizi/v0-bis.json" "${HAIKU}" "${w}/rubrica.md" \
    @tutti=0 lei=1 fatti=1
  run kit "${w}" confronta . v0 v1
  expect "contesto: solo affermazioni instabili" 0 \
    "sono solo affermazioni instabili"
  expect "il segno dell'instabile" 0 "[contesto] fatti (instabile)"
  e01 w
  fx giudizio "${w}/giudizi/v0-bis.json" "${HAIKU}" "${w}/rubrica.md" \
    @tutti=0
  run kit "${w}" confronta . v0 v1
  expect "in v0 l'instabile non conta" 0 "giudice 0 → 4 su 5"
  expect "chiarezza senza l'instabile" 0 "confermata (criteri segnati \
[chiarezza] rispettati: 1 su 6 in v0, 6 su 6 in v1; senza 1 affermazione \
instabile)"
  rm "${w}/giudizi/v0-bis.json"
  run kit "${w}" confronta . v0 v1
  expect "senza il secondo giudizio, l'avviso" 0 \
    "la prova del giudice manca"
}

# Gli esiti «non decisa» del registro e delle cose cambiate insieme.
t_esiti_non_decisi() {
  local w
  e01 w '…'
  run kit "${w}" confronta . v0 v1
  expect "pratica da scrivere" 0 "la pratica di v1 è da scrivere"
  e01 w boh
  run kit "${w}" confronta . v0 v1
  expect "pratica fuori elenco" 0 "si scrive una di chiarezza"
  e01 w
  registro_e01 "${w}" v0:partenza
  run kit "${w}" confronta . v0 v1
  expect "la riga che manca" 0 "registro.md non ha la riga di v1"
  e01 w
  cp "${w}/prompt/v0.md" "${w}/prompt/v1.md"
  kit "${w}" opzioni . v1 sonnet low || rotta "opzioni"
  run kit "${w}" confronta . v0 v1
  expect "testo uguale" 0 "la pratica non è stata applicata"
  e01 w
  fx risposta "${w}/risposte/v1.json" "${BUONA}" "${OPUS}"
  run kit "${w}" confronta . v0 v1
  expect "due cose insieme: il modello" 0 \
    "è cambiato anche il modello della risposta (${SONNET} → ${OPUS})"
  e01 w
  printf 'Un altro messaggio.\n' > "${w}/dati/messaggio.md"
  kit "${w}" opzioni . v1 sonnet low || rotta "opzioni"
  run kit "${w}" confronta . v0 v1
  expect "due cose insieme: i dati" 0 "sono cambiati anche i file di dati/"
  e01 w ruolo
  run kit "${w}" confronta . v0 v1
  expect "ruolo: sempre non decisa" 0 "non decisa (la frase parla del system"
  e01 w
  run kit "${w}" confronta . v1 v0
  expect "partenza" 0 "non decisa (v0 è la partenza)"
}

# effort, modello e rimisura: lo stesso testo di v1 in v2.
t_esiti_stesso_testo() {
  local w
  e01 w
  versione "${w}" . v2 "${w}/prompt/v1.md" "${ALTRA}" sonnet high @tutti=1
  registro_e01 "${w}" v0:partenza v1:chiarezza v2:effort
  run kit "${w}" confronta . v1 v2
  expect "effort confermata" 0 "confermata (misura 7 con effort low (v1), \
8 con effort high (v2), su 8)"
  fx giudizio "${w}/giudizi/v2.json" "${HAIKU}" "${w}/rubrica.md" \
    @tutti=1 fatti=0
  run kit "${w}" confronta . v1 v2
  expect "effort non decisa: la stessa misura" 0 "non decisa (misura 7 \
con effort low (v1), 7 con effort high (v2), su 8; la stessa misura: \
questa coppia non lo dice)"
  fx giudizio "${w}/giudizi/v2.json" "${HAIKU}" "${w}/rubrica.md" \
    @tutti=1 fatti=0 lei=0
  run kit "${w}" confronta . v1 v2
  expect "effort non confermata, con i due sospetti" 0 "non confermata in \
questa misura (misura 7 con effort low (v1), 6 con effort high (v2), su 8; \
Anthropic: se non succede"
  expect_absent "effort: mai «smentita»" "smentit"
  fx giudizio "${w}/giudizi/v1.json" "${HAIKU}" "${w}/rubrica.md" @tutti=1
  run kit "${w}" confronta . v1 v2
  expect "effort senza margine" 0 "è già al massimo"
  kit "${w}" opzioni . v2 sonnet low || rotta "opzioni"
  run kit "${w}" confronta . v1 v2
  expect "effort uguale" 0 "l'effort è lo stesso (low)"
  rm "${w}/risposte/v2.opzioni"
  run kit "${w}" confronta . v1 v2
  expect "effort non registrato" 0 "non si sa se l'effort è cambiato"
  e01 w
  versione "${w}" . v2 "${w}/prompt/v1.md" "${ALTRA}" opus low @tutti=1
  registro_e01 "${w}" v0:partenza v1:chiarezza v2:modello
  run kit "${w}" confronta . v1 v2
  expect "modello: la misura, non decisa" 0 \
    "il kit non sa quale dei due modelli sia «più capace»"
  e01 w
  versione "${w}" . v2 "${w}/prompt/v1.md" "${ALTRA}" sonnet low \
    @tutti=1 fatti=0
  registro_e01 "${w}" v0:partenza v1:chiarezza v2:rimisura
  run kit "${w}" confronta . v1 v2
  expect "rimisura confermata" 0 "le due risposte sono diverse"
  fx risposta "${w}/risposte/v2.json" "${BUONA}" "${SONNET}"
  run kit "${w}" confronta . v1 v2
  expect "rimisura non decisa" 0 "le due risposte sono identiche"
  printf 'un altro testo\n' > "${w}/prompt/v2.md"
  kit "${w}" opzioni . v2 sonnet low || rotta "opzioni"
  run kit "${w}" confronta . v1 v2
  expect "rimisura con il testo cambiato" 0 \
    "con «rimisura» il testo del prompt resta lo stesso"
}

# L'avviso dello stesso modello, e rimisura fuori da M2-E01.
t_avvisi() {
  local w
  e01 w
  fx risposta "${w}/risposte/v1.json" "${BUONA}" "${HAIKU}"
  run kit "${w}" confronta . v0 v1
  expect "lo stesso modello per risposta e giudizio" 0 \
    "vengono dallo stesso modello (${HAIKU})"
  run kit "${w}" giudizio . v1
  expect "l'avviso anche nel giudizio" 0 "stesso modello"
  e02 w sistemi
  sed -i 's/^| sistemi | v2 | contesto |/| sistemi | v2 | rimisura |/' \
    "${w}/registro.md"
  run kit "${w}" confronta sistemi v1 v2
  expect "rimisura fuori elenco in M2-E02" 0 \
    "si scrive una di chiarezza, contesto, ruolo, tag, effort, modello"
}

# I dati rovinati: le uscite del contratto, mai un traceback.
t_rovinati() {
  local w
  e01 w
  printf '{"type": "result",' > "${w}/giudizi/v1.json"
  run kit "${w}" confronta . v0 v1
  expect "un giudizio che non è JSON esce 1" 1 "non è un JSON valido"
  expect_absent "e senza traceback" "Traceback"
  e01 w
  printf '{"type":"result","is_error":true,"result":"x"}\n' \
    > "${w}/risposte/v1.json"
  run kit "${w}" confronta . v0 v1
  expect "una risposta con is_error esce 1" 1 "errore di Claude Code"
  e01 w
  printf '{"type":"result","is_error":false,"result":""}\n' \
    > "${w}/giudizi/v1.json"
  run kit "${w}" confronta . v0 v1
  expect "un giudizio senza structured_output esce 1" 1 "structured_output"
  e01 w
  fx giudizio "${w}/giudizi/v1.json" "${HAIKU}" "${w}/rubrica.md" \
    @tutti=1 firma=x
  run kit "${w}" giudizio . v1
  expect "un'affermazione senza esito" 0 "firma: non valutato dal giudice"
  printf 'niente tabelle\n' > "${w}/registro.md"
  run kit "${w}" confronta . v0 v1
  expect "un registro senza tabella" 0 "registro.md non ha la riga di v1"
  e01 w
  printf 'effort\tmax\nrotta\n' > "${w}/risposte/v1.opzioni"
  run kit "${w}" confronta . v0 v1
  expect "opzioni rovinate: un effort che non si sa non conta" 0 \
    "esito della pratica: confermata"
  expect_absent "opzioni rovinate: senza traceback" "Traceback"
}

# misura.sh con il claude finto: il secondo giudizio su v0, le opzioni, la
# misura nuova, --pratiche senza claude.
t_misura() {
  local w n
  ws w "${E01}/esercizio"
  finto "${w}/misura.sh" v0
  expect "misura.sh v0: la prova del giudice" 0 \
    "Giudice su v0: stesso esito due volte su 5 affermazioni di 5"
  n="$(chiamate)"
  if (( n == 3 )) && [[ -f "${w}/giudizi/v0-bis.json" ]]; then
    pass "misura.sh v0: tre chiamate e giudizi/v0-bis.json"
  else fail "misura.sh v0: ${n} chiamate"; fi
  cp "${E01}/soluzione/prompt/v1.md" "${w}/prompt/v1.md"
  finto "${w}/misura.sh" v1 --effort high
  n="$(chiamate)"
  if (( n == 2 )) && [[ ! -e "${w}/giudizi/v1-bis.json" ]]; then
    pass "misura.sh v1: due chiamate, un giudizio"
  else fail "misura.sh v1: ${n} chiamate"; fi
  run cat "${w}/risposte/v1.opzioni"
  expect "misura.sh: le opzioni registrate" 0 $'effort\thigh'
  # CLAUDE_CODE_EFFORT_LEVEL ha la precedenza su --effort: misura.sh lo
  # toglie, così l'effort registrato è quello della chiamata.
  ws w "${E01}/esercizio"
  : > "${TMP}/spia.log"
  run env PATH="${TMP}/spia:${PATH}" SPIA_LOG="${TMP}/spia.log" \
    SPIA_FINTO="${TMP}/finto/claude" CLAUDE_CODE_EFFORT_LEVEL=high \
    "${w}/misura.sh" v0
  expect "misura.sh con CLAUDE_CODE_EFFORT_LEVEL=high nell'ambiente" 0 \
    "Giudice su v0"
  n="$(grep -c '^effort' "${TMP}/spia.log")"
  if (( n == 3 )) && ! grep -qv '^effort assente$' "${TMP}/spia.log"; then
    pass "misura.sh: CLAUDE_CODE_EFFORT_LEVEL non arriva a claude, 3 su 3"
  else
    fail "misura.sh: CLAUDE_CODE_EFFORT_LEVEL a claude: $(tr '\n' ' ' \
      < "${TMP}/spia.log")"
  fi
  run cat "${w}/risposte/v0.opzioni"
  expect "misura.sh: l'effort registrato è quello di --effort" 0 \
    $'effort\tlow'
  finto FINTO_ESITO=ko "${w}/misura.sh" v0
  if (( RC == 1 )) && [[ ! -e "${w}/giudizi/v0-bis.json" ]]; then
    pass "misura.sh: la misura nuova toglie il secondo giudizio vecchio"
  else fail "misura.sh: rc=${RC}, giudizi/v0-bis.json c'è ancora"; fi
  : > "${TMP}/esca.log"
  run env PATH="${TMP}/esca:${PATH}" ESCA_LOG="${TMP}/esca.log" \
    "${w}/misura.sh" --pratiche
  expect "misura.sh --pratiche" 0 "Le pratiche: una per versione"
  n="$(grep -c '^chiamata' "${TMP}/esca.log")"
  if (( n == 0 )); then pass "misura.sh --pratiche: nessuna chiamata"
  else fail "misura.sh --pratiche: ${n} chiamate a claude"; fi
}

# verifica.sh: le uscite, la garanzia, gli esiti stampati.
t_verifica() {
  local w
  run "${E01}/verifica.sh" "${TMP}/assente"
  expect "verifica: spazio di lavoro assente" 2 "spazio di lavoro assente"
  ws w "${E01}/esercizio"
  run "${E01}/verifica.sh" "${w}"
  expect "verifica: il punto di partenza di M2-E01" 1 \
    "servono almeno v0 e v1"
  ws w "${E02}/esercizio"
  run "${E02}/verifica.sh" "${w}"
  expect "verifica: il punto di partenza di M2-E02" 1 \
    "servono almeno v0 e v1"
  e01 w
  run "${E01}/verifica.sh" "${w}"
  expect "verifica: il lavoro completo" 0 "${FINE}"
  if [[ "${OUT##*$'\n'}" == "${FINE}" ]]; then
    pass "verifica: la frase finale è l'ultima riga"
  else fail "verifica: l'ultima riga è «${OUT##*$'\n'}»"; fi
  expect "verifica: l'esito della pratica" 0 \
    "v1 rispetto a v0, chiarezza: confermata"
  expect "verifica: la garanzia confermata" 0 \
    "(--json-schema), 3 su 3: confermata"
  expect_riga "verifica: il telefono assente dalla risposta, un dato" 0 \
    "Il telefono del cliente nella risposta di v1: assente"
  giudizi_v0 "${w}" @tutti=1
  fx giudizio "${w}/giudizi/v1.json" "${HAIKU}" "${w}/rubrica.md" @tutti=0
  run "${E01}/verifica.sh" "${w}"
  expect "verifica: una pratica non confermata non fa fallire" 0 \
    "v1 rispetto a v0, chiarezza: non confermata in questa misura \
(criteri segnati [chiarezza] rispettati: 5 su 7 in v0, 3 su 7 in v1"
  expect_absent "verifica: mai «smentita»" "smentit"
  python3 -B -I - "${w}/giudizi/v1.json" <<'PY' || rotta "schema"
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
d["structured_output"]["criteri"][0]["rispettato"] = "sì"
json.dump(d, open(sys.argv[1], "w", encoding="utf-8"))
PY
  run "${E01}/verifica.sh" "${w}"
  expect "verifica: la garanzia non confermata esce 1" 1 \
    "garantisce un JSON convalidato secondo lo schema (--json-schema): in \
questa esecuzione no"
  expect "verifica: dove" 1 "criteri[0].rispettato: atteso boolean"
  expect_absent "verifica: senza la frase finale" "Fatto:"
}

# verifica.sh: il lavoro che manca, le precondizioni.
t_verifica_lavoro() {
  local w c
  e01 w
  rm "${w}/giudizi/v0-bis.json"
  run "${E01}/verifica.sh" "${w}"
  expect "verifica: manca il secondo giudizio" 1 \
    "manca giudizi/v0-bis.json: misurate di nuovo v0 (./misura.sh v0)"
  e01 w boh
  run "${E01}/verifica.sh" "${w}"
  expect "verifica: una pratica fuori elenco" 1 "si scrive una di"
  e01 w
  sed -i 's/^| v0 | partenza | una cosa |/| v0 | partenza | … |/' \
    "${w}/registro.md"
  run "${E01}/verifica.sh" "${w}"
  expect "verifica: una riga da compilare" 1 "compilate la riga di v0"
  e01 w
  versione "${w}" . v2 "${w}/prompt/v1.md" "${ALTRA}" sonnet low @tutti=1
  run "${E01}/verifica.sh" "${w}"
  expect "verifica: la riga di una versione misurata che manca" 1 \
    "registro.md non ha la riga di v2"
  e01 w
  cp "${w}/prompt/v0.md" "${w}/prompt/v1.md"
  run "${E01}/verifica.sh" "${w}"
  expect "verifica: v1 uguale a v0" 1 "prompt/v1.md è uguale a prompt/v0.md"
  albero c "${E01}"
  rm "${c}/esercizio/strumenti/kit.py"
  e01 w
  run "${c}/verifica.sh" "${w}"
  expect "verifica: il kit dell'elemento che manca" 2 "manca"
  if (( EUID == 0 )); then
    skip "verifica: registro.md che non si legge (da root ogni file si legge)"
    return 0
  fi
  e01 w
  chmod 000 "${w}/registro.md"
  run "${E01}/verifica.sh" "${w}"
  expect "verifica: registro.md che non si legge" 2 "non si legge"
  chmod 644 "${w}/registro.md"
}

# verifica.sh: il telefono del cliente nella risposta dell'ultima versione
# di M2-E01, un dato stampato senza esito (nessuna frase di Anthropic lo
# decide), e le famiglie di M2-E02.
t_verifica_casi() {
  local w
  e01 w
  versione "${w}" . v2 "${w}/prompt/v1.md" "${TEL}" sonnet low @tutti=1
  registro_e01 "${w}" v0:partenza v1:chiarezza v2:rimisura
  run "${E01}/verifica.sh" "${w}"
  expect_riga "verifica: il telefono ripetuto, un dato che non fa fallire" \
    0 "${TEL_PRESENTE}"
  expect_absent "verifica: niente più la riga «Vincoli, …» con un esito" \
    "Vincoli,"
  expect_absent "verifica: il telefono, mai «smentita»" "smentit"
  e01 w
  versione "${w}" . v2 "${w}/prompt/v1.md" \
    "Gentile cliente, la richiamiamo al 000-000-0103." sonnet low @tutti=1
  registro_e01 "${w}" v0:partenza v1:chiarezza v2:rimisura
  run "${E01}/verifica.sh" "${w}"
  expect_riga "verifica: il telefono con i trattini" 0 "${TEL_PRESENTE}"
  e01 w
  printf 'Un messaggio di un vostro cliente.\n' > "${w}/dati/messaggio.md"
  run "${E01}/verifica.sh" "${w}"
  expect "verifica: il telefono sul percorso A, non cercato" 0 \
    "Il telefono del cliente nella risposta di v1: non cercato (il \
messaggio non è quello di CiaspoLink: il telefono lo cerca controlli.tsv)"
  e02 w sviluppo supporto sistemi
  run "${E02}/verifica.sh" "${w}"
  expect "verifica: M2-E02 completo" 0 "${FINE}"
  expect "verifica: M2-E02 contesto, v1 e v2 rispettano gli stessi criteri" \
    0 "v2 rispetto a v1, contesto: non decisa (criteri segnati [contesto] \
rispettati: 2 su 2 in v1, 2 su 2 in v2; lo stesso numero"
  fx giudizio "${w}/sistemi/giudizi/v1.json" "${HAIKU}" \
    "${w}/sistemi/rubrica.md" @tutti=1 un_guasto=0 primo_controllo=0
  run "${E02}/verifica.sh" "${w}"
  expect "verifica: M2-E02 contesto confermata, più criteri in v2" 0 \
    "v2 rispetto a v1, contesto: confermata (criteri segnati [contesto] \
rispettati: 0 su 2 in v1, 2 su 2 in v2)"
  e02 w sistemi
  run "${E02}/verifica.sh" "${w}"
  expect "verifica: M2-E02 una famiglia con v2" 1 \
    "famiglie con due cicli (v2): 1 su tre; ne servono almeno due"
}

# Il telefono del cliente con i trattini, come in M2-D01: il controllo di
# controlli.tsv lo trova, e con spazi o punti come prima.
t_telefono() {
  local w t
  for t in '000-000-0103' '000 000-0103' '000.000.0103'; do
    ws w "${E01}/esercizio"
    mkdir -p "${w}/risposte" || rotta "mkdir"
    fx risposta "${w}/risposte/v0.json" "La richiamiamo al ${t}." "${SONNET}"
    run kit "${w}" controlla . v0
    expect "telefono: controlli.tsv trova «${t}»" 1 "✗ [chiarezza] il \
numero di telefono del cliente non compare (trovato «${t}»)"
  done
}

# Mette un BOM in testa a un file. Arguments: $1 il file.
con_bom() {
  { printf '%s' "${BOM}"; cat "$1"; } > "$1.bom" || rotta "BOM $1"
  mv "$1.bom" "$1" || rotta "BOM $1"
}

# Lo stesso esito di prima: l'uscita attesa e un OUT identico.
# Arguments: $1 il nome, $2 l'uscita attesa, $3 l'OUT di prima.
uguale() {
  if (( RC == $2 )) && [[ "${OUT}" == "$3" ]]; then
    pass "$1"
  else
    fail "$1 (rc=${RC}, attesa $2): ${OUT:0:300}"
  fi
}

# Un BOM in testa a controlli.tsv, a rubrica.md o a registro.md non cambia
# l'esito, anche quando la prima riga è un'affermazione o la tabella.
t_bom() {
  local w prima
  e01 w
  run kit "${w}" controlla . v1
  prima="${OUT}"
  con_bom "${w}/controlli.tsv"
  run kit "${w}" controlla . v1
  uguale "BOM: controlli.tsv dà lo stesso esito" 0 "${prima}"
  e01 w
  grep '^- \*\*' "${w}/rubrica.md" > "${w}/solo.md" || rotta "rubrica"
  mv "${w}/solo.md" "${w}/rubrica.md" || rotta "rubrica"
  run kit "${w}" giudizio . v1
  prima="${OUT}"
  con_bom "${w}/rubrica.md"
  run kit "${w}" giudizio . v1
  uguale "BOM: rubrica.md che comincia con un'affermazione, lo stesso esito" \
    0 "${prima}"
  expect "BOM: la prima affermazione resta" 0 "✓ [chiarezza] domande"
  e01 w
  grep '^|' "${w}/registro.md" > "${w}/solo.md" || rotta "registro"
  mv "${w}/solo.md" "${w}/registro.md" || rotta "registro"
  run kit "${w}" confronta . v0 v1
  prima="${OUT}"
  con_bom "${w}/registro.md"
  run kit "${w}" confronta . v0 v1
  uguale "BOM: registro.md che comincia con la tabella, lo stesso esito" 0 \
    "${prima}"
  e01 w
  con_bom "${w}/controlli.tsv"
  con_bom "${w}/rubrica.md"
  run "${E01}/verifica.sh" "${w}"
  expect "BOM: la verifica passa come senza" 0 "${FINE}"
}

# verifica.sh passa le uscite 0, 1 e 2 di verifica.py; un'altra uscita o
# un segnale diventa 2, con un messaggio, mai «non ancora». Un kit che si
# rompe al caricamento esce 2 da verifica.py, senza traceback.
t_uscite_verifica() {
  local c w u
  ws w "${E01}/esercizio"
  albero c "${E01}"
  for u in 0 1 2; do
    printf 'import sys\nsys.exit(%d)\n' "${u}" > "${c}/verifica.py" \
      || rotta "verifica.py finto"
    run "${c}/verifica.sh" "${w}"
    if (( RC == u )); then pass "verifica.sh: l'uscita ${u} di verifica.py"
    else fail "verifica.sh: l'uscita ${u} di verifica.py diventa ${RC}"; fi
  done
  printf 'import sys\nsys.exit(3)\n' > "${c}/verifica.py" \
    || rotta "verifica.py finto"
  run "${c}/verifica.sh" "${w}"
  expect "verifica.sh: un'uscita fuori contratto diventa 2" 2 \
    "verifica: il controllo è uscito con 3"
  printf 'import os\nimport signal\nos.kill(os.getpid(), signal.SIGTERM)\n' \
    > "${c}/verifica.py" || rotta "verifica.py finto"
  run "${c}/verifica.sh" "${w}"
  expect "verifica.sh: un segnale diventa 2" 2 \
    "verifica: il controllo è uscito con 143"
  albero c "${E01}"
  printf 'raise RuntimeError("kit rotto")\n' \
    > "${c}/esercizio/strumenti/kit.py" || rotta "kit rotto"
  e01 w
  run "${c}/verifica.sh" "${w}"
  expect "verifica: un kit che si rompe esce 2" 2 \
    "errore inatteso (RuntimeError: kit rotto)"
  expect_absent "verifica: un kit che si rompe, senza traceback" "Traceback"
}

# I due live.sh: le precondizioni senza chiamate, la prova intera con il
# claude finto.
t_live() {
  local e w c n f
  for e in "${E01}" "${E02}"; do
    senza_chiamate "${e##*/} live.sh: spazio di lavoro assente" \
      "spazio di lavoro assente" "${e}/_docente/live.sh" "${TMP}/assente"
    ws w "${e}/esercizio"
    rm "${w}/registro.md"
    senza_chiamate "${e##*/} live.sh: registro.md che manca" \
      "file assente o illeggibile: registro.md" "${e}/_docente/live.sh" "${w}"
  done
  albero c "${E01}"
  rm "${c}/soluzione/prompt/v1.md"
  ws w "${E01}/esercizio"
  senza_chiamate "M2-E01 live.sh: la versione di riferimento che manca" \
    "soluzione/prompt/v1.md" "${c}/_docente/live.sh" "${w}"
  albero c "${E02}"
  rm "${c}/soluzione/sistemi/prompt/v2.md"
  ws w "${E02}/esercizio"
  senza_chiamate "M2-E02 live.sh: la versione di riferimento che manca" \
    "soluzione/sistemi/prompt/v2.md" "${c}/_docente/live.sh" "${w}"
  # M2-E02: ogni famiglia prima della prima chiamata, anche l'ultima
  # (sistemi): prompt/v0.md, rubrica.md, controlli.tsv, dati/, e v0 che si
  # compone con i controlli di misura.sh.
  for f in prompt/v0.md rubrica.md controlli.tsv; do
    ws w "${E02}/esercizio"
    rm "${w}/sistemi/${f}"
    senza_chiamate "M2-E02 live.sh: sistemi/${f} che manca" \
      "file assente o illeggibile: sistemi/${f}" "${E02}/_docente/live.sh" \
      "${w}"
  done
  ws w "${E02}/esercizio"
  rm -r "${w}/sistemi/dati"
  senza_chiamate "M2-E02 live.sh: sistemi/dati che manca" \
    "cartella assente o illeggibile: sistemi/dati" \
    "${E02}/_docente/live.sh" "${w}"
  ws w "${E02}/esercizio"
  printf 'assente\tsolo due campi\n' >> "${w}/sistemi/controlli.tsv"
  senza_chiamate "M2-E02 live.sh: una riga rotta di sistemi/controlli.tsv" \
    "attesi tre campi" "${E02}/_docente/live.sh" "${w}"
  for e in "${E01}:7" "${E02}:21"; do
    ws w "${e%:*}/esercizio"
    finto "${e%:*}/_docente/live.sh" "${w}"
    n="$(chiamate)"
    expect "${e%:*}: live.sh con il claude finto" 0 "VERIFICA OK"
    if (( n == ${e##*:} )); then pass "${e%:*}: ${n} chiamate"
    else fail "${e%:*}: ${n} chiamate, attese ${e##*:}"; fi
  done
}

# Lo shellcheck degli script dei due elementi e di questo.
t_shellcheck() {
  local f
  for f in "${E01}/esercizio/misura.sh" "${E01}/verifica.sh" \
      "${E01}/_docente/live.sh" "${E02}/esercizio/misura.sh" \
      "${E02}/verifica.sh" "${E02}/_docente/live.sh" "${SELF}"; do
    if shellcheck -x "${f}" > /dev/null 2>&1; then
      pass "shellcheck ${f#"${RADICE}"/}"
    else
      fail "shellcheck ${f#"${RADICE}"/}"
    fi
  done
}

main() {
  local t
  for t in python3 shellcheck; do
    command -v "${t}" > /dev/null 2>&1 \
      || { echo "test_m2_kit: manca ${t}" >&2; exit 2; }
  done
  for t in "${E01}" "${E02}" "${FINTO}"; do
    [[ -e "${t}" ]] || { echo "test_m2_kit: manca ${t}" >&2; exit 2; }
  done
  TMP="$(mktemp -d)" || exit 2
  trap 'chmod -R u+rwX "${TMP}" 2>/dev/null; rm -rf "${TMP}"' EXIT
  cd "${RADICE}" || exit 2
  prepara
  t_formati
  t_stabilita
  t_pratiche
  t_esiti_criteri
  t_esiti_non_decisi
  t_esiti_stesso_testo
  t_avvisi
  t_rovinati
  t_misura
  t_verifica
  t_verifica_lavoro
  t_verifica_casi
  t_telefono
  t_bom
  t_uscite_verifica
  t_live
  t_shellcheck
  echo "PASS=${PASS} FAIL=${FAIL} SKIP=${SKIP}" \
    "CASES=$((PASS + FAIL + SKIP))/${CASES}"
  if (( PASS + FAIL + SKIP != CASES )); then
    echo "test_m2_kit: eseguite $((PASS + FAIL + SKIP)) prove, attese" \
      "${CASES}: un caso manca o non è contato" >&2
    exit 2
  fi
  (( FAIL == 0 )) || exit 1
}

main "$@"
