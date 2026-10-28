#!/bin/bash
#
# test_m4_e05.sh -- le prove di M4-E05 «Il rapporto quotidiano dei log»,
# per il docente:
#   - i file dell'elemento: esercizio/ (SPECIFICA.md, il controllo, le
#     impostazioni con le loro allow e deny, il revisore con tools: Read,
#     Grep, Glob, model: haiku e un formato di risposta), progetti.txt,
#     verita.json (solo impronte, e i giorni) e _docente/verita.py, che la
#     conferma dai log e dalla mappa del docente (0), e su una copia
#     cambiata esce 1; sessioni_claude.py uguale a quello di M4-E04;
#   - il README: le dieci sezioni, i sei prompt fra i segni, il controllo e
#     un comando per volta, il revisore con la @-mention, le frasi di
#     Anthropic e i loro link (le cinque domande prima di un lavoro senza
#     sorveglianza, la quinta con la risposta del laboratorio), nessun
#     identificativo interno, niente macOS né Percorso A; il guasto che la
#     verifica conosce in nessun file dei partecipanti; la prima frase del
#     README e di SPECIFICA.md nomina CiaspoLink; il passo 8 torna in
#     esercitazioni con il suo percorso; la ripresa «più lenta»;
#   - esercizio/controlla_rapporto.py: lo script di riferimento, in Python
#     e chiamato da uno script Bash (0); le varianti che la specifica
#     boccia (1): la fine sbagliata, le linee, gli spazi, l'uscita 0, la
#     cartella e il giorno senza file che passano, gli errori su stdout, una
#     riga per il BGP, l'ordine, la fibra soltanto, l'aiuto su stderr, un
#     file scritto; una variante che lo passa senza leggere i log (0); le
#     precondizioni (2): nessuno script, tutti e due;
#   - verifica.sh con trascrizioni finte (PN_CLAUDE_DIR): il punto di
#     partenza (1); il riferimento (0, il guasto di martedì in ogni campo,
#     lunedì tranquillo, gli altri giorni come dati); le varianti (1),
#     anche quella che passa il controllo ma non i log veri; le altre come
#     dati, mai come uscita; il revisore pulito (0) e quello che modifica
#     (1); meno trascrizioni del revisore che chiamate («non
#     distinguibile», 0); lo spazio di lavoro intatto; le precondizioni
#     (2), anche una trascrizione che non si legge e un errore inatteso (una
#     riga su stderr);
#   - soluzione/applica.sh e tools/run_all.sh M4-E05;
#   - _docente/live.sh con un claude finto: le precondizioni escono 2 senza
#     chiamare claude, anche uno spazio di lavoro che ha già del lavoro (git
#     status non vuoto, o un commit dopo il primo); le due parti (il piano
#     in plan mode, poi --resume in dontAsk, la seconda parte in una
#     sessione nuova), i prompt del README, gli strumenti (nessun grep,
#     find, head, wc, git log né git diff), la chiave tolta, i JSON fuori
#     dallo spazio di lavoro; il lavoro finito nella seconda parte; mai
#     finito (i seguiti, 1); una chiamata fallita (1); il revisore che
#     modifica (1, senza seguiti);
#   - prepara_esercizio.sh e tools/verifica.sh con l'elemento vero;
#   - shellcheck -x sugli script dell'elemento e su questo.
# Gli spazi di lavoro nascono in una cartella temporanea, nella base di
# handson::init_temp_base; le trascrizioni finte in cartelle temporanee
# passate con PN_CLAUDE_DIR, mai in ~/.claude. Un numero di casi diverso da
# CASES esce 2.
#
# Uso:    m4_claude_code_agenti/_docente/test_m4_e05.sh
# Uscita: 0 = tutte le prove passano · 1 = almeno una fallita ·
#         2 = precondizione (manca python3, jq, git o shellcheck; una
#         preparazione non riesce; le prove eseguite non sono quante attese)
set -uo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly MOD="${SELF%/_docente/*}"
readonly RADICE="${MOD%/*}"
readonly LAB="${MOD}/s3_agente_nel_repository/m4_e2_laboratorio"
readonly E05="${LAB}/M4-E05_rapporto_log"
readonly E04="${LAB}/M4-E04_script_operativo"
readonly CLAUDE_FINTO="${MOD}/_docente/claude_finto_m4_e04_e05.py"
readonly RAPPORTO_FINTO="${MOD}/_docente/rapporto_finto_m4_e05.py"
# shellcheck source=../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"
readonly CASES=91
readonly RIFERIMENTO="${E05}/soluzione/rapporto_giornaliero.py"
STRUMENTI='Read,Write,Edit,Bash(python3 controlla_rapporto.py),'
STRUMENTI+='Bash(python3 rapporto_giornaliero.py *),'
STRUMENTI+='Bash(bash rapporto_giornaliero.sh *),Bash(git add *),'
STRUMENTI+='Bash(git commit *)'
readonly STRUMENTI
# Gli identificativi interni che i file per i partecipanti non portano.
INTERNI='FACT-|Tecnodata|[Tt]riage|Envelope|M[0-9]-X[0-9]|\bX-[0-9]'
INTERNI+='|\b(ASK|OQ|DEC|TD|PQ)-[0-9]|\bB#[0-9]'
readonly INTERNI
# Il guasto che la verifica conosce: in nessun file dei partecipanti.
readonly VERITA='olt-pergine-01|0/1/3|10:12|11:40'
TMP=''
VUOTA=''
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
    fail "$1 (rc=${RC}, attesa $2, parola «$3»): ${OUT:0:900}"
  fi
}

# Nessun falso positivo: la parola NON c'è (RU-01.T5).
# Arguments: $1 il nome, $2 la parola.
expect_absent() {
  if grep -qF -- "$2" <<< "${OUT}"; then
    fail "$1: «$2» c'è: ${OUT:0:900}"
  else
    pass "$1"
  fi
}

# La preparazione di una prova che non riesce: uscita 2.
rotta() { echo "test_m4_e05: preparazione non riuscita: $*" >&2; exit 2; }

# Le cartelle temporanee e il claude finto nel PATH.
# Globals: TMP, VUOTA (assegnate).
prepara_ambiente() {
  local t
  for t in python3 jq git shellcheck; do
    command -v "${t}" > /dev/null 2>&1 || rotta "manca ${t}"
  done
  handson::tmpdir TMP
  mkdir -p "${TMP}/bin" "${TMP}/claude-vuota" || rotta "mkdir"
  VUOTA="${TMP}/claude-vuota"
  if ! cp -- "${CLAUDE_FINTO}" "${TMP}/bin/claude" \
      || ! chmod +x "${TMP}/bin/claude"; then
    rotta "il claude finto"
  fi
}

# Uno spazio di lavoro nuovo. Arguments: $1 il nome della radice.
# Outputs: il percorso. Returns: 2 se prepara_esercizio.sh non riesce.
spazio() {
  local radice="${TMP}/$1"
  "${RADICE}/tools/prepara_esercizio.sh" M4-E05 --radice "${radice}" \
    > /dev/null 2>&1 || return 2
  printf '%s\n' "${radice}/M4-E05"
}

# Lo script del partecipante: una variante di rapporto_finto_m4_e05.py.
# Arguments: $1 lo spazio di lavoro, $2 la variante.
variante() {
  printf '%s\n%s\n' \
    "# FINTO: uno script di prova della suite, non di un partecipante" \
    "import subprocess, sys" > "$1/rapporto_giornaliero.py"
  printf 'sys.exit(subprocess.call([sys.executable, "-B", %s, %s, %s]%s))\n' \
    "'${RAPPORTO_FINTO}'" "'$2'" "'${RIFERIMENTO}'" " + sys.argv[1:]" \
    >> "$1/rapporto_giornaliero.py"
}

# Lo script del partecipante in Bash, che chiama il riferimento.
# Arguments: $1 lo spazio di lavoro.
in_bash() {
  printf '#!/bin/bash\n# FINTO: uno script di prova della suite\n%s\n%s\n' \
    'set -euo pipefail' "exec python3 -B '${RIFERIMENTO}' \"\$@\"" \
    > "$1/rapporto_giornaliero.sh"
}

# Il controllo dello spazio di lavoro. Arguments: $1 lo spazio di lavoro.
controllo() {
  # shellcheck disable=SC2016  # $1 è della shell figlia, non di questa
  run bash -c 'cd "$1" && python3 -B -I controlla_rapporto.py' _ "$1"
}

# verifica.sh dell'elemento, senza sessioni salvo le variabili in più.
# Arguments: $1 lo spazio di lavoro, poi variabili d'ambiente.
verifica() {
  local ws="$1"
  shift
  run env PN_HANDSON_ROOT="${RADICE}" PN_CLAUDE_DIR="${VUOTA}" "$@" \
    "${E05}/verifica.sh" "${ws}"
}

# Una chiamata al claude finto nello spazio di lavoro, per le trascrizioni.
# Arguments: $1 lo spazio di lavoro, $2 PN_CLAUDE_DIR, $3 il prompt, poi
# variabili d'ambiente.
finto() {
  local ws="$1" dir="$2" prompt="$3"
  shift 3
  ( cd "${ws}" && env PN_CLAUDE_DIR="${dir}" \
      FINTO_LOG="${TMP}/finto-diretto.log" FINTO_SOLUZIONE="${RIFERIMENTO}" \
      FINTO_RAPPORTO="${RAPPORTO_FINTO}" "$@" "${TMP}/bin/claude" -p \
      --output-format json -- "${prompt}" ) > /dev/null 2>&1
}

# --- i file dell'elemento --------------------------------------------------

test_file() {
  local f manca=''
  echo "== i file dell'elemento"
  for f in README.md progetti.txt verifica.sh verifica.py sessioni_claude.py \
      verita.json esercizio/SPECIFICA.md esercizio/controlla_rapporto.py \
      esercizio/.claude/settings.json esercizio/.claude/agents/revisore.md \
      soluzione/applica.sh soluzione/NOTA.md soluzione/rapporto_giornaliero.py \
      _docente/live.sh _docente/verita.py; do
    [[ -f "${E05}/${f}" ]] || manca+=" ${f}"
  done
  if [[ -z "${manca}" ]]; then
    pass "i file dell'elemento ci sono"
  else
    fail "file mancanti:${manca}"
  fi
  if [[ -x "${E05}/verifica.sh" && -x "${E05}/soluzione/applica.sh" \
      && -x "${E05}/_docente/live.sh" ]]; then
    pass "verifica.sh, applica.sh e live.sh eseguibili"
  else
    fail "verifica.sh, applica.sh o live.sh senza il bit di esecuzione"
  fi
  run cat "${E05}/progetti.txt"
  expect "progetti.txt: la rete" 0 "progetti/rete"
  run cmp "${E05}/sessioni_claude.py" "${E04}/sessioni_claude.py"
  expect "sessioni_claude.py uguale in M4-E05 e M4-E04" 0 ""
}

test_impostazioni() {
  local f="${E05}/esercizio/.claude/settings.json"
  echo "== le impostazioni e il revisore"
  run jq -r --arg s "${STRUMENTI}" '
    (.plansDirectory == "./piani")
    and (.permissions.defaultMode == "default")
    and ((.permissions.allow | sort) == (["Bash(python3 controlla_rapporto.py)",
      "Bash(python3 rapporto_giornaliero.py *)",
      "Bash(bash rapporto_giornaliero.sh *)"] | sort))
    and ((.permissions.allow - ($s | split(","))) == [])
    and ((["Read(**/.env)", "Read(**/.env.*)",
      "Read(**/secrets/**)", "Read(**/*.pem)", "Read(**/*.key)",
      "Edit(/controlla_rapporto.py)", "Edit(/SPECIFICA.md)",
      "Edit(/.claude/agents/**)", "Edit(/progetti/rete/**)"]
      - .permissions.deny) == [])
    | if . then "impostazioni ok" else "impostazioni diverse" end' "${f}"
  expect "settings: piani, Manual, le tre allow (fra gli strumenti), le deny" \
    0 "impostazioni ok"
  run python3 -B -I - "${f}" "${E05}/README.md" <<'PY'
import json
import re
import sys

impostazioni, readme = sys.argv[1:3]
with open(impostazioni, encoding="utf-8") as fh:
    deny = json.load(fh)["permissions"]["deny"]
with open(readme, encoding="utf-8") as fh:
    testo = fh.read()
piatto = " ".join(testo.split())
problemi = []
for regola in deny:
    if not re.match(r"(?:Read|Edit)\((?:\*\*/|/[^/])", regola):
        problemi.append("non ancorata: %s" % regola)
    elif regola.startswith("Edit(/") and regola not in testo:
        problemi.append("il README non la cita: %s" % regola)
frasi = ("`path` or `./path` | Path relative to current directory | "
         "`Read(*.env)` | `<cwd>/*.env`",
         "`/path` | Path relative to the settings source | "
         "`Edit(/src/**/*.ts)` | `<primary working directory>/src/**/*.ts` "
         "in project settings")
for frase in frasi:
    if frase not in piatto:
        problemi.append("manca «%s…»" % frase[:24])
if "https://code.claude.com/docs/en/permissions" not in testo:
    problemi.append("manca https://code.claude.com/docs/en/permissions")
print("; ".join(problemi) or "regole ancorate e citate")
PY
  expect "settings e README: le regole deny ancorate, citate, e perché" 0 \
    "regole ancorate e citate"
  run python3 -B -I - "${E05}/esercizio/.claude/agents/revisore.md" <<'PY'
import re
import sys

testo = open(sys.argv[1], encoding="utf-8").read()
testa = re.match(r"---\n(.*?)\n---\n", testo, re.S)
campi = dict(r.split(":", 1) for r in testa.group(1).splitlines()) \
    if testa else {}
campi = {k.strip(): v.strip() for k, v in campi.items()}
ok = (campi.get("name") == "revisore"
      and campi.get("tools") == "Read, Grep, Glob"
      and campi.get("model") == "haiku"
      and campi.get("description")
      and all(s in testo for s in ("ESITO: OK | DA CORREGGERE", "CONTRATTO:",
                                   "PROBLEMI:", "SPECIFICA.md")))
print("revisore ok" if ok else "revisore diverso: %r" % campi)
PY
  expect "revisore: tools Read, Grep, Glob, haiku, il formato" 0 \
    "revisore ok"
}

test_specifica() {
  local f="${E05}/esercizio/SPECIFICA.md" parola manca=''
  echo "== SPECIFICA.md"
  for parola in fibra radio riavvio voce dhcp PON_LOS PON_LOS_CLEAR \
      'cause LOS' 'link to' rebooting 'router rebooted' 'marked inactive' \
      'marked active' ALLOC_ENGINE_V4_ALLOC_FAIL_SUBNET \
      '--giorno AAAA-MM-GG' '--log <cartella>' '--help' 'TAB' \
      'controlla_rapporto.py' 'manca uno dei tre file' 'non scrive file'; do
    grep -qF -- "${parola}" "${f}" 2> /dev/null || manca+=" «${parola}»"
  done
  if [[ -z "${manca}" ]]; then
    pass "SPECIFICA.md: i tipi, i messaggi, le opzioni, le uscite"
  else
    fail "SPECIFICA.md senza${manca}"
  fi
}

test_verita() {
  local copia="${TMP}/verita-cambiata.json"
  echo "== verita.json e _docente/verita.py"
  run jq -r '[(.richiesto | keys | sort | join(",")), .richiesto.giorno,
      .tranquillo, (.dati | length | tostring)] | join(" ")' \
    "${E05}/verita.json"
  expect "verita.json: il guasto richiesto, il giorno tranquillo, i dati" 0 \
    "apparato,fine,giorno,inizio,linee,nome,porta 2026-09-08 2026-09-07 5"
  run grep -E -- "${VERITA}" "${E05}/verita.json"
  expect "verita.json: nessun valore in chiaro" 1 ""
  run env PN_HANDSON_ROOT="${RADICE}" python3 -B -I \
    "${E05}/_docente/verita.py" --check
  expect "verita.py --check: conferma verita.json" 0 "conferma"
  jq '.richiesto.fine = "00"' "${E05}/verita.json" > "${copia}" \
    2> /dev/null || rotta "la copia di verita.json"
  run env PN_HANDSON_ROOT="${RADICE}" python3 -B -I \
    "${E05}/_docente/verita.py" --check --verita "${copia}"
  expect "verita.py --check su una copia cambiata: 1" 1 "diversa"
}

test_readme() {
  echo "== il README"
  run python3 -B -I - "${E05}/README.md" <<'PY'
import re
import sys

testo = open(sys.argv[1], encoding="utf-8").read()
problemi = []
sezioni = ["Obiettivo", "Tempo", "Prerequisiti", "Punto di partenza",
           "Passi in Claude Code", "Che cosa osservare", "Verifica",
           "Se qualcosa va storto", "Impronta d'uso sul piano Pro",
           "Per approfondire"]
titoli = re.findall(r"^## (.+)$", testo, re.M)
if [t for t in titoli if any(t.startswith(s) for s in sezioni)] != \
        [next(t for t in titoli if t.startswith(s)) for s in sezioni]:
    problemi.append("le dieci sezioni, nell'ordine")
for n in range(1, 7):
    a = testo.count("<!-- prompt %d -->" % n)
    b = testo.count("<!-- /prompt %d -->" % n)
    if (a, b) != (1, 1):
        problemi.append("il prompt %d" % n)
prompt = [" ".join(p.split()) for p in re.findall(
    r"<!-- prompt \d -->(.*?)<!-- /prompt \d -->", testo, re.S)]
piatto = " ".join(testo.split())
for i in (0, 1, 4, 5):
    if i < len(prompt) and "python3 controlla_rapporto.py" not in prompt[i]:
        problemi.append("il controllo nel prompt %d" % (i + 1))
    if i < len(prompt) and "senza concatenarlo ad altri" not in prompt[i]:
        problemi.append("un comando per volta nel prompt %d" % (i + 1))
for i in (2, 4, 5):
    if i < len(prompt) and "@agent-revisore" not in prompt[i]:
        problemi.append("@agent-revisore nel prompt %d" % (i + 1))
frasi = [
    "it's worth going through these five questions with that specific task "
    "in mind: 1. Does it know what done looks like? … 2. Can it check its "
    "own work? … 3. What's it allowed to touch? … 4. What stops it? "
    "--max-turns, --max-budget-usd, a spend limit. 5. Where does the result "
    "go, and who signs off?",
    "«Dove va il risultato, e chi lo approva?»",
    "Give Claude something it can run that comes back pass or fail. Once it "
    "has that, it can keep going on its own",
    "Now it's a reviewer that can't edit anything",
    "enforced by Claude Code",
    "Giving a task fewer tools than the main session has, like a reviewer "
    "that can read but not edit",
    "Set model: haiku in a subagent's definition if its work is simple",
    "https://code.claude.com/docs/en/best-practices",
    "https://code.claude.com/docs/en/sub-agents"]
problemi += ["la frase «%s»" % f[:40] for f in frasi if f not in piatto]
if "quattro domande" in piatto:
    problemi.append("«quattro domande»: sono cinque")
for vietata in ("macOS", "Percorso A", "oggi", "prossima sessione"):
    if re.search(r"\b%s\b" % vietata, testo):
        problemi.append("«%s»" % vietata)
print("README ok" if not problemi else "README: " + "; ".join(problemi))
PY
  expect "README: sezioni, prompt, controllo, revisore, frasi, parole" 0 \
    "README ok"
  run grep -rEn -- "${INTERNI}" "${E05}/README.md" "${E05}/esercizio" \
    "${E05}/verifica.sh" "${E05}/verifica.py" "${E05}/sessioni_claude.py"
  expect "nessun identificativo interno nei file dei partecipanti" 1 ""
  run grep -rEn -- "${VERITA}" "${E05}/README.md" "${E05}/esercizio" \
    "${E05}/verifica.py" "${E05}/verifica.sh" "${E05}/sessioni_claude.py"
  expect "il guasto che la verifica conosce in nessun file dei partecipanti" \
    1 ""
  readme_lab "${E05}" M4-E05
}

# Il README e SPECIFICA.md di una traccia del laboratorio: la prima frase
# nomina CiaspoLink, l'operatore inventato del corso; il passo 8 torna in
# esercitazioni con il suo percorso, non con «cd -»; riprendere una
# conversazione lunga «è più lento», non «costa».
# Arguments: $1 la cartella dell'elemento, $2 il suo identificativo.
readme_lab() {
  run python3 -B -I - "$1/README.md" "$1/esercizio/SPECIFICA.md" "$2" \
    <<'PY'
import sys

readme, specifica, ident = sys.argv[1:4]


def prima_frase(percorso):
    testo = open(percorso, encoding="utf-8").read()
    corpo = [b for b in testo.split("\n\n")
             if b.strip() and not b.lstrip().startswith("#")]
    return " ".join(corpo[0].split()).split(". ")[0] if corpo else ""


frasi = [prima_frase(p) for p in (readme, specifica)]
print("ciaspolink ok" if all("CiaspoLink" in f and "inventato" in f
                             for f in frasi) else "ciaspolink: %s" % frasi)
testo = open(readme, encoding="utf-8").read()
passo = testo.split("\n8. ", 1)[-1].split("\n## ", 1)[0]
blocco = [r.strip() for r in passo.splitlines() if r.startswith("       ")]
print("ritorno ok" if blocco == ["cd ~/esercitazioni",
                                 "tools/verifica.sh %s" % ident]
      else "ritorno: %s" % blocco)
piatto = " ".join(testo.split())
print("ripresa ok" if "è più lento" in piatto and "invece, costa" not in
      piatto else "ripresa: «costa», o niente «è più lento»")
PY
  expect "README e SPECIFICA: la prima frase nomina CiaspoLink" 0 \
    "ciaspolink ok"
  expect "README: il passo 8 torna in esercitazioni, non con cd -" 0 \
    "ritorno ok"
  expect "README: riprendere una conversazione lunga è più lento" 0 \
    "ripresa ok"
}

# --- il controllo dello spazio di lavoro ----------------------------------

test_controllo() {
  local ws v
  echo "== esercizio/controlla_rapporto.py"
  ws="$(spazio controllo)" || rotta "lo spazio di lavoro"
  controllo "${ws}"
  expect "controllo: senza lo script esce 2" 2 "manca rapporto_giornaliero"
  cp -- "${RIFERIMENTO}" "${ws}/rapporto_giornaliero.py" \
    || rotta "il riferimento"
  in_bash "${ws}"
  controllo "${ws}"
  expect "controllo: con tutti e due gli script esce 2" 2 "tutti e due"
  rm -f -- "${ws}/rapporto_giornaliero.sh"
  controllo "${ws}"
  expect "controllo: lo script di riferimento passa" 0 "uscita: 0"
  expect "controllo: otto casi su otto" 0 "8 casi su 8"
  expect_absent "controllo: nessun NO sul riferimento" "NO  "
  run git -C "${ws}" status --porcelain -- . ":!rapporto_giornaliero.py"
  if (( RC == 0 )) && [[ -z "${OUT}" ]]; then
    pass "controllo: nessun file nuovo nello spazio di lavoro"
  else
    fail "controllo: lo spazio di lavoro è cambiato: ${OUT}"
  fi
  rm -f -- "${ws}/rapporto_giornaliero.py"
  in_bash "${ws}"
  controllo "${ws}"
  expect "controllo: il riferimento chiamato da uno script Bash passa" 0 \
    "uscita: 0"
  rm -f -- "${ws}/rapporto_giornaliero.sh"
  for v in "fine-sbagliata:attese e non trovate" \
      "senza-linee:attese e non trovate" "spazi:non sono nel formato" \
      "uscita-zero:uscita 0, attesa 1" "cartella-zero:uscita 0, attesa 2" \
      "giorno-vuoto:uscita 0, attesa 2" "errori-stdout:su stdout" \
      "bgp:uscita 1, attesa 0" "ordine:in ordine di inizio" \
      "fibra-sola:attese e non trovate" "aiuto-stderr:non nomina" \
      "scrive-file:la cartella dei log è cambiata"; do
    variante "${ws}" "${v%%:*}"
    controllo "${ws}"
    expect "controllo: la variante ${v%%:*} esce 1" 1 "${v#*:}"
  done
  variante "${ws}" prova-fissa
  controllo "${ws}"
  expect "controllo: prova-fissa passa senza leggere i log" 0 "8 casi su 8"
}

# --- verifica.sh ----------------------------------------------------------

test_verifica() {
  local ws prima dopo v
  echo "== verifica.sh"
  ws="$(spazio verifica)" || rotta "lo spazio di lavoro"
  verifica "${ws}"
  expect "verifica: il punto di partenza esce 1" 1 \
    "manca rapporto_giornaliero"
  expect "verifica: il punto di partenza, nessun subagent come dato" 1 \
    "nessun subagent trovato"
  verifica "${TMP}/non-esiste"
  expect "verifica: spazio di lavoro assente esce 2" 2 "assente"
  cp -- "${RIFERIMENTO}" "${ws}/rapporto_giornaliero.py" \
    || rotta "il riferimento"
  mkdir -p "${TMP}/radice-vuota" || rotta "mkdir"
  verifica "${ws}" PN_HANDSON_ROOT="${TMP}/radice-vuota"
  expect "verifica: senza i log originali della rete esce 2" 2 \
    "log della rete"
  prima="$(git -C "${ws}" status --porcelain --ignored | sort)"
  verifica "${ws}"
  expect "verifica: il riferimento passa" 0 "Fatto"
  expect "verifica: il guasto di martedì, campo per campo" 0 \
    "apparato sì · porta sì · inizio sì · fine sì · linee sì"
  expect "verifica: lunedì è tranquillo" 0 \
    "un giorno tranquillo: uscita 0, nessuna riga"
  expect "verifica: gli altri giorni come dati" 0 \
    "(dato) sabato 12: uscita 1, 1 riga; il disservizio che la verifica \
conosce: trovato"
  expect_absent "verifica: nessun valore atteso stampato" "olt-pergine-01"
  expect_absent "verifica: nessuna ora attesa stampata" "11:40"
  dopo="$(git -C "${ws}" status --porcelain --ignored | sort)"
  if [[ "${prima}" == "${dopo}" ]]; then
    pass "verifica: lo spazio di lavoro resta com'era"
  else
    fail "verifica: lo spazio di lavoro è cambiato"
  fi
  in_bash "${ws}"
  verifica "${ws}"
  expect "verifica: con tutti e due gli script, non ancora" 1 "tutti e due"
  rm -f -- "${ws}/rapporto_giornaliero.sh"
  for v in "prova-fissa:apparato no" "fine-sbagliata:fine no" \
      "senza-linee:linee no" "bgp:un giorno tranquillo: uscita 1" \
      "uscita-zero:uscita 0, attesa 1"; do
    variante "${ws}" "${v%%:*}"
    verifica "${ws}"
    expect "verifica: la variante ${v%%:*} esce 1" 1 "${v#*:}"
  done
  variante "${ws}" prova-fissa
  verifica "${ws}"
  expect "verifica: prova-fissa passa il controllo del partecipante" 1 \
    "8 casi su 8"
  variante "${ws}" fibra-sola
  verifica "${ws}"
  expect "verifica: gli altri giorni, non trovati, restano dati" 1 \
    "(dato) giovedì 10: uscita 0, nessuna riga; il disservizio che la \
verifica conosce: non trovato"
  expect_absent "verifica: gli altri giorni non sono un motivo" "giovedì 10 non"
}

test_verifica_sessioni() {
  local ws dir
  echo "== verifica.sh: le sessioni e il revisore"
  ws="$(spazio sessioni)" || rotta "lo spazio di lavoro"
  dir="${TMP}/claude-sessioni"
  finto "${ws}" "${dir}" "Il piano va bene: (finto)"
  finto "${ws}" "${dir}" "Prima del commit che chiude il rapporto (finto)"
  verifica "${ws}" PN_CLAUDE_DIR="${dir}"
  expect "verifica: con il revisore pulito passa" 0 "la garanzia vale"
  expect "verifica: le chiamate Agent come dato" 0 \
    "chiamate al tool Agent: 1 (revisore 1)"
  expect "verifica: il controllo eseguito da Claude, come dato" 0 \
    "il controllo eseguito da Claude: 1 volta, l'ultima con uscita 0"
  ws="$(spazio modifica)" || rotta "lo spazio di lavoro"
  dir="${TMP}/claude-modifica"
  finto "${ws}" "${dir}" "Il piano va bene: (finto)"
  finto "${ws}" "${dir}" "Prima del commit che chiude (finto)" \
    FINTO_REVISORE=modifica
  verifica "${ws}" PN_CLAUDE_DIR="${dir}"
  expect "verifica: il revisore che modifica è una segnalazione" 1 \
    "non ha tenuto"
  trascrizioni_mancanti
}

# Le trascrizioni del revisore che mancano o non si leggono, e un errore
# inatteso della verifica (un collegamento rotto fra i log di un
# repository di prova).
trascrizioni_mancanti() {
  local ws dir err rc=0 log="${TMP}/radice-rotta/progetti/rete/log"
  local -a tr
  ws="$(spazio due-revisioni)" || rotta "lo spazio di lavoro"
  dir="${TMP}/claude-due-revisioni"
  finto "${ws}" "${dir}" "Il piano va bene: (finto)"
  finto "${ws}" "${dir}" "Prima del commit che chiude (finto)"
  finto "${ws}" "${dir}" "Prima del commit che chiude (finto)"
  tr=("${dir}"/projects/*/*/subagents/agent-*.jsonl)
  (( ${#tr[@]} == 2 )) || rotta "le due trascrizioni del revisore"
  rm -f -- "${tr[0]}" || rotta "rm"
  verifica "${ws}" PN_CLAUDE_DIR="${dir}"
  expect "verifica: due chiamate, una trascrizione: non distinguibile" 0 \
    "non distinguibile"
  expect_absent "verifica: due chiamate, una trascrizione: mai «vale»" \
    "la garanzia vale"
  if ! rm -f -- "${tr[1]}" || ! mkdir -- "${tr[1]}"; then
    rotta "una cartella al posto della trascrizione"
  fi
  verifica "${ws}" PN_CLAUDE_DIR="${dir}"
  expect "verifica: una trascrizione che non si legge esce 2" 2 \
    "non si legge"
  ws="$(spazio inatteso)" || rotta "lo spazio di lavoro"
  cp -- "${RIFERIMENTO}" "${ws}/rapporto_giornaliero.py" \
    || rotta "il riferimento"
  mkdir -p "${log}/syslog" || rotta "mkdir"
  : > "${log}/syslog/syslog_2026-09-08.log" || rotta "il log"
  ln -s "${TMP}/non-esiste" "${log}/syslog/rotto.log" || rotta "ln"
  err="$(env PN_HANDSON_ROOT="${TMP}/radice-rotta" PN_CLAUDE_DIR="${VUOTA}" \
    "${E05}/verifica.sh" "${ws}" 2>&1 > /dev/null)" || rc=$?
  if (( rc == 2 )) && grep -qF "errore inatteso" <<< "${err}" \
      && (( $(wc -l <<< "${err}") == 1 )); then
    pass "verifica: un errore inatteso esce 2, una riga su stderr"
  else
    fail "verifica: un errore inatteso (rc=${rc}): ${err:0:600}"
  fi
}

# --- la soluzione e run_all -----------------------------------------------

test_soluzione() {
  local ws
  echo "== soluzione/applica.sh e tools/run_all.sh"
  ws="$(spazio applica)" || rotta "lo spazio di lavoro"
  run "${E05}/soluzione/applica.sh" "${ws}"
  expect "applica.sh: applica la soluzione" 0 ""
  if cmp -s "${RIFERIMENTO}" "${ws}/rapporto_giornaliero.py" \
      && [[ -f "${ws}/NOTA.md" ]]; then
    pass "applica.sh: lo script e NOTA.md"
  else
    fail "applica.sh: manca lo script o NOTA.md"
  fi
  verifica "${ws}"
  expect "applica.sh: poi la verifica passa" 0 "Fatto"
  run "${E05}/soluzione/applica.sh" "${TMP}/non-esiste"
  expect "applica.sh: spazio di lavoro assente esce 2" 2 "assente"
  run "${RADICE}/tools/run_all.sh" M4-E05
  expect "tools/run_all.sh M4-E05" 0 "1 ok, 0 KO"
}

# --- live.sh, con il claude finto ------------------------------------------

# Le chiamate del claude finto, una riga ciascuna: modo, resume, modello,
# effort, mcp, strumenti, chiave, prompt (impronta).
chiamate() {
  python3 -B -I - "$1" <<'PY'
import hashlib
import json
import sys

for riga in open(sys.argv[1], encoding="utf-8"):
    a = json.loads(riga)["argv"]
    chiave = json.loads(riga)["chiave"]

    def val(o):
        return a[a.index(o) + 1] if o in a else "-"

    p = a[a.index("--") + 1] if "--" in a else ""
    print("\t".join([val("--permission-mode"), val("--resume"),
                     val("--model"), val("--effort"),
                     "mcp" if "--strict-mcp-config" in a else "-",
                     val("--allowedTools"), str(chiave),
                     hashlib.sha256(p.encode()).hexdigest()[:16]]))
PY
}

# Le impronte dei prompt del README, nell'ordine 1…6.
impronte_readme() {
  python3 -B -I - "${E05}/README.md" <<'PY'
import hashlib
import sys
import textwrap

righe = open(sys.argv[1], encoding="utf-8").read().split("\n")
for n in range(1, 7):
    a = [i for i, r in enumerate(righe)
         if r.strip() == "<!-- prompt %d -->" % n]
    b = [i for i, r in enumerate(righe)
         if r.strip() == "<!-- /prompt %d -->" % n]
    testo = textwrap.dedent("\n".join(righe[a[0] + 1:b[0]])).strip("\n")
    print(hashlib.sha256(testo.encode()).hexdigest()[:16])
PY
}

# live.sh nello spazio di lavoro, con il claude finto.
# Arguments: $1 lo spazio di lavoro, $2 il nome della prova, poi variabili.
live() {
  local ws="$1" nome="$2"
  shift 2
  run env PATH="${TMP}/bin:${PATH}" HANDSON_NO_PAUSE=1 \
    PN_CLAUDE_DIR="${TMP}/claude-${nome}" FINTO_LOG="${TMP}/finto-${nome}.log" \
    FINTO_SOLUZIONE="${RIFERIMENTO}" FINTO_RAPPORTO="${RAPPORTO_FINTO}" \
    ANTHROPIC_API_KEY=finta-chiave-di-prova "$@" "${E05}/_docente/live.sh" \
    "${ws}"
}

test_live() {
  local ws righe attese
  echo "== _docente/live.sh, con il claude finto"
  live "${TMP}/non-esiste" assente
  expect "live: spazio di lavoro assente esce 2" 2 "assente"
  if [[ ! -s "${TMP}/finto-assente.log" ]]; then
    pass "live: senza spazio di lavoro nessuna chiamata a claude"
  else
    fail "live: ha chiamato claude senza spazio di lavoro"
  fi
  ws="$(spazio live-sporco)" || rotta "lo spazio di lavoro"
  : > "${ws}/NOTA.md"
  live "${ws}" sporco
  if (( RC == 2 )) && grep -qF "tools/reset_esercizio.sh M4-E05" \
      <<< "${OUT}" && [[ ! -s "${TMP}/finto-sporco.log" ]]; then
    pass "live: git status non vuoto esce 2 con il reset, senza claude"
  else
    fail "live: git status non vuoto (rc=${RC}): ${OUT:0:400}"
  fi
  ws="$(spazio live-commit)" || rotta "lo spazio di lavoro"
  git -C "${ws}" -c user.name=Prova -c user.email=prova@example.org \
    commit -q --allow-empty -m "lavoro di prima" || rotta "git commit"
  live "${ws}" commit
  if (( RC == 2 )) && grep -qF "tools/reset_esercizio.sh M4-E05" \
      <<< "${OUT}" && [[ ! -s "${TMP}/finto-commit.log" ]]; then
    pass "live: un commit dopo il primo esce 2 con il reset, senza claude"
  else
    fail "live: un commit dopo il primo (rc=${RC}): ${OUT:0:400}"
  fi
  ws="$(spazio live-completo)" || rotta "lo spazio di lavoro"
  live "${ws}" completo
  expect "live: il lavoro completo, la verifica passa" 0 "Fatto"
  righe="$(chiamate "${TMP}/finto-completo.log")"
  attese="$(printf '%s\t%s\tsonnet\tmedium\tmcp\t%s\tFalse\n' \
    plan - "${STRUMENTI}" \
    dontAsk sessione-finta-001 "${STRUMENTI}" \
    dontAsk sessione-finta-001 "${STRUMENTI}" \
    dontAsk sessione-finta-001 "${STRUMENTI}" \
    dontAsk - "${STRUMENTI}")"
  if [[ "$(cut -f1-7 <<< "${righe}")" == "${attese}" ]]; then
    pass "live: cinque turni, plan e poi --resume, la sessione nuova"
  else
    fail "live: i turni non sono quelli attesi: ${righe}"
  fi
  if [[ "$(cut -f8 <<< "${righe}")" \
      == "$(impronte_readme | head -n 5)" ]]; then
    pass "live: i prompt 1…5 sono quelli del README"
  else
    fail "live: i prompt non sono quelli del README"
  fi
  if [[ -f "${ws}.prova_dal_vivo/turno-5.json" && ! -e "${ws}/prova_dal_vivo" \
      && ! -e "${ws}/turno-1.json" ]]; then
    pass "live: i JSON fuori dallo spazio di lavoro"
  else
    fail "live: i JSON non sono in ${ws}.prova_dal_vivo/"
  fi
  test_live_varianti
}

test_live_varianti() {
  local ws righe
  ws="$(spazio live-meta)" || rotta "lo spazio di lavoro"
  live "${ws}" meta FINTO_LAVORO=a_meta
  expect "live: finito nella seconda parte" 0 "Fatto"
  if (( "$(wc -l < "${TMP}/finto-meta.log")" == 5 )); then
    pass "live: finito alla sessione nuova, nessun seguito"
  else
    fail "live: chiamate diverse da cinque nella prova a metà"
  fi
  ws="$(spazio live-mai)" || rotta "lo spazio di lavoro"
  live "${ws}" mai FINTO_LAVORO=mai FINTO_MAI=1
  expect "live: mai finito esce 1" 1 "VERIFICA KO"
  righe="$(chiamate "${TMP}/finto-mai.log")"
  if (( "$(wc -l <<< "${righe}")" == 7 )) \
      && [[ "$(sed -n '6p;7p' <<< "${righe}" | cut -f2 | sort -u)" \
        == "sessione-finta-005" \
      && "$(sed -n '6p;7p' <<< "${righe}" | cut -f8 | sort -u)" \
        == "$(impronte_readme | sed -n '6p')" ]]; then
    pass "live: due seguiti con il prompt 6, ripresi dalla sessione nuova"
  else
    fail "live: i seguiti non sono quelli attesi: ${righe}"
  fi
  ws="$(spazio live-ko)" || rotta "lo spazio di lavoro"
  live "${ws}" ko FINTO_KO_ALLA=2
  expect "live: una chiamata fallita esce 1" 1 "turno 2"
  ws="$(spazio live-modifica)" || rotta "lo spazio di lavoro"
  live "${ws}" modifica FINTO_REVISORE=modifica
  expect "live: il revisore che modifica esce 1" 1 "non ha tenuto"
  if (( "$(wc -l < "${TMP}/finto-modifica.log")" == 5 )); then
    pass "live: con la segnalazione sul revisore nessun seguito"
  else
    fail "live: seguiti dopo la segnalazione sul revisore"
  fi
}

# --- prepara_esercizio.sh, tools/verifica.sh, shellcheck -------------------

test_prepara() {
  local radice="${TMP}/vero-prepara" ws f manca=''
  echo "== prepara_esercizio.sh e tools/verifica.sh"
  run "${RADICE}/tools/prepara_esercizio.sh" M4-E05 --radice "${radice}"
  expect "prepara: lo spazio di lavoro pronto" 0 "Spazio di lavoro pronto"
  ws="${radice}/M4-E05"
  for f in SPECIFICA.md controlla_rapporto.py .claude/settings.json \
      .claude/agents/revisore.md progetti/rete/README.md \
      progetti/rete/log/syslog/syslog_2026-09-08.log \
      progetti/rete/log/dhcp/kea-dhcp4_2026-09-12.log; do
    [[ -f "${ws}/${f}" ]] || manca+=" ${f}"
  done
  if [[ -z "${manca}" ]]; then
    pass "prepara: i file del punto di partenza"
  else
    fail "prepara: mancano${manca}"
  fi
  if [[ ! -e "${ws}/progetti/rete/_docente" && ! -e "${ws}/verita.json" \
      && ! -e "${ws}/soluzione" && ! -e "${ws}/_docente" \
      && ! -e "${ws}/rapporto_giornaliero.py" ]]; then
    pass "prepara: niente verità, soluzione né materiale del docente"
  else
    fail "prepara: nello spazio di lavoro c'è ciò che non deve esserci"
  fi
  run "${RADICE}/tools/verifica.sh" M4-E05 --radice "${radice}"
  expect "tools/verifica.sh sul punto di partenza: NON ANCORA" 1 \
    "NON ANCORA"
}

test_shellcheck() {
  echo "== shellcheck"
  run shellcheck -x "${E05}/verifica.sh" "${E05}/soluzione/applica.sh" \
    "${E05}/_docente/live.sh" "${MOD}/_docente/lib_live_m4_e04_e05.sh" "${SELF}"
  expect "shellcheck -x pulito" 0 ""
}

main() {
  prepara_ambiente
  test_file
  test_impostazioni
  test_specifica
  test_verita
  test_readme
  test_controllo
  test_verifica
  test_verifica_sessioni
  test_soluzione
  test_live
  test_prepara
  test_shellcheck
  echo "PASS=${PASS} FAIL=${FAIL} (attese ${CASES})"
  if (( PASS + FAIL != CASES )); then
    echo "test_m4_e05: eseguite $((PASS + FAIL)) prove, attese ${CASES}" >&2
    exit 2
  fi
  (( FAIL == 0 )) || exit 1
}

main "$@"
