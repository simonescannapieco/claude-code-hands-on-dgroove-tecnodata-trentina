#!/bin/bash
#
# test_prove_skill.sh -- le prove di tools/prove_skill.sh, con un claude finto
# (tests/fixtures/prove_skill/claude_finto.py) davanti nel PATH e un piccolo
# albero del repository, con il suo manifest, in una cartella temporanea:
#   - ogni errore negli argomenti e nella configurazione (uscita 2, nessuna
#     chiamata);
#   - `copia` nei due modi e i suoi rifiuti: mai sopra uno SKILL.md, mai
#     evals/; il comando che stampa si incolla anche con uno spazio o un apice
#     nel percorso;
#   - `1 without`, `1 with`, `2 with` da capo a fondo: i flag, l'effort, che
#     cosa c'è nella copia (né evals/ né, in without, la skill, nemmeno nella
#     storia di git), i file scritti, la near-miss, old_skill riusato;
#   - un'esecuzione fallita: uscita 1, le altre finite; un braccio che c'è
#     già: uscita 2, con tutto ciò che va cancellato per rifarlo; un prompt con
#     virgolette, $, backtick e un a capo che arriva intatto; al massimo tre
#     insieme; nessun temporaneo lasciato;
#   - un segnale: nessuna sessione resta viva, nessun temporaneo; un giro per
#     volta sullo stesso spazio di lavoro; ciò che si può controllare fallisce
#     prima della prima chiamata (HANDSON_ENV, Skill(<skill>) negli strumenti,
#     un'esecuzione di prima fallita, un file al posto di una cartella, nessun
#     caso, pgrep che manca); la modalità di permesso è sempre dontAsk;
#   - prima.sh, verifica.py e le loro uscite; un elemento da capo a fondo con
#     tools/verifica.sh; shellcheck.
# Mai il claude vero: la suite controlla che il finto venga prima nel PATH,
# altrimenti esce 2. Gli stream del finto non sono risposte di Claude. Le
# cartelle nascono nella base di handson::init_temp_base, mai dentro ~/.claude.
#
# Uso:    tests/test_prove_skill.sh
# Uscita: 0 = tutte le prove passano · 1 = almeno una fallita ·
#         2 = precondizione (manca python3, git o shellcheck; il finto non
#         viene prima nel PATH)
# shellcheck disable=SC2016  # backtick e $ sono il testo delle prove
set -uo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly REPO="${SELF%/tests/*}"
readonly TOOL="${REPO}/tools/prove_skill.sh"
readonly LIB="${REPO}/tools/lib_prove_skill.sh"
readonly FINTO="${REPO}/tests/fixtures/prove_skill/claude_finto.py"
readonly ID=M5-E09
readonly SKILL=prova-skill
# shellcheck source=../tools/lib_handson.sh
source "${REPO}/tools/lib_handson.sh"
TMP=''
ALBERO=''
ITEM=''
RADICE=''
WS=''
LOG=''
PRIMA_LOG=''
BASE_TEMP=''
PID_FONDO=''
STDIN_PROVA=/dev/null
PASS=0
FAIL=0
RC=0
OUT=''
N=0

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

# Uscita attesa E parole attese (RU-01.T3).
# Arguments: $1 il nome, $2 l'uscita attesa, poi le parole (grep -F).
expect() {
  local nome="$1" atteso="$2" parola
  shift 2
  if (( RC != atteso )); then
    fail "${nome} (uscita ${RC}, attesa ${atteso}): ${OUT}"
    return 0
  fi
  if grep -qF -- 'Traceback' <<< "${OUT}"; then
    fail "${nome} (un traceback): ${OUT}"
    return 0
  fi
  for parola in "$@"; do
    if ! grep -qF -- "${parola}" <<< "${OUT}"; then
      fail "${nome} (manca «${parola}»): ${OUT}"
      return 0
    fi
  done
  pass "${nome}"
}

# Uscita attesa E parole assenti (RU-01.T5).
# Arguments: $1 il nome, $2 l'uscita attesa, poi le parole (grep -F).
expect_no() {
  local nome="$1" atteso="$2" parola
  shift 2
  if (( RC != atteso )); then
    fail "${nome} (uscita ${RC}, attesa ${atteso}): ${OUT}"
    return 0
  fi
  for parola in "$@"; do
    if grep -qF -- "${parola}" <<< "${OUT}"; then
      fail "${nome} (c'è «${parola}»): ${OUT}"
      return 0
    fi
  done
  pass "${nome}"
}

# Una condizione che è un comando. Arguments: $1 il nome, poi il comando.
vero() {
  local nome="$1"
  shift
  if "$@"; then
    pass "${nome}"
  else
    fail "${nome}"
  fi
}

# Il contrario di vero. Arguments: $1 il nome, poi il comando.
falso() {
  local nome="$1"
  shift
  if "$@"; then
    fail "${nome}"
  else
    pass "${nome}"
  fi
}

# Esegue un comando nell'ambiente delle prove; RC e OUT. Gli ambienti in più
# (NOME=valore) arrivano prima di «--».
# Arguments: [NOME=valore …] -- il comando e i suoi argomenti.
nell_ambiente() {
  local -a variabili=()
  while (( $# > 0 )) && [[ "$1" != "--" ]]; do
    variabili+=("$1")
    shift
  done
  shift
  OUT="$(env PATH="${TMP}/bin:${PATH}" PN_HANDSON_ROOT="${ALBERO}" \
    PN_WORKSPACE_ROOT="${RADICE}" FINTO_LOG="${LOG}" \
    PROVA_PRIMA_LOG="${PRIMA_LOG}" TMPDIR="${BASE_TEMP}" \
    ${variabili[@]+"${variabili[@]}"} "$@" 2>&1 < "${STDIN_PROVA}")"
  RC=$?
}

# prove_skill.sh, senza ambienti in più. Arguments: i suoi argomenti.
prova() { nell_ambiente -- "${TOOL}" "$@"; }

# Quante chiamate al claude finto sono nel registro.
chiamate() {
  if [[ -f "${LOG}" ]]; then
    grep -c '"evento": "inizio"' "${LOG}"
  else
    echo 0
  fi
}

# Python sul registro: `righe` sono le chiamate, nell'ordine in cui sono
# partite. Arguments: nessuno; il codice su STDIN. Globals: RC, OUT.
registro() {
  OUT="$(PN_LOG="${LOG}" PN_WS="${WS}" python3 -B -I "${TMP}/registro.py" 2>&1)"
  RC=$?
}

# Una configurazione al posto di quella buona.
# Arguments: $1 il testo di prove/config.
con_config() { printf '%b' "$1" > "${ITEM}/prove/config"; }

config_buona() {
  printf '# le prove\nskill=%s\nstrumenti=Read,Bash(git diff *),Skill(%s)\n' \
    "${SKILL}" "${SKILL}" > "${ITEM}/prove/config"
}

# L'albero del repository, una volta per tutte.
crea_albero() {
  ALBERO="${TMP}/albero"
  ITEM="${ALBERO}/m5_prova/s4_prova/m5_e2_prova/${ID}_prova"
  local es="${ITEM}/esercizio" skill="${ITEM}/esercizio/.claude/skills/${SKILL}"
  mkdir -p "${ALBERO}/tools" "${ALBERO}/.claude" "${ITEM}/prove" \
    "${skill}/evals" "${es}/progetti"
  cp "${REPO}"/tools/*.py "${ALBERO}/tools/"
  printf '{}\n' > "${ALBERO}/.claude/settings.json"
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' id kind env section_dir \
    subdeck_dir deck_path minutes title_it > "${ALBERO}/m5_prova/manifest.tsv"
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "${ID}" esercizio claude-code-pro \
    s4_prova m5_e2_prova slides/practice/m5_prova/m5_e2_prova 10 Prova \
    >> "${ALBERO}/m5_prova/manifest.tsv"
  printf '*-workspace/\n' > "${es}/.gitignore"
  printf '{"permissions": {"deny": ["Read(**/.env)"]}}\n' \
    > "${es}/.claude/settings.json"
  printf 'appunti di prova\n' > "${es}/progetti/appunti.txt"
  scrivi_casi "${skill}/evals"
  crea_riferimenti
  crea_controlli
  config_buona
  git -C "${ALBERO}" init -q
}

# I casi di prova, con il prompt difficile. Arguments: $1 la cartella evals/.
scrivi_casi() {
  cat > "$1/evals.json" <<'EOF'
{"skill_name": "prova-skill", "evals": [
  {"id": 1, "prompt": "CHIAMA la skill, per favore", "expected_output": "x",
   "assertions": ["La risposta nomina la versione", "Da guardare"]},
  {"id": 2,
   "prompt": "CHIAMA \"virgolette\" 'apici' $HOME `ls` \\n\nseconda riga\n",
   "expected_output": "x",
   "assertions": ["La risposta nomina la versione"]},
  {"id": 3, "prompt": "- CHIAMA con un trattino in testa, e SCRIVI",
   "expected_output": "x",
   "assertions": ["La risposta nomina la versione"]}]}
EOF
  cat > "$1/eval_queries.json" <<'EOF'
[{"query": "una richiesta vicina", "should_trigger": false}]
EOF
}

crea_riferimenti() {
  local es="${ALBERO}/riferimenti/skill-di-esempio/${SKILL}"
  mkdir -p "${es}/references" "${es}/evals"
  cat > "${es}/SKILL.md" <<'EOF'
---
name: prova-skill
description: Prova le cose. Da usare quando serve una prova.
---

# Prova

La versione è VERSIONE-1. Leggi `references/guida.md`.
EOF
  printf 'La guida.\n' > "${es}/references/guida.md"
  printf '{"skill_name": "DA-NON-COPIARE"}\n' > "${es}/evals/evals.json"
  cat > "${ALBERO}/riferimenti/template-SKILL.md" <<'EOF'
---
name: nome-della-skill
description: <Che cosa fa>. Da usare quando <le situazioni>.
---

# nome-della-skill, <il compito>

Il resto del modello, con $HOME e `backtick`.
EOF
}

# I controlli dell'elemento finto: lo stesso verifica.py che il modulo
# documenta, più una leva per provare le sue uscite.
crea_controlli() {
  cat > "${ITEM}/prove/prima.sh" <<'EOF'
#!/bin/bash
set -euo pipefail
[[ -z "${PROVA_PRIMA_KO:-}" ]] || exit 1
printf '%s %s %s\n' "$1" "$2" "${PWD}" >> "${PROVA_PRIMA_LOG}"
git -C "$1" checkout -q -b "pr-$2"
EOF
  chmod +x "${ITEM}/prove/prima.sh"
  cat > "${ITEM}/verifica.sh" <<'EOF'
#!/bin/bash
set -euo pipefail
SELF="$(readlink -f "${BASH_SOURCE[0]}")"
python3 -B -I "${SELF%/*}/verifica.py" "$1"
EOF
  chmod +x "${ITEM}/verifica.sh"
  cat > "${ITEM}/verifica.py" <<'EOF'
"""verifica.py di un elemento finto, per le prove di prove_skill.sh."""
import os
import sys
import time

RADICE = os.environ.get("PN_HANDSON_ROOT")
if not RADICE:
    print("verifica: manca PN_HANDSON_ROOT", file=sys.stderr)
    sys.exit(2)
sys.path.insert(0, os.path.join(RADICE, "tools"))
import controlla_skill  # noqa: E402
import lib_controlla_prove as prove  # noqa: E402

SKILL = "prova-skill"


def nomina_la_versione(esec, _contesto):
    return "VERSIONE-" in esec.testo, f"la risposta: «{esec.testo[:60]}»"


GIUDICI = {"La risposta nomina la versione": nomina_la_versione}


def main(argv):
    leva = os.environ.get("PROVA_USCITA")
    if leva:
        return int(leva)
    segno = os.environ.get("PROVA_DORMI")
    if segno:
        with open(segno, "w", encoding="utf-8"):
            time.sleep(1)
    ws = argv[0]
    solo_prove = "--solo-prove" in argv[1:]
    esame = prove.esamina(ws, SKILL, GIUDICI, None, scrivi=solo_prove)
    trovati = prove.reperti(esame, SKILL)
    for riga in trovati:
        print(f"REPERTO {riga}")
    if solo_prove:
        return 1 if trovati else 0
    mancano = prove.manca_per_finire(esame, ws, SKILL)
    mancano += controlla_skill.esamina_skill(esame.cartella_skill).errori
    for riga in mancano:
        print(f"MANCA {riga}")
    return 1 if trovati or mancano else 0


if __name__ == "__main__":
    sys.exit(prove.principale(main, sys.argv[1:]))
EOF
}

# Uno spazio di lavoro nuovo, con il suo registro.
# Globals: RADICE, WS, LOG, PRIMA_LOG, N, BASE_TEMP.
nuovo_ws() {
  N=$((N + 1))
  RADICE="${TMP}/r${N}"
  LOG="${TMP}/log${N}.jsonl"
  PRIMA_LOG="${TMP}/prima${N}.log"
  BASE_TEMP="${TMP}/temp${N}"
  WS="${RADICE}/${ID}"
  mkdir -p "${BASE_TEMP}"
  nell_ambiente -- "${REPO}/tools/prepara_esercizio.sh" "${ID}"
  if (( RC != 0 )); then
    echo "test_prove_skill: prepara_esercizio.sh non riesce: ${OUT}" >&2
    exit 2
  fi
}

# Il percorso di un'esecuzione. Arguments: $1 N, $2 l'id, $3 la configurazione.
braccio() {
  printf '%s/%s-workspace/iteration-%s/eval-%s/%s' "${WS}" "${SKILL}" "$1" \
    "$2" "$3"
}

# Lo stream della near-miss della prima iterazione.
stream_near_miss() {
  printf '%s/%s-workspace/iteration-1/near-miss-1/with_skill/outputs/%s' \
    "${WS}" "${SKILL}" stream.jsonl
}

# Una skill nello spazio di lavoro, con un marcatore di versione.
# Arguments: $1 il marcatore.
scrivi_skill() {
  cat > "${WS}/.claude/skills/${SKILL}/SKILL.md" <<EOF
---
name: ${SKILL}
description: Prova le cose. Da usare quando serve una prova.
---

La versione è VERSIONE-$1.
EOF
}

# Nessuna cartella rimasta nella base dei temporanei.
temp_pulita() { [[ -z "$(ls -A -- "${BASE_TEMP}")" ]]; }

# --- Gli argomenti ---------------------------------------------------------

test_argomenti() {
  nuovo_ws
  local -a caso
  prova
  expect 'senza argomenti: uscita 2 e l uso' 2 'Uso'
  prova --help
  expect '--help: uscita 0, i due usi' 0 'copia esempio|modello' \
    'without|with' '--radice'
  prova "${ID}"
  expect 'solo l elemento: uscita 2' 2 'Uso'
  prova "${ID}" copia
  expect 'copia senza il modo: uscita 2' 2 'Uso'
  prova "${ID}" copia boh
  expect 'copia con un modo sconosciuto: uscita 2' 2 'esempio' 'modello'
  for caso in '0 with' 'abc with' '-1 with' '1 boh' '1 with altro'; do
    # shellcheck disable=SC2086  # gli argomenti si dividono apposta
    prova "${ID}" ${caso}
    expect "argomenti sbagliati: ${caso}" 2
  done
  prova "${ID}" 1 with --non-so
  expect 'un opzione sconosciuta: uscita 2' 2 'non-so'
  prova "${ID}" 1 with --radice
  expect '--radice senza cartella: uscita 2' 2 'radice'
  prova M5-Z1 1 with
  expect 'un identificativo sbagliato: uscita 2' 2 'identificativo'
  prova M5-E77 1 with
  expect 'un elemento che non c è: uscita 2' 2 'M5-E77'
  RADICE="${TMP}/non-c-e"
  prova "${ID}" 1 without
  expect 'lo spazio di lavoro che non c è: uscita 2' 2 'prepara_esercizio'
  vero 'nessuna chiamata per gli argomenti sbagliati' test "$(chiamate)" = 0
}

test_radice() {
  nuovo_ws
  local radice_vera="${RADICE}"
  RADICE="${TMP}/non-questa"
  prova "${ID}" copia esempio --radice "${radice_vera}"
  expect '--radice <cartella>' 0 'Copiata'
  RADICE="${radice_vera}"
  rm -f -- "${WS}/.claude/skills/${SKILL}/SKILL.md"
  rm -rf -- "${WS}/.claude/skills/${SKILL}/references"
  RADICE="${TMP}/non-questa"
  prova "${ID}" copia esempio "--radice=${radice_vera}"
  expect '--radice=<cartella>' 0 'Copiata'
  RADICE="${radice_vera}"
  vero 'la skill è arrivata' test -f "${WS}/.claude/skills/${SKILL}/SKILL.md"
}

test_config() {
  nuovo_ws
  con_config '# senza la skill\nstrumenti=Read\n'
  prova "${ID}" 1 without
  expect 'config: manca skill' 2 'skill' 'config'
  con_config 'skill=Non Va\nstrumenti=Read\n'
  prova "${ID}" 1 without
  expect 'config: un nome di skill che non va' 2 'Non Va'
  con_config 'skill=../fuori\nstrumenti=Read\n'
  prova "${ID}" 1 without
  expect 'config: un nome di skill con un percorso' 2 '../fuori'
  con_config 'skill=prova-skill\n'
  prova "${ID}" 1 without
  expect 'config: manca strumenti' 2 'strumenti'
  con_config 'skill=prova-skill\nstrumenti=Read\nboh=1\n'
  prova "${ID}" 1 without
  expect 'config: una chiave sconosciuta' 2 'boh'
  con_config 'skill=prova-skill\nstrumenti=Read\nsenza uguale\n'
  prova "${ID}" 1 without
  expect 'config: una riga senza =' 2 'senza uguale'
  con_config 'skill=prova-skill\nstrumenti=Read\neffort=Non Va\n'
  prova "${ID}" 1 without
  expect 'config: un effort che non va' 2 'effort'
  con_config 'skill=prova-skill\nstrumenti=Read\nmodello=fable\n'
  prova "${ID}" 1 without
  expect 'config: Fable è rifiutato prima di chiamare' 2 'Fable'
  con_config 'skill=prova-skill\nstrumenti=--dangerously-skip-permissions\n'
  prova "${ID}" 1 without
  expect 'config: strumenti che saltano i permessi' 2 'rifiutato'
  con_config 'skill=prova-skill\nstrumenti=Read\n'
  prova "${ID}" 1 without
  expect 'config: senza Skill(<skill>) negli strumenti' 2 'Skill(prova-skill)'
  con_config 'skill=prova-skill\nstrumenti=Read,Skill(altra)\n'
  prova "${ID}" 1 without
  expect 'config: con Skill di un altra skill' 2 'Skill(prova-skill)'
  con_config 'skill=prova-skill\nstrumenti=Skill(prova-skill-due)\n'
  prova "${ID}" 1 without
  expect 'config: con Skill di un nome che la contiene' 2 'Skill(prova-skill)'
  con_config 'skill=prova-skill\nstrumenti=Read\nesempio=../fuori\n'
  prova "${ID}" copia esempio
  expect 'config: esempio con un percorso' 2 '../fuori'
  rm -f -- "${ITEM}/prove/config"
  prova "${ID}" 1 without
  expect 'config assente' 2 'config'
  vero 'nessuna chiamata per una configurazione sbagliata' \
    test "$(chiamate)" = 0
  config_buona
}

# --- copia ------------------------------------------------------------------

test_copia_esempio() {
  nuovo_ws
  local dest="${WS}/.claude/skills/${SKILL}"
  local casi
  casi="$(< "${dest}/evals/evals.json")"
  prova "${ID}" copia esempio
  expect 'copia esempio: uscita 0' 0 'Copiata' \
    "python3 -B -I tools/controlla_skill.py ${dest}"
  vero 'copia esempio: SKILL.md' cmp -s "${dest}/SKILL.md" \
    "${ALBERO}/riferimenti/skill-di-esempio/${SKILL}/SKILL.md"
  vero 'copia esempio: i file accanto' test -f "${dest}/references/guida.md"
  vero 'copia esempio: evals/ non si tocca' \
    test "$(< "${dest}/evals/evals.json")" = "${casi}"
  falso 'copia esempio: niente evals/ dell esempio' \
    grep -q DA-NON-COPIARE "${dest}/evals/evals.json"
  printf 'lavoro mio\n' > "${dest}/SKILL.md"
  prova "${ID}" copia esempio
  expect 'copia esempio: rifiuta se SKILL.md c è' 2 'SKILL.md' 'c'\''è già'
  vero 'copia esempio: il lavoro resta' \
    test "$(< "${dest}/SKILL.md")" = 'lavoro mio'
  prova "${ID}" copia modello
  expect 'copia modello: rifiuta se SKILL.md c è' 2 'SKILL.md' 'c'\''è già'
  vero 'copia modello: il lavoro resta' \
    test "$(< "${dest}/SKILL.md")" = 'lavoro mio'
}

# Il comando che `copia` stampa si incolla anche con uno spazio o un apice nel
# percorso: la prova lo esegue così com'è stampato.
test_copia_percorso_strano() {
  nuovo_ws
  RADICE="${TMP}/con spazio e l'apice"
  WS="${RADICE}/${ID}"
  nell_ambiente -- "${REPO}/tools/prepara_esercizio.sh" "${ID}"
  expect 'un percorso con spazio e apice: lo spazio di lavoro' 0 'pronto'
  prova "${ID}" copia esempio
  expect 'copia in quel percorso: uscita 0' 0 'Copiata'
  grep -F 'controlla_skill.py' <<< "${OUT}" > "${TMP}/comando.sh"
  OUT="$(cd "${REPO}" && bash "${TMP}/comando.sh" 2>&1)"
  RC=$?
  expect 'il comando stampato, incollato, legge quella cartella' 0 \
    'controlla_skill: prova-skill: 0 errori'
}

# Il lavoro del partecipante non si sovrascrive, anche senza uno SKILL.md.
test_copia_sopra_altri_file() {
  nuovo_ws
  local dest="${WS}/.claude/skills/${SKILL}"
  mkdir -p "${dest}/references"
  printf 'scritto a mano\n' > "${dest}/references/guida.md"
  prova "${ID}" copia esempio
  expect 'copia esempio: rifiuta se ci sono altri file' 2 'references' \
    'c'\''è già'
  vero 'copia esempio: il file scritto a mano resta' \
    test "$(< "${dest}/references/guida.md")" = 'scritto a mano'
  falso 'copia esempio: nessuno SKILL.md copiato' test -e "${dest}/SKILL.md"
  prova "${ID}" copia modello
  expect 'copia modello: scrive solo SKILL.md, quindi va bene' 0 'Copiata'
  vero 'copia modello: il file scritto a mano resta' \
    test "$(< "${dest}/references/guida.md")" = 'scritto a mano'
  nuovo_ws
  dest="${WS}/.claude/skills/${SKILL}"
  printf 'un file nascosto\n' > "${dest}/.nota"
  prova "${ID}" copia esempio
  expect 'copia esempio: anche un file nascosto conta' 2 '.nota'
}

test_copia_modello() {
  nuovo_ws
  local dest="${WS}/.claude/skills/${SKILL}"
  prova "${ID}" copia modello
  expect 'copia modello: uscita 0' 0 'Copiata'
  vero 'copia modello: il nome sostituito' \
    grep -qx "name: ${SKILL}" "${dest}/SKILL.md"
  vero 'copia modello: anche nel corpo' \
    grep -q "^# ${SKILL}, <il compito>\$" "${dest}/SKILL.md"
  falso 'copia modello: il segnaposto del nome non c è più' \
    grep -q nome-della-skill "${dest}/SKILL.md"
  vero 'copia modello: il resto com è' \
    grep -qF 'Il resto del modello, con $HOME e `backtick`.' "${dest}/SKILL.md"
  vero 'copia modello: l ultima riga con il suo a capo' \
    test "$(tail -c 1 "${dest}/SKILL.md" | od -An -c | tr -d ' ')" = '\n'
  vero 'copia modello: evals/ resta' test -f "${dest}/evals/evals.json"
}

test_copia_altro_esempio() {
  nuovo_ws
  local dest="${WS}/.claude/skills/${SKILL}"
  local altro="${ALBERO}/riferimenti/skill-di-esempio/altra-skill"
  mkdir -p "${altro}"
  printf 'quella giusta\n' > "${altro}/SKILL.md"
  printf 'skill=%s\nstrumenti=Read\nesempio=altra-skill\n' "${SKILL}" \
    > "${ITEM}/prove/config"
  prova "${ID}" copia esempio
  expect 'la chiave esempio' 0 'Copiata'
  vero 'la chiave esempio: la cartella giusta' \
    test "$(< "${dest}/SKILL.md")" = 'quella giusta'
  rm -rf -- "${altro}"
  rm -f -- "${dest}/SKILL.md"
  prova "${ID}" copia esempio
  expect 'un esempio che non c è: uscita 2' 2 'altra-skill'
  config_buona
  mv "${ALBERO}/riferimenti/template-SKILL.md" "${TMP}/template.salvo"
  prova "${ID}" copia modello
  expect 'il modello che non c è: uscita 2' 2 'template-SKILL.md'
  mv "${TMP}/template.salvo" "${ALBERO}/riferimenti/template-SKILL.md"
}

# --- 1 without --------------------------------------------------------------

test_without() {
  nuovo_ws
  printf '{"permissions": {"allow": ["Bash(*)"]}}\n' \
    > "${WS}/.claude/settings.local.json"
  nell_ambiente ANTHROPIC_API_KEY=chiave-finta-0042 -- \
    "${TOOL}" "${ID}" 1 without
  expect '1 without: uscita 0, la tabella' 0 'Iterazione 1' \
    'without_skill: Skill chiamata: no; 0 su 1 asserzione' \
    '3 esecuzioni, ognuna in una sessione nuova'
  expect_no '1 without: la chiave non si stampa' 0 'chiave-finta-0042'
  vero '1 without: tre chiamate' test "$(chiamate)" = 3
  registro <<'PY'
import json
for r in righe:
    atteso = ["-p", "--allowedTools",
              "Read,Bash(git diff *),Skill(prova-skill)", "--model",
              "sonnet", "--permission-mode", "dontAsk", "--permission-prompts",
              "none", "--output-format", "stream-json", "--verbose",
              "--setting-sources", "project,local", "--effort", "low",
              "--strict-mcp-config", "--no-session-persistence", "--",
              r["prompt"]]
    print("flag", r["argv"] == atteso)
    print("cwd", r["cwd"] != ws and not r["cwd"].startswith(ws))
    print("copia", r["skill"], r["evals"], r["workspace"], r["settings"],
          r["settings_local"], r["chiave"])
    print("storia", [f for f in r["git_log"] if "evals" in f or "prova-" in f])
print("rami", sorted(r["branch"] for r in righe))
PY
  expect_no '1 without: i flag esatti, da una copia' 0 'flag False' 'cwd False'
  expect '1 without: nella copia niente skill, evals, workspace, personali' 0 \
    'copia [] False False True False False'
  expect '1 without: niente nemmeno nella storia di git' 0 'storia []'
  expect '1 without: prima.sh in ogni copia' 0 "['pr-1', 'pr-2', 'pr-3']"
  local b1 b3
  b1="$(braccio 1 1 without_skill)"
  b3="$(braccio 1 3 without_skill)"
  vero '1 without: lo stream' test -s "${b1}/outputs/stream.jsonl"
  vero '1 without: stderr.txt' test -f "${b1}/outputs/stderr.txt"
  vero '1 without: la risposta' test -f "${b1}/outputs/risposta.md"
  vero '1 without: timing e grading' test -f "${b1}/timing.json" -a \
    -f "${b1}/grading.json"
  vero '1 without: benchmark' \
    test -f "${WS}/${SKILL}-workspace/iteration-1/benchmark.json"
  vero '1 without: file-cambiati vuoto dove niente cambia' \
    test ! -s "${b1}/outputs/file-cambiati.txt"
  vero '1 without: file-cambiati dove un file cambia' \
    grep -qx '?? nuovo.txt' "${b3}/outputs/file-cambiati.txt"
  falso '1 without: nessuna fotografia' \
    test -e "${WS}/${SKILL}-workspace/iteration-1/skill-snapshot"
  falso '1 without: nessuna near-miss' \
    test -e "${WS}/${SKILL}-workspace/iteration-1/near-miss-1"
  vero '1 without: nessun temporaneo' temp_pulita
  vero '1 without: per git i progetti restano come sono' \
    test -z "$(git -C "${WS}" status --porcelain -- progetti)"
  vero '1 without: la cartella dei risultati è ignorata' \
    git -C "${WS}" check-ignore -q "${SKILL}-workspace"
  nuovo_ws
  rm -f -- "${WS}/.gitignore"
  scrivi_skill 1
  prova "${ID}" 1 without
  expect 'senza il .gitignore dell elemento: gira lo stesso' 0 'Iterazione 1'
  prova "${ID}" 1 with
  expect 'senza il .gitignore: anche with, dopo without' 0 'Iterazione 1'
  registro <<'PY'
print("workspace", sorted({r["workspace"] for r in righe}))
print("storia", [f for r in righe for f in r["git_log"] if "workspace" in f])
PY
  expect 'senza il .gitignore: il risultato non entra mai nelle copie' 0 \
    'workspace [False]' 'storia []'
}

test_stdin() {
  nuovo_ws
  STDIN_PROVA="${SELF}"
  prova "${ID}" 1 without
  STDIN_PROVA=/dev/null
  expect 'con uno STDIN pieno: uscita 0' 0 'Iterazione 1'
  registro <<'PY'
print("stdin", sorted({r["stdin_nullo"] for r in righe}))
PY
  expect 'claude legge sempre da /dev/null, qualunque STDIN abbia chi lancia' \
    0 'stdin [True]'
}

test_effort_modello() {
  nuovo_ws
  printf 'skill=%s\nstrumenti=Skill(%s)\nmodello=haiku\neffort=medium\n' \
    "${SKILL}" "${SKILL}" > "${ITEM}/prove/config"
  prova "${ID}" 1 without
  expect 'modello ed effort della configurazione: uscita 0' 0 'Iterazione 1'
  registro <<'PY'
r = righe[0]["argv"]
print(r[r.index("--model") + 1], r[r.index("--effort") + 1],
      r[r.index("--allowedTools") + 1])
PY
  expect 'modello ed effort: arrivano a claude' 0 \
    'haiku medium Skill(prova-skill)'
  config_buona
}

# --- 1 with -----------------------------------------------------------------

test_with() {
  nuovo_ws
  prova "${ID}" 1 with
  expect '1 with senza SKILL.md: uscita 2 e che cosa fare' 2 'SKILL.md' 'copia'
  vero '1 with senza SKILL.md: nessuna chiamata' test "$(chiamate)" = 0
  falso '1 with senza SKILL.md: nessuna cartella' \
    test -e "${WS}/${SKILL}-workspace"
  scrivi_skill 1
  mkdir -p "${WS}/.claude/skills/${SKILL}/references"
  printf 'guida\n' > "${WS}/.claude/skills/${SKILL}/references/guida.md"
  prova "${ID}" 1 with
  expect '1 with: uscita 0, la tabella' 0 'Iterazione 1' \
    'with_skill: Skill chiamata: sì; 1 su 1 asserzione' \
    'near-miss 1: Skill chiamata: no; dovrebbe attivarla: no;' \
    '«una richiesta vicina»'
  vero '1 with: tre casi e la near-miss' test "$(chiamate)" = 4
  registro <<'PY'
for r in righe:
    print("copia", r["skill"], r["evals"], r["workspace"], r["settings"])
    print("storia", [f for f in r["git_log"] if "evals" in f])
print("skill-md", all(any("prova-skill/SKILL.md" in f for f in r["git_log"])
                      for r in righe))
print("rami", sorted(r["branch"] for r in righe))
print("near", sum(1 for r in righe if r["prompt"] == "una richiesta vicina"))
PY
  expect '1 with: la skill nella copia, evals/ no, neanche in git' 0 \
    "copia ['prova-skill'] False False True" 'storia []' 'skill-md True'
  expect '1 with: prima.sh anche per la near-miss' 0 \
    "['pr-1', 'pr-2', 'pr-3', 'pr-q1']" 'near 1'
  local snap="${WS}/${SKILL}-workspace/iteration-1/skill-snapshot"
  vero '1 with: la fotografia' grep -q VERSIONE-1 "${snap}/SKILL.md"
  vero '1 with: la fotografia con i suoi file' \
    test -f "${snap}/references/guida.md"
  falso '1 with: la fotografia senza evals/' test -e "${snap}/evals"
  vero '1 with: la near-miss scrive i suoi file' test -s "$(stream_near_miss)"
  vero '1 with: gli evals/ dello spazio di lavoro restano' \
    test -f "${WS}/.claude/skills/${SKILL}/evals/evals.json"
  vero '1 with: nessun temporaneo' temp_pulita
}

# --- 2 with -----------------------------------------------------------------

test_seconda_iterazione() {
  nuovo_ws
  scrivi_skill 1
  prova "${ID}" 1 with
  expect 'la prima versione' 0 'Iterazione 1'
  scrivi_skill 2
  prova "${ID}" 2 with
  expect '2 with: dice che riusa, e perché' 0 'si riusano' 'quota del piano' \
    'Iterazione 2' 'old_skill: Skill chiamata: sì' \
    'with_skill 1, old_skill 1 asserzione passata: non distinguibile'
  vero '2 with: soltanto la versione nuova gira, quattro chiamate in più' \
    test "$(chiamate)" = 8
  local vecchia nuova
  vecchia="$(braccio 2 1 old_skill)"
  nuova="$(braccio 2 1 with_skill)"
  vero '2 with: old_skill è la copia delle esecuzioni di prima' cmp -s \
    "$(braccio 1 1 with_skill)/outputs/stream.jsonl" \
    "${vecchia}/outputs/stream.jsonl"
  vero '2 with: old_skill dice la versione di prima' \
    grep -q VERSIONE-1 "${vecchia}/outputs/risposta.md"
  vero '2 with: with_skill dice la versione nuova' \
    grep -q VERSIONE-2 "${nuova}/outputs/risposta.md"
  vero '2 with: grading di old_skill ricalcolato' \
    test -f "${vecchia}/grading.json"
  vero '2 with: benchmark con la baseline old_skill' \
    grep -q old_skill "${WS}/${SKILL}-workspace/iteration-2/benchmark.json"
  vero '2 with: la fotografia nuova' grep -q VERSIONE-2 \
    "${WS}/${SKILL}-workspace/iteration-2/skill-snapshot/SKILL.md"
  vero '2 with: la near-miss anche qui' test -d \
    "${WS}/${SKILL}-workspace/iteration-2/near-miss-1/with_skill/outputs"
  nuovo_ws
  scrivi_skill 1
  prova "${ID}" 4 with
  expect 'una iterazione senza la precedente: gira, senza old_skill' 0 \
    'Iterazione 4' 'Nessuna fotografia'
  falso 'una iterazione senza la precedente: niente old_skill' \
    test -e "$(braccio 4 1 old_skill)"
}

# --- I rifiuti ---------------------------------------------------------------

test_rifiuti() {
  nuovo_ws
  scrivi_skill 1
  prova "${ID}" 1 without
  expect 'la prima volta' 0 'Iterazione 1'
  local prima
  prima="$(chiamate)"
  prova "${ID}" 1 without
  local iter="${WS}/${SKILL}-workspace/iteration"
  expect '1 without due volte: uscita 2' 2 "usa l'iterazione seguente" \
    "cancella ${iter}-1/eval-*/without_skill e rilancia lo stesso comando." \
    "tools/prove_skill.sh ${ID} 2 without"
  expect_no '1 without due volte: niente di with' 2 'near-miss' 'with_skill'
  vero '1 without due volte: nessuna chiamata in più' \
    test "$(chiamate)" = "${prima}"
  vero 'un rifiuto non lascia temporanei' temp_pulita
  prova "${ID}" 1 with
  expect 'without e with nella stessa iterazione: va bene' 0 'Iterazione 1'
  prima="$(chiamate)"
  prova "${ID}" 1 with
  expect '1 with due volte: uscita 2' 2 "usa l'iterazione seguente" \
    "cancella ${iter}-1/eval-*/with_skill, ${iter}-1/near-miss-* e rilancia" \
    "tools/prove_skill.sh ${ID} 2 with"
  vero '1 with due volte: nessuna chiamata in più' \
    test "$(chiamate)" = "${prima}"
  prova "${ID}" 2 with
  expect '2 with: va bene' 0 'Iterazione 2'
  prima="$(chiamate)"
  prova "${ID}" 2 with
  expect '2 with due volte: uscita 2' 2 "usa l'iterazione seguente" \
    "${iter}-2/near-miss-*, ${iter}-2/eval-*/old_skill e rilancia" \
    "tools/prove_skill.sh ${ID} 3 with"
  vero '2 with due volte: nessuna chiamata in più' \
    test "$(chiamate)" = "${prima}"
  nuovo_ws
  scrivi_skill 1
  mkdir -p "${WS}/${SKILL}-workspace/iteration-1/near-miss-1/with_skill/outputs"
  prova "${ID}" 1 with
  expect 'una near-miss già lì: uscita 2' 2 "usa l'iterazione seguente"
  nuovo_ws
  scrivi_skill 1
  mkdir -p "$(braccio 2 1 old_skill)/outputs"
  prova "${ID}" 2 with
  expect 'un old_skill già lì: uscita 2' 2 "usa l'iterazione seguente"
  nuovo_ws
  scrivi_skill 1
  mkdir -p "${WS}/${SKILL}-workspace/iteration-1/skill-snapshot"
  printf 'vecchio\n' > "${WS}/${SKILL}-workspace/iteration-1/skill-snapshot/X"
  prova "${ID}" 1 with
  expect 'una fotografia senza esecuzioni si rifà' 0 'Iterazione 1'
  falso 'una fotografia senza esecuzioni: il vecchio se ne va' \
    test -e "${WS}/${SKILL}-workspace/iteration-1/skill-snapshot/X"
  nuovo_ws
  scrivi_skill 1
  mv "${WS}/.claude/skills/${SKILL}" "${WS}/.claude/skills/vera"
  ln -s vera "${WS}/.claude/skills/${SKILL}"
  prova "${ID}" 1 with
  expect 'una cartella della skill che è un collegamento: uscita 2' 2 \
    'collegamento'
  vero 'un collegamento: gli evals/ veri restano' \
    test -f "${WS}/.claude/skills/vera/evals/evals.json"
  vero 'un collegamento: nessuna chiamata' test "$(chiamate)" = 0
}

# Chi cancella ciò che il messaggio dice rifà tutti i casi: lo strumento non si
# ferma sul caso seguente e non restano i file ricalcolati di prima.
test_rifare_come_dice() {
  nuovo_ws
  prova "${ID}" 1 without
  expect 'da rifare: la prima volta' 0 'Iterazione 1'
  local caso
  caso="$(braccio 1 1 without_skill)"
  vero 'da rifare: i file ricalcolati ci sono' test -f "${caso}/grading.json"
  rm -rf -- "${caso}/outputs"
  prova "${ID}" 1 without
  expect 'da rifare: una sola cartella tolta non basta, e lo dice' 2 \
    'eval-2/without_skill/outputs' 'eval-*/without_skill'
  rm -rf -- "${WS}/${SKILL}-workspace/iteration-1"/eval-*/without_skill
  prova "${ID}" 1 without
  expect 'da rifare: tolto ciò che dice, riparte' 0 'Iterazione 1'
  vero 'da rifare: tre chiamate in più' test "$(chiamate)" = 6
}

# Un caso solo: il numero si accorda.
test_un_caso_solo() {
  nuovo_ws
  cat > "${WS}/.claude/skills/${SKILL}/evals/evals.json" <<'EOF'
{"skill_name": "prova-skill", "evals": [
  {"id": 1, "prompt": "un caso solo", "expected_output": "x"}]}
EOF
  prova "${ID}" 1 without
  expect 'un caso solo: «1 esecuzione»' 0 '1 esecuzione, in una sessione nuova'
  expect_no 'un caso solo: mai «1 esecuzioni»' 0 '1 esecuzioni'
}

# La modalità di permesso non dipende dall'ambiente di chi lancia lo strumento.
test_modo_fisso() {
  nuovo_ws
  nell_ambiente HANDSON_PERMISSION_MODE=acceptEdits -- \
    "${TOOL}" "${ID}" 1 without
  expect 'HANDSON_PERMISSION_MODE nell ambiente: uscita 0' 0 'Iterazione 1'
  registro <<'PY'
print("modi", sorted({r["argv"][r["argv"].index("--permission-mode") + 1]
                      for r in righe}))
PY
  expect 'HANDSON_PERMISSION_MODE nell ambiente: resta dontAsk' 0 \
    "modi ['dontAsk']"
}

# Senza pgrep un segnale non fermerebbe le sessioni in corso: lo strumento se ne
# accorge prima di cominciare. Il PATH ha solo ciò che serve per arrivarci.
test_senza_pgrep() {
  nuovo_ws
  local senza="${TMP}/senza-pgrep" t
  mkdir -p "${senza}"
  for t in git python3 readlink; do
    ln -s "$(command -v "${t}")" "${senza}/${t}"
  done
  ln -s "${TMP}/bin/claude" "${senza}/claude"
  nell_ambiente PATH="${senza}" -- "${TOOL}" "${ID}" 1 without
  expect 'manca pgrep: uscita 2' 2 'manca lo strumento: pgrep'
  vero 'manca pgrep: nessuna chiamata' test "$(chiamate)" = 0
  prova "${ID}" 1 without
  expect_no 'pgrep c è: nessun messaggio' 0 'manca lo strumento'
}

# --- Le esecuzioni che falliscono -------------------------------------------

test_fallite() {
  nuovo_ws
  scrivi_skill 1
  nell_ambiente 'FINTO_KO_SU=seconda riga' -- "${TOOL}" "${ID}" 1 with
  expect 'un esecuzione fallita: uscita 1, dice quale' 1 'FALLITA eval-2' \
    'cancella' 'with_skill'
  expect 'un esecuzione fallita: le altre finite e lette' 1 'Iterazione 1' \
    'eval-2' 'with_skill: incompleta'
  vero 'un esecuzione fallita: tutte partite' test "$(chiamate)" = 4
  vero 'un esecuzione fallita: eval-1 ha il suo risultato' grep -q \
    '"type": "result"' "$(braccio 1 1 with_skill)/outputs/stream.jsonl"
  vero 'un esecuzione fallita: eval-3 ha il suo risultato' grep -q \
    '"type": "result"' "$(braccio 1 3 with_skill)/outputs/stream.jsonl"
  vero 'un esecuzione fallita: la near-miss ha il suo risultato' grep -q \
    '"type": "result"' "$(stream_near_miss)"
  vero 'un esecuzione fallita: nessun temporaneo' temp_pulita
  nuovo_ws
  cat > "${WS}/.claude/skills/${SKILL}/evals/evals.json" <<'EOF'
{"skill_name": "prova-skill", "evals": [
  {"id": 1, "prompt": "ERRORE-RISULTATO qui", "expected_output": "x"},
  {"id": 2, "prompt": "CHIAMA", "expected_output": "x"}]}
EOF
  prova "${ID}" 1 without
  expect 'uscita 0 di claude ma is_error: è fallita' 1 'FALLITA eval-1' \
    'finita con un errore'
  expect_no 'uscita 0 di claude ma is_error: l altra no' 1 'FALLITA eval-2'
  nuovo_ws
  nell_ambiente FINTO_RIGA_ROTTA=1 -- "${TOOL}" "${ID}" 1 without
  expect 'uno stream rovinato: fallita, e lo dice' 1 'FALLITA eval-1' \
    'non è JSON'
  vero 'uno stream rovinato: nessun temporaneo' temp_pulita
}

# --- I prompt, il parallelo, i temporanei ------------------------------------

test_prompt_intatto() {
  nuovo_ws
  prova "${ID}" 1 without
  expect 'i prompt: uscita 0' 0 'Iterazione 1'
  registro <<'PY'
import json
casi = json.load(open(ws + "/.claude/skills/prova-skill/evals/evals.json",
                      encoding="utf-8"))["evals"]
visti = sorted(r["prompt"] for r in righe)
print("uguali", visti == sorted(c["prompt"] for c in casi))
print("ultimo", all(r["argv"][-1] == r["prompt"] and r["argv"][-2] == "--"
                    for r in righe))
print([r["prompt"] for r in righe if "virgolette" in r["prompt"]][0].__repr__())
for c in casi:
    p = (ws + "/prova-skill-workspace/iteration-1/eval-%d/without_skill/"
         "outputs/prompt.txt" % c["id"])
    with open(p, encoding="utf-8", newline="") as fh:
        print("accanto", fh.read() == c["prompt"])
PY
  expect 'i prompt: byte per byte, dopo --' 0 'uguali True' 'ultimo True'
  expect 'i prompt: ognuno resta accanto al suo stream' 0 'accanto True'
  expect_no 'i prompt: nessuno diverso da quello mandato' 0 'accanto False'
  expect 'i prompt: virgolette, $, backtick e l a capo' 0 \
    "\$HOME \`ls\` \\\\n\\nseconda riga\\n"
}

# Aspetta che il registro abbia quante chiamate servono. Arguments: $1 quante.
# Returns: 0; 1 dopo venti secondi.
aspetta_chiamate() {
  local tentativi=0
  until (( $(chiamate) >= $1 )); do
    tentativi=$((tentativi + 1))
    (( tentativi < 200 )) || return 1
    sleep 0.1
  done
}

# Lo strumento in background, con le chiamate che non finiscono da sole; il
# pid in PID_FONDO. Arguments: $1 la pausa del finto, $2 il file di uscita,
# poi gli argomenti.
nel_fondo() {
  local pausa="$1" uscita="$2"
  shift 2
  env PATH="${TMP}/bin:${PATH}" PN_HANDSON_ROOT="${ALBERO}" \
    PN_WORKSPACE_ROOT="${RADICE}" FINTO_LOG="${LOG}" \
    PROVA_PRIMA_LOG="${PRIMA_LOG}" TMPDIR="${BASE_TEMP}" \
    FINTO_PAUSA="${pausa}" python3 -B -I "${TMP}/lancio.py" \
    "${TOOL}" "$@" > "${uscita}" 2>&1 < /dev/null &
  PID_FONDO=$!
}

# Un segnale allo strumento: nessuna sessione resta viva a consumare il piano
# in una cartella cancellata, e l'uscita dice che cosa cancellare per rifare.
test_interruzione() {
  local coppia segnale atteso rc
  for coppia in 'TERM 143' 'HUP 129' 'INT 130'; do
    segnale="${coppia% *}"
    atteso="${coppia#* }"
    nuovo_ws
    nel_fondo 20 "${TMP}/interrotta.txt" "${ID}" 1 without
    if ! aspetta_chiamate 3; then
      fail "${segnale}: le chiamate non partono"
      kill "${PID_FONDO}" 2>/dev/null
      continue
    fi
    kill "-${segnale}" "${PID_FONDO}"
    rc=0
    wait "${PID_FONDO}" || rc=$?
    RC="${rc}"
    OUT="$(< "${TMP}/interrotta.txt")"
    expect "${segnale}: esce ${atteso}, dice che cosa cancellare" "${atteso}" \
      'cancella' 'without_skill'
    registro <<'PY'
vivi = []
for r in righe:
    try:
        os.kill(r["pid"], 0)
        vivi.append(r["pid"])
    except ProcessLookupError:
        pass
print("vivi", vivi, "finite", sum(1 for t in tutti if t["evento"] == "fine"))
PY
    expect "${segnale}: nessuna sessione resta viva" 0 'vivi [] finite 0'
    vero "${segnale}: nessun temporaneo" temp_pulita
    vero "${segnale}: nessun segno di giro in corso" \
      test "$(ls -A "${RADICE}")" = "${ID}"
  done
  test_interruzione_pipe
  test_interruzione_a_giro_finito
}

# Chi legge l'uscita smette di leggere: la riga dopo la quarta, «finita eval-1»,
# trova la pipe chiusa mentre le altre due sessioni stanno ancora lavorando.
test_interruzione_pipe() {
  local rc
  nuovo_ws
  env PATH="${TMP}/bin:${PATH}" PN_HANDSON_ROOT="${ALBERO}" \
    PN_WORKSPACE_ROOT="${RADICE}" FINTO_LOG="${LOG}" \
    PROVA_PRIMA_LOG="${PRIMA_LOG}" TMPDIR="${BASE_TEMP}" FINTO_PAUSA=20 \
    'FINTO_BREVE_SU=per favore' "${TOOL}" "${ID}" 1 without 2> /dev/null \
    < /dev/null | head -n 4 > /dev/null
  rc="${PIPESTATUS[0]}"
  vero "SIGPIPE: esce 141 (uscita ${rc})" test "${rc}" = 141
  registro <<'PY'
vivi = []
for r in righe:
    try:
        os.kill(r["pid"], 0)
        vivi.append(r["pid"])
    except ProcessLookupError:
        pass
print("vivi", vivi, "finite", sum(1 for t in tutti if t["evento"] == "fine"))
PY
  expect 'SIGPIPE: le sessioni ancora al lavoro si fermano' 0 'vivi [] finite 1'
  vero 'SIGPIPE: nessun temporaneo' temp_pulita
}

# Un segnale quando tutte le esecuzioni sono finite, durante la lettura: non
# dice di cancellare esecuzioni buone, già pagate con la quota del piano.
test_interruzione_a_giro_finito() {
  local segno rc=0
  nuovo_ws
  segno="${TMP}/in-lettura${N}"
  PROVA_DORMI="${segno}" nel_fondo 0 "${TMP}/a-giro-finito.txt" \
    "${ID}" 1 without
  local tentativi=0
  until [[ -e "${segno}" ]] || (( tentativi >= 200 )); do
    tentativi=$((tentativi + 1))
    sleep 0.1
  done
  kill -TERM "${PID_FONDO}"
  wait "${PID_FONDO}" || rc=$?
  RC="${rc}"
  OUT="$(< "${TMP}/a-giro-finito.txt")"
  expect 'a giro finito: esce 143' 143 'finita eval-3'
  expect_no 'a giro finito: non dice di cancellare niente' 143 'cancella'
  vero 'a giro finito: le esecuzioni restano' \
    test -s "$(braccio 1 3 without_skill)/outputs/stream.jsonl"
  vero 'a giro finito: nessun temporaneo' temp_pulita
}

# Due giri insieme sullo stesso spazio di lavoro: supererebbero il tetto, e uno
# leggerebbe gli stream dell'altro a metà.
test_un_giro_per_volta() {
  nuovo_ws
  local segno="${RADICE}/.${ID}.prove-in-corso" primo rc=0
  nel_fondo 2 "${TMP}/primo.txt" "${ID}" 1 without
  primo="${PID_FONDO}"
  if ! aspetta_chiamate 1; then
    fail 'un giro per volta: le chiamate non partono'
  fi
  local prima
  prima="$(chiamate)"
  prova "${ID}" 2 without
  expect 'un secondo giro mentre il primo gira: uscita 2' 2 'in corso' \
    "${segno}"
  vero 'un secondo giro: il segno del primo resta' test -d "${segno}"
  wait "${primo}" || rc=$?
  vero 'il primo giro finisce bene' test "${rc}" = 0
  falso 'il secondo non ha fatto chiamate' \
    test -e "${WS}/${SKILL}-workspace/iteration-2"
  falso 'alla fine il segno se ne va' test -e "${segno}"
  mkdir -- "${segno}"
  prima="$(chiamate)"
  prova "${ID}" 2 without
  expect 'un segno rimasto: uscita 2, dice come toglierlo' 2 'in corso' \
    "${segno}"
  vero 'un segno rimasto: nessuna chiamata' test "$(chiamate)" = "${prima}"
  rmdir -- "${segno}"
  prova "${ID}" copia esempio
  expect 'copia non guarda il segno' 0 'Copiata'
}

test_ambiente_chiave() {
  nuovo_ws
  nell_ambiente HANDSON_ENV=trainer-api ANTHROPIC_API_KEY=chiave-finta-0042 -- \
    "${TOOL}" "${ID}" 1 without
  expect 'HANDSON_ENV=trainer-api: uscita 2, prima di chiamare' 2 \
    'claude-code-pro'
  expect_no 'HANDSON_ENV=trainer-api: la chiave non si stampa' 2 \
    'chiave-finta-0042'
  vero 'HANDSON_ENV=trainer-api: nessuna chiamata' test "$(chiamate)" = 0
}

# Un'esecuzione fallita non diventa la baseline di quella dopo.
test_precedente_fallita() {
  nuovo_ws
  scrivi_skill 1
  nell_ambiente 'FINTO_KO_SU=seconda riga' -- "${TOOL}" "${ID}" 1 with
  expect 'la prima versione, con un caso fallito' 1 'FALLITA eval-2'
  local prima
  prima="$(chiamate)"
  scrivi_skill 2
  prova "${ID}" 2 with
  expect 'non si riusa un esecuzione fallita: uscita 2' 2 'eval-2' \
    'non è riuscita' 'iterazione 1'
  vero 'non si riusa: nessuna chiamata' test "$(chiamate)" = "${prima}"
  falso 'non si riusa: nessuna cartella' \
    test -e "${WS}/${SKILL}-workspace/iteration-2"
}

# Ciò che si può controllare fallisce prima della prima chiamata.
test_prima_di_chiamare() {
  nuovo_ws
  mkdir -p "${WS}/${SKILL}-workspace/iteration-1"
  printf 'non una cartella\n' > "${WS}/${SKILL}-workspace/iteration-1/eval-2"
  prova "${ID}" 1 without
  expect 'un file al posto di una cartella: uscita 2' 2 'non è una cartella'
  vero 'un file al posto di una cartella: nessuna chiamata' \
    test "$(chiamate)" = 0
  falso 'un file al posto di una cartella: nessun outputs/' \
    test -e "$(braccio 1 1 without_skill)"
  nuovo_ws
  mkdir -p "${TMP}/altrove${N}" "${WS}/${SKILL}-workspace"
  ln -s "${TMP}/altrove${N}" "${WS}/${SKILL}-workspace/iteration-1"
  prova "${ID}" 1 without
  expect 'iteration-1 che è un collegamento: uscita 2' 2 'collegamento'
  vero 'iteration-1 che è un collegamento: nessuna chiamata' \
    test "$(chiamate)" = 0
  nuovo_ws
  mkdir -p "$(braccio 1 2 x)"
  rm -rf -- "$(braccio 1 2 x)"
  ln -s "${TMP}" "$(braccio 1 2 without_skill)"
  prova "${ID}" 1 without
  expect 'without_skill che è un collegamento: uscita 2' 2 'collegamento'
  nuovo_ws
  cat > "${WS}/.claude/skills/${SKILL}/evals/evals.json" <<'EOF'
{"skill_name": "prova-skill", "evals": [
  {"id": -1, "prompt": "un id negativo", "expected_output": "x"}]}
EOF
  prova "${ID}" 1 without
  expect 'un id negativo: uscita 2, prima di chiamare' 2 '«id»'
  vero 'un id negativo: nessuna chiamata' test "$(chiamate)" = 0
}

test_temp_relativa() {
  nuovo_ws
  local dove="${PWD}"
  mkdir -p "${TMP}/temp-relativa"
  cd -- "${TMP}" || exit 2
  nell_ambiente TMPDIR=temp-relativa -- "${TOOL}" "${ID}" 1 without
  cd -- "${dove}" || exit 2
  expect 'un TMPDIR relativo: uscita 0' 0 'Iterazione 1' 'finita eval-1'
  expect_no 'un TMPDIR relativo: nessuna fallita' 0 'FALLITA'
  vero 'un TMPDIR relativo: nessun temporaneo' \
    test -z "$(ls -A "${TMP}/temp-relativa")"
}

test_chiamata_negata() {
  nuovo_ws
  scrivi_skill 1
  nell_ambiente FINTO_NEGA_SKILL=1 -- "${TOOL}" "${ID}" 1 with
  expect 'una chiamata negata: uscita 1, con il reperto' 1 \
    'with_skill: Skill chiamata: sì, ma negata dal permesso' \
    'REPERTO iterazione 1, eval-1, with_skill: la chiamata Skill a prova-skill'
}

# Nessun caso, o un nome che non torna: mai «fatto» senza aver fatto niente.
test_nessun_caso() {
  nuovo_ws
  # Lo strumento usa il suo aiuto, accanto a sé: la prova passa da una copia
  # di tools/ con un aiuto finto.
  local copia="${TMP}/tools-finti"
  mkdir -p "${copia}"
  cp "${REPO}"/tools/*.sh "${REPO}"/tools/*.py "${copia}/"
  printf 'import sys\nsys.exit(0)\n' > "${copia}/prove_skill_casi.py"
  nell_ambiente -- "${copia}/prove_skill.sh" "${ID}" 1 without
  expect 'nessun caso letto: uscita 2, non «fatto»' 2 'nessun caso'
  vero 'nessun caso letto: nessuna chiamata' test "$(chiamate)" = 0
  printf 'print("eval-../../fuori")\n' > "${copia}/prove_skill_casi.py"
  nell_ambiente -- "${copia}/prove_skill.sh" "${ID}" 1 without
  expect 'un nome di caso che diventerebbe un percorso: uscita 2' 2 \
    'eval-../../fuori'
  vero 'un nome di caso sbagliato: nessuna chiamata' test "$(chiamate)" = 0
}

test_prompt_con_chiave() {
  nuovo_ws
  local chiave="sk-ant""-finta-di-prova"
  cat > "${WS}/.claude/skills/${SKILL}/evals/evals.json" <<EOF
{"skill_name": "prova-skill", "evals": [
  {"id": 1, "prompt": "usa ${chiave}", "expected_output": "x"}]}
EOF
  prova "${ID}" 1 without
  expect 'una chiave in un prompt: uscita 2, prima di chiamare' 2 'chiave'
  expect_no 'una chiave in un prompt: non si stampa' 2 "${chiave}"
  vero 'una chiave in un prompt: nessuna chiamata' test "$(chiamate)" = 0
}

test_tre_insieme() {
  nuovo_ws
  local i casi=''
  for i in 1 2 3 4 5 6 7; do
    casi+="${casi:+,}{\"id\": ${i}, \"prompt\": \"caso ${i}\", "
    casi+='"expected_output": "x"}'
  done
  printf '{"skill_name": "%s", "evals": [%s]}\n' "${SKILL}" "${casi}" \
    > "${WS}/.claude/skills/${SKILL}/evals/evals.json"
  nell_ambiente FINTO_PAUSA=0.8 -- "${TOOL}" "${ID}" 1 without
  expect 'sette casi: uscita 0' 0 'Iterazione 1' 'eval-7'
  vero 'sette casi: sette chiamate' test "$(chiamate)" = 7
  registro <<'PY'
eventi = sorted((e["ora"], 1 if e["evento"] == "inizio" else -1) for e in tutti)
adesso = massimo = 0
for _, passo in eventi:
    adesso += passo
    massimo = max(massimo, adesso)
print("massimo", massimo)
PY
  expect 'al massimo tre insieme, e proprio tre' 0 'massimo 3'
}

# --- prima.sh, verifica.py ---------------------------------------------------

test_prima() {
  nuovo_ws
  nell_ambiente PROVA_PRIMA_KO=1 -- "${TOOL}" "${ID}" 1 without
  expect 'prima.sh che fallisce: uscita 2' 2 'prima.sh'
  vero 'prima.sh che fallisce: nessuna chiamata' test "$(chiamate)" = 0
  falso 'prima.sh che fallisce: nessuna cartella di risultati' \
    test -e "${WS}/${SKILL}-workspace"
  vero 'prima.sh che fallisce: nessun temporaneo' temp_pulita
  chmod -x "${ITEM}/prove/prima.sh"
  prova "${ID}" 1 without
  expect 'prima.sh non eseguibile: uscita 2' 2 'prima.sh' 'chmod'
  vero 'prima.sh non eseguibile: nessuna chiamata' test "$(chiamate)" = 0
  chmod +x "${ITEM}/prove/prima.sh"
  mv "${ITEM}/prove/prima.sh" "${TMP}/prima.salvo"
  prova "${ID}" 1 without
  expect 'senza prima.sh si gira lo stesso' 0 'Iterazione 1'
  mv "${TMP}/prima.salvo" "${ITEM}/prove/prima.sh"
  nuovo_ws
  prova "${ID}" 1 without
  expect 'prima.sh: una riga per copia' 0 'Iterazione 1'
  OUT="$(< "${PRIMA_LOG}")"
  RC=0
  expect 'prima.sh: la copia, l id, la cartella corrente' 0 ' 1 ' ' 2 ' ' 3 '
  local riga
  riga="$(head -n 1 "${PRIMA_LOG}")"
  # La cartella corrente è la copia: il primo e il terzo campo coincidono.
  if [[ "${riga%% *}" == "${riga##* }" ]]; then
    pass 'prima.sh: gira nella copia'
  else
    fail "prima.sh: gira nella copia: ${riga}"
  fi
}

test_verifica() {
  nuovo_ws
  mv "${ITEM}/verifica.py" "${TMP}/verifica.salvo"
  prova "${ID}" 1 without
  expect 'verifica.py che manca: uscita 2' 2 'verifica.py'
  vero 'verifica.py che manca: nessuna chiamata' test "$(chiamate)" = 0
  falso 'verifica.py che manca: nessuna cartella di risultati' \
    test -e "${WS}/${SKILL}-workspace"
  mv "${TMP}/verifica.salvo" "${ITEM}/verifica.py"
  nuovo_ws
  nell_ambiente PROVA_USCITA=1 -- "${TOOL}" "${ID}" 1 without
  expect 'verifica.py esce 1: uscita 1' 1
  nuovo_ws
  nell_ambiente PROVA_USCITA=2 -- "${TOOL}" "${ID}" 1 without
  expect 'verifica.py esce 2: uscita 2' 2
  nuovo_ws
  nell_ambiente PROVA_USCITA=7 -- "${TOOL}" "${ID}" 1 without
  expect 'verifica.py fuori contratto: uscita 2' 2 'contratto'
  nuovo_ws
  nell_ambiente "FINTO_CHIAMA_SEMPRE=${SKILL}" -- "${TOOL}" "${ID}" 1 without
  expect 'una garanzia che non regge: uscita 1, con il reperto' 1 \
    'REPERTO iterazione 1, eval-1, without_skill: una chiamata Skill'
  vero 'prove_skill passa PN_HANDSON_ROOT: verifica.py la legge' \
    test -f "$(braccio 1 1 without_skill)/grading.json"
}

test_da_capo_a_fondo() {
  nuovo_ws
  nell_ambiente -- "${REPO}/tools/verifica.sh" "${ID}"
  expect 'il punto di partenza: non ancora' 1 'MANCA' \
    'iterazione 1, eval-1: manca without_skill'
  prova "${ID}" 1 without
  expect 'la baseline' 0 'Iterazione 1'
  prova "${ID}" copia esempio
  expect 'la skill dell esempio' 0 'Copiata'
  prova "${ID}" 1 with
  expect 'la prima versione' 0 'confermata (una sola esecuzione per caso)'
  printf '{"eval-1": "", "eval-2": "manca il riepilogo", "eval-3": ""}\n' \
    > "${WS}/${SKILL}-workspace/iteration-1/feedback.json"
  prova "${ID}" 2 with
  expect 'la seconda, identica: gira' 0 'si riusano'
  nell_ambiente -- "${REPO}/tools/verifica.sh" "${ID}"
  expect 'due versioni uguali: non ancora' 1 'MANCA le due versioni'
  nuovo_ws
  prova "${ID}" 1 without
  prova "${ID}" copia esempio
  prova "${ID}" 1 with
  printf '{"eval-1": "", "eval-2": "manca il riepilogo", "eval-3": ""}\n' \
    > "${WS}/${SKILL}-workspace/iteration-1/feedback.json"
  printf '\nUna riga nuova: VERSIONE-2.\n' \
    >> "${WS}/.claude/skills/${SKILL}/SKILL.md"
  prova "${ID}" 2 with
  expect 'la seconda, diversa' 0 'Iterazione 2'
  nell_ambiente -- "${REPO}/tools/verifica.sh" "${ID}"
  expect 'tutto fatto: verifica.sh esce 0' 0 'VERIFICA OK'
  expect_no 'tutto fatto: nessun MANCA' 0 'MANCA' 'REPERTO'
  vero 'tutto fatto: nessun temporaneo' temp_pulita
}

test_file_e_shellcheck() {
  vero 'lo strumento è eseguibile' test -x "${TOOL}"
  falso 'la libreria non è eseguibile' test -x "${LIB}"
  local f
  for f in tools/prove_skill.sh tools/lib_prove_skill.sh \
      tests/test_prove_skill.sh; do
    OUT="$(cd "${REPO}" && shellcheck -x -- "${f}" 2>&1)"
    RC=$?
    expect_no "shellcheck ${f}" 0 'SC'
  done
}

# Il lancio in background: lì una shell senza job control ignora SIGINT, e un
# segnale ignorato all'ingresso non si può trappare; Ctrl-C in un terminale
# arriva invece con il SIGINT normale. Lo rimette, poi diventa lo strumento.
crea_lancio() {
  cat > "${TMP}/lancio.py" <<'PY'
"""Rimette SIGINT com'è in un terminale ed esegue il comando al suo posto."""
import os
import signal
import sys

signal.signal(signal.SIGINT, signal.SIG_DFL)
os.execv(sys.argv[1], sys.argv[1:])
PY
}

crea_pilota_registro() {
  cat > "${TMP}/registro.py" <<'PY'
"""Il pilota delle domande sul registro del claude finto."""
import json
import os
import sys

with open(os.environ["PN_LOG"], encoding="utf-8") as fh:
    tutti = [json.loads(riga) for riga in fh]
righe = [r for r in tutti if r.get("evento") == "inizio"]
ws = os.environ["PN_WS"]
exec(compile(sys.stdin.read(), "<prova>", "exec"))
PY
}

prepara() {
  local t quale
  for t in python3 git shellcheck; do
    command -v "${t}" >/dev/null 2>&1 || {
      echo "test_prove_skill: manca lo strumento: ${t}" >&2
      exit 2
    }
  done
  handson::init_temp_base
  TMP="$(mktemp -d "${HANDSON_TEMP_BASE}/test_prove_skill.XXXXXX")" || exit 2
  trap 'rm -rf -- "${TMP}"' EXIT
  mkdir -p "${TMP}/bin"
  cp -- "${FINTO}" "${TMP}/bin/claude"
  chmod +x "${TMP}/bin/claude"
  quale="$(PATH="${TMP}/bin:${PATH}" command -v claude)"
  if [[ "${quale}" != "${TMP}/bin/claude" ]]; then
    echo "test_prove_skill: il claude finto non viene prima nel PATH" >&2
    exit 2
  fi
  crea_pilota_registro
  crea_lancio
  crea_albero
}

main() {
  prepara
  test_argomenti
  test_radice
  test_config
  test_copia_esempio
  test_copia_percorso_strano
  test_copia_sopra_altri_file
  test_copia_modello
  test_copia_altro_esempio
  test_without
  test_stdin
  test_effort_modello
  test_with
  test_seconda_iterazione
  test_rifiuti
  test_rifare_come_dice
  test_un_caso_solo
  test_modo_fisso
  test_senza_pgrep
  test_fallite
  test_prompt_intatto
  test_prompt_con_chiave
  test_interruzione
  test_un_giro_per_volta
  test_ambiente_chiave
  test_precedente_fallita
  test_prima_di_chiamare
  test_temp_relativa
  test_chiamata_negata
  test_nessun_caso
  test_tre_insieme
  test_prima
  test_verifica
  test_da_capo_a_fondo
  test_file_e_shellcheck
  echo "PASS=${PASS} FAIL=${FAIL}"
  (( FAIL == 0 )) || exit 1
}

main "$@"
