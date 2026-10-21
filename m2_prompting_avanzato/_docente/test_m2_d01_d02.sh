#!/bin/bash
#
# test_m2_d01_d02.sh -- le prove dei controlli di M2-D01 e M2-D02, per il
# docente (sta in _docente/, il materiale del docente):
#   - M2-D01, demo/controlla_istruzioni.py attraverso verifica.sh, su file
#     confronto.tsv sintetici scritti qui: ogni ramo di ogni esito (le
#     cinque istruzioni di B rispettate e non rispettate, sempre con
#     l'uscita 0; la garanzia sui token confermata, e non confermata con
#     l'uscita 1), i confini (120 e 121 parole, l'apostrofo, B uguale ad
#     A), i dati rovinati (intestazione, righe, numeri, byte che non sono
#     UTF-8, un file vuoto, una cartella al posto del file), mai con un
#     traceback; una fila di 100000 trattini, entro 20 secondi;
#   - M2-D02, demo/controlla_sistema.py attraverso verifica.sh, sugli
#     stessi rami: le due garanzie, che confrontano le tre chiamate fra
#     loro, con i loro confini e con molto contesto in comune; le
#     differenze stampate come dati; «ok» con maiuscole e punti; i dati
#     che mancano o rovinati;
#   - i due controlli da soli: senza argomenti, uno spazio assente, un
#     errore inatteso (uscita 2, senza traceback);
#   - i due verifica.sh: spazio di lavoro assente (2), punto di partenza
#     (1), la soluzione registrata (0, la frase finale e gli esiti della
#     registrazione), il file dei risultati che non si legge (2; da root
#     la prova si salta), python3 che manca (2), il controllo che manca
#     accanto (2);
#   - le righe come le scrivono i passi 3 dei README con leggi_json.py, da
#     JSON sintetici: risposte riuscite, is_error, nessun JSON, un JSON
#     senza usage, uno usage senza i token in entrata (mai uno 0);
#   - leggi_json.py da solo: token_entrata con uno usage senza nessuno dei
#     tre campi in entrata, assenti o null (uscita 1), con uno solo (la
#     somma); un JSON annidato a dismisura (uscita 1, senza traceback);
#   - i due live.sh: le precondizioni escono 2 senza chiamare claude (un
#     claude esca, primo nel PATH, scrive ogni chiamata in un registro che
#     deve restare vuoto); con il claude finto del modulo girano per
#     intero, mostrano gli esiti ed escono 0, e la verifica dopo di loro
#     esce 0; su una garanzia non confermata escono 1, con la riga d'esito
#     una volta sola e «(uscita 1)»; se verifica.sh esce 2 (in una copia,
#     con una verifica.sh finta) si fermano con 2;
#   - i due controlli compilati con -W error, senza avvisi;
#   - shellcheck -x sui due verifica.sh, sui due live.sh e su questo file,
#     con l'elenco delle segnalazioni vuoto.
# Gli spazi di lavoro nascono in una cartella temporanea: l'albero del
# repository non cambia. Il vero claude non viene mai chiamato.
#
# Uso:    m2_prompting_avanzato/_docente/test_m2_d01_d02.sh
# Uscita: 0 = tutte le prove passano · 1 = almeno una fallita · 2 =
#         precondizione (manca python3, jq, shellcheck o timeout, la
#         cartella di un elemento o il claude finto; le prove eseguite non
#         sono CASES)
set -uo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly MOD="${SELF%/_docente/*}"
readonly RADICE="${MOD%/*}"
readonly S1="${MOD}/s1_progettare_il_prompt"
readonly D01="${S1}/m2_1_cambiato_solo_il_prompt/M2-D01_prompt_a_contro_b"
readonly D02="${S1}/m2_3_ruoli_dei_messaggi/M2-D02_system_prompt_nascosto"
readonly CONTROLLO_D01="${D01}/demo/controlla_istruzioni.py"
readonly CONTROLLO_D02="${D02}/demo/controlla_sistema.py"
readonly FINTO="${MOD}/_docente/claude_finto.py"
readonly CASES=140
readonly NL=$'\n'
readonly FATTO="Fatto: ogni affermazione è stata messa alla prova; gli \
esiti sono qui sopra."
# Gli esiti di M2-D01: le cinque istruzioni di B e la garanzia.
readonly V_COLONNE="le colonne Problema, Quando, Impatto, Priorità, Team \
proposto"
readonly V_NONIND='«non indicato» dove manca un dato'
readonly V_NOME='niente nome del cliente'
readonly V_TEL='niente telefono del cliente'
readonly V_PAROLE='al massimo 120 parole'
readonly G_TOKEN='più token in entrata per B che per A'
readonly DOC_TOKEN="La documentazione garantisce che i token in entrata \
contano tutto l'input, e quello di B è più lungo di quello di A: in questa \
esecuzione no."
# Gli esiti di M2-D02: le due garanzie.
readonly G_SOST="con --system-prompt meno token in entrata del predefinito, \
benché la riga ci sia"
readonly G_AGG="con --append-system-prompt più token in entrata del \
predefinito"
readonly DOC_SOST="La documentazione garantisce che --system-prompt \
sostituisce l'intero prompt predefinito: in questa esecuzione no."
readonly DOC_AGG="La documentazione garantisce che --append-system-prompt \
aggiunge al prompt predefinito: in questa esecuzione no."
readonly SI=': rispettata'
readonly NO=': non rispettata in questa esecuzione'
readonly CONF=': confermata'
readonly NCONF=': non confermata in questa esecuzione'
# Una risposta sintetica a B che rispetta le cinque istruzioni, su una
# riga come in confronto.tsv: 6 + 8 + 9 + 12 = 35 parole.
readonly INTEST='| Problema | Quando | Impatto | Priorità | Team proposto |'
readonly TRATT='|---|---|---|---|---|'
readonly RIGA1='| Centralino fermo | Venerdì | Ordini persi | Alta | Assistenza
telefonia |'
readonly RIGA2='| Linea di riserva | non indicato | non indicato | Media |
Commerciale |'
readonly CODA='**Richieste del cliente:** indennizzo; linea di riserva.
**Dati mancanti:** numero della segnalazione.'
B_BUONA="${INTEST} ${TRATT} ${RIGA1} ${RIGA2} ${CODA}"
B_BUONA="${B_BUONA//${NL}/ }"
readonly B_BUONA
readonly A_RISP='Riassunto: Franco Fittizio, telefono +39 000 000 0103.'
# Una risposta riuscita il cui usage non ha nessuno dei tre campi dei
# token in entrata: leggi_json.py token_entrata non deve stampare 0.
SENZA_ENTRATA='{"type":"result","is_error":false,"result":"una risposta",'
SENZA_ENTRATA+='"usage":{"output_tokens":40}}'
readonly SENZA_ENTRATA
TMP=''
PASS=0
FAIL=0
SKIP=0
RC=0
OUT=''

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }
skip() { echo "  SKIP: $1"; SKIP=$((SKIP + 1)); }
err() { echo "test_m2_d01_d02.sh: $*" >&2; }

# Esegue un comando; RC e OUT (STDOUT e STDERR insieme) per expect.
run() { OUT="$("$@" 2>&1)"; RC=$?; }

# Uscita attesa E parola attesa (grep -F), mai un traceback (RU-01.T3).
# Arguments: $1 il nome, $2 l'uscita, $3 la parola, $4 (facoltativa) una
# parola che NON deve esserci (RU-01.T5).
expect() {
  if (( RC == $2 )) && grep -qF -- "$3" <<< "${OUT}" \
      && ! grep -qF -- 'Traceback' <<< "${OUT}" \
      && { [[ -z "${4:-}" ]] || ! grep -qF -- "$4" <<< "${OUT}"; }; then
    pass "$1"
  else
    fail "$1 (rc=${RC}, attesa $2, «$3», non «${4:-}»): ${OUT:0:400}"
  fi
}

# Uscita 0 e, come ultima riga, la frase della verifica riuscita.
# Arguments: $1 il nome.
expect_fatto() {
  if (( RC == 0 )) && [[ "${OUT##*"${NL}"}" == "${FATTO}" ]]; then
    pass "$1"
  else
    fail "$1 (rc=${RC}): l'ultima riga è «${OUT##*"${NL}"}»"
  fi
}

# Ogni parola data c'è nell'uscita, con l'uscita 0.
# Arguments: $1 il nome, poi le parole.
expect_tutte() {
  local p
  for p in "${@:2}"; do
    if (( RC != 0 )) || ! grep -qF -- "${p}" <<< "${OUT}"; then
      fail "$1 (rc=${RC}): manca «${p}»: ${OUT:0:400}"
      return 0
    fi
  done
  pass "$1"
}

# Un nuovo spazio di lavoro, con il contenuto delle cartelle date.
# Arguments: $1 la variabile da assegnare, poi le cartelle da copiare.
ws() {
  local __w __c
  __w="$(mktemp -d "${TMP}/ws.XXXXXX")" || { err "mktemp"; exit 2; }
  for __c in "${@:2}"; do
    cp -R "${__c}/." "${__w}/" || { err "cp ${__c}"; exit 2; }
  done
  printf -v "$1" '%s' "${__w}"
}

# Uno spazio di lavoro di M2-D01 con confronto.tsv, righe A e B.
# Arguments: $1 la variabile da assegnare; $2 e $3 i token in entrata e
# la risposta di A; $4 e $5 quelli di B.
tsv_d01() {
  local __d
  ws __d
  {
    printf 'prompt\ttoken_entrata\ttoken_uscita\trisposta\n'
    printf 'A\t%s\t50\t%s\n' "$2" "$3"
    printf 'B\t%s\t50\t%s\n' "$4" "$5"
  } > "${__d}/confronto.tsv"
  printf -v "$1" '%s' "${__d}"
}

# verifica.sh di M2-D01 su un confronto.tsv scritto con tsv_d01.
# Arguments: quelli di tsv_d01 dopo la variabile.
d01() {
  local w
  tsv_d01 w "$@"
  run "${D01}/verifica.sh" "${w}"
}

# Uno spazio di lavoro di M2-D02 con sistema.tsv.
# Arguments: $1 la variabile da assegnare; poi token in entrata e
# risposta di predefinito ($2, $3), aggiunto ($4, $5), sostituito ($6, $7).
tsv_d02() {
  local __d
  ws __d
  {
    printf 'variante\ttoken_entrata\trisposta\n'
    printf 'predefinito\t%s\t%s\n' "$2" "$3"
    printf 'aggiunto\t%s\t%s\n' "$4" "$5"
    printf 'sostituito\t%s\t%s\n' "$6" "$7"
  } > "${__d}/sistema.tsv"
  printf -v "$1" '%s' "${__d}"
}

# verifica.sh di M2-D02 su un sistema.tsv scritto con tsv_d02.
# Arguments: quelli di tsv_d02 dopo la variabile.
d02() {
  local w
  tsv_d02 w "$@"
  run "${D02}/verifica.sh" "${w}"
}

# Il JSON di una risposta riuscita di claude -p.
# Arguments: $1 il testo della risposta, $2 cache_creation_input_tokens.
# Outputs: il JSON.
json_ok() {
  python3 -B -I -c 'import json, sys
print(json.dumps({"type": "result", "is_error": False, "result": sys.argv[1],
                  "usage": {"input_tokens": 2, "output_tokens": 40,
                            "cache_creation_input_tokens": int(sys.argv[2]),
                            "cache_read_input_tokens": 0},
                  "modelUsage": {"claude-finto": {}}}, ensure_ascii=False))' \
    "$1" "$2"
}

# Una riga di confronto.tsv come la scrive il passo 3 del README di
# M2-D01: lo stesso printf, il leggi_json.py dello spazio di lavoro. Gli
# errori di leggi_json.py restano fuori: nel README vanno sul terminale,
# qui conta che cosa finisce nel file.
# Arguments: $1 lo spazio di lavoro, $2 il prompt, $3 il JSON.
riga_d01() {
  printf '%s\t%s\t%s\t%s\n' "$2" \
    "$(python3 -B "$1/leggi_json.py" token_entrata <<< "$3" 2>/dev/null)" \
    "$(python3 -B "$1/leggi_json.py" token_uscita <<< "$3" 2>/dev/null)" \
    "$(python3 -B "$1/leggi_json.py" result <<< "$3" 2>/dev/null)" \
    >> "$1/confronto.tsv"
}

# Una riga di sistema.tsv come la scrive il passo 3 del README di M2-D02.
# Arguments: $1 lo spazio di lavoro, $2 la variante, $3 il JSON.
riga_d02() {
  printf '%s\t%s\t%s\n' "$2" \
    "$(python3 -B "$1/leggi_json.py" token_entrata <<< "$3" 2>/dev/null)" \
    "$(python3 -B "$1/leggi_json.py" result <<< "$3" 2>/dev/null)" \
    >> "$1/sistema.tsv"
}

# Un comando con il claude esca primo nel PATH; il registro riparte vuoto.
# Arguments: le variabili NOME=valore e il comando.
esca() {
  : > "${TMP}/esca.log"
  run env PATH="${TMP}/esca:${PATH}" HANDSON_NO_PAUSE=1 \
    ESCA_LOG="${TMP}/esca.log" "$@"
}

# Un comando con il claude finto del modulo primo nel PATH.
# Arguments: il comando.
finto_run() {
  run env PATH="${TMP}/finto:${PATH}" HANDSON_NO_PAUSE=1 \
    FINTO_LOG="${TMP}/finto.log" "$@"
}

# Una copia dell'elemento con la libreria accanto, come nel repository, in
# cui verifica.sh è finta: stampa una riga ed esce 2. L'albero del
# repository non cambia. Arguments: $1 la variabile da assegnare
# (l'elemento nella copia), $2 l'elemento.
albero_due() {
  local __a __rel="${2#"${RADICE}"/}"
  __a="$(mktemp -d "${TMP}/albero.XXXXXX")" || { err "mktemp"; exit 2; }
  mkdir -p "${__a}/tools" "${__a}/${__rel}" || exit 2
  cp -- "${RADICE}/tools/lib_handson.sh" "${__a}/tools/" || exit 2
  cp -R "$2/." "${__a}/${__rel}/" || exit 2
  printf '%s\n' '#!/bin/bash' 'echo "verifica finta"' 'exit 2' \
    > "${__a}/${__rel}/verifica.sh" || exit 2
  chmod 755 "${__a}/${__rel}/verifica.sh" || exit 2
  printf -v "$1" '%s' "${__a}/${__rel}"
}

# Il claude esca non è stato chiamato, nemmeno per --version.
# Arguments: $1 il nome.
nessuna_chiamata() {
  if [[ -f "${TMP}/esca.log" && ! -s "${TMP}/esca.log" ]]; then
    pass "$1"
  else
    fail "$1: $(cat -- "${TMP}/esca.log" 2>&1)"
  fi
}

# In ${TMP}: esca/claude, che scrive ogni chiamata nel registro ed esce 1;
# finto/claude, il claude finto del modulo; solo_readlink/, un PATH con
# il solo readlink (senza python3).
prepara_bin() {
  mkdir -p "${TMP}/esca" "${TMP}/finto" "${TMP}/solo_readlink" || exit 2
  # shellcheck disable=SC2016  # il corpo è del claude esca
  printf '%s\n' '#!/bin/bash' \
    'printf "chiamata %s\n" "$*" >> "${ESCA_LOG:?}"' 'exit 1' \
    > "${TMP}/esca/claude" || exit 2
  cp -- "${FINTO}" "${TMP}/finto/claude" || exit 2
  chmod 755 "${TMP}/esca/claude" "${TMP}/finto/claude" || exit 2
  ln -s "$(command -v readlink)" "${TMP}/solo_readlink/readlink" || exit 2
}

# --- Le prove --------------------------------------------------------------

# M2-D01: la risposta che rispetta tutto, poi le colonne.
t_d01_colonne() {
  local b
  d01 937 "${A_RISP}" 1211 "${B_BUONA}"
  expect "D01: B rispetta le cinque istruzioni, uscita 0" 0 \
    "${G_TOKEN}${CONF}" "${NO}"
  expect_fatto "D01: l'ultima riga è la frase finale"
  expect "D01: i numeri letti di B" 0 \
    "B, il prompt di cinque righe: 1211 token in entrata, 50 in uscita; 35"
  expect "D01: i dati di A, senza verdetto" 0 \
    "il nome del cliente: A sì · B no"
  b="| Problema | Quando | Impatto | Priorità | |---|---|---|---| | Fermo |"
  d01 937 "${A_RISP}" 1211 "${b} Venerdì | Ordini | Alta | non indicato"
  expect "D01: quattro colonne, non rispettata e uscita 0" 0 \
    "${V_COLONNE}${NO}"
  d01 937 "${A_RISP}" 1211 \
    "${B_BUONA/| Problema | Quando |/| Quando | Problema |}"
  expect "D01: le colonne in un altro ordine" 0 "${V_COLONNE}${NO}"
  b="${INTEST% |} | Note | ${TRATT}---| ${RIGA1//${NL}/ } non indicato"
  d01 937 "${A_RISP}" 1211 "${b}"
  expect "D01: sei colonne" 0 "${V_COLONNE}${NO}"
  d01 937 "${A_RISP}" 1211 "${INTEST} ${RIGA2//${NL}/ }"
  expect "D01: senza la riga dei trattini" 0 "la tabella: A nessuna · B nessuna"
  expect "D01: senza trattini, colonne non rispettate" 0 "${V_COLONNE}${NO}"
  d01 937 "${A_RISP}" 1211 "${B_BUONA/| Problema |/| Il problema |}"
  expect "D01: con le barre, «Il problema» non è «Problema»" 0 \
    "${V_COLONNE}${NO}"
  d01 937 "${A_RISP}" 1211 "${B_BUONA} | Dato | Valore | |---|---| | Ticket |"
  expect "D01: due tabelle, conta la prima" 0 "${V_COLONNE}${SI}"
  b="| **Problema** | **Quando** | **Impatto** | **Priorità (bassa/media/"
  b+="alta/urgente)** | **Team proposto** | |:---|:---:|---|---|---:|"
  d01 937 "${A_RISP}" 1211 "${b} ${RIGA2//${NL}/ }"
  expect "D01: grassetto, «Priorità (…)» e allineamenti: rispettata" 0 \
    "${V_COLONNE}${SI}"
  b="Scheda: Problema | Quando | Impatto | Priorità | Team proposto --- |"
  d01 937 "${A_RISP}" 1211 "${b} --- | --- | --- | --- Fermo | non indicato"
  expect "D01: una tabella senza le barre esterne: rispettata" 0 \
    "${V_COLONNE}${SI}"
}

# M2-D01: «non indicato», il nome, il telefono.
t_d01_formule() {
  local t
  d01 937 "${A_RISP}" 1211 "${B_BUONA//non indicato/da chiedere}"
  expect "D01: senza «non indicato»" 0 "${V_NONIND}${NO}"
  d01 937 "${A_RISP}" 1211 "${B_BUONA//non indicato/NON INDICATO}"
  expect "D01: «NON INDICATO» in maiuscolo vale" 0 "${V_NONIND}${SI}"
  d01 937 "${A_RISP}" 1211 "${B_BUONA} Scrive Franco."
  expect "D01: il nome di chi scrive" 0 "${V_NOME}${NO}"
  d01 937 "${A_RISP}" 1211 "${B_BUONA} Cliente: Falegnameria Fittizia."
  expect "D01: il nome dell'azienda" 0 "${V_NOME}${NO}"
  d01 937 "${A_RISP}" 1211 "${B_BUONA} Un caso fittizio."
  expect "D01: «fittizio» minuscolo non è un nome" 0 "${V_NOME}${SI}"
  for t in '+39 000 000 0103' '000.000.0103' '000-000-0103' '0000000103'; do
    d01 937 "${A_RISP}" 1211 "${B_BUONA} Richiamare al ${t}."
    expect "D01: il telefono scritto «${t}»" 0 "${V_TEL}${NO}"
  done
  d01 937 "${A_RISP}" 1211 "${B_BUONA} Segnalazione TK-0103."
  expect "D01: «TK-0103» non è il telefono" 0 "${V_TEL}${SI}"
}

# M2-D01: le parole al confine; la garanzia e i suoi confini.
t_d01_parole_garanzia() {
  local riempi
  riempi="$(printf ' parola%.0s' {1..84})"
  d01 937 "${A_RISP}" 1211 "${B_BUONA} l'assistenza${riempi}"
  expect "D01: 120 parole (l'apostrofo unisce, la tabella non conta)" 0 \
    "50 in uscita; 120 parole" "${V_PAROLE}${NO}"
  d01 937 "${A_RISP}" 1211 "${B_BUONA} l'assistenza${riempi} parola"
  expect "D01: 121 parole" 0 "${V_PAROLE}${NO}"
  d01 1211 "${A_RISP}" 937 "${B_BUONA}"
  expect "D01: B con meno token di A, uscita 1" 1 "${G_TOKEN}${NCONF}" \
    "${FATTO}"
  expect "D01: e la frase della documentazione" 1 "${DOC_TOKEN}"
  d01 937 "${A_RISP}" 937 "${B_BUONA}"
  expect "D01: B con gli stessi token di A, uscita 1" 1 "${G_TOKEN}${NCONF}"
  d01 937 "${A_RISP}" 938 "${B_BUONA}"
  expect "D01: B con un token più di A, uscita 0" 0 "${G_TOKEN}${CONF}"
  d01 0937 "${A_RISP}" 01211 "${B_BUONA}"
  expect "D01: numeri con uno zero davanti" 0 \
    "A, «Riassumi.»: 937 token in entrata"
}

# M2-D01: risposte e numeri che mancano, intestazioni rovinate.
t_d01_mancanze() {
  local w
  d01 937 "" 1211 "${B_BUONA}"
  expect "D01: la risposta di A vuota" 1 "Manca la risposta al prompt A."
  ws w
  printf 'prompt\ttoken_entrata\ttoken_uscita\trisposta\nA\t937\t50\t%s\n' \
    "${A_RISP}" > "${w}/confronto.tsv"
  run "${D01}/verifica.sh" "${w}"
  expect "D01: la riga B assente" 1 "Manca la risposta al prompt B."
  d01 937 "${A_RISP}" 12abc "${B_BUONA}"
  expect "D01: token di B che non sono numeri («12abc»)" 1 \
    "Token in entrata di A o di B mancanti o non numerici."
  d01 937 "${A_RISP}" -5 "${B_BUONA}"
  expect "D01: token negativi" 1 "mancanti o non numerici"
  ws w
  printf 'prompt\ttoken\trisposta\n' > "${w}/confronto.tsv"
  run "${D01}/verifica.sh" "${w}"
  expect "D01: un'altra intestazione" 1 \
    "la prima riga deve essere l'intestazione"
  ws w
  : > "${w}/confronto.tsv"
  run "${D01}/verifica.sh" "${w}"
  expect "D01: confronto.tsv vuoto" 1 "la prima riga deve essere"
  ws w
  printf '\xff\xfe\x00\x01 binario\n\x80\x81\n' > "${w}/confronto.tsv"
  run "${D01}/verifica.sh" "${w}"
  expect "D01: byte che non sono UTF-8" 1 "la prima riga deve essere"
}

# M2-D01: CRLF, BOM, righe ripetute, una cartella, il controllo da solo.
t_d01_forme() {
  local w
  tsv_d01 w 937 "${A_RISP}" 1211 "${B_BUONA}"
  sed -i 's/$/\r/' "${w}/confronto.tsv"
  run "${D01}/verifica.sh" "${w}"
  expect "D01: righe con CRLF" 0 "${V_COLONNE}${SI}"
  tsv_d01 w 937 "${A_RISP}" 1211 "${B_BUONA}"
  { printf '\xef\xbb\xbf'; cat -- "${w}/confronto.tsv"; } > "${w}/bom"
  mv -- "${w}/bom" "${w}/confronto.tsv"
  run "${D01}/verifica.sh" "${w}"
  expect "D01: il BOM in testa" 0 "${G_TOKEN}${CONF}"
  tsv_d01 w 937 "${A_RISP}" 1 "${B_BUONA}"
  printf 'B\t1211\t50\t%s\n' "${B_BUONA}" >> "${w}/confronto.tsv"
  run "${D01}/verifica.sh" "${w}"
  expect "D01: una riga ripetuta: vale l'ultima" 0 "${G_TOKEN}${CONF}"
  ws w
  mkdir "${w}/confronto.tsv"
  run "${D01}/verifica.sh" "${w}"
  expect "D01: una cartella al posto di confronto.tsv" 2 "non si legge"
  run python3 -B -I "${CONTROLLO_D01}"
  expect "D01: il controllo senza argomenti" 2 "Uso:"
  run python3 -B -I "${CONTROLLO_D01}" "${TMP}/assente"
  expect "D01: il controllo su uno spazio assente" 2 \
    "spazio di lavoro assente"
  inatteso "${CONTROLLO_D01}"
  expect "D01: un errore inatteso esce 2, senza traceback" 2 \
    "errore inatteso (RuntimeError: guasto finto)"
  tsv_d01 w 937 "${A_RISP}" 1211 \
    "$(printf '%*s' 100000 '' | tr ' ' '-') ${B_BUONA}"
  run timeout 20 "${D01}/verifica.sh" "${w}"
  expect "D01: 100000 trattini prima della tabella, entro 20 secondi" 0 \
    "${V_COLONNE}${SI}"
}

# Il ramo dell'errore inatteso di un controllo: main() con un controlla()
# che solleva un'eccezione. Arguments: $1 il controllo.
inatteso() {
  run python3 -B -I -c 'import importlib.util, sys
spec = importlib.util.spec_from_file_location("controllo", sys.argv[1])
modulo = importlib.util.module_from_spec(spec)
spec.loader.exec_module(modulo)
def guasto(_):
    raise RuntimeError("guasto finto")
modulo.controlla = guasto
sys.exit(modulo.main(["spazio"]))' "$1"
}

# M2-D01, il contratto di verifica.sh, e la soluzione registrata.
t_d01_contratto() {
  local w
  run "${D01}/verifica.sh" "${TMP}/assente"
  expect "D01 verifica.sh: spazio di lavoro assente" 2 \
    "spazio di lavoro assente"
  ws w "${D01}/demo"
  run "${D01}/verifica.sh" "${w}"
  expect "D01 verifica.sh: il punto di partenza" 1 \
    "Manca confronto.tsv: eseguite i passi del README."
  ws w "${D01}/demo" "${D01}/soluzione"
  run "${D01}/verifica.sh" "${w}"
  expect_fatto "D01 verifica.sh: la soluzione registrata esce 0"
  expect "D01 verifica.sh: registrazione, 131 parole" 0 \
    "1211 token in entrata, 452 in uscita; 131 parole"
  expect "D01 verifica.sh: registrazione, 120 parole non rispettata" 0 \
    "${V_PAROLE}${NO}"
  expect_tutte "D01 verifica.sh: registrazione, le altre quattro" \
    "${V_COLONNE}${SI}" "${V_NONIND}${SI}" "${V_NOME}${SI}" "${V_TEL}${SI}"
  expect "D01 verifica.sh: registrazione, garanzia confermata" 0 \
    "${G_TOKEN}${CONF}"
  run env PATH="${TMP}/solo_readlink" "${D01}/verifica.sh" "${w}"
  expect "D01 verifica.sh: senza python3" 2 "manca python3"
  cp -- "${D01}/verifica.sh" "${TMP}/verifica_d01.sh"
  run "${TMP}/verifica_d01.sh" "${w}"
  expect "D01 verifica.sh: senza il controllo accanto" 2 \
    "verifica: manca $(readlink -f "${TMP}")/demo/controlla_istruzioni.py"
  if (( EUID == 0 )); then
    skip "D01 verifica.sh: confronto.tsv che non si legge (da root si legge)"
    return 0
  fi
  chmod 000 "${w}/confronto.tsv"
  run "${D01}/verifica.sh" "${w}"
  expect "D01 verifica.sh: confronto.tsv che non si legge" 2 "non si legge"
}

# M2-D02: le due garanzie confrontano le tre chiamate fra loro, con i loro
# confini; il contesto uguale nelle tre chiamate non le cambia.
t_d02_garanzie() {
  d02 3669 ok 3689 ok 567 ok
  expect "D02: tutto confermato e rispettato, uscita 0" 0 \
    "${G_SOST}${CONF}" "${NO}"
  expect "D02: la seconda garanzia confermata" 0 "${G_AGG}${CONF}"
  expect_fatto "D02: l'ultima riga è la frase finale"
  expect "D02: le differenze, come dati" 0 "il predefinito pesa 3102 token \
più di sostituito; la riga in coda ne aggiunge 20"
  d02 13000 ok 13020 ok 10000 ok
  expect "D02: molto contesto in comune, le garanzie restano confermate" 0 \
    "${G_SOST}${CONF}" "${NCONF}"
  d02 1000 ok 1001 ok 1000 ok
  expect "D02: sostituito uguale al predefinito, uscita 1" 1 \
    "${G_SOST}${NCONF}" "${FATTO}"
  expect "D02: e la frase della documentazione, nessuna causa" 1 \
    "${DOC_SOST}" "Una causa possibile"
  expect "D02: sostituito uguale, la differenza 0 come dato" 1 \
    "il predefinito pesa 0 token più di sostituito"
  d02 1000 ok 1001 ok 999 ok
  expect "D02: sostituito un token sotto il predefinito, uscita 0" 0 \
    "${G_SOST}${CONF}"
  d02 1000 ok 1001 ok 1200 ok
  expect "D02: sostituito sopra il predefinito, la differenza come dato" 1 \
    "il predefinito pesa 200 token meno di sostituito"
  d02 1000 ok 1000 ok 100 ok
  expect "D02: aggiunto uguale al predefinito, uscita 1" 1 \
    "${G_AGG}${NCONF}" "${FATTO}"
  expect "D02: e la sua frase della documentazione" 1 "${DOC_AGG}"
  expect "D02: aggiunto uguale, la differenza 0 come dato" 1 \
    "la riga in coda ne aggiunge 0"
  d02 1000 ok 1001 ok 100 ok
  expect "D02: aggiunto un token sopra il predefinito, uscita 0" 0 \
    "${G_AGG}${CONF}"
  d02 1000 ok 999 ok 100 ok
  expect "D02: aggiunto sotto il predefinito, la differenza come dato" 1 \
    "la riga in coda ne toglie 1"
}

# M2-D02: «ok» rispettata e no, sempre con l'uscita 0.
t_d02_ok() {
  d02 3669 'OK.' 3689 '. Ok' 567 ' ok '
  expect "D02: «OK.», «. Ok» e « ok » valgono «ok»" 0 "sostituito${SI}" \
    "${NO}"
  d02 3669 ok 3689 'Ok!' 567 'ok, certo'
  expect "D02: «Ok!» non rispettata" 0 "aggiunto${NO}"
  expect "D02: «ok, certo» non rispettata" 0 "sostituito${NO}"
  expect_fatto "D02: una raccomandazione non rispettata non fa fallire"
  d02 3669 "$(printf 'parola %.0s' {1..30})" 3689 ok 567 ok
  expect "D02: una risposta lunga si stampa accorciata" 0 "…»"
}

# M2-D02: i dati che mancano e le forme del file.
t_d02_dati() {
  local w
  d02 3669 ok 3689 ok 567 ''
  expect "D02: la risposta di sostituito vuota" 1 \
    "Manca la risposta della variante sostituito."
  d02 3669 ok 12abc ok 567 ok
  expect "D02: token che non sono numeri («12abc»)" 1 \
    "Manca il numero di token della variante aggiunto."
  d02 -5 ok 3689 ok 567 ok
  expect "D02: token negativi" 1 \
    "Manca il numero di token della variante predefinito."
  ws w
  printf 'variante\ttoken\n' > "${w}/sistema.tsv"
  run "${D02}/verifica.sh" "${w}"
  expect "D02: un'altra intestazione" 1 "la prima riga deve essere"
  ws w
  : > "${w}/sistema.tsv"
  run "${D02}/verifica.sh" "${w}"
  expect "D02: sistema.tsv vuoto" 1 "la prima riga deve essere"
  ws w
  printf '\xff\xfe\x00\x01 binario\n\x80\x81\n' > "${w}/sistema.tsv"
  run "${D02}/verifica.sh" "${w}"
  expect "D02: byte che non sono UTF-8" 1 "la prima riga deve essere"
  tsv_d02 w 3669 ok 3689 ok 567 ok
  sed -i 's/$/\r/' "${w}/sistema.tsv"
  run "${D02}/verifica.sh" "${w}"
  expect "D02: righe con CRLF" 0 "sostituito${SI}"
  tsv_d02 w 3669 ok 3689 ok 567 ok
  { printf '\xef\xbb\xbf'; cat -- "${w}/sistema.tsv"; } > "${w}/bom"
  mv -- "${w}/bom" "${w}/sistema.tsv"
  run "${D02}/verifica.sh" "${w}"
  expect "D02: il BOM in testa" 0 "${G_SOST}${CONF}"
  tsv_d02 w 3669 ok 3689 ok 4000 ok
  printf 'sostituito\t567\tok\n' >> "${w}/sistema.tsv"
  run "${D02}/verifica.sh" "${w}"
  expect "D02: una riga ripetuta: vale l'ultima" 0 "${G_SOST}${CONF}"
  ws w
  mkdir "${w}/sistema.tsv"
  run "${D02}/verifica.sh" "${w}"
  expect "D02: una cartella al posto di sistema.tsv" 2 "non si legge"
  run python3 -B -I "${CONTROLLO_D02}"
  expect "D02: il controllo senza argomenti" 2 "Uso:"
  run python3 -B -I "${CONTROLLO_D02}" "${TMP}/assente"
  expect "D02: il controllo su uno spazio assente" 2 \
    "spazio di lavoro assente"
  inatteso "${CONTROLLO_D02}"
  expect "D02: un errore inatteso esce 2, senza traceback" 2 \
    "errore inatteso (RuntimeError: guasto finto)"
}

# M2-D02, il contratto di verifica.sh, e la soluzione registrata.
t_d02_contratto() {
  local w
  run "${D02}/verifica.sh" "${TMP}/assente"
  expect "D02 verifica.sh: spazio di lavoro assente" 2 \
    "spazio di lavoro assente"
  ws w "${D02}/demo"
  run "${D02}/verifica.sh" "${w}"
  expect "D02 verifica.sh: il punto di partenza" 1 \
    "Manca sistema.tsv: eseguite i passi del README."
  ws w "${D02}/demo" "${D02}/soluzione"
  run "${D02}/verifica.sh" "${w}"
  expect_fatto "D02 verifica.sh: la soluzione registrata esce 0"
  expect "D02 verifica.sh: registrazione, i numeri" 0 \
    "sostituito   567 token in entrata, risposta «ok»"
  expect_tutte "D02 verifica.sh: registrazione, «ok» 3 su 3, due garanzie" \
    "predefinito${SI}" "aggiunto${SI}" "sostituito${SI}" \
    "${G_SOST}${CONF}" "${G_AGG}${CONF}"
  run env PATH="${TMP}/solo_readlink" "${D02}/verifica.sh" "${w}"
  expect "D02 verifica.sh: senza python3" 2 "manca python3"
  cp -- "${D02}/verifica.sh" "${TMP}/verifica_d02.sh"
  run "${TMP}/verifica_d02.sh" "${w}"
  expect "D02 verifica.sh: senza il controllo accanto" 2 \
    "verifica: manca $(readlink -f "${TMP}")/demo/controlla_sistema.py"
  if (( EUID == 0 )); then
    skip "D02 verifica.sh: sistema.tsv che non si legge (da root si legge)"
    return 0
  fi
  chmod 000 "${w}/sistema.tsv"
  run "${D02}/verifica.sh" "${w}"
  expect "D02 verifica.sh: sistema.tsv che non si legge" 2 "non si legge"
}

# Le righe dei passi 3 dei README, da JSON sintetici, con leggi_json.py.
t_passi_readme() {
  local w a b tabella
  a="$(json_ok "${A_RISP}" 935)"
  tabella="${INTEST}${NL}${TRATT}${NL}${RIGA1//${NL}/ }${NL}"
  tabella+="${RIGA2//${NL}/ }${NL}${NL}${CODA}"
  for b in "$(json_ok "${tabella}" 1209)" \
      '{"type":"result","is_error":true,"result":"Errore finto"}' '' \
      '{"type":"result","is_error":false,"result":"una risposta"}' \
      "${SENZA_ENTRATA}"; do
    ws w "${D01}/demo"
    printf 'prompt\ttoken_entrata\ttoken_uscita\trisposta\n' \
      > "${w}/confronto.tsv"
    riga_d01 "${w}" A "${a}"
    riga_d01 "${w}" B "${b}"
    run "${D01}/verifica.sh" "${w}"
    case "${b}" in
      *Problema*) expect "passi D01: una tabella su più righe, unita" 0 \
        "${V_COLONNE}${SI}" ;;
      *is_error\":true*) expect "passi D01: B con is_error" 1 \
        "Manca la risposta al prompt B." ;;
      '') expect "passi D01: B senza JSON" 1 \
        "Manca la risposta al prompt B." ;;
      *output_tokens*) expect "passi D01: B senza i token in entrata" 1 \
        "mancanti o non numerici" "${NCONF}" ;;
      *) expect "passi D01: B senza usage" 1 "mancanti o non numerici" ;;
    esac
  done
  for b in "$(json_ok ok 3687)" '{"type":"result","is_error":true}'; do
    ws w "${D02}/demo"
    printf 'variante\ttoken_entrata\trisposta\n' > "${w}/sistema.tsv"
    riga_d02 "${w}" predefinito "$(json_ok ok 3667)"
    riga_d02 "${w}" aggiunto "${b}"
    riga_d02 "${w}" sostituito "$(json_ok ok 565)"
    run "${D02}/verifica.sh" "${w}"
    if [[ "${b}" == *is_error\":true* ]]; then
      expect "passi D02: aggiunto con is_error" 1 \
        "Manca la risposta della variante aggiunto."
    else
      expect_fatto "passi D02: tre risposte riuscite"
    fi
  done
}

# leggi_json.py token_entrata: uno usage senza nessuno dei tre campi in
# entrata (assenti o null) è un errore, con l'uscita 1 dei dati, mai uno
# 0; uno solo dei tre basta.
t_leggi_json() {
  local lj="${D01}/demo/leggi_json.py" j nulli
  nulli='{"is_error":false,"result":"ok","usage":{"input_tokens":null,'
  nulli+='"cache_creation_input_tokens":null,"cache_read_input_tokens":null,'
  nulli+='"output_tokens":40}}'
  for j in "${SENZA_ENTRATA}" "${nulli}"; do
    run python3 -B -I "${lj}" token_entrata <<< "${j}"
    expect "leggi_json: usage senza i token in entrata, uscita 1" 1 \
      "«usage» non riporta i token in entrata"
  done
  j='{"is_error":false,"result":"ok","usage":{"cache_read_input_tokens":7}}'
  run python3 -B -I "${lj}" token_entrata <<< "${j}"
  if (( RC == 0 )) && [[ "${OUT}" == '7' ]]; then
    pass "leggi_json: uno solo dei tre campi in entrata basta"
  else
    fail "leggi_json: un campo solo (rc=${RC}): ${OUT:0:200}"
  fi
  printf '[%.0s' {1..100000} > "${TMP}/annidato.json"
  run python3 -B -I "${lj}" result < "${TMP}/annidato.json"
  expect "leggi_json: un JSON annidato a dismisura, uscita 1" 1 \
    "non è un JSON valido"
}

# I live.sh: ogni precondizione esce 2 prima di chiamare claude.
t_live_precondizioni() {
  local e w nome manca
  for e in "${D01}" "${D02}"; do
    nome="${e##*/}"
    manca=prompt-b.md
    if [[ "${e}" == "${D02}" ]]; then
      manca=domanda.txt
    fi
    esca "${e}/_docente/live.sh" "${TMP}/assente"
    expect "${nome} live.sh: spazio di lavoro assente" 2 \
      "spazio di lavoro assente"
    nessuna_chiamata "${nome} live.sh: spazio assente, nessuna chiamata"
    ws w "${e}/demo"
    esca PN_MODELLO=fable "${e}/_docente/live.sh" "${w}"
    expect "${nome} live.sh: modello non ammesso" 2 "non ammesso"
    nessuna_chiamata "${nome} live.sh: modello non ammesso, nessuna chiamata"
    ws w "${e}/demo"
    rm -- "${w}/${manca}"
    esca "${e}/_docente/live.sh" "${w}"
    expect "${nome} live.sh: ${manca} che manca" 2 \
      "file assente o illeggibile: ${manca}"
    nessuna_chiamata "${nome} live.sh: ${manca} che manca, nessuna chiamata"
  done
}

# I live.sh con il claude finto del modulo: girano per intero, escono 0, e
# la verifica dopo di loro esce 0.
t_live_finto() {
  local e w
  for e in "${D01}" "${D02}"; do
    ws w "${e}/demo"
    finto_run "${e}/_docente/live.sh" "${w}"
    expect "${e##*/} live.sh con il claude finto: uscita 0" 0 "VERIFICA OK"
    expect "${e##*/} live.sh mostra gli esiti e la frase finale" 0 "${FATTO}"
    run "${e}/verifica.sh" "${w}"
    expect_fatto "${e##*/}: dopo live.sh la verifica esce 0"
  done
}

# I live.sh su una garanzia non confermata, con il claude finto: escono 1,
# con la riga d'esito e il verdetto «(uscita 1)», come chiede la suite del
# modulo. M2-D01: un prompt B di una riga, più corto di A; M2-D02: una riga
# lunga al posto del system prompt, più pesante del predefinito finto.
t_live_ko() {
  local w
  ws w "${D01}/demo"
  printf 'Riassumi.\n' > "${w}/prompt-b.md"
  finto_run "${D01}/_docente/live.sh" "${w}"
  expect "M2-D01 live.sh, garanzia non confermata: uscita 1" 1 \
    "${G_TOKEN}${NCONF}"
  expect "M2-D01 live.sh, e il verdetto con l'uscita del controllo" 1 \
    "(uscita 1)"
  una_volta "M2-D01 live.sh, la riga d'esito una volta sola" \
    "${G_TOKEN}${NCONF}"
  ws w "${D02}/demo"
  printf 'Rispondi in italiano. %.0s' {1..600} > "${w}/istruzione.txt"
  finto_run "${D02}/_docente/live.sh" "${w}"
  expect "M2-D02 live.sh, garanzia non confermata: uscita 1" 1 \
    "${G_SOST}${NCONF}"
  expect "M2-D02 live.sh, e il verdetto con l'uscita del controllo" 1 \
    "(uscita 1)"
  una_volta "M2-D02 live.sh, la riga d'esito una volta sola" \
    "${G_SOST}${NCONF}"
}

# Una riga c'è una volta sola nell'uscita: verifica.sh gira una volta e
# il suo esito non si ripete. Arguments: $1 il nome, $2 la riga (grep -F).
una_volta() {
  local n
  n="$(grep -cF -- "$2" <<< "${OUT}")"
  if (( n == 1 )); then
    pass "$1"
  else
    fail "$1: ${n} volte"
  fi
}

# I live.sh quando verifica.sh non può girare (esce 2): si fermano con 2 e
# la riga della libreria che lo dice, in una copia dell'elemento con
# verifica.sh finta.
t_live_due() {
  local e c w
  for e in "${D01}" "${D02}"; do
    albero_due c "${e}"
    ws w "${e}/demo"
    finto_run "${c}/_docente/live.sh" "${w}"
    expect "${e##*/} live.sh: verifica.sh che esce 2, la prova esce 2" 2 \
      "non hanno potuto girare (uscita 2 o più)"
  done
}

# I due controlli compilano senza avvisi (la riga stampata dopo compile);
# gli script passano shellcheck, con l'elenco delle segnalazioni vuoto.
t_strumenti() {
  local f
  for f in "${CONTROLLO_D01}" "${CONTROLLO_D02}"; do
    run python3 -B -I -W error -c 'import sys
with open(sys.argv[1], encoding="utf-8") as fh:
    compile(fh.read(), sys.argv[1], "exec")
print("compilato senza avvisi")' "${f}"
    expect "${f##*/} compila con -W error" 0 "compilato senza avvisi"
  done
  for f in "${D01}/verifica.sh" "${D02}/verifica.sh" \
      "${D01}/_docente/live.sh" "${D02}/_docente/live.sh" "${SELF}"; do
    run shellcheck -x -f json1 "${f}"
    expect "shellcheck -x ${f#"${MOD}"/}" 0 '{"comments":[]}'
  done
}

main() {
  local t
  for t in python3 jq shellcheck timeout; do
    command -v "${t}" >/dev/null 2>&1 || { err "manca ${t}"; exit 2; }
  done
  for t in "${D01}" "${D02}"; do
    [[ -d "${t}" ]] || { err "manca ${t}"; exit 2; }
  done
  [[ -r "${FINTO}" ]] || { err "manca ${FINTO}"; exit 2; }
  TMP="$(mktemp -d)" || { err "mktemp"; exit 2; }
  trap 'chmod -R u+rwX "${TMP}" 2>/dev/null; rm -rf "${TMP}"' EXIT
  prepara_bin
  t_d01_colonne
  t_d01_formule
  t_d01_parole_garanzia
  t_d01_mancanze
  t_d01_forme
  t_d01_contratto
  t_d02_garanzie
  t_d02_ok
  t_d02_dati
  t_d02_contratto
  t_passi_readme
  t_leggi_json
  t_live_precondizioni
  t_live_finto
  t_live_ko
  t_live_due
  t_strumenti
  echo "PASS=${PASS} FAIL=${FAIL} SKIP=${SKIP}"
  if (( PASS + FAIL + SKIP != CASES )); then
    err "eseguite $((PASS + FAIL + SKIP)) prove, attese ${CASES}:" \
      "ne manca qualcuna"
    exit 2
  fi
  (( FAIL == 0 )) || exit 1
}

main "$@"
