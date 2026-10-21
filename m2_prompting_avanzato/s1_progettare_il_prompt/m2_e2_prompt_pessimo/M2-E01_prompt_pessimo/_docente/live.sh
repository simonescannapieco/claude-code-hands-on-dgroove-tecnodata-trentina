#!/bin/bash
#
# live.sh di M2-E01 -- la prova dal vivo dell'esercitazione, come la farebbe
# un partecipante sul percorso B, con i comandi del README:
#   1. il registro: la pratica di ogni versione prima di misurarla (v0
#      «partenza», v1 «chiarezza», v2 «rimisura») e che cosa cambia;
#   2. ./misura.sh v0: il prompt pessimo, la risposta, i controlli e il
#      giudizio due volte (la prova del giudice);
#   3. la versione riscritta di soluzione/prompt/v1.md, poi ./misura.sh v1
#      e ./misura.sh --confronta v0 v1;
#   4. la rimisura: cp prompt/v1.md prompt/v2.md, ./misura.sh v2 e
#      ./misura.sh --confronta v1 v2;
#   5. il registro: i totali misurati, con un testo che dice che è una prova
#      automatica.
# Poi verifica.sh dell'elemento. La sessione interattiva del README qui non
# c'è: misura.sh è lo stesso comando che il partecipante lancia con «!».
# Sette chiamate a claude -p: tre per v0 (la risposta e due giudizi), due
# per v1 e due per v2.
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
# lo script sta in <radice>/m2_…/s1_…/m2_e2_…/M2-E01_…/_docente/
readonly RADICE="${SELF%/*/*/*/*/*/*}"
readonly ELEMENTO="${SELF%/_docente/*}"
readonly CONTROLLO="${ELEMENTO}/verifica.sh"
readonly RIFERIMENTO="${ELEMENTO}/soluzione/prompt/v1.md"
# shellcheck source=../../../../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"

readonly AUTOMATICA='(prova automatica del docente)'

# Il registro, in due tempi: «pratiche» scrive la pratica e il cambiamento
# di v0, v1 e v2 prima delle misure (./misura.sh --confronta li legge),
# «totali» scrive dopo i totali misurati. Il giudice di v0 conta le
# affermazioni rispettate tutte e due le volte, come la riga «totali» del
# confronto. Arguments: $1 pratiche o totali.
registro() {
  python3 -B -I - registro.md "$1" "${AUTOMATICA}" <<'PY'
import json
import re
import sys

path, fase, nota = sys.argv[1:4]
voci = {"v0": ("partenza", "il prompt di partenza"),
        "v1": ("chiarezza", "il template intero: ruolo, contesto e "
               "procedure tra tag, istruzione, formato, vincoli (la versione "
               "di riferimento)"),
        "v2": ("rimisura", "niente: v1 misurata di nuovo")}


def esiti(nome):
    criteri = json.load(open(nome, encoding="utf-8"))[
        "structured_output"]["criteri"]
    return {c.get("id"): c.get("rispettato") is True for c in criteri}


def giudice(v, ids):
    uno = esiti("giudizi/%s.json" % v)
    due = esiti("giudizi/v0-bis.json") if v == "v0" else uno
    return sum(1 for i in ids if uno.get(i) and due.get(i))


ids = [m.group(1) for m in (re.match(r"^- \*\*([a-z][a-z0-9_]*)\*\*", r)
       for r in open("rubrica.md", encoding="utf-8")) if m]
righe = open(path, encoding="utf-8").read().split("\n")
for n, riga in enumerate(righe):
    m = re.match(r"^\|\s*(v[0-2])\s*\|", riga)
    if not m:
        continue
    v = m.group(1)
    pratica, cambio = voci[v]
    if fase == "pratiche":
        righe[n] = "| %s | %s | %s | … | … | … |" % (v, pratica, cambio)
        continue
    tot = re.search(r"^totale\t(\d+/\d+)$",
                    open("controlli/%s.txt" % v, encoding="utf-8").read(),
                    re.M).group(1)
    righe[n] = "| %s | %s | %s | %s | %d/%d | %s |" % (
        v, pratica, cambio, tot, giudice(v, ids), len(ids), nota)
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
    "Modulo 2, pratica: v0, v1 (chiarezza) e la rimisura di v1"
  handson::step "1. Il registro: la pratica di ogni versione, prima di" \
    "misurarla"
  registro pratiche || handson::die "il registro non si compila"
  handson::step "2. La misura del prompt pessimo, con la prova del giudice"
  passo "la misura di v0" ./misura.sh v0
  handson::step "3. La versione riscritta, la sua misura e il confronto"
  cp -- "${RIFERIMENTO}" prompt/v1.md
  passo "la misura di v1" ./misura.sh v1
  passo "il confronto di v0 e v1" ./misura.sh --confronta v0 v1
  handson::step "4. La rimisura: v1 misurata di nuovo, come v2"
  cp -- prompt/v1.md prompt/v2.md
  passo "la misura di v2" ./misura.sh v2
  passo "il confronto di v1 e v2" ./misura.sh --confronta v1 v2
  handson::step "5. Il registro: i totali"
  registro totali || handson::verdict ko "il registro non si compila"
  handson::step "La verifica"
  out="$("${CONTROLLO}" "${ws}" 2>&1)" || rc=$?
  printf '%s\n' "${out}"
  handson::verdict_rc "${rc}" "verifica.sh dell'elemento"
  handson::finish
}

main "$@"
