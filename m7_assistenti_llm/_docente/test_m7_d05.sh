#!/bin/bash
#
# test_m7_d05.sh -- le prove di M7-D05 «Cercare per significato», per il
# docente (sta in _docente/, il materiale del docente):
#   - l'elemento: i file, i dodici articoli, le tre domande; il README: le
#     dieci sezioni, le frasi di Anthropic con il loro indirizzo, nessun
#     identificativo interno, «smentita» o riferimento alla giornata;
#   - prepara_esercizio.sh e verifica.sh sul punto di partenza (1);
#   - cerca.py su un Ollama finto (ollama_finto_m7_d05.py, vettori fissi):
#     le classifiche, il modello e il digest, risposte/risultati.json; la
#     progettazione delle domande (la ricerca per parole trova la prima, non
#     trova la seconda, si sbaglia sulla terza);
#   - cerca.py quando le cose vanno male: Ollama che non risponde, un host che
#     non è loopback, il modello che manca, un errore HTTP, un JSON rotto,
#     vettori sbagliati, articoli o domande che mancano (2, mai un traceback);
#   - verifica.sh: risultati.json che manca, rotto, senza una domanda (1);
#     completo (0); il controllo dell'elemento e non la copia;
#   - _docente/live.sh sull'Ollama finto, senza nessun servizio avviato e
#     senza chiamare Claude;
#   - shellcheck -x.
# Mai l'Ollama vero: la suite non parla con la porta 11434. Gli spazi di lavoro
# nascono in una cartella temporanea. CASES è il numero dei casi: se ne girano
# di più o di meno la suite esce 2.
#
# Uso:    m7_assistenti_llm/_docente/test_m7_d05.sh
# Uscita: 0 = tutti i casi passano · 1 = almeno un caso fallito · 2 =
#         precondizione (manca python3, git o shellcheck), o un numero di casi
#         diverso da CASES
set -uo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly MOD="${SELF%/_docente/*}"
readonly RADICE="${MOD%/*}"
D05="${MOD}/s6_conoscenza_e_valutazione/m7_6_la_conoscenza"
D05+="/M7-D05_cercare_per_significato"
readonly D05
readonly FINTO_PY="${MOD}/_docente/ollama_finto_m7_d05.py"
# shellcheck source=../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"
readonly CASES=78
readonly FATTO='Fatto: le due ricerche sono in risposte/risultati.json.'
TMP=''
PORTA=''
FINTO_PID=''
PASS=0
FAIL=0
RC=0
OUT=''
TUTTO=''

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

# Esegue un comando; RC e OUT (STDOUT e STDERR insieme) per expect; OUT si
# aggiunge a TUTTO, dove alla fine non devono esserci traceback.
run() { OUT="$("$@" 2>&1)"; RC=$?; TUTTO+="${OUT}"$'\n'; }

# Uscita attesa E parola chiave attesa (RU-01.T3).
# Arguments: $1 il nome, $2 l'uscita attesa, $3 la parola (grep -F).
expect() {
  if (( RC == $2 )) && grep -qF -- "$3" <<< "${OUT}"; then
    pass "$1"
  else
    fail "$1 (rc=${RC}, attesa $2, parola «$3»): ${OUT:0:500}"
  fi
}

# Nessun falso positivo: la parola NON c'è (RU-01.T5).
# Arguments: $1 il nome, $2 la parola.
assente() {
  if grep -qF -- "$2" <<< "${OUT}"; then
    fail "$1: «$2» c'è: ${OUT:0:400}"
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
# Returns: 0; 1 se prepara_esercizio.sh non riesce.
nuovo_ws() {
  local __r
  __r="$(mktemp -d "${TMP}/radice.XXXXXX")" || exit 2
  "${RADICE}/tools/prepara_esercizio.sh" M7-D05 --radice "${__r}" \
    > "${TMP}/prepara.log" 2>&1 || return 1
  printf -v "$1" '%s' "${__r}/M7-D05"
}

# Avvia l'Ollama finto su una porta libera. Globals: FINTO_PID, PORTA.
avvia_finto() {
  local i
  printf 'ok' > "${TMP}/modo" || exit 2
  python3 -B -I "${FINTO_PY}" "${TMP}/porta" "${TMP}/modo" \
    "${TMP}/richieste.log" &
  FINTO_PID=$!
  for (( i = 0; i < 100; i++ )); do
    if [[ -s "${TMP}/porta" ]]; then
      PORTA="$(cat "${TMP}/porta")"
      return 0
    fi
    sleep 0.05
  done
  echo "test_m7_d05: l'Ollama finto non parte" >&2
  exit 2
}

# Sceglie come si comporta l'Ollama finto. Arguments: $1 il modo.
modo() { printf '%s' "$1" > "${TMP}/modo" || exit 2; }

# cerca.py della copia dello spazio di lavoro, sull'Ollama finto; RC e OUT.
# Arguments: $1 lo spazio di lavoro.
cerca() {
  run env PN_OLLAMA_URL="http://127.0.0.1:${PORTA}" \
    python3 -B -I "$1/cerca.py" "$1"
}

t_elemento() {
  local f n
  for f in README.md verifica.sh demo/cerca.py demo/controlla_risultati.py \
      demo/domande.txt _docente/live.sh soluzione/LEGGIMI.md; do
    vero "elemento: ${f}" test -f "${D05}/${f}"
  done
  for f in verifica.sh _docente/live.sh; do
    vero "elemento: ${f} eseguibile" test -x "${D05}/${f}"
  done
  n="$(command find "${D05}/demo/articoli" -name 'art-*.md' | wc -l)"
  if (( n == 12 )); then
    pass "elemento: dodici articoli"
  else
    fail "elemento: ${n} articoli"
  fi
  n="$(grep -c . "${D05}/demo/domande.txt")"
  if (( n == 3 )); then
    pass "elemento: tre domande"
  else
    fail "elemento: ${n} domande"
  fi
  run command grep -rl 'example\.com' "${D05}/demo"
  if [[ -z "${OUT}" ]]; then
    pass "elemento: nessun example.com negli articoli (il canone è example.org)"
  else
    fail "elemento: ${OUT}"
  fi
}

t_readme() {
  run python3 -B -I - "${D05}/README.md" <<'PY'
import re, sys
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
for titolo in ("## Punto di partenza (tools/prepara_esercizio.sh M7-D05)",
               "## Verifica (tools/verifica.sh M7-D05)"):
    if titolo not in readme:
        problemi.append("il titolo «%s»" % titolo)
E = "https://platform.claude.com/docs/en/build-with-claude/embeddings"
C = "https://www.anthropic.com/research/contextual-retrieval"
frasi = [("Anthropic does not offer its own embedding model.", E),
         ("One embeddings provider with a wide variety of models and "
          "capabilities is Voyage AI by MongoDB.", E),
         ("RAG is a method that retrieves relevant information from a "
          "knowledge base and appends it to the user's prompt", C)]
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
  run "${RADICE}/tools/check_handson.sh"
  if grep -q 'M7-D05' <<< "${OUT}"; then
    fail "check_handson: una segnalazione su M7-D05: $(grep 'M7-D05' \
      <<< "${OUT}")"
  else
    pass "check_handson: nessuna segnalazione su M7-D05"
  fi
}

t_prepara() {
  local ws f
  if ! nuovo_ws ws; then
    fail "prepara_esercizio.sh M7-D05: $(tail -n 3 "${TMP}/prepara.log")"
    return
  fi
  pass "prepara_esercizio.sh M7-D05"
  # La demo gira su Ollama: il riepilogo non può dire che usa l'API.
  if grep -qF "lo esegue il docente" "${TMP}/prepara.log" \
      && ! grep -qF "l'API" "${TMP}/prepara.log"; then
    pass "prepara_esercizio.sh M7-D05: il riepilogo non nomina l'API"
  else
    fail "il riepilogo di M7-D05: $(tail -n 8 "${TMP}/prepara.log")"
  fi
  for f in domande.txt cerca.py controlla_risultati.py \
      articoli/art-06-addebito-ripetuto.md; do
    vero "spazio di lavoro: ${f}" test -f "${ws}/${f}"
  done
  if [[ ! -e "${ws}/soluzione" && ! -e "${ws}/_docente" ]]; then
    pass "spazio di lavoro: niente soluzione/ né _docente/"
  else
    fail "spazio di lavoro: soluzione/ o _docente/"
  fi
  run "${RADICE}/tools/verifica.sh" M7-D05 --radice "${ws%/M7-D05}"
  expect "verifica.sh sul punto di partenza: 1" 1 \
    "manca risposte/risultati.json"
}

# La progettazione delle domande, da risposte/risultati.json.
t_progetto() {
  local ws
  nuovo_ws ws || { fail "progetto: prepara_esercizio.sh"; return; }
  cerca "${ws}"
  expect "cerca: il modello e il digest" 0 \
    "Digest del modello: sha256:0000finto"
  run python3 -B -I - "${ws}/risposte/risultati.json" <<'PY'
import json, sys
dati = json.load(open(sys.argv[1], encoding="utf-8"))
d1, d2, d3 = dati["domande"]
def per_rango(d, r):
    return next(v["articolo"] for v in d["articoli"] if v[r] == 1)
problemi = []
if per_rango(d1, "rango_parole") != "art-03-password-wifi.md":
    problemi.append("d1 per parole")
if per_rango(d1, "rango_significato") != "art-03-password-wifi.md":
    problemi.append("d1 per significato")
if any(v["conteggio_parole"] for v in d2["articoli"]):
    problemi.append("d2 ha parole in comune con un articolo")
if per_rango(d2, "rango_significato") != "art-07-cambio-indirizzo.md":
    problemi.append("d2 per significato")
vincente = next(v for v in d3["articoli"] if v["rango_parole"] == 1)
if vincente["articolo"] == "art-06-addebito-ripetuto.md":
    problemi.append("d3: la ricerca per parole trova art-06")
if next(v for v in d3["articoli"] if v["articolo"]
        == "art-06-addebito-ripetuto.md")["conteggio_parole"]:
    problemi.append("d3: art-06 ha parole della domanda")
if per_rango(d3, "rango_significato") != "art-06-addebito-ripetuto.md":
    problemi.append("d3 per significato")
print("; ".join(problemi) or "domande fatte apposta")
PY
  expect "le domande: la parole trova la prima, non la seconda, sbaglia la" \
    0 "domande fatte apposta"
}

t_cerca() {
  local ws
  nuovo_ws ws || { fail "cerca: prepara_esercizio.sh"; return; }
  modo ok
  : > "${TMP}/richieste.log"
  cerca "${ws}"
  expect "cerca: 0, le classifiche affiancate" 0 "per parole"
  expect "cerca: la colonna per significato" 0 "per significato"
  expect "cerca: la domanda con le parole cercate" 0 "parole cercate:"
  expect "cerca: scrive il file" 0 "Scritto risposte/risultati.json"
  expect "cerca: dice che non è Claude" 0 "Anthropic non ha un modello"
  vero "cerca: risposte/risultati.json c'è" test -s \
    "${ws}/risposte/risultati.json"
  run python3 -B -I - "${TMP}/richieste.log" <<'PY'
import json, sys
righe = [json.loads(r) for r in open(sys.argv[1], encoding="utf-8")]
embed = [r for r in righe if r["percorso"] == "/api/embed"]
tags = [r for r in righe if r["percorso"] == "/api/tags"]
print("embed", len(embed), {r["model"] for r in embed},
      sorted(r["input"] for r in embed), "tags", len(tags))
PY
  expect "cerca: due chiamate, 12 articoli e 3 domande, con il modello" 0 \
    "embed 2 {'embeddinggemma:300m'} [3, 12] tags 1"
  run python3 -B -I - "${ws}/risposte/risultati.json" <<'PY'
import json, re, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
print("data giusta" if re.fullmatch(
    r"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z", d["data_utc"]) else d["data_utc"])
PY
  expect "risultati.json: data_utc nel formato ISO con la Z" 0 "data giusta"
  if grep -q 'utcnow' "${D05}/demo/cerca.py"; then
    fail "cerca.py: usa ancora utcnow"
  else
    pass "cerca.py: l'ora da datetime.now(timezone.utc)"
  fi
  run python3 -B -I - "${ws}/risposte/risultati.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
voce = d["domande"][0]["articoli"][0]
print(sorted(d), sorted(voce))
PY
  expect "risultati.json: i campi" 0 \
    "'conteggio_parole', 'coseno', 'rango_parole', 'rango_significato'"
}

t_guasti() {
  local ws
  nuovo_ws ws || { fail "guasti: prepara_esercizio.sh"; return; }
  run env PN_OLLAMA_URL=http://127.0.0.1:1 python3 -B -I "${ws}/cerca.py" \
    "${ws}"
  expect "guasto: Ollama che non risponde, 2" 2 "Ollama non risponde"
  vero "guasto: nessun risultato scritto" test ! -e \
    "${ws}/risposte/risultati.json"
  run env PN_OLLAMA_URL=http://example.org:11434 python3 -B -I \
    "${ws}/cerca.py" "${ws}"
  expect "host non loopback: 2" 2 "dev'essere http su questo computer"
  run env PN_OLLAMA_URL=ftp://127.0.0.1:11434 python3 -B -I "${ws}/cerca.py" \
    "${ws}"
  expect "schema non http: 2" 2 "dev'essere http su questo computer"
  local m
  for m in senza_modello:"non è fra quelli di Ollama" \
      errore_500:"Ollama ha risposto 500" \
      non_json:"non è JSON" pochi_vettori:"un vettore per ogni testo" \
      zeri:"soli zeri"; do
    modo "${m%%:*}"
    cerca "${ws}"
    expect "guasto ${m%%:*}: 2" 2 "${m#*:}"
    assente "guasto ${m%%:*}: nessun traceback" "Traceback"
  done
  modo ok
  rm -rf -- "${ws}/articoli"
  cerca "${ws}"
  expect "articoli che mancano: 2" 2 "manca la cartella degli articoli"
  nuovo_ws ws || { fail "guasti: prepara_esercizio.sh"; return; }
  : > "${ws}/domande.txt"
  cerca "${ws}"
  expect "domande vuote: 2" 2 "domande.txt è vuoto"
  rm -f -- "${ws}/domande.txt"
  cerca "${ws}"
  expect "domande che mancano: 2" 2 "domande.txt non si legge"
  run python3 -B -I "${ws}/cerca.py" "${TMP}/non-c-e"
  expect "spazio di lavoro assente: 2" 2 "spazio di lavoro assente"
  run python3 -B -I "${ws}/cerca.py" --help
  expect "un'opzione: 2" 2 "Uso:"
  run python3 -B -I "${ws}/cerca.py" "${ws}" "${ws}"
  expect "due spazi di lavoro: 2" 2 "Uso:"
}

t_verifica() {
  local ws
  run "${D05}/verifica.sh"
  expect "verifica: senza argomenti, 2" 2 "spazio di lavoro assente"
  nuovo_ws ws || { fail "verifica: prepara_esercizio.sh"; return; }
  run "${D05}/verifica.sh" "${ws}"
  expect "verifica: senza risultati, 1" 1 "manca risposte/risultati.json"
  modo ok
  cerca "${ws}"
  printf 'print("CONTROLLO FINTO")\n' > "${ws}/controlla_risultati.py" || exit 2
  run "${D05}/verifica.sh" "${ws}"
  expect "verifica: la prova fatta, 0" 0 "${FATTO}"
  expect "verifica: stampa le classifiche" 0 "per significato"
  assente "verifica: il controllo dell'elemento, non la copia" \
    "CONTROLLO FINTO"
  python3 -B -I - "${ws}/risposte/risultati.json" <<'PY' || exit 2
import json, sys
p = sys.argv[1]
d = json.load(open(p, encoding="utf-8"))
d["domande"] = d["domande"][:2]
json.dump(d, open(p, "w", encoding="utf-8"), ensure_ascii=False)
PY
  run "${D05}/verifica.sh" "${ws}"
  expect "verifica: una domanda che manca, 1" 1 "manca la domanda"
  printf '{ rotto\n' > "${ws}/risposte/risultati.json" || exit 2
  run "${D05}/verifica.sh" "${ws}"
  expect "verifica: un JSON rotto, 1" 1 "non si legge come JSON"
  assente "verifica: un JSON rotto, nessun traceback" "Traceback"
  printf '{"domande": [{"domanda": "x"}]}\n' \
    > "${ws}/risposte/risultati.json" || exit 2
  run "${D05}/verifica.sh" "${ws}"
  expect "verifica: le domande senza classifiche, 1" 1 "manca la domanda"
  rm -f -- "${ws}/domande.txt"
  run "${D05}/verifica.sh" "${ws}"
  expect "verifica: domande.txt che manca, 2" 2 "domande.txt non si legge"
}

t_live() {
  local ws
  nuovo_ws ws || { fail "live: prepara_esercizio.sh"; return; }
  modo ok
  : > "${TMP}/esca.log"
  run env PATH="${TMP}/esca:${PATH}" ESCA_LOG="${TMP}/esca.log" \
    PN_OLLAMA_URL="http://127.0.0.1:${PORTA}" HANDSON_NO_PAUSE=1 \
    "${D05}/_docente/live.sh" "${ws}"
  expect "live: l'Ollama finto, 0" 0 "VERIFICA OK   verifica.sh dell'elemento"
  expect "live: mostra il comando" 0 "python3 -B -I cerca.py"
  if [[ ! -s "${TMP}/esca.log" ]]; then
    pass "live: nessun servizio avviato, nessuna chiamata a Claude"
  else
    fail "live: $(cat "${TMP}/esca.log")"
  fi
  nuovo_ws ws || { fail "live: prepara_esercizio.sh"; return; }
  run env PN_OLLAMA_URL=http://127.0.0.1:1 HANDSON_NO_PAUSE=1 \
    "${D05}/_docente/live.sh" "${ws}"
  expect "live: Ollama che non risponde, 2" 2 "VERIFICA KO"
  run "${D05}/_docente/live.sh"
  expect "live: senza argomenti, 2" 2 "uso:"
  # La demo non usa la chiave API: per run_all.sh è un elemento trainer-local.
  run awk -F'\t' '$1 == "M7-D05" { print "env=" $3 }' \
    "${RADICE}/m7_assistenti_llm/manifest.tsv"
  expect "manifest: M7-D05 è trainer-local" 0 "env=trainer-local"
  modo ok
  run env PN_OLLAMA_URL="http://127.0.0.1:${PORTA}" HANDSON_NO_PAUSE=1 \
    "${RADICE}/tools/run_all.sh" --live M7-D05
  expect "run_all --live: l'Ollama finto, live ok" 0 "live ok"
  run env PN_OLLAMA_URL=http://127.0.0.1:1 HANDSON_NO_PAUSE=1 \
    "${RADICE}/tools/run_all.sh" --live M7-D05
  expect "run_all --live: Ollama che non risponde, SKIP" 0 \
    "live SKIP: elemento trainer-local"
  assente "run_all --live: lo SKIP non parla della chiave" "ANTHROPIC_API_KEY"
}

t_shellcheck() {
  local f
  for f in "${D05}/verifica.sh" "${D05}/_docente/live.sh" "${SELF}"; do
    if ( cd "${RADICE}" && shellcheck -x -- "${f}" ) > /dev/null 2>&1; then
      pass "shellcheck ${f#"${RADICE}"/}"
    else
      fail "shellcheck ${f#"${RADICE}"/}"
    fi
  done
}

prepara_esca() {
  local t
  mkdir -p "${TMP}/esca" || exit 2
  for t in claude ollama; do
    # shellcheck disable=SC2016  # il corpo è dell'esca
    printf '%s\n' '#!/bin/bash' \
      'printf "%s %s\n" "$0" "$*" >> "${ESCA_LOG}"' > "${TMP}/esca/${t}" \
      || exit 2
    chmod 755 "${TMP}/esca/${t}" || exit 2
  done
}

ferma_finto() {
  if [[ -n "${FINTO_PID}" ]]; then
    kill "${FINTO_PID}" 2> /dev/null
    wait "${FINTO_PID}" 2> /dev/null
  fi
}

main() {
  local t
  for t in python3 git shellcheck; do
    command -v "${t}" > /dev/null 2>&1 \
      || { echo "test_m7_d05: manca ${t}" >&2; exit 2; }
  done
  [[ -f "${FINTO_PY}" ]] \
    || { echo "test_m7_d05: manca ${FINTO_PY}" >&2; exit 2; }
  handson::init_temp_base
  TMP="$(mktemp -d "${HANDSON_TEMP_BASE}/test_m7_d05.XXXXXX")" || exit 2
  trap 'ferma_finto; chmod -R u+rwX "${TMP}" 2> /dev/null; rm -rf "${TMP}"' \
    EXIT
  prepara_esca
  avvia_finto
  t_elemento
  t_readme
  t_prepara
  t_progetto
  t_cerca
  t_guasti
  t_verifica
  t_live
  t_shellcheck
  OUT="${TUTTO}"
  assente "in nessuna uscita un traceback" "Traceback"
  assente "in nessuna uscita «smentita»" "smentita"
  echo "PASS=${PASS} FAIL=${FAIL}"
  if (( PASS + FAIL != CASES )); then
    echo "test_m7_d05: girati $((PASS + FAIL)) casi, attesi ${CASES}" >&2
    exit 2
  fi
  (( FAIL == 0 )) || exit 1
}

main "$@"
