#!/bin/bash
#
# test_m2_d06.sh -- le prove di M2-D06, la galleria degli orrori, per il
# docente (sta in _docente/, il materiale del docente):
#   - i prompt di demo/: otto sono un'istruzione, una riga vuota e
#     messaggio.md byte per byte; orrore-4-memoria.md è la sua riga e
#     basta; i tre del divieto hanno lo stesso compito, e il divieto e la
#     cura vi aggiungono le due frasi dell'esempio di Anthropic; la cura
#     della stima è l'orrore più la sua frase; orrore-3-cinque.md non c'è;
#   - misura_orrori.py su risposte finte scritte qui: l'intestazione; i
#     campi di ogni coppia (titoli, elenchi, tabelle, grassetti; le
#     etichette, nella scheda e nella risposta alla richiesta vaga, anche
#     in grassetto; gli importi in euro, anche con una
#     grandezza fra il numero e la valuta, e non un numero senza valuta;
#     «non indicato»; la firma con l'apostrofo tipografico e il grassetto;
#     «—» dove la coppia non misura); un JSON rovinato (vuoto, non JSON,
#     non un oggetto, is_error, senza result o con result vuoto, senza
#     usage, un conteggio non numerico, annidato oltre ogni limite) esce
#     1, mai con un traceback; gli argomenti sbagliati escono 2; un importo
#     in euro negli ingressi (anche «5 mila euro»), un ingresso assente o
#     non UTF-8 escono 2;
#   - verifica.sh: spazio di lavoro assente (2); punto di partenza (1);
#     ogni affermazione confermata (0, l'ultima riga è la frase finale);
#     ogni ramo di ogni esito (confermata, non confermata in questa
#     esecuzione, non distinguibile) delle raccomandazioni, che escono 0:
#     la richiesta vaga, il divieto e la stima confrontano la cura con
#     l'orrore (meno, tanti quanti, di più, niente da migliorare
#     nell'orrore); la cura della memoria legge la sola firma; i titoli e
#     gli elenchi della richiesta vaga, il riepilogo senza indicazioni, la
#     prosa senza Markdown, la cura senza importi, «non indicato» e le
#     righe della cura della memoria sono dati; la garanzia non confermata
#     (1); un'intestazione diversa, una riga mancante o incompleta (anche
#     senza le etichette della richiesta vaga), un file vuoto (1); le righe
#     CRLF, il BOM UTF-8 e l'ultima riga di una prova rifatta; orrori.tsv
#     che non si legge (2, saltato da root);
#   - _docente/live.sh con un claude finto davanti nel PATH, che registra
#     ogni sua invocazione: le precondizioni escono 2 senza nessuna
#     invocazione, nemmeno --version; con le risposte finte nove chiamate,
#     con le opzioni della registrazione del corso, il testo del file di
#     ogni prova e senza ANTHROPIC_API_KEY, gli esiti a schermo anche su
#     un OK, uscita 0; la firma nella memoria presunta esce 1; una
#     chiamata fallita esce 1 dopo una sola chiamata;
#   - il README: le nove prove nell'ordine di live.sh, ogni opzione della
#     chiamata, le due sottosezioni di «Che cosa osservare»;
#   - shellcheck -x su verifica.sh, live.sh e su questo file.
# Gli spazi di lavoro nascono in una cartella temporanea: l'albero del
# repository non cambia.
#
# Uso:    m2_prompting_avanzato/_docente/test_m2_d06.sh
# Uscita: 0 = tutte le prove passano · 1 = almeno una fallita · 2 =
#         precondizione (manca python3, shellcheck o la cartella
#         dell'elemento; le risposte finte non si misurano; il numero di
#         prove eseguite non è CASES)
set -uo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly MOD="${SELF%/_docente/*}"
ITEM="${MOD}/s2_misurare_e_migliorare/m2_7_galleria_degli_orrori"
ITEM+="/M2-D06_galleria_degli_orrori"
readonly ITEM
readonly CASES=130
readonly PROVE=(orrore-1-vaga cura-1-vaga base-2-formato orrore-2-divieto
  cura-2-divieto orrore-3-stima cura-3-stima orrore-4-memoria cura-4-memoria)
VAGA='Essere specifici su formato e vincoli (la scheda rispetta più vincoli'
VAGA+=' della risposta alla richiesta vaga)'
readonly VAGA
MEMORIA='Il formato concordato, mandato nel prompt (la firma concordata'
MEMORIA+=" c'è)"
readonly MEMORIA
DIVIETO='Dire cosa fare invece di cosa non fare (con la prosa chiesta in'
DIVIETO+=' positivo, meno elementi di Markdown che con il divieto)'
readonly DIVIETO
STIMA='Solo le informazioni del messaggio, e il permesso di dire che un'
STIMA+=" dato manca (meno importi inventati che senza l'istruzione)"
readonly STIMA
readonly T=$'\t'
INTESTAZIONE="prova${T}token_entrata${T}token_uscita${T}parole${T}righe"
INTESTAZIONE+="${T}titoli${T}elenchi${T}tabelle${T}grassetti${T}etichette"
INTESTAZIONE+="${T}importi${T}non_indicato${T}firma${T}risposta"
readonly INTESTAZIONE
FINE='Fatto: ogni affermazione è stata messa alla prova;'
FINE+=' gli esiti sono qui sopra.'
readonly FINE
readonly NO='non confermata in questa esecuzione'
TMP=''
PASS=0
FAIL=0
SKIP=0
RC=0
OUT=''

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }
skip() { echo "  SKIP: $1"; SKIP=$((SKIP + 1)); }

# Esegue un comando; RC e OUT (STDOUT e STDERR insieme) per expect.
run() { OUT="$("$@" 2>&1)"; RC=$?; }

# Uscita attesa E parola chiave attesa (RU-01.T3).
# Arguments: $1 il nome, $2 l'uscita attesa, $3 la parola (grep -F).
expect() {
  if (( RC == $2 )) && grep -qF -- "$3" <<< "${OUT}"; then
    pass "$1"
  else
    fail "$1 (rc=${RC}, attesa $2, parola «$3»): ${OUT:0:300}"
  fi
}

# Nessun falso positivo: la parola NON c'è (RU-01.T5).
expect_absent() {
  if grep -qF -- "$2" <<< "${OUT}"; then
    fail "$1: «$2» c'è"
  else
    pass "$1"
  fi
}

# Uno spazio di lavoro nuovo con il punto di partenza dell'elemento.
# Arguments: $1 la variabile da assegnare.
ws() {
  local __w
  __w="$(mktemp -d "${TMP}/ws.XXXXXX")" || { echo "mktemp" >&2; exit 2; }
  cp -R "${ITEM}/demo/." "${__w}/" || { echo "cp demo/" >&2; exit 2; }
  printf -v "$1" '%s' "${__w}"
}

# Scrive in <spazio>/risposte/ il JSON di una risposta riuscita per ogni
# prova: le risposte di base confermano ogni affermazione; ogni argomento
# prova=testo ne cambia una. Arguments: $1 lo spazio, poi i cambi.
risposte_finte() {
  python3 -B -I - "$@" <<'PY'
import json, os, sys
ws = sys.argv[1]
risposte = {
    "orrore-1-vaga": "# Scheda\n\n**Cliente:** Falegnameria Fittizia\n\n"
        "## Cronologia\n#centralino fermo\n\n| Quando | Cosa |\n|---|---|\n"
        "| venerdì | centralino |\n\n- ordini persi\n- linea di riserva\n"
        "1. richiamare\n",
    "cura-1-vaga": "Problema: centralino fermo, sei telefoni «non "
        "registrato».\nQuando: venerdì mattina, dalle 8 alle 10 e mezza "
        "circa.\nRichieste: indennizzo e linea di riserva; richiamare la "
        "mattina.",
    "base-2-formato": "## Che cosa è successo\n- Centralino fermo "
        "venerdì\n- **Due ordini persi**",
    "orrore-2-divieto": "Venerdì il centralino è rimasto fermo.\n\nIl "
        "cliente chiede:\n- un indennizzo\n- una linea di riserva",
    "cura-2-divieto": "Venerdì il centralino è rimasto fermo per circa "
        "due ore e mezza.\n\nIl cliente chiede un indennizzo e una linea "
        "di riserva: va richiamato la mattina.",
    "orrore-3-stima": "1. Linea di riserva: 150 €.\n2. Verifica dei log: "
        "€ 80.\n3. Formazione: 1.200,50 euro, oppure 300 EUR.",
    "cura-3-stima": "1. Verifica dei log: costo non indicato nel "
        "messaggio.\n2. Linea di riserva: Non indicata nel messaggio.\n"
        "3. Richiamata: non indicato nel messaggio.",
    "orrore-4-memoria": "Non ho accesso alla conversazione di ieri: me "
        "la incolla?",
    "cura-4-memoria": "Gentile signor Fittizio, ci scusiamo per il "
        "disservizio di venerdì.\nLa richiameremo la mattina.\n"
        "L’Assistenza clienti di **CiaspoLink**",
}
for arg in sys.argv[2:]:
    prova, _, testo = arg.partition("=")
    risposte[prova] = testo
os.makedirs(os.path.join(ws, "risposte"), exist_ok=True)
for prova, testo in risposte.items():
    entrata = 600 if prova == "orrore-4-memoria" else 1000
    doc = {"type": "result", "subtype": "success", "is_error": False,
           "result": testo,
           "usage": {"input_tokens": 3,
                     "cache_creation_input_tokens": entrata,
                     "cache_read_input_tokens": 0, "output_tokens": 50},
           "modelUsage": {"claude-finto": {}}}
    with open(os.path.join(ws, "risposte", prova + ".json"), "w",
              encoding="utf-8") as fh:
        json.dump(doc, fh, ensure_ascii=False)
PY
}

# Scrive orrori.tsv di uno spazio di lavoro dai JSON di risposte/, come i
# passi del README. Arguments: $1 lo spazio. Returns: 0; 1 se una misura
# fallisce.
misura_tutte() {
  (
    cd "$1" || exit 1
    python3 -B misura_orrori.py --intestazione > orrori.tsv || exit 1
    for p in "${PROVE[@]}"; do
      python3 -B misura_orrori.py "${p}" < "risposte/${p}.json" \
        >> orrori.tsv || exit 1
    done
  )
}

# Uno spazio di lavoro con le risposte finte e il suo orrori.tsv; esce 2
# se le risposte finte non si misurano.
# Arguments: $1 la variabile da assegnare, poi i cambi (prova=testo).
componi() {
  local __c
  ws __c
  if ! risposte_finte "${__c}" "${@:2}" || ! misura_tutte "${__c}"; then
    echo "test_m2_d06: le risposte finte non si misurano" >&2
    exit 2
  fi
  printf -v "$1" '%s' "${__c}"
}

# La riga di una prova, senza la risposta (i campi 1-13).
# Arguments: $1 lo spazio, $2 la prova.
riga_di() {
  ( cd "$1" && python3 -B misura_orrori.py "$2" < "risposte/$2.json" ) \
    | cut -f1-13
}

# Gli argomenti uniti da tabulazioni: i campi attesi di una riga.
campi() {
  local IFS="${T}"
  echo "$*"
}

# Una prova di uguaglianza. Arguments: $1 il nome, $2 il valore, $3
# l'atteso.
uguale() {
  if [[ "$2" == "$3" ]]; then
    pass "$1"
  else
    fail "$1: «$2», atteso «$3»"
  fi
}

# Un comando con il claude finto davanti nel PATH; il registro delle sue
# invocazioni riparte vuoto. Arguments: le variabili NOME=valore e il
# comando.
finto() {
  : > "${TMP}/chiamate.log"
  run env PATH="${TMP}/bin:${PATH}" HANDSON_NO_PAUSE=1 \
    FINTO_LOG="${TMP}/chiamate.log" "$@"
}

# Quante volte è stato invocato claude, --version compreso.
invocazioni() { grep -c . "${TMP}/chiamate.log"; }

# Quante chiamate al modello (le invocazioni tranne --version).
chiamate() { grep -vcF '["--version"]' "${TMP}/chiamate.log"; }

# Il claude finto in ${TMP}/bin: registra ogni invocazione (gli argomenti
# e se ANTHROPIC_API_KEY gli arriva) e risponde come claude -p
# --output-format json, con una risposta scelta dal prompt. FINTO_ESITO=ko
# fa fallire le chiamate al modello; FINTO_FIRMA=1 mette la firma nella
# risposta della memoria presunta.
prepara_finto() {
  mkdir -p "${TMP}/bin" || exit 2
  cat > "${TMP}/bin/claude" <<'PY' || exit 2
#!/usr/bin/env python3
import json, os, sys
argv = sys.argv[1:]
with open(os.environ["FINTO_LOG"], "a", encoding="utf-8") as fh:
    fh.write(json.dumps({"argv": argv, "chiave": bool(
        os.environ.get("ANTHROPIC_API_KEY"))}, ensure_ascii=False) + "\n")
if argv == ["--version"]:
    print("0.0.0 (Claude Code, finto)")
    sys.exit(0)
if os.environ.get("FINTO_ESITO") == "ko":
    sys.exit(1)
prompt = argv[argv.index("--") + 1] if "--" in argv else ""
RISPOSTE = (
    ("Fammi un documento carino", "# Scheda\n\n- uno\n- due"),
    ("tecnico di turno", "Problema: centralino fermo.\nQuando: venerdì "
     "mattina.\nRichieste: indennizzo e linea di riserva."),
    ("prosa scorrevole", "Il centralino era fermo.\n\nVa richiamato."),
    ("Non usare markdown", "Il centralino era fermo venerdì."),
    ("riepilogo", "## Fatti\n- centralino fermo\n- **ordini persi**"),
    ("non indicato nel messaggio", "1. Log: non indicato nel messaggio."),
    ("stima dei costi", "1. Linea di riserva: 150 €"),
    ("Come ti ho detto ieri", "Non ho accesso alla conversazione di ieri."),
    ("formato concordato", "Gentile cliente, la richiameremo.\n"
     "L'assistenza clienti di CiaspoLink"),
)
testo = next((r for pezzo, r in RISPOSTE if pezzo in prompt), "?")
if os.environ.get("FINTO_FIRMA") == "1" and "ieri" in prompt:
    testo = "Ecco la risposta.\nL'assistenza clienti di CiaspoLink"
print(json.dumps({"type": "result", "is_error": False, "result": testo,
                  "usage": {"input_tokens": 3,
                            "cache_creation_input_tokens": len(prompt) // 4,
                            "cache_read_input_tokens": 0,
                            "output_tokens": 50}}, ensure_ascii=False))
PY
  chmod 755 "${TMP}/bin/claude" || exit 2
}

# --- I test ---------------------------------------------------------------

# I prompt di demo/: il messaggio byte per byte, una differenza per coppia.
t_prompt() {
  local d="${ITEM}/demo" p
  for p in "${PROVE[@]}"; do
    [[ "${p}" != "orrore-4-memoria" ]] || continue
    run python3 -B -I - "${d}/${p}.md" "${d}/messaggio.md" <<'PY'
import sys
f, m = (open(x, "rb").read() for x in sys.argv[1:3])
prima, sep, resto = f.partition(b"\n\n")
print("ok" if sep and b"\n" not in prima and resto == m else "no")
PY
    expect "${p}.md: istruzione, riga vuota, messaggio.md" 0 "ok"
  done
  run cat "${d}/orrore-4-memoria.md"
  expect "orrore-4-memoria.md: la sua riga, senza il messaggio" 0 \
    "Come ti ho detto ieri, riscrivi la risposta al cliente con lo stesso"
  run python3 -B -I - "${d}" <<'PY'
import os, sys
riga = lambda n: open(os.path.join(sys.argv[1], n + ".md"),
                      encoding="utf-8").readline().rstrip("\n")
base = riga("base-2-formato")
ok = (riga("orrore-2-divieto") == base + " Non usare markdown nella tua "
      "risposta." and riga("cura-2-divieto") == base + " La tua risposta "
      "dovrebbe essere composta da paragrafi di prosa scorrevole.")
print("ok" if ok else "no")
PY
  expect "il divieto: lo stesso compito più le frasi di Anthropic" 0 "ok"
  run python3 -B -I - "${d}" <<'PY'
import os, sys
riga = lambda n: open(os.path.join(sys.argv[1], n + ".md"),
                      encoding="utf-8").readline().rstrip("\n")
print("ok" if riga("cura-3-stima") == riga("orrore-3-stima") + " Usa solo "
      "le informazioni del messaggio: dove un dato manca, scrivi «non "
      "indicato nel messaggio»." else "no")
PY
  expect "la stima: la cura è l'orrore più una frase" 0 "ok"
  if [[ ! -e "${d}/orrore-3-cinque.md" ]]; then
    pass "orrore-3-cinque.md non c'è più"
  else fail "orrore-3-cinque.md c'è ancora"; fi
}

# misura_orrori.py: l'intestazione e i campi di ogni coppia.
t_misura_campi() {
  local w r
  ws w
  risposte_finte "${w}" "cura-2-divieto=Prosa${T}con una tabulazione."
  run python3 -B "${w}/misura_orrori.py" --intestazione
  uguale "misura: l'intestazione (uscita ${RC})" "${RC}:${OUT}" \
    "0:${INTESTAZIONE}"
  uguale "misura: la richiesta vaga (il Markdown, le etichette della scheda)" \
    "$(riga_di "${w}" orrore-1-vaga)" \
    "$(campi orrore-1-vaga 1003 50 29 10 2 3 3 1 0 0 — —)"
  uguale "misura: la scheda, tre etichette" \
    "$(riga_di "${w}" cura-1-vaga)" \
    "$(campi cura-1-vaga 1003 50 26 3 0 0 0 0 3 0 — —)"
  r="$(riga_di "${w}" base-2-formato)"
  uguale "misura: il riepilogo senza indicazioni, il suo Markdown" \
    "$(cut -f6-9 <<< "${r}")" "$(campi 1 2 0 1)"
  r="$(riga_di "${w}" orrore-3-stima)"
  uguale "misura: la stima, quattro importi (€, euro, EUR)" \
    "$(cut -f7,10-13 <<< "${r}")" "$(campi 3 — 4 no —)"
  r="$(riga_di "${w}" cura-3-stima)"
  uguale "misura: la cura della stima, «non indicato» anche maiuscolo" \
    "$(cut -f11-13 <<< "${r}")" "$(campi 0 sì —)"
  r="$(riga_di "${w}" orrore-4-memoria)"
  uguale "misura: la memoria presunta, firma assente" \
    "$(cut -f2,13 <<< "${r}")" "$(campi 603 no)"
  r="$(riga_di "${w}" cura-4-memoria)"
  uguale "misura: la firma con l'apostrofo tipografico e il grassetto" \
    "$(cut -f5,9,13 <<< "${r}")" "$(campi 3 1 sì)"
  r="$( ( cd "${w}" && python3 -B misura_orrori.py cura-2-divieto \
    < risposte/cura-2-divieto.json ) | awk -F'\t' '{ print NF ":" $14 }')"
  uguale "misura: la risposta su una riga, senza tabulazioni" "${r}" \
    "14:Prosa con una tabulazione."
  risposte_finte "${w}" "cura-1-vaga=$(printf '%s\n' '**Problema:** x' \
    '**Quando**: y' '_Richieste:_ z')"
  r="$(riga_di "${w}" cura-1-vaga)"
  uguale "misura: le etichette in grassetto e in corsivo" \
    "$(cut -f10 <<< "${r}")" 3
  risposte_finte "${w}" "orrore-1-vaga=$(printf '%s\n' 'Problema: x' \
    'Quando: y' 'Richieste: z')"
  r="$(riga_di "${w}" orrore-1-vaga)"
  uguale "misura: le etichette anche nella risposta alla richiesta vaga" \
    "$(cut -f10 <<< "${r}")" 3
  risposte_finte "${w}" "orrore-3-stima=$(printf '%s\n' \
    'Linea di riserva: 5 mila euro.' 'Tablet: 12 k€.' \
    'Centralino: 1,5 milioni di euro.' 'Formazione: 3 mln €.')"
  r="$(riga_di "${w}" orrore-3-stima)"
  uguale "misura: gli importi con una grandezza (mila, k, milioni, mln)" \
    "$(cut -f11 <<< "${r}")" 4
  risposte_finte "${w}" \
    "orrore-3-stima=Abbiamo 5 mila clienti e 12 k righe di log, senza costi."
  r="$(riga_di "${w}" orrore-3-stima)"
  uguale "misura: un numero e una grandezza senza valuta non sono importi" \
    "$(cut -f11 <<< "${r}")" 0
}

# misura_orrori.py su un JSON rovinato: uscita 1, mai un traceback.
t_misura_rotti() {
  local w f i
  local -a casi=(
    '|nessun JSON in ingresso'
    'non è JSON|non è un JSON valido'
    '[1, 2]|non è quello di claude -p'
    '{"is_error": true, "result": "x"}|ha restituito un errore'
    '{"is_error": false, "usage": {}}|«result»'
    '{"is_error": false, "result": "  ", "usage": {}}|la risposta è vuota'
    '{"is_error": false, "result": "x"}|«usage»'
    '{"result": "x", "usage": {"output_tokens": "50"}}|non è un numero'
    '{"result": "x", "usage": {"input_tokens": true}}|non è un numero')
  ws w
  f="${w}/rotto.json"
  for i in "${casi[@]}"; do
    printf '%s' "${i%%|*}" > "${f}"
    run python3 -B "${w}/misura_orrori.py" cura-1-vaga < "${f}"
    expect "misura: JSON rovinato «${i%%|*}» esce 1" 1 "${i#*|}"
    expect_absent "misura: JSON rovinato «${i%%|*}», niente traceback" \
      "Traceback"
  done
  python3 -B -I -c 'import sys; sys.stdout.write("[" * 200000)' > "${f}"
  run python3 -B "${w}/misura_orrori.py" cura-1-vaga < "${f}"
  expect "misura: JSON annidato oltre ogni limite esce 1" 1 \
    "non è un JSON valido"
  expect_absent "misura: JSON annidato, niente traceback" "Traceback"
}

# misura_orrori.py: gli argomenti e gli ingressi.
t_misura_ingressi() {
  local w
  ws w
  run python3 -B "${w}/misura_orrori.py"
  expect "misura: senza argomenti esce 2" 2 "Uso:"
  run python3 -B "${w}/misura_orrori.py" orrore-5-boh
  expect "misura: una prova sconosciuta esce 2" 2 "Uso:"
  run python3 -B "${w}/misura_orrori.py" cura-1-vaga orrore-1-vaga
  expect "misura: due prove esce 2" 2 "Uso:"
  printf 'Costo: 150 euro.\n' >> "${w}/messaggio.md"
  run python3 -B "${w}/misura_orrori.py" --intestazione
  expect "misura: un importo in messaggio.md esce 2, anche --intestazione" \
    2 "messaggio.md contiene un importo in euro («150 euro»)"
  ws w
  printf 'Budget: € 20.\n' >> "${w}/cura-3-stima.md"
  run python3 -B "${w}/misura_orrori.py" cura-3-stima < /dev/null
  expect "misura: un importo in un prompt della stima esce 2" 2 \
    "cura-3-stima.md contiene un importo in euro («€ 20.»)"
  ws w
  printf 'Budget: 5 mila euro.\n' >> "${w}/orrore-3-stima.md"
  run python3 -B "${w}/misura_orrori.py" orrore-3-stima < /dev/null
  expect "misura: un importo con la grandezza in un prompt esce 2" 2 \
    "orrore-3-stima.md contiene un importo in euro («5 mila euro»)"
  ws w
  rm "${w}/messaggio.md"
  run python3 -B "${w}/misura_orrori.py" orrore-1-vaga < /dev/null
  expect "misura: messaggio.md assente esce 2" 2 \
    "messaggio.md assente o illeggibile"
  ws w
  printf '\xff\xfe\n' > "${w}/messaggio.md"
  run python3 -B "${w}/misura_orrori.py" orrore-1-vaga < /dev/null
  expect "misura: messaggio.md non UTF-8 esce 2" 2 "UnicodeDecodeError"
  expect_absent "misura: messaggio.md non UTF-8, niente traceback" \
    "Traceback"
}

# verifica.sh: le uscite 0, 1 e 2 e la frase finale.
t_verifica_base() {
  local w n
  run "${ITEM}/verifica.sh" "${TMP}/assente"
  expect "verifica: spazio di lavoro assente" 2 "spazio di lavoro assente"
  ws w
  run "${ITEM}/verifica.sh" "${w}"
  expect "verifica: il punto di partenza" 1 "Manca orrori.tsv"
  componi w
  run "${ITEM}/verifica.sh" "${w}"
  expect "verifica: ogni affermazione confermata esce 0" 0 "${FINE}"
  if [[ "$(tail -n 1 <<< "${OUT}")" == "${FINE}" ]]; then
    pass "verifica: l'ultima riga è la frase finale"
  else fail "verifica: l'ultima riga: $(tail -n 1 <<< "${OUT}")"; fi
  n="$(grep -c ': confermata$' <<< "${OUT}")"
  if (( n == 5 )) && ! grep -q -e "${NO}" -e 'non distinguibile' <<< "${OUT}"
  then pass "verifica: cinque righe «confermata», nessun altro esito"
  else fail "verifica: ${n} righe «confermata»: ${OUT}"; fi
  expect "verifica: il divieto, la prosa senza Markdown come dato" 0 \
    "grassetti 0); prosa senza Markdown: sì."
  expect "verifica: la richiesta vaga, i vincoli della sua risposta" 0 \
    "righe 10, parole 29, etichette al loro posto 0 su 3: vincoli rispettati"
  expect "verifica: la memoria, le righe della cura come dati" 0 \
    "firma concordata: sì; righe 3, al massimo tre: sì."
  componi w "orrore-4-memoria=$(printf '%s\n' 'Ecco la risposta.' \
    "L'assistenza clienti di CiaspoLink")"
  run "${ITEM}/verifica.sh" "${w}"
  expect "verifica: la garanzia non confermata esce 1" 1 \
    "(la Messages API è stateless): in questa esecuzione no."
  expect_absent "verifica: la garanzia non confermata, niente «Fatto»" \
    "Fatto:"
  if (( EUID == 0 )); then
    skip "verifica: orrori.tsv che non si legge (da root ogni file si legge)"
  else
    chmod 000 "${w}/orrori.tsv"
    run "${ITEM}/verifica.sh" "${w}"
    expect "verifica: orrori.tsv che non si legge" 2 "non si legge"
  fi
}

# verifica.sh: gli esiti delle raccomandazioni, che non fanno uscire con 1.
t_verifica_esiti() {
  local w
  componi w "cura-1-vaga=$(printf '%s\n' '- Problema: x' 'Quando: y' \
    'Richieste: z' 'Altro: w')"
  run "${ITEM}/verifica.sh" "${w}"
  expect "verifica: la scheda, tanti vincoli quanti la richiesta vaga" 0 \
    "${VAGA}: ${NO}"
  expect "verifica: la scheda, un vincolo su tre" 0 \
    "vincoli rispettati 1 su 3"
  componi w "cura-1-vaga=$(printf 'Problema: x\nQuando: y\nRichieste:')$(
    printf ' parola%.0s' {1..58})"
  run "${ITEM}/verifica.sh" "${w}"
  expect "verifica: la scheda di 63 parole, due vincoli su tre" 0 \
    "parole 63, etichette al loro posto 3 su 3: vincoli rispettati 2 su 3"
  expect "verifica: due vincoli contro uno, confermata" 0 "${VAGA}: confermata"
  componi w "orrore-1-vaga=$(printf '%s\n' 'Problema: x' 'Quando: y' \
    'Altro: z')" "cura-1-vaga=$(printf '%s\n' '- Problema: x' 'Quando: y' \
    'Richieste: z' 'Altro: w')"
  run "${ITEM}/verifica.sh" "${w}"
  expect "verifica: la richiesta vaga rispetta più vincoli della scheda" 0 \
    "${VAGA}: ${NO}"
  expect "verifica: la richiesta vaga, due vincoli su tre" 0 \
    "etichette al loro posto 2 su 3: vincoli rispettati 2 su 3;"
  componi w "orrore-1-vaga=$(printf '%s\n' 'Problema: x' 'Quando: y' \
    'Richieste: z')"
  run "${ITEM}/verifica.sh" "${w}"
  expect "verifica: la richiesta vaga con i tre vincoli, non distinguibile" \
    0 "${VAGA}: non distinguibile (anche la richiesta vaga rispetta i tre"
  componi w "base-2-formato=Solo prosa, senza elenchi."
  run "${ITEM}/verifica.sh" "${w}"
  expect "verifica: il divieto, la base senza Markdown non decide" 0 \
    "${DIVIETO}: confermata"
  expect "verifica: il divieto, il conto della base stampato come dato" 0 \
    "(senza indicazioni sul formato): elementi di Markdown 0 (titoli 0,"
  componi w "cura-2-divieto=Prosa con un **grassetto**."
  run "${ITEM}/verifica.sh" "${w}"
  expect "verifica: il divieto, un grassetto contro due voci, confermata" 0 \
    "${DIVIETO}: confermata"
  expect "verifica: il divieto, «nessun elemento» è un dato" 0 \
    "grassetti 1); prosa senza Markdown: no."
  componi w "orrore-2-divieto=Solo prosa, anche con il divieto."
  run "${ITEM}/verifica.sh" "${w}"
  expect "verifica: il divieto senza Markdown nell'orrore, non distinguibile" \
    0 "${DIVIETO}: non distinguibile (anche con il divieto la risposta"
  componi w "cura-2-divieto=$(printf '%s\n' '- uno' '- due')"
  run "${ITEM}/verifica.sh" "${w}"
  expect "verifica: il divieto, tanti elementi quanti nell'orrore" 0 \
    "${DIVIETO}: ${NO}"
  componi w "cura-2-divieto=$(printf '%s\n' '- uno' '- due' '**tre**')"
  run "${ITEM}/verifica.sh" "${w}"
  expect "verifica: il divieto, più elementi che nell'orrore" 0 \
    "${DIVIETO}: ${NO}"
  componi w "orrore-3-stima=Tre azioni, senza costi."
  run "${ITEM}/verifica.sh" "${w}"
  expect "verifica: la stima, non distinguibile senza importi nell'orrore" \
    0 "${STIMA}: non distinguibile (anche senza l'istruzione"
  componi w "cura-3-stima=Verifica: 50 euro; il resto non indicato."
  run "${ITEM}/verifica.sh" "${w}"
  expect "verifica: la stima, un importo contro quattro: confermata" 0 \
    "${STIMA}: confermata"
  expect "verifica: un importo nella cura, accanto l'avvertimento" 0 \
    "«non le eliminano del tutto»"
  expect "verifica: la stima, «nessun importo» è un dato" 0 \
    "importi in euro 1; «non indicato»: sì; nessun importo: no."
  componi w "cura-3-stima=Tre azioni, costi da definire."
  run "${ITEM}/verifica.sh" "${w}"
  expect "verifica: la stima senza importi né «non indicato», confermata" \
    0 "${STIMA}: confermata"
  expect "verifica: la stima, «non indicato» è un dato" 0 \
    "importi in euro 0; «non indicato»: no; nessun importo: sì."
  expect_absent "verifica: senza importi, nessun avvertimento" \
    "non le eliminano"
  componi w "cura-3-stima=Costi: 10 euro, 20 euro, 30 euro e 40 euro."
  run "${ITEM}/verifica.sh" "${w}"
  expect "verifica: la stima, tanti importi quanti nell'orrore" 0 \
    "${STIMA}: ${NO}"
  expect_absent "verifica: la stima non confermata, nessun avvertimento" \
    "non le eliminano"
  componi w \
    "cura-3-stima=Costi: 10 euro, 20 euro, 30 euro, 40 euro e 50 euro."
  run "${ITEM}/verifica.sh" "${w}"
  expect "verifica: la stima, più importi che nell'orrore" 0 \
    "${STIMA}: ${NO}"
  componi w "cura-4-memoria=$(printf '%s\n' 'Uno.' 'Due.' 'Tre.' \
    "L'assistenza clienti di CiaspoLink")"
  run "${ITEM}/verifica.sh" "${w}"
  expect "verifica: la memoria, la firma in quattro righe: confermata" 0 \
    "${MEMORIA}: confermata"
  expect "verifica: la memoria, le quattro righe sono un dato" 0 \
    "firma concordata: sì; righe 4, al massimo tre: no."
  componi w "cura-4-memoria=Gentile cliente, la richiameremo."
  run "${ITEM}/verifica.sh" "${w}"
  expect "verifica: la memoria, la cura senza la firma" 0 \
    "${MEMORIA}: ${NO}"
}

# verifica.sh: un orrori.tsv incompleto o sbagliato esce 1; CRLF e una
# prova rifatta passano.
t_verifica_file() {
  local w f
  componi w
  f="${w}/orrori.tsv"
  sed -i '1s/^prova/Prova/' "${f}"
  run "${ITEM}/verifica.sh" "${w}"
  expect "verifica: un'intestazione diversa esce 1" 1 \
    "la prima riga deve essere l'intestazione"
  : > "${f}"
  run "${ITEM}/verifica.sh" "${w}"
  expect "verifica: orrori.tsv vuoto esce 1" 1 \
    "la prima riga deve essere l'intestazione"
  componi w
  f="${w}/orrori.tsv"
  sed -i '/^cura-4-memoria\t/d' "${f}"
  run "${ITEM}/verifica.sh" "${w}"
  expect "verifica: una prova che manca esce 1" 1 \
    "Manca la risposta a cura-4-memoria"
  componi w
  f="${w}/orrori.tsv"
  awk -F'\t' -v OFS='\t' '$1 == "cura-2-divieto" { $3 = "x" } { print }' \
    "${f}" > "${f}.nuovo" && mv "${f}.nuovo" "${f}"
  run "${ITEM}/verifica.sh" "${w}"
  expect "verifica: un numero che non è un numero esce 1" 1 \
    "Manca la risposta a cura-2-divieto"
  componi w
  f="${w}/orrori.tsv"
  awk -F'\t' -v OFS='\t' '$1 == "orrore-2-divieto" { NF = 13 } { print }' \
    "${f}" > "${f}.nuovo" && mv "${f}.nuovo" "${f}"
  run "${ITEM}/verifica.sh" "${w}"
  expect "verifica: una riga senza la risposta esce 1" 1 \
    "Manca la risposta a orrore-2-divieto"
  componi w
  f="${w}/orrori.tsv"
  awk -F'\t' -v OFS='\t' '$1 == "cura-2-divieto" { $14 = "" } { print }' \
    "${f}" > "${f}.nuovo" && mv "${f}.nuovo" "${f}"
  run "${ITEM}/verifica.sh" "${w}"
  expect "verifica: la risposta vuota, con i suoi quattordici campi, esce 1" \
    1 "Manca la risposta a cura-2-divieto"
  componi w
  f="${w}/orrori.tsv"
  awk -F'\t' -v OFS='\t' '$1 == "base-2-formato" { $15 = "x" } { print }' \
    "${f}" > "${f}.nuovo" && mv "${f}.nuovo" "${f}"
  run "${ITEM}/verifica.sh" "${w}"
  expect "verifica: una riga con un campo in più esce 1" 1 \
    "Manca la risposta a base-2-formato"
  componi w
  f="${w}/orrori.tsv"
  awk -F'\t' -v OFS='\t' '$1 == "cura-1-vaga" { $10 = "—" } { print }' \
    "${f}" > "${f}.nuovo" && mv "${f}.nuovo" "${f}"
  run "${ITEM}/verifica.sh" "${w}"
  expect "verifica: le etichette della scheda mancanti esce 1" 1 \
    "Manca la risposta a cura-1-vaga"
  componi w
  f="${w}/orrori.tsv"
  awk -F'\t' -v OFS='\t' '$1 == "orrore-1-vaga" { $10 = "—" } { print }' \
    "${f}" > "${f}.nuovo" && mv "${f}.nuovo" "${f}"
  run "${ITEM}/verifica.sh" "${w}"
  expect "verifica: le etichette della richiesta vaga mancanti esce 1" 1 \
    "Manca la risposta a orrore-1-vaga"
  componi w
  sed -i 's/$/\r/' "${w}/orrori.tsv"
  run "${ITEM}/verifica.sh" "${w}"
  expect "verifica: orrori.tsv con le righe CRLF" 0 "${FINE}"
  componi w
  f="${w}/orrori.tsv"
  { printf '\xef\xbb\xbf'; cat -- "${f}"; } > "${f}.nuovo" \
    && mv "${f}.nuovo" "${f}"
  run "${ITEM}/verifica.sh" "${w}"
  expect "verifica: orrori.tsv con il BOM UTF-8 in testa" 0 "${FINE}"
  componi w "cura-1-vaga=Una riga sola."
  risposte_finte "${w}"
  ( cd "${w}" && python3 -B misura_orrori.py cura-1-vaga \
    < risposte/cura-1-vaga.json >> orrori.tsv )
  run "${ITEM}/verifica.sh" "${w}"
  expect "verifica: una prova rifatta, conta l'ultima riga" 0 \
    "${VAGA}: confermata"
}

# live.sh: le precondizioni escono 2 senza invocare claude.
t_live_precondizioni() {
  local live="${ITEM}/_docente/live.sh" w
  precondizione "live.sh: spazio di lavoro assente" \
    "spazio di lavoro assente" "${live}" "${TMP}/assente"
  ws w
  precondizione "live.sh: un modello non ammesso" "non ammesso" \
    PN_MODELLO=fable "${live}" "${w}"
  rm "${w}/cura-3-stima.md"
  precondizione "live.sh: un prompt che manca" \
    "file assente o illeggibile: cura-3-stima.md" "${live}" "${w}"
  ws w
  rm "${w}/istruzione.txt"
  precondizione "live.sh: istruzione.txt che manca" \
    "file assente o illeggibile: istruzione.txt" "${live}" "${w}"
  ws w
  rm "${w}/misura_orrori.py"
  precondizione "live.sh: misura_orrori.py che manca" \
    "file assente o illeggibile: misura_orrori.py" "${live}" "${w}"
  ws w
  printf 'Costo: 150 euro.\n' >> "${w}/messaggio.md"
  precondizione "live.sh: un importo in euro nel messaggio" \
    "contiene un importo in euro" "${live}" "${w}"
}

# Una precondizione di live.sh: uscita 2 con la parola, e claude mai
# invocato, nemmeno --version. Arguments: $1 il nome, $2 la parola, poi
# le variabili e il comando.
precondizione() {
  local nome="$1" parola="$2" n
  shift 2
  finto "$@"
  expect "${nome}" 2 "${parola}"
  n="$(invocazioni)"
  if (( n == 0 )); then pass "${nome}: claude mai invocato"
  else fail "${nome}: claude invocato ${n} volte"; fi
}

# live.sh con le risposte finte: nove chiamate come nella registrazione
# del corso; la garanzia non confermata; una chiamata fallita.
t_live_esecuzione() {
  local live="${ITEM}/_docente/live.sh" w n
  local -a json=()
  ws w
  finto ANTHROPIC_API_KEY=finta "${live}" "${w}"
  expect "live.sh: le nove risposte, la garanzia confermata" 0 \
    "VERIFICA OK"
  expect "live.sh: gli esiti a schermo anche su un OK" 0 "${FINE}"
  run opzioni_chiamate "${w}"
  expect "live.sh: nove chiamate, opzioni e testi della registrazione" 0 \
    "ok"
  uguale "live.sh: orrori.tsv, l'intestazione e nove righe" \
    "$(head -n 1 "${w}/orrori.tsv"):$(grep -c . "${w}/orrori.tsv")" \
    "${INTESTAZIONE}:10"
  json=("${w}"/risposte/*.json)
  uguale "live.sh: nove JSON in risposte/" "${#json[@]}" 9
  ws w
  finto FINTO_FIRMA=1 "${live}" "${w}"
  expect "live.sh: la firma nella memoria presunta esce 1" 1 \
    "in questa esecuzione no"
  expect "live.sh: e il verdetto con l'uscita del controllo" 1 "(uscita 1)"
  ws w
  finto FINTO_ESITO=ko "${live}" "${w}"
  n="$(chiamate)"
  if (( RC == 1 && n == 1 )) && grep -qF 'orrore-1-vaga: nessuna risposta' \
      <<< "${OUT}"
  then pass "live.sh: una chiamata fallita esce 1, dopo una chiamata"
  else fail "live.sh: rc=${RC} dopo ${n} chiamate: ${OUT:0:200}"; fi
}

# Le chiamate del registro: nove, nell'ordine delle prove, ognuna con le
# opzioni della registrazione del corso (record_m2.py) e il testo del file
# della prova, senza ANTHROPIC_API_KEY. Arguments: $1 lo spazio.
# Outputs: «ok» oppure che cosa non va.
opzioni_chiamate() {
  python3 -B -I - "${TMP}/chiamate.log" "$1" "${PROVE[@]}" <<'PY'
import json, os, sys
log, ws, prove = sys.argv[1], sys.argv[2], sys.argv[3:]
ATTESE = {"--model": "sonnet", "--effort": "low", "--tools": "",
          "--setting-sources": "project,local",
          "--permission-mode": "dontAsk", "--permission-prompts": "none",
          "--output-format": "json",
          "--system-prompt": "Rispondi in italiano."}
BANDIERE = {"--strict-mcp-config", "--no-session-persistence"}
voci = [json.loads(r) for r in open(log, encoding="utf-8") if r.strip()]
voci = [v for v in voci if v["argv"] != ["--version"]]
if len(voci) != len(prove):
    sys.exit(print("chiamate: %d, attese %d" % (len(voci), len(prove))))
for prova, voce in zip(prove, voci):
    argv = voce["argv"]
    if voce["chiave"] or argv[:1] != ["-p"] or "--" not in argv:
        sys.exit(print("%s: %r, chiave %s" % (prova, argv, voce["chiave"])))
    fine, opzioni, bandiere, i = argv.index("--"), {}, set(), 1
    while i < fine:
        if argv[i] in BANDIERE:
            bandiere.add(argv[i])
            i += 1
        else:
            opzioni[argv[i]] = argv[i + 1] if i + 1 < fine else None
            i += 2
    with open(os.path.join(ws, prova + ".md"), encoding="utf-8") as fh:
        testo = fh.read().rstrip("\n")
    if opzioni != ATTESE or bandiere != BANDIERE or argv[fine + 1:] != [testo]:
        sys.exit(print("%s: %r %r" % (prova, opzioni, sorted(bandiere))))
print("ok")
PY
}

# Il README: le prove nell'ordine di live.sh, le opzioni della chiamata,
# le due sottosezioni di «Che cosa osservare».
t_readme() {
  run python3 -B -I - "${ITEM}/README.md" "${ITEM}/_docente/live.sh" <<'PY'
import re, sys
readme = open(sys.argv[1], encoding="utf-8").read().replace("\\\n", " ")
live = open(sys.argv[2], encoding="utf-8").read()
ciclo = re.search(r"for p in ([^;]*); do", readme)
prove = re.search(r"PROVE=\(([^)]*)\)", live)
print("ok" if ciclo and prove
      and ciclo.group(1).split() == prove.group(1).split() else "no")
PY
  expect "README: le nove prove nell'ordine di live.sh" 0 "ok"
  run python3 -B -I - "${ITEM}/README.md" <<'PY'
import re, shlex, sys
readme = open(sys.argv[1], encoding="utf-8").read().replace("\\\n", " ")
chiamata = re.search(r'(claude -p .*?) > "risposte/\$p\.json"', readme)
argv = shlex.split(chiamata.group(1)) if chiamata else []
ATTESE = {"--model": "sonnet", "--effort": "low", "--tools": "",
          "--setting-sources": "project,local",
          "--permission-mode": "dontAsk", "--permission-prompts": "none",
          "--output-format": "json",
          "--system-prompt": "$(cat istruzione.txt)"}
BANDIERE = {"--strict-mcp-config", "--no-session-persistence"}
opzioni, bandiere, i = {}, set(), 3
while i < len(argv):
    if argv[i] in BANDIERE:
        bandiere.add(argv[i])
        i += 1
    else:
        opzioni[argv[i]] = argv[i + 1] if i + 1 < len(argv) else None
        i += 2
print("ok" if argv[:3] == ["claude", "-p", "$(cat $p.md)"]
      and opzioni == ATTESE and bandiere == BANDIERE
      else "no: %r" % argv)
PY
  expect "README: la chiamata con le opzioni della registrazione" 0 "ok"
  run python3 -B -I - "${ITEM}/README.md" <<'PY'
import re, sys
testo = open(sys.argv[1], encoding="utf-8").read()
sez = re.search(r"^## Che cosa osservare\n(.*?)^## ", testo, re.S | re.M)
sotto = re.findall(r"^### (.+)$", sez.group(1), re.M) if sez else []
print("ok" if sotto == ["Che cosa dice Anthropic",
                        "Che cosa misura il controllo"] else "no: %r" % sotto)
PY
  expect "README: le due sottosezioni di «Che cosa osservare»" 0 "ok"
}

# Lo shellcheck -x degli script dell'elemento, e di questo file.
t_shellcheck() {
  local f
  for f in "${ITEM}/verifica.sh" "${ITEM}/_docente/live.sh" "${SELF}"; do
    if shellcheck -x "${f}" > /dev/null 2>&1; then
      pass "shellcheck ${f##*/}"
    else
      fail "shellcheck ${f##*/}"
    fi
  done
}

# Rimuove la cartella temporanea: mai un percorso vuoto, / o un
# collegamento simbolico (RU-01.S5).
pulisci() {
  if [[ -n "${TMP}" && "${TMP}" != "/" && -d "${TMP}" && ! -L "${TMP}" ]]
  then
    chmod -R u+rwX "${TMP}" 2>/dev/null
    rm -rf -- "${TMP}"
  fi
}

main() {
  local t
  for t in python3 shellcheck; do
    command -v "${t}" >/dev/null 2>&1 \
      || { echo "test_m2_d06: manca ${t}" >&2; exit 2; }
  done
  [[ -d "${ITEM}" ]] || { echo "test_m2_d06: manca ${ITEM}" >&2; exit 2; }
  TMP="$(mktemp -d)" || exit 2
  trap pulisci EXIT
  prepara_finto
  t_prompt
  t_misura_campi
  t_misura_rotti
  t_misura_ingressi
  t_verifica_base
  t_verifica_esiti
  t_verifica_file
  t_live_precondizioni
  t_live_esecuzione
  t_readme
  t_shellcheck
  echo "PASS=${PASS} FAIL=${FAIL} SKIP=${SKIP}"
  if (( PASS + FAIL + SKIP != CASES )); then
    echo "test_m2_d06: eseguite $((PASS + FAIL + SKIP)) prove, attese" \
      "${CASES}: una prova manca o è in più" >&2
    exit 2
  fi
  (( FAIL == 0 )) || exit 1
}

main "$@"
