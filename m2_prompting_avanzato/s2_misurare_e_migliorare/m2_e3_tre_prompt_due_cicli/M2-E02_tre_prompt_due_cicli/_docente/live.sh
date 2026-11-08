#!/bin/bash
#
# live.sh di M2-E02 -- la prova dal vivo del laboratorio, come la farebbe
# un partecipante sul percorso B, con i comandi del README:
#   1. il registro: la pratica di ogni versione prima di misurarla (v0
#      «partenza», v1 «chiarezza», v2 «contesto», in ogni famiglia) e che
#      cosa cambia;
#   2. per ognuna delle tre famiglie (sviluppo, supporto, sistemi):
#      ./misura.sh <famiglia> v0, con il giudizio due volte (la prova del
#      giudice; dopo la prima famiglia, l'elenco delle pratiche); la
#      versione di soluzione/<famiglia>/prompt/v1.md, la sua misura,
#      ./misura.sh --confronta <famiglia> v0 v1 e il diff; la versione di
#      soluzione/<famiglia>/prompt/v2.md, la sua misura, il confronto di
#      v1 e v2 e il diff;
#   3. il registro: i totali misurati, con un testo che dice che è una prova
#      automatica.
# Poi verifica.sh dell'elemento. Stampa anche la data e la versione di
# Claude Code: tutto ciò che la soluzione del README mostra viene dall'uscita
# di questa prova. La sessione interattiva del README qui non c'è: misura.sh
# è lo stesso comando che il partecipante lancia con «!».
# Ventuno chiamate a claude -p: sette per famiglia, tre per v0 (la risposta
# e due giudizi), due per v1 e due per v2. Prima della prima chiamata
# controlla ogni famiglia (prompt/v0.md, rubrica.md, controlli.tsv, dati/ e
# v0 composta dal kit): una famiglia rotta ferma la prova prima di pagare
# le chiamate delle altre.
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

# Il registro, in due tempi: «pratiche» scrive la pratica e il cambiamento
# di ogni famiglia e versione prima delle misure (./misura.sh --confronta
# li legge), «totali» scrive dopo i totali misurati. Il giudice di v0 conta
# le affermazioni rispettate tutte e due le volte, come la riga «totali»
# del confronto. Arguments: $1 pratiche o totali.
registro() {
  python3 -B -I - registro.md "$1" "${AUTOMATICA}" <<'PY'
import json
import os
import re
import sys

path, fase, nota = sys.argv[1:4]
pratiche = {"v0": "partenza", "v1": "chiarezza", "v2": "contesto"}
cambi = {"v0": "il prompt di partenza",
         "v1": "il template intero: un tag per ingrediente, il dato nel suo "
         "tag",
         ("sviluppo", "v2"): "solo il contesto: il perché e chi usa il "
         "risultato, e la convenzione del team nel suo tag",
         ("supporto", "v2"): "solo il contesto: il perché e chi usa il "
         "risultato, e la guida al tono nel suo tag",
         ("sistemi", "v2"): "solo il contesto: il perché e chi usa il "
         "risultato"}


def esiti(nome):
    criteri = json.load(open(nome, encoding="utf-8"))[
        "structured_output"]["criteri"]
    return {c.get("id"): c.get("rispettato") is True for c in criteri}


def giudice(f, v, ids):
    uno = esiti("%s/giudizi/%s.json" % (f, v))
    due = esiti("%s/giudizi/v0-bis.json" % f) if v == "v0" else uno
    return sum(1 for i in ids if uno.get(i) and due.get(i))


righe = open(path, encoding="utf-8").read().split("\n")
for n, riga in enumerate(righe):
    m = re.match(r"^\|\s*(sviluppo|supporto|sistemi)\s*\|\s*(v[0-2])\s*\|",
                 riga)
    if not m:
        continue
    f, v = m.groups()
    cambio = cambi.get(v) or cambi[(f, v)]
    if fase == "pratiche":
        righe[n] = "| %s | %s | %s | %s | … | … | … |" % (
            f, v, pratiche[v], cambio)
        continue
    if not os.path.exists("%s/giudizi/%s.json" % (f, v)):
        continue
    ids = [x.group(1) for x in (re.match(r"^- \*\*([a-z][a-z0-9_]*)\*\*", r)
           for r in open(f + "/rubrica.md", encoding="utf-8")) if x]
    tot = re.search(r"^totale\t(\d+/\d+)$",
                    open("%s/controlli/%s.txt" % (f, v),
                         encoding="utf-8").read(), re.M).group(1)
    righe[n] = "| %s | %s | %s | %s | %s | %d/%d | %s |" % (
        f, v, pratiche[v], cambio, tot, giudice(f, v, ids), len(ids), nota)
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

# Il diff fra due versioni, come il comando del README: git diff --no-index
# esce 1 quando i file sono diversi, l'unico esito atteso qui. Senza pager e
# senza la configurazione di chi lo lancia, perché l'uscita sia quella che
# la soluzione del README mostra. Arguments: $1 e $2 i due file.
mostra_diff() {
  local rc=0
  handson::need_file "$1"
  handson::need_file "$2"
  GIT_PAGER=cat GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 \
    handson::run git diff --no-index "$1" "$2" || rc=$?
  (( rc == 1 )) \
    || handson::die "git diff: uscita ${rc}, attesa 1 (versioni diverse)"
}

# Le misure di una famiglia: v0 con la prova del giudice, poi le due
# versioni di riferimento, ognuna confrontata con la precedente, da cui
# parte, con il loro diff. Arguments: $1 la famiglia.
famiglia() {
  local v prima=v0
  handson::step "$1: la misura di v0, con la prova del giudice"
  passo "$1: la misura di v0" ./misura.sh "$1" v0
  if [[ "$1" == "${FAMIGLIE[0]}" ]]; then
    handson::step "L'elenco delle pratiche"
    passo "l'elenco delle pratiche" ./misura.sh --pratiche
  fi
  for v in v1 v2; do
    handson::step "$1: la versione ${v}, la sua misura e il confronto"
    cp -- "${SOLUZIONE}/$1/prompt/${v}.md" "$1/prompt/${v}.md"
    passo "$1: la misura di ${v}" ./misura.sh "$1" "${v}"
    passo "$1: il confronto di ${prima} e ${v}" \
      ./misura.sh --confronta "$1" "${prima}" "${v}"
    mostra_diff "$1/prompt/${prima}.md" "$1/prompt/${v}.md"
    prima="${v}"
  done
}

# Prima della prima chiamata, ogni famiglia dello spazio di lavoro:
# prompt/v0.md, rubrica.md, controlli.tsv e dati/, poi v0 composta dal kit,
# con i controlli che misura.sh fa prima di chiamare claude (i segnaposto,
# le righe di controlli.tsv, la rubrica, il peso). Esce 2 alla prima
# famiglia rotta, con il messaggio di kit.py su STDERR.
famiglie_pronte() {
  local f
  for f in "${FAMIGLIE[@]}"; do
    handson::need_file "${f}/prompt/v0.md"
    handson::need_file "${f}/rubrica.md"
    handson::need_file "${f}/controlli.tsv"
    [[ -d "${f}/dati" && -r "${f}/dati" && -x "${f}/dati" ]] \
      || handson::die "cartella assente o illeggibile: ${f}/dati"
    python3 -B strumenti/kit.py componi "${f}" v0 > /dev/null \
      || handson::die "${f}: v0 non si compone (il messaggio di kit.py è" \
        "qui sopra)"
  done
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
  handson::need_tools python3 git
  handson::need_file misura.sh
  handson::need_file registro.md
  handson::need_file strumenti/kit.py
  famiglie_pronte
  handson::need_claude
  handson::banner M2-E02 "Tre prompt, due cicli" \
    "Modulo 2, esercitazione: tre famiglie, v1 chiarezza e v2 contesto"
  printf 'data della prova: %s\n' "$(date -u +%F)"
  handson::step "Il registro: la pratica di ogni versione, prima di" \
    "misurarla"
  registro pratiche || handson::die "il registro non si compila"
  for f in "${FAMIGLIE[@]}"; do
    famiglia "${f}"
  done
  handson::step "Il registro: i totali"
  registro totali || handson::verdict ko "il registro non si compila"
  handson::step "La verifica"
  out="$("${CONTROLLO}" "${ws}" 2>&1)" || rc=$?
  printf '%s\n' "${out}"
  handson::verdict_rc "${rc}" "verifica.sh dell'elemento"
  handson::finish
}

main "$@"
