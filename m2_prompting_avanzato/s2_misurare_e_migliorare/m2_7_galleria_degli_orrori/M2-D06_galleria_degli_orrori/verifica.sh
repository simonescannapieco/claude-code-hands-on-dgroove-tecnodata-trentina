#!/bin/bash
#
# verifica.sh di M2-D06 -- la galleria degli orrori. Legge orrori.tsv
# (l'intestazione di «python3 misura_orrori.py --intestazione», poi la riga
# di ogni prova) e, per ogni affermazione di Anthropic che le quattro
# coppie mettono alla prova, stampa i numeri letti e una riga con l'esito:
# «confermata», «non confermata in questa esecuzione» oppure «non
# distinguibile (perché)».
#   - La richiesta vaga: la cura (la scheda) rispetta più vincoli della
#     risposta alla richiesta vaga, che differisce solo nell'istruzione,
#     fra i tre della scheda (tre righe; le etichette Problema:, Quando:,
#     Richieste:; al massimo 60 parole); non distinguibile se anche la
#     richiesta vaga li rispetta tutti e tre. I titoli, gli elenchi, le
#     tabelle e i grassetti della richiesta vaga sono dati.
#   - Il divieto: la cura (la prosa chiesta in positivo) ha meno elementi
#     di Markdown (titoli, voci di elenco, righe di tabella, grassetti)
#     dell'orrore (il divieto): le due prove differiscono solo nella riga
#     sul formato, le due forme dell'esempio di Anthropic; non
#     distinguibile se l'orrore non ne ha nessuno. Il conto del riepilogo
#     senza indicazioni e se la cura non ne ha nessuno sono dati.
#   - Una stima senza dati: la cura (la stessa richiesta con la frase che
#     la limita alle informazioni del messaggio e le permette «non
#     indicato») ha meno importi in euro dell'orrore; non distinguibile se
#     l'orrore non ne ha nessuno. Se la cura non ne ha nessuno, e se scrive
#     «non indicato», sono dati.
#   - La memoria presunta: la firma concordata manca nell'orrore, la cui
#     chiamata non l'ha ricevuta (la garanzia); la cura, che la manda nel
#     prompt, ha la firma. Le righe della cura, e se sono al massimo tre,
#     sono dati.
# Tranne la garanzia sono raccomandazioni: l'esito si stampa e, se non è
# confermato, non fa uscire con 1.
#
# Uso:    verifica.sh <spazio di lavoro>
# Uscita: 0 = le nove risposte ci sono e la garanzia è confermata; l'ultima
#         riga è «Fatto: …» · 1 = orrori.tsv assente, con un'intestazione
#         diversa, una riga mancante o incompleta, oppure la garanzia non
#         confermata · 2 = precondizione (spazio di lavoro assente,
#         orrori.tsv che non si legge)
set -euo pipefail

readonly FILE='orrori.tsv'
INTESTAZIONE=$'prova\ttoken_entrata\ttoken_uscita\tparole\trighe\ttitoli'
INTESTAZIONE+=$'\telenchi\ttabelle\tgrassetti\tetichette\timporti'
INTESTAZIONE+=$'\tnon_indicato\tfirma\trisposta'
readonly INTESTAZIONE
readonly PROVE=(orrore-1-vaga cura-1-vaga base-2-formato orrore-2-divieto
  cura-2-divieto orrore-3-stima cura-3-stima orrore-4-memoria cura-4-memoria)
# I campi sempre numerici: i token, le parole, le righe, i quattro
# elementi di Markdown, gli importi.
readonly NUMERICI=(2 3 4 5 6 7 8 9 11)
readonly NO='non confermata in questa esecuzione'
# Il BOM UTF-8 che un editor può mettere in testa al file.
readonly BOM=$'\xef\xbb\xbf'
FINE='Fatto: ogni affermazione è stata messa alla prova;'
FINE+=' gli esiti sono qui sopra.'
readonly FINE
TSV=''

# Un campo dell'ultima riga di una prova; vuoto se la riga manca o non ha
# quattordici campi. Globals: TSV. Arguments: $1 la prova, $2 il campo.
campo() {
  awk -F'\t' -v p="$1" -v f="$2" '{ sub(/\r$/, "") }
    NR > 1 && $1 == p { v = (NF == 14) ? $f : "" } END { print v }' "${TSV}"
}

# Vero se la riga di una prova è completa: la risposta, i campi numerici e
# il campo che misura la sua coppia (da 0 a 3 le etichette, sì o no
# «non indicato» e la firma). Arguments: $1 la prova.
completa() {
  local i
  [[ -n "$(campo "$1" 14)" ]] || return 1
  for i in "${NUMERICI[@]}"; do
    [[ "$(campo "$1" "${i}")" =~ ^[0-9]+$ ]] || return 1
  done
  case "$1" in
    *-1-vaga) [[ "$(campo "$1" 10)" =~ ^[0-3]$ ]] ;;
    *-3-stima) [[ "$(campo "$1" 12)" =~ ^(sì|no)$ ]] ;;
    *-4-memoria) [[ "$(campo "$1" 13)" =~ ^(sì|no)$ ]] ;;
    *) return 0 ;;
  esac
}

# Gli elementi di Markdown di una prova, in totale. Arguments: $1 la prova.
markdown() {
  local n=0 i v
  for i in 6 7 8 9; do
    v="$(campo "$1" "${i}")"
    n=$((n + 10#${v}))
  done
  echo "${n}"
}

# Gli stessi, uno per uno. Arguments: $1 la prova.
dettaglio() {
  echo "titoli $(campo "$1" 6), voci di elenco $(campo "$1" 7)," \
    "righe di tabella $(campo "$1" 8), grassetti $(campo "$1" 9)"
}

# I vincoli della scheda che una risposta rispetta, da 0 a 3: tre righe
# non vuote; le tre etichette al loro posto; al massimo 60 parole.
# Arguments: $1 la prova. Outputs: il numero.
vincoli() {
  local righe parole eti k=0
  righe="$(campo "$1" 5)"
  parole="$(campo "$1" 4)"
  eti="$(campo "$1" 10)"
  if (( 10#${righe} == 3 )); then k=$((k + 1)); fi
  if (( 10#${eti} == 3 )); then k=$((k + 1)); fi
  if (( 10#${parole} <= 60 )); then k=$((k + 1)); fi
  echo "${k}"
}

# I numeri di una risposta della richiesta vaga e i vincoli della scheda
# che rispetta. Arguments: $1 la prova, $2 i vincoli rispettati.
# Outputs: la riga dei dati, senza il punto finale.
numeri_vaga() {
  echo "  $1: righe $(campo "$1" 5), parole $(campo "$1" 4), etichette al" \
    "loro posto $(campo "$1" 10) su 3: vincoli rispettati $2 su 3"
}

# La richiesta vaga: i vincoli della scheda che rispettano le due risposte,
# e il Markdown della richiesta vaga, come dati; l'esito confronta la cura
# con l'orrore, che differiscono solo nell'istruzione, e non è
# distinguibile se l'orrore li rispetta già tutti e tre.
vaga() {
  local orrore cura v="${NO}"
  orrore="$(vincoli orrore-1-vaga)"
  cura="$(vincoli cura-1-vaga)"
  if (( orrore == 3 )); then
    v='non distinguibile (anche la richiesta vaga rispetta i tre vincoli'
    v+=" della scheda: non c'è niente da migliorare)"
  elif (( cura > orrore )); then
    v='confermata'
  fi
  printf '\nLa richiesta vaga\n'
  echo "$(numeri_vaga orrore-1-vaga "${orrore}"); $(dettaglio orrore-1-vaga)."
  echo "$(numeri_vaga cura-1-vaga "${cura}")."
  echo "Essere specifici su formato e vincoli (la scheda rispetta più" \
    "vincoli della risposta alla richiesta vaga): ${v}"
}

# Il divieto: il Markdown delle tre risposte, e se la cura non ne ha
# nessuno, come dati; l'esito confronta la cura con l'orrore, che
# differiscono solo nella riga sul formato, e non è distinguibile se
# l'orrore non ne ha: non c'è niente da migliorare.
divieto() {
  local base orrore cura senza='no' v="${NO}"
  base="$(markdown base-2-formato)"
  orrore="$(markdown orrore-2-divieto)"
  cura="$(markdown cura-2-divieto)"
  if (( cura == 0 )); then senza='sì'; fi
  if (( orrore == 0 )); then
    v="non distinguibile (anche con il divieto la risposta non ha elementi"
    v+=" di Markdown: non c'è niente da migliorare)"
  elif (( cura < orrore )); then
    v='confermata'
  fi
  printf '\nIl divieto\n'
  echo "  base-2-formato (senza indicazioni sul formato): elementi di" \
    "Markdown ${base} ($(dettaglio base-2-formato))."
  echo "  orrore-2-divieto («Non usare markdown nella tua risposta.»):" \
    "elementi di Markdown ${orrore} ($(dettaglio orrore-2-divieto))."
  echo "  cura-2-divieto («…paragrafi di prosa scorrevole.»): elementi di" \
    "Markdown ${cura} ($(dettaglio cura-2-divieto)); prosa senza" \
    "Markdown: ${senza}."
  echo "Dire cosa fare invece di cosa non fare (con la prosa chiesta in" \
    "positivo, meno elementi di Markdown che con il divieto): ${v}"
}

# Una stima senza dati: gli importi e «non indicato» delle due risposte,
# e se la cura non ha importi, come dati; l'esito confronta la cura con
# l'orrore, che differiscono solo nella frase dell'istruzione, e non è
# distinguibile se l'orrore non ha importi: non c'è niente da ridurre.
stima() {
  local orrore cura scrive senza='no' v="${NO}"
  orrore="$(campo orrore-3-stima 11)"
  cura="$(campo cura-3-stima 11)"
  scrive="$(campo cura-3-stima 12)"
  if (( 10#${cura} == 0 )); then senza='sì'; fi
  if (( 10#${orrore} == 0 )); then
    v="non distinguibile (anche senza l'istruzione la risposta non ha"
    v+=" importi in euro: non c'è niente da ridurre)"
  elif (( 10#${cura} < 10#${orrore} )); then
    v='confermata'
  fi
  printf '\nUna stima senza dati (il messaggio non ha importi in euro: '
  printf 'ogni importo è inventato)\n'
  echo "  orrore-3-stima: importi in euro ${orrore}; «non indicato»:" \
    "$(campo orrore-3-stima 12)."
  echo "  cura-3-stima: importi in euro ${cura}; «non indicato»: ${scrive};" \
    "nessun importo: ${senza}."
  echo "Solo le informazioni del messaggio, e il permesso di dire che un" \
    "dato manca (meno importi inventati che senza l'istruzione): ${v}"
  if [[ "${v}" == 'confermata' ]] && (( 10#${cura} > 0 )); then
    echo "  Per Anthropic queste tecniche riducono le allucinazioni ma" \
      "«non le eliminano del tutto»: un importo nella cura non smentisce" \
      "la riduzione."
  fi
}

# La memoria presunta: la firma e i token in entrata delle due risposte,
# e le righe della cura, come dati; la garanzia (la firma manca
# nell'orrore) e la raccomandazione (la firma, che la cura manda nel
# prompt, c'è nella sua risposta). Returns: 1 se la garanzia non è
# confermata.
memoria() {
  local orrore cura righe tre='no' g='confermata' v="${NO}" ko=0
  orrore="$(campo orrore-4-memoria 13)"
  cura="$(campo cura-4-memoria 13)"
  righe="$(campo cura-4-memoria 5)"
  if [[ "${orrore}" != "no" ]]; then
    g="${NO}"
    ko=1
  fi
  if [[ "${cura}" == "sì" ]]; then v='confermata'; fi
  if (( 10#${righe} <= 3 )); then tre='sì'; fi
  printf '\nLa memoria presunta\n'
  echo "  orrore-4-memoria: token in entrata $(campo orrore-4-memoria 2)" \
    "(il prompt di una riga, senza il messaggio); firma concordata:" \
    "${orrore}."
  echo "  cura-4-memoria: token in entrata $(campo cura-4-memoria 2) (il" \
    "formato e il messaggio nel prompt); firma concordata: ${cura};" \
    "righe ${righe}, al massimo tre: ${tre}."
  echo "Ogni chiamata riceve solo ciò che le si manda (la firma concordata" \
    "«ieri» non c'è): ${g}"
  if (( ko != 0 )); then
    echo "La documentazione garantisce che una chiamata riceve solo ciò" \
      "che le si manda (la Messages API è stateless): in questa" \
      "esecuzione no."
  fi
  echo "Il formato concordato, mandato nel prompt (la firma concordata" \
    "c'è): ${v}"
  return "${ko}"
}

main() {
  local ws="${1:-}" prima='' p ko=0
  if [[ -z "${ws}" || ! -d "${ws}" ]]; then
    echo "verifica: spazio di lavoro assente: ${ws}" >&2
    exit 2
  fi
  TSV="${ws}/${FILE}"
  if [[ ! -f "${TSV}" ]]; then
    echo "Manca ${FILE}: eseguite i passi del README."
    exit 1
  fi
  if [[ ! -r "${TSV}" ]]; then
    echo "verifica: ${FILE} non si legge" >&2
    exit 2
  fi
  if ! IFS= read -r prima < "${TSV}"; then
    : # file vuoto, o una riga senza a capo finale
  fi
  prima="${prima#"${BOM}"}"
  if [[ "${prima%$'\r'}" != "${INTESTAZIONE}" ]]; then
    echo "${FILE}: la prima riga deve essere l'intestazione di «python3" \
      "misura_orrori.py --intestazione», come nei passi del README."
    exit 1
  fi
  for p in "${PROVE[@]}"; do
    if ! completa "${p}"; then
      echo "Manca la risposta a ${p}, o la sua riga di ${FILE} non è" \
        "quella di misura_orrori.py: rifate quella prova (passi del README)."
      ko=1
    fi
  done
  if (( ko != 0 )); then
    exit 1
  fi
  echo "I numeri delle nove prove, da ${FILE}, e l'esito di ogni" \
    "affermazione:"
  vaga
  divieto
  stima
  if ! memoria; then
    ko=1
  fi
  if (( ko != 0 )); then
    exit 1
  fi
  printf '\n%s\n' "${FINE}"
}

main "$@"
