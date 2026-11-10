#!/bin/bash
#
# chiama.sh -- M8-D01 «Quanti token pesa una frase», dal vivo: quanti token
# pesa un testo prima di spedirlo a Claude. Per ogni testo, una POST a
# /v1/messages/count_tokens per il modello claude-haiku-5-5, fatta con curl: il
# comando si vede prima di girare, la chiave non si vede mai. Arriva a curl in
# una configurazione sullo STDIN («curl --config -»), mai fra gli argomenti e
# mai in un file. In risposte/, per ogni testo, tre file: <nome>.richiesta.json
# (il corpo, costruito qui), <nome>.json (il corpo della risposta) e
# <nome>.stato (lo stato HTTP). Poi controlla_conteggi.py stampa la tabella.
#
# Senza file, i due testi della demo, testi/frase-it.txt e testi/frase-en.txt.
# Con i file dati: quelli, ciascuno per intero in un messaggio utente; <nome> è
# il nome del file senza l'ultima estensione (è così che il docente conta i
# prompt del laboratorio, nel debrief).
#
# Uso:    <cartella dell'elemento>/demo/chiama.sh <spazio di lavoro> [file ...]
#           lo spazio di lavoro preparato con tools/prepara_esercizio.sh
#           M8-D01; un testo già contato non si riconta
#           (tools/reset_esercizio.sh M8-D01, oppure un file con un altro nome)
# Env:    ANTHROPIC_API_KEY  la chiave del docente, obbligatoria: letta solo
#                            da qui, mai stampata né scritta in un file
#         PN_HANDSON_ROOT    il repository (default: dal percorso di questo
#                            file; dalla copia nello spazio di lavoro va data)
#         HANDSON_NO_PAUSE   1 = nessuna pausa (tools/lib_handson.sh)
# Uscita: 0 = ogni testo ha il suo conteggio · 1 = curl non è riuscito, oppure
#         il controllo trova un conteggio che manca, che non è un intero
#         positivo o una risposta che non è un conteggio · 2 = precondizione
#         (spazio di lavoro, chiave, curl, un testo che non si può contare)
set -euo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SELF
# lo script sta in <radice>/m8_…/s6_…/m8_3_…/M8-D01_…/demo/
readonly RADICE="${PN_HANDSON_ROOT:-${SELF%/*/*/*/*/*/*}}"
[[ -f "${RADICE}/tools/lib_handson.sh" ]] || { echo "chiama.sh: non trovo" \
  "tools/lib_handson.sh in ${RADICE}: lanciatelo dal repository, o date" \
  "PN_HANDSON_ROOT" >&2; exit 2; }
# shellcheck source=../../../../../tools/lib_handson.sh
source "${RADICE}/tools/lib_handson.sh"

readonly ELEMENTO=M8-D01
readonly URL='https://api.anthropic.com/v1/messages/count_tokens'
readonly VERSIONE_API='2026-10-21'
readonly MODELLO='claude-haiku-5-5'
readonly MAX_SECONDI=60
readonly RISPOSTE=risposte
readonly NOME_RE='^[A-Za-z0-9][A-Za-z0-9._-]*$'
readonly PREDEFINITI=(testi/frase-it.txt testi/frase-en.txt)
TESTI=()
NOMI=()
CORPI=''

# I testi da contare: i file dati, con il percorso assoluto perché lo script
# poi si sposta nello spazio di lavoro; senza file, i due della demo.
# Globals: TESTI (assegnata). Arguments: i file dati.
raccogli_testi() {
  local f abs
  if (( $# == 0 )); then
    TESTI=("${PREDEFINITI[@]}")
    return 0
  fi
  for f in "$@"; do
    abs="$(readlink -f -- "${f}")" || abs="${f}"
    TESTI+=("${abs}")
  done
}

# Il nome di ogni testo e i controlli sui file: leggibile, con un nome che si
# può usare in risposte/, mai ripetuto e non ancora contato.
# Globals: TESTI (letta), NOMI (assegnata).
prepara_nomi() {
  local f base nome visto
  for f in "${TESTI[@]}"; do
    handson::need_file "${f}"
    base="${f##*/}"
    nome="${base%.*}"
    [[ "${nome}" =~ ${NOME_RE} ]] \
      || handson::die "il nome del file «${base}» non si può usare: lettere," \
        "cifre, punti, trattini e trattini bassi, e non comincia col punto"
    for visto in ${NOMI[@]+"${NOMI[@]}"}; do
      [[ "${visto}" != "${nome}" ]] \
        || handson::die "due file si chiamano «${nome}»: ogni testo vuole" \
          "un nome suo"
    done
    [[ ! -e "${RISPOSTE}/${nome}.json" ]] \
      || handson::die "${RISPOSTE}/${nome}.json c'è già: quel testo è già" \
        "contato (tools/reset_esercizio.sh ${ELEMENTO}, o un file con un" \
        "altro nome)"
    NOMI+=("${nome}")
  done
}

# Le precondizioni, prima di ogni chiamata. Va chiamata nello spazio di lavoro.
# Globals: ANTHROPIC_API_KEY, TESTI, NOMI.
precondizioni() {
  local radice segno
  handson::need_tools curl python3 git
  handson::need_api_key
  [[ "${ANTHROPIC_API_KEY}" =~ ^[A-Za-z0-9_.-]+$ ]] \
    || handson::die "ANTHROPIC_API_KEY ha caratteri che non si possono" \
      "mettere nella configurazione di curl: non la uso"
  radice="$(git rev-parse --show-toplevel 2> /dev/null)" || radice=''
  segno="$(git config --get corso.elemento 2> /dev/null)" || segno=''
  [[ "${radice}" == "$(pwd -P)" && "${segno}" == "${ELEMENTO}" ]] \
    || handson::die "$(pwd -P) non è lo spazio di lavoro di ${ELEMENTO}:" \
      "preparatelo con tools/prepara_esercizio.sh ${ELEMENTO}"
  handson::need_file controlla_conteggi.py
  prepara_nomi
}

# Il corpo di una richiesta: il modello e un solo messaggio utente con il
# testo del file, senza gli a capo finali. Un file vuoto o non UTF-8 è una
# precondizione: i corpi si costruiscono tutti prima della prima POST.
# Globals: MODELLO. Arguments: $1 il file del testo, $2 il file del corpo.
componi_corpo() {
  python3 -B -I - "$1" "$2" "${MODELLO}" <<'PY' \
    || handson::die "il testo «$1» non si può contare: è vuoto o non è UTF-8"
import json
import sys

testo_file, corpo_file, modello = sys.argv[1:]
try:
    with open(testo_file, encoding="utf-8") as fh:
        testo = fh.read()
except (OSError, UnicodeDecodeError):
    sys.exit(1)
testo = testo.rstrip("\n")
if not testo.strip():
    sys.exit(1)
with open(corpo_file, "w", encoding="utf-8") as fh:
    json.dump({"model": modello,
               "messages": [{"role": "user", "content": testo}]},
              fh, ensure_ascii=False)
PY
}

# Costruisce i corpi di tutti i testi, in una cartella temporanea, e solo
# dopo li mette in risposte/: se un testo non si può contare non resta niente.
# Globals: TESTI, NOMI (lette), CORPI (temporanea), RISPOSTE.
costruisci_corpi() {
  local i nome
  handson::tmpdir CORPI
  for i in "${!TESTI[@]}"; do
    componi_corpo "${TESTI[i]}" "${CORPI}/${NOMI[i]}.richiesta.json"
  done
  mkdir -p -- "${RISPOSTE}" || handson::die "non riesco a creare ${RISPOSTE}/"
  for nome in "${NOMI[@]}"; do
    cp -- "${CORPI}/${nome}.richiesta.json" \
      "${RISPOSTE}/${nome}.richiesta.json" \
      || handson::die "non riesco a scrivere in ${RISPOSTE}/"
  done
}

# Toglie ciò che questa esecuzione ha scritto in risposte/, così si può
# rilanciare lo script dopo una chiamata interrotta. Globals: NOMI, RISPOSTE.
togli_risposte() {
  local nome
  for nome in "${NOMI[@]}"; do
    rm -f -- "${RISPOSTE}/${nome}.richiesta.json" \
      "${RISPOSTE}/${nome}.json" "${RISPOSTE}/${nome}.stato"
  done
  rmdir -- "${RISPOSTE}" 2> /dev/null || handson::note "${RISPOSTE}/ resta"
}

# La POST di un testo: la riga di autorizzazione arriva a curl sullo STDIN,
# con --config -, così non è un argomento (ps) e non finisce in un file; il
# resto del comando si vede prima di girare (handson::run). Se curl non
# riesce: verdetto KO e fine, uscita 1, senza file a metà.
# Arguments: $1 il nome del testo.
posta() {
  local nome="$1"
  local -a comando=(curl --silent --show-error --max-time "${MAX_SECONDI}"
    --request POST --config - --header "anthropic-version: ${VERSIONE_API}"
    --header "content-type: application/json"
    --data-binary "@${RISPOSTE}/${nome}.richiesta.json"
    --output "${RISPOSTE}/${nome}.json" --write-out '%{http_code}\n'
    "${URL}")
  if ! printf 'header = "Authorization: Bearer %s"\n' \
      "${ANTHROPIC_API_KEY}" \
      | handson::run "${comando[@]}" > "${RISPOSTE}/${nome}.stato"; then
    togli_risposte
    handson::verdict ko "curl non è riuscito su ${nome}: la richiesta non" \
      "è arrivata"
    handson::finish
  fi
}

# Le POST, una per testo; con i due testi della demo si vede anche il corpo.
# Globals: NOMI, TESTI (lette). Arguments: $1 1 se i testi sono quelli della
# demo, 0 se vengono dagli argomenti.
conta_tutti() {
  local i nome
  for i in "${!NOMI[@]}"; do
    nome="${NOMI[i]}"
    handson::step "Il testo «${nome}»"
    if (( $1 == 1 )); then
      handson::run cat -- "${TESTI[i]}"
      handson::run cat -- "${RISPOSTE}/${nome}.richiesta.json"
      printf '\n'
    fi
    handson::note "la chiave arriva a curl sullo STDIN (--config -): non" \
      "compare sulla riga di comando, e non si scrive in nessun file"
    handson::pause "fare la POST"
    posta "${nome}"
  done
}

main() {
  local ws="${1:-}" predefiniti=0 rc=0
  [[ -n "${ws}" && -d "${ws}" ]] \
    || handson::die "spazio di lavoro assente: ${ws}"
  shift
  if (( $# == 0 )); then
    predefiniti=1
  fi
  raccogli_testi "$@"
  cd -- "${ws}" || handson::die "lo spazio di lavoro ${ws} non si apre"
  precondizioni
  handson::banner "${ELEMENTO}" "Quanti token pesa una frase" \
    "Modulo 8, «Il conto in token»: contare prima di spedire"
  costruisci_corpi
  conta_tutti "${predefiniti}"
  handson::step "I conteggi, testo per testo"
  handson::run python3 -B -I controlla_conteggi.py "${RISPOSTE}" \
    < /dev/null || rc=$?
  handson::verdict_rc "${rc}" "i conteggi, in ${RISPOSTE}/"
  handson::finish
}

main "$@"
