#!/bin/bash
#
# test_m2_d05.sh -- le prove di M2-D05 «Ragionare, oggi», per il docente
# (sta in _docente/, il materiale del docente). Nessun modello viene
# chiamato: al posto di claude c'è un'esca, davanti nel PATH, che registra
# ogni chiamata (anche --version) con il suo ambiente e risponde con un
# JSON sintetico.
#   - controlla_ragionamento.py, su tabelle scritte qui: ogni ramo dei
#     verdetti (V1 confermata o no: un thinking oltre l'uscita, uno sotto
#     zero, il caso uguale; V2 e V3 con più di 0 e con 0, mai «smentita»;
#     V4 confermata, non confermata con meno o con tanto quanto, non
#     distinguibile; l'orario mai un verdetto) e i dati rovinati (una riga
#     che manca, un numero che non è un numero, anche «²» o di 5000 cifre,
#     un modello_id vuoto, campi in meno, l'intestazione sbagliata, un
#     file vuoto o di
#     byte a caso, CRLF e BOM, byte non UTF-8, una riga lunghissima):
#     uscita 0 o 1 come dice il contratto, mai un traceback; un modello
#     diverso da quello della riga esce 2; di una chiamata conta l'ultima
#     riga; una riga estranea si segnala; l'uso sbagliato esce 2;
#   - verifica.sh: spazio di lavoro assente (2), punto di partenza (1),
#     tabella completa (0, la frase finale come ultima riga, anche con
#     V2-V4 non confermate), garanzia non confermata (1), tabella
#     incompleta (1), il file che non si legge (2; saltato da root), una
#     cartella al posto del file (2), un modello estraneo (2);
#   - i passi del README, eseguiti come li incollano i partecipanti, con
#     l'esca: la tabella passa la verifica; l'unset del passo 2 toglie
#     CLAUDE_CODE_EFFORT_LEVEL e MAX_THINKING_TOKENS dalle chiamate; una
#     risposta senza JSON, con is_error, senza modelUsage o senza niente
#     lascia la riga incompleta (1);
#   - live.sh con l'esca: le precondizioni (spazio di lavoro assente,
#     CLAUDE_CODE_EFFORT_LEVEL impostata, anche vuota, un file che manca)
#     escono 2 senza nessuna chiamata, nemmeno --version; le sette
#     chiamate escono 0, con i verdetti a schermo una volta sola;
#     MAX_THINKING_TOKENS=0 arriva a R2 e a nessun'altra chiamata, anche
#     se era già nell'ambiente; una chiamata fallita, una risposta con
#     is_error, senza modelUsage o senza JSON fermano la demo (1); un
#     modello estraneo esce 2; la garanzia non confermata esce 1; una
#     risposta senza orario no;
#   - le chiamate dei passi del README e quelle di live.sh sono le stesse:
#     modello, effort, ambiente, prompt, system prompt e opzioni;
#   - in nessuna uscita un traceback o «smentita»;
#   - shellcheck -x su verifica.sh, live.sh e questo script.
# Tutto nasce in una cartella temporanea: l'albero del repository non
# cambia.
#
# Uso:    m2_prompting_avanzato/_docente/test_m2_d05.sh
# Uscita: 0 = tutte le prove passano · 1 = almeno una fallita · 2 =
#         precondizione (manca python3 o shellcheck, o un file
#         dell'elemento; un numero di prove diverso da CASES)
set -uo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly MOD="${SELF%/_docente/*}"
readonly ITEM="${MOD}/s1_progettare_il_prompt/m2_6_ragionamento/M2-D05_ragionare_oggi"
readonly CONTROLLA="${ITEM}/demo/controlla_ragionamento.py"
readonly VERIFICA="${ITEM}/verifica.sh"
readonly LIVE="${ITEM}/_docente/live.sh"
readonly CASES=96
FATTO='Fatto: ogni affermazione è stata messa alla prova; gli esiti sono'
FATTO+=' qui sopra.'
readonly FATTO
V3_ZERO='non dimostrata in questa esecuzione: uno 0 può voler dire che'
V3_ZERO+=' Claude ha deciso di non ragionare'
readonly V3_ZERO
TMP=''
PASS=0
FAIL=0
SKIP=0
RC=0
OUT=''
# Ogni uscita delle prove, per le ultime due: niente traceback, niente
# «smentita».
TUTTE=''
# L'uscita dei passi del README dell'ultima esecuzione.
PASSI=''

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }
salta() { echo "  SKIP: $1"; SKIP=$((SKIP + 1)); }

# Esegue un comando; RC e OUT (STDOUT e STDERR insieme) per expect.
run() {
  OUT="$("$@" 2>&1)"
  RC=$?
  TUTTE+="${OUT}"$'\n'
}

# Uscita attesa E parola chiave attesa (RU-01.T3).
# Arguments: $1 il nome, $2 l'uscita attesa, $3 la parola (grep -F).
expect() {
  if (( RC == $2 )) && grep -qF -- "$3" <<< "${OUT}"; then
    pass "$1"
  else
    fail "$1 (rc=${RC}, attesa $2, parola «$3»): ${OUT:0:400}"
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

# Due valori uguali. Arguments: $1 il nome, $2 il valore, $3 l'atteso.
uguale() {
  if [[ "$2" == "$3" ]]; then
    pass "$1"
  else
    fail "$1: «$2», atteso «$3»"
  fi
}

# Una condizione: $1 il nome, poi il comando che la verifica.
vero() {
  local nome="$1"
  shift
  if "$@"; then
    pass "${nome}"
  else
    fail "${nome}"
  fi
}

# Le righe «I numeri…» e «Le affermazioni:» di OUT, in quest'ordine.
in_ordine() {
  awk '/^I numeri/ && !n { n = NR } /^Le affermazioni:/ && !a { a = NR }
    END { exit !(n && a && n < a) }' <<< "${OUT}"
}

# Un nuovo spazio di lavoro con il punto di partenza dell'elemento.
# Arguments: $1 la variabile da assegnare.
ws() {
  local __w
  __w="$(mktemp -d "${TMP}/ws.XXXXXX")" || { echo "mktemp" >&2; exit 2; }
  cp -R "${ITEM}/demo/." "${__w}/" || exit 2
  printf -v "$1" '%s' "${__w}"
}

# Una tabella di prova: le sette righe complete (tabella.py), con i cambi.
# Arguments: $1 il file, poi «Rn.campo=valore», «Rn=-», «+riga».
tabella() { python3 -B -I "${TMP}/tabella.py" "$@" || exit 2; }

# Il controllo su una tabella. Arguments: quelli del controllo.
controlla() { run python3 -B -I "${CONTROLLA}" "$@"; }

# Un comando con l'esca davanti nel PATH; il registro riparte vuoto.
# Arguments: le variabili NOME=valore e il comando.
esca() {
  : > "${TMP}/esca.log"
  run env PATH="${TMP}/bin:${PATH}" HANDSON_NO_PAUSE=1 HANDSON_SHOW_CMD=0 \
    ESCA_LOG="${TMP}/esca.log" "$@"
}

# Quante chiamate ha ricevuto l'esca, --version compreso.
chiamate() { grep -c '' "${TMP}/esca.log"; }

# I passi del README nello spazio di lavoro $1, come li incolla un
# partecipante, con l'esca (la loro uscita in PASSI); poi verifica.sh, con
# RC e OUT per expect.
# Arguments: $1 lo spazio di lavoro, poi le variabili NOME=valore.
passi() {
  local w="$1"
  shift
  : > "${TMP}/esca.log"
  PASSI="$(cd "${w}" && env PATH="${TMP}/bin:${PATH}" \
    ESCA_LOG="${TMP}/esca.log" "$@" bash "${TMP}/passi.sh" 2>&1)"
  TUTTE+="${PASSI}"$'\n'
  run "${VERIFICA}" "${w}"
}

# Il campo $3 (da 1) della riga $2 (da 1, l'intestazione compresa) della
# tabella dello spazio di lavoro $1.
campo() {
  awk -F'\t' -v r="$2" -v c="$3" 'NR == r { print $c }' \
    "$1/ragionamento.tsv"
}

# I comandi dei passi del README, in passi.sh: le righe di codice della
# sezione «Passi in Claude Code» (rientrate di sette spazi), senza la
# preparazione dello spazio di lavoro (prepara_esercizio.sh e cd).
estrai_passi() {
  awk '/^## / { dentro = ($0 ~ /^## Passi in Claude Code/); next }
    dentro && /^       / { sub(/^       /, ""); print }' "${ITEM}/README.md" \
    | grep -v -e '^tools/prepara_esercizio\.sh ' -e '^cd ~/corso-claude-code' \
    > "${TMP}/passi.sh"
}

# --- I file di prova -----------------------------------------------------

# L'esca, in TMP/bin/claude.
prepara_esca() {
  mkdir -p "${TMP}/bin" || exit 2
  cat > "${TMP}/bin/claude" <<'PY'
#!/usr/bin/env python3
"""L'esca di test_m2_d05.sh: registra ogni chiamata in ESCA_LOG (argv e le
variabili MAX_THINKING_TOKENS e CLAUDE_CODE_EFFORT_LEVEL) e risponde come
claude -p --output-format json con i numeri di BASE, per modello, effort e
MAX_THINKING_TOKENS ("-" se assente). ESCA_CAMBIA cambia un dato:
«modello:effort:mtt:campo=valore», separati da spazi; campi uscita,
thinking, id, esito (ok, ko: uscita 1 senza niente; nojson; errore:
is_error; senzamodello: niente modelUsage). ESCA_RISPOSTA il testo."""
import json
import os
import sys

BASE = {("haiku", "low", "-"): ["110", "105", "claude-haiku-5-5", "ok"],
        ("haiku", "low", "0"): ["110", "98", "claude-haiku-5-5", "ok"],
        ("haiku", "high", "-"): ["320", "300", "claude-haiku-5-5", "ok"],
        ("sonnet", "low", "-"): ["45", "0", "claude-sonnet-5-5", "ok"],
        ("sonnet", "high", "-"): ["130", "120", "claude-sonnet-5-5", "ok"],
        ("opus", "low", "-"): ["29", "24", "claude-opus-5-5", "ok"],
        ("opus", "high", "-"): ["205", "200", "claude-opus-5-5", "ok"]}
CAMPI = {"uscita": 0, "thinking": 1, "id": 2, "esito": 3}
VALORI = {"--model", "--effort", "--tools", "--system-prompt",
          "--setting-sources", "--output-format", "--permission-mode",
          "--permission-prompts", "--allowedTools"}
SOLI = {"-p", "--print", "--strict-mcp-config", "--no-session-persistence"}


def argomenti(argv):
    opz, oper, i = {}, [], 0
    while i < len(argv):
        a = argv[i]
        if a == "--":
            oper += argv[i + 1:]
            break
        if a in VALORI and i + 1 < len(argv):
            opz[a] = argv[i + 1]
            i += 2
        elif a in SOLI:
            opz[a] = ""
            i += 1
        elif a.startswith("-"):
            raise SystemExit("error: unknown option '%s'" % a)
        else:
            oper.append(a)
            i += 1
    if len(oper) != 1:
        raise SystemExit("error: %d prompt" % len(oper))
    return opz


def main(argv):
    with open(os.environ["ESCA_LOG"], "a", encoding="utf-8") as fh:
        fh.write(json.dumps({
            "argv": argv, "mtt": os.environ.get("MAX_THINKING_TOKENS"),
            "ccel": os.environ.get("CLAUDE_CODE_EFFORT_LEVEL")}) + "\n")
    if argv[:1] == ["--version"]:
        print("9.9.9 (Claude Code, esca)")
        return 0
    opz = argomenti(argv)
    dati = {k: list(v) for k, v in BASE.items()}
    for voce in os.environ.get("ESCA_CAMBIA", "").split():
        chiave, _, cambio = voce.rpartition(":")
        campo, _, valore = cambio.partition("=")
        dati[tuple(chiave.split(":"))][CAMPI[campo]] = valore
    chiave = (opz.get("--model"), opz.get("--effort"),
              os.environ.get("MAX_THINKING_TOKENS", "-"))
    if chiave not in dati:
        raise SystemExit("esca: nessuna risposta per %r" % (chiave,))
    uscita, thinking, ident, esito = dati[chiave]
    if esito == "ko":
        return 1
    if esito == "nojson":
        print("Errore: questa non è una risposta JSON")
        return 0
    doc = {"type": "result", "subtype": "success",
           "is_error": esito == "errore",
           "result": os.environ.get("ESCA_RISPOSTA", "9:36"),
           "usage": {"input_tokens": 3, "output_tokens": int(uscita),
                     "output_tokens_details": {"thinking_tokens":
                                               int(thinking)}},
           "modelUsage": {ident: {}}}
    if esito == "senzamodello":
        del doc["modelUsage"]
    print(json.dumps(doc, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
PY
  chmod 755 "${TMP}/bin/claude" || exit 2
}

# tabella.py e chiamate.py, in TMP.
prepara_strumenti() {
  cat > "${TMP}/tabella.py" <<'PY'
"""Scrive una tabella di prova: le sette righe complete, poi i cambi:
«Rn.campo=valore», «Rn=-» (la riga tolta), «+riga» (in coda; \t = TAB)."""
import sys

CAMPI = ["modello", "effort", "thinking_off", "modello_id", "orario",
         "token_uscita", "token_thinking"]
RIGHE = {
    "R1": ["haiku", "low", "no", "claude-haiku-5-5", "9:36", "110", "105"],
    "R2": ["haiku", "low", "MAX_THINKING_TOKENS=0", "claude-haiku-5-5",
           "9:36", "110", "98"],
    "R3": ["haiku", "high", "no", "claude-haiku-5-5", "9:36", "320", "300"],
    "R4": ["sonnet", "low", "no", "claude-sonnet-5-5", "9:36", "45", "0"],
    "R5": ["sonnet", "high", "no", "claude-sonnet-5-5", "9:36", "130", "120"],
    "R6": ["opus", "low", "no", "claude-opus-5-5", "9:36", "29", "24"],
    "R7": ["opus", "high", "no", "claude-opus-5-5", "9:36", "205", "200"]}
uscita, cambi, coda = sys.argv[1], sys.argv[2:], []
for cambio in cambi:
    if cambio.startswith("+"):
        coda.append(cambio[1:].replace("\\t", "\t"))
        continue
    chiave, _, valore = cambio.partition("=")
    riga, _, campo = chiave.partition(".")
    if campo:
        RIGHE[riga][CAMPI.index(campo)] = valore
    elif valore == "-":
        del RIGHE[riga]
with open(uscita, "w", encoding="utf-8", newline="") as fh:
    fh.write("\t".join(CAMPI) + "\n")
    for riga in sorted(RIGHE):
        fh.write("\t".join(RIGHE[riga]) + "\n")
    for riga in coda:
        fh.write(riga + "\n")
PY
  cat > "${TMP}/chiamate.py" <<'PY'
"""Le chiamate registrate dall'esca. «stampa <registro>»: una riga per
chiamata, senza --version: modello, effort, MAX_THINKING_TOKENS,
CLAUDE_CODE_EFFORT_LEVEL, prompt, system prompt e opzioni (non quelle dei
permessi, che aggiunge handson::claude_p). «attese <registro> <demo>»:
sono le sette di M2-D05, nell'ordine, con il prompt e il system prompt
dei file di demo/; esce 0, altrimenti con il primo scarto."""
import json
import sys

VALORI = {"--model", "--effort", "--tools", "--system-prompt",
          "--setting-sources", "--output-format", "--permission-mode",
          "--permission-prompts", "--allowedTools"}
ATTESE = [("haiku", "low", None), ("haiku", "low", "0"),
          ("haiku", "high", None), ("sonnet", "low", None),
          ("sonnet", "high", None), ("opus", "low", None),
          ("opus", "high", None)]


def chiamate(registro):
    righe = [json.loads(r) for r in open(registro, encoding="utf-8")]
    for r in righe:
        if r["argv"][:1] == ["--version"]:
            continue
        opz, oper, i = {}, [], 0
        while i < len(r["argv"]):
            a = r["argv"][i]
            if a == "--":
                oper += r["argv"][i + 1:]
                break
            if a in VALORI:
                opz[a] = r["argv"][i + 1]
                i += 2
            elif a.startswith("-"):
                opz[a] = True
                i += 1
            else:
                oper.append(a)
                i += 1
        yield [opz.get("--model"), opz.get("--effort"), r["mtt"], r["ccel"],
               oper, opz.get("--system-prompt"), opz.get("--tools"),
               opz.get("--output-format"), opz.get("--setting-sources"),
               "-p" in opz, "--strict-mcp-config" in opz,
               "--no-session-persistence" in opz]


def testo(percorso):
    return open(percorso, encoding="utf-8").read().rstrip("\n")


def attese(registro, demo):
    prompt = testo(demo + "/sportelli.md") + "\n" + testo(
        demo + "/direttamente.txt")
    fisse = [[prompt], testo(demo + "/istruzione.txt"), "", "json",
             "project,local", True, True, True]
    viste = list(chiamate(registro))
    if [tuple(c[:3]) for c in viste] != ATTESE:
        return "chiamate %r" % [c[:3] for c in viste]
    for n, c in enumerate(viste, start=1):
        if c[3] is not None:
            return "R%d: CLAUDE_CODE_EFFORT_LEVEL=%r" % (n, c[3])
        if c[4:] != fisse:
            return "R%d: %r" % (n, c[4:])
    return 0


if sys.argv[1] == "stampa":
    for c in chiamate(sys.argv[2]):
        print(json.dumps(c, ensure_ascii=False))
else:
    sys.exit(attese(sys.argv[2], sys.argv[3]))
PY
}

# --- I test ---------------------------------------------------------------

# Il controllo: ogni ramo dei verdetti, su tabelle scritte qui.
t_verdetti() {
  local f="${TMP}/v.tsv"
  tabella "${f}"
  controlla "${f}"
  expect "controllo: la tabella completa esce 0, V1 confermata" 0 \
    "in ogni chiamata (7 su 7): confermata"
  expect "controllo: V2 con più di 0 è confermata" 0 \
    "(R1: 105 token di ragionamento): confermata"
  expect "controllo: V3 con più di 0 è confermata" 0 \
    "(R2: 98 token di ragionamento): confermata"
  expect "controllo: V4, più thinking a high, confermata" 0 \
    "Haiku: token di ragionamento 105 a low (R1), 300 a high (R3); in uscita 110 e 320: confermata"
  expect "controllo: V4, da 0 a più di 0, confermata" 0 \
    "Sonnet: token di ragionamento 0 a low (R4), 120 a high (R5); in uscita 45 e 130: confermata"
  expect "controllo: i numeri, con la differenza" 0 \
    "  R3  haiku   high   no                     9:36        320       300          20"
  vero "controllo: prima i numeri, poi le affermazioni" in_ordine
  tabella "${f}" R1.token_thinking=0
  controlla "${f}"
  expect "controllo: V2 con 0, non confermata, uscita 0" 0 \
    "(R1: 0 token di ragionamento): non confermata in questa esecuzione"
  tabella "${f}" R2.token_thinking=0
  controlla "${f}"
  expect "controllo: V3 con 0, non dimostrata, uscita 0" 0 \
    "(R2: 0 token di ragionamento): ${V3_ZERO}"
  tabella "${f}" R7.token_thinking=10
  controlla "${f}"
  expect "controllo: V4 con meno thinking a high, non confermata" 0 \
    "24 a low (R6), 10 a high (R7); in uscita 29 e 205: non confermata in questa esecuzione"
  tabella "${f}" R3.token_thinking=105
  controlla "${f}"
  expect "controllo: V4 con tanto thinking quanto, non confermata" 0 \
    "105 a low (R1), 105 a high (R3); in uscita 110 e 320: non confermata in questa esecuzione"
  tabella "${f}" R5.token_thinking=0
  controlla "${f}"
  expect "controllo: V4 con 0 e 0, non distinguibile" 0 \
    "0 a low (R4), 0 a high (R5); in uscita 45 e 130: non distinguibile (uno 0 compare anche quando la suddivisione non è riportata)"
}

# Il controllo: la garanzia V1, e l'orario che non decide niente.
t_garanzia() {
  local f="${TMP}/g.tsv"
  tabella "${f}" R5.token_thinking=131
  controlla "${f}"
  expect "controllo: V1, thinking oltre l'uscita, esce 1" 1 \
    "la documentazione garantisce che thinking_tokens sia minore o uguale a output_tokens in ogni chiamata: in questa esecuzione no (R5: 131 su 130)"
  expect "controllo: V1 non confermata, gli altri verdetti ci sono" 1 \
    "  V4  un effort più elevato induce più ragionamento"
  expect "controllo: fuori dai limiti la differenza non si calcola" 1 \
    "       130       131           —"
  tabella "${f}" R4.token_thinking=-1
  controlla "${f}"
  expect "controllo: V1, thinking sotto zero, esce 1" 1 \
    "in questa esecuzione no (R4: -1 su 45)"
  tabella "${f}" R6.token_thinking=29
  controlla "${f}"
  expect "controllo: V1 con thinking uguale all'uscita, confermata" 0 \
    "(7 su 7): confermata"
  tabella "${f}" R1.orario= R3.orario=10:00
  controlla "${f}"
  expect "controllo: un orario vuoto o diverso non cambia l'esito" 0 \
    "  R1  haiku   low    no                     —           110       105"
  expect_absent "controllo: l'orario non è un verdetto" "10:00:"
}

# Il controllo: la tabella incompleta esce 1.
t_incompleta() {
  local f="${TMP}/i.tsv"
  tabella "${f}" R6=-
  controlla "${f}"
  expect "controllo: una riga che manca esce 1" 1 \
    "Manca la riga di R6 (opus, effort low)"
  tabella "${f}" R2=-
  controlla "${f}"
  expect "controllo: manca R2, detta con la sua variabile" 1 \
    "Manca la riga di R2 (haiku, effort low, MAX_THINKING_TOKENS=0)"
  tabella "${f}" R2.token_thinking=n/d
  controlla "${f}"
  expect "controllo: un numero che non è un numero esce 1" 1 \
    "token_thinking «n/d» non è un numero"
  tabella "${f}" "R3.token_uscita=$(printf '\xc2\xb2')"
  controlla "${f}"
  expect "controllo: «²» non è un numero" 1 "token_uscita «²» non è un numero"
  tabella "${f}" "R1.token_uscita=$(printf '9%.0s' {1..5000})"
  controlla "${f}"
  expect "controllo: un conteggio di 5000 cifre non è un numero" 1 \
    "R1 (haiku, effort low): token_uscita «99999"
  expect_absent "controllo: le 5000 cifre, senza traceback" "Traceback"
  tabella "${f}" R4.modello_id=
  controlla "${f}"
  expect "controllo: un modello_id vuoto esce 1" 1 \
    "Riga 5, R4 (sonnet, effort low): modello_id vuoto"
  tabella "${f}" R6=- "+opus\\tlow\\tno\\tclaude-opus-5-5\\t9:36\\t29"
  controlla "${f}"
  expect "controllo: campi in meno esce 1" 1 "6 campi invece di 7"
  printf 'problema\tmodello\tvariante\torario\ttoken_uscita\ttoken_thinking\n' \
    > "${f}"
  controlla "${f}"
  expect "controllo: l'intestazione vecchia esce 1" 1 \
    "la prima riga deve essere l'intestazione dei passi del README"
  : > "${f}"
  controlla "${f}"
  expect "controllo: un file vuoto esce 1" 1 "la prima riga deve essere"
  printf '\x00\xff\xfe\x80 a caso\n\x01\x02\n' > "${f}"
  controlla "${f}"
  expect "controllo: byte a caso escono 1" 1 "la prima riga deve essere"
}

# Il controllo: le righe ripetute o estranee, CRLF e BOM, i byte non
# UTF-8, l'uso.
t_righe() {
  local f="${TMP}/r.tsv" lunga
  tabella "${f}" R1.token_thinking=0 \
    "+haiku\\tlow\\tno\\tclaude-haiku-5-5\\t9:36\\t110\\t105"
  controlla "${f}"
  expect "controllo: di una chiamata conta l'ultima riga" 0 \
    "(R1: 105 token di ragionamento): confermata"
  tabella "${f}" \
    "+sonnet\\tlow\\tMAX_THINKING_TOKENS=0\\tclaude-sonnet-5-5\\t9:36\\t45\\t0"
  controlla "${f}"
  expect "controllo: una riga estranea si segnala e non conta" 0 \
    "Riga 9 ignorata: «sonnet, low, MAX_THINKING_TOKENS=0» non è una delle sette chiamate."
  tabella "${TMP}/r0.tsv"
  { printf '\xef\xbb\xbf'; sed 's/$/\r/' "${TMP}/r0.tsv"; } > "${f}"
  controlla "${f}"
  expect "controllo: CRLF e BOM" 0 "(7 su 7): confermata"
  tabella "${f}" R1=-
  printf 'haiku\tlow\tno\tclaude-haiku-5-5\t9:\xff\x00\x1b[31m\t110\t105\n' \
    >> "${f}"
  controlla "${f}"
  expect "controllo: byte non UTF-8 e di controllo nell'orario" 0 "??["
  expect_absent "controllo: nessun carattere di controllo a schermo" \
    "$(printf '\x1b')"
  lunga="$(printf 'x%.0s' {1..5000})"
  tabella "${f}" "+${lunga}"
  controlla "${f}"
  expect "controllo: una riga lunghissima si accorcia" 0 "xxxxxxx…» non è una"
  controlla "${f}" "${f}"
  expect "controllo: due argomenti, uso sbagliato" 2 "Uso:"
  controlla -h
  expect "controllo: un'opzione, uso sbagliato" 2 "Uso:"
  controlla "${TMP}/assente.tsv"
  expect "controllo: il file che manca esce 1" 1 \
    "Manca assente.tsv: eseguite i passi del README."
  controlla "${TMP}"
  expect "controllo: una cartella al posto del file esce 2" 2 "non si legge"
}

# Il controllo: un modello diverso da quello della riga esce 2.
t_modelli() {
  local f="${TMP}/m.tsv"
  tabella "${f}" R1.modello_id=claude-haiku-4-5
  controlla "${f}"
  expect "controllo: un altro modello esce 2" 2 \
    "ha risposto «claude-haiku-4-5», non claude-haiku-5-5"
  tabella "${f}" R5.modello_id=claude-opus-5-5
  controlla "${f}"
  expect "controllo: un 5.5 di un'altra famiglia esce 2" 2 \
    "ha risposto «claude-opus-5-5», non claude-sonnet-5-5"
  tabella "${f}" R7.modello_id=claude-opus-5-5,claude-haiku-5-5
  controlla "${f}"
  expect "controllo: due modelli in una riga escono 2" 2 \
    "le affermazioni messe alla prova riguardano claude-haiku-5-5"
  tabella "${f}" R1.modello_id=claude-haiku-4-5 R6=-
  controlla "${f}"
  expect "controllo: modello estraneo e riga mancante, esce 2" 2 \
    "Manca la riga di R6"
}

# verifica.sh, sui casi del contratto.
t_verifica() {
  local w
  run "${VERIFICA}" "${TMP}/assente"
  expect "verifica: spazio di lavoro assente" 2 "spazio di lavoro assente"
  ws w
  run "${VERIFICA}" "${w}"
  expect "verifica: il punto di partenza esce 1" 1 \
    "Manca ragionamento.tsv: eseguite i passi del README."
  tabella "${w}/ragionamento.tsv"
  run "${VERIFICA}" "${w}"
  expect "verifica: la tabella completa esce 0" 0 "(7 su 7): confermata"
  uguale "verifica: l'ultima riga è la frase finale" \
    "$(tail -n 1 <<< "${OUT}")" "${FATTO}"
  tabella "${w}/ragionamento.tsv" R1.token_thinking=0 R2.token_thinking=0 \
    R3.token_thinking=0 R5.token_thinking=0 R7.token_thinking=1
  run "${VERIFICA}" "${w}"
  expect "verifica: V2-V4 non confermate, esce 0 lo stesso" 0 "${FATTO}"
  tabella "${w}/ragionamento.tsv" R3.token_thinking=321
  run "${VERIFICA}" "${w}"
  expect "verifica: la garanzia non confermata esce 1" 1 \
    "in questa esecuzione no (R3: 321 su 320)"
  expect_absent "verifica: e niente frase finale" "Fatto:"
  tabella "${w}/ragionamento.tsv" R7=-
  run "${VERIFICA}" "${w}"
  expect "verifica: la tabella incompleta esce 1" 1 "Manca la riga di R7"
  tabella "${w}/ragionamento.tsv" R4.modello_id=claude-sonnet-4-5
  run "${VERIFICA}" "${w}"
  expect "verifica: un modello estraneo esce 2" 2 \
    "ha risposto «claude-sonnet-4-5»"
  ws w
  mkdir "${w}/ragionamento.tsv"
  run "${VERIFICA}" "${w}"
  expect "verifica: una cartella al posto del file esce 2" 2 "non si legge"
  if (( EUID == 0 )); then
    salta "verifica: da root ogni file si legge"
    return 0
  fi
  ws w
  tabella "${w}/ragionamento.tsv"
  chmod 000 "${w}/ragionamento.tsv"
  run "${VERIFICA}" "${w}"
  expect "verifica: il file che non si legge esce 2" 2 "non si legge"
}

# I passi del README, incollati come li incolla un partecipante.
t_readme() {
  local w
  estrai_passi
  uguale "README: sette chiamate nei passi" "$(grep -cE \
    '^(MAX_THINKING_TOKENS=0 )?chiedi (haiku|sonnet|opus) (low|high) ' \
    "${TMP}/passi.sh")" 7
  vero "README: il passo 2 toglie le due variabili" grep -qx \
    'unset CLAUDE_CODE_EFFORT_LEVEL MAX_THINKING_TOKENS' "${TMP}/passi.sh"
  ws w
  passi "${w}"
  cp "${TMP}/esca.log" "${TMP}/readme.log" || exit 2
  expect "README: i passi passano la verifica" 0 "${FATTO}"
  uguale "README: R2 con MAX_THINKING_TOKENS=0 nella tabella" \
    "$(campo "${w}" 3 3)" "MAX_THINKING_TOKENS=0"
  uguale "README: le altre righe con no" "$(awk -F'\t' \
    'NR > 1 && NR != 3 { print $3 }' "${w}/ragionamento.tsv" | sort -u)" "no"
  ws w
  passi "${w}" CLAUDE_CODE_EFFORT_LEVEL=high MAX_THINKING_TOKENS=5000
  vero "README: l'unset toglie le variabili; MAX_THINKING_TOKENS=0 a R2" \
    python3 -B -I "${TMP}/chiamate.py" attese "${TMP}/esca.log" "${ITEM}/demo"
  ws w
  passi "${w}" ESCA_CAMBIA=sonnet:low:-:esito=nojson
  expect "README: una risposta senza JSON, la riga incompleta" 1 \
    "Riga 5, R4 (sonnet, effort low): modello_id vuoto"
  ws w
  passi "${w}" ESCA_CAMBIA=sonnet:high:-:esito=errore
  expect "README: una risposta con is_error, la riga incompleta" 1 \
    "Riga 6, R5 (sonnet, effort high): modello_id vuoto"
  ws w
  passi "${w}" ESCA_CAMBIA=opus:low:-:esito=senzamodello
  expect "README: una risposta senza modelUsage, modello_id vuoto" 1 \
    "Riga 7, R6 (opus, effort low): modello_id vuoto"
  ws w
  passi "${w}" ESCA_CAMBIA=opus:high:-:esito=ko
  expect "README: una chiamata fallita, la riga incompleta" 1 \
    "Riga 8, R7 (opus, effort high): modello_id vuoto"
}

# live.sh: le precondizioni escono 2 senza nessuna chiamata a claude.
t_live_precondizioni() {
  local w
  esca "${LIVE}" "${TMP}/assente"
  expect "live.sh: spazio di lavoro assente" 2 "spazio di lavoro assente"
  uguale "live.sh: spazio di lavoro assente, nessuna chiamata" \
    "$(chiamate)" 0
  ws w
  esca CLAUDE_CODE_EFFORT_LEVEL=high "${LIVE}" "${w}"
  expect "live.sh: CLAUDE_CODE_EFFORT_LEVEL impostata esce 2" 2 \
    "CLAUDE_CODE_EFFORT_LEVEL è impostata («high»): vale più di --effort"
  uguale "live.sh: CLAUDE_CODE_EFFORT_LEVEL, nessuna chiamata" \
    "$(chiamate)" 0
  esca CLAUDE_CODE_EFFORT_LEVEL= "${LIVE}" "${w}"
  expect "live.sh: CLAUDE_CODE_EFFORT_LEVEL vuota esce 2" 2 \
    "CLAUDE_CODE_EFFORT_LEVEL è impostata"
  uguale "live.sh: CLAUDE_CODE_EFFORT_LEVEL vuota, nessuna chiamata" \
    "$(chiamate)" 0
  rm "${w}/direttamente.txt"
  esca "${LIVE}" "${w}"
  expect "live.sh: un file di partenza che manca esce 2" 2 \
    "file assente o illeggibile: direttamente.txt"
  uguale "live.sh: un file che manca, nessuna chiamata" "$(chiamate)" 0
}

# live.sh: le sette chiamate; MAX_THINKING_TOKENS=0 soltanto a R2; le
# stesse chiamate dei passi del README.
t_live() {
  local w
  ws w
  esca MAX_THINKING_TOKENS=5000 "${LIVE}" "${w}"
  cp "${TMP}/esca.log" "${TMP}/live.log" || exit 2
  expect "live.sh: le sette chiamate escono 0" 0 "VERIFICA OK"
  uguale "live.sh: i verdetti a schermo, una volta sola" \
    "$(grep -cF -- "${FATTO}" <<< "${OUT}")" 1
  expect "live.sh: dice che toglie MAX_THINKING_TOKENS" 0 \
    "MAX_THINKING_TOKENS è impostata: la tolgo, arriva soltanto a R2"
  uguale "live.sh: --version e sette chiamate" "$(chiamate)" 8
  vero "live.sh: MAX_THINKING_TOKENS=0 a R2 e a nessun'altra" \
    python3 -B -I "${TMP}/chiamate.py" attese "${TMP}/live.log" "${ITEM}/demo"
  uguale "live.sh: R2 con MAX_THINKING_TOKENS=0 nella tabella" \
    "$(campo "${w}" 3 3)" "MAX_THINKING_TOKENS=0"
  python3 -B -I "${TMP}/chiamate.py" stampa "${TMP}/readme.log" \
    > "${TMP}/readme.chiamate" || exit 2
  python3 -B -I "${TMP}/chiamate.py" stampa "${TMP}/live.log" \
    > "${TMP}/live.chiamate" || exit 2
  vero "README e live.sh mandano le stesse chiamate" cmp -s \
    "${TMP}/readme.chiamate" "${TMP}/live.chiamate"
  ws w
  esca ESCA_RISPOSTA='Non lo so.' "${LIVE}" "${w}"
  expect "live.sh: una risposta senza orario non è un KO" 0 "VERIFICA OK"
  uguale "live.sh: l'orario resta vuoto nella tabella" "$(campo "${w}" 2 5)" ""
}

# live.sh: le chiamate che falliscono e gli esiti diversi.
t_live_esiti() {
  local w
  ws w
  esca ESCA_CAMBIA=sonnet:high:-:esito=ko "${LIVE}" "${w}"
  expect "live.sh: una chiamata fallita esce 1" 1 \
    "VERIFICA KO   R5 (sonnet, high): claude -p è fallito"
  uguale "live.sh: si ferma lì (--version e cinque chiamate)" \
    "$(chiamate)" 6
  ws w
  esca ESCA_CAMBIA=haiku:low:-:esito=errore "${LIVE}" "${w}"
  expect "live.sh: una risposta con is_error esce 1" 1 \
    "R1 (haiku, low): il JSON non dice il modello o i token"
  uguale "live.sh: is_error, si ferma alla prima" "$(chiamate)" 2
  ws w
  esca ESCA_CAMBIA=haiku:high:-:esito=senzamodello "${LIVE}" "${w}"
  expect "live.sh: una risposta senza modelUsage esce 1" 1 \
    "R3 (haiku, high): il JSON non dice il modello o i token"
  ws w
  esca ESCA_CAMBIA=opus:low:-:esito=nojson "${LIVE}" "${w}"
  expect "live.sh: una risposta senza JSON esce 1" 1 \
    "R6 (opus, low): il JSON non dice il modello o i token"
  ws w
  esca ESCA_CAMBIA=haiku:low:-:id=claude-haiku-4-5 "${LIVE}" "${w}"
  expect "live.sh: un modello estraneo esce 2" 2 \
    "ha risposto «claude-haiku-4-5», non claude-haiku-5-5"
  ws w
  esca ESCA_CAMBIA=opus:high:-:thinking=206 "${LIVE}" "${w}"
  expect "live.sh: la garanzia non confermata esce 1" 1 \
    "in questa esecuzione no (R7: 206 su 205)"
  expect "live.sh: e il verdetto KO del controllo" 1 \
    "VERIFICA KO   tabella completa, thinking_tokens <= output_tokens (V1) (uscita 1)"
}

# In nessuna uscita delle prove un traceback, né «smentita».
t_uscite() {
  OUT="${TUTTE}"
  expect_absent "mai un traceback, nemmeno sui dati rovinati" "Traceback"
  expect_absent "mai «smentita»: uno 0 non smentisce" "smentit"
}

# Lo shellcheck degli script dell'elemento e di questo.
t_shellcheck() {
  local f
  for f in "${VERIFICA}" "${LIVE}" "${SELF}"; do
    vero "shellcheck ${f#"${MOD}"/}" shellcheck -x "${f}"
  done
}

main() {
  local t
  for t in python3 shellcheck; do
    command -v "${t}" > /dev/null 2>&1 \
      || { echo "test_m2_d05: manca ${t}" >&2; exit 2; }
  done
  for t in "${CONTROLLA}" "${VERIFICA}" "${LIVE}" "${ITEM}/README.md"; do
    [[ -f "${t}" ]] || { echo "test_m2_d05: manca ${t}" >&2; exit 2; }
  done
  unset CLAUDE_CODE_EFFORT_LEVEL MAX_THINKING_TOKENS ESCA_CAMBIA ESCA_RISPOSTA
  TMP="$(mktemp -d)" || exit 2
  trap 'chmod -R u+rwX "${TMP}" 2>/dev/null; rm -rf "${TMP}"' EXIT
  prepara_esca
  prepara_strumenti
  t_verdetti
  t_garanzia
  t_incompleta
  t_righe
  t_modelli
  t_verifica
  t_readme
  t_live_precondizioni
  t_live
  t_live_esiti
  t_uscite
  t_shellcheck
  echo "PASS=${PASS} FAIL=${FAIL} SKIP=${SKIP}"
  if (( PASS + FAIL + SKIP != CASES )); then
    echo "test_m2_d05: $((PASS + FAIL + SKIP)) prove, attese ${CASES}:" \
      "ne manca una, o ce n'è una in più" >&2
    exit 2
  fi
  (( FAIL == 0 )) || exit 1
}

main "$@"
