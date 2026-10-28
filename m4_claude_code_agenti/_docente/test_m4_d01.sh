#!/bin/bash
#
# test_m4_d01.sh -- le prove di M4-D01 «La chiave che scavalca il Pro», per
# il docente (sta in _docente/, il materiale del docente):
#   - l'elemento: i suoi file, verifica.sh e _docente/live.sh eseguibili,
#     il README con le dieci sezioni; prepara_esercizio.sh porta il
#     controllo nello spazio di lavoro, e verifica.sh vi esce 1;
#   - controlla_accesso.py --salva sul JSON del claude finto, che ha campi
#     simili a un'identità: tiene soltanto loggedIn, authMethod e
#     apiKeySource, e l'identità non arriva né nel file né a schermo; un
#     ingresso vuoto, non JSON (con un'e-mail, che non si ripete), un
#     elenco, senza authMethod: uscita 2 e nessun file; un file che non si
#     scrive (2); --salva senza file (2);
#   - il controllo: la garanzia confermata (0); la chiave ignorata o presa
#     da un'altra fonte (1, «non confermata in questa esecuzione»); senza
#     la chiave un altro metodo o nessun accesso (2: la prova non può
#     partire); stato/ che manca o un file che manca, con campi in più (che
#     non si stampano), non JSON o con tipi sbagliati (1); un file che non
#     si legge, argomenti sbagliati, un errore inatteso (2, senza
#     traceback);
#   - verifica.sh: spazio di lavoro assente (2), punto di partenza (1),
#     confermata (0, la frase finale per ultima), non confermata (1),
#     python3 che manca (2), un controllo che esce 3 o per un segnale (2);
#   - _docente/live.sh: le precondizioni escono 2 senza chiamare claude
#     (un'esca registra ogni invocazione); con il claude finto le due
#     esecuzioni di claude auth status --json, la prima senza
#     ANTHROPIC_API_KEY anche se l'ambiente ne ha una, la seconda con la
#     chiave finta del corso, nessuna chiamata -p; i file con i soli tre
#     campi; l'identità finta mai a schermo né nei file; i dati e il
#     verdetto a schermo una volta sola; la chiave ignorata (1), nessun
#     accesso (2), un'uscita che non è JSON (2); il blocco del passo 3 del
#     README, con lo stesso finto, dà le stesse invocazioni e gli stessi
#     file;
#   - il README: le frasi di Anthropic parola per parola con il loro
#     indirizzo, la chiave finta, nessun export della chiave, nessuna
#     sigla interna; «Tempo» come il deck (la prova di 2 minuti continua
#     con il README);
#   - shellcheck -x su verifica.sh, live.sh e questo file.
# Mai il claude vero: il finto e l'esca stanno davanti nel PATH, e la suite
# lo controlla prima di usarli. Gli stati finti non sono di un account:
# provano il controllo, non Claude Code. Gli spazi di lavoro nascono in una
# cartella temporanea, nella base di handson::init_temp_base: l'albero del
# repository non cambia. CASES è il numero dei casi: se ne girano di più o
# di meno la suite esce 2 (un caso saltato conta come girato).
#
# Uso:    m4_claude_code_agenti/_docente/test_m4_d01.sh
# Uscita: 0 = tutti i casi passano · 1 = almeno un caso fallito · 2 =
#         precondizione (manca python3, git o shellcheck, o la cartella
#         dell'elemento), o un numero di casi diverso da CASES
set -uo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly MOD="${SELF%/_docente/*}"
readonly RADICE="${MOD%/*}"
D01="${MOD}/s3_agente_nel_repository/m4_3_installare_configurare"
D01+="/M4-D01_chiave_che_scavalca"
readonly D01
readonly FINTO_PY="${MOD}/_docente/claude_finto_m4_d01_d02_d08.py"
# La libreria del repository, per la base dei file temporanei
# (handson::init_temp_base): mai dentro ~/.claude.
# shellcheck source=../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"
readonly CASES=67
readonly CHIAVE='finta-chiave-del-corso'
readonly IDENTITA=('persona@example.org' 'Org di prova' '00000000-0000')
FINE='Fatto: ogni affermazione è stata messa alla prova;'
FINE+=' gli esiti sono qui sopra.'
readonly FINE
readonly PARTENZA='Mancano i file di stato/: eseguite i passi del README.'
readonly NONCONF='non confermata in questa esecuzione'
readonly VERDETTO="Con ANTHROPIC_API_KEY impostata, Claude Code usa la chiave
 al posto dell'abbonamento"
SENZA='{"loggedIn": true, "authMethod": "claude.ai",'
SENZA+=' "apiKeySource": null}'
readonly SENZA
readonly TRE='apiKeySource,authMethod,loggedIn'
# Le due invocazioni attese, con la chiave che il finto ha visto.
readonly INVOCAZIONI=$'auth status --json | None\nauth status --json | finta'
CON='{"loggedIn": true, "authMethod": "api_key",'
CON+=' "apiKeySource": "ANTHROPIC_API_KEY"}'
readonly CON
TMP=''
PASS=0
FAIL=0
SKIP=0
RC=0
OUT=''
TUTTO=''

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }
skip() { echo "  SKIP: $1"; SKIP=$((SKIP + 1)); }

# Il verdetto su una riga: VERDETTO senza l'a capo che lo spezza qui.
verdetto() { printf '%s' "${VERDETTO//$'\n'/}"; }

# Esegue un comando; RC e OUT (STDOUT e STDERR insieme) per expect; OUT si
# aggiunge a TUTTO, dove alla fine non deve esserci «smentita».
run() { OUT="$("$@" 2>&1)"; RC=$?; TUTTO+="${OUT}"$'\n'; }

# Uscita attesa E parola chiave attesa (RU-01.T3).
# Arguments: $1 il nome, $2 l'uscita attesa, $3 la parola (grep -F).
expect() {
  if (( RC == $2 )) && grep -qF -- "$3" <<< "${OUT}"; then
    pass "$1"
  else
    fail "$1 (rc=${RC}, attesa $2, parola «$3»): ${OUT:0:400}"
  fi
}

# Nessun falso positivo: la parola NON c'è (RU-01.T5).
# Arguments: $1 il nome, $2 la parola.
expect_absent() {
  if grep -qF -- "$2" <<< "${OUT}"; then
    fail "$1: «$2» c'è"
  else
    pass "$1"
  fi
}

# Vero se nessuna stringa dell'identità finta compare nel testo $1.
senza_identita() {
  local s
  for s in "${IDENTITA[@]}"; do
    if grep -qF -- "${s}" <<< "$1"; then
      return 1
    fi
  done
  return 0
}

# Un nuovo spazio di lavoro: una copia di demo/.
# Arguments: $1 la variabile da assegnare.
ws() {
  local __w
  __w="$(mktemp -d "${TMP}/ws.XXXXXX")" || { echo "mktemp" >&2; exit 2; }
  cp -R "${D01}/demo/." "${__w}/" || exit 2
  printf -v "$1" '%s' "${__w}"
}

# I due file di stato/. Arguments: $1 lo spazio di lavoro, $2 il JSON di
# senza.json, $3 quello di con.json ("-" = il file non c'è).
stato() {
  mkdir -p "$1/stato" || exit 2
  if [[ "$2" != "-" ]]; then printf '%s\n' "$2" > "$1/stato/senza.json"; fi
  if [[ "$3" != "-" ]]; then printf '%s\n' "$3" > "$1/stato/con.json"; fi
}

# Il controllo dello spazio di lavoro, come lo lancia verifica.sh; RC e OUT.
# Arguments: lo spazio di lavoro e gli altri argomenti.
controlla() {
  run python3 -B -I "${D01}/demo/controlla_accesso.py" "$@"
}

# --salva nello spazio di lavoro $1, con lo STDIN dato in $2 e il file $3.
salva() {
  OUT="$(cd "$1" && printf '%s' "$2" \
    | python3 -B -I controlla_accesso.py --salva "$3" 2>&1)"
  RC=$?
  TUTTO+="${OUT}"$'\n'
}

# Il JSON del claude finto per auth status, con o senza la chiave.
# Arguments: $1 "senza" o "con", poi variabili NOME=valore per il finto.
json_finto() {
  local quale="$1"
  shift
  if [[ "${quale}" == con ]]; then
    env "$@" ANTHROPIC_API_KEY="${CHIAVE}" python3 -B -I "${FINTO_PY}" \
      auth status --json
  else
    env -u ANTHROPIC_API_KEY "$@" python3 -B -I "${FINTO_PY}" \
      auth status --json
  fi
}

# Il ramo dell'errore inatteso: main() del controllo con un controlla() che
# solleva un'eccezione. Arguments: gli argomenti di main.
inatteso() {
  run python3 -B -I -c 'import importlib.util, sys
spec = importlib.util.spec_from_file_location("controllo", sys.argv[1])
modulo = importlib.util.module_from_spec(spec)
spec.loader.exec_module(modulo)
def guasto(*_):
    raise RuntimeError("guasto finto")
modulo.controlla = guasto
sys.exit(modulo.main(sys.argv[2:]))' "${D01}/demo/controlla_accesso.py" "$@"
}

# Una copia di verifica.sh e di demo/ in cui il controllo è finto: esce con
# il codice dato, o si fa terminare da un segnale.
# Arguments: $1 la variabile da assegnare (la copia), $2 il codice d'uscita
# oppure «segnale».
albero_finto() {
  local __a __c
  __a="$(mktemp -d "${TMP}/albero.XXXXXX")" || { echo "mktemp" >&2; exit 2; }
  if ! cp -- "${D01}/verifica.sh" "${__a}/" \
      || ! cp -R "${D01}/demo" "${__a}/"; then
    echo "test_m4_d01: non riesco a copiare l'elemento" >&2
    exit 2
  fi
  __c="${__a}/demo/controlla_accesso.py"
  if [[ "$2" == segnale ]]; then
    printf '%s\n' 'import os, signal' 'os.kill(os.getpid(), signal.SIGTERM)' \
      > "${__c}"
  else
    printf 'import sys\nsys.exit(%d)\n' "$2" > "${__c}"
  fi
  printf -v "$1" '%s' "${__a}"
}

# L'esca in ${TMP}/esca (registra ogni invocazione ed esce 0); il claude
# finto in ${TMP}/finto; ${TMP}/senza_python, un PATH con readlink, env e
# l'esca; ${TMP}/senza_claude, uno con readlink, env, python3 e mkdir. Esce
# 2 se nel PATH di prova il claude trovato non è il finto.
prepara_claude() {
  local t
  mkdir -p "${TMP}/esca" "${TMP}/finto" "${TMP}/senza_python" \
    "${TMP}/senza_claude" || exit 2
  # shellcheck disable=SC2016  # il corpo è dell'esca
  printf '%s\n' '#!/bin/bash' \
    'printf "invocazione %s\n" "$*" >> "${ESCA_LOG}"' \
    > "${TMP}/esca/claude" || exit 2
  cp -- "${FINTO_PY}" "${TMP}/finto/claude_finto.py" || exit 2
  # shellcheck disable=SC2016  # il corpo è dell'involucro
  printf '%s\n' '#!/bin/bash' \
    'exec python3 "${0%/*}/claude_finto.py" "$@"' \
    > "${TMP}/finto/claude" || exit 2
  chmod 755 "${TMP}/esca/claude" "${TMP}/finto/claude" || exit 2
  ln -s "${TMP}/esca/claude" "${TMP}/senza_python/claude" || exit 2
  for t in readlink env; do
    ln -s "$(command -v "${t}")" "${TMP}/senza_python/${t}" || exit 2
  done
  for t in readlink env python3 mkdir; do
    ln -s "$(command -v "${t}")" "${TMP}/senza_claude/${t}" || exit 2
  done
  t="$(PATH="${TMP}/finto:${PATH}" command -v claude)"
  if [[ "${t}" != "${TMP}/finto/claude" ]]; then
    echo "test_m4_d01: nel PATH di prova claude è ${t}, non il finto" >&2
    exit 2
  fi
}

# live.sh con l'esca davanti nel PATH (o con un PATH dato); il registro
# delle invocazioni riparte vuoto. Arguments: $1 lo spazio di lavoro, $2
# facoltativo il PATH.
esca() {
  : > "${TMP}/esca.log"
  run env PATH="${2:-${TMP}/esca:${PATH}}" HANDSON_NO_PAUSE=1 \
    ESCA_LOG="${TMP}/esca.log" "${D01}/_docente/live.sh" "$1"
}

# Una precondizione di live.sh: uscita 2, la parola attesa, e nessuna
# invocazione dell'esca. Arguments: $1 il nome, $2 la parola, poi gli
# argomenti di esca.
precondizione() {
  local nome="$1" parola="$2" n
  shift 2
  esca "$@"
  expect "${nome}" 2 "${parola}"
  n="$(grep -c . "${TMP}/esca.log")"
  if (( n == 0 )); then
    pass "${nome}: nessuna invocazione di claude"
  else
    fail "${nome}: ${n} invocazioni di claude"
  fi
}

# live.sh con il claude finto davanti nel PATH e una ANTHROPIC_API_KEY
# nell'ambiente (la prima esecuzione la deve togliere); il registro riparte
# vuoto. Arguments: $1 lo spazio di lavoro, poi le variabili NOME=valore.
finto() {
  local w="$1"
  shift
  : > "${TMP}/finto.log"
  run env PATH="${TMP}/finto:${PATH}" HANDSON_NO_PAUSE=1 \
    ANTHROPIC_API_KEY=valore-reale-finto FINTO_LOG="${TMP}/finto.log" "$@" \
    "${D01}/_docente/live.sh" "${w}"
}

# Le invocazioni del finto, una per riga: gli argomenti e la chiave, senza
# --version (che non usa l'accesso). Arguments: $1 il registro.
invocazioni() {
  python3 -B -I - "$1" <<'PY'
import json, sys
for riga in open(sys.argv[1], encoding="utf-8"):
    voce = json.loads(riga)
    if voce["argv"][:1] != ["--version"]:
        print("%s | %s" % (" ".join(voce["argv"]), voce["chiave"]))
PY
}

# Il blocco di codice del README che contiene la parola $2, senza il
# rientro, nel file $1. Returns: 0; 1 se il blocco non c'è.
blocco_readme() {
  python3 -B -I - "${D01}/README.md" "$1" "$2" <<'PY'
import sys
readme, uscita, segno = sys.argv[1:4]
blocchi, attuale = [], []
for riga in open(readme, encoding="utf-8").read().splitlines():
    if riga.startswith(" " * 7):
        attuale.append(riga[7:])
    elif riga.strip() == "" and attuale:
        attuale.append("")
    elif attuale:
        blocchi.append(attuale)
        attuale = []
if attuale:
    blocchi.append(attuale)
scelti = [b for b in blocchi if any(segno in r for r in b)]
if len(scelti) != 1:
    sys.exit(1)
with open(uscita, "w", encoding="utf-8") as fh:
    fh.write("\n".join(scelti[0]).strip("\n") + "\n")
PY
}

# Le chiavi di un file JSON, ordinate e separate da virgola; vuoto se non
# si legge. Arguments: $1 il file.
chiavi() {
  python3 -B -I -c 'import json, sys
print(",".join(sorted(json.load(open(sys.argv[1], encoding="utf-8")))))' \
    "$1" 2>/dev/null
}

# --- L'elemento ----------------------------------------------------------

t_elemento() {
  local f mancanti='' sezione pat ap="'" alt="(’|')"
  for f in README.md demo/controlla_accesso.py verifica.sh _docente/live.sh \
      soluzione/LEGGIMI.md; do
    [[ -f "${D01}/${f}" ]] || mancanti+=" ${f}"
  done
  if [[ -z "${mancanti}" ]]; then
    pass "elemento: i suoi file ci sono"
  else
    fail "elemento: mancano${mancanti}"
  fi
  if [[ -x "${D01}/verifica.sh" && -x "${D01}/_docente/live.sh" ]]; then
    pass "elemento: verifica.sh e live.sh eseguibili"
  else
    fail "elemento: verifica.sh o live.sh senza il bit di esecuzione"
  fi
  mancanti=''
  for sezione in "${HANDSON_README_SECTIONS[@]}"; do
    pat="${sezione//${ap}/${alt}}"
    grep -Eq -- "^##[[:space:]]+${pat}([^[:alnum:]_]|\$)" \
      "${D01}/README.md" 2>/dev/null || mancanti+=" «${sezione}»"
  done
  if [[ -z "${mancanti}" ]]; then
    pass "README: le dieci sezioni"
  else
    fail "README: mancano${mancanti}"
  fi
}

# prepara_esercizio.sh e tools/verifica.sh sul punto di partenza.
t_prepara() {
  local radice
  radice="$(mktemp -d "${TMP}/radice.XXXXXX")" || exit 2
  run "${RADICE}/tools/prepara_esercizio.sh" M4-D01 --radice "${radice}"
  if (( RC == 0 )) && [[ -f "${radice}/M4-D01/controlla_accesso.py" \
      && -f "${radice}/M4-D01/.claude/settings.json" \
      && ! -e "${radice}/M4-D01/soluzione" \
      && ! -e "${radice}/M4-D01/_docente" ]]; then
    pass "prepara: il controllo nello spazio di lavoro, niente soluzione/"
  else
    fail "prepara: rc=${RC}: ${OUT:0:300}"
  fi
  run "${RADICE}/tools/verifica.sh" M4-D01 --radice "${radice}"
  expect "prepara: sul punto di partenza la verifica esce 1" 1 "${PARTENZA}"
}

# --- controlla_accesso.py --salva ---------------------------------------

t_salva() {
  local w j
  ws w
  j="$(json_finto senza)"
  salva "${w}" "${j}" stato/senza.json
  if (( RC == 0 )) && [[ "$(chiavi "${w}/stato/senza.json")" == "${TRE}" ]] \
      && grep -qF '"authMethod": "claude.ai"' "${w}/stato/senza.json" \
      && grep -qF '"apiKeySource": null' "${w}/stato/senza.json"; then
    pass "salva: tiene i tre campi, crea stato/"
  else
    fail "salva: rc=${RC}, chiavi «$(chiavi "${w}/stato/senza.json")»"
  fi
  if senza_identita "${OUT}" \
      && senza_identita "$(cat "${w}/stato/senza.json" 2>/dev/null)"; then
    pass "salva: l'identità finta né a schermo né nel file"
  else
    fail "salva: l'identità finta è passata: ${OUT}"
  fi
  expect "salva: dice che cosa ha salvato" 0 "metodo claude.ai"
  j="$(json_finto con)"
  salva "${w}" "${j}" stato/con.json
  if (( RC == 0 )) \
      && grep -qF '"apiKeySource": "ANTHROPIC_API_KEY"' "${w}/stato/con.json" \
      && grep -qF '"authMethod": "api_key"' "${w}/stato/con.json"; then
    pass "salva: con la chiave, api_key da ANTHROPIC_API_KEY"
  else
    fail "salva: con la chiave, rc=${RC}: $(cat "${w}/stato/con.json")"
  fi
  t_salva_rifiuti
}

# --salva rifiuta ciò che non è il JSON di claude auth status.
t_salva_rifiuti() {
  local w
  ws w
  salva "${w}" '' stato/x.json
  if (( RC == 2 )) && grep -qF 'nessun JSON' <<< "${OUT}" \
      && [[ ! -e "${w}/stato/x.json" ]]; then
    pass "salva: ingresso vuoto, uscita 2 e nessun file"
  else
    fail "salva: ingresso vuoto, rc=${RC}: ${OUT}"
  fi
  salva "${w}" 'Stato: persona@example.org, non JSON' stato/x.json
  if (( RC == 2 )) && senza_identita "${OUT}" \
      && [[ ! -e "${w}/stato/x.json" ]]; then
    pass "salva: non JSON, uscita 2, l'e-mail non si ripete"
  else
    fail "salva: non JSON, rc=${RC}: ${OUT}"
  fi
  expect_absent "salva: non JSON, nessun traceback" "Traceback"
  salva "${w}" '[1, 2]' stato/x.json
  expect "salva: un elenco, uscita 2" 2 "non è il JSON di claude auth status"
  salva "${w}" '{"loggedIn": true, "email": "persona@example.org"}' \
    stato/x.json
  if (( RC == 2 )) && senza_identita "${OUT}" \
      && [[ ! -e "${w}/stato/x.json" ]]; then
    pass "salva: senza authMethod, uscita 2 e nessun file"
  else
    fail "salva: senza authMethod, rc=${RC}: ${OUT}"
  fi
  run python3 -B -I "${D01}/demo/controlla_accesso.py" --salva
  expect "salva: senza il file, uscita 2" 2 "Uso:"
  if (( $(id -u) == 0 )); then
    skip "salva: un file che non si scrive (root scrive ovunque)"
    return 0
  fi
  mkdir -p "${w}/chiusa" && chmod 555 "${w}/chiusa"
  salva "${w}" "$(json_finto senza)" chiusa/x.json
  expect "salva: un file che non si scrive, uscita 2" 2 "non si scrive"
  chmod 755 "${w}/chiusa"
}

# --- Il controllo -------------------------------------------------------

t_controllo() {
  local w
  ws w
  controlla "${w}"
  expect "controllo: il punto di partenza, uscita 1" 1 "${PARTENZA}"
  stato "${w}" "${SENZA}" "${CON}"
  controlla "${w}"
  expect "controllo: la chiave al posto dell'abbonamento, uscita 0" 0 \
    "$(verdetto): confermata"
  expect "controllo: i dati senza la chiave" 0 \
    "senza ANTHROPIC_API_KEY: collegato sì · metodo claude.ai"
  expect "controllo: i dati con la chiave" 0 \
    "metodo api_key · chiave da ANTHROPIC_API_KEY"
  ws w
  stato "${w}" "${SENZA}" "${SENZA}"
  controlla "${w}"
  expect "controllo: la chiave ignorata, uscita 1" 1 \
    "$(verdetto): ${NONCONF}"
  ws w
  stato "${w}" "${SENZA}" '{"loggedIn": true, "authMethod": "api_key",
 "apiKeySource": "apiKeyHelper"}'
  controlla "${w}"
  expect "controllo: la chiave da un'altra fonte, uscita 1" 1 "${NONCONF}"
  ws w
  stato "${w}" "${CON}" "${CON}"
  controlla "${w}"
  expect "controllo: senza la chiave un altro metodo, uscita 2" 2 \
    "senza la chiave Claude Code non usa l'abbonamento"
  ws w
  stato "${w}" '{"loggedIn": false, "authMethod": "none",
 "apiKeySource": null}' "${CON}"
  controlla "${w}"
  expect "controllo: senza la chiave nessun accesso, uscita 2" 2 \
    "metodo: none"
  t_controllo_file
}

# I file che mancano o non vanno.
t_controllo_file() {
  local w
  ws w
  stato "${w}" "${SENZA}" -
  controlla "${w}"
  expect "controllo: con.json che manca, uscita 1" 1 "manca stato/con.json"
  ws w
  stato "${w}" "${SENZA}" '{"loggedIn": true, "authMethod": "api_key",
 "apiKeySource": "ANTHROPIC_API_KEY", "email": "persona@example.org"}'
  controlla "${w}"
  if (( RC == 1 )) && grep -qF 'campi in più' <<< "${OUT}" \
      && senza_identita "${OUT}"; then
    pass "controllo: campi in più, uscita 1, e non li stampa"
  else
    fail "controllo: campi in più, rc=${RC}: ${OUT:0:300}"
  fi
  ws w
  stato "${w}" "${SENZA}" 'non JSON'
  controlla "${w}"
  expect "controllo: un file che non è JSON, uscita 1" 1 "stato/con.json"
  ws w
  stato "${w}" "${SENZA}" '{"loggedIn": "sì", "authMethod": 3}'
  controlla "${w}"
  expect "controllo: tipi sbagliati, uscita 1" 1 "stato/con.json"
  if (( $(id -u) == 0 )); then
    skip "controllo: un file che non si legge (root legge ovunque)"
  else
    ws w
    stato "${w}" "${SENZA}" "${CON}"
    chmod 000 "${w}/stato/con.json"
    controlla "${w}"
    expect "controllo: un file che non si legge, uscita 2" 2 "non si legge"
    chmod 644 "${w}/stato/con.json"
  fi
  controlla --boh
  expect "controllo: un'opzione sconosciuta, uscita 2" 2 "Uso:"
  controlla "${w}" "${w}"
  expect "controllo: due spazi di lavoro, uscita 2" 2 "Uso:"
  controlla "${TMP}/assente"
  expect "controllo: spazio di lavoro assente, uscita 2" 2 \
    "spazio di lavoro assente"
  inatteso "${w}"
  expect "controllo: un errore inatteso, uscita 2" 2 "errore inatteso"
  expect_absent "controllo: un errore inatteso, nessun traceback" \
    "Traceback"
}

# --- verifica.sh --------------------------------------------------------

t_verifica() {
  local w a
  run "${D01}/verifica.sh"
  expect "verifica: senza spazio di lavoro, uscita 2" 2 \
    "spazio di lavoro assente"
  ws w
  run "${D01}/verifica.sh" "${w}"
  expect "verifica: il punto di partenza, uscita 1" 1 "${PARTENZA}"
  stato "${w}" "${SENZA}" "${CON}"
  run "${D01}/verifica.sh" "${w}"
  expect "verifica: confermata, uscita 0" 0 "${FINE}"
  if [[ "${OUT##*$'\n'}" == "${FINE}" ]]; then
    pass "verifica: la frase finale è l'ultima riga"
  else
    fail "verifica: l'ultima riga è «${OUT##*$'\n'}»"
  fi
  stato "${w}" "${SENZA}" "${SENZA}"
  run "${D01}/verifica.sh" "${w}"
  expect "verifica: non confermata, uscita 1" 1 "${NONCONF}"
  expect_absent "verifica: non confermata, nessuna frase finale" "Fatto:"
  run env PATH="${TMP}/senza_claude_python" "${D01}/verifica.sh" "${w}"
  expect "verifica: python3 che manca, uscita 2" 2 "manca python3"
  albero_finto a 3
  run "${a}/verifica.sh" "${w}"
  expect "verifica: un controllo che esce con 3, uscita 2" 2 \
    "controlla_accesso.py è uscito con 3"
  albero_finto a segnale
  run "${a}/verifica.sh" "${w}"
  expect "verifica: un controllo terminato da un segnale, uscita 2" 2 \
    "controlla_accesso.py è uscito con 143"
}

# --- _docente/live.sh ---------------------------------------------------

# Le precondizioni escono 2 prima di ogni invocazione di claude.
t_live_precondizioni() {
  local w
  precondizione "live: spazio di lavoro assente" "spazio di lavoro assente" \
    "${TMP}/assente"
  ws w
  rm "${w}/controlla_accesso.py"
  precondizione "live: controlla_accesso.py che manca" \
    "file assente o illeggibile: controlla_accesso.py" "${w}"
  ws w
  precondizione "live: python3 che manca" "manca lo strumento: python3" \
    "${w}" "${TMP}/senza_python"
  ws w
  esca "${w}" "${TMP}/senza_claude"
  expect "live: claude che manca" 2 "manca lo strumento: claude"
}

# Il claude finto: le due esecuzioni, i file, l'identità.
t_live_finto() {
  local w w2 r tutto
  ws w
  finto "${w}"
  expect "live: le due esecuzioni finte, uscita 0" 0 "VERIFICA OK"
  expect "live: il verdetto si vede anche quando passa" 0 \
    "$(verdetto): confermata"
  r="$(grep -cF 'senza ANTHROPIC_API_KEY: collegato sì' <<< "${OUT}")"
  if (( r == 1 )); then
    pass "live: i dati si vedono una volta sola"
  else
    fail "live: i dati senza la chiave si vedono ${r} volte"
  fi
  r="$(invocazioni "${TMP}/finto.log")"
  if [[ "${r}" == "${INVOCAZIONI}" ]]; then
    pass "live: la prima senza chiave, la seconda con la finta, niente -p"
  else
    fail "live: le invocazioni sono «${r}»"
  fi
  if [[ "$(chiavi "${w}/stato/senza.json")" == "${TRE}" \
      && "$(chiavi "${w}/stato/con.json")" == "${TRE}" ]]; then
    pass "live: i due file con i soli tre campi"
  else
    fail "live: le chiavi dei file non sono le tre"
  fi
  tutto="${OUT}$(cat "${w}/stato/"*.json 2>/dev/null)"
  if senza_identita "${tutto}"; then
    pass "live: l'identità finta né a schermo né nei file"
  else
    fail "live: l'identità finta è passata"
  fi
  if grep -qF "env ANTHROPIC_API_KEY=${CHIAVE} claude auth status --json" \
      <<< "${OUT}"; then
    pass "live: il comando con la chiave finta si vede prima di girare"
  else
    fail "live: il comando con la chiave finta non si vede"
  fi
  cp "${TMP}/finto.log" "${TMP}/live.log"
  ws w2
  if ! blocco_readme "${TMP}/passo.sh" "--salva stato/senza.json"; then
    fail "README: il blocco con --salva non c'è"
    return 0
  fi
  : > "${TMP}/finto.log"
  ( cd "${w2}" && PATH="${TMP}/finto:${PATH}" FINTO_LOG="${TMP}/finto.log" \
      ANTHROPIC_API_KEY=valore-reale-finto bash "${TMP}/passo.sh" ) \
    > /dev/null 2>&1
  if [[ "$(invocazioni "${TMP}/live.log")" \
      == "$(invocazioni "${TMP}/finto.log")" ]] \
      && cmp -s "${w}/stato/senza.json" "${w2}/stato/senza.json" \
      && cmp -s "${w}/stato/con.json" "${w2}/stato/con.json"; then
    pass "live e README: stesse invocazioni, stessi file"
  else
    fail "live e README: invocazioni o file diversi"
  fi
}

# Il claude finto: la chiave ignorata, nessun accesso, un'uscita non JSON.
t_live_esiti() {
  local w
  ws w
  finto "${w}" FINTO_AUTH_CON=claude.ai
  expect "live: la chiave ignorata, uscita 1" 1 "${NONCONF}"
  ws w
  finto "${w}" FINTO_AUTH=none
  expect "live: nessun accesso, uscita 2" 2 "metodo: none"
  ws w
  finto "${w}" FINTO_AUTH_ROTTO=1
  if (( RC == 2 )) && grep -qF 'non è il JSON di claude auth status' \
      <<< "${OUT}" && senza_identita "${OUT}"; then
    pass "live: un'uscita non JSON, uscita 2, l'e-mail non si vede"
  else
    fail "live: un'uscita non JSON, rc=${RC}: ${OUT:0:300}"
  fi
}

# --- Il README ----------------------------------------------------------

t_readme() {
  run python3 -B -I - "${D01}/README.md" <<'PY'
import re, sys
testo = open(sys.argv[1], encoding="utf-8").read()
piatto = " ".join(testo.split())
attese = [
    ("When set, this key is used instead of your Claude Pro, Max, Team, or "
     "Enterprise subscription even if you are logged in.",
     "https://code.claude.com/docs/en/env-vars"),
    ("In non-interactive mode (-p), the key is always used when present.",
     "https://code.claude.com/docs/en/authentication"),
    ("Run unset ANTHROPIC_API_KEY to fall back to your subscription, and "
     "check /status to confirm which method is active.",
     "https://code.claude.com/docs/en/authentication"),
]
problemi = []
for frase, url in attese:
    if frase not in piatto:
        problemi.append("manca «%s»" % frase[:40])
    if url not in testo:
        problemi.append("manca %s" % url)
if "finta-chiave-del-corso" not in testo:
    problemi.append("manca la chiave finta")
if re.search(r"export\s+ANTHROPIC_API_KEY", testo):
    problemi.append("un export della chiave")
for sigla in ("FACT-", "M4-X", "X-3", "sessione principale", "P1 "):
    if sigla in testo:
        problemi.append("sigla interna %s" % sigla)
print("; ".join(problemi) or "README in ordine")
PY
  expect "README: le frasi, gli indirizzi, la chiave finta, nessuna sigla" 0 \
    "README in ordine"
  # «Tempo» come il deck: la prova è una pagina di 2 minuti, e chi non
  # finisce la continua da solo con il README.
  run python3 -B -I - "${D01}/README.md" <<'PY'
import sys
testo = open(sys.argv[1], encoding="utf-8").read()
tempo = testo.split("## Tempo", 1)[-1].split("\n## ", 1)[0]
tempo = " ".join(tempo.split())
attese = ("2 per la demo del docente", "2 per la vostra prova",
          "continua da solo, con questo README")
mancano = [a for a in attese if a not in tempo]
print("Tempo come il deck" if not mancano else "manca: %s" % mancano)
PY
  expect "README: «Tempo» come il deck, la prova continua con il README" 0 \
    "Tempo come il deck"
}

# Gli script di M4-D01 e questo file, con shellcheck -x.
t_shellcheck() {
  local f
  for f in "${D01}/verifica.sh" "${D01}/_docente/live.sh" "${SELF}"; do
    if shellcheck -x "${f}" > /dev/null 2>&1; then
      pass "shellcheck ${f#"${RADICE}"/}"
    else
      fail "shellcheck ${f#"${RADICE}"/}"
    fi
  done
}

main() {
  local t
  for t in python3 git shellcheck; do
    command -v "${t}" >/dev/null 2>&1 \
      || { echo "test_m4_d01: manca ${t}" >&2; exit 2; }
  done
  [[ -d "${D01}" && -f "${FINTO_PY}" ]] \
    || { echo "test_m4_d01: manca ${D01} o ${FINTO_PY}" >&2; exit 2; }
  handson::init_temp_base
  TMP="$(mktemp -d "${HANDSON_TEMP_BASE}/test_m4_d01.XXXXXX")" || exit 2
  trap 'chmod -R u+rwX "${TMP}" 2>/dev/null; rm -rf "${TMP}"' EXIT
  prepara_claude
  mkdir -p "${TMP}/senza_claude_python" || exit 2
  ln -s "$(command -v readlink)" "${TMP}/senza_claude_python/readlink" \
    || exit 2
  t_elemento
  t_prepara
  t_salva
  t_controllo
  t_verifica
  t_live_precondizioni
  t_live_finto
  t_live_esiti
  t_readme
  t_shellcheck
  OUT="${TUTTO}"
  expect_absent "in nessuna uscita «smentita»" "smentita"
  echo "PASS=${PASS} FAIL=${FAIL} SKIP=${SKIP}"
  if (( PASS + FAIL + SKIP != CASES )); then
    echo "test_m4_d01: girati $((PASS + FAIL + SKIP)) casi, attesi" \
      "${CASES}" >&2
    exit 2
  fi
  (( FAIL == 0 )) || exit 1
}

main "$@"
