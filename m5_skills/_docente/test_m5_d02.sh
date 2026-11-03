#!/bin/bash
#
# test_m5_d02.sh -- le prove di M5-D02 «La descrizione decide», per il docente
# (sta in _docente/, il materiale del docente):
#   - l'elemento: la configurazione di due righe, le due richieste, le due
#     description, il corpo; le dieci sezioni del README, le frasi di Anthropic
#     con il loro indirizzo, i prompt uguali ai file; nessun nome interno,
#     percorso personale, «smentita» o riferimento alla giornata;
#   - prepara_esercizio.sh e verifica.sh sul punto di partenza (1);
#   - prepara_braccio.sh: i bracci differiscono soltanto nella parte che
#     cambia; controlla_skill.py passa sulla description specifica e avvisa su
#     quella vaga; le precondizioni (2);
#   - controlla_descrizione.py su stream del claude finto: i conteggi, il
#     marcatore come dato, il confronto (mai un'uscita diversa da 0), la
#     near-miss come dato, la garanzia del flag e /prova-d02 (1 se non
#     reggono); gli stream che mancano o non si leggono (2), mai un traceback;
#   - verifica.sh: il controllo dell'elemento, mai quello dello spazio di
#     lavoro; le precondizioni (2);
#   - demo/in_classe.sh e _docente/live.sh con il claude finto: quante chiamate,
#     da quale cartella nuova, con quali testi e opzioni, senza
#     ANTHROPIC_API_KEY, gli stream fuori dallo spazio di lavoro finché le
#     sessioni girano; le precondizioni (2, nessuna chiamata: l'esca); una
#     chiamata fallita (1);
#   - shellcheck -x sugli script e su questo file.
# Mai il claude vero: il finto e l'esca stanno davanti nel PATH, e la suite lo
# controlla prima di usarli. Gli stream del finto non sono risposte di Claude:
# provano il controllo, non il modello. Gli spazi di lavoro nascono in una
# cartella temporanea, nella base di handson::init_temp_base: l'albero del
# repository non cambia. CASES è il numero dei casi: se ne girano di più o di
# meno la suite esce 2.
#
# Uso:    m5_skills/_docente/test_m5_d02.sh
# Uscita: 0 = tutti i casi passano · 1 = almeno un caso fallito · 2 =
#         precondizione (manca python3, git o shellcheck), o un numero di casi
#         diverso da CASES
set -uo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly MOD="${SELF%/_docente/*}"
readonly RADICE="${MOD%/*}"
readonly D02="${MOD}/s4_skills/m5_4_anatomia/M5-D02_la_descrizione_decide"
readonly FINTO_PY="${MOD}/_docente/claude_finto_m5_d01_d02.py"
# La libreria del repository, per la base dei file temporanei.
# shellcheck source=../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"
readonly CASES=175
R='Controlla la configurazione di sw-prova-01 (configurazione.txt):'
R+=' ci sono problemi?'
readonly R
readonly N='Quante righe ha il file configurazione.txt?'
readonly VAGA='Aiuta con i file'
SPECIFICA='Controlla la configurazione di un apparato di rete contro la'
SPECIFICA+=' checklist di audit del team. Da usare quando si chiede di'
SPECIFICA+=' controllare o rivedere la configurazione di un apparato.'
readonly SPECIFICA
readonly NOME_SKILL=prova-d02
FATTO='Fatto: ogni affermazione è stata messa alla prova;'
FATTO+=' gli esiti sono qui sopra.'
readonly FATTO
readonly NONCONF='non confermata in questa esecuzione'
readonly NONDIST='non distinguibile'
readonly S_CONFRONTO='Specifica contro vaga'
S_FLAG="Con il flag, «Claude can't invoke the skill on its own»"
readonly S_FLAG
S_NOME='/prova-d02 con il flag, «Include /skill-name in the prompt string»'
readonly S_NOME
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
# aggiunge a TUTTO, dove alla fine non devono esserci «smentita» né traceback.
run() { OUT="$("$@" 2>&1)"; RC=$?; TUTTO+="${OUT}"$'\n'; }

# Uscita attesa E parola chiave attesa (RU-01.T3).
# Arguments: $1 il nome, $2 l'uscita attesa, $3 la parola (grep -F).
expect() {
  if (( RC == $2 )) && grep -qF -- "$3" <<< "${OUT}"; then
    pass "$1"
  else
    fail "$1 (rc=${RC}, attesa $2, parola «$3»): ${OUT:0:600}"
  fi
}

# Nessun falso positivo: la parola NON c'è (RU-01.T5).
# Arguments: $1 il nome, $2 la parola.
expect_absent() {
  if grep -qF -- "$2" <<< "${OUT}"; then
    fail "$1: «$2» c'è: ${OUT:0:400}"
  else
    pass "$1"
  fi
}

# Un caso che passa se il comando riesce.
# Arguments: $1 il nome, poi il comando.
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
# Arguments: $1 la variabile da assegnare.
# Returns: 0; 1 se prepara_esercizio.sh non riesce.
nuovo_ws() {
  local __r
  __r="$(mktemp -d "${TMP}/radice.XXXXXX")" || exit 2
  "${RADICE}/tools/prepara_esercizio.sh" M5-D02 --radice "${__r}" \
    > "${TMP}/prepara.log" 2>&1 || return 1
  printf -v "$1" '%s' "${__r}/M5-D02"
}

# L'esca (registra ogni invocazione ed esce 0), il claude finto e i PATH
# ridotti. Esce 2 se nel PATH di prova claude non è il finto.
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
  for t in readlink git; do
    ln -s "$(command -v "${t}")" "${TMP}/senza_python/${t}" || exit 2
  done
  ln -s "${TMP}/esca/claude" "${TMP}/senza_python/claude" || exit 2
  for t in readlink python3 git; do
    ln -s "$(command -v "${t}")" "${TMP}/senza_claude/${t}" || exit 2
  done
  t="$(PATH="${TMP}/finto:${PATH}" command -v claude)"
  if [[ "${t}" != "${TMP}/finto/claude" ]]; then
    echo "test_m5_d02: nel PATH di prova claude è ${t}, non il finto" >&2
    exit 2
  fi
}

# La lettera della cartella di un braccio. Arguments: $1 il braccio.
lettera() {
  case "$1" in
    vaga) echo a ;;
    specifica) echo b ;;
    near_miss) echo c ;;
    manuale) echo d ;;
    manuale_nome) echo e ;;
    *) echo "test_m5_d02: braccio sconosciuto $1" >&2; exit 2 ;;
  esac
}

# Rifà uno stream del finto, dalla cartella del suo braccio, con il prompt del
# braccio. Arguments: $1 la cartella degli stream, $2 il nome (vaga-1…), poi le
# variabili NOME=valore.
rifai() {
  local json="$1" nome="$2" b="${2%-*}" prompt="${R}" dir
  shift 2
  dir="${TMP}/prove/$(lettera "${b}")"
  case "${b}" in
    near_miss) prompt="${N}" ;;
    manuale_nome) prompt="/${NOME_SKILL} ${R}" ;;
  esac
  ( cd "${dir}" && env ${@+"$@"} "${TMP}/finto/claude" -p --model sonnet \
      --output-format stream-json --verbose --no-session-persistence \
      --allowedTools Read -- "${prompt}" ) > "${json}/${nome}.jsonl" \
    || { echo "test_m5_d02: il finto non scrive ${nome}" >&2; exit 2; }
}

# Una cartella nuova di stream, con le esecuzioni da 1 a $2.
# Arguments: $1 la variabile da assegnare, $2 quante esecuzioni.
nuova_serie() {
  local __j __n __b
  __j="$(mktemp -d "${TMP}/json.XXXXXX")" || exit 2
  for (( __n = 1; __n <= $2; __n++ )); do
    for __b in vaga specifica near_miss manuale manuale_nome; do
      rifai "${__j}" "${__b}-${__n}"
    done
  done
  printf -v "$1" '%s' "${__j}"
}

# controlla_descrizione.py dell'elemento; RC e OUT come run.
controlla() { run python3 -B -I "${D02}/demo/controlla_descrizione.py" "$@"; }

# Lo script con l'esca davanti nel PATH (o con un PATH dato); il registro
# riparte vuoto. Arguments: $1 lo script, $2 lo spazio di lavoro, $3 facoltativo
# il PATH, poi le variabili NOME=valore.
esca() {
  local script="$1" w="$2" percorso="${3:-${TMP}/esca:${PATH}}"
  shift 2
  (( $# == 0 )) || shift
  : > "${TMP}/esca.log"
  run env PATH="${percorso}" HANDSON_NO_PAUSE=1 ESCA_LOG="${TMP}/esca.log" \
    "$@" "${script}" "${w}"
}

# Una precondizione: uscita 2, la parola attesa, nessuna chiamata al modello
# (--version a parte). Arguments: $1 il nome, $2 la parola, poi gli argomenti di
# esca.
precondizione() {
  local nome="$1" parola="$2" n
  shift 2
  esca "$@"
  expect "${nome}" 2 "${parola}"
  n="$(grep -c -v -- '--version' "${TMP}/esca.log")"
  if (( n == 0 )); then
    pass "${nome}: nessuna chiamata al modello"
  else
    fail "${nome}: ${n} chiamate"
  fi
}

# Lo script con il finto davanti nel PATH e ANTHROPIC_API_KEY impostata (lo
# script la deve togliere); il registro riparte vuoto.
# Arguments: $1 lo script, $2 lo spazio di lavoro, poi le variabili NOME=valore.
finto() {
  local script="$1" w="$2"
  shift 2
  : > "${TMP}/finto.log"
  run env PATH="${TMP}/finto:${PATH}" HANDSON_NO_PAUSE=1 \
    ANTHROPIC_API_KEY=valore-finto FINTO_LOG="${TMP}/finto.log" "$@" \
    "${script}" "${w}"
}

# Le chiamate di un registro del finto, contro le attese.
# Arguments: $1 il registro, $2 lo spazio di lavoro, $3 quante esecuzioni.
controlla_chiamate() {
  run python3 -B -I - "$1" "$2" "$3" "${R}" "${N}" "${NOME_SKILL}" <<'PY'
import json, os, sys
log, ws, n, r, near, nome = sys.argv[1:7]
righe = [json.loads(x) for x in open(log, encoding="utf-8")]
chiamate = [x for x in righe if x["argv"][:1] != ["--version"]]
attese = []
for k in range(1, int(n) + 1):
    attese += [("a-%d" % k, r), ("b-%d" % k, r), ("c-%d" % k, near),
               ("d-%d" % k, r), ("e-%d" % k, "/%s %s" % (nome, r))]
VALORE = {"--model", "--effort", "--output-format", "--setting-sources",
          "--permission-mode", "--permission-prompts", "--allowedTools",
          "--tools"}
fisse = (("--model", "sonnet"), ("--effort", "low"),
         ("--output-format", "stream-json"), ("--allowedTools", "Read"),
         ("--tools", "Read,Skill"),
         ("--setting-sources", "project,local"),
         ("--permission-mode", "dontAsk"), ("--permission-prompts", "none"))
problemi = []
if len(chiamate) != len(attese):
    problemi.append("%d chiamate invece di %d" % (len(chiamate), len(attese)))
for i, (c, (cartella, testo)) in enumerate(zip(chiamate, attese), 1):
    argv = c["argv"]
    if "--" not in argv:
        problemi.append("chiamata %d: il prompt non è dopo «--»" % i)
        continue
    fine, opzioni, j = argv.index("--"), {}, 0
    while j < fine:
        if argv[j] in VALORE:
            opzioni[argv[j]] = argv[j + 1]
            j += 2
        else:
            opzioni[argv[j]] = True
            j += 1
    if argv[fine + 1:] != [testo]:
        problemi.append("chiamata %d: il prompt %r" % (i, argv[fine + 1:]))
    attesa = os.path.realpath(os.path.join(ws, "prove", cartella))
    if os.path.realpath(c["cwd"]) != attesa:
        problemi.append("chiamata %d: la cartella %s" % (i, c["cwd"]))
    for chiave, valore in fisse:
        if opzioni.get(chiave) != valore:
            problemi.append("chiamata %d: %s" % (i, chiave))
    for chiave in ("-p", "--verbose", "--strict-mcp-config",
                   "--no-session-persistence"):
        if opzioni.get(chiave) is not True:
            problemi.append("chiamata %d: %s" % (i, chiave))
    if c["chiave"]:
        problemi.append("chiamata %d: con ANTHROPIC_API_KEY" % i)
    if not c["stdin_nullo"]:
        problemi.append("chiamata %d: STDIN non è /dev/null" % i)
    if c["risposte_vicine"]:
        problemi.append("chiamata %d: risposte/ già nello spazio" % i)
    if c["stream_vicini"]:
        problemi.append("chiamata %d: uno stream nello spazio" % i)
print("; ".join(problemi) or "chiamate giuste")
PY
}

# --- L'elemento -------------------------------------------------------------

t_elemento() {
  local f
  for f in README.md verifica.sh demo/configurazione.txt demo/richiesta.txt \
      demo/richiesta_near_miss.txt demo/descrizione_vaga.txt \
      demo/descrizione_specifica.txt demo/corpo.md demo/prepara_braccio.sh \
      demo/controlla_descrizione.py demo/in_classe.sh _docente/live.sh; do
    vero "elemento: ${f}" test -f "${D02}/${f}"
  done
  vero "elemento: soluzione/" test -d "${D02}/soluzione"
  for f in verifica.sh _docente/live.sh demo/in_classe.sh \
      demo/prepara_braccio.sh; do
    vero "elemento: ${f} eseguibile" test -x "${D02}/${f}"
  done
  run cat -- "${D02}/demo/richiesta.txt"
  expect "richiesta.txt: la richiesta dei bracci" 0 "${R}"
  run cat -- "${D02}/demo/richiesta_near_miss.txt"
  expect "richiesta_near_miss.txt: la near-miss" 0 "${N}"
  run cat -- "${D02}/demo/descrizione_vaga.txt"
  expect "descrizione_vaga.txt" 0 "${VAGA}"
  run cat -- "${D02}/demo/descrizione_specifica.txt"
  expect "descrizione_specifica.txt: che cosa fa, e quando" 0 "${SPECIFICA}"
  run wc -l "${D02}/demo/configurazione.txt"
  expect "configurazione.txt: due righe" 0 "2 "
  run cat -- "${D02}/demo/corpo.md"
  expect "corpo.md: il marcatore che il controllo cerca" 0 "AUD-01"
  run cat -- "${D02}/demo/configurazione.txt"
  expect_absent "configurazione.txt: nessun marcatore nei dati" "AUD-01"
}

# Il README: le dieci sezioni, le frasi di Anthropic, i prompt uguali ai file;
# niente nomi interni, percorsi personali, giornate, «smentita».
t_readme() {
  run python3 -B -I - "${D02}" <<'PY'
import os, re, sys
item = sys.argv[1]
with open(os.path.join(item, "README.md"), encoding="utf-8") as fh:
    readme = fh.read()
problemi = []
sezioni = ("Obiettivo", "Tempo", "Prerequisiti", "Punto di partenza",
           "Passi in Claude Code", "Che cosa osservare", "Verifica",
           "Se qualcosa va storto", "Impronta d'uso sul piano Pro",
           "Per approfondire")
titoli = [r[3:] for r in readme.splitlines() if r.startswith("## ")]
if [next((s for s in sezioni if t.startswith(s)), "") for t in titoli] \
        != list(sezioni):
    problemi.append("le dieci sezioni, in ordine: %s" % titoli)
for titolo in ("## Punto di partenza (tools/prepara_esercizio.sh M5-D02)",
               "## Verifica (tools/verifica.sh M5-D02)"):
    if titolo not in readme:
        problemi.append("il titolo «%s»" % titolo)
SKILLS = "https://code.claude.com/docs/en/skills"
ARTICOLO = ("https://claude.com/resources/articles/"
            "how-to-create-skills-key-steps-limitations-and-examples")
frasi = [
    ("Check the description includes keywords users would naturally say",
     SKILLS),
    ("«Make the description more specific»", SKILLS),
    ("«Add disable-model-invocation: true if you only want manual "
     "invocation»", SKILLS),
    ("«VERIFICA OK M5-D02: fatto.»", SKILLS),
    ("Claude evaluates skill descriptions against your request to determine "
     "relevance. This isn't keyword matching—Claude understands semantic "
     "relationships. However, vague descriptions reduce triggering accuracy.",
     ARTICOLO),
    ("the name and description are the only parts of the SKILL.md file that "
     "influence triggering", ARTICOLO),
    ("disable-model-invocation: true: Claude can't invoke the skill on its "
     "own. Use this for workflows with side effects or that you want to "
     "control timing", SKILLS),
    ("disable-model-invocation: true | Yes | Not on its own | Description not "
     "in context, full skill loads when invoked", SKILLS),
    ("Set disable-model-invocation: true in a skill's frontmatter to keep its "
     "description out of Claude's context.",
     "https://code.claude.com/docs/en/features-overview"),
    ("User-invoked skills and custom commands work. Include /skill-name in "
     "the prompt string and Claude Code expands it before running.",
     "https://code.claude.com/docs/en/headless"),
    ("The most valuable negative test cases are near-misses — queries that "
     "share keywords or concepts with your skill but actually need something "
     "different.",
     "https://agentskills.io/skill-creation/optimizing-descriptions"),
    ("Avoid vague descriptions such as these",
     "https://platform.claude.com/docs/en/agents-and-tools/agent-skills/"
     "best-practices"),
    ("description: Does stuff with files",
     "https://platform.claude.com/docs/en/agents-and-tools/agent-skills/"
     "best-practices"),
]
piatto = " ".join(readme.split())
for frase, url in frasi:
    if frase not in piatto:
        problemi.append("manca la frase «%s…»" % frase[:40])
    if url not in readme:
        problemi.append("manca l'indirizzo %s" % url)
leggi = lambda nome: open(os.path.join(item, "demo", nome),
                          encoding="utf-8").read().strip()
for numero, atteso in ((1, leggi("richiesta.txt")),
                       (2, leggi("richiesta_near_miss.txt")),
                       (3, "/prova-d02 " + leggi("richiesta.txt"))):
    blocco = re.search(r"<!-- prompt %d -->\n(.*?)\n\s*<!-- /prompt %d -->"
                       % (numero, numero), readme, re.S)
    if not blocco or blocco.group(1).strip() != atteso:
        problemi.append("il prompt %d non è quello dei file" % numero)
for nome in ("descrizione_vaga.txt", "descrizione_specifica.txt"):
    if " ".join(leggi(nome).split()) not in piatto:
        problemi.append("il README non porta %s" % nome)
if "AVVISO description" not in piatto:
    problemi.append("il README non dice l'avviso su «quando»")
maniglie = re.compile(r"\bFACT-(?:C|M[0-9])-[0-9]{3}\b|\bM[0-9]-X[0-9]+\b"
                      r"|\bX-[0-9]+\b|(?<![\w-])D(?:0[1-9]|[12][0-9]|3[01])\b"
                      r"|\b(?:ASK|OQ|DEC|TD|PQ)-[0-9]+\b|(?i:\btriage\b)")
for cartella, sotto, file in os.walk(item):
    sotto[:] = [d for d in sotto if d != "soluzione"]
    for nome in file:
        rel = os.path.relpath(os.path.join(cartella, nome), item)
        try:
            with open(os.path.join(cartella, nome), encoding="utf-8") as fh:
                testo = fh.read()
        except (OSError, UnicodeDecodeError):
            continue
        for m in maniglie.finditer(testo):
            problemi.append("%s: un nome interno «%s»" % (rel, m.group()))
        if "/home/" in testo:
            problemi.append("%s: un percorso personale" % rel)
        if "smentit" in testo:
            problemi.append("%s: «smentita»" % rel)
if re.search(r"(?i)\boggi\b|prossima sessione|\bpausa\b|pranzo", readme):
    problemi.append("il README parla della giornata")
print("; ".join(problemi) or "README in ordine")
PY
  expect "README: sezioni, frasi, indirizzi, prompt, nessun nome interno" 0 \
    "README in ordine"
}

# prepara_esercizio.sh: i file della demo; nessun progetto né materiale del
# docente; verifica.sh esce 1 sul punto di partenza.
t_prepara() {
  local w
  if ! nuovo_ws w; then
    fail "prepara: prepara_esercizio.sh non riesce: $(cat "${TMP}/prepara.log")"
    return 0
  fi
  if [[ -f "${w}/configurazione.txt" && -f "${w}/controlla_descrizione.py" \
      && -f "${w}/prepara_braccio.sh" && -f "${w}/in_classe.sh" \
      && -f "${w}/.claude/settings.json" && ! -e "${w}/_docente" \
      && ! -e "${w}/soluzione" && ! -e "${w}/progetti" \
      && ! -e "${w}/.claude/skills" ]]; then
    pass "prepara: i file della demo, senza il materiale del docente"
  else
    fail "prepara: lo spazio di lavoro non è quello atteso: $(ls -A "${w}")"
  fi
  run "${RADICE}/tools/verifica.sh" M5-D02 --radice "${w%/*}"
  expect "prepara: sul punto di partenza la verifica esce 1" 1 \
    "Manca la cartella risposte/"
}

# --- prepara_braccio.sh -----------------------------------------------------

# Lo SKILL.md di un braccio. Arguments: $1 la lettera.
skill_di() {
  printf '%s' "${TMP}/prove/$1/.claude/skills/${NOME_SKILL}/SKILL.md"
}

t_bracci() {
  local b l
  for b in vaga specifica near_miss manuale manuale_nome; do
    l="$(lettera "${b}")"
    run bash "${D02}/demo/prepara_braccio.sh" "${TMP}/prove/${l}" "${b}"
    if (( RC != 0 )); then
      fail "bracci: ${b}: esce ${RC}: ${OUT:0:300}"
      mkdir -p "${TMP}/prove/${l}"
      continue
    fi
    pass "bracci: ${b}: esce 0"
    run git -C "${TMP}/prove/${l}" status --porcelain
    if (( RC == 0 )) && [[ -z "${OUT}" ]]; then
      pass "bracci: ${b} è un repository pulito"
    else
      fail "bracci: ${b}: rc=${RC}, «${OUT}»"
    fi
    vero "bracci: ${b} ha la configurazione" \
      cmp -s "${TMP}/prove/${l}/configurazione.txt" \
      "${D02}/demo/configurazione.txt"
  done
  run python3 -B -I - "${TMP}/prove" "${NOME_SKILL}" "${D02}/demo" "${VAGA}" \
    "${SPECIFICA}" <<'PY'
import os, sys
prove, nome, demo, vaga, specifica = sys.argv[1:6]
leggi = lambda l: open(os.path.join(prove, l, ".claude", "skills", nome,
                                    "SKILL.md"), encoding="utf-8").read()
corpo = open(os.path.join(demo, "corpo.md"), encoding="utf-8").read()
testa = "---\nname: %s\ndescription: %%s\n%%s---\n\n%s" % (nome, corpo)
attesi = {"a": testa % (vaga, ""), "b": testa % (specifica, ""),
          "c": testa % (specifica, ""),
          "d": testa % (specifica, "disable-model-invocation: true\n"),
          "e": testa % (specifica, "disable-model-invocation: true\n")}
male = [l for l, atteso in attesi.items() if leggi(l) != atteso]
print("male: %s" % male if male else
      "bracci uguali, tranne la parte che cambia")
PY
  expect "bracci: differiscono soltanto nella parte che cambia" 0 \
    "bracci uguali, tranne la parte che cambia"
  l="$(skill_di b)"
  run python3 -B -I "${RADICE}/tools/controlla_skill.py" "${l%/*}"
  expect "bracci: controlla_skill.py passa sulla specifica" 0 "0 errori"
  expect_absent "bracci: sulla specifica nessun avviso sul «quando»" \
    "AVVISO description"
  l="$(skill_di a)"
  run python3 -B -I "${RADICE}/tools/controlla_skill.py" "${l%/*}"
  expect "bracci: sulla vaga l'avviso sul «quando» è il punto" 0 \
    "AVVISO description: non dice quando"
  run bash "${D02}/demo/prepara_braccio.sh" "${TMP}/prove/a" vaga
  expect "bracci: una cartella che c'è già, uscita 2" 2 "c'è già"
  run bash "${D02}/demo/prepara_braccio.sh" "${TMP}/prove/nuova" sconosciuto
  expect "bracci: un braccio sconosciuto, uscita 2" 2 "sconosciuto"
  vero "bracci: un braccio sconosciuto non crea niente" \
    test ! -e "${TMP}/prove/nuova"
  run bash "${D02}/demo/prepara_braccio.sh"
  expect "bracci: senza argomenti, uscita 2" 2 "uso:"
  mkdir -p "${TMP}/solo_script"
  cp -- "${D02}/demo/prepara_braccio.sh" "${TMP}/solo_script/"
  run bash "${TMP}/solo_script/prepara_braccio.sh" "${TMP}/altra" vaga
  expect "bracci: senza i file accanto, uscita 2" 2 "corpo.md"
  vero "bracci: senza i file accanto nessuna cartella" test ! -e "${TMP}/altra"
}

# --- controlla_descrizione.py -----------------------------------------------

# Tre esecuzioni pulite: i conteggi, i dati, i verdetti.
t_complete() {
  local j
  nuova_serie j 3
  controlla "${j}"
  expect "controllo: tre esecuzioni, uscita 0" 0 "${S_CONFRONTO}, «vague\
 descriptions reduce triggering accuracy»: confermata (3 su 3 contro 0 su 3)"
  expect "controllo: la vaga" 0 "vaga: Skill 0 su 3, marcatore 0 su 3"
  expect "controllo: la specifica" 0 "specifica: Skill 3 su 3, marcatore 3 su 3"
  expect "controllo: la near-miss" 0 "near-miss: Skill 0 su 3, marcatore 0 su 3"
  expect "controllo: con il flag" 0 \
    "con il flag: Skill 0 su 3, marcatore 0 su 3"
  expect "controllo: /prova-d02" 0 \
    "/prova-d02 con il flag: marcatore 3 su 3, corpo nello stream 0 su 3"
  expect "controllo: una riga per esecuzione" 0 "specifica        sì   sì   sì"
  expect "controllo: la near-miss resta un dato, e dice perché" 0 \
    "Near-miss, come dato: Skill 0 su 3; una near-miss non dovrebbe far\
 scattare la skill"
  expect "controllo: la garanzia" 0 "${S_FLAG}: confermata 3 su 3"
  expect "controllo: /prova-d02 sotto il flag" 0 "${S_NOME}: confermata 3 su 3"
  expect "controllo: la prima richiesta, come dato" 0 \
    "esecuzione 1: vaga 17.050, specifica 17.050, near-miss 17.050, con il\
 flag 17.000"
  expect_absent "controllo: nessuna segnalazione" "SEGNALAZIONE"
  expect_absent "controllo: nessun «non confermata»" "${NONCONF}"
  expect_absent "controllo: nessuna altra skill" "Altre skill"
  expect_absent "controllo: la frase finale è della verifica" "Fatto:"
  nuova_serie j 1
  controlla "${j}"
  expect "controllo: un'esecuzione sola basta" 0 \
    "confermata (1 su 1 contro 0 su 1)"
}

# I verdetti che cambiano: mai un'uscita diversa da 0 per il confronto o per la
# near-miss.
t_verdetti() {
  local j n
  nuova_serie j 3
  for n in 1 2 3; do
    rifai "${j}" "specifica-${n}" FINTO_NON_CHIAMA=1
  done
  controlla "${j}"
  expect "verdetti: lo stesso conteggio, non distinguibile, uscita 0" 0 \
    "${NONDIST} (0 su 3 e 0 su 3)"
  for n in 1 2; do
    rifai "${j}" "vaga-${n}" FINTO_SKILL_SEMPRE="${NOME_SKILL}"
  done
  controlla "${j}"
  expect "verdetti: la vaga sopra la specifica, non confermata, uscita 0" 0 \
    "${NONCONF} (0 su 3 contro 2 su 3)"
  expect "verdetti: il marcatore è un dato che segue la chiamata" 0 \
    "vaga: Skill 2 su 3, marcatore 2 su 3"
  expect_absent "verdetti: nessuna segnalazione per il confronto" \
    "SEGNALAZIONE"
  nuova_serie j 3
  rifai "${j}" near_miss-2 FINTO_SKILL_SEMPRE="${NOME_SKILL}"
  controlla "${j}"
  expect "verdetti: una near-miss che scatta resta un dato, uscita 0" 0 \
    "Near-miss, come dato: Skill 1 su 3"
  expect_absent "verdetti: nessuna segnalazione per la near-miss" \
    "SEGNALAZIONE"
}

# La garanzia del flag e /prova-d02: uscita 1 se non reggono.
t_garanzia() {
  local j v
  nuova_serie j 3
  rifai "${j}" manuale-2 FINTO_SKILL_SEMPRE="${NOME_SKILL}"
  controlla "${j}"
  expect "garanzia: con il flag una chiamata riuscita, uscita 1" 1 \
    "SEGNALAZIONE manuale-2: Claude ha invocato prova-d02 da solo"
  expect "garanzia: il riepilogo" 1 "${S_FLAG}: ${NONCONF} (manuale-2)"
  nuova_serie j 1
  rifai "${j}" manuale_nome-1 FINTO_SKILL_SEMPRE="${NOME_SKILL}"
  controlla "${j}"
  expect "garanzia: una chiamata anche nella prova con /prova-d02, uscita 1" 1 \
    "SEGNALAZIONE manuale_nome-1: Claude ha invocato prova-d02 da solo"
  for v in errore permesso; do
    nuova_serie j 1
    rifai "${j}" manuale-1 FINTO_SKILL_SEMPRE="${NOME_SKILL}" \
      FINTO_RIFIUTA="${v}"
    controlla "${j}"
    expect "garanzia: tentata e rifiutata (${v}), uscita 0" 0 \
      "manuale-1: tentata e rifiutata"
    expect_absent "garanzia: tentata e rifiutata (${v}), nessuna segnalazione" \
      "SEGNALAZIONE"
  done
  nuova_serie j 1
  rifai "${j}" manuale-1 FINTO_SKILL_SEMPRE=code-review
  controlla "${j}"
  expect "garanzia: un'altra skill non è la garanzia, uscita 0" 0 \
    "Altre skill chiamate, come dato: manuale-1: code-review"
  expect_absent "garanzia: un'altra skill, nessuna segnalazione" "SEGNALAZIONE"
  nuova_serie j 1
  rifai "${j}" manuale_nome-1 FINTO_NOME_VUOTO=1
  controlla "${j}"
  expect "/prova-d02: zero turni, uscita 1" 1 "SEGNALAZIONE manuale_nome-1"
  expect "/prova-d02: il riepilogo" 1 "${S_NOME}: ${NONCONF} (manuale_nome-1)"
  nuova_serie j 1
  rifai "${j}" manuale_nome-1 FINTO_NOME_SENZA_MARCATORE=1
  controlla "${j}"
  expect "/prova-d02: né marcatore né corpo, uscita 1" 1 \
    "SEGNALAZIONE manuale_nome-1: né il marcatore né il corpo"
  nuova_serie j 1
  rifai "${j}" manuale_nome-1 FINTO_NOME_SINTETICO=1
  controlla "${j}"
  expect "/prova-d02: il corpo nello stream basta, uscita 0" 0 \
    "/prova-d02 con il flag: marcatore 0 su 1, corpo nello stream 1 su 1"
  expect_absent "/prova-d02: il corpo arrivato, nessuna segnalazione" \
    "SEGNALAZIONE"
  for v in vaga specifica near_miss manuale manuale_nome; do
    nuova_serie j 1
    rifai "${j}" "${v}-1" FINTO_SENZA_SKILL_INIT=1
    controlla "${j}"
    expect "segnalazione: ${v} senza la skill nell'elenco, uscita 1" 1 \
      "SEGNALAZIONE ${v}-1: prova-d02 non è fra le skill"
  done
}

# Gli stream che mancano o non si leggono: uscita 2, mai un conteggio più
# piccolo né un traceback.
t_illeggibili() {
  local j v
  nuova_serie j 2
  rm -- "${j}/near_miss-2.jsonl" "${j}/manuale_nome-1.jsonl"
  controlla "${j}"
  expect "illeggibile: uno stream che manca, uscita 2" 2 "near_miss-2.jsonl"
  expect "illeggibile: li dice tutti" 2 "manuale_nome-1.jsonl"
  expect_absent "illeggibile: nessun verdetto a metà" "confermata"
  nuova_serie j 1
  : > "${j}/vaga-1.jsonl"
  controlla "${j}"
  expect "illeggibile: uno stream vuoto, uscita 2" 2 "vaga-1.jsonl è vuoto"
  for v in "FINTO_RIGA_ROTTA=1:non è JSON" \
      "FINTO_TRONCO=1:non finisce con il risultato" \
      "FINTO_ERRORE=1:un errore" "FINTO_SENZA_INIT=1:system/init" \
      "FINTO_INIT_SENZA_ELENCO=1:system/init"; do
    nuova_serie j 1
    rifai "${j}" manuale-1 "${v%%:*}"
    controlla "${j}"
    expect "illeggibile: ${v%%=*}, uscita 2" 2 "${v#*:}"
  done
  nuova_serie j 1
  printf '\xff\xfe non è UTF-8\n' > "${j}/manuale-1.jsonl"
  controlla "${j}"
  expect "illeggibile: non è UTF-8, uscita 2" 2 "non si legge"
  nuova_serie j 1
  if (( EUID != 0 )); then
    chmod 000 "${j}/manuale-1.jsonl"
    controlla "${j}"
    expect "illeggibile: un file senza permessi, uscita 2" 2 "non si legge"
    chmod 644 "${j}/manuale-1.jsonl"
  else
    skip "illeggibile: un file senza permessi (da root si legge)"
  fi
  j="$(mktemp -d "${TMP}/json.XXXXXX")" || exit 2
  controlla "${j}"
  expect "illeggibile: una cartella senza stream, uscita 2" 2 "nessuno stream"
  controlla "${TMP}/non_esiste"
  expect "illeggibile: una cartella che non c'è, uscita 2" 2 "non esiste"
  controlla
  expect "illeggibile: senza argomenti, uscita 2" 2 "Uso:"
  controlla "${j}" "${j}"
  expect "illeggibile: due cartelle, uscita 2" 2 "Uso:"
  controlla --boh
  expect "illeggibile: un'opzione sconosciuta, uscita 2" 2 "Uso:"
}

# --- verifica.sh ------------------------------------------------------------

t_verifica() {
  local w j
  run "${D02}/verifica.sh"
  expect "verifica: senza argomenti, uscita 2" 2 "spazio di lavoro assente"
  run "${D02}/verifica.sh" "${TMP}/non_esiste"
  expect "verifica: uno spazio che non c'è, uscita 2" 2 \
    "spazio di lavoro assente"
  nuovo_ws w || { fail "verifica: nessuno spazio di lavoro"; return 0; }
  run env PATH="${TMP}/senza_python" "${D02}/verifica.sh" "${w}"
  expect "verifica: senza python3, uscita 2" 2 "manca python3"
  run "${D02}/verifica.sh" "${w}"
  expect "verifica: senza risposte/, uscita 1" 1 "Manca la cartella risposte/"
  mkdir -p "${w}/risposte"
  run "${D02}/verifica.sh" "${w}"
  expect "verifica: risposte/ vuota, uscita 1" 1 "nessuno stream"
  rmdir "${w}/risposte"
  nuova_serie j 3
  cp -R "${j}" "${w}/risposte"
  run "${D02}/verifica.sh" "${w}"
  expect "verifica: gli stream ci sono, uscita 0" 0 "${FATTO}"
  expect "verifica: stampa i verdetti" 0 "${S_FLAG}: confermata 3 su 3"
  rifai "${w}/risposte" specifica-1 FINTO_NON_CHIAMA=1
  rifai "${w}/risposte" specifica-2 FINTO_NON_CHIAMA=1
  rifai "${w}/risposte" specifica-3 FINTO_NON_CHIAMA=1
  run "${D02}/verifica.sh" "${w}"
  expect "verifica: un confronto non distinguibile non la ferma" 0 "${FATTO}"
  rifai "${w}/risposte" manuale-3 FINTO_SKILL_SEMPRE="${NOME_SKILL}"
  run "${D02}/verifica.sh" "${w}"
  expect "verifica: la garanzia non regge, uscita 1" 1 "SEGNALAZIONE manuale-3"
  expect_absent "verifica: niente «Fatto» con una segnalazione" "Fatto:"
  printf 'import sys\nsys.exit(0)\n' > "${w}/controlla_descrizione.py"
  run "${D02}/verifica.sh" "${w}"
  expect "verifica: il controllo dell'elemento, non quello dello spazio" 1 \
    "SEGNALAZIONE manuale-3"
  rm -- "${w}/risposte/near_miss-2.jsonl"
  rifai "${w}/risposte" manuale-3
  run "${D02}/verifica.sh" "${w}"
  expect "verifica: uno stream che manca, uscita 2" 2 "near_miss-2.jsonl"
}

# --- demo/in_classe.sh e _docente/live.sh -----------------------------------

t_live_precondizioni() {
  local w ic="${D02}/demo/in_classe.sh" chiave
  nuovo_ws w || { fail "live: nessuno spazio di lavoro"; return 0; }
  precondizione "in classe: uno spazio che non c'è" "spazio di lavoro assente" \
    "${ic}" "${TMP}/non_esiste"
  precondizione "in classe: senza claude" "manca lo strumento: claude" \
    "${ic}" "${w}" "${TMP}/senza_claude"
  precondizione "in classe: senza python3" "manca lo strumento: python3" \
    "${ic}" "${w}" "${TMP}/senza_python"
  precondizione "in classe: PN_ESECUZIONI=0" "PN_ESECUZIONI" \
    "${ic}" "${w}" "" PN_ESECUZIONI=0
  precondizione "in classe: HANDSON_ENV sbagliato" "claude-code-pro" \
    "${ic}" "${w}" "" HANDSON_ENV=trainer-api
  precondizione "in classe: bypassPermissions" "modalità di permesso" \
    "${ic}" "${w}" "" HANDSON_PERMISSION_MODE=bypassPermissions
  precondizione "in classe: PN_LIVE_JSON dentro lo spazio" "non stanno" \
    "${ic}" "${w}" "" PN_LIVE_JSON="${w}/dentro"
  mkdir -p "${TMP}/vecchi"
  : > "${TMP}/vecchi/vaga-1.jsonl"
  precondizione "in classe: una prova che c'è già" "c'è già una prova" \
    "${ic}" "${w}" "" PN_LIVE_JSON="${TMP}/vecchi"
  rm -- "${w}/richiesta.txt"
  precondizione "in classe: un file che manca" "richiesta.txt" "${ic}" "${w}"
  git -C "${w}" checkout -q -- richiesta.txt
  : > "${w}/sporco.txt"
  precondizione "in classe: non al punto di partenza" "punto di partenza" \
    "${ic}" "${w}"
  rm -- "${w}/sporco.txt"
  rm -rf -- "${w}/.git"
  precondizione "in classe: non è un repository git" "repository git" \
    "${ic}" "${w}"
  nuovo_ws w || return 0
  chiave="sk-ant""-finta"
  printf 'Controlla. %s\n' "${chiave}" > "${w}/richiesta.txt"
  git -C "${w}" -c user.name=Prova -c user.email=prova@example.org \
    commit -q -am 'richiesta con una chiave' || true
  precondizione "in classe: una chiave API nella richiesta" \
    "sembra una chiave API" "${ic}" "${w}"
  expect_absent "in classe: la chiave non si stampa" "${chiave}"
  nuovo_ws w || return 0
  run env PATH="${TMP}/esca:${PATH}" ESCA_LOG="${TMP}/esca.log" \
    HANDSON_NO_PAUSE=1 "${w}/in_classe.sh" "${w}"
  expect "in classe: dalla copia nello spazio, senza il repository" 2 \
    "lib_handson.sh"
  precondizione "live: uno spazio che non c'è" "spazio di lavoro assente" \
    "${D02}/_docente/live.sh" "${TMP}/non_esiste"
  run "${D02}/_docente/live.sh"
  expect "live: senza argomenti, uscita 2" 2 "uso:"
}

t_live_finto() {
  local w ic="${D02}/demo/in_classe.sh" n
  nuovo_ws w || { fail "live: nessuno spazio di lavoro"; return 0; }
  finto "${D02}/_docente/live.sh" "${w}"
  expect "live: tre esecuzioni, uscita 0" 0 \
    "confermata (3 su 3 contro 0 su 3)"
  expect "live: il comando si vede" 0 "claude -p"
  expect "live: il verdetto OK" 0 "VERIFICA OK"
  controlla_chiamate "${TMP}/finto.log" "${w}" 3
  expect "live: quindici chiamate, ognuna da una cartella nuova" 0 \
    "chiamate giuste"
  n="$(command find "${w}/risposte" -name '*.jsonl' | wc -l)"
  if (( n == 15 )); then
    pass "live: quindici stream in risposte/"
  else
    fail "live: ${n} stream in risposte/"
  fi
  n="$(command find "${w}.prova_dal_vivo" -name '*.jsonl' | wc -l)"
  if (( n == 15 )); then
    pass "live: quindici stream fuori dallo spazio di lavoro"
  else
    fail "live: ${n} stream in ${w}.prova_dal_vivo"
  fi
  run "${RADICE}/tools/verifica.sh" M5-D02 --radice "${w%/*}"
  expect "live: dopo la prova la verifica passa" 0 "${FATTO}"
  nuovo_ws w || return 0
  finto "${ic}" "${w}"
  expect "in classe: un'esecuzione, uscita 0" 0 \
    "confermata (1 su 1 contro 0 su 1)"
  controlla_chiamate "${TMP}/finto.log" "${w}" 1
  expect "in classe: cinque chiamate" 0 "chiamate giuste"
  nuovo_ws w || return 0
  finto "${ic}" "${w}" PN_ESECUZIONI=2 PN_LIVE_JSON="${TMP}/altrove"
  expect "in classe: PN_ESECUZIONI=2" 0 "confermata (2 su 2 contro 0 su 2)"
  vero "in classe: PN_LIVE_JSON, gli stream lì" \
    test -s "${TMP}/altrove/manuale_nome-2.jsonl"
  nuovo_ws w || return 0
  finto "${w}/in_classe.sh" "${w}" PN_HANDSON_ROOT="${RADICE}"
  expect "in classe: dalla copia nello spazio, con PN_HANDSON_ROOT" 0 \
    "confermata (1 su 1 contro 0 su 1)"
}

t_live_esiti() {
  local w ic="${D02}/demo/in_classe.sh" n
  nuovo_ws w || { fail "live: nessuno spazio di lavoro"; return 0; }
  finto "${ic}" "${w}" FINTO_ESITO_KO_SE="Quante righe"
  n="$(grep -c 'Quante righe' "${TMP}/finto.log")"
  if (( RC == 1 )) && (( n == 1 )) && grep -qF 'VERIFICA KO' <<< "${OUT}" \
      && [[ -s "${w}/risposte/specifica-1.jsonl" ]]; then
    pass "in classe: si ferma alla chiamata fallita, gli altri in risposte/"
  else
    fail "in classe: chiamata fallita: rc=${RC}, ${n}: ${OUT:0:300}"
  fi
  nuovo_ws w || return 0
  finto "${ic}" "${w}" FINTO_SKILL_SEMPRE="${NOME_SKILL}"
  expect "in classe: la garanzia non regge, uscita 1" 1 "VERIFICA KO"
  expect "in classe: e la segnalazione si vede" 1 "SEGNALAZIONE manuale-1"
  nuovo_ws w || return 0
  finto "${ic}" "${w}" FINTO_TRONCO=1
  expect "in classe: stream che non si leggono, uscita 2" 2 \
    "non finisce con il risultato"
}

# Il README e la registrazione: le righe che cita sono quelle che verifica.sh
# stampa sugli stream di soluzione/.
t_registrazione() {
  local w uscita="${TMP}/uscita.txt"
  nuovo_ws w || { fail "registrazione: lo spazio di lavoro"; return 0; }
  cp -R "${D02}/soluzione/." "${w}/" || exit 2
  run "${D02}/verifica.sh" "${w}"
  expect "registrazione: verifica.sh su soluzione/, uscita 0" 0 "${FATTO}"
  printf '%s\n' "${OUT}" > "${uscita}"
  run python3 -B -I "${MOD}/_docente/controlla_registrazione.py" \
    "${D02}/README.md" "${uscita}" <<'FRASI'
= vaga: Skill 0 su 3, marcatore 0 su 3
= specifica: Skill 3 su 3, marcatore 3 su 3
= near-miss: Skill 0 su 3, marcatore 0 su 3
= con il flag: Skill 0 su 3, marcatore 0 su 3
= Specifica contro vaga, «vague descriptions reduce triggering accuracy»: confermata (3 su 3 contro 0 su 3)
= Con il flag, «Claude can't invoke the skill on its own»: confermata 3 su 3
= /prova-d02 con il flag, «Include /skill-name in the prompt string»: confermata 3 su 3
= marcatore 3 su 3, corpo nello stream 0 su 3
= Near-miss, come dato: Skill 0 su 3
= vaga 7.141, specifica 7.192, near-miss 7.174, con il flag 7.128
R Nella registrazione del corso (3 novembre 2026, Claude Code 2.1.317, Sonnet con effort low, tre esecuzioni
R sull'account del docente, un piano Max
R Specify the list of available tools from the built-in set.
R il proprietario di un file
R 245.268
! <!-- registrazione
! si aggiunge qui
! pochi turni del modello attesi
FRASI
  expect "registrazione: il README cita le righe del controllo" 0 "in ordine"
}

# Gli script di M5-D02 e questo file, con shellcheck -x.
t_shellcheck() {
  local f
  for f in "${D02}/verifica.sh" "${D02}/_docente/live.sh" \
      "${D02}/demo/in_classe.sh" "${D02}/demo/prepara_braccio.sh" "${SELF}"; do
    if [[ -f "${f}" ]] \
        && ( cd "${RADICE}" && shellcheck -x -- "${f}" ) > /dev/null 2>&1; then
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
      || { echo "test_m5_d02: manca ${t}" >&2; exit 2; }
  done
  [[ -f "${FINTO_PY}" ]] \
    || { echo "test_m5_d02: manca ${FINTO_PY}" >&2; exit 2; }
  handson::init_temp_base
  TMP="$(mktemp -d "${HANDSON_TEMP_BASE}/test_m5_d02.XXXXXX")" || exit 2
  trap 'chmod -R u+rwX "${TMP}" 2>/dev/null; rm -rf "${TMP}"' EXIT
  prepara_claude
  t_elemento
  t_readme
  t_prepara
  t_bracci
  t_complete
  t_verdetti
  t_garanzia
  t_illeggibili
  t_verifica
  t_live_precondizioni
  t_live_finto
  t_live_esiti
  t_registrazione
  t_shellcheck
  OUT="${TUTTO}"
  expect_absent "in nessuna uscita «smentita»" "smentita"
  expect_absent "in nessuna uscita un traceback" "Traceback"
  echo "PASS=${PASS} FAIL=${FAIL} SKIP=${SKIP}"
  if (( PASS + FAIL + SKIP != CASES )); then
    echo "test_m5_d02: girati $((PASS + FAIL + SKIP)) casi, attesi" \
      "${CASES}" >&2
    exit 2
  fi
  (( FAIL == 0 )) || exit 1
}

main "$@"
