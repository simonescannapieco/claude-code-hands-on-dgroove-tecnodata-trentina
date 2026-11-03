# shellcheck shell=bash
# =====================================================================
# lib_lab_m5.sh -- la prova dal vivo del laboratorio del Modulo 5 (M5-E02,
# M5-E03, M5-E04): un partecipante emulato in claude -p, per il docente e per
# la registrazione del corso. Tredici chiamate: undici di prove, due di
# scrittura.
# ---------------------------------------------------------------------
# Libreria: si fa SOURCE dopo tools/lib_handson.sh, non si esegue (nessun bit
# di esecuzione). Si usa da un _docente/live.sh, con una riga sola:
#
#   lab::una_prova <ID> <spazio>
#
# Globals:   assegna HANDSON_* (tools/lib_handson.sh) e LAB_*; cambia cartella,
#            nello spazio di lavoro; HANDSON_NO_PAUSE e HANDSON_SHOW_CMD valgono
#            come negli altri live.sh
# Arguments: $1 l'identificativo dell'elemento, $2 lo spazio di lavoro, che
#            tools/prepara_esercizio.sh ha creato: una cartella che si chiama
#            come l'elemento (tools/prove_skill.sh la cerca così), al punto di
#            partenza
# Outputs:   ogni comando prima di eseguirlo, le tabelle di prove_skill.sh, per
#            ogni passo una riga con le chiamate, i turni del modello, i secondi
#            e i token di tutti i risultati dei suoi stream, e l'uscita di
#            verifica.sh
# Returns:   non torna, esce: 0 = verifica.sh passa · 1 = una chiamata o
#            un'esecuzione fallita, una garanzia che non regge, verifica.sh che
#            esce 1 · 2 = precondizione, prima della prima chiamata: argomenti,
#            uno strumento o un file che manca, uno spazio di lavoro con del
#            lavoro (dice tools/reset_esercizio.sh <ID>), gli stream di una
#            prova di prima, un README cambiato
#
# Che cosa chiede a un elemento:
#   - prove/config, con skill=<nome> (lo legge anche tools/prove_skill.sh);
#   - README.md, con il prompt per adattare la skill fra «<!-- prompt 1 -->» e
#     «<!-- /prompt 1 -->», e il seguito fra «<!-- prompt 2 -->» e
#     «<!-- /prompt 2 -->»: ognuno nomina .claude/skills/<nome>, e nessun altro
#     percorso sotto .claude/skills;
#   - nello spazio di lavoro controlla_skill.py, con lib_leggi_frontmatter.py;
#   - verifica.sh, che riceve lo spazio di lavoro e PN_HANDSON_ROOT.
#
# I passi:
#   1. tools/prove_skill.sh <ID> 1 without
#   2. tools/prove_skill.sh <ID> copia esempio
#   3. il prompt 1 in claude -p, Sonnet, effort medium, stream-json, con gli
#      strumenti nominati; lo stream fuori dallo spazio di lavoro, l'ID di
#      sessione tenuto
#   4. tools/prove_skill.sh <ID> 1 with
#   5. iteration-1/feedback.json: _docente/feedback_docente.py, o il file di
#      una persona con PN_FEEDBACK
#   6. il prompt 2 con --resume, gli stessi flag
#   7. tools/prove_skill.sh <ID> 2 with
#   8. verifica.sh dell'elemento
#
# La bozza: l'unica differenza dalla sessione di un partecipante. In claude -p
# Claude non può scrivere sotto .claude/, un percorso protetto: Write ed Edit
# finiscono in permission_denials anche se consentiti, perché
# «permissions.allow rules in settings files do not pre-approve protected-path
# writes» (https://code.claude.com/docs/en/permission-modes); un partecipante,
# nella sessione interattiva, approva la scrittura. Perciò ai passi 3 e 6 la
# skill si copia in bozza/<nome>/, fuori da .claude; il prompt del README cambia
# solo in quel percorso, e la libreria si ferma con 2 se il prompt non lo nomina
# più o ne nomina un altro; poi il risultato torna in .claude/skills/<nome>/,
# evals/ escluso, e la bozza sparisce: questo spostamento sta al posto
# dell'approvazione del partecipante. Le prove non vedono mai la bozza, perché
# nessun passo 1, 4 o 7 parte se c'è ancora.
#
# Variabili d'ambiente, tutte facoltative:
#   PN_FEEDBACK       un file da copiare come iteration-1/feedback.json, al
#                     posto di quello che scrive feedback_docente.py
#   PN_LIVE_JSON      la cartella degli stream dei passi (default: accanto allo
#                     spazio di lavoro, <spazio>.prova_dal_vivo); mai dentro, e
#                     senza gli stream di una prova di prima, che non si
#                     sovrascrivono
#   PN_LAB_STRUMENTI  gli strumenti consentiti dei passi 3 e 6 (default:
#                     Read,Edit,Write e il comando del controllo)
#   PN_HANDSON_ROOT   il repository, come negli strumenti
#
# La modalità di permesso è sempre dontAsk, qualunque sia quella dell'ambiente:
# ai passi 3 e 6 la fissa questa libreria, alle prove tools/prove_skill.sh.
#
# Compatibile con il bash 3.2, come tools/lib_handson.sh.
# =====================================================================

if [[ -n "${LAB_M5_LIB_LOADED:-}" ]]; then
  return 0
fi
readonly LAB_M5_LIB_LOADED=1

LAB_M5_LIB_FILE="$(readlink -f "${BASH_SOURCE[0]}")"
readonly LAB_M5_LIB_FILE
readonly LAB_M5_DOCENTE="${LAB_M5_LIB_FILE%/*}"
readonly LAB_MODELLO=sonnet
readonly LAB_EFFORT=medium
readonly LAB_BOZZA=bozza
LAB_STRUMENTI_DI_NORMA='Read,Edit,Write,'
LAB_STRUMENTI_DI_NORMA+='Bash(python3 -B -I controlla_skill.py *)'
readonly LAB_STRUMENTI_DI_NORMA

# Lo stato di una prova.
LAB_ID=''
LAB_WS=''
LAB_RADICE=''
LAB_SKILL=''
LAB_CARTELLA_SKILL=''
LAB_JSON=''
LAB_SESSIONE=''
LAB_PROMPT_1=''
LAB_PROMPT_2=''

# Il nome della skill, da prove/config. Globals: HANDSON_ITEM_DIR (letta);
# LAB_SKILL, LAB_CARTELLA_SKILL (assegnate). Esce 2 se non c'è.
lab::_leggi_skill() {
  local config="${HANDSON_ITEM_DIR}/prove/config" riga
  handson::need_file "${config}"
  while IFS= read -r riga || [[ -n "${riga}" ]]; do
    case "${riga}" in
      skill=?*) LAB_SKILL="${riga#skill=}" ;;
    esac
  done < "${config}"
  [[ "${LAB_SKILL}" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] \
    || handson::die "${config}: manca «skill=<nome>»"
  LAB_CARTELLA_SKILL=".claude/skills/${LAB_SKILL}"
}

# Il prompt N del README, fra i suoi marcatori, senza il rientro comune.
# Globals: HANDSON_ITEM_DIR. Arguments: $1 il numero.
# Outputs: il prompt su STDOUT. Returns: 2 se il README non lo ha.
lab::_prompt() {
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

# Il prompt N con il percorso della skill in bozza/, e controlla il risultato:
# se il README è cambiato, si ferma prima di ogni chiamata.
# Globals: LAB_CARTELLA_SKILL, LAB_SKILL. Arguments: $1 il numero.
# Outputs: il prompt riscritto su STDOUT. Esce 2.
lab::_prompt_per_la_bozza() {
  local testo
  testo="$(lab::_prompt "$1")" \
    || handson::die "il README non ha il prompt $1 fra le righe" \
      "«<!-- prompt $1 -->» e «<!-- /prompt $1 -->»"
  [[ "${testo}" == *"${LAB_CARTELLA_SKILL}"* ]] \
    || handson::die "il prompt $1 del README non nomina ${LAB_CARTELLA_SKILL}"
  testo="${testo//${LAB_CARTELLA_SKILL}/${LAB_BOZZA}/${LAB_SKILL}}"
  [[ "${testo}" != *.claude/skills* ]] \
    || handson::die "il prompt $1 del README nomina un altro percorso sotto" \
      ".claude/skills: lì in claude -p Claude non può scrivere"
  printf '%s\n' "${testo}"
}

# Lo spazio di lavoro al punto di partenza. Va chiamata nello spazio di lavoro.
# Globals: LAB_ID, LAB_SKILL. Esce 2 se ha già del lavoro.
lab::_al_punto_di_partenza() {
  local stato commit reset="tools/reset_esercizio.sh ${LAB_ID}"
  [[ -d .git ]] \
    || handson::die "$(pwd -P) non è uno spazio di lavoro preparato:" \
      "tools/prepara_esercizio.sh ${LAB_ID}"
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
  [[ ! -e "${LAB_SKILL}-workspace" && ! -e "${LAB_BOZZA}" ]] \
    || handson::die "lo spazio di lavoro non è al punto di partenza (ci sono" \
      "prove già fatte, o una bozza, che git non vede): ${reset}"
}

# La cartella degli stream, fuori dallo spazio di lavoro e senza stream di
# prima, che si sovrascriverebbero. Globals: LAB_ID, LAB_WS, PN_LIVE_JSON
# (lette), LAB_JSON (assegnata). Esce 2 se starebbe dentro, o se ne ha già.
lab::_cartella_json() {
  local reale f
  LAB_JSON="${PN_LIVE_JSON:-${LAB_WS}.prova_dal_vivo}"
  mkdir -p -- "${LAB_JSON}" || handson::die "non riesco a creare ${LAB_JSON}"
  reale="$(cd -- "${LAB_JSON}" && pwd -P)" \
    || handson::die "non riesco a leggere ${LAB_JSON}"
  if [[ "${reale}/" == "${LAB_WS}/"* ]]; then
    handson::die "gli stream dei passi non stanno nello spazio di lavoro:" \
      "${reale}"
  fi
  for f in "${reale}"/*.jsonl; do
    [[ ! -e "${f}" ]] \
      || handson::die "c'è già una prova in ${reale}: spostatela o" \
        "cancellatela, e ripartite da tools/reset_esercizio.sh ${LAB_ID}"
  done
  LAB_JSON="${reale}"
  handson::note "gli stream dei passi in ${LAB_JSON}"
}

# Tutto ciò che deve valere prima della prima chiamata; alla fine la cartella
# corrente è lo spazio di lavoro.
# Globals: LAB_*, HANDSON_ROOT, HANDSON_ITEM_DIR. Arguments: $1 l'id, $2 lo
# spazio di lavoro. Esce 2.
lab::_precondizioni() {
  LAB_ID="$1"
  handson::need_tools git python3
  handson::init_root || exit 2
  handson::find_item "${LAB_ID}" || exit 2
  [[ -d "$2" ]] || handson::die "spazio di lavoro assente: $2"
  LAB_WS="$(cd -- "$2" && pwd -P)" \
    || handson::die "lo spazio di lavoro $2 non si apre"
  LAB_RADICE="${LAB_WS%/*}"
  [[ "${LAB_WS##*/}" == "${LAB_ID}" ]] \
    || handson::die "lo spazio di lavoro deve chiamarsi ${LAB_ID}, come lo" \
      "crea tools/prepara_esercizio.sh: è ${LAB_WS##*/}"
  [[ -x "${HANDSON_ITEM_DIR}/verifica.sh" ]] \
    || handson::die "verifica.sh dell'elemento assente o non eseguibile"
  lab::_leggi_skill
  LAB_PROMPT_1="$(lab::_prompt_per_la_bozza 1)" || exit 2
  LAB_PROMPT_2="$(lab::_prompt_per_la_bozza 2)" || exit 2
  if [[ -n "${PN_FEEDBACK:-}" ]]; then
    handson::need_file "${PN_FEEDBACK}"
  fi
  cd -- "${LAB_WS}" || handson::die "lo spazio di lavoro non si apre"
  handson::need_file controlla_skill.py
  handson::need_file lib_leggi_frontmatter.py
  lab::_al_punto_di_partenza
  lab::_cartella_json
  handson::need_claude
}

# Una riga di riepilogo: le chiamate, i turni del modello, i secondi e i token
# di tutti i risultati degli stream, sommati come fa il controllo.
# Globals: HANDSON_TOOLS_DIR. Arguments: $1 l'etichetta, poi gli stream.
# Outputs: la riga su STDOUT. Esce 2 se uno stream non si legge.
lab::_riepilogo() {
  python3 -B -I - "${HANDSON_TOOLS_DIR}" "$@" <<'PY' \
    || handson::die "$1: gli stream non si leggono"
import sys

sys.path.insert(0, sys.argv[1])
import lib_controlla_prove as prove  # noqa: E402


def riepilogo(argv):
    lette = [prove.leggi_stream(s) for s in argv[1:]]
    segmenti = sum(e.segmenti for e in lette)
    pezzi = f" in {segmenti} segmenti" if segmenti > len(lette) else ""
    negati = sum(len(e.negati) for e in lette)
    secondi = f"{sum(e.secondi for e in lette):.1f}".replace(".", ",")
    quante = "1 chiamata" if len(lette) == 1 else f"{len(lette)} chiamate"
    turni = int(sum(e.turni for e in lette))
    quanti = "1 turno" if turni == 1 else f"{turni} turni"
    fermati = "1 negato" if negati == 1 else f"{negati} negati"
    print(f"  {argv[0]}: {quante}, {quanti} del modello{pezzi}, "
          f"{secondi} s, {int(sum(e.token_totali for e in lette))} token"
          + (f", {fermati} dal permesso" if negati else ""))
    return 0


sys.exit(prove.principale(riepilogo, sys.argv[2:]))
PY
}

# L'ID di sessione di uno stream: l'ultimo risultato che ne ha uno.
# Arguments: $1 lo stream. Outputs: l'ID, o niente.
lab::_sessione_di() {
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

# Un passo fallito: il verdetto KO e la fine.
# Arguments: il testo del verdetto. Non torna.
lab::_fallito() {
  handson::verdict ko "$*"
  handson::finish
}

# Un giro di tools/prove_skill.sh: la cartella della bozza non deve esserci.
# Un'uscita 1 chiude con 1, una di 2 o più esce uguale.
# Globals: LAB_ID, LAB_RADICE, HANDSON_TOOLS_DIR.
# Arguments: gli argomenti dello strumento dopo l'ID.
lab::_prove() {
  local rc=0
  [[ ! -e "${LAB_BOZZA}" ]] \
    || handson::die "${LAB_BOZZA}/ è ancora nello spazio di lavoro: le prove" \
      "la vedrebbero"
  handson::run "${HANDSON_TOOLS_DIR}/prove_skill.sh" "${LAB_ID}" "$@" \
    --radice "${LAB_RADICE}" < /dev/null || rc=$?
  case "${rc}" in
    0) ;;
    1) lab::_fallito "tools/prove_skill.sh ${LAB_ID} $*" ;;
    *) handson::err "tools/prove_skill.sh ${LAB_ID} $* è uscito con ${rc}"
       exit "${rc}" ;;
  esac
}

# Il riepilogo di un giro di prove: le esecuzioni fatte, non quelle riusate.
# Globals: LAB_SKILL. Arguments: $1 il numero del passo, $2 l'iterazione, $3 la
# configurazione.
lab::_riepilogo_prove() {
  local base="${LAB_SKILL}-workspace/iteration-$2" f
  local -a stream=()
  for f in "${base}"/eval-*/"$3"/outputs/stream.jsonl \
      "${base}"/near-miss-*/"$3"/outputs/stream.jsonl; do
    if [[ -f "${f}" ]]; then
      stream+=("${f}")
    fi
  done
  (( ${#stream[@]} > 0 )) \
    || handson::die "passo $1: nessuno stream in ${base}"
  lab::_riepilogo "passo $1" "${stream[@]}"
}

# La skill in bozza/, evals/ compreso, perché Claude possa leggerlo.
# Globals: LAB_CARTELLA_SKILL, LAB_SKILL.
lab::_bozza_prepara() {
  local bozza="${LAB_BOZZA}/${LAB_SKILL}"
  mkdir -p -- "${LAB_BOZZA}" || handson::die "non riesco a creare ${LAB_BOZZA}"
  handson::run cp -Rp -- "${LAB_CARTELLA_SKILL}" "${bozza}" \
    || handson::die "non riesco a copiare la skill in ${bozza}"
}

# Il risultato di bozza/ in .claude/skills/, evals/ escluso, poi via la bozza:
# è il posto dell'approvazione del partecipante, che in -p non c'è. Un file
# tolto dalla bozza esce anche dalla skill. Mai un percorso vuoto o un
# collegamento (RU-01.S5). Globals: LAB_CARTELLA_SKILL, LAB_SKILL.
lab::_bozza_riporta() {
  local bozza="${LAB_BOZZA}/${LAB_SKILL}"
  [[ -f "${bozza}/SKILL.md" ]] \
    || lab::_fallito "la scrittura non ha lasciato ${bozza}/SKILL.md"
  [[ ! -L "${LAB_BOZZA}" && ! -L "${bozza}" && ! -L "${LAB_CARTELLA_SKILL}" ]] \
    || handson::die "un collegamento simbolico fra bozza e skill: non lo seguo"
  (
    shopt -s dotglob nullglob
    for voce in "${LAB_CARTELLA_SKILL}"/*; do
      [[ "${voce##*/}" == evals ]] || rm -rf -- "${voce}" || exit 2
    done
    for voce in "${bozza}"/*; do
      [[ "${voce##*/}" == evals ]] \
        || cp -Rp -- "${voce}" "${LAB_CARTELLA_SKILL}/" || exit 2
    done
  ) || handson::die "non riesco a riportare ${bozza} in ${LAB_CARTELLA_SKILL}"
  rm -rf -- "${LAB_BOZZA}"
  handson::note "la bozza è tornata in ${LAB_CARTELLA_SKILL}: al posto" \
    "dell'approvazione del partecipante"
}

# Un passo di scrittura: la bozza, il prompt in claude -p, lo stream fuori dallo
# spazio di lavoro, il riepilogo, l'ID di sessione, il risultato riportato. Va
# chiamata nella shell dello script, non dentro $(…): una precondizione di
# handson::claude_p esce davvero con 2.
# Globals: LAB_*, HANDSON_TOOLS_DIR; HANDSON_OUTPUT_FORMAT e
# HANDSON_PERMISSION_MODE (locali).
# Arguments: $1 il numero del passo, $2 il prompt, poi le opzioni in più.
lab::_scrive() {
  local passo="$1" testo="$2" uscita="${LAB_JSON}/passo-$1.jsonl"
  local strumenti="${PN_LAB_STRUMENTI:-${LAB_STRUMENTI_DI_NORMA}}"
  shift 2
  # shellcheck disable=SC2034  # le legge handson::claude_p
  local HANDSON_OUTPUT_FORMAT=stream-json HANDSON_PERMISSION_MODE=dontAsk
  lab::_bozza_prepara
  handson::claude_p "${LAB_MODELLO}" "${strumenti}" "${testo}" \
    --effort "${LAB_EFFORT}" --strict-mcp-config "$@" < /dev/null \
    > "${uscita}" || lab::_fallito "passo ${passo}: claude -p è fallito"
  python3 -B -I "${HANDSON_TOOLS_DIR}/prove_skill_casi.py" esito "${uscita}" \
    || lab::_fallito "passo ${passo}: lo stream non ha un risultato riuscito"
  lab::_riepilogo "passo ${passo}" "${uscita}"
  LAB_SESSIONE="$(lab::_sessione_di "${uscita}")" \
    || lab::_fallito "passo ${passo}: lo stream non si legge"
  [[ -n "${LAB_SESSIONE}" ]] \
    || lab::_fallito "passo ${passo}: lo stream non ha un ID di sessione"
  lab::_bozza_riporta
}

# iteration-1/feedback.json: il file di una persona, o quello dello script, che
# lo dice nel suo testo. Globals: PN_FEEDBACK, LAB_SKILL, LAB_M5_DOCENTE.
# Esce 2.
lab::_feedback() {
  local iterazione="${LAB_SKILL}-workspace/iteration-1"
  if [[ -n "${PN_FEEDBACK:-}" ]]; then
    handson::run cp -- "${PN_FEEDBACK}" "${iterazione}/feedback.json" \
      || handson::die "non riesco a copiare ${PN_FEEDBACK}"
    return 0
  fi
  handson::run python3 -B -I "${LAB_M5_DOCENTE}/feedback_docente.py" \
    "${iterazione}" || handson::die "feedback_docente.py non riesce"
}

# La verifica dell'elemento: la sua uscita stampata, il verdetto e la fine.
# Globals: HANDSON_ITEM_DIR, HANDSON_ROOT, LAB_WS. Non torna.
lab::_verifica() {
  local out rc=0
  out="$(PN_HANDSON_ROOT="${HANDSON_ROOT}" \
    "${HANDSON_ITEM_DIR}/verifica.sh" "${LAB_WS}" 2>&1)" || rc=$?
  printf '%s\n' "${out}"
  handson::verdict_rc "${rc}" "verifica.sh dell'elemento"
  handson::finish
}

# La prova: vedi la testata del file.
lab::una_prova() {
  (( $# == 2 )) || handson::die "lab::una_prova: servono <ID> e <spazio>"
  lab::_precondizioni "$1" "$2"
  handson::step "Passo 1: la baseline, senza la skill"
  lab::_prove 1 without
  lab::_riepilogo_prove 1 1 without_skill
  handson::step "Passo 2: la skill di partenza, dall'esempio"
  lab::_prove copia esempio
  handson::step "Passo 3: il prompt per adattarla, sulla bozza"
  lab::_scrive 3 "${LAB_PROMPT_1}"
  handson::step "Passo 4: la prima versione"
  lab::_prove 1 with
  lab::_riepilogo_prove 4 1 with_skill
  handson::step "Passo 5: i commenti"
  lab::_feedback
  handson::step "Passo 6: il seguito, nella stessa sessione, sulla bozza"
  lab::_scrive 6 "${LAB_PROMPT_2}" --resume "${LAB_SESSIONE}"
  handson::step "Passo 7: la seconda versione"
  lab::_prove 2 with
  lab::_riepilogo_prove 7 2 with_skill
  handson::step "Passo 8: la verifica"
  lab::_verifica
}
