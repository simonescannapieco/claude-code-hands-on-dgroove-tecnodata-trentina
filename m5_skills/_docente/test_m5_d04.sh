#!/bin/bash
#
# test_m5_d04.sh -- le prove di M5-D04 «Prima e dopo, tre archetipi», per il
# docente (sta in _docente/, il materiale del docente):
#   - l'elemento: i file, le tre richieste, il pull request, la verità per
#     impronta, nessuna skill e nessuna verità in demo/; il README: le dieci
#     sezioni, le frasi di Anthropic con il loro indirizzo, nessun nome
#     interno, nessuna «smentita»;
#   - prepara_esercizio.sh e verifica.sh sul punto di partenza (1);
#   - controlla_archetipi.py su stream del claude finto: i criteri dei tre
#     archetipi, i tre esiti del confronto fra on e senza, che non decidono
#     l'uscita; le garanzie di senza e di off (1); un tentativo respinto e i
#     file letti sotto .claude/skills/, come dati (0); gli stream a metà (1);
#     gli stream illeggibili, la verità e le precondizioni (2), mai un
#     traceback; il set dei modelli, senza verdetti;
#   - verifica.sh: il controllo e la verità dell'elemento, non quelli dello
#     spazio di lavoro; le precondizioni (2);
#   - _docente/live.sh e in_classe.sh con il claude finto: le chiamate, ognuna
#     con le sue opzioni e dalla sua cartella, senza ANTHROPIC_API_KEY e senza
#     uno stream vicino; le due cartelle di un archetipo, uguali tranne la
#     skill; le precondizioni (2, nessuna chiamata); una chiamata fallita (1,
#     lo stream finito resta); la garanzia che non regge (1);
#   - shellcheck -x sugli script.
# Mai il claude vero: il finto e l'esca stanno davanti nel PATH, e la suite lo
# controlla prima di usarli. Gli stream del finto non sono risposte di Claude:
# provano il controllo, non il modello. Gli spazi di lavoro nascono in una
# cartella temporanea, nella base di handson::init_temp_base (mai dentro
# ~/.claude): l'albero del repository non cambia. CASES è il numero dei casi:
# se ne girano di più o di meno la suite esce 2.
#
# Uso:    m5_skills/_docente/test_m5_d04.sh
# Uscita: 0 = tutti i casi passano · 1 = almeno un caso fallito · 2 =
#         precondizione (manca python3, git o shellcheck; il finto non viene
#         prima nel PATH), o un numero di casi diverso da CASES
set -uo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly MOD="${SELF%/_docente/*}"
readonly RADICE="${MOD%/*}"
readonly ITEM="${MOD}/s4_skills/m5_7_tre_archetipi/M5-D04_prima_e_dopo"
readonly FINTO_PY="${MOD}/_docente/claude_finto_m5_d04.py"
readonly LAB="${MOD}/s4_skills/m5_e2_laboratorio"
# La libreria del repository, per la base dei file temporanei: mai dentro
# ~/.claude, dove prepara_esercizio.sh rifiuta gli spazi di lavoro.
# shellcheck source=../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"
readonly CASES=265
readonly P_REV='Rivedi il pull request di questo branch rispetto a main.'
P_RISP='Rispondi a questo cliente, nella chat del sito: «Sono il gestore del'
P_RISP+=' Rifugio Campione: da stamattina la connessione va e viene, il POS'
P_RISP+=' non riesce a collegarsi e le prenotazioni online si bloccano. Ho la'
P_RISP+=' sala piena.»'
readonly P_RISP
readonly P_AUD='Controlla la configurazione di core-trento-01: che problemi ha?'
readonly CONF='confermata'
readonly NONCONF='non confermata in questa esecuzione'
readonly NONDIST='non distinguibile'
TMP=''
PASS=0
FAIL=0
RC=0
OUT=''
TUTTO=''

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

# Esegue un comando; RC e OUT (STDOUT e STDERR insieme) per expect.
run() { OUT="$("$@" 2>&1)"; RC=$?; TUTTO+="${OUT}"$'\n'; }

# Uscita attesa E parola chiave attesa (RU-01.T3).
# Arguments: $1 il nome, $2 l'uscita attesa, $3 la parola (grep -F).
expect() {
  if (( RC == $2 )) && grep -qF -- "$3" <<< "${OUT}"; then
    pass "$1"
  else
    fail "$1 (rc=${RC}, attesa $2, parola «$3»): ${OUT:0:700}"
  fi
}

# La parola c'è, qualunque sia l'uscita. Arguments: $1 il nome, $2 la parola.
c_e() {
  if grep -qF -- "$2" <<< "${OUT}"; then
    pass "$1"
  else
    fail "$1: manca «$2»: ${OUT:0:700}"
  fi
}

# Nessun falso positivo: la parola NON c'è (RU-01.T5).
# Arguments: $1 il nome, $2 la parola.
assente() {
  if grep -qF -- "$2" <<< "${OUT}"; then
    fail "$1: «$2» c'è"
  else
    pass "$1"
  fi
}

# Un caso che passa se il comando riesce. Arguments: $1 il nome, poi il
# comando.
vero() {
  local nome="$1"
  shift
  if "$@"; then
    pass "${nome}"
  else
    fail "${nome}"
  fi
}

# Uno spazio di lavoro nuovo, con prepara_esercizio.sh in una radice nuova.
# Arguments: $1 la variabile da assegnare. Returns: 0; 1 se non riesce.
nuovo_ws() {
  local __r
  __r="$(mktemp -d "${TMP}/radice.XXXXXX")" || exit 2
  "${RADICE}/tools/prepara_esercizio.sh" M5-D04 --radice "${__r}" \
    > "${TMP}/prepara.log" 2>&1 || return 1
  printf -v "$1" '%s' "${__r}/M5-D04"
}

# L'esca (registra ogni invocazione ed esce 0) in ${TMP}/esca; il finto in
# ${TMP}/finto; ${TMP}/scatola, una cartella con le tre skill per scrivere gli
# stream a mano, e ${TMP}/scatola-senza, una senza; esce 2 se nel PATH di prova
# claude non è il finto.
prepara_claude() {
  local t s
  mkdir -p "${TMP}/esca" "${TMP}/finto" "${TMP}/senza_python" \
    "${TMP}/scatola-senza" || exit 2
  # shellcheck disable=SC2016  # il corpo è dell'esca
  printf '%s\n' '#!/bin/bash' \
    'printf "invocazione %s\n" "$*" >> "${ESCA_LOG}"' \
    > "${TMP}/esca/claude" || exit 2
  cp -- "${FINTO_PY}" "${TMP}/finto/claude" || exit 2
  chmod 755 "${TMP}/esca/claude" "${TMP}/finto/claude" || exit 2
  ln -s "$(command -v readlink)" "${TMP}/senza_python/readlink" || exit 2
  t="$(PATH="${TMP}/finto:${PATH}" command -v claude)"
  if [[ "${t}" != "${TMP}/finto/claude" ]]; then
    echo "test_m5_d04: nel PATH di prova claude è ${t}, non il finto" >&2
    exit 2
  fi
  for s in revisione-pr risposta-assistenza audit-configurazione; do
    mkdir -p "${TMP}/scatola/.claude/skills/${s}" || exit 2
    printf -- '---\nname: %s\ndescription: finta\n---\nCorpo finto.\n' "${s}" \
      > "${TMP}/scatola/.claude/skills/${s}/SKILL.md" || exit 2
  done
}

# Lo stream di una chiamata del finto dalla scatola, in un file.
# Arguments: $1 il file, $2 il modello, $3 l'archetipo, $4 on, senza o off, poi
# le variabili NOME=valore.
scrivi_stream() {
  local file="$1" modello="$2" arch="$3" braccio="$4" skill prompt
  local scatola="${TMP}/scatola"
  shift 4
  case "${arch}" in
    revisione) skill=revisione-pr prompt="${P_REV}" ;;
    risposta) skill=risposta-assistenza prompt="${P_RISP}" ;;
    audit) skill=audit-configurazione prompt="${P_AUD}" ;;
    *) echo "test_m5_d04: archetipo ${arch}" >&2; exit 2 ;;
  esac
  local -a extra=()
  if [[ "${braccio}" == off ]]; then
    extra=(--settings "{\"skillOverrides\":{\"${skill}\":\"off\"}}")
  elif [[ "${braccio}" == senza ]]; then
    scatola="${TMP}/scatola-senza"
  fi
  ( cd "${scatola}" && env "$@" "${TMP}/finto/claude" -p \
      --allowedTools "Read,Skill(${skill})" --model "${modello}" \
      --output-format stream-json --verbose ${extra[@]+"${extra[@]}"} \
      -- "${prompt}" ) > "${file}" \
    || { echo "test_m5_d04: il finto non scrive ${file}" >&2; exit 2; }
}

# Una cartella nuova per gli stream. Arguments: $1 la variabile da assegnare.
nuova_cartella() {
  local __c
  __c="$(mktemp -d "${TMP}/risposte.XXXXXX")" || exit 2
  printf -v "$1" '%s' "${__c}"
}

# La coppia n di un archetipo. Arguments: $1 la cartella, $2 l'archetipo, $3 n,
# poi le variabili NOME=valore, per tutti e due i bracci.
coppia() {
  local dir="$1" arch="$2" n="$3" braccio
  shift 3
  for braccio in on senza; do
    scrivi_stream "${dir}/${arch}-${braccio}-${n}.jsonl" sonnet "${arch}" \
      "${braccio}" "$@"
  done
}

# controlla_archetipi.py sulla cartella data; RC e OUT come run.
# Arguments: $1 la cartella, poi le opzioni.
controlla() {
  local dir="$1"
  shift
  run env PN_HANDSON_ROOT="${RADICE}" python3 -B -I \
    "${ITEM}/demo/controlla_archetipi.py" --verita "${ITEM}/verita.json" \
    "$@" "${dir}"
}

# Il controllo su una coppia, con il testo di on dato. RC e OUT come run.
# Arguments: $1 l'archetipo, $2 il testo.
coppia_con_testo() {
  local d
  nuova_cartella d
  scrivi_stream "${d}/$1-on-1.jsonl" sonnet "$1" on FINTO_TESTO_ON="$2"
  scrivi_stream "${d}/$1-senza-1.jsonl" sonnet "$1" senza
  controlla "${d}"
}

# Una risposta data, o un audit dato, nel braccio on. Arguments: $1 il testo.
risposta_on() { coppia_con_testo risposta "$1"; }
audit_on() { coppia_con_testo audit "$1"; }

# live.sh con il finto davanti e ANTHROPIC_API_KEY impostata (live.sh la deve
# togliere); il registro riparte vuoto.
# Arguments: $1 lo spazio di lavoro, $2 il set ("" = il principale), poi le
# variabili NOME=valore.
finto() {
  local w="$1" insieme="$2"
  shift 2
  : > "${TMP}/finto.log"
  run env PATH="${TMP}/finto:${PATH}" HANDSON_NO_PAUSE=1 \
    ANTHROPIC_API_KEY=valore-finto FINTO_LOG="${TMP}/finto.log" "$@" \
    "${ITEM}/_docente/live.sh" "${w}" ${insieme:+"${insieme}"}
}

# Una precondizione di live.sh con l'esca: uscita 2, la parola attesa, nessuna
# chiamata al modello. Arguments: $1 il nome, $2 la parola, poi il comando con
# le sue variabili (dopo env).
precondizione() {
  local nome="$1" parola="$2" n
  shift 2
  : > "${TMP}/esca.log"
  run env PATH="${TMP}/esca:${PATH}" HANDSON_NO_PAUSE=1 \
    ESCA_LOG="${TMP}/esca.log" "$@"
  expect "${nome}" 2 "${parola}"
  n="$(grep -vc -- '--version' "${TMP}/esca.log")"
  if (( n == 0 )); then
    pass "${nome}: nessuna chiamata al modello"
  else
    fail "${nome}: ${n} chiamate al modello"
  fi
}

# Le chiamate di un registro del finto, contro le attese. Arguments: $1 il
# registro, $2 lo spazio di lavoro, $3 il set (principale o modelli), $4 quante
# coppie per archetipo. Stampa «chiamate giuste», o che cosa non torna.
controlla_chiamate() {
  run python3 -B -I - "$1" "$2" "$3" "$4" "${P_REV}" "${P_RISP}" "${P_AUD}" \
    <<'PY'
import json, os, sys
log, ws, insieme, coppie, p_rev, p_risp, p_aud = sys.argv[1:8]
righe = [json.loads(r) for r in open(log, encoding="utf-8")]
chiamate = [r for r in righe if r["argv"][:1] != ["--version"]]
ATTESE = (("revisione", "revisione-pr", "gestionale-php", p_rev),
          ("risposta", "risposta-assistenza", "assistenza-clienti", p_risp),
          ("audit", "audit-configurazione", "rete", p_aud))
VALORE = {"--model", "--effort", "--allowedTools", "--output-format",
          "--setting-sources", "--permission-mode", "--permission-prompts",
          "--settings"}
problemi = []
def legge(argv):
    fine, opzioni, j = argv.index("--"), {}, 0
    while j < fine:
        if argv[j] in VALORE:
            opzioni[argv[j]] = argv[j + 1]
            j += 2
        else:
            opzioni[argv[j]] = True
            j += 1
    return opzioni, argv[fine + 1:]
modelli_visti = []
for arch, skill, progetto, prompt in ATTESE:
    cartella = os.path.realpath(os.path.join(ws, arch))
    senza = os.path.realpath(os.path.join(ws, arch + "-senza"))
    sue_on = [c for c in chiamate if os.path.realpath(c["cwd"]) == cartella]
    sue_senza = [c for c in chiamate if os.path.realpath(c["cwd"]) == senza]
    attese_on, attese_senza = int(coppie) + 1, int(coppie)
    if insieme == "modelli":
        attese_on, attese_senza = 2, 0
    if len(sue_on) != attese_on or len(sue_senza) != attese_senza:
        problemi.append("%s: %d chiamate on, %d senza" % (
            arch, len(sue_on), len(sue_senza)))
    if any(c["skill"] != [skill] for c in sue_on):
        problemi.append("%s: la cartella on senza la sua skill" % arch)
    if any(c["skill"] for c in sue_senza):
        problemi.append("%s: una skill nella cartella senza" % arch)
    for c in sue_on + sue_senza:
        opzioni, resto = legge(c["argv"])
        if resto != [prompt]:
            problemi.append("%s: il prompt" % arch)
        attese = {"--effort": "low", "--output-format": "stream-json",
                  "--allowedTools": "Read,Skill(%s)" % skill,
                  "--setting-sources": "project,local",
                  "--permission-mode": "dontAsk",
                  "--permission-prompts": "none"}
        for chiave, valore in attese.items():
            if opzioni.get(chiave) != valore:
                problemi.append("%s: %s=%r" % (arch, chiave,
                                               opzioni.get(chiave)))
        for chiave in ("-p", "--verbose", "--strict-mcp-config",
                       "--no-session-persistence"):
            if opzioni.get(chiave) is not True:
                problemi.append("%s: manca %s" % (arch, chiave))
        modelli_visti.append(opzioni.get("--model"))
        if c["chiave"]:
            problemi.append("%s: con ANTHROPIC_API_KEY" % arch)
        if c["risposte_vicine"]:
            problemi.append("%s: uno stream vicino alla sessione" % arch)
        if c["evals"]:
            problemi.append("%s: evals/ nella skill" % arch)
        if c["progetti"] != [progetto]:
            problemi.append("%s: i progetti %r" % (arch, c["progetti"]))
        if arch == "revisione" and (c["ramo"] != "pr-demo" or c["diff"] !=
                "progetti/gestionale-php/src/Report/ReportMorosita.php"):
            problemi.append("revisione: ramo %r, diff %r"
                            % (c["ramo"], c["diff"]))
    off = [c for c in sue_on if "--settings" in c["argv"]]
    atteso = '{"skillOverrides":{"%s":"off"}}' % skill
    if any(legge(c["argv"])[0]["--settings"] != atteso for c in off):
        problemi.append("%s: --settings" % arch)
    if any("--settings" in c["argv"] for c in sue_senza):
        problemi.append("%s: --settings nella cartella senza" % arch)
    if len(off) != (1 if insieme == "principale" else 0):
        problemi.append("%s: %d chiamate spente" % (arch, len(off)))
CARTELLE = ("revisione", "revisione-senza", "risposta", "risposta-senza",
            "audit", "audit-senza")
if any(c["cwd"].rsplit("/", 1)[1] not in CARTELLE for c in chiamate):
    problemi.append("una chiamata da un'altra cartella")
if insieme == "principale" and set(modelli_visti) != {"sonnet"}:
    problemi.append("i modelli %r" % sorted(set(modelli_visti)))
if insieme == "modelli" and sorted(modelli_visti) != sorted(
        ["haiku", "opus"] * 3):
    problemi.append("i modelli %r" % modelli_visti)
print("; ".join(problemi) or "chiamate giuste")
PY
}

# --- L'elemento -------------------------------------------------------------

t_elemento() {
  local f
  for f in README.md verita.json verifica.sh demo/richieste.tsv \
      demo/pr-demo.patch demo/controlla_archetipi.py demo/lib_archetipi.sh \
      demo/in_classe.sh _docente/live.sh _docente/verita.py \
      soluzione/LEGGIMI.md; do
    vero "elemento: ${f}" test -f "${ITEM}/${f}"
  done
  for f in verifica.sh demo/in_classe.sh _docente/live.sh; do
    vero "elemento: ${f} eseguibile" test -x "${ITEM}/${f}"
  done
  vero "elemento: lib_archetipi.sh senza il bit di esecuzione" \
    test ! -x "${ITEM}/demo/lib_archetipi.sh"
  run command find "${ITEM}/demo" -name 'SKILL.md'
  if [[ -z "${OUT}" ]]; then
    pass "elemento: nessuna skill in demo/"
  else
    fail "elemento: una skill in demo/: ${OUT}"
  fi
  run python3 -B -I - "${ITEM}/demo/richieste.tsv" "${P_REV}" "${P_RISP}" \
    "${P_AUD}" <<'PY'
import sys
righe = open(sys.argv[1], encoding="utf-8").read().splitlines()
atteso = ["archetipo\trichiesta", "revisione\t" + sys.argv[2],
          "risposta\t" + sys.argv[3], "audit\t" + sys.argv[4]]
print("richieste giuste" if righe == atteso else repr(righe))
PY
  expect "elemento: le tre richieste, nella forma di tutti" 0 \
    "richieste giuste"
  run command grep -c \
    '^+++ b/progetti/gestionale-php/src/Report/ReportMorosita\.php$' \
    "${ITEM}/demo/pr-demo.patch"
  expect "elemento: il pull request tocca la classe del gestionale" 0 "1"
  run command grep -E -n \
    '(2\.2|4\.1|4\.3|5\.1|6\.2|7\.1|7\.3|10\.2|AUD-0[123]|AUD-12)' \
    "${ITEM}/demo/controlla_archetipi.py" "${ITEM}/demo/lib_archetipi.sh" \
    "${ITEM}/demo/in_classe.sh" "${ITEM}/demo/richieste.tsv"
  if (( RC == 1 )); then
    pass "elemento: la verità non sta in demo/"
  else
    fail "elemento: la verità in demo/: ${OUT}"
  fi
}

t_verita() {
  local altro
  run env PN_HANDSON_ROOT="${RADICE}" python3 -B -I \
    "${ITEM}/_docente/verita.py" --check
  expect "verità: verita.json conferma i dati" 0 "conferma"
  run python3 -B -I - "${ITEM}/verita.json" <<'PY'
import json, re, sys
dati = json.load(open(sys.argv[1], encoding="utf-8"))
HASH = re.compile(r"^[0-9a-f]{64}$")
regole = dati["revisione"]["regole"]
categorie = dati["audit"]["categorie"]
buone = len(regole) == 8 and len(categorie) == 4 \
    and all(HASH.match(h) for h in regole + categorie)
print("impronte giuste" if buone else "impronte sbagliate")
PY
  expect "verità: otto regole e quattro categorie, come impronte" 0 \
    "impronte giuste"
  run command grep -n -E '"(2\.2|7\.1|AUD-0[123])"' "${ITEM}/verita.json"
  if (( RC == 1 )); then
    pass "verità: nessun valore in chiaro"
  else
    fail "verità: un valore in chiaro: ${OUT}"
  fi
  altro="${TMP}/verita-altra.json"
  python3 -B -I - "${ITEM}/verita.json" "${altro}" <<'PY' || exit 2
import json, sys
dati = json.load(open(sys.argv[1], encoding="utf-8"))
dati["revisione"]["regole"][0] = "0" * 64
json.dump(dati, open(sys.argv[2], "w", encoding="utf-8"))
PY
  run env PN_HANDSON_ROOT="${RADICE}" python3 -B -I \
    "${ITEM}/_docente/verita.py" --check --verita "${altro}"
  expect "verità: un file diverso dai dati (1)" 1 "diversa"
  run env PN_HANDSON_ROOT="${TMP}/non-c-e" python3 -B -I \
    "${ITEM}/_docente/verita.py"
  expect "verità: un repository senza la chiave (2)" 2 "verita:"
  assente "verità: niente traceback" "Traceback"
  run env PN_HANDSON_ROOT="${RADICE}" python3 -B -I \
    "${ITEM}/_docente/verita.py" --chek
  expect "verità: un'opzione sbagliata (2)" 2 "Uso:"
  assente "verità: e non stampa il JSON" '"elemento"'
  run env PN_HANDSON_ROOT="${RADICE}" python3 -B -I \
    "${ITEM}/_docente/verita.py" --check --verita
  expect "verità: --verita senza il file (2)" 2 "Uso:"
  assente "verità: e non conferma niente" "conferma"
}

t_readme() {
  run python3 -B -I - "${ITEM}/README.md" <<'PY'
import re, sys
testo = " ".join(open(sys.argv[1], encoding="utf-8").read().split())
SKILLS = "https://platform.claude.com/docs/en/agents-and-tools/agent-skills/"
FRASI = (
    "Skills are reusable, filesystem-based resources that give Claude "
    "domain-specific expertise: workflows, context, and best practices that "
    "turn a general-purpose agent into a specialist.",
    SKILLS + "overview",
    "Skills are the right fit when the agent needs to know how a team "
    "does work",
    "https://claude.com/resources/articles/"
    "building-agents-when-to-fold-subagents-into-your-main-agent-loop",
    "measure separately whether Claude invokes it on the prompts it should, "
    "and whether the output matches what you expect when it does.",
    "Collect a few realistic prompts, run each one in a fresh session with "
    "the skill available and again with it turned off",
    "https://code.claude.com/docs/en/skills",
    "run each test case twice: once with the skill and once without it (or "
    "with a previous version)",
    "https://agentskills.io/skill-creation/evaluating-skills",
    "Run Claude on representative tasks without a Skill.",
    "Invoking a hidden skill by its full name returns the skillOverrides "
    "error instead of running it.",
    "Skill audit-configurazione is disabled for model invocation in "
    "skillOverrides settings",
    "le parole della guida del tono e dello `SKILL.md`, con le forme della "
    "stessa parola",
    "--settings '{\"skillOverrides\":{\"revisione-pr\":\"off\"}}'",
    "> ../risposte/revisione-off-1.jsonl",
    "`progetti/gestionale-php`, sul ramo `pr-demo`",
    "«Rivedi il pull request di questo branch rispetto a main.»",
    "La differenza fra i due bracci è tutta nella forma del report",
    "una sessione così non le elencava",
    "3 turni, 82.290 token e 18,4 s nella revisione",
    "86.964, 65.542 e 163.693 token",
    "119.000, 91.508 e 162.704 token",
    "«VERIFICA OK M5-D04: fatto.»",
    "Categorie senza problemi",
    "Use modelUsage, or model_usage in Python, for whole-tree token "
    "accounting; the usage field undercounts as soon as nesting occurs.",
    "https://code.claude.com/docs/en/agent-sdk/cost-tracking",
    "A high score on its own doesn't tell you the plugin helped, because "
    "Claude might do as well without it.",
    "If a case scores 1.0 both with and without the plugin, the plugin isn't "
    "what made it pass.",
    "https://code.claude.com/docs/en/plugin-evals",
    "\"off\": Claude doesn't see the skill and /name is hidden from "
    "autocomplete",
    "https://code.claude.com/docs/en/settings-reference",
    "/code-review is a bundled skill: its instructions are built into Claude "
    "Code, so there is no SKILL.md file on disk to open or edit.",
    "Subjective skills (writing style, design quality) are better evaluated "
    "qualitatively — don't force assertions onto things that need human "
    "judgment.",
    "Tested with Haiku, Sonnet, and Opus",
    "Skills act as additions to models, so effectiveness depends on the "
    "underlying model.",
    SKILLS + "best-practices",
    "One run of a non-deterministic agent tells you little",
    "total_input_tokens = cache_read_input_tokens + "
    "cache_creation_input_tokens + input_tokens",
)
mancanti = [f for f in FRASI if f not in testo]
print("mancano: %r" % mancanti if mancanti else "frasi tutte presenti")
PY
  expect "README: le frasi di Anthropic, con l'indirizzo" 0 \
    "frasi tutte presenti"
  run cat -- "${ITEM}/README.md"
  assente "README: nessuna smentita" "smentita"
  assente "README: nessuna riga del registro" "FACT-"
  assente "README: nessuna decisione interna" "M5-X"
  assente "README: nessun percorso personale" "/home/"
  assente "README: «un'esecuzione», con l'elisione" "na esecuzione"
  assente "README: i token con il punto, fuori dalle righe citate" "82290"
  c_e "README: PN_HANDSON_ROOT nei passi" "PN_HANDSON_ROOT"
  c_e "README: il comando in classe" "./in_classe.sh"
  c_e "README: la skill spenta per un'esecuzione" "skillOverrides"
  c_e "README: le due cartelle di un archetipo" "revisione-senza/"
  run python3 -B -I - "${ITEM}/README.md" <<'PY'
import sys
testo = " ".join(open(sys.argv[1], encoding="utf-8").read().split())
frase = ("`off` toglie la skill da ciò che Claude vede come disponibile, e i "
         "suoi file restano sul disco, dove Claude li può trovare.")
print("detto chiaro" if frase in testo else "manca la frase su off")
PY
  expect "README: che cosa fa off, detto chiaro" 0 "detto chiaro"
  run "${RADICE}/tools/check_handson.sh"
  if grep -q 'M5-D04\|m5_7_tre_archetipi' <<< "${OUT}"; then
    fail "check_handson: una segnalazione su M5-D04: ${OUT:0:500}"
  else
    pass "check_handson: nessuna segnalazione su M5-D04"
  fi
}

t_prepara() {
  local w
  if ! nuovo_ws w; then
    fail "prepara: lo spazio di lavoro non si crea: $(cat "${TMP}/prepara.log")"
    return 0
  fi
  pass "prepara: lo spazio di lavoro nasce"
  vero "prepara: in_classe.sh eseguibile" test -x "${w}/in_classe.sh"
  vero "prepara: le richieste" test -f "${w}/richieste.tsv"
  vero "prepara: niente verità nello spazio di lavoro" \
    test ! -e "${w}/verita.json"
  vero "prepara: niente _docente" test ! -e "${w}/_docente"
  run command find "${w}" -name 'SKILL.md'
  if [[ -z "${OUT}" ]]; then
    pass "prepara: nessuna skill prima di in_classe.sh"
  else
    fail "prepara: una skill: ${OUT}"
  fi
  run env PN_HANDSON_ROOT="${RADICE}" "${ITEM}/verifica.sh" "${w}"
  expect "verifica: sul punto di partenza (1)" 1 "Manca"
}

# --- Il controllo -----------------------------------------------------------

t_completa() {
  local d
  nuova_cartella d
  coppia "${d}" revisione 1
  coppia "${d}" risposta 1
  coppia "${d}" audit 1
  controlla "${d}"
  expect "controllo: tre coppie (0)" 0 "coppia 1"
  c_e "controllo: la revisione on" "regole inserite citate: 8 su 8"
  c_e "controllo: la revisione senza" "regole inserite citate: 0 su 8"
  c_e "controllo: i numeri fuori chiave, come dati" "altre citate: 3.5"
  c_e "controllo: la Skill di on" "Skill revisione-pr: sì"
  c_e "controllo: la Skill di senza" "Skill revisione-pr: no"
  c_e "controllo: code-review, come dato" "altre skill: code-review"
  c_e "controllo: i turni, i token e i secondi di on" \
    "4 turni, 6210 token, 7,3 s"
  c_e "controllo: i turni, i token e i secondi di senza" \
    "3 turni, 5005 token, 35,5 s"
  c_e "controllo: il confronto della revisione" \
    "coppia 1: on 8, senza 0 su 8: ${CONF}"
  c_e "controllo: audit on" "categorie inserite trovate: 4 su 4"
  c_e "controllo: audit senza" "categorie inserite trovate: 0 su 4"
  c_e "controllo: le altre categorie, nelle parole di E04" \
    "altre categorie: AUD-16"
  assente "controllo: le parole di prima sulle categorie" "altre citate: AUD"
  c_e "controllo: le colonne on" "le sei colonne: sì"
  c_e "controllo: le colonne senza" "le sei colonne: no"
  c_e "controllo: il confronto dell'audit" \
    "coppia 1: on 5, senza 0 su 5: ${CONF}"
  c_e "controllo: la risposta on, nessuna parola da evitare" \
    "parole da evitare: nessuna"
  c_e "controllo: la risposta senza, le parole trovate" "a breve"
  c_e "controllo: le frasi" "frasi: 3, al massimo 3"
  c_e "controllo: la lunghezza in parole, come dato" "parole: "
  c_e "controllo: la forma on" "forma del canale: sì"
  c_e "controllo: la forma senza" "forma del canale: no"
  c_e "controllo: il testo per una persona" "| Mi dispiace: con la sala"
  c_e "controllo: la garanzia" "garanzia di senza: tiene 1 su 1"
  c_e "controllo: confermata per archetipo" "confermata 1 su 1"
  c_e "controllo: i file sotto .claude/skills/ in on, come dato" \
    "file sotto .claude/skills/: Read revisione-pr/references/guida.md"
  c_e "controllo: nessun file sotto .claude/skills/ in senza" \
    "file sotto .claude/skills/: nessuno"
  assente "controllo: nessun reperto su una buona coppia" "REPERTO"
  assente "controllo: niente off senza il suo set" "garanzia di off"
}

t_tre_coppie() {
  local d n
  nuova_cartella d
  for (( n = 1; n <= 3; n++ )); do
    coppia "${d}" revisione "${n}"
  done
  controlla "${d}"
  expect "tre coppie: confermata 3 su 3" 0 "${CONF} 3 su 3"
  c_e "tre coppie: la Skill n su N" "on 3 su 3, senza 0 su 3"
  c_e "tre coppie: la garanzia su tutte" "garanzia di senza: tiene 3 su 3"
  c_e "tre coppie: il totale dei criteri" "on 24, senza 0 su 24: ${CONF}"
}

t_verdetti() {
  local d testo
  nuova_cartella d
  testo="Numeri: 2.2 e 4.1."
  scrivi_stream "${d}/revisione-on-1.jsonl" sonnet revisione on \
    FINTO_TESTO_ON="${testo}"
  scrivi_stream "${d}/revisione-senza-1.jsonl" sonnet revisione senza \
    FINTO_TESTO_SENZA="${testo}"
  controlla "${d}"
  expect "confronto: uguali, non distinguibile, uscita 0" 0 "${NONDIST}"
  assente "confronto: uguali, nessuna conferma" "senza 2 su 8: ${CONF}"
  nuova_cartella d
  scrivi_stream "${d}/revisione-on-1.jsonl" sonnet revisione on \
    FINTO_TESTO_ON="Solo 2.2."
  scrivi_stream "${d}/revisione-senza-1.jsonl" sonnet revisione senza \
    FINTO_TESTO_SENZA="Numeri: 2.2, 4.1 e 7.3."
  controlla "${d}"
  expect "confronto: sotto, non confermata, uscita 0" 0 "${NONCONF}"
  nuova_cartella d
  scrivi_stream "${d}/revisione-on-1.jsonl" sonnet revisione on \
    FINTO_TESTO_ON="Non 17.1, 7.10, 10.2.0.1, v2.2, 4.1.3, 0.0."
  scrivi_stream "${d}/revisione-senza-1.jsonl" sonnet revisione senza \
    FINTO_TESTO_SENZA="La regola 7.1."
  controlla "${d}"
  c_e "confronto: il numero intero, on" "regole inserite citate: 0 su 8"
  c_e "confronto: il punto a fine frase non nasconde il numero" \
    "regole inserite citate: 1 su 8"
}

t_risposta() {
  local d testo
  nuova_cartella d
  testo="Ecco la risposta: ti scrivo a breve."
  scrivi_stream "${d}/risposta-on-1.jsonl" sonnet risposta on \
    FINTO_TESTO_ON="${testo}"
  scrivi_stream "${d}/risposta-senza-1.jsonl" sonnet risposta senza
  controlla "${d}"
  c_e "risposta: una premessa si conta" "senza premessa: no"
  c_e "risposta: la parola da evitare si nomina" "parole da evitare: a breve"
  c_e "risposta: i criteri sono quattro" "criteri: 2 su 4"
  c_e "risposta: i grassetti e gli elenchi si nominano" "grassetto"
  risposta_on 'Ci sono disservizi.'
  c_e "parole: il plurale della stessa parola" "parole da evitare: disservizi"
  risposta_on 'GENTILE CLIENTE, buongiorno.'
  c_e "parole: maiuscole o minuscole" "parole da evitare: GENTILE CLIENTE"
  risposta_on 'Ti faremo sapere.'
  c_e "parole: nel registro del tu" "parole da evitare: Ti faremo sapere"
  risposta_on $'La presa\nin carico è fatta.'
  c_e "parole: su due righe" "parole da evitare: presa in carico"
  risposta_on 'La OLT è ferma.'
  c_e "parole: una sigla della guida" "parole da evitare: OLT"
  risposta_on 'olt-pergine-01 è fermo.'
  c_e "parole: il nome di un apparato" "parole da evitare: olt-pergine-01"
  risposta_on 'Il ticketing.'
  c_e "parole: a parola intera, «ticketing» non vale" \
    "parole da evitare: nessuna"
}

# Le parole del controllo contro la guida e la tabella dello SKILL.md, nei due
# sensi, come fa la suite di M5-E03; e, contro E03 e E04, le costanti e il
# giudizio sulle categorie, perché il controllo di questa demo e quelli del
# laboratorio dicano la stessa cosa dello stesso testo.
t_parole_e_lab() {
  run env PN_HANDSON_ROOT="${RADICE}" python3 -B -I - \
    "${ITEM}/demo/controlla_archetipi.py" \
    "${RADICE}/progetti/assistenza-clienti/tono-di-voce.md" \
    "${RADICE}/riferimenti/skill-di-esempio/risposta-assistenza/SKILL.md" \
    "${LAB}/M5-E03_risposta_assistenza/verifica.py" \
    "${LAB}/M5-E04_audit_configurazione/verifica.py" <<'PY'
import importlib.util
import re
import sys
import types

def carica(nome, percorso):
    spec = importlib.util.spec_from_file_location(nome, percorso)
    modulo = importlib.util.module_from_spec(spec)
    sys.modules[nome] = modulo
    spec.loader.exec_module(modulo)
    return modulo

d04 = carica("d04", sys.argv[1])
guida = open(sys.argv[2], encoding="utf-8").read()
skill = open(sys.argv[3], encoding="utf-8").read()
e03 = carica("e03", sys.argv[4])
e04 = carica("e04", sys.argv[5])
parole = d04.PAROLE_DA_EVITARE
def sezione(testo, titolo):
    return testo.split(titolo, 1)[1].split("\n## ", 1)[0]
def colonna(testo):
    celle = [r.split("|")[1] for r in testo.splitlines()
             if r.startswith("|") and not r.startswith("|---")][1:]
    return celle, [p for c in celle for p in re.findall(r"«([^»]+)»", c)]
celle_g, voci_g = colonna(
    sezione(guida, "## Parole da usare e parole da evitare"))
celle_s, voci_s = colonna(sezione(skill, "## Parole da evitare"))
tutte = " ".join(celle_g + celle_s).lower()
for parola in parole:
    if parola.lower() not in tutte:
        sys.exit("«%s» non è nella guida" % parola)
for voce in voci_g + voci_s:
    if not any(p.lower() in voce.lower() for p in parole):
        sys.exit("la voce «%s» non è fra le parole" % voce)
if parole != e03.PAROLE_DA_EVITARE \
        or d04.RE_PAROLE.pattern != e03.RE_PAROLE.pattern:
    sys.exit("le parole non sono quelle di E03")
for nome in ("RE_CODICE", "RE_A_POSTO", "RE_ETICHETTA", "RE_SEPARATORE"):
    if getattr(d04, nome).pattern != getattr(e04, nome).pattern:
        sys.exit("%s non è quello di E04" % nome)
TESTA = ("| apparato | file | riga | categoria | gravità | descrizione |\n"
         "|---|---|---|---|---|---|\n")
TESTI = (
    "AUD-11: duplicato.\n\n**Categorie senza problemi:**\n- **AUD-05:** ok",
    "AUD-11: no.\n\n## Controlli senza problemi\n\nAUD-01: ok.\n\nAUD-05: ok.",
    "## Controlli senza problemi\n\nAUD-01: ok.\n\n## Problemi\n\nAUD-05: no.",
    "AUD-11: no.\n\n**Controlli che non hanno dato problemi**\n- AUD-05: su x.",
    "AUD-11: no.\n\n- **Altre categorie senza problemi:**\n  - AUD-05: su x.",
    "**Conformi:**\n- **Syslog:**\n  - AUD-05: su x.\n\nAUD-11: duplicato.",
    "**Conformi:**\n- AUD-01\n\nAUD-05: il collettore è dismesso.\nAUD-11: no.",
    "AUD-05: conforme.\nAUD-11: no.",
    "AUD-05: non conforme allo standard.\nAUD-11: non è conforme.",
    "AUD-05: non si applica.\nAUD-11 non verificata.",
    "AUD-05: non risulta conforme.\nAUD-11: non lo rende conforme.",
    "| categoria | voce | esito |\n|---|---|---|\n| AUD-05 | Conformità | KO |",
    TESTA + "| a | b | 1 | AUD-05 | alta | conforme a prima, duplicato |",
    "| categoria | esito |\n|---|---|\n| AUD-05 | conforme |\n| AUD-11 | no |",
    "AUD-111 e XAUD-05 e AUD-115",
    "Nessun problema trovato.",
    TESTA,
    " ",
)
for testo in TESTI:
    if d04.categorie_nel_testo(testo) != e04.categorie_nel_testo(testo):
        sys.exit("le categorie diverse da E04 su: %r" % testo)
    if d04.sei_colonne(testo) != e04.giudica_tabella(
            types.SimpleNamespace(testo=testo), None)[0]:
        sys.exit("la tabella diversa da E04 su: %r" % testo)
print(len(voci_g), "voci della guida e", len(voci_s), "dello SKILL.md;",
      len(TESTI), "testi uguali a E04")
PY
  expect "parole: ogni voce della guida e dello SKILL.md, e viceversa" 0 \
    "voci della guida"
  c_e "lab: le parole di E03 e il giudizio di E04, gli stessi" \
    "testi uguali a E04"
}

t_audit_criteri() {
  local testa t
  testa='| apparato | file | riga | categoria | gravità | descrizione |'
  testa+=$'\n|---|---|---|---|---|---|'
  t="${testa}"$'\n| c | f | 1 | AUD-01 | alta | x |\n\n'
  t+=$'**Categorie senza problemi:**\n- **AUD-02:** ok'
  audit_on "${t}"
  expect "audit: sotto «Categorie senza problemi» non vale (0)" 0 \
    "categorie inserite trovate: 1 su 4"
  c_e "audit: si dice, nelle parole di E04" "senza un rilievo: AUD-02"
  t=$'AUD-01: no.\n\n## Controlli senza problemi\n\n'
  t+=$'AUD-02: ok.\n\nAUD-03: ok.'
  audit_on "${t}"
  c_e "audit: sotto un titolo così non vale" \
    "categorie inserite trovate: 1 su 4"
  t=$'## Controlli senza problemi\n\nAUD-02: ok.\n\n'
  t+=$'## Problemi\n\nAUD-01: no.\nAUD-03: no.'
  audit_on "${t}"
  c_e "audit: dopo quel titolo, un altro titolo riapre" \
    "categorie inserite trovate: 2 su 4"
  audit_on $'AUD-01: conforme.\nAUD-02: no.'
  c_e "audit: una riga che dice «conforme» non vale" \
    "categorie inserite trovate: 1 su 4"
  audit_on $'AUD-01: non conforme allo standard.\nAUD-02: non è conforme.'
  c_e "audit: «non conforme» vale" "categorie inserite trovate: 2 su 4"
  audit_on $'AUD-01: non risulta conforme.\nAUD-02: non lo rende conforme.'
  c_e "audit: «non risulta conforme» e «non lo rende conforme» valgono" \
    "categorie inserite trovate: 2 su 4"
  assente "audit: e non sono «senza un rilievo»" "senza un rilievo"
  t=$'| categoria | voce | esito |\n|---|---|---|\n'
  t+=$'| AUD-01 | Conformità NTP | KO |'
  audit_on "${t}"
  c_e "audit: «Conformità», il nome di una voce, non è «a posto»" \
    "categorie inserite trovate: 1 su 4"
  assente "audit: quella voce non è «senza un rilievo»" "senza un rilievo"
  audit_on $'AUD-01: risulta conforme.\nAUD-02: no.'
  c_e "audit: «risulta conforme» resta «a posto»" "senza un rilievo: AUD-01"
  audit_on $'AUD-01: non si applica.\nAUD-02 non verificata.'
  c_e "audit: «non si applica» e «non verificata» non valgono" \
    "senza un rilievo: AUD-01, AUD-02"
  audit_on "${testa}"$'\n| c | f | 1 | AUD-01 | alta | conforme a prima |'
  c_e "audit: una riga del report vale sempre" \
    "categorie inserite trovate: 1 su 4"
  assente "audit: e non è «senza un rilievo»" "senza un rilievo"
  t=$'| categoria | esito |\n|---|---|\n'
  t+=$'| AUD-01 | conforme |\n| AUD-02 | no |'
  audit_on "${t}"
  c_e "audit: una tabella di esiti con «conforme» non vale" \
    "categorie inserite trovate: 1 su 4"
  assente "audit: e non ha le sei colonne" "le sei colonne: sì"
  audit_on 'AUD-011 e XAUD-01 e AUD-012'
  c_e "audit: a codice intero" "categorie inserite trovate: 0 su 4"
  assente "audit: nessun codice letto da quelle parole" "altre categorie"
  audit_on "${testa}"$'\n| c | f | 1 | AUD-16 | alta | x |'
  c_e "audit: le altre, nelle parole di E04" "altre categorie: AUD-16"
  audit_on "${testa}"
  assente "audit: le sei colonne senza una riga non bastano" \
    "le sei colonne: sì"
  t=$'**Categorie senza problemi:**\n'
  t+=$'- AUD-01\n- AUD-02\n- AUD-03\n- AUD-12'
  audit_on "${t}"
  expect "audit: le inserite elencate come a posto non danno un punto (0)" 0 \
    "coppia 1: on 0, senza 0 su 5: ${NONDIST}"
}

t_garanzia() {
  local d
  nuova_cartella d
  scrivi_stream "${d}/revisione-on-1.jsonl" sonnet revisione on
  scrivi_stream "${d}/revisione-senza-1.jsonl" sonnet revisione senza \
    FINTO_SENZA_CHIAMA=1
  controlla "${d}"
  expect "garanzia: senza, una chiamata che riesce (1)" 1 "REPERTO"
  nuova_cartella d
  scrivi_stream "${d}/revisione-on-1.jsonl" sonnet revisione on
  scrivi_stream "${d}/revisione-senza-1.jsonl" sonnet revisione senza \
    FINTO_SENZA_ELENCA=1
  controlla "${d}"
  expect "garanzia: senza, la skill nell'elenco (1)" 1 "fra le skill"
  nuova_cartella d
  printf -- '---\nname: x\ndescription: finta\nallowed-tools: Read\n---\nC.\n' \
    > "${TMP}/scatola/.claude/skills/audit-configurazione/SKILL.md" || exit 2
  ( cd "${TMP}/scatola" && "${TMP}/finto/claude" -p --allowedTools Read \
      --model sonnet --output-format stream-json --verbose -- "${P_AUD}" ) \
    > "${d}/audit-on-1.jsonl" || exit 2
  scrivi_stream "${d}/audit-senza-1.jsonl" sonnet audit senza
  controlla "${d}"
  expect "garanzia: on con la chiamata negata dal permesso (1)" 1 "negata"
  nuova_cartella d
  scrivi_stream "${d}/risposta-on-1.jsonl" sonnet risposta on \
    FINTO_ON_RESPINTA=1
  scrivi_stream "${d}/risposta-senza-1.jsonl" sonnet risposta senza
  controlla "${d}"
  expect "garanzia: on con la chiamata respinta (1)" 1 "respinta"
  printf -- '---\nname: x\ndescription: finta\n---\nCorpo finto.\n' \
    > "${TMP}/scatola/.claude/skills/audit-configurazione/SKILL.md" || exit 2
  nuova_cartella d
  coppia "${d}" audit 1 FINTO_NON_CHIAMA=1
  controlla "${d}"
  expect "invocazione: on senza chiamata è un dato (0)" 0 \
    "Skill audit-configurazione: no"
  nuova_cartella d
  coppia "${d}" revisione 1 FINTO_REVIEW_NEGATA=1
  controlla "${d}"
  expect "code-review negata dal permesso: un dato (0)" 0 \
    "code-review (negata dal permesso)"
  nuova_cartella d
  coppia "${d}" revisione 1 FINTO_NIENTE_REVIEW=1
  controlla "${d}"
  expect "senza code-review, la riga del braccio (0)" 0 \
    "Skill revisione-pr: no"
  assente "senza code-review, nessuna altra skill" "altre skill"
}

# La garanzia di off: un set a sé, un'esecuzione per archetipo, che non entra
# nelle coppie. Il primo caso è ciò che ha mostrato la prima esecuzione vera: la
# chiamata tentata e respinta, e i file letti dalla cartella.
t_off() {
  local d a
  nuova_cartella d
  coppia "${d}" audit 1
  for a in revisione risposta; do
    scrivi_stream "${d}/${a}-off-1.jsonl" sonnet "${a}" off
  done
  scrivi_stream "${d}/audit-off-1.jsonl" sonnet audit off FINTO_OFF_TENTA=1 \
    FINTO_OFF_LEGGE=1
  controlla "${d}"
  expect "off: un tentativo respinto non è un reperto (0)" 0 \
    "garanzia di off: tiene 1 su 1"
  assente "off: nessun reperto" "REPERTO"
  c_e "off: il tentativo si dice" \
    "Skill audit-configurazione: no, tentata e respinta"
  c_e "off: il testo dell'errore, come dato" \
    "Skill audit-configurazione is disabled for model invocation"
  c_e "off: i file letti, come dato" "Read audit-configurazione/SKILL.md"
  c_e "off: lo script eseguito, come dato" \
    "Bash audit-configurazione/scripts/controlli_ovvi.py"
  c_e "off: la garanzia su tutte, n su N" \
    "garanzia di off, in tutto: tiene 3 su 3"
  c_e "off: i tentativi, n su N" "tentativi respinti: 1 su 3"
  c_e "off: i file della skill, n su N" \
    "file sotto .claude/skills/ nominati da Claude: 1 su 3"
  c_e "off: la coppia dell'audit è fra on e senza" \
    "coppia 1: on 5, senza 0 su 5: ${CONF}"
  assente "off: non entra nel confronto" "on 5, off"
  nuova_cartella d
  coppia "${d}" audit 1
  scrivi_stream "${d}/audit-off-1.jsonl" sonnet audit off FINTO_OFF_CHIAMA=1
  controlla "${d}"
  expect "off: una chiamata che riesce (1)" 1 "REPERTO"
  c_e "off: la garanzia non tiene" "garanzia di off: tiene 0 su 1"
  nuova_cartella d
  coppia "${d}" audit 1
  scrivi_stream "${d}/audit-off-1.jsonl" sonnet audit off FINTO_OFF_ELENCA=1
  controlla "${d}"
  expect "off: la skill nell'elenco (1)" 1 "fra le skill"
  nuova_cartella d
  coppia "${d}" audit 1
  scrivi_stream "${d}/audit-off-1.jsonl" sonnet audit off FINTO_TRONCO=1
  controlla "${d}"
  expect "off: uno stream senza il risultato (1)" 1 "incompleta"
  nuova_cartella d
  scrivi_stream "${d}/audit-off-1.jsonl" sonnet audit off
  controlla "${d}"
  expect "off: da solo, nessuna coppia (1)" 1 "Nessuna coppia"
}

t_rovinati() {
  local d
  nuova_cartella d
  controlla "${d}"
  expect "stream: nessuna coppia (1)" 1 "Nessuna coppia"
  controlla "${d}/non-c-e"
  expect "stream: nessuna cartella (1)" 1 "Manca"
  nuova_cartella d
  scrivi_stream "${d}/revisione-on-1.jsonl" sonnet revisione on
  controlla "${d}"
  expect "stream: una coppia a metà (1)" 1 "manca revisione-senza-1.jsonl"
  nuova_cartella d
  coppia "${d}" revisione 1 FINTO_TRONCO=1
  controlla "${d}"
  expect "stream: senza il risultato (1)" 1 "incompleta"
  nuova_cartella d
  coppia "${d}" revisione 1 FINTO_ERRORE=1
  controlla "${d}"
  expect "stream: finito con un errore (1)" 1 "errore"
  nuova_cartella d
  coppia "${d}" revisione 1
  printf 'non è JSON\n' >> "${d}/revisione-on-1.jsonl"
  controlla "${d}"
  expect "stream: una riga che non è JSON (2)" 2 "non è JSON"
  assente "stream: niente traceback" "Traceback"
  nuova_cartella d
  coppia "${d}" revisione 1 FINTO_SENZA_ELENCO=1
  controlla "${d}"
  expect "stream: senza l'elenco delle skill (2)" 2 "elenco"
  nuova_cartella d
  coppia "${d}" revisione 1
  printf '{}\n' > "${d}/altro-nome.jsonl"
  controlla "${d}"
  expect "stream: un nome sconosciuto (2)" 2 "altro-nome.jsonl"
}

t_precondizioni() {
  local d
  nuova_cartella d
  coppia "${d}" revisione 1
  run env -u PN_HANDSON_ROOT python3 -B -I \
    "${ITEM}/demo/controlla_archetipi.py" "${d}"
  expect "precondizione: senza PN_HANDSON_ROOT (2)" 2 "PN_HANDSON_ROOT"
  run env PN_HANDSON_ROOT="${TMP}/non-c-e" python3 -B -I \
    "${ITEM}/demo/controlla_archetipi.py" "${d}"
  expect "precondizione: un PN_HANDSON_ROOT sbagliato (2)" 2 "PN_HANDSON_ROOT"
  run env PN_HANDSON_ROOT="${RADICE}" python3 -B -I \
    "${ITEM}/demo/controlla_archetipi.py" --verita "${TMP}/non-c-e" "${d}"
  expect "precondizione: la verità assente (2)" 2 "verit"
  printf '{"revisione": {"regole": ["x"]}}' > "${TMP}/brutta.json"
  run env PN_HANDSON_ROOT="${RADICE}" python3 -B -I \
    "${ITEM}/demo/controlla_archetipi.py" --verita "${TMP}/brutta.json" "${d}"
  expect "precondizione: una verità senza la forma giusta (2)" 2 "verit"
  run env PN_HANDSON_ROOT="${RADICE}" python3 -B -I \
    "${ITEM}/demo/controlla_archetipi.py"
  expect "precondizione: nessun argomento (2)" 2 "Uso:"
  run env PN_HANDSON_ROOT="${RADICE}" python3 -B -I \
    "${ITEM}/demo/controlla_archetipi.py" --boh "${d}"
  expect "precondizione: un'opzione sconosciuta (2)" 2 "--boh"
  assente "precondizione: niente traceback" "Traceback"
  run env PN_HANDSON_ROOT="${RADICE}" python3 -B -I \
    "${ITEM}/demo/controlla_archetipi.py" "${d}"
  expect "senza --verita, la verità dell'elemento (0)" 0 "su 8"
}

t_modelli() {
  local d a m
  nuova_cartella d
  for a in revisione risposta audit; do
    for m in haiku opus; do
      scrivi_stream "${d}/${a}-${m}.jsonl" "${m}" "${a}" on
    done
  done
  controlla "${d}" --modelli
  expect "modelli: sei esecuzioni (0)" 0 "haiku"
  c_e "modelli: Opus" "opus"
  c_e "modelli: gli stessi criteri" "regole inserite citate: 8 su 8"
  c_e "modelli: i turni e i token" "4 turni, 6210 token, 7,3 s"
  c_e "modelli: i file sotto .claude/skills/" \
    "file sotto .claude/skills/: Read"
  c_e "modelli: la frase di Anthropic" "Tested with Haiku, Sonnet, and Opus"
  assente "modelli: nessun verdetto" "confermata"
  assente "modelli: nessun confronto" "distinguibile"
  rm -- "${d}/audit-opus.jsonl"
  controlla "${d}" --modelli
  expect "modelli: uno stream che manca (1)" 1 "manca audit-opus.jsonl"
  printf '{}\n' > "${d}/audit-fable.jsonl"
  controlla "${d}" --modelli
  expect "modelli: un nome sconosciuto (2)" 2 "audit-fable.jsonl"
}

# --- verifica.sh ------------------------------------------------------------

t_verifica() {
  local w
  run "${ITEM}/verifica.sh" "${TMP}/non-c-e"
  expect "verifica: spazio di lavoro assente (2)" 2 "spazio di lavoro"
  nuovo_ws w || { fail "verifica: lo spazio di lavoro non nasce"; return 0; }
  run env PATH="${TMP}/senza_python" "${ITEM}/verifica.sh" "${w}"
  expect "verifica: senza python3 (2)" 2 "python3"
  mkdir -p "${w}/risposte" || exit 2
  coppia "${w}/risposte" revisione 1
  printf 'import sys\nsys.exit(0)\n' > "${w}/controlla_archetipi.py"
  run "${ITEM}/verifica.sh" "${w}"
  expect "verifica: il controllo dell'elemento, anche senza l'ambiente (0)" \
    0 "Fatto"
  c_e "verifica: i verdetti si vedono" "${CONF}"
  run env PN_HANDSON_ROOT="${RADICE}" "${RADICE}/tools/verifica.sh" M5-D04 \
    --radice "${w%/M5-D04}"
  expect "tools/verifica.sh: lo stesso esito (0)" 0 "VERIFICA OK"
  scrivi_stream "${w}/risposte/revisione-off-1.jsonl" sonnet revisione off \
    FINTO_OFF_TENTA=1
  run "${ITEM}/verifica.sh" "${w}"
  expect "verifica: un tentativo respinto, un dato (0)" 0 "Fatto"
  scrivi_stream "${w}/risposte/revisione-off-1.jsonl" sonnet revisione off \
    FINTO_OFF_CHIAMA=1
  run "${ITEM}/verifica.sh" "${w}"
  expect "verifica: la garanzia di off decide l'uscita (1)" 1 "REPERTO"
  rm -- "${w}/risposte/revisione-off-1.jsonl"
  coppia "${w}/risposte" revisione 2 FINTO_SENZA_CHIAMA=1
  run "${ITEM}/verifica.sh" "${w}"
  expect "verifica: la garanzia di senza decide l'uscita (1)" 1 "REPERTO"
}

# --- Le esecuzioni ----------------------------------------------------------

t_live() {
  local w
  nuovo_ws w || { fail "live: lo spazio di lavoro non nasce"; return 0; }
  finto "${w}" ""
  expect "live: 21 esecuzioni, le garanzie tengono (0)" 0 "VERIFICA OK"
  c_e "live: i verdetti si vedono" "${CONF} 3 su 3"
  c_e "live: il comando si vede" "claude -p"
  c_e "live: la garanzia di off si vede" \
    "garanzia di off, in tutto: tiene 3 su 3"
  controlla_chiamate "${TMP}/finto.log" "${w}" principale 3
  expect "live: ogni chiamata come deve" 0 "chiamate giuste"
  run command find "${w}/risposte" -name '*.jsonl'
  if (( $(grep -c . <<< "${OUT}") == 21 )); then
    pass "live: gli stream in risposte/"
  else
    fail "live: gli stream: ${OUT}"
  fi
  vero "live: l'off di ogni archetipo" test -s "${w}/risposte/audit-off-1.jsonl"
  vero "live: la cartella della revisione è su pr-demo" \
    test "$(git -C "${w}/revisione" rev-parse --abbrev-ref HEAD)" = pr-demo
  run python3 -B -I - "${w}" <<'PY'
import subprocess, sys
ws = sys.argv[1]
def git(cartella, *args):
    return subprocess.run(("git", "-C", ws + "/" + cartella) + args,
                          stdout=subprocess.PIPE, check=True).stdout.decode()
problemi = []
for arch, skill in (("revisione", "revisione-pr"),
                    ("risposta", "risposta-assistenza"),
                    ("audit", "audit-configurazione")):
    con = git(arch, "ls-files").splitlines()
    senza = git(arch + "-senza", "ls-files").splitlines()
    sua = ".claude/skills/%s/" % skill
    if not any(f.startswith(sua) for f in con):
        problemi.append("%s: la skill non è committata" % arch)
    if [f for f in con if not f.startswith(sua)] != senza:
        problemi.append("%s: le due cartelle differiscono" % arch)
    if git(arch, "log", "--format=%s") \
            != git(arch + "-senza", "log", "--format=%s"):
        problemi.append("%s: la storia differisce" % arch)
    if git(arch, "status", "--porcelain") \
            or git(arch + "-senza", "status", "--porcelain"):
        problemi.append("%s: una cartella cambiata" % arch)
print("; ".join(problemi) or "cartelle uguali tranne la skill")
PY
  expect "live: le due cartelle, uguali tranne la skill" 0 \
    "cartelle uguali tranne la skill"
  finto "${w}" ""
  expect "live: risposte/ c'è già (2)" 2 "risposte/"
  finto "${w}" modelli
  expect "live: i modelli nello spazio di lavoro usato (2)" 2 "risposte/"
  nuovo_ws w || { fail "live: lo spazio di lavoro non nasce"; return 0; }
  finto "${w}" modelli
  expect "live modelli: sei esecuzioni (0)" 0 "VERIFICA OK"
  c_e "live modelli: i dati" "Tested with Haiku, Sonnet, and Opus"
  assente "live modelli: nessun verdetto" "non distinguibile"
  controlla_chiamate "${TMP}/finto.log" "${w}" modelli 0
  expect "live modelli: ogni chiamata come deve" 0 "chiamate giuste"
  vero "live modelli: nella sua cartella" \
    test -f "${w}/risposte-modelli/audit-opus.jsonl"
  nuovo_ws w || { fail "live: lo spazio di lavoro non nasce"; return 0; }
  finto "${w}" "" PN_COPPIE=1
  expect "live: PN_COPPIE sceglie le coppie (0)" 0 "${CONF} 1 su 1"
  controlla_chiamate "${TMP}/finto.log" "${w}" principale 1
  expect "live: PN_COPPIE=1, una coppia e un off per archetipo" 0 \
    "chiamate giuste"
}

t_live_esiti() {
  local w
  nuovo_ws w || { fail "live: lo spazio di lavoro non nasce"; return 0; }
  finto "${w}" "" FINTO_KO_SENZA=1
  expect "live: una chiamata fallita (1)" 1 "claude -p è fallito"
  vero "live: lo stream finito resta" \
    test -s "${w}/risposte/revisione-on-1.jsonl"
  vero "live: le chiamate dopo non partono" \
    test ! -e "${w}/risposte/revisione-on-2.jsonl"
  nuovo_ws w || { fail "live: lo spazio di lavoro non nasce"; return 0; }
  finto "${w}" "" PN_COPPIE=1 FINTO_KO_SE=skillOverrides
  expect "live: una chiamata di off fallita (1)" 1 "claude -p è fallito"
  vero "live: le coppie restano" \
    test -s "${w}/risposte/audit-senza-1.jsonl"
  nuovo_ws w || { fail "live: lo spazio di lavoro non nasce"; return 0; }
  finto "${w}" "" PN_COPPIE=1 FINTO_OFF_CHIAMA=1
  expect "live: la garanzia di off che non regge (1)" 1 "REPERTO"
  nuovo_ws w || { fail "live: lo spazio di lavoro non nasce"; return 0; }
  finto "${w}" "" PN_COPPIE=1 FINTO_SENZA_CHIAMA=1
  expect "live: la garanzia di senza che non regge (1)" 1 "REPERTO"
  nuovo_ws w || { fail "live: lo spazio di lavoro non nasce"; return 0; }
  finto "${w}" "" PN_COPPIE=1 FINTO_OFF_TENTA=1 FINTO_OFF_LEGGE=1
  expect "live: un tentativo respinto, un dato (0)" 0 "VERIFICA OK"
  c_e "live: i file letti da off si vedono" "Read audit-configurazione/SKILL.md"
  nuovo_ws w || { fail "live: lo spazio di lavoro non nasce"; return 0; }
  finto "${w}" "" PN_COPPIE=1 FINTO_SCRIVE=1
  expect "live: un file lasciato da una sessione, un dato (0)" 0 \
    "segno-del-finto.txt"
  vero "live: la cartella on torna com'era" \
    test ! -e "${w}/revisione/segno-del-finto.txt"
  vero "live: la cartella senza torna com'era" \
    test ! -e "${w}/revisione-senza/segno-del-finto.txt"
}

t_live_precondizioni() {
  local w
  nuovo_ws w || { fail "live: lo spazio di lavoro non nasce"; return 0; }
  precondizione "live: senza argomenti, l'uso" "uso: _docente/live.sh" \
    "${ITEM}/_docente/live.sh"
  precondizione "live: tre argomenti, l'uso" "uso: _docente/live.sh" \
    "${ITEM}/_docente/live.sh" "${w}" modelli di-troppo
  precondizione "live: spazio di lavoro assente" "spazio di lavoro" \
    "${ITEM}/_docente/live.sh" "${TMP}/non-c-e"
  # Uno spazio di lavoro con del lavoro: una registrazione partirebbe da un
  # punto diverso, o con una richiesta diversa dal README.
  printf 'x\n' > "${w}/di-troppo.txt"
  precondizione "live: un file in più nello spazio di lavoro" \
    "reset_esercizio.sh M5-D04" "${ITEM}/_docente/live.sh" "${w}"
  rm -- "${w}/di-troppo.txt"
  printf 'una riga in più\n' >> "${w}/richieste.tsv"
  precondizione "live: una richiesta cambiata" \
    "reset_esercizio.sh M5-D04" "${ITEM}/_docente/live.sh" "${w}"
  git -C "${w}" checkout -q -- richieste.tsv || exit 2
  precondizione "live: una cartella non preparata" "prepara" \
    "${ITEM}/_docente/live.sh" "${TMP}/finto"
  precondizione "live: un set sconosciuto" "boh" \
    "${ITEM}/_docente/live.sh" "${w}" boh
  precondizione "live: PN_COPPIE sbagliato" "PN_COPPIE" PN_COPPIE=0 \
    "${ITEM}/_docente/live.sh" "${w}"
  precondizione "live: HANDSON_ENV sbagliato" "HANDSON_ENV" \
    HANDSON_ENV=trainer-api "${ITEM}/_docente/live.sh" "${w}"
  rm -- "${w}/richieste.tsv"
  precondizione "live: senza le richieste" "richieste.tsv" \
    "${ITEM}/_docente/live.sh" "${w}"
}

t_in_classe() {
  local w
  nuovo_ws w || { fail "in_classe: lo spazio di lavoro non nasce"; return 0; }
  run env -u PN_HANDSON_ROOT PATH="${TMP}/esca:${PATH}" HANDSON_NO_PAUSE=1 \
    ESCA_LOG="${TMP}/esca.log" "${w}/in_classe.sh" revisione
  expect "in_classe: senza PN_HANDSON_ROOT (2)" 2 "PN_HANDSON_ROOT"
  precondizione "in_classe: nessun archetipo" "archetipo" \
    PN_HANDSON_ROOT="${RADICE}" "${w}/in_classe.sh"
  precondizione "in_classe: un archetipo sconosciuto" "boh" \
    PN_HANDSON_ROOT="${RADICE}" "${w}/in_classe.sh" boh
  precondizione "in_classe: fuori da uno spazio di lavoro" "prepara" \
    PN_HANDSON_ROOT="${RADICE}" "${ITEM}/demo/in_classe.sh" revisione
  mkdir -p "${w}/audit" || exit 2
  precondizione "in_classe: una cartella a metà" "preparata" \
    PN_HANDSON_ROOT="${RADICE}" "${w}/in_classe.sh" audit
  rm -rf -- "${w}/audit" || exit 2
  mkdir -p "${w}/audit-senza" || exit 2
  precondizione "in_classe: la cartella senza a metà" "preparata" \
    PN_HANDSON_ROOT="${RADICE}" "${w}/in_classe.sh" audit
  rm -rf -- "${w}/audit-senza" "${w}/audit" || exit 2
  : > "${TMP}/finto.log"
  run env PATH="${TMP}/finto:${PATH}" HANDSON_NO_PAUSE=1 \
    ANTHROPIC_API_KEY=valore-finto PN_HANDSON_ROOT="${RADICE}" \
    FINTO_LOG="${TMP}/finto.log" "${w}/in_classe.sh" revisione
  expect "in_classe: una coppia (0)" 0 "${CONF} 1 su 1"
  c_e "in_classe: i dati si vedono" "regole inserite citate: 8 su 8"
  vero "in_classe: lo stream on" test -s "${w}/risposte/revisione-on-1.jsonl"
  vero "in_classe: lo stream senza" \
    test -s "${w}/risposte/revisione-senza-1.jsonl"
  vero "in_classe: nessun off" test ! -e "${w}/risposte/revisione-off-1.jsonl"
  vero "in_classe: solo le cartelle dell'archetipo" test ! -e "${w}/audit"
  run python3 -B -I - "${TMP}/finto.log" "${w}" <<'PY'
import json, sys
righe = [json.loads(r) for r in open(sys.argv[1], encoding="utf-8")]
chiamate = [r for r in righe if r["argv"][:1] != ["--version"]]
buone = len(chiamate) == 2 and all(
    not c["chiave"] and not c["risposte_vicine"]
    and "Read,Skill(revisione-pr)" in c["argv"]
    and "--settings" not in c["argv"] for c in chiamate) \
    and chiamate[0]["cwd"].endswith("/revisione") \
    and chiamate[0]["skill"] == ["revisione-pr"] \
    and chiamate[1]["cwd"].endswith("/revisione-senza") \
    and chiamate[1]["skill"] == [] \
    and chiamate[0]["argv"] == chiamate[1]["argv"]
print("chiamate giuste" if buone else repr(chiamate))
PY
  expect "in_classe: due chiamate, con le stesse opzioni" 0 "chiamate giuste"
  run env PATH="${TMP}/finto:${PATH}" HANDSON_NO_PAUSE=1 \
    PN_HANDSON_ROOT="${RADICE}" "${w}/in_classe.sh" revisione
  expect "in_classe: la seconda volta, la coppia dopo (0)" 0 "${CONF} 2 su 2"
  vero "in_classe: lo stream di prima resta" \
    test -s "${w}/risposte/revisione-on-2.jsonl"
  run env PN_HANDSON_ROOT="${RADICE}" "${RADICE}/tools/verifica.sh" M5-D04 \
    --radice "${w%/M5-D04}"
  expect "in_classe: poi la verifica (0)" 0 "VERIFICA OK"
}

# Il comando del README per la skill spenta, così com'è stampato, in uno spazio
# di lavoro nel posto che il README dice: gira, e la verifica lo legge.
t_readme_off() {
  local casa w blocco
  casa="$(mktemp -d "${TMP}/casa.XXXXXX")" || exit 2
  "${RADICE}/tools/prepara_esercizio.sh" M5-D04 --radice \
    "${casa}/corso-claude-code" > "${TMP}/prepara.log" 2>&1 \
    || { fail "README, off: lo spazio di lavoro non nasce"; return 0; }
  w="${casa}/corso-claude-code/M5-D04"
  run env PATH="${TMP}/finto:${PATH}" HANDSON_NO_PAUSE=1 \
    PN_HANDSON_ROOT="${RADICE}" "${w}/in_classe.sh" revisione
  expect "README, off: prima una coppia (0)" 0 "${CONF} 1 su 1"
  # Il solo blocco di codice dopo quella frase, e soltanto se è quello atteso:
  # il resto del README non è da eseguire.
  blocco="$(python3 -B -I - "${ITEM}/README.md" <<'PY'
import sys
righe = open(sys.argv[1], encoding="utf-8").read().split("\n")
inizio = next((n for n, r in enumerate(righe)
               if r.startswith("Per vedere la skill spenta")), len(righe))
blocco = []
for riga in righe[inizio + 1:]:
    if riga.startswith("    "):
        blocco.append(riga[4:])
    elif blocco:
        break
print("\n".join(blocco))
PY
)"
  if [[ "${blocco}" == 'cd ~/corso-claude-code/M5-D04/revisione'$'\n'* \
      && "${blocco}" == *'--settings'* \
      && "${blocco}" == *'> ../risposte/revisione-off-1.jsonl'$'\n''cd -' ]]
  then
    pass "README, off: il comando per intero, con il file dello stream"
  else
    fail "README, off: il comando per intero: «${blocco:0:400}»"
    return 0
  fi
  run env HOME="${casa}" PATH="${TMP}/finto:${PATH}" \
    FINTO_LOG="${TMP}/finto.log" bash -c "${blocco}"
  if (( RC == 0 )); then
    pass "README, off: il comando gira così com'è"
  else
    fail "README, off: il comando esce con ${RC}: ${OUT:0:500}"
  fi
  vero "README, off: lo stream in risposte/" \
    test -s "${w}/risposte/revisione-off-1.jsonl"
  run env PN_HANDSON_ROOT="${RADICE}" "${ITEM}/verifica.sh" "${w}"
  expect "README, off: la verifica lo legge (0)" 0 \
    "garanzia di off: tiene 1 su 1"
}

# Il README e la registrazione: le righe che cita sono quelle che verifica.sh
# stampa sugli stream di soluzione/. Il set modelli non sta in soluzione/: le
# sue righe si controllano soltanto nel README.
t_registrazione() {
  local w uscita="${TMP}/uscita.txt"
  nuovo_ws w || { fail "registrazione: lo spazio di lavoro"; return 0; }
  cp -R "${ITEM}/soluzione/." "${w}/" || exit 2
  run "${ITEM}/verifica.sh" "${w}"
  expect "registrazione: verifica.sh su soluzione/ (0)" 0 "Fatto"
  printf '%s\n' "${OUT}" > "${uscita}"
  run python3 -B -I "${MOD}/_docente/controlla_registrazione.py" \
    "${ITEM}/README.md" "${uscita}" <<'FRASI'
= garanzia di off, in tutto: tiene 3 su 3
= come dati: tentativi respinti: 0 su 3; file sotto .claude/skills/ nominati da Claude: 1 su 3
= revisione: Skill revisione-pr: on 3 su 3, senza 0 su 3
= revisione: altre skill, senza: code-review 3 su 3
= revisione: criteri in tutto: on 24, senza 0 su 24: confermata
= revisione: coppia per coppia: confermata 3 su 3
= risposta: Skill risposta-assistenza: on 3 su 3, senza 0 su 3
= risposta: criteri in tutto: on 12, senza 4 su 12: confermata
= risposta: coppia per coppia: confermata 3 su 3
= audit: Skill audit-configurazione: on 3 su 3, senza 0 su 3
= audit: criteri in tutto: on 15, senza 12 su 15: confermata
= audit: coppia per coppia: confermata 3 su 3
= revisione: in media, come dato: on 61093 token, 18,4 s; senza 60925 token, 17,5 s
= risposta: in media, come dato: on 60109 token, 13,0 s; senza 18017 token, 8,8 s
= audit: in media, come dato: on 154922 token, 34,1 s; senza 154386 token, 47,2 s
= dove i due bracci fanno lo stesso, non è la skill
R Nella registrazione del corso (3 novembre 2026, Claude Code 2.1.317, Sonnet con effort low, tre coppie per archetipo
R sull'account del docente, un piano Max
R Questa tabella non confronta i modelli.
R claude-haiku-5-5
R claude-opus-5-5
R In una prova precedente
! nove esecuzioni
! due esecuzioni su tre
! ne ha eseguito lo script
! Attesi, dalla prima esecuzione
FRASI
  expect "registrazione: il README cita le righe del controllo" 0 "in ordine"
}

t_shellcheck() {
  local f
  for f in "${SELF}" "${ITEM}/verifica.sh" "${ITEM}/_docente/live.sh" \
      "${ITEM}/demo/in_classe.sh" "${ITEM}/demo/lib_archetipi.sh"; do
    run shellcheck -x "${f}"
    if (( RC == 0 )); then
      pass "shellcheck: ${f##*/}"
    else
      fail "shellcheck: ${f##*/}: ${OUT:0:800}"
    fi
  done
}

main() {
  local t
  for t in python3 git shellcheck; do
    command -v "${t}" >/dev/null 2>&1 \
      || { echo "test_m5_d04: manca ${t}" >&2; exit 2; }
  done
  [[ -f "${FINTO_PY}" ]] \
    || { echo "test_m5_d04: manca ${FINTO_PY}" >&2; exit 2; }
  handson::init_temp_base
  TMP="$(mktemp -d "${HANDSON_TEMP_BASE}/test_m5_d04.XXXXXX")" || exit 2
  trap 'chmod -R u+rwX "${TMP}" 2>/dev/null; rm -rf "${TMP}"' EXIT
  prepara_claude
  t_elemento
  t_verita
  t_readme
  t_prepara
  t_completa
  t_tre_coppie
  t_verdetti
  t_risposta
  t_parole_e_lab
  t_audit_criteri
  t_garanzia
  t_off
  t_rovinati
  t_precondizioni
  t_modelli
  t_verifica
  t_live
  t_live_esiti
  t_live_precondizioni
  t_in_classe
  t_readme_off
  t_registrazione
  t_shellcheck
  OUT="${TUTTO}"
  assente "in nessuna uscita «smentita»" "smentita"
  echo "PASS=${PASS} FAIL=${FAIL}"
  if (( PASS + FAIL != CASES )); then
    echo "test_m5_d04: girati $((PASS + FAIL)) casi, attesi ${CASES}" >&2
    exit 2
  fi
  (( FAIL == 0 )) || exit 1
}

main "$@"
