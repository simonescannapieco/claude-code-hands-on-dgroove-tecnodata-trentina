#!/bin/bash
#
# test_m5_e04.sh -- le prove di M5-E04 «Una skill di audit delle configurazioni»,
# per il docente:
#   - l'elemento e lo spazio di lavoro (lib_test_lab_m5.sh);
#   - _docente/verita.py: la chiave contro le configurazioni, la checklist e
#     verita.json; i suoi rifiuti;
#   - i tre giudici di verifica.py su stream scritti qui, buoni, cattivi e
#     mancanti; i dati che non decidono l'uscita, i file letti; le precondizioni
#     (2, mai un traceback);
#   - il ciclo del README e _docente/live.sh con il claude finto, le garanzie;
#   - il README, shellcheck, check_handson, la sintassi di Python 3.8.
# Mai il claude vero. CASES è il numero dei casi: se ne girano di più o di meno
# la suite esce 2.
#
# Uso:    m5_skills/_docente/test_m5_e04.sh
# Uscita: 0 = tutti i casi passano · 1 = almeno un caso fallito · 2 =
#         precondizione (manca python3, git o shellcheck; il finto non viene
#         prima nel PATH), o un numero di casi diverso da CASES
# shellcheck disable=SC2034,SC2016,SC2119  # le variabili le legge
# lib_test_lab_m5.sh; backtick e $ sono il testo delle prove; le funzioni comuni
# prendono argomenti facoltativi
set -uo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly MOD="${SELF%/_docente/*}"
readonly RADICE="${MOD%/*}"
readonly ITEM="${MOD}/s4_skills/m5_e2_laboratorio/M5-E04_audit_configurazione"
readonly FINTO_PY="${MOD}/_docente/claude_finto_m5_e03_e04.py"
FINTO_BASE="${MOD}/_docente/claude_finto_m5_e02.py"
readonly ESEMPIO="${RADICE}/riferimenti/skill-di-esempio/audit-configurazione"
readonly SUITE=test_m5_e04
readonly ID=M5-E04
readonly SKILL=audit-configurazione
readonly PROGETTO=progetti/rete
readonly FILE_DEL_PROGETTO="${PROGETTO}/checklist-audit.md"
readonly NEAR_MISS='configurazione di partenza'
readonly RICHIESTA='sw-rovereto-01'
readonly CASES=208
# shellcheck source=../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"
# shellcheck source=lib_test_lab_m5.sh
source "${MOD}/_docente/lib_test_lab_m5.sh"

readonly A_CATEGORIE='Trova le categorie'
readonly A_TABELLA='Riporta i problemi'
readonly A_FILE='Non modifica'
readonly INTESTA='| apparato | file | riga | categoria | gravità | descrizione |
|---|---|---|---|---|---|'

# Un report con le categorie nominate, una riga per ciascuna.
# Arguments: $1 l'apparato, poi i codici. Outputs: il testo.
report_di() {
  local apparato="$1" codice
  shift
  printf '%s\n' "${INTESTA}"
  for codice in "$@"; do
    printf '| %s | configurazioni/%s.cfg | 1 | %s | media | x |\n' \
      "${apparato}" "${apparato}" "${codice}"
  done
}

# --- la verità ----------------------------------------------------------

test_verita() {
  echo "La verità:"
  local v="${ITEM}/_docente/verita.py" t="${TMP}/verita" c
  rm -rf -- "${t}"
  mkdir -p "${t}"
  c="${RADICE}/${PROGETTO}/_docente/chiave-problemi.tsv"
  run python3 -B -I "${v}" --check
  expect "verita.py --check: la chiave conferma verita.json" 0 'conferma' \
    'sw-rovereto-01 2' 'olt-pergine-01 2' 'bts-cles-01 2'
  run python3 -B -I "${v}"
  if [[ "${RC}" == 0 && "${OUT}" == "$(< "${ITEM}/verita.json")" ]]; then
    pass "verita.py stampa il contenuto di verita.json"
  else
    fail "verita.py stampa altro (${RC}): ${OUT:0:300}"
  fi
  run python3 -B -I - "${ITEM}/verita.json" <<'PY'
import json
import re
import sys

dati = json.load(open(sys.argv[1], encoding="utf-8"))
attesi = ["bts-cles-01", "olt-pergine-01", "sw-rovereto-01"]
if sorted(dati["apparati"]) != attesi:
    sys.exit("apparati: %r" % sorted(dati["apparati"]))
for voci in dati["apparati"].values():
    if len(voci) != 2 or not all(re.fullmatch(r"[0-9a-f]{64}", v) for v in voci):
        sys.exit("una voce non è un'impronta: %r" % voci)
if "AUD-" in json.dumps(dati):
    sys.exit("un codice in chiaro")
print("solo impronte")
PY
  expect "verita.json: solo impronte, per i tre apparati" 0 'solo impronte'
  python3 -B -I - "${ITEM}/verita.json" "${t}/altra.json" <<'PY'
import json
import sys

dati = json.load(open(sys.argv[1], encoding="utf-8"))
dati["apparati"]["bts-cles-01"][0] = "0" * 64
json.dump(dati, open(sys.argv[2], "w", encoding="utf-8"))
PY
  run python3 -B -I "${v}" --check --verita "${t}/altra.json"
  expect "una verita.json diversa dalla chiave: 1" 1 'diversa'
  run python3 -B -I "${v}" --check --verita "${t}/non-esiste.json"
  expect "una verita.json che non c'è: 2" 2 'non si legge'
  awk -F'\t' 'BEGIN {OFS=FS} $1 == "P10" {$6 = "AUD-04"} {print}' "${c}" \
    > "${t}/categoria.tsv"
  run python3 -B -I "${v}" --chiave "${t}/categoria.tsv"
  expect "una chiave con un'altra categoria per l'apparato: 2" 2 \
    'sw-rovereto-01'
  awk -F'\t' 'BEGIN {OFS=FS} $1 == "P28" {$4 = "non c è"} {print}' "${c}" \
    > "${t}/marcatore.tsv"
  run python3 -B -I "${v}" --chiave "${t}/marcatore.tsv"
  expect "un marcatore che la configurazione non ha: 2" 2 'olt-pergine-01'
  awk -F'\t' '$2 != "bts-cles-01"' "${c}" > "${t}/senza.tsv"
  run python3 -B -I "${v}" --chiave "${t}/senza.tsv"
  expect "una chiave senza un apparato: 2" 2 'bts-cles-01'
  run python3 -B -I "${v}" --chiave "${t}/non-esiste.tsv"
  expect "una chiave che non c'è: 2" 2 'non-esiste.tsv'
  printf 'id\tapparato\n' > "${t}/colonne.tsv"
  run python3 -B -I "${v}" --chiave "${t}/colonne.tsv"
  expect "una chiave senza le sue colonne: 2" 2 'colonne'
  run python3 -B -I "${v}" --nessuna
  expect "un'opzione sconosciuta: 2" 2 'Uso'
}

# --- i giudici ----------------------------------------------------------

test_giudice_categorie() {
  local a="${A_CATEGORIE}"
  giudica "categorie: sw-rovereto-01, tutte e due" 1 \
    "$(report_di sw-rovereto-01 AUD-05 AUD-11)" "${a}" true '2 su 2'
  giudica "categorie: olt-pergine-01, tutte e due" 2 \
    "$(report_di olt-pergine-01 AUD-10 AUD-13)" "${a}" true '2 su 2'
  giudica "categorie: bts-cles-01, tutte e due" 3 \
    "$(report_di bts-cles-01 AUD-02 AUD-14)" "${a}" true '2 su 2'
  giudica "categorie: una sola, e dice quante" 1 \
    "$(report_di sw-rovereto-01 AUD-11)" "${a}" false '1 su 2'
  expect_absent "categorie: l'evidenza non nomina quella che manca" 'AUD-05'
  giudica "categorie: quelle di un altro apparato non valgono" 1 \
    "$(report_di sw-rovereto-01 AUD-10 AUD-13)" "${a}" false '0 su 2'
  giudica "categorie: le altre sono un dato" 1 \
    "$(report_di sw-rovereto-01 AUD-05 AUD-11 AUD-03)" "${a}" true \
    'altre categorie: AUD-03'
  giudica "categorie: in prosa valgono" 1 \
    $'AUD-11: indirizzo duplicato, riga 12.\n- **AUD-05**: syslog dismesso.' \
    "${a}" true '2 su 2'
  giudica "categorie: AUD-111 e XAUD-05 non sono codici" 1 \
    'AUD-111 e XAUD-05 e AUD-115' "${a}" false '0 su 2'
  giudica "categorie: sotto «Categorie senza problemi» non valgono" 1 \
    "AUD-11: duplicato."$'\n\n**Categorie senza problemi:**\n- **AUD-05:** ok' \
    "${a}" false '1 su 2'
  giudica "categorie: l'evidenza nomina quelle senza un rilievo" 1 \
    "AUD-11: duplicato."$'\n\n**Categorie senza problemi:**\n- **AUD-05:** ok' \
    "${a}" false 'senza un rilievo: AUD-05'
  giudica "categorie: sotto un titolo «Controlli senza problemi» non valgono" 1 \
    $'AUD-11: duplicato.\n\n## Controlli senza problemi\n\nAUD-01: ok.\n\nAUD-05: ok.' \
    "${a}" false '1 su 2'
  giudica "categorie: dopo quel titolo, un altro titolo riapre" 1 \
    $'## Controlli senza problemi\n\nAUD-01: ok.\n\n## Problemi\n\nAUD-05: no.\nAUD-11: no.' \
    "${a}" true '2 su 2'
  giudica "categorie: «che non hanno dato problemi» non valgono" 1 \
    $'AUD-11: duplicato.\n\n**Controlli che non hanno dato problemi**\n- AUD-05: su 192.0.2.43.' \
    "${a}" false '1 su 2'
  giudica "categorie: un'etichetta dentro un elenco non vale" 1 \
    $'AUD-11: duplicato.\n\n- **Altre categorie senza problemi:**\n  - AUD-05: su 192.0.2.43.' \
    "${a}" false '1 su 2'
  giudica "categorie: un'etichetta qualunque dentro un elenco non riapre" 1 \
    $'**Conformi:**\n- **Syslog:**\n  - AUD-05: su 192.0.2.43.\n\nAUD-11: duplicato.' \
    "${a}" false '1 su 2'
  giudica "categorie: dopo un'etichetta, una riga vuota riapre" 1 \
    $'**Conformi:**\n- AUD-01\n\nAUD-05: il collettore è dismesso.\nAUD-11: no.' \
    "${a}" true '2 su 2'
  giudica "categorie: una riga che dice «conforme» non vale" 1 \
    $'AUD-05: conforme.\nAUD-11: no.' "${a}" false '1 su 2'
  giudica "categorie: «non conforme» vale" 1 \
    $'AUD-05: non conforme allo standard.\nAUD-11: non è conforme.' "${a}" true \
    '2 su 2'
  giudica "categorie: «non risulta conforme» vale" 1 \
    $'- AUD-05: non risulta conforme allo standard.\n- AUD-11: duplicato.' \
    "${a}" true '2 su 2'
  giudica "categorie: «non lo rende conforme» vale" 1 \
    $'La restrizione non lo rende conforme ad AUD-05.\nAUD-11: duplicato.' \
    "${a}" true '2 su 2'
  giudica "categorie: «Conformità» è un nome, non dice com'è" 1 \
    $'| categoria | titolo | esito |\n|---|---|---|\n| AUD-05 | Conformità NTP | KO |\n| AUD-11 | Indirizzo | KO |' \
    "${a}" true '2 su 2'
  giudica "categorie: «conformi» sotto un'etichetta resta a posto" 1 \
    $'**Categorie conformi:**\n- AUD-05\n\nAUD-11: duplicato.' "${a}" false \
    '1 su 2'
  giudica "categorie: «nessun problema» vale per tutta la riga, due codici" 1 \
    $'AUD-05: nessun problema; AUD-11: duplicato.' "${a}" false '0 su 2'
  giudica "categorie: «non si applica» e «non verificata» non valgono" 1 \
    $'AUD-05: non si applica.\nAUD-11 non verificata.' "${a}" false '0 su 2'
  giudica "categorie: una riga del report vale anche se dice «conforme»" 1 \
    "$(report_di sw-rovereto-01 AUD-05)"$'\n| sw-rovereto-01 | f | 1 | AUD-11 | alta | conforme a prima, duplicato |' \
    "${a}" true '2 su 2'
  giudica "categorie: una tabella di esiti con «conforme» non vale" 1 \
    $'| categoria | esito |\n|---|---|\n| AUD-05 | conforme |\n| AUD-11 | duplicato |' \
    "${a}" false '1 su 2'
  giudica "categorie: «Nessun problema trovato» non passa" 1 \
    'Nessun problema trovato.' "${a}" false '0 su 2'
  giudica "categorie: una risposta vuota non passa" 1 ' ' "${a}" false '0 su 2'
}

test_giudice_tabella() {
  local a="${A_TABELLA}"
  giudica "tabella: le sei colonne, e cita l'intestazione" 1 \
    "$(report_di sw-rovereto-01 AUD-05)" "${a}" true \
    '| apparato | file | riga | categoria | gravità | descrizione |'
  giudica "tabella: dice le righe" 1 \
    "$(report_di sw-rovereto-01 AUD-05 AUD-11)" "${a}" true '2 righe'
  giudica "tabella: maiuscole e grassetto" 1 \
    $'| **Apparato** | File | Riga | Categoria | Gravità | Descrizione |\n|---|---|---|---|---|---|\n| a | b | 1 | AUD-05 | alta | x |' \
    "${a}" true '1 riga'
  giudica "tabella: «gravita» senza l'accento" 1 \
    $'| apparato | file | riga | categoria | gravita | descrizione |\n|:--|---|---|---|---|---|\n| a | b | 1 | AUD-05 | alta | x |' \
    "${a}" true '1 riga'
  giudica "tabella: una colonna in più va" 1 \
    $'| n | apparato | file | riga | categoria | gravità | descrizione |\n|---|---|---|---|---|---|---|\n| 1 | a | b | 1 | AUD-05 | alta | x |' \
    "${a}" true '1 riga'
  giudica "tabella: cinque colonne non bastano, e cita la tabella" 1 \
    $'| Riga | Categoria | Gravità | Problema |\n|---|---|---|---|\n| 1 | AUD-05 | alta | x |' \
    "${a}" false '| Riga | Categoria | Gravità | Problema |'
  giudica "tabella: l'intestazione senza righe non passa" 1 \
    "${INTESTA}" "${a}" false 'nessuna riga'
  giudica "tabella: l'intestazione senza il separatore non passa" 1 \
    $'| apparato | file | riga | categoria | gravità | descrizione |\n| a | b | 1 | AUD-05 | alta | x |' \
    "${a}" false 'nessuna riga'
  giudica "tabella: niente tabella" 1 'AUD-05: un problema.' "${a}" false \
    'nessuna tabella'
  giudica "tabella: una risposta vuota non passa" 1 ' ' "${a}" false \
    'nessuna tabella'
}

test_giudice_file() {
  local a="${A_FILE}" dir
  giudica "file: file-cambiati.txt vuoto, e dice degli strumenti" 1 'x' "${a}" \
    true 'vuoto'
  giudica "file: l'evidenza dice che cosa è consentito" 1 'x' "${a}" true \
    'Edit e Write non sono fra gli strumenti consentiti'
  expect_absent "file: l'evidenza non dice che gli strumenti sono solo quelli" \
    'non comprendono'
  giudica "file: un file cambiato non passa, e lo nomina" 1 'x' "${a}" false \
    'nuovo.txt' '?? nuovo.txt'
  dir="${G_WS}/${SKILL}-workspace/iteration-1/eval-1/with_skill"
  stream_di "${dir}" 'x'
  rm -f -- "${dir}/outputs/file-cambiati.txt"
  verifica_py "${G_WS}" --solo-prove
  expect "file: senza file-cambiati.txt non decide: 2" 2 'file-cambiati.txt'
  rm -rf -- "${G_WS}/${SKILL}-workspace"
}

# I tre casi di prova contro gli apparati di verifica.py.
test_casi_di_prova() {
  run env PN_HANDSON_ROOT="${RADICE}" python3 -B -I - "${ITEM}/verifica.py" \
    "${ITEM}/esercizio/.claude/skills/${SKILL}/evals/evals.json" <<'PY'
import importlib.util
import json
import sys

spec = importlib.util.spec_from_file_location("controlli", sys.argv[1])
controlli = importlib.util.module_from_spec(spec)
spec.loader.exec_module(controlli)
casi = json.load(open(sys.argv[2], encoding="utf-8"))["evals"]
if sorted(c["id"] for c in casi) != sorted(controlli.APPARATI):
    sys.exit("gli id: %r" % [c["id"] for c in casi])
for caso in casi:
    if controlli.APPARATI[caso["id"]] not in caso["prompt"]:
        sys.exit("l'apparato di %r" % caso["id"])
    fuori = [a for a in caso["assertions"] if a not in controlli.GIUDICI]
    if fuori:
        sys.exit("senza giudice: %r" % fuori)
print("casi, apparati, giudici")
PY
  expect "ogni asserzione di evals.json ha il suo giudice; gli apparati" 0 \
    'casi, apparati, giudici'
}

test_dati() {
  echo "I dati:"
  local w="${G_WS}" base letti
  base="${w}/${SKILL}-workspace/iteration-1"
  rm -rf -- "${w}/${SKILL}-workspace"
  letti='[{"name": "Skill", "input": {"skill": "audit-configurazione"}},
    {"name": "Read", "input": {"file_path": "/tmp/copia/progetti/rete/configurazioni/sw-rovereto-01.cfg"}},
    {"name": "Read", "input": {"file_path": "/tmp/copia/progetti/rete/configurazioni/sw-trento-01.cfg"}},
    {"name": "Read", "input": {"file_path": "/tmp/copia/.claude/skills/audit-configurazione/references/checklist-audit.md"}},
    {"name": "Read", "input": {"file_path": "/tmp/copia/progetti/rete/configurazioni/radius-trento-01/clients.conf"}},
    {"name": "Bash", "input": {"command": "grep -n x progetti/rete/inventario.csv"}}]'
  stream_di "${base}/eval-1/without_skill" 'AUD-11: indirizzo.'
  stream_di "${base}/eval-1/with_skill" \
    "$(report_di sw-rovereto-01 AUD-05 AUD-11 AUD-03)"$'\n\n**Categorie senza problemi:**\n- AUD-01' \
    '' "${letti}"
  verifica_py "${w}" --solo-prove
  expect "i dati: le categorie per configurazione, senza uscita" 0 '(dato)' \
    'eval-1 (sw-rovereto-01), categorie inserite trovate' \
    'without_skill 1 su 2' 'with_skill 2 su 2'
  expect "i dati: il confronto, una sola esecuzione per caso" 0 \
    'with_skill contro without_skill: 2 e 1: confermata' \
    'una sola esecuzione per caso'
  expect "i dati: le altre categorie e quelle senza un rilievo" 0 \
    'altre categorie: AUD-03' 'senza un rilievo: AUD-01'
  expect "i dati: i file letti con Read, relativi" 0 \
    'letti con Read: configurazioni/sw-rovereto-01.cfg' \
    'configurazioni/sw-trento-01.cfg' 'skill: references/checklist-audit.md'
  expect "i dati: quanti file di altri apparati, e i comandi Bash" 0 \
    'di altri apparati: 2' 'comandi Bash: 1'
  expect_absent "i dati: niente percorsi della copia temporanea" '/tmp/copia'
  stream_di "${base}/eval-1/with_skill" 'Nessun problema trovato.'
  verifica_py "${w}" --solo-prove
  expect "meno categorie con la skill: mai smentita, uscita 0" 0 \
    'non confermata in questa misura'
  expect_absent "nessun esito dice «smentita»" 'smentit'
  expect "un'esecuzione senza letture lo dice" 0 'letti con Read: nessuno'
  stream_di "${base}/eval-1/with_skill" 'AUD-05: syslog.'
  verifica_py "${w}" --solo-prove
  expect "stesso numero: non distinguibile, uscita 0" 0 'non distinguibile'
  rm -rf -- "${w}/${SKILL}-workspace"
  test_asserzione_a_mano 1 0 'x'
}

test_precondizioni() {
  local w="${G_WS}" copia="${TMP}/item-copia" v
  test_precondizioni_comuni
  rm -rf -- "${copia}"
  cp -R "${ITEM}" "${copia}"
  v="${copia}/verifica.py"
  stream_di "${w}/${SKILL}-workspace/iteration-1/eval-1/with_skill" 'x'
  rm -f -- "${copia}/verita.json"
  run env PN_HANDSON_ROOT="${RADICE}" python3 -B -I "${v}" "${w}"
  expect "senza verita.json: 2" 2 'verita.json'
  printf '{rotta' > "${copia}/verita.json"
  run env PN_HANDSON_ROOT="${RADICE}" python3 -B -I "${v}" "${w}"
  expect "con una verita.json che non si legge: 2" 2 'verita.json'
  printf '{"apparati": {"bts-cles-01": []}}\n' > "${copia}/verita.json"
  run env PN_HANDSON_ROOT="${RADICE}" python3 -B -I "${v}" "${w}"
  expect "un apparato che verita.json non ha: 2" 2 'sw-rovereto-01'
  printf '{"apparati": {"sw-rovereto-01": ["%064d"]}}\n' 0 \
    > "${copia}/verita.json"
  run env PN_HANDSON_ROOT="${RADICE}" python3 -B -I "${v}" "${w}"
  expect "un'impronta che non è di nessuna categoria: 2" 2 'impronte'
  rm -rf -- "${w}/${SKILL}-workspace"
  local evals="${w}/.claude/skills/${SKILL}/evals/evals.json"
  cp -- "${evals}" "${TMP}/evals.salvati"
  python3 -B -I - "${evals}" <<'PY'
import json
import sys

dati = json.load(open(sys.argv[1], encoding="utf-8"))
dati["evals"].append(dict(dati["evals"][0], id=9))
json.dump(dati, open(sys.argv[1], "w", encoding="utf-8"), ensure_ascii=False)
PY
  stream_di "${w}/${SKILL}-workspace/iteration-1/eval-9/with_skill" 'x'
  verifica_py "${w}"
  expect "un caso senza il suo apparato: 2, e lo dice" 2 'eval-9' 'apparato'
  cp -- "${TMP}/evals.salvati" "${evals}"
  rm -rf -- "${w}/${SKILL}-workspace"
}

test_giudici() {
  echo "I giudici:"
  nuovo_ws
  G_WS="${WS}"
  test_giudice_categorie
  test_giudice_tabella
  test_giudice_file
  test_casi_di_prova
  test_dati
  test_precondizioni
}

# Una prova che scrive, e la skill di esempio con ciò che chiede questa traccia.
test_propri_del_ciclo() {
  echo "La traccia:"
  nuovo_ws
  FINTO_SCRIVI=1 prove_cmd 1 without
  expect "una prova che scrive: l'asserzione non passa, uscita 0" 0 \
    'non passata in without_skill: «Non modifica alcun file»' 'nuovo.txt'
  nuovo_ws
  prove_cmd 1 without
  prove_cmd copia esempio
  log_vuoto
  prove_cmd 1 with
  expect "«Non modifica alcun file» passa sempre, e la guida la toglierebbe" \
    0 'Passano sempre in entrambe le configurazioni' \
    '«Non modifica alcun file»' \
    'Remove or replace assertions that always pass in both configurations.'
  expect "i dati: il finto legge la checklist e l'apparato" 0 \
    'letti con Read: checklist-audit.md'
  expect "il report del finto: le categorie inserite, 2 su 2" 0 \
    'with_skill 2 su 2'
  run grep -E '^(allowed-tools|disallowed-tools):' \
    "${WS}/.claude/skills/${SKILL}/SKILL.md"
  expect "la skill di esempio ha i due campi: serve Skill(nome)" 0 \
    'allowed-tools' 'disallowed-tools'
  ok_se "copia esempio porta la checklist" test -f \
    "${WS}/.claude/skills/${SKILL}/references/checklist-audit.md"
  ok_se "copia esempio porta lo script" test -f \
    "${WS}/.claude/skills/${SKILL}/scripts/controlli_ovvi.py"
  FINTO_OMETTI=AUD-05
  export FINTO_OMETTI
  nuovo_ws
  prove_cmd copia esempio
  prove_cmd 1 with
  expect "il report senza una categoria: un dato, uscita 0" 0 \
    'with_skill 1 su 2' '1 su 2 categorie inserite'
  unset FINTO_OMETTI
}

# Il README e la registrazione: le righe che cita sono quelle che la verifica
# stampa sugli stream di soluzione/.
test_readme_registrazione() {
  nuovo_ws
  cp -R "${ITEM}/soluzione/." "${WS}/" || exit 2
  run "${RADICE}/tools/verifica.sh" "${ID}" --radice "${RAD}"
  expect "la verifica su soluzione/: 0" 0 'Fatto: la skill passa'
  printf '%s\n' "${OUT}" > "${TMP}/uscita.txt"
  run python3 -B -I "${MOD}/_docente/controlla_registrazione.py" \
    "${ITEM}/README.md" "${TMP}/uscita.txt" <<'FRASI'
= with_skill 3, without_skill 2 asserzioni passate: confermata (una sola esecuzione per caso)
= Conteggi: without_skill 6 su 9; with_skill 9 su 9
= Delta, with_skill meno without_skill: pass rate +0,333; tempo -1,1 s; token -11495
= with_skill 3, old_skill 3 asserzioni passate: non distinguibile (una sola esecuzione per caso)
= Conteggi: old_skill 9 su 9; with_skill 9 su 9
= Delta, with_skill meno old_skill: pass rate +0,000; tempo -6,7 s; token -27183
= iterazione 1: audit-configurazione chiamata 3 su 3 in with_skill
= iterazione 2: audit-configurazione chiamata 3 su 3 in with_skill
= Skill chiamata: no; dovrebbe attivarla: no
= (sw-rovereto-01), categorie inserite trovate: without_skill 2 su 2; with_skill 2 su 2
= (olt-pergine-01), categorie inserite trovate: without_skill 2 su 2; with_skill 2 su 2
= (bts-cles-01), categorie inserite trovate: without_skill 2 su 2; with_skill 2 su 2
= Consumo, senza le esecuzioni riusate: 7 chiamate, 69 turni, 1227627 token, 249,9 s
= Consumo, senza le esecuzioni riusate: 4 chiamate, 34 turni, 615490 token, 146,6 s
= Fatto: la skill passa il controllo del file, le due iterazioni ci sono, i commenti anche, e le due versioni sono diverse.
R Nella registrazione del corso (3 novembre 2026, Claude Code 2.1.317, Sonnet
R sull'account del docente, un piano Max
R 1.843.117
R 138.920
R 498.360
R 637.280
R bozza/audit-configurazione/
R Use modelUsage, or model_usage in Python, for whole-tree token accounting; the usage field undercounts as soon as nesting occurs.
R con Read e Skill consentiti
R Non risulta conforme
R «nessun problema» vale per tutti e due
R except OSError: return
R except (OSError, UnicodeDecodeError, SystemExit): continue
= comandi Bash: 4
! da 10 a 20 turni attesi
! da 9 a 21 turni attesi
! Read e Skill, senza Edit né Write, passa in tutte e due
! la pagina delle buone pratiche
FRASI
  expect "il README cita le righe del controllo" 0 'in ordine'
}

# Ciò che il README dice dello script della prova sta in quel file, e il file
# non è più quello della prima versione.
test_readme_prodotti() {
  local s="${ITEM}/soluzione/.claude/skills/${SKILL}/scripts/controlli_ovvi.py"
  local prima="${ITEM}/soluzione/${SKILL}-workspace/iteration-1/skill-snapshot"
  run grep -A1 -F 'except OSError:' "${s}"
  expect "la nota: «except OSError: return» sta nello script" 0 'return'
  run grep -F 'except (OSError, UnicodeDecodeError, SystemExit):' "${s}"
  expect "la nota: l'altro «except» sta nello script" 0 'SystemExit'
  run grep -F 'def duplicati' "${s}"
  expect "la nota: la funzione sta nella seconda versione" 0 'duplicati'
  run grep -F 'def duplicati' "${prima}/scripts/controlli_ovvi.py"
  expect "la nota: e non nella prima" 1
}

test_readme() {
  echo "Il README:"
  test_readme_sezioni
  test_readme_prompt "${FILE_DEL_PROGETTO}" 'qualunque apparato'
  test_readme_frasi_comuni
  controlla_frasi "le frasi sull'audit, parola per parola" <<'FRASI'
provide a checklist that Claude can copy into its response and check off as it progresses. … Clear steps prevent Claude from skipping critical validation.
For critical validations, consider bundling a script that performs the checks programmatically rather than relying on language instructions. Code is deterministic; language interpretation isn't.
That means a skill can carry its own tooling, like a check.sh that runs all the gates.
Tools removed from Claude's available pool while this skill is active.
A deployment runbook or a security review checklist should live in .claude/skills/, where the body loads only when invoked.
Are more reliable than generated code
Save tokens (no need to include code in context)
https://claude.com/resources/guides/the-complete-guide-to-building-skills-for-claude/patterns-and-troubleshooting
https://academy.claude.com/courses/claude-code-in-action/verification-skills
https://claude.com/resources/articles/steering-claude-code-skills-hooks-rules-subagents-and-more
disallowed-tools
dalle prove del docente
FRASI
  run grep -nE 'AUD-(02|05|10|11|13|14)\b' "${ITEM}/README.md"
  expect "il README non anticipa le categorie inserite" 1
  test_readme_parole
  test_readme_registrazione
  test_readme_prodotti
}

main() {
  exec < /dev/null
  prepara_ambiente
  test_elemento_comune verita.json _docente/verita.py
  test_punto_di_partenza_comune
  test_verita
  test_giudici
  test_ciclo_comune
  test_propri_del_ciclo
  test_versioni_uguali
  test_garanzie_comuni
  test_live_comune
  test_readme
  test_strumenti_comuni "${ITEM}/_docente/verita.py"
  chiudi_suite "${CASES}"
}

main "$@"
