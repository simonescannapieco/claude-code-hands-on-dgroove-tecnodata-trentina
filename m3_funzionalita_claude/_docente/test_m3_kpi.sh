#!/bin/bash
#
# test_m3_kpi.sh -- le prove dei KPI veri della settimana di ticket
# (kpi_veri.py di M3-E01, con le copie in M3-E02 e M3-E03), per il docente:
#   - kpi_veri.py sul CSV grezzo dà la verità del progetto dove vale (343
#     segnalazioni; 57, 80, 64, 53, 54, 25, 10 per giorno; 75 aperte; 2
#     annullate; 106 voti con media 3,52; 27 clienti ricorrenti, contati
#     su id_cliente), e mediana e medie uguali a quelle che calcola qui il
#     modulo statistics; le chiavi in ordine;
#   - sul file anonimo della soluzione gli stessi KPI del grezzo;
#   - la regola del confronto: un intero è giusto se uguale; un decimale se
#     sta entro mezza unità dell'ultimo decimale (anche con più cifre), e un
#     decimale arrotondato male è sbagliato; un oggetto con una chiave che
#     manca o in più è sbagliato, come una chiave che manca o in più in
#     cima; un booleano o un testo non sono numeri; un null è giusto solo
#     se il vero è null;
#   - le precondizioni della riga di comando (uscita 2);
#   - le copie di kpi_veri.py e di kpi_definizioni.md in M3-E02 e in
#     M3-E03 uguali byte per byte a quelle di M3-E01: finché un elemento non
#     c'è, o non ha la copia, la prova dice SKIP, mai PASS;
#   - shellcheck -x su questo script.
# I file temporanei nascono nella base di handson::init_temp_base (mai
# dentro ~/.claude, anche se TMPDIR punta lì).
#
# Uso:    m3_funzionalita_claude/_docente/test_m3_kpi.sh
# Env:    PN_M3_COPIE  dove cercare le cartelle di M3-E02 e M3-E03 (default
#                      la sezione del modulo, s2_funzionalita_claude/)
# Uscita: 0 = tutte le prove passano (gli SKIP contati a parte) · 1 =
#         almeno una fallita · 2 = precondizione (manca python3, manca
#         lo strumento shellcheck o un file di M3-E01; le prove eseguite
#         non sono quante attese)
set -uo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
readonly MOD="${SELF%/_docente/*}"
readonly RADICE="${MOD%/*}"
readonly SEZIONE="${MOD}/s2_funzionalita_claude"
readonly COPIE_IN="${PN_M3_COPIE:-${SEZIONE}}"
readonly E01="${SEZIONE}/m3_e2_anonimizzare/M3-E01_anonimizzare_ticket"
readonly KPI="${E01}/kpi_veri.py"
readonly DEFINIZIONI="${E01}/esercizio/kpi_definizioni.md"
readonly GREZZO="${E01}/esercizio/dati/ticket-settimana.csv"
readonly ANONIMO="${E01}/soluzione/anonimo/ticket-anonimi.csv"
# La libreria del repository, per la base dei file temporanei
# (handson::init_temp_base): mai dentro ~/.claude, anche se TMPDIR punta lì.
# shellcheck source=../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"
readonly CASES=37
TMP=''
PASS=0
FAIL=0
SKIP=0
RC=0
OUT=''

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }
# Una copia che non c'è ancora: contata a parte, mai come passata.
skip() { echo "  SKIP: $1"; SKIP=$((SKIP + 1)); }

# Esegue un comando; RC e OUT (STDOUT e STDERR insieme) per expect.
run() { OUT="$("$@" 2>&1)"; RC=$?; }

# Uscita attesa E parola chiave attesa (RU-01.T3).
# Arguments: $1 il nome, $2 l'uscita attesa, $3 la parola (grep -F).
expect() {
  if (( RC == $2 )) && grep -qF -- "$3" <<< "${OUT}"; then
    pass "$1"
  else
    fail "$1 (rc=${RC}, attesa $2, parola «$3»): ${OUT:0:400}"
  fi
}

# kpi_veri.py dalla riga di comando. Arguments: gli argomenti.
kpi() { run python3 -B -I "${KPI}" "$@"; }

# La verità del grezzo, e i controlli fatti qui con statistics.
t_grezzo() {
  local json
  kpi "${GREZZO}"
  json="${OUT}"
  expect "grezzo: 343 segnalazioni" 0 '"segnalazioni": 343'
  expect "grezzo: 75 aperte a fine settimana" 0 '"aperte_fine_settimana": 75'
  expect "grezzo: 2 annullate" 0 '"annullate": 2'
  expect "grezzo: 106 voti" 0 '"voti": 106'
  expect "grezzo: soddisfazione media 3.52" 0 '"soddisfazione_media": 3.52'
  expect "grezzo: 27 clienti ricorrenti (su id_cliente)" 0 \
    '"clienti_ricorrenti": 27'
  run python3 -B -I -c '
import csv, datetime, json, statistics, sys
kpi = json.loads(sys.argv[2])
righe = list(csv.DictReader(open(sys.argv[1], encoding="utf-8")))
giorni = [kpi["per_giorno"][g]
          for g in ("lun", "mar", "mer", "gio", "ven", "sab", "dom")]
print("giorni ok" if giorni == [57, 80, 64, 53, 54, 25, 10] else giorni)
prima = [int(r["minuti_prima_risposta"]) for r in righe
         if r["minuti_prima_risposta"]]
print("mediana ok" if abs(kpi["mediana_minuti_prima_risposta"]
                         - statistics.median(prima)) <= 0.05 else "mediana")
tec = {}
for r in righe:
    if r["minuti_risoluzione"]:
        tec.setdefault(r["tecnologia"], []).append(int(r["minuti_risoluzione"]))
medie = kpi["media_minuti_risoluzione_per_tecnologia"]
print("medie ok" if set(medie) == set(tec) and all(
    abs(medie[t] - statistics.mean(v)) <= 0.05 for t, v in tec.items())
    else "medie")
cat = kpi["per_categoria"]
print("categorie ok" if len(cat) == 14 and sum(cat.values()) == 343
      else "categorie")
chiavi = list(kpi)
print("chiavi ok" if chiavi == sorted(chiavi) and len(chiavi) == 10
      else "chiavi")
' "${GREZZO}" "${json}"
  expect "grezzo: per giorno 57, 80, 64, 53, 54, 25, 10" 0 "giorni ok"
  expect "grezzo: la mediana come statistics.median" 0 "mediana ok"
  expect "grezzo: le medie per tecnologia come statistics.mean" 0 "medie ok"
  expect "grezzo: 14 categorie che sommano 343" 0 "categorie ok"
  expect "grezzo: dieci chiavi, in ordine" 0 "chiavi ok"
}

# Il file anonimo della soluzione ha gli stessi KPI del grezzo.
t_anonimo() {
  local grezzo anonimo
  grezzo="$(python3 -B -I "${KPI}" "${GREZZO}")" || grezzo=''
  anonimo="$(python3 -B -I "${KPI}" "${ANONIMO}")" || anonimo=''
  if [[ -n "${grezzo}" && "${grezzo}" == "${anonimo}" ]]; then
    pass "il file anonimo della soluzione: gli stessi KPI del grezzo"
  else
    fail "il file anonimo della soluzione: KPI diversi dal grezzo"
  fi
}

# La regola del confronto, con il modulo: una riga «nome: ok» per caso.
t_regola() {
  local caso
  run python3 -B -I - "${KPI}" "${GREZZO}" "${TMP}" <<'PY'
import copy
import importlib.util
import os
import sys

spec = importlib.util.spec_from_file_location("kpi_veri", sys.argv[1])
kv = importlib.util.module_from_spec(spec)
spec.loader.exec_module(kv)
csv_ = sys.argv[2]
vero = kv.arrotonda(kv.esatti(csv_))


def esito(valori, chiave, percorso=csv_):
    for k, _, _, ok in kv.confronta(valori, percorso):
        if k == chiave:
            return ok
    return None


def con(chiave, valore):
    v = copy.deepcopy(vero)
    v[chiave] = valore
    return v


prove = {
    "tutto giusto": all(ok for *_, ok in kv.confronta(vero, csv_)),
    "intero uguale": esito(con("segnalazioni", 343), "segnalazioni") is True,
    "intero sbagliato di uno": esito(con("segnalazioni", 342),
                                     "segnalazioni") is False,
    "intero scritto 343.0": esito(con("segnalazioni", 343.0),
                                  "segnalazioni") is True,
    "decimale con più cifre": esito(con("soddisfazione_media", 3.5189),
                                    "soddisfazione_media") is True,
    "decimale arrotondato male": esito(con("soddisfazione_media", 3.51),
                                       "soddisfazione_media") is False,
    "booleano non è un numero": esito(con("annullate", True),
                                      "annullate") is False,
    "testo non è un numero": esito(con("soddisfazione_media", "3.52"),
                                   "soddisfazione_media") is False,
}
giorni = dict(vero["per_giorno"])
del giorni["dom"]
prove["oggetto con una chiave che manca"] = esito(
    con("per_giorno", giorni), "per_giorno") is False
giorni = dict(vero["per_giorno"], extra=0)
prove["oggetto con una chiave in più"] = esito(
    con("per_giorno", giorni), "per_giorno") is False
senza = copy.deepcopy(vero)
del senza["voti"]
prove["chiave che manca in cima"] = esito(senza, "voti") is False
prove["chiave in più in cima"] = esito(dict(vero, altro=1), "altro") is False
piccolo = os.path.join(sys.argv[3], "senza_voti.csv")
with open(piccolo, "w", encoding="utf-8") as fh:
    fh.write("aperto_il,chiuso_il,stato,categoria,tecnologia,"
             "minuti_prima_risposta,minuti_risoluzione,soddisfazione,cliente\n"
             "2026-09-07T10:00:00+02:00,,aperto,wifi,FTTH,,,,C-001\n")
prove["null giusto se il vero è null"] = esito(
    {"soddisfazione_media": None}, "soddisfazione_media", piccolo) is True
prove["un numero sbagliato se il vero è null"] = esito(
    {"soddisfazione_media": 0}, "soddisfazione_media", piccolo) is False
for nome, ok in prove.items():
    print("%s: %s" % (nome, "ok" if ok else "NO"))
PY
  for caso in "tutto giusto" "intero uguale" "intero sbagliato di uno" \
      "intero scritto 343.0" "decimale con più cifre" \
      "decimale arrotondato male" "booleano non è un numero" \
      "testo non è un numero" "oggetto con una chiave che manca" \
      "oggetto con una chiave in più" "chiave che manca in cima" \
      "chiave in più in cima" "null giusto se il vero è null" \
      "un numero sbagliato se il vero è null"; do
    expect "regola: ${caso}" 0 "${caso}: ok"
  done
}

# Le precondizioni della riga di comando.
t_precondizioni() {
  kpi "${TMP}/non-esiste.csv"
  expect "un file che manca esce 2" 2 "non c'è"
  printf 'aperto_il,stato\n2026-09-07T10:00:00+02:00,aperto\n' \
    > "${TMP}/colonne.csv"
  kpi "${TMP}/colonne.csv"
  expect "una colonna che manca esce 2" 2 "mancano le colonne"
  head -n 2 "${ANONIMO}" > "${TMP}/numero.csv" || exit 2
  python3 -B -I -c 'import csv, sys
r = list(csv.reader(open(sys.argv[1], encoding="utf-8")))
r[1][r[0].index("soddisfazione")] = "tre"
csv.writer(open(sys.argv[1], "w", encoding="utf-8", newline="")).writerows(r)
' "${TMP}/numero.csv" || exit 2
  kpi "${TMP}/numero.csv"
  expect "un numero che non è un intero esce 2" 2 \
    "soddisfazione non è un intero"
  sed '2s/^\(TK-[0-9-]*\),[^,]*,/\1,ieri,/' "${TMP}/numero.csv" \
    > "${TMP}/data.csv" || exit 2
  kpi "${TMP}/data.csv"
  expect "una data che non è ISO 8601 esce 2" 2 "non è una data ISO 8601"
  kpi
  expect "senza argomenti esce 2" 2 "uso:"
  kpi -h
  expect "-h esce 0" 0 "Uso:"
}

# Le copie in M3-E02 e M3-E03: uguali, o SKIP finché non ci sono.
t_copie() {
  local voce sigla cartella originale nome copie c diverse messaggio
  for voce in "M3-E02:m3_e3_dashboard" "M3-E03:m3_e4_dashboard_locale"; do
    sigla="${voce%%:*}"
    for originale in "${KPI}" "${DEFINIZIONI}"; do
      nome="${originale##*/}"
      copie=()
      for cartella in "${COPIE_IN}/${voce#*:}/${sigla}_"*/; do
        [[ -d "${cartella}" ]] || continue
        while IFS= read -r -d '' c; do
          copie+=("${c}")
        done < <(find "${cartella}" -name "${nome}" -type f -print0)
      done
      if (( ${#copie[@]} == 0 )); then
        skip "${nome} in ${sigla}: la copia non c'è ancora"
        continue
      fi
      diverse=0
      for c in "${copie[@]}"; do
        cmp -s "${originale}" "${c}" || diverse=$((diverse + 1))
      done
      messaggio="${nome} in ${sigla}: copie diverse da quella di M3-E01,"
      messaggio+=" ${diverse} su ${#copie[@]}"
      if (( diverse == 0 )); then
        pass "${messaggio}"
      else
        fail "${messaggio}"
      fi
    done
  done
}

t_shellcheck() {
  if (cd "${RADICE}" && shellcheck -x "${SELF}") > /dev/null 2>&1; then
    pass "shellcheck ${SELF#"${RADICE}"/}"
  else
    fail "shellcheck ${SELF#"${RADICE}"/}"
  fi
}

main() {
  local t
  for t in python3 shellcheck; do
    command -v "${t}" > /dev/null 2>&1 \
      || { echo "test_m3_kpi: manca ${t}" >&2; exit 2; }
  done
  for t in "${KPI}" "${DEFINIZIONI}" "${GREZZO}" "${ANONIMO}"; do
    [[ -f "${t}" ]] || { echo "test_m3_kpi: manca ${t}" >&2; exit 2; }
  done
  handson::init_temp_base
  TMP="$(mktemp -d "${HANDSON_TEMP_BASE}/test_m3_kpi.XXXXXX")" || exit 2
  trap 'rm -rf "${TMP}"' EXIT
  t_grezzo
  t_anonimo
  t_regola
  t_precondizioni
  t_copie
  t_shellcheck
  echo "PASS=${PASS} FAIL=${FAIL} SKIP=${SKIP}" \
    "CASES=$((PASS + FAIL + SKIP))/${CASES}"
  if (( PASS + FAIL + SKIP != CASES )); then
    echo "test_m3_kpi: eseguite $((PASS + FAIL + SKIP)) prove, attese" \
      "${CASES}: un caso manca o non è contato" >&2
    exit 2
  fi
  (( FAIL == 0 )) || exit 1
}

main "$@"
