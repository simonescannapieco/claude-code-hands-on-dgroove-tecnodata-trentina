#!/bin/bash
#
# live.sh di M2-E01 -- la prova dal vivo dell'esercitazione, come la farebbe
# un partecipante, in quattro tempi:
#   1. ./misura.sh v0: il prompt pessimo, la risposta, i controlli, il
#      giudizio;
#   2. la versione riscritta di soluzione/prompt/v1.md, poi ./misura.sh v1;
#   3. ./misura.sh --confronta v0 v1;
#   4. il registro: le righe di v0 e v1 con i totali misurati, scritte da
#      questo script con un testo che dice che è una prova automatica.
# Poi verifica.sh dell'elemento. La sessione interattiva del README qui non
# c'è: misura.sh è lo stesso comando che il partecipante lancia con «!».
#
# Uso:    _docente/live.sh <spazio di lavoro>
# Env:    le variabili di tools/lib_handson.sh (HANDSON_NO_PAUSE, ...)
# Uscita: 0 = verifica.sh passa · 1 = la verifica non passa, o misura.sh
#         esce 1 (una chiamata fallita) · 2 = precondizione, anche di
#         misura.sh. Al primo passo di misura.sh che fallisce la prova si
#         ferma, con l'uscita di misura.sh.
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
# lo script sta in <radice>/m2_…/s1_…/m2_e2_…/M2-E01_…/_docente/
readonly RADICE="${SELF%/*/*/*/*/*/*}"
readonly ELEMENTO="${SELF%/_docente/*}"
readonly CONTROLLO="${ELEMENTO}/verifica.sh"
readonly RIFERIMENTO="${ELEMENTO}/soluzione/prompt/v1.md"
# shellcheck source=../../../../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"

readonly AUTOMATICA='(prova automatica del docente)'

# Le righe di v0 e v1 in registro.md, con i totali dei file di misura.
compila_registro() {
  python3 -B -I - registro.md "${AUTOMATICA}" <<'PY'
import json
import re
import sys

path, nota = sys.argv[1:3]
ids = [m.group(1) for m in (re.match(r"^- \*\*([a-z][a-z0-9_]*)\*\*:", r)
       for r in open("rubrica.md", encoding="utf-8")) if m]
cambi = {"v0": "il prompt di partenza",
         "v1": "ruolo, contesto e procedure tra tag, istruzione, formato, "
               "firma (la versione di riferimento)"}
righe = open(path, encoding="utf-8").read().split("\n")
for i, riga in enumerate(righe):
    m = re.match(r"^\|\s*(v[01])\s*\|", riga)
    if not m:
        continue
    v = m.group(1)
    tot = re.search(r"^totale\t(\d+/\d+)$",
                    open("controlli/%s.txt" % v, encoding="utf-8").read(),
                    re.M).group(1)
    criteri = json.load(open("giudizi/%s.json" % v, encoding="utf-8"))[
        "structured_output"]["criteri"]
    ok = sum(1 for c in criteri if c.get("id") in ids and c.get("rispettato"))
    righe[i] = "| %s | %s | %s | %d/%d | %s |" % (v, cambi[v], tot, ok,
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

main() {
  local ws="${1:-}" out rc=0
  [[ -n "${ws}" && -d "${ws}" ]] \
    || handson::die "spazio di lavoro assente: ${ws}"
  handson::need_file "${RIFERIMENTO}"
  cd "${ws}"
  handson::need_tools python3
  handson::need_file misura.sh
  handson::need_file prompt/v0.md
  handson::need_file registro.md
  handson::need_claude
  handson::banner M2-E01 "Il prompt pessimo: misura, riscrivi, rimisura" \
    "Modulo 2, pratica: la misura di v0 e di v1"
  handson::step "1. La misura del prompt pessimo"
  passo "la misura di v0" ./misura.sh v0
  handson::step "2. La versione riscritta, e la sua misura"
  cp -- "${RIFERIMENTO}" prompt/v1.md
  passo "la misura di v1" ./misura.sh v1
  handson::step "3. Il confronto"
  passo "il confronto" ./misura.sh --confronta v0 v1
  handson::step "4. Il registro"
  compila_registro || handson::verdict ko "il registro non si compila"
  handson::step "La verifica"
  out="$("${CONTROLLO}" "${ws}" 2>&1)" || rc=$?
  printf '%s\n' "${out}"
  if (( rc == 0 )); then
    handson::verdict ok "verifica.sh dell'elemento"
  else
    handson::verdict ko "verifica.sh dell'elemento (uscita ${rc})"
  fi
  handson::finish
}

main "$@"
