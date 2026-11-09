#!/bin/bash
#
# test_m7_d06.sh -- le prove di M7-D06 «Tre brani, una risposta con la fonte»,
# per il docente (sta in _docente/, il materiale del docente):
#   - l'elemento: i tre brani, le due domande, lo schema, le due versioni che
#     differiscono nella sola frase del permesso e hanno lo stesso strumento
#     unico cerca_kb; il README: le dieci sezioni, le frasi di Anthropic con
#     il loro indirizzo, nessun identificativo interno, «smentita» o
#     riferimento alla giornata;
#   - prepara_esercizio.sh e verifica.sh sul punto di partenza (1);
#   - controlla_fonti.py su esecuzioni scritte dalla suite (mai una risposta di
#     Claude): i campi, i brani, i numeri fuori dai brani; il confronto per
#     ogni esito (confermata, non distinguibile, non confermata), che non cambia
#     mai l'uscita (0); le esecuzioni che mancano o non finiscono (1); i file
#     che non si leggono e gli usi sbagliati (2), mai un traceback;
#   - demo/in_classe.sh e _docente/live.sh con il claude finto: quante
#     chiamate, con quali opzioni e quale system prompt, senza
#     ANTHROPIC_API_KEY; le precondizioni (2, nessuna chiamata); una chiamata
#     fallita (1);
#   - shellcheck -x.
# Mai il claude vero: il finto (uno script che fissa l'ambiente e lancia
# claude_finto_m7_d06.py) e l'esca stanno davanti nel PATH, e la suite lo
# controlla prima di usarli. Gli spazi di lavoro nascono in una cartella
# temporanea. CASES è il numero dei casi: se ne girano di più o di meno la
# suite esce 2.
#
# Uso:    m7_assistenti_llm/_docente/test_m7_d06.sh
# Uscita: 0 = tutti i casi passano · 1 = almeno un caso fallito · 2 =
#         precondizione (manca python3, git o shellcheck), o un numero di casi
#         diverso da CASES
set -uo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly MOD="${SELF%/_docente/*}"
readonly RADICE="${MOD%/*}"
D06="${MOD}/s6_conoscenza_e_valutazione/m7_6_la_conoscenza"
D06+="/M7-D06_tre_brani"
readonly D06
readonly FINTO_PY="${MOD}/_docente/claude_finto_m7_d06.py"
# shellcheck source=../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"
readonly CASES=117
FATTO='Fatto: ogni esecuzione è stata messa alla prova;'
FATTO+=' gli esiti sono qui sopra.'
readonly FATTO
TMP=''
PASS=0
FAIL=0
RC=0
OUT=''
TUTTO=''

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

# Esegue un comando; RC e OUT (STDOUT e STDERR insieme); OUT si aggiunge a
# TUTTO, dove alla fine non devono esserci «smentita» né traceback.
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

# Nessun falso positivo: la parola NON c'è (RU-01.T5).
assente() {
  if grep -qF -- "$2" <<< "${OUT}"; then
    fail "$1: «$2» c'è: ${OUT:0:500}"
  else
    pass "$1"
  fi
}

# Un caso che passa se il comando riesce. Arguments: $1 il nome, poi il comando.
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
nuovo_ws() {
  local __r
  __r="$(mktemp -d "${TMP}/radice.XXXXXX")" || exit 2
  "${RADICE}/tools/prepara_esercizio.sh" M7-D06 --radice "${__r}" \
    > "${TMP}/prepara.log" 2>&1 || return 1
  printf -v "$1" '%s' "${__r}/M7-D06"
}

# controlla_fonti.py dell'elemento; RC e OUT come run.
controlla() { run python3 -B -I "${D06}/demo/controlla_fonti.py" "$@"; }

# Il claude finto: uno script che fissa l'ambiente (prova.py lo ripulisce) e
# lancia il finto; anche uv finto. Esce 2 se nel PATH di prova claude non è
# il finto.
prepara_claude() {
  local t
  mkdir -p "${TMP}/finto" "${TMP}/esca" "${TMP}/senza_uv" \
    "${TMP}/senza_claude" || exit 2
  cat > "${TMP}/finto/claude" <<FINTO
#!/bin/bash
export FINTO_LOG="${TMP}/finto.log"
FINTO_MODO="\$(cat "${TMP}/modo" 2>/dev/null || echo ok)"
export FINTO_MODO
exec python3 -B -I "${FINTO_PY}" "\$@"
FINTO
  # uv finto: prova.py lo lancia per preparare l'ambiente del server
  printf '#!/bin/bash\nexit 0\n' > "${TMP}/finto/uv"
  # shellcheck disable=SC2016  # il corpo è dell'esca
  printf '%s\n' '#!/bin/bash' \
    'printf "invocazione %s\n" "$*" >> "${ESCA_LOG}"' > "${TMP}/esca/claude"
  printf '#!/bin/bash\nexit 0\n' > "${TMP}/esca/uv"
  chmod 755 "${TMP}/finto/claude" "${TMP}/finto/uv" "${TMP}/esca/claude" \
    "${TMP}/esca/uv" || exit 2
  for t in readlink python3 git tar; do
    ln -s "$(command -v "${t}")" "${TMP}/senza_uv/${t}" || exit 2
    ln -s "$(command -v "${t}")" "${TMP}/senza_claude/${t}" || exit 2
  done
  ln -s "${TMP}/esca/claude" "${TMP}/senza_uv/claude" || exit 2
  ln -s "${TMP}/esca/uv" "${TMP}/senza_claude/uv" || exit 2
  t="$(PATH="${TMP}/finto:${PATH}" command -v claude)"
  if [[ "${t}" != "${TMP}/finto/claude" ]]; then
    echo "test_m7_d06: nel PATH di prova claude è ${t}, non il finto" >&2
    exit 2
  fi
}

# Sceglie come si comporta il claude finto. Arguments: $1 il modo.
modo() { printf '%s' "$1" > "${TMP}/modo" || exit 2; }

# Una domanda di un'esecuzione, scritta dalla suite (nessuna è una risposta di
# Claude). Arguments: $1 la cartella delle esecuzioni, $2 l'esecuzione
# (con-permesso-1…), $3 il caso, $4 coperta true/false, $5 il codice o null,
# $6 la risposta, $7 facoltativo: i brani restituiti («KB-90,KB-91», default)
# oppure «nessuno».
scrivi_domanda() {
  local dove="$1/$2/$3"
  mkdir -p "${dove}" || exit 2
  python3 -B -I - "${dove}" "$3" "$4" "$5" "$6" "${7:-KB-90,KB-91}" <<'PY' \
    || exit 2
import json, os, sys
dove, caso, coperta, codice, risposta, brani = sys.argv[1:]
strutturato = {"coperta": coperta == "true",
               "codice_procedura": None if codice == "null" else codice,
               "risposta": risposta}
esito = {"caso": caso, "completa": True, "errore": False,
         "strutturato": strutturato, "turni": 2, "secondi": 3.0,
         "token_prima_richiesta": 2000}
init = {"type": "system", "subtype": "init", "session_id": "s-finta",
        "tools": ["mcp__assistenza__cerca_kb"],
        "mcp_servers": [{"name": "assistenza", "status": "connected"}]}
json.dump(esito, open(os.path.join(dove, "esito.json"), "w", encoding="utf-8"),
          ensure_ascii=False)
estratti = {"KB-90": "Il nuovo router parte entro 2 giorni lavorativi; "
                     "si rispedisce entro 10 giorni.",
            "KB-91": "Restituzione entro 30 giorni dalla cessazione.",
            "KB-92": "L'intervento costa 59 euro."}
registro = os.path.join(dove, "registro.jsonl")
if brani == "nessuno":
    if os.path.exists(registro):
        os.remove(registro)
else:
    risultati = [{"id": b, "titolo": b, "estratto": estratti[b]}
                 for b in brani.split(",")]
    riga = {"n": 1, "strumento": "cerca_kb", "capacita": "cerca_kb",
            "argomenti": {"query": "router"},
            "risultato": {"risultati": risultati}, "errore": False}
    with open(registro, "w", encoding="utf-8") as fh:
        fh.write(json.dumps(riga, ensure_ascii=False) + "\n")
fine = {"type": "result", "subtype": "success", "is_error": False,
        "num_turns": 2, "duration_ms": 3000, "result": risposta,
        "structured_output": strutturato,
        "usage": {"input_tokens": 3, "cache_creation_input_tokens": 2000,
                  "cache_read_input_tokens": 0, "output_tokens": 40},
        "modelUsage": {"finto": {"inputTokens": 3, "outputTokens": 40,
                                 "cacheReadInputTokens": 0,
                                 "cacheCreationInputTokens": 2000}}}
with open(os.path.join(dove, "stream.jsonl"), "w", encoding="utf-8") as fh:
    fh.write(json.dumps(init, ensure_ascii=False) + "\n")
    fh.write(json.dumps(fine, ensure_ascii=False) + "\n")
PY
}

# Cambia un evento dello stream di una domanda. Arguments: $1 lo stream, $2
# «init» o «result», $3 l'espressione Python che modifica il dizionario e.
ritocca_stream() {
  python3 -B -I - "$1" "$2" "$3" <<'PY' || exit 2
import json, sys
percorso, quale, codice = sys.argv[1:]
righe = [json.loads(r) for r in open(percorso, encoding="utf-8") if r.strip()]
e = next(r for r in righe if r.get("type") == quale
         or r.get("subtype") == quale)
exec(codice)  # solo testo della suite
with open(percorso, "w", encoding="utf-8") as fh:
    for riga in righe:
        fh.write(json.dumps(riga, ensure_ascii=False) + "\n")
PY
}

# Una serie di esecuzioni, n per braccio: la domanda coperta ha risposta e
# codice giusti in tutte; la non coperta ha coperta false nel braccio con il
# permesso e true (con un numero inventato) nell'altro. Arguments: $1 la
# variabile della cartella da assegnare, $2 quante esecuzioni per braccio.
serie() {
  local __d k b
  __d="$(mktemp -d "${TMP}/serie.XXXXXX")" || exit 2
  for (( k = 1; k <= $2; k++ )); do
    for b in con-permesso senza-permesso; do
      scrivi_domanda "${__d}" "${b}-${k}" coperta true KB-90 \
        'Parte entro 2 giorni lavorativi.'
      if [[ "${b}" == con-permesso ]]; then
        scrivi_domanda "${__d}" "${b}-${k}" non-coperta false null \
          'Non lo so: le procedure che ho non lo dicono.'
      else
        scrivi_domanda "${__d}" "${b}-${k}" non-coperta true KB-92 \
          'Paghi 75 euro in fattura.' KB-90,KB-92
      fi
    done
  done
  printf -v "$1" '%s' "${__d}"
}

t_elemento() {
  local f
  for f in README.md verifica.sh progetti.txt demo/in_classe.sh \
      demo/controlla_fonti.py demo/schema.json demo/casi/caso-1-coperta.json \
      demo/casi/caso-2-non-coperta.json demo/con-permesso/system-prompt.md \
      demo/senza-permesso/system-prompt.md demo/con-permesso/strumenti.json \
      demo/senza-permesso/strumenti.json \
      demo/kb/kb-90-router-comodato-guasto.md \
      demo/kb/kb-91-router-fine-contratto.md demo/kb/kb-92-presa-ottica.md \
      _docente/live.sh soluzione/LEGGIMI.md; do
    vero "elemento: ${f}" test -f "${D06}/${f}"
  done
  for f in verifica.sh _docente/live.sh demo/in_classe.sh; do
    vero "elemento: ${f} eseguibile" test -x "${D06}/${f}"
  done
  run python3 -B -I - "${D06}" <<'PY'
import difflib, json, os, re, sys
item = sys.argv[1]
def testo(p):
    return open(os.path.join(item, p), encoding="utf-8").read()
problemi = []
con, senza = (testo("demo/%s/system-prompt.md" % a)
              for a in ("con-permesso", "senza-permesso"))
aggiunte = [r for r in difflib.ndiff(senza.split("\n"), con.split("\n"))
            if r.startswith(("+ ", "- "))]
if len(aggiunte) != 1 or not aggiunte[0].startswith("+ "):
    problemi.append("le versioni differiscono in: %r" % aggiunte)
elif "non lo sai" not in aggiunte[0]:
    problemi.append("la frase del permesso: %r" % aggiunte[0])
for tag in ("<role>", "<context>", "<instructions>", "<format>",
            "<constraints>"):
    if con.count(tag) != 1:
        problemi.append("%s non è una volta" % tag)
if not re.search(r"<role>\nSei ", con):
    problemi.append("il ruolo non comincia con «Sei»")
if testo("demo/con-permesso/strumenti.json") \
        != testo("demo/senza-permesso/strumenti.json"):
    problemi.append("strumenti.json diversi")
strumenti = json.loads(testo("demo/con-permesso/strumenti.json"))
if len(strumenti) != 1 or strumenti[0].get("capacita") != "cerca_kb":
    problemi.append("lo strumento: %r" % strumenti)
schema = json.loads(testo("demo/schema.json"))
if sorted(schema["properties"]) != ["codice_procedura", "coperta", "risposta"]:
    problemi.append("lo schema: %r" % sorted(schema["properties"]))
if schema["properties"]["coperta"]["type"] != "boolean":
    problemi.append("coperta non è boolean")
casi = sorted(os.listdir(os.path.join(item, "demo/casi")))
if casi != ["caso-1-coperta.json", "caso-2-non-coperta.json"]:
    problemi.append("casi: %r" % casi)
for c in casi:
    d = json.loads(testo("demo/casi/" + c))
    for campo in ("id", "scenario", "messaggio", "asserzioni"):
        if campo not in d:
            problemi.append("%s senza %s" % (c, campo))
for k in os.listdir(os.path.join(item, "demo/kb")):
    t = testo("demo/kb/" + k)
    if not re.match(r"# KB-9[0-9] · ", t) or len(t.split()) >= 60:
        problemi.append("il brano %s: %d parole" % (k, len(t.split())))
print("; ".join(problemi) or "versioni giuste")
PY
  expect "elemento: una sola frase in più, lo stesso strumento, tre brani" 0 \
    "versioni giuste"
}

# Il README: le dieci sezioni, le frasi di Anthropic, niente di vietato.
t_readme() {
  run python3 -B -I - "${D06}/README.md" <<'PY'
import sys
readme = open(sys.argv[1], encoding="utf-8").read()
piano = " ".join(readme.split())
problemi = []
sezioni = ("Obiettivo", "Tempo", "Prerequisiti", "Punto di partenza",
           "Passi in Claude Code", "Che cosa osservare", "Verifica",
           "Se qualcosa va storto", "Impronta d'uso sul piano Pro",
           "Per approfondire")
titoli = [r[3:] for r in readme.splitlines() if r.startswith("## ")]
if [next((s for s in sezioni if t.startswith(s)), "") for t in titoli] \
        != list(sezioni):
    problemi.append("le dieci sezioni, in ordine: %s" % titoli)
for titolo in ("## Punto di partenza (tools/prepara_esercizio.sh M7-D06)",
               "## Verifica (tools/verifica.sh M7-D06)"):
    if titolo not in readme:
        problemi.append("il titolo «%s»" % titolo)
H = "https://platform.claude.com/docs/en/test-and-evaluate/" \
    "strengthen-guardrails/reduce-hallucinations"
frasi = [
    ("Allow Claude to say \"I don't know\": Explicitly give Claude "
     "permission to admit uncertainty. This technique can drastically "
     "reduce false information.", H),
    ("Make Claude's response auditable by having it cite quotes and sources "
     "for each of its claims.", H),
    ("If you're unsure about any aspect or if the report lacks necessary "
     "information, say \"I don't have enough information to confidently "
     "assess this.\"", H),
    ("Remember, although these techniques significantly reduce "
     "hallucinations, they don't eliminate them entirely.", H),
    ("Get validated JSON output matching a JSON Schema after the agent "
     "completes its workflow (print mode only).",
     "https://code.claude.com/docs/en/cli-reference")]
for frase, url in frasi:
    if frase not in piano:
        problemi.append("manca «%s»" % frase[:50])
    if url not in readme:
        problemi.append("manca %s" % url)
for vietata in ("smentit", "FACT-", "M7-X", "X-3", "X-4", "oggi", "domani",
                "pausa", "pranzo", "/home/"):
    if vietata in readme:
        problemi.append("«%s»" % vietata)
print("; ".join(problemi) or "README a posto")
PY
  expect "README: sezioni, frasi con l'indirizzo, niente di vietato" 0 \
    "README a posto"
  run python3 -B -I - "${D06}" <<'PY'
import json, os, re, sys
item = sys.argv[1]
testo = open(os.path.join(item, "README.md"), encoding="utf-8").read()
casi = ["caso-1-coperta.json", "caso-2-non-coperta.json"]
problemi = []
for n, c in enumerate(casi, 1):
    m = re.search(r"<!-- prompt %d -->\n(.*?)\n\s*<!-- /prompt %d -->" % (n, n),
                  testo, re.S)
    messaggio = json.load(open(os.path.join(item, "demo/casi", c),
                               encoding="utf-8"))["messaggio"]
    if not m or " ".join(m.group(1).split()) != messaggio:
        problemi.append("il prompt %d non è il messaggio di %s" % (n, c))
print("; ".join(problemi) or "prompt uguali ai casi")
PY
  expect "README: i due prompt sono i messaggi dei casi, parola per parola" 0 \
    "prompt uguali ai casi"
  run "${RADICE}/tools/check_handson.sh"
  if grep -q 'M7-D06' <<< "${OUT}"; then
    fail "check_handson: una segnalazione su M7-D06: $(grep 'M7-D06' \
      <<< "${OUT}")"
  else
    pass "check_handson: nessuna segnalazione su M7-D06"
  fi
}

t_prepara() {
  local ws f
  if ! nuovo_ws ws; then
    fail "prepara_esercizio.sh M7-D06: $(tail -n 3 "${TMP}/prepara.log")"
    return
  fi
  pass "prepara_esercizio.sh M7-D06"
  for f in schema.json controlla_fonti.py in_classe.sh \
      con-permesso/system-prompt.md kb/kb-92-presa-ottica.md \
      casi/caso-2-non-coperta.json \
      progetti/assistenza-clienti/banco/prova.py; do
    vero "spazio di lavoro: ${f}" test -f "${ws}/${f}"
  done
  if [[ ! -e "${ws}/soluzione" && ! -e "${ws}/_docente" ]]; then
    pass "spazio di lavoro: niente soluzione/ né _docente/"
  else
    fail "spazio di lavoro: soluzione/ o _docente/"
  fi
  run "${RADICE}/tools/verifica.sh" M7-D06 --radice "${ws%/M7-D06}"
  expect "verifica.sh sul punto di partenza: 1" 1 \
    "Manca la cartella risposte/"
}

t_controllo() {
  local j
  serie j 3
  controlla "${j}"
  expect "controllo: tre esecuzioni per braccio, 0" 0 "confermata (con il permesso 3, senza 0)"
  expect "controllo: i brani restituiti" 0 "brani restituiti: KB-90, KB-91"
  expect "controllo: i campi" 0 "coperta: no; codice_procedura: null"
  expect "controllo: il codice fra i brani" 0 \
    "coperta: sì; codice_procedura: KB-90; fra i brani restituiti: sì"
  expect "controllo: i numeri fuori dai brani, dato" 0 \
    "(dato) numeri della risposta che non stanno nei brani: 75"
  expect "controllo: il numero nei brani non è segnalato" 0 \
    "(dato) numeri della risposta che non stanno nei brani: nessuno"
  expect "controllo: la domanda coperta, codice giusto come dato" 0 \
    "con il permesso di dire «non lo so»: 3 su 3"
  expect "controllo: non coperta, n su N nei due bracci" 0 \
    "con il permesso di dire «non lo so»: 3 su 3; (dato) con un numero che non sta nei brani: 0 su 3"
  expect "controllo: non coperta, senza permesso" 0 \
    "senza quel permesso: 0 su 3; (dato) con un numero che non sta nei brani: 3 su 3"
  expect "controllo: il consumo, come dato" 0 \
    "Come dati, tutte le 12 chiamate: turni 24; token 24.516; 36,0 s."
  assente "controllo: nessun «non distinguibile» qui" "non distinguibile"
  serie j 3
  scrivi_domanda "${j}" senza-permesso-1 non-coperta false null 'Non lo so.'
  scrivi_domanda "${j}" senza-permesso-2 non-coperta false null 'Non lo so.'
  scrivi_domanda "${j}" senza-permesso-3 non-coperta false null 'Non lo so.'
  controlla "${j}"
  expect "esito: uguali, non distinguibile, 0" 0 \
    "non distinguibile (3 contro 3"
  serie j 3
  scrivi_domanda "${j}" con-permesso-1 non-coperta true KB-90 \
    'Paghi 2 giorni di stipendio.' KB-90
  scrivi_domanda "${j}" con-permesso-2 non-coperta true KB-90 'Non so.' KB-90
  controlla "${j}"
  expect "esito: la conta scende, 1 contro 0" 0 \
    "confermata (con il permesso 1, senza 0)"
  serie j 2
  scrivi_domanda "${j}" con-permesso-1 non-coperta true KB-90 'Paghi.' KB-90
  scrivi_domanda "${j}" con-permesso-2 non-coperta true KB-90 'Paghi.' KB-90
  scrivi_domanda "${j}" senza-permesso-1 non-coperta false null 'Non lo so.'
  controlla "${j}"
  expect "esito: meno con il permesso, non confermata, 0" 0 \
    "non confermata in questa misura (con il permesso 0, senza 1)"
  serie j 1
  scrivi_domanda "${j}" con-permesso-1 coperta true KB-99 'Parte.' KB-90
  controlla "${j}"
  expect "dato: un codice che non è fra i brani" 0 \
    "fra i brani restituiti: no"
  expect "dato: il codice giusto, 0 su 1" 0 \
    "con il permesso di dire «non lo so»: 0 su 1"
  serie j 1
  scrivi_domanda "${j}" con-permesso-1 non-coperta false null 'Non lo so.' \
    nessuno
  controlla "${j}"
  expect "dato: nessuna chiamata a cerca_kb" 0 "nessuna chiamata a cerca_kb"
  serie j 1
  scrivi_domanda "${j}" senza-permesso-1 coperta true KB-90 \
    'Costa 1.200,50 euro o tre euro, KB-90.' KB-90
  controlla "${j}"
  expect "numeri: migliaia, decimali, lettere, mai il codice KB" 0 \
    "numeri della risposta che non stanno nei brani: 1.200,50, tre"
}

t_mancanze() {
  local j
  serie j 2
  rm -r -- "${j}/con-permesso-2"
  controlla "${j}"
  expect "mancanza: un'esecuzione senza la sua coppia, 1" 1 \
    "manca l'esecuzione con-permesso-2"
  serie j 1
  rm -r -- "${j}/senza-permesso-1/non-coperta"
  controlla "${j}"
  expect "mancanza: una domanda che manca, 1" 1 \
    "manca senza-permesso-1/non-coperta/stream.jsonl"
  serie j 1
  sed -i '/"type": "result"/d' "${j}/con-permesso-1/coperta/stream.jsonl"
  controlla "${j}"
  expect "mancanza: uno stream senza il risultato, 1" 1 "non è finita bene"
  serie j 1
  ritocca_stream "${j}/senza-permesso-1/coperta/stream.jsonl" result \
    'e["is_error"] = True'
  controlla "${j}"
  expect "mancanza: un risultato con l'errore, 1" 1 "non è finita bene"
  serie j 1
  ritocca_stream "${j}/con-permesso-1/coperta/stream.jsonl" result \
    'e["structured_output"] = None'
  controlla "${j}"
  expect "mancanza: senza l'uscita strutturata, 1" 1 \
    "senza l'uscita strutturata"
  serie j 1
  ritocca_stream "${j}/con-permesso-1/coperta/stream.jsonl" init \
    'e["mcp_servers"][0]["status"] = "failed"; e["tools"] = []'
  controlla "${j}"
  expect "mancanza: il server MCP che non si è collegato, 1" 1 \
    "non si è collegato"
  # Un init compattato, senza «tools» né «mcp_servers», non è un guasto: lo
  # hanno le copie della registrazione in soluzione/.
  serie j 1
  ritocca_stream "${j}/con-permesso-1/coperta/stream.jsonl" init \
    'del e["tools"], e["mcp_servers"]'
  controlla "${j}"
  expect "init compattato: si conta, 0" 0 "confermata"
  # L'uscita strutturata si legge dallo stream: esito.json non conta, che menta
  # o che manchi.
  serie j 1
  python3 -B -I - "${j}/con-permesso-1/non-coperta/esito.json" <<'PY' || exit 2
import json, sys
p = sys.argv[1]; d = json.load(open(p, encoding="utf-8"))
d["strutturato"]["coperta"] = True
d["strutturato"]["codice_procedura"] = "KB-92"
json.dump(d, open(p, "w", encoding="utf-8"))
PY
  controlla "${j}"
  expect "esito.json che mente: il confronto dallo stream, 0" 0 \
    "confermata (con il permesso 1, senza 0)"
  serie j 1
  rm -f -- "${j}"/*/*/esito.json
  controlla "${j}"
  expect "esito.json assente: il confronto dallo stream, 0" 0 \
    "confermata (con il permesso 1, senza 0)"
}

t_illeggibili() {
  local j
  serie j 1
  printf '{rotto\n' > "${j}/senza-permesso-1/coperta/stream.jsonl" || exit 2
  controlla "${j}"
  expect "illeggibile: uno stream rotto, 2" 2 "non è JSON"
  assente "illeggibile: nessun traceback" "Traceback"
  serie j 1
  printf 'non json\n' > "${j}/con-permesso-1/non-coperta/registro.jsonl" \
    || exit 2
  controlla "${j}"
  expect "illeggibile: una riga del registro rotta, 2" 2 "non è JSON"
  serie j 1
  rm -f -- "${j}/con-permesso-1/coperta/stream.jsonl"
  controlla "${j}"
  expect "mancanza: lo stream che manca, 1" 1 \
    "manca con-permesso-1/coperta/stream.jsonl"
  j="$(mktemp -d "${TMP}/vuota.XXXXXX")"
  controlla "${j}"
  expect "illeggibile: nessuna esecuzione, 2" 2 "nessuna esecuzione"
  controlla "${TMP}/non-c-e"
  expect "illeggibile: una cartella che non c'è, 2" 2 "non esiste"
  controlla
  expect "uso: senza argomenti, 2" 2 "Uso:"
  controlla --aiuto
  expect "uso: un'opzione, 2" 2 "Uso:"
  serie j 1
  run env PN_HANDSON_ROOT="${TMP}/non-c-e" python3 -B -I \
    "${D06}/demo/controlla_fonti.py" "${j}"
  expect "precondizione: tools/ che non c'è, 2" 2 \
    "non trovo tools/lib_leggi_contesto.py"
}

t_verifica() {
  local ws j
  nuovo_ws ws || { fail "verifica: prepara_esercizio.sh"; return; }
  run "${D06}/verifica.sh" "${ws}"
  expect "verifica: senza risposte/, 1" 1 "Manca la cartella risposte/"
  mkdir -p "${ws}/risposte" || exit 2
  run "${D06}/verifica.sh" "${ws}"
  expect "verifica: risposte/ vuota, 1" 1 "nessuna esecuzione"
  serie j 1
  cp -R "${j}/." "${ws}/risposte/" || exit 2
  printf 'print("CONTROLLO FINTO")\n' > "${ws}/controlla_fonti.py" || exit 2
  run env PN_HANDSON_ROOT="${RADICE}" "${D06}/verifica.sh" "${ws}"
  expect "verifica: una serie completa, 0, «Fatto»" 0 "${FATTO}"
  assente "verifica: il controllo dell'elemento, non della copia" \
    "CONTROLLO FINTO"
  rm -r -- "${ws}/risposte/con-permesso-1"
  run "${D06}/verifica.sh" "${ws}"
  expect "verifica: un'esecuzione che manca, 1" 1 "con-permesso-1"
  run "${D06}/verifica.sh"
  expect "verifica: senza argomenti, 2" 2 "spazio di lavoro assente"
}

# Lo script con l'esca davanti nel PATH, il registro nuovo.
# Arguments: $1 lo script, $2 lo spazio di lavoro, $3 facoltativo il PATH,
# poi le variabili NOME=valore.
esca() {
  local script="$1" w="$2" percorso="${3:-${TMP}/esca:${PATH}}"
  shift 2
  (( $# == 0 )) || shift
  : > "${TMP}/esca.log"
  run env PATH="${percorso}" HANDSON_NO_PAUSE=1 ESCA_LOG="${TMP}/esca.log" \
    "$@" "${script}" "${w}"
}

# Una precondizione: 2, la parola, nessuna chiamata al modello.
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

# Lo script con il finto davanti nel PATH.
finto() {
  local script="$1" w="$2"
  shift 2
  : > "${TMP}/finto.log"
  run env PATH="${TMP}/finto:${PATH}" HANDSON_NO_PAUSE=1 \
    ANTHROPIC_API_KEY=valore-finto TMPDIR="${TMP}" "$@" "${script}" "${w}"
}

# Le chiamate del finto, contro le attese: quante, con quali opzioni e con
# quale system prompt. Arguments: $1 il registro, $2 quante esecuzioni.
controlla_chiamate() {
  run python3 -B -I - "$1" "$2" "${D06}" <<'PY'
import json, os, sys
log, n, item = sys.argv[1:4]
righe = [json.loads(r) for r in open(log, encoding="utf-8")]
chiamate = [r for r in righe if r["argv"][:1] != ["--version"]]
attese = 2 * 2 * int(n)
problemi = []
if len(chiamate) != attese:
    problemi.append("%d chiamate invece di %d" % (len(chiamate), attese))
per_braccio = {"con-permesso": 0, "senza-permesso": 0}
for i, c in enumerate(chiamate, 1):
    a = c["argv"]
    fisse = (("--model", "sonnet"), ("--effort", "low"),
             ("--output-format", "stream-json"), ("--tools", ""),
             ("--setting-sources", "project,local"),
             ("--permission-mode", "dontAsk"),
             ("--permission-prompts", "none"),
             ("--allowedTools", "mcp__assistenza__*"))
    for k, v in fisse:
        if k not in a or a[a.index(k) + 1] != v:
            problemi.append("chiamata %d: %s" % (i, k))
    for k in ("-p", "--verbose", "--strict-mcp-config",
              "--no-session-persistence", "--json-schema", "--mcp-config"):
        if k not in a:
            problemi.append("chiamata %d: manca %s" % (i, k))
    if any("dangerously" in x or "bypassPermissions" in x for x in a):
        problemi.append("chiamata %d: salta i permessi" % i)
    if c["chiave"]:
        problemi.append("chiamata %d: con ANTHROPIC_API_KEY" % i)
    sp = a[a.index("--system-prompt-file") + 1]
    braccio = next((b for b in per_braccio if ("/%s-" % b) in sp), None)
    if braccio is None:
        problemi.append("chiamata %d: il system prompt %s" % (i, sp))
        continue
    per_braccio[braccio] += 1
    if c["permesso"] != (braccio == "con-permesso"):
        problemi.append("chiamata %d: il permesso nel braccio sbagliato" % i)
if per_braccio["con-permesso"] != per_braccio["senza-permesso"]:
    problemi.append("per braccio: %r" % per_braccio)
print("; ".join(problemi) or "chiamate giuste")
PY
}

t_in_classe() {
  local ws
  nuovo_ws ws || { fail "in_classe: prepara_esercizio.sh"; return; }
  modo ok
  finto "${D06}/demo/in_classe.sh" "${ws}" PN_ESECUZIONI=2
  expect "in_classe: due esecuzioni per braccio, 0" 0 \
    "VERIFICA OK   il controllo, sulle esecuzioni di risposte/"
  expect "in_classe: il comando del banco sullo schermo" 0 \
    "--versione con-permesso"
  expect "in_classe: il confronto, sullo schermo" 0 "confermata"
  controlla_chiamate "${TMP}/finto.log" 2
  expect "in_classe: le chiamate e le opzioni" 0 "chiamate giuste"
  run git -C "${ws}" status --porcelain
  if [[ "${OUT}" == '?? risposte/' ]]; then
    pass "in_classe: lo spazio di lavoro cambia solo in risposte/"
  else
    fail "in_classe: git status «${OUT}»"
  fi
  run env PN_HANDSON_ROOT="${RADICE}" "${D06}/verifica.sh" "${ws}"
  expect "in_classe: poi verifica.sh, 0" 0 "${FATTO}"
}

t_live() {
  local ws
  nuovo_ws ws || { fail "live: prepara_esercizio.sh"; return; }
  modo ok
  finto "${D06}/_docente/live.sh" "${ws}"
  expect "live: tre esecuzioni per braccio, 0" 0 \
    "VERIFICA OK   verifica.sh dell'elemento"
  controlla_chiamate "${TMP}/finto.log" 3
  expect "live: le dodici chiamate" 0 "chiamate giuste"
  run "${RADICE}/tools/verifica.sh" M7-D06 --radice "${ws%/M7-D06}"
  expect "live: poi tools/verifica.sh, 0" 0 "VERIFICA OK   M7-D06: fatto."
  run "${D06}/_docente/live.sh"
  expect "live: senza argomenti, 2" 2 "uso:"
}

t_precondizioni() {
  local ws s="${D06}/demo/in_classe.sh"
  nuovo_ws ws || { fail "precondizioni: prepara_esercizio.sh"; return; }
  precondizione "precondizione: una cartella che non è lo spazio" \
    "non è lo spazio di lavoro di M7-D06" "${s}" "${TMP}"
  precondizione "precondizione: nessuno spazio di lavoro" \
    "spazio di lavoro assente" "${s}" ""
  precondizione "precondizione: PN_ESECUZIONI 0" "PN_ESECUZIONI" \
    "${s}" "${ws}" "${TMP}/esca:${PATH}" PN_ESECUZIONI=0
  precondizione "precondizione: HANDSON_ENV claude-ai-pro" \
    "è un elemento claude-code-pro" "${s}" "${ws}" "${TMP}/esca:${PATH}" \
    HANDSON_ENV=claude-ai-pro
  precondizione "precondizione: senza uv" "manca lo strumento: uv" \
    "${s}" "${ws}" "${TMP}/senza_uv"
  precondizione "precondizione: senza claude" "manca lo strumento: claude" \
    "${s}" "${ws}" "${TMP}/senza_claude"
  printf 'x\n' > "${ws}/estraneo.txt" || exit 2
  precondizione "precondizione: uno spazio di lavoro cambiato" \
    "non è al punto di partenza" "${s}" "${ws}"
  rm -f -- "${ws}/estraneo.txt"
  mkdir -p "${ws}/risposte" || exit 2
  precondizione "precondizione: risposte/ c'è già" \
    "non è al punto di partenza" "${s}" "${ws}"
  rmdir -- "${ws}/risposte"
  mv -- "${ws}/schema.json" "${TMP}/schema.json" || exit 2
  precondizione "precondizione: lo schema che manca" \
    "file assente o illeggibile: schema.json" "${s}" "${ws}"
  precondizione "precondizione: senza tools/lib_handson.sh" \
    "lanciatelo dal repository, o date PN_HANDSON_ROOT" "${s}" "${ws}" \
    "${TMP}/esca:${PATH}" PN_HANDSON_ROOT="${TMP}/non-c-e"
}

t_fallita() {
  local ws
  nuovo_ws ws || { fail "fallita: prepara_esercizio.sh"; return; }
  modo rotto
  finto "${D06}/demo/in_classe.sh" "${ws}"
  expect "fallita: una chiamata che fallisce, 1" 1 \
    "VERIFICA KO   con-permesso-1: il banco di prova"
  nuovo_ws ws || { fail "fallita: prepara_esercizio.sh"; return; }
  modo senza_strutturato
  finto "${D06}/_docente/live.sh" "${ws}" PN_ESECUZIONI=1
  expect "fallita: senza uscita strutturata, 1" 1 \
    "senza l'uscita strutturata"
  nuovo_ws ws || { fail "fallita: prepara_esercizio.sh"; return; }
  modo server_ko
  finto "${D06}/demo/in_classe.sh" "${ws}"
  modo ok
  expect "fallita: il server MCP che non parte, 1" 1 \
    "VERIFICA KO   con-permesso-1: il banco di prova"
  expect "fallita: il motivo del server, sullo schermo" 1 "non si è collegato"
  run env PN_HANDSON_ROOT="${RADICE}" "${D06}/verifica.sh" "${ws}"
  expect "fallita: verifica.sh non conta quella prova, 1" 1 "non si è collegato"
}

t_shellcheck() {
  local f
  for f in "${D06}/verifica.sh" "${D06}/_docente/live.sh" \
      "${D06}/demo/in_classe.sh" "${SELF}"; do
    if ( cd "${RADICE}" && shellcheck -x -- "${f}" ) > /dev/null 2>&1; then
      pass "shellcheck ${f#"${RADICE}"/}"
    else
      fail "shellcheck ${f#"${RADICE}"/}"
    fi
  done
}

main() {
  local t
  for t in python3 git shellcheck; do
    command -v "${t}" > /dev/null 2>&1 \
      || { echo "test_m7_d06: manca ${t}" >&2; exit 2; }
  done
  [[ -f "${FINTO_PY}" ]] \
    || { echo "test_m7_d06: manca ${FINTO_PY}" >&2; exit 2; }
  handson::init_temp_base
  TMP="$(mktemp -d "${HANDSON_TEMP_BASE}/test_m7_d06.XXXXXX")" || exit 2
  trap 'chmod -R u+rwX "${TMP}" 2> /dev/null; rm -rf "${TMP}"' EXIT
  prepara_claude
  t_elemento
  t_readme
  t_prepara
  t_controllo
  t_mancanze
  t_illeggibili
  t_verifica
  t_in_classe
  t_live
  t_precondizioni
  t_fallita
  t_shellcheck
  OUT="${TUTTO}"
  assente "in nessuna uscita «smentita»" "smentita"
  assente "in nessuna uscita un traceback" "Traceback"
  echo "PASS=${PASS} FAIL=${FAIL}"
  if (( PASS + FAIL != CASES )); then
    echo "test_m7_d06: girati $((PASS + FAIL)) casi, attesi ${CASES}" >&2
    exit 2
  fi
  (( FAIL == 0 )) || exit 1
}

main "$@"
