#!/bin/bash
#
# test_m6_e03.sh -- le prove di M6-E03 «Un CLAUDE.md per la rete», per il
# docente:
#   - l'elemento, il punto di partenza, prove/prima.sh (lib_test_lab_m6.sh);
#   - i criteri di verifica.py su prove scritte qui: r1 (i due controlli del
#     progetto, la cifra di ognuno nella risposta, nessun file cambiato), r2
#     (il refuso, il commit, la forma del team di rete, la riga Rif:, i file),
#     r3 (la risposta); i confronti, che non decidono l'uscita; le
#     precondizioni (2, mai un traceback);
#   - il ciclo del README con tools/prova_contesto.sh e il claude finto, le
#     garanzie, _docente/live.sh;
#   - il README, la soluzione, gli strumenti, e le righe della registrazione
#     del corso, se c'è.
# Mai il claude vero. CASES è il numero dei casi, SKIP compresi: se ne girano
# di più o di meno la suite esce 2.
#
# Uso:    m6_projects_context/_docente/test_m6_e03.sh
# Env:    PN_M6_REGISTRAZIONE  uno spazio di lavoro con la prova del docente,
#                              per le righe della registrazione quando
#                              soluzione/ non le ha ancora
# Uscita: 0 = tutti i casi passano · 1 = almeno un caso fallito · 2 =
#         precondizione (manca python3, git o shellcheck; il finto non viene
#         prima nel PATH), o un numero di casi diverso da CASES
# shellcheck disable=SC2034,SC2016  # le variabili le legge lib_test_lab_m6.sh;
# backtick e $ sono il testo delle prove
set -uo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly MOD="${SELF%/_docente/*}"
readonly RADICE="${MOD%/*}"
readonly LAB="${MOD}/s5_projects_context/m6_e2_laboratorio"
readonly ITEM="${LAB}/M6-E03_claude_md_rete"
readonly ALTRO="${LAB}/M6-E02_claude_md_gestionale"
readonly FINTO_PY="${MOD}/_docente/claude_finto_m6_lab.py"
readonly SUITE=test_m6_e03
readonly ID=M6-E03
readonly PROGETTO=progetti/rete
readonly FILE_REFUSO=progetti/rete/checklist-audit.md
readonly REFUSO='sono disativati'
readonly GIUSTO='sono disattivati'
readonly RIF='Rif: NOC-0'
readonly REGOLA=.claude/rules/generatore.md
readonly GLOB='progetti/rete/generatore/**'
readonly ESCLUDI='escludi=appunti-del-team.md'
readonly CASES=174
RICHIESTE=(r1 r2 r3)
PROMPTS=("Controlla che i file del progetto rete siano a posto e dimmi l'esito."
  "Nella checklist di audit c'è un refuso nello standard di AUD-02: correggilo e fai il commit."
  'Che cosa controlla la categoria AUD-07 della checklist di audit? Rispondi in cinque righe.')
STRUMENTI=('Read,Glob,Grep,Bash' 'Read,Glob,Grep,Edit,Bash' 'Read,Glob,Grep')
DENY_NUOVE=('Edit(/progetti/rete/configurazioni/**)'
  'Edit(/progetti/rete/log/**)' 'Edit(/progetti/rete/inventario.csv)'
  'Edit(/progetti/rete/allarmi.csv)')
V1_TESTO='# Rete

- A posto: `python3 progetti/rete/genera.py --check` e `--canone`.
- Commit: `rete(<ambito>): <descrizione>`, poi la riga `Rif: NOC-0`.'
# shellcheck source=../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"
# shellcheck source=lib_test_lab_m6.sh
source "${MOD}/_docente/lib_test_lab_m6.sh"

G_WS=''
readonly CHECK='python3 progetti/rete/genera.py --check'
readonly CANONE='python3 progetti/rete/genera.py --canone'
readonly CHECK_OK='genera.py --check: 65 file identici'
readonly CANONE_OK='genera.py --canone: 83 file conformi'

# Una specifica di r1 con questi comandi e risultati, e il testo.
# Arguments: $1 il testo finale, $2 true o false (il CLAUDE.md caricato), poi
#   coppie comando, risultato.
spec_r1() {
  python3 -B -I - "$@" <<'PY'
import json
import sys

testo, carica, resto = sys.argv[1], sys.argv[2] == "true", sys.argv[3:]
coppie = [[resto[i], resto[i + 1]] for i in range(0, len(resto), 2)]
print(json.dumps({"comandi": coppie, "testo": testo, "carica": carica}))
PY
}

# La specifica di una prova che va bene, in JSON, per la richiesta.
# Arguments: $1 la richiesta, $2 true o false (il CLAUDE.md caricato).
spec_buona() {
  case "$1" in
    r1) spec_r1 '--check: 65 file identici; --canone: 83 file conformi.' \
          "$2" "${CHECK}" "${CHECK_OK}" "${CANONE}" "${CANONE_OK}" ;;
    r2) printf '{"commit": [["rete(audit): corregge il refuso", "%s"]],
"committati": ["%s"], "diff": "corretto", "carica": %s}\n' \
          "${RIF}" "${FILE_REFUSO}" "$2" ;;
    *) printf '{"testo": "uno\\ndue\\ntre\\nquattro\\ncinque", "carica": %s}\n' \
          "$2" ;;
  esac
}

# Una variante della v1 di una richiesta, e il controllo da capo.
# Arguments: $1 la richiesta, $2 la specifica in JSON.
variante() {
  prova_sintetica "${G_WS}" v1 "$1" "$2"
  verifica_py "${G_WS}" --solo-prove
}

# Una specifica di r2 con questi commit (soggetto, corpo) e file.
# Arguments: $1 il diff, $2 i file committati (JSON), $3 i file ancora
#   cambiati (JSON), poi coppie soggetto, corpo.
spec_r2() {
  python3 -B -I - "$@" <<'PY'
import json
import sys

diff, committati, cambiati, resto = (sys.argv[1], json.loads(sys.argv[2]),
                                     json.loads(sys.argv[3]), sys.argv[4:])
commit = [[resto[i], resto[i + 1]] for i in range(0, len(resto), 2)]
print(json.dumps({"diff": diff, "committati": committati,
                  "cambiati": cambiati, "commit": commit, "carica": True}))
PY
}

test_criteri_r1() {
  echo "I criteri di r1:"
  tre_versioni_sintetiche "${G_WS}"
  verifica_py "${G_WS}" --solo-prove
  criterio "--check ha girato, con il suo riepilogo" \
    'genera.py --check ha girato' "v1 sì (${CHECK_OK})"
  criterio "--canone ha girato, con il suo riepilogo" \
    'genera.py --canone ha girato' "v1 sì (${CANONE_OK})"
  criterio "la cifra di ogni controllo nella risposta" \
    "l'esito di ogni controllo nella risposta" \
    'v1 sì (--check 65 sì; --canone 83 sì)'
  criterio "nessun file cambiato" 'nessun file cambiato' 'v1 sì (nessuno)'
  variante r1 "$(spec_r1 '65 file identici.' true "${CHECK}" "${CHECK_OK}")"
  criterio "soltanto --check: --canone no" 'genera.py --canone ha girato' \
    'v1 no (nessun comando con genera.py --canone)'
  criterio "soltanto --check: la sua cifra basta" \
    "l'esito di ogni controllo nella risposta" 'v1 sì (--check 65 sì)'
  criterio "il confronto: prima sì, con la v1 no" 'v1 contro base' \
    'genera.py --canone ha girato: non confermata in questa misura'
  expect_absent "nessun confronto dice «smentita»" 'smentit'
  variante r1 "$(spec_r1 'Tutto a posto.' true "${CHECK}" "${CHECK_OK}" \
    "${CANONE}" "${CANONE_OK}")"
  criterio "la cifra che manca nella risposta: no, quale" \
    "l'esito di ogni controllo nella risposta" \
    'v1 no (--check 65 no; --canone 83 no)'
  variante r1 "$(spec_r1 '3 file non corrispondono.' true "${CHECK}" \
    'genera.py --check: 3 file non corrispondono')"
  criterio "un controllo che fallisce: il suo riepilogo" \
    'genera.py --check ha girato' \
    'v1 sì (genera.py --check: 3 file non corrispondono)'
  criterio "e la sua cifra nella risposta" \
    "l'esito di ogni controllo nella risposta" 'v1 sì (--check 3 sì)'
  variante r1 "$(spec_r1 'Errore.' true "${CHECK}" 'genera.py: errore: x')"
  criterio "il comando senza riepilogo: ha girato, e lo dice" \
    'genera.py --check ha girato' 'v1 sì (nessun riepilogo nel risultato)'
  criterio "nessun riepilogo da confrontare" \
    "l'esito di ogni controllo nella risposta" \
    'v1 no (nessun riepilogo da confrontare)'
  variante r1 "$(spec_r1 '65 e 83.' true "${CHECK} && ${CANONE}" \
    "${CHECK_OK}"$'\n'"${CANONE_OK}")"
  criterio "un comando solo con i due controlli: --check" \
    'genera.py --check ha girato' "v1 sì (${CHECK_OK})"
  criterio "un comando solo con i due controlli: --canone" \
    'genera.py --canone ha girato' "v1 sì (${CANONE_OK})"
  prova_sintetica "${G_WS}" v1 r1 '{"comandi": [], "testo": "x",
"cambiati": [" M progetti/rete/README.md"], "carica": true}'
  verifica_py "${G_WS}" --solo-prove
  criterio "un file cambiato, nominato" 'nessun file cambiato' \
    'v1 no (1 file: progetti/rete/README.md)'
  criterio "nessun comando: --check no" 'genera.py --check ha girato' \
    'v1 no (nessun comando con genera.py --check)'
  tre_versioni_sintetiche "${G_WS}"
  prova_sintetica "${G_WS}" base r1 "$(spec_r1 'x' false 'ls' '')"
  verifica_py "${G_WS}" --solo-prove
  criterio "il confronto: prima no, con la v1 sì" 'v1 contro base' \
    'genera.py --check ha girato: confermata'
}

test_criteri_r2() {
  echo "I criteri di r2:"
  local uno="[\"${FILE_REFUSO}\"]" nessuno='[]'
  tre_versioni_sintetiche "${G_WS}"
  verifica_py "${G_WS}" --solo-prove
  criterio "il refuso corretto" 'il refuso corretto' 'v1 sì (la riga corretta)'
  criterio "un commit" 'un commit' 'v1 sì (1 commit)'
  criterio "la forma del team di rete, citata" \
    'il soggetto nella forma del team di rete' \
    'v1 sì («rete(audit): corregge il refuso»)'
  criterio "la riga Rif:" "la riga «${RIF}»" "v1 sì (${RIF})"
  criterio "un file solo" 'cambiato soltanto checklist-audit.md' \
    'v1 sì (1 file)'
  criterio "configurazioni/ e log/ intatti" 'configurazioni/ e log/ intatti' \
    'v1 sì (nessun file lì)'
  variante r2 "$(spec_r2 nessuno "${nessuno}" "${nessuno}")"
  criterio "nessun cambiamento: il refuso è ancora lì" 'il refuso corretto' \
    'v1 no (il refuso è ancora nel file)'
  criterio "nessun commit" 'un commit' 'v1 no (nessun commit)'
  criterio "nessun commit: nessuna forma" \
    'il soggetto nella forma del team di rete' 'v1 no (nessun commit)'
  variante r2 "$(spec_r2 diverso "${uno}" "${nessuno}" 'rete(audit): y' \
    "${RIF}")"
  criterio "una riga diversa da quella giusta" 'il refuso corretto' \
    'v1 no (la riga è diversa:'
  variante r2 "$(spec_r2 corretto_e_una "${uno}" "${nessuno}" \
    'rete(audit): y' "${RIF}")"
  criterio "corretto, e una riga in più: al singolare" 'il refuso corretto' \
    'v1 sì (la riga corretta, e 1 altra riga cambiata nel file)'
  variante r2 "$(spec_r2 corretto "${uno}" "${nessuno}" \
    'fix(audit): corregge il refuso' "${RIF}")"
  criterio "la forma del gestionale non è quella della rete" \
    'il soggetto nella forma del team di rete' \
    'v1 no («fix(audit): corregge il refuso»)'
  variante r2 "$(spec_r2 corretto "${uno}" "${nessuno}" 'rete(audit): a' \
    'Rif: NOC-7')"
  criterio "un altro Rif:, citato" "la riga «${RIF}»" 'v1 no («Rif: NOC-7»)'
  variante r2 "$(spec_r2 corretto "${uno}" "${nessuno}" 'rete(audit): a' \
    'Corregge.')"
  criterio "nessuna riga Rif:" "la riga «${RIF}»" \
    'v1 no (nessuna riga «Rif:» nel messaggio)'
  variante r2 "$(spec_r2 corretto \
    "[\"${FILE_REFUSO}\", \"progetti/rete/configurazioni/sw-trento-01.cfg\"]" \
    "${nessuno}" 'rete(audit): a' "${RIF}")"
  criterio "un file di configurazioni/ nel commit" \
    'configurazioni/ e log/ intatti' \
    'v1 no (progetti/rete/configurazioni/sw-trento-01.cfg)'
  criterio "e il file in più, nominato" 'cambiato soltanto checklist-audit.md' \
    'v1 no (anche 1 altro: progetti/rete/configurazioni/sw-trento-01.cfg)'
  variante r2 "$(spec_r2 corretto "${uno}" \
    '[" M progetti/rete/log/syslog/syslog_2026-09-07.log"]' 'rete(audit): a' \
    "${RIF}")"
  criterio "un log cambiato fuori dal commit" 'configurazioni/ e log/ intatti' \
    'v1 no (progetti/rete/log/syslog/syslog_2026-09-07.log)'
}

test_criteri_r3() {
  echo "I criteri di r3 e l'uscita:"
  tre_versioni_sintetiche "${G_WS}"
  verifica_py "${G_WS}" --solo-prove
  criterio "una risposta, con le sue righe" 'una risposta' 'v1 sì (5 righe)'
  expect "--solo-prove: le garanzie reggono, 0" 0 \
    'v1: prima richiesta 1000 token · 2 turni · 2 s'
  expect_absent "--solo-prove non dice «Fatto»" 'Fatto:'
  prova_sintetica "${G_WS}" v1 r3 '{"testo": "", "carica": true}'
  verifica_py "${G_WS}" --solo-prove
  criterio "una risposta vuota: no" 'una risposta' \
    'v1 no (nessun testo nella risposta)'
  prova_sintetica "${G_WS}" v1 r3 '{"testo": "Una riga sola.", "carica": true}'
  verifica_py "${G_WS}" --solo-prove
  criterio "una risposta di una riga: al singolare" 'una risposta' \
    'v1 sì (1 riga)'
  tre_versioni_sintetiche "${G_WS}"
  verifica_py "${G_WS}"
  expect "tutto fatto: 0, e «Fatto» con il campione" 0 'Fatto:' 'un campione'
  expect_absent "tutto fatto: nessun MANCA" 'MANCA'
}

test_precondizioni() {
  echo "Le precondizioni:"
  local copia="${TMP}/item-copia"
  verifica_py
  expect "senza lo spazio di lavoro: 2, l'uso" 2 'uso: verifica.py'
  verifica_py "${G_WS}" --boh
  expect "un'opzione sconosciuta: 2" 2 'uso: verifica.py'
  run env PN_HANDSON_ROOT="${TMP}/non-esiste" python3 -B -I \
    "${ITEM}/verifica.py" "${G_WS}"
  expect "un repository senza tools/: 2" 2 'non trovo gli strumenti'
  tre_versioni_sintetiche "${G_WS}"
  printf 'non json\n' >> "${G_WS}/prove-contesto/v2/r1/stream.jsonl"
  verifica_py "${G_WS}"
  expect "uno stream che non si legge: 2" 2 'non è JSON'
  rm -rf -- "${copia}"
  cp -R "${ITEM}" "${copia}"
  cp -- "${RADICE}/${FILE_REFUSO}" "${copia}/esercizio/${FILE_REFUSO}"
  run env PN_HANDSON_ROOT="${RADICE}" python3 -B -I "${copia}/verifica.py" \
    "${G_WS}"
  expect "un punto di partenza senza il refuso: 2" 2 \
    'devono differire in una riga sola'
}

test_criteri() {
  nuovo_ws
  G_WS="${WS}"
  test_criteri_r1
  test_criteri_r2
  test_criteri_r3
  test_precondizioni
}

test_registrazione() {
  echo "La registrazione del corso:"
  test_registrazione_comune <<'RIGHE'
= la riga «Rif: NOC-0»: base no (nessuna riga «Rif:» nel messaggio); v1 sì (Rif: NOC-0); v2 sì (Rif: NOC-0)
= il soggetto nella forma del team di rete: base no («Correggi refuso in AUD-02 (disattivati)»); v1 sì («rete(audit): corregge il refuso nello standard di AUD-02»)
= il soggetto nella forma del team di rete: confermata; la riga «Rif: NOC-0»: confermata
= genera.py --check ha girato: base sì (genera.py --check: 65 file identici)
= genera.py --canone ha girato: base sì (genera.py --canone: 83 file conformi)
= base: prima richiesta 6420 token · 4 turni · 15 s · 50441 token
= v1: prima richiesta 6892 token · 3 turni · 9 s · 14303 token
= base: prima richiesta 4877 token
= v1: prima richiesta 5351 token
= v2: prima richiesta 5352 token
= v1: CLAUDE.md, 14 righe
= v2: CLAUDE.md, 14 righe
= Garanzia, base: nessun file di istruzioni caricato in 3 su 3 esecuzioni
= Garanzia, v1: CLAUDE.md caricato all'avvio in 3 su 3 esecuzioni
RIGHE
}

test_readme() {
  test_readme_comune
  test_readme_frasi_comuni
  controlla_frasi "le frasi di questa traccia" <<'FRASI'
Niente PHP né Docker: il progetto della rete è fatto di file di testo e di un generatore in Python.
un apparato nuovo è una procedura, una skill del Modulo 5, e qui non serve
They don’t apply … to arbitrary subprocesses that read or write files indirectly, like a Python or Node script that opens files itself.
progetti/rete/generatore/topologia.py
FRASI
}

main() {
  exec < /dev/null
  prepara_ambiente
  test_elemento_comune
  test_punto_di_partenza_comune
  test_prima_comune
  test_criteri
  test_ciclo_comune
  test_garanzie_comuni
  test_live_comune
  test_readme
  test_soluzione_comune
  test_registrazione
  test_strumenti_comuni
  chiudi_suite "${CASES}"
}

main "$@"
