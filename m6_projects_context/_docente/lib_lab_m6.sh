# shellcheck shell=bash
# =====================================================================
# lib_lab_m6.sh -- la prova dal vivo del laboratorio del Modulo 6 (M6-E02,
# il gestionale; M6-E03, la rete): un partecipante emulato in claude -p, per
# il docente e per la registrazione del corso. Dodici chiamate: nove di
# prove, tre di scrittura.
# ---------------------------------------------------------------------
# Libreria: si fa SOURCE dopo tools/lib_handson.sh, non si esegue (nessun bit
# di esecuzione). Si usa da un _docente/live.sh, con una riga sola:
#
#   lab6::una_prova <ID> <spazio>
#
# Globals:   assegna HANDSON_* (tools/lib_handson.sh) e LAB6_*; esporta
#            CLAUDE_CODE_DISABLE_AUTO_MEMORY=1; cambia cartella, nello spazio
#            di lavoro; HANDSON_NO_PAUSE e HANDSON_SHOW_CMD valgono come negli
#            altri live.sh
# Arguments: $1 l'identificativo dell'elemento, $2 lo spazio di lavoro, che
#            tools/prepara_esercizio.sh ha creato: una cartella che si chiama
#            come l'elemento (tools/prova_contesto.sh la cerca così), al punto
#            di partenza
# Outputs:   ogni comando prima di eseguirlo, l'uscita di prova_contesto.sh,
#            per ogni passo una riga con le chiamate, i turni del modello, i
#            secondi e i token dei suoi stream, e l'uscita di verifica.sh
# Returns:   non torna, esce: 0 = verifica.sh passa · 1 = una chiamata o
#            un'esecuzione fallita, una garanzia che non regge, un passo di
#            scrittura che non lascia ciò che deve, verifica.sh che esce 1 ·
#            2 = precondizione, prima della prima chiamata: argomenti, uno
#            strumento o un file che manca, uno spazio di lavoro con del
#            lavoro (dice tools/reset_esercizio.sh <ID>), gli stream di una
#            prova di prima, un README cambiato; anche dopo, un giro di
#            tools/prova_contesto.sh che esce 2 (la v2 uguale alla v1, un
#            seguito che non ha cambiato niente)
#
# Che cosa chiede a un elemento:
#   - README.md, con il prompt che asciuga la bozza di /init fra
#     «<!-- prompt 1 -->» e «<!-- /prompt 1 -->», che non nomina .claude/, e
#     il seguito fra «<!-- prompt 2 -->» e «<!-- /prompt 2 -->», che nomina
#     .claude/rules/ e .claude/settings.json e ha, fra i tag
#     <verification_result>, una riga sola: la libreria la sostituisce con il
#     confronto che le prove della v1 hanno stampato;
#   - prove/config e prove/richieste.tsv, per tools/prova_contesto.sh;
#   - verifica.sh, che riceve lo spazio di lavoro e PN_HANDSON_ROOT.
#
# I passi, quelli del README:
#   1. tools/prova_contesto.sh <ID> base
#   2. /init in claude -p: Sonnet, effort medium, stream-json, gli strumenti
#      nominati; lo stream fuori dallo spazio di lavoro, l'ID di sessione
#      tenuto, la bozza di /init copiata accanto agli stream
#   3. il prompt 1 con --resume, gli stessi flag
#   4. tools/prova_contesto.sh <ID> v1, la sua uscita tenuta accanto agli
#      stream
#   5. il prompt 2 con --resume, con il confronto della v1 fra i tag
#      <verification_result>, sulla bozza
#   6. tools/prova_contesto.sh <ID> v2
#   7. verifica.sh dell'elemento
#
# La bozza: l'unica differenza dalla sessione di un partecipante. In claude -p
# Claude non può scrivere sotto .claude/, un percorso protetto: in dontAsk
# Write ed Edit sono negati anche se consentiti, perché «permissions.allow
# rules in settings files do not pre-approve protected-path writes»
# (https://code.claude.com/docs/en/permission-modes); un partecipante, nella
# sessione interattiva, approva la scrittura. Perciò al passo 5
# .claude/settings.json e .claude/rules/ si copiano in bozza/, e il prompt del
# README cambia soltanto in quei due percorsi: la libreria si ferma con 2 se
# il prompt non li nomina, o se ne nomina un altro sotto .claude/. Poi il
# risultato torna in .claude/ e la bozza sparisce: questo spostamento sta al
# posto dell'approvazione del partecipante. Il settings.json della bozza deve
# essere un oggetto JSON con l'hook InstructionsLoaded di prima, uguale; se
# no il passo è fallito (uscita 1), perché le prove della v2 non direbbero che
# cosa si è caricato. Nessuna prova parte se la bozza c'è ancora.
#
# La auto memory è spenta anche nelle chiamate di scrittura, come nelle prove:
# la sessione non lascia note che una prova potrebbe leggere.
#
# Variabili d'ambiente, tutte facoltative:
#   PN_LIVE_JSON      la cartella degli stream dei passi (default: accanto allo
#                     spazio di lavoro, <spazio>.prova_dal_vivo); mai dentro, e
#                     senza gli stream di una prova di prima, che non si
#                     sovrascrivono
#   PN_LAB_STRUMENTI  gli strumenti consentiti dei passi 2, 3 e 5 (default:
#                     Read,Glob,Grep,Write,Edit)
#   PN_HANDSON_ROOT   il repository, come negli strumenti
#
# La modalità di permesso è sempre dontAsk, qualunque sia quella
# dell'ambiente: ai passi 2, 3 e 5 la fissa questa libreria, alle prove
# tools/prova_contesto.sh.
#
# Compatibile con il bash 3.2, come tools/lib_handson.sh.
# =====================================================================

if [[ -n "${LAB6_LIB_LOADED:-}" ]]; then
  return 0
fi
readonly LAB6_LIB_LOADED=1

readonly LAB6_MODELLO=sonnet
readonly LAB6_EFFORT=medium
readonly LAB6_STRUMENTI_DI_NORMA='Read,Glob,Grep,Write,Edit'
readonly LAB6_BOZZA=bozza
readonly LAB6_REGOLE='.claude/rules/'
readonly LAB6_IMPOSTAZIONI='.claude/settings.json'

# Lo stato di una prova.
LAB6_ID=''
LAB6_WS=''
LAB6_RADICE=''
LAB6_JSON=''
LAB6_SESSIONE=''
LAB6_PRIMA=''
LAB6_PROMPT_1=''
LAB6_CONFRONTO=''

# Il prompt N del README, fra i suoi marcatori, senza il rientro comune.
# Globals: HANDSON_ITEM_DIR. Arguments: $1 il numero.
# Outputs: il prompt su STDOUT. Returns: 2 se il README non lo ha.
lab6::_prompt() {
  python3 -B -I - "${HANDSON_ITEM_DIR}/README.md" "$1" <<'PY'
import sys
import textwrap

righe = open(sys.argv[1], encoding="utf-8").read().split("\n")
n = sys.argv[2]
a = [i for i, r in enumerate(righe) if r.strip() == "<!-- prompt %s -->" % n]
b = [i for i, r in enumerate(righe) if r.strip() == "<!-- /prompt %s -->" % n]
if len(a) != 1 or len(b) != 1 or a[0] > b[0]:
    sys.exit(2)
testo = textwrap.dedent("\n".join(righe[a[0] + 1:b[0]])).strip("\n")
if not testo.strip():
    sys.exit(2)
print(testo)
PY
}

# Il seguito per la bozza: i due percorsi sotto .claude/ portati in bozza/ e
# la riga fra i tag <verification_result> sostituita dal confronto. Senza il
# confronto ($1 vuoto) controlla soltanto il prompt, prima delle chiamate.
# Globals: HANDSON_ITEM_DIR. Arguments: $1 il file del confronto, o "".
# Outputs: il prompt riscritto su STDOUT. Returns: 1 se il prompt non va, con
# il motivo su STDERR.
lab6::_seguito() {
  python3 -B -I - "${HANDSON_ITEM_DIR}/README.md" "$1" "${LAB6_REGOLE}" \
    "${LAB6_IMPOSTAZIONI}" "${LAB6_BOZZA}" <<'PY'
import sys
import textwrap

leggi, confronto, regole, impostazioni, bozza = sys.argv[1:6]
righe = open(leggi, encoding="utf-8").read().split("\n")
a = [i for i, r in enumerate(righe) if r.strip() == "<!-- prompt 2 -->"]
b = [i for i, r in enumerate(righe) if r.strip() == "<!-- /prompt 2 -->"]
if len(a) != 1 or len(b) != 1 or a[0] > b[0]:
    sys.exit("il README non ha il prompt 2 fra i suoi marcatori")
testo = textwrap.dedent("\n".join(righe[a[0] + 1:b[0]])).strip("\n")
for percorso in (regole, impostazioni):
    if percorso not in testo:
        sys.exit("il prompt 2 non nomina %s" % percorso)
testo = testo.replace(regole, bozza + "/rules/")
testo = testo.replace(impostazioni, bozza + "/settings.json")
if ".claude/" in testo:
    sys.exit("il prompt 2 nomina un altro percorso sotto .claude/: lì in "
             "claude -p Claude non può scrivere")
linee = testo.split("\n")
dentro = [i for i, r in enumerate(linee) if r == "<verification_result>"]
fuori = [i for i, r in enumerate(linee) if r == "</verification_result>"]
if len(dentro) != 1 or len(fuori) != 1 or fuori[0] != dentro[0] + 2:
    sys.exit("il prompt 2 non ha una riga sola fra i tag "
             "<verification_result>")
if confronto:
    blocco = open(confronto, encoding="utf-8").read().strip("\n")
    if not blocco.strip():
        sys.exit("il confronto della v1 è vuoto")
    linee[dentro[0] + 1] = blocco
print("\n".join(linee))
PY
}

# Lo spazio di lavoro al punto di partenza. Va chiamata nello spazio di lavoro.
# Globals: LAB6_ID. Esce 2 se ha già del lavoro.
lab6::_al_punto_di_partenza() {
  local stato commit reset="tools/reset_esercizio.sh ${LAB6_ID}"
  [[ -d .git ]] \
    || handson::die "$(pwd -P) non è uno spazio di lavoro preparato:" \
      "tools/prepara_esercizio.sh ${LAB6_ID}"
  stato="$(git status --porcelain)" || handson::die "git status non riesce"
  [[ -z "${stato}" ]] \
    || handson::die "lo spazio di lavoro non è al punto di partenza (git" \
      "status non è vuoto): ${reset}"
  commit="$(git rev-list --count HEAD)" \
    || handson::die "git rev-list non riesce"
  if [[ ! "${commit}" =~ ^[0-9]+$ ]] || (( commit != 1 )); then
    handson::die "lo spazio di lavoro non è al punto di partenza (ci sono" \
      "commit dopo il primo): ${reset}"
  fi
  if [[ -e prove-contesto || -e "${LAB6_BOZZA}" || -e CLAUDE.md \
      || -e CLAUDE.local.md || -e .claude/rules ]]; then
    handson::die "lo spazio di lavoro non è al punto di partenza (prove" \
      "già fatte, una bozza o file di istruzioni che git non vede):" \
      "${reset}"
  fi
}

# La cartella degli stream, fuori dallo spazio di lavoro e senza stream di
# prima. Globals: LAB6_ID, LAB6_WS, PN_LIVE_JSON (lette), LAB6_JSON
# (assegnata). Esce 2 se starebbe dentro, o se ne ha già.
lab6::_cartella_json() {
  local reale f
  LAB6_JSON="${PN_LIVE_JSON:-${LAB6_WS}.prova_dal_vivo}"
  mkdir -p -- "${LAB6_JSON}" \
    || handson::die "non riesco a creare ${LAB6_JSON}"
  reale="$(cd -- "${LAB6_JSON}" && pwd -P)" \
    || handson::die "non riesco a leggere ${LAB6_JSON}"
  if [[ "${reale}/" == "${LAB6_WS}/"* ]]; then
    handson::die "gli stream dei passi non stanno nello spazio di lavoro:" \
      "${reale}"
  fi
  for f in "${reale}"/*.jsonl; do
    [[ ! -e "${f}" ]] \
      || handson::die "c'è già una prova in ${reale}: spostatela o" \
        "cancellatela, e ripartite da tools/reset_esercizio.sh ${LAB6_ID}"
  done
  LAB6_JSON="${reale}"
  handson::note "gli stream dei passi in ${LAB6_JSON}"
}

# Tutto ciò che deve valere prima della prima chiamata; alla fine la cartella
# corrente è lo spazio di lavoro.
# Globals: LAB6_*, HANDSON_ROOT, HANDSON_ITEM_DIR. Arguments: $1 l'id, $2 lo
# spazio di lavoro. Esce 2.
lab6::_precondizioni() {
  LAB6_ID="$1"
  handson::need_tools git python3
  handson::init_root || exit 2
  handson::find_item "${LAB6_ID}" || exit 2
  [[ -d "$2" ]] || handson::die "spazio di lavoro assente: $2"
  LAB6_WS="$(cd -- "$2" && pwd -P)" \
    || handson::die "lo spazio di lavoro $2 non si apre"
  LAB6_RADICE="${LAB6_WS%/*}"
  [[ "${LAB6_WS##*/}" == "${LAB6_ID}" ]] \
    || handson::die "lo spazio di lavoro deve chiamarsi ${LAB6_ID}, come lo" \
      "crea tools/prepara_esercizio.sh: è ${LAB6_WS##*/}"
  [[ -x "${HANDSON_ITEM_DIR}/verifica.sh" ]] \
    || handson::die "verifica.sh dell'elemento assente o non eseguibile"
  LAB6_PROMPT_1="$(lab6::_prompt 1)" \
    || handson::die "il README non ha il prompt 1 fra le righe" \
      "«<!-- prompt 1 -->» e «<!-- /prompt 1 -->»"
  [[ "${LAB6_PROMPT_1}" != *.claude/* ]] \
    || handson::die "il prompt 1 del README nomina un percorso sotto" \
      ".claude/: lì in claude -p Claude non può scrivere"
  lab6::_seguito '' > /dev/null || handson::die "il prompt 2 del README non va"
  cd -- "${LAB6_WS}" || handson::die "lo spazio di lavoro non si apre"
  lab6::_al_punto_di_partenza
  lab6::_cartella_json
  handson::need_claude
}

# Una riga di riepilogo: le chiamate, i turni del modello, i secondi e i token
# di tutti i risultati degli stream, sommati come fa il controllo. Con
# --prima <stream>, una sessione ripresa: modelUsage conta anche i passi di
# prima, e i token del passo sono la differenza.
# Globals: HANDSON_TOOLS_DIR. Arguments: $1 l'etichetta, [--prima <stream>],
# poi gli stream. Outputs: la riga su STDOUT. Esce 2 se uno stream non si
# legge.
lab6::_riepilogo() {
  python3 -B -I - "${HANDSON_TOOLS_DIR}" "$@" <<'PY' \
    || handson::die "$1: gli stream non si leggono"
import sys

sys.path.insert(0, sys.argv[1])
from lib_leggi_stream import Problema, leggi_stream  # noqa: E402

etichetta, resto = sys.argv[2], sys.argv[3:]
prima = 0
try:
    if resto[:1] == ["--prima"]:
        prima = leggi_stream(resto[1]).token_totali
        resto = resto[2:]
    lette = [leggi_stream(s) for s in resto]
except (Problema, IndexError) as exc:
    print(exc, file=sys.stderr)
    sys.exit(2)
turni = int(sum(e.turni for e in lette))
secondi = f"{sum(e.secondi for e in lette):.1f}".replace(".", ",")
token = int(sum(e.token_totali for e in lette)) - int(prima)
negati = sum(len(e.negati) for e in lette)
quante = "1 chiamata" if len(lette) == 1 else f"{len(lette)} chiamate"
riga = (f"  {etichetta}: {quante}, {turni} turni del modello, {secondi} s, "
        f"{token} token")
if prima:
    riga += " (la sessione ripresa ne conta anche i passi di prima)"
if negati:
    riga += f", {negati} negati dal permesso"
print(riga)
PY
}

# L'ID di sessione di uno stream: l'ultimo risultato che ne ha uno.
# Arguments: $1 lo stream. Outputs: l'ID, o niente.
lab6::_sessione_di() {
  python3 -B -I - "$1" <<'PY'
import json
import sys

sessione = ""
with open(sys.argv[1], encoding="utf-8") as fh:
    for riga in fh:
        evento = json.loads(riga) if riga.strip() else {}
        if evento.get("type") == "result" and evento.get("session_id"):
            sessione = evento["session_id"]
print(sessione)
PY
}

# Vero se lo stream ha un risultato e nessun errore.
# Globals: HANDSON_TOOLS_DIR. Arguments: $1 lo stream.
lab6::_riuscito() {
  python3 -B -I - "${HANDSON_TOOLS_DIR}" "$1" <<'PY'
import sys

sys.path.insert(0, sys.argv[1])
from lib_leggi_stream import Problema, leggi_stream  # noqa: E402

try:
    esecuzione = leggi_stream(sys.argv[2])
except Problema:
    sys.exit(1)
sys.exit(0 if esecuzione.completa and not esecuzione.errore else 1)
PY
}

# Un passo fallito: il verdetto KO e la fine.
# Arguments: il testo del verdetto. Non torna.
lab6::_fallito() {
  handson::verdict ko "$*"
  handson::finish
}

# Un giro di tools/prova_contesto.sh, con la sua uscita tenuta accanto agli
# stream; la bozza non deve esserci. Un'uscita 1 chiude con 1, una di 2 o più
# esce uguale. Globals: LAB6_ID, LAB6_RADICE, LAB6_JSON, HANDSON_TOOLS_DIR.
# Arguments: $1 la versione.
lab6::_prove() {
  local rc=0
  [[ ! -e "${LAB6_BOZZA}" ]] \
    || handson::die "${LAB6_BOZZA}/ è ancora nello spazio di lavoro: le prove" \
      "la vedrebbero"
  handson::run "${HANDSON_TOOLS_DIR}/prova_contesto.sh" "${LAB6_ID}" "$1" \
    --radice "${LAB6_RADICE}" < /dev/null \
    | tee "${LAB6_JSON}/prove-$1.txt" || rc=$?
  case "${rc}" in
    0) ;;
    1) lab6::_fallito "tools/prova_contesto.sh ${LAB6_ID} $1" ;;
    *) handson::err "tools/prova_contesto.sh ${LAB6_ID} $1 è uscito con ${rc}"
       exit "${rc}" ;;
  esac
  lab6::_riepilogo "prove $1" prove-contesto/"$1"/*/stream.jsonl
}

# Il confronto che le prove di una versione hanno stampato, da «Il confronto
# delle versioni» in giù. Va chiamata nella shell dello script, non dentro
# $(…): il verdetto KO di lab6::_fallito va sullo schermo, non in una
# variabile. Globals: LAB6_JSON (letta), LAB6_CONFRONTO (assegnata: il file
# del confronto). Arguments: $1 la versione. Esce 1 se il confronto non c'è.
lab6::_confronto() {
  local da="${LAB6_JSON}/prove-$1.txt" a="${LAB6_JSON}/confronto-$1.txt"
  if ! awk 'index($0, "Il confronto delle versioni") == 1 { su = 1 } su' \
      "${da}" > "${a}" || [[ ! -s "${a}" ]]; then
    lab6::_fallito "le prove della $1 non hanno stampato il confronto"
  fi
  LAB6_CONFRONTO="${a}"
}

# Un passo di scrittura: il prompt in claude -p, lo stream fuori dallo spazio
# di lavoro, il riepilogo, l'ID di sessione. Va chiamata nella shell dello
# script, non dentro $(…): una precondizione di handson::claude_p esce davvero
# con 2. Globals: LAB6_*; HANDSON_OUTPUT_FORMAT e HANDSON_PERMISSION_MODE
# (locali). Arguments: $1 il numero del passo, $2 il prompt, poi le opzioni.
lab6::_scrive() {
  local passo="$1" testo="$2" uscita="${LAB6_JSON}/passo-$1.jsonl"
  local strumenti="${PN_LAB_STRUMENTI:-${LAB6_STRUMENTI_DI_NORMA}}"
  local -a prima=()
  shift 2
  # shellcheck disable=SC2034  # le legge handson::claude_p
  local HANDSON_OUTPUT_FORMAT=stream-json HANDSON_PERMISSION_MODE=dontAsk
  handson::claude_p "${LAB6_MODELLO}" "${strumenti}" "${testo}" \
    --effort "${LAB6_EFFORT}" --strict-mcp-config "$@" < /dev/null \
    > "${uscita}" || lab6::_fallito "passo ${passo}: claude -p è fallito"
  lab6::_riuscito "${uscita}" \
    || lab6::_fallito "passo ${passo}: lo stream non ha un risultato riuscito"
  if [[ -n "${LAB6_PRIMA}" ]]; then
    prima=(--prima "${LAB6_PRIMA}")
  fi
  lab6::_riepilogo "passo ${passo}" ${prima[@]+"${prima[@]}"} "${uscita}"
  LAB6_PRIMA="${uscita}"
  LAB6_SESSIONE="$(lab6::_sessione_di "${uscita}")" \
    || lab6::_fallito "passo ${passo}: lo stream non si legge"
  [[ -n "${LAB6_SESSIONE}" ]] \
    || lab6::_fallito "passo ${passo}: lo stream non ha un ID di sessione"
}

# .claude/settings.json e .claude/rules/ in bozza/, perché Claude li possa
# scrivere in claude -p.
lab6::_bozza_prepara() {
  mkdir -- "${LAB6_BOZZA}" \
    || handson::die "non riesco a creare ${LAB6_BOZZA}/"
  handson::run cp -p -- "${LAB6_IMPOSTAZIONI}" "${LAB6_BOZZA}/settings.json" \
    || handson::die "non riesco a copiare ${LAB6_IMPOSTAZIONI} nella bozza"
  if [[ -d "${LAB6_REGOLE}" ]]; then
    handson::run cp -Rp -- "${LAB6_REGOLE%/}" "${LAB6_BOZZA}/rules" \
      || handson::die "non riesco a copiare ${LAB6_REGOLE} nella bozza"
  else
    mkdir -- "${LAB6_BOZZA}/rules" \
      || handson::die "non riesco a creare ${LAB6_BOZZA}/rules/"
  fi
}

# Il settings.json della bozza: un oggetto JSON con l'hook di prima, uguale.
# Arguments: $1 il file. Outputs: il motivo, se no. Returns: 0 sì, 1 no.
lab6::_hook_intatto() {
  python3 -B -I - "$1" "${LAB6_IMPOSTAZIONI}" <<'PY'
import json
import sys

try:
    nuovo = json.load(open(sys.argv[1], encoding="utf-8"))
    vecchio = json.load(open(sys.argv[2], encoding="utf-8"))
except (OSError, ValueError) as exc:
    print("settings.json non si legge come JSON: %s" % exc)
    sys.exit(1)
if not isinstance(nuovo, dict):
    print("settings.json non è un oggetto JSON")
    sys.exit(1)
chiave = "InstructionsLoaded"
if (nuovo.get("hooks") or {}).get(chiave) != vecchio["hooks"][chiave]:
    print("l'hook InstructionsLoaded non è più quello di prima")
    sys.exit(1)
PY
}

# Il risultato della bozza in .claude/, poi via la bozza: è il posto
# dell'approvazione del partecipante, che in -p non c'è. Mai un percorso vuoto
# o un collegamento (RU-01.S5).
lab6::_bozza_riporta() {
  local perche regole="${LAB6_REGOLE%/}"
  [[ ! -L "${LAB6_BOZZA}" && ! -L "${LAB6_BOZZA}/rules" \
      && ! -L "${regole}" && ! -L "${LAB6_BOZZA}/settings.json" ]] \
    || handson::die "un collegamento simbolico nella bozza: non lo seguo"
  perche="$(lab6::_hook_intatto "${LAB6_BOZZA}/settings.json")" \
    || lab6::_fallito "passo 5: ${perche}"
  cp -p -- "${LAB6_BOZZA}/settings.json" "${LAB6_IMPOSTAZIONI}" \
    || handson::die "non riesco a riportare settings.json in .claude/"
  rm -rf -- "${regole}"
  if [[ -n "$(ls -A -- "${LAB6_BOZZA}/rules")" ]]; then
    cp -Rp -- "${LAB6_BOZZA}/rules" "${regole}" \
      || handson::die "non riesco a riportare le regole in .claude/"
  fi
  rm -rf -- "${LAB6_BOZZA}"
  handson::note "la bozza è tornata in .claude/: al posto dell'approvazione" \
    "del partecipante"
}

# La verifica dell'elemento: la sua uscita stampata, il verdetto e la fine.
# Globals: HANDSON_ITEM_DIR, HANDSON_ROOT, LAB6_WS. Non torna.
lab6::_verifica() {
  local out rc=0
  out="$(PN_HANDSON_ROOT="${HANDSON_ROOT}" \
    "${HANDSON_ITEM_DIR}/verifica.sh" "${LAB6_WS}" 2>&1)" || rc=$?
  printf '%s\n' "${out}"
  handson::verdict_rc "${rc}" "verifica.sh dell'elemento"
  handson::finish
}

# La prova: vedi la testata del file.
lab6::una_prova() {
  local seguito
  (( $# == 2 )) || handson::die "lab6::una_prova: servono <ID> e <spazio>"
  export CLAUDE_CODE_DISABLE_AUTO_MEMORY=1
  lab6::_precondizioni "$1" "$2"
  handson::step "Passo 1: le tre richieste senza CLAUDE.md (base)"
  lab6::_prove base
  handson::step "Passo 2: /init, la bozza del CLAUDE.md"
  lab6::_scrive 2 /init
  [[ -f CLAUDE.md ]] || lab6::_fallito "passo 2: /init non ha scritto CLAUDE.md"
  cp -p -- CLAUDE.md "${LAB6_JSON}/bozza-init.md" \
    || handson::die "non riesco a tenere la bozza di /init"
  handson::step "Passo 3: il prompt che asciuga la bozza, nella stessa sessione"
  lab6::_scrive 3 "${LAB6_PROMPT_1}" --resume "${LAB6_SESSIONE}"
  if [[ ! -f CLAUDE.md ]] || cmp -s CLAUDE.md "${LAB6_JSON}/bozza-init.md"; then
    lab6::_fallito "passo 3: il CLAUDE.md non è cambiato"
  fi
  handson::step "Passo 4: le stesse richieste con la prima versione (v1)"
  lab6::_prove v1
  lab6::_confronto v1
  handson::step "Passo 5: il seguito, con il confronto, sulla bozza"
  seguito="$(lab6::_seguito "${LAB6_CONFRONTO}")" \
    || handson::die "il seguito del README non si costruisce"
  lab6::_bozza_prepara
  lab6::_scrive 5 "${seguito}" --resume "${LAB6_SESSIONE}"
  lab6::_bozza_riporta
  handson::step "Passo 6: le stesse richieste con la seconda versione (v2)"
  lab6::_prove v2
  handson::step "Passo 7: la verifica"
  lab6::_verifica
}
