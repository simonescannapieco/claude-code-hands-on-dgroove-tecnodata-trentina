#!/bin/bash
#
# live.sh di M2-E02 -- la prova dal vivo del laboratorio, come la farebbe
# un partecipante sul percorso B: per ognuna delle tre famiglie
# (sviluppo, supporto, sistemi)
#   1. ./misura.sh <famiglia> v0;
#   2. la versione di soluzione/<famiglia>/prompt/v1.md, poi la sua misura;
#   3. la versione di soluzione/<famiglia>/prompt/v2.md, la sua misura e il
#      confronto con v0;
# poi il registro, con i totali misurati e un testo che dice che è una
# prova automatica, e verifica.sh dell'elemento. La sessione interattiva
# del README qui non c'è: misura.sh è lo stesso comando che il partecipante
# lancia con «!».
#
# Uso:    _docente/live.sh <spazio di lavoro>
# Env:    le variabili di tools/lib_handson.sh (HANDSON_NO_PAUSE, ...)
# Uscita: 0 = verifica.sh passa · 1 = la verifica non passa, o misura.sh
#         esce 1 (una chiamata fallita) · 2 = precondizione, anche di
#         misura.sh o di verifica.sh (uscita 2 o più: la verifica non ha
#         potuto girare). Al primo passo di misura.sh che fallisce la prova
#         si ferma, con l'uscita di misura.sh.
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
# lo script sta in <radice>/m2_…/s2_…/m2_e3_…/M2-E02_…/_docente/
readonly RADICE="${SELF%/*/*/*/*/*/*}"
readonly ELEMENTO="${SELF%/_docente/*}"
readonly CONTROLLO="${ELEMENTO}/verifica.sh"
readonly SOLUZIONE="${ELEMENTO}/soluzione"
# shellcheck source=../../../../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"

readonly FAMIGLIE=(sviluppo supporto sistemi)
readonly AUTOMATICA='(prova automatica del docente)'

# Le righe di registro.md con i totali dei file di misura.
compila_registro() {
  python3 -B -I - registro.md "${AUTOMATICA}" <<'PY'
import json
import os
import re
import sys

path, nota = sys.argv[1:3]
cambi = {"v0": "il prompt di partenza",
         "v1": "ruolo, contesto tra tag, istruzione, formato",
         "v2": "il formato stretto e la consegna precisata"}
righe = open(path, encoding="utf-8").read().split("\n")
for i, riga in enumerate(righe):
    m = re.match(r"^\|\s*(sviluppo|supporto|sistemi)\s*\|\s*(v[0-2])\s*\|",
                 riga)
    if not m or not os.path.exists("%s/giudizi/%s.json" % m.groups()):
        continue
    f, v = m.groups()
    ids = [x.group(1) for x in (re.match(r"^- \*\*([a-z][a-z0-9_]*)\*\*:", r)
           for r in open(f + "/rubrica.md", encoding="utf-8")) if x]
    tot = re.search(r"^totale\t(\d+/\d+)$",
                    open("%s/controlli/%s.txt" % (f, v),
                         encoding="utf-8").read(), re.M).group(1)
    criteri = json.load(open("%s/giudizi/%s.json" % (f, v),
                             encoding="utf-8"))["structured_output"]["criteri"]
    ok = sum(1 for c in criteri if c.get("id") in ids and c.get("rispettato"))
    righe[i] = "| %s | %s | %s | %s | %d/%d | %s |" % (f, v, cambi[v], tot, ok,
                                                       len(ids), nota)
open(path, "w", encoding="utf-8").write("\n".join(righe))
PY
}

# Un passo con misura.sh, mostrato e poi eseguito. Se fallisce la prova si
# ferma qui, con l'uscita di misura.sh (1 una chiamata fallita, 2 una
# precondizione) e una riga su STDERR che nomina il passo.
# Arguments: $1 il passo, poi il comando.
passo() {
  local nome="$1" rc=0
  shift
  handson::run "$@" || rc=$?
  if (( rc != 0 )); then
    handson::err "fallito il passo «${nome}» (uscita ${rc}): la prova si" \
      "ferma qui"
    exit "${rc}"
  fi
}

# Le misure di una famiglia: v0, poi le due versioni di riferimento.
# Arguments: $1 la famiglia.
famiglia() {
  local v
  handson::step "$1: la misura di v0"
  passo "$1: la misura di v0" ./misura.sh "$1" v0
  for v in v1 v2; do
    handson::step "$1: la versione ${v}, e la sua misura"
    cp -- "${SOLUZIONE}/$1/prompt/${v}.md" "$1/prompt/${v}.md"
    passo "$1: la misura di ${v}" ./misura.sh "$1" "${v}"
  done
  passo "$1: il confronto" ./misura.sh --confronta "$1" v0 v2
}

main() {
  local ws="${1:-}" out rc=0 f
  [[ -n "${ws}" && -d "${ws}" ]] \
    || handson::die "spazio di lavoro assente: ${ws}"
  for f in "${FAMIGLIE[@]}"; do
    handson::need_file "${SOLUZIONE}/${f}/prompt/v1.md"
    handson::need_file "${SOLUZIONE}/${f}/prompt/v2.md"
  done
  cd "${ws}"
  handson::need_tools python3
  handson::need_file misura.sh
  handson::need_file registro.md
  handson::need_claude
  handson::banner M2-E02 "Tre prompt, due cicli" \
    "Modulo 2, pratica: tre famiglie, v0, v1 e v2"
  for f in "${FAMIGLIE[@]}"; do
    famiglia "${f}"
  done
  handson::step "Il registro"
  compila_registro || handson::verdict ko "il registro non si compila"
  handson::step "La verifica"
  out="$("${CONTROLLO}" "${ws}" 2>&1)" || rc=$?
  printf '%s\n' "${out}"
  handson::verdict_rc "${rc}" "verifica.sh dell'elemento"
  handson::finish
}

main "$@"
