#!/bin/bash
#
# test_m4_d07.sh -- le prove di M4-D07 «Due filoni, due worktree», per il
# docente (sta in _docente/, il materiale del docente):
#   - i due prompt (l'esempio in formato doctest, la rinomina), lo spazio
#     di lavoro di prepara_esercizio.sh (un repository git con un commit,
#     pulito; nessun controllo), dove verifica.sh esce 1;
#   - demo/fotografa.sh su repository git veri, con worktree veri: lo
#     stato del checkout, lo stato di ogni worktree con il suo ramo, le
#     copie di urgenza.py; un worktree che manca registrato come assente;
#     le precondizioni con l'uscita 2;
#   - controlla_worktree.py su stream e fotografie finti scritti qui
#     (percorsi sintetici sotto /tmp/m4ws): le garanzie (la sessione nel
#     suo worktree, sul ramo worktree-<nome>; il checkout principale senza
#     modifiche ai file tracciati; nessuna modifica fuori dal worktree;
#     ogni worktree con la sola modifica della sua sessione) e le loro
#     segnalazioni con l'uscita 1; il blocco confermato solo se una
#     sessione ha provato a modificare il checkout principale e la sua
#     chiamata è nell'elenco permission_denials, non distinguibile se il
#     tentativo è fallito senza esserci, o se nessuna ci ha provato;
#     l'isolamento non
#     distinguibile se l'altra sessione non ha modificato niente; i
#     percorsi relativi, i blocchi senza id, U+2028 in una riga; il
#     braccio senza worktree come dato (tutte e due, una, nessuna, a metà,
#     un file rotto, gli Edit con errore); le coppie che non vanno; gli
#     stream rovinati; le precondizioni con l'uscita 2;
#   - verifica.sh: spazio di lavoro assente (2), punto di partenza (1),
#     esecuzione buona (0, la frase finale), una segnalazione (1), python3
#     che manca (2), un controllo che esce 3 o per un segnale (2);
#   - _docente/live.sh: le precondizioni escono 2 senza chiamare claude
#     (l'esca); con il claude finto (claude_finto_m4_urgenze.py), che con
#     -w crea davvero il worktree con git: i due bracci con i testi e le
#     opzioni del README (il suo blocco gira con lo stesso finto, e le
#     chiamate si confrontano), le fotografie, la verifica, la pulizia
#     (nessun worktree né ramo worktree-* alla fine); un worktree ignorato,
#     una modifica fuori dal worktree, un ramo con un altro nome (1, e la
#     pulizia lo stesso); due tentativi non riusciti, negati o no, e un
#     worktree non bloccato (0); la prima chiamata fallita; i controlli
#     della libreria; un TERM mentre le due sessioni girano (le sessioni
#     fermate, uscita 143);
#   - il README: la garanzia nell'ambito della frase (Edit, Write,
#     NotebookEdit), il percorso dei worktree come lo ha trovato la
#     registrazione, «locked» soltanto come caso di git, cd - prima della
#     verifica e cd nello spazio di lavoro prima della pulizia, il reset per
#     le esecuzioni che ci sono già;
#   - shellcheck -x su verifica.sh, live.sh, lib_worktree.sh (che non è
#     eseguibile), fotografa.sh e questo file.
# Mai il claude vero: il finto e l'esca stanno davanti nel PATH, e la
# suite lo controlla prima di usarli. Gli stream finti non sono risposte
# di Claude: provano il controllo, non il modello. Gli spazi di lavoro
# nascono in una cartella temporanea, nella base di handson::init_temp_base:
# l'albero del repository non cambia. CASES è il numero dei casi: se ne
# girano di più o di meno la suite esce 2 (un caso saltato conta come
# girato).
#
# Uso:    m4_claude_code_agenti/_docente/test_m4_d07.sh
# Uscita: 0 = tutti i casi passano · 1 = almeno un caso fallito · 2 =
#         precondizione (manca python3, git o shellcheck, o la cartella
#         dell'elemento), o un numero di casi diverso da CASES
set -uo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly MOD="${SELF%/_docente/*}"
readonly RADICE="${MOD%/*}"
D07="${MOD}/s3_agente_nel_repository/m4_9_in_parallelo"
D07+="/M4-D07_due_worktree"
readonly D07
readonly FINTO_PY="${MOD}/_docente/claude_finto_m4_urgenze.py"
readonly URG="${RADICE}/progetti/urgenze"
# shellcheck source=../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"
readonly CASES=132
FINE='Fatto: ogni affermazione è stata messa alla prova;'
FINE+=' gli esiti sono qui sopra.'
readonly FINE
PARTENZA='Manca la cartella esecuzioni/ con i due bracci, senza-worktree/'
PARTENZA+=' e con-worktree/: eseguite i passi del README.'
readonly PARTENZA
readonly S_WT="Con -w, un worktree isolato su un ramo nuovo, e Claude parte lì"
readonly S_CO='Le modifiche al checkout principale sono bloccate'
readonly S_IS="Ogni worktree tiene soltanto la modifica della sua sessione"
readonly NONCONF='non confermata in questa esecuzione'
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

# Uno spazio di lavoro vero, con prepara_esercizio.sh (un repository git
# con un commit). Arguments: $1 la variabile da assegnare.
ws_git() {
  local __r
  __r="$(mktemp -d "${TMP}/radice.XXXXXX")" || { echo "mktemp" >&2; exit 2; }
  if ! "${RADICE}/tools/prepara_esercizio.sh" M4-D07 --radice "${__r}" \
      > /dev/null 2>&1; then
    echo "test_m4_d07: prepara_esercizio.sh non riesce" >&2
    exit 2
  fi
  printf -v "$1" '%s' "${__r}/M4-D07"
}

# Uno spazio di lavoro senza git, per il controllo sui dati finti.
# Arguments: $1 la variabile da assegnare.
ws() {
  local __w
  __w="$(mktemp -d "${TMP}/ws.XXXXXX")" || { echo "mktemp" >&2; exit 2; }
  if ! cp -R "${D07}/demo/." "${__w}/" \
      || ! mkdir -p "${__w}/progetti/urgenze" \
      || ! cp -p "${URG}/urgenza.py" "${URG}/test_urgenza.py" \
        "${__w}/progetti/urgenze/"; then
    echo "test_m4_d07: non riesco a preparare lo spazio di lavoro" >&2
    exit 2
  fi
  printf -v "$1" '%s' "${__w}"
}

# Scrive in esecuzioni/ gli stream e le fotografie finti dei due bracci:
# di norma quelli di una prova che conferma. Arguments: $1 lo spazio di
# lavoro, poi le varianti:
#   A_cwd_fuori=<n>  la sessione <n> del braccio con i worktree parte nel
#       checkout principale;  A_ramo=<n>:<ramo>  il suo worktree è su
#       <ramo>;  A_assente=<n>  il suo worktree non c'era;  A_checkout_M
#       il checkout principale è cambiato;  A_edit_fuori=<n>  la sessione
#       modifica anche il file del checkout principale;  A_edit_bloccato=<n>
#       ci prova e riceve un errore;  A_edit_negato=<n>  ci prova, riceve un
#       errore, e la chiamata è nell'elenco permission_denials del
#       risultato;  A_estraneo=<n>  il suo worktree ha
#       anche l'altra modifica;  A_file_estraneo=<n>  nel suo worktree è
#       cambiato test_urgenza.py;  A_proprio=<n>  la sessione scrive da sé
#       anche il segno dell'altra modifica;  A_relativo=<n>  il suo Edit ha
#       un percorso relativo;  A_senza_id=<n>  i suoi blocchi tool_use non
#       hanno id;  A_testo_speciale=<n>  la sua risposta contiene U+2028 e
#       U+0085;  A_nessuna_modifica  le due sessioni leggono soltanto;
#   B_cwd_wt  una sessione del braccio senza worktree parte in un worktree;
#   B_cwd_diverso  le due partono da cartelle diverse;  B_contenuto=<c>
#       urgenza.py del checkout: entrambe, esempio, rinomina, nessuna,
#       meta, rotto;  B_errore=<n>  un Edit con errore;
#   A_altro_checkout  il braccio con i worktree viene da un altro checkout;
#   modello=<braccio>/<n>:<m>  il modello di una sessione;
#   tronco=<braccio>/<n>, solo=…, errore=…, senza_init=…  lo stream rovinato;
#   senza=<percorso>  un file da togliere, relativo a esecuzioni/.
genera() {
  python3 -B -I - "${URG}/urgenza.py" "$@" <<'PY'
import json, os, sys
originale_file, ws = sys.argv[1:3]
varianti = sys.argv[3:]
originale = open(originale_file, encoding="utf-8").read()
ESEMPIO = ('\n"""\n', '\n\n>>> urgente(12, 0)\nTrue\n"""\n')
RINOMINA = ("giorni_aperta", "giorni_di_apertura")
FILE = "progetti/urgenze/urgenza.py"
TEST = "progetti/urgenze/test_urgenza.py"
NOMI = ("esempio", "rinomina")

def opzione(chiave):
    return [v.split("=", 1)[1] for v in varianti
            if v.startswith(chiave + "=")]

def con(testo, *modifiche):
    for m in modifiche:
        vecchio, nuovo = ESEMPIO if m == "esempio" else RINOMINA
        testo = testo.replace(vecchio, nuovo, 1 if m == "esempio" else -1)
    return testo

def sessione(braccio, nome, cwd, principale, extra):
    """Lo stream di una sessione: Read, Edit, risposta, risultato."""
    modello = "modello-finto"
    for v in opzione("modello"):
        chi, _, m = v.partition(":")
        if chi == "%s/%s" % (braccio, nome):
            modello = m
    eventi = [{"type": "system", "subtype": "init", "cwd": cwd,
               "model": modello, "permissionMode": "dontAsk",
               "claude_code_version": "9.9.9"}]
    file_ = cwd + "/" + FILE
    con_wt = braccio == "con-worktree"
    vecchio, nuovo = ESEMPIO if nome == "esempio" else RINOMINA
    chiamate = [("Read", {"file_path": file_}, False)]
    chiamate += extra
    if not (con_wt and "A_nessuna_modifica" in varianti):
        relativo = con_wt and ("A_relativo=" + nome) in varianti
        chiamate.append(("Edit", {"file_path": FILE if relativo else file_,
                                  "old_string": vecchio,
                                  "new_string": nuovo}, False))
    if ("B_errore=" + nome) in varianti and braccio == "senza-worktree":
        chiamate.insert(1, ("Edit", {"file_path": file_,
                                     "old_string": vecchio,
                                     "new_string": nuovo}, True))
    senza_id = con_wt and ("A_senza_id=" + nome) in varianti
    negato = con_wt and ("A_edit_negato=" + nome) in varianti
    dinieghi = []
    for i, (strumento, ingresso, errore) in enumerate(chiamate, 1):
        blocco = {"type": "tool_use", "name": strumento, "input": ingresso}
        risultato = {"type": "tool_result", "content": "finto"}
        if not senza_id:
            blocco["id"] = risultato["tool_use_id"] = "toolu_%s_%d" % (nome,
                                                                       i)
        eventi.append({"type": "assistant", "parent_tool_use_id": None,
                       "message": {"id": "msg_%s_%d" % (nome, i),
                                   "content": [blocco],
                                   "usage": {"input_tokens": 100 * i}}})
        if errore:
            risultato["is_error"] = True
            if negato and ingresso.get("file_path") == (principale + "/"
                                                        + FILE):
                dinieghi.append({"tool_name": strumento,
                                 "tool_use_id": blocco.get("id"),
                                 "tool_input": ingresso})
        eventi.append({"type": "user", "parent_tool_use_id": None,
                       "message": {"content": [risultato]}})
    finale = "fatto"
    if ("A_testo_speciale=" + nome) in varianti:
        finale = "fatto a capo\u0085fine"
    eventi.append({"type": "assistant", "parent_tool_use_id": None,
                   "message": {"id": "msg_%s_fine" % nome,
                               "content": [{"type": "text",
                                            "text": finale}],
                               "usage": {"input_tokens": 999}}})
    eventi.append({"type": "result", "subtype": "success",
                   "is_error": False, "result": "fatto",
                   "duration_ms": 4000, "permission_denials": dinieghi})
    chi = "%s/%s" % (braccio, nome)
    if chi in opzione("errore"):
        eventi[-1]["is_error"] = True
    if chi in opzione("senza_init"):
        eventi = eventi[1:]
    if chi in opzione("solo"):
        eventi = eventi[-1:]
    if chi in opzione("tronco"):
        eventi = eventi[:-1]
    return eventi

def scrivi(percorso, testo):
    os.makedirs(os.path.dirname(percorso), exist_ok=True)
    with open(percorso, "w", encoding="utf-8") as fh:
        fh.write(testo)

def scrivi_stream(percorso, eventi):
    scrivi(percorso, "".join(json.dumps(e, ensure_ascii=False) + "\n"
                             for e in eventi))

principale = "/tmp/m4ws"
base = os.path.join(ws, "esecuzioni")
# Il braccio senza worktree: le due sessioni nel checkout principale.
for nome in NOMI:
    cwd = principale
    if "B_cwd_wt" in varianti and nome == "esempio":
        cwd = principale + "/.claude/worktrees/esempio"
    if "B_cwd_diverso" in varianti and nome == "rinomina":
        cwd = "/tmp/altro"
    scrivi_stream(os.path.join(base, "senza-worktree", nome + ".jsonl"),
                  sessione("senza-worktree", nome, cwd, principale, []))
contenuto_b = {"entrambe": con(originale, "esempio", "rinomina"),
               "esempio": con(originale, "esempio"),
               "rinomina": con(originale, "rinomina"),
               "nessuna": originale,
               "meta": originale.replace(
                   "def urgente(clienti, giorni_aperta)",
                   "def urgente(clienti, giorni_di_apertura)"),
               "rotto": originale + "\ndef rotto(:\n"}
scelta = (opzione("B_contenuto") or ["entrambe"])[0]
scrivi(os.path.join(base, "senza-worktree", "urgenza.py"),
       contenuto_b[scelta])
scrivi(os.path.join(base, "senza-worktree", "checkout.txt"),
       " M %s\n?? esecuzioni/\n" % FILE)
# Il braccio con i worktree.
principale_a = "/tmp/m4altro" if "A_altro_checkout" in varianti \
    else principale
for nome in NOMI:
    altro = "rinomina" if nome == "esempio" else "esempio"
    cwd = principale_a + "/.claude/worktrees/" + nome
    if ("A_cwd_fuori=" + nome) in varianti:
        cwd = principale_a
    extra = []
    if ("A_edit_fuori=" + nome) in varianti:
        vecchio, nuovo = ESEMPIO if nome == "esempio" else RINOMINA
        extra.append(("Edit", {"file_path": principale_a + "/" + FILE,
                               "old_string": vecchio,
                               "new_string": nuovo}, False))
    if ("A_edit_bloccato=" + nome) in varianti \
            or ("A_edit_negato=" + nome) in varianti:
        extra.append(("Edit", {"file_path": principale_a + "/" + FILE,
                               "old_string": "x", "new_string": "y"}, True))
    if ("A_proprio=" + nome) in varianti:
        segno = ">>> urgente(1, 0)" if nome == "rinomina" \
            else "giorni_di_apertura"
        extra.append(("Edit", {"file_path": cwd + "/" + FILE,
                               "old_string": "x", "new_string": segno},
                      False))
    scrivi_stream(os.path.join(base, "con-worktree", nome + ".jsonl"),
                  sessione("con-worktree", nome, cwd, principale_a, extra))
    ramo = "worktree-" + nome
    for v in opzione("A_ramo"):
        chi, _, r = v.partition(":")
        if chi == nome:
            ramo = r
    stato = "## %s\n M %s\n" % (ramo, FILE)
    if "A_nessuna_modifica" in varianti:
        stato = "## %s\n" % ramo
    if ("A_file_estraneo=" + nome) in varianti:
        stato += " M %s\n" % TEST
    if ("A_assente=" + nome) in varianti:
        stato = ""
    scrivi(os.path.join(base, "con-worktree", nome + ".status"), stato)
    if stato:
        modifiche = [] if "A_nessuna_modifica" in varianti else [nome]
        if ("A_estraneo=" + nome) in varianti:
            modifiche.append(altro)
        testo = con(originale, *modifiche)
        if ("A_proprio=" + nome) in varianti:
            testo += "\n# >>> urgente(1, 0)\n" if nome == "rinomina" \
                else "\n# giorni_di_apertura\n"
        scrivi(os.path.join(base, "con-worktree", nome + ".py"), testo)
checkout_a = "?? .claude/worktrees/\n?? esecuzioni/\n"
if "A_checkout_M" in varianti:
    checkout_a = " M %s\n" % FILE + checkout_a
scrivi(os.path.join(base, "con-worktree", "checkout.txt"), checkout_a)
for v in opzione("senza"):
    os.remove(os.path.join(base, v))
PY
}

# Il controllo dell'elemento sullo spazio di lavoro $1 (gli argomenti che
# seguono vanno prima); RC e OUT come run.
controlla() {
  local w="$1"
  shift
  run python3 -B -I "${D07}/controlla_worktree.py" "$@" "${w}"
}

# Uno spazio di lavoro con i dati finti di genera e le varianti date, poi
# il controllo. Arguments: le varianti di genera.
con_varianti() {
  local w
  ws w
  genera "${w}" "$@"
  controlla "${w}"
}

# Il ramo dell'errore inatteso: main() del controllo con un controlla()
# che solleva un'eccezione. Arguments: gli argomenti di main.
inatteso() {
  run python3 -B -I -c 'import importlib.util, sys
spec = importlib.util.spec_from_file_location("controllo", sys.argv[1])
modulo = importlib.util.module_from_spec(spec)
spec.loader.exec_module(modulo)
def guasto(*_):
    raise RuntimeError("guasto finto")
modulo.controlla = guasto
sys.exit(modulo.main(sys.argv[2:]))' "${D07}/controlla_worktree.py" "$@"
}

# Una copia di verifica.sh in cui il controllo è finto: esce con il codice
# dato, o si fa terminare da un segnale.
# Arguments: $1 la variabile da assegnare (la copia), $2 il codice
# d'uscita, oppure «segnale».
albero_finto() {
  local __a
  __a="$(mktemp -d "${TMP}/albero.XXXXXX")" || { echo "mktemp" >&2; exit 2; }
  cp -- "${D07}/verifica.sh" "${__a}/" || exit 2
  if [[ "$2" == segnale ]]; then
    printf '%s\n' 'import os, signal' 'os.kill(os.getpid(), signal.SIGTERM)' \
      > "${__a}/controlla_worktree.py"
  else
    printf 'import sys\nsys.exit(%d)\n' "$2" > "${__a}/controlla_worktree.py"
  fi
  printf -v "$1" '%s' "${__a}"
}

# L'esca in ${TMP}/esca (registra ogni invocazione ed esce 0); il claude
# finto in ${TMP}/finto; ${TMP}/senza_python, un PATH con readlink,
# dirname, git e l'esca; ${TMP}/senza_claude, uno con readlink, python3 e
# git. Esce 2 se nel PATH di prova il claude trovato non è il finto.
prepara_claude() {
  local t
  mkdir -p "${TMP}/esca" "${TMP}/finto" "${TMP}/senza_python" \
    "${TMP}/senza_claude" || exit 2
  # shellcheck disable=SC2016  # il corpo è dell'esca
  printf '%s\n' '#!/bin/bash' \
    'printf "invocazione %s\n" "$*" >> "${ESCA_LOG}"' \
    > "${TMP}/esca/claude" || exit 2
  cp -- "${FINTO_PY}" "${TMP}/finto/claude" || exit 2
  chmod 755 "${TMP}/esca/claude" "${TMP}/finto/claude" || exit 2
  ln -s "${TMP}/esca/claude" "${TMP}/senza_python/claude" || exit 2
  for t in readlink dirname git; do
    ln -s "$(command -v "${t}")" "${TMP}/senza_python/${t}" || exit 2
  done
  for t in readlink python3 git; do
    ln -s "$(command -v "${t}")" "${TMP}/senza_claude/${t}" || exit 2
  done
  t="$(PATH="${TMP}/finto:${PATH}" command -v claude)"
  if [[ "${t}" != "${TMP}/finto/claude" ]]; then
    echo "test_m4_d07: nel PATH di prova claude è ${t}, non il finto" >&2
    exit 2
  fi
}

# live.sh con l'esca davanti nel PATH (o con un PATH dato); il registro
# delle invocazioni riparte vuoto. Arguments: $1 lo spazio di lavoro, $2
# facoltativo il PATH.
esca() {
  : > "${TMP}/esca.log"
  run env PATH="${2:-${TMP}/esca:${PATH}}" HANDSON_NO_PAUSE=1 \
    ESCA_LOG="${TMP}/esca.log" "${D07}/_docente/live.sh" "$1"
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

# live.sh con il claude finto davanti nel PATH e ANTHROPIC_API_KEY
# impostata (live.sh la deve togliere); il registro riparte vuoto.
# Arguments: $1 lo spazio di lavoro, poi le variabili NOME=valore.
finto() {
  local w="$1"
  shift
  : > "${TMP}/finto.log"
  run env PATH="${TMP}/finto:${PATH}" HANDSON_NO_PAUSE=1 \
    ANTHROPIC_API_KEY=valore-finto FINTO_LOG="${TMP}/finto.log" "$@" \
    "${D07}/_docente/live.sh" "${w}"
}

# Quante chiamate al modello (non --version) ha ricevuto il finto, e
# quante con ANTHROPIC_API_KEY. Arguments: $1 il registro.
# Outputs: «chiamate chiavi».
chiamate() {
  python3 -B -I - "$1" <<'PY'
import json, sys
righe = [json.loads(r) for r in open(sys.argv[1], encoding="utf-8")]
modello = [r for r in righe if r["argv"][:1] != ["--version"]]
print(len(modello), sum(1 for r in modello if r["chiave"]))
PY
}

# I worktree e i rami worktree-* che restano in un repository.
# Arguments: $1 il repository. Outputs: «worktree rami».
residui() {
  local wt rami
  wt="$(git -C "$1" worktree list --porcelain | grep -c '^worktree ')"
  rami="$(git -C "$1" branch --list 'worktree-*' 'altro-*' | grep -c .)"
  echo "$((wt - 1)) ${rami}"
}

# Il blocco di comandi del README fra le righe «<!-- comandi -->» e
# «<!-- /comandi -->», senza il rientro comune, in un file.
# Arguments: $1 il file. Returns: 0; 1 se il blocco non c'è.
blocco_readme() {
  python3 -B -I - "${D07}/README.md" "$1" <<'PY'
import sys, textwrap
righe = open(sys.argv[1], encoding="utf-8").read().split("\n")
segni = [i for i, r in enumerate(righe)
         if r.strip() in ("<!-- comandi -->", "<!-- /comandi -->")]
if len(segni) != 2:
    sys.exit(1)
blocco = textwrap.dedent("\n".join(righe[segni[0] + 1:segni[1]])).strip()
if "claude -p" not in blocco:
    sys.exit(1)
with open(sys.argv[2], "w", encoding="utf-8") as fh:
    fh.write(blocco + "\n")
PY
}

# --- I prompt e lo spazio di lavoro -----------------------------------------

t_file() {
  local e r
  e="$(cat "${D07}/demo/prompt-esempio.txt")"
  r="$(cat "${D07}/demo/prompt-rinomina.txt")"
  if [[ "${e}" == *doctest* && "${e}" == *">>>"* \
      && "${e}" == *progetti/urgenze/urgenza.py* \
      && "${e}" == *"Non cambiare altro"* \
      && "${e}" != *giorni_di_apertura* ]]; then
    pass "prompt: l'esempio in formato doctest, nient'altro"
  else
    fail "prompt-esempio.txt: «${e}»"
  fi
  if [[ "${r}" == *giorni_aperta* && "${r}" == *giorni_di_apertura* \
      && "${r}" == *progetti/urgenze/urgenza.py* \
      && "${r}" == *progetti/urgenze/test_urgenza.py* \
      && "${r}" == *"Non cambiare altro"* && "${r}" != *">>>"* ]]; then
    pass "prompt: la rinomina nel modulo e nei test, nient'altro"
  else
    fail "prompt-rinomina.txt: «${r}»"
  fi
  if [[ ! -e "${D07}/demo/controlla_worktree.py" \
      && -f "${D07}/controlla_worktree.py" ]]; then
    pass "il controllo sta nella cartella dell'elemento, non in demo/"
  else
    fail "il controllo non è dove deve stare"
  fi
}

# prepara_esercizio.sh: un repository git con un commit e pulito, e lì
# verifica.sh esce 1.
t_prepara() {
  local r="${TMP}/radice" w
  run "${RADICE}/tools/prepara_esercizio.sh" M4-D07 --radice "${r}"
  expect "prepara: lo spazio di lavoro nasce" 0 "Spazio di lavoro pronto"
  w="${r}/M4-D07"
  if [[ -f "${w}/progetti/urgenze/urgenza.py" \
      && -f "${w}/prompt-esempio.txt" && -f "${w}/prompt-rinomina.txt" \
      && -f "${w}/fotografa.sh" && -f "${w}/.claude/settings.json" \
      && ! -e "${w}/progetti/urgenze/_docente" \
      && ! -e "${w}/controlla_worktree.py" && ! -e "${w}/soluzione" \
      && ! -e "${w}/_docente" ]]; then
    pass "prepara: il progetto, i prompt e la fotografia, niente altro"
  else
    fail "prepara: lo spazio di lavoro non è quello atteso"
  fi
  if [[ "$(git -C "${w}" rev-list --count HEAD)" == 1 \
      && -z "$(git -C "${w}" status --porcelain)" ]]; then
    pass "prepara: un repository git con un commit, pulito"
  else
    fail "prepara: il repository git non è quello atteso"
  fi
  run "${RADICE}/tools/verifica.sh" M4-D07 --radice "${r}"
  expect "prepara: sul punto di partenza la verifica esce 1" 1 "${PARTENZA}"
}

# --- demo/fotografa.sh ------------------------------------------------------

t_fotografa() {
  local w d
  ws_git w
  git -C "${w}" worktree add -q -b worktree-esempio \
    .claude/worktrees/esempio HEAD
  git -C "${w}" worktree add -q -b worktree-rinomina \
    .claude/worktrees/rinomina HEAD
  printf '# in più\n' >> "${w}/.claude/worktrees/esempio/progetti/urgenze/\
urgenza.py"
  mkdir -p "${w}/esecuzioni/con-worktree"
  run bash -c 'cd "$1" && bash fotografa.sh con-worktree' _ "${w}"
  d="${w}/esecuzioni/con-worktree"
  expect "fotografa: con i worktree, uscita 0" 0 \
    "Fotografia di con-worktree in esecuzioni/con-worktree/"
  if [[ "$(head -n 1 "${d}/esempio.status")" == "## worktree-esempio" ]] \
      && grep -qx ' M progetti/urgenze/urgenza.py' "${d}/esempio.status" \
      && [[ "$(cat "${d}/rinomina.status")" == "## worktree-rinomina" ]] \
      && cmp -s "${d}/esempio.py" \
        "${w}/.claude/worktrees/esempio/progetti/urgenze/urgenza.py" \
      && grep -qx '?? .claude/worktrees/' "${d}/checkout.txt"; then
    pass "fotografa: lo stato e il ramo di ogni worktree, le copie"
  else
    fail "fotografa: le fotografie del braccio con i worktree"
  fi
  git -C "${w}" worktree remove --force .claude/worktrees/rinomina
  rm -rf "${d}"
  mkdir -p "${d}"
  run bash -c 'cd "$1" && bash fotografa.sh con-worktree' _ "${w}"
  if (( RC == 0 )) && [[ -f "${d}/rinomina.status" \
      && ! -s "${d}/rinomina.status" && ! -e "${d}/rinomina.py" ]] \
      && grep -qF 'il worktree .claude/worktrees/rinomina non c' \
        <<< "${OUT}"; then
    pass "fotografa: un worktree che manca, registrato come assente"
  else
    fail "fotografa: un worktree che manca, rc=${RC}: ${OUT}"
  fi
  printf '# nel checkout\n' >> "${w}/progetti/urgenze/urgenza.py"
  mkdir -p "${w}/esecuzioni/senza-worktree"
  run bash -c 'cd "$1" && bash fotografa.sh senza-worktree' _ "${w}"
  if (( RC == 0 )) && cmp -s "${w}/progetti/urgenze/urgenza.py" \
      "${w}/esecuzioni/senza-worktree/urgenza.py" \
      && grep -qx ' M progetti/urgenze/urgenza.py' \
        "${w}/esecuzioni/senza-worktree/checkout.txt"; then
    pass "fotografa: senza worktree, lo stato e la copia del checkout"
  else
    fail "fotografa: senza worktree, rc=${RC}: ${OUT}"
  fi
  run bash -c 'cd "$1" && bash fotografa.sh tutti' _ "${w}"
  expect "fotografa: un braccio sconosciuto, uscita 2" 2 "uso:"
  run bash -c 'cd "$1/progetti" && bash ../fotografa.sh con-worktree' _ \
    "${w}"
  expect "fotografa: non dalla cima del repository, uscita 2" 2 \
    "dalla cartella dello spazio di lavoro"
  rm -rf "${w}/esecuzioni"
  run bash -c 'cd "$1" && bash fotografa.sh con-worktree' _ "${w}"
  expect "fotografa: la cartella del braccio che manca, uscita 2" 2 \
    "manca esecuzioni/con-worktree/"
}

# --- controlla_worktree.py ---------------------------------------------------

t_buona() {
  con_varianti
  expect "buona: uscita 0, il worktree dell'esempio" 0 \
    "${S_WT} (esempio): confermata: partita in .claude/worktrees/esempio, \
sul ramo worktree-esempio"
  expect "buona: il worktree della rinomina" 0 \
    "${S_WT} (rinomina): confermata"
  expect "buona: il blocco non messo alla prova, non distinguibile" 0 \
    "${S_CO}: non distinguibile: nessuna sessione ha provato a modificare \
il checkout principale; il checkout principale non ha modifiche ai file \
tracciati"
  expect "buona: l'esempio solo nel suo worktree" 0 \
    "${S_IS} (esempio): confermata"
  expect "buona: la rinomina solo nel suo worktree" 0 \
    "${S_IS} (rinomina): confermata"
  expect "buona: senza worktree, le due modifiche mescolate" 0 \
    "senza worktree, urgenza.py nel checkout: l'esempio sì, la rinomina sì: \
le due modifiche nello stesso file, nello stesso checkout"
  expect "buona: i dati di un worktree" 0 \
    "con-worktree/esempio: partita in .claude/worktrees/esempio, ramo \
worktree-esempio; strumenti: Edit 1, Read 1; nel worktree: M \
progetti/urgenze/urgenza.py; urgenza.py: l'esempio sì, la rinomina no"
  expect "buona: i worktree restano dopo claude -p, come dato" 0 \
    "dopo claude -p i worktree c'erano ancora: esempio, rinomina"
  expect "buona: i file non tracciati, come dato" 0 \
    "con i worktree, il checkout principale: nessuna modifica ai file \
tracciati; non tracciati: .claude/worktrees/, esecuzioni/"
  expect_absent "buona: nessuna segnalazione" "Segnalazioni"
}

# Le garanzie che non tengono: una segnalazione, uscita 1; un tentativo
# non riuscito, una modifica propria, un percorso relativo, nessuna
# modifica, blocchi senza id, U+2028: uscita 0.
t_garanzie() {
  con_varianti A_cwd_fuori=esempio
  expect "garanzie: una sessione fuori dal worktree" 1 \
    "${S_WT} (esempio): ${NONCONF}: la sessione non è partita in \
.claude/worktrees/esempio; una segnalazione"
  con_varianti A_ramo=esempio:altro-esempio
  expect "garanzie: un ramo con un altro nome" 1 \
    "il worktree è sul ramo altro-esempio, non su worktree-esempio"
  con_varianti A_assente=rinomina
  expect "garanzie: un worktree che non c'era" 1 \
    "il worktree .claude/worktrees/rinomina non c'era dopo l'esecuzione"
  con_varianti A_checkout_M
  expect "garanzie: il checkout principale cambiato" 1 \
    "${S_CO}: ${NONCONF}: il checkout principale è cambiato: M \
progetti/urgenze/urgenza.py; una segnalazione"
  con_varianti A_edit_fuori=esempio
  expect "garanzie: una modifica fuori dal worktree" 1 \
    "la sessione esempio ha modificato progetti/urgenze/urgenza.py del \
checkout principale"
  con_varianti A_estraneo=esempio
  expect "garanzie: nel worktree la modifica dell'altra sessione" 1 \
    "${S_IS} (esempio): ${NONCONF}: nel worktree c'è la rinomina, che la \
sua sessione non ha scritto; una segnalazione"
  con_varianti A_estraneo=rinomina
  expect "garanzie: e viceversa" 1 \
    "nel worktree c'è l'esempio, che la sua sessione non ha scritto"
  con_varianti A_file_estraneo=rinomina
  expect "garanzie: un file cambiato che la sessione non ha toccato" 1 \
    "nel worktree è cambiato progetti/urgenze/test_urgenza.py, che la sua \
sessione non ha modificato"
  expect "garanzie: la riga delle segnalazioni" 1 "Segnalazioni: 1."
  # Un tentativo fallito conta come blocco soltanto se la chiamata è
  # nell'elenco permission_denials: un errore qualunque non si distingue.
  con_varianti A_edit_bloccato=esempio
  expect "garanzie: un tentativo fallito fuori dall'elenco, non distinguibile" \
    0 "${S_CO}: non distinguibile: 1 tentativo di modificare il checkout \
principale non riuscito, ma non nell'elenco permission_denials"
  expect_absent "garanzie: e non confermata" "${S_CO}: confermata"
  con_varianti A_edit_negato=esempio
  expect "garanzie: un tentativo negato, nell'elenco, confermata" 0 \
    "${S_CO}: confermata: 1 tentativo di modificare il checkout principale, \
negato (nell'elenco permission_denials); il checkout principale non ha \
modifiche ai file tracciati"
  con_varianti A_proprio=rinomina
  expect "garanzie: un segno scritto dalla sessione stessa non è estraneo" 0 \
    "${S_IS} (rinomina): confermata"
  con_varianti A_relativo=esempio
  expect "garanzie: un percorso relativo è nel worktree della sessione" 0 \
    "${S_IS} (esempio): confermata"
  con_varianti A_nessuna_modifica
  expect "garanzie: nessuna modifica, l'isolamento non distinguibile" 0 \
    "${S_IS} (esempio): non distinguibile: l'altra sessione non ha \
modificato niente"
  con_varianti A_senza_id=esempio
  expect "garanzie: blocchi senza id, contati tutti" 0 \
    "con-worktree/esempio: partita in .claude/worktrees/esempio, ramo \
worktree-esempio; strumenti: Edit 1, Read 1;"
  con_varianti A_testo_speciale=rinomina
  expect "garanzie: U+2028 e U+0085 in una riga non la spezzano" 0 \
    "${S_WT} (rinomina): confermata"
}

# Il braccio senza worktree, come dato.
t_dati_senza() {
  con_varianti B_contenuto=esempio
  expect "senza: solo l'esempio" 0 \
    "urgenza.py nel checkout: l'esempio sì, la rinomina no"
  con_varianti B_contenuto=rinomina
  expect "senza: solo la rinomina" 0 \
    "urgenza.py nel checkout: l'esempio no, la rinomina sì"
  con_varianti B_contenuto=nessuna
  expect "senza: nessuna delle due" 0 \
    "urgenza.py nel checkout: l'esempio no, la rinomina no"
  con_varianti B_contenuto=meta
  expect "senza: la rinomina a metà" 0 "la rinomina a metà"
  con_varianti B_contenuto=rotto
  expect "senza: un file che non è più Python valido" 0 \
    "urgenza.py nel checkout non è più Python valido"
  con_varianti B_errore=rinomina
  expect "senza: un Edit con errore, come dato" 0 \
    "senza-worktree/rinomina: partita nel checkout principale; strumenti: \
Edit 2, Read 1 (1 con errore)"
}

# Le coppie che non vanno: uscita 1, il motivo.
t_coppie() {
  con_varianti B_cwd_wt
  expect "coppie: senza worktree, una sessione in un worktree" 1 \
    "la sessione esempio del braccio senza worktree è partita in un worktree"
  con_varianti B_cwd_diverso
  expect "coppie: le due sessioni da cartelle diverse" 1 \
    "le due sessioni del braccio senza worktree non sono partite dalla \
stessa cartella"
  con_varianti A_altro_checkout
  expect "coppie: due checkout diversi" 1 \
    "i due bracci non vengono dallo stesso checkout"
  con_varianti modello=con-worktree/rinomina:altro
  expect "coppie: due modelli diversi" 1 \
    "le sessioni non hanno lo stesso modello e la stessa modalità"
  con_varianti senza=con-worktree/esempio.status
  expect "coppie: una fotografia che manca" 1 \
    "manca la fotografia esecuzioni/con-worktree/esempio.status"
  con_varianti senza=senza-worktree/urgenza.py
  expect "coppie: la copia del checkout che manca" 1 \
    "manca la fotografia esecuzioni/senza-worktree/urgenza.py"
  local w
  ws w
  genera "${w}"
  rm -rf "${w}/esecuzioni/con-worktree"
  controlla "${w}"
  expect "coppie: un braccio che manca" 1 "manca il braccio con-worktree"
}

# Gli stream rovinati: uscita 1, il motivo, nessun traceback.
t_rovinati() {
  local w
  con_varianti senza=con-worktree/rinomina.jsonl
  expect "rovinati: uno stream che manca" 1 \
    "manca esecuzioni/con-worktree/rinomina.jsonl"
  expect "rovinati: il messaggio «Non ancora»" 1 "Non ancora:"
  ws w
  genera "${w}"
  : > "${w}/esecuzioni/senza-worktree/esempio.jsonl"
  controlla "${w}"
  expect "rovinati: uno stream vuoto" 1 "senza-worktree/esempio.jsonl è vuoto"
  printf '{"type": "system"}\n{rotto\n' \
    > "${w}/esecuzioni/senza-worktree/esempio.jsonl"
  controlla "${w}"
  expect "rovinati: una riga che non è JSON" 1 \
    "esempio.jsonl, riga 2: non è un evento dello stream-json"
  con_varianti tronco=con-worktree/esempio
  expect "rovinati: senza il risultato in fondo" 1 \
    "lo stream non finisce con il risultato"
  con_varianti solo=con-worktree/esempio
  expect "rovinati: soltanto il risultato" 1 \
    "c'è soltanto il risultato, senza gli eventi"
  con_varianti errore=con-worktree/esempio
  expect "rovinati: is_error" 1 "claude ha restituito un errore"
  con_varianti senza_init=con-worktree/rinomina
  expect "rovinati: senza l'evento di avvio" 1 \
    "con-worktree/rinomina.jsonl: manca l'evento di avvio con la cartella"
  expect_absent "rovinati: mai un traceback" "Traceback"
}

# esecuzioni/ che manca, gli argomenti, le precondizioni.
t_precondizioni() {
  local w
  ws w
  controlla "${w}"
  expect "partenza: esecuzioni/ che manca, uscita 1" 1 "${PARTENZA}"
  genera "${w}"
  run python3 -B -I "${D07}/controlla_worktree.py" --tutto "${w}"
  expect "precondizione: un'opzione sconosciuta, uscita 2" 2 \
    "opzione sconosciuta: --tutto"
  run python3 -B -I "${D07}/controlla_worktree.py" "${w}" "${w}"
  expect "precondizione: due spazi di lavoro" 2 \
    "uno spazio di lavoro per volta"
  run python3 -B -I "${D07}/controlla_worktree.py" "${TMP}/assente"
  expect "precondizione: spazio di lavoro assente" 2 \
    "spazio di lavoro assente"
  inatteso "${w}"
  expect "precondizione: un errore inatteso, uscita 2" 2 \
    "errore inatteso (RuntimeError: guasto finto)"
  expect_absent "precondizione: l'errore inatteso senza traceback" \
    "Traceback"
  if (( EUID == 0 )); then
    skip "precondizione: una fotografia che non si legge (da root si legge)"
    return 0
  fi
  chmod 000 "${w}/esecuzioni/con-worktree/checkout.txt"
  controlla "${w}"
  expect "precondizione: una fotografia che non si legge" 2 \
    "esecuzioni/con-worktree/checkout.txt non si legge"
  chmod 644 "${w}/esecuzioni/con-worktree/checkout.txt"
}

# --- verifica.sh ------------------------------------------------------------

t_verifica() {
  local w a
  run "${D07}/verifica.sh"
  expect "verifica: senza spazio di lavoro, uscita 2" 2 \
    "spazio di lavoro assente"
  ws w
  run "${D07}/verifica.sh" "${w}"
  expect "verifica: il punto di partenza, uscita 1" 1 "${PARTENZA}"
  genera "${w}"
  run "${D07}/verifica.sh" "${w}"
  expect "verifica: un'esecuzione buona, uscita 0" 0 "${FINE}"
  if [[ "${OUT##*$'\n'}" == "${FINE}" ]]; then
    pass "verifica: la frase finale è l'ultima riga"
  else
    fail "verifica: l'ultima riga è «${OUT##*$'\n'}»"
  fi
  genera "${w}" A_checkout_M
  run "${D07}/verifica.sh" "${w}"
  expect "verifica: una segnalazione, uscita 1" 1 "Segnalazioni: 1."
  expect_absent "verifica: una segnalazione, nessuna frase finale" "Fatto:"
  run env PATH="${TMP}/senza_python" "${D07}/verifica.sh" "${w}"
  expect "verifica: python3 che manca, uscita 2" 2 "manca python3"
  albero_finto a 3
  run "${a}/verifica.sh" "${w}"
  expect "verifica: un controllo che esce con 3, uscita 2" 2 \
    "controlla_worktree.py è uscito con 3"
  albero_finto a segnale
  run "${a}/verifica.sh" "${w}"
  expect "verifica: un controllo terminato da un segnale, uscita 2" 2 \
    "controlla_worktree.py è uscito con 143"
}

# --- _docente/live.sh -------------------------------------------------------

# Le precondizioni escono 2 prima di ogni invocazione di claude.
t_live_precondizioni() {
  local w f
  precondizione "live: spazio di lavoro assente" "spazio di lavoro assente" \
    "${TMP}/assente"
  for f in prompt-esempio.txt fotografa.sh progetti/urgenze/urgenza.py; do
    ws_git w
    rm "${w}/${f}"
    precondizione "live: ${f} che manca" "file assente o illeggibile: ${f}" \
      "${w}"
  done
  ws w
  precondizione "live: uno spazio di lavoro che non è un repository git" \
    "non è un repository git con un commit" "${w}"
  ws_git w
  printf '# cambiato\n' >> "${w}/progetti/urgenze/urgenza.py"
  precondizione "live: un checkout con modifiche" \
    "il checkout principale ha modifiche" "${w}"
  ws_git w
  mkdir "${w}/esecuzioni"
  precondizione "live: esecuzioni/ che c'è già" "ci sono già delle esecuzioni" \
    "${w}"
  ws_git w
  git -C "${w}" branch worktree-rinomina
  precondizione "live: un ramo worktree-* che c'è già" \
    "c'è già il ramo worktree-rinomina" "${w}"
  ws_git w
  precondizione "live: python3 che manca" "manca lo strumento: python3" \
    "${w}" "${TMP}/senza_python"
  ws_git w
  esca "${w}" "${TMP}/senza_claude"
  expect "live: claude che manca" 2 "manca lo strumento: claude"
}

# Il claude finto, che con -w crea davvero i worktree: i due bracci, le
# fotografie, la verifica, la pulizia; il testo e le opzioni del README.
t_live_finto() {
  local w w2 r
  ws_git w
  finto "${w}"
  expect "live: i due bracci, uscita 0" 0 "VERIFICA OK"
  expect "live: i dati e i verdetti si vedono anche quando passa" 0 "${FINE}"
  expect "live: le garanzie dei worktree" 0 "${S_IS} (rinomina): confermata"
  expect "live: la riga di claude con -w si vede prima di girare" 0 \
    "claude -p -w esempio"
  r="$(chiamate "${TMP}/finto.log")"
  if [[ "${r}" == "4 0" ]]; then
    pass "live: quattro chiamate, senza ANTHROPIC_API_KEY"
  else
    fail "live: chiamate e chiavi «${r}», attese «4 0»"
  fi
  r="$(residui "${w}")"
  if [[ "${r}" == "0 0" && ! -e "${w}/.claude/worktrees/esempio" ]]; then
    pass "live: la pulizia, nessun worktree né ramo worktree-*"
  else
    fail "live: dopo la pulizia restano «${r}» (worktree, rami)"
  fi
  if [[ -z "$(git -C "${w}" status --porcelain -- progetti)" ]]; then
    pass "live: il checkout principale torna pulito"
  else
    fail "live: il checkout principale ha modifiche"
  fi
  run "${D07}/verifica.sh" "${w}"
  expect "live: dopo la pulizia la verifica decide dalle fotografie" 0 \
    "${FINE}"
  cp "${TMP}/finto.log" "${TMP}/live.log"
  ws_git w2
  if ! blocco_readme "${TMP}/passo.sh"; then
    fail "README: il blocco dei comandi non c'è"
    return 0
  fi
  : > "${TMP}/readme.log"
  ( cd "${w2}" && PATH="${TMP}/finto:${PATH}" \
      FINTO_LOG="${TMP}/readme.log" bash "${TMP}/passo.sh" ) > /dev/null 2>&1
  run python3 -B -I - "${w}" "${w2}" "${TMP}/live.log" "${TMP}/readme.log" \
    <<'PY'
import json, os, sys
ws, ws2, log_live, log_readme = sys.argv[1:5]
VALORE = {"--model", "--effort", "--tools", "--allowedTools",
          "--output-format", "--setting-sources", "--permission-mode",
          "--permission-prompts", "-w", "--worktree"}

def chiamate(log):
    righe = [json.loads(r) for r in open(log, encoding="utf-8")]
    return [r for r in righe if r["argv"][:1] != ["--version"]]

def analizza(argv):
    """(il prompt, le opzioni): il prompt dopo «--», o l'operando."""
    opzioni, prompt, i = {}, None, 0
    while i < len(argv):
        a = argv[i]
        if a == "--":
            prompt = argv[i + 1]
            break
        if a in VALORE:
            opzioni[a] = argv[i + 1]
            i += 2
        elif a.startswith("-"):
            opzioni[a] = True
            i += 1
        else:
            prompt = a
            i += 1
    return prompt, opzioni

def leggi(nome):
    with open(os.path.join(ws, nome), encoding="utf-8") as fh:
        return fh.read().rstrip("\n")

testi = {leggi("prompt-esempio.txt"): "esempio",
         leggi("prompt-rinomina.txt"): "rinomina"}
problemi = []

def per_chiave(righe, base):
    gruppi = {}
    for riga in righe:
        prompt, opzioni = analizza(riga["argv"])
        nome = testi.get(prompt)
        if nome is None:
            problemi.append("un prompt sconosciuto")
            continue
        wt = opzioni.get("-w")
        if wt is not None and wt != nome:
            problemi.append("-w %s per %s" % (wt, nome))
        if os.path.realpath(riga["cwd"]) != os.path.realpath(base):
            problemi.append("la cartella di partenza")
        gruppi[(nome, wt is not None)] = (opzioni, riga["argv"])
    return gruppi

live = per_chiave(chiamate(log_live), ws)
readme = per_chiave(chiamate(log_readme), ws2)
if len(live) != 4 or len(readme) != 4:
    problemi.append("chiamate: live.sh %d, README %d" % (len(live),
                                                        len(readme)))
fisse = (("--model", "sonnet"), ("--allowedTools", "Read,Edit"),
         ("--effort", "low"), ("--output-format", "stream-json"),
         ("--setting-sources", "project,local"),
         ("--permission-mode", "dontAsk"), ("--permission-prompts", "none"))
for chiave, (orr, _) in readme.items():
    ol, argv = live.get(chiave, ({}, []))
    for opzione, valore in list(orr.items()) + list(fisse):
        if ol.get(opzione) != valore:
            problemi.append("%s: %s" % (chiave, opzione))
    for opzione in ("-p", "--verbose", "--strict-mcp-config",
                    "--no-session-persistence"):
        if ol.get(opzione) is not True:
            problemi.append("%s: %s" % (chiave, opzione))
    if "--" not in argv:
        problemi.append("%s: il prompt non è dopo «--»" % (chiave,))
for base in (ws, ws2):
    for braccio, nomi in (("senza-worktree", ("checkout.txt",
                                               "urgenza.py")),
                          ("con-worktree", ("checkout.txt",
                                            "esempio.status",
                                            "rinomina.status",
                                            "esempio.py", "rinomina.py"))):
        for nome in nomi + ("esempio.jsonl", "rinomina.jsonl"):
            if not os.path.isfile(os.path.join(base, "esecuzioni", braccio,
                                               nome)):
                problemi.append("manca %s/%s" % (braccio, nome))
print("; ".join(sorted(set(problemi))) or "stesse chiamate")
PY
  expect "live e README: stessi testi, stesse opzioni, stesse fotografie" 0 \
    "stesse chiamate"
  run "${D07}/verifica.sh" "${w2}"
  expect "README: i comandi del README danno la stessa prova" 0 "${FINE}"
}

# Il claude finto: un worktree ignorato, una modifica fuori, un ramo con un
# altro nome, un tentativo rifiutato, un worktree non bloccato, la prima
# chiamata fallita, uno stream troncato, i controlli della libreria.
t_live_esiti() {
  local w r chiave
  ws_git w
  finto "${w}" FINTO_WT=ignora
  expect "live: un worktree ignorato, una segnalazione" 1 \
    "${S_WT} (esempio): ${NONCONF}"
  if [[ "$(residui "${w}")" == "0 0" ]]; then
    pass "live: la pulizia anche dopo una segnalazione"
  else
    fail "live: restano worktree o rami: $(residui "${w}")"
  fi
  ws_git w
  finto "${w}" FINTO_WT_FUORI=1
  expect "live: una modifica fuori dal worktree, una segnalazione" 1 \
    "del checkout principale"
  ws_git w
  finto "${w}" FINTO_WT_RAMO=altro-
  expect "live: un ramo con un altro nome, una segnalazione" 1 \
    "il worktree è sul ramo altro-esempio, non su worktree-esempio"
  if [[ "$(residui "${w}")" == "0 0" ]]; then
    pass "live: la pulizia toglie anche il ramo con l'altro nome"
  else
    fail "live: restano worktree o rami: $(residui "${w}")"
  fi
  ws_git w
  finto "${w}" FINTO_WT_BLOCCATO=1
  expect "live: due tentativi falliti fuori dall'elenco, non distinguibile" 0 \
    "${S_CO}: non distinguibile: 2 tentativi di modificare il checkout \
principale non riusciti, ma non nell'elenco permission_denials"
  ws_git w
  finto "${w}" FINTO_WT_BLOCCATO=negato
  expect "live: due tentativi negati, nell'elenco, il blocco confermato" 0 \
    "${S_CO}: confermata: 2 tentativi di modificare il checkout \
principale, negati (nell'elenco permission_denials)"
  ws_git w
  finto "${w}" FINTO_WT_LOCK=0
  r="$(residui "${w}")"
  if (( RC == 0 )) && [[ "${r}" == "0 0" ]]; then
    pass "live: worktree non bloccati, la stessa pulizia"
  else
    fail "live: worktree non bloccati, rc=${RC}, residui «${r}»"
  fi
  ws_git w
  finto "${w}" FINTO_ESITO=ko
  r="$(chiamate "${TMP}/finto.log")"
  if (( RC == 1 )) && [[ "${r}" == "2 0" ]] \
      && grep -qF 'VERIFICA KO' <<< "${OUT}"; then
    pass "live: si ferma dopo il primo braccio fallito"
  else
    fail "live: rc=${RC} dopo le chiamate «${r}»: ${OUT:0:300}"
  fi
  ws_git w
  finto "${w}" FINTO_TRONCO=1
  expect "live: uno stream troncato, uscita 1" 1 \
    "lo stream non finisce con il risultato"
  ws_git w
  finto "${w}" HANDSON_PERMISSION_MODE=bypassPermissions
  r="$(chiamate "${TMP}/finto.log")"
  if (( RC == 2 )) && [[ "${r}" == "0 0" ]] \
      && grep -qF 'modalità di permesso non ammessa' <<< "${OUT}"; then
    pass "live: bypassPermissions rifiutata prima di chiamare il modello"
  else
    fail "live: bypassPermissions, rc=${RC}, chiamate «${r}»"
  fi
  ws_git w
  chiave="sk-ant""-finta"
  printf 'Aggiungi un esempio. %s\n' "${chiave}" > "${w}/prompt-esempio.txt"
  git -C "${w}" -c user.name=Prova -c user.email=prova@example.org \
    commit -q -am "prompt con una chiave finta"
  finto "${w}"
  r="$(chiamate "${TMP}/finto.log")"
  if (( RC == 2 )) && [[ "${r}" == "0 0" ]] \
      && grep -qF 'sembra una chiave API' <<< "${OUT}"; then
    pass "live: una chiave API nel prompt rifiutata prima di chiamare"
  else
    fail "live: chiave nel prompt, rc=${RC}, chiamate «${r}»"
  fi
  expect_absent "live: la chiave non si stampa" "${chiave}"
}

# Un TERM a live.sh mentre girano le due sessioni del primo braccio (il
# finto aspetta 30 secondi prima di rispondere): live.sh le ferma prima di
# uscire, con 143, e nessuna resta a lavorare. Le sessioni rimaste, se ce
# ne sono, le toglie la prova stessa.
t_live_interrotto() {
  local w pid rc=0
  ws_git w
  : > "${TMP}/pid_finti"
  env PATH="${TMP}/finto:${PATH}" HANDSON_NO_PAUSE=1 FINTO_DORMI=30 \
    FINTO_PID="${TMP}/pid_finti" "${D07}/_docente/live.sh" "${w}" \
    > "${TMP}/interrotto.out" 2>&1 &
  pid=$!
  run python3 -B -I - "${TMP}/pid_finti" "${pid}" <<'PY'
import os, signal, sys, time
file_pid, live = sys.argv[1], int(sys.argv[2])
pids, fine = [], time.time() + 20
while time.time() < fine and len(pids) < 2:
    time.sleep(0.1)
    with open(file_pid, encoding="utf-8") as fh:
        pids = [int(r) for r in fh.read().split()]
if len(pids) < 2:
    print("le due sessioni non sono partite (%d)" % len(pids))
os.kill(live, signal.SIGTERM)
print("TERM mandato a live.sh, con %d sessioni in corso" % len(pids))
PY
  expect "live: le due sessioni partono, poi un TERM a live.sh" 0 \
    "TERM mandato a live.sh, con 2 sessioni in corso"
  wait "${pid}" || rc=$?
  run python3 -B -I - "${TMP}/pid_finti" <<'PY'
import os, signal, sys, time
pids = [int(r) for r in open(sys.argv[1], encoding="utf-8").read().split()]
vivi, fine = [], time.time() + 5
for p in pids:
    while True:
        try:
            os.kill(p, 0)
        except (ProcessLookupError, PermissionError):
            break
        if time.time() > fine:
            vivi.append(p)
            break
        time.sleep(0.1)
for p in vivi:
    os.kill(p, signal.SIGKILL)
print("sessioni ancora vive: %d" % len(vivi))
PY
  expect "live: il TERM ferma anche le due sessioni" 0 \
    "sessioni ancora vive: 0"
  if (( rc == 143 )) \
      && grep -qF "interrotto: fermo le sessioni" "${TMP}/interrotto.out"
  then
    pass "live: interrotto, live.sh lo dice ed esce con 143"
  else
    fail "live: interrotto, rc=${rc}: $(tail -n 3 "${TMP}/interrotto.out")"
  fi
}

# --- Il README ----------------------------------------------------------

t_readme() {
  run python3 -B -I - "${D07}/README.md" <<'PY'
import sys
readme = open(sys.argv[1], encoding="utf-8").read()
piatto = " ".join(readme.split())

def sezione(titolo):
    return readme.split("## " + titolo, 1)[-1].split("\n## ", 1)[0]

passi = sezione("Passi in Claude Code")
storto = " ".join(sezione("Se qualcosa va storto").split())
problemi = []
# La garanzia nell'ambito della frase della pagina sui worktree.
if "un Edit, un Write o un NotebookEdit diretto a un percorso del " \
        "checkout principale" not in piatto:
    problemi.append("la garanzia senza Edit, Write e NotebookEdit")
if "blocca le modifiche ai file del checkout principale" in piatto:
    problemi.append("la garanzia oltre la frase della pagina")
# Il percorso dei worktree: come l'ha trovato la registrazione, non come
# una promessa della pagina; «locked» soltanto come caso di git.
if "è partita in `.claude/worktrees/<nome>` del checkout" in piatto:
    problemi.append("il percorso dato come garanzia")
if "dove l'ha trovato la registrazione del corso" not in piatto:
    problemi.append("il percorso senza la registrazione")
if "rifiuta un worktree bloccato" in piatto:
    problemi.append("«locked» dato per i worktree di claude -p")
if "permission_denials" not in piatto:
    problemi.append("il blocco senza l'elenco permission_denials")
# I comandi nell'ordine giusto: cd - prima della verifica, cd nello
# spazio di lavoro prima della pulizia.
dopo = passi.split("<!-- /comandi -->", 1)[-1]
verifica = dopo.find("tools/verifica.sh M4-D07")
pulizia = dopo.find("git worktree remove")
if verifica == -1 or "cd -" not in dopo[:verifica]:
    problemi.append("cd - prima della verifica")
if pulizia == -1 or "cd ~/corso-claude-code/M4-D07" \
        not in dopo[verifica:pulizia]:
    problemi.append("cd nello spazio di lavoro prima della pulizia")
if "la pulizia qui sotto non tocca `esecuzioni/`" not in storto:
    problemi.append("il reset per le esecuzioni che ci sono già")
print("; ".join(problemi) or "README in ordine")
PY
  expect "README: la garanzia, il percorso, locked, cd, il reset" 0 \
    "README in ordine"
}

# Gli script di M4-D07, la sua libreria e questo file, con shellcheck -x;
# la libreria non è eseguibile (si carica con source).
t_shellcheck() {
  local f
  for f in "${D07}/verifica.sh" "${D07}/_docente/live.sh" \
      "${D07}/_docente/lib_worktree.sh" "${D07}/demo/fotografa.sh" \
      "${SELF}"; do
    if shellcheck -x "${f}" > /dev/null 2>&1; then
      pass "shellcheck ${f#"${RADICE}"/}"
    else
      fail "shellcheck ${f#"${RADICE}"/}"
    fi
  done
  if [[ -f "${D07}/_docente/lib_worktree.sh" \
      && ! -x "${D07}/_docente/lib_worktree.sh" \
      && -x "${D07}/_docente/live.sh" ]]; then
    pass "live.sh eseguibile, lib_worktree.sh no"
  else
    fail "lib_worktree.sh manca o è eseguibile, o live.sh non lo è"
  fi
}

main() {
  local t
  for t in python3 git shellcheck; do
    command -v "${t}" >/dev/null 2>&1 \
      || { echo "test_m4_d07: manca ${t}" >&2; exit 2; }
  done
  [[ -d "${D07}" && -f "${FINTO_PY}" && -d "${URG}" ]] \
    || { echo "test_m4_d07: manca ${D07}, ${FINTO_PY} o ${URG}" >&2; exit 2; }
  handson::init_temp_base
  TMP="$(mktemp -d "${HANDSON_TEMP_BASE}/test_m4_d07.XXXXXX")" || exit 2
  trap 'chmod -R u+rwX "${TMP}" 2>/dev/null; rm -rf "${TMP}"' EXIT
  prepara_claude
  t_file
  t_prepara
  t_fotografa
  t_buona
  t_garanzie
  t_dati_senza
  t_coppie
  t_rovinati
  t_precondizioni
  t_verifica
  t_live_precondizioni
  t_live_finto
  t_live_esiti
  t_live_interrotto
  t_readme
  t_shellcheck
  OUT="${TUTTO}"
  expect_absent "in nessuna uscita «smentita»" "smentita"
  echo "PASS=${PASS} FAIL=${FAIL} SKIP=${SKIP}"
  if (( PASS + FAIL + SKIP != CASES )); then
    echo "test_m4_d07: girati $((PASS + FAIL + SKIP)) casi, attesi" \
      "${CASES}" >&2
    exit 2
  fi
  (( FAIL == 0 )) || exit 1
}

main "$@"
