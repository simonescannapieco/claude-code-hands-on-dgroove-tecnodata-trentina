#!/bin/bash
#
# test_m1_d05.sh -- le prove di M1-D05, la circolare che non esiste, per il
# docente (sta in _docente/, fuori dalla copia dei partecipanti). Nessun
# modello viene chiamato:
#   - controlla_citazioni.py, su risposte sintetiche scritte qui: le
#     regole del confronto (un'omissione che divide una citazione in pezzi,
#     «» “” e "", la maiuscola della sola prima lettera, una citazione
#     presa dalla domanda della chiamata e non dall'altra, NON NEL
#     DOCUMENTO tra «» che non è una citazione, apostrofi, trattini e
#     asterischi tipografici, la punteggiatura in fondo, un pezzo o una
#     frase di meno di tre parole, 1.200 e 1200, gli zeri davanti, 10 e
#     2010); ogni ramo dei tre verdetti (il terzo confronta i numeri
#     estranei con e senza le regole: meno, quanti, di più, nessuno senza;
#     i due conteggi si stampano); esiti.tsv;
#   - i dati malformati: file vuoto, JSON non valido o annidato oltre il
#     limite di Python, un JSON che non è un oggetto, is_error vero o
#     assente, result assente, vuoto o non testo, la risposta di un altro
#     modello, una risposta mancante, nessuna risposta (uscita 1); un testo
#     non UTF-8, la circolare che manca accanto al controllo, esiti.tsv che
#     non si scrive, un argomento sbagliato, un errore che il controllo non
#     prevede (os.path.isdir che solleva: uscita 2, una riga); un surrogato
#     isolato (uscita 0); mai un traceback;
#   - verifica.sh: spazio di lavoro assente (2), punto di partenza (1, con
#     il suo messaggio), le dodici risposte (0, con la frase finale come
#     ultima riga e senza scrivere niente), una raccomandazione non
#     confermata (0: non è una garanzia), una risposta incompleta (1), la
#     circolare dell'elemento e non la copia dello spazio di lavoro, un
#     file dei risultati o risposte/ che non si leggono (2; saltate da
#     root); un python3 finto che esce 3 o muore di SIGTERM (2, con un
#     messaggio, mai 1);
#   - live.sh con un claude finto davanti nel PATH, che registra ogni
#     chiamata: le precondizioni (spazio di lavoro assente, un file che
#     manca, la modalità di permesso) escono 2 senza chiamare il modello;
#     le dodici chiamate mandano il messaggio, l'istruzione di sistema e le
#     opzioni che manda il registratore del corso, gli stessi dei passi del
#     README, eseguiti qui con lo stesso claude finto; i nove verdetti
#     confermati; una chiamata fallita esce 1;
#   - i file della demo: richiesta.txt e istruzione.txt come sempre
#     (sha256), prova-claude-ai.md fatto delle regole, della circolare e
#     della domanda B, leggi_json.py uguale a quello di M1-D04, le due
#     sottosezioni di «Che cosa osservare» nel README; il README che cita
#     «scrivi soltanto» di regole.txt e dà, come dato, quante risposte B
#     con le regole sono la sola frase;
#   - shellcheck -x su verifica.sh, live.sh e questo file; il controllo
#     compila con -W error.
# Il numero di prove eseguite (anche quelle saltate) deve essere CASES.
# Il file supera le 800 righe per scelta: il claude finto e i due aiuti in
# Python (il confronto con il registratore, i passi del README) stanno qui
# dentro, così la suite non dipende da altri file.
#
# Uso:    m1_fondamenti_llm/_docente/test_m1_d05.sh
# Uscita: 0 = tutte le prove passano · 1 = almeno una fallita
#         2 = precondizione (manca jq, python3, shellcheck, sha256sum o
#             cmp, o un file dell'elemento; il claude finto non è il primo
#             nel PATH; il numero di prove eseguite non è CASES)
set -uo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly MOD="${SELF%/_docente/*}"
readonly S1="${MOD}/s1_fondamenti_llm"
readonly ITEM="${S1}/m1_4_forze_e_limiti/M1-D05_circolare"
readonly D04="${S1}/m1_3_token_e_contesto/M1-D04_senza_memoria"
readonly DEMO="${ITEM}/demo"
readonly CHECK="${DEMO}/controlla_citazioni.py"
readonly VERIFICA="${ITEM}/verifica.sh"
readonly LIVE="${ITEM}/_docente/live.sh"
readonly README="${ITEM}/README.md"
readonly CASES=104
readonly MODELLI=(haiku sonnet opus)
FATTO='Fatto: ogni affermazione è stata messa alla prova; gli esiti sono'
FATTO+=' qui sopra.'
readonly FATTO
readonly NC='non confermata in questa esecuzione'
PUNTO_1='Dal 1° marzo 2025 ogni attivazione FWA si chiude entro 10 giorni'
PUNTO_1+=' lavorativi dalla firma del contratto.'
readonly PUNTO_1
SHA_RICHIESTA='e21d6993180552a5f93dc3d33519f5d3'
SHA_RICHIESTA+='7d0526065e0454dff9722ab6a5ba38b2'
readonly SHA_RICHIESTA
SHA_ISTRUZIONE='35631d2b7804e18072204a1d31bcb4da'
SHA_ISTRUZIONE+='e62df2a21ad9c6b3dbc2015143ace6ea'
readonly SHA_ISTRUZIONE
# Una barra rovescia: le sequenze di escape dei JSON si compongono qui.
readonly BS=$'\x5c'
TMP=''
LOG=''
PASS=0
FAIL=0
SKIP=0
RC=0
OUT=''

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }
salta() { echo "  SKIP: $1"; SKIP=$((SKIP + 1)); }

# Esegue un comando; RC e OUT (STDOUT e STDERR insieme) per expect.
run() { OUT="$("$@" 2>&1)"; RC=$?; }

# Uscita attesa E parola attesa (RU-01.T3), e nessun traceback di Python.
# Arguments: $1 il nome, $2 l'uscita attesa, $3 la parola (grep -F).
expect() {
  if (( RC == $2 )) && grep -qF -- "$3" <<< "${OUT}" \
      && ! grep -qF -- 'Traceback (most recent call last)' <<< "${OUT}"
  then
    pass "$1"
  else
    fail "$1 (rc=${RC}, attesa $2, parola «$3»): ${OUT:0:400}"
  fi
}

# Un valore uguale a quello atteso.
# Arguments: $1 il nome, $2 il valore, $3 il valore atteso.
expect_eq() {
  if [[ "$2" == "$3" ]]; then
    pass "$1"
  else
    fail "$1: «$2», atteso «$3»"
  fi
}

# Un nuovo spazio di lavoro, con il contenuto di una cartella se indicata.
# Arguments: $1 la variabile da assegnare, $2 (facoltativo) la cartella.
ws() {
  local __w
  __w="$(mktemp -d "${TMP}/ws.XXXXXX")" || { echo "mktemp" >&2; exit 2; }
  if [[ -n "${2:-}" ]]; then
    cp -R "$2/." "${__w}/"
  fi
  printf -v "$1" '%s' "${__w}"
}

# Il JSON di una risposta riuscita, in <spazio>/risposte/<nome>.json.
# Arguments: $1 lo spazio di lavoro, $2 il nome (A-regole-haiku), $3 la
#   risposta, $4 (facoltativo) il modello nel JSON.
risposta() {
  mkdir -p "$1/risposte"
  jq -n --arg r "$3" --arg m "${4:-claude-${2##*-}-prova}" \
    '{type: "result", subtype: "success", is_error: false, result: $r,
      modelUsage: {($m): {}}}' > "$1/risposte/$2.json"
}

# Un file di risposta scritto così com'è.
# Arguments: $1 lo spazio di lavoro, $2 il nome, $3 il contenuto.
grezza() {
  mkdir -p "$1/risposte"
  printf '%s' "$3" > "$1/risposte/$2.json"
}

# Le dodici risposte di riferimento: ogni affermazione confermata.
# Arguments: $1 lo spazio di lavoro.
dodici() {
  local m
  for m in "${MODELLI[@]}"; do
    risposta "$1" "A-senza-${m}" 'Entro 10 giorni lavorativi dalla firma.'
    risposta "$1" "A-regole-${m}" "Entro 10 giorni lavorativi: «${PUNTO_1}»"
    risposta "$1" "B-senza-${m}" 'La n. 7/2025 chiede 30 giorni e 49 euro.'
    risposta "$1" "B-regole-${m}" 'NON NEL DOCUMENTO'
  done
}

# Le dodici risposte di riferimento con una cambiata, poi il controllo come
# lo lanciano i partecipanti (scrive esiti.tsv).
# Arguments: $1 la variabile dello spazio di lavoro, $2 il nome della
#   risposta, $3 il suo testo.
con_risposta() {
  local __c
  ws __c
  dodici "${__c}"
  risposta "${__c}" "$2" "$3"
  run python3 -B -I "${CHECK}" "${__c}"
  printf -v "$1" '%s' "${__c}"
}

# Un campo di esiti.tsv, per nome di colonna.
# Arguments: $1 lo spazio di lavoro, $2 la risposta (A-regole-haiku), $3 la
#   colonna. Outputs: il valore, vuoto se manca.
campo() {
  local d v m
  IFS=- read -r d v m <<< "$2"
  awk -F'\t' -v d="${d}" -v v="${v}" -v m="${m}" -v c="$3" '
    NR == 1 { for (i = 1; i <= NF; i++) if ($i == c) k = i; next }
    k && $1 == d && $2 == v && $3 == m { print $k }' "$1/esiti.tsv"
}

# Citazioni e ritrovate di una risposta in esiti.tsv, come «n/m».
# Arguments: $1 lo spazio di lavoro, $2 la risposta.
cit() {
  printf '%s/%s' "$(campo "$1" "$2" citazioni)" "$(campo "$1" "$2" ritrovate)"
}

# La riga del verdetto di un'affermazione, come la stampa il controllo.
# Arguments: $1 il modello, $2 l'affermazione (1, 2, 3), $3 l'esito.
verdetto() {
  local a='citazioni verificabili (A, con le regole)'
  if [[ "$2" == 2 ]]; then
    a='la frase concordata e nessun numero estraneo (B, con le regole)'
  elif [[ "$2" == 3 ]]; then
    a='meno numeri estranei con le regole (B)'
  fi
  printf '  %s, %s: %s' "$1" "${a}" "$3"
}

# Le dodici risposte di riferimento con una scritta così com'è, poi il
# controllo: uscita 1 con la parola attesa.
# Arguments: $1 il nome della prova, $2 la risposta, $3 il contenuto, $4
#   la parola attesa.
malformata() {
  local w
  ws w
  dodici "${w}"
  grezza "${w}" "$2" "$3"
  run python3 -B -I "${CHECK}" "${w}"
  expect "$1" 1 "$4"
}

# Esegue un comando in una cartella.
# Arguments: $1 la cartella, poi il comando.
in_cartella() { ( cd "$1" && shift && "$@" ); }

# Il controllo con un errore che non prevede: os.path.isdir solleva
# ZeroDivisionError sullo spazio di lavoro, e il controllo gira come
# script (__main__). Arguments: $1 il controllo, $2 lo spazio di lavoro.
guasto() {
  run python3 -B -I - "$1" "$2" <<'PY'
import os
import runpy
import sys

controllo, ws = sys.argv[1:3]
vero = os.path.isdir
os.path.isdir = lambda p: 1 / 0 if p == ws else vero(p)
sys.argv = [controllo, ws]
runpy.run_path(controllo, run_name="__main__")
PY
}

# live.sh con il claude finto davanti nel PATH; il registro delle chiamate
# riparte vuoto. Arguments: $1 lo spazio di lavoro (vuoto: nessuno), poi
# le variabili NOME=valore.
live() {
  local w="$1"
  local -a argomenti=()
  shift
  if [[ -n "${w}" ]]; then
    argomenti=("${w}")
  fi
  : > "${LOG}"
  run env PATH="${TMP}/bin:${PATH}" HANDSON_NO_PAUSE=1 FINTO_LOG="${LOG}" \
    "$@" "${LIVE}" ${argomenti[@]+"${argomenti[@]}"}
}

# Il claude finto non è stato lanciato, nemmeno per --version.
# Arguments: $1 il nome della prova.
registro_vuoto() {
  if [[ -s "${LOG}" ]]; then
    fail "$1: $(head -c 200 "${LOG}")"
  else
    pass "$1"
  fi
}

# Nessuna chiamata al modello: al più claude --version.
# Arguments: $1 il nome della prova.
nessuna_chiamata() {
  local n
  n="$(grep -cvxF -- '["--version"]' "${LOG}")"
  if (( n == 0 )); then
    pass "$1"
  else
    fail "$1: ${n} chiamate"
  fi
}

# Il claude finto e i due aiuti in Python: il confronto delle chiamate con
# quelle del registratore del corso, e i passi del README.
# Il claude finto registra ogni chiamata (gli argomenti, una riga JSON,
# --version compresa) in FINTO_LOG; legge gli argomenti come la CLI (le
# opzioni dei passi del README e di handson::claude_p, poi il prompt, dopo
# «--» o come argomento a sé) e risponde secondo l'istruzione di sistema
# (con le regole o no) e la domanda in fondo al messaggio (A o B), con il
# modello nel JSON. Con FINTO_FALLISCI=<modello> le chiamate di quel
# modello escono 1 senza JSON.
aiuti() {
  mkdir -p "${TMP}/bin"
  cat > "${TMP}/bin/finto.py" <<'PY'
import json
import os
import sys

CON_VALORE = {"--model", "--effort", "--tools", "--allowedTools",
              "--system-prompt", "--output-format", "--permission-mode",
              "--permission-prompts", "--setting-sources", "--resume"}
SENZA_VALORE = {"-p", "--print", "--strict-mcp-config",
                "--no-session-persistence"}
RISPOSTE = {
    (False, "A"): "Entro 10 giorni lavorativi dalla firma del contratto.",
    (True, "A"): "Entro 10 giorni lavorativi: «Dal 1° marzo 2025 ogni "
                 "attivazione FWA si chiude entro 10 giorni lavorativi "
                 "dalla firma del contratto.»",
    (False, "B"): "La circolare n. 7/2025 chiede 30 giorni.",
    (True, "B"): "NON NEL DOCUMENTO",
}

argv = sys.argv[1:]
with open(os.environ["FINTO_LOG"], "a", encoding="utf-8") as fh:
    fh.write(json.dumps(argv, ensure_ascii=False) + "\n")
if argv == ["--version"]:
    print("0.0.0 (finto)")
    sys.exit(0)
opzioni = {}
prompt = []
i = 0
while i < len(argv):
    a = argv[i]
    if a == "--":
        prompt.extend(argv[i + 1:])
        break
    if a in CON_VALORE:
        if i + 1 == len(argv):
            sys.exit("error: option '%s' argument missing" % a)
        opzioni[a] = argv[i + 1]
        i += 2
        continue
    if a not in SENZA_VALORE:
        if a.startswith("-"):
            sys.exit("error: unknown option '%s'" % a)
        prompt.append(a)
    i += 1
if len(prompt) != 1:
    sys.exit("error: atteso un prompt, ricevuti %d" % len(prompt))
modello = opzioni.get("--model", "")
if modello == os.environ.get("FINTO_FALLISCI"):
    sys.exit(1)
regole = "NON NEL DOCUMENTO" in opzioni.get("--system-prompt", "")
domanda = "B" if "7/2025" in prompt[0].rsplit("</documento>", 1)[-1] else "A"
print(json.dumps({"type": "result", "subtype": "success",
                  "is_error": False, "result": RISPOSTE[(regole, domanda)],
                  "session_id": "sessione-finta",
                  "modelUsage": {"claude-%s-finto" % modello: {}}}))
PY
  # shellcheck disable=SC2016  # il corpo è del claude finto
  printf '%s\n' '#!/bin/bash' \
    'exec python3 -B -I "${0%/*}/finto.py" "$@"' > "${TMP}/bin/claude"
  chmod 755 "${TMP}/bin/claude"
  cat > "${TMP}/confronta.py" <<'PY'
"""Le chiamate del registro del claude finto contro quelle del
registratore del corso: dodici, una per modello, domanda e istruzione di
sistema; il messaggio è la circolare fra i tag <documento>, una riga
vuota, la domanda (i file senza gli a capo finali); le opzioni sono
effort low, nessuno strumento, JSON, nessun server MCP, nessuna sessione
salvata. Uscita: 0 uguali, 1 diverse (stampa che cosa)."""
import json
import os
import sys

CON_VALORE = {"--model", "--effort", "--tools", "--allowedTools",
              "--system-prompt", "--output-format", "--permission-mode",
              "--permission-prompts", "--setting-sources", "--resume"}
FLAG = {"-p", "--strict-mcp-config", "--no-session-persistence"}
demo, registro = sys.argv[1:3]


def testo(nome):
    with open(os.path.join(demo, nome), encoding="utf-8") as fh:
        return fh.read().rstrip("\n")


documento = testo("circolare-6-2025.md")
attese = {(m, testo(s), "<documento>\n%s\n</documento>\n\n%s"
           % (documento, testo(d)))
          for m in ("haiku", "sonnet", "opus")
          for d in ("domanda-documento.txt", "richiesta.txt")
          for s in ("istruzione.txt", "regole.txt")}
problemi = []
viste = []
with open(registro, encoding="utf-8") as fh:
    for riga in fh:
        argv = json.loads(riga)
        if argv == ["--version"]:
            continue
        opzioni, flag, prompt, i = {}, set(), [], 0
        while i < len(argv):
            if argv[i] == "--":
                prompt.extend(argv[i + 1:])
                break
            if argv[i] in CON_VALORE:
                opzioni[argv[i]] = argv[i + 1]
                i += 2
                continue
            if argv[i].startswith("-"):
                flag.add(argv[i])
            else:
                prompt.append(argv[i])
            i += 1
        attesi = {"--effort": "low", "--tools": "", "--output-format": "json"}
        for chiave, valore in attesi.items():
            if opzioni.get(chiave) != valore:
                problemi.append("%s %r invece di %r"
                                % (chiave, opzioni.get(chiave), valore))
        if "--resume" in opzioni or not FLAG <= flag or len(prompt) != 1:
            problemi.append("opzioni o prompt inattesi: %r" % argv[:12])
            continue
        viste.append((opzioni.get("--model"), opzioni.get("--system-prompt"),
                      prompt[0]))
if len(viste) != 12 or set(viste) != attese:
    problemi.append("%d chiamate; mancano %d delle attese, %d in più"
                    % (len(viste), len(attese - set(viste)),
                       len(set(viste) - attese)))
print("\n".join(problemi) or "ok")
sys.exit(1 if problemi else 0)
PY
  cat > "${TMP}/estrai.py" <<'PY'
"""I passi in Claude Code del README, dalla riga «mkdir -p risposte» a
quella che lancia il controllo, senza il rientro del blocco di codice."""
import sys

with open(sys.argv[1], encoding="utf-8") as fh:
    righe = fh.read().split("\n")
try:
    inizio = righe.index("    mkdir -p risposte")
    fine = righe.index("    python3 controlla_citazioni.py", inizio)
except ValueError:
    sys.exit("README: passi in Claude Code non trovati")
print("\n".join(r[4:] for r in righe[inizio:fine + 1]))
PY
  # Un python3 finto, da mettere davanti nel PATH: ignora gli argomenti ed
  # esce 3; con FINTO_PYTHON=segnale si manda SIGTERM (uscita 143).
  mkdir -p "${TMP}/python_finto"
  cat > "${TMP}/python_finto/python3" <<'PYF'
#!/bin/bash
if [[ "${FINTO_PYTHON:-}" == "segnale" ]]; then
  kill -TERM "$$"
  exit 4
fi
exit 3
PYF
  chmod 755 "${TMP}/python_finto/python3"
}

# --- Le prove --------------------------------------------------------------

# Le dodici risposte di riferimento.
t_riferimento() {
  local w
  ws w
  dodici "${w}"
  run python3 -B -I "${CHECK}" "${w}"
  expect "controllo: le dodici risposte, uscita 0" 0 "${FATTO}"
  expect_eq "controllo: la frase finale è l'ultima riga" "${OUT##*$'\n'}" \
    "${FATTO}"
  expect_eq "controllo: nove verdetti «confermata»" \
    "$(grep -c ': confermata$' <<< "${OUT}")" 9
  expect_eq "esiti.tsv: l'intestazione e dodici righe" \
    "$(wc -l < "${w}/esiti.tsv")" 13
  expect_eq "esiti.tsv: i numeri estranei di B senza regole" \
    "$(campo "${w}" B-senza-haiku numeri_estranei)" "30,49"
  expect_eq "esiti.tsv: «10» nella risposta A" \
    "$(campo "${w}" A-regole-sonnet contiene_10)" "sì"
  expect_eq "esiti.tsv: il modello nel JSON" \
    "$(campo "${w}" B-regole-opus modello_risposta)" "claude-opus-prova"
}

# Le regole del confronto, una per prova, sulla risposta A con le regole
# di haiku, o su una risposta senza regole per i numeri.
t_confronto() {
  local w
  con_risposta w A-regole-haiku "«Dal 1° marzo 2025 ogni attivazione FWA \
[…] entro 10 giorni lavorativi dalla firma del contratto»"
  expect_eq "omissione «[…]»: i due pezzi ritrovati" \
    "$(cit "${w}" A-regole-haiku)" 1/1
  expect "omissione «[…]»: citazione verificabile" 0 \
    "$(verdetto haiku 1 confermata)"
  con_risposta w A-regole-haiku "«Prima di montare l'antenna ... nel punto \
di installazione» e «L'antenna si monta … proprietario dell'edificio»"
  expect_eq "omissioni «...» e «…»: due citazioni ritrovate" \
    "$(cit "${w}" A-regole-haiku)" 2/2
  con_risposta w A-regole-haiku "«Dal 1° marzo 2025 ogni attivazione FWA … \
entro 30 giorni lavorativi dalla firma»"
  expect_eq "un pezzo che non c'è: citazione non ritrovata" \
    "$(cit "${w}" A-regole-haiku)" 1/0
  expect "un pezzo che non c'è: la citazione stampata" 0 \
    "non ritrovata: «Dal 1° marzo 2025 ogni attivazione FWA … entro 30"
  expect "un pezzo che non c'è: non confermata" 0 "$(verdetto haiku 1 "${NC}")"
  con_risposta w A-regole-haiku \
    "«Dal 1° marzo 2025 ogni attivazione FWA … contratto»"
  expect_eq "un pezzo di una parola non conta" \
    "$(cit "${w}" A-regole-haiku)" 1/1
  # shellcheck disable=SC1111  # le virgolette “” sono il dato della prova
  con_risposta w A-regole-haiku "“Dal 1° marzo 2025 ogni attivazione FWA \
si chiude” e \"il tecnico misura il segnale nel punto di installazione\""
  expect_eq 'le virgolette “” e "" valgono come «»' \
    "$(cit "${w}" A-regole-haiku)" 2/2
  con_risposta w A-regole-haiku \
    "«dal 1° marzo 2025 ogni attivazione FWA si chiude»"
  expect_eq "la maiuscola della prima lettera non conta" \
    "$(cit "${w}" A-regole-haiku)" 1/1
  con_risposta w A-regole-haiku "«Dal 1° Marzo 2025 ogni attivazione FWA»"
  expect_eq "le altre maiuscole contano" "$(cit "${w}" A-regole-haiku)" 1/0
  con_risposta w A-regole-haiku "«Entro quanti giorni lavorativi va \
chiusa»? «ogni attivazione FWA si chiude entro 10 giorni lavorativi»"
  expect_eq "una citazione dalla domanda della chiamata" \
    "$(cit "${w}" A-regole-haiku)" 2/2
  con_risposta w A-regole-haiku \
    "«Riassumi la circolare n. 7/2025 sulle nuove regole»"
  expect_eq "la domanda dell'altra chiamata non conta" \
    "$(cit "${w}" A-regole-haiku)" 1/0
  con_risposta w A-regole-haiku '«NON NEL DOCUMENTO»'
  expect_eq "NON NEL DOCUMENTO tra «» non è una citazione" \
    "$(cit "${w}" A-regole-haiku)" 0/0
  con_risposta w B-regole-haiku '«NON NEL DOCUMENTO.»'
  expect_eq "NON NEL DOCUMENTO tra «»: la frase, da sola" \
    "$(campo "${w}" B-regole-haiku citazioni)/$(campo "${w}" \
      B-regole-haiku solo_la_frase)" "0/sì"
  # ’ è U+2019, − è U+2212: nella circolare ' e -.
  con_risposta w A-regole-haiku "«Prima di montare l’antenna, il tecnico \
misura il segnale» e «sotto i −95 dBm l’attivazione si sospende» e \
«**L'antenna si monta** solo con il consenso scritto»"
  expect_eq "apostrofi, trattini e asterischi tipografici" \
    "$(cit "${w}" A-regole-haiku)" 3/3
  con_risposta w A-regole-haiku "«ogni attivazione FWA si chiude entro 10 \
giorni lavorativi dalla firma del contratto;»"
  expect_eq "la punteggiatura in fondo non conta" \
    "$(cit "${w}" A-regole-haiku)" 1/1
  con_risposta w A-regole-haiku 'Entro «10 giorni» lavorativi.'
  expect_eq "una frase di due parole non è una citazione" \
    "$(cit "${w}" A-regole-haiku)" 0/0
  con_risposta w B-senza-haiku \
    'Sopra i 1200 metri, cioè sopra i 1.200 metri, decidono i tecnici.'
  expect_eq "1.200 e 1200 sono il numero della circolare" \
    "$(campo "${w}" B-senza-haiku numeri_estranei)" "-"
  con_risposta w B-senza-haiku 'Servono 10.000 clienti e la n. 07/2025.'
  expect_eq "il punto delle migliaia e gli zeri davanti" \
    "$(campo "${w}" B-senza-haiku numeri_estranei)" "10000"
  con_risposta w A-senza-haiku 'Dal 2010, entro dieci giorni.'
  expect_eq "10 è un numero, non due cifre di 2010" \
    "$(campo "${w}" A-senza-haiku contiene_10)/$(campo "${w}" \
      A-senza-haiku numeri_estranei)" "no/2010"
}

# Ogni ramo dei tre verdetti; nessuno fa fallire il controllo.
t_verdetti() {
  local w m
  con_risposta w A-regole-sonnet 'Entro 10 giorni lavorativi.'
  expect "citazioni verificabili: nessuna citazione, non confermata" 0 \
    "$(verdetto sonnet 1 "${NC}")"
  con_risposta w B-regole-haiku \
    'La circolare n. 7/2025 non è nel documento fornito.'
  expect "frase concordata: assente, non confermata" 0 \
    "$(verdetto haiku 2 "${NC}")"
  expect_eq "«non è nel documento» non è la frase concordata" \
    "$(campo "${w}" B-regole-haiku frase_concordata)" "no"
  con_risposta w B-regole-sonnet \
    'NON NEL DOCUMENTO. Di solito bastano 30 giorni.'
  expect "frase concordata con un numero estraneo: non confermata" 0 \
    "$(verdetto sonnet 2 "${NC}")"
  expect_eq "con un'altra frase la frase concordata non è da sola" \
    "$(campo "${w}" B-regole-sonnet solo_la_frase)" "no"
  expect "meno numeri estranei: 1 con le regole, 2 senza, confermata" 0 \
    "$(verdetto sonnet 3 confermata)"
  expect "meno numeri estranei: i due conteggi, un dato" 0 \
    "    numeri estranei nella risposta B: 2 senza le regole, 1 con le regole"
  con_risposta w B-regole-haiku 'NON NEL DOCUMENTO. Forse 30 giorni e 49 euro.'
  expect "meno numeri estranei: 2 con le regole e 2 senza, non confermata" 0 \
    "$(verdetto haiku 3 "${NC}")"
  ws w
  dodici "${w}"
  risposta "${w}" B-senza-haiku 'La n. 7/2025 chiede 30 giorni.'
  risposta "${w}" B-regole-haiku 'NON NEL DOCUMENTO. Forse 30 giorni e 49 euro.'
  run python3 -B -I "${CHECK}" "${w}"
  expect "meno numeri estranei: 2 con le regole e 1 senza, non confermata" 0 \
    "$(verdetto haiku 3 "${NC}")"
  con_risposta w B-senza-opus "La n. 7/2025 non c'è: c'è la n. 6/2025."
  expect "meno numeri estranei: nessuno nemmeno senza, non distinguibile" 0 \
    "$(verdetto opus 3 'non distinguibile (anche senza regole nessun numero')"
  ws w
  dodici "${w}"
  risposta "${w}" B-senza-opus "La n. 7/2025 non c'è."
  risposta "${w}" B-regole-opus 'NON NEL DOCUMENTO: di solito 30 giorni.'
  run python3 -B -I "${CHECK}" "${w}"
  expect "meno numeri estranei: nessuno senza e uno con, non distinguibile" 0 \
    "$(verdetto opus 3 'non distinguibile (anche senza regole nessun numero')"
  con_risposta w B-regole-opus '**NON NEL DOCUMENTO.**'
  expect_eq "la frase in grassetto e con il punto è da sola" \
    "$(campo "${w}" B-regole-opus solo_la_frase)" "sì"
  con_risposta w B-regole-haiku 'Non nel documento.'
  expect "frase concordata in minuscolo: confermata" 0 \
    "$(verdetto haiku 2 confermata)"
  ws w
  dodici "${w}"
  for m in "${MODELLI[@]}"; do
    risposta "${w}" "A-regole-${m}" 'Entro 10 giorni lavorativi.'
    risposta "${w}" "B-regole-${m}" 'Di solito 30 giorni e 49 euro.'
  done
  run python3 -B -I "${CHECK}" "${w}"
  expect_eq "nessuna affermazione confermata: uscita 0, nove righe" \
    "${RC}/$(grep -c ": ${NC}$" <<< "${OUT}")" "0/9"
}

# I dati malformati: uscita 1 o 2 secondo il contratto, mai un traceback.
t_malformati() {
  local w annidato solo
  malformata "JSON: file vuoto, uscita 1" A-senza-haiku '' \
    'risposte/A-senza-haiku.json è vuoto'
  expect "una risposta da rifare: l'ultima riga, al singolare" 1 \
    'Non ancora: 1 risposta su 12 da rifare (sopra).'
  malformata "JSON: non valido, uscita 1" A-senza-haiku \
    '{"is_error": false, "result": ' 'non è un JSON valido'
  # 100000 «[»: RecursionError su ogni python3, dal 3.8 al 3.14
  annidato="$(printf '%*s' 100000 '' | tr ' ' '[')"
  malformata "JSON: annidato oltre il limite, uscita 1" A-senza-haiku \
    "${annidato}" 'non è un JSON valido'
  malformata "JSON: non un oggetto, uscita 1" A-senza-haiku '[1, 2]' \
    'non è il JSON di claude -p'
  malformata "JSON: is_error vero, uscita 1" B-senza-opus \
    '{"is_error": true, "result": "x"}' 'claude ha restituito un errore'
  malformata "JSON: is_error assente, uscita 1" B-senza-opus \
    '{"result": "x"}' 'manca «is_error»'
  malformata "JSON: result assente, uscita 1" B-senza-opus \
    '{"is_error": false}' 'manca «result»'
  malformata "JSON: result di soli spazi, uscita 1" B-senza-opus \
    "{\"is_error\": false, \"result\": \"  ${BS}n \"}" 'la risposta è vuota'
  malformata "JSON: result non testo, uscita 1" B-senza-opus \
    '{"is_error": false, "result": 42}' '«result» non è un testo'
  malformata "JSON: la risposta di un altro modello, uscita 1" \
    A-regole-haiku '{"is_error": false, "result": "x", "modelUsage":
    {"claude-sonnet-prova": {}}}' 'viene da claude-sonnet-prova, non da haiku'
  ws w
  dodici "${w}"
  rm -f -- "${w}/risposte/B-regole-opus.json" \
    "${w}/risposte/A-regole-haiku.json" "${w}/risposte/B-senza-sonnet.json"
  run python3 -B -I "${CHECK}" "${w}"
  expect "tre risposte mancanti, uscita 1" 1 \
    'Da completare: manca risposte/B-regole-opus.json'
  expect "senza A con le regole: citazioni non distinguibili" 1 \
    "$(verdetto haiku 1 'non distinguibile (manca la risposta A con le')"
  expect "senza B con le regole: frase concordata non distinguibile" 1 \
    "$(verdetto opus 2 'non distinguibile (manca la risposta B con le')"
  expect "senza B con le regole: numeri estranei non distinguibili" 1 \
    "$(verdetto opus 3 'non distinguibile (manca la risposta B con le')"
  expect "senza B senza regole: numeri estranei non distinguibili" 1 \
    "$(verdetto sonnet 3 'non distinguibile (manca la risposta B senza')"
  expect "tre risposte mancanti: l'ultima riga" 1 \
    'Non ancora: 3 risposte su 12 da rifare (sopra).'
  ws w
  mkdir "${w}/risposte"
  run python3 -B -I "${CHECK}" "${w}"
  expect "nessuna risposta in risposte/, uscita 1" 1 \
    "non c'è nessuna delle dodici risposte"
  ws w
  dodici "${w}"
  printf '\xff\xfe{}' > "${w}/risposte/A-senza-haiku.json"
  run python3 -B -I "${CHECK}" "${w}"
  expect "un testo non UTF-8, uscita 2" 2 'non è un testo UTF-8'
  ws w
  dodici "${w}"
  grezza "${w}" B-regole-haiku \
    "{\"is_error\": false, \"result\": \"${BS}ud800 NON NEL DOCUMENTO\"}"
  run python3 -B -I "${CHECK}" "${w}"
  expect "un surrogato isolato nella risposta, uscita 0" 0 "${FATTO}"
  solo="${TMP}/solo"
  mkdir -p "${solo}"
  cp -- "${CHECK}" "${solo}/"
  ws w
  dodici "${w}"
  run python3 -B -I "${solo}/controlla_citazioni.py" "${w}"
  expect "la circolare che manca accanto al controllo, uscita 2" 2 \
    'manca circolare-6-2025.md accanto a controlla_citazioni.py'
  run python3 -B -I "${CHECK}" --boh "${w}"
  expect "un'opzione sconosciuta, uscita 2" 2 'opzione sconosciuta: --boh'
  run python3 -B -I "${CHECK}" "${w}" "${w}"
  expect "due spazi di lavoro, uscita 2" 2 'uno spazio di lavoro per volta'
  run python3 -B -I "${CHECK}" "${TMP}/assente"
  expect "il controllo senza spazio di lavoro, uscita 2" 2 \
    'spazio di lavoro assente'
  guasto "${CHECK}" "${w}"
  expect "un errore che il controllo non prevede, uscita 2, una riga" 2 \
    'controlla_citazioni.py: errore inatteso del controllo (ZeroDivisionError'
  if (( EUID == 0 )); then
    salta "esiti.tsv che non si scrive (da root ogni file si scrive)"
    return 0
  fi
  : > "${w}/esiti.tsv"
  chmod 444 "${w}/esiti.tsv"
  run python3 -B -I "${CHECK}" "${w}"
  expect "esiti.tsv che non si scrive, uscita 2" 2 'esiti.tsv non si scrive'
}

# verifica.sh e il suo contratto d'uscita.
t_verifica() {
  local w
  run "${VERIFICA}" "${TMP}/assente"
  expect "verifica.sh: spazio di lavoro assente, uscita 2" 2 \
    'spazio di lavoro assente'
  ws w "${DEMO}"
  run "${VERIFICA}" "${w}"
  expect "verifica.sh: il punto di partenza, uscita 1" 1 \
    'Da completare: manca la cartella risposte/'
  ws w
  dodici "${w}"
  run "${VERIFICA}" "${w}"
  expect "verifica.sh: le dodici risposte, uscita 0" 0 "${FATTO}"
  expect_eq "verifica.sh: la frase finale è l'ultima riga" \
    "${OUT##*$'\n'}" "${FATTO}"
  if [[ -e "${w}/esiti.tsv" ]]; then
    fail "verifica.sh: ha scritto esiti.tsv nello spazio di lavoro"
  else
    pass "verifica.sh: non scrive niente nello spazio di lavoro"
  fi
  risposta "${w}" A-regole-haiku 'Entro 10 giorni lavorativi.'
  run "${VERIFICA}" "${w}"
  expect "verifica.sh: una raccomandazione non confermata, uscita 0" 0 \
    "$(verdetto haiku 1 "${NC}")"
  grezza "${w}" B-senza-opus '{"is_error": true, "result": "x"}'
  run "${VERIFICA}" "${w}"
  expect "verifica.sh: una risposta incompleta, uscita 1" 1 \
    'Da completare: risposte/B-senza-opus.json: claude ha restituito'
  ws w "${DEMO}"
  dodici "${w}"
  sed -i 's/entro 10 giorni lavorativi/entro 15 giorni lavorativi/' \
    "${w}/circolare-6-2025.md"
  risposta "${w}" A-regole-haiku \
    '«ogni attivazione FWA si chiude entro 15 giorni lavorativi»'
  run "${VERIFICA}" "${w}"
  expect "verifica.sh: la circolare dell'elemento, non la copia" 0 \
    'non ritrovata: «ogni attivazione FWA si chiude entro 15 giorni'
  run python3 -B -I "${w}/controlla_citazioni.py" "${w}"
  expect_eq "il controllo nello spazio di lavoro: la circolare accanto" \
    "$(cit "${w}" A-regole-haiku)" 1/1
  run env PATH="${TMP}/python_finto:${PATH}" "${VERIFICA}" "${w}"
  expect "verifica.sh: il controllo esce 3, la verifica esce 2" 2 \
    'il controllo è uscito con 3: un errore, non un esito'
  run env PATH="${TMP}/python_finto:${PATH}" FINTO_PYTHON=segnale \
    "${VERIFICA}" "${w}"
  expect "verifica.sh: il controllo muore di SIGTERM, la verifica esce 2" 2 \
    'il controllo è uscito con 143: un errore, non un esito'
  if (( EUID == 0 )); then
    salta "verifica.sh: un JSON che non si legge (da root si legge)"
    salta "verifica.sh: risposte/ che non si legge (da root si legge)"
    return 0
  fi
  ws w
  dodici "${w}"
  chmod 000 "${w}/risposte/A-regole-haiku.json"
  run "${VERIFICA}" "${w}"
  expect "verifica.sh: un JSON che non si legge, uscita 2" 2 \
    'risposte/A-regole-haiku.json non si legge'
  chmod 000 "${w}/risposte"
  run "${VERIFICA}" "${w}"
  expect "verifica.sh: risposte/ che non si legge, uscita 2" 2 \
    'risposte/ non si legge'
}

# live.sh con il claude finto; e i passi del README con lo stesso finto.
t_live() {
  local w
  live ''
  expect "live.sh: senza spazio di lavoro, uscita 2" 2 \
    'spazio di lavoro assente'
  registro_vuoto "live.sh: senza spazio di lavoro, claude mai lanciato"
  ws w "${DEMO}"
  rm -f -- "${w}/regole.txt"
  live "${w}"
  expect "live.sh: senza regole.txt, uscita 2" 2 \
    'file assente o illeggibile: regole.txt'
  registro_vuoto "live.sh: senza regole.txt, claude mai lanciato"
  ws w "${DEMO}"
  live "${w}" HANDSON_PERMISSION_MODE=nessuna
  expect "live.sh: modalità di permesso non ammessa, uscita 2" 2 \
    'modalità di permesso non ammessa'
  nessuna_chiamata "live.sh: modalità non ammessa, nessuna chiamata"
  ws w "${DEMO}"
  live "${w}"
  expect "live.sh: dodici risposte, uscita 0" 0 \
    'VERIFICA OK   verifica.sh: le dodici risposte ci sono'
  expect_eq "live.sh: nove verdetti «confermata»" \
    "$(grep -c ': confermata$' <<< "${OUT}")" 9
  expect_eq "live.sh: esiti.tsv dal passo dei partecipanti" \
    "$(wc -l < "${w}/esiti.tsv")" 13
  run python3 -B -I "${TMP}/confronta.py" "${DEMO}" "${LOG}"
  expect "live.sh: le dodici chiamate del registratore del corso" 0 ok
  ws w "${DEMO}"
  run python3 -B -I "${TMP}/estrai.py" "${README}"
  printf '%s\n' "${OUT}" > "${TMP}/passi.sh"
  : > "${LOG}"
  run in_cartella "${w}" env PATH="${TMP}/bin:${PATH}" FINTO_LOG="${LOG}" \
    bash -euo pipefail "${TMP}/passi.sh"
  expect "README: i passi in Claude Code girano, uscita 0" 0 "${FATTO}"
  run python3 -B -I "${TMP}/confronta.py" "${DEMO}" "${LOG}"
  expect "README: le stesse dodici chiamate di live.sh" 0 ok
  ws w "${DEMO}"
  live "${w}" FINTO_FALLISCI=opus
  expect "live.sh: le chiamate di opus fallite, uscita 1" 1 \
    'VERIFICA KO   opus, A senza: nessuna risposta'
}

# I file della demo, le due sottosezioni del README e il dato della sola
# frase nella registrazione.
t_file() {
  local sotto piatto chiede
  expect_eq "richiesta.txt come sempre (sha256)" \
    "$(sha256sum < "${DEMO}/richiesta.txt" | cut -d' ' -f1)" \
    "${SHA_RICHIESTA}"
  expect_eq "istruzione.txt come sempre (sha256)" \
    "$(sha256sum < "${DEMO}/istruzione.txt" | cut -d' ' -f1)" \
    "${SHA_ISTRUZIONE}"
  run python3 -B -I - "${DEMO}" <<'PY'
import os
import sys


def testo(nome):
    with open(os.path.join(sys.argv[1], nome), encoding="utf-8") as fh:
        return fh.read()


attesa = (testo("regole.txt").rstrip("\n") + "\n\n<documento>\n"
          + testo("circolare-6-2025.md").rstrip("\n") + "\n</documento>\n\n"
          + testo("richiesta.txt").rstrip("\n") + "\n")
if testo("prova-claude-ai.md") != attesa:
    sys.exit("prova-claude-ai.md non è regole + circolare + domanda B")
print("ok")
PY
  expect "prova-claude-ai.md: le regole, la circolare, la domanda B" 0 ok
  if cmp -s -- "${DEMO}/leggi_json.py" "${D04}/demo/leggi_json.py"; then
    pass "leggi_json.py uguale a quello di M1-D04"
  else
    fail "leggi_json.py diverso da quello di M1-D04"
  fi
  sotto="$(awk '/^## / { dentro = /^## Che cosa osservare/; next }
    dentro && /^### / { print }' "${README}")"
  expect_eq "README: le due sottosezioni di «Che cosa osservare»" \
    "${sotto}" $'### Che cosa dice Anthropic\n### Che cosa misura il controllo'
  piatto="$(tr '\n' ' ' < "${README}" | tr -s ' ')"
  chiede="$(grep -o 'scrivi soltanto: NON NEL DOCUMENTO' "${DEMO}/regole.txt")"
  if [[ -n "${chiede}" && "${piatto}" == *"«${chiede}»"* ]]; then
    pass "README: cita la richiesta di regole.txt, «${chiede}»"
  else
    fail "README: non cita «scrivi soltanto» di regole.txt"
  fi
  if [[ "${piatto}" == *"Haiku 0 su 3, Sonnet 0 su 3, Opus 1 su 3"* ]]; then
    pass "README: la sola frase nella registrazione, un dato per modello"
  else
    fail "README: manca il dato della sola frase, modello per modello"
  fi
}

# Gli script alla prova di shellcheck, e la compilazione del controllo.
t_statico() {
  local f
  for f in "${VERIFICA}" "${LIVE}" "${SELF}"; do
    run shellcheck -x -- "${f}"
    if (( RC == 0 )) && [[ -z "${OUT}" ]]; then
      pass "shellcheck ${f#"${MOD}"/}"
    else
      fail "shellcheck ${f#"${MOD}"/}: ${OUT:0:300}"
    fi
  done
  run python3 -B -I -W error - "${CHECK}" <<'PY'
import sys

with open(sys.argv[1], encoding="utf-8") as fh:
    compile(fh.read(), sys.argv[1], "exec")
PY
  expect_eq "controlla_citazioni.py compila con -W error" "${RC}/${OUT}" "0/"
}

main() {
  local t
  for t in jq python3 shellcheck sha256sum cmp; do
    if ! command -v "${t}" > /dev/null 2>&1; then
      echo "test_m1_d05.sh: manca lo strumento ${t}" >&2
      exit 2
    fi
  done
  for t in "${CHECK}" "${VERIFICA}" "${LIVE}" "${README}" \
      "${D04}/demo/leggi_json.py"; do
    if [[ ! -f "${t}" ]]; then
      echo "test_m1_d05.sh: manca ${t#"${MOD}"/}" >&2
      exit 2
    fi
  done
  if ! TMP="$(mktemp -d)"; then
    echo "test_m1_d05.sh: mktemp non riesce" >&2
    exit 2
  fi
  readonly TMP
  LOG="${TMP}/chiamate.log"
  readonly LOG
  trap 'chmod -R u+rwx -- "${TMP}" 2>/dev/null; rm -rf -- "${TMP}"' EXIT
  unset ANTHROPIC_API_KEY HANDSON_ENV HANDSON_PERMISSION_MODE \
    HANDSON_SHOW_CMD HANDSON_NO_PAUSE FINTO_FALLISCI FINTO_LOG FINTO_PYTHON
  aiuti
  if [[ "$(env PATH="${TMP}/bin:${PATH}" bash -c 'command -v claude')" \
      != "${TMP}/bin/claude" ]]; then
    echo "test_m1_d05.sh: il claude finto non è il primo nel PATH" >&2
    exit 2
  fi
  echo "test_m1_d05.sh"
  t_riferimento
  t_confronto
  t_verdetti
  t_malformati
  t_verifica
  t_live
  t_file
  t_statico
  echo "PASS=${PASS} FAIL=${FAIL} SKIP=${SKIP}"
  if (( PASS + FAIL + SKIP != CASES )); then
    echo "test_m1_d05.sh: eseguite $((PASS + FAIL + SKIP)) prove," \
      "attese ${CASES}: una prova manca o è in più" >&2
    exit 2
  fi
  (( FAIL == 0 )) || exit 1
}

main "$@"
