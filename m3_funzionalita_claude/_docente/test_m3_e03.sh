#!/bin/bash
#
# test_m3_e03.sh -- le prove di M3-E03 «La stessa dashboard in Claude
# Code», per il docente:
#   - le copie di M3-E01 (anonimo/ticket-anonimi.csv, anonimo/profilo.json,
#     kpi_definizioni.md, kpi_veri.py) uguali byte per byte;
#     _docente/aggiorna.py --controlla lo conferma, su una copia
#     dell'elemento con un file cambiato esce 1 e lo rimette a posto, senza
#     M3-E01 esce 2;
#   - esercizio/controlla_dashboard.py: la pagina della soluzione (0), un
#     numero sbagliato, uno script da una CDN, un @import da internet, un
#     foglio di stile in un altro file, nessun blocco kpi, due blocchi, un
#     blocco che non è JSON, uno script nella pagina che chiama la rete
#     (fetch, import(), XMLHttpRequest, WebSocket, EventSource, sendBeacon,
#     un indirizzo http o https) (1); data:, un link a, un riferimento
#     interno, uno script che non chiama la rete e un blocco di dati con un
#     indirizzo non sono risorse esterne (0, nessun falso positivo); le
#     chiavi prese dal profilo: un profilo con i propri indicatori (il
#     percorso A) e la pagina con le stesse chiavi (0), un valore diverso o
#     una chiave che manca (1), un decimale entro mezza unità dell'ultima
#     cifra del riferimento (0); nessun testo dei ticket stampato; l'ultima
#     riga è sempre l'uscita; ogni esecuzione aggiunge una riga al
#     registro, nella cartella della pagina, anche una precondizione; -h
#     no; le precondizioni (2): niente pagina, niente profilo, un profilo
#     senza kpi, con kpi vuoto o con un valore che non è un numero, non
#     JSON, una pagina non UTF-8, argomenti sbagliati;
#   - verifica.sh: il punto di partenza (1), la soluzione (0, 7 valori su 7
#     nel testo), un numero sbagliato, una CDN, uno script che chiama la
#     rete, nessun blocco, una pagina non UTF-8 (1); la regola della copia
#     originale (un controllo dello spazio di lavoro che dice sempre 0 non
#     basta); le esecuzioni del registro soltanto come dato, senza un esito
#     sul ciclo della guida e mai come uscita, con la frase della guida
#     com'è oggi nella pagina, non quella di prima; i numeri nel testo come
#     dato; nessun testo dei ticket stampato; la verifica non scrive nel
#     registro; le precondizioni (2);
#   - soluzione/: genera_dashboard.py, eseguito in uno spazio di lavoro
#     nuovo, riproduce byte per byte soluzione/dashboard.html; il registro
#     di riferimento ha la forma di un'esecuzione passata;
#   - .claude/settings.json (con la regola deny di Edit sul controllo); il
#     README (il prompt fra i segni, che chiede un comando per volta e
#     l'uscita nell'ultima riga; la versione breve in 19 righe × 66
#     colonne; le dieci sezioni; Linux e WSL 2, non macOS; nessun
#     identificativo interno nei file per i partecipanti);
#   - _docente/live.sh con un claude finto: le precondizioni escono 2 senza
#     chiamare claude (anche impostazioni senza regole Bash); finito al
#     primo turno, al secondo dopo una pagina sbagliata o dopo nessuna
#     pagina (con --resume e il seguito giusto), mai finito (quattro
#     chiamate, uscita 1), una chiamata fallita; le opzioni passate a
#     claude (Read, Write, Edit e le regole Bash delle impostazioni,
#     --strict-mcp-config), il prompt uguale a quello del README,
#     ANTHROPIC_API_KEY tolta;
#   - prepara_esercizio.sh e tools/verifica.sh con l'elemento vero;
#   - shellcheck -x sugli script dell'elemento e su questo.
# Gli spazi di lavoro nascono in una cartella temporanea, nella base di
# handson::init_temp_base (mai dentro ~/.claude, anche se TMPDIR punta
# lì): l'albero del repository non cambia. Un numero di casi diverso da
# CASES esce 2.
#
# Uso:    m3_funzionalita_claude/_docente/test_m3_e03.sh
# Uscita: 0 = tutte le prove passano · 1 = almeno una fallita ·
#         2 = precondizione (manca python3, jq o shellcheck, un file
#             dell'elemento o di M3-E01; una preparazione non riesce; le
#             prove eseguite non sono quante attese)
set -uo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly MOD="${SELF%/_docente/*}"
readonly RADICE="${MOD%/*}"
readonly SEZIONE="${MOD}/s2_funzionalita_claude"
readonly E03="${SEZIONE}/m3_e4_dashboard_locale/M3-E03_dashboard_locale"
readonly E01="${SEZIONE}/m3_e2_anonimizzare/M3-E01_anonimizzare_ticket"
# La libreria del repository, per la base dei file temporanei
# (handson::init_temp_base): mai dentro ~/.claude, dove prepara_esercizio.sh
# rifiuta gli spazi di lavoro, anche se TMPDIR punta lì.
# shellcheck source=../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"
readonly CASES=122
readonly FINE="Fatto: la pagina c'è, i suoi KPI sono quelli veri e non \
carica niente da fuori."
# La frase della guida di Claude Code che la verifica stampa, com'è oggi
# nella pagina, e un pezzo di quella di prima, che non c'è più.
readonly FRASE_GUIDA="It makes the change, runs the check, and if \
something broke it reads the output and fixes it before running the \
check again."
readonly FRASE_DI_PRIMA="iterates until the check passes"
readonly UN_COMANDO="Esegui ogni comando da solo, senza concatenarlo ad \
altri, e leggi l'uscita del controllo nella sua ultima riga."
# L'ora UTC in testa a una riga di controlli_dashboard.log.
readonly RIGA_LOG='^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z'
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

# L'ultima riga di OUT comincia con il testo atteso.
# Arguments: $1 il nome, $2 l'inizio atteso dell'ultima riga.
expect_ultima() {
  local ultima="${OUT##*$'\n'}"
  if [[ "${ultima}" == "$2"* ]]; then
    pass "$1"
  else
    fail "$1: l'ultima riga è «${ultima}», attesa «$2…»"
  fi
}

# La preparazione di una prova che non riesce: uscita 2.
rotta() { echo "test_m3_e03: preparazione non riuscita: $*" >&2; exit 2; }

# Un nuovo spazio di lavoro dal punto di partenza, più facoltativamente la
# soluzione. Arguments: $1 la variabile da assegnare, $2 «soluzione» o
# niente.
ws() {
  local __ws_d
  __ws_d="$(mktemp -d "${TMP}/ws.XXXXXX")" || rotta "mktemp"
  cp -R "${E03}/esercizio/." "${__ws_d}/" || rotta "cp esercizio"
  if [[ "${2:-}" == "soluzione" ]]; then
    cp -R "${E03}/soluzione/." "${__ws_d}/" || rotta "cp soluzione"
  fi
  printf -v "$1" '%s' "${__ws_d}"
}

# Una modifica della pagina con fx.py; la preparazione rotta esce 2.
fx() { python3 -B -I "${FX}" "$@" || rotta "fx $*"; }

# Il controllo di uno spazio di lavoro, eseguito nella sua cartella.
# Arguments: $1 lo spazio, poi gli argomenti di controlla_dashboard.py.
controllo() {
  local w="$1"
  shift
  run bash -c 'cd "$1" && shift && python3 -B controlla_dashboard.py "$@"' _ \
    "${w}" "$@"
}

# La verifica dell'elemento su uno spazio di lavoro.
verifica() { run "${E03}/verifica.sh" "$1"; }

# Le righe di un registro (0 se non c'è). Arguments: $1 il file.
righe_log() {
  local n=0
  if [[ -f "$1" ]]; then
    n="$(wc -l < "$1")"
  fi
  echo $((n))
}

# La riga di un KPI nel controllo e nella verifica.
riga() { printf '  %-40s %s' "$1" "$2"; }

# fx.py, il claude finto e il claude esca.
prepara() {
  FX="${TMP}/fx.py"
  mkdir -p "${TMP}/finto" "${TMP}/esca" || rotta "mkdir"
  cat > "${FX}" <<'PY' || rotta "fx.py"
"""fx.py -- le modifiche della pagina e del profilo nelle prove di M3-E03."""
import json
import os
import re
import sys

BLOCCO = re.compile(r'<script type="application/json" id="kpi">.*?</script>\n',
                    re.S)
TICKET = ("<p>Messaggio in chat: «Mi è arrivato un sollecito ma la fattura "
          "risulta pagata dalla banca.»</p>\n")
# Uno script nella pagina che chiama la rete, per ogni modo; e due che non
# la chiamano (uno script qualunque, un blocco di dati con un indirizzo).
SCRIPT = {
    "fetch": '<script>fetch("dati.json").then(function (r) { return 0; });'
             "</script>",
    "import": '<script type="module">import("./grafici.js");</script>',
    "xhr": "<script>var x = new XMLHttpRequest();</script>",
    "websocket": '<script>var w = new WebSocket("wss://example.org/f");'
                 "</script>",
    "eventsource": '<script>var e = new EventSource("/eventi");</script>',
    "beacon": '<script>navigator.sendBeacon("/visite", "1");</script>',
    "indirizzo": '<script>var fonte = "https://example.org/dati.json";'
                 "</script>",
    "innocuo": '<script>document.title = "Dashboard della settimana";'
               '</script>\n<script type="application/json" id="fonti">'
               '{"fonte": "https://example.org/aiuto"}</script>',
}
# Il percorso A: un profilo con i propri indicatori, e il blocco kpi della
# pagina per ogni variante.
PROPRI = {"aperte": 75, "media": 3.5, "per_canale": {"chat": 10, "email": 5},
          "righe": 343}
VARIANTI_A = {"uguale": {}, "diverso": {"aperte": 74},
              "decimale": {"media": 3.54}, "manca": {"per_canale": None}}


def pagina(ws, cosa):
    p = os.path.join(ws, "dashboard.html")
    with open(p, encoding="utf-8") as fh:
        t = fh.read()
    if cosa == "numero":
        t = t.replace('"voti": 106', '"voti": 105', 1)
    elif cosa == "cdn":
        t = t.replace("</head>", '<script src="https://cdn.example.org/'
                      'grafici.js"></script>\n</head>', 1)
    elif cosa == "font":
        t = t.replace("<style>", "<style>@import url(https://fonts.example."
                      "org/carattere.css);\n", 1)
    elif cosa == "file":
        t = t.replace("</head>", '<link rel="stylesheet" href="stile.css">'
                      "\n</head>", 1)
    elif cosa == "innocui":
        t = t.replace("</body>", '<img src="data:image/png;base64,iVBORw0KGgo='
                      '" alt="">\n<a href="https://example.org/aiuto">aiuto'
                      '</a>\n<svg><use href="#barra"/></svg>\n</body>', 1)
    elif cosa == "senza_blocco":
        t = BLOCCO.sub("", t, count=1)
    elif cosa == "due_blocchi":
        t = t.replace("</body>", BLOCCO.search(t).group(0) + "</body>", 1)
    elif cosa == "blocco_rotto":
        t = t.replace('"voti": 106', '"voti": 106,,', 1)
    elif cosa == "testo":
        t = t.replace("</body>", TICKET + "</body>", 1)
    elif cosa == "senza_numero":
        t = t.replace('<div class="numero">3,52</div>',
                      '<div class="numero">tre e mezzo</div>', 1)
    elif cosa in SCRIPT:
        t = t.replace("</body>", SCRIPT[cosa] + "\n</body>", 1)
    elif cosa == "latin1":
        t = t.replace("</body>", "<p>Perché è così</p>\n</body>", 1)
        with open(p, "wb") as fh:
            fh.write(t.encode("latin-1"))
        return 0
    else:
        return 2
    with open(p, "w", encoding="utf-8") as fh:
        fh.write(t)
    return 0


def profilo(ws, cosa):
    p = os.path.join(ws, "anonimo", "profilo.json")
    if cosa == "senza_kpi":
        documento = {"altro": 1}
    elif cosa == "kpi_vuoto":
        documento = {"kpi": {}}
    elif cosa == "kpi_testo":
        documento = {"kpi": {"righe": "tante"}}
    elif cosa == "rotto":
        with open(p, "w", encoding="utf-8") as fh:
            fh.write("{")
        return 0
    else:
        return 2
    with open(p, "w", encoding="utf-8") as fh:
        json.dump(documento, fh)
    return 0


def percorso_a(ws, variante):
    """Il profilo con i propri indicatori, e la pagina con il blocco kpi
    della variante: uguale, un valore diverso, un decimale entro mezza
    unità, una chiave che manca."""
    with open(os.path.join(ws, "anonimo", "profilo.json"), "w",
              encoding="utf-8") as fh:
        json.dump({"kpi": PROPRI}, fh)
    valori = dict(PROPRI)
    for chiave, valore in VARIANTI_A[variante].items():
        if valore is None:
            del valori[chiave]
        else:
            valori[chiave] = valore
    p = os.path.join(ws, "dashboard.html")
    with open(p, encoding="utf-8") as fh:
        t = fh.read()
    blocco = ('<script type="application/json" id="kpi">%s</script>\n'
              % json.dumps(valori))
    with open(p, "w", encoding="utf-8") as fh:
        fh.write(BLOCCO.sub(lambda _m: blocco, t, count=1))
    return 0


def main(a):
    if a[0] == "pagina":
        return pagina(a[1], a[2])
    if a[0] == "profilo":
        return profilo(a[1], a[2])
    if a[0] == "percorso_a":
        return percorso_a(a[1], a[2])
    return 2


sys.exit(main(sys.argv[1:]))
PY
  cat > "${TMP}/finto/claude" <<'PY' || rotta "il claude finto"
#!/usr/bin/env python3
"""Un claude finto per live.sh di M3-E03: risponde come claude -p
--output-format json e intanto lavora nello spazio di lavoro (la cartella
corrente), secondo FINTO_MODO: completo (lo script della soluzione,
eseguito, poi il controllo), a_rate (al primo turno una pagina con un
numero sbagliato, con --resume la soluzione), senza_pagina (al primo turno
niente, con --resume la soluzione), mai (sempre la pagina sbagliata). Con
FINTO_ESITO=ko esce 1. Registra ogni chiamata in FINTO_LOG («CHIAVE» se
ANTHROPIC_API_KEY gli arriva), gli argomenti in FINTO_ARGV (una riga JSON
per chiamata) e il prompt di ogni chiamata in FINTO_PROMPT.<n>."""
import json
import os
import shutil
import subprocess
import sys

OPZIONI = {"-p": 0, "--allowedTools": 1, "--model": 1, "--effort": 1,
           "--permission-mode": 1, "--permission-prompts": 1,
           "--output-format": 1, "--setting-sources": 1, "--resume": 1,
           "--strict-mcp-config": 0}


def esegui(script):
    subprocess.run([sys.executable, "-B", script], check=False,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def pagina(giusta):
    shutil.copy(os.path.join(os.environ["FINTO_SOLUZIONE"],
                             "genera_dashboard.py"), "genera_dashboard.py")
    esegui("genera_dashboard.py")
    if not giusta:
        with open("dashboard.html", encoding="utf-8") as fh:
            t = fh.read().replace('"voti": 106', '"voti": 105', 1)
        with open("dashboard.html", "w", encoding="utf-8") as fh:
            fh.write(t)
    esegui("controlla_dashboard.py")


def main(argv):
    if argv[:1] == ["--version"]:
        print("0.0.0 (Claude Code, finto)")
        return 0
    with open(os.environ["FINTO_LOG"], "a", encoding="utf-8") as fh:
        fh.write("chiamata %s\n" % (
            "CHIAVE" if os.environ.get("ANTHROPIC_API_KEY") else "-"))
    with open(os.environ["FINTO_LOG"], encoding="utf-8") as fh:
        numero = sum(1 for _ in fh)
    with open(os.environ["FINTO_ARGV"], "a", encoding="utf-8") as fh:
        fh.write(json.dumps(argv) + "\n")
    opzioni, i = {}, 0
    while i < len(argv) and argv[i] != "--":
        if argv[i] not in OPZIONI:
            sys.stderr.write("error: unknown option '%s'\n" % argv[i])
            return 1
        opzioni[argv[i]] = argv[i + 1] if OPZIONI[argv[i]] else ""
        i += 1 + OPZIONI[argv[i]]
    prompt = argv[i + 1] if i + 1 < len(argv) else ""
    with open("%s.%d" % (os.environ["FINTO_PROMPT"], numero), "w",
              encoding="utf-8") as fh:
        fh.write(prompt)
    if os.environ.get("FINTO_ESITO", "ok") != "ok":
        return 1
    modo, ripresa = os.environ.get("FINTO_MODO", "completo"), \
        "--resume" in opzioni
    if modo == "completo" or (modo in ("a_rate", "senza_pagina") and ripresa):
        pagina(True)
    elif modo in ("a_rate", "mai"):
        pagina(False)
    print(json.dumps({
        "type": "result", "subtype": "success", "is_error": False,
        "session_id": "sessione-finta", "result": "Fatto (finto).",
        "num_turns": 4, "duration_ms": 2500,
        "usage": {"input_tokens": 10, "cache_creation_input_tokens": 2000,
                  "cache_read_input_tokens": 500, "output_tokens": 300},
        "modelUsage": {"claude-sonnet-finto": {}}}))
    return 0


sys.exit(main(sys.argv[1:]))
PY
  # shellcheck disable=SC2016  # il corpo è dell'esca
  printf '%s\n' '#!/bin/bash' 'echo "chiamata $*" >> "${ESCA_LOG}"' \
    'exit 1' > "${TMP}/esca/claude" || rotta "il claude esca"
  chmod 755 "${TMP}/finto/claude" "${TMP}/esca/claude" || rotta "chmod"
}

# Le copie di M3-E01 e aggiorna.py.
t_copie() {
  local voce copia
  for voce in "kpi_veri.py:kpi_veri.py" \
      "esercizio/kpi_definizioni.md:esercizio/kpi_definizioni.md" \
      "esercizio/anonimo/ticket-anonimi.csv:\
soluzione/anonimo/ticket-anonimi.csv" \
      "esercizio/anonimo/profilo.json:soluzione/anonimo/profilo.json"; do
    if cmp -s "${E03}/${voce%%:*}" "${E01}/${voce#*:}"; then
      pass "${voce%%:*} uguale a quello di M3-E01"
    else
      fail "${voce%%:*} diverso da quello di M3-E01"
    fi
  done
  run python3 -B -I "${E03}/_docente/aggiorna.py" --controlla
  expect "aggiorna --controlla: copie e riferimenti attesi" 0 \
    "le copie e i riferimenti sono quelli attesi"
  copia="$(mktemp -d "${TMP}/elemento.XXXXXX")" || rotta "mktemp"
  cp -R "${E03}/." "${copia}/" || rotta "cp elemento"
  printf ' ' >> "${copia}/esercizio/anonimo/profilo.json" || rotta "modifica"
  run env PN_M3_E01="${E01}" python3 -B -I "${copia}/_docente/aggiorna.py" \
    --controlla
  expect "aggiorna --controlla: una copia cambiata esce 1" 1 "DIVERSO"
  run env PN_M3_E01="${E01}" python3 -B -I "${copia}/_docente/aggiorna.py"
  if (( RC == 0 )) && cmp -s "${copia}/esercizio/anonimo/profilo.json" \
      "${E01}/soluzione/anonimo/profilo.json"; then
    pass "aggiorna: riscrive la copia cambiata"
  else
    fail "aggiorna: la copia non è stata riscritta (rc=${RC}): ${OUT:0:300}"
  fi
  run env PN_M3_E01="${TMP}/non-esiste" python3 -B -I \
    "${copia}/_docente/aggiorna.py" --controlla
  expect "aggiorna: senza M3-E01 esce 2" 2 "M3-E01 non c'è"
}

# Il controllo: la soluzione, le differenze, le risorse esterne, nessun
# falso positivo, nessun testo dei ticket, l'ultima riga, il registro.
t_controllo() {
  local w voce prima dopo
  ws w soluzione
  prima="$(righe_log "${w}/controlli_dashboard.log")"
  controllo "${w}"
  expect "controllo: la soluzione esce 0" 0 \
    "nessuna: la pagina non carica niente dalla rete né da altri file"
  expect_ultima "controllo: l'ultima riga dice l'uscita 0" \
    "uscita: 0 — i KPI sono quelli del profilo"
  dopo="$(righe_log "${w}/controlli_dashboard.log")"
  if (( dopo == prima + 1 )) && tail -n 1 "${w}/controlli_dashboard.log" \
      | grep -qE "${RIGA_LOG}"$'\t0\t0$'; then
    pass "controllo: una riga in più nel registro, ora-uscita-differenze"
  else
    fail "controllo: il registro non ha la riga attesa (${prima} → ${dopo})"
  fi
  ws w soluzione
  fx pagina "${w}" numero
  controllo "${w}"
  expect "controllo: un numero sbagliato esce 1" 1 "$(riga voti NO)"
  expect_ultima "controllo: l'ultima riga dice l'uscita 1" \
    "uscita: 1 — 1 differenza da correggere"
  for voce in \
      "cdn:NO  dalla rete, <script src>: https://cdn.example.org/grafici.js" \
      "font:NO  dalla rete, <style> url(): \
https://fonts.example.org/carattere.css" \
      "file:NO  da un altro file, <link href>: stile.css" \
      "senza_blocco:NO  nessun blocco \
<script type=\"application/json\" id=\"kpi\">" \
      "due_blocchi:NO  2 blocchi \
<script type=\"application/json\" id=\"kpi\">" \
      "blocco_rotto:NO  il blocco kpi non è un JSON valido" \
      "fetch:NO  dalla rete, <script> nella pagina: fetch(" \
      "import:NO  dalla rete, <script> nella pagina: import(" \
      "xhr:NO  dalla rete, <script> nella pagina: XMLHttpRequest" \
      "websocket:NO  dalla rete, <script> nella pagina: WebSocket" \
      "eventsource:NO  dalla rete, <script> nella pagina: EventSource" \
      "beacon:NO  dalla rete, <script> nella pagina: sendBeacon" \
      "indirizzo:NO  dalla rete, <script> nella pagina: \
https://example.org/dati.json"; do
    ws w soluzione
    fx pagina "${w}" "${voce%%:*}"
    controllo "${w}"
    expect "controllo: ${voce%%:*} esce 1" 1 "${voce#*:}"
  done
  ws w soluzione
  fx pagina "${w}" innocui
  controllo "${w}"
  expect "controllo: data:, un link a e un #riferimento non sono esterni" 0 \
    "uscita: 0"
  expect_absent "controllo: nessuna risorsa dalla rete segnalata" "dalla rete,"
  ws w soluzione
  fx pagina "${w}" innocuo
  controllo "${w}"
  expect "controllo: uno script senza rete e un blocco di dati, esce 0" 0 \
    "uscita: 0"
  expect_absent "controllo: lo script senza rete non è segnalato" \
    "<script> nella pagina"
  t_controllo_percorso_a
  ws w soluzione
  fx pagina "${w}" testo
  controllo "${w}"
  expect "controllo: un testo di ticket nella pagina, esce 0" 0 "uscita: 0"
  expect_absent "controllo: nessun testo dei ticket stampato" "sollecito"
}

# Il controllo prende le chiavi dal profilo: il percorso A, con i propri
# indicatori, passa con la pagina giusta e non con una sbagliata.
t_controllo_percorso_a() {
  local w
  ws w soluzione
  fx percorso_a "${w}" uguale
  controllo "${w}"
  expect "controllo: il percorso A, i propri indicatori, esce 0" 0 \
    "uscita: 0 — i KPI sono quelli del profilo"
  expect "controllo: il percorso A, un indicatore proprio confrontato" 0 \
    "$(riga per_canale ok)"
  expect_absent "controllo: il percorso A, nessuna chiave del corso" \
    "segnalazioni"
  ws w soluzione
  fx percorso_a "${w}" diverso
  controllo "${w}"
  expect "controllo: il percorso A, un valore diverso esce 1" 1 \
    "$(riga aperte NO)"
  ws w soluzione
  fx percorso_a "${w}" manca
  controllo "${w}"
  expect "controllo: il percorso A, una chiave che manca esce 1" 1 "(manca)"
  ws w soluzione
  fx percorso_a "${w}" decimale
  controllo "${w}"
  expect "controllo: un decimale entro mezza unità del riferimento, 0" 0 \
    "$(riga media ok)"
}

# Il controllo: le precondizioni, l'aiuto, gli argomenti, il registro
# nella cartella della pagina.
t_controllo_precondizioni() {
  local w prima
  ws w
  controllo "${w}"
  expect "controllo: senza pagina esce 2" 2 "manca"
  expect_ultima "controllo: senza pagina, l'ultima riga dice l'uscita 2" \
    "uscita: 2 — il controllo non può girare: manca"
  if grep -qE $'\t2\t-$' "${w}/controlli_dashboard.log" 2>/dev/null; then
    pass "controllo: una precondizione si registra con uscita 2 e «-»"
  else
    fail "controllo: la precondizione non è nel registro"
  fi
  ws w soluzione
  rm "${w}/anonimo/profilo.json" || rotta "rm"
  controllo "${w}"
  expect "controllo: senza profilo esce 2" 2 "il riferimento del controllo"
  ws w soluzione
  fx profilo "${w}" senza_kpi
  controllo "${w}"
  expect "controllo: un profilo senza kpi esce 2" 2 "non ha la chiave kpi"
  ws w soluzione
  fx profilo "${w}" kpi_vuoto
  controllo "${w}"
  expect "controllo: un profilo con kpi vuoto esce 2" 2 "non ha la chiave kpi"
  ws w soluzione
  fx profilo "${w}" kpi_testo
  controllo "${w}"
  expect "controllo: un kpi che non è un numero esce 2" 2 \
    "non ha la chiave kpi"
  ws w soluzione
  fx profilo "${w}" rotto
  controllo "${w}"
  expect "controllo: un profilo non JSON esce 2" 2 "non è un JSON valido"
  ws w soluzione
  fx pagina "${w}" latin1
  controllo "${w}"
  expect "controllo: una pagina non UTF-8 esce 2" 2 "non è un testo UTF-8"
  ws w soluzione
  prima="$(righe_log "${w}/controlli_dashboard.log")"
  controllo "${w}" -h
  expect "controllo: -h esce 0 con l'uso" 0 "Uso:"
  if (( "$(righe_log "${w}/controlli_dashboard.log")" == prima )); then
    pass "controllo: -h non scrive nel registro"
  else
    fail "controllo: -h ha scritto nel registro"
  fi
  controllo "${w}" --boh
  expect "controllo: un'opzione sconosciuta esce 2" 2 "opzione sconosciuta"
  expect_ultima "controllo: argomenti sbagliati, l'ultima riga dice 2" \
    "uscita: 2 — argomenti sbagliati"
  controllo "${w}" a.html b.html
  expect "controllo: due pagine escono 2" 2 "una pagina sola"
  mkdir -p "${w}/copia" || rotta "mkdir"
  cp "${w}/dashboard.html" "${w}/copia/" || rotta "cp"
  controllo "${w}" copia/dashboard.html
  if (( RC == 0 )) && [[ -f "${w}/copia/controlli_dashboard.log" ]]; then
    pass "controllo: con una pagina data, il registro sta accanto alla pagina"
  else
    fail "controllo: il registro non è accanto alla pagina (rc=${RC})"
  fi
}

# La verifica: partenza, soluzione, differenze, la copia originale, il
# ciclo stampato e mai come uscita, i numeri nel testo come dato.
t_verifica() {
  local w prima
  ws w
  verifica "${w}"
  expect "verifica: il punto di partenza esce 1" 1 \
    "Non ancora: manca dashboard.html"
  expect "verifica: senza esecuzioni, il registro come dato" 1 \
    "nessuna esecuzione registrata"
  expect_absent "verifica: nessun esito sul ciclo della guida" "confermata"
  ws w soluzione
  prima="$(righe_log "${w}/controlli_dashboard.log")"
  verifica "${w}"
  expect "verifica: la soluzione esce 0" 0 "${FINE}"
  expect "verifica: le esecuzioni del registro, come dato" 0 \
    "esecuzioni registrate: 1; uscite, in ordine: 0"
  expect "verifica: il registro lo scrive il controllo, non lo prova" 0 \
    "Che Claude l'abbia eseguito lo dicono le sue chiamate"
  expect "verifica: la frase della guida, com'è oggi" 0 "${FRASE_GUIDA}"
  expect_absent "verifica: non più la frase di prima" "${FRASE_DI_PRIMA}"
  expect_absent "verifica: mai «In questa esecuzione»" "In questa esecuzione"
  expect_absent "verifica: nessun esito sul ciclo, sulla soluzione" \
    "confermata"
  expect "verifica: i numeri nel testo della pagina, come dato" 0 \
    "7 valori su 7 nel testo della pagina."
  expect_absent "verifica: la soluzione senza «Non ancora»" "Non ancora"
  if (( "$(righe_log "${w}/controlli_dashboard.log")" == prima )); then
    pass "verifica: non scrive nel registro"
  else
    fail "verifica: ha scritto nel registro"
  fi
  fx pagina "${w}" numero
  verifica "${w}"
  expect "verifica: un numero sbagliato esce 1" 1 \
    "Non ancora: i KPI del blocco kpi non tornano: voti"
  printf 'import sys\nprint("uscita: 0")\n' > "${w}/controlla_dashboard.py" \
    || rotta "controllo finto"
  printf '2026-10-21T09:00:00Z\t0\t0\n' >> "${w}/controlli_dashboard.log"
  verifica "${w}"
  expect "verifica: un controllo che dice sempre 0 non basta" 1 \
    "i KPI del blocco kpi non tornano: voti"
  expect "verifica: il controllo cambiato è un dato" 1 \
    "controlla_dashboard.py dello spazio di lavoro: DIVERSO dall'originale"
  ws w soluzione
  fx pagina "${w}" cdn
  verifica "${w}"
  expect "verifica: uno script da una CDN esce 1" 1 \
    "la pagina carica 1 risorsa dalla rete"
  ws w soluzione
  fx pagina "${w}" fetch
  verifica "${w}"
  expect "verifica: uno script nella pagina che chiama la rete esce 1" 1 \
    "la pagina carica 1 risorsa dalla rete"
  ws w soluzione
  fx pagina "${w}" senza_blocco
  verifica "${w}"
  expect "verifica: nessun blocco kpi esce 1" 1 "Non ancora: nessun blocco"
  ws w soluzione
  fx pagina "${w}" latin1
  verifica "${w}"
  expect "verifica: una pagina non UTF-8 esce 1" 1 "non è un testo UTF-8"
}

# La verifica: gli esiti e i dati che non decidono l'uscita.
t_verifica_dati() {
  local w
  ws w soluzione
  printf '2026-10-21T09:00:00Z\t1\t3\n' >> "${w}/controlli_dashboard.log"
  verifica "${w}"
  expect "verifica: l'ultima esecuzione uscita 1, l'uscita resta 0" 0 \
    "esecuzioni registrate: 2; uscite, in ordine: 0 1"
  rm "${w}/controlli_dashboard.log" || rotta "rm"
  verifica "${w}"
  expect "verifica: senza registro, un dato, e l'uscita resta 0" 0 \
    "nessuna esecuzione registrata"
  ws w soluzione
  fx pagina "${w}" senza_numero
  verifica "${w}"
  expect "verifica: un numero che manca nel testo è un dato" 0 \
    "6 valori su 7 nel testo della pagina."
  ws w soluzione
  fx pagina "${w}" testo
  verifica "${w}"
  expect "verifica: un testo di ticket nella pagina, esce 0" 0 "${FINE}"
  expect_absent "verifica: nessun testo dei ticket stampato" "sollecito"
  ws w soluzione
  rm "${w}/genera_dashboard.py" || rotta "rm"
  verifica "${w}"
  expect "verifica: senza genera_dashboard.py, un dato" 0 \
    "genera_dashboard.py: manca"
}

# La verifica: le precondizioni, anche su una copia dell'elemento.
t_verifica_precondizioni() {
  local w copia
  run "${E03}/verifica.sh" "${TMP}/non-esiste"
  expect "verifica: spazio di lavoro assente esce 2" 2 \
    "spazio di lavoro assente"
  ws w soluzione
  rm "${w}/anonimo/ticket-anonimi.csv" || rotta "rm"
  verifica "${w}"
  expect "verifica: senza il file anonimo esce 2" 2 \
    "manca anonimo/ticket-anonimi.csv nello spazio di lavoro"
  copia="$(mktemp -d "${TMP}/elemento.XXXXXX")" || rotta "mktemp"
  cp -R "${E03}/." "${copia}/" || rotta "cp elemento"
  rm "${copia}/esercizio/controlla_dashboard.py" || rotta "rm"
  ws w soluzione
  run "${copia}/verifica.sh" "${w}"
  expect "verifica: il controllo originale che manca esce 2" 2 \
    "controlla_dashboard.py"
  printf 'import sys\nsys.exit(5)\n' > "${copia}/verifica.py" || rotta "py"
  run "${copia}/verifica.sh" "${w}"
  expect "verifica: un'uscita fuori contratto diventa 2" 2 \
    "il controllo è uscito con 5"
}

# La soluzione: lo script riproduce la pagina; il registro di riferimento.
t_soluzione() {
  local w
  ws w
  cp "${E03}/soluzione/genera_dashboard.py" "${w}/" || rotta "cp"
  (cd "${w}" && python3 -B genera_dashboard.py) > /dev/null 2>&1 \
    || rotta "genera_dashboard.py non gira"
  if cmp -s "${w}/dashboard.html" "${E03}/soluzione/dashboard.html"; then
    pass "soluzione: genera_dashboard.py riproduce dashboard.html"
  else
    fail "soluzione: dashboard.html non è quella che lo script produce"
  fi
  if (( "$(righe_log "${E03}/soluzione/controlli_dashboard.log")" == 1 )) \
      && grep -qE "${RIGA_LOG}"$'\t0\t0$' \
        "${E03}/soluzione/controlli_dashboard.log"; then
    pass "soluzione: il registro, un'esecuzione passata"
  else
    fail "soluzione: il registro non ha la forma di un'esecuzione passata"
  fi
}

# Le impostazioni di progetto dello spazio di lavoro.
t_settings() {
  run python3 -B -I - "${E03}/esercizio/.claude/settings.json" \
    "${RADICE}/.claude/settings.json" <<'PY'
import json
import sys

e = json.load(open(sys.argv[1], encoding="utf-8"))["permissions"]
r = json.load(open(sys.argv[2], encoding="utf-8"))["permissions"]
deny = r["deny"] + ["Read(./anonimo/ticket-anonimi.csv)",
                    "Edit(./controlla_dashboard.py)"]
allow = ["Bash(python3 genera_dashboard.py)",
         "Bash(python3 controlla_dashboard.py)",
         "Bash(python3 controlla_dashboard.py *)"]
print("deny %s" % ("ok" if e.get("deny") == deny else "diverso"))
print("allow %s" % ("ok" if e.get("allow") == allow else "diverso"))
print("modo %s" % ("ok" if e.get("defaultMode") == "default" else "diverso"))
PY
  expect "settings: le regole del repository, il Read del CSV, l'Edit" 0 \
    "deny ok"
  expect "settings: i due comandi python3 consentiti, non altro" 0 "allow ok"
  expect "settings: defaultMode default (Manual)" 0 "modo ok"
}

# Il README: il prompt (in ${TMP}/prompt-readme.txt), la versione breve, le
# dieci sezioni; nessun identificativo interno nei file per i partecipanti.
t_readme() {
  local f trovati=''
  run python3 -B -I - "${E03}/README.md" "${TMP}/prompt-readme.txt" \
    "${UN_COMANDO}" <<'PY'
import sys
import textwrap

righe = open(sys.argv[1], encoding="utf-8").read().split("\n")
a = [i for i, r in enumerate(righe) if r.strip() == "<!-- prompt -->"]
b = [i for i, r in enumerate(righe) if r.strip() == "<!-- /prompt -->"]
if len(a) == 1 and len(b) == 1 and a[0] < b[0]:
    prompt = textwrap.dedent("\n".join(righe[a[0] + 1:b[0]])).strip("\n")
    open(sys.argv[2], "w", encoding="utf-8").write(prompt)
    print("prompt ok")
    if sys.argv[3] in " ".join(prompt.split()):
        print("un comando per volta ok")
    # Lo script si esegue con il comando che le impostazioni consentono: in
    # claude -p un'altra forma (python3 -I, una redirezione) è negata, dove
    # un partecipante risponde.
    if "Eseguilo con python3 genera_dashboard.py" in " ".join(prompt.split()):
        print("il comando consentito ok")
i = next(k for k, r in enumerate(righe) if "La versione breve" in r)
breve = []
for r in righe[i + 1:]:
    if r.startswith("       "):
        breve.append(r[7:])
    elif breve:
        break
if 0 < len(breve) <= 19 and max(len(r) for r in breve) <= 66:
    print("breve ok: %d righe" % len(breve))
if "Eseguilo con python3 genera_dashboard.py" in " ".join(" ".join(
        breve).split()):
    print("breve: il comando consentito ok")
sezioni = ("Obiettivo", "Tempo", "Prerequisiti", "Punto di partenza",
           "Passi in Claude Code", "Che cosa osservare", "Verifica",
           "Se qualcosa va storto", "Impronta d'uso sul piano Pro",
           "Per approfondire")
if all(any(r.startswith("## " + s) for r in righe) for s in sezioni):
    print("sezioni ok")
PY
  expect "README: il prompt fra i due segni" 0 "prompt ok"
  expect "README: il prompt chiede un comando per volta e l'ultima riga" 0 \
    "un comando per volta ok"
  expect "README: il prompt nomina il comando consentito" 0 \
    "il comando consentito ok"
  expect "README: la versione breve in 19 righe × 66 colonne" 0 "breve ok"
  expect "README: la versione breve nomina il comando consentito" 0 \
    "breve: il comando consentito ok"
  expect "README: le dieci sezioni" 0 "sezioni ok"
  OUT="$(cat "${E03}/README.md")"
  expect_absent "README: gli ambienti del corso, non macOS" "macOS"
  for f in README.md verifica.sh verifica.py kpi_veri.py \
      esercizio/controlla_dashboard.py esercizio/kpi_definizioni.md \
      esercizio/.claude/settings.json esercizio/anonimo/profilo.json; do
    if grep -qE -- "${INTERNI}" "${E03}/${f}"; then
      trovati+=" ${f}"
    fi
  done
  if [[ -z "${trovati}" ]]; then
    pass "nessun identificativo interno nei file per i partecipanti"
  else
    fail "identificativi interni in:${trovati}"
  fi
}

# live.sh con il claude finto in testa al PATH.
# Arguments: $1 lo spazio di lavoro, poi variabili d'ambiente (VAR=valore).
live_finto() {
  local w="$1"
  shift
  : > "${TMP}/finto.log"
  : > "${TMP}/finto.argv"
  rm -f "${TMP}/prompt."*
  run env "$@" PATH="${TMP}/finto:${PATH}" HANDSON_NO_PAUSE=1 \
    FINTO_LOG="${TMP}/finto.log" FINTO_ARGV="${TMP}/finto.argv" \
    FINTO_PROMPT="${TMP}/prompt" FINTO_SOLUZIONE="${E03}/soluzione" \
    "${E03}/_docente/live.sh" "${w}"
}

# Una chiamata attesa: il numero di chiamate del claude finto.
# Arguments: $1 il nome, $2 le chiamate attese.
expect_chiamate() {
  local n
  n="$(righe_log "${TMP}/finto.log")"
  if (( n == $2 )); then pass "$1"; else fail "$1: ${n} chiamate, attese $2"; fi
}

# Le precondizioni di live.sh: escono 2 senza chiamare claude.
# Arguments: $1 il nome, $2 la parola attesa, $3 lo spazio di lavoro.
senza_chiamate() {
  : > "${TMP}/esca.log"
  run env PATH="${TMP}/esca:${PATH}" ESCA_LOG="${TMP}/esca.log" \
    HANDSON_NO_PAUSE=1 "${E03}/_docente/live.sh" "$3"
  if (( RC == 2 )) && grep -qF -- "$2" <<< "${OUT}" \
      && [[ ! -s "${TMP}/esca.log" ]]; then
    pass "$1"
  else
    fail "$1 (rc=${RC}, chiamate: $(righe_log "${TMP}/esca.log")):" \
      "${OUT:0:400}"
  fi
}

t_live() {
  local w
  senza_chiamate "live.sh: spazio di lavoro assente esce 2" \
    "spazio di lavoro assente" "${TMP}/non-esiste"
  ws w
  rm "${w}/controlla_dashboard.py" || rotta "rm"
  senza_chiamate "live.sh: senza controlla_dashboard.py esce 2" \
    "controlla_dashboard.py" "${w}"
  ws w
  rm "${w}/anonimo/profilo.json" || rotta "rm"
  senza_chiamate "live.sh: senza il profilo esce 2" "profilo.json" "${w}"
  ws w
  printf '{"permissions": {"allow": ["Read(./kpi_definizioni.md)"]}}\n' \
    > "${w}/.claude/settings.json" || rotta "le impostazioni senza Bash"
  senza_chiamate "live.sh: impostazioni senza regole Bash escono 2" \
    "nessuna regola Bash" "${w}"
  ws w
  live_finto "${w}" FINTO_MODO=completo
  expect "live.sh: finito al primo turno esce 0" 0 \
    "VERIFICA OK   verifica.sh dell'elemento"
  expect_chiamate "live.sh: finito al primo turno, una chiamata" 1
  expect "live.sh: il riepilogo del turno" 0 "token in entrata 2510"
  if cmp -s "${TMP}/prompt.1" "${TMP}/prompt-readme.txt"; then
    pass "live.sh: il prompt è quello del README"
  else
    fail "live.sh: il prompt non è quello del README"
  fi
  run python3 -B -I - "${TMP}/finto.argv" <<'PY'
import json
import sys

argv = json.loads(open(sys.argv[1], encoding="utf-8").readline())
coppie = {argv[i]: argv[i + 1] for i in range(len(argv) - 1)}
attese = {"--model": "sonnet", "--effort": "medium",
          "--allowedTools": "Read,Write,Edit,"
                            "Bash(python3 genera_dashboard.py),"
                            "Bash(python3 controlla_dashboard.py),"
                            "Bash(python3 controlla_dashboard.py *)",
          "--permission-mode": "dontAsk", "--permission-prompts": "none",
          "--output-format": "json", "--setting-sources": "project,local"}
sbagliate = [k for k, v in attese.items() if coppie.get(k) != v]
if "--strict-mcp-config" not in argv:
    sbagliate.append("--strict-mcp-config")
print("opzioni ok" if not sbagliate and "-p" in argv else
      "opzioni diverse: %s" % sbagliate)
PY
  expect "live.sh: modello, effort, strumenti delle impostazioni, MCP" 0 \
    "opzioni ok"
  ws w
  live_finto "${w}" FINTO_MODO=a_rate
  expect "live.sh: finito al secondo turno esce 0" 0 "VERIFICA OK"
  expect "live.sh: due esecuzioni del controllo nel registro, come dato" 0 \
    "esecuzioni registrate: 2; uscite, in ordine: 1 0"
  expect_chiamate "live.sh: finito al secondo turno, due chiamate" 2
  if sed -n 2p "${TMP}/finto.argv" | grep -qF '"--resume", "sessione-finta"' \
      && grep -qF "controlla_dashboard.py e correggi" "${TMP}/prompt.2" \
      && grep -qF "${UN_COMANDO}" "${TMP}/prompt.2"; then
    pass "live.sh: il secondo turno riprende la sessione e chiede il controllo"
  else
    fail "live.sh: il secondo turno non riprende la sessione o non chiede il" \
      "controllo un comando per volta"
  fi
  ws w
  live_finto "${w}" FINTO_MODO=senza_pagina
  expect "live.sh: la pagina al secondo turno esce 0" 0 "VERIFICA OK"
  if grep -qF "Scrivi, se manca, ed esegui genera_dashboard.py" \
      "${TMP}/prompt.2" && grep -qF "${UN_COMANDO}" "${TMP}/prompt.2"; then
    pass "live.sh: senza pagina il secondo turno chiede lo script"
  else
    fail "live.sh: senza pagina il secondo turno non chiede lo script"
  fi
  ws w
  live_finto "${w}" FINTO_MODO=mai
  expect "live.sh: mai finito esce 1" 1 "VERIFICA KO"
  expect_chiamate "live.sh: mai finito, quattro chiamate" 4
  ws w
  live_finto "${w}" FINTO_ESITO=ko
  expect "live.sh: una chiamata fallita esce 1" 1 \
    "il turno 1 non ha dato una risposta"
  ws w
  live_finto "${w}" FINTO_MODO=completo ANTHROPIC_API_KEY=chiave-finta
  if grep -q "CHIAVE" "${TMP}/finto.log"; then
    fail "live.sh: ANTHROPIC_API_KEY arriva a claude"
  else
    pass "live.sh: ANTHROPIC_API_KEY tolta, claude usa l'abbonamento"
  fi
}

# Gli strumenti del repository: prepara_esercizio.sh e verifica.sh.
t_integrazione() {
  local radice
  radice="$(mktemp -d "${TMP}/radice.XXXXXX")" || rotta "mktemp"
  run "${RADICE}/tools/prepara_esercizio.sh" M3-E03 --radice "${radice}"
  expect "prepara_esercizio.sh M3-E03" 0 "Spazio di lavoro pronto"
  if [[ -f "${radice}/M3-E03/controlla_dashboard.py" \
      && -f "${radice}/M3-E03/anonimo/ticket-anonimi.csv" \
      && -f "${radice}/M3-E03/anonimo/profilo.json" \
      && ! -e "${radice}/M3-E03/genera_dashboard.py" \
      && ! -e "${radice}/M3-E03/_docente" ]] \
      && grep -qF "Read(./anonimo/ticket-anonimi.csv)" \
        "${radice}/M3-E03/.claude/settings.json"; then
    pass "lo spazio di lavoro: il punto di partenza, con le sue impostazioni"
  else
    fail "lo spazio di lavoro non è il punto di partenza"
  fi
  run "${RADICE}/tools/verifica.sh" M3-E03 --radice "${radice}"
  expect "tools/verifica.sh sul punto di partenza esce 1" 1 "NON ANCORA"
  cp -R "${E03}/soluzione/." "${radice}/M3-E03/" || rotta "cp soluzione"
  run "${RADICE}/tools/verifica.sh" M3-E03 --radice "${radice}"
  expect "tools/verifica.sh con la soluzione esce 0" 0 "VERIFICA OK"
}

t_shellcheck() {
  local f
  for f in "${E03}/verifica.sh" "${E03}/_docente/live.sh" "${SELF}"; do
    if (cd "${RADICE}" && shellcheck -x "${f}") > /dev/null 2>&1; then
      pass "shellcheck ${f#"${RADICE}"/}"
    else
      fail "shellcheck ${f#"${RADICE}"/}"
    fi
  done
}

main() {
  local t
  for t in python3 jq shellcheck; do
    command -v "${t}" > /dev/null 2>&1 \
      || { echo "test_m3_e03: manca ${t}" >&2; exit 2; }
  done
  for t in verifica.sh verifica.py kpi_veri.py \
      esercizio/controlla_dashboard.py \
      esercizio/.claude/settings.json esercizio/anonimo/profilo.json \
      soluzione/genera_dashboard.py soluzione/dashboard.html \
      _docente/live.sh _docente/aggiorna.py; do
    [[ -e "${E03}/${t}" ]] || { echo "test_m3_e03: manca ${t}" >&2; exit 2; }
  done
  [[ -f "${E01}/kpi_veri.py" ]] \
    || { echo "test_m3_e03: manca M3-E01" >&2; exit 2; }
  handson::init_temp_base
  TMP="$(mktemp -d "${HANDSON_TEMP_BASE}/test_m3_e03.XXXXXX")" || exit 2
  trap 'rm -rf "${TMP}"' EXIT
  prepara
  t_copie
  t_controllo
  t_controllo_precondizioni
  t_verifica
  t_verifica_dati
  t_verifica_precondizioni
  t_soluzione
  t_settings
  t_readme
  t_live
  t_integrazione
  t_shellcheck
  echo "PASS=${PASS} FAIL=${FAIL} CASES=$((PASS + FAIL))/${CASES}"
  if (( PASS + FAIL != CASES )); then
    echo "test_m3_e03: eseguite $((PASS + FAIL)) prove, attese ${CASES}:" \
      "un caso manca o non è contato" >&2
    exit 2
  fi
  (( FAIL == 0 )) || exit 1
}

main "$@"
