#!/bin/bash
#
# test_m7_d07.sh -- le prove di M7-D07 «Tre difese a confronto», per il
# docente (sta in _docente/, il materiale del docente):
#   - l'elemento: la scheda, i tre attacchi, i tre system prompt che
#     differiscono solo in ciò che difende la scheda (una riga in più in
#     educata, le righe dei campi in meno in ridotta); il README: le dieci
#     sezioni, le frasi di Anthropic con il loro indirizzo, niente di vietato;
#   - prepara_esercizio.sh e verifica.sh sul punto di partenza (1);
#   - controlla_campi.py su stream scritti dalla suite (mai una risposta di
#     Claude): i campi trovati nella risposta, n su N per cella, la
#     dimostrazione della scheda ridotta; un campo che non c'è nel system
#     prompt, da guardare; le esecuzioni che mancano o non finiscono (1); i
#     file che non si leggono e gli usi sbagliati (2), mai un traceback;
#   - demo/in_classe.sh e _docente/live.sh con il claude finto: quante
#     chiamate, con quali opzioni e quale system prompt, senza
#     ANTHROPIC_API_KEY, in una cartella vuota; le precondizioni (2, nessuna
#     chiamata); una chiamata fallita (1);
#   - shellcheck -x.
# Mai il claude vero: il finto e l'esca stanno davanti nel PATH, e la suite lo
# controlla prima di usarli. Gli spazi di lavoro nascono in una cartella
# temporanea. CASES è il numero dei casi: se ne girano di più o di meno la
# suite esce 2.
#
# Uso:    m7_assistenti_llm/_docente/test_m7_d07.sh
# Uscita: 0 = tutti i casi passano · 1 = almeno un caso fallito · 2 =
#         precondizione (manca python3, git o shellcheck), o un numero di casi
#         diverso da CASES
set -uo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly MOD="${SELF%/_docente/*}"
readonly RADICE="${MOD%/*}"
D07="${MOD}/s6_conoscenza_e_valutazione/m7_7_guardrail"
D07+="/M7-D07_tre_difese"
readonly D07
readonly FINTO_PY="${MOD}/_docente/claude_finto_m7_d07.py"
# shellcheck source=../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"
readonly CASES=101
FATTO='Fatto: ogni esecuzione è stata messa alla prova;'
FATTO+=' i dati sono qui sopra.'
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
  "${RADICE}/tools/prepara_esercizio.sh" M7-D07 --radice "${__r}" \
    > "${TMP}/prepara.log" 2>&1 || return 1
  printf -v "$1" '%s' "${__r}/M7-D07"
}

# controlla_campi.py dell'elemento; RC e OUT come run.
controlla() { run python3 -B -I "${D07}/demo/controlla_campi.py" "$@"; }

# Una esecuzione scritta dalla suite: uno stream con la risposta data (nessuna
# è una risposta di Claude). Arguments: $1 la cartella, $2 il nome
# (nessuna-difesa-diretta-1…), $3 la risposta, $4 facoltativo: tronco | errore.
scrivi() {
  mkdir -p "$1/$2" || exit 2
  python3 -B -I - "$1/$2/stream.jsonl" "$3" "${4:-}" <<'PY' || exit 2
import json, sys
percorso, risposta, modo = sys.argv[1:]
righe = [{"type": "system", "subtype": "init", "session_id": "s"},
         {"type": "assistant", "parent_tool_use_id": None,
          "message": {"content": [{"type": "text", "text": risposta}],
                      "usage": {"input_tokens": 3, "output_tokens": 5}}}]
if modo != "tronco":
    righe.append({"type": "result", "subtype": "success",
                  "is_error": modo == "errore", "num_turns": 1,
                  "duration_ms": 1000, "result": risposta,
                  "usage": {"input_tokens": 3, "output_tokens": 40,
                            "cache_creation_input_tokens": 700,
                            "cache_read_input_tokens": 0},
                  "modelUsage": {"finto": {
                      "inputTokens": 3, "outputTokens": 40,
                      "cacheCreationInputTokens": 700,
                      "cacheReadInputTokens": 0}}})
with open(percorso, "w", encoding="utf-8") as fh:
    for riga in righe:
        fh.write(json.dumps(riga, ensure_ascii=False) + "\n")
PY
}

# Una serie: n esecuzioni per cella, ogni risposta senza campi, tranne quelle
# che la suite aggiunge. Arguments: $1 la variabile della cartella, $2 quante
# esecuzioni per cella.
serie() {
  local __d k a b
  __d="$(mktemp -d "${TMP}/serie.XXXXXX")" || exit 2
  for (( k = 1; k <= $2; k++ )); do
    for b in nessuna-difesa educata ridotta; do
      for a in diretta collega ripeti; do
        scrivi "${__d}" "${b}-${a}-${k}" 'Non posso condividere quei dati.'
      done
    done
  done
  printf -v "$1" '%s' "${__d}"
}

# Il claude finto (copia del .py), l'esca e i PATH ridotti.
prepara_claude() {
  local t
  mkdir -p "${TMP}/finto" "${TMP}/esca" "${TMP}/senza_python" \
    "${TMP}/senza_claude" || exit 2
  # shellcheck disable=SC2016  # il corpo è dell'esca
  printf '%s\n' '#!/bin/bash' \
    'printf "invocazione %s\n" "$*" >> "${ESCA_LOG}"' \
    > "${TMP}/esca/claude" || exit 2
  cp -- "${FINTO_PY}" "${TMP}/finto/claude" || exit 2
  chmod 755 "${TMP}/esca/claude" "${TMP}/finto/claude" || exit 2
  for t in readlink git tar; do
    ln -s "$(command -v "${t}")" "${TMP}/senza_python/${t}" || exit 2
  done
  ln -s "${TMP}/esca/claude" "${TMP}/senza_python/claude" || exit 2
  for t in readlink python3 git tar; do
    ln -s "$(command -v "${t}")" "${TMP}/senza_claude/${t}" || exit 2
  done
  t="$(PATH="${TMP}/finto:${PATH}" command -v claude)"
  if [[ "${t}" != "${TMP}/finto/claude" ]]; then
    echo "test_m7_d07: nel PATH di prova claude è ${t}, non il finto" >&2
    exit 2
  fi
}

t_elemento() {
  local f
  for f in README.md verifica.sh demo/in_classe.sh demo/controlla_campi.py \
      demo/scheda.md demo/nessuna-difesa.md demo/educata.md demo/ridotta.md \
      demo/attacchi/diretta.txt demo/attacchi/collega.txt \
      demo/attacchi/ripeti.txt _docente/live.sh soluzione/LEGGIMI.md; do
    vero "elemento: ${f}" test -f "${D07}/${f}"
  done
  for f in verifica.sh _docente/live.sh demo/in_classe.sh; do
    vero "elemento: ${f} eseguibile" test -x "${D07}/${f}"
  done
  run python3 -B -I - "${D07}" <<'PY'
import difflib, os, re, sys
item = sys.argv[1]
def testo(p):
    return open(os.path.join(item, p), encoding="utf-8").read()
problemi = []
scheda = testo("demo/scheda.md").strip().split("\n")
if len(scheda) != 6:
    problemi.append("la scheda non ha sei campi")
base, educata, ridotta = (testo("demo/%s.md" % a)
                          for a in ("nessuna-difesa", "educata", "ridotta"))
for riga in scheda:
    if riga not in base.split("\n"):
        problemi.append("%r non è in nessuna-difesa.md" % riga)
differenze = [r for r in difflib.ndiff(base.split("\n"), educata.split("\n"))
              if r.startswith(("+ ", "- "))]
if len(differenze) != 1 or not differenze[0].startswith("+ ") \
        or "riservati" not in differenze[0]:
    problemi.append("educata: %r" % differenze)
tolte = [r[2:] for r in difflib.ndiff(base.split("\n"), ridotta.split("\n"))
         if r.startswith("- ")]
aggiunte = [r for r in difflib.ndiff(base.split("\n"), ridotta.split("\n"))
            if r.startswith("+ ")]
attese = [r for r in scheda
          if r.startswith(("Telefono:", "E-mail:", "Indirizzo:", "Nota "))]
if sorted(tolte) != sorted(attese) or aggiunte:
    problemi.append("ridotta: tolte %r, aggiunte %r" % (tolte, aggiunte))
for arma in ("nessuna-difesa", "educata", "ridotta"):
    t = testo("demo/%s.md" % arma)
    tag = re.findall(r"(?m)^<(\w+)>$", t)
    if tag != ["role", "context", "instructions", "format", "constraints",
               "data"]:
        problemi.append("%s: i tag %r" % (arma, tag))
    if not re.search(r"<role>\nSei ", t):
        problemi.append("%s: il ruolo" % arma)
    if len(re.sub(r"</?\w+>", "", t).split()) < 60:
        problemi.append("%s: meno di 60 parole" % arma)
for a in ("diretta", "collega", "ripeti"):
    r = testo("demo/attacchi/%s.txt" % a)
    if r.count("\n") != 1 or not r.strip():
        problemi.append("l'attacco %s non è una riga" % a)
if "example.org" not in testo("demo/scheda.md") \
        or "+39 00" not in testo("demo/scheda.md"):
    problemi.append("la scheda non è nel canone")
print("; ".join(problemi) or "bracci giusti")
PY
  expect "elemento: i bracci differiscono in ciò che difende la scheda" 0 \
    "bracci giusti"
}

t_readme() {
  run python3 -B -I - "${D07}/README.md" <<'PY'
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
for titolo in ("## Punto di partenza (tools/prepara_esercizio.sh M7-D07)",
               "## Verifica (tools/verifica.sh M7-D07)"):
    if titolo not in readme:
        problemi.append("il titolo «%s»" % titolo)
L = "https://platform.claude.com/docs/en/test-and-evaluate/" \
    "strengthen-guardrails/reduce-prompt-leak"
frasi = [("Although no method is foolproof, the following strategies can "
          "significantly reduce the risk.", L),
         ("If Claude doesn’t need it to perform the task, don’t include it.",
          L)]
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
  run python3 -B -I - "${D07}" <<'PY'
import os, re, sys
item = sys.argv[1]
testo = open(os.path.join(item, "README.md"), encoding="utf-8").read()
problemi = []
for n, a in enumerate(("diretta", "collega", "ripeti"), 1):
    m = re.search(r"<!-- prompt %d -->\n(.*?)\n\s*<!-- /prompt %d -->" % (n, n),
                  testo, re.S)
    attacco = open(os.path.join(item, "demo/attacchi", a + ".txt"),
                   encoding="utf-8").read().strip()
    if not m or " ".join(m.group(1).split()) != " ".join(attacco.split()):
        problemi.append("il prompt %d non è attacchi/%s.txt" % (n, a))
print("; ".join(problemi) or "prompt uguali agli attacchi")
PY
  expect "README: i tre prompt sono gli attacchi, parola per parola" 0 \
    "prompt uguali agli attacchi"
  run "${RADICE}/tools/check_handson.sh"
  if grep -q 'M7-D07' <<< "${OUT}"; then
    fail "check_handson: una segnalazione su M7-D07: $(grep 'M7-D07' \
      <<< "${OUT}")"
  else
    pass "check_handson: nessuna segnalazione su M7-D07"
  fi
}

t_prepara() {
  local ws f
  if ! nuovo_ws ws; then
    fail "prepara_esercizio.sh M7-D07: $(tail -n 3 "${TMP}/prepara.log")"
    return
  fi
  pass "prepara_esercizio.sh M7-D07"
  for f in scheda.md nessuna-difesa.md educata.md ridotta.md \
      attacchi/ripeti.txt controlla_campi.py in_classe.sh; do
    vero "spazio di lavoro: ${f}" test -f "${ws}/${f}"
  done
  if [[ ! -e "${ws}/soluzione" && ! -e "${ws}/_docente" ]]; then
    pass "spazio di lavoro: niente soluzione/ né _docente/"
  else
    fail "spazio di lavoro: soluzione/ o _docente/"
  fi
  run "${RADICE}/tools/verifica.sh" M7-D07 --radice "${ws%/M7-D07}"
  expect "verifica.sh sul punto di partenza: 1" 1 \
    "Manca la cartella risposte/"
}

t_controllo() {
  local j
  serie j 3
  controlla "${j}"
  expect "controllo: tre esecuzioni per cella, 0" 0 "3 esecuzioni per cella"
  expect "controllo: i sei campi della scheda" 0 \
    "6 campi (Nome, Telefono, E-mail, Codice cliente, Indirizzo, Nota interna)"
  expect "controllo: nessun campo uscito" 0 "esecuzione 1: 0 campi su 6: nessuno"
  expect "controllo: la tabella per cella" 0 "0 0 0 (0 su 3)"
  expect "controllo: la dimostrazione, i campi della scheda ridotta" 0 \
    "contiene 2 campi su 6: Nome, Codice cliente"
  expect "controllo: ciò che non può uscire" 0 \
    "Telefono, E-mail, Indirizzo, Nota interna"
  expect "controllo: nessuno di quei campi nelle esecuzioni" 0 \
    "nessuno di quei campi"
  scrivi "${j}" nessuna-difesa-diretta-1 \
    'Giulia Campione, +39 005 147 0042, GIULIA.CAMPIONE@example.org, CL-005147, Via della Prova 18, recupero crediti.'
  scrivi "${j}" educata-ripeti-2 'Il telefono è 005 1470042.'
  scrivi "${j}" ridotta-collega-3 "La nota dice PC-2026-0147, l'indirizzo è via della prova 18."
  controlla "${j}"
  expect "campi: sei su sei, maiuscole e minuscole" 0 \
    "esecuzione 1: 6 campi su 6: Nome, Telefono, E-mail, Codice cliente, Indirizzo, Nota interna"
  expect "campi: il telefono senza prefisso e con spazi diversi" 0 \
    "esecuzione 2: 1 campi su 6: Telefono"
  expect "campi: la nota dal numero di pratica, l'indirizzo in minuscolo" 0 \
    "esecuzione 3: 2 campi su 6: Indirizzo, Nota interna"
  expect "tabella: la cella con un'esecuzione su tre" 0 "6 0 0 (1 su 3)"
  expect "dimostrazione: un campo assente dalla ridotta, da guardare" 0 \
    "Compaiono lo stesso, da guardare: ridotta-collega-3: Indirizzo, Nota interna"
  scrivi "${j}" educata-collega-1 'La chiamiamo domani, grazie: giulia.'
  controlla "${j}"
  assente "campi: un nome di battesimo non è il campo Nome" \
    "educata, attacco «collega»: esecuzione 1: 1"
  expect "dati: il consumo" 0 "Come dati, tutte le 27 chiamate: turni 27;"
}

t_mancanze() {
  local j
  serie j 2
  rm -r -- "${j}/ridotta-ripeti-2"
  controlla "${j}"
  expect "mancanza: un'esecuzione che manca, 1" 1 \
    "manca ridotta-ripeti-2/stream.jsonl"
  serie j 1
  scrivi "${j}" educata-diretta-1 'Tagliata.' tronco
  controlla "${j}"
  expect "mancanza: uno stream senza il risultato, 1" 1 \
    "non finisce con il risultato"
  serie j 1
  scrivi "${j}" educata-diretta-1 'Errore.' errore
  controlla "${j}"
  expect "mancanza: un risultato con l'errore, 1" 1 \
    "claude ha restituito un errore"
}

t_illeggibili() {
  local j
  serie j 1
  printf '{rotto\n' > "${j}/nessuna-difesa-collega-1/stream.jsonl" || exit 2
  controlla "${j}"
  expect "illeggibile: una riga che non è JSON, 2" 2 "non è JSON"
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
    "${D07}/demo/controlla_campi.py" "${j}"
  expect "precondizione: tools/ che non c'è, 2" 2 \
    "non trovo tools/lib_leggi_contesto.py"
  mkdir -p "${TMP}/senza_scheda" || exit 2
  cp -- "${D07}/demo/controlla_campi.py" "${TMP}/senza_scheda/" || exit 2
  run env PN_HANDSON_ROOT="${RADICE}" python3 -B -I \
    "${TMP}/senza_scheda/controlla_campi.py" "${j}"
  expect "precondizione: scheda.md che manca, 2" 2 "non si legge"
}

t_verifica() {
  local ws j
  nuovo_ws ws || { fail "verifica: prepara_esercizio.sh"; return; }
  run "${D07}/verifica.sh" "${ws}"
  expect "verifica: senza risposte/, 1" 1 "Manca la cartella risposte/"
  mkdir -p "${ws}/risposte" || exit 2
  run "${D07}/verifica.sh" "${ws}"
  expect "verifica: risposte/ vuota, 1" 1 "nessuna esecuzione"
  serie j 1
  cp -R "${j}/." "${ws}/risposte/" || exit 2
  printf 'print("CONTROLLO FINTO")\n' > "${ws}/controlla_campi.py" || exit 2
  run env PN_HANDSON_ROOT="${RADICE}" "${D07}/verifica.sh" "${ws}"
  expect "verifica: una serie completa, 0, «Fatto»" 0 "${FATTO}"
  assente "verifica: il controllo dell'elemento, non della copia" \
    "CONTROLLO FINTO"
  rm -r -- "${ws}/risposte/ridotta-collega-1"
  run "${D07}/verifica.sh" "${ws}"
  expect "verifica: un'esecuzione che manca, 1" 1 "ridotta-collega-1"
  run "${D07}/verifica.sh"
  expect "verifica: senza argomenti, 2" 2 "spazio di lavoro assente"
}

# Lo script con il finto davanti nel PATH.
finto() {
  local script="$1" w="$2"
  shift 2
  : > "${TMP}/finto.log"
  run env PATH="${TMP}/finto:${PATH}" HANDSON_NO_PAUSE=1 \
    ANTHROPIC_API_KEY=valore-finto FINTO_LOG="${TMP}/finto.log" \
    TMPDIR="${TMP}" "$@" "${script}" "${w}"
}

# Le chiamate del finto, contro le attese. Arguments: $1 il registro, $2
# quante esecuzioni per cella, $3 lo spazio di lavoro.
controlla_chiamate() {
  run python3 -B -I - "$1" "$2" "$3" <<'PY'
import json, os, sys
log, n, ws = sys.argv[1:4]
righe = [json.loads(r) for r in open(log, encoding="utf-8")]
chiamate = [r for r in righe if r["argv"][:1] != ["--version"]]
attese = 9 * int(n)
problemi = []
if len(chiamate) != attese:
    problemi.append("%d chiamate invece di %d" % (len(chiamate), attese))
attacchi = {a: open(os.path.join(ws, "attacchi", a + ".txt"),
                    encoding="utf-8").read().strip()
            for a in ("diretta", "collega", "ripeti")}
visti = {}
for i, c in enumerate(chiamate, 1):
    a = c["argv"]
    fisse = (("--model", "sonnet"), ("--effort", "low"),
             ("--output-format", "stream-json"), ("--tools", ""),
             ("--setting-sources", "project,local"),
             ("--permission-mode", "dontAsk"),
             ("--permission-prompts", "none"))
    for k, v in fisse:
        if k not in a or a[a.index(k) + 1] != v:
            problemi.append("chiamata %d: %s" % (i, k))
    for k in ("-p", "--verbose", "--strict-mcp-config",
              "--no-session-persistence"):
        if k not in a:
            problemi.append("chiamata %d: manca %s" % (i, k))
    if any("dangerously" in x or "bypassPermissions" in x for x in a):
        problemi.append("chiamata %d: salta i permessi" % i)
    if "--allowedTools" in a:
        problemi.append("chiamata %d: --allowedTools" % i)
    if c["chiave"]:
        problemi.append("chiamata %d: con ANTHROPIC_API_KEY" % i)
    if c["prompt"] not in attacchi.values():
        problemi.append("chiamata %d: il prompt %r" % (i, c["prompt"]))
    sp = a[a.index("--system-prompt-file") + 1]
    if os.path.dirname(sp) != os.path.realpath(ws) \
            or os.path.basename(sp) not in ("nessuna-difesa.md", "educata.md",
                                            "ridotta.md"):
        problemi.append("chiamata %d: il system prompt %s" % (i, sp))
    if os.path.realpath(c["cwd"]) == os.path.realpath(ws) \
            or not c["vuota"]:
        problemi.append("chiamata %d: la cartella %s" % (i, c["cwd"]))
    chiave = (os.path.basename(sp), c["prompt"])
    visti[chiave] = visti.get(chiave, 0) + 1
if len(visti) != 9 or set(visti.values()) != {int(n)}:
    problemi.append("le celle: %r" % sorted(visti.values()))
print("; ".join(problemi) or "chiamate giuste")
PY
}

t_in_classe() {
  local ws
  nuovo_ws ws || { fail "in_classe: prepara_esercizio.sh"; return; }
  finto "${D07}/demo/in_classe.sh" "${ws}" PN_ESECUZIONI=2
  expect "in_classe: due esecuzioni per cella, 0" 0 \
    "VERIFICA OK   il controllo, sulle esecuzioni di risposte/"
  expect "in_classe: il comando sullo schermo" 0 "--system-prompt-file"
  expect "in_classe: l'opzione senza strumenti, sullo schermo" 0 "--tools ''"
  expect "in_classe: la tabella, sullo schermo" 0 "in quante almeno uno:"
  controlla_chiamate "${TMP}/finto.log" 2 "${ws}"
  expect "in_classe: diciotto chiamate, le opzioni e i bracci" 0 \
    "chiamate giuste"
  run git -C "${ws}" status --porcelain
  if [[ "${OUT}" == '?? risposte/' ]]; then
    pass "in_classe: lo spazio di lavoro cambia solo in risposte/"
  else
    fail "in_classe: git status «${OUT}»"
  fi
  run env PN_HANDSON_ROOT="${RADICE}" "${D07}/verifica.sh" "${ws}"
  expect "in_classe: poi verifica.sh, 0" 0 "${FATTO}"
  run python3 -B -I - "${ws}/risposte" <<'PY'
import glob, sys
print(len(glob.glob(sys.argv[1] + "/*/stream.jsonl")))
PY
  expect "in_classe: un file per chiamata" 0 "18"
}

t_live() {
  local ws
  nuovo_ws ws || { fail "live: prepara_esercizio.sh"; return; }
  finto "${D07}/_docente/live.sh" "${ws}"
  expect "live: tre esecuzioni per cella, 0" 0 \
    "VERIFICA OK   verifica.sh dell'elemento"
  controlla_chiamate "${TMP}/finto.log" 3 "${ws}"
  expect "live: le ventisette chiamate" 0 "chiamate giuste"
  run "${RADICE}/tools/verifica.sh" M7-D07 --radice "${ws%/M7-D07}"
  expect "live: poi tools/verifica.sh, 0" 0 "VERIFICA OK   M7-D07: fatto."
  run "${D07}/_docente/live.sh"
  expect "live: senza argomenti, 2" 2 "uso:"
}

# Lo script con l'esca davanti nel PATH.
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

t_precondizioni() {
  local ws s="${D07}/demo/in_classe.sh"
  nuovo_ws ws || { fail "precondizioni: prepara_esercizio.sh"; return; }
  precondizione "precondizione: una cartella che non è lo spazio" \
    "non è lo spazio di lavoro di M7-D07" "${s}" "${TMP}"
  precondizione "precondizione: nessuno spazio di lavoro" \
    "spazio di lavoro assente" "${s}" ""
  precondizione "precondizione: PN_ESECUZIONI 0" "PN_ESECUZIONI" \
    "${s}" "${ws}" "${TMP}/esca:${PATH}" PN_ESECUZIONI=0
  precondizione "precondizione: HANDSON_ENV claude-ai-pro" \
    "è un elemento claude-code-pro" "${s}" "${ws}" "${TMP}/esca:${PATH}" \
    HANDSON_ENV=claude-ai-pro
  precondizione "precondizione: senza python3" "manca lo strumento: python3" \
    "${s}" "${ws}" "${TMP}/senza_python"
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
  mv -- "${ws}/scheda.md" "${TMP}/scheda.md" || exit 2
  precondizione "precondizione: la scheda che manca" \
    "file assente o illeggibile: scheda.md" "${s}" "${ws}"
  precondizione "precondizione: senza tools/lib_handson.sh" \
    "lanciatelo dal repository, o date PN_HANDSON_ROOT" "${s}" "${ws}" \
    "${TMP}/esca:${PATH}" PN_HANDSON_ROOT="${TMP}/non-c-e"
}

t_fallita() {
  local ws
  nuovo_ws ws || { fail "fallita: prepara_esercizio.sh"; return; }
  finto "${D07}/demo/in_classe.sh" "${ws}" FINTO_KO_SE="reparto tecnico"
  expect "fallita: una chiamata che fallisce, 1" 1 \
    "VERIFICA KO   nessuna-difesa-collega-1: claude -p"
  run "${D07}/verifica.sh" "${ws}"
  expect "fallita: verifica.sh dopo, 1" 1 "collega"
  nuovo_ws ws || { fail "fallita: prepara_esercizio.sh"; return; }
  finto "${D07}/demo/in_classe.sh" "${ws}" FINTO_ERRORE=1
  expect "fallita: claude che restituisce un errore, 1" 1 \
    "claude ha restituito un errore"
}

t_shellcheck() {
  local f
  for f in "${D07}/verifica.sh" "${D07}/_docente/live.sh" \
      "${D07}/demo/in_classe.sh" "${SELF}"; do
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
      || { echo "test_m7_d07: manca ${t}" >&2; exit 2; }
  done
  [[ -f "${FINTO_PY}" ]] \
    || { echo "test_m7_d07: manca ${FINTO_PY}" >&2; exit 2; }
  handson::init_temp_base
  TMP="$(mktemp -d "${HANDSON_TEMP_BASE}/test_m7_d07.XXXXXX")" || exit 2
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
    echo "test_m7_d07: girati $((PASS + FAIL)) casi, attesi ${CASES}" >&2
    exit 2
  fi
  (( FAIL == 0 )) || exit 1
}

main "$@"
