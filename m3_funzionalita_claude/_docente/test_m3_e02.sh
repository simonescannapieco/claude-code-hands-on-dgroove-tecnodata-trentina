#!/bin/bash
#
# test_m3_e02.sh -- le prove di M3-E02 «La dashboard della settimana», per
# il docente:
#   - le copie di M3-E01 (ticket-anonimi.csv, kpi_definizioni.md,
#     kpi_veri.py) uguali byte per byte; soluzione/kpi.json uguale a ciò che
#     stampa kpi_veri.py sulla copia del file anonimo; _docente/aggiorna.py
#     --controlla lo conferma, su una copia dell'elemento con un file
#     cambiato esce 1 e lo rimette a posto, senza M3-E01 esce 2;
#   - verifica.sh: il punto di partenza (1), la soluzione (0, 10 su 10), un
#     valore sbagliato (0: il NO e «9 KPI su 10» sono un dato), il blocco
#     di codice ```json (0), un BOM (0); una chiave che manca o in più, un
#     intero scritto come testo o con la virgola, per_giorno senza una
#     chiave, l'oggetto dentro una chiave kpi, un elenco, un JSON rotto, un
#     testo non UTF-8, le virgolette tipografiche del testo della pagina (1,
#     con il pulsante «Copy» e senza «dalla { alla }»); il contesto di
#     Anthropic stampato, mai
#     «smentita»; le precondizioni (2): spazio di lavoro assente, CSV
#     assente o senza le colonne, kpi_veri.py dell'elemento assente, un
#     controllo uscito fuori contratto;
#   - _docente/confronta_gemello.py su esecuzioni sintetiche, costruite qui
#     come dati di prova (non sono risposte di Claude): confermata, non
#     distinguibile, non confermata in questa esecuzione; le esecuzioni
#     fallite (is_error, senza structured_output, JSON illeggibile) che
#     contano 0; i token stampati; --json; mai «smentita»; una coppia
#     incompleta, una cartella vuota e un'opzione sconosciuta escono 2;
#   - _docente/schema_kpi.json: le chiavi di kpi_veri.py, tutte
#     obbligatorie; la soluzione lo rispetta, un tipo sbagliato, una chiave
#     in più, un giorno che manca no (un validatore minimo, scritto qui);
#   - i prompt: nel README fra i segni, uguali a esercizio/prompt-*.md, in
#     19 righe × 66 colonne; i due della coppia del docente uguali a quello
#     dei numeri dopo il primo paragrafo, e diversi nel primo, dove il
#     braccio file dice che python3 è l'unico comando, da solo; il README con
#     le dieci sezioni; nessun identificativo interno nei file per i
#     partecipanti;
#   - prepara_esercizio.sh e tools/verifica.sh con l'elemento vero;
#   - shellcheck -x su verifica.sh e su questo script.
# Gli spazi di lavoro nascono in una cartella temporanea, nella base di
# handson::init_temp_base (mai dentro ~/.claude, anche se TMPDIR punta
# lì): l'albero del repository non cambia. Un numero di casi diverso da
# CASES esce 2.
#
# Uso:    m3_funzionalita_claude/_docente/test_m3_e02.sh
# Uscita: 0 = tutte le prove passano · 1 = almeno una fallita ·
#         2 = precondizione (manca python3 o shellcheck, un file
#             dell'elemento o di M3-E01; una preparazione non riesce; le
#             prove eseguite non sono quante attese)
set -uo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly MOD="${SELF%/_docente/*}"
readonly RADICE="${MOD%/*}"
readonly SEZIONE="${MOD}/s2_funzionalita_claude"
readonly E02="${SEZIONE}/m3_e3_dashboard/M3-E02_dashboard_settimana"
readonly E01="${SEZIONE}/m3_e2_anonimizzare/M3-E01_anonimizzare_ticket"
# La libreria del repository, per la base dei file temporanei
# (handson::init_temp_base): mai dentro ~/.claude, dove prepara_esercizio.sh
# rifiuta gli spazi di lavoro, anche se TMPDIR punta lì.
# shellcheck source=../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"
readonly CASES=77
readonly FINE="Fatto: kpi.json ha le dieci chiavi, con i tipi giusti."
# Gli identificativi interni che i file per i partecipanti non portano.
INTERNI='FACT-|Tecnodata|[Tt]riage|Envelope|M[0-9]-X[0-9]|\bX-[0-9]'
INTERNI+='|\b(ASK|OQ|DEC|TD|PQ)-[0-9]'
readonly INTERNI
TMP=''
FX=''
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
    fail "$1 (rc=${RC}, attesa $2, parola «$3»): ${OUT:0:600}"
  fi
}

# Nessun falso positivo: la parola NON c'è (RU-01.T5).
# Arguments: $1 il nome, $2 la parola.
expect_absent() {
  if grep -qF -- "$2" <<< "${OUT}"; then
    fail "$1: «$2» c'è: ${OUT:0:600}"
  else
    pass "$1"
  fi
}

# La preparazione di una prova che non riesce: uscita 2.
rotta() { echo "test_m3_e02: preparazione non riuscita: $*" >&2; exit 2; }

# Un nuovo spazio di lavoro dal punto di partenza, più facoltativamente la
# soluzione. Arguments: $1 la variabile da assegnare, $2 «soluzione» o
# niente.
ws() {
  local __ws_d
  __ws_d="$(mktemp -d "${TMP}/ws.XXXXXX")" || rotta "mktemp"
  cp -R "${E02}/esercizio/." "${__ws_d}/" || rotta "cp esercizio"
  if [[ "${2:-}" == "soluzione" ]]; then
    cp -R "${E02}/soluzione/." "${__ws_d}/" || rotta "cp soluzione"
  fi
  printf -v "$1" '%s' "${__ws_d}"
}

# Una modifica dei file con fx.py; la preparazione rotta esce 2.
fx() { python3 -B -I "${FX}" "$@" || rotta "fx $*"; }

# La verifica dell'elemento su uno spazio di lavoro.
verifica() { run "${E02}/verifica.sh" "$1"; }

# La riga di un KPI nella verifica: «  <chiave in 40 colonne> ok|NO».
riga() { printf '  %-40s %s' "$1" "$2"; }

# fx.py: le modifiche di kpi.json e le esecuzioni sintetiche della coppia.
prepara() {
  FX="${TMP}/fx.py"
  cat > "${FX}" <<'PY' || rotta "fx.py"
"""fx.py -- le modifiche delle prove di M3-E02 e le esecuzioni sintetiche
della coppia del docente (dati di prova, non risposte di Claude)."""
import copy
import json
import os
import sys


def leggi(p):
    with open(p, encoding="utf-8") as fh:
        return json.load(fh)


def scrivi(p, d):
    with open(p, "w", encoding="utf-8") as fh:
        json.dump(d, fh, ensure_ascii=False)


def kpi(ws, cosa):
    p = os.path.join(ws, "kpi.json")
    d = leggi(p)
    if cosa == "valore":
        d["voti"] += 1
    elif cosa == "manca":
        del d["annullate"]
    elif cosa == "in_piu":
        d["totale"] = 1
    elif cosa == "testo":
        d["segnalazioni"] = "343"
    elif cosa == "virgola":
        d["segnalazioni"] = 343.0
    elif cosa == "giorno":
        del d["per_giorno"]["dom"]
    elif cosa == "involucro":
        d = {"kpi": d}
    elif cosa == "elenco":
        d = [d]
    else:
        return 2
    scrivi(p, d)
    return 0


def testo(ws, cosa):
    p = os.path.join(ws, "kpi.json")
    with open(p, "rb") as fh:
        t = fh.read()
    if cosa == "recinto":
        t = b"```json\n" + t + b"```\n"
    elif cosa == "bom":
        t = b"\xef\xbb\xbf" + t
    elif cosa == "rotto":
        t = t[:-5]
    elif cosa == "latin1":
        t = t.replace(b'"voti"', '"vòti"'.encode("latin-1"))
    elif cosa == "tipografiche":
        # come il testo della pagina di claude.ai nella prova del docente:
        # “ dopo { o [, ” altrove
        s = t.decode("utf-8")
        t = "".join((chr(0x201C) if i and s[i - 1] in "{[" else
                     chr(0x201D)) if c == '"' else c
                    for i, c in enumerate(s)).encode("utf-8")
    else:
        return 2
    with open(p, "wb") as fh:
        fh.write(t)
    return 0


def esecuzione(so=None, errore=False):
    d = {"type": "result", "subtype": "success", "is_error": errore,
         "num_turns": 2, "session_id": "sessione-di-prova",
         "usage": {"input_tokens": 100, "cache_creation_input_tokens": 30000,
                   "cache_read_input_tokens": 0, "output_tokens": 500},
         "modelUsage": {"claude-sonnet-di-prova": {}}}
    if so is not None:
        d["structured_output"] = so
    return d


def gemello(cartella, modo, vero_p):
    os.makedirs(cartella, exist_ok=True)
    vero = leggi(vero_p)
    sbagliato = copy.deepcopy(vero)
    sbagliato["voti"] += 1
    sbagliato["per_giorno"]["lun"] += 2
    coppie = {"migliore": (sbagliato, vero), "uguale": (vero, vero),
              "peggiore": (vero, sbagliato), "fallite": (vero, None)}
    if modo not in coppie:
        return 2
    incollato, file_ = coppie[modo]
    for n in (1, 2, 3):
        scrivi(os.path.join(cartella, "incollato-%d.json" % n),
               esecuzione(incollato))
        p = os.path.join(cartella, "file-%d.json" % n)
        if modo != "fallite":
            scrivi(p, esecuzione(file_))
        elif n == 1:
            scrivi(p, esecuzione(None, errore=True))
        elif n == 2:
            scrivi(p, esecuzione(None))
        else:
            with open(p, "w", encoding="utf-8") as fh:
                fh.write("{non json")
    return 0


def main(a):
    if a[0] == "kpi":
        return kpi(a[1], a[2])
    if a[0] == "testo":
        return testo(a[1], a[2])
    if a[0] == "gemello":
        return gemello(a[1], a[2], a[3])
    return 2


sys.exit(main(sys.argv[1:]))
PY
}

# Le copie di M3-E01, il riferimento calcolato, aggiorna.py.
t_copie() {
  local voce copia
  for voce in "kpi_veri.py:kpi_veri.py" \
      "esercizio/kpi_definizioni.md:esercizio/kpi_definizioni.md" \
      "esercizio/ticket-anonimi.csv:soluzione/anonimo/ticket-anonimi.csv"; do
    if cmp -s "${E02}/${voce%%:*}" "${E01}/${voce#*:}"; then
      pass "${voce%%:*} uguale a quello di M3-E01"
    else
      fail "${voce%%:*} diverso da quello di M3-E01"
    fi
  done
  if cmp -s <(python3 -B -I "${E02}/kpi_veri.py" \
      "${E02}/esercizio/ticket-anonimi.csv") "${E02}/soluzione/kpi.json"; then
    pass "soluzione/kpi.json è ciò che stampa kpi_veri.py"
  else
    fail "soluzione/kpi.json non è ciò che stampa kpi_veri.py"
  fi
  run python3 -B -I "${E02}/_docente/aggiorna.py" --controlla
  expect "aggiorna --controlla: copie e riferimento identici" 0 \
    "identici byte per byte"
  copia="$(mktemp -d "${TMP}/elemento.XXXXXX")" || rotta "mktemp"
  cp -R "${E02}/." "${copia}/" || rotta "cp elemento"
  printf 'cambiato\n' >> "${copia}/esercizio/kpi_definizioni.md" \
    || rotta "modifica"
  run env PN_M3_E01="${E01}" python3 -B -I "${copia}/_docente/aggiorna.py" \
    --controlla
  expect "aggiorna --controlla: una copia cambiata esce 1" 1 "DIVERSO"
  run env PN_M3_E01="${E01}" python3 -B -I "${copia}/_docente/aggiorna.py"
  if (( RC == 0 )) && cmp -s "${copia}/esercizio/kpi_definizioni.md" \
      "${E01}/esercizio/kpi_definizioni.md"; then
    pass "aggiorna: riscrive la copia cambiata"
  else
    fail "aggiorna: la copia non è stata riscritta (rc=${RC}): ${OUT:0:300}"
  fi
  run env PN_M3_E01="${TMP}/non-esiste" python3 -B -I \
    "${copia}/_docente/aggiorna.py" --controlla
  expect "aggiorna: senza M3-E01 esce 2" 2 "M3-E01 non c'è"
}

# La verifica: partenza, soluzione, un valore sbagliato come dato, il
# blocco di codice, il BOM.
t_verifica() {
  local w
  ws w
  verifica "${w}"
  expect "verifica: il punto di partenza esce 1" 1 \
    "Non ancora: manca kpi.json"
  ws w soluzione
  verifica "${w}"
  expect "verifica: la soluzione esce 0" 0 "${FINE}"
  expect "verifica: la soluzione, 10 KPI su 10 come dato" 0 \
    "Come dato: 10 KPI su 10 corrispondono."
  expect_absent "verifica: la soluzione senza «Non ancora»" "Non ancora"
  expect "verifica: la misura di Anthropic, come contesto" 0 \
    "ha risposto giusto a 7 domande su 25"
  expect "verifica: il confronto lo decide la coppia del docente" 0 \
    "coppia registrata dal docente in Claude Code"
  expect "verifica: l'esito della registrazione del corso, come dato" 0 \
    "Nella registrazione del corso"
  expect_absent "verifica: nessun segnaposto di registrazione" \
    "[REGISTRAZIONE"
  expect_absent "verifica: nessun esito dice «smentita»" "smentit"
  fx kpi "${w}" valore
  verifica "${w}"
  expect "verifica: un valore sbagliato esce 0" 0 \
    "Come dato: 9 KPI su 10 corrispondono."
  expect "verifica: il valore sbagliato stampato con NO" 0 "$(riga voti NO)"
  ws w soluzione
  fx testo "${w}" recinto
  verifica "${w}"
  expect 'verifica: il blocco ```json si toglie, esce 0' 0 \
    "è racchiuso in un blocco di codice"
  expect "verifica: dentro il blocco, 10 KPI su 10" 0 "10 KPI su 10"
  ws w soluzione
  fx testo "${w}" bom
  verifica "${w}"
  expect "verifica: un BOM in testa esce 0" 0 "${FINE}"
}

# La verifica: le forme sbagliate di kpi.json escono 1 e dicono che cosa.
t_verifica_forme() {
  local w voce
  for voce in "manca:Non ancora: manca la chiave annullate." \
      "in_piu:Non ancora: la chiave totale è in più." \
      "testo:segnalazioni: serve un intero, c'è un testo (\"343\")" \
      "virgola:segnalazioni: serve un intero, c'è un numero con la \
virgola (343.0)" \
      "giorno:per_giorno: servono le sette chiavi lun, mar, mer, gio, ven, \
sab, dom (mancano dom)" \
      "involucro:kpi.json ha soltanto la chiave kpi" \
      "elenco:kpi.json non contiene un oggetto JSON"; do
    ws w soluzione
    fx kpi "${w}" "${voce%%:*}"
    verifica "${w}"
    expect "verifica: ${voce%%:*} esce 1" 1 "${voce#*:}"
  done
  ws w soluzione
  fx testo "${w}" rotto
  verifica "${w}"
  expect "verifica: un JSON rotto esce 1" 1 \
    "kpi.json non è un JSON valido (il primo errore alla riga"
  ws w soluzione
  fx testo "${w}" tipografiche
  verifica "${w}"
  expect "verifica: le virgolette tipografiche della pagina escono 1" 1 \
    "kpi.json ha le virgolette tipografiche"
  expect "verifica: e dicono di copiare con il pulsante Copy" 1 \
    "con il pulsante «Copy» sotto la risposta"
  expect_absent "verifica: e non dicono di copiare dalla { alla }" \
    "dalla { alla }"
  ws w soluzione
  fx testo "${w}" latin1
  verifica "${w}"
  expect "verifica: un testo non UTF-8 esce 1" 1 \
    "kpi.json non è un testo UTF-8"
}

# La verifica: le precondizioni, anche su una copia dell'elemento.
t_verifica_precondizioni() {
  local w copia
  run "${E02}/verifica.sh" "${TMP}/non-esiste"
  expect "verifica: spazio di lavoro assente esce 2" 2 \
    "spazio di lavoro assente"
  ws w soluzione
  rm "${w}/ticket-anonimi.csv" || rotta "rm"
  verifica "${w}"
  expect "verifica: senza il CSV esce 2" 2 \
    "manca ticket-anonimi.csv nello spazio di lavoro"
  ws w soluzione
  printf 'a,b\n1,2\n' > "${w}/ticket-anonimi.csv" || rotta "csv"
  verifica "${w}"
  expect "verifica: un CSV senza le colonne esce 2" 2 \
    "i KPI veri non si calcolano"
  copia="$(mktemp -d "${TMP}/elemento.XXXXXX")" || rotta "mktemp"
  cp -R "${E02}/." "${copia}/" || rotta "cp elemento"
  rm "${copia}/kpi_veri.py" || rotta "rm"
  ws w soluzione
  run "${copia}/verifica.sh" "${w}"
  expect "verifica: kpi_veri.py dell'elemento che manca esce 2" 2 \
    "kpi_veri.py"
  printf 'import sys\nsys.exit(5)\n' > "${copia}/verifica.py" || rotta "py"
  run "${copia}/verifica.sh" "${w}"
  expect "verifica: un'uscita fuori contratto diventa 2" 2 \
    "il controllo è uscito con 5"
}

# La coppia del docente, su esecuzioni sintetiche.
t_gemello() {
  local g="${TMP}/gemello" cg="${E02}/_docente/confronta_gemello.py" json
  local vero="${E02}/soluzione/kpi.json"
  fx gemello "${g}/migliore" migliore "${vero}"
  run python3 -B -I "${cg}" "${g}/migliore"
  expect "gemello: più KPI giusti con il file, confermata" 0 \
    "coppia 1: incollato 8, file 10 KPI giusti: confermata"
  expect "gemello: confermata 3 su 3" 0 \
    "In questa registrazione: confermata 3 su 3."
  expect "gemello: i KPI sbagliati elencati" 0 "sbagliati: per_giorno, voti"
  expect "gemello: i token in entrata come dato" 0 "30100"
  expect_absent "gemello: nessun esito dice «smentita»" "smentit"
  json="$(python3 -B -I "${cg}" --json "${g}/migliore" 2>&1)"
  run python3 -B -I -c 'import json, sys
d = json.loads(sys.argv[1])
ok = d["confermate"] == 3 and d["coppie_totali"] == 3 and \
    len(d["esecuzioni"]) == 6 and all(c["esito"] == "confermata"
                                      for c in d["coppie"])
print("json ok" if ok else d)' "${json}"
  expect "gemello --json: il riepilogo per la registrazione" 0 "json ok"
  fx gemello "${g}/uguale" uguale "${vero}"
  run python3 -B -I "${cg}" "${g}/uguale"
  expect "gemello: tanti quanti, non distinguibile" 0 \
    "coppia 2: incollato 10, file 10 KPI giusti: non distinguibile"
  expect "gemello: uguali, confermata 0 su 3" 0 "confermata 0 su 3."
  fx gemello "${g}/peggiore" peggiore "${vero}"
  run python3 -B -I "${cg}" "${g}/peggiore"
  expect "gemello: meno con il file, non confermata in questa esecuzione" 0 \
    "coppia 3: incollato 10, file 8 KPI giusti: non confermata in questa \
esecuzione"
  expect_absent "gemello peggiore: nessun esito dice «smentita»" "smentit"
  fx gemello "${g}/fallite" fallite "${vero}"
  run python3 -B -I "${cg}" "${g}/fallite"
  expect "gemello: is_error è un'esecuzione fallita" 0 \
    "esecuzione fallita: is_error: la chiamata è fallita"
  expect "gemello: senza structured_output è fallita" 0 \
    "esecuzione fallita: nessun structured_output"
  expect "gemello: un JSON illeggibile è fallito" 0 \
    "esecuzione fallita: il JSON non si legge"
  expect "gemello: un'esecuzione fallita conta 0" 0 \
    "coppia 1: incollato 10, file 0 KPI giusti: non confermata"
  rm "${g}/migliore/file-2.json" || rotta "rm"
  run python3 -B -I "${cg}" "${g}/migliore"
  expect "gemello: una coppia incompleta esce 2" 2 \
    "la coppia 2 è incompleta: manca file-2.json"
  mkdir -p "${g}/vuota" || rotta "mkdir"
  run python3 -B -I "${cg}" "${g}/vuota"
  expect "gemello: una cartella vuota esce 2" 2 "nessuna esecuzione"
  run python3 -B -I "${cg}" --boh
  expect "gemello: un'opzione sconosciuta esce 2" 2 "opzione sconosciuta"
}

# Lo schema dei KPI, con un validatore minimo (type, properties, required,
# additionalProperties, minimum).
t_schema() {
  run python3 -B -I - "${E02}/_docente/schema_kpi.json" \
    "${E02}/soluzione/kpi.json" "${E02}/kpi_veri.py" <<'PY'
import copy
import importlib.util
import json
import sys


def valida(s, x):
    errori = []
    tipo = s.get("type")
    if tipo == "object":
        if not isinstance(x, dict):
            return ["non è un oggetto"]
        errori += ["manca %s" % k for k in s.get("required", []) if k not in x]
        proprieta = s.get("properties", {})
        altre = s.get("additionalProperties", True)
        for k, v in x.items():
            if k in proprieta:
                errori += valida(proprieta[k], v)
            elif altre is False:
                errori.append("in più %s" % k)
            elif isinstance(altre, dict):
                errori += valida(altre, v)
    elif tipo == "integer":
        if isinstance(x, bool) or not isinstance(x, int):
            errori.append("non è un intero")
        elif x < s.get("minimum", x):
            errori.append("sotto il minimo")
    elif tipo == "number":
        if isinstance(x, bool) or not isinstance(x, (int, float)):
            errori.append("non è un numero")
    return errori


schema = json.load(open(sys.argv[1], encoding="utf-8"))
vero = json.load(open(sys.argv[2], encoding="utf-8"))
spec = importlib.util.spec_from_file_location("kv", sys.argv[3])
kv = importlib.util.module_from_spec(spec)
spec.loader.exec_module(kv)
if sorted(schema["required"]) == sorted(kv.CHIAVI) == \
        sorted(schema["properties"]) and \
        schema["additionalProperties"] is False:
    print("chiavi ok")
if not valida(schema, vero):
    print("soluzione ok")
casi = {}
casi["testo"] = dict(vero, segnalazioni="343")
casi["chiave in più"] = dict(vero, totale=1)
giorni = dict(vero["per_giorno"])
del giorni["dom"]
casi["giorno"] = dict(vero, per_giorno=giorni)
casi["categoria"] = dict(vero, per_categoria=dict(vero["per_categoria"],
                                                  wifi=32.5))
for nome, istanza in casi.items():
    print("%s %s" % (nome, "respinto" if valida(schema, istanza)
                     else "accettato"))
PY
  expect "schema: le chiavi di kpi_veri.py, obbligatorie, nessuna in più" 0 \
    "chiavi ok"
  expect "schema: la soluzione lo rispetta" 0 "soluzione ok"
  expect "schema: un intero scritto come testo è respinto" 0 "testo respinto"
  expect "schema: una chiave in più è respinta" 0 "chiave in più respinto"
  expect "schema: un giorno che manca è respinto" 0 "giorno respinto"
  expect "schema: un decimale in per_categoria è respinto" 0 \
    "categoria respinto"
}

# I prompt, il README, gli identificativi interni.
t_readme() {
  local f trovati=''
  run python3 -B -I - "${E02}" <<'PY'
import os
import sys
import textwrap

e = sys.argv[1]
righe = open(os.path.join(e, "README.md"), encoding="utf-8").read().split("\n")


def leggi(*parti):
    return open(os.path.join(e, *parti), encoding="utf-8").read()


def tra(a, b):
    i = [k for k, r in enumerate(righe) if r.strip() == a]
    j = [k for k, r in enumerate(righe) if r.strip() == b]
    if len(i) != 1 or len(j) != 1 or i[0] > j[0]:
        return None
    return textwrap.dedent("\n".join(righe[i[0] + 1:j[0]])).strip("\n")


for nome in ("numeri", "dashboard"):
    testo = leggi("esercizio", "prompt-%s.md" % nome)
    if tra("<!-- prompt: %s -->" % nome,
           "<!-- /prompt: %s -->" % nome) + "\n" == testo:
        print("%s uguale" % nome)
    r = testo.rstrip("\n").split("\n")
    if len(r) <= 19 and max(len(x) for x in r) <= 66:
        print("%s in 19 x 66" % nome)
testa, _, coda = leggi("esercizio", "prompt-numeri.md").partition("\n\n")
gemelli = [leggi("_docente", "prompt-%s.md" % b).partition("\n\n")
           for b in ("incollato", "file")]
if coda and all(g[2] == coda for g in gemelli):
    print("coppia stessa coda")
if len({testa, gemelli[0][0], gemelli[1][0]}) == 3 and \
        "con il codice" in gemelli[1][0] and \
        "con il codice" not in gemelli[0][0]:
    print("coppia primo paragrafo diverso")
if "L'unico comando permesso è python3" in gemelli[1][0] and \
        "senza concatenarlo ad altri" in gemelli[1][0] and \
        "python3" not in gemelli[0][0]:
    print("coppia il braccio file dice il suo comando")
sezioni = ("Obiettivo", "Tempo", "Prerequisiti", "Punto di partenza",
           "Passi in Claude Code", "Che cosa osservare", "Verifica",
           "Se qualcosa va storto", "Impronta d'uso sul piano Pro",
           "Per approfondire")
if all(any(r.startswith("## " + s) for r in righe) for s in sezioni):
    print("sezioni ok")
PY
  expect "README: il prompt dei numeri uguale al suo file" 0 "numeri uguale"
  expect "README: il prompt della dashboard uguale al suo file" 0 \
    "dashboard uguale"
  expect "prompt dei numeri in 19 righe × 66 colonne" 0 "numeri in 19 x 66"
  expect "prompt della dashboard in 19 righe × 66 colonne" 0 \
    "dashboard in 19 x 66"
  expect "coppia: le dieci chiavi uguali al prompt dei numeri" 0 \
    "coppia stessa coda"
  expect "coppia: il primo paragrafo dice dove sta la tabella" 0 \
    "coppia primo paragrafo diverso"
  expect "coppia: il braccio file dice che python3 va eseguito da solo" 0 \
    "coppia il braccio file dice il suo comando"
  expect "README: le dieci sezioni" 0 "sezioni ok"
  for f in README.md verifica.sh verifica.py kpi_veri.py \
      esercizio/prompt-numeri.md esercizio/prompt-dashboard.md \
      esercizio/kpi_definizioni.md; do
    if grep -qE -- "${INTERNI}" "${E02}/${f}"; then
      trovati+=" ${f}"
    fi
  done
  if [[ -z "${trovati}" ]]; then
    pass "nessun identificativo interno nei file per i partecipanti"
  else
    fail "identificativi interni in:${trovati}"
  fi
}

# Gli strumenti del repository: prepara_esercizio.sh e verifica.sh.
t_integrazione() {
  local radice
  radice="$(mktemp -d "${TMP}/radice.XXXXXX")" || rotta "mktemp"
  run "${RADICE}/tools/prepara_esercizio.sh" M3-E02 --radice "${radice}"
  expect "prepara_esercizio.sh M3-E02" 0 \
    "Questo elemento si svolge su claude.ai"
  if [[ -f "${radice}/M3-E02/ticket-anonimi.csv" \
      && -f "${radice}/M3-E02/prompt-numeri.md" \
      && -f "${radice}/M3-E02/.claude/settings.json" \
      && ! -e "${radice}/M3-E02/kpi.json" \
      && ! -e "${radice}/M3-E02/_docente" \
      && ! -e "${radice}/M3-E02/confronta_gemello.py" ]]; then
    pass "lo spazio di lavoro: il punto di partenza, senza soluzione né docente"
  else
    fail "lo spazio di lavoro non è il punto di partenza"
  fi
  run "${RADICE}/tools/verifica.sh" M3-E02 --radice "${radice}"
  expect "tools/verifica.sh sul punto di partenza esce 1" 1 "NON ANCORA"
  cp -R "${E02}/soluzione/." "${radice}/M3-E02/" || rotta "cp soluzione"
  run "${RADICE}/tools/verifica.sh" M3-E02 --radice "${radice}"
  expect "tools/verifica.sh con la soluzione esce 0" 0 "VERIFICA OK"
}

t_shellcheck() {
  local f
  for f in "${E02}/verifica.sh" "${SELF}"; do
    if (cd "${RADICE}" && shellcheck -x "${f}") > /dev/null 2>&1; then
      pass "shellcheck ${f#"${RADICE}"/}"
    else
      fail "shellcheck ${f#"${RADICE}"/}"
    fi
  done
}

main() {
  local t
  for t in python3 shellcheck; do
    command -v "${t}" > /dev/null 2>&1 \
      || { echo "test_m3_e02: manca ${t}" >&2; exit 2; }
  done
  for t in verifica.sh verifica.py kpi_veri.py esercizio/ticket-anonimi.csv \
      esercizio/prompt-numeri.md soluzione/kpi.json _docente/aggiorna.py \
      _docente/confronta_gemello.py _docente/schema_kpi.json; do
    [[ -e "${E02}/${t}" ]] || { echo "test_m3_e02: manca ${t}" >&2; exit 2; }
  done
  [[ -f "${E01}/kpi_veri.py" ]] \
    || { echo "test_m3_e02: manca M3-E01" >&2; exit 2; }
  handson::init_temp_base
  TMP="$(mktemp -d "${HANDSON_TEMP_BASE}/test_m3_e02.XXXXXX")" || exit 2
  trap 'rm -rf "${TMP}"' EXIT
  prepara
  t_copie
  t_verifica
  t_verifica_forme
  t_verifica_precondizioni
  t_gemello
  t_schema
  t_readme
  t_integrazione
  t_shellcheck
  echo "PASS=${PASS} FAIL=${FAIL} CASES=$((PASS + FAIL))/${CASES}"
  if (( PASS + FAIL != CASES )); then
    echo "test_m3_e02: eseguite $((PASS + FAIL)) prove, attese ${CASES}:" \
      "un caso manca o non è contato" >&2
    exit 2
  fi
  (( FAIL == 0 )) || exit 1
}

main "$@"
