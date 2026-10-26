#!/bin/bash
#
# test_m3_d04.sh -- le prove di M3-D04 «Una chat senza memoria», per il
# docente (sta in _docente/, il materiale del docente):
#   - domanda.txt, la domanda delle due chat di prova;
#   - nuovo_codice.py: la forma del codice (LP-, quattro lettere senza I e
#     O, un trattino, due cifre) e della frase; dove togliere il codice
#     dalla memoria, nei due layout delle impostazioni; il rifiuto di
#     sovrascrivere codice.txt (uscita 2, file intatti); --nuovo, che lo
#     cambia; lo spazio di lavoro come argomento; codici diversi a ogni
#     estrazione; il file dei ticket, trovato con PN_HANDSON_ROOT, nello
#     spazio di lavoro o sopra lo script (il codice, o le sue lettere e
#     cifre, che vi compare si scarta; senza il file non si controlla;
#     ogni estrazione scartata, o il file che non si legge: uscita 2); le
#     precondizioni (argomenti, spazio di lavoro, un file che non si
#     scrive, un collegamento simbolico, un errore inatteso), con l'uscita
#     2 e senza traceback;
#   - controlla_memoria.py su risposte scritte qui, testi di prova e mai
#     risposte di Claude: le due affermazioni confermate (0, senza falsi
#     positivi); la garanzia che non tiene (1), con il codice esatto, senza
#     prefisso, in minuscolo, con un altro trattino, con uno spazio, senza
#     separatore, in caratteri larghi; un altro codice o le sole lettere
#     (non contano); il «può» non confermato, che non fa fallire e dice
#     dove guardare la memoria nei due layout delle impostazioni, e allora
#     la garanzia, che senza il codice nella chat con la memoria non può
#     mostrare niente, «non distinguibile» con il perché (0), salvo il
#     codice comparso senza memoria (1); «NON LO
#     SO» come dato; codice.txt che manca o è vuoto (1), in minuscolo
#     (letto), senza la forma attesa o non UTF-8 (2); una risposta che
#     manca o è vuota (1, con l'altra detta lo stesso: senza la chat con la
#     memoria, che fa da controllo, la garanzia «non distinguibile», mai
#     «confermata», salvo il codice comparso); l'inizio lungo troncato; una
#     risposta non UTF-8, una cartella, un file che non si legge (2, senza
#     traceback e senza dati a metà); gli argomenti; un errore inatteso
#     (2); nessun file scritto;
#   - verifica.sh, che fa girare il controllo di demo/: spazio di lavoro
#     assente (2), punto di partenza (1), le risposte complete (0, con la
#     frase finale per ultima), il «può» non confermato (0), la garanzia
#     che non tiene (1), il controllo dello spazio di lavoro manomesso che
#     non conta, codice.txt senza forma (2), python3 che manca (2), un
#     controllo che esce con un codice fuori dal contratto o per un
#     segnale (2);
#   - il README: le dieci sezioni, la domanda di domanda.txt, i file che il
#     controllo legge, le affermazioni citate parola per parola, i due
#     layout delle impostazioni (ogni percorso o nome del layout
#     precedente detto tale), nessun nome interno;
#   - shellcheck -x su verifica.sh e su questo file.
# Gli spazi di lavoro e i repository finti nascono in una cartella
# temporanea, nella base di handson::init_temp_base (mai dentro ~/.claude,
# anche se TMPDIR punta lì): l'albero del repository non cambia. CASES è
# il numero dei casi: se ne girano di più o di meno la suite esce 2 (un
# caso saltato da root conta come girato).
#
# Uso:    m3_funzionalita_claude/_docente/test_m3_d04.sh
# Uscita: 0 = tutti i casi passano · 1 = almeno un caso fallito · 2 =
#         precondizione (manca python3 o shellcheck, o la cartella
#         dell'elemento), o un numero di casi diverso da CASES
set -uo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly MOD="${SELF%/_docente/*}"
D04="${MOD}/s2_funzionalita_claude/m3_6_memoria_e_dati"
D04+="/M3-D04_chat_senza_memoria"
readonly D04
# La libreria del repository, per la base dei file temporanei
# (handson::init_temp_base): mai dentro ~/.claude, anche se TMPDIR punta lì.
# shellcheck source=../../tools/lib_handson.sh
source "${MOD%/*}/tools/lib_handson.sh"
readonly CASES=116
readonly L='LP-QZKW-37'
readonly FORMA='^LP-[ABCDEFGHJKLMNPQRSTUVWXYZ]{4}-[0-9]{2}$'
readonly TICKET='progetti/assistenza-clienti/dati/ticket-settimana.csv'
FINE='Fatto: ogni affermazione è stata messa alla prova;'
FINE+=' gli esiti sono qui sopra.'
readonly FINE
V_CON='Claude può ricordare il contesto delle chat e portarlo nelle'
V_CON+=' conversazioni nuove (chat con la memoria)'
readonly V_CON
V_SENZA='In una chat senza memoria Claude non usa la memoria e non cerca'
V_SENZA+=' nelle chat passate (chat senza memoria)'
readonly V_SENZA
G='La documentazione garantisce che in una chat con la memoria spenta'
G+=' Claude non usa la memoria e non cerca nelle chat passate: in questa'
G+=' esecuzione il codice è comparso.'
readonly G
readonly NC='non confermata in questa esecuzione'
readonly ND='non distinguibile'
readonly SENZA_CON='Nella chat con la memoria il codice non è comparso'
SENZA_CONTROLLO='Manca la risposta della chat con la memoria: non si sa se il'
SENZA_CONTROLLO+=' codice è arrivato'
readonly SENZA_CONTROLLO
readonly MANCA='Manca codice.txt: lanciate python3 nuovo_codice.py'
readonly FRASE='Ricordati che il codice della linea di prova del corso è'
# Dove si vede la memoria, nei due layout delle impostazioni di claude.ai:
# i due script lo stampano con queste due righe.
DOVE_NUOVO='in Settings > Your Claude, con «Manage» accanto a'
DOVE_NUOVO+=' «Your memory»'
readonly DOVE_NUOVO
DOVE_PRIMA='nel layout precedente delle impostazioni,'
DOVE_PRIMA+=' in Settings > Memory'
readonly DOVE_PRIMA
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

# Un caso che confronta un valore con quello atteso.
# Arguments: $1 il nome, $2 il valore, $3 quello atteso.
expect_uguale() {
  if [[ "$2" == "$3" ]]; then pass "$1"; else fail "$1: «$2», atteso «$3»"; fi
}

# Un nuovo spazio di lavoro: una copia di demo/.
# Arguments: $1 la variabile da assegnare.
ws() {
  local __w
  __w="$(mktemp -d "${TMP}/ws.XXXXXX")" || { echo "mktemp" >&2; exit 2; }
  cp -R "${D04}/demo/." "${__w}/" || exit 2
  printf -v "$1" '%s' "${__w}"
}

# Scrive un file; nel testo \n è un a capo e \xHH quel byte (printf %b).
# Arguments: $1 la cartella, $2 il file, $3 il testo.
scrivi() { printf '%b' "$3" > "$1/$2" || exit 2; }

# Le risposte di un'esecuzione in cui le due affermazioni sono
# confermate: testi di prova scritti qui, non risposte di Claude.
# Arguments: $1 lo spazio di lavoro.
complete() {
  scrivi "$1" codice.txt "${L}\n"
  scrivi "$1" risposta-con-memoria.txt "${L}\n"
  scrivi "$1" risposta-senza-memoria.txt 'NON LO SO\n'
}

# controlla_memoria.py nello spazio di lavoro $1, con gli argomenti che
# seguono; RC e OUT come run.
controlla() {
  local w="$1"
  shift
  OUT="$(cd "${w}" && python3 -B -I controlla_memoria.py "$@" 2>&1)"
  RC=$?
}

# nuovo_codice.py nello spazio di lavoro $1, con gli argomenti che
# seguono; RC e OUT come run.
genera() {
  local w="$1"
  shift
  OUT="$(cd "${w}" && python3 -B -I nuovo_codice.py "$@" 2>&1)"
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

# main() di nuovo_codice.py con un estrai_codice che restituisce i codici
# dati, uno dopo l'altro (l'ultimo si ripete). Arguments: $1 il valore di
# PN_HANDSON_ROOT («-» per toglierla), $2 lo script, $3 i codici separati
# da virgole, poi gli argomenti di main. RC e OUT per expect.
con_codici() {
  local -a ambiente=(env -u PN_HANDSON_ROOT)
  if [[ "$1" != "-" ]]; then
    ambiente=(env "PN_HANDSON_ROOT=$1")
  fi
  shift
  run "${ambiente[@]}" python3 -B -I -c 'import importlib.util, sys
spec = importlib.util.spec_from_file_location("elemento", sys.argv[1])
modulo = importlib.util.module_from_spec(spec)
spec.loader.exec_module(modulo)
codici = sys.argv[2].split(",")
def estrai():
    return codici.pop(0) if len(codici) > 1 else codici[0]
modulo.estrai_codice = estrai
sys.exit(modulo.main(sys.argv[3:]))' "$@"
}

# Un repository finto con il file dei ticket. Arguments: $1 la variabile
# da assegnare (la radice), $2 il testo del file (come per scrivi).
radice_finta() {
  local __r
  __r="$(mktemp -d "${TMP}/radice.XXXXXX")" || { echo "mktemp" >&2; exit 2; }
  mkdir -p "${__r}/${TICKET%/*}" || exit 2
  scrivi "${__r}" "${TICKET}" "$2"
  printf -v "$1" '%s' "${__r}"
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
  if ! cp -- "${D04}/verifica.sh" "${__a}/" || ! cp -R "${D04}/demo" "${__a}/"
  then
    echo "test_m3_d04: non riesco a copiare l'elemento" >&2
    exit 2
  fi
  __c="${__a}/demo/controlla_memoria.py"
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

# domanda.txt: la domanda delle due chat di prova, una riga.
t_domanda() {
  local f="${D04}/demo/domanda.txt" attesa
  attesa='Quale codice della linea di prova del corso ti ho chiesto di'
  attesa+=' ricordare? Rispondi solo con il codice, oppure NON LO SO.'
  if [[ "$(cat "${f}")" == "${attesa}" ]] && (( $(wc -l < "${f}") == 1 ))
  then pass "domanda.txt: la domanda delle due chat, una riga"
  else fail "domanda.txt: «$(cat "${f}")»"; fi
}

# nuovo_codice.py: il codice, la frase, le istruzioni, nessuna
# sovrascrittura senza --nuovo.
t_genera() {
  local w prima c
  ws w
  genera "${w}"
  expect "nuovo_codice: uscita 0, il codice" 0 "Codice della linea di prova:"
  expect "nuovo_codice: la pulizia della memoria" 0 \
    "cancellare le chat non basta"
  expect "nuovo_codice: dove togliere il codice, nel layout aggiornato" 0 \
    "${DOVE_NUOVO}"
  expect "nuovo_codice: e nel layout precedente delle impostazioni" 0 \
    "${DOVE_PRIMA}"
  c="$(cat "${w}/codice.txt")"
  expect "nuovo_codice: stampa la frase da mandare" 0 "    ${FRASE} ${c}."
  if [[ "${c}" =~ ${FORMA} ]] && (( $(wc -l < "${w}/codice.txt") == 1 ))
  then pass "nuovo_codice: codice.txt ha la forma LP-XXXX-NN, senza I e O"
  else fail "nuovo_codice: codice.txt è «${c}»"; fi
  expect_uguale "nuovo_codice: frase-da-ricordare.txt ha la frase" \
    "$(cat "${w}/frase-da-ricordare.txt")" "${FRASE} ${c}."
  prima="$(cat "${w}/codice.txt" "${w}/frase-da-ricordare.txt")"
  genera "${w}"
  expect "nuovo_codice: codice.txt c'è già, uscita 2" 2 "codice.txt c'è già"
  expect_uguale "nuovo_codice: senza --nuovo i file restano com'erano" \
    "$(cat "${w}/codice.txt" "${w}/frase-da-ricordare.txt")" "${prima}"
}

# nuovo_codice.py: --nuovo, lo spazio di lavoro come argomento, il caso.
t_genera_nuovo() {
  local w w2 c i
  local -a visti=()
  ws w
  scrivi "${w}" codice.txt 'LP-IIII-00\n'
  genera "${w}" --nuovo
  expect "--nuovo: uscita 0" 0 "Codice della linea di prova:"
  c="$(cat "${w}/codice.txt")"
  if [[ "${c}" != LP-IIII-00 && "${c}" =~ ${FORMA} ]]; then
    pass "--nuovo: un codice nuovo, con la sua forma"
  else fail "--nuovo: codice.txt è «${c}»"; fi
  expect_uguale "--nuovo: la frase segue il codice nuovo" \
    "$(cat "${w}/frase-da-ricordare.txt")" "${FRASE} ${c}."
  ws w2
  OUT="$(cd "${TMP}" && python3 -B -I "${D04}/demo/nuovo_codice.py" \
    "${w2}" 2>&1)"
  RC=$?
  if (( RC == 0 )) && [[ -f "${w2}/codice.txt" \
      && -f "${w2}/frase-da-ricordare.txt" && ! -e "${TMP}/codice.txt" ]]
  then pass "nuovo_codice: scrive nello spazio di lavoro dato, non altrove"
  else fail "nuovo_codice: spazio di lavoro come argomento (rc=${RC})"; fi
  for i in 1 2 3 4 5 6 7 8 9 10; do
    genera "${w}" --nuovo
    visti+=("$(cat "${w}/codice.txt")")
  done
  i="$(printf '%s\n' "${visti[@]}" | sort -u | wc -l)"
  if (( i >= 2 )); then pass "nuovo_codice: dieci estrazioni, ${i} diverse"
  else fail "nuovo_codice: dieci estrazioni, sempre lo stesso codice"; fi
}

# nuovo_codice.py e il file dei ticket: un codice che vi compare si scarta.
t_genera_ticket() {
  local w r fuori
  ws w
  radice_finta r "id_ticket,descrizione\nTK-1,linea ${L} guasta\n"
  con_codici "${r}" "${D04}/demo/nuovo_codice.py" "${L},LP-ABCD-12" "${w}"
  expect_uguale "ticket (PN_HANDSON_ROOT): il codice che compare si scarta" \
    "$(cat "${w}/codice.txt")" "LP-ABCD-12"
  ws w
  radice_finta r 'id_ticket,descrizione\nTK-1,codice qzkw-37\n'
  con_codici "${r}" "${D04}/demo/nuovo_codice.py" "${L},LP-ABCD-12" "${w}"
  expect_uguale "ticket: anche le sole lettere e cifre, in minuscolo" \
    "$(cat "${w}/codice.txt")" "LP-ABCD-12"
  ws w
  mkdir -p "${w}/${TICKET%/*}"
  scrivi "${w}" "${TICKET}" "TK-1,${L}\n"
  con_codici - "${D04}/demo/nuovo_codice.py" "${L},LP-ABCD-12" "${w}"
  expect_uguale "ticket: il file nello spazio di lavoro" \
    "$(cat "${w}/codice.txt")" "LP-ABCD-12"
  ws w
  con_codici - "${D04}/demo/nuovo_codice.py" "LP-TK-2026,LP-ABCD-12" "${w}"
  expect_uguale "ticket: il file del repository, sopra lo script" \
    "$(cat "${w}/codice.txt")" "LP-ABCD-12"
  fuori="$(mktemp -d "${TMP}/fuori.XXXXXX")" || exit 2
  cp "${D04}/demo/nuovo_codice.py" "${fuori}/" || exit 2
  ws w
  con_codici - "${fuori}/nuovo_codice.py" "LP-TK-2026,LP-ABCD-12" "${w}"
  expect_uguale "ticket: senza il file non si controlla" \
    "$(cat "${w}/codice.txt")" "LP-TK-2026"
  ws w
  radice_finta r "TK-1,${L}\n"
  con_codici "${r}" "${D04}/demo/nuovo_codice.py" "${L}" "${w}"
  expect "ticket: ogni estrazione scartata, uscita 2" 2 \
    "nessun codice libero dopo 100 estrazioni"
  if (( EUID == 0 )); then
    skip "ticket: il file che non si legge (da root si legge)"
    return 0
  fi
  chmod 000 "${r}/${TICKET}"
  con_codici "${r}" "${D04}/demo/nuovo_codice.py" "LP-ABCD-12" "${w}"
  expect "ticket: il file che c'è ma non si legge, uscita 2" 2 \
    "c'è ma non si legge"
}

# nuovo_codice.py: le precondizioni, con l'uscita 2 e senza traceback.
t_genera_precondizioni() {
  local w
  ws w
  genera "${w}" --boh
  expect "nuovo_codice: un'opzione sconosciuta" 2 "Uso:"
  genera "${w}" a b
  expect "nuovo_codice: due spazi di lavoro" 2 "uno spazio di lavoro per volta"
  genera "${w}" "${TMP}/assente"
  expect "nuovo_codice: uno spazio di lavoro che non c'è" 2 \
    "spazio di lavoro assente: ${TMP}/assente"
  mkdir "${w}/frase-da-ricordare.txt"
  genera "${w}"
  expect "nuovo_codice: la frase che non si scrive" 2 \
    "frase-da-ricordare.txt non si scrive"
  if [[ ! -e "${w}/codice.txt" ]]; then
    pass "nuovo_codice: senza la frase nessun codice.txt"
  else fail "nuovo_codice: codice.txt scritto senza la frase"; fi
  ws w
  ln -s "${TMP}/altrove.txt" "${w}/codice.txt"
  genera "${w}" --nuovo
  expect "nuovo_codice: codice.txt collegamento simbolico" 2 \
    "codice.txt è un collegamento simbolico"
  if [[ ! -e "${TMP}/altrove.txt" ]]; then
    pass "nuovo_codice: il collegamento non viene seguito"
  else fail "nuovo_codice: ha scritto attraverso il collegamento"; fi
  ws w
  inatteso "${D04}/demo/nuovo_codice.py" estrai_codice "${w}"
  expect "nuovo_codice: un errore inatteso esce 2" 2 \
    "errore inatteso (RuntimeError: guasto finto)"
  expect_absent "nuovo_codice: un errore inatteso, senza traceback" \
    "Traceback"
}

# Le due affermazioni confermate: uscita 0, i dati, nessun falso positivo.
t_confermate() {
  local w
  ws w
  complete "${w}"
  controlla "${w}"
  expect "controlla: il «può» confermato, uscita 0" 0 "${V_CON}: confermata"
  expect "controlla: la garanzia confermata" 0 "${V_SENZA}: confermata"
  expect_absent "controlla: nessun «non confermata»" "${NC}"
  expect_absent "controlla: nessuna frase della garanzia" \
    "La documentazione garantisce"
  expect "controlla: il codice letto" 0 "Codice della linea di prova: ${L}"
  expect "controlla: i dati della chat con la memoria" 0 \
    "Chat con la memoria (risposta-con-memoria.txt): «${L}»"
  expect "controlla: il codice c'è con la memoria" 0 \
    "il codice c'è: sì; NON LO SO: no"
  expect "controlla: NON LO SO senza la memoria" 0 \
    "il codice c'è: no; NON LO SO: sì"
  expect "controlla: con la ricerca spenta, il codice torna dalla memoria" 0 \
    "Con la ricerca nelle chat passate spenta (README, passo 1), il codice può tornare solo dalla memoria"
  expect_absent "controlla: non più «o dalla ricerca»" \
    "o dalla ricerca nelle chat passate"
  expect "controlla: il «può» non fa fallire" 0 \
    "l'esito di una sola esecuzione si stampa e non fa fallire la verifica"
  expect_absent "controlla: la frase finale è della verifica" "Fatto:"
}

# La garanzia: il codice nella risposta senza memoria, in ogni forma; un
# altro codice o le sole lettere non sono il codice.
t_garanzia() {
  local w larga
  caso w risposta-senza-memoria.txt "${L}\n"
  expect "garanzia: il codice esatto, uscita 1" 1 "${G}"
  expect "garanzia: il verdetto" 1 "${V_SENZA}: ${NC}"
  caso w risposta-senza-memoria.txt 'Forse QZKW-37?\n'
  expect "garanzia: senza il prefisso LP-" 1 "${G}"
  caso w risposta-senza-memoria.txt 'lp-qzkw-37\n'
  expect "garanzia: in minuscolo" 1 "${G}"
  caso w risposta-senza-memoria.txt 'LP-QZKW\xe2\x80\x9337\n'
  expect "garanzia: con il trattino medio" 1 "${G}"
  caso w risposta-senza-memoria.txt 'LP QZKW 37\n'
  expect "garanzia: con gli spazi" 1 "${G}"
  caso w risposta-senza-memoria.txt 'LPQZKW37\n'
  expect "garanzia: senza separatori" 1 "${G}"
  larga="$(python3 -B -I -c 'import sys
print("".join(chr(ord(c) + 0xFEE0) for c in sys.argv[1]))' "${L}")"
  caso w risposta-senza-memoria.txt "${larga}\n"
  expect "garanzia: in caratteri larghi" 1 "${G}"
  caso w risposta-senza-memoria.txt "NON LO SO. Forse ${L}?\n"
  expect "garanzia: il codice con NON LO SO conta lo stesso" 1 "${G}"
  caso w risposta-senza-memoria.txt 'LP-QZKW-38\n'
  expect "garanzia: un altro codice non è il codice" 0 \
    "${V_SENZA}: confermata"
  caso w risposta-senza-memoria.txt 'QZKW, e poi non ricordo.\n'
  expect "garanzia: le sole lettere non sono il codice" 0 \
    "${V_SENZA}: confermata"
}

# Il «può»: non confermato non fa fallire; NON LO SO è un dato.
t_puo() {
  local w
  caso w risposta-con-memoria.txt 'NON LO SO.\n'
  expect "può: senza il codice, uscita 0" 0 "${V_CON}: ${NC}"
  expect "può: dove guardare la memoria, nel layout aggiornato" 0 \
    "${DOVE_NUOVO}"
  expect "può: e nel layout precedente delle impostazioni" 0 "${DOVE_PRIMA}"
  expect_absent "può: nessuna frase di garanzia" "La documentazione garantisce"
  expect "può: NON LO SO come dato" 0 "il codice c'è: no; NON LO SO: sì"
  expect "può senza il codice: la garanzia non distinguibile" 0 \
    "${V_SENZA}: ${ND}"
  expect "può senza il codice: il perché" 0 "${SENZA_CON}"
  expect_absent "può senza il codice: la garanzia non è «confermata»" \
    "${V_SENZA}: confermata"
  ws w
  complete "${w}"
  scrivi "${w}" risposta-con-memoria.txt 'NON LO SO.\n'
  scrivi "${w}" risposta-senza-memoria.txt "${L}\n"
  controlla "${w}"
  expect "può senza il codice, il codice senza memoria: non confermata" 1 \
    "${V_SENZA}: ${NC}"
  caso w risposta-con-memoria.txt 'Il codice è qzkw37.\n'
  expect "può: il codice in minuscolo e senza prefisso" 0 \
    "${V_CON}: confermata"
  caso w risposta-con-memoria.txt 'Non lo so, mi spiace.\n'
  expect "può: Non lo so, maiuscole a piacere" 0 "NON LO SO: sì"
  caso w risposta-con-memoria.txt 'Non lo sono mai stato.\n'
  expect "può: «non lo sono» non è NON LO SO" 0 "NON LO SO: no"
}

# codice.txt: manca o è vuoto (1), in minuscolo (letto), senza la forma o
# non UTF-8 (2).
t_codice() {
  local w
  ws w
  complete "${w}"
  rm "${w}/codice.txt"
  controlla "${w}"
  expect "codice.txt che manca, uscita 1" 1 "${MANCA}"
  expect_absent "codice.txt che manca: nessun verdetto" "confermata"
  caso w codice.txt '  \n'
  expect "codice.txt vuoto, uscita 1" 1 "python3 nuovo_codice.py --nuovo"
  caso w codice.txt 'lp-qzkw-37\n'
  expect "codice.txt in minuscolo si legge" 0 "${V_CON}: confermata"
  caso w codice.txt 'ciao\n'
  expect "codice.txt senza la forma, uscita 2" 2 \
    "codice.txt non ha la forma di nuovo_codice.py"
  caso w codice.txt 'LP-QZKW\xe2\x80\x9337\n'
  expect "codice.txt con un altro trattino, uscita 2" 2 "non ha la forma"
  caso w codice.txt '\xff\xfeLP-QZKW-37\n'
  expect "codice.txt non UTF-8, uscita 2" 2 "codice.txt non è testo UTF-8"
}

# Una risposta che manca o è vuota: uscita 1, l'altra decisa lo stesso;
# l'inizio lungo troncato.
t_mancanti() {
  local w lunga
  ws w
  complete "${w}"
  rm "${w}/risposta-senza-memoria.txt"
  controlla "${w}"
  expect "senza memoria che manca, uscita 1" 1 \
    "manca risposta-senza-memoria.txt: fate la chat senza memoria"
  expect "senza memoria che manca: il «può» deciso lo stesso" 1 \
    "${V_CON}: confermata"
  expect "senza memoria che manca: il messaggio finale" 1 "Non ancora:"
  expect_absent "senza memoria che manca: nessun verdetto sulla garanzia" \
    "${V_SENZA}"
  caso w risposta-con-memoria.txt ' \n\t\n'
  expect "con la memoria vuoto, uscita 1" 1 \
    "risposta-con-memoria.txt è vuoto"
  expect "con la memoria vuoto: la garanzia, non distinguibile" 1 \
    "${V_SENZA}: ${ND}"
  # Senza la chat con la memoria, il controllo della garanzia, la risposta
  # senza memoria non mostra niente: mai «confermata», e l'uscita resta 1.
  ws w
  complete "${w}"
  rm "${w}/risposta-con-memoria.txt"
  controlla "${w}"
  expect "con la memoria che manca, uscita 1" 1 \
    "manca risposta-con-memoria.txt: fate la chat con la memoria"
  expect "con la memoria che manca: la garanzia non distinguibile" 1 \
    "${V_SENZA}: ${ND}"
  expect "con la memoria che manca: il perché" 1 "${SENZA_CONTROLLO}"
  expect_absent "con la memoria che manca: la garanzia non è «confermata»" \
    "${V_SENZA}: confermata"
  scrivi "${w}" risposta-senza-memoria.txt "${L}\n"
  controlla "${w}"
  expect "con la memoria che manca, il codice senza memoria: non confermata" \
    1 "${V_SENZA}: ${NC}"
  ws w
  controlla "${w}"
  expect "punto di partenza: manca codice.txt, uscita 1" 1 "${MANCA}"
  lunga="$(printf 'Testo di prova lungo. %.0s' {1..12})"
  caso w risposta-senza-memoria.txt "${lunga}\n"
  expect "l'inizio lungo si tronca a 120 caratteri" 0 "«${lunga:0:120}…»"
}

# Le precondizioni del controllo: uscita 2, senza traceback e senza dati a
# metà; il controllo non scrive niente.
t_precondizioni() {
  local w prima
  caso w risposta-senza-memoria.txt '\xff\xfe testo\n'
  expect "una risposta non UTF-8, uscita 2" 2 \
    "risposta-senza-memoria.txt non è testo UTF-8"
  expect_absent "una risposta non UTF-8: senza traceback" "Traceback"
  expect_absent "una risposta non UTF-8: nessun dato a metà" \
    "Chat con la memoria ("
  ws w
  complete "${w}"
  rm "${w}/risposta-con-memoria.txt"
  mkdir "${w}/risposta-con-memoria.txt"
  controlla "${w}"
  expect "una cartella al posto della risposta, uscita 2" 2 \
    "risposta-con-memoria.txt non si legge"
  controlla "${w}" --boh
  expect "controlla: un'opzione sconosciuta" 2 "Uso:"
  controlla "${w}" . .
  expect "controlla: due spazi di lavoro" 2 "uno spazio di lavoro per volta"
  controlla "${w}" "${TMP}/assente"
  expect "controlla: uno spazio di lavoro che non c'è" 2 \
    "spazio di lavoro assente: ${TMP}/assente"
  inatteso "${D04}/demo/controlla_memoria.py" controlla "${w}"
  expect "controlla: un errore inatteso esce 2, senza traceback" 2 \
    "errore inatteso (RuntimeError: guasto finto)"
  ws w
  complete "${w}"
  prima="$(elenco "${w}")"
  controlla "${w}"
  expect_uguale "controlla: non scrive e non cambia niente" \
    "$(elenco "${w}")" "${prima}"
  if (( EUID == 0 )); then
    skip "una risposta che non si legge (da root si legge)"
    return 0
  fi
  chmod 000 "${w}/risposta-senza-memoria.txt"
  controlla "${w}"
  expect "una risposta che non si legge, uscita 2" 2 \
    "risposta-senza-memoria.txt non si legge"
}

# verifica.sh: le uscite di base, il «può» e la garanzia.
t_verifica() {
  local w a
  run "${D04}/verifica.sh" "${TMP}/assente"
  expect "verifica: spazio di lavoro assente" 2 "spazio di lavoro assente"
  ws w
  run "${D04}/verifica.sh" "${w}"
  expect "verifica: il punto di partenza" 1 "${MANCA}"
  complete "${w}"
  run "${D04}/verifica.sh" "${w}"
  expect "verifica: le risposte complete, uscita 0" 0 "${FINE}"
  expect_uguale "verifica: la frase finale è l'ultima riga" \
    "${OUT##*$'\n'}" "${FINE}"
  scrivi "${w}" risposta-con-memoria.txt 'NON LO SO\n'
  run "${D04}/verifica.sh" "${w}"
  expect "verifica: il «può» non confermato non fa fallire" 0 "${FINE}"
  scrivi "${w}" risposta-senza-memoria.txt "${L}\n"
  run "${D04}/verifica.sh" "${w}"
  expect "verifica: la garanzia che non tiene, uscita 1" 1 "${G}"
  expect_absent "verifica: nessuna frase finale" "Fatto:"
  printf 'import sys\nsys.exit(0)\n' > "${w}/controlla_memoria.py"
  run "${D04}/verifica.sh" "${w}"
  expect "verifica: il controllo dello spazio di lavoro non conta" 1 "${G}"
  scrivi "${w}" codice.txt 'ciao\n'
  run "${D04}/verifica.sh" "${w}"
  expect "verifica: codice.txt senza forma, uscita 2" 2 "non ha la forma"
  complete "${w}"
  run env PATH="${TMP}/senza_python" "${D04}/verifica.sh" "${w}"
  expect "verifica: python3 che manca, uscita 2" 2 "manca python3"
  albero_finto a 3
  run "${a}/verifica.sh" "${w}"
  expect "verifica: un controllo che esce con 3, uscita 2" 2 \
    "controlla_memoria.py è uscito con 3"
  albero_finto a segnale
  run "${a}/verifica.sh" "${w}"
  expect "verifica: un controllo terminato da un segnale, uscita 2" 2 \
    "controlla_memoria.py è uscito con 143"
}

# Il README: le dieci sezioni, la domanda, i file, le citazioni, nessun
# nome interno.
t_readme() {
  run python3 -B -I - "${D04}/README.md" "${D04}/demo/domanda.txt" <<'PY'
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
file = ["nuovo_codice.py", "codice.txt", "frase-da-ricordare.txt",
        "domanda.txt", "controlla_memoria.py", "risposta-con-memoria.txt",
        "risposta-senza-memoria.txt"]
print("file: " + (", ".join(f for f in file if f not in testo) or "tutti"))
citazioni = [
    "Claude can also remember context from your chats and carry it into "
    "new conversations and Cowork tasks.",
    "Claude doesn't use memory in that chat, doesn’t search your past "
    "chats from it, and doesn’t save anything from it to memory.",
    "Select any topic to read it, then use the edit icon to change it or "
    "select \"Delete\" to remove it.",
    "When a conversation is deleted, including under a retention period, "
    "memory entries generated from it aren’t removed, but you can delete "
    "individual memories while memory is on."]
print("citazioni: " + ("tutte" if all(c in piatto for c in citazioni)
                       else "no"))
# I due layout delle impostazioni: il percorso aggiornato c'è, e ogni
# percorso o nome del layout precedente ha «layout precedente delle
# impostazioni» nelle 80 lettere prima.
nuovi = all(s in piatto for s in ("Settings > Your Claude",
                                  "«Memory from chats»",
                                  "«Manage» accanto a «Your memory»"))
vecchi = [m.start() for m in re.finditer(
    r"Settings > Memory|Generate memory from chats", piatto)]
soli = [i for i in vecchi if "layout precedente delle impostazioni"
        not in piatto[max(0, i - 80):i]]
print("layout: " + ("sì" if nuovi and vecchi and not soli
                    else "no (aggiornato: %s; precedenti senza il layout: "
                    "%d)" % ("sì" if nuovi else "no", len(soli))))
vietate = re.findall(r"FACT-|Tecnodata|smentit|\boggi\b|stamattina|"
                     r"prossima sessione|\bX-[0-9]", testo)
print("vietate: " + (", ".join(vietate) or "nessuna"))
PY
  expect "README: le dieci sezioni" 0 "sezioni: tutte"
  expect "README: la domanda di domanda.txt" 0 "domanda: sì"
  expect "README: i file dell'elemento" 0 "file: tutti"
  expect "README: le affermazioni citate parola per parola" 0 \
    "citazioni: tutte"
  expect "README: i due layout delle impostazioni, il precedente detto tale" 0 \
    "layout: sì"
  expect "README: nessun nome interno né riferimento al giorno" 0 \
    "vietate: nessuna"
}

# verifica.sh e questo file, con shellcheck -x.
t_shellcheck() {
  local f
  for f in "${D04}/verifica.sh" "${SELF}"; do
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
      || { echo "test_m3_d04: manca ${t}" >&2; exit 2; }
  done
  [[ -d "${D04}" ]] || { echo "test_m3_d04: manca ${D04}" >&2; exit 2; }
  handson::init_temp_base
  TMP="$(mktemp -d "${HANDSON_TEMP_BASE}/test_m3_d04.XXXXXX")" || exit 2
  trap 'chmod -R u+rwX "${TMP}" 2>/dev/null; rm -rf "${TMP}"' EXIT
  prepara_path
  t_domanda
  t_genera
  t_genera_nuovo
  t_genera_ticket
  t_genera_precondizioni
  t_confermate
  t_garanzia
  t_puo
  t_codice
  t_mancanti
  t_precondizioni
  t_verifica
  t_readme
  t_shellcheck
  echo "PASS=${PASS} FAIL=${FAIL} SKIP=${SKIP}"
  if (( PASS + FAIL + SKIP != CASES )); then
    echo "test_m3_d04: girati $((PASS + FAIL + SKIP)) casi, attesi" \
      "${CASES}" >&2
    exit 2
  fi
  (( FAIL == 0 )) || exit 1
}

main "$@"
