#!/bin/bash
#
# test_m3_d03.sh -- le prove di M3-D03 «Che cosa vede Claude in un
# progetto», per il docente (sta in _docente/, il materiale del docente):
#   - domanda.txt, la domanda delle tre prove;
#   - nuova_parola.py: la forma della parola (una parola di montagna in
#     maiuscolo, un trattino, quattro cifre) e della frase; il rifiuto di
#     sovrascrivere parola.txt (uscita 2, file intatti); --nuova, che la
#     cambia; lo spazio di lavoro come argomento; parole diverse a ogni
#     estrazione; le precondizioni (argomenti, spazio di lavoro, un file
#     che non si scrive, un collegamento simbolico, un errore inatteso),
#     con l'uscita 2 e senza traceback;
#   - controlla_progetto.py su risposte scritte qui, testi di prova e mai
#     risposte di Claude: le tre garanzie che tengono (0, senza falsi
#     positivi); ciascuna che non tiene (1, con la sua frase); la parola in
#     minuscolo, con un altro trattino, con uno spazio, senza separatore,
#     in caratteri larghi; all'inizio dopo il grassetto, un titolo, le
#     virgolette, una citazione, un elenco, gli apici inversi, un BOM, uno
#     spazio a larghezza zero; presente ma non all'inizio, o dopo
#     un'etichetta (0: la garanzia B si decide sulla parola che c'è, e
#     «all'inizio: no» resta un dato, X-38); assente (1), e allora A e C,
#     che senza la parola in B non possono mostrare niente, «non
#     distinguibile» con il perché, salvo una parola comparsa in A (non
#     confermata); il nome senza le cifre, o le cifre senza il nome
#     (non contano); parola.txt che manca o è vuoto (1), in minuscolo
#     (letto), senza la forma attesa o non UTF-8 (2); una risposta che
#     manca o è vuota (1, con le altre decise); l'inizio lungo troncato;
#     una risposta non UTF-8, una cartella, un file che non si legge (2,
#     senza traceback e senza dati a metà); gli argomenti; un errore
#     inatteso (2); nessun file scritto;
#   - verifica.sh, che fa girare il controllo di demo/: spazio di lavoro
#     assente (2), punto di partenza (1), le tre garanzie (0, con la frase
#     finale per ultima), una che non tiene (1), il controllo dello spazio
#     di lavoro manomesso che non conta, parola.txt senza forma (2),
#     python3 che manca (2), un controllo che esce con un codice fuori dal
#     contratto o per un segnale (2);
#   - il README: le dieci sezioni, la domanda di domanda.txt, i file che il
#     controllo legge, le tre affermazioni citate parola per parola, nessun
#     nome interno;
#   - shellcheck -x su verifica.sh e su questo file.
# Gli spazi di lavoro nascono in una cartella temporanea, nella base di
# handson::init_temp_base (mai dentro ~/.claude, anche se TMPDIR punta
# lì): l'albero del repository non cambia. CASES è il numero dei casi: se
# ne girano di più o di meno la suite esce 2 (un caso saltato da root
# conta come girato).
#
# Uso:    m3_funzionalita_claude/_docente/test_m3_d03.sh
# Uscita: 0 = tutti i casi passano · 1 = almeno un caso fallito · 2 =
#         precondizione (manca python3 o shellcheck, o la cartella
#         dell'elemento), o un numero di casi diverso da CASES
set -uo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly MOD="${SELF%/_docente/*}"
D03="${MOD}/s2_funzionalita_claude/m3_5_progetti_o_chat"
D03+="/M3-D03_che_cosa_vede_un_progetto"
readonly D03
# La libreria del repository, per la base dei file temporanei
# (handson::init_temp_base): mai dentro ~/.claude, anche se TMPDIR punta lì.
# shellcheck source=../../tools/lib_handson.sh
source "${MOD%/*}/tools/lib_handson.sh"
readonly CASES=107
readonly W='GENZIANA-4817'
readonly FORMA='^[A-Z]{3,}-[1-9][0-9]{3}$'
FINE='Fatto: ogni affermazione è stata messa alla prova;'
FINE+=' gli esiti sono qui sopra.'
readonly FINE
readonly V_A='Claude non vede la descrizione del progetto (prova A)'
V_B='Claude usa le istruzioni del progetto in tutte le sue chat'
V_B+=' (prova B)'
readonly V_B
readonly V_C='Le istruzioni valgono solo per le chat del progetto (prova C)'
G_A='La documentazione garantisce che Claude non vede la descrizione del'
G_A+=' progetto: in questa esecuzione la parola è comparsa.'
readonly G_A
G_B='La documentazione garantisce che Claude usa le istruzioni in tutte le'
G_B+=' chat del progetto: in questa esecuzione la parola non è comparsa.'
readonly G_B
G_C='La documentazione garantisce che le istruzioni valgono solo per le'
G_C+=' chat del progetto: in questa esecuzione la parola è comparsa fuori'
G_C+=' dal progetto.'
readonly G_C
readonly NC='non confermata in questa esecuzione'
readonly ND='non distinguibile'
readonly SENZA_B='Nella prova B la parola non è comparsa'
readonly MANCA='Manca parola.txt: lanciate python3 nuova_parola.py'
TMP=''
PASS=0
FAIL=0
SKIP=0
RC=0
OUT=''

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }
skip() { echo "  SKIP: $1"; SKIP=$((SKIP + 1)); }

# Esegue un comando; RC e OUT (STDOUT e STDERR insieme) per expect.
run() { OUT="$("$@" 2>&1)"; RC=$?; }

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

# Un nuovo spazio di lavoro: una copia di demo/.
# Arguments: $1 la variabile da assegnare.
ws() {
  local __w
  __w="$(mktemp -d "${TMP}/ws.XXXXXX")" || { echo "mktemp" >&2; exit 2; }
  cp -R "${D03}/demo/." "${__w}/" || exit 2
  printf -v "$1" '%s' "${__w}"
}

# Scrive un file dello spazio di lavoro; nel testo \n è un a capo e \xHH
# quel byte (printf %b). Arguments: $1 lo spazio di lavoro, $2 il file,
# $3 il testo.
scrivi() { printf '%b' "$3" > "$1/$2" || exit 2; }

# Le risposte di un'esecuzione in cui le tre garanzie tengono: testi di
# prova scritti qui, non risposte di Claude. Arguments: $1 lo spazio di
# lavoro.
complete() {
  scrivi "$1" parola.txt "${W}\n"
  scrivi "$1" risposta-A.txt 'Testo di prova: il ponte radio è fermo.\n'
  scrivi "$1" risposta-B.txt "${W} Testo di prova: la fibra è interrotta.\n"
  scrivi "$1" risposta-C.txt 'Testo di prova: apparato riavviato.\n'
}

# controlla_progetto.py nello spazio di lavoro $1, con gli argomenti che
# seguono; RC e OUT come run.
controlla() {
  local w="$1"
  shift
  OUT="$(cd "${w}" && python3 -B -I controlla_progetto.py "$@" 2>&1)"
  RC=$?
}

# nuova_parola.py nello spazio di lavoro $1, con gli argomenti che
# seguono; RC e OUT come run.
genera() {
  local w="$1"
  shift
  OUT="$(cd "${w}" && python3 -B -I nuova_parola.py "$@" 2>&1)"
  RC=$?
}

# Le risposte complete, un file cambiato, poi il controllo: RC e OUT sono
# quelli del controllo. Arguments: $1 la variabile da assegnare con lo
# spazio di lavoro, $2 il file, $3 il testo (come per scrivi).
caso() {
  local __c
  ws __c
  complete "${__c}"
  scrivi "${__c}" "$2" "$3"
  controlla "${__c}"
  printf -v "$1" '%s' "${__c}"
}

# main() di uno script di demo/ con una sua funzione che solleva
# un'eccezione. Arguments: $1 lo script, $2 la funzione da guastare, poi
# gli argomenti di main. RC e OUT per expect.
inatteso() {
  run python3 -B -I -c 'import importlib.util, sys
spec = importlib.util.spec_from_file_location("elemento", sys.argv[1])
modulo = importlib.util.module_from_spec(spec)
spec.loader.exec_module(modulo)
def guasto(*_):
    raise RuntimeError("guasto finto")
setattr(modulo, sys.argv[2], guasto)
sys.exit(modulo.main(sys.argv[3:]))' "$@"
}

# I file di una cartella, con dimensione e data di modifica, uno per riga.
# Arguments: $1 la cartella. Outputs: l'elenco.
elenco() {
  python3 -B -I - "$1" <<'PY'
import os, sys
for radice, _, nomi in sorted(os.walk(sys.argv[1])):
    for nome in sorted(nomi):
        s = os.lstat(os.path.join(radice, nome))
        print(os.path.join(radice, nome), s.st_size, s.st_mtime_ns)
PY
}

# Una copia di verifica.sh e di demo/ in cui il controllo è finto: esce
# con il codice dato, o si fa terminare da un segnale. L'albero del
# repository non cambia. Arguments: $1 la variabile da assegnare (la
# copia), $2 il codice d'uscita, oppure «segnale».
albero_finto() {
  local __a __c
  __a="$(mktemp -d "${TMP}/albero.XXXXXX")" || { echo "mktemp" >&2; exit 2; }
  if ! cp -- "${D03}/verifica.sh" "${__a}/" || ! cp -R "${D03}/demo" "${__a}/"
  then
    echo "test_m3_d03: non riesco a copiare l'elemento" >&2
    exit 2
  fi
  __c="${__a}/demo/controlla_progetto.py"
  if [[ "$2" == segnale ]]; then
    printf '%s\n' 'import os, signal' 'os.kill(os.getpid(), signal.SIGTERM)' \
      > "${__c}"
  else
    printf 'import sys\nsys.exit(%d)\n' "$2" > "${__c}"
  fi
  printf -v "$1" '%s' "${__a}"
}

# Un PATH con readlink e senza python3, per verifica.sh.
prepara_path() {
  mkdir -p "${TMP}/senza_python" || exit 2
  ln -s "$(command -v readlink)" "${TMP}/senza_python/readlink" || exit 2
}

# --- I test ---------------------------------------------------------------

# domanda.txt: la domanda delle tre prove, una riga.
t_domanda() {
  local f="${D03}/demo/domanda.txt"
  if [[ "$(cat "${f}")" == 'Scrivi una frase su un guasto di rete.' ]] \
      && (( $(wc -l < "${f}") == 1 )); then
    pass "domanda.txt: la domanda delle tre prove, una riga"
  else fail "domanda.txt: «$(cat "${f}")»"; fi
}

# nuova_parola.py: la parola, la frase, le istruzioni, nessuna
# sovrascrittura senza --nuova.
t_genera() {
  local w prima p
  ws w
  genera "${w}"
  expect "nuova_parola: uscita 0, la parola" 0 "Parola in codice:"
  expect "nuova_parola: dove va la frase" 0 \
    "Non scrivete mai la parola in una chat."
  p="$(cat "${w}/parola.txt")"
  expect "nuova_parola: stampa la frase da incollare" 0 \
    "    Inizia ogni risposta con la parola in codice ${p}."
  if [[ "${p}" =~ ${FORMA} ]] && (( $(wc -l < "${w}/parola.txt") == 1 ))
  then pass "nuova_parola: parola.txt ha la forma PAROLA-NNNN, una riga"
  else fail "nuova_parola: parola.txt è «${p}»"; fi
  run python3 -B -I -c 'import importlib.util, re, sys
spec = importlib.util.spec_from_file_location("g", sys.argv[1])
g = importlib.util.module_from_spec(spec)
spec.loader.exec_module(g)
ok = all(re.fullmatch("[A-Z]{3,}", p) for p in g.PAROLE)
print("ok" if ok and sys.argv[2].split("-")[0] in g.PAROLE else "no")' \
    "${D03}/demo/nuova_parola.py" "${p}"
  expect "nuova_parola: la parola viene dall'elenco, tutto maiuscolo" 0 ok
  if [[ "$(cat "${w}/frase.txt")" == \
      "Inizia ogni risposta con la parola in codice ${p}." ]]; then
    pass "nuova_parola: frase.txt ha la frase con la parola"
  else fail "nuova_parola: frase.txt è «$(cat "${w}/frase.txt")»"; fi
  prima="$(cat "${w}/parola.txt" "${w}/frase.txt")"
  genera "${w}"
  expect "nuova_parola: parola.txt c'è già, uscita 2" 2 "parola.txt c'è già"
  if [[ "$(cat "${w}/parola.txt" "${w}/frase.txt")" == "${prima}" ]]; then
    pass "nuova_parola: senza --nuova i file restano com'erano"
  else fail "nuova_parola: senza --nuova un file è cambiato"; fi
}

# nuova_parola.py: --nuova, lo spazio di lavoro come argomento, il caso.
t_genera_nuova() {
  local w w2 p i
  local -a viste=()
  ws w
  scrivi "${w}" parola.txt 'PROVA-0000\n'
  genera "${w}" --nuova
  expect "--nuova: uscita 0" 0 "Parola in codice:"
  p="$(cat "${w}/parola.txt")"
  if [[ "${p}" != PROVA-0000 && "${p}" =~ ${FORMA} ]]; then
    pass "--nuova: una parola nuova, con la sua forma"
  else fail "--nuova: parola.txt è «${p}»"; fi
  if [[ "$(cat "${w}/frase.txt")" == \
      "Inizia ogni risposta con la parola in codice ${p}." ]]; then
    pass "--nuova: frase.txt segue la parola nuova"
  else fail "--nuova: frase.txt è «$(cat "${w}/frase.txt")»"; fi
  ws w2
  OUT="$(cd "${TMP}" && python3 -B -I "${D03}/demo/nuova_parola.py" \
    "${w2}" 2>&1)"
  RC=$?
  if (( RC == 0 )) && [[ -f "${w2}/parola.txt" && -f "${w2}/frase.txt" \
      && ! -e "${TMP}/parola.txt" ]]; then
    pass "nuova_parola: scrive nello spazio di lavoro dato, non altrove"
  else fail "nuova_parola: spazio di lavoro come argomento (rc=${RC})"; fi
  for i in 1 2 3 4 5 6 7 8 9 10; do
    genera "${w}" --nuova
    viste+=("$(cat "${w}/parola.txt")")
  done
  i="$(printf '%s\n' "${viste[@]}" | sort -u | wc -l)"
  if (( i >= 2 )); then pass "nuova_parola: dieci estrazioni, ${i} diverse"
  else fail "nuova_parola: dieci estrazioni, sempre la stessa parola"; fi
}

# nuova_parola.py: le precondizioni, con l'uscita 2 e senza traceback.
t_genera_precondizioni() {
  local w
  ws w
  genera "${w}" --boh
  expect "nuova_parola: un'opzione sconosciuta" 2 "Uso:"
  genera "${w}" a b
  expect "nuova_parola: due spazi di lavoro" 2 "uno spazio di lavoro per volta"
  genera "${w}" "${TMP}/assente"
  expect "nuova_parola: uno spazio di lavoro che non c'è" 2 \
    "spazio di lavoro assente: ${TMP}/assente"
  mkdir "${w}/frase.txt"
  genera "${w}"
  expect "nuova_parola: frase.txt che non si scrive" 2 "frase.txt non si scrive"
  if [[ ! -e "${w}/parola.txt" ]]; then
    pass "nuova_parola: senza frase.txt nessun parola.txt"
  else fail "nuova_parola: parola.txt scritto senza frase.txt"; fi
  ws w
  ln -s "${TMP}/altrove.txt" "${w}/parola.txt"
  genera "${w}" --nuova
  expect "nuova_parola: parola.txt collegamento simbolico" 2 \
    "parola.txt è un collegamento simbolico"
  if [[ ! -e "${TMP}/altrove.txt" ]]; then
    pass "nuova_parola: il collegamento non viene seguito"
  else fail "nuova_parola: ha scritto attraverso il collegamento"; fi
  ws w
  inatteso "${D03}/demo/nuova_parola.py" estrai_parola "${w}"
  expect "nuova_parola: un errore inatteso esce 2" 2 \
    "errore inatteso (RuntimeError: guasto finto)"
  expect_absent "nuova_parola: un errore inatteso, senza traceback" \
    "Traceback"
}

# Le tre garanzie che tengono: uscita 0, i dati, nessun falso positivo.
t_garanzie() {
  local w n
  ws w
  complete "${w}"
  controlla "${w}"
  expect "controlla: le tre garanzie tengono, uscita 0" 0 \
    "${V_A}: confermata"
  n="$(grep -c ': confermata$' <<< "${OUT}")"
  if (( n == 3 )); then pass "controlla: tre righe «confermata»"
  else fail "controlla: ${n} righe «confermata», attese 3"; fi
  expect_absent "controlla: nessun «non confermata»" "${NC}"
  expect_absent "controlla: nessuna frase della garanzia" \
    "La documentazione garantisce"
  expect "controlla: la parola letta" 0 "Parola in codice: ${W}"
  expect "controlla: i dati di B" 0 "la parola c'è: sì; all'inizio: sì"
  expect "controlla: l'inizio di A" 0 "Prova A, la frase nella descrizione \
del progetto (risposta-A.txt): «Testo di prova: il ponte radio è fermo.»"
  expect_absent "controlla: la frase finale è della verifica" "Fatto:"
}

# Prova A: la parola nella risposta, in ogni forma; il nome o le cifre da
# soli non sono la parola.
t_garanzia_a() {
  local w larga
  caso w risposta-A.txt "Testo di prova con ${W} dentro.\n"
  expect "A: la parola nella risposta, uscita 1" 1 "${G_A}"
  expect "A: il verdetto" 1 "${V_A}: ${NC}"
  caso w risposta-A.txt 'Testo con genziana-4817 in minuscolo.\n'
  expect "A: la parola in minuscolo" 1 "${G_A}"
  caso w risposta-A.txt 'Testo con GENZIANA\xe2\x80\x934817 e un trattino.\n'
  expect "A: la parola con il trattino medio" 1 "${G_A}"
  caso w risposta-A.txt 'Testo con GENZIANA\xe2\x80\x914817 e un trattino.\n'
  expect "A: la parola con il trattino che non va a capo" 1 "${G_A}"
  caso w risposta-A.txt 'Testo con GENZIANA 4817 e uno spazio.\n'
  expect "A: la parola con uno spazio al posto del trattino" 1 "${G_A}"
  caso w risposta-A.txt 'Testo con GENZIANA4817 senza trattino.\n'
  expect "A: la parola senza separatore" 1 "${G_A}"
  larga="$(python3 -B -I -c 'import sys
print("".join(chr(ord(c) + 0xFEE0) for c in sys.argv[1]))' "${W}")"
  caso w risposta-A.txt "Testo con ${larga} in caratteri larghi.\n"
  expect "A: la parola in caratteri larghi" 1 "${G_A}"
  caso w risposta-A.txt 'Il guasto alla malga Genziana, testo di prova.\n'
  expect "A: il nome senza le cifre non è la parola" 0 "${V_A}: confermata"
  caso w risposta-A.txt 'Testo di prova: 4817 utenti senza linea.\n'
  expect "A: le cifre senza il nome non sono la parola" 0 \
    "${V_A}: confermata"
}

# Prova B: la parola all'inizio, dopo il markdown e i caratteri che non
# contano; non all'inizio, che conferma lo stesso e resta un dato (X-38);
# assente.
t_garanzia_b() {
  local w
  caso w risposta-B.txt "**${W}** Testo di prova.\n"
  expect "B: dopo il grassetto" 0 "${V_B}: confermata"
  caso w risposta-B.txt "# ${W}\n\nTesto di prova.\n"
  expect "B: in un titolo" 0 "${V_B}: confermata"
  caso w risposta-B.txt "\xc2\xab${W}\xc2\xbb Testo di prova.\n"
  expect "B: fra le virgolette basse" 0 "${V_B}: confermata"
  caso w risposta-B.txt "> ${W}: testo di prova.\n"
  expect "B: in una citazione" 0 "${V_B}: confermata"
  caso w risposta-B.txt "- ${W}\n- testo di prova\n"
  expect "B: in un elenco" 0 "${V_B}: confermata"
  caso w risposta-B.txt "\`${W}\` testo di prova.\n"
  expect "B: fra gli apici inversi" 0 "${V_B}: confermata"
  caso w risposta-B.txt "\xef\xbb\xbf${W} testo di prova.\n"
  expect "B: dopo un BOM" 0 "${V_B}: confermata"
  caso w risposta-B.txt "\xe2\x80\x8b${W} testo di prova.\n"
  expect "B: dopo uno spazio a larghezza zero" 0 "${V_B}: confermata"
  caso w risposta-B.txt 'genziana-4817: testo di prova.\n'
  expect "B: in minuscolo" 0 "${V_B}: confermata"
  caso w risposta-B.txt "Testo di prova, e alla fine ${W}.\n"
  expect "B: la parola non all'inizio, confermata" 0 "${V_B}: confermata"
  expect "B: il dato, c'è ma non all'inizio" 0 \
    "la parola c'è: sì; all'inizio: no"
  expect_absent "B: non all'inizio, nessun «non confermata»" "${NC}"
  caso w risposta-B.txt "Parola in codice: ${W}. Testo di prova.\n"
  expect "B: dopo un'etichetta, confermata" 0 "${V_B}: confermata"
  caso w risposta-B.txt 'Testo di prova senza la parola.\n'
  expect "B: la parola assente, uscita 1" 1 "${G_B}"
  expect "B senza la parola: A non distinguibile" 1 "${V_A}: ${ND}"
  expect "B senza la parola: C non distinguibile" 1 "${V_C}: ${ND}"
  expect "B senza la parola: il perché" 1 "${SENZA_B}"
  expect_absent "B senza la parola: A non è «confermata»" "${V_A}: confermata"
  expect_absent "B senza la parola: C non è «confermata»" "${V_C}: confermata"
  ws w
  complete "${w}"
  scrivi "${w}" risposta-B.txt 'Testo di prova senza la parola.\n'
  scrivi "${w}" risposta-A.txt "Testo di prova. ${W}\n"
  controlla "${w}"
  expect "B senza la parola, A con la parola: A non confermata" 1 \
    "${V_A}: ${NC}"
  expect "B senza la parola, A con la parola: C non distinguibile" 1 \
    "${V_C}: ${ND}"
}

# Prova C: la parola nella risposta fuori dal progetto.
t_garanzia_c() {
  local w
  caso w risposta-C.txt "Testo di prova. ${W}\n"
  expect "C: la parola nella risposta, uscita 1" 1 "${G_C}"
  expect "C: il verdetto" 1 "${V_C}: ${NC}"
}

# parola.txt: manca o è vuoto (1), in minuscolo (letto), senza la forma
# o non UTF-8 (2).
t_parola() {
  local w
  ws w
  complete "${w}"
  rm "${w}/parola.txt"
  controlla "${w}"
  expect "parola.txt che manca, uscita 1" 1 "${MANCA}"
  expect_absent "parola.txt che manca: nessun verdetto" "confermata"
  caso w parola.txt '  \n'
  expect "parola.txt vuoto, uscita 1" 1 "python3 nuova_parola.py --nuova"
  caso w parola.txt 'genziana-4817\n'
  expect "parola.txt in minuscolo si legge" 0 "${V_B}: confermata"
  caso w parola.txt 'ciao\n'
  expect "parola.txt senza la forma, uscita 2" 2 \
    "parola.txt non ha la forma di nuova_parola.py"
  caso w parola.txt 'GENZIANA\xe2\x80\x934817\n'
  expect "parola.txt con un altro trattino, uscita 2" 2 "non ha la forma"
  caso w parola.txt '\xff\xfeGENZIANA-4817\n'
  expect "parola.txt non UTF-8, uscita 2" 2 "parola.txt non è testo UTF-8"
}

# Una risposta che manca o è vuota: uscita 1, le altre decise lo stesso;
# l'inizio lungo troncato.
t_mancanti() {
  local w lunga
  ws w
  complete "${w}"
  rm "${w}/risposta-B.txt"
  controlla "${w}"
  expect "B che manca, uscita 1" 1 "manca risposta-B.txt: fate la prova B"
  expect "B che manca: A decisa lo stesso" 1 "${V_A}: confermata"
  expect "B che manca: C decisa lo stesso" 1 "${V_C}: confermata"
  expect "B che manca: il messaggio finale" 1 "Non ancora:"
  expect_absent "B che manca: nessun verdetto su B" "${V_B}"
  caso w risposta-C.txt ' \n\t\n'
  expect "C vuoto, uscita 1" 1 "risposta-C.txt è vuoto"
  ws w
  controlla "${w}"
  expect "punto di partenza: manca parola.txt, uscita 1" 1 "${MANCA}"
  lunga="$(printf 'Testo di prova lungo. %.0s' {1..12})"
  caso w risposta-A.txt "${lunga}\n"
  expect "l'inizio lungo si tronca a 120 caratteri" 0 "«${lunga:0:120}…»"
}

# Le precondizioni del controllo: uscita 2, senza traceback e senza dati a
# metà; il controllo non scrive niente.
t_precondizioni() {
  local w prima
  caso w risposta-B.txt '\xff\xfe testo\n'
  expect "una risposta non UTF-8, uscita 2" 2 \
    "risposta-B.txt non è testo UTF-8"
  expect_absent "una risposta non UTF-8: senza traceback" "Traceback"
  expect_absent "una risposta non UTF-8: nessun dato a metà" "Prova A,"
  ws w
  complete "${w}"
  rm "${w}/risposta-B.txt"
  mkdir "${w}/risposta-B.txt"
  controlla "${w}"
  expect "una cartella al posto della risposta, uscita 2" 2 \
    "risposta-B.txt non si legge"
  controlla "${w}" --boh
  expect "controlla: un'opzione sconosciuta" 2 "Uso:"
  controlla "${w}" . .
  expect "controlla: due spazi di lavoro" 2 "uno spazio di lavoro per volta"
  controlla "${w}" "${TMP}/assente"
  expect "controlla: uno spazio di lavoro che non c'è" 2 \
    "spazio di lavoro assente: ${TMP}/assente"
  inatteso "${D03}/demo/controlla_progetto.py" controlla "${w}"
  expect "controlla: un errore inatteso esce 2, senza traceback" 2 \
    "errore inatteso (RuntimeError: guasto finto)"
  ws w
  complete "${w}"
  prima="$(elenco "${w}")"
  controlla "${w}"
  if [[ "$(elenco "${w}")" == "${prima}" ]]; then
    pass "controlla: non scrive e non cambia niente"
  else fail "controlla: lo spazio di lavoro è cambiato"; fi
  if (( EUID == 0 )); then
    skip "una risposta che non si legge (da root si legge)"
    return 0
  fi
  chmod 000 "${w}/risposta-A.txt"
  controlla "${w}"
  expect "una risposta che non si legge, uscita 2" 2 \
    "risposta-A.txt non si legge"
}

# verifica.sh: le uscite di base e le garanzie.
t_verifica() {
  local w a
  run "${D03}/verifica.sh" "${TMP}/assente"
  expect "verifica: spazio di lavoro assente" 2 "spazio di lavoro assente"
  ws w
  run "${D03}/verifica.sh" "${w}"
  expect "verifica: il punto di partenza" 1 "${MANCA}"
  complete "${w}"
  run "${D03}/verifica.sh" "${w}"
  expect "verifica: le tre garanzie, uscita 0" 0 "${FINE}"
  if [[ "${OUT##*$'\n'}" == "${FINE}" ]]; then
    pass "verifica: la frase finale è l'ultima riga"
  else fail "verifica: l'ultima riga è «${OUT##*$'\n'}»"; fi
  scrivi "${w}" risposta-A.txt "Testo con ${W}.\n"
  run "${D03}/verifica.sh" "${w}"
  expect "verifica: A che non tiene, uscita 1" 1 "${G_A}"
  expect_absent "verifica: nessuna frase finale" "Fatto:"
  printf 'import sys\nsys.exit(0)\n' > "${w}/controlla_progetto.py"
  run "${D03}/verifica.sh" "${w}"
  expect "verifica: il controllo dello spazio di lavoro non conta" 1 "${G_A}"
  scrivi "${w}" parola.txt 'ciao\n'
  run "${D03}/verifica.sh" "${w}"
  expect "verifica: parola.txt senza forma, uscita 2" 2 "non ha la forma"
  complete "${w}"
  run env PATH="${TMP}/senza_python" "${D03}/verifica.sh" "${w}"
  expect "verifica: python3 che manca, uscita 2" 2 "manca python3"
  albero_finto a 3
  run "${a}/verifica.sh" "${w}"
  expect "verifica: un controllo che esce con 3, uscita 2" 2 \
    "controlla_progetto.py è uscito con 3"
  albero_finto a segnale
  run "${a}/verifica.sh" "${w}"
  expect "verifica: un controllo terminato da un segnale, uscita 2" 2 \
    "controlla_progetto.py è uscito con 143"
}

# Il README: le dieci sezioni, la domanda, i file, le citazioni, nessun
# nome interno.
t_readme() {
  run python3 -B -I - "${D03}/README.md" "${D03}/demo/domanda.txt" <<'PY'
import re, sys
testo = open(sys.argv[1], encoding="utf-8").read()
piatto = " ".join(testo.split())
domanda = open(sys.argv[2], encoding="utf-8").read().strip()
sezioni = ["Obiettivo", "Tempo", "Prerequisiti", "Punto di partenza",
           "Passi in Claude Code", "Che cosa osservare", "Verifica",
           "Se qualcosa va storto", "Impronta d'uso sul piano Pro",
           "Per approfondire"]
mancano = [s for s in sezioni
           if not re.search(r"^##\s+%s(\W|$)" % re.escape(s), testo, re.M)]
print("sezioni: " + (", ".join(mancano) or "tutte"))
print("domanda: " + ("sì" if "«%s»" % domanda in piatto else "no"))
file = ["nuova_parola.py", "parola.txt", "frase.txt", "domanda.txt",
        "controlla_progetto.py", "risposta-A.txt", "risposta-B.txt",
        "risposta-C.txt"]
print("file: " + (", ".join(f for f in file if f not in testo) or "tutti"))
citazioni = [
    "Give your project a name and description (note that Claude will not "
    "have access to these details).",
    "Claude will use these instructions for all the chats within the "
    "project.",
    "These instructions only apply to chats within that project."]
print("citazioni: " + ("tutte" if all(c in piatto for c in citazioni)
                       else "no"))
vietate = re.findall(r"FACT-|Tecnodata|smentit|\boggi\b|stamattina|"
                     r"prossima sessione|\bX-[0-9]", testo)
print("vietate: " + (", ".join(vietate) or "nessuna"))
PY
  expect "README: le dieci sezioni" 0 "sezioni: tutte"
  expect "README: la domanda di domanda.txt" 0 "domanda: sì"
  expect "README: i file dell'elemento" 0 "file: tutti"
  expect "README: le tre affermazioni citate parola per parola" 0 \
    "citazioni: tutte"
  expect "README: nessun nome interno né riferimento al giorno" 0 \
    "vietate: nessuna"
}

# verifica.sh e questo file, con shellcheck -x.
t_shellcheck() {
  local f
  for f in "${D03}/verifica.sh" "${SELF}"; do
    if shellcheck -x "${f}" > /dev/null 2>&1; then
      pass "shellcheck ${f#"${MOD%/*}"/}"
    else
      fail "shellcheck ${f#"${MOD%/*}"/}"
    fi
  done
}

main() {
  local t
  for t in python3 shellcheck; do
    command -v "${t}" >/dev/null 2>&1 \
      || { echo "test_m3_d03: manca ${t}" >&2; exit 2; }
  done
  [[ -d "${D03}" ]] || { echo "test_m3_d03: manca ${D03}" >&2; exit 2; }
  handson::init_temp_base
  TMP="$(mktemp -d "${HANDSON_TEMP_BASE}/test_m3_d03.XXXXXX")" || exit 2
  trap 'chmod -R u+rwX "${TMP}" 2>/dev/null; rm -rf "${TMP}"' EXIT
  prepara_path
  t_domanda
  t_genera
  t_genera_nuova
  t_genera_precondizioni
  t_garanzie
  t_garanzia_a
  t_garanzia_b
  t_garanzia_c
  t_parola
  t_mancanti
  t_precondizioni
  t_verifica
  t_readme
  t_shellcheck
  echo "PASS=${PASS} FAIL=${FAIL} SKIP=${SKIP}"
  if (( PASS + FAIL + SKIP != CASES )); then
    echo "test_m3_d03: girati $((PASS + FAIL + SKIP)) casi, attesi" \
      "${CASES}" >&2
    exit 2
  fi
  (( FAIL == 0 )) || exit 1
}

main "$@"
