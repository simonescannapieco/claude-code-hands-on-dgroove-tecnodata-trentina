#!/bin/bash
#
# test_m5_d05.sh -- le prove di M5-D05 «La stessa skill in claude.ai», per il
# docente (sta in _docente/, il materiale del docente):
#   - l'elemento: i file, la richiesta della chat, nessuna skill in demo/; il
#     README: le dieci sezioni, le frasi di Anthropic con il loro indirizzo, la
#     pulizia per ultima, nessun nome interno;
#   - impacchetta.sh: i tre ZIP, la cartella al primo livello, niente evals/, il
#     settimo campo in uno solo, i tag XML in uno solo, lo stesso risultato a ogni
#     esecuzione, nessuno zip di sistema; le precondizioni (2);
#   - controlla.sh: gli esiti attesi, una dimostrazione, senza dire che cosa farà
#     il sito; ZIP scambiati (1); le precondizioni (2);
#   - verifica.sh: il punto di partenza (1); i tre ZIP (0); ogni ZIP sbagliato
#     (1); la risposta copiata, come dati (0), vuota (1), non UTF-8 (2);
#   - _docente/live.sh senza mai chiamare claude; soluzione/applica.sh con
#     tools/run_all.sh;
#   - shellcheck -x sugli script.
# Nessuna chiamata al modello: un'esca al posto di claude lo prova. Gli spazi di
# lavoro nascono in una cartella temporanea, nella base di
# handson::init_temp_base (mai dentro ~/.claude). CASES è il numero dei casi: se
# ne girano di più o di meno la suite esce 2.
#
# Uso:    m5_skills/_docente/test_m5_d05.sh
# Uscita: 0 = tutti i casi passano · 1 = almeno un caso fallito · 2 =
#         precondizione (manca python3, git o shellcheck), o un numero di casi
#         diverso da CASES
set -uo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly MOD="${SELF%/_docente/*}"
readonly RADICE="${MOD%/*}"
ITEM="${MOD}/s4_skills/m5_e4_stessa_skill_claude_ai"
ITEM+="/M5-D05_stessa_skill_claude_ai"
readonly ITEM
readonly SKILL_DIR="${RADICE}/riferimenti/skill-di-esempio/risposta-assistenza"
readonly ZIP1=risposta-assistenza.zip
readonly ZIP2=risposta-assistenza-settimo-campo.zip
readonly ZIP3=risposta-assistenza-tag-xml.zip
readonly ERRORE_XML='ERRORE description: niente tag XML'
MESSAGGIO='Unexpected key(s) in SKILL.md frontmatter: argument-hint. Allowed'
MESSAGGIO+=' properties are: allowed-tools, compatibility, description,'
MESSAGGIO+=' license, metadata, name'
readonly MESSAGGIO
# shellcheck source=../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"
readonly CASES=87
TMP=''
PASS=0
FAIL=0
RC=0
OUT=''

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

# Esegue un comando; RC e OUT (STDOUT e STDERR insieme) per expect.
run() { OUT="$("$@" 2>&1)"; RC=$?; }

# Uscita attesa E parola chiave attesa (RU-01.T3).
# Arguments: $1 il nome, $2 l'uscita attesa, $3 la parola (grep -F).
expect() {
  if (( RC == $2 )) && grep -qF -- "$3" <<< "${OUT}"; then
    pass "$1"
  else
    fail "$1 (rc=${RC}, attesa $2, parola «$3»): ${OUT:0:700}"
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

# Uno spazio di lavoro nuovo. Arguments: $1 la variabile da assegnare.
# Returns: 0; 1 se prepara_esercizio.sh non riesce.
nuovo_ws() {
  local __r
  __r="$(mktemp -d "${TMP}/radice.XXXXXX")" || exit 2
  "${RADICE}/tools/prepara_esercizio.sh" M5-D05 --radice "${__r}" \
    > "${TMP}/prepara.log" 2>&1 || return 1
  printf -v "$1" '%s' "${__r}/M5-D05"
}

# I tre ZIP in uno spazio di lavoro, con lo script dell'elemento.
# Arguments: $1 lo spazio di lavoro.
impacchetta() {
  ( cd "$1" && PN_HANDSON_ROOT="${RADICE}" ./impacchetta.sh pacchetti ) \
    > /dev/null 2>&1 \
    || { echo "test_m5_d05: impacchetta fallisce" >&2; exit 2; }
}

# Rifà uno ZIP con le regole date, in Python. Arguments: $1 lo ZIP, $2 che cosa
# cambiare: alla_radice, con_evals.
rifai_zip() {
  python3 -B -I - "$1" "$2" <<'PY' || exit 2
import sys, zipfile
percorso, modo = sys.argv[1:3]
with zipfile.ZipFile(percorso) as zf:
    voci = [(n, zf.read(n)) for n in zf.namelist()]
with zipfile.ZipFile(percorso, "w") as zf:
    for nome, dati in voci:
        if modo == "alla_radice":
            nome = nome.split("/", 1)[1]
        zf.writestr(nome, dati)
    if modo == "con_evals":
        zf.writestr("risposta-assistenza/evals/evals.json", b"{}")
PY
}

# verifica.sh su uno spazio di lavoro; RC e OUT come run.
verifica() {
  run env PN_HANDSON_ROOT="${RADICE}" "${ITEM}/verifica.sh" "$1"
}

t_elemento() {
  local f
  for f in README.md verifica.sh verifica.py demo/impacchetta.sh \
      demo/impacchetta.py demo/controlla.sh demo/richiesta.txt \
      _docente/live.sh soluzione/LEGGIMI.md soluzione/applica.sh; do
    vero "elemento: ${f}" test -f "${ITEM}/${f}"
  done
  for f in verifica.sh demo/impacchetta.sh demo/controlla.sh \
      _docente/live.sh soluzione/applica.sh; do
    vero "elemento: ${f} eseguibile" test -x "${ITEM}/${f}"
  done
  run command find "${ITEM}/demo" -name 'SKILL.md'
  if [[ -z "${OUT}" ]]; then
    pass "elemento: nessuna skill in demo/"
  else
    fail "elemento: una skill in demo/: ${OUT}"
  fi
  run python3 -B -I - "${ITEM}/demo/richiesta.txt" "${SKILL_DIR}" <<'PY'
import json, os, sys
testo = open(sys.argv[1], encoding="utf-8").read().strip()
casi = json.load(open(os.path.join(sys.argv[2], "evals", "evals.json"),
                      encoding="utf-8"))["evals"]
buona = testo.startswith("Rispondi") and "<" not in testo \
    and not any(testo == caso["prompt"] for caso in casi) \
    and "Rifugio Campione" not in testo
print("richiesta giusta" if buona else repr(testo))
PY
  expect "elemento: la richiesta, naturale e non del laboratorio" 0 \
    "richiesta giusta"
}

t_readme() {
  run python3 -B -I - "${ITEM}/README.md" <<'PY'
import sys
testo = " ".join(open(sys.argv[1], encoding="utf-8").read().split())
FRASI = (
    "If you include any field the spec doesn't allow, packaging or upload "
    "fails with a hard error instead of ignoring the field",
    "Unexpected key(s) in SKILL.md frontmatter: argument-hint. Allowed "
    "properties are: allowed-tools, compatibility, description, license, "
    "metadata, name",
    "claude.ai skill uploads, the Skills API, and packaging with "
    "package_skill.py from anthropics/skills",
    "https://code.claude.com/docs/en/skills",
    "ALLOWED_PROPERTIES = {'name', 'description', 'license', 'allowed-tools', "
    "'metadata', 'compatibility'}",
    "https://raw.githubusercontent.com/anthropics/skills/main/skills/"
    "skill-creator/scripts/quick_validate.py",
    "The ZIP must contain the skill directory itself as its top level, "
    "because Claude looks for <skill-name>/SKILL.md inside the archive",
    "https://claude.com/docs/skills/how-to",
    "Claude Code-only body features, such as dynamic context injection, don't "
    "function in claude.ai chat or through the API.",
    "This feature requires code execution to be enabled.",
    "You can enable example skills and upload your own in Customize > Skills.",
    "To add custom skills, click the \"+\" button, then \"+ Create skill.\"",
    "https://support.claude.com/en/articles/12512180-use-skills-in-claude",
    "«ZIP file exceeds size limits»",
    "«Skill folder name doesn't match the skill name»",
    "«Missing required skill.md file»",
    "«Invalid characters in skill name or description»",
    "«Must be non-empty»",
    "«Maximum 1,024 characters»",
    "«Cannot contain XML tags»",
    "«SKILL.md description cannot contain XML tags»",
    "«Zip must contain a SKILL.md file»",
    "«+ Add»",
    "«Upload skill»",
    "«Upload and replace»",
    "«Create and edit files»",
    "Loaded skill",
    "Check the frontmatter against the Agent Skills specification with the "
    "skills-ref reference tool",
    "A skill that passes prints Valid skill: ./my-skill. Otherwise the command "
    "lists each problem",
    "«VERIFICA OK M5-D05: fatto.»",
    "On all other plans, each person uploads skills to their own account.",
    "To see which skills synced, run /skills. The menu lists them under "
    "claude.ai sync.",
    "perché non torni nel vostro terminale con lo stesso account",
)
mancanti = [f for f in FRASI if f not in testo]
print("mancano: %r" % mancanti if mancanti else "frasi tutte presenti")
PY
  expect "README: le frasi, con l'indirizzo" 0 "frasi tutte presenti"
  run cat -- "${ITEM}/README.md"
  assente "README: nessuna smentita" "smentita"
  assente "README: nessuna riga del registro" "FACT-"
  assente "README: nessuna decisione interna" "M5-X"
  assente "README: nessun percorso personale" "/home/"
  run python3 -B -I - "${ITEM}/README.md" <<'PY'
import re, sys
testo = open(sys.argv[1], encoding="utf-8").read()
sezione = testo.split("## Passi")[1].split("\n## ")[0]
numeri = re.findall(r"(?m)^(\d+)\. \*\*([^*]+)\*\*", sezione)
print("ultimo: %s" % numeri[-1][1] if numeri else "nessun passo")
PY
  expect "README: la rimozione è l'ultimo passo" 0 "ultimo: La pulizia"
  run "${RADICE}/tools/check_handson.sh"
  if grep -q 'M5-D05\|m5_e4_stessa_skill' <<< "${OUT}"; then
    fail "check_handson: una segnalazione su M5-D05: ${OUT:0:500}"
  else
    pass "check_handson: nessuna segnalazione su M5-D05"
  fi
}

t_impacchetta_precondizioni() {
  local d
  d="$(mktemp -d "${TMP}/d.XXXXXX")" || exit 2
  run env -u PN_HANDSON_ROOT "${ITEM}/demo/impacchetta.sh" "${d}"
  expect "impacchetta: senza PN_HANDSON_ROOT (2)" 2 "PN_HANDSON_ROOT"
  run env PN_HANDSON_ROOT="${RADICE}" "${ITEM}/demo/impacchetta.sh"
  expect "impacchetta: senza la cartella (2)" 2 "Uso:"
  : > "${d}/un-file"
  run env PN_HANDSON_ROOT="${RADICE}" "${ITEM}/demo/impacchetta.sh" \
    "${d}/un-file"
  expect "impacchetta: un file al posto della cartella (2)" 2 "un-file"
  run env PN_HANDSON_ROOT="${TMP}" "${ITEM}/demo/impacchetta.sh" "${d}"
  expect "impacchetta: un repository senza la skill (2)" 2 "PN_HANDSON_ROOT"
  run env PATH="${TMP}/senza_python" PN_HANDSON_ROOT="${RADICE}" \
    "${ITEM}/demo/impacchetta.sh" "${d}"
  expect "impacchetta: senza python3 (2)" 2 "python3"
}

t_impacchetta() {
  local d primo
  d="$(mktemp -d "${TMP}/d.XXXXXX")" || exit 2
  : > "${TMP}/zip.log"
  run env PATH="${TMP}/esca_zip:${PATH}" ZIP_LOG="${TMP}/zip.log" \
    PN_HANDSON_ROOT="${RADICE}" "${ITEM}/demo/impacchetta.sh" "${d}/nuova"
  expect "impacchetta: i tre ZIP (0)" 0 "${ZIP3}"
  vero "impacchetta: nessuno zip di sistema" test ! -s "${TMP}/zip.log"
  run python3 -B -I - "${d}/nuova" "${SKILL_DIR}" <<'PY'
import os, sys, zipfile
cartella, sorgente = sys.argv[1:3]
TOP = "risposta-assistenza/"
problemi = []
def voci(nome):
    with zipfile.ZipFile(os.path.join(cartella, nome)) as zf:
        return {n: zf.read(n) for n in zf.namelist()}
uno = voci("risposta-assistenza.zip")
due = voci("risposta-assistenza-settimo-campo.zip")
attesi = set()
for radice, cartelle, nomi in os.walk(sorgente):
    if radice == sorgente:
        cartelle[:] = [c for c in cartelle if c != "evals"]
    for nome in nomi:
        pieno = os.path.join(radice, nome)
        attesi.add(TOP + os.path.relpath(pieno, sorgente))
if set(uno) != attesi:
    problemi.append("i file del primo: %r" % (set(uno) ^ attesi))
if set(due) != attesi:
    problemi.append("i file del secondo: %r" % (set(due) ^ attesi))
for nome, dati in uno.items():
    with open(os.path.join(sorgente, nome[len(TOP):]), "rb") as fh:
        if fh.read() != dati:
            problemi.append("%s non è uguale al sorgente" % nome)
for nome in uno:
    if nome != TOP + "SKILL.md" and uno[nome] != due[nome]:
        problemi.append("%s cambia nel secondo" % nome)
righe_uno = uno[TOP + "SKILL.md"].decode().split("\n")
righe_due = due[TOP + "SKILL.md"].decode().split("\n")
in_piu = [r for r in righe_due if r not in righe_uno]
if len(righe_due) != len(righe_uno) + 1 or len(in_piu) != 1 \
        or not in_piu[0].startswith("argument-hint: "):
    problemi.append("il settimo campo: %r" % in_piu)
if righe_due.index(in_piu[0]) >= righe_due.index("---", 1):
    problemi.append("il settimo campo non sta nel frontmatter")
if "name: risposta-assistenza" not in righe_due:
    problemi.append("il nome della skill è cambiato")
tre = voci("risposta-assistenza-tag-xml.zip")
if set(tre) != attesi:
    problemi.append("i file del terzo: %r" % (set(tre) ^ attesi))
for nome in uno:
    if nome != TOP + "SKILL.md" and uno[nome] != tre[nome]:
        problemi.append("%s cambia nel terzo" % nome)
righe_tre = tre[TOP + "SKILL.md"].decode().split("\n")
diverse = [(a, b) for a, b in zip(righe_uno, righe_tre) if a != b]
if len(righe_tre) != len(righe_uno) or len(diverse) != 1:
    problemi.append("il terzo non cambia in una riga sola: %r" % diverse)
else:
    prima, dopo = diverse[0]
    testo = prima[len("description: "):]
    if not prima.startswith("description: ") \
            or dopo != "description: <scopo>%s</scopo>" % testo:
        problemi.append("i tag XML del terzo: %r" % dopo)
print("; ".join(problemi) or "pacchetti giusti")
PY
  expect "impacchetta: la forma dei tre ZIP" 0 "pacchetti giusti"
  primo="$(sha256sum "${d}/nuova/${ZIP1}" "${d}/nuova/${ZIP2}" \
    "${d}/nuova/${ZIP3}")" || exit 2
  run env PN_HANDSON_ROOT="${RADICE}" "${ITEM}/demo/impacchetta.sh" "${d}/nuova"
  expect "impacchetta: una seconda volta (0)" 0 "${ZIP1}"
  if [[ "${primo}" == "$(sha256sum "${d}/nuova/${ZIP1}" \
      "${d}/nuova/${ZIP2}" "${d}/nuova/${ZIP3}")" ]]; then
    pass "impacchetta: lo stesso risultato a ogni esecuzione"
  else
    fail "impacchetta: gli ZIP cambiano da un'esecuzione all'altra"
  fi
}

t_controlla() {
  local d
  d="$(mktemp -d "${TMP}/d.XXXXXX")" || exit 2
  run env PN_HANDSON_ROOT="${RADICE}" "${ITEM}/demo/impacchetta.sh" "${d}"
  run env PN_HANDSON_ROOT="${RADICE}" "${ITEM}/demo/controlla.sh" "${d}"
  expect "controlla: i tre esiti attesi (0)" 0 "${MESSAGGIO}"
  if grep -qF -- 'risposta-assistenza: 0 errori' <<< "${OUT}"; then
    pass "controlla: zero errori sul primo"
  else
    fail "controlla: zero errori sul primo: ${OUT:0:500}"
  fi
  if grep -qF -- 'dimostrazione' <<< "${OUT}"; then
    pass "controlla: si dice che è una dimostrazione"
  else
    fail "controlla: si dice che è una dimostrazione"
  fi
  if grep -qF -- "${ERRORE_XML}" <<< "${OUT}"; then
    pass "controlla: l'errore sui tag XML nel terzo"
  else
    fail "controlla: l'errore sui tag XML nel terzo: ${OUT:0:500}"
  fi
  assente "controlla: non dice che cosa farà il sito" "rifiut"
  run env -u PN_HANDSON_ROOT "${ITEM}/demo/controlla.sh" "${d}"
  expect "controlla: senza PN_HANDSON_ROOT (2)" 2 "PN_HANDSON_ROOT"
  run env PN_HANDSON_ROOT="${RADICE}" "${ITEM}/demo/controlla.sh"
  expect "controlla: senza la cartella (2)" 2 "Uso:"
  run env PN_HANDSON_ROOT="${RADICE}" "${ITEM}/demo/controlla.sh" \
    "${TMP}/non-c-e"
  expect "controlla: una cartella senza gli ZIP (2)" 2 "${ZIP1}"
  cp -- "${d}/${ZIP1}" "${d}/salvato.zip" || exit 2
  cp -- "${d}/${ZIP2}" "${d}/${ZIP1}" || exit 2
  run env PN_HANDSON_ROOT="${RADICE}" "${ITEM}/demo/controlla.sh" "${d}"
  expect "controlla: il settimo campo anche nel primo (1)" 1 "NON TORNA"
  cp -- "${d}/salvato.zip" "${d}/${ZIP1}" || exit 2
  cp -- "${d}/salvato.zip" "${d}/${ZIP2}" || exit 2
  run env PN_HANDSON_ROOT="${RADICE}" "${ITEM}/demo/controlla.sh" "${d}"
  expect "controlla: nessun settimo campo nel secondo (1)" 1 "NON TORNA"
  run env PN_HANDSON_ROOT="${RADICE}" "${ITEM}/demo/impacchetta.sh" "${d}"
  cp -- "${d}/salvato.zip" "${d}/${ZIP3}" || exit 2
  run env PN_HANDSON_ROOT="${RADICE}" "${ITEM}/demo/controlla.sh" "${d}"
  expect "controlla: nessun tag XML nel terzo (1)" 1 "NON TORNA"
  printf 'non è uno zip' > "${d}/${ZIP1}"
  run env PN_HANDSON_ROOT="${RADICE}" "${ITEM}/demo/controlla.sh" "${d}"
  expect "controlla: uno ZIP rotto (2)" 2 "${ZIP1}"
}

t_verifica() {
  local w
  run "${ITEM}/verifica.sh" "${TMP}/non-c-e"
  expect "verifica: spazio di lavoro assente (2)" 2 "spazio di lavoro"
  nuovo_ws w || { fail "verifica: lo spazio di lavoro non nasce"; return 0; }
  vero "prepara: impacchetta.sh eseguibile" test -x "${w}/impacchetta.sh"
  vero "prepara: controlla.sh eseguibile" test -x "${w}/controlla.sh"
  vero "prepara: la richiesta" test -f "${w}/richiesta.txt"
  vero "prepara: nessuno ZIP già pronto" test ! -e "${w}/pacchetti"
  verifica "${w}"
  expect "verifica: sul punto di partenza (1)" 1 "impacchetta.sh"
  run env PATH="${TMP}/senza_python" "${ITEM}/verifica.sh" "${w}"
  expect "verifica: senza python3 (2)" 2 "python3"
  impacchetta "${w}"
  verifica "${w}"
  expect "verifica: i tre ZIP (0)" 0 "Fatto: i tre ZIP"
  assente "verifica: non dice che cosa farà il sito" "rifiut"
  if grep -qF -- 'risposta_claude_ai.md: non c' <<< "${OUT}"; then
    pass "verifica: la prova facoltativa, senza la risposta"
  else
    fail "verifica: la prova facoltativa: ${OUT:0:500}"
  fi
  : > "${w}/risposta_claude_ai.md"
  verifica "${w}"
  expect "verifica: la risposta vuota (1)" 1 "vuoto"
  printf 'Ti scrivo a breve!! Ecco.\n' > "${w}/risposta_claude_ai.md"
  verifica "${w}"
  expect "verifica: la risposta, come dati (0)" 0 "parole da evitare: a breve"
  if grep -qF -- '| Ti scrivo a breve!! Ecco.' <<< "${OUT}"; then
    pass "verifica: il testo per una persona"
  else
    fail "verifica: il testo per una persona: ${OUT:0:500}"
  fi
  printf 'Ci sono disservizi sulla OLT.\n' > "${w}/risposta_claude_ai.md"
  verifica "${w}"
  expect "verifica: le forme della stessa parola, come in M5-E03 (0)" 0 \
    "parole da evitare: disservizi, OLT"
  local lab="${MOD}/s4_skills/m5_e2_laboratorio"
  run env PN_HANDSON_ROOT="${RADICE}" python3 -B -I - "${ITEM}/verifica.py" \
    "${lab}/M5-E03_risposta_assistenza/verifica.py" <<'PY'
import importlib.util
import sys

def carica(nome, percorso):
    spec = importlib.util.spec_from_file_location(nome, percorso)
    modulo = importlib.util.module_from_spec(spec)
    sys.modules[nome] = modulo
    spec.loader.exec_module(modulo)
    return modulo

d05 = carica("d05", sys.argv[1])
e03 = carica("e03", sys.argv[2])
uguali = d05.PAROLE_DA_EVITARE == e03.PAROLE_DA_EVITARE \
    and d05.RE_PAROLE.pattern == e03.RE_PAROLE.pattern
print("le parole di M5-E03" if uguali else "le parole diverse da M5-E03")
PY
  expect "verifica: le parole sono quelle di M5-E03" 0 "le parole di M5-E03"
  printf '\xff\xfe' > "${w}/risposta_claude_ai.md"
  verifica "${w}"
  expect "verifica: una risposta non UTF-8 (2)" 2 "UTF-8"
  rm -- "${w}/risposta_claude_ai.md"
  run env PN_HANDSON_ROOT="${RADICE}" "${RADICE}/tools/verifica.sh" M5-D05 \
    --radice "${w%/M5-D05}"
  expect "tools/verifica.sh: lo stesso esito (0)" 0 "VERIFICA OK"
  rifai_zip "${w}/pacchetti/${ZIP1}" alla_radice
  verifica "${w}"
  expect "verifica: SKILL.md alla radice dello ZIP (1)" 1 "primo livello"
  impacchetta "${w}"
  rifai_zip "${w}/pacchetti/${ZIP1}" con_evals
  verifica "${w}"
  expect "verifica: evals/ nello ZIP (1)" 1 "evals"
  impacchetta "${w}"
  printf 'non è uno zip' > "${w}/pacchetti/${ZIP2}"
  verifica "${w}"
  expect "verifica: uno ZIP rotto (1)" 1 "non è uno ZIP"
  impacchetta "${w}"
  cp -- "${w}/pacchetti/${ZIP2}" "${w}/pacchetti/${ZIP1}" || exit 2
  verifica "${w}"
  expect "verifica: il settimo campo nel primo (1)" 1 "argument-hint"
  impacchetta "${w}"
  cp -- "${w}/pacchetti/${ZIP1}" "${w}/pacchetti/${ZIP2}" || exit 2
  verifica "${w}"
  expect "verifica: nessun settimo campo nel secondo (1)" 1 "argument-hint"
  impacchetta "${w}"
  cp -- "${w}/pacchetti/${ZIP3}" "${w}/pacchetti/${ZIP1}" || exit 2
  verifica "${w}"
  expect "verifica: i tag XML nel primo (1)" 1 "non deve avere tag XML"
  impacchetta "${w}"
  cp -- "${w}/pacchetti/${ZIP1}" "${w}/pacchetti/${ZIP3}" || exit 2
  verifica "${w}"
  expect "verifica: nessun tag XML nel terzo (1)" 1 "deve avere dei tag XML"
  rm -- "${w}/pacchetti/${ZIP3}"
  verifica "${w}"
  expect "verifica: il terzo ZIP che manca (1)" 1 "${ZIP3}"
  impacchetta "${w}"
  rm -- "${w}/pacchetti/${ZIP2}"
  verifica "${w}"
  expect "verifica: uno ZIP che manca (1)" 1 "${ZIP2}"
}

t_live() {
  local w
  run "${ITEM}/_docente/live.sh"
  expect "live: senza argomenti (2), e l'uso" 2 "uso: _docente/live.sh"
  nuovo_ws w || { fail "live: lo spazio di lavoro non nasce"; return 0; }
  : > "${TMP}/esca.log"
  run env PATH="${TMP}/esca:${PATH}" ESCA_LOG="${TMP}/esca.log" \
    HANDSON_NO_PAUSE=1 "${ITEM}/_docente/live.sh" "${w}"
  expect "live: la parte locale (0)" 0 "VERIFICA OK"
  if grep -qF -- 'dimostrazione' <<< "${OUT}"; then
    pass "live: la dimostrazione si vede"
  else
    fail "live: la dimostrazione si vede: ${OUT:0:500}"
  fi
  vero "live: claude non si chiama mai" test ! -s "${TMP}/esca.log"
  vero "live: gli ZIP nello spazio di lavoro" \
    test -f "${w}/pacchetti/${ZIP3}"
  run env PATH="${TMP}/esca:${PATH}" ESCA_LOG="${TMP}/esca.log" \
    HANDSON_NO_PAUSE=1 "${ITEM}/_docente/live.sh" "${TMP}/non-c-e"
  expect "live: spazio di lavoro assente (2)" 2 "spazio di lavoro"
  run "${RADICE}/tools/run_all.sh" M5-D05
  expect "run_all: partenza e soluzione (0)" 0 "1 ok"
}

# Il README e la prova del corso: la corsa su claude.ai del 4 novembre 2026, e la
# parte locale con le righe che controlla.sh stampa.
t_registrazione() {
  local d uscita="${TMP}/uscita.txt"
  d="$(mktemp -d "${TMP}/d.XXXXXX")" || exit 2
  run env PN_HANDSON_ROOT="${RADICE}" "${ITEM}/demo/impacchetta.sh" "${d}"
  run env PN_HANDSON_ROOT="${RADICE}" "${ITEM}/demo/controlla.sh" "${d}"
  expect "registrazione: controlla.sh, i tre esiti (0)" 0 "${MESSAGGIO}"
  printf '%s\n' "${OUT}" > "${uscita}"
  run python3 -B -I "${MOD}/_docente/controlla_registrazione.py" \
    "${ITEM}/README.md" "${uscita}" <<'FRASI'
= controlla_skill: risposta-assistenza: 0 errori, 1 avviso
= controlla_skill: risposta-assistenza: 1 errore, 1 avviso
R Nella prova del corso (4 novembre 2026
R argument-hint: "[canale]"
R anthropic-skills:risposta-assistenza
! (3 novembre 2026
! Il rifiuto vero
! Il docente carica due ZIP
! un campo in più non si ignora
FRASI
  expect "registrazione: il README cita le righe del controllo" 0 "in ordine"
}

t_shellcheck() {
  local f
  for f in "${SELF}" "${ITEM}/verifica.sh" "${ITEM}/_docente/live.sh" \
      "${ITEM}/demo/impacchetta.sh" "${ITEM}/demo/controlla.sh" \
      "${ITEM}/soluzione/applica.sh"; do
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
  for t in python3 git shellcheck sha256sum; do
    command -v "${t}" >/dev/null 2>&1 \
      || { echo "test_m5_d05: manca ${t}" >&2; exit 2; }
  done
  handson::init_temp_base
  TMP="$(mktemp -d "${HANDSON_TEMP_BASE}/test_m5_d05.XXXXXX")" || exit 2
  trap 'chmod -R u+rwX "${TMP}" 2>/dev/null; rm -rf "${TMP}"' EXIT
  mkdir -p "${TMP}/esca" "${TMP}/esca_zip" "${TMP}/senza_python" || exit 2
  # shellcheck disable=SC2016  # il corpo è dell'esca
  printf '%s\n' '#!/bin/bash' \
    'printf "invocazione %s\n" "$*" >> "${ESCA_LOG}"' \
    > "${TMP}/esca/claude" || exit 2
  # shellcheck disable=SC2016  # il corpo è dell'esca
  printf '%s\n' '#!/bin/bash' \
    'printf "invocazione %s\n" "$*" >> "${ZIP_LOG}"' \
    > "${TMP}/esca_zip/zip" || exit 2
  chmod 755 "${TMP}/esca/claude" "${TMP}/esca_zip/zip" || exit 2
  ln -s "$(command -v readlink)" "${TMP}/senza_python/readlink" || exit 2
  t_elemento
  t_readme
  t_impacchetta_precondizioni
  t_impacchetta
  t_controlla
  t_verifica
  t_live
  t_registrazione
  t_shellcheck
  echo "PASS=${PASS} FAIL=${FAIL}"
  if (( PASS + FAIL != CASES )); then
    echo "test_m5_d05: girati $((PASS + FAIL)) casi, attesi ${CASES}" >&2
    exit 2
  fi
  (( FAIL == 0 )) || exit 1
}

main "$@"
