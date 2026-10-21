#!/bin/bash
#
# test_m3_e01.sh -- le prove di M3-E01 «Anonimizzare la settimana di
# ticket», per il docente:
#   - _docente/costruisci_impronte.py: con --controlla riproduce byte per
#     byte impronte.json e le copie di dati/; le copie sono uguali ai file
#     di progetti/assistenza-clienti/dati/; i numeri della verità del
#     progetto che tornano (47 telefoni, 12 e-mail, 6 MAC, 10 IP, le quattro
#     righe della salute); il controllo sul CSV grezzo trova ogni dato
#     elencato e nient'altro; sui testi grezzi con l'ultima o la prima
#     parola di ogni nome di persona al posto di un [OMESSO] trova un nome
#     a metà in ogni posto, con il nome intero nessuno; un controllo senza
#     la regola dei nomi a metà fa uscire --controlla con 1; la forma di
#     impronte.json (versione 2, le parti dei nomi); nessun valore su
#     STDOUT, i valori soltanto con --debug e soltanto su STDERR;
#   - esercizio/controlla_pii.py: sul CSV grezzo (con il nome del file
#     anonimo) trova residui in ogni classe ed esce 1, senza stampare un
#     valore (alcuni letti dal CSV al momento della prova); --forme
#     maschera; un telefono senza spazi, un nome in maiuscolo e un nome a
#     metà accanto a [OMESSO] (resta il nome o il cognome) sono residui,
#     non un nome staccato da una virgola o in minuscolo; sul file della
#     soluzione esce 0; ogni esecuzione aggiunge una riga al registro,
#     anche una precondizione; una colonna da togliere esce 1; le
#     precondizioni escono 2 (anche impronte.json di versione 1, senza le
#     parti, con una parte malformata); in ogni caso, anche con --forme,
#     l'ultima riga dice l'esito («uscita: N (…)»), con lo stesso codice
#     dell'uscita;
#   - verifica.sh: il punto di partenza (1), la soluzione (0), un KPI
#     sbagliato di uno (1), un telefono rimesso al suo posto (1), un nome a
#     metà (1), la regola della copia originale (un controlla_pii.py dello
#     spazio di lavoro che esce sempre 0 non basta), le esecuzioni del
#     registro soltanto come dato e senza esito; come dato, mai come
#     uscita, i dati del corso rimasti in parte (un civico, il dominio di
#     un'e-mail) e le omissioni senza un dato del corso (una in più, tutto
#     omesso); le forme sbagliate del file (colonne, righe, pseudonimi,
#     testo riscritto, colonna cambiata, BOM, CRLF), il profilo (manca, non
#     è JSON, una chiave in più), le precondizioni (2);
#   - soluzione/: anonimizza.py e profilo.py, eseguiti in uno spazio di
#     lavoro nuovo, riproducono byte per byte i file di soluzione/anonimo/;
#     prepara_esercizio.sh e tools/verifica.sh con l'elemento vero;
#   - _docente/residui.py: per classe, i dati rimasti in parte e le
#     omissioni senza un dato del corso (null se i testi non si allineano),
#     la coppia (confermata, non distinguibile, non confermata in questa
#     esecuzione; non decidibile se un file manca; mai «smentita»), un
#     testo qualunque, senza valori;
#   - _docente/live.sh con un claude finto: le precondizioni escono 2 senza
#     chiamare claude (anche impostazioni senza regole Bash); una sessione
#     che finisce al primo turno, una che finisce al secondo (con
#     --resume), una che non finisce (quattro chiamate, uscita 1), una a
#     cui manca il profilo, una chiamata fallita; le opzioni passate a
#     claude (Read, Write, Edit e le regole Bash delle impostazioni,
#     --strict-mcp-config), il prompt uguale a quello del README,
#     ANTHROPIC_API_KEY tolta;
#   - .claude/settings.json (con le regole deny di Edit sul controllo e
#     sulle impronte), il README (il prompt fra i segni; un comando alla
#     volta, anche senza il paragrafo del controllo; l'esito dalla sua
#     ultima riga, non da $?; la versione breve in 19 righe × 66 colonne,
#     con le stesse due regole; il percorso A con le colonne che il
#     controllo chiede; le dieci sezioni; nessun identificativo interno nei
#     file per i partecipanti); i turni di live.sh dopo il primo chiedono
#     anche loro un comando alla volta;
#   - shellcheck -x sugli script dell'elemento e su questo.
# Gli spazi di lavoro nascono in una cartella temporanea, nella base di
# handson::init_temp_base (mai dentro ~/.claude, anche se TMPDIR punta
# lì): l'albero del repository non cambia. Nessun dato personale compare
# nell'uscita delle
# prove: quelli che servono si leggono in variabili, e l'uscita di una
# prova fallita li copre con «<valore>». I casi si contano: da root il caso
# del file che non si legge è saltato (SKIP), e un numero di casi diverso
# da CASES esce 2.
#
# Uso:    m3_funzionalita_claude/_docente/test_m3_e01.sh
# Uscita: 0 = tutte le prove passano · 1 = almeno una fallita ·
#         2 = precondizione (manca python3, jq o shellcheck, un file
#             dell'elemento; una preparazione non riesce; le prove eseguite
#             non sono quante attese)
set -uo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly MOD="${SELF%/_docente/*}"
readonly RADICE="${MOD%/*}"
readonly E01="${MOD}/s2_funzionalita_claude/m3_e2_anonimizzare/\
M3-E01_anonimizzare_ticket"
readonly PROGETTO="${RADICE}/progetti/assistenza-clienti"
# La libreria del repository, per la base dei file temporanei
# (handson::init_temp_base): mai dentro ~/.claude, dove prepara_esercizio.sh
# rifiuta gli spazi di lavoro, anche se TMPDIR punta lì.
# shellcheck source=../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"
readonly CASES=176
readonly FINE="Fatto: il file anonimo, i dati personali rimasti e il \
profilo sono quelli attesi."
# L'ora UTC in testa a una riga di controlli.log (espressione estesa).
readonly RIGA_LOG='^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z'
# Gli identificativi interni che i file per i partecipanti non portano.
INTERNI='FACT-|Tecnodata|[Tt]riage|Envelope|M[0-9]-X[0-9]|\bX-[0-9]'
INTERNI+='|\b(ASK|OQ|DEC|TD|PQ)-[0-9]'
readonly INTERNI
TMP=''
FX=''
PASS=0
FAIL=0
SKIP=0
RC=0
OUT=''
VALORI=()

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }
# Un caso che da root non può girare: contato a parte, mai come passato.
skip() { echo "  SKIP: $1"; SKIP=$((SKIP + 1)); }

# Esegue un comando; RC e OUT (STDOUT e STDERR insieme) per expect.
run() { OUT="$("$@" 2>&1)"; RC=$?; }

# OUT, con ogni dato personale letto dal CSV coperto da «<valore>», e al
# più 600 caratteri: quello che una prova fallita può stampare.
sicuro() {
  local testo="${OUT}" v
  for v in "${VALORI[@]}"; do
    testo="${testo//"${v}"/<valore>}"
  done
  printf '%s' "${testo:0:600}"
}

# Uscita attesa E parola chiave attesa (RU-01.T3).
# Arguments: $1 il nome, $2 l'uscita attesa, $3 la parola (grep -F).
expect() {
  if (( RC == $2 )) && grep -qF -- "$3" <<< "${OUT}"; then
    pass "$1"
  else
    fail "$1 (rc=${RC}, attesa $2, parola «$3»): $(sicuro)"
  fi
}

# Nessun falso positivo: la parola NON c'è (RU-01.T5).
# Arguments: $1 il nome, $2 la parola.
expect_absent() {
  if grep -qF -- "$2" <<< "${OUT}"; then
    fail "$1: «$2» c'è: $(sicuro)"
  else
    pass "$1"
  fi
}

# Uscita attesa E l'ultima riga di OUT (STDOUT e STDERR insieme), uguale
# carattere per carattere: la riga finale del controllo.
# Arguments: $1 il nome, $2 l'uscita attesa, $3 l'ultima riga attesa.
expect_ultima() {
  local ultima
  ultima="$(tail -n 1 <<< "${OUT}")"
  if (( RC == $2 )) && [[ "${ultima}" == "$3" ]]; then
    pass "$1"
  else
    fail "$1 (rc=${RC}, attesa $2, ultima riga attesa «$3»): $(sicuro)"
  fi
}

# Uscita attesa E la riga di una classe con i residui attesi.
# Arguments: $1 il nome, $2 l'uscita attesa, $3 la classe, $4 i residui.
expect_classe() {
  if (( RC == $2 )) && grep -qE "^  $3 +$4  " <<< "${OUT}"; then
    pass "$1"
  else
    fail "$1 (rc=${RC}, attesa $2, $3 $4): $(sicuro)"
  fi
}

# Nessuno dei dati personali letti dal CSV compare in OUT; una prova
# fallita non dice quale.
nessun_valore() {
  local v
  for v in "${VALORI[@]}"; do
    if [[ "${OUT}" == *"${v}"* ]]; then
      fail "$1: un dato personale in chiaro nell'uscita (non lo stampo)"
      return 0
    fi
  done
  pass "$1"
}

# La preparazione di una prova che non riesce: uscita 2.
rotta() { echo "test_m3_e01: preparazione non riuscita: $*" >&2; exit 2; }

# Un nuovo spazio di lavoro dal punto di partenza, più facoltativamente
# la soluzione («soluzione») o il CSV grezzo al posto del file anonimo
# («grezzo»). Arguments: $1 la variabile da assegnare, $2 il tipo.
ws() {
  local __ws_d
  __ws_d="$(mktemp -d "${TMP}/ws.XXXXXX")" || rotta "mktemp"
  cp -R "${E01}/esercizio/." "${__ws_d}/" || rotta "cp esercizio"
  case "${2:-}" in
    soluzione) cp -R "${E01}/soluzione/." "${__ws_d}/" || rotta "cp sol" ;;
    grezzo)
      mkdir -p "${__ws_d}/anonimo" || rotta "mkdir"
      cp "${__ws_d}/dati/ticket-settimana.csv" \
        "${__ws_d}/anonimo/ticket-anonimi.csv" || rotta "cp grezzo" ;;
  esac
  printf -v "$1" '%s' "${__ws_d}"
}

# Una modifica dei file con fx.py; la preparazione rotta esce 2.
fx() { python3 -B -I "${FX}" "$@" || rotta "fx $*"; }

# Il controllo di uno spazio di lavoro, eseguito nella sua cartella.
# Arguments: $1 lo spazio, poi gli argomenti di controlla_pii.py.
controllo() {
  local w="$1"
  shift
  run bash -c 'cd "$1" && shift && python3 -B controlla_pii.py "$@"' _ \
    "${w}" "$@"
}

# La verifica dell'elemento su uno spazio di lavoro.
verifica() { run "${E01}/verifica.sh" "$1"; }

# fx.py, il claude finto, il claude esca e i dati personali da non vedere.
prepara() {
  FX="${TMP}/fx.py"
  mkdir -p "${TMP}/finto" "${TMP}/esca" || rotta "mkdir"
  cat > "${FX}" <<'PY' || rotta "fx.py"
"""fx.py -- letture e modifiche delle prove di M3-E01. Non stampa mai un
dato personale, salvo «valori», che le prove leggono in una variabile."""
import csv
import json
import os
import re
import sys

# Un nome di persona del CSV accanto a [OMESSO]: a metà (il nome o il
# cognome), staccato da una virgola, in minuscolo; una parola qualunque.
A_META = {"nome_a_meta": " Firmato: %(nome)s [OMESSO].",
          "cognome_a_meta": " Firmato: [OMESSO] %(cognome)s.",
          "nome_virgola": " Firmati: %(nome)s, [OMESSO].",
          "nome_minuscolo_a_meta": " firmato da %(minuscolo)s [OMESSO].",
          "parola_a_meta": " Guasto [OMESSO] risolto."}


def leggi(p):
    with open(p, encoding="utf-8-sig", newline="") as fh:
        righe = list(csv.reader(fh))
    return righe[0], righe[1:]


def scrivi(p, intestazione, righe, fine="\n", bom=False):
    with open(p, "w", encoding="utf-8", newline="") as fh:
        if bom:
            fh.write("﻿")
        w = csv.writer(fh, lineterminator=fine)
        w.writerow(intestazione)
        w.writerows(righe)


def indice(intestazione):
    return {c: n for n, c in enumerate(intestazione)}


def valori(grezzo):
    gi, gr = leggi(grezzo)
    x = indice(gi)

    def primo(col, tipo=None):
        return next(r[x[col]] for r in gr if r[x[col]]
                    and (tipo is None or r[x["tipo_cliente"]] == tipo))
    for v in (primo("telefono"), primo("email"),
              primo("nome_cliente", "privato"), primo("id_cliente"),
              primo("id_linea")):
        print(v)


def telefono_indietro(ws):
    """Rimette in una descrizione anonima il telefono che vi era tolto."""
    gi, gr = leggi(os.path.join(ws, "dati", "ticket-settimana.csv"))
    anon = os.path.join(ws, "anonimo", "ticket-anonimi.csv")
    ai, ar = leggi(anon)
    gx, ax = indice(gi), indice(ai)
    for g, r in zip(gr, ar):
        tel, d = g[gx["telefono"]], g[gx["descrizione"]]
        if tel and tel in d and \
                r[ax["descrizione"]] == d.replace(tel, "[OMESSO]"):
            r[ax["descrizione"]] = d
            scrivi(anon, ai, ar)
            return 0
    return 1


def modifica(ws, cosa):
    anon = os.path.join(ws, "anonimo", "ticket-anonimi.csv")
    ai, ar = leggi(anon)
    ax = indice(ai)
    gi, gr = leggi(os.path.join(ws, "dati", "ticket-settimana.csv"))
    gx = indice(gi)
    if cosa == "colonna_in_piu":
        ai.append("email")
        for r in ar:
            r.append("")
    elif cosa == "togli_riga":
        ar.pop()
    elif cosa == "pseudonimo":
        clienti = [r[ax["cliente"]] for r in ar if r[ax["cliente"]]]
        altro = next(c for c in clienti if c != ar[0][ax["cliente"]])
        ar[0][ax["cliente"]] = altro
    elif cosa == "riscrivi":
        r = next(r for r in ar if "[OMESSO]" in r[ax["descrizione"]])
        r[ax["descrizione"]] = r[ax["descrizione"]].replace(
            "[OMESSO]", "[REDATTO]", 1)
    elif cosa == "comune":
        r = next(r for r in ar if r[ax["comune"]] != r[ax["comune"]].upper())
        r[ax["comune"]] = r[ax["comune"]].upper()
    elif cosa == "telefono_compatto":
        tel = next(r[gx["telefono"]] for r in gr if r[gx["telefono"]])
        ar[0][ax["descrizione"]] += " Tel. " + tel.replace(" ", "")
    elif cosa == "nome_maiuscolo":
        nome = next(r[gx["nome_cliente"]] for r in gr
                    if r[gx["tipo_cliente"]] == "privato")
        ar[0][ax["descrizione"]] += " Firmato: " + nome.upper()
    elif cosa in A_META:
        nome, cognome = next(r[gx["nome_cliente"]] for r in gr if r[gx[
            "tipo_cliente"]] == "privato").split(" ", 1)
        ar[0][ax["descrizione"]] += A_META[cosa] % {
            "nome": nome, "cognome": cognome, "minuscolo": nome.lower()}
    elif cosa == "omissione_in_piu":
        r = next(r for r in ar if "[OMESSO]" not in r[ax["oggetto"]]
                 and re.search(r"[^\W\d_]{4,}", r[ax["oggetto"]]))
        r[ax["oggetto"]] = re.sub(r"[^\W\d_]{4,}", "[OMESSO]",
                                  r[ax["oggetto"]], count=1)
    elif cosa == "tutto_omesso":
        for r in ar:
            r[ax["oggetto"]] = r[ax["descrizione"]] = "[OMESSO]"
    elif cosa in ("bom", "crlf"):
        scrivi(anon, ai, ar, "\r\n" if cosa == "crlf" else "\n",
               cosa == "bom")
        return 0
    else:
        return 2
    scrivi(anon, ai, ar)
    return 0


def kpi(ws, chiave, valore):
    p = os.path.join(ws, "anonimo", "profilo.json")
    with open(p, encoding="utf-8") as fh:
        profilo = json.load(fh)
    profilo["kpi"][chiave] = json.loads(valore)
    with open(p, "w", encoding="utf-8") as fh:
        json.dump(profilo, fh)


def testo_con_telefono(grezzo, uscita):
    gi, gr = leggi(grezzo)
    x = indice(gi)
    tel = next(r[x["telefono"]] for r in gr if r[x["telefono"]])
    with open(uscita, "w", encoding="utf-8") as fh:
        fh.write("Una riga di prova.\nIl numero era %s, poi basta.\n" % tel)


def forma_impronte(p):
    with open(p, encoding="utf-8") as fh:
        d = json.load(fh)

    def elenco(v):
        return v == sorted(set(v)) and v and all(
            len(x) == 64 and set(x) <= set("0123456789abcdef") for x in v)
    classi, parti = d["classi"], d.get("parti")
    ok = d["versione"] == 2 and isinstance(d["sale"], str) and \
        len(classi) == 11 and all(elenco(v) for v in classi.values()) \
        and isinstance(parti, dict) and sorted(parti) == ["familiari", "nomi"] \
        and all(elenco(v) for v in parti.values())
    return 0 if ok else 1


def impronte(p, cosa):
    """impronte.json cambiato: la versione 1, senza le parti, senza le
    parti dei familiari, una parte o un'impronta malformate, senza
    impronte."""
    with open(p, encoding="utf-8") as fh:
        d = json.load(fh)
    if cosa == "versione_1":
        d["versione"] = 1
    elif cosa == "senza_parti":
        del d["parti"]
    elif cosa == "senza_familiari":
        d["parti"] = {"nomi": d["parti"]["nomi"]}
    elif cosa == "parte_malformata":
        d["parti"]["familiari"] = ["non-esadecimale"]
    elif cosa == "impronta_malformata":
        d["classi"]["nomi"] = ["non-esadecimale"]
    elif cosa == "senza_impronte":
        d["classi"] = {k: [] for k in d["classi"]}
    else:
        return 2
    with open(p, "w", encoding="utf-8") as fh:
        json.dump(d, fh)
    return 0


def controllo_di(e01):
    """Il controllo originale dell'elemento e le sue impronte."""
    sys.path.insert(0, os.path.join(e01, "esercizio"))
    import controlla_pii
    return controlla_pii, controlla_pii.carica_impronte(
        os.path.join(e01, "esercizio", "impronte.json"))


def adatto(cp, imp, valore, come):
    """Un dato su cui la modifica si può fare: per «ultima» un nome di
    persona di due parole, per «civico» un indirizzo con il numero, per
    «dominio» un'e-mail."""
    if come == "ultima":
        parole = valore.split(" ")
        return len(parole) == 2 and all(
            cp.impronta(imp.sale, cp.piega(p)) in imp.parti["nomi"]
            for p in parole)
    if come == "civico":
        return valore.rsplit(" ", 1)[-1].isdigit()
    return "@" in valore


def resta(valore, come):
    """Quello che resta del dato: il nome senza l'ultima parola, il solo
    civico, il solo dominio, con [OMESSO] al posto del resto."""
    if come == "ultima":
        return valore.rsplit(" ", 1)[0] + " [OMESSO]"
    if come == "civico":
        return "[OMESSO] " + valore.rsplit(" ", 1)[1]
    return "[OMESSO]" + valore[valore.index("@"):]


def parziale(ws, e01, classe, come):
    """Nel file anonimo, un testo rifatto dal grezzo con [OMESSO] al posto
    di ogni dato del corso, salvo il primo adatto della classe, che resta
    in parte. Uscita 1 se non c'è."""
    cp, imp = controllo_di(e01)
    gi, gr = leggi(os.path.join(ws, "dati", "ticket-settimana.csv"))
    anon = os.path.join(ws, "anonimo", "ticket-anonimi.csv")
    ai, ar = leggi(anon)
    gx, ax = indice(gi), indice(ai)
    for g, r in zip(gr, ar):
        for col in ("descrizione", "oggetto"):
            testo = g[gx[col]]
            trovati = cp.cerca(testo, imp)
            scelto = next((t for t in trovati if t[0] == classe and adatto(
                cp, imp, testo[t[1]:t[2]], come)), None)
            if scelto is None:
                continue
            pezzi, pos = [], 0
            for t in trovati:
                pezzi += [testo[pos:t[1]], resta(testo[t[1]:t[2]], come)
                          if t == scelto else "[OMESSO]"]
                pos = t[2]
            r[ax[col]] = "".join(pezzi) + testo[pos:]
            scrivi(anon, ai, ar)
            return 0
    return 1


def main(a):
    if a[0] == "valori":
        valori(a[1])
        return 0
    if a[0] == "telefono_indietro":
        return telefono_indietro(a[1])
    if a[0] == "modifica":
        return modifica(a[1], a[2])
    if a[0] == "kpi":
        kpi(a[1], a[2], a[3])
        return 0
    if a[0] == "testo_con_telefono":
        testo_con_telefono(a[1], a[2])
        return 0
    if a[0] == "forma_impronte":
        return forma_impronte(a[1])
    if a[0] == "parziale":
        return parziale(a[1], a[2], a[3], a[4])
    if a[0] == "impronte":
        return impronte(a[1], a[2])
    return 2


sys.exit(main(sys.argv[1:]))
PY
  cat > "${TMP}/finto/claude" <<'PY' || rotta "il claude finto"
#!/usr/bin/env python3
"""Un claude finto per live.sh di M3-E01: risponde come claude -p
--output-format json e intanto fa il lavoro nello spazio di lavoro (la
cartella corrente), secondo FINTO_MODO: completo (gli script della
soluzione, il controllo, il profilo), a_rate (al primo turno uno script che
non toglie niente, con --resume la soluzione), mai (sempre lo script che non
toglie niente), senza_profilo (al primo turno niente profilo). Con
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
COLONNE = ("id_ticket", "aperto_il", "chiuso_il", "canale", "cliente",
           "tipo_cliente", "comune", "tecnologia", "categoria", "priorita",
           "stato", "oggetto", "descrizione", "team",
           "minuti_prima_risposta", "minuti_risoluzione", "soddisfazione")
CATTIVO = '''import csv, os
COLONNE = %r
righe = list(csv.DictReader(open("dati/ticket-settimana.csv",
                                 encoding="utf-8", newline="")))
os.makedirs("anonimo", exist_ok=True)
pseudonimi = {}
with open("anonimo/ticket-anonimi.csv", "w", encoding="utf-8",
          newline="") as fh:
    w = csv.writer(fh, lineterminator="\\n")
    w.writerow(COLONNE)
    for r in righe:
        c = r["id_cliente"]
        if c and c not in pseudonimi:
            pseudonimi[c] = "C-%%03d" %% (len(pseudonimi) + 1)
        r = dict(r, cliente=pseudonimi.get(c, ""))
        w.writerow([r[k] for k in COLONNE])
''' % (COLONNE,)


def esegui(*argomenti):
    subprocess.run([sys.executable, "-B"] + list(argomenti), check=False,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def buono(profilo):
    sol = os.environ["FINTO_SOLUZIONE"]
    for nome in ("anonimizza.py", "profilo.py"):
        shutil.copy(os.path.join(sol, nome), nome)
    esegui("anonimizza.py")
    esegui("controlla_pii.py")
    if profilo:
        esegui("profilo.py")


def cattivo():
    with open("anonimizza.py", "w", encoding="utf-8") as fh:
        fh.write(CATTIVO)
    esegui("anonimizza.py")
    esegui("controlla_pii.py")


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
    if modo == "completo" or (modo == "a_rate" and ripresa):
        buono(True)
    elif modo in ("a_rate", "mai"):
        cattivo()
    elif modo == "senza_profilo":
        if ripresa:
            esegui("profilo.py")
        else:
            buono(False)
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
  local v
  while IFS= read -r v; do
    VALORI+=("${v}")
  done < <(python3 -B -I "${FX}" valori \
    "${E01}/esercizio/dati/ticket-settimana.csv")
  (( ${#VALORI[@]} == 5 )) || rotta "i dati personali da cercare"
}

# costruisci_impronte.py --controlla in una copia dell'elemento in cui il
# controllo non ha la regola dei nomi a metà: la proprietà non tiene, e
# l'uscita è 1 anche se i file sono identici.
senza_regola() {
  local copia
  copia="$(mktemp -d "${TMP}/elemento.XXXXXX")" || rotta "mktemp"
  cp -R "${E01}/." "${copia}/" || rotta "cp elemento"
  printf '\n\ndef _nomi_a_meta(*_argomenti):\n    return []\n' \
    >> "${copia}/esercizio/controlla_pii.py" || rotta "la regola tolta"
  run env PN_HANDSON_ROOT="${RADICE}" python3 -B -I \
    "${copia}/_docente/costruisci_impronte.py" --controlla
  expect "senza la regola dei nomi a metà --controlla esce 1" 1 \
    "senza un nome a metà"
  expect "senza la regola: i file restano identici" 1 \
    "Identici byte per byte: esercizio/impronte.json"
  nessun_valore "senza la regola: nessun valore su STDOUT"
}

# Le impronte: la ricostruzione, le copie, i conteggi, i valori.
t_impronte() {
  local costruisci="${E01}/_docente/costruisci_impronte.py" d std
  run python3 -B -I "${costruisci}" --controlla
  expect "costruisci_impronte --controlla: identici" 0 \
    "Identici byte per byte: esercizio/impronte.json"
  expect "il generatore riproduce il CSV" 0 \
    "riproduce dati/ticket-settimana.csv"
  expect "il controllo trova ogni dato elencato e nient'altro" 0 \
    "trova ogni dato elencato"
  expect "verità: 47 telefoni" 0 "47 telefoni; nei testi 47 occorrenze"
  expect "verità: 12 e-mail (con le utenze PPPoE)" 0 \
    "12 e-mail; nei testi 12 occorrenze"
  expect "verità: 6 MAC" 0 "6 indirizzi MAC; nei testi 6 occorrenze"
  expect "verità: 10 IP (righe)" 0 "nei testi 11 occorrenze in 10 righe"
  expect "verità: le quattro righe della salute" 0 "salute nelle righe: \
TK-2026-04286, TK-2026-04312, TK-2026-04345, TK-2026-04553"
  expect "nomi a metà: l'ultima parola di ogni nome al posto di [OMESSO]" 0 \
    "Con l'ultima parola di ogni nome di persona al posto di un [OMESSO], \
il controllo trova un nome a metà in ognuno dei"
  expect "nomi a metà: la prima parola di ogni nome al posto di [OMESSO]" 0 \
    "Con la prima parola di ogni nome di persona al posto di un [OMESSO], \
il controllo trova un nome a metà in ognuno dei"
  expect "nomi interi al posto di [OMESSO]: nessun nome a metà" 0 \
    "Con il nome intero al posto di un [OMESSO], il controllo non trova \
nessun nome a metà"
  nessun_valore "costruisci_impronte: nessun valore su STDOUT"
  for d in ticket-settimana.csv README.md; do
    if cmp -s "${E01}/esercizio/dati/${d}" "${PROGETTO}/dati/${d}"; then
      pass "esercizio/dati/${d} uguale a quello del progetto"
    else
      fail "esercizio/dati/${d} diverso da quello del progetto"
    fi
  done
  run python3 -B -I "${FX}" forma_impronte "${E01}/esercizio/impronte.json"
  expect "impronte.json: versione 2, sale, 11 classi, le parti, ordinate" 0 ""
  senza_regola
  std="$(python3 -B -I "${costruisci}" --controlla --debug \
    2> "${TMP}/debug.err")"
  OUT="${std}"
  nessun_valore "--debug: nessun valore su STDOUT"
  if grep -qF -- "${VALORI[0]}" "${TMP}/debug.err"; then
    pass "--debug: i valori su STDERR"
  else
    fail "--debug: i valori non sono su STDERR"
  fi
  run python3 -B -I "${costruisci}" --boh
  expect "costruisci_impronte: un argomento sconosciuto esce 2" 2 \
    "argomenti non riconosciuti"
}

# I nomi a metà accanto a [OMESSO], sul file della soluzione: il nome o il
# cognome che resta è un residuo di nomi; non un nome staccato da una
# virgola, né in minuscolo, né una parola qualunque.
t_controllo_a_meta() {
  local w cosa
  for cosa in nome_a_meta cognome_a_meta; do
    ws w soluzione
    fx modifica "${w}" "${cosa}"
    controllo "${w}" --forme
    expect_classe "${cosa}: un residuo di nomi" 1 nomi 1
    expect_ultima "${cosa}: l'ultima riga dice uscita 1" 1 \
      "uscita: 1 (restano dati personali: vedi sopra)"
    nessun_valore "${cosa}: nessun valore in chiaro"
  done
  for cosa in nome_virgola nome_minuscolo_a_meta parola_a_meta; do
    ws w soluzione
    fx modifica "${w}" "${cosa}"
    controllo "${w}"
    expect_ultima "${cosa}: nessun residuo, esce 0" 0 \
      "uscita: 0 (nessun dato personale rimasto)"
  done
}

# Il controllo sul CSV grezzo e sulla soluzione.
t_controllo() {
  local w classe mancanti=''
  ws w grezzo
  controllo "${w}"
  expect_ultima "controlla_pii sul grezzo: esce 1, e lo dice l'ultima riga" 1 \
    "uscita: 1 (restano dati personali e colonne da togliere: vedi sopra)"
  for classe in nomi familiari indirizzi telefoni email utenze_pppoe mac ip \
      codici_cliente codici_linea salute; do
    grep -qE "^  ${classe} +[1-9][0-9]* " <<< "${OUT}" \
      || mancanti+=" ${classe}"
  done
  if [[ -z "${mancanti}" ]]; then
    pass "controlla_pii sul grezzo: residui in ogni classe"
  else
    fail "controlla_pii sul grezzo: nessun residuo in${mancanti}"
  fi
  expect "controlla_pii sul grezzo: le colonne da togliere" 1 \
    "Colonne da togliere ancora nell'intestazione: nome_cliente"
  nessun_valore "controlla_pii sul grezzo: nessun valore in chiaro"
  controllo "${w}" --forme
  expect "--forme: la forma di un telefono" 1 "+99 999 999 9999"
  expect "--forme: la colonna del residuo" 1 "  descrizione  "
  expect_ultima "--forme: l'ultima riga dice l'esito" 1 \
    "uscita: 1 (restano dati personali e colonne da togliere: vedi sopra)"
  nessun_valore "--forme: nessun valore in chiaro"
  ws w soluzione
  controllo "${w}"
  expect_ultima "controlla_pii sulla soluzione: esce 0, e lo dice l'ultima" 0 \
    "uscita: 0 (nessun dato personale rimasto)"
  expect_absent "controlla_pii sulla soluzione: nessun residuo" "uscita: 1"
  controllo "${w}" --forme
  expect_ultima "--forme sulla soluzione: l'ultima riga dice uscita 0" 0 \
    "uscita: 0 (nessun dato personale rimasto)"
  fx modifica "${w}" telefono_compatto
  controllo "${w}"
  expect "un telefono senza spazi è un residuo" 1 "Residui: 1 in 1"
  ws w soluzione
  fx modifica "${w}" nome_maiuscolo
  controllo "${w}" --forme
  expect "un nome in maiuscolo è un residuo" 1 "XXXXX"
  expect_ultima "--forme con soli residui: l'ultima riga" 1 \
    "uscita: 1 (restano dati personali: vedi sopra)"
  nessun_valore "un nome in maiuscolo: nessun valore in chiaro"
  t_controllo_a_meta
  ws w soluzione
  fx modifica "${w}" colonna_in_piu
  controllo "${w}"
  expect "una colonna da togliere esce 1" 1 \
    "Colonne da togliere ancora nell'intestazione: email."
  expect_ultima "una colonna da togliere: l'ultima riga" 1 \
    "uscita: 1 (restano colonne da togliere: vedi sopra)"
  run python3 -B -I -c 'import sys; sys.path.insert(0, sys.argv[1])
import controlla_pii as c
print(c.maschera("Ab-1 cD.é"))' "${E01}/esercizio"
  expect "maschera: lettere x/X, cifre 9, il resto com'è" 0 "Xx-9 xX.x"
}

# Il registro del controllo: una riga per esecuzione, anche per una
# precondizione.
t_registro() {
  local w righe
  ws w soluzione
  rm -f "${w}/anonimo/controlli.log"
  controllo "${w}"
  controllo "${w}" --forme
  righe="$(grep -cE "${RIGA_LOG}"$'\t0\t0$' "${w}/anonimo/controlli.log")"
  if (( righe == 2 )); then
    pass "il registro: due esecuzioni, due righe ora-uscita-residui"
  else
    fail "il registro: ${righe} righe nella forma attesa, attese 2"
  fi
  ws w
  controllo "${w}"
  expect "file anonimo assente: esce 2" 2 "non c'è"
  expect_ultima "file anonimo assente: l'ultima riga, dopo l'errore" 2 \
    "uscita: 2 (il controllo non ha potuto girare: vedi sopra)"
  if grep -qE $'\t2\t-$' "${w}/anonimo/controlli.log" 2>/dev/null; then
    pass "una precondizione si registra con uscita 2 e residui «-»"
  else
    fail "una precondizione non è nel registro"
  fi
  ws w soluzione
  rm "${w}/anonimo/controlli.log" || rotta "rm"
  mkdir "${w}/anonimo/controlli.log" || rotta "mkdir"
  controllo "${w}"
  expect_ultima "il registro che non si scrive esce 2, e lo dice" 2 \
    "uscita: 2 (il registro controlli.log non si scrive: vedi sopra)"
}

# impronte.json dello spazio di lavoro: la copia dell'elemento, cambiata
# da fx.py. Arguments: $1 lo spazio di lavoro, $2 la modifica.
impronte_cambiate() {
  cp "${E01}/esercizio/impronte.json" "$1/impronte.json" || rotta "cp"
  fx impronte "$1/impronte.json" "$2"
}

# Le precondizioni del controllo: uscita 2.
t_controllo_precondizioni() {
  local w
  ws w soluzione
  printf '\xff\xfe\x00' > "${w}/anonimo/ticket-anonimi.csv"
  controllo "${w}"
  expect "un file non UTF-8 esce 2" 2 "non è un testo UTF-8"
  printf 'a,b\n1,2\n' > "${w}/anonimo/ticket-anonimi.csv"
  controllo "${w}"
  expect "senza id_ticket esce 2" 2 "manca la colonna id_ticket"
  printf 'id_ticket,b\n1,2,3\n' > "${w}/anonimo/ticket-anonimi.csv"
  controllo "${w}"
  expect "una riga con un campo in più esce 2" 2 "ha 3 campi invece di 2"
  printf 'id_ticket,b\n' > "${w}/anonimo/ticket-anonimi.csv"
  controllo "${w}"
  expect "solo l'intestazione esce 2" 2 "niente da controllare"
  ws w soluzione
  rm "${w}/impronte.json"
  controllo "${w}"
  expect "senza impronte.json esce 2" 2 "manca impronte.json"
  printf '{' > "${w}/impronte.json"
  controllo "${w}"
  expect "impronte.json non JSON esce 2" 2 "non è un JSON valido"
  printf '%s' '{"versione":2,"sale":"s","classi":{"nomi":[]},' \
    '"parti":{"nomi":[],"familiari":[]}}' > "${w}/impronte.json"
  controllo "${w}"
  expect "impronte.json senza tutte le classi esce 2" 2 "le classi non sono"
  impronte_cambiate "${w}" versione_1
  controllo "${w}"
  expect "impronte.json di versione 1 esce 2" 2 "servono versione 2"
  impronte_cambiate "${w}" senza_parti
  controllo "${w}"
  expect "impronte.json senza le parti dei nomi esce 2" 2 \
    "sale, classi e parti"
  impronte_cambiate "${w}" senza_familiari
  controllo "${w}"
  expect "impronte.json senza le parti dei familiari esce 2" 2 \
    "le parti non sono quelle del controllo"
  impronte_cambiate "${w}" parte_malformata
  controllo "${w}"
  expect "una parte malformata esce 2" 2 \
    "impronte malformate nelle parti di familiari"
  impronte_cambiate "${w}" impronta_malformata
  controllo "${w}"
  expect "un'impronta malformata esce 2" 2 \
    "impronte malformate nella classe nomi"
  impronte_cambiate "${w}" senza_impronte
  controllo "${w}"
  expect "impronte.json senza impronte esce 2" 2 "non contiene nessuna impronta"
  ws w soluzione
  controllo "${w}" --boh
  expect "un'opzione sconosciuta esce 2" 2 "opzione sconosciuta"
  expect_ultima "un'opzione sconosciuta: l'ultima riga" 2 \
    "uscita: 2 (argomenti non validi: vedi sopra)"
  controllo "${w}" a.csv b.csv
  expect "due file esce 2" 2 "un file solo"
  if (( EUID == 0 )); then
    skip "un file che non si legge esce 2 (da root si legge comunque)"
  else
    chmod 000 "${w}/anonimo/ticket-anonimi.csv" || rotta "chmod"
    controllo "${w}"
    expect "un file che non si legge esce 2" 2 "non si legge"
    chmod 644 "${w}/anonimo/ticket-anonimi.csv" || rotta "chmod"
  fi
  controllo "${w}" -h
  expect "-h esce 0 con l'uso" 0 "Uso:"
}

# La verifica: partenza, soluzione, un KPI, un telefono, la copia
# originale, il registro soltanto come dato, mai un esito sul ciclo.
t_verifica() {
  local w
  ws w
  verifica "${w}"
  expect "verifica: il punto di partenza esce 1" 1 \
    "Non ancora: manca anonimo/ticket-anonimi.csv"
  expect "verifica: senza esecuzioni, il registro come dato" 1 \
    "nessuna esecuzione registrata"
  expect_absent "verifica: nessun esito sul ciclo della guida" "confermata"
  ws w soluzione
  verifica "${w}"
  expect "verifica: la soluzione esce 0" 0 "${FINE}"
  expect "verifica: le esecuzioni del registro, come dato" 0 \
    "esecuzioni registrate: 1; uscite, in ordine: 0"
  expect "verifica: il registro lo scrive il controllo, non lo prova" 0 \
    "Che Claude l'abbia eseguito lo dicono le sue chiamate"
  expect_absent "verifica: mai «In questa esecuzione»" "In questa esecuzione"
  expect_absent "verifica: nessun esito sul ciclo, sulla soluzione" \
    "confermata"
  expect_absent "verifica: la soluzione senza «Non ancora»" "Non ancora"
  expect "verifica: nessun dato del corso rimasto in parte" 0 \
    "dati del corso rimasti in parte: 0"
  expect "verifica: nessuna omissione senza un dato del corso" 0 \
    "omissioni senza un dato del corso: 0"
  nessun_valore "verifica: nessun valore in chiaro"
  fx kpi "${w}" segnalazioni 342
  verifica "${w}"
  expect "verifica: un KPI sbagliato di uno esce 1" 1 \
    "i KPI del profilo non tornano: segnalazioni"
  ws w soluzione
  fx telefono_indietro "${w}"
  verifica "${w}"
  expect "verifica: un telefono rimesso esce 1" 1 "telefoni 1,"
  nessun_valore "verifica: il telefono rimesso non si stampa"
  printf 'import sys\nsys.exit(0)\n' > "${w}/controlla_pii.py"
  verifica "${w}"
  expect "verifica: un controllo che esce sempre 0 non basta" 1 \
    "Non ancora: resta 1 dato personale nel file anonimo"
  expect "verifica: il controllo cambiato è un dato" 1 \
    "controlla_pii.py dello spazio di lavoro: DIVERSO dall'originale"
  ws w soluzione
  printf '2026-10-21T09:00:00Z\t1\t3\n' >> "${w}/anonimo/controlli.log"
  verifica "${w}"
  expect "verifica: l'ultima esecuzione uscita 1, l'uscita resta 0" 0 \
    "esecuzioni registrate: 2; uscite, in ordine: 0 1"
  rm "${w}/anonimo/controlli.log"
  verifica "${w}"
  expect "verifica: senza registro, un dato e l'uscita resta 0" 0 \
    "nessuna esecuzione registrata"
  ws w grezzo
  verifica "${w}"
  expect "verifica: il CSV grezzo come file anonimo esce 1" 1 \
    "l'intestazione non è quella attesa"
  expect "verifica: sul grezzo, i dati personali rimasti" 1 \
    "Non ancora: restano"
  nessun_valore "verifica sul grezzo: nessun valore in chiaro"
  t_verifica_in_parte
}

# La verifica: i dati del corso rimasti in parte e le omissioni senza un
# dato del corso, come dato; un nome a metà è un residuo (uscita 1), un
# civico o un dominio rimasti, una parola omessa in più o tutto omesso
# non cambiano l'uscita.
t_verifica_in_parte() {
  local w
  ws w soluzione
  fx parziale "${w}" "${E01}" nomi ultima
  verifica "${w}"
  expect "verifica: un nome a metà è un residuo, esce 1" 1 \
    "Non ancora: resta 1 dato personale nel file anonimo"
  expect "verifica: il nome a metà, anche fra i dati rimasti in parte" 1 \
    "dati del corso rimasti in parte: 1 (nomi 1)"
  nessun_valore "verifica: il nome a metà non si stampa"
  ws w soluzione
  fx parziale "${w}" "${E01}" indirizzi civico
  verifica "${w}"
  expect "verifica: il civico rimasto è un dato, esce 0" 0 \
    "dati del corso rimasti in parte: 1 (indirizzi 1)"
  expect "verifica: il civico rimasto, la verifica passa" 0 "${FINE}"
  ws w soluzione
  fx parziale "${w}" "${E01}" email dominio
  verifica "${w}"
  expect "verifica: il dominio rimasto è un dato, esce 0" 0 \
    "dati del corso rimasti in parte: 1 (email 1)"
  nessun_valore "verifica: il dominio rimasto, nessun valore in chiaro"
  ws w soluzione
  fx modifica "${w}" omissione_in_piu
  verifica "${w}"
  expect "verifica: un'omissione senza un dato del corso, esce 0" 0 \
    "omissioni senza un dato del corso: 1"
  ws w soluzione
  fx modifica "${w}" tutto_omesso
  verifica "${w}"
  expect "verifica: tutto omesso, un dato, esce 0" 0 \
    "omissioni senza un dato del corso: "
  expect_absent "verifica: tutto omesso, le omissioni contate" \
    "omissioni senza un dato del corso: 0"
  ws w soluzione
  fx modifica "${w}" riscrivi
  verifica "${w}"
  expect "verifica: un testo riscritto, la misura non si fa" 1 \
    "non si misura"
}

# La verifica: le forme sbagliate del file anonimo.
t_verifica_forme() {
  local w voce cosa
  for voce in "colonna_in_piu:l'intestazione non è quella attesa" \
      "togli_riga:le righe non sono quelle del file grezzo" \
      "pseudonimo:pseudonimi diversi da quelli attesi in 1 riga" \
      "riscrivi:1 testo non è il testo originale con [OMESSO]" \
      "comune:la colonna comune è cambiata in 1 riga" \
      "bom:comincia con un BOM" "crlf:ha fine riga CRLF"; do
    cosa="${voce%%:*}"
    ws w soluzione
    fx modifica "${w}" "${cosa}"
    verifica "${w}"
    expect "verifica: ${cosa} esce 1" 1 "${voce#*:}"
  done
}

# La verifica: il profilo.
t_verifica_profilo() {
  local w
  ws w soluzione
  rm "${w}/anonimo/profilo.json"
  verifica "${w}"
  expect "verifica: senza profilo esce 1" 1 "manca anonimo/profilo.json"
  printf '{' > "${w}/anonimo/profilo.json"
  verifica "${w}"
  expect "verifica: un profilo non JSON esce 1" 1 "non è un JSON valido"
  printf '{"altro": 1}' > "${w}/anonimo/profilo.json"
  verifica "${w}"
  expect "verifica: un profilo senza kpi esce 1" 1 "non ha la chiave kpi"
  ws w soluzione
  fx kpi "${w}" in_piu 1
  verifica "${w}"
  expect "verifica: una chiave in più in kpi esce 1" 1 "(chiave in più)"
  ws w soluzione
  fx kpi "${w}" soddisfazione_media 3.519
  verifica "${w}"
  expect "verifica: un decimale con più cifre va bene" 0 "${FINE}"
  fx kpi "${w}" soddisfazione_media 3.51
  verifica "${w}"
  expect "verifica: un decimale arrotondato male esce 1" 1 \
    "i KPI del profilo non tornano: soddisfazione_media"
}

# La verifica: le precondizioni, su una copia dell'elemento.
t_verifica_precondizioni() {
  local w copia
  run "${E01}/verifica.sh" "${TMP}/non-esiste"
  expect "verifica: spazio di lavoro assente esce 2" 2 \
    "spazio di lavoro assente"
  copia="$(mktemp -d "${TMP}/elemento.XXXXXX")" || rotta "mktemp"
  cp -R "${E01}/." "${copia}/" || rotta "cp elemento"
  rm "${copia}/esercizio/controlla_pii.py" || rotta "rm"
  ws w soluzione
  run "${copia}/verifica.sh" "${w}"
  expect "verifica: il controllo originale che manca esce 2" 2 \
    "controlla_pii.py"
  cp "${E01}/esercizio/controlla_pii.py" "${copia}/esercizio/" || rotta "cp"
  printf 'import sys\nsys.exit(5)\n' > "${copia}/verifica.py"
  run "${copia}/verifica.sh" "${w}"
  expect "verifica: un'uscita fuori contratto diventa 2" 2 \
    "il controllo è uscito con 5"
}

# Gli script della soluzione, eseguiti in uno spazio di lavoro nuovo,
# riproducono byte per byte il file anonimo e il profilo di soluzione/.
t_soluzione() {
  local w f
  ws w
  cp "${E01}/soluzione/anonimizza.py" "${E01}/soluzione/profilo.py" \
    "${w}/" || rotta "cp gli script della soluzione"
  (cd "${w}" && python3 -B anonimizza.py && python3 -B profilo.py) \
    > /dev/null 2>&1 || rotta "gli script della soluzione non girano"
  for f in ticket-anonimi.csv profilo.json; do
    if cmp -s "${w}/anonimo/${f}" "${E01}/soluzione/anonimo/${f}"; then
      pass "soluzione: gli script riproducono anonimo/${f}"
    else
      fail "soluzione: anonimo/${f} non è quello che gli script producono"
    fi
  done
}

# Gli strumenti del repository: prepara_esercizio.sh e verifica.sh.
t_integrazione() {
  local radice
  radice="$(mktemp -d "${TMP}/radice.XXXXXX")" || rotta "mktemp"
  run "${RADICE}/tools/prepara_esercizio.sh" M3-E01 --radice "${radice}"
  expect "prepara_esercizio.sh M3-E01" 0 "Spazio di lavoro pronto"
  if [[ -f "${radice}/M3-E01/controlla_pii.py" \
      && -f "${radice}/M3-E01/dati/ticket-settimana.csv" \
      && ! -e "${radice}/M3-E01/anonimizza.py" \
      && ! -e "${radice}/M3-E01/_docente" \
      && ! -e "${radice}/M3-E01/costruisci_impronte.py" ]]; then
    pass "lo spazio di lavoro: il punto di partenza, senza soluzione né docente"
  else
    fail "lo spazio di lavoro non è il punto di partenza"
  fi
  run "${RADICE}/tools/verifica.sh" M3-E01 --radice "${radice}"
  expect "tools/verifica.sh sul punto di partenza esce 1" 1 "NON ANCORA"
  cp -R "${E01}/soluzione/." "${radice}/M3-E01/" || rotta "cp soluzione"
  run "${RADICE}/tools/verifica.sh" M3-E01 --radice "${radice}"
  expect "tools/verifica.sh con la soluzione esce 0" 0 "VERIFICA OK"
}

# residui.py su un file, ridotto da jq alla misura per posizione: la somma
# dei dati rimasti in parte e le omissioni senza un dato del corso.
# Arguments: $1 il nome, $2 il file, $3 la coppia attesa («[n,m]» o
# «[null,null]»).
residui_parte() {
  run bash -c 'python3 -B -I "$1" "$2" | jq -c \
    "[(.in_parte | if . == null then null else add end),
      .omissioni_senza_dato]"' _ "${E01}/_docente/residui.py" "$2"
  expect "$1" 0 "$3"
}

# residui.py: per classe, la misura per posizione, la coppia, un testo
# qualunque.
t_residui() {
  local w s r="${E01}/_docente/residui.py"
  ws w grezzo
  run python3 -B -I "${r}" "${w}/anonimo/ticket-anonimi.csv"
  expect "residui: sul grezzo, anche le utenze PPPoE" 0 '"utenze_pppoe": 2'
  nessun_valore "residui: nessun valore in chiaro"
  residui_parte "residui: sul grezzo, la misura per posizione è null" \
    "${w}/anonimo/ticket-anonimi.csv" "[null,null]"
  ws s soluzione
  run python3 -B -I "${r}" "${s}/anonimo/ticket-anonimi.csv"
  expect "residui: la soluzione, totale 0" 0 '"totale": 0'
  residui_parte "residui: la soluzione, nulla in parte, nulla omesso in più" \
    "${s}/anonimo/ticket-anonimi.csv" "[0,0]"
  ws w soluzione
  fx parziale "${w}" "${E01}" indirizzi civico
  residui_parte "residui: un civico rimasto, un indirizzo in parte" \
    "${w}/anonimo/ticket-anonimi.csv" "[1,0]"
  ws w grezzo
  run python3 -B -I "${r}" --coppia "${s}/anonimo/ticket-anonimi.csv" \
    "${w}/anonimo/ticket-anonimi.csv"
  expect "residui --coppia: con il controllo migliore, confermata" 0 \
    '"esito": "confermata"'
  run python3 -B -I "${r}" --coppia "${w}/anonimo/ticket-anonimi.csv" \
    "${s}/anonimo/ticket-anonimi.csv"
  expect "residui --coppia: peggiore, non confermata in questa esecuzione" 0 \
    '"esito": "non confermata in questa esecuzione"'
  expect_absent "residui --coppia: mai «smentita»" "smentit"
  run python3 -B -I "${r}" --coppia "${s}/anonimo/ticket-anonimi.csv" \
    "${s}/anonimo/ticket-anonimi.csv"
  expect "residui --coppia: uguali, non distinguibile" 0 \
    '"esito": "non distinguibile"'
  run python3 -B -I "${r}" --coppia "${s}/anonimo/ticket-anonimi.csv" \
    "${TMP}/manca.csv"
  expect "residui --coppia: manca il file senza il controllo, non decidibile" \
    0 '"esito": "non decidibile"'
  run python3 -B -I "${r}" --coppia "${TMP}/manca.csv" \
    "${s}/anonimo/ticket-anonimi.csv"
  expect "residui --coppia: manca il file con il controllo, non decidibile" \
    0 '"esito": "non decidibile"'
  fx testo_con_telefono "${E01}/esercizio/dati/ticket-settimana.csv" \
    "${TMP}/testo.txt"
  run python3 -B -I "${r}" --testo "${TMP}/testo.txt"
  expect "residui --testo: un telefono in un testo qualunque" 0 \
    '"telefoni": 1'
  nessun_valore "residui --testo: nessun valore in chiaro"
  run python3 -B -I "${r}" --boh
  expect "residui: argomenti sbagliati escono 2" 2 "uso: residui.py"
}

# Le impostazioni di progetto dello spazio di lavoro.
t_settings() {
  run python3 -B -I - "${E01}/esercizio/.claude/settings.json" \
    "${RADICE}/.claude/settings.json" <<'PY'
import json
import sys

e = json.load(open(sys.argv[1], encoding="utf-8"))["permissions"]
r = json.load(open(sys.argv[2], encoding="utf-8"))["permissions"]
deny = r["deny"] + ["Read(./dati/ticket-settimana.csv)",
                    "Read(./anonimo/ticket-anonimi.csv)",
                    "Edit(./controlla_pii.py)", "Edit(./impronte.json)"]
allow = ["Bash(python3 anonimizza.py)", "Bash(python3 controlla_pii.py)",
         "Bash(python3 controlla_pii.py *)", "Bash(python3 profilo.py)"]
print("deny %s" % ("ok" if e.get("deny") == deny else "diverso"))
print("allow %s" % ("ok" if e.get("allow") == allow else "diverso"))
print("modo %s" % ("ok" if e.get("defaultMode") == "default" else "diverso"))
PY
  expect "settings: le regole del repository, i due Read e i due Edit" 0 \
    "deny ok"
  expect "settings: i quattro comandi python3 consentiti, non altro" 0 \
    "allow ok"
  expect "settings: defaultMode default (Manual)" 0 "modo ok"
}

# Il README: il prompt fra i segni (in ${TMP}/prompt-readme.txt), il
# paragrafo del controllo, la versione breve, le dieci sezioni; nessun
# identificativo interno nei file per i partecipanti.
t_readme() {
  local f trovati=''
  run python3 -B -I - "${E01}/README.md" "${TMP}/prompt-readme.txt" <<'PY'
import sys
import textwrap

righe = open(sys.argv[1], encoding="utf-8").read().split("\n")
a = [i for i, r in enumerate(righe) if r.strip() == "<!-- prompt -->"]
b = [i for i, r in enumerate(righe) if r.strip() == "<!-- /prompt -->"]
if len(a) == 1 and len(b) == 1 and a[0] < b[0]:
    prompt = textwrap.dedent("\n".join(righe[a[0] + 1:b[0]])).strip("\n")
    open(sys.argv[2], "w", encoding="utf-8").write(prompt)
    print("prompt ok")
    paragrafi = prompt.split("\n\n")
    controllo = [p for p in paragrafi
                 if p.startswith("Poi esegui python3 controlla_pii.py")]
    if len(controllo) == 1:
        print("paragrafo del controllo ok")
        piano = " ".join(controllo[0].split())
        if "ultima riga" in piano and "«uscita: 0»" in piano \
                and "$?" in piano:
            print("ultima riga nel paragrafo del controllo ok")
    # Il prompt senza il paragrafo del controllo (la coppia del docente)
    # chiede ancora un comando alla volta: le due metà differiscono in una
    # cosa sola.
    senza = " ".join(" ".join(p for p in paragrafi
                              if p not in controllo).split())
    if "Esegui ogni comando da solo" in senza and "&&" in senza \
            and "echo" in senza:
        print("un comando alla volta anche senza il controllo ok")
    # Gli script si eseguono con i comandi che le impostazioni consentono,
    # nominati anche senza il controllo: in claude -p un'altra forma
    # (python3 -I, una redirezione) è negata, dove un partecipante risponde.
    if "Eseguilo con python3 anonimizza.py" in senza \
            and "Eseguilo con python3 profilo.py" in senza:
        print("i comandi consentiti anche senza il controllo ok")
i = next(k for k, r in enumerate(righe) if "La versione breve" in r)
breve = []
for r in righe[i + 1:]:
    if r.startswith("       "):
        breve.append(r[7:])
    elif breve:
        break
if 0 < len(breve) <= 19 and max(len(r) for r in breve) <= 66:
    print("breve ok: %d righe" % len(breve))
breve_piano = " ".join(" ".join(breve).split())
if "Esegui ogni comando da solo" in breve_piano \
        and "ultima riga dice uscita: 0" in breve_piano:
    print("breve: un comando alla volta e l'ultima riga ok")
if "Eseguilo con python3 anonimizza.py" in breve_piano \
        and "Eseguilo con python3 profilo.py" in breve_piano:
    print("breve: i comandi consentiti ok")
sezioni = ("Obiettivo", "Tempo", "Prerequisiti", "Punto di partenza",
           "Passi in Claude Code", "Che cosa osservare", "Verifica",
           "Se qualcosa va storto", "Impronta d'uso sul piano Pro",
           "Per approfondire")
if all(any(r.startswith("## " + s) for r in righe) for s in sezioni):
    print("sezioni ok")
# Il percorso A: le colonne che il controllo chiede e quelle che segnala;
# nessun valori.tsv, perché le impronte sono quelle della settimana.
j = next((k for k, r in enumerate(righe) if "**Percorso A" in r), None)
if j is not None:
    paragrafo = []
    for r in righe[j:]:
        if paragrafo and r.lstrip().startswith("- **Percorso B"):
            break
        paragrafo.append(r)
    a_piano = " ".join(" ".join(paragrafo).split())
    if all(c in a_piano for c in ("id_ticket", "nome_cliente", "telefono",
                                  "email", "id_linea", "id_cliente")) \
            and "valori.tsv" not in a_piano and "profilo.py" in a_piano:
        print("percorso A ok")
PY
  expect "README: il prompt fra i due segni" 0 "prompt ok"
  expect "README: il percorso A dice le colonne e i limiti del controllo" 0 \
    "percorso A ok"
  expect "README: il paragrafo del controllo, separabile" 0 \
    "paragrafo del controllo ok"
  expect "README: il controllo si legge dalla sua ultima riga, non da \$?" 0 \
    "ultima riga nel paragrafo del controllo ok"
  expect "README: un comando alla volta, anche senza il controllo" 0 \
    "un comando alla volta anche senza il controllo ok"
  expect "README: i comandi consentiti nominati, anche senza il controllo" \
    0 "i comandi consentiti anche senza il controllo ok"
  expect "README: la versione breve in 19 righe × 66 colonne" 0 "breve ok"
  expect "README: la versione breve, un comando alla volta e l'ultima riga" \
    0 "breve: un comando alla volta e l'ultima riga ok"
  expect "README: la versione breve nomina i comandi consentiti" 0 \
    "breve: i comandi consentiti ok"
  expect "README: le dieci sezioni" 0 "sezioni ok"
  for f in README.md verifica.sh verifica.py kpi_veri.py \
      esercizio/controlla_pii.py esercizio/kpi_definizioni.md \
      esercizio/impronte.json esercizio/.claude/settings.json; do
    if grep -qE -- "${INTERNI}" "${E01}/${f}"; then
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
    FINTO_PROMPT="${TMP}/prompt" FINTO_SOLUZIONE="${E01}/soluzione" \
    "${E01}/_docente/live.sh" "${w}"
}

# Quante chiamate ha ricevuto il claude finto.
chiamate() { local n; n="$(wc -l < "${TMP}/finto.log")"; echo $((n)); }

# Una chiamata attesa: il numero di chiamate del claude finto.
# Arguments: $1 il nome, $2 le chiamate attese.
expect_chiamate() {
  local n
  n="$(chiamate)"
  if (( n == $2 )); then pass "$1"; else fail "$1: ${n} chiamate, attese $2"; fi
}

# Le precondizioni di live.sh: escono 2 senza chiamare claude.
# Arguments: $1 il nome, $2 la parola attesa, $3 lo spazio di lavoro.
senza_chiamate() {
  : > "${TMP}/esca.log"
  run env PATH="${TMP}/esca:${PATH}" ESCA_LOG="${TMP}/esca.log" \
    HANDSON_NO_PAUSE=1 "${E01}/_docente/live.sh" "$3"
  if (( RC == 2 )) && grep -qF -- "$2" <<< "${OUT}" \
      && [[ ! -s "${TMP}/esca.log" ]]; then
    pass "$1"
  else
    fail "$1 (rc=${RC}, chiamate: $(wc -l < "${TMP}/esca.log")): $(sicuro)"
  fi
}

t_live() {
  local w
  senza_chiamate "live.sh: spazio di lavoro assente esce 2" \
    "spazio di lavoro assente" "${TMP}/non-esiste"
  ws w
  rm "${w}/controlla_pii.py"
  senza_chiamate "live.sh: senza controlla_pii.py esce 2" "controlla_pii.py" \
    "${w}"
  ws w
  rm "${w}/impronte.json"
  senza_chiamate "live.sh: senza impronte.json esce 2" "impronte.json" "${w}"
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
          "--allowedTools": "Read,Write,Edit,Bash(python3 anonimizza.py),"
                            "Bash(python3 controlla_pii.py),"
                            "Bash(python3 controlla_pii.py *),"
                            "Bash(python3 profilo.py)",
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
  expect_chiamate "live.sh: finito al secondo turno, due chiamate" 2
  if sed -n 2p "${TMP}/finto.argv" | grep -qF '"--resume", "sessione-finta"' \
      && grep -qF "poi da solo python3 controlla_pii.py, e leggi la sua" \
        "${TMP}/prompt.2" \
      && grep -qF "correggi finché dice uscita: 0." "${TMP}/prompt.2"; then
    pass "live.sh: il turno 2 riprende la sessione, un comando per volta"
  else
    fail "live.sh: il secondo turno non riprende la sessione come atteso"
  fi
  ws w
  live_finto "${w}" FINTO_MODO=mai
  expect "live.sh: mai finito esce 1" 1 "VERIFICA KO"
  expect_chiamate "live.sh: mai finito, quattro chiamate" 4
  ws w
  live_finto "${w}" FINTO_MODO=senza_profilo
  expect "live.sh: il profilo al secondo turno esce 0" 0 "VERIFICA OK"
  if grep -qF "Ora scrivi profilo.py ed eseguilo da solo" "${TMP}/prompt.2"
  then
    pass "live.sh: il secondo turno chiede il profilo, da solo"
  else
    fail "live.sh: il secondo turno non chiede il profilo"
  fi
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

# Lo shellcheck degli script dell'elemento e di questo.
t_shellcheck() {
  local f
  for f in "${E01}/verifica.sh" "${E01}/_docente/live.sh" "${SELF}"; do
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
      || { echo "test_m3_e01: manca ${t}" >&2; exit 2; }
  done
  for t in verifica.sh verifica.py kpi_veri.py esercizio/controlla_pii.py \
      esercizio/impronte.json _docente/live.sh _docente/residui.py \
      _docente/costruisci_impronte.py soluzione/anonimizza.py; do
    [[ -e "${E01}/${t}" ]] || { echo "test_m3_e01: manca ${t}" >&2; exit 2; }
  done
  [[ -f "${PROGETTO}/dati/ticket-settimana.csv" ]] \
    || { echo "test_m3_e01: manca il progetto assistenza-clienti" >&2; exit 2; }
  handson::init_temp_base
  TMP="$(mktemp -d "${HANDSON_TEMP_BASE}/test_m3_e01.XXXXXX")" || exit 2
  trap 'chmod -R u+rwX "${TMP}" 2>/dev/null; rm -rf "${TMP}"' EXIT
  prepara
  t_impronte
  t_controllo
  t_registro
  t_controllo_precondizioni
  t_verifica
  t_verifica_forme
  t_verifica_profilo
  t_verifica_precondizioni
  t_soluzione
  t_integrazione
  t_residui
  t_settings
  t_readme
  t_live
  t_shellcheck
  echo "PASS=${PASS} FAIL=${FAIL} SKIP=${SKIP}" \
    "CASES=$((PASS + FAIL + SKIP))/${CASES}"
  if (( PASS + FAIL + SKIP != CASES )); then
    echo "test_m3_e01: eseguite $((PASS + FAIL + SKIP)) prove, attese" \
      "${CASES}: un caso manca o non è contato" >&2
    exit 2
  fi
  (( FAIL == 0 )) || exit 1
}

main "$@"
